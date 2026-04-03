//
//  DiffRendering.swift
//  AiyuTerm
//
//  Author: everettjf
//

import Foundation

enum DiffRenderedLineKind: Hashable, Sendable {
    case context
    case added
    case removed
}

enum DiffSplitCellKind: Hashable, Sendable {
    case context
    case added
    case removed
    case changedAdded
    case changedRemoved
}

struct DiffUnifiedLine: Identifiable, Hashable, Sendable {
    let id: String
    let kind: DiffRenderedLineKind
    let oldLineNumber: Int?
    let newLineNumber: Int?
    let text: String
}

struct DiffSplitCell: Hashable, Sendable {
    let lineNumber: Int?
    let text: String
    let kind: DiffSplitCellKind
}

struct DiffSplitRow: Identifiable, Hashable, Sendable {
    let id: String
    let left: DiffSplitCell?
    let right: DiffSplitCell?
}

struct StructuredDiffDocument: Hashable, Sendable {
    let unifiedLines: [DiffUnifiedLine]
    let splitRows: [DiffSplitRow]
    let addedLineCount: Int
    let removedLineCount: Int
}

struct DiffPatchAnalysis: Hashable, Sendable {
    let hunkCount: Int
    let totalOldSpan: Int
    let totalNewSpan: Int
    let maxOldSpan: Int
    let maxNewSpan: Int
    let maxTouchedOldLine: Int
    let maxTouchedNewLine: Int

    nonisolated var maxSpan: Int {
        max(maxOldSpan, maxNewSpan)
    }

    nonisolated var totalSpan: Int {
        max(totalOldSpan, totalNewSpan)
    }
}

extension StructuredDiffDocument {
    nonisolated static func empty() -> StructuredDiffDocument {
        StructuredDiffDocument(
            unifiedLines: [],
            splitRows: [],
            addedLineCount: 0,
            removedLineCount: 0
        )
    }

    func displayedUnifiedLines(showsFullFile: Bool, contextLineCount: Int = 3) -> [DiffUnifiedLine] {
        guard !showsFullFile else { return unifiedLines }
        return collapseUnifiedContext(contextLineCount: contextLineCount)
    }

    func displayedSplitRows(showsFullFile: Bool, contextLineCount: Int = 3) -> [DiffSplitRow] {
        guard !showsFullFile else { return splitRows }
        return collapseSplitContext(contextLineCount: contextLineCount)
    }

    private func collapseUnifiedContext(contextLineCount: Int) -> [DiffUnifiedLine] {
        var collapsed: [DiffUnifiedLine] = []
        var index = 0

        while index < unifiedLines.count {
            if unifiedLines[index].kind != .context {
                collapsed.append(unifiedLines[index])
                index += 1
                continue
            }

            let start = index
            while index < unifiedLines.count, unifiedLines[index].kind == .context {
                index += 1
            }

            let run = Array(unifiedLines[start..<index])
            collapsed.append(
                contentsOf: collapsedUnifiedRun(
                    run,
                    startIndex: start,
                    hasPreviousChange: start > 0,
                    hasNextChange: index < unifiedLines.count,
                    contextLineCount: contextLineCount
                )
            )
        }

        return collapsed
    }

    private func collapseSplitContext(contextLineCount: Int) -> [DiffSplitRow] {
        var collapsed: [DiffSplitRow] = []
        var index = 0

        while index < splitRows.count {
            if !splitRows[index].isContextRow {
                collapsed.append(splitRows[index])
                index += 1
                continue
            }

            let start = index
            while index < splitRows.count, splitRows[index].isContextRow {
                index += 1
            }

            let run = Array(splitRows[start..<index])
            collapsed.append(
                contentsOf: collapsedSplitRun(
                    run,
                    startIndex: start,
                    hasPreviousChange: start > 0,
                    hasNextChange: index < splitRows.count,
                    contextLineCount: contextLineCount
                )
            )
        }

        return collapsed
    }

    private func collapsedUnifiedRun(
        _ run: [DiffUnifiedLine],
        startIndex: Int,
        hasPreviousChange: Bool,
        hasNextChange: Bool,
        contextLineCount: Int
    ) -> [DiffUnifiedLine] {
        if !hasPreviousChange && !hasNextChange {
            return run
        }

        let clampedContext = max(contextLineCount, 0)

        if hasPreviousChange && hasNextChange {
            let leadingCount = min(clampedContext, run.count)
            let trailingCount = min(clampedContext, max(run.count - leadingCount, 0))
            let omittedCount = run.count - leadingCount - trailingCount
            if omittedCount <= 0 {
                return run
            }
            return Array(run.prefix(leadingCount))
                + [collapsedUnifiedMarker(startIndex: startIndex, omittedCount: omittedCount)]
                + Array(run.suffix(trailingCount))
        }

        if hasNextChange {
            let trailingCount = min(clampedContext, run.count)
            let omittedCount = run.count - trailingCount
            if omittedCount <= 0 {
                return run
            }
            return [collapsedUnifiedMarker(startIndex: startIndex, omittedCount: omittedCount)] + Array(run.suffix(trailingCount))
        }

        let leadingCount = min(clampedContext, run.count)
        let omittedCount = run.count - leadingCount
        if omittedCount <= 0 {
            return run
        }
        return Array(run.prefix(leadingCount)) + [collapsedUnifiedMarker(startIndex: startIndex, omittedCount: omittedCount)]
    }

    private func collapsedSplitRun(
        _ run: [DiffSplitRow],
        startIndex: Int,
        hasPreviousChange: Bool,
        hasNextChange: Bool,
        contextLineCount: Int
    ) -> [DiffSplitRow] {
        if !hasPreviousChange && !hasNextChange {
            return run
        }

        let clampedContext = max(contextLineCount, 0)

        if hasPreviousChange && hasNextChange {
            let leadingCount = min(clampedContext, run.count)
            let trailingCount = min(clampedContext, max(run.count - leadingCount, 0))
            let omittedCount = run.count - leadingCount - trailingCount
            if omittedCount <= 0 {
                return run
            }
            return Array(run.prefix(leadingCount))
                + [collapsedSplitMarker(startIndex: startIndex, omittedCount: omittedCount)]
                + Array(run.suffix(trailingCount))
        }

        if hasNextChange {
            let trailingCount = min(clampedContext, run.count)
            let omittedCount = run.count - trailingCount
            if omittedCount <= 0 {
                return run
            }
            return [collapsedSplitMarker(startIndex: startIndex, omittedCount: omittedCount)] + Array(run.suffix(trailingCount))
        }

        let leadingCount = min(clampedContext, run.count)
        let omittedCount = run.count - leadingCount
        if omittedCount <= 0 {
            return run
        }
        return Array(run.prefix(leadingCount)) + [collapsedSplitMarker(startIndex: startIndex, omittedCount: omittedCount)]
    }

    private func collapsedUnifiedMarker(startIndex: Int, omittedCount: Int) -> DiffUnifiedLine {
        DiffUnifiedLine(
            id: "u-collapse-\(startIndex)-\(omittedCount)",
            kind: .context,
            oldLineNumber: nil,
            newLineNumber: nil,
            text: "… \(omittedCount) unchanged line\(omittedCount == 1 ? "" : "s")"
        )
    }

    private func collapsedSplitMarker(startIndex: Int, omittedCount: Int) -> DiffSplitRow {
        let marker = DiffSplitCell(
            lineNumber: nil,
            text: "… \(omittedCount) unchanged line\(omittedCount == 1 ? "" : "s")",
            kind: .context
        )
        return DiffSplitRow(
            id: "s-collapse-\(startIndex)-\(omittedCount)",
            left: marker,
            right: marker
        )
    }
}

private extension DiffSplitRow {
    var isContextRow: Bool {
        left?.kind == .context && right?.kind == .context
    }
}

private enum DiffEditOperation {
    case equal(String)
    case insert(String)
    case delete(String)
}

private struct DiffPatchHunkHeader {
    let oldStart: Int
    let oldCount: Int
    let newStart: Int
    let newCount: Int
}

enum DiffRenderingResult: Hashable, Sendable {
    case document(StructuredDiffDocument)
    case requiresPatchFallback(reason: String)
}

enum DiffRenderingEngine {
    nonisolated private static let maxDynamicProgrammingCells = 250_000

    nonisolated static func render(old oldText: String, new newText: String, debugLabel: String? = nil) -> DiffRenderingResult {
        let start = DiffDiagnostics.now()
        let oldLines = normalizedLines(in: oldText)
        let newLines = normalizedLines(in: newText)
        let dpCellCount = oldLines.count * newLines.count
        let label = debugLabel ?? "<unknown>"

        DiffDiagnostics.log(
            "Diff render start for \(label) [oldLines=\(oldLines.count), newLines=\(newLines.count), dpCells=\(dpCellCount)]"
        )

        if oldText == "<<Binary file>>" || newText == "<<Binary file>>" {
            let reason = "File is binary."
            DiffDiagnostics.log("Diff render requires patch fallback for \(label) because file is binary")
            return .requiresPatchFallback(reason: reason)
        }

        if dpCellCount > maxDynamicProgrammingCells {
            let reason = "Structured diff exceeded supported limits."
            DiffDiagnostics.log(
                "Diff render requires patch fallback for \(label) because dpCells \(dpCellCount) exceed limit \(maxDynamicProgrammingCells)"
            )
            return .requiresPatchFallback(reason: reason)
        }

        let operationsStart = DiffDiagnostics.now()
        let operations = operations(oldLines: oldLines, newLines: newLines)
        let document = makeDocument(from: operations)
        DiffDiagnostics.log(
            "Diff render finished for \(label) in \(DiffDiagnostics.formatMilliseconds(DiffDiagnostics.elapsedMilliseconds(since: start))) [operations=\(operations.count), lcs=\(DiffDiagnostics.formatMilliseconds(DiffDiagnostics.elapsedMilliseconds(since: operationsStart))), unified=\(document.unifiedLines.count), split=\(document.splitRows.count)]"
        )
        return .document(document)
    }

    nonisolated static func renderPatch(_ patch: String, debugLabel: String? = nil) -> StructuredDiffDocument? {
        let label = debugLabel ?? "<unknown>"
        let start = DiffDiagnostics.now()
        let lines = patch.components(separatedBy: "\n")

        var unifiedLines: [DiffUnifiedLine] = []
        var splitRows: [DiffSplitRow] = []
        var pendingRemoved: [(lineNumber: Int, text: String)] = []
        var pendingAdded: [(lineNumber: Int, text: String)] = []
        var addedLineCount = 0
        var removedLineCount = 0
        var rowID = 0
        var index = 0
        var currentOldLine: Int?
        var currentNewLine: Int?
        var sawHunk = false

        func flushPendingChanges() {
            guard !pendingRemoved.isEmpty || !pendingAdded.isEmpty else { return }
            let pairCount = max(pendingRemoved.count, pendingAdded.count)
            for pairIndex in 0..<pairCount {
                let removed = pairIndex < pendingRemoved.count ? pendingRemoved[pairIndex] : nil
                let added = pairIndex < pendingAdded.count ? pendingAdded[pairIndex] : nil

                if let removed {
                    unifiedLines.append(
                        DiffUnifiedLine(
                            id: "u-\(rowID)-old",
                            kind: .removed,
                            oldLineNumber: removed.lineNumber,
                            newLineNumber: nil,
                            text: removed.text
                        )
                    )
                    removedLineCount += 1
                }

                if let added {
                    unifiedLines.append(
                        DiffUnifiedLine(
                            id: "u-\(rowID)-new",
                            kind: .added,
                            oldLineNumber: nil,
                            newLineNumber: added.lineNumber,
                            text: added.text
                        )
                    )
                    addedLineCount += 1
                }

                splitRows.append(
                    DiffSplitRow(
                        id: "s-\(rowID)",
                        left: removed.map {
                            DiffSplitCell(
                                lineNumber: $0.lineNumber,
                                text: $0.text,
                                kind: added == nil ? .removed : .changedRemoved
                            )
                        },
                        right: added.map {
                            DiffSplitCell(
                                lineNumber: $0.lineNumber,
                                text: $0.text,
                                kind: removed == nil ? .added : .changedAdded
                            )
                        }
                    )
                )
                rowID += 1
            }

            pendingRemoved.removeAll(keepingCapacity: true)
            pendingAdded.removeAll(keepingCapacity: true)
        }

        func appendContextLine(text: String, oldLineNumber: Int, newLineNumber: Int) {
            flushPendingChanges()
            unifiedLines.append(
                DiffUnifiedLine(
                    id: "u-\(rowID)",
                    kind: .context,
                    oldLineNumber: oldLineNumber,
                    newLineNumber: newLineNumber,
                    text: text
                )
            )
            splitRows.append(
                DiffSplitRow(
                    id: "s-\(rowID)",
                    left: DiffSplitCell(lineNumber: oldLineNumber, text: text, kind: .context),
                    right: DiffSplitCell(lineNumber: newLineNumber, text: text, kind: .context)
                )
            )
            rowID += 1
        }

        func appendOmittedMarker(count: Int) {
            guard count > 0 else { return }
            flushPendingChanges()
            let text = "… \(count) unchanged line\(count == 1 ? "" : "s")"
            let marker = DiffSplitCell(lineNumber: nil, text: text, kind: .context)
            unifiedLines.append(
                DiffUnifiedLine(
                    id: "u-collapse-\(rowID)-\(count)",
                    kind: .context,
                    oldLineNumber: nil,
                    newLineNumber: nil,
                    text: text
                )
            )
            splitRows.append(
                DiffSplitRow(
                    id: "s-collapse-\(rowID)-\(count)",
                    left: marker,
                    right: marker
                )
            )
            rowID += 1
        }

        while index < lines.count {
            guard let hunk = parseHunkHeader(lines[index]) else {
                index += 1
                continue
            }

            sawHunk = true
            if let previousOldLine = currentOldLine, let previousNewLine = currentNewLine {
                let omittedCount = max(hunk.oldStart - previousOldLine, hunk.newStart - previousNewLine)
                appendOmittedMarker(count: omittedCount)
            }

            currentOldLine = hunk.oldStart
            currentNewLine = hunk.newStart
            index += 1

            while index < lines.count, parseHunkHeader(lines[index]) == nil {
                let line = lines[index]
                guard let prefix = line.first else {
                    index += 1
                    continue
                }
                let text = String(line.dropFirst())

                switch prefix {
                case " ":
                    guard let oldLineNumber = currentOldLine, let newLineNumber = currentNewLine else {
                        return nil
                    }
                    appendContextLine(text: text, oldLineNumber: oldLineNumber, newLineNumber: newLineNumber)
                    currentOldLine = oldLineNumber + 1
                    currentNewLine = newLineNumber + 1
                case "-":
                    guard let oldLineNumber = currentOldLine else { return nil }
                    pendingRemoved.append((lineNumber: oldLineNumber, text: text))
                    currentOldLine = oldLineNumber + 1
                case "+":
                    guard let newLineNumber = currentNewLine else { return nil }
                    pendingAdded.append((lineNumber: newLineNumber, text: text))
                    currentNewLine = newLineNumber + 1
                case "\\":
                    break
                default:
                    break
                }

                index += 1
            }

            flushPendingChanges()
        }

        guard sawHunk else {
            DiffDiagnostics.log("Patch render unavailable for \(label) because no hunks were found")
            return nil
        }

        let document = StructuredDiffDocument(
            unifiedLines: unifiedLines,
            splitRows: splitRows,
            addedLineCount: addedLineCount,
            removedLineCount: removedLineCount
        )
        DiffDiagnostics.log(
            "Patch render finished for \(label) in \(DiffDiagnostics.formatMilliseconds(DiffDiagnostics.elapsedMilliseconds(since: start))) [unified=\(document.unifiedLines.count), split=\(document.splitRows.count)]"
        )
        return document
    }

    nonisolated static func analyzePatch(_ patch: String) -> DiffPatchAnalysis {
        var hunkCount = 0
        var totalOldSpan = 0
        var totalNewSpan = 0
        var maxOldSpan = 0
        var maxNewSpan = 0
        var maxTouchedOldLine = 0
        var maxTouchedNewLine = 0

        for line in patch.split(separator: "\n", omittingEmptySubsequences: false) {
            guard let hunk = parseHunkHeader(String(line)) else { continue }
            hunkCount += 1
            totalOldSpan += hunk.oldCount
            totalNewSpan += hunk.newCount
            maxOldSpan = max(maxOldSpan, hunk.oldCount)
            maxNewSpan = max(maxNewSpan, hunk.newCount)
            maxTouchedOldLine = max(maxTouchedOldLine, hunk.oldStart + max(hunk.oldCount - 1, 0))
            maxTouchedNewLine = max(maxTouchedNewLine, hunk.newStart + max(hunk.newCount - 1, 0))
        }

        return DiffPatchAnalysis(
            hunkCount: hunkCount,
            totalOldSpan: totalOldSpan,
            totalNewSpan: totalNewSpan,
            maxOldSpan: maxOldSpan,
            maxNewSpan: maxNewSpan,
            maxTouchedOldLine: maxTouchedOldLine,
            maxTouchedNewLine: maxTouchedNewLine
        )
    }

    private nonisolated static func makeDocument(from operations: [DiffEditOperation]) -> StructuredDiffDocument {
        var unifiedLines: [DiffUnifiedLine] = []
        var splitRows: [DiffSplitRow] = []
        var oldLineNumber = 1
        var newLineNumber = 1
        var addedLineCount = 0
        var removedLineCount = 0
        var operationIndex = 0
        var rowID = 0

        while operationIndex < operations.count {
            switch operations[operationIndex] {
            case .equal(let text):
                unifiedLines.append(
                    DiffUnifiedLine(
                        id: "u-\(rowID)",
                        kind: .context,
                        oldLineNumber: oldLineNumber,
                        newLineNumber: newLineNumber,
                        text: text
                    )
                )
                splitRows.append(
                    DiffSplitRow(
                        id: "s-\(rowID)",
                        left: DiffSplitCell(lineNumber: oldLineNumber, text: text, kind: .context),
                        right: DiffSplitCell(lineNumber: newLineNumber, text: text, kind: .context)
                    )
                )
                oldLineNumber += 1
                newLineNumber += 1
                rowID += 1
                operationIndex += 1

            case .delete, .insert:
                var removedLines: [String] = []
                var addedLines: [String] = []

                while operationIndex < operations.count {
                    switch operations[operationIndex] {
                    case .delete(let text):
                        removedLines.append(text)
                        operationIndex += 1
                    case .insert(let text):
                        addedLines.append(text)
                        operationIndex += 1
                    case .equal:
                        break
                    }

                    if operationIndex < operations.count,
                       case .equal = operations[operationIndex] {
                        break
                    }
                }

                let pairCount = max(removedLines.count, addedLines.count)
                for pairIndex in 0..<pairCount {
                    let removedText = pairIndex < removedLines.count ? removedLines[pairIndex] : nil
                    let addedText = pairIndex < addedLines.count ? addedLines[pairIndex] : nil
                    let currentOldLineNumber = removedText == nil ? nil : oldLineNumber
                    let currentNewLineNumber = addedText == nil ? nil : newLineNumber

                    if let removedText {
                        unifiedLines.append(
                            DiffUnifiedLine(
                                id: "u-\(rowID)-old",
                                kind: .removed,
                                oldLineNumber: oldLineNumber,
                                newLineNumber: nil,
                                text: removedText
                            )
                        )
                        oldLineNumber += 1
                        removedLineCount += 1
                    }

                    if let addedText {
                        unifiedLines.append(
                            DiffUnifiedLine(
                                id: "u-\(rowID)-new",
                                kind: .added,
                                oldLineNumber: nil,
                                newLineNumber: newLineNumber,
                                text: addedText
                            )
                        )
                        newLineNumber += 1
                        addedLineCount += 1
                    }

                    splitRows.append(
                        DiffSplitRow(
                            id: "s-\(rowID)",
                            left: removedText.map {
                                DiffSplitCell(
                                    lineNumber: currentOldLineNumber,
                                    text: $0,
                                    kind: addedText == nil ? .removed : .changedRemoved
                                )
                            },
                            right: addedText.map {
                                DiffSplitCell(
                                    lineNumber: currentNewLineNumber,
                                    text: $0,
                                    kind: removedText == nil ? .added : .changedAdded
                                )
                            }
                        )
                    )
                    rowID += 1
                }
            }
        }

        return StructuredDiffDocument(
            unifiedLines: unifiedLines,
            splitRows: splitRows,
            addedLineCount: addedLineCount,
            removedLineCount: removedLineCount
        )
    }

    private nonisolated static func operations(oldLines: [String], newLines: [String]) -> [DiffEditOperation] {
        let rowCount = oldLines.count
        let columnCount = newLines.count
        let width = columnCount + 1
        var lcs = Array(repeating: 0, count: (rowCount + 1) * (columnCount + 1))

        if rowCount > 0 && columnCount > 0 {
            for row in 1...rowCount {
                for column in 1...columnCount {
                    let index = row * width + column
                    if oldLines[row - 1] == newLines[column - 1] {
                        lcs[index] = lcs[(row - 1) * width + (column - 1)] + 1
                    } else {
                        lcs[index] = max(
                            lcs[(row - 1) * width + column],
                            lcs[row * width + (column - 1)]
                        )
                    }
                }
            }
        }

        var row = rowCount
        var column = columnCount
        var operations: [DiffEditOperation] = []

        while row > 0 || column > 0 {
            if row > 0 && column > 0 && oldLines[row - 1] == newLines[column - 1] {
                operations.append(.equal(oldLines[row - 1]))
                row -= 1
                column -= 1
            } else if column > 0 &&
                        (row == 0 || lcs[row * width + (column - 1)] >= lcs[(row - 1) * width + column]) {
                operations.append(.insert(newLines[column - 1]))
                column -= 1
            } else if row > 0 {
                operations.append(.delete(oldLines[row - 1]))
                row -= 1
            }
        }

        return operations.reversed()
    }

    private nonisolated static func normalizedLines(in text: String) -> [String] {
        guard !text.isEmpty else { return [] }
        var lines = text.components(separatedBy: "\n")
        if text.hasSuffix("\n"), lines.last == "" {
            lines.removeLast()
        }
        return lines
    }

    private nonisolated static func parseHunkHeader(_ line: String) -> DiffPatchHunkHeader? {
        guard line.hasPrefix("@@") else { return nil }

        let body = line.dropFirst(2)
        guard let closingRange = body.range(of: "@@") else { return nil }
        let header = body[..<closingRange.lowerBound].trimmingCharacters(in: .whitespaces)
        let parts = header.split(separator: " ")
        guard parts.count >= 2 else { return nil }
        guard let oldRange = parseHunkRange(parts[0], prefix: "-"),
              let newRange = parseHunkRange(parts[1], prefix: "+") else {
            return nil
        }
        return DiffPatchHunkHeader(
            oldStart: oldRange.start,
            oldCount: oldRange.count,
            newStart: newRange.start,
            newCount: newRange.count
        )
    }

    private nonisolated static func parseHunkRange<S: StringProtocol>(
        _ value: S,
        prefix: Character
    ) -> (start: Int, count: Int)? {
        guard value.first == prefix else { return nil }
        let numbers = value.dropFirst().split(separator: ",", maxSplits: 1, omittingEmptySubsequences: false)
        guard let start = numbers.first.flatMap({ Int($0) }) else { return nil }
        let count = numbers.count > 1 ? Int(numbers[1]) ?? 1 : 1
        return (start: start, count: count)
    }
}

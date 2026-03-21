//
//  DiffRendering.swift
//  Liney
//
//  Author: wuwenrui
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
    let usesFallbackLayout: Bool
}

extension StructuredDiffDocument {
    nonisolated static func empty(usesFallbackLayout: Bool = false) -> StructuredDiffDocument {
        StructuredDiffDocument(
            unifiedLines: [],
            splitRows: [],
            addedLineCount: 0,
            removedLineCount: 0,
            usesFallbackLayout: usesFallbackLayout
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

enum DiffRenderingEngine {
    nonisolated private static let maxDynamicProgrammingCells = 250_000

    nonisolated static func render(old oldText: String, new newText: String) -> StructuredDiffDocument {
        let oldLines = normalizedLines(in: oldText)
        let newLines = normalizedLines(in: newText)

        if oldText == "<<Binary file>>" || newText == "<<Binary file>>" {
            return fallbackDocument(oldLines: oldLines, newLines: newLines)
        }

        if oldLines.count * newLines.count > maxDynamicProgrammingCells {
            return fallbackDocument(oldLines: oldLines, newLines: newLines)
        }

        let operations = operations(oldLines: oldLines, newLines: newLines)
        return makeDocument(from: operations, usesFallbackLayout: false)
    }

    private nonisolated static func makeDocument(
        from operations: [DiffEditOperation],
        usesFallbackLayout: Bool
    ) -> StructuredDiffDocument {
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
            removedLineCount: removedLineCount,
            usesFallbackLayout: usesFallbackLayout
        )
    }

    private nonisolated static func fallbackDocument(
        oldLines: [String],
        newLines: [String]
    ) -> StructuredDiffDocument {
        let operations = oldLines.map(DiffEditOperation.delete) + newLines.map(DiffEditOperation.insert)
        return makeDocument(from: operations, usesFallbackLayout: true)
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
}

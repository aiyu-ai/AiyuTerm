//
//  DiffWindowState.swift
//  Liney
//
//  Author: wuwenrui
//

import Combine
import Foundation

struct DiffFileDocument: Sendable {
    let file: DiffChangedFile
    let oldContents: String
    let newContents: String
    let unifiedPatch: String
    let renderedDiff: StructuredDiffDocument
    let isPatchOnly: Bool
    let supportsFullFileExpansion: Bool
}

enum DiffDiagnostics {
    nonisolated static func log(_ message: String) {
#if DEBUG
        print("[Diff] \(message)")
#endif
    }

    nonisolated static func error(_ message: String) {
#if DEBUG
        print("[Diff][Error] \(message)")
#endif
    }

    nonisolated static func now() -> UInt64 {
        DispatchTime.now().uptimeNanoseconds
    }

    nonisolated static func elapsedMilliseconds(since start: UInt64) -> Double {
        Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000
    }

    nonisolated static func formatMilliseconds(_ value: Double) -> String {
        String(format: "%.1fms", value)
    }

    nonisolated static func describeText(_ text: String) -> String {
        "\(text.utf8.count)B/\(lineCount(in: text)) lines"
    }

    nonisolated static func lineCount(in text: String) -> Int {
        guard !text.isEmpty else { return 0 }
        return text.split(separator: "\n", omittingEmptySubsequences: false).count
    }
}

@MainActor
final class DiffWindowState: ObservableObject {
    nonisolated private static let documentLoadTimeoutNanoseconds: UInt64 = 4_000_000_000
    nonisolated private static let patchPreferredPatchByteThreshold = 128 * 1_024
    nonisolated private static let patchPreferredFileByteThreshold = 256 * 1_024
    nonisolated private static let patchPreferredMaxHunkSpan = 400
    nonisolated private static let patchPreferredTotalHunkSpan = 800
    nonisolated private static let patchPreferredTouchedLineThreshold = 2_000

    @Published var worktreePath: String?
    @Published var branchName: String = ""
    @Published var emptyStateMessage: String = "Working directory is clean."
    @Published var changedFiles: [DiffChangedFile] = []
    @Published var selectedFileID: String?
    @Published var document: DiffFileDocument?
    @Published var isLoadingFiles = false
    @Published var isLoadingDocument = false
    @Published var loadErrorMessage: String?

    private let gitRepositoryService = GitRepositoryService()
    private var documentCache: [String: DiffFileDocument] = [:]
    private var fileListTask: Task<Void, Never>?
    private var documentTask: Task<Void, Never>?

    func load(worktreePath: String?, branchName: String, emptyStateMessage: String) {
        DiffDiagnostics.log("Loading diff window state for branch \(branchName) at \(worktreePath ?? "<nil>")")
        self.worktreePath = worktreePath
        self.branchName = branchName
        self.emptyStateMessage = emptyStateMessage
        changedFiles = []
        selectedFileID = nil
        document = nil
        loadErrorMessage = nil
        documentCache = [:]
        fileListTask?.cancel()
        documentTask?.cancel()
        guard let worktreePath else {
            isLoadingFiles = false
            isLoadingDocument = false
            return
        }
        fileListTask = Task { await reloadFileList(for: worktreePath) }
    }

    func refresh() {
        guard let worktreePath else { return }
        DiffDiagnostics.log("Refreshing diff file list for \(worktreePath)")
        documentCache = [:]
        fileListTask?.cancel()
        documentTask?.cancel()
        fileListTask = Task { await reloadFileList(for: worktreePath) }
    }

    func updateDocumentSelection(for id: String?) {
        documentTask?.cancel()
        DiffDiagnostics.log("Selecting diff file id \(id ?? "<nil>")")

        guard let id,
              let worktreePath,
              let file = changedFiles.first(where: { $0.id == id }) else {
            DiffDiagnostics.log("Clearing diff document because selection is empty or missing")
            document = nil
            isLoadingDocument = false
            return
        }

        if let cached = documentCache[id] {
            DiffDiagnostics.log("Using cached diff document for \(file.displayPath)")
            document = cached
            isLoadingDocument = false
            return
        }

        document = nil
        isLoadingDocument = true
        documentTask = Task {
            let start = DiffDiagnostics.now()
            DiffDiagnostics.log("Starting diff load for \(file.displayPath)")
            do {
                let loadedDocument = try await Task.detached(priority: .userInitiated) {
                    try await Self.loadDocumentWithTimeout(for: file, worktreePath: worktreePath)
                }.value
                guard !Task.isCancelled else { return }
                documentCache[file.id] = loadedDocument
                document = loadedDocument
                isLoadingDocument = false
                DiffDiagnostics.log(
                    "Finished diff load for \(file.displayPath) in \(DiffDiagnostics.formatMilliseconds(DiffDiagnostics.elapsedMilliseconds(since: start))) [patchOnly=\(loadedDocument.isPatchOnly)]"
                )
            } catch {
                guard !Task.isCancelled else { return }
                DiffDiagnostics.error(
                    "Diff load failed for \(file.displayPath) after \(DiffDiagnostics.formatMilliseconds(DiffDiagnostics.elapsedMilliseconds(since: start))): \(error.localizedDescription)"
                )
                document = Self.makePatchOnlyDocument(
                    file: file,
                    unifiedPatch: error.localizedDescription.nonEmptyOrFallback("Unable to load diff."),
                    reason: nil
                )
                isLoadingDocument = false
            }
        }
    }

    private func reloadFileList(for worktreePath: String) async {
        let start = DiffDiagnostics.now()
        DiffDiagnostics.log("Loading changed files for \(worktreePath)")
        isLoadingFiles = true
        loadErrorMessage = nil

        do {
            async let trackedOutput = gitRepositoryService.diffNameStatus(for: worktreePath)
            async let untrackedPaths = gitRepositoryService.untrackedFilePaths(for: worktreePath)

            let trackedFiles = DiffChangedFile.parseNameStatus(try await trackedOutput)
            let untrackedFiles = try await untrackedPaths.map {
                DiffChangedFile(status: .added, oldPath: nil, newPath: $0)
            }

            let allFiles = (trackedFiles + untrackedFiles).sorted {
                $0.displayPath.localizedStandardCompare($1.displayPath) == .orderedAscending
            }

            guard !Task.isCancelled else { return }

            changedFiles = allFiles
            isLoadingFiles = false
            DiffDiagnostics.log(
                "Loaded \(allFiles.count) changed files in \(DiffDiagnostics.formatMilliseconds(DiffDiagnostics.elapsedMilliseconds(since: start)))"
            )

            if let selectedFileID,
               allFiles.contains(where: { $0.id == selectedFileID }) {
                updateDocumentSelection(for: selectedFileID)
            } else {
                let nextSelectionID = allFiles.first?.id
                selectedFileID = nextSelectionID
                updateDocumentSelection(for: nextSelectionID)
            }
        } catch {
            guard !Task.isCancelled else { return }
            DiffDiagnostics.error(
                "Loading changed files failed after \(DiffDiagnostics.formatMilliseconds(DiffDiagnostics.elapsedMilliseconds(since: start))): \(error.localizedDescription)"
            )
            changedFiles = []
            document = nil
            selectedFileID = nil
            isLoadingFiles = false
            isLoadingDocument = false
            loadErrorMessage = error.localizedDescription.nonEmptyOrFallback("Unable to load diff.")
        }
    }

    nonisolated private static func loadDocument(for file: DiffChangedFile, worktreePath: String) async throws -> DiffFileDocument {
        let gitRepositoryService = GitRepositoryService()
        let start = DiffDiagnostics.now()
        let preloadedUnifiedPatch = try await preloadUnifiedPatch(for: file, worktreePath: worktreePath)

        if let preloadedUnifiedPatch,
           let patchRenderedDiff = DiffRenderingEngine.renderPatch(preloadedUnifiedPatch, debugLabel: file.displayPath) {
            async let headFileSize = estimatedHeadFileSize(for: file, worktreePath: worktreePath)
            async let worktreeFileSize = estimatedWorktreeFileSize(for: file, worktreePath: worktreePath)
            let patchAnalysis = DiffRenderingEngine.analyzePatch(preloadedUnifiedPatch)
            let preferenceReasons = patchRenderingPreferenceReasons(
                analysis: patchAnalysis,
                patchByteCount: preloadedUnifiedPatch.utf8.count,
                estimatedOldFileSize: await headFileSize,
                estimatedNewFileSize: await worktreeFileSize
            )

            if !preferenceReasons.isEmpty {
                DiffDiagnostics.log(
                    "Prefer patch rendering for \(file.displayPath): \(preferenceReasons.joined(separator: ", "))"
                )
                return makeStructuredPatchDocument(
                    file: file,
                    unifiedPatch: preloadedUnifiedPatch,
                    renderedDiff: patchRenderedDiff
                )
            }
        }

        let oldContents: String
        let newContents: String

        switch file.status {
        case .added:
            oldContents = ""
            newContents = Self.readFile(at: URL(fileURLWithPath: worktreePath).appendingPathComponent(file.displayPath))
        case .deleted:
            let headLoadStart = DiffDiagnostics.now()
            DiffDiagnostics.log("Loading HEAD contents for deleted file \(file.displayPath)")
            oldContents = try await gitRepositoryService.showFileAtHEAD(file.oldPath ?? file.displayPath, in: worktreePath) ?? ""
            DiffDiagnostics.log(
                "Loaded HEAD contents for deleted file \(file.displayPath) in \(DiffDiagnostics.formatMilliseconds(DiffDiagnostics.elapsedMilliseconds(since: headLoadStart))) [\(DiffDiagnostics.describeText(oldContents))]"
            )
            newContents = ""
        case .renamed, .copied, .modified, .unknown:
            let oldPath = file.oldPath ?? file.displayPath
            let newPath = file.newPath ?? file.displayPath
            let headLoadStart = DiffDiagnostics.now()
            DiffDiagnostics.log("Loading HEAD contents for \(oldPath)")
            oldContents = try await gitRepositoryService.showFileAtHEAD(oldPath, in: worktreePath) ?? ""
            DiffDiagnostics.log(
                "Loaded HEAD contents for \(oldPath) in \(DiffDiagnostics.formatMilliseconds(DiffDiagnostics.elapsedMilliseconds(since: headLoadStart))) [\(DiffDiagnostics.describeText(oldContents))]"
            )
            newContents = Self.readFile(at: URL(fileURLWithPath: worktreePath).appendingPathComponent(newPath))
        }

        let unifiedPatch = try await loadUnifiedPatch(
            for: file,
            worktreePath: worktreePath,
            oldContents: oldContents,
            newContents: newContents,
            preloadedPatch: preloadedUnifiedPatch
        )
        let renderStart = DiffDiagnostics.now()
        let renderResult = DiffRenderingEngine.render(old: oldContents, new: newContents, debugLabel: file.displayPath)
        DiffDiagnostics.log(
            "Completed document assembly for \(file.displayPath) in \(DiffDiagnostics.formatMilliseconds(DiffDiagnostics.elapsedMilliseconds(since: start))) [old=\(DiffDiagnostics.describeText(oldContents)), new=\(DiffDiagnostics.describeText(newContents)), patch=\(unifiedPatch.utf8.count)B]"
        )

        return makeDocument(
            file: file,
            oldContents: oldContents,
            newContents: newContents,
            unifiedPatch: unifiedPatch,
            renderResult: renderResult,
            renderElapsedMilliseconds: DiffDiagnostics.elapsedMilliseconds(since: renderStart)
        )
    }

    nonisolated private static func loadDocumentWithTimeout(
        for file: DiffChangedFile,
        worktreePath: String
    ) async throws -> DiffFileDocument {
        let start = DiffDiagnostics.now()
        let timeoutNanoseconds = documentLoadTimeoutNanoseconds
        DiffDiagnostics.log("Starting timed diff load for \(file.displayPath)")
        return try await withThrowingTaskGroup(of: DiffFileDocument.self) { group in
            group.addTask {
                try await loadDocument(for: file, worktreePath: worktreePath)
            }
            group.addTask {
                try await Task.sleep(nanoseconds: timeoutNanoseconds)
                DiffDiagnostics.log(
                    "Structured diff timed out for \(file.displayPath) after \(DiffDiagnostics.formatMilliseconds(Double(timeoutNanoseconds) / 1_000_000))"
                )
                return try await loadPatchOnlyDocument(
                    for: file,
                    worktreePath: worktreePath,
                    reason: "Structured diff timed out. Showing raw patch."
                )
            }

            guard let first = try await group.next() else {
                throw CancellationError()
            }
            group.cancelAll()
            DiffDiagnostics.log(
                "Timed diff load finished for \(file.displayPath) in \(DiffDiagnostics.formatMilliseconds(DiffDiagnostics.elapsedMilliseconds(since: start))) [patchOnly=\(first.isPatchOnly)]"
            )
            return first
        }
    }

    nonisolated private static func loadUnifiedPatch(
        for file: DiffChangedFile,
        worktreePath: String,
        oldContents: String,
        newContents: String,
        preloadedPatch: String? = nil
    ) async throws -> String {
        if let preloadedPatch {
            return preloadedPatch
        }

        let gitRepositoryService = GitRepositoryService()
        if file.status == .added, file.oldPath == nil {
            DiffDiagnostics.log("Using synthetic patch for added file \(file.displayPath)")
            return Self.syntheticPatch(for: file, oldContents: oldContents, newContents: newContents)
        }

        let diffPath = file.newPath ?? file.oldPath ?? file.displayPath
        let start = DiffDiagnostics.now()
        DiffDiagnostics.log("Loading git patch for \(diffPath)")
        let patch = try await gitRepositoryService.diffPatch(for: worktreePath, filePath: diffPath)
        DiffDiagnostics.log(
            "Loaded git patch for \(diffPath) in \(DiffDiagnostics.formatMilliseconds(DiffDiagnostics.elapsedMilliseconds(since: start))) [\(patch.utf8.count)B]"
        )
        return patch.nilIfEmpty ?? Self.syntheticPatch(for: file, oldContents: oldContents, newContents: newContents)
    }

    nonisolated private static func loadPatchOnlyDocument(
        for file: DiffChangedFile,
        worktreePath: String,
        reason: String?
    ) async throws -> DiffFileDocument {
        let start = DiffDiagnostics.now()
        DiffDiagnostics.log("Loading patch-only fallback for \(file.displayPath)")
        let patch: String

        if file.status == .added, file.oldPath == nil {
            let newContents = Self.readFile(at: URL(fileURLWithPath: worktreePath).appendingPathComponent(file.displayPath))
            patch = Self.syntheticPatch(for: file, oldContents: "", newContents: newContents)
        } else if file.status == .deleted {
            let gitRepositoryService = GitRepositoryService()
            let oldContents = try await gitRepositoryService.showFileAtHEAD(file.oldPath ?? file.displayPath, in: worktreePath) ?? ""
            patch = Self.syntheticPatch(for: file, oldContents: oldContents, newContents: "")
        } else {
            let gitRepositoryService = GitRepositoryService()
            let diffPath = file.newPath ?? file.oldPath ?? file.displayPath
            let rawPatch = try await gitRepositoryService.diffPatch(for: worktreePath, filePath: diffPath)
            patch = rawPatch.nilIfEmpty ?? "No unified patch available for \(file.displayPath)."
        }

        DiffDiagnostics.log(
            "Loaded patch-only fallback for \(file.displayPath) in \(DiffDiagnostics.formatMilliseconds(DiffDiagnostics.elapsedMilliseconds(since: start))) [\(patch.utf8.count)B]"
        )

        return makePatchOnlyDocument(file: file, unifiedPatch: patch, reason: reason)
    }

    nonisolated static func makeDocument(
        file: DiffChangedFile,
        oldContents: String,
        newContents: String,
        unifiedPatch: String,
        renderResult: DiffRenderingResult,
        renderElapsedMilliseconds: Double
    ) -> DiffFileDocument {
        switch renderResult {
        case .document(let renderedDiff):
            DiffDiagnostics.log(
                "Rendered structured diff for \(file.displayPath) in \(DiffDiagnostics.formatMilliseconds(renderElapsedMilliseconds)) [added=\(renderedDiff.addedLineCount), removed=\(renderedDiff.removedLineCount)]"
            )
            return DiffFileDocument(
                file: file,
                oldContents: oldContents,
                newContents: newContents,
                unifiedPatch: unifiedPatch,
                renderedDiff: renderedDiff,
                isPatchOnly: false,
                supportsFullFileExpansion: true
            )
        case .requiresPatchFallback(let reason):
            if let renderedDiff = DiffRenderingEngine.renderPatch(unifiedPatch, debugLabel: file.displayPath) {
                DiffDiagnostics.log(
                    "Structured diff switched to patch hunks for \(file.displayPath) in \(DiffDiagnostics.formatMilliseconds(renderElapsedMilliseconds)): \(reason)"
                )
                return makeStructuredPatchDocument(file: file, unifiedPatch: unifiedPatch, renderedDiff: renderedDiff)
            } else {
                DiffDiagnostics.log(
                    "Structured diff switched to patch-only for \(file.displayPath) in \(DiffDiagnostics.formatMilliseconds(renderElapsedMilliseconds)): \(reason)"
                )
                return makePatchOnlyDocument(
                    file: file,
                    unifiedPatch: unifiedPatch,
                    reason: "\(reason) Showing raw patch."
                )
            }
        }
    }

    nonisolated private static func makePatchOnlyDocument(
        file: DiffChangedFile,
        unifiedPatch: String,
        reason: String?
    ) -> DiffFileDocument {
        let annotatedPatch: String
        if let reason, !reason.isEmpty {
            annotatedPatch = "\(reason)\n\n\(unifiedPatch)"
        } else {
            annotatedPatch = unifiedPatch
        }

        return DiffFileDocument(
            file: file,
            oldContents: "",
            newContents: "",
            unifiedPatch: annotatedPatch,
            renderedDiff: .empty(),
            isPatchOnly: true,
            supportsFullFileExpansion: false
        )
    }

    nonisolated private static func makeStructuredPatchDocument(
        file: DiffChangedFile,
        unifiedPatch: String,
        renderedDiff: StructuredDiffDocument
    ) -> DiffFileDocument {
        DiffFileDocument(
            file: file,
            oldContents: "",
            newContents: "",
            unifiedPatch: unifiedPatch,
            renderedDiff: renderedDiff,
            isPatchOnly: false,
            supportsFullFileExpansion: false
        )
    }

    nonisolated private static func readFile(at url: URL) -> String {
        let start = DiffDiagnostics.now()
        guard let data = try? Data(contentsOf: url) else {
            DiffDiagnostics.error("Reading file failed for \(url.path)")
            return ""
        }
        if data.contains(0) {
            DiffDiagnostics.log(
                "Read binary file \(url.path) in \(DiffDiagnostics.formatMilliseconds(DiffDiagnostics.elapsedMilliseconds(since: start))) [\(data.count)B]"
            )
            return "<<Binary file>>"
        }
        if let string = String(data: data, encoding: .utf8) {
            DiffDiagnostics.log(
                "Read file \(url.path) in \(DiffDiagnostics.formatMilliseconds(DiffDiagnostics.elapsedMilliseconds(since: start))) [\(data.count)B/\(DiffDiagnostics.lineCount(in: string)) lines]"
            )
            return string
        }
        let string = String(decoding: data, as: UTF8.self)
        DiffDiagnostics.log(
            "Read non-UTF8 file \(url.path) in \(DiffDiagnostics.formatMilliseconds(DiffDiagnostics.elapsedMilliseconds(since: start))) [\(data.count)B/\(DiffDiagnostics.lineCount(in: string)) lines]"
        )
        return string
    }

    nonisolated private static func syntheticPatch(
        for file: DiffChangedFile,
        oldContents: String,
        newContents: String
    ) -> String {
        let path = file.displayPath
        switch file.status {
        case .added:
            return """
            diff --git a/\(path) b/\(path)
            --- /dev/null
            +++ b/\(path)
            \(patchHunk(oldPrefixCount: 0, newPrefixCount: lineCount(in: newContents), contents: newContents, prefix: "+"))
            """
        case .deleted:
            return """
            diff --git a/\(path) b/\(path)
            --- a/\(path)
            +++ /dev/null
            \(patchHunk(oldPrefixCount: lineCount(in: oldContents), newPrefixCount: 0, contents: oldContents, prefix: "-"))
            """
        default:
            return "No unified patch available for \(path)."
        }
    }

    nonisolated private static func patchHunk(
        oldPrefixCount: Int,
        newPrefixCount: Int,
        contents: String,
        prefix: Character
    ) -> String {
        let lines = contents.split(separator: "\n", omittingEmptySubsequences: false)
        let body = lines.map { "\(prefix)\($0)" }.joined(separator: "\n")
        let oldStart = oldPrefixCount == 0 ? 0 : 1
        let newStart = newPrefixCount == 0 ? 0 : 1
        return "@@ -\(oldStart),\(oldPrefixCount) +\(newStart),\(newPrefixCount) @@\n\(body)"
    }

    nonisolated private static func lineCount(in text: String) -> Int {
        DiffDiagnostics.lineCount(in: text)
    }

    nonisolated private static func preloadUnifiedPatch(for file: DiffChangedFile, worktreePath: String) async throws -> String? {
        guard !(file.status == .added && file.oldPath == nil) else {
            return nil
        }

        let gitRepositoryService = GitRepositoryService()
        let diffPath = file.newPath ?? file.oldPath ?? file.displayPath
        let start = DiffDiagnostics.now()
        DiffDiagnostics.log("Preloading git patch for \(diffPath)")
        let patch = try await gitRepositoryService.diffPatch(for: worktreePath, filePath: diffPath)
        DiffDiagnostics.log(
            "Preloaded git patch for \(diffPath) in \(DiffDiagnostics.formatMilliseconds(DiffDiagnostics.elapsedMilliseconds(since: start))) [\(patch.utf8.count)B]"
        )
        return patch.nilIfEmpty
    }

    nonisolated private static func estimatedHeadFileSize(for file: DiffChangedFile, worktreePath: String) async -> Int? {
        guard let path = file.oldPath ?? file.newPath else {
            return nil
        }
        let gitRepositoryService = GitRepositoryService()
        return try? await gitRepositoryService.fileSizeAtHEAD(path, in: worktreePath)
    }

    nonisolated private static func estimatedWorktreeFileSize(for file: DiffChangedFile, worktreePath: String) async -> Int? {
        guard let path = file.newPath else {
            return nil
        }
        return fileSize(at: URL(fileURLWithPath: worktreePath).appendingPathComponent(path))
    }

    nonisolated static func patchRenderingPreferenceReasons(
        analysis: DiffPatchAnalysis,
        patchByteCount: Int,
        estimatedOldFileSize: Int?,
        estimatedNewFileSize: Int?
    ) -> [String] {
        var reasons: [String] = []

        if patchByteCount >= patchPreferredPatchByteThreshold {
            reasons.append("patch \(patchByteCount)B >= \(patchPreferredPatchByteThreshold)B")
        }

        let largestFileSize = max(estimatedOldFileSize ?? 0, estimatedNewFileSize ?? 0)
        if largestFileSize >= patchPreferredFileByteThreshold {
            reasons.append("file \(largestFileSize)B >= \(patchPreferredFileByteThreshold)B")
        }

        if analysis.maxSpan >= patchPreferredMaxHunkSpan {
            reasons.append("max hunk span \(analysis.maxSpan) >= \(patchPreferredMaxHunkSpan)")
        }

        if analysis.totalSpan >= patchPreferredTotalHunkSpan {
            reasons.append("total hunk span \(analysis.totalSpan) >= \(patchPreferredTotalHunkSpan)")
        }

        let maxTouchedLine = max(analysis.maxTouchedOldLine, analysis.maxTouchedNewLine)
        if maxTouchedLine >= patchPreferredTouchedLineThreshold {
            reasons.append("touched line \(maxTouchedLine) >= \(patchPreferredTouchedLineThreshold)")
        }

        return reasons
    }

    nonisolated private static func fileSize(at url: URL) -> Int? {
        guard let values = try? url.resourceValues(forKeys: [.fileSizeKey]) else {
            return nil
        }
        return values.fileSize
    }
}

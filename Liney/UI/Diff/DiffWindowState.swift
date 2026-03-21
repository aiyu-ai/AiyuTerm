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
}

@MainActor
final class DiffWindowState: ObservableObject {
    private static let documentLoadTimeoutNanoseconds: UInt64 = 4_000_000_000

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
        documentCache = [:]
        fileListTask?.cancel()
        documentTask?.cancel()
        fileListTask = Task { await reloadFileList(for: worktreePath) }
    }

    func updateDocumentSelection(for id: String?) {
        documentTask?.cancel()

        guard let id,
              let worktreePath,
              let file = changedFiles.first(where: { $0.id == id }) else {
            document = nil
            isLoadingDocument = false
            return
        }

        if let cached = documentCache[id] {
            document = cached
            isLoadingDocument = false
            return
        }

        document = nil
        isLoadingDocument = true
        documentTask = Task {
            do {
                let loadedDocument = try await Task.detached(priority: .userInitiated) {
                    try await Self.loadDocumentWithTimeout(for: file, worktreePath: worktreePath)
                }.value
                guard !Task.isCancelled else { return }
                documentCache[file.id] = loadedDocument
                document = loadedDocument
                isLoadingDocument = false
            } catch {
                guard !Task.isCancelled else { return }
                document = DiffFileDocument(
                    file: file,
                    oldContents: "",
                    newContents: "",
                    unifiedPatch: error.localizedDescription.nonEmptyOrFallback("Unable to load diff."),
                    renderedDiff: .empty(),
                    isPatchOnly: true
                )
                isLoadingDocument = false
            }
        }
    }

    private func reloadFileList(for worktreePath: String) async {
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
        let oldContents: String
        let newContents: String

        switch file.status {
        case .added:
            oldContents = ""
            newContents = Self.readFile(at: URL(fileURLWithPath: worktreePath).appendingPathComponent(file.displayPath))
        case .deleted:
            oldContents = try await gitRepositoryService.showFileAtHEAD(file.oldPath ?? file.displayPath, in: worktreePath) ?? ""
            newContents = ""
        case .renamed, .copied, .modified, .unknown:
            let oldPath = file.oldPath ?? file.displayPath
            let newPath = file.newPath ?? file.displayPath
            oldContents = try await gitRepositoryService.showFileAtHEAD(oldPath, in: worktreePath) ?? ""
            newContents = Self.readFile(at: URL(fileURLWithPath: worktreePath).appendingPathComponent(newPath))
        }

        let unifiedPatch = try await loadUnifiedPatch(for: file, worktreePath: worktreePath, oldContents: oldContents, newContents: newContents)

        return DiffFileDocument(
            file: file,
            oldContents: oldContents,
            newContents: newContents,
            unifiedPatch: unifiedPatch,
            renderedDiff: DiffRenderingEngine.render(old: oldContents, new: newContents),
            isPatchOnly: false
        )
    }

    nonisolated private static func loadDocumentWithTimeout(
        for file: DiffChangedFile,
        worktreePath: String
    ) async throws -> DiffFileDocument {
        try await withThrowingTaskGroup(of: DiffFileDocument.self) { group in
            group.addTask {
                try await loadDocument(for: file, worktreePath: worktreePath)
            }
            group.addTask {
                try await Task.sleep(nanoseconds: documentLoadTimeoutNanoseconds)
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
            return first
        }
    }

    nonisolated private static func loadUnifiedPatch(
        for file: DiffChangedFile,
        worktreePath: String,
        oldContents: String,
        newContents: String
    ) async throws -> String {
        let gitRepositoryService = GitRepositoryService()
        if file.status == .added, file.oldPath == nil {
            return Self.syntheticPatch(for: file, oldContents: oldContents, newContents: newContents)
        }

        let diffPath = file.newPath ?? file.oldPath ?? file.displayPath
        let patch = try await gitRepositoryService.diffPatch(for: worktreePath, filePath: diffPath)
        return patch.nilIfEmpty ?? Self.syntheticPatch(for: file, oldContents: oldContents, newContents: newContents)
    }

    nonisolated private static func loadPatchOnlyDocument(
        for file: DiffChangedFile,
        worktreePath: String,
        reason: String?
    ) async throws -> DiffFileDocument {
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

        let annotatedPatch: String
        if let reason, !reason.isEmpty {
            annotatedPatch = "\(reason)\n\n\(patch)"
        } else {
            annotatedPatch = patch
        }

        return DiffFileDocument(
            file: file,
            oldContents: "",
            newContents: "",
            unifiedPatch: annotatedPatch,
            renderedDiff: .empty(usesFallbackLayout: true),
            isPatchOnly: true
        )
    }

    nonisolated private static func readFile(at url: URL) -> String {
        guard let data = try? Data(contentsOf: url) else { return "" }
        if data.contains(0) {
            return "<<Binary file>>"
        }
        if let string = String(data: data, encoding: .utf8) {
            return string
        }
        return String(decoding: data, as: UTF8.self)
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
        let oldCount = max(oldPrefixCount, contents.isEmpty ? 0 : 1)
        let newCount = max(newPrefixCount, contents.isEmpty ? 0 : 1)
        return "@@ -1,\(oldCount) +1,\(newCount) @@\n\(body)"
    }

    nonisolated private static func lineCount(in text: String) -> Int {
        guard !text.isEmpty else { return 0 }
        return text.split(separator: "\n", omittingEmptySubsequences: false).count
    }
}

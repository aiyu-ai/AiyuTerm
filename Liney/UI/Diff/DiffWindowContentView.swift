//
//  DiffWindowContentView.swift
//  Liney
//
//  Author: wuwenrui
//

import SwiftUI
import YiTong

private enum DiffPresentationStyle: String {
    case split
    case unified
}

struct DiffWindowContentView: View {
    @ObservedObject var state: DiffWindowState
    @State private var columnVisibility: NavigationSplitViewVisibility = .automatic
    @State private var listSelection: String?
    @AppStorage("liney.diff.viewStyle") private var diffStyleRaw = DiffPresentationStyle.split.rawValue

    private var diffStyle: DiffPresentationStyle {
        DiffPresentationStyle(rawValue: diffStyleRaw) ?? .split
    }

    init(state: DiffWindowState) {
        self.state = state
        _listSelection = State(initialValue: state.selectedFileID)
    }

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            fileListSidebar
                .navigationSplitViewColumnWidth(min: 220, ideal: 280, max: 360)
        } detail: {
            diffDetail
        }
        .background(LineyTheme.appBackground)
        .onChange(of: listSelection) { _, newValue in
            guard state.selectedFileID != newValue else { return }
            state.selectedFileID = newValue
            state.updateDocumentSelection(for: newValue)
        }
        .onChange(of: state.selectedFileID) { _, newValue in
            guard listSelection != newValue else { return }
            listSelection = newValue
        }
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button {
                    toggleSidebar()
                } label: {
                    Image(systemName: "sidebar.leading")
                }
                .help("Toggle Sidebar")
            }

            ToolbarItem(placement: .primaryAction) {
                Picker("Diff Style", selection: $diffStyleRaw) {
                    Image(systemName: "square.split.2x1")
                        .tag(DiffPresentationStyle.split.rawValue)
                    Image(systemName: "text.justify.left")
                        .tag(DiffPresentationStyle.unified.rawValue)
                }
                .pickerStyle(.segmented)
                .frame(width: 110)
                .help("Diff Style")
            }

            ToolbarItem(placement: .primaryAction) {
                Button {
                    state.refresh()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .help("Refresh Diff")
            }
        }
    }

    private var fileListSidebar: some View {
        List(selection: $listSelection) {
            ForEach(state.changedFiles) { file in
                DiffFileRow(file: file)
                    .tag(file.id)
            }
        }
        .listStyle(.sidebar)
        .overlay {
            if state.isLoadingFiles && state.changedFiles.isEmpty {
                ProgressView()
            } else if let loadErrorMessage = state.loadErrorMessage {
                ContentUnavailableView(
                    "Unable to Load Changes",
                    systemImage: "exclamationmark.triangle",
                    description: Text(loadErrorMessage)
                )
            } else if !state.isLoadingFiles && state.changedFiles.isEmpty {
                ContentUnavailableView(
                    "No Changes",
                    systemImage: "checkmark.circle",
                    description: Text(state.emptyStateMessage)
                )
            }
        }
    }

    private var diffDetail: some View {
        Group {
            if state.isLoadingDocument && state.document == nil {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let document = state.document {
                VStack(spacing: 0) {
                    DiffDocumentHeader(file: document.file)
                    DiffDocumentSummary(document: document)

                    if document.isPatchOnly {
                        DiffRawPatchDocumentView(text: document.unifiedPatch)
                    } else {
                        DiffYiTongDocumentView(document: document, diffStyle: diffStyle)
                    }
                }
            } else if state.isLoadingFiles {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if state.changedFiles.isEmpty && state.loadErrorMessage == nil {
                ContentUnavailableView(
                    "No Changes",
                    systemImage: "checkmark.circle",
                    description: Text(state.emptyStateMessage)
                )
            } else {
                ContentUnavailableView(
                    "Select a File",
                    systemImage: "doc.text",
                    description: Text("Choose a changed file from the sidebar.")
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(LineyTheme.appBackground)
    }

    private func toggleSidebar() {
        withAnimation(.easeInOut(duration: 0.15)) {
            columnVisibility = columnVisibility == .detailOnly ? .automatic : .detailOnly
        }
    }
}

private struct DiffFileRow: View {
    let file: DiffChangedFile

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(file.statusSymbol)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(file.status.color)
                    .frame(width: 14)

                Text(file.displayName)
                    .lineLimit(1)

                Spacer(minLength: 8)

                if file.status == .renamed || file.status == .copied {
                    Text(file.status == .renamed ? "rename" : "copy")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(file.status.color)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(file.status.color.opacity(0.12), in: Capsule())
                }
            }

            if !file.directoryPath.isEmpty {
                Text(file.directoryPath)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(LineyTheme.mutedText)
                    .lineLimit(1)
                    .truncationMode(.head)
            }

            if let oldPath = file.oldPath, let newPath = file.newPath, oldPath != newPath {
                Text("\(oldPath) -> \(newPath)")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(LineyTheme.mutedText)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
        .padding(.vertical, 2)
    }
}

private struct DiffDocumentHeader: View {
    let file: DiffChangedFile

    var body: some View {
        HStack(spacing: 10) {
            Text(file.statusSymbol)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(file.status.color)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(file.status.color.opacity(0.12), in: Capsule())

            VStack(alignment: .leading, spacing: 3) {
                Text(file.displayName)
                    .font(.system(size: 14, weight: .semibold))
                if !file.directoryPath.isEmpty {
                    Text(file.directoryPath)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(LineyTheme.mutedText)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(LineyTheme.chromeBackground.opacity(0.96))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(LineyTheme.border)
                .frame(height: 1)
        }
    }
}

private struct DiffDocumentSummary: View {
    let document: DiffFileDocument

    var body: some View {
        HStack(spacing: 10) {
            DiffSummaryBadge(label: "+\(document.renderedDiff.addedLineCount)", tint: LineyTheme.success)
            DiffSummaryBadge(label: "-\(document.renderedDiff.removedLineCount)", tint: LineyTheme.danger)
            if document.isPatchOnly {
                DiffSummaryBadge(label: "Patch Only", tint: LineyTheme.warning)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(LineyTheme.panelBackground)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(LineyTheme.border)
                .frame(height: 1)
        }
    }
}

private struct DiffYiTongDocumentView: View {
    let document: DiffFileDocument
    let diffStyle: DiffPresentationStyle

    var body: some View {
        DiffView(
            document: yiTongDocument,
            configuration: yiTongConfiguration
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(LineyTheme.canvasBackground)
    }

    private var yiTongDocument: DiffDocument {
        if document.supportsFullFileExpansion {
            return DiffDocument(
                files: [
                    DiffFile(
                        oldPath: document.file.oldPath,
                        newPath: document.file.newPath,
                        oldContents: document.oldContents,
                        newContents: document.newContents
                    ),
                ],
                title: document.file.displayPath,
                fallbackPatch: document.unifiedPatch.nilIfEmpty
            )
        }

        return DiffDocument(
            patch: document.unifiedPatch,
            title: document.file.displayPath
        )
    }

    private var yiTongConfiguration: DiffConfiguration {
        DiffConfiguration(
            appearance: .automatic,
            style: diffStyle == .split ? .split : .unified,
            indicators: .bars,
            showsLineNumbers: true,
            showsChangeBackgrounds: true,
            wrapsLines: false,
            showsFileHeaders: false,
            inlineChangeStyle: .wordAlt,
            allowsSelection: true
        )
    }
}

private struct DiffRawPatchDocumentView: View {
    let text: String

    var body: some View {
        ScrollView([.vertical, .horizontal]) {
            Text(text.isEmpty ? "No patch available." : text)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(LineyTheme.secondaryText)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(LineyTheme.canvasBackground)
    }
}

private struct DiffSummaryBadge: View {
    let label: String
    let tint: Color

    var body: some View {
        Text(label)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(tint.opacity(0.12), in: Capsule())
            .overlay(
                Capsule()
                    .stroke(tint.opacity(0.22), lineWidth: 1)
            )
    }
}

private extension DiffFileStatus {
    var color: Color {
        switch self {
        case .modified:
            return LineyTheme.warning
        case .added:
            return LineyTheme.success
        case .deleted:
            return LineyTheme.danger
        case .renamed, .copied:
            return LineyTheme.accent
        case .unknown:
            return LineyTheme.mutedText
        }
    }
}

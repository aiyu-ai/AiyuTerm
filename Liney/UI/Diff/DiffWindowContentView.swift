//
//  DiffWindowContentView.swift
//  Liney
//
//  Author: wuwenrui
//

import SwiftUI

private enum DiffPresentationStyle: String {
    case split
    case unified
}

private enum DiffContentVisibilityMode: String {
    case changesOnly
    case fullFile
}

struct DiffWindowContentView: View {
    @ObservedObject var state: DiffWindowState
    @State private var columnVisibility: NavigationSplitViewVisibility = .automatic
    @State private var listSelection: String?
    @AppStorage("liney.diff.viewStyle") private var diffStyleRaw = DiffPresentationStyle.split.rawValue
    @AppStorage("liney.diff.contentVisibility") private var contentVisibilityRaw = DiffContentVisibilityMode.changesOnly.rawValue

    private var diffStyle: DiffPresentationStyle {
        DiffPresentationStyle(rawValue: diffStyleRaw) ?? .split
    }

    private var contentVisibility: DiffContentVisibilityMode {
        DiffContentVisibilityMode(rawValue: contentVisibilityRaw) ?? .changesOnly
    }

    private var showsFullFile: Bool {
        contentVisibility == .fullFile && (state.document?.supportsFullFileExpansion ?? false)
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
                    contentVisibilityRaw = showsFullFile
                        ? DiffContentVisibilityMode.changesOnly.rawValue
                        : DiffContentVisibilityMode.fullFile.rawValue
                } label: {
                    Image(systemName: showsFullFile ? "rectangle.compress.vertical" : "rectangle.expand.vertical")
                }
                .disabled(!(state.document?.supportsFullFileExpansion ?? false))
                .help(
                    state.document?.supportsFullFileExpansion != true
                        ? "Patch-based diff does not support full-file expansion"
                        : (showsFullFile ? "Show Diff Hunks" : "Show Full File")
                )
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
                        switch diffStyle {
                        case .split:
                            DiffSplitDocumentView(document: document, showsFullFile: showsFullFile)
                        case .unified:
                            DiffUnifiedDocumentView(document: document, showsFullFile: showsFullFile)
                        }
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

private struct DiffSplitDocumentView: View {
    let document: DiffFileDocument
    let showsFullFile: Bool
    private let minimumColumnWidth: CGFloat = 420

    var body: some View {
        GeometryReader { proxy in
            let availableWidth = max(proxy.size.width, 0)
            let columnWidth = max(minimumColumnWidth, floor(availableWidth / 2))
            let contentWidth = max(availableWidth, columnWidth * 2)
            let displayedRows = document.renderedDiff.displayedSplitRows(showsFullFile: showsFullFile)

            ScrollView([.vertical, .horizontal]) {
                LazyVStack(spacing: 0) {
                    HStack(spacing: 0) {
                        DiffSplitColumnHeader(title: "HEAD", tint: LineyTheme.danger, columnWidth: columnWidth)
                        DiffSplitColumnHeader(title: "Working Tree", tint: LineyTheme.success, columnWidth: columnWidth)
                    }

                    ForEach(displayedRows) { row in
                        HStack(spacing: 0) {
                            DiffSplitCellView(cell: row.left, columnWidth: columnWidth)
                            DiffSplitCellView(cell: row.right, columnWidth: columnWidth)
                        }
                    }
                }
                .frame(minWidth: contentWidth, maxWidth: .infinity, alignment: .topLeading)
                .frame(minHeight: proxy.size.height, alignment: .topLeading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .background(LineyTheme.canvasBackground)
    }
}

private struct DiffUnifiedDocumentView: View {
    let document: DiffFileDocument
    let showsFullFile: Bool

    var body: some View {
        GeometryReader { proxy in
            let availableWidth = max(proxy.size.width, 0)
            let displayedLines = document.renderedDiff.displayedUnifiedLines(showsFullFile: showsFullFile)

            ScrollView([.vertical, .horizontal]) {
                LazyVStack(spacing: 0) {
                    ForEach(displayedLines) { line in
                        DiffUnifiedLineRow(line: line)
                    }

                    if displayedLines.isEmpty {
                        Text(document.unifiedPatch.isEmpty ? "No visible changes." : document.unifiedPatch)
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundStyle(LineyTheme.secondaryText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(14)
                    }
                }
                .frame(minWidth: availableWidth, maxWidth: .infinity, alignment: .topLeading)
                .frame(minHeight: proxy.size.height, alignment: .topLeading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .background(LineyTheme.canvasBackground)
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

private struct DiffSplitColumnHeader: View {
    let title: String
    let tint: Color
    let columnWidth: CGFloat

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(tint)
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(minWidth: columnWidth, alignment: .leading)
        .background(LineyTheme.panelBackground)
        .overlay(alignment: .bottomTrailing) {
            Rectangle()
                .fill(LineyTheme.border)
                .frame(width: 1)
        }
    }
}

private struct DiffSplitCellView: View {
    let cell: DiffSplitCell?
    let columnWidth: CGFloat

    var body: some View {
        HStack(spacing: 0) {
            Text(cell?.lineNumber.map(String.init) ?? "")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(LineyTheme.mutedText)
                .frame(width: 52, alignment: .trailing)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(backgroundColor.opacity(0.78))

            Rectangle()
                .fill(LineyTheme.border)
                .frame(width: 1)

            Text(cell?.text.isEmpty == false ? cell?.text ?? "" : " ")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(labelColor)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(backgroundColor)
        }
        .frame(minWidth: columnWidth, alignment: .leading)
        .overlay(alignment: .bottomTrailing) {
            Rectangle()
                .fill(LineyTheme.border.opacity(0.65))
                .frame(height: 1)
        }
    }

    private var backgroundColor: Color {
        guard let cell else { return LineyTheme.canvasBackground }
        switch cell.kind {
        case .context:
            return LineyTheme.canvasBackground
        case .added:
            return LineyTheme.success.opacity(0.14)
        case .removed:
            return LineyTheme.danger.opacity(0.14)
        case .changedAdded:
            return LineyTheme.success.opacity(0.18)
        case .changedRemoved:
            return LineyTheme.warning.opacity(0.16)
        }
    }

    private var labelColor: Color {
        guard let cell else { return LineyTheme.secondaryText }
        switch cell.kind {
        case .context:
            return LineyTheme.secondaryText
        case .added, .changedAdded, .removed, .changedRemoved:
            return .white
        }
    }
}

private struct DiffUnifiedLineRow: View {
    let line: DiffUnifiedLine

    var body: some View {
        HStack(spacing: 0) {
            Text(prefix)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(prefixColor)
                .frame(width: 20, alignment: .center)
                .padding(.vertical, 4)
                .background(backgroundColor)

            Text(line.oldLineNumber.map(String.init) ?? "")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(LineyTheme.mutedText)
                .frame(width: 56, alignment: .trailing)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(backgroundColor)

            Text(line.newLineNumber.map(String.init) ?? "")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(LineyTheme.mutedText)
                .frame(width: 56, alignment: .trailing)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(backgroundColor)

            Rectangle()
                .fill(LineyTheme.border)
                .frame(width: 1)

            Text(line.text.isEmpty ? " " : line.text)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(LineyTheme.secondaryText)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(backgroundColor)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(LineyTheme.border.opacity(0.65))
                .frame(height: 1)
        }
    }

    private var prefix: String {
        switch line.kind {
        case .context:
            return " "
        case .added:
            return "+"
        case .removed:
            return "-"
        }
    }

    private var backgroundColor: Color {
        switch line.kind {
        case .context:
            return LineyTheme.canvasBackground
        case .added:
            return LineyTheme.success.opacity(0.15)
        case .removed:
            return LineyTheme.danger.opacity(0.15)
        }
    }

    private var prefixColor: Color {
        switch line.kind {
        case .context:
            return LineyTheme.mutedText
        case .added:
            return LineyTheme.success
        case .removed:
            return LineyTheme.danger
        }
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

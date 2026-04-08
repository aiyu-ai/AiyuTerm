//
//  SplitNodeView.swift
//  AiyuTerm
//
//  Author: wuwenrui
//

import SwiftUI

struct SplitNodeView: View {
    @ObservedObject var workspace: WorkspaceModel
    @ObservedObject var sessionController: WorkspaceSessionController
    let node: SessionLayoutNode

    var body: some View {
        Group {
            if let zoomedPaneID = workspace.zoomedPaneID {
                if let session = sessionController.session(for: zoomedPaneID) {
                    TerminalPaneView(workspace: workspace, sessionController: sessionController, session: session, paneID: zoomedPaneID)
                } else {
                    Color.clear
                }
            } else {
                switch node {
                case .pane(let leaf):
                    if let session = sessionController.session(for: leaf.paneID) {
                        TerminalPaneView(workspace: workspace, sessionController: sessionController, session: session, paneID: leaf.paneID)
                    } else {
                        Color.clear
                    }
                case .split(let split):
                    GeometryReader { geometry in
                        splitBody(split, in: geometry.size)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func splitBody(_ split: PaneSplitNode, in size: CGSize) -> some View {
        let dividerThickness: CGFloat = 6
        let clampedFraction = min(max(split.fraction, 0.12), 0.88)
        let availableWidth = max(size.width - dividerThickness, 1)
        let availableHeight = max(size.height - dividerThickness, 1)
        let splitSpace = "split_\(split.id)"

        if split.axis == .vertical {
            let firstWidth = max(120, availableWidth * clampedFraction)
            let secondWidth = max(120, availableWidth - firstWidth)

            HStack(spacing: 0) {
                SplitNodeView(workspace: workspace, sessionController: sessionController, node: split.first)
                    .frame(width: firstWidth)
                SplitDivider(
                    axis: .vertical,
                    availableLength: availableWidth,
                    coordinateSpaceName: splitSpace
                ) { fraction in
                    workspace.updateSplitFraction(splitID: split.id, fraction: fraction)
                }
                    .frame(width: dividerThickness)
                SplitNodeView(workspace: workspace, sessionController: sessionController, node: split.second)
                    .frame(width: secondWidth)
            }
            .coordinateSpace(name: splitSpace)
        } else {
            let firstHeight = max(90, availableHeight * clampedFraction)
            let secondHeight = max(90, availableHeight - firstHeight)

            VStack(spacing: 0) {
                SplitNodeView(workspace: workspace, sessionController: sessionController, node: split.first)
                    .frame(height: firstHeight)
                SplitDivider(
                    axis: .horizontal,
                    availableLength: availableHeight,
                    coordinateSpaceName: splitSpace
                ) { fraction in
                    workspace.updateSplitFraction(splitID: split.id, fraction: fraction)
                }
                    .frame(height: dividerThickness)
                SplitNodeView(workspace: workspace, sessionController: sessionController, node: split.second)
                    .frame(height: secondHeight)
            }
            .coordinateSpace(name: splitSpace)
        }
    }
}

private struct SplitDivider: View {
    let axis: PaneSplitAxis
    let availableLength: CGFloat
    let coordinateSpaceName: String
    let onUpdate: (Double) -> Void

    @State private var isHovered = false
    @State private var isDragging = false

    private var isActive: Bool { isHovered || isDragging }

    private static let accentBlue = Color(nsColor: .controlAccentColor)

    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color.clear)

            Rectangle()
                .fill(isActive ? Self.accentBlue : AiyuTermTheme.strongBorder)
                .frame(width: axis == .vertical ? 1.5 : nil, height: axis == .horizontal ? 1.5 : nil)

            Capsule(style: .continuous)
                .fill(Self.accentBlue)
                .overlay(
                    Capsule(style: .continuous)
                        .strokeBorder(Self.accentBlue.opacity(0.6), lineWidth: 1)
                )
                .frame(
                    width: axis == .vertical ? 8 : 36,
                    height: axis == .horizontal ? 8 : 36
                )
                .shadow(color: Self.accentBlue.opacity(0.4), radius: 3, x: 0, y: 0)
                .opacity(isActive ? 1 : 0)
        }
        .contentShape(Rectangle())
        .background(
            ResizeCursorView(axis: axis)
                .allowsHitTesting(false)
        )
        .onHover { hovering in
            isHovered = hovering
        }
        .gesture(
            DragGesture(minimumDistance: 1, coordinateSpace: .named(coordinateSpaceName))
                .onChanged { value in
                    if !isDragging { isDragging = true }
                    let position = axis == .vertical ? value.location.x : value.location.y
                    let fraction = position / max(availableLength, 1)
                    onUpdate(fraction)
                }
                .onEnded { _ in
                    isDragging = false
                }
        )
    }
}

private struct ResizeCursorView: NSViewRepresentable {
    let axis: PaneSplitAxis

    func makeNSView(context: Context) -> ResizeCursorNSView {
        let view = ResizeCursorNSView()
        view.axis = axis
        return view
    }

    func updateNSView(_ nsView: ResizeCursorNSView, context: Context) {
        nsView.axis = axis
    }
}

private final class ResizeCursorNSView: NSView {
    var axis: PaneSplitAxis = .vertical {
        didSet { resetCursorRects() }
    }

    override func resetCursorRects() {
        discardCursorRects()
        let cursor: NSCursor = axis == .vertical ? .resizeLeftRight : .resizeUpDown
        addCursorRect(bounds, cursor: cursor)
    }
}

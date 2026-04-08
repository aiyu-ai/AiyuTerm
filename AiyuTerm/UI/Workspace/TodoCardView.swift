//
//  TodoCardView.swift
//  AiyuTerm
//
//  Author: wuwenrui
//

import Combine
import SwiftUI

// MARK: - Compact Badge

struct TodoCardBadge: View {
    let count: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 10, weight: .semibold))
                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                }
            }
            .foregroundStyle(count > 0 ? AiyuTermTheme.accent : AiyuTermTheme.mutedText)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                AiyuTermTheme.panelRaised.opacity(0.9),
                in: Capsule()
            )
            .overlay(
                Capsule()
                    .stroke(count > 0 ? AiyuTermTheme.accent.opacity(0.42) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .help("Todo")
    }
}

// MARK: - Expanded Card

struct TodoCardView: View {
    @ObservedObject var workspace: WorkspaceModel
    @State private var editingItemID: UUID?
    @State private var newItemText: String = ""
    @State private var inputFocusTrigger: Int = 0

    private var worktreePath: String {
        workspace.activeWorktreePath
    }

    private var todoList: WorkspaceTodoList {
        workspace.settings.todoLists[worktreePath] ?? WorkspaceTodoList()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            cardHeader
            Divider().opacity(0.3)
            cardBody
            if todoList.hasCompletedItems {
                Divider().opacity(0.3)
                cardFooter
            }
        }
        .frame(width: 280)
        .frame(maxHeight: 360)
        .background(
            AiyuTermTheme.panelRaised.opacity(0.95),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(AiyuTermTheme.accent.opacity(0.3), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.15), radius: 10, y: 4)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                inputFocusTrigger += 1
            }
        }
    }

    // MARK: - Header

    private var cardHeader: some View {
        HStack {
            Image(systemName: "lightbulb.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(AiyuTermTheme.accent)
            Text("Capsules")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AiyuTermTheme.tertiaryText)
            if todoList.incompleteCount > 0 {
                Text("\(todoList.incompleteCount)")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(AiyuTermTheme.accent, in: Capsule())
            }
            Spacer()
            Button(action: addNewItem) {
                Image(systemName: "plus")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AiyuTermTheme.mutedText)
            }
            .buttonStyle(.plain)
            .help("Add item")
            Button(action: { workspace.isTodoPanelVisible = false }) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(AiyuTermTheme.mutedText)
            }
            .buttonStyle(.plain)
            .help("Close")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Body

    private var cardBody: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                newItemRow
                ForEach(todoList.sortedItems) { item in
                    TodoItemRow(
                        item: item,
                        isEditing: editingItemID == item.id,
                        onToggle: { toggleItem(item.id) },
                        onEdit: { editingItemID = item.id },
                        onCommit: { content in commitEdit(item.id, content: content) },
                        onDelete: { deleteItem(item.id) }
                    )
                }
            }
            .padding(.vertical, 4)
        }
        .frame(maxHeight: 280)
    }

    // MARK: - New Item Row

    private var newItemRow: some View {
        HStack(alignment: .top, spacing: 8) {
            Circle()
                .stroke(AiyuTermTheme.mutedText.opacity(0.4), lineWidth: 1.5)
                .frame(width: 14, height: 14)
                .padding(.top, 2)
            TodoInputField(text: $newItemText, placeholder: "Quick thought...", focusTrigger: inputFocusTrigger) {
                commitNewItem()
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(AiyuTermTheme.accent.opacity(0.06))
    }

    // MARK: - Footer

    private var cardFooter: some View {
        Button(action: clearCompleted) {
            Text("Clear completed")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(AiyuTermTheme.mutedText)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    // MARK: - Actions

    private func addNewItem() {
        newItemText = ""
        inputFocusTrigger += 1
    }

    private func commitNewItem() {
        let trimmed = newItemText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            newItemText = ""
            return
        }
        workspace.settings.todoLists[worktreePath, default: WorkspaceTodoList()].add(trimmed)
        workspace.objectWillChange.send()
        newItemText = ""
        // Stay focused for rapid capture
    }

    private func toggleItem(_ id: UUID) {
        workspace.settings.todoLists[worktreePath, default: WorkspaceTodoList()].toggleCompleted(id: id)
        workspace.objectWillChange.send()
    }

    private func commitEdit(_ id: UUID, content: String) {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            workspace.settings.todoLists[worktreePath, default: WorkspaceTodoList()].remove(id: id)
        } else {
            workspace.settings.todoLists[worktreePath, default: WorkspaceTodoList()].updateContent(id: id, content: trimmed)
        }
        editingItemID = nil
        workspace.objectWillChange.send()
    }

    private func deleteItem(_ id: UUID) {
        workspace.settings.todoLists[worktreePath, default: WorkspaceTodoList()].remove(id: id)
        workspace.objectWillChange.send()
    }

    private func clearCompleted() {
        workspace.settings.todoLists[worktreePath, default: WorkspaceTodoList()].clearCompleted()
        workspace.objectWillChange.send()
    }
}

// MARK: - Single Item Row

struct TodoItemRow: View {
    let item: TodoItem
    let isEditing: Bool
    let onToggle: () -> Void
    let onEdit: () -> Void
    let onCommit: (String) -> Void
    let onDelete: () -> Void

    @State private var editText: String = ""
    @State private var isHovering: Bool = false
    @State private var checkboxScale: CGFloat = 1.0
    @FocusState private var isFieldFocused: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            // Checkbox with large tap area and bounce animation
            ZStack {
                Circle()
                    .stroke(item.isCompleted ? AiyuTermTheme.accent : AiyuTermTheme.mutedText.opacity(0.4), lineWidth: 1.5)
                    .frame(width: 16, height: 16)
                if item.isCompleted {
                    Circle()
                        .fill(AiyuTermTheme.accent)
                        .frame(width: 16, height: 16)
                    Image(systemName: "checkmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .scaleEffect(checkboxScale)
            .frame(width: 24, height: 24)
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.5)) {
                    checkboxScale = 0.7
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.5)) {
                        checkboxScale = 1.0
                    }
                }
                onToggle()
            }

            if isEditing {
                TextField("", text: $editText, axis: .vertical)
                    .font(.system(size: 12))
                    .textFieldStyle(.plain)
                    .focused($isFieldFocused)
                    .lineLimit(1...5)
                    .onSubmit { onCommit(editText) }
                    .onAppear {
                        editText = item.content
                        isFieldFocused = true
                    }
            } else {
                Text(item.content)
                    .font(.system(size: 12))
                    .foregroundStyle(item.isCompleted ? AiyuTermTheme.mutedText : AiyuTermTheme.tertiaryText)
                    .strikethrough(item.isCompleted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .onTapGesture { if !item.isCompleted { onEdit() } }
            }

            // Hover action buttons
            if isHovering && !isEditing {
                HStack(spacing: 4) {
                    if !item.isCompleted {
                        todoActionButton(icon: "pencil", color: AiyuTermTheme.accent) {
                            onEdit()
                        }
                    }
                    todoActionButton(icon: "trash", color: Color(red: 1.0, green: 0.27, blue: 0.23)) {
                        onDelete()
                    }
                }
                .transition(.opacity)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .background(isHovering ? AiyuTermTheme.accent.opacity(0.04) : .clear)
        .cornerRadius(6)
        .animation(.easeInOut(duration: 0.15), value: isHovering)
        .onHover { isHovering = $0 }
    }

    private func todoActionButton(icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(color.opacity(0.8))
                .frame(width: 20, height: 20)
                .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - NSTextField wrapper for reliable focus in AppKit hybrid

struct TodoInputField: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String
    var focusTrigger: Int
    var onSubmit: () -> Void

    func makeNSView(context: Context) -> NSTextField {
        let field = NSTextField()
        field.isBordered = false
        field.drawsBackground = false
        field.font = .systemFont(ofSize: 12)
        field.placeholderString = placeholder
        field.focusRingType = .none
        field.delegate = context.coordinator
        field.lineBreakMode = .byTruncatingTail
        field.cell?.wraps = false
        field.cell?.isScrollable = true
        return field
    }

    func updateNSView(_ nsView: NSTextField, context: Context) {
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
        context.coordinator.onSubmit = onSubmit
        if context.coordinator.lastFocusTrigger != focusTrigger {
            context.coordinator.lastFocusTrigger = focusTrigger
            DispatchQueue.main.async {
                nsView.window?.makeFirstResponder(nsView)
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: TodoInputField
        var onSubmit: () -> Void = {}
        var lastFocusTrigger: Int = 0

        init(_ parent: TodoInputField) {
            self.parent = parent
        }

        func controlTextDidChange(_ obj: Notification) {
            guard let field = obj.object as? NSTextField else { return }
            parent.text = field.stringValue
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                onSubmit()
                return true
            }
            return false
        }
    }
}

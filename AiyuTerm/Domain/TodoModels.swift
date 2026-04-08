//
//  TodoModels.swift
//  AiyuTerm
//
//  Author: wuwenrui
//

import Foundation

struct TodoItem: Codable, Identifiable, Hashable {
    var id: UUID
    var content: String
    var isCompleted: Bool
    var createdAt: Date
    var sortOrder: Int

    init(
        id: UUID = UUID(),
        content: String = "",
        isCompleted: Bool = false,
        createdAt: Date = Date(),
        sortOrder: Int = 0
    ) {
        self.id = id
        self.content = content
        self.isCompleted = isCompleted
        self.createdAt = createdAt
        self.sortOrder = sortOrder
    }
}

struct WorkspaceTodoList: Codable, Hashable {
    var items: [TodoItem]

    init(items: [TodoItem] = []) {
        self.items = items
    }

    var incompleteCount: Int {
        items.filter { !$0.isCompleted }.count
    }

    var hasCompletedItems: Bool {
        items.contains { $0.isCompleted }
    }

    /// Sorted: incomplete first (by sortOrder), then completed (by sortOrder).
    var sortedItems: [TodoItem] {
        let incomplete = items.filter { !$0.isCompleted }.sorted { $0.sortOrder < $1.sortOrder }
        let completed = items.filter { $0.isCompleted }.sorted { $0.sortOrder < $1.sortOrder }
        return incomplete + completed
    }

    @discardableResult
    mutating func add(_ content: String) -> TodoItem {
        let nextOrder = (items.map(\.sortOrder).max() ?? -1) + 1
        let item = TodoItem(content: content, sortOrder: nextOrder)
        items.append(item)
        return item
    }

    mutating func remove(id: UUID) {
        items.removeAll { $0.id == id }
    }

    mutating func toggleCompleted(id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].isCompleted.toggle()
    }

    mutating func updateContent(id: UUID, content: String) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].content = content
    }

    mutating func clearCompleted() {
        items.removeAll { $0.isCompleted }
    }
}

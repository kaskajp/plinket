import Foundation

/// A slot in a ``PlayQueue``. The `id` distinguishes repeated occurrences of the same item.
public struct QueueEntry<Item: Hashable & Sendable & Codable>: Identifiable, Hashable, Sendable, Codable {
    public let id: UUID
    public let item: Item

    public init(item: Item, id: UUID = UUID()) {
        self.id = id
        self.item = item
    }
}

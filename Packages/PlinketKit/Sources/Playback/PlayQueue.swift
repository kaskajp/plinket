import Foundation

/// An ordered play queue with a current position, repeat mode and reversible shuffle.
///
/// `currentIndex` is `nil` exactly when the queue is empty.
public struct PlayQueue<Item: Hashable & Sendable & Codable>: Sendable, Equatable, Codable {
    public typealias Entry = QueueEntry<Item>

    public private(set) var entries: [Entry]
    public private(set) var currentIndex: Int?
    public var repeatMode: RepeatMode
    /// The unshuffled order, kept while shuffle is on so it can be restored.
    private var originalOrder: [Entry]?

    public init(repeatMode: RepeatMode = .off) {
        entries = []
        currentIndex = nil
        self.repeatMode = repeatMode
        originalOrder = nil
    }

    public var items: [Item] { entries.map(\.item) }

    public var isEmpty: Bool { entries.isEmpty }

    public var isShuffled: Bool { originalOrder != nil }

    public var currentEntry: Entry? {
        guard let currentIndex else { return nil }
        return entries[currentIndex]
    }

    public var current: Item? { currentEntry?.item }

    // MARK: - Building the queue

    /// Replaces the whole queue and makes the item at `startIndex` current.
    ///
    /// Turns shuffle off; an out-of-range `startIndex` is clamped. The repeat mode is kept.
    public mutating func replace(with items: [Item], startingAt startIndex: Int = 0) {
        entries = items.map { Entry(item: $0) }
        originalOrder = nil
        guard !entries.isEmpty else {
            currentIndex = nil
            return
        }
        currentIndex = min(max(startIndex, 0), entries.count - 1)
    }

    /// Inserts `items` directly after the current item, in the given order.
    public mutating func playNext(_ items: [Item]) {
        let newEntries = items.map { Entry(item: $0) }
        guard !newEntries.isEmpty else { return }
        guard let currentIndex else {
            append(newEntries)
            return
        }
        let currentID = entries[currentIndex].id
        entries.insert(contentsOf: newEntries, at: currentIndex + 1)
        guard let originalCurrentIndex = originalOrder?.firstIndex(where: { $0.id == currentID }) else { return }
        originalOrder?.insert(contentsOf: newEntries, at: originalCurrentIndex + 1)
    }

    /// Adds `items` to the end of the queue.
    public mutating func append(_ items: [Item]) {
        append(items.map { Entry(item: $0) })
    }

    /// Moves entries using `List.onMove` semantics: `destination` is an offset in the pre-move order.
    ///
    /// The current entry stays current wherever it ends up. Invalid offsets leave the queue unchanged.
    public mutating func move(fromOffsets offsets: IndexSet, toOffset destination: Int) {
        guard let lastOffset = offsets.last, lastOffset < entries.count,
              let firstOffset = offsets.first, firstOffset >= 0,
              (0...entries.count).contains(destination)
        else { return }

        let currentID = currentEntry?.id
        let movingEntries = offsets.map { entries[$0] }
        var remainingEntries = entries.enumerated()
            .filter { !offsets.contains($0.offset) }
            .map(\.element)
        let insertionIndex = destination - offsets.count(in: 0..<destination)
        remainingEntries.insert(contentsOf: movingEntries, at: insertionIndex)
        entries = remainingEntries
        currentIndex = entries.firstIndex { $0.id == currentID }
    }

    /// Removes the entries at `offsets`; out-of-range offsets are ignored.
    ///
    /// If the current entry is removed, the first surviving entry after it becomes current,
    /// or the last entry when nothing followed it.
    public mutating func remove(atOffsets offsets: IndexSet) {
        let validOffsets = offsets.filteredIndexSet { entries.indices.contains($0) }
        guard !validOffsets.isEmpty, let previousIndex = currentIndex else { return }

        let removedIDs = Set(validOffsets.map { entries[$0].id })
        entries.removeAll { removedIDs.contains($0.id) }
        originalOrder?.removeAll { removedIDs.contains($0.id) }

        guard !entries.isEmpty else {
            currentIndex = nil
            return
        }
        let survivorsBeforeCurrent = previousIndex - validOffsets.count(in: 0..<previousIndex)
        currentIndex = min(survivorsBeforeCurrent, entries.count - 1)
    }

    /// Empties the queue and turns shuffle off. The repeat mode is kept.
    public mutating func clear() {
        entries = []
        currentIndex = nil
        originalOrder = nil
    }

    // MARK: - Navigation

    /// Moves to the item that should play when the current one finishes on its own.
    ///
    /// Honors every repeat mode, so `.one` returns the current item again.
    /// Returns `nil` and keeps the position when the queue has ended.
    @discardableResult
    public mutating func advance() -> Item? {
        moveCurrent(to: nextIndex(repeatingCurrent: repeatMode == .one))
    }

    /// Moves to the next item on user request. Ignores `.one`; only `.all` wraps around.
    @discardableResult
    public mutating func skipForward() -> Item? {
        moveCurrent(to: nextIndex(repeatingCurrent: false))
    }

    /// Moves to the previous item; only `.all` wraps from the first item to the last.
    ///
    /// Returns `nil` and keeps the position when there is no previous item.
    @discardableResult
    public mutating func skipBackward() -> Item? {
        moveCurrent(to: previousIndex())
    }

    /// The item ``advance()`` would move to, without moving. Use it to preload.
    public func peekNext() -> Item? {
        peekNextEntry()?.item
    }

    /// The entry ``advance()`` would move to, without moving.
    public func peekNextEntry() -> Entry? {
        guard let index = nextIndex(repeatingCurrent: repeatMode == .one) else { return nil }
        return entries[index]
    }

    /// Makes the entry at `index` current. Returns `nil` and keeps the position when out of range.
    @discardableResult
    public mutating func jump(to index: Int) -> Item? {
        guard entries.indices.contains(index) else { return nil }
        return moveCurrent(to: index)
    }

    // MARK: - Shuffle

    public mutating func setShuffle(_ isEnabled: Bool) {
        var generator = SystemRandomNumberGenerator()
        setShuffle(isEnabled, using: &generator)
    }

    /// Turning shuffle on puts the current entry first and shuffles the rest; turning it off
    /// restores the original order with the same entry current. Setting the current state is a no-op.
    public mutating func setShuffle(_ isEnabled: Bool, using generator: inout some RandomNumberGenerator) {
        guard isEnabled != isShuffled else { return }
        if isEnabled {
            shuffle(using: &generator)
        } else {
            unshuffle()
        }
    }

    // MARK: - Private

    private mutating func append(_ newEntries: [Entry]) {
        guard !newEntries.isEmpty else { return }
        entries.append(contentsOf: newEntries)
        originalOrder?.append(contentsOf: newEntries)
        if currentIndex == nil {
            currentIndex = 0
        }
    }

    private func nextIndex(repeatingCurrent: Bool) -> Int? {
        guard let currentIndex else { return nil }
        if repeatingCurrent {
            return currentIndex
        }
        if currentIndex + 1 < entries.count {
            return currentIndex + 1
        }
        return repeatMode == .all ? 0 : nil
    }

    private func previousIndex() -> Int? {
        guard let currentIndex else { return nil }
        if currentIndex > 0 {
            return currentIndex - 1
        }
        return repeatMode == .all ? entries.count - 1 : nil
    }

    private mutating func moveCurrent(to index: Int?) -> Item? {
        guard let index else { return nil }
        currentIndex = index
        return entries[index].item
    }

    private mutating func shuffle(using generator: inout some RandomNumberGenerator) {
        originalOrder = entries
        guard let currentIndex else { return }
        var remainingEntries = entries
        let currentEntry = remainingEntries.remove(at: currentIndex)
        remainingEntries.shuffle(using: &generator)
        entries = [currentEntry] + remainingEntries
        self.currentIndex = 0
    }

    private mutating func unshuffle() {
        guard let originalOrder else { return }
        let currentID = currentEntry?.id
        entries = originalOrder
        self.originalOrder = nil
        currentIndex = entries.firstIndex { $0.id == currentID }
    }
}

extension PlayQueue {
    private enum CodingKeys: String, CodingKey {
        case entries, currentIndex, repeatMode, originalOrder
    }

    /// Rejects persisted state that would break the queue's invariants instead of trapping later.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let entries = try container.decode([Entry].self, forKey: .entries)
        let currentIndex = try container.decodeIfPresent(Int.self, forKey: .currentIndex)
        let originalOrder = try container.decodeIfPresent([Entry].self, forKey: .originalOrder)

        let isCurrentIndexValid = if let currentIndex { entries.indices.contains(currentIndex) } else { entries.isEmpty }
        guard isCurrentIndexValid else {
            throw DecodingError.dataCorruptedError(
                forKey: .currentIndex, in: container,
                debugDescription: "currentIndex \(String(describing: currentIndex)) is invalid for \(entries.count) entries"
            )
        }
        if let originalOrder, Set(originalOrder.map(\.id)) != Set(entries.map(\.id)) {
            throw DecodingError.dataCorruptedError(
                forKey: .originalOrder, in: container,
                debugDescription: "originalOrder does not contain the same entries as the queue"
            )
        }

        self.entries = entries
        self.currentIndex = currentIndex
        self.repeatMode = try container.decode(RepeatMode.self, forKey: .repeatMode)
        self.originalOrder = originalOrder
    }
}

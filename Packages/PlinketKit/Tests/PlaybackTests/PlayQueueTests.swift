import Foundation
import Testing
@testable import Playback

private func makeQueue(
    _ items: [String],
    startingAt startIndex: Int = 0,
    repeatMode: RepeatMode = .off
) -> PlayQueue<String> {
    var queue = PlayQueue<String>(repeatMode: repeatMode)
    queue.replace(with: items, startingAt: startIndex)
    return queue
}

private struct SeededGenerator: RandomNumberGenerator {
    var state: UInt64

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var mixed = state
        mixed = (mixed ^ (mixed >> 30)) &* 0xBF58_476D_1CE4_E5B9
        mixed = (mixed ^ (mixed >> 27)) &* 0x94D0_49BB_1331_11EB
        return mixed ^ (mixed >> 31)
    }
}

private let twentyItems = (1...20).map { "track\($0)" }

private func shuffled(_ queue: PlayQueue<String>, seed: UInt64 = 42) -> PlayQueue<String> {
    var queue = queue
    var generator = SeededGenerator(state: seed)
    queue.setShuffle(true, using: &generator)
    return queue
}

@Suite struct PlayQueueReplaceTests {
    @Test func replace_startsAtGivenIndex() {
        let queue = makeQueue(["a", "b", "c"], startingAt: 1)
        #expect(queue.current == "b")
    }

    @Test(arguments: [(-3, "a"), (7, "c")])
    func replace_clampsOutOfRangeStartIndex(startIndex: Int, expectedCurrent: String) {
        let queue = makeQueue(["a", "b", "c"], startingAt: startIndex)
        #expect(queue.current == expectedCurrent)
    }

    @Test func replace_withNoItemsLeavesNothingCurrent() {
        let queue = makeQueue([])
        #expect(queue.currentIndex == nil)
    }

    @Test func replace_turnsShuffleOff() {
        var queue = shuffled(makeQueue(["a", "b", "c"]))
        queue.replace(with: ["x", "y"])
        #expect(!queue.isShuffled)
    }

    @Test func replace_keepsRepeatMode() {
        var queue = makeQueue(["a"], repeatMode: .all)
        queue.replace(with: ["x", "y"])
        #expect(queue.repeatMode == .all)
    }

    @Test func replace_givesDuplicateItemsDistinctEntries() {
        let queue = makeQueue(["a", "a"])
        #expect(queue.entries[0].id != queue.entries[1].id)
    }
}

@Suite struct PlayQueueAddingTests {
    @Test func playNext_insertsAfterCurrentInGivenOrder() {
        var queue = makeQueue(["a", "b", "c"], startingAt: 1)
        queue.playNext(["x", "y"])
        #expect(queue.items == ["a", "b", "x", "y", "c"])
    }

    @Test func playNext_onEmptyQueueMakesFirstInsertedItemCurrent() {
        var queue = PlayQueue<String>()
        queue.playNext(["x", "y"])
        #expect(queue.current == "x")
    }

    @Test func playNext_whileShuffledFollowsCurrentInOriginalOrder() {
        var queue = shuffled(makeQueue(["a", "b", "c", "d"], startingAt: 1))
        queue.playNext(["x"])
        queue.setShuffle(false)
        #expect(queue.items == ["a", "b", "x", "c", "d"])
    }

    @Test func playNext_allowsItemAlreadyInQueue() {
        var queue = makeQueue(["a", "b"])
        queue.playNext(["b"])
        #expect(queue.items == ["a", "b", "b"])
    }

    @Test func append_addsToEnd() {
        var queue = makeQueue(["a", "b"])
        queue.append(["x", "y"])
        #expect(queue.items == ["a", "b", "x", "y"])
    }

    @Test func append_onEmptyQueueMakesFirstItemCurrent() {
        var queue = PlayQueue<String>()
        queue.append(["x", "y"])
        #expect(queue.current == "x")
    }

    @Test func append_whileShuffledAddsToEndOfOriginalOrder() {
        var queue = shuffled(makeQueue(["a", "b", "c"]))
        queue.append(["x"])
        queue.setShuffle(false)
        #expect(queue.items == ["a", "b", "c", "x"])
    }
}

@Suite struct PlayQueueNavigationTests {
    @Test func advance_movesToNextItem() {
        var queue = makeQueue(["a", "b", "c"])
        #expect(queue.advance() == "b")
    }

    @Test func advance_atEndWithRepeatOffReturnsNil() {
        var queue = makeQueue(["a", "b"], startingAt: 1)
        #expect(queue.advance() == nil)
    }

    @Test func advance_atEndWithRepeatOffKeepsLastItemCurrent() {
        var queue = makeQueue(["a", "b"], startingAt: 1)
        queue.advance()
        #expect(queue.currentIndex == 1)
    }

    @Test func advance_atEndWithRepeatAllWrapsToFirst() {
        var queue = makeQueue(["a", "b"], startingAt: 1, repeatMode: .all)
        #expect(queue.advance() == "a")
    }

    @Test func advance_withRepeatOneStaysOnCurrent() {
        var queue = makeQueue(["a", "b", "c"], startingAt: 1, repeatMode: .one)
        queue.advance()
        #expect(queue.currentIndex == 1)
    }

    @Test func advance_onEmptyQueueReturnsNil() {
        var queue = PlayQueue<String>()
        #expect(queue.advance() == nil)
    }

    @Test func advance_throughDuplicatesVisitsEachEntry() {
        var queue = makeQueue(["a", "a", "b"])
        queue.advance()
        #expect(queue.currentEntry?.id == queue.entries[1].id)
    }

    @Test func skipForward_withRepeatOneMovesToNextItem() {
        var queue = makeQueue(["a", "b"], repeatMode: .one)
        #expect(queue.skipForward() == "b")
    }

    @Test func skipForward_atEndWithRepeatOneReturnsNil() {
        var queue = makeQueue(["a", "b"], startingAt: 1, repeatMode: .one)
        #expect(queue.skipForward() == nil)
    }

    @Test func skipForward_atEndWithRepeatAllWrapsToFirst() {
        var queue = makeQueue(["a", "b"], startingAt: 1, repeatMode: .all)
        #expect(queue.skipForward() == "a")
    }

    @Test func skipBackward_movesToPreviousItem() {
        var queue = makeQueue(["a", "b", "c"], startingAt: 2)
        #expect(queue.skipBackward() == "b")
    }

    @Test(arguments: [RepeatMode.off, .one])
    func skipBackward_atStartWithoutRepeatAllReturnsNil(repeatMode: RepeatMode) {
        var queue = makeQueue(["a", "b"], repeatMode: repeatMode)
        #expect(queue.skipBackward() == nil)
    }

    @Test func skipBackward_atStartWithRepeatAllWrapsToLast() {
        var queue = makeQueue(["a", "b", "c"], repeatMode: .all)
        #expect(queue.skipBackward() == "c")
    }

    @Test(arguments: [RepeatMode.off, .all, .one], [0, 1, 2])
    func peekNext_matchesAdvance(repeatMode: RepeatMode, startIndex: Int) {
        var queue = makeQueue(["a", "b", "c"], startingAt: startIndex, repeatMode: repeatMode)
        let peeked = queue.peekNext()
        #expect(peeked == queue.advance())
    }

    @Test func peekNext_atEndWithRepeatOffReturnsNil() {
        let queue = makeQueue(["a", "b"], startingAt: 1)
        #expect(queue.peekNext() == nil)
    }

    @Test func peekNext_atEndWithRepeatAllReturnsFirst() {
        let queue = makeQueue(["a", "b"], startingAt: 1, repeatMode: .all)
        #expect(queue.peekNext() == "a")
    }

    @Test func peekNext_withRepeatOneReturnsCurrent() {
        let queue = makeQueue(["a", "b"], repeatMode: .one)
        #expect(queue.peekNext() == "a")
    }

    @Test func jump_makesEntryAtIndexCurrent() {
        var queue = makeQueue(["a", "b", "c"])
        #expect(queue.jump(to: 2) == "c")
    }

    @Test(arguments: [-1, 3])
    func jump_outOfRangeKeepsCurrent(index: Int) {
        var queue = makeQueue(["a", "b", "c"], startingAt: 1)
        queue.jump(to: index)
        #expect(queue.currentIndex == 1)
    }
}

@Suite struct PlayQueueMoveTests {
    @Test func move_currentEntryStaysCurrent() {
        var queue = makeQueue(["a", "b", "c", "d"], startingAt: 1)
        queue.move(fromOffsets: [1], toOffset: 4)
        #expect(queue.currentIndex == 3)
    }

    @Test func move_entryFromBeforeToAfterCurrentShiftsCurrentBack() {
        var queue = makeQueue(["a", "b", "c", "d"], startingAt: 2)
        queue.move(fromOffsets: [0], toOffset: 4)
        #expect(queue.currentIndex == 1)
    }

    @Test func move_entryFromAfterToBeforeCurrentShiftsCurrentForward() {
        var queue = makeQueue(["a", "b", "c", "d"], startingAt: 1)
        queue.move(fromOffsets: [3], toOffset: 0)
        #expect(queue.currentIndex == 2)
    }

    @Test func move_multipleOffsetsUsesPreMoveDestination() {
        var queue = makeQueue(["a", "b", "c", "d", "e"])
        queue.move(fromOffsets: [0, 2], toOffset: 4)
        #expect(queue.items == ["b", "d", "a", "c", "e"])
    }

    @Test func move_keepsTrackOfCurrentAmongDuplicates() {
        var queue = makeQueue(["a", "a", "a"], startingAt: 1)
        let currentID = queue.currentEntry?.id
        queue.move(fromOffsets: [1], toOffset: 0)
        #expect(queue.entries[0].id == currentID)
    }

    @Test(arguments: [(IndexSet([5]), 0), (IndexSet([0]), 9), (IndexSet(), 1)])
    func move_invalidArgumentsLeaveQueueUnchanged(offsets: IndexSet, destination: Int) {
        let queue = makeQueue(["a", "b", "c"])
        var moved = queue
        moved.move(fromOffsets: offsets, toOffset: destination)
        #expect(moved == queue)
    }
}

@Suite struct PlayQueueRemoveTests {
    @Test func remove_beforeCurrentKeepsSameItemCurrent() {
        var queue = makeQueue(["a", "b", "c", "d"], startingAt: 2)
        queue.remove(atOffsets: [0, 1])
        #expect(queue.currentIndex == 0)
    }

    @Test func remove_afterCurrentKeepsIndex() {
        var queue = makeQueue(["a", "b", "c"], startingAt: 1)
        queue.remove(atOffsets: [2])
        #expect(queue.current == "b")
    }

    @Test func remove_currentMakesFollowingItemCurrent() {
        var queue = makeQueue(["a", "b", "c", "d"], startingAt: 1)
        queue.remove(atOffsets: [1, 2])
        #expect(queue.current == "d")
    }

    @Test func remove_currentLastItemMakesNewLastItemCurrent() {
        var queue = makeQueue(["a", "b", "c"], startingAt: 2)
        queue.remove(atOffsets: [2])
        #expect(queue.current == "b")
    }

    @Test func remove_everythingLeavesNothingCurrent() {
        var queue = makeQueue(["a", "b"])
        queue.remove(atOffsets: [0, 1])
        #expect(queue.currentIndex == nil)
    }

    @Test func remove_oneDuplicateKeepsTheOther() {
        var queue = makeQueue(["a", "b", "a"])
        let keptID = queue.entries[2].id
        queue.remove(atOffsets: [0])
        #expect(queue.entries.map(\.id).contains(keptID))
    }

    @Test func remove_ignoresOutOfRangeOffsets() {
        var queue = makeQueue(["a", "b"])
        queue.remove(atOffsets: [1, 5])
        #expect(queue.items == ["a"])
    }

    @Test func remove_whileShuffledAlsoRemovesFromOriginalOrder() {
        var queue = shuffled(makeQueue(["a", "b", "c", "d"]))
        let removedIndex = queue.items.firstIndex(of: "c") ?? -1
        queue.remove(atOffsets: [removedIndex])
        queue.setShuffle(false)
        #expect(queue.items == ["a", "b", "d"])
    }
}

@Suite struct PlayQueueShuffleTests {
    @Test func shuffle_putsCurrentFirst() {
        let queue = shuffled(makeQueue(twentyItems, startingAt: 7))
        #expect(queue.currentIndex == 0)
    }

    @Test func shuffle_keepsCurrentItem() {
        let queue = shuffled(makeQueue(twentyItems, startingAt: 7))
        #expect(queue.current == "track8")
    }

    @Test func shuffle_keepsEveryEntry() {
        let original = makeQueue(twentyItems, startingAt: 7)
        let queue = shuffled(original)
        #expect(Set(queue.entries) == Set(original.entries))
    }

    @Test func shuffle_reordersRemainingEntries() {
        let queue = shuffled(makeQueue(twentyItems))
        #expect(queue.items != twentyItems)
    }

    @Test func shuffle_enablingTwiceDoesNotReshuffle() {
        let once = shuffled(makeQueue(twentyItems), seed: 1)
        let twice = shuffled(once, seed: 2)
        #expect(twice == once)
    }

    @Test func unshuffle_restoresOriginalOrder() {
        var queue = shuffled(makeQueue(twentyItems, startingAt: 7))
        queue.setShuffle(false)
        #expect(queue.items == twentyItems)
    }

    @Test func unshuffle_keepsItemReachedWhileShuffledCurrent() {
        var queue = shuffled(makeQueue(twentyItems))
        queue.advance()
        queue.advance()
        let currentID = queue.currentEntry?.id
        queue.setShuffle(false)
        #expect(queue.currentEntry?.id == currentID)
    }

    @Test func unshuffle_keepsCurrentAmongDuplicates() {
        var queue = shuffled(makeQueue(["a", "a", "a", "a"], startingAt: 2))
        queue.setShuffle(false)
        #expect(queue.currentIndex == 2)
    }

    @Test func unshuffle_whenNotShuffledLeavesQueueUnchanged() {
        let queue = makeQueue(["a", "b", "c"], startingAt: 1)
        var unshuffled = queue
        unshuffled.setShuffle(false)
        #expect(unshuffled == queue)
    }

    @Test func clear_emptiesQueue() {
        var queue = makeQueue(["a", "b"])
        queue.clear()
        #expect(queue.isEmpty && queue.currentIndex == nil)
    }

    @Test func clear_turnsShuffleOff() {
        var queue = shuffled(makeQueue(["a", "b"]))
        queue.clear()
        #expect(!queue.isShuffled)
    }

    @Test func clear_keepsRepeatMode() {
        var queue = makeQueue(["a"], repeatMode: .one)
        queue.clear()
        #expect(queue.repeatMode == .one)
    }
}

@Suite struct PlayQueueCodingTests {
    @Test func codable_roundTripsShuffledQueue() throws {
        var queue = shuffled(makeQueue(["a", "b", "a", "c"], startingAt: 2, repeatMode: .all))
        queue.advance()
        let decoded = try JSONDecoder().decode(PlayQueue<String>.self, from: JSONEncoder().encode(queue))
        #expect(decoded == queue)
    }

    @Test func codable_roundTripRestoresOriginalOrderOnUnshuffle() throws {
        let queue = shuffled(makeQueue(["a", "b", "c"]))
        var decoded = try JSONDecoder().decode(PlayQueue<String>.self, from: JSONEncoder().encode(queue))
        decoded.setShuffle(false)
        #expect(decoded.items == ["a", "b", "c"])
    }

    @Test(arguments: [
        #"{"entries":[],"currentIndex":0,"repeatMode":"off"}"#,
        #"{"entries":[{"id":"7E57D004-2B97-0E7A-B45F-5387367791CD","item":"a"}],"repeatMode":"off"}"#,
        #"{"entries":[{"id":"7E57D004-2B97-0E7A-B45F-5387367791CD","item":"a"}],"currentIndex":1,"repeatMode":"off"}"#,
        #"{"entries":[{"id":"7E57D004-2B97-0E7A-B45F-5387367791CD","item":"a"}],"currentIndex":0,"repeatMode":"off","originalOrder":[]}"#,
    ])
    func decoding_rejectsInconsistentState(json: String) {
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(PlayQueue<String>.self, from: Data(json.utf8))
        }
    }
}

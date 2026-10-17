import Subsonic

/// One disc of a multi-disc album.
public struct AlbumDisc: Identifiable, Sendable, Hashable {
    public let number: Int
    /// Positions in the album's `songs`, so playback can start the whole album from any of them.
    public let songIndices: [Int]

    public var id: Int { number }
}

extension AlbumDetail {
    /// The songs grouped by disc number in album order; songs without a disc number count as disc 1.
    public var discs: [AlbumDisc] {
        var indicesByDisc: [Int: [Int]] = [:]
        for (index, song) in songs.enumerated() {
            indicesByDisc[song.discNumber ?? 1, default: []].append(index)
        }
        return indicesByDisc
            .sorted { $0.key < $1.key }
            .map { AlbumDisc(number: $0.key, songIndices: $0.value) }
    }
}

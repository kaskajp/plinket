import Subsonic

/// Known album totals, using loaded tracks only when they provide a complete total.
public struct AlbumSummary: Sendable, Equatable {
    public let songCount: Int?
    /// Total playing time in seconds, omitted when incomplete.
    public let duration: Int?

    public init(album: Album, detail: AlbumDetail? = nil) {
        songCount = Self.positiveValue(detail?.album.songCount)
            ?? Self.positiveValue(album.songCount)
            ?? Self.positiveValue(detail?.songs.count)
        duration = Self.positiveValue(detail?.album.duration)
            ?? Self.positiveValue(album.duration)
            ?? Self.totalDuration(of: detail?.songs ?? [], songCount: songCount)
    }

    private static func positiveValue(_ value: Int?) -> Int? {
        guard let value, value > 0 else { return nil }
        return value
    }

    private static func totalDuration(of songs: [Song], songCount: Int?) -> Int? {
        guard !songs.isEmpty, songs.count == songCount else { return nil }
        var total = 0
        for song in songs {
            guard let duration = positiveValue(song.duration) else { return nil }
            total += duration
        }
        return total
    }
}

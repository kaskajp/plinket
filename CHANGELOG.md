# Changelog

All notable changes to Plinket are documented here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project uses [Semantic Versioning](https://semver.org/).

Versions are shown as Version (Build), matching the app. Add notes under Unreleased as you go; `scripts/release.sh` files them under the version and build set in Xcode when you release.

## [Unreleased]

First version of Plinket, an album-first client for Navidrome and other Subsonic API servers, on iOS 27 and macOS 27.

### Added
- Sign in to a Navidrome server with token authentication; credentials are kept in the Keychain.
- Album grid with sorting, plus artists, playlists, favorites and search.
- Album and playlist pages with Play, Shuffle and a favorite button; the song that's playing is highlighted in track lists.
- Star and unstar albums and songs.
- Playback with a queue (play next, add to queue, reorder, shuffle, repeat) that's saved and restored on relaunch.
- Near-gapless playback that preloads the next song.
- Lock screen, Control Center, media key and AirPlay controls.
- Scrobbling to the server, with plays submitted later when the server can't be reached.
- iOS: tab layout with a mini player and a full Now Playing screen.
- macOS: sidebar layout with a player bar, a queue inspector, and menu and keyboard commands for playback.
- CarPlay with albums, playlists and favorites (simulator only until Apple grants the CarPlay entitlement).
- App icon and purple accent color.

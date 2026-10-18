# plinket
Bare essentials native iOS/macOS music player for your Navidrome library

Album-first, intentional listening: browse albums, artists, playlists and favorites, search, play with a simple queue. Scrobbles to your server, supports lock screen / media keys, AirPlay and CarPlay. No discovery, mixes or radio.

## Requirements
- Xcode 27, iOS 27 / macOS 27
- [XcodeGen](https://github.com/yonaskolb/XcodeGen): `brew install xcodegen`
- A Navidrome (or other Subsonic API) server

## Getting started
```sh
xcodegen generate      # creates Plinket.xcodeproj (not checked in)
open Plinket.xcodeproj
```
Set your development team in `project.yml` (`DEVELOPMENT_TEAM`) to run on devices and avoid repeated macOS keychain prompts between rebuilds.

Tests for the logic package:
```sh
swift test --package-path Packages/PlinketKit
```

## Layout
```
App/                 SwiftUI app (one multiplatform target)
  Shared/            views shared by iOS and macOS
  iOS/               tab root, mini player, Now Playing, CarPlay
  macOS/             split view root, player bar, menu commands
Packages/PlinketKit/
  Subsonic/          API client, token auth, models, Keychain credentials
  Library/           cached library store, star/unstar, image cache
  Playback/          queue, AVQueuePlayer engine, Now Playing, scrobbling
```

## Releasing
Add notes under `## [Unreleased]` in `CHANGELOG.md` as you go. To release:
1. Set Version and Build in Xcode (target → General → Identity).
2. With everything committed, run `scripts/release.sh`, then `git push --follow-tags`.

The script reads Version and Build from the Xcode project, files the Unreleased notes under `## [Version (Build)] - date`, copies the numbers into `project.yml` so the next `xcodegen generate` keeps them, then commits and tags `vVersion-build.Build`. Run it before regenerating the project, or the regenerated project resets Version and Build to what `project.yml` has.

## Debug launch options
Debug builds read these environment variables (ignored in release):
`PLINKET_DEBUG_SERVER`, `PLINKET_DEBUG_USER`, `PLINKET_DEBUG_PASSWORD` (auto sign-in), `PLINKET_DEBUG_SECTION`, `PLINKET_DEBUG_SEARCH`, `PLINKET_DEBUG_OPEN_ALBUM`, `PLINKET_DEBUG_PLAY_ALBUM`, `PLINKET_DEBUG_NOW_PLAYING`, `PLINKET_DEBUG_WINDOW_SNAPSHOT`.

## CarPlay
The `com.apple.developer.carplay-audio` entitlement works in the Simulator (I/O → External Displays → CarPlay). Running in a car requires Apple to grant the entitlement.

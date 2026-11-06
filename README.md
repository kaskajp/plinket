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

## Offline listening
Download an album from its track list or a song from its context menu. Completed
downloads appear in **Downloads** and play from local storage, including after a
restart without a network connection. They are kept in Application Support (not
the evictable cache), separately for each server/account, and excluded from backups.

Settings → Downloads controls downloading, Original/Opus/MP3 encoding, cellular
access (off by default), and the storage limit (5 GB by default). Original uses the
server's original file; Opus/MP3 require server transcoding and device playback
support. Unsupported or incorrectly transcoded responses are reported, not saved
as completed songs. Hotspots and other expensive connections follow the cellular
setting. Transfers are foreground work, not a background download service; a lost
connection pauses the queue, and interrupted transfers restart rather than resume
partway. Unfinished transfers are discarded on app restart and can be downloaded
again. Disabling downloads cancels pending work but keeps completed files.

The storage overview counts completed songs and their albums/artists. Delete all
downloads requires confirmation and removes local music only. Signing out stops
transfers but keeps completed downloads for the next sign-in to that same account.

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
  Downloads/         durable offline files, settings, storage and network policy
```

## Releasing
Add notes under `## [Unreleased]` in `CHANGELOG.md` as you go. To release:
1. Set Version and Build in Xcode (target → General → Identity).
2. With everything committed, run `scripts/release.sh`, then `git push --follow-tags`.

The script reads Version and Build from the Xcode project, files the Unreleased notes under `## [Version (Build)] - date`, copies the numbers into `project.yml` so the next `xcodegen generate` keeps them, then commits and tags `vVersion-build.Build`. Run it before regenerating the project, or the regenerated project resets Version and Build to what `project.yml` has.

## App Store art
`scripts/render-store-art.swift` renders the product page header and search results images into `build/store-art/`. The tagline is set at the top of the script.

Screenshots must not show real album artwork, so take them against the sample library: invented artists and albums with generated abstract covers, served over the Subsonic API on `127.0.0.1:4533`.

```sh
scripts/sample-library/server.py --dump build/sample-library/library.json
scripts/sample-library/render-covers.swift build/sample-library
scripts/sample-library/server.py
```

Then launch a debug build with `PLINKET_DEBUG_SERVER=http://127.0.0.1:4533` and any username and password, plus the launch options below to open the screen you want.

## Debug launch options
Debug builds read these environment variables (ignored in release):
`PLINKET_DEBUG_SERVER`, `PLINKET_DEBUG_USER`, `PLINKET_DEBUG_PASSWORD` (auto sign-in), `PLINKET_DEBUG_SECTION`, `PLINKET_DEBUG_SEARCH`, `PLINKET_DEBUG_OPEN_ALBUM`, `PLINKET_DEBUG_PLAY_ALBUM`, `PLINKET_DEBUG_NOW_PLAYING`, `PLINKET_DEBUG_WINDOW_SNAPSHOT`.

## CarPlay
Both device and Simulator builds include the `com.apple.developer.carplay-audio` entitlement. For device builds, use the Apple Developer team granted CarPlay audio access and a provisioning profile that includes the entitlement. If an existing profile predates the approval, regenerate it before signing.

To test in the Simulator, choose I/O → External Displays → CarPlay. Connect an iPhone to a CarPlay receiver to test on hardware. Sign in on the iPhone first; CarPlay shares its library, queue and playback controls.

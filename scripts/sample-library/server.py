#!/usr/bin/env python3
"""A made-up music library served over the Subsonic API, for App Store screenshots.

Every artist, album and song is invented, and the cover art is drawn by render-covers.swift, so screenshots
show nothing that belongs to anyone else.

Usage:
    scripts/sample-library/server.py --dump build/sample-library/library.json
    scripts/sample-library/render-covers.swift build/sample-library
    scripts/sample-library/server.py [--port 4533] [--data build/sample-library]

Sign in with http://127.0.0.1:4533, any username and any password.
"""

import argparse
import io
import json
import random
import re
import wave
from datetime import datetime, timedelta, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import parse_qs, urlparse

# (artist, album, year, genre)
ALBUMS = [
    ("Lumen Harbor", "Tidal Lights", 2023, "Dream Pop"),
    ("Lumen Harbor", "Slow Weather", 2020, "Dream Pop"),
    ("The Paper Orchards", "Kites Over Brickfield", 2019, "Indie Folk"),
    ("Mira Okafor-Lind", "Glass Atlas", 2024, "Electronic"),
    ("Mira Okafor-Lind", "Nightswim", 2021, "Electronic"),
    ("Copper Saints", "Static Hymns", 2018, "Post-Rock"),
    ("Velvet Cartography", "Inland Sea", 2022, "Ambient"),
    ("Juno Halloway", "Small Fires", 2024, "Singer-Songwriter"),
    ("Juno Halloway", "Letters from the Ridge", 2017, "Singer-Songwriter"),
    ("Orbit Bureau", "Satellite Postcards", 2021, "Synth-Pop"),
    ("Hollow Pines Quartet", "Winter Sessions", 2016, "Jazz"),
    ("Hollow Pines Quartet", "Blue Hour Standards", 2022, "Jazz"),
    ("Sola Marrow", "Saltwater Psalms", 2025, "Soul"),
    ("Tessellate", "Fold Lines", 2023, "Electronic"),
    ("The Low Meridian", "Westbound Lanterns", 2019, "Americana"),
    ("Kaito Verne", "Neon Tide", 2024, "City Pop"),
    ("Kaito Verne", "Coastline Radio", 2021, "City Pop"),
    ("Ashgrove", "Ember Field", 2020, "Shoegaze"),
    ("Ines Calder", "Quiet Machines", 2025, "Electronic"),
    ("Marigold Transit", "Sunday Freeway", 2022, "Indie Rock"),
    ("Feral Choir", "Moss & Mirrors", 2021, "Art Pop"),
    ("Delta Nocturne", "After the Rain", 2018, "Downtempo"),
    ("The Lantern Society", "Paper Moons", 2024, "Chamber Pop"),
    ("Polar Fable", "Aurora Drift", 2023, "Ambient"),
    ("Sola Marrow", "Honey & Iron", 2021, "Soul"),
    ("Copper Saints", "Lowland Choirs", 2015, "Post-Rock"),
    ("Velvet Cartography", "Field Recordings", 2019, "Ambient"),
    ("Orbit Bureau", "Weekend Protocol", 2024, "Synth-Pop"),
    ("Brightwater Club", "Summer Static", 2023, "Indie Pop"),
    ("Nadia Esterhaus", "Porcelain", 2022, "Neo-Classical"),
    ("The Paper Orchards", "Harvest Tapes", 2024, "Indie Folk"),
    ("Rook & Wren", "Two Rooms", 2020, "Folk"),
    ("Ines Calder", "Signal Garden", 2022, "Electronic"),
    ("Tessellate", "Prism Theory", 2020, "Electronic"),
    ("Marigold Transit", "Parking Lot Sunsets", 2019, "Indie Rock"),
    ("Cielo Vargas", "Casa de Luz", 2025, "Latin Jazz"),
]

TITLE_WORDS_A = [
    "Golden", "Quiet", "Paper", "Silver", "Distant", "Velvet", "Hollow", "Northern", "Electric", "Amber", "Lonely",
    "Painted", "Restless", "Sleeping", "Midnight", "Open", "Little", "Wandering", "Borrowed", "Second",
]
TITLE_WORDS_B = [
    "Rivers", "Signals", "Harbors", "Gardens", "Lanterns", "Static", "Satellites", "Mornings", "Avenues", "Tides",
    "Letters", "Fields", "Windows", "Ghosts", "Islands", "Machines", "Echoes", "Summers", "Highways", "Lights",
]
TITLE_SINGLES = [
    "Undertow", "Glasshouse", "Slow Bloom", "Afterglow", "Driftwood", "Heliotrope", "Westward", "Low Tide",
    "Daybreak", "Static Bloom", "Holding Pattern", "Wildflower Road", "Small Hours", "Blue Hour", "Paper Planes",
    "Night Bus", "Firefly", "Weathervane", "Long Way Home", "Soft Focus", "Overpass", "Kingfisher", "Salt & Cedar",
    "Parallel", "Monsoon", "Lighthouse", "Cartwheel", "Northbound", "Sunroom", "Tangerine",
]

PLAYLISTS = [
    ("Morning Coffee", [2, 7, 14, 21, 8]),
    ("Late Night Drive", [15, 16, 4, 9, 19]),
    ("Deep Focus", [6, 13, 18, 23, 3]),
    ("Rainy Sundays", [0, 11, 22, 17, 10]),
    ("Road Trip", [19, 14, 9, 5, 15]),
]

STARRED_ALBUMS = [0, 3, 7, 12, 15, 21]
STARRED_ARTISTS = ["Lumen Harbor", "Kaito Verne", "Juno Halloway"]

AUDIO_SAMPLE_RATE = 8000


def slug(text):
    return re.sub(r"[^a-z0-9]+", "-", text.lower()).strip("-")


def iso(date):
    return date.strftime("%Y-%m-%dT%H:%M:%S.000Z")


def build_library():
    rng = random.Random(4533)
    now = datetime(2026, 10, 30, 12, tzinfo=timezone.utc)
    artists, albums, songs = {}, [], {}
    singles = TITLE_SINGLES[:]
    rng.shuffle(singles)

    for index, (artist_name, album_name, year, genre) in enumerate(ALBUMS):
        artist_id = "ar-" + slug(artist_name)
        album_id = "al-" + slug(album_name)
        artist = artists.setdefault(artist_id, {
            "id": artist_id, "name": artist_name, "coverArt": artist_id, "albumCount": 0,
            "sortName": re.sub(r"^the ", "", artist_name.lower()), "artistImageUrl": "",
        })
        artist["albumCount"] += 1
        artist.setdefault("albumIDs", []).append(album_id)

        track_count = rng.randint(8, 12)
        album_songs = []
        for track in range(1, track_count + 1):
            if rng.random() < 0.35 and singles:
                title = singles.pop()
            else:
                title = f"{rng.choice(TITLE_WORDS_A)} {rng.choice(TITLE_WORDS_B)}"
            song_id = f"{album_id}-{track:02d}"
            song = {
                "id": song_id, "title": title, "album": album_name, "albumId": album_id, "artist": artist_name,
                "artistId": artist_id, "track": track, "discNumber": 1, "year": year, "genre": genre,
                "duration": rng.randint(150, 330), "coverArt": album_id, "suffix": "wav",
                "contentType": "audio/wav", "bitRate": 1411, "size": 0,
            }
            songs[song_id] = song
            album_songs.append(song_id)

        created = now - timedelta(days=index * 9 + rng.randint(0, 6))
        album = {
            "id": album_id, "name": album_name, "artist": artist_name, "artistId": artist_id, "coverArt": album_id,
            "songCount": len(album_songs), "duration": sum(songs[s]["duration"] for s in album_songs),
            "year": year, "genre": genre, "created": iso(created),
            "sortName": re.sub(r"^the ", "", album_name.lower()), "songIDs": album_songs, "style": index,
        }
        if index in STARRED_ALBUMS:
            album["starred"] = iso(now - timedelta(days=index))
        albums.append(album)

    for name in STARRED_ARTISTS:
        artists["ar-" + slug(name)]["starred"] = iso(now - timedelta(days=3))
    for song_id in rng.sample(sorted(songs), 6):
        songs[song_id]["starred"] = iso(now - timedelta(days=rng.randint(1, 30)))

    playlists = []
    for index, (name, album_indexes) in enumerate(PLAYLISTS):
        entries = []
        for album_index in album_indexes:
            entries += rng.sample(albums[album_index]["songIDs"], 2)
        playlists.append({
            "id": f"pl-{index + 1}", "name": name, "owner": "demo", "public": True, "songCount": len(entries),
            "duration": sum(songs[s]["duration"] for s in entries), "coverArt": f"pl-{index + 1}",
            "created": iso(now - timedelta(days=60 + index)), "changed": iso(now - timedelta(days=index * 4)),
            "entryIDs": entries, "coverAlbums": [albums[i]["id"] for i in album_indexes[:4]],
        })

    return {"artists": list(artists.values()), "albums": albums, "songs": songs, "playlists": playlists}


def public(item, *private_keys):
    return {key: value for key, value in item.items() if key not in private_keys}


class Library:
    def __init__(self, data, directory):
        self.data = data
        self.directory = directory
        self.albums = {album["id"]: album for album in data["albums"]}
        self.artists = {artist["id"]: artist for artist in data["artists"]}
        self.playlists = {playlist["id"]: playlist for playlist in data["playlists"]}
        self.songs = data["songs"]

    def album(self, album):
        return public(album, "songIDs", "style")

    def artist(self, artist):
        return public(artist, "albumIDs")

    def album_list(self, kind, size, offset):
        albums = list(self.data["albums"])
        if kind == "newest":
            albums.sort(key=lambda album: album["created"], reverse=True)
        elif kind == "alphabeticalByArtist":
            albums.sort(key=lambda album: (self.artists[album["artistId"]]["sortName"], album["sortName"]))
        elif kind == "byYear":
            albums.sort(key=lambda album: album["year"])
        else:
            albums.sort(key=lambda album: album["sortName"])
        return {"albumList2": {"album": [self.album(album) for album in albums[offset:offset + size]]}}

    def artist_indexes(self):
        indexes = {}
        for artist in sorted(self.data["artists"], key=lambda artist: artist["sortName"]):
            indexes.setdefault(artist["sortName"][0].upper(), []).append(self.artist(artist))
        return {"artists": {"ignoredArticles": "The", "index": [
            {"name": name, "artist": artists} for name, artists in indexes.items()
        ]}}

    def search(self, query):
        query = query.strip('"').lower()
        matches = lambda text: query in text.lower()
        return {"searchResult3": {
            "artist": [self.artist(a) for a in self.data["artists"] if matches(a["name"])],
            "album": [self.album(a) for a in self.data["albums"] if matches(a["name"]) or matches(a["artist"])],
            "song": [s for s in self.songs.values() if matches(s["title"]) or matches(s["artist"])][:50],
        }}

    def starred(self):
        return {"starred2": {
            "artist": [self.artist(a) for a in self.data["artists"] if "starred" in a],
            "album": [self.album(a) for a in self.data["albums"] if "starred" in a],
            "song": [s for s in self.songs.values() if "starred" in s],
        }}

    def set_starred(self, query, starred):
        targets = [(self.songs, query.get("id")), (self.albums, query.get("albumId")),
                   (self.artists, query.get("artistId"))]
        for items, ids in targets:
            for item_id in ids or []:
                item = items.get(item_id)
                if not item:
                    continue
                if starred:
                    item["starred"] = iso(datetime.now(timezone.utc))
                else:
                    item.pop("starred", None)
        return {}

    def respond(self, endpoint, query):
        first = lambda name, default=None: query.get(name, [default])[0]
        if endpoint == "ping":
            return {}
        if endpoint == "getAlbumList2":
            return self.album_list(first("type"), int(first("size", 500)), int(first("offset", 0)))
        if endpoint == "getAlbum":
            album = self.albums[first("id")]
            return {"album": self.album(album) | {"song": [self.songs[s] for s in album["songIDs"]]}}
        if endpoint == "getArtists":
            return self.artist_indexes()
        if endpoint == "getArtist":
            artist = self.artists[first("id")]
            return {"artist": self.artist(artist) | {"album": [self.album(self.albums[a]) for a in artist["albumIDs"]]}}
        if endpoint == "search3":
            return self.search(first("query", ""))
        if endpoint == "getPlaylists":
            return {"playlists": {"playlist": [public(p, "entryIDs", "coverAlbums") for p in self.data["playlists"]]}}
        if endpoint == "getPlaylist":
            playlist = self.playlists[first("id")]
            return {"playlist": public(playlist, "entryIDs", "coverAlbums") | {
                "entry": [self.songs[s] for s in playlist["entryIDs"]]}}
        if endpoint == "getStarred2":
            return self.starred()
        if endpoint in ("star", "unstar"):
            return self.set_starred(query, endpoint == "star")
        if endpoint == "scrobble":
            return {}
        return None


def make_handler(library):
    class Handler(BaseHTTPRequestHandler):
        def do_GET(self):
            url = urlparse(self.path)
            endpoint = url.path.rsplit("/", 1)[-1].removesuffix(".view")
            query = parse_qs(url.query)
            if endpoint == "getCoverArt":
                return self.send_file(library.directory / "covers" / f"{query['id'][0]}.jpg", "image/jpeg")
            if endpoint in ("stream", "download"):
                song = library.songs.get(query.get("id", [""])[0])
                return self.send_data(silence(song["duration"] if song else 1), "audio/wav")
            try:
                payload = library.respond(endpoint, query)
            except KeyError:
                payload = None
            if payload is None:
                body = {"status": "failed", "version": "1.16.1", "error": {"code": 70, "message": "Not found"}}
            else:
                body = {"status": "ok", "version": "1.16.1", "type": "plinket-sample", **payload}
            self.send_bytes(json.dumps({"subsonic-response": body}).encode(), "application/json")

        def send_file(self, path, content_type):
            if not path.exists():
                self.send_error(404)
                return
            self.send_data(path.read_bytes(), content_type)

        def send_data(self, data, content_type):
            byte_range = self.headers.get("Range")
            if not byte_range:
                return self.send_bytes(data, content_type)
            start, _, end = byte_range.removeprefix("bytes=").partition("-")
            start = int(start or 0)
            end = min(int(end) if end else len(data) - 1, len(data) - 1)
            self.send_response(206)
            self.send_header("Content-Range", f"bytes {start}-{end}/{len(data)}")
            self.send_header("Accept-Ranges", "bytes")
            self.send_header("Content-Type", content_type)
            self.send_header("Content-Length", str(end - start + 1))
            self.end_headers()
            self.wfile.write(data[start:end + 1])

        def send_bytes(self, data, content_type):
            self.send_response(200)
            self.send_header("Content-Type", content_type)
            self.send_header("Content-Length", str(len(data)))
            self.send_header("Accept-Ranges", "bytes")
            self.end_headers()
            self.wfile.write(data)

        def log_message(self, format, *args):
            pass

    return Handler


def silence(seconds):
    """A silent WAV as long as the song, so the player's times match the track list."""
    buffer = io.BytesIO()
    with wave.open(buffer, "wb") as audio:
        audio.setnchannels(1)
        audio.setsampwidth(1)
        audio.setframerate(AUDIO_SAMPLE_RATE)
        audio.writeframes(b"\x80" * AUDIO_SAMPLE_RATE * seconds)
    return buffer.getvalue()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--dump", type=Path, help="write the library as JSON and exit")
    parser.add_argument("--data", type=Path, default=Path("build/sample-library"))
    parser.add_argument("--port", type=int, default=4533)
    args = parser.parse_args()

    if args.dump:
        args.dump.parent.mkdir(parents=True, exist_ok=True)
        args.dump.write_text(json.dumps(build_library(), indent=1))
        print(f"Wrote {args.dump}")
        return

    library = Library(build_library(), args.data)
    server = ThreadingHTTPServer(("127.0.0.1", args.port), make_handler(library))
    print(f"Serving the sample library on http://127.0.0.1:{args.port}")
    server.serve_forever()


if __name__ == "__main__":
    main()

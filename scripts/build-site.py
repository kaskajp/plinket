#!/usr/bin/env python3
"""Build the website with a changelog from published GitHub releases."""

import argparse
from datetime import datetime
from html import escape
import json
from pathlib import Path
import shutil
import subprocess


ROOT = Path(__file__).resolve().parent.parent
RELEASES_START = "<!-- releases:start -->"
RELEASES_END = "<!-- releases:end -->"


def fetch_releases(repository: str) -> list[dict]:
    result = subprocess.run(
        [
            "gh", "api", f"repos/{repository}/releases?per_page=100",
            "--paginate", "--slurp",
            "-H", "Accept: application/vnd.github.html+json",
        ],
        check=True,
        stdout=subprocess.PIPE,
        text=True,
    )
    return [release for page in json.loads(result.stdout) for release in page]


def release_html(release: dict) -> str:
    version = escape(release["tag_name"])
    url = escape(release["html_url"], quote=True)
    published = datetime.fromisoformat(release["published_at"].replace("Z", "+00:00"))
    date = published.strftime("%B %d, %Y").replace(" 0", " ")
    # GitHub renders and sanitizes Markdown via the HTML media type requested above.
    notes = release["body_html"] or "<p>No release notes were provided.</p>"
    return f"""<article class="release">
            <h2>{version}</h2>
            <p class="updated"><time datetime="{published.date().isoformat()}">{date}</time> · <a href="{url}">View on GitHub</a></p>
            <div class="release-notes">{notes}</div>
        </article>"""


def render_changelog(template: str, releases: list[dict]) -> str:
    published = [release for release in releases if not release["draft"] and not release["prerelease"]]
    published.sort(key=lambda release: release["published_at"], reverse=True)
    before, remaining = template.split(RELEASES_START)
    empty_state, after = remaining.split(RELEASES_END)
    content = "\n".join(release_html(release) for release in published) if published else empty_state.strip()
    return f"{before}{RELEASES_START}\n        {content}\n        {RELEASES_END}{after}"


def build_site(output: Path, releases: list[dict]) -> None:
    template = (ROOT / "docs/changelog/index.html").read_text()
    changelog = render_changelog(template, releases)
    shutil.copytree(ROOT / "docs", output, dirs_exist_ok=True)
    (output / "changelog/index.html").write_text(changelog)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repository", default="kaskajp/plinket")
    parser.add_argument("--output", type=Path, default=ROOT / "build/site")
    args = parser.parse_args()
    build_site(args.output, fetch_releases(args.repository))
    print(f"Website built in {args.output}")


if __name__ == "__main__":
    main()

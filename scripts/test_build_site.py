import importlib.util
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch


spec = importlib.util.spec_from_file_location("build_site", Path(__file__).with_name("build-site.py"))
site = importlib.util.module_from_spec(spec)
spec.loader.exec_module(site)


def release(tag: str, published: str, notes: str = "<p>Release notes.</p>") -> dict:
    return {
        "tag_name": tag,
        "published_at": published,
        "html_url": f"https://github.com/kaskajp/plinket/releases/tag/{tag}",
        "body_html": notes,
        "draft": False,
        "prerelease": False,
    }


class ChangelogTests(unittest.TestCase):
    def setUp(self) -> None:
        self.template = (site.ROOT / "docs/changelog/index.html").read_text()

    def test_published_releases_use_publication_order_and_render_notes(self) -> None:
        older = release("v2.0.0", "2026-10-01T12:00:00Z")
        newer = release("v1.1.1", "2026-11-06T12:00:00Z", "<h3>Fixed</h3><ul><li>Playback &amp; queue</li></ul>")

        result = site.render_changelog(self.template, [older, newer])

        self.assertLess(result.index("<h2>v1.1.1</h2>"), result.index("<h2>v2.0.0</h2>"))
        self.assertIn('<time datetime="2026-11-06">November 6, 2026</time>', result)
        self.assertIn(f'href="{newer["html_url"]}"', result)
        self.assertIn(newer["body_html"], result)
        self.assertNotIn('class="empty-state"', result)

    def test_drafts_and_prereleases_leave_empty_state(self) -> None:
        draft = release("draft", "2026-11-06T12:00:00Z") | {"draft": True, "published_at": None}
        prerelease = release("preview", "2026-11-06T12:00:00Z") | {"prerelease": True}

        result = site.render_changelog(self.template, [draft, prerelease])

        self.assertIn("No releases have been published yet.", result)
        self.assertNotIn('<article class="release">', result)

    def test_no_releases_preserves_empty_state(self) -> None:
        result = site.render_changelog(self.template, [])

        self.assertIn("No releases have been published yet.", result)

    def test_release_metadata_is_escaped_without_escaping_rendered_markdown(self) -> None:
        entry = release('v1.0.0 & "special"', "2026-11-06T12:00:00Z", '<p><a href="https://example.com">Details</a></p>')

        result = site.render_changelog(self.template, [entry])

        self.assertIn("<h2>v1.0.0 &amp; &quot;special&quot;</h2>", result)
        self.assertIn('tag/v1.0.0 &amp; &quot;special&quot;"', result)
        self.assertIn(entry["body_html"], result)

    def test_build_replaces_edited_notes_and_preserves_website_assets(self) -> None:
        entry = release("v1.0.0", "2026-11-06T12:00:00Z", "<p>Original notes.</p>")
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / "site"
            site.build_site(output, [entry])
            entry["body_html"] = "<p>Updated notes.</p>"

            site.build_site(output, [entry])

            result = (output / "changelog/index.html").read_text()
            self.assertIn("Updated notes.", result)
            self.assertNotIn("Original notes.", result)
            self.assertEqual((output / "CNAME").read_bytes(), (site.ROOT / "docs/CNAME").read_bytes())
            self.assertEqual((output / "icon.png").read_bytes(), (site.ROOT / "docs/icon.png").read_bytes())
            self.assertEqual((site.ROOT / "docs/changelog/index.html").read_text(), self.template)

    def test_missing_notes_have_a_clear_fallback(self) -> None:
        result = site.render_changelog(self.template, [release("v1.0.0", "2026-11-06T12:00:00Z", "")])

        self.assertIn("No release notes were provided.", result)

    def test_missing_rendered_notes_fails_instead_of_silently_omitting_them(self) -> None:
        entry = release("v1.0.0", "2026-11-06T12:00:00Z")
        del entry["body_html"]

        with self.assertRaises(KeyError):
            site.render_changelog(self.template, [entry])


class FetchTests(unittest.TestCase):
    def test_all_api_pages_are_combined(self) -> None:
        first = release("v2.0.0", "2026-11-06T12:00:00Z")
        second = release("v1.0.0", "2026-10-01T12:00:00Z")
        response = subprocess.CompletedProcess([], 0, json.dumps([[first], [second]]))
        with patch.object(site.subprocess, "run", return_value=response) as run:
            result = site.fetch_releases("kaskajp/plinket")

        self.assertEqual(result, [first, second])
        command = run.call_args.args[0]
        self.assertIn("--paginate", command)
        self.assertIn("Accept: application/vnd.github.html+json", command)
        self.assertTrue(run.call_args.kwargs["check"])

    def test_api_failure_aborts_build_instead_of_publishing_empty_state(self) -> None:
        with patch.object(site.subprocess, "run", side_effect=subprocess.CalledProcessError(1, "gh")):
            with self.assertRaises(subprocess.CalledProcessError):
                site.fetch_releases("kaskajp/plinket")


if __name__ == "__main__":
    unittest.main()

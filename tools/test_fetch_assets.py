"""Offline tests for fetch_assets.py (task 1.6; art-pass "Fresh checkout", "Listing the packs";
design.md K12). No test opens a network connection: every fetch goes through a fake opener that
serves fixture bytes, and 7-Zip through a fake runner.

Usage: python -I -m unittest discover -s tools -p 'test_fetch_assets.py'
"""
import contextlib
import datetime
import io
import json
import os
import pathlib
import subprocess
import sys
import tempfile
import unittest
import urllib.error
import zipfile

import fetch_assets

HERE = pathlib.Path(__file__).resolve().parent
REPO = HERE.parent
TODAY = datetime.date(2026, 11, 9)
ART_FOLDERS = {
    "oga/zelda-like", "oga/dawnlike", "oga/eldiran-shoreline",
    "itch/metrocity", "itch/scallywag-water-islands", "itch/scallywag-ships",
    "itch/tth-animals", "itch/kyrise-icons", "itch/shikashi-icons",
}
DIRECT_FOLDERS = {"oga/zelda-like", "oga/dawnlike", "oga/eldiran-shoreline"}
KENNEY_PACKS = {
    "roguelike-characters": "characters",
    "tiny-dungeon": "characters",
    "roguelike-rpg-pack": "tiles",
    "generic-items": "items",
    "ui-pack": "ui",
    "pixel-ui-pack": "ui",
    "interface-sounds": "audio_sfx",
    "impact-sounds": "audio_sfx",
    "particle-pack": "particles",
}
FONT_FILES = {"PressStart2P-Regular.ttf", "PressStart2P-OFL.txt", "PixelifySans[wght].ttf", "PixelifySans-OFL.txt"}
OGA_FILES = "https://opengameart.org/sites/default/files"


class FakeWeb:
    """An opener that serves fixture bytes by URL and fails like the network for any other URL."""

    def __init__(self, responses):
        self.responses = responses
        self.requested = []

    def open(self, request, timeout=None):
        url = getattr(request, "full_url", request)
        self.requested.append(url)
        if url not in self.responses:
            raise urllib.error.URLError(f"offline fixture has no {url}")
        return io.BytesIO(self.responses[url])


class NoNetwork:
    """An opener that fails the test if anything tries to use it."""

    def open(self, request, timeout=None):
        raise AssertionError(f"network used: {getattr(request, 'full_url', request)}")


def _zip(entries):
    buffer = io.BytesIO()
    with zipfile.ZipFile(buffer, "w") as archive:
        for name, data in entries.items():
            archive.writestr(name, data)
    return buffer.getvalue()


def _pack(folder):
    return next(pack for pack in fetch_assets.ART_PACKS if pack.folder == folder)


def _offline_web():
    """What a fresh checkout would read: every Kenney pack, every font and the OpenGameArt pages."""
    responses = {}
    for index, slug in enumerate(KENNEY_PACKS):
        page = f"https://kenney.nl/assets/{slug}"
        download_id = f"{index + 10:x}"
        zip_url = f"https://kenney.nl/media/{slug}.zip"
        responses[page] = f"<a data-download-id='{download_id}'>Download</a>".encode()
        responses[f"https://kenney.nl/download-link/{download_id}"] = json.dumps({"url": zip_url}).encode()
        responses[zip_url] = _zip({"License.txt": b"CC0", f"{slug}/tile.png": b"png"})
    for url in fetch_assets.FONTS.values():
        responses[url] = b"font bytes"
    for pack in fetch_assets.ART_PACKS:
        if not pack.direct:
            continue
        links = "".join(f'<a href="{OGA_FILES}/{archive.name}">{archive.name}</a>' for archive in pack.archives)
        responses[pack.page] = f"<html><body>{links}</body></html>".encode()
        for archive in pack.archives:
            data = _zip({f"{archive.into}-root/sheet.png": b"png"}) if archive.kind == "zip" else b"\x89PNG fixture"
            responses[f"{OGA_FILES}/{archive.name}"] = data
    return responses


def _run(argv, opener, **kwargs):
    out = io.StringIO()
    with contextlib.redirect_stdout(out):
        code = fetch_assets.main(argv, opener=opener, today=TODAY, **kwargs)
    return code, out.getvalue()


def _no_7zip():
    return None


class TableTest(unittest.TestCase):
    def test_the_table_holds_the_nine_art_packs(self):
        packs = fetch_assets.ART_PACKS
        self.assertEqual(len(packs), 9)
        self.assertEqual({pack.folder for pack in packs}, ART_FOLDERS)
        self.assertEqual(len({pack.key for pack in packs}), 9)
        for pack in packs:
            with self.subTest(pack=pack.key):
                self.assertTrue(pack.name and pack.author and pack.licence)
                self.assertTrue(pack.page.startswith("https://"))
                self.assertTrue(pack.archives)
                for archive in pack.archives:
                    self.assertIn(archive.kind, ("zip", "rar", "file"))
                    self.assertEqual(archive.into == "", archive.kind == "file")
                self.assertEqual(pack.direct, pack.folder in DIRECT_FOLDERS)

    def test_the_cc_by_packs_say_so_and_the_others_are_cc0(self):
        cc_by = {"oga/dawnlike", "itch/tth-animals", "itch/kyrise-icons", "itch/shikashi-icons"}
        for pack in fetch_assets.ART_PACKS:
            with self.subTest(pack=pack.key):
                wording = pack.licence.replace("-", " ")
                self.assertTrue(wording.startswith("CC BY 4.0" if pack.folder in cc_by else "CC0"), pack.licence)

    def test_the_table_agrees_with_the_credits_and_the_assets_doc(self):
        credits = (REPO / "game" / "assets" / "CREDITS.md").read_text(encoding="utf-8")
        assets = (REPO / "docs" / "ASSETS.md").read_text(encoding="utf-8")
        for pack in fetch_assets.ART_PACKS:
            with self.subTest(pack=pack.key):
                rows = [line for line in credits.splitlines() if line.startswith("|") and f"`{pack.folder}/`" in line]
                self.assertTrue(any(pack.page in row for row in rows), f"CREDITS.md has no row for {pack.folder}/ with {pack.page}")
                self.assertIn(f"`{pack.folder}/`", assets)

    def test_the_kenney_packs_and_fonts_are_unchanged(self):
        self.assertEqual(fetch_assets.PACKS, KENNEY_PACKS)
        self.assertEqual(set(fetch_assets.FONTS), FONT_FILES)


class ListTest(unittest.TestCase):
    def test_list_prints_every_art_pack_with_folder_and_licence_then_kenney_and_fonts(self):
        code, out = _run(["--list"], NoNetwork())
        self.assertEqual(code, 0)
        lines = out.splitlines()
        for pack in fetch_assets.ART_PACKS:
            with self.subTest(pack=pack.key):
                self.assertTrue(any(pack.folder in line and pack.licence in line for line in lines), out)
        art = out.index("Art packs")
        kenney = out.index("Kenney packs")
        fonts = out.index("Fonts")
        self.assertLess(art, kenney)
        self.assertLess(kenney, fonts)
        for slug, sub in KENNEY_PACKS.items():
            self.assertIn(f"kenney/{sub}/{slug}", out[kenney:fonts])
        for name in FONT_FILES:
            self.assertIn(name, out[fonts:])

    def test_the_list_command_runs_as_written(self):
        result = subprocess.run([sys.executable, "-I", str(HERE / "fetch_assets.py"), "--list"], capture_output=True, text=True, encoding="utf-8")
        self.assertEqual(result.returncode, 0, result.stderr)
        for folder in ART_FOLDERS:
            self.assertIn(folder, result.stdout)


class FreshCheckoutTest(unittest.TestCase):
    def test_a_fresh_checkout_fetches_what_it_can_prints_the_rest_and_exits_non_zero(self):
        web = FakeWeb(_offline_web())
        with tempfile.TemporaryDirectory() as tmp:
            dest = pathlib.Path(tmp) / "assets"
            code, out = _run(["--dest", str(dest)], web, find_7zip=_no_7zip)
            self.assertEqual(code, 1, out)
            for slug, sub in KENNEY_PACKS.items():
                self.assertTrue((dest / "kenney" / sub / slug / "License.txt").is_file(), slug)
            for name in FONT_FILES:
                self.assertTrue((dest / "fonts" / name).is_file(), name)
            for pack in fetch_assets.ART_PACKS:
                folder = dest / pack.folder
                with self.subTest(pack=pack.key):
                    if pack.direct:
                        self._assert_landed(pack, folder)
                    else:
                        self.assertFalse((folder / "License.txt").exists())
                        self.assertTrue(any(pack.page in line and pack.folder in line for line in out.splitlines()), out)
        self.assertFalse([url for url in web.requested if "itch.io" in url])

    def _assert_landed(self, pack, folder):
        licence = (folder / "License.txt").read_text(encoding="utf-8").splitlines()
        self.assertIn(f"source: {pack.page}", licence)
        self.assertIn(f"license: {pack.licence}", licence)
        self.assertIn("read: 2026-11-08", licence, "the date the licence wording was read, not the fetch date")
        self.assertIn("fetched: 2026-11-09", licence)
        for archive in pack.archives:
            self.assertTrue((folder / archive.name).is_file(), archive.name)
            if archive.kind == "zip":
                self.assertTrue((folder / "extracted" / archive.into / f"{archive.into}-root" / "sheet.png").is_file())

    def test_a_complete_checkout_skips_every_pack_and_exits_0(self):
        with tempfile.TemporaryDirectory() as tmp:
            dest = pathlib.Path(tmp)
            for slug, sub in KENNEY_PACKS.items():
                (dest / "kenney" / sub / slug).mkdir(parents=True)
            (dest / "fonts").mkdir()
            for name in FONT_FILES:
                (dest / "fonts" / name).write_bytes(b"font")
            for pack in fetch_assets.ART_PACKS:
                folder = dest / pack.folder
                folder.mkdir(parents=True)
                (folder / "License.txt").write_text("source: x\n", encoding="utf-8")
                for archive in pack.archives:
                    (folder / archive.name).write_bytes(b"archive")
                    if archive.kind != "file":
                        (folder / "extracted" / archive.into).mkdir(parents=True)
                        (folder / "extracted" / archive.into / "sheet.png").write_bytes(b"png")
            code, out = _run(["--dest", str(dest)], NoNetwork(), find_7zip=_no_7zip)
        self.assertEqual(code, 0, out)

    def test_dry_run_writes_nothing_opens_no_connection_and_exits_non_zero(self):
        with tempfile.TemporaryDirectory() as tmp:
            dest = pathlib.Path(tmp) / "assets"
            dest.mkdir()
            code, out = _run(["--dry-run", "--dest", str(dest)], NoNetwork(), find_7zip=_no_7zip)
            self.assertEqual(list(dest.rglob("*")), [])
        self.assertEqual(code, 1, out)
        for pack in fetch_assets.ART_PACKS:
            self.assertTrue(any(pack.page in line and pack.folder in line for line in out.splitlines()), pack.key)
        self.assertIn("kenney/characters/tiny-dungeon", out)


class ArtPackTest(unittest.TestCase):
    def _fetch(self, pack, dest, web=None, find_7zip=_no_7zip, runner=None):
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            steps = fetch_assets.fetch_art_pack(pack, dest, opener=web or NoNetwork(), sevenzip=find_7zip(), runner=runner, today=TODAY)
        return steps, out.getvalue()

    def test_a_zip_downloaded_by_hand_is_unpacked_on_the_next_run(self):
        pack = _pack("itch/tth-animals")
        with tempfile.TemporaryDirectory() as tmp:
            dest = pathlib.Path(tmp)
            folder = dest / pack.folder
            folder.mkdir(parents=True)
            (folder / pack.archives[0].name).write_bytes(_zip({"spritesheet.png": b"png"}))
            steps, out = self._fetch(pack, dest)
            self.assertEqual(steps, [], out)
            self.assertTrue((folder / "extracted" / "animals" / "spritesheet.png").is_file())
            licence = (folder / "License.txt").read_text(encoding="utf-8").splitlines()
            self.assertIn("read: 2026-11-08", licence)
            self.assertIn("fetched: 2026-11-09", licence)

    def test_a_rar_without_7zip_is_a_manual_step_naming_its_folder(self):
        pack = _pack("itch/metrocity")
        with tempfile.TemporaryDirectory() as tmp:
            dest = pathlib.Path(tmp)
            folder = dest / pack.folder
            folder.mkdir(parents=True)
            for archive in pack.archives:
                (folder / archive.name).write_bytes(b"Rar!")
            steps, _out = self._fetch(pack, dest)
            self.assertEqual(len(steps), len(pack.archives))
            for archive, step in zip(pack.archives, steps):
                self.assertIn("7-Zip", step)
                self.assertIn((folder / "extracted" / archive.into).as_posix(), step)
            self.assertFalse((folder / "extracted").exists())
            self.assertFalse((folder / "License.txt").exists())

    def test_a_rar_is_unpacked_with_7zip_when_it_is_on_path(self):
        pack = _pack("itch/metrocity")
        calls = []

        def fake_7zip(args, **_kwargs):
            calls.append(args)
            out = pathlib.Path(next(arg[2:] for arg in args if arg.startswith("-o")))
            (out / "inner").mkdir(parents=True)
            (out / "inner" / "Character Model.png").write_bytes(b"png")
            return subprocess.CompletedProcess(args, 0)

        with tempfile.TemporaryDirectory() as tmp:
            dest = pathlib.Path(tmp)
            folder = dest / pack.folder
            folder.mkdir(parents=True)
            for archive in pack.archives:
                (folder / archive.name).write_bytes(b"Rar!")
            steps, out = self._fetch(pack, dest, find_7zip=lambda: "7z", runner=fake_7zip)
            self.assertEqual(steps, [], out)
            for archive in pack.archives:
                self.assertTrue((folder / "extracted" / archive.into / "inner" / "Character Model.png").is_file())
            self.assertTrue((folder / "License.txt").is_file())
        self.assertEqual([call[:3] for call in calls], [["7z", "x", "-y"]] * len(pack.archives))
        self.assertEqual([call[-1] for call in calls], [str(folder / archive.name) for archive in pack.archives])

    def test_a_rar_that_unpacks_nothing_fails_and_leaves_nothing_behind(self):
        pack = _pack("itch/metrocity")
        with tempfile.TemporaryDirectory() as tmp:
            dest = pathlib.Path(tmp)
            folder = dest / pack.folder
            folder.mkdir(parents=True)
            for archive in pack.archives:
                (folder / archive.name).write_bytes(b"Rar!")
            steps, _out = self._fetch(pack, dest, find_7zip=lambda: "7z", runner=lambda args, **_kw: subprocess.CompletedProcess(args, 0))
            self.assertEqual(len(steps), len(pack.archives))
            self.assertEqual(sorted(path.name for path in (folder / "extracted").iterdir()), [])
            self.assertFalse((folder / "License.txt").exists())

    @unittest.skipUnless(hasattr(os, "symlink"), "no symlinks here")
    def test_a_rar_that_unpacks_a_link_fails_and_leaves_nothing_behind(self):
        pack = _pack("itch/metrocity")

        def linking_7zip(args, **_kwargs):
            out = pathlib.Path(next(arg[2:] for arg in args if arg.startswith("-o")))
            (out / "sheet.png").write_bytes(b"png")
            os.symlink(out.parent.parent, out / "escape")
            return subprocess.CompletedProcess(args, 0)

        with tempfile.TemporaryDirectory() as tmp:
            dest = pathlib.Path(tmp)
            folder = dest / pack.folder
            folder.mkdir(parents=True)
            (folder / pack.archives[0].name).write_bytes(b"Rar!")
            try:
                os.symlink(folder, dest / "probe")
            except OSError:
                self.skipTest("this account cannot make symlinks")
            steps, _out = self._fetch(pack, dest, find_7zip=lambda: "7z", runner=linking_7zip)
            self.assertTrue(any("link" in step for step in steps), steps)
            self.assertEqual(list((folder / "extracted").iterdir()), [])

    def test_an_unsafe_zip_from_a_page_fails_and_leaves_nothing_behind(self):
        pack = _pack("oga/zelda-like")
        archive = pack.archives[0]
        web = FakeWeb({
            pack.page: f'<a href="{OGA_FILES}/{archive.name}">x</a>'.encode(),
            f"{OGA_FILES}/{archive.name}": _zip({"../escaped.txt": b"x"}),
        })
        with tempfile.TemporaryDirectory() as tmp:
            dest = pathlib.Path(tmp)
            steps, _out = self._fetch(pack, dest, web)
            folder = dest / pack.folder
            self.assertEqual(len(steps), 1)
            self.assertIn(pack.page, steps[0])
            self.assertFalse((folder / "extracted" / archive.into).exists())
            self.assertFalse((folder / "escaped.txt").exists())
            self.assertFalse((folder / "License.txt").exists())

    def test_a_page_without_the_file_link_is_a_manual_step_naming_the_page_and_folder(self):
        pack = _pack("oga/dawnlike")
        web = FakeWeb({pack.page: b"<html>no files here</html>"})
        with tempfile.TemporaryDirectory() as tmp:
            dest = pathlib.Path(tmp)
            steps, _out = self._fetch(pack, dest, web)
            self.assertEqual(len(steps), 1)
            self.assertIn(pack.page, steps[0])
            self.assertIn((dest / pack.folder).as_posix(), steps[0])
        self.assertEqual(web.requested, [pack.page])


class FileLinkTest(unittest.TestCase):
    PAGE = "https://opengameart.org/node/144858"

    def test_an_absolute_or_relative_link_with_the_file_name_is_found(self):
        html = '<a href="/sites/default/files/other.png">o</a><a href="/sites/default/files/cc0waveanimtiles16x16.png">w</a>'
        self.assertEqual(fetch_assets.find_file_link(html, self.PAGE, "cc0waveanimtiles16x16.png"), f"{OGA_FILES}/cc0waveanimtiles16x16.png")
        html = f'<a href="{OGA_FILES}/DawnLike_5.zip">d</a>'
        self.assertEqual(fetch_assets.find_file_link(html, self.PAGE, "DawnLike_5.zip"), f"{OGA_FILES}/DawnLike_5.zip")

    def test_an_escaped_file_name_matches(self):
        html = '<a href="/files/Tiny%2C%20Heroes.zip?x=1&amp;y=2">t</a>'
        self.assertEqual(fetch_assets.find_file_link(html, self.PAGE, "Tiny, Heroes.zip"), "https://opengameart.org/files/Tiny%2C%20Heroes.zip?x=1&y=2")

    def test_a_link_to_another_host_or_over_http_is_never_followed(self):
        html = '<a href="https://example.com/gfx_3.zip">a</a><a href="http://opengameart.org/gfx_3.zip">b</a>'
        self.assertIsNone(fetch_assets.find_file_link(html, self.PAGE, "gfx_3.zip"))

    def test_a_missing_file_gives_none(self):
        self.assertIsNone(fetch_assets.find_file_link("<a href='/a.zip'>a</a>", self.PAGE, "gfx_3.zip"))


if __name__ == "__main__":
    unittest.main()

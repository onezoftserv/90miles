"""Tests for check.py: the palette, alpha, outline, import and licence rules (task 1.5), on the
tracked art, on the GUT fixtures and on scratch folders."""
import pathlib
import subprocess
import sys
import tempfile
import unittest

import check
import palette
import png

HERE = pathlib.Path(__file__).resolve().parent
ART = palette.ART
FIXTURES = palette.GAME / "tests" / "fixtures" / "art"
## Each fixture a check.py rule must name (the others are for GUT-only checks: silhouettes,
## water contrast, sea in land tiles and frame budgets).
NAMED_FIXTURES = [
    "licence/no_licence", "licence/deed_only", "licence/vendor_only", "licence/no_source",
    "licence/own_work_url", "refs/unreferred.png", "creatures/off_palette.png", "items/half_alpha.png",
    "items/no_rim.png", "import/lossy.png", "import/mipmapped.png",
]
PASSING_FIXTURES = [
    "licence/good", "refs/referred.png", "items/rimmed.png", "items/twin_a.png", "shadows/half_alpha.png",
    "decals/shade.png", "creatures/fin_black.png", "creatures/strip5.png", "import/lossless.png",
]
OWN_WORK = "Work: fixture\nAuthor: 90 Millas\nLicence: All rights reserved (see LICENSE)\nSource: 90 Millas (own work)\nFiles: x\n"


def _command(*args):
    return subprocess.run([sys.executable, "-I", str(HERE / "check.py"), *map(str, args)], capture_output=True, text=True)


class TrackedArtTest(unittest.TestCase):
    def test_the_tracked_art_passes(self):
        self.assertEqual(check.check_tree(ART), [])

    def test_the_command_exits_0_on_the_tracked_art(self):
        result = _command(ART)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("0 problem(s)", result.stdout)

    def test_the_exemptions_name_existing_files_only(self):
        for relative in check.EXEMPT:
            self.assertTrue((ART / relative).exists(), f"{relative} is gone: drop it from check.EXEMPT")


class FixtureTest(unittest.TestCase):
    def setUp(self):
        self.problems = check.check_tree(FIXTURES)

    def test_each_fixture_is_named(self):
        text = "\n".join(self.problems)
        for fixture in NAMED_FIXTURES:
            self.assertIn(fixture, text)

    def test_the_passing_fixtures_are_not_named(self):
        for problem in self.problems:
            for fixture in PASSING_FIXTURES:
                self.assertNotIn(fixture + ":", problem)
                self.assertNotIn(fixture + "/", problem)

    def test_the_command_exits_non_zero_naming_each_fixture(self):
        result = _command(FIXTURES)
        self.assertNotEqual(result.returncode, 0)
        for fixture in NAMED_FIXTURES:
            self.assertIn(fixture, result.stdout)


class LicenceTest(unittest.TestCase):
    def test_blocks_start_at_pack_or_work_and_keep_their_own_keys(self):
        text = "\tVendor text\n\tLicense: CC0\n\thttp://creativecommons.org/publicdomain/zero/1.0/\n\nPack: P\nAuthor: A\nLicence: CC0 1.0\nSource: https://example.com/p\n\nWork: W\nLicence: x\nSource: 90 Millas (own work)\n"
        blocks = check.licence_blocks(text)
        self.assertEqual([b["kind"] for b in blocks], ["Pack", "Work"])
        self.assertEqual(blocks[0]["Source"], "https://example.com/p")
        self.assertEqual(check.licence_problems("f", text), [])

    def test_a_licence_deed_is_not_a_source(self):
        text = "Pack: P\nAuthor: A\nLicence: CC0 1.0\nSource: http://creativecommons.org/publicdomain/zero/1.0/\n"
        problems = check.licence_problems("folder", text)
        self.assertEqual(len(problems), 1)
        self.assertIn("'P'", problems[0])
        self.assertIn("deed", problems[0])

    def test_the_fixes_folder_gets_the_licence_rule_only(self):
        with tempfile.TemporaryDirectory() as scratch:
            fixes = pathlib.Path(scratch) / "fixes"
            fixes.mkdir()
            overlay = png.blank(4, 4)
            overlay.set(1, 1, (0xFF, 0x00, 0xFF, 255))  # the erase colour is never in the palette
            png.write_png(fixes / "body_x.png", overlay)
            problems = check.check_tree(fixes, licence_only=True)
            self.assertEqual(len(problems), 1)
            self.assertIn("License.txt", problems[0])
            (fixes / "License.txt").write_text(OWN_WORK, encoding="utf-8")
            self.assertEqual(check.check_tree(fixes, licence_only=True), [])

    def test_a_folder_under_tools_is_checked_for_its_licence_only(self):
        self.assertTrue(check.is_licence_only(HERE / "fixes"))
        self.assertFalse(check.is_licence_only(ART))


if __name__ == "__main__":
    unittest.main()

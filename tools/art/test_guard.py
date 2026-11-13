"""Tests for guard.py, the one out-folder guard every art tool imports (design.md K35): nothing is
written inside a download folder of the packs root."""
import pathlib
import tempfile
import unittest

import compose
import creatures
import guard
import items
import structures
import terrain


class GuardTest(unittest.TestCase):
    def test_a_path_inside_a_download_folder_is_refused_with_the_tools_own_error(self):
        with tempfile.TemporaryDirectory() as scratch:
            packs = pathlib.Path(scratch) / "packs"
            for folder in ("oga", "itch", "kenney"):
                with self.assertRaisesRegex(ValueError, f"inside the download folder {folder}/"):
                    guard.out_folder(packs / folder / "x" / "out", packs)

                class Mine(ValueError):
                    pass

                with self.assertRaises(Mine):
                    guard.out_folder(packs / folder, packs, Mine)

    def test_any_other_folder_comes_back_resolved(self):
        with tempfile.TemporaryDirectory() as scratch:
            packs = pathlib.Path(scratch) / "packs"
            self.assertEqual(guard.out_folder(pathlib.Path(scratch) / "out", packs), (pathlib.Path(scratch) / "out").resolve())
            self.assertEqual(guard.out_folder(packs / "other", packs), (packs / "other").resolve())

    def test_the_five_generators_use_this_one_guard(self):
        for tool in (terrain, creatures, items, structures, compose):
            self.assertIs(tool.guard, guard, f"{tool.__name__} imports guard")
        self.assertEqual(terrain.DOWNLOAD_FOLDERS, guard.DOWNLOAD_FOLDERS)


if __name__ == "__main__":
    unittest.main()

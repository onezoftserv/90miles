"""Tests for recordings.py, which trims the approved CC0 recordings into game sounds (openspec change
sound-pass, owner Q2 B). The shaping is checked on plain lists; the ffmpeg pass is checked on
synthetic WAVs in the downloads' own formats, and is skipped where ffmpeg is not installed.

Run: python -I -m unittest discover -s tools/audio -p "test_*.py"
"""
import math
import pathlib
import random
import shutil
import struct
import sys
import tempfile
import unittest

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))

import recordings  # noqa: E402
import sfx  # noqa: E402

RATE = sfx.RATE
HAS_FFMPEG = shutil.which("ffmpeg") is not None and shutil.which("ffprobe") is not None


def noise(n, seed=1, amp=0.3):
    rng = random.Random(seed)
    return [rng.uniform(-amp, amp) for _ in range(n)]


def write_wav(path, frames, rate, bits, floating):
    """A stereo WAV of `frames` [(left, right)], 32-bit float or 16/24-bit PCM."""
    width = bits // 8
    data = bytearray()
    for left, right in frames:
        for value in (left, right):
            if floating:
                data += struct.pack("<f", value)
            else:
                top = (1 << (bits - 1)) - 1
                data += int(round(max(-1.0, min(1.0, value)) * top)).to_bytes(width, "little", signed=True)
    fmt = struct.pack("<HHIIHH", 3 if floating else 1, 2, rate, rate * 2 * width, 2 * width, bits)
    body = b"WAVE" + b"fmt " + struct.pack("<I", len(fmt)) + fmt + b"data" + struct.pack("<I", len(data)) + bytes(data)
    pathlib.Path(path).write_bytes(b"RIFF" + struct.pack("<I", len(body)) + body)


class ShapingTest(unittest.TestCase):
    def test_level_meets_the_target_rms(self):
        samples, gain, capped = recordings.level([0.1, -0.1] * 100, 0.2)
        self.assertAlmostEqual(recordings.rms(samples), 0.2, places=6)
        self.assertAlmostEqual(gain, 2.0, places=6)
        self.assertFalse(capped)

    def test_level_holds_a_peak_under_the_cap(self):
        crack = [0.0] * 999 + [0.5]
        samples, _gain, capped = recordings.level(crack, 0.5)
        self.assertTrue(capped)
        self.assertAlmostEqual(max(abs(s) for s in samples), recordings.PEAK_CAP, places=6)

    def test_level_leaves_silence_alone(self):
        self.assertEqual(recordings.level([0.0] * 10, 0.2)[0], [0.0] * 10)

    def test_fade_starts_at_zero_and_ends_at_silence(self):
        out = recordings.fade([0.5] * RATE, 0.01, 0.5)
        self.assertEqual(out[0], 0.0)
        self.assertLess(abs(out[-1]), 1e-9)
        self.assertAlmostEqual(out[RATE // 4], 0.5)

    def test_window_levels_and_flattest(self):
        levels = [1.0, 0.2, 0.9, 0.5, 0.5, 0.5, 0.5, 0.1]
        self.assertEqual(recordings.flattest(levels, 4), 3)
        self.assertEqual(recordings.flattest([0.01, 0.01, 0.01, 0.5, 0.4, 0.5], 3, floor=0.2), 3)
        self.assertEqual(recordings.window_levels([0.5] * 100, 10 / RATE, RATE), [0.5] * 10)

    def test_a_loop_is_folded_to_a_clean_seam(self):
        rec = {"id": "sea", "loop": True, "length_s": 2.0, "crossfade_s": 0.5, "rms": 0.18}
        out = recordings.shape(rec, noise(int(2.5 * RATE)))
        self.assertEqual(len(out), 2 * RATE)
        self.assertTrue(sfx.seam_ok(out, RATE))
        self.assertAlmostEqual(recordings.rms(out), 0.18, places=3)

    def test_a_one_shot_ends_in_silence(self):
        rec = {"id": "thunder", "loop": False, "length_s": 1.0, "fade_out_s": 0.3, "rms": 0.1}
        out = recordings.shape(rec, noise(2 * RATE))
        self.assertEqual(len(out), RATE)
        self.assertLess(max(abs(s) for s in out[-32:]), 0.02)
        self.assertLess(abs(out[0]), 1e-9)

    def test_a_trim_past_the_end_fails(self):
        with self.assertRaises(ValueError):
            recordings.shape({"id": "sea", "loop": True, "length_s": 2.0, "crossfade_s": 0.5, "rms": 0.1}, noise(RATE))

    def test_the_params_name_three_cc0_recordings(self):
        recs = recordings.load_params()["recordings"]
        self.assertEqual(sorted(r["id"] for r in recs), ["sea", "thunder", "wind"])
        for rec in recs:
            self.assertEqual(rec["folder"], "loops" if rec["loop"] else "sfx", rec["id"])
            self.assertIn("CC0", rec["licence"], rec["id"])
            self.assertTrue(rec["page"].startswith("https://freesound.org/"), rec["id"])
            self.assertTrue(rec["source"].startswith(f"{rec['freesound_id']}__"), rec["id"])
            self.assertGreater(rec["expect_s"], rec["start_s"] + rec["length_s"] + rec.get("crossfade_s", 0.0), rec["id"])


@unittest.skipUnless(HAS_FFMPEG, "ffmpeg is not installed")
class FfmpegPassTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = pathlib.Path(self.tmp.name)
        (self.root / "raw").mkdir()

    def tearDown(self):
        self.tmp.cleanup()

    def rec(self, **fields):
        base = {"id": "sea", "folder": "loops", "loop": True, "source": "1__a__sea.wav", "freesound_id": 1,
                "expect_s": 4.0, "start_s": 0.5, "length_s": 2.0, "crossfade_s": 0.5, "rms": 0.18}
        base.update(fields)
        return base

    def test_a_float_stereo_download_becomes_a_mono_loop(self):
        left, right = noise(4 * 44100, 1), noise(4 * 44100, 2)
        write_wav(self.root / "raw" / "1__a__sea.wav", list(zip(left, right)), 44100, 32, True)
        path, notes = recordings.prepare(self.rec(), self.root / "raw", self.root / "out")
        self.assertEqual(path, self.root / "out" / "loops" / "sea.wav")
        rate, ints = sfx.read_wav(path.read_bytes())
        self.assertEqual(rate, RATE)
        self.assertEqual(len(ints), 2 * RATE)
        samples = [v / 32767 for v in ints]
        self.assertTrue(sfx.seam_ok(samples, RATE), notes)
        self.assertAlmostEqual(recordings.rms(samples), 0.18, places=2)
        self.assertIn("seam ok", notes)

    def test_a_24_bit_48k_download_is_found_by_its_number(self):
        left = noise(4 * 48000, 3)
        write_wav(self.root / "raw" / "1__renamed.wav", list(zip(left, left)), 48000, 24, False)
        rec = self.rec(id="thunder", folder="sfx", loop=False, fade_out_s=0.5, rms=0.1)
        rec.pop("crossfade_s")
        path, _notes = recordings.prepare(rec, self.root / "raw", self.root / "out")
        rate, ints = sfx.read_wav(path.read_bytes())
        self.assertEqual((rate, len(ints)), (RATE, 2 * RATE))
        self.assertLess(max(abs(v) for v in ints[-32:]), 0.02 * 32767)

    def test_a_download_of_the_wrong_length_is_refused(self):
        left = noise(2 * 44100, 4)
        write_wav(self.root / "raw" / "1__a__sea.wav", list(zip(left, left)), 44100, 16, False)
        with self.assertRaises(ValueError):
            recordings.prepare(self.rec(), self.root / "raw", self.root / "out")

    def test_a_missing_download_names_itself(self):
        with self.assertRaises(FileNotFoundError):
            recordings.prepare(self.rec(), self.root / "raw", self.root / "out")
        self.assertFalse((self.root / "out").exists())

    def test_analyse_reports_the_flattest_take(self):
        quiet, loud = [0.01] * (2 * 44100), noise(2 * 44100, 5, 0.5)
        frames = list(zip(loud + quiet, loud + quiet))
        write_wav(self.root / "raw" / "1__a__sea.wav", frames, 44100, 16, False)
        lines = recordings.analyse(self.rec(length_s=1.0, crossfade_s=0.0), self.root / "raw")
        self.assertIn("  flattest 1.0 s starts at 0.0 s", lines)


if __name__ == "__main__":
    unittest.main()

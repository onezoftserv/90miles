"""Tests for recording.py, which turns an approved CC0 recording into the game's WAV (openspec change
sound-pass task 9.3, owner Q2 B). The raw downloads are git-ignored, so these tests build their own
small WAVs in a temporary folder and never need the real files.

Run: python -I -m unittest discover -s tools/audio -p "test_*.py"
"""
import io
import json
import math
import pathlib
import random
import sys
import tempfile
import unittest
import wave

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))

import recording  # noqa: E402
import sfx  # noqa: E402

RATE = sfx.RATE


def make_wav(path, rate, channels, width, frames):
    """frames: a list of per-channel float tuples in -1..1, written as `width`-byte PCM."""
    top = (1 << (8 * width - 1)) - 1
    data = bytearray()
    for frame in frames:
        for value in frame:
            if width == 1:
                data += bytes([max(0, min(255, int(round(value * 127)) + 128))])
            else:
                data += max(-top - 1, min(top, int(round(value * top)))).to_bytes(width, "little", signed=True)
    with wave.open(str(path), "wb") as writer:
        writer.setnchannels(channels)
        writer.setsampwidth(width)
        writer.setframerate(rate)
        writer.writeframes(bytes(data))


def surf(rate, seconds, channels=2, seed=1):
    """Rough brown noise, a stand-in for the sea."""
    rng = random.Random(seed)
    level = 0.0
    frames = []
    for _ in range(int(rate * seconds)):
        level = max(-0.6, min(0.6, level * 0.999 + rng.uniform(-0.02, 0.02)))
        frames.append(tuple(level for _ in range(channels)))
    return frames


def entry(**fields):
    base = {
        "id": "sea", "folder": "loops", "source": "sea_raw.wav", "loop": True,
        "start_s": 0.5, "length_s": 2.0, "crossfade_s": 0.5,
        "author": "Someone", "licence": "CC0 1.0", "url": "https://freesound.org/people/someone/sounds/1/",
        "title": "Calm surf",
    }
    base.update(fields)
    return base


class ReadTest(unittest.TestCase):
    def test_every_pcm_width_and_stereo_reads_as_mono_floats(self):
        with tempfile.TemporaryDirectory() as tmp:
            for width in (1, 2, 3, 4):
                path = pathlib.Path(tmp) / f"w{width}.wav"
                make_wav(path, 8000, 2, width, [(0.5, -0.5), (0.25, 0.25), (-1.0, -1.0)])
                rate, mono = recording.read_audio(path.read_bytes())
                self.assertEqual(rate, 8000)
                self.assertEqual(len(mono), 3)
                self.assertAlmostEqual(mono[0], 0.0, delta=0.01, msg=f"width {width}: the channels average")
                self.assertAlmostEqual(mono[1], 0.25, delta=0.01, msg=f"width {width}")
                self.assertAlmostEqual(mono[2], -1.0, delta=0.01, msg=f"width {width}")

    def test_a_file_that_is_not_a_wav_says_to_export_one(self):
        with self.assertRaises(ValueError) as caught:
            recording.read_audio(b"fLaC\x00\x00\x00\x22")
        self.assertIn("WAV", str(caught.exception))


class ResampleTest(unittest.TestCase):
    def test_a_tone_keeps_its_pitch_and_length(self):
        src = 44100
        tone = [math.sin(2.0 * math.pi * 441.0 * i / src) for i in range(src)]
        out = recording.resample(tone, src, RATE)
        self.assertAlmostEqual(len(out), RATE, delta=1)
        crossings = sum(1 for a, b in zip(out, out[1:]) if (a < 0.0) != (b < 0.0))
        self.assertAlmostEqual(crossings, 882, delta=4)

    def test_the_same_rate_is_left_alone(self):
        samples = [0.1, -0.2, 0.3]
        self.assertEqual(recording.resample(samples, RATE, RATE), samples)

    def test_a_tone_above_the_new_limit_is_damped(self):
        src = 48000
        hiss = [math.sin(2.0 * math.pi * 15000.0 * i / src) for i in range(src)]
        out = recording.resample(hiss, src, RATE)
        level = math.sqrt(sum(s * s for s in out) / len(out))
        self.assertLess(level, 0.25, "15 kHz cannot be held at 22 050 Hz and must not fold back loud")


class PrepareTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = pathlib.Path(self.tmp.name)

    def tearDown(self):
        self.tmp.cleanup()

    def test_a_loop_has_its_length_its_peak_and_a_smooth_seam(self):
        make_wav(self.root / "sea_raw.wav", 44100, 2, 2, surf(44100, 4.0))
        samples = recording.prepare(entry(), (self.root / "sea_raw.wav").read_bytes())
        self.assertEqual(len(samples), 2 * RATE)
        self.assertAlmostEqual(max(abs(s) for s in samples), sfx.DEFAULT_PEAK, delta=1e-9)
        self.assertTrue(sfx.seam_ok(samples, RATE))

    def test_a_one_shot_fades_in_and_out(self):
        tone = [(0.8 * math.sin(2.0 * math.pi * 200.0 * i / RATE),) for i in range(RATE * 2)]
        make_wav(self.root / "thunder_raw.wav", RATE, 1, 2, tone)
        sound = entry(id="thunder", folder="sfx", source="thunder_raw.wav", loop=False, start_s=0.0,
                      length_s=1.0, fade_out_s=0.2)
        samples = recording.prepare(sound, (self.root / "thunder_raw.wav").read_bytes())
        self.assertEqual(len(samples), RATE)
        self.assertLess(abs(samples[0]), 0.01)
        self.assertLess(max(abs(s) for s in samples[-32:]), 0.02, "the one-shot ends in silence")

    def test_a_cut_past_the_end_of_the_file_is_refused(self):
        make_wav(self.root / "sea_raw.wav", RATE, 1, 2, surf(RATE, 1.0, channels=1))
        with self.assertRaises(ValueError) as caught:
            recording.prepare(entry(start_s=0.5, length_s=2.0), (self.root / "sea_raw.wav").read_bytes())
        self.assertIn("sea", str(caught.exception))

    def test_two_runs_are_byte_identical(self):
        make_wav(self.root / "sea_raw.wav", 48000, 2, 3, surf(48000, 3.0))
        data = (self.root / "sea_raw.wav").read_bytes()
        self.assertEqual(sfx.wav_bytes(recording.prepare(entry(), data)), sfx.wav_bytes(recording.prepare(entry(), data)))


class ListTest(unittest.TestCase):
    def test_only_cc0_with_an_author_and_a_page_is_accepted(self):
        self.assertEqual(recording.problems([entry()]), [])
        bad = recording.problems([
            entry(licence="CC BY 4.0"),
            entry(id="wind", author=""),
            entry(id="thunder", folder="sfx", loop=False, url="freesound.org/x"),
            entry(id="kraken"),
        ])
        text = "\n".join(bad)
        self.assertIn("sea: licence must be CC0", text)
        self.assertIn("wind: no author", text)
        self.assertIn("thunder: url must be an https:// source page", text)
        self.assertIn("kraken: not one of", text)

    def test_the_tracked_list_is_valid_and_names_only_the_three(self):
        recordings = recording.load_recordings()
        self.assertEqual(recording.problems(recordings), [])
        self.assertLessEqual({r["id"] for r in recordings}, set(recording.REPLACEABLE))

    def test_every_listed_recording_is_tracked_and_in_shape(self):
        """The raw downloads are git-ignored, so the tracked game files are what CI can check."""
        for rec in recording.load_recordings():
            path = sfx.DEFAULT_OUT / rec["folder"] / f"{rec['id']}.wav"
            self.assertTrue(path.exists(), f"{path} is missing: run python -I tools/audio/recording.py")
            rate, ints = sfx.read_wav(path.read_bytes())
            samples = [v / 32767 for v in ints]
            self.assertEqual(rate, RATE, rec["id"])
            self.assertEqual(len(samples), round(float(rec["length_s"]) * RATE), rec["id"])
            self.assertLess(max(abs(s) for s in samples), 0.99, rec["id"])
            if rec.get("loop"):
                self.assertTrue(sfx.seam_ok(samples, RATE), f"{rec['id']} clicks at its seam")
            else:
                self.assertLess(max(abs(s) for s in samples[-32:]), 0.02, f"{rec['id']} ends with a click")

    def test_a_missing_download_names_the_file_and_folder(self):
        with tempfile.TemporaryDirectory() as tmp:
            with self.assertRaises(FileNotFoundError) as caught:
                recording.build([entry()], raw_root=pathlib.Path(tmp) / "ambience", out_root=pathlib.Path(tmp) / "out")
            self.assertIn("sea_raw.wav", str(caught.exception))
            self.assertIn("ambience", str(caught.exception))

    def test_build_writes_the_game_file_in_place_of_the_placeholder(self):
        with tempfile.TemporaryDirectory() as tmp:
            raw = pathlib.Path(tmp) / "ambience"
            raw.mkdir()
            make_wav(raw / "sea_raw.wav", 44100, 2, 2, surf(44100, 4.0))
            written = recording.build([entry()], raw_root=raw, out_root=pathlib.Path(tmp) / "out")
            self.assertEqual([p.relative_to(pathlib.Path(tmp) / "out").as_posix() for p in written], ["loops/sea.wav"])
            with wave.open(str(written[0])) as reader:
                self.assertEqual((reader.getnchannels(), reader.getsampwidth(), reader.getframerate()), (1, 2, RATE))

    def test_the_credits_text_is_a_pack_block_and_a_table_row(self):
        block, row = recording.credits(entry())
        self.assertTrue(block.startswith("Pack: Calm surf"))
        for line in ("Author: Someone", "Licence: CC0 1.0", "Source: https://freesound.org/people/someone/sounds/1/", "Files: sea.wav"):
            self.assertIn(line, block)
        self.assertIn("`audio/loops/`: `sea.wav`", row)
        self.assertIn("CC0 1.0", row)


class RecipeTest(unittest.TestCase):
    def test_a_recorded_id_is_skipped_by_the_generator(self):
        recipe = sfx.load_recipe()
        with tempfile.TemporaryDirectory() as tmp:
            listing = pathlib.Path(tmp) / "recordings.json"
            listing.write_text(json.dumps({"recordings": [entry()]}))
            skipped = recording.recorded_ids(listing)
            self.assertEqual(skipped, {"sea"})
            written = sfx.build(recipe, pathlib.Path(tmp) / "out", only={"sea", "pickup"}, skip=skipped)
            self.assertEqual([p.name for p in written], ["pickup.wav"])


if __name__ == "__main__":
    unittest.main()

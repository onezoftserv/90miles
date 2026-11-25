"""Tests for sfx.py, the retro sound generator (openspec change sound-pass D1). They stand in for
ears: every sound in sounds.json is checked for level, clipping, length and, for loops, a seam
no worse than any ordinary step; and the tracked WAVs are checked against a fresh render.

Run: python -I -m unittest discover -s tools/audio -p "test_*.py"
"""
import io
import math
import pathlib
import sys
import tempfile
import unittest
import wave

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))

import sfx  # noqa: E402

RATE = sfx.RATE
# The twelve generated ids. sea, wind and thunder are CC0 recordings (owner Q2 B), made by
# recordings.py; test_recordings checks that the two lists cover the fifteen spec ids once each.
GENERATED_IDS = {
    "night", "patrol_motor",
    "pickup", "hurt_hit", "hurt_big", "hurt_drain", "use_done",
    "thirst_low", "raft_hit", "loudhailer", "arrival", "compass_rattle",
}
LOOPS = {"night", "patrol_motor"}


def rms(samples):
    return math.sqrt(sum(s * s for s in samples) / max(len(samples), 1))


def zero_crossings(samples):
    return sum(1 for a, b in zip(samples, samples[1:]) if (a < 0.0) != (b < 0.0))


def part(**fields):
    base = {"length": 0.5}
    base.update(fields)
    return base


class VoiceTest(unittest.TestCase):
    """The oscillators and their shapes."""

    def test_a_square_at_441_hz_crosses_zero_twice_a_cycle(self):
        samples = sfx.render_part(part(wave="square", freq=441.0, length=1.0), RATE)
        self.assertAlmostEqual(zero_crossings(samples), 882, delta=2)
        self.assertEqual({round(s, 6) for s in samples}, {1.0, -1.0})

    def test_a_square_duty_sets_the_share_of_high_samples(self):
        samples = sfx.render_part(part(wave="square", freq=441.0, duty=0.25, length=1.0), RATE)
        high = sum(1 for s in samples if s > 0.0) / len(samples)
        self.assertAlmostEqual(high, 0.25, delta=0.02, msg="within one sample of the 50-sample cycle")

    def test_triangle_and_sine_stay_in_range_and_have_the_frequency(self):
        for shape in ("triangle", "sine", "saw"):
            samples = sfx.render_part(part(wave=shape, freq=441.0, length=1.0), RATE)
            self.assertLessEqual(max(abs(s) for s in samples), 1.0 + 1e-9, shape)
            self.assertAlmostEqual(zero_crossings(samples), 882, delta=4, msg=shape)

    def test_noise_is_seeded_and_changes_at_its_rate(self):
        one = sfx.render_part(part(wave="noise", freq=2205.0, seed=7), RATE)
        two = sfx.render_part(part(wave="noise", freq=2205.0, seed=7), RATE)
        other = sfx.render_part(part(wave="noise", freq=2205.0, seed=8), RATE)
        self.assertEqual(one, two)
        self.assertNotEqual(one, other)
        changes = sum(1 for a, b in zip(one, one[1:]) if a != b)
        self.assertAlmostEqual(changes, 2205 * 0.5, delta=40, msg="a new value about every 10 samples")

    def test_brown_noise_is_darker_than_white(self):
        white = sfx.render_part(part(wave="noise", freq=RATE, seed=3, length=1.0), RATE)
        brown = sfx.render_part(part(wave="brown", seed=3, length=1.0), RATE)
        self.assertLess(zero_crossings(brown), zero_crossings(white) / 4)


class ShapeTest(unittest.TestCase):
    """Envelope, sweeps, steps, filters and the crush."""

    def test_the_envelope_rises_holds_and_releases_to_silence(self):
        env = {"attack": 0.1, "decay": 0.1, "sustain": 0.5, "release": 0.1}
        samples = sfx.render_part(part(wave="sine", freq=1000.0, length=1.0, env=env), RATE)
        attack = rms(samples[int(0.02 * RATE):int(0.04 * RATE)])
        hold = rms(samples[int(0.5 * RATE):int(0.6 * RATE)])
        peak = rms(samples[int(0.09 * RATE):int(0.11 * RATE)])
        self.assertLess(attack, peak)
        self.assertAlmostEqual(hold, 0.5 / math.sqrt(2.0), delta=0.02)
        self.assertLess(abs(samples[-1]), 0.01, "the release ends at silence")

    def test_a_sweep_down_lowers_the_pitch(self):
        samples = sfx.render_part(part(wave="sine", freq=800.0, to=200.0, length=1.0), RATE)
        first = zero_crossings(samples[: RATE // 4])
        last = zero_crossings(samples[-RATE // 4:])
        self.assertGreater(first, last * 2)

    def test_steps_change_the_pitch_at_their_times(self):
        samples = sfx.render_part(part(wave="square", freq=441.0, steps=[[0.5, 882.0]], length=1.0), RATE)
        self.assertAlmostEqual(zero_crossings(samples[: RATE // 2]), 441, delta=3)
        self.assertAlmostEqual(zero_crossings(samples[RATE // 2:]), 882, delta=3)

    def test_the_lowpass_takes_out_high_frequency_energy(self):
        raw = sfx.render_part(part(wave="noise", freq=RATE, seed=5, length=1.0), RATE)
        low = sfx.render_part(part(wave="noise", freq=RATE, seed=5, length=1.0, lowpass=500.0), RATE)
        self.assertLess(zero_crossings(low), zero_crossings(raw) / 2)

    def test_the_highpass_takes_out_the_low_end(self):
        raw = sfx.render_part(part(wave="sine", freq=60.0, length=1.0), RATE)
        high = sfx.render_part(part(wave="sine", freq=60.0, length=1.0, highpass=2000.0), RATE)
        self.assertLess(rms(high), rms(raw) / 10)

    def test_the_crush_leaves_few_levels(self):
        samples = sfx.render_part(part(wave="sine", freq=300.0, crush=3), RATE)
        self.assertLessEqual(len({round(s, 9) for s in samples}), 9)

    def test_a_repeat_plays_the_part_again_quieter(self):
        sound = {"id": "t", "folder": "sfx", "length_s": 0.4, "parts": [
            part(wave="square", freq=1000.0, length=0.05, repeat={"count": 3, "every_s": 0.1, "decay": 0.5}),
        ]}
        samples = sfx.render_sound(sound, RATE, normalise=False)
        bursts = [rms(samples[int(k * 0.1 * RATE):int((k * 0.1 + 0.05) * RATE)]) for k in range(3)]
        gaps = rms(samples[int(0.06 * RATE):int(0.09 * RATE)])
        self.assertAlmostEqual(bursts[1], bursts[0] * 0.5, delta=0.02)
        self.assertAlmostEqual(bursts[2], bursts[0] * 0.25, delta=0.02)
        self.assertEqual(gaps, 0.0)


class LoopTest(unittest.TestCase):
    def test_a_folded_loop_continues_across_its_seam(self):
        sound = {"id": "t", "folder": "loops", "length_s": 1.0, "loop": True, "crossfade_s": 0.25,
                 "parts": [part(wave="brown", seed=2, lowpass=800.0)]}
        samples = sfx.render_sound(sound, RATE)
        self.assertEqual(len(samples), RATE)
        self.assertTrue(sfx.seam_ok(samples, RATE), "the seam is no worse than an ordinary step")

    def test_a_cut_loop_fails_the_seam_check(self):
        samples = [math.sin(2.0 * math.pi * 3.3 * i / RATE) for i in range(RATE)]
        self.assertFalse(sfx.seam_ok(samples, RATE))


class WavTest(unittest.TestCase):
    def test_the_wav_is_mono_16_bit_at_the_rate_and_round_trips(self):
        samples = [0.0, 0.5, -0.5, 0.99, -0.99]
        data = sfx.wav_bytes(samples, RATE)
        with wave.open(io.BytesIO(data)) as reader:
            self.assertEqual((reader.getnchannels(), reader.getsampwidth(), reader.getframerate()), (1, 2, RATE))
            self.assertEqual(reader.getnframes(), len(samples))
        self.assertEqual(sfx.read_wav(data)[1], [round(s * 32767) for s in samples])


class RecipeTest(unittest.TestCase):
    """Every sound of the recipe, rendered once."""

    @classmethod
    def setUpClass(cls):
        cls.recipe = sfx.load_recipe()
        cls.sounds = {sound["id"]: sound for sound in cls.recipe["sounds"]}
        cls.rendered = {sid: sfx.render_sound(sound, RATE) for sid, sound in cls.sounds.items()}

    def test_the_recipe_has_the_twelve_generated_ids_in_their_folders(self):
        self.assertEqual(set(self.sounds), GENERATED_IDS)
        for sid, sound in self.sounds.items():
            self.assertEqual(sound["folder"], "loops" if sid in LOOPS else "sfx", sid)
            self.assertEqual(bool(sound.get("loop", False)), sid in LOOPS, sid)

    def test_no_sound_is_silent_or_clips(self):
        for sid, samples in self.rendered.items():
            self.assertGreater(rms(samples), 0.05, f"{sid} is too quiet")
            self.assertLess(max(abs(s) for s in samples), 0.99, f"{sid} clips")

    def test_every_sound_has_its_length(self):
        for sid, samples in self.rendered.items():
            self.assertEqual(len(samples), round(self.sounds[sid]["length_s"] * RATE), sid)

    def test_one_shots_end_in_silence(self):
        for sid, samples in self.rendered.items():
            if sid not in LOOPS:
                self.assertLess(max(abs(s) for s in samples[-32:]), 0.02, f"{sid} ends with a click")

    def test_loops_hold_their_seam(self):
        for sid in LOOPS:
            self.assertTrue(sfx.seam_ok(self.rendered[sid], RATE), f"{sid} clicks at its seam")

    def test_two_renders_are_byte_identical(self):
        for sid in ("night", "loudhailer"):
            again = sfx.render_sound(self.sounds[sid], RATE)
            self.assertEqual(sfx.wav_bytes(again, RATE), sfx.wav_bytes(self.rendered[sid], RATE), sid)

    def test_the_tracked_files_are_the_recipes(self):
        """Byte for byte on the machine that wrote them; elsewhere a different maths library may move
        a sample by one step of the last bit, never more."""
        for sid, samples in self.rendered.items():
            path = sfx.DEFAULT_OUT / self.sounds[sid]["folder"] / f"{sid}.wav"
            self.assertTrue(path.exists(), f"{path} is missing: run python -I tools/audio/sfx.py")
            rate, tracked = sfx.read_wav(path.read_bytes())
            self.assertEqual(rate, RATE, sid)
            fresh = sfx.read_wav(sfx.wav_bytes(samples, RATE))[1]
            self.assertEqual(len(tracked), len(fresh), sid)
            self.assertLessEqual(max(abs(a - b) for a, b in zip(tracked, fresh)), 1, sid)

    def test_build_writes_only_inside_out(self):
        with tempfile.TemporaryDirectory() as tmp:
            written = sfx.build(self.recipe, pathlib.Path(tmp), only={"pickup"})
            self.assertEqual([p.relative_to(tmp).as_posix() for p in written], ["sfx/pickup.wav"])
            self.assertEqual(sorted(p.relative_to(tmp).as_posix() for p in pathlib.Path(tmp).rglob("*") if p.is_file()), ["sfx/pickup.wav"])


if __name__ == "__main__":
    unittest.main()

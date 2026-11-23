"""Build the game's generated sounds (openspec change sound-pass D1): a small sfxr-style
synthesizer, standard library only.

From the recipe tools/audio/sounds.json it renders each sound and writes it as a 16-bit mono WAV
at 22 050 Hz to <--out>/<its "folder">/<its id>.wav, --out being game/assets/audio. Noise comes
from a seeded random.Random per part, so two runs give the same files byte for byte, and nothing
is written outside --out.

A sound: {id, folder ("sfx" or "loops"), length_s, parts, [loop, crossfade_s, crossfade, peak]}.
Its parts are mixed, each from its "start" (s) for its "length" (s; default: to the end). A loop
is rendered crossfade_s longer and its tail folded over its head ("power" or "linear" crossfade),
so the last sample runs straight on into the first. A loop's mix is DC-blocked; every mix is scaled so its peak
is `peak` (default 0.89): the game sets each sound's level in its sound bank, not here.

A part, in the order it is applied:
- wave: square [duty], triangle, sine, saw, noise (a new random value `freq` times a second, the
  sample-and-hold noise of old sound chips; freq = 22050 is white), brown (seeded, dark).
- freq (Hz, default 440), to (Hz: an exponential sweep over the part, or linear with
  "sweep": "lin"), steps ([[t, Hz], ...]: the pitch from each t on), vibrato {rate, depth}.
- highpass (Hz), lowpass (Hz, or a wander {min, max, min_s, max_s, seed}), poles (lowpass passes).
- crush (bits).
- env {attack, decay, sustain, release} (default flat), tremolo {rate, depth, [shape, duty]},
  gate {every_s, len_s, rate, duty, [offset_s]} (smooth pulses in bursts: insects),
  swell {min_s, max_s, floor, rise, seed} (waves arriving at random intervals), volume.
- repeat {count, every_s, decay}: the part again every every_s, each time `decay` times as loud.

Usage: python -I tools/audio/sfx.py [--recipe tools/audio/sounds.json] [--out game/assets/audio]
       [--only id,id] [--check]
"""
import argparse
import io
import json
import math
import pathlib
import random
import sys
import wave

HERE = pathlib.Path(__file__).resolve().parent
ROOT = HERE.parent.parent
DEFAULT_RECIPE = HERE / "sounds.json"
DEFAULT_OUT = ROOT / "game" / "assets" / "audio"
RATE = 22050
FOLDERS = ("sfx", "loops")
WAVES = ("square", "triangle", "sine", "saw", "noise", "brown")
DEFAULT_PEAK = 0.89
DC_BLOCK_R = 0.995
TAU = 2.0 * math.pi


def load_recipe(path=DEFAULT_RECIPE):
    with open(path, encoding="utf-8") as handle:
        return json.load(handle)


# --- one part ------------------------------------------------------------------------------------

def render_part(part, rate, default_length=None):
    """The part's samples, from its own start, `part["length"]` seconds long (or default_length)."""
    length = float(part.get("length", default_length if default_length is not None else 1.0))
    n = max(int(round(length * rate)), 0)
    shape = part.get("wave", "square")
    if shape not in WAVES:
        raise ValueError(f"unknown wave {shape!r}")
    rng = random.Random(int(part.get("seed", 1)))
    raw = _oscillate(part, shape, n, length, rate, rng)
    if "highpass" in part:
        raw = _highpass(raw, float(part["highpass"]), rate)
    if "lowpass" in part:
        cutoffs = _cutoffs(part["lowpass"], n, rate)
        for _ in range(int(part.get("poles", 1))):
            raw = _lowpass(raw, cutoffs, rate)
    if "crush" in part:
        steps = float(2 ** (int(part["crush"]) - 1))
        raw = [round(s * steps) / steps for s in raw]
    return _shape_amplitude(raw, part, length, rate)


def _pitch_at(part, t, length):
    steps = part.get("steps")
    if steps:
        freq = float(part.get("freq", 440.0))
        for at, value in steps:
            if t >= float(at):
                freq = float(value)
        return freq
    start = float(part.get("freq", 440.0))
    if "to" not in part or length <= 0.0:
        return start
    end = float(part["to"])
    k = min(max(t / length, 0.0), 1.0)
    if part.get("sweep", "exp") == "lin":
        return start + (end - start) * k
    return start * (end / start) ** k


def _oscillate(part, shape, n, length, rate, rng):
    out = [0.0] * n
    duty = float(part.get("duty", 0.5))
    vibrato = part.get("vibrato")
    phase = 0.0
    held = rng.uniform(-1.0, 1.0)
    brown = 0.0
    for i in range(n):
        t = i / rate
        if shape == "brown":
            brown = (brown + 0.02 * rng.uniform(-1.0, 1.0)) / 1.02
            out[i] = brown * 3.5
            continue
        freq = _pitch_at(part, t, length)
        if vibrato:
            freq *= 1.0 + float(vibrato["depth"]) * math.sin(TAU * float(vibrato["rate"]) * t)
        if shape == "noise":
            out[i] = held
        elif shape == "square":
            out[i] = 1.0 if phase < duty else -1.0
        elif shape == "triangle":
            out[i] = 1.0 - 4.0 * abs(phase - 0.5)
        elif shape == "sine":
            out[i] = math.sin(TAU * phase)
        else:
            out[i] = 2.0 * phase - 1.0
        phase += freq / rate
        if phase >= 1.0:
            phase -= math.floor(phase)
            if shape == "noise":
                held = rng.uniform(-1.0, 1.0)
    return out


def _cutoffs(spec, n, rate):
    if isinstance(spec, dict):
        return _wander(spec, n, rate)
    return [float(spec)] * n


def _lowpass(samples, cutoffs, rate):
    out = [0.0] * len(samples)
    y = 0.0
    last_fc = None
    a = 0.0
    for i, x in enumerate(samples):
        fc = cutoffs[i]
        if fc != last_fc:
            a = 1.0 - math.exp(-TAU * fc / rate)
            last_fc = fc
        y += a * (x - y)
        out[i] = y
    return out


def _highpass(samples, cutoff, rate):
    low = _lowpass(samples, [cutoff] * len(samples), rate)
    return [x - l for x, l in zip(samples, low)]


def _wander(spec, n, rate):
    """A smooth random curve between spec min and max, a new target every min_s..max_s seconds."""
    rng = random.Random(int(spec.get("seed", 1)))
    low, high = float(spec["min"]), float(spec["max"])
    points = [(0.0, rng.uniform(low, high))]
    total = n / rate
    while points[-1][0] <= total:
        points.append((points[-1][0] + rng.uniform(float(spec["min_s"]), float(spec["max_s"])), rng.uniform(low, high)))
    out = [0.0] * n
    k = 0
    for i in range(n):
        t = i / rate
        while points[k + 1][0] <= t:
            k += 1
        (t0, v0), (t1, v1) = points[k], points[k + 1]
        blend = 0.5 - 0.5 * math.cos(math.pi * (t - t0) / (t1 - t0))
        out[i] = v0 + (v1 - v0) * blend
    return out


def _swell_curve(spec, n, rate):
    """Waves arriving every min_s..max_s seconds: each rises from `floor` to its crest in `rise` of
    its time and ebbs back for the rest."""
    rng = random.Random(int(spec.get("seed", 1)))
    floor = float(spec.get("floor", 0.3))
    rise = float(spec.get("rise", 0.35))
    total = n / rate
    waves = []
    start = 0.0
    while start <= total:
        period = rng.uniform(float(spec["min_s"]), float(spec["max_s"]))
        waves.append((start, period, rng.uniform(0.7, 1.0)))
        start += period
    out = [0.0] * n
    k = 0
    for i in range(n):
        t = i / rate
        while waves[k][0] + waves[k][1] <= t:
            k += 1
        begin, period, crest = waves[k]
        x = (t - begin) / period
        if x < rise:
            level = 0.5 - 0.5 * math.cos(math.pi * x / rise)
        else:
            level = 0.5 + 0.5 * math.cos(math.pi * (x - rise) / (1.0 - rise))
        out[i] = floor + (crest - floor) * level
    return out


def _envelope(env, t, length):
    if not env:
        return 1.0
    attack = float(env.get("attack", 0.0))
    decay = float(env.get("decay", 0.0))
    sustain = float(env.get("sustain", 1.0))
    release = float(env.get("release", 0.0))
    if attack > 0.0 and t < attack:
        level = t / attack
    elif decay > 0.0 and t < attack + decay:
        level = 1.0 - (1.0 - sustain) * (t - attack) / decay
    else:
        level = sustain
    if release > 0.0 and t > length - release:
        level *= max(length - t, 0.0) / release
    return level


def _shape_amplitude(raw, part, length, rate):
    n = len(raw)
    env = part.get("env")
    tremolo = part.get("tremolo")
    gate = part.get("gate")
    swell = _swell_curve(part["swell"], n, rate) if "swell" in part else None
    volume = float(part.get("volume", 1.0))
    out = [0.0] * n
    for i in range(n):
        t = i / rate
        level = volume * _envelope(env, t, length)
        if tremolo:
            depth = float(tremolo["depth"])
            cycle = (float(tremolo["rate"]) * t) % 1.0
            if tremolo.get("shape", "sine") == "square":
                level *= 1.0 if cycle < float(tremolo.get("duty", 0.5)) else 1.0 - depth
            else:
                level *= 1.0 - depth * (0.5 + 0.5 * math.cos(TAU * cycle))
        if gate:
            local = (t - float(gate.get("offset_s", 0.0))) % float(gate["every_s"])
            if local >= float(gate["len_s"]):
                level = 0.0
            else:
                pulse = (local * float(gate["rate"])) % 1.0
                duty = float(gate.get("duty", 0.5))
                level *= math.sin(math.pi * pulse / duty) if pulse < duty else 0.0
        if swell is not None:
            level *= swell[i]
        out[i] = raw[i] * level
    return out


# --- one sound -----------------------------------------------------------------------------------

def render_sound(sound, rate=RATE, normalise=True):
    """The sound's samples, length_s long, mixed, folded if it loops, DC-blocked and scaled."""
    length = int(round(float(sound["length_s"]) * rate))
    loop = bool(sound.get("loop", False))
    fold = int(round(float(sound.get("crossfade_s", 0.0)) * rate)) if loop else 0
    total = length + fold
    mix = [0.0] * total
    for part in sound["parts"]:
        repeat = part.get("repeat") or {"count": 1, "every_s": 0.0, "decay": 1.0}
        for k in range(int(repeat["count"])):
            start = float(part.get("start", 0.0)) + k * float(repeat["every_s"])
            offset = int(round(start * rate))
            if offset >= total:
                break
            samples = render_part(part, rate, default_length=total / rate - start)
            gain = float(repeat.get("decay", 1.0)) ** k
            for i, s in enumerate(samples[: total - offset]):
                mix[offset + i] += s * gain
    if normalise and loop:
        # A loop never rests, so any offset would sit under it for good; a one-shot's release
        # already ends at silence, and blocking it would leave a tail after the release.
        mix = _dc_block(mix)
    if fold > 0:
        mix = _fold(mix, length, fold, sound.get("crossfade", "power"))
    if normalise:
        peak = max((abs(s) for s in mix), default=0.0)
        if peak > 0.0:
            scale = float(sound.get("peak", DEFAULT_PEAK)) / peak
            mix = [s * scale for s in mix]
    return mix[:length]


def _dc_block(samples):
    out = [0.0] * len(samples)
    last_x = 0.0
    last_y = 0.0
    for i, x in enumerate(samples):
        last_y = x - last_x + DC_BLOCK_R * last_y
        last_x = x
        out[i] = last_y
    return out


def _fold(samples, length, fold, curve):
    """The tail past `length` crossfaded over the head, so sample length-1 runs on into sample 0."""
    out = samples[:length]
    for i in range(fold):
        t = i / fold
        if curve == "linear":
            keep, tail = t, 1.0 - t
        else:
            keep, tail = math.sin(0.5 * math.pi * t), math.cos(0.5 * math.pi * t)
        out[i] = samples[i] * keep + samples[length + i] * tail
    return out


def seam_ok(samples, rate=RATE):
    """True when the step from the last sample to the first is no bigger than the loop's own
    99.9th-percentile step: the seam is as smooth as any ordinary moment of it."""
    steps = sorted(abs(b - a) for a, b in zip(samples, samples[1:]))
    if not steps:
        return False
    ordinary = steps[min(int(0.999 * len(steps)), len(steps) - 1)]
    return abs(samples[0] - samples[-1]) <= max(ordinary, 1e-6)


# --- files ---------------------------------------------------------------------------------------

def wav_bytes(samples, rate=RATE):
    frames = bytearray()
    for s in samples:
        value = max(-32768, min(32767, int(round(s * 32767))))
        frames += value.to_bytes(2, "little", signed=True)
    buffer = io.BytesIO()
    with wave.open(buffer, "wb") as writer:
        writer.setnchannels(1)
        writer.setsampwidth(2)
        writer.setframerate(rate)
        writer.writeframes(bytes(frames))
    return buffer.getvalue()


def read_wav(data):
    """(rate, samples as ints) of a 16-bit mono WAV."""
    with wave.open(io.BytesIO(data)) as reader:
        if reader.getnchannels() != 1 or reader.getsampwidth() != 2:
            raise ValueError("not a 16-bit mono WAV")
        raw = reader.readframes(reader.getnframes())
        rate = reader.getframerate()
    return rate, [int.from_bytes(raw[i:i + 2], "little", signed=True) for i in range(0, len(raw), 2)]


def build(recipe, out_root=DEFAULT_OUT, only=None):
    """Writes every sound (or those in `only`) under out_root; returns the paths written."""
    written = []
    for sound in recipe["sounds"]:
        if only is not None and sound["id"] not in only:
            continue
        if sound["folder"] not in FOLDERS:
            raise ValueError(f"{sound['id']}: folder must be one of {FOLDERS}")
        path = pathlib.Path(out_root) / sound["folder"] / f"{sound['id']}.wav"
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(wav_bytes(render_sound(sound, RATE), RATE))
        written.append(path)
    return written


def check(recipe, out_root=DEFAULT_OUT):
    """The ids whose tracked file is missing or differs from a fresh render by more than one step."""
    stale = []
    for sound in recipe["sounds"]:
        path = pathlib.Path(out_root) / sound["folder"] / f"{sound['id']}.wav"
        if not path.exists():
            stale.append(sound["id"])
            continue
        fresh = read_wav(wav_bytes(render_sound(sound, RATE), RATE))[1]
        _, tracked = read_wav(path.read_bytes())
        if len(fresh) != len(tracked) or any(abs(a - b) > 1 for a, b in zip(fresh, tracked)):
            stale.append(sound["id"])
    return stale


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--recipe", default=str(DEFAULT_RECIPE))
    parser.add_argument("--out", default=str(DEFAULT_OUT))
    parser.add_argument("--only", default="")
    parser.add_argument("--check", action="store_true", help="write nothing; fail if a tracked file is stale")
    args = parser.parse_args(argv)
    recipe = load_recipe(args.recipe)
    if args.check:
        stale = check(recipe, args.out)
        for sid in stale:
            print(f"stale: {sid}")
        return 1 if stale else 0
    only = {s for s in args.only.split(",") if s} or None
    for path in build(recipe, args.out, only):
        print(path.relative_to(pathlib.Path(args.out)).as_posix())
    return 0


if __name__ == "__main__":
    sys.exit(main())

"""Turns the approved CC0 recordings (openspec change sound-pass, owner Q2 B) into game sounds.

ffmpeg decodes, downmixes, resamples and trims each raw download to mono at 22 050 Hz. Then:
- a loop's tail is crossfaded over its head with sfx.py's fold, so it runs on without a seam;
  a download that already loops seamlessly ("seamless") is decoded twice over and one whole
  turn of it is taken, so the resampler's edges never reach the seam;
- a one-shot gets a short fade-in and a fade-out to silence;
- the level is set to the RMS of the generated placeholder the file replaces, so the bank's dB
  values still hold, unless that would push a peak past PEAK_CAP.

The parameters are data, in recordings.json: the file, its page, author and licence, the trim and
the target level. The raw downloads are git-ignored and never tracked, so CI cannot rebuild these
files. Run it locally after a download (ffmpeg on PATH):

    python -I tools/audio/recordings.py                    # write every recording
    python -I tools/audio/recordings.py --analyse wind     # print levels to choose a trim
    python -I tools/audio/recordings.py --source <folder>  # raw downloads elsewhere
"""
import argparse
import array
import json
import math
import pathlib
import shutil
import statistics
import subprocess
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))

import sfx  # noqa: E402

HERE = pathlib.Path(__file__).resolve().parent
DEFAULT_PARAMS = HERE / "recordings.json"
DEFAULT_SOURCE = sfx.ROOT / "game" / "assets" / "audio" / "ambience"
RATE = sfx.RATE
PEAK_CAP = 0.95
EDGE_FADE_S = 0.005
DURATION_SLACK_S = 0.5
WINDOW_S = 0.5


def load_params(path=DEFAULT_PARAMS):
    with open(path, encoding="utf-8") as handle:
        return json.load(handle)


# --- finding and decoding a download -------------------------------------------------------------

def find_source(rec, source_dir):
    """The download for `rec` in source_dir: its exact Freesound name, or any WAV whose name starts
    with the sound's Freesound number. None when there is none."""
    folder = pathlib.Path(source_dir)
    exact = folder / rec["source"]
    if exact.is_file():
        return exact
    matches = sorted(folder.glob(f"{rec['freesound_id']}_*.wav")) if folder.is_dir() else []
    return matches[0] if matches else None


def probe(path):
    """(duration_s, description) of a file, from ffprobe."""
    out = subprocess.run(
        ["ffprobe", "-v", "error", "-show_entries",
         "stream=codec_name,sample_rate,channels,bits_per_sample:format=duration",
         "-of", "json", str(path)],
        check=True, capture_output=True, text=True).stdout
    info = json.loads(out)
    stream = info["streams"][0]
    duration = float(info["format"]["duration"])
    text = (f"{stream['codec_name']}, {stream['sample_rate']} Hz, {stream['channels']} channel(s), "
            f"{duration:.2f} s")
    return duration, text


def decode(path, start_s=0.0, length_s=None, rate=RATE, repeat=0):
    """Mono float samples of `path` from start_s for length_s seconds (all of it when None),
    with the file played 1 + repeat times end to end."""
    command = ["ffmpeg", "-v", "error", "-nostdin"]
    if repeat > 0:
        command += ["-stream_loop", str(repeat)]
    command += ["-i", str(path), "-ss", f"{start_s:.6f}"]
    if length_s is not None:
        command += ["-t", f"{length_s:.6f}"]
    command += ["-ac", "1", "-ar", str(rate), "-f", "f32le", "-"]
    raw = subprocess.run(command, check=True, capture_output=True).stdout
    return parse_f32le(raw)


def parse_f32le(raw):
    samples = array.array("f")
    samples.frombytes(raw[: len(raw) - len(raw) % 4])
    if sys.byteorder == "big":
        samples.byteswap()
    return list(samples)


# --- shaping -------------------------------------------------------------------------------------

def rms(samples):
    return math.sqrt(sum(s * s for s in samples) / max(len(samples), 1))


def level(samples, target_rms, peak_cap=PEAK_CAP):
    """(scaled samples, gain, capped): scaled to target_rms, or lower when a peak would pass
    peak_cap."""
    now = rms(samples)
    peak = max((abs(s) for s in samples), default=0.0)
    if now <= 0.0:
        return list(samples), 1.0, False
    gain = target_rms / now
    capped = peak * gain > peak_cap
    if capped:
        gain = peak_cap / peak
    return [s * gain for s in samples], gain, capped


def fade(samples, fade_in_s, fade_out_s, rate=RATE):
    """Linear fade-in over fade_in_s and an equal-power fade-out to exactly zero over fade_out_s."""
    out = list(samples)
    n_in = min(int(round(fade_in_s * rate)), len(out))
    for i in range(n_in):
        out[i] *= i / n_in
    n_out = min(int(round(fade_out_s * rate)), len(out))
    for i in range(n_out):
        k = len(out) - n_out + i
        out[k] *= math.cos(0.5 * math.pi * (i + 1) / n_out)
    return out


def window_levels(samples, window_s=WINDOW_S, rate=RATE):
    """RMS of each window_s-long window, in order."""
    n = max(int(round(window_s * rate)), 1)
    return [rms(samples[i:i + n]) for i in range(0, len(samples) - n + 1, n)]


def flattest(levels, count, floor=0.0):
    """The index of the run of `count` windows whose levels vary least relative to their mean,
    among runs whose mean is at least `floor` (so a lull never wins for being steady)."""
    if count > len(levels) or count < 2:
        return 0
    best, best_spread = 0, math.inf
    for i in range(len(levels) - count + 1):
        run = levels[i:i + count]
        mean = sum(run) / count
        if mean <= 0.0 or mean < floor:
            continue
        spread = statistics.pstdev(run) / mean
        if spread < best_spread:
            best, best_spread = i, spread
    return best


def shape(rec, decoded, rate=RATE):
    """The game sound for `rec` from its decoded samples (length_s plus any crossfade_s)."""
    length = int(round(float(rec["length_s"]) * rate))
    if rec.get("seamless", False):
        # One whole turn of a loop that already runs on: only its offset is taken out, since a
        # filter's start-up would leave a step at the seam.
        if len(decoded) < length:
            raise ValueError(f"{rec['id']}: the trim runs past the end of the file")
        mean = sum(decoded[:length]) / length
        scaled, _gain, _capped = level([s - mean for s in decoded[:length]], float(rec["rms"]))
        return scaled
    samples = sfx._dc_block(decoded)
    if rec.get("loop", False):
        fold = int(round(float(rec["crossfade_s"]) * rate))
        if len(samples) < length + fold:
            raise ValueError(f"{rec['id']}: the trim runs past the end of the file")
        samples = sfx._fold(samples, length, fold, "power")
    else:
        if len(samples) < length:
            raise ValueError(f"{rec['id']}: the trim runs past the end of the file")
        samples = fade(samples[:length], EDGE_FADE_S, float(rec["fade_out_s"]), rate)
    scaled, _gain, _capped = level(samples[:length], float(rec["rms"]))
    return scaled


# --- the whole pass ------------------------------------------------------------------------------

def prepare(rec, source_dir=DEFAULT_SOURCE, out_root=sfx.DEFAULT_OUT, rate=RATE):
    """Writes rec's game file from its download; returns (path written, notes)."""
    if rec["folder"] not in sfx.FOLDERS:
        raise ValueError(f"{rec['id']}: folder must be one of {sfx.FOLDERS}")
    source = find_source(rec, source_dir)
    if source is None:
        raise FileNotFoundError(f"{rec['id']}: {rec['source']} is not in {source_dir}")
    duration, text = probe(source)
    if abs(duration - float(rec["expect_s"])) > DURATION_SLACK_S:
        raise ValueError(f"{rec['id']}: {source.name} lasts {duration:.2f} s, not the approved "
                         f"{rec['expect_s']} s; is it the approved file?")
    seamless = bool(rec.get("seamless", False))
    take = float(rec["length_s"]) + (float(rec.get("crossfade_s", 0.0)) if rec.get("loop", False) else 0.0)
    decoded = decode(source, float(rec["start_s"]), take, rate, repeat=1 if seamless else 0)
    samples = shape(rec, decoded, rate)
    path = pathlib.Path(out_root) / rec["folder"] / f"{rec['id']}.wav"
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(sfx.wav_bytes(samples, rate))
    peak = max(abs(s) for s in samples)
    notes = [f"from {source.name} ({text})",
             f"rms {rms(samples):.4f} (target {rec['rms']}), peak {peak:.3f}"]
    if rms(samples) < 0.95 * float(rec["rms"]):
        notes.append(f"held under the target so no peak passes {PEAK_CAP}")
    if rec.get("loop", False):
        notes.append("seam ok" if sfx.seam_ok(samples, rate) else "SEAM CLICKS")
    return path, notes


def analyse(rec, source_dir=DEFAULT_SOURCE, rate=RATE):
    """Lines describing a download's level over time, to choose its trim."""
    source = find_source(rec, source_dir)
    if source is None:
        return [f"{rec['id']}: {rec['source']} is not in {source_dir}"]
    _duration, text = probe(source)
    samples = decode(source, rate=rate)
    levels = window_levels(samples, WINDOW_S, rate)
    take = float(rec["length_s"]) + float(rec.get("crossfade_s", 0.0))
    count = max(int(round(take / WINDOW_S)), 2)
    start = flattest(levels, count, 0.5 * statistics.median(levels) if levels else 0.0) * WINDOW_S
    peak_at = max(range(len(samples)), key=lambda i: abs(samples[i])) / rate if samples else 0.0
    lines = [f"{rec['id']}: {source.name}: {text}",
             f"  whole file rms {rms(samples):.4f}, loudest sample at {peak_at:.2f} s",
             f"  flattest {take:.1f} s starts at {start:.1f} s",
             "  rms per %.1f s window:" % WINDOW_S]
    for i in range(0, len(levels), 10):
        row = " ".join(f"{v:.3f}" for v in levels[i:i + 10])
        lines.append(f"  {i * WINDOW_S:6.1f}s {row}")
    return lines


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--params", default=str(DEFAULT_PARAMS))
    parser.add_argument("--source", default=str(DEFAULT_SOURCE), help="folder of the raw downloads")
    parser.add_argument("--out", default=str(sfx.DEFAULT_OUT))
    parser.add_argument("--only", default="")
    parser.add_argument("--analyse", default="", help="print the levels of one id's download")
    args = parser.parse_args(argv)
    if shutil.which("ffmpeg") is None or shutil.which("ffprobe") is None:
        print("ffmpeg and ffprobe must be on PATH")
        return 2
    recs = {rec["id"]: rec for rec in load_params(args.params)["recordings"]}
    if args.analyse:
        print("\n".join(analyse(recs[args.analyse], args.source)))
        return 0
    only = {s for s in args.only.split(",") if s} or set(recs)
    for sid in sorted(only):
        path, notes = prepare(recs[sid], args.source, args.out)
        print(path.relative_to(pathlib.Path(args.out)).as_posix() + ": " + "; ".join(notes))
    return 0


if __name__ == "__main__":
    sys.exit(main())

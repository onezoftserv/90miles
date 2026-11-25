"""Turn the owner's approved CC0 recordings into the game's WAVs (openspec change sound-pass task 9.3,
owner Q2 B), standard library only.

The raw downloads live in the git-ignored game/assets/audio/ambience/ on the owner's machine and are
never tracked. tools/audio/recordings.json is the provenance list: one entry per approved file,
{id, folder, source, start_s, length_s, [loop, crossfade_s, fade_out_s, peak], title, author,
licence, url}. For each entry this script reads <ambience>/<source> (a PCM WAV of any rate, width
and channel count), averages it to mono, cuts start_s..start_s+length_s (plus crossfade_s for a
loop), resamples it to 22 050 Hz with a windowed-sinc filter, and then, for a loop, DC-blocks it and
folds its tail over its head so the seam runs straight on; a one-shot gets a short fade in and a
fade_out_s fade out. Last, it scales the peak to `peak` (default 0.89) and writes
game/assets/audio/<folder>/<id>.wav, in place of the generated placeholder. sfx.py skips every id
listed here, so the two never fight over a file.

Only sea, wind and thunder may be replaced, and only by a CC0 file with an author and an https://
source page. --credits prints the License.txt "Pack:" block and the CREDITS.md row to paste.

Usage: python -I tools/audio/recording.py [--list tools/audio/recordings.json]
       [--raw game/assets/audio/ambience] [--out game/assets/audio] [--only id,id] [--credits]
"""
import argparse
import io
import json
import math
import pathlib
import sys
import wave

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))

import sfx  # noqa: E402

DEFAULT_LIST = sfx.RECORDINGS
DEFAULT_RAW = sfx.DEFAULT_OUT / "ambience"
REPLACEABLE = {"sea": "loops", "wind": "loops", "thunder": "sfx"}
FADE_IN_S = 0.005
DEFAULT_FADE_OUT_S = 0.05
SINC_ZEROS = 16


def load_recordings(path=DEFAULT_LIST):
    return sfx.load_recordings(path)


def recorded_ids(path=DEFAULT_LIST):
    return sfx.recorded_ids(path)


def problems(recordings):
    """What is wrong with a provenance list, one line per problem, each led by its id."""
    found = []
    seen = set()
    for rec in recordings:
        rid = str(rec.get("id", ""))
        if rid not in REPLACEABLE:
            found.append(f"{rid}: not one of {', '.join(sorted(REPLACEABLE))}")
            continue
        if rid in seen:
            found.append(f"{rid}: listed twice")
        seen.add(rid)
        if rec.get("folder") != REPLACEABLE[rid]:
            found.append(f"{rid}: folder must be {REPLACEABLE[rid]}")
        if bool(rec.get("loop", False)) != (REPLACEABLE[rid] == "loops"):
            found.append(f"{rid}: loop must be {REPLACEABLE[rid] == 'loops'}")
        if "CC0" not in str(rec.get("licence", "")):
            found.append(f"{rid}: licence must be CC0, not {rec.get('licence', '')!r}")
        if not str(rec.get("author", "")).strip():
            found.append(f"{rid}: no author")
        if not str(rec.get("url", "")).startswith("https://"):
            found.append(f"{rid}: url must be an https:// source page")
        if not str(rec.get("source", "")).strip() or "/" in str(rec.get("source", "")):
            found.append(f"{rid}: source must be a file name inside the ambience folder")
        if float(rec.get("length_s", 0.0)) <= 0.0:
            found.append(f"{rid}: length_s must be above 0")
    return found


# --- reading -------------------------------------------------------------------------------------

def read_audio(data):
    """(rate, mono samples in -1..1) of a PCM WAV of 8, 16, 24 or 32 bits and any channel count."""
    try:
        reader = wave.open(io.BytesIO(data))
    except (wave.Error, EOFError) as error:
        raise ValueError(f"not a PCM WAV ({error}); export the download as a 16- or 24-bit WAV first") from error
    with reader:
        channels = reader.getnchannels()
        width = reader.getsampwidth()
        rate = reader.getframerate()
        raw = reader.readframes(reader.getnframes())
    frame = channels * width
    scale = float(1 << (8 * width - 1))
    mono = []
    for start in range(0, len(raw) - frame + 1, frame):
        total = 0.0
        for c in range(channels):
            chunk = raw[start + c * width:start + (c + 1) * width]
            if width == 1:
                value = chunk[0] - 128
            else:
                value = int.from_bytes(chunk, "little", signed=True)
            total += value / scale
        mono.append(total / channels)
    return rate, mono


def resample(samples, src, dst):
    """samples at src Hz as dst Hz: a Blackman-windowed sinc, its cutoff at the lower Nyquist."""
    if src == dst:
        return list(samples)
    ratio = dst / src
    cutoff = min(1.0, ratio)
    half = int(math.ceil(SINC_ZEROS / cutoff))
    count = int(round(len(samples) * ratio))
    out = [0.0] * count
    n = len(samples)
    for j in range(count):
        centre = j / ratio
        base = int(math.floor(centre))
        total = 0.0
        for k in range(base - half + 1, base + half + 1):
            if k < 0 or k >= n:
                continue
            x = k - centre
            arg = x * cutoff
            sinc = 1.0 if arg == 0.0 else math.sin(math.pi * arg) / (math.pi * arg)
            w = (x + half) / (2.0 * half)
            window = 0.42 - 0.5 * math.cos(2.0 * math.pi * w) + 0.08 * math.cos(4.0 * math.pi * w)
            total += samples[k] * sinc * window * cutoff
        out[j] = total
    return out


# --- shaping -------------------------------------------------------------------------------------

def prepare(rec, data):
    """The game's samples for one provenance entry, from the raw download's bytes."""
    rate, mono = read_audio(data)
    loop = bool(rec.get("loop", False))
    length = int(round(float(rec["length_s"]) * sfx.RATE))
    fold = int(round(float(rec.get("crossfade_s", 0.0)) * sfx.RATE)) if loop else 0
    start = float(rec.get("start_s", 0.0))
    needed_s = (length + fold) / sfx.RATE
    if start < 0.0 or start + needed_s > len(mono) / rate + 1e-9:
        raise ValueError(
            f"{rec['id']}: the cut {start:.2f}..{start + needed_s:.2f} s runs past the file's {len(mono) / rate:.2f} s")
    margin = int(math.ceil(SINC_ZEROS * rate / min(rate, sfx.RATE))) + 1
    first = int(round(start * rate))
    lo = max(0, first - margin)
    hi = min(len(mono), first + int(math.ceil(needed_s * rate)) + margin)
    piece = resample(mono[lo:hi], rate, sfx.RATE)
    skip = int(round((first - lo) * sfx.RATE / rate))
    piece = (piece[skip:] + [0.0] * (length + fold))[: length + fold]
    if loop:
        piece = sfx._dc_block(piece)
        piece = sfx._fold(piece, length, fold, rec.get("crossfade", "power")) if fold > 0 else piece[:length]
    else:
        piece = piece[:length]
        fade_in = min(length, int(round(FADE_IN_S * sfx.RATE)))
        fade_out = min(length, int(round(float(rec.get("fade_out_s", DEFAULT_FADE_OUT_S)) * sfx.RATE)))
        for i in range(fade_in):
            piece[i] *= i / fade_in
        for i in range(fade_out):
            piece[length - 1 - i] *= i / fade_out
    peak = max((abs(s) for s in piece), default=0.0)
    if peak <= 0.0:
        raise ValueError(f"{rec['id']}: the cut is silent")
    scale = float(rec.get("peak", sfx.DEFAULT_PEAK)) / peak
    return [s * scale for s in piece]


# --- files and credits ---------------------------------------------------------------------------

def build(recordings, raw_root=DEFAULT_RAW, out_root=sfx.DEFAULT_OUT, only=None):
    """Writes each recording's game WAV under out_root; returns the paths written."""
    bad = problems(recordings)
    if bad:
        raise ValueError("\n".join(bad))
    written = []
    for rec in recordings:
        if only is not None and rec["id"] not in only:
            continue
        source = pathlib.Path(raw_root) / rec["source"]
        if not source.exists():
            raise FileNotFoundError(f"{rec['id']}: put {rec['source']} in {pathlib.Path(raw_root)}")
        path = pathlib.Path(out_root) / rec["folder"] / f"{rec['id']}.wav"
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(sfx.wav_bytes(prepare(rec, source.read_bytes())))
        written.append(path)
    return written


def credits(rec):
    """(the License.txt "Pack:" block, the CREDITS.md table row) for one recording."""
    name = f"{rec['id']}.wav"
    block = "\n".join([
        f"Pack: {rec['title']}",
        f"Author: {rec['author']}",
        f"Licence: {rec['licence']}",
        f"Source: {rec['url']}",
        f"Files: {name} (cut, mono, 22 050 Hz by tools/audio/recording.py from {rec['source']})",
    ])
    row = (f"| {rec['title']} | {rec['author']} | {rec['licence']} | {rec['url']} | "
           f"`audio/{rec['folder']}/`: `{name}` (license: `audio/{rec['folder']}/License.txt`) |")
    return block, row


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--list", default=str(DEFAULT_LIST))
    parser.add_argument("--raw", default=str(DEFAULT_RAW))
    parser.add_argument("--out", default=str(sfx.DEFAULT_OUT))
    parser.add_argument("--only", default="")
    parser.add_argument("--credits", action="store_true", help="print the licence block and credits row; write nothing")
    args = parser.parse_args(argv)
    recordings = load_recordings(args.list)
    bad = problems(recordings)
    if bad:
        for line in bad:
            print(line, file=sys.stderr)
        return 1
    only = {s for s in args.only.split(",") if s} or None
    if args.credits:
        for rec in recordings:
            if only is None or rec["id"] in only:
                block, row = credits(rec)
                print(f"{block}\n\n{row}\n")
        return 0
    try:
        written = build(recordings, args.raw, args.out, only)
    except (FileNotFoundError, ValueError) as error:
        print(error, file=sys.stderr)
        return 1
    for path in written:
        print(path.relative_to(pathlib.Path(args.out)).as_posix())
    return 0


if __name__ == "__main__":
    sys.exit(main())

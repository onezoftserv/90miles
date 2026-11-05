#!/usr/bin/env python3
"""Download the CC0 Kenney packs listed in docs/ASSETS.md into game/assets/kenney/.

Usage: python -I tools/fetch_assets.py [--dest game/assets]

Kenney serves packs as zips from https://kenney.nl/media/pages/assets/<slug>/<hash>/<file>.zip,
and the exact URL changes per release. This script resolves each pack page and
follows the first .zip link it finds. If a pack fails, download it by hand from the
page URL printed and unzip it into the same folder.
"""
import argparse
import io
import pathlib
import re
import sys
import urllib.request
import zipfile

PACKS = {
    "roguelike-characters": "characters",
    "tiny-dungeon": "characters",
    "roguelike-rpg-pack": "tiles",
    "generic-items": "items",
    "roguelike-items": "items",
    "ui-pack": "ui",
    "pixel-ui-pack": "ui",
    "interface-sounds": "audio_sfx",
    "impact-sounds": "audio_sfx",
    "particle-pack": "particles",
}

UA = {"User-Agent": "90-millas-asset-fetch/1.0"}


def resolve_zip(slug: str) -> str | None:
    page = f"https://kenney.nl/assets/{slug}"
    html = urllib.request.urlopen(urllib.request.Request(page, headers=UA), timeout=30).read().decode()
    m = re.search(r'href="([^"]+\.zip)"', html)
    if not m:
        return None
    href = m.group(1)
    return href if href.startswith("http") else "https://kenney.nl" + href


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--dest", default="game/assets")
    args = ap.parse_args()
    root = pathlib.Path(args.dest) / "kenney"
    failed: list[str] = []
    for slug, sub in PACKS.items():
        out = root / sub / slug
        if out.exists():
            print(f"skip  {slug} (exists)")
            continue
        try:
            url = resolve_zip(slug)
            if not url:
                raise RuntimeError("no zip link on page")
            print(f"fetch {slug} <- {url}")
            data = urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=120).read()
            out.mkdir(parents=True, exist_ok=True)
            with zipfile.ZipFile(io.BytesIO(data)) as zf:
                for member in zf.infolist():
                    # guard against zip-slip
                    target = (out / member.filename).resolve()
                    if not str(target).startswith(str(out.resolve())):
                        continue
                    zf.extract(member, out)
            print(f"ok    {slug}")
        except Exception as e:  # noqa: BLE001
            print(f"FAIL  {slug}: {e}  -> download by hand from https://kenney.nl/assets/{slug}")
            failed.append(slug)
    if failed:
        print("\nManual downloads needed:", ", ".join(failed))
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())

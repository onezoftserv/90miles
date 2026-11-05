#!/usr/bin/env python3
"""Download the CC0 Kenney packs and OFL pixel fonts listed in docs/ASSETS.md.

Usage: python -I tools/fetch_assets.py [--dest game/assets]

Kenney pack pages carry a data-download-id; the site exchanges it at
https://kenney.nl/download-link/<id> for a short-lived signed zip URL, using the
page's session cookie. Packs land in game/assets/kenney/<sub>/<slug>/ and fonts in
game/assets/fonts/. Existing folders and files are skipped. A pack that fails
leaves nothing behind, so the next run retries it; if it keeps failing, download
it by hand from the page URL printed and unzip it into the same folder.
"""
import argparse
import http.cookiejar
import io
import json
import pathlib
import re
import shutil
import sys
import tempfile
import urllib.request
import zipfile

PACKS = {
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

GOOGLE_FONTS = "https://raw.githubusercontent.com/google/fonts/main/ofl"
FONTS = {
    "PressStart2P-Regular.ttf": f"{GOOGLE_FONTS}/pressstart2p/PressStart2P-Regular.ttf",
    "PressStart2P-OFL.txt": f"{GOOGLE_FONTS}/pressstart2p/OFL.txt",
    "PixelifySans[wght].ttf": f"{GOOGLE_FONTS}/pixelifysans/PixelifySans%5Bwght%5D.ttf",
    "PixelifySans-OFL.txt": f"{GOOGLE_FONTS}/pixelifysans/OFL.txt",
}

UA = "90-millas-asset-fetch/1.1"


def get(opener: urllib.request.OpenerDirector, url: str, timeout: int = 30, referer: str | None = None) -> bytes:
    headers = {"User-Agent": UA}
    if referer:
        headers["Referer"] = referer
    with opener.open(urllib.request.Request(url, headers=headers), timeout=timeout) as resp:
        return resp.read()


def resolve_zip(opener: urllib.request.OpenerDirector, slug: str) -> str | None:
    page = f"https://kenney.nl/assets/{slug}"
    html = get(opener, page).decode()
    m = re.search(r"data-download-id=['\"]([0-9a-f]+)['\"]", html)
    if not m:
        return None
    link = json.loads(get(opener, f"https://kenney.nl/download-link/{m.group(1)}", referer=page))
    return link.get("url")


def extract(data: bytes, out: pathlib.Path) -> None:
    """Unzip into a temp folder beside `out`, then rename it into place."""
    out.parent.mkdir(parents=True, exist_ok=True)
    tmp = pathlib.Path(tempfile.mkdtemp(dir=out.parent, prefix=f".{out.name}-"))
    try:
        root = tmp.resolve()
        with zipfile.ZipFile(io.BytesIO(data)) as zf:
            for member in zf.infolist():
                # guard against zip-slip
                if not (tmp / member.filename).resolve().is_relative_to(root):
                    continue
                zf.extract(member, tmp)
        tmp.rename(out)
    except BaseException:
        shutil.rmtree(tmp, ignore_errors=True)
        raise


def fetch_packs(opener: urllib.request.OpenerDirector, root: pathlib.Path, failed: list[str]) -> None:
    for slug, sub in PACKS.items():
        out = root / "kenney" / sub / slug
        if out.exists():
            print(f"skip  {slug} (exists)")
            continue
        try:
            url = resolve_zip(opener, slug)
            if not url:
                raise RuntimeError("no download id on page")
            print(f"fetch {slug}")
            extract(get(opener, url, timeout=180, referer=f"https://kenney.nl/assets/{slug}"), out)
            print(f"ok    {slug}")
        except Exception as e:  # noqa: BLE001
            print(f"FAIL  {slug}: {e}  -> download by hand from https://kenney.nl/assets/{slug}")
            failed.append(slug)


def fetch_fonts(opener: urllib.request.OpenerDirector, root: pathlib.Path, failed: list[str]) -> None:
    fonts = root / "fonts"
    fonts.mkdir(parents=True, exist_ok=True)
    for name, url in FONTS.items():
        out = fonts / name
        if out.exists():
            print(f"skip  {name} (exists)")
            continue
        try:
            data = get(opener, url, timeout=60)
            tmp = out.with_name(out.name + ".part")
            tmp.write_bytes(data)
            tmp.replace(out)
            print(f"ok    {name}")
        except Exception as e:  # noqa: BLE001
            print(f"FAIL  {name}: {e}  -> download by hand from {url}")
            failed.append(name)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--dest", default="game/assets")
    args = ap.parse_args()
    root = pathlib.Path(args.dest)
    opener = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(http.cookiejar.CookieJar()))
    failed: list[str] = []
    fetch_packs(opener, root, failed)
    fetch_fonts(opener, root, failed)
    if failed:
        print("\nManual downloads needed:", ", ".join(failed))
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())

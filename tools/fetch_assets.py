#!/usr/bin/env python3
"""Fetch the downloaded asset packs of docs/ASSETS.md into the git-ignored folders of game/assets.

Usage: python -I tools/fetch_assets.py [--dest <repo>/game/assets] [--list] [--dry-run]

Three tables, each fetched its own way:
- PACKS, the CC0 Kenney packs. Kenney pack pages carry a data-download-id; the site exchanges it
  at https://kenney.nl/download-link/<id> for a short-lived signed zip URL, using the page's
  session cookie. Packs land in game/assets/kenney/<sub>/<slug>/.
- FONTS, the OFL pixel fonts, into game/assets/fonts/.
- ART_PACKS, the nine art packs of art direction C (art-pass; design.md K12, K19). Each pack keeps
  its archives, an extracted/ folder and a License.txt with its source page, licence and the date
  read. OpenGameArt packs are fetched directly: the file link whose name matches the archive is
  read from the pack's page (same host, https only). itch.io packs need a click-through, so the
  script prints the page and the folder to download into; run it again afterwards and it unpacks
  what it finds there (a RAR with 7-Zip when 7z is on PATH, else it prints that step too).

Existing folders and files are skipped. A pack that fails leaves nothing behind, so the next run
retries it. The script exits non-zero while any download or manual step remains. --list prints
every pack and downloads nothing; --dry-run prints what a run would do and writes nothing.
"""
import argparse
import dataclasses
import datetime
import html
import http.cookiejar
import io
import json
import pathlib
import re
import shutil
import subprocess
import sys
import tempfile
import urllib.parse
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


@dataclasses.dataclass(frozen=True)
class Archive:
    """One file of a pack: a "zip" or "rar" unpacked into extracted/<into>, or a "file" kept as is."""

    name: str
    kind: str
    into: str = ""


@dataclasses.dataclass(frozen=True)
class ArtPack:
    key: str
    name: str
    author: str
    page: str
    licence: str
    version: str
    folder: str
    archives: tuple
    direct: bool
    # The day `licence` was read from the pack's page; License.txt says so, beside the fetch date.
    licence_read: str = "2026-11-08"


## The licence wording is what each pack's page stated when the owner downloaded it (2026-11-08,
## each pack's licence_read); the archive names and extracted/ layout are those of that download.
ART_PACKS = (
    ArtPack(
        "metrocity", "MetroCity Free Top Down Character Pack", "JIK-A-4",
        "https://jik-a-4.itch.io/metrocity-free-topdown-character-pack", "CC0", "1.0 and 2.0", "itch/metrocity",
        (Archive("MetroCity.rar", "rar", "MetroCity"), Archive("MetroCity 2.0.rar", "rar", "MetroCity 2.0")), False,
    ),
    ArtPack(
        "zelda-like", "Zelda-like tilesets and sprites", "ArMM1998",
        "https://opengameart.org/content/zelda-like-tilesets-and-sprites", "CC0", "", "oga/zelda-like",
        (Archive("gfx_3.zip", "zip", "gfx_3"),), True,
    ),
    ArtPack(
        "scallywag-water-islands", "Scallywag - Water and Islands", "Foozle, commissioned from Pixel Carvel",
        "https://foozlecc.itch.io/scallywag-water-islands", "CC0", "1.0", "itch/scallywag-water-islands",
        (Archive("Foozle_2DT0014_Scallywag_WaterAndIslands.zip", "zip", "Foozle_2DT0014_Scallywag_WaterAndIslands"),), False,
    ),
    ArtPack(
        "scallywag-ships", "Scallywag - Ships", "Foozle, commissioned from Pixel Carvel",
        "https://foozlecc.itch.io/scallywag-ships", "CC0", "1.0", "itch/scallywag-ships",
        (Archive("Foozle_2DT0013_Scallywag_Ships.zip", "zip", "Foozle_2DT0013_Scallywag_Ships"),), False,
    ),
    ArtPack(
        "eldiran-shoreline", "16x16 Shoreline Wave Animation Tiles", "Eldiran",
        "https://opengameart.org/node/144858", "CC0", "", "oga/eldiran-shoreline",
        (Archive("cc0waveanimtiles16x16.png", "file"),), True,
    ),
    ArtPack(
        "dawnlike", "DawnLike - 16x16 Universal Rogue-like tileset", "DragonDePlatino; palette by DawnBringer",
        "https://opengameart.org/content/dawnlike-16x16-universal-rogue-like-tileset-v181",
        "CC-BY 4.0 (DawnLike by DragonDePlatino, palette by DawnBringer)", "1.81", "oga/dawnlike",
        (Archive("DawnLike_5.zip", "zip", "DawnLike_5"),), True,
    ),
    ArtPack(
        "tth-animals", "Tiny, Tiny Heroes - Animals", "Kacper Woźniak (thkaspar)",
        "https://thkaspar.itch.io/tth-animals", "CC BY 4.0 (Tiny, Tiny Heroes - Animals by Kacper Wozniak, thkaspar)", "",
        "itch/tth-animals", (Archive("Tiny, Tiny Heroes - Animals.zip", "zip", "animals"),), False,
    ),
    ArtPack(
        "kyrise-icons", "Kyrise's Free 16x16 RPG Icon Pack", "Kyrise",
        "https://kyrise.itch.io/kyrises-free-16x16-rpg-icon-pack", "CC BY 4.0 (Kyrise's Free 16x16 RPG Icon Pack by Kyrise)",
        "1.3", "itch/kyrise-icons", (Archive("Kyrises_16x16_RPG_Icon_Pack_V1.3.zip", "zip", "Kyrises_16x16_RPG_Icon_Pack_V1.3"),), False,
    ),
    ArtPack(
        "shikashi-icons", "Shikashi's Fantasy Icons Pack", "Matt Firth (shikashipx); game-icons.net bases",
        "https://shikashipx.itch.io/shikashis-fantasy-icons-pack",
        "CC BY 4.0 (Shikashi's Fantasy Icons Pack v2 by Matt Firth, shikashipx; game-icons.net bases CC BY 3.0)", "2",
        "itch/shikashi-icons", (Archive("Shikashi's Fantasy Icons Pack v2.zip", "zip", "v2"),), False,
    ),
)

UA = "90-millas-asset-fetch/1.2"
LICENCE_FILE = "License.txt"
HREF = re.compile(r"""href\s*=\s*["']([^"']+)["']""", re.IGNORECASE)


class NeedsSevenZip(Exception):
    """A RAR is here but 7-Zip is not on PATH."""


def get(opener: urllib.request.OpenerDirector, url: str, timeout: int = 30, referer: str | None = None) -> bytes:
    headers = {"User-Agent": UA}
    if referer:
        headers["Referer"] = referer
    with opener.open(urllib.request.Request(url, headers=headers), timeout=timeout) as resp:
        return resp.read()


def resolve_zip(opener: urllib.request.OpenerDirector, slug: str) -> str | None:
    page = f"https://kenney.nl/assets/{slug}"
    page_html = get(opener, page).decode()
    m = re.search(r"data-download-id=['\"]([0-9a-f]+)['\"]", page_html)
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
                # zip-slip: a member that would land outside the pack folder fails the whole pack
                if not (tmp / member.filename).resolve().is_relative_to(root):
                    raise RuntimeError(f"unsafe path in archive: {member.filename}")
                zf.extract(member, tmp)
        if not any(p.is_file() for p in tmp.rglob("*")):
            raise RuntimeError("archive contained no files")
        tmp.rename(out)
    except BaseException:
        shutil.rmtree(tmp, ignore_errors=True)
        raise


def fetch_packs(opener: urllib.request.OpenerDirector | None, root: pathlib.Path, failed: list[str], dry_run: bool = False) -> None:
    for slug, sub in PACKS.items():
        out = root / "kenney" / sub / slug
        if out.exists():
            print(f"skip  {slug} (exists)")
            continue
        if dry_run:
            print(f"would fetch {slug} from https://kenney.nl/assets/{slug} into {out.as_posix()}")
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


def fetch_fonts(opener: urllib.request.OpenerDirector | None, root: pathlib.Path, failed: list[str], dry_run: bool = False) -> None:
    fonts = root / "fonts"
    if not dry_run:
        fonts.mkdir(parents=True, exist_ok=True)
    for name, url in FONTS.items():
        out = fonts / name
        if out.exists():
            print(f"skip  {name} (exists)")
            continue
        if dry_run:
            print(f"would fetch {name} from {url} into {out.as_posix()}")
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


# --- Art packs ------------------------------------------------------------------------------------

def find_file_link(page_html: str, page: str, name: str) -> str | None:
    """The first link on `page` whose file name is `name`, on the page's own host over https."""
    host = urllib.parse.urlsplit(page).hostname
    for href in HREF.findall(page_html):
        url = urllib.parse.urljoin(page, html.unescape(href))
        parts = urllib.parse.urlsplit(url)
        if parts.scheme != "https" or parts.hostname != host:
            continue
        if urllib.parse.unquote(parts.path.rsplit("/", 1)[-1]) == name:
            return url
    return None


def find_7zip() -> str | None:
    return shutil.which("7z") or shutil.which("7za") or shutil.which("7zz")


def _has_files(folder: pathlib.Path) -> bool:
    return folder.is_dir() and any(path.is_file() for path in folder.rglob("*"))


def _archive_done(folder: pathlib.Path, archive: Archive) -> bool:
    if archive.kind == "file":
        return (folder / archive.name).is_file()
    return _has_files(folder / "extracted" / archive.into)


def _download_from_page(opener: urllib.request.OpenerDirector, page: str, name: str, target: pathlib.Path) -> None:
    url = find_file_link(get(opener, page).decode("utf-8", "replace"), page, name)
    if url is None:
        raise RuntimeError(f"no https link to {name} on the page")
    data = get(opener, url, timeout=180, referer=page)
    target.parent.mkdir(parents=True, exist_ok=True)
    tmp = target.with_name(target.name + ".part")
    tmp.write_bytes(data)
    tmp.replace(target)


def _check_unpacked(tmp: pathlib.Path) -> None:
    """Every unpacked path is a plain file or folder inside `tmp`, and there is at least one file."""
    root = tmp.resolve()
    has_file = False
    for path in tmp.rglob("*"):
        if path.is_symlink():
            raise RuntimeError(f"unsafe link in archive: {path.relative_to(tmp)}")
        if not path.resolve().is_relative_to(root):
            raise RuntimeError(f"unsafe path in archive: {path.relative_to(tmp)}")
        has_file = has_file or path.is_file()
    if not has_file:
        raise RuntimeError("archive contained no files")


def unpack_rar(archive: pathlib.Path, out: pathlib.Path, sevenzip: str, runner) -> None:
    """7-Zip into a temp folder beside `out`, check what it wrote, then rename it into place.
    7-Zip strips absolute and parent paths unless given -spf, which this never passes."""
    out.parent.mkdir(parents=True, exist_ok=True)
    tmp = pathlib.Path(tempfile.mkdtemp(dir=out.parent, prefix=f".{out.name}-"))
    try:
        runner([sevenzip, "x", "-y", f"-o{tmp}", str(archive)], check=True, capture_output=True)
        _check_unpacked(tmp)
        tmp.rename(out)
    except BaseException:
        shutil.rmtree(tmp, ignore_errors=True)
        raise


def _unpack(archive: Archive, source: pathlib.Path, out: pathlib.Path, sevenzip: str | None, runner) -> None:
    if archive.kind == "rar" and sevenzip is None:
        raise NeedsSevenZip()
    if out.exists():
        shutil.rmtree(out)  # only reached when it holds no file: a folder left by a failed unpack
    if archive.kind == "zip":
        extract(source.read_bytes(), out)
    else:
        unpack_rar(source, out, sevenzip, runner)


def write_licence(pack: ArtPack, folder: pathlib.Path, today: datetime.date) -> None:
    """The pack's License.txt: the licence as read on `pack.licence_read`, and the day it was fetched."""
    (folder / LICENCE_FILE).write_text(
        f"source: {pack.page}\nlicense: {pack.licence}\nread: {pack.licence_read}\nfetched: {today.isoformat()}\n\n"
        "License as recorded in tools/fetch_assets.py from the source page; check the page before relying on it. "
        "Keep this file beside the pack.\n",
        encoding="utf-8",
    )


def _seven_zip_step(target: pathlib.Path, out: pathlib.Path) -> str:
    return f"unpack {target.as_posix()} into {out.as_posix()} with 7-Zip (7z is not on PATH), then run this script again"


def _archive_step(pack: ArtPack, archive: Archive, folder: pathlib.Path, opener, sevenzip, runner, dry_run: bool) -> str | None:
    """Bring one archive into place; returns the step left for the user, or None when it is done
    (or, in a dry run, when the run would do it)."""
    target = folder / archive.name
    out = folder / "extracted" / archive.into
    downloaded = False
    if not target.is_file():
        if not pack.direct:
            return f"download {archive.name} from {pack.page} into {folder.as_posix()}, then run this script again"
        if dry_run:
            print(f"would fetch {archive.name} from {pack.page} into {folder.as_posix()}")
            return None
        try:
            print(f"fetch {pack.key}: {archive.name}")
            _download_from_page(opener, pack.page, archive.name, target)
            downloaded = True
        except Exception as e:  # noqa: BLE001
            return f"{e}; download {archive.name} by hand from {pack.page} into {folder.as_posix()}"
    if archive.kind == "file":
        return None
    if dry_run:
        if archive.kind == "rar" and sevenzip is None:
            return _seven_zip_step(target, out)
        print(f"would unpack {target.as_posix()} into {out.as_posix()}")
        return None
    try:
        _unpack(archive, target, out, sevenzip, runner)
    except NeedsSevenZip:
        return _seven_zip_step(target, out)
    except Exception as e:  # noqa: BLE001
        if downloaded:
            target.unlink(missing_ok=True)  # so the next run downloads it again
        return f"{e}; unpack {target.as_posix()} into {out.as_posix()} by hand, or fetch it again from {pack.page} into {folder.as_posix()}"
    return None


def fetch_art_pack(pack: ArtPack, root: pathlib.Path, *, opener, sevenzip: str | None, runner, today: datetime.date, dry_run: bool = False) -> list[str]:
    """Fetch, unpack and license one art pack; returns the steps left for the user (empty when it
    is complete, or in a dry run when the run would complete it)."""
    folder = root / pack.folder
    pending = [archive for archive in pack.archives if not _archive_done(folder, archive)]
    if not pending and (folder / LICENCE_FILE).is_file():
        print(f"skip  {pack.key} (exists)")
        return []
    steps = []
    for archive in pending:
        step = _archive_step(pack, archive, folder, opener, sevenzip, runner, dry_run)
        if step is not None:
            print(f"TODO  {pack.key}: {step}")
            steps.append(step)
    if not steps and not dry_run:
        if not (folder / LICENCE_FILE).is_file():
            write_licence(pack, folder, today)
        print(f"ok    {pack.key}")
    return steps


def fetch_art_packs(root: pathlib.Path, manual: list[str], *, opener, sevenzip: str | None, runner, today: datetime.date, dry_run: bool) -> None:
    for pack in ART_PACKS:
        steps = fetch_art_pack(pack, root, opener=opener, sevenzip=sevenzip, runner=runner, today=today, dry_run=dry_run)
        manual.extend(f"{pack.key}: {step}" for step in steps)


def print_list() -> None:
    print("Art packs (docs/ASSETS.md; direct = fetched from OpenGameArt, manual = itch.io click-through):")
    for pack in ART_PACKS:
        how = "direct" if pack.direct else "manual"
        version = f" {pack.version}" if pack.version else ""
        print(f"  {pack.folder:<30} {how:<6}  {pack.licence}  ({pack.name}{version}, {pack.author}; {pack.page})")
    print("\nKenney packs (CC0 1.0, kenney.nl):")
    for slug, sub in PACKS.items():
        folder = f"kenney/{sub}/{slug}"
        print(f"  {folder:<40} https://kenney.nl/assets/{slug}")
    print("\nFonts (SIL OFL 1.1, Google Fonts):")
    for name, url in FONTS.items():
        print(f"  {'fonts/' + name:<40} {url}")


def main(argv: list[str] | None = None, *, opener=None, find_7zip=find_7zip, runner=subprocess.run, today: datetime.date | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n", 1)[0])
    ap.add_argument("--dest", default=str(pathlib.Path(__file__).resolve().parent.parent / "game" / "assets"))
    ap.add_argument("--list", action="store_true", help="print every pack with its folder and licence, download nothing")
    ap.add_argument("--dry-run", action="store_true", help="print what a run would do, write and download nothing")
    args = ap.parse_args(argv)
    if args.list:
        print_list()
        return 0
    root = pathlib.Path(args.dest)
    if args.dry_run:
        opener = None  # a dry run must never reach the network: any fetch would fail loudly
    elif opener is None:
        opener = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(http.cookiejar.CookieJar()))
    failed: list[str] = []
    manual: list[str] = []
    fetch_packs(opener, root, failed, args.dry_run)
    fetch_fonts(opener, root, failed, args.dry_run)
    fetch_art_packs(root, manual, opener=opener, sevenzip=find_7zip(), runner=runner, today=today or datetime.date.today(), dry_run=args.dry_run)
    if failed:
        print("\nManual downloads needed:", ", ".join(failed))
    if manual:
        print("\nManual steps needed:")
        for step in manual:
            print(f"  {step}")
    return 1 if failed or manual else 0


if __name__ == "__main__":
    # A console that cannot show a name (Woźniak on cp1252) gets an escape, never a crash.
    sys.stdout.reconfigure(errors="backslashreplace")
    sys.exit(main())

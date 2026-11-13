"""The one guard the art tools share: nothing is written inside a download folder of the packs root
(`oga/`, `itch/`, `kenney/`), which holds other people's art and is git-ignored. Each tool passes
its own error class so its message and its tests keep their names."""
import pathlib

DOWNLOAD_FOLDERS = ("oga", "itch", "kenney")


def out_folder(out, packs, error=ValueError):
    """`out` resolved; raises `error` when it is inside a download folder of `packs`."""
    out = pathlib.Path(out).resolve()
    for folder in DOWNLOAD_FOLDERS:
        if out.is_relative_to(pathlib.Path(packs).resolve() / folder):
            raise error(f"{out} is inside the download folder {folder}/, where nothing is written")
    return out

"""Draw the raft fittings' overlays (island-stop task 3.6): game/assets/art/structures/raft_fittings.png.

Three 64x32 cells, each aligned to a frame of raft.png so it is drawn over the raft standing
bottom-centre on the same origin: the clavazón's nail heads on the deck, the defensas' two tubes
lashed along the front edge, and the toldo's tarp on four posts over the back of the deck. Drawn by
hand here in DB32 colours of the master palette (the tarp's blues, the nails' and tubes' greys),
every edge pixel in the structures' dark outline tones, rough first, as the art direction allows;
a proper pass belongs with the art review (design.md "Open Questions").

    python3 tools/art/raft_fittings.py [--out PATH]
"""
import argparse
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import png  # noqa: E402

CELL_W = 64
CELL_H = 32
ORDER = ("raft_clavazon", "raft_defensas", "raft_toldo")
OUT = pathlib.Path(__file__).resolve().parents[2] / "game/assets/art/structures/raft_fittings.png"

VALHALLA = "#222034"
OPAL = "#323c39"
LOULOU = "#45283c"
GREY = "#847e87"
GREY_LIGHT = "#9badb7"
STEEL = "#cbdbfc"
TARP_LIGHT = "#639bff"
TARP = "#5b6ee1"
TARP_DARK = "#3f3f74"


def _put(image, x, y, colour):
    if 0 <= x < image.width and 0 <= y < image.height:
        r, g, b = png.parse_colour(colour)
        i = (y * image.width + x) * 4
        image.pixels[i:i + 4] = bytes((r, g, b, 255))


def clavazon(image, left):
    """Nail heads between the lashings on each plank row: a steel pixel ringed in the dark tones,
    so every edge pixel is an outline colour as structures are."""
    for x in (24, 38):
        for y in (5, 12, 19):
            _put(image, left + x, y, STEEL)
            for dx, dy, colour in ((-1, 0, OPAL), (1, 0, VALHALLA), (0, -1, OPAL), (0, 1, VALHALLA)):
                _put(image, left + x + dx, y + dy, colour)


def _ring(image, cx, cy, rx, ry, hole_rx, hole_ry):
    for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
        for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
            dx = (x + 0.5 - cx)
            dy = (y + 0.5 - cy)
            outer = (dx / rx) ** 2 + (dy / ry) ** 2
            inner = (dx / hole_rx) ** 2 + (dy / hole_ry) ** 2
            if outer > 1.0 or inner < 1.0:
                continue
            edge = outer > 0.62 or inner < 1.6
            if edge:
                colour = OPAL
            elif dy < 0:
                colour = GREY_LIGHT
            else:
                colour = GREY
            _put(image, x, y, colour)


def defensas(image, left):
    """Two inner tubes lying along the deck's front edge, outlined in opal."""
    for cx in (23.0, 41.0):
        _ring(image, left + cx, 28.0, 7.0, 3.6, 2.8, 1.2)


def toldo(image, left):
    """A tarp on four posts over the back half of the deck: a roof, its front fold and the posts."""
    for x in (15, 50):
        for y in range(9, 21):
            _put(image, left + x, y, LOULOU)
    top, fold, bottom = 0, 6, 9
    first, last = 12, 53
    for y in range(top, bottom + 1):
        for x in range(first, last + 1):
            if y in (top, bottom) or x in (first, last):
                colour = VALHALLA
            elif y >= fold:
                colour = TARP_DARK if y == bottom - 1 else TARP
            elif x in (25, 39):
                colour = TARP
            elif y == top + 1:
                colour = STEEL if x % 6 == 0 else TARP_LIGHT
            else:
                colour = TARP_LIGHT
            _put(image, left + x, y, colour)


def _rim(image):
    """Any opaque pixel with a clear 4-neighbour (or the cell's border) and not already a dark
    tone becomes opal, as tools/art/check.py wants a structure's edge."""
    dark = {png.parse_colour(c) for c in (VALHALLA, OPAL, LOULOU)}
    opal = png.parse_colour(OPAL)

    def alpha(x, y):
        if not (0 <= y < image.height) or not (0 <= x < image.width) or x // CELL_W != cell:
            return 0
        return image.pixels[(y * image.width + x) * 4 + 3]

    edges = []
    for y in range(image.height):
        for x in range(image.width):
            i = (y * image.width + x) * 4
            cell = x // CELL_W
            if image.pixels[i + 3] == 0 or tuple(image.pixels[i:i + 3]) in dark:
                continue
            if any(alpha(x + dx, y + dy) == 0 for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                edges.append(i)
    for i in edges:
        image.pixels[i:i + 3] = bytes(opal)


def sheet():
    image = png.blank(CELL_W * len(ORDER), CELL_H)
    for index, draw in enumerate((clavazon, defensas, toldo)):
        draw(image, index * CELL_W)
    _rim(image)
    return image


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--out", type=pathlib.Path, default=OUT)
    args = parser.parse_args(argv)
    png.write_png(args.out, sheet())
    print(f"wrote {args.out}")


if __name__ == "__main__":
    main()

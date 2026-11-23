"""Tests for terrain.py, the terrain art builder of design.md D11 to D13, T13, T14 and K35 to K39,
on a fixture pack written to a scratch folder: key out and recolour, compose the hand tiles from
quadrants, stamp the brush set, lay the sheets out, mask the plain tiles, wrap the foam round the
sand edge and cut the water texture.

Run: python -I -m unittest discover -s tools/art -p "test_*.py"
"""
import contextlib
import io
import json
import pathlib
import tempfile
import unittest

import png
import terrain

GRASS = (0x10, 0xC0, 0x10)  # off-palette pack colours
BLUE = (0x10, 0x10, 0xC0)
WHITE = (0xFF, 0xFF, 0xFF)
SAND = (0xEE, 0xC3, 0x9A)
ROCK = (0x84, 0x7E, 0x87)
DEEP = (0x30, 0x60, 0x82)
BLACK = (0, 0, 0)
PALETTE = [SAND, ROCK, DEEP, WHITE, BLACK]


def filled(colour, width=16, height=16, rows=None, columns=None):
    """A tile of one colour on the given rows and columns (all of them by default)."""
    image = png.blank(width, height)
    for y in rows if rows is not None else range(height):
        for x in columns if columns is not None else range(width):
            image.set(x, y, colour + (255,))
    return image


def numbered():
    """A stamp with a different colour on each pixel and a transparent one-pixel border."""
    image = png.blank(16, 16)
    for y in range(1, 15):
        for x in range(1, 15):
            image.set(x, y, (x * 16, y * 16, 0, 255))
    return image


def opaque_rows(image):
    return [y for y in range(image.height) if any(image.alpha(x, y) for x in range(image.width))]


def opaque_columns(image):
    return [x for x in range(image.width) if any(image.alpha(x, y) for y in range(image.height))]


def mirrored(image):
    out = png.blank(image.width, image.height)
    for y in range(image.height):
        for x in range(image.width):
            out.set(image.width - 1 - x, y, image.get(x, y))
    return out


def enclosed_clear(image):
    """The clear pixels that no 4-connected run of clear pixels joins to the image's border: holes
    the drawn pixels close in, where the ground shows through (design pass TR14)."""
    seen = set()
    todo = [(x, y) for y in range(image.height) for x in range(image.width)
            if (x in (0, image.width - 1) or y in (0, image.height - 1)) and not image.alpha(x, y)]
    while todo:
        x, y = todo.pop()
        if (x, y) in seen:
            continue
        seen.add((x, y))
        for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
            if 0 <= nx < image.width and 0 <= ny < image.height and not image.alpha(nx, ny) and (nx, ny) not in seen:
                todo.append((nx, ny))
    return [(x, y) for y in range(image.height) for x in range(image.width) if not image.alpha(x, y) and (x, y) not in seen]


class PieceTests(unittest.TestCase):
    def test_cut_takes_one_16_px_tile_and_refuses_one_off_the_sheet(self):
        sheet = png.blank(32, 16)
        sheet.set(16, 0, GRASS + (255,))
        self.assertEqual(terrain.cut(sheet, 1, 0).get(0, 0), GRASS + (255,))
        with self.assertRaisesRegex(terrain.TerrainError, r"tile \(2, 0\)"):
            terrain.cut(sheet, 2, 0, "sand")

    def test_recolour_maps_keys_out_and_drops_partial_alpha(self):
        tile = filled(GRASS)
        tile.set(0, 0, BLUE + (255,))
        tile.set(1, 0, BLACK + (102,))
        out = terrain.recolour(tile, {GRASS: SAND}, {BLUE}, "sand 3")
        self.assertEqual(out.get(5, 5), SAND + (255,))
        self.assertEqual(out.alpha(0, 0), 0)
        self.assertEqual(out.alpha(1, 0), 0)
        self.assertEqual(tile.get(5, 5), GRASS + (255,), "the source tile is not changed")

    def test_recolour_refuses_a_colour_the_recipe_does_not_name(self):
        tile = filled(GRASS)
        tile.set(3, 3, (1, 2, 3, 255))
        with self.assertRaisesRegex(terrain.TerrainError, "sand 3.*#010203"):
            terrain.recolour(tile, {GRASS: SAND}, set(), "sand 3")

    def test_quadrants_takes_each_quarter_from_its_own_tile(self):
        tiles = [filled(c) for c in (SAND, ROCK, DEEP, WHITE)]
        out = terrain.quadrants(*tiles)
        self.assertEqual([out.get(0, 0)[:3], out.get(8, 7)[:3], out.get(7, 8)[:3], out.get(15, 15)[:3]], [SAND, ROCK, DEEP, WHITE])

    def test_stamped_draws_the_centre_stamp_and_a_quarter_stamp_on_each_land_corner(self):
        stamp = numbered()
        self.assertEqual(terrain.stamped(stamp, 0), stamp)
        north_west = terrain.stamped(stamp, terrain.NW)
        self.assertEqual(north_west.get(0, 0), stamp.get(8, 8), "the corner stamp is centred on the corner")
        self.assertEqual(north_west.get(5, 5), stamp.get(5, 5), "the centre stamp is in front of a northern corner")
        self.assertEqual(north_west.alpha(15, 15), 0)
        south_east = terrain.stamped(stamp, terrain.SE)
        self.assertEqual(south_east.get(9, 9), stamp.get(1, 1), "a southern corner stamp is in front of the centre")
        self.assertEqual(terrain.stamped(stamp, 15).get(15, 0), stamp.get(7, 8))

    def test_mirrored_flips_a_tile_left_to_right(self):
        tile = png.blank(16, 16)
        tile.set(0, 3, SAND + (255,))
        self.assertEqual(terrain.mirrored(tile).get(15, 3), SAND + (255,))

    def test_set_sheet_puts_mask_m_at_column_m_mod_4_row_m_div_4_and_the_variants_on_row_4(self):
        tiles = {mask: filled((mask, 0, 0)) for mask in range(16)}
        sheet = terrain.set_sheet(tiles, [filled(WHITE), filled(ROCK)])
        self.assertEqual((sheet.width, sheet.height), (64, 80))
        self.assertEqual(sheet.get(3 * 16, 0)[:3], (3, 0, 0))
        self.assertEqual(sheet.get(2 * 16, 3 * 16)[:3], (14, 0, 0))
        self.assertEqual(sheet.get(0, 64)[:3], WHITE)
        self.assertEqual(sheet.get(16, 64)[:3], ROCK)
        self.assertEqual(sheet.alpha(32, 64), 0)
        self.assertEqual(terrain.sheet_tile(sheet, 14), tiles[14])

    def test_set_sheet_refuses_a_missing_mask(self):
        with self.assertRaisesRegex(terrain.TerrainError, "mask 15"):
            terrain.set_sheet({mask: filled(SAND) for mask in range(15)}, [])

    def test_masked_cuts_a_tile_by_another_tiles_alpha(self):
        out = terrain.masked(filled(ROCK), filled(SAND, rows=range(0, 12)))
        self.assertEqual(out.get(4, 11), ROCK + (255,))
        self.assertEqual(out.alpha(4, 12), 0)


def land_where(keep):
    """A sand tile with land on the pixels `keep(x, y)` picks."""
    tile = png.blank(16, 16)
    for y in range(16):
        for x in range(16):
            if keep(x, y):
                tile.set(x, y, SAND + (255,))
    return tile


def touching_land_edge(tile, x, y):
    """Whether a land pixel has a water pixel among the 8 round it."""
    return any(not tile.alpha(x + dx, y + dy) for dx in (-1, 0, 1) for dy in (-1, 0, 1)
               if (dx or dy) and 0 <= x + dx < 16 and 0 <= y + dy < 16)


def touching_land(tile, x, y):
    """Whether any of the 8 pixels round (x, y) is land."""
    return any(tile.alpha(x + dx, y + dy) for dx in (-1, 0, 1) for dy in (-1, 0, 1)
               if (dx or dy) and 0 <= x + dx < 16 and 0 <= y + dy < 16)


class FoamTests(unittest.TestCase):
    def frame(self):
        """An Eldiran-like frame: land on rows 0 to 5, a foam line on row 6 and a wash on row 5."""
        frame = filled((0x9D, 0x51, 0x2D), rows=range(0, 6))
        for x in range(16):
            frame.set(x, 6, WHITE + (255,))
        for x in range(0, 4):
            frame.set(x, 5, WHITE + (255,))
        return frame

    def test_the_foam_starts_on_the_row_after_the_sand_ends(self):
        sand = filled(SAND, rows=range(0, 12))
        piece = terrain.foam_piece(terrain.shore_field(sand), self.frame(), 6, WHITE, WHITE)
        self.assertEqual(opaque_rows(piece), [11, 12])
        self.assertEqual([x for x in range(16) if piece.alpha(x, 11)], [0, 1, 2, 3], "the wash runs one row up the sand")
        self.assertEqual(piece.get(9, 12), WHITE + (255,))

    def test_the_foam_wraps_round_a_shore_that_faces_east_north_and_west(self):
        field = terrain.shore_field(filled(SAND, columns=range(0, 10)))
        self.assertEqual(opaque_columns(terrain.foam_piece(field, self.frame(), 6, WHITE, WHITE)), [9, 10])
        north = terrain.foam_piece(terrain.shore_field(filled(SAND, rows=range(5, 16))), self.frame(), 6, WHITE, WHITE)
        self.assertEqual(opaque_rows(north), [4, 5])
        west = terrain.foam_piece(terrain.shore_field(filled(SAND, columns=range(4, 16))), self.frame(), 6, WHITE, WHITE)
        self.assertEqual(opaque_columns(west), [3, 4])

    def test_a_tile_with_no_shore_has_no_foam(self):
        self.assertTrue(terrain.foam_piece(terrain.shore_field(filled(SAND)), self.frame(), 6, WHITE, WHITE).is_empty())
        self.assertTrue(terrain.foam_piece(terrain.shore_field(png.blank(16, 16)), self.frame(), 6, WHITE, WHITE).is_empty())

    def shapes(self):
        return {
            "outer corner": land_where(lambda x, y: x < 8 and y < 8),
            "inner corner": land_where(lambda x, y: x < 8 or y < 8),
            "diagonal": land_where(lambda x, y: x + y < 15),
            "islet": land_where(lambda x, y: (x - 7.5) ** 2 + (y - 7.5) ** 2 <= 20),
        }

    def test_the_shore_field_counts_steps_from_the_edge_all_the_way_round_a_corner_or_an_islet(self):
        for name, tile in self.shapes().items():
            field = terrain.shore_field(tile)
            self.assertEqual(len(field), 256, name)
            for x, y, steps, _along in field:
                if tile.alpha(x, y):
                    self.assertEqual(steps == 0, touching_land_edge(tile, x, y), f"{name}: last sand pixel at ({x}, {y})")
                    self.assertLessEqual(steps, 0, name)
                else:
                    self.assertEqual(steps == 1, touching_land(tile, x, y), f"{name}: first water pixel at ({x}, {y})")
                    self.assertGreaterEqual(steps, 1, name)

    def test_the_foam_has_no_gap_round_a_corner_or_an_islet(self):
        for name, tile in self.shapes().items():
            piece = terrain.foam_piece(terrain.shore_field(tile), self.frame(), 6, WHITE, WHITE)
            first_water = {(x, y) for y in range(16) for x in range(16) if not tile.alpha(x, y) and touching_land(tile, x, y)}
            on_first_row = {(x, y) for y in range(16) for x in range(16) if piece.alpha(x, y) and not tile.alpha(x, y)}
            self.assertEqual(on_first_row & first_water, first_water, f"{name}: a first water pixel has no foam")
            self.assertTrue(first_water, name)
            for x, y in first_water:
                self.assertEqual(piece.get(x, y), WHITE + (255,), name)

    def test_a_straight_shore_never_turns_and_a_square_corner_turns_only_on_its_outer_diagonal(self):
        self.assertEqual(terrain.turning(filled(SAND, rows=range(0, 12))), set())
        self.assertEqual(terrain.turning(filled(SAND)), set(), "no shore at all")
        corner = self.shapes()["outer corner"]  # land where x < 8 and y < 8
        bends = terrain.turning(corner)
        self.assertIn((8, 8), bends)
        self.assertIn((10, 10), bends)
        self.assertNotIn((7, 7), bends, "the sand's nearest water is straight beside it")
        self.assertNotIn((12, 3), bends, "beside a straight run of the edge")

    def test_with_corners_the_foam_is_lighter_where_the_shore_turns_but_keeps_its_first_water_step(self):
        frame = filled(WHITE, rows=range(2, 10))  # white from three steps up the sand to four out
        islet = self.shapes()["islet"]
        field = terrain.shore_field(islet)
        bends = terrain.turning(islet)
        plain = terrain.foam_piece(field, frame, 6, WHITE, WHITE)
        lighter = terrain.foam_piece(field, frame, 6, WHITE, WHITE, corners=(bends, 2, ROCK))
        trimmed = faded = 0
        for x, y, steps, _along in field:
            if steps == 1:
                self.assertEqual(lighter.get(x, y), WHITE + (255,), f"({x}, {y}): the first water step stays white")
            elif (x, y) in bends and steps <= -2:
                self.assertEqual(lighter.alpha(x, y), 0, f"({x}, {y}): the wash keeps only the last two sand steps")
                trimmed += plain.alpha(x, y) > 0
            elif (x, y) in bends and steps >= 2 and plain.alpha(x, y):
                self.assertEqual(lighter.get(x, y)[:3], ROCK, f"({x}, {y}): the outer foam fades")
                faded += 1
            elif (x, y) not in bends:
                self.assertEqual(lighter.get(x, y), plain.get(x, y), f"({x}, {y}): untouched where the shore runs straight")
        self.assertGreater(trimmed, 0, "the fixture has wash to trim")
        self.assertGreater(faded, 0, "and outer foam to fade")
        straight = terrain.shore_field(filled(SAND, rows=range(0, 12)))
        self.assertEqual(terrain.foam_piece(straight, frame, 6, WHITE, WHITE, corners=(set(), 2, ROCK)), terrain.foam_piece(straight, frame, 6, WHITE, WHITE))

    def test_the_fade_colours_the_foam_from_that_distance_on(self):
        frame = self.frame()
        for y in range(7, 10):
            for x in range(16):
                frame.set(x, y, WHITE + (255,))
        field = terrain.shore_field(filled(SAND, rows=range(0, 12)))
        piece = terrain.foam_piece(field, frame, 6, WHITE, WHITE, fade=(3, ROCK))
        self.assertEqual([piece.get(4, y)[:3] for y in (12, 13, 14, 15)], [WHITE, WHITE, ROCK, ROCK])


class ShadeTests(unittest.TestCase):
    def test_a_shade_tile_is_the_shape_in_one_colour_and_softer_at_its_edge(self):
        tile = terrain.shade_tile(filled(SAND, rows=range(0, 12)), BLACK, 60, (20, 40))
        self.assertEqual([tile.get(4, y) for y in (9, 10, 11, 12)], [BLACK + (60,), BLACK + (40,), BLACK + (20,), terrain.CLEAR])

    def test_a_whole_shape_is_shaded_evenly_and_an_empty_one_not_at_all(self):
        whole = terrain.shade_tile(filled(SAND), BLACK, 60, (20, 40))
        self.assertEqual({whole.get(x, y) for x in range(16) for y in range(16)}, {BLACK + (60,)})
        self.assertTrue(terrain.shade_tile(png.blank(16, 16), BLACK, 60, (20, 40)).is_empty())


class ShoreCutTests(unittest.TestCase):
    def edge(self):
        return filled(SAND, rows=range(0, 12))

    def test_a_shore_cut_keeps_a_tile_only_on_the_shape(self):
        edge = self.edge()
        cut = terrain.shore_cut(filled(ROCK), edge, terrain.shore_field(edge))
        self.assertEqual(opaque_rows(cut), list(range(0, 12)))
        self.assertEqual(cut.colours(), {ROCK})

    def test_an_inset_leaves_the_shapes_edge_pixels_bare_and_a_rim_colours_the_cut(self):
        edge = self.edge()
        cut = terrain.shore_cut(filled(ROCK), edge, terrain.shore_field(edge), inset=1, rim=BLACK)
        self.assertEqual(opaque_rows(cut), list(range(0, 11)), "the sand's last row shows")
        self.assertEqual({cut.get(x, 10)[:3] for x in range(16)}, {BLACK})
        self.assertEqual({cut.get(x, 9)[:3] for x in range(16)}, {ROCK})

    def test_the_rim_of_a_diagonal_is_one_pixel_per_row_not_a_stair(self):
        diagonal = land_where(lambda x, y: x + y < 15)
        line = {(x, 14 - x) for x in range(15)}
        rimmed = terrain.rimmed(terrain.masked(filled(ROCK), diagonal), diagonal, BLACK)
        cut = terrain.shore_cut(filled(ROCK), diagonal, terrain.shore_field(diagonal), 0, BLACK)
        for name, tile in (("rimmed", rimmed), ("shore_cut", cut)):
            rim = {(x, y) for y in range(16) for x in range(16) if tile.alpha(x, y) and tile.get(x, y)[:3] == BLACK}
            self.assertEqual(rim, line, f"{name}: the rim is the pixels with a 4-neighbour in the sea")
            self.assertEqual(tile.get(5, 8)[:3], ROCK, f"{name}: the pixel diagonal to the sea is not rim")

    def test_a_shore_cut_never_adds_a_pixel_the_tile_does_not_have(self):
        edge = self.edge()
        tile = filled(ROCK, rows=range(4, 16))
        cut = terrain.shore_cut(tile, edge, terrain.shore_field(edge), rim=BLACK)
        self.assertEqual(opaque_rows(cut), list(range(4, 12)))

    def test_a_shore_sheet_holds_own_mask_d_cut_by_sand_mask_s_at_column_s_row_d(self):
        shape = terrain.set_sheet({mask: (filled(SAND) if mask == 15 else self.edge()) for mask in range(16)}, [])
        rows = [[filled(ROCK) for _mask in range(16)], [filled(GRASS) for _mask in range(16)]]
        sheet = terrain.shore_sheet(rows, shape)
        self.assertEqual((sheet.width, sheet.height), (256, 512))
        for s in range(16):
            for d in range(16):
                first = sheet.crop(s * 16, d * 16, 16, 16)
                second = sheet.crop(s * 16, (16 + d) * 16, 16, 16)
                if s == 15 or d & ~s:
                    self.assertTrue(first.is_empty() and second.is_empty(), f"no tile at {s}, {d}")
                else:
                    self.assertEqual(opaque_rows(first), list(range(0, 12)), f"{s}, {d}")
                    self.assertEqual((first.colours(), second.colours()), ({ROCK}, {GRASS}))


def block(colour, x0, y0, width, height):
    """A blank tile with a block of one colour."""
    return filled(colour, rows=range(y0, y0 + height), columns=range(x0, x0 + width))


def drawn(image):
    return {(x, y): image.get(x, y) for y in range(image.height) for x in range(image.width) if image.alpha(x, y)}


class FitTests(unittest.TestCase):
    """art-coast-pass D1: a shore bush is moved whole onto the sand, not cut by it."""

    def edge(self):
        return filled(SAND, rows=range(0, 12))  # sand on rows 0 to 11, the sea south of it

    def test_the_search_takes_the_smallest_shift_that_keeps_the_piece_on_the_sand_at_the_inset(self):
        edge = self.edge()
        field = terrain.shore_field(edge)
        piece = block(ROCK, 6, 10, 4, 3)  # rows 10 to 12: off the sand by one row
        self.assertEqual(terrain.fit_shift(edge, field, piece, 0), (0, -1))
        self.assertEqual(terrain.fit_shift(edge, field, piece, 1), (0, -2), "row 11 is the edge, so the inset keeps it bare")
        self.assertEqual(terrain.fit_shift(edge, field, block(ROCK, 6, 4, 4, 3), 1), (0, 0), "a piece on the sand stays put")

    def test_the_search_breaks_ties_by_the_smaller_upward_move_then_by_x(self):
        notch = filled(SAND)
        for y in range(0, 6):
            for x in range(6, 10):
                notch.set(x, y, terrain.CLEAR)  # a notch of sea in the top middle
        field = terrain.shore_field(notch)
        self.assertEqual(terrain.fit_shift(notch, field, block(ROCK, 7, 3, 2, 2), 0), (-3, 0), "three left, three right or three down: no move down first, then the lower dx")

    def test_nothing_fits_a_piece_wider_than_the_sand(self):
        edge = filled(SAND, columns=range(0, 6))
        self.assertIsNone(terrain.fit_shift(edge, terrain.shore_field(edge), block(ROCK, 2, 2, 8, 3), 0))

    def test_fitted_tries_each_piece_at_the_inset_then_the_fallback_then_the_next_piece(self):
        edge = self.edge()
        field = terrain.shore_field(edge)
        big = block(ROCK, 0, 0, 16, 12)  # fits only at inset 0
        small = block(DEEP, 5, 5, 3, 3)
        index, inset, moved = terrain.fitted(edge, field, [big, small], [1, 0])
        self.assertEqual((index, inset), (0, 0), "the pick at the fallback inset before the tuft")
        self.assertEqual(drawn(moved), drawn(big))
        index, inset, moved = terrain.fitted(edge, field, [big, small], [1])
        self.assertEqual((index, inset), (1, 1), "the tuft when the pick does not fit")
        self.assertEqual(drawn(moved), drawn(small))
        self.assertIsNone(terrain.fitted(edge, field, [big], [1]))

    def test_a_fitted_shore_tile_draws_the_quarters_on_the_sand_under_and_over_the_whole_piece(self):
        edge = self.edge()
        field = terrain.shore_field(edge)
        stamp = numbered()
        centre = terrain.shifted(block(ROCK, 4, 2, 6, 5), 0, 0)
        tile = terrain.fit_tile(stamp, terrain.NW | terrain.NE, edge, field, centre)
        self.assertEqual(tile.get(0, 0), stamp.get(8, 8), "the north-west quarter stamp")
        self.assertEqual(tile.get(15, 0), stamp.get(7, 8), "the north-east one")
        self.assertEqual(tile.get(5, 3), ROCK + (255,), "the piece is in front of the north quarters")
        self.assertEqual(terrain.fit_tile(stamp, 0, edge, field, centre), centre, "own mask 0 is the piece alone")
        low = terrain.shifted(block(ROCK, 2, 6, 6, 5), 0, 0)
        south = terrain.fit_tile(stamp, terrain.SW, filled(SAND), terrain.shore_field(filled(SAND)), low)
        self.assertEqual(south.get(5, 9), stamp.get(13, 1), "a south quarter is in front of the piece")
        self.assertEqual(south.get(5, 7), ROCK + (255,))


class BuildTests(unittest.TestCase):
    def setUp(self):
        scratch = tempfile.TemporaryDirectory()
        self.addCleanup(scratch.cleanup)
        self.root = pathlib.Path(scratch.name)
        self.packs = self.root / "packs"
        (self.packs / "oga").mkdir(parents=True)
        self.fixes = self.root / "fixes"
        self.fixes.mkdir()
        self.out = self.root / "art"
        sheet = png.blank(64, 32)
        sheet.paste(filled(GRASS), 0, 0)  # the full tile
        edge = filled(GRASS, rows=range(0, 12))
        for x in range(16):
            edge.set(x, 12, WHITE + (255,))
            edge.set(x, 13, BLUE + (255,))
        sheet.paste(edge, 16, 0)  # an edge tile with a baked foam rim and water strip
        sheet.paste(filled(BLUE, 32, 32), 32, 0)  # the water
        png.write_png(self.packs / "oga" / "world.png", sheet)
        strip = png.blank(1 + 17 * 2, 32)
        frame = filled((0x9D, 0x51, 0x2D), rows=range(0, 6))
        for x in range(16):
            frame.set(x, 6, WHITE + (255,))
        strip.paste(frame, 1, 9)
        strip.paste(frame, 18, 9)
        png.write_png(self.packs / "oga" / "waves.png", strip)

    def recipe(self):
        tiles = {str(mask): [1, 0] for mask in range(1, 15)}
        tiles["15"] = [0, 0]
        hexes = {png.colour_hex(GRASS): png.colour_hex(SAND)}
        erase = [png.colour_hex(WHITE), png.colour_hex(BLUE)]
        return {
            "sources": {"world": "oga/world.png", "waves": "oga/waves.png"},
            "sets": [
                {"id": "sand", "source": "world", "map": hexes, "erase": erase, "tiles": tiles, "quadrants": {"0": [15, 15, 1, 1]}, "variants": ["15", "3h"]},
                {"id": "brush", "source": "world", "map": hexes, "erase": erase, "stamp": [1, 0], "variants": ["0"]},
            ],
            "plain": {"source": "world", "shape": "sand", "rows": [{"id": "rock", "tile": [0, 0], "map": {png.colour_hex(GRASS): png.colour_hex(ROCK)}}]},
            "water": {"source": "world", "rect": [32, 0, 32, 32], "map": {png.colour_hex(BLUE): png.colour_hex(DEEP)}, "ramps": [["#306082"], ["#847e87"]]},
            "foam": {"source": "waves", "shape": "sand", "origin": [1, 9], "step": 17, "frames": 2, "land_rows": 6, "white": "#ffffff", "colour": "#ffffff"},
            "shade": {"shape": "sand", "colour": "#000000", "alpha": 60, "edge": [20, 40], "spots": "spots.png",
                      "hut": {"north": 60, "south": 13, "bands": 3}},
            "copies": [{"from": "pool.png", "to": "terrain/pool.png"}],
        }

    def spots(self):
        """A hand-drawn strip of spot shades: one soft pixel in its first cell."""
        strip = png.blank(64, 16)
        strip.set(5, 5, BLACK + (30,))
        return strip

    def build(self, recipe=None, packs=None, out=None, spots=None):
        png.write_png(self.fixes / "pool.png", filled(ROCK))
        png.write_png(self.fixes / "spots.png", spots or self.spots())
        return terrain.build(recipe or self.recipe(), packs or self.packs, self.fixes, out or self.out, PALETTE, log=lambda _line: None)

    def test_build_writes_every_sheet_at_its_size(self):
        self.build()
        sizes = {}
        for path in sorted(self.out.rglob("*.png")):
            image = png.read_png(path)
            sizes[path.relative_to(self.out).as_posix()] = (image.width, image.height)
        self.assertEqual(sizes, {
            "decals/shade.png": (64, 272), "sea/foam.png": (32, 256), "sea/water.png": (32, 32), "sea/water_ramps.png": (1, 2),
            "terrain/brush.png": (64, 80), "terrain/plain.png": (256, 16), "terrain/pool.png": (16, 16), "terrain/sand.png": (64, 80),
        })

    def test_the_edge_tile_keeps_no_water_or_foam_and_the_foam_meets_it(self):
        self.build()
        sand = png.read_png(self.out / "terrain" / "sand.png")
        edge = terrain.sheet_tile(sand, 3)
        self.assertEqual(edge.colours(), {SAND})
        self.assertEqual(opaque_rows(edge)[-1], 11)
        foam = png.read_png(self.out / "sea" / "foam.png")
        self.assertEqual(opaque_rows(foam.crop(0, 3 * 16, 16, 16)), [12])
        self.assertEqual(opaque_rows(foam.crop(16, 3 * 16, 16, 16)), [12], "frame 1 is the column beside frame 0")
        self.assertTrue(foam.crop(0, 15 * 16, 32, 16).is_empty(), "the full tile has no shore")

    def test_the_quadrant_tile_the_variants_and_the_masked_plain_tiles(self):
        self.build()
        sand = png.read_png(self.out / "terrain" / "sand.png")
        islet = terrain.sheet_tile(sand, 0)
        self.assertEqual((islet.alpha(0, 3), islet.alpha(15, 11), islet.alpha(0, 13)), (255, 255, 0), "the south half is the edge tile's")
        self.assertEqual(sand.crop(0, 64, 16, 16), terrain.sheet_tile(sand, 15))
        self.assertEqual(sand.crop(16, 64, 16, 16), terrain.mirrored(terrain.sheet_tile(sand, 3)))
        plain = png.read_png(self.out / "terrain" / "plain.png")
        self.assertEqual(plain.crop(15 * 16, 0, 16, 16), filled(ROCK), "column 15 is the whole tile")
        self.assertEqual(opaque_rows(plain.crop(3 * 16, 0, 16, 16))[-1], 11, "column m is cut by the sand tile of mask m")
        water = png.read_png(self.out / "sea" / "water.png")
        self.assertEqual(water.colours(), {DEEP})

    def test_a_shore_entry_writes_the_layers_shore_sheet(self):
        recipe = self.recipe()
        recipe["sets"][1]["shore"] = {"shape": "sand", "inset": 1, "rim": "#000000"}
        recipe["plain"]["shore"] = {}
        self.build(recipe)
        brush = png.read_png(self.out / "terrain" / "brush_shore.png")
        self.assertEqual((brush.width, brush.height), (256, 256))
        tile = brush.crop(3 * 16, 0, 16, 16)  # the islet bush on a cell whose sand ends on row 11
        self.assertEqual(opaque_rows(tile)[-1], 10, "one pixel inside the sand's edge")
        self.assertEqual({tile.get(x, 10)[:3] for x in range(16) if tile.alpha(x, 10)}, {BLACK})
        self.assertTrue(brush.crop(15 * 16, 0, 16, 16).is_empty(), "the full sand tile has no shore")
        self.assertTrue(brush.crop(1 * 16, 2 * 16, 16, 16).is_empty(), "mask 2 is not inside mask 1")
        plain = png.read_png(self.out / "terrain" / "plain_shore.png")
        self.assertEqual((plain.width, plain.height), (256, 256))
        self.assertEqual(opaque_rows(plain.crop(3 * 16, 3 * 16, 16, 16)), list(range(0, 12)))

    def fit_recipe(self, **fit):
        """The recipe with a brush pick 1 that is a 5x4 rock block and a fitted brush shore."""
        recipe = self.recipe()
        recipe["sets"][1]["variants"] = ["0", "0"]
        recipe["sets"][1]["shore"] = {"shape": "sand", "inset": 1, "rim": "#000000", "fit": {"pick": 1, "fallback_inset": 0, **fit}}
        pixels = []
        for y in range(16):
            for x in range(16):
                inside = 5 <= x < 10 and 6 <= y < 10
                if inside:
                    pixels.append((16 + x, 64 + y, ROCK))
                elif y < 12:
                    pixels.append((16 + x, 64 + y, None))  # erase the rest of the stamp's copy
        fix = png.blank(64, 80)
        for x, y, rgb in pixels:
            fix.set(x, y, (0xFF, 0x00, 0xFF, 255) if rgb is None else rgb + (255,))
        png.write_png(self.fixes / "brush.png", fix)
        return recipe

    def test_fit_variants_take_a_block_of_16_rows_each_placed_by_the_same_search(self):
        recipe = self.fit_recipe(variants=["bush.png"])
        png.write_png(self.fixes / "bush.png", block(DEEP, 4, 3, 6, 6))
        self.build(recipe)
        brush = png.read_png(self.out / "terrain" / "brush_shore.png")
        self.assertEqual((brush.width, brush.height), (256, 2 * 256), "one block of 16 rows per piece")
        pick = png.read_png(self.out / "terrain" / "brush.png").crop(16, 64, 16, 16)
        bush = png.read_png(self.fixes / "bush.png")
        for s in range(1, 15):
            first = brush.crop(s * 16, 0, 16, 16)
            second = brush.crop(s * 16, 16 * 16, 16, 16)
            self.assertEqual(sorted(drawn(first).values()), sorted(drawn(pick).values()), f"mask {s}: block 0 is the pick")
            self.assertEqual(sorted(drawn(second).values()), sorted(drawn(bush).values()), f"mask {s}: block 1 is the variant, whole")
        self.assertTrue(brush.crop(15 * 16, 16 * 16, 16, 16).is_empty(), "no shore on a whole sand tile")

    def test_fit_variants_are_hand_drawn_tiles_the_recipe_reads(self):
        recipe = self.fit_recipe(variants=["missing.png"])
        with self.assertRaisesRegex(terrain.TerrainError, r"missing\.png: no such hand-drawn source"):
            self.build(recipe)
        recipe = self.fit_recipe()
        png.write_png(self.fixes / "bush.png", block(DEEP, 4, 3, 6, 6))
        with self.assertRaisesRegex(terrain.TerrainError, r"bush\.png: no step of the recipe reads it"):
            self.build(recipe)

    def test_a_fitted_shore_draws_the_pick_whole_on_the_sand_with_no_rim(self):
        self.build(self.fit_recipe())
        brush = png.read_png(self.out / "terrain" / "brush_shore.png")
        pick = png.read_png(self.out / "terrain" / "brush.png").crop(16, 64, 16, 16)
        for s in range(1, 15):
            tile = brush.crop(s * 16, 0, 16, 16)
            self.assertEqual(sorted(drawn(tile).values()), sorted(drawn(pick).values()), f"mask {s}: the whole pick")
            self.assertEqual(tile.colours(), {ROCK}, f"mask {s}: no rim")
            self.assertLessEqual(opaque_rows(tile)[-1], 10, f"mask {s}: one pixel inside the sand's edge")
        self.assertEqual(drawn(brush.crop(3 * 16, 0, 16, 16)), drawn(pick), "already on the sand: not moved")
        islet = brush.crop(0, 0, 16, 16)
        self.assertEqual(opaque_rows(islet)[-1], 10, "sand mask 0 keeps the cut")
        self.assertEqual({islet.get(x, 10)[:3] for x in range(16) if islet.alpha(x, 10)}, {BLACK}, "and its rim")
        corner = brush.crop(3 * 16, 1 * 16, 16, 16)
        self.assertEqual(corner.get(0, 0)[:3], SAND, "own mask 1 keeps its north-west quarter stamp")
        self.assertEqual(corner.get(5, 6)[:3], ROCK, "in front of which stands the pick")

    def test_a_fit_moves_the_pick_up_off_the_sea_and_falls_back_to_the_tuft(self):
        recipe = self.fit_recipe()
        low = png.read_png(self.fixes / "brush.png")
        for y in range(64 + 6, 64 + 10):  # move the block down to rows 9 to 12, off the sand
            for x in range(16 + 5, 16 + 10):
                low.set(x, y + 3, ROCK + (255,))
        for y in range(64 + 6, 64 + 9):
            for x in range(16 + 5, 16 + 10):
                low.set(x, y, (0xFF, 0x00, 0xFF, 255))
        png.write_png(self.fixes / "brush.png", low)
        self.build(recipe)
        tile = png.read_png(self.out / "terrain" / "brush_shore.png").crop(3 * 16, 0, 16, 16)
        self.assertEqual(opaque_rows(tile), [7, 8, 9, 10], "moved up three rows to stand one pixel in")
        recipe["sets"][1]["shore"]["fit"] = {"pick": 0, "fallback_inset": 1, "tuft": "tuft.png"}
        png.write_png(self.fixes / "tuft.png", block(DEEP, 6, 5, 3, 2))
        self.build(recipe)
        tile = png.read_png(self.out / "terrain" / "brush_shore.png").crop(3 * 16, 0, 16, 16)
        self.assertEqual(tile.colours(), {DEEP}, "the stamp is too wide for the sand, so the tuft stands there")

    def test_a_fit_where_nothing_fits_is_refused_naming_the_mask(self):
        recipe = self.fit_recipe()
        recipe["sets"][1]["shore"]["fit"] = {"pick": 0, "fallback_inset": 1}
        with self.assertRaisesRegex(terrain.TerrainError, r"brush shore: nothing of the fit fits whole on the sand tile of mask 1"):
            self.build(recipe)
        self.assertFalse(self.out.exists(), "nothing is written")

    def test_a_malformed_fit_is_refused_by_key(self):
        cases = [
            ("not a table", r"brush shore: \"fit\" is a table"),
            ({"fallback_inset": 0}, r"brush shore fit has no \"pick\""),
            ({"pick": 4}, r"brush shore fit: \"pick\" is a whole number from 0 to 3"),
            ({"pick": 3}, r"brush shore fit: pick 3 is not drawn"),
            ({"pick": 1, "fallback_inset": 2}, r"brush shore fit: \"fallback_inset\" is a whole number from 0 to 1"),
            ({"pick": 1, "tuft": "../tuft.png"}, r"a hand-drawn source is a lower-case name"),
            ({"pick": 1, "tuft": "missing.png"}, r"missing\.png: no such hand-drawn source"),
            ({"pick": 1, "tuft": "wide.png"}, r"wide\.png: a tuft is a drawn 16x16 tile, not 32x16"),
        ]
        png.write_png(self.fixes / "wide.png", filled(ROCK, 32, 16))
        for fit, message in cases:
            recipe = self.fit_recipe()
            recipe["sets"][1]["shore"]["fit"] = fit
            with self.subTest(fit=fit), self.assertRaisesRegex(terrain.TerrainError, message):
                self.build(recipe)
        recipe = self.fit_recipe()
        recipe["sets"][0]["shore"] = {"shape": "sand", "fit": {"pick": 0}}
        with self.assertRaisesRegex(terrain.TerrainError, r"sand shore: \"fit\" needs a stamp set"):
            self.build(recipe)
        self.assertFalse(self.out.exists(), "nothing is written")

    def test_the_foams_corners_are_checked_and_leave_a_straight_shore_as_it_was(self):
        self.build()
        straight = png.read_png(self.out / "sea" / "foam.png")
        recipe = self.recipe()
        recipe["foam"]["corners"] = {"keep": 2, "colour": png.colour_hex(ROCK)}
        self.build(recipe)
        self.assertEqual(png.read_png(self.out / "sea" / "foam.png"), straight, "the fixture's sand is straight on every mask")
        for corners, message in (("x", r"foam: \"corners\" is a table"), ({"colour": "#000000"}, r"foam corners has no \"keep\""),
                                 ({"keep": 0, "colour": "#000000"}, r"foam corners: \"keep\" is a whole number from 1 to 8"),
                                 ({"keep": 2, "colour": "black"}, r"foam corners: 'black' is not a #rrggbb colour")):
            recipe["foam"]["corners"] = corners
            with self.subTest(corners=corners), self.assertRaisesRegex(terrain.TerrainError, message):
                self.build(recipe)

    def test_a_fits_tuft_is_a_fix_the_recipe_reads(self):
        recipe = self.fit_recipe(tuft="tuft.png")
        png.write_png(self.fixes / "tuft.png", block(DEEP, 6, 5, 3, 2))
        self.build(recipe)
        del recipe["sets"][1]["shore"]["fit"]["tuft"]
        with self.assertRaisesRegex(terrain.TerrainError, r"tuft\.png: no step of the recipe reads it"):
            self.build(recipe)

    def test_a_shore_inset_is_a_small_whole_number(self):
        for bad in (-1, 8, "1", 1.5, True):
            recipe = self.recipe()
            recipe["sets"][1]["shore"] = {"shape": "sand", "inset": bad}
            with self.assertRaisesRegex(terrain.TerrainError, r"brush shore: \"inset\""):
                self.build(recipe)
        self.assertFalse(self.out.exists(), "nothing is written")

    def test_a_fix_overlay_is_blended_last_and_shapes_the_foam(self):
        fix = png.blank(64, 80)
        for x in range(16):
            fix.set(3 * 16 + x, 11, (0xFF, 0x00, 0xFF, 255))
        png.write_png(self.fixes / "sand.png", fix)
        self.build()
        self.assertEqual(opaque_rows(terrain.sheet_tile(png.read_png(self.out / "terrain" / "sand.png"), 3))[-1], 10)
        self.assertEqual(opaque_rows(png.read_png(self.out / "sea" / "foam.png").crop(0, 48, 16, 16)), [11])

    def overlay(self, *pixels):
        """A 64x80 sand overlay of (x, y, colour) pixels; a colour of None erases."""
        fix = png.blank(64, 80)
        for x, y, rgb in pixels:
            fix.set(x, y, (0xFF, 0x00, 0xFF, 255) if rgb is None else rgb + (255,))
        return fix

    def test_an_overlay_pixel_that_is_already_what_the_tool_builds_is_refused_by_sheet_and_cell(self):
        for pixel in ((5, 5, SAND), (50, 13, None), (20, 40, SAND)):
            png.write_png(self.fixes / "sand.png", self.overlay(pixel))
            cell = (pixel[0] // 16, pixel[1] // 16)
            with self.assertRaisesRegex(terrain.TerrainError, rf"sand\.png.*\({pixel[0]}, {pixel[1]}\).*cell \({cell[0]}, {cell[1]}\)"):
                self.build()
        self.assertFalse(self.out.exists(), "nothing is written")
        png.write_png(self.fixes / "sand.png", self.overlay((5, 5, DEEP), (50, 13, DEEP)))
        self.build()

    def test_a_hand_cell_is_a_blank_tile_the_overlay_must_cover_with_all_256_pixels(self):
        recipe = self.recipe()
        del recipe["sets"][0]["quadrants"]["0"]
        recipe["sets"][0]["tiles"]["0"] = "hand"
        png.write_png(self.fixes / "sand.png", self.overlay((5, 5, SAND)))
        with self.assertRaisesRegex(terrain.TerrainError, r"sand\.png.*hand cell \(0, 0\)"):
            self.build(recipe)
        whole = [(x, y, SAND if (x + y) % 5 else None) for y in range(16) for x in range(16)]
        png.write_png(self.fixes / "sand.png", self.overlay(*whole))
        self.build(recipe)
        islet = terrain.sheet_tile(png.read_png(self.out / "terrain" / "sand.png"), 0)
        self.assertEqual((islet.get(1, 1)[:3], islet.alpha(5, 0)), (SAND, 0), "the hand pixels are the tile, #ff00ff left clear")

    def test_a_map_change_reaches_the_variant_tile_under_the_hand_pixels(self):
        png.write_png(self.fixes / "sand.png", self.overlay((2, 2 + 16 * 4, DEEP)))
        self.build()
        variant = png.read_png(self.out / "terrain" / "sand.png").crop(0, 64, 16, 16)
        self.assertEqual((variant.get(5, 5)[:3], variant.get(2, 2)[:3]), (SAND, DEEP))
        recipe = self.recipe()
        recipe["sets"][0]["map"] = {png.colour_hex(GRASS): png.colour_hex(ROCK)}
        self.build(recipe)
        variant = png.read_png(self.out / "terrain" / "sand.png").crop(0, 64, 16, 16)
        self.assertEqual((variant.get(5, 5)[:3], variant.get(2, 2)[:3]), (ROCK, DEEP), "the recipe drives the variant")

    def test_a_png_in_the_fixes_folder_that_no_step_reads_is_refused_by_name(self):
        for stray in ("water.png", "shade.png", "sand_shore.png", "brush_shore.png", "plain_shore.png", "water_ramps.png", "nothing.png"):
            png.write_png(self.fixes / stray, self.overlay((5, 5, DEEP)))
            with self.assertRaisesRegex(terrain.TerrainError, rf"{stray}: no step of the recipe reads it"):
                self.build()
            (self.fixes / stray).unlink()
        recipe = self.recipe()
        del recipe["foam"]
        png.write_png(self.fixes / "foam.png", png.blank(32, 256))
        with self.assertRaisesRegex(terrain.TerrainError, r"foam\.png: no step of the recipe reads it"):
            self.build(recipe)
        self.assertFalse(self.out.exists(), "nothing is written")

    def test_every_png_the_recipe_reads_is_accepted_in_the_fixes_folder(self):
        png.write_png(self.fixes / "brush.png", self.overlay((5, 5, DEEP)))
        foam = png.blank(32, 256)
        foam.set(3, 240, WHITE + (255,))
        png.write_png(self.fixes / "foam.png", foam)
        self.build()
        self.assertTrue((self.out / "terrain" / "pool.png").exists())

    def test_a_plain_row_takes_a_rim_colour_on_its_cut_edge_and_the_foam_a_fade_colour(self):
        recipe = self.recipe()
        recipe["plain"]["rows"][0]["rim"] = "#000000"
        recipe["foam"]["fade"] = {"from": 1, "colour": png.colour_hex(ROCK)}
        self.build(recipe)
        plain = png.read_png(self.out / "terrain" / "plain.png")
        edge = plain.crop(3 * 16, 0, 16, 16)
        self.assertEqual((edge.get(4, 11)[:3], edge.get(4, 10)[:3]), (BLACK, ROCK))
        self.assertEqual(plain.crop(15 * 16, 0, 16, 16), filled(ROCK), "the whole tile has no rim")
        self.assertEqual(png.read_png(self.out / "sea" / "foam.png").colours(), {ROCK})

    def plain_overlay(self, width, *pixels):
        """A plain.png overlay `width` columns wide of (x, y, colour) pixels."""
        fix = png.blank(width * 16, 16)
        for x, y, rgb in pixels:
            fix.set(x, y, rgb + (255,))
        return fix

    def test_a_plain_row_lists_full_tile_variants_from_column_16(self):
        recipe = self.recipe()
        row = recipe["plain"]["rows"][0]
        row["map"][png.colour_hex(BLUE)] = png.colour_hex(DEEP)
        row["variants"] = [[2, 0], "15"]
        png.write_png(self.fixes / "plain.png", self.plain_overlay(18, (17 * 16 + 3, 4, BLACK)))
        self.build(recipe)
        plain = png.read_png(self.out / "terrain" / "plain.png")
        self.assertEqual((plain.width, plain.height), (18 * 16, 16), "the sheet grows to the right")
        self.assertEqual(plain.crop(16 * 16, 0, 16, 16), filled(DEEP), "a pack tile through the row's map")
        variant = plain.crop(17 * 16, 0, 16, 16)
        self.assertEqual((variant.get(3, 4)[:3], variant.get(5, 5)[:3]), (BLACK, ROCK), "the full tile with its hand pixels")
        self.assertEqual(plain.crop(15 * 16, 0, 16, 16), filled(ROCK), "the full tile itself is not changed")
        self.assertEqual(plain.crop(14 * 16, 0, 16, 16).get(3, 4)[:3], ROCK, "the cut tiles follow the full tile, not a variant")

    def test_the_plain_overlay_fixes_the_full_tile_and_the_cut_tiles_follow_it(self):
        recipe = self.recipe()
        recipe["plain"]["shore"] = {}
        png.write_png(self.fixes / "plain.png", self.plain_overlay(16, (15 * 16 + 4, 5, BLACK)))
        self.build(recipe)
        plain = png.read_png(self.out / "terrain" / "plain.png")
        self.assertEqual((plain.width, plain.height), (256, 16), "no variants, no wider")
        for mask in (15, 14, 3):
            self.assertEqual(plain.crop(mask * 16, 0, 16, 16).get(4, 5)[:3], BLACK, f"column {mask}")
        shore = png.read_png(self.out / "terrain" / "plain_shore.png")
        self.assertEqual(shore.crop(3 * 16, 3 * 16, 16, 16).get(4, 5)[:3], BLACK, "and so does the shore sheet")

    def test_a_plain_overlay_pixel_on_a_cut_column_or_of_the_wrong_size_is_refused(self):
        png.write_png(self.fixes / "plain.png", self.plain_overlay(16, (3 * 16 + 4, 5, BLACK)))
        with self.assertRaisesRegex(terrain.TerrainError, r"plain\.png.*\(52, 5\).*column 15"):
            self.build()
        png.write_png(self.fixes / "plain.png", self.plain_overlay(16, (15 * 16 + 4, 5, ROCK)))
        with self.assertRaisesRegex(terrain.TerrainError, r"plain\.png.*\(244, 5\).*not a hand pixel"):
            self.build()
        png.write_png(self.fixes / "plain.png", self.plain_overlay(17, (15 * 16 + 4, 5, BLACK)))
        with self.assertRaisesRegex(terrain.TerrainError, r"plain\.png"):
            self.build()
        self.assertFalse(self.out.exists(), "nothing is written")

    def test_a_plain_row_has_at_most_four_variants_of_its_own_tiles(self):
        for bad in (["15"] * 5, ["14"], "15", [[0]], [[9, 9]]):
            recipe = self.recipe()
            recipe["plain"]["rows"][0]["variants"] = bad
            with self.assertRaisesRegex(terrain.TerrainError, r"plain rock"):
                self.build(recipe)
        self.assertFalse(self.out.exists(), "nothing is written")

    def test_the_shade_set_follows_the_sand_shape_and_its_last_row_holds_the_spots(self):
        self.build()
        shade = png.read_png(self.out / "decals" / "shade.png")
        edge = terrain.sheet_tile(shade, 3)
        self.assertEqual([edge.get(4, y) for y in (9, 10, 11, 12)], [BLACK + (60,), BLACK + (40,), BLACK + (20,), terrain.CLEAR])
        self.assertEqual(terrain.sheet_tile(shade, 15).get(8, 8), BLACK + (60,))
        self.assertEqual(shade.crop(0, 64, 64, 16), self.spots())

    def test_the_hut_shade_is_darkest_on_the_hut_north_edge_and_never_darker_going_south(self):
        # art-prop-polish D5: under a shelter, the shade is full on the hut's north edge, under the
        # roof, and fades south. One corner set per depth band (from the hut's north edge) follows
        # the spot row: mask m of band b at (m % 4, 5 + 4 * b + m // 4).
        self.build()
        shade = png.read_png(self.out / "decals" / "shade.png")

        def hut_tile(band, mask):
            return shade.crop((mask % 4) * 16, (5 + 4 * band + mask // 4) * 16, 16, 16)

        column = []
        for band in range(3):
            tile = hut_tile(band, 15)
            rows = [tile.get(8, y)[3] for y in range(16)]
            self.assertEqual(max(rows), rows[0], f"band {band}: highest on its north row")
            self.assertTrue(all(tile.get(8, y)[:3] == BLACK for y in range(16)), "in the shade colour")
            column += rows
        self.assertEqual(column[0], 60, "full on the hut's north edge")
        self.assertEqual(column[-1], 13, "the south value on the last band's last row")
        self.assertEqual(column, sorted(column, reverse=True), "never darker going south")
        self.assertGreater(column[0], column[16], "band 1 starts lighter than band 0")
        # A mask open on its south side still ends softly there, under the ramp.
        south_open = hut_tile(0, 3)
        self.assertEqual(south_open.get(4, 12), terrain.CLEAR, "the shape's open side is clear")
        self.assertLess(south_open.get(4, 11)[3], south_open.get(4, 0)[3], "and fades into it")

    def test_a_hut_ramp_out_of_order_or_range_is_refused(self):
        for hut, pattern in (({"north": 20, "south": 60, "bands": 3}, r"shade hut: .*north.*south"),
                             ({"north": 0, "south": 0, "bands": 3}, r'shade hut: "north"'),
                             ({"north": 60, "south": 13, "bands": 0}, r'shade hut: "bands"')):
            recipe = self.recipe()
            recipe["shade"]["hut"] = hut
            with self.assertRaisesRegex(terrain.TerrainError, pattern):
                self.build(recipe)
        self.assertFalse(self.out.exists(), "nothing is written")

    def test_a_spot_strip_of_another_size_or_colour_is_refused(self):
        with self.assertRaisesRegex(terrain.TerrainError, r"spots\.png.*64x16"):
            self.build(spots=png.blank(32, 16))
        grey = self.spots()
        grey.set(5, 5, ROCK + (30,))
        with self.assertRaisesRegex(terrain.TerrainError, r"decals/shade\.png: a half-transparent pixel"):
            self.build(spots=grey)
        self.assertFalse(self.out.exists(), "nothing at all is written when a sheet is refused")

    def test_a_hand_source_is_a_bare_file_name_in_the_fixes_folder(self):
        outside = self.root / "outside.png"
        png.write_png(outside, filled(DEEP))
        bad_names = ["..\\outside.png", str(outside), "sub/x.png", "../x.png", "Pool.png", "pool.PNG", "pool", ""]
        for bad in bad_names:
            for key in ("copies", "spots"):
                recipe = self.recipe()
                if key == "copies":
                    recipe["copies"][0]["from"] = bad
                else:
                    recipe["shade"]["spots"] = bad
                with self.assertRaisesRegex(terrain.TerrainError, r"a hand-drawn source is a lower-case name ending in \.png", msg=f"{key} {bad!r}"):
                    self.build(recipe)
        self.assertFalse(self.out.exists(), "nothing is written")

    def test_a_copy_goes_to_a_folder_and_a_lower_case_png_name(self):
        for bad in ("../x.png", "/x.png", "C:/x.png", "x.png", "a/b/c.png", "terrain\\x.png", "Terrain/x.png", "terrain/x.PNG", "terrain/x", ""):
            recipe = self.recipe()
            recipe["copies"][0]["to"] = bad
            with self.assertRaisesRegex(terrain.TerrainError, r"a copy goes to <folder>/<name>\.png", msg=repr(bad)):
                self.build(recipe)
        self.assertFalse(self.out.exists(), "nothing is written")

    def test_no_sheet_is_made_twice(self):
        def twice(change):
            recipe = self.recipe()
            change(recipe)
            with self.assertRaisesRegex(terrain.TerrainError, r"made twice"):
                self.build(recipe)
        twice(lambda r: r["sets"].append(dict(r["sets"][0])))
        twice(lambda r: r["sets"].append(dict(r["sets"][1], id="plain")))
        twice(lambda r: r["sets"].append(dict(r["sets"][1], id="sand_shore")) or r["sets"][0].update(shore={"shape": "sand"}))
        twice(lambda r: r["copies"][0].update({"to": "terrain/sand.png"}))
        twice(lambda r: r["copies"][0].update({"to": "terrain/plain.png"}))
        twice(lambda r: r["copies"][0].update({"to": "sea/water.png"}))
        twice(lambda r: r["copies"][0].update({"to": "sea/water_ramps.png"}))
        twice(lambda r: r["copies"][0].update({"to": "sea/foam.png"}))
        twice(lambda r: r["copies"][0].update({"to": "decals/shade.png"}))
        twice(lambda r: r["copies"].append(dict(r["copies"][0])))
        twice(lambda r: r["plain"].update(shore={}) or r["copies"][0].update({"to": "terrain/plain_shore.png"}))
        self.assertFalse(self.out.exists(), "nothing is written")

    def test_nothing_is_written_under_a_download_folder_or_the_fixes_folder(self):
        recipe = self.recipe()
        recipe["copies"][0]["to"] = "oga/made.png"
        with self.assertRaisesRegex(terrain.TerrainError, r"download folder oga/"):
            self.build(recipe, out=self.packs)
        self.assertFalse((self.packs / "oga" / "made.png").exists())
        recipe["copies"][0]["to"] = "fixes/pool.png"
        with self.assertRaisesRegex(terrain.TerrainError, r"the fixes folder"):
            self.build(recipe, out=self.root)
        self.assertEqual((self.fixes / "pool.png").read_bytes(), png.encode_png(filled(ROCK)), "the hand source is not replaced")
        self.assertFalse((self.root / "terrain").exists(), "nothing at all is written")

    def run_main(self, recipe, palette=None, files=None):
        """terrain.main on the fixture with `recipe` written to a file: (exit code, what it printed on stderr)."""
        png.write_png(self.fixes / "pool.png", filled(ROCK))
        png.write_png(self.fixes / "spots.png", self.spots())
        palette_path = palette or self.root / "palette.png"
        if palette is None:
            image = png.blank(len(PALETTE), 1)
            for x, rgb in enumerate(PALETTE):
                image.set(x, 0, rgb + (255,))
            png.write_png(palette_path, image)
        for relative, data in (files or {}).items():
            (self.root / relative).write_bytes(data)
        recipe_path = self.root / "recipe.json"
        recipe_path.write_text(json.dumps(recipe), encoding="utf-8")
        argv = ["--packs", str(self.packs), "--recipe", str(recipe_path), "--fixes", str(self.fixes), "--out", str(self.out),
                "--palette", str(palette_path)]
        errors = io.StringIO()
        with contextlib.redirect_stderr(errors), contextlib.redirect_stdout(io.StringIO()):
            code = terrain.main(argv)
        return code, errors.getvalue()

    def test_a_malformed_recipe_is_refused_naming_its_section_and_key_and_writes_nothing(self):
        def set_(index, **changes):
            return lambda r: r["sets"][index].update(changes)

        def tile_of(index, key, value):
            return lambda r: r["sets"][index]["tiles"].update({key: value})

        def to(section, **changes):
            return lambda r: r[section].update(changes)

        cases = [
            ("mask key text", tile_of(0, "x", [1, 0]), r'sand tiles: "x"'),
            ("mask key 16", tile_of(0, "16", [1, 0]), r'sand tiles: "16"'),
            ("mask key -1", tile_of(0, "-1", [1, 0]), r'sand tiles: "-1"'),
            ("mask key 1.5", tile_of(0, "1.5", [1, 0]), r'sand tiles: "1.5"'),
            ("tiles a list", set_(0, tiles=[]), r'sand: "tiles"'),
            ("tile spec short", tile_of(0, "3", [1]), r'sand mask 3: a tile is'),
            ("tile spec text", tile_of(0, "3", ["a", "b"]), r'sand mask 3: a tile is'),
            ("tile spec number", tile_of(0, "3", 5), r'sand mask 3: a tile is'),
            ("tile spec table", tile_of(0, "3", {"a": 1}), r'sand mask 3: a tile is'),
            ("tile spec bool", tile_of(0, "3", [True, 0]), r'sand mask 3: a tile is'),
            ("tile spec colour", tile_of(0, "3", "oops"), r"sand.*'oops'"),
            ("quadrants a list", set_(0, quadrants=[]), r'sand: "quadrants"'),
            ("quadrants mask 99", set_(0, quadrants={"99": [15, 15, 1, 1]}), r'sand quadrants: "99"'),
            ("quadrants parts three", set_(0, quadrants={"0": [15, 15, 1]}), r'sand quadrants: "0" needs four'),
            ("quadrants parts a number", set_(0, quadrants={"0": 5}), r'sand quadrants: "0" needs four'),
            ("quadrants part text", set_(0, quadrants={"0": [15, "x", 1, 1]}), r'sand quadrants: "x"'),
            ("quadrants part 16", set_(0, quadrants={"0": [15, 16, 1, 1]}), r'sand quadrants: "16"'),
            ("map a list", set_(0, map=[]), r'sand: "map"'),
            ("map colour", set_(0, map={"#10c010": 5}), r"sand"),
            ("erase a number", set_(0, erase=5), r'sand: "erase"'),
            ("erase colour", set_(0, erase=["red"]), r"sand.*'red'"),
            ("variants text", set_(0, variants="15"), r'sand: "variants"'),
            ("variant none", set_(0, variants=[None]), r"sand: variant None"),
            ("stamp short", set_(1, stamp=[1]), r"brush stamp: a tile is"),
            ("stamp number", set_(1, stamp=5), r"brush stamp: a tile is"),
            ("a set not a table", lambda r: r["sets"].append(5), r"a set has no"),
            ("sets a table", lambda r: r.update(sets={}), r'the recipe: "sets"'),
            ("shore text (set)", set_(1, shore="x"), r'brush shore: "shore"'),
            ("shore text (plain)", lambda r: r["plain"].update(shore="x"), r'plain shore: "shore"'),
            ("plain a list", lambda r: r.update(plain=[]), r'the recipe: "plain"'),
            ("plain rows empty", lambda r: r["plain"].update(rows=[]), r'plain: "rows"'),
            ("plain rows text", lambda r: r["plain"].update(rows="x"), r'plain: "rows"'),
            ("plain row not a table", lambda r: r["plain"].update(rows=[5]), r"plain row 0"),
            ("plain tile short", lambda r: r["plain"]["rows"][0].update(tile=[1]), r"plain rock: a tile is"),
            ("plain tile text", lambda r: r["plain"]["rows"][0].update(tile="x"), r"plain rock.*'x'"),
            ("plain map a list", lambda r: r["plain"]["rows"][0].update(map=[]), r'plain rock: "map"'),
            ("water a number", lambda r: r.update(water=5), r'the recipe: "water"'),
            ("water rect short", to("water", rect=[1, 2]), r'water: "rect"'),
            ("water rect text", to("water", rect="x"), r'water: "rect"'),
            ("water rect non-number", to("water", rect=[0, 0, "a", 1]), r'water: "rect"'),
            ("water map a list", to("water", map=[]), r'water: "map"'),
            ("ramps text", to("water", ramps="x"), r"water ramps"),
            ("ramps rows of numbers", to("water", ramps=[5]), r"water ramps"),
            ("ramps empty row", to("water", ramps=[["#306082"], []]), r"water ramps"),
            ("ramps colour", to("water", ramps=[["red"]]), r"water ramps.*'red'"),
            ("foam step text", to("foam", step="a"), r'foam: "step"'),
            ("foam step 0", to("foam", step=0), r'foam: "step"'),
            ("foam frames 0", to("foam", frames=0), r'foam: "frames"'),
            ("foam frames text", to("foam", frames="x"), r'foam: "frames"'),
            ("foam frames float", to("foam", frames=1.5), r'foam: "frames"'),
            ("foam origin short", to("foam", origin=[1]), r'foam: "origin"'),
            ("foam land_rows text", to("foam", land_rows="x"), r'foam: "land_rows"'),
            ("foam fade text", to("foam", fade="x"), r'foam: "fade"'),
            ("foam fade from", to("foam", fade={"from": "a", "colour": "#ffffff"}), r'foam fade: "from"'),
            ("foam no pixel at all", to("foam", white="#123456"), r"foam: no pixel at all"),
            ("foam a list", lambda r: r.update(foam=[]), r'the recipe: "foam"'),
            ("shade alpha text", to("shade", alpha="x"), r'shade: "alpha"'),
            ("shade alpha 0", to("shade", alpha=0), r'shade: "alpha"'),
            ("shade alpha 256", to("shade", alpha=256), r'shade: "alpha"'),
            ("shade edge text", to("shade", edge="x"), r'shade: "edge"'),
            ("shade edge item", to("shade", edge=["a"]), r'shade: "edge"'),
            ("shade edge 0", to("shade", edge=[0]), r'shade: "edge"'),
            ("shade a list", lambda r: r.update(shade=[]), r'the recipe: "shade"'),
            ("copies a table", lambda r: r.update(copies={}), r'the recipe: "copies"'),
            ("a copy not a table", lambda r: r.update(copies=[5]), r"a copy has no"),
        ]
        for label, change, message in cases:
            recipe = self.recipe()
            change(recipe)
            code, printed = self.run_main(recipe)
            self.assertEqual(code, 1, f"{label}: {printed}")
            self.assertRegex(printed, r"^terrain: ", label)
            self.assertRegex(printed, message, label)
            self.assertFalse(self.out.exists(), f"{label}: nothing is written")

    def test_a_missing_palette_and_corrupt_pngs_are_refused_with_their_path(self):
        code, printed = self.run_main(self.recipe(), palette=self.root / "no_palette.png")
        self.assertEqual((code, self.out.exists()), (1, False))
        self.assertIn("no_palette.png", printed)
        for relative, name in (("packs/oga/world.png", "world.png"), ("packs/oga/waves.png", "waves.png"), ("fixes/sand.png", "sand.png"),
                               ("fixes/shade_spots.png", "shade_spots.png"), ("fixes/pool.png", "pool.png")):
            self.setUp()
            recipe = self.recipe()
            recipe["shade"]["spots"] = "shade_spots.png" if name == "shade_spots.png" else "spots.png"
            code, printed = self.run_main(recipe, files={relative: b"not a png at all"})
            self.assertEqual(code, 1, name)
            self.assertIn(name, printed)
            self.assertFalse(self.out.exists(), name)

    def test_a_colour_outside_the_palette_is_refused_by_name(self):
        recipe = self.recipe()
        recipe["water"]["map"] = {png.colour_hex(BLUE): "#123456"}
        with self.assertRaisesRegex(terrain.TerrainError, r"sea/water\.png.*#123456"):
            self.build(recipe)
        self.assertFalse(self.out.exists(), "nothing at all is written when a sheet is refused")

    def test_a_source_outside_the_packs_root_is_refused(self):
        recipe = self.recipe()
        recipe["sources"]["world"] = "../fixes/pool.png"
        with self.assertRaisesRegex(terrain.TerrainError, "outside the packs root"):
            self.build(recipe)

    def test_it_never_writes_inside_a_download_folder(self):
        with self.assertRaisesRegex(terrain.TerrainError, "download folder"):
            self.build(out=self.packs / "oga" / "made")
        self.assertFalse((self.packs / "oga" / "made").exists())

    def test_main_returns_0_and_writes_the_sheets(self):
        code, printed = self.run_main(self.recipe())
        self.assertEqual((code, printed), (0, ""))
        self.assertEqual(len(list(self.out.rglob("*.png"))), 8)
        self.assertEqual(png.read_png(self.out / "terrain" / "pool.png"), filled(ROCK))

    def test_main_prints_the_error_after_terrain_on_stderr_and_returns_1(self):
        recipe = self.recipe()
        recipe["sets"][0]["source"] = "nowhere"
        code, printed = self.run_main(recipe)
        self.assertEqual((code, printed), (1, "terrain: sand: no source named 'nowhere'\n"))
        self.assertFalse(self.out.exists())

    def test_a_set_whose_full_tile_is_a_colour_fill_has_it_on_every_pixel(self):
        recipe = self.recipe()
        recipe["sets"][0]["tiles"]["15"] = png.colour_hex(GRASS)
        self.build(recipe)
        sand = png.read_png(self.out / "terrain" / "sand.png")
        self.assertEqual(terrain.sheet_tile(sand, 15), filled(SAND))
        self.assertEqual(sand.crop(0, 64, 16, 16), filled(SAND), "the variants start from the filled tile")

    def test_every_refusal_of_the_builder_names_what_is_wrong(self):
        def sand(**changes):
            return lambda r: r["sets"][0].update(changes)

        def edit(section, **changes):
            return lambda r: r[section].update(changes)

        def tile(mask, value):
            return lambda r: r["sets"][0]["tiles"].update({mask: value})

        cases = [
            ("set id", sand(id="Bad Id"), r"set id 'Bad Id' is not lower-case"),
            ("set without id", lambda r: r["sets"][0].pop("id"), r'a set has no "id"'),
            ("set without tiles", lambda r: r["sets"][0].pop("tiles"), r'sand has no "tiles"'),
            ("set without source", lambda r: r["sets"][0].pop("source"), r'sand has no "source"'),
            ("no sources", lambda r: r.pop("sources"), r'the recipe has no "sources"'),
            ("unknown source", sand(source="nowhere"), r"sand: no source named 'nowhere'"),
            ("pack file missing", lambda r: r["sources"].update(world="oga/none.png"), r"sand: .*none\.png not found"),
            ("tile off the sheet", tile("3", [9, 9]), r"sand mask 3: tile \(9, 9\) is off the 64x32 sheet"),
            ("colour not named", sand(map={}), r"sand mask 1: the recipe does not name #10c010"),
            ("five variants", sand(variants=["15"] * 5), r"sand: 5 variants, and row 4 holds 4"),
            ("variant not a mask", sand(variants=["x"]), r"sand: variant 'x' is not a mask of the set"),
            ("no tile for a mask", lambda r: r["sets"][0]["tiles"].pop("14"), r"sand: no tile for mask 14"),
            ("plain shape not built", lambda r: r["plain"].update(shape="ghost"), r"plain: its shape set 'ghost' is not built"),
            ("foam shape not built", edit("foam", shape="ghost"), r"foam: its shape set 'ghost' is not built"),
            ("shade shape not built", edit("shade", shape="ghost"), r"shade: its shape set 'ghost' is not built"),
            ("shore shape not built", lambda r: r["sets"][1].update(shore={"shape": "ghost"}), r"brush shore: its shape set 'ghost' is not built"),
            ("water rect off the sheet", edit("water", rect=[32, 0, 64, 32]), r"water: the rect \[32, 0, 64, 32\] is off the 64x32 sheet"),
            ("foam frame off the sheet", edit("foam", frames=50), r"foam: frame \d+ is off the 35x32 sheet"),
            ("spots missing", lambda r: r["shade"].update(spots="gone.png"), r"gone\.png: no such hand-drawn source"),
            ("copy missing", lambda r: r["copies"][0].update({"from": "gone.png"}), r"gone\.png: no such hand-drawn source"),
        ]
        for label, change, message in cases:
            recipe = self.recipe()
            change(recipe)
            with self.assertRaisesRegex(terrain.TerrainError, message, msg=label):
                self.build(recipe)
        self.assertFalse(self.out.exists(), "nothing is written")
        png.write_png(self.fixes / "sand.png", png.blank(8, 8))
        with self.assertRaisesRegex(terrain.TerrainError, r"sand\.png: the fix overlay is 8x8, not 64x80"):
            self.build()

    def test_a_recipe_file_that_cannot_be_read_is_refused_by_path(self):
        missing = self.root / "none.json"
        with self.assertRaisesRegex(terrain.TerrainError, r"none\.json"):
            terrain.load_recipe(missing)
        broken = self.root / "broken.json"
        broken.write_text("{not json", encoding="utf-8")
        with self.assertRaisesRegex(terrain.TerrainError, r"broken\.json"):
            terrain.load_recipe(broken)
        for text in ("[]", "{}", '{"sources": []}'):
            broken.write_text(text, encoding="utf-8")
            with self.assertRaisesRegex(terrain.TerrainError, r'broken\.json has no "sources" table'):
                terrain.load_recipe(broken)

    def test_the_tracked_recipe_names_only_sources_under_the_download_folders(self):
        recipe = terrain.load_recipe(terrain.DEFAULT_RECIPE)
        self.assertEqual(sorted(recipe["sources"]), ["eldiran", "overworld", "scallywag"])
        for relative in recipe["sources"].values():
            self.assertIn(relative.split("/")[0], terrain.DOWNLOAD_FOLDERS)
        self.assertEqual([entry["id"] for entry in recipe["sets"]], ["sand", "dune", "brush"])
        self.assertEqual([row["id"] for row in recipe["plain"]["rows"]],
                         ["rock", "shingle", "cliff", "hammock", "casuarina", "reef_flat", "coral", "mangrove", "wreck_interior"])
        self.assertEqual(recipe["shade"]["shape"], "sand")

    def test_the_tracked_brush_has_four_hand_drawn_variants_not_mirrors(self):
        brush = terrain.load_recipe(terrain.DEFAULT_RECIPE)["sets"][2]
        self.assertEqual(brush["variants"], ["0", "0", "0", "0"])
        overlay = png.read_png(terrain.DEFAULT_FIXES / "brush.png")
        for column in (1, 2, 3):
            cell = overlay.crop(column * 16, terrain.VARIANT_ROW * 16, 16, 16)
            self.assertGreater(sum(1 for alpha in cell.pixels[3::4] if alpha), 10, f"variant {column} is redrawn by hand")
        self.assertTrue(overlay.crop(0, 0, 64, 64).is_empty(), "the masks keep the pack's bush")

    def test_no_tracked_brush_pick_has_a_hole_inside_its_outline(self):
        """art-terrain-polish TR14: a lone bush is solid, so no sand shows through inside it."""
        brush = png.read_png(terrain.DEFAULT_OUT / "terrain" / "brush.png")
        for column in range(terrain.SET_COLUMNS):
            cell = brush.crop(column * 16, terrain.VARIANT_ROW * 16, 16, 16)
            self.assertEqual(enclosed_clear(cell), [], f"brush pick {column} has no hole inside its outline")

    def test_a_hole_is_a_clear_pixel_closed_in_by_drawn_ones(self):
        ring = filled(BLACK, rows=range(4, 9), columns=range(4, 9))
        ring.set(6, 6, (0, 0, 0, 0))
        self.assertEqual(enclosed_clear(ring), [(6, 6)])
        notch = filled(BLACK, rows=range(4, 9), columns=range(4, 9))
        notch.set(6, 4, (0, 0, 0, 0))
        self.assertEqual(enclosed_clear(notch), [], "a bite open to the outside is not a hole")

    def test_the_tracked_rock_has_the_pack_variant_and_two_hand_ones_that_keep_its_border(self):
        rock = terrain.load_recipe(terrain.DEFAULT_RECIPE)["plain"]["rows"][0]
        self.assertEqual((rock["tile"], rock["variants"]), ([12, 13], [[12, 14], "15", "15"]))
        overlay = png.read_png(terrain.DEFAULT_FIXES / "plain.png")
        for column in (17, 18):
            cell = overlay.crop(column * 16, 0, 16, 16)
            self.assertGreater(sum(1 for alpha in cell.pixels[3::4] if alpha), 0, f"column {column} has hand pixels")
            border = [(x, y) for y in range(16) for x in range(16) if x in (0, 15) or y in (0, 15)]
            self.assertEqual([at for at in border if cell.alpha(*at)], [], f"column {column} keeps the full tile's border, so any two join")


    def test_the_tracked_brush_shore_fits_the_small_pick_or_the_tuft_whole(self):
        brush = terrain.load_recipe(terrain.DEFAULT_RECIPE)["sets"][2]
        self.assertEqual({key: value for key, value in brush["shore"]["fit"].items() if key != "variants"}, {"pick": 1, "fallback_inset": 0, "tuft": "shore_tuft.png"}, "the variants are art-terrain-polish C10b's, below")
        tuft = png.read_png(terrain.DEFAULT_FIXES / "shore_tuft.png")
        rows, columns = opaque_rows(tuft), opaque_columns(tuft)
        self.assertLessEqual((len(columns), len(rows)), (8, 7), "an 8x7 sprig at most")
        self.assertEqual(tuft.colours(), {png.parse_colour(c) for c in ("#4b692f", "#37946e", "#6abe30", "#99e550", "#323c39")}, "the brush greens and its outline")
        made = terrain.DEFAULT_OUT / "terrain"
        pick = drawn(png.read_png(made / "brush.png").crop(16, 64, 16, 16))
        shore = png.read_png(made / "brush_shore.png")

        def moved(tile, piece):
            if len(tile) != len(piece):
                return False
            dx = min(x for x, _y in tile) - min(x for x, _y in piece)
            dy = min(y for _x, y in tile) - min(y for _x, y in piece)
            return all(tile.get((x + dx, y + dy)) == colour for (x, y), colour in piece.items())

        for s in range(1, 15):
            tile = drawn(shore.crop(s * 16, 0, 16, 16))
            self.assertTrue(moved(tile, pick) or moved(tile, drawn(tuft)), f"sand mask {s}: the pick or the tuft, whole")

    def test_the_tracked_overlays_hold_only_hand_pixels(self):
        recipe = terrain.load_recipe(terrain.DEFAULT_RECIPE)
        for entry in recipe["sets"][:2]:
            overlay = png.read_png(terrain.DEFAULT_FIXES / f"{entry['id']}.png")
            hand = terrain.hand_cells(entry)
            for column in range(terrain.SET_COLUMNS):
                cell = overlay.crop(column * 16, terrain.VARIANT_ROW * 16, 16, 16)
                opaque = sum(1 for alpha in cell.pixels[3::4] if alpha)
                self.assertLess(opaque, 40, f"{entry['id']} variant {column} is mask 15 plus a few hand pixels")
            self.assertEqual(hand, {(0, 0)} if entry["id"] == "dune" else set(), entry["id"])
            self.assertEqual(sum(1 for alpha in overlay.crop(0, 0, 16, 16).pixels[3::4] if alpha), 256 if hand else 0)


class StillFoamTests(unittest.TestCase):
    """art-terrain-polish D2: the still piece of a lagoon's rim."""

    def shapes(self):
        sets = png.blank(64, 80)
        sets.paste(filled(SAND, rows=range(0, 12)), 3 * 16, 0)  # mask 3: land north, sea south
        sets.paste(filled(SAND), 3 * 16, 3 * 16)  # mask 15: whole
        return sets

    def test_the_still_piece_is_one_line_on_the_first_water_step_alike_in_every_frame(self):
        sheet = terrain.build_foam_still({"colour": "#8fe0f0"}, self.shapes(), 8)
        self.assertEqual((sheet.width, sheet.height), (8 * 16, 16 * 16))
        piece = sheet.crop(0, 3 * 16, 16, 16)
        self.assertEqual(opaque_rows(piece), [12], "one line, on the first water row")
        self.assertEqual(piece.colours(), {png.parse_colour("#8fe0f0")}, "no white")
        for frame in range(1, 8):
            self.assertEqual(sheet.crop(frame * 16, 3 * 16, 16, 16).pixels, piece.pixels, f"frame {frame} is frame 0")
        self.assertTrue(sheet.crop(0, 15 * 16, 8 * 16, 16).is_empty(), "a whole tile has no shore")

    def test_still_is_a_table_with_a_colour(self):
        with self.assertRaisesRegex(terrain.TerrainError, r'"still" is a table'):
            terrain.build_foam_still("#8fe0f0", self.shapes(), 8)
        with self.assertRaisesRegex(terrain.TerrainError, r"colour"):
            terrain.build_foam_still({}, self.shapes(), 8)

    def test_the_tracked_still_foam_is_the_foam_sheets_size_and_alike_in_every_frame(self):
        made = terrain.DEFAULT_OUT / "sea"
        still = png.read_png(made / "foam_still.png")
        foam = png.read_png(made / "foam.png")
        self.assertEqual((still.width, still.height), (foam.width, foam.height))
        for mask in range(16):
            first = still.crop(0, mask * 16, 16, 16)
            for frame in range(1, 8):
                self.assertEqual(still.crop(frame * 16, mask * 16, 16, 16).pixels, first.pixels, f"mask {mask} frame {frame}")
        self.assertNotIn((0xFF, 0xFF, 0xFF), still.colours(), "no white")


class SandTextureTests(unittest.TestCase):
    """art-terrain-polish D4 (TR12): a beach with no grid."""

    def test_the_tracked_sand_fill_is_one_tone_and_its_picks_are_distinct_and_not_mirrors(self):
        made = png.read_png(terrain.DEFAULT_OUT / "terrain" / "sand.png")
        full = made.crop(3 * 16, 3 * 16, 16, 16)
        self.assertEqual(len(full.colours()), 1, "the whole tile is one tone, no stripes")
        picks = [made.crop(column * 16, terrain.VARIANT_ROW * 16, 16, 16) for column in range(terrain.SET_COLUMNS)]
        self.assertEqual(picks[0].pixels, full.pixels, "pick 0 is the clean tile")
        seen = []
        for column, pick in enumerate(picks):
            self.assertNotIn(pick.pixels, seen, f"pick {column} repeats another")
            self.assertNotIn(mirrored(pick).pixels, seen, f"pick {column} mirrors another")
            seen.append(pick.pixels)
        for column in range(1, terrain.SET_COLUMNS):
            marks = [(x, y) for y in range(16) for x in range(16) if picks[column].get(x, y) != full.get(x, y)]
            self.assertTrue(0 < len(marks) <= 16, f"pick {column} has a few sparse marks, not a field ({len(marks)})")

    def test_the_sand_picks_marks_are_off_the_old_three_spot_lattice(self):
        made = png.read_png(terrain.DEFAULT_OUT / "terrain" / "sand.png")
        full = made.crop(3 * 16, 3 * 16, 16, 16)
        marked = {}
        for column in range(1, terrain.SET_COLUMNS):
            pick = made.crop(column * 16, terrain.VARIANT_ROW * 16, 16, 16)
            for at in ((x, y) for y in range(16) for x in range(16) if pick.get(x, y) != full.get(x, y)):
                self.assertNotIn(at, marked, f"pick {column} marks {at}, as pick {marked.get(at)} does: a lattice")
                marked[at] = column


class CanopyTests(unittest.TestCase):
    """art-terrain-polish D5 (TR10): no ground inside a thicket, and whole-bush picks."""

    def stamp(self):
        disc = png.blank(16, 16)
        for y in range(16):
            for x in range(16):
                if (x - 7.5) ** 2 + (y - 7.5) ** 2 <= 36:
                    disc.set(x, y, SAND + (255,))
        return disc

    def gaps(self, tile, corners):
        band = dict(terrain.CANOPY_GAPS)[corners]
        return [(x, y) for x, y in band if not tile.alpha(x, y)]

    def test_the_canopy_fills_the_gaps_between_lobes_on_an_edge_whose_corners_are_land(self):
        bare = terrain.stamped(self.stamp(), 15)
        self.assertTrue(self.gaps(bare, terrain.NW | terrain.NE), "a round stamp leaves ground between its lobes")
        full = terrain.stamped(self.stamp(), 15, DEEP)
        for corners, _band in terrain.CANOPY_GAPS:
            self.assertEqual(self.gaps(full, corners), [], f"edge {corners} is filled")
        self.assertEqual({full.get(x, y)[:3] for x, y in self.gaps(bare, terrain.NW | terrain.NE)}, {DEEP}, "in the canopy colour")

    def test_an_edge_with_one_land_corner_keeps_its_ground(self):
        self.assertEqual(terrain.stamped(self.stamp(), terrain.NW, DEEP).pixels, terrain.stamped(self.stamp(), terrain.NW).pixels)

    def test_a_fitted_shore_tile_fills_the_same_gaps_as_its_inland_tile(self):
        edge = filled(SAND)  # a shore tile whose sand covers the gaps (the fit never cuts them)
        field = terrain.shore_field(filled(SAND, rows=range(0, 15)))
        centre = png.blank(16, 16)
        inland = terrain.stamped(self.stamp(), 15, DEEP)
        tile = terrain.fit_tile(self.stamp(), 15, edge, field, centre, DEEP)
        for corners, _band in terrain.CANOPY_GAPS:
            for x, y in self.gaps(terrain.stamped(self.stamp(), 15), corners):
                self.assertEqual(tile.get(x, y), inland.get(x, y), f"({x}, {y}) as inland")
        self.assertEqual(terrain.fit_tile(self.stamp(), 15, edge, field, centre).pixels, terrain.fit_tile(self.stamp(), 15, edge, field, centre, None).pixels)

    def test_a_full_variant_row_makes_the_sheet_96_high(self):
        tiles = {mask: filled(SAND) for mask in range(16)}
        sheet = terrain.set_sheet(tiles, [filled(SAND)], [filled(ROCK), filled(DEEP)])
        self.assertEqual((sheet.width, sheet.height), (64, 96))
        self.assertEqual(sheet.crop(16, 80, 16, 16).colours(), {DEEP})
        self.assertEqual((terrain.set_sheet(tiles, [filled(SAND)]).height), 80, "no full variants, no row 5")
        with self.assertRaisesRegex(terrain.TerrainError, "full variants"):
            terrain.set_sheet(tiles, [], [filled(SAND)] * 5)

    def test_the_tracked_brush_has_a_canopy_and_three_full_picks_that_keep_the_corner_quarters(self):
        brush = terrain.load_recipe(terrain.DEFAULT_RECIPE)["sets"][2]
        self.assertEqual(brush["canopy"], "#4b692f")
        made = png.read_png(terrain.DEFAULT_OUT / "terrain" / "brush.png")
        self.assertEqual((made.width, made.height), (64, 96))
        full = terrain.sheet_tile(made, 15)
        self.assertEqual(sum(1 for alpha in full.pixels[3::4] if not alpha), 0, "a whole scrub cell shows no ground")
        picks = [made.crop(column * 16, 80, 16, 16) for column in range(4)]
        self.assertEqual(picks[0].pixels, full.pixels, "pick 0 is the full tile")
        seen = []
        for column, pick in enumerate(picks):
            self.assertNotIn(pick.pixels, seen, f"pick {column} repeats another")
            self.assertNotIn(mirrored(pick).pixels, seen, f"pick {column} mirrors another")
            seen.append(pick.pixels)
            changed = [(x, y) for y in range(16) for x in range(16) if pick.get(x, y) != full.get(x, y)]
            self.assertTrue(all(3 <= x <= 12 and 3 <= y <= 12 for x, y in changed), f"pick {column} changes only its centre lobe")
            self.assertEqual(column > 0, bool(changed), f"pick {column}")
            self.assertEqual(enclosed_clear(pick), [], f"pick {column} has no hole")


class ShoreVariantTests(unittest.TestCase):
    """art-terrain-polish D5: two or three whole shore bushes, picked by hash."""

    def test_the_tracked_brush_shore_has_three_whole_bushes_each_placed_on_the_sand(self):
        brush = terrain.load_recipe(terrain.DEFAULT_RECIPE)["sets"][2]
        names = brush["shore"]["fit"]["variants"]
        self.assertEqual(names, ["shore_bush_a.png", "shore_bush_b.png"])
        made = terrain.DEFAULT_OUT / "terrain"
        shore = png.read_png(made / "brush_shore.png")
        self.assertEqual((shore.width, shore.height), (256, 3 * 256))
        tuft = drawn(png.read_png(terrain.DEFAULT_FIXES / "shore_tuft.png"))
        pieces = [drawn(png.read_png(made / "brush.png").crop(16, 64, 16, 16))]
        for name in names:
            bush = png.read_png(terrain.DEFAULT_FIXES / name)
            rows, columns = opaque_rows(bush), opaque_columns(bush)
            self.assertLessEqual((len(columns), len(rows)), (11, 10), f"{name}: at most 11x10")
            self.assertTrue(bush.colours() <= {png.parse_colour(c) for c in ("#4b692f", "#37946e", "#6abe30", "#99e550", "#323c39", "#76428a", "#45283c")}, f"{name}: brush greens, its outline and berries")
            pieces.append(drawn(bush))

        def moved(tile, piece):
            if len(tile) != len(piece):
                return False
            dx = min(x for x, _y in tile) - min(x for x, _y in piece)
            dy = min(y for _x, y in tile) - min(y for _x, y in piece)
            return all(tile.get((x + dx, y + dy)) == colour for (x, y), colour in piece.items())

        for v, piece in enumerate(pieces):
            for s in range(1, 15):
                tile = drawn(shore.crop(s * 16, v * 256, 16, 16))
                self.assertTrue(moved(tile, piece) or moved(tile, tuft), f"block {v}, sand mask {s}: its bush or the tuft, whole")


class RockEdgeTests(unittest.TestCase):
    """art-terrain-polish D6 (TR9): a dark rim, a lit north lip, a low face on the water, pebbles."""

    LIP = (0x9B, 0xAD, 0xB7)
    FACE = [(0x69, 0x6A, 0x6A), (0x59, 0x56, 0x52)]

    def test_a_lip_lights_the_row_under_a_north_facing_rim_only(self):
        shape = filled(SAND, rows=range(4, 16), columns=range(0, 12))  # north edge on row 4, east edge at x 11
        tile = terrain.rimmed(terrain.masked(filled(ROCK), shape), shape, BLACK)
        lit = terrain.lipped(tile, BLACK, self.LIP)
        self.assertEqual({lit.get(x, 5)[:3] for x in range(1, 11)}, {self.LIP}, "the row under the north rim")
        self.assertEqual({lit.get(x, 4)[:3] for x in range(0, 12)}, {BLACK}, "the rim stays")
        self.assertEqual(lit.get(10, 9)[:3], ROCK, "no lip on the east edge")
        self.assertEqual(terrain.lipped(terrain.rimmed(terrain.masked(filled(ROCK), filled(SAND, rows=range(0, 12))), filled(SAND, rows=range(0, 12)), BLACK), BLACK, self.LIP).colours(), {ROCK, BLACK}, "a south edge gets none")

    def test_a_face_shows_above_a_south_facing_rim_on_the_water_only(self):
        sand = filled(SAND, rows=range(0, 12))  # the sea from row 12
        tile = terrain.rimmed(terrain.masked(filled(ROCK), sand), sand, BLACK)
        faced = terrain.faced(tile, sand, BLACK, self.FACE)
        self.assertEqual(faced.get(5, 11)[:3], BLACK, "the rim stays at the water")
        self.assertEqual(faced.get(5, 10)[:3], self.FACE[1], "the low face row just above it")
        self.assertEqual(faced.get(5, 9)[:3], self.FACE[0])
        self.assertEqual(faced.get(5, 8)[:3], ROCK, "two rows, no more")
        seam = terrain.rimmed(terrain.masked(filled(ROCK), sand), sand, BLACK)
        land = filled(SAND)  # the same edge against land, not water
        self.assertEqual(terrain.faced(seam, land, BLACK, self.FACE).pixels, seam.pixels, "no face on a land seam")

    def test_the_tracked_rock_has_a_dark_rim_a_lit_lip_and_a_low_face_on_the_water(self):
        rock = terrain.load_recipe(terrain.DEFAULT_RECIPE)["plain"]["rows"][0]
        self.assertEqual((rock["rim"], rock["lip"], rock["face"]), ("#323c39", "#9badb7", ["#696a6a", "#595652"]))
        made = terrain.DEFAULT_OUT / "terrain"
        plain = png.read_png(made / "plain.png")
        north = plain.crop(12 * 16, 0, 16, 16)  # mask 12: rock to the south, a north-facing edge
        rows = opaque_rows(north)
        self.assertEqual({north.get(x, rows[0])[:3] for x in range(16) if north.alpha(x, rows[0])}, {png.parse_colour("#323c39")}, "the rim is #323c39")
        self.assertIn(png.parse_colour("#9badb7"), {north.get(x, rows[0] + 1)[:3] for x in range(16)}, "a lit lip under it")
        shore = png.read_png(made / "plain_shore.png")
        faced = shore.crop(3 * 16, 3 * 16, 16, 16)  # sand mask 3 (the sea to the south), own mask 3
        bottom = opaque_rows(faced)[-1]
        self.assertEqual(faced.get(8, bottom - 1)[:3], png.parse_colour("#595652"), "the face over the water")
        cliff = terrain.load_recipe(terrain.DEFAULT_RECIPE)["plain"]["rows"][2]
        self.assertNotIn("face", cliff, "the cliff keeps its own deeper drop")

    def test_the_tracked_pebbles_sit_in_the_sand_strip_of_each_straight_seam(self):
        pebbles = png.read_png(terrain.DEFAULT_OUT / "decals" / "pebbles.png")
        self.assertEqual((pebbles.width, pebbles.height), (64, 16))
        strips = {0: (range(0, 4), range(0, 16)), 1: (range(12, 16), range(0, 16)), 2: (range(0, 16), range(0, 4)), 3: (range(0, 16), range(12, 16))}
        for column, (xs, ys) in strips.items():
            tile = pebbles.crop(column * 16, 0, 16, 16)
            drawn_at = [(x, y) for y in range(16) for x in range(16) if tile.alpha(x, y)]
            self.assertTrue(drawn_at, f"pebble tile {column} is drawn")
            self.assertTrue(all(x in xs and y in ys for x, y in drawn_at), f"pebble tile {column} stays in its strip")
            self.assertLessEqual((len({x for x, _ in drawn_at}), len({y for _, y in drawn_at})) if column < 2 else (len({y for _, y in drawn_at}), len({x for x, _ in drawn_at})), (6, 8), f"pebble tile {column}: at most 8x6")


if __name__ == "__main__":
    unittest.main()

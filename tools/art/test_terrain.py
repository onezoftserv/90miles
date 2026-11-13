"""Tests for terrain.py, the terrain art builder of design.md D11 to D13, T13, T14 and K35 to K39,
on a fixture pack written to a scratch folder: key out and recolour, compose the hand tiles from
quadrants, stamp the brush set, lay the sheets out, mask the plain tiles, wrap the foam round the
sand edge and cut the water texture.

Run: python -I -m unittest discover -s tools/art -p "test_*.py"
"""
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

    def test_the_feather_thins_the_foam_from_that_distance_on(self):
        frame = self.frame()
        for y in range(7, 10):
            for x in range(16):
                frame.set(x, y, WHITE + (255,))
        field = terrain.shore_field(filled(SAND, rows=range(0, 12)))
        whole = terrain.foam_piece(field, frame, 6, WHITE, WHITE)
        thin = terrain.foam_piece(field, frame, 6, WHITE, WHITE, feather=4)
        self.assertEqual(sum(1 for x in range(16) if whole.alpha(x, 15)), 16)
        self.assertEqual(sum(1 for x in range(16) if thin.alpha(x, 15)), 8)
        self.assertEqual(sum(1 for x in range(16) if thin.alpha(x, 14)), 16)

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
            "shade": {"shape": "sand", "colour": "#000000", "alpha": 60, "edge": [20, 40], "spots": "spots.png"},
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
            "decals/shade.png": (64, 80), "sea/foam.png": (32, 256), "sea/water.png": (32, 32), "sea/water_ramps.png": (1, 2),
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

    def test_a_fix_overlay_is_blended_last_and_shapes_the_foam(self):
        fix = png.blank(64, 80)
        for x in range(16):
            fix.set(3 * 16 + x, 11, (0xFF, 0x00, 0xFF, 255))
        png.write_png(self.fixes / "sand.png", fix)
        self.build()
        self.assertEqual(opaque_rows(terrain.sheet_tile(png.read_png(self.out / "terrain" / "sand.png"), 3))[-1], 10)
        self.assertEqual(opaque_rows(png.read_png(self.out / "sea" / "foam.png").crop(0, 48, 16, 16)), [11])

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

    def test_the_shade_set_follows_the_sand_shape_and_its_last_row_holds_the_spots(self):
        self.build()
        shade = png.read_png(self.out / "decals" / "shade.png")
        edge = terrain.sheet_tile(shade, 3)
        self.assertEqual([edge.get(4, y) for y in (9, 10, 11, 12)], [BLACK + (60,), BLACK + (40,), BLACK + (20,), terrain.CLEAR])
        self.assertEqual(terrain.sheet_tile(shade, 15).get(8, 8), BLACK + (60,))
        self.assertEqual(shade.crop(0, 64, 64, 16), self.spots())

    def test_a_spot_strip_of_another_size_or_colour_is_refused(self):
        with self.assertRaisesRegex(terrain.TerrainError, r"spots\.png.*64x16"):
            self.build(spots=png.blank(32, 16))
        grey = self.spots()
        grey.set(5, 5, ROCK + (30,))
        with self.assertRaisesRegex(terrain.TerrainError, r"decals/shade\.png: a half-transparent pixel"):
            self.build(spots=grey)
        self.assertFalse((self.out / "decals").exists(), "nothing is written when a sheet is refused")

    def test_a_colour_outside_the_palette_is_refused_by_name(self):
        recipe = self.recipe()
        recipe["water"]["map"] = {png.colour_hex(BLUE): "#123456"}
        with self.assertRaisesRegex(terrain.TerrainError, r"sea/water\.png.*#123456"):
            self.build(recipe)

    def test_a_source_outside_the_packs_root_is_refused(self):
        recipe = self.recipe()
        recipe["sources"]["world"] = "../fixes/pool.png"
        with self.assertRaisesRegex(terrain.TerrainError, "outside the packs root"):
            self.build(recipe)

    def test_it_never_writes_inside_a_download_folder(self):
        with self.assertRaisesRegex(terrain.TerrainError, "download folder"):
            self.build(out=self.packs / "oga" / "made")
        self.assertFalse((self.packs / "oga" / "made").exists())

    def test_main_prints_the_error_and_returns_1(self):
        recipe_path = self.root / "recipe.json"
        recipe_path.write_text(json.dumps({"sources": {}, "sets": [{"id": "sand", "source": "nowhere"}]}), encoding="utf-8")
        code = terrain.main(["--packs", str(self.packs), "--recipe", str(recipe_path), "--fixes", str(self.fixes), "--out", str(self.out)])
        self.assertEqual(code, 1)

    def test_the_tracked_recipe_names_only_sources_under_the_download_folders(self):
        recipe = terrain.load_recipe(terrain.DEFAULT_RECIPE)
        self.assertEqual(sorted(recipe["sources"]), ["eldiran", "overworld", "scallywag"])
        for relative in recipe["sources"].values():
            self.assertIn(relative.split("/")[0], terrain.DOWNLOAD_FOLDERS)
        self.assertEqual([entry["id"] for entry in recipe["sets"]], ["sand", "dune", "brush"])
        self.assertEqual(len(recipe["plain"]["rows"]), 9)
        self.assertEqual(recipe["shade"]["shape"], "sand")


if __name__ == "__main__":
    unittest.main()

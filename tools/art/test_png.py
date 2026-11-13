"""Tests for png.py: RGBA round trips and the PNG kinds the packs use."""
import struct
import unittest
import zlib

import png


def _chunk(kind, data):
    return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data) & 0xFFFFFFFF)


def _png(width, height, depth, colour_type, raw, interlace=0, extra=b""):
    header = struct.pack(">IIBBBBB", width, height, depth, colour_type, 0, 0, interlace)
    return png.SIGNATURE + _chunk(b"IHDR", header) + extra + _chunk(b"IDAT", zlib.compress(raw)) + _chunk(b"IEND", b"")


class PngTest(unittest.TestCase):
    def test_an_rgba_image_round_trips(self):
        image = png.blank(5, 3)
        image.set(0, 0, (1, 2, 3, 255))
        image.set(4, 2, (250, 128, 7, 100))
        back = png.decode_png(png.encode_png(image))
        self.assertEqual((back.width, back.height), (5, 3))
        self.assertEqual(back.pixels, image.pixels)

    def test_an_indexed_4_bit_png_with_transparency_reads_as_rgba(self):
        palette = bytes([10, 20, 30, 200, 100, 50])
        trns = bytes([0, 255])
        raw = bytes([0, 0x01, 0x10])  # one row, filter 0: indices 0, 1, 1, 0
        data = _png(4, 1, 4, 3, raw, extra=_chunk(b"PLTE", palette) + _chunk(b"tRNS", trns))
        image = png.decode_png(data)
        self.assertEqual([image.get(x, 0) for x in range(4)], [(10, 20, 30, 0), (200, 100, 50, 255), (200, 100, 50, 255), (10, 20, 30, 0)])

    def test_greyscale_and_16_bit_rgb_read_as_rgba(self):
        grey = png.decode_png(_png(2, 1, 8, 0, bytes([0, 7, 200])))
        self.assertEqual(grey.get(1, 0), (200, 200, 200, 255))
        deep = png.decode_png(_png(1, 1, 16, 2, bytes([0, 0x12, 0x34, 0x56, 0x78, 0x9A, 0xBC])))
        self.assertEqual(deep.get(0, 0), (0x12, 0x56, 0x9A, 255))

    def test_every_filter_type_is_undone(self):
        rows = []
        for kind in range(5):
            rows.append(bytes([kind]) + bytes([kind * 10 + i for i in range(8)]))
        image = png.decode_png(_png(2, 5, 8, 6, b"".join(rows)))
        self.assertEqual(image.get(0, 0), (0, 1, 2, 3))
        self.assertEqual(image.get(1, 1), ((14 + 10) & 0xFF, (15 + 11) & 0xFF, (16 + 12) & 0xFF, (17 + 13) & 0xFF))

    def test_an_interlaced_png_reads_the_same_as_a_plain_one(self):
        width, height = 5, 5
        source = png.blank(width, height)
        for y in range(height):
            for x in range(width):
                source.set(x, y, (x * 40, y * 40, x + y, 255))
        raw = bytearray()
        for x0, y0, dx, dy in png.ADAM7:
            for y in range(y0, height, dy):
                columns = list(range(x0, width, dx))
                if not columns:
                    continue
                raw.append(0)
                for x in columns:
                    raw.extend(source.get(x, y))
        self.assertEqual(png.decode_png(_png(width, height, 8, 6, bytes(raw), interlace=1)), source)

    def test_a_damaged_or_oversized_png_is_refused(self):
        good = bytearray(png.encode_png(png.blank(2, 2)))
        good[30] ^= 0xFF
        with self.assertRaises(png.PngError):
            png.decode_png(bytes(good))
        with self.assertRaises(png.PngError):
            png.decode_png(_png(70000, 70000, 8, 6, b""))
        with self.assertRaises(png.PngError):
            png.decode_png(b"GIF89a")

    def test_keyed_transparency_reads_for_grey_and_rgb(self):
        grey = png.decode_png(_png(2, 1, 8, 0, bytes([0, 7, 200]), extra=_chunk(b"tRNS", bytes([0, 7]))))
        self.assertEqual([grey.alpha(x, 0) for x in range(2)], [0, 255])
        rgb = png.decode_png(_png(2, 1, 8, 2, bytes([0, 1, 2, 3, 4, 5, 6]), extra=_chunk(b"tRNS", bytes([0, 1, 0, 2, 0, 3]))))
        self.assertEqual([rgb.alpha(x, 0) for x in range(2)], [0, 255])

    def test_over_composites_top_over_bottom(self):
        bottom = png.blank(2, 1)
        bottom.set(0, 0, (0, 0, 255, 255))
        bottom.set(1, 0, (0, 0, 255, 255))
        top = png.blank(2, 1)
        top.set(0, 0, (255, 0, 0, 255))
        out = png.over(bottom, top)
        self.assertEqual(out.get(0, 0), (255, 0, 0, 255))
        self.assertEqual(out.get(1, 0), (0, 0, 255, 255))
        self.assertEqual(bottom.get(0, 0), (0, 0, 255, 255), "the inputs are not changed")

    def test_images_equal_whatever_the_rgb_of_transparent_texels(self):
        a = png.blank(1, 1)
        b = png.blank(1, 1)
        b.set(0, 0, (9, 9, 9, 0))
        self.assertEqual(a, b)

    def test_colours_parse_and_print_as_hex(self):
        self.assertEqual(png.parse_colour("#5b6ee1"), (0x5B, 0x6E, 0xE1))
        self.assertEqual(png.colour_hex((0x5B, 0x6E, 0xE1)), "#5b6ee1")


class MalformedPngTest(unittest.TestCase):
    """The packs are untrusted: every malformed file is refused with PngError, never another error."""

    def assertRefused(self, data, words):
        with self.assertRaises(png.PngError) as caught:
            png.decode_png(data)
        self.assertIn(words, str(caught.exception))

    def test_a_header_that_is_not_13_bytes_is_refused(self):
        short = png.SIGNATURE + _chunk(b"IHDR", struct.pack(">IIBBBB", 1, 1, 8, 6, 0, 0)) + _chunk(b"IEND", b"")
        self.assertRefused(short, "IHDR")
        long = png.SIGNATURE + _chunk(b"IHDR", struct.pack(">IIBBBBBB", 1, 1, 8, 6, 0, 0, 0, 0)) + _chunk(b"IEND", b"")
        self.assertRefused(long, "IHDR")

    def test_a_corrupt_image_stream_is_refused(self):
        corrupt = png.SIGNATURE + _chunk(b"IHDR", struct.pack(">IIBBBBB", 2, 2, 8, 6, 0, 0, 0)) + _chunk(b"IDAT", b"\x78\x9c\xff\xff\xff\xff") + _chunk(b"IEND", b"")
        self.assertRefused(corrupt, "image data")

    def test_a_transparency_chunk_that_does_not_fit_the_colour_type_is_refused(self):
        raw_rgb = bytes([0, 1, 2, 3])
        self.assertRefused(_png(1, 1, 8, 2, raw_rgb, extra=_chunk(b"tRNS", b"\x00")), "tRNS")
        self.assertRefused(_png(1, 1, 8, 0, bytes([0, 7]), extra=_chunk(b"tRNS", b"\x00\x07\x00")), "tRNS")
        self.assertRefused(_png(1, 1, 8, 6, bytes([0, 1, 2, 3, 4]), extra=_chunk(b"tRNS", b"\x00\x00")), "tRNS")
        self.assertRefused(_png(1, 1, 8, 4, bytes([0, 1, 2]), extra=_chunk(b"tRNS", b"\x00\x00")), "tRNS")
        indexed = _chunk(b"PLTE", bytes([1, 2, 3])) + _chunk(b"tRNS", bytes([0, 255]))
        self.assertRefused(_png(1, 1, 8, 3, bytes([0, 0]), extra=indexed), "tRNS")

    def test_an_unknown_interlace_compression_or_filter_method_is_refused(self):
        raw = bytes([0, 1, 2, 3, 4])
        for compression, filter_method, interlace in ((0, 0, 7), (1, 0, 0), (0, 1, 0)):
            header = struct.pack(">IIBBBBB", 1, 1, 8, 6, compression, filter_method, interlace)
            data = png.SIGNATURE + _chunk(b"IHDR", header) + _chunk(b"IDAT", zlib.compress(raw)) + _chunk(b"IEND", b"")
            with self.subTest(compression=compression, filter=filter_method, interlace=interlace):
                with self.assertRaises(png.PngError):
                    png.decode_png(data)

    def test_a_depth_the_colour_type_does_not_allow_is_refused(self):
        self.assertRefused(_png(1, 1, 4, 2, bytes([0, 0, 0])), "depth 4")
        palette = _chunk(b"PLTE", bytes([1, 2, 3]))
        self.assertRefused(_png(1, 1, 16, 3, bytes([0, 0, 0]), extra=palette), "depth 16")


if __name__ == "__main__":
    unittest.main()

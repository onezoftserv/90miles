"""Read and write RGBA PNGs with the standard library only (design.md D8).

The packs are untrusted data: the reader checks every chunk's CRC, refuses images over
MAX_PIXELS and inflates with a bounded output size. It reads every colour type and bit depth of
the PNG standard, transparency chunks and Adam7 interlacing, and always returns 8-bit RGBA. Any
input it cannot read (a short header, a method or depth the standard does not allow, a tRNS that
does not fit the colour type, a corrupt image stream) raises PngError, never another error.
"""
import struct
import zlib

SIGNATURE = b"\x89PNG\r\n\x1a\n"
MAX_PIXELS = 4096 * 4096
CHANNELS = {0: 1, 2: 3, 3: 1, 4: 2, 6: 4}
# The bit depths the PNG standard allows for each colour type.
DEPTHS = {0: (1, 2, 4, 8, 16), 2: (8, 16), 3: (1, 2, 4, 8), 4: (8, 16), 6: (8, 16)}
# A tRNS key's length for grey and RGB; indexed images give one alpha per palette entry at most,
# and grey-alpha and RGBA images carry their own alpha, so they take none.
TRNS_BYTES = {0: 2, 2: 6}
ADAM7 = ((0, 0, 8, 8), (4, 0, 8, 8), (0, 4, 4, 8), (2, 0, 4, 4), (0, 2, 2, 4), (1, 0, 2, 2), (0, 1, 1, 2))


class PngError(ValueError):
    """A file that is not a PNG this reader accepts."""


class Image:
    """An 8-bit RGBA image; pixels are row-major RGBA bytes."""

    __slots__ = ("width", "height", "pixels")

    def __init__(self, width, height, pixels=None):
        self.width = width
        self.height = height
        self.pixels = bytearray(width * height * 4) if pixels is None else bytearray(pixels)
        if len(self.pixels) != width * height * 4:
            raise ValueError("pixel buffer does not match the size")

    def get(self, x, y):
        i = (y * self.width + x) * 4
        return tuple(self.pixels[i:i + 4])

    def set(self, x, y, rgba):
        i = (y * self.width + x) * 4
        self.pixels[i:i + 4] = bytes(rgba)

    def alpha(self, x, y):
        return self.pixels[(y * self.width + x) * 4 + 3]

    def copy(self):
        return Image(self.width, self.height, self.pixels)

    def crop(self, x, y, width, height):
        out = Image(width, height)
        for row in range(height):
            start = ((y + row) * self.width + x) * 4
            out.pixels[row * width * 4:(row + 1) * width * 4] = self.pixels[start:start + width * 4]
        return out

    def paste(self, source, x, y):
        """Copies `source` over this image at (x, y), every texel replaced."""
        for row in range(source.height):
            start = ((y + row) * self.width + x) * 4
            self.pixels[start:start + source.width * 4] = source.pixels[row * source.width * 4:(row + 1) * source.width * 4]

    def is_empty(self):
        return not any(self.pixels[3::4])

    def colours(self):
        """Every RGB of a texel with any alpha."""
        return {tuple(self.pixels[i:i + 3]) for i in range(0, len(self.pixels), 4) if self.pixels[i + 3] > 0}

    def __eq__(self, other):
        return isinstance(other, Image) and (self.width, self.height) == (other.width, other.height) and _visible(self.pixels) == _visible(other.pixels)

    def __repr__(self):
        return f"Image({self.width}x{self.height})"


def _visible(pixels):
    """The buffer with the RGB of fully transparent texels cleared."""
    out = bytearray(pixels)
    for i in range(3, len(out), 4):
        if out[i] == 0:
            out[i - 3:i] = b"\x00\x00\x00"
    return bytes(out)


def blank(width, height):
    return Image(width, height)


def over(bottom, top):
    """`top` composited over `bottom` (Porter-Duff over, same size), as a new image."""
    if (bottom.width, bottom.height) != (top.width, top.height):
        raise ValueError("over() needs two images of one size")
    out = bottom.copy()
    for i in range(0, len(out.pixels), 4):
        ta = top.pixels[i + 3]
        if ta == 0:
            continue
        if ta == 255:
            out.pixels[i:i + 4] = top.pixels[i:i + 4]
            continue
        ba = out.pixels[i + 3]
        alpha = ta * 255 + ba * (255 - ta)
        for c in range(3):
            out.pixels[i + c] = (top.pixels[i + c] * ta * 255 + out.pixels[i + c] * ba * (255 - ta) + alpha // 2) // alpha
        out.pixels[i + 3] = (alpha + 127) // 255
    return out


def parse_colour(text):
    """'#rrggbb' to an (r, g, b) tuple."""
    value = text.strip().lstrip("#")
    if len(value) != 6:
        raise ValueError(f"not a #rrggbb colour: {text}")
    return tuple(int(value[i:i + 2], 16) for i in (0, 2, 4))


def colour_hex(rgb):
    return "#%02x%02x%02x" % tuple(rgb[:3])


def read_png(path):
    with open(path, "rb") as handle:
        return decode_png(handle.read())


def write_png(path, image):
    with open(path, "wb") as handle:
        handle.write(encode_png(image))


def encode_png(image):
    raw = bytearray()
    stride = image.width * 4
    for y in range(image.height):
        raw.append(0)
        raw.extend(image.pixels[y * stride:(y + 1) * stride])
    header = struct.pack(">IIBBBBB", image.width, image.height, 8, 6, 0, 0, 0)
    return SIGNATURE + _chunk(b"IHDR", header) + _chunk(b"IDAT", zlib.compress(bytes(raw), 9)) + _chunk(b"IEND", b"")


def _chunk(kind, data):
    return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data) & 0xFFFFFFFF)


def decode_png(data):
    """`data` as an 8-bit RGBA Image; any malformed input raises PngError and nothing else."""
    header, palette, transparency, compressed = _read_chunks(data)
    width, height, depth, colour_type, interlace = _check_header(header, palette, transparency)
    bits = CHANNELS[colour_type] * depth
    passes = ADAM7 if interlace == 1 else ((0, 0, 1, 1),)
    raw = _inflate(compressed, sum(_pass_size(width, height, p, bits) for p in passes))
    image = Image(width, height)
    position = 0
    for x0, y0, dx, dy in passes:
        pass_width = (width - x0 + dx - 1) // dx
        pass_height = (height - y0 + dy - 1) // dy
        if pass_width == 0 or pass_height == 0:
            continue
        stride = (pass_width * bits + 7) // 8
        rows = _unfilter(raw, position, pass_width, pass_height, stride, max(1, bits // 8))
        position += pass_height * (stride + 1)
        for row_index, row in enumerate(rows):
            for column, rgba in enumerate(_row_pixels(row, pass_width, colour_type, depth, palette, transparency)):
                image.set(x0 + column * dx, y0 + row_index * dy, rgba)
    return image


def _read_chunks(data):
    """The IHDR body, the palette, the tRNS body and the IDAT bodies joined, every CRC checked."""
    if not data.startswith(SIGNATURE):
        raise PngError("not a PNG")
    header, palette, transparency, compressed = None, None, None, bytearray()
    offset = len(SIGNATURE)
    while offset + 12 <= len(data):
        length, kind = struct.unpack(">I4s", data[offset:offset + 8])
        body = data[offset + 8:offset + 8 + length]
        if len(body) != length or offset + 12 + length > len(data):
            raise PngError("truncated chunk")
        (crc,) = struct.unpack(">I", data[offset + 8 + length:offset + 12 + length])
        if zlib.crc32(kind + body) & 0xFFFFFFFF != crc:
            raise PngError(f"bad CRC in {kind!r}")
        offset += 12 + length
        if kind == b"IHDR":
            header = bytes(body)
        elif kind == b"PLTE":
            palette = [tuple(body[i:i + 3]) for i in range(0, len(body) - 2, 3)]
        elif kind == b"tRNS":
            transparency = bytes(body)
        elif kind == b"IDAT":
            compressed.extend(body)
        elif kind == b"IEND":
            break
    if header is None:
        raise PngError("no IHDR")
    return header, palette, transparency, bytes(compressed)


def _check_header(header, palette, transparency):
    """The header's width, height, depth, colour type and interlace, refusing what the PNG standard
    does not allow."""
    if len(header) != 13:
        raise PngError(f"IHDR is {len(header)} bytes, not 13")
    width, height, depth, colour_type, compression, filter_method, interlace = struct.unpack(">IIBBBBB", header)
    if depth not in DEPTHS.get(colour_type, ()) or width == 0 or height == 0:
        raise PngError(f"unsupported PNG: colour type {colour_type}, depth {depth}")
    if compression != 0 or filter_method != 0 or interlace not in (0, 1):
        raise PngError(f"unsupported PNG: compression {compression}, filter method {filter_method}, interlace {interlace}")
    if width * height > MAX_PIXELS:
        raise PngError(f"image too large: {width}x{height}")
    if colour_type == 3 and palette is None:
        raise PngError("indexed PNG without a palette")
    _check_transparency(colour_type, palette, transparency)
    return width, height, depth, colour_type, interlace


def _check_transparency(colour_type, palette, transparency):
    if transparency is None:
        return
    if colour_type == 3:
        if len(transparency) > len(palette):
            raise PngError(f"tRNS has {len(transparency)} entries for a palette of {len(palette)}")
        return
    expected = TRNS_BYTES.get(colour_type)
    if expected is None:
        raise PngError(f"tRNS with colour type {colour_type}, which has its own alpha")
    if len(transparency) != expected:
        raise PngError(f"tRNS is {len(transparency)} bytes, not {expected}, for colour type {colour_type}")


def _inflate(compressed, budget):
    """At most `budget` + 1 bytes of the image stream; a corrupt or short stream raises PngError."""
    try:
        raw = zlib.decompressobj().decompress(compressed, budget + 1)
    except zlib.error as error:
        raise PngError(f"corrupt image data: {error}") from None
    if len(raw) < budget:
        raise PngError("image data too short")
    return raw


def _pass_size(width, height, adam_pass, bits):
    x0, y0, dx, dy = adam_pass
    pass_width = (width - x0 + dx - 1) // dx
    pass_height = (height - y0 + dy - 1) // dy
    if pass_width == 0 or pass_height == 0:
        return 0
    return pass_height * ((pass_width * bits + 7) // 8 + 1)


def _unfilter(raw, position, width, height, stride, bpp):
    rows = []
    previous = bytearray(stride)
    for _ in range(height):
        kind = raw[position]
        line = bytearray(raw[position + 1:position + 1 + stride])
        position += stride + 1
        for i in range(stride):
            left = line[i - bpp] if i >= bpp else 0
            up = previous[i]
            if kind == 1:
                line[i] = (line[i] + left) & 0xFF
            elif kind == 2:
                line[i] = (line[i] + up) & 0xFF
            elif kind == 3:
                line[i] = (line[i] + ((left + up) >> 1)) & 0xFF
            elif kind == 4:
                up_left = previous[i - bpp] if i >= bpp else 0
                line[i] = (line[i] + _paeth(left, up, up_left)) & 0xFF
            elif kind != 0:
                raise PngError(f"unknown filter {kind}")
        rows.append(line)
        previous = line
    return rows


def _paeth(a, b, c):
    p = a + b - c
    pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
    if pa <= pb and pa <= pc:
        return a
    return b if pb <= pc else c


def _samples(row, count, depth):
    if depth == 8:
        return list(row[:count])
    if depth == 16:
        return [row[2 * i] for i in range(count)]  # the high byte
    per_byte = 8 // depth
    mask = (1 << depth) - 1
    return [(row[i // per_byte] >> (8 - depth * (i % per_byte + 1))) & mask for i in range(count)]


def _row_pixels(row, width, colour_type, depth, palette, transparency):
    channels = CHANNELS[colour_type]
    samples = _samples(row, width * channels, depth)
    scale = 255 // ((1 << depth) - 1) if depth < 8 else 1
    key = None
    if transparency is not None and colour_type in (0, 2):
        values = struct.unpack(">%dH" % (len(transparency) // 2), transparency)
        key = tuple(v >> 8 if depth == 16 else v for v in values)
    out = []
    for i in range(width):
        s = samples[i * channels:(i + 1) * channels]
        if colour_type == 3:
            index = s[0]
            if index >= len(palette):
                raise PngError("palette index out of range")
            alpha = transparency[index] if transparency is not None and index < len(transparency) else 255
            out.append(palette[index] + (alpha,))
        elif colour_type == 0:
            grey = s[0] * scale
            out.append((grey, grey, grey, 0 if key is not None and (s[0],) == key[:1] else 255))
        elif colour_type == 4:
            out.append((s[0], s[0], s[0], s[1]))
        elif colour_type == 2:
            out.append((s[0], s[1], s[2], 0 if key is not None and tuple(s) == key[:3] else 255))
        else:
            out.append(tuple(s))
    return out

// Shared by the art shaders (art-pass; design.md D6, D19 and C1 D6). A shader that includes this
// sets both varyings in its vertex(): art_modulate = COLOR, the node's modulate, because in
// fragment() COLOR already holds the texture sample times it; and art_local_y = VERTEX.y, the
// node-local y in pixels, because UV is atlas space for an AtlasTexture frame.

varying vec4 art_modulate;
varying float art_local_y;

// Half an 8-bit step: two colours closer than this per channel are the same palette colour.
const float ART_EXACT = 0.5 / 255.0;
const int ART_SHADES = 4;
// Row 0 of a ramp texture holds the key ramp.
const int ART_KEY_ROW = 0;
// Below the water line: this many rows fade, the last one to ART_FADE_MIN, then the rest is cut.
const float ART_FADE_ROWS = 4.0;
const float ART_FADE_MIN = 0.25;

bool art_same_rgb(vec3 a, vec3 b) {
	return all(lessThan(abs(a - b), vec3(ART_EXACT)));
}

// `texel` with a key-ramp colour (row 0 of `ramps`) replaced by the same shade of row `row`; any
// other colour is unchanged, and so is alpha. One lookup per texel.
vec4 art_swap_key(vec4 texel, sampler2D ramps, int row) {
	for (int shade = 0; shade < ART_SHADES; shade++) {
		if (art_same_rgb(texel.rgb, texelFetch(ramps, ivec2(shade, ART_KEY_ROW), 0).rgb)) {
			return vec4(texelFetch(ramps, ivec2(shade, row), 0).rgb, texel.a);
		}
	}
	return texel;
}

// The alpha a row keeps at `local_y` against a water line at `line_y` (both node-local px): full
// above it, the next ART_FADE_ROWS rows fading to ART_FADE_MIN, then none.
float art_water_alpha(float local_y, float line_y) {
	float depth = local_y - line_y;
	if (depth < 0.0) {
		return 1.0;
	}
	if (depth >= ART_FADE_ROWS) {
		return 0.0;
	}
	return mix(1.0, ART_FADE_MIN, (floor(depth) + 1.0) / ART_FADE_ROWS);
}

// True on the 1 px ripple row, the first row at the water line.
bool art_on_ripple(float local_y, float line_y) {
	return local_y >= line_y && local_y < line_y + 1.0;
}

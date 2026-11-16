// The island's sea (art-pass "Scrolling sea"; design.md D12, T4, K38, K39, K46; art-coast-pass D6):
// the 32 px water texture drifting, its four deep colours swapped to the row of the ramps the depth
// mask picks. The mask has one texel per cell, red the shallowness (shallows or brackish) and green
// the brackishness, softened on the CPU (SeaMask.soft_channels), filtered linearly, sampled at a
// point moved by a static noise warp so long straight runs bend, and cut at a slowly wobbling
// level, so the steps meet in a soft curve instead of cell squares. A second sample at an offset that is not a multiple of 32 px,
// with its own drift, hides the texture's period: the lighter of the two shades is drawn. Every
// pixel is one of the ramps' colours. It runs on the shader clock, so it moves under solo pause.
shader_type canvas_item;

#include "res://scenes/art/art_common.gdshaderinc"

// The deep water texture (ArtTuning.sea_water) and the depth ramps (ArtTuning.sea_ramps).
uniform sampler2D water : filter_nearest, repeat_enable;
uniform sampler2D ramps : filter_nearest;
// One texel per cell: r 1 on shallows and brackish water, g 1 on brackish water.
uniform sampler2D depth_mask : filter_linear;
// Rows of the ramps: deep is the key, the texture's own colours.
uniform int deep_row = 0;
uniform int shallows_row = 1;
uniform int brackish_row = 2;
// The grid's columns and rows, and a cell's size in px.
uniform vec2 grid_cells = vec2(1.0);
uniform float cell_px = 16.0;
// Drift in px per second of each sample, and the second one's offset (not a multiple of 32).
uniform vec2 drift = vec2(5.0, 0.0);
uniform vec2 second_drift = vec2(-2.0, 3.0);
uniform vec2 second_offset = vec2(13.0, 19.0);
// How far the cut moves from 0.5 (in mask units), and how fast it sways: about 2 px each way on a
// softened straight edge, so with the warp the line stays within half a cell of where it rests.
uniform float wobble = 0.05;
uniform float wobble_speed = 0.35;
// The static warp of the point where the mask is sampled: value noise on a lattice of
// warp_period_px, up to warp_px on each axis (SeaMask.WARP_PX, SeaMask.WARP_PERIOD_PX).
uniform float warp_px = 4.0;
uniform float warp_period_px = 48.0;

varying vec2 sea_px;

void vertex() {
	art_modulate = COLOR;
	art_local_y = VERTEX.y;
	sea_px = VERTEX;
}

// The shade (0 dark to 3 light) of the water texel at `px`.
int sea_shade(vec2 px) {
	ivec2 size = textureSize(water, 0);
	ivec2 at = ivec2(mod(floor(px), vec2(size)));
	vec3 rgb = texelFetch(water, at, 0).rgb;
	for (int shade = 0; shade < ART_SHADES; shade++) {
		if (art_same_rgb(rgb, texelFetch(ramps, ivec2(shade, deep_row), 0).rgb)) {
			return shade;
		}
	}
	return 0;
}

// murmur3's 32-bit finaliser (TerrainArt.mix32).
uint sea_mix32(uint h) {
	h ^= h >> 16u;
	h *= 2246822507u;
	h ^= h >> 13u;
	h *= 3266489909u;
	h ^= h >> 16u;
	return h;
}

// A lattice point's value from -1 to 1 (SeaMask.lattice).
float sea_lattice(ivec2 cell, uint channel) {
	uint mixed = sea_mix32(uint(cell.x) ^ sea_mix32(uint(cell.y) ^ sea_mix32(channel)));
	return float(mixed & 65535u) / 65535.0 * 2.0 - 1.0;
}

float sea_noise(vec2 at, uint channel) {
	vec2 base = floor(at);
	vec2 part = at - base;
	vec2 ease = part * part * (3.0 - 2.0 * part);
	ivec2 cell = ivec2(base);
	float top = mix(sea_lattice(cell, channel), sea_lattice(cell + ivec2(1, 0), channel), ease.x);
	float bottom = mix(sea_lattice(cell + ivec2(0, 1), channel), sea_lattice(cell + ivec2(1, 1), channel), ease.x);
	return mix(top, bottom, ease.y);
}

// The static warp at `px` (SeaMask.warp_offset): it never moves with time.
vec2 sea_warp(vec2 px) {
	vec2 at = px / warp_period_px;
	return vec2(sea_noise(at, 0u), sea_noise(at, 1u)) * warp_px;
}

void fragment() {
	vec2 px = floor(sea_px) + 0.5;
	int shade = max(sea_shade(px - drift * TIME), sea_shade(px + second_offset - second_drift * TIME));
	vec2 mask = texture(depth_mask, (px + sea_warp(px)) / (grid_cells * cell_px)).rg;
	// Two low sines of the position: a smooth, slowly moving cut, never per-pixel noise.
	float sway = sin(px.x * 0.071 + px.y * 0.023 + TIME * wobble_speed)
			+ sin(px.y * 0.083 - px.x * 0.031 - TIME * wobble_speed * 0.7);
	float cut = 0.5 + wobble * 0.5 * sway;
	int row = deep_row;
	if (mask.r > cut) {
		row = mask.g > cut ? brackish_row : shallows_row;
	}
	COLOR = vec4(texelFetch(ramps, ivec2(shade, row), 0).rgb, 1.0) * art_modulate;
}

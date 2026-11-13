// The island's sea (art-pass "Scrolling sea"; design.md D12, T4, K38, K39, K46): the 32 px water
// texture drifting, its four deep colours swapped to the row of the ramps the depth mask picks.
// The mask has one texel per cell, red the shallowness (shallows or brackish) and green the
// brackishness, filtered linearly and cut at a slowly wobbling level, so the steps meet in a soft
// line instead of cell squares. A second sample at an offset that is not a multiple of 32 px,
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
// How far the cut moves from 0.5 (in mask units), and how fast it sways.
uniform float wobble = 0.14;
uniform float wobble_speed = 0.35;

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

void fragment() {
	vec2 px = floor(sea_px) + 0.5;
	int shade = max(sea_shade(px - drift * TIME), sea_shade(px + second_offset - second_drift * TIME));
	vec2 mask = texture(depth_mask, px / (grid_cells * cell_px)).rg;
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

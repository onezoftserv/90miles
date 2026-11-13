// The foam on the Shore layer (art-pass "Shoreline overlay"; design.md D13, K37, K39, K46): every
// shore cell holds frame 0 of its mask, and this steps whole tiles along the sheet's row to frame
// (clock frame + the cell's phase) mod 8, the phase read from a mask with one texel per cell. The
// foam sheet's source has no texture padding, so frame f of a tile is f tiles to the right.
shader_type canvas_item;

#include "res://scenes/art/art_common.gdshaderinc"

// One texel per grid cell: the phase 0 to 7, scaled so 7 is white (SeaMask.to_image).
uniform sampler2D phase_mask : filter_nearest;
// The layer's canvas position: a tile layer draws its tiles in quadrants, each with its own origin.
uniform vec2 origin = vec2(0.0);
uniform float cell_px = 16.0;
uniform int frames = 8;
// Calm: about six frames a second.
uniform float frames_per_second = 6.0;

varying vec2 shore_px;

void vertex() {
	art_modulate = COLOR;
	art_local_y = VERTEX.y;
	shore_px = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy - origin;
}

void fragment() {
	ivec2 size = textureSize(phase_mask, 0);
	ivec2 cell = clamp(ivec2(floor(shore_px / cell_px)), ivec2(0), size - 1);
	int phase = int(round(texelFetch(phase_mask, cell, 0).r * float(frames - 1)));
	int frame = (int(floor(TIME * frames_per_second)) + phase) % frames;
	vec2 uv = UV + vec2(float(frame) * cell_px * TEXTURE_PIXEL_SIZE.x, 0.0);
	COLOR = texture(TEXTURE, uv) * art_modulate;
}

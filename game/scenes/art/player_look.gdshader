// The player's look (art-pass "Clothing colours" and "Swimmers at the water line"; design.md D6,
// D19 and C1 D6): one material per player, on Look/Sprite. It swaps the clothing key ramp to the
// look slot's ramp and, while swimming or floating, cuts the frame at the water line with a 1 px
// ripple. Each frame is an AtlasTexture region of one atlas, so the cut uses the node-local y
// passed from vertex(), never UV.
shader_type canvas_item;

#include "res://scenes/art/art_common.gdshaderinc"

// The row of `ramps` the clothing takes: the look slot + 1 (row 0 is the key ramp).
uniform int slot_row = 1;
// palette/player_ramps.png.
uniform sampler2D ramps : filter_nearest;
uniform bool water_line_on = false;
// Look/Sprite-local px: the water row - 27 + the swim drop = 19 - 27 + 12 = +4, the feet line.
uniform float water_line_y = 4.0;
uniform vec4 foam_color : source_color = vec4(1.0);

void vertex() {
	art_modulate = COLOR;
	art_local_y = VERTEX.y;
}

void fragment() {
	vec4 texel = art_swap_key(texture(TEXTURE, UV), ramps, slot_row);
	if (water_line_on) {
		bool ripple = texel.a > 0.0 && art_on_ripple(art_local_y, water_line_y);
		texel.rgb = ripple ? foam_color.rgb : texel.rgb;
		texel.a *= art_water_alpha(art_local_y, water_line_y);
	}
	COLOR = texel * art_modulate;
}

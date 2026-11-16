// The player's look (art-pass "Clothing colours" and "Swimmers at the water line"; design.md D6,
// D19 and C1 D6; art-sprite-polish D1): one material per player, on Look/Sprite. It swaps the
// clothing key ramp to the look slot's ramp and, while swimming or floating, cuts the frame hard at
// the water line: the rows above it opaque, the rest clear, and Look/SwimRing draws the water round
// the body. Each frame is an AtlasTexture region of one atlas, so the cut uses the node-local y
// passed from vertex(), never UV. The shark and the deck keep art_common's fade (waterline.gdshader).
shader_type canvas_item;

#include "res://scenes/art/art_common.gdshaderinc"

// The row of `ramps` the clothing takes: the look slot + 1 (row 0 is the key ramp).
uniform int slot_row = 1;
// palette/player_ramps.png.
uniform sampler2D ramps : filter_nearest;
uniform bool water_line_on = false;
// Look/Sprite-local px: the water row - 27 + the swim drop = 19 - 27 + 12 = +4, the feet line.
uniform float water_line_y = 4.0;
// damage-feedback D4, the hurt blink, after the water-line cut: white for the frame of a hit, hidden
// on half of each blink, or a steady tint (alpha 0: none) with "Reducir destellos".
uniform bool hurt_white = false;
uniform bool hurt_hidden = false;
uniform vec4 hurt_tint : source_color = vec4(0.0);

void vertex() {
	art_modulate = COLOR;
	art_local_y = VERTEX.y;
}

void fragment() {
	vec4 texel = art_swap_key(texture(TEXTURE, UV), ramps, slot_row);
	if (water_line_on) {
		texel.a = art_local_y < water_line_y ? texel.a : 0.0;
	}
	if (hurt_white) {
		texel.rgb = vec3(1.0);
	}
	texel.rgb = mix(texel.rgb, hurt_tint.rgb, hurt_tint.a);
	if (hurt_hidden) {
		texel.a = 0.0;
	}
	COLOR = texel * art_modulate;
}

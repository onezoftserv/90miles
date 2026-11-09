// A water creature drawn at the water line (art-pass "Swimmers at the water line"; design.md D16,
// D19): the rows above water_line_y at full alpha, the next rows fading, the rest cut, with a 1 px
// ripple on the line. The cut uses the node-local y passed from vertex(), never UV.
shader_type canvas_item;

#include "res://scenes/art/art_common.gdshaderinc"

// Node-local px of the water line.
uniform float water_line_y = 0.0;
uniform vec4 foam_color : source_color = vec4(1.0);

void vertex() {
	art_modulate = COLOR;
	art_local_y = VERTEX.y;
}

void fragment() {
	vec4 texel = texture(TEXTURE, UV);
	bool ripple = texel.a > 0.0 && art_on_ripple(art_local_y, water_line_y);
	texel.rgb = ripple ? foam_color.rgb : texel.rgb;
	texel.a *= art_water_alpha(art_local_y, water_line_y);
	COLOR = texel * art_modulate;
}

// Sunstroke (survival-meters): blurs and warms everything drawn before this rect.
// A 5x5 box blur over the screen texture, which works in the Compatibility renderer.
shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear;
// Distance between samples, in screen pixels.
uniform float spread_px = 1.0;
// How much of the warm haze color is mixed in.
uniform float haze = 0.12;
uniform vec3 haze_color : source_color = vec3(1.0, 0.85, 0.6);

void fragment() {
	vec2 offset = SCREEN_PIXEL_SIZE * spread_px;
	vec3 sum = vec3(0.0);
	for (int x = -2; x <= 2; x++) {
		for (int y = -2; y <= 2; y++) {
			sum += texture(screen_texture, SCREEN_UV + vec2(float(x), float(y)) * offset).rgb;
		}
	}
	COLOR = vec4(mix(sum / 25.0, haze_color, haze), 1.0);
}

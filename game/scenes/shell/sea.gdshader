// ui-shell title background: a banded sunset over a moving sea, drawn in whole pixels of the
// 640x360 view (the window's integer scale keeps them square). Written for 90 Millas.
shader_type canvas_item;

uniform vec4 sky_top : source_color = vec4(0.09, 0.11, 0.26, 1.0);
uniform vec4 sky_low : source_color = vec4(0.93, 0.50, 0.31, 1.0);
uniform vec4 sun_color : source_color = vec4(1.0, 0.82, 0.36, 1.0);
uniform vec4 sea_far : source_color = vec4(0.13, 0.35, 0.53, 1.0);
uniform vec4 sea_near : source_color = vec4(0.03, 0.12, 0.24, 1.0);
uniform vec4 foam : source_color = vec4(0.86, 0.93, 0.95, 1.0);
uniform float horizon = 0.5;
uniform float sun_x = 0.72;
uniform vec2 view_size = vec2(640.0, 360.0);

const float BANDS = 6.0;

void fragment() {
	vec2 px = floor(UV * view_size);
	vec2 uv = px / view_size;
	float aspect = view_size.x / view_size.y;
	vec3 color;
	if (uv.y < horizon) {
		color = mix(sky_top.rgb, sky_low.rgb, floor(uv.y / horizon * BANDS) / BANDS);
		if (distance(vec2(uv.x * aspect, uv.y), vec2(sun_x * aspect, horizon)) < 0.12) {
			color = sun_color.rgb;
		}
	} else {
		float depth = (uv.y - horizon) / (1.0 - horizon);
		color = mix(sea_far.rgb, sea_near.rgb, floor(depth * BANDS) / BANDS);
		float wave = sin(px.x * 0.09 + TIME * 1.3 + depth * 22.0) + sin(px.x * 0.031 - TIME * 0.7 + depth * 9.0);
		float row = fract(depth * (6.0 + depth * 18.0) - TIME * 0.04);
		if (wave > 1.3 && row < 0.16) {
			color = foam.rgb;
		}
		float glitter = abs(uv.x - sun_x) - 0.06 * (1.0 - depth * 0.6);
		if (glitter < 0.0 && wave > 0.6 && row < 0.35) {
			color = mix(color, sun_color.rgb, 0.85);
		}
	}
	COLOR = vec4(color, 1.0);
}

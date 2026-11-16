// ui-shell "Hit flash at the screen edges" (damage-feedback design D5): a red band in from every
// edge of the screen, deepest at the edge and clear in the centre, in four flat steps for the pixel
// look. `strength` is the flash's alpha now; HurtOverlay sets it each frame.
shader_type canvas_item;

uniform vec4 flash_color : source_color = vec4(0.85, 0.08, 0.08, 1.0);
uniform float strength = 0.0;
// How deep the band reaches in from each edge, in the overlay's own pixels.
uniform float edge_px = 24.0;
// The overlay's size in its own pixels.
uniform vec2 size_px = vec2(640.0, 360.0);

const float STEPS = 4.0;

void fragment() {
	vec2 px = UV * size_px;
	float from_edge = min(min(px.x, size_px.x - px.x), min(px.y, size_px.y - px.y));
	float depth = clamp(1.0 - from_edge / edge_px, 0.0, 1.0);
	float stepped = ceil(depth * STEPS) / STEPS;
	COLOR = vec4(flash_color.rgb, strength * stepped * stepped);
}

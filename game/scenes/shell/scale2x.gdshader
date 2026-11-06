// ui-shell "Pixel filter" (Suave): Scale2x-style smoothing of the enlarged world picture.
// Written from the published rules (Eric Johnston's EPX and Andrea Mazzoleni's description of
// Scale2x); no reference implementation was used.
//
// It runs once per screen pixel over the 640×360 world texture drawn at a whole-number scale.
// Each world texel P is split into four quarters. With its edge neighbours A (up), B (right),
// C (left) and D (down):
//   top-left     = A if C == A and C != D and A != B, else P
//   top-right    = B if A == B and A != C and B != D, else P
//   bottom-left  = C if D == C and D != B and C != A, else P
//   bottom-right = D if B == D and B != A and D != C, else P
// At 3× and 4× a quarter covers more than one screen pixel. The rules are symmetric, so the
// result does not depend on which way the texture's rows run.
shader_type canvas_item;

// Colours closer than this on every channel count as the same colour.
const float SAME = 0.004;

bool same(vec4 first, vec4 second) {
	vec4 gap = abs(first - second);
	return max(max(gap.r, gap.g), max(gap.b, gap.a)) < SAME;
}

void fragment() {
	vec2 texel = TEXTURE_PIXEL_SIZE;
	vec2 source = UV / texel;
	vec2 cell = floor(source);
	vec2 quarter = step(vec2(0.5), source - cell);
	vec2 centre = (cell + 0.5) * texel;
	vec4 p = texture(TEXTURE, centre);
	vec4 a = texture(TEXTURE, centre - vec2(0.0, texel.y));
	vec4 b = texture(TEXTURE, centre + vec2(texel.x, 0.0));
	vec4 c = texture(TEXTURE, centre - vec2(texel.x, 0.0));
	vec4 d = texture(TEXTURE, centre + vec2(0.0, texel.y));
	vec4 result = p;
	if (quarter.y < 0.5) {
		if (quarter.x < 0.5) {
			if (same(c, a) && !same(c, d) && !same(a, b)) {
				result = a;
			}
		} else if (same(a, b) && !same(a, c) && !same(b, d)) {
			result = b;
		}
	} else {
		if (quarter.x < 0.5) {
			if (same(d, c) && !same(d, b) && !same(c, a)) {
				result = c;
			}
		} else if (same(b, d) && !same(b, a) && !same(d, c)) {
			result = d;
		}
	}
	COLOR = result;
}

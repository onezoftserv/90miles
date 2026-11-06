class_name DisplayFit
extends RefCounted
## ui-shell "Display scaling": the game draws its 640×360 view at a whole-number scale (the
## project's integer stretch). These pick that scale and the window size for it, as Shattered
## Pixel Dungeon picks its zoom from the window (ideas only; no code taken).

const BASE_SIZE: Vector2i = Vector2i(640, 360)


## The largest whole-number scale at which `base` fits `area`, at least 1.
static func best_scale(area: Vector2i, base: Vector2i = BASE_SIZE) -> int:
	return maxi(1, mini(floori(float(area.x) / base.x), floori(float(area.y) / base.y)))


## The window's scale: `fixed` (1 to 4) when set, the best fit when 0, never larger than fits.
static func window_scale(fixed: int, usable: Vector2i, base: Vector2i = BASE_SIZE) -> int:
	var best := best_scale(usable, base)
	return best if fixed <= 0 else mini(fixed, best)


static func window_size(scale: int, base: Vector2i = BASE_SIZE) -> Vector2i:
	return base * maxi(scale, 1)

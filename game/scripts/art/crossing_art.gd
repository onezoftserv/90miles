class_name CrossingArt
extends RefCounted
## What the crossing's looks share (art-sprite-polish D2; art-mood-pass D6-D8): pure reads of the
## crossing's synced state (its plan clock, its lateral position, its integrity), the same on every
## peer. Drawing only; it never writes the crossing.

## The crossing's scroll wraps at this many px (Crossing.advance: two lengths of the 32 px water
## texture); the wake's frames step a whole number of times per wrap so the wrap never shows.
const SCROLL_WRAP_PX: float = 64.0
const CREST_FRAMES: int = 3
const BOW_FRAMES: int = 2
const STERN_FRAMES: int = 3
## The bow ripple's rows just north of the deck, and the stern V's start just under its south edge.
const BOW_ROWS: float = 3.0
const STERN_TUCK_PX: float = 2.0
## The stern V's size, and the small one a board gets (the full V's top middle, so it is the same V).
const STERN_SIZE: Vector2 = Vector2(32.0, 24.0)
const SMALL_STERN_SIZE: Vector2 = Vector2(16.0, 12.0)


## The rects of `crossing`'s decks drawn now: each afloat board on a board route, else the shared
## deck while its vessel is intact (CrossingDeck and CrossingBoards draw on the same rule). Empty on
## a swim with no vessel and once the deck has sunk.
static func drawn_decks(crossing: Crossing) -> Array[Rect2]:
	var decks: Array[Rect2] = []
	if crossing == null or crossing.finished:
		return decks
	if crossing.is_board_route():
		for peer: int in crossing.boards:
			if (crossing.boards[peer] as VesselIntegrity).intact():
				decks.append(crossing.deck_rect_of(peer))
	elif crossing.integrity.intact():
		decks.append(crossing.deck_rect())
	return decks


## art-mood-pass D6: the crests on `crossing`'s sea now, each {"at": its middle in the crossing's
## coordinates, "frame": 0 rising, 1 peak, 2 falling}.
static func crests(crossing: Crossing) -> Array[Dictionary]:
	if crossing == null:
		return []
	return crests_at(crossing, crossing.elapsed_s, crossing.steer.position)


## The crests at plan time `elapsed_s` with the vessel `lateral_tiles` off its line. A lattice of
## `crest_cell_tiles` cells is laid on the water, which drifts south with the scroll (the route's
## speed over the plan clock, unwrapped, so every peer agrees) and sideways against the vessel's
## lateral position, as the hazards do. Each cell shows at most one crest, in the time slots its
## hash passes `crest_density`; where in the cell and when in the slot come from the same hash.
static func crests_at(crossing: Crossing, elapsed_s: float, lateral_tiles: float) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	if crossing == null or crossing.route == null or crossing.tuning == null or crossing.finished:
		return found
	var art := ArtTuning.standard()
	var cell: float = art.crest_cell_tiles * Crossing.TILE_PX
	var speed: float = crossing.tuning.scroll_tiles_per_s * Crossing.TILE_PX * crossing.route.speed_multiplier
	var drift := Vector2(-lateral_tiles * Crossing.TILE_PX, elapsed_s * speed)
	var sea: Rect2 = crossing.sea_rect()
	var first := Vector2i(floori((sea.position.x - drift.x) / cell), floori((sea.position.y - drift.y) / cell))
	var last := Vector2i(floori((sea.end.x - drift.x) / cell), floori((sea.end.y - drift.y) / cell))
	for j: int in range(first.y, last.y + 1):
		for i: int in range(first.x, last.x + 1):
			var seed: int = TerrainArt.mix32(TerrainArt.mix32(i) ^ (j * 0x9e3779b1))
			var phase_s: float = float(seed % 1000) / 1000.0 * art.crest_slot_s
			var slot: int = floori((elapsed_s + phase_s) / art.crest_slot_s)
			if float(TerrainArt.mix32(seed ^ slot) % 10000) / 10000.0 >= art.crest_density:
				continue
			var offset := Vector2(4.0 + float((seed >> 8) % int(cell - 8.0)), 2.0 + float((seed >> 16) % int(cell - 4.0)))
			var at: Vector2 = Vector2(i, j) * cell + offset + drift
			if not sea.has_point(at):
				continue
			var through: float = fposmod(elapsed_s + phase_s, art.crest_slot_s) / art.crest_slot_s
			found.append({"at": at, "frame": mini(floori(through * CREST_FRAMES), CREST_FRAMES - 1)})
	return found


## art-mood-pass D7: the wake of each drawn deck or board, each {"deck": its rect, "small": a board's,
## "bow": the bow ripple's rect along the deck's north edge, "stern": the stern V's rect trailing
## south, "bow_frame", "stern_frame"}. The frames step with the scroll, so a faster route's wake runs
## faster; a sunk deck and a swim have none.
static func wakes(crossing: Crossing) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	if crossing == null:
		return found
	var steps: int = ArtTuning.standard().wake_steps
	var step: int = floori(crossing.scroll_px() * steps / SCROLL_WRAP_PX)
	var small: bool = crossing.is_board_route()
	for deck: Rect2 in drawn_decks(crossing):
		var stern_size: Vector2 = SMALL_STERN_SIZE if small else STERN_SIZE
		found.append({
			"deck": deck,
			"small": small,
			"bow": Rect2(deck.position.x, deck.position.y - BOW_ROWS, deck.size.x, BOW_ROWS),
			"stern": Rect2(Vector2(deck.get_center().x - stern_size.x / 2.0, deck.end.y - STERN_TUCK_PX), stern_size),
			"bow_frame": posmod(step, BOW_FRAMES),
			"stern_frame": posmod(step, STERN_FRAMES),
		})
	return found


## art-mood-pass D8: the part of a 16x16 item icon drawn on the water: the rows down to its waterline,
## `flotsam_cut_rows` above its lowest opaque row, but never fewer than `flotsam_min_rows` of it, so
## its silhouette and outline still read.
static func waterline_cut(image: Image, art: ArtTuning) -> Rect2i:
	var top: int = image.get_height()
	var lowest: int = -1
	for y: int in image.get_height():
		for x: int in image.get_width():
			if image.get_pixel(x, y).a8 > 0:
				top = mini(top, y)
				lowest = maxi(lowest, y)
	if lowest < 0:
		return Rect2i(Vector2i.ZERO, image.get_size())
	var line: int = clampi(lowest - art.flotsam_cut_rows, top + art.flotsam_min_rows - 1, lowest)
	return Rect2i(0, 0, image.get_width(), line + 1)


## art-mood-pass D8: a floating piece's bob, 0 or 1 px, from its beat index and the plan clock.
static func bob(index: int, elapsed_s: float, art: ArtTuning) -> int:
	var phase: float = float(TerrainArt.mix32(index) % 1000) / 1000.0 * 2.0
	return 1 if fposmod(elapsed_s / art.flotsam_bob_s + phase, 2.0) >= 1.0 else 0

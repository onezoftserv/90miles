extends GutTest
## secret-cay "Spot pick", "Concealment", "Concealed pick-up hold", "Map hint" and "Needle bands"
## with exactly 1 player, offline, in the dev hunt scene from a fixed seed: both pieces lie on two
## different hiding spots, the same two cells when placed again; walking within 3 tiles reveals
## each; a 1.5 s hold takes each; picking up the map shows its text with the compass's spot-kind
## phrase in the landmark slot (no "palma" when the compass hides by the flotsam); with the compass
## carried the needle points at the map and steadies band by band as the player walks in.

const SCENE: PackedScene = preload("res://scenes/dev/secret_hunt_playground.tscn")
const TILE: float = 16.0
const FRAME_S: float = 1.0 / 60.0

var scene: SecretHuntPlayground
var tuning: SecretTuning = SecretTuning.standard()


func before_each() -> void:
	WeatherManager.stop()
	scene = SCENE.instantiate() as SecretHuntPlayground
	add_child_autofree(scene)
	assert_true(scene.start(SecretPlayground.parse_args(PackedStringArray(["--solo"]))), "the hunt starts solo")


func after_each() -> void:
	WeatherManager.stop()
	NetManager.leave()


func _body() -> PlayerBody:
	var body := scene.session.body(CoopSession.HOST_ID)
	body.player_input.enabled = false
	body.auto_advance = false
	return body


func _piece(item_id: StringName) -> WorldItem:
	return scene.hunt.pieces.get(item_id) as WorldItem


func _hold(body: PlayerBody, seconds: float) -> void:
	for i: int in roundi(seconds / FRAME_S):
		body.intent = MoveIntent.create(Vector2.ZERO, false, false, true)
		body.advance(FRAME_S)
	body.intent = MoveIntent.create(Vector2.ZERO, false, false, false)
	body.advance(FRAME_S)


# Walks the body to the piece's cell, checking it is revealed within 3 tiles, then digs it out.
func _find(body: PlayerBody, item_id: StringName) -> void:
	var piece := _piece(item_id)
	assert_not_null(piece, "%s lies on the island" % item_id)
	if piece == null:
		return
	body.position = piece.position + Vector2(5.0 * TILE, 0.0)
	piece.step(0.0)
	assert_false(piece.revealed, "%s hidden at 5 tiles" % item_id)
	body.position = piece.position + Vector2(3.0 * TILE, 0.0)
	piece.step(0.0)
	assert_true(piece.revealed, "%s revealed at 3 tiles" % item_id)
	body.position = piece.position + Vector2(0.5 * TILE, 0.0)
	_hold(body, 1.0)
	assert_eq(body.inventory.count_id(item_id), 0, "a 1 s hold leaves %s" % item_id)
	_hold(body, 1.5)
	assert_eq(body.inventory.count_id(item_id), 1, "a 1.5 s hold takes %s" % item_id)


# Puts the compass on a hiding spot whose nearest feature is `kind`, and the map elsewhere.
func _replace_pieces(kind: StringName) -> bool:
	for item: WorldItem in [_piece(tuning.map_item_id), _piece(tuning.compass_item_id)]:
		if item != null:
			item.get_parent().remove_child(item)
			item.free()
	var built: IslandLayout = scene.island.built
	var spots: Array[Vector2i] = built.hiding_spots(tuning)
	var compass_cell := Vector2i(-1, -1)
	for cell: Vector2i in spots:
		if built.spot_kind(cell, tuning) == kind:
			compass_cell = cell
			break
	assert_ne(compass_cell, Vector2i(-1, -1), "a hiding spot by a %s" % kind)
	if compass_cell.x < 0:
		return false
	var map_cell: Vector2i = spots[0] if spots[0] != compass_cell else spots[1]
	return scene.hunt.place_pieces(map_cell, compass_cell)


func test_both_pieces_lie_on_two_hiding_spots_from_the_seed() -> void:
	var spots: Array[Vector2i] = scene.island.built.hiding_spots(tuning)
	var map_cell: Vector2i = scene.hunt.cells.get(tuning.map_item_id, Vector2i(-1, -1))
	var compass_cell: Vector2i = scene.hunt.cells.get(tuning.compass_item_id, Vector2i(-1, -1))
	assert_has(spots, map_cell, "the map on a hiding spot")
	assert_has(spots, compass_cell, "the compass on a hiding spot")
	assert_ne(map_cell, compass_cell, "two different spots")
	var again: Array[Vector2i] = SecretHunt.pick_cells(scene.island.built, tuning, SecretHuntPlayground.DEV_SEED)
	assert_eq(again, [map_cell, compass_cell] as Array[Vector2i], "the same two cells from the same seed")
	for item_id: StringName in [tuning.map_item_id, tuning.compass_item_id]:
		var piece := _piece(item_id)
		assert_not_null(piece)
		if piece != null:
			assert_true(piece.concealed, "%s lies concealed" % item_id)
			assert_eq(piece.position, IslandLayout.cell_center(scene.hunt.cells[item_id]))


func test_a_solo_player_finds_both_pieces() -> void:
	var body := _body()
	_find(body, tuning.compass_item_id)
	_find(body, tuning.map_item_id)


func test_a_solo_player_reads_where_the_compass_hides() -> void:
	assert_true(_replace_pieces(&"palm"))
	var body := _body()
	_find(body, tuning.map_item_id)
	var shown: String = scene.hud.note_label.shown_text()
	assert_eq(shown, SecretHunt.map_text(tuning, &"palm", "es"))
	assert_string_contains(shown, "una palma", "the palm phrase in the slot")
	assert_false(shown.contains("{pista}"), "the slot is filled")
	assert_false(shown.contains(str(scene.hunt.cells[tuning.compass_item_id])), "no cell")
	assert_false(shown.contains(scene.layout.name_es), "no island")


func test_a_hint_that_is_not_a_palm() -> void:
	assert_true(_replace_pieces(&"flotsam"))
	var body := _body()
	_find(body, tuning.map_item_id)
	var shown: String = scene.hud.note_label.shown_text()
	assert_string_contains(shown, "un reguero de cosas que trajo el mar", "the flotsam phrase")
	assert_false(shown.to_lower().contains("palma"), "no palm")


func test_the_needle_points_at_the_map_and_steadies() -> void:
	var body := _body()
	body.inventory.add(tuning.compass_item_id, 1)
	var map := _piece(tuning.map_item_id)
	var needle: CompassNeedle = scene.hud.needle
	needle.set_process(false)
	# Walk in along the line from a far cell of the island to the map.
	var start: Vector2 = map.position + Vector2(-30.0 * TILE, 0.0)
	var widest: float = INF
	for tiles: float in [30.0, 15.0, 8.0, 4.0]:
		body.position = map.position + (start - map.position).normalized() * tiles * TILE
		needle.step(0.05)
		assert_eq(needle.target, map as Node2D, "it points at the map at %d tiles" % tiles)
		assert_lte(needle.wobble_deg, widest, "steadier at %d tiles" % tiles)
		widest = needle.wobble_deg
	assert_eq(needle.wobble_deg, 0.0, "still within 6 tiles")


func test_the_map_in_english() -> void:
	var text: String = SecretHunt.map_text(tuning, &"palm", "en")
	assert_eq(text, "An X, a palm and a crooked compass rose. You can tell it was drawn with a compass that doesn't work.")
	assert_string_contains(SecretHunt.map_text(tuning, &"no_such_kind", "en"), "something nobody can make out", "the default phrase")
	assert_string_contains(SecretHunt.map_text(tuning, &"no_such_kind", "es"), "algo que no se entiende")

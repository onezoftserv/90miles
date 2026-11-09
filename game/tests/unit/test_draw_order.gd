extends GutTest
## art-pass "Draw order by foot position" ("Behind and in front of a palm"; design.md D15, P9, T5,
## T6), with exactly 1 player, offline: through the game shell, a solo player one tile north of a
## palm is drawn under it and, after walking to one tile south, over it, and no node changes its
## parent; ground layers sit below 0, the crossing's sea at -40 and its deck at -20 under the
## riders, and the name tag and speech bubble at 20 over any crown; after travelling to the coast
## cay, a player on its land is drawn over its terrain. The order is read from the tree by Godot's
## 2D rules (DrawOrder; a headless run renders nothing), whose own reading is checked first.

const SHELL_SCENE: PackedScene = preload("res://scenes/shell/game_shell.tscn")
const NAME_TAG_SCENE: PackedScene = preload("res://scenes/ui/name_tag.tscn")
const SPEECH_BUBBLE_SCENE: PackedScene = preload("res://scenes/ui/speech_bubble.tscn")
const MOVEMENT_PLAYGROUND: PackedScene = preload("res://scenes/dev/movement_playground.tscn")
const COOP_PLAYGROUND: PackedScene = preload("res://scenes/dev/coop_playground.tscn")
const SETTINGS_PATH: String = "user://test_draw_order_settings.cfg"
const TILE: float = 16.0
const COAST: StringName = &"coast_cay"
const CROSSING_SEA_Z: int = -40
const CROSSING_DECK_Z: int = -20
const OVERHEAD_Z: int = 20
## Frames a two-tile walk may take at walking speed, with room to spare.
const WALK_FRAMES: int = 240
## The session's own containers, filled by its spawners.
const SESSION_CONTAINERS: Array[StringName] = [&"Entities", &"Pickups", &"Players"]


func before_each() -> void:
	NetManager.start_solo()
	WeatherManager.stop()
	WeatherManager.sky.start_at(0.0)


func after_each() -> void:
	WeatherManager.stop()
	NetManager.leave()
	if FileAccess.file_exists(SETTINGS_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS_PATH))


func _shell() -> GameShell:
	var shell := SHELL_SCENE.instantiate() as GameShell
	shell.settings_path = SETTINGS_PATH
	add_child_autofree(shell)
	(shell.screen as TitleScreen).solo_requested.emit()
	shell.session.body(CoopSession.HOST_ID).player_input.enabled = false
	return shell


func _cell_of(at: Vector2) -> Vector2i:
	return Vector2i(floori(at.x / TILE), floori(at.y / TILE))


func _is_land(island: SandbarIsland, cell: Vector2i) -> bool:
	return not TerrainQuery.is_water(island.terrain.terrain_at(cell))


# A palm whose cells one tile north and one tile south are land, so a player walks past it on foot.
func _walkable_palm(island: SandbarIsland) -> Palm:
	for node: Node in island.get_node(^"Palms").get_children():
		var palm := node as Palm
		var cell := _cell_of(palm.position)
		if _is_land(island, cell + Vector2i.UP) and _is_land(island, cell + Vector2i.DOWN):
			return palm
	return null


# The island's ground layers: every tile layer it builds (task 4.5), however it is made.
func _ground_layers(island: SandbarIsland) -> Array[Node]:
	return island.find_children("*", "TileMapLayer", true, false)


# --- DrawOrder's reading of Godot's rules --------------------------------------------------------

func _node_at(parent: Node, y: float) -> Node2D:
	var node := Node2D.new()
	node.position = Vector2(0.0, y)
	parent.add_child(node)
	return node


func test_the_reading_follows_tree_order_without_y_sort() -> void:
	var root := Node2D.new()
	add_child_autofree(root)
	var first := _node_at(root, 50.0)
	var second := _node_at(root, 10.0)
	assert_true(DrawOrder.drawn_after(second, first), "later in the tree, drawn later, whatever its y")
	assert_true(DrawOrder.drawn_after(_node_at(first, 0.0), first), "a child after its parent")


func test_the_reading_sorts_by_y_through_nested_y_sort_and_keeps_subtrees_whole() -> void:
	var root := Node2D.new()
	root.y_sort_enabled = true
	add_child_autofree(root)
	var sorted_group := _node_at(root, 0.0)
	sorted_group.y_sort_enabled = true
	var plain_group := _node_at(root, 0.0)
	var low := _node_at(sorted_group, 40.0)
	var high := _node_at(sorted_group, 10.0)
	var inside_plain := _node_at(plain_group, 30.0)
	assert_true(DrawOrder.drawn_after(low, high), "lower on screen, drawn later")
	assert_true(DrawOrder.drawn_after(low, inside_plain), "a y-sorted group's children sort with the root's")
	assert_true(DrawOrder.drawn_after(high, inside_plain), "a plain group draws its subtree at its own y (0)")
	high.z_index = 1
	assert_true(DrawOrder.drawn_after(high, low), "a higher z wins over y")
	assert_eq(DrawOrder.absolute_z(_node_at(high, 0.0)), 1, "z is relative to the parent")


# Godot sorts a y-sorted node's own drawing into its list at its own origin, first among equal y
# (RendererCanvasCull::_cull_canvas_item: child_items[0] is the item, ysort_pos (0, 0), index 0).
func test_a_y_sorted_parent_draws_itself_at_its_origin_among_its_children() -> void:
	var root := Node2D.new()
	root.y_sort_enabled = true
	add_child_autofree(root)
	var above := _node_at(root, -5.0)
	var below := _node_at(root, 5.0)
	var level := _node_at(root, 0.0)
	assert_false(DrawOrder.drawn_after(above, root), "a child above the parent's origin is drawn before the parent")
	assert_true(DrawOrder.drawn_after(root, above), "so the parent is drawn after it")
	assert_true(DrawOrder.drawn_after(below, root), "a child below the origin, after the parent")
	assert_true(DrawOrder.drawn_after(level, root), "on a tie the parent comes first")
	var nested := _node_at(root, 20.0)
	nested.y_sort_enabled = true
	var inside := _node_at(nested, -30.0)
	assert_false(DrawOrder.drawn_after(inside, nested), "a nested y-sorted parent sorts at its origin (20) in the outer list")
	assert_true(DrawOrder.drawn_after(nested, inside), "and is drawn after a child at -10")
	assert_false(DrawOrder.drawn_after(inside, root), "the outer parent (0) is drawn after it too")
	var plain := _node_at(root, 30.0)
	assert_true(DrawOrder.drawn_after(_node_at(plain, -100.0), plain), "a plain parent draws before its subtree, whatever its y")


# --- the game's tree -----------------------------------------------------------------------------

func test_a_solo_player_walks_from_behind_a_palm_to_in_front_of_it() -> void:
	var shell := _shell()
	var body := shell.session.body(CoopSession.HOST_ID)
	var palm := _walkable_palm(shell.island)
	assert_not_null(palm, "a palm with land north and south of it")
	if palm == null:
		return
	body.global_position = palm.global_position + Vector2(0.0, -TILE)
	var body_path: NodePath = body.get_path()
	var palm_path: NodePath = palm.get_path()
	var body_parent: Node = body.get_parent()
	var palm_parent: Node = palm.get_parent()
	assert_true(DrawOrder.drawn_after(palm, body), "one tile north: the crown is drawn over the player")
	body.intent = MoveIntent.create(Vector2.DOWN, false, false, false)
	var frames: int = 0
	while body.global_position.y < palm.global_position.y + TILE and frames < WALK_FRAMES:
		await wait_physics_frames(1)
		frames += 1
	body.intent = MoveIntent.new()
	assert_gte(body.global_position.y, palm.global_position.y + TILE, "walked to one tile south in %d frames" % frames)
	assert_true(DrawOrder.drawn_after(body, palm), "one tile south: the player is drawn over the palm")
	assert_eq(body.get_path(), body_path, "the player's node did not move")
	assert_eq(palm.get_path(), palm_path, "the palm's node did not move")
	assert_same(body.get_parent(), body_parent)
	assert_same(palm.get_parent(), palm_parent)
	assert_false(body.y_sort_enabled, "the player's own root is not y-sorted")


func test_the_world_island_palms_and_session_are_y_sorted() -> void:
	var shell := _shell()
	assert_true((shell.world_viewport.get_node(^"World") as Node2D).y_sort_enabled, "World")
	assert_true(shell.island.y_sort_enabled, "the island root")
	assert_true((shell.island.get_node(^"Palms") as Node2D).y_sort_enabled, "Palms")
	assert_true(shell.session.y_sort_enabled, "the session root")
	for container: StringName in SESSION_CONTAINERS:
		assert_true((shell.session.get_node(NodePath(container)) as Node2D).y_sort_enabled, String(container))


func test_the_dev_playgrounds_are_y_sorted() -> void:
	var movement := MOVEMENT_PLAYGROUND.instantiate() as Node2D
	assert_true(movement.y_sort_enabled, "MovementPlayground")
	movement.free()
	var coop := COOP_PLAYGROUND.instantiate() as Node2D
	assert_true(coop.y_sort_enabled, "CoopPlayground")
	var session := coop.get_node(^"Session") as Node2D
	assert_true(session.y_sort_enabled, "its Session")
	for container: StringName in SESSION_CONTAINERS:
		assert_true((session.get_node(NodePath(container)) as Node2D).y_sort_enabled, String(container))
	coop.free()


func test_ground_is_under_the_player_and_overhead_text_over_a_crown() -> void:
	var shell := _shell()
	var body := shell.session.body(CoopSession.HOST_ID)
	var palm := _walkable_palm(shell.island)
	body.global_position = palm.global_position + Vector2(0.0, -TILE)
	for layer: Node in _ground_layers(shell.island):
		assert_lt(DrawOrder.absolute_z(layer as CanvasItem), 0, "ground layer %s below 0" % layer.name)
	assert_true(DrawOrder.drawn_after(body, shell.island), "the player over the island's own drawing")
	var tag := NAME_TAG_SCENE.instantiate() as NameTag
	tag.name = "NameTag"
	body.add_child(tag)
	var bubble := shell.session.show_bubble(body, "¡Ayuda!")
	assert_eq(tag.z_index, OVERHEAD_Z, "the name tag's z")
	assert_eq(bubble.z_index, OVERHEAD_Z, "the speech bubble's z")
	assert_true(DrawOrder.drawn_after(tag, palm), "a tag over a player behind a palm shows over the crown")
	assert_true(DrawOrder.drawn_after(bubble, palm), "so does a bubble")


func test_the_name_tag_and_speech_bubble_scenes_draw_at_20() -> void:
	var tag := NAME_TAG_SCENE.instantiate() as Node2D
	var bubble := SPEECH_BUBBLE_SCENE.instantiate() as Node2D
	assert_eq(tag.z_index, OVERHEAD_Z)
	assert_true(tag.z_as_relative)
	assert_eq(bubble.z_index, OVERHEAD_Z)
	assert_true(bubble.z_as_relative)
	tag.free()
	bubble.free()


func test_the_crossing_sea_and_deck_lie_under_its_riders() -> void:
	var crossing := CrossingRig.make(self, &"raft", 1, 100.0, 90.0)
	var rider := crossing.body_of(1)
	var sea := crossing.get_node_or_null(^"Sea") as CanvasItem
	var deck := crossing.get_node_or_null(^"Deck") as CanvasItem
	assert_not_null(sea, "the crossing's sea is a child of its own")
	assert_not_null(deck, "so is its deck")
	if sea == null or deck == null:
		return
	assert_eq(DrawOrder.absolute_z(sea), CROSSING_SEA_Z)
	assert_eq(DrawOrder.absolute_z(deck), CROSSING_DECK_Z)
	assert_true(DrawOrder.drawn_after(deck, sea), "the deck over the sea")
	assert_true(DrawOrder.drawn_after(rider, deck), "a rider aboard over the deck")
	crossing.throw_in(1)
	assert_true(DrawOrder.drawn_after(rider, sea), "a rider in the water over the sea")


func test_after_travel_a_player_on_the_coast_cay_is_drawn_over_its_terrain() -> void:
	var shell := _shell()
	shell.travel.travel(COAST)
	await wait_process_frames(2)
	assert_eq(shell.island.layout.id, COAST)
	var body := shell.session.body(CoopSession.HOST_ID)
	assert_true(_is_land(shell.island, _cell_of(body.global_position)), "the player stands on the cay's land")
	assert_true(DrawOrder.drawn_after(body, shell.island), "the player over the cay's own drawing")
	for layer: Node in _ground_layers(shell.island):
		assert_true(DrawOrder.drawn_after(body, layer as CanvasItem), "the player over %s" % layer.name)

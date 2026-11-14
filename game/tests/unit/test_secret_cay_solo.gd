extends GutTest
## secret-cay "The hidden cay", "Needle target", "Empty chest", "The red-band yarey hat" and "A
## lone player can live and leave" with exactly 1 player, offline, in the dev cay scene: with the
## map and the compass carried the needle points at the chest; the chest opens once and its note
## shows; the player takes the hat and no second hat exists. From an empty inventory at thirst and
## hunger 50, the player takes the knife and a rain cup, climbs a palm, drinks both through
## CoopSession.use_for and ends above 50 on both; then takes every raft input, builds the raft
## alone, launches it and leaves the island.

const SCENE: PackedScene = preload("res://scenes/dev/secret_cay_playground.tscn")
const TILE: float = 16.0
const FRAME_S: float = 1.0 / 60.0
const HAT: StringName = &"sombrero_cinta_roja"

var scene: SecretCayPlayground
var body: PlayerBody
var tuning: SecretTuning = SecretTuning.standard()


func before_each() -> void:
	WeatherManager.stop()
	scene = SCENE.instantiate() as SecretCayPlayground
	add_child_autofree(scene)
	assert_true(scene.start(SecretPlayground.parse_args(PackedStringArray(["--solo", SecretCayPlayground.WITH_PIECES]), PackedStringArray([SecretCayPlayground.WITH_PIECES]))))
	body = scene.session.body(CoopSession.HOST_ID)
	body.player_input.enabled = false
	body.auto_advance = false
	WeatherManager.stop()


func after_each() -> void:
	WeatherManager.stop()
	NetManager.leave()


func _hold(seconds: float) -> void:
	for i: int in roundi(seconds / FRAME_S):
		body.intent = MoveIntent.create(Vector2.ZERO, false, false, true)
		body.advance(FRAME_S)
	body.intent = MoveIntent.create(Vector2.ZERO, false, false, false)
	body.advance(FRAME_S)


func _lying(item_id: StringName) -> Array[WorldItem]:
	var found: Array[WorldItem] = []
	for node: Node in scene.session.pickups.get_children():
		var item := node as WorldItem
		if item != null and item.item_id == item_id and not item.is_queued_for_deletion():
			found.append(item)
	return found


# Walks onto each lying `item_id` (up to `limit`) and takes it. Returns how many were taken.
func _take(item_id: StringName, limit: int = 99) -> int:
	var taken: int = 0
	for item: WorldItem in _lying(item_id):
		if taken >= limit:
			break
		body.global_position = item.global_position
		item.interactable.use(body)
		taken += 1
	return taken


func _empty_handed() -> void:
	for slot: InventorySlot in body.inventory.slots:
		slot.clear()


func _slot_of(item_id: StringName) -> int:
	for i: int in body.inventory.slots.size():
		if body.inventory.slots[i].item_id == item_id and not body.inventory.slots[i].is_empty():
			return i
	return -1


func test_the_needle_points_at_the_chest_and_the_chest_opens_once() -> void:
	assert_eq(body.inventory.count_id(tuning.compass_item_id), 1, "--with-pieces: the compass")
	assert_eq(body.inventory.count_id(tuning.map_item_id), 1, "--with-pieces: the map")
	var needle: CompassNeedle = scene.hud.needle
	needle.set_process(false)
	needle.step(0.05)
	assert_true(needle.visible, "the needle shows")
	assert_eq(needle.target, scene.chest as Node2D, "it points at the chest")
	body.position = scene.chest.position + Vector2(-TILE, 0.0)
	_hold(1.0)
	assert_true(scene.chest.opened, "the chest opens on a 1 s hold")
	assert_true(scene.hud.note_label.visible, "the note label shows")
	assert_eq(scene.hud.note_label.shown_text(), scene.chest.entry(scene.chest.entry_id).body_es)
	await get_tree().process_frame
	assert_eq(_lying(tuning.compass_item_id).size() + _lying(&"nota_llegaste_tarde").size(), 1, "one note and nothing else beside it")
	_hold(1.0)
	await get_tree().process_frame
	assert_eq(_lying(&"nota_llegaste_tarde").size(), 1, "it opens once")
	needle.step(0.05)
	assert_true(needle.spinning, "the needle spins once the chest is open")


func test_one_hat_for_the_one_player() -> void:
	assert_eq(_lying(HAT).size(), 1, "one hat on the lean-to")
	assert_eq(_take(HAT), 1)
	await get_tree().process_frame
	assert_eq(body.inventory.count_id(HAT), 1, "the player holds it")
	assert_eq(_lying(HAT).size(), 0, "no second hat exists")
	scene.chest.receive_state(true, &"el_sombrero", false)
	await get_tree().process_frame
	assert_eq(_lying(HAT).size(), 0, "the chest never holds a hat")


func test_empty_handed_and_alone() -> void:
	_empty_handed()
	body.meters.thirst = 50.0
	body.meters.hunger = 50.0
	assert_eq(_take(&"knife"), 1, "the knife beside the embers")
	assert_eq(_take(&"rain_cup", 1), 1, "a rain cup")
	var palm := scene.island.get_node(^"Palms").get_child(0) as Palm
	body.global_position = palm.global_position + Vector2(TILE * 0.5, 0.0)
	palm.interactable.use(body)
	assert_eq(body.inventory.count_id(&"coco"), 1, "a coconut from the palm")
	assert_true(scene.session.use_for(CoopSession.HOST_ID, _slot_of(&"rain_cup"), 0, 0), "drinks the rain cup")
	assert_true(scene.session.use_for(CoopSession.HOST_ID, _slot_of(&"coco"), 0, 0), "drinks the coconut")
	assert_gt(body.meters.thirst, 50.0, "thirst above 50")
	assert_gt(body.meters.hunger, 50.0, "hunger above 50")


func test_enough_for_the_raft_and_leaving_alone() -> void:
	_empty_handed()
	var raft_recipe := load("res://resources/recipes/raft.tres") as RecipeData
	for id: StringName in raft_recipe.inputs:
		_take(id)
		assert_gte(body.inventory.count_id(id), raft_recipe.inputs[id], "enough %s on the cay" % id)
	var site := scene.session.get_node("RaftSite") as BuildSite
	body.global_position = site.global_position
	assert_true(scene.session.deposit_for(CoopSession.HOST_ID, NodePath("RaftSite")), "deposits in the raft site")
	body.crafter.advance(raft_recipe.time_s)
	var raft := scene.session.get_node_or_null("Raft") as Raft
	assert_not_null(raft, "one player built the raft alone")
	if raft == null:
		return
	raft.interactable.use(body)
	assert_true(scene.session.has_left(CoopSession.HOST_ID), "and left the island by raft")

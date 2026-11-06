extends GutTest
## island-generation "Palm climbing": a hold on a palm gives a coconut and costs energy, on the
## host, for one player alone.

const PALM_SCENE: PackedScene = preload("res://scenes/levels/palm.tscn")
const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")

var body: PlayerBody


func before_each() -> void:
	NetManager.start_solo()
	body = PLAYER_SCENE.instantiate() as PlayerBody
	add_child_autofree(body)
	body.player_input.enabled = false
	body.meters.energy = 80.0


func _palm(coconuts: int) -> Palm:
	var palm := PALM_SCENE.instantiate() as Palm
	palm.coconuts = coconuts
	var cost := EffectData.new()
	cost.meter = DataEnums.Meter.ENERGY
	cost.amount = -5.0
	palm.climb_effects = [cost] as Array[EffectData]
	add_child_autofree(palm)
	return palm


func test_climbing_gives_one_coconut_and_costs_5_energy() -> void:
	var palm := _palm(2)
	palm.interactable.interacted.emit(body)
	assert_eq(body.inventory.count_id(&"coco"), 1)
	assert_almost_eq(body.meters.energy, 75.0, 0.01)
	assert_eq(palm.coconuts, 1)


func test_an_empty_palm_gives_nothing_and_costs_nothing() -> void:
	var palm := _palm(0)
	palm.interactable.interacted.emit(body)
	assert_eq(body.inventory.count_id(&"coco"), 0)
	assert_almost_eq(body.meters.energy, 80.0, 0.01)


func test_a_full_inventory_climbs_for_nothing() -> void:
	var palm := _palm(2)
	for slot: InventorySlot in body.inventory.slots:
		slot.item_id = &"driftwood"
		slot.count = 99
	palm.interactable.interacted.emit(body)
	assert_eq(palm.coconuts, 2)
	assert_almost_eq(body.meters.energy, 80.0, 0.01)


func test_the_hold_is_2_seconds() -> void:
	assert_eq(_palm(1).interactable.hold_time_s, 2.0)

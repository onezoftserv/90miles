extends GutTest
## content-batch-3 with exactly 1 player, offline (crafting-inventory "Drinking the batch's cups
## and rum", "Which of the batch's drinks revive", "Eating the batch's foods" and "Opening canned
## food"): a solo player drinks and eats the new items through the host's use path and the meters
## move by the numbers of docs/ITEMS.md. Meters are ticked by hand in a context at rest at dawn,
## so the only drain is the 0.1/s thirst and 0.05/s hunger of survival-meters.

const SESSION_SCENE: PackedScene = preload("res://scenes/net/coop_session.tscn")
const M := DataEnums.Meter
const STEP_S: float = 0.25

var session: CoopSession
var me: PlayerBody
var rest: MeterContext


func before_each() -> void:
	NetManager.start_solo()
	session = SESSION_SCENE.instantiate() as CoopSession
	add_child_autofree(session)
	session.start()
	me = session.body(CoopSession.HOST_ID)
	me.player_input.enabled = false
	rest = MeterContext.new()
	for slot: InventorySlot in me.inventory.slots:
		slot.clear()


func after_each() -> void:
	NetManager.leave()


func _use(item_id: StringName, use_index: int = 0) -> bool:
	return session.use_for(CoopSession.HOST_ID, _slot_of(item_id), use_index, 0)


func _slot_of(item_id: StringName) -> int:
	for i: int in me.inventory.slots.size():
		if me.inventory.slots[i].item_id == item_id:
			return i
	return -1


# `seconds` of the solo player's own time, at rest.
func _run(seconds: float) -> void:
	for i: int in roundi(seconds / STEP_S):
		me.meters.tick(STEP_S, rest)


func _last_stand() -> void:
	me.meters.solo = true
	me.meters.downed_bonus_s = 30.0
	me.meters.add(M.HEALTH, -me.meters.health)
	assert_true(me.meters.last_stand, "a solo player at 0 health is in a last stand")


func test_one_offline_player_and_no_one_else() -> void:
	assert_eq(session.peer_ids().size(), 1)
	assert_not_null(me)


func test_a_solo_player_drinks_a_still_cup() -> void:
	me.meters.thirst = 40.0
	me.inventory.add(&"still_cup", 1)
	assert_true(_use(&"still_cup"))
	assert_almost_eq(me.meters.thirst, 80.0, 0.001)
	assert_eq(me.inventory.count_id(&"still_cup"), 0, "the cup is gone")


func test_a_solo_player_drinks_seawater() -> void:
	me.meters.thirst = 50.0
	me.inventory.add(&"seawater_cup", 1)
	assert_true(_use(&"seawater_cup"))
	assert_almost_eq(me.meters.thirst, 60.0, 0.001, "+10 at once")
	_run(120.0)
	# 120 s at rest drain 12; the seawater takes 30 more.
	assert_almost_eq(me.meters.thirst, 60.0 - 12.0 - 30.0, 0.01)
	_run(10.0)
	assert_almost_eq(me.meters.thirst, 18.0 - 1.0, 0.01, "the seawater loss is over")
	assert_eq(me.inventory.count_id(&"seawater_cup"), 0)


func test_one_swig_of_rum() -> void:
	me.meters.thirst = 50.0
	me.meters.morale = 50.0
	me.meters.energy = 50.0
	me.inventory.add(&"rum", 1)
	assert_true(_use(&"rum"))
	assert_almost_eq(me.meters.thirst, 55.0, 0.001)
	assert_almost_eq(me.meters.morale, 65.0, 0.001)
	assert_almost_eq(me.meters.energy, 40.0, 0.001)
	assert_eq(me.inventory.slots[_slot_of(&"rum")].uses_left, 2, "two swigs left")
	_run(59.75)
	assert_almost_eq(me.meters.thirst, 55.0 - 5.975, 0.01, "nothing but the drain before 60 s")
	_run(0.25)
	assert_almost_eq(me.meters.thirst, 55.0 - 6.0 - 10.0, 0.01, "thirst -10 at 60 s")
	_run(30.0)
	assert_almost_eq(me.meters.thirst, 39.0 - 3.0, 0.01, "once")


func test_a_well_cup_stands_up_a_solo_last_stand() -> void:
	me.meters.thirst = 30.0
	me.inventory.add(&"well_cup", 1)
	_last_stand()
	var plan := UsePlan.choose(me, _slot_of(&"well_cup"), session)
	assert_eq(plan.reason, ItemUser.Reason.OK)
	assert_true(session.use_for(CoopSession.HOST_ID, _slot_of(&"well_cup"), plan.use_index, 0))
	assert_false(me.meters.last_stand)
	assert_almost_eq(me.meters.health, 30.0, 0.001)
	assert_almost_eq(me.meters.thirst, 60.0, 0.001)
	assert_eq(me.inventory.count_id(&"well_cup"), 0)


func test_rum_and_seawater_never_stand_up_a_last_stand() -> void:
	me.inventory.add(&"rum", 1)
	me.inventory.add(&"seawater_cup", 1)
	_last_stand()
	for id: StringName in [&"rum", &"seawater_cup"]:
		assert_eq(UsePlan.choose(me, _slot_of(id), session).reason, ItemUser.Reason.NO_USE, "%s has no reviving use" % id)
		assert_false(_use(id), "%s is refused in a last stand" % id)
	assert_true(me.meters.last_stand, "still down")
	assert_eq(me.inventory.count_id(&"rum"), 1)
	assert_eq(me.inventory.count_id(&"seawater_cup"), 1)


func test_a_solo_player_eats_cooked_fish() -> void:
	me.meters.hunger = 40.0
	me.meters.energy = 40.0
	me.inventory.add(&"fish_cooked", 2)
	assert_true(_use(&"fish_cooked"))
	assert_almost_eq(me.meters.hunger, 75.0, 0.001)
	assert_almost_eq(me.meters.energy, 50.0, 0.001, "a meal gives +10 energy")
	assert_eq(me.inventory.count_id(&"fish_cooked"), 1)


func test_canned_food_needs_an_opener() -> void:
	me.meters.hunger = 40.0
	me.meters.energy = 40.0
	me.inventory.add(&"canned_food", 1)
	assert_false(_use(&"canned_food"), "no opener")
	assert_eq(me.inventory.count_id(&"canned_food"), 1)
	assert_almost_eq(me.meters.hunger, 40.0, 0.001)
	me.inventory.add(&"knife", 1)
	var knife_slot: int = _slot_of(&"knife")
	var uses_before: int = me.inventory.slots[knife_slot].uses_left
	assert_true(_use(&"canned_food"))
	assert_almost_eq(me.meters.hunger, 70.0, 0.001)
	assert_almost_eq(me.meters.energy, 50.0, 0.001)
	assert_eq(me.inventory.count_id(&"canned_food"), 0)
	assert_eq(me.inventory.slots[knife_slot].uses_left, uses_before - 1, "the can cost one knife use")


func test_a_solo_player_eats_a_guanabana() -> void:
	me.meters.hunger = 50.0
	me.meters.thirst = 50.0
	me.meters.morale = 50.0
	me.meters.energy = 50.0
	me.inventory.add(&"guanabana", 1)
	assert_true(_use(&"guanabana"))
	assert_almost_eq(me.meters.hunger, 75.0, 0.001)
	assert_almost_eq(me.meters.thirst, 65.0, 0.001)
	assert_almost_eq(me.meters.morale, 60.0, 0.001)
	assert_almost_eq(me.meters.energy, 60.0, 0.001)


func test_wild_tobacco_needs_a_lit_fire() -> void:
	me.meters.morale = 50.0
	me.inventory.add(&"tabaco_silvestre", 1)
	assert_false(_use(&"tabaco_silvestre"), "no fire within 2 tiles")
	assert_eq(me.inventory.count_id(&"tabaco_silvestre"), 1)
	assert_almost_eq(me.meters.morale, 50.0, 0.001)

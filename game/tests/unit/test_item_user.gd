extends GutTest
## crafting-inventory "Using items" and "Fresh-water revives" with the survival-meters numbers.

const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")
const M := DataEnums.Meter

var user: PlayerBody
var mate: PlayerBody


func before_each() -> void:
	user = _body()
	mate = _body()


func _body() -> PlayerBody:
	var body := PLAYER_SCENE.instantiate() as PlayerBody
	add_child_autofree(body)
	return body


func _down(body: PlayerBody) -> void:
	body.meters.solo = false
	body.meters.add(M.HEALTH, -body.meters.health)
	assert_true(body.meters.downed)


func test_opening_a_coconut_needs_a_blade() -> void:
	user.meters.thirst = 50.0
	user.inventory.add(&"coco", 1)
	assert_false(ItemUser.use(user, 0, 0))
	assert_eq(user.inventory.count_id(&"coco"), 1)
	assert_eq(user.meters.thirst, 50.0)


func test_drinking_a_coconut_with_a_knife_is_a_meal() -> void:
	user.meters.thirst = 50.0
	user.meters.hunger = 50.0
	user.meters.energy = 50.0
	user.inventory.add(&"knife", 1)
	user.inventory.add(&"coco", 1)
	assert_true(ItemUser.use(user, 1, 0))
	assert_almost_eq(user.meters.thirst, 65.0, 0.001)
	assert_almost_eq(user.meters.hunger, 55.0, 0.001)
	assert_almost_eq(user.meters.energy, 60.0, 0.001, "a meal gives +10 energy")
	assert_eq(user.inventory.count_id(&"coco"), 0)
	assert_eq(user.inventory.slots[0].uses_left, 39)


func test_drinking_a_rain_cup_restores_25_thirst() -> void:
	user.meters.thirst = 50.0
	user.inventory.add(&"rain_cup", 1)
	assert_true(ItemUser.use(user, 0, 0))
	assert_almost_eq(user.meters.thirst, 75.0, 0.001)
	assert_eq(user.inventory.count_id(&"rain_cup"), 0)


func test_rain_cup_revives_a_downed_teammate_at_30() -> void:
	_down(mate)
	mate.meters.thirst = 50.0
	user.inventory.add(&"rain_cup", 1)
	assert_true(ItemUser.use(user, 0, 1, mate))
	assert_false(mate.meters.downed)
	assert_almost_eq(mate.meters.health, 30.0, 0.001)
	assert_almost_eq(mate.meters.thirst, 75.0, 0.001)
	assert_eq(user.inventory.count_id(&"rain_cup"), 0)


func test_a_revive_use_on_someone_standing_spends_nothing() -> void:
	user.inventory.add(&"rain_cup", 1)
	assert_false(ItemUser.use(user, 0, 1, mate))
	assert_eq(user.inventory.count_id(&"rain_cup"), 1)


func test_seawater_never_revives() -> void:
	var sea := ItemData.new()
	sea.id = &"seawater_fixture"
	sea.durability = 1
	var use := ItemUseData.new()
	use.action = ItemUseData.UseAction.DRINK
	use.can_target_others = true
	var drain := EffectData.new()
	drain.meter = M.THIRST
	drain.amount = -5.0
	drain.target = EffectData.Target.USE_TARGET
	use.effects = [drain] as Array[EffectData]
	sea.uses = [use] as Array[ItemUseData]
	user.inventory.register(sea)
	_down(mate)
	user.inventory.add(&"seawater_fixture", 1)
	user.inventory.add(&"rain_cup", 1)
	ItemUser.use(user, 0, 0, mate)
	assert_true(mate.meters.downed, "seawater leaves them down")
	assert_true(ItemUser.use(user, 1, 1, mate))
	assert_false(mate.meters.downed, "the rain cup stands them up")


func test_solo_last_stand_rain_cup_on_self() -> void:
	user.meters.solo = true
	user.meters.downed_bonus_s = 15.0
	user.meters.add(M.HEALTH, -user.meters.health)
	assert_true(user.meters.last_stand)
	user.inventory.add(&"rain_cup", 1)
	assert_true(ItemUser.use(user, 0, 1))
	assert_false(user.meters.last_stand)
	assert_almost_eq(user.meters.health, 30.0, 0.001)

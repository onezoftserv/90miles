extends GutTest
## creature-perch-ride "Carried-item immunity": a creature with an ITEM_CARRIED → NEGATE counter
## takes nothing from a player who carries that item: an island gull's swoop and the galleguito's
## theft roll alike. One offline player who carries a fixture feather and holds 2 food items.

const FIXTURES: String = "res://tests/fixtures/content"
const FEATHER: StringName = &"pluma_prueba"
const STEP_S: float = 0.1


func before_each() -> void:
	NetManager.start_solo()
	WeatherManager.stop()
	WeatherManager.sky.start_at(0.0)


func after_each() -> void:
	NetManager.leave()


static func _feather() -> ItemData:
	var item := ItemData.new()
	item.id = FEATHER
	item.name_es = "Pluma de prueba"
	item.name_en = "Test feather"
	item.tags = [DataEnums.ItemTag.KEEPSAKE] as Array[DataEnums.ItemTag]
	return item


static func _with_feather_counter(data: CreatureData) -> CreatureData:
	var copy := data.duplicate() as CreatureData
	var counter := CreatureCounterData.new()
	counter.trigger = CreatureCounterData.Trigger.ITEM_CARRIED
	counter.item_ids = [FEATHER] as Array[StringName]
	counter.response = CreatureCounterData.Response.NEGATE
	var counters: Array[CreatureCounterData] = copy.counters.duplicate()
	counters.append(counter)
	copy.counters = counters
	return copy


static func _carry_feather_and_food(body: PlayerBody) -> void:
	body.inventory.register(_feather())
	body.inventory.add(FEATHER, 1)
	body.inventory.add(&"coco", 2)


func test_an_island_gull_with_the_counter_takes_nothing_from_the_holder() -> void:
	var rig := CreatureRig.make(self)
	rig.world.phase = DataEnums.DayPhase.DAY
	var body := rig.player(Vector2i(4, 9))
	_carry_feather_and_food(body)
	var gull := rig.creature(&"", Vector2i(4, 5), _with_feather_counter(GameState.content.get_entry(&"creatures", &"seagull") as CreatureData))
	rig.run(10.0)
	assert_eq(body.inventory.count_tag(DataEnums.ItemTag.FOOD), 2, "still 2 food items")
	assert_false(gull.brain.history.has(&"SWOOP"), "it never swooped")


func test_without_the_feather_the_same_gull_still_steals() -> void:
	var rig := CreatureRig.make(self)
	rig.world.phase = DataEnums.DayPhase.DAY
	var body := rig.player(Vector2i(4, 9))
	body.inventory.add(&"coco", 2)
	rig.creature(&"", Vector2i(4, 5), _with_feather_counter(GameState.content.get_entry(&"creatures", &"seagull") as CreatureData))
	rig.run(10.0)
	assert_eq(body.inventory.count_tag(DataEnums.ItemTag.FOOD), 1, "the counter only spares the holder")


func test_the_galleguitos_theft_roll_takes_nothing_from_the_holder() -> void:
	var session := CrossingRig.make_session(self, 1)
	var catalog := ContentCatalog.new(FIXTURES)
	session.creature_catalog = catalog
	var crossing := CrossingRig.launch_on(session, &"raft", [1] as Array[int], 100.0, 200.0)
	var body := crossing.body_of(1)
	_carry_feather_and_food(body)
	var riders := CrossingCreatures.attach(crossing, DataEnums.ChainFamily.FINAL, DataEnums.DistanceBand.COAST)
	var gull := riders.creatures()[0]
	var sure := _with_feather_counter(gull.data)
	sure.steal_chance = 1.0
	gull.data = sure
	for i: int in roundi(140.0 / STEP_S):
		crossing.advance(STEP_S)
		gull.advance(STEP_S)
	assert_eq(gull.state_name(), &"PERCH", "it rode the whole time")
	assert_eq(body.inventory.count_tag(DataEnums.ItemTag.FOOD), 2, "still 2 food items after two sure rolls")

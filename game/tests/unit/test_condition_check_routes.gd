extends GutTest
## escape-routes "Swimmers' condition": the condition kinds the routes read.

const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")


func _body() -> PlayerBody:
	var body := PLAYER_SCENE.instantiate() as PlayerBody
	add_child_autofree(body)
	return body


func _condition(kind: ConditionData.Kind) -> ConditionData:
	var condition := ConditionData.new()
	condition.kind = kind
	return condition


func test_energy_at_least_100() -> void:
	var body := _body()
	var condition := _condition(ConditionData.Kind.METER_AT_LEAST)
	condition.meter = DataEnums.Meter.ENERGY
	condition.amount = 100.0
	body.meters.energy = 100.0
	assert_true(ConditionCheck.holds(condition, body))
	body.meters.energy = 99.0
	assert_false(ConditionCheck.holds(condition, body))


func test_bleeding_status_follows_set_status() -> void:
	var body := _body()
	var condition := _condition(ConditionData.Kind.STATUS_ACTIVE)
	condition.status = DataEnums.Status.BLEEDING
	condition.negate = true
	assert_true(ConditionCheck.holds(condition, body), "not bleeding")
	body.meters.set_status(DataEnums.Status.BLEEDING, true)
	assert_true(body.meters.has_status(DataEnums.Status.BLEEDING))
	assert_false(ConditionCheck.holds(condition, body))
	body.meters.set_status(DataEnums.Status.BLEEDING, false)
	assert_true(ConditionCheck.holds(condition, body))


func test_clear_weather_is_calm_and_not_squall() -> void:
	var body := _body()
	var condition := _condition(ConditionData.Kind.WEATHER_IS_CLEAR)
	body.climate.weather_id = &"calm"
	assert_true(ConditionCheck.holds(condition, body))
	body.climate.weather_id = &"squall"
	assert_false(ConditionCheck.holds(condition, body))


func test_structure_built_needs_a_built_structure_of_that_recipe() -> void:
	var body := _body()
	var condition := _condition(ConditionData.Kind.STRUCTURE_BUILT)
	condition.ref_id = &"raft"
	assert_false(ConditionCheck.holds(condition, body))
	var built := Node2D.new()
	built.set_meta(&"recipe_id", &"raft")
	built.add_to_group(PlayerBody.STRUCTURE_GROUP)
	add_child_autofree(built)
	assert_true(ConditionCheck.holds(condition, body))

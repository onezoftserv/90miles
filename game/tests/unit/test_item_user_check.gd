extends GutTest
## inventory-hud "Refused uses" (design D5): the two checks the host and the HUD share.
## `ItemUser.check` is `ItemUser.use`'s own checks in their order, returning why a use would be
## refused; `UsePlan.actor_reason` is `CoopSession.use_for`'s checks of the acting player (down,
## at sea, out of reach). Both are pure: they change nothing.

const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")
const M := DataEnums.Meter
const R := ItemUser.Reason
const TILE: float = 16.0

var user: PlayerBody
var mate: PlayerBody


func before_each() -> void:
	user = _body()
	mate = _body()


func _body() -> PlayerBody:
	var body := PLAYER_SCENE.instantiate() as PlayerBody
	add_child_autofree(body)
	return body


# Downed in co-op: no last stand, the player lies still.
func _down(body: PlayerBody) -> void:
	body.meters.solo = false
	body.meters.add(M.HEALTH, -body.meters.health)
	assert_true(body.meters.downed)


func _last_stand(body: PlayerBody) -> void:
	body.meters.solo = true
	body.meters.downed_bonus_s = 15.0
	body.meters.add(M.HEALTH, -body.meters.health)
	assert_true(body.meters.last_stand)


# --- ItemUser.check ---------------------------------------------------------------------------

func test_an_empty_slot_is_empty() -> void:
	assert_eq(ItemUser.check(user, 0, 0), R.EMPTY)
	assert_eq(ItemUser.check(user, -1, 0), R.EMPTY, "no such slot")
	assert_eq(ItemUser.check(user, 99, 0), R.EMPTY)


func test_driftwood_has_no_use() -> void:
	user.inventory.add(&"driftwood", 1)
	assert_eq(ItemUser.check(user, 0, 0), R.NO_USE)
	user.inventory.add(&"rain_cup", 1)
	assert_eq(ItemUser.check(user, 1, 2), R.NO_USE, "the rain cup has two uses, not three")
	assert_eq(ItemUser.check(user, 1, -1), R.NO_USE)


func test_a_self_only_use_cannot_go_on_a_teammate() -> void:
	user.inventory.add(&"rain_cup", 1)
	assert_eq(ItemUser.check(user, 0, 0, mate), R.NOT_TARGETABLE, "the first use is only for yourself")
	assert_eq(ItemUser.check(user, 0, 0, user), R.OK, "yourself as the target is yourself")


func test_a_dead_teammate_is_past_helping() -> void:
	_down(mate)
	mate.meters.dead = true
	user.inventory.add(&"rain_cup", 1)
	assert_eq(ItemUser.check(user, 0, 1, mate), R.TARGET_DEAD)


func test_a_reviving_use_needs_someone_down() -> void:
	user.inventory.add(&"rain_cup", 1)
	assert_eq(ItemUser.check(user, 0, 1, mate), R.NOT_DOWNED_TARGET, "the teammate is standing")
	_down(mate)
	assert_eq(ItemUser.check(user, 0, 1, mate), R.OK)


func test_a_coconut_without_a_knife_names_the_missing_tool() -> void:
	user.inventory.add(&"coco", 1)
	assert_eq(ItemUser.check(user, 0, 0), R.CONDITION)
	var missing := ItemUser.failed_condition(user, 0, 0)
	assert_not_null(missing)
	assert_eq(missing.kind, ConditionData.Kind.HAS_CAPABILITY)
	assert_eq(missing.capability, DataEnums.Capability.OPEN_COCONUT)
	user.inventory.add(&"knife", 1)
	assert_eq(ItemUser.check(user, 0, 0), R.OK)
	assert_null(ItemUser.failed_condition(user, 0, 0), "nothing missing once the knife is in")


func test_a_rain_cup_is_fine() -> void:
	user.inventory.add(&"rain_cup", 1)
	assert_eq(ItemUser.check(user, 0, 0), R.OK)


func test_checking_changes_nothing() -> void:
	user.meters.thirst = 50.0
	user.inventory.add(&"knife", 1)
	user.inventory.add(&"coco", 1)
	var before: Array = user.inventory.to_net()
	assert_eq(ItemUser.check(user, 1, 0), R.OK)
	assert_eq(user.inventory.to_net(), before)
	assert_eq(user.meters.thirst, 50.0)


func test_use_refuses_whatever_check_refuses() -> void:
	user.inventory.add(&"coco", 1)
	user.inventory.add(&"driftwood", 1)
	user.inventory.add(&"rain_cup", 1)
	for case: Array in [[2, 0, mate], [2, 1, mate], [0, 0, null], [1, 0, null], [5, 0, null]]:
		var target := case[2] as PlayerBody
		assert_ne(ItemUser.check(user, case[0], case[1], target), R.OK)
		assert_false(ItemUser.use(user, case[0], case[1], target), "slot %d use %d" % [case[0], case[1]])
	assert_eq(user.inventory.count_id(&"coco") + user.inventory.count_id(&"rain_cup"), 2, "nothing spent")


# --- UsePlan.actor_reason ----------------------------------------------------------------------

func test_a_player_on_their_feet_may_act() -> void:
	user.inventory.add(&"rain_cup", 1)
	assert_eq(UsePlan.actor_reason(user, false, 0, 0), R.OK)


func test_a_downed_co_op_player_cannot_act() -> void:
	user.inventory.add(&"rain_cup", 1)
	_down(user)
	assert_eq(UsePlan.actor_reason(user, false, 0, 0), R.DOWN)
	assert_eq(UsePlan.actor_reason(user, false, 0, 1), R.DOWN, "not even to revive: co-op has no last stand")


func test_a_dead_player_cannot_act() -> void:
	user.inventory.add(&"rain_cup", 1)
	user.meters.dead = true
	assert_eq(UsePlan.actor_reason(user, false, 0, 0), R.DOWN)


func test_a_last_stand_may_only_stand_themself_up() -> void:
	user.inventory.add(&"coco", 1)
	user.inventory.add(&"rain_cup", 1)
	_down(mate)
	mate.global_position = user.global_position + Vector2(8.0, 0.0)
	_last_stand(user)
	assert_eq(UsePlan.actor_reason(user, false, 0, 0), R.DOWN, "drinking a coconut is not reviving")
	assert_eq(UsePlan.actor_reason(user, false, 1, 0), R.DOWN, "the rain cup's first use does not revive")
	assert_eq(UsePlan.actor_reason(user, false, 1, 1, mate), R.DOWN, "nor may they revive someone else")
	assert_eq(UsePlan.actor_reason(user, false, 1, 1), R.OK, "the cup's reviving use on themself")
	assert_eq(UsePlan.actor_reason(user, false, 1, 1, user), R.OK)


func test_a_departed_player_is_at_sea() -> void:
	user.inventory.add(&"rain_cup", 1)
	assert_eq(UsePlan.actor_reason(user, true, 0, 0), R.AT_SEA)


func test_a_target_two_tiles_away_is_out_of_reach() -> void:
	user.inventory.add(&"rain_cup", 1)
	_down(mate)
	mate.global_position = user.global_position + Vector2(2.0 * TILE, 0.0)
	assert_eq(UsePlan.actor_reason(user, false, 0, 1, mate), R.OUT_OF_REACH)
	mate.global_position = user.global_position + Vector2(InteractionPicker.REACH_PX + PlayerBody.REACH_SLACK_PX, 0.0)
	assert_eq(UsePlan.actor_reason(user, false, 0, 1, mate), R.OK, "reach and its slack, as the host's hold")

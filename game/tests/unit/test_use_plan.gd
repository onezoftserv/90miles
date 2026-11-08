extends GutTest
## inventory-hud "Which use the button picks" (design D5): the item's first use on the player
## themself, except the first reviving use in a solo last stand, and the reviving use that can
## target others on the nearest downed (not dead) teammate within 1 tile in co-op. A use that is
## needed but missing reads as no use.

const SESSION_SCENE: PackedScene = preload("res://scenes/net/coop_session.tscn")
const R := ItemUser.Reason
const HERE: Vector2 = Vector2(100.0, 100.0)


func before_each() -> void:
	NetManager.start_solo()


func _session(extra: Array[int] = []) -> CoopSession:
	var session := SESSION_SCENE.instantiate() as CoopSession
	add_child_autofree(session)
	session.start()
	for peer_id: int in extra:
		session._add_player(peer_id)
		session.roster[peer_id] = "Papo"
	for peer_id: int in session.peer_ids():
		session.body(peer_id).player_input.enabled = false
	session.body(CoopSession.HOST_ID).global_position = HERE
	return session


func _downed_at(session: CoopSession, peer_id: int, offset_px: Vector2) -> PlayerBody:
	var teammate := session.body(peer_id)
	teammate.global_position = HERE + offset_px
	teammate.meters.downed = true
	return teammate


func test_the_first_use_goes_on_yourself() -> void:
	var session := _session()
	var me := session.body(1)
	me.inventory.add(&"coco", 1)
	var plan := UsePlan.choose(me, 0, session)
	assert_eq(plan.reason, R.OK)
	assert_eq(plan.use_index, 0)
	assert_null(plan.target)
	assert_eq(plan.target_peer, 0)


func test_a_solo_last_stand_takes_the_first_use_that_revives() -> void:
	var session := _session()
	var me := session.body(1)
	me.inventory.add(&"rain_cup", 1)
	me.meters.last_stand = true
	var plan := UsePlan.choose(me, 0, session)
	assert_eq(plan.reason, R.OK)
	assert_eq(plan.use_index, 1, "the rain cup's second use stands someone up")
	assert_null(plan.target, "on themself")


func test_a_downed_teammate_in_reach_gets_the_reviving_use() -> void:
	var session := _session([7] as Array[int])
	var me := session.body(1)
	me.inventory.add(&"rain_cup", 1)
	var papo := _downed_at(session, 7, Vector2(8.0, 0.0))
	var plan := UsePlan.choose(me, 0, session)
	assert_eq(plan.reason, R.OK)
	assert_eq(plan.use_index, 1)
	assert_same(plan.target, papo)
	assert_eq(plan.target_peer, 7)


func test_the_nearest_downed_teammate_wins() -> void:
	var session := _session([7, 8] as Array[int])
	var me := session.body(1)
	me.inventory.add(&"rain_cup", 1)
	_downed_at(session, 7, Vector2(12.0, 0.0))
	var nearer := _downed_at(session, 8, Vector2(0.0, -6.0))
	var plan := UsePlan.choose(me, 0, session)
	assert_same(plan.target, nearer)
	assert_eq(plan.target_peer, 8)


func test_the_target_peer_comes_from_the_session_not_the_node_name() -> void:
	var session := _session([7] as Array[int])
	var me := session.body(1)
	me.inventory.add(&"rain_cup", 1)
	var papo := _downed_at(session, 7, Vector2(8.0, 0.0))
	session._rebind_body(7, 9)
	var plan := UsePlan.choose(me, 0, session)
	assert_same(plan.target, papo)
	assert_eq(plan.target_peer, 9, "a reclaimed body keeps its old node name")


func test_a_dead_teammate_is_skipped() -> void:
	var session := _session([7, 8] as Array[int])
	var me := session.body(1)
	me.inventory.add(&"rain_cup", 1)
	var dead := _downed_at(session, 7, Vector2(8.0, 0.0))
	dead.meters.dead = true
	_downed_at(session, 8, Vector2(48.0, 0.0))
	var plan := UsePlan.choose(me, 0, session)
	assert_eq(plan.use_index, 0, "the player drinks it themself")
	assert_null(plan.target)
	assert_eq(plan.target_peer, 0)


func test_with_nobody_down_in_reach_the_player_uses_it_themself() -> void:
	var session := _session([7, 8] as Array[int])
	var me := session.body(1)
	me.inventory.add(&"rain_cup", 1)
	_downed_at(session, 7, Vector2(32.0, 0.0))
	session.body(8).global_position = HERE + Vector2(4.0, 0.0)
	var plan := UsePlan.choose(me, 0, session)
	assert_eq(plan.use_index, 0)
	assert_null(plan.target, "a standing teammate is not revived")


func test_an_item_without_the_use_it_needs_has_no_use() -> void:
	var session := _session()
	var me := session.body(1)
	me.inventory.add(&"driftwood", 1)
	me.inventory.add(&"coco", 1)
	var wood := UsePlan.choose(me, 0, session)
	assert_eq(wood.reason, R.NO_USE)
	assert_eq(wood.use_index, -1)
	me.meters.last_stand = true
	assert_eq(UsePlan.choose(me, 1, session).reason, R.NO_USE, "a coconut cannot stand you up")


func test_an_empty_slot_is_empty() -> void:
	var session := _session()
	var plan := UsePlan.choose(session.body(1), 0, session)
	assert_eq(plan.reason, R.EMPTY)
	assert_eq(plan.use_index, -1)
	assert_eq(UsePlan.choose(session.body(1), 99, session).reason, R.EMPTY, "no such slot")


func test_without_a_session_there_are_no_teammates() -> void:
	var body := (preload("res://scenes/player/player.tscn") as PackedScene).instantiate() as PlayerBody
	add_child_autofree(body)
	body.inventory.add(&"rain_cup", 1)
	var plan := UsePlan.choose(body, 0)
	assert_eq(plan.use_index, 0)
	assert_null(plan.target)

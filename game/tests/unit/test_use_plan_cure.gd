extends GutTest
## inventory-hud "Who a cure goes to" (bleeding-and-sabila design D5): a use that can go on others
## and cures a status goes on the holder if they have one it cures, else on the nearest standing
## teammate within 1 tile who has one, else on the holder. Revives keep their priority, and a use
## that cures nothing never goes to a standing teammate. Solo has no teammate.

const SESSION_SCENE: PackedScene = preload("res://scenes/net/coop_session.tscn")
const R := ItemUser.Reason
const ST := DataEnums.Status
const HERE: Vector2 = Vector2(100.0, 100.0)


func before_each() -> void:
	NetManager.start_solo()


func after_each() -> void:
	NetManager.leave()


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


func _bleeding_at(session: CoopSession, peer_id: int, offset_px: Vector2) -> PlayerBody:
	var teammate := session.body(peer_id)
	teammate.global_position = HERE + offset_px
	teammate.meters.set_status(ST.BLEEDING, true)
	return teammate


func _holder(session: CoopSession, item_id: StringName = &"aloe") -> PlayerBody:
	var me := session.body(CoopSession.HOST_ID)
	me.inventory.add(item_id, 1)
	return me


func test_sabila_goes_to_a_bleeding_teammate_in_reach() -> void:
	var session := _session([7] as Array[int])
	var me := _holder(session)
	var papo := _bleeding_at(session, 7, Vector2(8.0, 0.0))
	var plan := UsePlan.choose(me, 0, session)
	assert_eq(plan.reason, R.OK)
	assert_eq(plan.use_index, 0)
	assert_same(plan.target, papo)
	assert_eq(plan.target_peer, 7)
	assert_eq(InventoryStrip.item_line_text("Sábila", "F", "Untar", session.player_name(7)), "Sábila · [F] Untar: Papo")


func test_the_holder_who_bleeds_goes_first() -> void:
	var session := _session([7] as Array[int])
	var me := _holder(session)
	me.meters.set_status(ST.BLEEDING, true)
	_bleeding_at(session, 7, Vector2(8.0, 0.0))
	var plan := UsePlan.choose(me, 0, session)
	assert_null(plan.target)
	assert_eq(plan.target_peer, 0)


func test_a_bleeding_teammate_beyond_reach_is_not_aimed_at() -> void:
	var session := _session([7] as Array[int])
	var me := _holder(session)
	_bleeding_at(session, 7, Vector2(48.0, 0.0))
	assert_null(UsePlan.choose(me, 0, session).target)


func test_the_nearest_bleeding_teammate_wins() -> void:
	var session := _session([7, 8] as Array[int])
	var me := _holder(session)
	_bleeding_at(session, 7, Vector2(12.0, 0.0))
	var nearer := _bleeding_at(session, 8, Vector2(0.0, -6.0))
	var plan := UsePlan.choose(me, 0, session)
	assert_same(plan.target, nearer)
	assert_eq(plan.target_peer, 8)


func test_a_downed_dead_or_waiting_teammate_is_no_cure_target() -> void:
	var session := _session([7, 8, 9] as Array[int])
	var me := _holder(session)
	_bleeding_at(session, 7, Vector2(8.0, 0.0)).meters.downed = true
	_bleeding_at(session, 8, Vector2(0.0, 8.0)).meters.dead = true
	_bleeding_at(session, 9, Vector2(-8.0, 0.0)).left_island = true
	assert_null(UsePlan.choose(me, 0, session).target)


func test_a_revive_still_wins_over_a_cure() -> void:
	var session := _session([7, 8] as Array[int])
	var me := _holder(session, &"rain_cup")
	var downed := session.body(7)
	downed.global_position = HERE + Vector2(8.0, 0.0)
	downed.meters.downed = true
	_bleeding_at(session, 8, Vector2(0.0, 8.0))
	var plan := UsePlan.choose(me, 0, session)
	assert_same(plan.target, downed)
	assert_eq(plan.use_index, 1, "the cup's reviving use")


func test_a_cup_never_goes_to_a_standing_teammate() -> void:
	var session := _session([7] as Array[int])
	var me := _holder(session, &"rain_cup")
	me.meters.thirst = 50.0
	var papo := session.body(7)
	papo.global_position = HERE + Vector2(8.0, 0.0)
	papo.meters.thirst = 10.0
	papo.meters.set_status(ST.BLEEDING, true)
	var plan := UsePlan.choose(me, 0, session)
	assert_null(plan.target, "a cup cures nothing")
	assert_eq(plan.use_index, 0)


func test_solo_sabila_goes_on_the_lone_player() -> void:
	var session := _session()
	var me := _holder(session)
	me.meters.set_status(ST.BLEEDING, true)
	assert_null(UsePlan.choose(me, 0, session).target)
	assert_null(UsePlan.choose(me, 0, null).target, "no session, no teammate")


func test_the_host_treats_the_teammate_the_plan_names() -> void:
	var session := _session([7] as Array[int])
	var me := _holder(session)
	var papo := _bleeding_at(session, 7, Vector2(8.0, 0.0))
	papo.meters.health = 60.0
	var plan := UsePlan.choose(me, 0, session)
	assert_true(session.use_for(CoopSession.HOST_ID, 0, plan.use_index, plan.target_peer))
	assert_false(papo.meters.has_status(ST.BLEEDING))
	assert_eq(papo.meters.health, 65.0)

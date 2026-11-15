extends GutTest
## coop-networking "Rematch with the same party", "Rematch is the host's call" and "Rematch message
## order"; endings-progression "Rematch from a co-op summary" and "A fresh run starts clean"; ui-shell
## "Screen flow"; art-pass "Look slots in a rematch". Real shells for a host and clients over ENet on
## localhost (ShellHarness): the host's "Otra vez" takes every connected client to a new lobby on the
## same connection, each with the same name, player id and look slot, a new run seed and the new
## island whole. GUT fails any case that logs an engine error.

const WAITING_NOTE: String = "Esperando al anfitrión…"
const HOST_LEFT_NOTE: String = "El anfitrión cerró la partida."
const OLD_SEED: int = 101
const NEW_SEED: int = 202

var shells: ShellHarness
var _seeds: Array[int] = []


func before_each() -> void:
	_seeds = [OLD_SEED, NEW_SEED, 303]
	NetManager.start_solo()
	WeatherManager.stop()
	shells = ShellHarness.new(self)


func after_each() -> void:
	shells.teardown()
	WeatherManager.stop()
	get_tree().paused = false
	NetManager.leave()


func _start_host() -> GameShell:
	return shells.add_host("Yuni", func() -> int: return _seeds.pop_front())


# A host and Papo in a run.
func _pair_in_run() -> Array[GameShell]:
	var host := _start_host()
	var papo := await shells.join_lobby("Papo")
	assert_not_null(papo, "Papo reached the lobby")
	if papo == null:
		return []
	assert_true(await shells.begin_run(), "both in the run")
	return [host, papo]


func _summary_of(shell: GameShell) -> SummaryScreen:
	return shell.screen as SummaryScreen


func _lobby_of(shell: GameShell) -> LobbyScreen:
	return shell.screen as LobbyScreen


func _pick_otra_vez(host: GameShell) -> void:
	_summary_of(host).restart_button.pressed.emit()


# The client's lobby lists exactly `rows`, from a session that is not `old_session_id`.
func _in_new_lobby(shell: GameShell, old_session_id: int, rows: Array[String]) -> Callable:
	return func() -> bool:
		if shell.flow != GameShell.Flow.LOBBY or shell.session == null or shell.session.get_instance_id() == old_session_id:
			return false
		return _lobby_of(shell) != null and _lobby_of(shell).rows() == rows


func test_two_players_again() -> void:
	var pair := await _pair_in_run()
	if pair.is_empty():
		return
	var host := pair[0]
	var papo := pair[1]
	var papo_id: int = shells.peer_id(papo)
	var papo_peer: MultiplayerPeer = shells.peer_of(papo)
	assert_true(await shells.end_run())
	var host_summary := _summary_of(host)
	assert_true(host_summary.restart_button.visible, "the host's summary offers Otra vez")
	assert_eq(host_summary.restart_button.text, "Otra vez")
	# Its focus is checked in test_run_restart.gd: here both shells share one window, so one focus.
	assert_true(host_summary.home_button.visible)
	var papo_summary := _summary_of(papo)
	assert_false(papo_summary.restart_button.visible, "a client's does not")
	assert_true(papo_summary.home_button.visible)
	assert_true(papo_summary.note.visible)
	assert_eq(papo_summary.note.text, WAITING_NOTE)
	var old_papo_session: int = papo.session.get_instance_id()
	var old_host_session: CoopSession = host.session
	_pick_otra_vez(host)
	assert_eq(host.flow, GameShell.Flow.LOBBY, "the host's lobby shows at once")
	assert_true(_lobby_of(host).start_button.visible, "with Empezar viaje")
	assert_false(is_instance_valid(old_host_session), "the host's old run is gone")
	var rows: Array[String] = ["Yuni (anfitrión)", "Papo"]
	assert_true(await shells.wait(_in_new_lobby(papo, old_papo_session, rows)), "Papo's new lobby lists both")
	assert_true(await shells.wait(func() -> bool: return _lobby_of(host).rows() == rows), "so does the host's")
	assert_same(shells.peer_of(papo), papo_peer, "Papo's client opened no new connection")
	assert_eq(shells.peer_id(papo), papo_id, "and kept its peer id")
	assert_eq(host.session._identities.peer_for(papo.settings.identity.id), papo_id, "the host knows Papo by the same player id")
	assert_eq(host.session.phase, CoopSession.Phase.LOBBY)
	assert_eq(host.session.peer_ids().size(), 0, "nobody spawns in the lobby")


func test_the_new_island_is_whole_and_clean() -> void:
	var pair := await _pair_in_run()
	if pair.is_empty():
		return
	var host := pair[0]
	var papo := pair[1]
	var papo_id: int = shells.peer_id(papo)
	var host_look: int = host.session.body(1).look_slot
	var papo_look: int = host.session.body(papo_id).look_slot
	assert_eq(papo.session.world_state.get("run_seed"), OLD_SEED)
	assert_true(await shells.end_run())
	var old_papo_session: int = papo.session.get_instance_id()
	_pick_otra_vez(host)
	var rows: Array[String] = ["Yuni (anfitrión)", "Papo"]
	assert_true(await shells.wait(_in_new_lobby(papo, old_papo_session, rows)))
	assert_true(await shells.begin_run(), "the new run starts on both")
	await wait_physics_frames(10)
	var whole := func() -> bool:
		return papo.session.pickups.get_child_count() == host.session.pickups.get_child_count() \
			and papo.session.entities.get_child_count() == host.session.entities.get_child_count()
	assert_true(await shells.wait(whole), "Papo's sandbar has the host's pick-ups and creatures")
	assert_gt(host.session.pickups.get_child_count(), 0, "the sandbar has pick-ups to compare")
	assert_eq(host.session.body(1).look_slot, host_look, "the host keeps its look")
	assert_eq(host.session.body(papo_id).look_slot, papo_look, "Papo keeps his")
	assert_eq(papo.session.body(papo_id).look_slot, papo_look, "and Papo draws it")
	assert_eq(host.session.world_state.get("run_seed"), NEW_SEED, "a new run seed")
	assert_eq(papo.session.world_state.get("run_seed"), NEW_SEED, "the same one on Papo")
	for shell: GameShell in [host, papo]:
		assert_eq(shell.island.layout.id, &"sandbar")
		assert_eq(shell.travel.islands_reached, 1)
		assert_true(shell.session.removed_names().is_empty())
		assert_true(shell.crossings.is_empty())
		for id: int in shell.session.peer_ids():
			assert_false(shell.session.body(id).meters.dead)
			assert_eq(shell.session.body(id).meters.health, 100.0)
			assert_eq(shell.session.body(id).meters.death_cause, &"")
		assert_not_null(shell.hud, "with its HUD")
	assert_eq(WeatherManager.sky.clock.day, 1, "day 1")


func test_a_client_still_in_its_run() -> void:
	var pair := await _pair_in_run()
	if pair.is_empty():
		return
	var host := pair[0]
	var papo := pair[1]
	var old_papo_session: int = papo.session.get_instance_id()
	for id: int in host.session.peer_ids():
		host.session.body(id).meters.dead = true
	assert_eq(host.flow, GameShell.Flow.SUMMARY)
	# The host picks Otra vez in the same frame, before Papo has seen anyone die.
	assert_eq(papo.flow, GameShell.Flow.RUN)
	_pick_otra_vez(host)
	var rows: Array[String] = ["Yuni (anfitrión)", "Papo"]
	assert_true(await shells.wait(_in_new_lobby(papo, old_papo_session, rows)), "Papo's run ends and his lobby shows")
	assert_null(papo.hud, "his old HUD went with his run")


func test_the_host_starts_at_once() -> void:
	var pair := await _pair_in_run()
	if pair.is_empty():
		return
	var host := pair[0]
	var papo := pair[1]
	var papo_id: int = shells.peer_id(papo)
	var old_papo_session: int = papo.session.get_instance_id()
	for id: int in host.session.peer_ids():
		host.session.body(id).meters.dead = true
	_pick_otra_vez(host)
	assert_true(host.session.begin_run(), "Empezar viaje before Papo's join request arrives")
	var joined := func() -> bool:
		return papo.session != null and papo.session.get_instance_id() != old_papo_session \
			and papo.flow == GameShell.Flow.RUN and papo.session.body(papo_id) != null and papo.hud != null
	assert_true(await shells.wait(joined), "Papo joins the new run with his HUD")
	assert_not_null(host.session.body(papo_id), "and spawns on the host")


func test_a_client_who_left_is_not_pulled_back() -> void:
	var host := _start_host()
	var papo := await shells.join_lobby("Papo")
	var dayana := await shells.join_lobby("Dayana")
	assert_not_null(papo)
	assert_not_null(dayana)
	if papo == null or dayana == null:
		return
	var dayana_id: int = shells.peer_id(dayana)
	assert_true(await shells.begin_run())
	assert_true(await shells.end_run())
	shells.go_home(dayana)
	assert_eq(dayana.flow, GameShell.Flow.TITLE)
	assert_true(await shells.wait(func() -> bool: return not host.session.multiplayer.get_peers().has(dayana_id)), "the host saw Dayana leave")
	var old_papo_session: int = papo.session.get_instance_id()
	_pick_otra_vez(host)
	var rows: Array[String] = ["Yuni (anfitrión)", "Papo"]
	assert_true(await shells.wait(_in_new_lobby(papo, old_papo_session, rows)), "the new lobby has the host and Papo only")
	assert_eq(_lobby_of(host).rows(), rows)
	await wait_physics_frames(10)
	assert_eq(dayana.flow, GameShell.Flow.TITLE, "Dayana stays on her title")
	assert_null(dayana.session)


func test_old_messages_reach_the_new_lobby_and_change_nothing() -> void:
	var pair := await _pair_in_run()
	if pair.is_empty():
		return
	var host := pair[0]
	var papo := pair[1]
	assert_true(await shells.end_run())
	var old_session := papo.session
	var old_session_id: int = old_session.get_instance_id()
	# Papo's old run sends movement and actions just before the host's call.
	var moving: Array[PendingIntent] = [PendingIntent.create(1, MoveIntent.create(Vector2.RIGHT, false, false, false), 0.016)]
	old_session.send_intents(moving)
	old_session.say(0)
	old_session.start_route(&"raft")
	var site := old_session.get_node_or_null(^"RaftSite") as BuildSite
	assert_not_null(site, "the sandbar's raft site")
	if site != null:
		old_session.ask_site_state(site)
	_pick_otra_vez(host)
	var bubbles := func() -> int: return host.session.find_children("SpeechBubble", "", true, false).size()
	var rows: Array[String] = ["Yuni (anfitrión)", "Papo"]
	assert_true(await shells.wait(_in_new_lobby(papo, old_session_id, rows)))
	assert_eq(host.session.phase, CoopSession.Phase.LOBBY)
	assert_eq(host.session.peer_ids().size(), 0, "no body spawned from an old message")
	assert_eq(bubbles.call(), 0, "no quick chat")
	assert_false((host.session.get_node(^"Routes") as IslandRoutes).has_left(shells.peer_id(papo)), "no route started")


func test_the_same_looks_again() -> void:
	var host := _start_host()
	var gone := await shells.join_lobby("Nadie")
	var papo := await shells.join_lobby("Papo")
	assert_not_null(gone)
	assert_not_null(papo)
	if gone == null or papo == null:
		return
	var gone_id: int = shells.peer_id(gone)
	var papo_id: int = shells.peer_id(papo)
	assert_true(await shells.begin_run())
	assert_eq(host.session.body(papo_id).look_slot, 2, "Papo joined second: slot 2")
	shells.drop(gone)
	assert_true(await shells.wait(func() -> bool: return host.session.is_dropped(gone_id)))
	host.session._physics_process(CoopSession.DISCONNECT_DOWNED_S + 1.0)
	assert_null(host.session.body(gone_id), "the first client is removed and slot 1 is free")
	var removed: Array[String] = ["Nadie"]
	assert_true(await shells.wait(func() -> bool: return papo.session.removed_names() == removed), "Papo heard of the removal")
	assert_true(await shells.end_run())
	var old_papo_session: int = papo.session.get_instance_id()
	_pick_otra_vez(host)
	var rows: Array[String] = ["Yuni (anfitrión)", "Papo"]
	assert_true(await shells.wait(_in_new_lobby(papo, old_papo_session, rows)))
	assert_true(await shells.begin_run())
	assert_eq(host.session.body(papo_id).look_slot, 2, "Papo keeps slot 2, not the free slot 1")
	assert_true(await shells.wait(func() -> bool: return papo.session.body(papo_id).look_slot == 2), "and draws it")
	assert_true(host.session.removed_names().is_empty(), "the removed player stays in the old run")
	assert_true(papo.session.removed_names().is_empty(), "on Papo too")


# endings-progression "A fresh run starts clean", from a later island: nothing of the coast cay stays.
func test_the_party_again_from_the_coast_cay() -> void:
	var pair := await _pair_in_run()
	if pair.is_empty():
		return
	var host := pair[0]
	var papo := pair[1]
	host.travel.travel(&"coast_cay")
	var on_the_cay := func() -> bool:
		return host.island.layout.id == &"coast_cay" and papo.island.layout.id == &"coast_cay" and papo.travel.islands_reached == 2
	assert_true(await shells.wait(on_the_cay), "both reached the coast cay")
	assert_true(await shells.end_run())
	var old_papo_session: int = papo.session.get_instance_id()
	_pick_otra_vez(host)
	var rows: Array[String] = ["Yuni (anfitrión)", "Papo"]
	assert_true(await shells.wait(_in_new_lobby(papo, old_papo_session, rows)))
	assert_true(await shells.begin_run())
	var whole := func() -> bool:
		return papo.session.pickups.get_child_count() == host.session.pickups.get_child_count() \
			and papo.session.entities.get_child_count() == host.session.entities.get_child_count()
	assert_true(await shells.wait(whole), "Papo's sandbar has the host's pick-ups and creatures")
	for shell: GameShell in [host, papo]:
		assert_eq(shell.island.layout.id, &"sandbar", "back on the sandbar")
		assert_eq(shell.travel.islands_reached, 1, "1 island reached")
		assert_true(shell.crossings.is_empty())
		for node: Node in shell.island.get_parent().get_children():
			var current: bool = node == shell.island or node == shell.session or node == shell.tint
			assert_true(current or node.is_queued_for_deletion(), "nothing of the coast cay run is left: %s" % node.name)


# coop-networking "Rematch with the same party": a connected client that never asks to join again
# is disconnected after 10 s, as any peer that never asks.
func test_a_client_that_never_asks_again_is_disconnected() -> void:
	var pair := await _pair_in_run()
	if pair.is_empty():
		return
	var host := pair[0]
	var papo := pair[1]
	var papo_id: int = shells.peer_id(papo)
	assert_true(await shells.end_run())
	# Papo's client hears the call but does nothing with it (a frozen client).
	papo.rematch.called.disconnect(papo._on_rematch_called)
	_pick_otra_vez(host)
	await wait_physics_frames(10)
	assert_eq(_lobby_of(host).rows(), ["Yuni (anfitrión)"] as Array[String], "Papo has not asked again")
	assert_true(host.session._awaiting.has(papo_id), "the host waits for his join request")
	host.session._physics_process(CoopSession.JOIN_TIMEOUT_S + 1.0)
	var gone := func() -> bool: return not host.session.multiplayer.get_peers().has(papo_id)
	assert_true(await shells.wait(gone), "the host disconnects him")
	var told := func() -> bool: return _summary_of(papo) != null and _summary_of(papo).note.text == HOST_LEFT_NOTE
	assert_true(await shells.wait(told), "Papo's summary says the host closed the game")
	assert_eq(host.flow, GameShell.Flow.LOBBY, "the host's lobby stays open")


# coop-networking "Rematch is the host's call": a dropped player whose body died while away is not
# brought back by the rematch, and joins the new lobby as a new joiner.
func test_a_dropped_player_joins_later() -> void:
	var host := _start_host()
	var papo := await shells.join_lobby("Papo")
	var dayana := await shells.join_lobby("Dayana")
	assert_not_null(papo)
	assert_not_null(dayana)
	if papo == null or dayana == null:
		return
	var old_dayana_id: int = shells.peer_id(dayana)
	assert_true(await shells.begin_run())
	shells.drop(dayana)
	assert_true(await shells.wait(func() -> bool: return host.session.is_dropped(old_dayana_id)), "Dayana dropped")
	# Every body dies, Dayana's while she is away, so the run ends with her still dropped.
	assert_true(await shells.end_run())
	assert_eq(host.flow, GameShell.Flow.SUMMARY)
	var old_papo_session: int = papo.session.get_instance_id()
	_pick_otra_vez(host)
	var two: Array[String] = ["Yuni (anfitrión)", "Papo"]
	assert_true(await shells.wait(_in_new_lobby(papo, old_papo_session, two)), "the rematch lobby has the host and Papo")
	shells.rejoin(dayana)
	var three: Array[String] = ["Yuni (anfitrión)", "Papo", "Dayana"]
	var listed := func() -> bool:
		return dayana.flow == GameShell.Flow.LOBBY and _lobby_of(host).rows() == three and _lobby_of(dayana).rows() == three
	assert_true(await shells.wait(listed), "Dayana joins the new lobby")
	var dayana_id: int = shells.peer_id(dayana)
	assert_ne(dayana_id, old_dayana_id, "on a new connection")
	assert_eq(host.session._identities.peer_for(dayana.settings.identity.id), dayana_id, "a new joiner, known by her id")
	assert_eq(host.session.peer_ids().size(), 0, "nobody spawns in the lobby")


func test_the_waiting_note_gives_way_when_the_host_leaves() -> void:
	var pair := await _pair_in_run()
	if pair.is_empty():
		return
	var host := pair[0]
	var papo := pair[1]
	assert_true(await shells.end_run())
	assert_eq(_summary_of(papo).note.text, WAITING_NOTE)
	shells.go_home(host)
	var left := func() -> bool: return _summary_of(papo) != null and _summary_of(papo).note.text == HOST_LEFT_NOTE
	assert_true(await shells.wait(left), "the host-left note replaces it")
	assert_eq(papo.flow, GameShell.Flow.SUMMARY, "the summary stays")
	assert_false(_summary_of(papo).restart_button.visible)

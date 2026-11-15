extends GutTest
## coop-networking "Disconnect handling" and ui-shell "Teammate state word" over ENet on localhost
## (NetHarness): when Papo's client drops, the host, Dayana's client and a client that joins
## during his 90 s all hold him as disconnected, and every HUD's row for him reads "Desconectado"
## (not "Caído"); when he rejoins within the 90 s the word clears everywhere, under his new peer.
## "Muerto" comes first; a body the meters downed reads "Caído" once he is back.

const HUD_SCENE: PackedScene = preload("res://scenes/ui/run_hud.tscn")
const SPAWNS: Array[Vector2] = [Vector2(32.0, 48.0), Vector2(48.0, 48.0), Vector2(64.0, 48.0), Vector2(80.0, 48.0)]
const TIMEOUT_S: float = 5.0

var net: NetHarness
var papo: PlayerIdentity
# Freed before the sessions they read.
var huds: Array[Node] = []


func before_each() -> void:
	net = NetHarness.new(self)
	papo = PlayerIdentity.create()


func after_each() -> void:
	for hud: Node in huds:
		if is_instance_valid(hud):
			hud.free()
	huds.clear()
	net.teardown()


func _island(session: CoopSession) -> void:
	session.spawn_points = SPAWNS.duplicate()


func _as(identity: PlayerIdentity, player_name: String) -> Callable:
	return func(session: CoopSession) -> void:
		_island(session)
		session.local_identity = identity
		session.local_name = player_name


func _hud(session: CoopSession) -> RunHud:
	var hud := HUD_SCENE.instantiate() as RunHud
	add_child(hud)
	huds.append(hud)
	hud.bind(session, net.peer_id(session), false)
	return hud


# The row of the teammate named `player_name` on `hud` ("" when there is none), refreshed now.
func _row(hud: RunHud, player_name: String) -> String:
	hud.refresh()
	for row: String in hud.teammate_rows():
		if row.begins_with(player_name + " "):
			return row
	return ""


# The state word ending `row` ("" when the row is only a name and a number).
func _word(row: String) -> String:
	var parts := row.split(" ")
	return parts[parts.size() - 1] if parts.size() > 2 else ""


# A host, Dayana and Papo, everyone on every peer. Returns [host, dayana, papo].
func _trio() -> Array[CoopSession]:
	var host := net.add_host(_island)
	var dayana := await net.join(_as(PlayerIdentity.create(), "Dayana"))
	var client := await net.join(_as(papo, "Papo"))
	assert_not_null(dayana)
	assert_not_null(client)
	assert_true(await net.settle())
	net.silence_input()
	return [host, dayana, client] as Array[CoopSession]


# Papo's client quits; returns his old peer once the host holds him as dropped.
func _papo_drops(host: CoopSession, client: CoopSession) -> int:
	var papo_id: int = net.peer_id(client)
	net.drop(client)
	assert_true(await wait_until(func() -> bool: return host.is_dropped(papo_id), TIMEOUT_S), "the host holds Papo as dropped")
	return papo_id


# --- every peer knows ------------------------------------------------------------------------

func test_the_host_and_a_client_hold_a_dropped_player_as_dropped() -> void:
	var trio := await _trio()
	var host := trio[0]
	var dayana := trio[1]
	if dayana == null or trio[2] == null:
		return
	var papo_id := await _papo_drops(host, trio[2])
	assert_true(host.body(papo_id).net.net_dropped, "the host's body carries the flag")
	assert_true(await wait_until(func() -> bool: return dayana.is_dropped(papo_id), TIMEOUT_S), "Dayana holds Papo as dropped")
	assert_false(dayana.is_dropped(CoopSession.HOST_ID), "nobody else is")
	assert_false(dayana.is_dropped(net.peer_id(dayana)))


func test_a_client_that_joins_during_the_90_s_holds_him_as_dropped() -> void:
	var trio := await _trio()
	var host := trio[0]
	if trio[1] == null or trio[2] == null:
		return
	var papo_id := await _papo_drops(host, trio[2])
	var yuni := await net.join(_as(PlayerIdentity.create(), "Yuni"))
	assert_not_null(yuni)
	if yuni == null:
		return
	assert_true(await wait_until(func() -> bool: return yuni.body(papo_id) != null, TIMEOUT_S))
	assert_true(await wait_until(func() -> bool: return yuni.is_dropped(papo_id), TIMEOUT_S), "the late joiner holds Papo as dropped")


func test_a_rejoin_within_90_s_clears_it_everywhere() -> void:
	var trio := await _trio()
	var host := trio[0]
	var dayana := trio[1]
	if dayana == null or trio[2] == null:
		return
	var papo_id := await _papo_drops(host, trio[2])
	var papo_body := host.body(papo_id)
	assert_true(await wait_until(func() -> bool: return dayana.is_dropped(papo_id), TIMEOUT_S))
	var back := await net.join(_as(papo, "Papo"))
	assert_not_null(back, "Papo joins again")
	if back == null:
		return
	var new_id: int = net.peer_id(back)
	assert_same(host.body(new_id), papo_body, "the same body")
	assert_false(host.is_dropped(new_id), "not dropped on the host")
	assert_false(papo_body.net.net_dropped, "the host's body no longer carries the flag")
	assert_true(await wait_until(func() -> bool: return dayana.body(new_id) != null and not dayana.is_dropped(new_id), TIMEOUT_S), "nor on Dayana")
	assert_true(await wait_until(func() -> bool: return back.body(new_id) != null and not back.is_dropped(new_id), TIMEOUT_S), "nor on Papo's own client")


# --- the row's word ----------------------------------------------------------------------------

func test_a_dropped_teammates_row_reads_desconectado_on_the_host_and_a_client() -> void:
	var trio := await _trio()
	var host := trio[0]
	var dayana := trio[1]
	if dayana == null or trio[2] == null:
		return
	var host_hud := _hud(host)
	var dayana_hud := _hud(dayana)
	assert_eq(_word(_row(dayana_hud, "Papo")), "", "standing: no word")
	await _papo_drops(host, trio[2])
	assert_eq(_word(_row(host_hud, "Papo")), "Desconectado", "on the host")
	var word_on_dayana := func() -> bool: return _word(_row(dayana_hud, "Papo")) == "Desconectado"
	assert_true(await wait_until(word_on_dayana, TIMEOUT_S), "on Dayana's client, not 'Caído': %s" % _row(dayana_hud, "Papo"))


func test_a_late_joiners_row_reads_desconectado() -> void:
	var trio := await _trio()
	var host := trio[0]
	if trio[1] == null or trio[2] == null:
		return
	await _papo_drops(host, trio[2])
	var yuni := await net.join(_as(PlayerIdentity.create(), "Yuni"))
	assert_not_null(yuni)
	if yuni == null:
		return
	var yuni_hud := _hud(yuni)
	var word_on_yuni := func() -> bool: return _word(_row(yuni_hud, "Papo")) == "Desconectado"
	assert_true(await wait_until(word_on_yuni, TIMEOUT_S), "on the joiner's HUD: %s" % _row(yuni_hud, "Papo"))


func test_back_within_90_s_the_row_has_no_word() -> void:
	var trio := await _trio()
	var host := trio[0]
	var dayana := trio[1]
	if dayana == null or trio[2] == null:
		return
	var host_hud := _hud(host)
	var dayana_hud := _hud(dayana)
	await _papo_drops(host, trio[2])
	assert_true(await wait_until(func() -> bool: return _word(_row(dayana_hud, "Papo")) == "Desconectado", TIMEOUT_S))
	var back := await net.join(_as(papo, "Papo"))
	assert_not_null(back)
	if back == null:
		return
	assert_eq(_word(_row(host_hud, "Papo")), "", "the host's row: %s" % _row(host_hud, "Papo"))
	var cleared := func() -> bool:
		var row := _row(dayana_hud, "Papo")
		return not row.is_empty() and _word(row).is_empty()
	assert_true(await wait_until(cleared, TIMEOUT_S), "Dayana's row: %s" % _row(dayana_hud, "Papo"))


func test_downed_by_the_meters_reads_caido_once_back() -> void:
	var trio := await _trio()
	var host := trio[0]
	var dayana := trio[1]
	if dayana == null or trio[2] == null:
		return
	var dayana_hud := _hud(dayana)
	# Down by the meters, with time left on the downed timer (as at 0 health in co-op).
	var meters := host.body(net.peer_id(trio[2])).meters
	meters.downed_time_left_s = 60.0
	meters.health = 0.0
	meters.downed = true
	assert_true(await wait_until(func() -> bool: return _word(_row(dayana_hud, "Papo")) == "Caído", TIMEOUT_S))
	await _papo_drops(host, trio[2])
	assert_true(await wait_until(func() -> bool: return _word(_row(dayana_hud, "Papo")) == "Desconectado", TIMEOUT_S), "dropped outranks downed")
	var back := await net.join(_as(papo, "Papo"))
	assert_not_null(back)
	if back == null:
		return
	assert_true(host.body(net.peer_id(back)).downed, "the meters keep him down")
	assert_true(await wait_until(func() -> bool: return _word(_row(dayana_hud, "Papo")) == "Caído", TIMEOUT_S), "Dayana's row: %s" % _row(dayana_hud, "Papo"))


func test_dead_comes_first() -> void:
	var trio := await _trio()
	var host := trio[0]
	var dayana := trio[1]
	if dayana == null or trio[2] == null:
		return
	var dayana_hud := _hud(dayana)
	var papo_id := await _papo_drops(host, trio[2])
	assert_true(await wait_until(func() -> bool: return _word(_row(dayana_hud, "Papo")) == "Desconectado", TIMEOUT_S))
	host.body(papo_id).meters.dead = true
	assert_eq(_word(_row(_hud(host), "Papo")), "Muerto", "on the host")
	assert_true(await wait_until(func() -> bool: return _word(_row(dayana_hud, "Papo")) == "Muerto", TIMEOUT_S), "on Dayana's client")

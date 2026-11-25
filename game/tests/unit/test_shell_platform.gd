extends GutTest
## ui-shell "Screen flow", "Join screen" and "Lobby", and net-platform "Join requests from outside
## the game", through the shell: requests come back READY, PENDING or FAILED, a pending joiner never
## acts as host, failures show their reason, and a join from outside the game waits for the title.
## Most cases swap in FakeNetBackend (design.md D6); the first three are 1 player, offline, and
## need no second peer.

const SHELL_SCENE: PackedScene = preload("res://scenes/shell/game_shell.tscn")
var settings_path: String = UserTmp.path("test_shell_platform_settings.cfg")
const NOBODY_PORT: int = 7999
const ENET_NOTE: String = "Los demás se unen por IP en el puerto UDP %d. Por internet, abre ese puerto en tu router."

var _shells: Array[GameShell] = []
var _held: Array[MultiplayerPeer] = []


func before_all() -> void:
	assert_true(NetManager.backend is EnetBackend, "every suite starts on ENet")


func after_all() -> void:
	assert_true(NetManager.backend is EnetBackend, "every suite leaves ENet behind")


func before_each() -> void:
	NetManager.start_solo()
	WeatherManager.stop()


func after_each() -> void:
	# The run goes before the peer closes, as GameShell._end_run() requires.
	for shell: GameShell in _shells:
		if is_instance_valid(shell):
			shell._end_run()
			shell.free()
	_shells.clear()
	WeatherManager.stop()
	get_tree().paused = false
	NetManager.leave()
	NetManager.use_backend(null)
	FakeNetBackend.reset()
	for peer: MultiplayerPeer in _held:
		peer.close()
	_held.clear()
	if FileAccess.file_exists(settings_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(settings_path))


func _shell(host_port: int = 0) -> GameShell:
	# An install already asked its name, so the title's buttons can take the focus (run-menu D7).
	if not FileAccess.file_exists(settings_path):
		var config := ConfigFile.new()
		config.set_value("player", "name_asked", true)
		config.save(settings_path)
	var shell := SHELL_SCENE.instantiate() as GameShell
	shell.settings_path = settings_path
	shell.port = host_port
	add_child(shell)
	_shells.append(shell)
	return shell


func _fake(timeout_s: float = 0.0) -> FakeNetBackend:
	var fake := FakeNetBackend.make(timeout_s)
	NetManager.use_backend(fake)
	return fake


func _offline() -> bool:
	return NetManager.multiplayer.multiplayer_peer is OfflineMultiplayerPeer and not NetManager.is_online()


# A port nobody listens on: bound for a moment, then let go.
func _free_port() -> int:
	var probe := NetPeers.create_server(0)
	assert_not_null(probe, "a free port to probe")
	if probe == null:
		return NOBODY_PORT
	var port: int = NetPeers.bound_port(probe)
	probe.close()
	return port


# The title's "Unirse", then `text` and "Conectar", as the player would.
func _connect_from_the_join_screen(shell: GameShell, text: String) -> JoinScreen:
	(shell.screen as TitleScreen).join_requested.emit()
	var join := shell.screen as JoinScreen
	join.address_field.text = text
	join.connect_button.pressed.emit()
	return join


func _creatures(session: CoopSession) -> int:
	var count: int = 0
	for node: Node in session.entities.get_children():
		if node is Creature:
			count += 1
	return count


# --- 1 player, offline -------------------------------------------------------------------------

func test_solo_from_the_title_with_a_broken_platform() -> void:
	var fake := FakeNetBackend.make()
	fake.start_failure = NetFailure.Reason.PLATFORM_UNAVAILABLE
	fake.refuse_host = NetFailure.Reason.PLATFORM_UNAVAILABLE
	fake.refuse_join = NetFailure.Reason.PLATFORM_UNAVAILABLE
	NetManager.use_backend(fake)
	var shell := _shell()
	(shell.screen as TitleScreen).solo_requested.emit()
	assert_eq(shell.flow, GameShell.Flow.RUN)
	assert_true(_offline(), "solo is the offline peer")
	assert_eq(shell.session.peer_ids(), [1] as Array[int], "one body")
	shell.session.body(1).meters.dead = true
	assert_eq(shell.flow, GameShell.Flow.SUMMARY, "death shows the summary")
	var summary := shell.screen as SummaryScreen
	assert_true(summary.restart_button.visible)
	assert_eq(summary.restart_button.text, "Otra vez")
	# As if the 0.8 s gate had passed (menu-clarity design D5).
	summary.shown_at_s -= SummaryScreen.ACCEPT_DELAY_S
	summary.restart_button.pressed.emit()
	assert_eq(shell.flow, GameShell.Flow.RUN, "Otra vez starts a new run")
	assert_true(_offline(), "still offline")
	assert_eq(shell.session.peer_ids(), [1] as Array[int])
	assert_eq(fake.calls, PackedStringArray(["start"]), "no host, join or leave call")
	assert_true(fake.offered.is_empty(), "no port opened")


func test_hosting_alone_on_a_slower_backend() -> void:
	var fake := _fake()
	fake.defer_frames = 3
	var shell := _shell()
	(shell.screen as TitleScreen).host_requested.emit()
	assert_eq(shell.flow, GameShell.Flow.LOBBY, "the lobby opens at once")
	var opening := shell.screen as LobbyScreen
	assert_true(opening.waiting.visible)
	assert_eq(opening.waiting.text, LobbyScreen.OPENING)
	assert_false(opening.start_button.visible, "no Empezar viaje yet")
	assert_false(opening.note.visible)
	assert_false(opening.addresses.visible)
	assert_true(opening.leave_button.visible, "only Salir")
	assert_true(opening.rows().is_empty(), "nobody aboard yet")
	assert_null(shell.session, "no run while hosting opens")
	assert_null(shell.island)
	assert_true(_offline())
	assert_true(await wait_until(func() -> bool: return shell.session != null, 2.0), "hosting became ready")
	assert_eq(shell.flow, GameShell.Flow.LOBBY)
	var lobby := shell.screen as LobbyScreen
	assert_eq(lobby.rows(), ["Balsero (anfitrión)"] as Array[String], "the host alone")
	assert_true(lobby.start_button.visible)
	assert_false(lobby.waiting.visible)
	assert_not_null(NetManager.host_info())
	if NetManager.host_info() != null:
		assert_eq(lobby.note.text, "Sala de prueba en el puerto %d." % NetManager.host_info().port, "the note comes from the backend")
	lobby.start_button.pressed.emit()
	assert_eq(shell.flow, GameShell.Flow.RUN)
	assert_eq(shell.session.peer_ids(), [1] as Array[int], "one body")
	assert_false(shell.session.can_pause(), "hosting alone is not solo")
	assert_eq(fake.calls, PackedStringArray(["start", "host"]))
	shell.back_to_title()


func test_an_outside_join_during_a_solo_run_waits_for_the_title() -> void:
	var fake := _fake()
	fake.answer = false
	var shell := _shell()
	(shell.screen as TitleScreen).solo_requested.emit()
	fake.accept_invite(NetJoinTarget.with_token("sala-1", "Yuni"))
	await wait_process_frames(3)
	assert_eq(shell.flow, GameShell.Flow.RUN, "the run goes on")
	assert_true(_offline())
	assert_eq(shell.session.peer_ids(), [1] as Array[int])
	shell.session.body(1).meters.dead = true
	assert_eq(shell.flow, GameShell.Flow.SUMMARY)
	await wait_process_frames(3)
	assert_eq(shell.flow, GameShell.Flow.SUMMARY, "the summary is not interrupted either")
	assert_eq(fake.calls, PackedStringArray(["start"]), "kept, not joined")
	# As if the 0.8 s gate had passed (menu-clarity design D5).
	(shell.screen as SummaryScreen).shown_at_s -= SummaryScreen.ACCEPT_DELAY_S
	(shell.screen as SummaryScreen).home_button.pressed.emit()
	assert_eq(shell.flow, GameShell.Flow.TITLE)
	assert_true(await wait_until(func() -> bool: return fake.calls.has("join"), 2.0), "the join starts once the title shows")
	assert_eq(shell.flow, GameShell.Flow.JOIN)
	var join := shell.screen as JoinScreen
	assert_eq(join.address_field.text, "Yuni", "the request's label")
	assert_false(join.address_field.editable)
	assert_eq(join.status.text, JoinScreen.CONNECTING)
	assert_true(join.connect_button.disabled)
	assert_null(shell.session, "nothing is built while the join waits")
	assert_not_null(NetManager.pending_request())
	assert_null(NetManager.take_outside_join(), "the request was taken")


# --- Hosting -----------------------------------------------------------------------------------

func test_salir_while_opening_cancels() -> void:
	var fake := _fake()
	fake.defer_frames = 3
	fake.deliver_after_leave = true
	var shell := _shell()
	(shell.screen as TitleScreen).host_requested.emit()
	var request := NetManager.pending_request()
	assert_not_null(request)
	(shell.screen as LobbyScreen).leave_button.pressed.emit()
	assert_eq(shell.flow, GameShell.Flow.TITLE)
	assert_true(_offline())
	assert_has(fake.calls, "leave", "the backend left its session")
	if request != null:
		assert_eq(request.state, NetRequest.State.CANCELLED)
	assert_null(NetManager.pending_request())
	await wait_process_frames(6)
	assert_eq(fake.offered.size(), 1, "the backend still delivered a peer")
	var late := fake.last_offered()
	if late != null:
		assert_eq(late.get_connection_status(), MultiplayerPeer.CONNECTION_DISCONNECTED, "closed, never installed")
	assert_eq(shell.flow, GameShell.Flow.TITLE)
	assert_null(shell.session, "no run starts later")
	assert_true(_offline())


func test_pressing_host_twice_asks_once() -> void:
	var fake := _fake()
	fake.defer_frames = 3
	var shell := _shell()
	var title := shell.screen as TitleScreen
	title.host_requested.emit()
	title.host_requested.emit()
	shell.start_host()
	assert_eq(fake.calls.count("host"), 1, "one request while it is pending")
	assert_eq(shell.flow, GameShell.Flow.LOBBY)
	assert_eq((shell.screen as LobbyScreen).waiting.text, LobbyScreen.OPENING)
	assert_true(await wait_until(func() -> bool: return shell.session != null, 2.0), "hosting became ready")
	assert_eq(fake.calls.count("host"), 1)
	assert_eq((shell.screen as LobbyScreen).rows(), ["Balsero (anfitrión)"] as Array[String])
	shell.back_to_title()


func test_a_late_host_failure_returns_to_the_title_with_its_reason() -> void:
	var fake := _fake()
	fake.defer_frames = 3
	fake.refuse_host = NetFailure.Reason.NOT_SIGNED_IN
	var shell := _shell()
	(shell.screen as TitleScreen).host_requested.emit()
	assert_eq(shell.flow, GameShell.Flow.LOBBY)
	assert_true(await wait_until(func() -> bool: return shell.flow == GameShell.Flow.TITLE, 2.0), "back on the title")
	assert_eq((shell.screen as TitleScreen).status.text, "Inicia sesión en la plataforma para jugar en línea.", "on the red band")
	assert_true((shell.screen as TitleScreen).status.visible)
	assert_null(shell.session)
	assert_true(_offline())
	assert_has(fake.calls, "leave")


func test_the_lobby_names_the_port_opened() -> void:
	var port := _free_port()
	var shell := _shell(port)
	(shell.screen as TitleScreen).host_requested.emit()
	assert_eq(shell.flow, GameShell.Flow.LOBBY)
	var lobby := shell.screen as LobbyScreen
	var info := NetManager.host_info()
	assert_not_null(info)
	if info != null:
		assert_eq(info.port, port)
		assert_eq(lobby.note.text, ENET_NOTE % port, "the port actually opened")
		var listed := "Tu IP: %s" % ", ".join(info.addresses) if not info.addresses.is_empty() else ""
		assert_eq(lobby.addresses.text, listed, "the addresses come from the backend")
	assert_eq(lobby.rows(), ["Balsero (anfitrión)"] as Array[String])
	shell.back_to_title()


func test_enet_wording_is_kept_on_a_taken_port() -> void:
	var holder := NetPeers.create_server(0)
	assert_not_null(holder)
	if holder == null:
		return
	_held.append(holder)
	var port: int = NetPeers.bound_port(holder)
	var shell := _shell(port)
	(shell.screen as TitleScreen).host_requested.emit()
	assert_engine_error("Couldn't create an ENet host")
	assert_eq(shell.flow, GameShell.Flow.TITLE, "the title stays")
	# ui-shell "Menu windows", scenario "Hosting fails" (menu-clarity design D6): the reason shows on
	# the title's red band and stays while the focus and the pointer move over the buttons.
	var title := shell.screen as TitleScreen
	var reason: String = "No se pudo abrir el puerto %d." % port
	assert_eq(title.status.text, reason)
	assert_true(title.status.visible)
	assert_eq(title.status.theme_type_variation, &"ErrorLabel", "a red band")
	for button: Button in title.buttons():
		button.grab_focus()
		button.mouse_entered.emit()
		assert_eq(title.status.text, reason, "kept while '%s' has the focus" % button.text)
		assert_true(title.status.visible)
	assert_ne(title.description.text, reason, "the description panel describes the focused button")
	assert_null(shell.session)
	assert_true(_offline())


# --- Joining -----------------------------------------------------------------------------------

func test_a_pending_joiner_never_acts_as_host() -> void:
	var fake := _fake()
	fake.defer_frames = 5
	var shell := _shell()
	var join := _connect_from_the_join_screen(shell, "127.0.0.1:%d" % NOBODY_PORT)
	var request := NetManager.pending_request()
	assert_not_null(request, "the join waits on the backend")
	assert_eq(join.status.text, JoinScreen.CONNECTING)
	assert_null(shell.session, "no session while pending")
	assert_null(shell.island, "no island while pending")
	await wait_process_frames(2)
	assert_null(shell.session)
	assert_null(shell.island)
	assert_true(_offline())
	assert_true(await wait_until(func() -> bool: return shell.session != null, 2.0), "the join was answered")
	if shell.session == null:
		return
	if request != null:
		assert_eq(request.state, NetRequest.State.READY)
	assert_false(shell.session.multiplayer.is_server(), "the session runs as a client")
	assert_true(shell.session.roster.is_empty(), "in no roster")
	assert_true(shell.session.peer_ids().is_empty(), "no body")
	await wait_process_frames(5)
	assert_eq(_creatures(shell.session), 0, "no creature spawns on a client")
	assert_eq(shell.flow, GameShell.Flow.JOIN, "still connecting")


func test_a_launch_argument_joins_after_the_title() -> void:
	var port := _free_port()
	NetManager.use_backend(EnetBackend.new(), PackedStringArray(["--connect=127.0.0.1:%d" % port]))
	var shell := _shell()
	assert_eq(shell.flow, GameShell.Flow.TITLE, "the title shows first")
	assert_true(await wait_until(func() -> bool: return shell.flow == GameShell.Flow.JOIN, 2.0), "then the join screen")
	var join := shell.screen as JoinScreen
	assert_eq(join.address_field.text, "127.0.0.1:%d" % port, "the target's label")
	assert_false(join.address_field.editable)
	assert_eq(join.status.text, JoinScreen.CONNECTING)
	assert_true(join.connect_button.disabled)
	assert_not_null(shell.session, "ENet answers at once: the run is built as a client")
	if shell.session != null:
		assert_false(shell.session.multiplayer.is_server())
	assert_true(NetManager.is_online())


func test_a_failed_outside_join_says_why() -> void:
	# Refused a few frames late, so the reason reaches the shell through join_failed (the
	# NOT_FOUND case below fails inside the call).
	var fake := _fake()
	fake.defer_frames = 3
	fake.refuse_join = NetFailure.Reason.FULL
	var shell := _shell()
	fake.accept_invite(NetJoinTarget.with_token("sala-1", "Yuni"))
	assert_true(await wait_until(func() -> bool: return NetManager.last_failure == NetFailure.Reason.FULL, 2.0), "taken on the title, then refused")
	assert_eq(shell.flow, GameShell.Flow.JOIN)
	var join := shell.screen as JoinScreen
	assert_eq(join.status.text, "La partida está llena.")
	assert_true(join.address_field.editable, "the player can try again")
	assert_false(join.connect_button.disabled)
	assert_null(shell.session)
	assert_true(_offline())


func test_a_join_failure_opens_the_join_screen() -> void:
	var fake := _fake()
	var shell := _shell()
	assert_eq(shell.flow, GameShell.Flow.TITLE)
	shell._join_target(NetJoinTarget.with_token("nope", "Yuni"))
	assert_eq(shell.flow, GameShell.Flow.JOIN, "the join screen opens")
	assert_eq((shell.screen as JoinScreen).status.text, "Esa partida ya no existe.")
	assert_null(shell.session)
	assert_true(_offline())
	assert_eq(fake.calls, PackedStringArray(["start", "join"]))


func test_volver_cancels_a_pending_join() -> void:
	var fake := _fake()
	fake.defer_frames = 3
	fake.deliver_after_leave = true
	var shell := _shell()
	var join := _connect_from_the_join_screen(shell, "127.0.0.1:%d" % NOBODY_PORT)
	var request := NetManager.pending_request()
	assert_not_null(request)
	join.back_button.pressed.emit()
	assert_eq(shell.flow, GameShell.Flow.TITLE)
	assert_has(fake.calls, "leave", "the backend left its session")
	if request != null:
		assert_eq(request.state, NetRequest.State.CANCELLED)
	await wait_process_frames(6)
	assert_eq(fake.offered.size(), 1, "a late answer still came")
	var late := fake.last_offered()
	if late != null:
		assert_eq(late.get_connection_status(), MultiplayerPeer.CONNECTION_DISCONNECTED, "and was ignored")
	assert_eq(shell.flow, GameShell.Flow.TITLE)
	assert_null(shell.session, "no session starts later")
	assert_true(_offline())

extends GutTest
## net-platform "Join requests from outside the game" and "Join timeout", through the shell. A join
## from outside the game starts at once on the title, settings, credits or a join screen with no
## join under way; in a lobby (opening, the host's or a client's) or on a join screen still
## connecting it is kept, and taken once the title shows. A join that times out says so on the join
## screen. The launch line goes through the startup pick. Each case is 1 player; the fake's peers
## are ENet on localhost with nobody on the other end.

const SHELL_SCENE: PackedScene = preload("res://scenes/shell/game_shell.tscn")
var settings_path: String = UserTmp.path("test_shell_join_rules_settings.cfg")
const NOBODY_PORT: int = 7999
## Frames given to a kept request: the shell takes one on the next idle step, so this is plenty.
const KEEP_FRAMES: int = 3

var _shells: Array[GameShell] = []


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
	if FileAccess.file_exists(settings_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(settings_path))


func _shell() -> GameShell:
	var shell := SHELL_SCENE.instantiate() as GameShell
	shell.settings_path = settings_path
	shell.port = 0
	add_child(shell)
	_shells.append(shell)
	return shell


func _fake(timeout_s: float = 0.0) -> FakeNetBackend:
	var fake := FakeNetBackend.make(timeout_s)
	NetManager.use_backend(fake)
	return fake


func _offline() -> bool:
	return NetManager.multiplayer.multiplayer_peer is OfflineMultiplayerPeer and not NetManager.is_online()


func _invite() -> NetJoinTarget:
	return NetJoinTarget.with_token("sala-1", "Yuni")


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


# The invite was taken: the fake got its `joins`-th join, and the join screen shows the label,
# connecting, with the field locked.
func _assert_taken(shell: GameShell, fake: FakeNetBackend, joins: int, why: String) -> void:
	assert_true(await wait_until(func() -> bool: return fake.calls.count("join") >= joins, 2.0), why)
	assert_eq(fake.calls.count("join"), joins, "one join for the invite")
	assert_eq(shell.flow, GameShell.Flow.JOIN, "the join screen")
	var join := shell.screen as JoinScreen
	assert_not_null(join)
	if join == null:
		return
	assert_eq(join.address_field.text, "Yuni", "the request's label")
	assert_false(join.address_field.editable)
	assert_eq(join.status.text, JoinScreen.CONNECTING)
	assert_true(join.connect_button.disabled)
	assert_null(NetManager.take_outside_join(), "the request was taken once")


# The invite is kept for now: no new join reached the fake after a few frames.
func _assert_kept(shell: GameShell, fake: FakeNetBackend, joins: int, flow: GameShell.Flow) -> void:
	await wait_process_frames(KEEP_FRAMES)
	assert_eq(fake.calls.count("join"), joins, "kept, not joined")
	assert_eq(shell.flow, flow, "nothing is interrupted")


# --- Taken at once -----------------------------------------------------------------------------

func test_an_outside_join_starts_at_once_from_settings() -> void:
	var fake := _fake()
	fake.answer = false
	var shell := _shell()
	shell.show_settings()
	assert_eq(shell.flow, GameShell.Flow.SETTINGS)
	fake.accept_invite(_invite())
	await _assert_taken(shell, fake, 1, "taken from settings")
	assert_null(shell.session, "nothing is built while the join waits")


func test_an_outside_join_starts_at_once_from_credits() -> void:
	var fake := _fake()
	fake.answer = false
	var shell := _shell()
	shell.show_credits()
	assert_eq(shell.flow, GameShell.Flow.CREDITS)
	fake.accept_invite(_invite())
	await _assert_taken(shell, fake, 1, "taken from credits")


func test_an_outside_join_starts_at_once_from_an_idle_join_screen() -> void:
	var fake := _fake()
	fake.answer = false
	var shell := _shell()
	(shell.screen as TitleScreen).join_requested.emit()
	var idle := shell.screen as JoinScreen
	assert_eq(shell.flow, GameShell.Flow.JOIN)
	fake.accept_invite(_invite())
	await _assert_taken(shell, fake, 1, "taken from a join screen nobody has used")
	assert_eq(shell.screen, idle, "the same join screen, now connecting")


func test_an_outside_join_starts_at_once_after_a_failed_join() -> void:
	var fake := _fake()
	var shell := _shell()
	shell._join_target(NetJoinTarget.with_token("nope", "Pepe"))
	assert_eq(shell.flow, GameShell.Flow.JOIN)
	assert_eq((shell.screen as JoinScreen).status.text, "Esa partida ya no existe.", "the first join failed")
	fake.answer = false
	fake.accept_invite(_invite())
	await _assert_taken(shell, fake, 2, "taken from a join screen after a failure")


# --- Kept, then taken on the title -------------------------------------------------------------

func test_an_outside_join_waits_out_the_opening_lobby() -> void:
	var fake := _fake()
	fake.answer = false
	var shell := _shell()
	(shell.screen as TitleScreen).host_requested.emit()
	assert_eq((shell.screen as LobbyScreen).waiting.text, LobbyScreen.OPENING, "hosting opens")
	fake.accept_invite(_invite())
	await _assert_kept(shell, fake, 0, GameShell.Flow.LOBBY)
	assert_eq((shell.screen as LobbyScreen).waiting.text, LobbyScreen.OPENING, "still opening")
	assert_eq(fake.calls.count("host"), 1)
	(shell.screen as LobbyScreen).leave_button.pressed.emit()
	await _assert_taken(shell, fake, 1, "taken once Salir shows the title")


func test_an_outside_join_waits_out_the_hosts_lobby() -> void:
	var fake := _fake()
	var shell := _shell()
	(shell.screen as TitleScreen).host_requested.emit()
	assert_not_null(shell.session, "hosting is ready")
	assert_eq((shell.screen as LobbyScreen).rows(), ["Balsero (anfitrión)"] as Array[String])
	fake.accept_invite(_invite())
	await _assert_kept(shell, fake, 0, GameShell.Flow.LOBBY)
	assert_not_null(shell.session, "the host's run is still there")
	assert_true(NetManager.multiplayer.is_server())
	fake.answer = false
	shell.back_to_title()
	await _assert_taken(shell, fake, 1, "taken once the title shows")


func test_an_outside_join_waits_out_a_clients_lobby() -> void:
	var fake := _fake()
	var shell := _shell()
	shell._join("127.0.0.1", NOBODY_PORT)
	assert_not_null(shell.session, "the fake answers at once: a client's run")
	if shell.session == null:
		return
	shell.session.lobby_received.emit(false)
	assert_eq(shell.flow, GameShell.Flow.LOBBY, "the client's lobby")
	assert_false((shell.screen as LobbyScreen).is_host)
	fake.accept_invite(_invite())
	await _assert_kept(shell, fake, 1, GameShell.Flow.LOBBY)
	assert_not_null(shell.session)
	fake.answer = false
	shell.back_to_title()
	await _assert_taken(shell, fake, 2, "taken once the title shows")


func test_an_outside_join_waits_out_a_join_still_connecting() -> void:
	var fake := _fake()
	var shell := _shell()
	var join := _connect_from_the_join_screen(shell, "127.0.0.1:%d" % NOBODY_PORT)
	assert_not_null(shell.session, "answered at once: the client peer is connecting")
	assert_null(NetManager.pending_request())
	fake.accept_invite(_invite())
	await _assert_kept(shell, fake, 1, GameShell.Flow.JOIN)
	assert_eq(shell.screen, join)
	assert_eq(join.address_field.text, "127.0.0.1:%d" % NOBODY_PORT, "the player's own join goes on")
	fake.answer = false
	shell.back_to_title()
	await _assert_taken(shell, fake, 2, "taken once the title shows")


func test_an_outside_join_waits_out_a_join_still_pending() -> void:
	var fake := _fake()
	fake.answer = false
	var shell := _shell()
	_connect_from_the_join_screen(shell, "127.0.0.1:%d" % NOBODY_PORT)
	assert_not_null(NetManager.pending_request(), "the join waits on the backend")
	fake.accept_invite(_invite())
	await _assert_kept(shell, fake, 1, GameShell.Flow.JOIN)
	assert_not_null(NetManager.pending_request())
	(shell.screen as JoinScreen).back_button.pressed.emit()
	await _assert_taken(shell, fake, 2, "taken once Volver shows the title")


# --- A join nobody answers ---------------------------------------------------------------------

func test_a_join_nobody_answers_says_so_on_the_join_screen() -> void:
	var fake := _fake(0.3)
	fake.answer = false
	var shell := _shell()
	watch_signals(NetManager)
	var join := _connect_from_the_join_screen(shell, "127.0.0.1:%d" % NOBODY_PORT)
	assert_not_null(NetManager.pending_request())
	assert_eq(join.status.text, JoinScreen.CONNECTING)
	assert_true(await wait_for_signal(NetManager.join_failed, 3.0), "the watchdog fired")
	assert_eq(shell.flow, GameShell.Flow.JOIN)
	assert_eq(shell.screen, join, "the same join screen")
	assert_eq(join.status.text, "El anfitrión no respondió.")
	assert_true(join.address_field.editable, "the player can try again")
	assert_false(join.connect_button.disabled)
	assert_null(shell.session)
	assert_true(_offline())
	assert_has(fake.calls, "leave")


# --- The launch line ---------------------------------------------------------------------------

func test_a_launch_argument_joins_through_the_startup_pick() -> void:
	# What NetManager._ready() does with the command line, with the line given here: the startup
	# backend from the shipped table, then use_backend() with every argument.
	var port := _free_port()
	var launch_line := PackedStringArray(["--headless", "--path", "game", "--connect=127.0.0.1:%d" % port])
	NetManager.use_backend(NetManager._startup_backend(), launch_line)
	assert_true(NetManager.backend is EnetBackend, "the startup pick is ENet")
	assert_eq(NetManager.backend_profile().id, &"enet")
	assert_eq(NetManager.startup_failure, NetFailure.Reason.NONE)
	var shell := _shell()
	assert_eq(shell.flow, GameShell.Flow.TITLE, "the title shows first")
	assert_true(await wait_until(func() -> bool: return shell.flow == GameShell.Flow.JOIN, 2.0), "then the join screen")
	var join := shell.screen as JoinScreen
	assert_eq(join.address_field.text, "127.0.0.1:%d" % port, "the target's label")
	assert_false(join.address_field.editable)
	assert_eq(join.status.text, JoinScreen.CONNECTING)
	assert_not_null(shell.session, "ENet answers at once: the run is built as a client")
	if shell.session != null:
		assert_false(shell.session.multiplayer.is_server())
	assert_true(NetManager.is_online())

extends GutTest
## build-verification "Solo offline on the shipped backend": the main scene boots to the title on
## the backend the shipped table picks (ENet), and "Jugar solo" runs on the offline peer with no
## host, join or leave call and no port opened. Exactly 1 player, offline. The smoke run boots the
## same scene but asserts nothing about the network, so the check lives here.

const SETTINGS_PATH: String = "user://test_solo_on_the_shipped_backend_settings.cfg"

var _shells: Array[GameShell] = []


## The shipped ENet backend, counting what the game asks of it.
class CountingEnet:
	extends EnetBackend

	var calls: PackedStringArray = PackedStringArray()

	func start(args: PackedStringArray) -> NetFailure.Reason:
		calls.append("start")
		return super.start(args)

	func host(request: NetRequest, port: int) -> void:
		calls.append("host")
		super.host(request, port)

	func join(request: NetRequest) -> void:
		calls.append("join")
		super.join(request)

	func leave() -> void:
		calls.append("leave")
		super.leave()


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
	if FileAccess.file_exists(SETTINGS_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS_PATH))


func _offline() -> bool:
	return NetManager.multiplayer.multiplayer_peer is OfflineMultiplayerPeer and not NetManager.is_online()


func test_solo_on_the_shipped_backend_asks_it_for_nothing() -> void:
	# The startup pick from the shipped table, with no platform feature tag: ENet, started cleanly.
	var shipped := NetManager.backend_profile()
	assert_true(NetManager.backend is EnetBackend, "the shipped table picks ENet")
	assert_not_null(shipped)
	if shipped == null:
		return
	assert_eq(shipped.id, &"enet")
	assert_eq(NetManager.startup_failure, NetFailure.Reason.NONE)
	var counting := CountingEnet.new()
	counting.profile = shipped
	NetManager.use_backend(counting)
	# The project's main scene, as the smoke run boots it.
	var main_path: String = ProjectSettings.get_setting("application/run/main_scene", "")
	var main_scene := load(main_path) as PackedScene
	assert_not_null(main_scene, "the main scene loads")
	if main_scene == null:
		return
	var shell := main_scene.instantiate() as GameShell
	assert_not_null(shell, "the main scene is the shell")
	if shell == null:
		return
	shell.settings_path = SETTINGS_PATH
	add_child(shell)
	_shells.append(shell)
	assert_eq(shell.flow, GameShell.Flow.TITLE)
	await wait_process_frames(2)
	assert_eq(counting.calls, PackedStringArray(["start"]), "booting to the title asks nothing")
	assert_true(_offline(), "no port on the title")
	(shell.screen as TitleScreen).solo_requested.emit()
	assert_eq(shell.flow, GameShell.Flow.RUN)
	assert_eq(shell.session.peer_ids(), [1] as Array[int], "one player")
	assert_true(shell.session.can_pause(), "a solo run")
	assert_true(_offline(), "the run is on the offline peer")
	assert_null(NetManager.pending_request())
	assert_null(NetManager.host_info(), "nothing hosted")
	await wait_process_frames(2)
	shell.back_to_title()
	assert_eq(counting.calls, PackedStringArray(["start"]), "no host, join or leave call")

extends GutTest
## island-stop, crossing "Fittings ride with the raft", with exactly 1 player, offline, through the
## shell: a raft with a toldo leaves the sandbar at 100 of 100 and beaches on the coast cay at 70 of
## 100 with its toldo; a nailed raft that breaks leaves an empty site, and a raft built there is at
## 100 of 100 with no fittings; nothing is sent to anyone.

const SHELL_SCENE: PackedScene = preload("res://scenes/shell/game_shell.tscn")
const COAST: StringName = &"coast_cay"
const K := CrossingBeat.Kind
var settings_path: String = UserTmp.path("test_raft_fittings_carry_settings.cfg")


func before_each() -> void:
	NetManager.start_solo()
	WeatherManager.stop()
	WeatherManager.sky.start_at(0.0)


func after_each() -> void:
	WeatherManager.stop()
	NetManager.leave()
	if FileAccess.file_exists(settings_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(settings_path))


func _shell() -> GameShell:
	var shell := SHELL_SCENE.instantiate() as GameShell
	shell.settings_path = settings_path
	add_child_autofree(shell)
	(shell.screen as TitleScreen).solo_requested.emit()
	shell.session.body(1).player_input.enabled = false
	return shell


# The sandbar's raft beached as `raft`, launched by the lone player into a 20 s crossing with a
# squall at 10 s; tied down when `tied`.
func _launch(shell: GameShell, raft: RaftRecord, tied: bool) -> Crossing:
	shell.island.beach_raft(raft)
	var built := shell.session.get_node("Raft") as Raft
	var body := shell.session.body(1)
	body.global_position = built.global_position
	assert_true(shell.session.start_route_for(1, &"raft"), "the raft launches")
	var crossing := shell.crossings[0] as Crossing
	crossing.plan = CrossingPlan.create(20.0, [CrossingRig.beat(10.0, K.SQUALL)] as Array[RefCounted])
	if tied:
		crossing.tie(1)
	return crossing


func test_solo_carries_a_toldo_to_the_coast_cay() -> void:
	var shell := _shell()
	var raft := RaftRecord.bare(100.0)
	raft.fittings = [&"raft_toldo"] as Array[StringName]
	var crossing := _launch(shell, raft, true)
	assert_eq(crossing.integrity.value, 100.0)
	assert_eq(crossing.integrity.maximum, 100.0)
	assert_eq(crossing.fitted.fittings, [&"raft_toldo"] as Array[StringName], "the toldo rides along")
	CrossingRig.run(crossing, 20.0)
	await wait_process_frames(2)
	assert_eq(shell.island.layout.id, COAST)
	var beached := shell.session.get_node_or_null("Raft") as Raft
	assert_not_null(beached, "a raft stands at the coast cay's build site")
	if beached == null:
		return
	assert_eq(beached.integrity, 70.0, "at 70")
	assert_eq(beached.max_integrity, 100.0, "of 100")
	assert_eq(beached.fittings, [&"raft_toldo"] as Array[StringName], "with the toldo")
	assert_true(shell.session.multiplayer.get_peers().is_empty(), "nothing is sent to anyone")


func test_a_broken_raft_loses_its_fittings() -> void:
	var shell := _shell()
	var raft := RaftRecord.bare(30.0, 120.0)
	raft.fittings = [&"raft_clavazon"] as Array[StringName]
	var crossing := _launch(shell, raft, false)
	CrossingRig.run(crossing, 20.0)
	assert_true(crossing.result.broken, "the squall breaks it")
	await wait_process_frames(2)
	assert_eq(shell.island.layout.id, COAST)
	assert_null(shell.session.get_node_or_null("Raft"), "no raft beached")
	var site := shell.session.get_node_or_null("RaftSite") as BuildSite
	assert_not_null(site, "the raft build site is empty")
	if site == null:
		return
	var body := shell.session.body(1)
	body.meters.health = 100.0
	body.meters.energy = 100.0
	body.global_position = site.global_position
	body.inventory.add(&"driftwood", 6)
	body.inventory.add(&"inner_tube", 2)
	body.inventory.add(&"rope", 3)
	site.deposit(body)
	site.work(1.0)
	var rebuilt := shell.session.get_node_or_null("Raft") as Raft
	assert_not_null(rebuilt, "a raft is built there")
	if rebuilt == null:
		return
	assert_eq(rebuilt.integrity, 100.0)
	assert_eq(rebuilt.max_integrity, 100.0)
	assert_eq(rebuilt.fittings, [] as Array[StringName], "with no fittings")

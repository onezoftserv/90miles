extends GutTest
## island-generation, solo and offline: the sandbar's palms, pick-ups, knife, squall refresh,
## the shell's run on it and its camera. One player alone does all of it.

const ISLAND_SCENE: PackedScene = preload("res://scenes/levels/sandbar_island.tscn")
const SESSION_SCENE: PackedScene = preload("res://scenes/net/coop_session.tscn")
const SHELL_SCENE: PackedScene = preload("res://scenes/shell/game_shell.tscn")
const SETTINGS_PATH: String = "user://test_sandbar_settings.cfg"

var island: SandbarIsland
var session: CoopSession


func before_each() -> void:
	NetManager.start_solo()
	WeatherManager.stop()
	WeatherManager.sky.start_at(0.0)


func after_each() -> void:
	WeatherManager.stop()
	NetManager.leave()
	if FileAccess.file_exists(SETTINGS_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS_PATH))


func _run() -> PlayerBody:
	island = ISLAND_SCENE.instantiate() as SandbarIsland
	add_child_autofree(island)
	session = SESSION_SCENE.instantiate() as CoopSession
	session.terrain = island.terrain
	session.spawn_points = island.spawn_points(true)
	add_child_autofree(session)
	island.furnish(session)
	session.start()
	island.place_pickups(session)
	var body := session.body(1)
	body.player_input.enabled = false
	return body


func _counts() -> Dictionary:
	var counts: Dictionary = {}
	for node: Node in session.pickups.get_children():
		var item := node as WorldItem
		if not item.is_queued_for_deletion():
			counts[item.item_id] = counts.get(item.item_id, 0) + item.count
	return counts


func _take(body: PlayerBody, item_id: StringName) -> void:
	for node: Node in session.pickups.get_children():
		var item := node as WorldItem
		if item.item_id == item_id and not item.is_queued_for_deletion():
			item.interactable.interacted.emit(body)
			await wait_frames(1)
			return


func test_the_island_builds_6_palms_and_one_workbench() -> void:
	_run()
	var palms := island.get_node("Palms")
	assert_eq(palms.get_child_count(), 6)
	var coconuts: int = 0
	for palm: Palm in palms.get_children():
		coconuts += palm.coconuts
	assert_eq(coconuts, 10)
	var bench := session.get_node_or_null("HutWorkbench") as Workbench
	assert_not_null(bench)
	assert_eq(bench.position, IslandLayout.cell_center(island.built.workbench))
	assert_true(island.terrain.is_shaded(island.built.workbench))
	assert_false(island.terrain.is_shaded(island.built.solo_spawn))


func test_the_host_places_every_pickup_once() -> void:
	_run()
	assert_eq(_counts(), {&"tarp": 1, &"driftwood": 8, &"knife": 1, &"inner_tube": 2, &"plastic_jug": 3, &"rope": 1, &"dry_grass": 3})
	assert_eq(session.pickups.get_child_count(), 19)


func test_a_solo_player_climbs_and_opens_the_coconut_with_the_hut_knife() -> void:
	var body := _run()
	body.meters.energy = 80.0
	body.meters.thirst = 50.0
	body.meters.hunger = 50.0
	await _take(body, &"knife")
	var palm := island.get_node("Palms").get_child(0) as Palm
	palm.interactable.interacted.emit(body)
	assert_eq(body.inventory.count_id(&"coco"), 1)
	assert_almost_eq(body.meters.energy, 75.0, 0.01)
	var slot: int = -1
	for i: int in body.inventory.slots.size():
		if body.inventory.slots[i].item_id == &"coco":
			slot = i
	session.use_item(slot, 0)
	assert_eq(body.inventory.count_id(&"coco"), 0)
	assert_almost_eq(body.meters.thirst, 65.0, 0.01)
	assert_almost_eq(body.meters.hunger, 55.0, 0.01)
	assert_almost_eq(body.meters.energy, 85.0, 0.5)
	for held: InventorySlot in body.inventory.slots:
		if held.item_id == &"knife":
			assert_eq(held.uses_left, 39)


func test_a_solo_player_takes_every_coconut_alone() -> void:
	var body := _run()
	body.meters.energy = 100.0
	for palm: Palm in island.get_node("Palms").get_children():
		while palm.coconuts > 0:
			palm.interactable.interacted.emit(body)
	assert_eq(body.inventory.count_id(&"coco"), 10)
	assert_almost_eq(body.meters.energy, 50.0, 0.01)
	(island.get_node("Palms").get_child(0) as Palm).interactable.interacted.emit(body)
	assert_eq(body.inventory.count_id(&"coco"), 10)
	assert_almost_eq(body.meters.energy, 50.0, 0.01)


func test_flotsam_refreshes_after_a_squall_ends() -> void:
	var body := _run()
	await _take(body, &"inner_tube")
	await _take(body, &"inner_tube")
	await _take(body, &"plastic_jug")
	await _take(body, &"knife")
	for i: int in 3:
		await _take(body, &"driftwood")
	WeatherManager.sky.weather.start_weather(&"squall")
	assert_eq(_counts().get(&"inner_tube", 0), 0, "not back while the squall falls")
	WeatherManager.sky.weather.start_weather(&"calm")
	var counts := _counts()
	assert_eq(counts.get(&"inner_tube", 0), 2)
	assert_eq(counts.get(&"plastic_jug", 0), 3, "untaken jugs are not doubled")
	assert_eq(counts.get(&"rope", 0), 1)
	assert_eq(counts.get(&"knife", 0), 0, "hut loot never comes back")
	assert_eq(counts.get(&"driftwood", 0), 6, "the beach driftwood is back; the hut's 2 pieces are not")


func test_calm_to_calm_restores_nothing() -> void:
	var body := _run()
	await _take(body, &"rope")
	WeatherManager.sky.weather.apply(&"calm", 10.0, &"", -1.0)
	assert_eq(_counts().get(&"rope", 0), 0)


func _shell() -> GameShell:
	var shell := SHELL_SCENE.instantiate() as GameShell
	shell.settings_path = SETTINGS_PATH
	shell.port = 0
	add_child_autofree(shell)
	return shell


func test_a_solo_run_starts_on_the_sandbar() -> void:
	var shell := _shell()
	(shell.screen as TitleScreen).solo_requested.emit()
	assert_true(shell.island is SandbarIsland)
	assert_true(shell.multiplayer.multiplayer_peer is OfflineMultiplayerPeer, "no network port")
	var body := shell.session.body(1)
	assert_eq(body.position, shell.island.spawn_points(true)[0])
	assert_eq(shell.session.pickups.get_child_count(), 19)
	assert_eq(shell.island.get_node("Palms").get_child_count(), 6)
	assert_eq(body.camera.limit_right, 64 * 16)
	assert_eq(body.camera.limit_bottom, 40 * 16)


func test_leaving_the_run_frees_the_island_and_pickups() -> void:
	var shell := _shell()
	(shell.screen as TitleScreen).solo_requested.emit()
	shell.back_to_title()
	assert_null(shell.island)
	assert_null(shell.session)

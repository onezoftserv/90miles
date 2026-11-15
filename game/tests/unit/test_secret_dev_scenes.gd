extends GutTest
## secret-cay "Dev scenes for the hunt and the cay" with exactly 1 player, offline: both dev scenes
## start solo with no network port, the player at the layout's solo spawn and the run HUD bound to
## that player with its needle and note label; the hunt holds the concealed map and compass; and a
## solo run from the title still starts on the sandbar with no secret item placed.

const HUNT_SCENE: PackedScene = preload("res://scenes/dev/secret_hunt_playground.tscn")
const CAY_SCENE: PackedScene = preload("res://scenes/dev/secret_cay_playground.tscn")
const SHELL_SCENE: PackedScene = preload("res://scenes/shell/game_shell.tscn")
const SETTINGS_PATH: String = "user://test_secret_dev_scenes_settings.cfg"


func before_each() -> void:
	WeatherManager.stop()


func after_each() -> void:
	WeatherManager.stop()
	NetManager.leave()
	if FileAccess.file_exists(SETTINGS_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS_PATH))


func _secret_items_lying(session: CoopSession) -> Array[StringName]:
	var found: Array[StringName] = []
	for node: Node in session.pickups.get_children():
		var item := node as WorldItem
		if item != null and SecretRules.is_secret(GameState.content.get_entry(&"items", item.item_id)):
			found.append(item.item_id)
	return found


func _assert_starts_solo(scene: SecretPlayground) -> void:
	add_child_autofree(scene)
	assert_eq(scene.mode, "", "no arguments: the panel waits")
	assert_true(scene.start(SecretPlayground.parse_args(PackedStringArray(["--solo"]))), "starts solo")
	assert_true(scene.session.multiplayer.multiplayer_peer is OfflineMultiplayerPeer, "no network port opens")
	var body := scene.session.body(CoopSession.HOST_ID)
	assert_not_null(body, "the one player")
	if body == null:
		return
	assert_eq(body.position, IslandLayout.cell_center(scene.island.built.solo_spawn), "at the solo spawn")
	assert_eq(scene.island.layout, scene.layout, "its own layout")
	assert_not_null(scene.hud, "a run HUD")
	assert_eq(scene.hud.needle.body, body, "the needle follows the local player")
	assert_eq(scene.hud.note_label.session, scene.session, "the note label follows the session")


func test_the_hunt_starts_solo() -> void:
	var scene := HUNT_SCENE.instantiate() as SecretHuntPlayground
	_assert_starts_solo(scene)
	assert_eq(scene.layout.id, &"secret_hunt")
	var lying: Array[StringName] = _secret_items_lying(scene.session)
	lying.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	assert_eq(lying, [&"brujula_rota", &"mapa_sin_norte"] as Array[StringName], "the concealed compass and map")
	for node: Node in scene.session.pickups.get_children():
		var item := node as WorldItem
		if item != null and SecretRules.is_secret(GameState.content.get_entry(&"items", item.item_id)):
			assert_true(item.concealed, "%s is concealed" % item.item_id)


func test_the_cay_starts_solo() -> void:
	var scene := CAY_SCENE.instantiate() as SecretCayPlayground
	_assert_starts_solo(scene)
	assert_eq(scene.layout.id, &"cayo_sin_norte")
	assert_not_null(scene.chest, "the chest")
	assert_eq(_secret_items_lying(scene.session), [&"sombrero_cinta_roja"] as Array[StringName], "only the hat lies there")


func test_with_pieces_gives_the_first_player_both() -> void:
	var scene := CAY_SCENE.instantiate() as SecretCayPlayground
	add_child_autofree(scene)
	var args := SecretPlayground.parse_args(PackedStringArray(["--solo", "--with-pieces"]), PackedStringArray([SecretCayPlayground.WITH_PIECES]))
	assert_eq(args["mode"], "solo")
	assert_true(scene.start(args))
	var body := scene.session.body(CoopSession.HOST_ID)
	assert_eq(body.inventory.count_id(&"brujula_rota"), 1)
	assert_eq(body.inventory.count_id(&"mapa_sin_norte"), 1)


func test_real_runs_are_unchanged() -> void:
	var shell := SHELL_SCENE.instantiate() as GameShell
	shell.settings_path = SETTINGS_PATH
	add_child_autofree(shell)
	(shell.screen as TitleScreen).solo_requested.emit()
	assert_not_null(shell.island, "a solo run started")
	assert_eq(shell.island.layout.id, &"sandbar", "on the sandbar")
	assert_eq(_secret_items_lying(shell.session), [] as Array[StringName], "no secret item placed")
	assert_null(shell.session.get_node_or_null(NodePath(Chest.NAME)), "no chest")
	assert_null(shell.session.get_node_or_null(NodePath(SecretHunt.NAME)), "no hunt")

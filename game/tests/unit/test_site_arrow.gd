extends GutTest
## hud-clarity, ui-shell "Raft-site arrow" and "When the raft-site arrow hides", with exactly 1
## player, offline: the arrow points at the raft site from the frame's edge while the site is off
## screen, in eight directions, inside (8,96)-(632,300) and off every HUD window; it goes when the
## site comes back, at sea, under the crafting list, a sign note or a screen; it follows the raft.

const SHELL_SCENE: PackedScene = preload("res://scenes/shell/game_shell.tscn")
const FRAME: Rect2 = Rect2(8.0, 96.0, 624.0, 204.0)
const MORNING_S: float = 90.0
## Far enough that the site is off a 640×360 view, in pixels.
const FAR_PX: float = 900.0

var settings_path: String = UserTmp.path("test_site_arrow_settings.cfg")


func after_each() -> void:
	WeatherManager.stop()
	NetManager.leave()
	if FileAccess.file_exists(settings_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(settings_path))


func _shell() -> GameShell:
	NetManager.start_solo()
	WeatherManager.stop()
	var shell := SHELL_SCENE.instantiate() as GameShell
	shell.settings_path = settings_path
	add_child_autofree(shell)
	(shell.screen as TitleScreen).solo_requested.emit()
	shell.session.body(1).player_input.enabled = false
	WeatherManager.sky.weather.rolls_enabled = false
	WeatherManager.sky.start_at(MORNING_S)
	return shell


func _arrow(shell: GameShell) -> SiteArrow:
	return shell.hud.get_node(^"SiteArrow") as SiteArrow


func _site(shell: GameShell) -> Node2D:
	return shell.session.get_node(^"RaftSite") as Node2D


# Stands the player at the map's centre (where the camera is never held by the map's edge) with the
# raft site `offset` pixels away from them, and lets the camera and HUD catch up.
func _stand(shell: GameShell, offset: Vector2) -> void:
	var body := shell.session.body(1)
	body.global_position = Vector2(shell.island.built.size) * 16.0 / 2.0
	body.camera.reset_smoothing()
	_site(shell).global_position = body.global_position - offset
	await wait_process_frames(3)


func test_the_eight_directions_from_the_centre() -> void:
	var c := SiteArrow.CENTRE
	var expected: Dictionary[Vector2, Vector2i] = {
		c + Vector2(500, 0): Vector2i(1, 0), c + Vector2(400, 400): Vector2i(1, 1),
		c + Vector2(0, 500): Vector2i(0, 1), c + Vector2(-400, 400): Vector2i(-1, 1),
		c + Vector2(-500, 0): Vector2i(-1, 0), c + Vector2(-400, -400): Vector2i(-1, -1),
		c + Vector2(0, -500): Vector2i(0, -1), c + Vector2(400, -400): Vector2i(1, -1),
	}
	for point: Vector2 in expected:
		assert_eq(SiteArrow.DIRECTIONS[SiteArrow.octant_of(point)], expected[point], "towards %s" % point)


func test_the_rect_stays_in_the_frame_for_every_direction() -> void:
	for step: int in 32:
		var angle: float = TAU * float(step) / 32.0
		var point: Vector2 = SiteArrow.CENTRE + Vector2.from_angle(angle) * 2000.0
		var rect := SiteArrow.place(point)
		assert_true(FRAME.encloses(rect), "%s inside the frame for %s" % [rect, point])
		assert_eq(rect.size, Vector2(9, 9))
		assert_eq(rect.position, rect.position.floor(), "whole pixels")


func test_a_solo_player_walks_off_west_of_the_site() -> void:
	var shell := _shell()
	await _stand(shell, Vector2(FAR_PX, 0.0))
	var arrow := _arrow(shell)
	assert_not_null(arrow)
	if arrow == null:
		return
	assert_true(arrow.shown(), "the site is out of view to the west")
	assert_eq(arrow.direction(), Vector2i(-1, 0), "the arrow points west")
	assert_almost_eq(arrow.arrow_rect().position.x, FRAME.position.x, 1.0, "on the frame's left edge")
	await _stand(shell, Vector2(16.0, 0.0))
	assert_false(arrow.shown(), "gone once the site is in view")


func test_the_arrow_keeps_off_the_windows() -> void:
	var shell := _shell()
	var arrow := _arrow(shell)
	for offset: Vector2 in [Vector2(FAR_PX, FAR_PX), Vector2(-FAR_PX, FAR_PX), Vector2(FAR_PX, -FAR_PX), Vector2(-FAR_PX, -FAR_PX), Vector2(0, FAR_PX), Vector2(0, -FAR_PX), Vector2(FAR_PX, 0), Vector2(-FAR_PX, 0)]:
		await _stand(shell, offset)
		assert_true(arrow.shown(), "shown for %s" % offset)
		var rect := arrow.arrow_rect()
		assert_true(FRAME.encloses(rect), "inside the frame for %s" % offset)
		for window: Rect2 in shell.hud.panel_rects():
			assert_false(rect.intersects(window), "off the window %s for %s" % [window, offset])


func test_hidden_at_sea() -> void:
	var shell := _shell()
	await _stand(shell, Vector2(FAR_PX, 0.0))
	assert_true(_arrow(shell).shown())
	(shell.session.get_node(^"Routes") as IslandRoutes).departed[1] = &"raft"
	await wait_process_frames(2)
	assert_false(_arrow(shell).shown(), "no arrow on a crossing")


func test_hidden_under_the_crafting_list_a_sign_note_and_a_screen() -> void:
	var shell := _shell()
	await _stand(shell, Vector2(FAR_PX, 0.0))
	var arrow := _arrow(shell)
	shell.hud.list_open = true
	await wait_process_frames(2)
	assert_false(arrow.shown(), "hidden while a list or note is open")
	shell.hud.list_open = false
	await wait_process_frames(2)
	assert_true(arrow.shown())
	shell.hud.set_screen_shown(true)
	await wait_process_frames(2)
	assert_false(arrow.shown(), "hidden under a screen")
	shell.hud.set_screen_shown(false)
	await wait_process_frames(2)
	assert_true(arrow.shown())


func test_it_follows_the_raft_once_built() -> void:
	var shell := _shell()
	var site := _site(shell) as BuildSite
	var at: Vector2 = site.global_position
	for id: StringName in site.recipe.inputs:
		site.deposited[id] = site.recipe.inputs[id]
	site.work(1.0)
	await wait_process_frames(2)
	var raft := shell.session.get_node_or_null(^"Raft") as Node2D
	assert_not_null(raft, "the raft is built")
	assert_eq(raft.global_position, at)
	var body := shell.session.body(1)
	body.global_position = Vector2(shell.island.built.size) * 16.0 / 2.0
	body.camera.reset_smoothing()
	raft.global_position = body.global_position + Vector2(0.0, FAR_PX)
	await wait_process_frames(3)
	assert_true(_arrow(shell).shown())
	assert_eq(_arrow(shell).direction(), Vector2i(0, 1), "points south at the raft")
	assert_eq(_arrow(shell).site(), raft)

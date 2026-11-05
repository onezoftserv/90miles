extends GutTest
## ui-shell "Pixel filter" and player-movement "Camera and viewport": the world renders in its
## own 640×360 view; Nítido keeps the window enlarging that picture with nearest filtering, Suave
## draws it at the window's resolution through the Scale2x shader. The HUD and menus stay on the
## root canvas. Solo, offline.

const SHELL_SCENE: PackedScene = preload("res://scenes/shell/game_shell.tscn")
const SETTINGS_PATH: String = "user://test_pixel_filter_settings.cfg"


func before_each() -> void:
	NetManager.start_solo()


func after_each() -> void:
	NetManager.leave()
	get_tree().root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	if FileAccess.file_exists(SETTINGS_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS_PATH))


func _shell(filter: PixelFilter.Mode = PixelFilter.Mode.SHARP) -> GameShell:
	var settings := GameSettings.new(SETTINGS_PATH)
	settings.pixel_filter = filter
	settings.save()
	var shell := SHELL_SCENE.instantiate() as GameShell
	shell.settings_path = SETTINGS_PATH
	add_child_autofree(shell)
	return shell


func test_the_world_renders_in_its_own_base_view() -> void:
	var shell := _shell()
	var view := shell.world_viewport
	assert_eq(view.size, DisplayFit.BASE_SIZE)
	assert_true(view.snap_2d_transforms_to_pixel, "the project's pixel snapping")
	assert_eq(view.canvas_item_default_texture_filter, Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST)
	assert_false(view.transparent_bg, "clears to the project colour")
	assert_eq(shell.world_view.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST)
	shell.start_solo()
	assert_eq(shell.session.get_viewport(), view, "the run is inside the world view")
	assert_eq(shell.hud.get_viewport(), get_tree().root, "the HUD is not")


func test_sharp_keeps_todays_presentation() -> void:
	var shell := _shell()
	assert_null(shell.world_view.material)
	assert_eq(get_tree().root.content_scale_mode, Window.CONTENT_SCALE_MODE_VIEWPORT)


func test_smooth_from_the_settings() -> void:
	var shell := _shell(PixelFilter.Mode.SMOOTH)
	var smooth := shell.world_view.material as ShaderMaterial
	assert_not_null(smooth, "the Scale2x shader on the world")
	if smooth != null:
		assert_eq(smooth.shader.resource_path, "res://scenes/shell/scale2x.gdshader")
	var root := get_tree().root
	assert_eq(root.content_scale_mode, Window.CONTENT_SCALE_MODE_CANVAS_ITEMS)
	assert_eq(root.content_scale_size, DisplayFit.BASE_SIZE, "the same 640×360 base")
	assert_eq(root.content_scale_stretch, Window.CONTENT_SCALE_STRETCH_INTEGER, "whole-number scale")
	assert_eq(root.content_scale_aspect, Window.CONTENT_SCALE_ASPECT_KEEP, "black bars")


func test_the_settings_screen_switches_the_filter() -> void:
	var shell := _shell()
	(shell.screen as TitleScreen).settings_requested.emit()
	var screen := shell.screen as SettingsScreen
	assert_eq(screen.filter_picker.item_count, 2)
	assert_eq(screen.filter_picker.get_item_text(0), "Nítido")
	assert_eq(screen.filter_picker.get_item_text(1), "Suave")
	assert_eq(screen.filter_picker.selected, 0)
	screen.filter_picker.select(1)
	screen.filter_picker.item_selected.emit(1)
	assert_not_null(shell.world_view.material)
	assert_eq(get_tree().root.content_scale_mode, Window.CONTENT_SCALE_MODE_CANVAS_ITEMS)
	assert_eq(GameSettings.load_from(SETTINGS_PATH).pixel_filter, PixelFilter.Mode.SMOOTH, "saved at once")
	screen.filter_picker.select(0)
	screen.filter_picker.item_selected.emit(0)
	assert_null(shell.world_view.material)
	assert_eq(get_tree().root.content_scale_mode, Window.CONTENT_SCALE_MODE_VIEWPORT)


func test_a_solo_run_in_smooth() -> void:
	var shell := _shell(PixelFilter.Mode.SMOOTH)
	(shell.screen as TitleScreen).solo_requested.emit()
	assert_eq(shell.flow, GameShell.Flow.RUN)
	assert_not_null(shell.session.body(1), "the one player spawned")
	assert_eq(shell.session.body(1).camera.get_viewport(), shell.world_viewport, "their camera drives the world view")
	assert_not_null(shell.world_view.material)
	shell.session.body(1).meters.dead = true
	assert_eq(shell.flow, GameShell.Flow.SUMMARY, "the run still ends with the summary")

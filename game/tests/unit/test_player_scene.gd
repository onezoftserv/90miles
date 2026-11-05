extends GutTest
## player-movement: the local-only camera and the committed placeholder sprite.

const PLAYER_PATH := "res://scenes/player/player.tscn"
const SPRITE_PATH := "res://assets/art/characters/player_placeholder.png"


func _spawn(local: bool) -> PlayerBody:
	var scene := load(PLAYER_PATH) as PackedScene
	var body := scene.instantiate() as PlayerBody
	body.local_player = local
	add_child_autofree(body)
	return body


func test_local_player_camera_is_enabled() -> void:
	var body := _spawn(true)
	assert_true(body.camera.enabled)


func test_remote_player_camera_is_disabled() -> void:
	var body := _spawn(false)
	assert_false(body.camera.enabled)


func test_remote_player_ignores_local_input() -> void:
	var body := _spawn(false)
	assert_false(body.get_node(^"PlayerInput").get(&"enabled"))


func test_placeholder_sprite_is_a_16x16_tracked_texture() -> void:
	var texture := load(SPRITE_PATH) as Texture2D
	assert_not_null(texture)
	assert_eq(texture.get_size(), Vector2(16.0, 16.0))
	var sprite := _spawn(true).get_node(^"Sprite") as Sprite2D
	assert_eq(sprite.texture.resource_path, SPRITE_PATH)
	assert_eq(sprite.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST)


func test_player_scene_does_not_depend_on_git_ignored_assets() -> void:
	for dependency: String in ResourceLoader.get_dependencies(PLAYER_PATH):
		assert_false(dependency.contains("res://assets/kenney/"), dependency)


func test_placeholder_license_and_credit_are_committed() -> void:
	assert_true(FileAccess.file_exists("res://assets/art/characters/License.txt"))
	var credits := FileAccess.get_file_as_string("res://assets/CREDITS.md")
	assert_true(credits.contains("player_placeholder.png"))

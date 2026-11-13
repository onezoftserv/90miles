extends GutTest
## player-movement: the local-only camera, and the player's look (art-pass "Player frames and
## anchor", "Layered player look"; design.md D1, C1): `Look/Sprite` plays 32x32 frames of the
## composite of a solo player's slot 0 look, from tracked MetroCity parts with their licence and
## credit.

const PLAYER_PATH := "res://scenes/player/player.tscn"
const ART_PATH := "res://assets/art/characters/balsero_art.tres"
const PARTS_LICENCE := "res://assets/art/characters/parts/License.txt"
const METROCITY_SOURCE := "https://jik-a-4.itch.io/metrocity-free-topdown-character-pack"


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


func test_a_solo_player_draws_32x32_frames_of_its_composed_look() -> void:
	var sprite := _spawn(true).get_node(^"Look/Sprite") as AnimatedSprite2D
	assert_not_null(sprite, "the look is drawn by Look/Sprite")
	if sprite == null:
		return
	assert_null(_spawn(true).get_node_or_null(^"Sprite"), "the old Sprite2D is gone")
	var frame := sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame) as AtlasTexture
	assert_not_null(frame)
	if frame == null:
		return
	assert_eq(frame.get_size(), Vector2(32.0, 32.0))
	var art := load(ART_PATH) as BodyArt
	assert_same(frame.atlas, LookComposer.compose(art.look_for_slot(0)).texture, "the composed atlas of slot 0's look")
	assert_eq(sprite.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST)


func test_player_scene_does_not_depend_on_git_ignored_assets() -> void:
	for dependency: String in ResourceLoader.get_dependencies(PLAYER_PATH):
		assert_false(dependency.contains("res://assets/kenney/"), dependency)


func test_the_parts_licence_and_credit_are_committed() -> void:
	assert_true(FileAccess.file_exists(PARTS_LICENCE))
	var licence := FileAccess.get_file_as_string(PARTS_LICENCE)
	assert_string_contains(licence, "Pack: MetroCity Free Top Down Character Pack")
	assert_string_contains(licence, "Source: " + METROCITY_SOURCE)
	var credits := FileAccess.get_file_as_string("res://assets/CREDITS.md")
	var row: String = ""
	for line: String in credits.split("
"):
		if line.contains("`art/characters/parts/`"):
			row = line
	assert_string_contains(row, METROCITY_SOURCE, "a CREDITS.md row for the MetroCity character parts")
	assert_false(credits.contains("player_placeholder.png"), "the placeholder's row is gone")

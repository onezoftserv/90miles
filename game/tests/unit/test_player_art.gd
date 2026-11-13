extends GutTest
## art-pass "Player frames and anchor", "Crouch pose", "Swimmers at the water line", "Drop shadows",
## "Clothing colours" and "Layered player look" on the player scene (task 5.4): the template
## balsero_frames.tres, the `Look` scene under the body (`Look/Sprite` playing the composite of
## the body's look slot, `Look/Ripple` for the dive, `Look/Shadow`), its placement on the feet line
## and its material (design.md D1, D3, D19, C1, C2). Each case is a solo, offline player, the
## look stepped by hand (no frame is awaited).

const PLAYER_PATH: String = "res://scenes/player/player.tscn"
const FRAMES_PATH: String = "res://assets/art/characters/balsero_frames.tres"
const ART_PATH: String = "res://assets/art/characters/balsero_art.tres"
const RIPPLE_PATH: String = "res://assets/art/fx/dive_ripple.tres"
const ATLAS_PATH: String = "res://assets/art/characters/parts/body_man.png"
const M := MovementStep.Move
const CELL: int = 32
const STEP_S: float = 1.0 / 60.0
const AT: Vector2 = Vector2(100.0, 100.0)
const OFFSET: Vector2 = Vector2(-16.0, -27.0)
const FEET_Y: float = 104.0
## Animation -> its cells on the frame layout (design.md C1 D3).
const CELLS: Dictionary = {
	&"idle_down": [Vector2i(0, 0)], &"idle_side": [Vector2i(0, 1)], &"idle_up": [Vector2i(0, 2)],
	&"walk_down": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0), Vector2i(4, 0), Vector2i(5, 0)],
	&"walk_side": [Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1), Vector2i(4, 1), Vector2i(5, 1)],
	&"walk_up": [Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2), Vector2i(3, 2), Vector2i(4, 2), Vector2i(5, 2)],
	&"crouch_down": [Vector2i(6, 0), Vector2i(7, 0)], &"crouch_side": [Vector2i(6, 1), Vector2i(7, 1)],
	&"crouch_up": [Vector2i(6, 2), Vector2i(7, 2)],
	&"swim_down": [Vector2i(8, 0), Vector2i(9, 0)], &"swim_side": [Vector2i(8, 1), Vector2i(9, 1)],
	&"swim_up": [Vector2i(8, 2), Vector2i(9, 2)],
	&"downed": [Vector2i(0, 3), Vector2i(1, 3)], &"dead": [Vector2i(2, 3)],
}
const FPS: Dictionary = {&"walk_down": 8.0, &"crouch_down": 4.0, &"swim_down": 4.0, &"downed": 1.0}


func before_each() -> void:
	NetManager.start_solo()


func after_each() -> void:
	NetManager.leave()


func _spawn(slot: int = 0) -> PlayerBody:
	var body := (load(PLAYER_PATH) as PackedScene).instantiate() as PlayerBody
	body.local_player = true
	body.look_slot = slot
	body.position = AT
	add_child_autofree(body)
	body.player_input.enabled = false
	_step(body, 1)
	return body


func _look(body: PlayerBody) -> PlayerLook:
	return body.get_node(^"Look") as PlayerLook


func _sprite(body: PlayerBody) -> AnimatedSprite2D:
	return body.get_node(^"Look/Sprite") as AnimatedSprite2D


func _ripple(body: PlayerBody) -> AnimatedSprite2D:
	return body.get_node(^"Look/Ripple") as AnimatedSprite2D


func _shadow(body: PlayerBody) -> DropShadow:
	return body.get_node(^"Look/Shadow") as DropShadow


func _step(body: PlayerBody, frames: int) -> void:
	for i: int in frames:
		_look(body).step(STEP_S)


# Moves the body right by `px_per_frame` for `frames` frames, stepping its look.
func _walk(body: PlayerBody, px_per_frame: Vector2, frames: int) -> void:
	for i: int in frames:
		body.position += px_per_frame
		_look(body).step(STEP_S)


func _composed(slot: int) -> ComposedLook:
	var art: BodyArt = load(ART_PATH) as BodyArt
	return LookComposer.compose(art.look_for_slot(slot))


func _frame(body: PlayerBody) -> AtlasTexture:
	var sprite: AnimatedSprite2D = _sprite(body)
	return sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame) as AtlasTexture


func _cell_of(atlas: AtlasTexture) -> Vector2i:
	return Vector2i(atlas.region.position) / CELL


# The global y where the drawn frame's lowest opaque row ends.
func _feet_y(body: PlayerBody) -> float:
	var sprite: AnimatedSprite2D = _sprite(body)
	var atlas: AtlasTexture = _frame(body)
	var image: Image = (atlas.atlas as Texture2D).get_image().get_region(Rect2i(atlas.region))
	var used: Rect2i = image.get_used_rect()
	return sprite.global_position.y + sprite.offset.y + float(used.end.y)


func test_the_template_has_every_animation_on_the_frame_layout() -> void:
	var frames: SpriteFrames = load(FRAMES_PATH) as SpriteFrames
	assert_not_null(frames)
	if frames == null:
		return
	var names: Array[String] = []
	for name: StringName in frames.get_animation_names():
		names.append(String(name))
	names.sort()
	var expected: Array[String] = []
	for name: StringName in CELLS:
		expected.append(String(name))
	expected.sort()
	assert_eq(names, expected, "D3's animations except dive")
	for name: StringName in CELLS:
		var cells: Array = CELLS[name]
		assert_eq(frames.get_frame_count(name), cells.size(), String(name))
		for index: int in mini(cells.size(), frames.get_frame_count(name)):
			var atlas: AtlasTexture = frames.get_frame_texture(name, index) as AtlasTexture
			assert_not_null(atlas, "%s[%d] is an AtlasTexture" % [name, index])
			if atlas == null:
				continue
			assert_eq(atlas.atlas.resource_path, ATLAS_PATH, "%s[%d]" % [name, index])
			assert_eq(atlas.region, Rect2(Vector2(cells[index]) * CELL, Vector2(CELL, CELL)), "%s[%d]" % [name, index])
	for name: StringName in FPS:
		assert_eq(frames.get_animation_speed(name), FPS[name], String(name))
	var tuning: ArtTuning = ArtTuning.standard()
	assert_eq(ArtChecks.check_frame_budget(FRAMES_PATH, frames, tuning.max_unique_frames, tuning.max_fps), PackedStringArray())
	assert_lte(ArtChecks.total_unique_frames(frames), tuning.max_character_frames)


func test_the_dive_ripple_is_its_own_two_frame_animation() -> void:
	var ripple: SpriteFrames = load(RIPPLE_PATH) as SpriteFrames
	assert_not_null(ripple)
	if ripple == null:
		return
	assert_true(ripple.has_animation(&"dive"))
	assert_eq(ripple.get_frame_count(&"dive"), 2)
	assert_eq(ripple.get_animation_speed(&"dive"), 4.0)


func test_a_solo_player_plays_slot_0s_composite() -> void:
	var body: PlayerBody = _spawn()
	assert_eq(body.look_slot, 0)
	var sprite: AnimatedSprite2D = _sprite(body)
	assert_not_null(sprite.sprite_frames)
	assert_same(_frame(body).atlas, _composed(0).texture, "drawn from the composite of slot 0's look")
	assert_eq(sprite.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST)
	assert_false(sprite.centered)


func test_a_player_in_slot_1_plays_slot_1s_composite() -> void:
	var body: PlayerBody = _spawn(1)
	assert_same(_frame(body).atlas, _composed(1).texture)
	body.look_slot = 2
	_step(body, 1)
	assert_same(_frame(body).atlas, _composed(2).texture, "composed again when the slot is set")


func test_a_solo_player_standing_at_100_100() -> void:
	# art-pass "A solo player standing".
	var body: PlayerBody = _spawn()
	var sprite: AnimatedSprite2D = _sprite(body)
	assert_eq(String(sprite.animation), "idle_down")
	assert_eq(sprite.offset, OFFSET)
	assert_eq(sprite.global_position, AT, "centred on x 100: the frame spans 84 to 116")
	assert_eq(_feet_y(body), FEET_Y, "the lowest opaque row ends at y 104")
	for name: StringName in [&"walk_down", &"walk_side", &"walk_up", &"crouch_down"]:
		sprite.play(name)
		for index: int in sprite.sprite_frames.get_frame_count(name):
			sprite.frame = index
			assert_eq(sprite.offset, OFFSET, "%s[%d] at the same offset" % [name, index])
			assert_eq(_frame(body).get_size(), Vector2(CELL, CELL))
	var shape := body.get_node(^"CollisionShape") as CollisionShape2D
	assert_eq((shape.shape as CircleShape2D).radius, 6.0)
	assert_eq(shape.position, Vector2.ZERO)


func test_a_crouching_player_keeps_full_frames_on_the_same_feet_line() -> void:
	# art-pass "A solo player crouches in brush".
	var body: PlayerBody = _spawn()
	body.movement_state = M.CROUCH
	_step(body, 2)
	var sprite: AnimatedSprite2D = _sprite(body)
	assert_eq(String(sprite.animation), "crouch_down")
	assert_eq(_frame(body).get_size(), Vector2(CELL, CELL), "full 32x32 frames")
	assert_eq(sprite.offset, OFFSET)
	assert_eq(_feet_y(body), FEET_Y, "the feet line unchanged")


func test_a_slot_0_swimmer_is_cut_at_the_feet_line_with_no_shadow() -> void:
	# art-pass "Swim and dive"; design.md C1 D6.
	var body: PlayerBody = _spawn()
	body.movement_state = M.SWIM
	_walk(body, Vector2(0.5, 0.0), 12)
	var sprite: AnimatedSprite2D = _sprite(body)
	assert_eq(String(sprite.animation), "swim_side")
	var material: ShaderMaterial = sprite.material as ShaderMaterial
	assert_not_null(material)
	if material == null:
		return
	assert_eq(material.get_shader_parameter(&"water_line_on"), true)
	assert_eq(material.get_shader_parameter(&"water_line_y"), 4.0)
	assert_eq(material.get_shader_parameter(&"slot_row"), 1)
	assert_eq(sprite.offset, OFFSET + Vector2(0.0, 12.0), "sunk 12 px through the offset")
	assert_eq(sprite.position, Vector2.ZERO, "never through the node's position")
	assert_false(_shadow(body).visible, "no shadow on a swimmer")
	assert_false(_ripple(body).visible, "the ripple is the dive's")


func test_a_diver_shows_only_the_ripple() -> void:
	var body: PlayerBody = _spawn()
	body.movement_state = M.DIVE
	_step(body, 2)
	assert_false(_sprite(body).visible, "Look/Sprite is hidden")
	assert_false(_shadow(body).visible)
	var ripple: AnimatedSprite2D = _ripple(body)
	assert_true(ripple.visible)
	assert_eq(ripple.sprite_frames.resource_path, RIPPLE_PATH)
	assert_eq(String(ripple.animation), "dive")
	assert_true(ripple.is_playing())


func test_each_player_has_its_own_material() -> void:
	var first: PlayerBody = _spawn(0)
	var second: PlayerBody = _spawn(3)
	assert_ne(_sprite(first).material, _sprite(second).material, "local to scene")
	assert_eq((_sprite(second).material as ShaderMaterial).get_shader_parameter(&"slot_row"), 4)
	assert_eq((_sprite(first).material as ShaderMaterial).get_shader_parameter(&"water_line_on"), false, "dry on land")


func test_a_standing_solo_player_has_the_12x7_shadow_at_its_feet() -> void:
	# art-pass "Shadows on the sandbar".
	var body: PlayerBody = _spawn()
	var shadow: DropShadow = _shadow(body)
	assert_true(shadow.visible)
	assert_eq(shadow.texture.get_size(), Vector2(12.0, 7.0))
	var rect: Rect2 = shadow.get_global_transform() * shadow.get_rect()
	assert_almost_eq(rect.get_center().x, AT.x, 1.0, "centred under the body")
	assert_true(rect.position.y < FEET_Y and rect.end.y >= FEET_Y, "across the feet line: %s" % rect)
	assert_lt(shadow.z_index, 0, "under the body")


func test_a_slot_0_swimmers_clothing_maps_the_key_ramp_to_azul() -> void:
	# art-pass "A swimmer keeps its colours", through the reference mapping (design.md K32).
	var body: PlayerBody = _spawn()
	body.movement_state = M.SWIM
	_step(body, 2)
	var material: ShaderMaterial = _sprite(body).material as ShaderMaterial
	var ramps_texture: Texture2D = material.get_shader_parameter(&"ramps") as Texture2D
	assert_not_null(ramps_texture)
	if ramps_texture == null:
		return
	assert_eq(ramps_texture.resource_path, ArtTuning.standard().player_ramps.resource_path)
	var ramps: Image = ArtChecks.read_png(ramps_texture.resource_path)
	var slot_row: int = material.get_shader_parameter(&"slot_row")
	for shade: int in PaletteSwap.SHADES:
		var key: Color = ramps.get_pixel(shade, PaletteSwap.KEY_ROW)
		var drawn: Color = PaletteSwap.map_color(key, ramps, slot_row)
		assert_eq(drawn.to_html(false), ramps.get_pixel(shade, 1).to_html(false), "key shade %d to azul" % shade)


func test_a_solo_player_who_walks_crouches_swims_and_is_downed_is_drawn_from_those_cells() -> void:
	# art-pass "A look built from parts".
	var body: PlayerBody = _spawn()
	var texture: Texture2D = _composed(0).texture
	_walk(body, Vector2(0.0, 1.0), 12)
	assert_eq(String(_sprite(body).animation), "walk_down")
	assert_has(CELLS[&"walk_down"], _cell_of(_frame(body)))
	body.movement_state = M.CROUCH
	_walk(body, Vector2(0.0, 0.5), 12)
	assert_eq(String(_sprite(body).animation), "crouch_down")
	assert_has(CELLS[&"crouch_down"], _cell_of(_frame(body)))
	body.movement_state = M.SWIM
	_walk(body, Vector2(0.0, 0.5), 12)
	assert_eq(String(_sprite(body).animation), "swim_down")
	assert_has(CELLS[&"swim_down"], _cell_of(_frame(body)))
	body.movement_state = M.WALK
	body.downed = true
	_step(body, 2)
	assert_eq(String(_sprite(body).animation), "downed")
	assert_has(CELLS[&"downed"], _cell_of(_frame(body)))
	assert_same(_frame(body).atlas, texture, "every pose from the one composite")
	body.meters.dead = true
	_step(body, 2)
	assert_eq(String(_sprite(body).animation), "dead", "dead, never the downed breathing frame")
	assert_eq(_cell_of(_frame(body)), Vector2i(2, 3))

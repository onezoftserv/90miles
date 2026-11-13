extends GutTest
## art-pass "Creature frames from data", "Creature motion on every peer", "The sandbar's
## creatures", "Drop shadows", "Actors stand out from the ground" and "Frame budget" (design.md
## D16, D19, D21, K4, K15): every shipped creature has frames with an idle within the budget; a
## boss proxy needs none and draws nothing; a new creature plays its state frames on the host and
## on a client with no script; a client's crab scuttles steadily; the shark is drawn at the water
## line with no shadow and its fin stands out on water; a crab and a flying gull have their
## shadows on the ground; a perched gull stands at its palm's crown nest point and sorts over the
## crown, on the host and on a client and with exactly 1 player, offline.
##
## The perched gull's feet are compared with the crown nest point of the real palm's look (group 8;
## design.md K64).

const FRAME_S: float = 1.0 / 60.0
const TIMEOUT_S: float = 5.0
const SHELL_SCENE: PackedScene = preload("res://scenes/shell/game_shell.tscn")
const PALM_SCENE: PackedScene = preload("res://scenes/levels/palm.tscn")
const WATERLINE_SHADER: String = "res://scenes/art/waterline.gdshader"
const CREATURE_ART: String = "res://assets/art/creatures/creature_art.tres"
const FIXTURE_ROOT: String = "res://tests/fixtures/art/creatures/content"
const SETTINGS_PATH: String = "user://test_creature_art_settings.cfg"
const TILE: float = 16.0
## The gull's lift in flight (design.md D16).
const AIR_LIFT_PX: float = 8.0
## SwoopSteal's and PatrolCircleStrike's states.
const PERCH: int = 0
const SWOOP: int = 1
const PATROL: int = 0
const CIRCLE: int = 2

var net: NetHarness


func before_each() -> void:
	net = NetHarness.new(self)


func after_each() -> void:
	net.teardown()
	WeatherManager.stop()
	NetManager.leave()
	if FileAccess.file_exists(SETTINGS_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS_PATH))


func _data(id: StringName) -> CreatureData:
	return GameState.content.get_entry(&"creatures", id) as CreatureData


func _art() -> CreatureArt:
	return load(CREATURE_ART) as CreatureArt


func _look(creature: Node) -> CreatureLook:
	return creature.get_node_or_null(^"Look") as CreatureLook


func _sprite(creature: Node) -> AnimatedSprite2D:
	return creature.get_node_or_null(^"Look/Sprite") as AnimatedSprite2D


func _shadow(creature: Node) -> DropShadow:
	return creature.get_node_or_null(^"Look/Shadow") as DropShadow


# The global y of the bottom edge of the sprite's current frame (frames are centred, no offset).
func _feet_y(sprite: AnimatedSprite2D) -> float:
	var frame: Texture2D = sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
	return sprite.global_position.y + frame.get_size().y / 2.0


func _step(creature: Node, frames: int = 1) -> void:
	for frame: int in frames:
		_look(creature).step(FRAME_S)


func _frames_only(names: Array[StringName]) -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	var texture := ImageTexture.create_from_image(Image.create(16, 16, false, Image.FORMAT_RGBA8))
	for animation: StringName in names:
		frames.add_animation(animation)
		frames.add_frame(animation, texture)
	return frames


func _fixture_catalog(session: CoopSession) -> void:
	session.creature_catalog = ContentCatalog.new(FIXTURE_ROOT)


func _client_creature(client: CoopSession) -> Creature:
	if not await wait_until(func() -> bool: return client.entities.get_child_count() == 1, TIMEOUT_S):
		return null
	return client.entities.get_child(0) as Creature


# --- the shipped frames --------------------------------------------------------------------------

func test_every_creature_has_frames_with_an_idle_within_the_budget() -> void:
	var tuning := ArtTuning.standard()
	var checked: int = 0
	for id: StringName in GameState.content.list_ids(&"creatures"):
		var data := _data(id)
		assert_eq(CreatureArt.frames_problems(data), PackedStringArray(), String(id))
		if data.sprite_frames == null:
			continue
		checked += 1
		assert_eq(ArtChecks.check_frame_budget(String(id), data.sprite_frames, tuning.max_creature_frames, tuning.max_fps), PackedStringArray())
	assert_gte(checked, 3, "the shark, the crab and the gull")


func test_frames_with_only_idle_side_fail() -> void:
	var data := CreatureData.new()
	data.id = &"fixture_side_only"
	data.sprite_frames = _frames_only([&"idle_side", &"move_side"])
	var problems := CreatureArt.frames_problems(data)
	assert_eq(problems.size(), 1)
	assert_string_contains(problems[0] if not problems.is_empty() else "", "fixture_side_only")
	data.sprite_frames = _frames_only([&"idle_side", &"idle_up", &"idle_down"])
	assert_eq(CreatureArt.frames_problems(data), PackedStringArray(), "the three facing variants count as idle")
	data.sprite_frames = null
	assert_eq(CreatureArt.frames_problems(data).size(), 1, "no frames at all")


func test_a_weather_proxy_needs_no_frames_and_its_look_draws_nothing() -> void:
	var proxy := CreatureData.new()
	proxy.id = &"fixture_huracan"
	proxy.category = CreatureData.Category.ENVIRONMENT
	proxy.boss_kind = CreatureData.BossKind.WEATHER
	assert_eq(CreatureArt.frames_problems(proxy), PackedStringArray())
	var rig := CreatureRig.make(self)
	var made := rig.creature(&"", Vector2i(10, 10), proxy)
	_step(made, 10)
	var sprite := _sprite(made)
	assert_not_null(sprite, "the proxy has the look too")
	if sprite == null:
		return
	assert_false(sprite.visible, "draws nothing")
	assert_false(sprite.is_playing(), "never plays")
	assert_null(sprite.sprite_frames)
	assert_false(_shadow(made).visible, "and casts no shadow")


# --- data, not code ------------------------------------------------------------------------------

func test_a_new_creature_plays_its_state_frames_on_the_host_and_a_client_with_no_script() -> void:
	var host := net.add_host(_fixture_catalog)
	var client := await net.join(_fixture_catalog)
	var data := host.creature_catalog.get_entry(&"creatures", &"tiburon_prueba") as CreatureData
	assert_not_null(data, "the fixture file loads as a creature")
	var shark := host.spawn_creature(data, Vector2(200.0, 200.0))
	var theirs: Creature = await _client_creature(client)
	assert_not_null(theirs, "the client has it")
	if theirs == null:
		return
	assert_eq((shark.get_script() as Script).resource_path, "res://scenes/creatures/creature.gd", "the generic creature script")
	var both_play := func(animation: StringName) -> bool:
		return _sprite(shark).animation == animation and _sprite(theirs).animation == animation and _sprite(theirs).is_playing()
	assert_true(await wait_until(both_play.bind(&"patrol"), TIMEOUT_S), "both play patrol")
	shark.state_id = CIRCLE
	assert_true(await wait_until(both_play.bind(&"circle"), TIMEOUT_S), "then both play circle")


# --- motion --------------------------------------------------------------------------------------

func test_a_client_crab_fed_positions_at_10_hz_plays_move_every_frame_then_idle() -> void:
	var rig := CreatureRig.make(self)
	var crab := rig.creature(&"land_crab", Vector2i(3, 10))
	_step(crab)
	var sprite := _sprite(crab)
	var not_moving: Array[int] = []
	for frame: int in 60:
		if frame % 6 == 0:
			crab.position += Vector2(1.6, 0.0)
		_step(crab)
		if sprite.animation != &"move":
			not_moving.append(frame)
	assert_eq(not_moving, [] as Array[int], "move on every frame of 1 s")
	_step(crab, 3)
	assert_eq(sprite.animation, &"move", "0.133 s after the last change")
	_step(crab, 3)
	assert_eq(sprite.animation, &"idle", "idle 0.15 s after the last change")


# --- the sandbar's creatures ---------------------------------------------------------------------

func test_the_shark_draws_at_the_water_line_with_no_shadow() -> void:
	var rig := CreatureRig.make(self)
	var shark := rig.creature(&"reef_shark", Vector2i(20, 10))
	_step(shark)
	var sprite := _sprite(shark)
	var material := sprite.material as ShaderMaterial
	assert_not_null(material, "a shader material")
	if material == null:
		return
	assert_eq(material.shader.resource_path, WATERLINE_SHADER)
	var entry := _art().entry(&"reef_shark")
	assert_true(entry.water_line)
	var frame: Texture2D = sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
	assert_eq(material.get_shader_parameter(&"water_line_y"), entry.water_line_px - frame.get_size().y / 2.0, "the line in the sprite's own px")
	assert_false(_shadow(shark).visible, "no shadow under the fin")
	assert_eq(sprite.animation, &"patrol")


func test_the_shark_fin_stands_out_on_shallows_and_deep_water() -> void:
	var tuning := ArtTuning.standard()
	var grounds: Dictionary[StringName, Color] = {&"shallows": tuning.water_grounds[&"shallows"], &"deep": tuning.water_grounds[&"deep"]}
	var entry := _art().entry(&"reef_shark")
	var frames := _data(&"reef_shark").sprite_frames
	var failures: PackedStringArray = []
	var checked: int = 0
	for animation: StringName in frames.get_animation_names():
		for index: int in frames.get_frame_count(animation):
			var atlas := frames.get_frame_texture(animation, index) as AtlasTexture
			var cell: Image = ArtChecks.read_png(atlas.atlas.resource_path).get_region(Rect2i(atlas.region))
			var above := Rect2i(0, 0, cell.get_width(), int(entry.water_line_px))
			failures.append_array(ArtChecks.check_water_contrast("reef_shark %s[%d]" % [animation, index], cell, above, grounds, tuning.contrast_min))
			checked += 1
	assert_eq(failures, PackedStringArray())
	assert_gt(checked, 0)


func test_a_solo_crab_on_the_sand_has_its_shadow_under_it() -> void:
	var rig := CreatureRig.make(self)
	var crab := rig.creature(&"land_crab", Vector2i(3, 10))
	_step(crab)
	var shadow := _shadow(crab)
	var sprite := _sprite(crab)
	assert_true(shadow.visible, "a shadow")
	assert_true(sprite.visible)
	assert_null(sprite.material, "no water line on land")
	assert_eq(shadow.global_position.x, crab.global_position.x)
	assert_between(shadow.global_position.y, crab.global_position.y, _feet_y(sprite), "between the crab's position and its feet")
	assert_lt(DrawOrder.absolute_z(shadow), DrawOrder.absolute_z(sprite), "under the crab")
	assert_true(DrawOrder.drawn_after(sprite, shadow))
	var entry := _art().entry(&"land_crab")
	assert_eq(_feet_y(sprite), crab.global_position.y + entry.foot_px, "its feet on the creature art's foot line")


func test_a_flying_gulls_shadow_stays_on_the_ground_8_px_below_its_sprite() -> void:
	var rig := CreatureRig.make(self)
	var gull := rig.creature(&"seagull", Vector2i(3, 10))
	gull.state_id = SWOOP
	_step(gull)
	var entry := _art().entry(&"seagull")
	var sprite := _sprite(gull)
	var shadow := _shadow(gull)
	assert_eq(entry.air_lift_px, AIR_LIFT_PX)
	assert_true(shadow.visible, "a flying gull has a shadow")
	assert_eq(_feet_y(sprite), gull.global_position.y + entry.foot_px - AIR_LIFT_PX, "the sprite lifted 8 px")
	assert_eq(shadow.global_position.y, gull.global_position.y + entry.shadow_y_px, "the shadow where a standing gull's would be")
	assert_between(entry.shadow_y_px, 0.0, entry.foot_px, "on the ground under the gull")
	assert_true(sprite.animation.begins_with("move"), "flying")


# The palm as drawn: its look, after one step (design.md K64).
func _palm_look(palm: Palm) -> StructureLook:
	var look := palm.get_node(NodePath(StructureLook.NODE_NAME)) as StructureLook
	look.step()
	return look


# A gull perched at its nest: the look node 1 px south, the feet on the palm look's nest point, no
# shadow, the synced position untouched.
func _assert_perched(gull: Creature, at: Vector2, palm: Palm, peer: String) -> void:
	var look := _look(gull)
	var sprite := _sprite(gull)
	assert_eq(gull.position, at, "%s: the synced position untouched" % peer)
	assert_true(gull.y_sort_enabled, "%s: Creature is y-sorted" % peer)
	assert_eq(look.position, Vector2(0.0, 1.0), "%s: the look node 1 px south of the trunk base" % peer)
	var feet := Vector2(sprite.global_position.x, _feet_y(sprite))
	assert_eq(feet, _palm_look(palm).nest_point(), "%s: the feet on the palm look's crown nest point" % peer)
	assert_false(_shadow(gull).visible, "%s: no shadow of its own" % peer)
	assert_true(sprite.animation.begins_with("idle"), "%s: standing" % peer)


func test_a_perched_gull_stands_in_the_crown_on_the_host_and_a_client() -> void:
	var host := net.add_host()
	var client := await net.join()
	var at := Vector2(200.0, 200.0)
	var gull := host.spawn_creature(_data(&"seagull"), at)
	var theirs: Creature = await _client_creature(client)
	assert_not_null(theirs)
	if theirs == null:
		return
	var palms: Array[Node2D] = []
	for session: CoopSession in [host, client]:
		var palm := PALM_SCENE.instantiate() as Palm
		palm.position = at
		session.add_child(palm)
		palms.append(palm)
	await wait_frames(3)
	assert_eq(theirs.state_id, PERCH)
	_assert_perched(gull, at, palms[0] as Palm, "host")
	_assert_perched(theirs, at, palms[1] as Palm, "client")
	assert_true(DrawOrder.drawn_after(_sprite(gull), _palm_look(palms[0] as Palm).still), "host: over the crown")
	assert_true(DrawOrder.drawn_after(_sprite(theirs), _palm_look(palms[1] as Palm).still), "client: over the crown")


func test_a_solo_players_perched_gull_sorts_over_its_palm_and_behind_a_player_south_of_it() -> void:
	NetManager.start_solo()
	WeatherManager.stop()
	WeatherManager.sky.start_at(0.0)
	var shell := SHELL_SCENE.instantiate() as GameShell
	shell.settings_path = SETTINGS_PATH
	add_child_autofree(shell)
	(shell.screen as TitleScreen).solo_requested.emit()
	var body := shell.session.body(CoopSession.HOST_ID)
	body.player_input.enabled = false
	await wait_physics_frames(2)
	var spawner := shell.session.get_node(^"Creatures") as CreatureSpawner
	var gulls := spawner.creatures(&"seagull")
	assert_gt(gulls.size(), 0, "gulls at the nest palms")
	if gulls.is_empty():
		return
	var gull: Creature = null
	for each: Creature in gulls:
		if each.state_id == PERCH:
			gull = each
	assert_not_null(gull, "a perched gull")
	if gull == null:
		return
	var palm: Palm = null
	for node: Node in shell.island.get_node(^"Palms").get_children():
		if (node as Palm).global_position == gull.global_position:
			palm = node as Palm
	assert_not_null(palm, "the gull sits on a palm's trunk base")
	if palm == null:
		return
	_assert_perched(gull, gull.position, palm, "solo")
	assert_true(DrawOrder.drawn_after(_sprite(gull), _palm_look(palm).still), "over the crown")
	assert_true(_palm_look(palm).nest.visible, "on a nest palm, its nest drawn")
	body.global_position = palm.global_position + Vector2(0.0, TILE)
	assert_true(DrawOrder.drawn_after(body, _sprite(gull)), "behind a player one tile south of the palm")
	body.global_position = palm.global_position + Vector2(0.0, -TILE)
	assert_true(DrawOrder.drawn_after(_sprite(gull), body), "over a player one tile north of it")

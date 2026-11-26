extends GutTest
## art-pass "Palms", "Camp structures", "Raft site and raft" and "Drop shadows" on the real nodes
## (design.md D18, T6-T10, K87), with exactly 1 player, offline: each structure's StructureLook
## shows the frame StructureArt picks for the state it reads every frame, standing bottom-centre on
## the structure's origin. test_structure_art.gd checks the rules themselves.

const PALM_SCENE: PackedScene = preload("res://scenes/levels/palm.tscn")
const FIRE_SCENE: PackedScene = preload("res://scenes/structures/fire.tscn")
const CATCHER_SCENE: PackedScene = preload("res://scenes/structures/rain_catcher.tscn")
const RAFT_SCENE: PackedScene = preload("res://scenes/structures/raft.tscn")
const SITE_SCENE: PackedScene = preload("res://scenes/structures/build_site.tscn")
const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")
const SHELL_SCENE: PackedScene = preload("res://scenes/shell/game_shell.tscn")
const SANDBAR: IslandLayoutData = preload("res://resources/islands/sandbar.tres")
var settings_path: String = UserTmp.path("test_structure_looks_settings.cfg")

var data: StructureArtData
var body: PlayerBody
var arena: Node2D


func before_each() -> void:
	NetManager.start_solo()
	data = StructureArtData.standard()
	body = PLAYER_SCENE.instantiate() as PlayerBody
	add_child_autofree(body)
	body.player_input.enabled = false
	arena = Node2D.new()
	add_child_autofree(arena)


func after_each() -> void:
	WeatherManager.stop()
	if FileAccess.file_exists(settings_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(settings_path))


func _look(structure: Node) -> StructureLook:
	return structure.get_node_or_null(NodePath(StructureLook.NODE_NAME)) as StructureLook


# The look drawn now, after one step.
func _drawn(structure: Node) -> StructureLook:
	var look := _look(structure)
	look.step()
	return look


# The methods a node's own script (and the scripts it extends) define.
func _script_methods(node: Object) -> PackedStringArray:
	var methods: PackedStringArray = []
	for method: Dictionary in (node.get_script() as Script).get_script_method_list():
		methods.append(method["name"])
	return methods


func _raft_recipe() -> RecipeData:
	return GameState.content.get_entry(&"recipes", &"raft") as RecipeData


# The offset of the sprite the look shows, and the offset its frame should have.
func _assert_stands_on_origin(look: StructureLook, what: String) -> void:
	var shown: Node2D = look.sprite if look.sprite.visible else look.still
	var size: Vector2
	var offset: Vector2
	if shown == look.sprite:
		size = look.sprite.sprite_frames.get_frame_texture(look.sprite.animation, 0).get_size()
		offset = look.sprite.offset
	else:
		size = look.still.texture.get_size()
		offset = look.still.offset
	assert_eq(offset, StructureArt.frame_offset(size), "%s stands bottom-centre on its origin" % what)
	assert_eq(look.position, Vector2.ZERO, "%s: the look sits on the structure's origin" % what)


func test_every_look_is_drawing_only() -> void:
	var made: Array[Node] = [PALM_SCENE.instantiate(), FIRE_SCENE.instantiate(), CATCHER_SCENE.instantiate(),
		RAFT_SCENE.instantiate(), SITE_SCENE.instantiate(), Workbench.new(), IslandSign.new()]
	for structure: Node in made:
		var look := _look(structure)
		assert_not_null(look, "%s has its look before it enters the tree" % structure.name)
		if look != null:
			assert_true(look.is_in_group(&"art_view"), "%s's look is in art_view" % structure.name)
			assert_false(_script_methods(look).has("_enter_tree"), "no _enter_tree")
		assert_false(_script_methods(structure).has("_draw"), "%s draws nothing itself" % structure.name)
		structure.free()
	var spot := DrinkSpot.new()
	assert_null(_look(spot), "a drink spot has no look")
	assert_false(_script_methods(spot).has("_draw"), "and no _draw")
	spot.free()


func test_a_palm_look_shows_its_coconuts_up_to_three() -> void:
	var palm := PALM_SCENE.instantiate() as Palm
	arena.add_child(palm)
	var drawn: Array[int] = []
	for coconuts: int in [0, 1, 2, 3, 5]:
		palm.coconuts = coconuts
		drawn.append(_drawn(palm).coconuts_drawn())
	assert_eq(drawn, [0, 1, 2, 3, 3] as Array[int])
	var look := _look(palm)
	assert_true(look.still.visible, "the palm itself")
	assert_eq(look.still.texture, data.palm)
	assert_eq(look.coconuts.offset, look.still.offset, "the overlay lies on the palm's frame")
	assert_false(look.nest.visible, "a palm off an island has no nest")
	assert_eq(look.shadow.size, DropShadow.Size.LARGE)
	_assert_stands_on_origin(look, "the palm")


func test_on_the_sandbar_the_nest_shows_on_palms_4_and_5_and_a_solo_climb_leaves_it_and_1_coconut() -> void:
	NetManager.start_solo()
	WeatherManager.stop()
	WeatherManager.sky.start_at(0.0)
	var shell := SHELL_SCENE.instantiate() as GameShell
	shell.settings_path = settings_path
	add_child_autofree(shell)
	(shell.screen as TitleScreen).solo_requested.emit()
	var player := shell.session.body(CoopSession.HOST_ID)
	player.player_input.enabled = false
	var palms := shell.island.get_node(^"Palms").get_children()
	var nests: Array[int] = []
	for index: int in palms.size():
		assert_true(palms[index] is Palm, "Palms holds only palms")
		if _drawn(palms[index]).nest.visible:
			nests.append(index)
	assert_eq(nests, [4, 5] as Array[int])
	var palm := palms[SANDBAR.nest_palms[0]] as Palm
	palm.coconuts = 2
	palm.interactable.interacted.emit(player)
	var look := _drawn(palm)
	assert_true(look.nest.visible, "the nest stays")
	assert_eq(look.coconuts_drawn(), 1, "1 coconut left")
	assert_eq(look.nest_point(), palm.global_position + Vector2(0.0, -34.0), "the crown's nest point")
	WeatherManager.stop()
	NetManager.leave()


# A solo run on the sandbar, its player still.
func _solo_shell() -> GameShell:
	NetManager.start_solo()
	WeatherManager.stop()
	WeatherManager.sky.start_at(0.0)
	var shell := SHELL_SCENE.instantiate() as GameShell
	shell.settings_path = settings_path
	add_child_autofree(shell)
	(shell.screen as TitleScreen).solo_requested.emit()
	shell.session.body(CoopSession.HOST_ID).player_input.enabled = false
	return shell


# The look each palm of the island draws, in layout order.
func _palm_looks(shell: GameShell) -> Array[int]:
	var looks: Array[int] = []
	for palm: Node in shell.island.get_node(^"Palms").get_children():
		looks.append(_drawn(palm).palm_look)
	return looks


## art-prop-polish D4 (QP1 (a)): a palm off an island draws today's look; a look shown draws its own
## frame with the coconut and nest overlays on it, every look keeping the nest point.
func test_a_palm_look_draws_its_own_frame_under_the_coconuts() -> void:
	var palm := PALM_SCENE.instantiate() as Palm
	arena.add_child(palm)
	var look := _drawn(palm)
	assert_eq(look.palm_look, 0, "a palm off an island draws today's look")
	assert_eq(data.palm_look_count(), 3, "QP1 (a): three looks")
	for index: int in data.palm_look_count():
		look.palm_look = index
		for coconuts: int in [1, 2, 3]:
			palm.coconuts = coconuts
			look.step()
			assert_eq(look.still.texture, data.palm_texture(index), "look %d: its own frame" % index)
			assert_eq(look.coconuts_drawn(), coconuts, "look %d: %d coconuts drawn" % [index, coconuts])
			assert_eq(look.coconuts.offset, look.still.offset, "look %d: the overlay on the frame" % index)
		_assert_stands_on_origin(look, "palm look %d" % index)
		assert_eq(look.nest_point(), palm.global_position + Vector2(0.0, -34.0), "look %d: the nest point holds" % index)


## The 1-player test of art-prop-polish 4.1: the sandbar built twice for one offline player uses
## more than one look, the same look per palm both times, each the cell's hash.
func test_the_sandbar_built_twice_for_one_offline_player_draws_the_same_mixed_palm_looks() -> void:
	var first := _solo_shell()
	await wait_physics_frames(2)
	var looks := _palm_looks(first)
	first.queue_free()
	WeatherManager.stop()
	NetManager.leave()
	await wait_process_frames(1)
	var second := _solo_shell()
	await wait_physics_frames(2)
	assert_eq(_palm_looks(second), looks, "the same look per palm both times")
	var built := IslandLayout.build(SANDBAR)
	assert_eq(looks.size(), built.palms.size(), "a look per palm")
	var seen: Dictionary[int, bool] = {}
	for index: int in looks.size():
		seen[looks[index]] = true
		assert_eq(looks[index], StructureArt.palm_look(SANDBAR.id, built.palms[index], data.palm_look_count()),
			"palm %d: its cell's look" % index)
	assert_gt(seen.size(), 1, "more than one look on the sandbar: %s" % [looks])
	WeatherManager.stop()
	NetManager.leave()


func test_a_solo_fire_look_flickers_while_lit_and_shows_embers_once_out() -> void:
	var fire := FIRE_SCENE.instantiate() as Fire
	arena.add_child(fire)
	fire.light()
	var look := _drawn(fire)
	assert_eq(look.frame(), StructureArt.FIRE_LIT)
	assert_true(look.sprite.is_playing(), "the flicker plays")
	assert_false(look.shadow.visible, "a fire has no shadow")
	_assert_stands_on_origin(look, "the fire")
	fire.advance(fire.tuning.fire_burn_s + 1.0)
	assert_eq(_drawn(fire).frame(), StructureArt.FIRE_OUT)


# The image of the frame `look` shows now.
func _frame_image(look: StructureLook) -> Image:
	var sprite := look.sprite as AnimatedSprite2D
	return sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame).get_image()


## art-prop-polish D3 (PR8), with exactly 1 player, offline: the rain catcher wears a tarp funnel in the
## tarp's blues tied over its barrel, its mouth dark while empty and showing water at one cup.
func test_the_rain_catcher_wears_a_tarp_funnel_whose_mouth_shows_the_water() -> void:
	var catcher := CATCHER_SCENE.instantiate() as RainCatcher
	arena.add_child(catcher)
	var empty: Image = _frame_image(_drawn(catcher))
	catcher.cups = 1
	var water: Image = _frame_image(_drawn(catcher))
	for image: Image in [empty, water]:
		var tarp: Dictionary[String, int] = {"5b6ee1": 0, "3f3f74": 0}
		for y: int in range(2, 14):
			for x: int in image.get_width():
				var colour: Color = image.get_pixel(x, y)
				var hex: String = colour.to_html(false)
				if colour.a > 0.5 and tarp.has(hex):
					tarp[hex] += 1
		assert_gt(tarp["5b6ee1"], 8, "the tarp's blue over the barrel's rim")
		assert_gt(tarp["3f3f74"], 4, "and its shade, where it dips into the mouth")
	assert_eq(empty.get_pixel(8, 7).to_html(false), "222034", "an empty funnel's mouth is dark")
	assert_eq(water.get_pixel(8, 7).to_html(false), "5fcde4", "at one cup, water shows in its mouth")


func test_a_rain_catcher_look_shows_water_while_it_holds_a_cup() -> void:
	var catcher := CATCHER_SCENE.instantiate() as RainCatcher
	arena.add_child(catcher)
	assert_eq(_drawn(catcher).frame(), StructureArt.CATCHER_EMPTY)
	catcher.cups = 1
	assert_eq(_drawn(catcher).frame(), StructureArt.CATCHER_WATER)
	assert_true(_look(catcher).shadow.visible)
	_assert_stands_on_origin(_look(catcher), "the rain catcher")


func test_the_workbench_and_an_island_sign_show_their_stills() -> void:
	var bench := Workbench.new()
	var sign := IslandSign.new()
	arena.add_child(bench)
	arena.add_child(sign)
	assert_eq(_drawn(bench).frame(), StructureArt.KIND_WORKBENCH)
	assert_eq(_look(bench).still.texture, data.still_for(StructureArt.KIND_WORKBENCH))
	assert_false(_look(bench).shadow.visible, "the bench stands on legs, no shadow")
	assert_eq(_drawn(sign).frame(), StructureArt.KIND_SIGN)
	assert_eq(_look(sign).still.texture, data.still_for(StructureArt.KIND_SIGN), "its post")
	assert_eq(_look(sign).shadow.size, DropShadow.Size.SMALL)
	_assert_stands_on_origin(_look(bench), "the workbench")
	_assert_stands_on_origin(_look(sign), "the sign")


# art-terrain-polish D3 (C14): a raft or its site stands bottom-centre on its origin moved by its
# look offset toward land (`side`: -1 west, 1 east), and so does its shadow; the look itself stays
# on the origin, where the prompt and the interactable are.
func _assert_rests_toward_land(look: StructureLook, kind: StringName, side: int, what: String) -> void:
	var lean: Vector2 = data.look_offset(kind, side)
	var size: Vector2 = look.sprite.sprite_frames.get_frame_texture(look.sprite.animation, 0).get_size()
	assert_ne(lean, Vector2.ZERO, "%s leans toward land" % what)
	assert_eq(look.sprite.offset, StructureArt.frame_offset(size) + lean, "%s stands bottom-centre on its origin moved toward land" % what)
	assert_eq(look.position, Vector2.ZERO, "%s: the look sits on the structure's origin" % what)
	if look.shadow.visible:
		assert_eq(look.shadow.position, lean + data.shadow_offsets.get(kind, Vector2.ZERO), "%s: its shadow leans with it" % what)


func _assert_wide_shadow(look: StructureLook, shown: bool, what: String) -> void:
	assert_eq(look.shadow.visible, shown, "%s: %s" % [what, "the WIDE shadow" if shown else "no shadow"])
	if shown:
		assert_eq(int(look.shadow.size), int(DropShadow.Size.get("WIDE", -2)), "%s: the WIDE shadow" % what)


## art-terrain-polish D3 (C14), one player offline: the site's stages and the raft lean toward land.
## Off an island (this arena has no session) the ground is TerrainQuery's featureless beach, as
## Raft.work_offset reads it, so they lean west. Marked and with materials the site casts no shadow;
## half-built, and as a raft, the WIDE one.
func test_a_solo_build_shows_every_site_stage_then_the_raft_in_its_place() -> void:
	var site := SITE_SCENE.instantiate() as BuildSite
	site.recipe = _raft_recipe()
	site.position = IslandLayout.cell_center(IslandLayout.build(SANDBAR).raft_site)
	arena.add_child(site)
	var at: Vector2 = site.position
	var lean: Vector2 = data.look_offset(StructureArt.KIND_RAFT_SITE, -1)
	assert_eq(_drawn(site).frame(), StructureArt.SITE_MARKED)
	_assert_rests_toward_land(_look(site), StructureArt.KIND_RAFT_SITE, -1, "the raft site")
	_assert_wide_shadow(_look(site), false, "a marked site")
	assert_eq(StructureArt.foot_rect(at + lean, Vector2(64, 32)), Rect2(at + _look(site).sprite.offset, Vector2(64, 32)), "beside the B cell, toward land")
	body.inventory.add(&"driftwood", 6)
	body.inventory.add(&"inner_tube", 2)
	body.inventory.add(&"rope", 3)
	site.deposit(body)
	assert_eq(_drawn(site).frame(), StructureArt.SITE_MATERIALS)
	_assert_wide_shadow(_look(site), false, "a site with its materials")
	site.work(0.5)
	assert_eq(_drawn(site).frame(), StructureArt.SITE_HALF_BUILT)
	_assert_wide_shadow(_look(site), true, "a half-built site")
	_assert_rests_toward_land(_look(site), StructureArt.KIND_RAFT_SITE, -1, "the half-built site")
	site.work(0.5)
	var raft: Raft = null
	for child: Node in arena.get_children():
		if child is Raft:
			raft = child as Raft
	assert_not_null(raft, "the raft replaces the site")
	if raft == null:
		return
	assert_eq(raft.position, at, "in the site's place")
	assert_eq(_drawn(raft).frame(), StructureArt.RAFT_WHOLE)
	_assert_rests_toward_land(_look(raft), StructureArt.KIND_RAFT, -1, "the raft")
	_assert_wide_shadow(_look(raft), true, "the raft")


func test_a_bench_placed_site_hides_its_stake_marker_once_built() -> void:
	var site := SITE_SCENE.instantiate() as BuildSite
	site.recipe = GameState.content.get_entry(&"recipes", &"fire") as RecipeData
	site.spawned = true
	arena.add_child(site)
	assert_eq(_drawn(site).frame(), StructureArt.KIND_STAKE, "the stake marker")
	assert_true(_look(site).shadow.visible)
	site.built = true
	assert_eq(_drawn(site).frame(), StructureArt.NO_FRAME, "hidden once built (design.md T10)")
	assert_false(_look(site).shadow.visible, "its shadow with it")


func test_a_raft_look_follows_integrity_set_after_it_enters_the_tree_every_frame() -> void:
	var raft := RAFT_SCENE.instantiate() as Raft
	arena.add_child(raft)
	await wait_process_frames(1)
	assert_eq(_look(raft).frame(), StructureArt.NO_FRAME, "no deck before it is built")
	raft.on_built(_raft_recipe())
	await wait_process_frames(1)
	assert_eq(_look(raft).frame(), StructureArt.RAFT_WHOLE, "read on the next frame, not once in _ready")
	raft.integrity = 50.0
	await wait_process_frames(1)
	assert_eq(_look(raft).frame(), StructureArt.RAFT_WORN, "beached at 50")
	raft.integrity = 0.0
	await wait_process_frames(1)
	assert_eq(_look(raft).frame(), StructureArt.NO_FRAME, "no deck at 0")
	assert_false(_look(raft).sprite.visible)
	assert_false(_look(raft).shadow.visible, "and no shadow")


## art-terrain-polish 5.1 (C14), one player offline: on the sandbar and on the coast cay the site,
## marked, leans toward land with no shadow; a raft beached there leans the same way, the opaque
## pixels of its bottom rows lie over land cells (read from the frame's image and the layout), its
## WIDE shadow lies over land, and its origin, where the prompt anchors, is still on the hull.
func test_a_solo_raft_on_the_sandbar_and_the_coast_cay_rests_on_land_with_its_wide_shadow() -> void:
	var shell := _solo_shell()
	await wait_process_frames(2)
	for id: StringName in [&"sandbar", &"coast_cay"]:
		if shell.island.layout.id != id:
			shell.travel.travel(id)
			await wait_process_frames(2)
		var island := shell.island
		assert_eq(island.layout.id, id)
		var site_cell: Vector2i = island.built.raft_site
		var origin: Vector2 = IslandLayout.cell_center(site_cell)
		var side: int = StructureArt.land_side(island.built.terrain, site_cell)
		assert_eq(side, -1, "%s: land west of the site" % id)
		var site := shell.session.get_node_or_null(^"RaftSite") as BuildSite
		assert_not_null(site, "%s: the site" % id)
		if site == null:
			continue
		assert_eq(_drawn(site).frame(), StructureArt.SITE_MARKED, "%s: marked" % id)
		_assert_rests_toward_land(_look(site), StructureArt.KIND_RAFT_SITE, side, "%s: the marked site" % id)
		_assert_wide_shadow(_look(site), false, "%s: the marked site" % id)
		island.beach_raft(RaftRecord.bare(100.0))
		await wait_process_frames(1)
		var raft := shell.session.get_node_or_null(^"Raft") as Raft
		assert_not_null(raft, "%s: a raft on the site" % id)
		if raft == null:
			continue
		var look := _drawn(raft)
		assert_eq(look.frame(), StructureArt.RAFT_WHOLE)
		_assert_rests_toward_land(look, StructureArt.KIND_RAFT, side, "%s: the raft" % id)
		_assert_wide_shadow(look, true, "%s: the raft" % id)
		var image := _frame_image(look)
		var top_left: Vector2 = raft.global_position + look.sprite.offset
		var row_top: float = site_cell.y * IslandLayout.TILE
		var wet: Array[String] = []
		for y: int in image.get_height():
			if top_left.y + y < row_top:
				continue
			for x: int in image.get_width():
				if image.get_pixel(x, y).a8 == 0:
					continue
				var cell := Vector2i(floori((top_left.x + x) / IslandLayout.TILE), site_cell.y)
				if TerrainQuery.is_water(island.built.terrain.terrain_at(cell)) and not wet.has(str(cell)):
					wet.append(str(cell))
		assert_eq(wet, [] as Array[String], "%s: the hull's bottom rows over land" % id)
		var shadow_rect := Rect2(look.shadow.global_position - look.shadow.texture.get_size() / 2.0, look.shadow.texture.get_size())
		for corner: Vector2 in [shadow_rect.position, shadow_rect.end - Vector2.ONE, Vector2(shadow_rect.position.x, shadow_rect.end.y - 1.0), Vector2(shadow_rect.end.x - 1.0, shadow_rect.position.y)]:
			var cell := Vector2i(floori(corner.x / IslandLayout.TILE), floori(corner.y / IslandLayout.TILE))
			assert_false(TerrainQuery.is_water(island.built.terrain.terrain_at(cell)), "%s: the shadow's corner %s over land" % [id, cell])
		var hull := Rect2(raft.global_position + look.sprite.offset, Vector2(image.get_size()))
		assert_true(hull.has_point(raft.global_position + Vector2(0.0, -1.0)), "%s: the origin, where the prompt anchors, is on the hull" % id)
		assert_eq(raft.global_position, origin, "%s: the raft itself stays on the site" % id)


# --- art-mood-pass C33b: firelight (design D2; owner Q13 (a)) ---

## Well into the night (past the 20 s blend) and the middle of the day.
const NIGHT_AT_S: float = DayClock.NIGHT_START_S + 30.0
const DAY_AT_S: float = 200.0
const SURVIVAL_TUNING: SurvivalTuning = preload("res://resources/survival_tuning.tres")


func _fire_light(structure: Node) -> PointLight2D:
	return _look(structure).get_node_or_null(^"FireLight") as PointLight2D


func _lit_fire() -> Fire:
	var fire := FIRE_SCENE.instantiate() as Fire
	arena.add_child(fire)
	fire.light()
	return fire


## One player, offline: a lit fire at night lights a stepped pool exactly as far as its company reaches.
func test_a_solo_lit_fire_at_night_lights_a_pool_as_far_as_its_company() -> void:
	WeatherManager.sky.start_at(NIGHT_AT_S)
	var fire := _lit_fire()
	_drawn(fire)
	var light := _fire_light(fire)
	assert_not_null(light, "a FireLight under the fire's Look")
	if light == null:
		return
	var radius: int = FireGlow.radius_px(SURVIVAL_TUNING.company_radius_tiles)
	assert_eq(radius, 80, "5 tiles of company, 16 px each")
	assert_true(light.visible, "on at night")
	assert_eq(light.blend_mode, Light2D.BLEND_MODE_ADD)
	assert_eq(light.texture_scale, 1.0, "1:1, so the rings stay hard")
	assert_eq(light.texture.get_width(), 2 * radius + 1)
	assert_between(light.energy, 0.0001, 0.9999, "energy below 1")
	assert_false(light.shadow_enabled)


func test_the_firelight_is_off_by_day_and_once_the_fire_is_out() -> void:
	WeatherManager.sky.start_at(DAY_AT_S)
	var fire := _lit_fire()
	_drawn(fire)
	assert_false(_fire_light(fire).visible, "off by day")
	WeatherManager.sky.start_at(NIGHT_AT_S)
	_drawn(fire)
	assert_true(_fire_light(fire).visible, "on at night")
	fire.advance(fire.tuning.fire_burn_s + 1.0)
	_drawn(fire)
	assert_false(_fire_light(fire).visible, "off once only embers are left")


## A palm, a rain catcher and a workbench never make a light.
func test_no_other_structure_makes_a_light() -> void:
	WeatherManager.sky.start_at(NIGHT_AT_S)
	var palm := PALM_SCENE.instantiate()
	arena.add_child(palm)
	var catcher := CATCHER_SCENE.instantiate()
	arena.add_child(catcher)
	var bench := (load("res://scenes/structures/workbench.tscn") as PackedScene).instantiate()
	arena.add_child(bench)
	for structure: Node in [palm, catcher, bench]:
		_drawn(structure)
		assert_null(_fire_light(structure), "%s has no light" % structure.name)


func test_the_pool_follows_the_company_radius_in_data() -> void:
	assert_eq(FireGlow.radius_px(6.0), 96)
	var art := ArtTuning.standard()
	assert_eq(FireGlow.texture(FireGlow.radius_px(6.0), art.fire_ring_values).get_width(), 193)


func test_the_rings_are_hard_steps_and_nothing_lies_beyond_the_radius() -> void:
	var art := ArtTuning.standard()
	assert_eq(art.fire_ring_values.size(), art.fire_light_steps, "one value per ring")
	var image: Image = FireGlow.texture(80, art.fire_ring_values).get_image()
	var values: Dictionary[float, bool] = {}
	for y: int in image.get_height():
		for x: int in image.get_width():
			var value: float = snappedf(image.get_pixel(x, y).r, 0.001)
			var outside: bool = Vector2(x - 80, y - 80).length() > 80.0
			if outside:
				assert_eq(value, 0.0, "(%d, %d) lies beyond the radius" % [x, y])
			elif value > 0.0:
				values[value] = true
	assert_eq(values.size(), art.fire_light_steps, "exactly %d hard steps" % art.fire_light_steps)


func test_the_flicker_follows_the_flame_and_holds_still_under_reduce_flashes() -> void:
	var art := ArtTuning.standard()
	var frames: int = data.fire.get_frame_count(StructureArt.FIRE_LIT)
	assert_eq(art.fire_flicker.size(), frames, "one factor per lit flame frame")
	WeatherManager.sky.start_at(NIGHT_AT_S)
	var fire := _lit_fire()
	var look := _drawn(fire)
	var was: bool = HurtCues.reduce_flashes
	var seen: Dictionary[float, bool] = {}
	HurtCues.reduce_flashes = false
	for frame: int in frames:
		look.sprite.frame = frame
		look.step()
		seen[snappedf(_fire_light(fire).energy / art.fire_flicker[frame], 0.0001)] = true
	assert_eq(seen.size(), 1, "the energy follows the flame's frame through the table")
	var steady: Dictionary[float, bool] = {}
	HurtCues.reduce_flashes = true
	for frame: int in frames:
		look.sprite.frame = frame
		look.step()
		steady[snappedf(_fire_light(fire).energy, 0.0001)] = true
	HurtCues.reduce_flashes = was
	assert_eq(steady.size(), 1, "under Reducir destellos the light holds steady")


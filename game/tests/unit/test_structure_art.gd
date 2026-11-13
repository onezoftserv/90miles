extends GutTest
## art-pass "Palms", "Camp structures" and "Raft site and raft" (design.md D18, T8-T11): the pure
## rules that pick a structure's frame from the state its peer holds, and where the frames stand.
## The state is read from the real structures where a test can build them; the looks that read it
## every frame are task 8.4's.

const PALM_SCENE: PackedScene = preload("res://scenes/levels/palm.tscn")
const FIRE_SCENE: PackedScene = preload("res://scenes/structures/fire.tscn")
const RAFT_SCENE: PackedScene = preload("res://scenes/structures/raft.tscn")
const SITE_SCENE: PackedScene = preload("res://scenes/structures/build_site.tscn")
const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")
const SANDBAR: IslandLayoutData = preload("res://resources/islands/sandbar.tres")
const COAST_CAY: IslandLayoutData = preload("res://resources/islands/coast_cay.tres")

# The fire's logs fill its frame's last rows (design.md K84); only the flame above them flickers.
const FIRE_BASE_TOP: int = 12

var data: StructureArtData
var body: PlayerBody
# Sites and the rafts they become go here, so each test starts without leftovers.
var arena: Node2D


func before_each() -> void:
	NetManager.start_solo()
	data = StructureArtData.standard()
	body = PLAYER_SCENE.instantiate() as PlayerBody
	add_child_autofree(body)
	body.player_input.enabled = false
	arena = Node2D.new()
	add_child_autofree(arena)


func _frame_image(texture: Texture2D) -> Image:
	var atlas := texture as AtlasTexture
	if atlas == null:
		return texture.get_image()
	return atlas.atlas.get_image().get_region(Rect2i(atlas.region))


func _raft_recipe() -> RecipeData:
	return GameState.content.get_entry(&"recipes", &"raft") as RecipeData


func _raft_site() -> BuildSite:
	var site := SITE_SCENE.instantiate() as BuildSite
	site.recipe = _raft_recipe()
	site.position = IslandLayout.cell_center(IslandLayout.build(SANDBAR).raft_site)
	arena.add_child(site)
	return site


func _stage(site: BuildSite) -> StringName:
	return StructureArt.site_stage(site.deposited, site.tags_deposited, site.progress())


func _rafts() -> Array[Raft]:
	var found: Array[Raft] = []
	for child: Node in arena.get_children():
		if child is Raft and not child.is_queued_for_deletion():
			found.append(child as Raft)
	return found


func test_the_data_loads() -> void:
	assert_not_null(data, "res://assets/art/structures/structure_art.tres")


func test_a_palm_shows_its_coconuts_up_to_three() -> void:
	var shown: Array[int] = []
	for coconuts: int in [0, 1, 2, 3, 5]:
		shown.append(StructureArt.coconuts_shown(coconuts))
	assert_eq(shown, [0, 1, 2, 3, 3] as Array[int])
	assert_eq(StructureArt.coconuts_shown(-1), 0)
	assert_eq(data.coconut_overlays.size(), StructureArt.MAX_COCONUTS_SHOWN, "one overlay per count shown")
	for overlay: Texture2D in data.coconut_overlays:
		assert_eq(overlay.get_size(), data.palm.get_size(), "an overlay covers the palm's frame")


func test_the_nest_shows_only_on_the_layouts_nest_palms() -> void:
	var sandbar := IslandLayout.build(SANDBAR)
	var nests: Array[int] = []
	for index: int in sandbar.palms.size():
		if StructureArt.shows_nest(index, SANDBAR.nest_palms):
			nests.append(index)
	assert_eq(nests, [4, 5] as Array[int])
	var cay := IslandLayout.build(COAST_CAY)
	for index: int in cay.palms.size():
		assert_false(StructureArt.shows_nest(index, COAST_CAY.nest_palms), "the coast cay has no nest palm")
	assert_eq(data.nest.get_size(), data.palm.get_size(), "the nest overlay covers the palm's frame")


func test_a_solo_climb_on_a_nest_palm_leaves_the_nest_and_1_coconut() -> void:
	var sandbar := IslandLayout.build(SANDBAR)
	var index: int = SANDBAR.nest_palms[0]
	var palm := PALM_SCENE.instantiate() as Palm
	palm.position = IslandLayout.cell_center(sandbar.palms[index])
	palm.coconuts = sandbar.palm_coconuts[index]
	add_child_autofree(palm)
	assert_eq(palm.coconuts, 1, "the sandbar's nest palms start with 1 (design.md T11)")
	palm.coconuts = 2
	palm.interactable.interacted.emit(body)
	assert_eq(body.inventory.count_id(Palm.COCONUT_ID), 1)
	assert_true(StructureArt.shows_nest(index, SANDBAR.nest_palms))
	assert_eq(StructureArt.coconuts_shown(palm.coconuts), 1)


func test_the_palm_stands_on_its_trunk_base_with_the_nest_in_its_crown() -> void:
	assert_eq(data.palm.get_size(), Vector2(32, 48))
	var frame: Rect2 = StructureArt.foot_rect(Vector2.ZERO, data.palm.get_size())
	assert_eq(frame, Rect2(-16, -48, 32, 48), "origin at the trunk base, bottom-centre")
	assert_eq(data.nest_point, Vector2(0, -34), "design.md D18: about 34 px over the trunk base")
	assert_true(frame.has_point(data.nest_point))


func test_a_solo_fire_flickers_while_lit_and_shows_embers_once_out() -> void:
	var fire := FIRE_SCENE.instantiate() as Fire
	add_child_autofree(fire)
	fire.light()
	assert_eq(StructureArt.fire_frame(fire.lit), StructureArt.FIRE_LIT)
	fire.advance(fire.tuning.fire_burn_s + 1.0)
	assert_false(fire.lit)
	assert_eq(StructureArt.fire_frame(fire.lit), StructureArt.FIRE_OUT)
	assert_eq(data.fire.get_frame_count(StructureArt.FIRE_LIT), 4, "a 4-frame flicker")
	assert_eq(data.fire.get_frame_count(StructureArt.FIRE_OUT), 1)
	assert_eq(data.fire.get_frame_texture(StructureArt.FIRE_LIT, 0).get_size(), Vector2(16, 16))
	# The flicker moves only the flame: every lit frame differs from every other, and the logs'
	# bottom rows are the same pixels in all four, so the base never jumps.
	var frames: Array[Image] = []
	for i: int in 4:
		frames.append(_frame_image(data.fire.get_frame_texture(StructureArt.FIRE_LIT, i)))
	for i: int in 4:
		for j: int in range(i + 1, 4):
			assert_ne(frames[i].get_data(), frames[j].get_data(), "lit frames %d and %d differ" % [i, j])
		for y: int in range(FIRE_BASE_TOP, 16):
			for x: int in 16:
				if frames[i].get_pixel(x, y) != frames[0].get_pixel(x, y):
					fail_test("lit frame %d moves the base at (%d, %d)" % [i, x, y])
					return


func test_the_rain_catcher_shows_water_while_it_holds_a_cup() -> void:
	assert_eq(StructureArt.catcher_frame(0), StructureArt.CATCHER_EMPTY)
	assert_eq(StructureArt.catcher_frame(1), StructureArt.CATCHER_WATER)
	assert_eq(StructureArt.catcher_frame(3), StructureArt.CATCHER_WATER)
	for frame: StringName in [StructureArt.CATCHER_EMPTY, StructureArt.CATCHER_WATER]:
		assert_eq(data.rain_catcher.get_frame_count(frame), 1)
		assert_eq(data.rain_catcher.get_frame_texture(frame, 0).get_size(), Vector2(16, 24))


func test_an_island_sign_draws_its_post_and_a_drink_spot_draws_nothing() -> void:
	var post: Texture2D = data.still_for(StructureArt.kind_of(autofree(IslandSign.new())))
	assert_not_null(post, "every sign uses the one post (design.md T17)")
	if post != null:
		assert_eq(post.get_size(), Vector2(16, 16))
	assert_eq(StructureArt.kind_of(autofree(DrinkSpot.new())), &"", "the water shows where to drink")
	assert_null(data.still_for(&""))


func test_the_workbench_and_the_stake_marker_have_their_sprites() -> void:
	var bench := Workbench.new()
	autofree(bench)
	var bench_art: Texture2D = data.still_for(StructureArt.kind_of(bench))
	assert_not_null(bench_art)
	if bench_art != null:
		assert_eq(bench_art.get_size(), Vector2(32, 16))
	var marker: Texture2D = data.still_for(StructureArt.KIND_STAKE)
	assert_not_null(marker)
	if marker != null:
		assert_eq(marker.get_size(), Vector2(16, 16))


func test_raft_site_stages_follow_any_deposit_and_half_the_work() -> void:
	assert_eq(StructureArt.site_stage({}, {}, 0.0), StructureArt.SITE_MARKED)
	assert_eq(StructureArt.site_stage({&"rope": 0}, {0: 0}, 0.0), StructureArt.SITE_MARKED, "entries holding 0 count as none")
	assert_eq(StructureArt.site_stage({&"rope": 1}, {}, 0.0), StructureArt.SITE_MATERIALS)
	assert_eq(StructureArt.site_stage({&"rope": 0}, {0: 2}, 0.0), StructureArt.SITE_MATERIALS, "a tag deposit counts")
	assert_eq(StructureArt.site_stage({&"rope": 3}, {}, 0.49), StructureArt.SITE_MATERIALS)
	assert_eq(StructureArt.site_stage({&"rope": 3}, {}, 0.5), StructureArt.SITE_HALF_BUILT)
	var stages: SpriteFrames = data.site_frames_for(&"raft")
	assert_not_null(stages, "the raft's site has its own stages")
	if stages != null:
		for stage: StringName in [StructureArt.SITE_MARKED, StructureArt.SITE_MATERIALS, StructureArt.SITE_HALF_BUILT]:
			assert_eq(stages.get_frame_count(stage), 1, String(stage))
			assert_eq(stages.get_frame_texture(stage, 0).get_size(), Vector2(64, 32))
	assert_null(data.site_frames_for(&"fire"), "any other site is the stake marker")


func test_a_solo_build_goes_through_every_stage_then_the_raft_stands_in_its_place() -> void:
	var site := _raft_site()
	var at: Vector2 = site.position
	assert_eq(_stage(site), StructureArt.SITE_MARKED)
	body.inventory.add(&"driftwood", 1)
	site.deposit(body)
	assert_eq(_stage(site), StructureArt.SITE_MATERIALS)
	body.inventory.add(&"driftwood", 5)
	body.inventory.add(&"inner_tube", 2)
	body.inventory.add(&"rope", 3)
	site.deposit(body)
	assert_true(site.inputs_complete())
	assert_eq(_stage(site), StructureArt.SITE_MATERIALS)
	site.work(0.5)
	assert_eq(_stage(site), StructureArt.SITE_HALF_BUILT)
	site.work(0.5)
	var rafts := _rafts()
	assert_eq(rafts.size(), 1, "the raft replaces the site")
	if rafts.size() == 1:
		assert_eq(rafts[0].position, at)
		assert_eq(StructureArt.raft_frame(rafts[0].integrity), StructureArt.RAFT_WHOLE)


func test_a_bench_placed_site_hides_its_marker_once_built() -> void:
	var site := SITE_SCENE.instantiate() as BuildSite
	site.recipe = GameState.content.get_entry(&"recipes", &"fire") as RecipeData
	site.spawned = true
	arena.add_child(site)
	assert_true(StructureArt.site_marker_shown(site.built))
	site.built = true
	assert_false(StructureArt.site_marker_shown(site.built), "design.md T10")


func test_raft_frames_by_integrity() -> void:
	var cases: Dictionary[float, StringName] = {
		100.0: StructureArt.RAFT_WHOLE, 60.0: StructureArt.RAFT_WORN, 30.0: StructureArt.RAFT_BREAKING,
		66.5: StructureArt.RAFT_WHOLE, 66.0: StructureArt.RAFT_WORN, 33.5: StructureArt.RAFT_WORN,
		33.0: StructureArt.RAFT_BREAKING, 0.5: StructureArt.RAFT_BREAKING,
		0.0: StructureArt.NO_FRAME, -4.0: StructureArt.NO_FRAME,
	}
	for integrity: float in cases:
		assert_eq(StructureArt.raft_frame(integrity), cases[integrity], "integrity %s" % integrity)
	for frame: StringName in [StructureArt.RAFT_WHOLE, StructureArt.RAFT_WORN, StructureArt.RAFT_BREAKING]:
		assert_eq(data.raft.get_frame_count(frame), 1, String(frame))
		assert_eq(data.raft.get_frame_texture(frame, 0).get_size(), Vector2(64, 32))
	assert_false(data.raft.has_animation(&"broken"), "no deck is drawn at 0")


func test_a_raft_whose_integrity_is_set_in_the_tree_shows_the_new_value() -> void:
	var raft := RAFT_SCENE.instantiate() as Raft
	arena.add_child(raft)
	assert_eq(StructureArt.raft_frame(raft.integrity), StructureArt.NO_FRAME, "0 until built")
	raft.on_built(_raft_recipe())
	assert_eq(StructureArt.raft_frame(raft.integrity), StructureArt.RAFT_WHOLE)
	# beach_raft: on_built's full integrity, then what the crossing left.
	raft.integrity = 50.0
	assert_eq(StructureArt.raft_frame(raft.integrity), StructureArt.RAFT_WORN, "a raft beached at 50")


func test_the_site_and_raft_stand_bottom_centre_on_the_b_cell() -> void:
	var size := Vector2(64, 32)
	var sandbar: Vector2 = IslandLayout.cell_center(IslandLayout.build(SANDBAR).raft_site)
	assert_eq(sandbar, Vector2(504, 472), "(31,29)")
	assert_eq(StructureArt.foot_rect(sandbar, size), Rect2(472, 440, 64, 32))
	var cay: Vector2 = IslandLayout.cell_center(IslandLayout.build(COAST_CAY).raft_site)
	assert_eq(cay, Vector2(312, 728), "(19,45)")
	assert_eq(StructureArt.foot_rect(cay, size), Rect2(280, 696, 64, 32))
	assert_eq(StructureArt.frame_offset(size), Vector2(-32, -32), "the offset of an uncentred sprite")
	assert_eq(data.raft.get_frame_texture(StructureArt.RAFT_WHOLE, 0).get_size(), size)


func test_every_frame_name_the_rules_pick_is_in_the_frames() -> void:
	for frame: StringName in [StructureArt.FIRE_LIT, StructureArt.FIRE_OUT]:
		assert_true(data.fire.has_animation(frame), String(frame))
	assert_eq(data.fire.get_animation_names().size(), 2)
	assert_eq(data.rain_catcher.get_animation_names().size(), 2)
	assert_eq(data.raft.get_animation_names().size(), 3)


func test_each_structure_names_its_shadow() -> void:
	for kind: StringName in StructureArt.KINDS:
		assert_true(data.shadows.has(kind), "%s names a shadow size or none (-1)" % kind)
	for kind: StringName in data.shadows:
		var size: int = data.shadows[kind]
		assert_true(size >= -1 and size <= DropShadow.Size.SMALL, "%s: %d" % [kind, size])

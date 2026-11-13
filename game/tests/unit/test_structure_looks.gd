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
const SETTINGS_PATH: String = "user://test_structure_looks_settings.cfg"

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
	if FileAccess.file_exists(SETTINGS_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS_PATH))


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
	shell.settings_path = SETTINGS_PATH
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


func test_a_solo_build_shows_every_site_stage_then_the_raft_in_its_place() -> void:
	var site := SITE_SCENE.instantiate() as BuildSite
	site.recipe = _raft_recipe()
	site.position = IslandLayout.cell_center(IslandLayout.build(SANDBAR).raft_site)
	arena.add_child(site)
	var at: Vector2 = site.position
	assert_eq(_drawn(site).frame(), StructureArt.SITE_MARKED)
	_assert_stands_on_origin(_look(site), "the raft site")
	assert_eq(StructureArt.foot_rect(at, Vector2(64, 32)), Rect2(at + _look(site).sprite.offset, Vector2(64, 32)), "over the B cell")
	body.inventory.add(&"driftwood", 6)
	body.inventory.add(&"inner_tube", 2)
	body.inventory.add(&"rope", 3)
	site.deposit(body)
	assert_eq(_drawn(site).frame(), StructureArt.SITE_MATERIALS)
	site.work(0.5)
	assert_eq(_drawn(site).frame(), StructureArt.SITE_HALF_BUILT)
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
	_assert_stands_on_origin(_look(raft), "the raft")


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

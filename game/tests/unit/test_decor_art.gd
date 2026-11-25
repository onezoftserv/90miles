extends GutTest
## art-prop-polish D6 (C16): the hidden cay's scenery drawn from DecorArtData. Each decor cell of a
## layout draws its piece: flat pieces (the embers, the drag mark, the cut line) in DecorView under
## the actors' shadows, upright ones (the cigar stub, the post, Platino) as children of the y-sorted
## DecorPieces, standing on their cell. A decor id with no look still draws its colour square, so a
## new kind stays a data edit. Drawing only. GUT runs headless, so each cell's decision is read from
## DecorView.piece_for rather than from _draw.

const ISLAND_SCENE: PackedScene = preload("res://scenes/levels/sandbar_island.tscn")
const SHELL_SCENE: PackedScene = preload("res://scenes/shell/game_shell.tscn")
const CAY: IslandLayoutData = preload("res://resources/islands/cayo_sin_norte.tres")
const DECOR_IDS: Array[StringName] = [&"embers", &"cigar_smoke", &"drag_mark", &"post", &"cut_line", &"platino"]
const UPRIGHT_IDS: Array[StringName] = [&"cigar_smoke", &"post", &"platino"]
const TILE: float = 16.0
## The stub's wisp: at most this many unique frames, at most this fast (art-pass frame budgets).
const WISP_FRAMES: int = 4
const WISP_FPS: float = 12.0

var settings_path: String = UserTmp.path("test_decor_art_settings.cfg")


func before_each() -> void:
	NetManager.start_solo()
	WeatherManager.stop()
	WeatherManager.sky.start_at(0.0)


func after_each() -> void:
	WeatherManager.stop()
	NetManager.leave()
	if FileAccess.file_exists(settings_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(settings_path))


func _island() -> SandbarIsland:
	var island := ISLAND_SCENE.instantiate() as SandbarIsland
	island.layout = CAY
	island.with_creatures = false
	add_child_autofree(island)
	return island


func _view(island: Node) -> DecorView:
	return island.get_node_or_null(^"Decor") as DecorView


func _pieces(view: DecorView) -> Node2D:
	return view.get_node_or_null(^"DecorPieces") as Node2D


# The upright piece drawn for the decor cell `cell`, or null.
func _upright_at(view: DecorView, cell: Vector2i) -> Node2D:
	var pieces := _pieces(view)
	if pieces == null:
		return null
	for child: Node in pieces.get_children():
		if child is Node2D and (child as Node2D).position == IslandLayout.cell_center(cell):
			return child as Node2D
	return null


func _opaque_pixels(texture: Texture2D, region: Rect2i) -> int:
	var atlas := texture as AtlasTexture
	var image: Image = ArtChecks.read_png((atlas.atlas if atlas != null else texture).resource_path)
	var origin := Vector2i(atlas.region.position) if atlas != null else Vector2i.ZERO
	var count: int = 0
	for y: int in range(region.position.y, region.end.y):
		for x: int in range(region.position.x, region.end.x):
			if image.get_pixelv(origin + Vector2i(x, y)).a > 0.0:
				count += 1
	return count


func test_each_decor_id_of_the_hidden_cay_draws_its_piece() -> void:
	var island := _island()
	var view := _view(island)
	assert_not_null(view, "the Decor child")
	if view == null:
		return
	var drawn: Dictionary[StringName, int] = {}
	for entry: Dictionary in island.built.decor:
		var piece: Dictionary = view.piece_for(entry)
		var label: String = "%s at %s" % [entry["decor_id"], entry["cell"]]
		assert_ne(piece["kind"], DecorView.PIECE_SQUARE, "%s draws its piece, not its square" % label)
		if piece["kind"] != DecorView.PIECE_NONE:
			drawn[entry["decor_id"]] = drawn.get(entry["decor_id"], 0) + 1
		var upright: bool = UPRIGHT_IDS.has(entry["decor_id"])
		if piece["kind"] != DecorView.PIECE_NONE:
			assert_eq(piece["kind"], DecorView.PIECE_UPRIGHT if upright else DecorView.PIECE_FLAT, "%s: %s" % [label, "upright" if upright else "flat"])
	for decor_id: StringName in DECOR_IDS:
		assert_gt(drawn.get(decor_id, 0), 0, "%s is drawn somewhere" % decor_id)


func test_upright_pieces_are_children_of_the_y_sorted_decor_pieces_standing_on_their_cell() -> void:
	var island := _island()
	var view := _view(island)
	var pieces := _pieces(view)
	assert_not_null(pieces, "DecorPieces")
	if pieces == null:
		return
	assert_true(view.y_sort_enabled and pieces.y_sort_enabled, "y-sorted, so the pieces sort with the island's actors")
	assert_eq(view.z_index + pieces.z_index, 0, "the pieces at the actors' z")
	assert_lt(view.z_index, -1, "the flat pieces under every actor's shadow (z -1)")
	for entry: Dictionary in island.built.decor:
		var piece: Dictionary = view.piece_for(entry)
		if piece["kind"] != DecorView.PIECE_UPRIGHT:
			continue
		var node := _upright_at(view, entry["cell"])
		assert_not_null(node, "%s at %s stands on its cell's centre" % [entry["decor_id"], entry["cell"]])
		if node != null:
			assert_true(node.is_in_group(&"art_view"), "drawing only")


func test_the_post_in_the_shallows_has_its_ripple_foot_and_a_post_on_sand_none() -> void:
	var data := DecorArtData.standard()
	var wet := data.look_for(&"post", DataEnums.Terrain.SHALLOWS)
	var dry := data.look_for(&"post", DataEnums.Terrain.BEACH)
	assert_not_null(wet, "a post in the shallows")
	assert_not_null(dry, "a post on sand")
	if wet == null or dry == null:
		return
	assert_not_null(wet.foot, "the waterline foot")
	assert_null(dry.foot, "a dry foot: none")
	assert_same(wet.texture, dry.texture, "the same post")
	var island := _island()
	for entry: Dictionary in island.built.decor:
		if entry["decor_id"] == &"post":
			assert_eq(island.terrain.terrain_at(entry["cell"]), DataEnums.Terrain.SHALLOWS, "the cay's post stands in the shallows")
			var node := _upright_at(_view(island), entry["cell"])
			assert_not_null(node.get_node_or_null(^"Foot") if node != null else null, "its foot is drawn")


func test_an_id_with_no_look_draws_its_colour_square() -> void:
	var island := _island()
	var view := _view(island)
	view.data = DecorArtData.new()
	for entry: Dictionary in island.built.decor:
		var piece: Dictionary = view.piece_for(entry)
		assert_eq(piece["kind"], DecorView.PIECE_SQUARE, "%s without a look" % entry["decor_id"])
		assert_eq(piece["colour"], CAY.decor_colors[entry["decor_id"]], "in its layout colour")
	view.data = DecorArtData.standard()
	var stranger := {"cell": Vector2i(22, 8), "decor_id": &"embers_of_another_kind"}
	assert_eq(view.piece_for(stranger)["kind"], DecorView.PIECE_NONE, "an id with no look and no colour draws nothing")


func test_the_stubs_wisp_keeps_the_frame_budget() -> void:
	var look := DecorArtData.standard().look_for(&"cigar_smoke", DataEnums.Terrain.BEACH)
	assert_not_null(look, "the cigar stub")
	if look == null or look.frames == null:
		assert_not_null(look.frames if look != null else null, "its wisp frames")
		return
	assert_lte(ArtChecks.total_unique_frames(look.frames), WISP_FRAMES, "at most 4 unique frames")
	for animation: StringName in look.frames.get_animation_names():
		assert_gt(look.frames.get_frame_count(animation), 1, "the wisp moves")
		assert_lte(look.frames.get_animation_speed(animation), WISP_FPS, "at most 12 fps")


func test_the_drag_mark_runs_over_every_sand_cell_of_its_run_and_no_water_cell() -> void:
	var island := _island()
	var view := _view(island)
	var sand: int = 0
	for entry: Dictionary in island.built.decor:
		if entry["decor_id"] != &"drag_mark":
			continue
		var piece: Dictionary = view.piece_for(entry)
		var cell: Vector2i = entry["cell"]
		if island.terrain.terrain_at(cell) == DataEnums.Terrain.SHALLOWS:
			assert_eq(piece["kind"], DecorView.PIECE_NONE, "%s: under water nothing shows" % cell)
			continue
		sand += 1
		assert_eq(piece["kind"], DecorView.PIECE_FLAT, "%s: furrows" % cell)
		var look := piece["look"] as DecorLook
		assert_gt(_opaque_pixels(look.texture, piece["region"]), 0, "%s: its half of the furrows has pixels" % cell)
	assert_eq(sand, 5, "the run's five sand cells")


## The embers lie in the cell over which the palm at (22, 17) spreads its crown; they are drawn on
## their cell's north edge so most of their pixels show above it, whatever look the palm draws.
func test_the_embers_show_above_the_palm_crown_beside_them() -> void:
	var island := _island()
	var view := _view(island)
	var data := StructureArtData.standard()
	var embers: Dictionary = {}
	for entry: Dictionary in island.built.decor:
		if entry["decor_id"] == &"embers":
			embers = entry
	assert_false(embers.is_empty(), "the cay has embers")
	if embers.is_empty():
		return
	var piece: Dictionary = view.piece_for(embers)
	var look := piece["look"] as DecorLook
	var region: Rect2 = piece["region"]
	var corner: Vector2 = Vector2(embers["cell"]) * TILE
	var at: Vector2 = corner + Vector2((TILE - region.size.x) / 2.0, TILE - region.size.y) + look.offset
	var atlas := look.texture as AtlasTexture
	var ember_image: Image = ArtChecks.read_png(atlas.atlas.resource_path).get_region(Rect2i(atlas.region))
	for look_index: int in data.palm_look_count():
		var palm_image: Image = ArtChecks.read_png(data.palm_texture(look_index).resource_path)
		var shown: int = 0
		var total: int = 0
		for palm_cell: Vector2i in island.built.palms:
			var foot: Vector2 = IslandLayout.cell_center(palm_cell)
			var frame := Rect2(foot + StructureArt.frame_offset(Vector2(palm_image.get_size())), Vector2(palm_image.get_size()))
			if not frame.intersects(Rect2(at, region.size)):
				continue
			for y: int in ember_image.get_height():
				for x: int in ember_image.get_width():
					if ember_image.get_pixel(x, y).a == 0.0:
						continue
					total += 1
					var world := at + Vector2(x, y)
					var local := Vector2i(world - frame.position)
					if not Rect2i(Vector2i.ZERO, palm_image.get_size()).has_point(local) or palm_image.get_pixelv(local).a == 0.0:
						shown += 1
		if total > 0:
			assert_gt(shown * 2, total, "palm look %d: most of the embers show (%d of %d)" % [look_index, shown, total])


## The 1-player test of art-prop-polish 6.1: the hidden cay, built for one offline player, shows
## every piece and no colour square; Platino stands on the chest's ledge; a player south of an
## upright piece is drawn over it and one north of it behind it; the player's shadow lies over the
## flat embers.
func test_a_solo_player_on_the_hidden_cay_sees_every_piece_and_platino_on_the_chests_ledge() -> void:
	var shell := SHELL_SCENE.instantiate() as GameShell
	shell.settings_path = settings_path
	add_child_autofree(shell)
	(shell.screen as TitleScreen).solo_requested.emit()
	shell.session.travel_to("cayo_sin_norte", 1, "", {1: {"health": 100.0, "energy": 100.0}}, 0.0)
	await wait_physics_frames(2)
	var island := shell.travel.island
	assert_eq(island.layout.id, &"cayo_sin_norte", "on the hidden cay")
	var view := _view(island)
	assert_not_null(view, "its Decor child")
	if view == null:
		return
	var platino: Node2D = null
	var post: Node2D = null
	for entry: Dictionary in island.built.decor:
		assert_ne(view.piece_for(entry)["kind"], DecorView.PIECE_SQUARE, "%s at %s: no colour square" % [entry["decor_id"], entry["cell"]])
		if entry["decor_id"] == &"platino":
			platino = _upright_at(view, entry["cell"])
			assert_lte(Vector2(entry["cell"]).distance_to(Vector2(island.built.chest)), 1.5, "Platino on the chest's ledge")
		elif entry["decor_id"] == &"post":
			post = _upright_at(view, entry["cell"])
	assert_not_null(platino, "Platino is drawn")
	assert_not_null(post, "the post is drawn")
	if post == null:
		return
	var body := shell.session.body(CoopSession.HOST_ID)
	body.player_input.enabled = false
	body.global_position = post.global_position + Vector2(0.0, TILE)
	assert_true(DrawOrder.drawn_after(body, post), "a player south of the post is drawn over it")
	body.global_position = post.global_position + Vector2(0.0, -TILE)
	assert_true(DrawOrder.drawn_after(post, body), "a player north of the post is drawn behind it")
	var shadow := body.get_node_or_null(^"Look/Shadow") as CanvasItem
	assert_not_null(shadow, "the player's drop shadow")
	if shadow != null:
		assert_true(DrawOrder.drawn_after(shadow, view), "the shadow lies over the flat pieces")

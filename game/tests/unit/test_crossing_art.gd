extends GutTest
## art-pass "Crossing look" (task 9.1; design.md D12, D15, T5, T15, T18, T19): the crossing's sea
## is the island's sea shader with an all-deep mask, at z -40, following `Crossing.scroll_px()`;
## its deck at -20 shows the raft frame for the vessel's integrity and is gone once sunk; a rider
## thrown in is cut at the water line beside it. With a host and a client both draw it from the
## state they hold, the shark of the pass included, and a late joiner draws the host's deck. Solo
## cases run on the crossing rig, offline; the others over ENet on localhost (NetHarness).
## Every look here follows its state in `_process`, so the waits count process frames: after a slow
## frame the engine runs several physics steps before one process frame, and a physics-frame wait
## could end before the look had moved (the sea still at its spawn origin, seen once in CI).

const ISLAND_SCENE: PackedScene = preload("res://scenes/levels/sandbar_island.tscn")
const SEA_SHADER: String = "res://scenes/art/sea/world_sea.gdshader"
const SEA_Z: int = -40
const DECK_Z: int = -20
const SHARK := CrossingBeat.Kind.SHARK_PASS
const SQUALL := CrossingBeat.Kind.SQUALL
const TIMEOUT_S: float = 6.0
## A scroll period: two lengths of the 32 px water texture (design.md T18).
const SCROLL_WRAP_PX: float = 64.0

var net: NetHarness
var islands: Array[SandbarIsland] = []
var rng := RandomNumberGenerator.new()
var _solo: bool = false


func before_each() -> void:
	WeatherManager.stop()
	WeatherManager.sky.start_at(0.0)


func after_each() -> void:
	if net != null:
		net.teardown()
		net = null
	for island: SandbarIsland in islands:
		island.free()
	islands.clear()
	if _solo:
		NetManager.leave()
		_solo = false


func _start_solo() -> void:
	NetManager.start_solo()
	WeatherManager.stop()
	WeatherManager.sky.start_at(0.0)
	_solo = true


# The sandbar in `session`, with a crossing launched on every route start (the shell's job).
func _setup(session: CoopSession) -> void:
	var island := ISLAND_SCENE.instantiate() as SandbarIsland
	add_child(island)
	islands.append(island)
	session.terrain = island.terrain
	session.climate = island.climate
	session.spawn_points = island.spawn_points(false)
	island.furnish(session)
	var routes := session.get_node("Routes") as IslandRoutes
	routes.route_started.connect(func(id: StringName, peers: Array[int]) -> void:
		var route := GameState.content.get_entry(&"routes", id) as RouteData
		var integrity: float = routes.departure_integrity.get(id, float(route.vessel_integrity))
		Crossing.launch(session, route, peers, integrity, DataEnums.DistanceBand.COAST, rng))


# A host and a client, spawned and settled, with both on a raft the host launched; the host's
# crossing gets a 600 s plan with no beats. Empty on a timeout.
func _raft_pair() -> Array[CoopSession]:
	net = NetHarness.new(self)
	var host := net.add_host(_setup)
	var client := await net.join(_setup)
	assert_not_null(client)
	if client == null:
		return []
	assert_true(await net.settle())
	net.silence_input()
	var site := host.get_node("RaftSite") as BuildSite
	for id: int in host.peer_ids():
		host.body(id).global_position = site.global_position
	var builder := host.body(1)
	builder.inventory.add(&"driftwood", 6)
	builder.inventory.add(&"inner_tube", 2)
	builder.inventory.add(&"rope", 3)
	site.deposit(builder)
	site.work(1.0)
	assert_true(host.start_route_for(1, &"raft"), "the raft leaves with both")
	var crossing := host.get_node_or_null(^"Crossing0") as Crossing
	if crossing == null:
		return []
	crossing.plan = CrossingPlan.create(600.0)
	var pair: Array[CoopSession] = [host, client]
	return pair


# The crossing numbered 0 on `session` once it exists and has a plan, or null.
func _crossing_on(session: CoopSession) -> Crossing:
	var path := NodePath(Crossing.node_name_for(0))
	var built := func() -> bool:
		var found := session.get_node_or_null(path) as Crossing
		return found != null and found.plan != null
	if not await wait_until(built, TIMEOUT_S):
		return null
	return session.get_node(path) as Crossing


func _sea_of(crossing: Crossing) -> Polygon2D:
	return crossing.get_node_or_null(^"Sea") as Polygon2D


func _deck_of(crossing: Crossing) -> Sprite2D:
	return crossing.get_node_or_null(^"Deck") as Sprite2D


# The raft frame StructureArt picks for `integrity`, or null for no deck.
func _raft_texture(integrity: float) -> Texture2D:
	var frame: StringName = StructureArt.raft_frame(integrity)
	if frame == StructureArt.NO_FRAME:
		return null
	return StructureArtData.standard().raft.get_frame_texture(frame, 0)


# True when `crossing`'s deck shows the raft frame for `integrity` (hidden at 0).
func _deck_shows(crossing: Crossing, integrity: float) -> bool:
	var deck := _deck_of(crossing)
	if deck == null:
		return false
	var wanted := _raft_texture(integrity)
	if wanted == null:
		return not deck.visible
	return deck.visible and deck.texture == wanted


# The rect `crossing`'s deck sprite covers, in the crossing's space (its children sit at (0, 0)).
func _deck_drawn_rect(deck: Sprite2D) -> Rect2:
	return deck.get_transform() * deck.get_rect()


func _water_line_on(body: PlayerBody) -> bool:
	var sprite := body.get_node_or_null(^"Look/Sprite") as CanvasItem
	var material := sprite.material as ShaderMaterial if sprite != null else null
	return material != null and bool(material.get_shader_parameter(&"water_line_on"))


func _shark_look(shark: Creature) -> AnimatedSprite2D:
	return shark.get_node_or_null(^"Look/Sprite") as AnimatedSprite2D


# The reef sharks `session` shows inside `sea` (the crossing's, not the island's).
func _sharks_in(session: CoopSession, sea: Rect2) -> Array[Creature]:
	var found: Array[Creature] = []
	for child: Node in session.entities.get_children():
		var creature := child as Creature
		if creature != null and creature.data.id == &"reef_shark" and not creature.is_queued_for_deletion() and sea.has_point(creature.position):
			found.append(creature)
	return found


func _assert_sea_is_deep_shader(crossing: Crossing, peer: String) -> void:
	var sea := _sea_of(crossing)
	assert_not_null(sea, "%s: the crossing's sea is a polygon" % peer)
	if sea == null:
		return
	assert_true(sea.is_in_group(&"art_view"), "%s: the sea is art" % peer)
	assert_eq(DrawOrder.absolute_z(sea), SEA_Z, "%s: the sea at -40" % peer)
	var material := sea.material as ShaderMaterial
	assert_not_null(material, "%s: the sea has a shader material" % peer)
	if material == null:
		return
	assert_eq((material.shader as Shader).resource_path, SEA_SHADER, "%s: the island's sea shader" % peer)
	var deep: int = TerrainArt.data().depth_steps[DataEnums.Terrain.DEEP]
	assert_eq(int(material.get_shader_parameter(&"deep_row")), deep, "%s: deep is the ramps' deep row" % peer)
	var bytes := sea.get(&"depth_bytes") as PackedByteArray
	assert_eq(bytes.size(), Crossing.SEA_TILES.x * Crossing.SEA_TILES.y, "%s: one depth byte per sea cell" % peer)
	var not_deep: int = 0
	for step: int in bytes:
		if step != deep:
			not_deep += 1
	assert_eq(not_deep, 0, "%s: every cell is the deep step, the deck's included (design.md T19)" % peer)
	assert_not_null(material.get_shader_parameter(&"depth_mask"), "%s: the mask is set" % peer)
	assert_not_null(material.get_shader_parameter(&"water"), "%s: so is the water texture" % peer)
	assert_not_null(material.get_shader_parameter(&"ramps"), "%s: and its ramps" % peer)
	assert_eq(SeaShaderChecks.drift_of(material), Vector2(SeaShaderChecks.DRIFT_PX_PER_S, 0.0), "%s: it drifts 5 px/s east, as the islands' sea does" % peer)


# The sea moved with `crossing.scroll_px()` and covers the whole sea rect at this scroll.
func _assert_sea_follows(crossing: Crossing, peer: String) -> void:
	var sea := _sea_of(crossing)
	if sea == null:
		return
	assert_eq(sea.position, Vector2(0.0, crossing.scroll_px()), "%s: the sea sits at the crossing's scroll" % peer)
	var bounds := Rect2(sea.polygon[0], Vector2.ZERO)
	for point: Vector2 in sea.polygon:
		bounds = bounds.expand(point)
	bounds.position += sea.position
	assert_true(bounds.encloses(crossing.sea_rect()), "%s: the scrolled sea still covers the crossing's sea" % peer)


# --- solo -----------------------------------------------------------------------------------------

func test_a_solo_crossing_sea_is_the_deep_sea_shader_under_everything() -> void:
	_start_solo()
	var crossing := CrossingRig.make(self, &"raft", 1, 100.0, 90.0)
	await wait_process_frames(2)
	_assert_sea_is_deep_shader(crossing, "solo")
	var sea := _sea_of(crossing)
	if sea != null:
		assert_true(DrawOrder.drawn_after(crossing.body_of(1), sea), "the rider over the sea")


func test_a_solo_crossing_sea_follows_the_crossing_scroll() -> void:
	_start_solo()
	var crossing := CrossingRig.make(self, &"raft", 1, 100.0, 90.0)
	await wait_process_frames(2)
	var first: float = crossing.scroll_px()
	_assert_sea_follows(crossing, "solo")
	await wait_seconds(0.3)
	assert_ne(crossing.scroll_px(), first, "the crossing scrolls")
	assert_between(crossing.scroll_px(), 0.0, SCROLL_WRAP_PX, "and wraps at 64 px")
	_assert_sea_follows(crossing, "solo")


func test_the_deck_shows_the_raft_frame_for_its_integrity_and_is_gone_once_sunk() -> void:
	_start_solo()
	var crossing := CrossingRig.make(self, &"raft", 1, 100.0, 90.0)
	await wait_process_frames(2)
	var deck := _deck_of(crossing)
	assert_not_null(deck, "the deck is a sprite")
	if deck == null:
		return
	assert_true(deck.is_in_group(&"art_view"))
	assert_eq(DrawOrder.absolute_z(deck), DECK_Z)
	var sea := _sea_of(crossing)
	if sea != null:
		assert_true(DrawOrder.drawn_after(deck, sea), "the deck over the sea")
	assert_true(DrawOrder.drawn_after(crossing.body_of(1), deck), "the rider aboard over the deck")
	assert_eq(_deck_drawn_rect(deck), crossing.deck_rect(), "the raft frame covers the deck")
	for value: float in [100.0, 50.0, 20.0, 0.0]:
		crossing.hit_vessel(crossing.integrity.value - value)
		await wait_process_frames(2)
		assert_eq(crossing.integrity.value, value)
		assert_true(_deck_shows(crossing, value), "at %d the deck shows %s" % [value, StructureArt.raft_frame(value)])
	assert_true(crossing.integrity.broken)
	assert_false(deck.visible, "a sunk deck is not drawn")


## art-terrain-polish D3 (C14): the raft leans toward land on the beach only. The crossing deck reads
## the raft's frames itself and never the look offset, so it stays on deck_rect.
func test_the_deck_ignores_the_beachs_look_offset() -> void:
	var offsets: Variant = StructureArtData.standard().get(&"look_offsets")
	assert_true(offsets is Dictionary and (offsets as Dictionary).get(StructureArt.KIND_RAFT, Vector2.ZERO) != Vector2.ZERO, "the beach raft has a look offset")
	_start_solo()
	var crossing := CrossingRig.make(self, &"raft", 1, 100.0, 90.0)
	await wait_process_frames(2)
	var deck := _deck_of(crossing)
	assert_not_null(deck, "the deck")
	if deck == null:
		return
	assert_eq(_deck_drawn_rect(deck), crossing.deck_rect(), "the deck stays on deck_rect")


# --- art-sprite-polish D2 (C22, SP5): a swimmer north of the deck goes under it ------------------

## Between the crossing's sea (-40) and its deck (-20): a swimmer just north of a drawn deck.
const UNDER_DECK_Z: int = -21


func _player_look(body: PlayerBody) -> PlayerLook:
	return body.get_node(^"Look") as PlayerLook


# Puts `body` at `at` and draws its look there now.
func _swim_at(body: PlayerBody, at: Vector2) -> PlayerLook:
	body.global_position = at
	var look := _player_look(body)
	look.step(0.0)
	return look


# A solo raft crossing with its rider thrown in and swimming.
func _solo_swimmer(route: StringName, integrity: float) -> Crossing:
	_start_solo()
	var crossing := CrossingRig.make(self, route, 1, integrity, 90.0)
	crossing.throw_in(1)
	CrossingRig.run(crossing, 0.2)
	await wait_process_frames(2)
	return crossing


## art-sprite-polish 7.1, one player offline: a swimmer 1 px north of the deck's top edge, within its
## span, is drawn after the sea and before the deck; beside the deck (east), south of it and aboard
## the rider keeps z 0; and once the deck has sunk the north swimmer is back at z 0.
func test_a_solo_swimmer_north_of_the_deck_goes_under_it_and_nowhere_else() -> void:
	var crossing: Crossing = await _solo_swimmer(&"raft", 100.0)
	var body := crossing.body_of(1)
	var deck := crossing.deck_rect()
	var look := _swim_at(body, Vector2(deck.get_center().x, deck.position.y - 1.0))
	assert_true(PlayerPose.shows_swim_ring(look.pose), "swimming: %s" % PlayerPose.Pose.keys()[look.pose])
	assert_eq(look.z_index, UNDER_DECK_Z, "north of the deck: under it")
	assert_true(DrawOrder.drawn_after(look, _sea_of(crossing)), "over the sea")
	assert_true(DrawOrder.drawn_after(_deck_of(crossing), look), "under the deck")
	look = _swim_at(body, Vector2(deck.position.x - 4.0, deck.position.y - 1.0))
	assert_eq(look.z_index, UNDER_DECK_Z, "north of the deck's west corner, within the sprite's half-width")
	CrossingRig.put_beside_deck(crossing, body, 6.0)
	look = _swim_at(body, body.global_position)
	assert_eq(look.z_index, 0, "beside the deck, east")
	look = _swim_at(body, Vector2(deck.get_center().x, deck.end.y + 6.0))
	assert_eq(look.z_index, 0, "south of the deck")
	look = _swim_at(body, Vector2(deck.end.x + 40.0, deck.position.y - 1.0))
	assert_eq(look.z_index, 0, "north but well east of the deck")
	crossing.bring_aboard(1)
	CrossingRig.run(crossing, 0.2)
	look = _player_look(body)
	look.step(0.0)
	assert_false(PlayerPose.shows_swim_ring(look.pose), "aboard")
	assert_eq(look.z_index, 0, "a rider aboard")
	crossing.throw_in(1)
	CrossingRig.run(crossing, 0.2)
	crossing.hit_vessel(crossing.integrity.value)
	assert_false(crossing.integrity.intact(), "the deck has sunk")
	look = _swim_at(crossing.body_of(1), Vector2(deck.get_center().x, deck.position.y - 1.0))
	assert_eq(look.z_index, 0, "no deck: back at z 0")


## art-sprite-polish 7.1, one player offline: on a board route a swimmer north of a board goes under
## that board.
func test_a_solo_swimmer_north_of_a_board_goes_under_it() -> void:
	FixtureRoutes.put_in()
	var crossing: Crossing = await _solo_swimmer(&"test_board", 0.0)
	var board := crossing.deck_rect_of(1)
	assert_true(crossing.boards[1].intact(), "the board is afloat")
	var look := _swim_at(crossing.body_of(1), Vector2(board.get_center().x, board.position.y - 1.0))
	FixtureRoutes.take_out()
	assert_true(PlayerPose.shows_swim_ring(look.pose), "swimming")
	assert_eq(look.z_index, UNDER_DECK_Z, "north of the board: under it")


## art-sprite-polish 7.1, one player offline: an island swimmer, with no crossing, keeps z 0.
func test_a_solo_island_swimmer_keeps_z_0() -> void:
	_start_solo()
	var rig := CreatureRig.make(self)
	var body := rig.player(Vector2i(20, 10))
	body.movement_state = MovementStep.Move.SWIM
	var look := _player_look(body)
	look.step(0.0)
	assert_true(PlayerPose.shows_swim_ring(look.pose), "swimming")
	assert_eq(look.z_index, 0, "no crossing, no deck")


# --- art-sprite-polish D3 (SP1): the fin stays off the deck -------------------------------------

## The rows the water-line shader draws under the line (art_common.gdshaderinc ART_FADE_ROWS).
const FIN_FADE_ROWS: int = 4


# The box of the drawn pixels of `shark`'s current frame, where its look draws it: the frame's
# non-clear texels down to the water line's last faded row, mirrored as the sprite is.
func _fin_box(shark: Creature) -> Rect2:
	var sprite := shark.get_node(^"Look/Sprite") as AnimatedSprite2D
	var atlas := sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame) as AtlasTexture
	var cell: Image = ArtChecks.read_png(atlas.atlas.resource_path).get_region(Rect2i(atlas.region))
	var entry := (load("res://assets/art/creatures/creature_art.tres") as CreatureArt).entry(&"reef_shark")
	var rows: int = mini(cell.get_height(), int(entry.water_line_px) + FIN_FADE_ROWS)
	var low := Vector2i(cell.get_width(), rows)
	var high := Vector2i(-1, -1)
	for y: int in rows:
		for x: int in cell.get_width():
			if cell.get_pixel(x, y).a8 > 0:
				var drawn_x: int = cell.get_width() - 1 - x if sprite.flip_h else x
				low = Vector2i(mini(low.x, drawn_x), mini(low.y, y))
				high = Vector2i(maxi(high.x, drawn_x), maxi(high.y, y))
	var top_left: Vector2 = sprite.global_position - Vector2(cell.get_size()) / 2.0
	return Rect2(top_left + Vector2(low), Vector2(high - low + Vector2i.ONE))


func _crossing_sharks(crossing: Crossing) -> Array[Creature]:
	var found: Array[Creature] = []
	for child: Node in (crossing.get_parent() as CoopSession).entities.get_children():
		if child is Creature and (child as Creature).data.id == &"reef_shark" and not child.is_queued_for_deletion():
			found.append(child as Creature)
	return found


# Runs `crossing` past its shark pass at 6 s and the shark's circle, drawing each shark every step,
# and returns what the fin's drawn box did: the steps it was drawn, and every overlap of an intact
# deck or board rect or step outside the sea.
func _fin_pass(crossing: Crossing, rects: Callable) -> Dictionary:
	var drawn: int = 0
	var spots: Dictionary[Vector2i, bool] = {}
	var bad: PackedStringArray = []
	for step: int in 140:
		crossing.advance(CrossingRig.STEP_S)
		for peer: int in crossing.peers():
			crossing.body_of(peer).advance(CrossingRig.STEP_S)
		for shark: Creature in _crossing_sharks(crossing):
			shark.advance(CrossingRig.STEP_S)
			if shark.is_queued_for_deletion():
				continue
			(shark.get_node(^"Look") as CreatureLook).step(CrossingRig.STEP_S)
			var box := _fin_box(shark)
			drawn += 1
			spots[Vector2i(shark.position.round())] = true
			for rect: Rect2 in rects.call():
				if box.intersects(rect):
					bad.append("%.1f s: %s over %s (%s)" % [crossing.elapsed_s, box, rect, (shark.get_node(^"Look/Sprite") as AnimatedSprite2D).animation])
			if not crossing.sea_rect().encloses(box):
				bad.append("%.1f s: %s outside the sea" % [crossing.elapsed_s, box])
	return {"drawn": drawn, "spots": spots.size(), "bad": bad}


## art-sprite-polish 6.1 (D3, SP1), one player offline: in a raft crossing whose shark pass names the
## east side, the fin's drawn box never overlaps the intact deck from the warning (5 s before the
## pass) through its circle and strike to its retreat, and stays inside the sea.
func test_a_solo_raft_crossings_fin_never_draws_over_the_deck() -> void:
	_start_solo()
	var crossing := CrossingRig.make(self, &"raft", 1, 100.0, 90.0, [CrossingBeat.create(6.0, SHARK, 0, CrossingBeat.Side.EAST)])
	var deck := func() -> Array[Rect2]:
		var rects: Array[Rect2] = []
		if crossing.integrity.intact():
			rects.append(crossing.deck_rect())
		return rects
	var result := _fin_pass(crossing, deck)
	assert_gt(int(result["drawn"]), 50, "the fin was drawn from its warning to its retreat")
	assert_gt(int(result["spots"]), 2, "it circled and then struck")
	assert_eq(result["bad"], PackedStringArray(), "the fin's drawn box stays off the deck and in the sea")


## art-sprite-polish 6.1 (D3, SP1), one player offline: on a board crossing the fin's drawn box never
## overlaps the intact board.
func test_a_solo_board_crossings_fin_never_draws_over_the_board() -> void:
	_start_solo()
	FixtureRoutes.put_in()
	var crossing := CrossingRig.make(self, &"test_board", 1, 0.0, 90.0, [CrossingBeat.create(6.0, SHARK, 0, CrossingBeat.Side.EAST)])
	var boards := func() -> Array[Rect2]:
		var rects: Array[Rect2] = []
		for peer: int in crossing.boards:
			if crossing.boards[peer].intact():
				rects.append(crossing.deck_rect_of(peer))
		return rects
	var result := _fin_pass(crossing, boards)
	FixtureRoutes.take_out()
	assert_gt(int(result["drawn"]), 50, "the fin was drawn from its warning to its retreat")
	assert_eq(result["bad"], PackedStringArray(), "the fin's drawn box stays off the board and in the sea")


func test_a_solo_raft_crossing_with_a_squall_throw_in() -> void:
	_start_solo()
	var crossing := CrossingRig.make(self, &"raft", 1, 100.0, 90.0, [CrossingRig.beat(0.5, SQUALL)])
	var body := crossing.body_of(1)
	CrossingRig.run(crossing, 0.6)
	assert_eq(crossing.rider_state(1), Crossing.Rider.IN_WATER, "the squall throws the rider in")
	CrossingRig.put_beside_deck(crossing, body, 6.0)
	CrossingRig.run(crossing, 0.3)
	await wait_process_frames(2)
	assert_true(_deck_shows(crossing, crossing.integrity.value), "the deck at the vessel's integrity")
	assert_false(crossing.deck_rect().has_point(body.global_position), "the swimmer beside the deck")
	assert_true(_water_line_on(body), "the swimmer is cut at the water line")
	var shadow := body.get_node_or_null(^"Look/Shadow") as CanvasItem
	assert_true(shadow != null and not shadow.visible, "with no shadow")
	var sea := _sea_of(crossing)
	if sea != null:
		assert_true(DrawOrder.drawn_after(body, sea), "drawn over the sea")
	_assert_sea_follows(crossing, "solo")


func test_drawing_the_crossing_changes_nothing_it_simulates() -> void:
	_start_solo()
	var crossing := CrossingRig.make(self, &"raft", 1, 100.0, 90.0)
	var cells: int = crossing.sea.cells.size()
	var deck_terrain: DataEnums.Terrain = crossing.sea.terrain_at(Vector2i((crossing.deck_center() / Crossing.TILE_PX).floor()))
	var spot := crossing.body_of(1).global_position
	crossing.set_physics_process(false)
	await wait_process_frames(3)
	assert_eq(crossing.integrity.value, 100.0)
	assert_eq(crossing.elapsed_s, 0.0, "the clock is the host's step, not the look's")
	assert_eq(crossing.sea.cells.size(), cells)
	assert_eq(crossing.sea.terrain_at(Vector2i((crossing.deck_center() / Crossing.TILE_PX).floor())), deck_terrain)
	assert_eq(crossing.body_of(1).global_position, spot)
	var methods: PackedStringArray = []
	for method: Dictionary in (crossing.get_script() as Script).get_script_method_list():
		methods.append(method[&"name"])
	assert_false(methods.has("_draw"), "the crossing draws nothing itself (design.md T18)")


# --- host and client --------------------------------------------------------------------------

func test_host_and_client_draw_riders_and_the_shark_over_the_sea_and_the_deck() -> void:
	var pair := await _raft_pair()
	if pair.is_empty():
		return
	var host := pair[0]
	var client := pair[1]
	var client_id: int = net.peer_id(client)
	var host_crossing := host.get_node(^"Crossing0") as Crossing
	var client_crossing := await _crossing_on(client)
	assert_not_null(client_crossing, "the client has the crossing")
	if client_crossing == null:
		return
	host_crossing.hit_vessel(40.0)
	host_crossing.throw_in(client_id)
	var swimmer := host_crossing.body_of(client_id)
	swimmer.meters.energy = 15.0
	CrossingRig.put_beside_deck(host_crossing, swimmer, 20.0)
	host_crossing.threats.resolve(CrossingBeat.create(1.0, SHARK), host_crossing)
	var sea := host_crossing.sea_rect()
	var states := func() -> bool:
		var theirs := client_crossing.body_of(client_id)
		return client_crossing.rider_state(client_id) == Crossing.Rider.IN_WATER and theirs != null and not client_crossing.deck_rect().has_point(theirs.global_position) \
				and _sharks_in(client, sea).size() == 1 and _deck_shows(client_crossing, host_crossing.integrity.value)
	assert_true(await wait_until(states, TIMEOUT_S), "the client has the swimmer where the host put it, the shark and the worn deck")
	await wait_process_frames(3)
	for side: Array in [["host", host, host_crossing], ["client", client, client_crossing]]:
		var peer: String = side[0]
		var session: CoopSession = side[1]
		var crossing: Crossing = side[2]
		_assert_sea_is_deep_shader(crossing, peer)
		_assert_sea_follows(crossing, peer)
		assert_true(_deck_shows(crossing, 60.0), "%s: the worn raft at the host's 60" % peer)
		var water := _sea_of(crossing)
		var deck := _deck_of(crossing)
		if water == null or deck == null:
			continue
		assert_true(DrawOrder.drawn_after(crossing.body_of(1), deck), "%s: the rider aboard over the deck" % peer)
		assert_true(DrawOrder.drawn_after(crossing.body_of(client_id), water), "%s: the swimmer over the sea" % peer)
		assert_false(crossing.deck_rect().has_point(crossing.body_of(client_id).global_position), "%s: the swimmer beside the deck" % peer)
		var sharks := _sharks_in(session, sea)
		assert_eq(sharks.size(), 1, "%s: one shark in the crossing's sea" % peer)
		if sharks.is_empty():
			continue
		assert_true(DrawOrder.drawn_after(sharks[0], water), "%s: the shark over the sea" % peer)
		assert_false(crossing.deck_rect().has_point(sharks[0].position), "%s: the shark of a bite is off the deck (design.md T15)" % peer)
		var look := _shark_look(sharks[0])
		assert_not_null(look, "%s: the shark has its look" % peer)
		if look != null:
			# art-sprite-polish D4: patrol comes by facing; a passing shark keeps a new creature's down.
			assert_eq(look.animation, &"patrol_down", "%s: the passing shark glides" % peer)
			assert_true(look.is_playing(), "%s: and the glide plays" % peer)
	var line := func() -> bool: return _water_line_on(client_crossing.body_of(client_id))
	assert_true(await wait_until(line, TIMEOUT_S), "the client draws its own swimmer at the water line")
	assert_true(_water_line_on(host_crossing.body_of(client_id)), "so does the host")


func test_a_late_joiner_draws_the_deck_at_the_host_integrity() -> void:
	var pair := await _raft_pair()
	if pair.is_empty():
		return
	var host := pair[0]
	var host_crossing := host.get_node(^"Crossing0") as Crossing
	host_crossing.hit_vessel(75.0)
	host_crossing.throw_in(net.peer_id(pair[1]))
	var late := await net.join(_setup)
	assert_not_null(late)
	if late == null:
		return
	var theirs := await _crossing_on(late)
	assert_not_null(theirs, "the late joiner builds the crossing")
	if theirs == null:
		return
	await wait_process_frames(3)
	assert_eq(theirs.integrity.value, 25.0)
	assert_true(_deck_shows(theirs, 25.0), "the late joiner's deck is the breaking raft")
	_assert_sea_is_deep_shader(theirs, "late joiner")
	_assert_sea_follows(theirs, "late joiner")

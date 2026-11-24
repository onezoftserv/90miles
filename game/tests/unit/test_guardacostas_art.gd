extends GutTest
## art-guardacostas groups 4 and 5 (design.md D2, D3, D5; art-pass "Shore soldier look", "Patrol boat and
## dinghy look"): the coast guard's art data and how the looks draw it, with exactly 1 player offline
## (the game shell on the real sandbar).
## - GuardacostasArt lists three soldier looks; a soldier named `Creature<n>` takes look n mod 3.
## - Every hull frame's opaque bounds are wider and taller than every raft frame's; the hull's lamp pixel
##   sits on the boat's position (the light's apex) mirrored or not.
## - The patrol look draws the hull sprite only in sight, mirrored by heading, `move` while moving.
## - A solo player's spot lands three soldiers drawn in three different looks, walking and facing their
##   motion; the dinghy is a DinghyLook at `dinghy_px`, rowing in and beached on the landing, and a player
##   walking past it is drawn in front of it from the south and behind it from the north.

const SHELL_SCENE: PackedScene = preload("res://scenes/shell/game_shell.tscn")
const RAFT_SHEET: String = "res://assets/art/structures/raft.png"
const RAFT_CELL: Vector2i = Vector2i(64, 32)
const TILE: float = 16.0
const NIGHT_S: float = 430.0
var settings_path: String = UserTmp.path("test_guardacostas_art_settings.cfg")

var art: GuardacostasArt
var patrol: PatrolData


func before_each() -> void:
	art = GuardacostasArt.standard()
	patrol = (GameState.content.get_entry(&"creatures", &"patrol_boat") as CreatureData).patrol
	NetManager.start_solo()
	WeatherManager.stop()
	WeatherManager.sky.start_at(0.0)
	WeatherManager.sky.weather.rolls_enabled = false


func after_each() -> void:
	WeatherManager.sky.weather.rolls_enabled = true
	WeatherManager.sky.start_at(0.0)
	WeatherManager.stop()
	NetManager.leave()
	if FileAccess.file_exists(settings_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(settings_path))


func _used(texture: Texture2D) -> Rect2i:
	return texture.get_image().get_used_rect()


# --- the data ---------------------------------------------------------------------------------------

func test_three_soldier_looks_dealt_by_the_number_in_the_node_name() -> void:
	assert_not_null(art, "guardacostas_art.tres ships")
	assert_eq(art.soldier_looks.size(), 3)
	var ids: Array[StringName] = []
	for look: PlayerLookData in art.soldier_looks:
		assert_not_null(look)
		assert_eq(look.outfit_id, &"outfit_uniform", "%s wears the uniform" % look.id)
		assert_eq(look.hair_id, &"hair_cap", "and the cap")
		assert_false(ids.has(look.id))
		ids.append(look.id)
	assert_eq(GuardacostasArt.node_number("Creature12"), 12)
	assert_eq(GuardacostasArt.node_number("Creature"), 0)
	assert_eq(GuardacostasArt.node_number("Creature7"), 7)
	assert_eq(art.soldier_look("Creature12"), art.soldier_looks[0])
	assert_eq(art.soldier_look("Creature13"), art.soldier_looks[1])
	assert_eq(art.soldier_look("Creature14"), art.soldier_looks[2])
	assert_eq(art.soldier_look("Creature15"), art.soldier_looks[0])
	var three: Array[StringName] = []
	for n: int in range(40, 43):
		three.append(art.soldier_look("Creature%d" % n).id)
	assert_eq(three.size(), 3)
	assert_ne(three[0], three[1], "three soldiers spawned one after another take three looks")
	assert_ne(three[1], three[2])
	assert_ne(three[0], three[2])


# Spec "The boat is bigger than the raft".
func test_every_hull_frame_is_wider_and_taller_than_every_raft_frame() -> void:
	var raft: Image = (load(RAFT_SHEET) as Texture2D).get_image()
	var raft_w: int = 0
	var raft_h: int = 0
	for x: int in range(0, raft.get_width(), RAFT_CELL.x):
		var used: Rect2i = raft.get_region(Rect2i(Vector2i(x, 0), RAFT_CELL)).get_used_rect()
		raft_w = maxi(raft_w, used.size.x)
		raft_h = maxi(raft_h, used.size.y)
	assert_gt(raft_w, 0, "the raft has frames")
	assert_not_null(art.hull_frames)
	var frames: int = 0
	for animation: StringName in [&"move", &"idle"]:
		assert_true(art.hull_frames.has_animation(animation), "the hull has %s" % animation)
		assert_lte(art.hull_frames.get_frame_count(animation), 4, "the creature frame budget")
		for i: int in art.hull_frames.get_frame_count(animation):
			var used: Rect2i = _used(art.hull_frames.get_frame_texture(animation, i))
			assert_gt(used.size.x, raft_w, "%s %d is wider than the raft (%d)" % [animation, i, raft_w])
			assert_gt(used.size.y, raft_h, "%s %d is taller than the raft (%d)" % [animation, i, raft_h])
			frames += 1
	assert_eq(frames, 4)


func test_the_lamp_pixel_sits_on_the_boats_position_mirrored_or_not() -> void:
	var cell: Image = art.hull_frames.get_frame_texture(&"idle", 0).get_image()
	assert_eq(cell.get_pixelv(art.hull_lamp_px).to_html(false), "fbf236", "the lamp is the lamp colour")
	assert_eq(art.hull_offset(false) + Vector2(art.hull_lamp_px), Vector2.ZERO, "the lamp's pixel at the origin")
	var mirrored_x: float = art.hull_offset(true).x + (art.hull_cell.x - 1 - art.hull_lamp_px.x)
	assert_eq(mirrored_x, 0.0, "and mirrored")
	for i: int in art.hull_frames.get_frame_count(&"move"):
		var frame: Image = art.hull_frames.get_frame_texture(&"move", i).get_image()
		assert_eq(frame.get_pixelv(art.hull_lamp_px).to_html(false), "fbf236", "the lamp holds still in move %d" % i)
	assert_lt(art.hull_top_y(), 0.0, "the hull's top is over the boat's position")


func test_the_dinghy_rows_and_lies_beached_within_the_frame_budget() -> void:
	assert_not_null(art.dinghy_frames)
	assert_true(art.dinghy_frames.has_animation(DinghyLook.ROW))
	assert_true(art.dinghy_frames.has_animation(DinghyLook.BEACHED))
	assert_eq(art.dinghy_frames.get_frame_count(DinghyLook.ROW), 2)
	assert_eq(art.dinghy_frames.get_frame_count(DinghyLook.BEACHED), 1)
	assert_eq(art.dinghy_offset(false) + Vector2(art.dinghy_foot_px), Vector2.ZERO, "the keel's middle on its position")


# --- in a solo run ------------------------------------------------------------------------------------

func _solo() -> GameShell:
	var shell := SHELL_SCENE.instantiate() as GameShell
	shell.settings_path = settings_path
	add_child_autofree(shell)
	(shell.screen as TitleScreen).solo_requested.emit()
	shell.session.body(CoopSession.HOST_ID).player_input.enabled = false
	return shell


func _boat(shell: GameShell) -> Creature:
	var spawner := shell.session.get_node(NodePath(SandbarIsland.CREATURES_NAME)) as CreatureSpawner
	spawner.world.weather_override = GameState.content.get_entry(&"weather", &"calm") as WeatherData
	spawner.set_physics_process(false)
	var boat: Creature = spawner.creatures(&"patrol_boat")[0]
	boat.set_physics_process(false)
	return boat


# The solo run's boat docked by a spot on land, its dinghy rowed in and its squad ashore; `rowing` is
# called once on a tick while the dinghy is between the boat and the landing.
func _land_squad(shell: GameShell, rowing: Callable = Callable()) -> Creature:
	var boat := _boat(shell)
	var brain := boat.brain as PatrolRoute
	brain.set_clock(patrol.horizon_warning_s + 10.0)
	boat.advance(0.0)
	var body := shell.session.body(CoopSession.HOST_ID)
	brain.spot(body, &"sight")
	body.global_position = Vector2(2.5, 2.5) * TILE
	body.stealth_state = MovementStep.Stealth.SUBMERGED
	var seen_rowing: bool = false
	for i: int in 100:
		if boat.squad_state == PatrolRoute.Squad.ASHORE:
			break
		boat.advance(0.1)
		if not seen_rowing and boat.dinghy_t > 0.0 and boat.dinghy_t < 1.0 and rowing.is_valid():
			seen_rowing = true
			rowing.call(boat)
	assert_eq(boat.squad_state, PatrolRoute.Squad.ASHORE)
	return boat


func test_the_patrol_look_draws_the_hull_sprite_only_in_sight_mirrored_by_heading() -> void:
	var shell := _solo()
	await wait_physics_frames(2)
	WeatherManager.sky.start_at(NIGHT_S)
	var boat := _boat(shell)
	var brain := boat.brain as PatrolRoute
	var look := boat.get_node(^"PatrolLook") as PatrolLook
	brain.set_clock(5.0)
	boat.advance(0.0)
	look.step(0.0)
	assert_eq(boat.state_name(), &"HORIZON")
	assert_not_null(look.hull, "a hull sprite")
	assert_false(look.hull.visible, "hidden on the horizon")
	brain.set_clock(patrol.horizon_warning_s + 10.0)
	boat.advance(0.0)
	look.step(0.0)
	boat.advance(0.1)
	look.step(0.1)
	assert_true(look.hull.visible, "shown in its lap")
	assert_eq(look.hull.sprite_frames, art.hull_frames)
	assert_eq(look.hull.animation, &"move", "moving along its lap")
	assert_eq(look.mirrored, boat.facing.x < 0.0, "mirrored by heading")
	assert_eq(look.hull.offset, art.hull_offset(look.mirrored), "the lamp on the boat's position")
	assert_eq(look.light.position, Vector2.ZERO, "the light's apex on the same point")
	look.step(0.1)
	assert_eq(look.hull.animation, &"idle", "idle while it holds still")
	for i: int in 2000:
		boat.advance(0.1)
		if boat.state_name() == &"AWAY":
			break
	look.step(0.1)
	assert_eq(boat.state_name(), &"AWAY")
	assert_false(look.hull.visible, "hidden away")


# Spec "A solo player meets the squad" and "A solo player sees the dinghy land".
func test_a_solo_players_spot_lands_three_soldiers_in_three_looks_and_a_beached_dinghy() -> void:
	var shell := _solo()
	await wait_physics_frames(2)
	var rowing: Dictionary = {}
	var on_rowing := func(boat: Creature) -> void:
		var squad := boat.get_node(^"SquadLook") as SquadLook
		squad.step(0.1)
		rowing["dinghy"] = squad.dinghy
		rowing["animation"] = squad.dinghy.animation() if squad.dinghy != null else &""
		rowing["at"] = squad.dinghy.global_position if squad.dinghy != null else Vector2.ZERO
		rowing["px"] = squad.dinghy_px
	var boat := _land_squad(shell, on_rowing)
	assert_false(rowing.is_empty(), "the dinghy was seen rowing in")
	assert_eq(rowing["animation"], DinghyLook.ROW, "rowing on the way in")
	assert_eq(rowing["at"], rowing["px"], "at dinghy_px")
	var squad := boat.get_node(^"SquadLook") as SquadLook
	squad.step(0.1)
	var dinghy: DinghyLook = squad.dinghy
	assert_not_null(dinghy)
	assert_same(dinghy.get_parent(), boat, "a child of the boat's node, so it sorts by its own y")
	assert_true(dinghy.visible)
	assert_eq(dinghy.animation(), DinghyLook.BEACHED, "beached on the landing")
	assert_eq(dinghy.global_position, IslandLayout.cell_center(boat.landing))
	assert_true(dinghy.is_in_group(&"art_view"))
	# The three soldiers.
	var brain := boat.brain as PatrolRoute
	assert_eq(brain.soldiers.size(), 3)
	var looks: Array[StringName] = []
	for soldier: Creature in brain.soldiers:
		var look := soldier.get_node(^"SquadLook") as SquadLook
		look.step(0.1)
		assert_not_null(look.soldier_sprite, "%s is drawn as a figure" % soldier.name)
		assert_not_null(look.soldier_look)
		assert_eq(look.soldier_look, art.soldier_look(soldier.name))
		assert_false(looks.has(look.soldier_look.id), "no two soldiers share a look")
		looks.append(look.soldier_look.id)
		assert_eq(look.soldier_sprite.offset, PlayerPose.OFFSET, "its feet on the creature's position")
		assert_null(soldier.data.sprite_frames, "CreatureLook stays out")
	# A soldier walking east faces east in a walk; standing still, it stands.
	var walker: Creature = brain.soldiers[0]
	var walker_look := walker.get_node(^"SquadLook") as SquadLook
	walker.set_physics_process(false)
	for i: int in 4:
		walker.position += Vector2(4.0, 0.0)
		walker_look.step(0.1)
	assert_eq(walker_look.pose, PlayerPose.Pose.WALK, "walking")
	assert_eq(walker_look.facing.dir, Facing.Dir.RIGHT, "facing its motion")
	assert_eq(walker_look.soldier_sprite.animation, PlayerPose.animation(PlayerPose.Pose.WALK, Facing.Dir.RIGHT))
	for i: int in 4:
		walker_look.step(0.1)
	assert_eq(walker_look.pose, PlayerPose.Pose.STANDING, "standing when still")
	# A player passing the beached dinghy: in front of it from the south, behind it from the north.
	var body := shell.session.body(CoopSession.HOST_ID)
	body.stealth_state = MovementStep.Stealth.VISIBLE
	body.global_position = dinghy.global_position + Vector2(4.0, TILE * 0.5)
	assert_true(DrawOrder.drawn_after(body, dinghy.sprite), "from the south the player is drawn over the dinghy")
	body.global_position = dinghy.global_position + Vector2(4.0, -TILE * 0.5)
	assert_true(DrawOrder.drawn_after(dinghy.sprite, body), "from the north the dinghy is drawn over the player")

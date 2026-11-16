class_name CreatureWorld
extends RefCounted
## What a creature's brain may read or ask of the island (creatures-ai): the grids, the players,
## lit fires and food on the ground, and the few things it may do to them. Host only: a creature
## without a world does nothing. Tests build one without a session. A crossing's creatures get a
## world on its sea (`for_crossing`): its players are the living riders, and the crossing answers
## where the deck is and who stands where (creature-perch-ride).

const FOOD_TAG: DataEnums.ItemTag = DataEnums.ItemTag.FOOD

var terrain: GridTerrain = GridTerrain.new()
var nav: CreatureNav = null
## The node whose children are the ground items (the session's Pickups).
var pickups: Node = null
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var phase: DataEnums.DayPhase = DataEnums.DayPhase.DAY
## A lit fire keeps land creatures this far (tiles) away: the company radius (crafting-inventory "Fire").
var light_radius_tiles: float = (preload("res://resources/survival_tuning.tres") as SurvivalTuning).company_radius_tiles
## The crossing these creatures ride along with, or null on an island.
var crossing: Crossing = null
## The run's flags, creature counts and effect limits: the session's (a fresh one in a bare rig).
var record: RunRecord = RunRecord.new()
## The session's world event bus (noise and smoke), or null in a bare rig. Group 7's patrol brain
## listens to it; a noise made through it is scaled by `noise_multiplier_at`.
var events: WorldEvents = null
## A test's weather: when set, `weather()` answers it instead of the sky's.
var weather_override: WeatherData = null
## guardacostas-capture: how a docked boat puts its squad ashore, `func(data: CreatureData, at: Vector2)
## -> Creature` (the session's spawn_creature on an island; a test's own). Without one no squad lands.
var spawner: Callable = Callable()
## The island's spot-meter watch (the spawner's), so a landed soldier becomes a sight source.
var watch: PatrolWatch = null
## The island's layout id and the run's seed, which seed a squad's random walk.
var island_id: StringName = &""
var island_run_seed: int = 0
## Where creature ids are read from (the session's catalog; the game's content by default).
var catalog: ContentCatalog = null

# The island's patrol loop and the rules' read-only sea distances, built once for every boat.
var _patrol_loops: Dictionary[String, PatrolLoop] = {}
var _patrol_rules: PatrolTriggers = null


## A world on `on`'s sea for the creatures that ride along with it, writing its session's record.
## Its dice are seeded from the run seed and the crossing's number.
static func for_crossing(on: Crossing) -> CreatureWorld:
	var made := CreatureWorld.new()
	made.crossing = on
	made.terrain = on.sea
	var session := on.session()
	if session != null:
		made.record = session.run_record
		made.pickups = session.pickups
		made.events = session.events if is_instance_valid(session.events) else null
	made.rng.seed = hash([made.run_seed(), on.serial])
	return made


## The weather now (the sky's current weather; a test may override it). The patrol boat reads
## `patrols_in_port` and `disabled_senses` from it.
func weather() -> WeatherData:
	if weather_override != null:
		return weather_override
	return WeatherManager.sky.weather.current


## The loop `patrol`'s boats run on this world's terrain, built once and shared (pure data).
func patrol_loop(patrol: PatrolData) -> PatrolLoop:
	var key: String = "%f|%f" % [patrol.route_lap_s, patrol.route_offshore_tiles]
	if not _patrol_loops.has(key):
		_patrol_loops[key] = PatrolLoop.build(terrain, nav.size, patrol.route_lap_s, patrol.route_offshore_tiles)
	return _patrol_loops[key]


## One boat's trigger rules: the island's sea distances (measured once, shared by every kind) with
## `patrol`'s own radii and a memory of its own.
func patrol_triggers(patrol: PatrolData) -> PatrolTriggers:
	if _patrol_rules == null:
		_patrol_rules = PatrolTriggers.build(terrain, nav.size, patrol)
	var rules: PatrolTriggers = _patrol_rules.fresh()
	rules.use_numbers_of(patrol)
	return rules


## How much a noise made in `cell` is amplified: a place's PoiData.noise_multiplier (a cave echoes
## x2). 1 today: no handmade island has POIs yet, so this is the seam they fill.
func noise_multiplier_at(_cell: Vector2i) -> float:
	return 1.0


## Whether a squad can be put ashore here.
func can_spawn() -> bool:
	return spawner.is_valid()


## Puts a creature of `data` at `at` (pixels) through the spawner, or null.
func spawn_creature(data: CreatureData, at: Vector2) -> Creature:
	if not spawner.is_valid() or data == null:
		return null
	return spawner.call(data, at) as Creature


## The creature data for `id`, from the world's catalog.
func creature_data(id: StringName) -> CreatureData:
	var source: ContentCatalog = catalog if catalog != null else GameState.content
	return source.get_entry(&"creatures", id) as CreatureData


func light_radius_px() -> float:
	return light_radius_tiles * CreatureNav.TILE


## Living player bodies; on a crossing, its riders that are not dead.
func players() -> Array[PlayerBody]:
	var found: Array[PlayerBody] = []
	if crossing != null:
		for peer: int in crossing.peers():
			var rider := crossing.body_of(peer)
			if rider != null and CoopSession.is_alive(rider) and crossing.rider_state(peer) != Crossing.Rider.DEAD:
				found.append(rider)
		return found
	for node: Node in _tree().get_nodes_in_group(PlayerBody.GROUP):
		var body := node as PlayerBody
		if body != null and CoopSession.is_alive(body):
			found.append(body)
	return found


## Every player body on the island, dead ones too (PatrolWatch clears a dead player's meter).
func all_players() -> Array[PlayerBody]:
	var found: Array[PlayerBody] = []
	for node: Node in _tree().get_nodes_in_group(PlayerBody.GROUP):
		var body := node as PlayerBody
		if body != null:
			found.append(body)
	return found


func lit_fires() -> Array[Node2D]:
	var found: Array[Node2D] = []
	for node: Node in _tree().get_nodes_in_group(PlayerBody.FIRE_GROUP):
		if node is Node2D:
			found.append(node as Node2D)
	return found


## A lit fire whose light reaches `position`, or null.
func fire_covering(position: Vector2) -> Node2D:
	for fire: Node2D in lit_fires():
		if fire.global_position.distance_to(position) < light_radius_px():
			return fire
	return null


## Food lying on the ground, in a stable order.
func food_pickups() -> Array[WorldItem]:
	var found: Array[WorldItem] = []
	if pickups == null:
		return found
	for node: Node in pickups.get_children():
		var item := node as WorldItem
		if item != null and item.count > 0 and not item.is_queued_for_deletion() and is_food(item.item_id):
			found.append(item)
	return found


func is_food(item_id: StringName) -> bool:
	var item := GameState.content.get_entry(&"items", item_id) as ItemData
	return item != null and item.tags.has(FOOD_TAG)


## True while the player's client is gone and the body waits for it (PlayerNet.net_dropped, set on
## the host by CoopSession): such a body is not a patrol's target.
static func is_dropped(body: PlayerBody) -> bool:
	return body.net != null and body.net.net_dropped


static func is_swimming(body: PlayerBody) -> bool:
	return body.movement_state == MovementStep.Move.SWIM or body.movement_state == MovementStep.Move.DIVE


## A shark's strike: health and bleeding. The creature's id is the cause of death if it kills.
func strike(body: PlayerBody, data: CreatureData) -> void:
	body.meters.harm(data.damage, data.id)
	body.meters.set_status(DataEnums.Status.BLEEDING, true)


## A crab's pinch: health only.
func pinch(body: PlayerBody, data: CreatureData) -> void:
	body.meters.harm(data.damage, data.id)


## Takes `count` (at most what lies there) from a ground item; returns how many.
func take_from_pickup(item: WorldItem, count: int) -> int:
	var taken: int = mini(count, item.count)
	item.count -= taken
	if item.count <= 0:
		item.interactable.enabled = false
		item.queue_free()
	return taken


## True when `body` carries an item that one of `data`'s ITEM_CARRIED → NEGATE counters names (the
## Pluma de galleguito): that creature takes nothing from them.
static func carries_negator(data: CreatureData, body: PlayerBody) -> bool:
	for counter: CreatureCounterData in data.counters:
		if counter.trigger != CreatureCounterData.Trigger.ITEM_CARRIED or counter.response != CreatureCounterData.Response.NEGATE:
			continue
		var needed: int = maxi(counter.count, 1)
		for id: StringName in counter.item_ids:
			if body.inventory.count_id(id) >= needed:
				return true
		for tag: DataEnums.ItemTag in counter.item_tags:
			if body.inventory.count_tag(tag) >= needed:
				return true
	return false


## Takes one item of the player's held food (their inventory's first FOOD slot); &"" if none.
func take_held(body: PlayerBody) -> StringName:
	var id: StringName = body.inventory.held_food()
	if id.is_empty() or not body.inventory.remove_id(id, 1):
		return &""
	return id


## The crossing's rider state of `body` (DEAD off the crossing or without one).
func rider_state(body: PlayerBody) -> Crossing.Rider:
	if crossing == null or body == null:
		return Crossing.Rider.DEAD
	return crossing.rider_state(crossing.peer_of(body))


## The peer `body` plays under now, or 0 (coop-reconnect: never the node name).
func peer_of(body: PlayerBody) -> int:
	var session := CoopSession.of(body)
	return session.peer_of(body) if session != null else 0


func deck_center() -> Vector2:
	return crossing.deck_center() if crossing != null else Vector2.ZERO


func deck_rect() -> Rect2:
	return crossing.deck_rect() if crossing != null else Rect2()


## The run's seed (the session's world state), or 0 when there is none.
func run_seed() -> int:
	if crossing == null:
		return island_run_seed
	var session: CoopSession = crossing.session()
	if session == null:
		return 0
	var value: Variant = session.world_state.get("run_seed", 0)
	return value if value is int else 0


## The run's day (1 on the first).
func day() -> int:
	return WeatherManager.sky.clock.day


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree

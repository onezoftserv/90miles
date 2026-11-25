class_name RunSounds
extends Node
## sound-pass design D5: one per peer, under the run's HUD. Each frame it reads the run state this
## peer already holds and asks AudioManager for the cues it implies. It writes nothing to the
## session, its bodies, creatures, crossings or the weather, adds no synced property or RPC, and its
## random thunder gaps come from its own generator, so sound never changes the simulation.
## - Own events (this peer's player only): a bag that gains an item (pickup), thirst falling to the
##   Sed bar's pulse step (thirst_low) and the broken compass's needle rattling (compass_rattle).
##   The hurt and use cues come from MetersHud, which follows the body the meters show.
## - World events (every peer, from synced state): the sea, wind and night loops; thunder when a
##   squall is warned (far), breaks, and now and then while it blows; the patrol motor (PatrolSwell,
##   the loudest boat) and a loudhailer line on each new alert serial; a hit on the vessel this
##   player rides (raft_hit); the end of this player's crossing alive (arrival).
## The first state seen of a bag, thirst, vessel or boat only seeds, so a joiner hears nothing old;
## on a client, whose body, vessel or boat may show a default for a moment before the host's state
## lands, everything new only seeds for CLIENT_SETTLE_S.
## Freed with the HUD when the run ends, it stops every loop.

const TILE_PX: float = 16.0
## A vessel's integrity must fall by more than this to count as a hit.
const HIT_EPSILON: float = 0.01
## Seconds a client lets a new body, vessel or boat settle before it trusts a change in it.
const CLIENT_SETTLE_S: float = 1.5

var session: CoopSession = null
## The peer whose player this is.
var local_peer: int = CoopSession.HOST_ID
var bank: SoundBank = null
## Where the cues go: the AudioManager service unless a test hands each peer its own.
var audio: Node = null
## Seconds from first sight in which a new body's bag and thirst, a vessel and a boat only seed:
## below 0 (the default) picks it at bind, 0 on the host and solo, CLIENT_SETTLE_S on a client.
var settle_s: float = -1.0
## This peer's sky, read each frame; tests replace them.
var phase_source: Callable = func() -> DataEnums.DayPhase: return WeatherManager.phase()
var weather_source: Callable = func() -> StringName: return WeatherManager.weather_id()
var pending_source: Callable = func() -> StringName:
	var pending: WeatherData = WeatherManager.sky.weather.pending
	return pending.id if pending != null else &""

var _rng := RandomNumberGenerator.new()
var _thirst: ThresholdCue = null
var _bag := InventoryGain.new()
var _vessels := ChangeWatch.new()
var _serials := ChangeWatch.new()
var _body: PlayerBody = null
var _inventory: Inventory = null
var _was_squall: bool = false
var _was_pending: StringName = &""
var _thunder_in_s: float = INF
var _bound: bool = false
var _now_s: float = 0.0
var _body_since_s: float = 0.0


func _init() -> void:
	name = "RunSounds"


func _process(delta: float) -> void:
	step(delta)


func _exit_tree() -> void:
	_out().stop_loops()


## Follows `run_session` from now on as `peer_id`'s player, and `needle` (the HUD's compass needle)
## if there is one. The weather as it is now only seeds: a joiner arriving in a squall hears no break.
func bind(run_session: CoopSession, peer_id: int, needle: CompassNeedle = null) -> void:
	session = run_session
	local_peer = peer_id
	if bank == null:
		var service_bank: SoundBank = _out().get(&"bank") as SoundBank
		bank = service_bank if service_bank != null else load(SoundBank.STANDARD_PATH) as SoundBank
	_thirst = ThresholdCue.new(bank.thirst_low_at, bank.thirst_rearm_above)
	if settle_s < 0.0:
		settle_s = 0.0 if run_session.multiplayer.is_server() else CLIENT_SETTLE_S
	_vessels.settle_s = settle_s
	_serials.settle_s = settle_s
	_rng.randomize()
	if needle != null and not needle.rattled.is_connected(_on_rattled):
		needle.rattled.connect(_on_rattled)
	_was_squall = RunAmbience.is_squall(weather_source.call(), bank)
	_was_pending = pending_source.call()
	_thunder_in_s = _next_gap() if _was_squall else INF
	_bound = true
	step(0.0)


## One frame of reading: the local body, the ambience, the thunder, the patrol and the crossings.
func step(delta: float) -> void:
	if not _bound or not is_instance_valid(session):
		return
	_now_s += delta
	_follow_body()
	_step_ambience()
	_step_thunder(delta)
	_step_patrol()
	_step_crossings()


# --- own events ----------------------------------------------------------------------------------

func _follow_body() -> void:
	var body: PlayerBody = session.body(local_peer)
	if body != _body:
		if is_instance_valid(_inventory) and _inventory.changed.is_connected(_on_bag_changed):
			_inventory.changed.disconnect(_on_bag_changed)
		_body = body
		_body_since_s = _now_s
		_inventory = body.inventory if body != null else null
		_thirst.reset()
		_bag.reset()
		if _inventory != null:
			_inventory.changed.connect(_on_bag_changed)
			_bag.observe(InventoryGain.counts(_inventory))
	if _body == null:
		return
	if _settling():
		_thirst.reset()
		_thirst.observe(_body.meters.thirst)
		_bag.reset()
		_bag.observe(InventoryGain.counts(_inventory))
	elif not _body.meters.dead and _thirst.observe(_body.meters.thirst):
		_out().play_sfx(&"thirst_low")


func _on_bag_changed() -> void:
	if not is_instance_valid(_inventory):
		return
	if _settling():
		_bag.reset()
		_bag.observe(InventoryGain.counts(_inventory))
	elif _bag.observe(InventoryGain.counts(_inventory)):
		_out().play_sfx(&"pickup")


# True while the local body is new enough that its state may still be arriving (a client only).
func _settling() -> bool:
	return _now_s - _body_since_s < settle_s


func _on_rattled() -> void:
	_out().play_sfx(&"compass_rattle")


# --- world events ----------------------------------------------------------------------------------

func _step_ambience() -> void:
	var squall: bool = RunAmbience.is_squall(weather_source.call(), bank)
	var levels: Dictionary[StringName, float] = RunAmbience.levels(riding() != null, phase_source.call(), squall, bank)
	for id: StringName in levels:
		_out().set_loop_level(id, levels[id])


func _step_thunder(delta: float) -> void:
	var pending: StringName = pending_source.call()
	if pending != _was_pending and RunAmbience.is_squall(pending, bank):
		_out().play_sfx(&"thunder", bank.thunder_far_db)
	_was_pending = pending
	var squall: bool = RunAmbience.is_squall(weather_source.call(), bank)
	if squall and not _was_squall:
		_out().play_sfx(&"thunder")
		_thunder_in_s = _next_gap()
	elif squall:
		_thunder_in_s -= delta
		if _thunder_in_s <= 0.0:
			_out().play_sfx(&"thunder")
			_thunder_in_s = _next_gap()
	else:
		_thunder_in_s = INF
	_was_squall = squall


func _step_patrol() -> void:
	var eye: Vector2 = _body.global_position if is_instance_valid(_body) else Vector2.ZERO
	var loudest: float = 0.0
	var seen: Array[int] = []
	for node: Node in session.entities.get_children():
		var boat := node as Creature
		if boat == null or boat.is_queued_for_deletion() or not boat.is_patrol():
			continue
		var key: int = boat.get_instance_id()
		seen.append(key)
		if _serials.observe(key, float(boat.alert_serial), _now_s) > 0.0:
			_out().play_sfx(&"loudhailer")
		var warning_s: float = boat.data.patrol.horizon_warning_s
		var distance_tiles: float = boat.global_position.distance_to(eye) / TILE_PX
		loudest = maxf(loudest, PatrolSwell.level(boat.state_id, boat.route_t, warning_s, distance_tiles, bank))
	_serials.keep_only(seen)
	_out().set_loop_level(&"patrol_motor", loudest)


func _step_crossings() -> void:
	var seen: Array[int] = []
	for node: Node in session.get_children():
		var crossing := node as Crossing
		if crossing == null or crossing.is_queued_for_deletion():
			continue
		if not crossing.ended.is_connected(_on_crossing_ended):
			crossing.ended.connect(_on_crossing_ended)
		if crossing.finished or not crossing.peers().has(local_peer):
			continue
		var vessel: VesselIntegrity = crossing.vessel_of(local_peer)
		if vessel == null or not vessel.has_integrity():
			continue
		var key: int = vessel.get_instance_id()
		seen.append(key)
		if _vessels.observe(key, vessel.value, _now_s) < -HIT_EPSILON:
			_out().play_sfx(&"raft_hit")
	_vessels.keep_only(seen)


func _on_crossing_ended(result: CrossingResult) -> void:
	if result == null or not result.riders.has(local_peer):
		return
	var rider: Dictionary = result.riders[local_peer]
	if not bool(rider.get("dead", false)):
		_out().play_sfx(&"arrival")


## The live crossing this peer's player rides, or null (on an island).
func riding() -> Crossing:
	for node: Node in session.get_children():
		var crossing := node as Crossing
		if crossing != null and not crossing.finished and not crossing.is_queued_for_deletion() \
				and crossing.peers().has(local_peer) and crossing.rider_state(local_peer) != Crossing.Rider.DEAD:
			return crossing
	return null


func _out() -> Node:
	return audio if audio != null else AudioManager


func _next_gap() -> float:
	return _rng.randf_range(bank.thunder_gap_min_s, bank.thunder_gap_max_s)

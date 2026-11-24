class_name PlayerBody
extends CharacterBody2D
## A player's body. It applies the MovementModel to the current MoveIntent with 16 px tiles
## and spends the energy the model asks for. It never reads Input: PlayerInput (local) or
## coop-networking (remote) sets `intent`. On the host it also ticks its SurvivalMeters and
## follows their downed state.

## Every player body, for teammate checks.
const GROUP: StringName = &"players"
## Lit fires (Node2D) join this group; one within the company radius keeps a player company at
## night. crafting-inventory's Fire joins it while lit.
const FIRE_GROUP: StringName = &"lit_fires"
## Finished structures that routes and conditions look up by their `recipe_id` meta.
const STRUCTURE_GROUP: StringName = &"built_structures"
const TILE_SIZE: float = 16.0
## Leeway beyond the 1 tile reach before a timed press is dropped.
const REACH_SLACK_PX: float = 2.0
## How far a held press, a use on a teammate or a request at a bench or a site reaches: the
## picker's 1 tile and the slack. The host and the HUD read this one number.
const HOLD_REACH_PX: float = InteractionPicker.REACH_PX + REACH_SLACK_PX

## What this player wants to do now. Set by PlayerInput, tests or the network.
var intent: MoveIntent = MoveIntent.new()
## Ground and current under the body. Replaced by the island once it exists.
var terrain: TerrainQuery = TerrainQuery.new()
## Clock and weather for the meters. Replaced by weather-daynight once it exists.
var climate: ClimateState = ClimateState.new()
var model: MovementModel = MovementModel.new()
var movement_state: MovementStep.Move = MovementStep.Move.WALK
var stealth_state: MovementStep.Stealth = MovementStep.Stealth.VISIBLE
## Host (guardacostas-stealth): the spot meter, stepped once per physics tick by the island's
## PatrolWatch across every boat. The network group sends `spot_fraction()` as net_spot.
var spot_meter: SpotMeter = SpotMeter.new()
## Every peer: the spot meter's fraction as this peer shows it (0 to 1), the open eye's fill. The host
## writes it from `spot_fraction()` each tick, a client takes it from the host's net_spot.
var spot_shown: float = 0.0
## True when this body belongs to the local peer: it gets the camera and local input.
## Set before the body enters the tree.
@export var local_player: bool = true
## Downed players cannot act; a teammate can drag them (DragHandle). Follows the meters'
## downed state; a dead player stays down and cannot be dragged.
var downed: bool = false
## The player left the island by a route (escape-routes): hidden, not simulated, not ticked.
var left_island: bool = false
## A tied-down rider (crossing) cannot move but still interacts.
var pinned: bool = false
## Host (guardacostas-capture "Captives"): a captured player cannot move, use, craft or pick up; they
## keep quick chat and their meters run. Their soldier leads them by the drag handle's dragger at drag
## speed, or they sit in the dinghy, or ride aboard the boat that hauled them (`captive_aboard`, never
## freed). CaptureRules sets it.
var captive: bool = false
var captive_aboard: bool = false
## Host (guardacostas-capture "Taken captives"): a captive the squad took while a teammate was free. Out
## of play like a rider on the next shore (left_island) until the party next lands.
var taken: bool = false
## A HUD panel holds the interact button (inventory-hud's crafting list, until interact is let go
## after it closes): the local intent carries no interact press meanwhile.
var hud_holds_interact: bool = false
## Scales the energy swimming spends: 0 where the crossing pays its own pace drain instead.
var swim_energy_factor: float = 1.0
## The look slot (0-3) the host gave this body in its spawn payload (art-pass "Player look slots"):
## its clothing colour and look. A plain field, never replicated; set before the body enters the
## tree. Solo is slot 0.
var look_slot: int = 0
## The background this player plays (a BackgroundData id), read by the persuasion check
## (guardacostas-capture, ConditionData BACKGROUND_PRESENT). Empty until the backgrounds change ships
## a way to pick one; host state, never sent.
var background_id: StringName = &""
var interaction_hold: InteractionHold = InteractionHold.new()
## False once coop-networking drives the body: PlayerNet then steps it per intent (host),
## predicts it (owning client) or draws it from host states (other clients).
var auto_advance: bool = true
var _interact_was_held: bool = false

@onready var meters: SurvivalMeters = $SurvivalMeters
@onready var camera: Camera2D = $Camera
@onready var player_input: PlayerInput = $PlayerInput
@onready var drag_handle: DragHandle = $DragHandle
@onready var net: PlayerNet = $PlayerNet
@onready var inventory: Inventory = $Inventory
@onready var crafter: Crafter = $Crafter
@onready var free_handle: FreeHandle = $FreeHandle


func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	refresh_local()
	add_to_group(GROUP)
	meters.at_sea_source = _departed
	meters.downed_changed.connect(set_downed)
	meters.last_stand_changed.connect(_on_last_stand_changed)
	meters.died.connect(_on_died)
	meters.effect_due.connect(_on_effect_due)
	free_handle.interacted.connect(_on_free_handle_used)


func _physics_process(delta: float) -> void:
	if auto_advance:
		advance(delta)
	# Once per host frame, after this frame's movement: PlayerNet may have advanced the body once
	# per queued intent, or not at all while a client's intents stall.
	_tick_meters(delta)


# Meters are host state: only the host ticks them, and clients show what it replicates. The
# energy a client's movement spends in advance() is local prediction that PlayerNet reconciles.
func _tick_meters(delta: float) -> void:
	if left_island or not is_inside_tree() or not multiplayer.is_server():
		return
	# Solo: nobody else alive in the run (a one-player run or the last one alive), so health 0
	# kills instead of waiting for a revive nobody can give.
	meters.solo = not _has_living_teammate(INF)
	crafter.advance(delta)
	meters.tick(delta, _meter_context())


## One simulation step from the current intent. Interactions run only where the world is
## authoritative (the host, or offline); a client predicting its own player passes false.
func advance(delta: float, with_interaction: bool = true) -> void:
	if left_island:
		return
	var result: MovementStep
	if captive:
		free_handle.refresh()
	if downed or captive:
		if with_interaction:
			_interact_was_held = false
			interaction_hold.update(false, delta, self, null)
		result = _dragged_step(delta)
	else:
		if with_interaction:
			_update_interaction(delta)
		var cell := cell()
		var step_intent: MoveIntent = MoveIntent.create(Vector2.ZERO, false, false, intent.interact_held) if pinned else intent
		result = model.step(terrain.terrain_at(cell), terrain.current_at(cell), meters.energy, step_intent, delta, meters.speed_factor(), terrain.is_shaded(cell))
		var swimming: bool = result.movement == MovementStep.Move.SWIM or result.movement == MovementStep.Move.DIVE
		meters.spend_energy(result.energy_spent * (swim_energy_factor if swimming else 1.0))
	movement_state = result.movement
	stealth_state = result.stealth
	velocity = result.velocity * TILE_SIZE
	_move(velocity * delta)


## The spot meter as a fraction of this player's spot time, 0 to 1 (the HUD's open eye).
func spot_fraction() -> float:
	return spot_meter.fraction(SpotMeter.stealth_bonus_s(SpotMeter.stealth_level_of(self)))


## The camera and keyboard follow this body only on its own player's peer.
func refresh_local() -> void:
	var is_local: bool = local_player and is_multiplayer_authority()
	camera.enabled = is_local
	player_input.enabled = is_local


## coop-reconnect: this body now belongs to `peer_id`, a rejoined player's new peer.
func rebind(peer_id: int, net_role: PlayerNet.Role, send: Callable) -> void:
	net.rebind(peer_id, net_role, send)
	refresh_local()


## Host (CaptureRules): makes the body a captive led by `by` (a soldier), or one aboard the boat that
## hauled them (`aboard`), or frees it where it stands. Any press under way is dropped.
func set_captive(value: bool, by: Node2D = null, aboard: bool = false) -> void:
	captive = value
	captive_aboard = value and aboard
	model.reset()
	interaction_hold.cancel(self)
	_interact_was_held = false
	velocity = Vector2.ZERO
	if not downed:
		drag_handle.dragger = by if value and not aboard else null
	free_handle.refresh()


## Host: the captive sits in the dinghy at `at` (nobody leads them now).
func seat_captive(at: Vector2) -> void:
	if not downed:
		drag_handle.dragger = null
	global_position = at
	velocity = Vector2.ZERO
	model.reset()


## The capture state PlayerNet sends: 0 none, 1 a captive, 2 a captive aboard the boat, 3 taken.
func capture_code() -> int:
	if taken:
		return 3
	if captive:
		return 2 if captive_aboard else 1
	return 0


## Client: the host's capture state (the flags only: a taken player leaves play by the host's
## CaptureScene.take_out_of_play call, ordered with the travel that lands them again, so a late sync
## never holds a player who has landed).
func apply_capture_code(code: int) -> void:
	captive = code == 1 or code == 2
	captive_aboard = code == 2
	taken = code == 3


## Whether this body is a captive a teammate may free: led to the dinghy or sitting in it, never one
## aboard the boat or out of play.
func can_be_freed() -> bool:
	return captive and not captive_aboard and not left_island


# Host: a teammate's hold on the "Soltar" handle completed. The host checks the rule again (no soldier
# within the guard radius) and frees the captive where they stand.
func _on_free_handle_used(by: Node) -> void:
	if not is_inside_tree() or not multiplayer.is_server():
		return
	if not can_be_freed() or not free_handle.usable_by(by) or free_handle.guard_near():
		return
	CaptureRules.release(self)


func set_downed(value: bool) -> void:
	downed = value
	model.reset()
	# A captive (dropped while led or sitting in the dinghy) is nobody's to drag away.
	drag_handle.enabled = value and not captive
	if not value and not captive:
		drag_handle.dragger = null


## The terrain cell under the body.
func cell() -> Vector2i:
	return Vector2i(floori(position.x / TILE_SIZE), floori(position.y / TILE_SIZE))


## What the meters need to know about this body right now.
func _meter_context() -> MeterContext:
	var here := cell()
	var context := MeterContext.new()
	context.phase = climate.phase
	context.midday = climate.midday
	context.heat_factor = climate.heat_factor
	context.shaded = terrain.is_shaded(here)
	context.in_water = TerrainQuery.is_water(terrain.terrain_at(here))
	context.swimming = movement_state == MovementStep.Move.SWIM or movement_state == MovementStep.Move.DIVE
	var radius_px: float = meters.tuning.company_radius_tiles * TILE_SIZE
	context.teammate_nearby = _has_living_teammate(radius_px)
	context.near_fire = _near_lit_fire(radius_px)
	context.crafting = crafter.is_crafting()
	context.at_sea = _departed()
	return context


## This player rides a crossing: they left the island by a route (the session's departures, the rule
## UsePlan refuses item use at sea by), or they walk on a crossing's sea under way in the session. Read
## by duck typing: naming the crossing's class here would preload its scene from the player's script.
func _departed() -> bool:
	var session := CoopSession.of(self)
	if session == null:
		return false
	if session.has_left(session.peer_of(self)):
		return true
	for child: Node in session.get_children():
		if child.has_method(&"body_of") and child.get(&"sea") == terrain and not child.get(&"finished"):
			return true
	return false


## Another player who is not dead (downed counts) and not waiting out of play, within `within_px`.
func _has_living_teammate(within_px: float) -> bool:
	for node: Node in get_tree().get_nodes_in_group(GROUP):
		var other := node as PlayerBody
		# A rider waiting out of play on the next island is no company and no one to revive you.
		if other == null or other == self or other.meters.dead or other.left_island:
			continue
		if global_position.distance_to(other.global_position) <= within_px:
			return true
	return false


## A lit fire within `within_px`.
func _near_lit_fire(within_px: float) -> bool:
	for node: Node in get_tree().get_nodes_in_group(FIRE_GROUP):
		var fire := node as Node2D
		if fire != null and global_position.distance_to(fire.global_position) <= within_px:
			return true
	return false


## A solo last stand: lie where you fell like a downed player, but nobody can drag you.
func _on_last_stand_changed(active: bool) -> void:
	set_downed(active)
	if active:
		drag_handle.enabled = false


# A delayed effect of this player's is due (EffectApplier.apply held it in the meters).
func _on_effect_due(effect: EffectData) -> void:
	EffectApplier.apply_now(effect, self, self)


func _on_died() -> void:
	set_downed(true)
	drag_handle.enabled = false
	# Stop now, not when the helper's hold next notices the handle is disabled.
	drag_handle.dragger = null


func _dragged_step(delta: float) -> MovementStep:
	var dragger: Node2D = drag_handle.dragger
	if dragger == null or not is_instance_valid(dragger):
		return MovementStep.new()
	return model.drag_step((dragger.global_position - global_position) / TILE_SIZE, delta)


func _update_interaction(delta: float) -> void:
	var candidate: Interactable = null
	var pressed: bool = intent.interact_held and not _interact_was_held
	_interact_was_held = intent.interact_held
	# A press still counting down is dropped when its target is out of reach; a completed one
	# (a drag) stays, because the dragger walks faster than the body it drags.
	var target: Interactable = interaction_hold.target
	if is_instance_valid(target) and not interaction_hold.completed 			and global_position.distance_to(target.global_position) > HOLD_REACH_PX:
		interaction_hold.cancel(self)
	# Only a fresh press picks a target; holding while walking into reach does nothing.
	if pressed:
		var nearby: Array[Interactable] = []
		for node: Node in get_tree().get_nodes_in_group(Interactable.GROUP):
			var interactable := node as Interactable
			if interactable != null:
				nearby.append(interactable)
		candidate = InteractionPicker.pick(global_position, nearby, self)
	interaction_hold.update(intent.interact_held, delta, self, candidate)


# move_and_slide() takes its time step from the engine, which makes hand-stepped tests inexact;
# moving by an explicit motion and sliding along what was hit gives the same feel and exact
# numbers.
func _move(motion: Vector2) -> void:
	var collision := move_and_collide(motion)
	if collision != null:
		move_and_collide(collision.get_remainder().slide(collision.get_normal()))

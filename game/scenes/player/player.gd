class_name PlayerBody
extends CharacterBody2D
## A player's body. It applies the MovementModel to the current MoveIntent with 16 px tiles
## and spends the energy the model asks for. It never reads Input: PlayerInput (local) or
## coop-networking (remote) sets `intent`. On the host it also ticks its SurvivalMeters and
## follows their downed state.

## Every player body, for teammate checks.
const GROUP: StringName = &"players"
## Lit fires (Node2D) join this group; one within the company radius keeps a player company at
## night. crafting-inventory's fire joins it while lit.
const FIRE_GROUP: StringName = &"lit_fires"
const TILE_SIZE: float = 16.0
## Leeway beyond the 1 tile reach before a timed press is dropped.
const REACH_SLACK_PX: float = 2.0

## What this player wants to do now. Set by PlayerInput, tests or the network.
var intent: MoveIntent = MoveIntent.new()
## Ground and current under the body. Replaced by the island once it exists.
var terrain: TerrainQuery = TerrainQuery.new()
## Clock and weather for the meters. Replaced by weather-daynight once it exists.
var climate: ClimateState = ClimateState.new()
var model: MovementModel = MovementModel.new()
var movement_state: MovementStep.Move = MovementStep.Move.WALK
var stealth_state: MovementStep.Stealth = MovementStep.Stealth.VISIBLE
## True when this body belongs to the local peer: it gets the camera and local input.
## Set before the body enters the tree.
@export var local_player: bool = true
## Downed players cannot act; a teammate can drag them (DragHandle). Follows the meters'
## downed state; a dead player stays down and cannot be dragged.
var downed: bool = false
var interaction_hold: InteractionHold = InteractionHold.new()
var _interact_was_held: bool = false

@onready var meters: SurvivalMeters = $SurvivalMeters
@onready var camera: Camera2D = $Camera
@onready var player_input: PlayerInput = $PlayerInput
@onready var drag_handle: DragHandle = $DragHandle


func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var is_local: bool = local_player and is_multiplayer_authority()
	camera.enabled = is_local
	player_input.enabled = is_local
	add_to_group(GROUP)
	meters.downed_changed.connect(set_downed)
	meters.last_stand_changed.connect(_on_last_stand_changed)
	meters.died.connect(_on_died)


func _physics_process(delta: float) -> void:
	var result: MovementStep
	if downed:
		_interact_was_held = false
		interaction_hold.update(false, delta, self, null)
		result = _dragged_step(delta)
	else:
		_update_interaction(delta)
		var cell := cell()
		result = model.step(terrain.terrain_at(cell), terrain.current_at(cell), meters.energy, intent, delta, meters.speed_factor())
		meters.spend_energy(result.energy_spent)
	movement_state = result.movement
	stealth_state = result.stealth
	velocity = result.velocity * TILE_SIZE
	_move(velocity * delta)
	# Meters are host state: only the host ticks them, and clients show what it replicates. The
	# energy a client's movement spends above is local prediction for coop-networking to reconcile.
	if is_inside_tree() and multiplayer.is_server():
		# Solo: nobody else alive in the run (a one-player run or the last one alive), so health 0
		# kills instead of waiting for a revive nobody can give.
		meters.solo = not _has_living_teammate(INF)
		meters.tick(delta, _meter_context())


func set_downed(value: bool) -> void:
	downed = value
	model.reset()
	drag_handle.enabled = value
	if not value:
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
	return context


## Another player who is not dead (downed counts) within `within_px`.
func _has_living_teammate(within_px: float) -> bool:
	for node: Node in get_tree().get_nodes_in_group(GROUP):
		var other := node as PlayerBody
		if other == null or other == self or other.meters.dead:
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
	if is_instance_valid(target) and not interaction_hold.completed 			and global_position.distance_to(target.global_position) > InteractionPicker.REACH_PX + REACH_SLACK_PX:
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

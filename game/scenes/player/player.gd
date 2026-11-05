class_name PlayerBody
extends CharacterBody2D
## A player's body. It applies the MovementModel to the current MoveIntent with 16 px tiles
## and spends the energy the model asks for. It never reads Input: PlayerInput (local) or
## coop-networking (remote) sets `intent`.

const TILE_SIZE: float = 16.0

## What this player wants to do now. Set by PlayerInput, tests or the network.
var intent: MoveIntent = MoveIntent.new()
## Ground and current under the body. Replaced by the island once it exists.
var terrain: TerrainQuery = TerrainQuery.new()
var model: MovementModel = MovementModel.new()
var movement_state: MovementStep.Move = MovementStep.Move.WALK
var stealth_state: MovementStep.Stealth = MovementStep.Stealth.VISIBLE
## True when this body belongs to the local peer: it gets the camera and local input.
## Set before the body enters the tree.
@export var local_player: bool = true
## Downed players cannot act; a teammate can drag them (DragHandle). The flag is a plain
## property until survival-meters owns it.
var downed: bool = false
var interaction_hold: InteractionHold = InteractionHold.new()

@onready var meters: SurvivalMeters = $SurvivalMeters
@onready var camera: Camera2D = $Camera
@onready var player_input: PlayerInput = $PlayerInput
@onready var drag_handle: DragHandle = $DragHandle


func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var is_local: bool = local_player and is_multiplayer_authority()
	camera.enabled = is_local
	player_input.enabled = is_local


func _physics_process(delta: float) -> void:
	var result: MovementStep
	if downed:
		interaction_hold.update(false, delta, self, null)
		result = _dragged_step(delta)
	else:
		_update_interaction(delta)
		var cell := cell()
		result = model.step(terrain.terrain_at(cell), terrain.current_at(cell), meters.energy, intent, delta)
		meters.spend_energy(result.energy_spent)
	movement_state = result.movement
	stealth_state = result.stealth
	velocity = result.velocity * TILE_SIZE
	_move(velocity * delta)


func set_downed(value: bool) -> void:
	downed = value
	drag_handle.enabled = value
	if not value:
		drag_handle.dragger = null


## The terrain cell under the body.
func cell() -> Vector2i:
	return Vector2i(floori(position.x / TILE_SIZE), floori(position.y / TILE_SIZE))


func _dragged_step(delta: float) -> MovementStep:
	var dragger: Node2D = drag_handle.dragger
	if dragger == null or not is_instance_valid(dragger):
		return MovementStep.new()
	return model.drag_step((dragger.global_position - global_position) / TILE_SIZE, delta)


func _update_interaction(delta: float) -> void:
	var candidate: Interactable = null
	if intent.interact_held and interaction_hold.target == null:
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

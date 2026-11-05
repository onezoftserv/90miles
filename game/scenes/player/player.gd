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
var local_player: bool = true

@onready var meters: SurvivalMeters = $SurvivalMeters
@onready var camera: Camera2D = $Camera
@onready var player_input: PlayerInput = $PlayerInput


func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var is_local: bool = local_player and is_multiplayer_authority()
	camera.enabled = is_local
	player_input.enabled = is_local


func _physics_process(delta: float) -> void:
	var cell := cell()
	var result := model.step(terrain.terrain_at(cell), terrain.current_at(cell), meters.energy, intent, delta)
	movement_state = result.movement
	stealth_state = result.stealth
	meters.spend_energy(result.energy_spent)
	velocity = result.velocity * TILE_SIZE
	_move(velocity * delta)


## The terrain cell under the body.
func cell() -> Vector2i:
	return Vector2i(floori(position.x / TILE_SIZE), floori(position.y / TILE_SIZE))


# move_and_slide() takes its time step from the engine, which makes hand-stepped tests inexact;
# moving by an explicit motion and sliding along what was hit gives the same feel and exact
# numbers.
func _move(motion: Vector2) -> void:
	var collision := move_and_collide(motion)
	if collision != null:
		move_and_collide(collision.get_remainder().slide(collision.get_normal()))

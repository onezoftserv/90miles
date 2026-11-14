class_name Creature
extends Node2D
## One creature of the island or the crossing (creatures-ai), read from its CreatureData: a generic
## scene, a brain from the data's behavior. Host only: the host ticks the brain and the session
## syncs position, facing and state; a client draws the creature and never moves or damages with
## it. `world` is set on the host's creatures only.

const SCENE: PackedScene = preload("res://scenes/creatures/creature.tscn")
const SYNC_NAME: StringName = &"Sync"
const SYNC_INTERVAL_S: float = 0.1

var data: CreatureData
var brain: CreatureBrain
## Set by the host's spawner; without it the creature does nothing.
var world: CreatureWorld = null
## What it stole, item id to count.
var carried: Dictionary[StringName, int] = {}
## Where it lives (a gull's palm).
var nest: Vector2 = Vector2.ZERO
## Synced: where it faces, and the brain's state.
var facing: Vector2 = Vector2.DOWN
var state_id: int = 0
## Seconds before it frees itself; negative means it stays (the crossing's visual shark).
var lifetime_s: float = -1.0
## Host: the bodies (instance ids) that have seen it, so its sighting effects reach each once.
var seen_by: Dictionary[int, bool] = {}
## Host: it rides along with a crossing (CrossingCreatures), so it is not one of the island's.
var passing: bool = false

@onready var interactable: Interactable = $Interactable


static func make(creature_data: CreatureData) -> Creature:
	var made := SCENE.instantiate() as Creature
	made.data = creature_data
	made.brain = CreatureBrain.for_behavior(creature_data.behavior)
	return made


func _ready() -> void:
	var shoo_counter := CreatureBrain.counter_for(data, CreatureCounterData.Trigger.INTERACT)
	interactable.hold_time_s = 0.0
	interactable.enabled = shoo_counter != null
	interactable.interacted.connect(_on_interacted)


## Adds the synchronizer that sends position, facing and state to the clients; the session does
## it for the creatures it spawns, so a creature outside the session has none.
func attach_sync() -> void:
	var config := SceneReplicationConfig.new()
	for property: String in [".:position", ".:facing", ".:state_id"]:
		config.add_property(NodePath(property))
		config.property_set_spawn(NodePath(property), true)
		config.property_set_replication_mode(NodePath(property), SceneReplicationConfig.REPLICATION_MODE_ALWAYS)
	var sync := MultiplayerSynchronizer.new()
	sync.name = SYNC_NAME
	sync.replication_interval = SYNC_INTERVAL_S
	sync.replication_config = config
	add_child(sync)


func cell() -> Vector2i:
	return CreatureNav.cell_of(position)


## True for a creature that leaves by itself after its lifetime (the crossing's shark) or rides
## along with a crossing: it passes through and is not one of the island's creatures. Host only: a
## client's copy has no lifetime and is not marked.
func is_passing() -> bool:
	return passing or lifetime_s >= 0.0


func state_name() -> StringName:
	return brain.state_name() if brain != null else &"NONE"


## The interact prompt names the creature.
func prompt_target(_by: Node, locale: String) -> String:
	return data.get_display_name(locale) if data != null else ""


## Host: runs the brain for `delta` seconds. A client creature, or one with no world, only waits.
func advance(delta: float) -> void:
	if is_inside_tree() and not multiplayer.is_server():
		return
	if lifetime_s >= 0.0:
		lifetime_s -= delta
		if lifetime_s <= 0.0:
			queue_free()
		return
	if world == null or brain == null:
		return
	brain.tick(self, world, delta)
	state_id = brain.state


## A player shoos it from `by`; true if it fled. Out of reach (the counter's radius) is refused.
func shoo(by: Node2D) -> bool:
	var counter := CreatureBrain.counter_for(data, CreatureCounterData.Trigger.INTERACT)
	if counter == null or brain == null or by.global_position.distance_to(global_position) > counter.radius_tiles * CreatureNav.TILE:
		return false
	var fled: bool = brain.shoo(self, by)
	state_id = brain.state
	return fled


func _physics_process(delta: float) -> void:
	if multiplayer.is_server():
		advance(delta)
	elif brain != null:
		brain.state = state_id


func _on_interacted(by: Node) -> void:
	if multiplayer.is_server() and by is Node2D:
		shoo(by as Node2D)


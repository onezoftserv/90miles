class_name WorldEvents
extends Node
## guardacostas-stealth decision 8: the session's bus of things the world can hear or see. A child
## node named WorldEvents of every CoopSession (never an autoload: it ends with its session, and two
## sessions in one test process keep their own). Host only: on a client every call does nothing, so
## a client can neither forge a noise nor double one the host raised.
## `blood(position)` is not built: no creature bleeds onto the bus yet, so it comes with the
## creatures that need it (the creatures-ai "Blood draws investigation" scenario).

## A noise of `radius_tiles` (already scaled by the place's multiplier) was made at `position` (px).
signal noise_made(position: Vector2, radius_tiles: float, source: StringName)
## A fire was lit at `position` (px), or smoke rose with no fire to point at (`fire` null).
signal smoke_rose(position: Vector2, fire: Node2D)

## The island's world, asked for the noise multiplier of the place a noise is made in
## (CreatureWorld.noise_multiplier_at, 1 today). Without one a noise keeps its radius.
var world: CreatureWorld = null
## The last noise and how many there were, for a test that reads events without a signal.
var last_noise: NoiseEvent = null
var noise_count: int = 0
var last_smoke_position: Vector2 = Vector2.ZERO
var smoke_count: int = 0


## One noise as the bus saw it.
class NoiseEvent extends RefCounted:
	var position: Vector2 = Vector2.ZERO
	var radius_tiles: float = 0.0
	var source: StringName = &""


## Host: a noise at `position` (px) that would carry `radius_tiles`; the place's multiplier is applied
## here (through CreatureWorld.noise_multiplier_at) before `noise_made` goes out.
func make_noise(position: Vector2, radius_tiles: float, source: StringName) -> void:
	if not _is_host() or radius_tiles <= 0.0:
		return
	var scaled: float = radius_tiles
	if world != null:
		var cell := Vector2i(floori(position.x / CreatureNav.TILE), floori(position.y / CreatureNav.TILE))
		scaled *= world.noise_multiplier_at(cell)
	var event := NoiseEvent.new()
	event.position = position
	event.radius_tiles = scaled
	event.source = source
	last_noise = event
	noise_count += 1
	noise_made.emit(position, scaled, source)


## Host: smoke rose at `position` (px) from `fire` (a fire just lit; null for the SMOKE effect).
func raise_smoke(position: Vector2, fire: Node2D) -> void:
	if not _is_host():
		return
	last_smoke_position = position
	smoke_count += 1
	smoke_rose.emit(position, fire)


## The lit fires: what a boat that watches for smoke looks at (the lit_fires group).
func smoke_sources() -> Array[Node2D]:
	var found: Array[Node2D] = []
	if not is_inside_tree():
		return found
	var mine := CoopSession.of(self)
	for node: Node in get_tree().get_nodes_in_group(PlayerBody.FIRE_GROUP):
		if node is Node2D and CoopSession.of(node) == mine:
			found.append(node as Node2D)
	return found


## The bus of the session `node` belongs to, or null outside a session.
static func of(node: Node) -> WorldEvents:
	var session := CoopSession.of(node)
	if session == null:
		return null
	return session.get_node_or_null(^"WorldEvents") as WorldEvents


func _is_host() -> bool:
	return is_inside_tree() and multiplayer.is_server()

class_name IslandArrival
extends RefCounted
## The rules of arriving on the next island (crossing "Arrival", escape-routes "Split parties"),
## pure enough to test without a shell. A rider whose crossing ended is held: out of play, hidden,
## unhurtable, with frozen meters, watching. When the next island loads, every player is landed on
## one of its landing cells.

const HELD_COLLISION_META: StringName = &"held_collision"


## Takes `body` out of play where it stands (a rider whose crossing ended, waiting for the others).
static func hold(body: PlayerBody) -> void:
	if not body.left_island:
		body.set_meta(HELD_COLLISION_META, [body.collision_layer, body.collision_mask])
	body.left_island = true
	body.visible = false
	body.collision_layer = 0
	body.collision_mask = 0


## Puts `body` back in play on `ground` at `at`: visible and solid again, on the island's terrain,
## with nothing left of the sea (no pin, no crossing swim drain, no stride) and no stale network
## history, so a remote body does not slide there from the sea.
static func land(body: PlayerBody, at: Vector2, ground: TerrainQuery) -> void:
	if body.has_meta(HELD_COLLISION_META):
		var saved: Array = body.get_meta(HELD_COLLISION_META)
		body.collision_layer = saved[0]
		body.collision_mask = saved[1]
		body.remove_meta(HELD_COLLISION_META)
	elif body.collision_layer == 0 and body.collision_mask == 0:
		body.collision_layer = 1
		body.collision_mask = 1
	body.left_island = false
	body.visible = true
	body.pinned = false
	body.swim_energy_factor = 1.0
	body.terrain = ground
	body.global_position = at
	body.velocity = Vector2.ZERO
	body.model.reset()
	body.net.net_position = at
	body.net.buffer.clear()
	body.net.interpolator.clear()


## Where each of `peer_ids` stands: the landing cells in the order of the sorted ids, wrapping if
## there are more players than cells.
static func landing_positions(built: IslandLayout, peer_ids: Array[int]) -> Dictionary[int, Vector2]:
	var sorted: Array[int] = peer_ids.duplicate()
	sorted.sort()
	var cells: Array[Vector2i] = built.landing_cells()
	var positions: Dictionary[int, Vector2] = {}
	if cells.is_empty():
		cells = [built.solo_spawn]
	for index: int in sorted.size():
		positions[sorted[index]] = IslandLayout.cell_center(cells[index % cells.size()])
	return positions


## Keeps `body`'s camera inside the island.
static func fit_camera(body: PlayerBody, bounds: Rect2i) -> void:
	body.camera.limit_left = bounds.position.x
	body.camera.limit_top = bounds.position.y
	body.camera.limit_right = bounds.end.x
	body.camera.limit_bottom = bounds.end.y

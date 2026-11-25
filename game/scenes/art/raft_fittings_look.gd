class_name RaftFittingsLook
extends Node2D
## The fittings drawn on a raft (island-stop task 3.6): a placeholder that kitbashes the tracked item
## icons the fittings are made from:
## - the toldo's tarp over the middle of the deck;
## - the defensas' inner tubes on both edges;
## - the clavazón's nails at the near corners.
## It reads its parent each frame: a beached Raft (its look stands bottom-centre on the raft's
## origin, so the 64x32 raft's centre is 16 px up), or a Crossing (the deck's centre, nothing once
## it sank). Drawing only: it never writes the raft or the crossing, and each peer draws the
## fittings it holds. It names neither class, so loading it loads neither scene.

const NODE_NAME: StringName = &"FittingsLook"
## Fitting id -> [the item whose icon stands for it, its spots from the raft's centre]. A fitting
## with no entry draws nothing.
const PIECES: Dictionary = {
	&"raft_toldo": [&"tarp", [Vector2(0.0, -6.0)]],
	&"raft_defensas": [&"inner_tube", [Vector2(-30.0, 2.0), Vector2(30.0, 2.0)]],
	&"raft_clavazon": [&"nails", [Vector2(-18.0, 8.0), Vector2(18.0, 8.0)]],
}
## A beached raft's centre from its origin.
const ISLAND_CENTER: Vector2 = Vector2(0.0, -16.0)

var _shown: Array[StringName] = []
var _sprites: Array[Sprite2D] = []


static func create() -> RaftFittingsLook:
	var look := RaftFittingsLook.new()
	look.name = NODE_NAME
	return look


func _process(_delta: float) -> void:
	step()


## Draws the fittings the parent has now.
func step() -> void:
	var source := get_parent()
	if source == null:
		return
	var fitted: Array[StringName] = []
	if source.has_method(&"deck_center"):
		position = source.call(&"deck_center")
		var vessel: Variant = source.get(&"integrity")
		if vessel is VesselIntegrity and (vessel as VesselIntegrity).intact():
			fitted.assign(source.get(&"fittings"))
	else:
		position = ISLAND_CENTER
		if source.get(&"fittings") is Array:
			fitted.assign(source.get(&"fittings"))
	if fitted == _shown:
		return
	_shown = fitted
	_rebuild()


## The icons on show, for tests.
func sprite_count() -> int:
	var count: int = 0
	for sprite: Sprite2D in _sprites:
		if sprite.visible:
			count += 1
	return count


func _rebuild() -> void:
	for sprite: Sprite2D in _sprites:
		sprite.queue_free()
	_sprites.clear()
	for id: StringName in _shown:
		var piece: Variant = PIECES.get(id)
		if not piece is Array:
			continue
		var item := GameState.content.get_entry(&"items", (piece as Array)[0]) as ItemData
		if item == null or item.sprite == null:
			continue
		for spot: Variant in (piece as Array)[1]:
			var sprite := Sprite2D.new()
			sprite.texture = item.sprite
			sprite.position = spot
			sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			add_child(sprite)
			_sprites.append(sprite)

class_name RaftFittingsLook
extends Node2D
## A raft's fittings drawn over its frame (island-stop task 3.6): the clavazón's nails, the
## defensas' tubes and the toldo's tarp, each a 64x32 overlay from StructureArtData.raft_fittings,
## aligned to the raft frame it sits under. It is the child of the sprite that draws the raft (the
## beached raft's look, or the crossing's deck) and copies that sprite's centring, offset and flip,
## so the overlays stand where the raft stands. It only shows: it never writes the raft, and
## freeing it changes nothing in the simulation. Each peer draws the fittings it holds.

const NODE_NAME: StringName = &"Fittings"

var _shown: Array[Texture2D] = []


## The look under `parent`, made on first use.
static func of(parent: Node2D) -> RaftFittingsLook:
	var look := parent.get_node_or_null(NodePath(NODE_NAME)) as RaftFittingsLook
	if look == null:
		look = RaftFittingsLook.new()
		look.name = NODE_NAME
		# The deck's water line shader reaches the overlays too, so the front tubes sit in the sea.
		look.use_parent_material = true
		parent.add_child(look)
	return look


## Shows the overlays of `fittings` (`data`'s draw order) the way `frame` draws: its centring, offset
## and flip. Nothing for no fittings.
func show_fittings(data: StructureArtData, fittings: Array[StringName], frame: Node2D) -> void:
	var overlays: Array[Texture2D] = data.fitting_overlays(fittings) if data != null else ([] as Array[Texture2D])
	if overlays != _shown:
		_shown = overlays
		for child: Node in get_children():
			remove_child(child)
			child.queue_free()
		for texture: Texture2D in overlays:
			var layer := Sprite2D.new()
			layer.texture = texture
			layer.use_parent_material = true
			add_child(layer)
	var centred: bool = frame.get(&"centered") if frame.get(&"centered") is bool else true
	var offset: Vector2 = frame.get(&"offset") if frame.get(&"offset") is Vector2 else Vector2.ZERO
	var flipped: bool = frame.get(&"flip_h") if frame.get(&"flip_h") is bool else false
	for child: Node in get_children():
		var layer := child as Sprite2D
		layer.centered = centred
		layer.offset = offset
		layer.flip_h = flipped
	visible = not overlays.is_empty()


## The overlays drawn now, bottom first.
func shown() -> Array[Texture2D]:
	return _shown.duplicate()

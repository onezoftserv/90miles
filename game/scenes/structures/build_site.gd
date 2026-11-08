class_name BuildSite
extends Node2D
## A shared build (crafting-inventory "Shared builds"): any player deposits the recipe's inputs
## from their own inventory, progress is shared, and work advances only once every input is in.
## One player can deposit everything and do all the work. When it completes it becomes the
## structure scene named by the recipe id (game/scenes/structures/<id>.tscn).

signal completed(structure: Node)

const STRUCTURE_PATH: String = "res://scenes/structures/%s.tscn"
## A synced site pushes its state to the clients each time progress moved this much (1/120 of
## the build; provisional).
const PUSH_EVERY: float = 1.0 / 120.0

var recipe: RecipeData
var climate: ClimateState = null
var deposited: Dictionary[StringName, int] = {}
## Tag deposits, by ItemTag value.
var tags_deposited: Dictionary[int, int] = {}
## True once the site became its structure.
var built: bool = false
## Placed by a level on every peer at the same path: the host pushes its state to the clients.
var synced: bool = false
## Name the finished structure takes (empty keeps the scene's own), so its path matches on every peer.
var structure_name: StringName = &""
var _progress: float = 0.0
var _pushed_progress: float = 0.0

@onready var interactable: Interactable = $Interactable


func _ready() -> void:
	interactable.hold_time_s = 0.0
	interactable.interacted.connect(_on_interacted)


## The interact prompt names what is being built: the recipe.
func prompt_target(_by: Node, locale: String) -> String:
	return recipe.get_display_name(locale) if recipe != null else ""


## Moves matching inputs from the player's inventory into the site; returns the units moved.
func deposit(player: PlayerBody) -> int:
	var moved: int = 0
	for id: StringName in recipe.inputs:
		var take: int = mini(recipe.inputs[id] - deposited.get(id, 0), player.inventory.count_id(id))
		if take > 0 and player.inventory.remove_id(id, take):
			deposited[id] = deposited.get(id, 0) + take
			moved += take
	if moved > 0:
		_push_state()
	for tag: DataEnums.ItemTag in recipe.input_tags:
		var need: int = recipe.input_tags[tag] - tags_deposited.get(tag, 0)
		var taken: Array[StringName] = player.inventory.take_tag(tag, need)
		tags_deposited[tag] = tags_deposited.get(tag, 0) + taken.size()
		moved += taken.size()
	return moved


## The inputs still to be deposited, by item id, in the recipe's order.
func missing_items() -> Dictionary[StringName, int]:
	var missing: Dictionary[StringName, int] = {}
	for id: StringName in recipe.inputs:
		var short: int = recipe.inputs[id] - deposited.get(id, 0)
		if short > 0:
			missing[id] = short
	return missing


## The tags still to be deposited, by ItemTag value, in the recipe's order.
func missing_tags() -> Dictionary[int, int]:
	var missing: Dictionary[int, int] = {}
	for tag: DataEnums.ItemTag in recipe.input_tags:
		var short: int = recipe.input_tags[tag] - tags_deposited.get(tag, 0)
		if short > 0:
			missing[tag] = short
	return missing


func inputs_complete() -> bool:
	for id: StringName in recipe.inputs:
		if deposited.get(id, 0) < recipe.inputs[id]:
			return false
	for tag: DataEnums.ItemTag in recipe.input_tags:
		if tags_deposited.get(tag, 0) < recipe.input_tags[tag]:
			return false
	return true


## 0 to 1, the same for every player.
func progress() -> float:
	return _progress


## Adds `fraction` of the build. Does nothing (false) until every input is deposited.
func work(fraction: float) -> bool:
	if built or not inputs_complete():
		return false
	_progress = minf(_progress + fraction, 1.0)
	if _progress >= 1.0 - 0.000001:
		_complete()
	elif _progress - _pushed_progress >= PUSH_EVERY:
		_push_state()
	return true


## Clients: the host's deposits, progress and whether it is built. Anything not from the host or
## not shaped like a state is dropped.
@rpc("authority", "call_remote", "reliable")
func receive_state(deposits: Dictionary, progress: float, is_built: bool) -> void:
	if multiplayer.get_remote_sender_id() != 1 or not synced or built or not is_finite(progress):
		return
	for id: StringName in recipe.inputs:
		var amount: Variant = deposits.get(id, 0)
		deposited[id] = clampi(amount if amount is int else 0, 0, recipe.inputs[id])
	_progress = clampf(progress, 0.0, 1.0)
	if is_built:
		_complete()


# Host: sends the current state to every client (a level-placed site only).
func _push_state() -> void:
	_pushed_progress = _progress
	if synced and is_inside_tree() and multiplayer.is_server() and not multiplayer.get_peers().is_empty():
		receive_state.rpc(deposited, _progress, built)


func _on_interacted(by: Node) -> void:
	var player := by as PlayerBody
	if player == null:
		return
	deposit(player)
	player.crafter.start_work(self)


func _complete() -> void:
	built = true
	interactable.enabled = false
	_push_state()
	var scene := load(STRUCTURE_PATH % recipe.id) as PackedScene
	var structure: Node = scene.instantiate() if scene != null else null
	if structure != null:
		if structure is Node2D:
			(structure as Node2D).position = position
		structure.set("climate", climate)
		if not structure_name.is_empty():
			structure.name = structure_name
		get_parent().add_child(structure)
		if structure.has_method(&"on_built"):
			structure.call(&"on_built", recipe)
	completed.emit(structure)
	# Out of the tree at once, so the structure and any later site can take this name.
	get_parent().remove_child(self)
	queue_free()


func _draw() -> void:
	draw_rect(Rect2(-6.0, -6.0, 12.0, 12.0), Color(0.6, 0.5, 0.3, 0.6), false)

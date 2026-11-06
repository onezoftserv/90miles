class_name BuildSite
extends Node2D
## A shared build (crafting-inventory "Shared builds"): any player deposits the recipe's inputs
## from their own inventory, progress is shared, and work advances only once every input is in.
## One player can deposit everything and do all the work. When it completes it becomes the
## structure scene named by the recipe id (game/scenes/structures/<id>.tscn).

signal completed(structure: Node)

const STRUCTURE_PATH: String = "res://scenes/structures/%s.tscn"

var recipe: RecipeData
var climate: ClimateState = null
var deposited: Dictionary[StringName, int] = {}
## Tag deposits, by ItemTag value.
var tags_deposited: Dictionary[int, int] = {}
## True once the site became its structure.
var built: bool = false
var _progress: float = 0.0

@onready var interactable: Interactable = $Interactable


func _ready() -> void:
	interactable.hold_time_s = 0.0
	interactable.interacted.connect(_on_interacted)


## Moves matching inputs from the player's inventory into the site; returns the units moved.
func deposit(player: PlayerBody) -> int:
	var moved: int = 0
	for id: StringName in recipe.inputs:
		var take: int = mini(recipe.inputs[id] - deposited.get(id, 0), player.inventory.count_id(id))
		if take > 0 and player.inventory.remove_id(id, take):
			deposited[id] = deposited.get(id, 0) + take
			moved += take
	for tag: DataEnums.ItemTag in recipe.input_tags:
		var need: int = recipe.input_tags[tag] - tags_deposited.get(tag, 0)
		var taken: Array[StringName] = player.inventory.take_tag(tag, need)
		tags_deposited[tag] = tags_deposited.get(tag, 0) + taken.size()
		moved += taken.size()
	return moved


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
	return true


func _on_interacted(by: Node) -> void:
	var player := by as PlayerBody
	if player == null:
		return
	deposit(player)
	player.crafter.start_work(self)


func _complete() -> void:
	built = true
	interactable.enabled = false
	var scene := load(STRUCTURE_PATH % recipe.id) as PackedScene
	var structure: Node = scene.instantiate() if scene != null else null
	if structure != null:
		if structure is Node2D:
			(structure as Node2D).position = position
		structure.set("climate", climate)
		get_parent().add_child(structure)
		if structure.has_method(&"on_built"):
			structure.call(&"on_built", recipe)
	completed.emit(structure)
	queue_free()


func _draw() -> void:
	draw_rect(Rect2(-6.0, -6.0, 12.0, 12.0), Color(0.6, 0.5, 0.3, 0.6), false)

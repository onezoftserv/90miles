class_name RainCatcher
extends Node2D
## A rain catcher (crafting-inventory "Water structures"): after tuning.rain_fill_s of
## continuous rain it holds the recipe's yield (1 rain cup), once per squall, until a player
## takes it. Rain is the recipe's produce_on_weather_id, read from the ClimateState the sky writes.
## A catcher spawned at a bench carries a synchronizer (`attach_sync`): the host's `cups` reach every
## client, a late joiner included (coop-networking "Structure state on every peer").

## Its synchronizer's node name.
const SYNC_NAME: StringName = &"StateSync"

var tuning: CraftingTuning = preload("res://resources/crafting_tuning.tres")
var climate: ClimateState = null
var recipe: RecipeData = null
## Cups waiting to be taken.
var cups: int = 0

var _rain_s: float = 0.0
var _filled: bool = false

@onready var interactable: Interactable = $Interactable


func _ready() -> void:
	if recipe == null:
		recipe = GameState.content.get_entry(&"recipes", &"rain_catcher") as RecipeData
	interactable.hold_time_s = 0.0
	interactable.interacted.connect(_on_interacted)


## The interact prompt names the item it yields.
func prompt_target(_by: Node, locale: String) -> String:
	var item: ItemData = null
	if recipe != null:
		item = GameState.content.get_entry(&"items", recipe.produces_item_id) as ItemData
	return item.get_display_name(locale) if item != null else ""


## The session's entity spawner adds it to a catcher it spawns: `cups` from the host, with the spawn
## and on each change (structure-state-sync design D3).
func attach_sync() -> void:
	add_child(SitePlacer.state_sync(SYNC_NAME, PackedStringArray([".:cups"])))


func on_built(built_recipe: RecipeData) -> void:
	recipe = built_recipe


func advance(delta: float) -> void:
	var raining: bool = climate != null and climate.weather_id == recipe.produce_on_weather_id
	if not raining:
		_rain_s = 0.0
		_filled = false
		return
	if _filled:
		return
	_rain_s += delta
	if _rain_s >= tuning.rain_fill_s - 0.000001:
		cups += maxi(recipe.produce_count, 1)
		_filled = true


func _physics_process(delta: float) -> void:
	if multiplayer.is_server():
		advance(delta)


# The player takes what fits; the rest stays.
func _on_interacted(by: Node) -> void:
	var player := by as PlayerBody
	if player == null or cups <= 0:
		return
	cups -= player.inventory.add(recipe.produces_item_id, cups)

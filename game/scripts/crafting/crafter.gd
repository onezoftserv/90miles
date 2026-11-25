class_name Crafter
extends Node
## Runs one RecipeData for its player (crafting-inventory "Recipes", "Workbench", "Shared builds"):
## a station craft takes the recipe's time at a workbench in reach and consumes inputs and tool
## wear only when it completes; a build-site recipe places a BuildSite the player then works.
## Host only: the host steps it from the player's physics frame. Clients never run it.

signal crafted(recipe: RecipeData)

var body: PlayerBody

var _recipes: Dictionary[StringName, RecipeData] = {}
var _recipe: RecipeData = null
var _station: Node2D = null
var _site: BuildSite = null
var _elapsed_s: float = 0.0


func _ready() -> void:
	body = get_parent() as PlayerBody


## Makes `recipe` known without a file (tests).
func register(recipe: RecipeData) -> void:
	_recipes[recipe.id] = recipe


## Every recipe this player can name: the content's recipe files and those registered here, one per
## id (a registered one in place of the file).
func known_recipes() -> Array[RecipeData]:
	var by_id: Dictionary[StringName, RecipeData] = {}
	for id: StringName in GameState.content.list_ids(&"recipes"):
		var recipe := GameState.content.get_entry(&"recipes", id) as RecipeData
		if recipe != null:
			by_id[id] = recipe
	by_id.merge(_recipes, true)
	var known: Array[RecipeData] = []
	known.assign(by_id.values())
	return known


func recipe_for(id: StringName) -> RecipeData:
	if _recipes.has(id):
		return _recipes[id]
	return GameState.content.get_entry(&"recipes", id) as RecipeData


func is_crafting() -> bool:
	return _recipe != null or _site != null


## Whether the player carries every input and tool of `recipe`.
func can_craft(recipe: RecipeData) -> bool:
	var inventory := body.inventory
	for id: StringName in recipe.inputs:
		if inventory.count_id(id) < recipe.inputs[id]:
			return false
	for tag: DataEnums.ItemTag in recipe.input_tags:
		if inventory.count_tag(tag) < recipe.input_tags[tag]:
			return false
	for capability: DataEnums.Capability in recipe.tools:
		if inventory.capability_slot(capability) < 0:
			return false
	return true


## Seconds the craft takes this player: a carried fast tool replaces the recipe's own time, and a
## player whose background has the recipe's skill works it `skill_speed_multiplier` times as fast
## (a Mecánico mends and builds the raft at 2×; escape-routes "Shared crafting", island-stop).
func recipe_time(recipe: RecipeData) -> float:
	var fast := _fast_item(recipe)
	if fast != null and fast.tool_action_time_s >= 0.0:
		return fast.tool_action_time_s
	return recipe.time_s / _skill_factor(recipe)


# The recipe's speed-up for this player's background skill, 1 without one.
func _skill_factor(recipe: RecipeData) -> float:
	if recipe.skill == DataEnums.Skill.NONE or recipe.skill_speed_multiplier <= 0.0 or body == null:
		return 1.0
	var background_id: StringName = body.background_id
	if background_id.is_empty():
		return 1.0
	var background := GameState.content.get_entry(&"backgrounds", background_id) as BackgroundData
	if background != null and background.skills.has(recipe.skill):
		return recipe.skill_speed_multiplier
	return 1.0


## Starts a craft at `station` (a Workbench). False, changing nothing, when the recipe needs
## another station, the player is out of reach or lacks an input or tool.
func start(recipe: RecipeData, station: Node2D) -> bool:
	if recipe == null or recipe.build_site or recipe.output_kind != RecipeData.OutputKind.ITEM:
		return false
	if recipe.station != RecipeData.Station.WORKBENCH or not station is Workbench:
		return false
	if not _in_reach(station) or not can_craft(recipe):
		return false
	cancel()
	_recipe = recipe
	_station = station
	_elapsed_s = 0.0
	return true


## Places a build site for `recipe` at `at` under `parent` (the first player who starts it).
func place_site(recipe: RecipeData, at: Vector2, parent: Node) -> BuildSite:
	if recipe == null or not recipe.build_site:
		return null
	var site := preload("res://scenes/structures/build_site.tscn").instantiate() as BuildSite
	site.recipe = recipe
	site.climate = body.climate
	site.position = at
	parent.add_child(site)
	return site


## Starts working `site`; the work advances while this player stays in reach (and, on a staged site,
## holds interact).
func start_work(site: BuildSite) -> bool:
	if site == null or not is_instance_valid(site) or site.built or not _in_reach(site):
		return false
	cancel()
	_site = site
	return true


func cancel() -> void:
	_recipe = null
	_station = null
	_site = null
	_elapsed_s = 0.0


func advance(delta: float) -> void:
	if _site != null:
		_advance_site(delta)
	elif _recipe != null:
		_advance_station(delta)


func _advance_station(delta: float) -> void:
	if not is_instance_valid(_station) or not _in_reach(_station):
		cancel()
		return
	_elapsed_s += delta
	if _elapsed_s < recipe_time(_recipe):
		return
	var recipe := _recipe
	cancel()
	if _finish(recipe):
		crafted.emit(recipe)


# A staged site is worked only while the body holds interact and can act (island-pressure D2); letting
# go ends the work and keeps the progress. Work never runs past the site's limit, and a recipe with a
# work cost charges each second actually worked (D3): no energy, no work.
func _advance_site(delta: float) -> void:
	if not is_instance_valid(_site) or _site.built or not _in_reach(_site):
		_end_site_work()
		return
	var recipe := _site.recipe
	if recipe.is_staged() and not _holding():
		_end_site_work()
		return
	var seconds := recipe_time(recipe)
	var fast_used: bool = _fast_item(recipe) != null
	var work_s: float = delta * _speed(recipe)
	if seconds > 0.0:
		work_s = minf(work_s, _site.work_room() * seconds)
		if work_s <= 0.0:
			return
		work_s = _pay_for_work(recipe, work_s)
		if work_s <= 0.0:
			return
	_site.work(1.0 if seconds <= 0.0 else work_s / seconds)
	if _site.built:
		if fast_used:
			body.inventory.spend_use(body.inventory.capability_slot(recipe.fast_tool))
		cancel()
		crafted.emit(recipe)


# Charges `work_s` seconds of `recipe`'s work cost and returns the seconds of work done. With energy,
# each second worked costs the energy and the thirst (fewer seconds when the energy runs out). With
# none, the hold works at the recipe's slow-work factor and costs the thirst alone (owner Q4 (a)).
func _pay_for_work(recipe: RecipeData, work_s: float) -> float:
	var meters := body.meters
	if recipe.work_energy_per_s > 0.0 and meters.energy <= SurvivalMeters.EMPTY_EPSILON:
		if recipe.exhausted_work_factor <= 0.0:
			return 0.0
		var held_s: float = work_s / recipe.exhausted_work_factor
		if recipe.work_thirst_per_s > 0.0:
			meters.add(DataEnums.Meter.THIRST, -recipe.work_thirst_per_s * held_s)
		return work_s
	if recipe.work_energy_per_s > 0.0:
		work_s = meters.spend_energy(recipe.work_energy_per_s * work_s) / recipe.work_energy_per_s
	if recipe.work_thirst_per_s > 0.0 and work_s > 0.0:
		meters.add(DataEnums.Meter.THIRST, -recipe.work_thirst_per_s * work_s)
	return work_s


# The share of a second's work a second held does: 1, or the slow-work factor with no energy.
func _speed(recipe: RecipeData) -> float:
	if recipe.work_energy_per_s > 0.0 and body.meters.energy <= SurvivalMeters.EMPTY_EPSILON:
		return recipe.exhausted_work_factor
	return 1.0


# The body holds interact and can act: not downed (a solo last stand lies down too), not captive.
func _holding() -> bool:
	return body.intent.interact_held and not body.downed and not body.captive and not body.meters.dead


# The work on a site stops: the site tells every peer where it stopped.
func _end_site_work() -> void:
	if is_instance_valid(_site):
		_site.sync_now()
	cancel()


# Consumes the inputs, spends tool wear and adds the output. If the output does not fit the
# inventory goes back to how it was and nothing is crafted.
func _finish(recipe: RecipeData) -> bool:
	var inventory := body.inventory
	if not can_craft(recipe):
		return false
	var before: Array = inventory.to_net()
	var fast_slot: int = inventory.capability_slot(recipe.fast_tool) if _fast_item(recipe) != null else -1
	for id: StringName in recipe.inputs:
		inventory.remove_id(id, recipe.inputs[id])
	for tag: DataEnums.ItemTag in recipe.input_tags:
		inventory.take_tag(tag, recipe.input_tags[tag])
	for capability: DataEnums.Capability in recipe.tools:
		for i: int in recipe.tool_wear:
			inventory.spend_use(inventory.capability_slot(capability))
	if fast_slot >= 0:
		inventory.spend_use(inventory.capability_slot(recipe.fast_tool))
	if not recipe.output_item_id.is_empty() and inventory.add(recipe.output_item_id, recipe.output_count) < recipe.output_count:
		inventory.from_net(before)
		return false
	return true


func _fast_item(recipe: RecipeData) -> ItemData:
	if recipe.fast_tool == DataEnums.Capability.NONE:
		return null
	var slot: int = body.inventory.capability_slot(recipe.fast_tool)
	if slot < 0:
		return null
	return body.inventory.item_for(body.inventory.slots[slot].item_id)


func _in_reach(node: Node2D) -> bool:
	return body.global_position.distance_to(node.global_position) <= PlayerBody.HOLD_REACH_PX

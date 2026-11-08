class_name CreatureWorld
extends RefCounted
## What a creature's brain may read or ask of the island (creatures-ai): the grids, the players,
## lit fires and food on the ground, and the few things it may do to them. Host only: a creature
## without a world does nothing. Tests build one without a session.

const FOOD_TAG: DataEnums.ItemTag = DataEnums.ItemTag.FOOD

var terrain: GridTerrain = GridTerrain.new()
var nav: CreatureNav = null
## The node whose children are the ground items (the session's Pickups).
var pickups: Node = null
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var phase: DataEnums.DayPhase = DataEnums.DayPhase.DAY
## A lit fire keeps land creatures this far (tiles) away: the company radius (crafting-inventory "Fire").
var light_radius_tiles: float = (preload("res://resources/survival_tuning.tres") as SurvivalTuning).company_radius_tiles


func light_radius_px() -> float:
	return light_radius_tiles * CreatureNav.TILE


## Living player bodies.
func players() -> Array[PlayerBody]:
	var found: Array[PlayerBody] = []
	for node: Node in _tree().get_nodes_in_group(PlayerBody.GROUP):
		var body := node as PlayerBody
		if body != null and CoopSession.is_alive(body):
			found.append(body)
	return found


func lit_fires() -> Array[Node2D]:
	var found: Array[Node2D] = []
	for node: Node in _tree().get_nodes_in_group(PlayerBody.FIRE_GROUP):
		if node is Node2D:
			found.append(node as Node2D)
	return found


## A lit fire whose light reaches `position`, or null.
func fire_covering(position: Vector2) -> Node2D:
	for fire: Node2D in lit_fires():
		if fire.global_position.distance_to(position) < light_radius_px():
			return fire
	return null


## Food lying on the ground, in a stable order.
func food_pickups() -> Array[WorldItem]:
	var found: Array[WorldItem] = []
	if pickups == null:
		return found
	for node: Node in pickups.get_children():
		var item := node as WorldItem
		if item != null and item.count > 0 and not item.is_queued_for_deletion() and is_food(item.item_id):
			found.append(item)
	return found


func is_food(item_id: StringName) -> bool:
	var item := GameState.content.get_entry(&"items", item_id) as ItemData
	return item != null and item.tags.has(FOOD_TAG)


static func is_swimming(body: PlayerBody) -> bool:
	return body.movement_state == MovementStep.Move.SWIM or body.movement_state == MovementStep.Move.DIVE


## A shark's strike: health and bleeding. The creature's id is the cause of death if it kills.
func strike(body: PlayerBody, data: CreatureData) -> void:
	body.meters.harm(data.damage, data.id)
	body.meters.set_status(DataEnums.Status.BLEEDING, true)


## A crab's pinch: health only.
func pinch(body: PlayerBody, data: CreatureData) -> void:
	body.meters.harm(data.damage, data.id)


## Takes `count` (at most what lies there) from a ground item; returns how many.
func take_from_pickup(item: WorldItem, count: int) -> int:
	var taken: int = mini(count, item.count)
	item.count -= taken
	if item.count <= 0:
		item.interactable.enabled = false
		item.queue_free()
	return taken


## Takes one item of the player's held food (their inventory's first FOOD slot); &"" if none.
func take_held(body: PlayerBody) -> StringName:
	var id: StringName = body.inventory.held_food()
	if id.is_empty() or not body.inventory.remove_id(id, 1):
		return &""
	return id


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree

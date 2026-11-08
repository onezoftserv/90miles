class_name CreatureRig
extends RefCounted
## Test helper (creatures-ai): a 30x30 sea with a 6-wide beach strip at the west edge and two
## columns of shallows next to it, one CreatureWorld on it, and creatures, bodies, pick-ups and
## fires added by cell. Creatures are advanced by hand in 0.1 s steps so the times are exact.

const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")
const FIRE_SCENE: PackedScene = preload("res://scenes/structures/fire.tscn")
const STEP_S: float = 0.1
const BEACH_COLUMNS: int = 6
const SIZE: Vector2i = Vector2i(30, 30)

var terrain: GridTerrain = GridTerrain.new()
var world: CreatureWorld = CreatureWorld.new()
var root: Node2D = Node2D.new()
## Typed with the base class: a typed array of its own class leaks at exit.
var creatures: Array[Node2D] = []
var _test: GutTest


static func make(test: GutTest) -> CreatureRig:
	var rig := CreatureRig.new()
	rig._test = test
	rig.terrain.default_terrain = DataEnums.Terrain.DEEP
	rig.terrain.fill_rect(Rect2i(0, 0, BEACH_COLUMNS, SIZE.y), DataEnums.Terrain.BEACH)
	rig.terrain.fill_rect(Rect2i(BEACH_COLUMNS, 0, 2, SIZE.y), DataEnums.Terrain.SHALLOWS)
	rig.world.terrain = rig.terrain
	rig.world.nav = CreatureNav.build(rig.terrain, SIZE)
	rig.world.pickups = rig.root
	rig.world.rng.seed = 7
	test.add_child_autofree(rig.root)
	return rig


static func center(cell: Vector2i) -> Vector2:
	return (Vector2(cell) + Vector2(0.5, 0.5)) * 16.0


## A creature from the catalog (or `data`) standing in `cell`.
func creature(id: StringName, cell: Vector2i, data: CreatureData = null) -> Creature:
	var made := Creature.make(data if data != null else GameState.content.get_entry(&"creatures", id) as CreatureData)
	made.position = center(cell)
	made.nest = made.position
	made.world = world
	root.add_child(made)
	creatures.append(made)
	return made


## A shark whose circle lasts exactly `circle_s`.
func shark(cell: Vector2i, circle_s: float = 6.0) -> Creature:
	var data := (GameState.content.get_entry(&"creatures", &"reef_shark") as CreatureData).duplicate() as CreatureData
	data.circle_time_s = Vector2(circle_s, circle_s)
	return creature(&"reef_shark", cell, data)


func player(cell: Vector2i) -> PlayerBody:
	var body := PLAYER_SCENE.instantiate() as PlayerBody
	_test.add_child_autofree(body)
	body.player_input.enabled = false
	body.global_position = center(cell)
	return body


func pickup(item_id: StringName, count: int, cell: Vector2i) -> WorldItem:
	var item := CoopSession.WORLD_ITEM_SCENE.instantiate() as WorldItem
	item.item_id = item_id
	item.count = count
	item.position = center(cell)
	root.add_child(item)
	return item


func fire(cell: Vector2i) -> Fire:
	var lit := FIRE_SCENE.instantiate() as Fire
	lit.position = center(cell)
	_test.add_child_autofree(lit)
	lit.light()
	return lit


## Advances every creature `seconds`.
func run(seconds: float) -> void:
	for i: int in roundi(seconds / STEP_S):
		for node: Node2D in creatures:
			if is_instance_valid(node):
				(node as Creature).advance(STEP_S)

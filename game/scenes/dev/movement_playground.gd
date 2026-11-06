class_name MovementPlayground
extends Node2D
## Manual-test island for player-movement and survival-meters: land, brush, shallow, deep and
## brackish water, a shaded hut, one interactable, two players under a fixed midday sun, and the
## local player's meters HUD. Everything is drawn with colored rectangles, no textures.

const TILE: int = DevIslandTerrain.TILE
const HUT: Rect2i = DevIslandTerrain.HUT

var terrain: GridTerrain = GridTerrain.new()
## Midday in the day phase, so heat rises outside the hut and sunstroke can be tried by hand.
var climate: ClimateState = ClimateState.new()

@onready var hud: MetersHud = $Hud/MetersHud


func _ready() -> void:
	_build_terrain()
	climate.phase = DataEnums.DayPhase.DAY
	climate.midday = true
	var hud_bound: bool = false
	for child: Node in get_children():
		var body := child as PlayerBody
		if body == null:
			continue
		body.terrain = terrain
		body.climate = climate
		if body.local_player and not hud_bound:
			hud.bind(body.meters)
			hud_bound = true
	queue_redraw()


func _build_terrain() -> void:
	DevIslandTerrain.fill(terrain)


func _draw() -> void:
	DevIslandTerrain.draw(self, terrain)
	for child: Node in get_children():
		if child is Interactable:
			draw_circle((child as Interactable).position, 4.0, Color("8b5a2b"))

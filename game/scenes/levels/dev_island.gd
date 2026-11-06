class_name DevIsland
extends Node2D
## The run's island for now (ui-shell): the dev beach, its spawn points on the sand and the sky's
## climate. The handmade sandbar and island-generation replace it.

const SPAWN_POINTS: Array[Vector2] = [
	Vector2(40.0, 200.0), Vector2(72.0, 200.0), Vector2(40.0, 232.0), Vector2(72.0, 232.0),
]

## The island in pixels: the run camera stays inside it.
const BOUNDS: Rect2i = Rect2i(0, 0, 48 * DevIslandTerrain.TILE, 24 * DevIslandTerrain.TILE)

var terrain: GridTerrain = DevIslandTerrain.build()
## The game's one sky's climate (weather-daynight); the session and the bodies read it.
var climate: ClimateState = WeatherManager.sky.climate


func _ready() -> void:
	queue_redraw()


func _draw() -> void:
	DevIslandTerrain.draw(self, terrain)

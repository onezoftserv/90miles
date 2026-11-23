class_name DayNightTint
extends CanvasModulate
## Tints the scene by the day phase and the weather (weather-daynight "Day cycle"). The colours
## are data (resources/day_cycle.tres and the weather files). HUD CanvasLayers are not tinted.
## Its child WeatherVfx shows the weather's overlay inside the tinted world (art-mood-pass D3).

## Defaults to the game's one sky.
var sky: WorldSky


func _ready() -> void:
	if sky == null:
		sky = WeatherManager.sky
	color = sky.tint()


func _process(_delta: float) -> void:
	color = sky.tint()

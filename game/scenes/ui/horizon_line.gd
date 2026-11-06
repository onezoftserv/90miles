class_name HorizonLine
extends ColorRect
## The dark line on the horizon that announces a squall 60 s early (weather-daynight "Weather
## states"). Lives in the HUD layer so the day tint does not darken it.

const BAND_HEIGHT: float = 6.0
const BAND_WIDTH: float = 640.0
const BAND_COLOR: Color = Color(0.1, 0.12, 0.18, 0.85)

## Defaults to the game's one sky.
var sky: WorldSky


func _ready() -> void:
	if sky == null:
		sky = WeatherManager.sky
	color = BAND_COLOR
	size = Vector2(BAND_WIDTH, BAND_HEIGHT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = sky.horizon_line_visible()


func _process(_delta: float) -> void:
	visible = sky.horizon_line_visible()

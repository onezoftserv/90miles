class_name WeatherVfx
extends Node2D
## The weather's overlay inside the tinted world (art-mood-pass "Squall on screen", design D3): a
## child of DayNightTint, so every scene that tints its world also shows its weather. While the
## current weather has a `vfx_scene` it holds one instance of it (a squall: RainOverlay), and it
## frees that instance when the weather changes away. A new overlay, such as fog, is then data only.
## Because the instance draws in the world's canvas, under the CanvasModulate, the sky's tint
## multiplies it and a fire's light lights it; it is never a CanvasLayer. Drawing only: it reads the
## sky and never writes it.

## Defaults to the tint's sky, else the game's one sky.
var sky: WorldSky
## The overlay it shows now, or null.
var shown: Node = null

var _shown_scene: PackedScene = null


func _init() -> void:
	add_to_group(&"art_view")


func _ready() -> void:
	follow()


func _process(_delta: float) -> void:
	follow()


## Shows the current weather's vfx scene, or nothing: a new instance only when the scene changes.
func follow() -> void:
	var from: WorldSky = _sky()
	var weather: WeatherData = from.weather.current if from != null and from.weather != null else null
	var scene: PackedScene = weather.vfx_scene if weather != null else null
	if scene == _shown_scene:
		return
	if shown != null:
		shown.queue_free()
		shown = null
	_shown_scene = scene
	if scene == null:
		return
	shown = scene.instantiate()
	if &"sky" in shown:
		shown.set(&"sky", from)
	add_child(shown)


func _sky() -> WorldSky:
	if sky != null:
		return sky
	var tint := get_parent() as DayNightTint
	if tint != null and tint.sky != null:
		return tint.sky
	return WeatherManager.sky

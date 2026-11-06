extends GutTest
## crafting-inventory on weather-daynight's sky: the rain catcher reads its recipe's weather and
## fills from the sky's weather cycle; a fire is company at night as the sky's clock reports it.
## Everything runs offline with 1 player.

const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")
const CATCHER_SCENE: PackedScene = preload("res://scenes/structures/rain_catcher.tscn")
const FIRE_SCENE: PackedScene = preload("res://scenes/structures/fire.tscn")
const STEP: float = 0.25


func before_each() -> void:
	NetManager.start_solo()
	WeatherManager.start(0.0)


func after_each() -> void:
	WeatherManager.stop()


func _catcher() -> RainCatcher:
	var catcher := CATCHER_SCENE.instantiate() as RainCatcher
	catcher.climate = WeatherManager.sky.climate
	add_child_autofree(catcher)
	return catcher


func _run(catcher: RainCatcher, seconds: float) -> void:
	for i: int in roundi(seconds / STEP):
		WeatherManager.sky.advance(STEP)
		catcher.advance(STEP)


func test_the_rain_catcher_recipe_names_squall() -> void:
	var recipe := GameState.content.get_entry(&"recipes", &"rain_catcher") as RecipeData
	assert_eq(recipe.produce_on_weather_id, &"squall")
	assert_true(GameState.content.has_entry(&"weather", recipe.produce_on_weather_id))


func test_a_catcher_fills_in_a_squall_of_the_sky_and_not_in_calm() -> void:
	var sky: WorldSky = WeatherManager.sky
	var catcher := _catcher()
	_run(catcher, 50.0)
	assert_eq(sky.weather.current.id, &"calm")
	assert_eq(catcher.cups, 0, "calm gives nothing")
	sky.weather.start_weather(&"squall")
	_run(catcher, 50.0)
	assert_eq(sky.weather.current.id, &"squall")
	assert_eq(catcher.cups, 1, "50 s of squall, one cup")


func test_a_fire_is_company_at_night_only_as_the_sky_reports_it() -> void:
	var sky: WorldSky = WeatherManager.sky
	var body := PLAYER_SCENE.instantiate() as PlayerBody
	body.climate = sky.climate
	add_child_autofree(body)
	var fire := FIRE_SCENE.instantiate() as Fire
	fire.position = Vector2(48, 0)
	add_child_autofree(fire)
	fire.light()
	sky.start_at(DayClock.NIGHT_START_S + 1.0)
	assert_eq(sky.climate.phase, DataEnums.DayPhase.NIGHT)
	body.meters.morale = 50.0
	for i: int in 240:
		body._physics_process(STEP)
	assert_almost_eq(body.meters.morale, 50.0, 0.001, "a lit fire within 5 tiles is company at night")
	fire.put_out()
	for i: int in 240:
		body._physics_process(STEP)
	assert_lt(body.meters.morale, 49.0, "alone at night without it")

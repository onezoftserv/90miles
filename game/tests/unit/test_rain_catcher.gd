extends GutTest
## crafting-inventory "Water structures": a rain catcher fills one rain cup after 30 s of rain,
## once per squall, and holds it until a player takes it.

const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")
const CATCHER_SCENE: PackedScene = preload("res://scenes/structures/rain_catcher.tscn")

var catcher: RainCatcher


func before_each() -> void:
	catcher = CATCHER_SCENE.instantiate() as RainCatcher
	catcher.climate = ClimateState.new()
	add_child_autofree(catcher)


func test_a_rain_cup_fills_during_a_squall() -> void:
	catcher.climate.weather_id = &"squall"
	catcher.advance(29.9)
	assert_eq(catcher.cups, 0)
	catcher.advance(0.2)
	assert_eq(catcher.cups, 1)
	catcher.advance(120.0)
	assert_eq(catcher.cups, 1, "once per squall")


func test_no_rain_no_cup() -> void:
	catcher.climate.weather_id = &"calm"
	catcher.advance(300.0)
	assert_eq(catcher.cups, 0)


func test_a_new_squall_fills_it_again() -> void:
	catcher.climate.weather_id = &"squall"
	catcher.advance(31.0)
	catcher.climate.weather_id = &"calm"
	catcher.advance(1.0)
	catcher.climate.weather_id = &"squall"
	catcher.advance(31.0)
	assert_eq(catcher.cups, 2)


func test_rain_that_stops_early_restarts_the_count() -> void:
	catcher.climate.weather_id = &"squall"
	catcher.advance(20.0)
	catcher.climate.weather_id = &"calm"
	catcher.advance(1.0)
	catcher.climate.weather_id = &"squall"
	catcher.advance(20.0)
	assert_eq(catcher.cups, 0, "30 s of continuous rain")


func test_a_solo_player_takes_the_cup() -> void:
	NetManager.start_solo()
	var body := PLAYER_SCENE.instantiate() as PlayerBody
	add_child_autofree(body)
	catcher.climate.weather_id = &"squall"
	catcher.advance(30.0)
	catcher.interactable.use(body)
	assert_eq(body.inventory.count_id(&"rain_cup"), 1)
	assert_eq(catcher.cups, 0)

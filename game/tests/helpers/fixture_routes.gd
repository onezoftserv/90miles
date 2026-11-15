class_name FixtureRoutes
extends RefCounted
## Test-only routes outside the catalog folder (vessel-car-board). `put_in` places them in
## `GameState.content`'s cache by id so `get_entry(&"routes", id)` finds them; `take_out` removes
## them again. Call `take_out` in `after_each` so no other test or the content check sees them.

const DIR := "res://tests/fixtures/routes"
const IDS: Array[StringName] = [&"test_board", &"test_car"]


## Every fixture route, freshly loaded and in the cache. Returns them by id; edit the returned
## copies freely, they are duplicates of the files.
static func put_in() -> Dictionary[StringName, RouteData]:
	var routes: Dictionary[StringName, RouteData] = {}
	for id: StringName in IDS:
		var route := (load("%s/%s.tres" % [DIR, id]) as RouteData).duplicate(true) as RouteData
		GameState.content._cache["routes/%s" % id] = route
		routes[id] = route
	return routes


static func take_out() -> void:
	for id: StringName in IDS:
		GameState.content._cache.erase("routes/%s" % id)

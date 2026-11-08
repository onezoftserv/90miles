class_name RunSummary
extends RefCounted
## What the run summary shows (endings-progression "Run summary totals" and "Cause of death on
## the run summary"): the totals and one entry per player. Entry keys: `name`, `dead`, `cause`
## (a DeathCause id, empty for a survivor), `cause_label`, `line` (the one-liner), `line_id`,
## `peer` (0 for a removed player), and `route` only for a survivor who left by a route. Living
## players come first in peer order, then the removed in removal order.

var islands_reached: int = 1
var days: int = 1
var length_s: float = 0.0
## Until companions and found texts exist (npcs-dialogue) both stay 0 and the card reads "ninguno".
var companions_saved: int = 0
var companions_lost: int = 0
var texts_found: int = 0
var entries: Array[Dictionary] = []


## The summary of `session`'s run, read from its players, their routes and the run seed.
static func collect(session: CoopSession, islands: int, day: int, run_length_s: float, lines: DeathLines, catalog: ContentCatalog) -> RunSummary:
	var made := RunSummary.new()
	made.islands_reached = islands
	made.days = day
	made.length_s = run_length_s
	var run_seed: int = session.world_state["run_seed"] if session.world_state.get("run_seed") is int else 0
	var routes := session.get_node(^"Routes") as IslandRoutes
	for peer_id: int in session.peer_ids():
		var meters := session.body(peer_id).meters
		var player_name: String = session.player_name(peer_id)
		if meters.dead:
			made._add_dead(player_name, peer_id, DeathCause.of(meters), run_seed, lines, catalog, session.locale)
		else:
			made.entries.append(_survivor(player_name, peer_id, routes.route_left_by(peer_id), catalog))
	var removed: Array[String] = session.removed_names()
	var causes: Array[StringName] = session.removed_causes()
	for index: int in removed.size():
		var cause: StringName = causes[index] if index < causes.size() else DeathCause.REMOVED
		made._add_dead(removed[index], 0, cause, run_seed, lines, catalog, session.locale)
	return made


# A death: the cause, its label and the line this cause's next player gets.
func _add_dead(player_name: String, peer_id: int, cause: StringName, run_seed: int, lines: DeathLines, catalog: ContentCatalog, locale: String) -> void:
	var nth: int = 0
	for earlier: Dictionary in entries:
		if earlier["cause"] == cause:
			nth += 1
	var line := lines.line_for(cause, run_seed, nth)
	entries.append({
		"name": player_name, "dead": true, "cause": cause,
		"cause_label": DeathCause.label(cause, catalog),
		"line": DeathLines.text(line, locale), "line_id": line.id if line != null else &"",
		"peer": peer_id,
	})


static func _survivor(player_name: String, peer_id: int, left_by: StringName, catalog: ContentCatalog) -> Dictionary:
	var entry: Dictionary = {
		"name": player_name, "dead": false, "cause": &"", "cause_label": "",
		"line": "", "line_id": &"", "peer": peer_id,
	}
	if not left_by.is_empty():
		entry["route"] = _route_name(left_by, catalog)
	return entry


static func _route_name(route_id: StringName, catalog: ContentCatalog) -> String:
	var route := catalog.get_entry(&"routes", route_id) as RouteData
	return route.name_es if route != null else String(route_id)

extends GutTest
## endings-progression "Survivor one-liners", "Run summary heading" and "Cause of death on the run
## summary" (scenario "A survivor"), menu-clarity design D2 and D3: a survivor's row gets a Cuban
## one-liner for the route they left by, picked by the run seed as death lines are, and the summary's
## heading follows this peer's own fate. Exactly 1 player, offline, unless two entries are built.

const PATH: String = "res://resources/dialogue/survivor_one_liners.tres"
const SUMMARY_SCENE: PackedScene = preload("res://scenes/shell/summary_screen.tscn")
const SHELL_SCENE: PackedScene = preload("res://scenes/shell/game_shell.tscn")
const MAX_CHARACTERS: int = 120
const STATES: Array[StringName] = [&"raft", &"binoculars_swim", &"other"]
const SWEARS: Array[String] = ["coño", "cojones", "carajo", "pinga", "mierda", "singao", "cabrón", "me cago"]

var _lines: DeathLines
var settings_path: String = UserTmp.path("test_survivor_lines.cfg")


func before_each() -> void:
	NetManager.start_solo()
	_lines = DeathLines.from_catalog(GameState.content, DeathLines.SURVIVOR_ID)


func after_each() -> void:
	NetManager.leave()
	if FileAccess.file_exists(settings_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(settings_path))


func _data() -> DialogueData:
	return load(PATH) as DialogueData


func _swears(text: String) -> bool:
	for word: String in SWEARS:
		if text.to_lower().contains(word):
			return true
	return false


func test_the_content_check() -> void:
	var data := _data()
	assert_not_null(data)
	if data == null:
		return
	assert_eq(data.id, &"survivor_one_liners")
	assert_eq(data.kind, DialogueData.Kind.SURVIVOR_LINES)
	var seen: Array[StringName] = []
	for state: DialogueStateData in data.states:
		seen.append(state.state)
		assert_gte(state.lines.size(), 2, "%s has at least 2 lines" % state.state)
		var n: int = 1
		for line: DialogueLineData in state.lines:
			assert_eq(line.id, StringName("arrival_%s_%d" % [state.state, n]))
			assert_eq(line.speaker_id, &"narrator")
			assert_false(line.text_es.is_empty(), "%s Spanish" % line.id)
			assert_false(line.text_en.is_empty(), "%s English" % line.id)
			assert_lte(line.text_es.length(), MAX_CHARACTERS, "%s Spanish fits" % line.id)
			assert_lte(line.text_en.length(), MAX_CHARACTERS, "%s English fits" % line.id)
			if _swears(line.text_es) or _swears(line.text_en):
				assert_false(line.text_es_soft.is_empty() or line.text_en_soft.is_empty(), "%s swears, so it has soft variants" % line.id)
			n += 1
	assert_eq(seen, STATES)
	assert_eq(ContentValidator.validate(ContentCatalog.new()), PackedStringArray(), "the content validates")


func test_every_state_but_other_is_a_route() -> void:
	for state: StringName in STATES:
		if state != &"other":
			assert_true(GameState.content.has_entry(&"routes", state), "%s is a route" % state)


func test_a_solo_raft_survivor_gets_the_first_raft_line() -> void:
	var config := ConfigFile.new()
	config.set_value("player", "name_asked", true)
	config.save(settings_path)
	var shell := SHELL_SCENE.instantiate() as GameShell
	shell.settings_path = settings_path
	shell.seed_source = func() -> int: return 0
	add_child_autofree(shell)
	shell.start_solo()
	var session: CoopSession = shell.session
	session.body(1).player_input.enabled = false
	var routes := session.get_node(^"Routes") as IslandRoutes
	routes.departed[1] = &"raft"
	var made := RunSummary.collect(session, 2, 1, 60.0, DeathLines.from_catalog(GameState.content), GameState.content, _lines)
	assert_eq(made.entries.size(), 1)
	var entry: Dictionary = made.entries[0]
	assert_false(entry["dead"])
	assert_eq(entry["cause"], &"", "a survivor has no cause")
	assert_eq(entry["route_id"], &"raft")
	assert_eq(entry["line_id"], &"arrival_raft_1")
	assert_eq(entry["line"], DeathLines.text(_lines.line_for(&"raft", 0, 0)))
	var screen := SUMMARY_SCENE.instantiate() as SummaryScreen
	add_child_autofree(screen)
	screen.show_summary(made, "Otra vez", 1)
	assert_eq(screen.heading.text, "Llegaste")
	assert_eq(screen.rows()[0], "%s: Sobrevivió (se fue en: %s)" % [entry["name"], entry["route"]])
	assert_eq(screen.one_liners()[0], entry["line"])
	assert_true(screen.row(0).line.visible)


func test_two_survivors_of_one_route_get_different_lines() -> void:
	var made := RunSummary.new()
	made.add_survivor("Yuni", 1, &"raft", 0, _lines, GameState.content)
	made.add_survivor("Papo", 7, &"raft", 0, _lines, GameState.content)
	assert_eq(made.entries[0]["line_id"], &"arrival_raft_1")
	assert_eq(made.entries[1]["line_id"], &"arrival_raft_2")


func test_a_route_without_lines_uses_the_other_lines() -> void:
	var made := RunSummary.new()
	made.add_survivor("Balsero", 1, &"car_drums", 0, _lines, GameState.content)
	assert_eq(made.entries[0]["line_id"], &"arrival_other_1")


func test_a_survivor_who_left_by_no_route_has_no_line() -> void:
	var made := RunSummary.new()
	made.add_survivor("Balsero", 1, &"", 0, _lines, GameState.content)
	assert_eq(made.entries[0]["line"], "")
	assert_false(made.entries[0].has("route"))


func _entry(peer: int, dead: bool) -> Dictionary:
	var entry: Dictionary = {"name": "P%d" % peer, "dead": dead, "cause": &"drowning" if dead else &"", "cause_label": "ahogamiento" if dead else "", "line": "", "line_id": &"", "peer": peer}
	if not dead:
		entry["route"] = "Balsa"
		entry["route_id"] = &"raft"
	return entry


func test_the_heading_follows_this_peers_own_fate() -> void:
	var made := RunSummary.new()
	made.entries = [_entry(1, false), _entry(7, true)] as Array[Dictionary]
	assert_eq(SummaryScreen.heading_for(made, 1), "Llegaste", "the host left by raft")
	assert_eq(SummaryScreen.heading_for(made, 7), "Fin del viaje", "the client drowned")
	assert_eq(SummaryScreen.heading_for(made, 9), "Fin del viaje", "a peer with no row")
	var died := RunSummary.new()
	died.entries = [_entry(1, true)] as Array[Dictionary]
	assert_eq(SummaryScreen.heading_for(died, 1), "Fin del viaje", "a solo death")

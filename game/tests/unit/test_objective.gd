extends GutTest
## hud-clarity, ui-shell "Objective row", "Objective while building the raft", "Objective at launch
## and at sea", "Objective waits for the dark" and "The objective keeps secrets", with exactly 1
## player, offline: a solo sandbar run through the game shell, every step in order, in Spanish and in
## English, and every line within the row's 27 glyphs.

const SHELL_SCENE: PackedScene = preload("res://scenes/shell/game_shell.tscn")
const COAST: StringName = &"coast_cay"
const ROW_GLYPHS: int = 27
## weather-daynight: 90 s after dawn is 09:00 (day, the patrol's light off) and 450 s is 21:00 (night).
const MORNING_S: float = 90.0
const NIGHT_S: float = 450.0

var settings_path: String = UserTmp.path("test_objective_settings.cfg")
var text: HudText = HudText.load_default()


func after_each() -> void:
	WeatherManager.stop()
	NetManager.leave()
	if FileAccess.file_exists(settings_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(settings_path))


func _shell(at_s: float = MORNING_S) -> GameShell:
	NetManager.start_solo()
	WeatherManager.stop()
	var shell := SHELL_SCENE.instantiate() as GameShell
	shell.settings_path = settings_path
	add_child_autofree(shell)
	(shell.screen as TitleScreen).solo_requested.emit()
	shell.session.body(1).player_input.enabled = false
	WeatherManager.sky.weather.rolls_enabled = false
	WeatherManager.sky.start_at(at_s)
	return shell


func _goal(shell: GameShell, locale: String = "es") -> Objective.Goal:
	return Objective.from(shell.session, CoopSession.HOST_ID, shell.island.layout, text, locale)


func _site(shell: GameShell) -> BuildSite:
	return shell.session.get_node_or_null(^"RaftSite") as BuildSite


func _bag(shell: GameShell) -> Inventory:
	return shell.session.body(CoopSession.HOST_ID).inventory


# Fills the raft site with every input and works it to `fraction` (1 builds the raft).
func _fill(site: BuildSite, fraction: float = 0.0) -> void:
	for id: StringName in site.recipe.inputs:
		site.deposited[id] = site.recipe.inputs[id]
	if fraction > 0.0:
		site.work(fraction)


func _boats(shell: GameShell) -> Array[Creature]:
	var found: Array[Creature] = []
	for node: Node in shell.session.entities.get_children():
		if node is Creature and (node as Creature).is_patrol():
			found.append(node as Creature)
	return found


func test_a_solo_players_first_frame() -> void:
	var shell := _shell()
	var goal := _goal(shell)
	assert_eq(goal.step, Objective.Step.GATHER)
	assert_eq(goal.line, "Arma la balsa: 0/6 madera")
	assert_eq(_goal(shell, "en").line, "Build the raft: 0/6 wood")


func test_counting_what_is_carried_and_what_is_in() -> void:
	var shell := _shell()
	_bag(shell).add(&"driftwood", 4)
	_site(shell).deposited[&"driftwood"] = 2
	assert_eq(_goal(shell).line, "Arma la balsa: 0/2 cámaras")
	_bag(shell).add(&"inner_tube", 2)
	assert_eq(_goal(shell).line, "Arma la balsa: 0/3 sogas")
	assert_eq(_goal(shell, "en").line, "Build the raft: 0/3 ropes")


func test_more_than_needed_counts_as_needed() -> void:
	var shell := _shell()
	_bag(shell).add(&"driftwood", 9)
	assert_eq(_goal(shell).line, "Arma la balsa: 0/2 cámaras", "9 driftwood cover the 6")


func test_everything_in_hand_then_building() -> void:
	var shell := _shell()
	_bag(shell).add(&"driftwood", 6)
	_bag(shell).add(&"inner_tube", 2)
	_bag(shell).add(&"rope", 3)
	assert_eq(_goal(shell).step, Objective.Step.DELIVER)
	assert_eq(_goal(shell).line, "Lleva to' pa' la balsa")
	assert_eq(_goal(shell, "en").line, "Take it all to the raft")
	var site := _site(shell)
	_fill(site, 0.4)
	assert_eq(_goal(shell).step, Objective.Step.WORK)
	assert_eq(_goal(shell).line, "Dale a la balsa: 40%")
	assert_eq(_goal(shell, "en").line, "Work the raft: 40%")


func test_built_by_day_with_a_boat_out_waits_for_the_dark() -> void:
	var shell := _shell(MORNING_S)
	await wait_process_frames(2)
	assert_gt(_boats(shell).size(), 0, "the sandbar's patrol boat is out")
	_fill(_site(shell), 1.0)
	await wait_process_frames(1)
	assert_not_null(shell.session.get_node_or_null(^"Raft"), "the raft is built")
	assert_true(Objective.launch_waits(shell.session))
	assert_eq(_goal(shell).step, Objective.Step.WAIT_DARK)
	assert_eq(_goal(shell).line, "Espera la noche pa' zarpar")
	assert_eq(_goal(shell, "en").line, "Wait for dark to set off")


func test_night_opens_the_window() -> void:
	var shell := _shell(MORNING_S)
	await wait_process_frames(2)
	_fill(_site(shell), 1.0)
	WeatherManager.sky.start_at(NIGHT_S)
	await wait_process_frames(1)
	assert_false(Objective.launch_waits(shell.session), "at night only the light sees")
	assert_eq(_goal(shell).step, Objective.Step.LAUNCH)
	assert_eq(_goal(shell).line, "Zarpa pa'l cayo")
	assert_eq(_goal(shell, "en").line, "Set off for the cay")


func test_a_squall_opens_the_window_by_day() -> void:
	var shell := _shell(MORNING_S)
	await wait_process_frames(2)
	_fill(_site(shell), 1.0)
	WeatherManager.sky.weather.start_weather(&"squall")
	WeatherManager.sky.advance(0.01)
	assert_true(shell.session.climate.weather_id == &"squall", "a squall falls")
	assert_eq(_goal(shell).line, "Zarpa pa'l cayo", "the patrol stays in port")


func test_no_boat_no_wait() -> void:
	var shell := _shell(MORNING_S)
	await wait_process_frames(2)
	for boat: Creature in _boats(shell):
		boat.get_parent().remove_child(boat)
		boat.free()
	_fill(_site(shell), 1.0)
	assert_eq(_goal(shell).line, "Zarpa pa'l cayo")


func test_at_sea() -> void:
	var shell := _shell(NIGHT_S)
	await wait_process_frames(2)
	var routes := shell.session.get_node(^"Routes") as IslandRoutes
	routes.departed[CoopSession.HOST_ID] = &"raft"
	assert_eq(_goal(shell).step, Objective.Step.AT_SEA)
	assert_eq(_goal(shell).line, "Aguanta hasta tierra")
	assert_eq(_goal(shell, "en").line, "Hold on till land")


func test_the_coast_cay_uses_the_default_line_at_night() -> void:
	var shell := _shell(NIGHT_S)
	shell.travel.travel(COAST)
	await wait_process_frames(3)
	assert_eq(shell.island.layout.id, COAST)
	var site := _site(shell)
	assert_not_null(site, "the coast cay has a raft site")
	if site == null:
		return
	_fill(site, 1.0)
	await wait_process_frames(1)
	WeatherManager.sky.start_at(NIGHT_S)
	assert_eq(_goal(shell).line, "Zarpa pa'l norte")
	assert_eq(_goal(shell, "en").line, "Set off north")


func test_a_bench_placed_build_site_is_ignored() -> void:
	var shell := _shell()
	var other := (load("res://scenes/structures/build_site.tscn") as PackedScene).instantiate() as BuildSite
	other.recipe = GameState.content.get_entry(&"recipes", &"fire") as RecipeData
	other.name = &"FireSite"
	shell.session.add_child(other)
	assert_eq(_goal(shell).line, "Arma la balsa: 0/6 madera", "only the level's raft site counts")


func test_no_raft_site_hides_the_goal() -> void:
	var shell := _shell()
	var site := _site(shell)
	shell.session.remove_child(site)
	site.free()
	assert_eq(_goal(shell).step, Objective.Step.NONE)
	assert_eq(_goal(shell).line, "")


# ui-shell "Objective row": every line, filled to its longest (each vessel build-site recipe's
# inputs at their real need, 100%), fits the row's 27 glyphs in both languages.
func test_every_line_fits_27_glyphs() -> void:
	var lines: Array[String] = []
	for locale: String in ["es", "en"]:
		for key: StringName in [&"deliver", &"wait_dark", &"launch_default", &"at_sea"]:
			lines.append(text.objective_line(key, locale))
		lines.append(text.objective_line(&"work", locale) % 100)
		for recipe: RecipeData in _vessel_site_recipes():
			for id: StringName in recipe.inputs:
				var item := GameState.content.get_entry(&"items", id) as ItemData
				lines.append(text.objective_line(&"gather", locale) % [recipe.inputs[id], recipe.inputs[id], item.count_name(locale)])
		for layout: IslandLayoutData in _layouts():
			lines.append(layout.launch_line(locale))
	assert_gt(lines.size(), 12)
	for line: String in lines:
		assert_lte(line.length(), ROW_GLYPHS, "\"%s\" fits" % line)


# ui-shell "The objective keeps secrets": on the hidden cay, carrying the map and the compass, the
# row counts driftwood and names nothing secret.
func test_nothing_secret() -> void:
	var shell := _shell()
	var cay := _secret_layout()
	assert_not_null(cay, "a secret island exists")
	_bag(shell).add(&"mapa_sin_norte", 1)
	_bag(shell).add(&"brujula_rota", 1)
	var goal := Objective.from(shell.session, CoopSession.HOST_ID, cay, text, "es")
	assert_eq(goal.line, "Arma la balsa: 0/6 madera")
	for word: String in [cay.name_es, "cofre", "mapa", "brújula", "cayo"]:
		assert_false(goal.line.to_lower().contains(word.to_lower()), "names no %s" % word)
	_fill(_site(shell), 1.0)
	WeatherManager.sky.start_at(NIGHT_S)
	var launch := Objective.from(shell.session, CoopSession.HOST_ID, cay, text, "es")
	assert_false(launch.line.to_lower().contains(cay.name_es.to_lower()), "the launch line names no secret island")


func _vessel_site_recipes() -> Array[RecipeData]:
	var found: Array[RecipeData] = []
	for id: StringName in GameState.content.list_ids(&"recipes"):
		var recipe := GameState.content.get_entry(&"recipes", id) as RecipeData
		if recipe.build_site and recipe.output_kind == RecipeData.OutputKind.VESSEL:
			found.append(recipe)
	return found


func _layouts() -> Array[IslandLayoutData]:
	var found: Array[IslandLayoutData] = []
	for id: StringName in GameState.content.list_ids(&"islands"):
		found.append(GameState.content.get_entry(&"islands", id) as IslandLayoutData)
	return found


func _secret_layout() -> IslandLayoutData:
	for layout: IslandLayoutData in _layouts():
		if layout.secret:
			return layout
	return null

class_name Objective
extends RefCounted
## hud-clarity, ui-shell "Objective row" and the requirements after it: the local player's current
## goal as one line. It reads only state every peer holds: the level's raft site or built raft by
## name (never another build site, nothing secret), the synced deposits and progress, the local
## body's synced inventory, whether the local player has left on a crossing, the climate and the
## patrol boats. Steps, in the order they are decided:
##   AT_SEA     the local player left: "Aguanta hasta tierra".
##   WAIT_DARK  the raft is built and a patrol boat would see the launch: "Espera la noche pa' zarpar".
##   LAUNCH     the raft is built: the island's launch line, else "Zarpa pa'l norte".
##   GATHER     the first input, in recipe order, the site and the bag still lack: "Arma la balsa: 0/6 madera".
##   DELIVER    everything is in hand: "Lleva to' pa' la balsa".
##   WORK       everything is in: "Dale a la balsa: 40%".
##   NONE       no raft site on this level: the row hides.

enum Step { NONE, AT_SEA, WAIT_DARK, LAUNCH, GATHER, DELIVER, WORK }

const RAFT_SITE_NAME: NodePath = ^"RaftSite"
const RAFT_NAME: NodePath = ^"Raft"


## A goal: its step and the line the row shows ("" for NONE).
class Goal:
	var step: Step = Step.NONE
	var line: String = ""

	func _init(goal_step: Step = Step.NONE, goal_line: String = "") -> void:
		step = goal_step
		line = goal_line


## The goal of `peer`'s player in `session`, on the island `layout` (null: no launch line), in `locale`.
static func from(session: CoopSession, peer: int, layout: IslandLayoutData, text: HudText, locale: String) -> Goal:
	if session == null or not is_instance_valid(session):
		return Goal.new()
	if session.has_left(peer):
		return Goal.new(Step.AT_SEA, text.objective_line(&"at_sea", locale))
	var site := session.get_node_or_null(RAFT_SITE_NAME) as BuildSite
	if session.get_node_or_null(RAFT_NAME) is Raft or (site != null and site.built):
		return launch(session, layout, text, locale)
	if site == null or site.recipe == null:
		return Goal.new()
	var body := session.body(peer)
	return for_site(site, body.inventory if body != null else null, text, locale)


## The goal while the raft is built: wait for the dark while a patrol boat would see the launch,
## else the island's launch line or the default one.
static func launch(session: CoopSession, layout: IslandLayoutData, text: HudText, locale: String) -> Goal:
	if launch_waits(session):
		return Goal.new(Step.WAIT_DARK, text.objective_line(&"wait_dark", locale))
	var line: String = layout.launch_line(locale) if layout != null else ""
	if line.is_empty():
		line = text.objective_line(&"launch_default", locale)
	return Goal.new(Step.LAUNCH, line)


## The goal while `site` is not built, counting what it holds and what `inventory` carries.
static func for_site(site: BuildSite, inventory: Inventory, text: HudText, locale: String) -> Goal:
	var recipe: RecipeData = site.recipe
	for id: StringName in recipe.inputs:
		var need: int = recipe.inputs[id]
		var carried: int = inventory.count_id(id) if inventory != null else 0
		var have: int = mini(site.deposited.get(id, 0) + carried, need)
		if have < need:
			return Goal.new(Step.GATHER, text.objective_line(&"gather", locale) % [have, need, _noun(id, locale)])
	for tag: DataEnums.ItemTag in recipe.input_tags:
		var need: int = recipe.input_tags[tag]
		var carried: int = inventory.count_tag(tag) if inventory != null else 0
		var have: int = mini(site.tags_deposited.get(tag, 0) + carried, need)
		if have < need:
			return Goal.new(Step.GATHER, text.objective_line(&"gather", locale) % [have, need, text.tag_name(tag, locale).to_lower()])
	if not site.inputs_complete():
		return Goal.new(Step.DELIVER, text.objective_line(&"deliver", locale))
	return Goal.new(Step.WORK, text.objective_line(&"work", locale) % floori(site.progress() * 100.0 + 0.000001))


## Whether a launch now would be seen (island-pressure's day rule, owner 2026-11-23): a patrol boat
## is out among the session's entities and the phase is one in which its searchlight is off, while
## the weather neither keeps patrols in port (a squall) nor blinds sight. island-pressure's
## LaunchSight.seen_by answers the same for the host; whichever change merges second makes this call it.
static func launch_waits(session: CoopSession) -> bool:
	var weather: WeatherData = _weather(session)
	if weather != null and (weather.patrols_in_port or weather.disabled_senses.has(DataEnums.Sense.SIGHT)):
		return false
	var phase: DataEnums.DayPhase = session.climate.phase
	for node: Node in session.entities.get_children():
		var boat := node as Creature
		if boat == null or boat.is_queued_for_deletion() or not boat.is_patrol():
			continue
		if not boat.data.patrol.searchlight_phases.has(phase):
			return true
	return false


# The weather falling now: the session's sky (the host's, which clients follow), else the climate's.
static func _weather(session: CoopSession) -> WeatherData:
	if session.sky != null and session.sky.weather != null and session.sky.weather.current != null:
		return session.sky.weather.current
	if session.climate.weather_id.is_empty():
		return null
	return GameState.content.get_entry(&"weather", session.climate.weather_id) as WeatherData


static func _noun(id: StringName, locale: String) -> String:
	var item := GameState.content.get_entry(&"items", id) as ItemData
	return item.count_name(locale) if item != null else ""

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


## Whether the launch must wait for the dark: island-pressure's LaunchSight sees a launch from the
## raft now, and the boat that sees it has its searchlight off in this phase (by day the guard watches
## the whole sea). The objective and the launch prompt's warning read the same rule, so they never
## disagree; a searchlight on the raft at night is the prompt's warning alone, never "wait for the dark".
static func launch_waits(session: CoopSession) -> bool:
	var boat: Creature = LaunchSight.seen_in(session, _launch_point(session))
	return boat != null and not boat.data.patrol.searchlight_phases.has(session.climate.phase)


# Where the raft launches from: the built raft, else the level's site.
static func _launch_point(session: CoopSession) -> Vector2:
	var raft := session.get_node_or_null(RAFT_NAME) as Node2D
	if raft != null:
		return raft.global_position
	var site := session.get_node_or_null(RAFT_SITE_NAME) as Node2D
	return site.global_position if site != null else Vector2.ZERO


static func _noun(id: StringName, locale: String) -> String:
	var item := GameState.content.get_entry(&"items", id) as ItemData
	return item.count_name(locale) if item != null else ""

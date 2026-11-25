class_name Raft
extends Node2D
## A built raft lying on the beach (escape-routes "Raft build site"; island-stop). Holding interact
## on it for 1 s launches the route named by its recipe id for whoever uses it: the host picks the
## riders. It stays until the route starts; the island then puts a fresh build site in its place.
##
## Its work point, on the land-side neighbour cell (island-stop "Raft jobs are shared"), opens the
## raft's list of mends and fittings on the local HUD; a chosen one becomes the raft's one job, a
## build site on the work point that anyone feeds and works. When it is done the host mends the
## raft or fits it; a launch ends it and gives the deposits back. The host decides the integrity,
## the maximum, the fittings and the job and sends them to every client, and a client asks for
## them as its raft appears (a joiner, or the raft a level site became), so every peer shows the
## same raft.

const LAUNCH_HOLD_S: float = 1.0
const WORK_POINT_NAME: StringName = &"WorkPoint"
const JOB_NAME: StringName = &"Job"
## Loaded when a job opens, not preloaded: the job's look reads the Raft class, so a preload here
## would load in a cycle.
const JOB_SCENE_PATH: String = "res://scenes/structures/raft_job.tscn"
const HOST_ID: int = 1
## The work point's side is the first of these with the most land around it, the same on every peer.
const SIDES: Array[Vector2i] = [Vector2i(0, 1), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, -1)]
## A raft takes at most this many fittings, whatever a forged message says.
const MAX_FITTINGS: int = 8

var climate: ClimateState = null
var recipe_id: StringName = &""
var integrity: float = 0.0
## The recipe's integrity plus the fittings' bonuses (island-stop "Raft maximum and fittings at sea").
var max_integrity: float = 0.0
## The recipe ids of the fittings on this raft, in the order they were done.
var fittings: Array[StringName] = []
## The mend or fitting being worked, or null.
var job: RaftJob = null

@onready var interactable: Interactable = $Interactable
@onready var work_point: Interactable = $WorkPoint


## Whether `recipe` is worked on a raft: a mend or a fitting.
static func is_job_recipe(recipe: RecipeData) -> bool:
	return recipe != null and (recipe.output_kind == RecipeData.OutputKind.VESSEL_REPAIR or recipe.output_kind == RecipeData.OutputKind.VESSEL_UPGRADE)


func _ready() -> void:
	interactable.hold_time_s = LAUNCH_HOLD_S
	interactable.interacted.connect(_on_interacted)
	work_point.hold_time_s = 0.0
	work_point.position = work_offset()
	# Drawing only: the fittings on the raft (island-stop).
	add_child(RaftFittingsLook.create())
	ask_for_state()


## Called by a BuildSite when the build completes, and by an island that beaches a raft.
func on_built(recipe: RecipeData) -> void:
	recipe_id = recipe.id
	integrity = recipe.vessel_integrity
	max_integrity = recipe.vessel_integrity
	set_meta(&"recipe_id", recipe_id)
	add_to_group(PlayerBody.STRUCTURE_GROUP)


## Where the work point stands from the raft's origin: one tile toward the neighbour cell that is
## land and has the most land round it (south, east, west, north on a tie), so it is on the raft's
## land side. It reads the session's terrain, the same on every peer.
func work_offset() -> Vector2:
	var session := CoopSession.of(self)
	var terrain: TerrainQuery = session.terrain if session != null else TerrainQuery.new()
	var cell := Vector2i((position / float(IslandLayout.TILE)).floor())
	var best: Vector2i = SIDES[0]
	var best_land: int = -1
	for side: Vector2i in SIDES:
		var next: Vector2i = cell + side
		if TerrainQuery.is_water(terrain.terrain_at(next)):
			continue
		var land: int = 0
		for dy: int in range(-1, 2):
			for dx: int in range(-1, 2):
				if not TerrainQuery.is_water(terrain.terrain_at(next + Vector2i(dx, dy))):
					land += 1
		if land > best_land:
			best = side
			best_land = land
	return Vector2(best * IslandLayout.TILE)


## Why the raft cannot take `recipe` now, or empty when it can: a job already open ("in_progress"),
## a mend at its maximum ("raft_whole"), a fitting it has ("raft_has_it"), anything else ("not_now").
func refusal(recipe: RecipeData) -> StringName:
	if not is_job_recipe(recipe):
		return &"not_now"
	if job != null:
		return &"in_progress"
	if recipe.output_kind == RecipeData.OutputKind.VESSEL_REPAIR and integrity >= max_integrity:
		return &"raft_whole"
	if recipe.output_kind == RecipeData.OutputKind.VESSEL_UPGRADE and fittings.has(recipe.id):
		return &"raft_has_it"
	return &""


## Host: `player` opens a job of `recipe` at the work point, which they must be in reach of. False,
## changing nothing, when the raft cannot take it (`refusal`) or the recipe is not one every player
## knows (an NPC teaches it), as the site placer refuses one.
func open_job_for(player: PlayerBody, recipe: RecipeData) -> bool:
	if not multiplayer.is_server() or player == null or not refusal(recipe).is_empty():
		return false
	if recipe.availability != RecipeData.Availability.KNOWN:
		return false
	if player.global_position.distance_to(work_point.global_position) > PlayerBody.HOLD_REACH_PX:
		return false
	_open_job(recipe.id)
	_push_state()
	return job != null


## Host: the job of `recipe` is done: a mend adds its integrity, a fitting raises the maximum and
## the integrity by its bonus and stays on the raft; the job goes and every client hears it.
func finish_job(recipe: RecipeData) -> void:
	if not multiplayer.is_server() or recipe == null:
		return
	if recipe.output_kind == RecipeData.OutputKind.VESSEL_UPGRADE and not fittings.has(recipe.id):
		fittings.append(recipe.id)
		max_integrity += recipe.integrity_delta
		integrity = minf(integrity + recipe.integrity_delta, max_integrity)
	elif recipe.output_kind == RecipeData.OutputKind.VESSEL_REPAIR:
		integrity = minf(integrity + recipe.integrity_delta, max_integrity)
	_close_job()
	_push_state()


## Host: this beached raft is the one a crossing left with `left_fittings` on it (crossing "Fittings
## ride with the raft"): it keeps them, its maximum is the recipe's plus their bonuses, and every
## client hears it.
func refit(left_fittings: Array[StringName]) -> void:
	if not multiplayer.is_server():
		return
	fittings = VesselFittings.checked(left_fittings, MAX_FITTINGS)
	var recipe := GameState.content.get_entry(&"recipes", recipe_id) as RecipeData
	var base: float = recipe.vessel_integrity if recipe != null else max_integrity
	max_integrity = base + VesselFittings.bonus(fittings)
	integrity = minf(integrity, max_integrity)
	_push_state()


## Host: the raft is launching, so an unfinished job ends: each deposit goes back to the player who
## made it, or lies on the raft's cell when they cannot carry it all (island-stop "A launch ends an
## unfinished job"). The work done is lost.
func end_job() -> void:
	if job == null:
		return
	if multiplayer.is_server():
		var session := CoopSession.of(self)
		for given: Dictionary in job.given():
			var player: Variant = given["body"]
			var id: StringName = given["id"]
			var count: int = given["count"]
			if is_instance_valid(player) and player is PlayerBody:
				count -= (player as PlayerBody).inventory.add(id, count)
			if count > 0 and session != null:
				session.spawn_pickup(id, count, position)
	_close_job()


## Clients: the host's integrity, maximum, fittings and open job. Anything not from the host, or
## not shaped like a raft's state, is dropped.
@rpc("authority", "call_remote", "reliable")
func receive_state(new_integrity: float, new_max: float, new_fittings: Array, job_id: StringName) -> void:
	if multiplayer.get_remote_sender_id() != HOST_ID or not is_finite(new_integrity) or not is_finite(new_max) or new_max <= 0.0:
		return
	max_integrity = new_max
	integrity = clampf(new_integrity, 0.0, new_max)
	fittings = VesselFittings.checked(new_fittings, MAX_FITTINGS)
	if job != null and (job_id.is_empty() or job.recipe.id != job_id):
		_close_job()
	if job == null and not job_id.is_empty():
		_open_job(job_id)


## Host: sends this raft's state to `peer` alone (the session checked the ask).
func send_state_to(peer: int) -> void:
	if multiplayer.is_server():
		receive_state.rpc_id(peer, integrity, max_integrity, fittings, _job_id())


## Client: asks the host for this raft's live state once connected.
func ask_for_state() -> void:
	if is_inside_tree() and not multiplayer.is_server() and _connected():
		_send_state_request.call_deferred()


func _send_state_request() -> void:
	var session := CoopSession.of(self)
	if session != null and is_inside_tree() and not multiplayer.is_server() and _connected():
		session.ask_site_state(self)


func _connected() -> bool:
	var peer := multiplayer.multiplayer_peer
	return peer != null and peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED


# Host: the current state to every client.
func _push_state() -> void:
	if is_inside_tree() and multiplayer.is_server() and not multiplayer.get_peers().is_empty():
		receive_state.rpc(integrity, max_integrity, fittings, _job_id())


func _job_id() -> StringName:
	return job.recipe.id if job != null and job.recipe != null else &""


# The job node, named the same on every peer, on the work point; the work point waits meanwhile.
func _open_job(id: StringName) -> void:
	var recipe := GameState.content.get_entry(&"recipes", id) as RecipeData
	if job != null or not is_job_recipe(recipe):
		return
	var made := (load(JOB_SCENE_PATH) as PackedScene).instantiate() as RaftJob
	made.name = JOB_NAME
	made.recipe = recipe
	made.climate = climate
	made.synced = true
	made.raft = self
	made.position = work_point.position
	add_child(made)
	job = made
	work_point.enabled = false


# Out of the tree at once, so the next job can take its name.
func _close_job() -> void:
	if job == null:
		return
	var old := job
	job = null
	remove_child(old)
	old.queue_free()
	work_point.enabled = true


func _on_interacted(by: Node) -> void:
	var routes := get_tree().get_first_node_in_group(IslandRoutes.GROUP) as IslandRoutes
	if routes != null and by is PlayerBody and multiplayer.is_server():
		routes.start_for(routes.peer_of(by as PlayerBody), recipe_id)

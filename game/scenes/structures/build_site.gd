class_name BuildSite
extends Node2D
## A shared build (crafting-inventory "Shared builds"): any player deposits the recipe's inputs
## from their own inventory, progress is shared, and work advances only once every input is in.
## One player can deposit everything and do all the work. A recipe with stages (island-pressure) is
## worked stage by stage: progress stays one shared value, the stage being worked is derived from it,
## and work stops at the end of the last stage whose inputs are in. When it completes it becomes the
## structure scene named by the recipe id (game/scenes/structures/<id>.tscn).
## A synced site (the level's raft site, or one placed at a bench) has the host push its item and
## tag deposits and its progress to every client, and a client asks for the live state when it is
## ready (a joiner gets only the spawn payload otherwise); a level site the host already built is
## answered as built, so a joiner's copy becomes its structure too. A site placed at a bench (`spawned`)
## becomes its structure through the session: the host spawns the structure once, on every peer,
## runs its build effects alone and frees the site; no peer builds it locally.

signal completed(structure: Node)

## Every build site joins it, so the HUD and the host can find the unfinished ones.
const GROUP: StringName = &"build_sites"
const STRUCTURE_PATH: String = "res://scenes/structures/%s.tscn"
## A synced site pushes its state to the clients each time progress moved this much (1/120 of
## the build; provisional).
const PUSH_EVERY: float = 1.0 / 120.0
## Progress this close to a stage's end counts as at it.
const STAGE_EPSILON: float = 0.000001

var recipe: RecipeData
var climate: ClimateState = null
var deposited: Dictionary[StringName, int] = {}
## Tag deposits, by ItemTag value.
var tags_deposited: Dictionary[int, int] = {}
## True once the site became its structure.
var built: bool = false
## Placed by a level on every peer at the same path: the host pushes its state to the clients.
var synced: bool = false
## Placed at a bench through the session's entity spawner: completion goes through the session.
var spawned: bool = false
## Name the finished structure takes (empty keeps the scene's own), so its path matches on every peer.
var structure_name: StringName = &""
var _progress: float = 0.0
var _pushed_progress: float = 0.0

@onready var interactable: Interactable = $Interactable


func _enter_tree() -> void:
	add_to_group(GROUP)


func _ready() -> void:
	interactable.hold_time_s = 0.0
	interactable.interacted.connect(_on_interacted)
	ask_for_state()


## The interact prompt names what is being built: the recipe.
func prompt_target(_by: Node, locale: String) -> String:
	return recipe.get_display_name(locale) if recipe != null else ""


## Moves matching inputs from the player's inventory into the site; returns the units moved.
func deposit(player: PlayerBody) -> int:
	var moved: int = 0
	for id: StringName in recipe.inputs:
		var take: int = mini(recipe.inputs[id] - deposited.get(id, 0), player.inventory.count_id(id))
		if take > 0 and player.inventory.remove_id(id, take):
			deposited[id] = deposited.get(id, 0) + take
			moved += take
	for tag: DataEnums.ItemTag in recipe.input_tags:
		var need: int = recipe.input_tags[tag] - tags_deposited.get(tag, 0)
		var taken: Array[StringName] = player.inventory.take_tag(tag, need)
		tags_deposited[tag] = tags_deposited.get(tag, 0) + taken.size()
		moved += taken.size()
	if moved > 0:
		_push_state()
	return moved


## The inputs still to be deposited, by item id, in the recipe's order.
func missing_items() -> Dictionary[StringName, int]:
	var missing: Dictionary[StringName, int] = {}
	for id: StringName in recipe.inputs:
		var short: int = recipe.inputs[id] - deposited.get(id, 0)
		if short > 0:
			missing[id] = short
	return missing


## The tags still to be deposited, by ItemTag value, in the recipe's order.
func missing_tags() -> Dictionary[int, int]:
	var missing: Dictionary[int, int] = {}
	for tag: DataEnums.ItemTag in recipe.input_tags:
		var short: int = recipe.input_tags[tag] - tags_deposited.get(tag, 0)
		if short > 0:
			missing[tag] = short
	return missing


func inputs_complete() -> bool:
	for id: StringName in recipe.inputs:
		if deposited.get(id, 0) < recipe.inputs[id]:
			return false
	for tag: DataEnums.ItemTag in recipe.input_tags:
		if tags_deposited.get(tag, 0) < recipe.input_tags[tag]:
			return false
	return true


## 0 to 1, the same for every player.
func progress() -> float:
	return _progress


## How many stages the recipe lists (crafting-inventory "Build stages"); 0 for a build without.
func stage_count() -> int:
	return recipe.stages.size() if recipe != null else 0


## The progress (0 to 1) at which stage `index` ends: the stage times so far over the whole time.
func stage_end(index: int) -> float:
	var count: int = stage_count()
	if count == 0 or index >= count - 1:
		return 1.0
	var total: float = 0.0
	var upto: float = 0.0
	for i: int in count:
		total += recipe.stages[i].time_s
		if i <= index:
			upto += recipe.stages[i].time_s
	return upto / total if total > 0.0 else 1.0


## The stage being worked, 0-based: the first whose end lies above the progress (the last once
## built). Derived from the shared progress, so every peer reads the same stage. 0 without stages.
func stage_index() -> int:
	var count: int = stage_count()
	for i: int in count:
		if stage_end(i) > _progress + STAGE_EPSILON:
			return i
	return maxi(count - 1, 0)


## How far the stage being worked is done, 0 to 1 (the whole build's progress without stages).
func stage_progress() -> float:
	if stage_count() == 0:
		return _progress
	var index: int = stage_index()
	var start: float = stage_end(index - 1) if index > 0 else 0.0
	var end: float = stage_end(index)
	return clampf((_progress - start) / (end - start), 0.0, 1.0) if end > start else 1.0


## What stage `index` (the one being worked, by default) still needs before it can be worked: its
## inputs and every earlier stage's, less what is deposited, in the recipe's input order. Without
## stages, the whole recipe's missing items.
func stage_missing_items(index: int = -1) -> Dictionary[StringName, int]:
	if stage_count() == 0:
		return missing_items()
	var upto: int = stage_index() if index < 0 else mini(index, stage_count() - 1)
	var needed: Dictionary[StringName, int] = {}
	for i: int in upto + 1:
		var stage: BuildStageData = recipe.stages[i]
		for id: StringName in stage.inputs:
			needed[id] = needed.get(id, 0) + stage.inputs[id]
	var missing: Dictionary[StringName, int] = {}
	for id: StringName in recipe.inputs:
		var short: int = needed.get(id, 0) - deposited.get(id, 0)
		if short > 0:
			missing[id] = short
	return missing


## The furthest the progress may go now: the end of the last stage whose inputs (and every earlier
## stage's) are in. Without stages, the whole build once every input is in, else where it stands.
func work_limit() -> float:
	if stage_count() == 0:
		return 1.0 if inputs_complete() else _progress
	var limit: float = 0.0
	for i: int in stage_count():
		if not stage_missing_items(i).is_empty():
			break
		limit = stage_end(i)
	return maxf(limit, _progress)


## How much of the build (0 to 1) can be worked before the limit.
func work_room() -> float:
	return 0.0 if built else maxf(work_limit() - _progress, 0.0)


## True when `player` cannot work this site for want of energy: its recipe costs energy and the
## player has none (inventory-hud "Sin fuerzas").
func needs_strength(player: PlayerBody) -> bool:
	return recipe != null and recipe.work_energy_per_s > 0.0 and player != null and player.meters.energy <= SurvivalMeters.EMPTY_EPSILON


## Adds `fraction` of the build, never past `work_limit()`. Does nothing (false) while the inputs
## of the stage being worked (every input, without stages) are not all in.
func work(fraction: float) -> bool:
	if built:
		return false
	var limit: float = work_limit()
	if _progress >= limit - STAGE_EPSILON:
		return false
	_progress = minf(_progress + fraction, limit)
	if _progress >= 1.0 - 0.000001:
		_complete()
	elif _progress >= limit - STAGE_EPSILON or _progress - _pushed_progress >= PUSH_EVERY:
		# At a stage's end the clients hear at once, so their prompt asks for the next stage's inputs.
		_push_state()
	return true


## Host: sends the state now (a held build's work just stopped), so every peer shows where it stopped.
func sync_now() -> void:
	if not built and _progress != _pushed_progress:
		_push_state()


## Clients: the host's item and tag deposits, progress and whether it is built, each clamped to
## the recipe. Anything not from the host or not shaped like a state is dropped. A spawned site
## built on the host is only marked built here: the host's spawner brings the structure.
@rpc("authority", "call_remote", "reliable")
func receive_state(deposits: Dictionary, tag_deposits: Dictionary, progress: float, is_built: bool) -> void:
	if multiplayer.get_remote_sender_id() != 1 or not synced or built or not is_finite(progress):
		return
	for id: StringName in recipe.inputs:
		var amount: Variant = deposits.get(id, 0)
		deposited[id] = clampi(amount if amount is int else 0, 0, recipe.inputs[id])
	for tag: DataEnums.ItemTag in recipe.input_tags:
		var tag_amount: Variant = tag_deposits.get(tag, 0)
		tags_deposited[tag] = clampi(tag_amount if tag_amount is int else 0, 0, recipe.input_tags[tag])
	_progress = clampf(progress, 0.0, 1.0)
	if is_built:
		if spawned:
			_mark_built()
		else:
			_complete()


## Client: asks the host for this synced site's live state, once connected (the session asks again
## when the host's world state arrives, which covers a site made before the connection). The ask
## goes through the session, which is there on the host even when this site no longer is.
func ask_for_state() -> void:
	if synced and is_inside_tree() and not multiplayer.is_server() and _connected():
		_send_state_request.call_deferred()


## Host: sends this synced site's state to `peer` alone (the session checked the ask).
func send_state_to(peer: int) -> void:
	if synced and multiplayer.is_server():
		receive_state.rpc_id(peer, deposited, tags_deposited, _progress, built)


## Client: the host built this level site before this peer asked (`CoopSession.receive_site_built`),
## so it becomes its structure here too. A site placed at a bench never does: the spawner brings it.
func complete_from_host() -> void:
	if synced and not spawned and not built and not multiplayer.is_server():
		_complete()


# Deferred, so a request made as the connection opens follows the session's join request.
func _send_state_request() -> void:
	var session := CoopSession.of(self)
	if session != null and is_inside_tree() and not multiplayer.is_server() and _connected():
		session.ask_site_state(self)


func _connected() -> bool:
	var peer := multiplayer.multiplayer_peer
	return peer != null and peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED


# Host: sends the current state to every client (a synced site only).
func _push_state() -> void:
	_pushed_progress = _progress
	if synced and is_inside_tree() and multiplayer.is_server() and not multiplayer.get_peers().is_empty():
		receive_state.rpc(deposited, tags_deposited, _progress, built)


func _on_interacted(by: Node) -> void:
	var player := by as PlayerBody
	if player == null:
		return
	deposit(player)
	player.crafter.start_work(self)


func _complete() -> void:
	if spawned:
		_complete_spawned()
		return
	_mark_built()
	_push_state()
	var session := CoopSession.of(self)
	if session != null and synced:
		session.record_site_built(self)
	var scene := load(STRUCTURE_PATH % recipe.id) as PackedScene
	var structure: Node = scene.instantiate() if scene != null else null
	if structure != null:
		if structure is Node2D:
			(structure as Node2D).position = position
		structure.set("climate", climate)
		if not structure_name.is_empty():
			structure.name = structure_name
		get_parent().add_child(structure)
		if structure.has_method(&"on_built"):
			structure.call(&"on_built", recipe)
	completed.emit(structure)
	# Out of the tree at once, so the structure and any later site can take this name.
	get_parent().remove_child(self)
	queue_free()


# A site placed at a bench: marked built everywhere, and on the host the session spawns the
# structure once, on every peer, with its build effects here alone; the site then goes, and the
# spawner removes it on every client.
func _complete_spawned() -> void:
	_mark_built()
	_push_state()
	if not multiplayer.is_server():
		return
	var session := CoopSession.of(self)
	var structure: Node2D = session.spawn_structure(recipe, session.to_local(global_position)) if session != null else null
	completed.emit(structure)
	queue_free()


func _mark_built() -> void:
	built = true
	interactable.enabled = false

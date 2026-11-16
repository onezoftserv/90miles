class_name CaptureScene
extends Node
## guardacostas-capture design.md §2, §7 and §9: the session's capture keeper and the runner of
## `la_captura`. A child named CaptureScene of every CoopSession (added in its _ready, kept across a
## travel), so its RPCs reach the same node on every peer.
## - Host: after every capture, death, removal, drop and downed change it asks CaptureRules whether the
##   whole party is caught. If so, CaptureOutcome routes it: on an island (or a crossing that is not
##   the final one) the scene plays; in the final crossing the run ends with `devuelto` instead, which
##   this change only signals (`run_devuelto`).
## - Host: a squad that rows out with captives while someone is free takes them (CaptureRules.take).
## - The scene: every player is held out of play. The host resolves the scene's states (open, act,
##   plea, outcome) from the DialogueData, each state's highest-priority entry whose conditions hold
##   for the scene's party, sends every line to every peer in order, holds each for its reveal time
##   (40 chars/s) plus 2 s, then frees the party, stands a downed player at 30 health and applies the
##   outcome's effects (the flags, the fire sources, the release or the restart).
## - Every peer: `current_*` hold the line the scene panel draws; a joiner is sent it on arrival.

## Host: a whole-party capture in the final crossing (the final-crossing work connects the ending).
signal run_devuelto
## Every peer: the scene began (everyone is out of play) or ended.
signal scene_started
signal scene_ended
## Every peer: a new line is current.
signal line_changed

const NODE_NAME: StringName = &"CaptureScene"
const DEFAULT_SCENE_ID: StringName = &"beat_la_captura"
const REVEAL_CHARS_PER_S: float = 40.0
const LINE_HOLD_S: float = 2.0
## The speaker id of a line a player says (the plea).
const PLAYER_SPEAKER: StringName = &"player"
const START_STATE: StringName = &"open"
## A sanity bound on a host message.
const MAX_LINES: int = 64

## Every peer: true while the scene plays (from the host's begin and end calls).
var playing: bool = false
## Every peer: the current line: its serial (1 for the first), the dialogue file, the line's id, its
## speaker id and, for a player's line, the speaking peer.
var current_serial: int = 0
var current_scene_id: StringName = &""
var current_line_id: StringName = &""
var current_speaker_id: StringName = &""
var current_speaker_peer: int = 0
## Host: the final-crossing seam, `func() -> bool`; false until the final crossing exists.
var in_final_crossing: Callable = Callable()

var _session: CoopSession = null
var _scene_id: StringName = DEFAULT_SCENE_ID
var _lines: Array[Dictionary] = []
var _index: int = -1
var _left_s: float = 0.0
var _outcome: DialogueStateData = null
var _party: Array[PlayerBody] = []
var _check_queued: bool = false


## The keeper of the session `node` belongs to, or null.
static func of(node: Node) -> CaptureScene:
	var session := CoopSession.of(node)
	if session == null:
		return null
	return session.get_node_or_null(NodePath(NODE_NAME)) as CaptureScene


func _ready() -> void:
	_session = CoopSession.of(self)
	if _session == null:
		return
	_session.player_spawned.connect(_watch_body)
	_session.removal_recorded.connect(func(_peer: int, _name: String) -> void: queue_check())
	_session.player_disconnected.connect(func(_peer: int) -> void: queue_check())
	_session.join_state_sent.connect(_tell_joiner)


## Whether the island's travel must wait: the scene plays, or (on the host) the whole party is caught
## and the scene is about to begin. IslandTravel.check asks first.
func holds_travel() -> bool:
	if playing:
		return true
	if not _is_host():
		return false
	if CaptureRules.is_whole_party(CaptureRules.members_of(_session)):
		queue_check()
		return true
	return false


## Host: check for a whole-party capture after this frame (never from inside the signal that asked).
func queue_check() -> void:
	if not _is_host() or _check_queued:
		return
	_check_queued = true
	_check.call_deferred()


## Host, from a patrol boat: `body` was captured by `boat` (its squad or a haul).
func on_captured(body: PlayerBody, boat: Creature) -> void:
	if boat != null and boat.data != null and boat.data.patrol != null and not boat.data.patrol.capture_dialogue_id.is_empty():
		_scene_id = boat.data.patrol.capture_dialogue_id
	queue_check()


## Host, from a patrol boat: its squad rowed out (or the boat left sight) with `captives`, whose secret
## items go on `landing_px` (session coordinates). While someone is free they are taken; otherwise the
## whole-party capture plays with them.
func on_rowed_out(captives: Array[PlayerBody], landing_px: Vector2) -> void:
	if not _is_host() or playing:
		return
	var members := CaptureRules.members_of(_session)
	if CaptureRules.taken_on_leaving(captives.size(), members) > 0:
		for body: PlayerBody in captives:
			if is_instance_valid(body) and body.captive:
				CaptureRules.take(_session, body, landing_px)
				take_out_of_play.rpc(_session.peer_of(body))
	_session.capture_state_changed.emit()
	queue_check()


func _check() -> void:
	_check_queued = false
	if not _is_host() or playing or not is_inside_tree():
		return
	if not CaptureRules.is_whole_party(CaptureRules.members_of(_session)):
		return
	var final: bool = in_final_crossing.is_valid() and in_final_crossing.call()
	match CaptureOutcome.resolve(final):
		CaptureOutcome.Route.DEVUELTO:
			run_devuelto.emit()
		CaptureOutcome.Route.SCENE:
			_begin()


# --- the scene (host) ------------------------------------------------------------------------------

func _begin() -> void:
	_party = _scene_party()
	var scene := GameState.content.get_entry(&"dialogue", _scene_id) as DialogueData
	if scene == null or _party.is_empty():
		return
	_lines = _resolve(scene)
	_index = -1
	begin_scene.rpc()
	_next_line()


## Host: skip the current line (in solo, the player).
func skip() -> void:
	if _is_host() and playing:
		_next_line()


func _physics_process(delta: float) -> void:
	if not playing or not _is_host() or _index < 0:
		return
	_left_s -= delta
	if _left_s <= 0.0:
		_next_line()


func _next_line() -> void:
	_index += 1
	if _index >= _lines.size():
		_finish()
		return
	var line: Dictionary = _lines[_index]
	_left_s = hold_s(String(line["text"]))
	show_line.rpc(_index + 1, String(_scene_id), String(line["id"]), String(line["speaker"]), int(line["peer"]))


## Seconds a line of `text` stays: its reveal at 40 chars/s, plus 2 s.
static func hold_s(text: String) -> float:
	return float(text.length()) / REVEAL_CHARS_PER_S + LINE_HOLD_S


# The scene ends: the party is free and in play again, a downed player stands at 30 health, and the
# outcome's effects run (the flags, the fire sources, then the release or the restart).
func _finish() -> void:
	var outcome := _outcome
	var party := _party.duplicate()
	end_scene.rpc()
	for body: PlayerBody in party:
		if not is_instance_valid(body):
			continue
		body.set_captive(false)
		body.taken = false
		var peer: int = _session.peer_of(body)
		if body.meters.downed and not body.meters.dead and not _session.is_dropped(peer):
			body.meters.revive()
	if outcome == null:
		return
	var actor: PlayerBody = party[0] if not party.is_empty() else null
	for effect: EffectData in outcome.on_enter_effects:
		if actor != null:
			EffectApplier.apply(effect, actor, actor)


# Every player of the run in peer order but the dead: the captive, the taken, the downed and the
# dropped all go with the party (owner decision 9).
func _scene_party() -> Array[PlayerBody]:
	var party: Array[PlayerBody] = []
	for peer_id: int in _session.peer_ids():
		var body := _session.body(peer_id)
		if body != null and not body.meters.dead:
			party.append(body)
	return party


# The scene's lines in order: each state's highest-priority entry whose conditions hold for the party,
# its lines filtered by their own conditions; the plea's speaker is the standing player who passes it,
# the higher morale first, then peer order. Remembers the outcome entry for its effects.
func _resolve(scene: DialogueData) -> Array[Dictionary]:
	var lines: Array[Dictionary] = []
	_outcome = null
	var actor: PlayerBody = _party[0]
	var state: StringName = START_STATE
	var guard: int = 0
	while not state.is_empty() and guard < 8:
		guard += 1
		var entry := _entry(scene, state, actor)
		if entry == null:
			break
		var speaker_peer: int = 0
		var speaker := _speaker(entry)
		if speaker != null:
			speaker_peer = _session.peer_of(speaker)
		for line: DialogueLineData in entry.lines:
			if not ConditionCheck.all_hold(line.conditions, actor, _party):
				continue
			var speaker_id: StringName = line.speaker_id if not line.speaker_id.is_empty() else scene.npc_id
			lines.append({"id": line.id, "speaker": speaker_id, "peer": speaker_peer if speaker_id == PLAYER_SPEAKER else 0, "text": line.text_es})
			if lines.size() >= MAX_LINES:
				return lines
		if entry.next_state.is_empty():
			_outcome = entry
		state = entry.next_state
	return lines


func _entry(scene: DialogueData, state: StringName, actor: PlayerBody) -> DialogueStateData:
	var best: DialogueStateData = null
	for entry: DialogueStateData in scene.states:
		if entry.state != state or not ConditionCheck.all_hold(entry.conditions, actor, _party):
			continue
		if best == null or entry.priority > best.priority:
			best = entry
	return best


# The standing player who passes the entry's ANY_PLAYER condition (the plea's speaker), or null.
func _speaker(entry: DialogueStateData) -> PlayerBody:
	for condition: ConditionData in entry.conditions:
		if condition.scope != ConditionData.Scope.ANY_PLAYER:
			continue
		return pick_speaker(ConditionCheck.passing_players(condition, _party))
	return null


## Who of `passing` (in join order) speaks: the higher morale, then the earlier join; null for none.
static func pick_speaker(passing: Array[PlayerBody]) -> PlayerBody:
	if passing.is_empty():
		return null
	var best: PlayerBody = passing[0]
	for player: PlayerBody in passing:
		if player.meters.morale > best.meters.morale:
			best = player
	return best


# --- every peer ------------------------------------------------------------------------------------

## Every peer, from the host: the scene begins; every player is held out of play.
@rpc("authority", "call_local", "reliable")
func begin_scene() -> void:
	if not _from_host():
		return
	playing = true
	for peer_id: int in _session.peer_ids():
		var body := _session.body(peer_id)
		if body != null and not body.meters.dead:
			IslandArrival.hold(body)
	scene_started.emit()


## Every peer, from the host: line number `serial` of `scene_id` is `line_id`, said by `speaker_id`
## (`speaker_peer`'s player for a player's line).
@rpc("authority", "call_local", "reliable")
func show_line(serial: int, scene_id: String, line_id: String, speaker_id: String, speaker_peer: int) -> void:
	if not _from_host() or serial < 1 or serial > MAX_LINES:
		return
	playing = true
	current_serial = serial
	current_scene_id = StringName(scene_id)
	current_line_id = StringName(line_id)
	current_speaker_id = StringName(speaker_id)
	current_speaker_peer = speaker_peer
	line_changed.emit()


## Every peer, from the host: the scene ended (the travel that follows lands everyone).
@rpc("authority", "call_local", "reliable")
func end_scene() -> void:
	if not _from_host():
		return
	playing = false
	current_serial = 0
	current_line_id = &""
	scene_ended.emit()


## Every peer, from the host: `peer_id`'s player was taken; it waits out of play here too.
@rpc("authority", "call_remote", "reliable")
func take_out_of_play(peer_id: int) -> void:
	if not _from_host():
		return
	var body := _session.body(peer_id)
	if body != null:
		body.taken = true
		IslandArrival.hold(body)


## The current line's text in `locale`, and its speaker's name (the NPC's, or the player's).
func current_text(locale: String) -> String:
	var line := _line(current_scene_id, current_line_id)
	if line == null:
		return ""
	return line.text_en if locale == "en" and not line.text_en.is_empty() else line.text_es


func current_speaker_name(locale: String) -> String:
	if current_speaker_id == PLAYER_SPEAKER:
		return _session.player_name(current_speaker_peer) if _session != null else ""
	var npc := GameState.content.get_entry(&"npcs", current_speaker_id)
	return npc.get_display_name(locale) if npc != null else String(current_speaker_id)


static func _line(scene_id: StringName, line_id: StringName) -> DialogueLineData:
	var scene := GameState.content.get_entry(&"dialogue", scene_id) as DialogueData
	if scene == null:
		return null
	for entry: DialogueStateData in scene.states:
		for line: DialogueLineData in entry.lines:
			if line.id == line_id:
				return line
	return null


# Host: a joiner (or a rejoined player) arriving during the scene is held and sees its current line.
func _tell_joiner(peer_id: int) -> void:
	if not _is_host() or not playing:
		return
	begin_scene.rpc_id(peer_id)
	show_line.rpc_id(peer_id, current_serial, String(current_scene_id), String(current_line_id), String(current_speaker_id), current_speaker_peer)


func _watch_body(_peer_id: int, body: PlayerBody) -> void:
	if playing and _is_host():
		IslandArrival.hold(body)
		if not _party.has(body):
			_party.append(body)
	body.meters.died.connect(queue_check)
	body.meters.downed_changed.connect(func(_value: bool) -> void: queue_check())
	body.meters.last_stand_changed.connect(func(_value: bool) -> void: queue_check())


func _is_host() -> bool:
	return _session != null and is_inside_tree() and multiplayer.is_server()


func _from_host() -> bool:
	var sender: int = multiplayer.get_remote_sender_id()
	return sender == CoopSession.HOST_ID or (sender == 0 and multiplayer.is_server())

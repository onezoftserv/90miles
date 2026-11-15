class_name Chest
extends Node2D
## The secret cay's empty chest (secret-cay "Empty chest", "Same chest for everyone"; design.md
## decision 7). The level builds it on every peer under the fixed name `Chest`, so the host's call
## reaches the same path everywhere. Holding interact for the tuning's chest hold opens it, once:
## the host picks one entry of the note by weight, lays the note beside the chest as a pick-up and
## tells every peer which entry it was; each peer whose player is in the run shows that entry on
## its note label. A peer whose player joins later, or takes back its body, gets the open state
## with no label. It has no health and no theft or fire hook: it cannot be broken, burned, moved
## or looted, and the hat is never inside it.

## The chest opened on this peer, with the note's entry `entry_id`.
signal opened_with(entry_id: StringName)

const NAME: StringName = &"Chest"
const INTERACTABLE_NAME: StringName = &"Interactable"
const PROMPT_ID: StringName = &"open_chest"
const HOST_ID: int = 1
## Placeholder until the chest's art: a dark lid on a wooden box, and an open box once opened.
const WOOD: Color = Color("#8f563b")
const LID: Color = Color("#663931")
const INSIDE: Color = Color("#222034")
const BOX: Rect2 = Rect2(-6.0, -6.0, 12.0, 8.0)

## The note's item id, laid beside the chest when it opens (the layout's chest_item_id).
var note_id: StringName = &""
var tuning: SecretTuning = SecretTuning.standard()
## Open, on this peer.
var opened: bool = false
## The note entry picked when it opened, or empty.
var entry_id: StringName = &""
var interactable: Interactable = Interactable.new()
## Host: picks the note's entry (seeded by tests).
var rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _init() -> void:
	name = NAME
	interactable.name = INTERACTABLE_NAME
	interactable.prompt_id = PROMPT_ID
	interactable.hides_contents = true
	add_child(interactable)


func _ready() -> void:
	interactable.hold_time_s = tuning.chest_hold_s
	interactable.interacted.connect(_on_interacted)
	var session := CoopSession.of(self)
	if session != null:
		session.player_spawned.connect(_on_player_joined)
		session.player_rebound.connect(func(_old: int, new_peer: int, _body: PlayerBody) -> void: _on_player_joined(new_peer, null))


## The note's entry `id`, or null.
func entry(id: StringName) -> TextEntryData:
	var note := GameState.content.get_entry(&"items", note_id) as TextData
	if note == null:
		return null
	for candidate: TextEntryData in note.entries:
		if candidate.id == id:
			return candidate
	return null


# Host: the first completed hold opens it; later ones change nothing.
func _on_interacted(by: Node) -> void:
	if opened or not multiplayer.is_server() or not by is PlayerBody:
		return
	var picked: StringName = _pick_entry()
	var session := CoopSession.of(self)
	if session != null and not note_id.is_empty():
		session.spawn_pickup(note_id, 1, position + Vector2(0.0, IslandLayout.TILE))
	receive_state.rpc(true, picked, true)


## Every peer: the host says the chest is open with entry `picked`. `live`: it opened just now, so
## the note shows on this peer's label; a late joiner gets it with `live` false.
@rpc("authority", "call_local", "reliable")
func receive_state(is_open: bool, picked: StringName, live: bool) -> void:
	var sender: int = multiplayer.get_remote_sender_id()
	if sender != HOST_ID and not (sender == 0 and multiplayer.is_server()):
		return
	if not is_open or opened:
		return
	opened = true
	entry_id = picked
	interactable.enabled = false
	queue_redraw()
	opened_with.emit(picked)
	var chosen := entry(picked)
	if live and chosen != null:
		NoteLabel.show_in(CoopSession.of(self), chosen.body_es, chosen.body_en)


func _draw() -> void:
	draw_rect(BOX, WOOD)
	if opened:
		draw_rect(Rect2(BOX.position + Vector2(2.0, 1.0), Vector2(BOX.size.x - 4.0, 3.0)), INSIDE)
	else:
		draw_rect(Rect2(BOX.position, Vector2(BOX.size.x, 3.0)), LID)


# Host: one entry of the note by weight (RANDOM_ONE).
func _pick_entry() -> StringName:
	var note := GameState.content.get_entry(&"items", note_id) as TextData
	if note == null or note.entries.is_empty():
		return &""
	var total: float = 0.0
	for candidate: TextEntryData in note.entries:
		total += maxf(candidate.weight, 0.0)
	var roll: float = rng.randf() * total
	for candidate: TextEntryData in note.entries:
		roll -= maxf(candidate.weight, 0.0)
		if roll < 0.0:
			return candidate.id
	return note.entries[note.entries.size() - 1].id


# Host: a player who joins, or takes back its body, after the opening sees the chest open.
func _on_player_joined(peer_id: int, _body: PlayerBody) -> void:
	if opened and multiplayer.is_server() and peer_id != HOST_ID and multiplayer.get_peers().has(peer_id):
		receive_state.rpc_id(peer_id, true, entry_id, false)

class_name SecretHunt
extends Node
## The dev hunt (secret-cay "Spot pick", "Map hint"; design.md decisions 3 and 8): on the host it
## places the two pieces the tuning names on hiding spots of the island, picked from a seed (the
## map first, then the compass from the rest), and remembers the kind of spot where the compass
## lies. When anyone takes the map, the host tells every peer to show the map's text with that
## kind's hint in its landmark slot, each peer in its own language, on its note label. It sits in
## the session at a fixed name on every peer, so the host's call reaches each copy. A solo player
## is their own host. In real runs the pieces wait for island-generation (design.md "Later").

## A piece was placed on the host: `item_id` at `cell`.
signal piece_placed(item_id: StringName, cell: Vector2i)
## The host saw `item_id` taken `seconds` after it was placed (the dev scene's finding log).
signal piece_found(item_id: StringName, seconds: float)

const NAME: StringName = &"SecretHunt"
const HOST_ID: int = 1
const SLOT: String = "{pista}"

var tuning: SecretTuning = SecretTuning.standard()
var session: CoopSession = null
var island: SandbarIsland = null
## Host: where each piece was placed, by item id.
var cells: Dictionary[StringName, Vector2i] = {}
## Host: the kind of spot where the compass lies (the map's hint).
var compass_kind: StringName = &""
## Host: the pieces lying on the island, by item id (null once taken).
var pieces: Dictionary[StringName, WorldItem] = {}
## Clock for the finding log; tests may replace it.
var clock: Callable = func() -> float: return Time.get_ticks_msec() / 1000.0

var _placed_s: Dictionary[StringName, float] = {}


func _init() -> void:
	name = NAME


## The map's and the compass's cells for `hunt_seed` on `built`: two different hiding spots, the map's
## drawn first. Empty when the island has fewer than two spots.
static func pick_cells(built: IslandLayout, hunt_tuning: SecretTuning, hunt_seed: int) -> Array[Vector2i]:
	var spots: Array[Vector2i] = built.hiding_spots(hunt_tuning)
	if spots.size() < 2:
		return [] as Array[Vector2i]
	var rng := RandomNumberGenerator.new()
	rng.seed = hunt_seed
	var map_cell: Vector2i = spots.pop_at(rng.randi_range(0, spots.size() - 1))
	var compass_cell: Vector2i = spots[rng.randi_range(0, spots.size() - 1)]
	return [map_cell, compass_cell] as Array[Vector2i]


## The map's description in `locale` with the hint for `kind` in its landmark slot.
static func map_text(hunt_tuning: SecretTuning, kind: StringName, locale: String) -> String:
	var map := GameState.content.get_entry(&"items", hunt_tuning.map_item_id) as ItemData
	if map == null:
		return ""
	var english: bool = locale.begins_with("en")
	var text: String = map.description_en if english and not map.description_en.is_empty() else map.description_es
	return text.replace(SLOT, hunt_tuning.hint_for(kind, "en" if english else "es"))


## Every peer: follows `run_session` on `run_island`.
func setup(run_session: CoopSession, run_island: SandbarIsland) -> void:
	session = run_session
	island = run_island


## Host: places both pieces on the hiding spots `hunt_seed` picks. Returns whether it placed them.
func place_from_seed(hunt_seed: int) -> bool:
	var picked: Array[Vector2i] = pick_cells(island.built, tuning, hunt_seed)
	if picked.size() < 2:
		return false
	return place_pieces(picked[0], picked[1])


## Host: lays the map on `map_cell` and the compass on `compass_cell`.
func place_pieces(map_cell: Vector2i, compass_cell: Vector2i) -> bool:
	if session == null or not session.multiplayer.is_server():
		return false
	compass_kind = island.built.spot_kind(compass_cell, tuning)
	_place(tuning.map_item_id, map_cell)
	_place(tuning.compass_item_id, compass_cell)
	return true


## Every peer: the host says the map was taken; show its text with the hint for `kind`.
@rpc("authority", "call_local", "reliable")
func show_map_text(kind: StringName) -> void:
	var sender: int = multiplayer.get_remote_sender_id()
	if sender != HOST_ID and not (sender == 0 and multiplayer.is_server()):
		return
	NoteLabel.show_in(session, map_text(tuning, kind, "es"), map_text(tuning, kind, "en"))


func _place(item_id: StringName, cell: Vector2i) -> void:
	var lying: WorldItem = session.spawn_pickup(item_id, 1, IslandLayout.cell_center(cell))
	cells[item_id] = cell
	pieces[item_id] = lying
	_placed_s[item_id] = clock.call()
	if lying != null:
		lying.taken.connect(_on_taken)
	piece_placed.emit(item_id, cell)


func _on_taken(_by: PlayerBody, item_id: StringName) -> void:
	pieces[item_id] = null
	piece_found.emit(item_id, clock.call() - _placed_s.get(item_id, clock.call()))
	if item_id == tuning.map_item_id:
		show_map_text.rpc(compass_kind)

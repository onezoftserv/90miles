class_name CrossingLeaks
extends RefCounted
## The crossing's open leaks (crossing "Leaks"; design.md D5): debris that hits a vessel opens one on
## the half of its deck nearer the debris, each drains integrity until a rider aboard plugs it, and a
## vessel holds at most a few. Pure logic over plain values: each leak is {id, vessel, x, y}, where
## `vessel` is 0 for the shared deck or the board's rider, and (x, y) is its spot in tiles from that
## deck's centre. The host opens, drains and plugs; clients hold what the host sent.

## Spots in tiles from a shared deck's centre, west half first (the east half mirrors them).
const DECK_SPOTS: Array[Vector2] = [Vector2(-1.5, -0.5), Vector2(-0.5, 0.5), Vector2(-1.5, 0.5), Vector2(-0.5, -0.5)]
## Spots on a 1x2 board.
const BOARD_SPOTS: Array[Vector2] = [Vector2(0.0, -0.5), Vector2(0.0, 0.5), Vector2(0.0, 0.0)]

var list: Array[Dictionary] = []
var _next_id: int = 1


## Host: opens a leak on `vessel` (0 shared, else the board's rider), on its east half when `east`.
## Returns the new leak's id, or 0 when that vessel already holds `max_leaks`.
func open(vessel: int, east: bool, max_leaks: int) -> int:
	var count: int = 0
	var taken: Array[Vector2] = []
	for leak: Dictionary in list:
		if leak["vessel"] == vessel:
			count += 1
			taken.append(Vector2(leak["x"], leak["y"]))
	if count >= max_leaks:
		return 0
	var spots: Array[Vector2] = BOARD_SPOTS if vessel != 0 else DECK_SPOTS
	var spot: Vector2 = Vector2.ZERO
	var found: bool = false
	for candidate: Vector2 in spots:
		var placed := Vector2(-candidate.x if east and vessel == 0 else candidate.x, candidate.y)
		if not taken.has(placed):
			spot = placed
			found = true
			break
	if not found:
		spot = Vector2(0.0, 0.0)
	var id: int = _next_id
	_next_id += 1
	list.append({"id": id, "vessel": vessel, "x": spot.x, "y": spot.y})
	return id


## Host: closes leak `id`; false if it is not open.
func plug(id: int) -> bool:
	for index: int in list.size():
		if list[index]["id"] == id:
			list.remove_at(index)
			return true
	return false


## The open leaks on `vessel`.
func count_on(vessel: int) -> int:
	var count: int = 0
	for leak: Dictionary in list:
		if leak["vessel"] == vessel:
			count += 1
	return count


## The leak with `id`, or an empty dictionary.
func get_leak(id: int) -> Dictionary:
	for leak: Dictionary in list:
		if leak["id"] == id:
			return leak
	return {}


## Every leak on `vessel` goes (it sank).
func clear_vessel(vessel: int) -> void:
	var kept: Array[Dictionary] = []
	for leak: Dictionary in list:
		if leak["vessel"] != vessel:
			kept.append(leak)
	list = kept


## The leak list a rejoined board rider's board keeps.
func rename_vessel(old_peer: int, new_peer: int) -> void:
	for leak: Dictionary in list:
		if leak["vessel"] == old_peer:
			leak["vessel"] = new_peer


## Plain values for the wire: [[id, vessel, x, y], ...].
func to_array() -> Array:
	var rows: Array = []
	for leak: Dictionary in list:
		rows.append([leak["id"], leak["vessel"], leak["x"], leak["y"]])
	return rows


## Takes the host's list; false (and unchanged) for anything malformed or with more than
## `max_rows` leaks.
func read(data: Variant, max_rows: int) -> bool:
	if not data is Array or (data as Array).size() > max_rows:
		return false
	var rows: Array[Dictionary] = []
	for raw: Variant in data:
		if not raw is Array or (raw as Array).size() != 4:
			return false
		var row: Array = raw
		if not row[0] is int or not row[1] is int:
			return false
		for index: int in [2, 3]:
			if not (row[index] is float or row[index] is int) or not is_finite(float(row[index])) or absf(float(row[index])) > 2.0:
				return false
		rows.append({"id": row[0], "vessel": row[1], "x": float(row[2]), "y": float(row[3])})
	list = rows
	return true

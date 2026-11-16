class_name IslandHistory
extends RefCounted
## guardacostas-capture design.md §8 (spec "Island history"): every island the party has stood on this
## run, in order, with its index (the sandbar is 1, each on-graph island after it one more; an
## off-graph cay such as the secret cay keeps the index of the island it was reached from). Pure:
## IslandTravel owns one and appends in `_load`. The previous island is the last on-graph island
## before the current one with a lower index, so island 1's is itself and the secret cay is never it.
## The islands reached are the highest on-graph index, so a restart or a second arrival counts
## nothing twice.

## One stay on an island.
class Entry extends RefCounted:
	var layout_id: StringName = &""
	var index: int = 1
	var off_graph: bool = false


var entries: Array[Entry] = []


## The party now stands on `layout_id`, island number `index`.
func arrive(layout_id: StringName, index: int, off_graph: bool) -> void:
	var entry := Entry.new()
	entry.layout_id = layout_id
	entry.index = maxi(index, 1)
	entry.off_graph = off_graph
	entries.append(entry)


func current_id() -> StringName:
	return entries.back().layout_id if not entries.is_empty() else &""


## The current island's index (1 before anything is recorded).
func current_index() -> int:
	return entries.back().index if not entries.is_empty() else 1


## The index an island reached from here by a route or a release gets: one more for an on-graph
## island, the same for an off-graph one.
func next_index(off_graph: bool) -> int:
	return current_index() if off_graph else current_index() + 1


## The last on-graph entry before the current one with a lower index; the current one on island 1
## (or when nothing lower was recorded). Null when the history is empty.
func previous_entry() -> Entry:
	if entries.is_empty():
		return null
	var here: Entry = entries.back()
	for i: int in range(entries.size() - 2, -1, -1):
		var entry: Entry = entries[i]
		if not entry.off_graph and entry.index < here.index:
			return entry
	return here


## The previous island's layout id (see previous_entry); &"" when the history is empty.
func previous() -> StringName:
	var entry := previous_entry()
	return entry.layout_id if entry != null else &""


## The previous island's index (1 when the history is empty).
func previous_index() -> int:
	var entry := previous_entry()
	return entry.index if entry != null else 1


## The islands reached: the highest on-graph index, 1 at the least.
func reached() -> int:
	var highest: int = 1
	for entry: Entry in entries:
		if not entry.off_graph:
			highest = maxi(highest, entry.index)
	return highest

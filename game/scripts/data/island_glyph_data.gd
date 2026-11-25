class_name IslandGlyphData
extends DataPart
## A glyph of a handmade island's map that stands for a pick-up: the item lying on that cell, how
## many, which set of features it belongs to and when it comes back. One glyph, one cell.

## The character in the layout's rows.
@export var glyph: String = ""
@export var item_id: StringName = &""
@export var count: int = 1
## NEVER: lies there once. SQUALL: put back by the host when a squall ends. DAILY: put back by
## the host when a dawn begins.
@export var respawn: DataEnums.RespawnTrigger = DataEnums.RespawnTrigger.NEVER
## The set the pick-up belongs to (&"hut", &"flotsam", &"beach", &"dune").
@export var group: StringName = &""
## Share of the glyph's cells kept per extra player (1.0 keeps them all, a handmade layout's fixed
## counts). The raft recipe's inputs are never scaled below its amounts.
@export var party_scaling_per_extra_player: float = 1.0


func get_reference_fields() -> Dictionary[StringName, StringName]:
	var fields: Dictionary[StringName, StringName] = {}
	if not item_id.is_empty():
		fields[&"item_id"] = &"items"
	return fields

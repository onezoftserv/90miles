class_name PlayerLookData
extends Resource
## A player's look as part ids (art-pass "Layered player look"; design.md C1, C2): the body, the
## skin row the body is swapped to, the outfit, the hair and the signature item, each a `LookPart`
## id in res://assets/art/characters/parts/. The slot looks live in characters/looks/; the look
## composer builds one atlas per distinct look. The slot colour is not part of a look.

@export var id: StringName = &""
@export var body_id: StringName = &""
## Row of palette/skin_ramps.png: 0 claro, 1 trigueño, 2 moreno.
@export var skin_row: int = 0
@export var outfit_id: StringName = &""
@export var hair_id: StringName = &""
## Empty for no item.
@export var item_id: StringName = &""


## Equal for two looks that compose to the same atlas.
func cache_key() -> String:
	return "%s|%d|%s|%s|%s" % [body_id, skin_row, outfit_id, hair_id, item_id]

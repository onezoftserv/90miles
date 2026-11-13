class_name ShelterArtData
extends Resource
## Which island layouts get a shelter drawn over their hut, only in
## res://assets/art/structures/shelter_art.tres (art-pass "Lean-to over the hut"; design.md D18).
## A layout it does not name keeps only its shade decal (the coast cay's watch post, until its
## building art comes). The shelter scene's origin is the hut's back edge.

const STANDARD_PATH: String = "res://assets/art/structures/shelter_art.tres"

## Shelter scene by island layout id.
@export var shelters: Dictionary[StringName, PackedScene] = {}


static func standard() -> ShelterArtData:
	return load(STANDARD_PATH) as ShelterArtData


## The shelter of the layout `layout_id`, or null for none.
func shelter_for(layout_id: StringName) -> PackedScene:
	return shelters.get(layout_id, null) as PackedScene

class_name DecorArtData
extends Resource
## The decor looks, only in res://assets/art/structures/decor_art.tres (art-prop-polish D6;
## secret-cay "He left minutes ago"). DecorView draws each decor cell from the look of its decor id
## and terrain; an id with no look keeps its layout colour square, so a new kind stays a data edit.

const STANDARD_PATH: String = "res://assets/art/structures/decor_art.tres"

@export var looks: Array[DecorLook] = []


static func standard() -> DecorArtData:
	return load(STANDARD_PATH) as DecorArtData


## The look of `decor_id` on `terrain`: the one for that terrain, else the one for any terrain, else
## null.
func look_for(decor_id: StringName, terrain: int) -> DecorLook:
	var any: DecorLook = null
	for look: DecorLook in looks:
		if look.decor_id != decor_id:
			continue
		if look.terrain == terrain:
			return look
		if look.terrain < 0 and any == null:
			any = look
	return any

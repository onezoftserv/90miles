class_name SecretCayPlayground
extends SecretPlayground
## secret-cay's dev cay (design.md decision 11): the hidden cay, El cayo sin norte, with its empty
## chest, its note and the hat. `--with-pieces` gives the host's player the broken compass and the
## map, for checking the needle and the chest by hand. Every peer logs the chest's opening and its
## entry ("secret: chest open with entry <id>") and the note it shows. Arguments as
## SecretPlayground, plus `--with-pieces`.

const WITH_PIECES: String = "--with-pieces"

var chest: Chest = null


func _known_flags() -> PackedStringArray:
	return super() + PackedStringArray([WITH_PIECES])


# The chest, until it is open.
func _autopilot_target() -> Node2D:
	return chest if chest != null and not chest.opened else null


func _on_built() -> void:
	chest = session.get_node_or_null(NodePath(Chest.NAME)) as Chest
	if chest != null:
		chest.opened_with.connect(func(entry_id: StringName) -> void: log_line("chest open with entry %s" % entry_id))
	hud.note_label.shown.connect(func(text: String) -> void: log_line("note shows: %s" % text))
	if flags.has(WITH_PIECES) and session.multiplayer.is_server():
		var first := session.body(CoopSession.HOST_ID)
		var tuning := SecretTuning.standard()
		if first != null:
			first.inventory.add(tuning.compass_item_id, 1)
			first.inventory.add(tuning.map_item_id, 1)
			log_line("player %d carries the compass and the map" % CoopSession.HOST_ID)

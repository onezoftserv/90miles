class_name IslandSign
extends Interactable
## A flavour sign (island-generation "Flavour signs"): a wall slogan, a dead radio, two crossed
## sticks. Using it shows its line in a speech bubble over it, on every peer; nothing else changes.
## The level places it in the session at the same path on every peer.

## The two lines, set before it enters the tree.
var line_es: String = ""
var line_en: String = ""


# The level makes signs with new(), so the sign post's look is added here (drawing only).
func _init() -> void:
	add_child(StructureLook.create())


func _ready() -> void:
	hold_time_s = 0.0
	interacted.connect(_on_interacted)


## The line in `locale`.
func line(locale: String = "es") -> String:
	if locale.begins_with("en") and not line_en.is_empty():
		return line_en
	return line_es


# Host: tells every peer's session to show the bubble (the use runs only where the world is
# authoritative).
func _on_interacted(by: Node) -> void:
	var session := get_parent() as CoopSession
	if session == null or not by is PlayerBody or not session.multiplayer.is_server():
		return
	session.show_sign.rpc(String(name))

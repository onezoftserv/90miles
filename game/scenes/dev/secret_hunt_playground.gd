class_name SecretHuntPlayground
extends SecretPlayground
## secret-cay's dev hunt (design.md decision 11): the dev hunt layout, with the map and the broken
## compass placed by the hiding-spot rule from a fixed seed. Every peer logs where each piece lies
## ("secret: piece <id> at cell (x, y)"), the host logs the compass's spot kind and how long each
## piece took to find, for tuning. Arguments as SecretPlayground.

## The fixed dev seed the hunt places the pieces from.
const DEV_SEED: int = 1959

var hunt: SecretHunt = null


func _on_built() -> void:
	hunt = SecretHunt.new()
	session.add_child(hunt)
	hunt.setup(session, island)
	hunt.piece_found.connect(func(item_id: StringName, seconds: float) -> void: log_line("piece %s found after %.1f s" % [item_id, seconds]))
	hud.note_label.shown.connect(func(text: String) -> void: log_line("note shows: %s" % text))
	session.pickup_spawner.spawned.connect(_on_pickup_spawned)
	if session.multiplayer.is_server():
		hunt.piece_placed.connect(func(item_id: StringName, cell: Vector2i) -> void: log_line("piece %s at cell %s" % [item_id, cell]))
		if hunt.place_from_seed(DEV_SEED):
			log_line("the compass hides by a %s" % hunt.compass_kind)
		else:
			log_line("no hiding spots on %s" % layout.id)


# A client logs each concealed piece the host's spawner brings, to compare with the host's cells.
func _on_pickup_spawned(node: Node) -> void:
	var item := node as WorldItem
	if item != null and item.concealed:
		log_line("piece %s at cell %s" % [item.item_id, Vector2i(item.position / IslandLayout.TILE)])

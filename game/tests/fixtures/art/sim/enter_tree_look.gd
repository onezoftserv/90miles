extends Node2D
## Fixture for test_art_sim_invariance.gd (design.md K34): an art node with code in _enter_tree,
## which runs before the stripped run can detach its script, so the guard names it.

const ART_GROUP: StringName = &"art_view"


func _init() -> void:
	add_to_group(ART_GROUP)


func _enter_tree() -> void:
	pass

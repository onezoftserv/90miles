extends Node2D
## Fixture for test_art_sim_invariance.gd (design.md K34): a bad look that writes its player's
## thirst, a synced value, in one place: as it becomes ready, each physics frame or each process
## frame. The guard must catch each of them.

const ART_GROUP: StringName = &"art_view"
## Thirst taken by each write.
const SIP: float = 0.5

## &"ready", &"physics_process" or &"process": where this look writes.
var writes_in: StringName = &""


func _init(where: StringName = &"") -> void:
	writes_in = where
	add_to_group(ART_GROUP)


func _ready() -> void:
	_write_if(&"ready")


func _physics_process(_delta: float) -> void:
	_write_if(&"physics_process")


func _process(_delta: float) -> void:
	_write_if(&"process")


# Writes the thirst of the player this look sits under, at any depth.
func _write_if(where: StringName) -> void:
	if where != writes_in:
		return
	var node: Node = get_parent()
	while node != null and not node is PlayerBody:
		node = node.get_parent()
	var body := node as PlayerBody
	if body != null:
		body.meters.thirst -= SIP

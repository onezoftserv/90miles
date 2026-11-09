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


func _write_if(where: StringName) -> void:
	var body := get_parent() as PlayerBody
	if where == writes_in and body != null:
		body.meters.thirst -= SIP

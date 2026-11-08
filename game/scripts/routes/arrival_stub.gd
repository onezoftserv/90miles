class_name ArrivalStub
extends RefCounted
## The hand-off seam of the crossing: until arrival on the next island exists, a rider whose
## crossing ended simply leaves play. The island-arrival change replaces this file and the shell's
## handling of Crossing.ended.


static func hold(body: PlayerBody) -> void:
	body.left_island = true
	body.visible = false
	body.collision_layer = 0
	body.collision_mask = 0

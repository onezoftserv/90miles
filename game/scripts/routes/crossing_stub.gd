class_name CrossingStub
extends RefCounted
## The hand-off seam of escape-routes: until the crossing change ships, riders of a started
## route simply leave the island. The crossing change replaces this file and the shell's
## handling of IslandRoutes.route_started.


static func depart(body: PlayerBody) -> void:
	body.left_island = true
	body.visible = false
	body.collision_layer = 0
	body.collision_mask = 0

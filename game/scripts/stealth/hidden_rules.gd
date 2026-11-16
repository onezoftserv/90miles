class_name HiddenRules
extends RefCounted
## guardacostas-stealth decision 6: what hides a body on land, as one pure rule MovementModel calls.
## A roofed cell (a hut or post the island marks) hides in any posture; mangrove hides in any
## posture; scrub hides only a crouching player. In the water the swim and dive logic stays (a dive
## is SUBMERGED, a swimmer is not hidden), so this is asked on land only.


static func is_hidden_on_land(terrain: DataEnums.Terrain, crouching: bool, roofed: bool) -> bool:
	if roofed or terrain == DataEnums.Terrain.MANGROVE:
		return true
	return terrain == DataEnums.Terrain.SCRUB and crouching

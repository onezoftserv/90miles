class_name ChainRouteEntryData
extends DataPart
## One row of a chain's escape-route table, embedded in ChainData.routes: the per-chain
## guarantee, chance, starter and requirement tweaks for a RouteData id. A rolled route forces
## its starter POI into the island. Sources: ISLANDS 'Escape routes.', escape-routes spec.

## RouteData id.
@export var route_id: StringName = &""
## Always exposed on this chain.
@export var guaranteed: bool = false
## Pick weight for the open route slots.
@export var weight: float = 1.0
## Chance (0..1) that the carrier is available (Ramón 0.3).
@export var chance: float = 1.0
## POI id that anchors and starts the route here (forced into the island when rolled).
@export var starter_poi_id: StringName = &""
## NPC id of the carrier or giver here.
@export var starter_npc_id: StringName = &""
## Terrain anchor when there is no starter POI.
@export var anchor_feature: DataEnums.TerrainFeature = DataEnums.TerrainFeature.NONE
## Added to RouteData.requirements on this chain.
@export var extra_requirements: Array[ConditionData] = []
## extra_requirements replace the route's requirements (rider requirements are unchanged).
@export var replace_requirements: bool = false
## Map hint once the route is discovered.
@export var hint_es: String = ""
## English map hint.
@export var hint_en: String = ""


func get_reference_fields() -> Dictionary[StringName, StringName]:
	return {
		&"route_id": &"routes",
		&"starter_poi_id": &"pois",
		&"starter_npc_id": &"npcs",
	}

class_name SetPieceData
extends ContentData
## A scripted mini-situation (a Brogue-style 'machine'): at most one per island, or rolled
## during a crossing. Holds location filters, triggers, placement, spawns, contents and
## choices. Files live in game/resources/set_pieces/. Sources: ISLANDS set-piece table.

@export_group("Text")
## Situation text.
@export_multiline var description_es: String = ""
## English situation text.
@export_multiline var description_en: String = ""

@export_group("Where")
## ISLAND or CROSSING.
@export var context: DataEnums.SceneContext = DataEnums.SceneContext.ISLAND
## Chain family filter, OR with chain_ids.
@export var chain_families: Array[DataEnums.ChainFamily] = []
## Chain variant ids filter, OR with chain_families.
@export var chain_ids: Array[StringName] = []
## Distance bands allowed; empty means any band.
@export var distance_bands: Array[DataEnums.DistanceBand] = []
## POI ids: at least one must be present; the first present anchors the set piece.
@export var required_poi_ids: Array[StringName] = []

@export_group("When")
## Run-state gates (after a companion dies, 2+ players).
@export var trigger_conditions: Array[ConditionData] = []
## Earliest island number it can appear on.
@export var min_island: int = 1
## Pick weight (TBD).
@export var weight: float = 1.0
## Extra roll (0..1) once picked.
@export var chance: float = 1.0
## At most once per run (false for the_funeral).
@export var once_per_run: bool = true

@export_group("Placement")
## Where it goes; ignored when anchored by a POI or in a CROSSING.
@export var placement: DataEnums.Placement = DataEnums.Placement.BEACH
## Distance from shore in tiles, for OFFSHORE placement.
@export var offshore_distance_tiles: int = 0
## How long it lasts, in seconds; 0 means until resolved.
@export var duration_s: float = 0.0
## Prefab (asset).
@export var scene: PackedScene = null

@export_group("Contents")
## Creatures and NPCs it brings (the only place SpawnEntryData CREATURE/NPC is allowed).
@export var spawns: Array[SpawnEntryData] = []
## Items it holds.
@export var contents: Array[SpawnEntryData] = []
## Effects applied immediately when it starts.
@export var on_start_effects: Array[EffectData] = []
## Player options and their outcomes.
@export var choices: Array[ChoiceData] = []


func get_reference_fields() -> Dictionary[StringName, StringName]:
	return {
		&"chain_ids": &"chains",
		&"required_poi_ids": &"pois",
	}

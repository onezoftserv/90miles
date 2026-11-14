class_name SecretTuning
extends Resource
## Every number of the secret in one file (game/resources/secret_tuning.tres), like CraftingTuning,
## and which items are its two pieces (secret-cay "Secret tuning data"). The reveal radius is each
## item's own `conceal_radius_tiles`, not a value here. The same values hold for 1 to 4 players.

const STANDARD_PATH: String = "res://resources/secret_tuning.tres"

@export_group("Pieces")
## The map's item id; nothing in a script names it.
@export var map_item_id: StringName = &"mapa_sin_norte"
## The broken compass's item id.
@export var compass_item_id: StringName = &"brujula_rota"

@export_group("Existence roll")
## Chance that a run holds the secret (one roll for the pair).
@export var run_chance: float = 0.33
## The run indices the two pieces are drawn from, both ends included.
@export var index_min: int = 2
@export var index_max: int = 5
## Mixed with the run seed so the roll has a stream of its own.
@export var roll_salt: int = 0

@export_group("Concealment")
## A concealed item shimmers for shimmer_length_s every shimmer_period_s.
@export var shimmer_period_s: float = 6.0
@export var shimmer_length_s: float = 0.75
## Seconds interact is held to pick up a concealed item.
@export var concealed_pickup_hold_s: float = 1.5

@export_group("Needle")
## Distance band edges in tiles, outermost first: beyond the first it spins, inside the last it
## holds still.
@export var band_edges_tiles: Array[float] = [40.0, 20.0, 11.0, 6.0]
## Wobble amplitude in degrees inside each band but the last (parallel to the edges).
@export var band_wobble_deg: Array[float] = [90.0, 45.0, 20.0]
## The wobble's angular speed, radians per second.
@export var wobble_rad_per_s: float = 6.0
## Turns per second while it spins.
@export var spin_turns_per_s: float = 0.5

@export_group("Chest and note")
## Seconds interact is held to open the chest.
@export var chest_hold_s: float = 1.0
## The note label shows a text for note_base_s + note_per_char_s per character.
@export var note_base_s: float = 6.0
@export var note_per_char_s: float = 0.05

@export_group("Hiding spots")
## The strict band of land walking distance from the landing, as percentiles.
@export var spot_percentile_min: float = 0.50
@export var spot_percentile_max: float = 0.85
## The first fallback band.
@export var spot_fallback_percentile_min: float = 0.25
@export var spot_fallback_percentile_max: float = 1.0
## A strict spot lies this many tiles (straight line) from the nearest feature.
@export var spot_feature_min_tiles: float = 4.0
@export var spot_feature_max_tiles: float = 10.0
## The kinds of feature a spot is measured from.
@export var spot_feature_kinds: Array[StringName] = [&"palm", &"pickup", &"tide_pool", &"workbench", &"raft_site"]

@export_group("Map hint")
## Spot kind to the phrase that fills the map's {pista} slot; `default` for a kind with none.
@export var spot_hints_es: Dictionary[StringName, String] = {}
@export var spot_hints_en: Dictionary[StringName, String] = {}


static func standard() -> SecretTuning:
	return load(STANDARD_PATH) as SecretTuning


## The hint phrase for `kind` in `locale` ("es" unless "en"), or the default phrase.
func hint_for(kind: StringName, locale: String) -> String:
	var hints: Dictionary[StringName, String] = spot_hints_en if locale == "en" else spot_hints_es
	return hints.get(kind, hints.get(&"default", ""))

class_name DifficultyScaling
extends RefCounted
## Co-op difficulty for one island (coop-networking "Difficulty scaling", approved 2026-11-05):
## from the number of living, connected players when the island is set up. Resources ×0.8 per
## such player beyond the first; patrols +1 per 2 such players, rounded down. One player (solo,
## or the last survivor of a party) gets the base numbers: solo has no tuning of its own.
## CoopSession.island_difficulty() counts the players; island setup reads the result.

const RESOURCE_FACTOR_PER_EXTRA_PLAYER: float = 0.8
const PLAYERS_PER_EXTRA_PATROL: float = 2.0

## Living, connected players counted (at least 1).
var players: int = 1
## Multiplier on resource spawn rates.
var resource_multiplier: float = 1.0
## Patrols added to the island's base count.
var extra_patrols: int = 0


static func for_players(count: int) -> DifficultyScaling:
	var scaling := DifficultyScaling.new()
	scaling.players = maxi(count, 1)
	scaling.resource_multiplier = pow(RESOURCE_FACTOR_PER_EXTRA_PLAYER, scaling.players - 1)
	scaling.extra_patrols = floori(scaling.players / PLAYERS_PER_EXTRA_PATROL)
	return scaling

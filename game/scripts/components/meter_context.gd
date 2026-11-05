class_name MeterContext
extends RefCounted
## What the world says about one player for one SurvivalMeters.tick. Tests set it directly;
## PlayerBody builds it each physics frame from the terrain, the movement state, nearby
## teammates and the ClimateState. The defaults describe a player at rest out of the sun.

## Day phase from the clock (weather-daynight).
var phase: DataEnums.DayPhase = DataEnums.DayPhase.DAWN
## In-game 10:00-16:00, the only time direct sun raises heat.
var midday: bool = false
## Under a roof, a tarp or a palm canopy.
var shaded: bool = false
var in_water: bool = false
## Moving through water under the player's own power (not floating).
var swimming: bool = false
## Crafting or building (crafting-inventory sets it).
var crafting: bool = false
## A living teammate within company_radius_tiles.
var teammate_nearby: bool = false
## Weather multiplier on heat gain: 2 in scorching calm.
var heat_factor: float = 1.0


## Day phase, on land, not in shade.
func in_direct_sun() -> bool:
	return phase == DataEnums.DayPhase.DAY and not shaded and not in_water

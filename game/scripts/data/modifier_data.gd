class_name ModifierData
extends DataPart
## The single passive stat modifier: from an equipped item (or a carried one with no equip slot),
## a background (always), a companion in the party, or a keepsake. Embedded in items, backgrounds
## and NpcData.companion; holds no references. Sources: ITEMS, CHARACTERS 'Skill:', GAME_DESIGN 10.

enum Stat {
	HEAT_GAIN,
	WALK_SPEED,
	SWIM_SPEED,
	SWIM_THIRST_FACTOR,
	CORAL_DAMAGE,
	INVENTORY_SLOTS,
	MORALE_DRAIN,
	BUILD_SPEED,
	REPAIR_SPEED,
	LINE_FISH_RATE,
	FISH_CATCH_INTERVAL_S,
	VESSEL_MAX_INTEGRITY,
	VESSEL_SQUALL_DAMAGE,
	VESSEL_LEAK_RATE,
	PATROL_SPOT_TIME,
	NOISE_RADIUS,
	MELEE_DAMAGE,
	THROWN_DAMAGE,
	HEAL_RATE,
	HEAL_PER_NIGHT,
	TEXT_FIND_RATE,
	NPC_TRUST_GAIN,
	SONG_MORALE,
}

enum Op {
	MULTIPLY,
	ADD,
	SET,
}

enum Context {
	ALWAYS,
	ON_LAND,
	IN_WATER,
	ABOARD_VESSEL,
}

enum Scope {
	HOLDER,
	PARTY,
	VESSEL,
}

## Stat modified. HEAT_GAIN is the rate toward sunstroke, whichever way the meter runs.
@export var stat: Stat = Stat.HEAT_GAIN
## How value applies: MULTIPLY, ADD or SET.
@export var op: Op = Op.MULTIPLY
## Operand (straw hat x0.7, belt +2, wetsuit thirst SET 2.0).
@export var value: float = 1.0
## When it counts: always, on land, in water or aboard a vessel.
@export var context: Context = Context.ALWAYS
## HOLDER (the carrier, player or companion), PARTY (everyone with them) or VESSEL (raft or boat).
@export var scope: Scope = Scope.HOLDER

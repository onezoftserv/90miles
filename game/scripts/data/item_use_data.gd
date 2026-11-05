class_name ItemUseData
extends DataPart
## One action an item offers, embedded in ItemData.uses (game/resources/items/*.tres).
## Every requirement (a tool capability, items carried, fire nearby, players nearby, phase,
## band) is a ConditionData. No references of its own. Sources: ITEMS.md, crafting-inventory spec.

## Verb and animation of the action.
enum UseAction {
	EAT,
	DRINK,
	APPLY,
	SMOKE,
	READ,
	PLAY,
	THROW,
	PLACE,
	SIGNAL,
	LISTEN,
	CALL,
	CHARGE,
	ACTIVATE,
}

## Verb and animation. EAT also triggers the global +10 energy meal rule.
@export var action: UseAction = UseAction.EAT
## Seconds the action takes (solar charger: 720, a full day).
@export var time_s: float = 0.0
## Day phases the action uses up (dominoes: 1 night phase).
@export var time_phases: int = 0
## Spends 1 durability; false for repeatable uses.
@export var spends_use: bool = true
## Usable on an adjacent teammate (revive with water, feed, aloe); USE_TARGET effects hit them.
@export var can_target_others: bool = false
## All must hold (HAS_CAPABILITY OPEN_COCONUT, LIT_FIRE_NEARBY, PLAYERS_NEARBY_AT_LEAST 2...).
@export var conditions: Array[ConditionData] = []
## Applied in order when the action completes.
@export var effects: Array[EffectData] = []

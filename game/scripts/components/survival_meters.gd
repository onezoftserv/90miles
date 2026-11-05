class_name SurvivalMeters
extends Node
## Per-player survival meters (survival-meters spec). Thirst, hunger, energy, morale and health
## start full and drain; heat starts at 0 and rises toward sunstroke at 100. Every value and state
## is a plain property so coop-networking can replicate it: setters only clamp and signal. The
## host changes them through the methods below, which also derive the states.

signal meter_changed(meter: DataEnums.Meter, value: float)
## Kept from player-movement; also emitted as meter_changed(ENERGY, value).
signal energy_changed(value: float)
signal sunstroke_changed(active: bool)
signal hallucinating_changed(active: bool)
signal downed_changed(is_downed: bool)
signal died

const MAX_VALUE: float = 100.0
const MAX_ENERGY: float = MAX_VALUE

## Rates and thresholds. The numbers live in the .tres, never in code.
@export var tuning: SurvivalTuning = preload("res://resources/survival_tuning.tres")

var thirst: float = MAX_VALUE:
	set(value):
		var clamped := _clamped(value)
		if clamped == thirst:
			return
		thirst = clamped
		meter_changed.emit(DataEnums.Meter.THIRST, thirst)

var hunger: float = MAX_VALUE:
	set(value):
		var clamped := _clamped(value)
		if clamped == hunger:
			return
		hunger = clamped
		meter_changed.emit(DataEnums.Meter.HUNGER, hunger)

## 0 is cool; sunstroke at tuning.sunstroke_at.
var heat: float = 0.0:
	set(value):
		var clamped := _clamped(value)
		if clamped == heat:
			return
		heat = clamped
		meter_changed.emit(DataEnums.Meter.HEAT, heat)

var energy: float = MAX_ENERGY:
	set(value):
		var clamped := _clamped(value)
		if clamped == energy:
			return
		energy = clamped
		meter_changed.emit(DataEnums.Meter.ENERGY, energy)
		energy_changed.emit(energy)

var morale: float = MAX_VALUE:
	set(value):
		var clamped := _clamped(value)
		if clamped == morale:
			return
		morale = clamped
		meter_changed.emit(DataEnums.Meter.MORALE, morale)

var health: float = MAX_VALUE:
	set(value):
		var clamped := _clamped(value)
		if clamped == health:
			return
		health = clamped
		meter_changed.emit(DataEnums.Meter.HEALTH, health)

## Screen blur and slower movement, from heat reaching sunstroke_at until it drops below
## sunstroke_ends_below.
var sunstroke: bool = false:
	set(value):
		if value == sunstroke:
			return
		sunstroke = value
		sunstroke_changed.emit(sunstroke)

## Morale below hallucinate_below. Other systems show the hallucinations.
var hallucinating: bool = false:
	set(value):
		if value == hallucinating:
			return
		hallucinating = value
		hallucinating_changed.emit(hallucinating)

## Health reached 0 in co-op: immobile and draggable until revived or the timer ends.
var downed: bool = false:
	set(value):
		if value == downed:
			return
		downed = value
		downed_changed.emit(downed)

## Permadeath for the run. Set once; emits died.
var dead: bool = false:
	set(value):
		if value == dead:
			return
		dead = value
		if dead:
			died.emit()


## The value of `meter`, 0 for NONE.
func value(meter: DataEnums.Meter) -> float:
	match meter:
		DataEnums.Meter.THIRST:
			return thirst
		DataEnums.Meter.HUNGER:
			return hunger
		DataEnums.Meter.HEAT:
			return heat
		DataEnums.Meter.ENERGY:
			return energy
		DataEnums.Meter.MORALE:
			return morale
		DataEnums.Meter.HEALTH:
			return health
	return 0.0


## Sets `meter` directly (clamped), as replication does. Derives no state.
func set_value(meter: DataEnums.Meter, new_value: float) -> void:
	match meter:
		DataEnums.Meter.THIRST:
			thirst = new_value
		DataEnums.Meter.HUNGER:
			hunger = new_value
		DataEnums.Meter.HEAT:
			heat = new_value
		DataEnums.Meter.ENERGY:
			energy = new_value
		DataEnums.Meter.MORALE:
			morale = new_value
		DataEnums.Meter.HEALTH:
			health = new_value
		_:
			push_error("SurvivalMeters.set_value: no meter %d" % meter)


## Spends up to `amount` (never below 0) and returns the amount actually spent.
func spend_energy(amount: float) -> float:
	if amount <= 0.0:
		return 0.0
	var before: float = energy
	energy = before - amount
	return before - energy


func gain_energy(amount: float) -> void:
	if amount > 0.0:
		energy = energy + amount


static func _clamped(raw: float) -> float:
	return clampf(raw, 0.0, MAX_VALUE)

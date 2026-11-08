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
signal last_stand_changed(active: bool)
## A free revive (the Medalla) stood the player up at 0 health.
signal free_revive_used
signal died
## Every peer: a status started or ended (status_flags changed, by set_status or the sync).
signal statuses_changed(flags: int)

## One-off morale changes other systems report; the amounts are in the tuning.
enum MoraleEvent { ALLY_DIED, SQUALL, FIRE_LIT, SONG, TEXT_READ }

const MAX_VALUE: float = 100.0
const MAX_ENERGY: float = MAX_VALUE
## A value at or below this is empty: repeated float subtraction leaves crumbs like 2e-15.
const EMPTY_EPSILON: float = 0.000001
const ALL_METERS: Array[DataEnums.Meter] = [
	DataEnums.Meter.THIRST, DataEnums.Meter.HUNGER, DataEnums.Meter.HEAT,
	DataEnums.Meter.ENERGY, DataEnums.Meter.MORALE, DataEnums.Meter.HEALTH,
]

## Rates and thresholds. The numbers live in the .tres, never in code.
@export var tuning: SurvivalTuning = preload("res://resources/survival_tuning.tres")
## No other living player in the run (a one-player run or the last one alive): health 0 starts a
## last stand instead of downing. PlayerBody derives it on the host every tick.
@export var solo: bool = false
## Seconds added to the downed timer and to a solo last stand: Experiencia levels and the point
## boost. endings-progression sets it; the meters never compute it.
@export var downed_bonus_s: float = 0.0
## Unused free revives this run (the Medalla de la Caridad's holder gets 1). The keepsake system
## sets it; each one stands the player at revive_health once instead of going down or dying.
@export var free_revives: int = 0

## Seconds left before dying while downed or in a last stand.
var downed_time_left_s: float = 0.0

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

## A solo player at 0 health with time left to save themselves: lying still, not downed.
var last_stand: bool = false:
	set(value):
		if value == last_stand:
			return
		last_stand = value
		last_stand_changed.emit(last_stand)

## Permadeath for the run. Set once; emits died.
var dead: bool = false:
	set(value):
		if value == dead:
			return
		dead = value
		if dead:
			died.emit()

## Statuses on this player, one bit (1 << status) per DataEnums.Status (status-sync). The host
## sets them through set_status; the player's synchronizer sends the int to every peer like the
## meters, so a client reads the host's and never sets one.
var status_flags: int = 0:
	set(value):
		if status_flags == value:
			return
		status_flags = value
		statuses_changed.emit(value)

## Changes spread over time (seawater, poison), advanced by tick.
var _timed: Array[MeterOverTime] = []


## One host step: timed changes, then drains and restores from `context`, then the states.
func tick(delta: float, context: MeterContext) -> void:
	if dead or delta < 0.0:
		return
	if downed or last_stand:
		downed_time_left_s = maxf(downed_time_left_s - delta, 0.0)
		if downed_time_left_s <= EMPTY_EPSILON:
			dead = true
			return
	_advance_timed(delta)
	thirst -= SurvivalRules.thirst_drain(context, tuning) * delta
	hunger -= SurvivalRules.hunger_drain(context, tuning) * delta
	heat = SurvivalRules.next_heat(heat, context, tuning, delta)
	morale += SurvivalRules.morale_rate(context, tuning) * delta
	_snap_empty()
	if thirst <= 0.0:
		health -= tuning.dry_health_per_s * delta
	_update_states()


## Adds `amount` (negative to take) to `meter` now. Energy respects the starving cap.
func add(meter: DataEnums.Meter, amount: float) -> void:
	if dead:
		return
	_add_raw(meter, amount)
	_update_states()


## Spreads `total` over `duration_s` seconds of ticks; instant when the duration is 0.
func add_over_time(meter: DataEnums.Meter, total: float, duration_s: float) -> void:
	if duration_s <= 0.0:
		add(meter, total)
		return
	_timed.append(MeterOverTime.new(meter, total, duration_s))


## Eats food worth `hunger_amount`. Anything that restores hunger is a meal and gives energy.
func eat(hunger_amount: float) -> void:
	if dead or hunger_amount <= 0.0:
		return
	hunger += hunger_amount
	gain_energy(tuning.meal_energy)
	_update_states()


## A full night in shelter.
func sleep_night() -> void:
	add(DataEnums.Meter.ENERGY, tuning.sleep_energy)


func morale_event(event: MoraleEvent) -> void:
	add(DataEnums.Meter.MORALE, _morale_amount(event))


## Stands a downed player up at revive_health (the cup's own effects are the caller's). Returns
## false, changing nothing, unless the player is downed and alive.
func revive() -> bool:
	if not (downed or last_stand) or dead:
		return false
	health = tuning.revive_health
	downed_time_left_s = 0.0
	downed = false
	last_stand = false
	_update_states()
	return true


## Multiplier on the player's own movement speed.
func speed_factor() -> float:
	return tuning.sunstroke_speed_factor if sunstroke else 1.0


## Highest energy right now: lower while hunger is empty.
func energy_cap() -> float:
	return tuning.starving_energy_cap if hunger <= 0.0 else MAX_ENERGY


func has_status(status: DataEnums.Status) -> bool:
	return _is_real_status(status) and (status_flags & (1 << status)) != 0


## Host: starts or ends `status`. NONE and values outside DataEnums.Status change nothing.
func set_status(status: DataEnums.Status, active: bool) -> void:
	if not _is_real_status(status):
		return
	var bit: int = 1 << status
	status_flags = (status_flags | bit) if active else (status_flags & ~bit)


static func _is_real_status(status: int) -> bool:
	return status > DataEnums.Status.NONE and status < DataEnums.Status.size()


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


## Restores up to `amount`, never past energy_cap() (and never lowers a value already above it).
func gain_energy(amount: float) -> void:
	if amount > 0.0:
		energy = maxf(energy, minf(energy + amount, energy_cap()))


func _add_raw(meter: DataEnums.Meter, amount: float) -> void:
	if meter == DataEnums.Meter.ENERGY:
		if amount >= 0.0:
			gain_energy(amount)
		else:
			spend_energy(-amount)
		return
	set_value(meter, value(meter) + amount)


func _advance_timed(delta: float) -> void:
	var running: Array[MeterOverTime] = []
	for change: MeterOverTime in _timed:
		_add_raw(change.meter, change.take(delta))
		if not change.finished():
			running.append(change)
	_timed = running


func _snap_empty() -> void:
	for meter: DataEnums.Meter in ALL_METERS:
		var current: float = value(meter)
		if current > 0.0 and current <= EMPTY_EPSILON:
			set_value(meter, 0.0)


## Derives the states from the values. Host only: replicated values never call it.
func _update_states() -> void:
	if energy > energy_cap():
		energy = energy_cap()
	if heat >= tuning.sunstroke_at:
		sunstroke = true
	elif heat < tuning.sunstroke_ends_below:
		sunstroke = false
	hallucinating = morale < tuning.hallucinate_below
	if health <= 0.0 and not downed and not last_stand and not dead:
		_on_health_empty()


## Health just reached 0: a free revive, else co-op downed, else a solo last stand or death.
func _on_health_empty() -> void:
	if free_revives > 0:
		free_revives -= 1
		health = tuning.revive_health
		free_revive_used.emit()
		return
	if not solo:
		downed_time_left_s = tuning.downed_s + downed_bonus_s
		downed = true
		return
	var window_s: float = tuning.solo_last_stand_s + downed_bonus_s
	if window_s <= EMPTY_EPSILON:
		dead = true
		return
	downed_time_left_s = window_s
	last_stand = true


func _morale_amount(event: MoraleEvent) -> float:
	match event:
		MoraleEvent.ALLY_DIED:
			return tuning.morale_ally_died
		MoraleEvent.SQUALL:
			return tuning.morale_squall
		MoraleEvent.FIRE_LIT:
			return tuning.morale_fire_lit
		MoraleEvent.SONG:
			return tuning.morale_song
		MoraleEvent.TEXT_READ:
			return tuning.morale_text_read
	return 0.0


static func _clamped(raw: float) -> float:
	return clampf(raw, 0.0, MAX_VALUE)

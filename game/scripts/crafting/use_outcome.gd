class_name UseOutcome
extends RefCounted
## What a use would do to whoever it goes on (damage-feedback design D11, D12), worked out on scratch
## copies of their meters, never the real ones, through the same rules the host applies
## (EffectApplier.add_meter_to, SurvivalMeters.set_status): a hunger gain is a meal with its energy,
## and energy keeps the starving cap. Only meter gains at once and cures are tried; any other kind
## of effect (a revive, items, routes, flags, a delay, a change over time, a loss, or a kind the host
## does not apply yet) counts as doing something.

const EPSILON: float = 0.0001
const METERS: Array[DataEnums.Meter] = [
	DataEnums.Meter.THIRST, DataEnums.Meter.HUNGER, DataEnums.Meter.HEAT,
	DataEnums.Meter.ENERGY, DataEnums.Meter.MORALE, DataEnums.Meter.HEALTH,
]


## Whether no effect of `action` would change anything for whoever it goes on (crafting-inventory
## "A use that changes nothing is refused"). A use with no effects is never judged wasted.
static func changes_nothing(action: ItemUseData, actor: PlayerBody, target: PlayerBody) -> bool:
	if action == null or action.effects.is_empty() or actor == null:
		return false
	for effect: EffectData in action.effects:
		if not tried(effect):
			return false
	var runs := _Runs.new()
	for effect: EffectData in action.effects:
		_apply(effect, runs.scratch_for(EffectApplier.subject_of(effect, actor, target)))
	var nothing: bool = runs.all_unchanged()
	runs.free_all()
	return nothing


## How much of each meter gain at once in `action` would land, in order: for effect i, the gain of
## its own meter and, for a meal, the energy it brings. Effects that are not gains at once get
## Vector2.ZERO. Worked out effect by effect on scratch copies, so two gains share the headroom.
static func useful_gains(action: ItemUseData, actor: PlayerBody, target: PlayerBody) -> Array[Vector2]:
	var gains: Array[Vector2] = []
	if action == null or actor == null:
		return gains
	var runs := _Runs.new()
	for effect: EffectData in action.effects:
		if not tried(effect):
			gains.append(Vector2.ZERO)
			continue
		var subject := EffectApplier.subject_of(effect, actor, target)
		if subject == null:
			gains.append(Vector2.ZERO)
			continue
		var scratch: SurvivalMeters = runs.scratch_for(subject)
		var meter_before: float = scratch.value(effect.meter) if effect.kind == EffectData.Kind.METER_ADD else 0.0
		var energy_before: float = scratch.energy
		_apply(effect, scratch)
		if effect.kind != EffectData.Kind.METER_ADD:
			gains.append(Vector2.ZERO)
			continue
		var meal: float = scratch.energy - energy_before if effect.meter == DataEnums.Meter.HUNGER else 0.0
		gains.append(Vector2(scratch.value(effect.meter) - meter_before, meal))
	runs.free_all()
	return gains


## Whether a dry run tries `effect`: a meter gain at once or a cure, with no delay.
static func tried(effect: EffectData) -> bool:
	if effect == null or effect.delay_s > 0.0:
		return false
	if effect.kind == EffectData.Kind.CURE_STATUS:
		return true
	return effect.kind == EffectData.Kind.METER_ADD and effect.amount > 0.0 and effect.duration_s <= 0.0


static func _apply(effect: EffectData, scratch: SurvivalMeters) -> void:
	if scratch == null:
		return
	if effect.kind == EffectData.Kind.CURE_STATUS:
		scratch.set_status(effect.status, false)
	else:
		EffectApplier.add_meter_to(effect, scratch)


# The scratch meters of each subject in one dry run, and the real ones they copy.
class _Runs:
	extends RefCounted

	var _real: Array[SurvivalMeters] = []
	var _scratch: Array[SurvivalMeters] = []

	func scratch_for(subject: PlayerBody) -> SurvivalMeters:
		if subject == null:
			return null
		var index: int = _real.find(subject.meters)
		if index >= 0:
			return _scratch[index]
		var copy := SurvivalMeters.new()
		var real: SurvivalMeters = subject.meters
		copy.tuning = real.tuning
		copy.solo = real.solo
		copy.thirst = real.thirst
		copy.hunger = real.hunger
		copy.heat = real.heat
		copy.morale = real.morale
		copy.health = real.health
		copy.energy = real.energy
		copy.status_flags = real.status_flags
		_real.append(real)
		_scratch.append(copy)
		return copy

	func all_unchanged() -> bool:
		for i: int in _real.size():
			if _real[i].status_flags != _scratch[i].status_flags:
				return false
			for meter: DataEnums.Meter in UseOutcome.METERS:
				if absf(_real[i].value(meter) - _scratch[i].value(meter)) > UseOutcome.EPSILON:
					return false
		return true

	func free_all() -> void:
		for copy: SurvivalMeters in _scratch:
			copy.free()
		_scratch.clear()
		_real.clear()

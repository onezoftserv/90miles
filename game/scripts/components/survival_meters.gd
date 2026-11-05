class_name SurvivalMeters
extends Node
## Per-player survival meters. Only energy exists so far (player-movement); the other five
## arrive with the survival-meters change, which extends this component.

signal energy_changed(value: float)

const MAX_ENERGY: float = 100.0

## 0 to MAX_ENERGY. Emits energy_changed when the value actually changes.
var energy: float = MAX_ENERGY:
	set(value):
		var clamped: float = clampf(value, 0.0, MAX_ENERGY)
		if clamped == energy:
			return
		energy = clamped
		energy_changed.emit(energy)


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

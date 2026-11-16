class_name HurtCues
extends RefCounted
## What every hit, drain and change cue shares (damage-feedback design D6, D8): the tuning, loaded
## once, and the "Reducir destellos" setting. The shell writes `reduce_flashes` when the settings
## load or change; it is per install, so one value per process is right. Tests that set it put it
## back. Feedback only.

const TUNING_PATH: String = "res://resources/hurt_cue_tuning.tres"

## With it on, nothing flashes, blinks or shakes: the blink is a steady tint, and the edge flash,
## the bar flash and the shake are gone. Slices, floats and the glow stay.
static var reduce_flashes: bool = false

static var _tuning: HurtCueTuning = null


static func tuning() -> HurtCueTuning:
	if _tuning == null:
		_tuning = load(TUNING_PATH) as HurtCueTuning
	return _tuning

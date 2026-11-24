class_name AudioBuses
extends RefCounted
## The game's mix (sound-pass design D4): the Efectos and Ambiente buses, both sending to Master,
## whose volume is the player's volume setting, and the size of AudioManager's voice pool (a
## service declares no constants, core-services). Made in code at start, so no editor bus layout
## file is needed.

const SFX: StringName = &"Efectos"
const AMBIENCE: StringName = &"Ambiente"
const MASTER: StringName = &"Master"
## One-shot voices AudioManager keeps; the oldest is reused when all are taken.
const VOICES: int = 8
## A loop level below this counts as silent.
const SILENT: float = 0.0001


## Adds the two buses under Master unless they are there already.
static func ensure() -> void:
	for bus_name: StringName in [SFX, AMBIENCE]:
		if AudioServer.get_bus_index(bus_name) >= 0:
			continue
		AudioServer.add_bus()
		var index: int = AudioServer.bus_count - 1
		AudioServer.set_bus_name(index, bus_name)
		AudioServer.set_bus_send(index, MASTER)


## The bus a sound of the bank plays on.
static func name_of(bus: SoundData.Bus) -> StringName:
	return AMBIENCE if bus == SoundData.Bus.AMBIENCE else SFX

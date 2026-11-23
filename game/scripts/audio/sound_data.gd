class_name SoundData
extends Resource
## One sound of the sound bank (sound-pass design D3): the file the game plays for one id and how.
## Content data: replacing a file or retuning a level edits only the bank.

## Efectos carries every cue and the patrol motor (a warning); Ambiente the sea, wind and night beds.
enum Bus {
	SFX,
	AMBIENCE,
}

## What callers ask for: AudioManager.play_sfx(id) or set_loop_level(id, level).
@export var id: StringName = &""
@export var stream: AudioStream = null
@export var bus: Bus = Bus.SFX
## The level at which it plays, before the volume setting and any loop level or db offset.
@export_range(-60.0, 0.0, 0.5) var volume_db: float = 0.0
## Loops are set to a level and keep playing; the rest play once per request.
@export var loop: bool = false
## Each play's pitch is 1 ± a random fraction up to this (SPD's hit-sound spread).
@export_range(0.0, 0.5, 0.01) var pitch_spread: float = 0.0
## Requests for this id closer together than this play once.
@export var min_interval_s: float = 0.0
## Loops: seconds to move from silence to full or back.
@export var fade_s: float = 1.0
## True for a file made by tools/audio/sfx.py; false for an approved recording (owner Q2 B), whose
## author, licence and source its folder's License.txt carries.
@export var generated: bool = true

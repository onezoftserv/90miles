class_name CreatureAnim
extends RefCounted
## Which animation a creature plays (art-pass "Creature frames from data", "Creature motion on every
## peer", "Facing variants for creatures"; design.md D16, K1, K3, K15). `pick` is pure: from the
## frames' names, the state name, the facing and whether it moves it tries `<state>_<facing>`,
## `<state>`, `move_<facing>` and `move` (only while moving), `idle_<facing>` and `idle`, and
## returns only a name the frames have, or &"" when none fits, so `play()` never gets a missing
## name. An instance keeps what one look needs from frame to frame: whether the drawn position
## changed within the last MOTION_WINDOW_S, and a one-shot of the creature art data playing once
## after a state change it saw. Nothing here writes the creature.

## Longer than the 0.1 s between the positions a client receives (Creature.SYNC_INTERVAL_S).
const MOTION_WINDOW_S: float = 0.15
## Float steps of a frame's delta summed past the window still count as past it.
const WINDOW_EPSILON_S: float = 0.0001
const SIDE: StringName = &"side"
const UP: StringName = &"up"
const DOWN: StringName = &"down"
const MOVE: StringName = &"move"
const IDLE: StringName = &"idle"

## What `update` last returned.
var animation: StringName = &""
var moving: bool = false

var _last_position: Vector2 = Vector2.ZERO
var _seen_position: bool = false
var _since_change_s: float = INF
var _state: StringName = &""
var _one_shot: StringName = &""
var _one_shot_left_s: float = 0.0


## `side` unless the vertical part of the facing is the larger; a diagonal tie faces sideways.
static func facing_suffix(facing: Vector2) -> StringName:
	if absf(facing.x) >= absf(facing.y) and facing != Vector2.ZERO:
		return SIDE
	return UP if facing.y < 0.0 else DOWN


static func pick(names: PackedStringArray, state: StringName, facing: Vector2, moving_now: bool) -> StringName:
	var suffix: String = "_" + String(facing_suffix(facing))
	var state_name: String = String(state).to_lower()
	var tries: PackedStringArray = [state_name + suffix, state_name]
	if moving_now:
		tries.append_array([String(MOVE) + suffix, String(MOVE)])
	tries.append_array([String(IDLE) + suffix, String(IDLE)])
	for name: String in tries:
		if names.has(name):
			return StringName(name)
	return &""


## Side-on frames face right and are mirrored while the creature faces left; `_up` and `_down`
## variants never are.
static func flipped(animation_name: StringName, facing: Vector2) -> bool:
	var name: String = String(animation_name)
	if name.ends_with("_" + String(UP)) or name.ends_with("_" + String(DOWN)):
		return false
	if name.ends_with("_" + String(SIDE)):
		return facing.x < 0.0 and facing_suffix(facing) == SIDE
	return facing.x < 0.0


## `idle`, or all three facing variants of it (art-pass "Facing variants count as idle").
static func has_idle(names: PackedStringArray) -> bool:
	if names.has(String(IDLE)):
		return true
	for suffix: StringName in [DOWN, UP, SIDE]:
		if not names.has(String(IDLE) + "_" + String(suffix)):
			return false
	return true


## Seconds one pass of `animation_name` lasts at its own speed.
static func length_s(frames: SpriteFrames, animation_name: StringName) -> float:
	var speed: float = frames.get_animation_speed(animation_name)
	if speed <= 0.0:
		return 0.0
	var beats: float = 0.0
	for index: int in frames.get_frame_count(animation_name):
		beats += frames.get_frame_duration(animation_name, index)
	return beats / speed


## Records the drawn position this frame; true while it changed within the last MOTION_WINDOW_S.
func observe(position: Vector2, delta: float) -> bool:
	if not _seen_position:
		_seen_position = true
		_last_position = position
		moving = false
		return moving
	if position != _last_position:
		_last_position = position
		_since_change_s = 0.0
	else:
		_since_change_s += delta
	moving = _since_change_s < MOTION_WINDOW_S - WINDOW_EPSILON_S
	return moving


## The animation to show this frame, `delta` after the last call: a one-shot while it lasts, else
## `pick` (an airborne state counts as moving).
func update(frames: SpriteFrames, art: CreatureArtEntry, state: StringName, facing: Vector2, delta: float) -> StringName:
	var state_name := StringName(String(state).to_lower())
	var names: PackedStringArray = frames.get_animation_names() if frames != null else PackedStringArray()
	if _one_shot_left_s > 0.0:
		_one_shot_left_s -= delta
	if state_name != _state:
		var first_seen: bool = _state.is_empty()
		_state = state_name
		_one_shot = &"" if first_seen else StringName(art.one_shots.get(state_name, &""))
		_one_shot_left_s = length_s(frames, _one_shot) if names.has(String(_one_shot)) else 0.0
	if _one_shot_left_s > 0.0:
		animation = _one_shot
		return animation
	var airborne: bool = art.airborne_states.has(String(state_name))
	animation = pick(names, state_name, facing, moving or airborne)
	return animation

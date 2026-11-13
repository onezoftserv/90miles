class_name CreatureLook
extends Node2D
## A creature's look (art-pass "Creature frames from data", "The sandbar's creatures", "Drop
## shadows"; design.md D16, D19, D22, K1, K4, K15): the `Look` child of creature.tscn, in
## `art_view`. Every frame it reads its creature's data, synced `position`, `facing` and
## `state_id` and draws them: the animation CreatureAnim picks, the airborne and perch lifts, the
## shadow on the ground and the water-line material, from the creature art data. It never writes
## the creature. A creature without frames (a boss proxy) draws nothing and never plays.
## CreatureRig processes no frames, so the tests drive `step` themselves.

const WATERLINE_SHADER: Shader = preload("res://scenes/art/waterline.gdshader")
## A perched look sorts this far south of its creature's position, over the palm whose trunk base
## that position is, and its sprite is raised by as much.
const PERCH_SORT_PX: float = 1.0

@export var art: CreatureArt

var _anim: CreatureAnim = CreatureAnim.new()

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var shadow: DropShadow = $Shadow


func _process(delta: float) -> void:
	step(delta)


## Draws the creature as it is now, `delta` seconds after the last step.
func step(delta: float) -> void:
	var creature := get_parent() as Creature
	var data: CreatureData = creature.data if creature != null else null
	var frames: SpriteFrames = data.sprite_frames if data != null else null
	if frames == null:
		_show_nothing()
		return
	var entry: CreatureArtEntry = art.entry(data.id) if art != null else CreatureArtEntry.new()
	var state: StringName = _state_name(creature)
	_anim.observe(creature.position, delta)
	var animation: StringName = _anim.update(frames, entry, state, creature.facing, delta)
	if animation.is_empty():
		_show_nothing()
		return
	if sprite.sprite_frames != frames:
		sprite.sprite_frames = frames
	sprite.visible = true
	if sprite.animation != animation or (not sprite.is_playing() and frames.get_animation_loop(animation)):
		sprite.play(animation)
	sprite.flip_h = CreatureAnim.flipped(animation, creature.facing)
	_place(entry, state, frames.get_frame_texture(animation, 0).get_size().y)


# The look node 1 px south while perched; the sprite's feet on the foot line, lifted in the air or
# on the perch; the shadow on the ground; the water line for a water creature.
func _place(entry: CreatureArtEntry, state: StringName, frame_height: float) -> void:
	var perched: bool = not entry.perch_state.is_empty() and state == entry.perch_state
	var airborne: bool = entry.airborne_states.has(String(state))
	position = Vector2(0.0, PERCH_SORT_PX if perched else 0.0)
	var feet: float = -entry.perch_lift_px if perched else entry.foot_px - (entry.air_lift_px if airborne else 0.0)
	sprite.position = Vector2(0.0, feet - frame_height / 2.0 - position.y)
	shadow.visible = entry.has_shadow and not perched and not entry.water_line
	if shadow.size != entry.shadow_size:
		shadow.size = entry.shadow_size
	shadow.position = Vector2(0.0, entry.shadow_y_px - position.y)
	if not entry.water_line:
		sprite.material = null
		return
	var water := sprite.material as ShaderMaterial
	if water == null:
		water = ShaderMaterial.new()
		water.shader = WATERLINE_SHADER
		sprite.material = water
	water.set_shader_parameter(&"water_line_y", entry.water_line_px - frame_height / 2.0)


func _show_nothing() -> void:
	sprite.visible = false
	shadow.visible = false


# The creature's synced state as the brain names it, in lower case; &"" without a brain.
func _state_name(creature: Creature) -> StringName:
	if creature.brain == null:
		return &""
	var names: Array[StringName] = creature.brain.names()
	if creature.state_id < 0 or creature.state_id >= names.size():
		return &""
	return StringName(String(names[creature.state_id]).to_lower())

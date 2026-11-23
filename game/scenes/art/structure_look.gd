class_name StructureLook
extends Node2D
## A structure's look (art-pass "Palms", "Camp structures", "Raft site and raft", "Drop shadows";
## design.md D18, D22, T6-T10): the `Look` child of a palm, fire, rain catcher, build site, raft,
## workbench or island sign, in `art_view`. Every frame it reads its structure's fields (a palm's
## coconuts, a fire's `lit`, a catcher's cups, a site's deposits, progress and `built`, a raft's
## integrity) and shows the frame StructureArt picks, standing bottom-centre on the structure's
## origin, with the shadow its kind names. It never writes the structure. Each peer draws the state
## it holds: palm coconuts, fire burn-out and rain cups are host state a client does not receive
## today, so a client's look follows its own copy (design.md D18's risk note).

const SCENE_PATH: String = "res://scenes/art/structure_look.tscn"
const NODE_NAME: StringName = &"Look"
## The fire's light reaches as far as its company (art-mood-pass D2).
const SURVIVAL_TUNING: SurvivalTuning = preload("res://resources/survival_tuning.tres")

## Read once per look; every look shares the one resource.
var data: StructureArtData = StructureArtData.standard()
## A palm's look (art-prop-polish D4): picked once from its island's layout id and its cell, and
## kept; -1 until it is drawn. A palm on no island draws today's palm, look 0.
var palm_look: int = -1
## art-mood-pass D2: a fire's light, made on its first step (other kinds never have one).
var fire_light: PointLight2D = null
var _art: ArtTuning = ArtTuning.standard()

@onready var shadow: DropShadow = $Shadow
## Palms, the workbench, the stake marker and the sign post: one frame.
@onready var still: Sprite2D = $Still
## Palm overlays, drawn over the palm in this order.
@onready var coconuts: Sprite2D = $Coconuts
@onready var nest: Sprite2D = $Nest
## Fires, rain catchers, the raft site's stages and the raft.
@onready var sprite: AnimatedSprite2D = $Sprite


## A new look, for a structure made with `new()` (its `_init` adds it, as its Interactable is).
static func create() -> StructureLook:
	var look := (load(SCENE_PATH) as PackedScene).instantiate() as StructureLook
	look.name = NODE_NAME
	return look


func _process(_delta: float) -> void:
	step()


## Draws the structure as it is now.
func step() -> void:
	var structure := get_parent()
	var kind: StringName = StructureArt.kind_of(structure)
	var site := structure as BuildSite
	var stages: SpriteFrames = data.site_frames_for(site.recipe.id) if site != null and site.recipe != null else null
	if stages != null:
		kind = StructureArt.KIND_RAFT_SITE
	still.visible = false
	coconuts.visible = false
	nest.visible = false
	sprite.visible = false
	match kind:
		StructureArt.KIND_PALM:
			_show_palm(structure as Palm)
		StructureArt.KIND_FIRE:
			_play(data.fire, StructureArt.fire_frame((structure as Fire).lit))
			_light_fire((structure as Fire).lit)
		StructureArt.KIND_RAIN_CATCHER:
			_play(data.rain_catcher, StructureArt.catcher_frame((structure as RainCatcher).cups))
		StructureArt.KIND_RAFT_SITE:
			_play(stages, StructureArt.site_stage(site.deposited, site.tags_deposited, site.progress()))
		StructureArt.KIND_RAFT:
			_play(data.raft, StructureArt.raft_frame((structure as Raft).integrity))
		StructureArt.KIND_STAKE:
			if StructureArt.site_marker_shown(site.built):
				_show_still(data.still_for(kind))
		StructureArt.KIND_WORKBENCH:
			_show_still(data.still_for(kind))
		StructureArt.KIND_SIGN:
			_show_still(data.sign_texture((structure as IslandSign).look))
	_place_shadow(kind, still.visible or sprite.visible)


## The frame shown now: the animation's name, or the kind for a one-frame structure; empty when
## nothing is drawn.
func frame() -> StringName:
	if sprite.visible:
		return sprite.animation
	if still.visible:
		return StructureArt.kind_of(get_parent())
	return StructureArt.NO_FRAME


## Where a perched gull stands on this palm, in global coordinates: the crown's nest point.
func nest_point() -> Vector2:
	return global_position + data.nest_point


## The coconuts this look draws (0 to 3).
func coconuts_drawn() -> int:
	if not coconuts.visible:
		return 0
	return data.coconut_overlays.find(coconuts.texture) + 1


# The nest is layout data: the palm's index among the island's palms in `layout.nest_palms`. A palm
# that is not on an island has no nest.
func _show_palm(palm: Palm) -> void:
	var layout := _layout_of(palm)
	if palm_look < 0:
		palm_look = 0
		if layout != null:
			var cell := Vector2i((palm.position / IslandLayout.TILE).floor())
			palm_look = StructureArt.palm_look(layout.id, cell, data.palm_look_count())
	_show_still(data.palm_texture(palm_look))
	var shown: int = StructureArt.coconuts_shown(palm.coconuts)
	if shown > 0 and shown <= data.coconut_overlays.size():
		coconuts.texture = data.coconut_overlays[shown - 1]
		coconuts.offset = still.offset
		coconuts.visible = true
	if layout != null and StructureArt.shows_nest(palm.get_index(), layout.nest_palms):
		nest.texture = data.nest
		nest.offset = still.offset
		nest.visible = true


# The island's layout, read by name: the island's script preloads the palm and raft scenes, which
# hold this look, so naming its class here would load them in a cycle.
func _layout_of(palm: Palm) -> IslandLayoutData:
	var palms := palm.get_parent()
	var island: Node = palms.get_parent() if palms != null else null
	return island.get(&"layout") as IslandLayoutData if island != null else null


func _show_still(texture: Texture2D) -> void:
	if texture == null:
		return
	still.texture = texture
	still.offset = StructureArt.frame_offset(texture.get_size())
	still.visible = true


func _play(frames: SpriteFrames, animation: StringName) -> void:
	if frames == null or animation == StructureArt.NO_FRAME or not frames.has_animation(animation):
		return
	if sprite.sprite_frames != frames:
		sprite.sprite_frames = frames
	if sprite.animation != animation or not sprite.is_playing():
		sprite.play(animation)
	sprite.offset = StructureArt.frame_offset(frames.get_frame_texture(animation, 0).get_size())
	sprite.visible = true


# art-mood-pass D2 (owner Q13 (a)): a lit fire lights a pool of hard rings exactly as far as its
# company reaches, scaled by how dark the sky's tint is (none by day) and flickering with the flame's
# frame through the art tuning's table, held at the table's mean under "Reducir destellos". Embers
# give no light. Drawing only.
func _light_fire(lit: bool) -> void:
	if fire_light == null:
		fire_light = PointLight2D.new()
		fire_light.name = "FireLight"
		fire_light.blend_mode = Light2D.BLEND_MODE_ADD
		fire_light.shadow_enabled = false
		fire_light.texture_scale = 1.0
		fire_light.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		fire_light.color = _art.fire_light_color
		fire_light.texture = FireGlow.texture(FireGlow.radius_px(SURVIVAL_TUNING.company_radius_tiles), _art.fire_ring_values)
		add_child(fire_light)
	var dark: float = darkness(WeatherManager.sky)
	fire_light.visible = lit and dark > 0.0
	if not fire_light.visible:
		return
	fire_light.energy = _art.fire_light_energy * dark * _flicker()


## How dark `sky`'s tint is now, from 0 (as bright as day) to 1 (as dark as a calm night).
static func darkness(sky: WorldSky) -> float:
	if sky == null:
		return 0.0
	var night: Color = sky.tuning.phase_tints[DataEnums.DayPhase.NIGHT]
	var full: float = 1.0 - night.get_luminance()
	if full <= 0.0:
		return 0.0
	return clampf((1.0 - sky.tint().get_luminance()) / full, 0.0, 1.0)


# The flicker factor of the flame's current frame, or the table's mean held steady.
func _flicker() -> float:
	var table: PackedFloat32Array = _art.fire_flicker
	if table.is_empty():
		return 1.0
	if HurtCues.reduce_flashes:
		var total: float = 0.0
		for factor: float in table:
			total += factor
		return total / table.size()
	return table[posmod(sprite.frame, table.size())]


func _place_shadow(kind: StringName, drawn: bool) -> void:
	var size: int = data.shadows.get(kind, -1)
	shadow.visible = drawn and size >= 0
	if not shadow.visible:
		return
	if shadow.size != size:
		shadow.size = size as DropShadow.Size
	shadow.position = data.shadow_offsets.get(kind, Vector2.ZERO)

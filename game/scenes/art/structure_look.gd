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

## Read once per look; every look shares the one resource.
var data: StructureArtData = StructureArtData.standard()

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
		StructureArt.KIND_RAIN_CATCHER:
			_play(data.rain_catcher, StructureArt.catcher_frame((structure as RainCatcher).cups))
		StructureArt.KIND_RAFT_SITE:
			_play(stages, StructureArt.site_stage(site.deposited, site.tags_deposited, site.progress()))
		StructureArt.KIND_RAFT:
			_play(data.raft, StructureArt.raft_frame((structure as Raft).integrity))
		StructureArt.KIND_STAKE:
			if StructureArt.site_marker_shown(site.built):
				_show_still(data.still_for(kind))
		StructureArt.KIND_WORKBENCH, StructureArt.KIND_SIGN:
			_show_still(data.still_for(kind))
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
	_show_still(data.palm)
	var shown: int = StructureArt.coconuts_shown(palm.coconuts)
	if shown > 0 and shown <= data.coconut_overlays.size():
		coconuts.texture = data.coconut_overlays[shown - 1]
		coconuts.offset = still.offset
		coconuts.visible = true
	var layout := _layout_of(palm)
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


func _place_shadow(kind: StringName, drawn: bool) -> void:
	var size: int = data.shadows.get(kind, -1)
	shadow.visible = drawn and size >= 0
	if not shadow.visible:
		return
	if shadow.size != size:
		shadow.size = size as DropShadow.Size
	shadow.position = data.shadow_offsets.get(kind, Vector2.ZERO)

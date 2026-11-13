class_name CrossingSea
extends Polygon2D
## The crossing's sea (art-pass "Crossing look"; design.md D12, T18, T19): the islands' sea shader
## on a rect round the crossing's sea, every cell the deep step, moved down by the crossing's
## `scroll_px()` so the open water passes under the vessel. The scroll wraps at two lengths of the
## water texture, so the wrap never shows. It only reads its parent, every frame, the same on every
## peer; it is `Sea` in crossing.tscn, at z -40.

const SEA_SHADER: Shader = preload("res://scenes/art/sea/world_sea.gdshader")

## The depth step of every cell of the crossing's sea, row-major: all deep.
var depth_bytes: PackedByteArray = PackedByteArray()

var _built_for: Rect2 = Rect2()


func _init() -> void:
	add_to_group(&"art_view")


func _ready() -> void:
	_follow()


func _process(_delta: float) -> void:
	_follow()


func _follow() -> void:
	var crossing := get_parent() as Crossing
	if crossing == null:
		return
	var rect: Rect2 = crossing.sea_rect()
	if rect != _built_for:
		_build(rect)
	position = Vector2(0.0, crossing.scroll_px())


# The rect over the sea and the margin TerrainView gives an island, so a camera at the sea's edge
# still sees water; a mask whose texels are all deep (both channels 0), as TerrainView builds it.
func _build(rect: Rect2) -> void:
	_built_for = rect
	var area: Rect2 = rect.grow(TerrainView.SEA_MARGIN_PX)
	polygon = PackedVector2Array([area.position, Vector2(area.end.x, area.position.y), area.end, Vector2(area.position.x, area.end.y)])
	var art: TerrainArtData = TerrainArt.data()
	var deep: int = art.depth_steps[DataEnums.Terrain.DEEP]
	var cells: Vector2i = Crossing.SEA_TILES
	depth_bytes = PackedByteArray()
	depth_bytes.resize(cells.x * cells.y)
	depth_bytes.fill(deep)
	var sea := ShaderMaterial.new()
	sea.shader = SEA_SHADER
	TerrainView.setup_sea(sea, depth_bytes, cells, Crossing.TILE_PX)
	material = sea

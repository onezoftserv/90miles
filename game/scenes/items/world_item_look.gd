class_name WorldItemLook
extends Node2D
## How a pick-up is drawn (art-pass "Item icons" and "Drop shadows"; design.md D17, K6, K7, K8):
## its item's 16x16 icon centred on the pick-up and raised 3 px (5 px for an icon under 8 px
## tall), over the 8x4 shadow. Drawing only (`art_view`, set in world_item.tscn): every frame it
## reads the pick-up's item id and writes nothing back. While `concealed` neither icon nor shadow
## shows. secret-cay will set it; nothing does yet, and it is separate from
## Interactable.hides_contents, which only words the prompt.

## SPD's perspective raise, scaled to 16 px icons.
const RAISE_PX: float = 3.0
## Raise of a flat icon, one under SHORT_ICON_PX tall.
const SHORT_RAISE_PX: float = 5.0
const SHORT_ICON_PX: int = 8

## Hides icon and shadow (a pick-up another capability conceals).
@export var concealed: bool = false:
	set(value):
		concealed = value
		_show()

var _item_id: StringName = &""
var _item: ItemData = null
var _texture: Texture2D = null
var _raise: float = RAISE_PX

@onready var icon: Sprite2D = $Icon
@onready var shadow: Sprite2D = $Shadow


## How far `texture` is raised: SHORT_RAISE_PX when its opaque pixels are under SHORT_ICON_PX tall.
static func raise_for(texture: Texture2D) -> float:
	if texture == null:
		return RAISE_PX
	var image: Image = texture.get_image()
	if image == null:
		return RAISE_PX
	return SHORT_RAISE_PX if image.get_used_rect().size.y < SHORT_ICON_PX else RAISE_PX


func _ready() -> void:
	_show()


func _process(_delta: float) -> void:
	_show()


func _show() -> void:
	if not is_node_ready():
		return
	var item_id: StringName = get_parent().get(&"item_id")
	if item_id != _item_id:
		_item_id = item_id
		_item = GameState.content.get_entry(&"items", item_id) as ItemData
	var texture: Texture2D = _item.sprite if _item != null else null
	if texture != _texture:
		_texture = texture
		_raise = raise_for(texture)
	icon.texture = _texture
	icon.position = Vector2(0.0, -_raise)
	var shown: bool = _texture != null and not concealed
	icon.visible = shown
	shadow.visible = shown

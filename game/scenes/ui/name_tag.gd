class_name NameTag
extends Node2D
## ui-shell "HUD layout": a teammate's name and a thin health strip over their head, shown only
## while their health is not full (Shattered Pixel Dungeon and DCSS overhead bars). Every frame it
## follows its player's head anchor (art-pass "Head anchor"; design.md P4): its origin 2 px above
## the anchor, so the 1 px strip under the origin ends on the anchor and covers no hair.

## The origin sits this far above the player's head anchor.
const ANCHOR_GAP_PX: float = 2.0
## The label's top below the origin, as name_tag.tscn places it.
const LABEL_TOP_PX: float = -9.0
const STRIP_WIDTH: float = 16.0
const LOOK_NAME: StringName = &"BodyLook"

## Set again when the name reaches the host after the spawn (a join during the run).
var player_name: String = "":
	set(value):
		player_name = value
		if label != null:
			label.text = player_name
var meters: SurvivalMeters

@onready var label: Label = $Label
@onready var _fill: ColorRect = $Strip/Fill


## The top of the label of `player`'s tag as placed on its current anchor, in the player's own
## pixels, whether the tag shows or not (the interact prompt sits above it; design.md P5).
static func label_top_over(player: Node) -> float:
	var look := player.get_node_or_null(NodePath(LOOK_NAME)) as BodyLook
	var anchor: float = look.head_anchor_y() if look != null else 0.0
	return anchor - ANCHOR_GAP_PX + LABEL_TOP_PX


func _ready() -> void:
	label.text = player_name
	refresh()


func _process(_delta: float) -> void:
	refresh()


func refresh() -> void:
	if get_parent() != null:
		position = Vector2(0.0, label_top_over(get_parent()) - LABEL_TOP_PX)
	if meters == null:
		return
	var health: float = meters.health
	visible = health < SurvivalMeters.MAX_VALUE
	_fill.size.x = STRIP_WIDTH * clampf(health / SurvivalMeters.MAX_VALUE, 0.0, 1.0)

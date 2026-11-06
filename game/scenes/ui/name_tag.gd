class_name NameTag
extends Node2D
## ui-shell "HUD layout": a teammate's name and a thin health strip over their head, shown only
## while their health is not full (Shattered Pixel Dungeon and DCSS overhead bars).

const OFFSET: Vector2 = Vector2(0.0, -22.0)
const STRIP_WIDTH: float = 16.0

## Set again when the name reaches the host after the spawn (a join during the run).
var player_name: String = "":
	set(value):
		player_name = value
		if label != null:
			label.text = player_name
var meters: SurvivalMeters

@onready var label: Label = $Label
@onready var _fill: ColorRect = $Strip/Fill


func _ready() -> void:
	position = OFFSET
	label.text = player_name
	refresh()


func _process(_delta: float) -> void:
	refresh()


func refresh() -> void:
	if meters == null:
		return
	var health: float = meters.health
	visible = health < SurvivalMeters.MAX_VALUE
	_fill.size.x = STRIP_WIDTH * clampf(health / SurvivalMeters.MAX_VALUE, 0.0, 1.0)

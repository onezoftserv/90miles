class_name Workbench
extends Node2D
## A flat rock or a wreck table the level places (crafting-inventory "Workbench"): a player
## within 1 tile can craft workbench recipes here. It only marks the spot; Crafter does the work.

const SIZE: Vector2 = Vector2(14.0, 8.0)


func _draw() -> void:
	draw_rect(Rect2(-SIZE / 2.0, SIZE), Color(0.45, 0.33, 0.2))

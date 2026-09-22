extends Node2D

func _draw() -> void:
	get_parent()._draw_background(self)

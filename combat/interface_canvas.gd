extends Node2D
## Menus and ability buttons stay above both threats and scene postprocessing.
func _draw() -> void:
	get_parent().get_parent()._draw_ui(self)

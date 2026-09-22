extends Node2D
## The composition root supplies a renderer; hierarchy is not part of the API.
var render: Callable

func _draw() -> void:
	render.call(self)

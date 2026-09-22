extends Node2D
var game: Node2D
## Hostile projectiles are composited after environment glow.
func _draw() -> void:
	if game.state == game.GameState.TITLE:
		return
	for bullet in game.enemy_bullets:
		game._draw_enemy_bullet(bullet, self)

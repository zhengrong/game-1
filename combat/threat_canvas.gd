extends Node2D
## Hostile projectiles are composited after environment glow.
func _draw() -> void:
	var game = get_parent().get_parent()
	if game.state == game.GameState.TITLE:
		return
	for bullet in game.enemy_bullets:
		game._draw_enemy_bullet(bullet, self)

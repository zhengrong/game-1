extends SceneTree
## Headless CPU microbenchmark; excludes rendering and fixture construction.
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	for count in [500, 4000]:
		for expire in [false, true]:
			var samples: Array[int] = []
			for repeat in range(35):
				game.particles.clear()
				for i in range(count):
					game.particles.append({"kind": "fire", "pos": Vector2(100, 100), "vel": Vector2.ZERO,
						"life": 0.001 if expire and i % 2 == 0 else 1.0, "max_life": 1.0,
						"size": 20.0, "growth": 5.0, "drag": 0.1})
				var start := Time.get_ticks_usec()
				game._update_particles(1.0 / 60.0)
				var duration := Time.get_ticks_usec() - start
				if repeat >= 5:
					samples.append(duration)
			samples.sort()
			print("particles=%d half_expire=%s median_us=%d" % [count, expire, samples[samples.size() / 2]])
	game.free()
	quit()

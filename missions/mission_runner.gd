extends RefCounted
## Schedules content and tracks encounter-owned enemies. No game or renderer dependency.
const Mission = preload("res://missions/mission_definition.gd")
const Stage = preload("res://missions/stage_definition.gd")
signal spawn_requested(definition: Resource, x_fraction: float, token: int)
signal stage_started(index: int)
signal stage_cleared
signal completed
signal failed
var mission: Mission
var stage_index: int = -1
var waiting: float = 0.0
var stage_time: float = 0.0
var spawned: int = 0
var finished: bool = false
var transitioning: bool = true
var counts: Array[int] = []
var active: Dictionary = {}
var next_token: int = 0

func reset(definition: Mission) -> void:
	mission = definition
	stage_index = -1
	waiting = maxf(0.0, mission.initial_delay)
	stage_time = 0.0
	spawned = 0
	finished = false
	transitioning = true
	counts.clear()
	active.clear()
	# Tokens never repeat across restarts, so stale removals cannot affect a new run.

func advance(delta: float) -> void:
	if finished:
		return
	if transitioning:
		waiting -= maxf(0.0, delta)
		if waiting <= 0.0:
			begin_stage()
		return
	stage_time += maxf(0.0, delta)
	var stage: Stage = mission.stages[stage_index]
	# Merge group timelines so hitches preserve cross-group spawn/RNG order.
	while true:
		var selected := -1
		var next_time := INF
		for i in range(stage.groups.size()):
			var candidate = stage.groups[i]
			var due: float = candidate.start_time + counts[i] * candidate.interval
			if counts[i] < candidate.count and due <= stage_time + 0.000001 and due < next_time:
				selected = i
				next_time = due
		if selected < 0:
			break
		var group = stage.groups[selected]
		var ordinal := counts[selected]
		counts[selected] += 1
		spawned += 1
		next_token += 1
		active[next_token] = true
		spawn_requested.emit(group.enemies[ordinal % group.enemies.size()], group.formation[ordinal % group.formation.size()], next_token)

func begin_stage() -> void:
	stage_index += 1
	if stage_index >= mission.stages.size():
		finished = true
		completed.emit()
		return
	transitioning = false
	waiting = 0.0
	stage_time = 0.0
	spawned = 0
	counts.clear()
	counts.resize(mission.stages[stage_index].groups.size())
	counts.fill(0)
	stage_started.emit(stage_index)

func enemy_removed(token: int, defeated: bool) -> void:
	if not active.has(token):
		return
	active.erase(token)
	if not defeated and mission.stages[stage_index].completion == Stage.Completion.DEFEAT_ALL:
		finished = true
		failed.emit()

func check_completion() -> void:
	if finished or transitioning or not active.is_empty():
		return
	var stage: Stage = mission.stages[stage_index]
	for i in range(stage.groups.size()):
		if counts[i] < stage.groups[i].count:
			return
	if stage_index == mission.stages.size() - 1:
		finished = true
		completed.emit()
	else:
		transitioning = true
		waiting = maxf(0.0, stage.transition_delay)
		stage_cleared.emit()

extends GutTest
const State = preload("res://ships/ship_state.gd")
const Definition = preload("res://ships/ship_definition.gd")
const DEFAULT = preload("res://ships/interceptor.tres")
const BULWARK = preload("res://ships/bulwark.tres")

func test_ship_states_do_not_share_runtime_data() -> void:
	var first := State.new()
	var second := State.new()
	first.reset(DEFAULT)
	second.reset(DEFAULT)
	first.health = 1
	first.aura_energy = 0.0
	first.weapon.start_beam()
	assert_eq(second.health, 3)
	assert_eq(second.aura_energy, 100.0)
	assert_eq(second.weapon.beam_visible_timer, 0.0)
	assert_eq(DEFAULT.health, 3)
	first.reset(BULWARK)
	assert_eq(first.health, 5)
	assert_eq(first.aura_energy, 140.0)
	assert_eq(first.nova_energy, 24.0)
	assert_eq(first.weapon.beam_visible_timer, 0.0)
	assert_eq(first.weapon.config.twin_damage, 32.0)

func test_new_definitions_own_separate_configuration_resources() -> void:
	var first := Definition.new()
	var second := Definition.new()
	first.weapon.twin_damage = 99.0
	first.abilities.aura_capacity = 55.0
	first.engines.scale = 2.0
	assert_eq(second.weapon.twin_damage, 24.0)
	assert_eq(second.abilities.aura_capacity, 100.0)
	assert_eq(second.engines.scale, 1.0)

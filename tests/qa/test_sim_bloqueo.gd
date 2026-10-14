extends GutTest
## V2-41 (QA): definición de "bloqueo" de tools/sim.gd (>= 3 rondas cerradas seguidas sin
## PLAY_CARD, REACT, USE_ARTIFACT ni daño). Prueba la función estática del simulador.

const SIM = preload("res://tools/sim.gd")


func test_no_idle_rounds() -> void:
	var r: Dictionary = SIM.block_stats([1, 2, 1, 3], [0, 0, 1, 0], 4)
	assert_eq(int(r["blocked_rounds"]), 0)
	assert_eq(int(r["max_run"]), 0)


func test_two_idle_rounds_are_not_a_block() -> void:
	var r: Dictionary = SIM.block_stats([1, 0, 0, 2, 1], [0, 0, 0, 0, 0], 5)
	assert_eq(int(r["blocked_rounds"]), 0)
	assert_eq(int(r["max_run"]), 2)


func test_three_idle_rounds_are_a_block() -> void:
	var r: Dictionary = SIM.block_stats([1, 0, 0, 0, 2], [0, 0, 0, 0, 0], 5)
	assert_eq(int(r["blocked_rounds"]), 3)
	assert_eq(int(r["runs"]), 1)
	assert_eq(int(r["first_block_round"]), 2, "1-based")


func test_damage_breaks_the_run_and_two_runs_add_up() -> void:
	# rondas: jugada, 3 inactivas, daño, 4 inactivas, jugada
	var plays: Array = [1, 0, 0, 0, 0, 0, 0, 0, 0, 1]
	var dmg: Array = [0, 0, 0, 0, 1, 0, 0, 0, 0, 0]
	var r: Dictionary = SIM.block_stats(plays, dmg, 10)
	assert_eq(int(r["blocked_rounds"]), 7)
	assert_eq(int(r["runs"]), 2)
	assert_eq(int(r["max_run"]), 4)


func test_open_round_at_the_end_is_not_counted() -> void:
	# 3 rondas cerradas inactivas y la 4.ª (la última, abierta) sin datos: closed = 3 -> la racha llega al final.
	var r: Dictionary = SIM.block_stats([0, 0, 0, 0], [0, 0, 0, 0], 3)
	assert_eq(int(r["blocked_rounds"]), 3)
	var r2: Dictionary = SIM.block_stats([0, 0, 0], [0, 0, 0], 2)
	assert_eq(int(r2["blocked_rounds"]), 0, "solo 2 rondas cerradas")

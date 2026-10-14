extends GutTest
## V2-26c: pantalla de fin (GameOverSummary + TableGameOver) y "Jugar otra vez".
## Casos C8-9, C8-10, C8-11 de docs/diseno/criterios-v02.md.

var _prev_handler: Callable
var _prev_setup: Dictionary


func before_each() -> void:
	FakeState.install_defs()
	_prev_handler = UiNav.replay_handler
	_prev_setup = UiNav.last_setup
	UiNav.replay_handler = func(_t: SceneTree) -> void: pass


func after_each() -> void:
	UiNav.replay_handler = _prev_handler
	UiNav.last_setup = _prev_setup


## Vista terminada con n magos: p1 gana (o empate si `tie`), el resto cae por orden.
func _finished_view(n: int, tie: bool = false) -> Dictionary:
	var v: Dictionary = FakeState.make_view(n, "p1")
	v["status"] = Types.STATUS_FINISHED
	v["winners"] = [] if tie else ["p1"]
	var players: Array = v["players"]
	for i: int in players.size():
		var p: Dictionary = players[i]
		if i == 0 and not tie:
			continue
		p["eliminated"] = true
		p["hp"] = 0
		p["eliminated_reason"] = Types.ELIM_HP
		p["eliminated_order"] = 1 if tie else n - i
		p["turns_played"] = 3 + i
	return v


func _table(v: Dictionary) -> TableScreen:
	var t: TableScreen = (load("res://src/ui/screens/table.tscn") as PackedScene).instantiate()
	t.demo_when_empty = false
	add_child_autofree(t)
	t.set_view(v, "p1")
	return t


func test_summary_has_one_row_per_player_and_scrolls() -> void:
	var t: TableScreen = _table(_finished_view(6))
	await wait_process_frames(2)
	var go: TableGameOver = t.ctx.game_over
	assert_true(go.is_result_open())
	assert_eq(go.summary_view.row_nodes.size(), 6)
	assert_not_null(go.summary_view.scroll)
	assert_true(go.summary_view.all_text().contains(String(go.summary()["title"])))
	for row: Variant in go.summary()["rows"]:
		assert_true(go.summary_view.all_text().contains(String((row as Dictionary)["text"])))
	assert_false(go.summary_view.all_text().contains("_"), "sin claves internas")


func test_tie_shows_subtitle() -> void:
	var t: TableScreen = _table(_finished_view(4, true))
	await wait_process_frames(2)
	var sv: GameOverSummary = t.ctx.game_over.summary_view
	assert_true(sv.subtitle_label.visible)
	assert_eq(sv.subtitle_label.text, String(t.ctx.game_over.summary()["subtitle"]))


## C8-9: "Jugar otra vez" visible en victoria, derrota y empate; principal (144 px a 1080).
func test_play_again_visible_and_primary_in_win_loss_tie() -> void:
	for mode: String in ["win", "loss", "tie"]:
		var v: Dictionary = _finished_view(4, mode == "tie")
		if mode == "loss":
			v["winners"] = ["p2"]
			for p: Variant in (v["players"] as Array):
				var pd: Dictionary = p
				pd["eliminated"] = String(pd["id"]) != "p2"
		var t: TableScreen = _table(v)
		await wait_process_frames(2)
		var b: Button = t.ctx.game_over.play_again_button
		assert_true(b.is_visible_in_tree(), "visible en " + mode)
		assert_gte(b.custom_minimum_size.y, 144.0, "alto mínimo principal en " + mode)
		assert_gte(b.size.y, 144.0, "alto real en " + mode)
		assert_eq(b.theme_type_variation, UiTheme.VARIATION_PRIMARY)
		assert_lt(t.ctx.game_over.see_table_button.custom_minimum_size.y, 144.0, "el resto es secundario")


func test_play_again_hidden_without_replay_handler() -> void:
	UiNav.replay_handler = Callable()
	var t: TableScreen = _table(_finished_view(4))
	await wait_process_frames(2)
	assert_false(t.ctx.game_over.play_again_button.visible)


func test_play_again_button_triggers_replay_once() -> void:
	var calls: Array[int] = [0]
	UiNav.replay_handler = func(_t: SceneTree) -> void: calls[0] += 1
	var t: TableScreen = _table(_finished_view(4))
	await wait_process_frames(2)
	t.ctx.game_over.play_again_button.pressed.emit()
	assert_eq(calls[0], 1)
	assert_false(t.ctx.game_over.is_result_open())


## C8-9 / C8-10: mismos jugadores y opciones, semilla nueva.
func test_replay_keeps_players_and_options_with_new_seed() -> void:
	for cfg: Dictionary in [{"potion_limit_enabled": false}, {"potion_limit_enabled": true, "potion_limit": 6}]:
		var setup: Dictionary = {
			"players": [
				{"name": "Ana", "age": 30, "birth_month": 3, "is_bot": false},
				{"name": "Bruno", "age": 25, "birth_month": 7, "is_bot": true},
				{"name": "Cira", "age": 41, "birth_month": 12, "is_bot": true}],
			"config": cfg, "seed": 12345}
		UiNav.last_setup = setup.duplicate(true)
		var again: Dictionary = UiNav.replay_setup()
		assert_eq(again["players"], setup["players"])
		assert_eq(again["config"], setup["config"])
		assert_ne(int(again["seed"]), 12345, "semilla nueva")
		assert_eq(UiNav.last_setup["seed"], 12345, "no muta la configuración guardada")
		var ls: LocalSession = LocalSession.create(again)
		add_child_autofree(ls)
		var st: Dictionary = ls.state
		assert_eq((st["config"] as Dictionary).get("potion_limit_enabled"), cfg["potion_limit_enabled"])
		assert_eq((st["players"] as Array).size(), 3)
		assert_eq(int(((st["players"] as Array)[0] as Dictionary)["hp"]), 10)
		assert_eq(int((st["turn"] as Dictionary)["number"]), 1)


func test_replay_without_prior_seed_gets_one() -> void:
	UiNav.last_setup = {"players": [], "config": {}}
	assert_true(UiNav.replay_setup().has("seed"))


## C8-11: "Ver la mesa" cierra, "Ver resultado" reabre el mismo resumen; "Volver al menú" sin errores.
func test_see_result_reopens_same_summary() -> void:
	var t: TableScreen = _table(_finished_view(6))
	await wait_process_frames(2)
	var go: TableGameOver = t.ctx.game_over
	var before: String = go.summary_view.all_text()
	assert_false(go.see_result_button.visible)
	go.see_table_button.pressed.emit()
	assert_false(go.is_result_open())
	assert_true(go.see_result_button.visible)
	assert_gte(go.see_result_button.custom_minimum_size.y, float(UiTheme.BUTTON_MIN_H))
	assert_lt(go.see_result_button.custom_minimum_size.y, 144.0, "secundario")
	go.see_result_button.pressed.emit()
	assert_true(go.is_result_open())
	assert_false(go.see_result_button.visible)
	assert_eq(go.summary_view.all_text(), before)
	assert_true(t.is_game_over_shown())


func test_menu_button_leaves_via_menu_exit() -> void:
	var t: TableScreen = _table(_finished_view(4))
	await wait_process_frames(2)
	var go: TableGameOver = t.ctx.game_over
	assert_true(go.menu_button.is_visible_in_tree())
	assert_eq(go.menu_button.text, Strings.BUTTON_BACK_TO_MENU)
	# La mesa de la prueba no cuelga del árbol principal: el botón no debe fallar al cerrarse.
	go.menu_button.pressed.emit()
	assert_false(go.is_result_open())

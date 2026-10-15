extends GutTest
## T8: mesa (TableScreen) + LocalSession con el motor real. Acciones simuladas
## pulsando la UI: jugar una ofensiva, responder con una defensiva, beber
## poción fuera de turno, temporizador de reacción, avisos, Magic Hand y una
## partida completa (1 humano scriptado + 2 bots) hasta la victoria.

const H = preload("res://tests/fixtures/engine_helpers.gd")
const Driver = preload("res://tests/integration/local_ui_driver.gd")

var _now: int = 5_000_000
var _errors: Array[String] = []


func before_all() -> void:
	CardCatalog.load_json()
	EffectRegistry.reset()


func before_each() -> void:
	UiUtil.prefer_extra = false
	_errors.clear()


## Deja que se liberen los nodos de la UI encolados con queue_free.
func after_each() -> void:
	await wait_process_frames(2)


func _clock() -> int:
	return _now


func _table() -> TableScreen:
	var t: TableScreen = (load("res://src/ui/screens/table.tscn") as PackedScene).instantiate()
	add_child_autofree(t)
	return t


## p1 humano, p2 y p3 bots (o humanos si hot_seat). Manos fijas, 6 de maná.
func _session(turn_pid: String, hands: Dictionary, cfg: Dictionary = {}, humans: int = 1) -> LocalSession:
	var players: Array = []
	for i: int in 3:
		players.append(Types.make_player("p%d" % (i + 1), ["Ana", "Bruno", "Cira"][i], 40 - i * 10, i + 1, i >= humans))
	var s: Dictionary = Game.new_game(players, cfg, 99)
	for pid: String in ["p1", "p2", "p3"]:
		H.set_hand(s, pid, hands.get(pid, []) as Array)
		H.set_mana(s, pid, 6)
	H.force_turn(s, turn_pid)
	var ls: LocalSession = LocalSession.new()
	ls.auto_run_bots = false
	ls.clock = _clock
	ls.start(s, 3)
	ls.error.connect(func(code: String, a: Dictionary) -> void: _errors.append("%s %s" % [code, JSON.stringify(a)]))
	return ls


func _iid(ls: LocalSession, pid: String, card_id: String) -> int:
	for c: Variant in H.hand(ls.state, pid):
		if String((c as Dictionary)["card_id"]) == card_id:
			return int((c as Dictionary)["iid"])
	return -1


func test_play_offensive_with_payment_and_target() -> void:
	var ls: LocalSession = _session("p1", {"p1": [Types.CARD_FIREBALL, Types.CARD_FIRE_ARROW, Types.CARD_HEAL]})
	var t: TableScreen = _table()
	t.bind_session(ls)
	var fb: int = _iid(ls, "p1", Types.CARD_FIREBALL)
	var arrow: int = _iid(ls, "p1", Types.CARD_FIRE_ARROW)
	var heal: int = _iid(ls, "p1", Types.CARD_HEAL)
	t._on_hand_tapped({"iid": fb})
	assert_false(t._play_btn.disabled, "Fireball se puede jugar")
	t._play_btn.pressed.emit()
	assert_eq(t._step, TableScreen.Step.TARGETS)
	assert_false(t._allowed().is_empty())
	t._on_panel_tapped("p2")
	assert_eq(t._step, TableScreen.Step.PAYMENT, "pide pago")
	t._on_hand_tapped({"iid": heal})
	assert_eq(t._selected, [arrow] as Array[int], "Heal no sirve para pagar; Fire Arrow ya va preseleccionada (V2-24)")
	assert_false(t._mode_confirm.disabled)
	t._mode_confirm.pressed.emit()
	assert_eq(_errors, [] as Array[String])
	assert_eq(int(Types.get_player(ls.state, "p2")["hp"]), 8, "Fireball: 2 de daño a p2")
	assert_eq(int(Types.get_player(ls.state, "p1")["mana"]), 5)
	assert_eq(_iid(ls, "p1", Types.CARD_FIRE_ARROW), -1, "Fire Arrow pagada")


func test_illegal_is_disabled_and_explained() -> void:
	var ls: LocalSession = _session("p1", {"p1": [Types.CARD_FIREBALL, Types.CARD_MAGIC_SHIELD]})
	var t: TableScreen = _table()
	t.bind_session(ls)
	t._on_hand_tapped({"iid": _iid(ls, "p1", Types.CARD_FIREBALL)})
	assert_true(t._play_btn.disabled, "sin carta de fuego para pagar")
	assert_true(t._hint.visible)
	assert_string_contains(t._hint.text, "pagar")
	t._on_hand_tapped({"iid": _iid(ls, "p1", Types.CARD_FIREBALL)})
	t._on_hand_tapped({"iid": _iid(ls, "p1", Types.CARD_MAGIC_SHIELD)})
	assert_true(t._play_btn.disabled, "defensiva fuera de reacción")
	assert_string_contains(t._hint.text, "defensiva")
	assert_false(t._discard_btn.disabled, "descartar sí es legal")
	assert_false(t._exchange_btn.disabled)
	t._exchange_btn.pressed.emit()
	assert_eq(_errors, [] as Array[String])
	assert_eq(int((ls.state["turn"] as Dictionary)["exchanges"]), 1)


func test_respond_with_defensive_from_reaction_modal() -> void:
	var ls: LocalSession = _session("p2", {"p1": [Types.CARD_MAGIC_SHIELD], "p2": [Types.CARD_FIRE_ARROW]})
	var t: TableScreen = _table()
	t.bind_session(ls)
	assert_false(t._reaction_overlay.visible)
	ls._enqueue(Types.make_action_play_card("p2", _iid(ls, "p2", Types.CARD_FIRE_ARROW), ["p1"]), "bot")
	assert_true(t._reaction_overlay.visible, "modal de reacción para p1")
	assert_eq(t.options().reactable_iids(), [_iid(ls, "p1", Types.CARD_MAGIC_SHIELD)] as Array[int])
	t._reaction.react_requested.emit(_iid(ls, "p1", Types.CARD_MAGIC_SHIELD))
	assert_eq(t._step, TableScreen.Step.TARGETS, "Magic Shield: elegir a quién protege")
	assert_false(t._reaction_overlay.visible)
	t._on_panel_tapped("p1")
	assert_eq(_errors, [] as Array[String])
	ls.run_bots(10)
	assert_true((ls.state["reaction"] as Dictionary).is_empty(), "ventana cerrada")
	assert_eq(int(Types.get_player(ls.state, "p1")["hp"]), 10, "Magic Shield evita el daño")
	var reacted: bool = false
	for h: Dictionary in ls.history:
		if String((h["action"] as Dictionary)["type"]) == Types.ACTION_REACT and String(h["error"]) == "":
			reacted = true
	assert_true(reacted)


func test_drink_potion_out_of_turn_and_during_reaction() -> void:
	var ls: LocalSession = _session("p2", {"p1": [Types.CARD_MAGIC_SHIELD], "p2": [Types.CARD_FIRE_ARROW]},
		{"potion_limit": 2})
	var t: TableScreen = _table()
	t.bind_session(ls)
	assert_false(t._drink_btn.disabled, "beber siempre disponible")
	assert_string_contains(t._drink_btn.text, "0/2")
	t._drink_btn.pressed.emit()
	assert_eq(int(Types.get_player(ls.state, "p1")["potions"]), 1)
	assert_string_contains(t._drink_btn.text, "1/2")
	ls._enqueue(Types.make_action_play_card("p2", _iid(ls, "p2", Types.CARD_FIRE_ARROW), ["p1"]), "bot")
	assert_true(t._reaction_overlay.visible)
	t._reaction.drink_requested.emit()
	assert_eq(int(Types.get_player(ls.state, "p1")["potions"]), 2, "bebe durante la ventana")
	assert_true(t._reaction_overlay.visible, "la ventana sigue abierta")
	# La siguiente poción elimina: aviso de Too Much Mana.
	t._drink_btn.pressed.emit()
	assert_true(t._dialog_overlay.visible)
	assert_eq(t._dialog_kind, "drink_warn")
	t._on_dialog_button("drink_cancel")
	assert_eq(int(Types.get_player(ls.state, "p1")["potions"]), 2, "cancelado: no bebe")
	assert_eq(_errors, [] as Array[String])


func test_reaction_timeout_closes_modal() -> void:
	var ls: LocalSession = _session("p2", {"p1": [Types.CARD_MAGIC_SHIELD], "p2": [Types.CARD_FIRE_ARROW]},
		{"reaction_timeout_local_ms": 8000})
	var t: TableScreen = _table()
	t.bind_session(ls)
	ls._enqueue(Types.make_action_play_card("p2", _iid(ls, "p2", Types.CARD_FIRE_ARROW), ["p1"]), "bot")
	assert_true(t._reaction_overlay.visible)
	assert_eq(t._reaction.deadline_ms, _now + 8000, "barra de tiempo con el plazo")
	_now += 8001
	assert_true(ls.check_timeouts())
	assert_false(t._reaction_overlay.visible, "el modal se cierra al vencer")
	assert_eq(int(Types.get_player(ls.state, "p1")["hp"]), 9)


func test_event_notice_and_curse_of_rules_button() -> void:
	var ls: LocalSession = _session("p1", {"p1": [Types.CARD_CURSE_OF_RULES, Types.CARD_HEAL]})
	H.stack_deck(ls.state, [Types.CARD_BLESSING])
	var t: TableScreen = _table()
	t.bind_session(ls)
	var n0: int = t.pending_notices()
	assert_false(t._rule_btn.visible)
	t._on_hand_tapped({"iid": _iid(ls, "p1", Types.CARD_CURSE_OF_RULES)})
	t._play_btn.pressed.emit()
	assert_eq(t._dialog_kind, "rule", "pide el texto de la regla")
	t._dialog.text_input.text = "Nada de decir 'sí'"
	t._on_dialog_button("rule_ok")
	assert_eq(_errors, [] as Array[String])
	ls.run_bots(10)
	assert_true(t._rule_btn.visible, "botón Rompió la regla")
	t._on_break_rule()
	assert_string_contains(t._mode_label.text, "Nada de decir")
	var mana2: int = int(Types.get_player(ls.state, "p2")["mana"])
	t._on_panel_tapped("p2")
	assert_eq(int(Types.get_player(ls.state, "p2")["mana"]), mana2 - 1, "−1 maná")
	# Al terminar el turno p2 roba Blessing (evento) -> aviso.
	t._end_btn.pressed.emit()
	ls.run_bots(5)
	assert_gt(t.pending_notices(), n0, "aviso de evento")
	assert_true(t._notice_overlay.visible)
	t._on_notice_ok()


func test_magic_hand_private_choice() -> void:
	var ls: LocalSession = _session("p1", {"p1": [Types.CARD_MAGIC_HAND], "p2": [Types.CARD_HEAL, Types.CARD_FIREBALL]})
	var t: TableScreen = _table()
	t.bind_session(ls)
	t._on_hand_tapped({"iid": _iid(ls, "p1", Types.CARD_MAGIC_HAND)})
	t._play_btn.pressed.emit()
	t._on_panel_tapped("p2")
	ls.run_bots(10)
	assert_eq(_errors, [] as Array[String])
	assert_true(t._dialog_overlay.visible, "diálogo con la mano de p2")
	assert_eq(t._dialog_kind, "prompt")
	var opts: Array = t.options().of_type(Types.ACTION_CHOOSE_CARDS)
	assert_eq(opts.size(), 2, "elige entre las 2 cartas reveladas")
	var heal: int = _iid(ls, "p2", Types.CARD_HEAL)
	var chosen: Array[int] = [heal]
	t._dialog.chosen = chosen
	t._on_dialog_button("cards_ok")
	assert_eq(_errors, [] as Array[String])
	assert_eq(_iid(ls, "p1", Types.CARD_HEAL), heal, "la carta pasa a mi mano")
	# p2 no ve la revelación de p1.
	assert_true(((ls.get_view_for("p2")["reveals"] as Dictionary).get("p1", []) as Array).is_empty())


func test_hot_seat_reaction_passes_device_to_target() -> void:
	var ls: LocalSession = _session("p2", {"p1": [Types.CARD_MAGIC_SHIELD], "p2": [Types.CARD_FIRE_ARROW]}, {}, 3)
	var t: TableScreen = _table()
	t.bind_session(ls)
	await wait_process_frames(2)
	assert_true(t._pass_screen.visible, "al empezar se pasa el dispositivo a quien decide")
	assert_eq(t._pass_screen.size, t.size, "la pantalla de paso tapa toda la mesa")
	assert_eq(t._pass_screen.player_name, "Bruno")
	t._pass_screen._on_pressed()
	assert_eq(t.viewer_id, "p2")
	var arrow: int = _iid(ls, "p2", Types.CARD_FIRE_ARROW)
	t._on_hand_tapped({"iid": arrow})
	t._play_btn.pressed.emit()
	t._on_panel_tapped("p1")
	assert_eq(_errors, [] as Array[String])
	assert_true(t._pass_screen.visible, "reacción de otro humano: pasar el dispositivo")
	assert_eq(t._pass_screen.player_name, "Ana")
	assert_eq(t.viewer_id, "p2", "aún no se muestra la mano de Ana")
	t._pass_screen._on_pressed()
	assert_eq(t.viewer_id, "p1")
	assert_true(t._reaction_overlay.visible, "modal de reacción para Ana")
	t._reaction.pass_requested.emit()
	assert_true(t._pass_screen.visible, "vuelve el turno de Bruno")
	assert_eq(t._pass_screen.player_name, "Bruno")
	t._pass_screen._on_pressed()
	assert_eq(t.viewer_id, "p2")
	assert_eq(int(Types.get_player(ls.state, "p1")["hp"]), 9)


## Partida completa: el humano decide con la IA pero todo pasa por la UI.
func _play_full_game(seed_value: int, humans: int) -> Dictionary:
	var players: Array = []
	for i: int in 3:
		players.append({"name": ["Ana", "Bruno", "Cira"][i], "age": 30 + i * 5, "birth_month": i + 2,
			"is_bot": i >= humans})
	var setup: Dictionary = {"players": players, "config": {"potion_limit_enabled": true, "potion_limit": 10,
		"potion_mana": 3, "include_curse_of_rules": true, "reaction_timeout_local_ms": 0, "mode": "local"}}
	var ls: LocalSession = LocalSession.create(setup, seed_value)
	ls.auto_run_bots = false
	ls.error.connect(func(code: String, a: Dictionary) -> void: _errors.append("%s %s" % [code, JSON.stringify(a)]))
	var t: TableScreen = _table()
	t.bind_session(ls)
	var drv: Driver = Driver.new(t)
	var rng: int = Rng.seed_from(seed_value)
	var steps: int = 0
	var leaks: Array[String] = []
	for step: int in 4000:
		steps = step
		if String(ls.state["status"]) != Types.STATUS_PLAYING:
			break
		if t._pass_screen.visible:
			t._pass_screen._on_pressed()
			continue
		var d: String = Decision.local_decider(ls.state, ls.get_local_player_ids())
		if d != "":
			if t.viewer_id != d:
				leaks.append("paso %d: decide %s pero mira %s" % [step, d, t.viewer_id])
			var v: Dictionary = ls.get_view_for(d)
			var res: Dictionary = Bot.choose_action(v, d, rng, 10)
			rng = int(res["rng_state"])
			var a: Dictionary = res["action"]
			if not a.is_empty():
				drv.perform(a)
				if step % 25 == 0:
					await wait_process_frames(1)
				continue
		if ls.run_bots(1) == 0:
			fail_test("bloqueo en el paso %d" % step)
			break
		if step % 25 == 0:
			await wait_process_frames(1)
	return {"session": ls, "table": t, "driver": drv, "steps": steps, "leaks": leaks}


func test_full_game_one_human_two_bots_reaches_victory() -> void:
	var replayed: Array[int] = [0]
	var prev: Callable = UiNav.replay_handler
	UiNav.replay_handler = func(_tree: SceneTree) -> void: replayed[0] += 1
	var r: Dictionary = await _play_full_game(11, 1)
	var ls: LocalSession = r["session"]
	var t: TableScreen = r["table"]
	var drv: Driver = r["driver"]
	assert_eq(String(ls.state["status"]), Types.STATUS_FINISHED, "la partida termina (%d pasos)" % int(r["steps"]))
	assert_eq(drv.mismatches, [] as Array[String], "la UI emite exactamente las acciones elegidas")
	assert_eq(_errors, [] as Array[String], "sin errores del motor")
	assert_true(t.is_game_over_shown(), "pantalla de fin de partida")
	assert_eq(t._dialog_kind, "game_over")
	gut.p("acciones por la UI: %s" % str(drv.performed))
	t._on_dialog_button("play_again")
	assert_eq(replayed[0], 1, "Jugar otra vez")
	UiNav.replay_handler = prev


func test_full_game_three_humans_hot_seat() -> void:
	var r: Dictionary = await _play_full_game(23, 3)
	var ls: LocalSession = r["session"]
	var drv: Driver = r["driver"]
	assert_eq(String(ls.state["status"]), Types.STATUS_FINISHED, "termina (%d pasos)" % int(r["steps"]))
	assert_eq(r["leaks"], [] as Array[String], "nunca se muestra la mano de otro humano")
	assert_eq(drv.mismatches, [] as Array[String])
	assert_eq(_errors, [] as Array[String])
	assert_true((r["table"] as TableScreen).is_game_over_shown())

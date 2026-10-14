extends GutTest
## V2-27 (puerta de la oleada 2): comprobaciones independientes de QA sobre los
## criterios de "hecho" de V2-22 a V2-26c, V2-39 y V2-40. No sustituyen a los tests
## de cada tarea: se escriben desde los criterios, con escenarios propios.

const H = preload("res://tests/fixtures/engine_helpers.gd")
const X = preload("res://tests/engine/effects/t6c_helpers.gd")
const NAMES: Array = ["Ana", "Bruno", "Cira", "Dario", "Eva", "Fede"]

var _now: int = 0
var _actions: Array = []
var _prev_handler: Callable


func before_each() -> void:
	CardCatalog.load_json()
	EffectRegistry.reset()
	UiUtil.extra_defs = {}
	_actions = []
	_prev_handler = UiNav.replay_handler
	UiNav.replay_handler = func(_t: SceneTree) -> void: pass


func after_each() -> void:
	UiNav.replay_handler = _prev_handler
	await wait_process_frames(2)


func _table() -> TableScreen:
	var t: TableScreen = (load("res://src/ui/screens/table.tscn") as PackedScene).instantiate()
	t.demo_when_empty = false
	add_child_autofree(t)
	return t


func _session(n: int, sd: int, humans: int = 1) -> LocalSession:
	var players: Array = []
	for i: int in n:
		players.append(Types.make_player("p%d" % (i + 1), NAMES[i], 40 - i * 5, i + 1, i >= humans))
	var s: Dictionary = Game.new_game(players, {"log_limit": 100000, "reaction_timeout_local_ms": 15000}, sd)
	var ls: LocalSession = LocalSession.new()
	autofree(ls)
	ls.auto_run_bots = false
	ls.clock = func() -> int: return _now
	ls.start(s, sd)
	return ls


# ---------------------------------------------------------------- V2-22 feedback

## 1 feedback por entrada pública de daño/curación/maná/poción; sin refresh();
## y un número en curso sobrevive a un refresh() completo.
func test_o2_feedback_one_per_event_and_survives_refresh() -> void:
	var ls: LocalSession = _session(3, 5)
	var t: TableScreen = _table()
	t.bind_session(ls)
	t.feedback().bus.auto_advance = false
	await wait_process_frames(2)
	var fb: TableFeedback = t.feedback()
	var base: int = fb.bus.last_seq()
	var ids: Array[String] = ["p1"]
	for i: int in 400:
		if String(ls.state["status"]) != Types.STATUS_PLAYING:
			break
		var d: String = Decision.local_decider(ls.state, ids)
		if d != "":
			var a: Dictionary = Bot.choose_action(ls.get_view_for(d), d, 900 + i, 0)["action"]
			if a.is_empty():
				break
			ls.submit_action(a)
		elif not ls.step_bot():
			break
		fb.bus.advance(60)
		if i % 40 == 0:
			await wait_process_frames(1)
	var refreshes: int = t.refresh_count
	fb.bus.drain()
	assert_eq(t.refresh_count, refreshes, "el feedback no dispara refresh()")
	var want: Dictionary = {"damage": 0, "heal": 0, "mana": 0, "potion": 0}
	var map: Dictionary = {Types.LOG_DAMAGE: "damage", Types.LOG_HEAL: "heal",
		Types.LOG_MANA_CHANGED: "mana", Types.LOG_POTION: "potion"}
	for e: Variant in ls.state["log"] as Array:
		var en: Dictionary = e
		if int(en["log_seq"]) > base and (en.get("visible_to", []) as Array).is_empty() and map.has(String(en["type"])):
			want[map[String(en["type"])]] = int(want[map[String(en["type"])]]) + 1
	var total: int = 0
	for k: String in want:
		total += int(want[k])
		assert_eq(int(fb.layer.played.get(k, 0)), int(want[k]), "dibujados == entradas de log: " + k)
	assert_gt(total, 5, "la partida produjo eventos (no pasa en vacío)")
	# Sobrevive a un refresh completo.
	fb.layer.play({"log_seq": 99001, "rev": 1, "kind": "damage", "lane": FeedbackMapper.lane_for("p2"),
		"target": "p2", "actor": "p2", "amount": -2, "card_id": "", "targets": [], "extra": {"prevented": 0},
		"visible_to": [], "duration_ms": FeedbackMapper.DUR_PANEL_MS})
	var before: int = fb.layer.visible_texts().size()
	assert_gt(before, 0)
	t.refresh()
	await wait_process_frames(2)
	assert_eq(fb.layer.visible_texts().size(), before, "el número flotante sobrevive a refresh()")


# ---------------------------------------------------------------- V2-24 pago

func _pay_state(hand: Array, scroll: bool = false) -> Dictionary:
	var s: Dictionary = H.game(3, {}, 3, [40, 30, 20])
	H.set_hand(s, "p1", hand)
	H.set_mana(s, "p1", 4)
	H.force_turn(s, "p1")
	s["pending"] = []
	if scroll:
		var tc: Dictionary = H._take_any(s, Types.CARD_SCROLL_OF_ELEMENTS)
		(H.player(s, "p1")["artifacts"] as Array).append(Types.make_table_card(int(tc["iid"]), Types.CARD_SCROLL_OF_ELEMENTS, "p1"))
	return s


func _pay_table(s: Dictionary) -> TableScreen:
	var t: TableScreen = _table()
	t.action_requested.connect(func(a: Dictionary) -> void: _actions.append(a))
	t.set_view(Types.view_for(s, "p1"), "p1")
	return t


func _iid(s: Dictionary, card_id: String, nth: int = 0) -> int:
	var k: int = 0
	for c: Variant in H.hand(s, "p1"):
		if String((c as Dictionary)["card_id"]) == card_id:
			if k == nth:
				return int((c as Dictionary)["iid"])
			k += 1
	return -1


func test_o2_payment_text_requirement_and_preselect() -> void:
	# Una única combinación: preselección, Confirmar activo, texto con requisito.
	var s: Dictionary = _pay_state(["fireball", "fire_arrow", "ice_bolt", "heal"])
	var t: TableScreen = _pay_table(s)
	t.ctx.flow.begin_play(_iid(s, "fireball"), false)
	if t.ctx.step == TableContext.Step.TARGETS:
		t.ctx.flow.on_panel_tapped("p2")
	assert_eq(t.ctx.step, TableContext.Step.PAYMENT)
	var txt: String = t.ctx.mode_bar.mode_label.text
	assert_true(txt.contains("Fireball"), txt)
	assert_true(txt.contains("1 carta de fuego"), "requisito singular con elemento: " + txt)
	assert_false(txt.contains("carta(s)"), "sin plural provisional: " + txt)
	assert_true(txt.ends_with("(1/1)"), txt)
	assert_false(t.ctx.mode_bar.mode_confirm.disabled, "Confirmar activo con una combinación")
	# Dos combinaciones: nada preseleccionado y Confirmar inactivo.
	var s2: Dictionary = _pay_state(["fireball", "fire_arrow", "fire_arrow", "heal"])
	var t2: TableScreen = _pay_table(s2)
	t2.ctx.flow.begin_play(_iid(s2, "fireball"), false)
	if t2.ctx.step == TableContext.Step.TARGETS:
		t2.ctx.flow.on_panel_tapped("p2")
	assert_true(t2.ctx.mode_bar.mode_label.text.ends_with("(0/1)"), t2.ctx.mode_bar.mode_label.text)
	assert_true(t2.ctx.mode_bar.mode_confirm.disabled)


func test_o2_payment_plural_and_type_requirements() -> void:
	var two: Array = [{"by": "element", "value": "fire", "count": 2}]
	assert_true(Strings.requirement_text(two).begins_with("2 cartas de "), Strings.requirement_text(two))
	assert_true(Strings.requirement_text([{"by": "element", "value": "fire", "count": 1}]).begins_with("1 carta de "))
	assert_eq(Strings.discard_title(1, "icy_grasp"), "Descarta 1 carta (Icy Grasp).")
	assert_eq(Strings.discard_title(2, "icy_grasp"), "Descarta 2 cartas (Icy Grasp).")
	# Por tipo, para todas las cartas con requisito: nunca "carta(s)" ni claves internas.
	for id: String in CardCatalog.all_defs().keys():
		var reqs: Array = (CardCatalog.get_def(id).get("cost", {}) as Dictionary).get("cards", []) as Array
		if reqs.is_empty():
			continue
		var s: String = Strings.requirement_text(reqs)
		assert_ne(s, "", id)
		assert_false(s.contains("(s)") or s.contains("_"), id + ": " + s)


# ---------------------------------------------------------------- V2-23 jugables y coste

func test_o2_playable_cost_with_active_event_matches_engine() -> void:
	for with_storm: bool in [false, true]:
		for mana: int in [0, 1, 2, 3]:
			var s: Dictionary = H.game(4, {}, 7, [40, 30, 20, 25])
			H.set_hand(s, "p1", ["fire_arrow", "fireball", "ice_bolt", "heal", "magic_shield"])
			H.set_mana(s, "p1", mana)
			H.force_turn(s, "p1")
			s["pending"] = []
			if with_storm:
				X.event(s, "fire_storm")
			var view: Dictionary = Types.view_for(s, "p1")
			var infos: Dictionary = CardInfo.for_hand(view, "p1", ActionOptions.build(view, "p1"))
			var legal: Array = Game.legal_actions(s, "p1")
			for i: Variant in infos.values():
				var inf: Dictionary = i
				var legal_play: bool = false
				for a: Variant in legal:
					var ad: Dictionary = a
					if String(ad.get("type", "")) == Types.ACTION_PLAY_CARD and int(ad.get("card", -1)) == int(inf["iid"]):
						legal_play = true
				var tag: String = "%s storm=%s mana=%d" % [inf["card_id"], with_storm, mana]
				assert_eq(bool(inf["playable"]), legal_play, "jugable == hay jugada legal: " + tag)
				var d: Dictionary = CardCatalog.get_def(String(inf["card_id"]))
				assert_eq(int(inf["cost"]), Damage.card_cost(view, "p1", d, int(inf["iid"]), false), "coste == motor: " + tag)
				assert_gte(int(inf["cost"]), 0)
				if not bool(inf["playable"]):
					assert_ne(String(inf["reason"]), "", "no jugable explica el motivo: " + tag)
	# Fire Storm sube de verdad el coste del hechizo de fuego (1 -> 2).
	var s2: Dictionary = H.game(4, {}, 7, [40, 30, 20, 25])
	H.set_hand(s2, "p1", ["fire_arrow"])
	H.set_mana(s2, "p1", 5)
	H.force_turn(s2, "p1")
	X.event(s2, "fire_storm")
	var v2: Dictionary = Types.view_for(s2, "p1")
	var one: Dictionary = (CardInfo.for_hand(v2, "p1", ActionOptions.build(v2, "p1")).values() as Array)[0]
	assert_eq(int(one["cost"]), 2)
	assert_eq(String(one["mana_line"]), "Maná: 2 (base 1)")


# ---------------------------------------------------------------- V2-25b auto-pase

func _ap_session(mode: String, caster: String, target: String) -> LocalSession:
	var players: Array = []
	for i: int in 3:
		players.append(Types.make_player("p%d" % (i + 1), NAMES[i], 40 - i, i + 1, i >= 1))
	var s: Dictionary = Game.new_game(players, {"log_limit": 100000, "reaction_timeout_local_ms": 0}, 7)
	for pd: Variant in players:
		H.set_hand(s, String((pd as Dictionary)["id"]), [Types.CARD_MAGIC_SHIELD])
		H.set_mana(s, String((pd as Dictionary)["id"]), 6)
	H.set_hand(s, caster, [Types.CARD_FIRE_ARROW])
	H.force_turn(s, caster)
	var ls: LocalSession = LocalSession.new()
	autofree(ls)
	ls.auto_run_bots = false
	ls.clock = func() -> int: return 1000
	ls.reaction_notify = mode
	ls.start(s, 7)
	var iid: int = int(H.hand(ls.state, caster)[0]["iid"])
	ls._enqueue(Types.make_action_play_card(caster, iid, [target]), "bot")
	var n: int = 0
	while not (ls.state["reaction"] as Dictionary).is_empty() and ls.is_bot(Decision.responder(ls.state)) and n < 10:
		ls._enqueue(Types.make_action_pass_reaction(Decision.responder(ls.state)), "bot")
		n += 1
	return ls


func _autos(ls: LocalSession) -> int:
	var n: int = 0
	for h: Dictionary in ls.history:
		if String(h["by"]) == "auto_pass":
			n += 1
	return n


func test_o2_auto_pass_affecting_vs_all() -> void:
	# Entre bots (p2 -> p3) con Magic Shield en la mano del humano p1.
	var all_s: LocalSession = _ap_session("all", "p2", "p3")
	assert_eq(_autos(all_s), 0, "all: nunca auto-pasa")
	assert_false((all_s.state["reaction"] as Dictionary).is_empty(), "all: la ventana espera al humano")
	assert_eq(Decision.responder(all_s.state), "p1", "all: el humano con Magic Shield decide")
	var aff: LocalSession = _ap_session("affecting", "p2", "p3")
	assert_eq(_autos(aff), 1, "affecting: el humano no afectado se auto-pasa una vez")
	assert_ne(Decision.responder(aff.state), "p1", "affecting: p1 no decide")
	# Si el humano ES el objetivo, affecting NO lo auto-pasa.
	var targeted: LocalSession = _ap_session("affecting", "p2", "p1")
	assert_eq(_autos(targeted), 0, "affecting: si me apuntan se me avisa")
	assert_eq(Decision.responder(targeted.state), "p1")
	assert_eq(Types.validate_state(aff.state), [], "estado válido tras auto-pase")
	assert_eq(Types.validate_state(targeted.state), [])


# ---------------------------------------------------------------- V2-26 resumen

func _finished_session(n: int, sd: int) -> LocalSession:
	var ls: LocalSession = _session(n, sd, 0)
	ls.run_bots(5000)
	return ls


func test_o2_engine_summary_fields_and_match_summary() -> void:
	for sd: int in [2, 3, 4]:
		var n: int = 3 + sd % 3
		var ls: LocalSession = _finished_session(n, sd)
		assert_eq(String(ls.state["status"]), Types.STATUS_FINISHED, "partida terminada sd=%d" % sd)
		assert_eq(Types.validate_state(ls.state), [])
		var view: Dictionary = ls.get_view_for("p1")
		var orders: Array = []
		for p: Variant in view["players"]:
			var pd: Dictionary = p
			assert_gte(int(pd["turns_played"]), 0)
			if not bool(pd["eliminated"]):
				assert_gt(int(pd["turns_played"]), 0, "el superviviente jugó turnos")
			if bool(pd["eliminated"]):
				assert_gt(int(pd["eliminated_order"]), 0)
				assert_gt(int(pd["eliminated_turn"]), 0)
				orders.append(int(pd["eliminated_order"]))
				if String(pd["eliminated_reason"]) == Types.ELIM_HP:
					assert_ne(String(pd["eliminated_cause"]), "", "causa fina con ELIM_HP")
			else:
				assert_eq(int(pd["eliminated_order"]), 0)
		var uniq: Dictionary = {}
		for o: Variant in orders:
			uniq[o] = true
		assert_eq(uniq.size(), orders.size(), "eliminated_order sin repetidos")
		var sm: Dictionary = MatchSummary.build(view, ["p1"] as Array[String])
		assert_eq((sm["rows"] as Array).size(), n)
		assert_ne(String(sm["title"]), "")
		assert_false(String(sm["title"]).contains("_"))
		var first: Dictionary = (sm["rows"] as Array)[0]
		assert_eq(int(first["position"]), 1)
		for r: Variant in sm["rows"]:
			var row: Dictionary = r
			assert_false(String(row["text"]).contains("_"), String(row["text"]))
			assert_false(String(row["stats"]).contains("_"))
			assert_ne(String(row["cause"]), "")
		if not (view["winners"] as Array).is_empty():
			assert_true(bool(first["winner"]), "el ganador va primero")


func test_o2_play_again_button_is_primary_and_larger_than_secondary() -> void:
	var ls: LocalSession = _finished_session(4, 3)
	var t: TableScreen = _table()
	t.set_view(ls.get_view_for("p1"), "p1")
	await wait_process_frames(3)
	var go: TableGameOver = t.ctx.game_over
	assert_true(go.is_result_open())
	var b: Button = go.play_again_button
	assert_true(b.is_visible_in_tree())
	assert_gte(UiTheme.BUTTON_PRIMARY_H, 144)
	assert_gte(b.custom_minimum_size.y, 144.0)
	assert_gte(b.size.y, 144.0, "alto real >= 144 px (diseño 1080)")
	assert_eq(b.theme_type_variation, UiTheme.VARIATION_PRIMARY, "estilo principal distinto del secundario")
	for sec: Button in [go.see_table_button]:
		assert_lt(sec.custom_minimum_size.y, b.custom_minimum_size.y)
		assert_gte(sec.custom_minimum_size.y, float(UiTheme.BUTTON_MIN_H))


# ---------------------------------------------------------------- V2-40 tema

func test_o2_theme_constants() -> void:
	assert_eq(UiTheme.BUTTON_PRIMARY_H, 144)
	assert_gte(UiTheme.BUTTON_PRIMARY_H, UiTheme.BUTTON_MIN_H)
	assert_eq(UiTheme.BUTTON_MIN_H, 96)
	var b: Button = Button.new()
	autofree(b)
	b.custom_minimum_size = Vector2(10, 20)
	UiTheme.apply_primary(b)
	assert_eq(b.custom_minimum_size.y, 144.0)
	b.custom_minimum_size = Vector2(10, 300)
	UiTheme.apply_primary(b)
	assert_eq(b.custom_minimum_size.y, 300.0, "no reduce un mínimo mayor")


# ---------------------------------------------------------------- V2-39 huérfano (comportamiento)

## Mutación manual (por lectura, no se edita src/): si TablePrompts.update_overlays no
## llamara a _drop_orphan_flow, con prompts vacíos solo se ejecutaría la rama
## `prompts.is_empty()` (shown_prompt_id = -1, cierra diálogo) que NO toca ctx.step ni
## flow_data. test_orphan_selection.test_orphan_discard_is_reset aserta step == NONE y
## flow_data vacío tras quitar el prompt, y fallaría. Aquí se comprueba el comportamiento
## desde otro ángulo: Confirmar no queda activo y el texto huérfano desaparece.
func test_o2_orphan_selection_cleared_without_confirm_text() -> void:
	var st: Dictionary = H.game(3, {}, 4, [40, 30, 20])
	H.force_turn(st, "p2")
	st["pending"] = [Types.make_prompt(7, "p1", Types.PROMPT_DISCARD, {"count": 1}, "ice_bolt")]
	var t: TableScreen = _table()
	t.set_view(Types.view_for(st, "p1"), "p1")
	await wait_process_frames(2)
	assert_eq(t.ctx.step, TableContext.Step.CARDS)
	assert_true(t.ctx.mode_bar.mode_label.text.begins_with("Descarta"), t.ctx.mode_bar.mode_label.text)
	st["pending"] = []
	t.set_view(Types.view_for(st, "p1"), "p1")
	await wait_process_frames(2)
	assert_eq(t.ctx.step, TableContext.Step.NONE)
	# El texto del Label queda obsoleto pero la barra (con Confirmar) está oculta.
	assert_false(t.ctx.mode_bar.bar.is_visible_in_tree(), "barra de selección oculta")
	assert_false(t.ctx.mode_bar.mode_confirm.is_visible_in_tree(), "sin botón Confirmar huérfano")

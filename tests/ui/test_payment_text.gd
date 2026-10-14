extends GutTest
## V2-24 (criterios-v02 item 4): texto del paso de pago y preseleccion.
## Casos C4-1..C4-11 con el catalogo real y la pantalla de mesa.

var _actions: Array = []
var _iid: int = 0


func before_each() -> void:
	CardCatalog.load_json()
	UiUtil.extra_defs = {}
	_actions = []
	_iid = 0


func _on_action(a: Dictionary) -> void:
	_actions.append(a)


func _inst(card_id: String) -> Dictionary:
	_iid += 1
	return Types.make_card_instance(_iid, card_id)


## Estado: Ana (p1, turno, maná 3), Bruno (p2) y Cira (p3). `hand` son card_ids.
func _state(hand: Array, scroll: bool = false) -> Dictionary:
	var s: Dictionary = Types.make_state({}, 5)
	for i: int in 3:
		var p: Dictionary = Types.make_player("p%d" % (i + 1), ["Ana", "Bruno", "Cira"][i], 30 + i, i + 1, i > 0)
		p["hp"] = 10
		p["mana"] = 3
		(s["players"] as Array).append(p)
	var ana: Dictionary = Types.get_player(s, "p1")
	for id: Variant in hand:
		(ana["hand"] as Array).append(_inst(String(id)))
	if scroll:
		_iid += 1
		(ana["artifacts"] as Array).append(Types.make_table_card(_iid, Types.CARD_SCROLL_OF_ELEMENTS, "p1"))
	for k: int in 10:
		(s["deck"] as Array).append(_inst(Types.CARD_HEAL))
	s["status"] = Types.STATUS_PLAYING
	s["turn"] = Types.make_turn(1, "p1", Types.PHASE_MAIN)
	s["card_total"] = Types.all_card_iids(s).size()
	return s


func _table(s: Dictionary) -> TableScreen:
	var t: TableScreen = (load("res://src/ui/screens/table.tscn") as PackedScene).instantiate()
	t.demo_when_empty = false
	add_child_autofree(t)
	t.action_requested.connect(_on_action)
	t.set_view(Types.view_for(s, "p1"), "p1")
	return t


func _iid_of(s: Dictionary, card_id: String, nth: int = 0) -> int:
	var k: int = 0
	for c: Variant in Types.get_player(s, "p1")["hand"] as Array:
		if String((c as Dictionary)["card_id"]) == card_id:
			if k == nth:
				return int((c as Dictionary)["iid"])
			k += 1
	return -1


## Juega la carta (ya con objetivo p2 si lo pide) y deja la barra en pago.
func _start(t: TableScreen, iid: int, target: String = "p2") -> void:
	t.ctx.flow.begin_play(iid, false)
	if t.ctx.step == TableContext.Step.TARGETS:
		t.ctx.flow.on_panel_tapped(target)


func _label(t: TableScreen) -> String:
	return t.ctx.mode_bar.mode_label.text


func _confirm_disabled(t: TableScreen) -> bool:
	return t.ctx.mode_bar.mode_confirm.disabled


# --- C4-1, C4-2 ----------------------------------------------------------------

func test_c4_1_single_combo_preselected() -> void:
	var s: Dictionary = _state(["fireball", "fire_arrow", "ice_bolt", "heal"])
	var t: TableScreen = _table(s)
	_start(t, _iid_of(s, "fireball"))
	assert_eq(t.ctx.step, TableContext.Step.PAYMENT)
	assert_eq(_label(t), "Fireball: paga 1 carta de fuego (1/1)")
	assert_eq(t.ctx.payment(), [_iid_of(s, "fire_arrow")])
	assert_false(_confirm_disabled(t))


func test_c4_2_deselect_reselect_confirm() -> void:
	var s: Dictionary = _state(["fireball", "fire_arrow", "ice_bolt", "heal"])
	var t: TableScreen = _table(s)
	var fa: int = _iid_of(s, "fire_arrow")
	_start(t, _iid_of(s, "fireball"))
	t.ctx.mode_bar.on_hand_tapped(fa)
	assert_eq(_label(t), "Fireball: paga 1 carta de fuego (0/1)")
	assert_true(_confirm_disabled(t))
	t.ctx.mode_bar.on_hand_tapped(fa)
	assert_false(_confirm_disabled(t))
	t.ctx.mode_bar._on_mode_confirm()
	assert_eq(_actions.size(), 1)
	assert_eq(_actions[0]["type"], Types.ACTION_PLAY_CARD)
	assert_eq(_actions[0]["payment"], [fa])
	assert_eq(_actions[0]["targets"], ["p2"])


# --- C4-3 ----------------------------------------------------------------------

func test_c4_3_two_combos_no_preselection() -> void:
	var s: Dictionary = _state(["fireball", "fire_arrow", "fire_arrow", "heal"])
	var t: TableScreen = _table(s)
	_start(t, _iid_of(s, "fireball"))
	assert_eq(_label(t), "Fireball: paga 1 carta de fuego (0/1)")
	assert_eq(t.ctx.payment(), [])
	assert_true(_confirm_disabled(t))
	t.ctx.mode_bar.on_hand_tapped(_iid_of(s, "heal"))
	assert_eq(t.ctx.payment(), [], "heal no se puede marcar")
	t.ctx.mode_bar.on_hand_tapped(_iid_of(s, "fire_arrow", 1))
	assert_false(_confirm_disabled(t))


# --- C4-4 ----------------------------------------------------------------------

func test_c4_4_scroll_and_hand_card() -> void:
	var s: Dictionary = _state(["fireball", "fire_arrow", "heal"], true)
	var t: TableScreen = _table(s)
	_start(t, _iid_of(s, "fireball"))
	assert_eq(_label(t), "Fireball: paga 1 carta de fuego (o tu Scroll of Elements) (0/1)")
	assert_eq(t.ctx.payment(), [])
	assert_true(_confirm_disabled(t))


func test_c4_4_scroll_only_preselected() -> void:
	var s: Dictionary = _state(["fireball", "heal"], true)
	var t: TableScreen = _table(s)
	_start(t, _iid_of(s, "fireball"))
	assert_eq(t.ctx.step, TableContext.Step.PAYMENT)
	assert_eq(t.ctx.pay_table.size(), 1)
	assert_eq(_label(t), "Fireball: paga 1 carta de fuego (1/1)")
	assert_false(_confirm_disabled(t))


# --- C4-5 ----------------------------------------------------------------------

func test_c4_5_armageddon() -> void:
	var s: Dictionary = _state(["armageddon", "fire_arrow", "ice_bolt", "lightning", "heal"])
	s["players"][0]["mana"] = 5
	var t: TableScreen = _table(s)
	_start(t, _iid_of(s, "armageddon"))
	assert_eq(_label(t), "Armageddon: paga 1 carta de fuego, 1 carta de hielo y 1 carta de electricidad (3/3)")
	assert_eq(t.ctx.payment().size(), 3)
	assert_false(_confirm_disabled(t))


func test_c4_5_armageddon_two_fire() -> void:
	var s: Dictionary = _state(["armageddon", "fire_arrow", "fire_arrow", "ice_bolt", "lightning"])
	s["players"][0]["mana"] = 5
	var t: TableScreen = _table(s)
	_start(t, _iid_of(s, "armageddon"))
	assert_eq(_label(t), "Armageddon: paga 1 carta de fuego, 1 carta de hielo y 1 carta de electricidad (0/3)")
	assert_eq(t.ctx.payment(), [])
	assert_true(_confirm_disabled(t))


# --- C4-6 / C4-11: textos por tipo --------------------------------------------

func test_c4_6_type_requirements() -> void:
	var texts: Dictionary = {"mana_implosion": "1 carta de maldición", "vampiric_touch": "1 carta de apoyo",
		"mirror_shield": "1 carta defensiva"}
	for id: String in texts:
		var reqs: Array = (CardCatalog.get_def(id)["cost"] as Dictionary)["cards"]
		assert_eq(Strings.requirement_text(reqs), texts[id], id)


func test_c4_6_header_vampiric_touch_in_table() -> void:
	var s: Dictionary = _state(["vampiric_touch", "heal"])
	var t: TableScreen = _table(s)
	_start(t, _iid_of(s, "vampiric_touch"))
	assert_eq(_label(t), "Vampiric Touch: paga 1 carta de apoyo (1/1)")


# --- C4-7 ----------------------------------------------------------------------

func test_c4_7_no_payment_step() -> void:
	var s: Dictionary = _state(["fire_arrow", "heal"])
	var t: TableScreen = _table(s)
	_start(t, _iid_of(s, "fire_arrow"))
	assert_ne(t.ctx.step, TableContext.Step.PAYMENT)
	assert_false(_label(t).contains("(0/0)"))
	assert_eq(_actions.size(), 1)
	assert_eq(_actions[0]["payment"], [])


# --- C4-8: reaccion ------------------------------------------------------------

func _reaction_state(hand: Array) -> Dictionary:
	var s: Dictionary = _state(hand)
	s["players"][0]["mana"] = 5
	var spell: Dictionary = Types.make_spell(_inst("fireball"), "p2", ["p1"])
	s["reaction"] = Types.make_reaction(spell, ["p1"])
	s["card_total"] = Types.all_card_iids(s).size()
	return s


func test_c4_8_reaction_single_combo() -> void:
	var s: Dictionary = _reaction_state(["mirror_shield", "magic_shield", "heal"])
	var t: TableScreen = _table(s)
	t.ctx.flow.begin_play(_iid_of(s, "mirror_shield"), true)
	if t.ctx.step == TableContext.Step.TARGETS:
		t.ctx.flow.on_panel_tapped("p1")
	if t.ctx.step == TableContext.Step.PAYMENT:
		assert_eq(_label(t), "Mirror Shield: paga 1 carta defensiva (1/1)")
		assert_false(_confirm_disabled(t))
	else:
		assert_not_null(t.ctx.pflow)
		var f: PlayFlow = t.ctx.pflow
		assert_eq(f.payment_combos().size(), 1)


func test_c4_8_reaction_two_combos() -> void:
	var s: Dictionary = _reaction_state(["mirror_shield", "magic_shield", "magic_shield", "heal"])
	var t: TableScreen = _table(s)
	t.ctx.flow.begin_play(_iid_of(s, "mirror_shield"), true)
	if t.ctx.step == TableContext.Step.TARGETS:
		t.ctx.flow.on_panel_tapped("p1")
	var f: PlayFlow = t.ctx.pflow
	assert_eq(f.sole_payment(), [])
	assert_eq(t.ctx.payment(), [])


# --- C4-9: recalculo al cambiar de objetivo ------------------------------------

func _cand(target: String, pay: Array) -> Dictionary:
	return Types.make_action_play_card("p1", 1, [target], pay)


func test_c4_9_target_change_recomputes() -> void:
	var f: PlayFlow = PlayFlow.create([_cand("p2", [10]), _cand("p3", [10]), _cand("p3", [11])])
	assert_true(f.toggle_target("p2"))
	assert_eq(f.sole_payment(), [10])
	assert_true(f.toggle_target("p3"))
	assert_eq(f.sole_payment(), [], "con p3 hay dos combinaciones")


func test_c4_9_enter_payment_clears_stale_selection() -> void:
	var s: Dictionary = _state(["fireball", "fire_arrow", "fire_arrow"])
	var t: TableScreen = _table(s)
	_start(t, _iid_of(s, "fireball"))
	t.ctx.selected.append(_iid_of(s, "fire_arrow"))
	t.ctx.mode_bar.enter_payment()
	assert_eq(t.ctx.payment(), [])


# --- C4-10: coherencia con el motor -------------------------------------------

func test_c4_10_ui_combos_match_engine() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 424242
	var pool: Array[String] = ["fire_arrow", "ice_bolt", "lightning", "heal", "mirror_shield",
		"magic_shield", "fireball", "armageddon", "vampiric_touch", "mana_implosion", "curse_of_rules"]
	var checked: int = 0
	for n: int in 50:
		var hand: Array = []
		for k: int in rng.randi_range(3, 8):
			hand.append(pool[rng.randi_range(0, pool.size() - 1)])
		_iid = 0
		var s: Dictionary = _state(hand, rng.randi() % 3 == 0)
		s["players"][0]["mana"] = 8
		var view: Dictionary = Types.view_for(s, "p1")
		var opts: ActionOptions = ActionOptions.build(view, "p1")
		for c: Variant in Types.get_player(s, "p1")["hand"] as Array:
			var iid: int = int((c as Dictionary)["iid"])
			var cands: Array = opts.plays_for(iid)
			if cands.is_empty():
				continue
			var f: PlayFlow = PlayFlow.create(cands)
			for tg: String in ["p2", "p3"]:
				if f.need_targets() > 0 and not f.toggle_target(tg):
					continue
				if f.needs_target_card() or f.needs_extra():
					f.target_card = f.target_card_choices()[0] if not f.target_card_choices().is_empty() else PlayFlow.UNSET
				var legal: Array = []
				for a: Variant in f.remaining():
					var pay: Array = (a as Dictionary)["payment"]
					if not pay.is_empty():
						legal.append(a)
				var combos: Array = f.payment_combos()
				for combo: Variant in combos:
					var act: Dictionary = f.build(combo as Array)
					if act.is_empty():
						continue
					var r: Dictionary = Game.reduce(s, act)
					assert_ne(r["error"], Types.ERR_INVALID_PAYMENT, "pago aceptado por el motor")
					checked += 1
				var distinct: int = 0
				var seen: Array = []
				for a: Variant in legal:
					var pay2: Array = (a as Dictionary)["payment"]
					var dup: bool = false
					for sp: Variant in seen:
						if ActionOptions.same_set(sp as Array, pay2):
							dup = true
					if not dup:
						seen.append(pay2)
						distinct += 1
				assert_eq(combos.size(), distinct)
				if f.need_targets() > 0:
					f.toggle_target(tg)
	assert_gt(checked, 0)


# --- C4-11: todas las cartas con coste en cartas --------------------------------

func test_c4_11_requirement_text_all_cards() -> void:
	var n: int = 0
	for id: String in CardCatalog.all_defs():
		var d: Dictionary = CardCatalog.get_def(id)
		if not bool(d.get("playable", false)):
			continue
		n += 1
		var reqs: Array = (d["cost"] as Dictionary)["cards"]
		if reqs.is_empty():
			continue
		var txt: String = Strings.requirement_text(reqs)
		assert_ne(txt, "", id)
		assert_false(txt.contains("_"), id)
		assert_false(txt.contains("by") or txt.contains("element"), id)
		assert_false(txt.contains("carta(s)"), id)
		var total: int = 0
		for r: Variant in reqs:
			total += int((r as Dictionary)["count"])
		assert_eq(Strings.requirement_total(reqs), total, id)
	assert_eq(n, 58)

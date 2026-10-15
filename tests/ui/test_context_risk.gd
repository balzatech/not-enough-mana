extends NemTest
## V2-29 (ítem 10): riesgo de la poción, "contra ti" y "Pasa el dispositivo" con motivo.

const H = preload("res://tests/fixtures/engine_helpers.gd")

var _t: TableScreen


func before_each() -> void:
	super.before_each()
	CardCatalog.load_json()
	EffectRegistry.reset()


func after_each() -> void:
	await super.after_each()
	if _t != null:
		_t.queue_free()
		_t = null


func _state(potions: int, cfg: Dictionary = {}) -> Dictionary:
	var s: Dictionary = H.game(3, cfg, 7)
	H.force_turn(s, "p1")
	s["pending"] = []
	Types.get_player(s, "p1")["potions"] = potions
	return s


func _table(s: Dictionary) -> TableScreen:
	_t = (load("res://src/ui/screens/table.tscn") as PackedScene).instantiate()
	add_child_autofree(_t)
	_t.set_view(Types.view_for(s, "p1"), "p1")
	return _t


func _fill(t: TableScreen) -> Color:
	return (t._drink_btn.get_theme_stylebox("normal") as StyleBoxFlat).bg_color


func _with_reaction(target: String) -> Dictionary:
	var s: Dictionary = _state(0)
	var spell: Dictionary = Types.make_spell({"iid": 900, "card_id": Types.CARD_FIREBALL}, "p2", [target])
	s["reaction"] = Types.make_reaction(spell, ["p1"])
	return s


func test_risk_levels_and_colors() -> void:
	var fills: Array[Color] = []
	var expect: Array = [[7, 0, false], [8, 1, true], [9, 2, true], [10, 3, true]]
	for e: Array in expect:
		var t: TableScreen = _table(_state(int(e[0])))
		fills.append(_fill(t))
		assert_eq(TableActions.potion_risk(int(e[0]), 10, true), int(e[1]), "nivel %d/10" % int(e[0]))
		assert_eq(t._drink_btn.text.begins_with("⚠"), bool(e[2]), "símbolo a %d/10" % int(e[0]))
		assert_true(t._drink_btn.text.contains("%d/10" % int(e[0])), "contador a %d/10" % int(e[0]))
		assert_eq(t._drink_btn.tooltip_text != "", bool(e[2]), "aviso a %d/10" % int(e[0]))
		_t.queue_free()
		_t = null
	assert_eq(fills[0], TableActions.RISK_FILL[0])
	assert_eq(fills[1], TableActions.RISK_FILL[1])
	assert_eq(fills[2], TableActions.RISK_FILL[2])
	assert_eq(fills[3], TableActions.RISK_FILL[3])
	assert_ne(fills[1], fills[2])
	assert_gt(fills[3].r, fills[3].g * 2.0, "10/10 es rojo")


func test_risk_off_when_limit_disabled() -> void:
	var t: TableScreen = _table(_state(9, {"potion_limit_enabled": false}))
	assert_eq(_fill(t), TableActions.RISK_FILL[0])
	assert_false(t._drink_btn.text.begins_with("⚠"))
	assert_eq(TableActions.potion_risk(9, 10, false), 0)


func test_risk_respects_custom_limit() -> void:
	assert_eq(TableActions.potion_risk(3, 5, true), 1)
	assert_eq(TableActions.potion_risk(4, 5, true), 2)
	assert_eq(TableActions.potion_risk(5, 5, true), 3)
	assert_eq(TableActions.potion_risk(2, 5, true), 0)


func test_against_you_with_fireball_on_me() -> void:
	var t: TableScreen = _table(_with_reaction("p1"))
	assert_true(t._reaction_overlay.visible)
	assert_true(t._reaction._against_label.visible)
	assert_true(t._reaction._against_label.text.contains(Strings.AGAINST_YOU))
	assert_false(t._reaction._against_label.text.contains("No va"))


func test_not_against_you_with_fireball_on_other() -> void:
	var t: TableScreen = _table(_with_reaction("p3"))
	assert_true(t._reaction_overlay.visible)
	assert_true(t._reaction._against_label.visible)
	assert_eq(t._reaction._against_label.text, Strings.NOT_AGAINST_YOU)


func test_pass_reason_turn_reaction_decision() -> void:
	var s: Dictionary = _state(0)
	assert_eq(TableSync.pass_reason(Types.view_for(s, "p1"), "p1"), Strings.PASS_REASON_TURN)
	var r: Dictionary = _with_reaction("p1")
	assert_eq(TableSync.pass_reason(Types.view_for(r, "p1"), "p1"), Strings.PASS_REASON_REACTION)
	var d: Dictionary = _state(0)
	d["pending"] = [{"id": 1, "player": "p1", "kind": Types.PROMPT_DRINK_OR_SUFFER, "data": {"hp": 1}}]
	assert_eq(TableSync.pass_reason(Types.view_for(d, "p1"), "p1"), Strings.PASS_REASON_DECISION)


func test_pass_screen_shows_reason_text() -> void:
	var p: PassDeviceScreen = PassDeviceScreen.new()
	add_child_autofree(p)
	p.show_for("Cira", Strings.PASS_REASON_TURN)
	assert_eq(p.reason, "Turno de Cira")
	p.show_for("Cira", Strings.PASS_REASON_REACTION)
	assert_eq(p.reason, "Cira: ¿respondes al hechizo?")
	p.show_for("Cira", Strings.PASS_REASON_DECISION)
	assert_eq(p.reason, "Cira: tienes una decisión pendiente")
	assert_eq(p._reason_label.text, "Cira: tienes una decisión pendiente")

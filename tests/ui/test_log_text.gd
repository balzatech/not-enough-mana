extends NemTest
## LogText / ActionLog (V2-16): el registro nunca muestra claves internas ni "efecto aplicado".

const OH = preload("res://tests/engine/effects/offensive_helpers.gd")

var _names: Dictionary = {"p1": "Ana", "p2": "Bruno", "p3": "Cira", "p4": "Dario"}


func before_each() -> void:
	super.before_each()
	CardCatalog.load_json()


func _entry(type: String, data: Dictionary) -> Dictionary:
	return Types.make_log_entry(type, 1, "p1", data)


func _assert_clean(txt: String, label: String) -> void:
	assert_false(txt.contains("_"), "%s: sin guiones bajos: %s" % [label, txt])
	assert_false(txt.contains("efecto aplicado"), "%s: sin texto genérico: %s" % [label, txt])
	assert_ne(txt, "", label)


func test_all_log_types_are_clean() -> void:
	for t: String in Strings.LOG_TYPES:
		var data: Dictionary = {"card_id": Types.CARD_FIREBALL, "targets": ["p2"], "target": "p2"}
		_assert_clean(LogText.format(_entry(t, data), _names), t)
		_assert_clean(LogText.format(_entry(t, {}), _names), t + " (sin datos)")


func test_all_effect_whats_are_clean() -> void:
	for w: String in Strings.EFFECT_WHATS:
		var data: Dictionary = {"card_id": Types.CARD_FIREBALL, "what": w, "target": "p2", "targets": ["p2"],
			"seen": ([] as Array) if w == "hand_cards" else ("" as Variant), "to": (["p3"] as Variant) if w == "lightning_redirected" else ("p3" as Variant), "from": ["p2"], "caster": "p1"}
		_assert_clean(LogText.format(_entry(Types.LOG_EFFECT, data), _names), w)
		_assert_clean(LogText.format(_entry(Types.LOG_EFFECT, {"what": w}), _names), w + " (sin datos)")


func test_unknown_what_is_not_generic() -> void:
	_assert_clean(LogText.format(_entry(Types.LOG_EFFECT, {"card_id": Types.CARD_FIREBALL, "what": "zzz"}), _names), "zzz")


func test_mana_changed_real_engine_data() -> void:
	var s: Dictionary = OH.make_state(4)
	var events: Array = []
	Damage.lose_mana(s, "p2", 2, events, "p1", Types.CARD_MANA_IMPLOSION)
	var txt: String = LogText.format(OH.events_of(events, Types.LOG_MANA_CHANGED)[0], _names)
	assert_true(txt.begins_with("Bruno pierde 2 de maná"), txt)
	assert_false(txt.contains("+0"), txt)
	_assert_clean(txt, "mana_changed")


func test_damage_real_engine_data() -> void:
	var s: Dictionary = OH.make_state(4)
	var events: Array = []
	Damage.lose_hp(s, "p2", 3, events, "p1", Types.CARD_MANA_IMPLOSION)
	var ev: Array = OH.events_of(events, Types.LOG_DAMAGE)
	assert_eq(ev.size(), 1)
	var txt: String = LogText.format(ev[0], _names)
	assert_true(txt.begins_with("Bruno pierde 3 de vida"), txt)
	assert_false(txt.contains(" 0 "), txt)
	_assert_clean(txt, "damage")


func test_damage_prevented_is_shown() -> void:
	var txt: String = LogText.format(_entry(Types.LOG_DAMAGE, {"target": "p2", "dealt": 1, "prevented": 2}), _names)
	assert_eq(txt, "Bruno recibe 1 de daño; evita 2.")


func test_card_played_targets_list() -> void:
	var txt: String = LogText.format(_entry(Types.LOG_CARD_PLAYED, {"card_id": Types.CARD_FIREBALL, "targets": ["p2"]}), _names)
	assert_true(txt.contains("Bruno"), txt)


func test_highlight_marks_names_and_escapes() -> void:
	var h: String = LogText.highlight("Ana ataca a Bruno [x]", _names)
	assert_true(h.contains("[b]Ana[/b]") and h.contains("[b]Bruno[/b]"), h)
	assert_true(h.contains("[lb]x]"), h)


func test_action_log_shows_last_three() -> void:
	var al: ActionLog = ActionLog.new()
	add_child_autofree(al)
	var entries: Array = []
	for i: int in 5:
		entries.append(Types.make_log_entry(Types.LOG_TURN_STARTED, i + 1, "p1", {}))
	al.set_entries(entries, _names)
	assert_eq(al.lines.size(), 5)
	var shown: Array[String] = al.strip_lines()
	assert_eq(shown.size(), 3)
	assert_eq(shown[2], al.lines[4])
	assert_eq(shown[0], al.lines[2])
	assert_false(al.expanded)
	al.toggle()
	assert_true(al.expanded)

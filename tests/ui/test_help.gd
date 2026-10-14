extends GutTest
## V2-30: pantalla "Cómo se juega", accesos desde el menú y la mesa, aviso de evento.

const H = preload("res://tests/fixtures/engine_helpers.gd")
const ORDER: Array[String] = ["Objetivo", "Tu turno", "Pagar cartas y maná", "Pociones de maná",
	"Too Much Mana", "Defensivas y reacciones", "Eventos", "Artefactos y maldiciones"]


func before_each() -> void:
	CardCatalog.load_json()
	EffectRegistry.reset()


func _help(cfg: Dictionary = {}) -> HelpScreen:
	var h: HelpScreen = (load(UiNav.HELP) as PackedScene).instantiate()
	h.auto_navigate = false
	h.config = cfg
	add_child_autofree(h)
	return h


func _table(cfg: Dictionary = {}) -> TableScreen:
	var s: Dictionary = H.game(3, cfg, 5)
	var t: TableScreen = (load("res://src/ui/screens/table.tscn") as PackedScene).instantiate()
	t.demo_when_empty = false
	add_child_autofree(t)
	t.set_view(Types.view_for(s, "p1"), "p1")
	return t


func _all_labels(n: Node, out: Array[Label]) -> void:
	if n is Label:
		out.append(n)
	for c: Node in n.get_children():
		_all_labels(c, out)


func test_eight_sections_in_order() -> void:
	var h: HelpScreen = _help()
	assert_eq(h.title_labels.size(), 8)
	for i: int in 8:
		assert_eq(h.title_labels[i].text, ORDER[i])
		assert_ne(h.body_labels[i].text, "")


func test_numbers_follow_config() -> void:
	var h: HelpScreen = _help({"start_hp": 17, "potion_mana": 4})
	assert_string_contains(h.body_labels[0].text, "17 de vida")
	assert_string_contains(h.body_labels[3].text, "+4 de maná")
	var d: HelpScreen = _help()
	assert_string_contains(d.body_labels[0].text, "%d de vida" % int(Types.default_config()["start_hp"]))


func test_no_potion_limit_says_so() -> void:
	var h: HelpScreen = _help({"potion_limit_enabled": false})
	assert_string_contains(h.body_labels[4].text, "no hay límite de pociones")


func test_scrollable_with_back_and_hint() -> void:
	var h: HelpScreen = _help()
	assert_not_null(h.scroll)
	assert_eq(h.scroll.horizontal_scroll_mode, ScrollContainer.SCROLL_MODE_DISABLED)
	assert_eq(h.back_btn.text, "Volver")
	assert_gte(h.back_btn.custom_minimum_size.y, float(UiTheme.BUTTON_MIN_H))
	assert_eq(h.hint_label.text, StringsAyuda.VIEW_CARD_HINT)
	assert_string_contains(h.body_labels[1].text, "Adaptación digital:")


func test_no_underscores_and_font_size() -> void:
	var h: HelpScreen = _help()
	var labels: Array[Label] = []
	_all_labels(h, labels)
	for l: Label in labels:
		assert_false(l.text.contains("_"), "guion bajo en: " + l.text.left(40))
		assert_gte(l.get_theme_font_size("font_size"), UiTheme.FONT_MIN, l.text.left(30))


func test_back_emits_signal() -> void:
	var h: HelpScreen = _help()
	watch_signals(h)
	h.back_btn.pressed.emit()
	assert_signal_emitted(h, "back_pressed")


func test_main_menu_has_help_button() -> void:
	var m: MainMenu = (load("res://src/ui/screens/main_menu.tscn") as PackedScene).instantiate()
	m.auto_navigate = false
	add_child_autofree(m)
	assert_eq(m.help_btn.text, "Cómo se juega")
	assert_gte(m.help_btn.custom_minimum_size.y, float(UiTheme.BUTTON_MIN_H))
	watch_signals(m)
	m.help_btn.pressed.emit()
	assert_signal_emitted(m, "help_requested")


func test_table_help_roundtrip_keeps_state() -> void:
	var t: TableScreen = _table({"start_hp": 13})
	var before: Dictionary = t.view.duplicate(true)
	var sess: GameSession = t.session
	t.ctx.menu._on_menu()
	t.ctx.dialogs.on_button("help")
	var ov: HelpScreen = t.ctx.menu.help_overlay
	assert_not_null(ov)
	assert_true(ov.is_inside_tree())
	assert_string_contains(ov.body_labels[0].text, "13 de vida")
	ov.back_btn.pressed.emit()
	assert_null(t.ctx.menu.help_overlay)
	await get_tree().process_frame
	assert_eq(t.view, before)
	assert_eq(t.session, sess)
	assert_false(t.ctx.dialogs.dialog_overlay.visible)


func _notice_text(t: TableScreen) -> String:
	var labels: Array[Label] = []
	_all_labels(t.ctx.notices.notice_panel, labels)
	var out: Array[String] = []
	for l: Label in labels:
		out.append(l.text)
	return "\n".join(out)


func _event_entry(card_id: String) -> Dictionary:
	return {"type": Types.LOG_EVENT_DRAWN, "data": {"card_id": card_id, "iid": 900}}


func test_event_notice_persistent() -> void:
	var t: TableScreen = _table()
	t.ctx.notices.queue_event_notices([_event_entry("fire_storm")])
	assert_string_contains(_notice_text(t), "Evento: Fire Storm. Dura hasta el próximo evento.")


func test_event_notice_instant() -> void:
	var t: TableScreen = _table()
	t.ctx.notices.queue_event_notices([_event_entry("blessing")])
	assert_string_contains(_notice_text(t), "Evento: Blessing. Efecto inmediato, no dura.")

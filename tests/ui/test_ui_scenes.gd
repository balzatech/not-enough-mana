extends GutTest
## Tests de UI: las escenas se instancian sin errores y emiten las acciones esperadas.

const SCENES: Array[String] = [
	"res://src/ui/screens/main_menu.tscn",
	"res://src/ui/screens/local_setup.tscn",
	"res://src/ui/screens/lobby.tscn",
	"res://src/ui/screens/settings.tscn",
	"res://src/ui/screens/table.tscn",
	"res://src/ui/screens/pass_device_screen.tscn",
	"res://src/ui/screens/reaction_prompt.tscn",
	"res://src/ui/components/card_view.tscn",
	"res://src/ui/components/player_panel.tscn",
]

var _actions: Array[Dictionary] = []


func before_each() -> void:
	_actions = []
	FakeState.install_defs()
	UiUtil.prefer_extra = true


func after_each() -> void:
	UiUtil.prefer_extra = false


func _on_action(a: Dictionary) -> void:
	_actions.append(a)


func _table(n: int, pid: String = "p1") -> TableScreen:
	var t: TableScreen = (load("res://src/ui/screens/table.tscn") as PackedScene).instantiate()
	t.demo_when_empty = false
	add_child_autofree(t)
	t.action_requested.connect(_on_action)
	t.set_view(FakeState.make_view(n, pid), pid)
	return t


func _all_buttons(node: Node, out: Array[Button]) -> void:
	if node is Button:
		out.append(node as Button)
	for c: Node in node.get_children():
		_all_buttons(c, out)


func test_scenes_instantiate() -> void:
	for path: String in SCENES:
		var ps: PackedScene = load(path)
		assert_not_null(ps, "carga " + path)
		var n: Node = ps.instantiate()
		assert_not_null(n, "instancia " + path)
		if n is TableScreen:
			(n as TableScreen).demo_when_empty = false
		add_child_autofree(n)
		await wait_process_frames(2)
		assert_true(is_instance_valid(n), path)


func test_main_scene_is_main_menu() -> void:
	assert_eq(ProjectSettings.get_setting("application/run/main_scene"), UiNav.MAIN_MENU)


func test_fake_state_is_valid_and_view_hides_info() -> void:
	for n: int in range(2, 7):
		var s: Dictionary = FakeState.make_state(n)
		assert_eq(Types.validate_state(s), [] as Array[String], "estado válido con %d" % n)
		var v: Dictionary = Types.view_for(s, "p1")
		assert_true(bool(v["is_view"]))
		var p2: Dictionary = Types.get_player(v, "p2")
		assert_eq((p2["hand"] as Array).size(), 0)
		assert_gt(int(p2["hand_count"]), 0)


func test_table_with_3_to_6_players() -> void:
	for n: int in range(3, 7):
		var t: TableScreen = _table(n)
		await wait_process_frames(3)
		assert_eq(t._rival_panels.size(), n - 1, "rivales con %d jugadores" % n)
		assert_eq(t._hand.hand.size(), 7)
		var fan_rect: Rect2 = Rect2(Vector2.ZERO, t._rival_fan.size)
		for pp: PlayerPanel in t._rival_panels:
			assert_gt(pp.size.x, 100.0)
			assert_true(fan_rect.size.x >= pp.position.x + pp.size.x - 1.0, "cabe en el ancho (%d)" % n)
		t.queue_free()
		await wait_process_frames(1)


func test_touch_targets_at_least_48px() -> void:
	var t: TableScreen = _table(4)
	await wait_process_frames(3)
	var buttons: Array[Button] = []
	_all_buttons(t, buttons)
	assert_gt(buttons.size(), 5)
	for b: Button in buttons:
		assert_gte(b.get_combined_minimum_size().y, 48.0, "alto de '%s'" % b.text)
	assert_gte(t._drink_btn.size.y, 96.0, "Beber poción grande")
	assert_true(t._drink_btn.is_visible_in_tree(), "Beber poción visible")


func test_drink_potion_emits_action() -> void:
	var t: TableScreen = _table(4)
	t._drink_btn.pressed.emit()
	assert_eq(_actions.size(), 1)
	assert_eq(_actions[0]["type"], Types.ACTION_DRINK_POTION)
	assert_eq(_actions[0]["player"], "p1")


func test_end_turn_and_exchange_and_discard() -> void:
	var t: TableScreen = _table(4)
	var hand: Array = t._hand.hand
	t._on_hand_tapped(hand[0])
	t._exchange_btn.pressed.emit()
	assert_eq(_actions[0]["type"], Types.ACTION_EXCHANGE)
	assert_eq(_actions[0]["card"], int((hand[0] as Dictionary)["iid"]))
	t._on_hand_tapped(hand[0])
	t._on_hand_tapped(hand[1])
	t._discard_btn.pressed.emit()
	assert_eq(_actions[1]["type"], Types.ACTION_DISCARD)
	assert_eq((_actions[1]["cards"] as Array).size(), 2)
	t._end_btn.pressed.emit()
	assert_eq(_actions[2]["type"], Types.ACTION_END_TURN)


## Vista de prueba con maná de sobra para p1 (la mesa solo habilita lo legal
## según Game.legal_actions con el catálogo real).
func _rich_table(n: int, tweak: Callable = Callable()) -> TableScreen:
	var st: Dictionary = FakeState.make_state(n)
	(Types.get_player(st, "p1"))["mana"] = 10
	if tweak.is_valid():
		tweak.call(st)
	var t: TableScreen = (load("res://src/ui/screens/table.tscn") as PackedScene).instantiate()
	t.demo_when_empty = false
	add_child_autofree(t)
	t.action_requested.connect(_on_action)
	t.set_view(Types.view_for(st, "p1"), "p1")
	return t


func test_play_card_with_target() -> void:
	var t: TableScreen = _rich_table(4)
	var hand: Array = t._hand.hand
	var heal: Dictionary = hand[2]
	assert_eq(heal["card_id"], Types.CARD_HEAL)
	t._on_hand_tapped(heal)
	assert_false(t._play_btn.disabled, "Heal es legal")
	t._play_btn.pressed.emit()
	assert_eq(_actions.size(), 0, "espera objetivo")
	t._on_panel_tapped("p3")
	assert_eq(_actions.size(), 1)
	var a: Dictionary = _actions[0]
	assert_eq(a["type"], Types.ACTION_PLAY_CARD)
	assert_eq(a["targets"], ["p3"])
	assert_eq(Types.validate_action_shape(a), Types.ERR_NONE)


func test_play_card_with_payment() -> void:
	# Book Exchange pide pagar con una carta eléctrica: la última carta pasa a ser Electric Arc.
	var t: TableScreen = _rich_table(4, func(st: Dictionary) -> void:
		var h: Array = Types.get_player(st, "p1")["hand"]
		(h[6] as Dictionary)["card_id"] = Types.CARD_ELECTRIC_ARC)
	var hand: Array = t._hand.hand
	var book: Dictionary = {}
	for c: Variant in hand:
		if (c as Dictionary)["card_id"] == Types.CARD_BOOK_EXCHANGE:
			book = c
	assert_false(book.is_empty())
	t.begin_play(int(book["iid"]), false)
	t._on_panel_tapped("p2")
	assert_eq(_actions.size(), 0, "espera pago")
	var pay: Dictionary = hand[6]
	assert_eq(t._selected, [int(pay["iid"])] as Array[int], "única combinación: preseleccionada (V2-24)")
	t._on_hand_tapped(hand[0])
	assert_eq(t._selected.size(), 1, "Fireball no es eléctrica: no sirve para pagar")
	t._mode_confirm.pressed.emit()
	assert_eq(_actions.size(), 1)
	assert_eq(_actions[0]["payment"], [int(pay["iid"])])
	assert_eq(Types.validate_action_shape(_actions[0]), Types.ERR_NONE)


func test_break_rule_button() -> void:
	var t: TableScreen = _table(4)
	assert_true(t._rule_btn.visible, "hay Curse of Rules en mesa")
	t._on_break_rule()
	t._on_panel_tapped("p2")
	assert_eq(_actions.size(), 1)
	assert_eq(_actions[0]["type"], Types.ACTION_BREAK_RULE)
	assert_eq(_actions[0]["target"], "p2")


func test_reaction_prompt_pass_and_react() -> void:
	var st: Dictionary = FakeState.make_state(4)
	FakeState.with_reaction(st)
	(Types.get_player(st, "p1"))["mana"] = 5
	var t: TableScreen = (load("res://src/ui/screens/table.tscn") as PackedScene).instantiate()
	t.demo_when_empty = false
	add_child_autofree(t)
	t.action_requested.connect(_on_action)
	t.set_view(Types.view_for(st, "p1"), "p1")
	await wait_process_frames(2)
	assert_true(t._reaction_overlay.visible)
	t._reaction.pass_requested.emit()
	assert_eq(_actions[0]["type"], Types.ACTION_PASS_REACTION)
	t._reaction.react_requested.emit(int(((t._hand.hand[1]) as Dictionary)["iid"]))
	# Magic Shield: elige a quién protege.
	t._on_panel_tapped("p1")
	assert_eq(_actions.size(), 2)
	assert_eq(_actions[1]["type"], Types.ACTION_REACT)
	assert_eq(_actions[1]["targets"], ["p1"])


func test_prompt_dialog_actions() -> void:
	var st: Dictionary = FakeState.make_state(3)
	st["pending"] = [Types.make_prompt(9, "p1", Types.PROMPT_DRINK_OR_SUFFER, {"hp": 2})]
	var t: TableScreen = (load("res://src/ui/screens/table.tscn") as PackedScene).instantiate()
	t.demo_when_empty = false
	add_child_autofree(t)
	t.action_requested.connect(_on_action)
	t.set_view(Types.view_for(st, "p1"), "p1")
	await wait_process_frames(2)
	assert_true(t._dialog_overlay.visible)
	t._dialog.button_pressed.emit("p_decline")
	assert_eq(_actions[0]["type"], Types.ACTION_DECLINE)
	assert_eq(_actions[0]["prompt_id"], 9)


func test_hot_seat_shows_pass_screen_between_humans() -> void:
	var st: Dictionary = FakeState.make_state(4)
	(Types.get_player(st, "p2"))["is_bot"] = false
	var fs: FakeSession = FakeSession.create(st, ["p1", "p2"] as Array[String])
	var t: TableScreen = (load("res://src/ui/screens/table.tscn") as PackedScene).instantiate()
	t.demo_when_empty = false
	add_child_autofree(t)
	add_child_autofree(fs)
	t.bind_session(fs)
	await wait_process_frames(2)
	assert_eq(t.viewer_id, "p1")
	t._end_btn.pressed.emit()
	assert_eq(fs.submitted.size(), 1)
	assert_true(t._pass_screen.visible, "pantalla pasa el dispositivo")
	assert_eq(t.viewer_id, "p1", "aún no se revela la mano")
	t._pass_screen.confirmed.emit()
	assert_eq(t.viewer_id, "p2")
	assert_eq(t._hand.hand.size(), (Types.get_player(Types.view_for(st, "p2"), "p2")["hand"] as Array).size())


func test_card_view_placeholder_without_image() -> void:
	var def: Dictionary = Types.make_card_def("carta_inexistente", "Carta Test", Types.CARD_TYPE_OFFENSIVE,
		Types.ELEMENT_FIRE, 2)
	def["text"] = "Texto de prueba"
	var cv: CardView = CardView.create({"iid": 1, "card_id": "carta_inexistente"}, def, 200.0)
	add_child_autofree(cv)
	await wait_process_frames(2)
	assert_null(cv._art, "sin imagen => placeholder")
	assert_not_null(cv._name_label)
	assert_eq(cv._name_label.text, "Carta Test")
	var back: CardView = CardView.create({}, {}, 200.0, true)
	add_child_autofree(back)
	await wait_process_frames(1)
	assert_true(back.face_down)


func test_card_view_modes_and_zoom_signal() -> void:
	var def: Dictionary = UiUtil.card_def(Types.CARD_FIREBALL)
	var cv: CardView = CardView.create({"iid": 5, "card_id": Types.CARD_FIREBALL}, def, 200.0)
	add_child_autofree(cv)
	await wait_process_frames(1)
	for m: CardView.Mode in [CardView.Mode.NORMAL, CardView.Mode.SELECTABLE,
			CardView.Mode.SELECTED, CardView.Mode.DISABLED]:
		cv.set_mode(m)
		assert_eq(cv.mode, m)
	watch_signals(cv)
	cv._request_zoom()
	assert_signal_emitted(cv, "zoom_requested")


func test_player_panel_states() -> void:
	var s: Dictionary = FakeState.make_state(6)
	var view: Dictionary = Types.view_for(s, "p1")
	var pp: PlayerPanel = PlayerPanel.create(false, 200.0)
	add_child_autofree(pp)
	pp.update_player(Types.get_player(view, "p5"), false)
	assert_true(pp._tags().has("ELIMINADO"))
	pp.update_player(Types.get_player(view, "p6"), false)
	assert_true(pp._tags().has("DESCONECTADO"))
	pp.update_player(Types.get_player(view, "p1"), true)
	assert_true(pp._tags().has("TURNO"))
	pp.update_player(Types.get_player(view, "p3"), false)
	assert_true(pp._tags().has("Congelado"))


func test_local_setup_players_and_config() -> void:
	var ls: LocalSetup = (load("res://src/ui/screens/local_setup.tscn") as PackedScene).instantiate()
	ls.auto_navigate = false
	add_child_autofree(ls)
	await wait_process_frames(2)
	assert_eq(ls.player_count(), 3)
	ls.remove_player()
	assert_eq(ls.player_count(), 3, "mínimo 3")
	for i: int in 5:
		ls.add_player()
	assert_eq(ls.player_count(), 6, "máximo 6")
	var setup: Dictionary = ls.get_setup()
	assert_eq((setup["players"] as Array).size(), 6)
	var p0: Dictionary = (setup["players"] as Array)[0]
	for k: String in ["name", "age", "birth_month", "is_bot"]:
		assert_true(p0.has(k), k)
	var cfg: Dictionary = setup["config"]
	assert_eq(cfg["potion_limit"], 10)
	assert_eq(cfg["potion_mana"], 3)
	assert_eq(cfg["reaction_timeout_local_ms"], 0)
	assert_true(cfg["include_curse_of_rules"])
	watch_signals(ls)
	ls._on_start()
	assert_signal_emitted(ls, "start_requested")


func test_lobby_host_button_visibility() -> void:
	var lb: Lobby = (load("res://src/ui/screens/lobby.tscn") as PackedScene).instantiate()
	lb.auto_navigate = false
	add_child_autofree(lb)
	await wait_process_frames(2)
	lb.set_host(true)
	assert_true(lb._start_btn.visible)
	lb.set_host(false)
	assert_false(lb._start_btn.visible)
	lb.set_room_code("XYZW")
	assert_eq(lb._code_label.text, "XYZW")


func test_main_menu_signals() -> void:
	var mm: MainMenu = (load("res://src/ui/screens/main_menu.tscn") as PackedScene).instantiate()
	mm.auto_navigate = false
	add_child_autofree(mm)
	await wait_process_frames(2)
	watch_signals(mm)
	mm._on_local()
	mm._on_create()
	mm._on_settings()
	assert_signal_emitted(mm, "local_requested")
	assert_signal_emitted(mm, "create_room_requested")
	assert_signal_emitted(mm, "settings_requested")


func test_main_menu_hides_online_entries() -> void:
	var mm: MainMenu = (load("res://src/ui/screens/main_menu.tscn") as PackedScene).instantiate()
	mm.auto_navigate = false
	add_child_autofree(mm)
	await wait_process_frames(2)
	var texts: Array[String] = []
	var btns: Array[Button] = []
	_all_buttons(mm, btns)
	for b: Button in btns:
		if b.is_visible_in_tree() and not b.disabled:
			texts.append(b.text)
	assert_does_not_have(texts, "Crear sala")
	assert_does_not_have(texts, "Unirse con código")
	assert_has(texts, "Jugar local")
	assert_has(texts, "Ajustes")
	watch_signals(mm)
	mm._on_local()
	assert_signal_emitted(mm, "local_requested")


func test_settings_has_no_audio_controls() -> void:
	var st: Settings = (load("res://src/ui/screens/settings.tscn") as PackedScene).instantiate()
	st.auto_navigate = false
	add_child_autofree(st)
	await wait_process_frames(2)
	assert_null(st.get("music"))
	assert_null(st.get("sfx"))
	assert_null(st.find_child("Stepper", true, false))
	for l: Node in st.find_children("*", "Label", true, false):
		var t: String = (l as Label).text
		assert_ne(t, "Música")
		assert_ne(t, "Efectos")

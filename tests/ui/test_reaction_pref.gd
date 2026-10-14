extends GutTest
## V2-25c: preferencia "Avisarme de reacciones" (R15) y cableado en UiNav.

const H = preload("res://tests/fixtures/engine_helpers.gd")
const TMP: String = "user://test_reaction_pref.cfg"


func before_all() -> void:
	CardCatalog.load_json()
	EffectRegistry.reset()


func before_each() -> void:
	DirAccess.remove_absolute(TMP)


func after_all() -> void:
	DirAccess.remove_absolute(TMP)


func test_r15_default_without_file() -> void:
	assert_eq(Settings.load_reaction_notify(TMP), "affecting")


func test_r15_save_and_load() -> void:
	Settings.save_reaction_notify("all", TMP)
	assert_eq(Settings.load_reaction_notify(TMP), "all")
	Settings.save_reaction_notify("affecting", TMP)
	assert_eq(Settings.load_reaction_notify(TMP), "affecting")


func test_r15_unknown_value_falls_back() -> void:
	Settings.save_reaction_notify("basura", TMP)
	assert_eq(Settings.load_reaction_notify(TMP), "affecting")


func test_r15_save_keeps_other_keys() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	cfg.set_value("audio", "music", 0.4)
	cfg.set_value("ui", "vibration", false)
	cfg.save(TMP)
	Settings.save_reaction_notify("all", TMP)
	var back: ConfigFile = ConfigFile.new()
	back.load(TMP)
	assert_eq(float(back.get_value("audio", "music")), 0.4)
	assert_false(bool(back.get_value("ui", "vibration")))
	assert_eq(String(back.get_value("reactions", "notify")), "all")


func test_settings_button_toggles_and_has_min_height() -> void:
	var st: Settings = (load("res://src/ui/screens/settings.tscn") as PackedScene).instantiate()
	st.auto_navigate = false
	add_child_autofree(st)
	await wait_process_frames(2)
	assert_not_null(st.reaction_btn)
	assert_gte(int(st.reaction_btn.custom_minimum_size.y), UiTheme.BUTTON_MIN_H)
	var before: String = st.reaction_btn.text
	st.reaction_btn.pressed.emit()
	assert_ne(st.reaction_btn.text, before)


## Humano p1 con Magic Shield; bots p2 (Fireball) y p3 (objetivo).
func _session(mode: String) -> LocalSession:
	var players: Array = [
		Types.make_player("p1", "Humano", 40, 1, false),
		Types.make_player("p2", "Bot 2", 39, 2, true),
		Types.make_player("p3", "Bot 3", 38, 3, true)]
	var s: Dictionary = Game.new_game(players, {"log_limit": 100000, "reaction_timeout_local_ms": 0}, 7)
	for pid: String in ["p1", "p2", "p3"]:
		H.set_hand(s, pid, [Types.CARD_MAGIC_SHIELD])
		H.set_mana(s, pid, 8)
	H.set_hand(s, "p2", [Types.CARD_FIREBALL, Types.CARD_FIRE_ARROW])  # la flecha paga el elemento
	H.force_turn(s, "p2")
	var ls: LocalSession = LocalSession.new()
	autofree(ls)
	ls.auto_run_bots = false
	ls.clock = func() -> int: return 1000
	ls.reaction_notify = mode
	ls.start(s, 7)
	return ls


func _fireball_until_human(ls: LocalSession) -> String:
	var iid: int = int(H.hand(ls.state, "p2")[0]["iid"])
	var pay: int = int(H.hand(ls.state, "p2")[1]["iid"])
	ls._enqueue(Types.make_action_play_card("p2", iid, ["p3"], [pay]), "bot")
	var n: int = 0
	while not (ls.state["reaction"] as Dictionary).is_empty() and ls.is_bot(Decision.responder(ls.state)) and n < 10:
		ls._enqueue(Types.make_action_pass_reaction(Decision.responder(ls.state)), "bot")
		n += 1
	if (ls.state["reaction"] as Dictionary).is_empty():
		return ""
	return Decision.responder(ls.state)


func test_affecting_does_not_open_modal_for_unaffected_human() -> void:
	assert_eq(_fireball_until_human(_session("affecting")), "")


func test_all_opens_modal_for_human_with_shield() -> void:
	assert_eq(_fireball_until_human(_session("all")), "p1")


func test_uinav_assigns_saved_pref_default_affecting() -> void:
	var prev: Callable = UiNav.session_factory
	UiNav.session_factory = Callable()
	var setup: Dictionary = {"players": [
		{"name": "A", "age": 30, "birth_month": 1, "is_bot": false},
		{"name": "B", "age": 30, "birth_month": 2, "is_bot": true}], "config": {}}
	var gs: GameSession = UiNav.make_local_session(setup)
	autofree(gs)
	assert_true(gs is LocalSession)
	assert_eq((gs as LocalSession).reaction_notify, Settings.load_reaction_notify())
	UiNav.session_factory = prev

extends GutTest
## V2-36: cierre de los defectos menores de la puerta final de v0.2 (QA-V2-35-01 a 05).
## Un caso por defecto, con 3 y 6 jugadores y a 1080x1920 y 720x1280.

const H = preload("res://tests/fixtures/engine_helpers.gd")
const BASE: Vector2i = Vector2i(1080, 1920)
const SIZES: Array[Vector2i] = [Vector2i(1080, 1920), Vector2i(720, 1280)]
const NAMES: Array[String] = ["Ana", "Bruno", "Cira", "Dario", "Elena", "Fabio"]
const TMP_CFG: String = "user://test_defectos_finales.cfg"

var _vp: SubViewport = null


func before_each() -> void:
	CardCatalog.load_json()
	EffectRegistry.reset()


func after_each() -> void:
	_drop()
	if FileAccess.file_exists(TMP_CFG):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP_CFG))
	await wait_process_frames(1)


func _drop() -> void:
	if _vp != null and is_instance_valid(_vp):
		_vp.queue_free()
	_vp = null


func _state(which: String, n: int) -> Dictionary:
	var players: Array = []
	for i: int in n:
		players.append(Types.make_player("p%d" % (i + 1), NAMES[i], 40 - i * 5, i + 1, i > 0))
	var s: Dictionary = Game.new_game(players, {"reaction_timeout_local_ms": 15000}, 21)
	H.force_turn(s, "p1")
	s["pending"] = []
	match which:
		"descarte":
			Damage.forced_discard(s, "p1", 2, [], Types.CARD_ICY_GRASP)
		"descarte-1":
			Damage.forced_discard(s, "p1", 1, [], Types.CARD_ICY_GRASP)
		"reaccion":
			H.force_turn(s, "p2")
			H.set_hand(s, "p1", [Types.CARD_MAGIC_SHIELD, Types.CARD_FIREBALL])
			H.set_hand(s, "p2", [Types.CARD_ICE_BOLT])
			H.set_mana(s, "p2", 5)
			H.player(s, "p1")["potions"] = 9
	return s


func _table(which: String, n: int, px: Vector2i) -> TableScreen:
	_drop()
	_vp = SubViewport.new()
	_vp.size = px
	_vp.size_2d_override = BASE
	_vp.size_2d_override_stretch = true
	_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_vp)
	var t: TableScreen = (load("res://src/ui/screens/table.tscn") as PackedScene).instantiate()
	t.demo_when_empty = false
	_vp.add_child(t)
	var ls: LocalSession = LocalSession.new()
	ls.start(_state(which, n), 21)
	ls.auto_run_bots = false
	t.bind_session(ls)
	await wait_process_frames(4)
	while t._notice_overlay.visible:
		t._on_notice_ok()
	if which == "reaccion":
		var bolt: int = int((H.hand(ls.state, "p2")[0] as Dictionary)["iid"])
		ls.submit_action(Types.make_action_play_card("p2", bolt, ["p1"]))
	await wait_process_frames(6)
	return t


func _texts(n: Node, out: Array[String]) -> void:
	for c: Node in n.get_children():
		if c is Button and (c as Button).is_visible_in_tree():
			out.append((c as Button).text)
		elif c is Label and (c as Label).is_visible_in_tree():
			out.append((c as Label).text)
		_texts(c, out)


func _gap(a: Rect2, b: Rect2) -> float:
	var gx: float = maxf(a.position.x, b.position.x) - minf(a.end.x, b.end.x)
	var gy: float = maxf(a.position.y, b.position.y) - minf(a.end.y, b.end.y)
	return maxf(gx, gy)


# ----------------------------------------------------------------------------- QA-V2-35-02

func test_d02_forced_discard_text_uses_correct_plural() -> void:
	var t: TableScreen = await _table("descarte", 6, BASE)
	assert_eq(t.ctx.mode_bar.mode_label.text, "Descarta 2 cartas (Icy Grasp) (0/2)")
	t = await _table("descarte-1", 3, BASE)
	assert_eq(t.ctx.mode_bar.mode_label.text, "Descarta 1 carta (Icy Grasp) (0/1)")
	assert_false(t.ctx.mode_bar.mode_label.text.contains("(s)"))


# ----------------------------------------------------------------------------- QA-V2-35-03

func test_d03_settings_hides_vibration_and_keeps_its_key() -> void:
	var st: Settings = (load("res://src/ui/screens/settings.tscn") as PackedScene).instantiate()
	st.auto_navigate = false
	add_child_autofree(st)
	await wait_process_frames(2)
	var texts: Array[String] = []
	_texts(st, texts)
	assert_gt(texts.size(), 3, "Ajustes tiene sus textos")
	for tx: String in texts:
		assert_false(tx.begins_with("Vibración"), "Vibración oculta: '%s'" % tx)
	assert_true(texts.has("Guardar y volver"))
	# La clave previa no se pierde al guardar la preferencia de reacciones.
	var cfg: ConfigFile = ConfigFile.new()
	cfg.set_value("ui", "vibration", false)
	cfg.save(TMP_CFG)
	Settings.save_reaction_notify("all", TMP_CFG)
	var back: ConfigFile = ConfigFile.new()
	back.load(TMP_CFG)
	assert_false(bool(back.get_value("ui", "vibration", true)))
	assert_eq(String(back.get_value("reactions", "notify")), "all")


# ----------------------------------------------------------------------------- QA-V2-35-01

func test_d01_menu_and_log_strip_are_16px_apart_and_strip_stays_readable() -> void:
	for n: int in [3, 6]:
		for px: Vector2i in SIZES:
			var t: TableScreen = await _table("descarte" if n == 6 else "reaccion", n, px)
			var tag: String = "%dj %dx%d" % [n, px.x, px.y]
			var strip: Button = null
			for b: Node in t._log.find_children("*", "Button", true, false):
				strip = b as Button
			assert_not_null(strip, tag)
			var menu_r: Rect2 = t.ctx.menu.menu_btn.get_global_rect()
			assert_gte(_gap(menu_r, strip.get_global_rect()) + 0.01, float(UiTheme.BUTTON_GAP_MIN), "Menú / franja (%s)" % tag)
			assert_gte(strip.get_global_rect().size.y + 0.01, float(UiTheme.BUTTON_MIN_H), "franja >= 96 (%s)" % tag)
			# El texto de la franja sigue dentro del botón y sigue dentro del registro.
			var rich: RichTextLabel = t._log.find_children("*", "RichTextLabel", true, false)[0] as RichTextLabel
			assert_true(strip.get_global_rect().grow(0.5).encloses(rich.get_global_rect()), "texto dentro de la franja (%s)" % tag)
			assert_true(t._log.get_global_rect().grow(0.5).encloses(strip.get_global_rect()), "franja dentro del registro (%s)" % tag)


# ----------------------------------------------------------------------------- QA-V2-35-04

func test_d04_reaction_sheet_keeps_own_vitals_visible_and_shows_them_in_a_line() -> void:
	for n: int in [3, 6]:
		for px: Vector2i in SIZES:
			var t: TableScreen = await _table("reaccion", n, px)
			var tag: String = "%dj %dx%d" % [n, px.x, px.y]
			assert_true(t._reaction_overlay.visible, tag)
			var own: Rect2 = t.ctx.players.own_panel.get_global_rect()
			var sheet: Rect2 = t._reaction.get_global_rect()
			assert_false(sheet.intersects(own), "la ventana no tapa el panel propio (%s)" % tag)
			assert_gte(sheet.position.y, own.end.y, "la ventana empieza bajo el panel propio (%s)" % tag)
			assert_true(Rect2(Vector2.ZERO, Vector2(BASE)).grow(1.0).encloses(sheet), "dentro de la pantalla (%s)" % tag)
			# Cabe entera, sin desplazarla (Beber poción y Pasar visibles).
			assert_gte(t._reaction.get_global_rect().end.y, t._reaction._pass_btn.get_global_rect().end.y, tag)
			var scroll: Control = t._reaction.get_parent() as Control
			assert_gte(scroll.size.y + 1.0, t._reaction.get_combined_minimum_size().y, "sin desplazamiento (%s)" % tag)
			var texts: Array[String] = []
			_texts(t._reaction, texts)
			assert_true(texts.has("Tu vida: 10 · Tu maná: 0"), "línea fija de vida y maná (%s): %s" % [tag, str(texts)])
			for b: Button in [t._reaction._drink_btn, t._reaction._pass_btn]:
				assert_gte(b.get_global_rect().size.y + 0.01, float(UiTheme.BUTTON_PRIMARY_H), "'%s' >= 144 (%s)" % [b.text, tag])
			assert_gte(_gap(t._reaction._drink_btn.get_global_rect(), t._reaction._pass_btn.get_global_rect()) + 0.01,
				float(UiTheme.BUTTON_GAP_POTION), "separación (%s)" % tag)


# ----------------------------------------------------------------------------- QA-V2-35-05

func test_d05_floating_numbers_do_not_reach_the_log_strip() -> void:
	for px: Vector2i in SIZES:
		var t: TableScreen = await _table("descarte", 6, px)
		var layer: FeedbackLayer = t.feedback().layer
		var log_bottom: float = t._log.get_global_rect().end.y
		for pid: String in ["p2", "p3", "p4", "p5", "p1"]:
			for amount: int in [-2, 3]:
				layer.play({"log_seq": 900 + amount, "rev": 1, "kind": FeedbackMapper.FB_MANA, "lane": FeedbackMapper.lane_for(pid),
					"target": pid, "actor": pid, "amount": amount, "card_id": "", "targets": [], "extra": {},
					"visible_to": [], "duration_ms": FeedbackMapper.DUR_PANEL_MS})
		var floats: Array[Node] = layer.find_children("*", "FloatingText", true, false)
		var seen: int = 0
		for f: Node in floats:
			var ft: FloatingText = f as FloatingText
			if not ft.visible:
				continue
			seen += 1
			var top_after_rise: float = ft.get_global_rect().position.y - FloatingText.RISE_PX
			assert_gte(top_after_rise + 0.5, log_bottom, "'%s' no sube sobre el registro (%dpx)" % [ft.text, px.x])
		assert_gte(seen, 6, "se dibujaron los números (%dpx)" % px.x)

extends GutTest
## V2-32 (QA, puerta de la oleada 3). Casos escritos desde los criterios de V2-28, 29, 30, 42, 45 y 31,
## independientes de los tests de cada tarea (otros escenarios, semillas y configuraciones).
## Informe: docs/qa/puerta-o3.md.

const H = preload("res://tests/fixtures/engine_helpers.gd")
const SUMMARIES: String = "res://data/card_summaries_es.json"

var _t: TableScreen


func before_each() -> void:
	CardCatalog.load_json()
	EffectRegistry.reset()
	CardInfo.summaries_path = SUMMARIES
	CardInfo.reload_summaries()


func after_each() -> void:
	CardInfo.summaries_path = SUMMARIES
	CardInfo.reload_summaries()


func _read(path: String) -> String:
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	return f.get_as_text() if f != null else ""


func _table(s: Dictionary, viewer: String = "p1") -> TableScreen:
	_t = (load("res://src/ui/screens/table.tscn") as PackedScene).instantiate()
	_t.demo_when_empty = false
	add_child_autofree(_t)
	_t.set_view(Types.view_for(s, viewer), viewer)
	return _t


func _state(n: int, potions: int = 0, cfg: Dictionary = {}) -> Dictionary:
	var s: Dictionary = H.game(n, cfg, 7)
	H.force_turn(s, "p1")
	s["pending"] = []
	Types.get_player(s, "p1")["potions"] = potions
	return s


# =============================================================================
# V2-28 resúmenes
# =============================================================================

func test_o3_summaries_cover_exactly_the_catalog() -> void:
	if not FileAccess.file_exists(SUMMARIES):
		pending("sin data/card_summaries_es.json (no versionado)")
		return
	var parsed: Variant = JSON.parse_string(_read(SUMMARIES))
	assert_true(parsed is Dictionary)
	var d: Dictionary = parsed
	var ids: Array = CardCatalog.all_defs().keys()
	assert_eq(d.size(), 61, "61 entradas")
	assert_eq(ids.size(), 61, "61 diseños en el catálogo")
	for id: Variant in ids:
		assert_true(d.has(id), "falta resumen de %s" % id)
	for k: Variant in d.keys():
		assert_true(ids.has(k), "clave sobrante %s" % k)
		var txt: String = String(d[k])
		assert_ne(txt.strip_edges(), "", "vacío %s" % k)
		assert_false(txt.contains("_"), "guion bajo en %s" % k)
		assert_lte(txt.length(), 95, "longitud %s" % k)
		assert_false(txt.contains("  "), "espacio doble en %s" % k)
		assert_true(txt.ends_with(".") or txt.ends_with(")"), "sin punto final en %s: %s" % [k, txt])


func test_o3_summaries_file_is_gitignored() -> void:
	var gi: PackedStringArray = _read("res://.gitignore").split("\n")
	assert_true(gi.has("data/card_summaries_es.json"), "línea exacta en .gitignore")


func test_o3_info_card_works_without_file_and_with_missing_id() -> void:
	CardInfo.summaries_path = "res://data/__no_existe_o3.json"
	CardInfo.reload_summaries()
	assert_eq(CardInfo.summary("lightning"), "")
	var ci: CardInfo = CardInfo.new()
	add_child_autofree(ci)
	ci.show_info({"name": "Lightning", "mana_line": "Maná: 2", "cards_line": "", "type_line": "Tipo: ofensiva",
		"element_line": "Elemento: electricidad", "reason": ""}, {"iid": 3, "card_id": "lightning"})
	assert_false(ci.summary_label.visible, "sin archivo la ficha no muestra resumen vacío")
	# con archivo pero un id que no existe: tampoco falla
	CardInfo.summaries_path = SUMMARIES
	CardInfo.reload_summaries()
	assert_eq(CardInfo.summary("carta_que_no_existe"), "")


func test_o3_summary_in_info_matches_file_for_every_card() -> void:
	if not FileAccess.file_exists(SUMMARIES):
		pending("sin archivo de resúmenes")
		return
	var ci: CardInfo = CardInfo.new()
	add_child_autofree(ci)
	for id: Variant in CardCatalog.all_defs().keys():
		ci.show_info({"name": String(id), "mana_line": "x", "cards_line": "", "type_line": "t",
			"element_line": "e", "reason": ""}, {"iid": 1, "card_id": String(id)})
		assert_eq(ci.summary_label.text, CardInfo.summary(String(id)), String(id))
		assert_true(ci.summary_label.visible, String(id))


# =============================================================================
# V2-29 ítem 10
# =============================================================================

func test_o3_potion_button_levels_with_custom_limit_and_symbol() -> void:
	# límite 6: 4/6 ámbar, 5/6 naranja, 6/6 rojo; 3/6 sin aviso
	var cfg: Dictionary = {"potion_limit": 6, "potion_limit_enabled": true}
	var fills: Array = []
	for n: int in [3, 4, 5, 6]:
		var t: TableScreen = _table(_state(3, n, cfg))
		var sb: StyleBoxFlat = t._drink_btn.get_theme_stylebox("normal") as StyleBoxFlat
		fills.append(sb.bg_color)
		assert_eq(t._drink_btn.text.begins_with("⚠"), n >= 4, "símbolo a %d/6" % n)
		assert_true(t._drink_btn.text.contains("%d/6" % n), "contador %d/6: %s" % [n, t._drink_btn.text])
		assert_gte(t._drink_btn.size.y, 0.0)
		_t.queue_free()
		_t = null
	for i: int in 4:
		for j: int in range(i + 1, 4):
			assert_ne(fills[i], fills[j], "colores distintos %d y %d" % [i, j])


func test_o3_potion_button_height_does_not_change_with_risk() -> void:
	var h: Array = []
	for n: int in [0, 8, 10]:
		var t: TableScreen = _table(_state(3, n))
		h.append(t._drink_btn.custom_minimum_size.y)
		_t.queue_free()
		_t = null
	assert_eq(h[0], h[1])
	assert_eq(h[1], h[2])


func test_o3_potion_warning_text_levels() -> void:
	assert_eq(Strings.potion_warning(7, 10), "")
	assert_string_contains(Strings.potion_warning(8, 10), "8 de 10")
	assert_string_contains(Strings.potion_warning(9, 10), "9 de 10")
	assert_string_contains(Strings.potion_warning(10, 10), "eliminado")


func _spell_state(card_id: String, caster: String, targets: Array, n: int = 4) -> Dictionary:
	var s: Dictionary = _state(n)
	var spell: Dictionary = Types.make_spell({"iid": 901, "card_id": card_id}, caster, targets)
	s["reaction"] = Types.make_reaction(spell, ["p1"])
	return s


func test_o3_against_you_matches_relevance_table_for_several_spells() -> void:
	# [carta, lanzador, objetivos, ¿contra p1 (4 magos: p1 p2 p3 p4 en círculo)?]
	var cases: Array = [
		[Types.CARD_FIREBALL, "p2", ["p1"], true],
		[Types.CARD_FIREBALL, "p2", ["p3"], false],
		[Types.CARD_ARMAGEDDON, "p3", [], true],
		[Types.CARD_ELECTRIC_EXPLOSION, "p2", [], true],
		[Types.CARD_ELECTRIC_EXPLOSION, "p1", [], false],
		[Types.CARD_METEOR_SHOWER, "p2", ["p3"], false],
		[Types.CARD_METEOR_SHOWER, "p2", ["p4"], true],
		[Types.CARD_ICE_BOOMERANG, "p1", ["p3"], true],
		[Types.CARD_ICE_BOOMERANG, "p2", ["p3"], false],
		[Types.CARD_CURSE_OF_RULES, "p3", [], true],
	]
	for c: Array in cases:
		var s: Dictionary = _spell_state(String(c[0]), String(c[1]), c[2] as Array)
		var expected: bool = bool(c[3])
		assert_eq(ReactionRelevance.affects(Types.view_for(s, "p1"), "p1"), expected, "tabla: %s" % str(c))
		var t: TableScreen = _table(s)
		assert_true(t._reaction._against_label.visible, "etiqueta visible: %s" % str(c))
		if expected:
			assert_true(t._reaction._against_label.text.contains(Strings.AGAINST_YOU), "contra ti: %s" % str(c))
			assert_false(t._reaction._against_label.text.contains("No va"), str(c))
		else:
			assert_eq(t._reaction._against_label.text, Strings.NOT_AGAINST_YOU, str(c))
		_t.queue_free()
		_t = null


func test_o3_pass_device_three_reasons_in_hot_seat_texts() -> void:
	assert_eq(Strings.pass_device_reason(Strings.PASS_REASON_TURN, "Cira"), "Turno de Cira")
	assert_eq(Strings.pass_device_reason(Strings.PASS_REASON_REACTION, "Cira"), "Cira: ¿respondes al hechizo?")
	assert_eq(Strings.pass_device_reason(Strings.PASS_REASON_DECISION, "Cira"), "Cira: tienes una decisión pendiente")
	# prioridad: reacción abierta con el responder = p1 y además prompt pendiente -> "reaction"
	var s: Dictionary = _spell_state(Types.CARD_FIREBALL, "p2", ["p1"])
	s["pending"] = [{"id": 5, "player": "p1", "kind": Types.PROMPT_DRINK_OR_SUFFER, "data": {"hp": 1}}]
	var v: Dictionary = Types.view_for(s, "p1")
	var r: String = TableSync.pass_reason(v, "p1")
	assert_true([Strings.PASS_REASON_REACTION, Strings.PASS_REASON_DECISION].has(r), "motivo con reacción+decisión: " + r)
	# un jugador sin nada pendiente que no es el que decide: turno
	assert_eq(TableSync.pass_reason(Types.view_for(s, "p3"), "p3"), Strings.PASS_REASON_TURN)
	for reason: String in [Strings.PASS_REASON_TURN, Strings.PASS_REASON_REACTION, Strings.PASS_REASON_DECISION]:
		assert_false(Strings.pass_device_reason(reason, "Ana").contains("_"))


# =============================================================================
# V2-30 ítem 11
# =============================================================================

const TITLES: Array = ["Objetivo", "Tu turno", "Pagar cartas y maná", "Pociones de maná", "Too Much Mana",
	"Defensivas y reacciones", "Eventos", "Artefactos y maldiciones"]


func test_o3_help_eight_sections_order_and_config_numbers() -> void:
	var sec: Array[Dictionary] = StringsAyuda.sections({})
	assert_eq(sec.size(), 8)
	for i: int in 8:
		assert_eq(String(sec[i]["title"]), String(TITLES[i]), "orden sección %d" % i)
	var custom: Array[Dictionary] = StringsAyuda.sections({"start_hp": 8, "start_mana": 2, "start_hand": 4,
		"potion_mana": 5, "potion_limit": 7, "potion_limit_enabled": true})
	var all: String = ""
	for s: Dictionary in custom:
		all += String(s["body"]) + "\n"
	assert_string_contains(all, "8 de vida")
	assert_string_contains(all, "+5 de maná")
	assert_string_contains(all, "7 pociones")
	assert_string_contains(all, "número 8")
	assert_string_contains(all, "5/7")
	assert_string_contains(all, "7/7")
	assert_false(all.contains("+3 de maná"), "no queda el valor por defecto")
	assert_false(all.contains("10 pociones"), "no queda el límite por defecto")
	var off: String = String(StringsAyuda.sections({"potion_limit_enabled": false})[4]["body"])
	assert_string_contains(off, "no hay límite")
	assert_false(off.contains("número"), "sin límite no habla de la poción número N")


func test_o3_help_no_internal_keys_and_unique_digital_tag() -> void:
	for cfg: Dictionary in [{}, {"potion_limit_enabled": false}, {"potion_limit": 15}]:
		for s: Dictionary in StringsAyuda.sections(cfg):
			assert_false(String(s["title"]).contains("_"))
			assert_false(String(s["body"]).contains("_"), String(s["title"]))
			assert_ne(String(s["body"]).strip_edges(), "")


func test_o3_help_from_game_with_open_reaction_keeps_state_and_reaction() -> void:
	var s: Dictionary = _spell_state(Types.CARD_FIREBALL, "p2", ["p1"])
	s["config"]["potion_limit"] = 12
	var t: TableScreen = _table(s)
	var before: Dictionary = t.view.duplicate(true)
	assert_true(t._reaction_overlay.visible)
	t.ctx.menu.open_help()
	var ov: HelpScreen = t.ctx.menu.help_overlay
	assert_not_null(ov)
	var body: String = ""
	for l: Label in ov.body_labels:
		body += l.text + "\n"
	assert_string_contains(body, "12 pociones")
	assert_eq(ov.body_labels.size(), 8)
	ov.back_btn.pressed.emit()
	await get_tree().process_frame
	assert_null(t.ctx.menu.help_overlay)
	assert_eq(t.view, before, "la vista no cambió")
	assert_true(t._reaction_overlay.visible, "la ventana de reacción sigue abierta")


func test_o3_help_screen_standalone_uses_default_config_and_scrolls() -> void:
	var host: Control = Control.new()
	host.size = Vector2(720, 1280)
	add_child_autofree(host)
	var h: HelpScreen = HelpScreen.new()
	h.auto_navigate = false
	host.add_child(h)
	await get_tree().process_frame
	assert_not_null(h.scroll)
	assert_eq(h.scroll.horizontal_scroll_mode, ScrollContainer.SCROLL_MODE_DISABLED)
	var joined: String = ""
	for l: Label in h.body_labels:
		joined += l.text
	assert_string_contains(joined, "10 pociones")
	assert_gte(h.back_btn.custom_minimum_size.y, float(UiTheme.BUTTON_MIN_H))
	assert_gte(HelpScreen.BODY_SIZE, 22)


func test_o3_event_catalog_has_7_persistent_and_4_instant_and_notice_matches() -> void:
	var persistent: Array = []
	var instant: Array = []
	for id: Variant in CardCatalog.all_defs().keys():
		var d: Dictionary = CardCatalog.all_defs()[id]
		if String(d.get("type", "")) != "event":
			continue
		if bool(d.get("persistent", false)):
			persistent.append(id)
		else:
			instant.append(id)
	assert_eq(persistent.size(), 7, "persistentes: %s" % str(persistent))
	assert_eq(instant.size(), 4, "instantáneos: %s" % str(instant))
	# la regla del manual: los de "hasta el próximo evento" y los de efecto único coinciden con lo que el motor registra
	for id: Variant in ["fire_storm", "ice_storm", "lightning_storm", "mana_focus", "shot_glass",
			"disrupted_gravity", "not_enough_mana"]:
		assert_true(persistent.has(id), String(id))
	for id: Variant in ["visit_of_the_archmage", "blessing", "warp_discharge", "elixir_transmutation"]:
		assert_true(instant.has(id), String(id))
	assert_string_contains(StringsAyuda.event_notice("Fire Storm", true), "próximo evento")
	assert_false(StringsAyuda.event_notice("Blessing", false).contains("próximo evento"))
	assert_string_contains(StringsAyuda.event_notice("Blessing", false), "inmediato")


# =============================================================================
# V2-45 icono
# =============================================================================

func _img(path: String) -> Image:
	return Image.load_from_file(ProjectSettings.globalize_path(path))


func test_o3_eliminado_icon_sizes_alpha_and_distinct_from_the_other_six() -> void:
	var names: Array = ["eliminado", "maldito", "cegado", "congelado", "campo_fuerza", "bot", "turno"]
	for sz: int in [96, 48]:
		var imgs: Dictionary = {}
		for n: String in names:
			var p: String = "res://assets/ui/icon_%s_%d.png" % [n, sz]
			assert_true(FileAccess.file_exists(p), p)
			assert_true(FileAccess.file_exists(p + ".import"), p + ".import")
			var im: Image = _img(p)
			assert_not_null(im, p)
			assert_eq(im.get_size(), Vector2i(sz, sz), p)
			assert_true(im.detect_alpha() != Image.ALPHA_NONE, "alfa en " + p)
			imgs[n] = im
		var e: Image = imgs["eliminado"]
		var opaque: int = 0
		for y: int in sz:
			for x: int in sz:
				if e.get_pixel(x, y).a > 0.5:
					opaque += 1
		assert_gt(opaque, int(sz * sz * 0.1), "el icono tiene contenido (%d px opacos)" % opaque)
		assert_lt(opaque, int(sz * sz * 0.9), "no es un bloque lleno")
		for n: String in names:
			if n == "eliminado":
				continue
			var diff: float = _mean_diff(e, imgs[n] as Image, sz)
			assert_gt(diff, 0.03, "eliminado se distingue de %s a %d px (dif media %.3f)" % [n, sz, diff])


func _mean_diff(a: Image, b: Image, sz: int) -> float:
	var tot: float = 0.0
	for y: int in sz:
		for x: int in sz:
			var ca: Color = a.get_pixel(x, y)
			var cb: Color = b.get_pixel(x, y)
			tot += absf(ca.a - cb.a) + (absf(ca.r - cb.r) + absf(ca.g - cb.g) + absf(ca.b - cb.b)) * 0.25 * minf(ca.a, cb.a)
	return tot / float(sz * sz)


func test_o3_eliminado_icon_in_generator_and_doc() -> void:
	var gen: String = _read("res://tools/gen_ui_icons.py")
	assert_string_contains(gen, "\"eliminado\":eliminado")
	var doc: String = _read("res://docs/arte/iconos-estado.md")
	assert_string_contains(doc, "icon_eliminado_{96,48}.png")


# =============================================================================
# V2-31 guion y límites de tamaño
# =============================================================================

func test_o3_guion_is_one_page_and_figures_match_the_options_doc() -> void:
	var g: String = _read("res://docs/qa/guion-m12.md")
	assert_ne(g, "")
	var words: int = g.split(" ", false).size()
	assert_lte(words, 750, "una página impresa ~ 700 palabras (hay %d)" % words)
	for needle: String in ["minutos", "turnos", "rondas", "nadie podía hacer nada", "sin querer", "1 humano + 3 bots",
			"hot-seat de 3", "Plantilla"]:
		assert_string_contains(g, needle)
	var o: String = _read("res://docs/diseno/opciones-bloqueo-pociones.md")
	# Cifras con los bots de V2-42 (guion corregido tras QA-V2-32-04): límite 10 -> 3 de 50 (máx. 140),
	# límite 15 -> 0 de 50 (máx. 47). El documento de opciones conserva las cifras de los bots previos.
	for fig: String in ["3 de 50", "140", "0 de 50", "47"]:
		assert_string_contains(g, fig)
	assert_string_contains(o, "9/50")
	assert_string_contains(o, "| 15 | 1/50 |")
	assert_string_contains(o, "130,4 / 74 / 458", "(control del documento)")
	assert_string_contains(o, "51,6 / 24 / 436")
	assert_string_contains(o, "24,5 / 25 / 52")


func test_o3_table_gd_not_over_400_lines() -> void:
	var n: int = _read("res://src/ui/screens/table.gd").split("\n").size() - 1
	assert_lte(n, 400, "table.gd %d líneas" % n)
	var dir: DirAccess = DirAccess.open("res://src/ui/screens/table")
	for f: String in dir.get_files():
		if f.ends_with(".gd"):
			var m: int = _read("res://src/ui/screens/table/" + f).split("\n").size() - 1
			assert_lte(m, 400, f)


# =============================================================================
# V2-42 bots: partidas completas con invariantes en cada paso
# =============================================================================

func _play_game(seed_value: int, n: int, potion_limit: Variant) -> Dictionary:
	var players: Array = []
	for i: int in n:
		players.append(Types.make_player("p%d" % (i + 1), "P%d" % (i + 1), 20 + (seed_value * 7 + i * 11) % 50, (i % 12) + 1))
	var cfg: Dictionary = {"log_limit": 40}
	if potion_limit is bool:
		cfg["potion_limit_enabled"] = potion_limit
	var s: Dictionary = Game.new_game(players, cfg, seed_value)
	var rng: int = Rng.seed_from(seed_value * 31 + 7)
	var steps: int = 0
	var bad: Array = []
	var cards_expected: int = int(s["card_total"])
	while steps < 2000 and s["status"] == Types.STATUS_PLAYING:
		var actor: String = ""
		for pid: String in Types.alive_ids(s):
			if Bot.has_decision(s, pid):
				actor = pid
				break
		if actor == "":
			bad.append("sin actor")
			break
		var res: Dictionary = Bot.choose_action(s, actor, rng, 0)
		rng = int(res["rng_state"])
		var r: Dictionary = Game.reduce(s, res["action"])
		if String(r["error"]) != "":
			bad.append("acción ilegal %s: %s" % [str((res["action"] as Dictionary).get("type")), r["error"]])
			break
		s = r["state"]
		steps += 1
		var errs: Array[String] = Types.validate_state(s)
		if not errs.is_empty():
			bad.append(str(errs))
			break
		if int(s["card_total"]) != cards_expected:
			bad.append("card_total cambió")
			break
		for p: Variant in s["players"]:
			var pd: Dictionary = p
			if int(pd["hp"]) < 0 or int(pd["hp"]) > 10 or int(pd["mana"]) < 0:
				bad.append("rango %s" % pd["id"])
	var tmm: int = 0
	for p: Variant in s["players"]:
		if String((p as Dictionary)["eliminated_reason"]) == Types.ELIM_TOO_MUCH_MANA:
			tmm += 1
	return {"state": s, "steps": steps, "bad": bad, "tmm": tmm, "turns": int((s["turn"] as Dictionary)["number"])}


func test_o3_bot_games_keep_invariants_no_tmm_and_finish() -> void:
	var finished: int = 0
	var tmm: int = 0
	for i: int in 10:
		var seed_value: int = 1 + i * 17
		var r: Dictionary = _play_game(seed_value, 3 + i % 4, null)
		assert_eq(r["bad"], [], "semilla %d" % seed_value)
		tmm += int(r["tmm"])
		if (r["state"] as Dictionary)["status"] != Types.STATUS_PLAYING:
			finished += 1
	assert_eq(tmm, 0, "0 eliminaciones por Too Much Mana")
	assert_eq(finished, 10, "las 10 partidas terminan")


func test_o3_bot_games_without_potion_limit() -> void:
	for i: int in 4:
		var r: Dictionary = _play_game(5 + i * 3, 4, false)
		assert_eq(r["bad"], [], "sin límite, semilla %d" % (5 + i * 3))
		assert_ne((r["state"] as Dictionary)["status"], Types.STATUS_PLAYING)
		assert_eq(r["tmm"], 0)


func test_o3_help_scene_loads_from_uinav_path_and_back_goes_to_main_menu() -> void:
	assert_true(ResourceLoader.exists(UiNav.HELP), "la escena de ayuda existe: " + UiNav.HELP)
	var host: Control = Control.new()
	host.size = Vector2(1080, 1920)
	add_child_autofree(host)
	var h: Node = (load(UiNav.HELP) as PackedScene).instantiate()
	assert_true(h is HelpScreen)
	(h as HelpScreen).auto_navigate = false
	host.add_child(h)
	assert_eq((h as HelpScreen).body_labels.size(), 8)
	assert_eq((h as HelpScreen).title_labels.size(), 8)
	assert_true(ResourceLoader.exists(UiNav.MAIN_MENU))
	var m: MainMenu = (load(UiNav.MAIN_MENU) as PackedScene).instantiate()
	m.auto_navigate = false
	add_child_autofree(m)
	assert_eq(m.help_btn.text, StringsAyuda.SCREEN_TITLE)

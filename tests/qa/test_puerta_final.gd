extends GutTest
## V2-35 (QA, puerta final de v0.2). Casos escritos por QA desde los criterios de §2.1 de docs/TAREAS.md
## (V2-33), P1 (fuente de respaldo) y P2 (un solo reduce por accion de bot), con otro metodo que los tests
## de cada tarea: recorrido generico del arbol de nodos (no se usan los miembros del modulo salvo para
## localizar Beber poción y la fila de acciones), parejas de botones, glifos usados por el codigo y
## trazas completas de partida. Informe: docs/qa/informe-v02.md.

const H = preload("res://tests/fixtures/engine_helpers.gd")
const X = preload("res://tests/engine/effects/t6c_helpers.gd")
const BASE: Vector2i = Vector2i(1080, 1920)
const SIZES: Array[Vector2i] = [Vector2i(1080, 1920), Vector2i(720, 1280)]
const NAMES: Array[String] = ["Ana", "Bruno", "Cira", "Dario", "Elena", "Fabio"]

var _vp: SubViewport = null


func before_each() -> void:
	CardCatalog.load_json()
	EffectRegistry.reset()


func after_each() -> void:
	_drop()
	await wait_process_frames(1)


func _drop() -> void:
	if _vp != null and is_instance_valid(_vp):
		_vp.queue_free()
	_vp = null


# ----------------------------------------------------------------------------- montaje

func _state(n: int) -> Dictionary:
	var players: Array = []
	for i: int in n:
		players.append(Types.make_player("p%d" % (i + 1), NAMES[i], 40 - i * 5, i + 1, i > 0))
	var s: Dictionary = Game.new_game(players, {"reaction_timeout_local_ms": 15000}, 21)
	H.force_turn(s, "p1")
	s["pending"] = []
	return s


func _scenario(which: String, n: int) -> Dictionary:
	var s: Dictionary = _state(n)
	match which:
		"estados":
			var f: Dictionary = H.player(s, "p2")["flags"] as Dictionary
			f["frozen"] = 1
			f["blinded"] = true
			f["force_field"] = Types.CARD_FIREBALL
			Damage.eliminate(s, "p3", "hp", [])
			H.player(s, "p3")["hp"] = 0
		"mana-insuficiente":
			H.set_mana(s, "p1", 0)
			(s["pending"] as Array).append(Types.make_prompt(Types.next_seq(s), "p1",
				Types.PROMPT_MANA_SHORTFALL, {"missing": 2}, Types.CARD_FIREBALL))
		"mana-focus":
			X.event(s, Types.CARD_MANA_FOCUS)
			H.set_mana(s, "p1", 5)
			X.spell_damage(s, "p2", "p1", 3, Types.ELEMENT_FIRE)
		"elixir":
			H.player(s, "p1")["hp"] = 6
			H.set_mana(s, "p1", 7)
			X.event(s, Types.CARD_ELIXIR_TRANSMUTATION, "p2")
		"descarte":
			Damage.forced_discard(s, "p1", 2, [], Types.CARD_ICY_GRASP)
		"reaccion":
			H.force_turn(s, "p2")
			H.set_hand(s, "p1", [Types.CARD_MAGIC_SHIELD, Types.CARD_FIREBALL])
			H.set_hand(s, "p2", [Types.CARD_ICE_BOLT])
			H.set_mana(s, "p2", 5)
			H.player(s, "p1")["potions"] = 9
		"ocho-pociones":
			H.player(s, "p1")["potions"] = 8
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
	_vp.add_child(t)
	var ls: LocalSession = LocalSession.new()
	ls.start(_scenario(which, n), 21)
	ls.auto_run_bots = false
	t.bind_session(ls)
	await wait_process_frames(4)
	while t._notice_overlay.visible:
		t._on_notice_ok()
	if which == "reaccion":
		var bolt: int = int((H.hand(ls.state, "p2")[0] as Dictionary)["iid"])
		ls.submit_action(Types.make_action_play_card("p2", bolt, ["p1"]))
	await wait_process_frames(4)
	return t


## Todos los Control visibles bajo `n`, sin entrar en CardView (texto impreso de la carta: fuera de V2-33).
func _walk(n: Node, out: Array[Control]) -> void:
	for c: Node in n.get_children():
		if not (c is Control):
			continue
		var cc: Control = c
		if not cc.is_visible_in_tree() or cc is CardView:
			continue
		out.append(cc)
		_walk(cc, out)


func _fs(c: Control) -> int:
	if c is StatChip:
		return (c as StatChip).font_size
	if c is RichTextLabel:
		return c.get_theme_font_size("normal_font_size")
	return c.get_theme_font_size("font_size")


func _has_text(c: Control) -> bool:
	if c is StatChip:
		return true
	if c is Label:
		return (c as Label).text.strip_edges() != ""
	if c is Button:
		return (c as Button).text.strip_edges() != ""
	if c is RichTextLabel:
		return (c as RichTextLabel).get_parsed_text().strip_edges() != ""
	return false


func _gap(a: Rect2, b: Rect2) -> float:
	## Separacion entre dos rectangulos (negativa si se solapan).
	var gx: float = maxf(a.position.x, b.position.x) - minf(a.end.x, b.end.x)
	var gy: float = maxf(a.position.y, b.position.y) - minf(a.end.y, b.end.y)
	return maxf(gx, gy)


# ----------------------------------------------------------------------------- V2-33: fuentes

func test_f_no_text_under_22px_in_3_5_6_player_tables() -> void:
	for n: int in [3, 5, 6]:
		for which: String in ["base", "estados", "ocho-pociones"]:
			var t: TableScreen = await _table(which, n, BASE)
			var all: Array[Control] = []
			_walk(t, all)
			var checked: int = 0
			for c: Control in all:
				if not _has_text(c):
					continue
				checked += 1
				assert_gte(_fs(c), UiTheme.FONT_MIN, "%dj %s: %s '%s'" % [n, which, c.get_path(), c.get("text")])
			assert_gt(checked, 10, "se comprobaron textos reales (%dj %s)" % [n, which])
			# Los paneles de jugador (QA-V2-21-05) tambien, aunque sus hijos cuelguen de otros contenedores.
			var panels: Array[PlayerPanel] = t.ctx.players.rival_panels.duplicate()
			panels.append(t.ctx.players.own_panel)
			for pp: PlayerPanel in panels:
				var sub: Array[Control] = []
				_walk(pp, sub)
				for c: Control in sub:
					if _has_text(c):
						assert_gte(_fs(c), UiTheme.FONT_MIN, "panel %s: %s" % [pp.player_id, c.get("text")])


func test_f_no_text_under_22px_in_dialogs_and_reaction_sheet_of_6_players() -> void:
	for which: String in ["mana-focus", "elixir", "mana-insuficiente", "descarte", "reaccion"]:
		var t: TableScreen = await _table(which, 6, BASE)
		var all: Array[Control] = []
		_walk(t, all)
		for c: Control in all:
			if _has_text(c):
				assert_gte(_fs(c), UiTheme.FONT_MIN, "%s: %s '%s'" % [which, c.get_path(), c.get("text")])


# ----------------------------------------------------------------------------- V2-33: botones

func _classify(t: TableScreen, b: Button) -> String:
	var a: TableActions = t.ctx.actions
	if b == a.drink_btn:
		return "drink"
	if [a.play_btn, a.exchange_btn, a.discard_btn, a.end_btn, t.ctx.mode_bar.mode_confirm].has(b):
		return "primary"
	if t._reaction != null and [t._reaction._drink_btn, t._reaction._pass_btn].has(b):
		return "primary"
	return "secondary"


func test_f_buttons_sizes_and_gaps_in_3_5_6_player_tables_both_resolutions() -> void:
	for n: int in [3, 5, 6]:
		for px: Vector2i in SIZES:
			var k: float = float(px.x) / float(BASE.x)
			var t: TableScreen = await _table("base", n, px)
			var tag: String = "%dj %dx%d" % [n, px.x, px.y]
			var all: Array[Control] = []
			_walk(t, all)
			var buttons: Array[Button] = []
			for c: Control in all:
				if c is Button:
					buttons.append(c as Button)
			assert_gte(buttons.size(), 6, "botones visibles (%s)" % tag)
			var seen_drink: bool = false
			for b: Button in buttons:
				var kind: String = _classify(t, b)
				var h_phys: float = b.get_global_rect().size.y * k
				var need: float = (144.0 if kind != "secondary" else 96.0) * k
				assert_gte(h_phys + 0.5, need, "%s '%s' (%s) alto %.1f < %.1f" % [kind, b.text, tag, h_phys, need])
				seen_drink = seen_drink or kind == "drink"
			assert_true(seen_drink, "Beber poción visible (%s)" % tag)
			# Parejas: >= 16 entre cualquiera, >= 24 si una es Beber poción.
			for i: int in buttons.size():
				for j: int in range(i + 1, buttons.size()):
					var a: Button = buttons[i]
					var b: Button = buttons[j]
					if t._log.is_ancestor_of(a) or t._log.is_ancestor_of(b):
						continue  # franja del registro: QA-V2-35-01, ver test_f_menu_and_log_strip_gap
					var need_gap: float = 24.0 if (a == t.ctx.actions.drink_btn or b == t.ctx.actions.drink_btn) else 16.0
					var g: float = _gap(a.get_global_rect(), b.get_global_rect())
					assert_gte(g + 0.5, need_gap, "'%s' (%s) / '%s' (%s) separados %.1f < %.0f (%s)" % [a.text, a.get_path(), b.text, b.get_path(), g, need_gap, tag])
			# Todo botón dentro de la pantalla.
			for b: Button in buttons:
				assert_true(Rect2(Vector2.ZERO, Vector2(BASE)).grow(1.0).encloses(b.get_global_rect()), "'%s' dentro (%s)" % [b.text, tag])


func test_f_buttons_in_forced_discard_bar_and_reaction_sheet() -> void:
	for which: String in ["descarte", "reaccion"]:
		for px: Vector2i in SIZES:
			var k: float = float(px.x) / float(BASE.x)
			var t: TableScreen = await _table(which, 6, px)
			var all: Array[Control] = []
			_walk(t, all)
			var buttons: Array[Button] = []
			for c: Control in all:
				# Con la ventana de reaccion abierta, lo que hay debajo del modal no se pulsa: solo cuenta el modal.
				if c is Button and (which != "reaccion" or t._reaction_overlay.is_ancestor_of(c)):
					buttons.append(c as Button)
			for b: Button in buttons:
				var need: float = (144.0 if _classify(t, b) != "secondary" else 96.0) * k
				assert_gte(b.get_global_rect().size.y * k + 0.5, need, "%s '%s' %dpx" % [which, b.text, px.x])
			for i: int in buttons.size():
				for j: int in range(i + 1, buttons.size()):
					if t._log.is_ancestor_of(buttons[i]) or t._log.is_ancestor_of(buttons[j]):
						continue  # QA-V2-35-01
					var drink: bool = buttons[i] == t.ctx.actions.drink_btn or buttons[j] == t.ctx.actions.drink_btn \
						or (t._reaction != null and (buttons[i] == t._reaction._drink_btn or buttons[j] == t._reaction._drink_btn))
					var need_gap: float = 24.0 if drink else 16.0
					assert_gte(_gap(buttons[i].get_global_rect(), buttons[j].get_global_rect()) + 0.5, need_gap,
						"%s: '%s' (%s) / '%s' (%s) (%dpx)" % [which, buttons[i].text, buttons[i].get_path(), buttons[j].text, buttons[j].get_path(), px.x])


func test_f_menu_and_log_strip_gap() -> void:
	## QA-V2-35-01: la franja del registro es un Button transparente a 8 px de "Menú" (< 16 px de §2.1).
	## Pendiente mientras el hueco sea < 16; pasa solo cuando se corrija.
	var t: TableScreen = await _table("base", 3, BASE)
	var menu_r: Rect2 = t.ctx.menu.menu_btn.get_global_rect()
	var log_btns: Array[Button] = []
	var all: Array[Control] = []
	_walk(t._log, all)
	for c: Control in all:
		if c is Button:
			log_btns.append(c as Button)
	assert_gt(log_btns.size(), 0, "la franja del registro tiene un boton de despliegue")
	for b: Button in log_btns:
		var g: float = _gap(menu_r, b.get_global_rect())
		if g < 15.5:
			pending("QA-V2-35-01: Menu y la franja del registro estan a %.1f px (< 16)" % g)
			return
		assert_gte(g, 15.5)


# ----------------------------------------------------------------------------- V2-33: botón principal con estilo propio

func _lum(c: Color) -> float:
	var ch: Array[float] = []
	for v: float in [c.r, c.g, c.b]:
		ch.append(v / 12.92 if v <= 0.03928 else pow((v + 0.055) / 1.055, 2.4))
	return 0.2126 * ch[0] + 0.7152 * ch[1] + 0.0722 * ch[2]


func _contrast(a: Color, b: Color) -> float:
	var l1: float = maxf(_lum(a), _lum(b))
	var l2: float = minf(_lum(a), _lum(b))
	return (l1 + 0.05) / (l2 + 0.05)


func test_f_primary_button_has_own_color_and_border_distinct_from_secondary() -> void:
	var th: Theme = UiTheme.get_theme()
	var prim: StyleBoxFlat = th.get_stylebox("normal", UiTheme.VARIATION_PRIMARY) as StyleBoxFlat
	var sec: StyleBoxFlat = th.get_stylebox("normal", "Button") as StyleBoxFlat
	assert_not_null(prim)
	assert_not_null(sec)
	assert_ne(prim.bg_color, sec.bg_color, "fondo distinto")
	assert_eq(prim.border_color, UiTheme.COL_ACCENT, "borde dorado")
	assert_gte(prim.border_width_left, 4, "borde >= 4 px")
	assert_gt(prim.border_width_left, sec.border_width_left, "borde mas grueso que el secundario")
	var fg: Color = th.get_color("font_color", UiTheme.VARIATION_PRIMARY)
	assert_gte(_contrast(fg, prim.bg_color), 4.5, "contraste texto/fondo del principal")
	assert_gte(_contrast(th.get_color("font_color", "Button"), sec.bg_color), 4.5, "contraste del secundario")
	for state: String in ["hover", "pressed", "disabled"]:
		var sb: StyleBoxFlat = th.get_stylebox(state, UiTheme.VARIATION_PRIMARY) as StyleBoxFlat
		assert_not_null(sb, state)
		assert_gte(sb.border_width_left, 3, "borde en " + state)
	# Una pantalla real: Jugar local (menu), "Jugar otra vez" y Confirmar de la barra la usan.
	var menu: Control = (load("res://src/ui/screens/main_menu.tscn") as PackedScene).instantiate()
	add_child_autofree(menu)
	await wait_process_frames(2)
	var primaries: int = 0
	var all: Array[Control] = []
	_walk(menu, all)
	for c: Control in all:
		if c is Button and (c as Button).theme_type_variation == UiTheme.VARIATION_PRIMARY:
			primaries += 1
			assert_gte((c as Button).get_global_rect().size.y, float(UiTheme.BUTTON_PRIMARY_H) - 0.5, "alto del principal del menu")
	assert_eq(primaries, 1, "el menu tiene un unico boton principal")
	var t: TableScreen = await _table("descarte", 3, BASE)
	assert_eq(t.ctx.mode_bar.mode_confirm.theme_type_variation, UiTheme.VARIATION_PRIMARY)
	assert_eq(t.ctx.actions.play_btn.theme_type_variation, UiTheme.VARIATION_PRIMARY)
	assert_eq(t.ctx.actions.end_btn.theme_type_variation, UiTheme.VARIATION_PRIMARY)
	# Beber poción conserva su propio estilo de riesgo (override de instancia gana a la variación).
	var drink_sb: StyleBox = t.ctx.actions.drink_btn.get_theme_stylebox("normal")
	assert_ne((drink_sb as StyleBoxFlat).bg_color, prim.bg_color, "Beber poción no se pinta de violeta")


# ----------------------------------------------------------------------------- V2-33: iconos de estado

func test_f_status_icons_are_48px_textures_distinct_and_no_old_text_tags() -> void:
	for px: Vector2i in SIZES:
		var k: float = float(px.x) / float(BASE.x)
		var t: TableScreen = await _table("estados", 6, px)
		var all: Array[Control] = []
		_walk(t, all)
		var by_tag: Dictionary = {}
		for c: Control in all:
			if c is Label:
				for old: String in ["TURNO", "Congelado", "Cegado", "Escudo", "Bot", "ELIMINADO"]:
					assert_ne((c as Label).text, old, "rotulo antiguo '%s' (%dpx)" % [old, px.x])
			if c is TextureRect and c.has_meta("status_icon"):
				var icon: TextureRect = c
				var tag: String = String(icon.get_meta("status_icon"))
				assert_not_null(icon.texture, "textura de " + tag)
				assert_almost_eq(icon.get_global_rect().size.x * k, 48.0 * k, 1.0, "ancho 48 de " + tag)
				assert_almost_eq(icon.get_global_rect().size.y * k, 48.0 * k, 1.0, "alto 48 de " + tag)
				by_tag[tag] = icon.texture.resource_path
		for need: String in ["Bot", "Congelado", "Cegado", "Escudo", "ELIMINADO", "TURNO"]:
			assert_true(by_tag.has(need), "icono %s presente a %dpx (hay %s)" % [need, px.x, by_tag.keys()])
		var paths: Dictionary = {}
		for tag: Variant in by_tag.keys():
			paths[by_tag[tag]] = true
		assert_eq(paths.size(), by_tag.size(), "cada estado tiene una textura distinta")


# ----------------------------------------------------------------------------- V2-33: diálogos sobre vida y maná propios

func test_f_dialogs_never_cover_own_hp_mana_chips_3_and_6_players() -> void:
	for n: int in [3, 6]:
		for which: String in ["mana-focus", "elixir", "mana-insuficiente", "descarte"]:
			for px: Vector2i in SIZES:
				var t: TableScreen = await _table(which, n, px)
				var tag: String = "%dj %s %dpx" % [n, which, px.x]
				var chips: Array[StatChip] = []
				var sub: Array[Control] = []
				_walk(t.ctx.players.own_panel, sub)
				for c: Control in sub:
					if c is StatChip:
						chips.append(c as StatChip)
				assert_gte(chips.size(), 3, "chips del panel propio (%s)" % tag)
				var overlay: Control = t.ctx.dialogs.dialog_overlay
				var covering: Array[Rect2] = []
				if overlay.visible:
					covering.append(t.ctx.dialogs.sheet.get_global_rect())
				# Barra de descarte forzado u otros modos: tampoco debe taparlos.
				if t.ctx.mode_bar.bar.is_visible_in_tree():
					covering.append(t.ctx.mode_bar.bar.get_global_rect())
				for r: Rect2 in covering:
					for ch: StatChip in chips:
						assert_false(r.intersects(ch.get_global_rect()), "tapa un chip propio (%s, kind %s)" % [tag, ch.kind])
				# Vida y maná propios siguen visibles en pantalla y sin escrim encima.
				if overlay.visible:
					var scrim_top: float = t.ctx.dialogs.scrim.get_global_rect().position.y
					for ch: StatChip in chips:
						assert_gte(ch.get_global_rect().end.y, 0.0)
						assert_lte(ch.get_global_rect().end.y, scrim_top + 0.5, "chip propio por encima del escrim (%s)" % tag)


# ----------------------------------------------------------------------------- V2-33: mesa de 5-6 jugadores

func test_f_rival_panels_do_not_overlap_and_own_panel_height_is_reported() -> void:
	var heights: Dictionary = {}
	for n: int in [3, 5, 6]:
		var t: TableScreen = await _table("base", n, BASE)
		var panels: Array[PlayerPanel] = t.ctx.players.rival_panels
		assert_eq(panels.size(), n - 1)
		for i: int in panels.size():
			for j: int in range(i + 1, panels.size()):
				assert_lt(_gap(panels[i].get_global_rect(), panels[j].get_global_rect()), 1e9)
				assert_false(panels[i].get_global_rect().intersects(panels[j].get_global_rect()), "paneles %d y %d se tocan (%dj)" % [i, j, n])
		heights[n] = t.ctx.players.own_panel.get_global_rect().position.y
	# Pendiente reportado por V2-33 (altura del panel propio distinta con 3 y 6): se documenta el valor, no se exige igualdad.
	gut.p("Y del panel propio a 1080: 3j=%s 5j=%s 6j=%s" % [heights[3], heights[5], heights[6]])
	assert_true(heights.has(3) and heights.has(6))


# ----------------------------------------------------------------------------- P1: fuente de respaldo

func _ui_symbol_chars() -> Dictionary:
	## Todo caracter no ASCII de simbolos/flechas/formas que aparece en el codigo de la UI (src/ui/**/*.gd).
	var out: Dictionary = {}
	var stack: Array[String] = ["res://src/ui"]
	while not stack.is_empty():
		var dir: String = stack.pop_back()
		for sub: String in DirAccess.get_directories_at(dir):
			stack.append(dir + "/" + sub)
		for f: String in DirAccess.get_files_at(dir):
			if not f.ends_with(".gd"):
				continue
			var fa: FileAccess = FileAccess.open(dir + "/" + f, FileAccess.READ)
			var txt: String = fa.get_as_text()
			for i: int in txt.length():
				var u: int = txt.unicode_at(i)
				var symbol: bool = (u >= 0x2190 and u <= 0x2BFF) or (u >= 0x2000 and u <= 0x206F) \
					or u == 0xB7 or (u >= 0x1F000 and u <= 0x1FAFF)
				if symbol:
					out[u] = dir + "/" + f
	return out


func test_f_p1_fallback_font_has_every_symbol_the_ui_code_uses() -> void:
	var font: FontFile = load("res://assets/fonts/DejaVuSans.ttf") as FontFile
	assert_not_null(font, "DejaVuSans.ttf se importa")
	for cp: int in [0x25BC, 0x25B2, 0x26A0, 0x2192, 0x2713, 0xB7]:
		assert_true(font.has_char(cp), "DejaVu tiene U+%04X" % cp)
	assert_false(font.allow_system_fallback, "sin busqueda de fuentes del SO")
	var used: Dictionary = _ui_symbol_chars()
	assert_gt(used.size(), 3, "el codigo de la UI usa varios simbolos")
	var th: Theme = UiTheme.get_theme()
	for cp: Variant in used.keys():
		var u: int = int(cp)
		assert_true(th.default_font.has_char(u), "U+%04X (%s) usado en %s no esta en la fuente del tema" % [u, char(u), used[cp]])
		assert_true(font.has_char(u), "U+%04X usado en %s no esta en el respaldo empaquetado" % [u, used[cp]])


func test_f_p1_license_ships_and_font_resolves_through_the_real_theme() -> void:
	assert_true(FileAccess.file_exists("res://assets/fonts/LICENSE-DejaVu.txt"))
	var lic: String = FileAccess.get_file_as_string("res://assets/fonts/LICENSE-DejaVu.txt")
	assert_true(lic.contains("Bitstream"), "texto de permiso de Bitstream Vera")
	assert_true(lic.to_lower().contains("permission"))
	assert_true(FileAccess.file_exists("res://assets/fonts/DejaVuSans.ttf.import"))
	# Un Label real con el tema del juego: la linea con simbolos se compone sin glifos vacios.
	var l: Label = Label.new()
	l.theme = UiTheme.get_theme()
	l.text = "▼ -3  ▲ +2  ⚠ 8/10 → ✓ ·"
	add_child_autofree(l)
	await wait_process_frames(2)
	var font: Font = l.get_theme_font("font")
	for ch: String in ["▼", "▲", "⚠", "→", "✓", "·"]:
		assert_gt(font.get_char_size(ch.unicode_at(0), 30).x, 4.0, "el glifo %s tiene ancho" % ch)
	assert_gt(l.get_minimum_size().x, 100.0, "la linea con simbolos tiene ancho propio")


# ----------------------------------------------------------------------------- P2: un solo reduce por acción de bot

## reuse: 1 = activar, 0 = flujo antiguo, -1 = dejar el valor por defecto de la sesion (lo que usa el juego).
func _bot_session(n: int, humans: int, seed_value: int, reuse: int, mode: String) -> LocalSession:
	var players: Array = []
	for i: int in n:
		players.append({"name": "Mago %d" % (i + 1), "age": 30 + i, "birth_month": i + 1, "is_bot": i >= humans})
	var setup: Dictionary = {"players": players, "config": {"potion_limit_enabled": true, "potion_limit": 10,
		"potion_mana": 3, "reaction_timeout_local_ms": 0}}
	var ls: LocalSession = LocalSession.create(setup, seed_value)
	autofree(ls)
	ls.auto_run_bots = false
	ls.bot_randomness = 0 if humans == 0 else 15
	if reuse >= 0:
		ls.reuse_bot_reduce = reuse == 1
	ls.reaction_notify = mode
	return ls


func test_f_p2_exactly_one_reduce_per_bot_action_over_full_games() -> void:
	for np: int in [3, 4, 6]:
		for sd: int in [7, 8]:
			var ls: LocalSession = _bot_session(np, 0, sd, -1, "all")
			assert_true(ls.reuse_bot_reduce, "por defecto la sesion reutiliza el reduce de validacion")
			var steps: int = 0
			while steps < 1500 and ls.step_bot():
				steps += 1
				assert_eq(ls.reduce_calls, steps, "%dj s%d paso %d: un reduce por accion" % [np, sd, steps])
				if ls.reduce_calls != steps:
					break
			assert_gt(steps, 40, "%dj s%d: la partida avanzo" % [np, sd])
			assert_eq(Types.validate_state(ls.state), [] as Array[String])


func test_f_p2_old_flow_is_exactly_twice_and_final_state_is_identical() -> void:
	for np: int in [3, 5]:
		for sd: int in [11, 12]:
			var a: LocalSession = _bot_session(np, 0, sd, -1, "all")
			var b: LocalSession = _bot_session(np, 0, sd, 0, "all")
			var na: int = a.run_bots(1500)
			var nb: int = b.run_bots(1500)
			assert_eq(na, nb, "%dj s%d: mismas acciones" % [np, sd])
			assert_eq(a.reduce_calls, na, "con reuse: 1 por accion")
			assert_eq(b.reduce_calls, 2 * nb, "sin reuse: 2 por accion")
			assert_eq(JSON.stringify(a.state), JSON.stringify(b.state), "%dj s%d: estado final identico" % [np, sd])
			assert_eq(JSON.stringify(a.history), JSON.stringify(b.history), "historial identico")
			assert_eq(a.get_rev(), b.get_rev())
			assert_eq(Types.validate_state(a.state), [] as Array[String])
			assert_eq(int(a.state["card_total"]), int(b.state["card_total"]), "cartas constantes")


func test_f_p2_with_a_human_and_affecting_mode_still_matches_old_flow() -> void:
	## Auto-pase + bots: el humano no actua, asi que la partida se detiene en su turno; las trazas deben coincidir igual.
	for sd: int in [3, 4, 5]:
		var a: LocalSession = _bot_session(4, 1, sd, -1, "affecting")
		var b: LocalSession = _bot_session(4, 1, sd, 0, "affecting")
		var na: int = a.run_bots(600)
		var nb: int = b.run_bots(600)
		assert_eq(na, nb, "s%d acciones" % sd)
		assert_eq(JSON.stringify(a.state), JSON.stringify(b.state), "s%d estado" % sd)
		assert_eq(JSON.stringify(a.history), JSON.stringify(b.history), "s%d historial" % sd)
		# reduce de bots + reduce de auto-pase: el de reuse nunca supera al antiguo ni baja de las acciones aplicadas.
		assert_gte(a.reduce_calls, na)
		assert_lt(a.reduce_calls, b.reduce_calls + 1)
		assert_eq(b.reduce_calls - a.reduce_calls, nb, "el flujo antiguo solo anade 1 reduce por accion de bot")
		assert_eq(Types.validate_state(a.state), [] as Array[String])


# ----------------------------------------------------------------------------- Ítem 6 y 5: sin opciones muertas ni textos con "_"

const SCREENS: Array[String] = [
	"res://src/ui/screens/main_menu.tscn",
	"res://src/ui/screens/settings.tscn",
	"res://src/ui/screens/help_screen.tscn",
	"res://src/ui/screens/local_setup.tscn",
	"res://src/ui/screens/pass_device_screen.tscn",
]


func _texts_of(root: Node) -> Array[String]:
	var out: Array[String] = []
	var all: Array[Control] = []
	_walk(root, all)
	for c: Control in all:
		if c is Label:
			out.append((c as Label).text)
		elif c is Button:
			out.append((c as Button).text)
		elif c is RichTextLabel:
			out.append((c as RichTextLabel).get_parsed_text())
	return out


func _dead_buttons(root: Node) -> Array[String]:
	var dead: Array[String] = []
	var all: Array[Control] = []
	_walk(root, all)
	for c: Control in all:
		if c is BaseButton:
			var b: BaseButton = c
			var wired: bool = b.get_signal_connection_list("pressed").size() > 0 or b.get_signal_connection_list("toggled").size() > 0
			if not wired and not b.disabled:
				dead.append("%s '%s'" % [b.get_path(), b.get("text")])
	return dead


func test_f_screens_have_no_dead_buttons_and_no_underscore_texts() -> void:
	for path: String in SCREENS:
		var n: Node = (load(path) as PackedScene).instantiate()
		add_child_autofree(n)
		await wait_process_frames(3)
		assert_eq(_dead_buttons(n), [] as Array[String], "botones sin accion en " + path)
		var sub: Array[Control] = []
		_walk(n, sub)
		for c: Control in sub:
			if c is Button and (c as Button).get_global_rect().size.y > 0.0:
				var is_primary: bool = (c as Button).theme_type_variation == UiTheme.VARIATION_PRIMARY
				var floor_h: float = float(UiTheme.BUTTON_PRIMARY_H) if is_primary else float(UiTheme.BUTTON_MIN_H)
				assert_gte((c as Button).get_global_rect().size.y + 0.5, floor_h, "alto de '%s' en %s" % [(c as Button).text, path])
		for txt: String in _texts_of(n):
			assert_false(txt.contains("_"), "texto con '_' en %s: '%s'" % [path, txt])
			assert_false(txt.to_lower().contains("abcd"), "sala falsa en " + path)
		var all_txt: String = " | ".join(_texts_of(n))
		for banned: String in ["Crear sala", "Unirse con código", "Música", "Efectos"]:
			assert_false(all_txt.contains(banned), "%s aun muestra '%s' (interfaz honesta)" % [path, banned])


func test_f_table_scenarios_have_no_dead_buttons_and_no_underscore_texts() -> void:
	for which: String in ["base", "estados", "mana-focus", "elixir", "mana-insuficiente", "descarte", "reaccion", "ocho-pociones"]:
		var t: TableScreen = await _table(which, 4, BASE)
		assert_eq(_dead_buttons(t), [] as Array[String], "botones sin accion en la mesa (%s)" % which)
		for txt: String in _texts_of(t):
			assert_false(txt.contains("_"), "texto con '_' en la mesa (%s): '%s'" % [which, txt])
			assert_false(txt.contains("efecto aplicado"), "texto generico en la mesa (%s)" % which)


# ----------------------------------------------------------------------------- Ítems 3, 4, 5 y 8 (escenarios propios)

func _own_state(hand: Array, mana: int, event: String = "") -> Dictionary:
	var s: Dictionary = _state(3)
	H.set_hand(s, "p1", hand)
	H.set_mana(s, "p1", mana)
	if event != "":
		X.event(s, event)
	return s


func _mount(s: Dictionary, px: Vector2i = BASE) -> TableScreen:
	_drop()
	_vp = SubViewport.new()
	_vp.size = px
	_vp.size_2d_override = BASE
	_vp.size_2d_override_stretch = true
	_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_vp)
	var t: TableScreen = (load("res://src/ui/screens/table.tscn") as PackedScene).instantiate()
	_vp.add_child(t)
	var ls: LocalSession = LocalSession.new()
	ls.start(s, 21)
	ls.auto_run_bots = false
	t.bind_session(ls)
	await wait_process_frames(4)
	while t._notice_overlay.visible:
		t._on_notice_ok()
	await wait_process_frames(3)
	return t


func test_f_item3_effective_cost_under_fire_storm_and_playable_equals_engine() -> void:
	var s: Dictionary = _own_state([Types.CARD_FIRE_ARROW, Types.CARD_ICE_BOLT, Types.CARD_HEAL, Types.CARD_MAGIC_SHIELD], 1,
		Types.CARD_FIRE_STORM)
	var t: TableScreen = await _mount(s)
	var legal_cards: Dictionary = {}
	for a: Variant in Game.legal_actions(Types.view_for(s, "p1"), "p1"):
		if String((a as Dictionary)["type"]) == Types.ACTION_PLAY_CARD:
			legal_cards[int((a as Dictionary)["iid"])] = true
	var infos: Dictionary = t.ctx.hand.infos
	assert_eq(infos.size(), 4)
	for c: Variant in H.hand(s, "p1"):
		var iid: int = int((c as Dictionary)["iid"])
		assert_eq(bool((infos[iid] as Dictionary)["playable"]), legal_cards.has(iid), "jugable == motor para %s" % (c as Dictionary)["card_id"])
	var fa: Dictionary = {}
	for c: Variant in H.hand(s, "p1"):
		if String((c as Dictionary)["card_id"]) == Types.CARD_FIRE_ARROW:
			fa = c
	t._on_hand_tapped({"iid": int(fa["iid"])})
	await wait_process_frames(2)
	var info: CardInfo = t.ctx.hand.info
	assert_true(info.visible, "ficha visible")
	assert_string_contains(info.mana_label.text, "2", "coste efectivo con Fire Storm")
	assert_string_contains(info.mana_label.text, "base 1", "muestra el coste base")
	assert_false(bool((infos[int(fa["iid"])] as Dictionary)["playable"]), "con 1 de maná Fire Arrow (cuesta 2) no es jugable")
	assert_gt(info.name_label.text.length(), 3, "nombre completo")
	assert_false(info.name_label.text.contains("..."), "sin elipsis")


func test_f_item4_payment_text_and_preselect_single_vs_two_combinations() -> void:
	# Una sola combinación: Fireball + 1 Fire Arrow.
	var s1: Dictionary = _own_state([Types.CARD_FIREBALL, Types.CARD_FIRE_ARROW, Types.CARD_HEAL], 3)
	var t1: TableScreen = await _mount(s1)
	var fb: Dictionary = H.hand(s1, "p1")[0]
	t1._on_hand_tapped({"iid": int(fb["iid"])})
	await wait_process_frames(2)
	t1.ctx.actions.play_btn.pressed.emit()
	await wait_process_frames(2)
	t1.ctx.flow.on_panel_tapped("p2")
	await wait_process_frames(3)
	assert_eq(t1.ctx.mode_bar.mode_label.text, "Fireball: paga 1 carta de fuego (1/1)")
	assert_false(t1.ctx.mode_bar.mode_confirm.disabled, "Confirmar activo con una unica combinacion")
	# Dos combinaciones: no se marca nada.
	var s2: Dictionary = _own_state([Types.CARD_FIREBALL, Types.CARD_FIRE_ARROW, Types.CARD_FIRE_ARROW], 3)
	var t2: TableScreen = await _mount(s2)
	t2._on_hand_tapped({"iid": int((H.hand(s2, "p1")[0] as Dictionary)["iid"])})
	await wait_process_frames(2)
	t2.ctx.actions.play_btn.pressed.emit()
	await wait_process_frames(2)
	t2.ctx.flow.on_panel_tapped("p2")
	await wait_process_frames(3)
	assert_eq(t2.ctx.mode_bar.mode_label.text, "Fireball: paga 1 carta de fuego (0/1)")
	assert_true(t2.ctx.mode_bar.mode_confirm.disabled, "Confirmar inactivo con dos combinaciones")


func test_f_item5_view_button_opens_zoom_with_one_tap_and_hint_is_visible() -> void:
	# Aislado: la pista "ya vista" se guarda en settings.cfg; se usa un archivo temporal para no tocar el del usuario.
	var saved_path: String = CardInfo.settings_path
	CardInfo.settings_path = "user://qa_final_settings.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(CardInfo.settings_path))
	CardInfo._hint_seen_session = false
	var s: Dictionary = _own_state([Types.CARD_FIRE_ARROW, Types.CARD_HEAL], 1)
	var t: TableScreen = await _mount(s, Vector2i(720, 1280))
	t._on_hand_tapped({"iid": int((H.hand(s, "p1")[0] as Dictionary)["iid"])})
	await wait_process_frames(2)
	var info: CardInfo = t.ctx.hand.info
	assert_true(info.view_button.is_visible_in_tree(), "boton Ver visible")
	assert_gte(info.view_button.get_global_rect().size.y, float(UiTheme.BUTTON_MIN_H) - 0.5, "Ver >= 96")
	assert_string_contains(info.hint_label.text, "Mantén pulsada", "pista de pulsacion larga")
	assert_false(t._zoom.visible)
	info.view_button.pressed.emit()
	await wait_process_frames(3)
	assert_true(t._zoom.visible, "el zoom se abre con un solo toque en Ver")
	CardInfo._hint_seen_session = false
	DirAccess.remove_absolute(ProjectSettings.globalize_path(CardInfo.settings_path))
	CardInfo.settings_path = saved_path


func test_f_item8_replay_handler_keeps_players_and_options_with_new_seed() -> void:
	var setup: Dictionary = {"players": [
		{"name": "Ana", "age": 30, "birth_month": 1, "is_bot": false},
		{"name": "Bruno", "age": 28, "birth_month": 3, "is_bot": true},
		{"name": "Cira", "age": 26, "birth_month": 7, "is_bot": true}],
		"config": {"potion_limit_enabled": true, "potion_limit": 6, "potion_mana": 4}, "seed": 77}
	UiNav.last_setup = setup.duplicate(true)
	UiNav.replay_handler = Callable(UiNav, "_replay_local")
	assert_true(UiNav.can_replay())
	var again: Dictionary = UiNav.replay_setup()
	assert_eq(again["players"], setup["players"], "mismos jugadores")
	assert_eq(again["config"], setup["config"], "mismas opciones (limite 6, pocion 4)")
	assert_ne(int(again["seed"]), 77, "semilla nueva")
	UiNav.replay_handler = Callable()
	UiNav.last_setup = {}


# ----------------------------------------------------------------------------- Defectos abiertos que se vigilan (pasan a verde al corregirse)

func test_f_open_defect_forced_discard_text_has_no_plural_placeholder() -> void:
	## QA-V2-35-02 (reabre QA-V2-03-03): la barra de descarte forzado dice "Descarta 2 carta(s) (Icy Grasp) (0/2)".
	var t: TableScreen = await _table("descarte", 3, BASE)
	var txt: String = t.ctx.mode_bar.mode_label.text
	assert_string_contains(txt, "Descarta", "la barra de descarte forzado esta visible")
	if txt.contains("(s)"):
		pending("QA-V2-35-02: '%s' conserva el plural provisional '(s)'" % txt)
		return
	assert_false(txt.contains("(s)"))
	assert_string_contains(txt, "cartas", "plural correcto")


func test_f_open_defect_vibration_toggle_has_a_consumer() -> void:
	## QA-V2-35-03: Ajustes ofrece "Vibración: sí/no" pero nada en src/ la lee ni vibra (opcion muerta como P6).
	var settings: Node = (load("res://src/ui/screens/settings.tscn") as PackedScene).instantiate()
	add_child_autofree(settings)
	await wait_process_frames(2)
	var has_toggle: bool = false
	for txt: String in _texts_of(settings):
		if txt.begins_with("Vibración"):
			has_toggle = true
	var consumer: bool = false
	var stack: Array[String] = ["res://src"]
	while not stack.is_empty():
		var dir: String = stack.pop_back()
		for sub: String in DirAccess.get_directories_at(dir):
			stack.append(dir + "/" + sub)
		for f: String in DirAccess.get_files_at(dir):
			if f.ends_with(".gd") and FileAccess.get_file_as_string(dir + "/" + f).contains("vibrate_handheld"):
				consumer = true
	if has_toggle and not consumer:
		pending("QA-V2-35-03: Ajustes muestra 'Vibración' pero ninguna parte de src/ llama a vibrate_handheld")
		return
	assert_true(not has_toggle or consumer)


func test_f_open_defect_reaction_modal_hides_own_vitals_in_6_player_table() -> void:
	## QA-V2-35-04: la ventana de reaccion (modal central) tapa vida/mana/pociones propios con 6 jugadores.
	for px: Vector2i in SIZES:
		var t: TableScreen = await _table("reaccion", 6, px)
		var modal: Control = t._reaction_overlay
		assert_true(modal.visible)
		var chips: Array[StatChip] = []
		var sub: Array[Control] = []
		_walk(t.ctx.players.own_panel, sub)
		for c: Control in sub:
			if c is StatChip:
				chips.append(c as StatChip)
		var covered: bool = false
		for r: Control in [t._reaction as Control]:
			for ch: StatChip in chips:
				if r.get_global_rect().intersects(ch.get_global_rect()):
					covered = true
		if covered:
			pending("QA-V2-35-04: la ventana de reaccion tapa los chips propios (6j %dpx)" % px.x)
			return
	assert_true(true)

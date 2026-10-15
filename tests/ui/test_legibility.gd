extends GutTest
## V2-33: legibilidad móvil (docs/TAREAS.md §2.1, docs/diseno/escenarios/mesa-5-6-jugadores.md §7).
## Mesas reales (motor + LocalSession) dentro de un SubViewport de 1080x1920 o 720x1280
## con la misma escala que el juego (stretch canvas_items desde 1080x1920). Las medidas
## lógicas se pasan a píxeles físicos con s = ancho / 1080 y se comparan con §2.1:
## principales >= 144 a 1080 (96 a 720), resto >= 96 (64), separaciones 16 y 24.

const H = preload("res://tests/fixtures/engine_helpers.gd")
const X = preload("res://tests/engine/effects/t6c_helpers.gd")
const BASE: Vector2i = Vector2i(1080, 1920)
const SIZES: Array[Vector2i] = [Vector2i(1080, 1920), Vector2i(720, 1280)]
const NAMES: Array[String] = ["Ana", "Bruno", "Cira", "Dario", "Elena", "Fabio"]
const OLD_TAGS: Array[String] = ["TURNO", "Congelado", "Cegado", "Escudo", "Bot", "ELIMINADO"]

var _vp: SubViewport = null


func after_each() -> void:
	if _vp != null and is_instance_valid(_vp):
		_vp.queue_free()
	_vp = null
	await wait_process_frames(1)


# ---------------------------------------------------------------- montaje

func _players(n: int) -> Array:
	var out: Array = []
	for i: int in n:
		out.append(Types.make_player("p%d" % (i + 1), NAMES[i], 40 - i * 5, i + 1, i > 0))
	return out


func _state(n: int) -> Dictionary:
	CardCatalog.load_json()
	EffectRegistry.reset()
	var s: Dictionary = Game.new_game(_players(n), {"reaction_timeout_local_ms": 15000}, 11)
	H.force_turn(s, "p1")
	s["pending"] = []
	return s


func _scenario(which: String, n: int) -> Dictionary:
	var s: Dictionary = _state(n)
	match which:
		"estados":
			Damage.eliminate(s, "p3", "hp", [])
			H.player(s, "p3")["hp"] = 0
			var f: Dictionary = H.player(s, "p2")["flags"] as Dictionary
			f["frozen"] = 1
			f["blinded"] = true
			f["force_field"] = Types.CARD_FIREBALL
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
		"magic-cap":
			s = _equip(s, "p1", Types.CARD_MAGIC_CAP)
			H.force_turn(s, "p2")
			X.spell_damage(s, "p2", "p1", 3, Types.ELEMENT_FIRE)
		"defensiva":
			H.set_hand(s, "p1", [Types.CARD_MAGIC_SHIELD, Types.CARD_HEAL])
		"descarte":
			Damage.forced_discard(s, "p1", 2, [], Types.CARD_ICY_GRASP)
		"reaccion":
			H.force_turn(s, "p2")
			H.set_hand(s, "p1", [Types.CARD_MAGIC_SHIELD, Types.CARD_FIREBALL])
			H.set_hand(s, "p2", [Types.CARD_ICE_BOLT])
			H.set_mana(s, "p2", 5)
			H.player(s, "p1")["potions"] = 8
	return s


func _equip(s: Dictionary, pid: String, card_id: String) -> Dictionary:
	H.force_turn(s, pid)
	var iid: int = X.give(s, pid, card_id)
	var pay: Array = X.pay_for(s, pid, card_id)
	var p: Dictionary = H.player(s, pid)
	var before: int = int(p["mana"])
	p["mana"] = before + Damage.card_cost(s, pid, CardCatalog.get_def(card_id))
	var r: Dictionary = Game.reduce(s, Types.make_action_play_card(pid, iid, [], pay))
	assert_eq(String(r["error"]), "", "equipar " + card_id)
	var ns: Dictionary = H.settle(r["state"])
	H.player(ns, pid)["mana"] = before
	return ns


## Mesa real en un SubViewport de `px` con la escala del juego.
func _table(which: String, n: int, px: Vector2i) -> TableScreen:
	_vp = SubViewport.new()
	_vp.size = px
	_vp.size_2d_override = BASE
	_vp.size_2d_override_stretch = true
	_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_vp)
	var t: TableScreen = (load("res://src/ui/screens/table.tscn") as PackedScene).instantiate()
	_vp.add_child(t)
	var ls: LocalSession = LocalSession.new()
	ls.start(_scenario(which, n), 11)
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


func _s(px: Vector2i) -> float:
	return float(px.x) / float(BASE.x)


## Rect lógico (coordenadas de la mesa) -> físico.
func _phys(r: Rect2, px: Vector2i) -> Rect2:
	var k: float = _s(px)
	return Rect2(r.position * k, r.size * k)


func _primary_min(px: Vector2i) -> float:
	return 144.0 if px.x == 1080 else 96.0


func _secondary_min(px: Vector2i) -> float:
	return 96.0 if px.x == 1080 else 64.0


func _visible_controls(n: Node, out: Array[Control], skip_cards: bool = true) -> void:
	for c: Node in n.get_children():
		if not (c is Control):
			continue
		var cc: Control = c
		if not cc.is_visible_in_tree():
			continue
		if skip_cards and cc is CardView:
			continue
		out.append(cc)
		_visible_controls(cc, out, skip_cards)


func _font_of(c: Control) -> int:
	if c is RichTextLabel:
		return c.get_theme_font_size("normal_font_size")
	if c is StatChip:
		return (c as StatChip).font_size
	return c.get_theme_font_size("font_size")


## Textos visibles por debajo de FONT_MIN (nombres de nodo), sin el texto impreso de las cartas.
func _small_texts(root: Node) -> Array[String]:
	var bad: Array[String] = []
	var all: Array[Control] = []
	_visible_controls(root, all)
	for c: Control in all:
		var is_text: bool = c is Label or c is Button or c is RichTextLabel or c is ProgressBar or c is StatChip
		if not is_text:
			continue
		if c is Button and (c as Button).text == "":
			continue
		if c is Label and (c as Label).text == "":
			continue
		if _font_of(c) < UiTheme.FONT_MIN:
			bad.append("%s '%s' %d px" % [c.get_path(), c.get("text"), _font_of(c)])
	return bad


func _gap_x(a: Control, b: Control) -> float:
	var ra: Rect2 = a.get_global_rect()
	var rb: Rect2 = b.get_global_rect()
	return rb.position.x - ra.end.x if rb.position.x >= ra.position.x else ra.position.x - rb.end.x


# ---------------------------------------------------------------- 1. fuentes

func test_no_text_below_font_min_in_tables_3_and_6() -> void:
	for n: int in [3, 6]:
		for which: String in ["base", "estados"]:
			var t: TableScreen = await _table(which, n, BASE)
			var bad: Array[String] = _small_texts(t)
			assert_eq(bad, [] as Array[String], "%dj %s: textos < %d px" % [n, which, UiTheme.FONT_MIN])
			# Incluido player_panel (QA-V2-21-05).
			for pp: PlayerPanel in t.ctx.players.rival_panels:
				assert_eq(_small_texts(pp), [] as Array[String], "panel %s" % pp.player_id)
			assert_eq(_small_texts(t.ctx.players.own_panel), [] as Array[String], "panel propio")
			_vp.queue_free()
			_vp = null
			await wait_process_frames(1)


func test_no_text_below_font_min_in_dialogs_and_reaction() -> void:
	for which: String in ["mana-focus", "elixir", "magic-cap", "mana-insuficiente", "descarte", "reaccion"]:
		var t: TableScreen = await _table(which, 6, BASE)
		assert_eq(_small_texts(t), [] as Array[String], "6j %s" % which)
		_vp.queue_free()
		_vp = null
		await wait_process_frames(1)


# ---------------------------------------------------------------- 2. botones

func test_action_buttons_primary_and_gaps_3_and_6_both_sizes() -> void:
	for n: int in [3, 6]:
		for px: Vector2i in SIZES:
			var t: TableScreen = await _table("base", n, px)
			var a: TableActions = t.ctx.actions
			var tag: String = "%dj %dx%d" % [n, px.x, px.y]
			var row: Array[Button] = [a.play_btn, a.exchange_btn, a.discard_btn, a.end_btn]
			for b: Button in row + [a.drink_btn] as Array[Button]:
				assert_true(b.is_visible_in_tree(), "%s visible: %s" % [b.text, tag])
				assert_gte(_phys(b.get_global_rect(), px).size.y, _primary_min(px) - 0.5, "%s alto (%s)" % [b.text, tag])
				var vr: Rect2 = Rect2(Vector2.ZERO, Vector2(BASE))
				assert_true(vr.encloses(b.get_global_rect()), "%s dentro de la pantalla (%s)" % [b.text, tag])
			for i: int in range(1, row.size()):
				assert_gte(_gap_x(row[i - 1], row[i]) * _s(px), 16.0 * _s(px) - 0.5, "separación fila (%s)" % tag)
			var gap_drink: float = a.drink_btn.get_global_rect().position.y - a.action_row.get_global_rect().end.y
			assert_gte(gap_drink, float(UiTheme.BUTTON_GAP_POTION) - 0.5, "Beber poción a >= 24 de la fila (%s)" % tag)
			# Secundarios: Menú y cualquier otro botón visible de la mesa.
			var all: Array[Control] = []
			_visible_controls(t, all, true)
			for c: Control in all:
				if c is Button and c != t.ctx.players.own_panel:
					assert_gte(_phys((c as Button).get_global_rect(), px).size.y, _secondary_min(px) - 0.5,
						"botón '%s' >= secundario (%s)" % [(c as Button).text, tag])
			# La mano entera cabe en la pantalla.
			assert_lte(t.ctx.hand.hand_view.get_global_rect().end.y, float(BASE.y) + 0.5, "mano dentro (%s)" % tag)
			# Con la ficha de una carta abierta, la mesa sigue cabiendo entera.
			var first: Dictionary = (t.ctx.me()["hand"] as Array)[0]
			t._on_hand_tapped({"iid": int(first["iid"])})
			await wait_process_frames(2)
			assert_true(t.ctx.hand.info.visible)
			assert_lte(t.ctx.hand.hand_view.get_global_rect().end.y, float(BASE.y) + 0.5, "mano dentro con ficha (%s)" % tag)
			var ver: Button = t.ctx.hand.info.view_button
			assert_gte(ver.get_global_rect().position.y - a.drink_btn.get_global_rect().end.y,
				float(UiTheme.BUTTON_GAP_POTION) - 0.5, "Ver a >= 24 de Beber poción (%s)" % tag)
			_vp.queue_free()
			_vp = null
			await wait_process_frames(1)


func test_mode_bar_confirm_primary_in_forced_discard() -> void:
	for px: Vector2i in SIZES:
		var t: TableScreen = await _table("descarte", 6, px)
		var mb: TableModeBar = t.ctx.mode_bar
		assert_true(mb.bar.is_visible_in_tree(), "barra de descarte visible")
		assert_gte(_phys(mb.mode_confirm.get_global_rect(), px).size.y, _primary_min(px) - 0.5, "Confirmar principal")
		assert_eq(mb.mode_confirm.theme_type_variation, UiTheme.VARIATION_PRIMARY)
		if mb.mode_cancel.is_visible_in_tree():
			assert_gte(_gap_x(mb.mode_confirm, mb.mode_cancel), 16.0 - 0.5)
		# La banda de descarte no tapa la mano ni el panel propio: hay cartas tocables.
		var own: Rect2 = t.ctx.players.own_panel.get_global_rect()
		assert_false(mb.bar.get_global_rect().intersects(own), "no tapa el panel propio")
		assert_false(t._dialog_overlay.visible, "sin diálogo modal sobre la mano")
		var hv: HandView = t.ctx.hand.hand_view
		assert_gt(hv.hand.size(), 0)
		var drink_r: Rect2 = t.ctx.actions.drink_btn.get_global_rect()
		assert_gte(drink_r.position.y - mb.bar.get_global_rect().end.y, float(UiTheme.BUTTON_GAP_POTION) - 0.5)
		var iid: int = int((hv.hand[0] as Dictionary)["iid"])
		t._on_hand_tapped({"iid": iid})
		assert_true(t._selected.has(iid), "la carta de la mano se puede elegir")
		_vp.queue_free()
		_vp = null
		await wait_process_frames(1)


# ---------------------------------------------------------------- 3. diálogos

func test_prompt_dialogs_do_not_hide_own_panel_actions_or_potion() -> void:
	for which: String in ["mana-focus", "elixir", "magic-cap", "mana-insuficiente"]:
		for px: Vector2i in SIZES:
			var t: TableScreen = await _table(which, 6, px)
			var tag: String = "%s %dx%d" % [which, px.x, px.y]
			var d: TableDialogs = t.ctx.dialogs
			assert_true(d.is_open(), "diálogo abierto: " + tag)
			var sheet_r: Rect2 = d.sheet.get_global_rect()
			for c: Control in [t.ctx.players.own_panel, t.ctx.actions.action_row, t.ctx.actions.drink_btn] as Array[Control]:
				assert_false(sheet_r.intersects(c.get_global_rect()), "%s tapa %s" % [tag, c.name])
			assert_true(Rect2(Vector2.ZERO, Vector2(BASE)).encloses(sheet_r), "hoja dentro de la pantalla: " + tag)
			assert_gte(d.scrim.get_global_rect().position.y, t.ctx.players.own_panel.get_global_rect().end.y,
				"el escrim no oscurece el panel propio: " + tag)
			# Línea informativa con vida y maná propios (QA-V2-03-04).
			assert_not_null(d.dialog.info_label)
			assert_string_contains(d.dialog.info_label.text, "Tu maná: %d" % int(t.ctx.me()["mana"]))
			assert_string_contains(d.dialog.info_label.text, "Tu vida: %d" % int(t.ctx.me()["hp"]))
			# Botones: principales >= 144 (96), resto >= 96 (64); separación >= 16; <= 2 filas.
			var rows: Dictionary = {}
			for b: Button in d.dialog.buttons:
				var id: String = String(b.get_meta("dialog_id", ""))
				var want: float = _primary_min(px) if TableDialogs.PRIMARY_IDS.has(id) else _secondary_min(px)
				assert_gte(_phys(b.get_global_rect(), px).size.y, want - 0.5, "%s: botón %s" % [tag, id])
				rows[roundi(b.get_global_rect().position.y)] = true
			assert_lte(rows.size(), 2, "como mucho dos filas de botones: " + tag)
			for i: int in range(1, d.dialog.buttons.size()):
				var a: Button = d.dialog.buttons[i - 1]
				var b2: Button = d.dialog.buttons[i]
				if absf(a.get_global_rect().position.y - b2.get_global_rect().position.y) < 1.0:
					assert_gte(_gap_x(a, b2), 16.0 - 0.5, "separación de botones: " + tag)
			if d.dialog.stepper != null:
				for c: Node in d.dialog.stepper.get_children():
					if c is Button:
						var r: Rect2 = _phys((c as Button).get_global_rect(), px)
						assert_gte(minf(r.size.x, r.size.y), _secondary_min(px) - 0.5, "selector -/+ 96x96: " + tag)
			_vp.queue_free()
			_vp = null
			await wait_process_frames(1)


func test_mana_focus_starts_at_zero_and_elixir_at_one() -> void:
	var t: TableScreen = await _table("mana-focus", 6, BASE)
	assert_eq(t._dialog.stepper.value, 0)
	_vp.queue_free()
	_vp = null
	await wait_process_frames(1)
	t = await _table("elixir", 6, BASE)
	assert_eq(t._dialog.stepper.value, 1)


# ---------------------------------------------------------------- 4. rivales (5 y 6 jugadores)

func test_rival_grid_sizes_no_overlap_no_rotation() -> void:
	var want: Dictionary = {6: Vector2(341, 200), 5: Vector2(518, 160)}
	for n: int in [5, 6]:
		for px: Vector2i in SIZES:
			var t: TableScreen = await _table("base", n, px)
			var tag: String = "%dj %dx%d" % [n, px.x, px.y]
			var panels: Array[PlayerPanel] = t.ctx.players.rival_panels
			assert_eq(panels.size(), n - 1)
			var vr: Rect2 = Rect2(Vector2.ZERO, Vector2(BASE))
			for i: int in panels.size():
				var r: Rect2 = panels[i].get_global_rect()
				var pr: Rect2 = _phys(r, px)
				var w: Vector2 = (want[n] as Vector2) * _s(px)
				assert_gte(pr.size.x, w.x - 1.0, "ancho panel (%s)" % tag)
				assert_gte(pr.size.y, w.y - 1.0, "alto panel (%s)" % tag)
				assert_gte(minf(pr.size.x, pr.size.y), _primary_min(px), "toque >= 48 dp (%s)" % tag)
				assert_eq(panels[i].rotation, 0.0, "sin giro (%s)" % tag)
				assert_true(vr.encloses(r), "dentro de la pantalla (%s)" % tag)
				for j: int in range(i + 1, panels.size()):
					var o: Rect2 = panels[j].get_global_rect()
					assert_false(r.grow(5.9).intersects(o), "separación >= 12 (%s)" % tag)
			# Panel propio y centro: el centro acaba por encima del panel propio.
			var own: Rect2 = t.ctx.players.own_panel.get_global_rect()
			assert_lte(t.ctx.center.center.get_global_rect().end.y, own.position.y, "centro sobre el panel propio")
			_vp.queue_free()
			_vp = null
			await wait_process_frames(1)


# ---------------------------------------------------------------- 5. iconos de estado

func test_status_icons_visible_48_and_no_old_labels() -> void:
	for px: Vector2i in SIZES:
		var t: TableScreen = await _table("estados", 6, px)
		var p2: PlayerPanel = t.ctx.players.panel_for("p2") as PlayerPanel
		var icons: Array[String] = p2.status_icons()
		for tag: String in ["Bot", "Congelado", "Cegado", "Escudo"]:
			assert_has(icons, tag, "icono %s" % tag)
		var all: Array[Control] = []
		_visible_controls(t, all, true)
		var found: int = 0
		for c: Control in all:
			if c.has_meta("status_icon"):
				found += 1
				var r: Rect2 = _phys(c.get_global_rect(), px)
				assert_almost_eq(r.size.x, 48.0 * _s(px), 1.0, "icono de 48 (32 a 720)")
				assert_almost_eq(r.size.y, 48.0 * _s(px), 1.0)
				assert_not_null((c as TextureRect).texture, "textura de assets/ui")
			if c is Label:
				assert_false(OLD_TAGS.has((c as Label).text), "sin rótulo de texto '%s'" % (c as Label).text)
		assert_gt(found, 5)
		# Turno: exactamente un panel con el icono de turno (el propio, en mi turno).
		var turn_panels: int = 0
		for pp: PlayerPanel in t.ctx.players.rival_panels + [t.ctx.players.own_panel] as Array[PlayerPanel]:
			if pp.status_icons().has("TURNO"):
				turn_panels += 1
		assert_eq(turn_panels, 1, "un solo panel en turno")
		_vp.queue_free()
		_vp = null
		await wait_process_frames(1)


func test_status_row_reserved_panel_size_stable_when_frozen() -> void:
	var s: Dictionary = _state(6)
	var p: Dictionary = (Types.view_for(s, "p1")["players"] as Array)[1]
	var pp: PlayerPanel = PlayerPanel.create(false, 341.0, 2)
	add_child_autofree(pp)
	pp.update_player(p, false)
	await wait_process_frames(1)
	var before: Vector2 = pp.get_combined_minimum_size()
	assert_not_null(pp.status_row)
	assert_eq(pp.status_row.custom_minimum_size.y, float(PlayerPanel.ICON_SIZE), "fila de iconos reservada")
	var frozen: Dictionary = p.duplicate(true)
	(frozen["flags"] as Dictionary)["frozen"] = 1
	(frozen["flags"] as Dictionary)["blinded"] = true
	pp.update_player(frozen, false)
	await wait_process_frames(1)
	assert_eq(pp.get_combined_minimum_size(), before, "congelarse no cambia el tamaño")
	assert_has(pp.status_icons(), "Congelado")
	assert_gte(before.y, PlayerPanel.MIN_H_TWO_ROWS)


func test_more_than_six_items_end_in_plus_n() -> void:
	var s: Dictionary = _state(6)
	var p: Dictionary = ((Types.view_for(s, "p1")["players"] as Array)[1] as Dictionary).duplicate(true)
	var f: Dictionary = p["flags"] as Dictionary
	f["frozen"] = 1
	f["blinded"] = true
	f["force_field"] = "x"
	var arts: Array = []
	for i: int in 5:
		arts.append({"iid": 9000 + i, "card_id": Types.CARD_MAGIC_CAP})
	p["artifacts"] = arts
	var pp: PlayerPanel = PlayerPanel.create(false, 341.0, 2)
	add_child_autofree(pp)
	pp.update_player(p, false)
	await wait_process_frames(1)
	assert_eq(pp.status_row.get_child_count(), PlayerPanel.ICON_SLOTS, "6 casillas como mucho")
	var last: Node = pp.status_row.get_child(pp.status_row.get_child_count() - 1)
	assert_true(last is Label and (last as Label).text.begins_with("+"), "la última es +n")


func test_eliminated_panel_dimmed_with_full_opacity_tombstone() -> void:
	var t: TableScreen = await _table("estados", 6, BASE)
	var p3: PlayerPanel = t.ctx.players.panel_for("p3") as PlayerPanel
	var slot: Vector2 = p3.position
	assert_true(p3.is_eliminated())
	assert_has(p3.status_icons(), "ELIMINADO")
	var all: Array[Control] = []
	_visible_controls(p3, all, true)
	var stone: Control = null
	var label_ok: bool = false
	var hatch: bool = false
	var dimmed: bool = false
	for c: Control in all:
		if String(c.get_meta("status_icon", "")) == "ELIMINADO":
			stone = c
		if c is Label and (c as Label).text == PlayerPanel.TEXT_ELIMINATED:
			label_ok = true
		if c is PlayerPanel.Hatch:
			hatch = true
		if c.modulate.a < 0.99:
			dimmed = true
	assert_not_null(stone, "lápida")
	var a: float = 1.0
	var n: Node = stone
	while n != null and n is CanvasItem:
		a *= (n as CanvasItem).modulate.a
		n = n.get_parent()
	assert_eq(a, 1.0, "la lápida va a opacidad completa")
	assert_true(label_ok, "texto 'Eliminado' visible")
	assert_true(hatch, "rayado")
	assert_true(dimmed, "contenido atenuado")
	assert_eq(p3.position, slot, "conserva su sitio")
	# No seleccionable como objetivo: no está entre los objetivos permitidos de la vista.
	assert_false(Types.alive_ids(t.view).has("p3"))


# ---------------------------------------------------------------- 6. reservas de las puertas

func test_reaction_prompt_primary_buttons_and_potion_risk() -> void:
	for px: Vector2i in SIZES:
		var t: TableScreen = await _table("reaccion", 6, px)
		var rp: ReactionPrompt = t._reaction
		assert_true(t._reaction_overlay.visible, "ventana de reacción abierta")
		assert_gte(_phys(rp._drink_btn.get_global_rect(), px).size.y, _primary_min(px) - 0.5)
		assert_gte(_phys(rp._pass_btn.get_global_rect(), px).size.y, _primary_min(px) - 0.5)
		assert_gte(_gap_x(rp._drink_btn, rp._pass_btn), float(UiTheme.BUTTON_GAP_POTION) - 0.5, "24 px junto a la poción")
		# 8/10 -> mismo riesgo que la mesa (QA-V2-32-01).
		var lvl: int = TableActions.potion_risk(8, 10, true)
		assert_eq(lvl, 1)
		assert_eq(rp.drink_risk, lvl)
		assert_true(rp._drink_btn.text.begins_with("⚠"), "⚠ en el modal")
		var sb: StyleBoxFlat = rp._drink_btn.get_theme_stylebox("normal") as StyleBoxFlat
		assert_eq(sb.bg_color, TableActions.RISK_FILL[lvl], "color de riesgo del modal")
		assert_eq(rp._drink_btn.tooltip_text, t._drink_btn.tooltip_text)
		_vp.queue_free()
		_vp = null
		await wait_process_frames(1)


func test_reaction_risk_levels_unit() -> void:
	var rp: ReactionPrompt = ReactionPrompt.new()
	add_child_autofree(rp)
	rp.set_drink_risk(3, "aviso")
	rp.open({"spell": {"card": {"iid": 1, "card_id": Types.CARD_FIREBALL}, "caster": "p2", "targets": ["p1"]}},
		[], {"p1": "Ana", "p2": "Bruno"}, 0, [], "Beber poción  (10/10)", true, 1)
	assert_eq(rp._drink_btn.text, "⚠ Beber poción  (10/10)")
	assert_eq((rp._drink_btn.get_theme_stylebox("normal") as StyleBoxFlat).bg_color, TableActions.RISK_FILL[3])
	rp.set_drink_risk(0)
	assert_eq(rp._drink_btn.text, "Beber poción  (10/10)", "sin riesgo, sin ⚠")


func test_floating_numbers_above_panel_figures_and_stacked() -> void:
	var layer: FeedbackLayer = FeedbackLayer.new()
	add_child_autofree(layer)
	var panel: Control = Control.new()
	panel.position = Vector2(100, 900)
	panel.size = Vector2(800, 110)
	add_child_autofree(panel)
	layer.anchor_provider = func(_pid: String) -> Control: return panel
	for amount: int in [-2, 3]:
		layer.play({"kind": FeedbackMapper.FB_DAMAGE, "target": "p1", "amount": amount, "duration_ms": 1500})
	layer.play({"kind": FeedbackMapper.FB_MANA, "target": "p1", "amount": 3, "duration_ms": 1500})
	var rects: Array[Rect2] = []
	for c: Node in layer.get_children():
		if c is FloatingText and (c as FloatingText).visible:
			rects.append((c as FloatingText).get_global_rect())
	assert_eq(rects.size(), 3)
	for r: Rect2 in rects:
		assert_lte(r.end.y, panel.get_global_rect().position.y + 1.0, "el número no tapa las cifras del panel")
	for i: int in rects.size():
		for j: int in range(i + 1, rects.size()):
			assert_false(rects[i].grow(-2.0).intersects(rects[j].grow(-2.0)), "simultáneos sin solaparse")


func test_hand_fan_keeps_card_names_visible() -> void:
	var t: TableScreen = await _table("base", 6, BASE)
	var hv: HandView = t.ctx.hand.hand_view
	var hand: Array = []
	for i: int in 7:
		hand.append({"iid": 5000 + i, "card_id": Types.CARD_FIRE_ARROW})
	hv.set_hand(hand, [] as Array[int], true)
	await wait_process_frames(1)
	var views: Array[CardView] = []
	for c: Node in hv.get_children():
		if c is CardView:
			views.append(c as CardView)
	assert_eq(views.size(), 7)
	for i: int in range(1, views.size()):
		var step: float = views[i].position.x - views[i - 1].position.x
		assert_gte(step, views[i].size.x * HandView.MIN_VISIBLE - 0.5, "cada carta deja ver >= 78 % (nombre)")


func test_playable_frame_distinct_from_unplayable() -> void:
	var good: CardView = CardView.for_instance({"iid": 1, "card_id": Types.CARD_FIRE_ARROW}, 200.0)
	var bad: CardView = CardView.for_instance({"iid": 2, "card_id": Types.CARD_FIRE_ARROW}, 200.0)
	add_child_autofree(good)
	add_child_autofree(bad)
	good.set_playable(true)
	bad.set_playable(false)
	good.set_mode(CardView.Mode.SELECTABLE)
	bad.set_mode(CardView.Mode.SELECTABLE)
	assert_true(good._frame.visible, "marco verde en la jugable")
	assert_false(bad._frame.visible)
	var sb: StyleBoxFlat = bad._border.get_theme_stylebox("panel") as StyleBoxFlat
	assert_eq(sb.border_color, CardView.BORDER_UNPLAYABLE, "la no jugable no lleva verde")


func test_unplayable_reason_shown_once() -> void:
	var t: TableScreen = await _table("defensiva", 3, BASE)
	var shield: int = -1
	for c: Variant in t.ctx.me()["hand"] as Array:
		if String((c as Dictionary)["card_id"]) == Types.CARD_MAGIC_SHIELD:
			shield = int((c as Dictionary)["iid"])
	assert_gt(shield, -1)
	t._on_hand_tapped({"iid": shield})
	await wait_process_frames(1)
	assert_true(t.ctx.hand.info.visible, "ficha visible")
	assert_true(t._hint.visible, "la pista explica el motivo")
	assert_string_contains(t._hint.text, "defensiva")
	assert_ne(t.ctx.hand.info.reason_label.text, "", "la ficha conoce el motivo")
	assert_false(t.ctx.hand.info.reason_label.visible, "pero no lo repite (QA-V2-27-03)")


# ---------------------------------------------------------------- 7. pantallas fuera de la mesa

func test_main_buttons_of_other_screens_are_primary() -> void:
	var mm: Node = (load("res://src/ui/screens/main_menu.tscn") as PackedScene).instantiate()
	add_child_autofree(mm)
	var ls: LocalSetup = (load("res://src/ui/screens/local_setup.tscn") as PackedScene).instantiate()
	ls.auto_navigate = false
	add_child_autofree(ls)
	var pd: PassDeviceScreen = (load("res://src/ui/screens/pass_device_screen.tscn") as PackedScene).instantiate()
	add_child_autofree(pd)
	await wait_process_frames(2)
	var want_primary: Array[String] = ["Jugar local", "Empezar", "Estoy listo"]
	var seen: Array[String] = []
	for root: Node in [mm, ls, pd]:
		var all: Array[Control] = []
		_visible_controls(root, all, true)
		for c: Control in all:
			if not (c is Button):
				continue
			var b: Button = c
			if want_primary.has(b.text):
				seen.append(b.text)
				assert_gte(b.get_global_rect().size.y, float(UiTheme.BUTTON_PRIMARY_H) - 0.5, "principal '%s'" % b.text)
				assert_eq(b.theme_type_variation, UiTheme.VARIATION_PRIMARY)
			else:
				assert_gte(b.get_global_rect().size.y, float(UiTheme.BUTTON_MIN_H) - 0.5, "secundario '%s'" % b.text)
		assert_eq(_small_texts(root), [] as Array[String])
	for w: String in want_primary:
		assert_has(seen, w)


# ---------------------------------------------------------------- 8. reservas V2-33 (QA-V2-27-02)

func test_card_info_hold_hint_at_least_font_min() -> void:
	var prev_path: String = CardInfo.settings_path
	var prev_seen: bool = CardInfo._hint_seen_session
	CardInfo.settings_path = "user://test_legibility_no_settings.cfg"
	CardInfo._hint_seen_session = false
	var t: TableScreen = await _table("base", 3, BASE)
	var first: Dictionary = (t.ctx.me()["hand"] as Array)[0]
	t._on_hand_tapped({"iid": int(first["iid"])})
	await wait_process_frames(2)
	var info: CardInfo = t.ctx.hand.info
	assert_true(info.hint_label.visible, "la pista se ve la primera vez")
	assert_eq(info.hint_label.text, CardInfo.HOLD_HINT)
	assert_gte(info.hint_label.get_theme_font_size("font_size"), UiTheme.FONT_MIN, "pista >= FONT_MIN")
	assert_lte(t.ctx.hand.hand_view.get_global_rect().end.y, float(BASE.y) + 0.5, "mano dentro con la pista")
	assert_eq(_small_texts(info), [] as Array[String], "ficha sin textos < FONT_MIN")
	CardInfo.settings_path = prev_path
	CardInfo._hint_seen_session = prev_seen


func test_game_over_buttons_gap_at_least_button_gap_min() -> void:
	FakeState.install_defs()
	var v: Dictionary = FakeState.make_view(6, "p1")
	v["status"] = Types.STATUS_FINISHED
	v["winners"] = ["p1"]
	var players: Array = v["players"]
	for i: int in range(1, players.size()):
		var p: Dictionary = players[i]
		p["eliminated"] = true
		p["hp"] = 0
		p["eliminated_reason"] = Types.ELIM_HP
		p["eliminated_order"] = players.size() - i
	var prev_handler: Callable = UiNav.replay_handler
	UiNav.replay_handler = func(_t: SceneTree) -> void: pass
	var t: TableScreen = (load("res://src/ui/screens/table.tscn") as PackedScene).instantiate()
	add_child_autofree(t)
	t.set_view(v, "p1")
	await wait_process_frames(3)
	var go: TableGameOver = t.ctx.game_over
	assert_true(go.is_result_open())
	assert_true(go.play_again_button.is_visible_in_tree(), "Jugar otra vez visible")
	var col: Control = go.play_again_button.get_parent()
	assert_gte(col.get_theme_constant("separation"), UiTheme.BUTTON_GAP_MIN, "separación del contenedor")
	var btns: Array[Button] = [go.play_again_button, go.see_table_button, go.menu_button]
	for i: int in range(1, btns.size()):
		var gap: float = btns[i].get_global_rect().position.y - btns[i - 1].get_global_rect().end.y
		assert_gte(gap, float(UiTheme.BUTTON_GAP_MIN) - 0.5, "separación %s -> %s" % [btns[i - 1].text, btns[i].text])
	UiNav.replay_handler = prev_handler

extends NemTest
## V2-23: cartas jugables + ficha de la carta seleccionada (criterios-v02 ítem 3, C3-01..C3-14).
## Estados con el motor y el catálogo reales; "jugable" sale de las acciones legales.

const H = preload("res://tests/fixtures/engine_helpers.gd")
const X = preload("res://tests/engine/effects/t6c_helpers.gd")

const S3A: Array = ["fire_arrow", "fireball", "ice_bolt", "heal", "magic_shield"]
var _tmp: String = "user://test_hand_info.cfg"


func before_each() -> void:
	super.before_each()
	CardCatalog.load_json()
	EffectRegistry.reset()
	CardInfo.settings_path = _tmp
	CardInfo._hint_seen_session = false
	DirAccess.remove_absolute(ProjectSettings.globalize_path(_tmp))


func after_all() -> void:
	CardInfo.settings_path = CardInfo.SETTINGS_PATH
	CardInfo._hint_seen_session = false
	DirAccess.remove_absolute(ProjectSettings.globalize_path(_tmp))


## Estado S3-A: turno de Ana (p1), 4 vivos, maná 1, pociones 0, sin evento ni artefactos.
func _s3a(hand: Array = S3A, mana: int = 1) -> Dictionary:
	var s: Dictionary = H.game(4, {}, 7, [40, 30, 20, 25])
	H.set_hand(s, "p1", hand)
	H.set_mana(s, "p1", mana)
	H.force_turn(s, "p1")
	s["pending"] = []
	return s


func _infos(s: Dictionary, pid: String = "p1") -> Dictionary:
	var view: Dictionary = Types.view_for(s, pid)
	return CardInfo.for_hand(view, pid, ActionOptions.build(view, pid))


## Info de la carta `card_id` de la mano de `pid`.
func _of(s: Dictionary, card_id: String, pid: String = "p1") -> Dictionary:
	for i: Variant in _infos(s, pid).values():
		if String((i as Dictionary)["card_id"]) == card_id:
			return i
	return {}


func test_c3_01_fire_arrow_jugable() -> void:
	assert_true(bool(_of(_s3a(), "fire_arrow")["playable"]))


func test_c3_02_fireball_jugable_con_ficha() -> void:
	var i: Dictionary = _of(_s3a(), "fireball")
	assert_true(bool(i["playable"]))
	assert_eq(i["mana_line"], "Maná: 1")
	assert_eq(i["cards_line"], "1 carta de fuego")


func test_c3_03_mana_insuficiente_con_pocion() -> void:
	var s: Dictionary = _s3a()
	for id: String in ["ice_bolt", "heal"]:
		var i: Dictionary = _of(s, id)
		assert_false(bool(i["playable"]), id)
		assert_eq(i["reason"], "Cuesta 2 de maná y tienes 1. Bebe una poción.")


func test_c3_04_defensiva_en_turno_propio() -> void:
	var s: Dictionary = _s3a(S3A, 5)
	var i: Dictionary = _of(s, "magic_shield")
	assert_false(bool(i["playable"]))
	assert_eq(i["reason"], "Solo se juega en respuesta a un hechizo.")


func test_c3_05_falta_carta_de_fuego() -> void:
	var i: Dictionary = _of(_s3a(["fireball", "ice_bolt", "heal"]), "fireball")
	assert_false(bool(i["playable"]))
	assert_eq(i["reason"], "Te falta 1 carta de fuego.")


func test_c3_06_fire_storm_sube_el_coste() -> void:
	var s: Dictionary = _s3a()
	X.event(s, "fire_storm")
	var a: Dictionary = _of(s, "fire_arrow")
	assert_false(bool(a["playable"]))
	assert_eq(a["mana_line"], "Maná: 2 (base 1)")
	assert_eq(a["reason"], "Cuesta 2 de maná y tienes 1. Bebe una poción.")
	var f: Dictionary = _of(s, "fireball")
	assert_false(bool(f["playable"]))
	assert_eq(f["mana_line"], "Maná: 2 (base 1)")


func test_c3_06_evento_sin_efecto_de_coste() -> void:
	var s: Dictionary = _s3a()
	X.event(s, "ice_storm")
	var a: Dictionary = _of(s, "fire_arrow")
	assert_true(bool(a["playable"]))
	assert_eq(a["mana_line"], "Maná: 1")
	assert_false(String(a["mana_line"]).contains("base"))


func test_c3_07_limite_de_pociones_sin_beber() -> void:
	var s: Dictionary = _s3a()
	H.player(s, "p1")["potions"] = 10
	assert_eq(_of(s, "ice_bolt")["reason"], "Cuesta 2 de maná y tienes 1.")


func test_c3_08_cegado() -> void:
	var s: Dictionary = _s3a()
	(H.player(s, "p1")["flags"] as Dictionary)["blinded"] = true
	for id: String in ["fire_arrow", "fireball", "ice_bolt"]:
		var i: Dictionary = _of(s, id)
		assert_false(bool(i["playable"]), id)
		assert_eq(i["reason"], Strings.REASON_BLINDED)
	assert_false(bool(_of(s, "heal")["playable"]), "con 1 de maná, heal no alcanza")
	H.set_mana(s, "p1", 2)
	assert_true(bool(_of(s, "heal")["playable"]))


func test_c3_09_scroll_sustituye_la_carta_de_fuego() -> void:
	var s: Dictionary = _s3a(["fireball", "ice_bolt", "heal"], 1)
	s = X.equip(self, s, "p1", "scroll_of_elements")
	H.set_hand(s, "p1", ["fireball", "ice_bolt", "heal"])
	H.set_mana(s, "p1", 1)
	H.force_turn(s, "p1")
	s["pending"] = []
	var i: Dictionary = _of(s, "fireball")
	assert_true(bool(i["playable"]))
	assert_eq(i["cards_line"], "1 carta de fuego (o tu Scroll of Elements)")


func test_c3_10_turno_ajeno() -> void:
	var s: Dictionary = _s3a()
	H.force_turn(s, "p2")
	var infos: Dictionary = _infos(s)
	assert_eq(infos.size(), S3A.size())
	for i: Variant in infos.values():
		assert_false(bool((i as Dictionary)["playable"]))
		assert_eq((i as Dictionary)["reason"], "No es tu turno")


func test_c3_11_ventana_de_reaccion() -> void:
	var s: Dictionary = _s3a(["magic_shield", "heal", "ice_bolt"], 2)
	var b: Array = H.set_hand(s, "p2", ["fireball", "fire_arrow"])
	H.set_mana(s, "p2", 6)
	H.force_turn(s, "p2")
	var r: Dictionary = Game.reduce(s, Types.make_action_play_card("p2", int(b[0]), ["p1"], [int(b[1])]))
	assert_eq(r["error"], "")
	var rs: Dictionary = r["state"]
	assert_false((rs["reaction"] as Dictionary).is_empty(), "ventana abierta")
	var sh: Dictionary = _of(rs, "magic_shield")
	assert_true(bool(sh["playable"]))
	var h: Dictionary = _of(rs, "heal")
	assert_false(bool(h["playable"]))
	assert_eq(h["reason"], Strings.REASON_REACTION_ONLY)


func test_prompt_pendiente_no_resalta() -> void:
	var s: Dictionary = _s3a()
	s["pending"] = [Types.make_prompt(1, "p1", Types.PROMPT_MANA_SHORTFALL, {"missing": 1}, "fireball")]
	for i: Variant in _infos(s).values():
		assert_false(bool((i as Dictionary)["playable"]))
		assert_eq((i as Dictionary)["reason"], Strings.REASON_PROMPT_PENDING)


func test_c3_12_nombre_completo_sin_cortar() -> void:
	var host: Control = Control.new()
	host.custom_minimum_size = Vector2(720, 400)
	host.size = Vector2(720, 400)
	add_child_autofree(host)
	var info: CardInfo = CardInfo.new()
	info.custom_minimum_size = Vector2(692, 0)
	host.add_child(info)
	var s: Dictionary = _s3a()
	for id: String in ["magic_capture", "meteor_shower", "elixir_transmutation"]:
		H.set_hand(s, "p1", [id])
		var inst: Dictionary = (H.hand(s, "p1") as Array)[0]
		var view: Dictionary = Types.view_for(s, "p1")
		var data: Dictionary = CardInfo.evaluate(view, "p1", ActionOptions.build(view, "p1"), inst)
		info.show_info(data, inst)
		await wait_process_frames(2)
		var nm: String = String(CardCatalog.get_def(id)["name"])
		assert_eq(info.name_label.text, nm)
		assert_false(info.name_label.text.contains("..."))
		assert_ne(info.name_label.autowrap_mode, TextServer.AUTOWRAP_OFF)
		assert_eq(info.name_label.get_visible_line_count(), info.name_label.get_line_count(), id)
		assert_gte(info.name_label.size.y, float(info.name_label.get_line_count()) * 20.0, id)
		assert_lte(info.name_label.size.x, 692.0)


func test_c3_13_coherencia_con_el_motor() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 2026
	var checked: int = 0
	for n: int in 50:
		var s: Dictionary = H.game(4, {}, 100 + n, [40, 30, 20, 25])
		var pid: String = "p%d" % ((n % 4) + 1)
		H.force_turn(s, pid)
		H.set_mana(s, pid, rng.randi_range(0, 5))
		s["pending"] = []
		var view: Dictionary = Types.view_for(s, pid)
		var legal: Dictionary = {}
		for a: Variant in Game.legal_actions(view, pid):
			if String((a as Dictionary)["type"]) == Types.ACTION_PLAY_CARD:
				legal[int((a as Dictionary)["card"])] = true
		var shown: Dictionary = {}
		for iid: Variant in _infos(s, pid):
			if bool((_infos(s, pid)[iid] as Dictionary)["playable"]):
				shown[iid] = true
		assert_eq(shown.keys().size(), legal.keys().size(), "estado %d" % n)
		for k: Variant in legal:
			assert_true(shown.has(k), "estado %d iid %s" % [n, k])
		checked += (view["players"] as Array).size()
	assert_gt(checked, 0)


func test_c3_14_coste_nunca_negativo() -> void:
	var s: Dictionary = _s3a()
	s["modifiers"] = [Types.make_modifier("test#1", Types.STAGE_COST, Types.OP_ADD, -5, "", Types.SIDE_ANY)]
	var i: Dictionary = _of(s, "fire_arrow")
	assert_eq(int(i["cost"]), 0)
	assert_eq(i["mana_line"], "Maná: 0 (base 1)")
	assert_eq(Strings.mana_line(-3, 1), "Maná: 0 (base 1)")


func test_ficha_tipo_y_elemento() -> void:
	var s: Dictionary = _s3a()
	var f: Dictionary = _of(s, "fire_arrow")
	assert_eq(f["type_line"], "Tipo: Ofensiva")
	assert_eq(f["element_line"], "Elemento: fuego")
	assert_eq(_of(s, "heal")["element_line"], "Elemento: sin elemento")


func test_boton_ver_abre_el_zoom_y_la_pista_se_guarda() -> void:
	var info: CardInfo = CardInfo.new()
	add_child_autofree(info)
	var s: Dictionary = _s3a()
	var inst: Dictionary = (H.hand(s, "p1") as Array)[0]
	var view: Dictionary = Types.view_for(s, "p1")
	info.show_info(CardInfo.evaluate(view, "p1", ActionOptions.build(view, "p1"), inst), inst)
	assert_true(info.visible)
	assert_true(info.view_button.visible)
	assert_gte(info.view_button.custom_minimum_size.y, float(UiTheme.BUTTON_MIN_H))
	assert_eq(info.view_button.text, "Ver")
	assert_true(info.hint_label.visible, "primera vez: pista")
	assert_eq(info.hint_label.text, "Mantén pulsada una carta para verla")
	var got: Array = []
	info.view_requested.connect(func(c: Dictionary, _d: Dictionary) -> void: got.append(int(c["iid"])))
	info.view_button.pressed.emit()
	assert_eq(got, [int(inst["iid"])])
	assert_true(CardInfo.hint_seen())
	CardInfo._hint_seen_session = false
	assert_true(CardInfo.hint_seen(), "persistida en el fichero de ajustes")
	info.show_info(CardInfo.evaluate(view, "p1", ActionOptions.build(view, "p1"), inst), inst)
	assert_false(info.hint_label.visible, "ya no se repite")


func test_card_view_marco_y_atenuado() -> void:
	var cv: CardView = CardView.for_instance({"iid": 1, "card_id": "fire_arrow"}, 200.0)
	add_child_autofree(cv)
	cv.set_mode(CardView.Mode.SELECTABLE)
	cv.set_playable(true)
	assert_true(cv._frame.visible)
	assert_eq(cv.modulate, Color.WHITE)
	cv.set_playable(false)
	assert_false(cv._frame.visible)
	assert_lt(cv.modulate.r, 0.7, "atenuada")
	var sb: StyleBoxTexture = cv._frame.get_theme_stylebox("panel") as StyleBoxTexture
	assert_not_null(sb.texture)
	assert_eq(sb.get_texture_margin(SIDE_LEFT), 14.0)


func test_mesa_resalta_y_muestra_ficha() -> void:
	var s: Dictionary = _s3a()
	var t: TableScreen = (load("res://src/ui/screens/table.tscn") as PackedScene).instantiate()
	add_child_autofree(t)
	t.set_view(Types.view_for(s, "p1"), "p1")
	await wait_process_frames(2)
	var hv: HandView = t._hand
	assert_eq(hv.playable.size(), S3A.size())
	var fa: int = int(_of(s, "fire_arrow")["iid"])
	var ib: int = int(_of(s, "ice_bolt")["iid"])
	assert_true(bool(hv.playable[fa]))
	assert_false(bool(hv.playable[ib]))
	assert_false(t._ctx.hand.info.visible, "sin selección no hay ficha")
	assert_true(t._ctx.hand._gap.visible, "pero se reserva el hueco")
	t._on_hand_tapped({"iid": ib})
	await wait_process_frames(2)
	var info: CardInfo = t._ctx.hand.info
	assert_true(info.visible)
	assert_eq(info.name_label.text, "Ice Bolt")
	assert_eq(info.reason_label.text, "Cuesta 2 de maná y tienes 1. Bebe una poción.")
	var zoomed: Array = []
	info.view_requested.connect(func(c: Dictionary, _d: Dictionary) -> void: zoomed.append(int(c["iid"])))
	info.view_button.pressed.emit()
	assert_eq(zoomed, [ib])
	assert_true(t._zoom.visible, "el botón Ver abre el zoom")

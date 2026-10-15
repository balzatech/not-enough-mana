extends NemTest
## V2-28: resúmenes en español de la ficha y el zoom.

const OK_PATH: String = "res://data/card_summaries_es.json"


func before_each() -> void:
	super.before_each()
	CardInfo.summaries_path = OK_PATH
	CardInfo.reload_summaries()
	FakeState.install_defs()


func after_all() -> void:
	CardInfo.summaries_path = OK_PATH
	CardInfo.reload_summaries()


func test_los_61_disenos_tienen_resumen_valido() -> void:
	if not FileAccess.file_exists(OK_PATH):
		pending("sin data/card_summaries_es.json (no versionado)")
		return
	CardCatalog.load_json()
	var n: int = 0
	for id: Variant in CardCatalog.all_defs():
		var s: String = CardInfo.summary(String(id))
		assert_ne(s, "", "resumen de %s" % id)
		assert_lte(s.length(), 95, "longitud de %s" % id)
		assert_false(s.contains("_"), "sin guion bajo en %s" % id)
		n += 1
	assert_eq(n, 61)


func test_resumenes_corregidos_por_el_game_designer() -> void:
	if not FileAccess.file_exists(OK_PATH):
		pending("sin archivo de resúmenes")
		return
	assert_eq(CardInfo.summary("lightning"),
		"El objetivo pierde 2 de vida; si responde con otro Lightning, +1 de daño y se redirige.")
	assert_eq(CardInfo.summary("last_wish"),
		"Defensiva: si un hechizo de otro mago te mata, él recibe ese mismo daño. Mueres igual.")


func test_la_ficha_muestra_el_resumen() -> void:
	if not FileAccess.file_exists(OK_PATH):
		pending("sin archivo de resúmenes")
		return
	var ci: CardInfo = CardInfo.new()
	add_child_autofree(ci)
	var inst: Dictionary = {"iid": 1, "card_id": "fire_arrow"}
	ci.show_info({"name": "Fire Arrow", "mana_line": "1 de maná", "cards_line": "",
		"type_line": "Tipo: ofensiva", "element_line": "Elemento: fuego", "reason": ""}, inst)
	assert_true(ci.summary_label.visible)
	assert_eq(ci.summary_label.text, "El objetivo pierde 1 de vida.")
	assert_gte(ci.summary_label.get_theme_font_size("font_size"), UiTheme.FONT_MIN)


func test_el_zoom_muestra_el_resumen() -> void:
	if not FileAccess.file_exists(OK_PATH):
		pending("sin archivo de resúmenes")
		return
	var host: Control = Control.new()
	host.size = Vector2(540, 960)
	add_child_autofree(host)
	var z: CardZoom = CardZoom.new()
	host.add_child(z)
	z.show_card({"iid": 1, "card_id": "heal"}, UiUtil.card_def("heal"))
	var found: bool = false
	for l: Node in z._holder.get_child(0).get_children():
		if l is Label and (l as Label).text == "El objetivo gana 1 de vida.":
			found = true
	assert_true(found)


func test_sin_archivo_no_hay_error_ni_resumen() -> void:
	CardInfo.summaries_path = "res://data/no_existe_xyz.json"
	CardInfo.reload_summaries()
	assert_eq(CardInfo.summary("fire_arrow"), "")
	var ci: CardInfo = CardInfo.new()
	add_child_autofree(ci)
	ci.show_info({"name": "Fire Arrow", "mana_line": "1", "cards_line": "", "type_line": "t",
		"element_line": "e", "reason": ""}, {"iid": 1, "card_id": "fire_arrow"})
	assert_false(ci.summary_label.visible)
	var host: Control = Control.new()
	host.size = Vector2(540, 960)
	add_child_autofree(host)
	var z: CardZoom = CardZoom.new()
	host.add_child(z)
	z.show_card({"iid": 1, "card_id": "heal"}, UiUtil.card_def("heal"))
	assert_true(z.visible)


func test_archivo_corrupto_se_ignora() -> void:
	var p: String = "user://resumenes_corruptos.json"
	var f: FileAccess = FileAccess.open(p, FileAccess.WRITE)
	f.store_string("{no es json")
	f.close()
	CardInfo.summaries_path = p
	CardInfo.reload_summaries()
	assert_eq(CardInfo.summary("heal"), "")
	# No dejar basura en la carpeta de datos del usuario.
	DirAccess.remove_absolute(ProjectSettings.globalize_path(p))

extends GutTest
## Fuente de respaldo con los símbolos de la UI (V2-P1, docs/rendimiento/v02-final.md).
## Sin ella, cada texto con ▼ ▲ ⚠ → busca una fuente del SO (3,7-5,8 ms) y en Web/Android puede salir un cuadrado.


func _fallback_font() -> Font:
	return load(UiTheme.FONT_FALLBACK_PATH) as Font


func test_fallback_font_has_all_ui_glyphs() -> void:
	var f: Font = _fallback_font()
	assert_not_null(f, "la fuente de respaldo se importa")
	for i: int in UiTheme.FALLBACK_GLYPHS.length():
		var ch: String = UiTheme.FALLBACK_GLYPHS[i]
		assert_true(f.has_char(ch.unicode_at(0)), "DejaVu Sans tiene '%s'" % ch)
	for g: String in [UiTheme.GLYPH_DAMAGE, UiTheme.GLYPH_HEAL, "⚠", "→"]:
		assert_true(UiTheme.FALLBACK_GLYPHS.contains(g), "FALLBACK_GLYPHS cubre %s" % g)


func test_fallback_does_not_search_system_fonts() -> void:
	var f: FontFile = _fallback_font() as FontFile
	assert_not_null(f)
	assert_false(f.allow_system_fallback, "sin búsqueda de fuentes del SO (coste y Web/Android)")


func test_theme_default_font_has_the_fallback() -> void:
	for t: Theme in [UiTheme.build(), UiTheme.get_theme()]:
		assert_true(t.has_default_font(), "el tema define default_font")
		var fv: FontVariation = t.default_font as FontVariation
		assert_not_null(fv)
		assert_eq(fv.fallbacks.size(), 1)
		assert_eq(fv.fallbacks[0].resource_path, UiTheme.FONT_FALLBACK_PATH)
		for i: int in UiTheme.FALLBACK_GLYPHS.length():
			assert_true(fv.has_char(UiTheme.FALLBACK_GLYPHS.unicode_at(i)),
					"la fuente del tema resuelve '%s'" % UiTheme.FALLBACK_GLYPHS[i])


func test_saved_theme_matches_generator() -> void:
	## theme.tres regenerado: lo guardado y lo que construye build() usan el mismo respaldo.
	var saved: Theme = load(UiTheme.PATH) as Theme
	var fv: FontVariation = saved.default_font as FontVariation
	assert_not_null(fv, "theme.tres tiene default_font (regenerar si falla)")
	assert_eq(fv.fallbacks.size(), 1)
	assert_eq(fv.variation_embolden, 0.0)
	var b: FontVariation = saved.get_font("bold_font", "RichTextLabel") as FontVariation
	assert_not_null(b, "el [b] del registro conserva su negrita sintética")
	assert_gt(b.variation_embolden, 1.0)


func test_float_text_uses_covered_glyphs() -> void:
	var th: Theme = UiTheme.build()
	for dmg: bool in [true, false]:
		var txt: String = UiTheme.float_text(3, dmg)
		for i: int in txt.length():
			assert_true(th.default_font.has_char(txt.unicode_at(i)), "'%s' en '%s'" % [txt[i], txt])


func test_license_ships_with_font() -> void:
	assert_true(FileAccess.file_exists("res://assets/fonts/LICENSE-DejaVu.txt"))

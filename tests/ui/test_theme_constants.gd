extends GutTest
## Constantes de accesibilidad del tema (V2-18, V2-40).


func test_constants() -> void:
	assert_eq(UiTheme.BUTTON_PRIMARY_H, 144)
	assert_eq(UiTheme.BUTTON_MIN_H, 96)
	assert_eq(UiTheme.FONT_MIN, 22)
	assert_true(UiTheme.BUTTON_PRIMARY_H >= UiTheme.BUTTON_MIN_H)
	assert_true(UiTheme.BUTTON_GAP_POTION > UiTheme.BUTTON_GAP_MIN)


func test_theme_has_explicit_font_with_fallback() -> void:
	var t: Theme = UiTheme.build()
	assert_true(t.has_default_font())
	assert_eq(t.default_font_size, UiTheme.FONT_BODY)
	assert_true(ResourceLoader.exists(UiTheme.FONT_FALLBACK_PATH))


func test_apply_primary_sets_min_height() -> void:
	var b: Button = Button.new()
	UiTheme.apply_primary(b)
	assert_eq(b.custom_minimum_size.y, float(UiTheme.BUTTON_PRIMARY_H))
	assert_eq(b.theme_type_variation, UiTheme.VARIATION_PRIMARY)
	b.free()


func test_apply_primary_keeps_larger_min_and_width() -> void:
	var b: Button = Button.new()
	b.custom_minimum_size = Vector2(200, 300)
	UiTheme.apply_primary(b)
	assert_eq(b.custom_minimum_size, Vector2(200, 300))
	b.free()


func test_theme_has_primary_variation() -> void:
	var t: Theme = UiTheme.build()
	assert_true(t.get_type_list().has(UiTheme.VARIATION_PRIMARY))
	assert_eq(t.get_type_variation_base(UiTheme.VARIATION_PRIMARY), &"Button")


## Contraste WCAG entre dos colores opacos.
func _lum(c: Color) -> float:
	var ch: Array[float] = [c.r, c.g, c.b]
	for i: int in 3:
		ch[i] = ch[i] / 12.92 if ch[i] <= 0.03928 else pow((ch[i] + 0.055) / 1.055, 2.4)
	return 0.2126 * ch[0] + 0.7152 * ch[1] + 0.0722 * ch[2]


func _contrast(a: Color, b: Color) -> float:
	var x: float = _lum(a)
	var y: float = _lum(b)
	return (maxf(x, y) + 0.05) / (minf(x, y) + 0.05)


func test_primary_variation_differs_from_button() -> void:
	var t: Theme = UiTheme.build()
	var pv: String = UiTheme.VARIATION_PRIMARY
	for st: String in ["normal", "hover", "pressed", "disabled"]:
		var p: StyleBoxFlat = t.get_stylebox(st, pv) as StyleBoxFlat
		var s: StyleBoxFlat = t.get_stylebox(st, "Button") as StyleBoxFlat
		assert_ne(p.bg_color, s.bg_color, "fondo %s distinto del Button" % st)
		assert_ne(p.border_color, s.border_color, "borde %s distinto del Button" % st)
	var pn: StyleBoxFlat = t.get_stylebox("normal", pv) as StyleBoxFlat
	assert_true(pn.border_width_left >= 3, "borde grueso (no solo color)")
	assert_true(pn.border_width_left > (t.get_stylebox("normal", "Button") as StyleBoxFlat).border_width_left)


func test_primary_text_contrast() -> void:
	var t: Theme = UiTheme.build()
	var pv: String = UiTheme.VARIATION_PRIMARY
	var pairs: Array = [["normal", "font_color"], ["hover", "font_hover_color"],
		["pressed", "font_pressed_color"], ["disabled", "font_disabled_color"],
		["normal", "font_focus_color"]]
	for pr: Array in pairs:
		var bg: Color = (t.get_stylebox(pr[0], pv) as StyleBoxFlat).bg_color
		var fg: Color = t.get_color(pr[1], pv)
		assert_gte(_contrast(fg, bg), 4.5, "contraste %s/%s" % [pr[0], pr[1]])


func test_primary_keeps_height_and_instance_override_wins() -> void:
	var b: Button = Button.new()
	UiTheme.apply_primary(b)
	assert_gte(b.custom_minimum_size.y, 144.0)
	var ov: StyleBoxFlat = UiTheme.box(Color(0.62, 0.30, 0.08), 22, Color.RED, 4)
	b.add_theme_stylebox_override("normal", ov)
	b.theme = UiTheme.build()
	assert_eq(b.get_theme_stylebox("normal"), ov, "el override de instancia (riesgo de poción) manda")
	b.free()

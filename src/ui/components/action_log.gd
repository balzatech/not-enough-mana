class_name ActionLog
extends Control
## Registro de acciones plegable: franja con las 3 últimas entradas; al tocar se despliega.

signal toggled(expanded: bool)

const STRIP_H: int = 104
const STRIP_LINES: int = 3
const STRIP_FONT: int = 22
## Aire sobre la franja: el botón "Menú" de arriba queda a 8 (separación de la raíz) + 8 = 16 px (QA-V2-35-01).
const STRIP_TOP_GAP: int = 8

var expanded: bool = false
var lines: Array[String] = []
var names: Dictionary = {}
var _strip: Button
var _strip_text: RichTextLabel
var _overlay: PanelContainer
var _scroll: ScrollContainer
var _list: VBoxContainer


func _ready() -> void:
	custom_minimum_size = Vector2(0, STRIP_H)
	mouse_filter = Control.MOUSE_FILTER_PASS
	_strip = UiUtil.button("", 24, STRIP_H - STRIP_TOP_GAP)
	_strip.custom_minimum_size = Vector2(0, STRIP_H - STRIP_TOP_GAP)
	_strip.set_anchors_preset(Control.PRESET_FULL_RECT)
	_strip.offset_top = STRIP_TOP_GAP
	_strip.pressed.connect(toggle)
	add_child(_strip)
	_strip_text = _rich(STRIP_FONT)
	_strip_text.fit_content = false
	_strip_text.clip_contents = true
	_strip_text.set_anchors_preset(Control.PRESET_FULL_RECT)
	_strip_text.offset_left = 14
	_strip_text.offset_right = -14
	_strip_text.offset_top = STRIP_TOP_GAP + 6
	_strip_text.offset_bottom = -4
	add_child(_strip_text)
	_overlay = PanelContainer.new()
	_overlay.z_index = 20
	_overlay.add_theme_stylebox_override("panel", UiTheme.box(Color(0.08, 0.08, 0.13, 1.0), 20, UiTheme.COL_ACCENT, 3, 18, 14))
	_overlay.visible = false
	_overlay.position = Vector2(0, STRIP_H + 6)
	_overlay.custom_minimum_size = Vector2(0, 640)
	add_child(_overlay)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_overlay.add_child(_scroll)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 6)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_list)
	resized.connect(_fit_overlay)
	_refresh()


func _fit_overlay() -> void:
	if _overlay != null:
		_overlay.size = Vector2(size.x, 640)


func toggle() -> void:
	set_expanded(not expanded)


func set_expanded(v: bool) -> void:
	expanded = v
	if _overlay != null:
		_overlay.visible = v
		_fit_overlay()
	toggled.emit(v)
	if v:
		_scroll_to_end.call_deferred()


func _scroll_to_end() -> void:
	if _scroll != null:
		_scroll.scroll_vertical = int(_scroll.get_v_scroll_bar().max_value)


func _rich(font_size: int) -> RichTextLabel:
	var r: RichTextLabel = RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	r.add_theme_font_size_override("normal_font_size", font_size)
	r.add_theme_font_size_override("bold_font_size", font_size)
	r.add_theme_color_override("default_color", UiTheme.COL_TEXT)
	return r


## Sustituye el contenido con las entradas del log de la vista.
func set_entries(entries: Array, p_names: Dictionary) -> void:
	names = p_names
	lines.clear()
	for e: Variant in entries:
		lines.append(LogText.format(e as Dictionary, p_names))
	if is_node_ready():
		_refresh()


## Las últimas n líneas (la más reciente abajo).
func strip_lines() -> Array[String]:
	var out: Array[String] = []
	for i: int in range(maxi(lines.size() - STRIP_LINES, 0), lines.size()):
		out.append(lines[i])
	return out


func _refresh() -> void:
	var shown: Array[String] = strip_lines()
	if shown.is_empty():
		_strip_text.text = "Registro vacío"
	else:
		var parts: Array[String] = []
		for l: String in shown:
			parts.append(LogText.highlight(l, names))
		_strip_text.text = "\n".join(parts)
	UiUtil.clear_children(_list)
	for l: String in lines:
		var lab: RichTextLabel = _rich(26)
		lab.text = LogText.highlight(l, names)
		lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_list.add_child(lab)

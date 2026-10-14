class_name GameOverSummary
extends VBoxContainer
## Resultado de fin de partida (V2-26c): título, subtítulo y una fila por mago ordenada
## por posición (causa, golpe final, turnos y pociones). Recibe MatchSummary.build();
## los textos ya vienen formateados. La lista se desplaza; la cabecera queda fija.

const POS_W: int = 84

var title_label: Label
var subtitle_label: Label
var scroll: ScrollContainer
var rows_box: VBoxContainer
var row_nodes: Array[Control] = []


func _init() -> void:
	add_theme_constant_override("separation", 12)
	title_label = UiUtil.label("", UiTheme.FONT_FLOAT, UiTheme.COL_TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(title_label)
	subtitle_label = UiUtil.label("", UiTheme.FONT_BODY, UiTheme.COL_TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(subtitle_label)
	scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	rows_box = VBoxContainer.new()
	rows_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows_box.add_theme_constant_override("separation", 10)
	scroll.add_child(rows_box)


func show_summary(summary: Dictionary) -> void:
	title_label.text = String(summary.get("title", ""))
	var sub: String = String(summary.get("subtitle", ""))
	subtitle_label.text = sub
	subtitle_label.visible = sub != ""
	UiUtil.clear_children(rows_box)
	row_nodes.clear()
	var prev_pos: int = -1
	for r: Variant in (summary.get("rows", []) as Array):
		var row: Dictionary = r
		var pos: int = int(row.get("position", 0))
		# Empates (eliminación simultánea): misma posición, se muestra una vez por grupo.
		var node: Control = _make_row(row, pos != prev_pos)
		prev_pos = pos
		rows_box.add_child(node)
		row_nodes.append(node)


## Todo el texto visible del resumen (para pruebas y para comparar reaperturas).
func all_text() -> String:
	var parts: Array[String] = [title_label.text, subtitle_label.text]
	for n: Control in row_nodes:
		for l: Node in n.find_children("*", "Label", true, false):
			parts.append((l as Label).text)
	return "\n".join(parts)


func _make_row(row: Dictionary, show_pos: bool) -> Control:
	var winner: bool = bool(row.get("winner", false))
	var panel: PanelContainer = PanelContainer.new()
	var bg: Color = Color(0.2, 0.16, 0.05, 0.9) if winner else Color(0.1, 0.1, 0.16, 0.9)
	panel.add_theme_stylebox_override("panel", UiTheme.box(bg, 14))
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	var h: HBoxContainer = HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	panel.add_child(h)
	var pos: Label = UiUtil.label("%dº" % int(row.get("position", 0)) if show_pos else "",
		UiTheme.FONT_BUTTON, UiTheme.COL_TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	pos.custom_minimum_size = Vector2(POS_W, 0)
	h.add_child(pos)
	var col: VBoxContainer = VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 2)
	h.add_child(col)
	var main: Label = UiUtil.label(String(row.get("text", "")), UiTheme.FONT_BODY)
	main.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(main)
	var stats: Label = UiUtil.label(String(row.get("stats", "")), UiTheme.FONT_MIN, Color(0.75, 0.75, 0.8))
	stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(stats)
	return panel

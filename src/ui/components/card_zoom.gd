class_name CardZoom
extends Control
## Overlay con la carta ampliada. Un toque en cualquier sitio la cierra.

var _dim: ColorRect
var _holder: CenterContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 100
	visible = false
	_dim = ColorRect.new()
	_dim.color = Color(0, 0, 0, 0.82)
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_dim)
	_holder = CenterContainer.new()
	_holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_holder)


func show_card(card: Dictionary, def: Dictionary) -> void:
	UiUtil.clear_children(_holder)
	var col: VBoxContainer = VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var w: float = minf(size.x - 120.0, (size.y - 380.0) / CardView.ASPECT)
	var cv: CardView = CardView.create(card, def, w)
	cv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(cv)
	var sm: String = CardInfo.summary(String(card.get("card_id", "")))
	if sm != "":
		var sl: Label = UiUtil.label(sm, UiTheme.FONT_MIN, UiTheme.COL_TEXT, HORIZONTAL_ALIGNMENT_CENTER)
		sl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		sl.custom_minimum_size.x = w
		col.add_child(sl)
	var hint: Label = UiUtil.label("Toca para cerrar", 26, UiTheme.COL_MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	col.add_child(hint)
	_holder.add_child(col)
	visible = true


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
			visible = false

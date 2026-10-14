class_name PassDeviceScreen
extends Control
## Pantalla de hot-seat: oculta la mano mientras se pasa el dispositivo.

signal confirmed

var player_name: String = ""
var reason: String = ""  ## texto del motivo (Strings.pass_device_reason)
var _title: Label
var _reason_label: Label
var _button: Button


func _ready() -> void:
	theme = UiTheme.get_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0.04, 0.03, 0.08, 1.0)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 40)
	col.custom_minimum_size = Vector2(800, 0)
	center.add_child(col)
	col.add_child(UiUtil.label(Strings.PASS_DEVICE_TITLE, 52, UiTheme.COL_MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	_title = UiUtil.label("", 76, UiTheme.COL_ACCENT, HORIZONTAL_ALIGNMENT_CENTER)
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_title)
	_reason_label = UiUtil.label("", 38, UiTheme.COL_TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	_reason_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_reason_label)
	col.add_child(UiUtil.label(Strings.PASS_DEVICE_HINT, 30, UiTheme.COL_MUTED,
		HORIZONTAL_ALIGNMENT_CENTER))
	_button = UiUtil.button("Estoy listo", 44, UiTheme.BUTTON_PRIMARY_H)
	UiTheme.apply_primary(_button)
	_button.pressed.connect(_on_pressed)
	col.add_child(_button)
	_refresh()


## Muestra la pantalla para `p_name`; `p_reason` = Strings.PASS_REASON_* ("" = turno).
func show_for(p_name: String, p_reason: String = Strings.PASS_REASON_TURN) -> void:
	player_name = p_name
	reason = Strings.pass_device_reason(p_reason, p_name)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = true
	_refresh()


func _refresh() -> void:
	if _title != null:
		_title.text = player_name
	if _reason_label != null:
		_reason_label.text = reason
		_reason_label.visible = reason != ""
	if _button != null:
		_button.text = Strings.pass_device_button(player_name) if player_name != "" else "Estoy listo"


func _on_pressed() -> void:
	visible = false
	confirmed.emit()

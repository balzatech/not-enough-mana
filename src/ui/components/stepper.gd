class_name Stepper
extends HBoxContainer
## Selector numérico táctil: [-] valor [+]. Con `labels` muestra textos en vez de números.

signal value_changed(value: int)

var value: int = 0
var min_value: int = 0
var max_value: int = 10
var labels: Array[String] = []
var _minus: Button
var _plus: Button
var _label: Label


static func create(p_value: int, p_min: int, p_max: int, p_labels: Array[String] = []) -> Stepper:
	var s: Stepper = Stepper.new()
	s.min_value = p_min
	s.max_value = p_max
	s.labels = p_labels
	s.value = clampi(p_value, p_min, p_max)
	return s


func _ready() -> void:
	add_theme_constant_override("separation", 6)
	_minus = UiUtil.button("-", 36)
	_minus.custom_minimum_size = Vector2(80, 80)
	_minus.pressed.connect(_step.bind(-1))
	add_child(_minus)
	_label = UiUtil.label("", 30, UiTheme.COL_TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.custom_minimum_size = Vector2(120, 80)
	_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(_label)
	_plus = UiUtil.button("+", 36)
	_plus.custom_minimum_size = Vector2(80, 80)
	_plus.pressed.connect(_step.bind(1))
	add_child(_plus)
	_refresh()


func set_value(v: int) -> void:
	value = clampi(v, min_value, max_value)
	_refresh()


func _step(delta: int) -> void:
	var nv: int = value + delta
	if nv < min_value:
		nv = max_value
	elif nv > max_value:
		nv = min_value
	if labels.is_empty():
		nv = clampi(value + delta, min_value, max_value)
	if nv == value:
		return
	value = nv
	_refresh()
	value_changed.emit(value)


func _refresh() -> void:
	if _label == null:
		return
	if labels.is_empty():
		_label.text = str(value)
	else:
		_label.text = labels[clampi(value - min_value, 0, labels.size() - 1)]

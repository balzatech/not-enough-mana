class_name LocalSetup
extends Control
## Configuración de partida local (RF1): 3-6 jugadores y opciones.
##
## Emite start_requested(setup) con:
##   {players: [{name, age, birth_month, is_bot}], config: {potion_limit_enabled,
##    potion_limit, potion_mana, include_curse_of_rules, reaction_timeout_local_ms}}

signal start_requested(setup: Dictionary)
signal back_requested

const MIN_PLAYERS: int = 3
const MAX_PLAYERS: int = 6
const TIMEOUTS_MS: Array[int] = [0, 10000, 15000, 30000]
const TIMEOUT_LABELS: Array[String] = ["Sin límite", "10 s", "15 s", "30 s"]

## Si true navega solo con UiNav (poner a false en tests).
var auto_navigate: bool = true

var _rows: Array[Dictionary] = []
var _list: VBoxContainer
var _add_btn: Button
var _remove_btn: Button
var _limit_toggle: Button
var _limit_step: Stepper
var _potion_step: Stepper
var _curse_toggle: Button
var _timer_step: Stepper


func _ready() -> void:
	theme = UiTheme.get_theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(UiUtil.make_background())
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 32)
	margin.add_theme_constant_override("margin_top", 40)
	margin.add_theme_constant_override("margin_bottom", 24)
	add_child(margin)
	var root: VBoxContainer = VBoxContainer.new()
	root.add_theme_constant_override("separation", 16)
	margin.add_child(root)
	root.add_child(UiUtil.label("Partida local", 60, UiTheme.COL_ACCENT, HORIZONTAL_ALIGNMENT_CENTER))
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	var content: VBoxContainer = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 16)
	scroll.add_child(content)
	content.add_child(UiUtil.label("Jugadores (3 a 6)", 36))
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 14)
	content.add_child(_list)
	var count_row: HBoxContainer = HBoxContainer.new()
	count_row.add_theme_constant_override("separation", UiTheme.BUTTON_GAP_MIN)
	_add_btn = UiUtil.button("Añadir jugador", 28, UiTheme.BUTTON_MIN_H)
	_add_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_add_btn.pressed.connect(add_player)
	_remove_btn = UiUtil.button("Quitar último", 28, UiTheme.BUTTON_MIN_H)
	_remove_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_remove_btn.pressed.connect(remove_player)
	count_row.add_child(_add_btn)
	count_row.add_child(_remove_btn)
	content.add_child(count_row)
	content.add_child(UiUtil.label("Opciones", 36))
	content.add_child(_build_options())
	var bottom: HBoxContainer = HBoxContainer.new()
	bottom.add_theme_constant_override("separation", UiTheme.BUTTON_GAP_MIN)
	var back: Button = UiUtil.button("Atrás", 36, UiTheme.BUTTON_MIN_H)
	back.custom_minimum_size = Vector2(260, UiTheme.BUTTON_MIN_H)
	back.pressed.connect(_on_back)
	bottom.add_child(back)
	var start: Button = UiUtil.button("Empezar", 44, UiTheme.BUTTON_PRIMARY_H)
	UiTheme.apply_primary(start)
	start.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	start.pressed.connect(_on_start)
	bottom.add_child(start)
	root.add_child(bottom)
	for i: int in MIN_PLAYERS:
		add_player()
	(_rows[1]["bot"] as Button).button_pressed = true
	(_rows[2]["bot"] as Button).button_pressed = true


func _build_options() -> Control:
	var panel: PanelContainer = PanelContainer.new()
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	panel.add_child(col)
	_limit_toggle = UiUtil.toggle_button("Límite de pociones: activado", "Límite de pociones: desactivado", true, 28)
	_limit_toggle.custom_minimum_size.y = UiTheme.BUTTON_MIN_H
	col.add_child(_limit_toggle)
	col.add_child(UiUtil.label("Pociones permitidas (Too Much Mana)", 26, UiTheme.COL_MUTED))
	_limit_step = Stepper.create(10, 1, 30)
	col.add_child(_limit_step)
	PromptDialog.size_stepper(_limit_step, false)
	col.add_child(UiUtil.label("Maná que da una poción", 26, UiTheme.COL_MUTED))
	_potion_step = Stepper.create(3, 1, 9)
	col.add_child(_potion_step)
	PromptDialog.size_stepper(_potion_step, false)
	_curse_toggle = UiUtil.toggle_button("Curse of Rules: incluida", "Curse of Rules: fuera del mazo", true, 28)
	_curse_toggle.custom_minimum_size.y = UiTheme.BUTTON_MIN_H
	col.add_child(_curse_toggle)
	col.add_child(UiUtil.label("Temporizador de reacción", 26, UiTheme.COL_MUTED))
	_timer_step = Stepper.create(0, 0, TIMEOUT_LABELS.size() - 1, TIMEOUT_LABELS)
	col.add_child(_timer_step)
	PromptDialog.size_stepper(_timer_step, false)
	return panel


func player_count() -> int:
	return _rows.size()


func add_player() -> void:
	if _rows.size() >= MAX_PLAYERS:
		return
	var idx: int = _rows.size()
	var panel: PanelContainer = PanelContainer.new()
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	panel.add_child(col)
	var name_edit: LineEdit = LineEdit.new()
	name_edit.placeholder_text = "Nombre del mago %d" % (idx + 1)
	name_edit.text = "Mago %d" % (idx + 1)
	name_edit.custom_minimum_size = Vector2(0, 84)
	col.add_child(name_edit)
	var grid: GridContainer = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_child(UiUtil.label("Edad", 26, UiTheme.COL_MUTED))
	grid.add_child(UiUtil.label("Mes de nacimiento", 26, UiTheme.COL_MUTED))
	var age: Stepper = Stepper.create(25 + idx * 3, 1, 99)
	age.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(age)
	PromptDialog.size_stepper(age, false)
	var months: Array[String] = []
	for m: String in UiUtil.MONTHS:
		months.append(m.substr(0, 3))
	var month: Stepper = Stepper.create(1 + idx * 2, 1, 12, months)
	month.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(month)
	PromptDialog.size_stepper(month, false)
	col.add_child(grid)
	var bot: Button = UiUtil.toggle_button("Bot", "Humano", false, 28)
	bot.custom_minimum_size.y = UiTheme.BUTTON_MIN_H
	col.add_child(bot)
	_list.add_child(panel)
	_rows.append({"panel": panel, "name": name_edit, "age": age, "month": month, "bot": bot})
	_update_count_buttons()


func remove_player() -> void:
	if _rows.size() <= MIN_PLAYERS:
		return
	var row: Dictionary = _rows.pop_back()
	var panel: PanelContainer = row["panel"]
	_list.remove_child(panel)
	panel.queue_free()
	_update_count_buttons()


func _update_count_buttons() -> void:
	if _add_btn != null:
		_add_btn.disabled = _rows.size() >= MAX_PLAYERS
		_remove_btn.disabled = _rows.size() <= MIN_PLAYERS


## Configuración tal como la espera la sesión local.
func get_setup() -> Dictionary:
	var players: Array = []
	for i: int in _rows.size():
		var row: Dictionary = _rows[i]
		var name_edit: LineEdit = row["name"]
		var age: Stepper = row["age"]
		var month: Stepper = row["month"]
		var bot: Button = row["bot"]
		var nm: String = name_edit.text.strip_edges()
		if nm == "":
			nm = "Mago %d" % (i + 1)
		players.append({"name": nm, "age": age.value, "birth_month": month.value,
			"is_bot": bot.button_pressed})
	var config: Dictionary = {
		"potion_limit_enabled": _limit_toggle.button_pressed,
		"potion_limit": _limit_step.value,
		"potion_mana": _potion_step.value,
		"include_curse_of_rules": _curse_toggle.button_pressed,
		"reaction_timeout_local_ms": TIMEOUTS_MS[_timer_step.value],
		"mode": "local",
	}
	return {"players": players, "config": config}


func _on_start() -> void:
	var setup: Dictionary = get_setup()
	start_requested.emit(setup)
	if auto_navigate:
		UiNav.start_local(get_tree(), setup)


func _on_back() -> void:
	back_requested.emit()
	if auto_navigate:
		UiNav.open_main_menu(get_tree())

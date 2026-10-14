class_name Lobby
extends Control
## Sala de espera (maqueta, sin red): código grande, miembros, "Empezar" solo para
## el anfitrión y formulario de perfil. Solo emite señales; la red la conecta otro.

signal start_requested
signal leave_requested
signal profile_changed(profile: Dictionary)

var auto_navigate: bool = true
var room_code: String = "ABCD"
var is_host: bool = true
## Miembros: [{id, name, age, birth_month, connected, is_host}]
var members: Array[Dictionary] = []

var _code_label: Label
var _members_box: VBoxContainer
var _start_btn: Button
var _wait_label: Label
var _name_edit: LineEdit
var _age: Stepper
var _month: Stepper


func _ready() -> void:
	theme = UiTheme.get_theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(UiUtil.make_background())
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 40)
	margin.add_theme_constant_override("margin_top", 60)
	margin.add_theme_constant_override("margin_bottom", 30)
	add_child(margin)
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 20)
	margin.add_child(col)
	col.add_child(UiUtil.label("Código de sala", 36, UiTheme.COL_MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	_code_label = UiUtil.label("", 140, UiTheme.COL_ACCENT, HORIZONTAL_ALIGNMENT_CENTER)
	col.add_child(_code_label)
	col.add_child(UiUtil.label("Magos en la sala", 36))
	_members_box = VBoxContainer.new()
	_members_box.add_theme_constant_override("separation", 10)
	col.add_child(_members_box)
	col.add_child(UiUtil.label("Tu perfil", 36))
	var prof: PanelContainer = PanelContainer.new()
	var pcol: VBoxContainer = VBoxContainer.new()
	prof.add_child(pcol)
	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = "Tu nombre"
	_name_edit.text = "Mago"
	_name_edit.custom_minimum_size = Vector2(0, 84)
	_name_edit.text_changed.connect(func(_t: String) -> void: _emit_profile())
	pcol.add_child(_name_edit)
	var grid: GridContainer = GridContainer.new()
	grid.columns = 2
	grid.add_child(UiUtil.label("Edad", 26, UiTheme.COL_MUTED))
	grid.add_child(UiUtil.label("Mes de nacimiento", 26, UiTheme.COL_MUTED))
	_age = Stepper.create(30, 1, 99)
	_age.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_age.value_changed.connect(func(_v: int) -> void: _emit_profile())
	grid.add_child(_age)
	var months: Array[String] = []
	for m: String in UiUtil.MONTHS:
		months.append(m.substr(0, 3))
	_month = Stepper.create(1, 1, 12, months)
	_month.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_month.value_changed.connect(func(_v: int) -> void: _emit_profile())
	grid.add_child(_month)
	pcol.add_child(grid)
	col.add_child(prof)
	col.add_child(UiUtil.spacer(0, true))
	_wait_label = UiUtil.label("Esperando a que el anfitrión empiece…", 30, UiTheme.COL_MUTED,
		HORIZONTAL_ALIGNMENT_CENTER)
	col.add_child(_wait_label)
	_start_btn = UiUtil.button("Empezar", 48, UiTheme.BUTTON_PRIMARY_H)
	UiTheme.apply_primary(_start_btn)
	_start_btn.pressed.connect(func() -> void: start_requested.emit())
	col.add_child(_start_btn)
	var leave: Button = UiUtil.button("Salir de la sala", 34, 110)
	leave.pressed.connect(_on_leave)
	col.add_child(leave)
	if not UiNav.pending_lobby.is_empty():
		room_code = String(UiNav.pending_lobby.get("code", room_code))
		is_host = String(UiNav.pending_lobby.get("role", "host")) == "host"
	if members.is_empty():
		members = _demo_members()
	refresh()


func _demo_members() -> Array[Dictionary]:
	var out: Array[Dictionary] = [
		{"id": "u1", "name": "Tú", "age": 30, "birth_month": 1, "connected": true, "is_host": is_host},
		{"id": "u2", "name": "Brisa", "age": 28, "birth_month": 5, "connected": true, "is_host": not is_host},
		{"id": "u3", "name": "Cael", "age": 41, "birth_month": 9, "connected": false, "is_host": false},
	]
	return out


func set_room_code(code: String) -> void:
	room_code = code
	refresh()


func set_host(v: bool) -> void:
	is_host = v
	refresh()


func set_members(list: Array[Dictionary]) -> void:
	members = list
	refresh()


func refresh() -> void:
	if _code_label == null:
		return
	_code_label.text = room_code
	UiUtil.clear_children(_members_box)
	for m: Dictionary in members:
		var row: PanelContainer = PanelContainer.new()
		var h: HBoxContainer = HBoxContainer.new()
		row.add_child(h)
		var nm: Label = UiUtil.label(String(m.get("name", "?")), 32)
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(nm)
		if bool(m.get("is_host", false)):
			h.add_child(UiUtil.label("Anfitrión", 24, UiTheme.COL_ACCENT))
		if not bool(m.get("connected", true)):
			h.add_child(UiUtil.label("Desconectado", 24, UiTheme.COL_DANGER))
		h.add_child(UiUtil.label("%d años · %s" % [int(m.get("age", 0)),
			UiUtil.MONTHS[clampi(int(m.get("birth_month", 1)) - 1, 0, 11)]], 24, UiTheme.COL_MUTED))
		_members_box.add_child(row)
	_start_btn.visible = is_host
	_start_btn.disabled = members.size() < 3
	_wait_label.visible = not is_host


func _emit_profile() -> void:
	profile_changed.emit({"name": _name_edit.text.strip_edges(), "age": _age.value,
		"birth_month": _month.value})


func _on_leave() -> void:
	leave_requested.emit()
	if auto_navigate:
		UiNav.open_main_menu(get_tree())

class_name MainMenu
extends Control
## Menú principal: Jugar local y Ajustes (el modo en línea llega en B1).

signal local_requested
signal create_room_requested
signal join_room_requested(code: String)
signal settings_requested
signal help_requested

## Si true los botones navegan solos con UiNav (poner a false en tests).
var auto_navigate: bool = true
var help_btn: Button
var _join_overlay: Control
var _join_dialog: PromptDialog


func _ready() -> void:
	theme = UiTheme.get_theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(UiUtil.make_background())
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 80)
	margin.add_theme_constant_override("margin_right", 80)
	margin.add_theme_constant_override("margin_top", 160)
	margin.add_theme_constant_override("margin_bottom", 100)
	add_child(margin)
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 28)
	margin.add_child(col)
	var title: Label = UiUtil.label("Not Enough Mana", 84, UiTheme.COL_ACCENT, HORIZONTAL_ALIGNMENT_CENTER)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(title)
	col.add_child(UiUtil.label("El duelo de magos donde el maná nunca alcanza", 28, UiTheme.COL_MUTED,
		HORIZONTAL_ALIGNMENT_CENTER))
	col.add_child(UiUtil.spacer(120))
	var play_local: Button = _menu_button("Jugar local", _on_local)
	UiTheme.apply_primary(play_local)
	col.add_child(play_local)
	# Crear sala / Unirse con código: ocultos hasta el modo en línea (B1).
	# Los manejadores y la maqueta de lobby.gd se conservan solo para tests.
	col.add_child(_menu_button("Ajustes", _on_settings))
	help_btn = UiUtil.button(StringsAyuda.SCREEN_TITLE, 36, UiTheme.BUTTON_MIN_H)
	help_btn.pressed.connect(_on_help)
	col.add_child(help_btn)
	col.add_child(UiUtil.spacer(0, true))
	col.add_child(UiUtil.label("Uso personal · © SUPERHOTEX", 22, UiTheme.COL_MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	_join_dialog = PromptDialog.new()
	_join_dialog.button_pressed.connect(_on_join_dialog)
	_join_overlay = Control.new()
	_join_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_join_overlay.visible = false
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_join_overlay.add_child(dim)
	var cc: CenterContainer = CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	_join_dialog.custom_minimum_size = Vector2(880, 0)
	cc.add_child(_join_dialog)
	_join_overlay.add_child(cc)
	add_child(_join_overlay)


func _menu_button(text: String, cb: Callable) -> Button:
	var b: Button = UiUtil.button(text, 44, UiTheme.BUTTON_MIN_H)
	b.pressed.connect(cb)
	return b


func _on_local() -> void:
	local_requested.emit()
	if auto_navigate:
		UiNav.go(get_tree(), UiNav.LOCAL_SETUP)


func _on_create() -> void:
	create_room_requested.emit()
	if auto_navigate:
		UiNav.pending_lobby = {"role": "host", "code": "ABCD"}
		UiNav.go(get_tree(), UiNav.LOBBY)


func _on_join() -> void:
	_join_dialog.open("Unirse a una sala", "Escribe el código de la sala.",
		[{"id": "join_ok", "text": "Unirse"}, {"id": "join_cancel", "text": "Cancelar"}],
		-1, true, "Código (4 letras)")
	_join_dialog.text_input.max_length = 8
	_join_overlay.visible = true


func _on_join_dialog(id: String) -> void:
	_join_overlay.visible = false
	if id != "join_ok":
		return
	var code: String = _join_dialog.text_input.text.strip_edges().to_upper()
	if code == "":
		return
	join_room_requested.emit(code)
	if auto_navigate:
		UiNav.pending_lobby = {"role": "guest", "code": code}
		UiNav.go(get_tree(), UiNav.LOBBY)


func _on_settings() -> void:
	settings_requested.emit()
	if auto_navigate:
		UiNav.go(get_tree(), UiNav.SETTINGS)


func _on_help() -> void:
	help_requested.emit()
	if auto_navigate:
		UiNav.go(get_tree(), UiNav.HELP)

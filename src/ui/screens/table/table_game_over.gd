class_name TableGameOver
extends TableModule
## Pantalla de fin de partida (V2-26c): resumen con GameOverSummary + "Jugar otra vez"
## (botón principal, solo si hay UiNav.replay_handler), "Ver la mesa" y "Volver al menú".
## "Ver resultado" (secundario) reabre el mismo resumen sobre la mesa terminada.
## El diálogo genérico no se usa; `ctx.dialogs.kind` vale "game_over" mientras el resumen está abierto.

const KIND: String = "game_over"

var overlay: Control
var summary_view: GameOverSummary
var play_again_button: Button
var see_table_button: Button
var menu_button: Button
var see_result_button: Button

var _shown: bool = false
var _summary: Dictionary = {}


func check() -> void:
	var view: Dictionary = ctx.view
	if String(view.get("status", "")) != Types.STATUS_FINISHED or _shown:
		return
	_shown = true
	ctx.reset_flow()
	ctx.sync.hide_pass_screen()
	ctx.prompts.hide_reaction()
	var local_ids: Array[String] = ctx.local_ids
	_summary = MatchSummary.build(view, local_ids)
	_ensure_ui()
	summary_view.show_summary(_summary)
	play_again_button.visible = UiNav.can_replay()
	show_result()


func is_shown() -> bool:
	return _shown


## Resumen construido (copia), para pruebas.
func summary() -> Dictionary:
	return _summary.duplicate(true)


## Muestra (o reabre) el resumen.
func show_result() -> void:
	if overlay == null:
		return
	ctx.dialogs.hide_overlay()
	ctx.dialogs.kind = KIND
	overlay.visible = true
	see_result_button.visible = false
	if summary_view.scroll != null:
		summary_view.scroll.scroll_vertical = 0


## Oculta el resumen y deja a la vista la mesa terminada con "Ver resultado".
func hide_result() -> void:
	if overlay == null:
		return
	overlay.visible = false
	see_result_button.visible = _shown
	if ctx.dialogs.kind == KIND:
		ctx.dialogs.kind = ""


func is_result_open() -> bool:
	return overlay != null and overlay.visible


func on_dialog_button(id: String) -> bool:
	if id != "play_again":
		return false
	ctx.screen.play_again_requested.emit()
	if ctx.screen.is_inside_tree() and UiNav.can_replay():
		UiNav.replay(ctx.screen.get_tree())
	return true


func _on_menu() -> void:
	if overlay != null:
		overlay.visible = false
	ctx.dialogs.on_button("menu_exit")


func _on_play_again() -> void:
	if overlay != null:
		overlay.visible = false
	ctx.dialogs.on_button("play_again")


func _ensure_ui() -> void:
	if overlay != null:
		return
	summary_view = GameOverSummary.new()
	summary_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var panel: PanelContainer = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiTheme.box(Color(0.07, 0.07, 0.11, 0.97), 24,
		Color(0.8, 0.65, 0.25, 0.9), 3, 24, 24))
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", UiTheme.BUTTON_GAP_MIN)
	panel.add_child(col)
	col.add_child(summary_view)
	play_again_button = UiUtil.button(Strings.BUTTON_PLAY_AGAIN, UiTheme.FONT_BUTTON, UiTheme.BUTTON_PRIMARY_H)
	UiTheme.apply_primary(play_again_button)
	play_again_button.pressed.connect(_on_play_again)
	col.add_child(play_again_button)
	see_table_button = UiUtil.button("Ver la mesa", UiTheme.FONT_BUTTON, UiTheme.BUTTON_MIN_H)
	see_table_button.pressed.connect(hide_result)
	col.add_child(see_table_button)
	menu_button = UiUtil.button(Strings.BUTTON_BACK_TO_MENU, UiTheme.FONT_BUTTON, UiTheme.BUTTON_MIN_H)
	menu_button.pressed.connect(_on_menu)
	col.add_child(menu_button)

	overlay = Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.z_index = 55
	overlay.visible = false
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.75)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(dim)
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	margin.add_child(panel)
	overlay.add_child(margin)

	see_result_button = UiUtil.button(Strings.BUTTON_SEE_RESULT, UiTheme.FONT_BUTTON, UiTheme.BUTTON_MIN_H)
	see_result_button.set_anchors_preset(Control.PRESET_CENTER_TOP)
	see_result_button.offset_top = 120
	see_result_button.grow_horizontal = Control.GROW_DIRECTION_BOTH
	see_result_button.z_index = 54
	see_result_button.visible = false
	see_result_button.pressed.connect(show_result)
	ctx.screen.add_child(see_result_button)
	ctx.screen.add_child(overlay)

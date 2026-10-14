class_name TableMenu
extends TableModule
## Barra superior (Menú, turno, "Rompió la regla"), menú de partida y denuncia
## de Curse of Rules.

var menu_btn: Button
var turn_label: Label
var rule_btn: Button
var help_overlay: HelpScreen


func build_top_bar() -> HBoxContainer:
	var top: HBoxContainer = HBoxContainer.new()
	top.add_theme_constant_override("separation", UiTheme.BUTTON_GAP_MIN)
	menu_btn = UiUtil.button("Menú", 28, UiTheme.BUTTON_MIN_H)
	menu_btn.custom_minimum_size = Vector2(170, UiTheme.BUTTON_MIN_H)
	menu_btn.pressed.connect(_on_menu)
	top.add_child(menu_btn)
	turn_label = UiUtil.label("", 32, UiTheme.COL_ACCENT, HORIZONTAL_ALIGNMENT_CENTER)
	turn_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	turn_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	turn_label.clip_text = true
	turn_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	top.add_child(turn_label)
	rule_btn = UiUtil.button("Rompió la regla", 26, UiTheme.BUTTON_MIN_H)
	rule_btn.custom_minimum_size = Vector2(300, UiTheme.BUTTON_MIN_H)
	rule_btn.pressed.connect(on_break_rule)
	top.add_child(rule_btn)
	return top


func refresh_turn_label() -> void:
	var names: Dictionary = ctx.names()
	var cur: String = String(ctx.turn_info().get("current", ""))
	if not ctx.playing():
		turn_label.text = "Fin de la partida"
	else:
		turn_label.text = "Tu turno" if cur == ctx.viewer_id else "Turno de %s" % String(names.get(cur, "?"))


func refresh_rule_button(me: Dictionary) -> void:
	rule_btn.visible = ctx.playing() and not ctx.find_curse_of_rules().is_empty() \
		and not bool(me.get("eliminated", false))


func _on_menu() -> void:
	ctx.dialogs.open("menu", "Partida", "¿Qué quieres hacer?", [
		{"id": "resume", "text": "Continuar"},
		{"id": "help", "text": StringsAyuda.SCREEN_TITLE},
		{"id": "concede", "text": "Abandonar la partida"},
		{"id": "menu_exit", "text": "Salir al menú"},
	])


## "Rompió la regla": en local cualquiera puede denunciar a cualquier mago vivo.
func on_break_rule() -> void:
	var curse: Dictionary = ctx.find_curse_of_rules()
	if curse.is_empty() or not ctx.playing():
		return
	var rule: String = String((curse.get("data", {}) as Dictionary).get("rule", ""))
	var title: String = "¿Quién rompió la regla?"
	if rule != "":
		title = "Regla: «%s». ¿Quién la rompió?" % rule
	ctx.reset_flow()
	ctx.flow_data = {"kind": "break_rule", "card": int(curse["iid"]), "need_targets": 1,
		"allowed": Types.alive_ids(ctx.view), "targets": [] as Array[String], "title": title}
	ctx.flow.advance()


func on_dialog_button(id: String) -> bool:
	match id:
		"resume":
			return false
		"help":
			open_help()
			return true
		"concede":
			ctx.emit_action(Types.make_action_concede(ctx.viewer_id))
			return true
		"menu_exit":
			if ctx.screen.is_inside_tree():
				UiNav.open_main_menu(ctx.screen.get_tree())
			return true
	return false


## Ayuda como superposición de la mesa: no cambia de escena, así que la partida
## (estado, temporizadores) sigue intacta al volver.
func open_help() -> void:
	if help_overlay != null:
		return
	help_overlay = HelpScreen.new()
	help_overlay.auto_navigate = false
	help_overlay.config = ctx.view.get("config", {}) as Dictionary
	help_overlay.z_index = 70
	help_overlay.back_pressed.connect(close_help)
	ctx.screen.add_child(help_overlay)


func close_help() -> void:
	if help_overlay != null:
		help_overlay.queue_free()
		help_overlay = null

class_name TableSync
extends TableModule
## Sesión y hot-seat: cambios de estado, decisor local, pantalla "Pasa el
## dispositivo", errores de la sesión y fin de partida desde la sesión.
## La cáscara (bind_session) guarda la sesión y conecta sus señales aquí.

var pass_screen: PassDeviceScreen

var _pending_viewer: String = ""


func build_pass_screen() -> PassDeviceScreen:
	pass_screen = PassDeviceScreen.new()
	pass_screen.visible = false
	pass_screen.z_index = 200
	pass_screen.confirmed.connect(on_pass_confirmed)
	return pass_screen


func hide_pass_screen() -> void:
	pass_screen.visible = false


## Tras enlazar la sesión: avisos del registro, decisor local (hot-seat) y vista.
func on_bound() -> void:
	var session: GameSession = ctx.session
	var v: Dictionary = session.get_view_for(ctx.viewer_id)
	ctx.notices.queue_event_notices(v.get("log", []) as Array)
	if ctx.local_ids.size() > 1:
		var d: String = Decision.local_decider(v, ctx.local_ids)
		if d != "":
			ctx.viewer_id = d
			v = session.get_view_for(ctx.viewer_id)
			ctx.screen.set_view(v, ctx.viewer_id)
			_pending_viewer = d
			_show_pass(v, d)
			return
	ctx.screen.set_view(v, ctx.viewer_id)


## Motivo de la pantalla: respuesta a un hechizo, decisión pendiente o turno.
static func pass_reason(v: Dictionary, pid: String) -> String:
	if not (v.get("reaction", {}) as Dictionary).is_empty() and Decision.responder(v) == pid:
		return Strings.PASS_REASON_REACTION
	for pr: Variant in v.get("pending", []) as Array:
		if String((pr as Dictionary).get("player", "")) == pid:
			return Strings.PASS_REASON_DECISION
	return Strings.PASS_REASON_TURN


func _show_pass(v: Dictionary, pid: String) -> void:
	pass_screen.show_for(TableContext.name_of(v, pid), pass_reason(v, pid))


func on_state_changed(_rev: int, events: Array) -> void:
	var session: GameSession = ctx.session
	if session == null:
		return
	ctx.notices.queue_event_notices(events)
	var v: Dictionary = session.get_view_for(ctx.viewer_id)
	if String(v.get("status", "")) != Types.STATUS_PLAYING:
		pass_screen.visible = false
		_pending_viewer = ""
		ctx.screen.set_view(v, ctx.viewer_id)
		return
	if ctx.local_ids.size() > 1:
		var d: String = Decision.local_decider(v, ctx.local_ids)
		if pass_screen.visible:
			if d != "":
				_pending_viewer = d
				_show_pass(v, d)
			return
		if d != "" and d != ctx.viewer_id:
			ctx.reset_flow()
			_pending_viewer = d
			_show_pass(v, d)
			return
	ctx.screen.set_view(v, ctx.viewer_id)


func on_pass_confirmed() -> void:
	var session: GameSession = ctx.session
	if session == null:
		return
	var v: Dictionary = session.get_view_for(ctx.viewer_id)
	var d: String = Decision.local_decider(v, ctx.local_ids)
	var target: String = d if d != "" else _pending_viewer
	_pending_viewer = ""
	if target != "":
		ctx.viewer_id = target
	ctx.reset_flow()
	ctx.shown_prompt_id = -1
	ctx.dialogs.hide_overlay()
	ctx.screen.set_view(session.get_view_for(ctx.viewer_id), ctx.viewer_id)


func on_session_error(code: String, _action: Dictionary) -> void:
	ctx.toast(UiUtil.error_text(code))
	ctx.reset_flow()
	ctx.shown_prompt_id = -1
	if not ctx.view.is_empty():
		ctx.refresh()


func on_game_over(_winners: Array) -> void:
	if ctx.session != null:
		ctx.screen.set_view(ctx.session.get_view_for(ctx.viewer_id), ctx.viewer_id)

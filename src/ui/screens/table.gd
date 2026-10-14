class_name TableScreen
extends Control
## Mesa vertical. Solo recibe vistas (Types.view_for / compose_view) y emite
## acciones (Types.make_action_*) hacia un GameSession: sirve igual para
## LocalSession y OnlineSession.
##
## Uso: bind_session(session) o, para maquetas/tests, set_view(view, viewer_id).
##
## Todo lo que se puede pulsar sale de las acciones legales del jugador que mira
## (ActionOptions sobre la vista): lo ilegal queda deshabilitado. Las jugadas se
## construyen con PlayFlow (objetivos -> carta objetivo -> opción -> pago, con el
## Scroll of Elements como comodín). En hot-seat, cuando debe decidir otro
## humano (turno, reacción o prompt) se muestra PassDeviceScreen antes de
## enseñar su mano.
##
## Esta es la cáscara: señales, API pública, composición de la UI, orden de
## refresh() y servicios (acción, aviso, zoom). La lógica vive en los módulos
## de src/ui/screens/table/ (ver docs/TECNICO/division-table.md), que comparten
## estado a través de `ctx` (TableContext).

signal action_requested(action: Dictionary)
signal play_again_requested

const Step = TableContext.Step

## Si true y no hay sesión ni vista al arrancar, muestra una partida de demostración.
var demo_when_empty: bool = true

var session: GameSession:
	get: return _ctx.session
	set(value): _ctx.session = value
var viewer_id: String:
	get: return _ctx.viewer_id
	set(value): _ctx.viewer_id = value
var view: Dictionary:
	get: return _ctx.view
	set(value): _ctx.view = value
## Contexto compartido con los módulos (para tests nuevos: t.ctx.hand, t.ctx.mode_bar...).
var ctx: TableContext:
	get: return _ctx

## Número de refresh() completos (tests: ningún feedback debe disparar uno).
var refresh_count: int = 0
## Perfilado opcional de refresh() por paso (ms acumulados; ver tests/perf).
var profile_refresh: bool = false
var refresh_profile: Dictionary = {}

var _ctx: TableContext
var _log: ActionLog
var _log_sig: String = ""
var _toast: Label
var _zoom: CardZoom
var _feedback: TableFeedback


func _init() -> void:
	_ctx = TableContext.new()
	_ctx.screen = self
	_ctx.sync = TableSync.new()
	_ctx.menu = TableMenu.new()
	_ctx.players = TablePlayers.new()
	_ctx.center = TableCenter.new()
	_ctx.hand = TableHand.new()
	_ctx.actions = TableActions.new()
	_ctx.flow = TableFlow.new()
	_ctx.mode_bar = TableModeBar.new()
	_ctx.dialogs = TableDialogs.new()
	_ctx.prompts = TablePrompts.new()
	_ctx.notices = TableNotices.new()
	_ctx.game_over = TableGameOver.new()
	_feedback = TableFeedback.new()
	for m: TableModule in [_ctx.sync, _ctx.menu, _ctx.players, _ctx.center, _ctx.hand, _ctx.actions,
			_ctx.flow, _ctx.mode_bar, _ctx.dialogs, _ctx.prompts, _ctx.notices, _ctx.game_over, _feedback]:
		m.setup(_ctx)
		_ctx.modules.append(m)


func _notification(what: int) -> void:
	# Si la mesa se libera sin haber construido la UI, los módulos no son hijos suyos.
	if what == NOTIFICATION_PREDELETE and _ctx != null:
		for m: TableModule in _ctx.modules:
			if is_instance_valid(m) and m.get_parent() == null:
				m.free()


func _ready() -> void:
	_build_ui()
	if UiNav.pending_session != null:
		bind_session(UiNav.pending_session)
		UiNav.pending_session = null
	elif demo_when_empty and view.is_empty():
		FakeState.install_defs()
		var fs: FakeSession = FakeSession.create(FakeState.make_state(4), ["p1"] as Array[String])
		bind_session(fs)


# ---------------------------------------------------------------- construcción

## Orden de los widgets fijo (docs/TECNICO/division-table.md §4.1).
func _build_ui() -> void:
	theme = UiTheme.get_theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(UiUtil.make_background())
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 14)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	add_child(margin)
	var root: VBoxContainer = VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	margin.add_child(root)

	root.add_child(_ctx.menu.build_top_bar())
	_log = ActionLog.new()
	_log.toggled.connect(_on_log_toggled)
	root.add_child(_log)
	root.add_child(_ctx.players.build_rival_fan())
	root.add_child(_ctx.center.build())
	root.add_child(_ctx.players.build_own_panel())
	root.add_child(_ctx.hand.build_hint())
	root.add_child(_ctx.actions.build_action_row())
	root.add_child(_ctx.mode_bar.build())
	root.add_child(_ctx.actions.build_drink_button())
	root.add_child(_ctx.hand.build_hand())

	# Feedback (números, destellos, aviso de carta): encima de los paneles y
	# debajo de las superposiciones modales (bus-presentacion.md §4.5).
	add_child(_feedback.build_layer())

	# Superposiciones
	add_child(_ctx.prompts.build_overlay())
	add_child(_ctx.dialogs.build_overlay())
	add_child(_ctx.notices.build_overlay())
	_toast = UiUtil.label("", 30, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	_toast.add_theme_stylebox_override("normal", UiTheme.box(Color(0.5, 0.12, 0.12, 0.96), 18))
	_toast.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_toast.visible = false
	_toast.z_index = 60
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_toast)
	_zoom = CardZoom.new()
	add_child(_zoom)
	add_child(_ctx.sync.build_pass_screen())
	for m: TableModule in _ctx.modules:
		add_child(m)


# ---------------------------------------------------------------- sesión

func bind_session(p_session: GameSession) -> void:
	session = p_session
	if session.get_parent() == null:
		add_child(session)
	_ctx.local_ids = session.get_local_player_ids()
	if viewer_id == "" and not _ctx.local_ids.is_empty():
		viewer_id = _ctx.local_ids[0]
	var sync: TableSync = _ctx.sync
	if not session.state_changed.is_connected(sync.on_state_changed):
		session.state_changed.connect(sync.on_state_changed)
		session.error.connect(sync.on_session_error)
		session.game_over.connect(sync.on_game_over)
	# Después de TableSync: el feedback se dibuja sobre la vista ya refrescada.
	_feedback.bind(session)
	sync.on_bound()


# ---------------------------------------------------------------- vista

## Aplica una vista. viewer = quien mira (si "" se conserva el actual).
func set_view(v: Dictionary, p_viewer: String = "") -> void:
	view = v
	if p_viewer != "":
		viewer_id = p_viewer
	_ctx.opts = ActionOptions.build(view, viewer_id)
	if not is_node_ready():
		await ready
	refresh()


## Acciones legales del jugador que mira (sobre la vista actual).
func options() -> ActionOptions:
	return _ctx.opts


## Redibuja la mesa. Orden fijo (docs/TECNICO/division-table.md §4.2).
## Paneles, centro y registro se actualizan en sitio si no cambiaron (§5 del bus).
func refresh() -> void:
	if view.is_empty():
		return
	refresh_count += 1
	var c: TableContext = _ctx
	var t: int = Time.get_ticks_usec() if profile_refresh else 0
	var me: Dictionary = c.me()
	c.menu.refresh_turn_label()
	t = _lap("menu", t)
	_refresh_log()
	t = _lap("log", t)
	c.menu.refresh_rule_button(me)
	t = _lap("menu", t)
	c.players.rebuild_rivals()
	t = _lap("players", t)
	c.center.rebuild()
	t = _lap("center", t)
	c.players.refresh_own(me)
	t = _lap("players", t)
	c.actions.refresh_buttons(me)
	t = _lap("actions", t)
	c.hand.refresh_hand(me)
	c.hand.refresh_hint(me)
	t = _lap("hand", t)
	c.notices.check_reveals()
	c.prompts.update_overlays()
	c.notices.show_next()
	c.game_over.check()
	_lap("notices_prompts_game_over", t)


## Registro plegado: solo recibe las STRIP_LINES entradas de la franja (no rehace
## ~50 RichTextLabel ocultos); desplegado, el log entero. Sin cambios, no se toca.
func _refresh_log() -> void:
	var entries: Array = view.get("log", []) as Array
	var names: Dictionary = _ctx.names()
	var last: Dictionary = entries[entries.size() - 1] as Dictionary if not entries.is_empty() else {}
	var sig: String = "%s|%s|%d|%d|%s|%s" % [_log.expanded, viewer_id, entries.size(),
		int(last.get("log_seq", 0)), str(last), str(names)]
	if sig == _log_sig:
		return
	_log_sig = sig
	if not _log.expanded and entries.size() > ActionLog.STRIP_LINES:
		entries = entries.slice(entries.size() - ActionLog.STRIP_LINES)
	_log.set_entries(entries, names)


func _on_log_toggled(_expanded: bool) -> void:
	if not view.is_empty():
		_refresh_log()


func _lap(step: String, t0: int) -> int:
	if not profile_refresh:
		return 0
	var now: int = Time.get_ticks_usec()
	refresh_profile[step] = float(refresh_profile.get(step, 0.0)) + float(now - t0) / 1000.0
	return now


## Panel del mago `pid` (propio o rival) o null; ancla de FeedbackLayer.
func panel_for(pid: String) -> Control:
	return _ctx.players.panel_for(pid)


## Módulo de feedback (bus + capa); para tests y capturas.
func feedback() -> TableFeedback:
	return _feedback


# ---------------------------------------------------------------- servicios

## Envía una acción: cierra la jugada y el diálogo, emite action_requested y la
## manda a la sesión (sin sesión, solo redibuja).
func emit_action(a: Dictionary) -> void:
	_ctx.reset_flow()
	_ctx.dialogs.close()
	action_requested.emit(a)
	if session != null:
		session.submit_action(a)
	elif not view.is_empty():
		refresh()


func show_toast(text: String) -> void:
	_toast.text = " %s " % text
	_toast.visible = true
	_toast.custom_minimum_size = Vector2(minf(size.x - 80.0, 900.0), 0)
	_toast.reset_size()
	_toast.position = Vector2(size.x * 0.5 - _toast.size.x * 0.5, size.y - 600.0)
	var tw: Tween = create_tween()
	tw.tween_interval(2.4)
	tw.tween_callback(func() -> void: _toast.visible = false)


func show_zoom(card: Dictionary, def: Dictionary) -> void:
	_zoom.show_card(card, def)


## Inicia la jugada de una carta (o respuesta); ver TableFlow.begin_play.
func begin_play(iid: int, as_react: bool) -> void:
	_ctx.flow.begin_play(iid, as_react)


## Avisos pendientes (para tests).
func pending_notices() -> int:
	return _ctx.notices.pending()


func is_game_over_shown() -> bool:
	return _ctx.game_over.is_shown()


# ---------------------------------------------------------------- Compatibilidad: tests y capturas
# Miembros privados que usan tests/ y los scripts de captura. Congelado: los
# tests nuevos usan `ctx` y los módulos. Reenvían al objeto real.

var _step: TableContext.Step:
	get: return _ctx.step
var _selected: Array[int]:
	get: return _ctx.selected
var _pay_table: Array[int]:
	get: return _ctx.pay_table
var _pflow: PlayFlow:
	get: return _ctx.pflow
var _dialog: PromptDialog:
	get: return _ctx.dialogs.dialog
var _dialog_kind: String:
	get: return _ctx.dialogs.kind
var _dialog_overlay: Control:
	get: return _ctx.dialogs.dialog_overlay
var _reaction: ReactionPrompt:
	get: return _ctx.prompts.reaction
var _reaction_overlay: Control:
	get: return _ctx.prompts.reaction_overlay
var _notice_overlay: Control:
	get: return _ctx.notices.notice_overlay
var _pass_screen: PassDeviceScreen:
	get: return _ctx.sync.pass_screen
var _hint: Label:
	get: return _ctx.hand.hint
var _play_btn: Button:
	get: return _ctx.actions.play_btn
var _exchange_btn: Button:
	get: return _ctx.actions.exchange_btn
var _discard_btn: Button:
	get: return _ctx.actions.discard_btn
var _end_btn: Button:
	get: return _ctx.actions.end_btn
var _drink_btn: Button:
	get: return _ctx.actions.drink_btn
var _mode_confirm: Button:
	get: return _ctx.mode_bar.mode_confirm
var _mode_label: Label:
	get: return _ctx.mode_bar.mode_label
var _rule_btn: Button:
	get: return _ctx.menu.rule_btn
var _hand: HandView:
	get: return _ctx.hand.hand_view
var _rival_fan: Control:
	get: return _ctx.players.rival_fan
var _rival_panels: Array[PlayerPanel]:
	get: return _ctx.players.rival_panels


func _me() -> Dictionary:
	return _ctx.me()


func _allowed() -> Array[String]:
	return _ctx.allowed()


func _flow_targets() -> Array[String]:
	return _ctx.flow_targets()


func _reset_flow() -> void:
	_ctx.reset_flow()


func _on_hand_tapped(card: Dictionary) -> void:
	_ctx.hand.on_hand_tapped(card)


func _on_panel_tapped(pid: String) -> void:
	_ctx.flow.on_panel_tapped(pid)


func _on_dialog_button(id: String) -> void:
	_ctx.dialogs.on_button(id)


func _on_break_rule() -> void:
	_ctx.menu.on_break_rule()


func _on_mode_extra() -> void:
	_ctx.mode_bar.on_mode_extra()


func _on_own_card(card: Dictionary, def: Dictionary) -> void:
	_ctx.flow.on_own_card(card, def)


func _on_notice_ok() -> void:
	_ctx.notices.on_notice_ok()


func _show_zoom(card: Dictionary, def: Dictionary) -> void:
	show_zoom(card, def)

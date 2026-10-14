class_name TableFeedback
extends TableModule
## Feedback de la mesa (ítem 1, V2-22; docs/TECNICO/bus-presentacion.md §4.5-§6):
## crea el PresentationBus y la FeedbackLayer y los engancha a la mesa.
##  * La cáscara llama a bind(session) DESPUÉS de conectar TableSync.on_state_changed,
##    así el feedback se dibuja sobre la vista ya refrescada (además nada arranca
##    hasta el _process del bus).
##  * El bus queda bloqueado mientras se ve "Pasa el dispositivo" (visibilidad de
##    la pantalla de paso: TableSync la muestra y la oculta antes de set_view).
##  * La capa nunca llama a refresh(): solo lee la posición de los paneles.

var bus: PresentationBus
var layer: FeedbackLayer


func build_layer() -> FeedbackLayer:
	layer = FeedbackLayer.new()
	layer.anchor_provider = ctx.players.panel_for
	layer.names_provider = ctx.names
	bus = PresentationBus.new()
	bus.name = "PresentationBus"
	bus.feedback_started.connect(layer.play)
	add_child(bus)
	return layer


## Enlaza el bus a la sesión (base = log actual: no repite la historia).
func bind(session: GameSession) -> void:
	if bus == null:
		return
	var baseline: Dictionary = session.get_view_for(ctx.viewer_id)
	bus.bind(session, _viewer, baseline)
	var ps: PassDeviceScreen = ctx.sync.pass_screen
	if ps != null:
		if not ps.visibility_changed.is_connected(_sync_blocked):
			ps.visibility_changed.connect(_sync_blocked)
		_sync_blocked()


func _viewer() -> String:
	return ctx.viewer_id


func _sync_blocked() -> void:
	var ps: PassDeviceScreen = ctx.sync.pass_screen
	bus.set_blocked(ps != null and ps.visible)

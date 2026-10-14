class_name TablePlayers
extends TableModule
## Paneles de jugador: rejilla de rivales (mesa-5-6-jugadores.md §3) y panel propio.

const Step = TableContext.Step
## Separación entre paneles de rival, ancho máximo en una fila, margen superior y arco (px a 1080).
const GAP: float = 12.0
const ROW_PANEL_W: float = 341.0
const TOP_PAD: float = 4.0
const ARC_PX: float = 14.0

var rival_fan: Control
var rival_panels: Array[PlayerPanel] = []
var own_panel: PlayerPanel
## Reconstrucciones del abanico (para tests: el refresco normal no reconstruye).
var rebuild_count: int = 0

## pid -> PlayerPanel rival; clave "<pid1>,<pid2>,…" del abanico actual.
var _by_pid: Dictionary = {}
var _rival_key: String = ""
var _relayout_queued: bool = false


func build_rival_fan() -> Control:
	rival_fan = Control.new()
	rival_fan.custom_minimum_size = Vector2(0, 260)
	rival_fan.resized.connect(_layout_rivals)
	return rival_fan


func build_own_panel() -> PlayerPanel:
	own_panel = PlayerPanel.create(true)
	own_panel.tapped.connect(ctx.flow.on_panel_tapped)
	own_panel.card_zoom_requested.connect(ctx.flow.on_own_card)
	return own_panel


func refresh_own(me: Dictionary) -> void:
	var cur: String = String(ctx.turn_info().get("current", ""))
	own_panel.update_player(me, cur == ctx.viewer_id,
		ctx.step == Step.TARGETS and ctx.allowed().has(ctx.viewer_id), ctx.flow_targets().has(ctx.viewer_id))


func _rival_list() -> Array[Dictionary]:
	var players: Array = ctx.view.get("players", []) as Array
	var idx: int = Types.player_index(ctx.view, ctx.viewer_id)
	var out: Array[Dictionary] = []
	var n: int = players.size()
	for k: int in range(1, n):
		var p: Dictionary = players[((maxi(idx, 0)) + k) % n]
		out.append(p)
	return out


## Panel del mago `pid`: el propio si es quien mira, si no el rival; null si no existe.
func panel_for(pid: String) -> Control:
	if pid == "":
		return null
	if pid == ctx.viewer_id:
		return own_panel
	var pp: PlayerPanel = _by_pid.get(pid, null) as PlayerPanel
	if pp != null and is_instance_valid(pp):
		return pp
	return null


## Refresco incremental (bus-presentacion.md §5): si no cambian los rivales ni su
## orden, actualiza los paneles en sitio; si cambian, los reconstruye. Un cambio
## de ancho no reconstruye: _layout_rivals ajusta el ancho de los paneles.
func rebuild_rivals() -> void:
	var cur: String = String(ctx.turn_info().get("current", ""))
	var rivals: Array[Dictionary] = _rival_list()
	var w: float = _rival_width(rivals.size())
	var ids: PackedStringArray = PackedStringArray()
	for p: Dictionary in rivals:
		ids.append(String(p["id"]))
	var key: String = ",".join(ids)
	if key == _rival_key and rival_panels.size() == rivals.size():
		var changed: bool = false
		for i: int in rivals.size():
			changed = _update_rival(rival_panels[i], rivals[i], cur) or changed
		if changed and not _relayout_queued:
			_relayout_queued = true
			_relayout_if_needed.call_deferred()
		return
	_rival_key = key
	rebuild_count += 1
	for pp: PlayerPanel in rival_panels:
		rival_fan.remove_child(pp)
		pp.queue_free()
	rival_panels.clear()
	_by_pid.clear()
	var stat_rows: int = grid_for(rivals.size())[2]
	for p: Dictionary in rivals:
		var pp: PlayerPanel = PlayerPanel.create(false, w, stat_rows)
		_update_rival(pp, p, cur)
		pp.tapped.connect(ctx.flow.on_panel_tapped)
		pp.card_zoom_requested.connect(ctx.zoom)
		rival_fan.add_child(pp)
		rival_panels.append(pp)
		_by_pid[String(p["id"])] = pp
	_layout_rivals.call_deferred()


## true si el panel se redibujó.
func _update_rival(pp: PlayerPanel, p: Dictionary, cur: String) -> bool:
	var pid: String = String(p["id"])
	return pp.update_player(p, pid == cur, ctx.step == Step.TARGETS and ctx.allowed().has(pid),
		ctx.flow_targets().has(pid))


## Tras redibujar un panel en sitio: recoloca el abanico solo si cambió su alto.
func _relayout_if_needed() -> void:
	_relayout_queued = false
	for pp: PlayerPanel in rival_panels:
		if is_instance_valid(pp) and absf(pp.get_combined_minimum_size().y - pp.size.y) > 0.5:
			_layout_rivals()
			return


## Rejilla de rivales (mesa-5-6-jugadores.md §3): 1-3 rivales en una fila,
## 4 en 2x2 (estadísticas en una fila) y 5 en 3x2 (la 6a celda queda libre).
## Devuelve [columnas, filas, filas de estadísticas del panel].
static func grid_for(n: int) -> Array[int]:
	if n >= 5:
		return [3, 2, 2] as Array[int]
	if n == 4:
		return [2, 2, 1] as Array[int]
	return [maxi(n, 1), 1, 2] as Array[int]


func _rival_width(n: int) -> float:
	var cols: int = grid_for(n)[0]
	var avail: float = maxf(rival_fan.size.x if rival_fan != null else 1052.0, 400.0)
	var w: float = (avail - GAP * float(cols - 1)) / float(cols)
	# En una fila (3-4 jugadores) el panel no pasa de 341 (mesa-5-6-jugadores.md §3).
	if grid_for(n)[1] == 1:
		w = minf(w, ROW_PANEL_W)
	return floorf(w)


## Rejilla sin giro (>= 5 jugadores) y fila con un arco suave (3-4). La altura
## de la zona se ajusta a los paneles (sin hueco vacío debajo).
func _layout_rivals() -> void:
	var n: int = rival_panels.size()
	if n == 0:
		return
	var g: Array[int] = grid_for(n)
	var cols: int = g[0]
	var rows: int = g[1]
	var w: float = _rival_width(n)
	var avail: float = rival_fan.size.x
	var row_h: float = 0.0
	for pp: PlayerPanel in rival_panels:
		pp.set_layout(w, g[2])
		row_h = maxf(row_h, pp.get_combined_minimum_size().y)
	var bottom: float = 0.0
	for i: int in n:
		var pp: PlayerPanel = rival_panels[i]
		var r: int = floori(float(i) / float(cols))
		var c: int = i % cols
		var in_row: int = mini(cols, n - r * cols) if rows == 1 else cols
		var row_w: float = w * float(in_row) + GAP * float(in_row - 1)
		var x0: float = (avail - row_w) * 0.5
		var y: float = TOP_PAD + (row_h + GAP) * float(r)
		if rows == 1 and in_row > 1:
			var t: float = (float(c) - float(in_row - 1) * 0.5) / (float(in_row - 1) * 0.5)
			y += ARC_PX * t * t
		pp.rotation = 0.0
		pp.size = Vector2(w, row_h)
		pp.pivot_offset = pp.size * 0.5
		pp.position = Vector2(x0 + (w + GAP) * float(c), y)
		bottom = maxf(bottom, y + row_h + 4.0)
	var want: float = clampf(bottom, 160.0, 640.0)
	if absf(rival_fan.custom_minimum_size.y - want) > 2.0:
		rival_fan.custom_minimum_size = Vector2(0, want)

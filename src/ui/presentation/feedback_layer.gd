class_name FeedbackLayer
extends Control
## Capa visual del feedback (bus-presentacion.md §4.5). Rect completo encima de
## los paneles y debajo de las superposiciones modales; no captura toques.
## Recibe FeedbackItem (PresentationBus.feedback_started -> play) y dibuja:
##  * número flotante sobre el panel del mago (FloatingText: "▼ -2", "▲ +1",
##    "▲ +3 maná", "Bloqueado", "Eliminado");
##  * destello: ColorRect con el material del tema encima del rect del panel
##    (no `modulate` del panel, que PlayerPanel._style() sobrescribe);
##  * aviso de carta jugada arriba en el centro: "Bruno → Fireball → Ana".
## No conoce la sesión ni el estado: solo items, un ancla por pid y los nombres.
## Al no vivir dentro de los paneles, sobrevive a cualquier refresh de la mesa.

## Máximo de nodos reutilizables por tipo (números y destellos).
const POOL_MAX: int = 12
## Desfase vertical entre números simultáneos de un mismo panel (se apilan hacia arriba).
const STACK_PX: float = 58.0
## Los números nacen por encima del borde superior del panel (no tapan vida, maná
## ni pociones; QA-V2-27-01): centro a esta distancia sobre el borde.
const ABOVE_PX: float = 34.0
## Mitad del alto de un número flotante y margen con el registro (QA-V2-35-05).
const FLOAT_HALF_H: float = 30.0
const LOG_CLEAR_PX: float = 6.0
const BANNER_FONT: int = 34
## Alto relativo del aviso (por encima del centro de la mesa).
const BANNER_Y: float = 0.27
const TEXT_BLOCKED: String = "Bloqueado"
const TEXT_ELIMINATED: String = "Eliminado"
const TEXT_MANA: String = "maná"
const ARROW: String = " → "

## func(pid: String) -> Control (panel del mago o null).
var anchor_provider: Callable = Callable()
## func() -> Dictionary (pid -> nombre).
var names_provider: Callable = Callable()

## Items dibujados por tipo, y log_seq dibujados (últimos HISTORY_MAX), para tests.
var played: Dictionary = {}
var played_seqs: Array[int] = []
## Items sin ancla (panel inexistente): no se dibujan.
var no_anchor: int = 0

const HISTORY_MAX: int = 400

var _floats_free: Array[FloatingText] = []
var _flashes_free: Array[ColorRect] = []
var _active_floats: Dictionary = {}   # FloatingText -> pid
var _active_flashes: int = 0
var _banner: PanelContainer = null
var _banner_label: Label = null
var _banner_tween: Tween = null
var _log_ref: Control = null


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Dibuja un FeedbackItem (ver FeedbackMapper).
func play(item: Dictionary) -> void:
	var kind: String = String(item.get("kind", ""))
	var dur: int = maxi(int(item.get("duration_ms", FeedbackMapper.DUR_PANEL_MS)),
		FeedbackMapper.MIN_DURATION_MS)
	played[kind] = int(played.get(kind, 0)) + 1
	played_seqs.append(int(item.get("log_seq", 0)))
	if played_seqs.size() > HISTORY_MAX:
		played_seqs.remove_at(0)
	if kind == FeedbackMapper.FB_CARD_PLAYED:
		_show_banner(item, dur)
		var cost: int = int(item.get("amount", 0))
		var caster: String = String((item.get("extra", {}) as Dictionary).get("caster", item.get("actor", "")))
		if cost < 0:
			_float_on(caster, "%s %d %s" % [UiTheme.GLYPH_DAMAGE, cost, TEXT_MANA], true, dur, _mana_color())
		return
	var pid: String = String(item.get("target", ""))
	var amount: int = int(item.get("amount", 0))
	var extra: Dictionary = item.get("extra", {}) as Dictionary
	match kind:
		FeedbackMapper.FB_DAMAGE:
			var txt: String = UiTheme.float_text(amount, true)
			if amount == 0 and int(extra.get("prevented", 0)) > 0:
				txt = TEXT_BLOCKED
			if _float_on(pid, txt, true, dur):
				_flash_on(pid, true, dur)
		FeedbackMapper.FB_HEAL:
			if _float_on(pid, UiTheme.float_text(amount, false), false, dur):
				_flash_on(pid, false, dur)
		FeedbackMapper.FB_MANA:
			_float_on(pid, _mana_text(amount), amount < 0, dur, _mana_color())
		FeedbackMapper.FB_POTION:
			if _float_on(pid, _mana_text(amount), false, dur, _mana_color()):
				_flash_on(pid, false, dur)
		FeedbackMapper.FB_ELIMINATED:
			if _float_on(pid, TEXT_ELIMINATED, true, dur):
				_flash_on(pid, true, dur)
		_:
			pass


## Números y destellos en curso.
func active_count() -> int:
	return _active_floats.size() + _active_flashes + (1 if is_banner_visible() else 0)


func is_banner_visible() -> bool:
	return _banner != null and _banner.visible


func banner_text() -> String:
	return _banner_label.text if _banner_label != null else ""


## Textos de los números visibles (tests y capturas).
func visible_texts() -> Array[String]:
	var out: Array[String] = []
	for ft: Variant in _active_floats.keys():
		out.append((ft as FloatingText).text)
	return out


static func _mana_text(amount: int) -> String:
	var glyph: String = UiTheme.GLYPH_DAMAGE if amount < 0 else UiTheme.GLYPH_HEAL
	return "%s %s%d %s" % [glyph, "-" if amount < 0 else "+", absi(amount), TEXT_MANA]


static func _mana_color() -> Color:
	return UiTheme.COL_MANA.lightened(0.35)


func _anchor(pid: String) -> Control:
	if pid == "" or not anchor_provider.is_valid():
		return null
	var c: Control = anchor_provider.call(pid) as Control
	if c == null or not is_instance_valid(c) or not c.is_visible_in_tree():
		return null
	return c


## Transformación del panel en coordenadas de esta capa (incluye el giro del abanico).
func _xf(anchor: Control) -> Transform2D:
	return get_global_transform().affine_inverse() * anchor.get_global_transform()


func _float_on(pid: String, txt: String, damage: bool, dur: int, tint: Color = Color(0, 0, 0, 0)) -> bool:
	var anchor: Control = _anchor(pid)
	if anchor == null:
		no_anchor += 1
		return false
	var stack: int = 0
	for v: Variant in _active_floats.values():
		if String(v) == pid:
			stack += 1
	# Encima del borde superior del panel; los simultáneos, escalonados hacia arriba
	# (y alternando a izquierda y derecha) para no taparse entre sí.
	var center: Vector2 = _xf(anchor) * Vector2(anchor.size.x * 0.5, 0.0)
	center.y -= ABOVE_PX + STACK_PX * float(stack % 3)
	if stack % 2 == 1:
		center.x += anchor.size.x * 0.18
	elif stack > 0:
		center.x -= anchor.size.x * 0.18
	# Si al subir taparía la franja del registro (rivales de la fila superior), nace en la
	# parte baja del panel, que está vacía (QA-V2-35-05).
	var log_bottom: float = _log_bottom()
	var reach: float = center.y - FLOAT_HALF_H - FloatingText.RISE_PX
	if log_bottom > -INF and reach < log_bottom + LOG_CLEAR_PX:
		var low: Vector2 = _xf(anchor) * Vector2(anchor.size.x * 0.5, anchor.size.y)
		center.y = low.y - FLOAT_HALF_H - 4.0 - STACK_PX * float(stack % 2)
	var ft: FloatingText = _floats_free.pop_back() if not _floats_free.is_empty() else null
	if ft == null:
		ft = FloatingText.create()
		ft.done.connect(_on_float_done)
		add_child(ft)
	move_child(ft, -1)
	_active_floats[ft] = pid
	ft.play(txt, damage, center, dur, tint)
	return true


## Borde inferior (en coordenadas de la capa) del registro de la mesa; -INF si no hay.
func _log_bottom() -> float:
	if _log_ref == null or not is_instance_valid(_log_ref):
		_log_ref = null
		var par: Node = get_parent()
		if par != null:
			var found: Array[Node] = par.find_children("*", "ActionLog", true, false)
			if not found.is_empty():
				_log_ref = found[0] as Control
	if _log_ref == null or not _log_ref.is_visible_in_tree():
		return -INF
	return (get_global_transform().affine_inverse() * _log_ref.get_global_rect().end).y


func _on_float_done(ft: FloatingText) -> void:
	_active_floats.erase(ft)
	if _floats_free.size() < POOL_MAX:
		_floats_free.append(ft)
	else:
		ft.queue_free()


func _flash_on(pid: String, damage: bool, dur: int) -> void:
	var anchor: Control = _anchor(pid)
	if anchor == null:
		return
	var xf: Transform2D = _xf(anchor)
	var r: ColorRect = _flashes_free.pop_back() if not _flashes_free.is_empty() else null
	if r == null:
		r = ColorRect.new()
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		r.color = Color.WHITE
		r.material = UiTheme.make_flash_material(damage, anchor.size)
		add_child(r)
	var m: ShaderMaterial = r.material as ShaderMaterial
	m.set_shader_parameter("tint", UiTheme.COL_DAMAGE_FX if damage else UiTheme.COL_HEAL_FX)
	m.set_shader_parameter("hatched", damage)
	m.set_shader_parameter("rect_size", anchor.size)
	m.set_shader_parameter("amount", 0.0)
	r.position = xf.origin
	r.rotation = xf.get_rotation()
	r.size = anchor.size
	r.visible = true
	# Los destellos van debajo de los números.
	move_child(r, 0)
	_active_flashes += 1
	var secs: float = float(dur) / 1000.0
	var tw: Tween = r.create_tween()
	var set_amount: Callable = func(v: float) -> void: m.set_shader_parameter("amount", v)
	tw.tween_method(set_amount, 0.0, 1.0, 0.15)
	tw.tween_interval(maxf(secs - 0.65, 0.2))
	tw.tween_method(set_amount, 1.0, 0.0, 0.5)
	tw.tween_callback(_on_flash_done.bind(r))


func _on_flash_done(r: ColorRect) -> void:
	r.visible = false
	_active_flashes -= 1
	if _flashes_free.size() < POOL_MAX:
		_flashes_free.append(r)
	else:
		r.queue_free()


func _show_banner(item: Dictionary, dur: int) -> void:
	if _banner == null:
		_banner = PanelContainer.new()
		_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_banner.add_theme_stylebox_override("panel",
			UiTheme.box(UiTheme.COL_PANEL_LIGHT, 18, UiTheme.COL_ACCENT, 3, 26, 12))
		_banner_label = UiUtil.label("", BANNER_FONT, UiTheme.COL_TEXT, HORIZONTAL_ALIGNMENT_CENTER)
		_banner_label.clip_text = true
		_banner_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		_banner.add_child(_banner_label)
		add_child(_banner)
	var names: Dictionary = names_provider.call() as Dictionary if names_provider.is_valid() else {}
	var extra: Dictionary = item.get("extra", {}) as Dictionary
	var caster: String = String(extra.get("caster", item.get("actor", "")))
	var txt: String = Strings.mage(names, caster) + ARROW + Strings.card_name(String(item.get("card_id", "")))
	var targets: Array = item.get("targets", []) as Array
	if not targets.is_empty():
		txt += ARROW + Strings.mage_list(names, targets)
	_banner_label.text = txt
	# Una línea, ancho ajustado al texto (como mucho 960 px) y alto fijo.
	var font: Font = _banner_label.get_theme_font("font")
	var text_w: float = font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, BANNER_FONT).x
	var w: float = clampf(text_w + 80.0, 320.0, minf(size.x - 80.0, 960.0))
	_banner.size = Vector2(w, float(BANNER_FONT) * 1.5 + 24.0)
	_banner.position = Vector2((size.x - _banner.size.x) * 0.5, size.y * BANNER_Y - _banner.size.y * 0.5)
	move_child(_banner, -1)
	_banner.visible = true
	_banner.modulate.a = 0.0
	if _banner_tween != null and _banner_tween.is_valid():
		_banner_tween.kill()
	var secs: float = float(dur) / 1000.0
	_banner_tween = _banner.create_tween()
	_banner_tween.tween_property(_banner, "modulate:a", 1.0, 0.15)
	_banner_tween.tween_interval(maxf(secs - 0.4, 0.6))
	_banner_tween.tween_property(_banner, "modulate:a", 0.0, 0.25)
	_banner_tween.tween_callback(func() -> void: _banner.visible = false)

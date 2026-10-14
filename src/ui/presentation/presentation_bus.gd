class_name PresentationBus
extends Node
## Bus de presentación: sesión.state_changed -> FeedbackMapper -> FeedbackQueue.
## No bloquea al motor: ingest solo traduce y encola. Ver bus-presentacion.md §4.3.

signal feedback_started(item: Dictionary)
signal feedback_finished(item: Dictionary)
signal feedback_dropped(item: Dictionary, reason: String)

## false en tests: se avanza a mano con advance()/drain().
var auto_advance: bool = true

var _session: GameSession = null
var _viewer_provider: Callable = Callable()
var _queue: FeedbackQueue = FeedbackQueue.new()
var _blocked: bool = false
var _last_seq: int = 0
var _warned_unnumbered: bool = false
var _stats: Dictionary = {}


func _init() -> void:
	_reset_stats()


func _reset_stats() -> void:
	_stats = {"produced": {}, "started": {}, "dropped": {"private": 0, "skipped": 0},
		"gaps": 0, "unnumbered": 0}


func bind(p_session: GameSession, p_viewer_provider: Callable, baseline_view: Dictionary) -> void:
	unbind()
	_session = p_session
	_viewer_provider = p_viewer_provider
	_last_seq = Types.last_log_seq(baseline_view.get("log", []) as Array)
	if _session != null and not _session.state_changed.is_connected(ingest):
		_session.state_changed.connect(ingest)


func unbind() -> void:
	if _session != null and is_instance_valid(_session) and _session.state_changed.is_connected(ingest):
		_session.state_changed.disconnect(ingest)
	_session = null
	_queue.clear()
	_reset_stats()
	_last_seq = 0
	_warned_unnumbered = false


func ingest(rev: int, events: Array) -> void:
	var sorted: Array = events.duplicate()
	sorted.sort_custom(func(a: Variant, b: Variant) -> bool:
		return int((a as Dictionary).get("log_seq", 0)) < int((b as Dictionary).get("log_seq", 0)))
	var locals: Array[String] = []
	if _session != null:
		locals = _session.get_local_player_ids()
	var top: int = _last_seq
	for e: Variant in sorted:
		var entry: Dictionary = e
		var seq: int = int(entry.get("log_seq", 0))
		if seq > 0 and seq <= _last_seq:
			continue
		if seq == 0:
			_stats["unnumbered"] = int(_stats["unnumbered"]) + 1
			if not _warned_unnumbered:
				_warned_unnumbered = true
				push_warning("PresentationBus: entradas de log sin log_seq; no se pueden deduplicar")
		elif _last_seq > 0 and seq > _last_seq + 1 and seq > top + 1:
			_stats["gaps"] = int(_stats["gaps"]) + 1
		top = maxi(top, seq)
		var vis: Array = entry.get("visible_to", []) as Array
		if not vis.is_empty():
			var seen: bool = false
			for pid: Variant in vis:
				if locals.has(String(pid)):
					seen = true
					break
			if not seen:
				continue
		for item: Dictionary in FeedbackMapper.map_entry(entry, rev):
			var k: String = String(item["kind"])
			var prod: Dictionary = _stats["produced"]
			prod[k] = int(prod.get(k, 0)) + 1
			for d: Dictionary in _queue.push(item):
				_count_drop("skipped")
				feedback_dropped.emit(d, "skipped")
	_last_seq = maxi(_last_seq, top)


func _count_drop(reason: String) -> void:
	var d: Dictionary = _stats["dropped"]
	d[reason] = int(d.get(reason, 0)) + 1


func set_blocked(value: bool) -> void:
	_blocked = value


func is_blocked() -> bool:
	return _blocked


func _process(delta: float) -> void:
	if auto_advance:
		advance(int(delta * 1000.0))


func advance(ms: int) -> void:
	var viewer: String = ""
	if _viewer_provider.is_valid():
		viewer = String(_viewer_provider.call())
	var r: Dictionary = _queue.advance(ms, viewer, _blocked)
	for it: Dictionary in r["finished"]:
		feedback_finished.emit(it)
	for it: Dictionary in r["dropped"]:
		_count_drop("private")
		feedback_dropped.emit(it, "private")
	for it: Dictionary in r["started"]:
		var k: String = String(it["kind"])
		var st: Dictionary = _stats["started"]
		st[k] = int(st.get(k, 0)) + 1
		feedback_started.emit(it)


func drain(max_ms: int = 120000, step_ms: int = 50) -> void:
	var t: int = 0
	while not is_idle() and t < max_ms:
		advance(step_ms)
		t += step_ms


func is_idle() -> bool:
	return _queue.is_idle()


func pending_count() -> int:
	return _queue.pending_count()


func last_seq() -> int:
	return _last_seq


func stats() -> Dictionary:
	return _stats.duplicate(true)

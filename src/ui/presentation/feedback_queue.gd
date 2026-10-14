class_name FeedbackQueue
extends RefCounted
## Cola de feedback por carriles (panel:<pid> y banner). Pura y determinista:
## reloj propio en ms, sin nodos ni esperas. Ver bus-presentacion.md §4.2.

const STAGGER_MS: int = 250
const STAGGER_FAST_MS: int = 100
const FAST_BACKLOG: int = 4
const BANNER_MAX_PENDING: int = 2

var now_ms: int = 0
var _lanes: Dictionary = {}       # lane -> {pending: Array, next_start: int}
var _lane_order: Array[String] = []
var _active: Array[Dictionary] = []   # {item, started_at}


## Encola; devuelve los items descartados por "skipped".
func push(item: Dictionary) -> Array[Dictionary]:
	var dropped: Array[Dictionary] = []
	var lane: String = String(item.get("lane", FeedbackMapper.LANE_BANNER))
	if not _lanes.has(lane):
		_lanes[lane] = {"pending": [], "next_start": 0}
		_lane_order.append(lane)
	var pending: Array = (_lanes[lane] as Dictionary)["pending"]
	# Ordenado por log_seq (estable; los sin numerar, o sea 0, van al final en su orden).
	var seq: int = int(item.get("log_seq", 0))
	var idx: int = pending.size()
	if seq > 0:
		while idx > 0:
			var prev: int = int((pending[idx - 1] as Dictionary).get("log_seq", 0))
			if prev == 0 or prev > seq:
				idx -= 1
			else:
				break
	pending.insert(idx, item)
	if lane == FeedbackMapper.LANE_BANNER:
		while pending.size() > BANNER_MAX_PENDING:
			var old: Dictionary = pending.pop_front()
			(old["extra"] as Dictionary)["drop_reason"] = "skipped"
			dropped.append(old)
	return dropped


func advance(ms: int, viewer: String, blocked: bool) -> Dictionary:
	var started: Array[Dictionary] = []
	var finished: Array[Dictionary] = []
	var dropped: Array[Dictionary] = []
	now_ms += maxi(ms, 0)
	var still: Array[Dictionary] = []
	for a: Dictionary in _active:
		var it: Dictionary = a["item"]
		if now_ms >= int(a["started_at"]) + int(it["duration_ms"]):
			finished.append(it)
		else:
			still.append(a)
	_active = still
	if not blocked:
		for lane: String in _lane_order:
			var l: Dictionary = _lanes[lane]
			var pending: Array = l["pending"]
			while not pending.is_empty() and now_ms >= int(l["next_start"]):
				if lane == FeedbackMapper.LANE_BANNER and _banner_active():
					break
				var it: Dictionary = pending.pop_front()
				var vis: Array = it.get("visible_to", []) as Array
				if not vis.is_empty() and not vis.has(viewer):
					(it["extra"] as Dictionary)["drop_reason"] = "private"
					dropped.append(it)
					continue
				_active.append({"item": it, "started_at": now_ms})
				started.append(it)
				if lane == FeedbackMapper.LANE_BANNER:
					l["next_start"] = now_ms + int(it["duration_ms"])
				elif pending.size() >= FAST_BACKLOG:
					l["next_start"] = now_ms + STAGGER_FAST_MS
				else:
					l["next_start"] = now_ms + STAGGER_MS
	return {"started": started, "finished": finished, "dropped": dropped}


func _banner_active() -> bool:
	for a: Dictionary in _active:
		if String((a["item"] as Dictionary)["lane"]) == FeedbackMapper.LANE_BANNER:
			return true
	return false


func pending_count() -> int:
	var n: int = 0
	for lane: String in _lane_order:
		n += ((_lanes[lane] as Dictionary)["pending"] as Array).size()
	return n


func active_count() -> int:
	return _active.size()


func is_idle() -> bool:
	return pending_count() == 0 and _active.is_empty()


func clear() -> void:
	_lanes.clear()
	_lane_order.clear()
	_active.clear()
	now_ms = 0

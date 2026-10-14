extends GutTest
## V2-14b: FeedbackMapper, FeedbackQueue y PresentationBus (sin la mesa).

const GAME_SEED: int = 33
const KINDS: Dictionary = {
	"damage": "damage", "heal": "heal", "mana_changed": "mana",
	"potion": "potion", "eliminated": "eliminated"}


class HotSeatSession extends GameSession:
	func get_local_player_ids() -> Array[String]:
		return ["p1", "p2"]


var _viewer: String = ""
var _started: Array = []
var _finished: Array = []
var _dropped: Array = []


func before_all() -> void:
	CardCatalog.load_json()
	EffectRegistry.reset()


func _entry(type: String, data: Dictionary = {}, player: String = "p1", seq: int = 0,
		vis: Array = []) -> Dictionary:
	var e: Dictionary = Types.make_log_entry(type, 1, player, data, vis)
	e["log_seq"] = seq
	return e


func _bus(session: GameSession, baseline: Dictionary = {}) -> PresentationBus:
	var bus: PresentationBus = PresentationBus.new()
	autofree(bus)
	bus.auto_advance = false
	_started = []
	_finished = []
	_dropped = []
	bus.feedback_started.connect(func(i: Dictionary) -> void: _started.append(i))
	bus.feedback_finished.connect(func(i: Dictionary) -> void: _finished.append(i))
	bus.feedback_dropped.connect(func(i: Dictionary, r: String) -> void: _dropped.append([i, r]))
	bus.bind(session, func() -> String: return _viewer, baseline)
	return bus


func _hot() -> HotSeatSession:
	var s: HotSeatSession = HotSeatSession.new()
	autofree(s)
	return s


func _seqs(items: Array) -> Array:
	var out: Array = []
	for i: Variant in items:
		out.append(int((i as Dictionary)["log_seq"]))
	return out


# 1. Mapper
func test_mapper_table() -> void:
	var cases: Array = [
		[_entry(Types.LOG_DAMAGE, {"target": "p2", "dealt": 4, "prevented": 1, "element": "fire"}, "p1", 1),
			"damage", "p2", -4, "panel:p2"],
		[_entry(Types.LOG_DAMAGE, {"target": "p2", "dealt": 0, "prevented": 3}, "p1", 2),
			"damage", "p2", 0, "panel:p2"],
		[_entry(Types.LOG_HEAL, {"target": "p3", "amount": 5}, "p1", 3), "heal", "p3", 5, "panel:p3"],
		[_entry(Types.LOG_MANA_CHANGED, {"target": "p2", "delta": -2}, "p1", 4), "mana", "p2", -2, "panel:p2"],
		[_entry(Types.LOG_MANA_CHANGED, {"delta": 3}, "p4", 5), "mana", "p4", 3, "panel:p4"],
		[_entry(Types.LOG_POTION, {"amount": 2, "potions": 5}, "p2", 6), "potion", "p2", 2, "panel:p2"],
		[_entry(Types.LOG_ELIMINATED, {"reason": "hp"}, "p3", 7), "eliminated", "p3", 0, "panel:p3"],
		[_entry(Types.LOG_CARD_PLAYED, {"cost": 3, "targets": ["p2"], "card_id": "fire_arrow"}, "p1", 8),
			"card_played", "", -3, "banner"],
	]
	for c: Array in cases:
		var items: Array[Dictionary] = FeedbackMapper.map_entry(c[0], 7)
		assert_eq(items.size(), 1, "uno por entrada: %s" % c[1])
		var it: Dictionary = items[0]
		assert_eq(it["kind"], c[1])
		assert_eq(it["target"], c[2])
		assert_eq(it["amount"], c[3])
		assert_eq(it["lane"], c[4])
		assert_eq(it["rev"], 7)
		assert_gte(int(it["duration_ms"]), 1000)
	for t: String in [Types.LOG_TURN_STARTED, Types.LOG_CARD_DRAWN, Types.LOG_EFFECT, Types.LOG_EVENT_DRAWN]:
		assert_eq(FeedbackMapper.map_entry(_entry(t), 1).size(), 0, t)


# 2. Partida de 4
func test_four_player_game_one_feedback_per_entry() -> void:
	var players: Array = []
	for i: int in 4:
		players.append({"name": "Mago %d" % (i + 1), "age": 40 - i, "birth_month": i + 1, "is_bot": true})
	var cfg: Dictionary = {"potion_limit_enabled": true, "potion_limit": 10, "potion_mana": 3,
		"include_curse_of_rules": true, "reaction_timeout_local_ms": 0, "mode": "local", "log_limit": 100000}
	var ls: LocalSession = LocalSession.create({"players": players, "config": cfg}, GAME_SEED)
	autofree(ls)
	ls.auto_run_bots = false
	_viewer = ""
	var bus: PresentationBus = _bus(ls, ls.get_view_for(""))
	var guard: int = 0
	while String(ls.state["status"]) != Types.STATUS_FINISHED and guard < 5000:
		guard += 1
		ls.run_bots(1)
		bus.advance(50)
	assert_eq(String(ls.state["status"]), Types.STATUS_FINISHED, "la partida termina")
	bus.drain()
	var st: Dictionary = bus.stats()
	for t: String in KINDS:
		var k: String = KINDS[t]
		var expect: Array = []
		for e: Variant in ls.state["log"]:
			var ed: Dictionary = e
			if String(ed["type"]) == t and (ed["visible_to"] as Array).is_empty():
				expect.append(int(ed["log_seq"]))
		assert_gt(expect.size(), 0, "la semilla produce %s" % t)
		assert_eq(int((st["produced"] as Dictionary).get(k, 0)), expect.size(), "produced %s" % k)
		assert_eq(int((st["started"] as Dictionary).get(k, 0)), expect.size(), "started %s" % k)
		var got: Array = []
		for it: Variant in _started:
			if String((it as Dictionary)["kind"]) == k:
				got.append(int((it as Dictionary)["log_seq"]))
		got.sort()
		expect.sort()
		assert_eq(got, expect, "log_seq exactos de %s" % k)
	var played: int = 0
	for e: Variant in ls.state["log"]:
		if String((e as Dictionary)["type"]) == Types.LOG_CARD_PLAYED:
			played += 1
	var prod_cp: int = int((st["produced"] as Dictionary).get("card_played", 0))
	assert_eq(prod_cp, played)
	assert_eq(int((st["started"] as Dictionary).get("card_played", 0)) + int((st["dropped"] as Dictionary)["skipped"]), prod_cp)
	for it: Variant in _started:
		assert_gte(int((it as Dictionary)["duration_ms"]), 1000)
	assert_eq(_finished.size(), _started.size(), "todo arrancado termina")
	assert_true(bus.is_idle())


# 3. No bloquea
func test_ingest_does_not_start_or_create_nodes() -> void:
	var bus: PresentationBus = _bus(_hot())
	bus.ingest(1, [_entry(Types.LOG_DAMAGE, {"target": "p2", "dealt": 2}, "p1", 1)])
	assert_eq(_started.size(), 0)
	assert_eq(int((bus.stats()["started"] as Dictionary).size()), 0)
	assert_eq(bus.get_child_count(), 0)
	assert_eq(bus.pending_count(), 1)
	var ls: LocalSession = LocalSession.create({"players": [
		{"name": "A", "age": 30, "birth_month": 1, "is_bot": true},
		{"name": "B", "age": 31, "birth_month": 2, "is_bot": true}], "config": {"mode": "local"}}, 3)
	autofree(ls)
	ls.auto_run_bots = false
	_bus(ls, ls.get_view_for(""))
	assert_gt(ls.run_bots(10), 0, "el motor avanza sin avanzar el bus")


# 4. Deduplicación
func test_dedup_and_baseline() -> void:
	var bus: PresentationBus = _bus(_hot())
	var evs: Array = [_entry(Types.LOG_HEAL, {"target": "p1", "amount": 1}, "p1", 1),
		_entry(Types.LOG_HEAL, {"target": "p1", "amount": 1}, "p1", 2)]
	bus.ingest(1, evs)
	bus.ingest(2, evs)
	assert_eq(int((bus.stats()["produced"] as Dictionary)["heal"]), 2)
	var log40: Array = []
	for i: int in range(1, 41):
		log40.append(_entry(Types.LOG_TURN_STARTED, {}, "", i))
	var bus2: PresentationBus = _bus(_hot(), {"log": log40})
	var batch: Array = []
	for i: int in range(35, 46):
		batch.append(_entry(Types.LOG_HEAL, {"target": "p1", "amount": 1}, "p1", i))
	bus2.ingest(5, batch)
	bus2.drain()
	assert_eq(_seqs(_started), [41, 42, 43, 44, 45])
	assert_eq(bus2.last_seq(), 45)


# 5. Orden
func test_order_by_log_seq() -> void:
	var bus: PresentationBus = _bus(_hot())
	bus.ingest(1, [_entry(Types.LOG_DAMAGE, {"target": "p2", "dealt": 1}, "p1", 6),
		_entry(Types.LOG_DAMAGE, {"target": "p2", "dealt": 1}, "p1", 5)])
	bus.drain()
	assert_eq(_seqs(_started), [5, 6])


# 6. Privadas en hot-seat
func test_private_hot_seat() -> void:
	var mana: Dictionary = _entry(Types.LOG_MANA_CHANGED, {"target": "p1", "delta": -1}, "p1", 1, ["p1"])
	var dmg: Dictionary = _entry(Types.LOG_DAMAGE, {"target": "p2", "dealt": 2}, "p1", 2)
	_viewer = "p2"
	var bus: PresentationBus = _bus(_hot())
	bus.ingest(1, [mana, dmg])
	bus.drain()
	assert_eq(_seqs(_started), [2])
	assert_eq(_dropped.size(), 1)
	assert_eq(_dropped[0][1], "private")
	_viewer = "p1"
	var bus2: PresentationBus = _bus(_hot())
	bus2.ingest(1, [mana, dmg])
	bus2.drain()
	assert_eq(_seqs(_started), [1, 2])
	# bloqueo
	_viewer = "p2"
	var bus3: PresentationBus = _bus(_hot())
	bus3.set_blocked(true)
	bus3.ingest(1, [mana, dmg])
	bus3.advance(5000)
	assert_eq(_started.size(), 0)
	_viewer = "p1"
	bus3.set_blocked(false)
	bus3.advance(50)
	bus3.drain()
	assert_eq(_seqs(_started), [1, 2])
	# no local
	var bus4: PresentationBus = _bus(_hot())
	bus4.ingest(1, [_entry(Types.LOG_DAMAGE, {"target": "p3", "dealt": 2}, "p1", 1, ["p3"])])
	assert_eq(bus4.stats()["produced"], {})


# 7. Banner
func test_banner_exclusive_and_skips() -> void:
	var bus: PresentationBus = _bus(_hot())
	var evs: Array = []
	for i: int in 4:
		evs.append(_entry(Types.LOG_CARD_PLAYED, {"cost": 1, "targets": []}, "p1", i + 1))
	bus.ingest(1, evs)
	var max_active: int = 0
	var steps: int = 0
	while not bus.is_idle() and steps < 1000:
		steps += 1
		bus.advance(50)
		max_active = maxi(max_active, _started.size() - _finished.size())
	assert_lte(max_active, 1)
	var st: Dictionary = bus.stats()
	assert_eq(int((st["started"] as Dictionary)["card_played"]) + int((st["dropped"] as Dictionary)["skipped"]), 4)
	assert_eq(int((st["dropped"] as Dictionary)["skipped"]), 2)
	assert_eq(_seqs(_started), [3, 4], "se descartan los más viejos")


# 8. Sin log_seq
func test_unnumbered_entries() -> void:
	var bus: PresentationBus = _bus(_hot())
	bus.ingest(1, [_entry(Types.LOG_HEAL, {"target": "p1", "amount": 1}),
		_entry(Types.LOG_HEAL, {"target": "p1", "amount": 1})])
	assert_eq(int((bus.stats()["produced"] as Dictionary)["heal"]), 2)
	assert_eq(bus.stats()["unnumbered"], 2)
	bus.drain()
	assert_eq(_started.size(), 2)

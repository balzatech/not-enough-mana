extends GutTest
## T4: preparación (REQ 1, 1.1), mazo y robo (1.2.1).

const H = preload("res://tests/fixtures/engine_helpers.gd")


func before_each() -> void:
	EffectRegistry.reset()
	H.use_fixture_catalog()


func after_all() -> void:
	EffectRegistry.reset()
	CardCatalog.load_json()


func test_deck_has_154_playable_cards_and_conserves() -> void:
	var s: Dictionary = H.game(3)
	assert_eq(s["card_total"], 154)
	assert_eq(Types.validate_state(s), [] as Array[String])
	var ids: Dictionary = {}
	for iid: int in Types.all_card_iids(s):
		ids[iid] = true
	assert_eq(ids.size(), 154)
	# Ninguna carta no jugable entra en el mazo.
	for c: Variant in s["deck"]:
		var def: Dictionary = CardCatalog.get_def(String((c as Dictionary)["card_id"]))
		assert_ne(def["type"], Types.CARD_TYPE_NON_PLAYABLE)


func test_curse_of_rules_can_be_excluded() -> void:
	var s: Dictionary = H.game(3, {"include_curse_of_rules": false})
	assert_eq(s["card_total"], 151)


func test_start_values_hp10_mana0_five_cards() -> void:
	var s: Dictionary = H.game(4)
	assert_eq(s["status"], Types.STATUS_PLAYING)
	for p: Variant in s["players"]:
		var pd: Dictionary = p
		assert_eq(pd["hp"], 10)
		assert_eq(pd["mana"], 0)
		assert_eq((pd["hand"] as Array).size(), 5)
		for c: Variant in pd["hand"]:
			assert_false(Game.is_event(String((c as Dictionary)["card_id"])), "sin eventos en la mano inicial")
	# El pool entrega los 10 de vida de cada mago.
	assert_eq((s["pool"] as Dictionary)["hp"], 70 - 40)
	assert_eq((s["pool"] as Dictionary)["mana"], 70)


func test_shuffle_is_deterministic_by_seed() -> void:
	var a: Dictionary = H.game(3, {}, 42)
	var b: Dictionary = H.game(3, {}, 42)
	var c: Dictionary = H.game(3, {}, 43)
	assert_eq(a["deck"], b["deck"])
	assert_ne(a["deck"], c["deck"])


func test_fisher_yates_uses_rng_state() -> void:
	var s: Dictionary = Types.make_state({}, 7)
	s["deck"] = [Types.make_card_instance(1, "a"), Types.make_card_instance(2, "b"), Types.make_card_instance(3, "c")]
	var before: int = s["rng_state"]
	Deck.shuffle_pile(s)
	assert_ne(s["rng_state"], before)
	assert_eq((s["deck"] as Array).size(), 3)


func test_events_in_initial_deal_are_discarded_and_replaced() -> void:
	CardCatalog.set_defs(H.CardsFixture.small([
		["card_a", Types.CARD_TYPE_SUPPORT, 30], [Types.CARD_BLESSING, Types.CARD_TYPE_EVENT, 1],
		[Types.CARD_SHOT_GLASS, Types.CARD_TYPE_EVENT, 1]]))
	var s: Dictionary = Types.make_state({}, 1)
	s["players"] = H.make_players(2)
	s["status"] = Types.STATUS_PLAYING
	s["turn"] = Types.make_turn(1, "p1", Types.PHASE_MAIN)
	var deck: Array = []
	for i: int in 20:
		deck.append(Types.make_card_instance(i + 1, "card_a"))
	# Arriba (final) dos eventos: el primer jugador los descarta y roba otras.
	deck.append(Types.make_card_instance(21, Types.CARD_BLESSING))
	deck.append(Types.make_card_instance(22, Types.CARD_SHOT_GLASS))
	s["deck"] = deck
	s["card_total"] = 22
	var events: Array = []
	Game.deal_initial(s, events)
	assert_eq(H.hand(s, "p1").size(), 5)
	assert_eq(H.hand(s, "p2").size(), 5)
	assert_eq((s["discard"] as Array).size(), 2)
	assert_true((s["active_event"] as Dictionary).is_empty(), "en el reparto no se activan")
	assert_eq(Types.validate_state(s), [] as Array[String])


func test_eldest_starts() -> void:
	var s: Dictionary = H.game(4, {}, 1, [20, 55, 40, 55])
	assert_eq((s["turn"] as Dictionary)["current"], "p2", "el mayor; empate = primero en asiento")
	assert_eq((s["turn"] as Dictionary)["number"], 1)
	assert_eq((s["turn"] as Dictionary)["phase"], Types.PHASE_MAIN)


func test_turn_order_is_clockwise() -> void:
	var s: Dictionary = H.game(3, {}, 1, [30, 50, 40])
	assert_eq((s["turn"] as Dictionary)["current"], "p2")
	s = H.ok(self, s, Types.make_action_end_turn("p2"))
	assert_eq((s["turn"] as Dictionary)["current"], "p3")
	s = H.ok(self, s, Types.make_action_end_turn("p3"))
	assert_eq((s["turn"] as Dictionary)["current"], "p1")
	s = H.ok(self, s, Types.make_action_end_turn("p1"))
	assert_eq((s["turn"] as Dictionary)["current"], "p2")
	assert_eq((s["turn"] as Dictionary)["number"], 4)


func test_draw_up_to_hand_limit_at_turn_start() -> void:
	var s: Dictionary = H.game(3)
	var cur: String = (s["turn"] as Dictionary)["current"]
	var nxt: String = Game.next_alive_after(s, cur)
	H.set_hand(s, nxt, [Types.CARD_HEAL])
	H.stack_deck(s, [Types.CARD_HEAL, Types.CARD_HEAL, Types.CARD_HEAL, Types.CARD_HEAL])
	s = H.ok(self, s, Types.make_action_end_turn(cur))
	assert_eq(H.hand(s, nxt).size(), 5)
	assert_eq(Types.validate_state(s), [] as Array[String])


func test_hand_limit_modifier_increases_draw() -> void:
	var s: Dictionary = H.game(3)
	var cur: String = (s["turn"] as Dictionary)["current"]
	var nxt: String = Game.next_alive_after(s, cur)
	Modifiers.add(s, Types.make_modifier("spellbook#x", Types.STAGE_HAND_LIMIT, Types.OP_ADD, 1, nxt,
		Types.SIDE_TARGET))
	H.stack_deck(s, [Types.CARD_HEAL, Types.CARD_HEAL])
	s = H.ok(self, s, Types.make_action_end_turn(cur))
	assert_eq(H.hand(s, nxt).size(), 6)
	assert_eq(Damage.hand_limit(s, cur), 5)


func test_drawn_event_activates_and_is_replaced() -> void:
	var called: Array = []
	EffectRegistry.register(Types.CARD_BLESSING, func(st: Dictionary, ctx: Dictionary) -> Dictionary:
		called.append(String(ctx["caster"]))
		return st)
	var s: Dictionary = H.game(3)
	var cur: String = (s["turn"] as Dictionary)["current"]
	var nxt: String = Game.next_alive_after(s, cur)
	H.set_hand(s, nxt, [Types.CARD_HEAL, Types.CARD_HEAL, Types.CARD_HEAL, Types.CARD_HEAL])
	# Un modificador "hasta el próximo evento" que debe caducar.
	Modifiers.add(s, Types.make_modifier("old#1", Types.STAGE_POTION, Types.OP_SUB, 1, "", Types.SIDE_ANY, "",
		Types.EXPIRES_NEXT_EVENT))
	H.stack_deck(s, [Types.CARD_FIREBALL, Types.CARD_BLESSING])
	var r: Dictionary = Game.reduce(s, Types.make_action_end_turn(cur))
	s = r["state"]
	assert_eq(called, [nxt])
	assert_eq((s["active_event"] as Dictionary)["card_id"], Types.CARD_BLESSING)
	assert_eq(H.hand(s, nxt).size(), 5)
	assert_eq((H.hand(s, nxt).back() as Dictionary)["card_id"], Types.CARD_FIREBALL)
	assert_eq((s["modifiers"] as Array).size(), 0)
	var types: Array = []
	for e: Variant in r["events"]:
		types.append((e as Dictionary)["type"])
	assert_true(types.has(Types.LOG_EVENT_DRAWN))


func test_new_event_replaces_previous_one() -> void:
	var ended: Array = []
	EffectRegistry.register_hook(Types.HOOK_EVENT_END, Types.CARD_BLESSING,
		func(st: Dictionary, ctx: Dictionary) -> Dictionary:
			ended.append((ctx["card"] as Dictionary)["card_id"])
			return st)
	var s: Dictionary = H.game(3)
	var cur: String = (s["turn"] as Dictionary)["current"]
	var nxt: String = Game.next_alive_after(s, cur)
	H.set_hand(s, nxt, [Types.CARD_HEAL, Types.CARD_HEAL, Types.CARD_HEAL])
	H.stack_deck(s, [Types.CARD_HEAL, Types.CARD_SHOT_GLASS, Types.CARD_HEAL, Types.CARD_BLESSING])
	var blessing_iid: int = int(((s["deck"] as Array)[(s["deck"] as Array).size() - 1] as Dictionary)["iid"])
	s = H.ok(self, s, Types.make_action_end_turn(cur))
	assert_eq((s["active_event"] as Dictionary)["card_id"], Types.CARD_SHOT_GLASS)
	assert_eq(ended, [Types.CARD_BLESSING])
	assert_eq(((s["discard"] as Array).back() as Dictionary)["iid"], blessing_iid)
	assert_eq(Types.validate_state(s), [] as Array[String])


func test_reshuffle_discard_when_deck_runs_out() -> void:
	var s: Dictionary = H.game(3)
	var cur: String = (s["turn"] as Dictionary)["current"]
	var nxt: String = Game.next_alive_after(s, cur)
	# Todo el mazo al descarte salvo nada: el robo debe rebarajar.
	var deck: Array = s["deck"]
	(s["discard"] as Array).append_array(deck)
	deck.clear()
	H.set_hand(s, nxt, [])
	var r: Dictionary = Game.reduce(s, Types.make_action_end_turn(cur))
	s = r["state"]
	assert_eq(r["error"], "")
	assert_eq(H.hand(s, nxt).size(), 5)
	assert_gt((s["deck"] as Array).size(), 0)
	var types: Array = []
	for e: Variant in r["events"]:
		types.append((e as Dictionary)["type"])
	assert_true(types.has(Types.LOG_DECK_RESHUFFLED))
	assert_eq(Types.validate_state(s), [] as Array[String])


func test_draw_stops_when_no_cards_anywhere() -> void:
	var s: Dictionary = H.game(3)
	var cur: String = (s["turn"] as Dictionary)["current"]
	var nxt: String = Game.next_alive_after(s, cur)
	# Mueve mazo y descarte a la mano de un tercero (conserva cartas).
	var third: String = Game.next_alive_after(s, nxt)
	H.set_hand(s, nxt, [])
	H.hand(s, third).append_array(s["deck"] as Array)
	H.hand(s, third).append_array(s["discard"] as Array)
	(s["deck"] as Array).clear()
	(s["discard"] as Array).clear()
	var r: Dictionary = Game.reduce(s, Types.make_action_end_turn(cur))
	assert_eq(r["error"], "")
	assert_eq(H.hand(r["state"] as Dictionary, nxt).size(), 0)

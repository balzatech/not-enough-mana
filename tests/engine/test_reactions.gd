extends NemTest
## T6b: ventana de reacción (orden, pila LIFO, cierre automático, plazo,
## Annihilation, Mirror Shield, Last Wish, extensión de Lightning encadenado).
## Catálogo real; los ofensivos usan los efectos falsos de engine_helpers
## (Lightning = 2 de daño al objetivo).

const H = preload("res://tests/fixtures/engine_helpers.gd")


func before_each() -> void:
	super.before_each()
	CardCatalog.load_json()
	EffectRegistry.reset()
	H.register_fake_effects()


func after_all() -> void:
	EffectRegistry.reset()
	CardCatalog.load_json()


## n jugadores con 10💖, `mana`💧 y manos vacías; turno de p1 en fase main.
func _state(n: int, mana: int = 10) -> Dictionary:
	var s: Dictionary = Types.make_state({}, 11)
	var c: Dictionary = s["config"]
	var ps: Array = []
	for i: int in n:
		var p: Dictionary = Types.make_player("p%d" % (i + 1), "P%d" % (i + 1), 30 + i, (i % 12) + 1)
		p["mana"] = mana
		ps.append(p)
	s["players"] = ps
	var pool: Dictionary = s["pool"]
	pool["hp"] = int(pool["hp"]) - int(c["start_hp"]) * n
	pool["mana"] = maxi(0, int(pool["mana"]) - mana * n)
	var deck: Array = []
	for x: Variant in Deck.build_instances(CardCatalog.all_defs(), c):
		if not Game.is_event(String((x as Dictionary)["card_id"])):
			deck.append(x)
	s["deck"] = deck
	s["card_total"] = deck.size()
	s["status"] = Types.STATUS_PLAYING
	s["turn"] = Types.make_turn(1, "p1", Types.PHASE_MAIN)
	return s


func _cast(s: Dictionary, caster: String, card_id: String, targets: Array, payment_ids: Array = []) -> Dictionary:
	var ids: Array = [card_id]
	ids.append_array(payment_ids)
	var iids: Array = H.set_hand(s, caster, ids)
	var pay: Array = iids.slice(1)
	return Game.reduce(s, Types.make_action_play_card(caster, int(iids[0]), targets, pay))


func _hp(s: Dictionary, pid: String) -> int:
	return int(H.player(s, pid)["hp"])


func _re(s: Dictionary) -> Dictionary:
	return s["reaction"]


func _iid(s: Dictionary, pid: String, card_id: String) -> int:
	for c: Variant in H.hand(s, pid):
		if String((c as Dictionary)["card_id"]) == card_id:
			return int((c as Dictionary)["iid"])
	return -1


func _types(events: Array) -> Array:
	var out: Array = []
	for e: Variant in events:
		out.append((e as Dictionary)["type"])
	return out


# --- Cierre automático -------------------------------------------------------

func test_auto_close_without_defensives() -> void:
	var s: Dictionary = _state(3)
	var r: Dictionary = _cast(s, "p1", Types.CARD_LIGHTNING, ["p2"])
	assert_eq(r["error"], "")
	var s2: Dictionary = r["state"]
	assert_true(_re(s2).is_empty(), "nadie puede responder: no se abre")
	assert_eq(_hp(s2, "p2"), 8)
	assert_false(_types(r["events"]).has(Types.LOG_REACTION_OPENED))
	assert_eq(Types.validate_state(s2), [] as Array[String])


func test_auto_close_when_cost_unpayable() -> void:
	var s: Dictionary = _state(3, 0)
	H.set_mana(s, "p1", 10)
	# p2: Magic Shield sin maná y sin pociones seguras (Too Much Mana).
	H.set_hand(s, "p2", [Types.CARD_MAGIC_SHIELD])
	H.player(s, "p2")["potions"] = 10
	# p3: Mirror Shield sin otra defensiva para pagar, aunque tenga maná.
	H.set_hand(s, "p3", [Types.CARD_MIRROR_SHIELD, Types.CARD_FIRE_ARROW])
	H.set_mana(s, "p3", 10)
	var r: Dictionary = _cast(s, "p1", Types.CARD_LIGHTNING, ["p2"])
	assert_eq(r["error"], "")
	assert_true(_re(r["state"]).is_empty())
	assert_eq(_hp(r["state"], "p2"), 8)


func test_potions_count_as_payable() -> void:
	var s: Dictionary = _state(3, 0)
	H.set_mana(s, "p1", 10)
	H.set_hand(s, "p2", [Types.CARD_MAGIC_SHIELD])
	var s2: Dictionary = H.ok(self, s, Types.make_action_play_card("p1", H.set_hand(s, "p1", [Types.CARD_LIGHTNING])[0], ["p2"]))
	assert_eq(_re(s2)["awaiting"], ["p2"])
	var shield: int = _iid(s2, "p2", Types.CARD_MAGIC_SHIELD)
	# Sin maná todavía: hay que beber durante la ventana.
	assert_eq(H.err(s2, Types.make_action_react("p2", shield, ["p2"])), Types.ERR_INSUFFICIENT_MANA)
	var legal: Array = Reactions.legal_actions(s2, "p2")
	assert_eq(legal.size(), 1, "solo PASS hasta que beba")
	s2 = H.ok(self, s2, Types.make_action_drink_potion("p2"))
	assert_eq(int(H.player(s2, "p2")["mana"]), 3)
	s2 = H.ok(self, s2, Types.make_action_react("p2", shield, ["p2"]))
	assert_eq(int(H.player(s2, "p2")["mana"]), 1, "pagó 2 fuera de turno")
	assert_true(_re(s2).is_empty())
	assert_eq(_hp(s2, "p2"), 10)


# --- Apertura, turnos y PASS ----------------------------------------------------

func test_window_blocks_turn_and_pass_resolves() -> void:
	var s: Dictionary = _state(3)
	H.set_hand(s, "p2", [Types.CARD_MAGIC_SHIELD])
	var r: Dictionary = _cast(s, "p1", Types.CARD_LIGHTNING, ["p2"])
	var s2: Dictionary = r["state"]
	assert_true(_types(r["events"]).has(Types.LOG_REACTION_OPENED))
	assert_eq(_re(s2)["awaiting"], ["p2"])
	assert_eq(_hp(s2, "p2"), 10, "aún no se resuelve")
	assert_eq(H.err(s2, Types.make_action_end_turn("p1")), Types.ERR_REACTION_PENDING)
	assert_eq(H.err(s2, Types.make_action_pass_reaction("p3")), Types.ERR_NOT_YOUR_DECISION)
	var shield: int = _iid(s2, "p2", Types.CARD_MAGIC_SHIELD)
	assert_eq(H.err(s2, Types.make_action_play_card("p2", shield, ["p2"])), Types.ERR_NOT_YOUR_TURN)
	assert_eq(H.err(s2, Types.make_action_react("p3", shield, ["p2"])), Types.ERR_NOT_YOUR_DECISION)
	r = Game.reduce(s2, Types.make_action_pass_reaction("p2"))
	assert_eq(r["error"], "")
	var s3: Dictionary = r["state"]
	assert_true(_re(s3).is_empty())
	assert_eq(_hp(s3, "p2"), 8)
	assert_true(_types(r["events"]).has(Types.LOG_REACTION_PASSED))
	assert_true(_types(r["events"]).has(Types.LOG_SPELL_RESOLVED))
	assert_eq(Types.validate_state(s3), [] as Array[String])
	# Después de cerrar, el turno sigue.
	H.ok(self, s3, Types.make_action_end_turn("p1"))


func test_react_or_pass_without_window() -> void:
	var s: Dictionary = _state(3)
	assert_eq(H.err(s, Types.make_action_pass_reaction("p2")), Types.ERR_NO_REACTION)


func test_play_card_rejects_defensives() -> void:
	var s: Dictionary = _state(3)
	var iids: Array = H.set_hand(s, "p1", [Types.CARD_MAGIC_SHIELD])
	assert_eq(H.err(s, Types.make_action_play_card("p1", int(iids[0]), ["p1"])), Types.ERR_CARD_NOT_PLAYABLE)


func test_legal_actions_in_window() -> void:
	var s: Dictionary = _state(3)
	H.set_hand(s, "p2", [Types.CARD_MAGIC_SHIELD])
	H.set_hand(s, "p3", [Types.CARD_MAGIC_SHIELD])
	var s2: Dictionary = _cast(s, "p1", Types.CARD_LIGHTNING, ["p2"])["state"]
	var mine: Array = Reactions.legal_actions(s2, "p2")
	assert_eq((mine[0] as Dictionary)["type"], Types.ACTION_PASS_REACTION)
	assert_eq(mine.size(), 1 + 3, "PASS + Magic Shield sobre cada uno de los 3 magos")
	for a: Variant in mine:
		assert_eq(Game.reduce(s2, a as Dictionary)["error"], "", str(a))
	assert_eq(Reactions.legal_actions(s2, "p3"), [], "no le toca a p3")
	var all_p1: Array = Game.legal_actions(s2, "p1")
	for a: Variant in all_p1:
		assert_ne((a as Dictionary)["type"], Types.ACTION_END_TURN)


# --- Pila de 3 respuestas (LIFO) ----------------------------------------------

func test_stack_of_three_responses_resolves_lifo() -> void:
	var s: Dictionary = _state(3)
	H.set_hand(s, "p2", [Types.CARD_MAGIC_SHIELD])
	H.set_hand(s, "p3", [Types.CARD_MAGIC_SHIELD])
	var r: Dictionary = _cast(s, "p1", Types.CARD_LIGHTNING, ["p2"])
	var s2: Dictionary = r["state"]
	var light_iid: int = int(((_re(s2)["spell"] as Dictionary)["card"] as Dictionary)["iid"])
	assert_eq(_re(s2)["awaiting"], ["p2", "p3"])
	var a1: int = _iid(s2, "p2", Types.CARD_MAGIC_SHIELD)
	s2 = H.ok(self, s2, Types.make_action_react("p2", a1, ["p2"]))
	assert_eq(_re(s2)["awaiting"], ["p3"])
	# p1 (lanzador) recibe ahora una Magic Shield (p. ej. para protegerse luego).
	H.set_hand(s2, "p1", [Types.CARD_MAGIC_SHIELD])
	var a2: int = _iid(s2, "p3", Types.CARD_MAGIC_SHIELD)
	s2 = H.ok(self, s2, Types.make_action_react("p3", a2, ["p3"]))
	assert_eq(_re(s2)["awaiting"], ["p1"], "ronda nueva: solo quien aún puede responder")
	var a3: int = _iid(s2, "p1", Types.CARD_MAGIC_SHIELD)
	assert_eq((_re(s2)["stack"] as Array).size(), 2)
	r = Game.reduce(s2, Types.make_action_react("p1", a3, ["p1"]))
	assert_eq(r["error"], "")
	var s3: Dictionary = r["state"]
	assert_true(_re(s3).is_empty(), "nadie más puede responder: se cierra")
	# Orden de resolución: a3, a2, a1 y luego el Lightning.
	var order: Array = []
	for e: Variant in r["events"]:
		var ed: Dictionary = e
		if ed["type"] == Types.LOG_SPELL_RESOLVED:
			order.append(int((ed["data"] as Dictionary)["iid"]))
	assert_eq(order, [a3, a2, a1, light_iid])
	assert_eq(_hp(s3, "p2"), 10, "la Magic Shield de p2 previene los 2")
	assert_eq((s3["modifiers"] as Array).size(), 0, "caducan con el hechizo")
	var disc: Array = []
	for c: Variant in s3["discard"]:
		disc.append(int((c as Dictionary)["iid"]))
	for x: int in [a1, a2, a3, light_iid]:
		assert_true(disc.has(x))
	assert_eq(Types.validate_state(s3), [] as Array[String])


func test_responder_order_restarts_with_target_after_react() -> void:
	var s: Dictionary = _state(4)
	H.set_hand(s, "p2", [Types.CARD_MAGIC_SHIELD])
	H.set_hand(s, "p3", [Types.CARD_MAGIC_SHIELD, Types.CARD_MAGIC_SHIELD])
	H.set_hand(s, "p4", [Types.CARD_MAGIC_SHIELD])
	var s2: Dictionary = _cast(s, "p1", Types.CARD_LIGHTNING, ["p3"])["state"]
	assert_eq(_re(s2)["awaiting"], ["p3", "p4", "p2"])
	s2 = H.ok(self, s2, Types.make_action_pass_reaction("p3"))
	assert_eq(_re(s2)["passed"], ["p3"])
	s2 = H.ok(self, s2, Types.make_action_react("p4", _iid(s2, "p4", Types.CARD_MAGIC_SHIELD), ["p3"]))
	assert_eq(_re(s2)["awaiting"], ["p3", "p2"], "p3 vuelve a decidir; p4 ya no tiene cartas")
	assert_eq(_re(s2)["passed"], [])


# --- Annihilation -------------------------------------------------------------

func test_annihilation_on_stacked_defensive() -> void:
	var s: Dictionary = _state(3)
	H.set_hand(s, "p2", [Types.CARD_MAGIC_SHIELD])
	var s2: Dictionary = _cast(s, "p1", Types.CARD_LIGHTNING, ["p2"])["state"]
	H.set_hand(s2, "p1", [Types.CARD_ANNIHILATION, Types.CARD_FIRE_ARROW])
	var shield: int = _iid(s2, "p2", Types.CARD_MAGIC_SHIELD)
	s2 = H.ok(self, s2, Types.make_action_react("p2", shield, ["p2"]))
	assert_eq(_re(s2)["awaiting"], ["p1"])
	var ann: int = _iid(s2, "p1", Types.CARD_ANNIHILATION)
	var arrow: int = _iid(s2, "p1", Types.CARD_FIRE_ARROW)
	assert_eq(H.err(s2, Types.make_action_react("p1", ann, [], [arrow], {}, 99999)), Types.ERR_CARD_NOT_IN_PLAY)
	assert_eq(H.err(s2, Types.make_action_react("p1", ann, [], [], {}, shield)), Types.ERR_INVALID_PAYMENT)
	var r: Dictionary = Game.reduce(s2, Types.make_action_react("p1", ann, [], [arrow], {}, shield))
	assert_eq(r["error"], "")
	var s3: Dictionary = r["state"]
	assert_true(_re(s3).is_empty())
	assert_eq(_hp(s3, "p2"), 8, "la Magic Shield anulada no protege")
	assert_eq(int(H.player(s3, "p1")["mana"]), 10 - 2 - 4)
	var cancelled: Array = []
	for e: Variant in r["events"]:
		var ed: Dictionary = e
		if ed["type"] == Types.LOG_SPELL_CANCELLED:
			cancelled.append(int((ed["data"] as Dictionary)["iid"]))
	assert_eq(cancelled, [shield])
	var disc: Array = []
	for c: Variant in s3["discard"]:
		disc.append(int((c as Dictionary)["iid"]))
	assert_true(disc.has(shield) and disc.has(ann) and disc.has(arrow))
	assert_eq(Types.validate_state(s3), [] as Array[String])


func test_annihilation_on_spell_in_flight() -> void:
	var s: Dictionary = _state(3)
	H.set_hand(s, "p2", [Types.CARD_ANNIHILATION, Types.CARD_FIREBALL])
	var s2: Dictionary = _cast(s, "p1", Types.CARD_LIGHTNING, ["p2"])["state"]
	var light: int = int(((_re(s2)["spell"] as Dictionary)["card"] as Dictionary)["iid"])
	var r: Dictionary = Game.reduce(s2, Types.make_action_react("p2", _iid(s2, "p2", Types.CARD_ANNIHILATION), [],
		[_iid(s2, "p2", Types.CARD_FIREBALL)], {}, light))
	assert_eq(r["error"], "")
	var s3: Dictionary = r["state"]
	assert_true(_re(s3).is_empty())
	assert_eq(_hp(s3, "p2"), 10)
	assert_true(_types(r["events"]).has(Types.LOG_SPELL_CANCELLED))
	assert_eq(int(((s3["discard"] as Array).back() as Dictionary)["iid"]), light)


# --- Mirror Shield ---------------------------------------------------------------

func test_mirror_shield_towards_eliminated_is_illegal() -> void:
	var s: Dictionary = _state(4)
	var p4: Dictionary = H.player(s, "p4")
	p4["eliminated"] = true
	p4["eliminated_reason"] = Types.ELIM_HP
	p4["hp"] = 0
	H.set_hand(s, "p2", [Types.CARD_MIRROR_SHIELD, Types.CARD_MAGIC_SHIELD])
	var s2: Dictionary = _cast(s, "p1", Types.CARD_LIGHTNING, ["p2"])["state"]
	var ms: int = _iid(s2, "p2", Types.CARD_MIRROR_SHIELD)
	var pay: int = _iid(s2, "p2", Types.CARD_MAGIC_SHIELD)
	assert_eq(H.err(s2, Types.make_action_react("p2", ms, ["p4"], [pay])), Types.ERR_INVALID_TARGET)
	assert_eq(H.err(s2, Types.make_action_react("p2", ms, ["p3"], [pay], {"protect": "p4"})), Types.ERR_INVALID_TARGET)
	for a: Variant in Reactions.legal_actions(s2, "p2"):
		var ad: Dictionary = a
		if ad.has("targets"):
			assert_false((ad["targets"] as Array).has("p4"))
	# Hacia un mago vivo sí vale: los 2 de daño van a p3.
	var s3: Dictionary = H.ok(self, s2, Types.make_action_react("p2", ms, ["p3"], [pay]))
	assert_true(_re(s3).is_empty())
	assert_eq(_hp(s3, "p2"), 10)
	assert_eq(_hp(s3, "p3"), 8)


# --- Last Wish ----------------------------------------------------------------

func test_last_wish_with_death() -> void:
	var s: Dictionary = _state(3)
	H.player(s, "p2")["hp"] = 2
	H.set_hand(s, "p2", [Types.CARD_LAST_WISH])
	var s2: Dictionary = _cast(s, "p1", Types.CARD_LIGHTNING, ["p2"])["state"]
	var r: Dictionary = Game.reduce(s2, Types.make_action_react("p2", _iid(s2, "p2", Types.CARD_LAST_WISH)))
	assert_eq(r["error"], "")
	var s3: Dictionary = r["state"]
	assert_true(bool(H.player(s3, "p2")["eliminated"]), "sigue muriendo")
	assert_eq(_hp(s3, "p1"), 8, "el atacante recibe el mismo daño")
	var found: bool = false
	for e: Variant in r["events"]:
		var ed: Dictionary = e
		if ed["type"] == Types.LOG_EFFECT and String((ed["data"] as Dictionary).get("what", "")) == "last_wish" \
				and String((ed["data"] as Dictionary).get("target", "")) == "p1":
			found = true
	assert_true(found, "evento de Last Wish en el log de la acción")
	assert_eq(Types.validate_state(s3), [] as Array[String])


func test_last_wish_without_death_does_nothing() -> void:
	var s: Dictionary = _state(3)
	H.set_hand(s, "p2", [Types.CARD_LAST_WISH])
	var s2: Dictionary = _cast(s, "p1", Types.CARD_LIGHTNING, ["p2"])["state"]
	var s3: Dictionary = H.ok(self, s2, Types.make_action_react("p2", _iid(s2, "p2", Types.CARD_LAST_WISH)))
	assert_eq(_hp(s3, "p2"), 8)
	assert_eq(_hp(s3, "p1"), 10)
	assert_eq((s3["modifiers"] as Array).size(), 0)


func test_last_wish_can_end_game_in_draw() -> void:
	var s: Dictionary = _state(2)
	H.player(s, "p1")["hp"] = 2
	H.player(s, "p2")["hp"] = 1
	H.set_hand(s, "p2", [Types.CARD_LAST_WISH])
	var s2: Dictionary = _cast(s, "p1", Types.CARD_LIGHTNING, ["p2"])["state"]
	var s3: Dictionary = H.ok(self, s2, Types.make_action_react("p2", _iid(s2, "p2", Types.CARD_LAST_WISH)))
	assert_eq(s3["status"], Types.STATUS_FINISHED)
	assert_eq(s3["winners"], [], "los dos mueren: empate")


# --- Plazo (timeout) ------------------------------------------------------------

func test_timeout_passes_everyone_pending() -> void:
	var s: Dictionary = _state(4)
	for pid: String in ["p2", "p3", "p4"]:
		H.set_hand(s, pid, [Types.CARD_MAGIC_SHIELD])
	var s2: Dictionary = _cast(s, "p1", Types.CARD_LIGHTNING, ["p3"])["state"]
	assert_true(Reactions.needs_deadline(s2))
	assert_false(Reactions.is_expired(s2, 99999999), "sin plazo nunca vence")
	var timed: Dictionary = Reactions.set_deadline(s2, 1000, 15000)
	assert_eq(int(_re(s2)["deadline_ms"]), 0, "no muta la entrada")
	assert_eq(int(_re(timed)["deadline_ms"]), 16000)
	assert_false(Reactions.needs_deadline(timed))
	assert_false(Reactions.is_expired(timed, 15999))
	assert_true(Reactions.is_expired(timed, 16000))
	var acts: Array = Reactions.timeout_actions(timed)
	assert_eq(acts.size(), 3)
	var cur: Dictionary = timed
	for a: Variant in acts:
		assert_eq((a as Dictionary)["type"], Types.ACTION_PASS_REACTION)
		cur = H.ok(self, cur, a as Dictionary)
	assert_true(_re(cur).is_empty())
	assert_eq(_hp(cur, "p3"), 8, "como si todos pasaran")
	assert_eq(Types.validate_state(cur), [] as Array[String])


func test_deadline_resets_after_react() -> void:
	var s: Dictionary = _state(3)
	H.set_hand(s, "p2", [Types.CARD_MAGIC_SHIELD])
	H.set_hand(s, "p3", [Types.CARD_MAGIC_SHIELD])
	var s2: Dictionary = Reactions.set_deadline(_cast(s, "p1", Types.CARD_LIGHTNING, ["p2"])["state"], 0, 5000)
	s2 = H.ok(self, s2, Types.make_action_pass_reaction("p2"))
	assert_eq(int(_re(s2)["deadline_ms"]), 5000, "pasar no reinicia el plazo")
	s2 = H.ok(self, s2, Types.make_action_react("p3", _iid(s2, "p3", Types.CARD_MAGIC_SHIELD), ["p2"]))
	assert_true(_re(s2).is_empty() or Reactions.needs_deadline(s2))


# --- Orden con 4-6 jugadores ---------------------------------------------------

func test_order_with_4_to_6_players() -> void:
	for n: int in [4, 5, 6]:
		var s: Dictionary = _state(n)
		for i: int in range(2, n + 1):
			H.set_hand(s, "p%d" % i, [Types.CARD_MAGIC_SHIELD])
		H.set_hand(s, "p1", [Types.CARD_LIGHTNING, Types.CARD_MAGIC_SHIELD])
		var s2: Dictionary = H.ok(self, s, Types.make_action_play_card("p1", _iid(s, "p1", Types.CARD_LIGHTNING), ["p3"]))
		var expected: Array = []
		for k: int in n:
			expected.append("p%d" % (posmod(2 + k, n) + 1))
		assert_eq(_re(s2)["awaiting"], expected, "n=%d: objetivo primero y luego horario" % n)
		# Respetan el orden uno a uno.
		var cur: Dictionary = s2
		for pid: Variant in expected:
			for other: Variant in expected:
				if other != pid and (_re(cur)["awaiting"] as Array).has(other):
					assert_eq(H.err(cur, Types.make_action_pass_reaction(String(other))), Types.ERR_NOT_YOUR_DECISION)
			cur = H.ok(self, cur, Types.make_action_pass_reaction(String(pid)))
		assert_true(_re(cur).is_empty())
		assert_eq(_hp(cur, "p3"), 8)


func test_order_skips_eliminated_and_unable() -> void:
	var s: Dictionary = _state(6)
	for i: int in range(1, 7):
		H.set_hand(s, "p%d" % i, [Types.CARD_MAGIC_SHIELD])
	H.set_hand(s, "p5", [])  # no puede responder
	var p6: Dictionary = H.player(s, "p6")
	p6["eliminated"] = true
	p6["hp"] = 0
	var iids: Array = H.set_hand(s, "p1", [Types.CARD_LIGHTNING, Types.CARD_MAGIC_SHIELD])
	var s2: Dictionary = H.ok(self, s, Types.make_action_play_card("p1", int(iids[0]), ["p4"]))
	assert_eq(_re(s2)["awaiting"], ["p4", "p1", "p2", "p3"])


func test_order_area_spell_starts_after_caster() -> void:
	var s: Dictionary = _state(5)
	for i: int in range(1, 6):
		H.set_hand(s, "p%d" % i, [Types.CARD_MAGIC_SHIELD])
	H.force_turn(s, "p3")
	var iids: Array = H.set_hand(s, "p3", [Types.CARD_ELECTRIC_EXPLOSION, Types.CARD_FIRE_ARROW, Types.CARD_MAGIC_SHIELD])
	var s2: Dictionary = H.ok(self, s, Types.make_action_play_card("p3", int(iids[0]), [], [int(iids[1])]))
	assert_eq(_re(s2)["awaiting"], ["p4", "p5", "p1", "p2", "p3"])


# --- Ventana huérfana y JSON ------------------------------------------------------

func test_orphan_window_closes_when_last_responder_is_eliminated() -> void:
	var s: Dictionary = _state(3)
	H.set_hand(s, "p2", [Types.CARD_MAGIC_SHIELD])
	var s2: Dictionary = _cast(s, "p1", Types.CARD_LIGHTNING, ["p3"])["state"]
	assert_eq(_re(s2)["awaiting"], ["p2"])
	H.player(s2, "p2")["potions"] = 10
	s2 = H.ok(self, s2, Types.make_action_drink_potion("p2"))  # Too Much Mana
	assert_true(bool(H.player(s2, "p2")["eliminated"]))
	# Desde la estabilización de T4, Game._finalize llama a Reactions.sync: la
	# ventana huérfana se cierra en la misma acción y el hechizo se resuelve.
	assert_true(_re(s2).is_empty())
	assert_eq(_hp(s2, "p3"), 8)
	assert_eq(H.err(s2, Types.make_action_pass_reaction("p3")), Types.ERR_NO_REACTION)


func test_sync_closes_orphan_window() -> void:
	var s: Dictionary = _state(3)
	H.set_hand(s, "p2", [Types.CARD_MAGIC_SHIELD])
	var s2: Dictionary = _cast(s, "p1", Types.CARD_LIGHTNING, ["p3"])["state"]
	H.player(s2, "p2")["eliminated"] = true
	var events: Array = []
	var r: Dictionary = Reactions.sync(s2, events)
	assert_eq(r["error"], "")
	assert_true(_re(s2).is_empty())
	assert_eq(_hp(s2, "p3"), 8)


func test_json_roundtrip_with_stack() -> void:
	var s: Dictionary = _state(3)
	H.set_hand(s, "p2", [Types.CARD_MAGIC_SHIELD])
	H.set_hand(s, "p3", [Types.CARD_MAGIC_SHIELD])
	var s2: Dictionary = _cast(s, "p1", Types.CARD_LIGHTNING, ["p2"])["state"]
	s2 = H.ok(self, s2, Types.make_action_react("p2", _iid(s2, "p2", Types.CARD_MAGIC_SHIELD), ["p2"]))
	assert_eq((_re(s2)["stack"] as Array).size(), 1)
	var back: Dictionary = H.json_roundtrip(s2)
	assert_eq(back, s2)
	assert_eq(Types.validate_state(back), [] as Array[String])
	var s3: Dictionary = H.ok(self, back, Types.make_action_pass_reaction("p3"))
	assert_eq(_hp(s3, "p2"), 10)


# --- Extensión: Lightning encadenado (falso) --------------------------------------

class FakeChain:
	static func can_respond(state: Dictionary, ctx: Dictionary) -> Dictionary:
		var prev: Dictionary = ctx["responding_to"]
		var prev_id: String = String((prev["card"] as Dictionary)["card_id"])
		var me: String = ctx["caster"]
		if prev_id == Types.CARD_LIGHTNING and (prev["targets"] as Array).has(me):
			var t: String = (ctx["targets"] as Array)[0]
			if t == me:
				ctx["error"] = Types.ERR_INVALID_TARGET
			else:
				ctx["ok"] = true
		return state

	static func _bonus(sp: Dictionary) -> int:
		return int((sp["data"] as Dictionary).get("damage_bonus", 0))

	static func lightning(state: Dictionary, ctx: Dictionary) -> Dictionary:
		var me: Dictionary = ctx["spell"]
		if bool(ctx["is_response"]):
			var prev: Dictionary = Reactions.find_spell(state, int((me["data"] as Dictionary)["responds_to"]))
			if prev.is_empty() or bool(prev["cancelled"]):
				return state
			(prev["data"] as Dictionary)["damage_bonus"] = _bonus(prev) + 1 + _bonus(me)
			prev["targets"] = (me["targets"] as Array).duplicate()
			return state
		var card: Dictionary = ctx["card"]
		for t: Variant in ctx["targets"]:
			Damage.apply(state, Types.make_mod_event("damage", 2 + _bonus(me), String(ctx["caster"]), String(t),
				Types.ELEMENT_ELECTRIC, Types.CARD_LIGHTNING, int(card["iid"]), true), ctx["events"])
		return state


func _register_fake_chain() -> void:
	EffectRegistry.register(Types.CARD_LIGHTNING, Callable(FakeChain, "lightning"))
	EffectRegistry.register_hook(Reactions.HOOK_CAN_RESPOND, Types.CARD_LIGHTNING, Callable(FakeChain, "can_respond"))


func test_fake_lightning_chain_extension() -> void:
	_register_fake_chain()
	var s: Dictionary = _state(4)
	H.set_hand(s, "p2", [Types.CARD_LIGHTNING])
	H.set_hand(s, "p3", [Types.CARD_LIGHTNING])
	var s2: Dictionary = _cast(s, "p1", Types.CARD_LIGHTNING, ["p2"])["state"]
	assert_eq(_re(s2)["awaiting"], ["p2"], "solo el objetivo de un Lightning puede encadenar")
	var l2: int = _iid(s2, "p2", Types.CARD_LIGHTNING)
	assert_eq(H.err(s2, Types.make_action_react("p2", l2, ["p2"])), Types.ERR_INVALID_TARGET)
	var legal: Array = Reactions.legal_actions(s2, "p2")
	assert_eq(legal.size(), 1 + 3, "PASS + encadenar hacia p1, p3 o p4")
	s2 = H.ok(self, s2, Types.make_action_react("p2", l2, ["p3"]))
	assert_eq(_re(s2)["awaiting"], ["p3"], "el nuevo objetivo decide primero")
	s2 = H.ok(self, s2, Types.make_action_react("p3", _iid(s2, "p3", Types.CARD_LIGHTNING), ["p4"]))
	assert_true(_re(s2).is_empty(), "p4 no tiene Lightning: se cierra")
	assert_eq(_hp(s2, "p2"), 10)
	assert_eq(_hp(s2, "p3"), 10)
	assert_eq(_hp(s2, "p4"), 6, "2 + 1 por cada eslabón")
	assert_eq(Types.validate_state(s2), [] as Array[String])


func test_fake_lightning_chain_cannot_target_force_field() -> void:
	_register_fake_chain()
	var s: Dictionary = _state(4)
	H.set_hand(s, "p2", [Types.CARD_LIGHTNING])
	(H.player(s, "p3")["flags"] as Dictionary)["force_field"] = "p3"
	var s2: Dictionary = _cast(s, "p1", Types.CARD_LIGHTNING, ["p2"])["state"]
	var l2: int = _iid(s2, "p2", Types.CARD_LIGHTNING)
	assert_eq(H.err(s2, Types.make_action_react("p2", l2, ["p3"])), Types.ERR_TARGET_IMMUNE)
	assert_eq(Reactions.legal_actions(s2, "p2").size(), 1 + 2, "p3 excluido")

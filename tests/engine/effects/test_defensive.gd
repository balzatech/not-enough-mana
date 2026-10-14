extends GutTest
## T6b: efectos de las defensivas y Force Field, jugadas a través de la ventana
## de reacción. Catálogo real; ofensivos falsos de engine_helpers
## (Lightning = 2, Ice Boomerang = 3).

const H = preload("res://tests/fixtures/engine_helpers.gd")


func before_each() -> void:
	CardCatalog.load_json()
	EffectRegistry.reset()
	H.register_fake_effects()


func after_all() -> void:
	EffectRegistry.reset()
	CardCatalog.load_json()


## n jugadores con 10💖, `mana`💧, manos vacías y mazo sin eventos; turno de p1.
func _state(n: int, mana: int = 10) -> Dictionary:
	var s: Dictionary = Types.make_state({}, 23)
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
	return H.ok(self, s, Types.make_action_play_card(caster, int(iids[0]), targets, iids.slice(1)))


func _iid(s: Dictionary, pid: String, card_id: String) -> int:
	for c: Variant in H.hand(s, pid):
		if String((c as Dictionary)["card_id"]) == card_id:
			return int((c as Dictionary)["iid"])
	return -1


func _hp(s: Dictionary, pid: String) -> int:
	return int(H.player(s, pid)["hp"])


func _re(s: Dictionary) -> Dictionary:
	return s["reaction"]


func _discard_iids(s: Dictionary) -> Array:
	var out: Array = []
	for c: Variant in s["discard"]:
		out.append(int((c as Dictionary)["iid"]))
	return out


# --- Magic Shield / Frozen Bunny ------------------------------------------------

func test_magic_shield_on_another_wizard_prevents_2() -> void:
	var s: Dictionary = _state(3)
	H.set_hand(s, "p3", [Types.CARD_MAGIC_SHIELD])
	var s2: Dictionary = _cast(s, "p1", Types.CARD_ICE_BOOMERANG, ["p2"])
	assert_eq(_re(s2)["awaiting"], ["p3"])
	s2 = H.ok(self, s2, Types.make_action_react("p3", _iid(s2, "p3", Types.CARD_MAGIC_SHIELD), ["p2"]))
	assert_true(_re(s2).is_empty())
	assert_eq(_hp(s2, "p2"), 9, "3 - 2")
	assert_eq(int(H.player(s2, "p3")["mana"]), 8)
	assert_eq((s2["modifiers"] as Array).size(), 0)
	assert_eq(Types.validate_state(s2), [] as Array[String])


func test_magic_shield_only_affects_that_spell() -> void:
	var s: Dictionary = _state(3)
	H.set_hand(s, "p2", [Types.CARD_MAGIC_SHIELD])
	var s2: Dictionary = _cast(s, "p1", Types.CARD_LIGHTNING, ["p2"])
	s2 = H.ok(self, s2, Types.make_action_react("p2", _iid(s2, "p2", Types.CARD_MAGIC_SHIELD), ["p2"]))
	assert_eq(_hp(s2, "p2"), 10)
	s2 = _cast(s2, "p1", Types.CARD_LIGHTNING, ["p2"])
	assert_eq(_hp(s2, "p2"), 8, "el escudo caducó con el hechizo anterior")


func test_frozen_bunny_prevents_all() -> void:
	var s: Dictionary = _state(3)
	H.set_hand(s, "p2", [Types.CARD_FROZEN_BUNNY, Types.CARD_ICE_BOLT])
	var s2: Dictionary = _cast(s, "p1", Types.CARD_ICE_BOOMERANG, ["p2"])
	var bunny: int = _iid(s2, "p2", Types.CARD_FROZEN_BUNNY)
	assert_eq(H.err(s2, Types.make_action_react("p2", bunny, ["p2"])), Types.ERR_INVALID_PAYMENT)
	s2 = H.ok(self, s2, Types.make_action_react("p2", bunny, ["p2"], [_iid(s2, "p2", Types.CARD_ICE_BOLT)]))
	assert_eq(_hp(s2, "p2"), 10)
	assert_eq(int(H.player(s2, "p2")["mana"]), 10, "sin coste de maná")


func test_defensive_effect_outside_window_errors() -> void:
	var s: Dictionary = _state(3)
	var card: Dictionary = Types.make_card_instance(9999, Types.CARD_MAGIC_SHIELD)
	var ctx: Dictionary = Types.make_effect_ctx(card, CardCatalog.get_def(Types.CARD_MAGIC_SHIELD), "p1", ["p1"])
	DefensiveEffects.magic_shield(s, ctx)
	assert_eq(ctx["error"], Types.ERR_CARD_NOT_PLAYABLE)


# --- Mirror Shield ------------------------------------------------------------

func test_mirror_shield_protecting_other_wizard() -> void:
	var s: Dictionary = _state(4)
	H.set_hand(s, "p3", [Types.CARD_MIRROR_SHIELD, Types.CARD_LAST_WISH])
	var s2: Dictionary = _cast(s, "p1", Types.CARD_ICE_BOOMERANG, ["p2"])
	var ms: int = _iid(s2, "p3", Types.CARD_MIRROR_SHIELD)
	var pay: int = _iid(s2, "p3", Types.CARD_LAST_WISH)
	var legal: Array = Reactions.legal_actions(s2, "p3")
	var found: bool = false
	for a: Variant in legal:
		var ad: Dictionary = a
		if ad.get("card", -1) == ms and (ad["extra"] as Dictionary).get("protect", "") == "p2" and ad["targets"] == ["p1"]:
			found = true
	assert_true(found, "legal_actions ofrece proteger al objetivo")
	s2 = H.ok(self, s2, Types.make_action_react("p3", ms, ["p1"], [pay], {"protect": "p2"}))
	assert_eq(_hp(s2, "p2"), 9, "3 - 2 redirigidos")
	assert_eq(_hp(s2, "p1"), 8, "el lanzador recibe los 2")
	assert_eq(_hp(s2, "p3"), 10)


func test_mirror_shield_towards_force_field_is_illegal() -> void:
	var s: Dictionary = _state(3)
	(H.player(s, "p3")["flags"] as Dictionary)["force_field"] = "p3"
	H.set_hand(s, "p2", [Types.CARD_MIRROR_SHIELD, Types.CARD_MAGIC_SHIELD])
	var s2: Dictionary = _cast(s, "p1", Types.CARD_LIGHTNING, ["p2"])
	var ms: int = _iid(s2, "p2", Types.CARD_MIRROR_SHIELD)
	var pay: int = _iid(s2, "p2", Types.CARD_MAGIC_SHIELD)
	assert_eq(H.err(s2, Types.make_action_react("p2", ms, ["p3"], [pay])), Types.ERR_TARGET_IMMUNE)


# --- Magic Capture ------------------------------------------------------------

func test_magic_capture_steals_top_of_discard() -> void:
	var s: Dictionary = _state(3)
	var top: Dictionary = H._take_any(s, Types.CARD_FIREBALL)
	(s["discard"] as Array).append(top)
	H.set_hand(s, "p2", [Types.CARD_MAGIC_CAPTURE, Types.CARD_MAGIC_SHIELD])
	var s2: Dictionary = _cast(s, "p1", Types.CARD_LIGHTNING, ["p3"])
	var mc: int = _iid(s2, "p2", Types.CARD_MAGIC_CAPTURE)
	var pay: int = _iid(s2, "p2", Types.CARD_MAGIC_SHIELD)
	s2 = H.ok(self, s2, Types.make_action_react("p2", mc, [], [pay]))
	assert_true(_re(s2).is_empty())
	var hand: Array = H.hand(s2, "p2")
	assert_eq(hand.size(), 1)
	assert_eq(int((hand[0] as Dictionary)["iid"]), int(top["iid"]), "no recupera su propio pago")
	assert_true(_discard_iids(s2).has(pay))
	assert_true(_discard_iids(s2).has(mc))
	assert_eq(_hp(s2, "p3"), 8)
	assert_eq(Types.validate_state(s2), [] as Array[String])


# --- Annihilation sobre cartas en mesa ---------------------------------------------

func test_annihilation_on_artifact_removes_its_modifiers() -> void:
	var s: Dictionary = _state(3)
	var wf: Dictionary = H._take_any(s, Types.CARD_WILD_FIRE)
	var wiid: int = wf["iid"]
	(H.player(s, "p3")["artifacts"] as Array).append(Types.make_table_card(wiid, Types.CARD_WILD_FIRE, "p3"))
	Modifiers.add(s, Types.make_modifier("wild_fire#%d" % wiid, Types.STAGE_OUTGOING, Types.OP_ADD, 1, "p3",
		Types.SIDE_SOURCE, Types.ELEMENT_FIRE, Types.EXPIRES_WHILE_IN_PLAY, Types.CARD_WILD_FIRE, wiid))
	H.set_hand(s, "p2", [Types.CARD_ANNIHILATION, Types.CARD_FIRE_ARROW])
	var s2: Dictionary = _cast(s, "p1", Types.CARD_LIGHTNING, ["p3"])
	var legal: Array = Reactions.legal_actions(s2, "p2")
	var targets: Array = []
	for a: Variant in legal:
		var ad: Dictionary = a
		if ad["type"] == Types.ACTION_REACT:
			targets.append(int(ad["target_card"]))
	assert_true(targets.has(wiid), "puede anular el artefacto")
	assert_true(targets.has(int(((_re(s2)["spell"] as Dictionary)["card"] as Dictionary)["iid"])), "o el hechizo")
	s2 = H.ok(self, s2, Types.make_action_react("p2", _iid(s2, "p2", Types.CARD_ANNIHILATION), [],
		[_iid(s2, "p2", Types.CARD_FIRE_ARROW)], {}, wiid))
	assert_eq((H.player(s2, "p3")["artifacts"] as Array).size(), 0)
	assert_true(_discard_iids(s2).has(wiid))
	assert_eq((s2["modifiers"] as Array).size(), 0)
	assert_eq(_hp(s2, "p3"), 8, "el Lightning sigue")
	assert_eq(Types.validate_state(s2), [] as Array[String])


func test_annihilation_on_active_event() -> void:
	var s: Dictionary = _state(3)
	var ev: Dictionary = H._take_any(s, Types.CARD_SHOT_GLASS)
	if ev.is_empty():
		ev = Types.make_card_instance(int(s["card_total"]) + 500, Types.CARD_SHOT_GLASS)
		s["card_total"] = int(s["card_total"]) + 1
	var eiid: int = ev["iid"]
	s["active_event"] = Types.make_table_card(eiid, Types.CARD_SHOT_GLASS, "")
	Modifiers.add(s, Types.make_modifier("shot_glass#%d" % eiid, Types.STAGE_POTION, Types.OP_SUB, 1, "",
		Types.SIDE_ANY, "", Types.EXPIRES_NEXT_EVENT, Types.CARD_SHOT_GLASS, eiid))
	H.set_hand(s, "p2", [Types.CARD_ANNIHILATION, Types.CARD_FIRE_ARROW])
	var s2: Dictionary = _cast(s, "p1", Types.CARD_LIGHTNING, ["p3"])
	s2 = H.ok(self, s2, Types.make_action_react("p2", _iid(s2, "p2", Types.CARD_ANNIHILATION), [],
		[_iid(s2, "p2", Types.CARD_FIRE_ARROW)], {}, eiid))
	assert_true((s2["active_event"] as Dictionary).is_empty())
	assert_eq((s2["modifiers"] as Array).size(), 0)
	assert_true(_discard_iids(s2).has(eiid))
	assert_eq(Types.validate_state(s2), [] as Array[String])


# --- Force Field ----------------------------------------------------------------

func test_force_field_grants_immunity_until_caster_turn() -> void:
	var s: Dictionary = _state(3)
	var s2: Dictionary = _cast(s, "p1", Types.CARD_FORCE_FIELD, ["p2"], [Types.CARD_MAGIC_SHIELD])
	assert_true(_re(s2).is_empty(), "nadie puede responder: se resuelve")
	assert_eq((H.player(s2, "p2")["flags"] as Dictionary)["force_field"], "p1")
	var iids: Array = H.set_hand(s2, "p1", [Types.CARD_LIGHTNING])
	assert_eq(H.err(s2, Types.make_action_play_card("p1", int(iids[0]), ["p2"])), Types.ERR_TARGET_IMMUNE)
	s2 = H.ok(self, s2, Types.make_action_end_turn("p1"))
	assert_eq((H.player(s2, "p2")["flags"] as Dictionary)["force_field"], "p1", "sigue en turnos ajenos")
	s2 = H.ok(self, s2, Types.make_action_end_turn("p2"))
	s2 = H.ok(self, s2, Types.make_action_end_turn("p3"))
	assert_eq((s2["turn"] as Dictionary)["current"], "p1")
	assert_eq((H.player(s2, "p2")["flags"] as Dictionary)["force_field"], "", "caduca en el turno del lanzador")


func test_force_field_can_be_annihilated_in_flight() -> void:
	var s: Dictionary = _state(3)
	H.set_hand(s, "p3", [Types.CARD_ANNIHILATION, Types.CARD_FIREBALL])
	var s2: Dictionary = _cast(s, "p1", Types.CARD_FORCE_FIELD, ["p2"], [Types.CARD_MAGIC_SHIELD])
	assert_eq(_re(s2)["awaiting"], ["p3"])
	var ff: int = int(((_re(s2)["spell"] as Dictionary)["card"] as Dictionary)["iid"])
	s2 = H.ok(self, s2, Types.make_action_react("p3", _iid(s2, "p3", Types.CARD_ANNIHILATION), [],
		[_iid(s2, "p3", Types.CARD_FIREBALL)], {}, ff))
	assert_eq((H.player(s2, "p2")["flags"] as Dictionary)["force_field"], "")
	assert_true(_discard_iids(s2).has(ff))


func test_force_field_does_not_block_defensives() -> void:
	# Lectura literal: Force Field bloquea "spells"; las defensivas tienen is_spell=false.
	var s: Dictionary = _state(3)
	(H.player(s, "p3")["flags"] as Dictionary)["force_field"] = "p3"
	H.set_hand(s, "p2", [Types.CARD_MAGIC_SHIELD])
	var s2: Dictionary = _cast(s, "p1", Types.CARD_LIGHTNING, ["p2"])
	assert_eq(H.err(s2, Types.make_action_react("p2", _iid(s2, "p2", Types.CARD_MAGIC_SHIELD), ["p3"])), "")

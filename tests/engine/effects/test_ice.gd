extends NemTest
## T6a: efectos de hielo (Ice Bolt, Blizzard, Ice Boomerang, Vampiric Touch,
## Freeze, Icy Grasp) con el catálogo real.

const OH = preload("res://tests/engine/effects/offensive_helpers.gd")
const H = preload("res://tests/fixtures/engine_helpers.gd")

var s: Dictionary


func before_each() -> void:
	super.before_each()
	CardCatalog.load_json()
	EffectRegistry.reset()
	s = OH.make_state(4)


func after_all() -> void:
	EffectRegistry.reset()
	CardCatalog.load_json()


func _ok(r: Dictionary) -> void:
	assert_eq(r["error"], Types.ERR_NONE)
	assert_eq(Types.validate_state(s), [] as Array[String])


func _hand_size(pid: String) -> int:
	return H.hand(s, pid).size()


func test_ice_cards_registered() -> void:
	for id: String in [Types.CARD_ICE_BOLT, Types.CARD_BLIZZARD, Types.CARD_ICE_BOOMERANG,
			Types.CARD_VAMPIRIC_TOUCH, Types.CARD_FREEZE, Types.CARD_ICY_GRASP]:
		assert_true(EffectRegistry.has_effect(id), id)


func test_ice_damage_uses_ice_element_and_modifiers() -> void:
	OH.add_mod(s, "fake_ice_storm", Types.STAGE_OUTGOING, Types.OP_ADD, 1, Types.ELEMENT_ICE)
	OH.add_mod(s, "fake_boots", Types.STAGE_INCOMING, Types.OP_SUB, 1, Types.ELEMENT_FIRE,
		Types.SIDE_TARGET, "p2")
	var r: Dictionary = OH.cast(s, "p1", Types.CARD_ICE_BOOMERANG, ["p2"])
	_ok(r)
	assert_eq(OH.hp(s, "p2"), 6, "3 +1 (hielo); la reducción de fuego no aplica")
	assert_eq(OH.hp(s, "p1"), 8, "1 +1 (el bono de hielo también afecta al rebote)")
	for e: Variant in OH.events_of(r["events"], Types.LOG_DAMAGE):
		assert_eq((e as Dictionary)["data"]["element"], Types.ELEMENT_ICE)


# --- Ice Bolt --------------------------------------------------------------

func test_ice_bolt_base_with_choice() -> void:
	H.set_hand(s, "p2", [Types.CARD_FIRE_ARROW, Types.CARD_HEAL])
	_ok(OH.cast(s, "p1", Types.CARD_ICE_BOLT, ["p2"]))
	assert_eq(OH.hp(s, "p2"), 9)
	var prs: Array = OH.prompts(s, "p2", Types.PROMPT_DISCARD)
	assert_eq(prs.size(), 1)
	assert_eq((prs[0] as Dictionary)["data"]["count"], 1)
	assert_eq((prs[0] as Dictionary)["source"], Types.CARD_ICE_BOLT)


func test_ice_bolt_single_card_auto_discard() -> void:
	H.set_hand(s, "p2", [Types.CARD_FIRE_ARROW])
	_ok(OH.cast(s, "p1", Types.CARD_ICE_BOLT, ["p2"]))
	assert_eq(_hand_size("p2"), 0)
	assert_eq(OH.prompts(s, "p2", Types.PROMPT_DISCARD).size(), 0)


func test_ice_bolt_empty_hand_loses_mana() -> void:
	_ok(OH.cast(s, "p1", Types.CARD_ICE_BOLT, ["p2"]))
	assert_eq(OH.mana(s, "p2"), 9)


func test_ice_bolt_self() -> void:
	H.set_hand(s, "p1", [Types.CARD_FIRE_ARROW])
	_ok(OH.cast(s, "p1", Types.CARD_ICE_BOLT, ["p1"]))
	assert_eq(OH.hp(s, "p1"), 9)
	assert_eq(_hand_size("p1"), 0)


func test_ice_bolt_eliminated_target() -> void:
	OH.kill(s, "p2")
	assert_eq(OH.play_error(s, "p1", Types.CARD_ICE_BOLT, ["p2"]), Types.ERR_INVALID_TARGET)
	_ok(OH.cast(s, "p1", Types.CARD_ICE_BOLT, ["p2"]))
	assert_eq(OH.prompts(s, "p2", Types.PROMPT_DISCARD).size(), 0)
	assert_eq(OH.mana(s, "p2"), 10)


func test_ice_bolt_kills_no_discard_prompt() -> void:
	H.set_hand(s, "p2", [Types.CARD_FIRE_ARROW, Types.CARD_HEAL])
	OH.set_hp(s, "p2", 1)
	_ok(OH.cast(s, "p1", Types.CARD_ICE_BOLT, ["p2"]))
	assert_true(OH.eliminated(s, "p2"))
	assert_eq(OH.prompts(s, "p2", Types.PROMPT_DISCARD).size(), 0)
	assert_eq(_hand_size("p2"), 0, "la mano del eliminado va al descarte")


# --- Blizzard ----------------------------------------------------------------

func test_blizzard_base() -> void:
	for pid: String in ["p1", "p2", "p3", "p4"]:
		H.set_hand(s, pid, [Types.CARD_FIRE_ARROW])
	_ok(OH.cast(s, "p1", Types.CARD_BLIZZARD, ["p3"]))
	assert_eq(OH.hp(s, "p3"), 9)
	assert_eq(OH.hp(s, "p2"), 9)
	assert_eq(OH.hp(s, "p4"), 9)
	assert_eq(OH.hp(s, "p1"), 10)
	assert_eq(_hand_size("p3"), 0)
	assert_eq(_hand_size("p2"), 0)
	assert_eq(_hand_size("p4"), 0)
	assert_eq(_hand_size("p1"), 1)


func test_blizzard_self_hits_caster_and_neighbors() -> void:
	_ok(OH.cast(s, "p1", Types.CARD_BLIZZARD, ["p1"]))
	assert_eq(OH.hp(s, "p1"), 9)
	assert_eq(OH.hp(s, "p2"), 9)
	assert_eq(OH.hp(s, "p4"), 9)
	assert_eq(OH.hp(s, "p3"), 10)
	assert_eq(OH.mana(s, "p1"), 9, "sin cartas: pierde 1 maná")


func test_blizzard_skips_eliminated_neighbors() -> void:
	OH.kill(s, "p4")
	_ok(OH.cast(s, "p2", Types.CARD_BLIZZARD, ["p3"]))
	assert_eq(OH.hp(s, "p3"), 9)
	assert_eq(OH.hp(s, "p2"), 9)
	assert_eq(OH.hp(s, "p1"), 9, "p1 es vecino de p3 al faltar p4")
	assert_eq(OH.mana(s, "p4"), 10)


func test_blizzard_eliminated_target() -> void:
	OH.kill(s, "p3")
	assert_eq(OH.play_error(s, "p1", Types.CARD_BLIZZARD, ["p3"]), Types.ERR_INVALID_TARGET)
	_ok(OH.cast(s, "p1", Types.CARD_BLIZZARD, ["p3"]))
	assert_eq(OH.hp(s, "p2"), 10)
	assert_eq(OH.hp(s, "p4"), 10)


func test_blizzard_kills_neighbor_who_does_not_discard() -> void:
	H.set_hand(s, "p2", [Types.CARD_FIRE_ARROW, Types.CARD_HEAL])
	H.set_hand(s, "p4", [Types.CARD_FIRE_ARROW, Types.CARD_HEAL])
	OH.set_hp(s, "p2", 1)
	_ok(OH.cast(s, "p1", Types.CARD_BLIZZARD, ["p3"]))
	assert_true(OH.eliminated(s, "p2"))
	assert_eq(OH.prompts(s, "p2", Types.PROMPT_DISCARD).size(), 0)
	assert_eq(OH.prompts(s, "p4", Types.PROMPT_DISCARD).size(), 1)
	assert_eq(OH.mana(s, "p3"), 9)


func test_blizzard_neighbor_with_force_field() -> void:
	OH.flags(s, "p2")["force_field"] = "p2"
	_ok(OH.cast(s, "p1", Types.CARD_BLIZZARD, ["p3"]))
	assert_eq(OH.hp(s, "p2"), 10)
	assert_eq(OH.mana(s, "p2"), 10, "inmune: tampoco descarta")
	assert_eq(OH.hp(s, "p4"), 9)


# --- Ice Boomerang ----------------------------------------------------------------

func test_ice_boomerang_base() -> void:
	_ok(OH.cast(s, "p1", Types.CARD_ICE_BOOMERANG, ["p2"]))
	assert_eq(OH.hp(s, "p2"), 7)
	assert_eq(OH.hp(s, "p1"), 9)


func test_ice_boomerang_self() -> void:
	_ok(OH.cast(s, "p1", Types.CARD_ICE_BOOMERANG, ["p1"]))
	assert_eq(OH.hp(s, "p1"), 6)


func test_ice_boomerang_eliminated_target() -> void:
	OH.kill(s, "p2")
	assert_eq(OH.play_error(s, "p1", Types.CARD_ICE_BOOMERANG, ["p2"]), Types.ERR_INVALID_TARGET)
	_ok(OH.cast(s, "p1", Types.CARD_ICE_BOOMERANG, ["p2"]))
	assert_eq(OH.hp(s, "p1"), 10, "sin objetivo no hay rebote")


func test_ice_boomerang_kills_target_and_caster() -> void:
	OH.set_hp(s, "p2", 3)
	OH.set_hp(s, "p1", 1)
	_ok(OH.cast(s, "p1", Types.CARD_ICE_BOOMERANG, ["p2"]))
	assert_true(OH.eliminated(s, "p2"))
	assert_true(OH.eliminated(s, "p1"))


# --- Vampiric Touch ----------------------------------------------------------------

func test_vampiric_touch_base() -> void:
	OH.set_hp(s, "p1", 5)
	_ok(OH.cast(s, "p1", Types.CARD_VAMPIRIC_TOUCH, ["p2"]))
	assert_eq(OH.hp(s, "p2"), 8)
	assert_eq(OH.hp(s, "p1"), 6)


func test_vampiric_touch_heal_capped_at_max() -> void:
	_ok(OH.cast(s, "p1", Types.CARD_VAMPIRIC_TOUCH, ["p2"]))
	assert_eq(OH.hp(s, "p1"), 10)


func test_vampiric_touch_heals_even_if_damage_prevented() -> void:
	OH.set_hp(s, "p1", 5)
	OH.add_mod(s, "fake_shield", Types.STAGE_PREVENT, Types.OP_PREVENT_ALL, 0, "", Types.SIDE_TARGET, "p2")
	_ok(OH.cast(s, "p1", Types.CARD_VAMPIRIC_TOUCH, ["p2"]))
	assert_eq(OH.hp(s, "p2"), 10)
	assert_eq(OH.hp(s, "p1"), 6)


func test_vampiric_touch_self() -> void:
	_ok(OH.cast(s, "p1", Types.CARD_VAMPIRIC_TOUCH, ["p1"]))
	assert_eq(OH.hp(s, "p1"), 9)


func test_vampiric_touch_eliminated_target() -> void:
	OH.kill(s, "p2")
	OH.set_hp(s, "p1", 5)
	assert_eq(OH.play_error(s, "p1", Types.CARD_VAMPIRIC_TOUCH, ["p2"]), Types.ERR_INVALID_TARGET)
	_ok(OH.cast(s, "p1", Types.CARD_VAMPIRIC_TOUCH, ["p2"]))
	assert_eq(OH.hp(s, "p1"), 5)


func test_vampiric_touch_kills() -> void:
	OH.set_hp(s, "p2", 2)
	OH.set_hp(s, "p1", 5)
	_ok(OH.cast(s, "p1", Types.CARD_VAMPIRIC_TOUCH, ["p2"]))
	assert_true(OH.eliminated(s, "p2"))
	assert_eq(OH.hp(s, "p1"), 6)


func test_vampiric_touch_self_kill_no_heal() -> void:
	OH.set_hp(s, "p1", 2)
	_ok(OH.cast(s, "p1", Types.CARD_VAMPIRIC_TOUCH, ["p1"]))
	assert_true(OH.eliminated(s, "p1"))
	assert_eq(OH.hp(s, "p1"), 0)


# --- Freeze ----------------------------------------------------------------

func test_freeze_base_skips_next_turn() -> void:
	var r: Dictionary = OH.cast(s, "p1", Types.CARD_FREEZE, ["p2"])
	_ok(r)
	assert_eq(OH.flags(s, "p2")["frozen"], 1)
	assert_eq(OH.hp(s, "p2"), 10)
	var events: Array = []
	Game._end_turn(s, "p1", events)
	assert_eq((s["turn"] as Dictionary)["current"], "p3", "p2 pierde su turno")
	assert_eq(OH.flags(s, "p2")["frozen"], 0)
	assert_eq(OH.events_of(events, Types.LOG_TURN_SKIPPED).size(), 1)


func test_freeze_stacks() -> void:
	_ok(OH.cast(s, "p1", Types.CARD_FREEZE, ["p2"]))
	_ok(OH.cast(s, "p3", Types.CARD_FREEZE, ["p2"]))
	assert_eq(OH.flags(s, "p2")["frozen"], 2)


func test_freeze_self() -> void:
	_ok(OH.cast(s, "p1", Types.CARD_FREEZE, ["p1"]))
	assert_eq(OH.flags(s, "p1")["frozen"], 1)
	var events: Array = []
	Game._end_turn(s, "p1", events)
	for _i: int in 3:
		Game._end_turn(s, String((s["turn"] as Dictionary)["current"]), events)
	assert_eq((s["turn"] as Dictionary)["current"], "p2", "p1 se salta su siguiente turno")


func test_freeze_eliminated_target() -> void:
	OH.kill(s, "p2")
	assert_eq(OH.play_error(s, "p1", Types.CARD_FREEZE, ["p2"]), Types.ERR_INVALID_TARGET)
	var r: Dictionary = OH.cast(s, "p1", Types.CARD_FREEZE, ["p2"])
	_ok(r)
	assert_eq(OH.flags(s, "p2")["frozen"], 0)
	assert_eq(OH.events_of(r["events"], Types.LOG_EFFECT, "fizzled").size(), 1)


func test_freeze_does_not_kill_and_frozen_player_killed_later() -> void:
	# Freeze no hace daño: un objetivo a 1💖 sigue vivo. Si luego muere, su
	# turno se salta igualmente (no queda colgado por el flag).
	OH.set_hp(s, "p2", 1)
	_ok(OH.cast(s, "p1", Types.CARD_FREEZE, ["p2"]))
	assert_false(OH.eliminated(s, "p2"))
	_ok(OH.cast(s, "p1", Types.CARD_FIRE_ARROW, ["p2"]))
	assert_true(OH.eliminated(s, "p2"))
	var events: Array = []
	Game._end_turn(s, "p1", events)
	assert_eq((s["turn"] as Dictionary)["current"], "p3")


# --- Icy Grasp ----------------------------------------------------------------

func test_icy_grasp_base_steals_random_card() -> void:
	var iids: Array = H.set_hand(s, "p2", [Types.CARD_FIRE_ARROW, Types.CARD_HEAL, Types.CARD_FIREBALL])
	var rng_before: int = s["rng_state"]
	var r: Dictionary = OH.cast(s, "p1", Types.CARD_ICY_GRASP, ["p2"])
	_ok(r)
	assert_eq(OH.hp(s, "p2"), 8)
	assert_eq(_hand_size("p2"), 2)
	assert_eq(_hand_size("p1"), 1)
	var stolen: Dictionary = H.hand(s, "p1")[0]
	assert_true(iids.has(int(stolen["iid"])))
	assert_ne(int(s["rng_state"]), rng_before, "usa rng.gd")
	# Determinista: misma semilla → misma carta.
	var expected: int = int(Rng.next_int(rng_before, 3)["value"])
	assert_eq(int(stolen["iid"]), int(iids[expected]))


func test_icy_grasp_card_is_private() -> void:
	H.set_hand(s, "p2", [Types.CARD_BOOK_EXCHANGE])
	var r: Dictionary = OH.cast(s, "p1", Types.CARD_ICY_GRASP, ["p2"])
	_ok(r)
	Game._append_log(s, r["events"])
	# Reveal privado del ladrón.
	var priv: Dictionary = Types.private_view(s, "p1")
	var rev: Array = priv["reveals"]
	assert_eq(rev.size(), 1)
	assert_eq((rev[0] as Dictionary)["of"], "p2")
	assert_eq(((rev[0] as Dictionary)["cards"] as Array)[0]["card_id"], Types.CARD_BOOK_EXCHANGE)
	# La vista pública no menciona la carta.
	var pub: Dictionary = Types.public_view(s)
	assert_false(JSON.stringify(pub).contains(Types.CARD_BOOK_EXCHANGE), "la carta robada no es pública")
	assert_eq(OH.events_of(pub["log"] as Array, Types.LOG_EFFECT, "card_stolen").size(), 1)
	# p2 sabe qué perdió; p3 no.
	assert_true(JSON.stringify(Types.private_view(s, "p2")).contains(Types.CARD_BOOK_EXCHANGE))
	assert_false(JSON.stringify(Types.view_for(s, "p3")).contains(Types.CARD_BOOK_EXCHANGE))


func test_icy_grasp_can_decline_steal() -> void:
	H.set_hand(s, "p2", [Types.CARD_HEAL])
	_ok(OH.cast(s, "p1", Types.CARD_ICY_GRASP, ["p2"], {"steal": false}))
	assert_eq(OH.hp(s, "p2"), 8)
	assert_eq(_hand_size("p2"), 1)
	assert_eq(_hand_size("p1"), 0)


func test_icy_grasp_empty_hand() -> void:
	var r: Dictionary = OH.cast(s, "p1", Types.CARD_ICY_GRASP, ["p2"])
	_ok(r)
	assert_eq(OH.hp(s, "p2"), 8)
	assert_eq(_hand_size("p1"), 0)
	assert_eq(OH.events_of(r["events"], Types.LOG_EFFECT, "steal_empty").size(), 1)


func test_icy_grasp_self() -> void:
	H.set_hand(s, "p1", [Types.CARD_HEAL])
	_ok(OH.cast(s, "p1", Types.CARD_ICY_GRASP, ["p1"]))
	assert_eq(OH.hp(s, "p1"), 8)
	assert_eq(_hand_size("p1"), 1)
	assert_eq((s["reveals"] as Dictionary).size(), 0)


func test_icy_grasp_eliminated_target() -> void:
	OH.kill(s, "p2")
	assert_eq(OH.play_error(s, "p1", Types.CARD_ICY_GRASP, ["p2"]), Types.ERR_INVALID_TARGET)
	var before: int = _hand_size("p1")
	_ok(OH.cast(s, "p1", Types.CARD_ICY_GRASP, ["p2"]))
	assert_eq(_hand_size("p1"), before)


func test_icy_grasp_kills_nothing_to_steal() -> void:
	H.set_hand(s, "p2", [Types.CARD_HEAL, Types.CARD_FIREBALL])
	OH.set_hp(s, "p2", 2)
	_ok(OH.cast(s, "p1", Types.CARD_ICY_GRASP, ["p2"]))
	assert_true(OH.eliminated(s, "p2"))
	assert_eq(_hand_size("p1"), 0, "la mano del eliminado ya fue al descarte")

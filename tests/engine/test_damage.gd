extends NemTest
## T4: tubería de daño, maná, curación y pool (damage.gd).

const H = preload("res://tests/fixtures/engine_helpers.gd")

var s: Dictionary


func before_each() -> void:
	super.before_each()
	EffectRegistry.reset()
	H.use_fixture_catalog()
	s = H.game(3, {}, 9, [50, 40, 30])


func after_all() -> void:
	EffectRegistry.reset()
	CardCatalog.load_json()


func _fire(src: String, tgt: String, amount: int, spell_iid: int = 500) -> Dictionary:
	return Types.make_mod_event("damage", amount, src, tgt, Types.ELEMENT_FIRE, Types.CARD_FIREBALL, spell_iid, true)


func test_basic_damage_returns_crystals_to_pool() -> void:
	var pool0: int = (s["pool"] as Dictionary)["hp"]
	var ev: Array = []
	var out: Dictionary = Damage.resolve(s, _fire("p1", "p2", 2), ev)
	assert_eq(out["amount"], 2)
	assert_eq((out["data"] as Dictionary)["dealt"], 2)
	assert_eq(H.player(s, "p2")["hp"], 8)
	assert_eq((s["pool"] as Dictionary)["hp"], pool0 + 2)
	assert_eq((ev[0] as Dictionary)["type"], Types.LOG_DAMAGE)


func test_all_damage_stages_in_order() -> void:
	Modifiers.add(s, Types.make_modifier("wf", Types.STAGE_OUTGOING, Types.OP_ADD, 1, "p1", Types.SIDE_SOURCE, Types.ELEMENT_FIRE))
	Modifiers.add(s, Types.make_modifier("tiara", Types.STAGE_INCOMING, Types.OP_SUB, 1, "p2", Types.SIDE_TARGET, Types.ELEMENT_FIRE))
	var shield: Dictionary = Types.make_modifier("shield", Types.STAGE_PREVENT, Types.OP_SUB, 2, "p2", Types.SIDE_TARGET, "", Types.EXPIRES_SPELL)
	shield["spell_iid"] = 500
	Modifiers.add(s, shield)
	var mirror: Dictionary = Types.make_modifier("mirror", Types.STAGE_REDIRECT, Types.OP_REDIRECT, 2, "p2", Types.SIDE_TARGET, "", Types.EXPIRES_SPELL)
	mirror["spell_iid"] = 500
	mirror["data"] = {"to": "p3"}
	Modifiers.add(s, mirror)
	# 6 +1 -1 -2 = 4; 2 redirigidos a p3 → p2 recibe 2.
	var out: Dictionary = Damage.resolve(s, _fire("p1", "p2", 6), [])
	assert_eq(out["amount"], 2)
	assert_eq(H.player(s, "p2")["hp"], 8)
	assert_eq(H.player(s, "p3")["hp"], 8)
	assert_eq(out["applied"], ["wf", "tiara", "shield", "mirror"])


func test_redirected_damage_is_not_redirected_again() -> void:
	var m1: Dictionary = Types.make_modifier("m1", Types.STAGE_REDIRECT, Types.OP_REDIRECT, 2, "p2", Types.SIDE_TARGET)
	m1["data"] = {"to": "p3"}
	var m2: Dictionary = Types.make_modifier("m2", Types.STAGE_REDIRECT, Types.OP_REDIRECT, 2, "p3", Types.SIDE_TARGET)
	m2["data"] = {"to": "p2"}
	Modifiers.add(s, m1)
	Modifiers.add(s, m2)
	Damage.resolve(s, _fire("p1", "p2", 2), [])
	assert_eq(H.player(s, "p2")["hp"], 10)
	assert_eq(H.player(s, "p3")["hp"], 8)


func test_after_damage_custom_handler() -> void:
	EffectRegistry.register_modifier_handler("nem_test", func(st: Dictionary, _m: Dictionary, e: Dictionary) -> Dictionary:
		Damage.lose_mana(st, String(e["target"]), int(e["amount"]), [], "", "")
		return e)
	var m: Dictionary = Types.make_modifier("nem", Types.STAGE_AFTER_DAMAGE, Types.OP_CUSTOM, 0)
	m["handler"] = "nem_test"
	Modifiers.add(s, m)
	H.set_mana(s, "p2", 5)
	Damage.resolve(s, _fire("p1", "p2", 2), [])
	assert_eq(H.player(s, "p2")["mana"], 3)


func test_force_field_prevents_spell_damage_only() -> void:
	(H.player(s, "p2")["flags"] as Dictionary)["force_field"] = "p3"
	var out: Dictionary = Damage.resolve(s, _fire("p1", "p2", 3), [])
	assert_eq(out["amount"], 0)
	assert_eq(out["prevented"], 3)
	assert_eq(H.player(s, "p2")["hp"], 10)
	var ev: Dictionary = Types.make_mod_event("damage", 2, "", "p2")
	Damage.apply(s, ev, [])
	assert_eq(H.player(s, "p2")["hp"], 8, "un evento no-hechizo sí hace daño")


func test_damage_to_eliminated_is_ignored() -> void:
	H.player(s, "p2")["hp"] = 1
	Damage.apply(s, _fire("p1", "p2", 3), [])
	assert_true(H.player(s, "p2")["eliminated"])
	assert_eq(H.player(s, "p2")["hp"], 0)
	var out: Dictionary = Damage.resolve(s, _fire("p1", "p2", 3), [])
	assert_eq(out["amount"], 0)


func test_mana_loss_ignores_spell_and_element_modifiers() -> void:
	var shield: Dictionary = Types.make_modifier("shield", Types.STAGE_PREVENT, Types.OP_SUB, 2, "p2", Types.SIDE_TARGET)
	shield["spell_iid"] = 500
	Modifiers.add(s, shield)
	Modifiers.add(s, Types.make_modifier("fire", Types.STAGE_PREVENT, Types.OP_SUB, 2, "p2", Types.SIDE_TARGET, Types.ELEMENT_FIRE))
	H.set_mana(s, "p2", 5)
	Damage.lose_mana(s, "p2", 2, [], "p1", Types.CARD_MANA_IMPLOSION, 500)
	assert_eq(H.player(s, "p2")["mana"], 3)
	# Un modificador genérico de prevención (p. ej. Magic Cap) sí aplica.
	Modifiers.add(s, Types.make_modifier("cap", Types.STAGE_PREVENT, Types.OP_PREVENT_ALL, 0, "p2", Types.SIDE_TARGET,
		"", Types.EXPIRES_ONCE))
	Damage.lose_mana(s, "p2", 2, [], "p1", "")
	assert_eq(H.player(s, "p2")["mana"], 3)


func test_mana_returns_to_pool_and_gain_is_limited() -> void:
	(s["pool"] as Dictionary)["mana"] = 2
	assert_eq(Damage.gain_mana(s, "p1", 5, []), 2)
	assert_eq(H.player(s, "p1")["mana"], 2)
	Damage.pay_mana(s, "p1", 1)
	assert_eq((s["pool"] as Dictionary)["mana"], 1)


func test_heal_limited_by_pool() -> void:
	H.player(s, "p1")["hp"] = 4
	(s["pool"] as Dictionary)["hp"] = 1
	assert_eq(Damage.heal(s, "p1", 3, []), 1)
	assert_eq(H.player(s, "p1")["hp"], 5)


func test_shortfall_prompts_merge() -> void:
	Damage.lose_mana(s, "p2", 1, [], "", "")
	Damage.lose_mana(s, "p2", 2, [], "", "")
	assert_eq((s["pending"] as Array).size(), 1)
	assert_eq((((s["pending"] as Array)[0] as Dictionary)["data"] as Dictionary)["missing"], 3)


func test_card_cost_preview_does_not_consume_once() -> void:
	Modifiers.add(s, Types.make_modifier("disc", Types.STAGE_COST, Types.OP_SUB, 1, "p1", Types.SIDE_TARGET, "",
		Types.EXPIRES_ONCE))
	var def: Dictionary = CardCatalog.get_def(Types.CARD_FIREBALL)
	assert_eq(Damage.card_cost(s, "p1", def), 1)
	assert_eq((s["modifiers"] as Array).size(), 1)
	assert_eq(Damage.card_cost(s, "p1", def, -1, true), 1)
	assert_eq((s["modifiers"] as Array).size(), 0)
	assert_eq(Damage.card_cost(s, "p1", def), 2)


func test_potion_amount_order_stage_then_elixir() -> void:
	Modifiers.add(s, Types.make_modifier("shot", Types.STAGE_POTION, Types.OP_SUB, 1))
	(H.player(s, "p1")["flags"] as Dictionary)["potent_elixir"] = 1
	assert_eq(Damage.potion_amount(s, "p1"), 4)

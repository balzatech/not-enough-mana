extends GutTest
## T6c: los 11 eventos e interacciones (Wild Fire + Fire Storm, Tiara + Not
## Enough Mana, evento reemplazado).

const H = preload("res://tests/fixtures/engine_helpers.gd")
const X = preload("res://tests/engine/effects/t6c_helpers.gd")

var s: Dictionary


func before_each() -> void:
	s = X.new_state()


func after_all() -> void:
	CardCatalog.load_json()
	EffectRegistry.reset()


# --- Visit of the Archmage --------------------------------------------------

func test_visit_of_the_archmage_drink_or_lose_two() -> void:
	X.event(s, Types.CARD_VISIT_OF_THE_ARCHMAGE, "p2")
	var pend: Array = s["pending"]
	assert_eq(pend.size(), 3)
	assert_eq((pend[0] as Dictionary)["player"], "p2", "en orden de turno desde quien lo robó")
	for pr: Variant in pend:
		var prd: Dictionary = pr
		assert_eq(prd["kind"], Types.PROMPT_DRINK_OR_SUFFER)
		assert_true(bool(prd["optional"]))
		assert_eq(int((prd["data"] as Dictionary)["hp"]), 2)
	var p1: Dictionary = X.prompts_of(s, "p1", Types.PROMPT_DRINK_OR_SUFFER)[0]
	var p2: Dictionary = X.prompts_of(s, "p2", Types.PROMPT_DRINK_OR_SUFFER)[0]
	var p3: Dictionary = X.prompts_of(s, "p3", Types.PROMPT_DRINK_OR_SUFFER)[0]
	s = H.ok(self, s, Types.make_action_drink_potion("p1", int(p1["id"])))
	assert_eq(X.hp(s, "p1"), 10)
	assert_eq(X.mana(s, "p1"), 3)
	# DECLINE = lo que envía la sesión al vencer el temporizador en línea.
	s = H.ok(self, s, Types.make_action_decline("p2", int(p2["id"])))
	assert_eq(X.hp(s, "p2"), 8)
	s = H.ok(self, s, Types.make_action_decline("p3", int(p3["id"])))
	assert_eq(X.hp(s, "p3"), 8)
	assert_eq((s["pending"] as Array).size(), 0)
	X.valid(self, s)


func test_visit_skips_eliminated() -> void:
	H.player(s, "p3")["eliminated"] = true
	X.event(s, Types.CARD_VISIT_OF_THE_ARCHMAGE)
	assert_eq((s["pending"] as Array).size(), 2)


# --- Not Enough Mana --------------------------------------------------------

func test_not_enough_mana_damage_also_drains_mana() -> void:
	X.event(s, Types.CARD_NOT_ENOUGH_MANA)
	H.set_mana(s, "p2", 5)
	X.spell_damage(s, "p1", "p2", 2, Types.ELEMENT_ICE)
	assert_eq(X.hp(s, "p2"), 8)
	assert_eq(X.mana(s, "p2"), 3)


func test_not_enough_mana_shortfall() -> void:
	X.event(s, Types.CARD_NOT_ENOUGH_MANA)
	H.set_mana(s, "p2", 1)
	X.spell_damage(s, "p1", "p2", 3, Types.ELEMENT_ICE)
	assert_eq(X.mana(s, "p2"), 0)
	var prs: Array = X.prompts_of(s, "p2", Types.PROMPT_MANA_SHORTFALL)
	assert_eq(int(((prs[0] as Dictionary)["data"] as Dictionary)["missing"]), 2)


func test_tiara_plus_not_enough_mana_uses_reduced_damage() -> void:
	s = X.equip(self, s, "p2", Types.CARD_FIREPROOF_TIARA)
	X.event(s, Types.CARD_NOT_ENOUGH_MANA)
	H.set_mana(s, "p2", 5)
	X.spell_damage(s, "p1", "p2", 2, Types.ELEMENT_FIRE)
	assert_eq(X.hp(s, "p2"), 9, "Tiara: 2 − 1")
	assert_eq(X.mana(s, "p2"), 4, "Not Enough Mana con el daño final (1)")


func test_tiara_blocking_all_damage_drains_no_mana() -> void:
	s = X.equip(self, s, "p2", Types.CARD_FIREPROOF_TIARA)
	X.event(s, Types.CARD_NOT_ENOUGH_MANA)
	H.set_mana(s, "p2", 5)
	X.spell_damage(s, "p1", "p2", 1, Types.ELEMENT_FIRE)
	assert_eq(X.hp(s, "p2"), 10)
	assert_eq(X.mana(s, "p2"), 5)


# --- Shot Glass -------------------------------------------------------------

func test_shot_glass_potion_gives_one_less() -> void:
	X.event(s, Types.CARD_SHOT_GLASS)
	assert_eq(Damage.potion_amount(s, "p1"), 2)
	s = H.ok(self, s, Types.make_action_drink_potion("p1"))
	assert_eq(X.mana(s, "p1"), 2)


# --- Storms -----------------------------------------------------------------

func _storm_case(event_id: String, element: String, card_id: String, other: String) -> void:
	s = X.new_state()
	var def: Dictionary = CardCatalog.get_def(card_id)
	var base: int = Damage.card_cost(s, "p1", def)
	X.event(s, event_id)
	assert_eq(Damage.card_cost(s, "p1", def), base + 1, "%s: +1💧 de coste" % event_id)
	assert_eq(Damage.card_cost(s, "p1", CardCatalog.get_def(Types.CARD_HEAL)), 2, "sin elemento: sin cambio")
	X.spell_damage(s, "p2", "p3", 2, element, card_id)
	assert_eq(X.hp(s, "p3"), 7, "%s: +1 de daño para todos" % event_id)
	X.spell_damage(s, "p2", "p1", 2, other)
	assert_eq(X.hp(s, "p1"), 8, "%s: otro elemento sin bono" % event_id)


func test_fire_storm() -> void:
	_storm_case(Types.CARD_FIRE_STORM, Types.ELEMENT_FIRE, Types.CARD_FIREBALL, Types.ELEMENT_ICE)


func test_ice_storm() -> void:
	_storm_case(Types.CARD_ICE_STORM, Types.ELEMENT_ICE, Types.CARD_BLIZZARD, Types.ELEMENT_FIRE)


func test_lightning_storm() -> void:
	_storm_case(Types.CARD_LIGHTNING_STORM, Types.ELEMENT_ELECTRIC, Types.CARD_LIGHTNING, Types.ELEMENT_ICE)


func test_fire_storm_cost_is_charged_when_playing() -> void:
	X.event(s, Types.CARD_FIRE_STORM)
	H.force_turn(s, "p1")
	var iid: int = X.give(s, "p1", Types.CARD_FIRE_ARROW)
	var def: Dictionary = CardCatalog.get_def(Types.CARD_FIRE_ARROW)
	var cost: int = int((def["cost"] as Dictionary)["mana"]) + 1
	H.set_mana(s, "p1", cost - 1)
	var e: String = H.err(s, Types.make_action_play_card("p1", iid, ["p2"]))
	assert_true(e == Types.ERR_INSUFFICIENT_MANA or e == Types.ERR_NO_EFFECT, "sin maná suficiente: %s" % e)


func test_wild_fire_plus_fire_storm_stack() -> void:
	s = X.equip(self, s, "p1", Types.CARD_WILD_FIRE)
	X.event(s, Types.CARD_FIRE_STORM)
	var ev: Dictionary = X.spell_damage(s, "p1", "p2", 2, Types.ELEMENT_FIRE)
	assert_eq(int(ev["amount"]), 4, "2 + Wild Fire + Fire Storm")
	assert_eq(X.hp(s, "p2"), 6)
	X.spell_damage(s, "p3", "p2", 2, Types.ELEMENT_FIRE)
	assert_eq(X.hp(s, "p2"), 3, "Fire Storm sin Wild Fire para otro lanzador")


# --- Mana Focus -------------------------------------------------------------

func test_mana_focus_convert_damage_to_mana() -> void:
	X.event(s, Types.CARD_MANA_FOCUS)
	H.set_mana(s, "p2", 2)
	X.spell_damage(s, "p1", "p2", 3, Types.ELEMENT_FIRE)
	assert_eq(X.hp(s, "p2"), 10, "daño aplazado")
	var pr: Dictionary = X.prompts_of(s, "p2", Types.PROMPT_MANA_FOCUS)[0]
	assert_eq(int((pr["data"] as Dictionary)["damage"]), 3)
	var opts: Array = Game.legal_actions(s, "p2").filter(func(a: Dictionary) -> bool:
		return a["type"] == Types.ACTION_USE_EVENT)
	assert_eq(opts.size(), 3, "0, 1 o 2 de maná")
	assert_eq(H.err(s, Types.make_action_use_event("p2", {"mana": 3}, int(pr["id"]))), Types.ERR_INVALID_CHOICE)
	s = H.ok(self, s, Types.make_action_use_event("p2", {"mana": 2}, int(pr["id"])))
	assert_eq(X.mana(s, "p2"), 0)
	assert_eq(X.hp(s, "p2"), 9)
	assert_eq((s["pending"] as Array).size(), 0)
	X.valid(self, s)


func test_mana_focus_decline_takes_full_damage() -> void:
	X.event(s, Types.CARD_MANA_FOCUS)
	H.set_mana(s, "p2", 5)
	X.spell_damage(s, "p1", "p2", 3, Types.ELEMENT_FIRE)
	var pr: Dictionary = X.prompts_of(s, "p2", Types.PROMPT_MANA_FOCUS)[0]
	s = H.ok(self, s, Types.make_action_decline("p2", int(pr["id"])))
	assert_eq(X.hp(s, "p2"), 7)
	assert_eq(X.mana(s, "p2"), 5)


func test_mana_focus_without_mana_no_prompt() -> void:
	X.event(s, Types.CARD_MANA_FOCUS)
	H.set_mana(s, "p2", 0)
	X.spell_damage(s, "p1", "p2", 2, Types.ELEMENT_FIRE)
	assert_eq(X.hp(s, "p2"), 8)
	assert_eq((s["pending"] as Array).size(), 0)


func test_mana_focus_lethal_damage_can_be_absorbed() -> void:
	X.event(s, Types.CARD_MANA_FOCUS)
	H.player(s, "p2")["hp"] = 2
	H.set_mana(s, "p2", 5)
	X.spell_damage(s, "p1", "p2", 3, Types.ELEMENT_FIRE)
	assert_false(bool(H.player(s, "p2")["eliminated"]))
	var pr: Dictionary = X.prompts_of(s, "p2", Types.PROMPT_MANA_FOCUS)[0]
	s = H.ok(self, s, Types.make_action_use_event("p2", {"mana": 3}, int(pr["id"])))
	assert_eq(X.hp(s, "p2"), 2)
	assert_eq(X.mana(s, "p2"), 2)


# --- Disrupted Gravity, Blessing, Warp Discharge ----------------------------

func test_disrupted_gravity_all_hand_limits_plus_one() -> void:
	X.event(s, Types.CARD_DISRUPTED_GRAVITY)
	for pid: String in ["p1", "p2", "p3"]:
		assert_eq(Damage.hand_limit(s, pid), 6)


func test_disrupted_gravity_stacks_with_spellbook() -> void:
	s = X.equip(self, s, "p1", Types.CARD_SPELLBOOK)
	X.event(s, Types.CARD_DISRUPTED_GRAVITY)
	assert_eq(Damage.hand_limit(s, "p1"), 7)


func test_blessing_heals_two_capped() -> void:
	H.player(s, "p1")["hp"] = 5
	H.player(s, "p2")["hp"] = 9
	X.event(s, Types.CARD_BLESSING)
	assert_eq([X.hp(s, "p1"), X.hp(s, "p2"), X.hp(s, "p3")], [7, 10, 10])


func test_warp_discharge_lowest_mana_loses_others_gain() -> void:
	for pid: String in ["p1", "p2", "p3"]:
		H.player(s, pid)["hp"] = 5
	H.set_mana(s, "p1", 0)
	H.set_mana(s, "p2", 0)
	H.set_mana(s, "p3", 4)
	X.event(s, Types.CARD_WARP_DISCHARGE)
	assert_eq([X.hp(s, "p1"), X.hp(s, "p2"), X.hp(s, "p3")], [4, 4, 6], "empate en el mínimo: pierden todos")


func test_warp_discharge_single_lowest() -> void:
	H.set_mana(s, "p1", 3)
	H.set_mana(s, "p2", 1)
	H.set_mana(s, "p3", 2)
	H.player(s, "p1")["hp"] = 9
	X.event(s, Types.CARD_WARP_DISCHARGE)
	assert_eq([X.hp(s, "p1"), X.hp(s, "p2"), X.hp(s, "p3")], [10, 9, 10])


# --- Elixir Transmutation ---------------------------------------------------

func test_elixir_transmutation_buy_life() -> void:
	H.player(s, "p2")["hp"] = 6
	H.player(s, "p3")["hp"] = 9
	H.set_mana(s, "p2", 5)
	X.event(s, Types.CARD_ELIXIR_TRANSMUTATION)
	assert_eq(X.prompts_of(s, "p1", EventEffects.PROMPT_ELIXIR_TRANSMUTATION).size(), 0, "con vida máxima no pregunta")
	var pr: Dictionary = X.prompts_of(s, "p2", EventEffects.PROMPT_ELIXIR_TRANSMUTATION)[0]
	var opts: Array = Game.legal_actions(s, "p2").filter(func(a: Dictionary) -> bool:
		return a["type"] == Types.ACTION_USE_EVENT)
	assert_eq(opts.size(), 2, "5💧 alcanzan para 1 o 2💖")
	assert_eq(H.err(s, Types.make_action_use_event("p2", {"amount": 3}, int(pr["id"]))), Types.ERR_INVALID_CHOICE)
	s = H.ok(self, s, Types.make_action_use_event("p2", {"amount": 2}, int(pr["id"])))
	assert_eq(X.hp(s, "p2"), 8)
	assert_eq(X.mana(s, "p2"), 1)
	var pr3: Dictionary = X.prompts_of(s, "p3", EventEffects.PROMPT_ELIXIR_TRANSMUTATION)[0]
	s = H.ok(self, s, Types.make_action_decline("p3", int(pr3["id"])))
	assert_eq((s["pending"] as Array).size(), 0)
	X.valid(self, s)


func test_elixir_transmutation_capped_at_max_hp() -> void:
	H.player(s, "p2")["hp"] = 9
	H.set_mana(s, "p2", 10)
	X.event(s, Types.CARD_ELIXIR_TRANSMUTATION)
	var pr: Dictionary = X.prompts_of(s, "p2", EventEffects.PROMPT_ELIXIR_TRANSMUTATION)[0]
	assert_eq(H.err(s, Types.make_action_use_event("p2", {"amount": 2}, int(pr["id"]))), Types.ERR_INVALID_CHOICE)
	s = H.ok(self, s, Types.make_action_use_event("p2", {"amount": 1}, int(pr["id"])))
	assert_eq(X.hp(s, "p2"), 10)
	assert_eq(X.mana(s, "p2"), 8)


func test_elixir_transmutation_needs_prompt() -> void:
	H.player(s, "p2")["hp"] = 5
	H.set_mana(s, "p2", 10)
	X.event(s, Types.CARD_ELIXIR_TRANSMUTATION)
	assert_eq(H.err(s, Types.make_action_use_event("p2", {"amount": 1})), Types.ERR_PROMPT_NOT_FOUND)


# --- Evento reemplazado -----------------------------------------------------

func test_replaced_event_reverts_its_modifiers() -> void:
	X.event(s, Types.CARD_FIRE_STORM)
	assert_true(X.has_mod_from(s, Types.CARD_FIRE_STORM))
	X.event(s, Types.CARD_SHOT_GLASS)
	assert_false(X.has_mod_from(s, Types.CARD_FIRE_STORM), "Fire Storm revertido")
	assert_eq((s["active_event"] as Dictionary)["card_id"], Types.CARD_SHOT_GLASS)
	X.spell_damage(s, "p1", "p2", 2, Types.ELEMENT_FIRE)
	assert_eq(X.hp(s, "p2"), 8)
	assert_eq(Damage.potion_amount(s, "p1"), 2)
	X.event(s, Types.CARD_DISRUPTED_GRAVITY)
	assert_eq(Damage.potion_amount(s, "p1"), 3, "Shot Glass revertido")
	assert_eq(Damage.hand_limit(s, "p1"), 6)
	X.event(s, Types.CARD_BLESSING)
	assert_eq(Damage.hand_limit(s, "p1"), 5, "Disrupted Gravity revertido")
	X.valid(self, s)


func test_replaced_not_enough_mana_and_mana_focus() -> void:
	X.event(s, Types.CARD_NOT_ENOUGH_MANA)
	X.event(s, Types.CARD_MANA_FOCUS)
	H.set_mana(s, "p2", 5)
	X.spell_damage(s, "p1", "p2", 2, Types.ELEMENT_FIRE)
	assert_eq(X.mana(s, "p2"), 5, "Not Enough Mana ya no actúa")
	var pr: Dictionary = X.prompts_of(s, "p2", Types.PROMPT_MANA_FOCUS)[0]
	s = H.ok(self, s, Types.make_action_decline("p2", int(pr["id"])))
	X.event(s, Types.CARD_BLESSING)
	X.spell_damage(s, "p1", "p2", 2, Types.ELEMENT_FIRE)
	assert_eq((s["pending"] as Array).size(), 0, "Mana Focus ya no actúa")


func test_event_drawn_during_turn_draw() -> void:
	H.set_hand(s, "p2", [])
	X.event(s, Types.CARD_BLESSING)
	H.stack_deck(s, [Types.CARD_HEAL, Types.CARD_HEAL, Types.CARD_HEAL, Types.CARD_HEAL, Types.CARD_FIRE_STORM])
	s = H.ok(self, s, Types.make_action_end_turn("p1"))
	assert_eq((s["active_event"] as Dictionary)["card_id"], Types.CARD_FIRE_STORM)
	assert_eq(H.hand(s, "p2").size(), 5, "roba otra en lugar del evento")
	assert_true(X.has_mod_from(s, Types.CARD_FIRE_STORM))


func test_mana_focus_prompt_survives_new_event() -> void:
	X.event(s, Types.CARD_MANA_FOCUS)
	H.set_mana(s, "p2", 5)
	X.spell_damage(s, "p1", "p2", 2, Types.ELEMENT_FIRE)
	var pr: Dictionary = X.prompts_of(s, "p2", Types.PROMPT_MANA_FOCUS)[0]
	X.event(s, Types.CARD_BLESSING)
	var opts: Array = Game.legal_actions(s, "p2").filter(func(a: Dictionary) -> bool:
		return a["type"] == Types.ACTION_USE_EVENT)
	assert_eq(opts.size(), 3)
	s = H.ok(self, s, Types.make_action_use_event("p2", {"mana": 2}, int(pr["id"])))
	assert_eq(X.mana(s, "p2"), 3)
	assert_eq(X.hp(s, "p2"), 10)


func test_elixir_prompt_survives_new_event() -> void:
	H.player(s, "p2")["hp"] = 6
	H.set_mana(s, "p2", 4)
	X.event(s, Types.CARD_ELIXIR_TRANSMUTATION)
	var pr: Dictionary = X.prompts_of(s, "p2", EventEffects.PROMPT_ELIXIR_TRANSMUTATION)[0]
	X.event(s, Types.CARD_SHOT_GLASS)
	s = H.ok(self, s, Types.make_action_use_event("p2", {"amount": 2}, int(pr["id"])))
	assert_eq(X.hp(s, "p2"), 8)
	assert_eq(X.mana(s, "p2"), 0)
	assert_eq(H.err(s, Types.make_action_use_event("p1", {"amount": 1})), Types.ERR_PROMPT_NOT_FOUND)

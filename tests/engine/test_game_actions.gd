extends GutTest
## T4: acciones del turno (1.2.2-1.2.3), pociones (1), reglas especiales (1.3),
## eliminación y victoria, validación del reducer.

const H = preload("res://tests/fixtures/engine_helpers.gd")

var s: Dictionary
var cur: String
var nxt: String


func before_each() -> void:
	EffectRegistry.reset()
	H.use_fixture_catalog()
	H.register_fake_effects()
	s = H.game(3, {}, 5, [50, 40, 30])
	cur = "p1"
	nxt = "p2"


func after_all() -> void:
	EffectRegistry.reset()
	CardCatalog.load_json()


func _types(events: Array) -> Array:
	var out: Array = []
	for e: Variant in events:
		out.append((e as Dictionary)["type"])
	return out


# --- Validación general -------------------------------------------------------

func test_errors_do_not_mutate_and_do_not_throw() -> void:
	var before: Dictionary = s.duplicate(true)
	assert_eq(H.err(s, Types.make_action_end_turn(nxt)), Types.ERR_NOT_YOUR_TURN)
	assert_eq(H.err(s, {"type": "NOPE", "player": cur}), Types.ERR_INVALID_ACTION)
	assert_eq(H.err(s, {"type": Types.ACTION_DISCARD, "player": cur}), Types.ERR_INVALID_ACTION)
	assert_eq(H.err(s, Types.make_action_end_turn("zz")), Types.ERR_UNKNOWN_PLAYER)
	assert_eq(H.err(s, Types.make_action_exchange(cur, 99999)), Types.ERR_CARD_NOT_IN_HAND)
	var r: Dictionary = Game.reduce(s, Types.make_action_end_turn(nxt))
	assert_eq(r["events"], [])
	assert_true(is_same(r["state"], s))
	assert_eq(s, before)


func test_success_does_not_mutate_input_and_increments_rev() -> void:
	var before: Dictionary = s.duplicate(true)
	var r: Dictionary = Game.reduce(s, Types.make_action_drink_potion(nxt))
	assert_eq(r["error"], "")
	assert_eq(s, before)
	assert_eq((r["state"] as Dictionary)["rev"], int(s["rev"]) + 1)
	var s2: Dictionary = H.ok(self, r["state"], Types.make_action_end_turn(cur))
	assert_eq(s2["rev"], int(s["rev"]) + 2)


func test_finished_game_rejects_actions() -> void:
	s["status"] = Types.STATUS_FINISHED
	assert_eq(H.err(s, Types.make_action_drink_potion(cur)), Types.ERR_GAME_NOT_PLAYING)


# --- Descartar ----------------------------------------------------------------

func test_discard_any_number() -> void:
	var iids: Array = H.set_hand(s, cur, [Types.CARD_HEAL, Types.CARD_FIREBALL, Types.CARD_ICE_BOLT])
	var d0: int = (s["discard"] as Array).size()
	s = H.ok(self, s, Types.make_action_discard(cur, [iids[0], iids[2]]))
	assert_eq(H.hand(s, cur).size(), 1)
	assert_eq((s["discard"] as Array).size(), d0 + 2)
	assert_eq(H.err(s, Types.make_action_discard(cur, [])), Types.ERR_NOTHING_TO_DISCARD)
	assert_eq(H.err(s, Types.make_action_discard(cur, [iids[1], iids[1]])), Types.ERR_INVALID_ACTION)
	assert_eq(H.err(s, Types.make_action_discard(nxt, [iids[1]])), Types.ERR_NOT_YOUR_TURN)


# --- Intercambiar ---------------------------------------------------------------

func test_exchange_cost_grows_each_turn_and_resets() -> void:
	var iids: Array = H.set_hand(s, cur, [Types.CARD_HEAL, Types.CARD_HEAL, Types.CARD_HEAL])
	H.stack_deck(s, [Types.CARD_FIREBALL, Types.CARD_FIREBALL, Types.CARD_FIREBALL])
	H.set_mana(s, cur, 6)
	assert_eq(Damage.exchange_cost(s, cur), 1)
	s = H.ok(self, s, Types.make_action_exchange(cur, int(iids[0])))
	assert_eq(H.player(s, cur)["mana"], 5)
	assert_eq(H.hand(s, cur).size(), 3, "descarta 1 y roba 1")
	s = H.ok(self, s, Types.make_action_exchange(cur, int(iids[1])))
	assert_eq(H.player(s, cur)["mana"], 3)
	assert_eq(Damage.exchange_cost(s, cur), 3)
	s = H.ok(self, s, Types.make_action_exchange(cur, int(iids[2])))
	assert_eq(H.player(s, cur)["mana"], 0)
	var any_iid: int = int((H.hand(s, cur)[0] as Dictionary)["iid"])
	assert_eq(H.err(s, Types.make_action_exchange(cur, any_iid)), Types.ERR_INSUFFICIENT_MANA)
	s = H.ok(self, s, Types.make_action_end_turn(cur))
	assert_eq(Damage.exchange_cost(s, nxt), 1, "nuevo turno: vuelve a 1")
	assert_eq(Types.validate_state(s), [] as Array[String])


func test_exchange_cost_modifier_stage() -> void:
	Modifiers.add(s, Types.make_modifier("x#1", Types.STAGE_EXCHANGE_COST, Types.OP_SUB, 1, cur, Types.SIDE_TARGET))
	assert_eq(Damage.exchange_cost(s, cur), 0)


# --- Pociones --------------------------------------------------------------------

func test_potion_any_time_gives_3_and_uses_pool() -> void:
	s = H.ok(self, s, Types.make_action_drink_potion(nxt))  # fuera de su turno
	assert_eq(H.player(s, nxt)["mana"], 3)
	assert_eq(H.player(s, nxt)["potions"], 1)
	assert_eq((s["pool"] as Dictionary)["mana"], 67)


func test_potion_amount_configurable() -> void:
	s = H.game(3, {"potion_mana": 5}, 5)
	s = H.ok(self, s, Types.make_action_drink_potion("p2"))
	assert_eq(H.player(s, "p2")["mana"], 5)


func test_empty_pool_potion_gives_nothing() -> void:
	(s["pool"] as Dictionary)["mana"] = 2
	s = H.ok(self, s, Types.make_action_drink_potion(cur))
	assert_eq(H.player(s, cur)["mana"], 2)
	s = H.ok(self, s, Types.make_action_drink_potion(cur))
	assert_eq(H.player(s, cur)["mana"], 2)
	assert_eq(H.player(s, cur)["potions"], 2)


func test_pool_disabled_is_unlimited() -> void:
	s = H.game(3, {"pool_enabled": false}, 5)
	(s["pool"] as Dictionary)["mana"] = 0
	s = H.ok(self, s, Types.make_action_drink_potion("p1"))
	assert_eq(H.player(s, "p1")["mana"], 3)


func test_mana_has_no_upper_limit() -> void:
	for _i: int in 8:
		s = H.ok(self, s, Types.make_action_drink_potion(cur))
	assert_eq(H.player(s, cur)["mana"], 24)


func test_potent_elixir_doubles_next_potion() -> void:
	(H.player(s, cur)["flags"] as Dictionary)["potent_elixir"] = 1
	s = H.ok(self, s, Types.make_action_drink_potion(cur))
	assert_eq(H.player(s, cur)["mana"], 6)
	assert_eq((H.player(s, cur)["flags"] as Dictionary)["potent_elixir"], 0)
	s = H.ok(self, s, Types.make_action_drink_potion(cur))
	assert_eq(H.player(s, cur)["mana"], 9)


func test_potent_elixir_card_via_effect() -> void:
	var iids: Array = H.set_hand(s, cur, [Types.CARD_POTENT_ELIXIR])
	H.set_mana(s, cur, 1)
	s = H.play(self, s, Types.make_action_play_card(cur, int(iids[0])))
	s = H.ok(self, s, Types.make_action_drink_potion(cur))
	assert_eq(H.player(s, cur)["mana"], 6)


func test_potion_stage_modifier_shot_glass() -> void:
	Modifiers.add(s, Types.make_modifier("shot#1", Types.STAGE_POTION, Types.OP_SUB, 1))
	s = H.ok(self, s, Types.make_action_drink_potion(cur))
	assert_eq(H.player(s, cur)["mana"], 2)


func test_too_much_mana_eliminates_on_limit_plus_one() -> void:
	s = H.game(3, {"potion_limit": 2}, 5, [50, 40, 30])
	s = H.ok(self, s, Types.make_action_drink_potion("p2"))
	s = H.ok(self, s, Types.make_action_drink_potion("p2"))
	assert_false(H.player(s, "p2")["eliminated"])
	s = H.ok(self, s, Types.make_action_drink_potion("p2"))
	assert_true(H.player(s, "p2")["eliminated"])
	assert_eq(H.player(s, "p2")["eliminated_reason"], Types.ELIM_TOO_MUCH_MANA)
	assert_eq(H.hand(s, "p2").size(), 0, "el eliminado descarta su mano")
	assert_eq(H.err(s, Types.make_action_drink_potion("p2")), Types.ERR_PLAYER_ELIMINATED)
	assert_eq(Types.validate_state(s), [] as Array[String])


func test_too_much_mana_can_be_disabled() -> void:
	s = H.game(3, {"potion_limit": 1, "potion_limit_enabled": false}, 5)
	for _i: int in 5:
		s = H.ok(self, s, Types.make_action_drink_potion("p2"))
	assert_false(H.player(s, "p2")["eliminated"])


# --- Jugar cartas y pagar el coste --------------------------------------------------

func test_play_card_pays_mana_and_goes_to_discard() -> void:
	var iids: Array = H.set_hand(s, cur, [Types.CARD_FIREBALL])
	H.empty_other_hands(s, cur)  # nadie puede reaccionar: se resuelve en la misma acción
	H.set_mana(s, cur, 2)
	assert_eq(H.err(s, Types.make_action_play_card(cur, int(iids[0]), [])), Types.ERR_INVALID_TARGET)
	H.set_mana(s, cur, 1)
	assert_eq(H.err(s, Types.make_action_play_card(cur, int(iids[0]), [nxt])), Types.ERR_INSUFFICIENT_MANA)
	H.set_mana(s, cur, 2)
	var r: Dictionary = Game.reduce(s, Types.make_action_play_card(cur, int(iids[0]), [nxt]))
	assert_eq(r["error"], "")
	s = r["state"]
	assert_eq(H.player(s, cur)["mana"], 0)
	assert_eq(H.player(s, nxt)["hp"], 8)
	assert_eq(((s["discard"] as Array).back() as Dictionary)["iid"], iids[0])
	assert_true(_types(r["events"]).has(Types.LOG_SPELL_RESOLVED))
	assert_eq(Types.validate_state(s), [] as Array[String])


func test_spells_can_target_self() -> void:
	var iids: Array = H.set_hand(s, cur, [Types.CARD_FIRE_ARROW])
	H.set_mana(s, cur, 1)
	s = H.play(self, s, Types.make_action_play_card(cur, int(iids[0]), [cur]))
	assert_eq(H.player(s, cur)["hp"], 9)


func test_required_cards_are_paid_and_discarded() -> void:
	# Fixture: Electric Explosion cuesta 2 maná + 1 hechizo de fuego.
	var iids: Array = H.set_hand(s, cur, [Types.CARD_ELECTRIC_EXPLOSION, Types.CARD_FIRE_ARROW, Types.CARD_HEAL])
	H.set_mana(s, cur, 2)
	var play: int = iids[0]
	assert_eq(H.err(s, Types.make_action_play_card(cur, play, [], [])), Types.ERR_INVALID_PAYMENT)
	assert_eq(H.err(s, Types.make_action_play_card(cur, play, [], [iids[2]])), Types.ERR_INVALID_PAYMENT)
	assert_eq(H.err(s, Types.make_action_play_card(cur, play, [], [play])), Types.ERR_INVALID_PAYMENT)
	s = H.play(self, s, Types.make_action_play_card(cur, play, [], [iids[1]]))
	assert_eq(H.hand(s, cur).size(), 1)
	assert_eq(H.player(s, cur)["hp"], 10, "all_others no incluye a quien lanza")
	assert_eq(H.player(s, "p2")["hp"], 8)
	assert_eq(H.player(s, "p3")["hp"], 8)
	assert_eq(Types.validate_state(s), [] as Array[String])


func test_wildcard_hook_pays_required_card() -> void:
	var used: Array = []
	EffectRegistry.register(Types.CARD_SCROLL_OF_ELEMENTS, Callable(H.FakeFx, "noop"))
	EffectRegistry.register_hook(Game.HOOK_PAY_WILDCARD, Types.CARD_SCROLL_OF_ELEMENTS,
		func(st: Dictionary, ctx: Dictionary) -> Dictionary:
			if ctx["mode"] == "check":
				ctx["ok"] = true
			else:
				var tc: Dictionary = ctx["card"]
				used.append(tc["iid"])
				var arts: Array = Types.get_player(st, String(ctx["caster"]))["artifacts"]
				arts.erase(tc)
				(st["discard"] as Array).append(Types.make_card_instance(int(tc["iid"]), String(tc["card_id"])))
			return st)
	var iids: Array = H.set_hand(s, cur, [Types.CARD_SCROLL_OF_ELEMENTS, Types.CARD_ELECTRIC_EXPLOSION])
	H.set_mana(s, cur, 3)
	s = H.play(self, s, Types.make_action_play_card(cur, int(iids[0])))
	assert_eq((H.player(s, cur)["artifacts"] as Array).size(), 1, "el artefacto queda en mesa")
	s = H.play(self, s, Types.make_action_play_card(cur, int(iids[1]), [], [iids[0]]))
	assert_eq(used, [iids[0]])
	assert_eq((H.player(s, cur)["artifacts"] as Array).size(), 0)
	assert_eq(Types.validate_state(s), [] as Array[String])


func test_cost_stage_modifier() -> void:
	var iids: Array = H.set_hand(s, cur, [Types.CARD_FIREBALL])
	Modifiers.add(s, Types.make_modifier("storm#1", Types.STAGE_COST, Types.OP_ADD, 1, "", Types.SIDE_ANY,
		Types.ELEMENT_FIRE, Types.EXPIRES_NEXT_EVENT))
	H.set_mana(s, cur, 2)
	assert_eq(H.err(s, Types.make_action_play_card(cur, int(iids[0]), [nxt])), Types.ERR_INSUFFICIENT_MANA)
	H.set_mana(s, cur, 3)
	s = H.play(self, s, Types.make_action_play_card(cur, int(iids[0]), [nxt]))
	assert_eq(H.player(s, cur)["mana"], 0)


func test_unplayable_types_and_missing_effect() -> void:
	# Los 58 diseños reales tienen efecto: se añade al catálogo una carta sin él.
	var defs: Array = H.CardsFixture.defs()
	defs.append(Types.make_card_def("test_no_effect", "Test", Types.CARD_TYPE_SUPPORT, Types.ELEMENT_NONE,
		0, [], Types.TARGET_SINGLE))
	CardCatalog.set_defs(defs)
	var iids: Array = H.set_hand(s, cur, [Types.CARD_MAGIC_SHIELD, Types.CARD_BOOK_EXCHANGE])
	((H.hand(s, cur)[1]) as Dictionary)["card_id"] = "test_no_effect"
	H.set_mana(s, cur, 9)
	assert_eq(H.err(s, Types.make_action_play_card(cur, int(iids[0]), [cur])), Types.ERR_CARD_NOT_PLAYABLE)
	assert_eq(H.err(s, Types.make_action_play_card(cur, int(iids[1]), [nxt])), Types.ERR_NO_EFFECT)


func test_artifact_stays_on_table_with_modifiers() -> void:
	var iids: Array = H.set_hand(s, cur, [Types.CARD_WILD_FIRE, Types.CARD_FIREBALL])
	H.set_mana(s, cur, 4)
	s = H.play(self, s, Types.make_action_play_card(cur, int(iids[0])))
	assert_eq(((H.player(s, cur)["artifacts"] as Array)[0] as Dictionary)["owner"], cur)
	s = H.play(self, s, Types.make_action_play_card(cur, int(iids[1]), [nxt]))
	assert_eq(H.player(s, nxt)["hp"], 7, "Wild Fire +1")


func test_can_play_hook_blocks() -> void:
	EffectRegistry.register_hook(Types.HOOK_CAN_PLAY, Types.CARD_HEAL,
		func(st: Dictionary, ctx: Dictionary) -> Dictionary:
			ctx["error"] = Types.ERR_ARTIFACT_LIMIT
			return st)
	var iids: Array = H.set_hand(s, cur, [Types.CARD_HEAL])
	H.set_mana(s, cur, 3)
	assert_eq(H.err(s, Types.make_action_play_card(cur, int(iids[0]), [cur])), Types.ERR_ARTIFACT_LIMIT)


func _failing_heal() -> void:
	EffectRegistry.register(Types.CARD_HEAL, func(st: Dictionary, ctx: Dictionary) -> Dictionary:
		Types.get_player(st, String(ctx["caster"]))["hp"] = 1
		Damage.gain_mana(st, String(ctx["caster"]), 4, ctx["events"])
		ctx["error"] = Types.ERR_INVALID_TARGET
		return st)


func test_effect_error_without_window_rejects_action() -> void:
	# Nadie puede reaccionar: el hechizo se resuelve dentro de PLAY_CARD y el
	# error del efecto rechaza la acción entera sin tocar el estado.
	_failing_heal()
	var iids: Array = H.set_hand(s, cur, [Types.CARD_HEAL])
	H.empty_other_hands(s, cur)
	H.set_mana(s, cur, 3)
	var before: Dictionary = s.duplicate(true)
	assert_eq(H.err(s, Types.make_action_play_card(cur, int(iids[0]), [cur])), Types.ERR_INVALID_TARGET)
	assert_eq(s, before)


func test_effect_error_after_window_fizzles_without_partial_changes() -> void:
	# Con la ventana abierta, PLAY_CARD ya se aceptó (carta y coste pagados).
	# Al cerrarse, el efecto falla: el hechizo hace fizzle (va al descarte) y
	# sus cambios a medias se deshacen (Game.resolve_spell es atómico).
	_failing_heal()
	var iids: Array = H.set_hand(s, cur, [Types.CARD_HEAL])
	H.set_hand(s, nxt, [Types.CARD_MAGIC_SHIELD])
	H.set_mana(s, nxt, 5)
	H.set_mana(s, cur, 3)
	s = H.ok(self, s, Types.make_action_play_card(cur, int(iids[0]), [cur]))
	assert_false((s["reaction"] as Dictionary).is_empty(), "p2 puede responder: ventana abierta")
	var mana_after_cost: int = H.player(s, cur)["mana"]
	s = H.settle(s)
	assert_eq(H.player(s, cur)["hp"], 10)
	assert_eq(H.player(s, cur)["mana"], mana_after_cost)
	assert_eq(((s["discard"] as Array).back() as Dictionary)["iid"], iids[0])
	var fizzled: bool = false
	for e: Variant in s["log"]:
		var ed: Dictionary = e
		if ed["type"] == Types.LOG_EFFECT and (ed["data"] as Dictionary).get("what", "") == "fizzled":
			fizzled = true
	assert_true(fizzled)
	assert_eq(Types.validate_state(s), [] as Array[String])


func test_reaction_stub_resolves_directly() -> void:
	assert_eq(H.err(s, Types.make_action_pass_reaction(nxt)), Types.ERR_NO_REACTION)
	assert_true((s["reaction"] as Dictionary).is_empty())


func test_force_field_target_is_immune() -> void:
	var iids: Array = H.set_hand(s, cur, [Types.CARD_FIREBALL, Types.CARD_ARMAGEDDON])
	H.set_mana(s, cur, 9)
	(H.player(s, nxt)["flags"] as Dictionary)["force_field"] = "p3"
	assert_eq(H.err(s, Types.make_action_play_card(cur, int(iids[0]), [nxt])), Types.ERR_TARGET_IMMUNE)
	s = H.play(self, s, Types.make_action_play_card(cur, int(iids[1])))
	assert_eq(H.player(s, nxt)["hp"], 10, "el daño de hechizo se previene")
	assert_eq(H.player(s, "p3")["hp"], 7)
	# Caduca al empezar el turno de quien lo lanzó (p3).
	s = H.ok(self, s, Types.make_action_end_turn(cur))
	s = H.ok(self, s, Types.make_action_end_turn(nxt))
	assert_eq((H.player(s, nxt)["flags"] as Dictionary)["force_field"], "")


# --- Freeze / Blinding ---------------------------------------------------------------

func test_frozen_player_skips_turn() -> void:
	(H.player(s, nxt)["flags"] as Dictionary)["frozen"] = 1
	var r: Dictionary = Game.reduce(s, Types.make_action_end_turn(cur))
	s = r["state"]
	assert_eq((s["turn"] as Dictionary)["current"], "p3")
	assert_true(_types(r["events"]).has(Types.LOG_TURN_SKIPPED))
	assert_eq((H.player(s, nxt)["flags"] as Dictionary)["frozen"], 0)
	s = H.ok(self, s, Types.make_action_end_turn("p3"))
	s = H.ok(self, s, Types.make_action_end_turn("p1"))
	assert_eq((s["turn"] as Dictionary)["current"], nxt, "solo pierde un turno")


func test_freeze_card_skips_targets_next_turn() -> void:
	var iids: Array = H.set_hand(s, cur, [Types.CARD_FREEZE])
	H.set_mana(s, cur, 3)
	s = H.play(self, s, Types.make_action_play_card(cur, int(iids[0]), [nxt]))
	s = H.ok(self, s, Types.make_action_end_turn(cur))
	assert_eq((s["turn"] as Dictionary)["current"], "p3")


func test_blinded_cannot_cast_offensive_until_end_of_turn() -> void:
	var iids: Array = H.set_hand(s, cur, [Types.CARD_FIRE_ARROW, Types.CARD_HEAL])
	H.set_mana(s, cur, 5)
	(H.player(s, cur)["flags"] as Dictionary)["blinded"] = true
	assert_eq(H.err(s, Types.make_action_play_card(cur, int(iids[0]), [nxt])), Types.ERR_BLINDED)
	s = H.play(self, s, Types.make_action_play_card(cur, int(iids[1]), [cur]))
	s = H.ok(self, s, Types.make_action_end_turn(cur))
	assert_false((H.player(s, cur)["flags"] as Dictionary)["blinded"])


# --- Reglas especiales 1.3 ---------------------------------------------------------

func test_forced_discard_without_cards_costs_mana() -> void:
	H.set_hand(s, nxt, [])
	H.set_mana(s, nxt, 5)
	var ev: Array = []
	Damage.forced_discard(s, nxt, 2, ev, Types.CARD_PARALYSING_TOUCH)
	assert_eq(H.player(s, nxt)["mana"], 3)


func test_forced_discard_partial_hand() -> void:
	H.set_hand(s, nxt, [Types.CARD_HEAL])
	H.set_mana(s, nxt, 5)
	Damage.forced_discard(s, nxt, 2, [], "")
	assert_eq(H.hand(s, nxt).size(), 0)
	assert_eq(H.player(s, nxt)["mana"], 4)
	assert_eq(Types.validate_state(s), [] as Array[String])


func test_forced_discard_with_choice_creates_prompt() -> void:
	var iids: Array = H.set_hand(s, cur, [Types.CARD_ICE_BOLT])
	var tiids: Array = H.set_hand(s, nxt, [Types.CARD_HEAL, Types.CARD_FIREBALL])
	H.set_mana(s, cur, 1)
	s = H.play(self, s, Types.make_action_play_card(cur, int(iids[0]), [nxt]))
	var pend: Array = s["pending"]
	assert_eq(pend.size(), 1)
	var pr: Dictionary = pend[0]
	assert_eq(pr["kind"], Types.PROMPT_DISCARD)
	assert_eq(H.err(s, Types.make_action_end_turn(cur)), Types.ERR_PROMPT_PENDING)
	assert_eq(H.err(s, Types.make_action_choose_cards(cur, int(pr["id"]), [tiids[0]])), Types.ERR_NOT_YOUR_DECISION)
	assert_eq(H.err(s, Types.make_action_choose_cards(nxt, int(pr["id"]), [tiids[0], tiids[1]])), Types.ERR_INVALID_CHOICE)
	assert_eq(H.err(s, Types.make_action_decline(nxt, int(pr["id"]))), Types.ERR_INVALID_CHOICE)
	s = H.ok(self, s, Types.make_action_choose_cards(nxt, int(pr["id"]), [tiids[1]]))
	assert_eq(H.hand(s, nxt).size(), 1)
	assert_eq((s["pending"] as Array).size(), 0)
	s = H.ok(self, s, Types.make_action_end_turn(cur))


func test_mana_shortfall_drink_pays_the_rest() -> void:
	H.set_mana(s, nxt, 1)
	Damage.lose_mana(s, nxt, 3, [], cur, "")
	assert_eq(H.player(s, nxt)["mana"], 0)
	var pr: Dictionary = (s["pending"] as Array)[0]
	assert_eq(pr["kind"], Types.PROMPT_MANA_SHORTFALL)
	assert_eq((pr["data"] as Dictionary)["missing"], 2)
	s = H.ok(self, s, Types.make_action_drink_potion(nxt, int(pr["id"])))
	assert_eq(H.player(s, nxt)["mana"], 1)
	assert_eq(H.player(s, nxt)["hp"], 10)
	assert_eq((s["pending"] as Array).size(), 0)


func test_mana_shortfall_decline_loses_hp() -> void:
	Damage.lose_mana(s, nxt, 4, [], cur, "")
	var pr: Dictionary = (s["pending"] as Array)[0]
	assert_eq(H.err(s, Types.make_action_decline(cur, int(pr["id"]))), Types.ERR_NOT_YOUR_DECISION)
	s = H.ok(self, s, Types.make_action_decline(nxt, int(pr["id"])))
	assert_eq(H.player(s, nxt)["hp"], 6)
	assert_eq((s["pool"] as Dictionary)["hp"], 70 - 30 + 4)


func test_mana_shortfall_needs_several_potions() -> void:
	s = H.game(3, {"potion_mana": 2}, 5, [50, 40, 30])
	Damage.lose_mana(s, nxt, 5, [], cur, "")
	var pid: int = int(((s["pending"] as Array)[0] as Dictionary)["id"])
	s = H.ok(self, s, Types.make_action_drink_potion(nxt, pid))
	assert_eq((((s["pending"] as Array)[0] as Dictionary)["data"] as Dictionary)["missing"], 3)
	s = H.ok(self, s, Types.make_action_drink_potion(nxt))  # sin prompt_id también cuenta
	s = H.ok(self, s, Types.make_action_decline(nxt, pid))
	assert_eq(H.player(s, nxt)["hp"], 9)
	assert_eq(H.player(s, nxt)["mana"], 0)


func test_drink_or_suffer_prompt() -> void:
	EffectRegistry.register(Types.CARD_BLESSING, Callable(H.FakeFx, "visit"))
	var ev: Array = []
	Game.activate_event(s, H._take_any(s, Types.CARD_BLESSING), cur, ev)
	var pend: Array = s["pending"]
	assert_eq(pend.size(), 3)
	var p_cur: int = int((pend[0] as Dictionary)["id"])
	var p_nxt: int = int((pend[1] as Dictionary)["id"])
	s = H.ok(self, s, Types.make_action_drink_potion(cur, p_cur))
	s = H.ok(self, s, Types.make_action_decline(nxt, p_nxt))
	assert_eq(H.player(s, cur)["hp"], 10)
	assert_eq(H.player(s, nxt)["hp"], 8)


# --- Eliminación y victoria ------------------------------------------------------------

func test_zero_hp_eliminates_and_discards_hand() -> void:
	var iids: Array = H.set_hand(s, cur, [Types.CARD_FIREBALL])
	H.set_mana(s, cur, 2)
	H.player(s, nxt)["hp"] = 2
	var hand_n: int = H.hand(s, nxt).size()
	var d0: int = (s["discard"] as Array).size()
	s = H.play(self, s, Types.make_action_play_card(cur, int(iids[0]), [nxt]))
	assert_true(H.player(s, nxt)["eliminated"])
	assert_eq(H.player(s, nxt)["eliminated_reason"], Types.ELIM_HP)
	assert_eq(H.hand(s, nxt).size(), 0)
	assert_eq((s["discard"] as Array).size(), d0 + hand_n + 1)
	s = H.ok(self, s, Types.make_action_end_turn(cur))
	assert_eq((s["turn"] as Dictionary)["current"], "p3", "se salta al eliminado")


func test_last_wizard_standing_wins() -> void:
	var iids: Array = H.set_hand(s, cur, [Types.CARD_ELECTRIC_EXPLOSION, Types.CARD_FIRE_ARROW])
	H.empty_other_hands(s, cur)
	H.set_mana(s, cur, 2)
	H.player(s, "p2")["hp"] = 1
	H.player(s, "p3")["hp"] = 2
	var r: Dictionary = Game.reduce(s, Types.make_action_play_card(cur, int(iids[0]), [], [iids[1]]))
	assert_eq(r["error"], "")
	s = r["state"]
	assert_eq(s["status"], Types.STATUS_FINISHED)
	assert_eq(s["winners"], [cur])
	assert_true(_types(r["events"]).has(Types.LOG_GAME_OVER))
	assert_eq(Game.legal_actions(s, cur), [])


func test_everyone_dies_is_a_draw() -> void:
	var iids: Array = H.set_hand(s, cur, [Types.CARD_ARMAGEDDON])
	H.set_mana(s, cur, 5)
	for pid: String in ["p1", "p2", "p3"]:
		H.player(s, pid)["hp"] = 3
	s = H.play(self, s, Types.make_action_play_card(cur, int(iids[0])))
	assert_eq(s["status"], Types.STATUS_FINISHED)
	assert_eq(s["winners"], [])


func test_current_player_eliminated_passes_turn() -> void:
	var iids: Array = H.set_hand(s, cur, [Types.CARD_FIREBALL])
	H.set_mana(s, cur, 2)
	H.player(s, cur)["hp"] = 1
	s = H.play(self, s, Types.make_action_play_card(cur, int(iids[0]), [cur]))
	assert_true(H.player(s, cur)["eliminated"])
	assert_eq((s["turn"] as Dictionary)["current"], nxt)
	assert_eq((s["turn"] as Dictionary)["phase"], Types.PHASE_MAIN)


func test_concede() -> void:
	s = H.ok(self, s, Types.make_action_concede(nxt))
	assert_eq(H.player(s, nxt)["eliminated_reason"], Types.ELIM_CONCEDE)


# --- Curación ------------------------------------------------------------------------

func test_heal_caps_at_max_hp() -> void:
	H.player(s, cur)["hp"] = 9
	assert_eq(Damage.heal(s, cur, 3, []), 1)
	assert_eq(H.player(s, cur)["hp"], 10)


# --- Curse of Rules (botón) ------------------------------------------------------------

func test_break_rule_costs_one_mana() -> void:
	var c: Dictionary = H._take_any(s, Types.CARD_CURSE_OF_RULES)
	(H.player(s, cur)["curses"] as Array).append(Types.make_table_card(int(c["iid"]), Types.CARD_CURSE_OF_RULES, cur,
		{"rule": "no decir 'maná'"}))
	H.set_mana(s, "p3", 2)
	s = H.ok(self, s, Types.make_action_break_rule(nxt, "p3", int(c["iid"])))
	assert_eq(H.player(s, "p3")["mana"], 1)
	assert_eq(H.err(s, Types.make_action_break_rule(nxt, "p3", 99999)), Types.ERR_CARD_NOT_IN_PLAY)
	assert_eq(Types.validate_state(s), [] as Array[String])

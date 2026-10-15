extends NemTest
## T6a: efectos de electricidad (Lightning y su cadena, Electric Explosion,
## Blinding Flash, Electric Arc, Paralysing Touch) con el catálogo real.

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


func test_electric_cards_registered() -> void:
	for id: String in [Types.CARD_LIGHTNING, Types.CARD_ELECTRIC_EXPLOSION, Types.CARD_BLINDING_FLASH,
			Types.CARD_ELECTRIC_ARC, Types.CARD_PARALYSING_TOUCH]:
		assert_true(EffectRegistry.has_effect(id), id)
	assert_true(EffectRegistry.get_hook(ElectricEffects.HOOK_CAN_RESPOND, Types.CARD_LIGHTNING).is_valid())


# =============================================================================
# Lightning (sin cadena)
# =============================================================================

func test_lightning_base() -> void:
	var r: Dictionary = OH.cast(s, "p1", Types.CARD_LIGHTNING, ["p2"])
	_ok(r)
	assert_eq(OH.hp(s, "p2"), 8)
	assert_eq((OH.events_of(r["events"], Types.LOG_DAMAGE)[0] as Dictionary)["data"]["element"],
		Types.ELEMENT_ELECTRIC)


func test_lightning_self() -> void:
	_ok(OH.cast(s, "p1", Types.CARD_LIGHTNING, ["p1"]))
	assert_eq(OH.hp(s, "p1"), 8)


func test_lightning_eliminated_target() -> void:
	OH.kill(s, "p2")
	assert_eq(OH.play_error(s, "p1", Types.CARD_LIGHTNING, ["p2"]), Types.ERR_INVALID_TARGET)
	var r: Dictionary = OH.cast(s, "p1", Types.CARD_LIGHTNING, ["p2"])
	_ok(r)
	assert_eq(OH.events_of(r["events"], Types.LOG_EFFECT, "fizzled").size(), 1)


func test_lightning_kills() -> void:
	OH.set_hp(s, "p2", 2)
	_ok(OH.cast(s, "p1", Types.CARD_LIGHTNING, ["p2"]))
	assert_true(OH.eliminated(s, "p2"))


func test_lightning_with_fake_storm() -> void:
	OH.add_mod(s, "fake_lightning_storm", Types.STAGE_OUTGOING, Types.OP_ADD, 1, Types.ELEMENT_ELECTRIC)
	OH.add_mod(s, "fake_cloak", Types.STAGE_INCOMING, Types.OP_SUB, 2, Types.ELEMENT_ELECTRIC,
		Types.SIDE_TARGET, "p3")
	_ok(OH.cast(s, "p1", Types.CARD_LIGHTNING, ["p2"]))
	assert_eq(OH.hp(s, "p2"), 7)
	_ok(OH.cast(s, "p1", Types.CARD_LIGHTNING, ["p3"]))
	assert_eq(OH.hp(s, "p3"), 9)


# =============================================================================
# Lightning encadenado (simulando la ventana de reacción con los tipos)
# =============================================================================

## Abre a mano una ventana con un Lightning de caster a target.
func _open_lightning(caster: String, target: String) -> Dictionary:
	var card: Dictionary = H._take_any(s, Types.CARD_LIGHTNING)
	var spell: Dictionary = Types.make_spell(card, caster, [target])
	s["reaction"] = Types.make_reaction(spell)
	return spell


## Lo que haría reactions.gd tras un REACT de cadena aceptado: apilar la respuesta.
func _push_chain(by: String, to: String) -> Dictionary:
	var card: Dictionary = H._take_any(s, Types.CARD_LIGHTNING)
	var resp: Dictionary = Types.make_spell(card, by, [to], {}, true)
	((s["reaction"] as Dictionary)["stack"] as Array).append(resp)
	return resp


## Ctx del hook can_respond tal como lo construye reactions.gd.
func _can(pid: String, targets: Array) -> Dictionary:
	var card: Dictionary = Types.make_card_instance(9999, Types.CARD_LIGHTNING)
	var ctx: Dictionary = Types.make_effect_ctx(card, CardCatalog.get_def(Types.CARD_LIGHTNING), pid, targets)
	ctx["reaction"] = s["reaction"]
	ctx["ok"] = false
	EffectRegistry.get_hook(ElectricEffects.HOOK_CAN_RESPOND, Types.CARD_LIGHTNING).call(s, ctx)
	return ctx


## Cierre de la ventana como en el contrato: LIFO (pop y luego efecto con
## is_response) y por último el hechizo original con Game.resolve_spell.
func _close() -> Array:
	var events: Array = []
	var re: Dictionary = s["reaction"]
	var stack: Array = re["stack"]
	while not stack.is_empty():
		var resp: Dictionary = stack.pop_back()
		var card: Dictionary = resp["card"]
		var ctx: Dictionary = Types.make_effect_ctx(card, CardCatalog.get_def(String(card["card_id"])),
			String(resp["caster"]), resp["targets"] as Array, resp["extra"] as Dictionary)
		ctx["spell"] = resp
		ctx["is_response"] = true
		ctx["events"] = events
		EffectRegistry.get_effect(String(card["card_id"])).call(s, ctx)
		assert_eq(ctx["error"], Types.ERR_NONE)
		Deck.to_discard(s, card)
	var spell: Dictionary = re["spell"]
	s["reaction"] = {}
	var r: Dictionary = Game.resolve_spell(s, spell, events)
	assert_eq(r["error"], Types.ERR_NONE)
	return events


func test_chain_only_current_target_may_respond() -> void:
	_open_lightning("p1", "p2")
	var c: Dictionary = _can("p2", ["p3"])
	assert_true(c["ok"])
	assert_eq(c["error"], Types.ERR_NONE)
	assert_false(_can("p3", ["p4"])["ok"], "solo el objetivo puede encadenar")
	assert_false(_can("p1", ["p4"])["ok"])


func test_chain_cannot_redirect_to_self_or_eliminated() -> void:
	_open_lightning("p1", "p2")
	assert_eq(_can("p2", ["p2"])["error"], Types.ERR_INVALID_TARGET)
	OH.kill(s, "p4")
	assert_eq(_can("p2", ["p4"])["error"], Types.ERR_INVALID_TARGET)
	assert_true(_can("p2", ["p1"])["ok"], "puede devolverlo al lanzador")


func test_chain_not_on_other_spells_or_cancelled() -> void:
	var card: Dictionary = H._take_any(s, Types.CARD_FIREBALL)
	s["reaction"] = Types.make_reaction(Types.make_spell(card, "p1", ["p2"]))
	assert_false(_can("p2", ["p3"])["ok"], "no se responde a un Fireball con Lightning")
	var spell: Dictionary = _open_lightning("p1", "p2")
	spell["cancelled"] = true
	assert_false(_can("p2", ["p3"])["ok"])
	s["reaction"] = {}
	assert_false(_can("p2", ["p3"])["ok"], "sin ventana no hay cadena")


func test_chain_blinded_only_on_own_turn() -> void:
	_open_lightning("p1", "p2")
	OH.flags(s, "p2")["blinded"] = true
	assert_true(_can("p2", ["p3"])["ok"], "cegado, pero no es su turno")
	_open_lightning("p2", "p2")
	H.force_turn(s, "p2")
	assert_eq(_can("p2", ["p3"])["error"], Types.ERR_BLINDED)


func test_chain_one_link_adds_one_and_redirects() -> void:
	_open_lightning("p1", "p2")
	_push_chain("p2", "p3")
	assert_false(_can("p2", ["p4"])["ok"], "p2 ya no es el objetivo")
	assert_true(_can("p3", ["p4"])["ok"], "el nuevo objetivo puede seguir la cadena")
	var events: Array = _close()
	assert_eq(OH.hp(s, "p2"), 10)
	assert_eq(OH.hp(s, "p3"), 7)
	assert_eq(OH.events_of(events, Types.LOG_EFFECT, "lightning_redirected").size(), 1)
	assert_eq(Types.validate_state(s), [] as Array[String])


func test_chain_three_links_and_source_is_last_redirector() -> void:
	# p1 → p2; p2 → p3; p3 → p4; p4 → p1. Daño 2+3 = 5 a p1, causado por p4.
	OH.add_mod(s, "fake_tesla_p4", Types.STAGE_OUTGOING, Types.OP_ADD, 1, Types.ELEMENT_ELECTRIC,
		Types.SIDE_SOURCE, "p4")
	OH.add_mod(s, "fake_tesla_p1", Types.STAGE_OUTGOING, Types.OP_ADD, 10, Types.ELEMENT_ELECTRIC,
		Types.SIDE_SOURCE, "p1")
	_open_lightning("p1", "p2")
	_push_chain("p2", "p3")
	_push_chain("p3", "p4")
	_push_chain("p4", "p1")
	assert_true(_can("p1", ["p2"])["ok"])
	_close()
	assert_eq(OH.hp(s, "p1"), 4, "2 + 3 eslabones + 1 del bono de p4")
	for pid: String in ["p2", "p3", "p4"]:
		assert_eq(OH.hp(s, pid), 10, pid)
	assert_eq(Types.validate_state(s), [] as Array[String])


func test_chain_ignores_defensive_on_top() -> void:
	_open_lightning("p1", "p2")
	var shield: Dictionary = H._take_any(s, Types.CARD_MAGIC_SHIELD)
	((s["reaction"] as Dictionary)["stack"] as Array).append(Types.make_spell(shield, "p2", [], {}, true))
	assert_true(_can("p2", ["p3"])["ok"], "el foco sigue siendo el Lightning")
	# La defensiva queda fuera de la pila en este test (solo probamos la cadena).
	((s["reaction"] as Dictionary)["stack"] as Array).clear()
	Deck.to_discard(s, shield)
	_push_chain("p2", "p3")
	_close()
	assert_eq(OH.hp(s, "p3"), 7)


func test_chain_kills_final_target() -> void:
	OH.set_hp(s, "p3", 3)
	_open_lightning("p1", "p2")
	_push_chain("p2", "p3")
	_close()
	assert_true(OH.eliminated(s, "p3"))


func test_chain_final_target_eliminated_meanwhile() -> void:
	_open_lightning("p1", "p2")
	_push_chain("p2", "p3")
	OH.kill(s, "p3")
	var events: Array = _close()
	assert_eq(OH.hp(s, "p2"), 10)
	assert_eq(OH.events_of(events, Types.LOG_EFFECT, "fizzled").size(), 1)


func test_chain_cancelled_link_does_not_redirect() -> void:
	_open_lightning("p1", "p2")
	var l1: Dictionary = _push_chain("p2", "p3")
	_push_chain("p3", "p4")
	l1["cancelled"] = true
	# Simula reactions.gd: la respuesta cancelada no ejecuta su efecto.
	var events: Array = []
	var re: Dictionary = s["reaction"]
	var stack: Array = re["stack"]
	var l2: Dictionary = stack.pop_back()
	var ctx: Dictionary = Types.make_effect_ctx(l2["card"] as Dictionary,
		CardCatalog.get_def(Types.CARD_LIGHTNING), "p3", ["p4"])
	ctx["spell"] = l2
	ctx["is_response"] = true
	ctx["events"] = events
	ElectricEffects.lightning(s, ctx)
	Deck.to_discard(s, l2["card"] as Dictionary)
	Deck.to_discard(s, (stack.pop_back() as Dictionary)["card"] as Dictionary)
	var spell: Dictionary = re["spell"]
	s["reaction"] = {}
	Game.resolve_spell(s, spell, events)
	assert_eq(OH.hp(s, "p2"), 8, "sin el eslabón de p2, el rayo original golpea a p2")
	assert_eq(OH.hp(s, "p4"), 10)


func test_chain_through_reducer_if_reactions_ready() -> void:
	if not Game.REACTIONS_SCRIPT.has_method("handle"):
		pending("reactions.gd (T6b) aún no implementa handle")
		return
	var l0: Array = H.set_hand(s, "p1", [Types.CARD_LIGHTNING])
	var l1: Array = H.set_hand(s, "p2", [Types.CARD_LIGHTNING])
	var st: Dictionary = H.ok(self, s, Types.make_action_play_card("p1", int(l0[0]), ["p2"]))
	assert_false((st["reaction"] as Dictionary).is_empty(), "p2 puede encadenar: se abre la ventana")
	assert_eq(H.err(st, Types.make_action_react("p2", int(l1[0]), ["p2"])), Types.ERR_INVALID_TARGET)
	st = H.ok(self, st, Types.make_action_react("p2", int(l1[0]), ["p3"]))
	var guard: int = 0
	while not (st["reaction"] as Dictionary).is_empty() and guard < 10:
		guard += 1
		var who: String = String(((st["reaction"] as Dictionary)["awaiting"] as Array)[0])
		st = H.ok(self, st, Types.make_action_pass_reaction(who))
	assert_eq(OH.hp(st, "p3"), 7)
	assert_eq(OH.hp(st, "p2"), 10)
	assert_eq(OH.mana(st, "p2"), 8, "el eslabón paga su coste (2💧)")
	assert_eq(Types.validate_state(st), [] as Array[String])


# =============================================================================
# Electric Explosion
# =============================================================================

func test_electric_explosion_base() -> void:
	_ok(OH.cast(s, "p1", Types.CARD_ELECTRIC_EXPLOSION, ["p2", "p3", "p4"]))
	assert_eq(OH.hp(s, "p1"), 10)
	for pid: String in ["p2", "p3", "p4"]:
		assert_eq(OH.hp(s, pid), 8, pid)


func test_electric_explosion_never_hits_caster() -> void:
	# Aunque ctx.targets viniese con el lanzador, no se daña a sí mismo.
	_ok(OH.cast(s, "p1", Types.CARD_ELECTRIC_EXPLOSION, ["p1", "p2"]))
	assert_eq(OH.hp(s, "p1"), 10)
	assert_eq(OH.hp(s, "p2"), 8)
	_ok(OH.cast(s, "p2", Types.CARD_ELECTRIC_EXPLOSION, []))
	assert_eq(OH.hp(s, "p2"), 8)
	assert_eq(OH.hp(s, "p1"), 8)


func test_electric_explosion_skips_eliminated() -> void:
	OH.kill(s, "p3")
	var r: Dictionary = OH.cast(s, "p1", Types.CARD_ELECTRIC_EXPLOSION, ["p2", "p3", "p4"])
	_ok(r)
	assert_eq(OH.events_of(r["events"], Types.LOG_DAMAGE).size(), 2)


func test_electric_explosion_kills_and_wins() -> void:
	OH.set_hp(s, "p2", 2)
	OH.set_hp(s, "p3", 1)
	OH.set_hp(s, "p4", 2)
	_ok(OH.cast(s, "p1", Types.CARD_ELECTRIC_EXPLOSION, []))
	Game._finalize(s, [])
	assert_eq(s["status"], Types.STATUS_FINISHED)
	assert_eq(s["winners"], ["p1"])


# =============================================================================
# Blinding Flash
# =============================================================================

func test_blinding_flash_base() -> void:
	_ok(OH.cast(s, "p1", Types.CARD_BLINDING_FLASH, ["p2"]))
	assert_eq(OH.hp(s, "p2"), 8)
	assert_true(OH.flags(s, "p2")["blinded"])
	# En su turno no puede lanzar ofensivas (lo comprueba Game).
	H.force_turn(s, "p2")
	assert_eq(OH.play_error(s, "p2", Types.CARD_FIRE_ARROW, ["p1"]), Types.ERR_BLINDED)
	# Al acabar ese turno se le quita.
	Game._end_turn(s, "p2", [])
	assert_false(OH.flags(s, "p2")["blinded"])


func test_blinding_flash_self() -> void:
	_ok(OH.cast(s, "p1", Types.CARD_BLINDING_FLASH, ["p1"]))
	assert_eq(OH.hp(s, "p1"), 8)
	assert_true(OH.flags(s, "p1")["blinded"])


func test_blinding_flash_eliminated_target() -> void:
	OH.kill(s, "p2")
	assert_eq(OH.play_error(s, "p1", Types.CARD_BLINDING_FLASH, ["p2"]), Types.ERR_INVALID_TARGET)
	_ok(OH.cast(s, "p1", Types.CARD_BLINDING_FLASH, ["p2"]))
	assert_false(OH.flags(s, "p2")["blinded"])


func test_blinding_flash_kills_no_flag() -> void:
	OH.set_hp(s, "p2", 2)
	_ok(OH.cast(s, "p1", Types.CARD_BLINDING_FLASH, ["p2"]))
	assert_true(OH.eliminated(s, "p2"))
	assert_false(OH.flags(s, "p2")["blinded"])


# =============================================================================
# Electric Arc
# =============================================================================

func test_electric_arc_base() -> void:
	_ok(OH.cast(s, "p1", Types.CARD_ELECTRIC_ARC, ["p2", "p4"]))
	assert_eq(OH.hp(s, "p2"), 9)
	assert_eq(OH.hp(s, "p4"), 9)
	assert_eq(OH.hp(s, "p3"), 10)


func test_electric_arc_self_and_other() -> void:
	_ok(OH.cast(s, "p1", Types.CARD_ELECTRIC_ARC, ["p1", "p3"]))
	assert_eq(OH.hp(s, "p1"), 9)
	assert_eq(OH.hp(s, "p3"), 9)


func test_electric_arc_needs_two_distinct_alive_targets() -> void:
	assert_eq(OH.play_error(s, "p1", Types.CARD_ELECTRIC_ARC, ["p2", "p2"]), Types.ERR_INVALID_TARGET)
	assert_eq(OH.play_error(s, "p1", Types.CARD_ELECTRIC_ARC, ["p2"]), Types.ERR_INVALID_TARGET)
	OH.kill(s, "p3")
	assert_eq(OH.play_error(s, "p1", Types.CARD_ELECTRIC_ARC, ["p2", "p3"]), Types.ERR_INVALID_TARGET)


func test_electric_arc_one_target_eliminated_other_still_hit() -> void:
	OH.kill(s, "p3")
	_ok(OH.cast(s, "p1", Types.CARD_ELECTRIC_ARC, ["p2", "p3"]))
	assert_eq(OH.hp(s, "p2"), 9)
	OH.kill(s, "p2")
	var r: Dictionary = OH.cast(s, "p1", Types.CARD_ELECTRIC_ARC, ["p2", "p3"])
	_ok(r)
	assert_eq(OH.events_of(r["events"], Types.LOG_EFFECT, "fizzled").size(), 1)


func test_electric_arc_kills_both() -> void:
	OH.set_hp(s, "p2", 1)
	OH.set_hp(s, "p3", 1)
	_ok(OH.cast(s, "p1", Types.CARD_ELECTRIC_ARC, ["p2", "p3"]))
	assert_true(OH.eliminated(s, "p2"))
	assert_true(OH.eliminated(s, "p3"))


# =============================================================================
# Paralysing Touch
# =============================================================================

func test_paralysing_touch_base() -> void:
	H.set_hand(s, "p2", [Types.CARD_FIRE_ARROW, Types.CARD_HEAL, Types.CARD_FIREBALL])
	_ok(OH.cast(s, "p1", Types.CARD_PARALYSING_TOUCH, ["p2"]))
	assert_eq(OH.hp(s, "p2"), 8)
	var prs: Array = OH.prompts(s, "p2", Types.PROMPT_DISCARD)
	assert_eq(prs.size(), 1)
	assert_eq((prs[0] as Dictionary)["data"]["count"], 2)


func test_paralysing_touch_short_hand_loses_mana() -> void:
	H.set_hand(s, "p2", [Types.CARD_FIRE_ARROW])
	_ok(OH.cast(s, "p1", Types.CARD_PARALYSING_TOUCH, ["p2"]))
	assert_eq(H.hand(s, "p2").size(), 0)
	assert_eq(OH.mana(s, "p2"), 9, "1 carta descartada + 1💧 por la que falta")


func test_paralysing_touch_self() -> void:
	H.set_hand(s, "p1", [Types.CARD_FIRE_ARROW, Types.CARD_HEAL])
	_ok(OH.cast(s, "p1", Types.CARD_PARALYSING_TOUCH, ["p1"]))
	assert_eq(OH.hp(s, "p1"), 8)
	assert_eq(H.hand(s, "p1").size(), 0)


func test_paralysing_touch_eliminated_target() -> void:
	OH.kill(s, "p2")
	assert_eq(OH.play_error(s, "p1", Types.CARD_PARALYSING_TOUCH, ["p2"]), Types.ERR_INVALID_TARGET)
	_ok(OH.cast(s, "p1", Types.CARD_PARALYSING_TOUCH, ["p2"]))
	assert_eq(OH.mana(s, "p2"), 10)


func test_paralysing_touch_kills_no_discard() -> void:
	H.set_hand(s, "p2", [Types.CARD_FIRE_ARROW, Types.CARD_HEAL, Types.CARD_FIREBALL])
	OH.set_hp(s, "p2", 2)
	_ok(OH.cast(s, "p1", Types.CARD_PARALYSING_TOUCH, ["p2"]))
	assert_true(OH.eliminated(s, "p2"))
	assert_eq(OH.prompts(s, "p2", Types.PROMPT_DISCARD).size(), 0)

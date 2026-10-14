extends RefCounted
## Utilidades para los tests del motor (T4): catálogo de prueba, partidas,
## colocar cartas concretas y efectos falsos registrables.
##   const H = preload("res://tests/fixtures/engine_helpers.gd")

const CardsFixture = preload("res://tests/fixtures/cards_fixture.gd")


static func use_fixture_catalog() -> void:
	CardCatalog.set_defs(CardsFixture.defs())


## n jugadores p1..pn con edades `ages` (por defecto todos 30).
static func make_players(n: int, ages: Array = []) -> Array:
	var out: Array = []
	for i: int in n:
		var age: int = int(ages[i]) if i < ages.size() else 30
		out.append(Types.make_player("p%d" % (i + 1), "P%d" % (i + 1), age, (i % 12) + 1))
	return out


static func game(n: int = 3, cfg: Dictionary = {}, seed_value: int = 1, ages: Array = []) -> Dictionary:
	return Game.new_game(make_players(n, ages), cfg, seed_value)


static func player(s: Dictionary, pid: String) -> Dictionary:
	return Types.get_player(s, pid)


static func hand(s: Dictionary, pid: String) -> Array:
	return Types.get_player(s, pid)["hand"]


## Saca una instancia de card_id de cualquier zona (mazo, descarte, manos) y la
## devuelve ({} si no hay). Conserva el iid.
static func _take_any(s: Dictionary, card_id: String) -> Dictionary:
	var piles: Array = [s["deck"], s["discard"]]
	for p: Variant in s["players"]:
		piles.append((p as Dictionary)["hand"])
	for pile: Variant in piles:
		var arr: Array = pile
		for i: int in arr.size():
			var c: Dictionary = arr[i]
			if c["card_id"] == card_id:
				arr.remove_at(i)
				return c
	return {}


## Vacía la mano de pid (al descarte) y le da exactamente estas cartas.
static func set_hand(s: Dictionary, pid: String, card_ids: Array) -> Array:
	var h: Array = hand(s, pid)
	for c: Variant in h:
		(s["discard"] as Array).append(c)
	h.clear()
	var iids: Array = []
	for cid: Variant in card_ids:
		var c: Dictionary = _take_any(s, String(cid))
		assert(not c.is_empty(), "no queda %s" % cid)
		h.append(c)
		iids.append(int(c["iid"]))
	return iids


## Pone estas cartas encima del mazo; la ÚLTIMA de la lista queda arriba.
static func stack_deck(s: Dictionary, card_ids: Array) -> void:
	for cid: Variant in card_ids:
		var c: Dictionary = _take_any(s, String(cid))
		assert(not c.is_empty(), "no queda %s" % cid)
		(s["deck"] as Array).append(c)


## Pasa el turno a pid sin efectos (fase main, 0 intercambios).
static func force_turn(s: Dictionary, pid: String) -> void:
	var t: Dictionary = s["turn"]
	t["current"] = pid
	t["phase"] = Types.PHASE_MAIN
	t["exchanges"] = 0


static func set_mana(s: Dictionary, pid: String, mana: int) -> void:
	player(s, pid)["mana"] = mana


## Reduce y devuelve el estado nuevo; falla el test si hay error.
static func ok(t: GutTest, s: Dictionary, a: Dictionary) -> Dictionary:
	var r: Dictionary = Game.reduce(s, a)
	t.assert_eq(r["error"], "", "acción %s" % str(a))
	return r["state"]


## Cierra la ventana de reacción abierta (si la hay) como si venciera el plazo:
## aplica Reactions.timeout_actions() hasta que state.reaction quede vacío.
static func settle(s: Dictionary) -> Dictionary:
	var cur: Dictionary = s
	for _i: int in 100:
		if (cur["reaction"] as Dictionary).is_empty():
			return cur
		for a: Variant in Reactions.timeout_actions(cur):
			var r: Dictionary = Game.reduce(cur, a as Dictionary)
			assert(String(r["error"]) == "", "settle: %s" % str(r["error"]))
			cur = r["state"]
	return cur


## Como ok() y después cierra la ventana de reacción (todos pasan).
static func play(t: GutTest, s: Dictionary, a: Dictionary) -> Dictionary:
	return settle(ok(t, s, a))


## Vacía la mano de todos menos `keep` (al descarte): nadie podrá reaccionar.
static func empty_other_hands(s: Dictionary, keep: String) -> void:
	for p: Variant in s["players"]:
		var pd: Dictionary = p
		if String(pd["id"]) != keep:
			(s["discard"] as Array).append_array(pd["hand"] as Array)
			(pd["hand"] as Array).clear()


static func err(s: Dictionary, a: Dictionary) -> String:
	return String(Game.reduce(s, a)["error"])


## JSON ida y vuelta + normalización.
static func json_roundtrip(s: Dictionary) -> Dictionary:
	var parsed: Variant = JSON.parse_string(JSON.stringify(s))
	return Types.normalize_state(parsed as Dictionary)


# -----------------------------------------------------------------------------
# Efectos falsos (para simular sin T6)
# -----------------------------------------------------------------------------

static func register_fake_effects() -> void:
	var dmg: Callable = Callable(FakeFx, "damage")
	for id: String in [Types.CARD_FIRE_ARROW, Types.CARD_FIREBALL, Types.CARD_METEOR_SHOWER,
			Types.CARD_ARMAGEDDON, Types.CARD_LIGHTNING, Types.CARD_ELECTRIC_EXPLOSION,
			Types.CARD_ELECTRIC_ARC, Types.CARD_VAMPIRIC_TOUCH, Types.CARD_ICE_BOOMERANG]:
		EffectRegistry.register(id, dmg)
	EffectRegistry.register(Types.CARD_MANA_IMPLOSION, Callable(FakeFx, "mana_implosion"))
	EffectRegistry.register(Types.CARD_ICE_BOLT, Callable(FakeFx, "ice_bolt"))
	EffectRegistry.register(Types.CARD_PARALYSING_TOUCH, Callable(FakeFx, "ice_bolt"))
	EffectRegistry.register(Types.CARD_FREEZE, Callable(FakeFx, "freeze"))
	EffectRegistry.register(Types.CARD_BLINDING_FLASH, Callable(FakeFx, "blinding_flash"))
	EffectRegistry.register(Types.CARD_HEAL, Callable(FakeFx, "heal"))
	EffectRegistry.register(Types.CARD_GREATER_HEAL, Callable(FakeFx, "heal"))
	EffectRegistry.register(Types.CARD_POTENT_ELIXIR, Callable(FakeFx, "potent_elixir"))
	EffectRegistry.register(Types.CARD_CURSE_OF_VIGOUR, Callable(FakeFx, "curse_all_others"))
	EffectRegistry.register(Types.CARD_CURSE_OF_EVEN, Callable(FakeFx, "curse_all_others"))
	EffectRegistry.register(Types.CARD_SPELLBOOK, Callable(FakeFx, "spellbook"))
	EffectRegistry.register(Types.CARD_WILD_FIRE, Callable(FakeFx, "wild_fire"))
	EffectRegistry.register(Types.CARD_FIREPROOF_TIARA, Callable(FakeFx, "noop"))
	EffectRegistry.register(Types.CARD_BLESSING, Callable(FakeFx, "blessing"))
	EffectRegistry.register(Types.CARD_VISIT_OF_THE_ARCHMAGE, Callable(FakeFx, "visit"))
	EffectRegistry.register(Types.CARD_SHOT_GLASS, Callable(FakeFx, "shot_glass"))
	EffectRegistry.register(Types.CARD_DISRUPTED_GRAVITY, Callable(FakeFx, "gravity"))


class FakeFx:
	static func _amount(card_id: String) -> int:
		match card_id:
			Types.CARD_FIRE_ARROW, Types.CARD_ELECTRIC_ARC:
				return 1
			Types.CARD_ARMAGEDDON, Types.CARD_ICE_BOOMERANG:
				return 3
		return 2

	static func damage(state: Dictionary, ctx: Dictionary) -> Dictionary:
		var def: Dictionary = ctx["def"]
		var card: Dictionary = ctx["card"]
		for t: Variant in ctx["targets"]:
			var ev: Dictionary = Types.make_mod_event("damage", _amount(String(card["card_id"])), String(ctx["caster"]),
				String(t), String(def["element"]), String(card["card_id"]), int(card["iid"]), true)
			Damage.apply(state, ev, ctx["events"])
		return state

	static func mana_implosion(state: Dictionary, ctx: Dictionary) -> Dictionary:
		damage(state, ctx)
		for t: Variant in ctx["targets"]:
			Damage.lose_mana(state, String(t), 2, ctx["events"], String(ctx["caster"]), Types.CARD_MANA_IMPLOSION)
		return state

	static func ice_bolt(state: Dictionary, ctx: Dictionary) -> Dictionary:
		damage(state, ctx)
		for t: Variant in ctx["targets"]:
			Damage.forced_discard(state, String(t), 1, ctx["events"], String((ctx["card"] as Dictionary)["card_id"]))
		return state

	static func freeze(state: Dictionary, ctx: Dictionary) -> Dictionary:
		for t: Variant in ctx["targets"]:
			var fl: Dictionary = Types.get_player(state, String(t))["flags"]
			fl["frozen"] = int(fl["frozen"]) + 1
		return state

	static func blinding_flash(state: Dictionary, ctx: Dictionary) -> Dictionary:
		damage(state, ctx)
		for t: Variant in ctx["targets"]:
			(Types.get_player(state, String(t))["flags"] as Dictionary)["blinded"] = true
		return state

	static func heal(state: Dictionary, ctx: Dictionary) -> Dictionary:
		for t: Variant in ctx["targets"]:
			Damage.heal(state, String(t), 2, ctx["events"], String(ctx["caster"]), Types.CARD_HEAL)
		return state

	static func potent_elixir(state: Dictionary, ctx: Dictionary) -> Dictionary:
		var fl: Dictionary = Types.get_player(state, String(ctx["caster"]))["flags"]
		fl["potent_elixir"] = int(fl["potent_elixir"]) + 1
		return state

	static func curse_all_others(state: Dictionary, ctx: Dictionary) -> Dictionary:
		for pid: String in Types.alive_ids(state):
			if pid != String(ctx["caster"]):
				Damage.lose_mana(state, pid, 3, ctx["events"], String(ctx["caster"]),
					String((ctx["card"] as Dictionary)["card_id"]))
		return state

	static func spellbook(state: Dictionary, ctx: Dictionary) -> Dictionary:
		var card: Dictionary = ctx["card"]
		Modifiers.add(state, Types.make_modifier("spellbook#%d" % int(card["iid"]), Types.STAGE_HAND_LIMIT,
			Types.OP_ADD, 1, String(ctx["caster"]), Types.SIDE_TARGET, "", Types.EXPIRES_WHILE_IN_PLAY,
			Types.CARD_SPELLBOOK, int(card["iid"])))
		return state

	static func wild_fire(state: Dictionary, ctx: Dictionary) -> Dictionary:
		var card: Dictionary = ctx["card"]
		Modifiers.add(state, Types.make_modifier("wild_fire#%d" % int(card["iid"]), Types.STAGE_OUTGOING,
			Types.OP_ADD, 1, String(ctx["caster"]), Types.SIDE_SOURCE, Types.ELEMENT_FIRE,
			Types.EXPIRES_WHILE_IN_PLAY, Types.CARD_WILD_FIRE, int(card["iid"])))
		return state

	static func noop(state: Dictionary, _ctx: Dictionary) -> Dictionary:
		return state

	static func blessing(state: Dictionary, ctx: Dictionary) -> Dictionary:
		for pid: String in Types.alive_ids(state):
			Damage.heal(state, pid, 2, ctx["events"], "", Types.CARD_BLESSING)
		return state

	static func visit(state: Dictionary, _ctx: Dictionary) -> Dictionary:
		for pid: String in Types.alive_ids(state):
			(state["pending"] as Array).append(Types.make_prompt(Types.next_seq(state), pid,
				Types.PROMPT_DRINK_OR_SUFFER, {"hp": 2}, Types.CARD_VISIT_OF_THE_ARCHMAGE, true))
		return state

	static func shot_glass(state: Dictionary, ctx: Dictionary) -> Dictionary:
		var card: Dictionary = ctx["card"]
		Modifiers.add(state, Types.make_modifier("shot_glass#%d" % int(card["iid"]), Types.STAGE_POTION,
			Types.OP_SUB, 1, "", Types.SIDE_ANY, "", Types.EXPIRES_NEXT_EVENT, Types.CARD_SHOT_GLASS, int(card["iid"])))
		return state

	static func gravity(state: Dictionary, ctx: Dictionary) -> Dictionary:
		var card: Dictionary = ctx["card"]
		Modifiers.add(state, Types.make_modifier("gravity#%d" % int(card["iid"]), Types.STAGE_HAND_LIMIT,
			Types.OP_ADD, 1, "", Types.SIDE_ANY, "", Types.EXPIRES_NEXT_EVENT, Types.CARD_DISRUPTED_GRAVITY, int(card["iid"])))
		return state

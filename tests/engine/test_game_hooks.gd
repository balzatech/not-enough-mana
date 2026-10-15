extends NemTest
## T4: puntos de extensión del reducer para T6a/b/c (hooks del registro).

const H = preload("res://tests/fixtures/engine_helpers.gd")

var s: Dictionary


func before_each() -> void:
	super.before_each()
	EffectRegistry.reset()
	H.use_fixture_catalog()
	s = H.game(3, {}, 11, [50, 40, 30])


func after_all() -> void:
	EffectRegistry.reset()
	CardCatalog.load_json()


func _put_artifact(pid: String, card_id: String) -> int:
	var c: Dictionary = H._take_any(s, card_id)
	(H.player(s, pid)["artifacts"] as Array).append(Types.make_table_card(int(c["iid"]), card_id, pid))
	return int(c["iid"])


func test_turn_start_hook_and_owner_turn_start_expiry() -> void:
	var seen: Array = []
	EffectRegistry.register_hook(Types.HOOK_TURN_START, Types.CARD_TWARDOWSKYS_MIRROR,
		func(st: Dictionary, ctx: Dictionary) -> Dictionary:
			seen.append(String(ctx["caster"]))
			return st)
	_put_artifact("p2", Types.CARD_TWARDOWSKYS_MIRROR)
	Modifiers.add(s, Types.make_modifier("m#1", Types.STAGE_POTION, Types.OP_ADD, 1, "p2", Types.SIDE_TARGET, "",
		Types.EXPIRES_OWNER_TURN_START))
	Modifiers.add(s, Types.make_modifier("m#2", Types.STAGE_POTION, Types.OP_ADD, 1, "p1", Types.SIDE_TARGET, "",
		Types.EXPIRES_END_OF_TURN))
	s = H.ok(self, s, Types.make_action_end_turn("p1"))
	assert_eq(seen, ["p2"])
	assert_eq((s["modifiers"] as Array).size(), 0)


func test_use_artifact_routes_to_hook() -> void:
	EffectRegistry.register_hook(Types.HOOK_USE, Types.CARD_TRANSFORMATION_GLOVE,
		func(st: Dictionary, ctx: Dictionary) -> Dictionary:
			Damage.gain_mana(st, String(ctx["caster"]), 1, ctx["events"])
			return st)
	var iid: int = _put_artifact("p2", Types.CARD_TRANSFORMATION_GLOVE)
	s = H.ok(self, s, Types.make_action_use_artifact("p2", iid))
	assert_eq(H.player(s, "p2")["mana"], 1)
	assert_eq(H.err(s, Types.make_action_use_artifact("p1", iid)), Types.ERR_CARD_NOT_IN_PLAY)
	var other: int = _put_artifact("p1", Types.CARD_SPELLBOOK)
	assert_eq(H.err(s, Types.make_action_use_artifact("p1", other)), Types.ERR_NO_EFFECT)


func test_use_event_routes_to_hook() -> void:
	assert_eq(H.err(s, Types.make_action_use_event("p1", {"amount": 1})), Types.ERR_CARD_NOT_IN_PLAY)
	EffectRegistry.register_hook(Types.HOOK_USE_EVENT, Types.CARD_ELIXIR_TRANSMUTATION,
		func(st: Dictionary, ctx: Dictionary) -> Dictionary:
			Damage.heal(st, String(ctx["caster"]), int((ctx["extra"] as Dictionary)["amount"]), ctx["events"])
			return st)
	Game.activate_event(s, H._take_any(s, Types.CARD_ELIXIR_TRANSMUTATION), "p1", [])
	H.player(s, "p3")["hp"] = 5
	s = H.ok(self, s, Types.make_action_use_event("p3", {"amount": 2}))
	assert_eq(H.player(s, "p3")["hp"], 7)


func test_prompt_hook_and_legal_actions_hook() -> void:
	var got: Array = []
	EffectRegistry.register_hook(Game.HOOK_PROMPT, Types.CARD_MAGIC_HAND,
		func(st: Dictionary, ctx: Dictionary) -> Dictionary:
			got.append((ctx["action"] as Dictionary)["cards"])
			return st)
	var pr: Dictionary = Types.make_prompt(Types.next_seq(s), "p1", Types.PROMPT_CHOOSE_CARD,
		{"from": "p2", "count": 1, "cards": [1, 2]}, Types.CARD_MAGIC_HAND)
	(s["pending"] as Array).append(pr)
	var acts: Array = Game.legal_actions(s, "p1")
	var choose: Array = acts.filter(func(a: Dictionary) -> bool: return a["type"] == Types.ACTION_CHOOSE_CARDS)
	assert_eq(choose.size(), 2)
	s = H.ok(self, s, choose[1] as Dictionary)
	assert_eq(got, [[2]])
	assert_eq((s["pending"] as Array).size(), 0)

	EffectRegistry.register_hook(Game.HOOK_LEGAL_ACTIONS, Types.CARD_TRANSFORMATION_GLOVE,
		func(st: Dictionary, ctx: Dictionary) -> Dictionary:
			(ctx["actions"] as Array).append(Types.make_action_use_artifact("p1", int((ctx["card"] as Dictionary)["iid"])))
			return st)
	var iid: int = _put_artifact("p1", Types.CARD_TRANSFORMATION_GLOVE)
	var found: bool = false
	for a: Variant in Game.legal_actions(s, "p1"):
		var ad: Dictionary = a
		if ad["type"] == Types.ACTION_USE_ARTIFACT and int(ad["card"]) == iid:
			found = true
	assert_true(found)


func test_prompt_without_hook() -> void:
	# Source sin HOOK_PROMPT registrado (Magic Cap ya tiene el suyo).
	var pr: Dictionary = Types.make_prompt(Types.next_seq(s), "p2", Types.PROMPT_USE_MAGIC_CAP, {}, Types.CARD_HEAL, true)
	(s["pending"] as Array).append(pr)
	assert_eq(H.err(s, Types.make_action_choose_targets("p2", int(pr["id"]), ["p1"])), Types.ERR_NOT_IMPLEMENTED)
	assert_eq(H.err(s, Types.make_action_decline("p1", int(pr["id"]))), Types.ERR_NOT_YOUR_DECISION)
	assert_eq(H.err(s, Types.make_action_decline("p2", 9999)), Types.ERR_PROMPT_NOT_FOUND)
	s = H.ok(self, s, Types.make_action_decline("p2", int(pr["id"])))
	assert_eq((s["pending"] as Array).size(), 0)


func test_resolve_spell_cancelled_goes_to_discard() -> void:
	var c: Dictionary = H._take_any(s, Types.CARD_FIREBALL)
	var spell: Dictionary = Types.make_spell(c, "p1", ["p2"])
	spell["cancelled"] = true
	var r: Dictionary = Game.resolve_spell(s, spell, [])
	assert_eq(r["error"], "")
	assert_eq(((s["discard"] as Array).back() as Dictionary)["iid"], c["iid"])
	assert_eq(H.player(s, "p2")["hp"], 10)

extends NemTest
## Tubería de modificadores (contrato T1).


func before_each() -> void:
	super.before_each()
	EffectRegistry.reset()


func _state() -> Dictionary:
	var s: Dictionary = Types.make_state()
	(s["players"] as Array).append(Types.make_player("a", "A"))
	(s["players"] as Array).append(Types.make_player("b", "B"))
	return s


func _fire(src: String, tgt: String, amount: int = 2, spell_iid: int = 10) -> Dictionary:
	return Types.make_mod_event("damage", amount, src, tgt, Types.ELEMENT_FIRE,
		Types.CARD_FIREBALL, spell_iid, true)


func test_outgoing_and_incoming() -> void:
	var s: Dictionary = _state()
	Modifiers.add(s, Types.make_modifier("wild_fire#1", Types.STAGE_OUTGOING, Types.OP_ADD, 1,
		"a", Types.SIDE_SOURCE, Types.ELEMENT_FIRE, Types.EXPIRES_WHILE_IN_PLAY, Types.CARD_WILD_FIRE, 1))
	Modifiers.add(s, Types.make_modifier("tiara#2", Types.STAGE_INCOMING, Types.OP_SUB, 1,
		"b", Types.SIDE_TARGET, Types.ELEMENT_FIRE, Types.EXPIRES_WHILE_IN_PLAY, Types.CARD_FIREPROOF_TIARA, 2))
	var ev: Dictionary = Modifiers.run_stages(s, Types.DAMAGE_STAGES, _fire("a", "b"))
	assert_eq(ev["amount"], 2)  # 2 +1 -1
	assert_eq(ev["applied"], ["wild_fire#1", "tiara#2"])
	# b ataca a a: no aplica ninguno.
	var ev2: Dictionary = Modifiers.run_stages(s, Types.DAMAGE_STAGES, _fire("b", "a"))
	assert_eq(ev2["amount"], 2)
	# Otro elemento: no aplica.
	var ice: Dictionary = _fire("a", "b")
	ice["element"] = Types.ELEMENT_ICE
	assert_eq(Modifiers.run_stages(s, Types.DAMAGE_STAGES, ice)["amount"], 2)


func test_prevent_redirect_and_spell_scope() -> void:
	var s: Dictionary = _state()
	var shield: Dictionary = Types.make_modifier("magic_shield#5", Types.STAGE_PREVENT, Types.OP_SUB, 2,
		"b", Types.SIDE_TARGET, "", Types.EXPIRES_SPELL, Types.CARD_MAGIC_SHIELD, 5)
	shield["spell_iid"] = 10
	Modifiers.add(s, shield)
	var mirror: Dictionary = Types.make_modifier("mirror#6", Types.STAGE_REDIRECT, Types.OP_REDIRECT, 2,
		"b", Types.SIDE_TARGET, "", Types.EXPIRES_SPELL, Types.CARD_MIRROR_SHIELD, 6)
	mirror["spell_iid"] = 10
	mirror["data"] = {"to": "a"}
	Modifiers.add(s, mirror)
	var ev: Dictionary = Modifiers.run_stages(s, Types.DAMAGE_STAGES, _fire("a", "b", 5))
	assert_eq(ev["amount"], 1)
	assert_eq(ev["prevented"], 2)
	assert_eq(ev["redirects"], [{"to": "a", "amount": 2}])
	# Otro hechizo: no aplica.
	assert_eq(Modifiers.run_stages(s, Types.DAMAGE_STAGES, _fire("a", "b", 5, 11))["amount"], 5)
	assert_eq(Modifiers.expire(s, Types.EXPIRES_SPELL, "", 10), 2)
	assert_eq((s["modifiers"] as Array).size(), 0)


func test_once_is_consumed_and_priority_order() -> void:
	var s: Dictionary = _state()
	var elixir: Dictionary = Types.make_modifier("elixir#s1", Types.STAGE_POTION, Types.OP_MUL, 2,
		"a", Types.SIDE_TARGET, "", Types.EXPIRES_ONCE, Types.CARD_POTENT_ELIXIR)
	elixir["priority"] = 10
	Modifiers.add(s, elixir)
	Modifiers.add(s, Types.make_modifier("shot#9", Types.STAGE_POTION, Types.OP_SUB, 1,
		"", Types.SIDE_ANY, "", Types.EXPIRES_NEXT_EVENT, Types.CARD_SHOT_GLASS, 9))
	var ev: Dictionary = Modifiers.run_stage(s, Types.STAGE_POTION,
		Types.make_mod_event("potion", 3, "a", "a"))
	assert_eq(ev["amount"], 4, "(3-1)*2: Shot Glass antes por prioridad")
	assert_eq((s["modifiers"] as Array).size(), 1, "el elixir se consumió")
	assert_eq(Modifiers.run_stage(s, Types.STAGE_POTION, Types.make_mod_event("potion", 3, "a", "a"))["amount"], 2)
	assert_eq(Modifiers.expire(s, Types.EXPIRES_NEXT_EVENT), 1)


func test_custom_handler_via_registry() -> void:
	var s: Dictionary = _state()
	EffectRegistry.register_modifier_handler("test_nem", func(st: Dictionary, _m: Dictionary, ev: Dictionary) -> Dictionary:
		var p: Dictionary = Types.get_player(st, String(ev["target"]))
		p["mana"] = int(p["mana"]) - int(ev["amount"])
		return ev)
	var m: Dictionary = Types.make_modifier("nem#1", Types.STAGE_AFTER_DAMAGE, Types.OP_CUSTOM, 0,
		"", Types.SIDE_ANY, "", Types.EXPIRES_NEXT_EVENT, Types.CARD_NOT_ENOUGH_MANA, 1)
	m["handler"] = "test_nem"
	Modifiers.add(s, m)
	Modifiers.run_stage(s, Types.STAGE_AFTER_DAMAGE, _fire("a", "b", 2))
	assert_eq(Types.get_player(s, "b")["mana"], -2)


func test_remove_by_source() -> void:
	var s: Dictionary = _state()
	Modifiers.add(s, Types.make_modifier("x#1", Types.STAGE_HAND_LIMIT, Types.OP_ADD, 1, "a",
		Types.SIDE_TARGET, "", Types.EXPIRES_WHILE_IN_PLAY, Types.CARD_SPELLBOOK, 1))
	Modifiers.add(s, Types.make_modifier("x#1", Types.STAGE_HAND_LIMIT, Types.OP_ADD, 2, "a",
		Types.SIDE_TARGET, "", Types.EXPIRES_WHILE_IN_PLAY, Types.CARD_SPELLBOOK, 1))
	assert_eq((s["modifiers"] as Array).size(), 1, "mismo id reemplaza")
	assert_eq(Modifiers.run_stage(s, Types.STAGE_HAND_LIMIT, Types.make_mod_event("hand_limit", 5, "a", "a"))["amount"], 7)
	assert_eq(Modifiers.remove_by_source(s, 1), 1)
	assert_true(Types.is_json_safe(s))

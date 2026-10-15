extends NemTest
## T6c: artefactos.

const H = preload("res://tests/fixtures/engine_helpers.gd")
const X = preload("res://tests/engine/effects/t6c_helpers.gd")

var s: Dictionary


func before_each() -> void:
	super.before_each()
	s = X.new_state()


func after_all() -> void:
	CardCatalog.load_json()
	EffectRegistry.reset()


func _artifact_iid(pid: String, card_id: String) -> int:
	for c: Variant in H.player(s, pid)["artifacts"]:
		var cd: Dictionary = c
		if cd["card_id"] == card_id:
			return int(cd["iid"])
	return -1


# --- Protección elemental --------------------------------------------------

func _protection_case(card_id: String, element: String, other: String) -> void:
	s = X.new_state()
	s = X.equip(self, s, "p2", card_id)
	assert_true(_artifact_iid("p2", card_id) >= 0, "%s en mesa" % card_id)
	var ev: Dictionary = X.spell_damage(s, "p1", "p2", 2, element)
	assert_eq(int(ev["amount"]), 1, "%s: −1 al daño de %s" % [card_id, element])
	assert_eq(X.hp(s, "p2"), 9)
	X.spell_damage(s, "p1", "p2", 2, other)
	assert_eq(X.hp(s, "p2"), 7, "%s: otro elemento sin reducción" % card_id)
	X.spell_damage(s, "p1", "p3", 2, element)
	assert_eq(X.hp(s, "p3"), 8, "solo protege a su dueño")
	X.valid(self, s)


func test_fireproof_tiara() -> void:
	_protection_case(Types.CARD_FIREPROOF_TIARA, Types.ELEMENT_FIRE, Types.ELEMENT_ICE)


func test_padded_boots() -> void:
	_protection_case(Types.CARD_PADDED_BOOTS, Types.ELEMENT_ICE, Types.ELEMENT_ELECTRIC)


func test_faradays_cloak() -> void:
	_protection_case(Types.CARD_FARADAYS_CLOAK, Types.ELEMENT_ELECTRIC, Types.ELEMENT_FIRE)


func test_protection_cost_read_from_catalog() -> void:
	for cid: String in [Types.CARD_FIREPROOF_TIARA, Types.CARD_PADDED_BOOTS, Types.CARD_FARADAYS_CLOAK]:
		s = X.new_state()
		var def: Dictionary = CardCatalog.get_def(cid)
		var iid: int = X.give(s, "p1", cid)
		var pay: Array = X.pay_for(s, "p1", cid)
		H.set_mana(s, "p1", int((def["cost"] as Dictionary)["mana"]) - 1)
		assert_eq(H.err(s, Types.make_action_play_card("p1", iid, [], pay)), Types.ERR_INSUFFICIENT_MANA)
		H.set_mana(s, "p1", int((def["cost"] as Dictionary)["mana"]))
		assert_eq(H.err(s, Types.make_action_play_card("p1", iid, [], [])), Types.ERR_INVALID_PAYMENT)
		s = X.play(self, s, Types.make_action_play_card("p1", iid, [], pay))
		assert_eq(X.mana(s, "p1"), 0)


func test_protection_does_not_apply_to_non_spell_damage() -> void:
	s = X.equip(self, s, "p2", Types.CARD_FIREPROOF_TIARA)
	var ev: Dictionary = Types.make_mod_event(Damage.KIND_DAMAGE, 2, "", "p2", Types.ELEMENT_FIRE, "")
	Damage.apply(s, ev, [])
	assert_eq(X.hp(s, "p2"), 8)


# --- Bonos elementales -----------------------------------------------------

func _bonus_case(card_id: String, element: String, other: String) -> void:
	s = X.new_state()
	s = X.equip(self, s, "p1", card_id)
	var ev: Dictionary = X.spell_damage(s, "p1", "p2", 2, element)
	assert_eq(int(ev["amount"]), 3, "%s: +1 a tus hechizos de %s" % [card_id, element])
	X.spell_damage(s, "p1", "p3", 2, other)
	assert_eq(X.hp(s, "p3"), 8, "%s: otro elemento sin bono" % card_id)
	X.spell_damage(s, "p2", "p3", 2, element)
	assert_eq(X.hp(s, "p3"), 6, "%s: solo los hechizos del dueño" % card_id)


func test_wild_fire() -> void:
	_bonus_case(Types.CARD_WILD_FIRE, Types.ELEMENT_FIRE, Types.ELEMENT_ICE)


func test_dragon_glass() -> void:
	_bonus_case(Types.CARD_DRAGON_GLASS, Types.ELEMENT_ICE, Types.ELEMENT_ELECTRIC)


func test_tesla_coil() -> void:
	_bonus_case(Types.CARD_TESLA_COIL, Types.ELEMENT_ELECTRIC, Types.ELEMENT_FIRE)


func test_wild_fire_vs_tiara_cancel_out() -> void:
	s = X.equip(self, s, "p1", Types.CARD_WILD_FIRE)
	s = X.equip(self, s, "p2", Types.CARD_FIREPROOF_TIARA)
	X.spell_damage(s, "p1", "p2", 2, Types.ELEMENT_FIRE)
	assert_eq(X.hp(s, "p2"), 8)


# --- Spellbook --------------------------------------------------------------

func test_spellbook_raises_hand_limit() -> void:
	assert_eq(Damage.hand_limit(s, "p1"), 5)
	s = X.equip(self, s, "p1", Types.CARD_SPELLBOOK)
	assert_eq(Damage.hand_limit(s, "p1"), 6)
	assert_eq(Damage.hand_limit(s, "p2"), 5)


func test_spellbook_duplicate_is_rejected() -> void:
	s = X.equip(self, s, "p1", Types.CARD_SPELLBOOK)
	H.force_turn(s, "p1")
	var iid: int = X.give(s, "p1", Types.CARD_SPELLBOOK)
	var pay: Array = X.pay_for(s, "p1", Types.CARD_SPELLBOOK)
	H.set_mana(s, "p1", 10)
	assert_eq(H.err(s, Types.make_action_play_card("p1", iid, [], pay)), Types.ERR_ARTIFACT_LIMIT)
	var plays: Array = Game.legal_actions(s, "p1").filter(func(a: Dictionary) -> bool:
		return a["type"] == Types.ACTION_PLAY_CARD and int(a["card"]) == iid)
	assert_eq(plays.size(), 0, "no aparece en las acciones legales")
	# Otro mago sí puede tener el suyo.
	s = X.equip(self, s, "p2", Types.CARD_SPELLBOOK)
	assert_eq(Damage.hand_limit(s, "p2"), 6)


# --- Magic Cap --------------------------------------------------------------

func test_magic_cap_avoids_damage_once() -> void:
	s = X.equip(self, s, "p2", Types.CARD_MAGIC_CAP)
	var cap: int = _artifact_iid("p2", Types.CARD_MAGIC_CAP)
	X.spell_damage(s, "p1", "p2", 3, Types.ELEMENT_FIRE)
	assert_eq(X.hp(s, "p2"), 10, "pérdida aplazada")
	var prs: Array = X.prompts_of(s, "p2", Types.PROMPT_USE_MAGIC_CAP)
	assert_eq(prs.size(), 1)
	var pr: Dictionary = prs[0]
	var uses: Array = Game.legal_actions(s, "p2").filter(func(a: Dictionary) -> bool:
		return a["type"] == Types.ACTION_USE_ARTIFACT)
	assert_eq(uses.size(), 1)
	s = H.ok(self, s, Types.make_action_use_artifact("p2", cap, [], [], {}, int(pr["id"])))
	assert_eq(X.hp(s, "p2"), 10)
	assert_eq(_artifact_iid("p2", Types.CARD_MAGIC_CAP), -1, "el Cap se descarta")
	assert_false(X.has_mod_from(s, Types.CARD_MAGIC_CAP))
	assert_eq((s["pending"] as Array).size(), 0)
	X.spell_damage(s, "p1", "p2", 3, Types.ELEMENT_FIRE)
	assert_eq(X.hp(s, "p2"), 7, "solo una vez")
	X.valid(self, s)


func test_magic_cap_decline_applies_loss() -> void:
	s = X.equip(self, s, "p2", Types.CARD_MAGIC_CAP)
	X.spell_damage(s, "p1", "p2", 3, Types.ELEMENT_FIRE)
	var pr: Dictionary = X.prompts_of(s, "p2", Types.PROMPT_USE_MAGIC_CAP)[0]
	s = H.ok(self, s, Types.make_action_decline("p2", int(pr["id"])))
	assert_eq(X.hp(s, "p2"), 7)
	assert_true(_artifact_iid("p2", Types.CARD_MAGIC_CAP) >= 0, "el Cap sigue en mesa")


func test_magic_cap_avoids_mana_loss() -> void:
	s = X.equip(self, s, "p2", Types.CARD_MAGIC_CAP)
	H.set_mana(s, "p2", 4)
	var cap: int = _artifact_iid("p2", Types.CARD_MAGIC_CAP)
	Damage.lose_mana(s, "p2", 3, [], "p1", Types.CARD_MANA_IMPLOSION)
	assert_eq(X.mana(s, "p2"), 4)
	var pr: Dictionary = X.prompts_of(s, "p2", Types.PROMPT_USE_MAGIC_CAP)[0]
	assert_eq(((pr["data"] as Dictionary)["loss"] as Dictionary)["kind"], Damage.KIND_MANA_LOSS)
	s = H.ok(self, s, Types.make_action_use_artifact("p2", cap, [], [], {}, int(pr["id"])))
	assert_eq(X.mana(s, "p2"), 4)


func test_magic_cap_decline_mana_loss_with_shortfall() -> void:
	s = X.equip(self, s, "p2", Types.CARD_MAGIC_CAP)
	H.set_mana(s, "p2", 1)
	Damage.lose_mana(s, "p2", 3, [], "p1", Types.CARD_MANA_IMPLOSION)
	var pr: Dictionary = X.prompts_of(s, "p2", Types.PROMPT_USE_MAGIC_CAP)[0]
	s = H.ok(self, s, Types.make_action_decline("p2", int(pr["id"])))
	assert_eq(X.mana(s, "p2"), 0)
	assert_eq(X.prompts_of(s, "p2", Types.PROMPT_MANA_SHORTFALL).size(), 1)


func test_magic_cap_use_without_prompt_fails() -> void:
	s = X.equip(self, s, "p2", Types.CARD_MAGIC_CAP)
	var cap: int = _artifact_iid("p2", Types.CARD_MAGIC_CAP)
	assert_eq(H.err(s, Types.make_action_use_artifact("p2", cap)), Types.ERR_INVALID_CHOICE)


func test_magic_cap_one_pending_prompt_per_cap() -> void:
	s = X.equip(self, s, "p2", Types.CARD_MAGIC_CAP)
	X.spell_damage(s, "p1", "p2", 2, Types.ELEMENT_FIRE)
	X.spell_damage(s, "p1", "p2", 1, Types.ELEMENT_FIRE)
	assert_eq(X.prompts_of(s, "p2", Types.PROMPT_USE_MAGIC_CAP).size(), 1)
	assert_eq(X.hp(s, "p2"), 9, "la segunda pérdida no se aplaza")


# --- Scroll of Elements -----------------------------------------------------

func test_scroll_of_elements_replaces_required_card_once() -> void:
	s = X.equip(self, s, "p1", Types.CARD_SCROLL_OF_ELEMENTS)
	var scroll: int = _artifact_iid("p1", Types.CARD_SCROLL_OF_ELEMENTS)
	H.force_turn(s, "p1")
	var book: int = X.give(s, "p1", Types.CARD_BOOK_EXCHANGE)
	H.set_mana(s, "p1", 3)
	var plays: Array = Game.legal_actions(s, "p1").filter(func(a: Dictionary) -> bool:
		return a["type"] == Types.ACTION_PLAY_CARD and int(a["card"]) == book and (a["payment"] as Array).has(scroll))
	assert_true(plays.size() > 0, "el Scroll aparece como pago legal")
	s = X.play(self, s, Types.make_action_play_card("p1", book, ["p2"], [scroll]))
	assert_eq(_artifact_iid("p1", Types.CARD_SCROLL_OF_ELEMENTS), -1, "se descarta tras usarlo")
	var top: Dictionary = (s["discard"] as Array).back()
	assert_true(int(top["iid"]) == scroll or int(top["iid"]) == book)
	X.valid(self, s)


func test_scroll_of_elements_cannot_pay_mana() -> void:
	s = X.equip(self, s, "p1", Types.CARD_SCROLL_OF_ELEMENTS)
	var scroll: int = _artifact_iid("p1", Types.CARD_SCROLL_OF_ELEMENTS)
	H.force_turn(s, "p1")
	var heal: int = X.give(s, "p1", Types.CARD_HEAL)
	H.set_mana(s, "p1", 2)
	assert_eq(H.err(s, Types.make_action_play_card("p1", heal, ["p1"], [scroll])), Types.ERR_INVALID_PAYMENT,
		"Heal no requiere cartas")


# --- Transformation Glove ---------------------------------------------------

func test_transformation_glove_once_per_turn() -> void:
	s = X.equip(self, s, "p1", Types.CARD_TRANSFORMATION_GLOVE)
	var glove: int = _artifact_iid("p1", Types.CARD_TRANSFORMATION_GLOVE)
	H.force_turn(s, "p1")
	var hand: Array = H.set_hand(s, "p1", [Types.CARD_FIREBALL, Types.CARD_HEAL])
	var uses: Array = Game.legal_actions(s, "p1").filter(func(a: Dictionary) -> bool:
		return a["type"] == Types.ACTION_USE_ARTIFACT)
	assert_eq(uses.size(), 2, "una por carta de la mano")
	s = H.ok(self, s, Types.make_action_use_artifact("p1", glove, [], [hand[0]]))
	assert_eq(H.hand(s, "p1").size(), 2)
	assert_eq(Deck.hand_index(H.player(s, "p1"), int(hand[0])), -1, "la carta se descartó")
	assert_eq(H.err(s, Types.make_action_use_artifact("p1", glove, [], [hand[1]])), Types.ERR_ARTIFACT_ALREADY_USED)
	assert_eq(Game.legal_actions(s, "p1").filter(func(a: Dictionary) -> bool:
		return a["type"] == Types.ACTION_USE_ARTIFACT).size(), 0)
	(s["turn"] as Dictionary)["number"] = int((s["turn"] as Dictionary)["number"]) + 3
	s = H.ok(self, s, Types.make_action_use_artifact("p1", glove, [], [hand[1]]))
	X.valid(self, s)


func test_transformation_glove_only_in_own_turn_and_valid_card() -> void:
	s = X.equip(self, s, "p1", Types.CARD_TRANSFORMATION_GLOVE)
	var glove: int = _artifact_iid("p1", Types.CARD_TRANSFORMATION_GLOVE)
	var hand: Array = H.set_hand(s, "p1", [Types.CARD_FIREBALL])
	H.force_turn(s, "p2")
	assert_eq(H.err(s, Types.make_action_use_artifact("p1", glove, [], [hand[0]])), Types.ERR_NOT_YOUR_TURN)
	H.force_turn(s, "p1")
	assert_eq(H.err(s, Types.make_action_use_artifact("p1", glove, [], [])), Types.ERR_INVALID_CHOICE)
	assert_eq(H.err(s, Types.make_action_use_artifact("p1", glove, [], [99999])), Types.ERR_CARD_NOT_IN_HAND)


# --- Twardowsky's Mirror ----------------------------------------------------

func test_twardowskys_mirror_peek_is_private_once_per_turn() -> void:
	s = X.equip(self, s, "p1", Types.CARD_TWARDOWSKYS_MIRROR)
	var mirror: int = _artifact_iid("p1", Types.CARD_TWARDOWSKYS_MIRROR)
	H.force_turn(s, "p1")
	var deck: Array = s["deck"]
	var top: Dictionary = deck.back()
	s = H.ok(self, s, Types.make_action_use_artifact("p1", mirror))
	var rv: Array = (s["reveals"] as Dictionary)["p1"]
	assert_eq(rv.size(), 1)
	assert_eq((rv[0] as Dictionary)["kind"], "deck_top")
	assert_eq(int((((rv[0] as Dictionary)["cards"] as Array)[0] as Dictionary)["iid"]), int(top["iid"]))
	assert_eq((s["deck"] as Array).size(), deck.size(), "no roba")
	assert_eq(Types.public_view(s)["reveals"], {})
	assert_false((Types.view_for(s, "p2")["reveals"] as Dictionary).has("p1"))
	for e: Variant in Types.public_view(s)["log"]:
		assert_false(((e as Dictionary)["data"] as Dictionary).has("seen"))
	assert_eq(H.err(s, Types.make_action_use_artifact("p1", mirror)), Types.ERR_ARTIFACT_ALREADY_USED)
	(s["turn"] as Dictionary)["number"] = int((s["turn"] as Dictionary)["number"]) + 3
	s = H.ok(self, s, Types.make_action_use_artifact("p1", mirror))
	assert_eq(((s["reveals"] as Dictionary)["p1"] as Array).size(), 1, "sustituye la revelación vieja")


func test_twardowskys_mirror_legal_action() -> void:
	s = X.equip(self, s, "p1", Types.CARD_TWARDOWSKYS_MIRROR)
	H.force_turn(s, "p1")
	var uses: Array = Game.legal_actions(s, "p1").filter(func(a: Dictionary) -> bool:
		return a["type"] == Types.ACTION_USE_ARTIFACT)
	assert_eq(uses.size(), 1)
	assert_eq(Game.legal_actions(s, "p2").filter(func(a: Dictionary) -> bool:
		return a["type"] == Types.ACTION_USE_ARTIFACT).size(), 0)


# --- Retirada de modificadores ----------------------------------------------

func test_discard_artifact_removes_its_modifiers() -> void:
	s = X.equip(self, s, "p1", Types.CARD_WILD_FIRE)
	var iid: int = _artifact_iid("p1", Types.CARD_WILD_FIRE)
	assert_true(ArtifactEffects.discard_artifact(s, "p1", iid))
	X.spell_damage(s, "p1", "p2", 2, Types.ELEMENT_FIRE)
	assert_eq(X.hp(s, "p2"), 8)
	X.valid(self, s)

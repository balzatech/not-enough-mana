extends NemTest
## T6c: cartas de soporte (Heal, Greater Heal, Book Exchange, Magic Hand,
## Potent Elixir, Space Shift).

const H = preload("res://tests/fixtures/engine_helpers.gd")
const X = preload("res://tests/engine/effects/t6c_helpers.gd")

var s: Dictionary


func before_each() -> void:
	super.before_each()
	s = X.new_state()


func after_all() -> void:
	CardCatalog.load_json()
	EffectRegistry.reset()


func test_heal_gains_one_and_caps_at_max() -> void:
	H.player(s, "p2")["hp"] = 5
	s = X.cast(self, s, "p1", Types.CARD_HEAL, ["p2"])
	assert_eq(X.hp(s, "p2"), 6)
	s = X.cast(self, s, "p1", Types.CARD_HEAL, ["p1"])
	assert_eq(X.hp(s, "p1"), 10, "tope 10")
	X.valid(self, s)


func test_greater_heal_gains_two_and_caps_at_max() -> void:
	H.player(s, "p2")["hp"] = 5
	s = X.cast(self, s, "p1", Types.CARD_GREATER_HEAL, ["p2"])
	assert_eq(X.hp(s, "p2"), 7)
	H.player(s, "p3")["hp"] = 9
	s = X.cast(self, s, "p1", Types.CARD_GREATER_HEAL, ["p3"])
	assert_eq(X.hp(s, "p3"), 10, "tope 10")


func test_heal_costs_two_mana() -> void:
	var iid: int = X.give(s, "p1", Types.CARD_HEAL)
	H.set_mana(s, "p1", 1)
	assert_eq(H.err(s, Types.make_action_play_card("p1", iid, ["p2"])), Types.ERR_INSUFFICIENT_MANA)
	H.set_mana(s, "p1", 2)
	s = X.play(self, s, Types.make_action_play_card("p1", iid, ["p2"]))
	assert_eq(X.mana(s, "p1"), 0)


func test_book_exchange_swaps_hands() -> void:
	var mine: Array = H.set_hand(s, "p1", [Types.CARD_HEAL, Types.CARD_FIREBALL])
	var theirs: Array = H.set_hand(s, "p2", [Types.CARD_BLIZZARD])
	var book: int = X.give(s, "p1", Types.CARD_BOOK_EXCHANGE)
	var bolt: int = X.give(s, "p1", Types.CARD_LIGHTNING)
	H.set_mana(s, "p1", 3)
	assert_eq(H.err(s, Types.make_action_play_card("p1", book, ["p1"], [bolt])), Types.ERR_INVALID_TARGET,
		"no puedes elegirte a ti mismo")
	s = X.play(self, s, Types.make_action_play_card("p1", book, ["p2"], [bolt]))
	var h1: Array = []
	for c: Variant in H.hand(s, "p1"):
		h1.append(int((c as Dictionary)["iid"]))
	var h2: Array = []
	for c: Variant in H.hand(s, "p2"):
		h2.append(int((c as Dictionary)["iid"]))
	assert_eq(h1, theirs)
	assert_eq(h2, mine)
	assert_eq(X.mana(s, "p1"), 0)
	X.valid(self, s)


func test_magic_hand_reveal_is_private_and_steals_one() -> void:
	var theirs: Array = H.set_hand(s, "p2", [Types.CARD_BLIZZARD, Types.CARD_FIREBALL])
	H.set_hand(s, "p1", [])
	s = X.cast(self, s, "p1", Types.CARD_MAGIC_HAND, ["p2"])
	var reveals: Array = (s["reveals"] as Dictionary).get("p1", [])
	assert_eq(reveals.size(), 1)
	var rv: Dictionary = reveals[0]
	assert_eq(rv["kind"], "hand")
	assert_eq(rv["of"], "p2")
	assert_eq((rv["cards"] as Array).size(), 2)
	# Nada de lo visto en la vista pública ni en la de otro jugador.
	var pub: Dictionary = Types.public_view(s)
	assert_eq(pub["reveals"], {})
	for e: Variant in pub["log"]:
		assert_false(((e as Dictionary)["data"] as Dictionary).has("seen"), "lo visto no va al log público")
	var v3: Dictionary = Types.view_for(s, "p3")
	assert_false((v3["reveals"] as Dictionary).has("p1"))
	for e: Variant in v3["log"]:
		assert_false(((e as Dictionary)["data"] as Dictionary).has("seen"))
	var seen_priv: bool = false
	for e: Variant in Types.private_view(s, "p1")["log"]:
		seen_priv = seen_priv or ((e as Dictionary)["data"] as Dictionary).has("seen")
	assert_true(seen_priv, "el lanzador ve las cartas en su log privado")
	var v1: Dictionary = Types.view_for(s, "p1")
	assert_eq(((v1["reveals"] as Dictionary)["p1"] as Array).size(), 1)
	# El prompt público no lleva las iids.
	var prs: Array = X.prompts_of(s, "p1", Types.PROMPT_CHOOSE_CARD)
	assert_eq(prs.size(), 1)
	var pr: Dictionary = prs[0]
	assert_eq((pr["data"] as Dictionary)["cards"], [])
	# Acciones legales: una por carta de la mano ajena.
	var choose: Array = Game.legal_actions(s, "p1").filter(func(a: Dictionary) -> bool:
		return a["type"] == Types.ACTION_CHOOSE_CARDS)
	assert_eq(choose.size(), 2)
	assert_eq(H.err(s, Types.make_action_choose_cards("p1", int(pr["id"]), [12345])), Types.ERR_INVALID_CHOICE)
	assert_eq(H.err(s, Types.make_action_decline("p1", int(pr["id"]))), Types.ERR_INVALID_CHOICE)
	s = H.ok(self, s, Types.make_action_choose_cards("p1", int(pr["id"]), [theirs[1]]))
	assert_eq(H.hand(s, "p1").size(), 1)
	assert_eq(int((H.hand(s, "p1")[0] as Dictionary)["iid"]), int(theirs[1]))
	assert_eq(H.hand(s, "p2").size(), 1)
	assert_eq((s["pending"] as Array).size(), 0)
	X.valid(self, s)


func test_magic_hand_on_empty_hand_has_no_prompt() -> void:
	H.set_hand(s, "p2", [])
	s = X.cast(self, s, "p1", Types.CARD_MAGIC_HAND, ["p2"])
	assert_eq((s["pending"] as Array).size(), 0)


func test_potent_elixir_doubles_next_potion() -> void:
	s = X.cast(self, s, "p1", Types.CARD_POTENT_ELIXIR)
	assert_eq(int((H.player(s, "p1")["flags"] as Dictionary)["potent_elixir"]), 1)
	H.set_mana(s, "p1", 0)
	s = H.ok(self, s, Types.make_action_drink_potion("p1"))
	assert_eq(X.mana(s, "p1"), 6)
	s = H.ok(self, s, Types.make_action_drink_potion("p1"))
	assert_eq(X.mana(s, "p1"), 9, "solo la siguiente poción")


func test_space_shift_discards_hand_and_draws_full_hand() -> void:
	var old: Array = H.set_hand(s, "p1", [Types.CARD_FIREBALL, Types.CARD_BLIZZARD])
	s = X.cast(self, s, "p1", Types.CARD_SPACE_SHIFT)
	var hand: Array = H.hand(s, "p1")
	assert_eq(hand.size(), Damage.hand_limit(s, "p1"))
	var discard_ids: Array = []
	for c: Variant in s["discard"]:
		discard_ids.append(int((c as Dictionary)["iid"]))
	for iid: Variant in old:
		assert_true(discard_ids.has(int(iid)), "carta vieja al descarte")
	X.valid(self, s)

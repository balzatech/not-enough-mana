extends GutTest
## T6c: maldiciones (Rules, Elder, Younger, Vigour, Even, Odd) y Runic Armor.
## Jugadores: p1 40 años (enero), p2 30 (febrero), p3 20 (marzo).

const H = preload("res://tests/fixtures/engine_helpers.gd")
const X = preload("res://tests/engine/effects/t6c_helpers.gd")

var s: Dictionary


func before_each() -> void:
	s = X.new_state()
	for pid: String in ["p1", "p2", "p3"]:
		H.set_mana(s, pid, 5)


func after_all() -> void:
	CardCatalog.load_json()
	EffectRegistry.reset()


func _manas() -> Array:
	return [X.mana(s, "p1"), X.mana(s, "p2"), X.mana(s, "p3")]


# --- Curse of Rules ----------------------------------------------------------

func test_curse_of_rules_is_persistent_with_text_and_break_rule_costs_one() -> void:
	s = X.cast(self, s, "p1", Types.CARD_CURSE_OF_RULES, [], {"rule": "  no swearing  "})
	var curses: Array = H.player(s, "p1")["curses"]
	assert_eq(curses.size(), 1)
	var tc: Dictionary = curses[0]
	assert_eq(tc["card_id"], Types.CARD_CURSE_OF_RULES)
	assert_eq((tc["data"] as Dictionary)["rule"], "no swearing")
	var iid: int = tc["iid"]
	s = H.ok(self, s, Types.make_action_break_rule("p2", "p3", iid))
	assert_eq(X.mana(s, "p3"), 4)
	s = H.ok(self, s, Types.make_action_break_rule("p2", "p1", iid))
	assert_eq(X.mana(s, "p1"), 4, "afecta también a quien la lanzó")
	X.valid(self, s)


func test_curse_of_rules_legal_break_rule_actions() -> void:
	s = X.cast(self, s, "p1", Types.CARD_CURSE_OF_RULES, [], {"rule": "x"})
	var br: Array = Game.legal_actions(s, "p2").filter(func(a: Dictionary) -> bool:
		return a["type"] == Types.ACTION_BREAK_RULE)
	assert_eq(br.size(), 2)


func test_curse_of_rules_rule_text_is_capped() -> void:
	var long: String = "a".repeat(500)
	s = X.cast(self, s, "p1", Types.CARD_CURSE_OF_RULES, [], {"rule": long})
	var tc: Dictionary = (H.player(s, "p1")["curses"] as Array)[0]
	assert_eq(String((tc["data"] as Dictionary)["rule"]).length(), CurseEffects.MAX_RULE_LENGTH)


func test_can_report_rule_break_online_only_host_or_self() -> void:
	assert_true(CurseEffects.can_report_rule_break(s, "p2", "p3", "p1"), "local: cualquiera")
	(s["config"] as Dictionary)["mode"] = "online"
	assert_true(CurseEffects.can_report_rule_break(s, "p1", "p3", "p1"), "anfitrión")
	assert_true(CurseEffects.can_report_rule_break(s, "p3", "p3", "p1"), "el propio afectado")
	assert_false(CurseEffects.can_report_rule_break(s, "p2", "p3", "p1"), "un tercero no")


func test_runic_armor_blocks_break_rule() -> void:
	s = X.equip(self, s, "p3", Types.CARD_RUNIC_ARMOR)
	s = X.cast(self, s, "p1", Types.CARD_CURSE_OF_RULES, [], {"rule": "x"})
	var iid: int = int(((H.player(s, "p1")["curses"] as Array)[0] as Dictionary)["iid"])
	s = H.ok(self, s, Types.make_action_break_rule("p1", "p3", iid))
	assert_eq(X.mana(s, "p3"), 5)


# --- Elder / Younger -------------------------------------------------------

func test_curse_of_the_elder_hits_strictly_older() -> void:
	s = X.cast(self, s, "p2", Types.CARD_CURSE_OF_THE_ELDER)
	assert_eq(_manas(), [2, 5, 5])


func test_curse_of_the_younger_hits_strictly_younger() -> void:
	s = X.cast(self, s, "p2", Types.CARD_CURSE_OF_THE_YOUNGER)
	assert_eq(_manas(), [5, 5, 2])


func test_elder_and_younger_same_age_not_affected() -> void:
	H.player(s, "p3")["age"] = 30
	H.player(s, "p3")["birth_month"] = 12
	s = X.cast(self, s, "p2", Types.CARD_CURSE_OF_THE_ELDER)
	assert_eq(_manas(), [2, 5, 5], "misma edad: no afectado (sin desempate por mes)")
	s = X.cast(self, s, "p2", Types.CARD_CURSE_OF_THE_YOUNGER)
	assert_eq(_manas(), [2, 5, 5])


# --- Vigour / Even / Odd ---------------------------------------------------

func test_curse_of_vigour_includes_caster() -> void:
	H.player(s, "p1")["hp"] = 10
	H.player(s, "p2")["hp"] = 5
	H.player(s, "p3")["hp"] = 4
	s = X.cast(self, s, "p2", Types.CARD_CURSE_OF_VIGOUR)
	assert_eq(_manas(), [2, 2, 5])


func test_curse_of_even_uses_birth_month() -> void:
	s = X.cast(self, s, "p1", Types.CARD_CURSE_OF_EVEN)
	assert_eq(_manas(), [5, 2, 5])


func test_curse_of_odd_uses_birth_month_and_includes_caster() -> void:
	s = X.cast(self, s, "p1", Types.CARD_CURSE_OF_ODD)
	assert_eq(_manas(), [2, 5, 2])


func test_curse_mana_shortfall_opens_prompt() -> void:
	H.set_mana(s, "p3", 1)
	s = X.cast(self, s, "p2", Types.CARD_CURSE_OF_THE_YOUNGER)
	assert_eq(X.mana(s, "p3"), 0)
	var prs: Array = X.prompts_of(s, "p3", Types.PROMPT_MANA_SHORTFALL)
	assert_eq(prs.size(), 1)
	assert_eq(int(((prs[0] as Dictionary)["data"] as Dictionary)["missing"]), 2)


func test_curse_skips_force_field() -> void:
	(H.player(s, "p3")["flags"] as Dictionary)["force_field"] = "p2"
	s = X.cast(self, s, "p2", Types.CARD_CURSE_OF_THE_YOUNGER)
	assert_eq(X.mana(s, "p3"), 5)


func test_curse_skips_eliminated() -> void:
	H.player(s, "p3")["eliminated"] = true
	s = X.cast(self, s, "p1", Types.CARD_CURSE_OF_ODD)
	assert_eq(X.mana(s, "p3"), 5)


# --- Runic Armor contra cada maldición -------------------------------------

func _armor_case(caster: String, curse: String, armored: String) -> void:
	s = X.new_state()
	for pid: String in ["p1", "p2", "p3"]:
		H.set_mana(s, pid, 5)
	H.player(s, "p1")["hp"] = 10
	H.player(s, "p2")["hp"] = 5
	H.player(s, "p3")["hp"] = 10
	s = X.equip(self, s, armored, Types.CARD_RUNIC_ARMOR)
	assert_true(X.has_mod_from(s, Types.CARD_RUNIC_ARMOR))
	s = X.cast(self, s, caster, curse)
	assert_eq(X.mana(s, armored), 5, "%s: Runic Armor protege a %s" % [curse, armored])


func test_runic_armor_vs_elder() -> void:
	_armor_case("p2", Types.CARD_CURSE_OF_THE_ELDER, "p1")


func test_runic_armor_vs_younger() -> void:
	_armor_case("p2", Types.CARD_CURSE_OF_THE_YOUNGER, "p3")
	assert_eq(X.mana(s, "p1"), 5)


func test_runic_armor_vs_vigour() -> void:
	_armor_case("p2", Types.CARD_CURSE_OF_VIGOUR, "p3")
	assert_eq(X.mana(s, "p1"), 2, "los no protegidos sí pierden")


func test_runic_armor_vs_even() -> void:
	_armor_case("p1", Types.CARD_CURSE_OF_EVEN, "p2")


func test_runic_armor_vs_odd() -> void:
	_armor_case("p2", Types.CARD_CURSE_OF_ODD, "p3")
	assert_eq(X.mana(s, "p1"), 2)


func test_runic_armor_does_not_block_other_losses() -> void:
	s = X.equip(self, s, "p3", Types.CARD_RUNIC_ARMOR)
	Damage.lose_mana(s, "p3", 2, [], "p1", Types.CARD_MANA_IMPLOSION)
	assert_eq(X.mana(s, "p3"), 3)
	X.spell_damage(s, "p1", "p3", 2, Types.ELEMENT_FIRE)
	assert_eq(X.hp(s, "p3"), 8)

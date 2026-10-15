extends NemTest
## T6a: efectos de fuego (Fire Arrow, Fireball, Meteor Shower, Armageddon,
## Mana Implosion) con el catálogo real.

const OH = preload("res://tests/engine/effects/offensive_helpers.gd")
const H = preload("res://tests/fixtures/engine_helpers.gd")

var s: Dictionary


func before_all() -> void:
	CardCatalog.load_json()


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


# --- Registro ----------------------------------------------------------------

func test_fire_cards_registered() -> void:
	for id: String in [Types.CARD_FIRE_ARROW, Types.CARD_FIREBALL, Types.CARD_METEOR_SHOWER,
			Types.CARD_ARMAGEDDON, Types.CARD_MANA_IMPLOSION]:
		assert_true(EffectRegistry.has_effect(id), id)


# --- Fire Arrow --------------------------------------------------------------

func test_fire_arrow_base() -> void:
	var r: Dictionary = OH.cast(s, "p1", Types.CARD_FIRE_ARROW, ["p2"])
	_ok(r)
	assert_eq(OH.hp(s, "p2"), 9)
	assert_eq(OH.hp(s, "p1"), 10)
	var dmg: Array = OH.events_of(r["events"], Types.LOG_DAMAGE)
	assert_eq(dmg.size(), 1)
	assert_eq((dmg[0] as Dictionary)["data"]["element"], Types.ELEMENT_FIRE)
	assert_eq((s["discard"] as Array).back()["iid"], r["iid"], "la carta va al descarte")


func test_fire_arrow_self() -> void:
	_ok(OH.cast(s, "p1", Types.CARD_FIRE_ARROW, ["p1"]))
	assert_eq(OH.hp(s, "p1"), 9)


func test_fire_arrow_eliminated_target() -> void:
	OH.kill(s, "p2")
	assert_eq(OH.play_error(s, "p1", Types.CARD_FIRE_ARROW, ["p2"]), Types.ERR_INVALID_TARGET)
	var r: Dictionary = OH.cast(s, "p1", Types.CARD_FIRE_ARROW, ["p2"])
	_ok(r)
	assert_eq(OH.hp(s, "p2"), 0)
	assert_eq(OH.events_of(r["events"], Types.LOG_DAMAGE).size(), 0)
	assert_eq(OH.events_of(r["events"], Types.LOG_EFFECT, "fizzled").size(), 1)


func test_fire_arrow_kills() -> void:
	OH.set_hp(s, "p2", 1)
	var r: Dictionary = OH.cast(s, "p1", Types.CARD_FIRE_ARROW, ["p2"])
	_ok(r)
	assert_true(OH.eliminated(s, "p2"))
	assert_eq(Types.get_player(s, "p2")["eliminated_reason"], Types.ELIM_HP)
	assert_eq(OH.events_of(r["events"], Types.LOG_ELIMINATED).size(), 1)


func test_damage_goes_through_modifiers() -> void:
	# Un "artefacto" falso de fuego (+1 saliente) y una "tiara" falsa (−1 entrante).
	OH.add_mod(s, "fake_wild_fire", Types.STAGE_OUTGOING, Types.OP_ADD, 1, Types.ELEMENT_FIRE,
		Types.SIDE_SOURCE, "p1")
	_ok(OH.cast(s, "p1", Types.CARD_FIRE_ARROW, ["p2"]))
	assert_eq(OH.hp(s, "p2"), 8)
	OH.add_mod(s, "fake_tiara", Types.STAGE_INCOMING, Types.OP_SUB, 1, Types.ELEMENT_FIRE,
		Types.SIDE_TARGET, "p3")
	_ok(OH.cast(s, "p1", Types.CARD_FIREBALL, ["p3"]))
	assert_eq(OH.hp(s, "p3"), 8, "2 +1 −1")
	# Un modificador de otro elemento no toca al fuego.
	OH.add_mod(s, "fake_ice", Types.STAGE_OUTGOING, Types.OP_ADD, 5, Types.ELEMENT_ICE)
	_ok(OH.cast(s, "p2", Types.CARD_FIRE_ARROW, ["p4"]))
	assert_eq(OH.hp(s, "p4"), 9)


func test_damage_prevented_by_fake_shield() -> void:
	OH.add_mod(s, "fake_shield", Types.STAGE_PREVENT, Types.OP_PREVENT_ALL, 0, "", Types.SIDE_TARGET, "p2")
	var r: Dictionary = OH.cast(s, "p1", Types.CARD_FIREBALL, ["p2"])
	_ok(r)
	assert_eq(OH.hp(s, "p2"), 10)
	var dmg: Dictionary = OH.events_of(r["events"], Types.LOG_DAMAGE)[0]
	assert_eq(dmg["data"]["prevented"], 2)


# --- Fireball ----------------------------------------------------------------

func test_fireball_base() -> void:
	_ok(OH.cast(s, "p1", Types.CARD_FIREBALL, ["p3"]))
	assert_eq(OH.hp(s, "p3"), 8)


func test_fireball_self() -> void:
	_ok(OH.cast(s, "p1", Types.CARD_FIREBALL, ["p1"]))
	assert_eq(OH.hp(s, "p1"), 8)


func test_fireball_eliminated_target() -> void:
	OH.kill(s, "p3")
	assert_eq(OH.play_error(s, "p1", Types.CARD_FIREBALL, ["p3"]), Types.ERR_INVALID_TARGET)
	_ok(OH.cast(s, "p1", Types.CARD_FIREBALL, ["p3"]))
	assert_eq(OH.hp(s, "p1"), 10)


func test_fireball_kills_with_overkill() -> void:
	OH.set_hp(s, "p3", 1)
	var r: Dictionary = OH.cast(s, "p1", Types.CARD_FIREBALL, ["p3"])
	_ok(r)
	assert_true(OH.eliminated(s, "p3"))
	assert_eq(OH.hp(s, "p3"), 0)
	assert_eq((OH.events_of(r["events"], Types.LOG_DAMAGE)[0] as Dictionary)["data"]["dealt"], 1)


# --- Meteor Shower -------------------------------------------------------------

func test_meteor_shower_base() -> void:
	_ok(OH.cast(s, "p1", Types.CARD_METEOR_SHOWER, ["p3"]))
	assert_eq(OH.hp(s, "p3"), 8)
	assert_eq(OH.hp(s, "p2"), 9)
	assert_eq(OH.hp(s, "p4"), 9)
	assert_eq(OH.hp(s, "p1"), 10)


func test_meteor_shower_hits_caster_when_neighbor() -> void:
	_ok(OH.cast(s, "p1", Types.CARD_METEOR_SHOWER, ["p2"]))
	assert_eq(OH.hp(s, "p2"), 8)
	assert_eq(OH.hp(s, "p1"), 9)
	assert_eq(OH.hp(s, "p3"), 9)
	assert_eq(OH.hp(s, "p4"), 10)


func test_meteor_shower_wraps_around_table() -> void:
	_ok(OH.cast(s, "p2", Types.CARD_METEOR_SHOWER, ["p1"]))
	assert_eq(OH.hp(s, "p1"), 8)
	assert_eq(OH.hp(s, "p4"), 9, "p4 está sentado junto a p1")
	assert_eq(OH.hp(s, "p2"), 9)
	assert_eq(OH.hp(s, "p3"), 10)


func test_meteor_shower_self() -> void:
	_ok(OH.cast(s, "p1", Types.CARD_METEOR_SHOWER, ["p1"]))
	assert_eq(OH.hp(s, "p1"), 8)
	assert_eq(OH.hp(s, "p2"), 9)
	assert_eq(OH.hp(s, "p4"), 9)
	assert_eq(OH.hp(s, "p3"), 10)


func test_meteor_shower_skips_eliminated_neighbors() -> void:
	OH.kill(s, "p2")
	_ok(OH.cast(s, "p4", Types.CARD_METEOR_SHOWER, ["p3"]))
	assert_eq(OH.hp(s, "p3"), 8)
	assert_eq(OH.hp(s, "p1"), 9, "p1 es el vecino vivo tras eliminar a p2")
	assert_eq(OH.hp(s, "p4"), 9)


func test_meteor_shower_two_players_single_neighbor() -> void:
	s = OH.make_state(2)
	_ok(OH.cast(s, "p1", Types.CARD_METEOR_SHOWER, ["p2"]))
	assert_eq(OH.hp(s, "p2"), 8)
	assert_eq(OH.hp(s, "p1"), 9, "el único vecino recibe 1 sola vez")


func test_meteor_shower_eliminated_target() -> void:
	OH.kill(s, "p3")
	assert_eq(OH.play_error(s, "p1", Types.CARD_METEOR_SHOWER, ["p3"]), Types.ERR_INVALID_TARGET)
	var r: Dictionary = OH.cast(s, "p1", Types.CARD_METEOR_SHOWER, ["p3"])
	_ok(r)
	assert_eq(OH.hp(s, "p2"), 10)
	assert_eq(OH.hp(s, "p4"), 10)
	assert_eq(OH.events_of(r["events"], Types.LOG_EFFECT, "fizzled").size(), 1)


func test_meteor_shower_kills_target_still_hits_neighbors() -> void:
	OH.set_hp(s, "p3", 2)
	OH.set_hp(s, "p4", 1)
	_ok(OH.cast(s, "p1", Types.CARD_METEOR_SHOWER, ["p3"]))
	assert_true(OH.eliminated(s, "p3"))
	assert_true(OH.eliminated(s, "p4"))
	assert_eq(OH.hp(s, "p2"), 9)


func test_meteor_shower_neighbors_with_modifier() -> void:
	OH.add_mod(s, "fake_storm", Types.STAGE_OUTGOING, Types.OP_ADD, 1, Types.ELEMENT_FIRE)
	_ok(OH.cast(s, "p1", Types.CARD_METEOR_SHOWER, ["p3"]))
	assert_eq(OH.hp(s, "p3"), 7)
	assert_eq(OH.hp(s, "p2"), 8)
	assert_eq(OH.hp(s, "p4"), 8)


# --- Armageddon ----------------------------------------------------------------

func test_armageddon_base_includes_caster() -> void:
	_ok(OH.cast(s, "p1", Types.CARD_ARMAGEDDON, ["p1", "p2", "p3", "p4"]))
	for pid: String in ["p1", "p2", "p3", "p4"]:
		assert_eq(OH.hp(s, pid), 7, pid)


func test_armageddon_without_targets_uses_all_alive() -> void:
	_ok(OH.cast(s, "p2", Types.CARD_ARMAGEDDON, []))
	for pid: String in ["p1", "p2", "p3", "p4"]:
		assert_eq(OH.hp(s, pid), 7, pid)


func test_armageddon_skips_eliminated() -> void:
	OH.kill(s, "p3")
	var r: Dictionary = OH.cast(s, "p1", Types.CARD_ARMAGEDDON, ["p1", "p2", "p3", "p4"])
	_ok(r)
	assert_eq(OH.hp(s, "p3"), 0)
	assert_eq(OH.events_of(r["events"], Types.LOG_DAMAGE).size(), 3)


func test_armageddon_kills_caster_and_others() -> void:
	OH.set_hp(s, "p1", 3)
	OH.set_hp(s, "p2", 2)
	_ok(OH.cast(s, "p1", Types.CARD_ARMAGEDDON, ["p1", "p2", "p3", "p4"]))
	assert_true(OH.eliminated(s, "p1"))
	assert_true(OH.eliminated(s, "p2"))
	assert_eq(OH.hp(s, "p3"), 7)


func test_armageddon_kills_everyone_is_draw() -> void:
	for pid: String in ["p1", "p2", "p3", "p4"]:
		OH.set_hp(s, pid, 3)
	var events: Array = []
	_ok(OH.cast(s, "p1", Types.CARD_ARMAGEDDON, ["p1", "p2", "p3", "p4"]))
	Game._finalize(s, events)
	assert_eq(s["status"], Types.STATUS_FINISHED)
	assert_eq(s["winners"], [])


# --- Mana Implosion ----------------------------------------------------------------

func test_mana_implosion_base() -> void:
	_ok(OH.cast(s, "p1", Types.CARD_MANA_IMPLOSION, ["p2"]))
	assert_eq(OH.hp(s, "p2"), 8)
	assert_eq(OH.mana(s, "p2"), 8)


func test_mana_implosion_shortfall_prompt() -> void:
	Types.get_player(s, "p2")["mana"] = 1
	_ok(OH.cast(s, "p1", Types.CARD_MANA_IMPLOSION, ["p2"]))
	assert_eq(OH.mana(s, "p2"), 0)
	var prs: Array = OH.prompts(s, "p2", Types.PROMPT_MANA_SHORTFALL)
	assert_eq(prs.size(), 1)
	assert_eq((prs[0] as Dictionary)["data"]["missing"], 1)


func test_mana_implosion_self() -> void:
	_ok(OH.cast(s, "p1", Types.CARD_MANA_IMPLOSION, ["p1"]))
	assert_eq(OH.hp(s, "p1"), 8)
	assert_eq(OH.mana(s, "p1"), 8)


func test_mana_implosion_eliminated_target() -> void:
	OH.kill(s, "p2")
	assert_eq(OH.play_error(s, "p1", Types.CARD_MANA_IMPLOSION, ["p2"]), Types.ERR_INVALID_TARGET)
	_ok(OH.cast(s, "p1", Types.CARD_MANA_IMPLOSION, ["p2"]))
	assert_eq(OH.mana(s, "p2"), 10)


func test_mana_implosion_kills_no_mana_loss_nor_prompt() -> void:
	OH.set_hp(s, "p2", 2)
	Types.get_player(s, "p2")["mana"] = 0
	_ok(OH.cast(s, "p1", Types.CARD_MANA_IMPLOSION, ["p2"]))
	assert_true(OH.eliminated(s, "p2"))
	assert_eq(OH.prompts(s, "p2", Types.PROMPT_MANA_SHORTFALL).size(), 0)


func test_mana_loss_is_not_elemental() -> void:
	# Un bono de fuego afecta al daño pero no a la pérdida de maná.
	OH.add_mod(s, "fake_storm", Types.STAGE_OUTGOING, Types.OP_ADD, 1, Types.ELEMENT_FIRE)
	_ok(OH.cast(s, "p1", Types.CARD_MANA_IMPLOSION, ["p2"]))
	assert_eq(OH.hp(s, "p2"), 7)
	assert_eq(OH.mana(s, "p2"), 8)


# --- Force Field en área ---------------------------------------------------------

func test_area_damage_respects_force_field() -> void:
	OH.flags(s, "p3")["force_field"] = "p3"
	_ok(OH.cast(s, "p1", Types.CARD_ARMAGEDDON, []))
	assert_eq(OH.hp(s, "p3"), 10)
	assert_eq(OH.hp(s, "p2"), 7)

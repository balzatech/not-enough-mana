extends GutTest
## Regresiones de la estabilización tras la oleada 2 (T4).

const H = preload("res://tests/fixtures/engine_helpers.gd")

var s: Dictionary


func before_each() -> void:
	EffectRegistry.reset()
	H.use_fixture_catalog()
	H.register_fake_effects()
	s = H.game(3, {}, 5, [50, 40, 30])


func after_all() -> void:
	EffectRegistry.reset()
	CardCatalog.load_json()


## Origen de los "Out of bounds get index '0'" en defensive.gd (_protect,
## check_response, mirror_shield): el catálogo de prueba daba target "none" a
## Magic Shield / Mirror Shield / Frozen Bunny, Reactions aceptaba targets = []
## y el efecto leía targets[0]. Ahora la fixture copia los metadatos reales…
func test_fixture_metadata_matches_real_catalog() -> void:
	var real: Dictionary = H.CardsFixture.real_defs()
	if real.is_empty():
		pass_test("sin data/cards.json")
		return
	for d: Variant in H.CardsFixture.defs():
		var dd: Dictionary = d
		var r: Dictionary = real[dd["id"]]
		for k: String in ["type", "element", "target", "is_spell", "persistent", "defensive", "playable"]:
			assert_eq(dd[k], r[k], "%s.%s" % [dd["id"], k])


## …y las defensivas que exigen objetivo rechazan targets = [] en vez de romper.
func test_defensive_without_target_is_rejected_not_crashing() -> void:
	for cid: String in [Types.CARD_MAGIC_SHIELD, Types.CARD_MIRROR_SHIELD, Types.CARD_FROZEN_BUNNY]:
		var card: Dictionary = Types.make_card_instance(999, cid)
		var ctx: Dictionary = Types.make_effect_ctx(card, CardCatalog.get_def(cid), "p2", [])
		DefensiveEffects.check_response(s, ctx)
		assert_eq(ctx["error"], Types.ERR_INVALID_TARGET, cid)
		# Al resolverse (respuesta ligada a un hechizo) tampoco indexa targets[0].
		var resp: Dictionary = Types.make_spell(card, "p2", [], {}, true)
		(resp["data"] as Dictionary)["spell_iid"] = 1
		var rctx: Dictionary = Types.make_effect_ctx(card, CardCatalog.get_def(cid), "p2", [])
		rctx["spell"] = resp
		rctx["is_response"] = true
		EffectRegistry.get_effect(cid).call(s, rctx)
		assert_eq(rctx["error"], Types.ERR_INVALID_TARGET, cid + " (efecto)")


func test_window_closes_when_only_responder_is_eliminated() -> void:
	var iids: Array = H.set_hand(s, "p1", [Types.CARD_FIREBALL])
	H.set_hand(s, "p3", [])
	H.set_hand(s, "p2", [Types.CARD_MAGIC_SHIELD])
	H.set_mana(s, "p1", 2)
	H.set_mana(s, "p2", 5)
	s = H.ok(self, s, Types.make_action_play_card("p1", int(iids[0]), ["p3"]))
	var re: Dictionary = s["reaction"]
	assert_eq(re.get("awaiting", []), ["p2"])
	# p2 se rinde: Game._finalize llama a Reactions.sync y el hechizo se resuelve.
	s = H.ok(self, s, Types.make_action_concede("p2"))
	assert_true((s["reaction"] as Dictionary).is_empty())
	assert_eq(H.player(s, "p3")["hp"], 8)
	assert_eq(Types.validate_state(s), [] as Array[String])


func test_resolve_spell_is_atomic_on_error() -> void:
	EffectRegistry.register(Types.CARD_HEAL, func(st: Dictionary, ctx: Dictionary) -> Dictionary:
		Damage.lose_hp(st, "p3", 4, ctx["events"])
		ctx["error"] = Types.ERR_INVALID_TARGET
		return st)
	var c: Dictionary = H._take_any(s, Types.CARD_HEAL)
	var before: Dictionary = s.duplicate(true)
	var events: Array = []
	var r: Dictionary = Game.resolve_spell(s, Types.make_spell(c, "p1", ["p1"]), events)
	assert_eq(r["error"], Types.ERR_INVALID_TARGET)
	assert_eq(s, before)
	assert_eq(events, [])

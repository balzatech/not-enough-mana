extends NemTest
## T4: simulación de partidas con acciones legales aleatorias, invariantes del
## estado y JSON ida y vuelta.
##
## Normalización JSON: JSON.parse_string devuelve todos los números como float;
## Types.normalize_state() los convierte a int (y restaura []/{} vacíos), así que
## normalize_state(parse(stringify(s))) == s para cualquier estado del motor.

const H = preload("res://tests/fixtures/engine_helpers.gd")

const GAMES: int = 100
const MAX_STEPS: int = 300

## Peso de cada tipo de acción al elegir al azar (para que las partidas avancen).
const WEIGHTS: Dictionary = {
	Types.ACTION_PLAY_CARD: 12,
	Types.ACTION_END_TURN: 4,
	Types.ACTION_DRINK_POTION: 3,
	Types.ACTION_EXCHANGE: 2,
	Types.ACTION_DISCARD: 1,
	Types.ACTION_CHOOSE_CARDS: 10,
	Types.ACTION_DECLINE: 10,
	Types.ACTION_BREAK_RULE: 1,
	Types.ACTION_CONCEDE: 0,
}


func before_each() -> void:
	super.before_each()
	EffectRegistry.reset()
	H.use_fixture_catalog()
	H.register_fake_effects()


func after_all() -> void:
	EffectRegistry.reset()
	CardCatalog.load_json()


func _all_legal(s: Dictionary) -> Array:
	var out: Array = []
	for pid: String in Types.alive_ids(s):
		out.append_array(Game.legal_actions(s, pid))
	return out


func _pick(actions: Array, rng: int) -> Dictionary:
	var by_type: Dictionary = {}
	for a: Variant in actions:
		var t: String = (a as Dictionary)["type"]
		if not by_type.has(t):
			by_type[t] = []
		(by_type[t] as Array).append(a)
	var total: int = 0
	var types: Array = by_type.keys()
	types.sort()
	for t: Variant in types:
		total += int(WEIGHTS.get(t, 1))
	var r: Dictionary = Rng.next_int(rng, maxi(1, total))
	var roll: int = r["value"]
	var chosen: String = types[0]
	for t: Variant in types:
		roll -= int(WEIGHTS.get(t, 1))
		if roll < 0:
			chosen = t
			break
	var group: Array = by_type[chosen]
	var r2: Dictionary = Rng.next_int(int(r["state"]), group.size())
	return {"action": group[int(r2["value"])], "rng": int(r2["state"])}


func _check_invariants(s: Dictionary, label: String) -> bool:
	var errs: Array[String] = Types.validate_state(s)
	if not errs.is_empty():
		fail_test("%s: %s" % [label, str(errs)])
		return false
	var hp: int = 0
	var mana: int = 0
	for p: Variant in s["players"]:
		hp += int((p as Dictionary)["hp"])
		mana += int((p as Dictionary)["mana"])
	var pool: Dictionary = s["pool"]
	if hp + int(pool["hp"]) != 70 or mana + int(pool["mana"]) != 70:
		fail_test("%s: pool no conserva cristales (hp %d+%d, mana %d+%d)" % [label, hp, int(pool["hp"]), mana, int(pool["mana"])])
		return false
	return true


func test_random_games_keep_valid_state() -> void:
	var finished: int = 0
	var total_steps: int = 0
	for g: int in GAMES:
		var n: int = 3 + g % 4
		var ages: Array = []
		for i: int in n:
			ages.append(20 + (g * 7 + i * 13) % 50)
		var s: Dictionary = H.game(n, {"log_limit": 40}, g + 1, ages)
		if not _check_invariants(s, "partida %d inicio" % g):
			return
		var rng: int = Rng.seed_from(g * 7919 + 13)
		for step: int in MAX_STEPS:
			if s["status"] != Types.STATUS_PLAYING:
				break
			var actions: Array = _all_legal(s)
			if actions.is_empty():
				fail_test("partida %d paso %d: sin acciones legales" % [g, step])
				return
			var pick: Dictionary = _pick(actions, rng)
			rng = pick["rng"]
			var a: Dictionary = pick["action"]
			var rev0: int = s["rev"]
			var r: Dictionary = Game.reduce(s, a)
			if r["error"] != "":
				fail_test("partida %d paso %d: acción legal rechazada %s -> %s" % [g, step, str(a), r["error"]])
				return
			s = r["state"]
			total_steps += 1
			if int(s["rev"]) != rev0 + 1:
				fail_test("rev no se incrementa")
				return
			if not _check_invariants(s, "partida %d paso %d (%s)" % [g, step, a["type"]]):
				return
			if step % 20 == 0 and H.json_roundtrip(s) != s:
				fail_test("partida %d paso %d: JSON ida y vuelta cambia el estado" % [g, step])
				return
		if s["status"] == Types.STATUS_FINISHED:
			finished += 1
			assert_true((s["winners"] as Array).size() <= 1)
	gut.p("partidas terminadas: %d/%d, pasos: %d" % [finished, GAMES, total_steps])
	assert_gt(finished, 0, "alguna partida debe terminar")
	pass_test("ok")


func test_json_roundtrip_is_identity() -> void:
	var s: Dictionary = H.game(4, {}, 77)
	assert_eq(H.json_roundtrip(s), s)
	# Con prompts, modificadores, artefactos y evento activo.
	var iids: Array = H.set_hand(s, (s["turn"] as Dictionary)["current"], [Types.CARD_WILD_FIRE])
	var cur: String = (s["turn"] as Dictionary)["current"]
	H.set_mana(s, cur, 5)
	s = H.ok(self, s, Types.make_action_play_card(cur, int(iids[0])))
	Damage.lose_mana(s, cur, 9, [], "", "")
	Game.activate_event(s, H._take_any(s, Types.CARD_SHOT_GLASS), cur, [])
	var back: Dictionary = H.json_roundtrip(s)
	assert_eq(back, s)
	assert_eq(Types.validate_state(back), [] as Array[String])
	assert_typeof((back["players"] as Array)[0]["hp"], TYPE_INT)
	# El estado sigue jugable tras la vuelta.
	var r: Dictionary = Game.reduce(back, Types.make_action_drink_potion(cur))
	assert_eq(r["error"], "")


func test_legal_actions_are_all_accepted() -> void:
	var s: Dictionary = H.game(3, {}, 3)
	var cur: String = (s["turn"] as Dictionary)["current"]
	H.set_hand(s, cur, [Types.CARD_FIREBALL, Types.CARD_ELECTRIC_EXPLOSION, Types.CARD_FIRE_ARROW, Types.CARD_ELECTRIC_ARC])
	H.set_mana(s, cur, 3)
	var acts: Array = Game.legal_actions(s, cur)
	var kinds: Dictionary = {}
	for a: Variant in acts:
		var ad: Dictionary = a
		kinds[ad["type"]] = true
		assert_eq(Game.reduce(s, ad)["error"], "", str(ad))
	for t: String in [Types.ACTION_PLAY_CARD, Types.ACTION_DISCARD, Types.ACTION_EXCHANGE,
			Types.ACTION_END_TURN, Types.ACTION_DRINK_POTION, Types.ACTION_CONCEDE]:
		assert_true(kinds.has(t), t)
	# Electric Arc: pares de objetivos distintos; Electric Explosion exige pagar con fuego.
	var arcs: int = 0
	for a: Variant in acts:
		var ad: Dictionary = a
		if ad["type"] == Types.ACTION_PLAY_CARD and (ad["targets"] as Array).size() == 2:
			arcs += 1
	assert_eq(arcs, 3)
	# Fuera de turno: solo pociones y abandonar.
	var other: String = Game.next_alive_after(s, cur)
	for a: Variant in Game.legal_actions(s, other):
		assert_true(Types.OUT_OF_TURN_ACTIONS.has((a as Dictionary)["type"]))


func test_legal_actions_with_prompt_block_turn_actions() -> void:
	var s: Dictionary = H.game(3, {}, 3)
	var cur: String = (s["turn"] as Dictionary)["current"]
	var other: String = Game.next_alive_after(s, cur)
	Damage.lose_mana(s, other, 2, [], "", "")
	var types: Array = []
	for a: Variant in Game.legal_actions(s, cur):
		types.append((a as Dictionary)["type"])
	assert_false(types.has(Types.ACTION_END_TURN))
	var other_types: Array = []
	for a: Variant in Game.legal_actions(s, other):
		other_types.append((a as Dictionary)["type"])
	assert_true(other_types.has(Types.ACTION_DECLINE))

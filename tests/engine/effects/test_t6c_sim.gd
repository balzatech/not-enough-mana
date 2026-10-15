extends NemTest
## T6c: partidas con el registro real en las que se fuerzan artefactos, eventos
## y prompts de T6c. Toda acción legal de los hooks de T6c debe aplicarse sin
## error y el estado debe seguir siendo válido.

const H = preload("res://tests/fixtures/engine_helpers.gd")
const X = preload("res://tests/engine/effects/t6c_helpers.gd")

const MINE: Array[String] = [Types.ACTION_USE_ARTIFACT, Types.ACTION_USE_EVENT, Types.ACTION_CHOOSE_CARDS]


func after_all() -> void:
	CardCatalog.load_json()
	EffectRegistry.reset()


func _actors(s: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for pr: Variant in s["pending"]:
		var pid: String = (pr as Dictionary)["player"]
		if not out.has(pid):
			out.append(pid)
	if out.is_empty():
		out.append(String((s["turn"] as Dictionary)["current"]))
	return out


func _run(seed_value: int) -> void:
	var s: Dictionary = X.new_state(seed_value)
	for pid: String in ["p1", "p2", "p3"]:
		H.set_mana(s, pid, 6)
	s = X.equip(self, s, "p1", Types.CARD_TRANSFORMATION_GLOVE)
	s = X.equip(self, s, "p1", Types.CARD_TWARDOWSKYS_MIRROR)
	s = X.equip(self, s, "p2", Types.CARD_MAGIC_CAP)
	s = X.equip(self, s, "p3", Types.CARD_SCROLL_OF_ELEMENTS)
	H.force_turn(s, "p1")
	X.event(s, Types.CARD_MANA_FOCUS)
	var mine_ok: int = 0
	for step: int in 250:
		if String(s["status"]) != Types.STATUS_PLAYING:
			break
		if step % 40 == 5:
			X.event(s, Types.CARD_ELIXIR_TRANSMUTATION if step % 80 == 5 else Types.CARD_VISIT_OF_THE_ARCHMAGE)
			for p: Variant in s["players"]:
				var pd: Dictionary = p
				if not bool(pd["eliminated"]):
					pd["hp"] = maxi(1, int(pd["hp"]) - 2)
		var actor: String = _actors(s)[0]
		var legal: Array = Game.legal_actions(s, actor)
		var preferred: Array = legal.filter(func(a: Dictionary) -> bool: return MINE.has(String(a["type"])))
		var pool: Array = preferred if not preferred.is_empty() and step % 2 == 0 else legal
		var a: Dictionary = pool[(step * 7 + seed_value) % pool.size()]
		if String(a["type"]) == Types.ACTION_CONCEDE:
			a = legal[0]
		var r: Dictionary = Game.reduce(s, a)
		if MINE.has(String(a["type"])):
			assert_eq(r["error"], "", "acción legal de T6c falla: %s" % str(a))
			mine_ok += 1
		if String(r["error"]) == "":
			s = r["state"]
			s = X.pass_all(self, s)
		else:
			s = H.ok(self, s, Types.make_action_end_turn(actor)) if Game.in_turn_error(s, actor) == "" else s
		var errs: Array[String] = Types.validate_state(s)
		if not errs.is_empty():
			assert_true(false, "estado inválido en el paso %d: %s" % [step, str(errs)])
			return
	assert_true(mine_ok > 0, "se usaron acciones de T6c")


func test_sim_seed_3() -> void:
	_run(3)


func test_sim_seed_11() -> void:
	_run(11)

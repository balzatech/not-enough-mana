extends NemTest
## V2-21 (QA, puerta de la oleada 1): pruebas independientes de los ítems 2, 6 y 9 de LINEAMIENTOS.
## No dependen de los tests de los desarrolladores: usan el motor real, el Bot real y las escenas reales.

const OH = preload("res://tests/engine/effects/offensive_helpers.gd")

var _names: Dictionary = {"p1": "Ana", "p2": "Bruno", "p3": "Cira", "p4": "Dario"}


func before_each() -> void:
	super.before_each()
	EffectRegistry.reset()
	CardCatalog.load_json()


func _clean(txt: String, label: String) -> void:
	assert_ne(txt, "", label + " vacío")
	assert_false(txt.contains("_"), "%s: guion bajo en '%s'" % [label, txt])
	assert_false(txt.to_lower().contains("efecto aplicado"), "%s: genérico en '%s'" % [label, txt])


# ---------------------------------------------------------------- ítem 2: registro

func test_i2_mana_changed_uses_delta_and_names_target() -> void:
	var s: Dictionary = OH.make_state(4)
	var ev: Array = []
	Damage.gain_mana(s, "p3", 2, ev, "p1", Types.CARD_MANA_IMPLOSION)
	Damage.lose_mana(s, "p3", 1, ev, "p1", Types.CARD_MANA_IMPLOSION)
	var got: Array = OH.events_of(ev, Types.LOG_MANA_CHANGED)
	assert_eq(got.size(), 2)
	if got.size() == 2:
		var up: String = LogText.format(got[0], _names)
		var down: String = LogText.format(got[1], _names)
		assert_true(up.contains("Cira") and up.contains("2") and not up.contains("Ana"), up)
		assert_true(down.contains("Cira") and down.contains("1") and not down.contains("+0"), down)
		_clean(up, "gana")
		_clean(down, "pierde")


func test_i2_every_log_type_and_what_is_clean() -> void:
	for t: String in Strings.LOG_TYPES:
		for d: Dictionary in [{}, {"card_id": Types.CARD_FIREBALL, "targets": ["p2"], "target": "p2", "amount": 2, "delta": -2, "dealt": 2, "prevented": 1}]:
			_clean(LogText.format(Types.make_log_entry(t, 3, "p1", d), _names), t)
	for w: String in ["blinded", "frozen", "frozen_bunny", "magic_shield", "force_field", "mirror_shield",
			"magic_capture", "annihilation", "lightning_redirected"]:
		var multi: bool = w == "lightning_redirected"
		var e: Dictionary = Types.make_log_entry(Types.LOG_EFFECT, 3, "p1",
			{"what": w, "card_id": Types.CARD_FIREBALL, "target": "p2", "to": (["p3"] as Variant) if multi else ("p3" as Variant),
			"from": (["p2"] as Variant) if multi else ("p2" as Variant), "damage": 2, "caster": "p1"})
		_clean(LogText.format(e, _names), "what=" + w)


func test_i2_damage_blocked_shows_blocked() -> void:
	var e: Dictionary = Types.make_log_entry(Types.LOG_DAMAGE, 3, "p1",
		{"target": "p2", "amount": 4, "dealt": 0, "prevented": 4, "card_id": Types.CARD_FIREBALL})
	var txt: String = LogText.format(e, _names)
	assert_true(txt.to_lower().contains("bloque") or txt.to_lower().contains("evit") or txt.to_lower().contains("absorb"), txt)
	var e2: Dictionary = Types.make_log_entry(Types.LOG_DAMAGE, 3, "p1",
		{"target": "p2", "amount": 4, "dealt": 3, "prevented": 0, "card_id": Types.CARD_FIREBALL})
	assert_true(LogText.format(e2, _names).contains("3"), LogText.format(e2, _names))


func test_i2_strip_shows_last_three_and_highlights_names() -> void:
	var log_node: ActionLog = ActionLog.new()
	add_child_autofree(log_node)
	var entries: Array = []
	for i: int in 7:
		entries.append(Types.make_log_entry(Types.LOG_TURN_STARTED, i + 1, "p%d" % (i % 4 + 1), {}))
	log_node.size = Vector2(1000, 104)
	log_node.set_entries(entries, _names)
	await wait_process_frames(2)
	var strip: Array[String] = log_node.strip_lines()
	assert_eq(strip.size(), 3)
	assert_true(strip[2].begins_with("Turno 7"), strip[2])
	assert_true(strip[0].begins_with("Turno 5"), strip[0])
	var hl: String = LogText.highlight("Ana ataca a Bruno", _names)
	assert_true(hl.contains("[color") and hl.contains("Ana") and hl.contains("Bruno"), hl)
	log_node.toggle()
	assert_true(log_node.expanded)
	log_node.toggle()
	assert_false(log_node.expanded)


func test_i2_real_games_log_is_clean() -> void:
	# 3 partidas reales (3, 4 y 6 jugadores) con bots: ninguna entrada del log produce texto sucio.
	var bad: Array[String] = []
	var checked: int = 0
	for cfg: Array in [[5, 3], [6, 4], [8, 6]]:
		var s: Dictionary = _new_game(int(cfg[0]), int(cfg[1]))
		var rng: int = Rng.seed_from(int(cfg[0]) * 31 + 7)
		var steps: int = 0
		var nm: Dictionary = {}
		for p: Variant in s["players"]:
			nm[String((p as Dictionary)["id"])] = String((p as Dictionary)["name"])
		while steps < 400 and s["status"] == Types.STATUS_PLAYING:
			var res: Dictionary = _bot_step(s, rng)
			if res.is_empty():
				break
			rng = int(res["rng"])
			var r: Dictionary = res["r"]
			for e: Variant in r["events"]:
				var txt: String = LogText.format(e as Dictionary, nm)
				checked += 1
				if txt == "" or txt.contains("_") or txt.contains("efecto aplicado"):
					bad.append("%s -> '%s'" % [JSON.stringify(e), txt])
			s = r["state"]
			steps += 1
	assert_gt(checked, 300, "entradas comprobadas")
	assert_eq(bad.size(), 0, "entradas sucias: " + str(bad.slice(0, 5)))


# ---------------------------------------------------------------- ítem 6: interfaz honesta

func _buttons(node: Node, out: Array[Button]) -> void:
	if node is Button:
		out.append(node as Button)
	for c: Node in node.get_children():
		_buttons(c, out)


func test_i6_main_menu_has_no_dead_buttons() -> void:
	var mm: MainMenu = (load("res://src/ui/screens/main_menu.tscn") as PackedScene).instantiate()
	mm.auto_navigate = false
	add_child_autofree(mm)
	await wait_process_frames(2)
	var bs: Array[Button] = []
	_buttons(mm, bs)
	var active: Array[String] = []
	for b: Button in bs:
		if b.is_visible_in_tree():
			active.append(b.text + ("|off" if b.disabled else ""))
	for t: String in active:
		assert_false(t.contains("Crear sala") and not t.ends_with("|off"), "activo: " + t)
		assert_false(t.contains("Unirse") and not t.ends_with("|off"), "activo: " + t)
	assert_true(active.has("Jugar local"), str(active))
	assert_true(active.has("Ajustes"), str(active))


func test_i6_settings_has_no_audio_and_keeps_cfg_structure() -> void:
	var st: Settings = (load("res://src/ui/screens/settings.tscn") as PackedScene).instantiate()
	st.auto_navigate = false
	add_child_autofree(st)
	await wait_process_frames(2)
	var bs: Array[Button] = []
	_buttons(st, bs)
	for b: Button in bs:
		if b.is_visible_in_tree():
			assert_false(b.text.contains("Música") or b.text.contains("Efectos") or b.text.contains("Sonido"), b.text)
	for l: Node in st.find_children("*", "Label", true, false):
		var t: String = (l as Label).text
		if (l as Label).is_visible_in_tree():
			assert_false(t.contains("Música") or t.contains("Efectos"), t)
	# QA-V2-35-03: Vibración tampoco se ofrece (nada la lee). Su clave no se pierde: save_reaction_notify
	# conserva el resto de claves del archivo (test_r15_save_keeps_other_keys en test_reaction_pref.gd).
	for b: Button in bs:
		assert_false(b.text.begins_with("Vibración"), b.text)


# ---------------------------------------------------------------- ítem 9: bots

func _new_game(seed_value: int, n: int) -> Dictionary:
	var players: Array = []
	for i: int in n:
		players.append(Types.make_player("p%d" % (i + 1), "P%d" % (i + 1), 18 + (seed_value * 7 + i * 11) % 50, (i % 12) + 1))
	return Game.new_game(players, {"log_limit": 50}, seed_value)


func _bot_step(s: Dictionary, rng: int, randomness: int = 0) -> Dictionary:
	var actor: String = ""
	for pid: String in Types.alive_ids(s):
		if Bot.has_decision(s, pid):
			actor = pid
			break
	if actor == "":
		return {}
	var res: Dictionary = Bot.choose_action(s, actor, rng, randomness)
	var r: Dictionary = Game.reduce(s, res["action"])
	if String(r["error"]) != "":
		return {}
	return {"rng": int(res["rng_state"]), "r": r, "action": res["action"], "pre": s}


func test_i9_bots_never_eliminated_by_too_much_mana_and_finish() -> void:
	# Semillas que fallaban en la línea base (3, 4, 12, 14) más las vecinas; 3-6 jugadores.
	var tmm: Array[String] = []
	var finished: int = 0
	var total: int = 0
	var violations: Array[String] = []
	for seed_value: int in [2, 3, 4, 5, 12, 13, 14, 15]:
		for n: int in [3, 6]:
			var randomness: int = 0 if (seed_value + n) % 2 == 0 else 15  # con humanos en la mesa el bot usa 15
			var s: Dictionary = _new_game(seed_value, n)
			var rng: int = Rng.seed_from(seed_value * 31 + 7)
			var steps: int = 0
			while steps < 2000 and s["status"] == Types.STATUS_PLAYING:
				var res: Dictionary = _bot_step(s, rng, randomness)
				if res.is_empty():
					violations.append("bloqueo/ilegal semilla %d n=%d paso %d" % [seed_value, n, steps])
					break
				rng = int(res["rng"])
				var r: Dictionary = res["r"]
				for e: Variant in r["events"]:
					var ev: Dictionary = e
					if String(ev["type"]) == Types.LOG_ELIMINATED and String((ev["data"] as Dictionary).get("reason", "")) == Types.ELIM_TOO_MUCH_MANA:
						tmm.append("semilla %d n=%d jugador %s" % [seed_value, n, ev["player"]])
				s = r["state"]
				var errs: Array[String] = Types.validate_state(s)
				if not errs.is_empty():
					violations.append("invariante semilla %d: %s" % [seed_value, str(errs)])
					break
				steps += 1
			total += 1
			if s["status"] == Types.STATUS_FINISHED:
				finished += 1
	assert_eq(violations.size(), 0, str(violations))
	assert_eq(tmm.size(), 0, "Too Much Mana: " + str(tmm))
	assert_eq(finished, total, "terminadas %d/%d" % [finished, total])

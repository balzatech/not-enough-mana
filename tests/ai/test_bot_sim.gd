extends NemTest
## T9: partidas bot contra bot. Comprueba que el bot nunca envía acciones
## ilegales, que siempre hay alguien que puede decidir (sin bloqueos) y que
## ningún turno se alarga sin fin (anti-bucle).

const H = preload("res://tests/fixtures/engine_helpers.gd")

const GAMES: int = 200
## Con efectos falsos (independientes de T6) basta una muestra menor.
const GAMES_FAKE: int = 50
const MAX_STEPS: int = 600
## Con el registro vacío las partidas no avanzan: basta con pocos pasos.
const MAX_STEPS_SPARSE: int = 250
## Margen sobre Bot.MAX_ACTIONS_PER_TURN: reacciones, prompts y utilidades.
const MAX_BOT_STEPS_PER_TURN: int = 60


func after_all() -> void:
	EffectRegistry.reset()
	CardCatalog.load_json()


## Quién debe decidir ahora: prompt propio, reacción pendiente o jugador en turno.
func _next_actor(s: Dictionary) -> String:
	for pid: String in Types.alive_ids(s):
		if Bot.has_decision(s, pid):
			return pid
	return ""


## Juega `games` partidas. Devuelve {finished, steps, error}.
func _run(games: int, max_steps: int) -> Dictionary:
	var finished: int = 0
	var steps_total: int = 0
	var kinds: Dictionary = {}
	for g: int in games:
		var n: int = 2 + g % 5
		var ages: Array = []
		for i: int in n:
			ages.append(18 + (g * 7 + i * 11) % 50)
		var s: Dictionary = H.game(n, {"log_limit": 200}, g + 101, ages)
		var rng: int = Rng.seed_from(g * 31 + 7)
		var randomness: int = 25 if g % 4 == 0 else 0
		var last_turn: int = -1
		var in_turn: int = 0
		for step: int in max_steps:
			if s["status"] != Types.STATUS_PLAYING:
				break
			var actor: String = _next_actor(s)
			if actor == "":
				return {"error": "partida %d paso %d: nadie puede decidir (bloqueo)" % [g, step]}
			var res: Dictionary = Bot.choose_action(s, actor, rng, randomness)
			rng = int(res["rng_state"])
			var a: Dictionary = res["action"]
			if a.is_empty():
				return {"error": "partida %d paso %d: %s no devolvió acción" % [g, step, actor]}
			var r: Dictionary = Game.reduce(s, a)
			if String(r["error"]) != "":
				return {"error": "partida %d paso %d: acción ilegal %s -> %s" % [g, step, JSON.stringify(a), r["error"]]}
			kinds[String(a["type"])] = int(kinds.get(String(a["type"]), 0)) + 1
			s = r["state"]
			steps_total += 1
			var tn: int = int((s["turn"] as Dictionary)["number"])
			if tn != last_turn:
				last_turn = tn
				in_turn = 0
			in_turn += 1
			if in_turn > MAX_BOT_STEPS_PER_TURN:
				return {"error": "partida %d: bucle en el turno %d (%d acciones)" % [g, tn, in_turn]}
		if s["status"] == Types.STATUS_FINISHED:
			finished += 1
	return {"finished": finished, "steps": steps_total, "kinds": kinds, "error": ""}


func test_bot_games_with_fake_effects_no_illegal_actions_no_loops() -> void:
	EffectRegistry.reset()
	CardCatalog.load_json()
	H.register_fake_effects()
	var res: Dictionary = _run(GAMES_FAKE, MAX_STEPS)
	if String(res["error"]) != "":
		fail_test(String(res["error"]))
		return
	gut.p("efectos falsos: terminadas %d/%d, pasos %d, tipos %s" % [res["finished"], GAMES_FAKE, res["steps"], str(res["kinds"])])
	assert_gt(int(res["finished"]), 10, "varias partidas deben terminar")
	assert_gt(int((res["kinds"] as Dictionary).get(Types.ACTION_PLAY_CARD, 0)), 0, "el bot juega cartas")


## PENDIENTE T10a: con los efectos reales (T6a-c) este test debe ejecutarse con
## el registro completo. Hoy se ejecuta con los efectos que haya registrados; si
## faltan, las partidas siguen sin acciones ilegales pero el test se marca
## pendiente para repetirlo cuando estén todos.
func test_200_bot_games_with_registered_effects() -> void:
	EffectRegistry.reset()
	CardCatalog.load_json()
	var missing: Array[String] = []
	for id: String in Types.PLAYABLE_CARD_IDS:
		if not EffectRegistry.has_effect(id):
			missing.append(id)
	var res: Dictionary = _run(GAMES, MAX_STEPS if missing.is_empty() else MAX_STEPS_SPARSE)
	if String(res["error"]) != "":
		fail_test(String(res["error"]))
		return
	gut.p("efectos reales: terminadas %d/%d, pasos %d, sin efecto: %d, tipos %s" % [res["finished"], GAMES, res["steps"], missing.size(), str(res["kinds"])])
	if not missing.is_empty():
		pending("T10a: repetir con todos los efectos; faltan %d cartas: %s" % [missing.size(), str(missing)])
	else:
		assert_gte(int(res["finished"]), GAMES - 10, "al menos el 95 por ciento de las partidas debe terminar con ganador en %d pasos" % MAX_STEPS)

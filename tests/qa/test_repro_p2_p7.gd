extends GutTest
## V2-01 (QA): confirmación reproducible de dos fallos del MVP.
##   P2: registro (LogText) con claves/datos que no coinciden con lo que escribe el motor.
##   P7: el bot se elimina solo por Too Much Mana al no saber contestar al prompt oculto de Magic Hand.
## Informe: docs/historico/v0.2/confirmacion-p2-p7.md.
##
## Convención: cada fallo tiene
##   * un test "estado actual" que PASA documentando el defecto (si alguien lo arregla, este test
##     se pone en rojo: es la señal para borrarlo y activar el de abajo);
##   * un test "esperado" que usa _pending_unless(): mientras el defecto exista queda como
##     pending() (la suite no se rompe); en cuanto se arregla pasa a verde solo y asserta lo correcto.
## Para endurecerlos tras V2-16 / V2-17: borrar el test "estado actual" y reemplazar
## _pending_unless(cond, msg) por assert_true(cond, msg).

const OH = preload("res://tests/engine/effects/offensive_helpers.gd")
const H = preload("res://tests/fixtures/engine_helpers.gd")

## Semillas de tools/sim.gd cuya partida llega al prompt oculto de Magic Hand dentro de
## MAX_REPLAY_STEPS. Eran [3, 4, 12, 14] (las que eliminaban al bot por Too Much Mana antes
## de V2-17). Tras V2-42 (bot con reserva de pociones) la trayectoria de la semilla 3 ya no
## llega a ese prompt, así que se sustituye por la 10 (sondeo V2-42: llegan 4, 10, 11, 12, 14...).
const TMM_SEEDS: Array = [10, 4, 12, 14]
const MAX_REPLAY_STEPS: int = 400

var _names: Dictionary = {"p1": "Ana", "p2": "Bruno", "p3": "Cira", "p4": "Dani"}


func before_each() -> void:
	EffectRegistry.reset()
	CardCatalog.load_json()


func after_all() -> void:
	EffectRegistry.reset()
	CardCatalog.load_json()


func _pending_unless(cond: bool, msg: String) -> void:
	if cond:
		assert_true(cond, msg)
	else:
		pending("PENDIENTE (defecto abierto): " + msg)


# =============================================================================
# P2 - Registro
# =============================================================================

## Icy Grasp con el motor real: el log privado se traduce hoy; la captura antigua no es reproducible.
func test_p2_icy_grasp_private_log_is_translated_now() -> void:
	var s: Dictionary = OH.make_state(4)
	H.set_hand(s, "p2", [Types.CARD_HEAL, Types.CARD_FIREBALL])
	var r: Dictionary = OH.cast(s, "p1", Types.CARD_ICY_GRASP, ["p2"])
	assert_eq(r["error"], Types.ERR_NONE)
	var priv: Array = OH.events_of(r["events"], Types.LOG_EFFECT, "card_stolen_private")
	assert_eq(priv.size(), 1, "el motor escribe card_stolen_private")
	var txt: String = LogText.format(priv[0], _names)
	assert_false(txt.contains("card_stolen_private"), "no debe verse la clave interna: " + txt)
	assert_false(txt.contains("_"), "sin guiones bajos: " + txt)
	assert_true(txt.begins_with("Ana se queda "), txt)
	assert_true(txt.ends_with(" de Bruno."), txt)
	# El texto de la captura antigua ("Icy Grasp: card_stolen_private") no lo puede producir LogText actual.
	assert_ne(txt, "Icy Grasp: card_stolen_private")
	var pub: Array = OH.events_of(r["events"], Types.LOG_EFFECT, "card_stolen")
	assert_eq(LogText.format(pub[0], _names), "Ana roba una carta a Bruno.")


func test_p2_mana_changed_expected_text() -> void:
	var s: Dictionary = OH.make_state(4)
	var events: Array = []
	Damage.lose_mana(s, "p2", 2, events, "p1", Types.CARD_MANA_IMPLOSION)
	var txt: String = LogText.format(OH.events_of(events, Types.LOG_MANA_CHANGED)[0], _names)
	assert_true(txt.contains("pierde 2") and txt.contains("Bruno"),
		"V2-16: LOG_MANA_CHANGED debe leer data.delta y nombrar a data.target (Bruno pierde 2); hoy: " + txt)


## Todos los LOG_EFFECT.what que escribe el motor y LogText no traduce (caen en "efecto aplicado").
const UNTRANSLATED_WHATS: Array = ["blinded", "frozen", "frozen_bunny", "magic_shield", "force_field",
	"mirror_shield", "magic_capture", "annihilation", "lightning_redirected"]
## LOG_EFFECT.what que LogText sí traduce.
const TRANSLATED_WHATS: Array = ["fizzled", "used_as_payment", "rule_established", "peeked_deck", "peeked_card",
	"next_potion_doubled", "loss_avoided", "immune", "last_wish", "hands_exchanged", "hand_seen", "hand_cards",
	"drank_to_avoid", "curse_targets", "card_stolen", "card_stolen_detail", "card_stolen_private", "steal_empty",
	"lowest_mana"]


func _effect_text(what: String) -> String:
	var e: Dictionary = Types.make_log_entry(Types.LOG_EFFECT, 1, "p1",
		{"card_id": Types.CARD_FIREBALL, "what": what, "target": "p2",
		"seen": ([] as Array) if what == "hand_cards" else ("" as Variant), "targets": []})
	return LogText.format(e, _names)


func test_p2_untranslated_effect_whats_expected() -> void:
	var bad: Array = []
	for w: String in UNTRANSLATED_WHATS:
		if _effect_text(w).ends_with("efecto aplicado."):
			bad.append(w)
	assert_true(bad.is_empty(), "V2-16: LogText sin traducción para %s" % str(bad))


## Recorre partidas bot contra bot reales y cuenta entradas de log con texto defectuoso.
func _scan_games(seeds: Array) -> Dictionary:
	var out: Dictionary = {}
	for seed_value: int in seeds:
		var n: int = 3 + (seed_value - 1) % 4
		var players: Array = []
		var names: Dictionary = {}
		for i: int in n:
			players.append(Types.make_player("p%d" % (i + 1), "P%d" % (i + 1), 18 + (seed_value * 7 + i * 11) % 50, (i % 12) + 1))
			names["p%d" % (i + 1)] = "Nom%d" % (i + 1)
		var s: Dictionary = Game.new_game(players, {"log_limit": 50}, seed_value)
		var rng: int = Rng.seed_from(seed_value * 31 + 7)
		var steps: int = 0
		while steps < 700 and s["status"] == Types.STATUS_PLAYING:
			var actor: String = ""
			for pid: String in Types.alive_ids(s):
				if Bot.has_decision(s, pid):
					actor = pid
					break
			if actor == "":
				break
			var res: Dictionary = Bot.choose_action(s, actor, rng, 0)
			rng = int(res["rng_state"])
			if (res["action"] as Dictionary).is_empty():
				break
			var r: Dictionary = Game.reduce(s, res["action"])
			if String(r["error"]) != "":
				break
			s = r["state"]
			steps += 1
			for e: Variant in r["events"]:
				var ed: Dictionary = e
				var txt: String = LogText.format(ed, names)
				var defect: String = ""
				if txt.contains("_"):
					defect = "guion_bajo"
				elif txt.ends_with("efecto aplicado."):
					defect = "generico"
				elif String(ed["type"]) == Types.LOG_MANA_CHANGED and txt.contains("+0"):
					defect = "mana+0"
				if defect != "":
					var key: String = String(ed["type"])
					if key == Types.LOG_EFFECT:
						key += "/" + String((ed["data"] as Dictionary).get("what", ""))
					out[key] = defect
	return out


# =============================================================================
# P7 - Bot que se elimina solo por Too Much Mana
# =============================================================================

## Reproduce la partida de tools/sim.gd con la semilla dada hasta que un bot tiene el prompt
## oculto de Magic Hand. Devuelve {state, actor} o {} si no llega.
func _replay_to_hidden_prompt(seed_value: int) -> Dictionary:
	var n: int = 3 + (seed_value - 1) % 4
	var players: Array = []
	for i: int in n:
		players.append(Types.make_player("p%d" % (i + 1), "P%d" % (i + 1), 18 + (seed_value * 7 + i * 11) % 50, (i % 12) + 1))
	var s: Dictionary = Game.new_game(players, {"log_limit": 50}, seed_value)
	var rng: int = Rng.seed_from(seed_value * 31 + 7)
	var steps: int = 0
	while steps < MAX_REPLAY_STEPS and s["status"] == Types.STATUS_PLAYING:
		var actor: String = ""
		for pid: String in Types.alive_ids(s):
			if Bot.has_decision(s, pid):
				actor = pid
				break
		if actor == "":
			return {}
		for x: Variant in s["pending"] as Array:
			var pr: Dictionary = x
			if String(pr["player"]) == actor and String(pr["kind"]) == Types.PROMPT_CHOOSE_CARD \
					and bool((pr["data"] as Dictionary).get("hidden", false)):
				return {"state": s, "actor": actor, "rng": rng, "prompt": pr}
		var res: Dictionary = Bot.choose_action(s, actor, rng, 0)
		rng = int(res["rng_state"])
		var r: Dictionary = Game.reduce(s, res["action"])
		if String(r["error"]) != "":
			return {}
		s = r["state"]
		steps += 1
	return {}


func test_p7_trace_bot_cannot_answer_hidden_magic_hand_prompt() -> void:
	for seed_value: int in TMM_SEEDS:
		var ctx: Dictionary = _replay_to_hidden_prompt(seed_value)
		assert_false(ctx.is_empty(), "semilla %d: el bot llega al prompt oculto de Magic Hand" % seed_value)
		if ctx.is_empty():
			continue
		var s: Dictionary = ctx["state"]
		var actor: String = ctx["actor"]
		var pr: Dictionary = ctx["prompt"]
		var data: Dictionary = pr["data"]
		assert_eq(data["cards"], [], "semilla %d: data.cards vacío (oculto)" % seed_value)
		# Causa 1: la vista del bot oculta la mano de la víctima, así que el hook
		# legal_magic_hand no genera ninguna CHOOSE_CARDS.
		var view: Dictionary = Bot.make_view(s, actor)
		assert_eq((Types.get_player(view, String(data["from"]))["hand"] as Array).size(), 0, "la vista no trae la mano ajena")
		var legal: Array = Game.legal_actions(view, actor)
		var types: Array = []
		for a: Variant in legal:
			types.append(String((a as Dictionary)["type"]))
		assert_false(types.has(Types.ACTION_CHOOSE_CARDS), "semilla %d: sin CHOOSE_CARDS legal en la vista del bot: %s" % [seed_value, str(types)])
		assert_eq(types[0], Types.ACTION_DRINK_POTION, "legal[0] es DRINK_POTION")
		# ...pero las cartas SÍ están en reveals[actor] (kind hand): la información existe.
		var revealed: Array = ActionOptions.revealed_hand(view, actor, String(data["from"]))
		assert_gt(revealed.size(), 0, "reveals contiene la mano observada")
		# Arreglado (V2-17): el bot construye CHOOSE_CARDS desde reveals.
		var chosen: Dictionary = Bot.choose_action(s, actor, int(ctx["rng"]), 0)["action"]
		assert_eq(chosen["type"], Types.ACTION_CHOOSE_CARDS, "semilla %d: el bot responde al prompt" % seed_value)


func test_p7_bot_expected_answers_prompt_with_choose_cards() -> void:
	var ctx: Dictionary = _replay_to_hidden_prompt(12)
	assert_false(ctx.is_empty())
	if ctx.is_empty():
		return
	var chosen: Dictionary = Bot.choose_action(ctx["state"], ctx["actor"], int(ctx["rng"]), 0)["action"]
	var ok: bool = String(chosen.get("type", "")) == Types.ACTION_CHOOSE_CARDS \
			and int(chosen.get("prompt_id", -2)) == int((ctx["prompt"] as Dictionary)["id"])
	assert_true(ok, "V2-17: el bot debe responder CHOOSE_CARDS [iid de reveals] al prompt oculto de Magic Hand; hoy elige " + str(chosen.get("type", "")))
	if ok:
		var r: Dictionary = Game.reduce(ctx["state"], chosen)
		assert_eq(r["error"], "", "la acción elegida es legal para el motor")


## Un humano SÍ puede resolverlo: la UI añade una CHOOSE_CARDS por carta de reveals
## (ActionOptions._add_hidden_choices) y el motor las acepta.
func test_p7_human_can_resolve_hidden_prompt_via_reveals() -> void:
	for seed_value: int in TMM_SEEDS:
		var ctx: Dictionary = _replay_to_hidden_prompt(seed_value)
		assert_false(ctx.is_empty())
		if ctx.is_empty():
			continue
		var s: Dictionary = ctx["state"]
		var actor: String = ctx["actor"]
		var pr: Dictionary = ctx["prompt"]
		var view: Dictionary = Types.view_for(s, actor)
		var opts: ActionOptions = ActionOptions.build(view, actor)
		var picks: Array = opts.prompt_actions(int(pr["id"]), Types.ACTION_CHOOSE_CARDS)
		assert_gt(picks.size(), 0, "semilla %d: la UI ofrece cartas elegibles" % seed_value)
		if picks.is_empty():
			continue
		var r: Dictionary = Game.reduce(s, picks[0])
		assert_eq(r["error"], "", "semilla %d: el motor acepta la elección del humano" % seed_value)
		var after: Dictionary = r["state"]
		var still: bool = false
		for x: Variant in after["pending"] as Array:
			if int((x as Dictionary)["id"]) == int(pr["id"]):
				still = true
		assert_false(still, "el prompt queda resuelto")

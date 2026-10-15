extends GutTest
## V3-11 (A1): Game.legal_actions(estado, pid) == Game.legal_actions(vista propia, pid).
## Contrato en docs/CONTRATO-TIPOS.md (regla A1) y docs/TECNICO/v03-diseno.md §3.
##
## 1. Simulación: partidas bot contra bot con semillas fijas (3 a 6 jugadores,
##    Bot.choose_action con randomness 15). En cada estado alcanzado y para cada
##    jugador vivo se compara el conjunto canónico de acciones legales sobre el
##    estado, sobre Types.view_for (lo que usa la UI) y sobre Bot.make_view (lo
##    que usa el bot). Mínimos: >= 1000 comparaciones, >= 50 con reacción
##    abierta, >= 30 con prompts pendientes y >= 10 con un artefacto activable.
## 2. Las 8 reglas de acciones legales que tocan zonas ocultas, con un estado
##    construido a mano cada una, también con el mazo vacío y la mano vacía:
##    R1 Twardowsky's Mirror (mazo/descarte)    R5 descartar en el turno (mano propia)
##    R2 Magic Hand (mano ajena -> reveals)     R6 PROMPT_DISCARD (mano propia)
##    R3 Transformation Glove (mano propia)     R7 respuestas en ventana (Reactions)
##    R4 intercambiar (mano propia, mazo)       R8 jugar con pago y objetivo (Book Exchange)
## 3. El espejo de Twardowsky se ofrece en la interfaz (ActionOptions sobre la vista).

const H = preload("res://tests/fixtures/engine_helpers.gd")
const OH = preload("res://tests/engine/effects/offensive_helpers.gd")

const SIM_GAMES: int = 30
const SIM_SEED: int = 1
const SIM_STEPS_PER_GAME: int = 60
## Cada ARTIFACT_EVERY partidas, p1 empieza con Twardowsky's Mirror y p2 con
## Transformation Glove en mesa: los bots casi nunca llegan a tenerlos y hacen
## falta estados con un artefacto activable.
const ARTIFACT_EVERY: int = 3
const SIM_RANDOMNESS: int = 15
const MIN_COMPARISONS: int = 1000
const MIN_REACTION: int = 50
const MIN_PROMPT: int = 30
const MIN_ARTIFACT: int = 10


func before_each() -> void:
	EffectRegistry.reset()
	CardCatalog.load_json()


func after_all() -> void:
	EffectRegistry.reset()
	CardCatalog.load_json()


# =============================================================================
# Utilidades
# =============================================================================

## Lista ordenada de las acciones serializadas con claves ordenadas.
static func canon(actions: Array) -> Array:
	var out: Array = []
	for a: Variant in actions:
		out.append(JSON.stringify(a, "", true))
	out.sort()
	return out


## Acciones que están en `a` y no en `b` (multiconjunto).
static func minus(a: Array, b: Array) -> Array:
	var rest: Array = b.duplicate()
	var out: Array = []
	for x: Variant in a:
		var i: int = rest.find(x)
		if i >= 0:
			rest.remove_at(i)
		else:
			out.append(x)
	return out


## "" si las acciones de pid coinciden en estado, view_for y make_view; si no, la diferencia.
static func diff_for(s: Dictionary, pid: String) -> String:
	var full: Array = canon(Game.legal_actions(s, pid))
	var msg: String = ""
	var views: Dictionary = {"view_for": Types.view_for(s, pid), "make_view": Bot.make_view(s, pid)}
	for k: String in views:
		var v: Array = canon(Game.legal_actions(views[k] as Dictionary, pid))
		if v != full:
			msg += "[%s] solo en estado: %s | solo en vista: %s " % [k, str(minus(full, v)), str(minus(v, full))]
	return msg


## Compara para todos los vivos; devuelve el número de comparaciones.
func assert_equivalent(s: Dictionary, label: String) -> int:
	var n: int = 0
	for pid: String in Types.alive_ids(s):
		var d: String = diff_for(s, pid)
		assert_eq(d, "", "%s, pid %s: %s" % [label, pid, d])
		n += 1
	return n


## Igual que assert_equivalent y, además, con el mazo vacío (mismo descarte).
func assert_equivalent_variants(s: Dictionary, label: String) -> void:
	assert_equivalent(s, label)
	var e: Dictionary = s.duplicate(true)
	e["deck"] = []
	assert_equivalent(e, label + " (mazo vacío)")


static func of_type(actions: Array, t: String, pid: String = "") -> Array:
	var out: Array = []
	for a: Variant in actions:
		var ad: Dictionary = a
		if String(ad["type"]) == t and (pid == "" or String(ad["player"]) == pid):
			out.append(ad)
	return out


## Pone en la mesa de pid una instancia real de card_id. Devuelve su iid.
static func equip(s: Dictionary, pid: String, card_id: String) -> int:
	var c: Dictionary = H._take_any(s, card_id)
	assert(not c.is_empty(), "no queda %s" % card_id)
	(Types.get_player(s, pid)["artifacts"] as Array).append(
		Types.make_table_card(int(c["iid"]), card_id, pid))
	return int(c["iid"])


static func empty_deck_to_discard(s: Dictionary) -> void:
	(s["discard"] as Array).append_array(s["deck"] as Array)
	s["deck"] = []


# =============================================================================
# 1. Simulación
# =============================================================================

func test_simulated_states_match_view() -> void:
	var comparisons: int = 0
	var with_reaction: int = 0
	var with_prompt: int = 0
	var with_artifact: int = 0
	var failures: Array = []
	for g: int in SIM_GAMES:
		var seed_value: int = SIM_SEED + g
		var n: int = 3 + g % 4
		var players: Array = []
		for i: int in n:
			players.append(Types.make_player("p%d" % (i + 1), "P%d" % (i + 1),
				18 + (seed_value * 7 + i * 11) % 50, (i % 12) + 1))
		var s: Dictionary = Game.new_game(players, {"log_limit": 50}, seed_value)
		if g % ARTIFACT_EVERY == 0:
			equip(s, "p1", Types.CARD_TWARDOWSKYS_MIRROR)
			equip(s, "p2", Types.CARD_TRANSFORMATION_GLOVE)
		var rng: int = Rng.seed_from(seed_value * 31 + 7)
		for step: int in SIM_STEPS_PER_GAME:
			if String(s["status"]) != Types.STATUS_PLAYING:
				break
			var has_reaction: bool = not (s["reaction"] as Dictionary).is_empty()
			var has_prompt: bool = not (s["pending"] as Array).is_empty()
			for pid: String in Types.alive_ids(s):
				var d: String = diff_for(s, pid)
				comparisons += 1
				if d != "" and failures.size() < 10:
					failures.append("semilla %d, paso %d, turno %d, pid %s: %s" % [
						seed_value, step, int((s["turn"] as Dictionary)["number"]), pid, d])
				if has_reaction:
					with_reaction += 1
				if has_prompt:
					with_prompt += 1
				for a: Variant in of_type(Game.legal_actions(s, pid), Types.ACTION_USE_ARTIFACT):
					if int((a as Dictionary).get("prompt_id", -1)) < 0:
						with_artifact += 1
						break
			var actor: String = ""
			for pid: String in Types.alive_ids(s):
				if Bot.has_decision(s, pid):
					actor = pid
					break
			if actor == "":
				break
			var res: Dictionary = Bot.choose_action(s, actor, rng, SIM_RANDOMNESS)
			rng = int(res["rng_state"])
			var a2: Dictionary = res["action"]
			if a2.is_empty():
				break
			var r: Dictionary = Game.reduce(s, a2)
			if String(r["error"]) != "":
				failures.append("semilla %d, paso %d: el bot eligió una acción ilegal %s -> %s" % [
					seed_value, step, JSON.stringify(a2), r["error"]])
				break
			s = r["state"]
	gut.p("A1: %d comparaciones (reacción %d, prompts %d, artefacto activable %d)" % [
		comparisons, with_reaction, with_prompt, with_artifact])
	assert_eq(failures, [], "estado y vista deben dar las mismas acciones legales")
	assert_gte(comparisons, MIN_COMPARISONS, "estados x jugador comparados")
	assert_gte(with_reaction, MIN_REACTION, "comparaciones con reacción abierta")
	assert_gte(with_prompt, MIN_PROMPT, "comparaciones con prompts pendientes")
	assert_gte(with_artifact, MIN_ARTIFACT, "comparaciones con un artefacto activable")


# =============================================================================
# R1. Twardowsky's Mirror
# =============================================================================

## El caso del bug: mazo lleno, descarte vacío. Antes la vista (deck = []) no lo ofrecía.
func test_r1_mirror_full_deck_empty_discard_is_offered_on_view() -> void:
	var s: Dictionary = OH.make_state(4)
	var mirror: int = equip(s, "p1", Types.CARD_TWARDOWSKYS_MIRROR)
	assert_gt((s["deck"] as Array).size(), 0)
	assert_eq((s["discard"] as Array).size(), 0)
	var expected: Array = [Types.make_action_use_artifact("p1", mirror)]
	assert_eq(canon(of_type(Game.legal_actions(s, "p1"), Types.ACTION_USE_ARTIFACT)), canon(expected))
	assert_eq(canon(of_type(Game.legal_actions(Types.view_for(s, "p1"), "p1"), Types.ACTION_USE_ARTIFACT)),
		canon(expected), "la vista del jugador ofrece el espejo")
	assert_equivalent(s, "R1 mazo lleno")
	assert_eq(String(Game.reduce(s, expected[0])["error"]), "", "el motor acepta la acción")


func test_r1_mirror_offered_in_ui_action_options() -> void:
	var s: Dictionary = OH.make_state(4)
	var mirror: int = equip(s, "p1", Types.CARD_TWARDOWSKYS_MIRROR)
	var opts: ActionOptions = ActionOptions.build(Types.view_for(s, "p1"), "p1")
	assert_true(opts.usable_artifacts().has(mirror), "la interfaz ofrece el espejo")
	assert_eq(opts.artifact_uses(mirror).size(), 1)
	assert_eq(String(Game.reduce(s, opts.artifact_uses(mirror)[0] as Dictionary)["error"]), "")
	# También por la vista compuesta como en línea (pública + privada).
	var v2: Dictionary = Types.compose_view(Types.public_view(s), Types.private_view(s, "p1"), "p1")
	assert_true(ActionOptions.build(v2, "p1").usable_artifacts().has(mirror))


func test_r1_mirror_empty_deck_and_discard_not_offered_anywhere() -> void:
	var s: Dictionary = OH.make_state(4)
	equip(s, "p1", Types.CARD_TWARDOWSKYS_MIRROR)
	s["deck"] = []
	assert_eq(of_type(Game.legal_actions(s, "p1"), Types.ACTION_USE_ARTIFACT), [])
	assert_eq(of_type(Game.legal_actions(Types.view_for(s, "p1"), "p1"), Types.ACTION_USE_ARTIFACT), [])
	assert_equivalent(s, "R1 mazo y descarte vacíos")


func test_r1_mirror_empty_deck_with_discard_is_offered() -> void:
	var s: Dictionary = OH.make_state(4)
	var mirror: int = equip(s, "p1", Types.CARD_TWARDOWSKYS_MIRROR)
	empty_deck_to_discard(s)
	H.set_hand(s, "p1", [])
	var a: Dictionary = Types.make_action_use_artifact("p1", mirror)
	assert_eq(canon(of_type(Game.legal_actions(Types.view_for(s, "p1"), "p1"), Types.ACTION_USE_ARTIFACT)), canon([a]))
	assert_equivalent(s, "R1 mazo vacío, descarte lleno, mano vacía")
	assert_eq(String(Game.reduce(s, a)["error"]), "", "baraja el descarte y mira")


# =============================================================================
# R2. Magic Hand
# =============================================================================

## p1 lanza Magic Hand a p2 y queda el prompt oculto. Devuelve el estado.
func _magic_hand_state(victim_cards: Array, empty_deck: bool = false) -> Dictionary:
	var s: Dictionary = OH.make_state(4)
	H.set_hand(s, "p2", victim_cards)
	H.set_hand(s, "p1", [])
	if empty_deck:
		empty_deck_to_discard(s)
	var r: Dictionary = OH.cast(s, "p1", Types.CARD_MAGIC_HAND, ["p2"])
	assert_eq(r["error"], Types.ERR_NONE)
	return s


func _prompt_of(s: Dictionary, pid: String) -> Dictionary:
	for pr: Variant in s["pending"]:
		if String((pr as Dictionary)["player"]) == pid:
			return pr
	return {}


func test_r2_magic_hand_choices_come_from_reveals() -> void:
	var s: Dictionary = _magic_hand_state([Types.CARD_HEAL, Types.CARD_FIREBALL, Types.CARD_FIRE_ARROW])
	var pr: Dictionary = _prompt_of(s, "p1")
	assert_false(pr.is_empty(), "prompt de Magic Hand abierto")
	var victim_iids: Array = []
	for c: Variant in H.hand(s, "p2"):
		victim_iids.append(int((c as Dictionary)["iid"]))
	var expected: Array = []
	for iid: Variant in victim_iids:
		expected.append(Types.make_action_choose_cards("p1", int(pr["id"]), [int(iid)]))
	var on_view: Array = of_type(Game.legal_actions(Types.view_for(s, "p1"), "p1"), Types.ACTION_CHOOSE_CARDS)
	assert_eq(canon(on_view), canon(expected), "la vista ofrece una elección por carta vista")
	assert_eq(canon(of_type(Game.legal_actions(s, "p1"), Types.ACTION_CHOOSE_CARDS)), canon(expected))
	assert_eq(canon(ActionOptions.build(Types.view_for(s, "p1"), "p1").prompt_actions(int(pr["id"]),
		Types.ACTION_CHOOSE_CARDS)), canon(expected), "la UI ofrece lo mismo sin parches")
	assert_equivalent_variants(s, "R2 Magic Hand")
	assert_eq(String(Game.reduce(s, on_view[0] as Dictionary)["error"]), "")


func test_r2_magic_hand_bot_answers_without_hidden_patch() -> void:
	var s: Dictionary = _magic_hand_state([Types.CARD_HEAL, Types.CARD_FIREBALL])
	var a: Dictionary = Bot.choose_action(s, "p1", 7, 0)["action"]
	assert_eq(String(a.get("type", "")), Types.ACTION_CHOOSE_CARDS, "el bot responde al prompt oculto")
	assert_eq(String(Game.reduce(s, a)["error"]), "")


func test_r2_magic_hand_empty_deck_and_empty_caster_hand() -> void:
	var s: Dictionary = _magic_hand_state([Types.CARD_HEAL], true)
	assert_eq(H.hand(s, "p1").size(), 0, "la mano de quien elige está vacía")
	assert_eq((s["deck"] as Array).size(), 0)
	assert_eq(of_type(Game.legal_actions(Types.view_for(s, "p1"), "p1"), Types.ACTION_CHOOSE_CARDS).size(), 1)
	assert_equivalent(s, "R2 mazo vacío y mano vacía")


func test_r2_magic_hand_on_empty_hand_opens_no_prompt() -> void:
	var s: Dictionary = _magic_hand_state([])
	assert_true(_prompt_of(s, "p1").is_empty())
	assert_equivalent_variants(s, "R2 víctima sin mano")


## Si la víctima pierde una carta vista hacia una zona pública (otro prompt), ya no se ofrece.
func test_r2_magic_hand_skips_revealed_cards_now_in_discard() -> void:
	var s: Dictionary = _magic_hand_state([Types.CARD_HEAL, Types.CARD_FIREBALL])
	var pr: Dictionary = _prompt_of(s, "p1")
	var gone: Dictionary = H.hand(s, "p2").pop_back()
	(s["discard"] as Array).append(gone)
	var on_view: Array = of_type(Game.legal_actions(Types.view_for(s, "p1"), "p1"), Types.ACTION_CHOOSE_CARDS)
	assert_eq(on_view.size(), 1)
	assert_ne(int((on_view[0] as Dictionary)["cards"][0]), int(gone["iid"]))
	assert_eq(String(Game.reduce(s, Types.make_action_choose_cards("p1", int(pr["id"]), [int(gone["iid"])]))["error"]),
		Types.ERR_INVALID_CHOICE, "el motor la rechaza: ya no está en la mano")
	assert_equivalent(s, "R2 carta vista descartada")


## Prompt pendiente de otro jugador: el que mira solo puede beber o rendirse.
func test_r2_prompt_of_other_player_gives_viewer_no_choices() -> void:
	var s: Dictionary = _magic_hand_state([Types.CARD_HEAL, Types.CARD_FIREBALL])
	for pid: String in ["p2", "p3"]:
		var types: Array = []
		for a: Variant in Game.legal_actions(Types.view_for(s, pid), pid):
			types.append(String((a as Dictionary)["type"]))
		types.sort()
		assert_eq(types, [Types.ACTION_CONCEDE, Types.ACTION_DRINK_POTION], pid)
	assert_equivalent(s, "R2 prompt ajeno")


# =============================================================================
# R3. Transformation Glove
# =============================================================================

func test_r3_glove_uses_own_hand_with_empty_deck() -> void:
	var s: Dictionary = OH.make_state(4)
	var glove: int = equip(s, "p1", Types.CARD_TRANSFORMATION_GLOVE)
	H.set_hand(s, "p1", [Types.CARD_HEAL, Types.CARD_FIRE_ARROW])
	assert_eq(of_type(Game.legal_actions(Types.view_for(s, "p1"), "p1"), Types.ACTION_USE_ARTIFACT).size(), 2)
	assert_equivalent_variants(s, "R3 guante")
	H.set_hand(s, "p1", [])
	assert_eq(of_type(Game.legal_actions(Types.view_for(s, "p1"), "p1"), Types.ACTION_USE_ARTIFACT), [])
	assert_equivalent_variants(s, "R3 guante, mano vacía")
	assert_gt(glove, -1)


# =============================================================================
# R4 y R5. Intercambiar y descartar en el turno
# =============================================================================

func test_r4_r5_exchange_and_discard_with_empty_deck_and_hand() -> void:
	var s: Dictionary = OH.make_state(4)
	H.set_hand(s, "p1", [Types.CARD_HEAL, Types.CARD_FIRE_ARROW])
	var v: Array = Game.legal_actions(Types.view_for(s, "p1"), "p1")
	assert_eq(of_type(v, Types.ACTION_EXCHANGE).size(), 2)
	assert_eq(of_type(v, Types.ACTION_DISCARD).size(), 3)
	assert_equivalent_variants(s, "R4/R5")
	var e: Dictionary = s.duplicate(true)
	e["deck"] = []
	assert_eq(of_type(Game.legal_actions(Types.view_for(e, "p1"), "p1"), Types.ACTION_EXCHANGE).size(), 2,
		"con el mazo vacío se puede intercambiar igual (no se roba)")
	H.set_hand(s, "p1", [])
	v = Game.legal_actions(Types.view_for(s, "p1"), "p1")
	assert_eq(of_type(v, Types.ACTION_EXCHANGE), [])
	assert_eq(of_type(v, Types.ACTION_DISCARD), [])
	assert_eq(of_type(v, Types.ACTION_END_TURN).size(), 1)
	assert_equivalent_variants(s, "R4/R5 mano vacía")


# =============================================================================
# R6. Descarte forzado
# =============================================================================

func test_r6_discard_prompt_uses_own_hand() -> void:
	var s: Dictionary = OH.make_state(4)
	H.set_hand(s, "p2", [Types.CARD_HEAL, Types.CARD_FIRE_ARROW, Types.CARD_FIREBALL])
	Damage.forced_discard(s, "p2", 2, [], Types.CARD_FIREBALL)
	var pr: Dictionary = _prompt_of(s, "p2")
	assert_eq(String(pr.get("kind", "")), Types.PROMPT_DISCARD)
	assert_eq(of_type(Game.legal_actions(Types.view_for(s, "p2"), "p2"), Types.ACTION_CHOOSE_CARDS).size(), 3)
	assert_equivalent_variants(s, "R6 descarte forzado")


func test_r6_discard_prompt_with_empty_hand() -> void:
	var s: Dictionary = OH.make_state(4)
	H.set_hand(s, "p2", [])
	(s["pending"] as Array).append(Types.make_prompt(Types.next_seq(s), "p2", Types.PROMPT_DISCARD,
		{"count": 1}, Types.CARD_FIREBALL))
	assert_equivalent_variants(s, "R6 mano vacía")


# =============================================================================
# R7. Ventana de reacción
# =============================================================================

## p1 lanza Fire Arrow a p2; p2 tiene Magic Shield y 0 maná: puede beber para pagar.
func _reaction_state(empty_deck: bool) -> Dictionary:
	var s: Dictionary = OH.make_state(4)
	var arrow: Array = H.set_hand(s, "p1", [Types.CARD_FIRE_ARROW])
	H.set_hand(s, "p2", [Types.CARD_MAGIC_SHIELD])
	H.set_hand(s, "p3", [])
	H.set_hand(s, "p4", [])
	H.set_mana(s, "p2", 0)
	if empty_deck:
		empty_deck_to_discard(s)
	var r: Dictionary = Game.reduce(s, Types.make_action_play_card("p1", int(arrow[0]), ["p2"]))
	assert_eq(r["error"], "")
	return r["state"]


func test_r7_reaction_window_drink_to_pay() -> void:
	for empty_deck: bool in [false, true]:
		var s: Dictionary = _reaction_state(empty_deck)
		assert_false((s["reaction"] as Dictionary).is_empty(), "ventana abierta")
		assert_eq(Reactions.current_responder(s), "p2", "p2 responde: puede pagar bebiendo")
		var v: Array = Game.legal_actions(Types.view_for(s, "p2"), "p2")
		assert_eq(of_type(v, Types.ACTION_REACT), [], "con 0 maná aún no puede pagar")
		assert_eq(of_type(v, Types.ACTION_DRINK_POTION).size(), 1, "puede beber")
		assert_eq(of_type(v, Types.ACTION_PASS_REACTION).size(), 1)
		assert_equivalent(s, "R7 ventana (mazo vacío: %s)" % str(empty_deck))
		var r: Dictionary = Game.reduce(s, Types.make_action_drink_potion("p2"))
		assert_eq(r["error"], "")
		var s2: Dictionary = r["state"]
		assert_gt(of_type(Game.legal_actions(Types.view_for(s2, "p2"), "p2"), Types.ACTION_REACT).size(), 0,
			"tras beber puede responder")
		assert_equivalent(s2, "R7 tras beber (mazo vacío: %s)" % str(empty_deck))
		# p1 (lanzador, mano vacía) no tiene respuestas.
		assert_eq(of_type(Game.legal_actions(Types.view_for(s, "p1"), "p1"), Types.ACTION_REACT), [])


# =============================================================================
# R8. Jugar con pago en cartas y objetivo cuya mano está oculta
# =============================================================================

## Book Exchange (pago: 1 carta eléctrica) contra un rival sin mano; mazo vacío.
func test_r8_play_with_payment_against_empty_hand() -> void:
	var s: Dictionary = OH.make_state(4)
	H.set_hand(s, "p1", [Types.CARD_BOOK_EXCHANGE, Types.CARD_LIGHTNING, Types.CARD_MAGIC_HAND])
	H.set_hand(s, "p2", [])
	var v: Array = Game.legal_actions(Types.view_for(s, "p1"), "p1")
	var plays: int = of_type(v, Types.ACTION_PLAY_CARD).size()
	assert_gt(plays, 0)
	var full: Array = Game.legal_actions(s, "p1")
	assert_eq(of_type(full, Types.ACTION_PLAY_CARD).size(), plays)
	assert_equivalent_variants(s, "R8 Book Exchange / Magic Hand")
	H.set_hand(s, "p1", [])
	assert_eq(of_type(Game.legal_actions(Types.view_for(s, "p1"), "p1"), Types.ACTION_PLAY_CARD), [])
	assert_equivalent_variants(s, "R8 mano vacía")

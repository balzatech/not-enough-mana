class_name Bot
extends RefCounted
## IA básica (T9). Función pura: elige SIEMPRE una acción de Game.legal_actions().
##
##   Bot.choose_action(state, player_id, rng_state, randomness = 0)
##       -> {"action": Dictionary, "rng_state": int}
##
## * `state` puede ser el estado completo (autoridad / partida local) o ya una
##   vista (state.is_view). Internamente el bot trabaja SOLO con
##   Types.view_for(state, player_id): no mira manos ajenas ni el mazo.
## * Si el jugador no tiene nada que decidir ahora (has_decision == false) devuelve
##   action = {} (la sesión no debe pedir acción al bot en ese caso).
## * randomness: 0 = determinista; 1..100 añade ruido a las puntuaciones
##   (consume rng_state, que se devuelve actualizado). Con 0, rng_state no cambia.
## * Anti-bucle: tope de acciones por turno; superado, termina el turno.
## * No importa nada de ui/ ni net/.

## Tope de acciones propias (jugar, descartar, intercambiar, beber) por turno.
const MAX_ACTIONS_PER_TURN: int = 14
const MAX_DRINKS_PER_TURN: int = 2
const MAX_DISCARDS_PER_TURN: int = 3
const MAX_EXCHANGES_PER_TURN: int = 2
## Una jugada solo se hace si su valor neto supera este umbral.
const PLAY_THRESHOLD: float = 0.5
## Valor de cada punto de maná gastado.
const MANA_WEIGHT: float = 0.25
const EXCHANGE_RESERVE: int = 1
const JUNK_KEEP: float = 0.8
## Descartes por turno para renovar mano cuando no hay jugada posible.
const MAX_CYCLE_DISCARDS: int = 2
## Sin jugadas, bebe hasta tener este maná (si hay margen de pociones).
const STOCKPILE_MANA: int = 0
## Gestión de pociones (V2-42). El maná solo sale de beber y el límite de
## pociones es finito (3 por poción), así que un bot que llega a 10 pociones
## sin maná se queda sin jugadas. Por eso:
## * beber para jugar solo si quedan DRINK_RESERVE pociones libres tras beber
##   (salvo jugadas muy valiosas: DRINK_FORCE_NET);
## * con SCARCE_POTIONS o más, las jugadas no ofensivas pagan SCARCE_PENALTY por
##   punto de maná y no se cura (el maná se guarda para dañar).
const DRINK_RESERVE: int = 3
const DRINK_FORCE_NET: float = 8.0
const SCARCE_POTIONS: int = 5
const SCARCE_PENALTY: float = 0.5


# =============================================================================
# API pública
# =============================================================================

## ¿Debe decidir algo `pid` ahora mismo? (prompt propio, ventana de reacción
## con pid el primero de awaiting, o su turno sin prompts pendientes ni ventana abierta).
static func has_decision(state: Dictionary, pid: String) -> bool:
	if String(state.get("status", "")) != Types.STATUS_PLAYING:
		return false
	var p: Dictionary = Types.get_player(state, pid)
	if p.is_empty() or bool(p["eliminated"]):
		return false
	var pending: Array = state["pending"]
	for x: Variant in pending:
		if String((x as Dictionary)["player"]) == pid:
			return true
	if not pending.is_empty():
		return false
	var re: Dictionary = state["reaction"]
	if not re.is_empty():
		# Orden estricto: solo decide el primero de awaiting.
		var aw: Array = re["awaiting"]
		return not aw.is_empty() and String(aw[0]) == pid
	var turn: Dictionary = state["turn"]
	return String(turn["current"]) == pid and String(turn["phase"]) == Types.PHASE_MAIN


static func choose_action(state: Dictionary, player_id: String, rng_state: int, randomness: int = 0) -> Dictionary:
	var view: Dictionary = state if bool(state.get("is_view", false)) else make_view(state, player_id)
	if not has_decision(view, player_id):
		return {"action": {}, "rng_state": rng_state}
	var legal: Array = Game.legal_actions(view, player_id)
	return choose_among(view, player_id, legal, rng_state, randomness)


## Vista del jugador equivalente a Types.view_for (manos ajenas, mazo, rng y
## revelaciones ajenas ocultos) pero más barata: comparte por referencia las
## partes públicas (el bot no las muta) y solo copia a los jugadores. El log
## solo conserva las entradas públicas del turno actual (anti-bucle).
static func make_view(state: Dictionary, pid: String) -> Dictionary:
	var v: Dictionary = state.duplicate(false)
	v["is_view"] = true
	v["deck_count"] = (state["deck"] as Array).size()
	v["deck"] = []
	v["rng_state"] = 0
	var reveals: Dictionary = state["reveals"]
	v["reveals"] = {pid: (reveals.get(pid, []) as Array)}
	var players: Array = []
	for p: Variant in state["players"] as Array:
		var pd: Dictionary = p
		var cp: Dictionary = pd.duplicate(false)
		cp["hand_count"] = (pd["hand"] as Array).size()
		if String(pd["id"]) != pid:
			cp["hand"] = []
		players.append(cp)
	v["players"] = players
	var number: int = int((state["turn"] as Dictionary)["number"])
	var turn_log: Array = []
	var src: Array = state["log"]
	var i: int = src.size() - 1
	while i >= 0:
		var e: Dictionary = src[i]
		if int(e["turn"]) < number:
			break
		var vis: Array = e["visible_to"]
		if vis.is_empty() or vis.has(pid):
			turn_log.append(e)
		i -= 1
	turn_log.reverse()
	v["log"] = turn_log
	return v


## Núcleo: elige entre `legal` (acciones legales de pid) usando solo `view`.
static func choose_among(view: Dictionary, pid: String, legal_all: Array, rng_state: int,
		randomness: int = 0) -> Dictionary:
	var legal: Array = []
	for a: Variant in legal_all:
		var t: String = String((a as Dictionary)["type"])
		if t != Types.ACTION_CONCEDE and t != Types.ACTION_BREAK_RULE:
			legal.append(a)
	var cands: Array = []
	var pr: Dictionary = _first_prompt(view, pid)
	if not pr.is_empty():
		legal = legal + _hidden_choices(view, pid, pr, legal)
	# Nunca beber voluntariamente la poción que elimina por Too Much Mana.
	if not potion_room(view, pid, 0):
		var safe: Array = []
		for a2: Variant in legal:
			if String((a2 as Dictionary)["type"]) != Types.ACTION_DRINK_POTION:
				safe.append(a2)
		if not safe.is_empty():
			legal = safe
	var re: Dictionary = view.get("reaction", {}) as Dictionary
	if not pr.is_empty():
		cands = _prompt_candidates(view, pid, legal, pr)
	elif not re.is_empty() and (re["awaiting"] as Array).has(pid):
		cands = _reaction_candidates(view, pid, legal)
	elif String((view["turn"] as Dictionary)["current"]) == pid:
		cands = _main_candidates(view, pid, legal)
	if cands.is_empty():
		cands = _fallback(legal, not pr.is_empty())
	if cands.is_empty():
		return {"action": {}, "rng_state": rng_state}
	return _pick(cands, rng_state, randomness)


# =============================================================================
# Selección
# =============================================================================

static func _pick(cands: Array, rng_state: int, randomness: int) -> Dictionary:
	var rng: int = rng_state
	var best: Dictionary = {}
	var best_score: float = -INF
	for c: Variant in cands:
		var cd: Dictionary = c
		var s: float = float(cd["score"])
		if randomness > 0:
			var r: Dictionary = Rng.next_int(rng, 1000)
			rng = int(r["state"])
			s += float(int(r["value"])) / 1000.0 * float(clampi(randomness, 0, 100)) / 100.0 * 6.0
		if s > best_score:
			best_score = s
			best = cd
	return {"action": best["action"], "rng_state": rng}


## Si ninguna heurística propone nada: termina el turno / pasa / rechaza.
static func _fallback(legal: Array, has_prompt: bool = false) -> Array:
	for t: String in [Types.ACTION_END_TURN, Types.ACTION_PASS_REACTION, Types.ACTION_DECLINE]:
		for a: Variant in legal:
			if String((a as Dictionary)["type"]) == t:
				return [{"action": a, "score": 0.0}]
	for a: Variant in legal:
		if not (has_prompt and String((a as Dictionary)["type"]) == Types.ACTION_DRINK_POTION):
			return [{"action": a, "score": 0.0}]
	return []


## Magic Hand (prompt oculto): CHOOSE_CARDS [iid] por cada carta de la mano
## observada en reveals (misma información que ve el humano).
static func _hidden_choices(view: Dictionary, pid: String, pr: Dictionary, legal: Array) -> Array:
	var out: Array = []
	if String(pr["kind"]) != Types.PROMPT_CHOOSE_CARD:
		return out
	var data: Dictionary = pr["data"]
	if not bool(data.get("hidden", false)):
		return out
	var pr_id: int = int(pr["id"])
	for a: Variant in legal:
		var ad: Dictionary = a
		if String(ad["type"]) == Types.ACTION_CHOOSE_CARDS and int(ad.get("prompt_id", -1)) == pr_id:
			return out
	for c: Variant in ActionOptions.revealed_hand(view, pid, String(data.get("from", ""))):
		out.append(Types.make_action_choose_cards(pid, pr_id, [int((c as Dictionary)["iid"])]))
	return out


static func _first_prompt(view: Dictionary, pid: String) -> Dictionary:
	for x: Variant in view["pending"] as Array:
		if String((x as Dictionary)["player"]) == pid:
			return x
	return {}


static func _of_type(legal: Array, type: String) -> Array:
	var out: Array = []
	for a: Variant in legal:
		if String((a as Dictionary)["type"]) == type:
			out.append(a)
	return out


# =============================================================================
# Utilidades de estado
# =============================================================================

## Pociones que puede beber sin llegar a Too Much Mana. `reserve` = pociones
## que quiere dejar libres.
static func potion_room(view: Dictionary, pid: String, reserve: int) -> bool:
	var cfg: Dictionary = view["config"]
	if not bool(cfg.get("potion_limit_enabled", true)):
		return true
	var p: Dictionary = Types.get_player(view, pid)
	return int(p["potions"]) <= int(cfg.get("potion_limit", 10)) - 1 - reserve


## ¿Ha bebido ya tantas pociones que el maná que le queda es escaso?
static func is_scarce(view: Dictionary, pid: String) -> bool:
	if not bool((view["config"] as Dictionary).get("potion_limit_enabled", true)):
		return false
	return int(Types.get_player(view, pid)["potions"]) >= SCARCE_POTIONS


## Contadores del turno actual de pid a partir del log público.
static func _turn_counts(view: Dictionary, pid: String) -> Dictionary:
	var number: int = int((view["turn"] as Dictionary)["number"])
	var plays: int = 0
	var drinks: int = 0
	var discards: int = 0
	for e: Variant in view["log"] as Array:
		var ed: Dictionary = e
		if int(ed["turn"]) != number or String(ed["player"]) != pid:
			continue
		match String(ed["type"]):
			Types.LOG_CARD_PLAYED:
				plays += 1
			Types.LOG_POTION:
				drinks += 1
			Types.LOG_CARD_DISCARDED:
				discards += 1
			Types.LOG_EXCHANGE:
				plays += 1
	return {"plays": plays, "drinks": drinks, "discards": discards, "total": plays + drinks + discards}


static func _drink_action(legal: Array, pid: String) -> Dictionary:
	for a: Variant in _of_type(legal, Types.ACTION_DRINK_POTION):
		if int((a as Dictionary)["prompt_id"]) < 0:
			return a
	return Types.make_action_drink_potion(pid)


static func _keep(view: Dictionary, pid: String, iid: int) -> float:
	var c: Dictionary = BotEval.hand_card(Types.get_player(view, pid), iid)
	if c.is_empty():
		return 3.0  # comodín en mesa (Scroll of Elements)
	var cid: String = String(c["card_id"])
	# No acaparar defensivas: solo se valora la primera de la mano; las demás
	# (y Magic Capture, que no protege) son descartables.
	if cid == Types.CARD_MAGIC_CAPTURE:
		return 0.5
	if BotEval.DEFENSIVE_IDS.has(cid):
		for o: Variant in Types.get_player(view, pid)["hand"] as Array:
			var od: Dictionary = o
			if int(od["iid"]) < iid and BotEval.DEFENSIVE_IDS.has(String(od["card_id"])):
				return 0.6
	return BotEval.keep_value(view, pid, cid)


static func _cards_keep(view: Dictionary, pid: String, iids: Array) -> float:
	var sum: float = 0.0
	for i: Variant in iids:
		sum += _keep(view, pid, int(i))
	return sum


# =============================================================================
# Turno principal
# =============================================================================

static func _play_net(view: Dictionary, pid: String, a: Dictionary) -> float:
	var me: Dictionary = Types.get_player(view, pid)
	var card: Dictionary = BotEval.hand_card(me, int(a["card"]))
	if card.is_empty():
		return -INF
	var def: Dictionary = CardCatalog.get_def(String(card["card_id"]))
	if def.is_empty():
		return -INF
	var value: float = BotEval.play_value(view, pid, def, a)
	if value <= -999.0:
		return -INF
	var cost: int = Damage.card_cost(view, pid, def, int(card["iid"]), false)
	var net: float = value - MANA_WEIGHT * float(cost) - 0.8 * _cards_keep(view, pid, a["payment"] as Array)
	# Reserva de maná para poder responder con una defensiva.
	var mana_after: int = int(me["mana"]) - cost
	if value < 8.0 and mana_after < _cheapest_defensive(view, pid, int(card["iid"]), a["payment"] as Array, int(me["mana"])):
		net -= 1.2
	if String(def.get("type", "")) != Types.CARD_TYPE_OFFENSIVE and is_scarce(view, pid):
		net -= SCARCE_PENALTY * float(cost)
	return net


## Coste de la defensiva más barata de la mano que hoy podría pagar (0 si no
## hay ninguna: sin reserva que guardar).
static func _cheapest_defensive(view: Dictionary, pid: String, played_iid: int, payment: Array, mana: int) -> int:
	var best: int = 0
	for c: Variant in Types.get_player(view, pid)["hand"] as Array:
		var cd: Dictionary = c
		var iid: int = int(cd["iid"])
		if iid == played_iid or payment.has(iid):
			continue
		if not BotEval.DEFENSIVE_IDS.has(String(cd["card_id"])):
			continue
		var def: Dictionary = CardCatalog.get_def(String(cd["card_id"]))
		var cost: int = Damage.card_cost(view, pid, def, iid, false)
		if cost <= mana and (best == 0 or cost < best):
			best = cost
	return best


static func _best_play(view: Dictionary, pid: String, legal: Array) -> Dictionary:
	var best: Dictionary = {}
	var best_net: float = -INF
	for a: Variant in _of_type(legal, Types.ACTION_PLAY_CARD):
		var n: float = _play_net(view, pid, a)
		if n > best_net:
			best_net = n
			best = a
	return {"action": best, "score": best_net}


static func _main_candidates(view: Dictionary, pid: String, legal: Array) -> Array:
	var me: Dictionary = Types.get_player(view, pid)
	var turn: Dictionary = view["turn"]
	var counts: Dictionary = _turn_counts(view, pid)
	var end_turn: Dictionary = {}
	for a: Variant in _of_type(legal, Types.ACTION_END_TURN):
		end_turn = a
	var cands: Array = []
	if not end_turn.is_empty():
		cands.append({"action": end_turn, "score": 0.0})
	if int(counts["total"]) >= MAX_ACTIONS_PER_TURN:
		return cands  # anti-bucle: solo terminar el turno
	# 1) Jugadas.
	var best_net: float = -INF
	for a: Variant in _of_type(legal, Types.ACTION_PLAY_CARD):
		var n: float = _play_net(view, pid, a)
		if n > PLAY_THRESHOLD:
			cands.append({"action": a, "score": n})
			best_net = maxf(best_net, n)
	# 2) Beber poción si con más maná la mejor jugada mejora mucho.
	if int(counts["drinks"]) < MAX_DRINKS_PER_TURN and int(me["mana"]) < 9 and potion_room(view, pid, 0):
		var amount: int = Damage.potion_amount(view, pid, false)
		if amount > 0:
			# Vista hipotética con la poción ya bebida (solo se copia al jugador).
			var v2: Dictionary = view.duplicate(false)
			var players2: Array = []
			for pp: Variant in view["players"] as Array:
				players2.append((pp as Dictionary).duplicate(false))
			v2["players"] = players2
			var me2: Dictionary = Types.get_player(v2, pid)
			me2["mana"] = int(me2["mana"]) + amount
			var best2: Dictionary = _best_play(v2, pid, Game.legal_actions(v2, pid))
			var n2: float = float(best2["score"])
			if n2 >= 1.5 and n2 - 1.0 > best_net and (potion_room(view, pid, DRINK_RESERVE) or n2 >= DRINK_FORCE_NET):
				cands.append({"action": _drink_action(legal, pid), "score": n2 - 1.0})
	# 3) Habilidades de artefactos y del evento activo.
	for a: Variant in _of_type(legal, Types.ACTION_USE_ARTIFACT):
		var s: float = _use_artifact_score(view, pid, a)
		if s > PLAY_THRESHOLD:
			cands.append({"action": a, "score": s})
	for a: Variant in _of_type(legal, Types.ACTION_USE_EVENT):
		var s2: float = _use_event_score(view, pid, a)
		if s2 > PLAY_THRESHOLD:
			cands.append({"action": a, "score": s2})
	# 4) Intercambiar solo si sobra maná; descartar lo inútil.
	if int(turn["exchanges"]) < MAX_EXCHANGES_PER_TURN:
		var ex_cost: int = Damage.exchange_cost(view, pid, false)
		if int(me["mana"]) - ex_cost >= EXCHANGE_RESERVE:
			for a: Variant in _of_type(legal, Types.ACTION_EXCHANGE):
				var k: float = _keep(view, pid, int((a as Dictionary)["card"]))
				if k < 2.9:
					cands.append({"action": a, "score": 0.3 + (3.0 - k) * 0.05})
	var idle: bool = best_net == -INF
	if int(counts["discards"]) < MAX_DISCARDS_PER_TURN:
		# Descartar lo inútil; si no hay jugada posible, renovar la peor carta
		# (se roba hasta el límite al empezar el siguiente turno).
		var worst: Dictionary = {}
		var worst_keep: float = INF
		for a: Variant in _of_type(legal, Types.ACTION_DISCARD):
			var cards: Array = (a as Dictionary)["cards"]
			if cards.size() != 1:
				continue
			var k: float = _keep(view, pid, int(cards[0]))
			if k <= JUNK_KEEP:
				cands.append({"action": a, "score": 0.4})
			elif k < worst_keep:
				worst_keep = k
				worst = a
		if idle and not worst.is_empty() and int(counts["discards"]) < MAX_CYCLE_DISCARDS:
			cands.append({"action": worst, "score": 0.15})
	# Sin jugadas: acumular maná bebiendo si sobra margen de pociones.
	if idle and int(me["mana"]) < STOCKPILE_MANA and int(counts["drinks"]) < MAX_DRINKS_PER_TURN \
			and potion_room(view, pid, 2):
		cands.append({"action": _drink_action(legal, pid), "score": 0.25})
	return cands


static func _use_artifact_score(view: Dictionary, pid: String, a: Dictionary) -> float:
	if int(a["prompt_id"]) >= 0:
		return -1.0
	var me: Dictionary = Types.get_player(view, pid)
	var card_id: String = ""
	for c: Variant in me["artifacts"] as Array:
		if int((c as Dictionary)["iid"]) == int(a["card"]):
			card_id = String((c as Dictionary)["card_id"])
	match card_id:
		Types.CARD_TWARDOWSKYS_MIRROR:
			return 0.6
		Types.CARD_TRANSFORMATION_GLOVE:
			var cards: Array = a["cards"]
			if cards.is_empty():
				return -1.0
			var s: float = (2.2 - _cards_keep(view, pid, cards)) * 0.8
			return s if s > 0.0 else -1.0
	return -1.0


static func _use_event_score(view: Dictionary, pid: String, a: Dictionary) -> float:
	if int(a["prompt_id"]) >= 0:
		return -1.0
	var ev: Dictionary = view["active_event"]
	if ev.is_empty() or String(ev["card_id"]) != Types.CARD_ELIXIR_TRANSMUTATION:
		return -1.0
	var me: Dictionary = Types.get_player(view, pid)
	var amount: int = 0
	for k: Variant in (a["extra"] as Dictionary):
		var v: Variant = (a["extra"] as Dictionary)[k]
		if v is int:
			amount = maxi(amount, int(v))
	var hp: int = int(me["hp"])
	var mx: int = BotEval.max_hp(view)
	if amount <= 0 or hp + amount > mx:
		return -1.0
	var left: int = int(me["mana"]) - 2 * amount
	if left < 0 or (hp >= 5 and left < 2):
		return -1.0
	return float(amount) * (2.0 + float(mx - hp) * 0.6) - MANA_WEIGHT * 2.0 * float(amount)


# =============================================================================
# Prompts
# =============================================================================

static func _prompt_candidates(view: Dictionary, pid: String, legal: Array, pr: Dictionary) -> Array:
	var me: Dictionary = Types.get_player(view, pid)
	var pr_id: int = int(pr["id"])
	var data: Dictionary = pr["data"]
	var acts: Array = []
	for a: Variant in legal:
		var ad: Dictionary = a
		if ad.has("prompt_id") and int(ad["prompt_id"]) == pr_id:
			acts.append(ad)
	var cands: Array = []
	var hp: int = int(me["hp"])
	match String(pr["kind"]):
		Types.PROMPT_DISCARD:
			for a: Variant in acts:
				var ad: Dictionary = a
				if String(ad["type"]) == Types.ACTION_CHOOSE_CARDS:
					cands.append({"action": ad, "score": -_cards_keep(view, pid, ad["cards"] as Array)})
		Types.PROMPT_CHOOSE_TARGETS:
			for a: Variant in acts:
				var ad: Dictionary = a
				if String(ad["type"]) == Types.ACTION_CHOOSE_TARGETS:
					cands.append({"action": ad, "score": _targets_score(view, pid, String(pr["source"]), ad["targets"] as Array)})
		Types.PROMPT_CHOOSE_CARD:
			var known: Dictionary = _revealed_cards(view, pid)
			for a: Variant in acts:
				var ad: Dictionary = a
				if String(ad["type"]) != Types.ACTION_CHOOSE_CARDS:
					continue
				var s: float = 0.0
				for i: Variant in ad["cards"] as Array:
					s += BotEval.keep_value(view, pid, String(known.get(int(i), ""))) if known.has(int(i)) else 1.0
				cands.append({"action": ad, "score": s})
		Types.PROMPT_MANA_SHORTFALL:
			var missing: int = int(data.get("missing", 1))
			var drink: bool = potion_room(view, pid, 0) and (hp <= missing + 2 or potion_room(view, pid, 3))
			_drink_or_decline(acts, drink, cands)
		Types.PROMPT_DRINK_OR_SUFFER:
			var loss: int = int(data.get("hp", 2))
			var drink2: bool = potion_room(view, pid, 0) and (hp <= loss + 2 or potion_room(view, pid, 4))
			_drink_or_decline(acts, drink2, cands)
		Types.PROMPT_USE_MAGIC_CAP:
			var loss_ev: Dictionary = data.get("loss", {}) as Dictionary
			var amount: int = int(loss_ev.get("amount", 0))
			var is_mana: bool = String(loss_ev.get("kind", "")) == Damage.KIND_MANA_LOSS
			var use: bool = amount >= 2 or (not is_mana and amount >= hp) or (is_mana and amount >= 3)
			for a: Variant in acts:
				var ad: Dictionary = a
				if String(ad["type"]) == Types.ACTION_USE_ARTIFACT:
					cands.append({"action": ad, "score": 5.0 if use else -5.0})
				elif String(ad["type"]) == Types.ACTION_DECLINE:
					cands.append({"action": ad, "score": 0.0})
		Types.PROMPT_MANA_FOCUS:
			var damage: int = int(data.get("damage", 0))
			var mana: int = int(me["mana"])
			var want: int = 0
			if hp <= damage or mana - damage >= 3:
				want = mini(damage, mana)
			elif hp - damage <= 3:
				want = mini(damage, mana)
			for a: Variant in acts:
				var ad: Dictionary = a
				if String(ad["type"]) == Types.ACTION_USE_EVENT:
					var k: int = int((ad["extra"] as Dictionary).get("mana", 0))
					if k > 0:
						cands.append({"action": ad, "score": 3.0 - absf(float(k - want)) if want > 0 else -5.0})
				elif String(ad["type"]) == Types.ACTION_DECLINE:
					cands.append({"action": ad, "score": 0.0 if want == 0 else -1.0})
	if cands.is_empty():
		# Prompt desconocido: rechazar si se puede; si no, la primera respuesta.
		for a: Variant in acts:
			if String((a as Dictionary)["type"]) == Types.ACTION_DECLINE:
				return [{"action": a, "score": 0.0}]
		if not acts.is_empty():
			return [{"action": acts[0], "score": 0.0}]
	return cands


static func _drink_or_decline(acts: Array, drink: bool, cands: Array) -> void:
	for a: Variant in acts:
		var ad: Dictionary = a
		if String(ad["type"]) == Types.ACTION_DRINK_POTION:
			cands.append({"action": ad, "score": 5.0 if drink else -5.0})
		elif String(ad["type"]) == Types.ACTION_DECLINE:
			cands.append({"action": ad, "score": 0.0})


## iid -> card_id de las cartas que el jugador ha visto por revelaciones privadas.
static func _revealed_cards(view: Dictionary, pid: String) -> Dictionary:
	var out: Dictionary = {}
	var reveals: Dictionary = view.get("reveals", {}) as Dictionary
	for r: Variant in reveals.get(pid, []) as Array:
		for c: Variant in (r as Dictionary).get("cards", []) as Array:
			out[int((c as Dictionary)["iid"])] = String((c as Dictionary)["card_id"])
	return out


static func _targets_score(view: Dictionary, pid: String, source_id: String, targets: Array) -> float:
	var friendly: bool = [Types.CARD_HEAL, Types.CARD_GREATER_HEAL, Types.CARD_FORCE_FIELD].has(source_id)
	var score: float = 0.0
	for t: Variant in targets:
		var tid: String = String(t)
		var p: Dictionary = Types.get_player(view, tid)
		if p.is_empty():
			continue
		if friendly:
			score += 5.0 if tid == pid else 0.0
		elif tid == pid:
			score -= 10.0
		else:
			score += float(BotEval.max_hp(view) - int(p["hp"])) * 0.5 + BotEval.threat(p) * 0.2
	return score


# =============================================================================
# Ventana de reacción
# =============================================================================

static func _incoming_damage(view: Dictionary, spell: Dictionary, pid: String) -> int:
	if String(spell.get("caster", "")) == pid or bool(spell.get("cancelled", false)):
		return 0
	var card: Dictionary = spell.get("card", {}) as Dictionary
	var def: Dictionary = CardCatalog.get_def(String(card.get("card_id", "")))
	if def.is_empty() or String(def.get("type", "")) != Types.CARD_TYPE_OFFENSIVE:
		return 0
	var total: int = 0
	for e: Variant in BotEval.affected(view, def, String(spell["caster"]), spell.get("targets", []) as Array):
		if String((e as Dictionary)["pid"]) == pid:
			total += int((e as Dictionary)["dmg"])
	return total


## Daño que ya impide una respuesta mía en la pila.
static func _stack_protection(re: Dictionary, pid: String, incoming: int) -> int:
	var prot: int = 0
	for r: Variant in re.get("stack", []) as Array:
		var rd: Dictionary = r
		if String(rd.get("caster", "")) != pid:
			continue
		match String((rd.get("card", {}) as Dictionary).get("card_id", "")):
			Types.CARD_FROZEN_BUNNY, Types.CARD_ANNIHILATION:
				prot += incoming
			Types.CARD_MAGIC_SHIELD, Types.CARD_MIRROR_SHIELD:
				prot += 2
	return prot


static func _reaction_candidates(view: Dictionary, pid: String, legal: Array) -> Array:
	var re: Dictionary = view["reaction"]
	var me: Dictionary = Types.get_player(view, pid)
	var spell: Dictionary = re["spell"]
	var hp: int = int(me["hp"])
	var mana: int = int(me["mana"])
	var pass_a: Dictionary = Types.make_action_pass_reaction(pid)
	for a: Variant in _of_type(legal, Types.ACTION_PASS_REACTION):
		pass_a = a
	var incoming: int = _incoming_damage(view, spell, pid)
	var d: int = incoming - _stack_protection(re, pid, incoming)
	if d <= 0:
		return [{"action": pass_a, "score": 0.0}]
	var lethal: bool = d >= hp
	var cands: Array = [{"action": pass_a, "score": 0.5 if lethal else 1.5}]
	var spell_iid: int = int((spell.get("card", {}) as Dictionary).get("iid", -1))
	var rival: String = _weakest_rival(view, pid)
	var reacted: bool = false
	for a: Variant in _of_type(legal, Types.ACTION_REACT):
		var ad: Dictionary = a
		var card: Dictionary = BotEval.hand_card(me, int(ad["card"]))
		if card.is_empty():
			continue
		var cid: String = String(card["card_id"])
		var targets: Array = ad["targets"]
		var saved: int = 0
		var bonus: float = 0.0
		match cid:
			Types.CARD_FROZEN_BUNNY:
				saved = d
			Types.CARD_MAGIC_SHIELD:
				saved = mini(2, d)
			Types.CARD_MIRROR_SHIELD:
				saved = mini(2, d)
				bonus = 2.0 + (0.5 if _mentions(ad, rival) else 0.0)
			Types.CARD_ANNIHILATION:
				if int(ad["target_card"]) == spell_iid:
					saved = d
			Types.CARD_LAST_WISH:
				if lethal:
					bonus = 3.5
		if saved <= 0 and bonus <= 0.0:
			continue
		if cid != Types.CARD_LAST_WISH and cid != Types.CARD_ANNIHILATION \
				and not targets.is_empty() and not targets.has(pid):
			continue
		var def: Dictionary = CardCatalog.get_def(cid)
		var cost: int = Damage.card_cost(view, pid, def, int(card["iid"]), false)
		if cost > mana:
			continue
		var value: float = bonus
		if saved > 0:
			var survives: bool = hp - (d - saved) > 0
			value += 60.0 if (lethal and survives) else float(saved) * (3.0 if hp - d <= 2 else 1.6)
		var net: float = value - MANA_WEIGHT * float(cost) - 0.4 * BotEval.keep_value(view, pid, cid) \
			- 0.8 * _cards_keep(view, pid, ad["payment"] as Array)
		cands.append({"action": ad, "score": net})
		reacted = true
	# Letal sin poder pagar la defensiva: beber una poción primero.
	if lethal and not reacted and potion_room(view, pid, 0) \
			and int(_turn_counts(view, pid)["drinks"]) < MAX_DRINKS_PER_TURN:
		var amount: int = Damage.potion_amount(view, pid, false)
		for c: Variant in me["hand"] as Array:
			var cd: Dictionary = c
			var cid2: String = String(cd["card_id"])
			if not [Types.CARD_FROZEN_BUNNY, Types.CARD_MAGIC_SHIELD, Types.CARD_MIRROR_SHIELD].has(cid2):
				continue
			var cost2: int = Damage.card_cost(view, pid, CardCatalog.get_def(cid2), int(cd["iid"]), false)
			if cost2 > mana and cost2 <= mana + amount:
				cands.append({"action": _drink_action(legal, pid), "score": 50.0})
				break
	return cands


static func _mentions(a: Dictionary, pid: String) -> bool:
	if pid == "":
		return false
	return JSON.stringify(a).contains("\"%s\"" % pid)


static func _weakest_rival(view: Dictionary, pid: String) -> String:
	var best: String = ""
	var best_hp: int = 1 << 30
	for id: String in Types.alive_ids(view):
		if id == pid:
			continue
		var hp: int = int(Types.get_player(view, id)["hp"])
		if hp < best_hp:
			best_hp = hp
			best = id
	return best

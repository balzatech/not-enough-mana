class_name Game
extends RefCounted
## Reducer principal del motor (T4).
##
## new_game(players, cfg, seed) -> estado inicial (status=playing, turno 1).
## reduce(state, action)        -> Types.make_result(state, error, events). NUNCA muta
##                                 la entrada ni lanza: los errores vuelven en "error".
## legal_actions(state, pid)    -> acciones concretas aceptables por reduce().
##
## Puntos de extensión (sin tocar este archivo):
##  * Efectos de carta: EffectRegistry.register(card_id, fn). Se llaman al
##    resolver un hechizo/artefacto (resolve_spell) o al robar un evento.
##  * Hooks de registro (EffectRegistry.register_hook):
##      Types.HOOK_CAN_PLAY    validación extra antes de jugar (escribe ctx.error).
##      Types.HOOK_TURN_START  carta en mesa de pid al empezar su turno.
##      Types.HOOK_EVENT_END   el evento activo deja de estarlo.
##      Types.HOOK_USE         USE_ARTIFACT sobre un artefacto propio.
##      Types.HOOK_USE_EVENT   USE_EVENT sobre el evento activo.
##      HOOK_PROMPT            respuesta (CHOOSE_*/DECLINE/USE_*) a un prompt cuyo
##                             `source` es esa carta y cuyo kind no gestiona T4.
##                             ctx.extra.prompt = el prompt; ctx.action = acción.
##      HOOK_LEGAL_ACTIONS     añade acciones a ctx.actions (se llama por cada
##                             artefacto del jugador, el evento activo y el
##                             `source` de sus prompts pendientes).
##      HOOK_PAY_WILDCARD      comodín de pago en mesa (Scroll of Elements). ctx:
##                             {card: table_card, caster, req, def, mode, ok, events}.
##                             mode "check": poner ctx.ok = true si sustituye a req.
##                             mode "consume": gastarlo (moverlo al descarte, etc.).
##  * Ventana de reacción (T6b, reactions.gd). Si Reactions define estos static,
##    Game los usa; si no, los hechizos se resuelven directamente:
##      static func open(state, spell, events) -> Dictionary  # {state, error}
##      static func handle(state, action, events) -> Dictionary  # REACT / PASS_REACTION
##      static func legal_actions(state, pid) -> Array         # opcional
##    Para resolver el hechizo al cerrar la ventana: Game.resolve_spell(state,
##    spell, events) (con el hechizo ya fuera de state.reaction).

const HOOK_PROMPT: String = Types.HOOK_PROMPT
const HOOK_LEGAL_ACTIONS: String = Types.HOOK_LEGAL_ACTIONS
const HOOK_PAY_WILDCARD: String = Types.HOOK_PAY_WILDCARD

const REACTIONS_SCRIPT: Script = preload("res://src/engine/reactions.gd")

## Seguridad anti-bucles (mazos formados solo por eventos, etc.).
const MAX_LOOP: int = 2000
## Por encima de este tamaño de mano legal_actions no enumera todos los
## subconjuntos para DISCARD (solo cartas sueltas y la mano entera).
const MAX_SUBSET_HAND: int = 8


# =============================================================================
# Partida nueva
# =============================================================================

## Crea una partida nueva. players = Array de Types.make_player() en orden de
## asiento (sentido horario); cfg = overrides de Types.default_config();
## seed_value = semilla del Rng. El mazo sale de CardCatalog (cartas jugables).
static func new_game(players: Array, cfg: Dictionary = {}, seed_value: int = 0) -> Dictionary:
	var s: Dictionary = Types.make_state(cfg, seed_value)
	var c: Dictionary = s["config"]
	var ps: Array = []
	for raw: Variant in players:
		var src: Dictionary = raw
		var pd: Dictionary = Types.make_player(String(src.get("id", "")), String(src.get("name", "")))
		pd.merge(src.duplicate(true), true)
		pd["hp"] = int(c["start_hp"])
		pd["mana"] = int(c["start_mana"])
		pd["potions"] = 0
		pd["hand"] = []
		pd["artifacts"] = []
		pd["curses"] = []
		pd["flags"] = Types.make_player_flags()
		pd["eliminated"] = false
		pd["eliminated_reason"] = ""
		ps.append(pd)
	s["players"] = ps
	if bool(c["pool_enabled"]):
		var pool: Dictionary = s["pool"]
		pool["hp"] = maxi(0, int(pool["hp"]) - int(c["start_hp"]) * ps.size())
		pool["mana"] = maxi(0, int(pool["mana"]) - int(c["start_mana"]) * ps.size())
	var deck: Array = Deck.build_instances(CardCatalog.all_defs(), c)
	s["deck"] = deck
	s["card_total"] = deck.size()
	Deck.shuffle_pile(s, "deck")
	s["status"] = Types.STATUS_PLAYING
	var events: Array = []
	events.append(Types.make_log_entry(Types.LOG_GAME_STARTED, 0, "", {"players": ps.size(), "deck": deck.size()}))
	deal_initial(s, events)
	if not ps.is_empty():
		_start_turn(s, eldest(s), events)
		_finalize(s, events)
	_append_log(s, events)
	return s


## Reparte config.start_hand cartas a cada jugador. Los eventos que salgan se
## descartan y se roba otra en su lugar (regla 1.1.3).
static func deal_initial(s: Dictionary, events: Array) -> void:
	var n: int = int((s["config"] as Dictionary)["start_hand"])
	for p: Variant in s["players"]:
		var pd: Dictionary = p
		var hand: Array = pd["hand"]
		var guard: int = 0
		while hand.size() < n and guard < MAX_LOOP:
			guard += 1
			var c: Dictionary = Deck.pop_top(s, events)
			if c.is_empty():
				break
			if is_event(String(c["card_id"])):
				Deck.to_discard(s, c)
				events.append(Types.make_log_entry(Types.LOG_CARD_DISCARDED, 0, String(pd["id"]),
					{"cards": [int(c["iid"])], "card_ids": [String(c["card_id"])], "setup_event": true}))
				continue
			hand.append(c)


## Id del mago de más edad (empate: el primero en orden de asiento).
static func eldest(s: Dictionary) -> String:
	var best: String = ""
	var best_age: int = -1
	for p: Variant in s["players"]:
		var pd: Dictionary = p
		if bool(pd["eliminated"]):
			continue
		if int(pd["age"]) > best_age:
			best_age = int(pd["age"])
			best = String(pd["id"])
	return best


static func is_event(card_id: String) -> bool:
	return String(CardCatalog.get_def(card_id).get("type", "")) == Types.CARD_TYPE_EVENT


# =============================================================================
# Reducer
# =============================================================================

## Aplica una acción. Devuelve Types.make_result(state, error, events). Nunca
## muta la entrada (duplicate(true) al entrar). Si hay error, devuelve el estado
## de entrada y events = [].
static func reduce(state: Dictionary, action: Dictionary) -> Dictionary:
	if Types.validate_action_shape(action) != Types.ERR_NONE:
		return Types.make_result(state, Types.ERR_INVALID_ACTION, [])
	if String(state.get("status", "")) != Types.STATUS_PLAYING:
		return Types.make_result(state, Types.ERR_GAME_NOT_PLAYING, [])
	var pid: String = action["player"]
	var p: Dictionary = Types.get_player(state, pid)
	if p.is_empty():
		return Types.make_result(state, Types.ERR_UNKNOWN_PLAYER, [])
	if bool(p["eliminated"]):
		return Types.make_result(state, Types.ERR_PLAYER_ELIMINATED, [])
	var s: Dictionary = state.duplicate(true)
	var events: Array = []
	var err: String = _dispatch(s, action, events)
	if err != Types.ERR_NONE:
		return Types.make_result(state, err, [])
	_finalize(s, events)
	s["rev"] = int(s["rev"]) + 1
	_append_log(s, events)
	return Types.make_result(s, Types.ERR_NONE, events)


static func _dispatch(s: Dictionary, a: Dictionary, events: Array) -> String:
	var pid: String = a["player"]
	var t: String = a["type"]
	match t:
		Types.ACTION_PLAY_CARD, Types.ACTION_DISCARD, Types.ACTION_EXCHANGE, Types.ACTION_END_TURN:
			var e: String = in_turn_error(s, pid)
			if e != Types.ERR_NONE:
				return e
			match t:
				Types.ACTION_PLAY_CARD:
					return _play_card(s, a, events)
				Types.ACTION_DISCARD:
					return _discard(s, a, events)
				Types.ACTION_EXCHANGE:
					return _exchange(s, a, events)
				_:
					return _end_turn(s, pid, events)
		Types.ACTION_DRINK_POTION:
			return _drink(s, a, events)
		Types.ACTION_CHOOSE_TARGETS, Types.ACTION_CHOOSE_CARDS, Types.ACTION_DECLINE:
			return _answer_prompt(s, a, events)
		Types.ACTION_REACT, Types.ACTION_PASS_REACTION:
			if (s["reaction"] as Dictionary).is_empty() or not REACTIONS_SCRIPT.has_method("handle"):
				return Types.ERR_NO_REACTION
			var r: Dictionary = REACTIONS_SCRIPT.call("handle", s, a, events)
			_adopt(s, r.get("state", s))
			return String(r.get("error", Types.ERR_NONE))
		Types.ACTION_USE_ARTIFACT:
			return _use_artifact(s, a, events)
		Types.ACTION_USE_EVENT:
			return _use_event(s, a, events)
		Types.ACTION_BREAK_RULE:
			return _break_rule(s, a, events)
		Types.ACTION_CONCEDE:
			Damage.eliminate(s, pid, Types.ELIM_CONCEDE, events)
			return Types.ERR_NONE
	return Types.ERR_INVALID_ACTION


## "" si pid puede hacer ahora una acción de turno (jugar, descartar,
## intercambiar, terminar); si no, el ERR_* correspondiente.
static func in_turn_error(s: Dictionary, pid: String) -> String:
	var turn: Dictionary = s["turn"]
	if String(turn["current"]) != pid:
		return Types.ERR_NOT_YOUR_TURN
	if not (s["reaction"] as Dictionary).is_empty():
		return Types.ERR_REACTION_PENDING
	if not (s["pending"] as Array).is_empty():
		return Types.ERR_PROMPT_PENDING
	if String(turn["phase"]) != Types.PHASE_MAIN:
		return Types.ERR_WRONG_PHASE
	return Types.ERR_NONE


# =============================================================================
# Turnos
# =============================================================================

## Siguiente jugador vivo en sentido horario después de pid ("" si no hay).
static func next_alive_after(s: Dictionary, pid: String) -> String:
	var ps: Array = s["players"]
	var i: int = Types.player_index(s, pid)
	for k: int in range(1, ps.size() + 1):
		var pd: Dictionary = ps[posmod(i + k, ps.size())]
		if not bool(pd["eliminated"]):
			return String(pd["id"])
	return ""


## Empieza el turno de pid: caducidades, hooks de mesa, Freeze (salta el turno)
## y robo hasta el límite de mano.
static func _start_turn(s: Dictionary, first_pid: String, events: Array) -> void:
	var pid: String = first_pid
	var turn: Dictionary = s["turn"]
	for _guard: int in MAX_LOOP:
		if pid == "":
			return
		turn["number"] = int(turn["number"]) + 1
		turn["current"] = pid
		turn["phase"] = Types.PHASE_DRAW
		turn["exchanges"] = 0
		events.append(Types.make_log_entry(Types.LOG_TURN_STARTED, int(turn["number"]), pid))
		var tp: Dictionary = Types.get_player(s, pid)
		tp["turns_played"] = int(tp["turns_played"]) + 1
		Modifiers.expire(s, Types.EXPIRES_OWNER_TURN_START, pid)
		for p: Variant in s["players"]:
			var fl: Dictionary = (p as Dictionary)["flags"]
			if String(fl["force_field"]) == pid:
				fl["force_field"] = ""
		_run_turn_start_hooks(s, pid, events)
		var pd: Dictionary = Types.get_player(s, pid)
		if bool(pd["eliminated"]):
			return  # _finalize pasará el turno
		var flags: Dictionary = pd["flags"]
		if int(flags["frozen"]) > 0:
			flags["frozen"] = int(flags["frozen"]) - 1
			events.append(Types.make_log_entry(Types.LOG_TURN_SKIPPED, int(turn["number"]), pid,
				{"frozen_left": int(flags["frozen"])}))
			_end_turn_cleanup(s, pid)
			pid = next_alive_after(s, pid)
			continue
		draw_up_to_limit(s, pid, events)
		turn["phase"] = Types.PHASE_MAIN
		return


static func _run_turn_start_hooks(s: Dictionary, pid: String, events: Array) -> void:
	var pd: Dictionary = Types.get_player(s, pid)
	var cards: Array = []
	cards.append_array(pd["artifacts"] as Array)
	cards.append_array(pd["curses"] as Array)
	for c: Variant in cards:
		var tc: Dictionary = c
		var fn: Callable = EffectRegistry.get_hook(Types.HOOK_TURN_START, String(tc["card_id"]))
		if fn.is_valid():
			var ctx: Dictionary = _ctx(s, tc, pid, events)
			_call(fn, s, ctx)


## Limpieza al terminar el turno de pid (también si se lo salta por Freeze).
static func _end_turn_cleanup(s: Dictionary, pid: String) -> void:
	(s["turn"] as Dictionary)["phase"] = Types.PHASE_END
	Modifiers.expire(s, Types.EXPIRES_END_OF_TURN)
	var pd: Dictionary = Types.get_player(s, pid)
	if not pd.is_empty():
		(pd["flags"] as Dictionary)["blinded"] = false


static func _end_turn(s: Dictionary, pid: String, events: Array) -> String:
	_end_turn_cleanup(s, pid)
	_start_turn(s, next_alive_after(s, pid), events)
	return Types.ERR_NONE


## Comprueba victoria y, si el jugador en turno ha sido eliminado (y no hay
## ventana de reacción abierta), pasa el turno al siguiente.
static func _finalize(s: Dictionary, events: Array) -> void:
	for _guard: int in MAX_LOOP:
		if String(s["status"]) != Types.STATUS_PLAYING:
			return
		var alive: Array[String] = Types.alive_ids(s)
		if alive.size() <= 1:
			s["status"] = Types.STATUS_FINISHED
			s["winners"] = alive.duplicate()
			s["pending"] = []
			events.append(Types.make_log_entry(Types.LOG_GAME_OVER, Damage.turn_no(s), "",
				{"winners": alive.duplicate()}))
			return
		if not (s["reaction"] as Dictionary).is_empty():
			# Si quienes debían responder han quedado eliminados, la ventana se
			# cierra (y el hechizo se resuelve) sin esperar a nadie.
			if not REACTIONS_SCRIPT.has_method("sync"):
				return
			var r: Dictionary = REACTIONS_SCRIPT.call("sync", s, events)
			_adopt(s, r.get("state", s))
			if not (s["reaction"] as Dictionary).is_empty():
				return
			continue
		var cur: String = (s["turn"] as Dictionary)["current"]
		var cp: Dictionary = Types.get_player(s, cur)
		if cp.is_empty() or not bool(cp["eliminated"]):
			return
		_end_turn_cleanup(s, cur)
		_start_turn(s, next_alive_after(s, cur), events)


# =============================================================================
# Robo y eventos
# =============================================================================

## Roba hasta el límite de mano de pid (Damage.hand_limit).
static func draw_up_to_limit(s: Dictionary, pid: String, events: Array) -> void:
	var pd: Dictionary = Types.get_player(s, pid)
	for _guard: int in MAX_LOOP:
		if bool(pd["eliminated"]) or String(s["status"]) != Types.STATUS_PLAYING:
			return
		if (pd["hand"] as Array).size() >= Damage.hand_limit(s, pid):
			return
		if not draw_one(s, pid, events):
			return


## Roba una carta para pid. Si sale un evento, lo activa y roba otra en su
## lugar. Devuelve false si no quedan cartas (mazo y descarte vacíos).
static func draw_one(s: Dictionary, pid: String, events: Array) -> bool:
	var pd: Dictionary = Types.get_player(s, pid)
	var limit: int = int(s["card_total"]) + 1
	for _guard: int in limit:
		if bool(pd["eliminated"]):
			return false
		var c: Dictionary = Deck.pop_top(s, events)
		if c.is_empty():
			return false
		if is_event(String(c["card_id"])):
			activate_event(s, c, pid, events)
			continue
		(pd["hand"] as Array).append(c)
		events.append(Types.make_log_entry(Types.LOG_CARD_DRAWN, Damage.turn_no(s), pid,
			{"iid": int(c["iid"]), "card_id": String(c["card_id"])}, [pid]))
		return true
	return false


## Pone un evento en el centro: el anterior deja de estar activo (HOOK_EVENT_END,
## caducan los modificadores next_event, va al descarte) y se aplica el efecto
## del nuevo vía EffectRegistry.
static func activate_event(s: Dictionary, card: Dictionary, drawer: String, events: Array) -> void:
	var old: Dictionary = s["active_event"]
	if not old.is_empty():
		var end_fn: Callable = EffectRegistry.get_hook(Types.HOOK_EVENT_END, String(old["card_id"]))
		if end_fn.is_valid():
			_call(end_fn, s, _ctx(s, old, drawer, events))
		Modifiers.expire(s, Types.EXPIRES_NEXT_EVENT)
		var cur_old: Dictionary = s["active_event"]
		if not cur_old.is_empty():
			Deck.to_discard(s, Types.make_card_instance(int(cur_old["iid"]), String(cur_old["card_id"])))
	else:
		Modifiers.expire(s, Types.EXPIRES_NEXT_EVENT)
	s["active_event"] = Types.make_table_card(int(card["iid"]), String(card["card_id"]), "")
	events.append(Types.make_log_entry(Types.LOG_EVENT_DRAWN, Damage.turn_no(s), drawer,
		{"iid": int(card["iid"]), "card_id": String(card["card_id"])}))
	var fn: Callable = EffectRegistry.get_effect(String(card["card_id"]))
	if fn.is_valid():
		var ctx: Dictionary = _ctx(s, card, drawer, events)
		_call(fn, s, ctx)


# =============================================================================
# Jugar carta
# =============================================================================

static func _play_card(s: Dictionary, a: Dictionary, events: Array) -> String:
	var pid: String = a["player"]
	var iid: int = a["card"]
	var p: Dictionary = Types.get_player(s, pid)
	if Deck.hand_index(p, iid) < 0:
		return Types.ERR_CARD_NOT_IN_HAND
	var card: Dictionary = (p["hand"] as Array)[Deck.hand_index(p, iid)]
	var def: Dictionary = CardCatalog.get_def(String(card["card_id"]))
	if def.is_empty():
		return Types.ERR_UNKNOWN_CARD
	var chk: Dictionary = check_play(s, pid, card, def, a)
	if String(chk["error"]) != Types.ERR_NONE:
		return chk["error"]
	Deck.take_from_hand(p, iid)
	var cost: int = Damage.card_cost(s, pid, def, iid, true)
	Damage.pay_mana(s, pid, cost)
	var paid_ids: Array = []
	var paid_cards: Array = []
	for x: Variant in chk["pay_hand"]:
		var pc: Dictionary = Deck.take_from_hand(p, int(x))
		Deck.to_discard(s, pc)
		paid_ids.append(int(x))
		paid_cards.append(String(pc["card_id"]))
	for x: Variant in chk["pay_table"]:
		var found: Dictionary = Deck.find_in_play(s, int(x))
		var tc: Dictionary = found["card"]
		var fn: Callable = EffectRegistry.get_hook(HOOK_PAY_WILDCARD, String(tc["card_id"]))
		var ctx: Dictionary = _ctx(s, tc, pid, events)
		ctx["mode"] = "consume"
		ctx["def"] = def
		_call(fn, s, ctx)
		paid_ids.append(int(x))
		paid_cards.append(String(tc["card_id"]))
	var targets: Array = chk["targets"]
	events.append(Types.make_log_entry(Types.LOG_CARD_PLAYED, Damage.turn_no(s), pid, {
		"iid": iid, "card_id": String(card["card_id"]), "targets": targets.duplicate(),
		"target_card": int(a["target_card"]), "payment": paid_ids, "payment_cards": paid_cards, "cost": cost,
	}))
	var spell: Dictionary = Types.make_spell(card, pid, targets, a["extra"] as Dictionary, false, int(a["target_card"]))
	(spell["data"] as Dictionary)["payment"] = paid_ids
	var r: Dictionary
	if bool(def.get("is_spell", false)) and REACTIONS_SCRIPT.has_method("open"):
		r = REACTIONS_SCRIPT.call("open", s, spell, events)
	else:
		r = resolve_spell(s, spell, events, a)
	_adopt(s, r.get("state", s))
	return String(r.get("error", Types.ERR_NONE))


## Comprueba si pid puede jugar `card` (instancia de su mano) con la acción `a`
## SIN aplicar nada. Devuelve {error, targets, pay_hand:[iid], pay_table:[iid], cost}.
## Llama al hook can_play (que no debe mutar el estado).
static func check_play(s: Dictionary, pid: String, card: Dictionary, def: Dictionary, a: Dictionary) -> Dictionary:
	var out: Dictionary = {"error": Types.ERR_NONE, "targets": [], "pay_hand": [], "pay_table": [], "cost": 0}
	var ctype: String = def.get("type", "")
	var card_id: String = card["card_id"]
	if not bool(def.get("playable", false)) or ctype == Types.CARD_TYPE_EVENT \
			or ctype == Types.CARD_TYPE_NON_PLAYABLE or ctype == Types.CARD_TYPE_DEFENSIVE:
		out["error"] = Types.ERR_CARD_NOT_PLAYABLE
		return out
	var p: Dictionary = Types.get_player(s, pid)
	if ctype == Types.CARD_TYPE_OFFENSIVE and bool((p["flags"] as Dictionary)["blinded"]):
		out["error"] = Types.ERR_BLINDED
		return out
	if not EffectRegistry.has_effect(card_id):
		out["error"] = Types.ERR_NO_EFFECT
		return out
	var tres: Dictionary = _resolve_targets(s, pid, def, a["targets"] as Array, int(a["target_card"]))
	if String(tres["error"]) != Types.ERR_NONE:
		out["error"] = tres["error"]
		return out
	out["targets"] = tres["targets"]
	var can_fn: Callable = EffectRegistry.get_hook(Types.HOOK_CAN_PLAY, card_id)
	if can_fn.is_valid():
		var ctx: Dictionary = Types.make_effect_ctx(card, def, pid, tres["targets"] as Array, a["extra"] as Dictionary)
		ctx["target_card"] = int(a["target_card"])
		ctx["payment"] = (a["payment"] as Array).duplicate()
		ctx["action"] = a
		can_fn.call(s, ctx)
		if String(ctx["error"]) != Types.ERR_NONE:
			out["error"] = ctx["error"]
			return out
	var pay: Dictionary = check_payment(s, pid, def, int(card["iid"]), a["payment"] as Array)
	if String(pay["error"]) != Types.ERR_NONE:
		out["error"] = pay["error"]
		return out
	out["pay_hand"] = pay["hand"]
	out["pay_table"] = pay["table"]
	var cost: int = Damage.card_cost(s, pid, def, int(card["iid"]), false)
	out["cost"] = cost
	if int(p["mana"]) < cost:
		out["error"] = Types.ERR_INSUFFICIENT_MANA
	return out


static func _resolve_targets(s: Dictionary, pid: String, def: Dictionary, raw: Array, target_card: int) -> Dictionary:
	var alive: Array[String] = Types.alive_ids(s)
	var out: Dictionary = {"error": Types.ERR_NONE, "targets": []}
	var ids: Array = []
	for t: Variant in raw:
		if not (t is String) or ids.has(t):
			out["error"] = Types.ERR_INVALID_TARGET
			return out
		ids.append(t)
	var mode: String = def.get("target", Types.TARGET_NONE)
	var need: int = -1
	match mode:
		Types.TARGET_NONE:
			need = 0
		Types.TARGET_SINGLE, Types.TARGET_OTHER:
			need = 1
		Types.TARGET_TWO:
			need = 2
		Types.TARGET_ALL:
			out["targets"] = alive.duplicate()
			return out
		Types.TARGET_ALL_OTHERS:
			var others: Array = alive.duplicate()
			others.erase(pid)
			out["targets"] = others
			return out
		Types.TARGET_CARD_IN_PLAY:
			if Deck.find_in_play(s, target_card).is_empty():
				out["error"] = Types.ERR_CARD_NOT_IN_PLAY
			return out
	if ids.size() != need:
		out["error"] = Types.ERR_INVALID_TARGET
		return out
	for t: Variant in ids:
		var tid: String = t
		if not alive.has(tid) or (mode == Types.TARGET_OTHER and tid == pid):
			out["error"] = Types.ERR_INVALID_TARGET
			return out
		var tp: Dictionary = Types.get_player(s, tid)
		if bool(def.get("is_spell", false)) and String((tp["flags"] as Dictionary)["force_field"]) != "":
			out["error"] = Types.ERR_TARGET_IMMUNE
			return out
	out["targets"] = ids
	return out


## Valida el pago en cartas de def.cost.cards con los iids `payment` (de la
## mano de pid o comodines en su mesa con HOOK_PAY_WILDCARD). Debe cubrir
## exactamente los requisitos. Devuelve {error, hand:[iid], table:[iid]}.
static func check_payment(s: Dictionary, pid: String, def: Dictionary, card_iid: int, payment: Array) -> Dictionary:
	var out: Dictionary = {"error": Types.ERR_NONE, "hand": [], "table": []}
	var reqs: Array = []
	var cost: Dictionary = def.get("cost", {})
	for r: Variant in cost.get("cards", []):
		var rd: Dictionary = r
		for _i: int in int(rd.get("count", 1)):
			reqs.append(rd)
	if payment.size() != reqs.size():
		out["error"] = Types.ERR_INVALID_PAYMENT
		return out
	var p: Dictionary = Types.get_player(s, pid)
	var items: Array = []
	var seen: Array = []
	for x: Variant in payment:
		if not (x is int) or seen.has(x) or int(x) == card_iid:
			out["error"] = Types.ERR_INVALID_PAYMENT
			return out
		seen.append(x)
		var iid: int = x
		var hi: int = Deck.hand_index(p, iid)
		if hi >= 0:
			var hc: Dictionary = (p["hand"] as Array)[hi]
			items.append({"iid": iid, "table": false, "card": hc, "def": CardCatalog.get_def(String(hc["card_id"]))})
			(out["hand"] as Array).append(iid)
			continue
		var tc: Dictionary = _own_artifact(p, iid)
		if tc.is_empty() or not EffectRegistry.get_hook(HOOK_PAY_WILDCARD, String(tc["card_id"])).is_valid():
			out["error"] = Types.ERR_INVALID_PAYMENT
			return out
		items.append({"iid": iid, "table": true, "card": tc, "def": def})
		(out["table"] as Array).append(iid)
	var used: Array = []
	used.resize(reqs.size())
	used.fill(false)
	if not _match_payment(s, pid, items, reqs, 0, used):
		out["error"] = Types.ERR_INVALID_PAYMENT
	return out


static func _match_payment(s: Dictionary, pid: String, items: Array, reqs: Array, i: int, used: Array) -> bool:
	if i >= items.size():
		return true
	var it: Dictionary = items[i]
	for j: int in reqs.size():
		if bool(used[j]):
			continue
		if _item_meets(s, pid, it, reqs[j] as Dictionary):
			used[j] = true
			if _match_payment(s, pid, items, reqs, i + 1, used):
				return true
			used[j] = false
	return false


static func _item_meets(s: Dictionary, pid: String, it: Dictionary, req: Dictionary) -> bool:
	if bool(it["table"]):
		var tc: Dictionary = it["card"]
		var fn: Callable = EffectRegistry.get_hook(HOOK_PAY_WILDCARD, String(tc["card_id"]))
		var ctx: Dictionary = Types.make_effect_ctx(tc, it["def"] as Dictionary, pid)
		ctx["mode"] = "check"
		ctx["req"] = req
		ctx["ok"] = false
		fn.call(s, ctx)
		return bool(ctx["ok"])
	return card_meets(it["def"] as Dictionary, req)


## ¿La definición `d` cumple el requisito de coste `req`?
static func card_meets(d: Dictionary, req: Dictionary) -> bool:
	var value: String = req.get("value", "")
	match String(req.get("by", "")):
		Types.REQ_ANY:
			return true
		Types.REQ_BY_TYPE:
			return String(d.get("type", "")) == value
		Types.REQ_BY_ELEMENT:
			return String(d.get("element", "")) == value
		Types.REQ_BY_CARD:
			return String(d.get("id", "")) == value
	return false


static func _own_artifact(p: Dictionary, iid: int) -> Dictionary:
	for c: Variant in p["artifacts"]:
		var cd: Dictionary = c
		if int(cd["iid"]) == iid:
			return cd
	return {}


## Resuelve un hechizo (o artefacto/carta no-hechizo): coloca los artefactos en
## la mesa de quien los juega, llama al efecto registrado, caduca los
## modificadores ligados al hechizo y, si la carta no quedó en ningún sitio
## (mesa, mano…), la manda al descarte. Devuelve {state, error}. Si
## spell.cancelled, no aplica el efecto. El hechizo NO debe seguir en
## state.reaction al llamar.
## Atómico: si el efecto devuelve error, se deshacen TODOS sus cambios (estado
## y eventos) antes de devolver el error. Así, al cerrar una ventana de
## reacción, un hechizo que falla (fizzle) no deja efectos a medias.
static func resolve_spell(s: Dictionary, spell: Dictionary, events: Array, action: Dictionary = {}) -> Dictionary:
	var card: Dictionary = spell["card"]
	var iid: int = card["iid"]
	var card_id: String = card["card_id"]
	var def: Dictionary = CardCatalog.get_def(card_id)
	var caster: String = spell["caster"]
	if bool(spell.get("cancelled", false)):
		Modifiers.expire(s, Types.EXPIRES_SPELL, "", iid)
		if not Types.all_card_iids(s).has(iid):
			Deck.to_discard(s, card)
		events.append(Types.make_log_entry(Types.LOG_SPELL_CANCELLED, Damage.turn_no(s), caster,
			{"iid": iid, "card_id": card_id}))
		return {"state": s, "error": Types.ERR_NONE}
	var snapshot: Dictionary = s.duplicate(true)
	var n_events: int = events.size()
	if String(def.get("type", "")) == Types.CARD_TYPE_ARTIFACT:
		var cp: Dictionary = Types.get_player(s, caster)
		(cp["artifacts"] as Array).append(Types.make_table_card(iid, card_id, caster))
	var ctx: Dictionary = Types.make_effect_ctx(card, def, caster, spell["targets"] as Array, spell["extra"] as Dictionary)
	ctx["target_card"] = int(spell["target_card"])
	ctx["payment"] = ((spell["data"] as Dictionary).get("payment", []) as Array).duplicate()
	ctx["spell"] = spell
	ctx["is_response"] = bool(spell["is_response"])
	ctx["action"] = action
	ctx["events"] = events
	var fn: Callable = EffectRegistry.get_effect(card_id)
	if fn.is_valid():
		_call(fn, s, ctx)
	if String(ctx["error"]) != Types.ERR_NONE:
		s.clear()
		s.merge(snapshot)
		events.resize(n_events)
		DefensiveEffects.drain_side_events()
		return {"state": s, "error": String(ctx["error"])}
	Modifiers.expire(s, Types.EXPIRES_SPELL, "", iid)
	if not Types.all_card_iids(s).has(iid):
		Deck.to_discard(s, card)
	events.append(Types.make_log_entry(Types.LOG_SPELL_RESOLVED, Damage.turn_no(s), caster,
		{"iid": iid, "card_id": card_id, "targets": (spell["targets"] as Array).duplicate()}))
	return {"state": s, "error": Types.ERR_NONE}


# =============================================================================
# Descartar, intercambiar
# =============================================================================

static func _discard(s: Dictionary, a: Dictionary, events: Array) -> String:
	var pid: String = a["player"]
	var p: Dictionary = Types.get_player(s, pid)
	var cards: Array = a["cards"]
	if cards.is_empty():
		return Types.ERR_NOTHING_TO_DISCARD
	var err: String = _check_hand_ids(p, cards)
	if err != Types.ERR_NONE:
		return err
	var ids: Array = []
	var cids: Array = []
	for x: Variant in cards:
		var c: Dictionary = Deck.take_from_hand(p, int(x))
		Deck.to_discard(s, c)
		ids.append(int(x))
		cids.append(String(c["card_id"]))
	events.append(Types.make_log_entry(Types.LOG_CARD_DISCARDED, Damage.turn_no(s), pid,
		{"cards": ids, "card_ids": cids}))
	return Types.ERR_NONE


## "" si `cards` son iids int distintos de la mano de p.
static func _check_hand_ids(p: Dictionary, cards: Array) -> String:
	var seen: Array = []
	for x: Variant in cards:
		if not (x is int) or seen.has(x):
			return Types.ERR_INVALID_ACTION
		seen.append(x)
		if Deck.hand_index(p, int(x)) < 0:
			return Types.ERR_CARD_NOT_IN_HAND
	return Types.ERR_NONE


static func _exchange(s: Dictionary, a: Dictionary, events: Array) -> String:
	var pid: String = a["player"]
	var p: Dictionary = Types.get_player(s, pid)
	var iid: int = a["card"]
	if Deck.hand_index(p, iid) < 0:
		return Types.ERR_CARD_NOT_IN_HAND
	if int(p["mana"]) < Damage.exchange_cost(s, pid, false):
		return Types.ERR_INSUFFICIENT_MANA
	var c: Dictionary = Deck.take_from_hand(p, iid)
	Deck.to_discard(s, c)
	var cost: int = Damage.exchange_cost(s, pid, true)
	Damage.pay_mana(s, pid, cost)
	var turn: Dictionary = s["turn"]
	turn["exchanges"] = int(turn["exchanges"]) + 1
	events.append(Types.make_log_entry(Types.LOG_EXCHANGE, Damage.turn_no(s), pid,
		{"iid": iid, "card_id": String(c["card_id"]), "cost": cost, "n": int(turn["exchanges"])}))
	draw_one(s, pid, events)
	return Types.ERR_NONE


# =============================================================================
# Pociones y prompts
# =============================================================================

## Kinds de prompt que se resuelven bebiendo una poción.
const DRINK_PROMPTS: Array[String] = [Types.PROMPT_MANA_SHORTFALL, Types.PROMPT_DRINK_OR_SUFFER]


static func _drink(s: Dictionary, a: Dictionary, events: Array) -> String:
	var pid: String = a["player"]
	var prompt_id: int = a["prompt_id"]
	var pr: Dictionary = {}
	if prompt_id >= 0:
		pr = find_prompt(s, prompt_id)
		if pr.is_empty():
			return Types.ERR_PROMPT_NOT_FOUND
		if String(pr["player"]) != pid:
			return Types.ERR_NOT_YOUR_DECISION
		if not DRINK_PROMPTS.has(String(pr["kind"])):
			return Types.ERR_INVALID_CHOICE
	else:
		for x: Variant in s["pending"]:
			var xd: Dictionary = x
			if String(xd["player"]) == pid and DRINK_PROMPTS.has(String(xd["kind"])):
				pr = xd
				break
	var res: Dictionary = Damage.drink_potion(s, pid, events)
	if pr.is_empty() or bool(res["eliminated"]):
		return Types.ERR_NONE
	var data: Dictionary = pr["data"]
	if String(pr["kind"]) == Types.PROMPT_MANA_SHORTFALL:
		var missing: int = Damage.pay_shortfall(s, pid, int(data["missing"]))
		if missing <= 0:
			remove_prompt(s, int(pr["id"]))
		else:
			data["missing"] = missing
	else:
		remove_prompt(s, int(pr["id"]))
		events.append(Types.make_log_entry(Types.LOG_EFFECT, Damage.turn_no(s), pid,
			{"card_id": String(pr["source"]), "what": "drank_to_avoid"}))
	return Types.ERR_NONE


static func find_prompt(s: Dictionary, prompt_id: int) -> Dictionary:
	for x: Variant in s["pending"]:
		var xd: Dictionary = x
		if int(xd["id"]) == prompt_id:
			return xd
	return {}


static func remove_prompt(s: Dictionary, prompt_id: int) -> void:
	var pending: Array = s["pending"]
	for i: int in pending.size():
		if int((pending[i] as Dictionary)["id"]) == prompt_id:
			pending.remove_at(i)
			return


static func _answer_prompt(s: Dictionary, a: Dictionary, events: Array) -> String:
	var pid: String = a["player"]
	var t: String = a["type"]
	var pr: Dictionary = find_prompt(s, int(a["prompt_id"]))
	if pr.is_empty():
		return Types.ERR_PROMPT_NOT_FOUND
	if String(pr["player"]) != pid:
		return Types.ERR_NOT_YOUR_DECISION
	var data: Dictionary = pr["data"]
	var pr_id: int = pr["id"]
	match String(pr["kind"]):
		Types.PROMPT_MANA_SHORTFALL:
			if t != Types.ACTION_DECLINE:
				return Types.ERR_INVALID_CHOICE
			remove_prompt(s, pr_id)
			Damage.lose_hp(s, pid, int(data["missing"]), events, "", String(pr["source"]), true,
				Types.ELIM_CAUSE_MANA_SHORTFALL)
			return Types.ERR_NONE
		Types.PROMPT_DRINK_OR_SUFFER:
			if t != Types.ACTION_DECLINE:
				return Types.ERR_INVALID_CHOICE
			remove_prompt(s, pr_id)
			Damage.apply(s, Types.make_mod_event(Damage.KIND_DAMAGE, int(data.get("hp", 0)), "", pid,
				Types.ELEMENT_NONE, String(pr["source"])), events)
			return Types.ERR_NONE
		Types.PROMPT_DISCARD:
			if t != Types.ACTION_CHOOSE_CARDS:
				return Types.ERR_INVALID_CHOICE
			var cards: Array = a["cards"]
			var p: Dictionary = Types.get_player(s, pid)
			var count: int = data["count"]
			var must: int = mini(count, (p["hand"] as Array).size())
			if cards.size() != must or _check_hand_ids(p, cards) != Types.ERR_NONE:
				return Types.ERR_INVALID_CHOICE
			var cids: Array = []
			for x: Variant in cards:
				var c: Dictionary = Deck.take_from_hand(p, int(x))
				Deck.to_discard(s, c)
				cids.append(String(c["card_id"]))
			remove_prompt(s, pr_id)
			events.append(Types.make_log_entry(Types.LOG_CARD_DISCARDED, Damage.turn_no(s), pid,
				{"cards": cards.duplicate(), "card_ids": cids, "forced": true, "card_id": String(pr["source"])}))
			if count > must:
				Damage.lose_mana(s, pid, count - must, events, "", String(pr["source"]))
			return Types.ERR_NONE
	if t == Types.ACTION_DECLINE and not bool(pr["optional"]):
		return Types.ERR_INVALID_CHOICE
	var fn: Callable = EffectRegistry.get_hook(HOOK_PROMPT, String(pr["source"]))
	if not fn.is_valid():
		if t == Types.ACTION_DECLINE:
			remove_prompt(s, pr_id)
			return Types.ERR_NONE
		return Types.ERR_NOT_IMPLEMENTED
	var err: String = _run_prompt_hook(fn, s, pr, a, events)
	if err == Types.ERR_NONE:
		remove_prompt(s, pr_id)
	return err


static func _run_prompt_hook(fn: Callable, s: Dictionary, pr: Dictionary, a: Dictionary, events: Array) -> String:
	var src: String = pr["source"]
	var ctx: Dictionary = Types.make_effect_ctx({}, CardCatalog.get_def(src), String(a["player"]),
		(a.get("targets", []) as Array), {"prompt": pr.duplicate(true)})
	ctx["action"] = a
	ctx["events"] = events
	_call(fn, s, ctx)
	return ctx["error"]


# =============================================================================
# Artefactos, evento activo, Curse of Rules
# =============================================================================

static func _use_artifact(s: Dictionary, a: Dictionary, events: Array) -> String:
	var pid: String = a["player"]
	var p: Dictionary = Types.get_player(s, pid)
	var tc: Dictionary = _own_artifact(p, int(a["card"]))
	if tc.is_empty():
		return Types.ERR_CARD_NOT_IN_PLAY
	var fn: Callable = EffectRegistry.get_hook(Types.HOOK_USE, String(tc["card_id"]))
	if not fn.is_valid():
		return Types.ERR_NO_EFFECT
	return _run_use_hook(fn, s, tc, a, events)


static func _use_event(s: Dictionary, a: Dictionary, events: Array) -> String:
	var ev: Dictionary = s["active_event"]
	if ev.is_empty():
		return Types.ERR_CARD_NOT_IN_PLAY
	var fn: Callable = EffectRegistry.get_hook(Types.HOOK_USE_EVENT, String(ev["card_id"]))
	if not fn.is_valid():
		return Types.ERR_NO_EFFECT
	return _run_use_hook(fn, s, ev, a, events)


## USE_ARTIFACT / USE_EVENT. Si prompt_id >= 0 debe ser un prompt de quien
## actúa; tras un hook sin error se retira (si el hook no lo hizo ya).
static func _run_use_hook(fn: Callable, s: Dictionary, tc: Dictionary, a: Dictionary, events: Array) -> String:
	var pid: String = a["player"]
	var prompt_id: int = a["prompt_id"]
	var pr: Dictionary = {}
	if prompt_id >= 0:
		pr = find_prompt(s, prompt_id)
		if pr.is_empty():
			return Types.ERR_PROMPT_NOT_FOUND
		if String(pr["player"]) != pid:
			return Types.ERR_NOT_YOUR_DECISION
	var ctx: Dictionary = _ctx(s, tc, pid, events)
	ctx["targets"] = (a.get("targets", []) as Array).duplicate()
	ctx["extra"] = (a.get("extra", {}) as Dictionary).duplicate(true)
	if not pr.is_empty():
		(ctx["extra"] as Dictionary)["prompt"] = pr.duplicate(true)
	ctx["payment"] = (a.get("cards", []) as Array).duplicate()
	ctx["action"] = a
	_call(fn, s, ctx)
	if String(ctx["error"]) != Types.ERR_NONE:
		return ctx["error"]
	if prompt_id >= 0:
		remove_prompt(s, prompt_id)
	return Types.ERR_NONE


## BREAK_RULE: quien denuncia (player) acusa a target de romper la Curse of
## Rules `curse` (en mesa). El acusado pierde 1 maná (decisión 7).
static func _break_rule(s: Dictionary, a: Dictionary, events: Array) -> String:
	var found: Dictionary = Deck.find_in_play(s, int(a["curse"]))
	if found.is_empty() or String((found["card"] as Dictionary)["card_id"]) != Types.CARD_CURSE_OF_RULES:
		return Types.ERR_CARD_NOT_IN_PLAY
	var target: String = a["target"]
	if not Types.alive_ids(s).has(target):
		return Types.ERR_INVALID_TARGET
	events.append(Types.make_log_entry(Types.LOG_RULE_BROKEN, Damage.turn_no(s), String(a["player"]),
		{"target": target, "curse": int(a["curse"])}))
	Damage.lose_mana(s, target, 1, events, String(a["player"]), Types.CARD_CURSE_OF_RULES)
	return Types.ERR_NONE


# =============================================================================
# Acciones legales
# =============================================================================

## Acciones legales para pid (para UI y bots). Enumera las de T4 y amplía con
## Reactions.legal_actions y HOOK_LEGAL_ACTIONS.
static func legal_actions(state: Dictionary, player_id: String) -> Array:
	var out: Array = []
	if String(state.get("status", "")) != Types.STATUS_PLAYING:
		return out
	var p: Dictionary = Types.get_player(state, player_id)
	if p.is_empty() or bool(p["eliminated"]):
		return out
	out.append(Types.make_action_drink_potion(player_id))
	var hook_cards: Array = []
	for x: Variant in state["pending"]:
		var pr: Dictionary = x
		if String(pr["player"]) == player_id:
			_prompt_actions(state, p, pr, out)
			hook_cards.append({"iid": -1, "card_id": String(pr["source"]), "owner": "", "data": {"prompt": pr}})
	if not (state["reaction"] as Dictionary).is_empty() and REACTIONS_SCRIPT.has_method("legal_actions"):
		var extra: Array = REACTIONS_SCRIPT.call("legal_actions", state, player_id)
		out.append_array(extra)
	if in_turn_error(state, player_id) == Types.ERR_NONE:
		_turn_actions(state, p, out)
	for c: Variant in state["players"]:
		var pd: Dictionary = c
		for cc: Variant in pd["curses"]:
			_break_rule_actions(state, player_id, cc as Dictionary, out)
		for cc: Variant in pd["artifacts"]:
			_break_rule_actions(state, player_id, cc as Dictionary, out)
	hook_cards.append_array(p["artifacts"] as Array)
	if not (state["active_event"] as Dictionary).is_empty():
		hook_cards.append(state["active_event"])
	for c: Variant in hook_cards:
		var tc: Dictionary = c
		var fn: Callable = EffectRegistry.get_hook(HOOK_LEGAL_ACTIONS, String(tc["card_id"]))
		if fn.is_valid():
			var ctx: Dictionary = Types.make_effect_ctx(tc, CardCatalog.get_def(String(tc["card_id"])), player_id)
			ctx["actions"] = out
			fn.call(state, ctx)
	out.append(Types.make_action_concede(player_id))
	return out


static func _turn_actions(state: Dictionary, p: Dictionary, out: Array) -> void:
	var pid: String = p["id"]
	out.append(Types.make_action_end_turn(pid))
	var hand_ids: Array = []
	for c: Variant in p["hand"]:
		hand_ids.append(int((c as Dictionary)["iid"]))
	if hand_ids.size() <= MAX_SUBSET_HAND:
		for k: int in range(1, hand_ids.size() + 1):
			for combo: Variant in combinations(hand_ids, k):
				out.append(Types.make_action_discard(pid, combo as Array))
	elif not hand_ids.is_empty():
		for iid: Variant in hand_ids:
			out.append(Types.make_action_discard(pid, [iid]))
		out.append(Types.make_action_discard(pid, hand_ids))
	if int(p["mana"]) >= Damage.exchange_cost(state, pid, false):
		for iid: Variant in hand_ids:
			out.append(Types.make_action_exchange(pid, int(iid)))
	for c: Variant in p["hand"]:
		_play_actions(state, p, c as Dictionary, out)


static func _play_actions(state: Dictionary, p: Dictionary, card: Dictionary, out: Array) -> void:
	var pid: String = p["id"]
	var def: Dictionary = CardCatalog.get_def(String(card["card_id"]))
	if def.is_empty():
		return
	var ctype: String = def.get("type", "")
	if ctype == Types.CARD_TYPE_EVENT or ctype == Types.CARD_TYPE_NON_PLAYABLE or ctype == Types.CARD_TYPE_DEFENSIVE \
			or not EffectRegistry.has_effect(String(card["card_id"])):
		return
	var alive: Array[String] = Types.alive_ids(state)
	var target_sets: Array = []
	var target_cards: Array = [-1]
	match String(def.get("target", Types.TARGET_NONE)):
		Types.TARGET_SINGLE:
			for t: String in alive:
				target_sets.append([t])
		Types.TARGET_OTHER:
			for t: String in alive:
				if t != pid:
					target_sets.append([t])
		Types.TARGET_TWO:
			for combo: Variant in combinations(Array(alive), 2):
				target_sets.append(combo)
		Types.TARGET_CARD_IN_PLAY:
			target_sets.append([])
			target_cards = _in_play_iids(state)
		_:
			target_sets.append([])
	var n_req: int = 0
	for r: Variant in (def.get("cost", {}) as Dictionary).get("cards", []):
		n_req += int((r as Dictionary).get("count", 1))
	var pay_sets: Array = [[]]
	if n_req > 0:
		var pool_ids: Array = []
		for c: Variant in p["hand"]:
			var ci: int = (c as Dictionary)["iid"]
			if ci != int(card["iid"]):
				pool_ids.append(ci)
		for c: Variant in p["artifacts"]:
			var tc: Dictionary = c
			if EffectRegistry.get_hook(HOOK_PAY_WILDCARD, String(tc["card_id"])).is_valid():
				pool_ids.append(int(tc["iid"]))
		pay_sets = combinations(pool_ids, n_req)
	for tcard: Variant in target_cards:
		for ts: Variant in target_sets:
			for ps: Variant in pay_sets:
				var a: Dictionary = Types.make_action_play_card(pid, int(card["iid"]), ts as Array, ps as Array, {}, int(tcard))
				if String(check_play(state, pid, card, def, a)["error"]) == Types.ERR_NONE:
					out.append(a)


static func _in_play_iids(state: Dictionary) -> Array:
	var out: Array = []
	for p: Variant in state["players"]:
		var pd: Dictionary = p
		for zone: String in ["artifacts", "curses"]:
			for c: Variant in pd[zone]:
				out.append(int((c as Dictionary)["iid"]))
	var ev: Dictionary = state["active_event"]
	if not ev.is_empty():
		out.append(int(ev["iid"]))
	return out


static func _break_rule_actions(state: Dictionary, pid: String, tc: Dictionary, out: Array) -> void:
	if String(tc["card_id"]) != Types.CARD_CURSE_OF_RULES:
		return
	for t: String in Types.alive_ids(state):
		if t != pid:
			out.append(Types.make_action_break_rule(pid, t, int(tc["iid"])))


static func _prompt_actions(_state: Dictionary, p: Dictionary, pr: Dictionary, out: Array) -> void:
	var pid: String = p["id"]
	var pr_id: int = pr["id"]
	var data: Dictionary = pr["data"]
	var declined: bool = false
	match String(pr["kind"]):
		Types.PROMPT_MANA_SHORTFALL, Types.PROMPT_DRINK_OR_SUFFER:
			out.append(Types.make_action_drink_potion(pid, pr_id))
			out.append(Types.make_action_decline(pid, pr_id))
			declined = true
		Types.PROMPT_DISCARD:
			var ids: Array = []
			for c: Variant in p["hand"]:
				ids.append(int((c as Dictionary)["iid"]))
			for combo: Variant in combinations(ids, mini(int(data.get("count", 1)), ids.size())):
				out.append(Types.make_action_choose_cards(pid, pr_id, combo as Array))
		Types.PROMPT_CHOOSE_TARGETS:
			for combo: Variant in combinations(data.get("allowed", []) as Array, int(data.get("count", 1))):
				out.append(Types.make_action_choose_targets(pid, pr_id, combo as Array))
		Types.PROMPT_CHOOSE_CARD:
			for combo: Variant in combinations(data.get("cards", []) as Array, int(data.get("count", 1))):
				out.append(Types.make_action_choose_cards(pid, pr_id, combo as Array))
		Types.PROMPT_MANA_FOCUS:
			var top: int = mini(int(data.get("damage", 0)), int(p["mana"]))
			for k: int in range(0, top + 1):
				out.append(Types.make_action_use_event(pid, {"mana": k}, pr_id))
	if bool(pr["optional"]) and not declined:
		out.append(Types.make_action_decline(pid, pr_id))


## Combinaciones (sin orden) de k elementos de items, en orden de aparición.
static func combinations(items: Array, k: int) -> Array:
	var out: Array = []
	if k < 0 or k > items.size():
		return out
	if k == 0:
		out.append([])
		return out
	_comb(items, k, 0, [], out)
	return out


static func _comb(items: Array, k: int, start: int, cur: Array, out: Array) -> void:
	if cur.size() == k:
		out.append(cur.duplicate())
		return
	for i: int in range(start, items.size()):
		cur.append(items[i])
		_comb(items, k, i + 1, cur, out)
		cur.pop_back()


# =============================================================================
# Utilidades internas
# =============================================================================

## Contexto de efecto para una carta (instancia o carta en mesa) y un actor.
static func _ctx(_s: Dictionary, card: Dictionary, actor: String, events: Array) -> Dictionary:
	var ctx: Dictionary = Types.make_effect_ctx(card, CardCatalog.get_def(String(card.get("card_id", ""))), actor)
	ctx["events"] = events
	return ctx


## Llama a un efecto/hook (state, ctx) -> Dictionary y adopta el estado que
## devuelva (si es otro objeto) sin perder la referencia de `s`.
static func _call(fn: Callable, s: Dictionary, ctx: Dictionary) -> void:
	var ret: Variant = fn.call(s, ctx)
	_adopt(s, ret)


static func _adopt(s: Dictionary, ret: Variant) -> void:
	if ret is Dictionary and not is_same(ret, s):
		var d: Dictionary = ret
		if d.is_empty():
			return
		var copy: Dictionary = d.duplicate()
		s.clear()
		s.merge(copy)


static func _append_log(s: Dictionary, events: Array) -> void:
	var entries: Array = s["log"]
	for e: Variant in events:
		entries.append((e as Dictionary).duplicate(true))
	Types.stamp_log_seq(entries)
	var limit: int = int((s["config"] as Dictionary)["log_limit"])
	if entries.size() > limit:
		s["log"] = entries.slice(entries.size() - limit)

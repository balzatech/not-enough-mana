class_name LocalSession
extends GameSession
## Sesión local (T8): hot-seat + bots en el propio dispositivo.
##
## - Guarda el estado completo y aplica Game.reduce(). La UI solo ve vistas
##   (Types.view_for) a través de get_view_for().
## - Bots: una sola decisión en curso a la vez. Cuando algún bot tiene algo que
##   decidir (Bot.has_decision) se arma un Timer cancelable (600-900 ms por
##   defecto); al vencer, el bot elige UNA acción, se aplica y se vuelve a
##   programar. Nunca hay recursión: las acciones que llegan mientras se aplica
##   otra (p. ej. desde un manejador de state_changed) se encolan y se procesan
##   en un bucle iterativo.
## - Si un bot devuelve {} o una acción ilegal, se usa una acción segura
##   (pasar, rechazar, primera elección válida, terminar turno). Si tampoco hay
##   ninguna, el bot abandona (evita bloquear la partida). Además hay un tope de
##   acciones de bot por turno (anti-bucle).
## - Temporizador de reacción opcional (config.reaction_timeout_local_ms > 0):
##   solo para humanos. Cuando decide un humano en la ventana se fija
##   reaction.deadline_ms (Reactions.set_deadline) y, al vencer, se envía la
##   primera acción de Reactions.timeout_actions() (el PASS_REACTION de quien
##   está decidiendo). Si el siguiente en decidir es otro humano, recibe un
##   plazo nuevo; los bots responden solos.
## - Auto-pase (reaction_notify == "affecting"): en _apply, antes de emitir, se
##   pasa en nombre de los humanos locales a los que el hechizo no afecta
##   (history.by = "auto_pass"); la mesa no ve el estado intermedio ni se
##   arranca plazo para ellos. Con "all" (defecto) no cambia nada.
##
## Uso:
##   var s: LocalSession = LocalSession.create(setup)   # setup de LocalSetup
##   table.bind_session(s)                               # la mesa la mete en el árbol
## Tests: auto_run_bots = false y run_bots(n) / step_bot() para avanzar sin
## temporizadores; clock = Callable que devuelve ms para el plazo de reacción.

## Retraso por defecto de cada acción de bot (ms).
const BOT_DELAY_MIN_MS: int = 600
const BOT_DELAY_MAX_MS: int = 900
## Tope de acciones de bot dentro de un mismo turno (anti-bucle).
const MAX_BOT_ACTIONS_PER_TURN: int = 120
## Tope de acciones procesadas en un solo submit (cola).
const MAX_QUEUE_STEPS: int = 64

var state: Dictionary = {}
var setup: Dictionary = {}
var bot_delay_min_ms: int = BOT_DELAY_MIN_MS
var bot_delay_max_ms: int = BOT_DELAY_MAX_MS
## Ruido del bot (0 = determinista). Ver Bot.choose_action.
var bot_randomness: int = 15
## Si false, los bots solo actúan con step_bot()/run_bots() (tests).
var auto_run_bots: bool = true
## Reloj en ms (unix). Callable() => Time.get_unix_time_from_system().
var clock: Callable = Callable()
## Acciones aplicadas (para depuración y tests): {action, error, by}.
var history: Array[Dictionary] = []

var _local_ids: Array[String] = []
var _bot_ids: Array[String] = []
var _bot_rng: int = 1
var _delay_rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _bot_timer: Timer = null
var _reaction_timer: Timer = null
var _queue: Array[Dictionary] = []
## Llamadas a Game.reduce hechas por esta sesión (tests de rendimiento/regresión).
var reduce_calls: int = 0
## Si true (defecto), el reduce que valida la acción del bot se reutiliza en _apply
## en vez de repetirlo. false = flujo antiguo (dos reduce), solo para comparar en tests.
var reuse_bot_reduce: bool = true
## Resultado de Game.reduce de la acción de bot recién validada: {state, action, result}.
## Solo vale si el estado y la acción siguen siendo exactamente los mismos objetos.
var _validated: Dictionary = {}
var _applying: bool = false
var _bot_turn_key: int = -1
var _bot_turn_count: int = 0
var _deadline_owner: String = ""
var _seen_prompts: Dictionary = {}
var _reaction_key: String = ""
var _over_emitted: bool = false
## Preferencia de aviso de reacciones: "all" (avisa siempre) o "affecting"
## (auto-pasa si el hechizo no afecta al humano local). Ver ReactionRelevance.
var reaction_notify: String = ReactionRelevance.MODE_ALL
## Último log_seq ya emitido en state_changed (bus de presentación).
var _last_log_seq: int = 0


## Crea una sesión desde la salida de LocalSetup:
## {players: [{name, age, birth_month, is_bot}], config: {...}}.
## seed_value < 0 => semilla aleatoria. setup.seed (int) también la fija.
static func create(p_setup: Dictionary, seed_value: int = -1) -> LocalSession:
	var s: LocalSession = LocalSession.new()
	s.setup = p_setup.duplicate(true)
	var players: Array = []
	var plist: Array = p_setup.get("players", []) as Array
	for i: int in plist.size():
		var pd: Dictionary = plist[i]
		var pid: String = "p%d" % (i + 1)
		var nm: String = String(pd.get("name", "")).strip_edges()
		if nm == "":
			nm = "Mago %d" % (i + 1)
		players.append(Types.make_player(pid, nm, int(pd.get("age", 30)), int(pd.get("birth_month", 1)),
			bool(pd.get("is_bot", false))))
	var cfg: Dictionary = (p_setup.get("config", {}) as Dictionary).duplicate(true)
	cfg["mode"] = "local"
	var sd: int = seed_value
	if sd < 0:
		sd = int(p_setup.get("seed", -1))
	if sd < 0:
		sd = randi()
	s.start(Game.new_game(players, cfg, sd), sd)
	return s


## Fábrica para UiNav.session_factory.
static func from_setup(p_setup: Dictionary) -> GameSession:
	return create(p_setup)


## Arranca (o reinicia) la sesión con un estado ya creado.
func start(p_state: Dictionary, seed_value: int = 1) -> void:
	state = p_state
	_bot_rng = Rng.seed_from(seed_value * 7919 + 17)
	_delay_rng.seed = seed_value
	_local_ids.clear()
	_bot_ids.clear()
	for p: Variant in state.get("players", []) as Array:
		var pd: Dictionary = p
		if bool(pd.get("is_bot", false)):
			_bot_ids.append(String(pd["id"]))
		else:
			_local_ids.append(String(pd["id"]))
	if not _local_ids.is_empty() and bot_randomness <= 0:
		bot_randomness = 15  # con humanos en la mesa el bot nunca es determinista
	_seen_prompts.clear()
	_reaction_key = ""
	_over_emitted = false
	_last_log_seq = Types.last_log_seq(state.get("log", []) as Array)
	_ensure_timers()
	_after_change([])


func _ready() -> void:
	_ensure_timers()
	_schedule()


func _ensure_timers() -> void:
	if _bot_timer == null:
		_bot_timer = Timer.new()
		_bot_timer.one_shot = true
		_bot_timer.name = "BotTimer"
		_bot_timer.timeout.connect(_on_bot_timer)
		add_child(_bot_timer)
	if _reaction_timer == null:
		_reaction_timer = Timer.new()
		_reaction_timer.one_shot = true
		_reaction_timer.name = "ReactionTimer"
		_reaction_timer.timeout.connect(_on_reaction_timer)
		add_child(_reaction_timer)


# ---------------------------------------------------------------- GameSession

func submit_action(action: Dictionary) -> void:
	_enqueue(action, "human")


func get_view_for(player_id: String) -> Dictionary:
	if state.is_empty():
		return {}
	return Types.view_for(state, player_id)


func get_local_player_ids() -> Array[String]:
	return _local_ids.duplicate()


func get_rev() -> int:
	return int(state.get("rev", 0))


func is_authority() -> bool:
	return true


# ---------------------------------------------------------------- consultas

func get_setup() -> Dictionary:
	return setup.duplicate(true)


func bot_ids() -> Array[String]:
	return _bot_ids.duplicate()


func is_bot(pid: String) -> bool:
	return _bot_ids.has(pid)


## ¿Hay una acción de bot programada (temporizador corriendo)?
func bot_pending() -> bool:
	return _bot_timer != null and not _bot_timer.is_stopped()


func now_ms() -> int:
	if clock.is_valid():
		return int(clock.call())
	return int(Time.get_unix_time_from_system() * 1000.0)


## Próximo bot que debe decidir ("" si ninguno). Primero el que marca el orden
## de la partida (Decision.decider) y si no, cualquier bot con decisión.
func next_bot() -> String:
	if String(state.get("status", "")) != Types.STATUS_PLAYING:
		return ""
	var d: String = Decision.decider(state)
	if _bot_ids.has(d) and Bot.has_decision(state, d):
		return d
	for pid: String in _bot_ids:
		if Bot.has_decision(state, pid):
			return pid
	return ""


# ---------------------------------------------------------------- aplicar

func _enqueue(action: Dictionary, by: String) -> void:
	_queue.append({"action": action, "by": by})
	if _applying:
		return
	_applying = true
	var guard: int = 0
	while not _queue.is_empty() and guard < MAX_QUEUE_STEPS:
		guard += 1
		var item: Dictionary = _queue.pop_front()
		_apply(item["action"] as Dictionary, String(item["by"]))
	_queue.clear()
	_applying = false
	_schedule()


## Aplica una acción. Devuelve el código de error ("" si se aplicó).
func _apply(action: Dictionary, by: String) -> String:
	if state.is_empty():
		error.emit(Types.ERR_GAME_NOT_PLAYING, action)
		return Types.ERR_GAME_NOT_PLAYING
	var r: Dictionary = _take_validated(action)
	if r.is_empty():
		r = _reduce(state, action)
	var err: String = String(r.get("error", ""))
	history.append({"action": action.duplicate(true), "error": err, "by": by})
	if history.size() > 400:
		history = history.slice(history.size() - 400)
	if err != Types.ERR_NONE:
		if by == "human":
			error.emit(err, action)
		return err
	state = r["state"]
	_auto_pass_loop()
	_after_change(r.get("events", []) as Array)
	return Types.ERR_NONE


## Game.reduce con contador de llamadas.
func _reduce(s: Dictionary, a: Dictionary) -> Dictionary:
	reduce_calls += 1
	return Game.reduce(s, a)


## Devuelve (y consume) el resultado de reduce ya calculado al validar la acción de
## bot, o {} si no aplica (otra acción, el estado cambió, flujo antiguo). Game.reduce
## es puro (duplica el estado), así que el resultado es idéntico al de recalcularlo.
func _take_validated(action: Dictionary) -> Dictionary:
	if _validated.is_empty():
		return {}
	var v: Dictionary = _validated
	_validated = {}
	if is_same(v["state"], state) and is_same(v["action"], action):
		return v["result"] as Dictionary
	return {}


## Auto-pase (preferencia "Avisarme de reacciones"): mientras la ventana espere
## a un humano local al que no le afecta el hechizo, se aplica su PASS_REACTION
## (by = "auto_pass") sin emitir estados intermedios. Acotado.
func _auto_pass_loop() -> void:
	if reaction_notify != ReactionRelevance.MODE_AFFECTING or _local_ids.is_empty():
		return
	var cap: int = maxi(1, (state.get("players", []) as Array).size()) * 4
	for _i: int in cap:
		if String(state.get("status", "")) != Types.STATUS_PLAYING:
			return
		var a: Dictionary = ReactionRelevance.auto_pass_action(state, _local_ids, reaction_notify)
		if a.is_empty():
			return
		var r: Dictionary = _reduce(state, a)
		var err: String = String(r.get("error", ""))
		history.append({"action": a.duplicate(true), "error": err, "by": "auto_pass"})
		if err != Types.ERR_NONE:
			return
		state = r["state"]


## Tras cada cambio: plazo de reacción, señales y fin de partida.
func _after_change(_events: Array) -> void:
	_update_reaction_deadline()
	var shown: Array = _new_log_entries()
	state_changed.emit(get_rev(), shown)
	var re: Dictionary = state.get("reaction", {}) as Dictionary
	if re.is_empty():
		_reaction_key = ""
	else:
		var key: String = "%d:%d" % [int(((re["spell"] as Dictionary)["card"] as Dictionary)["iid"]),
			(re["stack"] as Array).size()]
		if key != _reaction_key:
			_reaction_key = key
			reaction_opened.emit((re as Dictionary).duplicate(true))
	for pr: Variant in state.get("pending", []) as Array:
		var prd: Dictionary = pr
		var pr_id: int = int(prd["id"])
		if _seen_prompts.has(pr_id):
			continue
		_seen_prompts[pr_id] = true
		if _local_ids.has(String(prd["player"])):
			prompt_opened.emit(prd.duplicate(true))
	if String(state.get("status", "")) == Types.STATUS_FINISHED and not _over_emitted:
		_over_emitted = true
		_stop_timers()
		game_over.emit((state.get("winners", []) as Array).duplicate())


## Entradas de state.log con log_seq nuevo, en orden y visibles para algún
## jugador local. Actualiza _last_log_seq (también con las filtradas).
func _new_log_entries() -> Array:
	var log_entries: Array = state.get("log", []) as Array
	var fresh: Array = []
	var i: int = log_entries.size() - 1
	while i >= 0:
		var ed: Dictionary = log_entries[i]
		if int(ed.get("log_seq", 0)) <= _last_log_seq:
			break
		fresh.append(ed)
		i -= 1
	fresh.reverse()
	var shown: Array = []
	for ed: Dictionary in fresh:
		_last_log_seq = maxi(_last_log_seq, int(ed["log_seq"]))
		var to: Array = ed.get("visible_to", []) as Array
		var visible: bool = to.is_empty()
		for pid: String in _local_ids:
			if to.has(pid):
				visible = true
				break
		if visible:
			shown.append(ed.duplicate(true))
	return shown


# ---------------------------------------------------------------- bots

func _schedule() -> void:
	if String(state.get("status", "")) != Types.STATUS_PLAYING:
		_stop_timers()
		return
	if not auto_run_bots or not is_inside_tree() or _bot_timer == null:
		return
	if not _bot_timer.is_stopped():
		return
	if next_bot() == "":
		return
	var lo: int = maxi(0, mini(bot_delay_min_ms, bot_delay_max_ms))
	var hi: int = maxi(lo, bot_delay_max_ms)
	var ms: int = _delay_rng.randi_range(lo, hi)
	if not _any_local_alive():
		ms = int(float(ms) / 3.0)  # solo quedan bots: la partida avanza más rápido
	_bot_timer.start(maxf(0.001, float(ms) / 1000.0))


func _any_local_alive() -> bool:
	for pid: String in _local_ids:
		var p: Dictionary = Types.get_player(state, pid)
		if not p.is_empty() and not bool(p["eliminated"]):
			return true
	return false


## Cancela la acción de bot programada (p. ej. al salir de la mesa).
func cancel_bot() -> void:
	if _bot_timer != null:
		_bot_timer.stop()


func _stop_timers() -> void:
	if _bot_timer != null:
		_bot_timer.stop()
	if _reaction_timer != null:
		_reaction_timer.stop()


func _on_bot_timer() -> void:
	step_bot()


## Hace que el próximo bot decida y aplica su acción (sin esperar). Devuelve
## true si se aplicó alguna acción.
func step_bot() -> bool:
	if _applying:
		return false
	var pid: String = next_bot()
	if pid == "":
		_schedule()
		return false
	var a: Dictionary = _bot_action(pid)
	if a.is_empty():
		_schedule()
		return false
	_enqueue(a, "bot")
	return true


## Ejecuta hasta max_steps acciones de bot seguidas (tests). Para cuando
## ningún bot tiene decisión. Devuelve cuántas se aplicaron.
func run_bots(max_steps: int = 200) -> int:
	var n: int = 0
	for _i: int in max_steps:
		if not step_bot():
			break
		n += 1
	return n


func _bot_action(pid: String) -> Dictionary:
	var turn_no: int = int((state["turn"] as Dictionary)["number"])
	if turn_no != _bot_turn_key:
		_bot_turn_key = turn_no
		_bot_turn_count = 0
	_bot_turn_count += 1
	var a: Dictionary = {}
	if _bot_turn_count <= MAX_BOT_ACTIONS_PER_TURN:
		var res: Dictionary = Bot.choose_action(state, pid, _bot_rng, bot_randomness)
		_bot_rng = int(res.get("rng_state", _bot_rng))
		a = res.get("action", {}) as Dictionary
	_validated = {}
	if not a.is_empty():
		var r: Dictionary = _reduce(state, a)
		if String(r["error"]) == Types.ERR_NONE:
			if reuse_bot_reduce:
				_validated = {"state": state, "action": a, "result": r}
			return a
	if not a.is_empty():
		push_warning("LocalSession: el bot %s propuso una acción ilegal %s" % [pid, JSON.stringify(a)])
	a = safe_action(state, pid)
	if a.is_empty():
		push_warning("LocalSession: el bot %s no tiene acción posible; abandona" % pid)
		a = Types.make_action_concede(pid)
	return a


## Acción "segura" para pid: pasar, rechazar, primera elección válida o
## terminar turno. {} si no hay ninguna aplicable.
static func safe_action(s: Dictionary, pid: String) -> Dictionary:
	var legal: Array = Game.legal_actions(s, pid)
	var order: Array[String] = [Types.ACTION_PASS_REACTION, Types.ACTION_DECLINE, Types.ACTION_CHOOSE_CARDS,
		Types.ACTION_CHOOSE_TARGETS, Types.ACTION_USE_EVENT, Types.ACTION_USE_ARTIFACT, Types.ACTION_END_TURN]
	for t: String in order:
		for x: Variant in legal:
			var a: Dictionary = x
			if String(a["type"]) != t:
				continue
			if String(Game.reduce(s, a)["error"]) == Types.ERR_NONE:
				return a
	# Prompts que solo se resuelven bebiendo (maná insuficiente sin DECLINE).
	for x: Variant in legal:
		var a: Dictionary = x
		if String(a["type"]) == Types.ACTION_DRINK_POTION and int(a["prompt_id"]) >= 0:
			if String(Game.reduce(s, a)["error"]) == Types.ERR_NONE:
				return a
	return {}


# ---------------------------------------------------------------- temporizador de reacción

func reaction_timeout_ms() -> int:
	return int((state.get("config", {}) as Dictionary).get("reaction_timeout_local_ms", 0))


func _update_reaction_deadline() -> void:
	var ms: int = reaction_timeout_ms()
	if ms <= 0 or String(state.get("status", "")) != Types.STATUS_PLAYING \
			or (state.get("reaction", {}) as Dictionary).is_empty():
		_deadline_owner = ""
		if _reaction_timer != null:
			_reaction_timer.stop()
		return
	var cur: String = Reactions.current_responder(state)
	if cur == "" or not _local_ids.has(cur):
		_deadline_owner = ""
		if _reaction_timer != null:
			_reaction_timer.stop()
		return
	var now: int = now_ms()
	if Reactions.needs_deadline(state) or cur != _deadline_owner:
		state = Reactions.set_deadline(state, now, ms)
		_deadline_owner = cur
	var left: int = int((state["reaction"] as Dictionary)["deadline_ms"]) - now
	if _reaction_timer != null and _reaction_timer.is_inside_tree():
		_reaction_timer.start(maxf(0.05, float(left) / 1000.0))


func _on_reaction_timer() -> void:
	if not check_timeouts():
		_update_reaction_deadline()


## Si el plazo de reacción venció, pasa en nombre de quien decide. Devuelve
## true si envió una acción.
func check_timeouts(now: int = -1) -> bool:
	if now < 0:
		now = now_ms()
	if String(state.get("status", "")) != Types.STATUS_PLAYING or not Reactions.is_expired(state, now):
		return false
	var acts: Array = Reactions.timeout_actions(state)
	if acts.is_empty():
		return false
	_enqueue(acts[0] as Dictionary, "timeout")
	return true

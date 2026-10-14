extends SceneTree
## V2-02: simulación bot contra bot con efectos reales y métricas base.
##   godot --headless --path . -s tools/sim.gd -- --games 200 --seed 1 [--players N] [--json salida.json]
## Reproducible por semilla (partida g usa la semilla seed+g). Bots con randomness 0.
## Invariantes tras cada acción: Types.validate_state; cualquier violación se
## reporta con su semilla. No usa log_seq ni el log del estado (usa los events).

const MAX_STEPS: int = 2000
const MAX_STEPS_PER_TURN: int = 80

var _games: int = 200
var _seed: int = 1
var _fixed_players: int = 0
var _json_path: String = ""
## V2-41: límite de pociones. -1 = el de la config por defecto (10); 0 = desactivado; N>0 = N.
var _potion_limit: int = -1
## V2-27: "" = sin medir. "affecting"/"all": p1 hace de humano local con la preferencia de
## reacciones y se mide cuántas ventanas le llegan (auto-pase como LocalSession._auto_pass_loop).
var _reaction_notify: String = ""


func _init() -> void:
	_parse_args()
	var rep: Dictionary = _run_all()
	_print(rep)
	if _json_path != "":
		var f: FileAccess = FileAccess.open(_json_path, FileAccess.WRITE)
		if f != null:
			f.store_string(JSON.stringify(rep, "  "))
			f.close()
		else:
			push_error("no se pudo escribir " + _json_path)
	var bad: int = (rep["violations"] as Array).size() + (rep["errors"] as Array).size()
	quit(1 if bad > 0 else 0)


func _parse_args() -> void:
	var a: PackedStringArray = OS.get_cmdline_user_args()
	var i: int = 0
	while i < a.size():
		var k: String = a[i]
		var v: String = a[i + 1] if i + 1 < a.size() else ""
		match k:
			"--games":
				_games = int(v)
				i += 1
			"--seed":
				_seed = int(v)
				i += 1
			"--players":
				_fixed_players = clampi(int(v), 2, 6)
				i += 1
			"--json":
				_json_path = v
				i += 1
			"--reaction-notify":
				_reaction_notify = v
				i += 1
			"--potion-limit":
				_potion_limit = 0 if v == "off" else maxi(1, int(v))
				i += 1
		i += 1


static func _inc(d: Dictionary, k: String, n: int = 1) -> void:
	d[k] = int(d.get(k, 0)) + n


func _run_all() -> Dictionary:
	EffectRegistry.reset()
	CardCatalog.load_json()
	var missing: Array = []
	for id: String in Types.PLAYABLE_CARD_IDS:
		if not EffectRegistry.has_effect(id):
			missing.append(id)
	var rep: Dictionary = {
		"games": _games, "seed": _seed, "players_fixed": _fixed_players,
		"effects_missing": missing, "violations": [], "errors": [],
		"finished": 0, "capped": 0, "total_steps": 0,
		"player_turns": [], "rounds": [], "actions_per_turn_sum": 0, "actions_per_turn_n": 0,
		"actions_by_type": {}, "events_drawn": {}, "plays_by_card": {}, "reacts_by_card": {},
		"wins_by_seat": {}, "games_by_players": {}, "wins_by_seat_players": {},
		"windows_total": 0, "windows_by_caster": {}, "windows_received": {},
		"reaction_reacts": 0, "reaction_passes": 0, "windows_per_game": [],
		"eot_mana_sum": 0, "eot_potions_sum": 0, "eot_n": 0,
		"elim_reasons": {}, "tmm": [], "winners_multi": 0,
		"potion_limit": ("default" if _potion_limit < 0 else ("off" if _potion_limit == 0 else str(_potion_limit))),
		"per_game": [],
		"rn_mode": _reaction_notify, "rn_human_windows": 0, "rn_human_modals": 0, "rn_human_auto": 0,
		"rn_human_per_game": [],
	}
	for g: int in _games:
		_one_game(g, rep)
	return rep


func _one_game(g: int, rep: Dictionary) -> void:
	var seed_value: int = _seed + g
	var n: int = _fixed_players if _fixed_players > 0 else 3 + g % 4
	var ages: Array = []
	var players: Array = []
	for i: int in n:
		ages.append(18 + (seed_value * 7 + i * 11) % 50)
		players.append(Types.make_player("p%d" % (i + 1), "P%d" % (i + 1), int(ages[i]), (i % 12) + 1))
	var gcfg: Dictionary = {"log_limit": 50}
	if _potion_limit == 0:
		gcfg["potion_limit_enabled"] = false
	elif _potion_limit > 0:
		gcfg["potion_limit"] = _potion_limit
	var s: Dictionary = Game.new_game(players, gcfg, seed_value)
	var rng: int = Rng.seed_from(seed_value * 31 + 7)
	_inc(rep["games_by_players"], str(n))
	var errs: Array[String] = Types.validate_state(s)
	if not errs.is_empty():
		(rep["violations"] as Array).append({"seed": seed_value, "step": -1, "errors": errs})
		return
	var total: int = int(s["card_total"])
	var last_turn: int = -1
	var in_turn: int = 0
	var turns: int = 0
	var rounds: int = 0
	var last_seat: int = 99
	var windows: int = 0
	var steps: int = 0
	var seat_of: Dictionary = {}
	for i: int in n:
		seat_of["p%d" % (i + 1)] = i
	var ok: bool = true
	# V2-41: métricas por ronda (cubo i = ronda i+1 de la cuenta `rounds`).
	var rd_plays: Array = [0]      # PLAY_CARD + REACT + USE_ARTIFACT
	var rd_cards: Array = [0]      # solo PLAY_CARD
	var rd_dmg: Array = [0]        # daño efectivo (dealt > 0)
	var rd_discards: Array = [0]
	var rd_mana_in: Array = [0]    # maná ganado por efectos (MANA_CHANGED con delta > 0)
	var rd_events: Dictionary = {} # ronda (str) -> ids de eventos robados
	var elims: Array = []
	var streak: int = 0
	var snapshot: Dictionary = {}
	var tot_heal: int = 0
	var tot_dmg: int = 0
	var g_acts: Dictionary = {}
	var rn_modals: int = 0
	while steps < MAX_STEPS and s["status"] == Types.STATUS_PLAYING:
		if _reaction_notify == ReactionRelevance.MODE_AFFECTING:
			var ap: Dictionary = ReactionRelevance.auto_pass_action(s, ["p1"] as Array[String], _reaction_notify)
			if not ap.is_empty():
				var apr: Dictionary = Game.reduce(s, ap)
				if String(apr["error"]) == "":
					s = apr["state"]
					rep["rn_human_auto"] = int(rep["rn_human_auto"]) + 1
					continue
		var actor: String = ""
		for pid: String in Types.alive_ids(s):
			if Bot.has_decision(s, pid):
				actor = pid
				break
		if actor == "":
			(rep["errors"] as Array).append({"seed": seed_value, "step": steps, "msg": "nadie puede decidir (bloqueo)"})
			ok = false
			break
		var res: Dictionary = Bot.choose_action(s, actor, rng, 0)
		rng = int(res["rng_state"])
		var a: Dictionary = res["action"]
		if a.is_empty():
			(rep["errors"] as Array).append({"seed": seed_value, "step": steps, "msg": "%s sin acción" % actor})
			ok = false
			break
		var pre: Dictionary = s
		if _reaction_notify != "" and actor == "p1" and not (s["reaction"] as Dictionary).is_empty() \
				and (String(a["type"]) == Types.ACTION_REACT or String(a["type"]) == Types.ACTION_PASS_REACTION):
			rn_modals += 1
		var r: Dictionary = Game.reduce(s, a)
		if String(r["error"]) != "":
			(rep["errors"] as Array).append({"seed": seed_value, "step": steps,
				"msg": "acción ilegal %s -> %s" % [JSON.stringify(a), r["error"]]})
			ok = false
			break
		s = r["state"]
		steps += 1
		var t: String = String(a["type"])
		_inc(rep["actions_by_type"], t)
		_inc(g_acts, t)
		var bi: int = maxi(rounds - 1, 0)
		if t == Types.ACTION_PLAY_CARD:
			rd_cards[bi] = int(rd_cards[bi]) + 1
		if t == Types.ACTION_PLAY_CARD or t == Types.ACTION_REACT or t == Types.ACTION_USE_ARTIFACT:
			rd_plays[bi] = int(rd_plays[bi]) + 1
		if t == Types.ACTION_DISCARD:
			rd_discards[bi] = int(rd_discards[bi]) + 1
		# Cartas jugadas / reaccionadas (por card_id, leído de los events).
		var events: Array = r["events"]
		for e: Variant in events:
			var ev: Dictionary = e
			var et: String = String(ev["type"])
			var d: Dictionary = ev["data"]
			if et == Types.LOG_CARD_PLAYED:
				_inc(rep["plays_by_card"], String(d.get("card_id", "?")))
			elif et == Types.LOG_EVENT_DRAWN:
				_inc(rep["events_drawn"], String(d.get("card_id", "?")))
				if not rd_events.has(str(rounds)):
					rd_events[str(rounds)] = []
				(rd_events[str(rounds)] as Array).append(String(d.get("card_id", "?")))
			elif et == Types.LOG_REACTED:
				_inc(rep["reacts_by_card"], String(d.get("card_id", "?")))
			elif et == Types.LOG_REACTION_OPENED:
				windows += 1
				_inc(rep["windows_by_caster"], String(ev["player"]))
				for w: Variant in (d.get("awaiting", []) as Array):
					_inc(rep["windows_received"], String(w))
					if String(w) == "p1" and _reaction_notify != "":
						rep["rn_human_windows"] = int(rep["rn_human_windows"]) + 1
			elif et == Types.LOG_DAMAGE:
				var dealt: int = int(d.get("dealt", 0))
				if dealt > 0:
					rd_dmg[bi] = int(rd_dmg[bi]) + 1
					tot_dmg += dealt
			elif et == Types.LOG_MANA_CHANGED:
				if int(d.get("delta", 0)) > 0:
					rd_mana_in[bi] = int(rd_mana_in[bi]) + int(d["delta"])
			elif et == Types.LOG_HEAL:
				tot_heal += int(d.get("amount", 0))
			elif et == Types.LOG_ELIMINATED:
				var reason: String = String((d as Dictionary).get("reason", "?"))
				elims.append({"round": rounds, "player": String(ev["player"]), "reason": reason})
				_inc(rep["elim_reasons"], reason)
				if reason == Types.ELIM_TOO_MUCH_MANA:
					(rep["tmm"] as Array).append(_tmm_record(pre, ev, a, seed_value, seat_of))
		if t == Types.ACTION_REACT:
			rep["reaction_reacts"] = int(rep["reaction_reacts"]) + 1
		elif t == Types.ACTION_PASS_REACTION:
			rep["reaction_passes"] = int(rep["reaction_passes"]) + 1
		# Invariantes.
		var verrs: Array[String] = Types.validate_state(s)
		var extra: Array[String] = _extra_invariants(s, total)
		verrs.append_array(extra)
		if not verrs.is_empty():
			(rep["violations"] as Array).append({"seed": seed_value, "step": steps, "action": a, "errors": verrs})
			ok = false
			break
		# Turnos y acciones por turno.
		var tn: int = int((s["turn"] as Dictionary)["number"])
		if tn != last_turn:
			last_turn = tn
			turns += 1
			in_turn = 0
			var cur: String = String((s["turn"] as Dictionary)["current"])
			var seat: int = int(seat_of.get(cur, 0))
			if seat <= last_seat:
				# Se cierra el cubo de la ronda anterior (si hubo una).
				if rounds >= 1:
					var cb: int = rounds - 1
					if int(rd_plays[cb]) == 0 and int(rd_dmg[cb]) == 0:
						streak += 1
					else:
						streak = 0
					if streak == 3 and snapshot.is_empty():
						snapshot = _snapshot(s, rounds, rng)
				rounds += 1
				rd_plays.append(0)
				rd_cards.append(0)
				rd_dmg.append(0)
				rd_discards.append(0)
				rd_mana_in.append(0)
			last_seat = seat
		in_turn += 1
		if t != Types.ACTION_PASS_REACTION and t != Types.ACTION_REACT:
			pass
		rep["actions_per_turn_sum"] = int(rep["actions_per_turn_sum"]) + 1
		if in_turn > MAX_STEPS_PER_TURN:
			(rep["errors"] as Array).append({"seed": seed_value, "step": steps, "msg": "bucle en el turno %d" % tn})
			ok = false
			break
		if t == Types.ACTION_END_TURN:
			var me: Dictionary = Types.get_player(s, String(a["player"]))
			if not me.is_empty():
				rep["eot_mana_sum"] = int(rep["eot_mana_sum"]) + int(me["mana"])
				rep["eot_potions_sum"] = int(rep["eot_potions_sum"]) + int(me["potions"])
				rep["eot_n"] = int(rep["eot_n"]) + 1
	rep["total_steps"] = int(rep["total_steps"]) + steps
	(rep["player_turns"] as Array).append(turns)
	(rep["rounds"] as Array).append(rounds)
	(rep["windows_per_game"] as Array).append(windows)
	rep["rn_human_modals"] = int(rep["rn_human_modals"]) + rn_modals
	(rep["rn_human_per_game"] as Array).append(rn_modals)
	(rep["per_game"] as Array).append(_game_record(g, seed_value, n, turns, rounds, s, rd_plays, rd_cards, rd_dmg, rd_discards, snapshot, tot_heal, tot_dmg, g_acts, steps, rd_mana_in, rd_events, elims))
	rep["actions_per_turn_n"] = int(rep["actions_per_turn_n"]) + turns
	if s["status"] == Types.STATUS_FINISHED:
		rep["finished"] = int(rep["finished"]) + 1
		var w: Array = s["winners"]
		if w.size() > 1:
			rep["winners_multi"] = int(rep["winners_multi"]) + 1
		for x: Variant in w:
			_inc(rep["wins_by_seat"], str(int(seat_of.get(String(x), 0)) + 1))
			_inc(rep["wins_by_seat_players"], "%d:%d" % [n, int(seat_of.get(String(x), 0)) + 1])
	elif ok:
		rep["capped"] = int(rep["capped"]) + 1


## Bloqueo (V2-41): >= 2 vivos y >= 3 rondas CERRADAS seguidas sin PLAY_CARD, REACT, USE_ARTIFACT
## ni daño efectivo. Devuelve {blocked_rounds, max_run, first_block_round, runs}. La ronda en curso
## al terminar la partida no se cuenta. "Vivos >= 2" se cumple siempre mientras status == playing.
static func block_stats(rd_plays: Array, rd_dmg: Array, closed: int) -> Dictionary:
	var blocked: int = 0
	var max_run: int = 0
	var first: int = 0
	var runs: int = 0
	var run: int = 0
	for i: int in range(closed + 1):
		var idle: bool = i < closed and int(rd_plays[i]) == 0 and int(rd_dmg[i]) == 0
		if idle:
			run += 1
			continue
		if run >= 3:
			blocked += run
			runs += 1
			if first == 0:
				first = i - run + 1
		max_run = maxi(max_run, run)
		run = 0
	return {"blocked_rounds": blocked, "max_run": max_run, "first_block_round": first, "runs": runs}


func _snapshot(s: Dictionary, round_no: int, rng: int) -> Dictionary:
	var cur: String = String((s["turn"] as Dictionary)["current"])
	var cfg: Dictionary = s["config"]
	var plist: Array = []
	for x: Variant in s["players"]:
		var pd: Dictionary = x
		if bool(pd["eliminated"]):
			continue
		var costs: Array = []
		var ids: Array = []
		for c: Variant in pd["hand"]:
			var def: Dictionary = CardCatalog.get_def(String((c as Dictionary)["card_id"]))
			ids.append(String((c as Dictionary)["card_id"]))
			costs.append(Damage.card_cost(s, String(pd["id"]), def, int((c as Dictionary)["iid"]), false))
		plist.append({"id": pd["id"], "hp": int(pd["hp"]), "mana": int(pd["mana"]), "potions": int(pd["potions"]),
			"hand": ids, "hand_costs": costs, "artifacts": (pd["artifacts"] as Array).size(), "curses": (pd["curses"] as Array).size()})
	var legal: Array = Game.legal_actions(s, cur)
	var by_type: Dictionary = {}
	var plays: Array = []
	for la: Variant in legal:
		var a: Dictionary = la
		_inc(by_type, String(a["type"]))
		if String(a["type"]) == Types.ACTION_PLAY_CARD:
			plays.append(JSON.stringify(a))
	var drink: Dictionary = {}
	var rd: Dictionary = Game.reduce(s, Types.make_action_drink_potion(cur))
	if String(rd["error"]) == "":
		var ns: Dictionary = rd["state"]
		var me0: Dictionary = Types.get_player(s, cur)
		var me1: Dictionary = Types.get_player(ns, cur)
		drink = {"eliminated": bool(me1["eliminated"]), "mana_gained": int(me1["mana"]) - int(me0["mana"])}
	var bot: Dictionary = Bot.choose_action(s, cur, rng, 0)
	return {"round": round_no, "turn": int((s["turn"] as Dictionary)["number"]), "current": cur, "players": plist,
		"pool": (s["pool"] as Dictionary).duplicate(), "potion_limit": ("off" if not bool(cfg["potion_limit_enabled"]) else str(int(cfg["potion_limit"]))),
		"legal_by_type": by_type, "legal_plays": plays, "drink_probe": drink,
		"bot_choice": String((bot["action"] as Dictionary).get("type", "")),
		"deck": (s["deck"] as Array).size(), "discard": (s["discard"] as Array).size()}


func _game_record(g: int, seed_value: int, n: int, turns: int, rounds: int, s: Dictionary, rd_plays: Array, rd_cards: Array,
		rd_dmg: Array, rd_discards: Array, snapshot: Dictionary, tot_heal: int, tot_dmg: int, acts: Dictionary, steps: int,
		rd_mana_in: Array, rd_events: Dictionary, elims: Array) -> Dictionary:
	var closed: int = maxi(rounds - 1, 0)
	var bs: Dictionary = block_stats(rd_plays, rd_dmg, closed)
	var alive: Array = []
	for x: Variant in s["players"]:
		var pd: Dictionary = x
		if not bool(pd["eliminated"]):
			alive.append({"id": pd["id"], "hp": int(pd["hp"]), "mana": int(pd["mana"]), "potions": int(pd["potions"]), "hand": (pd["hand"] as Array).size()})
	var tot_plays: int = 0
	for v: Variant in rd_cards:
		tot_plays += int(v)
	var cfg: Dictionary = s["config"]
	return {"g": g, "seed": seed_value, "players": n, "turns": turns, "rounds": rounds, "steps": steps, "status": String(s["status"]),
		"blocked_rounds": bs["blocked_rounds"], "max_idle_run": bs["max_run"], "first_block_round": bs["first_block_round"], "block_runs": bs["runs"],
		"cards_played": tot_plays, "damage_dealt": tot_dmg, "healed": tot_heal, "acts": acts,
		"cards_per_round": rd_cards, "plays_per_round": rd_plays, "damage_events_per_round": rd_dmg, "discards_per_round": rd_discards,
		"mana_gained_per_round": rd_mana_in, "events_by_round": rd_events, "eliminations": elims,
		"alive_end": alive, "pool_end": (s["pool"] as Dictionary).duplicate(),
		"potion_limit": ("off" if not bool(cfg["potion_limit_enabled"]) else str(int(cfg["potion_limit"]))),
		"block_snapshot": snapshot}


func _extra_invariants(s: Dictionary, total: int) -> Array[String]:
	var out: Array[String] = []
	for p: Variant in s["players"]:
		var pd: Dictionary = p
		var hp: int = int(pd["hp"])
		if hp < 0 or hp > 10:
			out.append("vida fuera de rango %s: %d" % [pd["id"], hp])
		if int(pd["mana"]) < 0:
			out.append("maná negativo %s" % pd["id"])
	# La conservación exacta de cartas la cubre validate_state.
	if int(s["card_total"]) != total:
		out.append("card_total cambió: %d -> %d" % [total, int(s["card_total"])])
	if total != 154:
		out.append("card_total != 154: %d" % total)
	return out


func _tmm_record(pre: Dictionary, ev: Dictionary, a: Dictionary, seed_value: int, _seat_of: Dictionary) -> Dictionary:
	var pid: String = String(ev["player"])
	var p: Dictionary = Types.get_player(pre, pid)
	var prompts: Array = []
	for x: Variant in (pre["pending"] as Array):
		var pr: Dictionary = x
		if String(pr["player"]) == pid:
			prompts.append({"kind": String(pr["kind"]), "source": String(pr["source"]), "optional": bool(pr["optional"]), "data": (pr["data"] as Dictionary).duplicate(true)})
	return {
		"seed": seed_value, "player": pid, "mana": int(p.get("mana", -1)), "hp": int(p.get("hp", -1)),
		"potions_before": int(p.get("potions", -1)), "action": String(a["type"]), "actor": String(a["player"]),
		"turn": int((pre["turn"] as Dictionary)["number"]), "prompts": prompts,
		"forced": prompts.any(func(x: Dictionary) -> bool: return not bool(x["optional"])),
		"drink_answers_prompt": prompts.any(func(x: Dictionary) -> bool: return String(x["kind"]) in [Types.PROMPT_MANA_SHORTFALL, Types.PROMPT_DRINK_OR_SUFFER]),
	}


# =============================================================================
# Salida
# =============================================================================

static func _avg(arr: Array) -> float:
	if arr.is_empty():
		return 0.0
	var t: float = 0.0
	for x: Variant in arr:
		t += float(x)
	return t / arr.size()


static func _fmt(d: Dictionary, keys: Array = []) -> String:
	var ks: Array = keys if not keys.is_empty() else d.keys()
	if keys.is_empty():
		ks.sort()
	var parts: PackedStringArray = []
	for k: Variant in ks:
		parts.append("%s=%s" % [str(k), str(d.get(k, 0))])
	return ", ".join(parts)


func _print(rep: Dictionary) -> void:
	var g: int = int(rep["games"])
	var turns: Array = rep["player_turns"]
	var rounds: Array = rep["rounds"]
	var pt_sorted: Array = turns.duplicate()
	pt_sorted.sort()
	var med: float = float(pt_sorted[int(pt_sorted.size() / 2.0)]) if not pt_sorted.is_empty() else 0.0
	var played: Dictionary = rep["plays_by_card"]
	var never: Array = []
	var ev_never: Array = []
	for id: String in Types.PLAYABLE_CARD_IDS:
		if String(CardCatalog.get_def(id).get("type", "")) == Types.CARD_TYPE_EVENT:
			if not (rep["events_drawn"] as Dictionary).has(id):
				ev_never.append(id)
			continue
		if not played.has(id) and not (rep["reacts_by_card"] as Dictionary).has(id):
			never.append(id)
	rep["never_played"] = never
	rep["events_never_drawn"] = ev_never
	print("=== sim: %d partidas, semilla base %d, jugadores %s ===" % [g, rep["seed"], "3-6" if _fixed_players == 0 else str(_fixed_players)])
	print("efectos sin registrar: %s" % str(rep["effects_missing"]))
	print("terminadas dentro del tope (%d pasos): %d/%d (%.1f%%); sin terminar: %d" % [MAX_STEPS, rep["finished"], g, 100.0 * int(rep["finished"]) / maxf(1, g), rep["capped"]])
	print("pasos totales: %d (media %.1f por partida)" % [rep["total_steps"], float(rep["total_steps"]) / maxf(1, g)])
	print("turnos de jugador por partida: media %.1f, mediana %.0f, min %d, max %d" % [_avg(turns), med, (turns.min() if not turns.is_empty() else 0), (turns.max() if not turns.is_empty() else 0)])
	print("rondas completas por partida: media %.1f, max %d" % [_avg(rounds), (rounds.max() if not rounds.is_empty() else 0)])
	print("acciones (pasos del motor, incl. reacciones y prompts) por turno: %.2f" % (float(rep["actions_per_turn_sum"]) / maxf(1, int(rep["actions_per_turn_n"]))))
	print("acciones por tipo: %s" % _fmt(rep["actions_by_type"]))
	print("victorias por asiento (todas): %s" % _fmt(rep["wins_by_seat"]))
	print("partidas por nº de jugadores: %s" % _fmt(rep["games_by_players"]))
	print("victorias por nº jugadores:asiento: %s" % _fmt(rep["wins_by_seat_players"]))
	print("partidas con varios ganadores: %d" % rep["winners_multi"])
	var wg: Array = rep["windows_per_game"]
	print("ventanas de reacción: total %d, por partida media %.1f, max %d; reacciones %d, pasos %d" % [rep["windows_total"] if false else _sum(wg), _avg(wg), (wg.max() if not wg.is_empty() else 0), rep["reaction_reacts"], rep["reaction_passes"]])
	print("ventanas abiertas por lanzador: %s" % _fmt(rep["windows_by_caster"]))
	print("ventanas recibidas (en awaiting) por jugador: %s" % _fmt(rep["windows_received"]))
	var n_eot: int = int(rep["eot_n"])
	print("fin de turno de bot: maná medio %.2f, pociones medias %.2f (n=%d)" % [float(rep["eot_mana_sum"]) / maxf(1, n_eot), float(rep["eot_potions_sum"]) / maxf(1, n_eot), n_eot])
	print("eliminaciones por causa: %s" % _fmt(rep["elim_reasons"]))
	var tmm: Array = rep["tmm"]
	var forced: int = 0
	var answers: int = 0
	var mana_sum: float = 0.0
	for t: Variant in tmm:
		if bool((t as Dictionary)["forced"]):
			forced += 1
		if bool((t as Dictionary)["drink_answers_prompt"]):
			answers += 1
		mana_sum += float((t as Dictionary)["mana"])
	print("eliminados por Too Much Mana: %d (con prompt obligatorio pendiente: %d; beber respondía a ese prompt: %d; maná medio %.1f)" % [tmm.size(), forced, answers, mana_sum / maxf(1, tmm.size())])
	var shown: int = 0
	for t: Variant in tmm:
		shown += 1
		if shown > 12:
			print("  ... (%d más en --json)" % (tmm.size() - 12))
			break
		var d: Dictionary = t
		print("  semilla %d %s: maná %d, vida %d, pociones antes %d, acción %s de %s, turno %d, prompts %s" % [d["seed"], d["player"], d["mana"], d["hp"], d["potions_before"], d["action"], d["actor"], d["turn"], JSON.stringify(d["prompts"])])
	var rows: Array = []
	var ids: Array = played.keys()
	ids.sort_custom(func(x: String, y: String) -> bool: return int(played[x]) > int(played[y]))
	for id: Variant in ids:
		rows.append("%s=%d" % [id, played[id]])
	print("cartas jugadas (PLAY_CARD): %s" % ", ".join(PackedStringArray(rows)))
	print("cartas jugadas como respuesta (REACT): %s" % _fmt(rep["reacts_by_card"]))
	print("cartas que nunca se juegan, sin eventos (%d): %s" % [never.size(), str(never)])
	print("eventos robados (se aplican al robar): %s" % _fmt(rep["events_drawn"]))
	print("eventos que nunca salen (%d): %s" % [ev_never.size(), str(ev_never)])
	_print_blocks(rep)
	if String(rep["rn_mode"]) != "":
		var hg: Array = rep["rn_human_per_game"]
		print("reacciones al humano p1 (modo %s): ventanas con p1 en awaiting %d (%.2f/partida), modales (decisiones de p1) %d (%.2f/partida, max %d), auto-pases %d (%.2f/partida)" % [
			rep["rn_mode"], rep["rn_human_windows"], float(rep["rn_human_windows"]) / maxf(1.0, float(hg.size())),
			rep["rn_human_modals"], _avg(hg), (hg.max() if not hg.is_empty() else 0),
			rep["rn_human_auto"], float(rep["rn_human_auto"]) / maxf(1.0, float(hg.size()))])
	var viol: Array = rep["violations"]
	var errs: Array = rep["errors"]
	print("violaciones de invariantes: %d" % viol.size())
	for v: Variant in viol:
		print("  VIOLACION semilla %d paso %d: %s" % [(v as Dictionary)["seed"], (v as Dictionary)["step"], str((v as Dictionary)["errors"])])
	print("errores (acción ilegal/bloqueo/bucle): %d" % errs.size())
	for e: Variant in errs:
		print("  ERROR semilla %d paso %d: %s" % [(e as Dictionary)["seed"], (e as Dictionary)["step"], (e as Dictionary)["msg"]])


func _print_blocks(rep: Dictionary) -> void:
	var pg: Array = rep["per_game"]
	var with_block: int = 0
	var blocked_total: int = 0
	var over100: int = 0
	var over200: int = 0
	var over100_block: int = 0
	var lines: Array = []
	for x: Variant in pg:
		var r: Dictionary = x
		if int(r["blocked_rounds"]) > 0:
			with_block += 1
			blocked_total += int(r["blocked_rounds"])
		if int(r["turns"]) > 100:
			over100 += 1
			if int(r["blocked_rounds"]) > 0:
				over100_block += 1
			var al: Array = []
			for y: Variant in (r["alive_end"] as Array):
				var a: Dictionary = y
				al.append("%s(v%d m%d p%d)" % [a["id"], a["hp"], a["mana"], a["potions"]])
			lines.append("  g=%d semilla %d %dj: %d turnos, %d rondas, bloqueo %d rondas (racha max %d, desde ronda %d), cartas %d, daño %d, curado %d, pool fin %s, vivos %s, estado %s" % [
				r["g"], r["seed"], r["players"], r["turns"], r["rounds"], r["blocked_rounds"], r["max_idle_run"], r["first_block_round"],
				r["cards_played"], r["damage_dealt"], r["healed"], str(r["pool_end"]), " ".join(PackedStringArray(al)), r["status"]])
		if int(r["turns"]) > 200:
			over200 += 1
	print("límite de pociones en la corrida: %s" % str(rep["potion_limit"]))
	print("diagnóstico de bloqueo (>=3 rondas seguidas sin jugada/reacción/artefacto/daño): partidas con bloqueo %d/%d, rondas en bloqueo %d; partidas > 100 turnos %d (con bloqueo %d), > 200 turnos %d" % [with_block, pg.size(), blocked_total, over100, over100_block, over200])
	for l: Variant in lines:
		print(String(l))


static func _sum(arr: Array) -> int:
	var t: int = 0
	for x: Variant in arr:
		t += int(x)
	return t

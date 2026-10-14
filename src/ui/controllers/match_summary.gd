class_name MatchSummary
extends RefCounted
## Resumen de fin de partida (V2-26b, T26-B). Funciones estáticas puras: solo leen la
## vista pública (players, winners, config); no usan el log (que se recorta).
## Reglas: docs/TECNICO/preferencia-reaccion-y-resumen.md §2.2; textos: Strings §10.
##
## build(view, local_ids) -> {
##   title: String, subtitle: String, simultaneous: bool,
##   rows: [{pid, name, position:int, winner:bool, cause, blow, turns:int, potions:int,
##           stats: String, text: String}]
## }


static func build(view: Dictionary, local_ids: Array[String]) -> Dictionary:
	var players: Array = view.get("players", []) as Array
	var winners: Array = view.get("winners", []) as Array
	var cfg: Dictionary = view.get("config", {}) as Dictionary
	var limit: int = 0
	if bool(cfg.get("potion_limit_enabled", true)):
		limit = int(cfg.get("potion_limit", 10))

	var names: Dictionary = {}
	var seat: Dictionary = {}
	for i: int in players.size():
		var pd: Dictionary = players[i]
		names[String(pd["id"])] = String(pd.get("name", ""))
		seat[String(pd["id"])] = i

	# Solo cuentan como humanos locales los que juegan esta partida.
	var humans: Array = []
	for id: String in local_ids:
		if seat.has(id):
			humans.append(id)

	var ordered: Array = _sorted(players, winners, seat)
	var max_order: int = 0
	for p: Variant in ordered:
		max_order = maxi(max_order, int((p as Dictionary).get("eliminated_order", 0)))
	var at_max: int = 0
	for p: Variant in ordered:
		if max_order > 0 and int((p as Dictionary).get("eliminated_order", 0)) == max_order:
			at_max += 1
	var simultaneous: bool = winners.is_empty() and at_max > 1

	var rows: Array = []
	var prev_order: int = -1
	var prev_win: bool = false
	var position: int = 0
	for i: int in ordered.size():
		var pd: Dictionary = ordered[i]
		var pid: String = String(pd["id"])
		var is_winner: bool = winners.has(pid)
		var order: int = int(pd.get("eliminated_order", 0))
		if i == 0 or is_winner != prev_win or (not is_winner and order != prev_order):
			position = i + 1
		prev_order = order
		prev_win = is_winner
		var cause: String = Strings.END_CAUSE_WINNER
		var blow: String = ""
		if not is_winner:
			cause = Strings.end_cause(String(pd.get("eliminated_reason", "")))
			blow = _blow(pd, names, limit)
		var turns: int = int(pd.get("turns_played", 0))
		var potions: int = int(pd.get("potions", 0))
		rows.append({
			"pid": pid,
			"name": String(pd.get("name", "")),
			"position": position,
			"winner": is_winner,
			"cause": cause,
			"blow": blow,
			"turns": turns,
			"potions": potions,
			"stats": Strings.end_stats(turns, potions, limit),
			"text": Strings.end_row(String(pd.get("name", "")), cause, blow),
		})

	return {
		"title": Strings.end_title(winners, humans, names),
		"subtitle": Strings.end_tie_text(simultaneous) if winners.is_empty() else "",
		"simultaneous": simultaneous,
		"rows": rows,
	}


## Ganadores primero; luego eliminados por eliminated_order descendente; empate por asiento.
static func _sorted(players: Array, winners: Array, seat: Dictionary) -> Array:
	var out: Array = players.duplicate()
	out.sort_custom(func(a: Variant, b: Variant) -> bool:
		var ad: Dictionary = a
		var bd: Dictionary = b
		var aw: bool = winners.has(String(ad["id"]))
		var bw: bool = winners.has(String(bd["id"]))
		if aw != bw:
			return aw
		var ao: int = int(ad.get("eliminated_order", 0))
		var bo: int = int(bd.get("eliminated_order", 0))
		if ao != bo:
			return ao > bo
		return int(seat[String(ad["id"])]) < int(seat[String(bd["id"])]))
	return out


static func _blow(pd: Dictionary, names: Dictionary, limit: int) -> String:
	var pid: String = String(pd["id"])
	var by: String = String(pd.get("eliminated_by", ""))
	var card: String = String(pd.get("eliminated_card", ""))
	match String(pd.get("eliminated_reason", "")):
		Types.ELIM_TOO_MUCH_MANA:
			return Strings.end_potion_blow(int(pd.get("potions", 0)), limit)
		Types.ELIM_HP:
			if String(pd.get("eliminated_cause", "")) == Types.ELIM_CAUSE_MANA_SHORTFALL:
				return Strings.END_BY_LOW_MANA
			if by == pid and card != "":
				return Strings.end_self_blow(card)
			if by != "" and by != pid and card != "":
				return Strings.end_final_blow(Strings.mage(names, by), card)
			if by == "" and card != "":
				return Strings.end_by_source(card)
	return ""

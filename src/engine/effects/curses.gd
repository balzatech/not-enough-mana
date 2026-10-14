class_name CurseEffects
extends RefCounted
## Maldiciones (T6c). Firma: static func id(state: Dictionary, ctx: Dictionary) -> Dictionary
##
##  * Curse of Rules: se queda en la mesa de quien la lanza (player.curses) con
##    data.rule = texto libre (extra.rule). Cualquiera que rompa la regla pierde
##    1💧 con la acción BREAK_RULE (Game._break_rule), también quien la lanzó.
##    En línea, solo el anfitrión o el propio afectado pueden enviarla: la capa
##    de sesión lo comprueba con can_report_rule_break().
##  * Elder / Younger / Vigour / Even / Odd: los magos vivos que cumplen la
##    condición pierden 3💧 (Damage.lose_mana, card_id = la maldición).
##    Edad: comparación estricta (misma edad = no afectado; sin desempate por
##    mes). Vigour, Even y Odd incluyen a quien la lanza si cumple.
##  * Runic Armor NO se comprueba aquí: su modificador (prevent, custom
##    "runic_armor") anula toda pérdida cuyo card_id sea una maldición.
##  * Force Field: un mago con flags.force_field no es afectado (las maldiciones
##    son hechizos).

const CURSE_MANA_LOSS: int = 3
const MAX_RULE_LENGTH: int = 200


# =============================================================================
# Curse of Rules
# =============================================================================

static func curse_of_rules(state: Dictionary, ctx: Dictionary) -> Dictionary:
	var caster: String = ctx["caster"]
	var card: Dictionary = ctx["card"]
	var extra: Dictionary = ctx["extra"]
	var raw: Variant = extra.get("rule", "")
	var rule: String = (String(raw) if raw is String else "").strip_edges().left(MAX_RULE_LENGTH)
	var p: Dictionary = Types.get_player(state, caster)
	(p["curses"] as Array).append(Types.make_table_card(int(card["iid"]), Types.CARD_CURSE_OF_RULES, caster,
		{"rule": rule}))
	(ctx["events"] as Array).append(Types.make_log_entry(Types.LOG_EFFECT, Damage.turn_no(state), caster,
		{"card_id": Types.CARD_CURSE_OF_RULES, "what": "rule_established", "rule": rule, "iid": int(card["iid"])}))
	return state


## ¿Puede `reporter` denunciar a `target` por romper una Curse of Rules?
## En local siempre (botón compartido). En línea solo el anfitrión (host_id) o
## el propio afectado. Lo usa la capa de sesión antes de aceptar BREAK_RULE.
static func can_report_rule_break(state: Dictionary, reporter: String, target: String, host_id: String) -> bool:
	var mode: String = (state["config"] as Dictionary).get("mode", "local")
	if mode != "online":
		return true
	return reporter == host_id or reporter == target


# =============================================================================
# Maldiciones de 3💧
# =============================================================================

static func curse_of_the_elder(state: Dictionary, ctx: Dictionary) -> Dictionary:
	var me: Dictionary = Types.get_player(state, String(ctx["caster"]))
	var age: int = me["age"]
	return _drain(state, ctx, func(p: Dictionary) -> bool: return int(p["age"]) > age)


static func curse_of_the_younger(state: Dictionary, ctx: Dictionary) -> Dictionary:
	var me: Dictionary = Types.get_player(state, String(ctx["caster"]))
	var age: int = me["age"]
	return _drain(state, ctx, func(p: Dictionary) -> bool: return int(p["age"]) < age)


static func curse_of_vigour(state: Dictionary, ctx: Dictionary) -> Dictionary:
	var me: Dictionary = Types.get_player(state, String(ctx["caster"]))
	var hp: int = me["hp"]
	return _drain(state, ctx, func(p: Dictionary) -> bool: return int(p["hp"]) >= hp)


static func curse_of_even(state: Dictionary, ctx: Dictionary) -> Dictionary:
	return _drain(state, ctx, func(p: Dictionary) -> bool: return int(p["birth_month"]) % 2 == 0)


static func curse_of_odd(state: Dictionary, ctx: Dictionary) -> Dictionary:
	return _drain(state, ctx, func(p: Dictionary) -> bool: return int(p["birth_month"]) % 2 == 1)


## Magos vivos (en orden de asiento) que cumplen `pred` al resolverse.
static func affected(state: Dictionary, pred: Callable) -> Array[String]:
	var out: Array[String] = []
	for pid: String in Types.alive_ids(state):
		if bool(pred.call(Types.get_player(state, pid))):
			out.append(pid)
	return out


static func _drain(state: Dictionary, ctx: Dictionary, pred: Callable) -> Dictionary:
	var caster: String = ctx["caster"]
	var card: Dictionary = ctx["card"]
	var card_id: String = card["card_id"]
	var events: Array = ctx["events"]
	var hit: Array[String] = affected(state, pred)
	events.append(Types.make_log_entry(Types.LOG_EFFECT, Damage.turn_no(state), caster,
		{"card_id": card_id, "what": "curse_targets", "targets": Array(hit)}))
	for pid: String in hit:
		var p: Dictionary = Types.get_player(state, pid)
		if String((p["flags"] as Dictionary)["force_field"]) != "":
			events.append(Types.make_log_entry(Types.LOG_EFFECT, Damage.turn_no(state), caster,
				{"card_id": card_id, "what": "immune", "target": pid, "by": Types.CARD_FORCE_FIELD}))
			continue
		Damage.lose_mana(state, pid, CURSE_MANA_LOSS, events, caster, card_id, int(card["iid"]))
	return state

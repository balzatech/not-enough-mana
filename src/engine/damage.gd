class_name Damage
extends RefCounted
## Daño, curación, maná (con pool común), pociones, costes, límite de mano,
## descartes forzados y eliminación (T4).
##
## Todas las funciones MUTAN `state` (la copia de trabajo del reducer) y añaden
## entradas de log a `events`. Los efectos (T6a/b/c) las usan así:
##
##   var ev: Dictionary = Types.make_mod_event("damage", 2, caster, target,
##       Types.ELEMENT_FIRE, Types.CARD_FIREBALL, spell_iid, true)
##   state = Damage.apply(state, ev, ctx["events"])        # o Damage.resolve() para ver el evento final
##   Damage.lose_mana(state, target, 2, ctx["events"], caster, Types.CARD_MANA_IMPLOSION)
##   Damage.heal(state, target, 1, ctx["events"], caster, Types.CARD_HEAL)
##   Damage.forced_discard(state, target, 1, ctx["events"], Types.CARD_ICE_BOLT)
##
## Ampliación SIN tocar este archivo: registrando modificadores (Modifiers.add):
##  * daño ("damage"): etapas outgoing → incoming → prevent → redirect y, tras
##    aplicar, after_damage (amount = daño final aplicado al objetivo, data.dealt
##    = vida realmente perdida). El daño redirigido (OP_REDIRECT) se aplica como
##    un evento nuevo al destino que pasa solo por incoming y prevent (no vuelve
##    a redirigirse, para evitar bucles) y luego por after_damage.
##  * pérdida de maná ("mana_loss"): solo etapa prevent, con element = none,
##    is_spell = false y spell_iid = -1 (así Magic Shield y los bonos
##    elementales NO la tocan; un handler OP_CUSTOM como Magic Cap sí puede).
##    data.spell_iid y data.element guardan el origen real.
##  * coste ("cost"), intercambio ("exchange_cost"), poción ("potion") y límite
##    de mano ("hand_limit"): su etapa homónima.
##  * Force Field: el daño de hechizo (is_spell) a un mago con flags.force_field
##    != "" se previene entero antes de las etapas.

const KIND_DAMAGE: String = "damage"
const KIND_MANA_LOSS: String = "mana_loss"
const KIND_HP_LOSS: String = "hp_loss"
const KIND_COST: String = "cost"
const KIND_EXCHANGE_COST: String = "exchange_cost"
const KIND_POTION: String = "potion"
const KIND_HAND_LIMIT: String = "hand_limit"

## Etapas que recorre el daño redirigido (sin redirect para evitar bucles).
const REDIRECTED_STAGES: Array[String] = [Types.STAGE_INCOMING, Types.STAGE_PREVENT]


# =============================================================================
# Daño
# =============================================================================

## Aplica un evento de daño (Types.make_mod_event) y devuelve el estado.
static func apply(state: Dictionary, ev: Dictionary, events: Array) -> Dictionary:
	resolve(state, ev, events)
	return state


## Aplica un evento de daño y devuelve el evento final (tras after_damage).
## ev.amount = daño aplicado al objetivo original; ev.data.dealt = vida perdida.
static func resolve(state: Dictionary, ev: Dictionary, events: Array) -> Dictionary:
	var e: Dictionary = ev.duplicate(true)
	var target: Dictionary = Types.get_player(state, String(e["target"]))
	if target.is_empty() or bool(target["eliminated"]):
		e["amount"] = 0
		(e["data"] as Dictionary)["dealt"] = 0
		return e
	var flags: Dictionary = target["flags"]
	if bool(e["is_spell"]) and String(flags["force_field"]) != "":
		e["prevented"] = int(e["prevented"]) + int(e["amount"])
		e["amount"] = 0
		(e["data"] as Dictionary)["immune"] = true
	else:
		e = Modifiers.run_stages(state, Types.DAMAGE_STAGES, e)
	e["amount"] = maxi(0, int(e["amount"]))
	e = _deal(state, e, events)
	for r: Variant in e["redirects"]:
		var rd: Dictionary = r
		var sub: Dictionary = Types.make_mod_event(String(e["kind"]), int(rd["amount"]), String(e["source"]),
			String(rd["to"]), String(e["element"]), String(e["card_id"]), int(e["spell_iid"]), bool(e["is_spell"]))
		(sub["data"] as Dictionary)["redirected_from"] = String(e["target"])
		var to_p: Dictionary = Types.get_player(state, String(rd["to"]))
		if to_p.is_empty() or bool(to_p["eliminated"]):
			continue
		sub = Modifiers.run_stages(state, REDIRECTED_STAGES, sub)
		sub["amount"] = maxi(0, int(sub["amount"]))
		sub = _deal(state, sub, events)
		Modifiers.run_stage(state, Types.STAGE_AFTER_DAMAGE, sub)
	return Modifiers.run_stage(state, Types.STAGE_AFTER_DAMAGE, e)


static func _deal(state: Dictionary, e: Dictionary, events: Array) -> Dictionary:
	var pid: String = e["target"]
	var lost: int = lose_hp(state, pid, int(e["amount"]), events, String(e["source"]), String(e["card_id"]), false)
	(e["data"] as Dictionary)["dealt"] = lost
	events.append(Types.make_log_entry(Types.LOG_DAMAGE, turn_no(state), String(e["source"]), {
		"target": pid, "amount": int(e["amount"]), "dealt": lost, "prevented": int(e["prevented"]),
		"element": String(e["element"]), "card_id": String(e["card_id"]),
	}))
	_check_hp_elimination(state, pid, events, String(e["source"]), String(e["card_id"]), Types.ELIM_CAUSE_DAMAGE)
	return e


# =============================================================================
# Vida
# =============================================================================

## Pérdida directa de vida (sin modificadores). Devuelve la vida perdida.
## Los cristales vuelven al pool. Elimina al jugador si llega a 0.
static func lose_hp(state: Dictionary, pid: String, amount: int, events: Array,
		source: String = "", card_id: String = "", log_it: bool = true,
		cause: String = Types.ELIM_CAUSE_HP_LOSS) -> int:
	var p: Dictionary = Types.get_player(state, pid)
	if p.is_empty() or bool(p["eliminated"]) or amount <= 0:
		return 0
	var lost: int = mini(amount, int(p["hp"]))
	p["hp"] = int(p["hp"]) - lost
	_return_pool(state, "hp", lost)
	if log_it:
		events.append(Types.make_log_entry(Types.LOG_DAMAGE, turn_no(state), source, {
			"target": pid, "amount": amount, "dealt": lost, "prevented": 0,
			"element": Types.ELEMENT_NONE, "card_id": card_id, "kind": KIND_HP_LOSS,
		}))
		_check_hp_elimination(state, pid, events, source, card_id, cause)
	return lost


## Curación con tope config.max_hp (y limitada por el pool). Devuelve lo curado.
static func heal(state: Dictionary, pid: String, amount: int, events: Array,
		source: String = "", card_id: String = "") -> int:
	var p: Dictionary = Types.get_player(state, pid)
	if p.is_empty() or bool(p["eliminated"]) or amount <= 0:
		return 0
	var max_hp: int = int((state["config"] as Dictionary)["max_hp"])
	var want: int = maxi(0, mini(amount, max_hp - int(p["hp"])))
	var got: int = _take_pool(state, "hp", want)
	p["hp"] = int(p["hp"]) + got
	events.append(Types.make_log_entry(Types.LOG_HEAL, turn_no(state), source,
		{"target": pid, "amount": got, "card_id": card_id}))
	return got


# =============================================================================
# Maná
# =============================================================================

## Gana maná (limitado por el pool común). Devuelve lo ganado.
static func gain_mana(state: Dictionary, pid: String, amount: int, events: Array,
		source: String = "", card_id: String = "") -> int:
	var p: Dictionary = Types.get_player(state, pid)
	if p.is_empty() or bool(p["eliminated"]) or amount <= 0:
		return 0
	var got: int = _take_pool(state, "mana", amount)
	p["mana"] = int(p["mana"]) + got
	events.append(Types.make_log_entry(Types.LOG_MANA_CHANGED, turn_no(state), source,
		{"target": pid, "delta": got, "card_id": card_id}))
	return got


## Paga maná (coste ya validado: no genera faltante). Devuelve lo pagado.
static func pay_mana(state: Dictionary, pid: String, amount: int) -> int:
	var p: Dictionary = Types.get_player(state, pid)
	if p.is_empty() or amount <= 0:
		return 0
	var paid: int = mini(amount, int(p["mana"]))
	p["mana"] = int(p["mana"]) - paid
	_return_pool(state, "mana", paid)
	return paid


## Pérdida de maná por un efecto (regla 1.3). Si falta maná, el jugador queda a
## 0 y recibe un prompt PROMPT_MANA_SHORTFALL {missing}: si bebe una poción paga
## lo que falta con ella; si declina (DECLINE) pierde esa vida. Devuelve el
## maná realmente perdido ahora.
static func lose_mana(state: Dictionary, pid: String, amount: int, events: Array,
		source: String = "", card_id: String = "", spell_iid: int = -1) -> int:
	var p: Dictionary = Types.get_player(state, pid)
	if p.is_empty() or bool(p["eliminated"]) or amount <= 0:
		return 0
	var ev: Dictionary = Types.make_mod_event(KIND_MANA_LOSS, amount, source, pid, Types.ELEMENT_NONE, card_id)
	(ev["data"] as Dictionary)["spell_iid"] = spell_iid
	ev = Modifiers.run_stage(state, Types.STAGE_PREVENT, ev)
	var amt: int = maxi(0, int(ev["amount"]))
	if amt == 0:
		return 0
	var paid: int = pay_mana(state, pid, amt)
	var missing: int = amt - paid
	events.append(Types.make_log_entry(Types.LOG_MANA_CHANGED, turn_no(state), source,
		{"target": pid, "delta": -paid, "missing": missing, "card_id": card_id}))
	if missing > 0:
		add_shortfall(state, pid, missing, card_id)
	return paid


## Crea (o amplía) el prompt de maná insuficiente de pid.
static func add_shortfall(state: Dictionary, pid: String, missing: int, card_id: String = "") -> void:
	for pr: Variant in state["pending"]:
		var prd: Dictionary = pr
		if prd["player"] == pid and prd["kind"] == Types.PROMPT_MANA_SHORTFALL:
			var data: Dictionary = prd["data"]
			data["missing"] = int(data["missing"]) + missing
			return
	(state["pending"] as Array).append(Types.make_prompt(Types.next_seq(state), pid,
		Types.PROMPT_MANA_SHORTFALL, {"missing": missing}, card_id, true))


## Aplica el maná actual de pid al faltante `missing`. Devuelve lo que sigue
## faltando.
static func pay_shortfall(state: Dictionary, pid: String, missing: int) -> int:
	return missing - pay_mana(state, pid, missing)


# =============================================================================
# Pociones
# =============================================================================

## Maná que daría ahora una poción de pid (antes del límite del pool):
## config.potion_mana → etapa potion → ×2 por cada Potent Elixir pendiente.
## consume=false no gasta modificadores EXPIRES_ONCE (vista previa).
static func potion_amount(state: Dictionary, pid: String, consume: bool = false) -> int:
	var base: int = int((state["config"] as Dictionary)["potion_mana"])
	var ev: Dictionary = Types.make_mod_event(KIND_POTION, base, pid, pid)
	var amount: int = maxi(0, int(_run(state, Types.STAGE_POTION, ev, consume)["amount"]))
	var p: Dictionary = Types.get_player(state, pid)
	if not p.is_empty():
		var n: int = int((p["flags"] as Dictionary)["potent_elixir"])
		for _i: int in n:
			amount *= 2
	return amount


## Bebe una poción. Cuenta para Too Much Mana: si potion_limit_enabled y es la
## poción n.º potion_limit+1, el jugador queda eliminado (sin ganar maná).
## Devuelve {gained:int, eliminated:bool}.
static func drink_potion(state: Dictionary, pid: String, events: Array) -> Dictionary:
	var p: Dictionary = Types.get_player(state, pid)
	var cfg: Dictionary = state["config"]
	p["potions"] = int(p["potions"]) + 1
	if bool(cfg["potion_limit_enabled"]) and int(p["potions"]) > int(cfg["potion_limit"]):
		events.append(Types.make_log_entry(Types.LOG_POTION, turn_no(state), pid,
			{"amount": 0, "potions": int(p["potions"])}))
		eliminate(state, pid, Types.ELIM_TOO_MUCH_MANA, events)  # sin by/carta/causa
		return {"gained": 0, "eliminated": true}
	var amount: int = potion_amount(state, pid, true)
	(p["flags"] as Dictionary)["potent_elixir"] = 0
	var got: int = _take_pool(state, "mana", amount)
	p["mana"] = int(p["mana"]) + got
	events.append(Types.make_log_entry(Types.LOG_POTION, turn_no(state), pid,
		{"amount": got, "potions": int(p["potions"])}))
	return {"gained": got, "eliminated": false}


# =============================================================================
# Costes y límite de mano
# =============================================================================

## Coste en maná de jugar `def` (etapa cost). spell_iid = iid de la carta.
static func card_cost(state: Dictionary, pid: String, def: Dictionary, card_iid: int = -1,
		consume: bool = false) -> int:
	var cost: Dictionary = def.get("cost", {})
	var ev: Dictionary = Types.make_mod_event(KIND_COST, int(cost.get("mana", 0)), pid, pid,
		String(def.get("element", Types.ELEMENT_NONE)), String(def.get("id", "")), card_iid,
		bool(def.get("is_spell", false)))
	return maxi(0, int(_run(state, Types.STAGE_COST, ev, consume)["amount"]))


## Coste del próximo intercambio de pid: exchange_base_cost + intercambios ya
## hechos este turno (1, 2, 3…), por la etapa exchange_cost.
static func exchange_cost(state: Dictionary, pid: String, consume: bool = false) -> int:
	var base: int = int((state["config"] as Dictionary)["exchange_base_cost"]) \
		+ int((state["turn"] as Dictionary)["exchanges"])
	var ev: Dictionary = Types.make_mod_event(KIND_EXCHANGE_COST, base, pid, pid)
	return maxi(0, int(_run(state, Types.STAGE_EXCHANGE_COST, ev, consume)["amount"]))


## Límite de mano de pid (config.hand_limit por la etapa hand_limit). No consume.
static func hand_limit(state: Dictionary, pid: String) -> int:
	var ev: Dictionary = Types.make_mod_event(KIND_HAND_LIMIT, int((state["config"] as Dictionary)["hand_limit"]), pid, pid)
	return maxi(0, int(_run(state, Types.STAGE_HAND_LIMIT, ev, false)["amount"]))


static func _run(state: Dictionary, stage: String, ev: Dictionary, consume: bool) -> Dictionary:
	if consume:
		return Modifiers.run_stage(state, stage, ev)
	var tmp: Dictionary = state.duplicate()
	tmp["modifiers"] = (state["modifiers"] as Array).duplicate(true)
	return Modifiers.run_stage(tmp, stage, ev)


# =============================================================================
# Descartes forzados
# =============================================================================

## Un efecto obliga a pid a descartar `count` cartas. Si tiene más cartas que
## `count`, recibe un PROMPT_DISCARD {count} (responde con CHOOSE_CARDS). Si
## tiene `count` o menos, las descarta todas y pierde 1 maná por cada carta que
## no pudo descartar (regla 1.3, con faltante → prompt de maná).
static func forced_discard(state: Dictionary, pid: String, count: int, events: Array,
		card_id: String = "") -> void:
	var p: Dictionary = Types.get_player(state, pid)
	if p.is_empty() or bool(p["eliminated"]) or count <= 0:
		return
	var hand: Array = p["hand"]
	if hand.size() > count:
		(state["pending"] as Array).append(Types.make_prompt(Types.next_seq(state), pid,
			Types.PROMPT_DISCARD, {"count": count}, card_id, false))
		return
	var n: int = hand.size()
	var iids: Array = []
	for c: Variant in hand:
		iids.append(int((c as Dictionary)["iid"]))
		Deck.to_discard(state, c)
	hand.clear()
	if n > 0:
		events.append(Types.make_log_entry(Types.LOG_CARD_DISCARDED, turn_no(state), pid,
			{"cards": iids, "forced": true, "card_id": card_id}))
	if count > n:
		lose_mana(state, pid, count - n, events, "", card_id)


# =============================================================================
# Eliminación
# =============================================================================

## Elimina a pid: descarta su mano y retira sus prompts pendientes. Anota los
## campos del resumen de fin: eliminated_order (= rev de la acción en curso),
## eliminated_turn y, opcionalmente, quién dio el golpe, la carta y la causa.
static func eliminate(state: Dictionary, pid: String, reason: String, events: Array,
		by: String = "", card_id: String = "", cause: String = "") -> void:
	var p: Dictionary = Types.get_player(state, pid)
	if p.is_empty() or bool(p["eliminated"]):
		return
	p["eliminated"] = true
	p["eliminated_reason"] = reason
	p["eliminated_order"] = int(state["rev"]) + 1
	p["eliminated_turn"] = turn_no(state)
	p["eliminated_by"] = by
	p["eliminated_card"] = card_id
	p["eliminated_cause"] = cause
	var hand: Array = p["hand"]
	for c: Variant in hand:
		Deck.to_discard(state, c)
	hand.clear()
	var kept: Array = []
	for pr: Variant in state["pending"]:
		if (pr as Dictionary)["player"] != pid:
			kept.append(pr)
	state["pending"] = kept
	events.append(Types.make_log_entry(Types.LOG_ELIMINATED, turn_no(state), pid, {"reason": reason}))


static func _check_hp_elimination(state: Dictionary, pid: String, events: Array,
		source: String = "", card_id: String = "", cause: String = Types.ELIM_CAUSE_HP_LOSS) -> void:
	var p: Dictionary = Types.get_player(state, pid)
	if not p.is_empty() and not bool(p["eliminated"]) and int(p["hp"]) <= 0:
		eliminate(state, pid, Types.ELIM_HP, events, source, card_id, cause)


# =============================================================================
# Pool común de cristales
# =============================================================================

static func _take_pool(state: Dictionary, res: String, amount: int) -> int:
	if amount <= 0:
		return 0
	if not bool((state["config"] as Dictionary)["pool_enabled"]):
		return amount
	var pool: Dictionary = state["pool"]
	var got: int = mini(amount, int(pool[res]))
	pool[res] = int(pool[res]) - got
	return got


static func _return_pool(state: Dictionary, res: String, amount: int) -> void:
	if amount <= 0 or not bool((state["config"] as Dictionary)["pool_enabled"]):
		return
	var pool: Dictionary = state["pool"]
	pool[res] = int(pool[res]) + amount


static func turn_no(state: Dictionary) -> int:
	return int((state["turn"] as Dictionary)["number"])

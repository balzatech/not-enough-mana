class_name ElectricEffects
extends RefCounted
## Efectos ofensivos de electricidad (T6a). Firma: static func id(state: Dictionary, ctx: Dictionary) -> Dictionary
## Reglas comunes (daño por Damage, objetivo eliminado, vecinos, Force Field):
## ver la cabecera de FireEffects, cuyas utilidades se reutilizan aquí.
##
## =============================================================================
## CONTRATO LIGHTNING ENCADENADO  (T6a <-> T6b, reactions.gd)
## =============================================================================
## Texto: "The target loses 2💖. The target may use another Lightning card in
## order to increase the damage of the spell by 1 and redirect it to another
## wizard." Se apoya en el punto de extensión genérico de reactions.gd (T6b);
## este archivo NO llama a Reactions (solo lee/escribe state.reaction, que es
## parte de types.gd). Lo que T6a espera de reactions.gd:
##
##  1. Hook HOOK_CAN_RESPOND ("can_respond", = Reactions.HOOK_CAN_RESPOND)
##     registrado para Lightning (can_respond_lightning). reactions.gd lo llama
##     al validar un REACT con ctx = make_effect_ctx(card, def, caster = quien
##     responde, targets, extra) + reaction, responding_to, ok=false, DESPUÉS
##     de validar los objetivos según def.target (single: vivo, Force Field →
##     ERR_TARGET_IMMUNE). El hook no muta state; pone ctx.ok = true si:
##       - hay un Lightning "en foco" no cancelado (focus_lightning: el Lightning
##         más alto de reaction.stack o, si no hay, reaction.spell), y
##       - quien responde es su objetivo actual (targets[0]); y
##       - el nuevo objetivo es otro mago (no él mismo: ERR_INVALID_TARGET), y
##       - no está cegado en su propio turno (ERR_BLINDED; Blinding Flash solo
##         afecta "durante su próximo turno").
##  2. reactions.gd cobra el REACT como cualquier otro (coste normal de la
##     carta: 2💧 por la etapa cost, sin cartas de pago), lo apila en
##     reaction.stack como make_spell(is_response = true) con sus targets y
##     abre una ronda nueva cuyo primer decisor es el objetivo de la respuesta
##     (response_order usa la respuesta is_spell más alta como foco). Así el
##     nuevo objetivo puede volver a encadenar.
##  3. FIN DE LA CADENA: cuando la ronda se cierra sin que el objetivo actual
##     encadene (todos pasan, o ya no tiene Lightning/maná/objetivos válidos).
##     No hay límite de eslabones. Se puede redirigir a cualquier mago vivo
##     distinto de quien redirige (también al lanzador original o a un eslabón
##     anterior) sin Force Field.
##  4. Al cerrar, reactions.gd resuelve la pila LIFO: SACA la respuesta de
##     reaction.stack (pop) y DESPUÉS llama a su efecto con ctx.is_response =
##     true y ctx.spell = la respuesta, con state.reaction aún presente. El
##     efecto lightning() en modo respuesta busca el Lightning inmediatamente
##     inferior (chain_parent: el Lightning más alto que quede en la pila o, si
##     no hay, reaction.spell) y le copia el objetivo, le suma el bono
##     (bonus(prev) + 1 + bonus(me)) y le pasa data.lightning_source. No hace
##     daño. Por eso no depende de data.responds_to (que podría apuntar a una
##     defensiva jugada encima del Lightning).
##  5. Por último se resuelve reaction.spell (Game.resolve_spell): 2 +
##     data.damage_bonus de daño eléctrico al objetivo final, con source =
##     data.lightning_source (el último que redirigió; sin cadena, el lanzador).
##     Un eslabón cancelado (Annihilation) no transmite su redirección.
## =============================================================================

## Clave del hook de respuesta de reactions.gd (Reactions.HOOK_CAN_RESPOND).
## Copia local para no depender del script de T6b (pedido en CAMBIOS-TIPOS.md
## como Types.HOOK_CAN_RESPOND).
const HOOK_CAN_RESPOND: String = Types.HOOK_CAN_RESPOND

const LIGHTNING_DAMAGE: int = 2
const LIGHTNING_CHAIN_BONUS: int = 1
const EXPLOSION_DAMAGE: int = 2
const FLASH_DAMAGE: int = 2
const ARC_DAMAGE: int = 1
const PARALYSING_DAMAGE: int = 2
const PARALYSING_DISCARD: int = 2


# =============================================================================
# Cartas de electricidad
# =============================================================================

## Lightning: el objetivo (final, tras la cadena) pierde 2💖 + bonus de
## cadena. Como respuesta encadenada (ctx.is_response) no hace daño: transmite
## su objetivo y bono al Lightning inferior (ver contrato, punto 4).
static func lightning(state: Dictionary, ctx: Dictionary) -> Dictionary:
	var spell: Dictionary = ctx["spell"]
	if bool(ctx["is_response"]):
		return _chain_into_parent(state, ctx, spell)
	var data: Dictionary = spell.get("data", {})
	var target: String = FireEffects.main_target(ctx)
	if not FireEffects.is_alive(state, target):
		return FireEffects.fizzle(state, ctx)
	FireEffects.hit(state, ctx, target, lightning_damage(spell), String(data.get("lightning_source", "")))
	return state


## Electric Explosion: todos los magos vivos menos el lanzador pierden 2💖.
static func electric_explosion(state: Dictionary, ctx: Dictionary) -> Dictionary:
	for pid: String in FireEffects.area_targets(state, ctx, false):
		FireEffects.hit(state, ctx, pid, EXPLOSION_DAMAGE)
	return state


## Blinding Flash: el objetivo pierde 2💖 y no puede lanzar ofensivas en su
## próximo turno (flags.blinded; Game lo comprueba y lo quita al acabar ese turno).
static func blinding_flash(state: Dictionary, ctx: Dictionary) -> Dictionary:
	var target: String = FireEffects.main_target(ctx)
	if not FireEffects.is_alive(state, target):
		return FireEffects.fizzle(state, ctx)
	FireEffects.hit(state, ctx, target, FLASH_DAMAGE)
	if FireEffects.is_alive(state, target) and not FireEffects.immune(state, ctx, target):
		(Types.get_player(state, target)["flags"] as Dictionary)["blinded"] = true
		FireEffects.log_effect(state, ctx, "blinded", {"target": target})
	return state


## Electric Arc: dos objetivos distintos (Game lo valida) pierden 1💖 cada uno.
## Si uno ya está eliminado, el otro recibe su daño igualmente.
static func electric_arc(state: Dictionary, ctx: Dictionary) -> Dictionary:
	var alive: Array[String] = []
	for t: Variant in ctx["targets"]:
		if FireEffects.is_alive(state, String(t)):
			alive.append(String(t))
	if alive.is_empty():
		return FireEffects.fizzle(state, ctx)
	for pid: String in alive:
		FireEffects.hit(state, ctx, pid, ARC_DAMAGE)
	return state


## Paralysing Touch: el objetivo pierde 2💖 y descarta 2 cartas.
static func paralysing_touch(state: Dictionary, ctx: Dictionary) -> Dictionary:
	var target: String = FireEffects.main_target(ctx)
	if not FireEffects.is_alive(state, target):
		return FireEffects.fizzle(state, ctx)
	FireEffects.hit(state, ctx, target, PARALYSING_DAMAGE)
	if FireEffects.is_alive(state, target) and not FireEffects.immune(state, ctx, target):
		Damage.forced_discard(state, target, PARALYSING_DISCARD, ctx["events"], FireEffects.card_id(ctx))
	return state


# =============================================================================
# Cadena de Lightning (ver contrato arriba)
# =============================================================================

## Daño total del Lightning `spell` (2 + bonus de cadena).
static func lightning_damage(spell: Dictionary) -> int:
	return LIGHTNING_DAMAGE + _bonus(spell)


## Hook HOOK_CAN_RESPOND de Lightning (no muta state).
static func can_respond_lightning(state: Dictionary, ctx: Dictionary) -> Dictionary:
	var focus: Dictionary = focus_lightning(state)
	if focus.is_empty():
		return state
	var ft: Array = focus["targets"]
	var pid: String = ctx["caster"]
	if ft.size() != 1 or String(ft[0]) != pid:
		return state
	var targets: Array = ctx["targets"]
	if targets.size() != 1 or String(targets[0]) == pid or not FireEffects.is_alive(state, String(targets[0])):
		ctx["error"] = Types.ERR_INVALID_TARGET
		return state
	var p: Dictionary = Types.get_player(state, pid)
	if bool((p["flags"] as Dictionary)["blinded"]) and String((state["turn"] as Dictionary)["current"]) == pid:
		ctx["error"] = Types.ERR_BLINDED
		return state
	ctx["ok"] = true
	return state


## Lightning al que se puede encadenar ahora: el más alto no cancelado de
## reaction.stack o, si no hay, reaction.spell si es un Lightning no cancelado.
## {} si no hay ninguno (referencia viva).
static func focus_lightning(state: Dictionary) -> Dictionary:
	var re: Dictionary = state.get("reaction", {})
	if re.is_empty():
		return {}
	var stack: Array = re.get("stack", [])
	for i: int in range(stack.size() - 1, -1, -1):
		var sd: Dictionary = stack[i]
		if _is_lightning(sd):
			if bool(sd.get("cancelled", false)):
				return {}
			return sd
	var main: Dictionary = re.get("spell", {})
	if _is_lightning(main) and not bool(main.get("cancelled", false)):
		return main
	return {}


## Lightning inmediatamente inferior a una respuesta que se está resolviendo
## (ya fuera de la pila): el más alto que quede en reaction.stack (aunque esté
## cancelado) o reaction.spell. {} si no hay.
static func chain_parent(state: Dictionary, me_iid: int = -1) -> Dictionary:
	var re: Dictionary = state.get("reaction", {})
	if re.is_empty():
		return {}
	var stack: Array = re.get("stack", [])
	for i: int in range(stack.size() - 1, -1, -1):
		var sd: Dictionary = stack[i]
		if _is_lightning(sd) and _iid(sd) != me_iid:
			return sd
	var main: Dictionary = re.get("spell", {})
	if _is_lightning(main) and _iid(main) != me_iid:
		return main
	return {}


static func _chain_into_parent(state: Dictionary, ctx: Dictionary, me: Dictionary) -> Dictionary:
	var prev: Dictionary = chain_parent(state, _iid(me))
	var targets: Array = me.get("targets", [])
	if prev.is_empty() or targets.is_empty():
		return FireEffects.fizzle(state, ctx)
	var me_data: Dictionary = me.get("data", {})
	if not prev.has("data"):
		prev["data"] = {}
	var pdata: Dictionary = prev["data"]
	var from: Array = (prev.get("targets", []) as Array).duplicate()
	pdata["damage_bonus"] = _bonus(prev) + LIGHTNING_CHAIN_BONUS + _bonus(me)
	pdata["lightning_source"] = String(me_data.get("lightning_source", String(me["caster"])))
	prev["targets"] = targets.duplicate()
	FireEffects.log_effect(state, ctx, "lightning_redirected", {"from": from,
		"to": targets.duplicate(), "into": _iid(prev), "damage": lightning_damage(prev)})
	return state


static func _bonus(spell: Dictionary) -> int:
	var data: Dictionary = spell.get("data", {})
	return int(data.get("damage_bonus", 0))


static func _is_lightning(spell: Dictionary) -> bool:
	if spell.is_empty():
		return false
	var card: Dictionary = spell.get("card", {})
	return String(card.get("card_id", "")) == Types.CARD_LIGHTNING


static func _iid(spell: Dictionary) -> int:
	var card: Dictionary = spell.get("card", {})
	return int(card.get("iid", -1))

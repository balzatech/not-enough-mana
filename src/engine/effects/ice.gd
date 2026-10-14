class_name IceEffects
extends RefCounted
## Efectos ofensivos de hielo (T6a). Firma: static func id(state: Dictionary, ctx: Dictionary) -> Dictionary
## Reglas comunes (daño por Damage, objetivo eliminado, vecinos, Force Field):
## ver la cabecera de FireEffects, cuyas utilidades se reutilizan aquí.

const BOLT_DAMAGE: int = 1
const BOLT_DISCARD: int = 1
const BLIZZARD_DAMAGE: int = 1
const BLIZZARD_DISCARD: int = 1
const BOOMERANG_TARGET_DAMAGE: int = 3
const BOOMERANG_CASTER_DAMAGE: int = 1
const VAMPIRIC_DAMAGE: int = 2
const VAMPIRIC_HEAL: int = 1
const FREEZE_TURNS: int = 1
const GRASP_DAMAGE: int = 2

## Reveal (Types.make_reveal) que recibe quien roba con Icy Grasp.
const REVEAL_KIND_CARD: String = "card"


## Ice Bolt: el objetivo pierde 1💖 y descarta 1 carta (Damage.forced_discard:
## elige él si tiene más; sin cartas, pierde 1💧).
static func ice_bolt(state: Dictionary, ctx: Dictionary) -> Dictionary:
	var target: String = FireEffects.main_target(ctx)
	if not FireEffects.is_alive(state, target):
		return FireEffects.fizzle(state, ctx)
	FireEffects.hit(state, ctx, target, BOLT_DAMAGE)
	_discard(state, ctx, target, BOLT_DISCARD)
	return state


## Blizzard: el objetivo y sus vecinos vivos pierden 1💖; después, cada
## afectado que siga vivo descarta 1 carta.
static func blizzard(state: Dictionary, ctx: Dictionary) -> Dictionary:
	var target: String = FireEffects.main_target(ctx)
	if not FireEffects.is_alive(state, target):
		return FireEffects.fizzle(state, ctx)
	var affected: Array[String] = [target]
	affected.append_array(Types.neighbors(state, target))
	for pid: String in affected:
		FireEffects.hit(state, ctx, pid, BLIZZARD_DAMAGE)
	for pid: String in affected:
		_discard(state, ctx, pid, BLIZZARD_DISCARD)
	return state


## Ice Boomerang: el objetivo pierde 3💖 y el lanzador 1💖 (ambos daños de
## hielo del hechizo; si se apunta a sí mismo recibe los dos).
static func ice_boomerang(state: Dictionary, ctx: Dictionary) -> Dictionary:
	var target: String = FireEffects.main_target(ctx)
	if not FireEffects.is_alive(state, target):
		return FireEffects.fizzle(state, ctx)
	FireEffects.hit(state, ctx, target, BOOMERANG_TARGET_DAMAGE)
	FireEffects.hit(state, ctx, String(ctx["caster"]), BOOMERANG_CASTER_DAMAGE)
	return state


## Vampiric Touch: el objetivo pierde 2💖 y el lanzador gana 1💖 (literal: la
## curación no depende del daño realmente causado).
static func vampiric_touch(state: Dictionary, ctx: Dictionary) -> Dictionary:
	var target: String = FireEffects.main_target(ctx)
	if not FireEffects.is_alive(state, target):
		return FireEffects.fizzle(state, ctx)
	FireEffects.hit(state, ctx, target, VAMPIRIC_DAMAGE)
	var caster: String = ctx["caster"]
	Damage.heal(state, caster, VAMPIRIC_HEAL, ctx["events"], caster, FireEffects.card_id(ctx))
	return state


## Freeze: el objetivo pierde su próximo turno (flags.frozen += 1; Game lo
## consume al empezar su turno). Varios Freeze se acumulan.
static func freeze(state: Dictionary, ctx: Dictionary) -> Dictionary:
	var target: String = FireEffects.main_target(ctx)
	if not FireEffects.is_alive(state, target) or FireEffects.immune(state, ctx, target):
		return FireEffects.fizzle(state, ctx)
	var flags: Dictionary = Types.get_player(state, target)["flags"]
	flags["frozen"] = int(flags["frozen"]) + FREEZE_TURNS
	FireEffects.log_effect(state, ctx, "frozen", {"target": target, "frozen": int(flags["frozen"])})
	return state


## Icy Grasp: el objetivo pierde 2💖 y el lanzador le roba una carta al azar
## de la mano (Rng con state.rng_state). "You can steal": se roba salvo que la
## acción lleve extra.steal = false. La carta robada solo la ven el lanzador
## (state.reveals[caster] + log privado) y el robado (log privado); el log
## público solo dice que hubo robo.
static func icy_grasp(state: Dictionary, ctx: Dictionary) -> Dictionary:
	var target: String = FireEffects.main_target(ctx)
	if not FireEffects.is_alive(state, target):
		return FireEffects.fizzle(state, ctx)
	FireEffects.hit(state, ctx, target, GRASP_DAMAGE)
	var caster: String = ctx["caster"]
	var extra: Dictionary = ctx["extra"]
	if not bool(extra.get("steal", true)) or target == caster:
		return state
	if not FireEffects.is_alive(state, target) or not FireEffects.is_alive(state, caster) \
			or FireEffects.immune(state, ctx, target):
		return state
	var victim: Dictionary = Types.get_player(state, target)
	var hand: Array = victim["hand"]
	if hand.is_empty():
		FireEffects.log_effect(state, ctx, "steal_empty", {"target": target})
		return state
	var r: Dictionary = Rng.next_int(int(state["rng_state"]), hand.size())
	state["rng_state"] = int(r["state"])
	var stolen: Dictionary = hand[int(r["value"])]
	hand.remove_at(int(r["value"]))
	(Types.get_player(state, caster)["hand"] as Array).append(stolen)
	var turn: int = Damage.turn_no(state)
	var reveals: Dictionary = state["reveals"]
	if not reveals.has(caster):
		reveals[caster] = []
	(reveals[caster] as Array).append(Types.make_reveal(REVEAL_KIND_CARD, target, [stolen], turn))
	FireEffects.log_effect(state, ctx, "card_stolen", {"target": target})
	FireEffects.log_effect(state, ctx, "card_stolen_private", {"target": target,
		"iid": int(stolen["iid"]), "stolen_card_id": String(stolen["card_id"])}, [caster, target])
	return state


static func _discard(state: Dictionary, ctx: Dictionary, pid: String, count: int) -> void:
	if not FireEffects.is_alive(state, pid) or FireEffects.immune(state, ctx, pid):
		return
	Damage.forced_discard(state, pid, count, ctx["events"], FireEffects.card_id(ctx))

class_name FireEffects
extends RefCounted
## Efectos ofensivos de fuego (T6a) y utilidades compartidas por los efectos
## ofensivos de hielo (IceEffects) y electricidad (ElectricEffects).
##
## Firma de cada efecto: static func id(state: Dictionary, ctx: Dictionary) -> Dictionary
## (ver EffectRegistry). Todos MUTAN `state` (copia de trabajo del reducer) y
## lo devuelven.
##
## Reglas comunes de T6a:
##  * TODO el daño pasa por Damage.resolve() con el elemento de la carta,
##    is_spell de la definición y spell_iid = iid de la carta, para que los
##    modificadores (artefactos, eventos, defensivas) actúen sin que estos
##    efectos los conozcan.
##  * Objetivo principal eliminado al resolverse → el hechizo no hace nada
##    (LOG_EFFECT what="fizzled"). Un objetivo secundario eliminado (vecino,
##    segundo objetivo de Electric Arc…) simplemente se ignora.
##  * Vecinos = Types.neighbors(): jugadores VIVOS adyacentes en orden de turno,
##    calculados antes de aplicar el daño al objetivo.
##  * Los efectos que no son daño (descartes, Freeze, Blinding Flash, robo) no
##    se aplican a un mago inmune por Force Field (flags.force_field != "").


const ARROW_DAMAGE: int = 1
const FIREBALL_DAMAGE: int = 2
const METEOR_TARGET_DAMAGE: int = 2
const METEOR_NEIGHBOR_DAMAGE: int = 1
const ARMAGEDDON_DAMAGE: int = 3
const IMPLOSION_DAMAGE: int = 2
const IMPLOSION_MANA: int = 2


# =============================================================================
# Cartas de fuego
# =============================================================================

## Fire Arrow: el objetivo pierde 1💖.
static func fire_arrow(state: Dictionary, ctx: Dictionary) -> Dictionary:
	return single_damage(state, ctx, ARROW_DAMAGE)


## Fireball: el objetivo pierde 2💖.
static func fireball(state: Dictionary, ctx: Dictionary) -> Dictionary:
	return single_damage(state, ctx, FIREBALL_DAMAGE)


## Meteor Shower: el objetivo pierde 2💖 y sus vecinos vivos 1💖 (el lanzador
## también, si es vecino del objetivo).
static func meteor_shower(state: Dictionary, ctx: Dictionary) -> Dictionary:
	var target: String = main_target(ctx)
	if not is_alive(state, target):
		return fizzle(state, ctx)
	var around: Array[String] = Types.neighbors(state, target)
	hit(state, ctx, target, METEOR_TARGET_DAMAGE)
	for pid: String in around:
		hit(state, ctx, pid, METEOR_NEIGHBOR_DAMAGE)
	return state


## Armageddon: todos los magos vivos (incluido el lanzador) pierden 3💖, en
## orden de asiento. Si todos llegan a 0, la partida acaba en empate (T4).
static func armageddon(state: Dictionary, ctx: Dictionary) -> Dictionary:
	for pid: String in area_targets(state, ctx, true):
		hit(state, ctx, pid, ARMAGEDDON_DAMAGE)
	return state


## Mana Implosion: el objetivo pierde 2💖 y 2💧 (la pérdida de maná va por
## Damage.lose_mana: faltante → prompt de poción, regla 1.3).
static func mana_implosion(state: Dictionary, ctx: Dictionary) -> Dictionary:
	var target: String = main_target(ctx)
	if not is_alive(state, target):
		return fizzle(state, ctx)
	hit(state, ctx, target, IMPLOSION_DAMAGE)
	if is_alive(state, target) and not immune(state, ctx, target):
		Damage.lose_mana(state, target, IMPLOSION_MANA, ctx["events"], String(ctx["caster"]),
			card_id(ctx), card_iid(ctx))
	return state


# =============================================================================
# Utilidades compartidas (T6a: fuego, hielo, electricidad)
# =============================================================================

## Daño simple al objetivo principal (o nada si ya está eliminado).
static func single_damage(state: Dictionary, ctx: Dictionary, amount: int) -> Dictionary:
	var target: String = main_target(ctx)
	if not is_alive(state, target):
		return fizzle(state, ctx)
	hit(state, ctx, target, amount)
	return state


## Inflige `amount` de daño del hechizo de ctx a pid por Damage.resolve().
## source = quien causa el daño (por defecto ctx.caster). Devuelve el evento
## final (amount = daño aplicado, data.dealt = vida perdida).
static func hit(state: Dictionary, ctx: Dictionary, pid: String, amount: int, source: String = "") -> Dictionary:
	var def: Dictionary = ctx["def"]
	var src: String = source if source != "" else String(ctx["caster"])
	var ev: Dictionary = Types.make_mod_event(Damage.KIND_DAMAGE, amount, src, pid,
		String(def.get("element", Types.ELEMENT_NONE)), card_id(ctx), card_iid(ctx),
		bool(def.get("is_spell", true)))
	return Damage.resolve(state, ev, ctx["events"])


## Primer objetivo de ctx ("" si no hay).
static func main_target(ctx: Dictionary) -> String:
	var ts: Array = ctx["targets"]
	if ts.is_empty():
		return ""
	return String(ts[0])


## Objetivos vivos de un hechizo de área, en orden de asiento. Usa ctx.targets
## si viene relleno (lo calcula Game al jugar) y, si no, todos los vivos
## (con o sin el lanzador según include_caster).
static func area_targets(state: Dictionary, ctx: Dictionary, include_caster: bool) -> Array[String]:
	var caster: String = ctx["caster"]
	var wanted: Array = ctx["targets"]
	var out: Array[String] = []
	for pid: String in Types.alive_ids(state):
		if not include_caster and pid == caster:
			continue
		if wanted.is_empty() or wanted.has(pid):
			out.append(pid)
	return out


static func is_alive(state: Dictionary, pid: String) -> bool:
	if pid == "":
		return false
	var p: Dictionary = Types.get_player(state, pid)
	return not p.is_empty() and not bool(p["eliminated"])


## ¿pid es inmune a los efectos de este hechizo (Force Field)?
static func immune(state: Dictionary, ctx: Dictionary, pid: String) -> bool:
	var def: Dictionary = ctx["def"]
	if not bool(def.get("is_spell", true)):
		return false
	var p: Dictionary = Types.get_player(state, pid)
	return not p.is_empty() and String((p["flags"] as Dictionary)["force_field"]) != ""


static func card_id(ctx: Dictionary) -> String:
	var card: Dictionary = ctx["card"]
	return String(card.get("card_id", ""))


static func card_iid(ctx: Dictionary) -> int:
	var card: Dictionary = ctx["card"]
	return int(card.get("iid", -1))


## Registra un LOG_EFFECT de la carta de ctx.
static func log_effect(state: Dictionary, ctx: Dictionary, what: String, data: Dictionary = {},
		visible_to: Array = []) -> void:
	var d: Dictionary = data.duplicate(true)
	d["card_id"] = card_id(ctx)
	d["what"] = what
	(ctx["events"] as Array).append(Types.make_log_entry(Types.LOG_EFFECT, Damage.turn_no(state),
		String(ctx["caster"]), d, visible_to))


## El hechizo no tiene efecto (objetivo principal eliminado o inexistente).
static func fizzle(state: Dictionary, ctx: Dictionary) -> Dictionary:
	log_effect(state, ctx, "fizzled", {"targets": (ctx["targets"] as Array).duplicate()})
	return state

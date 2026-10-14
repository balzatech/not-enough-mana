class_name Modifiers
extends RefCounted
## Tubería genérica de modificadores (parte del contrato T1).
##
## Los modificadores son DATOS en state["modifiers"] (ver Types.make_modifier).
## Quien calcula un daño, coste, poción o límite de mano crea un evento con
## Types.make_mod_event() y lo pasa por las etapas con run_stage(). Quien crea
## un modificador (artefacto, evento, defensiva) solo hace add(). Así fuego/
## hielo/electricidad, defensivas y artefactos/eventos no dependen entre sí.
##
## Convención de mutación: estas funciones MUTAN `state` en sitio (es la copia
## de trabajo del reducer, que hace duplicate(true) una sola vez al entrar).
##
## Orden dentro de una etapa: priority ascendente y, a igualdad, orden de
## inserción en state.modifiers.
##
## Ejemplo de daño (lo implementa Damage, T4):
##   var ev: Dictionary = Types.make_mod_event("damage", 2, caster, target,
##       Types.ELEMENT_FIRE, Types.CARD_FIREBALL, spell_iid, true)
##   ev = Modifiers.run_stages(state, Types.DAMAGE_STAGES, ev)
##   # ... aplicar ev.amount a target y ev.redirects a sus destinos ...
##   ev = Modifiers.run_stage(state, Types.STAGE_AFTER_DAMAGE, ev)


## Añade un modificador. Si ya existe uno con el mismo id, lo reemplaza.
static func add(state: Dictionary, mod: Dictionary) -> void:
	var mods: Array = state["modifiers"]
	for i: int in mods.size():
		var m: Dictionary = mods[i]
		if m["id"] == mod["id"]:
			mods[i] = mod
			return
	mods.append(mod)


## Quita el modificador con ese id. Devuelve true si existía.
static func remove(state: Dictionary, mod_id: String) -> bool:
	var mods: Array = state["modifiers"]
	for i: int in mods.size():
		var m: Dictionary = mods[i]
		if m["id"] == mod_id:
			mods.remove_at(i)
			return true
	return false


## Quita todos los modificadores creados por la carta `iid` (p. ej. al
## destruir un artefacto con Annihilation). Devuelve cuántos quitó.
static func remove_by_source(state: Dictionary, iid: int) -> int:
	return _remove_where(state, func(m: Dictionary) -> bool: return int(m["source_iid"]) == iid)


## Quita los modificadores con esa caducidad. Si owner != "", solo los de ese
## dueño; si spell_iid >= 0, solo los ligados a ese hechizo.
## Llamadas previstas (las hace T4/T6b):
##   expire(state, EXPIRES_NEXT_EVENT)               al robar un evento nuevo
##   expire(state, EXPIRES_OWNER_TURN_START, pid)    al empezar el turno de pid
##   expire(state, EXPIRES_END_OF_TURN)              al terminar cada turno
##   expire(state, EXPIRES_SPELL, "", spell_iid)     al resolver/cancelar un hechizo
static func expire(state: Dictionary, expires: String, owner: String = "", spell_iid: int = -1) -> int:
	return _remove_where(state, func(m: Dictionary) -> bool:
		if m["expires"] != expires:
			return false
		if owner != "" and m["owner"] != owner:
			return false
		if spell_iid >= 0 and int(m["spell_iid"]) != spell_iid:
			return false
		return true)


## Modificadores de la etapa que aplican al evento, ya ordenados.
static func matching(state: Dictionary, stage: String, event: Dictionary) -> Array:
	var found: Array = []
	var mods: Array = state["modifiers"]
	for i: int in mods.size():
		var m: Dictionary = mods[i]
		if m["stage"] == stage and applies_to(m, event):
			found.append([int(m["priority"]), i, m])
	found.sort_custom(func(x: Array, y: Array) -> bool:
		if x[0] != y[0]:
			return int(x[0]) < int(y[0])
		return int(x[1]) < int(y[1]))
	var out: Array = []
	for f: Array in found:
		out.append(f[2])
	return out


## ¿El modificador aplica a este evento? (sin mirar la etapa)
static func applies_to(m: Dictionary, event: Dictionary) -> bool:
	var el: String = m["element"]
	if el != "" and el != event["element"]:
		return false
	if bool(m["spell_only"]) and not bool(event["is_spell"]):
		return false
	var siid: int = m["spell_iid"]
	if siid >= 0 and siid != int(event["spell_iid"]):
		return false
	match String(m["side"]):
		Types.SIDE_SOURCE:
			return event["source"] == m["owner"]
		Types.SIDE_TARGET:
			return event["target"] == m["owner"]
		_:
			return true


## Ejecuta una etapa sobre el evento y devuelve el evento modificado (copia).
## Los modificadores EXPIRES_ONCE aplicados se eliminan de state.
static func run_stage(state: Dictionary, stage: String, event: Dictionary) -> Dictionary:
	var ev: Dictionary = event.duplicate(true)
	var consumed: Array[String] = []
	for m: Variant in matching(state, stage, ev):
		var md: Dictionary = m
		ev = apply_op(state, md, ev)
		(ev["applied"] as Array).append(md["id"])
		if md["expires"] == Types.EXPIRES_ONCE:
			consumed.append(String(md["id"]))
	for id: String in consumed:
		remove(state, id)
	return ev


## Ejecuta varias etapas en orden (p. ej. Types.DAMAGE_STAGES).
static func run_stages(state: Dictionary, stages: Array, event: Dictionary) -> Dictionary:
	var ev: Dictionary = event
	for st: Variant in stages:
		ev = run_stage(state, String(st), ev)
	return ev


## Aplica la operación de un modificador al evento (muta y devuelve `ev`).
static func apply_op(state: Dictionary, m: Dictionary, ev: Dictionary) -> Dictionary:
	var amount: int = ev["amount"]
	var value: int = m["value"]
	match String(m["op"]):
		Types.OP_ADD:
			ev["amount"] = amount + value
		Types.OP_SUB:
			var removed: int = mini(value, amount)
			ev["amount"] = amount - removed
			ev["prevented"] = int(ev["prevented"]) + removed
		Types.OP_MUL:
			ev["amount"] = amount * value
		Types.OP_SET:
			ev["amount"] = value
		Types.OP_PREVENT_ALL:
			ev["prevented"] = int(ev["prevented"]) + amount
			ev["amount"] = 0
		Types.OP_REDIRECT:
			var moved: int = mini(value, amount)
			if moved > 0:
				ev["amount"] = amount - moved
				var data: Dictionary = m["data"]
				(ev["redirects"] as Array).append({"to": String(data.get("to", "")), "amount": moved})
		Types.OP_CUSTOM:
			var h: Callable = EffectRegistry.get_modifier_handler(String(m["handler"]))
			if h.is_valid():
				ev = h.call(state, m, ev)
	return ev


static func _remove_where(state: Dictionary, pred: Callable) -> int:
	var mods: Array = state["modifiers"]
	var kept: Array = []
	var removed: int = 0
	for m: Variant in mods:
		if bool(pred.call(m)):
			removed += 1
		else:
			kept.append(m)
	mods.clear()
	mods.append_array(kept)
	return removed

class_name ReactionRelevance
extends RefCounted
## "Me afecta": política de interfaz para la preferencia "Avisarme de reacciones"
## (docs/diseno/preferencia-reaccion.md, docs/TECNICO/preferencia-reaccion-y-resumen.md §1.4).
## Funciones estáticas puras sobre un estado o una vista pública: solo lee
## spell, stack, targets, caster, jugadores (edad, mes, vida, vivos) y mesa.
## Una entrada explícita por carta jugable. Carta sin entrada = avisar (duda).

const MODE_AFFECTING: String = "affecting"
const MODE_ALL: String = "all"

const R_TARGETS: String = "targets"
const R_TARGETS_AND_CASTER: String = "targets_and_caster"
const R_AREA: String = "area"
const R_ALL: String = "all"
const R_ALL_OTHERS: String = "all_others"
const R_CONDITION: String = "condition"
const R_EVERYONE: String = "everyone"
const R_CARD_OWNER: String = "card_owner"
const R_REFLECT: String = "reflect_caster"
const R_REDIRECT: String = "redirect"
const R_NONE: String = "none"

const RULES: Dictionary = {
	# Ofensivas
	Types.CARD_FIRE_ARROW: R_TARGETS,
	Types.CARD_FIREBALL: R_TARGETS,
	Types.CARD_METEOR_SHOWER: R_AREA,
	Types.CARD_ARMAGEDDON: R_ALL,
	Types.CARD_MANA_IMPLOSION: R_TARGETS,
	Types.CARD_ICE_BOLT: R_TARGETS,
	Types.CARD_BLIZZARD: R_AREA,
	Types.CARD_ICE_BOOMERANG: R_TARGETS_AND_CASTER,
	Types.CARD_VAMPIRIC_TOUCH: R_TARGETS,
	Types.CARD_FREEZE: R_TARGETS,
	Types.CARD_ICY_GRASP: R_TARGETS,
	Types.CARD_LIGHTNING: R_TARGETS,
	Types.CARD_ELECTRIC_EXPLOSION: R_ALL_OTHERS,
	Types.CARD_BLINDING_FLASH: R_TARGETS,
	Types.CARD_ELECTRIC_ARC: R_TARGETS,
	Types.CARD_PARALYSING_TOUCH: R_TARGETS,
	# Defensivas
	Types.CARD_MAGIC_SHIELD: R_NONE,
	Types.CARD_MIRROR_SHIELD: R_REDIRECT,
	Types.CARD_FROZEN_BUNNY: R_NONE,
	Types.CARD_LAST_WISH: R_REFLECT,
	Types.CARD_MAGIC_CAPTURE: R_NONE,
	Types.CARD_ANNIHILATION: R_CARD_OWNER,
	# Soporte (las curas ajenas no cuentan: decision por defecto del Game Designer)
	Types.CARD_HEAL: R_NONE,
	Types.CARD_GREATER_HEAL: R_NONE,
	Types.CARD_BOOK_EXCHANGE: R_TARGETS,
	Types.CARD_MAGIC_HAND: R_TARGETS,
	Types.CARD_FORCE_FIELD: R_NONE,
	Types.CARD_POTENT_ELIXIR: R_NONE,
	Types.CARD_SPACE_SHIFT: R_NONE,
	# Maldiciones
	Types.CARD_CURSE_OF_RULES: R_EVERYONE,
	Types.CARD_CURSE_OF_THE_ELDER: R_CONDITION,
	Types.CARD_CURSE_OF_THE_YOUNGER: R_CONDITION,
	Types.CARD_CURSE_OF_VIGOUR: R_CONDITION,
	Types.CARD_CURSE_OF_EVEN: R_CONDITION,
	Types.CARD_CURSE_OF_ODD: R_CONDITION,
	# Artefactos (no se juegan en ventana)
	Types.CARD_FIREPROOF_TIARA: R_NONE,
	Types.CARD_PADDED_BOOTS: R_NONE,
	Types.CARD_FARADAYS_CLOAK: R_NONE,
	Types.CARD_WILD_FIRE: R_NONE,
	Types.CARD_DRAGON_GLASS: R_NONE,
	Types.CARD_TESLA_COIL: R_NONE,
	Types.CARD_SPELLBOOK: R_NONE,
	Types.CARD_MAGIC_CAP: R_NONE,
	Types.CARD_RUNIC_ARMOR: R_NONE,
	Types.CARD_SCROLL_OF_ELEMENTS: R_NONE,
	Types.CARD_TRANSFORMATION_GLOVE: R_NONE,
	Types.CARD_TWARDOWSKYS_MIRROR: R_NONE,
	# Eventos (no se juegan en ventana)
	Types.CARD_VISIT_OF_THE_ARCHMAGE: R_NONE,
	Types.CARD_NOT_ENOUGH_MANA: R_NONE,
	Types.CARD_SHOT_GLASS: R_NONE,
	Types.CARD_FIRE_STORM: R_NONE,
	Types.CARD_ICE_STORM: R_NONE,
	Types.CARD_LIGHTNING_STORM: R_NONE,
	Types.CARD_MANA_FOCUS: R_NONE,
	Types.CARD_DISRUPTED_GRAVITY: R_NONE,
	Types.CARD_BLESSING: R_NONE,
	Types.CARD_WARP_DISCHARGE: R_NONE,
	Types.CARD_ELIXIR_TRANSMUTATION: R_NONE,
}


static func has_rule(card_id: String) -> bool:
	return RULES.has(card_id)


## Regla de una carta ("" si no tiene).
static func rule_of(card_id: String) -> String:
	return String(RULES.get(card_id, ""))


## Receptores (pids vivos, sin repetir, en orden de asiento) de UNA carta
## (hechizo o respuesta). Sin regla o con datos que no se pueden resolver
## devuelve todos los vivos (duda: avisar a todos).
static func receivers(view: Dictionary, spell: Dictionary) -> Array[String]:
	var alive: Array[String] = Types.alive_ids(view)
	if spell.is_empty():
		return []
	var card: Dictionary = spell.get("card", {}) as Dictionary
	var card_id: String = String(card.get("card_id", ""))
	if not RULES.has(card_id):
		return alive
	var caster: String = String(spell.get("caster", ""))
	var targets: Array = spell.get("targets", []) as Array
	var seen: Array[String] = []
	match String(RULES[card_id]):
		R_NONE:
			pass
		R_TARGETS, R_REDIRECT:
			_add_all(seen, targets)
		R_TARGETS_AND_CASTER:
			_add_all(seen, targets)
			_add(seen, caster)
		R_AREA:
			_add_all(seen, targets)
			for t: Variant in targets:
				_add_all(seen, Types.neighbors(view, String(t)))
		R_ALL, R_EVERYONE:
			return alive
		R_ALL_OTHERS:
			for pid: String in alive:
				if pid != caster:
					seen.append(pid)
		R_CONDITION:
			var me: Dictionary = Types.get_player(view, caster)
			if me.is_empty():
				return alive
			for pid: String in alive:
				if _meets(card_id, Types.get_player(view, pid), me):
					seen.append(pid)
		R_CARD_OWNER:
			var owner: Variant = _owner_of_card(view, int(spell.get("target_card", -1)))
			if owner == null:
				return alive
			_add(seen, String(owner))
		R_REFLECT:
			var rt: Dictionary = Reactions.find_spell(view, int((spell.get("data", {}) as Dictionary).get("responds_to", -1)))
			if rt.is_empty():
				return alive
			_add(seen, String(rt.get("caster", "")))
		_:
			return alive
	var out: Array[String] = []
	for pid: String in alive:
		if seen.has(pid):
			out.append(pid)
	return out


## ¿Me afecta (pid) el conjunto spell + stack no cancelado? false sin ventana.
## Carta sin regla: true (duda).
static func affects(view: Dictionary, pid: String) -> bool:
	var re: Dictionary = view.get("reaction", {}) as Dictionary
	if re.is_empty():
		return false
	var all: Array = [re.get("spell", {})]
	all.append_array(re.get("stack", []) as Array)
	for x: Variant in all:
		var sd: Dictionary = x as Dictionary
		if sd.is_empty() or bool(sd.get("cancelled", false)):
			continue
		var card_id: String = String((sd.get("card", {}) as Dictionary).get("card_id", ""))
		if not RULES.has(card_id):
			return true
		if receivers(view, sd).has(pid):
			return true
	return false


## PASS_REACTION que la sesión envía por un humano local al que no le afecta
## el hechizo, o {} si debe avisarse. Nunca auto-pasa un prompt pendiente.
static func auto_pass_action(view: Dictionary, local_ids: Array[String], mode: String) -> Dictionary:
	if mode != MODE_AFFECTING:
		return {}
	if (view.get("reaction", {}) as Dictionary).is_empty():
		return {}
	var resp: String = Decision.responder(view)
	if resp == "" or Decision.decider(view) != resp or not local_ids.has(resp):
		return {}
	for pr: Variant in view.get("pending", []) as Array:
		if String((pr as Dictionary).get("player", "")) == resp:
			return {}  # nunca se auto-pasa con un PROMPT_* propio pendiente (R14)
	if affects(view, resp):
		return {}
	return Types.make_action_pass_reaction(resp)


# -----------------------------------------------------------------------------

static func _add(seen: Array[String], pid: String) -> void:
	if pid != "" and not seen.has(pid):
		seen.append(pid)


static func _add_all(seen: Array[String], ids: Array) -> void:
	for x: Variant in ids:
		_add(seen, String(x))


static func _meets(card_id: String, p: Dictionary, me: Dictionary) -> bool:
	match card_id:
		Types.CARD_CURSE_OF_THE_ELDER:
			return int(p["age"]) > int(me["age"])
		Types.CARD_CURSE_OF_THE_YOUNGER:
			return int(p["age"]) < int(me["age"])
		Types.CARD_CURSE_OF_VIGOUR:
			return int(p["hp"]) >= int(me["hp"])
		Types.CARD_CURSE_OF_EVEN:
			return int(p["birth_month"]) % 2 == 0
		Types.CARD_CURSE_OF_ODD:
			return int(p["birth_month"]) % 2 == 1
	return true


## Dueño de la carta con ese iid: carta en mesa (owner o jugador que la tiene),
## hechizo/respuesta en la pila (su lanzador). null si no se encuentra o no
## se encuentra; "" si es el evento activo (sin dueño).
static func _owner_of_card(view: Dictionary, iid: int) -> Variant:
	if iid < 0:
		return null
	for p: Variant in Types.players_of(view):
		var pd: Dictionary = p
		for zone: String in ["artifacts", "curses"]:
			for c: Variant in pd.get(zone, []) as Array:
				if int((c as Dictionary).get("iid", -2)) == iid:
					return String(pd["id"])
	var sp: Dictionary = Reactions.find_spell(view, iid)
	if not sp.is_empty():
		return String(sp.get("caster", ""))
	var ev: Dictionary = view.get("active_event", {}) as Dictionary
	if not ev.is_empty() and int(ev.get("iid", -2)) == iid:
		return ""  # evento del centro: sin dueño, no afecta a nadie en concreto
	return null

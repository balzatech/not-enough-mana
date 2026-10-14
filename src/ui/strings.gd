class_name Strings
extends RefCounted
## Textos de interfaz de v0.2 en español (V2-08, Narrative Designer).
##
## API de solo funciones estáticas y constantes: reciben datos (eventos del log,
## nombres, números) y devuelven texto. No leen la sesión ni tocan nodos, así que
## se prueban sin escena. Reglas de estilo (ver docs/narrativa/textos-ui-v02.md):
##  * Los nombres de carta y de evento se quedan en inglés (catálogo); el texto
##    original de las cartas no se traduce ni se reescribe (© SUPERHOTEX).
##  * Nunca sale una clave interna ni un "_"; los plurales son correctos.
##  * Los nombres de mago llegan en `names` (pid -> nombre).
## Grupos: 1 ayudantes, 2 registro, 3 pistas, 4 motivos de "no jugable" y ficha,
## 5 pago y descarte, 6 errores de reglas, 7 prompts, 8 reacción y "contra ti",
## 9 "Pasa el dispositivo", 10 fin de partida.


# =============================================================================
# 1. Ayudantes
# =============================================================================

## "carta" / "cartas" según n (1 carta, 2 cartas, 0 cartas).
static func cards(n: int) -> String:
	return "%d %s" % [n, "carta" if n == 1 else "cartas"]


## "1 mago" / "3 magos".
static func mages(n: int) -> String:
	return "%d %s" % [n, "mago" if n == 1 else "magos"]


## Nombre de carta tal como sale del catálogo (inglés). Si no existe, se
## humaniza el id ("fire_arrow" -> "Fire Arrow"): nunca se muestra una clave.
static func card_name(card_id: String) -> String:
	if card_id == "":
		return "una carta"
	var def: Dictionary = CardCatalog.get_def(card_id)
	if not def.is_empty():
		return String(def.get("name", card_id))
	return card_id.replace("_", " ").capitalize()


## Nombre de mago; "alguien" si no se conoce.
static func mage(names: Dictionary, pid: String) -> String:
	var n: String = String(names.get(pid, ""))
	return n if n != "" else "alguien"


## "A", "A y B", "A, B y C".
static func join_list(items: Array) -> String:
	var parts: Array[String] = []
	for i: Variant in items:
		parts.append(String(i))
	if parts.is_empty():
		return ""
	if parts.size() == 1:
		return parts[0]
	var last: String = String(parts.pop_back())
	return "%s y %s" % [", ".join(parts), last]


## Nombres de una lista de pid; con más de 3, solo cuántos.
static func mage_list(names: Dictionary, pids: Array) -> String:
	if pids.size() > 3:
		return mages(pids.size())
	var out: Array[String] = []
	for p: Variant in pids:
		out.append(mage(names, String(p)))
	return join_list(out)


static func type_name(card_type: String) -> String:
	match card_type:
		Types.CARD_TYPE_OFFENSIVE:
			return "ofensiva"
		Types.CARD_TYPE_DEFENSIVE:
			return "defensiva"
		Types.CARD_TYPE_SUPPORT:
			return "apoyo"
		Types.CARD_TYPE_CURSE:
			return "maldición"
		Types.CARD_TYPE_ARTIFACT:
			return "artefacto"
		Types.CARD_TYPE_EVENT:
			return "evento"
	return "carta"


static func element_name(element: String) -> String:
	match element:
		Types.ELEMENT_FIRE:
			return "fuego"
		Types.ELEMENT_ICE:
			return "hielo"
		Types.ELEMENT_ELECTRIC:
			return "electricidad"
	return "sin elemento"


# =============================================================================
# 2. Registro de partida
# =============================================================================
## `log_text(entry, names)` devuelve una línea para cada Types.LOG_* y, para
## LOG_EFFECT, para cada data.what. `names`: pid -> nombre. Los datos que falta
## el motor ponerlos son opcionales: el texto se degrada sin dejar claves.

const LOG_TYPES: Array[String] = [
	Types.LOG_GAME_STARTED, Types.LOG_TURN_STARTED, Types.LOG_TURN_SKIPPED, Types.LOG_CARD_DRAWN,
	Types.LOG_EVENT_DRAWN, Types.LOG_DECK_RESHUFFLED, Types.LOG_CARD_PLAYED, Types.LOG_CARD_DISCARDED,
	Types.LOG_EXCHANGE, Types.LOG_POTION, Types.LOG_DAMAGE, Types.LOG_HEAL, Types.LOG_MANA_CHANGED,
	Types.LOG_REACTION_OPENED, Types.LOG_REACTION_PASSED, Types.LOG_REACTED, Types.LOG_SPELL_RESOLVED,
	Types.LOG_SPELL_CANCELLED, Types.LOG_RULE_BROKEN, Types.LOG_ELIMINATED, Types.LOG_GAME_OVER,
	Types.LOG_EFFECT,
]

## Todos los `what` de LOG_EFFECT que emite el motor (para el test de cobertura).
const EFFECT_WHATS: Array[String] = [
	"fizzled", "used_as_payment", "rule_established", "peeked_deck", "peeked_card",
	"next_potion_doubled", "loss_avoided", "immune", "last_wish", "hands_exchanged", "hand_seen",
	"hand_cards", "drank_to_avoid", "curse_targets", "card_stolen", "card_stolen_detail",
	"card_stolen_private", "steal_empty", "lowest_mana", "blinded", "frozen", "frozen_bunny",
	"magic_shield", "force_field", "mirror_shield", "magic_capture", "annihilation",
	"lightning_redirected",
]

const LOG_GAME_STARTED_TEXT: String = "Empieza la partida."
const LOG_DECK_RESHUFFLED_TEXT: String = "Se acaba el mazo: se baraja el descarte."
const LOG_AUTO_PASS_TEXT: String = "Pasas: este hechizo no iba contra ti."


## Una línea de registro. `entry` es Types.make_log_entry.
static func log_text(entry: Dictionary, names: Dictionary) -> String:
	var data: Dictionary = entry.get("data", {}) as Dictionary
	var pid: String = String(entry.get("player", ""))
	var who: String = mage(names, pid)
	var card_id: String = String(data.get("card_id", ""))
	var card: String = card_name(card_id)
	match String(entry.get("type", "")):
		Types.LOG_GAME_STARTED:
			return LOG_GAME_STARTED_TEXT
		Types.LOG_TURN_STARTED:
			return "Turno %d: %s." % [int(entry.get("turn", 0)), who]
		Types.LOG_TURN_SKIPPED:
			return "%s pierde el turno por estar congelado." % who
		Types.LOG_CARD_DRAWN:
			if card_id != "":
				return "%s roba %s." % [who, card]
			return "%s roba una carta." % who
		Types.LOG_EVENT_DRAWN:
			return "%s saca el evento %s." % [who, card]
		Types.LOG_DECK_RESHUFFLED:
			return LOG_DECK_RESHUFFLED_TEXT
		Types.LOG_CARD_PLAYED:
			return _played_text(who, pid, card_id, data.get("targets", []) as Array, names)
		Types.LOG_CARD_DISCARDED:
			return _discarded_text(who, data)
		Types.LOG_EXCHANGE:
			var cost: int = int(data.get("cost", 0))
			var base: String = "%s cambia %s" % [who, card if card_id != "" else "una carta"]
			return base + (" (%d de maná)." % cost if cost > 0 else ".")
		Types.LOG_POTION:
			return _potion_text(who, data)
		Types.LOG_DAMAGE:
			return damage_text(data, pid, names)
		Types.LOG_HEAL:
			var healed: String = mage(names, String(data.get("target", pid)))
			var got: int = int(data.get("amount", 0))
			if got <= 0:
				return "%s ya tiene la vida al máximo." % healed
			return "%s recupera %d de vida." % [healed, got]
		Types.LOG_MANA_CHANGED:
			return mana_text(data, pid, names)
		Types.LOG_REACTION_OPENED:
			return "%s Hora de reaccionar." % spell_line(pid, card_id, data.get("targets", []) as Array, names)
		Types.LOG_REACTION_PASSED:
			return "%s pasa." % who
		Types.LOG_REACTED:
			return "%s responde con %s." % [who, card]
		Types.LOG_SPELL_RESOLVED:
			if bool(data.get("response", false)):
				return "%s de %s surte efecto." % [card, who]
			return "Se resuelve %s de %s." % [card, who]
		Types.LOG_SPELL_CANCELLED:
			return "Se cancela %s de %s." % [card, who]
		Types.LOG_RULE_BROKEN:
			var breaker: String = mage(names, String(data.get("target", "")))
			return "%s acusa a %s de romper la regla: pierde 1 de maná." % [who, breaker]
		Types.LOG_ELIMINATED:
			return _eliminated_text(who, String(data.get("reason", "")))
		Types.LOG_GAME_OVER:
			var winners: Array = data.get("winners", []) as Array
			if winners.is_empty():
				return "Fin de la partida: no queda ningún mago en pie."
			if winners.size() == 1:
				return "Fin de la partida. Gana %s." % mage(names, String(winners[0]))
			return "Fin de la partida. Ganan %s." % mage_list(names, winners)
		Types.LOG_EFFECT:
			return effect_text(entry, names)
	return "Pasa algo en la mesa."


## "Ana juega Fireball contra Bruno." / "Ana juega Heal sobre sí."
static func _played_text(who: String, pid: String, card_id: String, targets: Array, names: Dictionary) -> String:
	var card: String = card_name(card_id)
	if targets.is_empty():
		return "%s juega %s." % [who, card]
	return "%s juega %s %s." % [who, card, _toward(card_id, pid, targets, names)]


## "contra Bruno" / "sobre Cira" / "contra sí" / "contra 4 magos".
static func _toward(card_id: String, caster: String, targets: Array, names: Dictionary) -> String:
	var def: Dictionary = CardCatalog.get_def(card_id)
	var kind: String = String(def.get("type", ""))
	var prep: String = "contra" if kind == Types.CARD_TYPE_OFFENSIVE or kind == Types.CARD_TYPE_CURSE else "sobre"
	if targets.size() == 1 and String(targets[0]) == caster:
		return "%s sí" % prep
	return "%s %s" % [prep, mage_list(names, targets)]


## "Ana lanza Fireball contra Bruno." (también para el encabezado de la reacción).
static func spell_line(caster: String, card_id: String, targets: Array, names: Dictionary) -> String:
	var line: String = "%s lanza %s" % [mage(names, caster), card_name(card_id)]
	if targets.is_empty():
		return line + "."
	return "%s %s." % [line, _toward(card_id, caster, targets, names)]


static func _discarded_text(who: String, data: Dictionary) -> String:
	var ids: Array = data.get("card_ids", []) as Array
	var n: int = ids.size() if not ids.is_empty() else (data.get("cards", []) as Array).size()
	var what: String = cards(maxi(n, 1))
	if ids.size() == 1:
		what = card_name(String(ids[0]))
	if bool(data.get("setup_event", false)):
		return "%s descarta %s: era un evento y no vale en la mano inicial." % [who, what]
	if bool(data.get("forced", false)):
		var src: String = String(data.get("card_id", ""))
		return "%s descarta %s%s." % [who, what, " por %s" % card_name(src) if src != "" else ""]
	return "%s descarta %s." % [who, what]


static func _potion_text(who: String, data: Dictionary) -> String:
	var got: int = int(data.get("amount", 0))
	var n: int = int(data.get("potions", 0))
	if got <= 0:
		return "%s bebe la poción n.º %d y no gana nada de maná." % [who, n]
	return "%s bebe una poción y gana %d de maná (n.º %d)." % [who, got, n]


static func _eliminated_text(who: String, reason: String) -> String:
	match reason:
		Types.ELIM_TOO_MUCH_MANA:
			return "%s se pasa de pociones (Too Much Mana) y sale de la partida." % who
		Types.ELIM_CONCEDE:
			return "%s se rinde y sale de la partida." % who
	return "%s se queda sin vida y sale de la partida." % who


## LOG_DAMAGE: usa data.dealt (vida perdida) y data.prevented (daño evitado).
## entry.player es el origen del daño; data.target, quien lo recibe.
static func damage_text(data: Dictionary, source_pid: String, names: Dictionary) -> String:
	var target_pid: String = String(data.get("target", source_pid))
	var target: String = mage(names, target_pid)
	var dealt: int = int(data.get("dealt", data.get("amount", 0)))
	var prevented: int = int(data.get("prevented", 0))
	var card_id: String = String(data.get("card_id", ""))
	var origin: String = ""
	if card_id != "":
		origin = card_name(card_id)
		if source_pid != "" and source_pid != target_pid:
			origin = "%s, de %s" % [origin, mage(names, source_pid)]
		origin = " (%s)" % origin
	if String(data.get("kind", "")) == Damage.KIND_HP_LOSS:
		return "%s pierde %d de vida%s." % [target, dealt, origin]
	if dealt <= 0 and prevented > 0:
		return "%s evita %d de daño%s." % [target, prevented, origin]
	if dealt <= 0:
		return "%s no recibe daño%s." % [target, origin]
	if prevented > 0:
		return "%s recibe %d de daño%s; evita %d." % [target, dealt, origin, prevented]
	return "%s recibe %d de daño%s." % [target, dealt, origin]


## LOG_MANA_CHANGED: data.delta (+gana / -pierde) y data.target; data.missing
## es lo que no tenía (le obliga a beber o perder vida).
static func mana_text(data: Dictionary, source_pid: String, names: Dictionary) -> String:
	var target: String = mage(names, String(data.get("target", source_pid)))
	var delta: int = int(data.get("delta", 0))
	var missing: int = int(data.get("missing", 0))
	var card_id: String = String(data.get("card_id", ""))
	var origin: String = " (%s)" % card_name(card_id) if card_id != "" else ""
	var tail: String = "; le faltan %d" % missing if missing > 0 else ""
	if delta > 0:
		return "%s gana %d de maná%s." % [target, delta, origin]
	if delta < 0:
		return "%s pierde %d de maná%s%s." % [target, -delta, origin, tail]
	if missing > 0:
		return "%s no tiene maná que perder%s%s." % [target, origin, tail]
	return "%s se queda con el mismo maná%s." % [target, origin]


## LOG_EFFECT según data.what. entry.player = quien lanza (salvo en last_wish).
static func effect_text(entry: Dictionary, names: Dictionary) -> String:
	var data: Dictionary = entry.get("data", {}) as Dictionary
	var who: String = mage(names, String(entry.get("player", "")))
	var target_pid: String = String(data.get("target", ""))
	var target: String = mage(names, target_pid) if target_pid != "" else ""
	var card_id: String = String(data.get("card_id", ""))
	var card: String = card_name(card_id)
	match String(data.get("what", "")):
		"fizzled":
			return "%s no tiene efecto." % card
		"used_as_payment":
			return "%s usa su Scroll of Elements como pago de %s." % [who, card_name(String(data.get("for", "")))]
		"rule_established":
			return "Nueva regla de mesa: «%s»." % String(data.get("rule", ""))
		"peeked_deck":
			return "%s mira la carta de arriba del mazo." % who
		"peeked_card":
			return "Arriba del mazo está %s." % card_name(String(data.get("seen", "")))
		"next_potion_doubled":
			return "La próxima poción de %s vale el doble." % who
		"loss_avoided":
			return "%s descarta Magic Cap y evita la pérdida." % who
		"immune":
			var shield: String = " gracias a %s" % card_name(String(data.get("by", ""))) if String(data.get("by", "")) != "" else ""
			return "%s es inmune a %s%s." % [target if target != "" else who, card, shield]
		"last_wish":
			if target == "":
				return "%s prepara Last Wish." % who
			var amount: int = int(data.get("amount", 0))
			return "Last Wish de %s devuelve %d de daño a %s." % [who, amount, target]
		"hands_exchanged":
			return "%s intercambia la mano con %s." % [who, target]
		"hand_seen":
			return "%s mira la mano de %s." % [who, target]
		"hand_cards":
			var seen: Array[String] = []
			for c: Variant in data.get("seen", []) as Array:
				seen.append(card_name(String(c)))
			return "Mano de %s: %s." % [target, ", ".join(seen)]
		"drank_to_avoid":
			return "%s bebe una poción para evitar %s." % [who, card]
		"curse_targets":
			var hit: Array = data.get("targets", []) as Array
			if hit.is_empty():
				return "%s no afecta a nadie." % card
			return "%s afecta a %s." % [card, mage_list(names, hit)]
		"card_stolen":
			return "%s roba una carta a %s." % [who, target]
		"card_stolen_detail", "card_stolen_private":
			var key: String = "stolen" if data.has("stolen") else "stolen_card_id"
			return "%s se queda %s de %s." % [who, card_name(String(data.get(key, ""))), target]
		"steal_empty":
			return "%s no tiene cartas que robar." % target
		"lowest_mana":
			var low: Array = data.get("targets", []) as Array
			if low.is_empty():
				return "%s: nadie pierde vida." % card
			return "%s: %s, con menos maná, pierde vida." % [card, mage_list(names, low)]
		"blinded":
			return "%s queda cegado: no podrá lanzar ofensivas en su próximo turno." % target
		"frozen":
			var turns: int = int(data.get("frozen", 1))
			if turns > 1:
				return "%s queda congelado: pierde sus próximos %d turnos." % [target, turns]
			return "%s queda congelado: pierde su próximo turno." % target
		"magic_shield":
			return "%s protege a %s con Magic Shield: el daño baja en 2." % [who, target]
		"frozen_bunny":
			return "%s protege a %s con Frozen Bunny: no recibe daño de este hechizo." % [who, target]
		"mirror_shield":
			return "%s usa Mirror Shield: el daño contra %s pasa a %s." % [
				who, target, mage(names, String(data.get("to", "")))]
		"magic_capture":
			return "%s recupera %s del descarte con Magic Capture." % [
				who, card_name(String(data.get("stolen_card_id", "")))]
		"annihilation":
			var gone: String = card_name(String(data.get("target_card_id", "")))
			var owner_pid: String = String(data.get("owner", ""))
			if String(data.get("zone", "")) == "reaction":
				return "%s cancela %s con Annihilation." % [who, gone]
			if owner_pid != "" and owner_pid != String(entry.get("player", "")):
				return "%s destruye %s de %s con Annihilation." % [who, gone, mage(names, owner_pid)]
			return "%s destruye %s con Annihilation." % [who, gone]
		"force_field":
			var caster: String = mage(names, String(data.get("caster", "")))
			var shielded: String = target if target != "" else who
			if String(data.get("caster", "")) == target_pid:
				return "%s se protege con Force Field hasta su próximo turno." % shielded
			return "%s queda protegido por Force Field hasta el próximo turno de %s." % [shielded, caster]
		"lightning_redirected":
			var from_n: String = mage_list(names, data.get("from", []) as Array)
			var to_n: String = mage_list(names, data.get("to", []) as Array)
			return "El rayo salta de %s a %s y ahora hace %d de daño." % [from_n, to_n, int(data.get("damage", 0))]
	return "%s surte efecto." % card


# =============================================================================
# 3. Pistas de uso (una línea; la mesa muestra la que toque)
# =============================================================================

const HINT_YOUR_TURN: String = "Tu turno: juega, descarta, cambia o termina el turno."
const HINT_SELECT_CARD: String = "Toca una carta para ver su ficha."
const HINT_HOLD_CARD: String = "Mantén pulsada una carta para verla en grande."
const HINT_PICK_TARGET: String = "Elige un objetivo."
const HINT_REACTION: String = "Responde con una defensiva o un Lightning, o pasa."
const HINT_DRINK_ANYTIME: String = "Puedes beber una poción cuando quieras."
const HINT_CONFIRM_PAY: String = "Confirma para jugar la carta."
const HINT_NOT_YOUR_TURN: String = "Espera: aún no es tu turno."
const HINT_RULE_BREAK: String = "¿Alguien rompió la regla? Díselo a la mesa con el botón."


static func hint_pick_targets(n: int) -> String:
	return "Elige %d %s." % [n, "objetivo" if n == 1 else "objetivos"]


static func hint_waiting_for(name: String) -> String:
	return "Esperando a %s…" % name


static func hint_bot_turn(name: String) -> String:
	return "Juega %s…" % name


## Contador del botón de poción: "Poción 3/10" (sin límite: "Poción 3").
static func potion_counter(drunk: int, limit: int) -> String:
	if limit <= 0:
		return "Poción %d" % drunk
	return "Poción %d/%d" % [drunk, limit]


## Aviso cuando la siguiente poción elimina.
static func potion_warning(drunk: int, limit: int) -> String:
	if limit > 0 and drunk >= limit:
		return "Otra poción y quedas eliminado (Too Much Mana)."
	if limit > 0 and drunk >= limit - 2:
		return "Cuidado: llevas %d de %d pociones." % [drunk, limit]
	return ""


# =============================================================================
# 4. Motivos de "no jugable" y ficha de carta (criterios-v02 §3)
# =============================================================================

const REASON_NOT_YOUR_TURN: String = "No es tu turno"
const REASON_PROMPT_PENDING: String = "Resuelve primero la decisión pendiente"
const REASON_REACTION_ONLY: String = "Solo puedes responder con una defensiva o un Lightning"
const REASON_BLINDED: String = "Estás cegado: no puedes lanzar ofensivas este turno."
const REASON_DEFENSIVE_ONLY_IN_REACTION: String = "Solo se juega en respuesta a un hechizo."
const REASON_NO_VALID_TARGET: String = "No hay un objetivo válido."


## "Cuesta 2 de maná y tienes 1." (+ " Bebe una poción." si aún se puede beber).
static func reason_mana(cost: int, have: int, can_drink: bool) -> String:
	var s: String = "Cuesta %d de maná y tienes %d." % [cost, have]
	return s + " Bebe una poción." if can_drink else s


## "Te falta 1 carta de fuego." (`requirement` sale de requirement_text).
static func reason_missing_cards(requirement: String) -> String:
	return "Te falta %s." % requirement


## "Maná: 2 (base 1)" si el coste efectivo difiere del base; si no, "Maná: 1".
static func mana_line(effective: int, base: int) -> String:
	if effective != base:
		return "Maná: %d (base %d)" % [maxi(effective, 0), base]
	return "Maná: %d" % maxi(effective, 0)


## "Ofensiva de fuego" / "Apoyo" / "Artefacto" para la ficha.
static func type_line(card_type: String, element: String) -> String:
	var t: String = type_name(card_type).capitalize()
	if element != "" and element != Types.ELEMENT_NONE:
		return "%s de %s" % [t, element_name(element)]
	return "%s, sin elemento" % t if card_type == Types.CARD_TYPE_OFFENSIVE else t


# =============================================================================
# 5. Pago y descarte (criterios-v02 §4)
# =============================================================================

const SCROLL_SUFFIX: String = " (o tu Scroll of Elements)"
const PAY_NO_MANA_NOTE: String = "se descuenta al confirmar"


## Un requisito de coste: {by: "element"|"type", value, count}.
## "1 carta de fuego", "2 cartas de hielo", "1 carta defensiva", "2 cartas de maldición".
static func requirement_one(req: Dictionary) -> String:
	var n: int = int(req.get("count", 1))
	var value: String = String(req.get("value", ""))
	var noun: String = "carta" if n == 1 else "cartas"
	if String(req.get("by", "")) == "element":
		return "%d %s de %s" % [n, noun, element_name(value)]
	match value:
		Types.CARD_TYPE_DEFENSIVE:
			return "%d %s" % [n, "carta defensiva" if n == 1 else "cartas defensivas"]
		Types.CARD_TYPE_OFFENSIVE:
			return "%d %s" % [n, "carta ofensiva" if n == 1 else "cartas ofensivas"]
	return "%d %s de %s" % [n, noun, type_name(value)]


## Todos los requisitos de `cost.cards`: "1 carta de fuego, 1 carta de hielo y 1
## carta de electricidad". `scroll`: añade " (o tu Scroll of Elements)".
static func requirement_text(reqs: Array, scroll: bool = false) -> String:
	var parts: Array[String] = []
	for r: Variant in reqs:
		parts.append(requirement_one(r as Dictionary))
	var s: String = join_list(parts)
	return s + SCROLL_SUFFIX if scroll and s != "" else s


## Total de cartas que pide el coste (para el contador n/total).
static func requirement_total(reqs: Array) -> int:
	var t: int = 0
	for r: Variant in reqs:
		t += int((r as Dictionary).get("count", 1))
	return t


## Encabezado de la barra de pago: "Fireball: paga 1 carta de fuego (0/1)".
static func pay_header(card: String, requirement: String, selected: int, total: int) -> String:
	return "%s: paga %s (%d/%d)" % [card, requirement, selected, total]


## "Maná: 1, se descuenta al confirmar".
static func pay_mana_note(mana: int) -> String:
	return "Maná: %d, %s" % [mana, PAY_NO_MANA_NOTE]


## Título de un descarte obligatorio: "Descarta 2 cartas (Icy Grasp)".
static func discard_title(count: int, source_card_id: String = "") -> String:
	var s: String = "Descarta %s" % cards(count)
	if source_card_id != "":
		s += " (%s)" % card_name(source_card_id)
	return s + "."


## Pago de "Intercambiar": "Cambiar cuesta 2 de maná."
static func exchange_cost(mana: int) -> String:
	return "Cambiar una carta cuesta %d de maná." % mana


# =============================================================================
# 6. Errores de reglas (Types.ERR_*): lo que ve el jugador si algo se rechaza
# =============================================================================

## Texto para un código de error del motor. Para `insufficient_mana` y
## `invalid_payment` es mejor la frase concreta del grupo 4.
static func error_text(err: String) -> String:
	match err:
		Types.ERR_NONE:
			return ""
		Types.ERR_INVALID_ACTION:
			return "Esa acción no vale."
		Types.ERR_NOT_IMPLEMENTED:
			return "Esa carta aún no está lista."
		Types.ERR_GAME_NOT_PLAYING:
			return "La partida ya terminó."
		Types.ERR_UNKNOWN_PLAYER:
			return "Ese mago no está en la partida."
		Types.ERR_PLAYER_ELIMINATED:
			return "Ya estás eliminado."
		Types.ERR_NOT_YOUR_TURN:
			return "No es tu turno."
		Types.ERR_WRONG_PHASE:
			return "Eso no se puede hacer ahora."
		Types.ERR_REACTION_PENDING:
			return "Hay un hechizo en el aire: primero se responde o se pasa."
		Types.ERR_NO_REACTION:
			return "No hay ningún hechizo al que responder."
		Types.ERR_NOT_YOUR_DECISION:
			return "Ahora no te toca decidir."
		Types.ERR_PROMPT_PENDING:
			return "Resuelve primero la decisión pendiente."
		Types.ERR_PROMPT_NOT_FOUND:
			return "Esa decisión ya no está pendiente."
		Types.ERR_CARD_NOT_IN_HAND:
			return "Esa carta no está en tu mano."
		Types.ERR_CARD_NOT_IN_PLAY:
			return "Esa carta ya no está en la mesa."
		Types.ERR_CARD_NOT_PLAYABLE:
			return "Esa carta no se puede jugar ahora."
		Types.ERR_UNKNOWN_CARD, Types.ERR_NO_EFFECT:
			return "Esa carta no hace nada todavía."
		Types.ERR_INSUFFICIENT_MANA:
			return "No te alcanza el maná."
		Types.ERR_INVALID_PAYMENT:
			return "Las cartas de pago no valen para esta jugada."
		Types.ERR_INVALID_TARGET:
			return "Ese objetivo no vale."
		Types.ERR_INVALID_CHOICE:
			return "Esa elección no vale."
		Types.ERR_BLINDED:
			return REASON_BLINDED
		Types.ERR_TARGET_IMMUNE:
			return "Ese mago es inmune a hechizos por ahora."
		Types.ERR_ARTIFACT_LIMIT:
			return "Ya tienes uno de esos artefactos en la mesa."
		Types.ERR_ARTIFACT_ALREADY_USED:
			return "Ese artefacto ya se usó este turno."
		Types.ERR_NOTHING_TO_DISCARD:
			return "No tienes nada que descartar."
		Types.ERR_STALE_REV:
			return "La mesa cambió mientras jugabas. Inténtalo otra vez."
	return "Eso no se puede hacer."


# =============================================================================
# 7. Decisiones del motor (prompts)
# =============================================================================

const PROMPT_DRINK: String = "Beber poción"
const PROMPT_DRINK_ELIMINATES: String = "Beber poción (¡eliminado!)"


## Maná insuficiente: título, texto y botón de perder vida.
const PROMPT_SHORTFALL_TITLE: String = "Maná insuficiente"


static func prompt_shortfall(missing: int) -> String:
	return "Te faltan %d de maná. Bebe una poción o pierde esa vida." % missing


static func button_lose_life(hp: int) -> String:
	return "Perder %d de vida" % hp


static func prompt_archmage(hp: int) -> String:
	return "Bebe una poción o pierde %d de vida." % hp


## Magic Cap (QA-V2-03-07): sin "gorro"; el nombre de la carta va en inglés.
## `kind`: Damage.KIND_MANA_LOSS o vida. Título de diálogo: card_name(CARD_MAGIC_CAP).
static func prompt_magic_cap(amount: int, kind: String) -> String:
	var what: String = "maná" if kind == Damage.KIND_MANA_LOSS else "vida"
	return "Vas a perder %d de %s. Descarta tu Magic Cap para evitarlo." % [amount, what]


const BUTTON_USE_MAGIC_CAP: String = "Usar Magic Cap"
const BUTTON_DONT_USE: String = "No usar"


static func prompt_mana_focus(damage: int) -> String:
	return "Vas a recibir %d de daño. Cada maná que gastes evita 1 de daño. ¿Cuánto gastas?" % damage


static func prompt_elixir(price: int, can_pay: bool) -> String:
	var s: String = "Compra vida: cada punto cuesta %d de maná." % price
	if not can_pay:
		s += " Ahora no te llega el maná: puedes beber antes."
	return s


const BUTTON_BUY_LIFE: String = "Comprar vida"
const BUTTON_DONT_BUY: String = "No comprar"
const BUTTON_CONFIRM: String = "Confirmar"
const BUTTON_PASS: String = "Pasar"
const BUTTON_CANCEL: String = "Cancelar"


static func prompt_choose_targets(card: String) -> String:
	return "%s: elige objetivo." % card if card != "" else HINT_PICK_TARGET


# =============================================================================
# 8. Ventana de reacción y "contra ti" (criterios ítem 10)
# =============================================================================

const AGAINST_YOU: String = "Contra ti"
const NOT_AGAINST_YOU: String = "No va contra ti"


## Encabezado de la ventana: "Ana lanza Fireball contra Bruno." + "Contra ti" si aplica.
static func reaction_title(caster: String, card_id: String, targets: Array, names: Dictionary, against_me: bool) -> String:
	var s: String = spell_line(caster, card_id, targets, names)
	return "%s  [%s]" % [s, AGAINST_YOU] if against_me else s


# =============================================================================
# 9. "Pasa el dispositivo" con motivo (hot-seat)
# =============================================================================

const PASS_DEVICE_TITLE: String = "Pasa el dispositivo"
const PASS_REASON_TURN: String = "turn"
const PASS_REASON_REACTION: String = "reaction"
const PASS_REASON_DECISION: String = "decision"


## Línea de motivo: "Turno de Cira", "Cira: ¿respondes al hechizo?" o
## "Cira: tienes una decisión pendiente". `reason`: PASS_REASON_*.
static func pass_device_reason(reason: String, name: String) -> String:
	match reason:
		PASS_REASON_REACTION:
			return "%s: ¿respondes al hechizo?" % name
		PASS_REASON_DECISION:
			return "%s: tienes una decisión pendiente" % name
	return "Turno de %s" % name


## Botón de la pantalla: "Soy Cira".
static func pass_device_button(name: String) -> String:
	return "Soy %s" % name


const PASS_DEVICE_HINT: String = "Que nadie más mire la pantalla."


# =============================================================================
# 10. Fin de partida (criterios-v02 §8.1)
# =============================================================================

const END_TIE_SIMULTANEOUS: String = "Todos los magos cayeron a la vez."
const END_TIE_NONE_LEFT: String = "No queda ningún mago en pie."
const END_CAUSE_HP: String = "Se quedó sin vida"
const END_CAUSE_TOO_MUCH_MANA: String = "Too Much Mana"
const END_CAUSE_CONCEDE: String = "Se rindió"
const END_CAUSE_WINNER: String = "Último en pie"
const END_BY_LOW_MANA: String = "Por maná insuficiente"
const BUTTON_PLAY_AGAIN: String = "Jugar otra vez"
const BUTTON_BACK_TO_MENU: String = "Volver al menú"
const BUTTON_SEE_RESULT: String = "Ver resultado"


## Título: "¡Victoria!" / "Derrota" / "Gana Ana" / "Ganan Ana y Bruno" / "Empate".
## `humans`: pids de humanos locales; `winners`: pids ganadores.
static func end_title(winners: Array, humans: Array, names: Dictionary) -> String:
	if winners.is_empty():
		return "Empate"
	if humans.size() == 1:
		return "¡Victoria!" if winners.has(humans[0]) else "Derrota"
	if winners.size() == 1:
		return "Gana %s" % mage(names, String(winners[0]))
	return "Ganan %s" % mage_list(names, winners)


## Subtítulo del empate.
static func end_tie_text(simultaneous: bool) -> String:
	return END_TIE_SIMULTANEOUS if simultaneous else END_TIE_NONE_LEFT


## Causa de eliminación según Types.ELIM_*; "" = ganador.
static func end_cause(reason: String) -> String:
	match reason:
		Types.ELIM_TOO_MUCH_MANA:
			return END_CAUSE_TOO_MUCH_MANA
		Types.ELIM_CONCEDE:
			return END_CAUSE_CONCEDE
		Types.ELIM_HP:
			return END_CAUSE_HP
	return END_CAUSE_WINNER


## "Golpe final: Ana con Lightning".
static func end_final_blow(attacker: String, card_id: String) -> String:
	return "Golpe final: %s con %s" % [attacker, card_name(card_id)]


## "Se eliminó a sí mismo con Armageddon".
static func end_self_blow(card_id: String) -> String:
	return "Se eliminó a sí mismo con %s" % card_name(card_id)


## "Por Fire Storm" (evento o carta sin mago origen).
static func end_by_source(card_id: String) -> String:
	return "Por %s" % card_name(card_id)


## "Bebió la poción n.º 11 (límite 10)"; sin límite, sin paréntesis.
static func end_potion_blow(potions: int, limit: int) -> String:
	if limit <= 0:
		return "Bebió la poción n.º %d" % potions
	return "Bebió la poción n.º %d (límite %d)" % [potions, limit]


## Línea de clasificación: "Bruno — Se quedó sin vida — Golpe final: Ana con Lightning".
static func end_row(name: String, cause: String, blow: String = "") -> String:
	if blow == "":
		return "%s — %s" % [name, cause]
	return "%s — %s — %s" % [name, cause, blow]


## "1.º", "2.º"...
static func ordinal(n: int) -> String:
	return "%d.º" % n


## "Turnos: 5 · Pociones: 4"; con la poción que elimina, "Pociones: 11 (límite 10)".
static func end_stats(turns: int, potions: int, limit: int) -> String:
	var p: String = str(potions)
	if limit > 0 and potions > limit:
		p = "%d (límite %d)" % [potions, limit]
	return "Turnos: %d · Pociones: %s" % [turns, p]

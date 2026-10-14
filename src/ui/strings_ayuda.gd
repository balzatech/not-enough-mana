class_name StringsAyuda
extends RefCounted
## Textos de la pantalla "Cómo se juega" en español (V2-09, Narrative Designer).
##
## Solo funciones estáticas y constantes; no tocan nodos ni la sesión. Contenido y
## orden: docs/diseno/ayuda-como-se-juega.md. Texto revisable en docs/narrativa/ayuda.md.
##  * Los números salen de la configuración (por defecto `Types.default_config()`);
##    con `potion_limit_enabled = false` la sección de Too Much Mana lo dice.
##  * Lo que es adaptación digital lleva el prefijo DIGITAL_TAG al inicio de la línea.
##  * Nombres de carta y de evento en inglés; no se copia el texto de las cartas (© SUPERHOTEX).
## Grupos: 1 etiquetas, 2 secciones, 3 aviso de evento.


# =============================================================================
# 1. Etiquetas
# =============================================================================

const SCREEN_TITLE: String = "Cómo se juega"
const BACK_LABEL: String = "Volver"
## Prefijo visible de toda línea que no está en el juego de mesa.
const DIGITAL_TAG: String = "Adaptación digital: "
const VIEW_CARD_HINT: String = "Ver una carta: mantén pulsada la carta."


# =============================================================================
# 2. Secciones
# =============================================================================

## Las 8 secciones en orden. Cada una: {"title": String, "body": String}; el cuerpo
## son líneas separadas por "\n". `config` = config activa de la partida; vacío =
## valores por defecto (ayuda del menú principal).
static func sections(config: Dictionary = {}) -> Array[Dictionary]:
	var cfg: Dictionary = Types.default_config()
	cfg.merge(config, true)
	var out: Array[Dictionary] = []
	out.append(_section("Objetivo", _objective(cfg)))
	out.append(_section("Tu turno", _turn(cfg)))
	out.append(_section("Pagar cartas y maná", _paying(cfg)))
	out.append(_section("Pociones de maná", _potions(cfg)))
	out.append(_section("Too Much Mana", _too_much_mana(cfg)))
	out.append(_section("Defensivas y reacciones", _reactions()))
	out.append(_section("Eventos", _events()))
	out.append(_section("Artefactos y maldiciones", _artifacts_curses()))
	return out


static func _section(title: String, lines: Array[String]) -> Dictionary:
	return {"title": title, "body": "\n".join(lines)}


static func _objective(cfg: Dictionary) -> Array[String]:
	return [
		"Eres un mago, de 3 a 6 en la mesa. Gana el último que siga en pie.",
		"Quedas fuera si te quedas en 0 de vida o por Too Much Mana.",
		"Empiezas con %d de vida (es también tu máximo), %d de maná y %s." % [
			int(cfg["start_hp"]), int(cfg["start_mana"]), _cards(int(cfg["start_hand"]))],
		"El maná no tiene tope. Casi siempre te faltará.",
	]


static func _turn(cfg: Dictionary) -> Array[String]:
	return [
		"1. Robas hasta tu límite de mano (normalmente %d). Si robas un evento, se aplica ya y robas otra carta." % int(cfg["hand_limit"]),
		"2. Actúas las veces que quieras y en el orden que quieras: jugar cartas, descartar o intercambiar.",
		"3. Terminas el turno.",
		"Si se acaba el mazo, se baraja el descarte y pasa a ser el mazo.",
		DIGITAL_TAG + "empieza el mago de más edad (la que se indicó al crear la partida) y se sigue en sentido horario.",
	]


static func _paying(cfg: Dictionary) -> Array[String]:
	var base: int = int(cfg["exchange_base_cost"])
	return [
		"Para jugar una carta pagas su coste: maná y, a veces, cartas de tu mano de un tipo o elemento (por ejemplo, 1 carta de fuego). Las que pagas van al descarte con la jugada.",
		"Eventos y artefactos pueden cambiar el coste. La carta siempre muestra el coste actual.",
		"Los hechizos con objetivo también se pueden lanzar contra ti.",
		"Scroll of Elements: en mesa, sustituye una carta requerida de un coste (un solo uso).",
		"Intercambiar: descartas una carta, pagas y robas otra. El primero del turno cuesta %d de maná, el segundo %d, el tercero %d..." % [base, base + 1, base + 2],
		"Si te obligan a descartar y no tienes cartas, pierdes 1 de maná por cada carta que no puedas descartar.",
		"Si tienes que perder más maná del que tienes, debes beber una poción en ese momento. Si no, pierdes tanta vida como maná te falte.",
		DIGITAL_TAG + "el juego te lo pregunta en una pantalla de decisión.",
		"Tipos de carta: ofensivas (fuego, hielo, electricidad), defensivas, de apoyo, maldiciones, artefactos y eventos.",
	]


static func _potions(cfg: Dictionary) -> Array[String]:
	var lines: Array[String] = [
		"Cada poción te da +%d de maná. Puedes beber en cualquier momento: también fuera de tu turno y mientras decides una reacción." % int(cfg["potion_mana"]),
		DIGITAL_TAG + "se bebe con el botón \"Beber poción\", siempre disponible mientras sigas vivo. Lleva tu contador de pociones bebidas.",
	]
	if bool(cfg["pool_enabled"]):
		lines.append("Hay una reserva común de cristales (%d de vida y %d de maná en total). Lo que ganas sale de ella; lo que pagas o pierdes vuelve. Si no quedan cristales de maná, las pociones no dan nada." % [int(cfg["pool_hp"]), int(cfg["pool_mana"])])
		lines.append(DIGITAL_TAG + "en la mesa física son cristales; aquí es un contador que ves en la mesa.")
	lines.append("Algunas cartas cambian lo que da una poción (más o menos 1). Esta ayuda no las enumera.")
	return lines


static func _too_much_mana(cfg: Dictionary) -> Array[String]:
	if not bool(cfg["potion_limit_enabled"]):
		return [
			DIGITAL_TAG + "Too Much Mana sustituye al K.O. por beber demasiado de la mesa física. En esta partida no hay límite de pociones.",
		]
	var limit: int = int(cfg["potion_limit"])
	var warn: int = maxi(limit - 2, 1)
	return [
		DIGITAL_TAG + "Too Much Mana sustituye al K.O. por beber demasiado de la mesa física: hay un límite de %s por partida (se puede desactivar al crear la partida)." % _potions_n(limit),
		DIGITAL_TAG + "Beber la poción número %d te elimina y no te da el maná. El botón se pone ámbar desde %d/%d y rojo en %d/%d, y te pide confirmación." % [limit + 1, warn, limit, limit, limit],
		DIGITAL_TAG + "Tu contador de pociones nunca baja durante la partida.",
	]


static func _reactions() -> Array[String]:
	return [
		"Las cartas defensivas se juegan en respuesta a un hechizo, incluso fuera de tu turno (escudos, conejo helado, última voluntad, captura de maná, aniquilación).",
		"Un Lightning también puede responder a otro Lightning: el daño sube y se redirige.",
		"No puedes jugar una defensiva en tu turno si no hay un hechizo al que responder.",
		DIGITAL_TAG + "ventana de reacción. Cuando alguien lanza un hechizo, decide un jugador a la vez: primero el objetivo y luego en sentido horario. Solo se espera a quien puede responder.",
		DIGITAL_TAG + "cada uno juega una defensiva o pulsa Pasar. Si alguien responde, vuelven a decidir todos los que puedan. Cuando todos pasan, se resuelve primero la última respuesta.",
		DIGITAL_TAG + "en línea hay un plazo para decidir; en local no, solo el botón Pasar.",
		DIGITAL_TAG + "en Ajustes, \"Avisarme de reacciones\" elige si te interrumpe cualquier hechizo o solo los que te afectan (por defecto, solo esos). No cambia las reglas: si no te sale la ventana, es como pulsar Pasar.",
	]


static func _events() -> Array[String]:
	return [
		"Un evento aparece cuando alguien lo roba: se lee, se pone en el centro de la mesa y se aplica. Después, quien lo robó roba otra carta. En la mano inicial, el evento se descarta y se roba otra.",
		"Unos son inmediatos (curan o dañan a todos). Otros cambian las reglas hasta que aparezca el siguiente evento (por ejemplo: un elemento cuesta más pero hace más, las pociones dan menos, el límite de mano sube).",
		"El evento activo se ve en el centro de la mesa. Cuando llega uno nuevo, el anterior se va.",
	]


static func _artifacts_curses() -> Array[String]:
	return [
		"Los artefactos se quedan en la mesa delante de su dueño y dan una ventaja mientras estén (o hasta que se usen).",
		"Las maldiciones quitan maná a los magos que cumplan su condición: edad, mes de nacimiento o vida.",
		"Curse of Rules deja una regla de mesa: quien la rompa pierde 1 de maná.",
		DIGITAL_TAG + "hay un botón \"Rompió la regla\" para avisarlo.",
		DIGITAL_TAG + "por eso, al crear la partida, se pide la edad y el mes de nacimiento de cada mago.",
	]


static func _cards(n: int) -> String:
	return "%d %s" % [n, "carta" if n == 1 else "cartas"]


static func _potions_n(n: int) -> String:
	return "%d %s" % [n, "poción" if n == 1 else "pociones"]


# =============================================================================
# 3. Aviso de evento
# =============================================================================

## Aviso al salir un evento. `persistent`: true = cambia las reglas hasta el
## siguiente evento; false = instantáneo, sin duración.
static func event_notice(card_name: String, persistent: bool) -> String:
	if persistent:
		return "Evento: %s. Dura hasta el próximo evento." % card_name
	return "Evento: %s. Efecto inmediato, no dura." % card_name

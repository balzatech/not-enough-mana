class_name Types
extends RefCounted
## ============================================================================
## CONTRATO COMPARTIDO DEL MOTOR (T1).  Archivo de solo lectura para los agentes.
## ============================================================================
## Si necesitas cambiar algo, NO edites este archivo: escribe la petición en
## docs/CAMBIOS-TIPOS.md y sigue con un workaround local.
##
## Principios (ver docs/CONTRATO-TIPOS.md):
##  * El estado de la partida es un Dictionary con SOLO tipos JSON:
##    int, String, bool, Array y Dictionary. **No hay floats en el estado**: todo
##    número es int. Todas las claves de Dictionary son String.
##  * Todas las constantes del estado son String (no enums int), porque las
##    cadenas sobreviven a JSON/Firebase sin conversión.
##  * Tras leer JSON (JSON.parse_string o Firebase) llama SIEMPRE a
##    Types.normalize_state(): convierte floats enteros a int y restaura claves
##    que Firebase elimina (arrays/diccionarios vacíos y null).
##  * Ids de jugador: String (en línea = uid de Firebase; en local "p1".."p6").
##  * Ids de carta: slug String (constantes CARD_*). Cada carta física es una
##    "instancia" con un iid int único en la partida.
##  * Pilas: en `deck` y `discard` la carta de ARRIBA es el ÚLTIMO elemento
##    (pop_back / push_back).
##  * Orden de asientos = orden del array `players` (sentido horario).

# -----------------------------------------------------------------------------
# Versiones
# -----------------------------------------------------------------------------

## Versión del esquema del estado. Súbela si cambia la forma del estado.
const SCHEMA_VERSION: int = 1
## Versión del protocolo de red (meta.protocolVersion en Firebase).
const PROTOCOL_VERSION: int = 1
## Límite superior (exclusivo) del estado del RNG: 2^32.
const RNG_MODULUS: int = 4294967296

# -----------------------------------------------------------------------------
# Tipos de carta (card_def.type)
# -----------------------------------------------------------------------------

const CARD_TYPE_OFFENSIVE: String = "offensive"   ## Hechizo ofensivo (tiene elemento)
const CARD_TYPE_DEFENSIVE: String = "defensive"   ## Se puede jugar fuera de turno como respuesta
const CARD_TYPE_SUPPORT: String = "support"       ## Soporte (curar, intercambiar mano…)
const CARD_TYPE_CURSE: String = "curse"           ## Maldición
const CARD_TYPE_ARTIFACT: String = "artifact"     ## Se queda en la mesa delante del jugador
const CARD_TYPE_EVENT: String = "event"           ## Se aplica al robarla; queda en el centro
const CARD_TYPE_NON_PLAYABLE: String = "non_playable"  ## Referencia, vacías, Anti-Joker (fuera del mazo)

const CARD_TYPES: Array[String] = [
	CARD_TYPE_OFFENSIVE, CARD_TYPE_DEFENSIVE, CARD_TYPE_SUPPORT, CARD_TYPE_CURSE,
	CARD_TYPE_ARTIFACT, CARD_TYPE_EVENT, CARD_TYPE_NON_PLAYABLE,
]

# -----------------------------------------------------------------------------
# Elementos (card_def.element y eventos de daño)
# -----------------------------------------------------------------------------

const ELEMENT_FIRE: String = "fire"
const ELEMENT_ICE: String = "ice"
const ELEMENT_ELECTRIC: String = "electric"
const ELEMENT_NONE: String = "none"   ## Cartas sin elemento y daño no elemental

const ELEMENTS: Array[String] = [ELEMENT_FIRE, ELEMENT_ICE, ELEMENT_ELECTRIC, ELEMENT_NONE]

# -----------------------------------------------------------------------------
# Objetivos (card_def.target): cómo elige objetivos la UI / el bot
# -----------------------------------------------------------------------------

const TARGET_NONE: String = "none"           ## Sin objetivo (afecta a quien la juega o es global)
const TARGET_SINGLE: String = "single"       ## 1 mago cualquiera (incluido uno mismo, regla 1.3)
const TARGET_TWO: String = "two"             ## 2 magos (Electric Arc)
const TARGET_OTHER: String = "other"         ## 1 mago distinto de quien la juega (Book Exchange, Magic Hand)
const TARGET_ALL: String = "all"             ## Todos, incluido quien la lanza (Armageddon)
const TARGET_ALL_OTHERS: String = "all_others"  ## Todos menos quien la lanza
const TARGET_CARD_IN_PLAY: String = "card_in_play"  ## Una carta en juego (Annihilation)

const TARGETS: Array[String] = [
	TARGET_NONE, TARGET_SINGLE, TARGET_TWO, TARGET_OTHER, TARGET_ALL,
	TARGET_ALL_OTHERS, TARGET_CARD_IN_PLAY,
]

# -----------------------------------------------------------------------------
# Requisitos de coste en cartas (card_def.cost.cards[i].by)
# -----------------------------------------------------------------------------

const REQ_BY_TYPE: String = "type"         ## value = CARD_TYPE_*
const REQ_BY_ELEMENT: String = "element"   ## value = ELEMENT_* (cualquier hechizo de ese elemento)
const REQ_BY_CARD: String = "card"         ## value = CARD_* (una carta concreta)
const REQ_ANY: String = "any"              ## cualquier carta (value = "")

# -----------------------------------------------------------------------------
# Ids de carta (slugs). T3 usa EXACTAMENTE estos ids en data/cards.json.
# -----------------------------------------------------------------------------

# No jugables
const CARD_QUICK_REFERENCE: String = "quick_reference"
const CARD_BLANK: String = "blank"
const CARD_ANTI_JOKER: String = "anti_joker"
# Ofensivas de fuego (T6a: fire.gd)
const CARD_FIRE_ARROW: String = "fire_arrow"
const CARD_FIREBALL: String = "fireball"
const CARD_METEOR_SHOWER: String = "meteor_shower"
const CARD_ARMAGEDDON: String = "armageddon"
const CARD_MANA_IMPLOSION: String = "mana_implosion"
# Ofensivas de hielo (T6a: ice.gd)
const CARD_ICE_BOLT: String = "ice_bolt"
const CARD_BLIZZARD: String = "blizzard"
const CARD_ICE_BOOMERANG: String = "ice_boomerang"
const CARD_VAMPIRIC_TOUCH: String = "vampiric_touch"
const CARD_FREEZE: String = "freeze"
const CARD_ICY_GRASP: String = "icy_grasp"
# Ofensivas eléctricas (T6a: electric.gd)
const CARD_LIGHTNING: String = "lightning"
const CARD_ELECTRIC_EXPLOSION: String = "electric_explosion"
const CARD_BLINDING_FLASH: String = "blinding_flash"
const CARD_ELECTRIC_ARC: String = "electric_arc"
const CARD_PARALYSING_TOUCH: String = "paralysing_touch"
# Defensivas (T6b: defensive.gd)
const CARD_MAGIC_SHIELD: String = "magic_shield"
const CARD_MIRROR_SHIELD: String = "mirror_shield"
const CARD_FROZEN_BUNNY: String = "frozen_bunny"
const CARD_LAST_WISH: String = "last_wish"
const CARD_MAGIC_CAPTURE: String = "magic_capture"
const CARD_ANNIHILATION: String = "annihilation"
# Soporte (T6c: support.gd)
const CARD_HEAL: String = "heal"
const CARD_GREATER_HEAL: String = "greater_heal"
const CARD_BOOK_EXCHANGE: String = "book_exchange"
const CARD_MAGIC_HAND: String = "magic_hand"
const CARD_FORCE_FIELD: String = "force_field"
const CARD_POTENT_ELIXIR: String = "potent_elixir"
const CARD_SPACE_SHIFT: String = "space_shift"
# Maldiciones (T6c: curses.gd)
const CARD_CURSE_OF_RULES: String = "curse_of_rules"
const CARD_CURSE_OF_THE_ELDER: String = "curse_of_the_elder"
const CARD_CURSE_OF_THE_YOUNGER: String = "curse_of_the_younger"
const CARD_CURSE_OF_VIGOUR: String = "curse_of_vigour"
const CARD_CURSE_OF_EVEN: String = "curse_of_even"
const CARD_CURSE_OF_ODD: String = "curse_of_odd"
# Artefactos (T6c: artifacts.gd)
const CARD_FIREPROOF_TIARA: String = "fireproof_tiara"
const CARD_PADDED_BOOTS: String = "padded_boots"
const CARD_FARADAYS_CLOAK: String = "faradays_cloak"
const CARD_WILD_FIRE: String = "wild_fire"
const CARD_DRAGON_GLASS: String = "dragon_glass"
const CARD_TESLA_COIL: String = "tesla_coil"
const CARD_SPELLBOOK: String = "spellbook"
const CARD_MAGIC_CAP: String = "magic_cap"
const CARD_RUNIC_ARMOR: String = "runic_armor"
const CARD_SCROLL_OF_ELEMENTS: String = "scroll_of_elements"
const CARD_TRANSFORMATION_GLOVE: String = "transformation_glove"
const CARD_TWARDOWSKYS_MIRROR: String = "twardowskys_mirror"
# Eventos (T6c: events.gd)
const CARD_VISIT_OF_THE_ARCHMAGE: String = "visit_of_the_archmage"
const CARD_NOT_ENOUGH_MANA: String = "not_enough_mana"
const CARD_SHOT_GLASS: String = "shot_glass"
const CARD_FIRE_STORM: String = "fire_storm"
const CARD_ICE_STORM: String = "ice_storm"
const CARD_LIGHTNING_STORM: String = "lightning_storm"
const CARD_MANA_FOCUS: String = "mana_focus"
const CARD_DISRUPTED_GRAVITY: String = "disrupted_gravity"
const CARD_BLESSING: String = "blessing"
const CARD_WARP_DISCHARGE: String = "warp_discharge"
const CARD_ELIXIR_TRANSMUTATION: String = "elixir_transmutation"

## Los 58 diseños jugables (sin referencia, vacías ni Anti-Joker).
const PLAYABLE_CARD_IDS: Array[String] = [
	CARD_FIRE_ARROW, CARD_FIREBALL, CARD_METEOR_SHOWER, CARD_ARMAGEDDON, CARD_MANA_IMPLOSION,
	CARD_ICE_BOLT, CARD_BLIZZARD, CARD_ICE_BOOMERANG, CARD_VAMPIRIC_TOUCH, CARD_FREEZE, CARD_ICY_GRASP,
	CARD_LIGHTNING, CARD_ELECTRIC_EXPLOSION, CARD_BLINDING_FLASH, CARD_ELECTRIC_ARC, CARD_PARALYSING_TOUCH,
	CARD_MAGIC_SHIELD, CARD_MIRROR_SHIELD, CARD_FROZEN_BUNNY, CARD_LAST_WISH, CARD_MAGIC_CAPTURE, CARD_ANNIHILATION,
	CARD_HEAL, CARD_GREATER_HEAL, CARD_BOOK_EXCHANGE, CARD_MAGIC_HAND, CARD_FORCE_FIELD, CARD_POTENT_ELIXIR, CARD_SPACE_SHIFT,
	CARD_CURSE_OF_RULES, CARD_CURSE_OF_THE_ELDER, CARD_CURSE_OF_THE_YOUNGER, CARD_CURSE_OF_VIGOUR, CARD_CURSE_OF_EVEN, CARD_CURSE_OF_ODD,
	CARD_FIREPROOF_TIARA, CARD_PADDED_BOOTS, CARD_FARADAYS_CLOAK, CARD_WILD_FIRE, CARD_DRAGON_GLASS, CARD_TESLA_COIL,
	CARD_SPELLBOOK, CARD_MAGIC_CAP, CARD_RUNIC_ARMOR, CARD_SCROLL_OF_ELEMENTS, CARD_TRANSFORMATION_GLOVE, CARD_TWARDOWSKYS_MIRROR,
	CARD_VISIT_OF_THE_ARCHMAGE, CARD_NOT_ENOUGH_MANA, CARD_SHOT_GLASS, CARD_FIRE_STORM, CARD_ICE_STORM, CARD_LIGHTNING_STORM,
	CARD_MANA_FOCUS, CARD_DISRUPTED_GRAVITY, CARD_BLESSING, CARD_WARP_DISCHARGE, CARD_ELIXIR_TRANSMUTATION,
]

# -----------------------------------------------------------------------------
# Estado global de la partida y fases del turno
# -----------------------------------------------------------------------------

const STATUS_SETUP: String = "setup"         ## Creada, sin repartir
const STATUS_PLAYING: String = "playing"
const STATUS_FINISHED: String = "finished"   ## Hay ganador(es) en state.winners

const PHASE_DRAW: String = "draw"     ## Robando hasta el límite (eventos al robar)
const PHASE_MAIN: String = "main"     ## Acciones libres del jugador en turno
const PHASE_END: String = "end"       ## Fin de turno anunciado; limpieza antes de pasar al siguiente

# -----------------------------------------------------------------------------
# Tipos de acción (action.type). Toda acción lleva "type" y "player".
# Ver make_action_*() para las claves exactas de cada una.
# -----------------------------------------------------------------------------

const ACTION_PLAY_CARD: String = "PLAY_CARD"           ## Jugar carta de la mano en tu turno
const ACTION_DISCARD: String = "DISCARD"               ## Descartar N cartas en tu turno
const ACTION_EXCHANGE: String = "EXCHANGE"             ## Intercambiar 1 carta (coste creciente)
const ACTION_DRINK_POTION: String = "DRINK_POTION"     ## Beber poción (en cualquier momento)
const ACTION_END_TURN: String = "END_TURN"             ## Anunciar fin de turno
const ACTION_REACT: String = "REACT"                   ## Responder en la ventana de reacción (defensiva, Lightning)
const ACTION_PASS_REACTION: String = "PASS_REACTION"   ## Pasar en la ventana de reacción
const ACTION_BREAK_RULE: String = "BREAK_RULE"         ## "Rompió la regla" (Curse of Rules): el acusado pierde 1 maná
const ACTION_CHOOSE_TARGETS: String = "CHOOSE_TARGETS" ## Responder a un prompt eligiendo magos
const ACTION_CHOOSE_CARDS: String = "CHOOSE_CARDS"     ## Responder a un prompt eligiendo cartas (iids)
const ACTION_DECLINE: String = "DECLINE"               ## Rechazar un prompt opcional (no beber, no usar Magic Cap…)
const ACTION_USE_ARTIFACT: String = "USE_ARTIFACT"     ## Activar un artefacto en mesa (Glove, Mirror, Magic Cap…)
const ACTION_USE_EVENT: String = "USE_EVENT"           ## Usar la opción del evento activo (p. ej. Elixir Transmutation)
const ACTION_CONCEDE: String = "CONCEDE"               ## Abandonar la partida (desconexión definitiva)
## Vencimiento de un plazo (v0.3, V3-13b). Solo la envía la sesión (en
## LocalSession con by = "timeout"; en línea, solo el anfitrión). Nunca sale en
## legal_actions; por eso NO está en ACTION_TYPES ni en OUT_OF_TURN_ACTIONS, sino
## en SESSION_ACTION_TYPES. La resuelve TimeoutRules (V3-14), que valida `expect`
## y devuelve ERR_TIMEOUT_STALE si la decisión que vencía ya no está abierta.
## Ver make_action_timeout() y docs/TECNICO/v03-diseno.md §1.5.
const ACTION_TIMEOUT: String = "TIMEOUT"

const ACTION_TYPES: Array[String] = [
	ACTION_PLAY_CARD, ACTION_DISCARD, ACTION_EXCHANGE, ACTION_DRINK_POTION, ACTION_END_TURN,
	ACTION_REACT, ACTION_PASS_REACTION, ACTION_BREAK_RULE, ACTION_CHOOSE_TARGETS,
	ACTION_CHOOSE_CARDS, ACTION_DECLINE, ACTION_USE_ARTIFACT, ACTION_USE_EVENT, ACTION_CONCEDE,
]

## Acciones que se pueden enviar fuera del turno propio.
const OUT_OF_TURN_ACTIONS: Array[String] = [
	ACTION_DRINK_POTION, ACTION_REACT, ACTION_PASS_REACTION, ACTION_BREAK_RULE,
	ACTION_CHOOSE_TARGETS, ACTION_CHOOSE_CARDS, ACTION_DECLINE, ACTION_USE_ARTIFACT,
	ACTION_USE_EVENT, ACTION_CONCEDE,
]

## Acciones que no elige un jugador: las genera la sesión (o el anfitrión) y
## nunca salen en Game.legal_actions. validate_action_shape las acepta.
const SESSION_ACTION_TYPES: Array[String] = [ACTION_TIMEOUT]

## TIMEOUT.scope: qué decisión ha vencido.
const TIMEOUT_SCOPE_TURN: String = "turn"          ## el turno completo; expect = {"turn": int}
const TIMEOUT_SCOPE_REACTION: String = "reaction"  ## una ronda de reacción; expect = {"spell_iid": int, "stack": int}
const TIMEOUT_SCOPE_PROMPT: String = "prompt"      ## un prompt; basta prompt_id (expect = {})
const TIMEOUT_SCOPES: Array[String] = [TIMEOUT_SCOPE_TURN, TIMEOUT_SCOPE_REACTION, TIMEOUT_SCOPE_PROMPT]

## LOG_TIMEOUT.data.resolution: qué aplicó el motor al vencer (E11).
const TIMEOUT_RES_PASS: String = "pass"            ## reaction: PASS_REACTION de ese jugador
const TIMEOUT_RES_DECLINE: String = "decline"      ## prompt: DECLINE
const TIMEOUT_RES_ZERO: String = "zero"            ## prompt mana_focus sin DECLINE: USE_EVENT {mana: 0}
const TIMEOUT_RES_RANDOM: String = "random"        ## prompt obligatorio: elección al azar con el RNG del estado
const TIMEOUT_RES_END_TURN: String = "end_turn"    ## turn: prompts propios resueltos + END_TURN

# -----------------------------------------------------------------------------
# Prompts: decisiones pendientes de un jugador concreto (state.pending)
# -----------------------------------------------------------------------------

const PROMPT_DISCARD: String = "discard"               ## data: {count:int}. Responder con CHOOSE_CARDS
const PROMPT_CHOOSE_TARGETS: String = "choose_targets" ## data: {count:int, allowed:Array[String]}. CHOOSE_TARGETS
const PROMPT_CHOOSE_CARD: String = "choose_card"       ## data: {from:String pid, count:int, cards:Array[iid]}. CHOOSE_CARDS (Magic Hand)
## Magic Hand: como state.pending es público, el prompt va con data.cards = [] y
## data.hidden = true; las cartas elegibles están en reveals[pid] (kind "hand").
const PROMPT_MANA_SHORTFALL: String = "mana_shortfall" ## data: {missing:int}. DRINK_POTION o DECLINE (pierde vida)
const PROMPT_DRINK_OR_SUFFER: String = "drink_or_suffer"  ## data: {hp:int}. Visit of the Archmage: DRINK_POTION o DECLINE
const PROMPT_USE_MAGIC_CAP: String = "use_magic_cap"   ## data: {loss: dict de evento}. USE_ARTIFACT o DECLINE
const PROMPT_MANA_FOCUS: String = "mana_focus"         ## data: {damage:int}. USE_EVENT (extra.mana:int) o DECLINE
const PROMPT_ELIXIR_TRANSMUTATION: String = "elixir_transmutation"  ## data: {price:int, max:int}. USE_EVENT (extra.amount:int) o DECLINE
# Nota: el texto de Curse of Rules NO es un prompt: va en PLAY_CARD extra.rule.

# -----------------------------------------------------------------------------
# Códigos de error (Game.reduce -> {"error": ...}). "" = sin error.
# -----------------------------------------------------------------------------

const ERR_NONE: String = ""
const ERR_INVALID_ACTION: String = "invalid_action"         ## Acción mal formada o tipo desconocido
const ERR_NOT_IMPLEMENTED: String = "not_implemented"       ## Stub sin implementar
const ERR_GAME_NOT_PLAYING: String = "game_not_playing"
const ERR_UNKNOWN_PLAYER: String = "unknown_player"
const ERR_PLAYER_ELIMINATED: String = "player_eliminated"
const ERR_NOT_YOUR_TURN: String = "not_your_turn"
const ERR_WRONG_PHASE: String = "wrong_phase"
const ERR_REACTION_PENDING: String = "reaction_pending"     ## Hay una ventana de reacción abierta
const ERR_NO_REACTION: String = "no_reaction"               ## REACT/PASS sin ventana abierta
const ERR_NOT_YOUR_DECISION: String = "not_your_decision"   ## No te toca decidir (reacción o prompt)
const ERR_PROMPT_PENDING: String = "prompt_pending"         ## Hay prompts sin resolver que bloquean
const ERR_PROMPT_NOT_FOUND: String = "prompt_not_found"
const ERR_CARD_NOT_IN_HAND: String = "card_not_in_hand"
const ERR_CARD_NOT_IN_PLAY: String = "card_not_in_play"
const ERR_CARD_NOT_PLAYABLE: String = "card_not_playable"   ## No jugable ahora (tipo, fase…)
const ERR_UNKNOWN_CARD: String = "unknown_card"             ## card_id sin definición en el catálogo
const ERR_NO_EFFECT: String = "no_effect"                   ## card_id sin efecto registrado
const ERR_INSUFFICIENT_MANA: String = "insufficient_mana"
const ERR_INVALID_PAYMENT: String = "invalid_payment"       ## Cartas de pago no cumplen el coste
const ERR_INVALID_TARGET: String = "invalid_target"
const ERR_INVALID_CHOICE: String = "invalid_choice"         ## Elección de prompt inválida
const ERR_BLINDED: String = "blinded"                       ## Blinding Flash: no puede lanzar ofensivas
const ERR_TARGET_IMMUNE: String = "target_immune"           ## Force Field / Runic Armor
const ERR_ARTIFACT_LIMIT: String = "artifact_limit"         ## p. ej. 2.º Spellbook
const ERR_ARTIFACT_ALREADY_USED: String = "artifact_already_used"  ## Ya usado este turno
const ERR_NOTHING_TO_DISCARD: String = "nothing_to_discard"
const ERR_STALE_REV: String = "stale_rev"                   ## En línea: baseRev de la acción desactualizado
## TIMEOUT cuya decisión ya no está abierta (el jugador actuó, cambió la ronda o
## el turno). La sesión no lo muestra a la UI (by != "human").
const ERR_TIMEOUT_STALE: String = "timeout_stale"

# -----------------------------------------------------------------------------
# Tubería de modificadores (ver sección "Modificadores" más abajo)
# -----------------------------------------------------------------------------

## Etapas, en el orden en que damage.gd / game.gd las ejecutan.
const STAGE_COST: String = "cost"               ## Coste de maná de una carta. event.amount = maná
const STAGE_OUTGOING: String = "outgoing"       ## Bonos del atacante/globales (Wild Fire, Storms). amount = daño
const STAGE_INCOMING: String = "incoming"       ## Reducciones del objetivo (Tiara, Boots, Cloak)
const STAGE_PREVENT: String = "prevent"         ## Defensivas que previenen (Magic Shield, Frozen Bunny)
const STAGE_REDIRECT: String = "redirect"       ## Defensivas que redirigen (Mirror Shield)
const STAGE_AFTER_DAMAGE: String = "after_damage"  ## Tras aplicar (Not Enough Mana, Last Wish). amount = daño final
const STAGE_POTION: String = "potion"           ## Maná que da una poción (Shot Glass, Potent Elixir)
const STAGE_HAND_LIMIT: String = "hand_limit"   ## Límite de mano (Spellbook, Disrupted Gravity)
const STAGE_EXCHANGE_COST: String = "exchange_cost"  ## Coste de un intercambio

const STAGES: Array[String] = [
	STAGE_COST, STAGE_OUTGOING, STAGE_INCOMING, STAGE_PREVENT, STAGE_REDIRECT,
	STAGE_AFTER_DAMAGE, STAGE_POTION, STAGE_HAND_LIMIT, STAGE_EXCHANGE_COST,
]
## Orden de las etapas de daño (las ejecuta Damage en este orden).
const DAMAGE_STAGES: Array[String] = [STAGE_OUTGOING, STAGE_INCOMING, STAGE_PREVENT, STAGE_REDIRECT]

## Operaciones estándar que aplica Modifiers.run_stage() sin código extra.
const OP_ADD: String = "add"               ## amount += value
const OP_SUB: String = "sub"               ## amount = max(0, amount - value); suma lo quitado a event.prevented
const OP_MUL: String = "mul"               ## amount *= value
const OP_SET: String = "set"               ## amount = value
const OP_PREVENT_ALL: String = "prevent_all"  ## event.prevented += amount; amount = 0
const OP_REDIRECT: String = "redirect"     ## mueve hasta `value` de amount a data.to (event.redirects)
const OP_CUSTOM: String = "custom"         ## llama al handler registrado en Registry (mod.handler)

## A quién afecta un modificador respecto a su `owner`.
const SIDE_ANY: String = "any"         ## A todos (eventos globales)
const SIDE_SOURCE: String = "source"   ## Solo si event.source == owner (Wild Fire: tus hechizos)
const SIDE_TARGET: String = "target"   ## Solo si event.target == owner (Tiara: daño que recibes)

## Caducidad del modificador.
const EXPIRES_WHILE_IN_PLAY: String = "while_in_play"  ## Mientras source_iid siga en mesa (artefactos)
const EXPIRES_NEXT_EVENT: String = "next_event"        ## Hasta que se robe el siguiente evento
const EXPIRES_OWNER_TURN_START: String = "owner_turn_start"  ## Al empezar el siguiente turno de owner
const EXPIRES_END_OF_TURN: String = "end_of_turn"      ## Al terminar el turno actual
const EXPIRES_SPELL: String = "spell"                  ## Al resolverse el hechizo spell_iid
const EXPIRES_ONCE: String = "once"                    ## Se consume la primera vez que se aplica
const EXPIRES_NEVER: String = "never"

# -----------------------------------------------------------------------------
# Tipos de entrada del log / eventos devueltos por reduce()
# -----------------------------------------------------------------------------

const LOG_GAME_STARTED: String = "game_started"
const LOG_TURN_STARTED: String = "turn_started"
const LOG_TURN_SKIPPED: String = "turn_skipped"        ## Freeze
const LOG_CARD_DRAWN: String = "card_drawn"            ## privado: visible_to = [quien roba]
const LOG_EVENT_DRAWN: String = "event_drawn"
const LOG_DECK_RESHUFFLED: String = "deck_reshuffled"
const LOG_CARD_PLAYED: String = "card_played"
const LOG_CARD_DISCARDED: String = "card_discarded"
const LOG_EXCHANGE: String = "exchange"
const LOG_POTION: String = "potion"
const LOG_DAMAGE: String = "damage"
const LOG_HEAL: String = "heal"
const LOG_MANA_CHANGED: String = "mana_changed"
const LOG_REACTION_OPENED: String = "reaction_opened"
const LOG_REACTION_PASSED: String = "reaction_passed"
const LOG_REACTED: String = "reacted"
const LOG_SPELL_RESOLVED: String = "spell_resolved"
const LOG_SPELL_CANCELLED: String = "spell_cancelled"
const LOG_RULE_BROKEN: String = "rule_broken"
const LOG_ELIMINATED: String = "eliminated"
const LOG_GAME_OVER: String = "game_over"
const LOG_EFFECT: String = "effect"                    ## Genérico de un efecto: data.card_id + data.what
## Se acabó el tiempo de `player` (v0.3). Público (visible_to = []). Va ANTES que
## las entradas de lo que se aplica. data: {scope:String TIMEOUT_SCOPE_*,
## resolution:String TIMEOUT_RES_*, prompt_kind:String ("" si no hay prompt),
## prompt_id:int (-1 si no hay prompt)}.
const LOG_TIMEOUT: String = "timeout"

## Motivos de eliminación (player.eliminated_reason).
const ELIM_HP: String = "hp"
const ELIM_TOO_MUCH_MANA: String = "too_much_mana"
const ELIM_CONCEDE: String = "concede"

## Causa fina de una eliminación por vida (player.eliminated_cause; "" en otros motivos).
const ELIM_CAUSE_DAMAGE: String = "damage"                  ## daño por la tubería (Damage.apply)
const ELIM_CAUSE_HP_LOSS: String = "hp_loss"                ## pérdida directa (evento, artefacto, maldición)
const ELIM_CAUSE_MANA_SHORTFALL: String = "mana_shortfall"  ## declinó PROMPT_MANA_SHORTFALL

## Hooks extra del registro de efectos (además del efecto principal).
const HOOK_CAN_PLAY: String = "can_play"     ## func(state, ctx) -> Dictionary; escribe ctx.error si no se puede
const HOOK_USE: String = "use"               ## Activación de artefacto en mesa (USE_ARTIFACT)
const HOOK_EVENT_END: String = "event_end"   ## El evento deja de estar activo
const HOOK_LEAVE_PLAY: String = "leave_play" ## Un artefacto/maldición sale de la mesa
const HOOK_TURN_START: String = "turn_start" ## Al empezar el turno del dueño de la carta en mesa
const HOOK_PROMPT: String = "prompt"             ## Respuesta (CHOOSE_*/DECLINE/USE_*) a un prompt cuyo source es la carta
const HOOK_LEGAL_ACTIONS: String = "legal_actions" ## Añade acciones legales extra a ctx.actions
const HOOK_PAY_WILDCARD: String = "pay_wildcard"  ## Comodín de pago en mesa (Scroll of Elements)
const HOOK_USE_EVENT: String = "use_event"   ## USE_EVENT sobre el evento activo
## Carta NO defensiva que puede jugarse con REACT (Lightning encadenado). fn(state, ctx)
## no muta state; pone ctx.ok = true si puede responder (ver reactions.gd).
const HOOK_CAN_RESPOND: String = "can_respond"


# =============================================================================
# CONFIGURACIÓN (state.config)
# =============================================================================

## Config por defecto (decisiones de docs/CONTEXTO-AGENTES.md). Claves exactas:
##  hand_limit:int            límite de mano base (5)
##  start_hand:int            cartas iniciales (5)
##  start_hp:int / max_hp:int vida inicial y máxima (10 / 10)
##  start_mana:int            maná inicial (0)
##  potion_mana:int           maná por poción (3)
##  potion_limit_enabled:bool K.O. por Too Much Mana activo (true)
##  potion_limit:int          pociones permitidas; beber la n.º limit+1 elimina (10)
##  pool_enabled:bool         simular el pool común de cristales (true)
##  pool_hp:int / pool_mana:int  cristales iniciales del pool (70 / 70)
##  exchange_base_cost:int    coste del 1.er intercambio; luego +1 por cada uno (1)
##  include_curse_of_rules:bool  Curse of Rules en el mazo (true; texto libre + botón)
##  turn_timeout_ms:int       plazo del turno completo de un humano local; 0 = sin límite (0).
##                            Los 30000 los pone MatchPrefs (UI), no el motor.
##  defense_timeout_ms:int    plazo por ventana de defensa o prompt fuera de mi
##                            turno; 0 = sin límite (0). MatchPrefs pone 20000.
##  reaction_timeout_local_ms:int  OBSOLETA (v0.2): solo vale como plazo de las
##                            ventanas de reacción si defense_timeout_ms == 0.
##                            0 = sin temporizador (botón "Pasar")
##  reaction_timeout_online_ms:int temporizador obligatorio en línea (15000)
##  mode:String               "local" | "online"
##  teams_enabled:bool        variante por equipos (false, v2)
##  astral_conjunction:bool   variante conjunción astral (false, v2)
##  log_limit:int             entradas máximas que se guardan en state.log (200)
##  view_log_limit:int        entradas del log que se publican en la vista (50)
static func default_config() -> Dictionary:
	return {
		"hand_limit": 5,
		"start_hand": 5,
		"start_hp": 10,
		"max_hp": 10,
		"start_mana": 0,
		"potion_mana": 3,
		"potion_limit_enabled": true,
		"potion_limit": 10,
		"pool_enabled": true,
		"pool_hp": 70,
		"pool_mana": 70,
		"exchange_base_cost": 1,
		"include_curse_of_rules": true,
		"turn_timeout_ms": 0,
		"defense_timeout_ms": 0,
		"reaction_timeout_local_ms": 0,
		"reaction_timeout_online_ms": 15000,
		"mode": "local",
		"teams_enabled": false,
		"astral_conjunction": false,
		"log_limit": 200,
		"view_log_limit": 50,
	}


## Devuelve default_config() sobrescrito con las claves de `overrides`.
static func make_config(overrides: Dictionary = {}) -> Dictionary:
	var cfg: Dictionary = default_config()
	for k: Variant in overrides:
		cfg[k] = overrides[k]
	return cfg


# =============================================================================
# DEFINICIÓN DE CARTA (catálogo data/cards.json, no va en el estado)
# =============================================================================

## Definición de un diseño de carta. Claves exactas:
##  id:String           slug (CARD_*)
##  name:String         nombre en inglés tal cual la carta
##  type:String         CARD_TYPE_*
##  element:String      ELEMENT_* (ELEMENT_NONE si no es hechizo elemental)
##  incantation:String  encantamiento de la carta ("" si no tiene)
##  text:String         texto completo del efecto (inglés)
##  cost:Dictionary     {mana:int, cards:Array[{by:REQ_*, value:String, count:int}]}
##  target:String       TARGET_*
##  quantity:int        copias físicas
##  pages:Array[int]    páginas del PDF (1-based) = nombre de imagen assets/cards/NNN.webp
##  playable:bool       entra en el mazo
##  persistent:bool     se queda en la mesa (artefactos, Curse of Rules, eventos con duración)
##  defensive:bool      se puede jugar como respuesta en la ventana de reacción
##  is_spell:bool       es un "hechizo" (abre ventana de reacción; lo afectan Force Field…)
##  notes:String        dudas/decisiones de transcripción (ver docs/AMBIGUEDADES.md)
static func make_card_def(
		id: String, name: String, type: String, element: String = ELEMENT_NONE,
		mana_cost: int = 0, card_reqs: Array = [], target: String = TARGET_NONE,
		quantity: int = 1, pages: Array = []) -> Dictionary:
	return {
		"id": id,
		"name": name,
		"type": type,
		"element": element,
		"incantation": "",
		"text": "",
		"cost": {"mana": mana_cost, "cards": card_reqs.duplicate(true)},
		"target": target,
		"quantity": quantity,
		"pages": pages.duplicate(),
		"playable": type != CARD_TYPE_NON_PLAYABLE,
		"persistent": type == CARD_TYPE_ARTIFACT,
		"defensive": type == CARD_TYPE_DEFENSIVE,
		"is_spell": type == CARD_TYPE_OFFENSIVE or type == CARD_TYPE_SUPPORT or type == CARD_TYPE_CURSE,
		"notes": "",
	}


## Requisito de carta para un coste: {by, value, count}.
static func make_card_req(by: String, value: String, count: int = 1) -> Dictionary:
	return {"by": by, "value": value, "count": count}


## Valida una definición de carta. Devuelve lista de errores ([] = válida).
static func validate_card_def(d: Dictionary) -> Array[String]:
	var errs: Array[String] = []
	var spec: Dictionary = {
		"id": TYPE_STRING, "name": TYPE_STRING, "type": TYPE_STRING, "element": TYPE_STRING,
		"incantation": TYPE_STRING, "text": TYPE_STRING, "cost": TYPE_DICTIONARY,
		"target": TYPE_STRING, "quantity": TYPE_INT, "pages": TYPE_ARRAY, "playable": TYPE_BOOL,
		"persistent": TYPE_BOOL, "defensive": TYPE_BOOL, "is_spell": TYPE_BOOL, "notes": TYPE_STRING,
	}
	_check_keys(d, spec, "card_def", errs)
	if not errs.is_empty():
		return errs
	var cid: String = d["id"]
	if not CARD_TYPES.has(d["type"]):
		errs.append("%s: type inválido '%s'" % [cid, d["type"]])
	if not ELEMENTS.has(d["element"]):
		errs.append("%s: element inválido '%s'" % [cid, d["element"]])
	if not TARGETS.has(d["target"]):
		errs.append("%s: target inválido '%s'" % [cid, d["target"]])
	var cost: Dictionary = d["cost"]
	if not (cost.get("mana") is int) or not (cost.get("cards") is Array):
		errs.append("%s: cost debe ser {mana:int, cards:Array}" % cid)
	else:
		for r: Variant in cost["cards"]:
			if not (r is Dictionary):
				errs.append("%s: requisito de coste no es Dictionary" % cid)
				continue
			var req: Dictionary = r
			if not [REQ_BY_TYPE, REQ_BY_ELEMENT, REQ_BY_CARD, REQ_ANY].has(req.get("by")) \
					or not (req.get("value") is String) or not (req.get("count") is int):
				errs.append("%s: requisito inválido %s" % [cid, str(req)])
	for p: Variant in d["pages"]:
		if not (p is int):
			errs.append("%s: pages debe contener int" % cid)
	return errs


# =============================================================================
# INSTANCIAS DE CARTA
# =============================================================================

## Carta física en la partida: {iid:int, card_id:String}. Así va en mazo,
## descarte y manos.
static func make_card_instance(iid: int, card_id: String) -> Dictionary:
	return {"iid": iid, "card_id": card_id}


## Carta en mesa (artefacto, maldición persistente, evento activo):
## {iid, card_id, owner:String ("" = centro de la mesa), data:Dictionary}.
## `data` guarda estado propio de la carta, p. ej.:
##   Curse of Rules: {"rule": "texto libre"}
##   artefactos 1 vez por turno: {"used_turn": número de turno}
static func make_table_card(iid: int, card_id: String, owner: String = "", data: Dictionary = {}) -> Dictionary:
	return {"iid": iid, "card_id": card_id, "owner": owner, "data": data.duplicate(true)}


# =============================================================================
# JUGADOR
# =============================================================================

## Jugador. Claves exactas:
##  id:String            id estable (uid en línea, "p1"… en local)
##  name:String
##  age:int              para "el mayor empieza" y Curse of the Elder/Younger
##  birth_month:int      1..12 (Curse of Even/Odd)
##  is_bot:bool
##  bot_level:String     "" o nivel de IA ("basic")
##  team:int             -1 sin equipo
##  hp:int               vida 0..config.max_hp
##  mana:int             >= 0, sin máximo
##  potions:int          pociones bebidas en la partida (Too Much Mana)
##  hand:Array           instancias {iid, card_id}  ← INFORMACIÓN OCULTA
##  artifacts:Array      cartas en mesa (make_table_card) delante del jugador
##  curses:Array         maldiciones persistentes que le afectan (make_table_card)
##  flags:Dictionary     estados temporales, claves exactas:
##     frozen:int          turnos que debe saltarse (Freeze)
##     blinded:bool        no puede lanzar ofensivas en su próximo turno (Blinding Flash)
##     force_field:String  "" o id del mago que lo lanzó; inmune a hechizos hasta el
##                         próximo turno de ese mago
##     potent_elixir:int   nº de Potent Elixir pendientes para la próxima poción
##  eliminated:bool
##  eliminated_reason:String  "" | ELIM_*
##  --- Resumen de fin (V2-06, aditivo; públicos; los escribe el motor) ---
##  turns_played:int     nº de turn_started de este jugador (incluye turnos saltados por Freeze)
##  eliminated_order:int 0 = vivo; si no, rev de la acción que lo eliminó (state.rev + 1
##                       mientras se aplica). Creciente; mismo valor = eliminación simultánea
##  eliminated_turn:int  turn.number de la eliminación (0 = vivo)
##  eliminated_by:String pid fuente del último daño/pérdida de vida que lo dejó a 0; "" si no
##                       hay mago (evento, maná insuficiente) y siempre en too_much_mana/concede
##  eliminated_card:String card_id de ese último daño ("" si no hay)
##  eliminated_cause:String "" | ELIM_CAUSE_* (solo con eliminated_reason == ELIM_HP)
static func make_player(id: String, name: String, age: int = 30, birth_month: int = 1,
		is_bot: bool = false, cfg: Dictionary = {}) -> Dictionary:
	var c: Dictionary = make_config(cfg)
	return {
		"id": id,
		"name": name,
		"age": age,
		"birth_month": birth_month,
		"is_bot": is_bot,
		"bot_level": "basic" if is_bot else "",
		"team": -1,
		"hp": int(c["start_hp"]),
		"mana": int(c["start_mana"]),
		"potions": 0,
		"hand": [],
		"artifacts": [],
		"curses": [],
		"flags": make_player_flags(),
		"eliminated": false,
		"eliminated_reason": "",
		"turns_played": 0,
		"eliminated_order": 0,
		"eliminated_turn": 0,
		"eliminated_by": "",
		"eliminated_card": "",
		"eliminated_cause": "",
	}


static func make_player_flags() -> Dictionary:
	return {"frozen": 0, "blinded": false, "force_field": "", "potent_elixir": 0}


# =============================================================================
# ESTADO COMPLETO
# =============================================================================

## Estado inicial vacío (status=setup). Game.new_game() lo rellena. Claves exactas:
##  schema_version:int
##  rev:int                  +1 por cada acción aplicada con éxito (sincronización en línea)
##  status:String            STATUS_*
##  config:Dictionary        make_config()
##  players:Array            make_player(); orden = asientos en sentido horario
##  deck:Array               instancias; ÚLTIMO = arriba          ← OCULTO (solo cuenta)
##  discard:Array            instancias; ÚLTIMO = arriba (público)
##  card_total:int           nº de cartas físicas en juego (conservación, validate_state)
##  active_event:Dictionary  {} o make_table_card() del evento activo (owner "")
##  modifiers:Array          make_modifier() activos (ver tubería)
##  pool:Dictionary          {hp:int, mana:int} cristales libres del pool común. Ganar
##                           vida/maná los toma del pool; pagar/perder los devuelve.
##  turn:Dictionary          {number:int (1..), current:String pid, phase:PHASE_*,
##                            exchanges:int (intercambios hechos este turno)}
##  reaction:Dictionary      {} si no hay ventana; si no make_reaction()
##  pending:Array            prompts make_prompt() sin resolver (FIFO)
##  reveals:Dictionary       pid -> Array de make_reveal()   ← PRIVADO por jugador
##  winners:Array[String]    ids ganadores (status=finished)
##  seq:int                  contador para ids de prompts/modificadores
##  rng_state:int            estado de Rng (0 <= x < 2^32)   ← OCULTO
##  log:Array                make_log_entry(); se recorta a config.log_limit
static func make_state(cfg: Dictionary = {}, seed_value: int = 0) -> Dictionary:
	var c: Dictionary = make_config(cfg)
	return {
		"schema_version": SCHEMA_VERSION,
		"rev": 0,
		"status": STATUS_SETUP,
		"config": c,
		"players": [],
		"deck": [],
		"discard": [],
		"card_total": 0,
		"active_event": {},
		"modifiers": [],
		"pool": {"hp": int(c["pool_hp"]), "mana": int(c["pool_mana"])},
		"turn": make_turn(),
		"reaction": {},
		"pending": [],
		"reveals": {},
		"winners": [],
		"seq": 0,
		"rng_state": posmod(seed_value, RNG_MODULUS),
		"log": [],
	}


static func make_turn(number: int = 0, current: String = "", phase: String = PHASE_DRAW) -> Dictionary:
	return {"number": number, "current": current, "phase": phase, "exchanges": 0}


# =============================================================================
# VENTANA DE REACCIÓN (state.reaction)
# =============================================================================

## Ventana abierta tras lanzar un hechizo. Claves exactas:
##  spell:Dictionary      hechizo en curso = make_spell()
##  stack:Array           respuestas jugadas (make_spell() con is_response=true), la
##                        última se resuelve primero
##  awaiting:Array[String] jugadores que aún deben decidir (REACT o PASS_REACTION).
##                        Cuando queda vacío, se resuelve la pila.
##  passed:Array[String]  quienes ya pasaron en esta ronda
##  deadline_ms:int       0 = sin plazo fijado. Lo escribe la CAPA DE SESIÓN (unix ms);
##                        el motor lo pone a 0 al empezar cada ronda nueva (tras un
##                        REACT): 0 significa "la sesión debe fijar un plazo nuevo".
##                        Helpers: Reactions.set_deadline, needs_deadline,
##                        is_expired y timeout_actions.
##                        el motor no lee el reloj. Al vencer, la sesión envía
##                        PASS_REACTION por cada jugador en `awaiting`.
static func make_reaction(spell: Dictionary, awaiting: Array = []) -> Dictionary:
	return {
		"spell": spell,
		"stack": [],
		"awaiting": awaiting.duplicate(),
		"passed": [],
		"deadline_ms": 0,
	}


## Hechizo (o respuesta) en curso. La carta está "en el aire": no está en la mano
## ni en el descarte hasta que se resuelve o se cancela. Claves exactas:
##  card:Dictionary       instancia {iid, card_id}
##  caster:String
##  targets:Array[String] pids objetivo
##  target_card:int       iid objetivo (Annihilation), -1 si no aplica
##  extra:Dictionary      parámetros de la acción (p. ej. redirect_to de Lightning)
##  is_response:bool
##  cancelled:bool        Annihilation lo marca; no se resuelve
##  data:Dictionary       estado libre del efecto. Claves usadas:
##                          payment:Array[int]  iids con los que se pagó
##                          spell_iid:int       (respuestas) iid del hechizo original
##                          responds_to:int     (respuestas) iid de la cima de la pila al jugarla
##                          damage_bonus:int    (Lightning) daño extra acumulado de la cadena
##                          lightning_source:String (Lightning) quién lanzó el último eslabón
static func make_spell(card: Dictionary, caster: String, targets: Array = [],
		extra: Dictionary = {}, is_response: bool = false, target_card: int = -1) -> Dictionary:
	return {
		"card": card.duplicate(true),
		"caster": caster,
		"targets": targets.duplicate(),
		"target_card": target_card,
		"extra": extra.duplicate(true),
		"is_response": is_response,
		"cancelled": false,
		"data": {},
	}


# =============================================================================
# PROMPTS (state.pending)
# =============================================================================

## Decisión pendiente de un jugador. Claves exactas:
##  id:int            único (state.seq)
##  player:String     quién debe responder
##  kind:String       PROMPT_*
##  source:String     card_id que lo originó ("" si es regla base)
##  optional:bool     se puede DECLINE
##  data:Dictionary   parámetros según kind (ver PROMPT_*)
##  deadline_ms:int   0 = sin límite (lo fija la sesión, como en la reacción)
static func make_prompt(id: int, player: String, kind: String, data: Dictionary = {},
		source: String = "", optional: bool = false) -> Dictionary:
	return {
		"id": id,
		"player": player,
		"kind": kind,
		"source": source,
		"optional": optional,
		"data": data.duplicate(true),
		"deadline_ms": 0,
	}


# =============================================================================
# REVELACIONES PRIVADAS (state.reveals[pid])
# =============================================================================

## Información que solo ve un jugador (Magic Hand, Twardowsky's Mirror, Icy Grasp).
##  kind:String   "hand" (mano de otro: Magic Hand) | "deck_top" (Twardowsky's Mirror)
##                | "card" (carta recibida: Icy Grasp; of = a quién se robó,
##                  cards = [la carta robada])
##  of:String     pid observado ("" para el mazo)
##  cards:Array   instancias reveladas
##  turn:int      turno en que se reveló (la UI/motor puede limpiarlas)
static func make_reveal(kind: String, of: String, cards: Array, turn: int) -> Dictionary:
	return {"kind": kind, "of": of, "cards": cards.duplicate(true), "turn": turn}


# =============================================================================
# LOG / EVENTOS
# =============================================================================

## Entrada de log (y evento devuelto por reduce()). El texto lo compone la UI en
## español a partir de `type` + `data`.
##  type:String          LOG_*
##  turn:int
##  player:String        actor principal ("" si es global)
##  data:Dictionary      parámetros (card_id, amount, target…)
##  visible_to:Array     [] = público; si no, solo esos pids lo ven
##  log_seq:int          nº de orden de la entrada en state.log (1, 2, 3…; único
##                       y creciente en la partida). 0 = aún sin numerar. Lo pone
##                       el motor al guardar la entrada (stamp_log_seq); los
##                       efectos lo dejan en 0. No confundir con state.seq (ids
##                       de prompts/modificadores). Lo usan las sesiones para
##                       emitir solo entradas nuevas y la UI para no duplicar
##                       feedback (docs/TECNICO/bus-presentacion.md).
static func make_log_entry(type: String, turn: int, player: String = "",
		data: Dictionary = {}, visible_to: Array = []) -> Dictionary:
	return {"type": type, "turn": turn, "player": player, "data": data.duplicate(true),
		"visible_to": visible_to.duplicate(), "log_seq": 0}


## Numera (log_seq) las entradas finales de `entries` que aún tienen log_seq <= 0,
## en orden, a continuación de la última numerada (o desde 1). Incluye las que
## un handler OP_CUSTOM escribió directamente en state.log. Se llama sobre
## state.log después de añadir los eventos de una acción y antes de recortarlo.
## Devuelve el último log_seq (0 si `entries` está vacío).
static func stamp_log_seq(entries: Array) -> int:
	var last: int = 0
	var first: int = entries.size()
	for i: int in range(entries.size() - 1, -1, -1):
		var n: int = int((entries[i] as Dictionary).get("log_seq", 0))
		if n > 0:
			last = n
			break
		first = i
	for i: int in range(first, entries.size()):
		last += 1
		(entries[i] as Dictionary)["log_seq"] = last
	return last


## Mayor log_seq de una lista de entradas (0 si ninguna está numerada).
static func last_log_seq(entries: Array) -> int:
	var best: int = 0
	for e: Variant in entries:
		best = maxi(best, int((e as Dictionary).get("log_seq", 0)))
	return best


# =============================================================================
# MODIFICADORES (state.modifiers): tubería de daño, coste, pociones y mano
# =============================================================================
#
# Un modificador es DATOS (serializable). Quien lo crea (artefacto, evento,
# defensiva) lo añade a state.modifiers; quien calcula (Damage, Game) llama a
# Modifiers.run_stage(state, stage, event) sin saber de dónde viene. Así T6a,
# T6b y T6c no dependen entre sí. Ejemplos:
#   Wild Fire    stage=outgoing  op=add value=1 element=fire side=source owner=pid expires=while_in_play
#   Fire Storm   stage=outgoing  op=add value=1 element=fire side=any  expires=next_event
#                + stage=cost    op=add value=1 element=fire side=any  expires=next_event
#   Tiara        stage=incoming  op=sub value=1 element=fire side=target owner=pid
#   Magic Shield stage=prevent   op=sub value=2 side=target owner=pid spell_iid=X expires=spell
#   Frozen Bunny stage=prevent   op=prevent_all side=target owner=pid spell_iid=X expires=spell
#   Mirror Shield stage=redirect op=redirect value=2 data={to:pid} spell_iid=X expires=spell
#   Spellbook    stage=hand_limit op=add value=1 side=target owner=pid
#   Shot Glass   stage=potion    op=sub value=1 side=any expires=next_event
#   Potent Elixir stage=potion   op=mul value=2 side=target owner=pid expires=once
#   Not Enough Mana stage=after_damage op=custom handler="not_enough_mana" expires=next_event

## Modificador. Claves exactas:
##  id:String           único: "<card_id>#<iid>" o "<card_id>#s<seq>"
##  stage:String        STAGE_*
##  op:String           OP_*
##  value:int           operando
##  handler:String      id del handler en Registry si op == OP_CUSTOM, si no ""
##  element:String      "" = cualquier elemento; si no ELEMENT_* que debe coincidir
##  side:String         SIDE_*
##  owner:String        pid dueño ("" global)
##  spell_only:bool     solo aplica a daño de hechizos (event.is_spell)
##  spell_iid:int       -1 = cualquiera; si no, solo al evento con ese spell_iid
##  source_card:String  card_id que lo creó
##  source_iid:int      iid de la carta que lo creó (-1 si ninguna)
##  priority:int        menor = antes dentro de la misma etapa (por defecto 0)
##  expires:String      EXPIRES_*
##  data:Dictionary     datos libres (p. ej. {"to": pid} para OP_REDIRECT)
static func make_modifier(id: String, stage: String, op: String, value: int = 0,
		owner: String = "", side: String = SIDE_ANY, element: String = "",
		expires: String = EXPIRES_WHILE_IN_PLAY, source_card: String = "",
		source_iid: int = -1) -> Dictionary:
	return {
		"id": id,
		"stage": stage,
		"op": op,
		"value": value,
		"handler": "",
		"element": element,
		"side": side,
		"owner": owner,
		"spell_only": false,
		"spell_iid": -1,
		"source_card": source_card,
		"source_iid": source_iid,
		"priority": 0,
		"expires": expires,
		"data": {},
	}


## Evento que recorre la tubería. Para daño/maná: kind="damage"|"mana_loss"; para
## coste: kind="cost"; poción: "potion"; mano: "hand_limit"; intercambio: "exchange_cost".
## Claves exactas:
##  kind:String
##  amount:int          valor que modifican las etapas
##  source:String       pid que lo causa ("" = evento/regla)
##  target:String       pid afectado (para cost/potion/hand_limit = el jugador)
##  element:String      ELEMENT_*
##  card_id:String      carta que lo causa ("" si ninguna)
##  spell_iid:int       iid del hechizo en curso, -1 si no viene de hechizo
##  is_spell:bool
##  prevented:int       total prevenido (OP_SUB / OP_PREVENT_ALL lo acumulan)
##  redirects:Array     [{to:String, amount:int}] generados por OP_REDIRECT
##  applied:Array       ids de modificadores aplicados (para log/UI)
##  data:Dictionary     libre
static func make_mod_event(kind: String, amount: int, source: String, target: String,
		element: String = ELEMENT_NONE, card_id: String = "", spell_iid: int = -1,
		is_spell: bool = false) -> Dictionary:
	return {
		"kind": kind,
		"amount": amount,
		"source": source,
		"target": target,
		"element": element,
		"card_id": card_id,
		"spell_iid": spell_iid,
		"is_spell": is_spell,
		"prevented": 0,
		"redirects": [],
		"applied": [],
		"data": {},
	}


# =============================================================================
# ACCIONES
# =============================================================================
# Claves comunes: type:String, player:String. En línea la sesión añade
# "base_rev":int (rev del estado que veía el cliente). El resto, por tipo:

## PLAY_CARD: card:int (iid en mano), targets:Array[String], payment:Array[int]
## (iids de la mano usados para pagar cartas requeridas, incl. Scroll of Elements
## en mesa), target_card:int (-1), extra:Dictionary (p. ej. {"rule": "..."}).
static func make_action_play_card(player: String, card_iid: int, targets: Array = [],
		payment: Array = [], extra: Dictionary = {}, target_card: int = -1) -> Dictionary:
	return {"type": ACTION_PLAY_CARD, "player": player, "card": card_iid,
		"targets": targets.duplicate(), "payment": payment.duplicate(),
		"target_card": target_card, "extra": extra.duplicate(true)}


## DISCARD: cards:Array[int]
static func make_action_discard(player: String, cards: Array) -> Dictionary:
	return {"type": ACTION_DISCARD, "player": player, "cards": cards.duplicate()}


## EXCHANGE: card:int
static func make_action_exchange(player: String, card_iid: int) -> Dictionary:
	return {"type": ACTION_EXCHANGE, "player": player, "card": card_iid}


## DRINK_POTION: prompt_id:int (-1 si no responde a un prompt)
static func make_action_drink_potion(player: String, prompt_id: int = -1) -> Dictionary:
	return {"type": ACTION_DRINK_POTION, "player": player, "prompt_id": prompt_id}


## END_TURN
static func make_action_end_turn(player: String) -> Dictionary:
	return {"type": ACTION_END_TURN, "player": player}


## REACT: igual que PLAY_CARD pero en la ventana de reacción.
static func make_action_react(player: String, card_iid: int, targets: Array = [],
		payment: Array = [], extra: Dictionary = {}, target_card: int = -1) -> Dictionary:
	var a: Dictionary = make_action_play_card(player, card_iid, targets, payment, extra, target_card)
	a["type"] = ACTION_REACT
	return a


## PASS_REACTION
static func make_action_pass_reaction(player: String) -> Dictionary:
	return {"type": ACTION_PASS_REACTION, "player": player}


## BREAK_RULE: player = quien denuncia, target = quien rompió la regla,
## curse:int = iid de la Curse of Rules en mesa.
static func make_action_break_rule(player: String, target: String, curse_iid: int) -> Dictionary:
	return {"type": ACTION_BREAK_RULE, "player": player, "target": target, "curse": curse_iid}


## CHOOSE_TARGETS: prompt_id:int, targets:Array[String]
static func make_action_choose_targets(player: String, prompt_id: int, targets: Array) -> Dictionary:
	return {"type": ACTION_CHOOSE_TARGETS, "player": player, "prompt_id": prompt_id,
		"targets": targets.duplicate()}


## CHOOSE_CARDS: prompt_id:int, cards:Array[int]
static func make_action_choose_cards(player: String, prompt_id: int, cards: Array) -> Dictionary:
	return {"type": ACTION_CHOOSE_CARDS, "player": player, "prompt_id": prompt_id,
		"cards": cards.duplicate()}


## DECLINE: prompt_id:int
static func make_action_decline(player: String, prompt_id: int) -> Dictionary:
	return {"type": ACTION_DECLINE, "player": player, "prompt_id": prompt_id}


## USE_ARTIFACT: card:int (iid del artefacto en mesa), targets, cards:Array[int]
## (cartas de la mano implicadas, p. ej. la que descarta Transformation Glove),
## prompt_id:int (-1 o el prompt al que responde, p. ej. Magic Cap), extra.
static func make_action_use_artifact(player: String, artifact_iid: int, targets: Array = [],
		cards: Array = [], extra: Dictionary = {}, prompt_id: int = -1) -> Dictionary:
	return {"type": ACTION_USE_ARTIFACT, "player": player, "card": artifact_iid,
		"targets": targets.duplicate(), "cards": cards.duplicate(),
		"extra": extra.duplicate(true), "prompt_id": prompt_id}


## USE_EVENT: extra:Dictionary (p. ej. {"amount": 1}), prompt_id:int
static func make_action_use_event(player: String, extra: Dictionary = {}, prompt_id: int = -1) -> Dictionary:
	return {"type": ACTION_USE_EVENT, "player": player, "extra": extra.duplicate(true),
		"prompt_id": prompt_id}


## CONCEDE
static func make_action_concede(player: String) -> Dictionary:
	return {"type": ACTION_CONCEDE, "player": player}


## TIMEOUT (solo la sesión): scope:String TIMEOUT_SCOPE_*, prompt_id:int (-1 si
## no es de prompt), expect:Dictionary con la decisión exacta que vence:
##  turn -> {"turn": int}; reaction -> {"spell_iid": int, "stack": int}; prompt -> {}.
static func make_action_timeout(pid: String, scope: String, prompt_id: int = -1,
		expect: Dictionary = {}) -> Dictionary:
	return {"type": ACTION_TIMEOUT, "player": pid, "scope": scope, "prompt_id": prompt_id,
		"expect": expect.duplicate(true)}


## Claves obligatorias por tipo de acción y su tipo Variant.
const ACTION_SPECS: Dictionary = {
	ACTION_PLAY_CARD: {"card": TYPE_INT, "targets": TYPE_ARRAY, "payment": TYPE_ARRAY, "target_card": TYPE_INT, "extra": TYPE_DICTIONARY},
	ACTION_REACT: {"card": TYPE_INT, "targets": TYPE_ARRAY, "payment": TYPE_ARRAY, "target_card": TYPE_INT, "extra": TYPE_DICTIONARY},
	ACTION_DISCARD: {"cards": TYPE_ARRAY},
	ACTION_EXCHANGE: {"card": TYPE_INT},
	ACTION_DRINK_POTION: {"prompt_id": TYPE_INT},
	ACTION_END_TURN: {},
	ACTION_PASS_REACTION: {},
	ACTION_BREAK_RULE: {"target": TYPE_STRING, "curse": TYPE_INT},
	ACTION_CHOOSE_TARGETS: {"prompt_id": TYPE_INT, "targets": TYPE_ARRAY},
	ACTION_CHOOSE_CARDS: {"prompt_id": TYPE_INT, "cards": TYPE_ARRAY},
	ACTION_DECLINE: {"prompt_id": TYPE_INT},
	ACTION_USE_ARTIFACT: {"card": TYPE_INT, "targets": TYPE_ARRAY, "cards": TYPE_ARRAY, "extra": TYPE_DICTIONARY, "prompt_id": TYPE_INT},
	ACTION_USE_EVENT: {"extra": TYPE_DICTIONARY, "prompt_id": TYPE_INT},
	ACTION_CONCEDE: {},
	ACTION_TIMEOUT: {"scope": TYPE_STRING, "prompt_id": TYPE_INT, "expect": TYPE_DICTIONARY},
}


## Valida la FORMA de una acción (no las reglas). "" si es correcta, si no
## ERR_INVALID_ACTION. Llamar tras normalize_value() si viene de JSON.
static func validate_action_shape(action: Dictionary) -> String:
	if not (action.get("type") is String) or not (action.get("player") is String):
		return ERR_INVALID_ACTION
	var t: String = action["type"]
	if not ACTION_SPECS.has(t):
		return ERR_INVALID_ACTION
	var spec: Dictionary = ACTION_SPECS[t]
	for k: Variant in spec:
		if not action.has(k) or typeof(action[k]) != int(spec[k]):
			return ERR_INVALID_ACTION
	return ERR_NONE


# =============================================================================
# RESULTADO DE reduce() Y CONTEXTO DE EFECTO
# =============================================================================

## Resultado de Game.reduce(): {state, error, events}. Si error != "", state es
## el estado de entrada sin cambios y events = [].
static func make_result(state: Dictionary, error: String = ERR_NONE, events: Array = []) -> Dictionary:
	return {"state": state, "error": error, "events": events}


## Contexto que recibe un efecto: func(state: Dictionary, ctx: Dictionary) -> Dictionary.
## Claves exactas:
##  card:Dictionary      instancia jugada {iid, card_id}
##  def:Dictionary       definición del catálogo (make_card_def)
##  caster:String
##  targets:Array        pids
##  target_card:int      iid objetivo o -1
##  payment:Array        iids usados para pagar (ya movidos al descarte)
##  extra:Dictionary     parámetros de la acción
##  spell:Dictionary     {} o el hechizo en curso (si es una respuesta: el que responde)
##  is_response:bool
##  action:Dictionary    acción original
##  error:String         el efecto escribe aquí un ERR_* para abortar (el reducer
##                       descarta todos los cambios)
##  events:Array         el efecto añade aquí make_log_entry() (el reducer las
##                       copia a state.log y las devuelve)
static func make_effect_ctx(card: Dictionary, def: Dictionary, caster: String,
		targets: Array = [], extra: Dictionary = {}) -> Dictionary:
	return {
		"card": card,
		"def": def,
		"caster": caster,
		"targets": targets.duplicate(),
		"target_card": -1,
		"payment": [],
		"extra": extra,
		"spell": {},
		"is_response": false,
		"action": {},
		"error": ERR_NONE,
		"events": [],
	}


# =============================================================================
# ACCESORES TIPADOS (evitan warnings UNSAFE_* al leer el Dictionary)
# =============================================================================

static func players_of(state: Dictionary) -> Array:
	return state["players"]


## Índice del jugador en players, o -1.
static func player_index(state: Dictionary, pid: String) -> int:
	var ps: Array = state["players"]
	for i: int in ps.size():
		var p: Dictionary = ps[i]
		if p["id"] == pid:
			return i
	return -1


## Diccionario del jugador (referencia: mutarlo muta el estado) o {} si no existe.
static func get_player(state: Dictionary, pid: String) -> Dictionary:
	var i: int = player_index(state, pid)
	if i < 0:
		return {}
	var ps: Array = state["players"]
	return ps[i]


## Ids de los jugadores no eliminados, en orden de asiento.
static func alive_ids(state: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for p: Variant in players_of(state):
		var pd: Dictionary = p
		if not bool(pd["eliminated"]):
			out.append(String(pd["id"]))
	return out


## Tamaños de zonas ocultas (regla de contrato A1, v0.3). Funcionan igual sobre
## el estado completo y sobre una vista (`is_view`): en la vista usan
## `deck_count` / `hand_count`; en el estado, `.size()`. Game.legal_actions, los
## hooks HOOK_LEGAL_ACTIONS / HOOK_CAN_RESPOND y lo que llamen solo pueden leer
## la parte pública, la mano propia de pid y reveals[pid]: para el tamaño del
## mazo o de una mano ajena usan estos helpers, nunca s.deck ni la hand ajena.

## Cartas que quedan en el mazo.
static func deck_size(s: Dictionary) -> int:
	if bool(s.get("is_view", false)) and s.has("deck_count"):
		return int(s["deck_count"])
	return (s.get("deck", []) as Array).size()


## Cartas en la mano de pid (0 si pid no existe).
static func hand_size(s: Dictionary, pid: String) -> int:
	var p: Dictionary = get_player(s, pid)
	if p.is_empty():
		return 0
	if bool(s.get("is_view", false)) and p.has("hand_count"):
		return int(p["hand_count"])
	return (p.get("hand", []) as Array).size()


## Vecinos vivos (izquierda/derecha en sentido horario) de pid. [] si está solo.
static func neighbors(state: Dictionary, pid: String) -> Array[String]:
	var alive: Array[String] = alive_ids(state)
	var i: int = alive.find(pid)
	var out: Array[String] = []
	if i < 0 or alive.size() < 2:
		return out
	var prev: String = alive[posmod(i - 1, alive.size())]
	var next: String = alive[posmod(i + 1, alive.size())]
	out.append(prev)
	if next != prev:
		out.append(next)
	return out


## Siguiente id de prompt/modificador: incrementa state.seq y lo devuelve.
static func next_seq(state: Dictionary) -> int:
	var s: int = int(state["seq"]) + 1
	state["seq"] = s
	return s


# =============================================================================
# VISTAS PÚBLICA / PRIVADA (información oculta)
# =============================================================================
# Oculto: manos ajenas, orden y contenido del mazo, rng_state, reveals ajenas y
# entradas del log con visible_to que no incluyen al jugador.
#   public_view(state)         -> lo que se publica en /rooms/{CODE}/public
#   private_view(state, pid)   -> /rooms/{CODE}/private/{pid}
#   compose_view(pub, priv, pid) -> lo que consume la UI (= view_for)
# En una vista cada jugador tiene además "hand_count":int, y el estado tiene
# "deck_count":int, "is_view":true. En public_view, todas las "hand" son [] y
# "deck" es []; rng_state = 0; reveals = {}.

static func public_view(state: Dictionary) -> Dictionary:
	var v: Dictionary = state.duplicate(true)
	v["is_view"] = true
	v["deck_count"] = (state["deck"] as Array).size()
	v["deck"] = []
	v["rng_state"] = 0
	v["reveals"] = {}
	for p: Variant in v["players"]:
		var pd: Dictionary = p
		pd["hand_count"] = (pd["hand"] as Array).size()
		pd["hand"] = []
	var limit: int = int((state["config"] as Dictionary).get("view_log_limit", 50))
	var pub_log: Array = []
	for e: Variant in state["log"]:
		var ed: Dictionary = e
		if (ed["visible_to"] as Array).is_empty():
			pub_log.append(ed.duplicate(true))
	v["log"] = pub_log.slice(max(0, pub_log.size() - limit))
	return v


## Parte privada de pid: {hand, reveals, log (entradas privadas para pid), rev}.
static func private_view(state: Dictionary, pid: String) -> Dictionary:
	var p: Dictionary = get_player(state, pid)
	var priv_log: Array = []
	for e: Variant in state["log"]:
		var ed: Dictionary = e
		if (ed["visible_to"] as Array).has(pid):
			priv_log.append(ed.duplicate(true))
	var limit: int = int((state["config"] as Dictionary).get("view_log_limit", 50))
	var reveals: Dictionary = state["reveals"]
	return {
		"hand": (p.get("hand", []) as Array).duplicate(true),
		"reveals": (reveals.get(pid, []) as Array).duplicate(true),
		"log": priv_log.slice(max(0, priv_log.size() - limit)),
		"rev": int(state["rev"]),
	}


## Une vista pública + privada de pid. pid "" = espectador (sin mano).
static func compose_view(pub: Dictionary, priv: Dictionary, pid: String) -> Dictionary:
	var v: Dictionary = pub.duplicate(true)
	if pid == "" or priv.is_empty():
		return v
	var me: Dictionary = get_player(v, pid)
	if not me.is_empty():
		me["hand"] = (priv.get("hand", []) as Array).duplicate(true)
		me["hand_count"] = (me["hand"] as Array).size()
	v["reveals"] = {pid: (priv.get("reveals", []) as Array).duplicate(true)}
	var merged: Array = (v["log"] as Array).duplicate()
	merged.append_array(priv.get("log", []) as Array)
	v["log"] = merged
	return v


## Atajo local: vista de pid directamente desde el estado completo.
static func view_for(state: Dictionary, pid: String) -> Dictionary:
	var pub: Dictionary = public_view(state)
	if pid == "":
		return pub
	return compose_view(pub, private_view(state, pid), pid)


# =============================================================================
# NORMALIZACIÓN TRAS JSON / FIREBASE
# =============================================================================

## Convierte recursivamente todo float entero (3.0) en int. Úsala sobre
## cualquier Dictionary/Array que venga de JSON.parse_string o de Firebase.
## (El estado no contiene floats por contrato.)
static func normalize_value(v: Variant) -> Variant:
	match typeof(v):
		TYPE_FLOAT:
			var f: float = v
			if is_finite(f) and f == floorf(f) and absf(f) < 9.0e15:
				return int(f)
			return f
		TYPE_DICTIONARY:
			var d: Dictionary = v
			var out: Dictionary = {}
			for k: Variant in d:
				out[str(k)] = normalize_value(d[k])
			return out
		TYPE_ARRAY:
			var a: Array = v
			var out_a: Array = []
			for x: Variant in a:
				out_a.append(normalize_value(x))
			return out_a
		_:
			return v


## Normaliza un estado que viene de JSON/Firebase: números a int y restaura las
## claves que Firebase borra (null, [] y {} vacíos) con sus valores por defecto.
## También convierte Dictionaries con claves "0","1",… en Array donde se espera
## un Array. Idempotente: normalize_state(s) == s para un estado sano.
static func normalize_state(raw: Dictionary) -> Dictionary:
	var s: Dictionary = normalize_value(raw)
	var cfg_raw: Dictionary = _as_dict(s.get("config"))
	var template: Dictionary = make_state(cfg_raw)
	_fill(s, template)
	s["config"] = make_config(_as_dict(s["config"]))
	var players: Array = _as_array(s["players"])
	for i: int in players.size():
		var p: Dictionary = _as_dict(players[i])
		_fill(p, make_player("", ""))
		p["flags"] = _filled(_as_dict(p["flags"]), make_player_flags())
		for key: String in ["artifacts", "curses"]:
			p[key] = _fill_list(_as_array(p[key]), make_table_card(-1, ""))
		p["hand"] = _as_array(p["hand"])
		players[i] = p
	s["players"] = players
	s["turn"] = _filled(_as_dict(s["turn"]), make_turn())
	s["pool"] = _filled(_as_dict(s["pool"]), {"hp": 0, "mana": 0})
	var ev: Dictionary = _as_dict(s["active_event"])
	if not ev.is_empty():
		ev = _filled(ev, make_table_card(-1, ""))
	s["active_event"] = ev
	s["modifiers"] = _fill_list(_as_array(s["modifiers"]), make_modifier("", "", ""))
	var re: Dictionary = _as_dict(s["reaction"])
	if not re.is_empty():
		re = _filled(re, make_reaction({}))
		re["spell"] = _filled(_as_dict(re["spell"]), make_spell({}, ""))
		re["stack"] = _fill_list(_as_array(re["stack"]), make_spell({}, ""))
	s["reaction"] = re
	s["pending"] = _fill_list(_as_array(s["pending"]), make_prompt(0, "", ""))
	var logs: Array = _fill_list(_as_array(s["log"]), make_log_entry("", 0))
	s["log"] = logs
	var reveals: Dictionary = _as_dict(s["reveals"])
	for k: Variant in reveals.keys():
		reveals[k] = _fill_list(_as_array(reveals[k]), make_reveal("", "", [], 0))
	s["reveals"] = reveals
	for key: String in ["deck", "discard", "winners"]:
		s[key] = _as_array(s[key])
	return s


static func _as_dict(v: Variant) -> Dictionary:
	if v is Dictionary:
		return v
	return {}


## Array tal cual; Dictionary {"0":a,"1":b} -> [a,b]; null/otros -> [].
static func _as_array(v: Variant) -> Array:
	if v is Array:
		return v
	if v is Dictionary:
		var d: Dictionary = v
		var keys: Array = d.keys()
		var idx: Array[int] = []
		for k: Variant in keys:
			var ks: String = str(k)
			if not ks.is_valid_int():
				return []
			idx.append(ks.to_int())
		idx.sort()
		var out: Array = []
		for i: int in idx:
			out.append(d[str(i)])
		return out
	return []


## Añade a `d` las claves de `template` que falten (in place). Si en `d` hay un
## Dictionary donde la plantilla espera Array (o al revés) lo corrige.
static func _fill(d: Dictionary, template: Dictionary) -> void:
	for k: Variant in template:
		var tv: Variant = template[k]
		if not d.has(k) or d[k] == null:
			if tv is Dictionary:
				d[k] = (tv as Dictionary).duplicate(true)
			elif tv is Array:
				d[k] = (tv as Array).duplicate(true)
			else:
				d[k] = tv
		elif tv is Array and not (d[k] is Array):
			d[k] = _as_array(d[k])
		elif tv is Dictionary and not (d[k] is Dictionary):
			d[k] = {}


static func _filled(d: Dictionary, template: Dictionary) -> Dictionary:
	_fill(d, template)
	return d


static func _fill_list(items: Array, template: Dictionary) -> Array:
	for i: int in items.size():
		var it: Dictionary = _as_dict(items[i])
		_fill(it, template)
		items[i] = it
	return items


# =============================================================================
# VALIDACIÓN DEL ESTADO (QA, tests, depuración)
# =============================================================================

## Comprueba la forma y los invariantes del estado. Devuelve la lista de
## problemas encontrados ([] = válido). No comprueba reglas de juego finas.
static func validate_state(state: Dictionary) -> Array[String]:
	var errs: Array[String] = []
	var spec: Dictionary = {
		"schema_version": TYPE_INT, "rev": TYPE_INT, "status": TYPE_STRING,
		"config": TYPE_DICTIONARY, "players": TYPE_ARRAY, "deck": TYPE_ARRAY,
		"discard": TYPE_ARRAY, "card_total": TYPE_INT, "active_event": TYPE_DICTIONARY,
		"modifiers": TYPE_ARRAY, "pool": TYPE_DICTIONARY, "turn": TYPE_DICTIONARY,
		"reaction": TYPE_DICTIONARY, "pending": TYPE_ARRAY, "reveals": TYPE_DICTIONARY,
		"winners": TYPE_ARRAY, "seq": TYPE_INT, "rng_state": TYPE_INT, "log": TYPE_ARRAY,
	}
	_check_keys(state, spec, "state", errs)
	if not errs.is_empty():
		return errs
	if not [STATUS_SETUP, STATUS_PLAYING, STATUS_FINISHED].has(state["status"]):
		errs.append("status inválido: %s" % state["status"])
	var rng: int = state["rng_state"]
	if rng < 0 or rng >= RNG_MODULUS:
		errs.append("rng_state fuera de rango")
	if int(state["rev"]) < 0:
		errs.append("rev negativo")
	var cfg: Dictionary = state["config"]
	for k: Variant in default_config():
		if not cfg.has(k):
			errs.append("config sin clave '%s'" % k)
	_check_keys(state["turn"], {"number": TYPE_INT, "current": TYPE_STRING,
		"phase": TYPE_STRING, "exchanges": TYPE_INT}, "turn", errs)
	_check_keys(state["pool"], {"hp": TYPE_INT, "mana": TYPE_INT}, "pool", errs)
	var pool: Dictionary = state["pool"]
	if int(pool.get("hp", 0)) < 0 or int(pool.get("mana", 0)) < 0:
		errs.append("pool negativo")
	var max_hp: int = int(cfg.get("max_hp", 10))
	var ids: Dictionary = {}
	var player_spec: Dictionary = {
		"id": TYPE_STRING, "name": TYPE_STRING, "age": TYPE_INT, "birth_month": TYPE_INT,
		"is_bot": TYPE_BOOL, "bot_level": TYPE_STRING, "team": TYPE_INT, "hp": TYPE_INT,
		"mana": TYPE_INT, "potions": TYPE_INT, "hand": TYPE_ARRAY, "artifacts": TYPE_ARRAY,
		"curses": TYPE_ARRAY, "flags": TYPE_DICTIONARY, "eliminated": TYPE_BOOL,
		"eliminated_reason": TYPE_STRING, "turns_played": TYPE_INT,
		"eliminated_order": TYPE_INT, "eliminated_turn": TYPE_INT,
		"eliminated_by": TYPE_STRING, "eliminated_card": TYPE_STRING,
		"eliminated_cause": TYPE_STRING,
	}
	for p: Variant in state["players"]:
		if not (p is Dictionary):
			errs.append("jugador no es Dictionary")
			continue
		var pd: Dictionary = p
		var before: int = errs.size()
		_check_keys(pd, player_spec, "player", errs)
		if errs.size() > before:
			continue
		var pid: String = pd["id"]
		if ids.has(pid):
			errs.append("id de jugador duplicado: %s" % pid)
		ids[pid] = true
		var hp: int = pd["hp"]
		if hp < 0 or hp > max_hp:
			errs.append("%s: hp fuera de rango (%d)" % [pid, hp])
		if int(pd["mana"]) < 0:
			errs.append("%s: maná negativo" % pid)
		if int(pd["birth_month"]) < 1 or int(pd["birth_month"]) > 12:
			errs.append("%s: birth_month fuera de 1..12" % pid)
		_check_keys(pd["flags"], {"frozen": TYPE_INT, "blinded": TYPE_BOOL,
			"force_field": TYPE_STRING, "potent_elixir": TYPE_INT}, pid + ".flags", errs)
	var turn: Dictionary = state["turn"]
	if state["status"] == STATUS_PLAYING:
		if not ids.has(turn.get("current", "")):
			errs.append("turn.current no es un jugador")
		if not [PHASE_DRAW, PHASE_MAIN, PHASE_END].has(turn.get("phase", "")):
			errs.append("turn.phase inválida")
	# Conservación de cartas: cada iid aparece una sola vez y el total cuadra.
	var seen: Dictionary = {}
	var count: int = 0
	for iid: int in all_card_iids(state):
		count += 1
		if seen.has(iid):
			errs.append("carta duplicada iid=%d" % iid)
		seen[iid] = true
	if state["status"] != STATUS_SETUP and count != int(state["card_total"]):
		errs.append("conservación: %d cartas localizadas, card_total=%d" % [count, int(state["card_total"])])
	for m: Variant in state["modifiers"]:
		var md: Dictionary = m
		if not STAGES.has(md.get("stage", "")):
			errs.append("modificador con stage inválido: %s" % str(md.get("id")))
	if not is_json_safe(state):
		errs.append("el estado contiene tipos no JSON (float, Object, claves no String…)")
	return errs


## iids de todas las cartas localizables en el estado: mazo, descarte, manos,
## artefactos, maldiciones, evento activo y hechizos en la ventana de reacción.
static func all_card_iids(state: Dictionary) -> Array[int]:
	var out: Array[int] = []
	for key: String in ["deck", "discard"]:
		for c: Variant in state[key]:
			out.append(int((c as Dictionary)["iid"]))
	for p: Variant in state["players"]:
		var pd: Dictionary = p
		for key: String in ["hand", "artifacts", "curses"]:
			for c: Variant in pd[key]:
				out.append(int((c as Dictionary)["iid"]))
	var ev: Dictionary = state["active_event"]
	if not ev.is_empty():
		out.append(int(ev["iid"]))
	var re: Dictionary = state["reaction"]
	if not re.is_empty():
		var spell: Dictionary = re["spell"]
		if not (spell.get("card", {}) as Dictionary).is_empty():
			out.append(int((spell["card"] as Dictionary)["iid"]))
		for s: Variant in re["stack"]:
			out.append(int(((s as Dictionary)["card"] as Dictionary)["iid"]))
	return out


## true si v solo contiene tipos JSON del contrato (sin floats ni objetos) y
## todas las claves de Dictionary son String.
static func is_json_safe(v: Variant) -> bool:
	# Las hojas se comprueban en línea (solo se recurre en contenedores):
	# validate_state lo llama en cada paso de las simulaciones.
	var t: int = typeof(v)
	if t == TYPE_DICTIONARY:
		var d: Dictionary = v
		for k: Variant in d:
			if typeof(k) != TYPE_STRING:
				return false
			var y: Variant = d[k]
			var ty: int = typeof(y)
			if ty == TYPE_STRING or ty == TYPE_INT or ty == TYPE_BOOL or ty == TYPE_NIL:
				continue
			if (ty != TYPE_DICTIONARY and ty != TYPE_ARRAY) or not is_json_safe(y):
				return false
		return true
	if t == TYPE_ARRAY:
		for y: Variant in (v as Array):
			var ty: int = typeof(y)
			if ty == TYPE_STRING or ty == TYPE_INT or ty == TYPE_BOOL or ty == TYPE_NIL:
				continue
			if (ty != TYPE_DICTIONARY and ty != TYPE_ARRAY) or not is_json_safe(y):
				return false
		return true
	return t == TYPE_STRING or t == TYPE_INT or t == TYPE_BOOL or t == TYPE_NIL


static func _check_keys(d: Variant, spec: Dictionary, label: String, errs: Array[String]) -> void:
	if not (d is Dictionary):
		errs.append("%s no es Dictionary" % label)
		return
	var dd: Dictionary = d
	for k: Variant in spec:
		if not dd.has(k):
			errs.append("%s: falta la clave '%s'" % [label, k])
		elif typeof(dd[k]) != int(spec[k]):
			errs.append("%s.%s: tipo %s, se esperaba %s" % [label, k,
				type_string(typeof(dd[k])), type_string(int(spec[k]))])

# Preferencia de reacción y datos del resumen de fin (V2-06)

Autor: Lead Programmer. Fecha: 2026-10-13. Entradas: `docs/diseno/preferencia-reaccion.md` (ítem 7), `docs/diseno/criterios-v02.md` §8 (ítem 8), las dos filas de `docs/ESCALADOS.md` del Game Designer (V2-07), `docs/TECNICO/bus-presentacion.md` y `docs/TECNICO/division-table.md`. Ninguna regla cambia.

## 0. Resumen de decisiones

| # | Decisión | Por qué |
|---|---|---|
| D1 | La preferencia "Avisarme de reacciones" se guarda en `user://settings.cfg` (`ConfigFile`, la misma que ya usa `Settings`), sección `reactions`, clave `notify`, valores `"affecting"` (por defecto) o `"all"`. Una por dispositivo. | Ya existe ese archivo y esa pantalla; no es una regla ni una opción de partida, así que **no** va en `config` del motor ni en `types.gd`. |
| D2 | El auto-pase lo ejecuta la **sesión** (`LocalSession`), no la mesa. La sesión recibe el modo como propiedad (`reaction_notify`), con valor por defecto `"all"` (comportamiento actual); quien crea la sesión real (`UiNav`) le pasa el valor guardado. | La sesión ya decide por los bots y lleva el temporizador. Si el auto-pase va en la sesión, el estado intermedio (C en `awaiting[0]`) **no se emite**: la mesa nunca ve ese estado, así que no hay parpadeo de "Pasa el dispositivo" ni modal, no se arranca el plazo, y los tests y la simulación (QA, R16) lo prueban sin escena. |
| D3 | La tabla "¿me afecta?" es **código**: `ReactionRelevance` en `src/ui/controllers/reaction_relevance.gd`, pura y estática, con **una entrada explícita por cada carta jugable** (no solo excepciones) y un test que recorre el catálogo. Carta sin entrada = avisar. | Es política de interfaz, no un dato mecánico. Varias reglas necesitan lógica (vecinos vivos, condición de edad/mes, destino de una redirección, dueño de `target_card`) que un campo en `data/cards.json` no expresa sin inventar un mini-lenguaje, y `cards.json` es el catálogo que comparte el motor. El test cruzado con `target` del catálogo evita que la tabla se desincronice. |
| D4 | El resumen de fin sale de **campos aditivos por jugador en el estado** que escribe el motor: `turns_played`, `eliminated_order`, `eliminated_turn`, `eliminated_by`, `eliminated_card`, `eliminated_cause` (más `potions` y `eliminated_reason`, que ya existen). **Aplicado en `types.gd`** (fila en `docs/CAMBIOS-TIPOS.md`); el motor que los rellena es tarea del Developer (T26-A). | No depende del recorte del log (C8-8), es determinista y forma parte del estado público: sirve tal cual en línea (B1), en reconexión y al reabrir "Ver resultado", sin un colector que tenga que haber visto la partida desde el primer turno. Coste: ~6 claves por jugador y 3 llamadas en el motor. Se descarta el colector `MatchSummary` alimentado por `log_seq`: solo local, se pierde si la mesa se crea tarde, y duplicaría lógica en el cliente en línea. |

## 1. Preferencia de reacción (ítem 7)

### 1.1 Almacenamiento
- Archivo `user://settings.cfg`, sección `"reactions"`, clave `"notify"`. Constantes en `ReactionRelevance`: `MODE_AFFECTING = "affecting"`, `MODE_ALL = "all"`.
- `Settings` (pantalla existente) añade un botón de dos estados "Avisarme de reacciones: solo de hechizos que me afectan / de todos" y dos funciones estáticas, para que se puedan probar sin escena:
  - `static func load_reaction_notify(path: String = PATH) -> String` (valor desconocido o ausente -> `MODE_AFFECTING`).
  - `static func save_reaction_notify(mode: String, path: String = PATH) -> void` (carga el archivo existente y solo cambia esa clave, para no borrar audio/vibración).
- Al guardar la pantalla de Ajustes hay que **cargar primero** el `ConfigFile` existente (hoy `_on_back` crea uno vacío y lo sobrescribe: perdería la clave nueva). Arreglarlo forma parte de T25-C.

### 1.2 Quién la aplica: `LocalSession`
- Propiedad nueva: `var reaction_notify: String = ReactionRelevance.MODE_ALL`. Valor por defecto `"all"` para que los tests y simulaciones existentes no cambien; `UiNav` (creación de la sesión real) asigna `Settings.load_reaction_notify()`. Se lee al crear la sesión: "Jugar otra vez" vuelve a leerla, así que se conserva.
- Punto de enganche: en `_apply`, justo después de `state = r["state"]` y **antes** de `_after_change`, un bucle acotado (máx. nº de jugadores + 1 iteraciones):
  1. `var pass: Dictionary = ReactionRelevance.auto_pass_action(Types.public_view(state), _local_ids, reaction_notify)`.
  2. Si está vacío, salir. Si no, `Game.reduce(state, pass)`; si hay error, salir (no se reintenta); si va bien, `state = r2.state`, acumular sus `events`, añadir a `history` con `by = "auto_pass"`.
  3. Repetir (el siguiente en `awaiting` puede ser otro humano local al que tampoco le afecta: R12).
  Después, un único `_after_change(eventos_acumulados)`. Con el contrato de V2-14 (eventos = entradas de log con `log_seq` nuevo) no hace falta acumular nada: `_after_change` emite todo lo nuevo del log, incluidas las entradas `reaction_passed`.
- `auto_pass_action(view, local_ids, mode)` devuelve `Types.make_action_pass_reaction(pid)` solo si se cumplen **todas**: `mode == MODE_AFFECTING`; hay ventana; `Decision.decider(view) == Decision.responder(view)` (no hay prompt pendiente antes: R14, nunca se auto-pasa un `PROMPT_*`); ese `pid` está en `local_ids` (los bots nunca entran: `_local_ids` solo tiene humanos); y `affects(view, pid) == false`. En cualquier otro caso, `{}`.
- Se evalúa sobre `Types.public_view(state)`: garantiza que la decisión no mira manos (doc. de diseño §5). Solo se calcula cuando hay ventana abierta, así que el coste de la copia es despreciable.
- **Temporizador:** como el auto-pase ocurre antes de `_update_reaction_deadline`, el humano que se auto-pasa nunca recibe plazo; el siguiente humano que sí decide recibe uno nuevo (la lógica actual de `_deadline_owner` ya lo hace). Sin cambios en `Reactions` ni en el motor.
- **Ventana y motor:** sin cambios. Para el motor es un `PASS_REACTION` normal (R1: el estado final es idéntico al pase manual salvo `rev`/`log_seq`).
- **Mesa:** no cambia su lógica de "Pasa el dispositivo" ni de modal: nunca ve el estado intermedio. La mesa (o `reaction_prompt.gd`) solo usa `ReactionRelevance.affects(view, pid)` para la banda "contra ti" (ítem 10). La línea opcional "Pasas (no iba contra ti)" queda fuera de v0.2 salvo que Narrative la pida: el registro ya muestra `reaction_passed`.
- **Sesión base:** `GameSession` no cambia de firma. Se documenta en su cabecera que una sesión puede enviar `PASS_REACTION` en nombre de un jugador local por su preferencia, igual que por plazo vencido.

### 1.3 Modo en línea (B1, futuro)
- La misma función pura `ReactionRelevance.auto_pass_action` la llama `ClientSession` con su vista compuesta y `[uid]` al recibir un estado nuevo: si devuelve una acción, la envía a `/actions` y **no** emite `reaction_opened` ni abre el modal para esa ronda (clave `iid:tamaño_pila`, igual que hoy).
- El anfitrión no conoce la preferencia de nadie ni la necesita: recibe un `PASS_REACTION` normal. Su temporizador obligatorio de 15 s sigue vigente; el auto-pase solo llega antes. En el anfitrión, para su propio uid, se usa el mismo bucle que en `LocalSession`.
- No filtra información: todo lo que mira `affects` es público, y `awaiting` ya lo era (AMBIGUEDADES T6b). La decisión de esperar o no a todos en línea (E5) sigue abierta para B1 y este diseño no la condiciona.

### 1.4 `ReactionRelevance` (contrato para el Developer)
`class_name ReactionRelevance extends RefCounted`, en `src/ui/controllers/reaction_relevance.gd`. Solo depende de `Types`, `CardCatalog` y `Decision` (misma carpeta). No conoce la sesión ni nodos.

```gdscript
const MODE_AFFECTING: String = "affecting"
const MODE_ALL: String = "all"
# Reglas (una por carta jugable). Ningún valor por defecto silencioso.
const R_TARGETS := "targets"            # receptores = targets (Fireball, Ice Bolt, Freeze, Magic Hand, Book Exchange...)
const R_TARGETS_AND_CASTER := "targets_and_caster"  # Ice Boomerang (retroceso)
const R_AREA := "area"                  # objetivo + Types.neighbors vivos (Meteor Shower, Blizzard)
const R_ALL := "all"                    # todos los vivos, incluido el lanzador (Armageddon)
const R_ALL_OTHERS := "all_others"      # todos los vivos salvo el lanzador (Electric Explosion)
const R_CONDITION := "condition"        # maldiciones por condición (Elder, Younger, Vigour, Even, Odd): quien la cumpla
const R_EVERYONE := "everyone"          # Curse of Rules
const R_CARD_OWNER := "card_owner"      # Annihilation: dueño de target_card o lanzador de lo cancelado en la pila
const R_REFLECT := "reflect_caster"     # Last Wish: lanzador del hechizo al que responde
const R_REDIRECT := "redirect"          # Mirror Shield, Lightning en cadena: destino de extra.redirect_to / targets
const R_NONE := "none"                  # beneficiosas o neutras (Heal, Magic Shield, Frozen Bunny, Force Field, artefactos...)
const RULES: Dictionary = { Types.CARD_FIREBALL: R_TARGETS, ... }  # una línea por carta

static func has_rule(card_id: String) -> bool
static func receivers(view: Dictionary, spell: Dictionary) -> Array[String]   # pids receptores de UNA carta
static func affects(view: Dictionary, pid: String) -> bool                    # spell + stack no cancelados
static func auto_pass_action(view: Dictionary, local_ids: Array[String], mode: String) -> Dictionary
```
- `affects`: `true` si `pid` está en `receivers` de `reaction.spell` o de cualquier `reaction.stack[i]` con `cancelled == false`; `true` si alguna de esas cartas no tiene regla (principio de duda, R13); `false` si no hay ventana.
- La tabla exacta de qué carta lleva qué regla es la de `docs/diseno/preferencia-reaccion.md` §2.1 y §2.2 (Heal sobre mí = `R_NONE`, decisión por defecto). Los nombres de claves de redirección se toman de `make_spell` (`extra.redirect_to` de Lightning) y del efecto de Mirror Shield; si Mirror Shield guarda el destino en otra clave, el Developer la lee de `src/engine/effects/defensive.gd` sin cambiar el motor.

## 2. Datos del resumen de fin (ítem 8)

### 2.1 Campos nuevos por jugador (aplicados en `types.gd`, aditivos)
| Clave | Tipo | Valor inicial | Significado |
|---|---|---|---|
| `turns_played` | int | 0 | nº de `turn_started` de ese jugador, incluidos los turnos perdidos por Freeze (C8-7) |
| `eliminated_order` | int | 0 | 0 = vivo. Si no, `rev` de la acción que lo eliminó (el valor que tendrá `state.rev` al terminar esa acción, es decir `state.rev + 1` mientras se aplica). Creciente en la partida; **mismo valor = eliminación simultánea** (C8-4) |
| `eliminated_turn` | int | 0 | `turn.number` en el que fue eliminado |
| `eliminated_by` | String | "" | pid de la **fuente** del último daño o pérdida de vida que lo dejó a 0 ("" si no hay mago: evento, maná insuficiente; y siempre "" en `too_much_mana` y `concede`). Puede ser el propio jugador (Armageddon, Ice Boomerang) |
| `eliminated_card` | String | "" | `card_id` de ese último daño ("" si no hay) |
| `eliminated_cause` | String | "" | Refina `eliminated_reason == hp`: `ELIM_CAUSE_DAMAGE` (daño por la tubería), `ELIM_CAUSE_HP_LOSS` (pérdida directa: evento, artefacto, maldición), `ELIM_CAUSE_MANA_SHORTFALL` (declinó el prompt de maná insuficiente). "" en los demás motivos |

Constantes nuevas en `Types`: `ELIM_CAUSE_DAMAGE = "damage"`, `ELIM_CAUSE_HP_LOSS = "hp_loss"`, `ELIM_CAUSE_MANA_SHORTFALL = "mana_shortfall"`. `normalize_state` las rellena con los valores iniciales (vía `make_player`), así que los estados antiguos o de Firebase siguen siendo válidos; `SCHEMA_VERSION` no cambia (cambio aditivo). `validate_state` comprueba sus tipos. Todo es público (ninguna clave oculta).

### 2.2 Cómo la interfaz deriva el resumen (sin leer el log)
- Clasificación: ganadores (`winners`) primero; después eliminados por `eliminated_order` **descendente**; empates de `eliminated_order` comparten posición y se ordenan por asiento (C8-4, C8-13).
- Causa y "quién" (tabla de `criterios-v02.md` §8.1, en este orden):
  1. `eliminated_reason == too_much_mana` -> "Too Much Mana", "Bebió la poción n.º {potions} (límite {config.potion_limit})".
  2. `concede` -> "Se rindió", sin golpe.
  3. `hp` y `eliminated_cause == mana_shortfall` -> "Por maná insuficiente".
  4. `hp` y `eliminated_by == id propio` -> "Se eliminó a sí mismo con {Carta}".
  5. `hp` y `eliminated_by` es otro mago -> "Golpe final: {Atacante} con {Carta}".
  6. `hp`, sin `eliminated_by` y con `eliminated_card` -> "Por {Carta}" (p. ej. Visit of the Archmage).
  7. Si no -> "Se quedó sin vida" sin línea de golpe.
- Empate "Todos los magos cayeron a la vez": `winners == []` y hay más de un jugador con el `eliminated_order` máximo.
- Turnos y pociones: `turns_played` y `potions`.
- Como todo está en el estado, "Ver resultado" (C8-11) y una mesa en línea que entre al final muestran lo mismo.

## 3. Tareas técnicas (para que el Producer ajuste V2-25 y V2-26)

### V2-25 (ítem 7) — se divide en tres
**T25-A `ReactionRelevance` (Developer).** Archivos: `src/ui/controllers/reaction_relevance.gd` (nuevo), `tests/ui/test_reaction_relevance.gd` (nuevo). Contrato: §1.4; lee `state.reaction` de una vista pública, no toca el motor. Tests: R2 a R10 y R13 como tests de la función pura `affects` sobre estados construidos con `Types` (asientos y vivos explícitos); R17: recorre todas las cartas jugables de `CardCatalog` y falla si alguna no tiene regla, y comprueba coherencia con el catálogo (`R_ALL` <-> `target == all`, `R_ALL_OTHERS` <-> `all_others`, `R_TARGETS`/`R_AREA`/`R_TARGETS_AND_CASTER` solo con objetivo de jugador; ninguna ofensiva ni maldición en `R_NONE`). Hecho: tests verdes, sin warnings.

**T25-B auto-pase en la sesión (Developer; depende de T25-A y de V2-14 parte A).** Archivos: `src/session/local_session.gd`, `src/session/game_session.gd` (solo comentario de cabecera), `tests/session/test_local_auto_pass.gd` (nuevo; o dentro de `tests/ui/test_reaction_pref.gd` si el Producer prefiere un solo archivo). Contrato: §1.2; `GameSession` sin cambios de firma; motor intacto. Tests: R1 (exactamente un `PASS_REACTION` con `by == "auto_pass"` en `history`, y estado final igual al del pase manual salvo `rev`/`log_seq`), R11 (modo `all`: no hay auto-pase), R12 (dos humanos locales: dos auto-pases, ningún `state_changed` emitido con un humano local no afectado como `responder`), R14 (prompt pendiente: no se auto-pasa), plazo: con `reaction_timeout_local_ms > 0` no se fija `deadline_ms` para el que se auto-pasa. Los 425 tests existentes no cambian (valor por defecto `all`). Hecho: suite y warnings en verde.

**T25-C Ajustes y cableado (Developer; depende de T25-A).** Archivos: `src/ui/screens/settings.gd`, `src/ui/ui_nav.gd` (asignar `reaction_notify` al crear la `LocalSession`), `src/ui/screens/reaction_prompt.gd` o `src/ui/screens/table/table_dialogs.gd` (banda "contra ti" con `ReactionRelevance.affects`, si el ítem 10 aún no la tiene), `tests/ui/test_reaction_pref.gd`. Tests: R15 (sin archivo -> `affecting`; guardar `all` en una ruta temporal y volver a cargar -> `all`; guardar no borra `audio/music`); integración: con la sesión creada por `UiNav` y un archivo con `affecting`, un Fireball entre dos bots no abre el modal al humano con Magic Shield. Hecho: verde y captura de Ajustes a 720x1280.

QA (R16): medir ventanas que ve el humano con `affecting` y con `all` en la simulación, usando `LocalSession.reaction_notify`; no requiere UI.

### V2-26 (ítem 8) — se divide en tres
**T26-A rellenar los campos en el motor (Developer).** Archivos: `src/engine/damage.gd`, `src/engine/game.gd`, `tests/engine/test_elimination_summary.gd` (nuevo). **No están en la lista actual de V2-26: el Producer debe añadirlos.** Contrato: §2.1, sin cambiar reglas ni el contenido del log.
- `Damage.eliminate(state, pid, reason, events, by := "", card_id := "", cause := "")`: escribe `eliminated_order = int(state.rev) + 1`, `eliminated_turn = turn_no(state)` y los tres opcionales.
- `_check_hp_elimination` recibe `source`, `card_id` y la causa: desde `_deal` con `ELIM_CAUSE_DAMAGE`; desde `lose_hp` con `ELIM_CAUSE_HP_LOSS`.
- En `Game` (rama `PROMPT_MANA_SHORTFALL`): si el jugador queda eliminado en ese `lose_hp`, poner `eliminated_cause = ELIM_CAUSE_MANA_SHORTFALL` y `eliminated_by = ""` (o añadir un parámetro opcional `cause` a `lose_hp`; lo elige el Developer, sin cambiar las entradas del log).
- `_start_turn`: `turns_played += 1` del jugador justo donde se emite `LOG_TURN_STARTED`.
- Tests: C8-1/C8-2 a nivel de estado (Fireball de `p2`, Too Much Mana con `potions == 11`, Lightning de `p1`), C8-4 (Armageddon: mismo `eliminated_order` para todos, `eliminated_by` = lanzador), C8-5 (concede), C8-6 (maná insuficiente y Visit of the Archmage), C8-7 (Freeze suma turno), C8-8 (`log_limit` 20 contra 100000 con la misma semilla: campos idénticos), `validate_state` vacío en cada paso, y `normalize_state` de un estado sin las claves las rellena. Las métricas base de QA (`winners`, `turn.number`) no deben cambiar con la misma semilla. Hecho: suite y warnings en verde.

**T26-B constructor puro del resumen (Developer; depende de T26-A, o usa estados construidos a mano).** Archivos: `src/ui/controllers/match_summary.gd` (nuevo, `class_name MatchSummary`, estático), `tests/ui/test_match_summary.gd` (nuevo). Contrato: `static func build(view: Dictionary, local_ids: Array[String]) -> Dictionary` -> `{title, subtitle, rows: [{pid, name, position, cause, blow, turns, potions}]}` con las reglas de §2.2 y los textos de `criterios-v02.md` §8.1 (nombres de carta desde `CardCatalog`, nunca ids). Solo lee la vista; no usa el log. Tests: C8-1 a C8-6, C8-12 (ningún texto con `_` ni claves internas), C8-13.

**T26-C pantalla de fin y "Jugar otra vez" (Developer; depende de T26-B).** Archivos: `src/ui/screens/game_over_summary.gd` (nuevo), `src/ui/screens/table/table_notices.gd`, `src/ui/ui_nav.gd` (nueva partida con `LocalSession.get_setup()` y semilla nueva), `tests/ui/test_game_over.gd` (nuevo). Contrato: módulo de la mesa según `division-table.md` (`table_notices` muestra y reabre "Ver resultado"); la pantalla recibe el `Dictionary` de `MatchSummary.build` y no lee el estado. Tests: C8-9, C8-10, C8-11, más la captura a 720x1280 con 6 jugadores.

## 4. Riesgos
- `ReactionRelevance` mal clasificada quita jugadas: por eso el principio de duda y el test de coherencia con el catálogo. QA debe revisar la tabla contra §2.1 del diseño.
- El auto-pase en la sesión cambia qué estados se emiten (se salta el intermedio). Es compatible con el bus (deduplica por `log_seq` y tolera saltos de `rev`), pero cualquier código de la mesa que cuente emisiones de `state_changed` puede notarlo.
- T26-A toca el motor: una eliminación sin pasar por `Damage.eliminate` dejaría los campos a 0. Hoy todas pasan por ahí (4 llamadas); el test de C8 lo cubre.

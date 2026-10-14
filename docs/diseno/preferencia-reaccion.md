# Preferencia "Avisarme de reacciones" (V2-07b, ítem 7 de v0.2)

Autor: Game Designer. Fecha: 2026-10-13. Origen: LINEAMIENTOS §4 ítem 7 y S1; `docs/DECISIONES.md` (2026-10-13: es un auto-pasar del jugador, no un cambio de regla) y E5 (la ventana en local espera solo a quien puede responder; **no se reabre**).

## 1. Qué es (y qué no es)
- Ajuste de la interfaz, por dispositivo: **"Avisarme de reacciones: Solo de hechizos que me afectan / De todos"**. Por defecto: **solo de hechizos que me afectan**.
- Es un **auto-pasar del jugador**: si el ajuste es "solo que me afectan" y el hechizo en curso **no me afecta**, la interfaz envía por mí `PASS_REACTION` en cuanto el motor me pide decidir, sin mostrar el modal. Para el motor es exactamente un `PASS_REACTION` pulsado a mano.
- **No cambia**: la regla del motor (`Reactions.eligible_order` y `awaiting` siguen incluyéndome si puedo responder), el orden de decisión, ni la ventana (sigue esperando a todos los `awaiting`, uno a uno). No hay cambio en `types.gd`, `reactions.gd` ni en ninguna carta. Los bots no usan el ajuste.
- Con "De todos" el comportamiento es el actual (modal siempre que puedo responder).
- Es una **decisión de la interfaz con información pública**: se calcula con lo que ya ve cualquier jugador (hechizo, objetivos, pila, mesa). Nunca mira mi mano para decidir (ver 5).

## 2. Qué cuenta como "me afecta" (contra mí)
Se evalúa **cada vez que el motor me pide decidir** (primera vez y en cada ronda nueva tras un `REACT`), sobre el estado actual de `state.reaction`: el hechizo base (`spell`) y todas las respuestas apiladas (`stack`) no canceladas.

> **Me afecta** si yo soy **receptor** de la parte negativa o de cambio de estado de **cualquier** carta del conjunto (hechizo base o respuesta apilada). Receptor = objetivo explícito, o miembro del área, o destino de una redirección, o dueño de lo que se va a descartar o robar.

Si el conjunto me incluye por cualquiera de estas vías, el modal se muestra; si no, se auto-pasa.

### 2.1 Casos que SÍ afectan
| Caso | Quién es receptor (afectado) | Origen del dato |
|---|---|---|
| Objetivo explícito de un hechizo perjudicial o que cambia mi estado (Fireball, Ice Bolt, Freeze, Icy Grasp, Mana Implosion, Paralysing Touch, Blinding Flash, Vampiric Touch, Ice Boomerang, Lightning, Electric Arc, Magic Hand, Book Exchange) | cada `targets[i]`. En Electric Arc, los dos | `spell.targets` |
| Objetivo = yo mismo (lanzo yo un hechizo perjudicial contra mí) | yo | `targets` |
| Vecino en área: Meteor Shower, Blizzard | el objetivo y los vecinos vivos del objetivo (`Types.neighbors`). El lanzador, si es vecino | `neighbors` del objetivo en el momento de evaluar. Con 2 vivos, el otro es el único vecino |
| Hechizo de todos: Armageddon (`target = all`) | todos los vivos, **incluido el lanzador** | `target` del catálogo |
| Hechizo de todos menos el lanzador: Electric Explosion (`all_others`) | todos los vivos salvo el lanzador | `target` del catálogo |
| Ice Boomerang | el objetivo, y **el lanzador** (retroceso de 1) | por carta |
| Daño redirigido: Mirror Shield de otro, Lightning encadenado | el **destino** de la redirección (`targets[0]` de la respuesta). Aparece como nueva ronda, en la que yo, destino, decido | `stack[i].targets` |
| Mano intercambiada o mirada: Book Exchange, Magic Hand | el objetivo (su mano cambia o se ve). No el lanzador | `targets` |
| Maldiciones por condición (Elder, Younger, Vigour, Even, Odd) | todo vivo que **cumpla la condición** al abrir la ventana, incluido el lanzador si la cumple (lectura literal registrada en AMBIGUEDADES). **No se descuentan** las protecciones propias (Force Field, Runic Armor): ante la duda, avisar | datos del jugador (edad, mes, vida) |
| Curse of Rules | todos los vivos (la regla de mesa les obliga) | por carta |
| Annihilation de otro contra una carta mía (artefacto, maldición activa) | yo, dueño de `target_card` | `target_card` |
| Annihilation de otro contra mi hechizo o mi respuesta en la pila | yo, lanzador de lo que se cancela | `stack`/`spell.caster` |
| Last Wish del objetivo (reflejo) | el **lanzador** del hechizo al que responde | `responds_to` |

### 2.2 Casos que NO afectan (se auto-pasan)
- Hechizos perjudiciales entre otros magos (Fireball de Bruno contra Cira) aunque yo tenga Magic Shield: **no me afectan** y no se pregunta. Es el caso principal del ítem.
- Respuestas defensivas que no tienen receptor perjudicado: Magic Shield, Frozen Bunny, Magic Capture (y Mirror Shield **si el destino no soy yo**).
- Apoyo **beneficioso o neutro sobre otro**: Heal, Greater Heal, Force Field, Potent Elixir, Space Shift (aunque afecte a mi mano si la juego yo), Scroll/artefactos.
- Mi propio hechizo cuando **no** me daña ni toca: yo lanzo Fireball a Bruno, la ventana se abre y yo (lanzador) tengo respuesta posible (por ejemplo un Lightning para encadenar si me responden): no me pregunta; si Bruno responde con Mirror Shield y me redirige el daño, sí me afecta (nueva ronda).
- Curación sobre mí (Heal que me lanza otro): beneficiosa. **Decisión por defecto**: no cuenta como "contra mí". Es criterio de interfaz (nadie reacciona a una cura, aunque Annihilation pudiera cancelarla); si el usuario prefiere avisar de toda carta que nombre al jugador, es un cambio de una línea en la tabla de la sección 6.

### 2.3 Principio de duda
Si el hechizo no tiene entrada en la tabla (carta nueva, error de datos, estado raro), **se avisa** (se comporta como "De todos"). Un auto-pasar equivocado quita jugadas al jugador; un aviso de más solo molesta.

## 3. Cuándo se evalúa y qué se envía
1. El motor deja a `awaiting[0]` = un humano local con el ajuste en "solo que me afectan".
2. La interfaz calcula `afecta_me(view, pid)` con la vista pública. Si es `false`: envía `PASS_REACTION(pid)` por la sesión (el mismo canal que el botón "Pasar"). No se abre el modal, no se pasa el dispositivo y no se arranca temporizador para ese jugador.
3. Si es `true` o hay duda: modal normal, con la banda "contra ti" del ítem 10 (esa etiqueta usa la misma función).
4. El registro muestra `reaction_passed` igual que en un pase manual; opcionalmente una línea discreta "Pasas (no iba contra ti)" solo en el registro del propio jugador, sin aviso modal ni animación. Narrative pule el texto.
5. Nunca se auto-pasa un `PROMPT_*` (decisiones de maná, descarte, Magic Cap, Mana Focus, Elixir...): el ajuste solo afecta a la **ventana de reacción**.

## 4. Hot-seat
- El ajuste es **uno por dispositivo** (Ajustes) y se aplica a **todos** los humanos locales. (Alternativa descartada: uno por jugador, que complica la pantalla de preparación; se puede añadir si se pide.)
- Cuando le toca decidir a un humano local al que el hechizo no le afecta, se auto-pasa **sin mostrar "Pasa el dispositivo"**: así el dispositivo no cambia de manos en cada hechizo ajeno (objetivo de S1). Solo se pasa el dispositivo cuando decide alguien al que sí le afecta o cuando el ajuste de ese dispositivo es "De todos".
- Si el humano al que sí le afecta no es el que sostiene el dispositivo, aparece "Pasa el dispositivo: Cira, ¿respondes al hechizo?" (ítem 10).
- La información que ve el que sostiene el dispositivo en un auto-pase es solo la pública (no se enseña la mano del que pasa).
- Mientras haya una pantalla "Pasa el dispositivo" abierta, la cola de feedback del bus sigue bloqueada (ver `docs/TECNICO/bus-presentacion.md`); el auto-pase no cambia eso.

## 5. Información oculta y partida en línea
- La evaluación usa solo `spell`, `stack`, `targets`, `caster`, jugadores y su orden de asiento: todo ello público. El motor ya revela públicamente quién tiene una respuesta posible (`awaiting`, registrado en AMBIGUEDADES T6b), así que el auto-pase **no filtra** nada nuevo: un `PASS_REACTION` es público igual que si lo hubiera pulsado.
- En línea (B1, futuro) funcionaría igual en el cliente de cada jugador, con el plazo obligatorio de 15 s: un auto-pase evita gastar el plazo. La decisión de esperar o no a todos en línea queda para B1 (E5). Este documento no la condiciona.

## 6. Dónde vive la lógica (para el Lead Programmer; viabilidad por confirmar)
- `afecta_me` debe ser una función pura (`ReactionRelevance.affects(view, pid) -> bool`) en `src/ui/controllers/`, sin tocar el motor.
- Para que la tabla 2.1 no se desincronice de los efectos reales, **la fuente de datos es el catálogo**: `target` (`single`, `other`, `two`, `all`, `all_others`, `card_in_play`) cubre casi todo; los casos que no salen de `target` (Meteor Shower y Blizzard por vecinos; Ice Boomerang por retroceso; maldiciones por condición; Last Wish; Curse of Rules) van en una lista corta de excepciones por `card_id` dentro de esa función. Pregunta abierta al Lead Programmer: si prefiere un campo de metadatos en `data/cards.json` (cambio de datos, no de efecto) o una tabla en código. Por defecto: tabla en código con un test que recorre las 58 cartas jugables y falla si hay una carta ofensiva o maldición sin entrada.
- La mesa ya expone `state.reaction`; no hace falta ningún campo nuevo en `types.gd`.

## 7. Criterios de aceptación
Estado base R0 (4 magos en orden de asiento A, B, C, D; A, B, D bots o humanos según el caso; C = humano local con `Magic Shield` en mano y 2 de maná; ajuste de C = "solo que me afectan"; turno de A).
| # | Dado / cuando / entonces |
|---|---|
| R1 | R0, A lanza Fireball contra B. Cuando se abre la ventana y el motor deja a C en `awaiting[0]`, entonces C no ve el modal, se envía exactamente un `PASS_REACTION(C)`, y el estado resultante tras cerrarse la ventana es idéntico al de pulsar "Pasar" a mano (misma comparación de `state` salvo `log_seq`/`rev`). |
| R2 | R0 pero Fireball contra C. Entonces C ve el modal con "contra ti" y se envía 0 `PASS_REACTION` automáticos. |
| R3 | R0 con los 4 vivos en orden A, B, C, D. A lanza Meteor Shower contra B (vecinos A y C): C ve el modal. A lanza Meteor Shower contra A (vecinos D y B): C se auto-pasa. Con Blizzard, igual. Con 2 vivos (A y C), Meteor Shower de A contra A: el único vecino C ve el modal. |
| R4 | R0, A lanza Armageddon: C ve el modal. A lanza Electric Explosion: C ve el modal. Con 2 vivos (A y C) y Electric Explosion de C, el lanzador C no es receptor: no hay modal para C (y para A sí). |
| R5 | R0, A lanza Lightning contra B; B responde con Lightning y redirige a C. Cuando empieza la ronda nueva, entonces C ve el modal (es destino). Si B redirige a D, C no ve el modal y se auto-pasa. |
| R6 | R0, A lanza Fireball contra B; B juega Mirror Shield redirigiendo 2 de daño a C. Entonces C ve el modal en la ronda nueva. Si el destino es A, C se auto-pasa. |
| R7 | R0, A lanza Book Exchange contra C o Magic Hand contra C: C ve el modal. Contra B: C se auto-pasa. |
| R8 | R0, A lanza Curse of the Elder y C es mayor que A: C ve el modal. Si C no cumple la condición: se auto-pasa. Con Curse of Rules: C siempre ve el modal. |
| R9 | R0, A lanza Heal sobre B: C se auto-pasa. Heal sobre C: C se auto-pasa (decisión por defecto 2.2). |
| R10 | R0, B lanza un hechizo, A responde con Annihilation contra un artefacto de C: C ve el modal. Contra un artefacto de D: se auto-pasa. |
| R11 | Ajuste de C = "De todos", mismo caso que R1: C ve el modal. |
| R12 | Hot-seat con humanos C y D en el mismo dispositivo, ambos con "solo que me afectan"; A lanza Fireball contra B y ambos tienen respuesta posible. Entonces no aparece ninguna pantalla "Pasa el dispositivo", se envían 2 `PASS_REACTION` (C y D) y el dispositivo no cambia de manos. Si el objetivo es D, solo aparece "Pasa el dispositivo" para D (y C se auto-pasa sin ella). |
| R13 | Carta sin entrada en la tabla (simulada con un `card_id` desconocido) en `spell`: el modal se muestra (principio de duda). |
| R14 | Ajuste "solo que me afectan" y prompt de maná insuficiente pendiente de C: C ve el prompt (el ajuste no actúa sobre `PROMPT_*`). |
| R15 | Valor por defecto: con la configuración de ajustes vacía, el ajuste vale "solo de hechizos que me afectan"; al cambiarlo y reiniciar la aplicación se conserva. |
| R16 | Métrica (QA, antes y después de implementarlo): en 20 partidas de 1 humano + 3 bots con semilla fija, el nº de ventanas de reacción que **ve** el humano baja con el ajuste por defecto respecto a "De todos", sin que cambie el estado final de ninguna partida (con el humano pasando siempre; comparación de `winners` y `turn.number`). |
| R17 | Test de cobertura: el recorrido de las 58 cartas jugables con un conjunto de estados de ejemplo no lanza error y no deja ninguna carta ofensiva o maldición sin clasificar. |

Los tests fijan el orden de asiento y los vivos de forma explícita; los vecinos son `Types.neighbors(objetivo)` entre vivos.

## 8. Escalado / decisión del usuario
- **No requiere decisión de reglas**: no hay efecto en el motor ni en la partida de nadie más (pasar siempre es legal).
- Pendiente solo como viabilidad técnica del Lead Programmer: dónde guardar la tabla de excepciones (6). Anotado en `docs/ESCALADOS.md`.
- Posible decisión de producto del usuario, con opción por defecto ya aplicada: ¿una cura que me lanza otro cuenta como "me afecta"? (por defecto, no).

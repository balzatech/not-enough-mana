# Criterios de aceptación v0.2: ítems 3, 4 y 8 (V2-07c)

Autor: Game Designer. Fecha: 2026-10-13. Fuente: `docs/revision/LINEAMIENTOS.md` §4 (ítems 3, 4 y 8). Sin reglas nuevas ni cambios de efectos: se describe cómo la interfaz presenta lo que el motor ya decide. Todos los criterios están escritos para convertirse en tests (QA y Developers). Convenciones:
- Jugadores `Ana`, `Bruno`, `Cira`, `Dani` = `p1..p4` en orden de asiento; "turno de Ana" = `turn.current == "p1"`, fase principal, sin `pending` ni `reaction`.
- Cartas por `card_id` del catálogo. "Elemento" = `fire`/`ice`/`electric`. Costes base de `data/cards.json`: `fire_arrow` 1 maná; `fireball` 1 maná + 1 carta de fuego; `ice_bolt` 2; `heal` 2; `lightning` 2; `scroll_of_elements` (artefacto) 2; `magic_shield` (defensiva) 2; `armageddon` 3 + fuego + hielo + electricidad.
- "Jugable" se define **solo** por el motor: una carta de la mano es jugable si `ActionOptions` (que usa `Game.legal_actions`) contiene al menos un `PLAY_CARD` con esa carta (o un `REACT` si hay ventana abierta). La interfaz no recalcula reglas.

---
## Ítem 3: cartas jugables y ficha con coste efectivo

### 3.1 Reglas de presentación
1. **Resaltado.** En el turno propio, sin prompt ni ventana, cada carta de la mano expone `playable: bool` y, si es `false`, `unplayable_reason: String` (no vacío). Las jugables y las no jugables se ven distintas (Art define el estilo; el test comprueba las propiedades y la captura lo confirma). Fuera de ese estado: si no es mi turno, ninguna se resalta y el motivo es "No es tu turno"; si hay un prompt pendiente mío, ninguna se resalta ("Resuelve primero la decisión pendiente"); si hay ventana de reacción, se resaltan las cartas con un `REACT` legal y las demás llevan "Solo puedes responder con una defensiva o un Lightning".
2. **Ficha de la carta seleccionada** (siempre visible al seleccionar, sin abrir el zoom): nombre **completo** (sin cortar ni usar elipsis), coste efectivo, tipo, elemento (si no tiene, "sin elemento"), el resumen de una línea en español (decisión E1(b), de Narrative) y, si no es jugable, el **motivo**.
3. **Coste efectivo** = maná que se pagaría ahora = `Damage.card_cost(view, pid, def, iid, false)` (incluye eventos y artefactos, nunca por debajo de 0) + las cartas requeridas del coste en el formato del ítem 4. Si el maná efectivo difiere del base, se muestra "Maná: 2 (base 1)".
4. **Motivos** (texto en español; las claves salen del error que daría `Game.check_play` con la mejor acción posible):
| Situación | `unplayable_reason` |
|---|---|
| `insufficient_mana` y la poción no basta o no se puede beber | "Cuesta N de maná y tienes M." |
| `insufficient_mana` y todavía se puede beber (límite de pociones y pool permiten llegar a N) | "Cuesta N de maná y tienes M. Bebe una poción." |
| `invalid_payment` (faltan cartas requeridas) | "Te falta 1 carta de fuego." (texto del requisito que no se puede cubrir) |
| `blinded` | "Estás cegado: no puedes lanzar ofensivas este turno." |
| Carta defensiva en turno sin ventana | "Solo se juega en respuesta a un hechizo." |
| Objetivos imposibles (todos inmunes por Force Field, etc.) | "No hay un objetivo válido." |
5. Si hay varias causas, se muestra la **primera** de la tabla (orden de arriba abajo).

### 3.2 Casos de aceptación
Estado S3-A (turno de Ana, `p1`): vida 10, maná 1, pociones 0 de 10; mano = `fire_arrow`, `fireball`, `ice_bolt`, `heal`, `magic_shield`; sin eventos ni artefactos; los 4 vivos.
| # | Cuando / entonces |
|---|---|
| C3-1 | En S3-A, `fire_arrow.playable == true` (cuesta 1, tiene 1). |
| C3-2 | En S3-A, `fireball.playable == true` (cuesta 1 de maná y paga con `fire_arrow`, que es de fuego). Su ficha muestra "Maná: 1" y "1 carta de fuego". |
| C3-3 | En S3-A, `ice_bolt.playable == false` y `unplayable_reason == "Cuesta 2 de maná y tienes 1. Bebe una poción."`; `heal` igual con su coste 2. |
| C3-4 | En S3-A, `magic_shield.playable == false`, motivo "Solo se juega en respuesta a un hechizo." (aunque tuviera maná). |
| C3-5 | S3-A pero la mano es `fireball`, `ice_bolt`, `heal` (sin otra carta de fuego): `fireball.playable == false`, motivo "Te falta 1 carta de fuego." |
| C3-6 | S3-A con evento activo `fire_storm` (el fuego cuesta +1): `fire_arrow.playable == false` (cuesta 2); su ficha muestra "Maná: 2 (base 1)" y su motivo es "Cuesta 2 de maná y tienes 1. Bebe una poción."; `fireball.playable == false`, ficha "Maná: 2 (base 1)". Con el evento sin efecto de coste (p. ej. `ice_storm`), `fire_arrow` sigue jugable con "Maná: 1" sin "(base ...)". |
| C3-7 | S3-A pero `pociones = 10` (el límite) y maná 1: `ice_bolt` motivo "Cuesta 2 de maná y tienes 1." (sin "Bebe una poción", porque la siguiente eliminaría). |
| C3-8 | S3-A con `blinded = true`: `fire_arrow`, `fireball` e `ice_bolt` no jugables con el motivo de cegado; `heal` (si el maná alcanzara) sigue siendo jugable. Con maná 2, `heal.playable == true`. |
| C3-9 | S3-A con `scroll_of_elements` equipado y mano `fireball`, `ice_bolt`, `heal`: `fireball.playable == true` (el Scroll sustituye a la carta de fuego); la ficha dice "1 carta de fuego (o tu Scroll of Elements)". |
| C3-10 | Es el turno de Bruno (`p2`): ninguna carta de Ana tiene `playable == true` y el motivo es "No es tu turno". |
| C3-11 | Ventana de reacción abierta (Bruno lanza Fireball contra Ana; Ana tiene `magic_shield`, 2 de maná): `magic_shield.playable == true`; `heal.playable == false` con el motivo de la regla 1. |
| C3-12 | **Nombre completo**: la ficha de `magic_capture`, `meteor_shower` y `elixir_transmutation` (la más larga) muestra su nombre sin recortar a 720x1280 (el texto de la ficha tiene `autowrap` y la altura se ajusta; no hay `...`). |
| C3-13 | **Coherencia con el motor**: para 50 estados generados con una semilla fija, en el turno de cada jugador, `{cartas con playable == true} == {cartas con al menos un PLAY_CARD en Game.legal_actions}` (cero diferencias). |
| C3-14 | El coste mostrado nunca es negativo: con un efecto que lo reduzca por debajo de 0, la ficha muestra "Maná: 0". |

---
## Ítem 4: pago explícito y preselección

### 4.1 Texto del pago
Formato exacto del encabezado de la barra de pago: `"{Nombre}: paga {requisitos} ({n}/{total})"`, donde `n` = cartas ya seleccionadas y `total` = nº total de cartas requeridas.
- Requisito por elemento: "1 carta de fuego", "1 carta de hielo", "1 carta de electricidad"; plural "2 cartas de fuego".
- Requisito por tipo: "1 carta de maldición", "1 carta de apoyo", "1 carta defensiva" (plural "2 cartas de maldición", "2 cartas defensivas").
- Varios requisitos distintos: se unen con coma y "y" al final, en el orden del catálogo: `armageddon` → "1 carta de fuego, 1 carta de hielo y 1 carta de electricidad".
- Si hay un Scroll equipado y utilizable: se añade al final " (o tu Scroll of Elements)".
- El maná del coste se muestra aparte ("Maná: N, se descuenta al confirmar") y no entra en el contador `(n/total)`.
- No se muestra "(0/0)": si no hay cartas requeridas no hay paso de pago.

### 4.2 Preselección
- **Combinación válida** = un conjunto de `iid` (sin orden) que aparece como `payment` en alguna acción `PLAY_CARD` legal de esa carta **con los objetivos ya elegidos** (o sin objetivos si no los lleva). El Scroll equipado cuenta como un `iid` más. Dos cartas iguales con `iid` distintos son combinaciones distintas.
- Si hay **exactamente una**: al abrir el paso de pago esas cartas ya están marcadas (`selected`), el contador marca `(total/total)` y `Confirmar` está habilitado. El jugador puede desmarcarlas; entonces `Confirmar` se deshabilita y puede volver a marcarlas.
- Si hay **más de una**: no se marca nada, el contador marca `(0/total)` y `Confirmar` está deshabilitado hasta completar una combinación válida; solo se pueden marcar cartas que formen parte de alguna combinación (las demás quedan deshabilitadas).
- Si hay **cero**: la carta no es jugable y no se llega al paso de pago.
- La preselección **no** juega la carta por sí sola: siempre hace falta confirmar. No cambia ningún efecto ni coste.

### 4.3 Casos de aceptación
Estado S4-A (turno de Ana): maná 3; mano = `fireball`, `fire_arrow`, `ice_bolt`, `heal`; sin artefactos.
| # | Cuando / entonces |
|---|---|
| C4-1 | Ana selecciona `fireball` y elige un objetivo (Bruno). El encabezado es exactamente `Fireball: paga 1 carta de fuego (1/1)` porque la única combinación válida es `{fire_arrow}`; `fire_arrow` aparece marcada y `Confirmar` está habilitado. |
| C4-2 | Siguiendo C4-1, Ana desmarca `fire_arrow`: encabezado `Fireball: paga 1 carta de fuego (0/1)` y `Confirmar` deshabilitado. Vuelve a marcarla: `Confirmar` habilitado. Ana pulsa Confirmar: se envía un `PLAY_CARD` con `payment == [iid de fire_arrow]` y `targets == ["p2"]`. |
| C4-3 | S4-A pero la mano es `fireball`, `fire_arrow`, `fire_arrow`(otro iid), `heal`: hay 2 combinaciones. Encabezado `Fireball: paga 1 carta de fuego (0/1)`; ninguna marcada; `Confirmar` deshabilitado; `ice_bolt`/`heal` no se pueden marcar. Al marcar una de las dos `fire_arrow`, `Confirmar` se habilita. |
| C4-4 | S4-A con `scroll_of_elements` equipado además de `fire_arrow` en mano: hay 2 combinaciones (`{fire_arrow}` y `{scroll}`); el encabezado termina en " (o tu Scroll of Elements)"; no hay preselección. Sin `fire_arrow` en mano, la combinación única es `{scroll}` y se preselecciona. |
| C4-5 | `armageddon` con mano de exactamente una carta de fuego, una de hielo y una eléctrica (más otras cartas de otro tipo): encabezado `Armageddon: paga 1 carta de fuego, 1 carta de hielo y 1 carta de electricidad (3/3)` y las 3 preseleccionadas. Si hay 2 cartas de fuego: `(0/3)`, nada preseleccionado. |
| C4-6 | `mana_implosion` (requiere "1 carta de maldición"), `vampiric_touch` ("1 carta de apoyo") y `mirror_shield` en reacción ("1 carta defensiva") muestran respectivamente `paga 1 carta de maldición`, `paga 1 carta de apoyo`, `paga 1 carta defensiva`. |
| C4-7 | `fire_arrow`/`ice_bolt`/`heal` (sin cartas requeridas): no hay paso de pago (no se muestra "(0/0)") y, con objetivo elegido, se puede confirmar directamente. |
| C4-8 | En una ventana de reacción, el pago de una respuesta (`mirror_shield` con otra defensiva en mano, una sola) sigue la misma regla: preselección con una combinación; sin preselección con varias. |
| C4-9 | La preselección se recalcula al **cambiar de objetivo** antes de confirmar: si con el objetivo X solo hay una combinación pero con Y hay dos, al pasar de X a Y se vacía la marcación. |
| C4-10 | **Coherencia con el motor**: en 50 estados generados (semilla fija), toda combinación que la interfaz permite confirmar es aceptada por `Game.reduce` (0 `invalid_payment`), y el nº de combinaciones que cuenta la interfaz = nº de acciones `PLAY_CARD` legales distintas para (carta, objetivos). |
| C4-11 | Texto de requisito para **todas** las cartas con coste en cartas del catálogo: un test recorre las 58 cartas jugables y comprueba que el texto generado no está vacío, no contiene `_` ni `by`/`element`, y que su número de cartas coincide con `sum(count)` de `cost.cards`. |

---
## Ítem 8: pantalla de fin con resumen

### 8.1 Qué se muestra (orden y datos)
Cuando `status == finished`:
1. **Título**: "¡Victoria!" (un humano local gana y es el único humano local), "Derrota" (un único humano local y no gana), "Gana {Nombre}" (hot-seat o ganadores no humanos), "Empate" (`winners == []`). En empate, un texto: "Todos los magos cayeron a la vez." solo si la última eliminación afectó a varios a la vez; si no, "No queda ningún mago en pie."
2. **Clasificación**: lista de **todos** los magos de 1.º a último: el ganador (o ganadores, `winners`) primero; luego los eliminados en orden **inverso** a su eliminación (el último en caer es 2.º; el primero en caer es el último). Eliminaciones simultáneas (misma acción) se listan en orden de asiento y llevan la misma posición.
3. Por cada eliminado una línea: `{Nombre} — {causa} — {quién dio el golpe}`, con la **causa** y el **golpe final**:
| Situación | Causa | Quién |
|---|---|---|
| `eliminated_reason == hp`, último daño de un hechizo de otro mago | "Se quedó sin vida" | "Golpe final: {Atacante} con {Carta}" |
| `hp`, último daño de un hechizo propio (Armageddon, Ice Boomerang contra sí, etc.) | "Se quedó sin vida" | "Se eliminó a sí mismo con {Carta}" |
| `hp`, último daño de un evento, de maná insuficiente (`hp_loss`) o sin mago origen | "Se quedó sin vida" | "Por {Evento / maná insuficiente}" |
| `too_much_mana` | "Too Much Mana" | "Bebió la poción n.º {potions} (límite {limit})" |
| `concede` | "Se rindió" | — |
| Ganador | "Último en pie" | — |
4. **Por jugador** (todos): `turnos jugados` y `pociones bebidas`. Turnos jugados = nº de `turn_started` del jugador (incluye turnos perdidos por Freeze, que empiezan y terminan). Pociones = `players[i].potions` tal como lo deja el motor: la poción que elimina por Too Much Mana **cuenta** (aparece 11 con límite 10, lo escribe tal cual: "11 (límite 10)").
5. **Botones**: "Jugar otra vez" y "Volver al menú". En partidas **locales** (1 humano + bots, o hot-seat) "Jugar otra vez" aparece siempre, sea victoria, derrota o empate. No aparece en línea hasta que B1 lo defina.
6. **Jugar otra vez**: nueva partida con **la misma configuración**: mismos jugadores (nombre, edad, mes, humano o bot, avatar, orden de asiento) y mismas opciones de partida (`potion_limit_enabled`, `potion_limit`, `pool_enabled`, vida inicial, maná de poción, preferencia de reacción), con **otra semilla** y reparto nuevo. Vuelve a empezar el mago de más edad.
7. El resumen se mantiene visible en el menú de la partida mientras `finished` (no desaparece al cerrar el diálogo): un botón "Ver resultado" lo reabre.

### 8.2 Fuente de los datos (para el Lead Programmer; ver escalado)
La interfaz necesita, por jugador: orden de eliminación, turno de la eliminación, causa y atacante final, turnos jugados y pociones. Hoy: `eliminated_reason` y `potions` están en el estado; el atacante sale del último `LOG_DAMAGE` sobre la víctima (`entry.player` = fuente, `data.card_id`); los turnos, de contar `LOG_TURN_STARTED`. El log del estado se recorta a 200 entradas y la vista a 50, así que **en partidas largas no basta con leer `state.log` al final**. Por defecto (viable ya, solo local): un colector `MatchSummary` que se alimenta de las mismas entradas de log que el bus de presentación (`log_seq`, sin duplicados) desde el primer turno. Propuesta mejor (cambio aditivo del contrato, decide el Lead Programmer): que el motor guarde por jugador `eliminated_order`, `eliminated_by` (pid y `card_id`) y `turns_played`. Los criterios de abajo no dependen de cuál se elija.

### 8.3 Casos de aceptación
Partida P8-A, 4 magos (Ana humana `p1`, Bruno, Cira y Dani bots), límite de pociones 10. Secuencia de eliminaciones (turno entre paréntesis):
1. Dani (turno 6): su vida baja a 0 por un `fireball` de Bruno (último `LOG_DAMAGE`: fuente `p2`, `card_id fireball`).
2. Cira (turno 11): bebe la poción n.º 11 → `too_much_mana`, `potions == 11`.
3. Bruno (turno 15): un `lightning` de Ana lo deja en 0.
Ana gana. Turnos jugados: Ana 5, Bruno 4, Cira 3, Dani 2. Pociones: Ana 4, Bruno 3, Cira 11, Dani 1.
| # | Cuando / entonces |
|---|---|
| C8-1 | Al pasar a `finished`, el título es "¡Victoria!" y se muestra la clasificación exacta: 1.º Ana ("Último en pie"), 2.º Bruno ("Se quedó sin vida", "Golpe final: Ana con Lightning"), 3.º Cira ("Too Much Mana", "Bebió la poción n.º 11 (límite 10)"), 4.º Dani ("Se quedó sin vida", "Golpe final: Bruno con Fireball"). |
| C8-2 | Cada jugador muestra sus turnos y pociones: Ana 5 y 4; Bruno 4 y 3; Cira 3 y "11 (límite 10)"; Dani 2 y 1. |
| C8-3 | Con una partida equivalente en la que gana Bruno (bot) y Ana cae antes, el título es "Derrota" y el ganador sigue primero en la lista. Con 2 humanos locales (hot-seat) y gana uno: título "Gana {Nombre}". |
| C8-4 | Empate: Armageddon deja a todos los vivos a 0 en la misma acción (`winners == []`): título "Empate", texto "Todos los magos cayeron a la vez.", los eliminados simultáneos comparten posición y se listan en orden de asiento; la causa es "Se quedó sin vida" y el golpe final es "Se eliminó a sí mismo con Armageddon" para el lanzador y "Golpe final: {Lanzador} con Armageddon" para los demás. |
| C8-5 | Rendición (`CONCEDE`) de Ana con 3 jugadores: su línea dice "Se rindió" sin golpe final. |
| C8-6 | Eliminación por maná insuficiente (la víctima declina la poción y pierde la vida que le falta): causa "Se quedó sin vida", quién "Por maná insuficiente". Por `visit_of_the_archmage`: "Por Visit of the Archmage". |
| C8-7 | Turno perdido por Freeze: Bruno es congelado y pierde un turno; su contador de turnos jugados sube en 1 (el turno empieza y acaba). |
| C8-8 | Partida larga: con `log_limit = 20` (se recorta el log) y 3 bots + Ana, el resumen al final tiene las mismas 4 filas, y los mismos valores que con `log_limit = 100000` y la misma semilla (el resumen no depende del recorte). |
| C8-9 | "Jugar otra vez" aparece en victoria, derrota y empate en local, en la captura a 720x1280 sin desplazarse. Al pulsarlo: nueva sesión con `players` idénticos en nombre, edad, mes, humano/bot y orden; `config` idéntica salvo la semilla; vida 10, maná 0, pociones 0, `turn.number == 1`, mano de 5; el diálogo de fin ya no está y `is_game_over_shown() == false` hasta que vuelva a terminar. |
| C8-10 | Con `potion_limit_enabled = false` en la partida original, la nueva también lo tiene; con límite 6, también 6; la frase de Too Much Mana usa ese límite. |
| C8-11 | El diálogo se cierra con "Volver al menú" sin errores; en la mesa terminada, "Ver resultado" reabre exactamente el mismo resumen. |
| C8-12 | Ningún texto del resumen contiene `_` ni claves internas (`too_much_mana`, `hp`) y todo cabe a 720x1280 con 6 jugadores (lista desplazable, cabecera y botones fijos). |
| C8-13 | Número de filas = número de jugadores de la partida (3 a 6) y cada jugador aparece exactamente una vez; la unión de posiciones es 1..N sin huecos (con empates por eliminación simultánea se permiten posiciones repetidas y se salta la siguiente). |

## Escalados y decisiones
- Fuente de datos del resumen (8.2): viabilidad técnica del Lead Programmer. Opción por defecto: colector en la interfaz/sesión local; opción mejor: campos aditivos en el estado. Registrado en `docs/ESCALADOS.md`.
- No hay decisiones de reglas para el usuario. Aclaración de producto con valor por defecto ya aplicado: si todos los humanos son eliminados y quedan solo bots, no se muestra el resumen hasta que termine la partida (el ítem de los eliminados espectadores es D4/v0.3).

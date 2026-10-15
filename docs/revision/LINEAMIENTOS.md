# Lineamientos tras la revisión del MVP local (v0.2 "Mesa legible")

Autor: Game Director. Fecha: 2026-10-13. Petición del usuario: que el juego sea **más divertido** y tenga **mejor UX/UI**.
Visión de referencia: `docs/VISION.md`. Decisiones: `docs/DECISIONES.md`. Preguntas al usuario: `docs/ESCALADOS.md`.

## 0. Límites de esta revisión (léelos antes de usar el documento)
- **No he tenido Bash.** No pude arrancar el juego, ejecutar tests ni simulaciones, ni generar capturas nuevas. Trabajé con las 12 capturas de `docs/revision/capturas/`, el código de `src/ui/**`, `src/session/local_session.gd`, `src/ai/bot.gd` (cabecera), las reglas y los documentos de decisiones.
- **No he jugado.** Todo lo que digo sobre la diversión es un juicio a partir de las reglas, las capturas y el código. Lo marcado **[VALIDAR]** debe comprobarlo el usuario en M12 o el QA Agent jugando.
- Capturas que creía que faltaban pero sí están: la **pantalla de victoria** sale en `partida-midgame.png` y el **aviso de evento** en `mesa-3j.png`, `mesa-6j.png` y `mesa-4j-720x1280.png` (por eso esas tres mesas aparecen tapadas por el aviso). Siguen faltando los **prompts del motor** (maná insuficiente, Magic Cap, Mana Focus, Elixir, descarte forzado) y el **zoom de carta**: de ellos opino solo por el código.
- Métricas que no pude recoger: duración real por partida (en turnos y minutos), cartas que nunca se juegan, reparto de victorias por asiento y número de ventanas de reacción que recibe un humano por partida. Se piden a QA (sección 3).

## 1. Diagnóstico

### 1.1 Lo que funciona (verificado)
- **Las reglas están completas y bien cubiertas:** 58 diseños con efecto, ventana de reacción con cadena de Lightning, eventos, artefactos, 425 tests y 0 acciones ilegales en las simulaciones (dato del integrador).
- **La mesa vertical está bien planteada** (capturas `partida-*`): rivales arriba, mazo, descarte y evento en el centro, tu panel, las acciones y la mano abajo. Se ve el turno de quién es ("Turno de Cira") y el texto "Esperando a Cira (turno)…".
- **La UI no deja hacer nada ilegal:** todo sale de las acciones legales (`ActionOptions`) y las cartas no jugables explican por qué (`table.gd::_unplayable_reason`, p. ej. "cuesta 2 de maná y tienes 1. Bebe una poción.").
- **"Intercambiar (n)" muestra el coste creciente** y beber no interrumpe una jugada a medias.
- **Hay aviso antes de la poción que elimina** y el botón se pone rojo cuando la siguiente poción te eliminaría (`_drink_would_eliminate`).
- **La ventana de reacción es clara** (`partida-reaction.png`): "Bruno lanza Ice Bolt contra Ana", la carta entrante, tus respuestas legales resaltadas, Beber poción, Pasar y barra de tiempo.
- **El hot-seat oculta la mano** con "Pasa el dispositivo / Soy Cira" (`partida-hotseat.png`).
- **Los eventos se anuncian** con un aviso modal y la carta grande.
- **Hay pantalla de fin** con Victoria, Derrota o Empate, y "Jugar otra vez" cuando la sesión lo permite.

### 1.2 Lo que no funciona o falla (verificado con evidencia)
| # | Problema | Evidencia |
|---|---|---|
| P1 | **No hay feedback de lo que pasa.** La vida, el maná y los estados cambian sin animación, número flotante, destello ni sonido. Con bots jugando cada 0,6-0,9 s, el humano no sabe qué le han hecho. | `player_panel.gd` reconstruye el panel con los valores nuevos y no hay nada más; no existe `assets/audio` ni `src/audio`. |
| P2 | **El registro enseña una sola línea**, y cuando un bot hace varias acciones solo se ve la última. Además se ha visto una clave interna en pantalla. | `action_log.gd` (franja = última línea). `partida-midgame.png`: "Registro: Icy Grasp: card_stolen_private". `log_text.gd` ya traduce esa clave, así que puede ser una captura antigua o un tipo de entrada distinto: **QA debe confirmarlo**. |
| P3 | **No se distingue qué cartas puedes jugar.** En la fase normal todas las cartas tienen el mismo aspecto: hay que tocarlas una a una para saberlo. | `table.gd::_refresh_hand` solo marca deshabilitadas durante el pago o al elegir cartas. |
| P4 | **El pago no dice qué hace falta.** "Fireball: paga con 1 carta(s) (0/1)" no dice que sea una carta de fuego. | `partida-payment.png`; `_update_mode_bar`. |
| P5 | **Las cartas no se leen en el celular.** En la mano en abanico los nombres quedan cortados ("HEAI", "MAGIC CAPT") y el texto de la carta es inglés de unos 6 px; el zoom es una pulsación larga que no se explica en ningún sitio. | `partida-start.png` y `partida-payment.png`; `card_view.gd` (pulsación larga o doble toque, sin pista). |
| P6 | **La interfaz muestra cosas que no funcionan.** "Crear sala" abre una sala falsa "ABCD" y "Unirse con código" lleva a la misma maqueta; los ajustes de Música y Efectos no hacen nada porque no hay audio. | `main_menu.gd::_on_create` (`"code": "ABCD"`); `settings.png`. |
| P7 | **Un bot se eliminó solo por Too Much Mana teniendo 23 de maná.** En la partida de la captura, Cira acaba ELIMINADA con 8 de vida, 23 de maná y 11 pociones (límite 10). Con vida > 0, la única causa posible es la poción número 11. | `partida-midgame.png`. **[VALIDAR]** con la semilla. |
| P8 | **El fin de partida es pobre.** "¡Has ganado, Ana!" y un botón. No dice cómo cayó cada uno ni quién eliminó a quién, que es justo lo que el grupo comenta. En la captura no aparece "Jugar otra vez". | `partida-midgame.png`; `_check_game_over`. |
| P9 | **Hay textos demasiado pequeños para el móvil:** las etiquetas de estado (TURNO, Congelado, Cegado, Escudo, Bot) usan 17 px a 1080 de ancho (≈ 8,5 px en un celular de 540). | `player_panel.gd::_rebuild` (`label(t, 17, …)`). |
| P10 | **El aviso de evento no explica el efecto en español:** dice solo "Fire Storm entra en juego." y la carta está en inglés. Después, el evento activo es solo una carta pequeña en el centro. | `mesa-6j.png`; `_queue_event_notices`. |
| P11 | **No hay ayuda ni onboarding.** No existe "Cómo se juega" en el menú ni en la partida. | `main_menu.gd`, `table.gd::_on_menu`. |

### 1.3 Lo que supongo y hay que medir
- **S1 Demasiadas interrupciones por reacción.** Hay 11 Magic Shield y 5 Mirror Shield en el mazo, y pueden proteger a cualquiera. Un humano que tenga una y 2 de maná recibirá probablemente un modal en casi cada hechizo de la mesa, aunque no vaya contra él. En hot-seat, además, obliga a pasar el dispositivo. **[VALIDAR]**: QA debe contar las ventanas que recibe cada humano por partida.
- **S2 La partida puede alargarse.** Unas 161 acciones de media; no sé cuántos turnos ni cuántos minutos son con humanos. Para una mesa social, mi objetivo es de **15 a 25 minutos con 4 jugadores**. **[VALIDAR]** en M12.
- **S3 Los turnos de los bots no se pueden seguir.** Con 3 bots, cada uno puede hacer varias acciones en pocos segundos y el humano solo ve el resultado (consecuencia de P1 y P2).
- **S4 Hay maná de sobra.** Cira acumuló 23 de maná, lo que sugiere que los bots beben de más. Que el maná "no alcance" es el tema del juego: si sobra, se pierde tensión. **[VALIDAR]** con métricas de maná medio y pociones por partida.
- **S5 La pantalla "Pasa el dispositivo" no da contexto:** no dice si se pasa por un turno o por una reacción.

## 2. Pilares

### Diversión
1. **D1 Caos legible.** Que pasen cosas está bien; que no se entiendan, no. *Ejemplo actual:* Bruno te lanza Ice Bolt, pierdes 1 de vida y una carta, y solo lo sabes si estabas mirando tu contador o abres el registro.
2. **D2 Riesgo visible con las pociones.** *Ejemplo actual:* el contador "(4/10)" está en el botón y el chip verde de cada rival, pero el riesgo solo se marca cuando ya estás en 10/10.
3. **D3 Reacción como clímax, no como trámite.** *Ejemplo actual:* el modal de reacción está bien, pero salta también con hechizos ajenos cuando solo tienes un escudo genérico (S1).
4. **D4 Ritmo sin tiempos muertos.** *Ejemplo actual:* hay que tocar el botón "Continuar" en cada evento; los eliminados solo pueden mirar.

### UX/UI
1. **U1 Sé qué puedo hacer y qué me cuesta.** *Ejemplos:* P3 y P4.
2. **U2 Sé qué pasó.** *Ejemplos:* P1, P2 y P8.
3. **U3 Legible a una mano en un celular.** Referencia 1080×1920 y comprobación a 720×1280. *Ejemplos:* P5 y P9.
4. **U4 Interfaz honesta y en español.** No se enseña lo que no funciona (P6); la ayuda es en español, sin tocar el texto ni el arte de las cartas (P10 y P11).

## 3. Lineamientos por rol
Todos los criterios se comprueban con un test, una captura en `docs/revision/` o una métrica de simulación. "1080 px" se refiere al ancho de referencia.

**Game Designer**
- Especifica el contenido de "Cómo se juega" (una pantalla: objetivo, turno, pago, pociones y Too Much Mana, defensivas, eventos) y los textos de ayuda contextual. Hechos: todo sale del manual o de `REQUERIMIENTOS.md` §1 y no hay reglas nuevas.
- Define la preferencia "Avisarme de reacciones: solo contra mí / siempre" (sección 4, ítem 7) como **auto-pasar del jugador, sin cambiar la regla**, y deja claro qué cuenta como "contra mí" (objetivo, vecino en área, daño redirigido).
- Prepara para el usuario la propuesta de **Conjunción astral** como opción (variante oficial del manual) con criterios de aceptación.
- Criterio: cada especificación incluye casos de aceptación verificables y no cambia ningún efecto de carta.

**Lead Programmer**
- Diseña un **bus de eventos de presentación**: a partir de los `events` de `state_changed`, la UI encola animaciones (daño, curación, maná, poción, carta jugada, eliminado) sin bloquear el motor. Debe servir igual en local y en línea.
- Decide si la mesa sigue reconstruyendo todos los nodos en cada `_refresh` o pasa a actualizarlos de forma incremental (riesgo de tirones cuando haya animaciones). La decisión es técnica y suya; que quede en `docs/ARQUITECTURA.md`.
- Criterio: en 1 partida de 4 jugadores, cada entrada `LOG_DAMAGE`, `LOG_HEAL`, `LOG_MANA_CHANGED`, `LOG_POTION` y `LOG_ELIMINATED` produce exactamente 1 feedback (comprobado con un test de integración).

**Developer**
- Implementa los ítems imprescindibles de la UI (sección 4: 1-8 y 10-12) en `src/ui/**` según las tareas del Producer.
- Criterios: los de cada ítem de la sección 4, más `bash tools/test.sh` en verde y `bash tools/check_warnings.sh` → OK.

**Art**
- Iconos de estado legibles (congelado, cegado, campo de fuerza, maldito) que sustituyan las etiquetas de texto de 17 px, y un marco o indicador para "carta jugable" y para "evento activo".
- No modifica las imágenes de las cartas (© SUPERHOTEX).
- Criterio: cada icono se distingue a 48×48 px en la captura de 720×1280.

**Technical Artist**
- Tema: tamaños mínimos de fuente (≥ 22 px a 1080) y de botones (≥ 96 px de alto a 1080, ≈ 48 dp). Destello o tinte del panel al recibir daño o curación, y números flotantes. Todo compatible con el renderizador Compatibility (Web).
- Criterio: 60 fps en escritorio durante el turno de 3 bots con animaciones (medido por Performance) y 0 textos menores de 22 px en las capturas de mesa.

**Audio** — *después (v0.3)*. Ahora no aplica, salvo que **los ajustes de volumen se ocultan hasta que exista audio** (lo hace el Developer). Cuando toque: efectos sintetizados o propios (daño, curación, poción, evento, reacción, victoria), desactivados por defecto; nada con copyright.

**Narrative**
- Escribe en español los textos de interfaz: registro (sin claves internas), pistas, "Cómo se juega", errores, pantalla de fin y "Pasa el dispositivo" con contexto ("Turno de Cira" o "Cira: ¿respondes al hechizo?").
- No traduce ni reescribe el texto de las cartas mientras el usuario no decida (escalado E1).
- Criterio: un test recorre todos los tipos de log y todos los `what` de `LOG_EFFECT` y comprueba que ninguno devuelve un texto con `_` ni el genérico "efecto aplicado".

**Level Designer** — composición de la mesa para 5 y 6 jugadores (rivales legibles a 720×1280). El tutorial guiado con mazo preparado queda **para después**.

**AI Programmer**
- Un bot nunca bebe voluntariamente la poción que le elimina (P7) y no acumula maná muy por encima de lo que puede gastar (S4).
- Usa `randomness` > 0 en partidas con humanos para que los bots no sean predecibles.
- Criterios en 200 partidas simuladas: 0 eliminaciones de bots por Too Much Mana sin un prompt que les obligara; ≥ 98 % de partidas terminadas (sin empeorar); maná medio al final del turno de un bot ≤ 8 (umbral provisional, se ajustará con datos).

**QA**
- Confirma P2 (clave interna en el registro) y P7 (bot suicida) con semilla reproducible.
- Añade a la simulación estas métricas, que faltan para decidir: turnos por partida, acciones por turno, cartas jugadas por diseño (y cuáles nunca), victorias por asiento, ventanas de reacción por jugador y por partida (S1) y maná y pociones medios.
- Genera las capturas que faltan en `docs/revision/capturas/`: prompts del motor, zoom de carta y mesa de 6 sin aviso.
- Prepara el guion de la prueba M12 para el usuario (1 partida de 1 humano + 3 bots y 1 de hot-seat de 3) con estas preguntas: ¿supiste siempre qué te pasó?, ¿cuánto duró?, ¿cuántas veces te interrumpió la reacción?, ¿qué te aburrió?

**Performance**
- Mide el tiempo de fotograma en el turno de 3 bots antes y después del feedback animado, en escritorio y en Web. Presupuesto: 16 ms. Repítelo en Android cuando exista la build (M14).

**Producer**
- Convierte la sección 4 en tareas de v0.2 en `docs/TAREAS.md`, en este orden: primero las victorias rápidas (6, 2, 4, 9), después la lectura del juego (1, 3, 5), luego el flujo (7, 8) y al final la ayuda (10, 11).
- Ajusta `docs/BACKLOG.md`: v0.2 va antes que B1 (ver `docs/DECISIONES.md`).

**Build & Release** — ahora no aplica. Para la prueba en el celular (M12/M13) hace falta una build Android de depuración (bloqueada por M14). **Nada de hosting público** (la URL expondría el arte).

## 4. Prioridades

### Imprescindible para v0.2 (en orden)
| # | Mejora | Por qué | Hecho cuando |
|---|---|---|---|
| 1 | **Feedback de cambios en los paneles:** número flotante (−2, +1, +3 de maná), destello del panel afectado y aviso breve "Bruno → Fireball → Ana". | Sin esto el caos no se entiende (D1, P1). Es la mejora con más impacto en la diversión. | Cada daño, curación, cambio de maná, poción y eliminación se ve en el panel afectado durante ≥ 1 s (test de integración y captura). |
| 2 | **Registro de 3 líneas y sin claves internas**, con el nombre de los magos resaltado; al tocarlo se despliega como ahora. | Para seguir los turnos de los bots (P2, S3). | Se ven las 3 últimas entradas; pasa el test de textos de Narrative. |
| 3 | **Resaltar las cartas jugables** en tu turno y **ficha de la carta seleccionada**: nombre completo, coste efectivo (con eventos y artefactos), tipo y elemento, y el motivo si no se puede jugar. | Ahora hay que tocar carta por carta (U1, P3, P5). | Con un estado de prueba, las cartas jugables y no jugables se ven distintas; la ficha muestra el coste efectivo correcto con Fire Storm activo (test). |
| 4 | **Pago explícito:** "Fireball: paga 1 carta de fuego (0/1)"; si solo hay una combinación válida, se preselecciona. | Menos dudas y menos toques (U1, P4). | Test: el texto incluye el requisito por tipo o elemento; con una única combinación válida, Confirmar ya está activo. |
| 5 | **Cartas legibles:** botón o icono "Ver" visible en la carta seleccionada (además de la pulsación larga) y la primera vez una pista "Mantén pulsada una carta para verla". | El texto de la carta es la regla; hoy no se puede leer en el móvil (P5). | Captura 720×1280 con una carta seleccionada y su "Ver"; el zoom se abre con un toque. |
| 6 | **Interfaz honesta:** ocultar "Crear sala" y "Unirse con código" (o mostrarlos deshabilitados como "Próximamente") y ocultar Música y Efectos mientras no haya audio. | Hoy llevan a una maqueta falsa (P6, U4). | Captura del menú y de Ajustes sin opciones muertas. |
| 7 | **Preferencia de reacción:** "Avisarme: solo de hechizos que me afectan / de todos" (por defecto, "solo que me afectan"). Es un auto-pasar del jugador; la regla no cambia. | Menos interrupciones y menos pases de dispositivo (D3, S1). | Con "solo que me afectan", un Fireball entre dos bots no abre el modal al humano aunque tenga Magic Shield (test). Métrica de QA antes y después. |
| 8 | **Pantalla de fin con resumen:** orden de eliminación, causa (vida o Too Much Mana) y quién dio el golpe final, turnos jugados y pociones de cada uno; "Jugar otra vez" con la misma configuración siempre visible en local. | Es lo que el grupo comenta y pide la revancha (P8). | Captura de fin con el resumen; "Jugar otra vez" repite jugadores y opciones (test). |
| 9 | **Bots sin suicidio y con menos acaparamiento:** criterios del AI Programmer. | Un bot que se elimina solo rompe la partida y la credibilidad (P7, S4). | Métricas en 200 simulaciones (ver AI Programmer). |
| 10 | **Contexto y riesgo:** el botón de poción cambia de color desde *límite − 2* (8/10), "contra ti" en el modal de reacción, y "Pasa el dispositivo" dice el motivo (turno, reacción o decisión). | D2, S5. | Tests de texto y de color; captura en 8/10. |
| 11 | **"Cómo se juega"** en el menú principal y en el menú de la partida (una pantalla con desplazamiento), y el aviso de evento con la duración "hasta el próximo evento". | No hay onboarding (P11, P10). | Captura de la pantalla de ayuda; textos revisados por el Game Designer contra el manual. |
| 12 | **Legibilidad móvil:** ≥ 22 px a 1080, iconos de estado en lugar de etiquetas de 17 px y botones ≥ 96 px. | U3, P9. | Revisión de capturas a 1080×1920 y 720×1280 con 3 y 6 jugadores. |

### Después (v0.3 en adelante)
- **Multijugador en línea (B1).** Sigue siendo importante, pero va después de v0.2 porque todos los fallos de UX se multiplican en red, y además está bloqueado por M3-M5.
- **Conjunción astral** como opción (variante oficial): da algo que hacer a los eliminados (D4). Depende del usuario (E4).
- **Audio** (efectos sintetizados, desactivado por defecto) y **vibración** al recibir daño en Android.
- **Animaciones de cartas** (robar, jugar, descartar) y **efectos por elemento** (fuego, hielo, rayo).
- **Tutorial guiado** con mazo preparado (Level Designer y Narrative).
- **Velocidad de bots** configurable (Normal / Rápido) y bots con distintos estilos.
- **Variante por equipos.**
- **Ficha en español** de cada carta, si el usuario la aprueba (E1).

### Descartado
- **Rediseñar cartas o reglas, o crear cartas nuevas:** son de SUPERHOTEX; los cambios de regla solo los decide el usuario.
- **Publicar** en tiendas o en hosting público, o subir assets a repositorios públicos: contradice los derechos.
- **Chat de texto en la partida, cuentas, clasificaciones, progresión o monetización:** el grupo habla en persona o por voz; alto coste y poco valor.
- **Contar o fomentar el alcohol real:** fuera de la visión.
- **Esperar siempre a todos en la ventana de reacción en local:** en hot-seat obligaría a pasar el dispositivo en cada hechizo (ver E5).

## 5. Decisiones que necesito del usuario
Están registradas en `docs/ESCALADOS.md` con sus opciones.
- **E1 Ficha en español de las cartas** (es traducir texto © para uso personal). Opciones: (a) solo datos mecánicos generados (coste, tipo, elemento, objetivo); (b) además, un resumen de una línea escrito por Narrative, solo en la app, sin distribuir; (c) traducción completa. **Recomiendo (b).**
- **E2 Partida rápida** (menos vida inicial u otro cambio de regla). **Recomiendo no hacerla todavía:** primero medir la duración real en M12; si una partida de 4 pasa de 30 minutos, se reconsidera.
- **E3 Confirmar que v0.2 (UX) va antes que el multijugador en línea.** **Recomiendo sí.**
- **E4 Conjunción astral** como opción, desactivada por defecto, en v0.3. **Recomiendo sí.**
- **E5 Punto 2 de `docs/DECISIONES-PARA-REVISAR.md`** (a quién espera la ventana de reacción). **Recomiendo dejarlo como está en local** (solo a quien puede responder) y decidirlo para el modo en línea al diseñar B1.

## 6. Cómo evaluaré v0.2
**Aprobado** si: los 12 ítems cumplen su criterio "hecho cuando", los tests y los warnings están en verde, QA aporta las métricas de la sección 3 y en la prueba M12 el usuario responde "sí" a "¿supiste siempre qué te pasó?". **Aprobado con cambios** si fallan los ítems 10-12. **Rechazado** si falla alguno de los ítems 1, 3, 7 o 9.

## Nota del Director, 2026-10-13 (tras la puerta de la oleada 1)
Detalle en `docs/historico/v0.2/evaluacion-o1.md`. No reescribe lo anterior; lo corrige o amplía:
- **Tamaño táctil (corrige §3 Technical Artist y ítem 12):** "96 px ≈ 48 dp" era un error: 96 px a 1080 ≈ 32 dp. Criterio vigente: **144 px a 1080 (≈ 48 dp) en los botones de acción principal** (Beber poción; Pasar y respuestas en la reacción; fila Jugar/Intercambiar/Descartar/Terminar turno; Confirmar; botón principal de cada pantalla) y **96 px en el resto**; ≥ 24 px alrededor de Beber poción.
- **Ítem 9 (bots) se amplía** con las partidas largas (QA-V2-21-02): en 200 simulaciones, ≤ 4 partidas > 100 turnos de jugador, 0 > 200 y media ≤ 30 turnos, además de los criterios anteriores (V2-41, V2-42). Sin cambiar reglas; la pregunta de regla es E6 para el usuario.
- **Ítem 1 (feedback):** criterio intermedio de rendimiento para V2-22 (fotogramas de animación p95 ≤ 16 ms, fotograma con acción sin empeorar la base); la meta de 60 fps sigue en V2-34.
- §6 no cambia: si fallan los nuevos criterios del ítem 9, cuenta como fallo del ítem 9.

## Nota del Director, 2026-10-13 (V2-36, cierre de v0.2)
Detalle en `docs/revision/evaluacion-v02.md`. No reescribe lo anterior:
- **Veredicto de v0.2: Aprobado a falta de M12.** Los 12 ítems cumplen (reservas en 1, 5, 11 y 12). Si M12 da "a veces" o "no" a "¿supiste siempre qué te pasó?", pasa a Aprobado con cambios y se hace v0.2.1 solo con esos arreglos.
- **Cambio de prioridades (pendiente de E8 y E9 del usuario):** lo siguiente es **v0.3 "En el celular"** (build Android, memoria y rendimiento en el dispositivo, prueba táctil, mano con ficha en 6, E6, Conjunción astral, audio y vibración, bots que usan todas las cartas, meta de 16 ms) y **B1 pasa a v0.4**. La lista "Después" de §4 queda sustituida por el orden de `evaluacion-v02.md` §4.

# Evaluación de v0.2 "Mesa legible" (V2-36)

Autor: Game Director. Fecha: 2026-10-13. Criterios: `docs/revision/LINEAMIENTOS.md` §4 (12 ítems) y §6, con las correcciones de la nota del 2026-10-13 (144 px y el ítem 9 ampliado).
Fuentes: `docs/qa/informe-v02.md` (puerta final V2-35), `docs/qa/metricas-final.md`, `docs/qa/bugs.md` (estado tras V2-36), `docs/rendimiento/v02-final.md`, `docs/qa/partidas-largas.md`, `docs/diseno/opciones-bloqueo-pociones.md` y las capturas `docs/revision/capturas/v2-33-*`, `v2-35-*`, `v2-36-*`, `v2-26c-*`, `v2-27b-*`, `v2-28-*`, `v2-29-*`, `v2-30-*`.

## 0. Qué he visto y qué no (léelo antes que el veredicto)
- **He visto con mis propios ojos** (Read de las imágenes) 10 capturas representativas a 720×1280: mesa de 3 y de 6 jugadores con estados, ficha con 3 y con 6 jugadores, feedback en una partida real de 4, ventana de reacción con 6 (V2-36), descarte forzado (V2-36), registro desplegado (V2-36), pantalla de fin de 6, Ajustes (V2-36) y "Cómo se juega".
- **He ejecutado** `bash tools/test.sh` y `bash tools/check_warnings.sh` (salidas en `docs/revision/salidas/v2-36-*.txt`; resultado en §1).
- **No he ejecutado** simulaciones ni mediciones de rendimiento: me fío de QA (V2-35), que las repitió dos veces con resultados idénticos y con mutaciones que demuestran que sus tests detectan fallos. Es una fuente fiable, pero no es mía.
- **No he jugado.** No puedo usar ratón, teclado ni dedo. **Mi criterio central, que el usuario responda "sí" a "¿supiste siempre qué te pasó?", solo se cierra con la prueba humana M12.** Ningún test, captura ni simulación lo sustituye: miden que el feedback *existe*, no que una persona lo *entienda* con 3 bots jugando cada 0,6-0,9 s.
- **Nadie ha visto el juego en un celular.** M12 se juega en el PC (`godot --path .`). El tamaño táctil (144 px ≈ 48 dp), la legibilidad real a 720 px, el rendimiento y la memoria en Android o Web siguen siendo cálculos o mediciones de escritorio.

## 1. Veredicto: **APROBADO A FALTA DE M12**

Según §6: los 12 ítems cumplen su "hecho cuando" (8 sin reserva y 4 con reservas menores, ninguno en 1, 3, 7 o 9 que obligue a rechazar); tests y warnings en verde; QA aportó todas las métricas de la sección 3. Falta solo la condición humana. Por tanto:

- **v0.2 queda cerrada en desarrollo** (no se añaden más tareas a v0.2) y registrada en `docs/DECISIONES.md`.
- **La aprobación es definitiva cuando el usuario responda "sí" en M12.**
- Si responde **"a veces" o "no"**, el veredicto pasa a **Aprobado con cambios**: se abre una mini-iteración **v0.2.1** solo con los arreglos de lo que M12 señale (cada "no" con su momento concreto, una captura si la hay y la causa), antes de empezar v0.3. No es un rechazo: los ítems 1, 3, 7 y 9 pasan con evidencia; lo que fallaría sería la comprensión, y eso se ajusta sobre lo que ya existe.

Verificación propia (ejecutada por mí tras V2-36): `bash tools/test.sh` -> **717/717**, 16 059 asserts, 0 pendientes, salida 0 (`docs/revision/salidas/v2-36-test.txt`); `bash tools/check_warnings.sh` -> **OK: sin warnings**, salida 0 (`docs/revision/salidas/v2-36-warnings.txt`).

## 2. Los 12 ítems

"Cumple" = criterio "hecho cuando" demostrado con test y captura. "Reserva" = cumple el criterio, pero queda algo que el usuario puede notar o que no se ha podido medir. Ningún ítem "no cumple".

| # | Ítem | Mi veredicto | Evidencia en la que me apoyo | Lo que vi yo / reserva |
|---|---|---|---|---|
| 1 | Feedback en los paneles | **Reserva** | `test_feedback`, `test_o2_feedback_one_per_event...` (1 feedback por evento, sobrevive al `refresh`); QA-V2-27-01 y 35-05 cerrados | Vi en `v2-35-feedback-4j`: destello rayado en el panel de Ana, "▼ -1", brillo en Dario y "Dario → Fire Arrow → Ana" grande y claro. Reservas: en `v2-36-reaccion-6j-720x1280` el "▼ -2 maná" tapa la cifra de maná de Bruno y el aviso "Bruno → Ice Bolt → Ana" tapa el nombre de Fabio durante ~1 s; la duración ≥ 1 s no se cronometró. **Que se entienda solo lo dice M12** |
| 2 | Registro de 3 líneas sin claves | **Cumple** | `test_log_text`, `test_i2_real_games_log_is_clean`; 0 textos con `_` en todas las pantallas | Nombres resaltados en amarillo y se lee bien. Cosmético: en la reacción salen dos líneas casi iguales ("juega Ice Bolt contra Ana" / "lanza Ice Bolt contra Ana. Hora de reaccionar", QA-V2-21-04) |
| 3 | Jugables y ficha con coste efectivo | **Cumple** | `test_f_item3_*` (Fire Storm: "Maná: 2 (base 1)"; jugable == existe `PLAY_CARD`), mutación M6 detectada | Vi el marco verde en las jugables y la ficha con nombre, maná, tipo, elemento, resumen en español, "Ver" y el motivo una sola vez ("Ice Bolt cuesta 2 de maná y tienes 1. Bebe una poción.") |
| 4 | Pago explícito | **Cumple** | `test_f_item4_*` (texto exacto y preselección con 1 combinación); QA-V2-35-02 cerrado | Vi "Descarta 2 cartas (Icy Grasp) (0/2)" en V2-36: el último plural provisional ya no está |
| 5 | Cartas legibles / "Ver" / zoom | **Reserva** | `test_f_item5_*` ("Ver" abre el zoom con un toque, pista la primera vez) | Con 3 jugadores la mano es grande y se lee. **Con 6 jugadores y la ficha abierta la mano queda diminuta** (QA-V2-35-06, abierto): las cartas se reconocen por el dibujo, pero no se leen nombre ni coste. Hay ~100 px vacíos entre "Beber poción" y la mano que se podrían usar. La pulsación larga con el dedo no se ha probado |
| 6 | Interfaz honesta | **Cumple** | 0 botones sin conexión en 5 pantallas y 8 mesas; QA-V2-35-03 cerrado | Vi el menú sin "Crear sala" ni "Unirse" y Ajustes con solo "Avisarme de reacciones" e "Idioma: español". Sin opciones muertas |
| 7 | Preferencia de reacción | **Cumple** | Simulación: modales al "humano" **5,39 → 2,77 por partida (−49 %)**, máximo 26 → 9 | Medido con un bot haciendo de humano; una persona con escudos puede querer más avisos. Número real: M12 (pregunta 2 del guion) |
| 8 | Pantalla de fin con resumen | **Cumple** | `test_f_item8_*` (repite jugadores y opciones con otra semilla), `test_game_over`, `test_match_summary` | Vi `v2-35-fin-6j`: clasificación 1.º-6.º, causa, golpe final con carta, turnos y pociones; "Jugar otra vez" destaca. Es exactamente lo que el grupo comentará |
| 9 | Bots sin suicidio ni acaparamiento | **Cumple** (con E6 abierta) | 200/200 terminadas, **0** Too Much Mana, 1 partida > 100 turnos (≤ 4), 0 > 200, media **24,8** turnos (≤ 30), rondas en bloqueo −91 %; semilla 1000 y sin límite, limpias | Los criterios se cumplen. Queda el riesgo de regla E6 (§3, R1), que no es un fallo de los bots |
| 10 | Contexto y riesgo | **Cumple** | `test_context_risk`, QA-V2-32-01 cerrado | Vi "⚠ Beber poción (8/10)" en ámbar en la mesa y "(9/10)" en naranja en la reacción, "⚠ Contra ti" en rojo y la línea "Tu vida: 10 · Tu maná: 0" en la hoja de reacción, que ya no tapa el panel propio (QA-V2-35-04 cerrado) |
| 11 | "Cómo se juega" | **Reserva** | `test_help`; accesible desde el menú y desde la partida | Se lee, pero el texto blanco va sobre el fondo con manchas sin panel oscuro (QA-V2-32-02, cosmético). No consta una revisión final del Game Designer del texto implementado contra su especificación (`docs/diseno/ayuda-como-se-juega.md` A4) |
| 12 | Legibilidad móvil | **Reserva** | `test_f_no_text_under_22px...` (0 textos < 22 px en 3, 5 y 6), botones ≥ 144/96 con separaciones ≥ 16/24, iconos de 48 px; mutaciones M3 y M5 detectadas | Vi iconos de estado claros (nieve, ojo tachado, escudo, lápida, robot) y paneles de 6 sin solapes. Reservas: **nada se ha visto en un celular real**; la mano con ficha y 6 jugadores (ítem 5); el panel propio y Beber poción cambian de altura según el número de magos (769 / 851 / 935 px a 1080) |

Rendimiento (criterio del Technical Artist, no de §6): fotogramas de animación p95 2,9-3,2 ms (cumple); fotograma con acción p95 20,0 ms (3j) y 27,2 ms (6j): cumple el criterio (≤ 57) y el objetivo (≤ 33), **no la meta de 16 ms**. En la práctica es un tirón de 1-2 fotogramas cuando actúa un bot; en escritorio no debería notarse. En un Android de gama media no se sabe.

## 3. Riesgos abiertos

| # | Riesgo | Gravedad | Por qué | Qué debe mirar el usuario en M12 |
|---|---|---|---|---|
| R1 | **E6: atascos por el límite de 10 pociones.** Con 10 sigue habiendo partidas con bloqueo (3/50; la peor, 140 turnos con un mago a 10/10 y 0 de maná) y con bots más aleatorios reaparece (2 > 100 turnos y 38 con bloqueo en 200, corrida de la puerta O3). Un humano **sí puede quedar sin ninguna jugada legal** (V2-41). Con límite 15 o sin límite: 0/50 | **Alta para la diversión** (una sola partida así arruina la sesión del grupo), baja en frecuencia | Es una regla nuestra (adaptación digital), no del manual. Decisión del usuario | Si en algún momento nadie podía hacer nada durante varias rondas; si alguien llegó a 8-10 pociones y qué sintió (tensión o fastidio). Responder la pregunta 9 del guion: 15 / desactivar / dejar en 10 |
| R2 | **No sabemos si "se entiende el caos"** con bots rápidos | **Alta** (es el objetivo de v0.2) | Solo medible con personas | Pregunta 1 del guion: cada vez que perdió vida o maná, ¿supo quién fue y con qué carta? Anotar el momento si no |
| R3 | **Memoria de texturas ~290 MB** (188 imágenes sin comprimir) | **Alta para Android y Web**, nula en escritorio | Un celular de gama media o un navegador pueden cerrar la app o ir lentos | Nada en M12 (es PC). Se decide al hacer la build (v0.3) |
| R4 | **Mano diminuta con la ficha abierta y 6 jugadores** (QA-V2-35-06) | **Media** con 5-6 jugadores; nula con 3-4 | Hay que cerrar la ficha para leer la mano | Partida C (opcional, 6 jugadores): si tuvo que abrir y cerrar la ficha para elegir carta |
| R5 | **Meta de 16 ms no alcanzada** (20 / 27 ms p95 con acción) | **Baja** en escritorio; **desconocida** en el móvil | Lo fija la decisión del bot en el hilo principal (propuesta P2b de `docs/rendimiento/v02-final.md`) | Si notó tirones cuando juegan los bots |
| R6 | **Tamaño táctil y legibilidad sin probar en un celular** | **Media** | 144 px ≈ 48 dp es un cálculo con densidad supuesta | En M12 en el PC, si puede, achicar la ventana a una altura de celular (unos 720×1280 o menos) y decir si lee bien. Lo táctil queda para la build |
| R7 | **Duración real desconocida** (la simulación da 24,8 turnos de media; minutos solo con personas) | **Media** | Objetivo de la visión: 15-25 min con 4 jugadores. E2 (partida rápida) depende de esto | Hora de inicio y fin de cada partida |
| R8 | **El humano puede quedar eliminado muy pronto y solo mirar** (en `v2-35-fin-6j` Ana cae en su turno 1 de 6 jugadores) | **Media** (D4 ritmo) | Lo resuelve en parte la Conjunción astral (decidida para v0.3) | Cuánto tiempo pasó mirando tras ser eliminado y si se aburrió (pregunta 3) |
| R9 | **Sin ningún commit** | **Media** (técnica y de proceso) | No hay historial: QA ha tenido que comparar por fecha de modificación (QA-V2-35-08) y no puede ver diffs ni demostrar que no se debilitaron tests. Un error de disco o un agente pierde semanas | Nada; es una decisión del usuario (E7) |
| R10 | 15 cartas que los bots nunca juegan (sobre todo artefactos) y sesgo del asiento 3 | **Baja** ahora | Es la heurística del bot, no las cartas; la mesa con bots se ve menos variada | Si echó de menos ver artefactos en juego |
| R11 | Cosméticos: ayuda sin panel oscuro, línea redundante en la reacción, números que rozan cifras, orphans en tests | **Baja** | — | Comentarios libres |

## 4. Prioridades de v0.3

### Siguiente gran prioridad: **v0.3 "En el celular"**, antes del multijugador en línea (B1 pasa a v0.4)
Razonamiento:
1. **La visión es un juego de celular, y hoy nadie del grupo puede jugarlo en el suyo.** El hot-seat en un solo celular ya cubre el caso "en la misma habitación" (el más habitual del grupo) sin depender de Firebase. Es el mayor valor por el menor coste.
2. **B1 necesita igualmente la build móvil.** La prueba en línea (M13) se hace con celulares, y la vía Web en línea exigiría hosting con URL pública que expone el arte © (prohibido sin confirmación expresa, M16). En la práctica, en línea = Android, así que la build Android está en el camino crítico de B1 de todos modos.
3. **Los riesgos R3, R5 y R6 solo se cierran en un dispositivo.** Si saltan en línea, se mezclan con los fallos de red y cuesta mucho más separarlos (el mismo argumento que puso v0.2 delante de B1).
4. **B1 sigue bloqueado** por M3-M5, que son del usuario. M3 (Java 17) sirve a la vez para Android y para el emulador de Firebase: es la primera tarea manual que conviene hacer.
5. La prueba de concepto de Firebase en Godot (B1.1) **puede adelantarse en paralelo** en cuanto M3-M5 estén hechos, si hay hueco (tope de 2 agentes), sin que retrase v0.3.

**Qué necesito del usuario para empezar:** (1) el resultado de M12 con la plantilla del guion; (2) la decisión E6 tras M12; (3) M3 (Java 17) y M14 (Android SDK, plantillas de exportación, keystore de depuración); (4) la plataforma prioritaria (E9) y el orden v0.3 antes de B1 (E8); (5) el primer commit (E7).

### Lista ordenada (máximo 10)

| # | Prioridad | Por qué | Hecho cuando | Depende de M12 |
|---|---|---|---|---|
| 1 | **v0.2.1: arreglos que pida M12** (solo si hay "no" o "a veces") | Cierra la condición pendiente de v0.2; sin entender el caos no hay diversión | Cada momento confuso de M12 tiene causa, arreglo y test o captura; el usuario confirma "sí" en una segunda partida corta | **Sí** (puede quedar vacía) |
| 2 | **E6 aplicada según decida el usuario** (límite 15 por defecto y/o variante anti-bloqueo opcional desactivada) | Un atasco arruina la partida (R1) | La opción elegida es configurable; en 200 simulaciones con los valores por defecto, 0 partidas con bloqueo de ≥ 10 rondas y 0 partidas > 100 turnos; con `randomness` 15, ≤ 1 | **Sí** |
| 3 | **Build Android de depuración** (y Web servida solo en la red local si el usuario la elige; nunca hosting público) | Llevar el juego al celular (visión) y desbloquear M13 | Un APK instalado en el celular de un miembro del grupo completa una partida de 6 jugadores sin errores; `tools/build.sh android-debug` reproducible | No (sí de M3/M14 y E9) |
| 4 | **Memoria de texturas y rendimiento en el dispositivo** | R3: puede impedir jugar en el celular | Memoria de texturas medida en el dispositivo y reducida al menos a la mitad frente a los ~290 MB (el presupuesto exacto lo fija el Lead Programmer tras medir); fotograma con acción p95 ≤ 33 ms en el celular con 6 jugadores; carga < 10 s | No |
| 5 | **Prueba M12-bis en el celular** (táctil y legibilidad) | R6: el 144 px ≈ 48 dp es un cálculo | El usuario juega 1 partida en el celular y responde "no" a "¿pulsaste algo sin querer?" y "sí" a "¿se lee?" | No |
| 6 | **Mano legible con la ficha abierta en 5-6 jugadores** (QA-V2-35-06), aprovechando el espacio vacío bajo "Beber poción" | R4; el 5-6 es la mesa más caótica | A 720×1280 con 6 jugadores y la ficha abierta, cada carta de la mano mide ≥ 150 px de ancho a 1080 (≈ el de 4 jugadores) y la ficha no tapa ninguna carta; captura y test | Sube si M12 lo señala |
| 7 | **Conjunción astral** (opción desactivada por defecto; decidida, E4) | D4 y R8: los eliminados hoy solo miran | Especificación del Game Designer aprobada por el usuario; tests de la variante; 200 simulaciones con la opción activada: 200/200 terminadas, 0 violaciones; el eliminado ve en su panel qué puede hacer | No (sube si M12 confirma R8) |
| 8 | **Audio mínimo** (efectos sintetizados o propios, desactivado por defecto) **y vibración** en Android | Refuerza D1 ("supe qué me pasó") en el celular, donde no siempre se mira la mesa | 6 efectos (daño, curación, poción, evento, reacción, victoria) sin copyright, con licencia documentada; los ajustes de volumen y vibración reaparecen y funcionan (sin opciones muertas, test); desactivado por defecto | Sube si M12 dice "a veces" |
| 9 | **Bots que usan las cartas que nunca se juegan** (artefactos, utilidades, maldiciones) **sin cambiar reglas** | R10: mesa más variada con bots; también para jugar solo contra bots | ≤ 5 cartas no jugadas en 200 simulaciones (hoy 15), sin empeorar ningún criterio de V2-42 ni el ítem 9 | No |
| 10 | **Meta de 16 ms: decisión del bot fuera del fotograma** (P2b) y refrescos parciales del registro y la mano (P3/P4) | R5; prioridad según lo que mida el punto 4 | p95 con acción ≤ 16 ms con 3 y 6 jugadores en escritorio; simulación 200 partidas idéntica a la actual (mismo resultado por semilla) | No (sube si el punto 4 falla en el móvil) |

**Fuera de la lista de v0.3 (después), con motivo:**
- **B1 multijugador en línea:** v0.4 (ver arriba). Su prueba de concepto puede ir en paralelo si M3-M5 están hechos.
- **Animaciones de cartas y efectos por elemento:** pulido visual de coste alto; primero hay que saber cuánto rendimiento queda en el celular (puntos 4 y 10).
- **Tutorial guiado:** solo si M12 muestra que "Cómo se juega" no basta. Mientras tanto, se pone el panel oscuro a la ayuda (cosmético, se puede meter en v0.2.1 o en el punto 6).
- **Ficha de carta mejorada:** ya cumple; solo se toca si M12 lo pide.
- **Dificultad o estilos de bots y velocidad configurable:** después del punto 9; la velocidad (Normal / Rápido) sube si M12 dice que los bots van demasiado rápido para seguirlos.
- **Partida rápida (E2):** se decide con los minutos de M12 (si una partida de 4 pasa de 30 minutos).
- **Cosméticos** (línea redundante de la reacción, orphans de los tests): cuando un Developer pase por esos archivos.

## 5. Preguntas al usuario
Registradas en `docs/ESCALADOS.md`: **E6 (seguimiento tras M12)**, **E7 primer commit**, **E8 orden v0.3 "En el celular" antes de B1** y **E9 plataforma prioritaria**. Mis recomendaciones: E6, límite 15 por defecto salvo que M12 muestre que el K.O. a 10 da tensión sin atascos; E7, commit local ya (sin remoto público); E8, sí; E9, Android primero.

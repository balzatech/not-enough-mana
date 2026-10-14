# Evaluación de la oleada 1 de v0.2 (puerta V2-21)

Autor: Game Director. Fecha: 2026-10-13. Base: `docs/qa/puerta-o1.md` (QA recomienda aceptar con reservas), `docs/qa/bugs.md` (QA-V2-21-01 a 06), `docs/qa/metricas-base.md`, `docs/rendimiento/v02-base.md`, `docs/diseno/escenarios/mesa-5-6-jugadores.md`, capturas `v02-base-*`.
Límites: no he ejecutado nada ni jugado. Me apoyo en lo que QA ejecutó (465/465 tests, warnings OK, 200/200 partidas, 0 eliminaciones por Too Much Mana) y en la captura `v02-base-inicio-720x1280.png`, que he mirado.

## 1. Veredicto: APROBADO CON CAMBIOS para pasar a la oleada 2

Por qué se aprueba: los cimientos que la oleada 2 necesita están hechos y validados por QA de forma independiente: mesa dividida en 14 módulos (ninguno > 400 líneas) con los tests de integración intactos, `log_seq` y bus de presentación con 1 feedback por entrada, registro de 3 líneas limpio (ítem 2), interfaz honesta (ítem 6), bots sin suicidio (ítem 9: de 101 a 0 eliminaciones por Too Much Mana), tema con mínimos de fuente y botón, iconos, zoom arreglado y línea base corregida.

Por qué "con cambios": dos reservas afectan a cómo se construye la oleada 2 (rendimiento y documentación de arquitectura), un defecto de la mesa se vuelve más probable con el auto-pase de V2-25b y las partidas largas de los bots no estaban en el plan. Nada de esto justifica parar la oleada.

### 1.1 Reservas que se cierran ANTES de empezar la tarea indicada (no bloquean toda la oleada)

| Reserva | Qué se exige | Responsable | Debe estar antes de |
|---|---|---|---|
| R3 / QA-V2-21-03: `ARQUITECTURA.md` no recoge la división de la mesa (V2-05) ni los campos de V2-06 | Añadir ambos (o remitir a `division-table.md` y `CONTRATO-TIPOS.md`) y la decisión de refresco incremental. Es documentación corta | Lead Programmer (nueva **V2-14d**) | **V2-22** (es el documento de contexto que leen todos los Developers de la oleada 2) |
| R2 / QA-V2-21-06: fotograma con acción de 38-68 ms (presupuesto 16 ms) | No se arregla aparte: pasa a ser **criterio de aceptación de V2-22** (ver 1.3) | Developer (V2-22); mide QA en V2-27 o Performance | Cierre de V2-22 |
| R1 / QA-V2-21-01: modo de selección huérfano ("Descarta 1 carta(s)... + Confirmar" sin prompt) | Arreglar el reseteo de `step`/`flow_data` al desaparecer el prompt, test nuevo y regenerar `partida-midgame.png`. Lo subo de "captura incorrecta" a defecto real: con V2-25b la sesión resolverá cosas sin que la UI las toque, y en hot-seat/plazos de reacción también puede pasar | Developer (nueva **V2-39**, `table_prompts.gd` y, si hace falta, `table_flow.gd`; ninguna tarea de la oleada 2 los edita) | **V2-25b** y, como tarde, la puerta V2-27 |

### 1.2 Reservas que se resuelven dentro de su tarea ya prevista (sin adelantar)
- **R4 / QA-V2-21-05: `player_panel` a 17 px, "Bot"/"TURNO".** Lo resuelve **V2-33** al sustituir las etiquetas por iconos (V2-10 §3.1). V2-22 edita `player_panel.gd` pero **no** debe arreglar el tamaño: solo hace el refresco incremental y el feedback (evita duplicar trabajo y ampliar V2-22).
- **QA-V2-21-04 (registro redundante en la reacción):** cosmético. Mini-tarea **V2-44** (Developer, `log_text.gd`) en la oleada 3 si hay hueco; si no, v0.3. No bloquea.
- **QA-V2-21-03 (45/50 con efectos falsos):** informativo, sin acción.
- **Memoria de texturas ~280 MB** (`v02-base.md` §2): no afecta a v0.2 en escritorio; pasa como riesgo a la build Android (M14) y Web. Lead Programmer + Technical Artist, v0.3 o antes de M13. Producer: anotarlo en riesgos/BACKLOG.

### 1.3 Criterio de rendimiento para V2-22 (decisión de prioridad, no técnica)
El Lead Programmer ya decidió el refresco incremental de paneles y centro; no lo cambio. Fijo qué se acepta:
- **Exigible al cerrar V2-22:** (1) ningún feedback dispara un `refresh()` completo; (2) los fotogramas sin `state_changed` con animaciones en curso, p95 ≤ 16 ms (modo `real`, 3j y 6j a 1080); (3) el fotograma con acción no empeora la base (p95 ≤ 57 ms); (4) el informe trae el desglose de `refresh()` por módulo.
- **Objetivo (no bloqueante en O2):** fotograma con acción p95 ≤ 33 ms.
- **Meta de v0.2** (se juzga en V2-34, sin cambios): p95 ≤ 16 ms, o informe con causa y propuesta. Medición con `tests/perf/perf_table.gd`.

## 2. Tamaño táctil: decisión (a), con validación en M12

El error es del lineamiento: 96 px a 1080 ≈ 32 dp, no 48 dp (V2-10 lo detectó bien). Elijo **(a): 144 px (≈ 48 dp) solo para los botones de acción principal, 96 px (≈ 32 dp) mínimo para el resto**, y la prueba en el móvil de M12 sirve para confirmar, no para decidir desde cero.

Motivos: (b) rompe la hoja inferior (Elixir pasa a pantalla completa) y come la mano y el centro en 6 jugadores por un beneficio pequeño en botones poco usados; (c) deja sin criterio a V2-33 hasta el final de la iteración. Los botones principales son los que se pulsan muchas veces, con prisa (plazo de reacción) o con consecuencia irreversible (Beber poción puede eliminarte): ahí un fallo de pulgar sí cuesta partidas.

**Botones de acción principal (≥ 144 px de alto a 1080; 96 a 720):**
1. **Beber poción** (en la mesa y en la ventana de reacción).
2. En la ventana de reacción: **Pasar** y cada **respuesta** (botón de reaccionar / carta de respuesta si es botón).
3. Fila de acciones del turno: **Jugar** y **Terminar turno**; la fila entera (con Intercambiar y Descartar) toma la misma altura para no mezclar alturas.
4. **Confirmar** en pago, descarte forzado, elegir cartas y en la hoja inferior de prompts (Mana Focus, Elixir, Magic Cap, maná insuficiente). En la hoja, la fila de Confirmar es de 144; si no cabe, Elixir usa la variante de una fila de 3 botones (V2-10 §5.1).
5. Botón principal de cada pantalla fuera de la mesa: **Jugar local**, **Empezar partida**, **Jugar otra vez**, **Soy X** (pasar el dispositivo).

**Secundarios (≥ 96 px a 1080):** Menú, Cancelar, Intercambiar/Descartar si salen de la fila, selector −/+ (96x96), "Ver" de la carta, "Ver resultado", Ajustes, Cómo se juega, botones de diálogo que no sean Confirmar. Separación mínima entre botones adyacentes: 16 px; **entre Beber poción y cualquier otro botón: ≥ 24 px**.

Criterio para V2-33: test que mide los botones de la lista (≥ 144 a 1080) y el resto (≥ 96), en mesas de 3 y 6 a 1080x1920 y 720x1280. El espacio sale del centro (cartas de mazo/descarte/evento hasta escala 0,8) y de los huecos libres; nunca de los mínimos de panel de rival de V2-10 ni del panel propio. Si con 6 jugadores a 720x1280 no cabe la fila de acciones a 144, V2-33 lo dice en su informe con capturas y lo decido yo; no se baja por cuenta propia.

Criterio para los Developers de la oleada 2 (V2-22 a V2-26c): **no redimensionan botones existentes** (lo hace V2-33 en solitario). Los botones **nuevos** que creen usan las constantes del tema: `UiTheme.BUTTON_MIN_H` para secundarios y la nueva constante de principal (nueva **V2-40**, Technical Artist, `ui_theme.gd` + `docs/arte/tecnico.md`, antes de V2-26c). Afecta sobre todo a "Jugar otra vez" (V2-26c, principal) y al interruptor de Ajustes (V2-25c, secundario).

Validación en M12: el guion (V2-31) pregunta "¿pulsaste algún botón sin querer o te costó acertar?". Si el usuario reporta fallos en secundarios, se suben en v0.3.

## 3. Partidas largas y bloqueo de recursos (QA-V2-21-02)

### 3.1 ¿Es un riesgo real de diversión? Sí, pero acotado
- **Lo normal está bien:** mediana 26 turnos de jugador y 9 rondas. Con 30-60 s por turno humano serían 13-26 min, dentro de mi objetivo de 15-25 min. La media (39,6 turnos, ≈ 20-40 min) la inflan las colas.
- **La cola es grave cuando ocurre:** 14 de 200 partidas (7 %) pasan de 100 turnos y 6 de 200. La de 436 turnos es una mesa en la que **no pasa nada** durante cientos de turnos: dos magos con 10/10 pociones, 0 de maná y descartando. En "1 humano + 3 bots" con el humano eliminado, eso son 15-20 minutos mirando bots a 0,6-0,9 s por acción, o una partida que hay que abandonar. Contradice D4 (ritmo) y la visión de partidas cortas. Una sola partida así en la prueba M12 arruinaría la impresión del juego.

### 3.2 ¿Bots o regla? Las dos cosas, y se atacan en ese orden
- **Bots (AI Programmer):** llegan al límite de pociones acumulando sin plan de gasto y luego no tienen salida; además reaccionan poco y no usan artefactos. Es acaparamiento, que ya estaba en el ítem 9 (S4). Se arregla sin tocar reglas.
- **Regla (Game Designer → usuario):** el límite de 10 pociones de Too Much Mana es una adaptación digital nuestra (en el físico la poción es un trago). Si un **humano** también puede quedar atascado (límite de pociones o pool común de maná agotado, sin acción útil posible), el problema es de la regla adaptada y solo lo resuelve el usuario. No lo decido yo: queda en `docs/ESCALADOS.md` (E6) con opciones y recomendación.
- Hipótesis a verificar: el pool común de 70 de maná podría estar vacío en esas partidas (las pociones no darían nada). Lo comprueba V2-41.

### 3.3 Tareas nuevas (sin cambiar reglas ni cartas)
| Id | Tarea | Responsable | Iteración / orden | Criterio medible |
|---|---|---|---|---|
| **V2-41** | Diagnóstico de partidas largas: métricas nuevas en `tools/sim.gd` (por partida: rondas en "bloqueo", pociones de los vivos frente al límite, maná del pool común, cartas jugadas por ronda) y análisis de las 14 partidas > 100 turnos. Definición de **bloqueo**: ≥ 2 vivos y 3 rondas seguidas sin ningún `PLAY_CARD`, `REACT`, `USE_ARTIFACT` ni daño. Responder: ¿cuántas colas son bloqueo?, ¿causa (límite de pociones, pool vacío, mano injugable)?, ¿podría salir un humano con alguna acción legal que el bot no elige? | QA (`tools/sim.gd`, `docs/qa/partidas-largas.md`) | v0.2, oleada 2, **antes de V2-27** (ambas tocan `sim.gd`, en serie) | Informe con las 14 partidas clasificadas, determinista con `--games 200 --seed 1` |
| **V2-42** | Bots sin bloqueo: gestión de pociones con margen frente al límite y preferencia por jugadas que hacen progresar la partida cuando quedan pocos rivales; política según lo que encuentre V2-41 | AI Programmer (`src/ai/**`, `tests/ai/**`) | v0.2, **oleada 3** (dep V2-41), antes de V2-35 y de M12. Fuera del camino crítico de la mesa | `tools/sim.gd --games 200 --seed 1`: partidas > 100 turnos de jugador **≤ 4** (hoy 14), **0** > 200 (hoy 6), media de turnos de jugador **≤ 30** (hoy 39,6), rondas en bloqueo -50 % o más; sin empeorar: 0 eliminaciones por Too Much Mana, 200/200 terminadas, 0 violaciones. Informativo: misma corrida con `randomness` 15 |
| **V2-43** | Solo si V2-41 demuestra que un humano puede quedar atascado: propuesta de opciones de regla (límite por defecto, variante anti-bloqueo opcional) con su efecto medido en simulación. Solo documento | Game Designer (`docs/diseno/**`) | v0.2 oleada 3, condicional | Opciones con cifras de sim; la decisión la toma el usuario (E6) y cualquier cambio de regla se implementa en v0.3, no en v0.2 |

### 3.4 Duración en minutos
La conversión a minutos **sí espera a M12**: no hay forma de medir el tiempo de un turno humano sin humanos. Lo que no espera es la cola: V2-41 y V2-42 se miden en turnos con la simulación. Para M12, el guion (V2-31) debe anotar **minutos, turnos y rondas** de cada partida (para sacar segundos por turno) y si hubo algún tramo en que nadie podía hacer nada. E2 (partida rápida) sigue aplazado con el mismo umbral: si una partida de 4 pasa de 30 min.

## 4. Para el Producer (actualizar `docs/TAREAS.md`)

**Tareas nuevas:** V2-14d (Lead Programmer, `ARQUITECTURA.md`), V2-39 (Developer, modo de selección huérfano + `partida-midgame.png`), V2-40 (Technical Artist, constante de botón principal 144), V2-41 (QA, diagnóstico de partidas largas), V2-42 (AI Programmer, bots sin bloqueo), V2-43 (Game Designer, condicional), V2-44 (Developer, redundancia del registro, opcional).

**Restricciones de orden:**
- V2-14d antes de V2-22.
- V2-39 antes de V2-25b (y siempre antes de V2-27).
- V2-40 antes de V2-26c y de V2-33.
- V2-41 antes de V2-27 (serie sobre `tools/sim.gd`) y de V2-42.
- V2-42 en la oleada 3, antes de V2-35; V2-35 repite las métricas de V2-41.
- V2-31 añade al guion: minutos/turnos/rondas por partida, tramos sin acciones y "¿pulsaste algo sin querer?".
- V2-22: añadir a su "criterio de hecho" el de rendimiento de §1.3. V2-33: el de tamaño táctil de §2.

**Orden sugerido de la oleada 2 (tope 2 agentes):** 2A0 V2-14d + V2-40 (cortas) → 2A V2-22 + V2-25a → 2B V2-23 + V2-24 → 2C V2-39 + V2-26a → 2D V2-25b + V2-26b → 2E V2-25c + V2-41 → 2F V2-26c → 2G V2-27. El Producer puede reordenar respetando las restricciones.

**Reservas de QA:** cerrar antes de la tarea indicada R3 (V2-14d) y R1 (V2-39); R2 entra en el criterio de V2-22; R4 queda en V2-33.

## 5. Decisiones que necesito del usuario
- **E6 (nuevo):** qué hacer con el bloqueo por límite de pociones si también afecta a humanos. Mi recomendación: no cambiar ninguna regla ahora; arreglar los bots (V2-42), medir (V2-41) y decidir con los datos y con M12. Detalle en `docs/ESCALADOS.md`.

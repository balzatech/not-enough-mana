# Métricas finales de v0.2 (V2-35, puerta final)

Fecha 2026-10-13. Godot 4.7.2.stable, `tools/sim.gd` **sin modificar** (mtime anterior a la puerta O3). Código de bots/motor sin cambios desde V2-42 (`find src/ai src/engine data -newer docs/qa/puerta-o3.md` solo da `data/card_summaries_es.json`, que no afecta al motor). Todo lo de abajo lo ejecuté yo en esta puerta; los textos crudos y los JSON están en el scratchpad de QA (no versionados).

Comando base: `/home/brayan/.local/bin/godot --headless --path . -s tools/sim.gd -- --games 200 --seed 1` (partida `g` con semilla `1+g`, 3 + g mod 4 jugadores, bots con `randomness` 0, tope 2000 pasos).

## 1. Determinismo y criterios de V2-42

| Comprobación | Resultado |
|---|---|
| `--games 200 --seed 1` dos veces | **idénticas**: `cmp` de la salida de texto y del JSON sin diferencias; código de salida 0 |
| Misma corrida frente a `metricas-base.md` (V2-32) | idéntica cifra a cifra (pasos 35 370, 4 470 ventanas, 701 eliminaciones por vida, mismas acciones por tipo) |
| Violaciones de invariantes (`Types.validate_state` tras cada acción, cartas constantes, vida 0-10, maná >= 0) | **0** en las 9 corridas ejecutadas (2 de la seed 1, seed 1000, 50 sin límite, 50 con límite 10, 200 `all`, 200 `affecting`, 50 `all`, 50 `affecting`) |
| Errores (acción ilegal, bloqueo, bucle) | **0** |

| Criterio de V2-42 | Umbral | Medido (seed 1, 200 partidas) | Resultado |
|---|---|---|---|
| Partidas terminadas | 200/200 | **200/200**, 0 topadas | cumple |
| Partidas > 100 turnos de jugador | <= 4 | **1** (g=19, semilla 20, 6 jugadores, 140 turnos) | cumple |
| Partidas > 200 turnos | 0 | **0** | cumple |
| Media de turnos de jugador | <= 30 | **24,8** (mediana 24, min 9, max 140) | cumple |
| Rondas en bloqueo | -50 % o más | **120** frente a 1 400 (V2-38): **-91 %**; 13/200 partidas con bloqueo (antes 33) | cumple |
| Eliminaciones por Too Much Mana | 0 | **0** (701 eliminaciones, todas por vida) | cumple |
| Violaciones | 0 | **0** | cumple |

## 2. Tabla antes / después (200 partidas, semilla 1)

"Antes" = línea base corregida de V2-38 (bots previos a V2-42, `metricas-base-v02-bots-previos.md`). "Base V2-32" = `metricas-base.md` (bots de V2-42). "Final V2-35" = esta puerta.

| Métrica | Antes (V2-38) | Base V2-32 | **Final V2-35** |
|---|---|---|---|
| Terminadas | 200/200 | 200/200 | **200/200** |
| Turnos de jugador: media / mediana / max | 39,6 / 26 / 436 | 24,8 / 24 / 140 | **24,8 / 24 / 140** |
| Partidas > 100 turnos / > 200 | 14 / 6 | 1 / 0 | **1 / 0** |
| Rondas por partida: media / max | 16,5 / 212 | 9,2 / 64 | **9,2 / 64** |
| Partidas con bloqueo / rondas en bloqueo | 33 / 1 400 | 13 / 120 | **13 / 120** |
| Pasos del motor por partida | 233,4 | 176,8 | **176,8** (35 370 en total) |
| Acciones por turno | 5,89 | 7,13 | **7,13** |
| Pociones medias / maná medio a fin de turno de bot | 6,62 / 0,48 | 4,24 / 0,71 | **4,24 / 0,71** |
| DRINK_POTION total | 5 481 | 4 867 | **4 867** |
| Ventanas de reacción por partida: media / max | 24,9 / 43 | 22,4 / 40 | **22,4 / 40** |
| REACT / PASS_REACTION | 310 / 8 529 | 386 / 7 750 | **386 / 7 750** |
| Eliminaciones por Too Much Mana / por vida | 0 / 700 | 0 / 701 | **0 / 701** |
| Violaciones / errores | 0 / 0 | 0 / 0 | **0 / 0** |
| Eventos que salen | los 11 | los 11 | **los 11** (99-128 veces cada uno) |
| Cartas nunca jugadas (sin eventos) | 15 | 15 | **15** (mismo conjunto, ver §5) |

Conclusión: el comportamiento de los bots es el medido en la puerta O3; esta puerta confirma que nada lo ha movido (V2-33, P1 y P2 no tocan `src/ai` ni `src/engine`). P2 (un solo `reduce` por acción de bot) no cambia la partida: mi test compara estado final, historial y `rev` con el flujo antiguo (§6).

## 3. Otras corridas ejecutadas

| Corrida | Terminadas | Turnos media / mediana / max | > 100 | > 200 | Con bloqueo / rondas | TMM | Violaciones / errores |
|---|---|---|---|---|---|---|---|
| 200 partidas, **semilla 1000** | 200/200 | 22,5 / 22 / 55 | 0 | 0 | 7 / 33 | 0 | 0 / 0 |
| **50 partidas `--potion-limit off`**, semilla 1 | 50/50 | 23,7 / 23 / 41 | 0 | 0 | 0 / 0 | 0 | 0 / 0 |
| 50 partidas, semilla 1, límite 10 (defecto) | 50/50 | 25,5 / 23 / 140 | 1 | 0 | 3 / 55 | 0 | 0 / 0 |
| 200 partidas, semilla 1, `--reaction-notify all` | 200/200 | 24,8 / 24 / 140 | 1 | 0 | 13 / 120 | 0 | 0 / 0 |
| 200 partidas, semilla 1, `--reaction-notify affecting` | 200/200 | 24,8 / 24 / 140 | 1 | 0 | 13 / 120 | 0 | 0 / 0 |

La semilla 1000 y el límite desactivado confirman que la mejora no es de la semilla 1. Sin límite de pociones no hay ni una partida con bloqueo (0/50); con el límite 10 sigue habiendo 3/50.

## 4. Interrupciones por reacción al humano (`--reaction-notify`)

`tools/sim.gd` no tiene humano: p1 hace de humano local jugado por el bot, con el mismo auto-pase que `LocalSession._auto_pass_loop`. "Modales" = decisiones de p1 en una ventana (lo que vería una persona). La partida (ventanas abiertas, REACT, turnos) es idéntica en los dos modos.

| Corrida | Ventanas donde p1 está en `awaiting` | **Modales al humano por partida** | Máx. por partida | Auto-pases por partida |
|---|---|---|---|---|
| 200 partidas, `all` | 1 074 (5,37/partida) | **5,39** (1 079) | 26 | 0 |
| 200 partidas, `affecting` | 1 074 (5,37/partida) | **2,77** (555) | 9 | 2,62 (524) |
| **Reducción (200 partidas)** | - | **-48,6 %** | 26 -> 9 | - |
| 50 partidas, `all` / `affecting` (comparable con la puerta O2) | 288 / 288 | 5,76 / **2,84** | 23 / 7 | 0 / 2,92 |
| **Reducción (50 partidas)** | - | **-50,7 %** | 23 -> 7 | - |

Antes (puerta O2, bots previos a V2-42, 50 partidas): 6,20 -> 2,66, **-57 %**. Ahora **-49 % a -51 %**: la preferencia sigue reduciendo a la mitad las interrupciones, pero algo menos que entonces porque los bots de V2-42 juegan distinto (menos curas, más defensivas) y cambia a quién apuntan sus hechizos (hipótesis, no analizada). Lo medido es un bot haciendo de humano; un humano real con Magic Shield podría querer reaccionar a más hechizos; `affecting` solo se lo quita cuando `ReactionRelevance.affects` es falso.

## 5. Cartas que nunca se juegan y reparto por asiento

**15 cartas nunca jugadas** (seed 1, 200 partidas, sin eventos; el mismo conjunto que la línea base y que V2-38): `last_wish`, `magic_capture`, `annihilation`, `space_shift`, `curse_of_rules`, `fireproof_tiara`, `padded_boots`, `faradays_cloak`, `wild_fire`, `dragon_glass`, `tesla_coil`, `spellbook`, `scroll_of_elements`, `transformation_glove`, `twardowskys_mirror`. Con la semilla 1000 son también 15 (cambian `last_wish` y `runic_armor` por la otra); con 50 partidas son 17 (se suman `mirror_shield`, jugada 1 vez en 200, y `runic_armor`). Es la heurística del bot (no usa artefactos ni varias defensivas/maldiciones), no calidad de las cartas; sigue sin tratarse (R15/BACKLOG). `mirror_shield` se juega 1 vez en 200 partidas como respuesta.

**Victorias por asiento (200 partidas, 50 de cada tamaño):**

| Corrida | Asientos 1..6 (todas) | 3 jugadores | 4 jugadores | 5 jugadores | 6 jugadores |
|---|---|---|---|---|---|
| Antes (V2-38) | 26, 28, 65, 36, 29, 16 | 13/11/26 | 6/10/18/16 | 4/5/14/11/16 | 3/2/7/9/13/16 |
| seed 1 final | 25, 38, **60**, 43, 19, 14 | 12/13/25 | 8/13/15/14 | 3/8/13/13/13 | 2/4/7/16/6/14 |
| seed 1000 | 25, 33, **58**, 37, 33, 14 | 10/14/26 | 10/8/16/16 | 2/5/12/15/16 | 3/6/4/6/17/14 |

El asiento 3 gana 58-60 de 200 (29-30 %) con las dos semillas y, con 3 jugadores, 25-26/50 (50-52 % frente al 33 % esperado). El asiento 1 de las mesas de 5-6 casi no gana (2-3/50). Con dos semillas independientes el patrón se repite, así que no es ruido de la semilla 1; **no lo introduce V2-42** (ya estaba en V2-38) y no se debe extrapolar a humanos (el asiento lo fija la edad que se indica al crear la partida: el más viejo empieza). Informativo para el Game Designer.

## 6. Puntos marcados

1. **Queda 1 partida larga** (g=19, 140 turnos, 6 jugadores, 48 rondas en bloqueo, p4 vivo con 1 de vida, 0 de maná y 10/10 pociones): la situación "vivo a 10/10 pociones sin maná" **sigue siendo posible** (rara, no imposible); con el límite 15 o sin límite no ocurre en 50 partidas. E6 sigue abierta y sin decisión del usuario hasta M12.
2. **Duración en minutos**: no medible sin humanos (M12). Solo hay turnos de jugador y rondas.
3. **Limitaciones**: bots con `randomness` 0 (no representan a un humano); 50 partidas por tamaño; "ventanas por jugador" cuenta ventanas en las que p1 está en `awaiting`. La corrida con `randomness` 15 de la puerta O3 (2 partidas > 100 turnos, 38 con bloqueo) **no la repetí** (`tools/sim.gd` no tiene esa opción y no lo modifiqué): vale la cifra de `metricas-base.md`.
4. Los bots curan un 74-77 % menos que antes (cambio deliberado de V2-42): un humano notará menos curas en la mesa.

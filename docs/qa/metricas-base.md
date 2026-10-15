# Métricas base con los bots de V2-42 (V2-32)

**Línea base vigente** para V2-34 y V2-35. Sustituye a la de V2-38 (bots previos a V2-42), conservada en `docs/historico/v0.2/metricas-base-v02-bots-previos.md` y, más atrás, `docs/historico/v0.2/metricas-base-mvp-sesgada.md`.

- Fecha: 2026-10-13. Godot 4.7.2.stable. Código con la política de bots de V2-42 (`src/ai/bot.gd`, `bot_eval.gd`); motor y cartas sin cambios desde V2-38.
- Comando: `/home/brayan/.local/bin/godot --headless --path . -s tools/sim.gd -- --games 200 --seed 1 --json salida.json` (partida `g` con semilla `1+g`, 3 + g mod 4 jugadores: 50 de cada tamaño, efectos reales, tope 2000 pasos, bots con `randomness` 0).
- **Determinismo verificado por QA:** dos ejecuciones con `--seed 1` dieron salida de texto y JSON idénticos (`cmp`). Código de salida 0.
- **Invariantes: 0 violaciones; errores (acción ilegal, bloqueo, bucle): 0; 200/200 terminadas; 0 partidas topadas.**

## Comparación fila a fila (bots previos -> bots de V2-42), 200 partidas, semilla 1

| Métrica | Bots previos (V2-38) | Bots V2-42 | Cambio |
|---|---|---|---|
| Partidas terminadas | 200/200 | 200/200 | igual |
| Turnos de jugador por partida | media 39,6, mediana 26, min 7, **max 436** | media **24,8**, mediana 24 (23,5 exacta), min 9, **max 140** | -37 % de media |
| Partidas > 100 turnos | 14 | **1** (g=19, 140 turnos, 6 jugadores) | criterio <= 4: cumple |
| Partidas > 200 turnos | 6 | **0** | criterio 0: cumple |
| Rondas por partida | media 16,5, mediana 9, max 212 | media 9,2, mediana 8, max 64 | -44 % |
| Partidas con bloqueo (>= 3 rondas sin jugada) | 33/200 | 13/200 | -61 % |
| Rondas en bloqueo | 1 400 | **120** | **-91 %** (criterio -50 %: cumple) |
| Pasos del motor por partida (total) | 233,4 (46 676) | 176,8 (35 370) | -24 % |
| Acciones por turno | 5,89 | 7,13 | +1,24 (no analizado; hay menos turnos por partida) |
| Pociones medias a fin de turno de bot | 6,62 | **4,24** | -2,4 (la reserva de V2-42) |
| Maná medio a fin de turno de bot | 0,48 | 0,71 | +0,23 |
| DRINK_POTION (total) | 5 481 | 4 867 | -11 % |
| Ventanas de reacción por partida | 24,9 (max 43; total 4 975) | 22,4 (max 40; total 4 470) | -2,5 |
| REACT / PASS_REACTION | 310 / 8 529 (3,5 %) | 386 / 7 750 (4,7 %) | los bots reaccionan algo más |
| Eliminaciones por Too Much Mana | **0** | **0** | igual (criterio: no empeorar) |
| Eliminaciones por vida | 700 | 701 | igual |
| Victorias por asiento (1..6) | 26, 28, 65, 36, 29, 16 | 25, 38, 60, 43, 19, 14 | ver abajo |
| Cartas nunca jugadas (sin eventos) | 15 | 15 (el mismo conjunto) | igual |
| Los 11 eventos salen | sí | sí (99-128 veces cada uno) | igual |

Otros totales (V2-42): CHOOSE_CARDS 732, DECLINE 537, DISCARD 9 276, DRINK_POTION 4 867, END_TURN 4 763, EXCHANGE 1 547, PASS_REACTION 7 750, PLAY_CARD 5 284, REACT 386, USE_ARTIFACT 121, USE_EVENT 107.

### Reparto de victorias por asiento

| Jugadores | Bots previos (asientos 1..n) | Bots V2-42 |
|---|---|---|
| 3 | 13 / 11 / 26 | 12 / 13 / 25 |
| 4 | 6 / 10 / 18 / 16 | 8 / 13 / 15 / 14 |
| 5 | 4 / 5 / 14 / 11 / 16 | 3 / 8 / 13 / 13 / 13 |
| 6 | 3 / 2 / 7 / 9 / 13 / 16 | 2 / 4 / 7 / 16 / 6 / 14 |

Con 50 partidas por tamaño el ruido es alto. **El asiento 3 sigue ganando de más** (60 de 200; en 3 jugadores 25/50 = 50 % frente al 33 % esperado) y el asiento 1 de los de 5-6 jugadores casi nunca gana (3/50 y 2/50). Es igual que antes de V2-42, de modo que **no lo introduce ni lo arregla V2-42**. No concluir balance de ahí (el asiento depende de la edad que se indica al crear la partida).

### Cartas que nunca se juegan (15, sin cambio)

`last_wish`, `magic_capture`, `annihilation`, `space_shift`, `curse_of_rules`, `fireproof_tiara`, `padded_boots`, `faradays_cloak`, `wild_fire`, `dragon_glass`, `tesla_coil`, `spellbook`, `scroll_of_elements`, `transformation_glove`, `twardowskys_mirror`. Igual que en V2-38: los bots no usan esas cartas (heurística, no calidad de la carta).

### Cambio de comportamiento de los bots que conviene conocer (V2-35, Game Designer)

La reserva de pociones **reduce mucho las curas**: `heal` 443 -> 114 (-74 %), `greater_heal` 187 -> 43 (-77 %), a cambio de `magic_shield` como respuesta 304 -> 377 y `ice_boomerang` 396 -> 368 (resto de ofensivas sin cambio relevante: lightning 1 314 -> 1 271, fire_arrow 859 -> 788). Es coherente con "curar solo con vida baja y con pociones de sobra" (`test_heals_only_when_hp_is_low`, `test_no_heal_when_potions_are_scarce`), y con ello las partidas son más cortas. No es un fallo, pero un humano contra estos bots verá menos curas. Los bots siguen sin usar las 15 cartas anteriores.

## Otras corridas (V2-32, informativas)

| Corrida | Terminadas | Turnos media / mediana / max | > 100 | > 200 | Partidas con bloqueo / rondas en bloqueo | Elim. TMM | Violaciones / errores |
|---|---|---|---|---|---|---|---|
| 200 partidas, **semilla 1000** | 200/200 | 22,5 / 22 / 55 | 0 | 0 | 7 / 33 | 0 | 0 / 0 |
| 50 partidas, semilla 1, `--potion-limit off` | 50/50 | 23,7 / 23 / 41 | 0 | 0 | 0 / 0 | 0 | 0 / 0 |
| 50 partidas, semilla 1, límite 10 (defecto) | 50/50 | 25,5 / 23 / 140 | 1 | 0 | 3 / 55 | 0 | 0 / 0 |
| 50 partidas, semilla 1, límite 15 | 50/50 | 23,5 / 22,5 / 47 | 0 | 0 | 0 / 0 | 0 | 0 / 0 |
| 200 partidas, semilla 1, `randomness` 15 (copia de `sim.gd` del scratchpad con `randomness` 15; `tools/sim.gd` no tiene la opción) | 200/200 | 31,4 / 30 / 110 | 2 (g=51, g=189) | 0 | 38 / 281 | 0 | 0 / 0 |

La semilla 1000 no tiene medición con los bots previos, así que no hay comparación; la política nueva no depende de la semilla 1 (los resultados son parecidos o mejores). Con `randomness` 15 (bots menos óptimos) la cola vuelve a asomar (2 partidas > 100) y el bloqueo reaparece en 38 partidas: el comportamiento "sin bloqueo" depende de que el bot decida bien.

## Puntos marcados

1. **Queda 1 partida larga (g=19, semilla 20, 6 jugadores): 140 turnos, 64 rondas, 48 rondas en bloqueo (racha de 26)**; termina con p4 superviviente a 1 de vida, 0 de maná y 10/10 pociones. Es el mismo caso de las 436 turnos de V2-41, ahora recortado a un tercio. Confirma que la situación (vivos a 10/10 con 0 de maná) **sigue siendo posible**; V2-42 la hace rara, no imposible. Con límite 15 desaparece en las 50 primeras partidas.
2. **Duración** sigue medida en turnos de jugador y rondas, no en minutos (R6/R7: M12).
3. **Limitaciones:** una semilla base y 50 partidas por tamaño; bots con `randomness` 0 (no representan a un humano); "ventanas por jugador" cuenta la apertura por lanzador. Las cifras de la tabla de límites de `opciones-bloqueo-pociones.md` son de los bots previos y están desactualizadas (ahora límite 10: 3/50 partidas con bloqueo y máx. 140 turnos; límite 15: 0/50 y máx. 47).

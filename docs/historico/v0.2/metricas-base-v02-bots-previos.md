# Métricas base corregida (V2-38) - bots previos a V2-42 (conservada)

> Conservada por V2-32 como referencia histórica: **ya no es la línea base vigente**. La vigente es `docs/qa/metricas-base.md` (bots de V2-42).

Línea base vigente para V2-27 (reacciones) y V2-34. Sustituye a la medición del MVP, sesgada por el bug del bot con el prompt oculto de Magic Hand (conservada en `docs/historico/v0.2/metricas-base-mvp-sesgada.md`, solo histórico).

- Fecha: 2026-10-13. Godot 4.7.2.stable. Código tras V2-17 (el bot responde al prompt oculto de Magic Hand).
- Comando (142 s con `--json`): `/home/brayan/.local/bin/godot --headless --path . -s tools/sim.gd -- --games 200 --seed 1 [--json salida.json]`
- Mismo diseño que la base anterior: partida `g` con semilla `1+g` y 3 + g mod 4 jugadores (50 de cada tamaño), efectos reales, tope 2000 pasos.
- **Determinismo verificado:** dos ejecuciones con la misma semilla dieron salida de texto y JSON idénticos (`cmp`). Código de salida 0.
- **Invariantes: 0 violaciones; errores (acción ilegal, bloqueo, bucle): 0.** Efectos sin registrar: ninguno.

## Comparación fila a fila (MVP sesgado -> corregida)

| Métrica | MVP sesgada | Corregida | Cambio |
|---|---|---|---|
| Pociones medias a fin de turno de bot | 6.11 | 6.62 | +0.51 |
| DRINK_POTION (total) | 5 803 | 5 481 | -5.5 % (pero ya no hay bebidas en bucle) |
| Turnos de jugador por partida | media 33.1, mediana 23, max 436 | media 39.6, mediana 26, min 7, max 436 | +6.5 de media |
| Rondas por partida | media 13.7, max 212 | media 16.5, mediana 9, max 212 | +2.8 |
| Pasos del motor por partida | 205.9 | 233.4 | +13 % |
| Acciones por turno | 6.22 | 5.89 | -0.33 |
| Ventanas de reacción por partida | 22.9 (max 43; total 4 577) | 24.9 (max 43; total 4 975) | +2.0 |
| Respuestas REACT / PASS_REACTION | 287 / 7 735 (3.6 %) | 310 / 8 529 (3.5 %) | % casi igual |
| Eliminaciones por Too Much Mana | 101 (14 %) | **0** (0 %) | corregido |
| Eliminaciones por vida | 601 | 700 | +99 |
| Victorias por asiento (1..6) | 29, 33, 53, 46, 24, 13 | 26, 28, 65, 36, 29, 16 | ver nota |
| Cartas nunca jugadas (no evento) | 14 | 15 | +1 (ver abajo) |
| Partidas terminadas | 200/200 (100 %) | 200/200 (100 %) | igual |

Otros totales (corregida): DISCARD 15 129, PASS_REACTION 8 529, END_TURN 7 722, DRINK_POTION 5 481, PLAY_CARD 6 092, EXCHANGE 1 608, DECLINE 800, CHOOSE_CARDS 746, REACT 310, USE_ARTIFACT 153, USE_EVENT 106. Maná medio a fin de turno de bot 0.48. Pasos totales 46 676.

Victorias por jugadores:asiento (corregida): 3j 13/11/26; 4j 6/10/18/16; 5j 4/5/14/11/16; 6j 3/2/7/9/13/16. Ventanas abiertas por lanzador p1..p6: 751, 1005, 1234, 969, 684, 332. Recibidas: 1186, 1604, 2209, 1822, 1313, 689. Ninguna partida con varios ganadores.

Nota sobre asientos: con una muestra de 50 partidas por tamaño es ruidoso. El asiento 3 domina (65 de 200) igual que antes (53); en 6 jugadores el reparto se ha movido hacia los asientos 5-6. No concluir balance de ahí.

Eliminar el bug alargó las partidas: antes los bots que se suicidaban bebiendo recortaban la partida. Ahora los 101 jugadores mueren por vida, que dura más.

## Puntos marcados

**1. Tope de pasos y colas largas.** Tope de 2000 pasos: **0 partidas lo alcanzan** (`capped` = 0; 200/200 terminadas). Colas largas por turnos de jugador: **14 partidas > 100** (antes 11) y 6 > 200 (rondas > 50: 14). Las mayores: 436 turnos/212 rondas (g=19, 6j), 390/188 (g=39, 6j), 320/154 (g=35, 6j), 250/123 (4j), 229/110 (5j), 227/113. La partida de 436 turnos es la misma que antes, así que **no depende de Too Much Mana**. Causa: sin verificar a fondo; hipótesis: partidas con bots que se curan, se protegen (Magic Shield 304 reacciones) y sin daño decisivo, sobre todo con 6 jugadores. Es una cola, no un fallo: la mediana es 26 turnos y 9 rondas. Si interesa, analizar con la semilla (1+g) en una tarea aparte.

**2. Duración.** Se mide en turnos de jugador y rondas, **no en minutos**: media 39.6 turnos de jugador (mediana 26, min 7, max 436) y 16.5 rondas (mediana 9, max 212). Convertir a minutos exige suponer un tiempo por turno humano; con 30-60 s serían unos 20-40 min de media (13-26 de mediana), solo como hipótesis. La duración real se mide en M12 (R7).

**3. Cartas sin jugar.** Siguen sin jugarse (15): last_wish, magic_capture, annihilation, space_shift, curse_of_rules, fireproof_tiara, padded_boots, faradays_cloak, wild_fire, dragon_glass, tesla_coil, spellbook, scroll_of_elements, transformation_glove, twardowskys_mirror. **El bot no juega ninguna carta nueva** respecto a la base anterior. Las 14 anteriores siguen sin jugarse; la diferencia es last_wish, que antes salió 1 vez como REACT y ahora 0 (varianza de la muestra). Cartas que ya salían ahora salen algo más (magic_hand 101 -> 110, etc.) pero ninguna entra en el conjunto. Los 11 eventos salen todos (143-174 veces).

Cartas jugadas (PLAY_CARD): lightning 1314, fire_arrow 859, ice_bolt 815, heal 443, ice_boomerang 396, vampiric_touch 343, fireball 317, electric_explosion 227, electric_arc 200, greater_heal 187, magic_cap 166, blizzard 136, meteor_shower 133, magic_hand 110, icy_grasp 70, blinding_flash 61, paralysing_touch 56, mana_implosion 51, force_field 50, potent_elixir 35, curse_of_the_younger 33, curse_of_odd 24, curse_of_the_elder 22, curse_of_even 22, curse_of_vigour 7, freeze 6, armageddon 5, book_exchange 3, runic_armor 1. Como respuesta (REACT): magic_shield 304, frozen_bunny 5, mirror_shield 1.

## Limitaciones

- Una semilla base y 50 partidas por tamaño: ruido alto por asiento. Comparar con los mismos argumentos exactos.
- Los bots reaccionan poco (3.5 %), no se farolean ni usan artefactos/utilidad: "nunca jugadas" depende de la heurística, no de la calidad de la carta. No extrapolar balance a humanos.
- "Ventanas por jugador" cuenta la apertura por lanzador (`reaction_opened`, solo el primer hechizo de la cadena) y la presencia en `awaiting`.
- Explicación de la causa de las colas largas: no verificada.

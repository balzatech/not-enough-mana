> **HISTÓRICO, SESGADO. No usar como línea base.** Medido con el código del MVP antes de V2-17: el bot no sabía responder al prompt oculto de Magic Hand, bebía hasta la poción n.º 11 y se eliminaba por Too Much Mana (101 eliminaciones). Eso infla DRINK_POTION y las pociones medias y recorta partidas. Se conserva solo para comparar. La línea base vigente es `docs/qa/metricas-base.md`.

# Métricas base (V2-02)

Línea base contra la que comparan V2-17 (bots) y V2-27 (reacciones). Generada con `tools/sim.gd`.

- Fecha: 2026-10-13. Godot 4.7.2.stable. Código del MVP (v0.1, antes de cualquier cambio de v0.2; `log_seq` no se usa).
- Comando exacto (≈108 s, determinista; dos ejecuciones dieron salida idéntica):

```
/home/brayan/.local/bin/godot --headless --path . -s tools/sim.gd -- --games 200 --seed 1 [--players N] [--json salida.json]
```

- Partida `g` usa la semilla `seed+g` (mazo y bot) y 3 + g mod 4 jugadores (50 partidas de cada tamaño 3, 4, 5 y 6), `randomness` 0, efectos reales (los 58 registrados), `log_limit` 50. Tope: 2000 pasos del motor por partida.
- Invariantes tras cada acción: `Types.validate_state`, vida 0-10, maná >= 0, `card_total` = 154 constante, sin bloqueo, sin bucle > 80 pasos en un turno, sin acción ilegal. Salida con código 1 si hay violaciones o errores; se listan con su semilla.

## Resultados (200 partidas, semilla 1)

| Métrica | Valor |
|---|---|
| Invariantes / acciones ilegales / bloqueos | 0 / 0 / 0 |
| Partidas terminadas dentro del tope | 200/200 (100 %) |
| Pasos del motor por partida | media 205.9 (total 41 179) |
| Turnos de jugador por partida | media 33.1, mediana 23, min 6, max 436 (11 partidas > 100) |
| Rondas completas por partida | media 13.7, max 212 |
| Acciones por turno (todos los pasos: reacciones y prompts incluidos) | 6.22 |
| Acciones por tipo | DISCARD 12 393, PASS_REACTION 7 735, END_TURN 6 339, DRINK_POTION 5 803, PLAY_CARD 5 660, EXCHANGE 1 469, DECLINE 665, CHOOSE_CARDS 592, REACT 287, USE_ARTIFACT 147, USE_EVENT 89 |
| Victorias por asiento (1..6) | 29, 33, 53, 46, 24, 13 |
| Victorias por jugadores:asiento | 3j: 12/14/24; 4j: 9/11/15/15; 5j: 4/5/12/15/14; 6j: 4/3/2/16/10/13 |
| Ventanas de reacción por partida | media 22.9 (max 43); total 4 577 |
| Respuestas en ventana | 287 REACT frente a 7 735 PASS_REACTION (3.6 % reaccionan) |
| Ventanas abiertas por lanzador (p1..p6) | 698, 934, 1101, 937, 615, 292 |
| Ventanas recibidas por jugador (p1..p6) | 1154, 1559, 1940, 1723, 1069, 561 |
| Fin de turno de bot: maná medio / pociones medias | 0.53 / 6.11 (n = 6 339) |
| Eliminaciones | vida 601, Too Much Mana 101 (14 % de las 702) |

Cartas jugadas (PLAY_CARD): lightning 1221, fire_arrow 782, ice_bolt 770, heal 430, ice_boomerang 370, vampiric_touch 336, fireball 305, electric_explosion 202, greater_heal 178, electric_arc 171, magic_cap 161, meteor_shower 120, blizzard 115, magic_hand 101, blinding_flash 66, icy_grasp 61, paralysing_touch 49, mana_implosion 45, force_field 44, potent_elixir 34, curse_of_the_younger 24, curse_of_even 22, curse_of_the_elder 18, curse_of_odd 16, curse_of_vigour 6, freeze 5, armageddon 4, book_exchange 3, runic_armor 1.
Jugadas como respuesta (REACT): magic_shield 278, frozen_bunny 7, last_wish 1, mirror_shield 1.

**Nunca jugadas (14 de 47 no-evento):** magic_capture, annihilation, space_shift, curse_of_rules, fireproof_tiara, padded_boots, faradays_cloak, wild_fire, dragon_glass, tesla_coil, spellbook, scroll_of_elements, transformation_glove, twardowskys_mirror.
Los 11 eventos (se aplican al robar, no se juegan) salieron todos (124-150 veces cada uno).

## Hallazgo: bots eliminados por Too Much Mana

101 bots se eliminan bebiendo la poción n.º 11. Con 5-27 de maná (media 19.4) y vida variada (1-10). En los 101 casos:

- Tenían **un único prompt obligatorio pendiente**, siempre `choose_card` de `magic_hand` con `data.hidden = true` y `data.cards = []`; beber **no** respondía a ese prompt.
- La acción que los eliminó fue `DRINK_POTION` de ese mismo jugador.
- Causa probable (sin confirmar leyendo el motor; a verificar por el AI Programmer): el bot no sabe contestar al prompt oculto de Magic Hand, `_prompt_candidates` no devuelve candidatos y `Bot._fallback` elige `legal[0]`, que es beber poción, una y otra vez hasta superar el límite de 10. Semillas para reproducir: 3 (p5), 4 (p3), 12 (p2, turno 1), 14 (p1, turno 1). Lista completa con maná/vida/prompt: `--json` (clave `tmm`).
- Explica el caso P7 de V2-01 (bot con maná alto y muchas pociones) y sesga estas métricas: DRINK_POTION (5 803), pociones medias (6.11) y la cola larga de partidas.

Esto es un bug de bot (grave para la calidad de partida), no una regla. V2-17 debe empezar por aquí; tras corregirlo, esta fila debería ser ~0.

## Limitaciones

- Mide **turnos y pasos del motor, no minutos**. Para estimar minutos hay que declarar un tiempo por turno humano (por ejemplo 30-60 s); con la media de 33 turnos de jugador serían ≈ 17-33 min, pero es una hipótesis, no una medición (R7: la duración real se mide en M12).
- Los bots no son humanos: reaccionan poco (3.6 %), no se farolean, y ahora mismo caen por el bug anterior. No extrapolar balance de cartas ni asientos a partidas humanas.
- "Nunca jugadas" depende de la heurística del bot (p. ej. no usa artefactos ni cartas de utilidad), no indica que la carta sea mala.
- "Ventanas por jugador" cuenta la apertura por lanzador (evento `reaction_opened`, solo el primer hechizo de una cadena) y la presencia en `awaiting` al abrir; las respuestas encadenadas no se cuentan como ventana nueva.
- Una sola semilla base (1) y una muestra de 50 partidas por tamaño: la variación por asiento es ruidosa. Para comparar tras V2-17/V2-27 usar los mismos argumentos exactos.
- Los jugadores usan edades y avatares fijos por semilla; la configuración es la por defecto (con `log_limit` 50 para no crecer el log).

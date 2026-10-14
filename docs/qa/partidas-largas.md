# Partidas largas y bloqueo (V2-41, QA-V2-21-02)

- Fecha: 2026-10-13. Godot 4.7.2. Código sin cambios de `src/` ni `data/`; solo se ha tocado `tools/sim.gd` (métricas, argumento `--potion-limit`) y se ha añadido `tests/qa/test_sim_bloqueo.gd`.
- Comando base (≈2,5 min): `godot --headless --path . -s tools/sim.gd -- --games 200 --seed 1 --json salida.json`. Los números de la línea base no cambian (46 676 pasos, media 39,6 turnos, 14 partidas > 100): las métricas nuevas no alteran la simulación (la salida de texto previa es idéntica línea a línea).
- **Determinismo verificado:** dos ejecuciones `--games 200 --seed 1` dieron salida de texto y JSON idénticos (`cmp`), incluido el JSON ampliado con métricas por partida. Código de salida 0, 0 violaciones, 0 errores, 200/200 terminadas.
- Verificado: `bash tools/test.sh` 586/586 (incluye 5 tests nuevos de la definición de bloqueo), `bash tools/check_warnings.sh` OK.

## Métricas nuevas (`tools/sim.gd`)

Por partida, en `--json` (`per_game[]`) y resumen en texto ("diagnóstico de bloqueo" + una línea por partida > 100 turnos):

- `blocked_rounds`, `max_idle_run`, `first_block_round`, `block_runs`: **bloqueo** = ≥ 3 rondas cerradas seguidas sin `PLAY_CARD`, `REACT`, `USE_ARTIFACT` ni daño efectivo (`LOG_DAMAGE` con `dealt > 0`). "≥ 2 vivos" se cumple siempre mientras la partida sigue. La ronda abierta al terminar no cuenta. Ronda = la cuenta `rounds` ya existente.
- `cards_per_round` (PLAY_CARD), `plays_per_round` (PLAY_CARD + REACT + USE_ARTIFACT), `damage_events_per_round`, `discards_per_round`, `mana_gained_per_round` (MANA_CHANGED con delta > 0; no incluye pociones), `events_by_round`, `eliminations` (ronda, jugador, causa), `acts`, `healed`, `damage_dealt`.
- `alive_end`, `pool_end` (fin de partida; el pool al final no sirve: lo vuelven a llenar los eliminados), `potion_limit`.
- `block_snapshot`: foto de la **primera vez que se cierran 3 rondas inactivas**: por vivo, vida, maná, pociones, mano con costes; `pool`; `legal_by_type` y `legal_plays` de `Game.legal_actions` para quien tiene el turno; `drink_probe` (qué pasa si bebe: eliminado y maná ganado); `bot_choice` (qué elige el bot ahí).
- Argumento nuevo `--potion-limit N|off` (por defecto el de la config, 10).

## (1) ¿Cuántas colas son bloqueo?

**Las 14 de las 14 partidas > 100 turnos son bloqueo; ninguna es solo una partida lenta.** En total 33 de 200 partidas (16,5 %) tienen bloqueo (1 400 rondas en bloqueo); 19 de ellas acaban en ≤ 100 turnos (media 53), por eso no aparecían en la cola.

| Grupo | n | turnos (media / mediana) | rondas (media) | cartas jugadas (media) |
|---|---|---|---|---|
| Sin bloqueo | 167 | 23,6 / 23 | 8,6 | 29,3 |
| Con bloqueo | 33 | 120,8 / 76 | 56,2 | 36,3 |
| > 100 turnos (todas con bloqueo) | 14 | 212,8 / 180,5 | 101,7 | 37,1 |

En las 14, **1 190 de 1 424 rondas (84 %) son bloqueo**; la racha inactiva más larga va de 17 a 49 rondas. Quitando las 14, la media sería 26,6 turnos (hoy 39,6). El bloqueo no es cosa de pocos jugadores: bloqueadas por tamaño 3j:3, 4j:7, 5j:10, 6j:13; de las 14 largas, 7 son de 6 jugadores. Las partidas sin bloqueo son sanas (mediana 23 turnos).

Las 14 (turnos / rondas / rondas en bloqueo / racha máx.): g=19 436/212/186/49, g=39 390/188/166/27, g=35 320/154/135/41, g=93 250/123/104/30, g=14 229/110/96/29, g=136 227/113/98/21, g=184 114/56/41/24, g=123 180/83/65/20, g=159 181/85/70/32, g=66 156/73/59/32, g=135 141/65/50/29, g=82 124/57/42/29, g=139 119/53/39/20, g=174 112/52/39/17 (semilla = 1+g; ver el texto de la corrida).

## (2) Causa de cada una

Estado en la foto de bloqueo de las 14 (todas, sin excepciones):

- **Quedan exactamente 2 vivos con 10/10 pociones (el límite) y 0-1 de maná** (8 casos con 0 en ambos; 6 con 1 de maná en alguno: g=35, 39, 66, 123, 136, 139). Beber la 11.ª poción elimina y no da maná (`drink_probe`: eliminado, +0, en las 14).
- **El pool común no está vacío:** maná libre 59-69 de 70 y vida libre 55-65. Hipótesis del pool vacío **descartada**: sobra maná en el pool, pero nadie puede cogerlo, porque solo se obtiene bebiendo (3 por poción) y el contador de pociones está al tope.
- **Mano injugable por coste:** coste mínimo en mano 1-2 y 0 maná; ninguna carta cuesta 0. En 13 de 14 `legal_plays` está vacío; en g=35 hay una jugada legal (Curse of Odd, coste 1) y el bot descarta en vez de jugarla (ver §3). g=39 está en un prompt (DECLINE).
- **Curas y escudos que se anulan:** durante el bloqueo no hay jugadas, ni cura ni escudo; el perfil de la partida es el de antes de bloquearse. Las bloqueadas curan más (16,9 frente a 8,0 puntos de media; las > 100: 21,7), es decir gastaron el presupuesto de maná en curas/escudos antes de llegar a 10 pociones.
- **Qué hace avanzar la partida durante el bloqueo:** solo el azar de robar eventos. Durante el bloqueo se robaron eventos de todos los tipos sin efecto (ninguno aporta maná: `mana_gained_per_round` = 0 en las 14 desde la foto). El bloqueo termina por una muerte por vida (causa `hp` en las 33) en una ronda en que sale un evento de daño, y en 26 de 33 hay un evento robado en las dos últimas rondas (visit_of_the_archmage 11 veces, warp_discharge 5, etc.): correlación observada, no verificada la causalidad evento a evento.
- Durante el bloqueo cada ronda es: robo, descarte forzado de mano (límite de mano) y END_TURN (g=19: 867 DISCARD en 436 turnos, 4 descartes por ronda).

Mecánica de fondo (verificada en los datos): el **presupuesto de maná de un mago es 3 por poción × 10 pociones = 30 de por vida** (más lo que den eventos). Un mago que ha bebido 10 pociones y gastado el maná ya no genera nada más, y si queda en la mesa con otro en la misma situación, nadie progresa. Con el límite desactivado esto no ocurre (§4).

## (3) ¿Podría salir un humano con una acción legal que el bot no elige?

**No, en 13 de 14 casos; en 1 (g=35) hay una alternativa marginal.** Acciones legales del jugador con el turno en la foto (`Game.legal_actions`):

- Casos típicos (12 de 14): solo `DISCARD` (31 ó 63 combinaciones), `END_TURN`, `DRINK_POTION` y `CONCEDE`. **Sin PLAY_CARD, sin EXCHANGE** (intercambiar exige ≥ 1 de maná y se tiene 0). Descartar y terminar turno no cambian nada; beber es suicidio (eliminado, +0 maná); rendirse acaba la partida. El bot elige DISCARD (más END_TURN), que es lo único que no pierde.
- g=35 (1 maná): legales `PLAY_CARD` ×1 (Curse of Odd, coste 1) y `EXCHANGE` ×5. El bot descarta. Un humano podría maldecir o intercambiar (1 maná), pero eso consume el último maná y no desbloquea nada: tras gastarlo se queda en el caso típico. **Mejora marginal del bot, no una salida.**
- g=39: en un prompt (`DECLINE` o `DRINK_POTION`); el bot elige DECLINE.
- Salida real para un humano: **ninguna acción legal desbloquea la partida**; solo `CONCEDE`, o esperar a un evento de daño. Un humano que va con cuidado (guardando pociones) evitaría llegar al tope, pero el bot de V2-42 también puede hacerlo: es un problema de planificación, no de acciones disponibles.

Matiz: en los 19 bloqueos cortos (≤ 100 turnos) hay 5 con un jugador por debajo del tope (g=9: 9 pociones; g=54 y g=175: 6; g=60: 3; g=122: 9) donde el bot, con 0-1 de maná y un jugador que aún puede beber, descarta (g=9, g=60, g=122) en lugar de beber o bebe más tarde (g=54, g=175 eligen DRINK_POTION). Son bloqueos transitorios resueltos por esa vía en ≤ 40 turnos.

## (4) Efecto del límite de pociones (50 partidas, semilla 1, misma base)

El límite 10 explícito da exactamente lo mismo que el valor por defecto (comprobado). Resultados (50 partidas cada una; mismas semillas 1..50):

| Límite | turnos (media / mediana / máx) | partidas > 100 | partidas > 200 | partidas con bloqueo | rondas en bloqueo | Eliminaciones por Too Much Mana | terminadas |
|---|---|---|---|---|---|---|---|
| 5 | 130,4 / 74 / 458 | 22 | 12 | 36/50 | 2 394 | 0 | 50/50 |
| **10 (defecto)** | 51,6 / 23,5 / 436 | 4 | 4 | 9/50 | 655 | 0 | 50/50 |
| desactivado | 24,2 / 24 / 51 | 0 | 0 | 0/50 | 0 | 0 | 50/50 |

(Estas 50 partidas son las primeras de la corrida de 200; en ellas el 10 pasa de 4 a las 14 totales.) Con 5 el bloqueo se multiplica (+ 2 394 / 655 = 3,7 veces más rondas en bloqueo, media de turnos × 2,5); desactivado, **cero bloqueos y partidas de 24,2 turnos** (máx. 51), como la mediana normal. Con límite 5 los bots siguen sin morir por Too Much Mana (0 eliminaciones): se quedan bloqueados en vez de suicidarse. Pociones medias a fin de turno: 4,71 (límite 5), 4,76 (desactivado; ya no llegan a 10 porque no hace falta).

## (5) Conclusión: ¿bots, regla o ambos?

**Ambos, con la regla como causa necesaria y los bots como agravante evitable.**

1. **Causa necesaria: la regla adaptada del límite de pociones.** Con el límite desactivado hay 0 bloqueos en 50 partidas (frente a 9 con 10 y 36 con 5); las 33 partidas bloqueadas de 200 acaban todas con 2 vivos a 10/10 pociones (28 de 33 con ambos al tope en la foto; en los otros 5 hay uno por debajo) y 0-1 de maná, con el pool lleno. La regla hace finito el maná de cada mago (30) y deja la partida sin acciones útiles. Un humano en esa mesa **no tiene acción legal que la desbloquee** (§3), así que V2-43 (Game Designer) **sí procede**: no basta con arreglar a los bots si el objetivo es que ninguna mesa se atasque. Pero tampoco es un problema solo de reglas: el 83,5 % de las partidas (167/200) no se bloquea, y con el límite 10 la mediana (23) está dentro de objetivo.
2. **Agravante de los bots (V2-42):** (a) beben hasta exactamente 10 (`Bot.potion_room(.., reserve)` deja entrar hasta el límite) y agotan los 30 de maná en curas/escudos (las bloqueadas curan 16,9 de media frente a 8,0), llegando al final de la partida sin recursos; (b) en la g=35 descartan con una jugada de 1 maná legal y 5 intercambios; (c) con jugadores por debajo del tope a veces descartan en vez de beber (g=9, g=60, g=122); (d) se quedan en la mesa con 2 vivos y 10/10 en vez de buscar un cierre antes de agotar el maná. V2-42 puede acortar la cola, pero **no puede eliminar el bloqueo cuando ambos vivos llegan a 10/10 y 0 de maná**: su objetivo medible (≤ 4 partidas > 100 turnos de 200) es alcanzable si los bots llegan al final con maná de reserva; el criterio "0 > 200 turnos" solo se cumple si la gestión de pociones evita llegar a ese estado, porque ahí ningún bot tiene jugada.
3. **Cifras para decidir:** 14/200 (7 %) > 100 turnos, 6/200 (3 %) > 200, 33/200 (16,5 %) con algún bloqueo, 84 % de las rondas de las colas son bloqueo. Con el límite desactivado: 0/50. El umbral de E6 (> 2 % por encima de 100 tras V2-42 o humano atascable) se cumple en lo segundo ya hoy: un humano **puede** quedar sin salida legal.

No se proponen cambios de reglas de cartas ni opciones de regla aquí (lo hará V2-43 si el Director lo mantiene).

## Limitaciones

- Una semilla base; las comparaciones de §4 son con 50 partidas (ruido alto: la corrida de 50 incluye 4 de las 14 colas).
- La causalidad "evento de daño termina el bloqueo" es una correlación observada, no verificada evento a evento.
- La foto se toma a las 3 rondas inactivas, no en el peor momento; el estado posterior (potencias, maná 0) se infiere de `alive_end` y de que `mana_gained_per_round` sigue en 0, no se fotografió ronda a ronda.
- No hay humanos: "un humano no tiene salida" se deduce de `Game.legal_actions` (acciones legales), no de pruebas con usuarios (M12).

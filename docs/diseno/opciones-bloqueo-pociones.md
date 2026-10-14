# Opciones de regla para el bloqueo por límite de pociones (V2-43, E6)

Solo documento. **No cambia ninguna carta ni su texto. La decisión es del usuario.** Cualquier cambio de regla se implementaría en v0.3, no en v0.2.

## 1. Punto de partida

- En la mesa física, "Too Much Mana" es una borrachera real: quien bebe de más queda K.O. (manual: "by K.O. (also known as Too Much Mana)"). **El límite numérico (10) es una adaptación digital nuestra y configurable** (`potion_limit_enabled`, `potion_limit` en `Types.default_config`; en `Damage.drink_potion` la poción n.º límite+1 cuenta y elimina sin dar maná, AMBIGUEDADES T4).
- Diagnóstico de V2-41 (`docs/qa/partidas-largas.md`): las 14 de 14 colas (> 100 turnos de 200 partidas) son bloqueo. Quedan 2 vivos con 10/10 pociones y 0-1 de maná; beber es suicidio, no hay jugada legal, el pool tiene maná libre (59-69 de 70) que nadie puede coger (solo se obtiene bebiendo). **Ninguna acción legal desbloquea la mesa**; solo un evento de daño o rendirse. El presupuesto de maná por mago es 3 x 10 = 30 de por vida.
- Dato nuevo relevante para elegir: **en ninguna de las corridas hay eliminaciones por Too Much Mana (0 en todas)**. Los bots nunca se suicidan; se quedan bloqueados. Por tanto el K.O. de pociones no se está ejerciendo en simulación y su efecto de tensión solo puede juzgarse con humanos (M12).

## 2. Cifras medidas (50 partidas, semilla 1, mismas semillas 1..50)

Comando: `godot --headless --path . -s tools/sim.gd -- --games 50 --seed 1 --potion-limit N`. Todas: 50/50 terminadas, 0 violaciones, 0 errores, 0 eliminaciones por Too Much Mana.

| Límite | Partidas con bloqueo | Rondas en bloqueo | Turnos media / mediana / máx | Partidas > 100 turnos | Pociones medias a fin de turno de bot | Elim. por Too Much Mana |
|---|---|---|---|---|---|---|
| 5 (V2-41) | 36/50 | 2 394 | 130,4 / 74 / 458 | 22 | 4,71 | 0 |
| **10 (defecto)** | 9/50 | 655 | 51,6 / 24 / 436 | 4 | 7,47 | 0 |
| 15 | 1/50 | 4 | 24,5 / 25 / 52 | 0 | 4,85 | 0 |
| 20 | 0/50 | 0 | 24,1 / 25 / 47 | 0 | 4,69 | 0 |
| desactivado | 0/50 | 0 | 24,2 / 25 / 51 | 0 | 4,76 | 0 |

Lectura: de 10 a 15 el bloqueo cae de 9 a 1 partidas y la cola desaparece (máx. 436 a 52 turnos); a 20 es igual que desactivado. Con 15 la mesa sana (mediana 25) no cambia respecto a "desactivado", es decir, el límite 15 casi nunca se alcanza por jugadores que no acaparan. Limitación: una sola semilla y 50 partidas; los bots actuales pueden cambiar tras V2-42, así que hay que repetir con la política nueva antes de fijar el valor.

## 3. Opciones

### (a) Dejarlo como está (límite 10) y arreglar solo bots (V2-42)
- **Qué cambia:** nada en reglas. V2-42 hace que los bots lleguen al final con maná de reserva.
- **Efecto esperado:** V2-41 estima que reduce la cola pero **no la elimina** si dos vivos llegan a 10/10 con 0 de maná. Cifras hoy: 14/200 > 100 turnos (7 %), 6/200 > 200. Con V2-42 el objetivo es <= 4/200 > 100.
- **Riesgos:** tono, intacto (K.O. real a 10). Balance de cartas, intacto. M12: un humano **sí puede quedar sin salida** (no es un problema de bots) y tendría que rendirse; una sola partida así arruina la prueba.

### (b) Subir el límite por defecto (15 o 20) o desactivarlo, conservando el K.O. como opción
- **Qué cambia:** solo `potion_limit` en `default_config` (10 a 15 o 20), o `potion_limit_enabled: false`. Sin cambio de motor; los ajustes ya existen y la sim ya admite `--potion-limit`.
- **Efecto medido:** ver tabla: 15 deja 1 bloqueo de 4 rondas y 0 colas; 20 y "off" dejan 0.
- **Riesgos:** tono: el K.O. se vuelve casi inalcanzable (15 pociones = 45 de maná, el pool entero es 70; con 20 ya es imposible en la práctica y con "off" desaparece la tensión de "pasarse", pilar D2). Con 15 sigue habiendo amenaza para quien acapare, pero menos. Balance de cartas: alterado solo de forma indirecta (más maná disponible por mago: hasta 45 en vez de 30 de por vida), a medir tras el cambio con las 58 cartas; los bots actuales casi no usan ese margen (media 4,8 pociones). M12: es la que menos riesgo tiene de partidas atascadas; deja abierto el K.O. para quien quiera la regla física estricta (opción en ajustes).

### (c) La poción n.º límite+1 no se puede beber (en vez de eliminar)
- **Qué cambia (cambio pequeño y localizado):** en `Damage.drink_potion` y `Game.legal_actions`, si `potions >= potion_limit`, `DRINK_POTION` deja de ser legal (no se emite la acción) en lugar de eliminar. Con prompts de "falta de maná" ya existe el caso de no poder pagar: habría que decidir que la carta/pago se rechaza igual que hoy sin maná.
- **Efecto esperado: ninguno sobre el bloqueo.** Los bots ya no beben la poción límite+1 (0 eliminaciones), así que los resultados serían idénticos a (a) en simulación: sigue habiendo 2 vivos a 10/10, 0 de maná y sin jugadas. Solo cambia que un humano ya no puede suicidarse por error. No se mide con la config actual porque no hay nada que medir (resultados esperados iguales a la fila 10).
- **Riesgos:** **rompe el tono** (la poción de más deja de ser un riesgo: se convierte en un tope y desaparece el K.O. como amenaza). No arregla el atasco. Balance: sin efecto sobre cartas. M12: elimina un fallo de usuario (beber sin querer) pero no el bloqueo. **No recomendada como solución al bloqueo**; sí tendría sentido si M12 muestra eliminaciones accidentales.

### (d) Variante anti-bloqueo, desactivada por defecto
- **Qué cambia:** nuevo ajuste `anti_stall_rounds` (0 = apagado). Si pasan N rondas cerradas seguidas sin jugada, reacción, uso de artefacto ni daño (misma definición de bloqueo de V2-41, N=3 propuesto como mínimo razonable; puede ser mayor, 5), cada mago vivo pierde 1 de vida al cierre de la ronda (la vida vuelve al pool) hasta que haya jugada. Cambio localizado en el cierre de ronda de `Game`; no toca cartas. Hay que fijar los empates: si dos magos quedan a 1 de vida y ambos caen a la vez, definir el ganador (menos pociones, o gana el que tenía más vida al empezar el bloqueo). Esto necesita decisión del usuario y es **un cambio de regla nuevo, no una carta física**.
- **Efecto esperado (estimación, no medida; hoy no se puede simular sin tocar `src/`):** en las 14 colas quedaban 2 vivos con vida 3-6; con N=3 el bloqueo terminaría en <= 3 + vida mínima del par (≈ 6-9 rondas) en lugar de las 17-49 rondas de racha máxima (1 190 rondas en bloqueo de las 14 colas pasarían a ≈ 100-130). Habría que implementarlo en una rama para medirlo.
- **Riesgos:** tono: aparece un reloj de "fatiga" que no existe en la mesa; es una regla de torneo habitual y solo actúa cuando nadie puede hacer nada. Balance de cartas: ninguno en partidas normales (no se activa si hay jugadas, 83,5 % de partidas sin bloqueo). Riesgo: dispararse en pausas legítimas (todos sin maná temporalmente con jugadas pendientes de robar) si N es pequeño; N=3 coincide con la definición de V2-41, que ya no incluyó falsos positivos en las partidas sanas. M12: el humano no se queda mirando y evita rendirse; hay que mostrar en la pantalla un aviso "la mesa está bloqueada: cada mago pierde 1 de vida" (texto a coordinar con el Narrative Designer).

### (e) Otras que se ven en los datos
- **(e1) Límite dinámico: sube al quedar 2 vivos** (p. ej. +5 cuando solo quedan 2 magos). Cambio localizado en `drink_potion`: con 2 vivos el límite no se aplica (o sube +5). Ataca justo la foto de las 14 colas (2 vivos a 10/10), mantiene el K.O. en la parte tensa de la partida (3+ vivos). Efecto esperado: probablemente cerca de "desactivado" en bloqueos (todas las colas son 2 vivos), no medido. Riesgo: tono, se mantiene al principio; en el duelo final desaparece el K.O. justo cuando más dramático sería; regla algo menos clara de explicar en la ayuda.
- **(e2) Devolver una poción al descartar** (descartar toda la mano a cambio de bajar 1 de contador de pociones). Daría una salida a quien está a 10/10 sin maná (la mano completa que hoy se descarta gratis cada ronda se convierte en recurso). Es un cambio de economía mayor: afecta el balance (más maná sin límite) y el tono (la poción deja de ser definitiva). Solo se menciona; no se recomienda.
- **(e3) Complemento, no regla: V2-42** (bots con reserva de pociones) combinado con cualquiera de las anteriores. No sustituye a una regla porque el humano sigue sin salida con (a).

## 4. Tabla resumen

| Opción | Cambio | Quita el bloqueo | Cifras | Tono (tensión del maná) | Balance de cartas | M12 |
|---|---|---|---|---|---|---|
| (a) 10 + V2-42 | solo bots | No del todo (humano sigue atascable) | 10: 9/50 con bloqueo, máx. 436 turnos; tras V2-42 por medir | Intacto | Intacto | Riesgo de partida atascada |
| (b1) límite 15 | `potion_limit` 15 | Casi (1/50, 4 rondas) | máx. 52 turnos, 0 > 100 | K.O. posible pero raro | Indirecto: hasta 45 de maná vitalicio; medir | Muy bajo riesgo |
| (b2) límite 20 | `potion_limit` 20 | Sí (0/50) | máx. 47 | K.O. prácticamente inalcanzable | Idem | Muy bajo |
| (b3) desactivado | `potion_limit_enabled` false | Sí (0/50) | máx. 51 | Sin K.O. por defecto (pilar D2 perdido) | Idem | Muy bajo |
| (c) límite+1 no se puede beber | `drink_potion` / `legal_actions` | **No** (los bots ya no beben de más) | Igual a (a) | K.O. se pierde igualmente | Intacto | No evita atasco; evita error accidental |
| (d) anti-bloqueo 1 de vida | ajuste nuevo, cierre de ronda | Sí, en ≈ 6-9 rondas (estimado) | No medible hoy | Reloj extra, solo si hay bloqueo | Intacto salvo en bloqueo | Evita rendirse; hay que mostrar aviso |
| (e1) límite se ignora con 2 vivos | `drink_potion` | Probable (todas las colas son de 2 vivos) | No medido | K.O. solo con 3+ vivos | Intacto salvo final | Bajo riesgo |

## 5. Recomendación razonada

**Opción (b) con límite 15 por defecto, conservando el K.O. como opción** (el ajuste ya existe; "desactivar" queda para quien lo prefiera), y **(d) como variante opcional desactivada por defecto en v0.3** solo si M12 o la sim posterior a V2-42 siguen mostrando partidas atascadas.

Razones: (1) con límite 15 la sim pasa de 9/50 a 1/50 partidas con bloqueo (4 rondas) y de máx. 436 a máx. 52 turnos, sin bajar la mediana de partida sana; (2) conserva el K.O. real (a 15 pociones seguiría eliminando a quien se pase, la regla de la mesa física) y la tensión para jugadores que acaparan, mientras que 20 y "off" ya lo hacen inalcanzable; (3) es un cambio de un valor de configuración, sin cambiar motor ni cartas; (4) (c) no arregla nada (los bots no beben de más) y (a) deja al humano sin salida. Caveats: una semilla y 50 partidas; hay que repetir 200 partidas con V2-42 y con `--potion-limit 15` antes de fijar; y el balance con hasta 45 de maná vitalicio debe revisarse (más curas/escudos). Sin humanos no se puede juzgar cuánta tensión pierde el 15 respecto al 10: M12 debe anotarlo.

## 6. Criterios de aceptación (si se elige alguna)

- (b): dado `potion_limit` por defecto 15, cuando se ejecutan 200 partidas con `--seed 1`, entonces 200/200 terminadas, 0 violaciones, partidas > 100 turnos <= 4, y un mago que bebe la poción n.º 16 queda eliminado por Too Much Mana sin recibir maná (test del motor ya existente con el valor nuevo).
- (d): dado `anti_stall_rounds` = 3 y 2 vivos sin jugadas 3 rondas cerradas, cuando se cierra la ronda, entonces cada vivo pierde 1 de vida (vuelve al pool) y se registra un evento visible; con `anti_stall_rounds` = 0 el comportamiento no cambia; con un empate simultáneo a 0 de vida se aplica el desempate acordado.
- (c): dado un mago con `potions` = `potion_limit`, cuando se piden las acciones legales, entonces no incluyen `DRINK_POTION` y no hay eliminación por Too Much Mana.

# Textos de interfaz v0.2 (V2-08)

Autor: Narrative Designer. Fecha: 2026-10-13. Código: `src/ui/strings.gd` (`class_name Strings`, solo funciones estáticas y constantes, sin estado). La integración en `log_text.gd`, `table.gd` y las pantallas es de V2-16. Tono: humor seco, corto, claro (`docs/VISION.md`).

## Reglas de estilo
- Nombres de carta y de evento: en inglés, tal como están en el catálogo. El texto original de las cartas no se traduce ni se reescribe (© SUPERHOTEX). Nombres de eventos del registro ("Fire Storm") igual.
- Nunca claves internas ni `_`. Si una carta no está en el catálogo, `Strings.card_name` humaniza el id.
- Plurales correctos con `Strings.cards(n)`: "1 carta", "2 cartas", "0 cartas".
- Nombres de mago: se pasan en `names` (pid -> nombre). Sin género: "sale de la partida", no "eliminado/a".

## Cómo usarlo (V2-16)
| Necesidad | Llamada |
|---|---|
| Línea de registro | `Strings.log_text(entry, names)` (cubre los 22 `Types.LOG_*` y los 28 `what`) |
| Cobertura / test | `Strings.LOG_TYPES`, `Strings.EFFECT_WHATS` |
| Motivo de "no jugable" | `reason_mana`, `reason_missing_cards`, constantes `REASON_*` |
| Coste en la ficha | `mana_line(efectivo, base)`, `type_line(tipo, elemento)` |
| Pago | `requirement_text(cost.cards, scroll)`, `pay_header`, `pay_mana_note`, `discard_title` |
| Errores | `error_text(Types.ERR_*)` |
| Decisiones | `prompt_*`, `button_*` / `BUTTON_*` |
| Reacción | `reaction_title(..., against_me)`, `AGAINST_YOU`, `LOG_AUTO_PASS_TEXT` |
| Pasar el dispositivo | `PASS_DEVICE_TITLE`, `pass_device_reason(PASS_REASON_*, nombre)`, `pass_device_button` |
| Fin de partida | `end_title`, `end_tie_text`, `end_cause`, `end_final_blow`, `end_self_blow`, `end_by_source`, `end_potion_blow`, `end_row`, `end_stats`, `ordinal` |

Cambios de datos que V2-16 debe saber: `LOG_CARD_PLAYED` y `LOG_REACTION_OPENED` traen `data.targets` (lista), no `data.target`: el viejo `log_text.gd` leía la clave equivocada y por eso salía "Ana juega X." sin objetivo. `LOG_MANA_CHANGED` usa `data.delta` (no `amount`); `LOG_DAMAGE` usa `dealt` y `prevented`. `LOG_RULE_BROKEN`: `entry.player` es quien acusa y `data.target` quien rompió la regla.

## Registro: una línea por evento
Ejemplos con Ana (p1), Bruno (p2), Cira (p3).
| Tipo | Texto |
|---|---|
| game_started | Empieza la partida. |
| turn_started | Turno 3: Cira. |
| turn_skipped | Bruno pierde el turno por estar congelado. |
| card_drawn | Ana roba Fireball. / Ana roba una carta. (privado: sin carta) |
| event_drawn | Ana saca el evento Fire Storm. |
| deck_reshuffled | Se acaba el mazo: se baraja el descarte. |
| card_played | Ana juega Fireball contra Bruno. / Ana juega Heal sobre sí. / Ana juega Armageddon. (sin objetivo) |
| card_discarded | Ana descarta Fire Arrow. / Ana descarta 2 cartas por Icy Grasp. |
| exchange | Ana cambia Heal (1 de maná). |
| potion | Ana bebe una poción y gana 3 de maná (n.º 4). / Ana bebe la poción n.º 11 y no gana nada de maná. |
| damage | Bruno recibe 3 de daño (Fireball, de Ana). / Bruno recibe 1 de daño (...); evita 2. / Bruno evita 3 de daño (...). / Bruno pierde 2 de vida (...) si es pérdida directa. |
| heal | Ana recupera 2 de vida. |
| mana_changed | Bruno pierde 2 de maná (Mana Implosion). / Bruno gana 3 de maná. / "; le faltan N" si no tenía. |
| reaction_opened | Ana lanza Fireball contra Bruno. Hora de reaccionar. |
| reaction_passed | Cira pasa. |
| reacted | Cira responde con Magic Shield. |
| spell_resolved | Se resuelve Fireball de Ana. / Magic Shield de Cira surte efecto. (respuesta) |
| spell_cancelled | Se cancela Fireball de Ana. |
| rule_broken | Ana acusa a Bruno de romper la regla: pierde 1 de maná. |
| eliminated | Bruno se queda sin vida y sale de la partida. / ...se pasa de pociones (Too Much Mana)... / ...se rinde... |
| game_over | Fin de la partida. Gana Ana. / Ganan Ana y Bruno. / ...no queda ningún mago en pie. |

### Efectos (`LOG_EFFECT`, `data.what`)
| what | Texto |
|---|---|
| fizzled | Fireball no tiene efecto. |
| used_as_payment | Ana usa su Scroll of Elements como pago de Fireball. |
| rule_established | Nueva regla de mesa: «...». |
| peeked_deck / peeked_card | Ana mira la carta de arriba del mazo. / Arriba del mazo está Heal. |
| next_potion_doubled | La próxima poción de Ana vale el doble. |
| loss_avoided | Ana descarta Magic Cap y evita la pérdida. |
| immune | Bruno es inmune a Freeze gracias a Force Field. |
| last_wish | Ana prepara Last Wish. / Last Wish de Ana devuelve 4 de daño a Bruno. |
| hands_exchanged / hand_seen / hand_cards | Ana intercambia la mano con Bruno. / Ana mira la mano de Bruno. / Mano de Bruno: Heal, Fire Arrow. |
| drank_to_avoid | Ana bebe una poción para evitar Visit of the Archmage. |
| curse_targets | Curse of the Elder afecta a Bruno y Cira. / ...no afecta a nadie. |
| card_stolen / card_stolen_detail / card_stolen_private | Ana roba una carta a Bruno. / Ana se queda Heal de Bruno. |
| steal_empty | Bruno no tiene cartas que robar. |
| lowest_mana | Warp Discharge: Cira, con menos maná, pierde vida. |
| **blinded** | Bruno queda cegado: no podrá lanzar ofensivas en su próximo turno. |
| **frozen** | Bruno queda congelado: pierde su próximo turno. / ...pierde sus próximos 2 turnos. |
| **frozen_bunny** | Cira protege a Bruno con Frozen Bunny: no recibe daño de este hechizo. |
| **magic_shield** | Cira protege a Bruno con Magic Shield: el daño baja en 2. |
| **force_field** | Bruno queda protegido por Force Field hasta el próximo turno de Ana. / Ana se protege con Force Field hasta su próximo turno. |
| **mirror_shield** | Cira usa Mirror Shield: el daño contra Bruno pasa a Ana. |
| **magic_capture** | Cira recupera Fireball del descarte con Magic Capture. |
| **annihilation** | Cira cancela Fireball con Annihilation. / Cira destruye Scroll of Elements de Bruno con Annihilation. |
| **lightning_redirected** | El rayo salta de Bruno a Cira y ahora hace 3 de daño. |
Si un `what` nuevo aún no tiene texto: "{Carta} surte efecto." (nunca "efecto aplicado"). QA debe recorrer `Strings.EFFECT_WHATS` y comprobar que ninguna salida contiene `_`.

## Pistas
- Tu turno: "Tu turno: juega, descarta, cambia o termina el turno." / "Toca una carta para ver su ficha." / "Mantén pulsada una carta para verla en grande." / "Elige un objetivo." / "Elige 2 objetivos." / "Responde con una defensiva o un Lightning, o pasa." / "Puedes beber una poción cuando quieras." / "Esperando a Cira…" / "Juega Bruno…".
- Poción: "Poción 3/10" (sin límite "Poción 3"); desde límite-2: "Cuidado: llevas 8 de 10 pociones."; en el límite: "Otra poción y quedas eliminado (Too Much Mana)."

## Motivos de "no jugable" (criterios §3.1)
Textos exactos de la tabla de §3.1: "No es tu turno" / "Resuelve primero la decisión pendiente" / "Solo puedes responder con una defensiva o un Lightning" / "Cuesta 2 de maná y tienes 1. Bebe una poción." / "Cuesta 2 de maná y tienes 1." / "Te falta 1 carta de fuego." / "Estás cegado: no puedes lanzar ofensivas este turno." / "Solo se juega en respuesta a un hechizo." / "No hay un objetivo válido." Ficha: "Maná: 2 (base 1)", "Ofensiva de fuego", "Apoyo", "Ofensiva, sin elemento".

## Pago (criterios §4)
- Encabezado: `Fireball: paga 1 carta de fuego (0/1)`; `Armageddon: paga 1 carta de fuego, 1 carta de hielo y 1 carta de electricidad (0/3)`; con Scroll: "... (o tu Scroll of Elements)".
- Por tipo: "1 carta de maldición", "1 carta de apoyo", "1 carta defensiva" / "2 cartas defensivas".
- Maná aparte: "Maná: 1, se descuenta al confirmar". Descarte: "Descarta 2 cartas (Icy Grasp)." / "Descarta 1 carta." Sin "carta(s)" en ningún sitio (QA-V2-03-03).

## Errores de reglas (`error_text`)
No es tu turno. / Hay un hechizo en el aire: primero se responde o se pasa. / No hay ningún hechizo al que responder. / Ahora no te toca decidir. / Resuelve primero la decisión pendiente. / Esa carta no está en tu mano. / Esa carta no se puede jugar ahora. / No te alcanza el maná. / Las cartas de pago no valen para esta jugada. / Ese objetivo no vale. / Ese mago es inmune a hechizos por ahora. / Ya tienes uno de esos artefactos en la mesa. / Ese artefacto ya se usó este turno. / La mesa cambió mientras jugabas. Inténtalo otra vez. Los demás códigos están en el archivo; el genérico es "Eso no se puede hacer." (sin código).

## Decisiones (prompts)
- Maná insuficiente: "Te faltan 2 de maná. Bebe una poción o pierde esa vida." Botones: "Beber poción" ("Beber poción (¡eliminado!)" si es la última) / "Perder 2 de vida".
- Visit of the Archmage: "Bebe una poción o pierde 1 de vida."
- **Magic Cap (QA-V2-03-07)**: título "Magic Cap" (nombre de carta, inglés); texto "Vas a perder 2 de maná. Descarta tu Magic Cap para evitarlo."; botones "Usar Magic Cap" / "No usar". Ya no dice "gorro".
- Mana Focus: "Vas a recibir 3 de daño. Cada maná que gastes evita 1 de daño. ¿Cuánto gastas?". Elixir Transmutation: "Compra vida: cada punto cuesta 2 de maná." (+ "Ahora no te llega el maná: puedes beber antes.").

## Reacción y "contra ti"
"Ana lanza Fireball contra Bruno.  [Contra ti]" (la etiqueta solo si afecta al jugador; en la interfaz puede ser una banda con el texto `AGAINST_YOU`). Auto-pase por preferencia: línea de registro propia "Pasas: este hechizo no iba contra ti."

## "Pasa el dispositivo" (S5)
Título "Pasa el dispositivo"; motivo en una línea: turno -> "Turno de Cira"; reacción -> "Cira: ¿respondes al hechizo?"; decisión -> "Cira: tienes una decisión pendiente". Botón "Soy Cira". Pie: "Que nadie más mire la pantalla."

## Fin de partida (criterios §8.1)
- Título: "¡Victoria!" / "Derrota" / "Gana Ana" / "Ganan Ana y Bruno" / "Empate" + "Todos los magos cayeron a la vez." o "No queda ningún mago en pie."
- Fila: `Bruno — Se quedó sin vida — Golpe final: Ana con Lightning`; `Cira — Too Much Mana — Bebió la poción n.º 11 (límite 10)`; `Dani — Se quedó sin vida — Por maná insuficiente`; `Ana — Último en pie`; `Ana — Se rindió`; propio: "Se eliminó a sí mismo con Armageddon"; evento: "Por Visit of the Archmage".
- Estadísticas: "Turnos: 5 · Pociones: 4" / "Turnos: 3 · Pociones: 11 (límite 10)". Posiciones: "1.º", "2.º".
- Botones: "Jugar otra vez", "Volver al menú", "Ver resultado".

## Abierto
- Nombres de carta y de evento quedan en inglés: confirmar con el usuario (es la propuesta). Si más adelante se traducen, solo cambia `card_name`.
- La frase "Magic Shield: el daño baja en 2" y "Frozen Bunny: no recibe daño" describen lo que hace el motor; si el usuario prefiere no repetir ni parafrasear efectos de carta, se quitan esos finales sin tocar nada más.

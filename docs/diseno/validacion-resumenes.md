# Validación de los resúmenes de cartas (V2-12)

Contraste de `docs/narrativa/resumenes-cartas.md` con el manual P&P, `data/cards.json`, las imágenes y los efectos implementados (`src/engine/effects/*.gd`, `damage.gd`). Criterio: correcto = un jugador que solo lea el resumen no se lleva una impresión falsa; no se exige completitud. Textos propuestos con los términos de `strings.gd`.

Resultado: 59 correctos, 2 a corregir (Lightning, Last Wish). Ningún desajuste texto-vs-motor.

| id | veredicto | texto propuesto / nota |
|---|---|---|
| CARD_QUICK_REFERENCE | correcto |  |
| CARD_BLANK | correcto |  |
| CARD_FIRE_ARROW | correcto |  |
| CARD_FIREBALL | correcto |  |
| CARD_METEOR_SHOWER | correcto | Motor concuerda: vecinos vivos; el lanzador si es vecino. |
| CARD_ARMAGEDDON | correcto |  |
| CARD_MANA_IMPLOSION | correcto |  |
| CARD_ICE_BOLT | correcto | Sin cartas en mano pierde 1 de maná (manual); omitirlo es aceptable. |
| CARD_BLIZZARD | correcto | Motor concuerda; descarta tras el daño solo quien sigue vivo y no es inmune. |
| CARD_ICE_BOOMERANG | correcto |  |
| CARD_VAMPIRIC_TOUCH | correcto | Motor: cura siempre (lectura literal); no cura si el objetivo ya murió (fizzle). |
| CARD_FREEZE | correcto |  |
| CARD_ICY_GRASP | correcto | Motor concuerda: opcional, no a uno mismo, no si el objetivo muere o es inmune. |
| CARD_LIGHTNING | corregir | **El objetivo pierde 2 de vida; si responde con otro Lightning, +1 de daño y se redirige.** (87 car.). "Con otro Lightning" no dice quién lo juega: lo juega el objetivo (paga 2 de maná) y el daño pasa a otro mago; se puede encadenar. |
| CARD_ELECTRIC_EXPLOSION | correcto | Coste con icono de fuego verificado en la imagen 062: la transcripción es correcta. |
| CARD_BLINDING_FLASH | correcto |  |
| CARD_ELECTRIC_ARC | correcto |  |
| CARD_PARALYSING_TOUCH | correcto |  |
| CARD_MAGIC_SHIELD | correcto |  |
| CARD_MIRROR_SHIELD | correcto | Motor concuerda: no hacia un mago con Force Field; lo redirigido no se vuelve a redirigir. |
| CARD_FROZEN_BUNNY | correcto |  |
| CARD_LAST_WISH | corregir | **Defensiva: si un hechizo de otro mago te mata, él recibe ese mismo daño. Mueres igual.** (86 car.). El motor exige atacante distinto y muerte por vida: un Armageddon propio no lo activa. |
| CARD_MAGIC_CAPTURE | correcto | Motor concuerda: salta las cartas de su propio pago. |
| CARD_ANNIHILATION | correcto | Motor concuerda: mesa (artefacto, maldición, evento), hechizo o respuesta en la ventana. |
| CARD_HEAL | correcto |  |
| CARD_GREATER_HEAL | correcto |  |
| CARD_BOOK_EXCHANGE | correcto |  |
| CARD_MAGIC_HAND | correcto |  |
| CARD_FORCE_FIELD | correcto | Motor concuerda (reactions.gd, damage.gd): no se puede apuntar con hechizos (ni curar); las defensivas sí. |
| CARD_POTENT_ELIXIR | correcto |  |
| CARD_SPACE_SHIFT | correcto |  |
| CARD_CURSE_OF_RULES | correcto | Motor concuerda: BREAK_RULE a cualquiera, lanzador incluido; Runic Armor lo anula, Force Field no. |
| CARD_CURSE_OF_THE_ELDER | correcto | Motor concuerda: edad estricta; Force Field y Runic Armor excluyen. |
| CARD_CURSE_OF_THE_YOUNGER | correcto | Idem Elder. |
| CARD_CURSE_OF_VIGOUR | correcto | Motor concuerda: vida >= la del lanzador, lanzador incluido. |
| CARD_CURSE_OF_EVEN | correcto | Motor concuerda (mes par), lanzador incluido. |
| CARD_CURSE_OF_ODD | correcto | Motor concuerda (mes impar), lanzador incluido. |
| CARD_FIREPROOF_TIARA | correcto | Coste eléctrico verificado en la imagen 132; protege contra fuego, como dice el texto. |
| CARD_PADDED_BOOTS | correcto |  |
| CARD_FARADAYS_CLOAK | correcto |  |
| CARD_WILD_FIRE | correcto |  |
| CARD_DRAGON_GLASS | correcto |  |
| CARD_TESLA_COIL | correcto |  |
| CARD_SPELLBOOK | correcto |  |
| CARD_MAGIC_CAP | correcto | Motor: aplaza daño o pérdida de maná y pregunta; la vida perdida por faltante de poción no se puede evitar (matiz menor). |
| CARD_RUNIC_ARMOR | correcto |  |
| CARD_SCROLL_OF_ELEMENTS | correcto |  |
| CARD_TRANSFORMATION_GLOVE | correcto | Motor concuerda: solo en tu turno. |
| CARD_TWARDOWSKYS_MIRROR | correcto | Motor concuerda: solo en tu turno; solo lo ve quien lo usa. |
| CARD_VISIT_OF_THE_ARCHMAGE | correcto | Motor: aviso opcional por mago; rechazar = 2 de daño sin elemento. |
| CARD_NOT_ENOUGH_MANA | correcto | Motor: usa el daño final tras prevenciones (0 si se previene todo). |
| CARD_SHOT_GLASS | correcto |  |
| CARD_FIRE_STORM | correcto |  |
| CARD_ICE_STORM | correcto |  |
| CARD_LIGHTNING_STORM | correcto |  |
| CARD_MANA_FOCUS | correcto | Motor concuerda; la conversión parcial es una extensión (ver pendientes). |
| CARD_DISRUPTED_GRAVITY | correcto |  |
| CARD_BLESSING | correcto |  |
| CARD_WARP_DISCHARGE | correcto | Motor concuerda; con empate pierden todos los empatados (omitido, aceptable). |
| CARD_ELIXIR_TRANSMUTATION | correcto | Motor: un único aviso por mago con vida < 10; ver pendientes. |
| CARD_ANTI_JOKER | correcto |  |

## Desajustes texto inglés vs. motor (para QA)

Ninguno encontrado en las cartas revisadas. Matices a cubrir con tests, no bugs:
- Heal / Greater Heal / cualquier hechizo de soporte no puede apuntar a un mago con Force Field (incluido uno mismo): lectura literal de "cannot be affected by spells".
- Vampiric Touch cura aunque el daño se prevenga (literal).
- Last Wish: no actúa si el atacante es el propio mago o si la muerte no es por vida.
- Not Enough Mana quita maná igual al daño final (tras prevenciones), no al nominal.

## Pendientes de decisión humana

1. Elixir Transmutation: la carta no indica duración; el motor da una única oportunidad al revelarse (¿o hasta el siguiente evento / siempre que quieran?).
2. Mana Focus: el texto dice "the same amount"; el motor permite conversión parcial (k de maná, resto en vida). Confirmar o limitar a todo-o-nada.
3. Vampiric Touch: curar aunque el daño se prevenga (literal) frente a curar solo el daño causado.
4. Force Field impide curarse a sí mismo con Heal (literal); decidir si se mantiene.
5. Curse of Elder/Younger: misma edad = no afectado (estricto), sin desempate por mes.
6. Curse of Rules: la regla es texto libre y la denuncia es manual (honor system); confirmar el flujo en línea (host o afectado).

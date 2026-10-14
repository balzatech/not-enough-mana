# Informe de auditoría del catálogo (T7)

Fuente: `data/cards.json` (61 diseños, 165 cartas, 154 jugables) frente a `assets/cards/NNN.webp`.

Leyenda de iconos de la banda de coste, confirmada con las imágenes: triángulo rojo hacia arriba = fuego; triángulo azul invertido = hielo; rayo naranja = electricidad; rombo blanco = carta defensiva; círculo verde = carta de soporte; ojo morado = maldición.

## Veredictos de las cartas pedidas

| Carta (página) | Pregunta | Veredicto |
|---|---|---|
| Electric Explosion (62) | ¿Pide carta de fuego? | **Sí.** Coste 2 maná + triángulo rojo (fuego). JSON correcto (`element: fire`, 1 carta). Es raro por ser un hechizo eléctrico, pero así está impreso. |
| Fireproof Tiara (132) | Coste | Correcto: 4 maná + rayo naranja (electricidad). La imagen NO pide fuego aunque el efecto proteja contra fuego. Texto: "fire spells deal 1 less damage to you". |
| Padded Boots (133) | Coste | Correcto: 4 maná + triángulo rojo (fuego). Protege contra hielo. Texto "ice spells deal 1 less damage to you". |
| Faraday's Cloak (134) | Coste | Correcto: 4 maná + triángulo azul invertido (hielo). Protege contra electricidad. |
| Frozen Bunny (90) | ¿Coste 0 + hielo? | **Confirmado.** No hay píldora de maná, solo un icono de hielo. JSON `mana: 0`, 1 carta de elemento hielo. Sin encantamiento impreso. |
| Elixir Transmutation (164) | ¿Dice duración? | **No.** Texto íntegro: "All wizards can gain any amount of ♥ by spending 2💧 for each." No hay "until the next event". Texto, iconos (vida ganada, maná pagado) y coste 0 coinciden con el JSON. Se mantiene la lectura de oportunidad única (ya en `docs/AMBIGUEDADES.md`). Conservé `needs_human_review: true` para que lo confirmes tú. |

Patrón de los artefactos de protección: el elemento exigido en el coste es distinto del que bloquean (Tiara: paga electricidad, bloquea fuego; Boots: paga fuego, bloquea hielo; Cloak: paga hielo, bloquea electricidad). Es coherente en las tres, por lo que parece intencional y no una errata de datos.

## Tabla de discrepancias

| Carta | Página | Campo | JSON | Imagen | Severidad |
|---|---|---|---|---|---|
| (ninguna) | - | - | - | - | - |

No hay discrepancias de coste, iconos, elemento ni texto en las cartas revisadas. No se modificó `data/cards.json`.

## Cartas revisadas con la imagen (44 imágenes)

- Con `needs_human_review`: 164.
- Maldiciones (todas): 124, 127, 128, 129, 130, 131.
- Eventos (todos): 154 a 164.
- Artefactos (todos los diseños): 132, 133, 134, 135, 136, 137, 138, 141, 144, 145, 152, 153.
- Ofensivas: 11 (Fire Arrow), 28 (Armageddon), 29 (Mana Implosion), 62 (Electric Explosion).
- Defensivas: 74 (Magic Shield), 85 (Mirror Shield), 90 (Frozen Bunny), 91 (Last Wish), 95 (Annihilation).
- Soporte: 97 (Heal), 111 (Book Exchange), 113 (Magic Hand), 118 (Potent Elixir).
- No jugable: 165 (Anti-Joker).

No revisadas visualmente (se fían de las notas del JSON): el resto de ofensivas, defensivas y soporte, copias repetidas de un mismo diseño, quick_reference y blank.

## Cobertura de efectos

`tests/test_catalog_effects.gd::test_catalog_effects_registered` falla mientras los agentes de efectos no terminen. En el momento de la auditoría `registry.gd` aún tenía las 58 líneas comentadas, así que faltaban los 58 ids jugables. Hay que volver a lanzarlo al final. No hay errores de efectos que reportar, aún no existen.

## Cartas que el usuario debe revisar a ojo

1. Elixir Transmutation (164): confirmar que el evento es de efecto único y no dura hasta el siguiente evento.
2. Electric Explosion (62): confirmar que el coste en fuego es lo que quieres jugar.
3. Fireproof Tiara (132), Padded Boots (133) y Faraday's Cloak (134): confirmar que el elemento de coste y el que bloquean no coinciden por diseño.
4. Frozen Bunny (90): coste 0 de maná, solo un hechizo de hielo.

## Tests

- `tests/test_catalog.gd` (9 tests, pasan): 61 diseños, 165 cartas, 154 jugables, 58 diseños jugables, no jugables = quick_reference/blank/anti_joker, ids únicos, páginas 1-165 sin solapes ni huecos y con imagen, `quantity` = nº de páginas, `validate_card_def` y forma de `make_card_def`, flags coherentes con el tipo, id jugable con constante `CARD_*`.
- `tests/test_catalog_effects.gd` (separado): cobertura en el registro.

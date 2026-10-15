# v0.3: ataque, defensa y temporizadores (V3-01)

Autor: Game Designer. Fecha: 2026-10-14. Entrada: `docs/revision/requisitos-v03-usuario.md` (R5, R6, R7), `docs/revision/LINEAMIENTOS-v03.md` §3-§5, decisiones E11 y E12 del usuario (no se reabren). Alcance: partida de **1 humano contra 2-5 bots** (hot-seat oculto). Los bots **no tienen plazo ni temporizador**.

Esto especifica la experiencia del jugador. No hay cambios de reglas de cartas ni del motor: el motor no lee el reloj; la sesión cuenta el tiempo y envía acciones normales (LINEAMIENTOS §5). Dónde vive el plazo es del Lead Programmer.

**Qué he visto:** el código actual (`reaction_prompt.gd`, `table_prompts.gd`, `strings.gd`, `reactions.gd`, `local_session.gd`): hoy existe un plazo de reacción (`reaction.deadline_ms`, al vencer se envía `PASS_REACTION`), una hoja inferior "Hechizo entrante" con barra sin cifras, `Strings.AGAINST_YOU`, y prompts del motor con sus textos. No he ejecutado el juego.

**Reglas que se conservan del motor** (ambigüedades ya cerradas): la ventana de reacción solo espera a quien **puede responder** (incluye maná que podría conseguir bebiendo; `docs/AMBIGUEDADES.md`, T6b); la preferencia "Avisarme de reacciones" auto-pasa por el jugador los hechizos que no le afectan; un ataque contra mí siempre me avisa.

---

## 1. Vocabulario y textos fijos

Los nombres de carta van en inglés (como `Strings.card_name`); los de magos son los de la partida. `{M}` = mago, `{C}` = carta, `{N}` = número.

### 1.1 Etiquetas de resultado (sobre el panel del mago afectado, ≥ 1 s, forma + texto, no solo color)
| Etiqueta | Cuándo | Forma / icono |
|---|---|---|
| `IMPACTO −{N}` | el mago pierde {N} de vida (o de maná: `MANÁ −{N}`) | número flotante rojo + anillo expansivo |
| `BLOQUEADO` | el efecto se evitó por completo (Frozen Bunny, Magic Shield que cubre todo el daño, Campo de fuerza) | escudo |
| `REDUCIDO −{N}` | un escudo evitó parte del daño; {N} = lo que **sí** se perdió | escudo partido |
| `REFLEJADO` | el efecto pasó a otro mago (Mirror Shield, Lightning en respuesta). El mago que lo recibe muestra además su propia etiqueta | flecha curva |
| `ANULADO` | Annihilation descartó el hechizo en curso (o la carta destruida) | círculo tachado |
| `SIN EFECTO` | el hechizo se resolvió pero no cambió nada (objetivo inmune, ya eliminado, daño 0, estado que ya tenía) | círculo vacío |
| `CURADO +{N}` | gana vida | cruz verde |
| `MANÁ +{N}` | gana maná | gota azul |
| `ELIMINADO` | el mago llega a 0 de vida o por Too Much Mana | lápida |

Regla: la etiqueta se **deduce de las entradas del log/`state_changed`** ya resueltas, no se predice (misma restricción que LINEAMIENTOS §4: sin predictor de daño). Si un hechizo produce varios resultados (área), hay una etiqueta por mago. Si un mago tiene dos etiquetas seguidas (p. ej. `REFLEJADO` y luego `IMPACTO −3` en otro), se apilan por orden de resolución.

### 1.2 Banners y avisos
| Id | Texto exacto | Cuándo |
|---|---|---|
| B-TURNO | `Tu turno` | inicio de mi turno (A0) |
| B-TURNO-BOT | `Turno de {M}` | turno de un bot |
| B-ATAQUE | `¡{M} te ataca!` + línea `{M} lanza {C}` | D0, hechizo ofensivo cuyo objetivo soy yo |
| B-ATAQUE-AREA | `¡{M} lanza {C}!` + línea `Te afecta a ti y a {K} más` | hechizo de área que me incluye (K = otros afectados; si K = 0 se usa B-ATAQUE) |
| B-PUEDES | `{M} lanza {C} contra {M2}` + línea `Puedes responder` | preferencia "siempre" y el hechizo no va contra mí |
| B-RESPONDE | `{M} responde con {C}` | D2' cadena |
| B-BOT-RESPONDE | `{M} puede responder…` | A5 (espera a bots) |
| B-SIN-DEF | `No tienes defensas para este hechizo` | D1a |
| B-SIN-PAGO | `No puedes pagar ninguna defensa` | D1a con defensivas en mano pero sin forma de pagarlas (ni bebiendo) |
| B-TIEMPO-TURNO | `Se acabó el tiempo: pierdes el turno` | vence el turno (≥ 1 s) |
| B-TIEMPO-DEF | `Se acabó el tiempo: recibes el golpe` | vence la defensa de un hechizo (≥ 1 s) |
| B-TIEMPO-OPC | `Se acabó el tiempo: no se hizo nada` | vence un prompt opcional (≥ 1 s) |
| B-TIEMPO-AZAR | `Se acabó el tiempo: se descartó al azar` | vence un descarte forzado (≥ 1 s) |
| B-AVISO-10 | `Te quedan 10 s` | turno, a los 10 s (toast ≤ 1 s, no bloquea) |
| B-AVISO-5 | `Te quedan 5 s` (turno) / `Te quedan 5 s para defenderte` (defensa) | a los 5 s |
| B-PAUSA | `Tiempo en pausa` | ver §4.3 |
| B-ELIMINADO | `Has sido eliminado` | ya existe |

Registro (línea nueva, `Strings`): `Se acabó el tiempo de {M}: pierde el turno.`, `Se acabó el tiempo de {M}: no se defiende.`, `Se acabó el tiempo de {M}: no usa {C}.` (prompt opcional rechazado), `Se acabó el tiempo de {M}: descarta {C} al azar.`

### 1.3 Botones (jerarquía de LINEAMIENTOS §2.5; icono + texto)
`Lanzar` (principal), `Cancelar`, `Elige objetivo` (principal deshabilitado con motivo; ver §2), `Terminar turno`, `Defender` (principal), `Recibir el golpe` (secundario grande, sustituye a `Pasar` en la hoja de defensa; el botón conserva la acción `PASS_REACTION`), `Beber poción`, `Confirmar`. En prompts opcionales se mantienen los botones actuales de `Strings` (`Usar Magic Cap`/`No usar`, `Comprar vida`/`No comprar`, `Perder N de vida`).

---

## 2. Ataque (mi turno): A0-A6

Estado de interfaz de turno: `SIN_CARTA` → `CARTA_ELEGIDA` → (`APUNTANDO`) → (`PAGANDO`) → `LISTO` → `ENVIADO` (en proceso) → `ESPERANDO_BOTS` → resultado → `SIN_CARTA`. Una sola carta elegida a la vez.

### A0 Inicio de turno
- **Ve:** banner B-TURNO (≤ 600 ms), mi panel en oro, mano activa (jugables con marco brillante; no jugables atenuadas, con el motivo al tocarlas: textos `Strings.REASON_*` actuales). Dock: `Intercambiar`, `Descartar`, `Beber poción` (si es legal), `Terminar turno` (secundario; pasa a principal si no queda nada jugable).
- **Toca:** una carta (A1) o un botón del dock.
- **Reloj:** el temporizador de turno arranca **al terminar el banner** (30 s por defecto). Si los robos/animaciones de inicio duran, el reloj aún no corre.
- Si estoy congelado o el motor salta mi turno: no hay A0 ni reloj; solo `Turno de {M}` del siguiente.

### A1 Elegir carta
- **Toca:** una carta de la mano. Tocar otra cambia la elegida (sin pasar por Cancelar). Tocar la misma la deselecciona.
- **Ve:** carta elevada; ficha en el centro con nombre, coste efectivo (con modificadores) y resumen en español (`data/card_summaries_es.json`). Dock: `Cancelar` + (`Lanzar` si no necesita objetivo ni pago | `Elige objetivo` si necesita objetivo). Se ocultan `Intercambiar`/`Descartar`/`Terminar turno` mientras hay carta elegida (vuelven al cancelar).
- La carta no jugable no se elige: muestra el motivo ("No tienes maná suficiente", "Estás cegado: no puedes lanzar ofensivas este turno.", etc.).
- **Toques:** 1.

### A2 Apuntar (solo cartas con objetivo de un mago)
- **Ve:** rivales **válidos** (los de `legal_actions` para esa carta) con contorno lavanda pulsante y sigilo iluminado, también como fichas en el dock (sigilo + nombre + vida); **inválidos** atenuados al 45 %; al tocar un inválido, el motivo en una línea: `{M} tiene Campo de fuerza`, `{M} está eliminado`, `No puedes elegirte a ti mismo` (según la carta). Texto guía: `Elige a quién lanzar {C}.` (hoy `Strings.prompt_choose_targets`).
- **Toca:** un rival válido (panel o ficha). Queda **elegido**: círculo rúnico girando en su panel + marca de puntería + ✓ en su ficha. Tocar otro válido cambia el elegido; tocar el elegido no lo quita (`Cancelar` sale de apuntar).
- **Un solo válido:** viene **preseleccionado** y A2 y A3 se muestran juntos (ya está marcado; no hace falta tocarlo). Si no hay ninguno válido, la carta ya estaba atenuada con motivo y no se llega aquí.
- **Cartas de "todos" o "vecinos"** (Meteor Shower, Blizzard, Ice Boomerang, etc.): sin paso de apuntar; se resaltan todos los afectados nominales en el fotograma de A1 y se ven en la vista previa. Si algún afectado es inmune o está protegido, sigue resaltado pero con la marca `SIN EFECTO` anticipada solo cuando el motivo es visible en el estado (Campo de fuerza activo): se indica en la vista previa (ver A3), no se calcula nada más.
- **Toques:** 2 en total hasta aquí (carta, objetivo); 1 si objetivo único preseleccionado.

### A3 Vista previa
- **Ve (dock, una a tres líneas):** `{C} → {M}: {efecto nominal} (si nadie responde).` y `Coste: {N} de maná.` Ejemplos exactos:
  - `Fire Arrow → Bruno: pierde 1 de vida (si nadie responde). Coste: 1 de maná.`
  - `Fireball → Bruno: pierde 3 de vida (si nadie responde). Coste: 3 de maná.`
  - `Meteor Shower → Bruno, Cira y Dario: pierden 2 de vida cada uno (si nadie responde). Coste: 4 de maná.`
  - Con escudo visible: `Fire Arrow → Bruno: tiene Campo de fuerza, no le afectará.` (única vez que se avisa de un modificador; no se calcula nada más).
  - Con coste en cartas: `Coste: 2 de maná y descartar 1 carta de hielo.` y se encadena el paso **PAGANDO** de v0.2 (elegir las cartas, `Confirmar`).
- La frase de efecto nominal sale de una **tabla por `card_id`** en `Strings` con test de cobertura de las 58 cartas jugables (igual que `ReactionRelevance`); el texto de cada carta lo redacta el Narrative Designer. Si una carta no tiene entrada, el test falla (no se inventa texto). Reglas de redacción: siempre "nominal" + "(si nadie responde)"; nunca cifras que dependan de modificadores del estado salvo coste efectivo y las del párrafo anterior.
- El botón principal pasa a `Lanzar` (habilitado).
- **Toques:** 3 máximo (carta, objetivo, Lanzar).

### A4 Lanzar
- **Toca:** `Lanzar`. El botón pasa a "en proceso" y no admite segundo toque. Se envía `PLAY_CARD` con el objetivo **elegido** (no hay valor por defecto distinto del preseleccionado único).
- **Ve:** la carta vuela al centro (250 ms), círculo rúnico en mi panel, proyectil del elemento hacia el objetivo (300-400 ms). Animaciones: LINEAMIENTOS §6.
- Si el motor rechaza la acción (error legal): el botón vuelve a normal y aparece `No se pudo lanzar: {motivo}` (motivo en español de `Strings`); la carta sigue elegida. El jugador nunca ve "en proceso" indefinidamente: tope de 2 s y entonces vuelve a normal con el aviso.

### A5 Respuestas
- Si ningún bot puede responder: se salta A5.
- Si alguno puede: banner B-BOT-RESPONDE, reloj de arena en su panel, **mi temporizador de turno en pausa** (§4.3), botones de acción en "en proceso". Si el bot responde, se ve su carta y se pasa a A6 de la cadena (la resolución final es en orden inverso: el efecto de la última respuesta se ve primero; cada paso lleva su etiqueta).
- Si la respuesta de un bot pasa a **afectarme** (Lightning que me redirige, p. ej.), se abre D0/D1b de §3 **dentro de mi turno**; ahí manda el temporizador de defensa y el de turno sigue en pausa.

### A6 Resultado
- **Ve:** impacto en el objetivo + etiqueta (§1.1) ≥ 1 s + línea del registro. Una etiqueta por mago afectado. La vista vuelve a `SIN_CARTA` (A1) con el temporizador de turno **reanudado** donde quedó.
- **Garantía:** todo lanzamiento termina en al menos una etiqueta visible; si el efecto fue una carta sin daño (artefacto, evento, curación, robo) la etiqueta es la que corresponda (`CURADO +N`, `MANÁ +N`) o, si no cambia nada visible, `SIN EFECTO` sobre el objetivo/lanzador. Un artefacto/evento no lleva etiqueta sobre un mago: aparece con su aro rúnico en la zona central y la línea del registro (A6 se cumple con eso).
- Si mi acción me elimina (daño propio, Too Much Mana): `ELIMINADO` y paso a modo espectador (LINEAMIENTOS §3.2).

### Fin de turno
- **Toca** `Terminar turno` (1 toque, sin confirmación) **o vence el tiempo** (§5). Transición a `Turno de {M}`.
- Terminar turno con jugadas disponibles no pide confirmación (decisión de v0.2); si hay prompts propios pendientes no se puede terminar (motivo `REASON_PROMPT_PENDING`).

---

## 3. Defensa: D0-D3

Una "ventana de defensa" es una vez que soy el siguiente en `awaiting` de la reacción (`Decision.responder(view) == yo`). Una cadena puede abrir varias ventanas seguidas para mí; cada una es una ronda.

### D0 Aviso
- **Ve:** banner carmesí B-ATAQUE (o B-ATAQUE-AREA, o B-PUEDES en el caso "siempre" cuando no va contra mí; este último en estilo plata, sin carmesí). Entrada ≤ 400 ms; se queda en la franja superior mientras dura la ventana. Borde carmesí en el panel del atacante, línea del atacante a mi panel, la carta del hechizo grande con su resumen en español.
- **Es parte de la cola de presentación:** una acción de bot posterior no adelanta al aviso.
- Se anuncia siempre con el nombre del atacante y la carta, en español: `¡Bruno te ataca!` / `Bruno lanza Fireball`.

### D1a Sin respuestas posibles (no hay ventana, no hay reloj)
- Cuando `awaiting` no me incluye (no tengo defensivas/Lightning legales, ni pagables ni bebiendo): no hay hoja ni temporizador. Se muestra D0 con la línea B-SIN-DEF (o B-SIN-PAGO si tengo defensivas en mano pero no puedo pagarlas), ≥ 1 s, y luego D3 con la etiqueta. No hay botones.
- Con la preferencia "solo si me afecta" y el hechizo ajeno a mí: no hay aviso, ni siquiera D0 (se ve solo la animación normal y el registro).

### D1b Fase de defensa
- **Ve (hoja inferior "Defiéndete", cubre Z6-Z7; mi vida y maná siguen a la vista fuera de la hoja):**
  1. Cabecera: `Defiéndete` + temporizador de defensa (plata, anillo segmentado con cifras; ver §4).
  2. Línea del hechizo: `{M} lanza {C}` (+ `Contra ti` / `No va contra ti`, existentes).
  3. **Consecuencia de no hacer nada**, una línea con la plantilla que corresponda al efecto nominal:
     - daño: `Si recibes el golpe: pierdes {N} de vida.`
     - maná: `Si recibes el golpe: pierdes {N} de maná.`
     - daño y robo/descarte: `Si recibes el golpe: pierdes {N} de vida y descartas {K} carta(s).`
     - estado: `Si recibes el golpe: quedas {congelado|cegado|…}.`
     - área: `Si recibes el golpe: este hechizo afecta a {K} magos, tú incluido.`
     - sin dato en la tabla: `Si recibes el golpe: se aplica su efecto.` (no se inventa)
     (Misma tabla nominal por `card_id` que A3; "nominal" = sin modificadores salvo los visibles; en la hoja se añade `(puede cambiar si hay respuestas)` si hay cadena.)
  4. Mi **vida y maná**: `Tu vida: {V} · Tu maná: {M}` (ya existe).
  5. **Respuestas posibles** como cartas grandes con su efecto en una línea y su coste:
     - `Magic Shield: evita 2 de daño de hechizo · 2 de maná`
     - `Frozen Bunny: evita todo el daño de un hechizo · descartar 1 carta de hielo`
     - `Mirror Shield: redirige hasta 2 de daño a otro mago · 2 de maná y descartar 1 defensiva`
     - `Lightning: +1 de daño y lo devuelves a otro mago · 2 de maná` (solo si el hechizo es Lightning)
     - `Annihilation: descarta una carta en juego, incluso este hechizo · 4 de maná y descartar 1 carta de fuego`
     - `Last Wish: si este hechizo te mata, el atacante recibe el mismo daño · 3 de maná`
     - `Magic Capture: robas la carta de arriba del descarte · 1 de maná y descartar 1 defensiva`
     Los textos salen del resumen en español existente; Narrative ajusta redacción.
  6. Las que no puedo pagar: atenuadas con el motivo en una línea (`Te falta 1 de maná: bebe una poción` si beber lo arregla; `No tienes una carta de hielo para pagar` si no hay forma). No son tocables, pero el toque muestra el motivo.
  7. Botones: `Defender` (principal; deshabilitado mientras no haya respuesta seleccionada completa), `Recibir el golpe` (secundario grande), `Beber poción` (si es legal, separado ≥ 24 px).
- El temporizador arranca cuando la hoja es **visible** (tras la entrada).
- **Solo una respuesta posible:** viene **preseleccionada** (marco dorado, ✓), pero **no se envía sola**: hay que tocar `Defender`. (E11: si vence el tiempo, no se defiende aunque estuviera preseleccionada.)
- Cartas de una "defensa" en mano que son defensivas pero no responden a este hechizo (p. ej. Magic Capture siempre se puede jugar en reacción): se listan igual si son legales.

### D2 Elegir
- **Toca:** una respuesta (queda seleccionada; tocar otra la cambia; tocar la misma la deselecciona) y luego `Defender` → **2 toques**. O `Recibir el golpe` → **1 toque**. Si la respuesta necesita decisiones extra (Mirror Shield: a quién redirigir y qué defensiva descartar; Lightning: a quién devolver; Annihilation: qué carta destruir; cualquier pago en cartas), se añaden **sus** toques; `Defender` se habilita al completar. Preselecciones por defecto: Annihilation preselecciona el hechizo en curso (primera opción de la lista); si hay un solo objetivo/carta válida, también va preseleccionada. Nunca se preselecciona un destino de Mirror Shield o Lightning cuando hay más de uno (el jugador elige a quién perjudica).
- Al tocar `Defender`: botón "en proceso", sin segundo toque; se envía `REACT` con los datos elegidos.
- `Beber poción` en la hoja no cierra la hoja ni reinicia el temporizador: actualiza maná y habilita las respuestas que ahora se pagan (quedan en su sitio, sin preselección nueva).
- **Respuesta que deja de ser legal** (otro mago cambió el estado mientras tanto; en esta versión solo puede pasar al abrirse una ronda nueva): la selección se limpia y se informa `{C} ya no se puede usar`.

### D2' Cadena
- Si el atacante (u otro) responde mientras yo tenía la ventana, o si tras mi respuesta alguien responde y vuelvo a estar en `awaiting`: banner B-RESPONDE, la hoja se **reconstruye** con el hechizo en foco (el último de la pila), consecuencia actualizada y **nuevo temporizador de defensa completo**. Se anuncia: `Nueva ronda: tienes {T} s` (≥ 800 ms). Es el único caso en que el plazo de defensa vuelve a empezar.
- Si quien responde es otro bot sin que yo vuelva a estar en `awaiting`: no hay hoja; se ve D0-like con B-RESPONDE y se pasa a D3.

### D3 Resultado
- **Ve:** efecto de escudo o impacto sobre mi panel y la etiqueta de §1.1; línea del registro; la hoja se cierra al empezar la presentación del resultado. Duración mínima de la etiqueta 1 s, en paralelo (no bloquea la cola más de 300 ms).
- Casos: me llegó daño completo → `IMPACTO −N`; el escudo cubrió todo → `BLOQUEADO`; cubrió parte → `REDUCIDO −N` (N = pérdida final); redirigí a otro → `REFLEJADO` sobre mí y la etiqueta correspondiente sobre el nuevo objetivo; anulé el hechizo → `ANULADO` sobre la carta/hechizo y `SIN EFECTO` no se añade; el hechizo no me afectaba → solo la etiqueta del afectado.

---

## 4. Temporizadores

### 4.1 Valores y opciones
| | Turno de ataque | Fase de defensa |
|---|---|---|
| Por defecto | **30 s por turno completo** | **20 s por ventana** (ronda) |
| Opciones | 15 s · 20 s · **30 s** · 45 s · 60 s · **Sin límite** | 10 s · 15 s · **20 s** · 30 s · **Sin límite** |
| Dónde se elige | pantalla de nueva partida, bloque "Tiempo", junto al límite de pociones; selector de una fila con las opciones en botones (≥ 96 px). Se recuerda para la siguiente partida | igual |
| Etiquetas del selector | `Tiempo de turno`, `Tiempo de defensa`; las opciones se escriben `30 s`, `Sin límite` | |
| Guardado | `user://settings.cfg`, claves a decidir por el Lead Programmer; valor 0 o ausente = `Sin límite` solo si se eligió explícitamente; ausente = defecto 30/20 | |

Cambiar el valor en la pantalla de nueva partida afecta a la partida siguiente (no hay cambio en mitad de partida). Los bots no tienen plazo en ningún caso. "Sin límite" oculta el reloj y las barras y muestra en su lugar la etiqueta `Sin límite` (texto pequeño, mismo sitio) para que no parezca un fallo.

### 4.2 Aspecto y diferencia entre los dos
| | Turno | Defensa |
|---|---|---|
| Color | oro (`COL_ACCENT`) | plata-acero con brillo azul (LINEAMIENTOS §2.2) |
| Forma | barra horizontal bajo el banner de Z1, que se vacía de derecha a izquierda | anillo segmentado en la cabecera de la hoja |
| Icono | reloj de arena | escudo |
| Cifras | `0:24` (minutos:segundos, cifras de ancho fijo), a la derecha de la barra | cifras grandes al centro del anillo (`18`), sin minutos |
| Etiqueta | `Tu turno` | `Defiéndete` |
| Posición | arriba (Z1) | en la hoja inferior (Z6-Z7) |
| Redundancia | el borde de `Terminar turno` se vacía con él | el borde de `Recibir el golpe` se vacía con él |

Debe distinguirse por forma, icono, posición y texto, no solo por color (R7 y LINEAMIENTOS §2.2).

### 4.3 Cuándo corre, pausa y reanudación
Turno (corre mientras **yo puedo actuar** en mi turno):
- Arranca al terminar el banner A0. **No se reinicia** con cada acción, carta o prompt propio: son 30 s en total.
- **Pausa** (icono ⏸ en vez del reloj de arena + `Tiempo en pausa`; la barra se queda congelada): (a) mientras se espera a bots (A5 y la presentación de la resolución de mi hechizo, incluida la cola de animaciones); (b) con el menú de partida abierto; (c) mientras se muestra una ventana de defensa mía abierta dentro de mi turno (corre el de defensa); (d) durante los avisos/banners bloqueantes de la cola de presentación (B-TIEMPO-*, cambio de turno).
- **Corre** mientras estoy viendo la ficha, la lupa o el registro (son míos).
- Reanuda con el tiempo que quedaba. Si al pausar quedaban < 1 s, al reanudar se garantiza ≥ 1 s (para no perder el turno por la animación del propio hechizo).
- Un prompt propio de mi turno (maná insuficiente, descarte, elegir objetivos) **usa el temporizador de turno** (sigue corriendo).

Defensa:
- Arranca cuando la hoja es visible; corre hasta que envío `Defender`/`Recibir el golpe`. No se pausa con el zoom ni con el registro (la amenaza no espera). **Solo se pausa con el menú de partida abierto**, porque abrirlo es una decisión consciente (decisión de diseño; vale también para el reloj de turno).
- Cada ronda de la cadena arranca un plazo completo, anunciado.
- Los prompts del motor causados por un rival y que surgen fuera de mi turno (maná insuficiente por Not Enough Mana, Visit of the Archmage, Magic Cap, Mana Focus, Elixir, descarte forzado de Icy Grasp, etc.) **usan el temporizador de defensa**, con la misma hoja. Si surgen dentro de mi turno por mi propia carta, usan el de turno.

### 4.4 Avisos
| | 10 s | 5 s | 0 s |
|---|---|---|---|
| Turno | barra y cifras en ámbar + pulso lento (1 Hz) + toast `Te quedan 10 s` | carmesí + pulso rápido (2 Hz) + icono ⚠ junto a la cifra + toast `Te quedan 5 s` | B-TIEMPO-TURNO |
| Defensa | — (no hay aviso a 10 s; si el plazo configurado ≤ 10 s no hay aviso previo salvo el de 5) | carmesí + pulso rápido + ⚠ + toast `Te quedan 5 s para defenderte` | B-TIEMPO-DEF |

Ningún aviso solo por color: pulso e icono ⚠ también. Con "Reducir animaciones": sin pulso, cambio de color + ⚠ + toast. Si el plazo total es ≤ 5 s (no se ofrece por defecto) solo vale el aviso de 5 s.

### 4.5 Medida del tiempo
- Reloj monótono (M3), tests con reloj inyectado. Las cifras se muestran redondeando hacia arriba (0:24 mientras queden 23,1 s); `0:00` solo en el fotograma del vencimiento.
- Si el tiempo vence en el mismo instante que un toque: gana lo que la sesión procesó antes; los toques recibidos después del vencimiento se descartan y, si el vencimiento fue de turno, se muestra B-TIEMPO-TURNO.

---

## 5. Qué ocurre al vencer cada decisión (E11, E15, E16)

Principio (usuario, E11): **al vencer no se elige nada por el jugador.** Lo no resuelto se rechaza; lo obligatorio se aplica igual; solo cuando el motor exige elegir (no existe opción de no hacer nada) se usa el azar con el RNG **del estado** (determinista y reproducible; E15, pendiente de confirmar). Esto sustituye lo que dice LINEAMIENTOS §5 ("valor por defecto", "como un bot") (E16).

| # | Decisión pendiente | Reloj | Al vencer |
|---|---|---|---|
| T1 | Mi turno, sin nada a medias | Turno | `END_TURN`. B-TIEMPO-TURNO. Pasa al siguiente mago |
| T2 | Mi turno con carta elegida/objetivo/pago sin confirmar | Turno | La UI descarta el borrador (carta, objetivo, pago): **no se juega**. Luego T1 |
| T3 | Mi turno con la ventana de defensa abierta (dentro de mi turno) | Defensa (el de turno en pausa) | Se resuelve como T6 (recibes el golpe). Después se reanuda el turno con el tiempo restante |
| T4 | Mi turno, esperando respuestas de bots | Turno en pausa | No vence (pausa) |
| T5 | Mi turno con un prompt propio opcional (maná insuficiente, Magic Cap, Mana Focus, Elixir, Visit of the Archmage) | Turno | `DECLINE` del prompt (ver T8-T12) y luego T1 |
| T6 | Defensa de un hechizo (`awaiting` me incluye) | Defensa | `PASS_REACTION`: no se defiende, aunque hubiera respuesta preseleccionada o a medias. B-TIEMPO-DEF. Se resuelve D3 |
| T7 | Defensa en cadena (ronda n) | Defensa | `PASS_REACTION` de esa ronda; el plazo de la siguiente ronda (si la hay) es nuevo |
| T8 | Prompt `mana_shortfall` | Defensa (rival) / Turno (mío) | `DECLINE`: pierde esa vida (efecto obligatorio aplicado igual; puede eliminar). B-TIEMPO-OPC |
| T9 | `drink_or_suffer` (Visit of the Archmage) | ídem | `DECLINE`: pierde la vida indicada |
| T10 | `use_magic_cap` | ídem | `DECLINE`: no usa Magic Cap; se aplica la pérdida |
| T11 | `mana_focus` | ídem | `DECLINE`: gasta 0 de maná; recibe el daño completo |
| T12 | `elixir_transmutation` | ídem | `DECLINE`: no compra vida |
| T13 | `discard` forzado (Icy Grasp, límite de mano, etc.) | ídem | Descarte **al azar** de `count` cartas de mi mano con el RNG del estado. B-TIEMPO-AZAR. Pendiente de confirmar por el usuario (E15) |
| T14 | `choose_targets` (elegir magos; solo cuando el motor no deja rechazar) | ídem | Al azar entre los permitidos con el RNG del estado; extensión de E15, pendiente de confirmar |
| T15 | `choose_card` (Magic Hand, elegir carta) | ídem | Al azar entre las elegibles, mismo RNG; extensión de E15, pendiente |
| T16 | Varios prompts pendientes a la vez (cola FIFO) | el del primero | Cada uno vence **por separado**, con su propio plazo completo desde que se hace visible; no se resuelven todos a la vez |
| T17 | Eliminado / espectador | — | No hay reloj |

Notas:
- Los T8-T15 también son los valores si el jugador ausente "nunca actúa" (50 partidas de QA).
- La sesión envía las acciones en este orden al vencer el turno: (1) cierra el borrador de interfaz, (2) resuelve prompts pendientes según T5/T8-T15, (3) `END_TURN`, (4) si `END_TURN` provoca un prompt obligatorio mío (p. ej. descarte por límite de mano), T13. Cada paso se registra.
- Beber poción **nunca** se hace por el jugador al vencer: el único modo en que perdería vida por maná insuficiente sin beber es T8, que es la regla ("no se elige nada").
- Registro: una línea por vencimiento (§1.2). El vencimiento es público (todos lo ven).

---

## 6. Casos raros

1. **Lightning encadenado.** Bruno lanza Lightning contra mí; respondo con Lightning contra Cira (+1 de daño, 3 en total). D2: tocar mi Lightning exige elegir el nuevo objetivo (no preseleccionado si hay más de uno); `Defender` se habilita al elegirlo. D3: sobre mí `REFLEJADO`; sobre Cira `IMPACTO −3` (si nadie responde). Si Cira puede responder, abre su ventana: B-RESPONDE y D1b con `Cira` humano (si Cira es un bot, no hay reloj). Si yo soy Cira en esa segunda ronda: nueva ventana, nuevo plazo de 20 s, anunciado.
2. **Lightning en mi turno.** Lanzo Lightning contra Bruno; Bruno responde con Lightning contra mí. A5 pasa a D0-D1b dentro de mi turno; el temporizador de turno está en pausa; el de defensa corre. Al terminar la cadena, el turno reanuda con el tiempo que quedaba.
3. **Annihilation.** Lista de cartas en juego destruibles: el hechizo en curso aparece primero (preseleccionado), luego artefactos, maldiciones y eventos (nombre y propietario). Si destruyo el hechizo: `ANULADO` sobre el hechizo (se ve la carta rota) y ninguno de los magos recibe `IMPACTO`; si destruyo otra carta, el hechizo se resuelve y su etiqueta aparece normal. Annihilation exige descartar una carta de fuego: el paso de pago se encadena. Si el hechizo en curso ya fue anulado por una respuesta anterior: no se ofrece como objetivo.
4. **Mirror Shield.** Pide dos cosas: a quién redirigir (cualquier mago vivo; el atacante también) y la defensiva a descartar. Redirección "hasta 2": si el daño nominal era 1, se redirige 1. Etiquetas: yo `REFLEJADO` (y `REDUCIDO −N` si me quedó daño), el nuevo objetivo `IMPACTO −N`. Si el nuevo objetivo es inmune (Campo de fuerza): `SIN EFECTO` en él y yo `REFLEJADO`. El toque de redirección se hace sobre los paneles/fichas con el mismo patrón de A2.
5. **Hechizos de área** (Meteor Shower, Blizzard, Ice Boomerang…). Una sola ventana por hechizo y por mago que pueda responder, en el orden de `awaiting`. D1b dice `este hechizo afecta a K magos, tú incluido`. Mi respuesta protege solo a quien la carta diga (Magic Shield: un mago; el elegido); los demás conservan su etiqueta propia. Resultado: una etiqueta por afectado.
6. **Objetivo inmune** (Campo de fuerza): en A2 aparece atenuado con motivo; en área se ve en la vista previa con una línea `Bruno tiene Campo de fuerza: sin efecto`. Si el efecto se resuelve igual: `SIN EFECTO` sobre su panel (≥ 1 s). Campo de fuerza no bloquea defensivas, así que no cambia mi ventana de defensa.
7. **Objetivo eliminado antes de resolver** (p. ej. murió por una respuesta): se omite su etiqueta de daño y el hechizo muestra `SIN EFECTO` sobre su lápida (≥ 1 s); el registro lo cuenta.
8. **Sin defensas jugables** (ninguna defensiva o ninguna pagable ni bebiendo): D1a, sin hoja ni reloj. Con defensivas en mano pero sin forma de pagar: B-SIN-PAGO. No hay temporizador y el flujo sigue a D3.
9. **Sin maná para defender pero con pociones:** la ventana se abre (el motor cuenta el maná bebible). Las respuestas salen atenuadas con `Te falta {N} de maná: bebe una poción`; `Beber poción` se resalta con riesgo visible (⚠ y color, como hoy). Beber no reinicia ni detiene el reloj. Si bebo y alcanzo para pagar, la respuesta se habilita y se puede elegir. Si el plazo vence antes de beber o de defender: T6 (recibes el golpe).
10. **Ataque que me elimina:** D3 muestra `IMPACTO −N` y `ELIMINADO` ≥ 1 s antes de pasar a espectador. Last Wish (si lo jugué) muestra `REFLEJADO` en el atacante con su propio `IMPACTO −N`; yo quedo `ELIMINADO` igualmente.
11. **Dos hechizos seguidos de bots antes de mi ventana:** cada uno tiene su banner; no se acumulan más de 1,5 s de cola (contrapresión LINEAMIENTOS §6.2). El reloj de defensa arranca con la hoja visible del hechizo que me pide, nunca mientras se reproduce el anterior.
12. **Preferencia "siempre":** hechizo entre dos bots con respuesta mía posible → B-PUEDES, hoja `Puedes responder` en plata, sin consecuencia para mí (`No va contra ti`); si vence: pasa (T6) sin etiqueta propia.
13. **Menú abierto:** pausa los dos relojes; al cerrar, reanuda. En "Sin límite" no hay efecto.
14. **Pantalla de fin / eliminado:** los relojes se detienen y se ocultan.
15. **Congelado/saltado:** mi turno saltado no tiene reloj ni banner de ataque; sí puede haber defensa.
16. **Fin de partida durante un reloj:** se cancela sin acciones.

---

## 7. Criterios de aceptación (para QA)

Los tests usan reloj inyectado, sin esperas reales. "Humano" = el único jugador humano; bots = sin plazo.

### Ataque
- **CA-AT-01** Dado el inicio de mi turno, cuando termina B-TURNO, entonces el temporizador de turno vale el configurado (30 s por defecto) y no corre antes.
- **CA-AT-02** Dado `SIN_CARTA`, cuando elijo una carta jugable, entonces se ve la ficha, el dock muestra solo `Cancelar` y (`Lanzar` o `Elige objetivo`), y no se ven `Intercambiar`, `Descartar` ni `Terminar turno`.
- **CA-AT-03** Dada una carta con objetivo de mago, cuando entro en apuntar, entonces los rivales resaltados son exactamente los de `legal_actions` para esa carta y todos los demás están al 45 % de opacidad con su motivo al tocarlos.
- **CA-AT-04** Dado un solo objetivo válido, cuando elijo la carta, entonces ya viene preseleccionado, `Lanzar` está habilitado y el hechizo se lanza en 2 toques.
- **CA-AT-05** Dados varios objetivos válidos, cuando elijo carta, objetivo y `Lanzar`, entonces son 3 toques y se envía `PLAY_CARD` con ese objetivo (y ningún otro).
- **CA-AT-06** Dado un objetivo elegido, cuando se muestra la vista previa, entonces contiene el nombre de la carta, el del objetivo, `(si nadie responde)` y `Coste: N de maná`; para las 58 cartas jugables existe frase nominal (test de cobertura).
- **CA-AT-07** Dada una carta de área, cuando la elijo, entonces no hay paso de apuntar y todos los afectados nominales están resaltados.
- **CA-AT-08** Dado `Lanzar` tocado, cuando se procesa, entonces el botón queda "en proceso", un segundo toque no envía otra acción y en ≤ 2 s vuelve a normal si el motor no responde.
- **CA-AT-09** Dado un lanzamiento con efecto sobre uno o más magos, cuando se resuelve, entonces hay una etiqueta de §1.1 por mago afectado, visible ≥ 1 s, y una línea de registro; ningún lanzamiento termina sin etiqueta (artefacto/evento: aro + registro).
- **CA-AT-10** Dado un hechizo mío al que un bot puede responder, cuando se espera, entonces se ve B-BOT-RESPONDE, el reloj de turno está en pausa (icono ⏸) y no avanza.
- **CA-AT-11** Dado el lanzamiento con pago en cartas, cuando se llega al paso de pago, entonces el flujo de v0.2 se mantiene y `Lanzar` solo ejecuta tras `Confirmar`.
- **CA-AT-12** Dado un objetivo inmune (Campo de fuerza), cuando lo toco en apuntar, entonces se muestra el motivo `{M} tiene Campo de fuerza` y no se elige.
- **CA-AT-13** Dado que la acción es rechazada por el motor, cuando vuelvo a A1, entonces se muestra `No se pudo lanzar: {motivo}` y la carta sigue elegida.

### Defensa
- **CA-DF-01** Dado un hechizo ofensivo contra mí, cuando empieza mi presentación, entonces el banner dice `¡{atacante} te ataca!` con el nombre de la carta y el panel del atacante tiene borde carmesí.
- **CA-DF-02** Dado un hechizo de área que me incluye, cuando aviso, entonces el banner es B-ATAQUE-AREA con el número correcto de otros afectados.
- **CA-DF-03** Dado que no estoy en `awaiting`, cuando me atacan, entonces no se abre hoja ni temporizador, se ve B-SIN-DEF (o B-SIN-PAGO si tengo defensivas sin pago posible) ≥ 1 s y luego la etiqueta de resultado.
- **CA-DF-04** Dado que estoy en `awaiting`, cuando la hoja es visible, entonces contiene: `Defiéndete`, temporizador de defensa, línea de consecuencia (`Si recibes el golpe: …`), vida y maná propios, las respuestas legales con efecto y coste en una línea, `Defender` y `Recibir el golpe`.
- **CA-DF-05** Dada una sola respuesta posible, cuando se abre la hoja, entonces está preseleccionada pero no se envía hasta tocar `Defender` (2 toques); y `Recibir el golpe` se envía con 1 toque.
- **CA-DF-06** Dada una respuesta no pagable, cuando se muestra, entonces está atenuada con el motivo y tocarla no la selecciona.
- **CA-DF-07** Dado maná insuficiente con poción bebible, cuando bebo, entonces el temporizador no se reinicia ni se detiene y la respuesta pasa a ser seleccionable.
- **CA-DF-08** Dado `Defender` tocado, cuando se envía `REACT`, entonces el botón queda en proceso y no admite segundo toque.
- **CA-DF-09** Dada una cadena (el atacante responde y vuelvo a estar en `awaiting`), cuando se abre la nueva ronda, entonces hay banner B-RESPONDE, consecuencia actualizada y un temporizador completo nuevo; en ninguna otra circunstancia se reinicia el temporizador de defensa.
- **CA-DF-10** Dado un bloqueo total (Frozen Bunny), un bloqueo parcial (Magic Shield sobre daño 3), un impacto sin defensa y una redirección (Mirror Shield o Lightning), cuando se resuelven, entonces las etiquetas son `BLOQUEADO`, `REDUCIDO −1`, `IMPACTO −N` y `REFLEJADO` (más la del nuevo objetivo) respectivamente.
- **CA-DF-11** Dado Annihilation sobre el hechizo en curso, cuando se resuelve, entonces aparece `ANULADO`, nadie recibe `IMPACTO` por ese hechizo y el hechizo estaba preseleccionado en la lista.
- **CA-DF-12** Dado Mirror Shield, cuando lo selecciono, entonces `Defender` no se habilita hasta elegir destino y la defensiva a descartar.
- **CA-DF-13** Dado un hechizo ajeno con preferencia "solo si me afecta", cuando se lanza, entonces no hay aviso ni hoja y se auto-pasa sin plazo.
- **CA-DF-14** Dado un hechizo ajeno con preferencia "siempre" y respuesta mía posible, cuando se abre, entonces se muestra B-PUEDES en estilo plata (no carmesí) y la consecuencia no habla de mí.
- **CA-DF-15** Dado el hechizo que me elimina, cuando se resuelve, entonces se ven `IMPACTO −N` y `ELIMINADO` ≥ 1 s antes de pasar a espectador.
- **CA-DF-16** Dado un objetivo eliminado antes de resolver, cuando se resuelve, entonces no hay `IMPACTO` sobre él, sí `SIN EFECTO` ≥ 1 s.

### Temporizadores
- **CA-TM-01** Dada una partida nueva sin cambios, cuando empieza, entonces turno = 30 s y defensa = 20 s; el selector ofrece exactamente 15/20/30/45/60/Sin límite y 10/15/20/30/Sin límite y el valor elegido persiste en la partida siguiente.
- **CA-TM-02** Dado "Sin límite" en turno, cuando juego, entonces no hay barra ni cifras, se ve `Sin límite` y jamás se envía `END_TURN` por tiempo; idem para defensa.
- **CA-TM-03** Dados 30 s, cuando juego varias cartas sin terminar, entonces el reloj no se reinicia (a los 30 s totales de tiempo corrido, sin contar pausas, vence).
- **CA-TM-04** Dada la pausa (espera de bots, menú abierto, banners bloqueantes), cuando pasan 10 s de reloj, entonces el tiempo restante no cambia; al reanudar continúa con lo que quedaba y, si quedaba < 1 s, con al menos 1 s.
- **CA-TM-05** Dados turno y defensa, entonces se distinguen por forma (barra vs anillo), icono (reloj de arena vs escudo), color (oro vs plata), etiqueta y posición (comprobable en el árbol de nodos y capturas).
- **CA-TM-06** Dado turno en los últimos 10 s, entonces cambia a ámbar con pulso y toast `Te quedan 10 s`; en 5 s, a carmesí con ⚠ y toast `Te quedan 5 s`; en defensa, solo el de 5 s con `Te quedan 5 s para defenderte`.
- **CA-TM-07** Dadas cifras mostradas, entonces usan redondeo hacia arriba en formato `m:ss` en turno; nunca muestran `0:00` antes del vencimiento.
- **CA-TM-08** Dados los bots, entonces ningún bot tiene reloj ni se muestra reloj en su turno; sus acciones mantienen el retardo de 600-900 ms.
- **CA-TM-09** Dado el menú de partida abierto en defensa, entonces el reloj de defensa se pausa y al cerrar reanuda (decisión de §4.3).
- **CA-TM-10** Dado un toque posterior al vencimiento de turno, entonces se descarta y no se juega nada.

### Vencimientos (E11)
- **CA-VC-01** Turno vence sin nada a medias → se envía `END_TURN` una vez, B-TIEMPO-TURNO ≥ 1 s, línea de registro `Se acabó el tiempo de {M}: pierde el turno.` y empieza el turno del siguiente mago.
- **CA-VC-02** Turno vence con carta elegida / objetivo / pago sin confirmar → no se envía `PLAY_CARD`; el borrador desaparece; se pierde el turno.
- **CA-VC-03** Turno vence con un prompt opcional propio → se envía `DECLINE` primero y luego `END_TURN`; las pérdidas del DECLINE (T8-T12) se aplican.
- **CA-VC-04** Defensa vence (con o sin respuesta preseleccionada/incompleta) → se envía `PASS_REACTION`, B-TIEMPO-DEF ≥ 1 s, y se ve D3; nunca se envía `REACT`.
- **CA-VC-05** Cada prompt opcional (T8-T12) vence → `DECLINE` y el efecto del rechazo documentado; nunca `DRINK_POTION`/`USE_*`.
- **CA-VC-06** Descarte forzado vence → se descartan `count` cartas elegidas con el RNG del estado: con la misma semilla y estado se descartan siempre las mismas; es una mano válida y B-TIEMPO-AZAR se muestra (pendiente de confirmar E15).
- **CA-VC-07** `choose_targets` / `choose_card` obligatorios vencen → elección al azar entre las válidas con el RNG del estado, reproducible (pendiente de confirmar).
- **CA-VC-08** Varios prompts pendientes: cada uno recibe su propio plazo desde que se hace visible; vencer el primero no resuelve el segundo.
- **CA-VC-09** Dadas 50 partidas con un humano que nunca actúa, entonces las 50 terminan, 0 bloqueos y 0 violaciones del invariante; en ninguna se envía una acción de defensa o de poción por el humano.
- **CA-VC-10** Cadena de Lightning donde el humano está en `awaiting` dos veces → vence la primera ronda (`PASS_REACTION`), la segunda ronda recibe un plazo completo nuevo, y un solo vencimiento nunca resuelve dos rondas.
- **CA-VC-11** Ventana de defensa abierta dentro de mi turno vence → `PASS_REACTION`; el turno reanuda con el tiempo restante y no se pierde.
- **CA-VC-12** Fin de partida durante un reloj → no se envía ninguna acción por tiempo.

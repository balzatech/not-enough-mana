# Lineamientos de la v0.3 "Versión local completa contra bots"

Autor: Game Director. Fecha: 2026-10-14.
**Fuente de verdad:** `docs/revision/requisitos-v03-usuario.md` (lo escribió el usuario tras jugar; aquí lo cito como R1-R8 por secciones). Si este documento contradice ese, manda el del usuario y se escala.
Decisiones del usuario que **no se reabren** (`docs/DECISIONES.md`, 2026-10-14): versión local contra bots antes del modo en línea; arte con **packs libres aprobados por el usuario antes de descargarlos** + efectos propios por código; arte de las cartas intocable; **hot-seat oculto** (1 humano + bots); **límite de pociones desactivado por defecto** (activable); **temporizadores 30 s turno / 20 s defensa**, configurables por separado; al vencer el turno se termina y pasa al siguiente mago.

## 0. Qué he visto y qué no
- He leído los requisitos del usuario, las decisiones, la visión, los lineamientos y la evaluación de v0.2, la revisión de código del 2026-10-14, el informe y los bugs de QA, el rendimiento final, los documentos de arte y la arquitectura, y he mirado las capturas más recientes (`v2-35-mesa-6j-estados`, `v2-35-ficha-3j`, `v2-35-feedback-4j`, `v2-36-reaccion-6j`, `v2-35-menu`, todas a 720×1280).
- **No he ejecutado el juego ni los tests en esta tarea** y no puedo jugar con el dedo. Todo lo que digo de ergonomía es un juicio sobre capturas y medidas; la validación final es humana (§8, M12-bis).
- La sección 8 del documento del usuario llega cortada ("Evitar interfaces confusas:"). Trabajo con lo que hay y lo pregunto (E10).

### Diagnóstico visual en una línea por captura
- **Fondo:** la ilustración de SUPERHOTEX a pantalla completa detrás de la mesa es ruidosa (manchas rojas, azules y naranjas) y compite con todo; los paneles flotan sobre ella sin marco. Es la causa principal de que se vea "plano y poco trabajado": no hay atmósfera propia, hay un póster detrás.
- **Botones:** rectángulos redondeados violeta sin icono, todos parecidos; fuera de mi turno siguen ahí en gris (`v2-35-feedback-4j`: "Jugar, Intercambiar, Descartar, Terminar turno" visibles y apagados mientras juega Dario): ruido y duda.
- **Disposición:** hay ~150 px vacíos entre "Beber poción" y la mano; "Beber poción" ocupa el ancho entero y es el botón más grande de la mesa aunque no es la acción principal; la ficha empuja la mano.
- **Ataque:** no hay modo de apuntar visible: no se ve qué magos son objetivo válido ni cuál elegí. El aviso "Dario → Fire Arrow → Ana" es correcto pero sale tarde y tapa otros paneles (`v2-36-reaccion-6j`).
- **Defensa:** la hoja "Hechizo entrante" de v0.2 ya deja ver vida y maná, pero no dice qué pasa si no me defiendo, la barra de tiempo no tiene cifras ni identidad, y la respuesta no explica su efecto en español en la propia hoja.

---

## 1. Objetivo y alcance

**Objetivo de v0.3, en una frase:** que una partida de 1 persona contra 2-5 bots en el PC sea **divertida, clara y con aspecto de juego de magos**: se sabe siempre a quién atacas, quién te ataca y qué pasó, cada fase tiene su tiempo visible y los controles están donde el pulgar los espera.

**Dentro:** las secciones R2-R8 del usuario sobre el modo local contra bots, más los cimientos técnicos de la revisión de código que lo hacen posible (§7, bloque A).

**Fuera de v0.3:**
- **Multijugador en línea** (B1, Firebase): pasa a v0.5. Sin cambios de red, ni prueba de concepto de Firebase.
- **Hot-seat:** oculto (decisión del usuario). El código se conserva y sus tests siguen pasando, pero no se invierte en él (ni pantalla "Pasa el dispositivo" nueva, ni arreglo del plazo durante el pase, salvo lo que sea gratis al rehacer los temporizadores).
- **Android y Web:** sin builds. La **Web en red local** (decisión E9 del usuario) llega **después**, en v0.4 "En el celular". Lo móvil de v0.3 se diseña y mide en el PC con ventanas de proporción de celular.
- **Memoria de texturas (A3):** entra **solo la parte barata y necesaria ya**: quitar la caché estática que nunca libera (o LRU con tope) y medir antes/después, porque los packs nuevos van a añadir texturas y necesitamos un presupuesto (§6.4). **La compresión con pérdida/VRAM por plataforma espera a v0.4** (solo se puede medir en el dispositivo y en el navegador).
- Audio y vibración, tutorial guiado, estilos o dificultad de bots, variante por equipos, partida rápida (E2), guardar partida: después (§7, "Después").
- Estado estático del motor (A2), bot con texto en inglés (M1), dos vistas (M2), topes silenciosos (M6): solo se tocan si una tarea de v0.3 pasa por ahí; son requisito del modo en línea o del bot en un hilo, no de esta versión.

---

## 2. Dirección de arte: "magos, runas y artefactos" sobre la noche violeta

Principio rector, del propio usuario: **la ergonomía y la claridad mandan sobre la decoración** (R3, criterio de aceptación). Todo adorno que reduzca contraste, tape información o añada un toque se quita.

### 2.1 Qué se respeta
- **Arte y texto de las cartas © SUPERHOTEX: intocables.** No se recolorean, recortan ni tapan nombre o coste. Los marcos y brillos van **alrededor** de la carta, nunca encima del texto.
- **Packs libres solo con aprobación previa del usuario.** El Art Agent **propone 2-3 packs concretos por necesidad** (nombre, autor, URL, licencia exacta, si exige atribución, qué piezas usaríamos y una muestra de cómo quedaría con la paleta) en `docs/arte/propuesta-packs-v03.md`, **sin descargar nada**. El usuario elige; solo entonces se descarga cada pack a su carpeta con su archivo de licencia y una fila en `docs/arte/licencias.md`. Licencias aceptables: CC0, CC BY (con atribución), SIL OFL para fuentes. Nada "solo uso no comercial" ambiguo, nada de packs con arte de terceros sin licencia clara, nada generado a partir de las cartas.
- **Packs que hacen falta:**
  1. **UI de fantasía** (marcos 9-slice, paneles, botones de piedra/metal/gema, separadores, barras): candidato de referencia del usuario, Kenney Fantasy UI Borders (CC0). Art propone 2-3.
  2. **Iconos de runas, hechizos y artefactos** (acciones, estados, sigilos de cada mago): candidato game-icons.net (CC BY 3.0, exige atribución → pantalla "Créditos y licencias" en Ajustes). Art propone 2-3.
  3. **Fuentes** (título de fantasía + cuerpo legible), SIL OFL. Art propone 2-3 parejas.
- **Efectos propios por código** (shaders `canvas_item`, `CPUParticles2D`, `Line2D`, tweens): círculos rúnicos, proyectiles, impactos, escudos, transiciones. No se descarga ningún paquete de efectos.

### 2.2 Paleta (evoluciona la actual; no la sustituye)
| Papel | Color (hex aprox.) | Uso |
|---|---|---|
| Fondo noche arcana | `#0E0B1A` → `#1B1433` (degradado vertical) | fondo de la mesa y de las pantallas |
| Panel | `#1A1430` al 92-95 % | paneles de magos, hojas, ficha |
| Panel elevado | `#2A2045` | hoja de defensa, ficha, diálogos |
| Marco / metal | oro viejo `#B8913F`; brillante `#F2C14E` (= `COL_ACCENT` actual) | marcos, botón principal, jugador en turno |
| Violeta arcano (principal) | `#6633BD` (= `COL_PRIMARY_BG` actual) | relleno del botón principal |
| Runa / energía mágica | lavanda luminosa `#B69CFF` | círculos rúnicos, brillo de selección de objetivo, motas del fondo |
| Peligro / ataque recibido | carmesí `#E0303A` | aviso "¡Te atacan!", borde del atacante, últimos 5 s |
| Defensa | plata-acero `#C9D6E8` con brillo `#8FB4FF` | temporizador de defensa, escudos, hoja de defensa |
| Vida, maná, pociones, daño, curación | **sin cambios** (`COL_HP`, `COL_MANA`, `COL_POTION`, `COL_DAMAGE_FX`, `COL_HEAL_FX`) | ya probados en contraste y daltonismo |

Reglas: texto ≥ 4,5:1 sobre su panel (como hoy, `test_primary_text_contrast`); **ningún significado solo por color**: cada estado lleva además forma o icono (como el daño/curación de v0.2).

### 2.3 Tipografía
- **Títulos y banners** ("Tu turno", "¡Bruno te ataca!", título del menú, pantalla de fin): una fuente de fantasía con remates (estilo romano o uncial), **solo a ≥ 40 px a 1080** y en textos cortos. Nunca en números, registro, ficha ni botones secundarios.
- **Cuerpo, botones y números:** una sans humanista legible (o la actual), con cifras de ancho fijo para vida, maná y temporizador (que los números no "bailen" al bajar).
- **Obligatorio:** cubrir español completo (á é í ó ú ü ñ ¿ ¡) y **mantener DejaVu Sans como respaldo** en todos los `FontVariation` (`UiTheme.FALLBACK_GLYPHS` y `tests/ui/test_glyph_fallback.gd` siguen en verde). Mínimos de v0.2 sin cambios: ningún texto < 22 px a 1080.

### 2.4 Paneles y marcos
- **Paneles de mago:** fondo de panel con marco 9-slice de metal oscuro y remates rúnicos en las esquinas (pequeños, sin tapar cifras). Cada mago tiene un **sigilo** propio (icono de runa del pack, color fijo por asiento) junto al nombre: sirve para reconocer de un vistazo al atacante y al objetivo, y se repite en el registro y en los avisos.
- **Jugador en turno:** marco dorado con un brillo que recorre el borde (lento, ≤ 1 vuelta/2 s).
- **Objetivo válido** (modo apuntar): contorno lavanda pulsante + sigilo iluminado. **Objetivo elegido:** círculo rúnico girando alrededor del panel + marca de puntería. **No válido:** panel al 45 % de opacidad y el motivo en una línea al tocarlo ("Tiene Campo de fuerza").
- **Atacante:** borde carmesí durante el ataque y la defensa.
- **Eliminado:** se mantiene la lápida y el rayado de v0.2 (con el estilo nuevo).
- **Hojas y diálogos:** panel elevado con marco de metal y una franja de título con la fuente de fantasía.

### 2.5 Botones (los 5 estados que pide R3)
Tres niveles, siempre **icono + texto** (salvo Menú y registro, que son solo icono con zona táctil ≥ 96 px):
| Nivel | Uso | Tamaño a 1080 | Aspecto |
|---|---|---|---|
| Principal | la acción de la fase (Lanzar, Defender, Confirmar, Terminar turno cuando no queda nada jugable, Jugar local, Empezar) | alto ≥ 144 px | gema violeta con marco de oro brillante e icono grande |
| Secundario | Pasar/Recibir el golpe, Beber poción, Intercambiar, Descartar, Cancelar, Terminar turno (si quedan jugables) | alto ≥ 96 px (Pasar y Beber poción ≥ 144) | piedra/metal oscuro con marco de oro viejo |
| Terciario | Menú, registro, "Ver", Ajustes | ≥ 96 px de zona táctil | solo icono o texto pequeño |

Estados, todos distintos por forma y no solo por color:
- **Normal:** como arriba.
- **Pulsado:** se hunde 3-4 px (sombra interior), relleno más oscuro, marco más brillante; respuesta en el mismo fotograma del toque.
- **Deshabilitado:** desaturado, marco gris, icono atenuado; **si el jugador lo toca, aparece el motivo** (como en v0.2 con las cartas). Regla nueva: **un botón que no aplica a la fase actual no se muestra deshabilitado, se oculta** (§3.2).
- **Seleccionado / activo** (carta elegida, respuesta elegida, objetivo elegido): marco dorado grueso + brillo pulsante suave + marca ✓.
- **En proceso** (acción enviada, esperando animación o respuesta de bots): el botón muestra un pequeño círculo rúnico girando y no admite un segundo toque.

### 2.6 Fondos
- **Mesa:** **fondo propio**, no la ilustración de SUPERHOTEX: degradado de noche arcana, un gran círculo rúnico muy tenue (≤ 10 % de opacidad) girando despacio detrás del centro de mesa, viñeta en los bordes y ≤ 30 motas de luz lentas (desactivables con "Reducir animaciones"). Objetivo: atmósfera sin restar legibilidad. Generado por código o shader (sin pack).
- **Menú, nueva partida, fin:** puede usarse la portada o un fondo de SUPERHOTEX (uso personal), **oscurecido y desenfocado**, con el contenido siempre sobre panel. "Cómo se juega" con panel oscuro (cierra QA-V2-32-02).

### 2.7 Iconografía
Un icono por acción y estado, del mismo pack (coherencia): Lanzar (rayo o mano con runa), Defender (escudo), Pasar/Recibir (mano abierta o flecha), Beber poción (frasco), Intercambiar (flechas cruzadas), Descartar (carta con llama), Terminar turno (reloj de arena), Menú, Registro (pergamino), sigilos de mago (6 runas distintas), estados (congelado, cegado, campo de fuerza, maldito, eliminado, bot). Los iconos de estado propios de v0.2 se sustituyen solo si el del pack conserva una silueta distinta para cada uno; si no, se quedan.

### 2.8 Efectos
Ver §6. Estilo: luz mágica (brillos aditivos, runas, chispas), siempre breve y siempre con un destino claro (de quién a quién).

---

## 3. Ergonomía móvil (R3)

Supuesto de agarre: celular en vertical, una mano (pulgar derecho o izquierdo) o dos pulgares. La zona cómoda es la **mitad inferior, centrada**; la franja superior es solo para leer.

### 3.1 Mapa de la pantalla vertical (alturas en % desde arriba; referencia 1080×1920)
| Zona | Altura | Contenido | ¿Se toca? |
|---|---|---|---|
| Z1 Barra de fase | 0-6 % | Menú (icono, esquina), **banner de fase** ("Tu turno" / "Turno de Bruno" / "¡Bruno te ataca!") y **temporizador de turno** | Solo Menú (raro) |
| Z2 Registro | 6-11 % | 2-3 últimas líneas; tocar despliega | Raro |
| Z3 Rivales | 11-38 % | Paneles de rivales con sigilo, vida, maná, pociones, estados | **Solo en modo apuntar** (y para ver detalles) |
| Z4 Centro | 38-52 % | Mazo, descarte, evento; **aquí vuelan los hechizos**; con una carta elegida, la **ficha** ocupa esta zona (no roba altura a la mano: cierra QA-V2-35-06) | No |
| Z5 Mi mago | 52-60 % | Mi panel: vida, maná, pociones, estados; destino de los ataques que recibo | No |
| Z6 Dock de acción | 60-78 % | **Zona del pulgar**: botón principal de la fase (centro-derecha), secundarios (izquierda), Beber poción separado ≥ 24 px, **selector de objetivos** y **vista previa** del ataque | **Sí: todo lo frecuente** |
| Z7 Mano | 78-100 % | Abanico de cartas | **Sí: lo más frecuente** |

La defensa usa una **hoja inferior** que cubre Z6-Z7 (no Z5: mi vida y maná siguen a la vista, como en v0.2).

### 3.2 Qué se muestra en cada fase
| Fase | Se muestra | Se oculta |
|---|---|---|
| **Mi turno, sin carta elegida** | Banner "Tu turno" + temporizador de turno (oro); mano con jugables marcadas; dock con Intercambiar, Descartar, Beber poción (si es legal) y **Terminar turno** (secundario; pasa a principal si no queda nada jugable) | Selector de objetivos, vista previa |
| **Mi turno, carta elegida** | Ficha en Z4; dock con **Lanzar** (principal) o "Elige objetivo", y Cancelar | Intercambiar/Descartar (vuelven al cancelar) |
| **Mi turno, apuntando** | Rivales válidos resaltados en Z3 **y** como fichas pequeñas (sigilo + nombre + vida) en el dock; inválidos atenuados; vista previa al elegir | Todo lo demás del dock salvo Lanzar y Cancelar |
| **Esperando la respuesta de los bots a mi hechizo** | Banner "Bruno puede responder…", reloj de arena en el panel de Bruno, mi temporizador **en pausa** (icono de pausa) | Botones de acción (estado "en proceso") |
| **Defensa** | Aviso de ataque, atacante resaltado, hoja de defensa con **temporizador de defensa** (plata), consecuencia de no defenderse, respuestas con su efecto, Pasar, Beber poción si es legal | Mano normal y botones de turno |
| **Esperando a un bot** | Banner "Turno de Bruno" con su sigilo; panel de Bruno en oro; dock reducido a una línea de estado ("Bruno está pensando…"); mano visible para planear, sin marcos de jugable | **Botones de turno: ocultos, no grises.** Beber poción solo si es legal en ese momento |
| **Eliminado** | Mesa en modo espectador con aviso fijo "Has sido eliminado" y botón "Ver resultado" | Dock y mano |

### 3.3 Criterios medibles (los verifica QA con tests de disposición y capturas)
1. **Zona del pulgar:** el centro de cada botón principal, de Pasar, de Beber poción y de cada ficha del selector de objetivos está por debajo del **55 %** de la altura de la pantalla. Ningún control de acción por encima del 30 % salvo Menú y registro.
2. **Un solo principal:** en cada estado de §3.2 hay **como máximo 1** botón principal visible y habilitado.
3. **Nada que no aplique:** fuera de mi turno, **0** botones de acciones de turno visibles.
4. **Tamaños:** principal ≥ 144 px de alto a 1080, secundario ≥ 96, Pasar y Beber poción ≥ 144; separación ≥ 16 px y ≥ 24 px alrededor de Beber poción (criterios de v0.2 que se mantienen); zona táctil de un panel de rival en modo apuntar ≥ 144×144 px.
5. **Toques:** lanzar un hechizo de un objetivo ≤ 3 toques (carta, objetivo, Lanzar); 2 si solo hay un objetivo válido (se preselecciona). Defenderse con una respuesta ≤ 2; pasar 1; terminar turno 1. Sin pago extra; el pago con cartas añade sus toques actuales.
6. **Mano:** con 5 cartas, cada carta ≥ 150 px de ancho a 1080 en cualquier fase y número de jugadores, también con la ficha abierta.
7. **Pantallas:** sin solapes, recortes ni texto < 22 px a 720×1280, 1080×1920, **1080×2400 y 720×1600 (20:9)**, con 3, 4 y 6 jugadores; margen superior de ≥ 48 px a 1080 libre de controles (muesca/cámara).
8. **Respuesta al toque:** todo botón cambia a "pulsado" en el fotograma del toque; toda acción enviada muestra "en proceso" hasta que su resultado se ve.

---

## 4. Rediseño del ataque y de la defensa (R5, R6)

Flujos para que el Game Designer los detalle (textos exactos, casos raros, criterios) en `docs/diseno/`. Restricción de alcance: **la vista previa describe el efecto nominal de la carta y los modificadores visibles** (escudo activo del objetivo, Campo de fuerza), con "si nadie responde"; **no se construye un predictor de daño** (sería una tercera copia de las reglas, el problema M1).

### 4.1 Ataque (mi turno)
| Paso | Qué hace el jugador | Qué ve |
|---|---|---|
| A0 Inicio de turno | — | Banner "Tu turno" (≤ 600 ms), mi panel en oro, la mano se activa (jugables con marco brillante; no jugables atenuadas, con motivo al tocar). El temporizador de turno arranca **al terminar el banner** |
| A1 Elegir carta | Toca una carta | La carta se eleva; ficha en Z4 (nombre, coste efectivo, efecto en español). Dock: "Lanzar" si no necesita objetivo; "Elige objetivo" si lo necesita |
| A2 Apuntar | Toca un rival (en su panel o en su ficha del dock) | Rivales válidos con contorno pulsante y sigilo iluminado, inválidos atenuados con motivo. Si solo hay un válido, ya viene elegido. Cartas de "todos" o "vecinos": se resaltan todos los afectados, sin paso de apuntar |
| A3 Vista previa | — | Círculo rúnico en el objetivo, línea de puntería desde mi panel, y en el dock: "**Fire Arrow → Bruno: pierde 1 de vida** (si nadie responde). Coste: 1 maná." Si hay pago con cartas, se encadena el paso de pago de v0.2 |
| A4 Lanzar | Toca **Lanzar** | La carta vuela al centro, círculo rúnico en mi panel, proyectil del elemento de la carta hacia el objetivo (§6) |
| A5 Respuestas | — | Si algún bot puede responder: "Bruno puede responder…", reloj de arena en su panel, mi temporizador en pausa. Si responde, se ve su carta y la cadena |
| A6 Resultado | — | Impacto en el objetivo + etiqueta de resultado sobre su panel: **IMPACTO −2**, **BLOQUEADO**, **REDUCIDO −1**, **REFLEJADO**, **ANULADO**, **CURADO +2** (forma y texto, no solo color) + línea del registro. Vuelve a A1 con el temporizador reanudado |
| Fin | Toca **Terminar turno**, o vence el tiempo | Transición al siguiente mago (§6) |

Regla de oro: el jugador **nunca adivina a quién ataca** (el objetivo elegido está marcado antes de lanzar) **ni si se ejecutó** (todo lanzamiento termina en una etiqueta de resultado visible ≥ 1 s).

### 4.2 Defensa (me atacan)
| Paso | Qué hace el jugador | Qué ve |
|---|---|---|
| D0 Aviso | — | Banner carmesí "**¡Bruno te ataca!**" con su sigilo (≤ 400 ms de entrada, se queda en Z1 mientras dura la defensa), borde carmesí en el panel de Bruno, línea de Bruno a mi panel, la carta del hechizo grande con su efecto en español |
| D1a Sin respuestas posibles | — | **No hay fase de defensa ni temporizador** (hoy la ventana solo espera a quien puede responder; se mantiene). Se ve "No tienes defensas para este hechizo" y el resultado (D3) |
| D1b Fase de defensa | — | Hoja inferior "**Defiéndete**" con el **temporizador de defensa** (arranca cuando la hoja es visible), la consecuencia de no hacer nada ("Si pasas: pierdes 1 de vida y descartas 1 carta"), mi vida y maná a la vista, cada respuesta posible como carta grande con su efecto en una línea ("Magic Shield: evita 2 de daño de hechizo") y su coste; las que no puedo pagar, atenuadas con el motivo ("Te falta 1 de maná: bebe una poción") |
| D2 Elegir | Toca una respuesta (queda **seleccionada**) y luego **Defender** (principal); o **Recibir el golpe** (Pasar, secundario grande). Si hay una sola respuesta, ya viene seleccionada | La respuesta elegida con marco dorado; Defender pasa a "en proceso" al tocarlo |
| D2' Cadena | — | Si el atacante responde (p. ej. Lightning), banner "Bruno responde" y **nueva ronda con su propio temporizador**; es el único caso en que el temporizador de defensa vuelve a empezar, y se anuncia |
| D3 Resultado | — | Efecto de escudo o impacto sobre mi panel y etiqueta: **BLOQUEADO**, **REDUCIDO −1**, **IMPACTO −2**, **REFLEJADO**; línea del registro; la hoja se cierra |
| Tiempo agotado | — | "Se acabó el tiempo: recibes el golpe" (≥ 1 s) y D3 |

Las demás decisiones fuera de mi turno que provoca un rival (prompts del motor: maná insuficiente, Visit of the Archmage, Magic Cap, Mana Focus, Elixir, descarte forzado) usan **la misma hoja y el mismo temporizador de defensa**. Las que surgen en mi turno usan el temporizador de turno. Lo detalla el Game Designer.

La preferencia "Avisarme de reacciones" (v0.2) se mantiene: con "solo si me afecta", los hechizos entre bots no me interrumpen; un ataque contra mí siempre me avisa.

---

## 5. Temporizadores (R7)

**Es una adaptación digital nueva:** el juego físico no tiene reloj. El motor **no lee el reloj** (determinismo): igual que el plazo de reacción actual, **la sesión** cuenta el tiempo y, al vencer, **envía acciones normales** (`END_TURN`, `PASS_REACTION`, `DECLINE`…). Para el motor es como si el jugador las hubiera elegido. El cómo (dónde vive el plazo, si el de turno va en el estado o solo en `LocalSession`) es del Lead Programmer.

| | Turno de ataque | Fase de defensa |
|---|---|---|
| Por defecto | **30 s** | **20 s** |
| Configurable | Sí, por separado (p. ej. 15 / 20 / 30 / 45 / 60 / Sin límite); en la pantalla de nueva partida, junto al límite de pociones, y se recuerda para la siguiente | Sí (p. ej. 10 / 15 / 20 / 30 / Sin límite) |
| Aspecto | **Oro**, reloj de arena; barra horizontal bajo el banner de Z1 + cifras "0:24"; el borde de Terminar turno se vacía con él | **Plata-acero**, escudo; anillo segmentado con cifras grandes en la cabecera de la hoja de defensa |
| Aviso | Últimos 10 s: ámbar y pulso; últimos 5 s: carmesí | Últimos 5 s: carmesí |
| Cuándo corre | Solo mientras yo puedo actuar en mi turno. **Pausa** (con icono) mientras se espera a otros (respuestas de bots a mi hechizo) y con el menú de partida abierto. **No se reinicia con cada acción**: 30 s por turno completo | Desde que la hoja de defensa es visible hasta que respondo. Nueva ronda de la cadena = nuevo plazo, anunciado |
| Al vencer | La sesión descarta lo que estuviera a medias en la interfaz (carta elegida, objetivo, pago sin confirmar), resuelve mis decisiones pendientes con el valor por defecto y envía **Terminar turno**. Registro: "Se acabó el tiempo de Ana" | **Pasar** (recibir el golpe). En los prompts opcionales, **rechazar** (`DECLINE`) |
| Bots | **No aplica**: siguen con su retardo de 600-900 ms | No aplica |

Puntos abiertos (en `docs/ESCALADOS.md`):
- **E11:** qué se elige al vencer en una decisión **obligatoria** sin opción de "no hacer nada" (descarte forzado, elegir cartas). Recomiendo: lo que elegiría un bot en ese momento, avisado en el registro.
- **E12:** confirmar que "30 s" es **por turno completo** (no por acción) y que se ofrece "Sin límite".

**Relación con M3 de la revisión de código:** (1) **reloj monótono** en local (`Time.get_ticks_msec`), no el de pared, para los dos temporizadores: entra en v0.3. (2) El plazo que corría durante "Pasa el dispositivo" deja de darse al ocultar el hot-seat; queda **como requisito para reactivarlo** (el plazo arranca tras "Soy X"), no se trabaja ahora. (3) Tests con reloj inyectado (la sesión ya acepta un `clock`), nunca con esperas reales.

---

## 6. Animaciones y efectos (R4)

### 6.1 Qué se anima
| Momento | Efecto | Duración (normal) |
|---|---|---|
| Robar | carta del mazo a la mano, en abanico | 200 ms por carta, escalonado 60 ms |
| Elegir carta | se eleva y brilla | 120 ms |
| Lanzar | carta de la mano al centro + círculo rúnico en el lanzador | 250 ms |
| Trayecto | proyectil por elemento: fuego (bola con estela de chispas), hielo (esquirla con cristales), rayo (línea quebrada con destello), sin elemento (orbe violeta); curaciones, chispas que suben | 300-400 ms |
| Impacto | destello en el panel (shader de v0.2) + anillo expansivo + número flotante + etiqueta de resultado | 250 ms + texto ≥ 1 s (en paralelo, no bloquea) |
| Escudo / bloqueo | burbuja de runas que absorbe el proyectil; reflejo: el proyectil rebota | 350 ms |
| Artefacto / evento | la carta aparece con un aro rúnico en su sitio | 300 ms |
| Poción | burbujas verdes en mi panel | 300 ms |
| Eliminación | el panel se apaga a piedra con humo | 500 ms |
| Cambio de turno | banner del mago con su sigilo | 400-600 ms |
| Aviso de ataque | banner carmesí | 300-400 ms de entrada |

### 6.2 Presupuesto de tiempo (que no ralentice)
- **Acción completa ≤ 900 ms** desde que se lanza hasta que se ve el resultado (sin contar la espera a respuestas). Cambio de turno ≤ 600 ms. Una animación **nunca** bloquea un toque del jugador más de 300 ms.
- **Secuenciación:** las acciones de los bots **esperan a que termine la presentación de la anterior** (contrapresión del bus, prevista en la decisión del 2026-10-13 "v0.3 si hace falta": hace falta). La cola de presentación no acumula más de **1,5 s** de retraso respecto al motor; si se pasa, acelera (×2) en vez de encolar.
- Un turno típico de bot (2-3 acciones) dura ≤ 4 s con animaciones normales.

### 6.3 Rendimiento (medido en escritorio en v0.2: animación p95 ~3 ms; fotograma con acción p95 20-27 ms; meta 16 ms)
- Fotogramas con animación, p95 **≤ 16 ms** (criterio duro).
- Fotograma con acción, p95 **sin empeorar la v0.2** (≤ 27 ms con 6 jugadores; tolerancia +2 ms); meta 16 ms (objetivo, no criterio de cierre: la palanca grande, la decisión del bot fuera del fotograma, depende de A2 y no entra salvo que el presupuesto se rompa).
- Partículas: `CPUParticles2D` (compatibles con Web), ≤ 64 por efecto y ≤ 150 en pantalla; shaders solo `canvas_item`, sin `screen_texture`.
- Las animaciones no reconstruyen paneles (`refresh()` completo prohibido por feedback, como en v0.2).

### 6.4 Memoria
Medir la memoria de texturas antes y después (`tests/perf/perf_final.gd`). Con la caché de A3 arreglada, los packs nuevos **no suben más de 20 MB** la memoria de texturas frente a la medida tras A3. Si no caben, se reducen los packs, no el arte de las cartas.

### 6.5 "Reducir animaciones" (Ajustes)
Trayectos y vuelos de cartas instantáneos, sin partículas ni motas del fondo, sin giro del círculo rúnico, banners sin desplazamiento. **Se mantienen** los destellos, números flotantes y etiquetas de resultado (≥ 1 s): son información, no adorno. Acción completa ≤ 400 ms.

---

## 7. Prioridades de v0.3 (orden de ejecución)

### Bloque A: cimientos técnicos y arreglos de la revisión
| # | Qué | Hecho cuando |
|---|---|---|
| 1 | **A4 herramientas de test** (`mkdir -p .godot`, `override.cfg` en `.gitignore` o fuera de la raíz, `flock -w`) | En un clon limpio `bash tools/test.sh` funciona a la primera; matar `check_warnings.sh` con `kill -9` no deja configuración que afecte al juego; QA lo reproduce |
| 2 | **A1 acciones legales sobre la vista** (contrato del Lead Programmer; el espejo de Twardowsky deja de desaparecer) | Test que compara `legal_actions(estado)` y `legal_actions(vista propia)` en ≥ 1000 estados del simulador: idénticas; el espejo se ofrece en la interfaz. **Es requisito de resaltar objetivos válidos (#8)** |
| 3 | **M4 aislamiento de tests y 0 nodos huérfanos** | Base común que restaura los estáticos; ruta `user://` de pruebas; `tools/test.sh` falla si hay huérfanos y hoy da 0 |
| 4 | **Temporizadores en la sesión** (+ M3: reloj monótono; M5 al tocar `LocalSession`: `start()` reinicia todo y la cola avisa si descarta) | Tests con reloj inyectado: turno vence → `END_TURN` tras resolver lo pendiente; defensa vence → `PASS_REACTION`/`DECLINE`; pausa mientras se espera a bots; no se reinicia con cada acción; "Sin límite" funciona; los bots no tienen plazo; 50 partidas con un humano que nunca actúa terminan sin bloqueo |
| 5 | **Presentación secuenciada y "Reducir animaciones"** (contrapresión del bus, presupuesto de §6.2) | Los bots no adelantan a la presentación; retraso máximo de la cola ≤ 1,5 s medido en 3 y 6 jugadores; la opción existe en Ajustes, se guarda y cumple §6.5 (test) |

### Bloque B: mecánica y UX
| # | Qué | Hecho cuando |
|---|---|---|
| 6 | **Partida contra bots**: hot-seat oculto (1 humano + 2-5 bots), límite de pociones desactivado por defecto y activable, temporizadores configurables | La pantalla de nueva partida solo permite 1 humano; 200 simulaciones con valores por defecto: 200/200 terminadas, 0 violaciones; los tests de hot-seat siguen pasando (código conservado) |
| 7 | **Mesa por zonas y por fase** (§3) | Los 8 criterios de §3.3 cubiertos por tests de disposición y capturas por fase a 720×1280, 1080×1920, 1080×2400 y 720×1600 |
| 8 | **Flujo de ataque** (§4.1, especificado por el Game Designer) | Capturas de A1-A6; tests: solo los válidos resaltados (coincide con `legal_actions`), objetivo único preseleccionado, ≤ 3 toques, toda acción termina en etiqueta de resultado |
| 9 | **Flujo de defensa** (§4.2) | Capturas de D0-D3; tests: aviso con atacante y hechizo, consecuencia de pasar, efecto de cada respuesta, sin fase si no hay respuestas, ≤ 2 toques, etiqueta de resultado |
| 10 | **Temporizadores en pantalla y transiciones de turno** (§5, §6.1) | Turno y defensa distinguibles por color, forma, icono y posición (capturas); avisos de 10 y 5 s; pausa visible; mensaje al vencer |

### Bloque C: visual
| # | Qué | Hecho cuando |
|---|---|---|
| 11 | **Propuesta de packs** (Art): 2-3 por necesidad con licencia, **sin descargar** | `docs/arte/propuesta-packs-v03.md` entregado; el usuario elige (escalado E13); descargados solo los elegidos, con licencia en su carpeta y en `docs/arte/licencias.md` |
| 12 | **Tema nuevo y A3** (Technical Artist + Art): paleta, fuentes, paneles, marcos, botones de 5 estados, sigilos, fondo propio de la mesa; caché de texturas arreglada | Guía `docs/arte/estilo-v03.md`; contraste ≥ 4,5:1 por test; DejaVu de respaldo (test de glifos en verde); memoria de texturas medida antes/después y dentro de §6.4; pantalla "Créditos y licencias" si algún pack exige atribución |
| 13 | **Efectos y animaciones** (§6) | Cada fila de §6.1 visible en captura o vídeo; rendimiento de §6.3 medido por Performance en 3 y 6 jugadores |
| 14 | **Pantallas fuera de la mesa** con la identidad nueva (menú, nueva partida, Ajustes, Cómo se juega con panel, fin) | Capturas a 720×1280 y 1080×2400; 0 opciones muertas (interfaz honesta, como en v0.2) |
| 15 | **Conjunción astral** (decidida por el usuario para v0.3, E4), opción desactivada | Especificación aprobada por el usuario, tests, 200 simulaciones con la opción: 200/200. **Es lo último**: si no cabe, pasa a v0.3.1 y se avisa al usuario (E14) |

**Orden y paralelismo** (lo planifica el Producer): 1-3 primero (baratos); 11 puede empezar a la vez (no toca código y la aprobación del usuario tarda); 4-5 y 12 antes de 7-10 y 13. Tope de 2 agentes simultáneos, como en v0.2.

### Después (no entra en v0.3)
- **v0.4 "En el celular":** Web en red local (E9), compresión de texturas (resto de A3), prueba táctil real, audio mínimo y vibración.
- **v0.5:** multijugador en línea (B1), con A2, M1, M2 y la decisión de la ventana de reacción en línea.
- Bots que usan las 15 cartas que nunca juegan y estilos de bot: **sube a v0.3.1** si M12-bis dice que los bots aburren.
- Tutorial guiado (solo si M12-bis muestra que la ficha y "Cómo se juega" no bastan), partida rápida (E2), equipos, hot-seat de nuevo.
- Cosméticos sueltos (línea redundante del registro, QA-V2-21-04): cuando un Developer pase por ese archivo.

---

## 8. Criterio de aceptación de v0.3

**Antes de la prueba humana, QA mide y entrega (puerta final):**
1. `bash tools/test.sh` en verde, `bash tools/check_warnings.sh` sin warnings, **0 nodos huérfanos**.
2. 200 simulaciones con la configuración por defecto (sin límite de pociones): 200/200 terminadas, 0 violaciones; 50 con un humano "ausente" que agota siempre el tiempo: todas terminan.
3. Los criterios de §3.3 (zona del pulgar, un solo principal, nada que no aplique, tamaños, toques, mano, resoluciones, respuesta al toque) con tests y capturas por fase.
4. Temporizadores: los casos de la prioridad 4 y su aspecto (prioridad 10).
5. Rendimiento (Performance): §6.3 y §6.4 en 3 y 6 jugadores a 720 y 1080; duración de un turno de bot (≤ 4 s).
6. Licencias: cada asset nuevo con su licencia y su fila en `docs/arte/licencias.md`; nada descargado sin aprobación; arte de las cartas sin modificar.
7. Una tanda de capturas para el Director: menú, nueva partida, mi turno, apuntar, vista previa, impacto, esperando a bot, defensa, defensa por tiempo, fin de turno por tiempo, eliminado, fin, Ajustes, "Reducir animaciones".

**Prueba humana final, M12-bis (el criterio del usuario, R3):** *"evaluar cada pantalla durante una partida real para comprobar que los controles están donde el jugador espera encontrarlos, que las acciones frecuentes se ejecutan cómodamente y que la interfaz no dificulta la lectura del combate"*. El usuario juega en el PC **2 partidas** (una con 3 bots, otra con 5), con la ventana a tamaño de celular (720×1280) y, si puede, otra a 1080×2400, y responde por pantalla y por fase:
- ¿Encontraste cada control donde lo esperabas? ¿Tuviste que buscar alguno?
- ¿Supiste siempre **a quién atacabas** y **si se ejecutó**? ¿Supiste siempre **quién te atacaba, con qué** y **si te defendiste**?
- ¿30 s de turno y 20 s de defensa se sienten bien? ¿Se distinguen los dos relojes?
- ¿Las animaciones ayudan o estorban? ¿Alguna vez esperaste de más?
- ¿Se ve como un juego de magos? ¿Algo sigue pareciendo "una aplicación"?
- ¿Volverías a jugar contra los bots? (pregunta de diversión)

**Veredicto:** aprobado si todo lo anterior está en verde y el usuario responde "sí" a las preguntas de claridad y de ubicación de controles; si alguna es "a veces" o "no", **Aprobado con cambios** y v0.3.1 solo con esos arreglos. **Limitación conocida:** con ratón no se valida el pulgar; la ergonomía táctil real se confirma en v0.4 (Web en red local en el celular).

## 9. Preguntas al usuario
En `docs/ESCALADOS.md`: **E10** (¿la sección 8 tenía más texto?), **E11** (elección al vencer en decisiones obligatorias), **E12** (30 s por turno completo y opción "Sin límite"), **E13** (aviso: aprobar los packs cuando Art los proponga) y **E14** (Conjunción astral al final de v0.3 o en v0.3.1).

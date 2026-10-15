# Mesa por zonas y por fase, v0.3 (V3-04)

Autor: Level Designer. Fecha: 2026-10-14. Destino: V3-17 y V3-19 (Developers) y QA (los criterios de la sección 9 son tests). Entradas: `docs/revision/requisitos-v03-usuario.md` §3, `docs/revision/LINEAMIENTOS-v03.md` §3, `docs/diseno/v03-ataque-defensa.md`, `docs/diseno/escenarios/mesa-5-6-jugadores.md` (v0.2, sigue vigente para el contenido del panel de rival), `docs/arte/tecnico.md` y las capturas `v2-35-ficha-6j-720x1280`, `v2-35-mesa-6j-estados`, `v2-36-reaccion-6j`. No cambia reglas ni textos de Game Designer.

**Qué he visto y qué no.** Leí los documentos y miré `v2-35-ficha-6j-720x1280.png`: confirma el defecto QA-V2-35-06 (la ficha entra en el flujo vertical entre "Beber poción" y la mano; la mano queda en ~150 px de alto con cartas de ~100 px de ancho a 720, unos 150 a 1080) y ~150 px vacíos entre "Beber poción" y la mano en otras fases. No ejecuté el juego ni medí en pantalla: **todas las cifras de abajo son diseño y cálculo, no medición**. El pulgar real no se valida con ratón (limitación conocida de LINEAMIENTOS §8).

## 1. Principios

1. **Cuatro bloques de altura fija anclados abajo (Z5, Z6, Z7) y arriba (Z1, Z2, Z3); solo Z4 es elástica.** Ningún cambio de fase mueve ni redimensiona la mano, el dock ni mi panel. Esto cierra QA-V2-35-06: la ficha es un **contenido de Z4**, nunca un nodo que empuja otros.
2. **El botón principal vive siempre en el mismo sitio**: fila B del dock, a la derecha (x 360-1064). Beber poción siempre en fila B a la izquierda. Un botón que no aplica se oculta y **su hueco queda vacío** (no se reflujan los demás: memoria muscular).
3. **Lo que se toca está en el 66 % inferior**; lo que solo se lee, arriba.
4. La hoja de defensa y los prompts **no tapan** Z5 (mi vida y maná).
5. Un único idioma de selección: contorno/marco dorado + ✓ = elegido; lavanda pulsante = elegible; 45 % de opacidad = no válido (LINEAMIENTOS §2.4).

## 2. Convenciones

- **Unidades:** px lógicos con el ancho base 1080 (`project.godot`: viewport 1080x1920, `stretch/mode=canvas_items`, `aspect=expand`). 720 de ancho = ×2/3 de todo (144→96, 96→64, 22→14,7). Con ventana más ancha que 9:16 la altura lógica queda en 1920 y se **centra una columna de 1080**; con ventana más alta la altura lógica crece (20:9 ⇒ H = 2400 a 1080 y a 720x1600).
- Las cuatro pantallas de la tarea son **dos alturas lógicas**: **H = 1920** (1080x1920 y 720x1280) y **H = 2400** (1080x2400 y 720x1600). Margen lateral 16, separación entre paneles 12 (como v0.2).
- **Margen superior** = `max(48, safe_area_top)`; **inferior** = `max(32, safe_area_bottom)`. Abajo uso 32.
- Mínimos de `tecnico.md`: `FONT_MIN` 22, `BUTTON_MIN_H` 96, `BUTTON_PRIMARY_H` 144, separaciones 16/24. Tamaños de texto que fijo aquí (todos ≥ 22): banner 40, título de hoja 40, nombre en ficha 34, texto de preview/consecuencia 28, registro 26, cifras de reloj 28 (ring 40), resumen en ficha 24, chips y etiquetas 22-26.

## 3. Mapa de zonas (px lógicos; "b" = H-32 es la línea inferior)

| Zona | Alto | y inicio | y fin | Contenido | ¿Se toca? |
|---|---|---|---|---|---|
| Z1 Barra de fase | 184 | 0 (controles desde 48) | 184 | Fila 1 (y 48-144): Menú 96x96 en x16, **banner** (x128-952, fuente de fantasía 40, 1-2 líneas), hueco derecho 96x96 libre. Fila 2 (y 152-184): **temporizador de turno** (solo en mi turno) | Menú (raro) |
| Z2 Registro | 88 | 192 | 280 | 2 líneas de 26 px; toque la despliega | Raro |
| Z3 Rivales | 200 / 332 / 412 | 288 | 488 (3-4j) / 620 (5j) / 700 (6j) | Paneles de rival (rejilla de v0.2) | Solo en modo apuntar |
| Z4 Centro | elástica | Z3 fin + 12 | H-872 | Mazo, descarte, evento, **ficha**, vista previa, carta del hechizo entrante, etiquetas de resultado; aquí vuelan los hechizos | No |
| Z5 Mi mago | 120 | H-860 | H-740 | Mi panel (nombre, vida, maná, pociones, iconos de estado), a todo el ancho | No |
| Z6 Dock | 336 | H-728 | H-392 | Dos bandas de 144: **fila A** y **fila B** (ver §5) | **Sí** |
| Z7 Mano | 360 | H-392 | H-32 | Abanico; carta en reposo 210x294 en y H-326 a H-32, elevada 36 px al elegirla | **Sí** |

Huecos: Z1-Z2 8, Z2-Z3 8, Z3-Z4 12, Z4-Z5 12, Z5-Z6 12. Z4 alto = `H - 872 - (Z3_fin + 12)`. La suma completa para 6j está comprobada en la sección 9.1, criterio 7.

### 3.1 Valores resultantes

| | H = 1920 (1080x1920) | 720x1280 (×2/3) | H = 2400 (1080x2400) | 720x1600 (×2/3) |
|---|---|---|---|---|
| Z1 / Z2 | 0-184 / 192-280 | 0-123 / 128-187 | igual | 0-123 / 128-187 |
| Z3 inicio | 288 | 192 | 288 | 192 |
| Z3 fin 3-4j / 5j / 6j | 488 / 620 / 700 | 325 / 413 / 467 | igual | igual que 1280 |
| **Z4** alto 3-4j / 5j / 6j | 548 / 416 / 336 | 365 / 277 / 224 | 1028 / 896 / 816 | 685 / 597 / 544 |
| Z4 fin (= H-872) | 1048 | 699 | 1528 | 1019 |
| Z5 | 1060-1180 | 707-787 | 1540-1660 | 1027-1107 |
| Z6 | 1192-1528 | 795-1019 | 1672-2008 | 1115-1339 |
| Z7 (mano) | 1528-1888 | 1019-1259 | 2008-2368 | 1339-1579 |

En 20:9 la altura extra (480 lógicos) va **solo a Z4**; los bloques que se tocan no se mueven respecto al borde inferior (el pulgar encuentra todo igual en cualquier alto de pantalla). En Z4 las cartas del centro mantienen su escala máxima y la ficha y la vista previa se anclan arriba de Z4 (junto al objetivo), el resto queda libre para efectos.

### 3.2 Rejilla de rivales por número de jugadores (1 humano + 2-5 bots)

El humano siempre es el asiento propio (Z5). Orden: sentido del turno, empezando por el siguiente al mío.

| Jugadores | Rivales | Rejilla | Panel | Z3 alto | Notas |
|---|---|---|---|---|---|
| 3 | 2 | 1 fila x 2 | **518 x 200** | 200 | contenido del panel de 4j reordenado en 3 filas como v0.2; más ancho, no más alto |
| 4 | 3 | 1 fila x 3 | 341 x 200 | 200 | rotación 0 (en v0.3 ya no hay abanico) |
| 5 | 4 | 2 x 2 | 518 x 160 | 332 | stats en una fila (v0.2 §3) |
| 6 | 5 | 3 x 2, 6.ª celda vacía | 341 x 200 | 412 | celda vacía no se reutiliza |

Todos ≥ 144x144 de zona táctil. A 720 se escala ×2/3 (p. ej. 227x133, 345x107; ambos ≥ 96x96).

## 4. Qué se ve y qué se oculta, por fase

Leyenda: **VIS** visible, **OCU** oculto (no existe/no ocupa hueco que reflujo), **GRIS** atenuado, **—** hueco vacío.

| Elemento | F1 Mi turno, sin selección | F2 Carta elegida (sin objetivo) | F3 Eligiendo objetivo | F4 Confirmando / pagando | F5 Defensa ("Defiéndete") | F6 Esperando bot (y respuestas de bot a mi hechizo) | F7 Prompt obligatorio | F8 Fin / eliminado |
|---|---|---|---|---|---|---|---|---|
| Z1 banner | "Tu turno" (oro) | igual | igual | igual | "¡X te ataca!" (carmesí) | "Turno de X" / "X puede responder…" | banner de la causa | "Has sido eliminado" / vacío |
| Z1 reloj de turno | corre | corre | corre | corre | en pausa ⏸ si es mi turno; OCU si no | OCU (turno de bot) / ⏸ si espero respuesta a mi hechizo | corre o ⏸ según §5 de `v03-ataque-defensa` | OCU |
| Z2 registro | VIS | VIS | VIS | VIS | VIS | VIS | VIS | VIS (en fin: parte del resumen) |
| Z3 rivales | normal | normal; con carta de área: afectados con contorno | **válidos con contorno lavanda; inválidos 45 %; elegido con círculo rúnico** | normal | atacante con borde carmesí; el resto atenuado al 60 % | el de turno en oro; el que puede responder con reloj de arena | atenuados al 60 % | espectador: normales |
| Z4 centro | mazo/descarte/evento a escala; recibe toasts de motivo | tira de 3 chips (48) + **ficha** (148) + **preview** (112) | igual que F2 | ficha con el coste a pagar y contador "k/N" | **carta del hechizo** a escala (≤ Z4 alto - 56) + "X → tú" | centro normal con resultados | centro normal | centro normal |
| Z5 mi panel | VIS, en oro | VIS | VIS | VIS | **VIS, por encima del escrim** | VIS | **VIS, por encima del escrim** | VIS (apagado si eliminado) |
| Z6 fila A | Intercambiar \| Descartar | — | **chips de objetivos** (5 máx.) | — | hoja cubre Z6 | Última jugada (2 líneas, solo lectura) | hoja cubre Z6 | OCU |
| Z6 fila B | Beber poción \| **Terminar turno** (pasa a principal si no queda nada jugable) | Cancelar \| **Lanzar** | Cancelar \| **Lanzar** (deshabilitado con motivo hasta elegir) | Cancelar \| **Confirmar** | (en la hoja) | estado "X está pensando…" (no botón); **Beber poción solo si es legal** | (en la hoja) | OCU |
| Z7 mano | VIS, jugables marcadas | VIS, elegida elevada | VIS, elegida elevada | VIS, **cartas de pago marcables** | cubierta por la hoja | VIS sin marcos de jugable (toque = ver ficha) | cubierta, salvo descarte/elegir carta (§7.7) | OCU |
| Hoja | OCU | OCU | OCU | OCU | **VIS** | OCU | VIS | OCU; pantalla de fin a pantalla completa |

Reglas derivadas (verificables):
- Fuera de mi turno y fuera de F5/F7 hay **0 botones de acciones de turno** visibles (criterio 3 de §3.3).
- En cada fase hay **≤ 1** botón principal visible y habilitado.
- Intercambiar, Descartar y Terminar turno **no existen** en F2-F4 (se restauran al cancelar). En F2-F4 el hueco de la fila A queda vacío.

## 5. Dock (Z6), geometría exacta

Z6 mide 336: banda A (y+12 a y+156), banda B (y+180 a y+324), 24 entre bandas, 12 arriba y abajo. Botones secundarios de 96 se centran en su banda (y+36..132 y y+204..300); principales y Beber poción, 144 completos.

| Elemento | x | Alto | Centro y (desde Z6 inicio) | Centro y en H=1920 (%) | en H=2400 (%) |
|---|---|---|---|---|---|
| Fila A: Intercambiar | 16-528 (512) | 96 | +84 | 1276 (66,5 %) | 1756 (73,2 %) |
| Fila A: Descartar | 552-1064 (512) | 96 | +84 | 1276 | 1756 |
| Fila A: chips de objetivo (≤5) | 16 + n·(196+16), ancho 196 | 144 | +84 | 1276 | 1756 |
| Fila B: Beber poción | 16-336 (320) | 144 | +252 | 1444 (75,2 %) | 1924 (80,2 %) |
| Fila B: Cancelar (F2-F4) | 16-336 (320) | 96 | +252 | 1444 | 1924 |
| Fila B: Terminar turno / Lanzar / Confirmar | 360-1064 (704) | 144 | +252 | 1444 | 1924 |
| Fila B: estado "X está pensando…" (F6, no es botón) | 16-1064 | 96 | +252 | — | — |

Separaciones: entre Beber poción y Terminar turno 24; de Beber poción a la fila A, **48** (156→180 menos el centrado del secundario, 132→180); entre chips 16; entre Cancelar y Lanzar 24. Todo ≥ 24 alrededor de Beber poción.

Chip de objetivo (196x144): sigilo 48 + nombre 26 (recorte con "…") arriba; ♥ vida 24 y 💧 maná 24 debajo; ✓ y marco dorado grueso si está elegido; al 45 % si no es válido (tocarlo muestra el motivo como toast en Z4: "Bruno tiene Campo de fuerza"). Orden = orden de la rejilla de Z3. Con un solo válido se muestra **preseleccionado** (la fila A no desaparece: el jugador ve a quién ataca). Con cartas de área/vecinos, fila A muestra los afectados **no interactivos** con marco de elegido.

## 6. Dónde va cada cosa clave

### 6.1 Ficha de carta (Z4): cierra QA-V2-35-06
- La ficha es contenido de **Z4** (rect fijo, ancho 1048, x16), no un nodo del flujo. **Z5, Z6 y Z7 no cambian de rect** entre F1 y F2-F4 (criterio L-05).
- Al elegir una carta, Z4 pasa de "mazo/descarte/evento a escala" a **tres bloques apilados**: tira de chips mazo/descarte/evento (48 de alto, texto 22-24 con "Mazo 119 · Descarte 5 · Evento"), **ficha** (148: nombre 34 en 40 de línea, línea de tipo/elemento/coste efectivo 28 en 34, resumen de ≤ 2 líneas a 24 en 60, botón "Ver" 144x96 a la derecha) y **vista previa** (112: hasta 3 líneas a 28, ver A3 de `v03-ataque-defensa`), con 8 entre bloques. Total **324**.
- Cabe incluso en el caso más estrecho: Z4 de 6j a H=1920 mide 336 (≥ 324, sobran 12). 3j/4j/5j sobran más. Si un día Z4 < 324 la **ficha pierde el botón Ver y el resumen a 1 línea** (nunca encoge la mano).
- Mientras hay ficha, las cartas grandes del centro se ocultan (la tira da el recuento); al lanzar vuelven y el vuelo del hechizo cruza Z4.
- Mano con ficha: 5 cartas a 210 de ancho (paso 209 de 1048) → **visibles ≥ 150 px** en todas las fases y con 3-6 jugadores. Con n > 5 cartas el paso baja hasta un mínimo de 120 y, a partir de 8 cartas, la mano se desplaza horizontalmente (fuera del criterio; no hay que probarlo en v0.3).

### 6.2 Selector de objetivos
Ruta principal: **chips en fila A** (por debajo del 55 %). Ruta secundaria redundante: tocar el panel del rival en Z3 (≥ 144x144; no cuenta como "control de acción", ver pregunta 1). Resaltado:
- **Válidos** (los de `legal_actions` para esa carta): contorno lavanda 6 px pulsante (1 Hz) dentro del borde del panel + sigilo iluminado, en panel y en chip.
- **Elegido**: círculo rúnico girando alrededor del panel (sin superar 6 px fuera del rect: cabe en el hueco de 12) + marca de puntería + ✓ en el chip; línea de puntería de mi panel (Z5) al suyo.
- **No válido**: 45 %; el toque da el motivo en una línea (toast de Z4, 22-26 px, ≥ 1,5 s).
- Tocar otro válido cambia el elegido; tocar el elegido no lo quita.
- Con "Reducir animaciones": sin pulso ni giro; contorno estático + ✓ + marca (la información no se pierde).

### 6.3 Hoja de defensa "Defiéndete" (F5) sin tapar vida ni maná
Rect: x16-1064, **y de H-696 a H-16** (680 de alto), entre Z5 (termina en H-740; hueco de 44) y el borde inferior; cubre Z6 y Z7 pero **no Z5**. Anclada abajo: si hay menos contenido la hoja se acorta desde arriba y los botones no se mueven. Escrim ≤ 0,45 sobre Z1-Z4; **Z5 se eleva por encima del escrim**; tocar fuera no cierra.

Presupuesto vertical (suma 680): pad 16 · cabecera 96 · 8 · línea del hechizo 36 · 4 · consecuencia 72 (2 líneas a 28) · 8 · respuestas 268 (2 filas de 128 + 12) · 12 · botones 144 · pad 16.
- Cabecera: icono escudo 48 + "Defiéndete" (40) a la izquierda; **anillo del temporizador de defensa 96x96** a la derecha (x 952-1048) con cifras a 40.
- Línea del hechizo: "Bruno lanza Fire Arrow · Contra ti" (28).
- Consecuencia: "Si recibes el golpe: …" (28, icono ⚠), texto de la tabla de Game Designer.
- Respuestas: cada una 512x128 (2 columnas; 1 sola respuesta = 1048x128): miniatura de carta 70x96, nombre (26), efecto en 1-2 líneas (22) y coste (22). No pagables al 45 % con el motivo; las seleccionadas con marco dorado + ✓. Hasta 4 visibles; la 5.ª y siguientes con desplazamiento vertical y un indicador "+N" (caso raro).
- Botones (banda de 144, x 32-1048): **Beber poción** x32-312 (280, solo si es legal) · 24 · **Recibir el golpe** x336-656 (320, secundario grande) · 24 · **Defender** x680-1048 (368, principal). Centros a y = H-104 (94,6 % a 1920; 95,7 % a 2400). Sin Beber poción, los otros dos no se mueven.
- Mi vida y maná: **en Z5, no se repiten en la hoja** (se retira la línea "Tu vida · Tu maná" de v0.2 en este flujo para no gastar 40 px; Z5 se lee a 30 px y por encima del escrim).
- Z4 muestra la carta del hechizo (escala ≤ (Z4 alto - 56)/337, p. ej. 0,83 en 6j a 1920) con "Bruno → tú" debajo; el panel de Bruno (Z3) lleva borde carmesí.

### 6.4 Temporizadores (visualmente distintos)
| | Turno | Defensa |
|---|---|---|
| Posición | Z1, fila 2 (y 152-184), arriba | Cabecera de la hoja, **abajo** |
| Forma | **barra** horizontal 32 de alto: icono reloj de arena 32 (x128), barra x172-880 (708 px) que se vacía de derecha a izquierda, cifras "0:24" a 28 px alineadas a la derecha (x892-1064) | **anillo segmentado** de 96 con cifras "18" a 40 en el centro |
| Color | oro `COL_ACCENT`; ≤10 s ámbar + pulso 1 Hz; ≤5 s carmesí + ⚠ + pulso 2 Hz | plata-acero; ≤5 s carmesí + ⚠ |
| Icono | reloj de arena (⏸ en pausa) | escudo |
| Redundancia | el borde de Terminar turno se vacía con él | el borde de Recibir el golpe se vacía con él |
Con "Sin límite": en su lugar el texto "Sin límite" (22-24) en el mismo sitio. En un prompt de mi turno el reloj de turno sigue en Z1; en uno causado por un rival, el anillo en la cabecera de la hoja.

### 6.5 Registro y menú
- **Registro:** Z2 (192-280), 2 líneas a 26; la franja entera es zona táctil (88 de alto; ≥ 96 no exigible: no es acción frecuente). Desplegado: panel de x16-1064 desde y192 hasta **H-872** (856 a 1920, 1336 a 2400) con 34 por línea, z por debajo de la hoja; botón "Cerrar" de 96 de alto en su borde inferior (excepción de "registro" al 30 %). Mientras está abierto, F3 sigue siendo operable por los chips (por eso hay chips). **No pausa los relojes.**
- **Menú:** botón 96x96 en Z1 (x16, y48). Abre un panel centrado x48-1032 con "Seguir" principal (144), Ajustes, Cómo se juega, Salir (96, separación 16), anclado desde 30 % de H hacia abajo. **Pausa ambos relojes** (decisión de `v03-ataque-defensa` §4.3).

## 7. Esquemas ASCII por fase (6 jugadores, 1080x1920; cifras = y lógica; `|` = x16 a x1064)

### F1 Mi turno, sin selección
```
  0 +[Menu]------ Tu turno -----------------+   48-144 banner (40 px)
152 |[hourglass] [=========bar======]  0:24 |   152-184 reloj de turno
192 | Registro (2 lineas)                    |   192-280
288 | [Bruno][Cira ][Dario]                  |   rivales 341x200
500 | [Elena][Fabio][ --- ]                  |   ...fin 700
712 |  [Mazo] [Descarte] [Evento]            |   Z4 712-1048 (336)
    |   119     5                            |
1060|==[ Ana  V10 P0 M1 C5 ]=================|   Z5 1060-1180 (en oro)
1204| [ Intercambiar 96 ] [ Descartar 96 ]   |   fila A  centro 1276
1372| [ Beber pocion ] [  Terminar turno  ]  |   fila B  centro 1444
1528|  .--.  .--.  .--.  .--.  .--.          |   Z7 mano 210x294
    | |    ||    ||    ||    ||    |         |   (1528-1888)
```
Oculto: chips de objetivo, ficha, preview, hoja. Terminar turno es principal (gema, 144) solo si no queda jugable; si no, secundario de 144.

### F2 Carta elegida, sin objetivo (p. ej. un artefacto)
```
712 | Mazo 119 . Descarte 5 . Evento    (48)|   tira
768 | FICHA  Ice Shield          [ Ver ]    |   148
    |  Coste 2 - Defensa - Hielo            |
    |  resumen 2 lineas                     |
924 | PREVIEW  3 lineas a 28                |   112
1060| Z5 mi panel                            |
1204|                                       |   fila A vacia
1372| [ Cancelar 96 ]  [ ==== LANZAR ==== ]  |   fila B
1528| mano: la elegida elevada 36 px         |
```
### F3 Eligiendo objetivo (carta con objetivo de mago)
```
 288| [Bruno ~lavanda~][Cira 45%][Dario ~lav~|   Z3: validos con contorno
    | [Elena (o) runico = elegido][Fabio 45%]|   elegido con circulo runico
712 | tira + FICHA + PREVIEW (324)          |   "Fire Arrow -> Elena: pierde 1 de vida
    |                                       |    (si nadie responde). Coste: 1 de mana."
1204| [Bru][Cir 45%][Dar][Ele ✓][Fab 45%]    |   chips 196x144, centro 1276
1372| [ Cancelar ]  [ ===== LANZAR ===== ]   |   Lanzar deshabilitado ("Elige objetivo") si no hay elegido
1528| mano igual, misma altura que en F1     |
```
### F4 Confirmando / pagando
Igual que F2 con: ficha muestra "Elige 1 carta de hielo para pagar (0/1)"; las cartas pagables de la mano se marcan; fila B = Cancelar | **Confirmar** (principal, deshabilitado hasta k = N). Fila A vacía.

### F5 Defensa
```
  0 +[Menu]-- ¡Bruno te ataca! ------------+   banner carmesi + "Bruno lanza Fire Arrow"
152 |  (reloj de turno oculto o ⏸)           |
288 | [Bruno BORDE CARMESI][Cira 60%]...     |
712 |        [carta del hechizo -> tu]       |   Z4
1060|==[ Ana  V10 M1  (sobre el escrim) ]====|   Z5 VISIBLE
1224| +-- Defiéndete          (anillo 96: 18)+   hoja 1224-1904 (680)
    | | Bruno lanza Fire Arrow . Contra ti    |
    | | ⚠ Si recibes el golpe: pierdes 1 de   |
    | |   vida.                               |
    | | [Magic Shield 512x128][Frozen B. 45%] |
    | | [Beber pocion][Recibir golpe][DEFENDER]|  centro y 1816
1904| +---------------------------------------+
```
(La hoja empieza siempre por debajo de Z5: 1224 > 1180.)

### F6 Esperando a un bot
```
  0 +[Menu]------ Turno de Bruno (sigilo) --+   reloj de turno oculto
288 | [Bruno ORO + hourglass][Cira]...       |
1060|==[ Ana ]===============================|
1204| Ultima jugada: Bruno -> Cira IMPACTO -2|   fila A, solo lectura
1372|      Bruno esta pensando...  (⟳)       |   fila B, no es boton; Beber pocion solo si es legal
1528| mano sin marcos de jugable; tocar = ver ficha en Z4
```
Si el bot puede responder a **mi** hechizo: banner "Bruno puede responder…", reloj de turno Z1 en ⏸, estado "en proceso" en fila B.

### F7 Prompt obligatorio
Cuatro tipos (todos con el temporizador que toque, ver `v03-ataque-defensa` §4.3):
1. **De botones** (Mana Focus, Elixir, Magic Cap, maná insuficiente, Visit, informativos): la **misma hoja de F5** con alto por contenido (≤ 680; Mana Focus ≈ 542, Elixir ≈ 636), botones en la banda de 144 con la opción afirmativa a la derecha. Texto: cabecera con título + anillo; selector -/+ de 96x96 y cifra a 44.
2. **Descarte / elegir carta** (necesitan la mano): **banda de 320 sobre Z6 (H-728 a H-408), la mano (Z7) queda libre y tocable**. Contenido: cabecera 96 (título "Descarta N", anillo de 72), contador "k/N" (28), botón Confirmar principal 144 en x360-1064, y centro a H-476 (75 % a 1920). Z5 visible.
3. **Elegir magos** (`choose_targets`): hoja completa con los **chips de §5** (144) y Confirmar principal; el selector de F3 se reutiliza.
4. **Maná insuficiente con poción**: hoja del tipo 1 con Beber poción a la izquierda resaltado (⚠ y color).
Los prompts se encolan de uno en uno (T16) con su plazo propio.

### F8 Fin de partida y eliminado
- **Eliminado** (espectador): banner carmesí fijo "Has sido eliminado" en Z1; Z6 y Z7 desaparecen; en su lugar, una línea "La partida sigue entre los bots" (28) en Z6 y **"Ver resultado"** principal (144, x16-1064... a ancho 704 en x360-1064, centro y H-104). Z3/Z4 siguen animándose.
- **Fin:** pantalla completa (sin Z1-Z7): título de fantasía 56 con el ganador, lista de magos (fila de 96, nombre 30, motivo/pociones 24), y abajo **"Jugar otra vez"** principal 144 (y H-288 a H-144, centro H-216) y **"Menú principal"** secundario 96 (y H-128 a H-32), separación 16; fondo oscurecido, contenido siempre sobre panel.

## 8. Variantes por número de jugadores (qué cambia)

Solo cambian Z3 y Z4; Z1, Z2, Z5, Z6, Z7 y la hoja son idénticos (criterio L-05).
- **3 jugadores:** 2 paneles de 518x200; Z4 de 548 (H=1920): cartas del centro a escala 1,0 (241x337); en F2/F3 la ficha y la vista previa se anclan arriba de Z4 y sobran ~224 px libres para efectos.
- **4 jugadores:** 3 paneles de 341x200 en una fila; Z4 igual que 3j.
- **5 jugadores:** 2x2 de 518x160 (stats en una fila); Z4 de 416; cartas a escala 1,0.
- **6 jugadores:** 3x2 de 341x200; Z4 de 336 (el caso límite): cartas a escala **0,83** (200x280), tira+ficha+preview = 324 (cabe con 12 de margen).
- **Confusiones detectadas y resueltas:** (a) la ficha empujaba la mano (QA-V2-35-06) → overlay en Z4; (b) fuera de mi turno había 4 botones grises → se ocultan; (c) "Beber poción" a todo el ancho parecía la acción principal → 320 de ancho, secundario, a la izquierda; (d) la hoja de reacción de v0.2 tapaba la banda de acciones → ahora cubre Z6-Z7 completos y es solo para decidir; (e) no se veía qué rivales eran objetivo → chips y contornos.

## 9. Verificación numérica de §3.3 (LINEAMIENTOS) y criterios de aceptación

### 9.1 Los ocho criterios de §3.3, comprobados sobre este diseño
| # | Criterio | Cálculo |
|---|---|---|
| 1 | Pulgar bajo el 55 % | 55 % = **1056** (H=1920) y **1320** (H=2400). Controles de acción más altos: chips de objetivo y Intercambiar/Descartar, centro 1276 (66,5 %) y 1756 (73,2 %); Beber poción, Terminar turno, Lanzar, Confirmar, Cancelar: centro 1444 (75,2 %) y 1924 (80,2 %); botones de la hoja: centro H-104 (94,6 %/95,7 %). Más del 30 % (y ≥ 576/720): solo Menú (y 48-144), registro (192-280, Cerrar) y los **paneles de rival como zona táctil secundaria** (y 288-700; ver pregunta 1) quedan por encima |
| 2 | Un solo principal | Tabla §4: F1 (Terminar turno, solo si no queda jugable), F2 Lanzar, F3 Lanzar, F4 Confirmar, F5 Defender, F7 Confirmar/afirmativa, F8 Ver resultado / Jugar otra vez: 1 por fase |
| 3 | Nada que no aplique | F6 y F8: 0 botones de turno; F2-F4: Intercambiar/Descartar/Terminar turno no existen |
| 4 | Tamaños | Principal 144 (Terminar turno/Lanzar/Confirmar/Defender/Jugar otra vez/Ver resultado) ≥ 144 ✓. Secundarios: Intercambiar/Descartar/Cancelar 96, Menú principal 96, Menú 96x96 ✓. Beber poción y Recibir el golpe 144 ✓. Separaciones: 24 entre botones de fila B, 48 entre bandas, 16 entre chips, 16 entre botones de fin; alrededor de Beber poción ≥ 24 ✓. Zona de panel de rival: mínima 341x200 y 518x160 (≥ 144x144) ✓; chip 196x144 ✓ |
| 5 | Toques | Lanzar con varios objetivos: carta, chip, Lanzar = 3; con un solo válido 2 (preseleccionado); sin objetivo 2 (carta, Lanzar); defensa 2 (respuesta, Defender; 1 si es solo Recibir el golpe); terminar turno 1 |
| 6 | Mano ≥ 150 con ficha | Carta 210, paso 209 con n = 5 (4·209 + 210 = 1046 ≤ 1048) ⇒ visibles 209 ≥ 150; el rect de Z7 es fijo (1528-1888) en todas las fases. A 720: 140 de ancho visible ≥ 100 (=150·2/3) ✓ |
| 7 | Pantallas, textos y muesca | Anchos: 1080 y 720 (×2/3 exacto); alturas lógicas 1920 y 2400 ⇒ las cuatro resoluciones son las dos tablas de §3.1. Z1 empieza controles en y 48 (≥ 48) ✓. Textos mínimos del diseño: 22 (chips, estado "+N", respuestas) ≥ 22 ✓. 6j: Z4 ≥ 324 ⇒ nada recorta; la suma de alturas fijas (184+8+88+8+412+12 + Z4 336 + 12 + 120 + 12 + 336 + 360 + 32) = 1920 ✓ (comprobada: 184+8=192; +88=280; +8=288; +412=700; +12=712; +336=1048; +12=1060; +120=1180; +12=1192; +336=1528; +360=1888; +32=1920) |
| 8 | Respuesta al toque / "en proceso" | Fila B y botones de la hoja tienen estado "en proceso" (círculo rúnico) sin cambiar de tamaño: se verifica por captura y árbol de nodos |

### 9.2 Criterios de aceptación para tests (resolución R ∈ {720x1280, 1080x1920, 1080x2400, 720x1600}; jugadores N ∈ {3, 4, 6}; rects en px de pantalla = lógico × (ancho / 1080); tolerancia ±1 px)
- **L-01 Zonas:** `Z1.y=0`, `Z2.y=192·s`, `Z3.y=288·s`; `Z5.y=(H_l-860)·s`, `Z6.y=(H_l-728)·s`, `Z7.y=(H_l-392)·s`, `Z7.bottom=(H_l-32)·s` con `H_l=1080·alto/ancho` y `s=ancho/1080`. Z3 alto = 200/332/412 según N∈{3-4, 5, 6}.
- **L-02 Sin solapes:** ningún par de rects de {Z1..Z7} (o de sus controles) se solapa, y todos están dentro del viewport; hueco Z4-Z5 y Z5-Z6 ≥ 12·s.
- **L-03 Pulgar:** en F1, F2, F3, F4 y F5, el centro de Beber poción, Terminar turno, Lanzar, Confirmar, Cancelar, Defender, Recibir el golpe, Intercambiar, Descartar y cada chip de objetivo cumple `centro.y ≥ 0,55·H`; y ningún control de acción con `centro.y < 0,30·H` excepto Menú, registro y paneles de rival en F3 (lista blanca).
- **L-04 Tamaños:** principales ≥ 144·s de alto; secundarios ≥ 96·s; Beber poción y Recibir el golpe ≥ 144·s; separación entre cualquier par de botones de una banda ≥ 16·s y ≥ 24·s alrededor de Beber poción; chips y paneles de rival en F3 con zona ≥ 144·s x 144·s.
- **L-05 Mano estable:** el rect de Z7 y los de Z5 y Z6 son **idénticos** (±1 px) en F1, F2, F3, F4, F6 (y Z5/Z7 en F5), para N=3, 4 y 6; con 5 cartas cada una mide ≥ 150·s de ancho visible. (Es el test de regresión de QA-V2-35-06.)
- **L-06 Ficha:** en F2/F3 el rect de la ficha está contenido en el rect de Z4 y su altura+preview+tira ≤ Z4 alto; con N=6 a H_l=1920, Z4 alto = 336·s y el contenido ≤ 324·s.
- **L-07 Un principal:** en cada fase F1-F8 hay ≤ 1 botón principal visible y habilitado (recorrer el árbol, contar `UiTheme.apply_primary`).
- **L-08 Nada que no aplique:** en F6 y F8, 0 botones de acciones de turno visibles (Jugar, Lanzar, Intercambiar, Descartar, Terminar turno); en F2-F4, Intercambiar/Descartar/Terminar turno no están en el árbol visible.
- **L-09 Posición del principal:** Lanzar, Confirmar y Terminar turno comparten rect (x 360·s a 1064·s, y `Z6.y+180·s` a `+324·s`); Beber poción comparte rect (x 16·s-336·s) en F1 y F6/F5 según corresponda.
- **L-10 Selector de objetivos:** en F3 el conjunto de chips/paneles con contorno de válido es exactamente el de `legal_actions` de la carta; los demás tienen opacidad 0,45; el elegido tiene ✓ y círculo rúnico; con un solo válido viene elegido; chips ordenados como la rejilla.
- **L-11 Hoja de defensa:** en F5, `hoja.top ≥ (Z5.bottom + 12·s)` (el rect de la hoja no interseca Z5), `hoja.bottom ≤ (H_l-16)·s`, alto ≤ 680·s; el Z5 está por encima del escrim; contiene `Defiéndete`, el anillo (96·s), la consecuencia, ≥ 1 respuesta cuando hay ventana, **Defender** y **Recibir el golpe**; los botones comparten y por encima del 55 %.
- **L-12 Relojes distintos:** el reloj de turno es una barra (en Z1, color oro) y el de defensa un anillo (en la hoja, color plata) con icono distinto y etiqueta distinta; nunca coexisten activos (turno ⏸ mientras corre el de defensa).
- **L-13 Textos:** ningún `Label`/`Button`/`RichTextLabel` visible en F1-F8 con `font_size < 22` a 1080 lógico (`UiTheme.FONT_MIN`); el test recorre el árbol y falla con el nombre del nodo. Margen: ningún control interactivo con `top < 48·s` salvo que `safe_area_top` lo suba.
- **L-14 Resoluciones y jugadores:** los criterios L-01 a L-13 se ejecutan en las cuatro resoluciones con N=3, 4 y 6; capturas por fase (F1-F8) de N=6 a 720x1280 y 1080x2400 y de N=3 a 720x1600 para revisión visual (Read), con el resultado registrado en `docs/qa/`.
- **L-15 Estados de la mesa:** con cualquier número de jugadores, el panel de rival no cambia de tamaño entre F1 y F3, y el contorno/círculo no excede 6·s fuera de su rect (cabe en los 12·s de separación).
- **L-16 Prompts:** descarte/elegir carta: la banda ocupa Z6 (`H_l-728` a `H_l-408`) y deja Z7 con al menos una carta tocable (el test simula el toque); Mana Focus/Elixir/Magic Cap/maná insuficiente: misma hoja que L-11.
- **L-17 Fin/eliminado:** en eliminado, Z6 y Z7 ocultos, "Ver resultado" principal a `y centro = (H_l-104)·s`; en el fin, "Jugar otra vez" 144·s y "Menú principal" 96·s, centros ≥ 0,55·H.

## 10. Preguntas abiertas (para Director/Producer; no bloquean la implementación)
1. **Paneles de rival como zona táctil por encima del 30 %.** §3.3-1 dice "ningún control de acción por encima del 30 % salvo Menú y registro", y §3.1 dice que Z3 se toca "en modo apuntar". Las dos frases chocan; lo resuelvo con la ruta principal en los chips (≥ 66 %) y los paneles como segunda ruta, fuera de la regla del 30 %. Recomiendo que el Director lo ratifique.
2. **Tamaño real del texto.** 22 px a 1080 ≈ 7 dp en un móvil de 360 dp de ancho, pequeño aunque cumple `FONT_MIN`. Los textos que realmente se leen en juego (preview, consecuencia, banner, cifras) van a 28-40; recomiendo que Technical Artist confirme si `FONT_MIN` debe subir a 24 (a 1080) antes de V3-17.
3. **Prompts de elegir cartas con mano visible** se resuelven con la banda de 320 sobre Z6 (§7, tipo 2), no con la hoja, para no tapar la mano; hace falta que el Developer confirme que el escrim se limita a Z1-Z4 en ese caso.
4. **Z4 con más de 5 cartas en la mano o más de 4 respuestas posibles** (caso raro) queda con desplazamiento; no se prueba en v0.3.

# Mesa para 5 y 6 jugadores y colocación de diálogos (V2-10)

Autor: Level Designer. Destino: V2-33 (implementa en `table_players.gd`, `table_center.gd`, `table_dialogs.gd`, `table_prompts.gd`) y su test de capturas. No cambia reglas. Origen: QA-V2-03-04 y QA-V2-03-05, lineamiento U3 / P9.

## 1. Convenciones y medidas

- Referencia 1080x1920. A 720x1280 todo escala x0,667 (stretch). Todas las cifras de este documento son px a 1080; entre paréntesis, 720.
- Densidad supuesta: 1080 px = 360 dp, así que 1 dp = 3 px a 1080 (2 px a 720). Toque mínimo 48 dp = **144 px (96 a 720)**.
- `UiTheme.FONT_MIN` = 22 (14,7 a 720), `FONT_BODY` 30 (20), icono de estado 48 (32).
- Observación (no la resuelvo yo): `BUTTON_MIN_H` 96 equivale a 32 dp, no a 48 dp; los botones reales miden ~105 px (35 dp). Si el Director quiere 48 dp estrictos en botones, harían falta 144 px y las acciones (Jugar/Intercambiar/Descartar/Terminar turno, Beber poción) ya no cabrían como hoy. Se deja fuera de V2-10; la exigencia de 48 dp de este documento aplica a **paneles de rival y botones de diálogo** (los diálogos usan 96 px de alto y están separados >= 16 px; ver §5.4). Escalar a Producer si se quiere unificar.
- Margen lateral 16 (11), separación entre paneles 12 (8).

## 2. Estado actual medido (capturas)

- 6j a 1080: 5 paneles en una sola fila, cada uno ~205x185 y girado (abanico); se tocan los bordes (el de Fabio llega al borde derecho). Texto de estadísticas 30 px, "Bot" ~20 px (<22), sin iconos de estado. Entre fila de rivales (y 385) y cartas del centro (y 500) hay ~115 px libres; entre el centro (y 880) y el panel propio (y 990) ~110 px. Hay espacio vertical de sobra: lo que falta es ancho, así que **se pasa a dos filas**.
- Un panel de rival lleva además miniaturas de artefactos equipados (visibles en `mesa-4j`).
- Diálogos (`v02-mana-focus-720x1280`, `v02-elixir-720x1280`): caja centrada de x 68 a 652 y y 435 a 845 (a 1080: y 650 a 1268) que tapa el panel propio (y 990-1090), las acciones y el centro. El prompt no muestra el maná propio.

## 3. Disposición de rivales

Se descartó un carrusel (obliga a deslizar para ver la vida del rival que va a atacar y oculta al que juega). Se usa **cuadrícula fija, sin giro** (rotación 0 a partir de 5 jugadores; con 3-4 se puede mantener el abanico actual con giro <= 2 grados).

| Jugadores | Rivales | Rejilla | Panel (1080) | Panel (720) | Zona de rivales (y) |
|---|---|---|---|---|---|
| 3-4 | 2-3 | 1 fila, hasta 3 columnas (se mantiene como hoy, panel 341 de ancho) | 341 x 200 | 227 x 133 | 200 a 400 |
| 5 | 4 | 2 columnas x 2 filas | 518 x 160 | 345 x 107 | 200 a 532 |
| 6 | 5 | 3 columnas x 2 filas (5 paneles; la 6a celda queda libre, ver abajo) | 341 x 200 | 227 x 133 | 200 a 612 |

- Orden: sentido del turno, izquierda a derecha y arriba a abajo, empezando por el siguiente rival al propio. En 6j la celda libre (fila 2, columna 3) se deja **vacía** (no se reutiliza para el registro).
- Ancho 6j: (1080 - 2x16 - 2x12) / 3 = 341. Ancho 5j: (1080 - 2x16 - 12) / 2 = 518.
- Cálculo de alto 6j: relleno 8 + fila nombre 48 + 2 filas de estadísticas 2x40 + fila de iconos 48 + separaciones 3x4 + relleno 8 = 204, redondeado a **200** (ajustar separaciones). Dos filas + hueco 12 = 412 (y 200 a 612).
- Cálculo de alto 5j: relleno 8 + nombre 48 + estadísticas en una sola fila 40 + iconos 48 + separaciones 8 + relleno 8 = 160; dos filas = 332 (y 200 a 532).

### 3.1 Contenido de un panel y prioridad

Filas (6j, 341 de ancho, interior 317):

1. Nombre (30 px, recorte con "..." a ~190 px) + icono Bot 48 (si es bot) + icono Turno 48 a la derecha. Los dos iconos caben: 190 + 48 + 48 + 8 = 294.
2. Vida y pociones (corazón + número, poción + número), 30 px.
3. Maná y cartas en mano, 30 px.
4. Fila de iconos de 48: hasta **6 casillas** (6x48 + 5x4 = 308 <= 317), ordenadas por prioridad: Congelado, Cegado, Campo de fuerza, Maldito, y después miniaturas de artefactos equipados (48x64 recortadas, sin texto). Si hay más de 6, la última casilla es "+n" a 22 px. Altura **reservada siempre** (aunque esté vacía) para que el panel no cambie de tamaño al congelarse.

En 5j la fila 2 y 3 se fusionan en una sola con 4 estadísticas (vida, pociones, maná, cartas; cada una ~110-120 px, total ~480 <= 494).

Prioridad si algún día falta espacio (formatos más estrechos que 9:16), se sacrifica de abajo arriba y nunca el primero:
1. Nombre. 2. Vida. 3. Quién tiene el turno. 4. Pociones (acercan a la victoria). 5. Iconos de estado. 6. Cartas en mano. 7. Maná. 8. Icono Bot. 9. Miniaturas de artefactos (pasan a "+n").
En 9:16 (720x1280 y 1080x1920) **no se sacrifica nada**: todo cabe con las medidas de arriba.

Los rótulos de texto "TURNO", "Congelado", "Cegado", "Escudo", "Bot" (17-20 px) **desaparecen** y los sustituyen los iconos `assets/ui/icon_*_48.png` (V2-19). Cada icono lleva `tooltip`/etiqueta accesible con el nombre; la silueta ya se diferencia sin color.

### 3.2 Toque

Panel de rival completo es objetivo de toque: 341x200 (227x133) y 518x160 (345x107) superan 144x144 (96x96) en 6j y en 5j. Los iconos de 48 **no** son objetivos de toque; al tocar el panel se muestra, en el sitio del registro, el texto de lo que significa cada estado (a >= 22 px). Separación entre paneles 12 (8): no hay solapes, el toque se asigna al panel cuya caja contiene el punto.

### 3.3 Jugador en turno y eliminados

- **En turno:** borde de 6 px `COL_ACCENT` + icono Turno 48 en la esquina superior derecha + fondo del panel un 15% más claro. Se distingue sin color (forma del icono y grosor del borde). No se agranda el panel (evita reflujo).
- **Eliminado:** el panel conserva su sitio (la rejilla no se reordena), se atenúa al 50%, aplica un rayado diagonal y la vida muestra "0" con la etiqueta "Eliminado" a 22 px (hasta que exista un icono propio; pedir a Art `icon_eliminado_48`, la calavera ya es "Maldito"). Sin toque de objetivo. El orden de turno lo salta.
- El propio jugador: borde y icono igual que en turno; su panel va debajo, a todo el ancho (y 990 a 1090).

## 4. Esquemas

Leyenda: `[N]` nombre, `V` vida, `P` poción, `M` maná, `C` cartas, `i` casilla de icono 48.

### 4.1 Seis jugadores, 1080x1920

```
x:0                                             1080
y0   +--[Menu]------------- Tu turno ----------+  0-100
y110 |  Registro .................................|  110-195
y200 +----------+ +----------+ +----------+
     |[Bru] B T| |[Cir]    T| |[Dar]    T|   fila 1: 341x200
     | V10 P0  | | V10 P0   | | V10 P0   |   cada una
     | M0  C5  | | M0  C5   | | M0  C5   |
     | i i i i | | i i i i  | | i i i i  |
y400 +----------+ +----------+ +----------+
y412 +----------+ +----------+  (libre 341x200)
     |[Ele]    T| |[Fab]    T|
     | V10 P0  | | V10 P0   |   fila 2
     | M0  C5  | | M0  C5   |
     | i i i i | | i i i i  |
y612 +----------+ +----------+
y624      [Mazo]    [Descarte]   [Evento]    cartas 193x270 (escala 0,8)
y894      etiquetas 30 px (y 894-934)
y934  (hueco 56)
y990 +==[ Ana  TURNO   V10 P0 M0 C5 ]=========+  panel propio 990-1090
y1100 [Jugar][Intercambiar][Descartar][Terminar]  1100-1195
y1205 [        Beber pocion (0/10)           ]  1205-1320
y1330 ---- zona de hoja inferior (1330-1920) ---
      mano de cartas (y 1450-1910)
```

### 4.2 Seis jugadores, 720x1280 (mismas proporciones x0,667)

```
y0    Menu ........ Tu turno              0-67
y73   Registro                            73-130
y133  [Bru][Cir][Dar]   3 paneles 227x133  133-266
y275  [Ele][Fab][ -- ]                    275-408
y416  Mazo  Descarte  Evento  (129x180)   416-596 (+etiquetas hasta 623)
y660  Panel propio                        660-727
y733  Acciones (4 botones)                733-797
y803  Beber pocion                        803-880
y887  hoja inferior (diálogos)            887-1280
```

### 4.3 Cinco jugadores, 1080x1920

```
y200 +-------------------+ +-------------------+
     |[Bru] B T          | |[Cir]           T  |  518x160
     | V10 P0 M0 C5      | | V10 P0 M0 C5      |
     | i i i i i i       | | i i i i i i       |
y360 +-------------------+ +-------------------+
y372 +-------------------+ +-------------------+
     |[Dar] ...          | |[Ele] ...          |
y532 +-------------------+ +-------------------+
y548  centro: cartas 202x285 (escala 0,85), etiquetas hasta y 873
y990  panel propio (igual que 6j)
```

A 720: dos filas de 345x107 (y 133 a 355), centro y 365.

## 5. Diálogos de prompt: dónde se colocan

Principio: **vida y maná propios (panel propio, y 990-1090 a 1080) y la fila de acciones deben verse siempre con un diálogo abierto.** La decisión depende de ellos (QA-V2-03-04). Se aprovecha que la mano no hace falta para la mayoría de decisiones y que abajo queda el alcance natural del pulgar.

### 5.1 Hoja inferior (bottom sheet)
Para: **Mana Focus, Elixir Transmutation, Magic Cap, maná insuficiente** y cualquier prompt de motor con botones.
- Ancla abajo: x 16 a 1064 (ancho 1048), alto máximo **560**, y de **1344 a 1904** (720: 896 a 1269, ancho 699). Cubre la mano (y 1330 en adelante), nunca el panel propio, ni las acciones, ni el botón Beber poción, ni los rivales ni el centro.
- El escrim (fondo oscuro) alfa <= 0,45 y **no oscurece** panel propio ni rivales (el panel propio se eleva por encima del escrim; así vida/maná se leen con su brillo normal). Tocar fuera no cierra (evita decisiones por error).
- Botones: alto 96 (64 a 720), ancho >= 144 (96); separación >= 16; **máximo dos filas de botones**, con "Confirmar" a la derecha (zona del pulgar) y la opción de no hacer nada a la izquierda. Selector -/+: botones de 96x96 y número a 44 px.
- Línea informativa fija en el diálogo (30 px): "Tu vida: V · Tu maná: M" (ya visibles en el panel propio; se repite porque QA vio que en Mana Focus no aparecía) y el resultado previsto, p. ej. "Daño: 3 → te quedan 10 de vida". Es información derivada, no cambia reglas.
- Presupuesto vertical de Mana Focus: relleno 24x2 + título 44 + texto 3 líneas x 40 + línea informativa 40 + selector 96 + fila de botones 96 + 4 separaciones 16 = ~452 <= 560. Elixir: título 44 + texto 40 + línea 40 + selector 96 + 2 filas de botones (Comprar vida | No comprar; debajo Beber poción) 208 + relleno 48 + separaciones 80 = ~556 <= 560 (justo; si el texto ocupa 2 líneas, bajar a una sola fila ancha de 3 botones de 328).
- Si el contenido supera 560, se recorta el texto explicativo, nunca se sube la hoja sobre el panel propio.

### 5.2 Banda central
Para el **descarte forzado**: necesita la mano visible y tocable, así que el diálogo es una banda de aviso (no modal sobre la mano): x 16 a 1064, y **640 a 900** (720: 427 a 600), con título "Descarta N carta(s)", contador "elegidas k/N" y botón Confirmar de 96 de alto. La mano y el panel propio quedan sin escrim y tocables. Cubre la zona del centro (mazo/descarte), que no se necesita para decidir.

### 5.3 Prompts informativos sin decisión (p. ej. "Nuevo evento")
Misma hoja inferior, con la carta a un máximo de 300 px de alto (no 760) para no exceder 560.

### 5.4 Nota sobre 48 dp en diálogos
96 px de alto (32 dp) en botones de diálogo es el mínimo de tema; con separación >= 16 px y ancho >= 328 el área efectiva supera 48 dp en el eje largo. Si el Director exige 144 de alto, la hoja de Elixir deja de caber (ver 5.1) y habría que pasar a pantalla completa; se deja como pregunta abierta, no se decide aquí.

## 6. Nota informativa: selector 0/1 por defecto (QA-V2-03-07)

Decisión de diseño informativa, sin tocar reglas:
- **Mana Focus** arranca en **0** (equivale a "No gastar"): no se gasta maná por un toque accidental, y "+" sube hasta min(maná, daño). Con maná 0 el "+" está desactivado y se explica en la línea informativa ("No tienes maná"). Se mantiene 0; no preseleccionar un valor para no gastar maná sin que el jugador lo decida. Mejora opcional: mostrar el efecto en vivo ("Gastas 2: recibes 1 de daño").
- **Elixir** arranca en **1** (mínimo útil de "Comprar vida"): con 0 el botón no haría nada. Se desactiva "Comprar vida" si maná < 2 por punto y se mantiene "Beber poción" / "No comprar" disponibles. Se mantiene 1.
- Es coherente que los dos valores iniciales sean distintos: cada uno es el valor más seguro de su prompt.
- Textos (texto en inglés del título de Magic Cap, "gorro") son de Narrative y de V2-16; no se tocan aquí.

## 7. Criterios de aceptación (V2-33 los convierte en test)

Capturas con `capture_v02.gd` a 1080x1920 y 720x1280, escenarios `mesa-6j`, `mesa-5j` y prompts (Mana Focus, Elixir, Magic Cap, maná insuficiente, descarte forzado) abiertos **con 6 jugadores**.

1. Ningún `Label`/`Button`/`ProgressBar` del panel de rival, panel propio, acciones y diálogos con `font_size` < 22 (FONT_MIN) a 1080; el test recorre el árbol y falla con el nombre del nodo.
2. Ningún panel recortado: el `get_global_rect()` de cada panel de rival está contenido en el viewport y en su celda de la rejilla; ningún par de paneles se solapa (separación >= 12 a 1080, >= 8 a 720); el contenido (hijos) está dentro del rect del panel.
3. Medidas mínimas del panel de rival: 6j >= 341x200 (227x133 a 720), 5j >= 518x160 (345x107); ambos >= 144x144 (96x96) en el tamaño de toque efectivo.
4. Rotación de paneles = 0 con >= 5 jugadores.
5. Los iconos de estado miden 48 (32 a 720) y la fila de iconos existe siempre (altura reservada) con 0 a 6 casillas; con un jugador congelado el panel no cambia de tamaño. No quedan rótulos "TURNO", "Congelado", "Cegado", "Escudo" ni "Bot" como `Label`.
6. Con 6j: el rect del panel propio no cambia respecto al de 3j y queda entre y 990-1090 (y 660-727 a 720); el centro (cartas + etiquetas) acaba en y <= 934 (623 a 720).
7. **Con cualquier diálogo abierto**, el rect del diálogo no interseca el rect del panel propio (vida y maná), de la fila de acciones ni del botón Beber poción (hoja inferior: borde superior >= 1344 a 1080; 896 a 720), y el panel propio no queda por debajo del escrim (z superior o escrim recortado). El texto de vida y maná del panel propio se lee en la captura.
8. Descarte forzado: el rect de la banda está en y 640-900 (427-600) y no cubre la mano (y >= 1330): al menos una carta de la mano es tocable (el test simula el toque).
9. Mana Focus y Elixir muestran maná y vida propios en la línea informativa; Mana Focus arranca en 0 y Elixir en 1; "+" desactivado si no hay maná suficiente.
10. Jugador en turno: borde 6 px acento + icono Turno visible en exactamente un panel; eliminado: panel atenuado, "Eliminado" visible, no seleccionable como objetivo, posición de la rejilla intacta.
11. Los botones de diálogo miden >= 96 de alto (64 a 720), separación >= 16 (11) y no hay más de dos filas de botones por diálogo.
12. Revisión visual con Read de las capturas a 720x1280 y a 1080x1920 con 6 jugadores (mesa y cada prompt); registrar resultado en `docs/qa/`.

## 8. Riesgos y pendientes

- Si el nombre más largo permitido no cabe en ~190 px (30 px de fuente, ~10 letras), hay que recortarlo con "..."; revisar con nombres de 12 caracteres.
- El icono "Eliminado" no existe (pedir a Art). Hasta entonces se usa texto.
- Reducir las cartas del centro al 80% (6j) afecta a `table_center.gd` y a la zona de toque del mazo (193x270 sigue >= 144).
- Pendiente medir en dispositivo real (densidad real) la equivalencia 48 dp = 144 px.

# Evaluación del diseño de la v0.3 (puerta V3-06)

Autor: Game Director. Fecha: 2026-10-15. Fuente de verdad: `docs/revision/requisitos-v03-usuario.md` (R1-R8). Mis lineamientos: `docs/revision/LINEAMIENTOS-v03.md`.

**Qué he visto:** los requisitos del usuario, mis lineamientos, V3-01 (`docs/diseno/v03-ataque-defensa.md`), V3-02 (`docs/TECNICO/v03-diseno.md`), V3-03/V3-22 (`docs/arte/propuesta-packs-v03.md`, `licencias.md`, `descarga-v03.md`, la carpeta `assets/ui_v03/`, `Preview.png` de Kenney y una prueba propia de los marcos `Double` teñidos de oro sobre `#1A1430` a escala 1 y 0,667 con filtro lineal y `nearest`, en el scratchpad), V3-04 (`docs/diseno/escenarios/mesa-zonas-v03.md`), V3-05 (`docs/qa/plan-pruebas-v03.md`), `docs/TAREAS.md`, `docs/DECISIONES.md` y `docs/ESCALADOS.md`.
**Qué no:** no hay código de la v0.3; no he jugado ni visto la mesa nueva. Todo lo de ergonomía es un juicio sobre medidas en papel. He ejecutado `bash tools/test.sh` como línea base antes de la oleada 1 (resultado en §8).

---

## 1. Veredicto

**APROBADA CON CONDICIONES.** El diseño cubre R1-R7 y, en su parte legible, R8. Los cinco documentos encajan entre sí en lo importante: tiempos 30/20 s, opciones, pausas, zonas, flujo A0-A6 y D0-D3, y los tests que lo comprueban. Encuentro 13 contradicciones, todas locales; ninguna obliga a rehacer un documento (§3). Las condiciones de §6 tienen dueño y tarea. **La oleada 1 queda autorizada ya**, en el orden del Producer (§7). Ninguna condición bloquea los lotes 1A-1G. Las erratas de diseño deben estar cerradas antes de la oleada 2.

## 2. Veredicto por entregable

| Entregable | Veredicto | Motivo principal |
|---|---|---|
| V3-01 Game Designer, ataque, defensa y temporizadores | **Aprobado con cambios** | Completo y verificable (CA-AT/DF/TM/VC, T1-T17). Aplica bien E11 y E12. Cambios: C1, C2, C5 y C11 (erratas de texto, sin cambiar reglas) |
| V3-02 Lead Programmer, diseño técnico | **Aprobado** (con la errata C6) | `MatchClock`/`ClockPolicy` puros, holds y contrapresión sin acoplar el motor, A1 opción (a), 5 módulos vacíos. La acción `TIMEOUT` del motor se aparta de mi §5 (decía "acciones normales"), pero lo acepto: el motor sigue sin leer el reloj, E11 vive en un solo sitio y el registro "Se acabó el tiempo" sale público (C4) |
| V3-03 / V3-22 Art, propuesta, descarga y licencias | **Aprobado con cambios** | Licencias verificadas contra los archivos, 0,47 MB, nada de SUPERHOTEX tocado. Cambios: faltan iconos para Menú, Registro, Recibir el golpe y Ajustes, y Lanzar no puede usar el mismo icono que el elemento rayo (C10). La nota de filtro `nearest` queda sustituida (C8) |
| V3-04 Level Designer, mesa por zonas | **Aprobado con cambios** | Cierra QA-V2-35-06 con bloques fijos y solo Z4 elástica. Pone el principal siempre en el mismo sitio y deja todo lo que se toca por debajo del 66 %. Las sumas de 6 jugadores a 1920 cuadran. Cambios: C7 y la regla de texto de D2 |
| V3-05 QA, plan de pruebas | **Aprobado** (con C12) | Cubre cada "hecho cuando", los 8 criterios de §3.3, L-01..L-17 y CA-*. Separa lo verificado de lo leído, prueba con mutantes y deja claro lo que no se puede automatizar. Vigilar el alcance (§5) |
| `docs/TAREAS.md` (Producer) | **Aprobado** | Lotes sin archivos compartidos, cadenas en serie bien identificadas, tests de v0.2 que cambian a propósito asignados (V3-15b). Ajustes de filas en la condición K2 |

### Cumplimiento de los requisitos del usuario
| Req. | Cubierto por | Estado |
|---|---|---|
| R1 solo contra bots, local completo | V3-16, hot-seat oculto (LP §4) | Sí |
| R2 identidad de magos y runas | packs aprobados, tema V3-30, fondo propio V3-33, efectos V3-34 | Sí en diseño; el estilo de los marcos se juzga en las capturas de O3 (K6) |
| R3 ergonomía | LD §3-§9, §3.3 medible, QA §3 con invariantes | Sí; el pulgar real solo se valida en v0.4 (limitación conocida) |
| R4 animaciones | LINEAMIENTOS §6, LP §2 (presupuesto 900/400 ms, holds) | Sí |
| R5 ataque | GD A0-A6, LD F3, labeler del LP | Sí |
| R6 defensa | GD D0-D3, LD F5 | Sí |
| R7 temporizadores | GD §4-§5, LP §1, E11/E12 | Sí; E15 provisional (§5) |
| R8 experiencia general | Ficha, vista previa, etiquetas, invariantes I1-I13 | Lo recibido, sí; el texto cortado sigue pendiente (E10) |

## 3. Contradicciones y corrección exigida

| # | Dónde | Qué choca | Corrección (manda lo indicado) | Dueño |
|---|---|---|---|---|
| C1 | GD D1b punto 4 y CA-DF-04 frente a LD §6.3 | GD repite "Tu vida · Tu maná" dentro de la hoja; LD la quita porque Z5 queda visible sobre el escrim | **Manda LD**: vida y maná solo en Z5, siempre visibles por encima del escrim. Cumple R6 y mi §3.1. GD reescribe D1b.4 y CA-DF-04 ("vida y maná propios visibles en Z5"). QA ya lo cubre con L-11 e I5 | GD |
| C2 | GD A3 ("Ve (dock…)") y LINEAMIENTOS §3.1 (Z6 con vista previa) frente a LD §6.1 | ¿La vista previa va en el dock o en Z4? | **Manda LD**: la vista previa va en Z4, debajo de la ficha. La fila A del dock es para los chips de objetivo. La vista previa solo se lee y Z4 es zona de lectura. Mi §3.1 queda corregido aquí. GD cambia "dock" por "Z4, bajo la ficha" | GD |
| C3 | LINEAMIENTOS §5, fila "Al vencer" y punto E11, frente a E11 del usuario (E16) | "Valor por defecto" o "como un bot" frente a "no se elige nada" | **Manda E11**: la tabla T1-T17 de GD §5 sustituye a mi fila. E16 queda resuelto | Director (hecho aquí) |
| C4 | LINEAMIENTOS §5 ("envía acciones normales") frente a LP §1.5 (acción `TIMEOUT`) | Hay una acción nueva del motor | **Acepto a LP**: es una decisión técnica suya, determinista, sin reloj en el motor y con la política en un solo sitio. Condición: `TIMEOUT` nunca sale en `legal_actions` y no la envían los bots. Ya lo exigen LP §1.10 y QA §2 | — |
| C5 | TAREAS V3-21 y V3-24 frente a GD §1.1 | TAREAS lista 6 etiquetas; GD define 9 (más `SIN EFECTO`, `MANÁ ±N` y `ELIMINADO`) | **Manda GD §1.1**: V3-21 y V3-24 cubren las 9 | Producer |
| C6 | LP §6 (`TableDock`, "Z5-Z6") frente a LD §3 | Z5 es mi panel, no el dock | `TableDock` es solo Z6; Z5 es de `table_players`. LP corrige la línea | LP |
| C7 | LD, cabecera ("Destino: V3-17 y V3-19 (Developers)") | Ids erróneos (V3-17 son shaders; V3-19, Conjunción) | Destino: V3-23, V3-24, V3-25 y V3-27 | Level Designer |
| C8 | `descarga-v03.md` §3 ("`nearest` y múltiplos enteros") frente a LP §7 (lineal) | Filtro de los marcos | **Manda LP**. Lo he comprobado: a escala 0,667, `nearest` deja trazos de grosor desigual y el lineal los deja uniformes; a 1080 dan lo mismo. Art anota en `descarga-v03.md` que la nota queda sustituida | Art |
| C9 | `licencias.md` ("Los SVG están sin modificar"; "algunos recoloreados") | Tras V3-13c, los iconos estarán adaptados | Texto: "adaptados: se eliminó el fondo y se recolorean en el juego". Ya está en la fila de V3-13c | Art |
| C10 | LINEAMIENTOS §2.7 frente a los 25 iconos descargados | No hay icono para Menú, Registro (pergamino), Recibir el golpe (mano abierta o flecha) ni Ajustes. `bolt-spell-cast` figura a la vez como "elemento rayo" y como candidato para Lanzar | Art añade como máximo 6 iconos **de los packs ya aprobados** (game-icons.net de los mismos autores o Kenney Game Icons CC0), con una fila por icono. Lanzar usa un icono propio, no el del rayo. La tabla icono→acción va en `estilo-v03.md` (V3-30) | Art (V3-13c) |
| C11 | GD §1.2 `B-TIEMPO-OPC` ("no se hizo nada") con T8-T10 | El jugador sí pierde vida al rechazar; el texto engaña. Además T14 y T15 no tienen banner ni línea de registro | Textos: maná insuficiente o Visit, `Se acabó el tiempo: pierdes {N} de vida`; resto de opcionales, `Se acabó el tiempo: no usas {C}`; T14/T15, `Se acabó el tiempo: se eligió al azar` y su línea de registro. Lo redacta GD y lo ajusta Narrative (V3-21); V3-14 añade la línea de registro | GD, V3-21, V3-14 |
| C12 | QA §0 propone archivos que no están en ninguna fila de TAREAS, y `test_puertas_v03_o1.gd` en lugar de `test_puerta_o1_v03.gd` | Archivos sin dueño | **Mandan los nombres de TAREAS.** El Producer añade a las filas de QA (V3-18, V3-27, V3-28, V3-36) los archivos nuevos que acepte (ver §5) | Producer |
| C13 | LINEAMIENTOS §2.4 y §2.7 ("sigilo = runa") frente a Art (6 cabezas de animal) | Emblemas de los magos | Decide el usuario; supuesto de trabajo en §5 | Usuario |

## 4. Decisiones sobre las preguntas abiertas

**D1. Paneles de rival por encima del 30 %. Ratificado.** La ruta principal para elegir objetivo son los **chips del dock** (fila A, centro al 66,5 %). Tocar el panel del rival en Z3 es una ruta secundaria redundante. Va en lista blanca de §3.3-1 solo en modo apuntar y en la redirección de Mirror Shield o Lightning. Así el pulgar nunca está obligado a subir, y quien mira el panel puede tocarlo directamente. **También ratifico el orden: el objetivo se elige primero en los chips y después, si se quiere, en los paneles**, con el mismo resaltado en ambos sitios y siempre sincronizados.

**D2. `FONT_MIN` se queda en 22 a 1080.** Subirlo a 24 en todo el juego reabre los tests de legibilidad de v0.2 y arriesga recortes en 6 jugadores a 720. No sabemos si aporta algo sin un celular real; eso se mide en v0.4. A cambio, el **texto que sirve para decidir** va a **≥ 24**: la línea de efecto de cada respuesta en la hoja (LD la tenía a 22), el nombre en el chip, el aviso del motivo de objetivo no válido, las etiquetas de resultado y los avisos de tiempo. Consecuencia, vista previa, banner y cifras ya superan esa cifra. QA lo comprueba con un caso nuevo de L-13 en V3-27. V3-30 mantiene `UiTheme.FONT_MIN = 22`.

**D3. Ratificado.** En el descarte o al elegir carta, el escrim cubre solo Z1-Z4. Z5 queda visible y Z7 se puede tocar, como pide L-16.

**D4. Aceptado.** Con más de 5 cartas o más de 4 respuestas se usa desplazamiento, con el indicador "+N". No es criterio de v0.3, pero QA saca **una** captura con 7 cartas y otra con 5 respuestas para que sepamos cómo se ve.

**G1-G4. Acepto los valores por defecto.** G1: con el menú abierto también esperan los bots, porque si no la partida avanza a escondidas. G2: `mana_focus` vencido gasta 0. G3: el descarte por límite de mano que crea un `END_TURN` por vencimiento se resuelve al azar dentro de la misma acción, sin plazo nuevo (coincide con la nota 4 de GD §5). G4: azar con el RNG del estado, provisional por E15.

**E16. Resuelto: manda E11** (C3).

**Estilo de los marcos (Kenney en pixel-art, PNG `Double`, filtro lineal). Encaja, con condiciones.** Teñidos de oro viejo sobre el violeta de panel, los marcos de esquinas escalonadas parecen metal grabado o piezas de un artefacto antiguo. Son sobrios y ese fondo de sobriedad es lo que pide R3 ("la claridad por encima de la decoración"). Por sí solos no dicen "runas". La identidad sale de la combinación: marco + icono y sigilo + Cinzel en los títulos + brillo de borde, círculo rúnico y fondo propio por código. Condiciones (K6): (a) en paneles de mago y hojas, las variantes con esquinas ornamentadas, no el cuadrado liso; (b) siempre teñidos (nunca blancos) y con el brillo de V3-17 en el jugador en turno; (c) trazo visible a 720×1280; (d) si en las capturas de O3 la mesa se lee como "retro pixel" en lugar de arcana, el respaldo es el borde doble por código (opción 1C-ii de Art, sin pack nuevo), no otro pack. El filtro lineal es decisión técnica del LP y la confirmo con la prueba visual (C8).

**Iconos: quitar el fondo negro y teñirlos (V3-13c). Aprobado** como lo describe la fila: script idempotente, una sola vez en origen, adaptación registrada (CC BY 3.0 lo permite indicándolo) y tinte con `self_modulate`. Añado los iconos que faltan (C10). **Decido** que añadir iconos sueltos de un pack que el usuario ya aprobó (mismo origen y licencia, máximo 6, con fila por icono) no necesita una aprobación nueva. Un pack o un autor nuevo, sí.

## 5. Supuestos de trabajo mientras el usuario no conteste

| Pregunta | Supuesto con el que se trabaja | Qué cambia si contesta otra cosa |
|---|---|---|
| **E15** azar al vencer en decisiones obligatorias | Se aplica por defecto: descarte forzado (T13), `choose_targets` (T14) y `choose_card` (T15) se eligen **al azar con el RNG del estado**, de forma reproducible y avisada en el registro. Aviso al usuario: **T14 y T15 amplían lo que se le preguntó** en E15 (solo el descarte); van en la misma pregunta. Los tests CA-VC-06/07 se marcan "provisional" | Solo el paso 3 de `TimeoutRules.resolve_prompt` y esos dos tests |
| **E10** sección 8 cortada | Termina en "Evitar interfaces confusas:". Se interpreta con lo que ya cubre el diseño: §3.2 de LINEAMIENTOS (mostrar solo lo de la fase), un solo principal, nada gris que no aplique, invariantes I1-I13 de QA | Si llega más texto, lo incorporo a LINEAMIENTOS y el Producer abre tareas. Nada se bloquea |
| **Emblemas** lobo, cuervo, búho, zorro, dragón y ciervo | Se trabaja con esos 6, **dentro de un anillo rúnico dibujado por código** para conservar el "sigilo de runa" de mis lineamientos, con un color fijo por asiento. Me parecen mejor que 6 runas: a 48 px las siluetas de animal se distinguen de un vistazo y las runas de game-icons se parecen entre sí. Además, la forma distingue sin depender del color | Cambiar los 6 SVG y su fila de licencia; el código no cambia (mapeo asiento→icono) |

## 6. Condiciones (dueño y tarea)

| # | Condición | Dueño | Tarea / momento | ¿Bloquea? |
|---|---|---|---|---|
| K1 | Errata de `v03-ataque-defensa.md`: C1, C2 y C11 (sin cambiar reglas) | Game Designer | junto con V3-19 (lote 1F) o una fila corta antes de 2A | Antes de V3-21 y V3-25 |
| K2 | Actualizar TAREAS: V3-21 y V3-24 con las 9 etiquetas (C5); V3-14 con la línea de registro de T14/T15 (C11); V3-13c con los iconos extra y `descarga-v03.md` (C8, C10); filas de QA con sus archivos (C12); V3-30 con `FONT_MIN` 22; V3-24, V3-25 y V3-27 con la regla ≥ 24 de D2; E16 resuelto | Producer | Antes de lanzar 1B (V3-13c) y 1C (V3-14) | Solo esos lotes |
| K3 | V3-13c ampliada: quitar fondos, registrar la adaptación, añadir hasta 6 iconos de packs aprobados (Menú, Registro, Recibir el golpe, Ajustes, Lanzar y uno de reserva), nota de filtro en `descarga-v03.md` | Art | V3-13c (lote 1B) | No |
| K4 | Errata C6 en `v03-diseno.md` §6 | Lead Programmer | V3-13b (lote 1A) | No |
| K5 | Errata C7 y textos de decisión ≥ 24 (D2) en `mesa-zonas-v03.md` §2 y §6.3 | Level Designer | Antes de V3-23 (lote 2B) | Antes de 2B |
| K6 | Marcos: variantes ornamentadas, teñidos, brillo de turno, trazo visible a 720; captura de comparación para el Director | Technical Artist | V3-30, que yo reviso en O3 (V3-36) | No |
| K7 | Recorte de alcance del plan de QA (§5): lo imprescindible bloquea la puerta, lo deseable no | QA / Producer | V3-18, V3-27, V3-28 | No |

## 7. Autorización de la oleada 1

**Autorizada, en el orden del Producer, sin cambios de orden:**
1A V3-13b + V3-10 → 1B V3-12 + V3-13c → 1C V3-14 + V3-11 → 1D V3-15 + V3-16 → 1E V3-15b + V3-17 → 1F V3-13 + V3-19 → 1G V3-18 (sola).

Notas:
- K2 se hace antes de 1B y 1C. En 1A no hace falta.
- V3-13 (1F) quita la caché estática de `ui_util.gd`, y la base de V3-12 restaura estáticos de `UiUtil`. Si la API estática cambia, V3-13 lo cuenta en su informe y el Producer abre una corrección en serie de `tests/base/nem_test.gd`. No se edita en paralelo.
- **V3-31 (Créditos) se puede adelantar al lote 2B**, junto a V3-23, como propone el Producer: no comparten archivos y la lista de iconos ya estará cerrada tras V3-13c. Autorizado.
- La oleada 2 necesita el visto bueno de O1 (V3-18) y K1 y K5 cerrados.

### Vigilancia del alcance
El plan de QA es bueno pero grande. **Imprescindible** (bloquea puertas): lo que piden los "hecho cuando" de TAREAS, §3.3, L-01..L-17, CA-*, la equivalencia A1 y 0 huérfanos. **Deseable** (no bloquea; se recorta si la suite pasa de ~3 min o la tarea se alarga): recorrido aleatorio de 20 semillas con invariantes, `sim.gd --check-view` y `--labels`, `tools/sim_lag.gd` con la mesa real y `test_secuencias_raras_v03.gd` más allá de Lightning+Mirror, Annihilation doble y eliminación en ventana. La Conjunción astral sigue siendo la última (E14).

## 8. Línea base

`bash tools/test.sh` ejecutado el 2026-10-15, antes de la oleada 1: **717/717 tests, 16 046 asserts, "All tests passed", código de salida 0**. Hay **3613 nodos huérfanos en 23 avisos**, la misma cifra base que da QA. V3-12 debe dejarla en 0. `git status` no muestra `override.cfg` ni archivos nuevos fuera de los documentos. La suite está en verde: 1A puede arrancar.

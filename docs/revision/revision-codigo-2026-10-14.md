# Revisión de calidad de código: v0.2 (2026-10-14)

Revisión hecha por la sesión principal, **sin subagentes**, sobre el commit `104a7c9` más los cambios posteriores (717/717 tests, 0 warnings). Objetivo: código basura, condiciones de carrera, duplicidades, malas prácticas y riesgos para el futuro que las puertas de QA no cubren (QA valida comportamiento; esto mira diseño y mantenimiento).

**Método:** mapa de tamaños; búsqueda de patrones de riesgo (azar o reloj fuera de `rng.gd`, estado `static var`, `await` y llamadas diferidas, conexiones de señales, bucles con tope); lectura completa de `local_session.gd` y lectura dirigida de motor, IA, mesa, bus de presentación, navegación y herramientas. Cada hallazgo indica **[verificado]** (lo ejecuté o reproduje) o **[por lectura]** (deducido del código, no ejecutado).

## Resumen

| Gravedad | Nº | Lo más importante |
|---|---|---|
| Alta | 4 | Acciones legales calculadas sobre vistas con información borrada (bug real); estado estático mutable en el motor; caché de texturas que nunca libera; `override.cfg` y candado frágiles en las herramientas |
| Media | 6 | Nodos huérfanos en los tests (3613); el bot deduce efectos leyendo el texto en inglés; dos implementaciones de "vista"; plazo de reacción durante "Pasa el dispositivo"; aislamiento de tests por disciplina; detalles de `LocalSession`; topes de bucle silenciosos |
| Baja | 8 | Código muerto y de maqueta en `src/`; archivos demasiado grandes; duplicación en scripts auxiliares; copias de estado repetidas |

Nada de esto rompe la v0.2 tal como se juega hoy en local con la configuración por defecto, salvo el bug A1 (raro). Varios hallazgos se vuelven **bloqueantes** en cuanto se aborde lo previsto: el modo en línea (A1, A2), la versión Web/móvil (A3) o mover el bot a un hilo (A2).

---

## Alta

### A1. Las acciones legales de la interfaz se calculan sobre una vista con información oculta borrada  **[verificado]**
- **Dónde:** `src/ui/controllers/action_options.gd:23` llama a `Game.legal_actions(p_view, p_pid)`. En una vista, `deck` siempre es `[]` y las manos ajenas están vacías (`Types.public_view`). Varias reglas leen precisamente eso:
  - `src/engine/effects/artifacts.gd:371` (`legal_twardowskys_mirror`): solo ofrece el espejo si el mazo **o** el descarte no están vacíos.
  - `src/engine/effects/support.gd:119` (`legal_magic_hand`): recorre la mano de la víctima.
- **Evidencia:** script de reproducción (mazo real con 137 cartas, descarte vacío, Twardowsky's Mirror en mesa): `legal_actions` sobre el estado = **1** acción de usar artefacto; sobre la vista que usa la UI = **0**; `Game.reduce` acepta la acción sin error. **La interfaz no ofrece una jugada legal.**
- **Es la misma causa raíz que el bug P7** (el bot se eliminaba solo porque su vista no tenía la mano de la víctima de Magic Hand). Hoy está tapada con parches puntuales (`ActionOptions._add_hidden_choices`, `Bot._hidden_choices`).
- **Impacto futuro:** en el modo en línea los clientes **solo** tienen vistas; cada regla nueva que mire información oculta repetirá el fallo.
- **Recomendación:** fijar un contrato explícito (Lead Programmer): o bien (a) `legal_actions` nunca lee información oculta y las reglas que la necesitan usan datos públicos (`deck_count`, `hand_count`) y la parte privada del jugador (`reveals`); o bien (b) la autoridad calcula las acciones legales y se las entrega al cliente. Para lo local, (a) con `deck_count` arregla el espejo en una línea. Añadir un test que compare `legal_actions(estado)` con `legal_actions(vista)` del propio jugador en miles de estados del simulador: deben coincidir.

### A2. Estado estático mutable dentro del motor y la IA  **[por lectura]**
- **Dónde:**
  - `src/engine/effects/defensive.gd:35` `static var _side_events`: canal lateral para el daño de Last Wish, porque el manejador de modificadores no recibe `events`. Lo vacían `Reactions.close()` (`reactions.gd:400-415`) y `Game.resolve_spell` (`game.gd:670`).
  - `src/engine/catalog.gd:14-15` (carga perezosa del catálogo), `src/engine/effects/registry.gd:21-24` (registro de efectos), `src/ai/bot_eval.gd:16` (caché de expresiones regulares).
- **Hoy funciona** porque Last Wish solo se activa dentro de `Reactions.close()`, que vacía el canal antes y después de cada paso.
- **Riesgos:**
  1. Rompe el contrato "motor puro: estado de entrada a estado de salida" de `ARQUITECTURA.md`.
  2. Si otra ruta dispara ese modificador fuera del cierre, sus eventos aparecen en una acción **posterior** que no tiene nada que ver.
  3. **No es seguro con hilos.** La propuesta P2(b) de rendimiento (decisión del bot en un hilo) correría sobre este estado compartido: carreras reales.
- **Recomendación:** pasar `events` a los manejadores de modificadores (la fila pendiente de `docs/CAMBIOS-TIPOS.md` sobre handlers `OP_CUSTOM`) y eliminar `_side_events`; cargar catálogo y registro una vez al arrancar, de forma explícita y de solo lectura después. Es requisito antes de P2(b) y antes del modo en línea.

### A3. La caché de texturas retiene todo para siempre  **[por lectura; la cifra de memoria es de `docs/rendimiento/v02-final.md`]**
- **Dónde:** `src/ui/ui_util.gd:19,24-36` `static var _tex_cache`: cada textura que se carga se guarda en un diccionario estático que nunca se vacía. Duplica la caché de recursos de Godot e impide que el motor libere memoria. Además, `tools/extract_assets.sh` fuerza importación sin compresión (`compress/mode=0`).
- **Impacto:** explica buena parte de los **~280-290 MB** de memoria de texturas medidos. Es el mayor riesgo para la versión Web que acabas de priorizar (E9) y para móvil.
- **Recomendación:** quitar la caché estática (o hacerla LRU con tope) y confiar en `ResourceLoader`; evaluar compresión con pérdida o VRAM para cartas; medir antes y después con `tests/perf/perf_final.gd`.

### A4. Herramientas de test frágiles  **[por lectura]**
- `tools/check_warnings.sh` crea **`override.cfg` en la raíz del proyecto** (convierte warnings en errores) y solo lo borra con `trap ... EXIT`.
  - Si el proceso muere con `kill -9` o por un tiempo agotado, el archivo **se queda** y cambia la configuración de todo lo que se ejecute después, incluidos el juego y el editor. QA ya tuvo que matar un `flock` colgado.
  - Aunque el script termine bien, mientras corre el archivo existe, y si abres el juego o el editor en ese momento se carga con esa configuración. El candado solo coordina los dos scripts, no el editor.
  - `override.cfg` **no está en `.gitignore`**: si se queda, puede acabar en un commit.
- `tools/test.sh` y `check_warnings.sh` abren el candado en `.godot/nem-godot.lock`. `.godot/` está ignorado, así que **en un clon nuevo no existe y los scripts fallan** hasta que Godot importe el proyecto.
- Envolver uno de los scripts en otro `flock` del mismo candado los cuelga (ya documentado como trampa en `ARQUITECTURA.md`).
- **Recomendación:** `mkdir -p .godot` antes del `exec`; añadir `override.cfg` a `.gitignore`; preferir pasar la configuración por línea de comandos o en un directorio temporal en vez de escribir en la raíz; `flock -w` con tiempo de espera.

---

## Media

### M1. El bot deduce los efectos leyendo el texto en inglés de las cartas  **[por lectura]**
- **Dónde:** `src/ai/bot_eval.gd:83-99` `profile()`: expresiones regulares sobre `def.text` ("lose[s]? (\\d+)\\{life\\}", "next to the target", "discard (\\d+) card"…). Y `est_damage()` (líneas ~103-140) reimplementa parte de la tubería de modificadores de `damage.gd`.
- **Riesgo:** si se corrige una frase de `data/cards.json` o cambia la tubería del motor, el bot pasa a estimar mal **sin que falle ningún test**. Es una segunda fuente de verdad de las reglas.
- **Recomendación:** datos estructurados por carta (daño, vecinos, descarte…) en el catálogo o en una tabla del bot con un test que la compare con el efecto real; o simular con el propio motor (`Game.reduce` sobre una copia) en vez de reimplementar.

### M2. Dos implementaciones de "vista": `Bot.make_view` y `Types.view_for`  **[por lectura]**
- `src/ai/bot.gd:85-116` hace copias **superficiales** (`duplicate(false)`): la vista del bot comparte con el estado real de la partida las banderas, artefactos, prompts pendientes, ventana de reacción y entradas del registro.
- Hoy la IA no escribe en esos datos (lo revisé), así que es seguro **por convención**. Pero cualquier escritura futura modificaría la partida real, y las reglas de qué es oculto pueden divergir entre las dos funciones.
- **Recomendación:** una sola función de vista en `Types` con un modo "solo lectura" barato, o congelar por test que `make_view` y `view_for` ocultan exactamente lo mismo.

### M3. Temporizador de reacción y reloj  **[por lectura]**
- En hot-seat con temporizador activado, la sesión fija el plazo en cuanto le toca decidir a un humano local (`local_session.gd:484-504`), **mientras la mesa muestra "Pasa el dispositivo"**. El siguiente jugador pierde parte de su tiempo pasando el celular. Por defecto el temporizador está desactivado, así que hoy no afecta.
- El plazo usa el reloj de pared (`Time.get_unix_time_from_system`, `local_session.gd:205`), que salta si el sistema ajusta la hora. En local, un reloj monótono (`Time.get_ticks_msec`) es más seguro; el de pared solo hace falta entre dispositivos (en línea).
- **Recomendación:** que la sesión no arranque el plazo hasta que la mesa confirme "Soy X" (o descontar ese tiempo), y usar reloj monótono en local.

### M4. Aislamiento de los tests  **[verificado en parte]**
- 25 archivos de tests modifican estado estático global: catálogo (`CardCatalog.set_defs`), registro de efectos, `UiNav.*`, `UiUtil.prefer_extra`/`extra_defs`, `CardInfo.summaries_path`/`settings_path`. Los que sustituyen catálogo y registro sí restauran en `after_each`, pero **por disciplina de cada archivo**: no hay un mecanismo común.
- Es la causa más probable del fallo intermitente que se vio una vez y no se reprodujo. Ya hubo dos efectos laterales reales: un test escribió en el `settings.cfg` real del usuario y otro dejó `resumenes_corruptos.json` en la carpeta de datos del juego (ambos corregidos).
- **Recomendación:** una clase base de test (o `pre_run`/`after_each` global de GUT) que restaure todos los estáticos; una ruta `user://` de pruebas separada para cualquier test que escriba ficheros.
- **Nodos sin liberar en los tests [verificado]:** GUT informa de **3613 nodos huérfanos** (23 avisos), casi todos en `tests/ui/test_ui_scenes.gd` (~2466) y `tests/ui/test_payment_text.gd` (~1146). Ya estaban en el commit `104a7c9` (misma cifra exacta, comprobado ejecutando ese commit en una copia aparte), así que no los introdujo la limpieza. Las puertas de QA no los vieron porque solo miraban la línea de "Passing". No rompen nada hoy, pero inflan la memoria de la suite y pueden ocultar fugas reales. Arreglo: `add_child_autofree`/`autofree` en las mesas y diálogos que esos tests crean, y que `tools/test.sh` falle si hay huérfanos.

### M5. Detalles de `LocalSession`  **[por lectura]**
- `_enqueue` (`local_session.gd:224-236`): si la cola pasa de `MAX_QUEUE_STEPS` (64), el resto se **descarta en silencio** (`_queue.clear()`). Debería al menos avisar.
- `start()` no reinicia `_queue`, `_validated`, `_bot_turn_key`, `_bot_turn_count`, `_deadline_owner` ni `history`. Hoy da igual porque cada partida crea una sesión nueva, pero `start()` se documenta como "arranca (o reinicia)".
- `history` se recorta con `slice` en cada acción una vez pasa de 400: coste O(n) por acción.
- `src/ui/screens/table.gd` `bind_session` no desconecta una sesión anterior: dos llamadas dejarían dos sesiones con sus temporizadores moviendo la misma mesa. Hoy no ocurre porque "Jugar otra vez" cambia de escena.
- El archivo tiene 523 líneas (deuda ya registrada en `ARQUITECTURA.md`).

### M6. Topes de bucle silenciosos en el motor  **[por lectura]**
- `Game.MAX_LOOP` (2000) protege varios bucles (`game.gd:103, 237, 300, 336`; `reactions.gd:402`). Si se alcanza, la partida sigue con un estado a medias y **no queda rastro**. Las simulaciones dan 0 violaciones, así que hoy no ocurre.
- **Recomendación:** registrar una entrada de log o devolver error al alcanzar un tope, y que `tools/sim.gd` lo cuente.

---

## Baja (higiene)

- **B1. Código muerto y de maqueta en `src/`:** `UiNav.make_fake_session` (no la usa nadie); `FakeSession` y `FakeState` en `src/ui/fixtures/` (solo para tests y para `demo_when_empty` de `table.gd`); `lobby.gd` (148 líneas) y los manejadores ocultos de "Crear sala/Unirse" en `main_menu.gd`; 6 *stubs* de red de 3 líneas (`src/net/*`, `online_session.gd`). Mover lo de pruebas a `tests/` y dejar los stubs documentados como v0.4.
- **B2. Instrumentación en producción:** `profile_refresh`/`refresh_profile` en `table.gd`, que está justo en su tope de 400 líneas.
- **B3. Archivos demasiado grandes:** `types.gd` (1492 líneas: constantes, constructores, validación, vistas y normalización), `game.gd` (1158), `strings.gd` (793). `table.gd` está en el tope de 400, así que cualquier cambio en la cáscara obliga a rodeos.
- **B4. Duplicación en scripts auxiliares:** 10 scripts de captura (771 líneas), 7 de rendimiento (1128) y 22 archivos que montan partidas a mano con `Game.new_game`. Un helper común reduciría mantenimiento. Además, **~515 KB de datos crudos de rendimiento versionados** en `tests/perf/*.txt`.
- **B5. Copias de estado repetidas:** `Types.view_for` copia el estado entero dos veces (`public_view` y `compose_view`); `Game.reduce` hace otra copia profunda por acción. Es parte del coste medido por acción.
- **B6. Bus de presentación:** `PresentationBus._process` corre cada fotograma aunque no haya nada en cola; `FeedbackLayer._log_bottom` localiza el registro buscando entre los nodos hermanos (acoplamiento a la estructura del árbol).
- **B7. `set_view` con `await ready`** (`table.gd`): varias llamadas antes de que el nodo esté listo crean varias corrutinas que refrescan la mesa varias veces.
- **B8. Documentación:** 47 documentos. Ya hubo textos obsoletos (QA-V2-27-04, QA-V2-35-07); conviene revisarlos al cerrar cada versión.

---

## Lo que está bien (para no perderlo)
- `Game.reduce` copia en profundidad antes de tocar nada y devuelve el estado original intacto si hay error; `resolve_spell` es atómico (deshace estado y eventos si el efecto falla).
- Las vistas que recibe la interfaz son copias: la UI no puede corromper la partida.
- Determinismo real: azar solo por `rng.gd` con semilla en el estado; ni `randi()` ni reloj en `src/engine/` ni en `src/ai/` (comprobado por búsqueda).
- 717 tests, warnings tratados como errores, tests de mutación en las puertas de QA, simulador reproducible.
- Separación motor / sesión / interfaz clara y documentada.

## Orden recomendado (encaja con E8 "pulir local" y E9 "Web en red local")
1. **A4** (minutos): `mkdir -p .godot`, `override.cfg` en `.gitignore`, `flock -w`.
2. **A1**: arreglo de una línea para el espejo con `deck_count` + test de equivalencia estado/vista; decidir el contrato antes de B1.
3. **A3**: caché de texturas y compresión, imprescindible para la versión Web.
4. **M4**: base de tests que restaura estáticos (elimina la fuente de fallos intermitentes).
5. **M3**: pausar el plazo durante "Pasa el dispositivo"; reloj monótono en local.
6. **A2 y M1-M2** antes de mover el bot a un hilo o empezar el modo en línea.
7. Bajas: cuando se toque cada archivo.

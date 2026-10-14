# Arquitectura (Godot + Firebase)

Este documento **sustituye** a las secciones 4.3, 4.4 y 5 de `REQUERIMIENTOS.md` (que proponían React). Las reglas del juego (secciones 1-3) y los requerimientos funcionales RF1-RF11 siguen vigentes.

## Decisiones tomadas (2026-10-12)

- **Motor de juego y UI:** Godot 4 (la última 4.x estable, fijada en `docs/VERSIONES.md` al instalarla), lenguaje **GDScript** con tipado estático.
- **Plataformas:** Android (APK) y Web (exportación HTML5 alojada en Firebase Hosting). Linux de escritorio solo para desarrollo.
- **Modos de juego:** local (hot-seat + bots, sin conexión) y **multijugador en línea** con salas por código.
- **Backend:** Firebase plan **Spark (gratis)**: Authentication anónima + **Realtime Database** + Hosting. Sin Cloud Functions.
- **Autoridad:** el **celular anfitrión** (quien crea la sala) ejecuta el motor y publica el estado. Los demás solo envían acciones.
- **Tests:** GUT (Godot Unit Test) en modo headless; reglas de seguridad probadas con Firebase Emulator Suite.

## Estructura del proyecto

```
not-enough-mana/
├─ project.godot
├─ addons/
│  ├─ gut/                       # tests
│  └─ godot-firebase/            # cliente Firebase (o capa propia, ver "Red")
├─ assets/
│  ├─ cards/001.webp … 165.webp  # NO versionar (copyright)
│  ├─ cardback.webp
│  └─ bg/
├─ data/cards.json               # catálogo (T3)
├─ data/card_summaries_es.json   # resúmenes en español de las cartas: NO versionado (ver «Ficha de carta»)
├─ src/
│  ├─ engine/                    # motor PURO: sin nodos, sin red, sin UI
│  │  ├─ types.gd                # ⭐ contrato: constantes, enums, constructores de estado/acciones
│  │  ├─ rng.gd                  # PRNG de 32 bits (mulberry32) con estado entero serializable
│  │  ├─ deck.gd  game.gd  damage.gd  reactions.gd
│  │  └─ effects/registry.gd fire.gd ice.gd electric.gd defensive.gd support.gd curses.gd artifacts.gd events.gd
│  ├─ ai/bot.gd
│  ├─ net/                       # todo lo de Firebase
│  │  ├─ firebase_client.gd      # auth anónima, lectura/escritura/escucha RTDB
│  │  ├─ room_service.gd         # crear/unirse/salir de sala, lobby
│  │  ├─ host_authority.gd       # anfitrión: consume acciones, ejecuta motor, publica estado
│  │  ├─ client_session.gd       # cliente: escucha estado, envía acciones
│  │  └─ state_view.gd           # divide el estado en público / privado por jugador
│  ├─ session/                   # capa común local/en línea que usa la UI
│  │  ├─ game_session.gd         # interfaz: submit_action(), signal state_changed
│  │  ├─ local_session.gd        # hot-seat + bots
│  │  └─ online_session.gd       # envuelve host_authority / client_session
│  └─ ui/                        # escenas .tscn y scripts de interfaz
│     ├─ screens/ (+ table/)     # pantallas y módulos de la mesa
│     ├─ components/             # PlayerPanel, HandView, CardView, GameOverSummary...
│     ├─ controllers/            # lógica de UI pura: ActionOptions, PlayFlow, ReactionRelevance, MatchSummary
│     ├─ presentation/           # bus de feedback: PresentationBus, FeedbackMapper, FeedbackQueue, FeedbackLayer
│     └─ ui_theme.gd strings.gd strings_ayuda.gd card_info.gd ui_nav.gd
├─ firebase/
│  ├─ firebase.json  .firebaserc
│  └─ database.rules.json
├─ tests/                        # GUT: tests/engine, tests/ai, tests/net, tests/integration
├─ tools/extract_assets.sh       # PDF → WebP
└─ export_presets.cfg            # Android + Web
```

## Motor (puro y serializable)

- El estado es un **`Dictionary` con solo tipos JSON** (int, float, String, bool, Array, Dictionary). Así se guarda en Firebase sin conversión.
- `Game.reduce(state: Dictionary, action: Dictionary) -> Dictionary` devuelve `{ "state": nuevo_estado, "error": "" | código, "events": [...] }`. Nunca muta la entrada (`duplicate(true)`).
- Azar: solo vía `rng.gd` con estado `int` < 2^32 guardado en el estado. **No** usar `randi()` ni `RandomNumberGenerator` (su estado de 64 bits pierde precisión en JSON).
- Las acciones son `Dictionary` con `"type"` (constantes en `types.gd`) y `"player"`.
- `Game.legal_actions(state, player_id) -> Array` para UI y bots.
- Efectos: `registry.gd` mapea `id de carta → Callable` con una línea por carta.

## Red (Firebase Realtime Database, autoridad en el anfitrión)

```
/rooms/{CODE}
  meta        { hostUid, status: "lobby"|"playing"|"finished", config, protocolVersion, createdAt }
  members/{uid} { name, age, birthMonth, seat, connected, lastSeen }
  public      estado sin información oculta: manos como número de cartas, mazo como número, rev
  private/{uid} { hand: [...], reveal: {...}, rev }    # Magic Hand, Twardowsky's Mirror, etc.
  actions/{pushId} { uid, action, baseRev, ts }       # los clientes escriben; el anfitrión consume y borra
  host/{...}  estado completo para que el anfitrión pueda reconectar (solo lo lee el anfitrión)
```

- **Reglas de seguridad:** `public` y `meta` los leen los miembros; `private/{uid}` solo ese uid y el anfitrión; `actions` lo escribe cualquier miembro con `uid == auth.uid`; todo lo demás solo el anfitrión.
- Los clientes nunca calculan reglas: muestran `public` + su `private` y envían acciones. Validación siempre en el anfitrión.
- Los bots de una partida en línea se ejecutan en el anfitrión.
- Ventana de reacción en línea: **temporizador obligatorio** (15 s por defecto) que el anfitrión hace cumplir; si vence, cuenta como "Pasar".
- Desconexión del anfitrión: la partida se pausa y se reanuda cuando vuelve (desde `host/`). Migración de anfitrión: fuera del MVP.
- Cliente Firebase: probar primero el addon **GodotFirebase** (REST + streaming) en Android **y** Web. Si en Web falla el streaming, usar en Web `JavaScriptBridge` + Firebase JS SDK detrás de la misma interfaz `firebase_client.gd`.

## Presentación: bus de feedback y refresh de la mesa (V2-04, 2026-10-13)

Detalle y contrato exacto: `docs/TECNICO/bus-presentacion.md`.

- **Log numerado.** Cada entrada de `state.log` tiene `log_seq:int` (1, 2, 3…, creciente en la partida). Lo asigna el motor con `Types.stamp_log_seq` al guardar las entradas de cada acción (incluidas las que un handler `OP_CUSTOM` escribe directamente en el log). `Types.last_log_seq(entries)` da el último.
- **Contrato de `GameSession.state_changed(rev, events)`:** `events` = entradas de log con `log_seq` mayor que la última emitida, ordenadas por `log_seq`, visibles para algún jugador local; cada entrada se emite una vez. Local y anfitrión las leen de `state.log`; el cliente en línea, del log de su vista compuesta (`compose_view` + `normalize_state`). Nunca se usan los `events` de `reduce` para presentar. `start()` emite `[]` con base en el `last_log_seq` inicial. Si el cliente en línea pierde más de 50 entradas por un salto de `rev`, emite lo que hay y el bus lo cuenta como `gap`. Contrato completo en `docs/CONTRATO-TIPOS.md` (sección «Log numerado») y `docs/TECNICO/bus-presentacion.md` §2-§3.
- **Bus de presentación** (`src/ui/presentation/`): `PresentationBus` (Node) se suscribe a `state_changed`, deduplica por `log_seq`, traduce con `FeedbackMapper` (1 item por `LOG_DAMAGE`, `LOG_HEAL`, `LOG_MANA_CHANGED`, `LOG_POTION`, `LOG_ELIMINATED`, `LOG_CARD_PLAYED`) y encola en `FeedbackQueue` (carriles por panel que se solapan, carril `banner` exclusivo; duración ≥ 1 s). La ingesta no bloquea: no crea nodos ni espera; los items arrancan en `_process`. Visibilidad: se filtra al ingerir (algún jugador local) y al arrancar (el que mira ahora); la cola se bloquea mientras se muestra "Pasa el dispositivo".
- **Capa visual** `FeedbackLayer`: overlay sobre los paneles y bajo los modales; dibuja números flotantes y destellos en el rect del panel (`TableScreen.panel_for(pid)`), sin tocar los nodos del panel. No conoce la sesión ni el estado.
- **Refresh de la mesa: incremental en paneles y centro (decisión de `bus-presentacion.md` §5; implementado en V2-22).** La mano y la barra de modo no cambian en v0.2. Estado real (verificado en `src/`):
  1. Rivales: `TablePlayers.rebuild_rivals()` compara la clave de ids (`_rival_key`) y, si no cambia, hace `update_player` sobre el mapa `pid -> PlayerPanel`; si cambia (hot-seat), reconstruye. El ancho no reconstruye: `_layout_rivals` ajusta el ancho de los paneles.
  2. `PlayerPanel.update_player`: firma (`JSON.stringify(player)` + `is_turn`, `pickable`, `picked`); sin `_rebuild()` si no cambia.
  3. Centro: `TableCenter.rebuild()` guarda una firma (mazo, tamaño del descarte, `iid` de la carta de arriba, `iid` del evento, ancho); sin cambios, no se toca.
  4. `TablePlayers.panel_for(pid) -> Control` (panel propio si `pid == viewer_id`, si no el rival; `null` si no existe); `TableScreen.panel_for` la reenvía. `TableFeedback` la pasa como `FeedbackLayer.anchor_provider`.
  5. Rendimiento (V2-27): turno activo p95 25,8-29,0 ms (base 54,8-56,7), 0 refrescos por feedback. La meta de 16 ms es de V2-34; solo si no se alcanza, siguiente paso = pool de `CardView`.
- **Estado de implementación (2026-10-13).** Implementados y probados: numeración del log, eventos de sesión desde el log (`LocalSession._last_log_seq`), `FeedbackMapper`, `FeedbackQueue`, `PresentationBus` (V2-14), `FeedbackLayer` (`src/ui/presentation/feedback_layer.gd`), `TableFeedback` (`src/ui/screens/table/table_feedback.gd`: crea el bus y la capa, enlaza `PresentationBus.bind` a la sesión y lo bloquea mientras se ve "Pasa el dispositivo"), `panel_for` y el refresh incremental (V2-22). Defecto abierto de presentación (QA-V2-27-01): los números flotantes se dibujan sobre las cifras del panel; V2-33.

## Constantes del tema de UI (`src/ui/ui_theme.gd`, V2-18)

Referencia: viewport base de 1080 px de ancho (a 720 px todo escala x0,667 por el stretch). Los números **no se repiten** en las pantallas: se leen de `UiTheme`.

| Constante | Valor | Uso |
|---|---|---|
| `FONT_MIN` | 22 | tamaño mínimo de cualquier texto (etiquetas secundarias) |
| `FONT_BODY` / `FONT_BUTTON` / `FONT_FLOAT` | 30 / 32 / 44 | cuerpo, botón, números flotantes de daño/curación |
| `BUTTON_MIN_H` / `BUTTON_MARGIN_V` | 96 / 30 | alto mínimo de botón; el tema lo garantiza con márgenes, y en `custom_minimum_size.y` para botones con icono |
| `BUTTON_PRIMARY_H` / `VARIATION_PRIMARY` | 144 / `"ButtonPrimary"` | acción principal (48 dp): fondo violeta, borde dorado de `PRIMARY_BORDER_W` = 4 |
| `BUTTON_GAP_MIN` / `BUTTON_GAP_POTION` | 16 / 24 | separación mínima entre botones adyacentes y alrededor de "Beber poción" |
| `COL_DAMAGE_FX` / `COL_HEAL_FX`, `GLYPH_DAMAGE` / `GLYPH_HEAL` | color + ▼ / ▲ | feedback no solo por color; shaders `SHADER_PANEL_FLASH` y `SHADER_FLOAT_NUMBER` |

Abierto: QA-V2-21-05 (etiquetas de `player_panel.gd` de 17 px por debajo de `FONT_MIN`), V2-33.

## Mesa de juego: división en módulos (V2-05, implementada en V2-13)

Detalle completo, tabla función -> módulo, reparto de ids de diálogo y orden de refactorización: `docs/TECNICO/division-table.md` (léelo antes de tocar la mesa). Resumen:

- **Cáscara** `src/ui/screens/table.gd` (`class_name TableScreen`, **400 líneas: en el límite**): señales `action_requested` y `play_again_requested`, API pública (`bind_session`, `set_view`, `options`, `show_toast`, `begin_play`, `pending_notices`, `is_game_over_shown`), composición de la UI en orden fijo, `refresh()` orquestador, servicios (acción, toast, zoom) y un bloque `## Compatibilidad: tests y capturas` **congelado** (miembros privados que usan los tests y capturas actuales; no se le añaden miembros).
- **Patrón `TableContext`** (`table/table_context.gd`, `RefCounted`): estado leído o escrito por dos o más módulos (`view`, `viewer_id`, `opts`, `selected`, `pay_table`, `flow_data`, `pflow`, `step`, `shown_prompt_id`, `local_ids`), consultas puras sobre la vista (`me()`, `allowed()`, `flow_targets()`, `my_prompts()`...), servicios delegados (`ctx.refresh()`, `ctx.emit_action(a)`, `ctx.toast(t)`, `ctx.zoom(c, d)`) y una referencia tipada a cada módulo. Los módulos son `Node` hijos de la mesa con base `TableModule` (`setup(ctx)` y `on_dialog_button(id) -> bool`); se llaman entre sí **solo a través de `ctx`** (`ctx.flow.advance()`, `ctx.dialogs.close()`), de forma síncrona y tipada; ninguno toca widgets de otro ni llama a la cáscara salvo por `ctx.screen` para operaciones de nodo (tween, árbol). Nadie guarda copias de `ctx.view`/`ctx.selected` entre llamadas. El estado de un solo dueño vive en su módulo. Tests nuevos: usar `t.ctx` y los módulos (`t.ctx.hand`, `t.ctx.mode_bar`...), no privados de la cáscara.
- **Límite de tamaño: 400 líneas por archivo de la mesa** (`table.gd` y cada módulo de `table/`); lo vigila `tests/qa/test_puerta_o3.gd`. `table.gd` está **exactamente en 400: congelado**, no puede crecer; todo lo nuevo va en un módulo de `table/` (el mayor es `table_flow.gd`, 246). Un cambio en la cáscara obliga a sacar código antes. La regla es de la mesa; la sesión no está sujeta (ver «Deuda técnica»).
- **Módulos** (`src/ui/screens/table/`; líneas reales a 2026-10-13):

| Archivo | Clase | Responsabilidad | Líneas |
|---|---|---|---|
| `table_module.gd` / `table_context.gd` | `TableModule` / `TableContext` | Base y estado compartido | 16 / 244 |
| `table_sync.gd` | `TableSync` | Sesión, hot-seat, "Pasa el dispositivo", errores | 107 |
| `table_menu.gd` | `TableMenu` | Barra superior, menú de partida, denuncia de Curse of Rules, "Cómo se juega" (`HelpScreen` superpuesta) | 103 |
| `table_players.gd` | `TablePlayers` | Abanico de rivales y panel propio, `panel_for`, refresco incremental | 176 |
| `table_center.gd` | `TableCenter` | Mazo, descarte, evento activo (con firma) | 92 |
| `table_hand.gd` | `TableHand` | Mano, selección, pista, ficha (`CardInfo`) y motivo de "no jugable" | 165 |
| `table_actions.gd` | `TableActions` | Jugar / Intercambiar / Descartar / Terminar, poción | 185 |
| `table_flow.gd` | `TableFlow` | Máquina de jugada: objetivos, opciones, elección de cartas, artefactos | 246 |
| `table_mode_bar.gd` | `TableModeBar` | Barra de modo: pago y elección de cartas | 187 |
| `table_dialogs.gd` | `TableDialogs` | Anfitrión de `PromptDialog` y despacho de botones | 195 |
| `table_prompts.gd` | `TablePrompts` | Ventana de reacción y prompts del motor | 236 |
| `table_notices.gd` | `TableNotices` | Avisos modales (eventos, revelaciones) | 118 |
| `table_game_over.gd` | `TableGameOver` | Fin de partida y "Jugar otra vez"; resumen con `MatchSummary` + `GameOverSummary` | 142 |
| `table_feedback.gd` | `TableFeedback` | Consumidor del bus de presentación (crea `PresentationBus` y `FeedbackLayer`) | 46 |

- **Quién edita qué** (ítem v0.2 -> archivos; tabla completa en `division-table.md` §6): V2-22 feedback = cáscara, `table_feedback.gd` (nuevo), `table_players.gd`, `table_center.gd`, `player_panel.gd`; V2-23 = `table_hand.gd`; V2-24 = `table_mode_bar.gd`; V2-25 = `table_prompts.gd` (poco, el auto-pase va en la sesión); V2-26 = `table_game_over.gd` y `table_notices.gd` + `game_over_summary.gd` nuevo; V2-29 = `table_actions.gd`, `table_sync.gd`, `table_prompts.gd`; V2-30 = `table_menu.gd`, `table_notices.gd`; V2-33 (en solitario) = los módulos de vista. Dos tareas en paralelo no pueden compartir archivo; la cáscara solo la edita V2-22 en su oleada.
- **`table_context.gd` y `table_dialogs.gd` son compartidos y están congelados** (QA verificó en la puerta O3 que no se tocaron; las líneas de la tabla son las de hoy, no un permiso para crecer). Un estado nuevo va en el módulo dueño; si de verdad hace falta en `ctx`, se pide en el informe y el Producer abre una mini-tarea en serie. Un id de botón nuevo lo declara su módulo dueño (`on_dialog_button`); `table_dialogs.gd` no se toca.
- **Orden fijo** (no cambiar sin revisión): construcción de widgets (`division-table.md` §4.1) y `refresh()` (§4.2).

## Preferencia de reacción (V2-06, decisión de `docs/TECNICO/preferencia-reaccion-y-resumen.md`)

Ninguna regla cambia. Estado de implementación: **implementado (V2-25)** en local; en línea queda para B1 (`src/net/*` y `online_session.gd` son stubs de 3 líneas).

- **Almacenamiento:** `user://settings.cfg` (`ConfigFile` de `settings.gd`), sección `reactions`, clave `notify` = `"affecting"` (por defecto) o `"all"`. Una por dispositivo; no va en `config` del motor ni en `types.gd`. `Settings.load_reaction_notify()` / `save_reaction_notify()` estáticas (valor desconocido = `affecting`); la pantalla de Ajustes alterna el valor y `_on_back` carga el archivo antes de escribir, así que conserva las demás claves.
- **Tabla `ReactionRelevance`** (`src/ui/controllers/reaction_relevance.gd`, pura y estática, una regla explícita por cada carta jugable, carta sin regla = avisar): `affects(view, pid)`, `receivers(view, spell)` y `auto_pass_action(view, local_ids, mode)`. Es política de interfaz, por eso es código y no un campo de `cards.json`; un test recorre el catálogo (T25-A).
- **Auto-pase en `LocalSession`, no en la mesa:** propiedad `reaction_notify` (por defecto de la clase `"all"` = comportamiento anterior; `UiNav` le asigna `Settings.load_reaction_notify()`, cuyo valor por defecto es `"affecting"`). En `_apply`, antes de emitir, `_auto_pass_loop()` (acotado) envía `PASS_REACTION` (`by = "auto_pass"` en `history`) por los humanos locales a los que `affects` da `false`, sobre `Types.public_view(state)`. Nunca se auto-pasa un `PROMPT_*` pendiente ni a un bot. El estado intermedio no se emite: no hay parpadeo de "Pasa el dispositivo" ni plazo para quien se auto-pasa. Para el motor es un pase normal. En línea (B1) la misma función pura la llama `ClientSession`; el anfitrión no conoce preferencias. Probado en `tests/ui/test_reaction_relevance.gd` y `tests/session/test_local_auto_pass.gd`.

## Datos de resumen de fin por jugador (V2-06)

El resumen de fin sale del **estado**, no del log (el log se recorta). Seis campos aditivos por jugador, públicos, definidos en `Types.make_player`, `normalize_state` y `validate_state` (`SCHEMA_VERSION` no cambia): `turns_played`, `eliminated_order`, `eliminated_turn`, `eliminated_by`, `eliminated_card`, `eliminated_cause` (+ constantes `ELIM_CAUSE_DAMAGE`, `ELIM_CAUSE_HP_LOSS`, `ELIM_CAUSE_MANA_SHORTFALL`). Significado, valores iniciales y reglas: `docs/CONTRATO-TIPOS.md` (sección «Campos del resumen de fin»).

- **Estado de implementación: implementado (V2-26).** El motor los rellena: `Damage.eliminate(state, pid, reason, events, by, card_id, cause)` escribe `eliminated_order` (= `rev` + 1 de la acción en curso), `eliminated_turn`, `eliminated_by`, `eliminated_card` y `eliminated_cause` (la tubería de daño pasa `ELIM_CAUSE_DAMAGE`, la pérdida directa `ELIM_CAUSE_HP_LOSS`, la rama de maná insuficiente `ELIM_CAUSE_MANA_SHORTFALL`; Too Much Mana y concesión lo dejan vacío); `_start_turn` de `game.gd` incrementa `turns_played`. `MatchSummary.build(view, local_ids)` (`src/ui/controllers/match_summary.gd`, estática, solo lee la vista) alimenta `GameOverSummary` (`src/ui/components/game_over_summary.gd`) desde `TableGameOver`.
- Como son estado público, sirven igual en local, en línea, en reconexión y al reabrir "Ver resultado". La clasificación usa `eliminated_order` descendente (mismo valor = eliminación simultánea); las causas, `eliminated_reason` + `eliminated_cause` + `eliminated_by`/`eliminated_card` (reglas en `preferencia-reaccion-y-resumen.md` §2.2).

## Ficha de carta, resúmenes en español y ayuda (V2-23, V2-30)

- **`CardInfo`** (`src/ui/card_info.gd`): ficha de la carta seleccionada. La parte estática (`evaluate` / `for_hand`) calcula si es jugable (acciones legales de `ActionOptions`), su coste efectivo (`Damage.card_cost`) y el motivo si no lo es, sin reimplementar reglas. Muestra nombre, maná, tipo, elemento, motivo, resumen y el botón "Ver" (zoom). La pista de pulsación larga se guarda en `user://settings.cfg` (`hold_hint_seen`).
- **Política de `data/card_summaries_es.json` (M19):** un resumen de una línea por carta en español, `id -> texto`. El archivo **no está versionado** (`.gitignore`) porque deriva del texto de las cartas (© SUPERHOTEX, uso personal). `CardInfo.summary(id)` lo carga una vez desde `res://data/card_summaries_es.json` (`CardInfo.summaries_path` para tests) y **nunca falla**: archivo ausente o inválido = cadena vacía, y la UI funciona igual sin la línea de resumen. Los tests de cobertura del catálogo (`tests/qa/test_puerta_o3.gd`) quedan `pending` si el archivo no está. Quien clone el repositorio debe recibirlo aparte, como `assets/cards/`.
- **Ayuda "Cómo se juega":** `HelpScreen` (`src/ui/screens/help_screen.gd`, 8 secciones con scroll) con los textos de `StringsAyuda` (`src/ui/strings_ayuda.gd`, estático, números tomados de la configuración, líneas de adaptación digital con prefijo `DIGITAL_TAG`). Se abre desde el menú principal (`UiNav.HELP`) y como superposición desde el menú de la partida (`TableMenu.open_help`), donde solo emite `back_pressed` y no toca el estado.

## Deuda técnica conocida

- **`src/session/local_session.gd` tiene 523 líneas** (QA-V2-27-06; eran 489 antes de P2, que añadió el reuso del `reduce` de validación del bot, el contador `reduce_calls` y `reuse_bot_reduce`). El límite de 400 es de la mesa; la sesión no está sujeta, pero reúne API de `GameSession`, `_apply`, auto-pase (`_auto_pass_loop`), eventos desde el log (`_new_log_entries`), temporizadores y cola de bots, y plazos de reacción. Propuesta cuando haya que tocarlo (p. ej. al conectar B1): extraer `_auto_pass_loop` y la cola de bots a un colaborador (`RefCounted`) sin cambiar `GameSession`. No se hace por ahora; no hay defecto asociado.
- **Candado de Godot (`.godot/nem-godot.lock`).** `tools/test.sh` y `tools/check_warnings.sh` toman el mismo candado (`exec 9>.godot/nem-godot.lock; flock 9`) para no correr a la vez (`check_warnings.sh` crea un `override.cfg` temporal que alteraría los tests). **Advertencia: no los envuelvas en otro `flock` sobre el mismo archivo** (p. ej. `flock .godot/nem-godot.lock bash tools/test.sh`): el `flock` interno espera a un candado que ya tiene el proceso padre y se queda colgado para siempre (reapareció en las puertas O2 y O3; también un `flock 9` huérfano de otra sesión bloquea `test.sh`). Ejecuta los scripts directamente; si se cuelgan, busca el proceso con `pgrep -af flock` y mátalo. Mejora pendiente: usar `flock -w <segundos>` o un candado reentrante (variable de entorno que indique "ya lo tengo") en ambos scripts.
- Otros defectos abiertos de la oleada 2/3: `docs/qa/bugs.md`.

## Exportación

- Android: APK firmado (debug para pruebas, release con keystore propio).
- Web: exportación **sin hilos** (thread support desactivado) para no necesitar cabeceras COOP/COEP en Hosting.
- Pantalla vertical (portrait) como diseño base: 1080×1920, stretch `canvas_items`, aspect `expand`.

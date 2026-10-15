# Arte técnico: tema, efectos y shaders

Responsable: Technical Artist. Renderizador **Compatibility** (WebGL2 / Android): solo `canvas_item`,
sin `hint_screen_texture`, compute, SDFGI ni nada de Forward+.

## Constantes de accesibilidad (`src/ui/ui_theme.gd`, V2-18)
Referencia: viewport 1080 px de ancho (a 720 todo escala x0.667 por stretch).

| Constante | Valor | Uso |
|---|---|---|
| `UiTheme.FONT_MIN` | 22 | Mínimo de cualquier texto (etiquetas secundarias, ProgressBar). Ningún texto por debajo. |
| `UiTheme.FONT_BODY` | 30 | Label / LineEdit (tema por defecto) |
| `UiTheme.FONT_BUTTON` | 32 | Button |
| `UiTheme.FONT_FLOAT` | 44 | Números flotantes |
| `UiTheme.BUTTON_MIN_H` | 96 | Alto mínimo de botón. Medido: botón de tema = 105 px. Para botones con icono/otra fuente, `custom_minimum_size.y = UiTheme.BUTTON_MIN_H`. |
| `UiTheme.BUTTON_MARGIN_V` | 30 | Margen vertical del StyleBox de botón |

Los Developer (V2-33) deben usar estas constantes en vez de números sueltos. Ojo: los `add_theme_font_size_override`
en componentes con valores < 22 siguen existiendo; migrarlos a `FONT_MIN` es trabajo de los Developer.

## Botones de acción principal y secundarios (V2-40, decisión del Director, `docs/TAREAS.md` §2.1)
Densidad: 1080 px = 360 dp (1 dp = 3 px a 1080, 2 px a 720). El stretch del viewport escala todo igual, así que las
constantes se expresan a 1080 y a 720 salen solas (144 -> 96, 96 -> 64).

| Constante / helper | Valor | Uso |
|---|---|---|
| `UiTheme.BUTTON_PRIMARY_H` | 144 (96 a 720) | Alto mínimo de un botón de acción principal (48 dp). |
| `UiTheme.BUTTON_MIN_H` | 96 (64 a 720) | Alto mínimo del resto de botones. |
| `UiTheme.VARIATION_PRIMARY` | `"ButtonPrimary"` | Variación de tema (base `Button`) con apariencia propia (ver "Aspecto del botón principal"). |
| `UiTheme.apply_primary(button)` | - | Pone la variación y `custom_minimum_size.y = max(actual, BUTTON_PRIMARY_H)`; no toca el ancho. |
| `UiTheme.BUTTON_GAP_MIN` / `BUTTON_GAP_POTION` | 16 / 24 | Separación mínima entre botones adyacentes / alrededor de Beber poción. |

Uso: `UiTheme.apply_primary(btn)` en botones nuevos o (V2-33) existentes; en secundarios,
`btn.custom_minimum_size.y = UiTheme.BUTTON_MIN_H`. V2-40 no redimensiona ningún botón existente; lo hace V2-33.

**Principales (>= `BUTTON_PRIMARY_H`):**
- Beber poción (mesa y ventana de reacción).
- Reacción: Pasar y cada respuesta.
- Fila de acciones del turno: Jugar y Terminar turno; la fila entera (con Intercambiar y Descartar) toma la misma altura.
- Confirmar en: pago, descarte forzado, elegir cartas y hoja inferior de prompts (Mana Focus, Elixir, Magic Cap, maná insuficiente).
- Botón principal de pantallas fuera de la mesa: Jugar local, Empezar partida, Jugar otra vez, Soy X.

**Secundarios (>= `BUTTON_MIN_H`):** Menú, Cancelar, "Ver", "Ver resultado", Ajustes, Cómo se juega, selector -/+ (96x96)
y botones de diálogo que no sean Confirmar.

**Separación:** >= 16 px (`BUTTON_GAP_MIN`) entre botones adyacentes y >= 24 px (`BUTTON_GAP_POTION`) entre Beber poción y
cualquier otro. V2-33 lo convierte en test; si con 6 jugadores a 720x1280 no cabe la fila de acciones a 144 px, se informa
al Director con capturas (no se baja el tamaño por cuenta propia). Se confirma en el móvil (M12).

### Aspecto del botón principal (QA-V2-27-02)
La variación `ButtonPrimary` ya no solo fija el alto: tiene fondo y borde propios, con el borde más grueso para no depender solo del color.

| Estado | Fondo | Borde | Texto | Contraste texto/fondo |
|---|---|---|---|---|
| normal | `COL_PRIMARY_BG` violeta vivo (.40,.20,.74) | dorado `COL_ACCENT`, 4 px | blanco | 7,6:1 |
| hover | `COL_PRIMARY_BG_HOVER` (.46,.26,.82) | blanco, 4 px | blanco | 5,6:1 |
| pressed | `COL_PRIMARY_BG_PRESSED` (.28,.14,.56) | dorado claro, 5 px | dorado | 6,6:1 |
| disabled | `COL_PRIMARY_BG_DISABLED` (.18,.15,.26) | dorado apagado, 3 px | `COL_MUTED` | 5,2:1 |

Un botón secundario (`Button`) queda violeta apagado (.22,.18,.36) con borde gris-violeta de 3 px. Todo el texto >= 4,5:1 (test `test_primary_text_contrast`).

**Jerarquía de estilos (de mayor a menor prioridad):** override de instancia (`add_theme_stylebox_override`) > variación `ButtonPrimary` > `Button`.
Por eso "Beber poción" de la mesa (`TableActions.drink_btn`) mantiene su verde y los colores de riesgo ámbar/naranja/rojo:
`build_drink_button()` y `apply_potion_risk()` ponen overrides de `normal`, `hover` y `pressed` en la instancia y la variación no los pisa
(test `test_primary_keeps_height_and_instance_override_wins`). Solo el estado `disabled` de `drink_btn` cae a la variación.
Otros botones con color propio deben seguir el mismo patrón (override de instancia), no tocar la variación.

### Nombres de nodo de los botones principales (V2-33, comprobados en el código)
| Módulo | Miembros / constantes |
|---|---|
| `TableActions` (`src/ui/screens/table/table_actions.gd`) | `play_btn`, `exchange_btn`, `discard_btn`, `end_btn` (fila `action_row`) y `drink_btn` (dentro de `drink_box`) |
| `TableModeBar` (`table_mode_bar.gd`) | `mode_confirm` (Confirmar de pago, descarte, elegir cartas) |
| `TableDialogs` (`table_dialogs.gd`) | `PRIMARY_IDS = ["p_focus", "p_elixir", "p_cap", "p_drink", "p_drink_free", "cards_ok"]`: ids de botón del diálogo que se dibujan como principales (`dialog.primary_ids`) |
| `ReactionPrompt` (`reaction_prompt.gd`) | `_drink_btn` (Beber poción, con riesgo vía `set_drink_risk`) y `_pass_btn` (Pasar) |
| Fuera de la mesa | `lobby._start_btn`, `pass_device_screen._button`, `TableGameOver.play_again_button`; "Jugar local" (`main_menu`) y "Empezar" (`local_setup`) son variables locales (`play_local`, `start`), sin miembro |

## Feedback de daño y curación
No depende solo del color: cada uno cambia **color, forma y glifo**.

| | Daño | Curación |
|---|---|---|
| Color | `COL_DAMAGE_FX` bermellón (1.0, .32, .12) | `COL_HEAL_FX` cian (.20, .85, .90) |
| Forma del panel | angular: esquinas rectas, borde grueso, rayado diagonal | redondeada: halo radial suave |
| Glifo | `GLYPH_DAMAGE` ▼ ("▼ -5") | `GLYPH_HEAL` ▲ ("▲ +3") |

API (V2-22 la cablea; no hay componentes tocados aquí):
- `UiTheme.make_flash_material(damage, rect_size)` -> `ShaderMaterial` (`shaders/panel_flash.gdshader`) para un `ColorRect`
  superpuesto al panel. Animar el uniform `amount` 0 -> 1 -> 0 con un `Tween` (>= 1 s visible).
  El `ColorRect` no tiene textura: hay que pasar su tamaño en `rect_size`.
- `UiTheme.flash_box(damage, alpha)` -> `StyleBoxFlat` equivalente sin shader (misma diferencia de forma).
- `UiTheme.float_text(amount, damage)` -> "▼ -5" / "▲ +3".
- Números flotantes: `Label` con `theme_type_variation = "FloatDamage"` o `"FloatHeal"` (fuente 44, contorno oscuro de 10 px
  + sombra: legible sobre cualquier fondo). Opcional `UiTheme.make_float_material()` (`shaders/floating_number.gdshader`:
  brillo vertical y uniform `fade` para el desvanecimiento). El contorno va por tema y no por shader porque un contorno por
  muestreo sangra entre glifos del atlas.

## Fuente de respaldo con símbolos (V2-P1, aplica `docs/rendimiento/v02-final.md` P1)
- **Qué:** `assets/fonts/DejaVuSans.ttf` (DejaVu Sans, 760 KB, copia sin modificar del paquete `fonts-dejavu-core`) y su licencia en
  `assets/fonts/LICENSE-DejaVu.txt`. Se añadió como **fuente de respaldo** (`fallbacks`) de la fuente del tema: `UiTheme.make_font()`
  devuelve un `FontVariation` sin `base_font` (= la fuente por defecto del motor, mismo aspecto) con DejaVu en `fallbacks`;
  `build()` lo pone como `default_font` y, además, como `normal/bold/italics/bold_italics_font` de `RichTextLabel`
  (con `default_font` en el tema Godot deja de usar la negrita sintética de su tema por defecto: se perdía el `[b]` del registro;
  el `embolden` 1,2 y la inclinación 0,2 reproducen la anterior; capturas idénticas píxel a píxel).
- **Licencia:** Bitstream Vera (la del paquete Debian `fonts-dejavu-core`, bloque `Files: *`): uso, copia, modificación y venta como parte de un
  paquete mayor permitidos; hay que **conservar el aviso de copyright y el texto de permiso** (va en `LICENSE-DejaVu.txt`) y, si se modifica
  la fuente, **renombrarla** (no se modifica). Los cambios propios de DejaVu son de dominio público.
- **Por qué:** (1) rendimiento: la fuente por defecto del motor no trae ▼ ▲ ⚠ → ✓; sin respaldo, cada texto con esos glifos hacía una búsqueda
  de fuente del sistema (3,7-5,8 ms por texto, `FloatingText.play` 2,5-6 ms); con el respaldo, 0,07-0,09 ms. (2) corrección: en Web
  Godot no accede a fuentes del SO y en Android la fuente del sistema puede no tener los glifos: saldría un cuadrado. Ahora los glifos van empaquetados.
- **Importación** (`DejaVuSans.ttf.import`): fuente dinámica (`font_data_dynamic`), `compress=true`, sin MSDF, hinting y antialiasing por defecto,
  **`allow_system_fallback=false`** (nunca busca fuentes del SO: ni coste ni resultados distintos por plataforma).
  Si la UI usa un símbolo nuevo: añadirlo a `UiTheme.FALLBACK_GLYPHS` (lo comprueba `tests/ui/test_glyph_fallback.gd`).
- **Peso:** +760 KB en `assets/` (sin subconjunto: no hay `fonttools`/`pyftsubset` en esta máquina). Un subconjunto de ~10 glifos
  pesaría < 10 KB: `pyftsubset DejaVuSans.ttf --unicodes=U+25BC,U+25B2,U+26A0,U+2192,U+2713 --output-file=...` si el tamaño de la descarga Web importa
  (el pck se comprime; medir con `tools/build.sh`). Si se hace, renombrar la fuente según la licencia.
- **Medido** (`tools/perf/perf_glyph.gd`, 12 textos por caso, ms por texto "▼ -3" / "▲ +3" / "▼ -3 maná"): antes 4,06 / 4,02 / 3,85; después 0,08 / 0,07 / 0,09.
  Textos sin glifo no cambian (0,05 -> 0,07-0,08, ruido).
- **Capturas** (mesa 720x1280, sin editar `capture.gd`): `docs/revision/capturas/v2-p1-antes-mesa.png` / `v2-p1-despues-mesa.png` idénticas;
  `v2-p1-antes-feedback.png` / `v2-p1-despues-feedback.png` (números flotantes ▼/▲) iguales salvo el instante de la animación.

## Procedimiento: cambiar el tema
1. Editar `UiTheme.build()`.
2. Regenerar el recurso (el `.ttf` de `assets/fonts/` debe estar importado: `godot --headless --path . --import`): script con `ResourceSaver.save(UiTheme.build(), "res://src/ui/theme.tres")`, ejecutado con
   `godot --headless --path . -s <script>.gd`.
3. Capturas: `godot --path . -s tests/ui/capture_v02.gd -- mesa-6j out.png 1080 1920` y otra a `720 1280` (con pantalla, no headless);
   revisar con Read.
4. `bash tools/test.sh`.

## Procedimiento: validar un shader
Arrancar Godot **con pantalla** (DISPLAY) y un script que lo cargue, lo asigne a un nodo, espere 2-3 fotogramas y guarde la captura;
los errores de compilación salen por stderr. Solo `canvas_item`; probar también que no usa nada de Forward+.
Validado en V2-18 con Mesa/AMD en modo Compatibility: 0 errores, rayado/halo y contorno visibles.

## Importación de un recurso nuevo (imágenes)
Sin cambios respecto a la práctica actual: arte en `assets/**`, importar en Godot (WebP lossless para UI nítida, lossy para fondos),
mipmaps desactivados para UI 2D, filtro lineal. Pendiente medir carga diferida de cartas (Performance).

# Descarga de packs v0.3 (V3-22)

Fecha: 2026-10-14. Autorizado por E13. Estado de todo: **generado** (no integrado). Descargas con `curl -L` a un directorio temporal; se comprobó `file`, se listaron los tipos del zip y no se ejecutó nada. Los ZIP no se conservan.

| Pack | Fuente oficial | Qué se conserva | Peso añadido (bytes) |
|---|---|---|---|
| Kenney Fantasy UI Borders | https://kenney.nl/assets/fantasy-ui-borders (zip 359 KB) | `PNG/Default` y `PNG/Double` (6 categorías: Border, Panel, Transparent border/center, Divider, Divider Fade; 32+32+32+32+6+6 piezas por escala), `Vector/*.svg`, `Preview.png`, `LICENSE.txt`. Se omitió `Sample.png` y los `.url` | 212 195 |
| Kenney Game Icons | https://kenney.nl/assets/game-icons (zip 1 MB, 425 PNG) | Solo `pause`, `checkmark`, `cross` (blanco, 1x y 2x) + `LICENSE.txt` | 92 409 (incluye licencia) |
| game-icons.net | repo oficial https://github.com/game-icons/icons (zip del master, 4 239 SVG; no se conserva) | 25 SVG elegidos + `LICENSE.txt` (su `license.txt`) | 43 086 |
| Cinzel | Google Fonts, https://github.com/google/fonts/tree/main/ofl/cinzel (`Cinzel[wght].ttf`, `OFL.txt`, `METADATA.pb` para autor) | `Cinzel-VariableFont_wght.ttf` + `OFL.txt` | 129 851 |

Total en `assets/ui_v03`: **477 541 bytes (~0,47 MB)**, por debajo del objetivo de 1,5 MB (`du -sh` muestra 1,7 MB por redondeo a bloques de 294 archivos). `assets/` total sigue en 8,2 MB. Seguridad: los zip solo traían png/svg/txt/url/xml/ai (Kenney) y svg/md/txt/sh/gitignore (repo de iconos); los `.sh` y `.ai/.xml/.url` no se copiaron.

## Verificaciones
1. **Licencias reales**: Fantasy UI Borders `License.txt` = CC0 (crédito no obligatorio). Game Icons de Kenney `license.txt` = CC0. game-icons.net `license.txt` del repo: "Creative Commons 3.0 BY, o CC0 si se indica" (solo Viscious Speed y Zeromancer); pide "include a mention 'Icons made by {author}'"; los 4 autores usados (Lorc, Delapouite, Willdabeast, Faithtoken) son CC BY 3.0. Cinzel `OFL.txt` = SIL OFL 1.1, "Copyright 2020 The Cinzel Project Authors (https://github.com/NDISCOVER/Cinzel)". **Coincide con la propuesta.** Nota: en el sample de Kenney se usó la fuente Aoboshi One (OFL) pero no se incluye en el pack.
2. **Cinzel**: `fontTools` no está instalado; se comprobó con Godot headless (`FontFile.has_char`): están **á é í ó ú ü ñ ¿ ¡ Á É Í Ó Ú Ü Ñ**, letras y dígitos; faltan: ninguno. Es una fuente variable con eje wght 400-900 (peso 400 por defecto). El cuerpo conserva DejaVu de respaldo (no tocado aquí).
3. **Marcos de Kenney**: son PNG **blancos de 1 bit** (48 px por pieza en Default, el doble en Double), estilo pixel/trazo fino, pensados para 9-slice. No son "demasiado claros": son monocromos y se **tintan con `modulate`** (oro viejo `#B8913F`, lavanda, carmesí); sin tinte quedarían blancos. Las variantes "Panel"/"Transparent border" traen relleno o solo borde. Al ser pixel-art a 48 px, ~~escalar con filtro `nearest` y múltiplos enteros~~ **Nota sustituida (C8, evaluación de diseño v0.3): se usa filtro lineal** (a escala 0,667 `nearest` deja trazos desiguales); usar `Double`.
4. **Iconos de game-icons.net**: SVG de 0,6-3,4 KB con un `<path d="M0 0h512v512H0z"/>` negro de fondo y la forma `fill="#fff"`. Para tintarlos hay que quitar ese rectángulo (adaptación, indicarla) o rasterizar con el fondo como máscara; decisión de integración pendiente para el Developer/Art. Godot los importa como textura sin error.
5. **Importación**: `godot --headless --path . --import` sin errores ni avisos tras añadir los archivos.

## Pendientes
- Integrar (Developer): marcos 9-slice, iconos, fuente; hasta entonces el estado es "generado".
- Pantalla "Créditos y licencias" con el texto de `docs/arte/licencias.md` (obligatoria por game-icons.net).
- Decidir si se genera una versión sin fondo/teñida de los 25 SVG (cuenta como adaptación).
- Elección de los 6 sigilos por mago (propuestos: lobo, cuervo, búho, zorro, dragón, ciervo) y de las piezas concretas de Kenney a usar.
- Decidir si se añade `assets/ui_v03` a `.gitignore`: no se ha hecho (no es arte de SUPERHOTEX; es CC0/CC BY/OFL redistribuible con su licencia).

## V3-13c (iconos adaptados y extra)
- `tools/strip_icon_bg.py` (`python3 -I`, solo stdlib, idempotente) quitó el fondo negro de los 31 SVG; segundo pase sin cambios. Rechaza SVG con `<script>`, `on*=` o referencias externas.
- 6 iconos nuevos de game-icons.net (descargados con `curl` a una carpeta vacía, verificados como SVG de texto sin script ni referencias): hamburger-menu (Menú), scroll-unfurled (Registro), hand (Recibir el golpe), cog (Ajustes), crystal-wand (Lanzar), impact-point (reserva). Kenney Game Icons solo tiene pause, checkmark y cross en disco, sin equivalentes.
- Estado: **generado** (no integrado hasta que un Developer los use).

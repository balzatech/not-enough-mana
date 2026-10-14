# Iconos de estado y marcos (V2-19)

Recursos propios, generados con `tools/gen_ui_icons.py` (Pillow; idempotente). Contact sheet: `docs/arte/iconos-estado.png`.
Todos en PNG con alfa, contorno oscuro de 3 px (a 96) para separarlos del panel `COL_PANEL`. Silueta distinta por icono (daltonismo).

| Recurso | Archivos | Tamaño | Silueta | Uso previsto | Estado |
|---|---|---|---|---|---|
| Congelado | `assets/ui/icon_congelado_{96,48}.png` | 96 y 48 | copo de 6 brazos | sustituye la etiqueta "Congelado" en `player_panel.gd` | generado |
| Cegado | `icon_cegado_*` | 96 y 48 | ojo tachado | etiqueta "Cegado" | generado |
| Campo de fuerza | `icon_campo_fuerza_*` | 96 y 48 | escudo heráldico | etiqueta "Escudo" | generado |
| Maldito | `icon_maldito_*` | 96 y 48 | calavera | maldición activa sobre el jugador | generado |
| Turno actual | `icon_turno_*` | 96 y 48 | círculo con flecha | sustituye "TURNO" | generado |
| Bot | `icon_bot_*` | 96 y 48 | cabeza de robot con antena | sustituye "Bot" | generado |
| Jugador eliminado | `icon_eliminado_{96,48}.png` | 96 y 48 | lápida de arco con cruz grabada sobre base de tierra (sin calavera; distinta de Maldito) | jugador eliminado en `player_panel.gd` (mesa 5-6, §3.3): junto a la etiqueta "Eliminado", con el panel al 50 % y rayado (V2-33 integra) | generado |
| Marco carta jugable | `assets/ui/frame_jugable_9slice.png` | 64x64, 9-slice, margen 14 px | borde verde brillante redondeado, centro transparente | `StyleBoxTexture`/NinePatchRect sobre la carta de la mano jugable; borde dentro de 5-9 px, no cubre nombre ni coste (esquina sup. y centro inf. quedan a >9 px del borde si se usa a tamaño carta) | generado |
| Marco evento activo | `frame_evento_9slice.png` | 64x64, 9-slice, margen 14 px | doble borde violeta/dorado con rombos en las esquinas | carta del centro (evento activo) | generado |

Colores: congelado cian claro, cegado blanco/violeta con tachado rojo, escudo dorado/azul (`COL_ACCENT`/`COL_MANA`), maldito violeta, turno `COL_ACCENT`, jugable verde (`COL_OK` aclarado).

Notas para integración (V2-33/V2-23): usar los 48 px en el panel y los 96 px en pantallas HiDPI; en el marco usar `patch_margin` 14 en los cuatro lados. Si los rombos de las esquinas del marco de evento tapan el coste, reducir el marco o usar solo el borde.

Eliminado (V2-45): gris piedra; debe mostrarse a opacidad completa aunque el panel esté atenuado, y acompañarse del texto "Eliminado".

Estado global: **generado**; ninguno integrado ni verificado en el juego. Pendiente: revisar el aspecto real sobre las cartas en el juego.

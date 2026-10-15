# Licencias de recursos de terceros (v0.3)

Fecha: 2026-10-14. Aprobación del usuario: decisión E13. Estado de todos los recursos: **generado** (descargado, no integrado). Cada carpeta lleva su archivo de licencia real; lo de abajo se ha contrastado con ellos (ver `docs/arte/descarga-v03.md`).

## Por pack
| Pack | Autor | URL | Licencia | Obligación | Carpeta | Estado |
|---|---|---|---|---|---|---|
| Fantasy UI Borders 1.0 | Kenney | https://kenney.nl/assets/fantasy-ui-borders | CC0 1.0 (`LICENSE.txt`) | Ninguna (crédito a Kenney voluntario) | `assets/ui_v03/kenney_fantasy_ui_borders/` | generado |
| Game Icons (Kenney) | Kenney Vleugels | https://kenney.nl/assets/game-icons | CC0 1.0 (`LICENSE.txt`) | Ninguna (crédito voluntario) | `assets/ui_v03/kenney_game_icons/` (solo pause, checkmark, cross; blanco 1x/2x) | generado |
| game-icons.net (31 iconos) | Lorc, Delapouite, Willdabeast, Faithtoken | https://game-icons.net ; https://github.com/game-icons/icons | CC BY 3.0 (https://creativecommons.org/licenses/by/3.0/) | **Atribución por autor** ("Icons made by {author}"), enlace a la licencia, indicar si se modifican (recolorear) | `assets/ui_v03/game_icons/` | generado |
| Cinzel (variable, wght 400-900) | Natanael Gama / The Cinzel Project Authors | https://fonts.google.com/specimen/Cinzel ; https://github.com/NDISCOVER/Cinzel | SIL OFL 1.1 (`OFL.txt`) | Conservar copyright y `OFL.txt` junto a la fuente; no vender la fuente suelta; sin atribución en pantalla | `assets/ui_v03/fonts/cinzel/` | generado |

Autores de game-icons.net usados (de su `license.txt`): Lorc (http://lorcblog.blogspot.com), Delapouite (http://delapouite.com), Willdabeast (http://wjbstories.blogspot.com), Faithtoken (http://fungustoken.deviantart.com). Ninguno de los 4 es de los marcados CC0 en esa lista (solo Viscious Speed y Zeromancer lo son): los 31 iconos son **CC BY 3.0**.

## Game-icons.net: una fila por icono
**Adaptados: se eliminó el fondo y se recolorean en el juego** (C9). Se quitó el rectángulo negro `M0 0h512v512H0z` con `tools/strip_icon_bg.py`; la forma queda en blanco y se tiñe con `self_modulate`. Aplica a los 31 iconos de la tabla (los 25 originales y los 6 de V3-13c). Las URL apuntan al original.

| Archivo | Autor | Icono | URL | Licencia | Uso previsto | Estado |
|---|---|---|---|---|---|---|
| `assets/ui_v03/game_icons/lorc__crossed-swords.svg` | Lorc | crossed-swords | https://game-icons.net/1x1/lorc/crossed-swords.html | CC BY 3.0 | Atacar | generado |
| `assets/ui_v03/game_icons/willdabeast__round-shield.svg` | Willdabeast | round-shield | https://game-icons.net/1x1/willdabeast/round-shield.html | CC BY 3.0 | Defender / escudo | generado |
| `assets/ui_v03/game_icons/lorc__potion-ball.svg` | Lorc | potion-ball | https://game-icons.net/1x1/lorc/potion-ball.html | CC BY 3.0 | Poción | generado |
| `assets/ui_v03/game_icons/lorc__hourglass.svg` | Lorc | hourglass | https://game-icons.net/1x1/lorc/hourglass.html | CC BY 3.0 | Terminar turno | generado |
| `assets/ui_v03/game_icons/delapouite__card-exchange.svg` | Delapouite | card-exchange | https://game-icons.net/1x1/delapouite/card-exchange.html | CC BY 3.0 | Intercambiar | generado |
| `assets/ui_v03/game_icons/faithtoken__card-discard.svg` | Faithtoken | card-discard | https://game-icons.net/1x1/faithtoken/card-discard.html | CC BY 3.0 | Descartar | generado |
| `assets/ui_v03/game_icons/delapouite__fire-spell-cast.svg` | Delapouite | fire-spell-cast | https://game-icons.net/1x1/delapouite/fire-spell-cast.html | CC BY 3.0 | Elemento fuego | generado |
| `assets/ui_v03/game_icons/delapouite__ice-spell-cast.svg` | Delapouite | ice-spell-cast | https://game-icons.net/1x1/delapouite/ice-spell-cast.html | CC BY 3.0 | Elemento hielo | generado |
| `assets/ui_v03/game_icons/delapouite__bolt-spell-cast.svg` | Delapouite | bolt-spell-cast | https://game-icons.net/1x1/delapouite/bolt-spell-cast.html | CC BY 3.0 | Elemento rayo | generado |
| `assets/ui_v03/game_icons/lorc__rune-stone.svg` | Lorc | rune-stone | https://game-icons.net/1x1/lorc/rune-stone.html | CC BY 3.0 | Runa | generado |
| `assets/ui_v03/game_icons/lorc__rune-sword.svg` | Lorc | rune-sword | https://game-icons.net/1x1/lorc/rune-sword.html | CC BY 3.0 | Runa / arma rúnica | generado |
| `assets/ui_v03/game_icons/lorc__magic-swirl.svg` | Lorc | magic-swirl | https://game-icons.net/1x1/lorc/magic-swirl.html | CC BY 3.0 | Magia / hechizo | generado |
| `assets/ui_v03/game_icons/lorc__magic-portal.svg` | Lorc | magic-portal | https://game-icons.net/1x1/lorc/magic-portal.html | CC BY 3.0 | Magia / portal | generado |
| `assets/ui_v03/game_icons/lorc__wolf-head.svg` | Lorc | wolf-head | https://game-icons.net/1x1/lorc/wolf-head.html | CC BY 3.0 | Sigilo mago 1 (lobo) | generado |
| `assets/ui_v03/game_icons/lorc__raven.svg` | Lorc | raven | https://game-icons.net/1x1/lorc/raven.html | CC BY 3.0 | Sigilo mago 2 (cuervo) | generado |
| `assets/ui_v03/game_icons/lorc__owl.svg` | Lorc | owl | https://game-icons.net/1x1/lorc/owl.html | CC BY 3.0 | Sigilo mago 3 (búho) | generado |
| `assets/ui_v03/game_icons/lorc__fox-head.svg` | Lorc | fox-head | https://game-icons.net/1x1/lorc/fox-head.html | CC BY 3.0 | Sigilo mago 4 (zorro) | generado |
| `assets/ui_v03/game_icons/lorc__dragon-head.svg` | Lorc | dragon-head | https://game-icons.net/1x1/lorc/dragon-head.html | CC BY 3.0 | Sigilo mago 5 (dragón) | generado |
| `assets/ui_v03/game_icons/lorc__stag-head.svg` | Lorc | stag-head | https://game-icons.net/1x1/lorc/stag-head.html | CC BY 3.0 | Sigilo mago 6 (ciervo) | generado |
| `assets/ui_v03/game_icons/lorc__skull-crossed-bones.svg` | Lorc | skull-crossed-bones | https://game-icons.net/1x1/lorc/skull-crossed-bones.html | CC BY 3.0 | Eliminado / peligro | generado |
| `assets/ui_v03/game_icons/delapouite__all-seeing-eye.svg` | Delapouite | all-seeing-eye | https://game-icons.net/1x1/delapouite/all-seeing-eye.html | CC BY 3.0 | Ojo / vista | generado |
| `assets/ui_v03/game_icons/lorc__crystal-ball.svg` | Lorc | crystal-ball | https://game-icons.net/1x1/lorc/crystal-ball.html | CC BY 3.0 | Maná / magia | generado |
| `assets/ui_v03/game_icons/lorc__wizard-staff.svg` | Lorc | wizard-staff | https://game-icons.net/1x1/lorc/wizard-staff.html | CC BY 3.0 | Báculo / mago | generado |
| `assets/ui_v03/game_icons/lorc__pointy-hat.svg` | Lorc | pointy-hat | https://game-icons.net/1x1/lorc/pointy-hat.html | CC BY 3.0 | Sombrero de mago | generado |
| `assets/ui_v03/game_icons/delapouite__spell-book.svg` | Delapouite | spell-book | https://game-icons.net/1x1/delapouite/spell-book.html | CC BY 3.0 | Libro / reglas | generado |
| `assets/ui_v03/game_icons/delapouite__hamburger-menu.svg` | Delapouite | hamburger-menu | https://game-icons.net/1x1/delapouite/hamburger-menu.html | CC BY 3.0 (adaptado) | Menú (V3-13c) | generado |
| `assets/ui_v03/game_icons/lorc__scroll-unfurled.svg` | Lorc | scroll-unfurled | https://game-icons.net/1x1/lorc/scroll-unfurled.html | CC BY 3.0 (adaptado) | Registro (pergamino) (V3-13c) | generado |
| `assets/ui_v03/game_icons/lorc__hand.svg` | Lorc | hand | https://game-icons.net/1x1/lorc/hand.html | CC BY 3.0 (adaptado) | Recibir el golpe (mano abierta) (V3-13c) | generado |
| `assets/ui_v03/game_icons/lorc__cog.svg` | Lorc | cog | https://game-icons.net/1x1/lorc/cog.html | CC BY 3.0 (adaptado) | Ajustes (V3-13c) | generado |
| `assets/ui_v03/game_icons/lorc__crystal-wand.svg` | Lorc | crystal-wand | https://game-icons.net/1x1/lorc/crystal-wand.html | CC BY 3.0 (adaptado) | Lanzar (propio, distinto del rayo) (V3-13c) | generado |
| `assets/ui_v03/game_icons/lorc__impact-point.svg` | Lorc | impact-point | https://game-icons.net/1x1/lorc/impact-point.html | CC BY 3.0 (adaptado) | Reserva (impacto) (V3-13c) | generado |

## Texto de atribución propuesto (pantalla "Créditos y licencias")
> Iconos de game-icons.net de Lorc, Delapouite, Willdabeast y Faithtoken, licencia CC BY 3.0 (https://creativecommons.org/licenses/by/3.0/); adaptados (se eliminó el fondo y se recolorean en el juego). Interfaz: Fantasy UI Borders y Game Icons de Kenney (kenney.nl), CC0. Tipografía: Cinzel, de Natanael Gama, SIL OFL 1.1. Cartas, ilustraciones y reglas: (c) SUPERHOTEX.

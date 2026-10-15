# Propuesta de packs de arte para la v0.3 (sin descargar nada)

Autor: Art Agent. Fecha: 2026-10-14. Prioridad 11 de `docs/revision/LINEAMIENTOS-v03.md`; el usuario elige (E13) y solo entonces se descarga.

## 0. Aviso de verificación (leer primero)
- **No tuve acceso a la web en esta tarea** (ni búsqueda ni descarga). Todo lo de abajo sale de mi conocimiento de estos recursos, no de haberlos abierto hoy. Solo propongo recursos que conozco bien, pero **cada licencia, enlace, peso y estilo está marcado "a verificar al descargar"**: antes de integrar se abre el archivo de licencia del propio paquete (Kenney incluye `License.txt`; las fuentes de Google traen `OFL.txt`) y se guarda en la carpeta del pack y en `docs/arte/licencias.md`.
- Los pesos son estimaciones. Presupuesto: el pack final solo lleva el **subconjunto usado** (lineamientos §6.4: ≤ +20 MB de texturas; `assets/` ≤ ~25 MB en Web).
- Nada de lo propuesto es "solo uso no comercial" ni imita el arte de SUPERHOTEX. Ningún recurso se aplica sobre las cartas: los marcos van alrededor.

## 1. Estado actual (lo que he visto en capturas)
`v2-33-mesa-5j-1080x1920` y `v2-36-reaccion-6j-720x1280`: paneles planos azul-noche con borde violeta fino, botones rectangulares redondeados sin icono, "Beber poción" verde enorme, texto en la fuente por defecto del motor con DejaVu de respaldo, y la ilustración de SUPERHOTEX (rojos/naranjas) a pantalla completa detrás. Falta: marcos con carácter, iconos por acción, fondo propio y un título con personalidad. Ya existen 7 iconos de estado propios y 2 marcos (`docs/arte/iconos-estado.md`, estado "generado").

---

## 2. Necesidad 1: interfaz de fantasía (paneles, marcos, botones)

### Opción 1A: Kenney "Fantasy UI Borders" (referencia del usuario)
- Autor: Kenney (kenney.nl). Enlace: https://kenney.nl/assets/fantasy-ui-borders (a verificar).
- **Licencia: CC0 1.0** (dominio público). No obliga a nada; Kenney agradece un crédito, opcional.
- Contenido (a verificar): marcos y paneles decorativos con esquinas ornamentadas, separadores, en PNG y a veces SVG, pensados para 9-slice; varias variantes de color/forma.
- Formato y peso: PNG; el zip pesa unos pocos MB, usaríamos 10-20 piezas (< 500 KB).
- Encaje: bueno para marcos de paneles de mago, hojas y diálogos (§2.4). Probable estilo limpio y neutro (gris/beige/oscuro): se recolorea a oro viejo `#B8913F` y violeta con `modulate` o con un shader sencillo si la pieza es clara/monocroma. **No trae botones con gema**; el botón principal se completa con `StyleBoxTexture` + nuestro relleno violeta.
- Riesgos: (a) el estilo de Kenney es limpio/plano y puede quedar poco "mágico" sin color ni brillo (se compensa con efectos por código); (b) si las piezas son de color fijo, el recoloreo pierde detalle; (c) comprobar que los bordes de 9-slice no tapan cifras en paneles pequeños (panel de rival ≈ 140 px alto).
- Recomendación: **sí, como base** de marcos y paneles.

### Opción 1B: Kenney "UI Pack - Adventure"
- Autor: Kenney. Enlace: https://kenney.nl/assets/ui-pack-adventure (a verificar).
- **Licencia: CC0 1.0.** Sin obligación.
- Contenido (a verificar): botones en varios tamaños y estados (normal/pulsado), paneles, barras, iconos básicos, con estética de aventura/pergamino.
- Formato y peso: PNG y hoja de sprites; unos MB, usaríamos < 1 MB.
- Encaje: medio. Aporta **estados de botón ya resueltos** (normal/pulsado), útiles para los 5 estados de §2.5, pero su paleta cálida (madera/pergamino) choca con la noche violeta; habría que tintar. Riesgo de aspecto "juego casual" frente al tono arcano.
- Recomendación: **solo si 1A no convence en botones**; usar como referencia de estados.

### Opción 1C: "UI Pack - RPG Expansion" (Kenney) o generado por código
- 1C-i: Kenney "UI Pack - RPG Expansion" (https://kenney.nl/assets/ui-pack-rpg-expansion, a verificar). **CC0**. Marrón/beige de pergamino, botones con bisel y paneles; mismo problema de paleta cálida que 1B.
- 1C-ii (sin pack): **paneles y botones por código** con `StyleBoxFlat` (bordes dobles oro, sombras, degradados) y los marcos 9-slice propios ya generados. Cero licencias, cero peso, 100 % coherentes con la paleta. Menos detalle ornamental.
- Recomendación: **1C-ii como complemento** (botones de 5 estados con StyleBox y gema por shader) y 1A solo para marcos/paneles/separadores.

---

## 3. Necesidad 2: iconos (magia, runas, elementos, pociones, escudos)

### Opción 2A: game-icons.net
- Autores: Lorc, Delapouite, Skoll, Willdabeast, Lucas, Sbed, Caro Asercion, y otros (cada icono indica su autor). Sitio: https://game-icons.net ; repositorio: https://github.com/game-icons/icons (a verificar).
- **Licencia: CC BY 3.0** en la gran mayoría (algunos autores pueden figurar como CC0/dominio público; **se comprueba icono por icono** en la ficha). **Obliga a atribución**: nombre del autor, enlace a la licencia y a la fuente, y avisar si se modificó (recolorear cuenta como adaptación: indicarlo). Se pone en la pantalla "Créditos y licencias" de Ajustes (texto en la sección 9).
- Contenido: más de 4 000 iconos de fantasía en una sola silueta (SVG y PNG, color configurable): llamas (`fire`), `snowflake-1`, `lightning-bolt`, `crystal-ball`, `potion-ball`, `round-shield`, `wizard-staff`, `hourglass`, `scroll-unfurled`, runas y sigilos, calavera, ojo, etc. Es la fuente idónea para los **6 sigilos de mago** y para cada acción de §2.7.
- Formato y peso: SVG 1-3 KB cada uno; unos 30-40 iconos ≈ 100 KB. Se rasterizan a PNG 96/192 (sin pérdida) si se quiere evitar dependencia del importador SVG.
- Encaje: **muy bueno**: monocromo, silueta fuerte, legible a 48-96 px; se tiñe con la paleta (oro, lavanda, plata) y es coherente entre sí. Cumple "forma además de color" de §2.2.
- Riesgos: (a) la **atribución es obligatoria y por autor** (hay que llevar una lista de los usados); (b) mezcla de autores = ligeras diferencias de grosor (elegir sobre todo Lorc y Delapouite, que comparten estilo); (c) nombres exactos de iconos a confirmar al elegir.
- Recomendación: **sí, pack principal de iconos.**

### Opción 2B: Font Awesome Free (iconos de utilidad)
- Autor: Fonticons, Inc. Enlace: https://fontawesome.com/license/free (a verificar).
- **Licencia: iconos CC BY 4.0** (fuentes SIL OFL 1.1, código MIT). Obliga a atribución; es válida la nota del archivo/páginas de licencia. Versión Free: solo estilo "solid" y "regular/brands" parcial.
- Contenido: `hat-wizard`, `wand-magic-sparkles`, `book-skull`, `hourglass-half`, `shield-halved`, `flask`, `fire`, `snowflake`, `bolt`, `scroll`, `gear`, `bars`, `repeat`, `trash`, `skull`, `eye-slash`. Cubre menú, ajustes, registro, intercambiar, descartar.
- Formato y peso: SVG ~0,5-1 KB cada uno.
- Encaje: medio. Es un set **uniforme y muy legible** pero con aire de "aplicación"; no tiene runas ni sigilos. Útil para el nivel terciario (Menú, Ajustes, registro).
- Riesgos: estilo genérico (justo lo que el usuario critica); dos sets distintos (2A+2B) exigen cuidar la coherencia.
- Recomendación: **opcional**, solo para Menú/Ajustes/registro si 2A no ofrece una silueta clara. Mejor limitarse a 2A.

### Opción 2C: Kenney "Game Icons" (y "Board Game Icons")
- Autor: Kenney. Enlace: https://kenney.nl/assets/game-icons (a verificar). **Licencia: CC0 1.0.** Sin obligación.
- Contenido: iconos genéricos (flechas, engranaje, sonido, cruz, check, pausa) en blanco/negro; muy poca fantasía.
- Peso: < 300 KB; usaríamos pocos.
- Encaje: bajo en tema; alto en limpieza legal. Sirve para **pausa, cerrar, check, flechas** sin atribución.
- Recomendación: **complemento CC0** para los iconos utilitarios, evitando 2B y su atribución.

Nota: los 7 iconos de estado propios (copo, ojo tachado, escudo, calavera, turno, bot, lápida) se conservan; solo se sustituyen si el icono de 2A mantiene una silueta distinta para cada uno (lineamientos §2.7).

---

## 4. Necesidad 3: fondo de la mesa

Decisión previa del Director: **fondo propio generado por código** (degradado noche arcana, círculo rúnico tenue, viñeta, motas). Un pack solo aportaría textura.

### Opción 3A: sin pack (generado por código y Pillow)
- Degradado `#0E0B1A` -> `#1B1433`, círculo rúnico dibujado con `draw`/shader a ≤ 10 % de opacidad, viñeta por shader `canvas_item`, ruido sutil generado en código.
- Licencia: propia, sin obligación. Peso: ~0 MB (o un PNG de ruido de 256x256 ≈ 50 KB).
- Encaje: total (paleta exacta); riesgo: puede verse "liso" si no se añade grano. Se mitiga con ruido y viñeta.
- Recomendación: **sí, base.**

### Opción 3B: ambientCG (texturas PBR)
- Autor: Lucas Majerowicz / ambientCG y colaboradores. Enlace: https://ambientcg.com (a verificar).
- **Licencia: CC0 1.0.** Sin obligación.
- Uso: una textura oscura de **tela/terciopelo, cuero o piedra** (solo el mapa de color, 1K, JPG/WebP) mezclada por shader a 8-15 % sobre el degradado, teñida de violeta. No se importan mapas de normales (coste).
- Peso: 1K JPG ≈ 0,5-1,5 MB; se reduce a 512x512 WebP (≈ 60-150 KB) y se repite en mosaico.
- Encaje: bueno si se tiñe y se mantiene muy tenue; sin tinte parece realista y rompe la fantasía. Riesgo: el mosaico puede notarse; elegir una textura sin patrón claro.
- Recomendación: **opcional**, solo si 3A queda liso.

### Opción 3C: Poly Haven (texturas)
- Autor: Poly Haven y artistas. Enlace: https://polyhaven.com/textures (a verificar). **Licencia: CC0 1.0.**
- Uso igual que 3B (tela, cuero, mármol oscuro); mismas condiciones de peso y tinte.
- Recomendación: alternativa a 3B si allí no hay una textura adecuada.

Elección de la tela concreta: se propone al usuario **tras** aprobar la opción, con 2-3 vistas previas generadas por Art (sin que se incorpore nada al juego hasta aprobarlas).

---

## 5. Necesidad 4: tipografía decorativa para títulos (con acentos del español)

Todas son **SIL OFL 1.1** (fuentes de Google Fonts, a verificar al descargar): se pueden usar y empaquetar gratis; **la atribución en pantalla no es obligatoria**, pero hay que **conservar el aviso de copyright y el texto de la licencia** (`OFL.txt`) en `assets/fonts/` y no vender la fuente suelta. Si se modifica (subconjunto) hay que respetar el "nombre reservado" (renombrar si lo declara). Mantener DejaVu Sans de respaldo en todos los `FontVariation` (§2.3; `test_glyph_fallback` en verde). Uso solo a ≥ 40 px, textos cortos, sin números.

### Opción 4A: Cinzel (Natanael Gama)
- Enlace: https://fonts.google.com/specimen/Cinzel. Licencia OFL 1.1. Latin y Latin Extended (á é í ó ú ü ñ ¿ ¡ a verificar con un texto de prueba).
- Estilo: capitales romanas clásicas, elegante, "grimorio/templo"; sin mayúscula-minúscula (las minúsculas son versalitas). Muy buena lectura a 40+ px y excelente con oro sobre violeta.
- Peso: fuente variable ≈ 100-150 KB (TTF). Existe también Cinzel Decorative (más floreos, más pesada y menos legible: no recomendada para frases).
- Riesgo: todo en versalitas puede cansar en frases largas ("¡Bruno te ataca!" funciona; frases de 5+ palabras, no). Verificar que las cifras tengan buen aspecto (no se usan).
- Recomendación: **elegida para títulos y banners.**

### Opción 4B: Metamorphous (Hector Gatti)
- Enlace: https://fonts.google.com/specimen/Metamorphous. OFL 1.1. Latin y Latin Extended (verificar).
- Estilo: caligrafía fantástica con remates angulosos, tono de juego de rol de fantasía más marcado que Cinzel; minúsculas legibles.
- Peso: ≈ 60-100 KB.
- Riesgo: algo más "juego de mesa de rol" que "arcano elegante"; a tamaños < 40 px pierde claridad.
- Recomendación: alternativa si se quiere más personalidad con minúsculas.

### Opción 4C: MedievalSharp (Wojciech Kalinowski) o Almendra (Ana Sanfelippo)
- Enlaces: https://fonts.google.com/specimen/MedievalSharp ; https://fonts.google.com/specimen/Almendra. OFL 1.1 (a verificar). Latin Extended a comprobar para `¿ ¡ ñ ü`.
- Estilo: MedievalSharp, gótico/cuchillo, más "medieval" que mago; Almendra, caligrafía cursiva con remates. Pesos 30-70 KB.
- Riesgo: menos sobrias; la **cobertura de acentos y de ¿ ¡ es lo que más hay que comprobar** antes de aceptar.
- Recomendación: no necesaria si se elige 4A o 4B.

### Cuerpo (convive con la fuente actual)
Se propone **mantener la fuente actual** (cuerpo y números) y DejaVu de respaldo; no hace falta pack. Si el usuario quiere cifras de ancho fijo garantizadas: **Source Sans 3** (Adobe, OFL 1.1, https://fonts.google.com/specimen/Source+Sans+3, con cifras tabulares `tnum`; fuente variable ≈ 300 KB, subconjunto latin ≈ 80 KB) o **Nunito Sans** (OFL 1.1). A verificar con una prueba en Godot que el `FontVariation` aplique `tnum`.

Pareja recomendada: **Cinzel (títulos) + fuente actual (cuerpo) + DejaVu (glifos).**

---

## 6. Necesidad 5: efectos y partículas

Los efectos los harán los agentes por código (shaders `canvas_item`, `CPUParticles2D`, `Line2D`, tweens); no se descarga ningún paquete de efectos animados.

### Opción 5A: solo código (recomendada)
- Círculos rúnicos, proyectiles, anillos y chispas con `GradientTexture2D`, `Line2D` y shaders; partículas con un punto suave generado por Pillow (64x64 PNG, < 5 KB). Sin licencias, sin peso, compatible con Web y con el presupuesto de §6.3.

### Opción 5B: Kenney "Particle Pack"
- Autor: Kenney. Enlace: https://kenney.nl/assets/particle-pack (a verificar). **Licencia: CC0 1.0.**
- Contenido: más de 100 sprites de partícula blancos (humo, chispas, estrellas, llamas, círculos, rayos), 512 px o menos; se tiñen por `modulate`.
- Peso: ~ 1-4 MB el zip; se usarían 8-12 sprites (< 200 KB, convertibles a WebP).
- Encaje: bueno (blancos, se tiñen de la paleta). Riesgo: bajo; que algún sprite sea muy "cartoon" (se descarta).
- Recomendación: **solo si un efecto concreto no queda bien con el punto suave** (p. ej. humo de eliminación).

### Opción 5C: Kenney "Smoke Particles" / "Muzzle Flashes"
- Mismo autor y licencia CC0 (verificar). Útil para el humo de eliminación y destellos de impacto; se tratan igual que 5B.
- Recomendación: no necesaria de entrada.

---

## 7. Qué NO propongo
- Packs sin licencia clara en OpenGameArt/itch.io (las licencias varían por obra y hay etiquetas "non-commercial" y "CC BY-SA"; la SA obliga a compartir bajo la misma licencia, mejor evitarla). Si el usuario conoce uno concreto, se evalúa aparte.
- Nada recortado o derivado de las cartas ni de la portada de SUPERHOTEX.
- Generación de ilustraciones con IA: no hay herramienta disponible y no se plantea.

## 8. Tabla resumen (recomendaciones)

| Necesidad | Opción recomendada | Licencia | Obliga a | Peso a incluir | Complemento / respaldo |
|---|---|---|---|---|---|
| 1. UI de fantasía | **1A Kenney Fantasy UI Borders** (marcos, paneles, separadores) + botones por código (1C-ii) | CC0 | Nada (crédito opcional) | < 0,5 MB | 1B/1C-i solo para referencia de botones |
| 2. Iconos | **2A game-icons.net** (acciones, elementos, runas, 6 sigilos) | CC BY 3.0 | **Atribución** por autor en Créditos | ~100 KB | 2C Kenney Game Icons (CC0) para pausa/check/cerrar |
| 3. Fondo de mesa | **3A generado por código** (sin pack) | Propia | Nada | ~0-50 KB | 3B ambientCG o 3C Poly Haven (CC0) si queda liso |
| 4. Títulos | **4A Cinzel** | SIL OFL 1.1 | Conservar `OFL.txt` y copyright; sin crédito en pantalla | ~100-150 KB | 4B Metamorphous; cuerpo: la fuente actual (+ Source Sans 3 si se quieren cifras tabulares) |
| 5. Efectos | **5A solo código** | Propia | Nada | < 10 KB | 5B Kenney Particle Pack (CC0) |

Peso total estimado: < 1,5 MB, muy por debajo del presupuesto de +20 MB de texturas.

## 9. Texto de atribución para la pantalla "Créditos y licencias" (Ajustes)
Se incluye **solo lo que se elija**; con la combinación recomendada, la única licencia que exige atribución es game-icons.net.

> **Iconos:** Iconos de game-icons.net de Lorc, Delapouite y otros autores (lista completa por icono en `docs/arte/licencias.md`), licencia CC BY 3.0 (https://creativecommons.org/licenses/by/3.0/). Algunos iconos han sido recoloreados.
>
> **Interfaz:** Fantasy UI Borders de Kenney (kenney.nl), CC0 1.0. *(crédito voluntario)*
>
> **Tipografía:** Cinzel, de Natanael Gama, SIL Open Font License 1.1. DejaVu Sans, Bitstream Vera / dominio público (ver `assets/fonts/`).
>
> **Cartas, ilustraciones y reglas de "Not Enough Mana":** © SUPERHOTEX. Proyecto no oficial de uso personal.

Si se elige además Font Awesome Free: "Iconos de Font Awesome Free por Fonticons, Inc., CC BY 4.0 (https://fontawesome.com/license/free)".
Si se elige además ambientCG, Poly Haven o Kenney Particle Pack (CC0): sin obligación; se puede añadir un crédito voluntario.

## 10. Qué necesito del usuario
1. Elegir una opción por necesidad (o aceptar la recomendada: 1A+código, 2A, 3A, 4A, 5A).
2. Si acepta 2A: ¿le importa tener la lista de autores en Ajustes (obligatoria)? Si no se quiere atribución alguna, la alternativa 100 % CC0 es 2C + iconos propios (menos fantasía).
3. Tras elegir: Art descarga **solo** lo elegido, cada pack en su carpeta con su archivo de licencia, y se rellena `docs/arte/licencias.md` (fila por pack y por autor de icono). Antes de integrar, Art verifica las licencias contra los archivos descargados, mide el peso y registra en `docs/arte/recursos.md` con estado **generado**; "integrado" y "verificado en el juego" solo cuando un Developer los use.

## 11. Puntos que deben verificarse al descargar (resumen)
- Licencia real de cada pack en su `License.txt` / `OFL.txt` / ficha (especialmente iconos de game-icons.net uno a uno).
- Cobertura de á é í ó ú ü ñ ¿ ¡ y mayúsculas acentuadas en Cinzel (texto de prueba en Godot).
- Contenido exacto y estilo de Fantasy UI Borders (si es demasiado claro/gris, se tiñe o se pasa a 1B).
- Pesos reales y número de iconos finalmente usados.

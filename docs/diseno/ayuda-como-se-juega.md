# Pantalla "Cómo se juega" (V2-07a, ítem 11 de v0.2)

Autor: Game Designer. Fecha: 2026-10-13. Sin reglas nuevas ni cambios de efectos: todo sale del manual (`P&P Manual - single page.pdf`, `pdftotext -layout`) y de `REQUERIMIENTOS.md` §1 y §3. Lo que es adaptación digital va marcado **[Digital]** y es lo único que no está en el manual.
Los textos de abajo son el **contenido y el orden** que debe tener la pantalla; el tono final y la ortografía de interfaz los pule Narrative (`src/ui/strings*`). No se cita ni se traduce texto de cartas (© SUPERHOTEX): se explican las reglas con palabras propias.

## 1. Estructura de la pantalla
- Una sola pantalla con desplazamiento vertical, accesible desde el menú principal y desde el menú de la partida ("Cómo se juega"). Al volver de la ayuda desde la partida no se pierde ningún estado ni se pausa a nadie (en local el turno de un bot puede seguir; la ventana de reacción, si hay, sigue abierta).
- 8 secciones en este orden, cada una con título corto y 2-5 líneas (viñetas). Mínimo 22 px a 1080 de ancho (LINEAMIENTOS §4 ítem 12).
- Al final, enlace "Ver una carta": recordatorio de que se mantiene pulsada una carta para verla (ítem 5).
- No hay textos de ayuda que dependan del estado de la partida: es estática.

## 2. Contenido por sección

### 2.1 Objetivo
- Eres un mago de 3 a 6. Ganas si eres el último que sigue en pie.
- Quedas eliminado si te quedas en 0 de vida o por **Too Much Mana** (ver 2.5).
- Empiezas con 10 de vida (también es tu máximo) y 0 de maná (el maná no tiene tope) y 5 cartas.

### 2.2 Tu turno
1. **Robas** hasta tu límite de mano (normalmente 5). Si robas un **evento**, se aplica en ese momento y robas otra carta en su lugar.
2. **Actúas** tantas veces y en el orden que quieras: jugar cartas, descartar las que quieras, intercambiar cartas.
3. **Terminas el turno.**
- Si se acaba el mazo, se baraja el descarte y pasa a ser el mazo.
- Empieza el mago de más edad y se sigue en sentido horario (edad que se indicó al crear la partida) **[Digital]**.

### 2.3 Jugar una carta y pagar
- Para jugar una carta pagas su **coste**: maná, y a veces también **cartas de tu mano** de un tipo o elemento concreto (p. ej. "1 carta de fuego"). Las cartas que usas para pagar van al descarte con la jugada.
- El maná que cuesta una carta puede cambiar por eventos y artefactos: la ficha de la carta siempre te enseña el **coste actual**.
- Los hechizos con objetivo también se pueden lanzar contra ti mismo.
- **Scroll of Elements:** si lo tienes en mesa, sustituye a una carta requerida en un coste (un solo uso).
- **Intercambiar** una carta: la descartas, pagas y robas otra. El primer intercambio del turno cuesta 1 de maná, el segundo 2, el tercero 3...
- Si un efecto te obliga a descartar y no tienes cartas, pierdes 1 de maná por cada carta que no puedes descartar.
- Si tienes que perder más maná del que tienes, **tienes que beber una poción en ese momento**; si no, pierdes de vida tanto como maná te falte. **[Digital]** el juego te lo pregunta con una pantalla de decisión.
- Tipos de carta: ofensivas (fuego, hielo, electricidad), defensivas, de apoyo, maldiciones, artefactos y eventos.

### 2.4 Pociones de maná
- Cada poción te da **+3 de maná**. Puedes beber **en cualquier momento**, también fuera de tu turno y mientras decides una reacción.
- **[Digital]** Se bebe con el botón "Beber poción" (siempre disponible mientras sigas vivo), que lleva tu contador "pociones bebidas / límite".
- Hay un **pool común de cristales** (70 de vida y 70 de maná en total): lo que ganas sale del pool y lo que pagas o pierdes vuelve. Si no quedan cristales de maná en el pool, las pociones no dan nada. **[Digital]** (en la mesa física es un montón de cristales; aquí es un contador que la mesa muestra).
- Algunas cartas cambian lo que da una poción (más, o menos 1); la ayuda no las enumera.

### 2.5 Too Much Mana
- **[Digital]** Sustituye al "K.O. por beber demasiado" de la mesa física: hay un **límite de pociones por partida** (por defecto 10; se puede desactivar al crear la partida).
- Beber la poción número 11 te elimina **y no te da el maná**. Antes de esa poción el botón se pone ámbar a partir de 8/10 y rojo en 10/10, y la aplicación pide confirmación.
- Tu contador de pociones nunca baja durante la partida.

### 2.6 Defensivas y la ventana de reacción
- Las cartas **defensivas** se juegan **en respuesta** a un hechizo, también fuera de tu turno (escudos, conejo helado, última voluntad, captura de maná, aniquilación). Un **Lightning** también puede responder a otro Lightning (el daño sube y se redirige).
- **[Digital]** Cuando alguien lanza un hechizo se abre la **ventana de reacción**: decide **un jugador a la vez** (primero el objetivo y luego en sentido horario) y solo se espera a quien tiene una respuesta posible. Cada uno juega una defensiva o pulsa **Pasar**. Si juegas una respuesta, vuelven a decidir todos los que puedan. Cuando todos pasan, se resuelve primero la última respuesta.
- **[Digital]** Hay un plazo en línea; en local, no (solo el botón Pasar).
- **[Digital]** En Ajustes, "Avisarme de reacciones" elige si te interrumpe cualquier hechizo o solo los que te afectan (por defecto, solo los que te afectan). No cambia las reglas: si no te aparece la ventana, equivale a pulsar Pasar (ver `docs/diseno/preferencia-reaccion.md`).
- No puedes jugar una defensiva en tu turno si no hay un hechizo al que responder (la ventana solo existe ante un hechizo).

### 2.7 Eventos
- Un evento aparece cuando alguien lo roba. Se lee, se pone en el centro de la mesa y se aplica; después el que lo robó roba otra carta. En la mano inicial, el evento se descarta y se roba otra carta.
- Unos son inmediatos (curar o dañar a todos); otros **cambian las reglas hasta que aparezca el siguiente evento** (p. ej. un elemento cuesta más pero hace más, las pociones dan menos, el límite de mano sube).
- El evento activo se ve en el centro de la mesa; al llegar uno nuevo, el anterior se va.

### 2.8 Artefactos, maldiciones y datos de la partida
- Los **artefactos** se quedan en la mesa delante de su dueño y dan una ventaja mientras estén (o hasta que se usen).
- Las **maldiciones** quitan maná a los magos que cumplan su condición (edad, mes de nacimiento, vida). **Curse of Rules** deja una regla de mesa: quien la rompa pierde 1 de maná; **[Digital]** hay un botón "Rompió la regla".
- **[Digital]** Por eso al crear la partida se pide la edad y el mes de nacimiento de cada mago.

## 3. Resumen visual (opcional, 1 línea por icono)
Corazón = vida, gota = maná, frasco = poción. Sin cambios de significado respecto a la mesa.

## 4. Criterios de aceptación (para QA / Developer)
| # | Dado / cuando / entonces |
|---|---|
| A1 | Dado el menú principal, cuando se pulsa "Cómo se juega", entonces se abre una pantalla con las 8 secciones 2.1-2.8 en ese orden y un botón "Volver" que regresa al menú sin cambiar nada. |
| A2 | Dada una partida en curso, cuando se abre la ayuda desde el menú de la partida y se vuelve, entonces el estado de la partida (`rev`, vida, maná, mano) es idéntico al de antes de abrirla salvo lo que hayan hecho los bots en ese tiempo, y una ventana de reacción abierta sigue abierta. |
| A3 | Dada la pantalla de ayuda, cuando se revisan los textos, entonces los números coinciden con los de `config` por defecto: 10 de vida, mano 5, poción +3, límite 10, intercambio 1, 2, 3... (test de strings contra `Types.default_config`). |
| A4 | Dada la pantalla de ayuda, cuando se recorren sus textos, entonces ninguno contiene `_` ni claves internas, ninguno copia texto de una carta (revisión del Game Designer contra el manual) y todo lo marcado **[Digital]** lleva la etiqueta visible "Adaptación digital". |
| A5 | Dada una captura a 1080x1920 y a 720x1280, entonces ningún texto de la ayuda es menor de 22 px (a 1080) y se puede llegar a la última línea desplazando con el dedo. |
| A6 | Dado un sistema con `potion_limit_enabled = false`, cuando se muestra la ayuda de Too Much Mana dentro de una partida, entonces se dice que en esta partida no hay límite (el texto del límite lo toma de la configuración activa, no de un número fijo). La ayuda del menú principal usa el valor por defecto. |

## 5. Dudas para Narrative / usuario
- No requiere decisión del usuario: no hay regla nueva. El único punto de criterio de diseño es la línea de "No puedes jugar una defensiva en tu turno..." de 2.6: es la lectura literal ya registrada en `docs/AMBIGUEDADES.md` (T4, "Defensivas en tu propio turno") y la ayuda solo la comunica.

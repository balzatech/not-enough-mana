# Pantalla "Cómo se juega" (V2-09)

Autor: Narrative Designer. Fuente: `docs/diseno/ayuda-como-se-juega.md`. Código: `src/ui/strings_ayuda.gd` (`StringsAyuda`). Sin reglas nuevas. Lo marcado "Adaptación digital:" no está en el juego de mesa. Los números son los de `Types.default_config()` (la API los toma de la config activa).

Etiquetas: título "Cómo se juega"; botón "Volver"; pie "Ver una carta: mantén pulsada la carta."

## 1. Objetivo
- Eres un mago, de 3 a 6 en la mesa. Gana el último que siga en pie.
- Quedas fuera si te quedas en 0 de vida o por Too Much Mana.
- Empiezas con 10 de vida (es también tu máximo), 0 de maná y 5 cartas.
- El maná no tiene tope. Casi siempre te faltará.

## 2. Tu turno
- 1. Robas hasta tu límite de mano (normalmente 5). Si robas un evento, se aplica ya y robas otra carta.
- 2. Actúas las veces que quieras y en el orden que quieras: jugar cartas, descartar o intercambiar.
- 3. Terminas el turno.
- Si se acaba el mazo, se baraja el descarte y pasa a ser el mazo.
- Adaptación digital: empieza el mago de más edad (la que se indicó al crear la partida) y se sigue en sentido horario.

## 3. Pagar cartas y maná
- Para jugar una carta pagas su coste: maná y, a veces, cartas de tu mano de un tipo o elemento (por ejemplo, 1 carta de fuego). Las que pagas van al descarte con la jugada.
- Eventos y artefactos pueden cambiar el coste. La carta siempre muestra el coste actual.
- Los hechizos con objetivo también se pueden lanzar contra ti.
- Scroll of Elements: en mesa, sustituye una carta requerida de un coste (un solo uso).
- Intercambiar: descartas una carta, pagas y robas otra. El primero del turno cuesta 1 de maná, el segundo 2, el tercero 3...
- Si te obligan a descartar y no tienes cartas, pierdes 1 de maná por cada carta que no puedas descartar.
- Si tienes que perder más maná del que tienes, debes beber una poción en ese momento. Si no, pierdes tanta vida como maná te falte.
- Adaptación digital: el juego te lo pregunta en una pantalla de decisión.
- Tipos de carta: ofensivas (fuego, hielo, electricidad), defensivas, de apoyo, maldiciones, artefactos y eventos.

## 4. Pociones de maná
- Cada poción te da +3 de maná. Puedes beber en cualquier momento: también fuera de tu turno y mientras decides una reacción.
- Adaptación digital: se bebe con el botón "Beber poción", siempre disponible mientras sigas vivo. Lleva tu contador de pociones bebidas.
- Hay una reserva común de cristales (70 de vida y 70 de maná en total). Lo que ganas sale de ella; lo que pagas o pierdes vuelve. Si no quedan cristales de maná, las pociones no dan nada.
- Adaptación digital: en la mesa física son cristales; aquí es un contador que ves en la mesa.
- Algunas cartas cambian lo que da una poción (más o menos 1). Esta ayuda no las enumera.

## 5. Too Much Mana
- Adaptación digital: Too Much Mana sustituye al K.O. por beber demasiado de la mesa física: hay un límite de 10 pociones por partida (se puede desactivar al crear la partida).
- Adaptación digital: beber la poción número 11 te elimina y no te da el maná. El botón se pone ámbar desde 8/10 y rojo en 10/10, y te pide confirmación.
- Adaptación digital: tu contador de pociones nunca baja durante la partida.
- Si la partida no tiene límite: "Adaptación digital: Too Much Mana sustituye al K.O. por beber demasiado de la mesa física. En esta partida no hay límite de pociones."

## 6. Defensivas y reacciones
- Las cartas defensivas se juegan en respuesta a un hechizo, incluso fuera de tu turno (escudos, conejo helado, última voluntad, captura de maná, aniquilación).
- Un Lightning también puede responder a otro Lightning: el daño sube y se redirige.
- No puedes jugar una defensiva en tu turno si no hay un hechizo al que responder.
- Adaptación digital: ventana de reacción. Cuando alguien lanza un hechizo, decide un jugador a la vez: primero el objetivo y luego en sentido horario. Solo se espera a quien puede responder.
- Adaptación digital: cada uno juega una defensiva o pulsa Pasar. Si alguien responde, vuelven a decidir todos los que puedan. Cuando todos pasan, se resuelve primero la última respuesta.
- Adaptación digital: en línea hay un plazo para decidir; en local no, solo el botón Pasar.
- Adaptación digital: en Ajustes, "Avisarme de reacciones" elige si te interrumpe cualquier hechizo o solo los que te afectan (por defecto, solo esos). No cambia las reglas: si no te sale la ventana, es como pulsar Pasar.

## 7. Eventos
- Un evento aparece cuando alguien lo roba: se lee, se pone en el centro de la mesa y se aplica. Después, quien lo robó roba otra carta. En la mano inicial, el evento se descarta y se roba otra.
- Unos son inmediatos (curan o dañan a todos). Otros cambian las reglas hasta que aparezca el siguiente evento (por ejemplo: un elemento cuesta más pero hace más, las pociones dan menos, el límite de mano sube).
- El evento activo se ve en el centro de la mesa. Cuando llega uno nuevo, el anterior se va.

Aviso al salir un evento (`event_notice`):
- Activo: "Evento: <nombre>. Dura hasta el próximo evento."
- Instantáneo: "Evento: <nombre>. Efecto inmediato, no dura."

## 8. Artefactos y maldiciones
- Los artefactos se quedan en la mesa delante de su dueño y dan una ventaja mientras estén (o hasta que se usen).
- Las maldiciones quitan maná a los magos que cumplan su condición: edad, mes de nacimiento o vida.
- Curse of Rules deja una regla de mesa: quien la rompa pierde 1 de maná.
- Adaptación digital: hay un botón "Rompió la regla" para avisarlo.
- Adaptación digital: por eso, al crear la partida, se pide la edad y el mes de nacimiento de cada mago.

## Criterios A1-A6 (revisión de texto)
- A1 pasa: 8 secciones en el orden 2.1-2.8 (`sections()` devuelve 8); el botón "Volver" y la pantalla los hace V2-30.
- A2 no aplica a este texto (estado de la partida): lo cubre V2-30. El texto es estático y no depende del estado.
- A3 pasa: los números salen de `Types.default_config()` (10 vida, mano 5, poción +3, límite 10, intercambio 1, 2, 3, reserva 70/70). Falta el test automático (Developer).
- A4 pasa: sin "_" ni claves; no se copia texto de cartas; todo lo digital lleva el prefijo visible "Adaptación digital:" (`DIGITAL_TAG`).
- A5 no aplica a este texto (tamaño de fuente y desplazamiento): lo cubre V2-30. Las líneas son cortas.
- A6 pasa: con `potion_limit_enabled = false`, la sección Too Much Mana dice "En esta partida no hay límite de pociones"; el límite sale de la config. El menú principal llama sin config (valores por defecto).

Nota: la compilación (`tools/check_warnings.sh`) no se pudo ejecutar, porque este agente no tiene shell. Falta correrla.

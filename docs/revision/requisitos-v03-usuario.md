# Requisitos del usuario para la siguiente versión (2026-10-14)

Documento escrito por el usuario después de revisar el juego. Es la **fuente de verdad** para planificar la v0.3: el Director lo convierte en lineamientos y el Producer en tareas. Se transcribe sin cambios de contenido.

> Nota de la sesión principal: el texto recibido termina en la sección 8, en "Evitar interfaces confusas:", y podría estar incompleto. Pendiente de confirmar con el usuario.

---

# Mejoras y prioridades para el juego de magos y runas

## 1. Definir el alcance de la versión actual

- **Priorizar la versión contra bots:** por ahora, el juego debe centrarse exclusivamente en partidas locales contra bots. La funcionalidad de multijugador en línea se implementará más adelante, cuando tengamos Firebase configurado.
- **Crear una versión local completa:** antes de implementar el modo en línea, debemos conseguir una versión local que sea divertida, funcional, visualmente atractiva y que realmente valga la pena jugar.

## 2. Mejorar el diseño y la identidad visual

Actualmente, el juego tiene una apariencia demasiado plana, simple y poco trabajada. Es necesario mejorar considerablemente su presentación visual.

- **Definir una temática clara:** todo el juego debe tener una identidad visual basada en magos, magia, hechizos, runas, artefactos místicos y elementos fantásticos.
- **Mejorar el arte general:** rediseñar los elementos visuales para que tengan más personalidad, detalle y coherencia con la temática.
- **Rediseñar los botones:** mejorar su apariencia, tamaño, colores, iconos y estados visuales para que parezcan parte de un juego de magia y no de una aplicación genérica.
- **Mejorar los escenarios y las interfaces:** utilizar fondos, paneles, marcos, efectos y elementos decorativos que ayuden a construir una atmósfera mágica.
- **Evitar una apariencia demasiado básica:** conseguir una presentación visual cuidada y atractiva desde el primer momento.

## 3. Usabilidad, ergonomía y experiencia del usuario

El juego debe ser intuitivo, cómodo de utilizar y estar diseñado para que el jugador pueda realizar las acciones necesarias sin esfuerzo ni confusión. La ubicación de los botones debe responder a criterios de usabilidad y ergonomía, especialmente en dispositivos móviles.

- **Ubicar los botones estratégicamente:** colocar cada botón en una posición lógica según su función, frecuencia de uso y relación con los demás elementos. Las acciones más importantes deben ser fáciles de encontrar y ejecutar.
- **Optimizar la interfaz para jugar con el celular:** organizar los controles teniendo en cuenta cómo se sostiene el dispositivo y el alcance natural de los dedos. Evitar que el jugador tenga que estirar demasiado el pulgar o cambiar constantemente la forma de sujetar el celular.
- **Priorizar las acciones principales:** los botones de atacar, defenderse, confirmar acciones y finalizar turnos deben estar en posiciones visibles y accesibles cuando corresponda.
- **Evitar errores de pulsación:** utilizar botones con un tamaño táctil adecuado y suficiente separación entre ellos para reducir los toques accidentales.
- **Mostrar los controles cuando sean necesarios:** durante la fase de ataque, priorizar las opciones de ataque y selección de objetivos; durante la defensa, destacar las opciones defensivas y el temporizador correspondiente.
- **Mantener una jerarquía visual clara:** diferenciar las acciones principales de las secundarias mediante el tamaño, el contraste, los iconos y la ubicación, sin saturar la pantalla.
- **Evitar interfaces sobrecargadas:** mostrar únicamente la información necesaria para la fase actual del juego y mantener accesibles las opciones adicionales sin ocupar espacio importante durante el combate.
- **Adaptar la interfaz a diferentes pantallas:** comprobar que los botones, textos, temporizadores y paneles se visualicen correctamente en celulares de distintos tamaños y resoluciones.
- **Proporcionar retroalimentación visual:** los botones deben reaccionar al tocarlos y mostrar claramente si una acción está disponible, seleccionada, deshabilitada o en proceso.
- **Diseñar pensando en el jugador:** evitar que el usuario tenga que buscar controles, recordar ubicaciones poco intuitivas o realizar pasos innecesarios para completar una acción.

**Criterio de aceptación:** evaluar cada pantalla durante una partida real para comprobar que los controles están donde el jugador espera encontrarlos, que las acciones frecuentes se ejecutan cómodamente y que la interfaz no dificulta la lectura del combate. La ergonomía debe priorizar la comodidad, la accesibilidad y la claridad por encima de la decoración visual.

## 4. Incorporar animaciones y efectos visuales

El juego necesita más movimiento y respuestas visuales para que las acciones se sientan satisfactorias.

- **Animar los ataques:** cada hechizo debe tener una animación que permita identificar qué acción se está realizando y hacia dónde se dirige.
- **Animar las defensas:** los escudos, bloqueos y otras habilidades defensivas deben tener efectos visuales propios.
- **Animar la colocación de elementos:** mejorar la animación de colocar runas, cartas, hechizos u otros elementos del juego para que las acciones no aparezcan de forma instantánea o brusca.
- **Añadir efectos mágicos:** incorporar partículas, destellos, círculos rúnicos, explosiones mágicas y otros efectos acordes con la temática.
- **Mejorar las transiciones:** hacer que los cambios de turno, las acciones y los resultados de los combates se desarrollen de forma fluida.
- **Mantener la claridad:** las animaciones deben ayudar a entender lo que sucede, no dificultar la lectura ni retrasar innecesariamente la partida.

## 5. Rediseñar el sistema de ataque

Actualmente, atacar resulta poco intuitivo porque no queda claro a quién se está atacando ni cómo se ejecuta la acción.

- **Hacer visible a los objetivos:** mostrar claramente qué magos pueden ser atacados y cuáles son los objetivos válidos.
- **Permitir seleccionar el objetivo:** cuando una acción requiera elegir un enemigo, el jugador debe poder identificarlo y seleccionarlo de manera sencilla.
- **Mostrar el objetivo seleccionado:** resaltar visualmente al mago elegido mediante un contorno, un indicador, una marca rúnica u otro recurso visual.
- **Explicar el ataque antes de ejecutarlo:** mostrar qué hechizo se utilizará, a quién afectará y qué efecto tendrá cuando esa información sea relevante.
- **Dar una respuesta visual al ataque:** una vez ejecutada la acción, mostrar claramente el recorrido del hechizo y su impacto sobre el objetivo.
- **Indicar el resultado:** comunicar si el ataque acertó, fue bloqueado, causó daño o produjo algún otro efecto.
- **Evitar acciones ambiguas:** el jugador nunca debería tener que adivinar a quién está atacando ni si su acción se ejecutó correctamente.

## 6. Rediseñar el sistema de defensa

La defensa también debe ser más clara y fácil de entender, especialmente cuando otro mago está atacando.

- **Avisar cuando el jugador recibe un ataque:** mostrar una notificación visible que indique que el mago está siendo atacado.
- **Identificar al atacante:** comunicar claramente qué mago está realizando el ataque y, cuando corresponda, qué hechizo está utilizando.
- **Indicar que comienza la fase de defensa:** la interfaz debe dejar claro que el jugador tiene la oportunidad de defenderse.
- **Mostrar las opciones defensivas disponibles:** presentar las defensas que puede utilizar y explicar de forma sencilla qué hace cada una.
- **Permitir una respuesta intuitiva:** el jugador debe poder elegir su defensa sin tener que descubrir por ensayo y error cómo funciona el sistema.
- **Mostrar el resultado de la defensa:** indicar claramente si el ataque fue bloqueado, reducido o si impactó al mago.

## 7. Implementar un sistema de turnos con temporizadores

Cada fase debe tener un tiempo límite visible y configurable para mantener el ritmo de la partida.

### Turno de ataque

- **Duración predeterminada:** 30 segundos por turno.
- **Temporizador visible:** mostrar una cuenta regresiva clara y destacada durante todo el turno.
- **Identificación del turno:** indicar de forma prominente qué mago está jugando y qué debe hacer.
- **Finalización automática:** si el tiempo termina sin que el jugador realice una acción válida, el turno debe finalizar y pasar al siguiente mago según las reglas del juego.
- **Configuración del tiempo:** permitir modificar la duración del turno desde las opciones del juego.

### Fase de defensa

- **Duración predeterminada:** 20 segundos para responder a un ataque.
- **Aviso inmediato:** al recibir un ataque, mostrar una notificación clara de que comienza el tiempo para defenderse.
- **Temporizador independiente:** mostrar una cuenta regresiva específica para la fase defensiva.
- **Finalización automática:** si el jugador no elige una defensa dentro del tiempo establecido, aplicar la regla predeterminada de defensa o ausencia de respuesta y continuar la partida.
- **Configuración del tiempo:** permitir modificar la duración de la fase defensiva desde las opciones del juego.

### Reglas generales de los temporizadores

- Los tiempos de ataque y defensa deben poder configurarse por separado.
- La interfaz debe diferenciar visualmente el tiempo de ataque del tiempo de defensa.
- El temporizador debe actualizarse correctamente y no reiniciarse de manera inesperada.
- Los cambios de fase deben ser claros, tanto visualmente como en el funcionamiento del juego.
- El sistema debe funcionar correctamente en las partidas locales contra bots.

## 8. Mejorar la experiencia general de juego

- **Hacer que las reglas sean fáciles de comprender:** el jugador debe entender qué puede hacer, cuándo puede hacerlo y qué consecuencias tendrá cada acción.
- **Mostrar información importante en el momento adecuado:** turnos, objetivos, ataques, defensas, efectos y tiempos restantes deben ser fáciles de identificar.
- **Evitar interfaces confusas:** _(el texto recibido termina aquí)_

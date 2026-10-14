# Visión: Not Enough Mana (versión digital, uso personal)

Mantiene: Game Director. Última revisión: 2026-10-13 (tras el MVP local).

> **Derechos.** El juego, sus reglas, su arte y sus textos son © SUPERHOTEX sp. z o.o. Esta adaptación es de **uso personal** para un grupo de amigos. No se publica ni se distribuye con sus assets. Cualquier propuesta que lo contradiga se rechaza.

## Concepto
Adaptación fiel del juego de cartas físico *Not Enough Mana*: un duelo **caótico y social** de 3 a 6 magos que se lanzan hechizos, maldiciones y artefactos hasta que solo queda uno, siempre al borde de quedarse sin maná o de pasarse con las pociones (*Too Much Mana*).

## Género y plataforma
- Cartas por turnos, todos contra todos, 3-6 jugadores, partidas cortas.
- **Celular en vertical** (referencia de diseño: 1080×1920; mínimo legible: 720×1280) y **navegador**.
- Modos: local (hot-seat en un solo dispositivo + bots) y, más adelante, en línea por salas.

## Público
Un grupo concreto de amigos hispanohablantes que conoce o va a conocer el juego físico. Juegan juntos en la misma habitación (hot-seat o cada uno con su celular) o a distancia hablando por voz. Algunos juegan solos contra bots para aprender o pasar el rato. No es un público de jugadores competitivos de cartas: se valora reírse más que optimizar.

## Experiencia deseada
1. **Caos que se entiende.** Pasan muchas cosas y no todas en tu turno, pero siempre sabes **qué te acaba de pasar, quién fue y por qué**.
2. **Tensión con las pociones.** Beber es tentador y peligroso: el contador de pociones de todos está a la vista y el riesgo se nota.
3. **Interacción y revancha.** Responder a un hechizo (un escudo, un Lightning devuelto, un espejo) es el momento estelar; debe sentirse rápido y dramático, no burocrático.
4. **Ritmo.** Poco tiempo muerto: los bots juegan rápido pero de forma legible, no hay confirmaciones inútiles y en hot-seat el dispositivo se pasa solo cuando hace falta.
5. **Mesa social.** Las maldiciones de edad y mes, *Curse of Rules* y el botón "Rompió la regla" hacen que la gente hable entre sí; la app las facilita, no las sustituye.

## Pilares (resumen; detalle en `docs/revision/LINEAMIENTOS.md`)
- **D1 Caos legible.** Cada cambio de vida, maná o estado tiene feedback visible en el mago afectado.
- **D2 Riesgo visible.** Pociones, maná y amenazas se leen de un vistazo.
- **D3 Reacción como clímax.** Ventana de reacción breve y clara, solo cuando de verdad puedes y quieres responder.
- **D4 Ritmo sin esperas.** Cada pantalla o toque extra tiene que estar justificado.
- **U1 Sé qué puedo hacer.** Lo jugable se distingue; lo no jugable explica por qué.
- **U2 Legible en el celular.** Texto y botones pensados para el pulgar y una pantalla de 720 px de ancho.
- **U3 Interfaz honesta.** No se muestra nada que no funcione todavía.

## Lo que lo diferencia (para este grupo)
- Es *su* juego de mesa favorito sin tener que imprimir cartas ni llevar la cuenta de vida, maná y pociones a mano.
- El motor aplica las reglas (también las raras) sin discusiones; los bots permiten jugar con menos de 3 personas.

## Fuera de alcance
- **Rediseñar reglas o cartas**, o reescribir/traducir el arte. Los cambios de reglas con efecto real los decide el usuario.
- **Publicar o distribuir** (tiendas, hosting público, repositorios públicos con assets).
- Monetización, cuentas con datos personales, clasificaciones globales, chat de texto dentro del juego (el grupo habla por voz o en persona).
- Campaña, historia o progresión entre partidas.
- **Alcohol real:** en el físico la poción es un trago. La app trata la poción solo como recurso del juego: ni incita a beber de verdad ni lleva la cuenta de bebidas reales.
- Gráficos 3D o efectos que comprometan el rendimiento en Web o en un Android de gama media.

## Estado
- MVP local terminado (RF1-RF11 sin red).
- **v0.2 "Mesa legible" cerrada a falta de la prueba humana M12** (2026-10-13): feedback en paneles, registro de 3 líneas, cartas jugables y ficha en español, pago explícito, preferencia de reacción, pantalla de fin con resumen, bots sin suicidio, ayuda y legibilidad móvil. Evaluación: `docs/revision/evaluacion-v02.md`.
- Propuesta siguiente (pendiente de E8/E9 del usuario): **v0.3 "En el celular"** (build Android, memoria y rendimiento en el dispositivo, Conjunción astral, audio) y después el multijugador en línea (B1, v0.4).

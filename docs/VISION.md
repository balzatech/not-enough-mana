# Visión: Not Enough Mana (versión digital, uso personal)

Mantiene: Game Director. Última revisión: 2026-10-14 (foco de la v0.3: versión local completa contra bots).

> **Derechos.** El juego, sus reglas, su arte y sus textos son © SUPERHOTEX sp. z o.o. Esta adaptación es de **uso personal** para un grupo de amigos. No se publica ni se distribuye con sus assets. Cualquier propuesta que lo contradiga se rechaza. El arte nuevo de interfaz sale de **packs libres aprobados por el usuario** (CC0, CC BY con atribución, SIL OFL) y de efectos propios por código; el arte de las cartas no se toca.

## Concepto
Adaptación fiel del juego de cartas físico *Not Enough Mana*: un duelo **caótico y social** de 3 a 6 magos que se lanzan hechizos, maldiciones y artefactos hasta que solo queda uno, siempre al borde de quedarse sin maná o de pasarse con las pociones (*Too Much Mana*).

## Género y plataforma
- Cartas por turnos, todos contra todos, 3-6 jugadores, partidas cortas.
- **Celular en vertical** (referencia de diseño: 1080×1920; mínimo legible: 720×1280; también pantallas 20:9) y **navegador**.
- Modos, por orden de llegada: **local contra bots** (1 persona + 2-5 bots; foco actual), después en el celular por **Web en red local**, y más adelante **en línea** por salas. El hot-seat (varias personas en un dispositivo) existe en el código pero está **oculto** por ahora.

## Público
Un grupo concreto de amigos hispanohablantes que conoce o va a conocer el juego físico. Ahora mismo, sobre todo **una persona jugando contra bots** para divertirse, aprender las cartas y probar el juego; después, el grupo junto o a distancia hablando por voz. No es un público de jugadores competitivos de cartas: se valora reírse más que optimizar.

## Experiencia deseada
1. **Caos que se entiende.** Pasan muchas cosas y no todas en tu turno, pero siempre sabes **qué te acaba de pasar, quién fue y por qué**; nunca adivinas a quién atacas ni si tu acción se ejecutó.
2. **Tensión con las pociones.** Beber es tentador y peligroso: el contador de pociones de todos está a la vista y el riesgo se nota.
3. **Interacción y revancha.** Defenderte (un escudo, un Lightning devuelto, un espejo) es el momento estelar: un aviso claro de quién te ataca, un tiempo visible para responder y un resultado que se ve.
4. **Ritmo.** Turno y defensa con tiempo límite visible; los bots juegan rápido pero de forma legible; animaciones que explican y no hacen esperar.
5. **Atmósfera de magos.** Runas, artefactos, círculos mágicos y luz arcana sobre la noche violeta: desde la primera pantalla parece un juego de magia, no una aplicación.
6. **Mesa social.** Las maldiciones de edad y mes, *Curse of Rules* y el botón "Rompió la regla" hacen que la gente hable entre sí; la app las facilita, no las sustituye.

## Pilares (detalle en `docs/revision/LINEAMIENTOS.md` para v0.2 y `docs/revision/LINEAMIENTOS-v03.md` para v0.3)
- **D1 Caos legible.** Cada cambio de vida, maná o estado tiene feedback visible en el mago afectado, con su origen.
- **D2 Riesgo visible.** Pociones, maná y amenazas se leen de un vistazo.
- **D3 Defensa como clímax.** Aviso, atacante, opciones explicadas, temporizador propio y resultado claro; solo cuando de verdad puedes responder.
- **D4 Ritmo sin esperas.** Cada pantalla, toque o animación extra tiene que estar justificado; temporizadores para no estancarse.
- **D5 Identidad mágica.** Paleta, tipografía, marcos, botones, fondos y efectos coherentes con magos y runas, sin restar legibilidad.
- **U1 Sé qué puedo hacer.** Lo jugable se distingue; lo no jugable explica por qué; lo que no aplica a la fase no se muestra.
- **U2 Hecho para el pulgar.** Acciones frecuentes en la mitad inferior, un solo botón principal por fase, botones grandes y separados, texto legible a 720 px.
- **U3 Interfaz honesta.** No se muestra nada que no funcione todavía.
- **Regla de desempate (del usuario):** la ergonomía y la claridad mandan sobre la decoración.

## Lo que lo diferencia (para este grupo)
- Es *su* juego de mesa favorito sin tener que imprimir cartas ni llevar la cuenta de vida, maná y pociones a mano.
- El motor aplica las reglas (también las raras) sin discusiones; los bots permiten jugar solo o con menos de 3 personas.

## Fuera de alcance
- **Rediseñar reglas o cartas**, o reescribir/traducir el arte. Los cambios de reglas con efecto real los decide el usuario (los temporizadores y el límite de pociones desactivado son adaptaciones digitales decididas por él).
- **Publicar o distribuir** (tiendas, hosting público, repositorios públicos con assets).
- Monetización, cuentas con datos personales, clasificaciones globales, chat de texto dentro del juego (el grupo habla por voz o en persona).
- Campaña, historia o progresión entre partidas.
- **Alcohol real:** en el físico la poción es un trago. La app trata la poción solo como recurso del juego: ni incita a beber de verdad ni lleva la cuenta de bebidas reales.
- Gráficos 3D o efectos que comprometan el rendimiento en Web o en un Android de gama media.
- Arte de interfaz descargado sin aprobación del usuario o con licencia dudosa.
- **En v0.3 en concreto:** modo en línea, hot-seat, builds Android/Web, audio, tutorial guiado.

## Estado
- MVP local terminado (RF1-RF11 sin red).
- v0.2 "Mesa legible" cerrada (2026-10-13): feedback en paneles, registro, cartas jugables y ficha en español, pago explícito, preferencia de reacción, pantalla de fin, bots sin suicidio, ayuda y legibilidad. Evaluación: `docs/revision/evaluacion-v02.md`. El usuario la jugó y escribió sus requisitos para la siguiente (`docs/revision/requisitos-v03-usuario.md`).
- **Ahora: v0.3 "Versión local completa contra bots"** (2026-10-14): identidad visual de magos y runas, ergonomía de pulgar, ataque y defensa rediseñados, temporizadores de 30 s y 20 s, animaciones. Lineamientos: `docs/revision/LINEAMIENTOS-v03.md`.
- Después: **v0.4 "En el celular"** (Web en red local, memoria, prueba táctil, audio) y **v0.5 en línea** (B1).

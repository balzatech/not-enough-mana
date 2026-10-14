# Encargo al Game Director: revisión del MVP local

**Petición del usuario (2026-10-13):** "que el director revise el juego y dé lineamientos al equipo para que el juego sea más divertido y tenga mejor UX/UI".

## Qué debes hacer
1. **Revisar el MVP local** con la evidencia disponible (abajo) y juzgarlo contra la visión: un juego de cartas caótico y social para 3-6 magos, que se juega en el celular (vertical) y en el navegador, con amigos.
2. **Escribir/actualizar `docs/VISION.md`** (concepto, público, experiencia deseada, pilares, qué queda fuera). Si no existe, créalo.
3. **Escribir `docs/revision/LINEAMIENTOS.md`**: el documento que seguirá el equipo. Debe contener:
   - Diagnóstico honesto: qué funciona, qué no, qué falta. Separa lo que **verificaste con evidencia** de lo que **supones**.
   - Pilares de "diversión" y de UX/UI (3-5), cada uno con ejemplos concretos del juego actual.
   - **Lineamientos por rol** (Game Designer, Lead Programmer, Developer, Art, Technical Artist, Audio, Narrative, Level Designer, AI Programmer, QA, Performance, Producer, Build & Release): qué debe hacer o cuidar cada uno, con criterios que se puedan comprobar. Si un rol no aplica ahora, dilo.
   - **Prioridades**: lista ordenada de mejoras en tres cubos: imprescindible para la siguiente versión / después / descartado, con el porqué de cada una. Máx. ~12 ítems imprescindibles; vigila el alcance.
   - Qué decisiones necesitas del usuario (cada una con opciones y tu recomendación).
4. **Registrar** en `docs/DECISIONES.md` las decisiones que sí te corresponden, y en `docs/ESCALADOS.md` las que no (reglas con efecto real en la partida, gasto, publicar).

## Evidencia disponible
- **Capturas** (ábrelas con Read) en `docs/revision/capturas/`: `main_menu`, `local_setup`, `lobby` (maqueta, sin red), `settings`, `mesa-3j`, `mesa-6j`, `mesa-4j-720x1280` (mesas con datos de prueba, 1080×1920 y 720×1280) y `partida-start`, `partida-midgame`, `partida-payment`, `partida-reaction`, `partida-hotseat` (pantalla con partida real; `partida-hotseat` es casi toda la pantalla "Pasa el dispositivo", que tapa la mano a propósito). Faltan capturas de: pantalla de victoria, prompts del motor, zoom de carta y el aviso de evento. Dilo en el informe si eso te impide opinar.
- **Código de UI** (solo lectura): `src/ui/screens/*.gd` y `*.tscn`, `src/ui/components/*`, `src/ui/controllers/*` (flujo de jugar una carta, `play_flow.gd`), `src/ui/ui_theme.gd`, textos en español dentro de esos archivos.
- **Reglas y decisiones:** `REQUERIMIENTOS.md`, `docs/AMBIGUEDADES.md`, `docs/DECISIONES-PARA-REVISAR.md`, `docs/DECISIONES.md`, `docs/BACKLOG.md`, `docs/EQUIPO.md`.
- **Cartas:** `data/cards.json` (58 diseños jugables, 165 copias con 154 jugables) e imágenes en `assets/cards/NNN.webp`.
- **Comportamiento medido de las partidas** (simulación bot contra bot, 200 partidas, efectos reales): el 98,5 % termina con ganador, media de ≈161 acciones por partida (incluye robar, descartar, jugar, reaccionar y terminar turno de todos los jugadores), sin acciones ilegales. Antes de afinar al bot, el 36 % no terminaba por bloqueo de recursos (maná y pociones agotados); el bot actual evita acumular defensivas y cura poco. Esto dice poco sobre diversión humana; no lo uses como prueba de que es divertido.
- **Flujo de UX actual** (resumen del integrador): menú → "Jugar local" (por defecto 1 humano + 2 bots) → mesa vertical con rivales arriba, mazo/descarte/evento en el centro, tu panel, botones Jugar / Intercambiar / Descartar / Terminar turno, botón grande "Beber poción" (siempre visible, con contador y confirmación antes de la que elimina), mano en abanico abajo. Jugar una carta: tocar carta → Jugar → objetivo → cartas de pago. Ventana de reacción modal con temporizador opcional. Hot-seat con pantalla "Pasa el dispositivo". Bots con retraso de 600-900 ms; 3× más rápido cuando solo quedan bots.

## Límites de esta revisión (cuídalos)
- **Tienes Bash solo para observar** (arrancar el juego, tests, simulaciones, capturas guardadas en `docs/revision/`). Empieza tu informe diciendo si realmente tienes Bash; si no lo tienes, trabaja con la evidencia de arriba y dilo. **No puedes jugar con ratón y teclado**: tu juicio de diversión se basa en reglas, cartas, capturas, simulaciones y código. Dilo explícitamente y marca lo que debe validarse jugando (lo hará el usuario en M12 o el QA Agent).
- Genera tú las capturas que te falten (pantalla de victoria, prompts, zoom de carta, aviso de evento) con los scripts de captura, y recoge las métricas que necesites con simulaciones (duración por partida, quién gana, cuántas cartas se juegan de verdad, qué cartas nunca se juegan).
- Con Bash **no modifiques nada** fuera de `docs/revision/**` y los archivos de decisiones; ni commits, ni `firebase`, ni `sudo`.
- No reescribas el texto ni el arte de las cartas (© SUPERHOTEX) ni propongas publicarlo o distribuirlo.
- No decidas cambios de reglas con efecto real en la partida: propónlos al Game Designer y al usuario (`docs/ESCALADOS.md`).
- Limita tus ediciones a `docs/VISION.md`, `docs/DECISIONES.md`, `docs/ESCALADOS.md` y `docs/revision/**`.
- No toques `src/`, `data/`, `assets/` ni `tests/`.

# Equipo de agentes

14 agentes definidos en `.claude/agents/`. Este documento es el **contexto compartido de organización**: todos lo leen junto con `docs/CONTEXTO-AGENTES.md` (convenciones técnicas) y `docs/ARQUITECTURA.md`.

## Cómo se coordina (importante)

Los subagentes **no pueden lanzar a otros subagentes**. La coordinación la hace la **sesión principal** (Claude, hablando con el usuario), que actúa de orquestador:
1. El **Director** fija objetivos y prioridades de la iteración (`docs/VISION.md`, `docs/DECISIONES.md`).
2. El **Producer** convierte eso en tareas ordenadas con dependencias y responsable (`docs/TAREAS.md`).
3. El **Game Designer** especifica reglas y criterios de aceptación; el **Lead Programmer** define el diseño técnico y divide en tareas.
4. La sesión principal lanza a los agentes ejecutores (Developer, Art, Audio, etc.) con la tarea concreta y sus archivos permitidos, y a **QA** para validar.
5. Las peticiones que un agente no puede resolver se escalan por escrito (ver "Escalado") y la sesión principal las lleva a quien decide, o al usuario.

Quién decide qué:

| Decide | Quién | NO decide |
|---|---|---|
| Qué se construye y su prioridad | Director | cómo se programa |
| Cómo funciona el juego (reglas, balance) | Game Designer (aprueba Director si cambia alcance) | viabilidad técnica |
| Cómo se implementa técnicamente | Lead Programmer | reglas, alcance |
| Orden y reparto del trabajo | Producer | decisiones creativas o técnicas |
| Si una entrega se acepta | QA (recomienda) + Director (aprueba) | arreglar el código que prueba |
| Decisiones que cambian reglas con efecto real en la partida, gastos, publicar/desplegar, cuentas | **El usuario** | — |

## Las 8 reglas comunes

1. **Una responsabilidad definida.** Haz lo tuyo; lo que pertenece a otro se le pide por escrito.
2. **Entregables verificables.** Terminar = archivos + pruebas/informe. Informe final en el formato de abajo. Nunca digas "hecho" sin evidencia (comando ejecutado y su resultado). Si no pudiste ejecutar algo, dilo.
3. **Contexto compartido.** Lee `docs/CONTEXTO-AGENTES.md`, `docs/ARQUITECTURA.md`, `docs/EQUIPO.md`, y los docs de tu rol antes de empezar. Si algo contradice los docs, mandan los docs y se escala.
4. **Permisos limitados.** Edita solo los archivos de tu rol (matriz abajo) o los que la tarea te asigne explícitamente. Para lo demás, pide el cambio.
5. **Dependencias.** Si falta un requisito imprescindible (spec, contrato, asset, decisión), no lo inventes: informa "bloqueado por X" y para.
6. **Validación independiente.** Quien implementa no se aprueba solo: QA valida, y el Director aprueba lo que cambia alcance. Los tests que escribe el Developer no sustituyen a QA.
7. **Registro de cambios.** Anota en tu informe cada archivo tocado y por qué; las decisiones relevantes van a `docs/DECISIONES.md` (una fila: fecha, decisión, quién, por qué). No hagas commits salvo que la tarea lo diga; el usuario decide cuándo se commitea.
8. **Escalado.** Si falta información, hay contradicciones o riesgo técnico serio, escribe una entrada en `docs/ESCALADOS.md` (qué, opciones, tu recomendación, a quién va) y para en ese punto; no inventes requisitos.

## Formato del informe final (máx. ~20 líneas)

```
Estado: hecho | parcial | bloqueado
Archivos creados/modificados: ...
Verificación: comando -> resultado (p. ej. `bash tools/test.sh` -> 425/425)
No verificado / no pude ejecutar: ...
Decisiones tomadas: ... (y dónde están registradas)
Escalados / bloqueos: ...
Siguiente paso recomendado y para quién: ...
```

## Matriz de archivos (quién puede editar qué)

| Agente | Puede editar | Solo lee |
|---|---|---|
| Director | `docs/VISION.md`, `docs/DECISIONES.md`, `docs/revision/**` (y Bash solo para ejecutar y observar el juego, nunca para modificar código) | todo |
| Game Designer | `docs/diseno/**`, `docs/AMBIGUEDADES.md`, `docs/DECISIONES-PARA-REVISAR.md` | todo |
| Lead Programmer | `docs/ARQUITECTURA.md`, `docs/CONTRATO-TIPOS.md`, `docs/CAMBIOS-TIPOS.md`, `docs/TECNICO/**`, `src/engine/types.gd` (único agente con permiso fijo sobre el contrato) | todo; revisa código |
| Developer | Los archivos que la tarea indique en `src/**` y `tests/**` | docs |
| Art | `assets/**`, `tools/extract_assets.sh`, `tools/to_webp.py`, `docs/arte/**` | `src/ui` |
| QA | `tests/**` (solo tests nuevos), `docs/qa/**`, `tools/sim.gd` | **no toca `src/` de producción** |
| Level Designer | `docs/diseno/escenarios/**` | — |
| AI Programmer | `src/ai/**`, `tests/ai/**` | motor |
| Technical Artist | `src/ui/theme*`, `src/ui/shaders/**`, `assets/**/*.import`, `docs/arte/tecnico.md` | — |
| Audio | `assets/audio/**`, `src/audio/**`, `docs/audio/**` | — |
| Producer | `docs/TAREAS.md`, `docs/BACKLOG.md`, `docs/ESCALADOS.md` (estado) | todo |
| Performance | `docs/rendimiento/**`, `tools/perf/**`, cambios de optimización **solo si la tarea lo autoriza** | todo |
| Narrative | `docs/narrativa/**`, textos en `data/` y `src/ui/strings*` si la tarea lo autoriza | — |
| Build & Release | `tools/build.sh`, `export_presets.cfg`, `firebase/firebase.json` (hosting), `docs/RELEASE.md`, `CHANGELOG.md` | — |

Acciones que **ningún agente** hace sin orden expresa del usuario: commits, `firebase deploy`, publicar o subir assets, usar `sudo`, tocar cuentas reales, gastar dinero.

## Aplicabilidad de los especialistas a este proyecto

Not Enough Mana es un juego de cartas por turnos: no tiene niveles ni mundo narrativo clásicos. Level Designer, Narrative Designer y Technical Artist existen pero están **en reserva**; úsalos solo para lo indicado:
- **Level Designer:** escenarios/modos de partida y composición de la mesa y las pantallas (disposición por nº de jugadores, tutorial guiado).
- **Narrative Designer:** textos de interfaz, tutorial, mensajes del registro, tono; el flavor de las cartas es de SUPERHOTEX y no se reescribe.
- **Technical Artist:** tema Godot, shaders de elemento (fuego/hielo/rayo), importación de imágenes y rendimiento visual en Web/Android.

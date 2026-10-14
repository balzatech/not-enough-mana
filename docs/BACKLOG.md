# Backlog (post-MVP local)

Estado a 2026-10-13: el MVP local está hecho (RF1-RF11 salvo multijugador): 58 cartas con efecto, ventana de reacción, bots (98,5 % de partidas terminadas), UI de mesa, hot-seat. 425/425 tests, 0 warnings. **Sin commits todavía** (el usuario pidió commitear cuando el MVP local funcione y lo confirme).

Este backlog lo mantiene el **Producer**. Cada ítem indica responsable sugerido y criterio de aceptación (lo refina el Game Designer / Lead Programmer).

## Orden de iteraciones (decidido el 2026-10-13, ver `docs/DECISIONES.md`)
1. **v0.2 "Mesa legible"** (ahora). Plan detallado en `docs/TAREAS.md`.
2. **B1 Multijugador en línea** (después de v0.2; bloqueado además por M3-M5).
3. **v0.3** (abajo). B2 y B3 pueden ir en paralelo con B1 cuando haya hueco.

## Pendientes de decisión del usuario
- Probar el MVP local (M12) y confirmar para el primer commit. Para v0.2, M12 se hace al final con el guion de QA (`docs/qa/guion-m12.md`, tarea V2-31).
- `docs/DECISIONES-PARA-REVISAR.md` (14 decisiones de reglas; sobre todo Elixir Transmutation). La ventana de reacción en local se queda como está (E5, resuelto); para el modo en línea se decide al diseñar B1.
- E2 Partida rápida: aplazada hasta medir la duración real (M12).

## v0.2 "Mesa legible"  *(prioridad actual)*
Los 12 ítems de `docs/revision/LINEAMIENTOS.md` §4 (feedback de paneles, registro de 3 líneas, cartas jugables y ficha, pago explícito, cartas legibles, interfaz honesta, preferencia de reacción, pantalla de fin con resumen, bots sin suicidio, contexto y riesgo, "Cómo se juega", legibilidad móvil) más: la **ficha en español** de cada carta (datos mecánicos generados + resumen de una línea de Narrative, solo dentro de la app; decisión E1), el bus de eventos de presentación y la división de `table.gd`. Oleadas, responsables, archivos y criterios: `docs/TAREAS.md`. Estado tras la oleada 1 (2026-10-13): oleada 1 cerrada, puerta V2-21 validada por QA y **aprobada con cambios por el Director** (465/465 tests, 200/200 partidas de bots, 0 eliminaciones por Too Much Mana, línea base corregida en `docs/qa/metricas-base.md`). Tareas nuevas en la oleada 2-3: V2-14d, V2-39, V2-40, V2-41, V2-42, V2-43 (condicional), V2-44 (opcional), V2-45 (icono Eliminado). Tope de 2 agentes simultáneos. Tamaño táctil: 144 px a 1080 en botones de acción principal, 96 px en el resto.

## v0.3  *(después de v0.2, y en paralelo o tras B1 según decida el Director)*
Cada ítem lo refina el Game Designer / Lead Programmer cuando se abra la iteración.

**Orden de v0.3 fijado por el Director (2026-10-13, V2-36; propuesta "En el celular", B1 pasaría a v0.4: pendiente de E8 y E9 del usuario).** Detalle, motivos y "hecho cuando" en `docs/revision/evaluacion-v02.md` §4:
1. v0.2.1: arreglos que pida M12 (solo si hay "no" o "a veces").
2. E6 aplicada según decida el usuario tras M12 (límite y/o variante anti-bloqueo).
3. Build Android de depuración (Web solo en la red local si el usuario la elige; nunca hosting público).
4. Memoria de texturas (~290 MB) y rendimiento medidos y reducidos en el dispositivo.
5. Prueba M12-bis en el celular (táctil y legibilidad).
6. Mano legible con la ficha abierta en 5-6 jugadores (QA-V2-35-06).
7. Conjunción astral (opción desactivada por defecto).
8. Audio mínimo y vibración en Android.
9. Bots que usan las 15 cartas que nunca se juegan (sin cambiar reglas).
10. Meta de 16 ms (decisión del bot fuera del fotograma, P2b; P3/P4).
Después de v0.3: animaciones de cartas y efectos por elemento, tutorial guiado (solo si M12 lo pide), estilos y velocidad de bots, variante por equipos, partida rápida (E2, según los minutos de M12). La lista de abajo se conserva como detalle de cada ítem.
- **Conjunción astral** como opción **desactivada por defecto** (E4, resuelto): los eliminados beben y quitan 1 de maná a los vivos. Game Designer (especificación y criterios), Developer, QA. Es un cambio de reglas opcional: el usuario aprueba la especificación final.
- **Audio** (efectos sintetizados o propios, desactivados por defecto; los ajustes de volumen reaparecen) y vibración en Android. Audio, Developer.
- **Animaciones de cartas** (robar, jugar, descartar) y opción "Reducir animaciones". Developer, Technical Artist.
- **Efectos por elemento** (fuego, hielo, rayo; `CPUParticles2D`, compatibles con Web). Technical Artist.
- **Tutorial guiado** con mazo preparado. Level Designer, Narrative.
- **Velocidad de bots** configurable (Normal / Rápido) y estilos de bot. AI Programmer, Developer.
- **Ficha en español**: solo si no se completa en v0.2 (los resúmenes V2-11 a V2-12 y V2-28 son las tareas que podrían moverse).
- Variante por equipos (si el usuario la quiere).
- **Seguimiento del Game Designer (de `docs/qa/metricas-base.md`, V2-02):** 14 de 47 cartas no-evento no se juegan nunca en 200 partidas de bots (magic_capture, annihilation, space_shift, curse_of_rules, fireproof_tiara, padded_boots, faradays_cloak, wild_fire, dragon_glass, tesla_coil, spellbook, scroll_of_elements, transformation_glove, twardowskys_mirror). Revisar con la línea base corregida (V2-38) cuántas siguen sin jugarse, y si es la heurística del bot (que no usa artefactos ni utilidades) o la carta. **Sin cambiar reglas**; cualquier cambio con efecto en la partida lo decide el usuario.
- **Memoria de texturas (~280 MB, `docs/rendimiento/v02-base.md` §2):** no afecta al escritorio; revisar antes de M13/M14 (builds Android y Web, aún inexistentes). Lead Programmer + Technical Artist.
- **Bloqueo por límite de pociones (E6):** si tras V2-42 sigue habiendo > 2 % de partidas > 100 turnos o un humano puede atascarse, implementar la opción que elija el usuario según V2-43 (cambio de regla: solo con su aprobación).
- **Si no caben en v0.2:** V2-44 (registro redundante en la reacción) y la optimización del fotograma con acción hasta <= 16 ms (V2-34 informa).
- Mejorar la medición: la duración en minutos no sale de la simulación (solo turnos y pasos); se mide en M12.

## B1. Multijugador en línea (Firebase)  *(después de v0.2)*
Bloqueado por tareas manuales M3-M5 (Java 17, proyecto Firebase con Auth anónima + Realtime Database, `firebase login`).
1. **Prueba de concepto de cliente Firebase en Godot** (Developer, apoyo Lead Programmer). Evaluar addon GodotFirebase en Android **y** Web contra el Emulator Suite (`auth,database`). Si el streaming no funciona en Web: `JavaScriptBridge` + SDK JS detrás de la misma interfaz `firebase_client.gd`. Documentar decisión en `docs/RED.md`. Si no hay solución viable, el Director decide si Web sale del MVP en línea.
2. **Capa de red** (Developer): `src/net/firebase_client.gd` (auth anónima, get/set/update/push/remove/listen, reintentos), `room_service.gd` (código de sala de 5 caracteres sin 0/O/1/I, máx. 6, unirse solo en lobby), `state_view.gd` (separación público/privado sin fugas), `firebase/database.rules.json` (el miembro A no lee `private/B`, un no miembro no lee la sala, un cliente no escribe `public`).
3. **Autoridad del anfitrión** (Developer): `host_authority.gd` (procesa `actions/` en orden con `Game.reduce`, publica `public`/`private`/`host` en una escritura multi-ruta, ejecuta bots y temporizador de reacción), `client_session.gd`, `online_session.gd` (implementa `GameSession`), lobby real, pausa/reanudación si cae el anfitrión (restaura desde `host/`), `meta.protocolVersion`.
4. **Pendientes técnicos arrastrados:** el cliente en línea debe emitir `state_changed.events` desde las entradas de `view.log` con `log_seq` nuevo (contrato en `docs/TECNICO/bus-presentacion.md` §3) y aplicar `ReactionRelevance.auto_pass_action` con su vista (`docs/TECNICO/preferencia-reaccion-y-resumen.md` §1.3); aplicar `CurseEffects.can_report_rule_break(state, reporter, target, host_id)` antes de aceptar `BREAK_RULE` en línea; temporizador de reacción obligatorio (15 s); handlers custom de `modifiers.gd` sin parámetro `events` (ver `docs/CAMBIOS-TIPOS.md`).
5. **Aceptación (QA):** 50 partidas en el emulador con 1 anfitrión + 2-5 clientes bot sin fugas de información, sin acciones perdidas o duplicadas, y reanudación tras caída del anfitrión. Prueba manual con celulares reales (M13).

## B2. QA a fondo del modo local  *(puede ir en paralelo con B1)*
- Simulación headless de ≥ 1000 partidas bot contra bot (`tools/sim.gd`), 3-6 jugadores, invariantes tras cada acción (`Types.validate_state`, 154 cartas constantes, vida 0-10, ida y vuelta JSON).
- `docs/MATRIZ-REGLAS.md`: cada regla del manual enlazada a un test (cubierta / no / ambigua).
- Interacciones raras: Lightning en cadena con Mirror Shield, Annihilation sobre Annihilation, eliminación durante la ventana de reacción, rebarajar con descarte vacío, evento robado en el reparto, Freeze al último jugador, Armageddon que mata a todos.
- Revisión de las 3 partidas bot que no terminan (bloqueo de recursos).

## B3. Builds y publicación
- Requisitos manuales: M2 (Godot, hecho), M14 (JDK 17, Android SDK, plantillas de exportación, keystore release).
- Presets Android (APK debug/release, vertical, permiso INTERNET, keystore por variables de entorno) y Web (sin hilos, para no necesitar COOP/COEP), `tools/build.sh [android-debug|android-release|web|linux]`, `firebase.json` hosting.
- **Nunca desplegar sin confirmación del usuario** (M16): la URL de Hosting es pública y expondría el arte con copyright.

## B4. Pulido  *(lo audiovisual pasa a v0.3, ver arriba; lo móvil y de rendimiento sigue aquí)*
- Animaciones con `Tween` (robar, jugar, descartar, números flotantes), "Reducir animaciones".
- Efectos por elemento (`CPUParticles2D`, compatibles con Web): fuego, hielo, electricidad.
- Sonido opcional, desactivado por defecto, sin audio con copyright (generado o sintetizado).
- Móvil: toques ≥ 48 px, botón atrás de Android, safe areas, vibración opcional.
- Rendimiento: carga diferida de texturas, 60 fps en Android de gama media, carga Web < 10 s.
- README: instalación de assets, tests, emulador, exportación, aviso de derechos.

## B5. Posible v2
Variantes por equipos y conjunción astral, guardar/cargar partida, migración de anfitrión, tutorial.

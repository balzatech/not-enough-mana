# Backlog (post-MVP local)

Estado a 2026-10-14: MVP local y **v0.2 "Mesa legible" cerradas** (commit `104a7c9` y revisión de código posterior, 717 tests, 0 warnings). El usuario jugó la v0.2 y escribió los requisitos de la siguiente (`docs/revision/requisitos-v03-usuario.md`). Lineamientos del Director: `docs/revision/LINEAMIENTOS-v03.md`.

Este backlog lo mantiene el **Producer** (reordenado por el Director el 2026-10-14 al fijar la v0.3). Cada ítem indica responsable sugerido y criterio de aceptación (lo refina el Game Designer / Lead Programmer).

## Orden de iteraciones (decidido el 2026-10-14, ver `docs/DECISIONES.md`)
1. **v0.3 "Versión local completa contra bots"** (ahora).
2. **v0.4 "En el celular"**: Web en red local (E9), memoria y prueba táctil.
3. **v0.5 Multijugador en línea (B1)**, cuando Firebase esté configurado (M3-M5).
B2 (QA a fondo) puede ir en paralelo cuando haya hueco; B3 se reparte entre v0.4 (Web local) y v0.5.

## Pendientes de decisión del usuario
- E10-E14 de `docs/ESCALADOS.md` (sección 8 cortada, elección al vencer el tiempo en decisiones obligatorias, semántica de los 30 s, aprobación de packs, Conjunción astral).
- `docs/DECISIONES-PARA-REVISAR.md` (14 decisiones de reglas; sobre todo Elixir Transmutation). La ventana de reacción en línea se decide al diseñar B1.
- E2 Partida rápida: aplazada hasta medir la duración real.

## v0.3 "Versión local completa contra bots"  *(prioridad actual)*
Objetivo: 1 persona contra 2-5 bots en el PC, divertida, clara y con aspecto de juego de magos. Detalle, flujos y "hecho cuando" en `docs/revision/LINEAMIENTOS-v03.md` §7; aceptación en §8 (puerta de QA + prueba humana M12-bis). Tope de 2 agentes simultáneos.

Estado (2026-10-14): plan de ejecución creado en `docs/TAREAS.md` (tareas V3-01..V3-44). Ninguna tarea iniciada; las prioridades 1-15 de abajo siguen todas en **pendiente**. Prioridad 11 (packs): propuesta = V3-03, descarga = V3-22 (bloqueada por aprobación del usuario).

**A. Cimientos**
1. A4 herramientas de test (`mkdir -p .godot`, `override.cfg`, `flock -w`). Developer / QA.
2. A1 acciones legales sobre la vista (contrato del Lead Programmer + test de equivalencia estado/vista). Requisito del resaltado de objetivos.
3. M4 aislamiento de tests y 0 nodos huérfanos (`tools/test.sh` falla si hay). Developer / QA.
4. Temporizadores en la sesión: turno 30 s y defensa 20 s configurables, pausa al esperar a bots, reloj monótono (M3), bots sin plazo, M5 al tocar `LocalSession`. Lead Programmer + Developer.
5. Presentación secuenciada (los bots esperan a la animación anterior) y opción "Reducir animaciones". Lead Programmer + Developer.

**B. Mecánica y UX**
6. Partida contra bots: hot-seat oculto (1 humano + 2-5 bots; código conservado), límite de pociones desactivado por defecto y activable, temporizadores configurables en la pantalla de nueva partida. Developer.
7. Mesa por zonas de pulgar y por fase (un solo principal, lo que no aplica se oculta, selector de objetivos en el dock, ficha en el centro, mano ≥ 150 px). Level Designer + Developer.
8. Flujo de ataque (elegir carta, objetivos válidos, vista previa, lanzar, resultado). Game Designer + Developer.
9. Flujo de defensa (aviso, atacante, opciones explicadas, temporizador, resultado). Game Designer + Developer.
10. Temporizadores en pantalla (oro turno / plata defensa) y transiciones de turno. Developer + Technical Artist.

**C. Visual**
11. Propuesta de 2-3 packs por necesidad (UI fantasía, iconos de runas y hechizos, fuentes) con licencia, **sin descargar** hasta que el usuario elija (E13). Art.
12. Tema nuevo (paleta, fuentes con DejaVu de respaldo, paneles, marcos, botones de 5 estados, sigilos de mago, fondo propio de mesa) + A3 (caché de texturas) con presupuesto de memoria. Technical Artist + Art.
13. Efectos y animaciones (proyectiles por elemento, escudos, impactos, círculos rúnicos, colocación de cartas). Technical Artist + Developer; Performance mide.
14. Pantallas fuera de la mesa con la identidad nueva (menú, nueva partida, Ajustes, Cómo se juega con panel, fin, créditos si hay atribución). Developer + Art.
15. Conjunción astral (E4), opción desactivada; la última, puede pasar a v0.3.1 (E14). Game Designer + Developer.

**Si M12-bis lo pide (v0.3.1):** arreglos de claridad o ergonomía; bots que usan las 15 cartas que nunca juegan, si los bots aburren.

## v0.4 "En el celular"  *(después de v0.3)*
1. Build Web servida solo en la red local (E9); nunca hosting público (M16).
2. Memoria de texturas: compresión por plataforma (resto de A3, P7 de `docs/rendimiento/v02-final.md`); carga < 10 s.
3. Rendimiento en el celular: fotograma con acción p95 ≤ 33 ms con 6 jugadores; si falla, P2b (bot fuera del fotograma, requiere A2) y P3/P4.
4. Prueba táctil real (M12-bis en el celular): ergonomía del pulgar, toques accidentales, legibilidad.
5. Audio mínimo (sin copyright, desactivado por defecto) y vibración; los ajustes reaparecen solo cuando funcionen.
6. Android (APK de depuración) cuando el usuario lo pida (M3, M14).

## Después de v0.4 (sin orden fijo)
- Bots: usar todas las cartas, estilos y velocidad configurable (sin cambiar reglas).
- Tutorial guiado (solo si las pruebas humanas lo piden), partida rápida (E2), variante por equipos, guardar partida.
- Hot-seat de nuevo (requisito: el plazo arranca tras "Soy X", M3).
- Seguimiento del Game Designer: cartas que los bots no juegan nunca (14-15; artefactos y utilidades). **Sin cambiar reglas**.

## B1. Multijugador en línea (Firebase)  *(v0.5)*
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

## B4. Pulido  *(lo visual entra en v0.3; lo móvil, audio y rendimiento en el dispositivo, en v0.4)*
- Animaciones con `Tween` (robar, jugar, descartar, números flotantes), "Reducir animaciones".
- Efectos por elemento (`CPUParticles2D`, compatibles con Web): fuego, hielo, electricidad.
- Sonido opcional, desactivado por defecto, sin audio con copyright (generado o sintetizado).
- Móvil: toques ≥ 48 px, botón atrás de Android, safe areas, vibración opcional.
- Rendimiento: carga diferida de texturas, 60 fps en Android de gama media, carga Web < 10 s.
- README: instalación de assets, tests, emulador, exportación, aviso de derechos.

## B5. Posible v2
Variantes por equipos y conjunción astral, guardar/cargar partida, migración de anfitrión, tutorial.

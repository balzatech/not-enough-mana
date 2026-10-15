# Tareas manuales (tuyas) y orden de ejecución

**Stack:** Godot 4 (GDScript) + Firebase (Auth anónima, Realtime Database y Hosting). Multijugador en línea con el celular anfitrión como autoridad. Se juega en Android y en Web. Detalle en `docs/ARQUITECTURA.md`.

Los subagentes están en `.claude/agents/` (14 en total, uno por rol) y hacen todo lo que **no** aparece en esta lista. Las tareas de aquí necesitan tu cuenta, `sudo`, un navegador, un celular o una decisión tuya. Cada una indica **qué, cuándo y por qué**.

## Mapa de agentes

Desde el 2026-10-13 el equipo son **14 agentes por rol** (ver `docs/EQUIPO.md`): Game Director, Game Designer, Lead Programmer, Developer, Art, QA, Level Designer, AI Programmer, Technical Artist, Audio, Producer, Performance, Narrative Designer y Build & Release. Sustituyen a los agentes por oleada que construyeron el MVP local (oleadas 0-3, ya completadas).

Los subagentes no pueden lanzar a otros. **Yo (la sesión principal) hago de orquestador**: el Producer planifica en `docs/TAREAS.md`, yo lanzo a cada agente con su tarea y QA valida. Tú instalas, configuras cuentas, decides y pruebas en dispositivos.

---

## Estado actual de las tareas manuales (2026-10-13)

Las referencias a "oleada N" más abajo son del plan antiguo; esta tabla manda.

| Tarea | Estado | Cuándo toca ahora |
|---|---|---|
| M1 Recargar agentes | Hecho (equipo de 14 cargado) | — |
| M2 Godot 4.7.2 | **Hecho** (`~/.local/bin/godot`) | — |
| M3 Java 17 | Pendiente | Antes de B1 (multijugador en línea) y de las builds Android |
| M4 Proyecto Firebase | Pendiente | Antes de B1 |
| M5 Firebase CLI + `firebase login` | Pendiente | Antes de B1 |
| M6 Decisiones por defecto | Hecho (valores en `docs/CONTEXTO-AGENTES.md`) | Revisa `docs/DECISIONES-PARA-REVISAR.md` |
| M7 `git init` | Hecho; **sin commits** | Primer commit cuando confirmes que el MVP local funciona |
| M8-M9 Revisar cartas y muestra | Hecho en lo esencial (el validador revisó 44 imágenes); queda confirmar Elixir Transmutation | Cuando quieras |
| M10 Elegir librería Firebase si falla en Web | Pendiente | Lo informará el Lead Programmer en B1 |
| M11 Resolver ambigüedades | Pendiente | `docs/DECISIONES-PARA-REVISAR.md`; antes del multijugador conviene al menos #1 y #2 |
| M12 **Probar el MVP local** | Pendiente. Para v0.2 se hace **al final**, con el guion `docs/qa/guion-m12.md` (tarea V2-31 de `docs/TAREAS.md`): 1 humano + 3 bots y hot-seat de 3 | `cd ~/not-enough-mana && godot --path .` |
| M12 (detalle v0.2) | El guion V2-31 debe anotar por partida **minutos, turnos y rondas**, tramos en que nadie podía hacer nada y **si pulsaste algún botón sin querer o te costó acertar** (confirma el tamaño táctil de 144 px / 48 dp en tu móvil real) | Tras V2-36 |
| E6 Límite de pociones (decisión abierta, **sin bloqueo**) | Pendiente. Si los bots bloquean partidas (14 de 200 pasan de 100 turnos) se arregla primero la IA (V2-42). Solo te preguntaré si un humano también puede atascarse: opciones en `docs/ESCALADOS.md` E6 y, si procede, `docs/diseno/opciones-bloqueo-pociones.md` (V2-43). Ningún cambio de regla entra en v0.2 | Tras las oleadas 2-3 |
| M12-base (opcional) | Pendiente | Una partida con el MVP actual apuntando la duración real, para decidir E2 (partida rápida) con datos. No bloquea nada |
| M19 Confirmar que los resúmenes en español van a `.gitignore` | **Hecho** (confirmada por el usuario, 2026-10-13) | V2-28 añadirá `data/card_summaries_es.json` a `.gitignore`. Son texto derivado de material con derechos; solo se usan dentro de la app |
| M13 Prueba en línea con celulares | Pendiente | Cuando exista B1 |
| M14 SDK Android, keystore | Pendiente | Antes de B3 (builds) |
| M15-M18 | Pendientes | Tras B3 |

El plan de trabajo vivo está en `docs/BACKLOG.md` (lo ordena el Producer en `docs/TAREAS.md`).

---

## Tareas manuales de la v0.3 (2026-10-14)

Plan en `docs/TAREAS.md`. Estado a 2026-10-14: la oleada 0 de diseño está entregada (falta el plan de QA, en curso, y la puerta del Director V3-06). **Siguen abiertas E10 (M-v0.3-3) y E15 (M-v0.3-2)**; los packs ya están aprobados y descargados. Lo tuyo en esta versión:

| Tarea | Cuándo | Qué | Por qué |
|---|---|---|---|
| ~~M-v0.3-1 Aprobar packs de arte~~ (E13) | **HECHO (2026-10-14)** | Aprobaste los packs recomendados y Art los descargó (V3-22 hecha): Kenney Fantasy UI Borders (CC0), Kenney Game Icons (CC0), game-icons.net (CC BY 3.0) y Cinzel (SIL OFL), 0,47 MB en `assets/ui_v03/`. Nada más que hacer; la atribución irá en la pantalla de Créditos | — |
| **M-v0.3-2 Confirmar el azar en decisiones obligatorias al vencer** (E15) | **Abierta.** Antes de la tarea V3-14 (temporizadores); no bloquea el inicio, hay valor por defecto | Responder si, al vencer el tiempo con una decisión obligatoria pendiente, el juego elige **al azar** (con el RNG de la partida): descarte forzado de cartas, y también elegir objetivos y elegir carta. Lo demás sigue siendo "no se elige nada" (perder turno, no defender, rechazar lo opcional) | Es el caso en que el motor exige elegir algo aunque "no se elige nada" (E11). Si dices que no, solo cambia un punto del código (`timeout_rules.gd`) |
| **M-v0.3-3 Sección 8 de tus requisitos** (E10) | **Abierta.** Cuando puedas, idealmente antes de V3-06 | Pegar el texto que falta tras "Evitar interfaces confusas:" (sección 8), o decir que acaba ahí | Tu documento llega cortado; el plan se hizo con lo recibido y lo que falte se añade a LINEAMIENTOS |
| **M-v0.3-4 Aprobar la especificación de Conjunción astral** | Tras V3-19 (lote 1E) | Leer `docs/diseno/conjuncion-astral.md` y aprobar o corregir | Cambia reglas, solo tú decides; sin tu aprobación V3-40 no se hace y pasa a v0.3.1 |
| **M-v0.3-5 Resolver E16** (opcional) | Antes de V3-06 | Confirmar que manda tu decisión E11 sobre el texto de LINEAMIENTOS §5 | Contradicción entre documentos; el Producer asumió tu decisión |
| **M12-bis Prueba humana final** (V3-44) | Tras V3-43 (aprobación previa del Director) | Jugar 2 partidas (3 y 5 bots) con la ventana a 720x1280 y, si puedes, otra a 1080x2400, y contestar el guion `docs/qa/guion-m12bis.md` (¿encontraste cada control?, ¿supiste a quién atacabas y quién te atacaba?, ¿30 s/20 s se sienten bien?, ¿animaciones ayudan?, ¿se ve como juego de magos?, ¿volverías a jugar?) | La ergonomía y la diversión solo las valida una persona; con ratón no se prueba el pulgar (se confirma en v0.4) |

---

## A. Preparación (ya hecha en gran parte)

### M1. Recargar los agentes
- **Cuándo:** ahora.
- **Qué:** cierra y vuelve a abrir Claude Code en `/home/brayan/not-enough-mana`.
- **Por qué:** el equipo nuevo de 14 agentes se carga al iniciar la sesión.

### M2. Instalar Godot 4 (editor y versión de consola)
- **Cuándo:** antes de la oleada 0. Bloquea todo.
- **Qué:**
  1. Descarga de https://godotengine.org/download/linux/ la versión **estable** más reciente de Godot 4 en "Standard" (no la .NET), Linux x86_64.
  2. Instálala:
     ```bash
     mkdir -p ~/.local/bin ~/apps/godot
     unzip ~/Downloads/Godot_v4.*-stable_linux.x86_64.zip -d ~/apps/godot
     ln -sf ~/apps/godot/Godot_v4.*-stable_linux.x86_64 ~/.local/bin/godot
     godot --version
     ```
     Si `godot` no se encuentra, añade `export PATH="$HOME/.local/bin:$PATH"` a `~/.zshrc` y abre una terminal nueva.
  3. Abre el editor una vez (`godot`) y, en *Editor → Manage Export Templates*, pulsa **Download and Install**. Esto puede esperar a la oleada 4, pero hacerlo ahora evita sorpresas.
- **Por qué:** los agentes necesitan `godot --headless` para importar el proyecto y ejecutar los tests GUT. Las plantillas son necesarias para exportar a Android y Web.

### M3. Instalar Java 17
- **Cuándo:** antes de la oleada 1.
- **Qué:** `sudo apt install openjdk-17-jdk` y comprueba con `java -version`.
- **Por qué:** el emulador de Firebase (necesario para probar la red sin tocar producción) y la exportación a Android necesitan Java. Requiere `sudo`, por eso lo haces tú.

### M4. Crear el proyecto Firebase
- **Cuándo:** antes de la oleada 1, porque el Developer (capa de red) lo necesita para configurar el cliente.
- **Qué:**
  1. Entra en https://console.firebase.google.com, pulsa **Agregar proyecto** y ponle un nombre (p. ej. `not-enough-mana`). Puedes desactivar Google Analytics. Deja el plan **Spark (gratis)**.
  2. *Compilación → Authentication → Comenzar → Método de acceso* → activa **Anónimo**.
  3. *Compilación → Realtime Database → Crear base de datos* → elige la región (`us-central1`, o `europe-west1` si estás en Europa) → **modo bloqueado**. Los agentes escriben las reglas reales.
  4. *Configuración del proyecto → Tus apps → Web (`</>`)* → registra la app "nem-web" y **no** actives Hosting todavía. Copia `apiKey`, `authDomain`, `databaseURL`, `projectId`, `appId` y `storageBucket`.
  5. Pásamelos o pégalos en `addons/godot-firebase/.env` cuando exista (te avisaré). Ese archivo está fuera de git.
- **Por qué:** necesita tu cuenta de Google, y los agentes no deben tocar cuentas reales. La `apiKey` web no es secreta (la protegen las reglas de seguridad), pero no conviene publicarla.

### M5. Instalar e iniciar sesión en Firebase CLI
- **Cuándo:** antes de la oleada 1.
- **Qué:**
  ```bash
  npm install -g firebase-tools     # si da error de permisos: npm config set prefix ~/.local  y repite
  firebase login                    # abre el navegador, inicia sesión con tu cuenta
  firebase emulators:start --only auth,database   # prueba que arranca; luego Ctrl+C
  ```
- **Por qué:** `firebase login` es interactivo con el navegador y no puedo hacerlo. El emulador permite que el Developer y QA prueben salas, reglas y partidas sin gastar cuota ni ensuciar la base real.

### M6. Confirmar las decisiones restantes
- **Cuándo:** antes de la oleada 0.
- **Qué:** revisa la tabla de `docs/CONTEXTO-AGENTES.md`. Puse por defecto: límite de 10 pociones, botón "Rompió la regla", temporizador de reacción de 15 s en línea y UI en español. Dime si cambias algo.
- **Por qué:** se fijan en el contrato de tipos (T1), y cambiarlas después obliga a tocar a varios agentes.

### M7. Control de versiones
- **Cuándo:** antes de la oleada 0, y un commit al final de cada oleada (puedo hacerlos yo si me lo pides).
- **Qué:** `git init` en la carpeta del proyecto. Si creas un repo remoto, que sea **privado**.
- **Por qué:** para poder volver atrás si una oleada rompe algo. El `.gitignore` excluye las cartas, los PDFs y la config de Firebase por copyright y privacidad.

---

## B. Durante el desarrollo

### M8. Revisar las cartas marcadas para revisión humana
- **Cuándo:** al terminar la oleada 1 y **antes** de la oleada 2.
- **Qué:** te daré la lista con el nombre y la página de cada carta. Abre `assets/cards/NNN.webp` y confirma el coste, los iconos 💖/💧 y el elemento. Lo más probable es que aparezcan las maldiciones (124-131) y los eventos (154-164), sobre todo Warp Discharge y Elixir Transmutation. Dime las correcciones y yo las aplico.
- **Por qué:** los iconos y el coste solo existen como imagen. Si se leen mal, el error pasa a los efectos y a sus tests.

### M9. Comprobar 10 cartas al azar
- **Cuándo:** al mismo tiempo que M8.
- **Qué:** elige 10 páginas cualesquiera y compara cada imagen con su entrada en `data/cards.json` (coste, cantidad y elemento).
- **Por qué:** es un control independiente del agente. Si fallan 2 o más, repito el catálogo.

### M10. Decidir la librería de Firebase si hay que elegir
- **Cuándo:** al terminar la oleada 1, si el Lead Programmer informa de que el addon GodotFirebase no funciona en Web.
- **Qué:** elegir entre la alternativa que proponga (por ejemplo, el SDK de JS de Firebase solo para la versión Web) o quitar Web del MVP y dejar solo Android.
- **Por qué:** es el mayor riesgo técnico del proyecto y afecta al alcance.

### M11. Resolver las ambigüedades de reglas
- **Cuándo:** al terminar la oleada 2, antes de la oleada 3. Están en `docs/AMBIGUEDADES.md`.
- **Qué:** elige una opción en cada caso (empate de edad en las maldiciones, fin de la cadena de Lightning, vecinos tras eliminaciones, etc.), según cómo jugáis en la mesa.
- **Por qué:** el manual no las resuelve y los agentes eligieron la lectura literal.

### M12. Primera partida local
- **Cuándo:** al terminar la oleada 3.
- **Qué:** `godot --path .` y pulsa Play (F5). Juega contra 2 bots y luego una partida hot-seat con alguien. Apunta lo que se sienta confuso o lento.
- **Por qué:** la simulación automática no detecta problemas de usabilidad.

### M13. Primera partida en línea con celulares reales
- **Cuándo:** al terminar la oleada 3. Para la versión Web solo necesitas la build de prueba; para Android, la parte de M14.
- **Qué:** con 2-3 dispositivos (pueden ser tu PC y tu celular), uno crea la sala y los demás se unen con el código. Prueba:
  - jugar varias rondas;
  - que nadie vea la mano ajena;
  - apagar el Wi-Fi del anfitrión 30 s y volver (la partida debe pausarse y reanudarse);
  - apagar el Wi-Fi de un cliente.
- **Por qué:** el emulador no reproduce la latencia ni los cortes reales del móvil, y yo no tengo celulares.

---

## C. Antes de publicar (oleada 4)

### M14. Preparar la exportación a Android
- **Cuándo:** antes de que el Build & Release Agent haga la build de Android.
- **Qué:**
  1. Instala Android Studio (`sudo snap install android-studio --classic`) o solo las *command-line tools*. Con el SDK Manager instala `platform-tools` y las versiones de `build-tools` y `platforms` que indique la documentación de exportación a Android de tu versión de Godot (el Build & Release Agent te dirá las exactas).
  2. En Godot: *Editor → Editor Settings → Export → Android* → indica la ruta del **Java SDK** (p. ej. `/usr/lib/jvm/java-17-openjdk-amd64`) y del **Android SDK** (`~/Android/Sdk`).
  3. Crea la **keystore de release** y guarda una copia de seguridad y la contraseña en un lugar seguro:
     ```bash
     keytool -genkeypair -v -keystore ~/keys/nem-release.keystore -alias nem -keyalg RSA -keysize 2048 -validity 10000
     ```
  4. Decide el nombre del paquete (p. ej. `com.brayan.notenoughmana`).
- **Por qué:** requiere `sudo`, aceptar licencias y elegir una contraseña. Si pierdes la keystore, no podrás actualizar el APK en los celulares donde ya esté instalado.

### M15. Instalar el APK en los celulares
- **Cuándo:** después de `tools/build.sh android-release`.
- **Qué:** pasa `export/android/not-enough-mana.apk` a cada celular (cable, Drive o WhatsApp). En el celular, permite **Instalar apps desconocidas** para la app con la que lo abras e instálalo. Con cable y depuración USB activada también funciona `adb install export/android/not-enough-mana.apk`.
- **Por qué:** no hay Play Store (y no se puede publicar ahí por los derechos), así que la instalación es manual.

### M16. Desplegar reglas y versión Web en Firebase (con confirmación)
- **Cuándo:** al terminar la oleada 4 con QA en verde.
- **Qué:** decide si se despliega. Si dices que sí, lo ejecuto o lo ejecutas tú:
  ```bash
  cd firebase && firebase deploy --only database       # reglas de seguridad (imprescindible antes de jugar en línea)
  firebase deploy --only hosting                       # versión Web
  ```
- **Por qué:** publica en un servicio externo. **Atención:** la URL de Hosting es pública y cualquiera que la tenga descarga el juego con el arte de SUPERHOTEX. Compártela solo con tus amigos y no la difundas, o usa únicamente el APK. Las reglas de la base de datos deben desplegarse **antes** de la primera partida real, porque el modo bloqueado rechaza todo.

### M17. Revisar el uso de Firebase
- **Cuándo:** una semana después de empezar a jugar.
- **Qué:** consola de Firebase → Realtime Database → *Uso*. Comprueba las conexiones simultáneas (máximo 100 en Spark) y la descarga (10 GB al mes).
- **Por qué:** en el plan gratis no hay facturas, pero si te pasas de la cuota el juego en línea deja de funcionar hasta el mes siguiente.

### M18. Aceptación final
- **Cuándo:** después de la oleada 4.
- **Qué:** revisa `docs/MATRIZ-REGLAS.md`, `docs/BUGS-PULIDO.md` y los RF1-RF11 de `REQUERIMIENTOS.md`, y decide qué queda para la v2.
- **Por qué:** solo tú sabes si el resultado es lo que querías.

---

## Orden resumido

1. **M1, M2, M6, M7** → las oleadas 0-3 (ya hechas).
2. **M3, M4, M5** → oleada 1 (assets, catálogo ×3, motor, UI y red).
3. Yo fusiono el catálogo y aplico los cambios de tipos → **M8, M9** (y **M10** si hace falta).
4. Oleada 2 (efectos, validador y bots) → **M11**.
5. Oleada 3 (integración local y en línea) → **M12, M13**.
6. **M14** → oleada 4 (QA, pulido y builds) → **M15, M16, M17, M18**.

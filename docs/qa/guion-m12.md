# Guion de la prueba humana M12 (45-60 min)

Gracias por probarlo. Criterio central: **¿supiste siempre qué te pasó?**

## 1. Preparación
- En una terminal: `cd ~/not-enough-mana && godot --path .`
  Si no lo encuentra: `~/.local/bin/godot --path ~/not-enough-mana`
- Deja las opciones por defecto: **límite de pociones = 10** y **reacciones = "solo de hechizos que me afectan"**.
- Ten un reloj a mano. Apunta la **hora de inicio y fin** de cada partida.

## 2. Partidas
- **A (~20 min):** 1 humano + 3 bots.
- **B (~20 min):** hot-seat de 3 humanos. Si estás solo, juega los 3 puestos y **anótalo**.
- **C (opcional):** 6 jugadores.

## 3. Qué anotar por partida
- Minutos (fin menos inicio, con el reloj).
- La pantalla de fin muestra, por cada mago, **turnos jugados y pociones** (no rondas ni total de turnos). Apunta los turnos del ganador (o los tuyos) como aproximación.
- Reacciones: cuántas veces salió el aviso y cuántas "contra ti".
- Tramos en que nadie podía hacer nada (¿atasco con el límite de pociones?).
- ¿Se entienden los números flotantes, el destello y el aviso "A → carta → B"? ¿Se lee bien el español?
- **¿Pulsaste algún botón sin querer o te costó acertar?**

## 4. Plantilla de respuesta (copia y rellena)

```
Dispositivo / pantalla:
Partida A: inicio __ fin __ | minutos __ | turnos del ganador/míos __ | pociones __
Partida B: inicio __ fin __ | minutos __ | turnos del ganador/míos __ | pociones __ | ¿3 puestos yo solo? sí/no
Partida C (opcional): ...

1. ¿Supiste siempre qué te pasó? (sí / no / a veces) Ejemplo:
2. Reacciones: veces que te interrumpieron (total __ / contra mí __)
3. ¿Qué te aburrió (cuándo y por qué)?
4. Momentos confusos:
5. Tramos sin poder hacer nada / atascos:
6. Feedback visual y cartas en español: ¿se entiende y se lee?
7. ¿Pulsaste algún botón sin querer o te costó acertar? (dispositivo y pantalla):
8. Comentarios libres:
9. DECISIÓN sobre el límite de pociones: 15 / desactivar / dejar en 10
```

**Ayuda para la pregunta 9** (50 partidas simuladas, semilla 1, bots actuales): con límite **10**, bloqueo en 3 de 50 (máx. 140 turnos); con **15**, 0 de 50 (máx. 47); **desactivado**, 0 de 50, pero se pierde la eliminación por exceso de maná. Con bots más aleatorios (como en una partida con humanos) todavía aparece algún bloqueo, por eso tu observación importa. Si no viste atascos, deja 10.

## 5. Si algo falla
- Haz una **captura** en ese momento.
- Guarda la consola: `godot --path . 2>&1 | tee ~/m12-log.txt`. Los registros están en `~/.local/share/godot/app_userdata/`.

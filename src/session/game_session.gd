class_name GameSession
extends Node
## Interfaz común local / en línea que usa la UI (contrato T1).
##
## La UI NUNCA llama a Game.reduce() directamente: envía acciones con
## submit_action() y redibuja al recibir state_changed, pidiendo la vista con
## get_view_for(pid) (vista = Types.view_for/compose_view: sin información oculta
## ajena).
##
## Implementaciones:
##  - LocalSession  (src/session/local_session.gd): hot-seat + bots, aplica
##    Game.reduce() en el propio dispositivo.
##  - OnlineSession (src/session/online_session.gd): en el anfitrión envuelve
##    HostAuthority; en los demás, ClientSession (envía a /actions y escucha
##    /public + /private/{uid}).
##
## Temporizadores: el motor no lee el reloj. La sesión escribe deadline_ms en
## state.reaction / state.pending y, al vencer, envía PASS_REACTION / DECLINE en
## nombre del jugador (en línea es obligatorio, 15 s por defecto).
## Preferencia de reacción: LocalSession puede auto-pasar (by = "auto_pass") en
## nombre de un humano local al que el hechizo no afecta, antes de emitir
## state_changed; la UI no ve el estado intermedio (LocalSession.reaction_notify).

## El estado cambió (rev nuevo). `events` = las entradas de log nuevas (con
## `log_seq` mayor que la última emitida por la sesión), ordenadas por
## `log_seq` y visibles para algún jugador local (públicas o con un pid local en
## `visible_to`). Cada entrada se emite una sola vez; en `start` se emite [].
## Fuente: state.log, no los events de reduce (ver docs/TECNICO/bus-presentacion.md §3).
signal state_changed(rev: int, events: Array)
## Una acción fue rechazada. code = Types.ERR_*.
signal error(code: String, action: Dictionary)
## Se abrió una ventana de reacción (state.reaction tal como lo ve la vista).
signal reaction_opened(reaction: Dictionary)
## Hay un prompt nuevo para un jugador local (Types.make_prompt).
signal prompt_opened(prompt: Dictionary)
## La partida terminó.
signal game_over(winners: Array)


## Envía una acción (Types.make_action_*). El resultado llega por señales.
func submit_action(action: Dictionary) -> void:
	error.emit(Types.ERR_NOT_IMPLEMENTED, action)


## Vista del estado para pid (manos ajenas ocultas). pid "" = espectador.
func get_view_for(_player_id: String) -> Dictionary:
	return {}


## Jugadores humanos controlados desde este dispositivo (hot-seat: varios;
## en línea: solo el propio uid).
func get_local_player_ids() -> Array[String]:
	return []


## rev del último estado conocido.
func get_rev() -> int:
	return 0


## true si este dispositivo ejecuta el motor (local o anfitrión en línea).
func is_authority() -> bool:
	return false

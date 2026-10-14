class_name TableModule
extends Node
## Base de los módulos de la mesa (ver docs/TECNICO/division-table.md).
## Cada módulo es un Node hijo de la mesa y habla con los demás a través de `ctx`.

var ctx: TableContext


func setup(p_ctx: TableContext) -> void:
	ctx = p_ctx


## Botones de PromptDialog. true = consumido (la mesa no hace nada más);
## false = no es mío o "sigue" (cae en la cola común de TableDialogs).
func on_dialog_button(_id: String) -> bool:
	return false

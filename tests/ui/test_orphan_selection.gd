extends GutTest
## QA-V2-21-01: un prompt que desaparece del estado sin que la UI lo resuelva
## (sesión, plazo, auto-pase) no deja la mesa en modo de selección huérfano.

const Step = TableContext.Step


func before_each() -> void:
	FakeState.install_defs()


func _view(with_prompt: bool) -> Dictionary:
	var st: Dictionary = FakeState.make_state(3)
	if with_prompt:
		st["pending"] = [Types.make_prompt(7, "p1", Types.PROMPT_DISCARD, {"count": 1}, "ice_bolt")]
	return Types.view_for(st, "p1")


func _table(with_prompt: bool) -> TableScreen:
	var t: TableScreen = (load("res://src/ui/screens/table.tscn") as PackedScene).instantiate()
	t.demo_when_empty = false
	add_child_autofree(t)
	t.set_view(_view(with_prompt), "p1")
	return t


func test_orphan_discard_is_reset() -> void:
	var t: TableScreen = _table(true)
	await wait_process_frames(2)
	var ctx: TableContext = t._ctx
	assert_eq(ctx.step, Step.CARDS)
	assert_eq(int(ctx.flow_data.get("prompt_id", -1)), 7)
	var hand: Array = ctx.me().get("hand", []) as Array
	assert_false(hand.is_empty())
	ctx.selected.append(int((hand[0] as Dictionary)["iid"]))
	t.set_view(_view(false), "p1")
	await wait_process_frames(2)
	assert_eq(ctx.step, Step.NONE)
	assert_true(ctx.flow_data.is_empty())
	assert_true(ctx.selected.is_empty())
	assert_eq(ctx.shown_prompt_id, -1)


func test_live_prompt_is_not_reset() -> void:
	var t: TableScreen = _table(true)
	await wait_process_frames(2)
	var ctx: TableContext = t._ctx
	var hand: Array = ctx.me().get("hand", []) as Array
	ctx.selected.append(int((hand[0] as Dictionary)["iid"]))
	t.set_view(_view(true), "p1")
	await wait_process_frames(2)
	assert_eq(ctx.step, Step.CARDS)
	assert_eq(int(ctx.flow_data.get("prompt_id", -1)), 7)
	assert_eq(ctx.selected.size(), 1)


func test_player_play_in_progress_survives() -> void:
	var t: TableScreen = _table(false)
	await wait_process_frames(2)
	var ctx: TableContext = t._ctx
	ctx.flow_data = {"kind": "play", "card": 1, "payment_done": false}
	ctx.step = Step.PAYMENT
	ctx.selected.append(5)
	t.set_view(_view(false), "p1")
	await wait_process_frames(2)
	assert_eq(ctx.step, Step.PAYMENT)
	assert_eq(String(ctx.flow_data.get("kind", "")), "play")
	assert_eq(ctx.selected.size(), 1)

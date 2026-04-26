extends RefCounted
class_name GameController

const Constants = preload("res://scripts/constants.gd")
const BoardClass = preload("res://scripts/board.gd")
const AIClass = preload("res://scripts/ai.gd")

var player_board: BoardClass
var enemy_board: BoardClass
var ai: AIClass

var turn: String = "player" # player|enemy
var over: bool = false

var moves: int = 0
var hits: int = 0
var misses: int = 0

var abilities := {"radar": 1, "airstrike": 1}

func _init(difficulty: String) -> void:
	player_board = BoardClass.new()
	enemy_board = BoardClass.new()
	ai = AIClass.new(difficulty)

func start_new() -> void:
	var ok := false
	while not ok:
		ok = player_board.auto_place_all()
	ok = false
	while not ok:
		ok = enemy_board.auto_place_all()
	_reset_state()

func start_new_with_board(p_player_board: BoardClass) -> void:
	player_board = p_player_board
	var ok := false
	while not ok:
		ok = enemy_board.auto_place_all()
	_reset_state()

func _reset_state() -> void:
	ai.reset()
	turn = "player"
	over = false
	moves = 0
	hits = 0
	misses = 0
	abilities = {"radar": 1, "airstrike": 1}

func player_shoot(r: int, c: int) -> Variant:
	if over or turn != "player":
		return null
	var cell_data: Dictionary = enemy_board.cell(r, c)
	if cell_data.is_empty():
		return null
	if cell_data.state == "hit" or cell_data.state == "miss":
		return null
	moves += 1
	var res_v: Variant = enemy_board.receive_shot(r, c)
	if res_v == null:
		return null
	var res: Dictionary = res_v
	if res.result == "miss":
		misses += 1
		turn = "enemy"
	else:
		hits += 1
		if enemy_board.all_ships_sunk():
			over = true
	return res

func use_radar(r: int, c: int) -> Array:
	if over or turn != "player":
		return []
	if int(abilities.radar) <= 0:
		return []
	abilities.radar = int(abilities.radar) - 1
	return enemy_board.radar_scan(r, c)

func use_airstrike(r: int, c: int) -> Array:
	if over or turn != "player":
		return []
	if int(abilities.airstrike) <= 0:
		return []
	abilities.airstrike = int(abilities.airstrike) - 1
	moves += 1
	var results := enemy_board.area_attack(r, c)
	for hit_info in results:
		if hit_info.get("result", null) == null:
			continue
		if hit_info.result == "hit":
			hits += 1
		else:
			misses += 1
	if enemy_board.all_ships_sunk():
		over = true
		return results
	turn = "enemy"
	return results

func enemy_take_step() -> Variant:
	if over or turn != "enemy":
		return null
	var target: Dictionary = ai.choose_shot(player_board)
	var res_v: Variant = player_board.receive_shot(int(target.r), int(target.c))
	if res_v == null:
		return null
	var res: Dictionary = res_v
	ai.report_result(int(target.r), int(target.c), String(res.result), res.get("ship", null))
	if res.result == "miss":
		turn = "player"
	else:
		if player_board.all_ships_sunk():
			over = true
	var out := {"r": int(target.r), "c": int(target.c)}
	out.merge(res)
	return out

func player_won() -> bool:
	return enemy_board.all_ships_sunk() and not player_board.all_ships_sunk()

func to_snapshot(difficulty: String) -> Dictionary:
	return {
		"difficulty": difficulty,
		"turn": turn,
		"over": over,
		"moves": moves,
		"hits": hits,
		"misses": misses,
		"abilities": abilities,
		"player_board": player_board.to_snapshot(),
		"enemy_board": enemy_board.to_snapshot(),
		"ai": {"diff": ai.diff, "shots": ai.shots, "hits": ai.hits}
	}

static func from_snapshot(data: Dictionary) -> GameController:
	var diff := String(data.get("difficulty", "medium"))
	var gc := GameController.new(diff)
	gc.turn = String(data.get("turn", "player"))
	gc.over = bool(data.get("over", false))
	gc.moves = int(data.get("moves", 0))
	gc.hits = int(data.get("hits", 0))
	gc.misses = int(data.get("misses", 0))
	gc.abilities = data.get("abilities", {"radar": 1, "airstrike": 1})
	gc.player_board.from_snapshot(data.get("player_board", {}))
	gc.enemy_board.from_snapshot(data.get("enemy_board", {}))
	var ai_data: Dictionary = data.get("ai", {})
	gc.ai.diff = String(ai_data.get("diff", diff))
	gc.ai.shots = ai_data.get("shots", {})
	gc.ai.hits = ai_data.get("hits", [])
	return gc

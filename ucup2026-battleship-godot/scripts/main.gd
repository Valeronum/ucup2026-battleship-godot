extends Control

const Constants = preload("res://scripts/constants.gd")
const GameControllerClass = preload("res://scripts/game_controller.gd")

const SHIP_TEXTURES = {
	1: preload("res://assets/ships/ship_1.png"),
	2: preload("res://assets/ships/ship_2.png"),
	3: preload("res://assets/ships/ship_3.png"),
	4: preload("res://assets/ships/ship_4.png"),
}

const WATER_TEXTURE = preload("res://assets/ships/Water_one.png")

var settings := {
	"difficulty": "medium",
	"sfx": true,
	"music": true,
	"autosave": true,
}

var game: GameControllerClass = null
var selected_ability: String = "" # "radar" | "airstrike" | ""

var _player_buttons: Array = []
var _enemy_buttons: Array = []

var _placement_board: Board = null
var _placement_buttons: Array = []
var _placement_ship_buttons: Array = []
var _placement_selected_def_index: int = -1
var _placement_vertical: bool = false
var _placement_hover_r: int = -1
var _placement_hover_c: int = -1
var _placement_ships_left: Dictionary = {}
var _placement_next_id: int = 0

@onready var screens: Control = $Screens
@onready var screen_menu: Control = $Screens/Menu
@onready var screen_settings: Control = $Screens/Settings
@onready var screen_help: Control = $Screens/Help
@onready var screen_history: Control = $Screens/History
@onready var screen_game: Control = $Screens/Game
@onready var screen_result: Control = $Screens/Result
@onready var screen_placement: Control = $Screens/Placement
@onready var grid_placement: GridContainer = $Screens/Placement/PlacementVBox/PlacementBody/Left/PlacementBoard
@onready var ships_container: VBoxContainer = $Screens/Placement/PlacementVBox/PlacementBody/Right/ShipsContainer

@onready var opt_difficulty: OptionButton = $Screens/Settings/SettingsVBox/DifficultyRow/Difficulty
@onready var chk_sfx: CheckBox = $Screens/Settings/SettingsVBox/Sfx
@onready var chk_music: CheckBox = $Screens/Settings/SettingsVBox/Music
@onready var chk_autosave: CheckBox = $Screens/Settings/SettingsVBox/Autosave

@onready var lbl_turn: Label = $Screens/Game/GameRoot/TurnIndicator
@onready var grid_player: GridContainer = $Screens/Game/GameRoot/GameBody/Left/PlayerBoard
@onready var grid_enemy: GridContainer = $Screens/Game/GameRoot/GameBody/Right/EnemyBoard
@onready var btn_radar: Button = $Screens/Game/GameRoot/GameBody/Sidebar/BtnRadar
@onready var btn_airstrike: Button = $Screens/Game/GameRoot/GameBody/Sidebar/BtnAirstrike
@onready var lbl_stats: Label = $Screens/Game/GameRoot/GameBody/Sidebar/Stats

@onready var lbl_result_text: Label = $Screens/Result/ResultVBox/ResultText

func _ready() -> void:
	randomize()
	_setup_settings_ui()
	_load_settings()
	_apply_settings_ui()
	_apply_music_state()
	_wire_events()
	_build_boards_ui()
	_build_placement_ui()
	_show_screen(screen_menu)

func _setup_settings_ui() -> void:
	opt_difficulty.clear()
	opt_difficulty.add_item("Легкий", 0)
	opt_difficulty.add_item("Середній", 1)
	opt_difficulty.add_item("Складний", 2)

func _load_settings() -> void:
	var loaded = Storage.load_json("settings", settings)
	if typeof(loaded) == TYPE_DICTIONARY:
		settings = loaded

func _save_settings() -> void:
	Storage.save_json("settings", settings)

func _apply_settings_ui() -> void:
	var diff := String(settings.get("difficulty", "medium"))
	var idx := 1
	if diff == "easy": idx = 0
	elif diff == "hard": idx = 2
	opt_difficulty.select(idx)
	chk_sfx.button_pressed = bool(settings.get("sfx", true))
	chk_music.button_pressed = bool(settings.get("music", true))
	chk_autosave.button_pressed = bool(settings.get("autosave", true))

func _apply_music_state() -> void:
	AudioManager.start_music(bool(settings.get("music", true)))

func _wire_events() -> void:
	$Screens/Menu/MenuVBox/BtnPlay.pressed.connect(_on_play)
	$Screens/Menu/MenuVBox/BtnSettings.pressed.connect(func(): _click(); _show_screen(screen_settings))
	$Screens/Menu/MenuVBox/BtnHelp.pressed.connect(func(): _click(); _show_screen(screen_help))
	$Screens/Menu/MenuVBox/BtnHistory.pressed.connect(func(): _click(); _refresh_history(); _show_screen(screen_history))

	$Screens/Settings/SettingsVBox/BtnSettingsBack.pressed.connect(func(): _click(); _show_screen(screen_menu))
	$Screens/Help/HelpVBox/BtnHelpBack.pressed.connect(func(): _click(); _show_screen(screen_menu))
	$Screens/History/HistoryVBox/HistoryButtons/BtnHistoryBack.pressed.connect(func(): _click(); _show_screen(screen_menu))
	$Screens/History/HistoryVBox/HistoryButtons/BtnClearHistory.pressed.connect(_on_clear_history)

	opt_difficulty.item_selected.connect(_on_difficulty_selected)
	chk_sfx.toggled.connect(func(v): settings.sfx = v; _save_settings())
	chk_music.toggled.connect(func(v): settings.music = v; _save_settings(); _apply_music_state())
	chk_autosave.toggled.connect(func(v): settings.autosave = v; _save_settings())

	btn_radar.pressed.connect(_on_radar_pressed)
	btn_airstrike.pressed.connect(_on_airstrike_pressed)
	$Screens/Game/GameRoot/GameBody/Sidebar/GameButtons/BtnSave.pressed.connect(_on_save_game)
	$Screens/Game/GameRoot/GameBody/Sidebar/GameButtons/BtnLoad.pressed.connect(_on_load_game)
	$Screens/Game/GameRoot/GameBody/Sidebar/GameButtons/BtnSurrender.pressed.connect(_on_surrender)
	$Screens/Game/GameRoot/GameBody/Sidebar/GameButtons/BtnGameMenu.pressed.connect(func(): _click(); AudioManager.stop_music(); _show_screen(screen_menu); _apply_music_state())

	$Screens/Result/ResultVBox/BtnReplay.pressed.connect(_on_play)
	$Screens/Result/ResultVBox/BtnResultMenu.pressed.connect(func(): _click(); _show_screen(screen_menu); _apply_music_state())

	$Screens/Placement/PlacementVBox/PlacementBody/Right/PlacementControls/BtnRotate.pressed.connect(_on_placement_rotate)
	$Screens/Placement/PlacementVBox/PlacementBody/Right/PlacementControls/BtnAuto.pressed.connect(_on_placement_auto)
	$Screens/Placement/PlacementVBox/PlacementBody/Right/PlacementControls/BtnClear.pressed.connect(_on_placement_clear)
	$Screens/Placement/PlacementVBox/PlacementBody/Right/PlacementControls/BtnStart.pressed.connect(_on_placement_start)
	$Screens/Placement/PlacementVBox/PlacementBody/Right/PlacementControls/BtnPlacementBack.pressed.connect(func(): _click(); _show_screen(screen_menu))

func _click() -> void:
	if bool(settings.get("sfx", true)):
		AudioManager.play_sfx("click")

func _on_difficulty_selected(index: int) -> void:
	if index == 0: settings.difficulty = "easy"
	elif index == 2: settings.difficulty = "hard"
	else: settings.difficulty = "medium"
	_save_settings()

func _on_play() -> void:
	_click()
	selected_ability = ""
	_start_placement()
	_show_screen(screen_placement)
	_apply_music_state()

func _show_screen(s: Control) -> void:
	for child in screens.get_children():
		child.visible = (child == s)

func _build_boards_ui() -> void:
	_player_buttons = _build_grid(grid_player, false)
	_enemy_buttons = _build_grid(grid_enemy, true)

func _build_grid(container: GridContainer, clickable: bool) -> Array:
	for ch in container.get_children():
		ch.queue_free()
	var buttons: Array = []
	buttons.resize(Constants.BOARD_SIZE * Constants.BOARD_SIZE)

	container.add_child(Label.new())
	for c in range(Constants.BOARD_SIZE):
		var l := Label.new()
		l.text = String.chr(65 + c)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		container.add_child(l)

	for r in range(Constants.BOARD_SIZE):
		var rl := Label.new()
		rl.text = str(r + 1)
		rl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		container.add_child(rl)
		for c in range(Constants.BOARD_SIZE):
			var b := Button.new()
			b.custom_minimum_size = Vector2(34, 34)
			b.text = ""
			b.focus_mode = Control.FOCUS_NONE
			b.icon = WATER_TEXTURE
			b.expand_icon = true
			b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
			var idx := Constants.rc(r, c)
			buttons[idx] = b
			container.add_child(b)
			if clickable:
				b.pressed.connect(func(rr=r, cc=c): _on_enemy_cell_pressed(rr, cc))
	return buttons

func _on_enemy_cell_pressed(r: int, c: int) -> void:
	if game == null or game.over or game.turn != "player":
		return
	if selected_ability != "":
		_click()
		if selected_ability == "radar":
			var res := game.use_radar(r, c)
			_update_abilities_ui()
			_flash_radar(res)
		elif selected_ability == "airstrike":
			if bool(settings.get("sfx", true)):
				AudioManager.play_sfx("shot")
			var res2 := game.use_airstrike(r, c)
			selected_ability = ""
			_update_all_ui()
			if game.over:
				_end_game(true)
				return
			await _enemy_turn_loop()
		if bool(settings.get("autosave", true)):
			_on_save_game(true)
		return

	if bool(settings.get("sfx", true)):
		AudioManager.play_sfx("shot")
	var shot_v: Variant = game.player_shoot(r, c)
	if shot_v == null:
		return
	var shot: Dictionary = shot_v
	if shot.result == "miss":
		if bool(settings.get("sfx", true)):
			AudioManager.play_sfx("miss")
		_update_all_ui()
		await _enemy_turn_loop()
	else:
		if shot.get("sunk", false) and bool(settings.get("sfx", true)):
			AudioManager.play_sfx("destroy")
		_update_all_ui()
		if game.over:
			_end_game(true)
			return
	if bool(settings.get("autosave", true)):
		_on_save_game(true)

func _flash_radar(res: Array) -> void:
	selected_ability = ""
	_update_abilities_ui()
	for info in res:
		var r := int(info.r)
		var c := int(info.c)
		var b: Button = _enemy_buttons[Constants.rc(r, c)]
		if bool(info.has_ship):
			b.text = "●"
			b.modulate = Color(0.4, 1.0, 0.4)
		else:
			b.modulate = Color(1, 1, 1)
	await get_tree().create_timer(2.5).timeout
	_update_enemy_board_ui()

func _enemy_turn_loop() -> void:
	_update_all_ui()
	await get_tree().create_timer(0.6).timeout
	while game != null and not game.over and game.turn == "enemy":
		var step_v: Variant = game.enemy_take_step()
		if bool(settings.get("sfx", true)):
			AudioManager.play_sfx("shot")
		await get_tree().create_timer(0.25).timeout
		var step: Dictionary = {} if step_v == null else step_v
		if step_v != null and step.result == "miss" and bool(settings.get("sfx", true)):
			AudioManager.play_sfx("miss")
		elif step_v != null and step.result == "hit" and step.get("sunk", false) and bool(settings.get("sfx", true)):
			AudioManager.play_sfx("destroy")
		_update_all_ui()
		if game.over:
			_end_game(false)
			return
		await get_tree().create_timer(0.7).timeout

func _update_all_ui() -> void:
	_update_turn_ui()
	_update_stats_ui()
	_update_abilities_ui()
	_update_player_board_ui()
	_update_enemy_board_ui()

func _update_turn_ui() -> void:
	if game == null:
		lbl_turn.text = ""
		return
	lbl_turn.text = "Хід гравця" if game.turn == "player" else "Хід противника"

func _update_stats_ui() -> void:
	if game == null:
		return
	var total := game.hits + game.misses
	var acc := 0
	if total > 0:
		acc = int(round(float(game.hits) / float(total) * 100.0))
	lbl_stats.text = "Ходи: %d\nВлучання: %d\nПромахи: %d\nТочність: %d%%" % [game.moves, game.hits, game.misses, acc]

func _update_abilities_ui() -> void:
	if game == null:
		return
	btn_radar.text = "Радар 3×3 (%d)" % int(game.abilities.radar)
	btn_airstrike.text = "Авіаудар 3×3 (%d)" % int(game.abilities.airstrike)
	btn_radar.disabled = game.turn != "player" or int(game.abilities.radar) <= 0
	btn_airstrike.disabled = game.turn != "player" or int(game.abilities.airstrike) <= 0

func _get_ship_size_by_id(ship_id: int) -> int:
	if _placement_board != null:
		for ship in _placement_board.ships:
			if ship.id == ship_id:
				return ship.size
	if game != null:
		for ship in game.player_board.ships:
			if ship.id == ship_id:
				return ship.size
		for ship in game.enemy_board.ships:
			if ship.id == ship_id:
				return ship.size
	return 0

func _update_player_board_ui() -> void:
	if game == null:
		return
	for r in range(Constants.BOARD_SIZE):
		for c in range(Constants.BOARD_SIZE):
			var cd: Dictionary = game.player_board.cell(r, c)
			var b: Button = _player_buttons[Constants.rc(r, c)]
			b.modulate = Color(1,1,1)
			b.icon = WATER_TEXTURE
			b.expand_icon = true
			b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
			b.text = ""
			if cd.state == "ship":
				var ship_id: int = int(cd.get("ship_id", -1))
				var ship_size: int = _get_ship_size_by_id(ship_id)
				if ship_size > 0 and SHIP_TEXTURES.has(ship_size):
					b.icon = SHIP_TEXTURES[ship_size]
			if cd.state == "miss":
				b.text = "•"
				b.modulate = Color(0.6,0.8,1)
			if cd.state == "hit":
				b.text = "X"
				b.modulate = Color(1,0.55,0.55)
			if bool(cd.get("sunk", false)):
				b.modulate = Color(1,0.3,0.3)

func _update_enemy_board_ui() -> void:
	if game == null:
		return
	for r in range(Constants.BOARD_SIZE):
		for c in range(Constants.BOARD_SIZE):
			var cd: Dictionary = game.enemy_board.cell(r, c)
			var b: Button = _enemy_buttons[Constants.rc(r, c)]
			b.modulate = Color(1,1,1)
			b.icon = WATER_TEXTURE
			b.expand_icon = true
			b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
			b.text = ""
			if cd.state == "miss":
				b.text = "•"
				b.modulate = Color(0.6,0.8,1)
			if cd.state == "hit":
				b.text = "X"
				b.modulate = Color(1,0.55,0.55)
			if bool(cd.get("sunk", false)):
				b.modulate = Color(1,0.3,0.3)

func _on_radar_pressed() -> void:
	if game == null:
		return
	_click()
	selected_ability = "radar" if selected_ability != "radar" else ""

func _on_airstrike_pressed() -> void:
	if game == null:
		return
	_click()
	selected_ability = "airstrike" if selected_ability != "airstrike" else ""

func _on_save_game(silent: bool = false) -> void:
	if game == null:
		return
	if not silent:
		_click()
	var snap := game.to_snapshot(String(settings.get("difficulty", "medium")))
	Storage.save_json("save_game", snap)

func _on_load_game() -> void:
	_click()
	var snap = Storage.load_json("save_game", null)
	if snap == null:
		return
	if typeof(snap) != TYPE_DICTIONARY:
		return
	game = GameControllerClass.from_snapshot(snap)
	settings.difficulty = String(snap.get("difficulty", settings.difficulty))
	_save_settings()
	_apply_settings_ui()
	selected_ability = ""
	_update_all_ui()
	_show_screen(screen_game)
	_apply_music_state()

func _on_surrender() -> void:
	if game == null or game.over:
		return
	_click()
	game.over = true
	_end_game(false)

func _end_game(player_won: bool) -> void:
	print("_end_game called, player_won=", player_won)
	AudioManager.stop_music()
	if bool(settings.get("sfx", true)):
		AudioManager.play_sfx("win" if player_won else "lose")
	_save_history(player_won)
	var total := game.hits + game.misses
	var acc := 0
	if total > 0:
		acc = int(round(float(game.hits) / float(total) * 100.0))
	lbl_result_text.text = ("Перемога!\n" if player_won else "Поразка\n") + "Ходи: %d\nВлучання: %d\nПромахи: %d\nТочність: %d%%\nСкладність: %s" % [game.moves, game.hits, game.misses, acc, String(settings.get("difficulty", "medium"))]
	_show_screen(screen_result)

func _history_key() -> String:
	return "history"

func _load_history() -> Array:
	print("_load_history: loading history...")
	var h = Storage.load_json(_history_key(), [])
	print("_load_history: raw loaded type=", typeof(h))
	if typeof(h) != TYPE_ARRAY:
		print("_load_history: not an array, returning empty")
		return []
	print("_load_history: loaded %d entries" % h.size())
	return h

func _save_history_entry(entry: Dictionary) -> void:
	var h := _load_history()
	h.insert(0, entry)
	if h.size() > 50:
		h = h.slice(0, 50)
	print("_save_history_entry: saving %d entries" % h.size())
	Storage.save_json(_history_key(), h)

func _save_history(player_won: bool) -> void:
	print("_save_history called")
	if game == null:
		print("_save_history: game is null, returning")
		return
	var total := game.hits + game.misses
	var acc := 0
	if total > 0:
		acc = int(round(float(game.hits) / float(total) * 100.0))
	_save_history_entry({
		"ts": Time.get_unix_time_from_system(),
		"won": player_won,
		"moves": game.moves,
		"accuracy": acc,
		"difficulty": String(settings.get("difficulty", "medium")),
	})

func _refresh_history() -> void:
	print("_refresh_history called")
	var h := _load_history()
	var rt: RichTextLabel = $Screens/History/HistoryVBox/HistoryText
	if h.size() == 0:
		rt.text = "Немає записів."
		return
	var lines := "[table=5][tr][th]Результат[/th][th]Ходи[/th][th]Точність[/th][th]Складність[/th][th]Час[/th][/tr]"
	for e in h:
		var res := "Перемога" if bool(e.get("won", false)) else "Поразка"
		var t := int(e.get("ts", 0))
		var dt := Time.get_datetime_dict_from_unix_time(t)
		var when := "%02d.%02d %02d:%02d" % [int(dt.day), int(dt.month), int(dt.hour), int(dt.minute)]
		lines += "[tr][td]%s[/td][td]%d[/td][td]%d%%[/td][td]%s[/td][td]%s[/td][/tr]" % [res, int(e.get("moves", 0)), int(e.get("accuracy", 0)), String(e.get("difficulty", "medium")), when]
	lines += "[/table]"
	rt.text = lines

func _on_clear_history() -> void:
	_click()
	Storage.clear(_history_key())
	_refresh_history()

# ---------- Placement ----------

func _build_placement_ui() -> void:
	_placement_buttons = _build_grid(grid_placement, false)
	for r in range(Constants.BOARD_SIZE):
		for c in range(Constants.BOARD_SIZE):
			var b: Button = _placement_buttons[Constants.rc(r, c)]
			b.pressed.connect(func(rr=r, cc=c): _on_placement_cell_pressed(rr, cc))
			b.mouse_entered.connect(func(rr=r, cc=c): _placement_hover_r = rr; _placement_hover_c = cc; _update_placement_board_ui())
			b.mouse_exited.connect(func(): _placement_hover_r = -1; _placement_hover_c = -1; _update_placement_board_ui())
	for ch in ships_container.get_children():
		ch.queue_free()
	_placement_ship_buttons = []
	for i in range(Constants.SHIPS_DEF.size()):
		var def = Constants.SHIPS_DEF[i]
		var size: int = int(def.size)
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(200, 40)
		btn.text = "%s ×%d" % [String(def.name), int(def.count)]
		if SHIP_TEXTURES.has(size):
			btn.icon = SHIP_TEXTURES[size]
			btn.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
			btn.expand_icon = true
		btn.pressed.connect(func(ii=i): _on_placement_ship_selected(ii))
		ships_container.add_child(btn)
		_placement_ship_buttons.append(btn)

func _start_placement() -> void:
	_placement_board = preload("res://scripts/board.gd").new()
	_placement_board._reset()
	_placement_selected_def_index = -1
	_placement_vertical = false
	_placement_hover_r = -1
	_placement_hover_c = -1
	_placement_next_id = 0
	_placement_ships_left = {}
	for i in range(Constants.SHIPS_DEF.size()):
		_placement_ships_left[i] = int(Constants.SHIPS_DEF[i].count)
	for btn in _placement_ship_buttons:
		btn.disabled = false
		btn.modulate = Color(1, 1, 1)
	_update_placement_board_ui()

func _on_placement_ship_selected(idx: int) -> void:
	_click()
	if _placement_ships_left.get(idx, 0) <= 0:
		return
	_placement_selected_def_index = idx
	for i in range(_placement_ship_buttons.size()):
		_placement_ship_buttons[i].modulate = Color(1.3, 1.3, 0.7) if i == idx else Color(1, 1, 1)

func _on_placement_rotate() -> void:
	_click()
	_placement_vertical = not _placement_vertical

func _on_placement_cell_pressed(r: int, c: int) -> void:
	_click()
	if _placement_selected_def_index < 0:
		return
	if _placement_ships_left.get(_placement_selected_def_index, 0) <= 0:
		return
	_try_place_ship(r, c)

func _try_place_ship(r: int, c: int) -> void:
	var def = Constants.SHIPS_DEF[_placement_selected_def_index]
	var size: int = int(def.size)
	if not _placement_board.can_place(r, c, size, _placement_vertical):
		return
	var ship := preload("res://scripts/ship.gd").new(size, _placement_next_id)
	_placement_next_id += 1
	_placement_board.place_ship(ship, r, c, _placement_vertical)
	_placement_ships_left[_placement_selected_def_index] = int(_placement_ships_left[_placement_selected_def_index]) - 1
	if _placement_ships_left[_placement_selected_def_index] <= 0:
		_placement_ship_buttons[_placement_selected_def_index].disabled = true
		_placement_selected_def_index = -1
		for btn in _placement_ship_buttons:
			btn.modulate = Color(1, 1, 1)
	_update_placement_board_ui()

func _on_placement_auto() -> void:
	_click()
	_placement_board._reset()
	_placement_next_id = 0
	for i in range(Constants.SHIPS_DEF.size()):
		_placement_ships_left[i] = int(Constants.SHIPS_DEF[i].count)
	var ok := _placement_board.auto_place_all()
	if ok:
		_placement_next_id = _placement_board.ships.size()
		for i in range(Constants.SHIPS_DEF.size()):
			_placement_ships_left[i] = 0
		for btn in _placement_ship_buttons:
			btn.disabled = true
			btn.modulate = Color(1, 1, 1)
		_placement_selected_def_index = -1
	_update_placement_board_ui()

func _on_placement_clear() -> void:
	_click()
	_placement_board._reset()
	_placement_next_id = 0
	for i in range(Constants.SHIPS_DEF.size()):
		_placement_ships_left[i] = int(Constants.SHIPS_DEF[i].count)
	for btn in _placement_ship_buttons:
		btn.disabled = false
		btn.modulate = Color(1, 1, 1)
	_placement_selected_def_index = -1
	_update_placement_board_ui()

func _is_placement_complete() -> bool:
	for v in _placement_ships_left.values():
		if int(v) > 0:
			return false
	return true

func _on_placement_start() -> void:
	_click()
	if not _is_placement_complete():
		return
	_start_game_with_placement()

func _start_game_with_placement() -> void:
	selected_ability = ""
	game = GameControllerClass.new(String(settings.get("difficulty", "medium")))
	game.start_new_with_board(_placement_board)
	_placement_board = null
	_update_all_ui()
	_show_screen(screen_game)
	_apply_music_state()

func _update_placement_board_ui() -> void:
	if _placement_board == null:
		return
	for r in range(Constants.BOARD_SIZE):
		for c in range(Constants.BOARD_SIZE):
			var cd: Dictionary = _placement_board.cell(r, c)
			var b: Button = _placement_buttons[Constants.rc(r, c)]
			b.modulate = Color(1, 1, 1)
			b.icon = WATER_TEXTURE
			b.expand_icon = true
			b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
			b.text = ""
			if cd.state == "ship":
				var ship_id: int = int(cd.get("ship_id", -1))
				var ship_size: int = _get_ship_size_by_id(ship_id)
				if ship_size > 0 and SHIP_TEXTURES.has(ship_size):
					b.icon = SHIP_TEXTURES[ship_size]
	# hover preview
	if _placement_selected_def_index >= 0 and _placement_hover_r >= 0 and _placement_hover_c >= 0:
		var def = Constants.SHIPS_DEF[_placement_selected_def_index]
		var size: int = int(def.size)
		var can := _placement_board.can_place(_placement_hover_r, _placement_hover_c, size, _placement_vertical)
		for i in range(size):
			var rr := _placement_hover_r + (i if _placement_vertical else 0)
			var cc := _placement_hover_c + (0 if _placement_vertical else i)
			if Constants.in_bounds(rr, cc):
				var b: Button = _placement_buttons[Constants.rc(rr, cc)]
				b.text = ""
				if SHIP_TEXTURES.has(size):
					b.icon = SHIP_TEXTURES[size]
					b.expand_icon = true
					b.modulate = Color(0.4, 1.0, 0.4, 0.7) if can else Color(1.0, 0.4, 0.4, 0.7)
				else:
					b.text = "□"
					b.modulate = Color(0.4, 1.0, 0.4) if can else Color(1.0, 0.4, 0.4)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_R:
		if screen_placement.visible and _placement_board != null:
			_placement_vertical = not _placement_vertical
			_update_placement_board_ui()

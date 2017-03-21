###############################################################################
# Copyright (c) 2017 Denis Ponomarev
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
###############################################################################

extends Node2D

const Constants = preload("res://constants.gd")

const SCORES_DATA = "user://scores.dat"
const GAME_STATE_DATA = "user://game.dat"

const STATE_GAME = 0
const STATE_END = 1

var state = STATE_END

var texture_0
var texture_1
var texture_2
var texture_3
var texture_4

onready var field_box = get_node("field_box")

var score = 0
onready var score_node = get_node("box/score")

var possible = 0
onready var possible_node = get_node("box/possible")

var field = {}
onready var count_node_0 = get_node("box/box_0")
onready var count_node_1 = get_node("box/box_1")
onready var count_node_2 = get_node("box/box_2")
onready var count_node_3 = get_node("box/box_3")
onready var count_node_4 = get_node("box/box_4")

var history = []
var history_scores = []
var history_possible = []

const top_score_count = 3
var top_scores = []

# -----------------------------------------------------------------------------
func _ready():
	# cache textures
	texture_0 = load("res://gfx/box_0.png")
	texture_1 = load("res://gfx/box_1.png")
	texture_2 = load("res://gfx/box_2.png")
	texture_3 = load("res://gfx/box_3.png")
	texture_4 = load("res://gfx/box_4.png")
	
	# build field
	for row in range(Constants.FieldHeight):
		for column in range(Constants.FieldWidth):
			field[[column, row]] = TextureFrame.new()
			field_box.add_child(field[[column, row]])
			field[[column, row]].set_pos(Vector2(column * Constants.QuadSize, row * Constants.QuadSize))
	
	# read top scores
	_top_scores_load()
	
	# start new game
	if !_load_game():
		_new_game()

# -----------------------------------------------------------------------------
func _top_scores_load():
	var f = File.new()
	if (!f.file_exists(SCORES_DATA)):
		for i in range(top_score_count):
			top_scores.append({"year":1970, "month":1, "day":1, "score":0})
	else:
		f.open(SCORES_DATA, f.READ)
		for i in range(top_score_count):
			top_scores.append({"year":f.get_16(), "month":f.get_16(), "day":f.get_16(), "score":f.get_16()})
		top_scores.sort_custom(self, "_custom_compare2")
		f.close()

# -----------------------------------------------------------------------------
func _top_scores_save():
	var f = File.new()
	f.open(SCORES_DATA, f.WRITE)
	for i in range(top_score_count):
		f.store_16(top_scores[i]["year"])
		f.store_16(top_scores[i]["month"])
		f.store_16(top_scores[i]["day"])
		f.store_16(top_scores[i]["score"])
	f.close()

# -----------------------------------------------------------------------------
func _save_game():
	var f = File.new()
	f.open(GAME_STATE_DATA, f.WRITE)
	# save current state
	f.store_32(score)
	for row in range(Constants.FieldHeight):
		for column in range(Constants.FieldWidth):
			if (field[[column, row]].get_texture() == texture_0):
				f.store_32(Constants.Quad_0)
			elif (field[[column, row]].get_texture() == texture_1):
				f.store_32(Constants.Quad_1)
			elif (field[[column, row]].get_texture() == texture_2):
				f.store_32(Constants.Quad_2)
			elif (field[[column, row]].get_texture() == texture_3):
				f.store_32(Constants.Quad_3)
			elif (field[[column, row]].get_texture() == texture_4):
				f.store_32(Constants.Quad_4)
			else:
				f.store_32(Constants.QuadNone)
	# save history
	f.store_32(history.size())
	for i in range(history.size()):
		for row in range(Constants.FieldHeight):
			for column in range(Constants.FieldWidth):
				f.store_32(history[i][[column, row]])
		f.store_32(history_scores[i])
		f.store_32(history_possible[i])
	f.close()

# -----------------------------------------------------------------------------
func _load_game():
	var f = File.new()
	if !f.file_exists(GAME_STATE_DATA):
		return false
	f.open(GAME_STATE_DATA, f.READ)
	if f.get_len() == 1:
		return false
	# load current state
	score = f.get_32()
	for row in range(Constants.FieldHeight):
		for column in range(Constants.FieldWidth):
			var rv = f.get_32()
			if (rv == Constants.Quad_0):
				field[[column, row]].set_texture(texture_0)
			elif (rv == Constants.Quad_1):
				field[[column, row]].set_texture(texture_1)
			elif (rv == Constants.Quad_2):
				field[[column, row]].set_texture(texture_2)
			elif (rv == Constants.Quad_3):
				field[[column, row]].set_texture(texture_3)
			elif (rv == Constants.Quad_4):
				field[[column, row]].set_texture(texture_4)
			else:
				field[[column, row]].set_texture(null)
	# load history
	var history_size = f.get_32()
	history.resize(history_size)
	history_scores.resize(history_size)
	history_possible.resize(history_size)
	if history_size > 0:
		for i in range(history.size()):
			history[i] = {}
			for row in range(Constants.FieldHeight):
				for column in range(Constants.FieldWidth):
					history[i][[column, row]] = f.get_32()
			history_scores[i] = f.get_32()
			history_possible[i] = f.get_32()
	f.close()
	possible = _get_possible_moves()
	_update_counters()
	state = STATE_GAME
	return true

# -----------------------------------------------------------------------------
func _select_item(x, y):
	var find_field = _find_quad_blocks(x, y)
	
	if (find_field == null || find_field.size() <= 1):
		if (find_field != null && find_field.size() <= 1):
			get_node("player").play("deny_blocks")
		return
	
	_mem_state()
	get_node("player").play("destroy_blocks")
	
	var counter = 0
	for item in find_field:
		field[item].set_texture(null)
		if (counter > 0):
			score += (counter * 2 - 1)
		counter += 1
	
	_compact_quads()
	possible = _get_possible_moves()
	_update_counters()
	
	# check avaible moves	
	if (possible == 0):
		state = STATE_END
		if (_check_win()):
			score = int(score * 1.5)
			_show_message_win()
		else:
			_show_message_lose()
		
		for i in range(top_score_count):
			if (top_scores[i]["score"] <= score):
				var date = OS.get_date()
				top_scores.insert(i, { "year":date["year"], "month":date["month"], "day":date["day"], "score":score })
				top_scores.pop_back()
				_top_scores_save()
				break

# -----------------------------------------------------------------------------
func _check_win():
	for row in range(Constants.FieldHeight):
		for column in range(Constants.FieldWidth):
			if (field[[column, row]].get_texture() != null):
				return false
	return true

# -----------------------------------------------------------------------------
func _get_possible_moves():
	var pm = [];
	for row in range(Constants.FieldHeight):
		for column in range(Constants.FieldWidth):
			if (field[[column, row]].get_texture() == null):
				continue
			
			var moves = _find_quad_blocks(column, row);
			moves.sort_custom(self, "_custom_compare")
			if (moves != null && moves.size() > 1 && !pm.has(moves)):
				pm.append(moves)
	return pm.size()
# -----------------------------------------------------------------------------
func _find_quad_blocks(x, y):
	var type = field[[x, y]].get_texture()
	
	if (type == null):
		return null
	
	# find block items
	var find_field = {}
	find_field[[x, y]] = false
	
	var block_found = false
	while !block_found:
		block_found = true
		var new_items = {}
		for item in find_field:
			if (find_field[item]):
				continue
			
			find_field[item] = true
			var x = item[0]
			var y = item[1]
						
			# find up
			if (y > 0 && field[[x, y - 1]].get_texture() == type && !find_field.has([x, y - 1])):
				new_items[[x, y - 1]] = false
			# find down
			if (y < Constants.FieldHeight - 1 && field[[x, y + 1]].get_texture() == type && !find_field.has([x, y + 1])):
				new_items[[x, y + 1]] = false
			# find left
			if (x > 0 && field[[x - 1, y]].get_texture() == type && !find_field.has([x - 1, y])):
				new_items[[x - 1, y]] = false
			#find right
			if (x < Constants.FieldWidth - 1 && field[[x + 1, y]].get_texture() == type && !find_field.has([x + 1, y])):
				new_items[[x + 1, y]] = false
		
		if (!new_items.empty()):
			block_found = false
			for item in new_items:
				find_field[item] = new_items[item]
	
	var rv = find_field.keys()
	return rv

# -----------------------------------------------------------------------------
func _compact_quads():
	# vertical compact
	var moved = true
	while (moved):
		moved = false
		for x in range(Constants.FieldWidth):
			for y in range(Constants.FieldHeight):
				y = Constants.FieldHeight - y - 1
				if (field[[x, y]].get_texture() == null):
					continue
					
				if (y < Constants.FieldHeight - 1 && field[[x, y + 1]].get_texture() == null):
					field[[x, y + 1]].set_texture(field[[x, y]].get_texture())
					field[[x, y]].set_texture(null)
					moved = true
	
	# horizontal compact
	var offset_counter = 0
	for x in range(Constants.FieldWidth):
		if (field[[x, Constants.FieldHeight - 1]].get_texture() == null):
			offset_counter += 1
		elif (offset_counter > 0):
			for y in range(Constants.FieldHeight):
				if (field[[x, y]].get_texture() != null):
					field[[x - offset_counter, y]].set_texture(field[[x, y]].get_texture())
					field[[x, y]].set_texture(null)

# -----------------------------------------------------------------------------
func _update_counters():
	var red_count = 0
	var blue_count = 0
	var green_count = 0
	var yellow_count = 0
	var orange_count = 0
	
	for row in range(Constants.FieldHeight):
		for column in range(Constants.FieldWidth):
			if (field[[column, row]].get_texture() == texture_0):
				red_count += 1
			elif (field[[column, row]].get_texture() == texture_1):
				blue_count += 1
			elif (field[[column, row]].get_texture() == texture_2):
				green_count += 1
			elif (field[[column, row]].get_texture() == texture_3):
				yellow_count += 1
			elif (field[[column, row]].get_texture() == texture_4):
				orange_count += 1
	
	score_node.set_text(str(score))
	possible_node.set_text(str(possible))
	count_node_0.set_text(str(red_count))
	count_node_1.set_text(str(blue_count))
	count_node_2.set_text(str(green_count))
	count_node_3.set_text(str(yellow_count))
	count_node_4.set_text(str(orange_count))

# -----------------------------------------------------------------------------
func _mem_state():
	var state = {}
	for row in range(Constants.FieldHeight):
		for column in range(Constants.FieldWidth):
			if (field[[column, row]].get_texture() == texture_0):
				state[[column, row]] = Constants.Quad_0
			elif (field[[column, row]].get_texture() == texture_1):
				state[[column, row]] = Constants.Quad_1
			elif (field[[column, row]].get_texture() == texture_2):
				state[[column, row]] = Constants.Quad_2
			elif (field[[column, row]].get_texture() == texture_3):
				state[[column, row]] = Constants.Quad_3
			elif (field[[column, row]].get_texture() == texture_4):
				state[[column, row]] = Constants.Quad_4
			else:
				state[[column, row]] = Constants.QuadNone
	
	history.append(state)
	history_scores.append(score)
	history_possible.append(possible)

# -----------------------------------------------------------------------------
func _show_top_score():
	var strs = ["overlay/top_scores_panel/top_1", "overlay/top_scores_panel/top_2", "overlay/top_scores_panel/top_3"]
	for idx in range(strs.size()):
		var y_str = str(top_scores[idx]["year"])
		
		var m_str
		if (top_scores[idx]["month"] < 10):
			m_str = "0" + str(top_scores[idx]["month"])
		else:
			m_str = str(top_scores[idx]["month"])
		
		var d_str
		if (top_scores[idx]["day"] < 10):
			d_str = "0" + str(top_scores[idx]["day"])
		else:
			d_str = str(top_scores[idx]["day"])
		
		var s_str = str(top_scores[idx]["score"])
		for i in range(6 - str(top_scores[idx]["score"]).length()):
			s_str = "0" + s_str
		
		get_node(strs[idx]).set_text(y_str + "." + m_str + "." + d_str + "....................." + s_str)
	
	get_tree().set_pause(true)
	get_node("overlay").show()
	get_node("overlay/top_scores_panel").show()

# -----------------------------------------------------------------------------
func _hide_top_score():
	get_tree().set_pause(false)
	get_node("overlay").hide()
	get_node("overlay/top_scores_panel").hide()

# -----------------------------------------------------------------------------
func _show_message_win():
	get_tree().set_pause(true)
	get_node("overlay").show()
	get_node("overlay/message_win").show()

# -----------------------------------------------------------------------------
func _hide_message_win():
	get_tree().set_pause(false)
	get_node("overlay").hide()
	get_node("overlay/message_win").hide()
	_new_game()

# -----------------------------------------------------------------------------
func _show_message_lose():
	get_tree().set_pause(true)
	get_node("overlay").show()
	get_node("overlay/message_lose").show()

# -----------------------------------------------------------------------------
func _hide_message_lose():
	get_tree().set_pause(false)
	get_node("overlay").hide()
	get_node("overlay/message_lose").hide()
	_new_game()

# -----------------------------------------------------------------------------
func _quit_game():	
	if state == STATE_GAME:
		_save_game()
	elif state == STATE_END:
		_remove_saved_state()
	get_tree().quit()

# -----------------------------------------------------------------------------
func _remove_saved_state():
	var f = File.new()
	if f.file_exists(GAME_STATE_DATA):
		f.open(GAME_STATE_DATA, f.WRITE)
		f.store_8(0)
		f.close()

# -----------------------------------------------------------------------------
func _notification(what):
	if what == MainLoop.NOTIFICATION_WM_QUIT_REQUEST:
		print("NOTIFICATION_WM_QUIT_REQUEST")
		# quitting app or back-button on Android
		_quit_game()
	if what == MainLoop.NOTIFICATION_WM_FOCUS_OUT && OS.get_name().nocasecmp_to("windows") != 0:
		# switched to different app
		if state == STATE_GAME:
			_save_game()
		elif state == STATE_END:
			_remove_saved_state()

# -----------------------------------------------------------------------------
func _new_game():
	_remove_saved_state()
	randomize()
	score = 0
	
	history.clear()
	history_scores.clear()
	history_possible.clear()
	
	for row in range(Constants.FieldHeight):
		for column in range(Constants.FieldWidth):
			var type = randi() % 5 # 5
			if (type == Constants.Quad_0):
				field[[column, row]].set_texture(texture_0)
			elif (type == Constants.Quad_1):
				field[[column, row]].set_texture(texture_1)
			elif (type == Constants.Quad_2):
				field[[column, row]].set_texture(texture_2)
			elif (type == Constants.Quad_3):
				field[[column, row]].set_texture(texture_3)
			elif (type == Constants.Quad_4):
				field[[column, row]].set_texture(texture_4)
			else:
				field[[column, row]].set_texture(null)
	
	possible = _get_possible_moves()
	_update_counters()
	state = STATE_GAME

# -----------------------------------------------------------------------------
func _undo():
	if (history.size() != 0):
		score = history_scores[history_scores.size() - 1]
		history_scores.pop_back()
		
		possible = history_possible[history_possible.size() - 1]
		history_possible.pop_back()
		
		var state = history[history.size() - 1]
		history.pop_back()
		
		for row in range(Constants.FieldHeight):
			for column in range(Constants.FieldWidth):
				if (state[[column, row]] == Constants.Quad_0):
					field[[column, row]].set_texture(texture_0)
				elif (state[[column, row]] == Constants.Quad_1):
					field[[column, row]].set_texture(texture_1)
				elif (state[[column, row]] == Constants.Quad_2):
					field[[column, row]].set_texture(texture_2)
				elif (state[[column, row]] == Constants.Quad_3):
					field[[column, row]].set_texture(texture_3)
				elif (state[[column, row]] == Constants.Quad_4):
					field[[column, row]].set_texture(texture_4)
				else:
					field[[column, row]].set_texture(null)
		
		_update_counters()

func _custom_compare(a1, a2):
	if (a1[0] == a2[0]):
		return a1[1] < a2[1]
	return a1[0] < a2[0]

func _custom_compare2(a1, a2):
	return a1["score"] > a2["score"]
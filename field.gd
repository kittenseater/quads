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

extends Container

const Constants = preload("constants.gd")

signal item_selected(x, y)

func _ready():
	connect("item_selected", get_tree().get_root().get_node("scene_root"), "_select_item")
	set_process_input(true)

func _input(event):
	if (event.type == InputEvent.MOUSE_BUTTON && event.is_pressed() && get_rect().has_point(Vector2(event.x, event.y))):
		var x = int((event.x - get_pos().x) / Constants.QuadSize)
		var y = int((event.y - get_pos().y) / Constants.QuadSize)
		emit_signal("item_selected", x, y)
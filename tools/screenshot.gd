extends SceneTree
## Dev helper: open a scene windowed, wait a moment, save a screenshot, quit.
## Run: godot -s tools/screenshot.gd -- <res://scene.tscn> <out.png> [frames]

var _frames := 0
var _wait := 90
var _out := "shot.png"


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		push_error("usage: godot -s tools/screenshot.gd -- <scene> <out.png> [frames]")
		quit(1)
		return
	_out = args[1]
	if args.size() > 2:
		_wait = int(args[2])
	change_scene_to_file.call_deferred(args[0])
	process_frame.connect(_tick)


func _tick() -> void:
	_frames += 1
	if _frames < _wait:
		return
	var img := root.get_texture().get_image()
	img.save_png(_out)
	print("Saved %s" % _out)
	quit()

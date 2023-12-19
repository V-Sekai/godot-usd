#	Copyright (c) 2021 K. S. Ernest (iFire) Lee and V-Sekai Contributors.
#	Copyright (c) 2007-2021 Juan Linietsky, Ariel Manzur.
#	Copyright (c) 2014-2021 Godot Engine contributors (cf. AUTHORS.md).
#
#	Permission is hereby granted, free of charge, to any person obtaining a copy
#	of this software and associated documentation files (the "Software"), to deal
#	in the Software without restriction, including without limitation the rights
#	to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
#	copies of the Software, and to permit persons to whom the Software is
#	furnished to do so, subject to the following conditions:
#
#	The above copyright notice and this permission notice shall be included in all
#	copies or substantial portions of the Software.
#
#	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
#	IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
#	FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
#	AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
#	LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
#	OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
#	SOFTWARE.

@tool
extends EditorSceneFormatImporter

func _get_extensions():
	return ["usd", "usdc"]


func _get_import_flags():
	return EditorSceneFormatImporter.IMPORT_SCENE


func _import_scene(path: String, flags: int, options: Dictionary):
	var import_config_file = ConfigFile.new()
	import_config_file.load(path + ".import")
	var compression_flags: int = import_config_file.get_value("params", "meshes/compress", 0)
	# ARRAY_COMPRESS_BASE = (ARRAY_INDEX + 1)
	compression_flags = compression_flags << (RenderingServer.ARRAY_INDEX + 1)

	var path_global : String = ProjectSettings.globalize_path(path)
	path_global = path_global.c_escape()
	var output_path : String = "res://.godot/imported/" + path.get_file().get_basename() + "-" + path.md5_text() + ".glb"
	var output_path_global = ProjectSettings.globalize_path(output_path)
	output_path_global = output_path_global.c_escape()
	var stdout = [].duplicate()
	var addon_path_global = ProjectSettings.get_setting("filesystem/import/blender/blender3_path", "/opt/homebrew/bin/blender")
	var script : String = ("import bpy, os, sys;" +
		"bpy.context.scene.render.fps=" + str(int(30)) + ";" +
		"bpy.ops.wm.usd_import(filepath='GODOT_FILENAME', import_subdiv=True, import_usd_preview=True);" +
		"bpy.ops.export_scene.gltf(filepath='GODOT_EXPORT_PATH',check_existing=True,filter_glob='*.fbx',use_selection=False,use_visible=False,use_active_collection=False,use_mesh_edges=False,export_colors=True,export_all_influences=False,export_extras=True,export_cameras=True,export_lights=True);"
		)
	path_global = path_global.c_escape()
	script = script.replace("GODOT_FILENAME", path_global)
	output_path_global = output_path_global.c_escape()
	script = script.replace("GODOT_EXPORT_PATH", output_path_global)
	var tex_dir_global = output_path_global + "_textures"
	tex_dir_global.c_escape()
	DirAccess.make_dir_recursive_absolute(tex_dir_global)
	script = script.replace("GODOT_TEXTURE_PATH", tex_dir_global)
	var args = [
		"--background",
		"--python-expr",
		script]
	print(args)
	var ret = OS.execute(addon_path_global, args, stdout, true)
	for line in stdout:
		print(line)
	if ret != 0:
		print("Blender returned " + str(ret))
		return null

	var gstate : GLTFState = GLTFState.new()
	var gltf : GLTFDocument = GLTFDocument.new()
	gltf.append_from_file(output_path, gstate, flags, path_global.get_basename())
	var root_node : Node = gltf.generate_scene(gstate, 30, true)
	root_node.name = path.get_basename().get_file()
	return root_node

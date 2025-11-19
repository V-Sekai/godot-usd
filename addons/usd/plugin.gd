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
#
@tool
extends EditorPlugin

var import_plugin
var file_dialog: EditorFileDialog
var gltf_document: GLTFDocument
var export_path: String = ""
var export_copyright: String = ""
var export_bake_fps: float = 30.0

func _enter_tree():
	# Import plugin
	var script = load("res://addons/usd/import_usd.gd")
	import_plugin = script.new()
	add_scene_format_importer_plugin(import_plugin)
	
	# Initialize GLTF document
	gltf_document = GLTFDocument.new()
	
	# Add export menu item
	var menu = get_export_as_menu()
	if menu:
		var idx = menu.get_item_count()
		menu.add_item("USD Scene...")
		menu.set_item_metadata(idx, _popup_usd_export_dialog)
		
		# Set up file dialog
		file_dialog = EditorFileDialog.new()
		file_dialog.file_mode = EditorFileDialog.FILE_MODE_SAVE_FILE
		file_dialog.access = EditorFileDialog.ACCESS_FILESYSTEM
		file_dialog.add_filter("*.usd", "USD Files")
		file_dialog.add_filter("*.usda", "USD ASCII Files")
		file_dialog.add_filter("*.usdc", "USD Crate Files")
		file_dialog.add_filter("*.usdz", "USD Zip Files")
		file_dialog.title = "Export Scene to USD File"
		file_dialog.file_selected.connect(_on_file_selected)
		EditorInterface.get_base_control().add_child(file_dialog)

func _exit_tree():
	remove_scene_format_importer_plugin(import_plugin)
	import_plugin = null
	if file_dialog:
		file_dialog.queue_free()
		file_dialog = null

func _popup_usd_export_dialog():
	var root = EditorInterface.get_edited_scene_root()
	if not root:
		push_error("This operation can't be done without a scene.")
		return
	
	# Set default filename
	var filename = root.get_scene_file_path().get_file().get_basename()
	if filename.is_empty():
		filename = root.name
	file_dialog.current_file = filename + ".usd"
	file_dialog.popup_centered_ratio(0.75)

func _on_file_selected(path: String):
	export_path = path
	_export_scene_as_usd()

func _export_scene_as_usd():
	var root = EditorInterface.get_edited_scene_root()
	if not root:
		return
	
	# Check Blender path
	var blender_path = EditorInterface.get_editor_settings().get_setting("filesystem/import/blender/blender_path")
	if blender_path.is_empty() or not FileAccess.file_exists(blender_path):
		push_error("Blender 3.0+ is required for USD export. Please configure Blender path in Editor Settings.")
		return
	
	# Step 1: Convert Godot scene to GLTF
	var state = GLTFState.new()
	state.set_copyright(export_copyright)
	var flags = EditorSceneFormatImporter.IMPORT_USE_NAMED_SKIN_BINDS
	state.set_bake_fps(export_bake_fps)
	var err = gltf_document.append_from_scene(root, state, flags)
	if err != OK:
		push_error("Failed to convert scene to GLTF for USD export.")
		return
	
	# Step 2: Export GLTF to temporary file
	# Use project's .godot folder for temp file
	var temp_gltf_path = "res://.godot/usd_export_temp_%d.gltf" % Time.get_ticks_msec()
	var temp_gltf_global = ProjectSettings.globalize_path(temp_gltf_path)
	err = gltf_document.write_to_filesystem(state, temp_gltf_path)
	if err != OK:
		push_error("Failed to write temporary GLTF file for USD export.")
		return
	
	# Step 3: Use Blender to convert GLTF to USD
	temp_gltf_global = temp_gltf_global.replace("\\", "/")
	
	var export_path_global = ProjectSettings.globalize_path(export_path)
	# Fix Windows network share paths
	if OS.get_name() == "Windows" and export_path_global.begins_with("//"):
		export_path_global = export_path_global.replace("//", "/")
	export_path_global = export_path_global.replace("\\", "/")
	
	# Ensure output directory exists
	var export_dir = export_path.get_base_dir()
	if not export_dir.is_empty():
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(export_dir))
	
	# Use Blender to convert GLTF to USD (matching C++ implementation structure)
	# Note: EditorImportBlendRunner is not accessible from GDScript, so we use OS.execute directly
	var script_parts = []
	script_parts.append("import bpy, os, sys")
	script_parts.append("opts = {'gltf_import_options': {'filepath': '%s'}, 'usd_export_options': {'filepath': '%s', 'selected_objects_only': False, 'visible_objects_only': False, 'export_animation': True, 'export_hair': False, 'export_uvmaps': True, 'export_normals': True, 'export_materials': True, 'use_instancing': True}}" % [temp_gltf_global.replace("'", "\\'"), export_path_global.replace("'", "\\'")])
	script_parts.append("if bpy.app.version < (3, 0, 0):")
	script_parts.append("  print('Blender 3.0 or higher is required for USD support.', file=sys.stderr)")
	script_parts.append("  sys.exit(1)")
	script_parts.append("try:")
	script_parts.append("  bpy.ops.object.select_all(action='SELECT')")
	script_parts.append("  bpy.ops.object.delete(use_global=False)")
	script_parts.append("  for mesh in list(bpy.data.meshes):")
	script_parts.append("    bpy.data.meshes.remove(mesh)")
	script_parts.append("  for material in list(bpy.data.materials):")
	script_parts.append("    bpy.data.materials.remove(material)")
	script_parts.append("  result = bpy.ops.import_scene.gltf(**opts['gltf_import_options'])")
	script_parts.append("  if 'FINISHED' not in result:")
	script_parts.append("    print('GLTF import failed with result: ' + str(result), file=sys.stderr)")
	script_parts.append("    sys.exit(1)")
	script_parts.append("  result = bpy.ops.wm.usd_export(**opts['usd_export_options'])")
	script_parts.append("  if 'FINISHED' not in result:")
	script_parts.append("    print('USD export failed with result: ' + str(result), file=sys.stderr)")
	script_parts.append("    sys.exit(1)")
	script_parts.append("except Exception as e:")
	script_parts.append("  print('Error during USD export: ' + str(e), file=sys.stderr)")
	script_parts.append("  import traceback")
	script_parts.append("  traceback.print_exc(file=sys.stderr)")
	script_parts.append("  sys.exit(1)")
	
	var script = "\n".join(script_parts)
	
	var stdout = []
	var args = ["--background", "--python-expr", script]
	var ret = OS.execute(blender_path, args, stdout, true)
	
	for line in stdout:
		print(line)
	
	if ret != OK:
		push_error("Failed to convert GLTF to USD. Check Blender version (3.0+ required).")
		# Clean up temp file
		if FileAccess.file_exists(temp_gltf_path):
			DirAccess.remove_absolute(temp_gltf_path)
			var temp_bin_path = temp_gltf_path.get_basename() + ".bin"
			if FileAccess.file_exists(temp_bin_path):
				DirAccess.remove_absolute(temp_bin_path)
		return
	
	# Clean up temp file
	if FileAccess.file_exists(temp_gltf_path):
		DirAccess.remove_absolute(temp_gltf_path)
		var temp_bin_path = temp_gltf_path.get_basename() + ".bin"
		if FileAccess.file_exists(temp_bin_path):
			DirAccess.remove_absolute(temp_bin_path)
	
	# Verify file was created
	if not FileAccess.file_exists(export_path):
		push_error("USD export completed but file was not found at: %s" % export_path)
		return
	
	# Refresh file system
	EditorInterface.get_resource_filesystem().scan()
	print("USD export completed successfully: ", export_path)

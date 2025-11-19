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
	return ["usd", "usda", "usdc", "usdz"]


func _get_import_flags():
	return EditorSceneFormatImporter.IMPORT_SCENE


func _get_import_options(path: String):
	# USD import options (matching C++ implementation)
	add_import_option("usd/import_subdiv", true)
	add_import_option("usd/import_usd_preview", true)
	add_import_option("usd/import_set_frame_range", true)
	add_import_option("usd/import_materials", true)
	
	# glTF export options (control what gets exported from USD -> glTF conversion)
	add_import_option("usd/materials/export_materials", 1)  # 0=Placeholder, 1=Export, 2=Named Placeholder
	add_import_option("usd/nodes/cameras", true)
	add_import_option("usd/nodes/punctual_lights", true)
	add_import_option("usd/meshes/skins", 1)  # 0=None, 1=Compatible, 2=All
	add_import_option("usd/meshes/uvs", true)
	add_import_option("usd/meshes/normals", true)
	add_import_option("usd/meshes/colors", true)
	
	# Animation options (shared with glTF)
	add_import_option("animation/import", true)
	add_import_option("animation/fps", 30)
	add_import_option("animation/trimming", true)
	add_import_option("animation/remove_immutable_tracks", true)


func _import_scene(path: String, flags: int, options: Dictionary):
	# Get Blender path from editor settings (matching C++ implementation)
	var blender_path = EditorInterface.get_editor_settings().get_setting("filesystem/import/blender/blender_path")
	
	if blender_path.is_empty():
		push_error("Blender path is empty, check your Editor Settings.")
		return null
	
	if not FileAccess.file_exists(blender_path):
		push_error("Invalid Blender path: %s, check your Editor Settings." % blender_path)
		return null

	# Get global paths for source and sink (matching C++ implementation)
	var source_global = ProjectSettings.globalize_path(path)
	# Fix Windows network share paths
	if OS.get_name() == "Windows" and source_global.begins_with("//"):
		source_global = source_global.replace("//", "/")
	
	var usd_basename = path.get_file().get_basename()
	# Use standard imported files path (res://.godot/imported/)
	var sink = "res://.godot/imported/%s-%s.gltf" % [usd_basename, path.md5_text()]
	var sink_global = ProjectSettings.globalize_path(sink)
	
	# Build USD import options
	var usd_import_options = {}
	usd_import_options["filepath"] = source_global
	if options.has("usd/import_subdiv"):
		usd_import_options["import_subdiv"] = bool(options["usd/import_subdiv"])
	if options.has("usd/import_usd_preview"):
		usd_import_options["import_usd_preview"] = bool(options["usd/import_usd_preview"])
	if options.has("usd/import_set_frame_range"):
		usd_import_options["set_frame_range"] = bool(options["usd/import_set_frame_range"])
	if options.has("usd/import_materials"):
		usd_import_options["import_materials"] = bool(options["usd/import_materials"])
	
	# Build glTF export options (matching C++ implementation)
	var gltf_export_options = {}
	gltf_export_options["filepath"] = sink_global
	gltf_export_options["export_format"] = "GLTF_SEPARATE"
	gltf_export_options["export_yup"] = true
	gltf_export_options["export_import_convert_lighting_mode"] = "COMPAT"
	
	# Material export mode
	if options.has("usd/materials/export_materials"):
		var export_mode = int(options["usd/materials/export_materials"])
		match export_mode:
			0:  # Placeholder
				gltf_export_options["export_materials"] = "PLACEHOLDER"
			1:  # Export
				gltf_export_options["export_materials"] = "EXPORT"
			2:  # Named Placeholder
				gltf_export_options["export_materials"] = "EXPORT"
				gltf_export_options["export_image_format"] = "NONE"
	else:
		gltf_export_options["export_materials"] = "PLACEHOLDER"
	
	# Node export options
	gltf_export_options["export_cameras"] = options.get("usd/nodes/cameras", true)
	gltf_export_options["export_lights"] = options.get("usd/nodes/punctual_lights", true)
	
	# Mesh export options
	if options.has("usd/meshes/skins"):
		var skins = int(options["usd/meshes/skins"])
		if skins == 0:  # None
			gltf_export_options["export_skins"] = false
		elif skins == 1:  # Compatible
			gltf_export_options["export_skins"] = true
			gltf_export_options["export_all_influences"] = false
		elif skins == 2:  # All
			gltf_export_options["export_skins"] = true
			gltf_export_options["export_all_influences"] = true
	else:
		gltf_export_options["export_skins"] = false
	
	gltf_export_options["export_texcoords"] = options.get("usd/meshes/uvs", true)
	gltf_export_options["export_normals"] = options.get("usd/meshes/normals", true)
	
	# Blender 4.2+ uses export_vertex_color instead of export_colors
	# For Blender 4.5.4, we must use export_vertex_color
	# Try to detect Blender version by checking the output
	var use_vertex_color = true  # Default to newer API for Blender 4.2+
	if options.get("usd/meshes/colors", true):
		gltf_export_options["export_vertex_color"] = "MATERIAL"
	else:
		gltf_export_options["export_vertex_color"] = "NONE"
	
	# Escape paths for Python (before building script)
	var source_escaped = source_global.replace("\\", "\\\\").replace("'", "\\'")
	var sink_escaped = sink_global.replace("\\", "\\\\").replace("'", "\\'")
	
	# Update options with escaped paths
	usd_import_options["filepath"] = source_escaped
	gltf_export_options["filepath"] = sink_escaped
	
	# Build Python script to execute in Blender
	var script_parts = []
	script_parts.append("import bpy, os, sys")
	script_parts.append("bpy.context.scene.render.fps = %d" % int(options.get("animation/fps", 30)))
	
	# USD import
	var usd_import_args = []
	for key in usd_import_options:
		var value = usd_import_options[key]
		if value is bool:
			usd_import_args.append("%s=%s" % [key, "True" if value else "False"])
		elif value is String:
			usd_import_args.append("%s='%s'" % [key, str(value).replace("'", "\\'")])
		else:
			usd_import_args.append("%s=%s" % [key, str(value)])
	
	script_parts.append("bpy.ops.wm.usd_import(%s)" % ", ".join(usd_import_args))
	
	# glTF export
	var gltf_export_args = []
	for key in gltf_export_options:
		var value = gltf_export_options[key]
		if value is bool:
			gltf_export_args.append("%s=%s" % [key, "True" if value else "False"])
		elif value is String:
			gltf_export_args.append("%s='%s'" % [key, str(value).replace("'", "\\'")])
		else:
			gltf_export_args.append("%s=%s" % [key, str(value)])
	
	script_parts.append("bpy.ops.export_scene.gltf(%s)" % ", ".join(gltf_export_args))
	
	var script = "; ".join(script_parts)
	
	# Execute Blender
	var stdout = []
	var args = ["--background", "--python-expr", script]
	var ret = OS.execute(blender_path, args, stdout, true)
	
	for line in stdout:
		print(line)
	
	if ret != 0:
		push_error("Blender returned error code: %d" % ret)
		return null
	
	# Load the generated glTF file (matching C++ implementation)
	var gltf = GLTFDocument.new()
	var gstate = GLTFState.new()
	gstate.scene_name = usd_basename
	# extract_path and extract_prefix are set automatically by append_from_file
	# based on the base_path parameter
	# base_path should be the directory containing the .gltf file so it can find the .bin file
	var sink_base_dir = sink.get_base_dir()
	
	var err = gltf.append_from_file(sink, gstate, flags, sink_base_dir)
	if err != OK:
		push_error("Failed to load generated GLTF file: %d" % err)
		return null
	
	if options.has("animation/import"):
		gstate.create_animations = bool(options["animation/import"])
	
	var fps = float(options.get("animation/fps", 30))
	var trimming = bool(options.get("animation/trimming", true))
	var root_node = gltf.generate_scene(gstate, fps, trimming, false)
	
	if root_node:
		root_node.name = usd_basename
	
	return root_node

# godot-blender-usd-importer

## Blender (USD) Importer Addon for Godot

This addon for Godot will automatically import any `.usdc` or `.usd` file in your project directory.

Changes to the file will be automatically picked up, and your scene updated.

## How to Use:


**TL,DR**:

- Add this addon to your Godot `addons` directory, activate it, and make sure the Blender path is correct in project settings.
- Now Blender files in the project directory magically auto-import and auto-update


**Longer Version**:

You will need Godot 3.4 and Blender 3.0

Beware: Godot Engine through Steam has sandboxing issues. Try official versions on [itch.io](https://godotengine.itch.io) or [Github](https://github.com/godotengine/godot/releases/tag/3.4-stable).

1. Open this project in Godot Engine 3.4. (or add the `addons` directory to your project)
2. May not be needed: Go to <kbd>Project Settings > Plugins</kbd> and make sure the plugin `Blend` is activated.
3. May not be needed: Go to <kbd>Project Settings > General > Filesystem > Import > Blender</kbd> (or just search for `blender` at the top) and make sure the path to Blender is set. If Blender is in your global path (for example, if you use [scoop](https://scoop.sh/) to install Blender, or you are on Linux/Mac), you can just leave the default `blender`.
4. Save USD files to the project folder. Create one directory per file (materials will be extracted, and might conflict with other materials if you have more than one file).
5. Switch to Godot, and see the USD file getting auto-imported
6. From the imported file, you can now create an inherited scene (double click the file and Godot will propose to create an inherited scene for you).

If you change your USD file, remember to close your inherited scene in Godot (without saving it), or else you won't be able to see the changes.

## Known Bugs

- It seems the editor can sometimes hang on exit if scenes are left open and unsaved
- If a scene is open, and the USD file is updated in blender, changes will not be reflected until the scene is reopened (known Godot limitation)

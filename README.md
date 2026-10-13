# Path Changer

Automatically updates referenced paths when moved in godot, to scripts. Also checks for conflicts in other scenes with the same scripts.

I feel like this is a very necessary addition to godot, as it's somewhat pestering to move the node and open up the file. Now you can just move the node and click a button! This isn't the most reliable script, however. I haven't tested it extensively (or externally for that matter), and it may not work in all cases. Make sure you don't break anything with it. Just a general notice.

## Setup

1. Clone the repo.
```sh
git clone https://github.com/OrtheSnowJames/path_changer_godot
```

2. Move/copy the `path_changer` folder into your godot project's `addons` folder.
```sh
cp -r path_changer_godot/addons/path_changer $GODOT_PROJECT_DIR/addons/path_changer
```

3. Enable the plugin in your project settings.

## Testing it out/exampling

You can test it out by opening this project in godot and moving the `Control` node into Node2D and then into the root. It should prompt you with an option to update the path. Use the other scene to test out conflicts.

# StrikePoint Mobile 5v5 (Godot 4.3+ / 4.7)

Offline Counter-Strike-inspired **5v5 tactical bomb-defusal FPS** built from scratch for **Android touch controls** and low-RAM 60 FPS performance.

## Importing into Godot 4 (Android or PC)

1. Push this repository to GitHub (or download the `godot_project` folder).
2. On your phone or PC, clone/extract the folder and open **Godot 4**.
3. Tap **Import** -> select `godot_project/project.godot` -> **Import & Edit**.
4. Wait a few seconds for Godot to import the textures in `assets/textures/` and `.obj` models in `assets/models/`.
5. Press **Play (▶)** to launch `scenes/main.tscn`.

## Features Included
- **5v5 Offline Competitive Match:** Play as **Counter-Terrorist (CT)** or **Terrorist (T)** with 9 tactical AI operators (`NavigationAgent3D`) that patrol lanes, peek angles, crouch in gunfights, plant C4 at **Site A** or **Site B**, and rotate to defuse.
- **Expanded Map (`Sandstone Yard` — 78m × 66m):** 3-lane layout with **Site A Heaven** & **Site B Balcony** elevated platforms, walkable ramps, central monument plinth, pergola arches, sandbag bunkers, and 512px PBR albedo + normal-map textures.
- **Articulated Operator Rigs & Expressive Faces:** Multi-joint character rigs with sculpted faces, glowing tactical visors, respirator masks, NVG helmets, chest plate carriers, and animated limb/death poses.
- **Multi-Material Viewmodels & First-Person Arms:** Camo-sleeved arms and tactical gloves holding detailed AK-47, M4A1 (red-dot + suppressor), MP5-SD, USP-Tactical (tritium sights), Glock-18C, Combat Knife, and throwable **HE Frag Grenade**, with live muzzle-flash lighting.
- **Mobile Touch Controls & Scoreboard:** Multi-touch virtual joystick, drag-while-firing recoil control, direct `[RIFLE] [PISTOL] [KNIFE] [FRAG]` slot bar, live 5v5 K/D scoreboard, damage vignette, multikill callouts, and procedural `AudioStreamWAV` SFX.

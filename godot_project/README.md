# StrikePoint Mobile 5v5 (Godot 4.3+ / 4.7)

Offline Counter-Strike-inspired **5v5 tactical bomb-defusal FPS** built from scratch for **Android touch controls** and low-RAM 60 FPS performance.

## Importing into Godot 4 (Android or PC)

1. Push this repository to GitHub (or download the `godot_project` folder).
2. On your phone or PC, clone/extract the folder and open **Godot 4**.
3. Tap **Import** -> select `godot_project/project.godot` -> **Import & Edit**.
4. Wait a few seconds for Godot to import the textures in `assets/textures/` and `.obj` models in `assets/models/`.
5. Press **Play (▶)** to launch `scenes/main.tscn`.

## Features Included in Phase 1
- **5v5 Offline Competitive Match:** Play as **Counter-Terrorist (CT)** or **Terrorist (T)** with 9 tactical AI bots (`NavigationAgent3D`) that patrol lanes, peek angles, plant C4 at **Site A** or **Site B**, and rotate to defuse.
- **Competitive Small Map (`Sandstone Yard`):** Compact 3-lane layout (Long A, Mid Courtyard, B Tunnels, CT Spawn, T Spawn, Site A, Site B) built for fast rounds and clean sightlines.
- **Mobile Touch Controls:** Multi-touch virtual joystick (left thumb), smooth drag-to-aim + **drag-while-firing** recoil control (right thumb), ADS zoom, crouch, jump, reload, weapon switch, contextual Plant/Defuse button, radar minimap, and adjustable touch sensitivity.
- **CS-Style Gunplay & Economy:** Standing/crouch accuracy, movement spread, spray recoil patterns, headshots (`3.5x` multiplier), buy menu (`$800` start), and procedural low-RAM SFX (`AudioStreamWAV`).

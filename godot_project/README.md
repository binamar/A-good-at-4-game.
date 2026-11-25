# StrikePoint Mobile 5v5 (Godot 4.3+ / 4.7)

Offline Counter-Strike-inspired **5v5 tactical bomb-defusal FPS** built from scratch for **Android touch controls** and low-RAM 60 FPS performance.

## Importing into Godot 4 (Android or PC)

1. Push this repository to GitHub (or download the `godot_project` folder).
2. On your phone or PC, clone/extract the folder and open **Godot 4**.
3. Tap **Import** -> select `godot_project/project.godot` -> **Import & Edit**.
4. Wait a few seconds for Godot to import the textures in `assets/textures/` and `.obj` models in `assets/models/`.
5. Press **Play (▶)** to launch `scenes/main.tscn`.

## Features Included
- **Thermal & 60 FPS Optimization:** Internal 3D render scale locked near 720p (`0.67`) with a `60 FPS` cap, single-sample UV-tiled map geometry (no heavy triplanar shader overhead), and sculpted low-draw-call `.obj` meshes.
- **4 Distinct Sculpted Operator Classes (5v5):** Assault, Heavy Breacher, Recon Ghost, and Tech Specialist — built from smooth beveled `.obj` helmets, sculpted heads/masks, curved visors, organic limbs, and distinct CT/T color schemes.
- **Dynamic Shadows & Zone Lighting:** Deep ambient contrast with PSSM directional shadows plus electric blue, deep purple, and golden-yellow zone light pools across *Sandstone Yard* (78m × 66m).
- **Sculpted First-Person Weapons & Arms:** Beveled `.obj` AK-47 (curved mag + walnut furniture), M4A1 (quad-rail + suppressor), MP5-SD, USP-Tactical, Glock-18C, Combat Knife, and throwable **HE Frag Grenade** held by tapered tactical sleeves and gloves.
- **Mobile Touch Controls & Scoreboard:** Multi-touch virtual joystick, drag-while-firing recoil control, direct `[RIFLE] [PISTOL] [KNIFE] [FRAG]` slot bar, live 5v5 K/D scoreboard, multikill callouts, and procedural `AudioStreamWAV` SFX.

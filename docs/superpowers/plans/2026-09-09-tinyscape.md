# TinyScape Implementation Plan

> Execute the independent Blender asset task with a worker and the tightly coupled game tasks in this session; review the integration before delivery.

**Goal:** Deliver a playable Godot village with a Blender-authored animated character and reliable tile movement.

**Architecture:** A deterministic world definition feeds both 3D scene construction and AStarGrid2D navigation. A reusable movement model owns tile transitions; the player scene drives animation from its state. UI and camera remain independent of movement.

**Tech Stack:** Godot 4.7.2, GDScript, Blender 5.2, glTF 2.0.

**Spec:** ../specs/2026-09-09-tinyscape-design.md

## Constraints
- The engine is Godot; keep assets reusable.
- This is a local prototype, with no networking claims.
- Preserve any concurrently created files; assign unique ownership.
- No existing repository history or work exists in this directory.

## Tasks
- [ ] Character: tools/create_character.py, assets/source/adventurer.blend, assets/models/adventurer.glb. Create rig and named Idle/Walk clips, export, verify skin and channels, render preview. Worker owns these files.
- [ ] Navigation: scripts/navigation.gd and scripts/movement.gd, tests/test_navigation.gd. First test invalid destinations, disconnected cells, no corner cutting, obstacle detours, mid-edge rerouting, exact arrival, delta independence. Then implement and run headless.
- [ ] Game: project.godot, scenes/main.tscn, scripts/main.gd, scripts/world.gd, scripts/player.gd, scripts/camera.gd, scripts/hud.gd. Create terrain and original low-poly props, integrate GLB, add picking/path preview and responsive HUD.
- [ ] Verify: tests/test_game.gd and tests/capture.gd. Import headless, verify state and input, render screenshots with the actual renderer, inspect and fix art issues.
- [ ] Deliver: export_presets.cfg, builds/windows/TinyScape.exe, README.md, launch script. Export, launch smoke test, run final tests, document controls and scope.

## Verification commands
```powershell
godot --headless --path . --editor --import
godot --headless --path . --script tests/test_navigation.gd
godot --headless --path . --script tests/test_game.gd
godot --path . --script tests/capture.gd
godot --headless --path . --export-release 'Windows Desktop' builds/windows/TinyScape.exe
```

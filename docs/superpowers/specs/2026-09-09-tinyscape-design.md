# TinyScape prototype

## Intent
Build a playable Godot 4.7.2 movement prototype for a RuneScape-inspired MMORPG. The user selected Godot. The first slice is local and single player: no network, combat, account system, or persistent progression.

## Experience
The player starts in Willowmere, a compact woodland village with a timber cottage, market stall, well, pond and footbridge. Click terrain to walk tile to tile, route around solid obstacles, and click again while moving to change destination at the next tile boundary. Eight-direction movement must not cut obstacle corners. Idle and Walk are actual Blender-authored skeletal clips with a short transition. Scroll zooms, right drag and Q/E orbit, G toggles grid, Home resets camera, Escape opens a working pause panel. A minimap, a discreet route preview, and clear movement status provide feedback.

## Art direction
A 3D diorama fills the screen. Moss #71844b, deep pine #283e34, pond blue #579b9f, warm stone #c2b698, walnut #573f2e and brass #d4b16d. Faceted geometry, soft directional shadows, calm water, and individually placed vegetation. UI uses dark timber-green panels with fine brass edges; large serif village title and quiet sans-serif controls. The village is the focal point, not dashboard chrome.

## Assets and architecture
Blender source lives in assets/source (ignored by Godot). assets/models/adventurer.glb contains a rigged original adventurer with Idle and Walk clips, Y up, feet at origin, forward +Z in Godot, approximately 1.85 units tall. The deterministic map defines both art placement and blocking. Navigation is separate from rendering. Player motion completes each edge before a new path, tracks current tile and intended destination, and is independent of frame rate. Scene composition, camera, UI, and player are separate scripts.

## Acceptance
- Launchable Godot project and Windows build.
- Blender source and reproducible generation script.
- Visible idle breathing and a coordinated walk cycle, smooth transitions, correct facing.
- Click pathfinding, blocking, corner protection, mid-edge rerouting, and exact tile arrival verified by headless tests.
- Rendered game screenshots and actual input smoke tests, including camera and UI.
- README with controls, launch/export/regeneration commands and prototype boundaries.

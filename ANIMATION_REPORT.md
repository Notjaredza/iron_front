# Animation round 1: rifleman (Question Chat, 2026-11-09)

ETA given: 7 to 9 h. It took about 20 minutes of build plus tuning.

## Videos (results/units/anim/)

| Video | Shows |
|---|---|
| rifleman_walk_run.mp4 | walk (1.35 m/s), blend into run (3.7 m/s), back to walk, moving over marked ground |
| rifleman_fire_reload.mp4 | standing, kneeling and prone together: fire with the bolt worked twice, stripper-clip reload, fire |
| rifleman_pose_changes.mp4 | ready, stand to kneel, kneel to stand, stand to prone, prone to stand (two angles) |
| rifleman_hit_death.mp4 | flinch, death thrown back, death crumpling forward; then all three at half speed |

Contact sheets for every clip: results/units/anim/sheet_<clip>.png.

## How it is built (shared, so other units reuse it)

- `scripts/units/anim/rig.gd`: the pose solver. Body bones by angles; feet and hands by two-bone IK; the item placed per pose. Blends two poses with IK after the blend, so hands stay on grips through every move.
- `scripts/units/anim/anim.gd`: clips (timed poses with easing), sampling, and `bake()` into a Godot Animation that plays on any skeleton with our bone names.
- `scripts/units/anim/clips_body.gd`: **shared by every unit**. Body poses, walk/run gait (feet planted by IK; a style table per unit type: speed, stride, lean, bob), getting down and up, hit, two deaths. Takes "carries" from an item file.
- `scripts/units/anim/clips_rifle.gd`: **the rifle's own part**. How the rifle is held (order, low ready, port, aim, one hand, falling), fire with bolt, reload, and the rifleman's clip list.
- A new unit type is a new item file (its grips and its own moves) plus a gait style. Everything in clips_body comes free.

## Checks

- `-- check` (headless): all 15 clips baked into an AnimationLibrary and played through an AnimationPlayer on a fresh soldier. Bones land exactly where the solver puts them (gap 0.0000 m).
- Tool: `tools/anim_clips.gd -- sheets | video | check`.

## Known small things

- Thin light wedges show at bent knees (gaps between the thigh and shin pieces).
- Hit and death labels in the video sit close together.

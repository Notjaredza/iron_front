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

# Gunner squad (started 2026-11-09 on the user's go)

ETA: models and first pictures about 1 to 1.5 h; moves about 2 to 3 h after the OK.

## Step 1: models (done 2026-11-09, waits for the user's look)

Pictures in results/units/mg/: mg_gun.png (4 views, one with the shield), mg_parts.png, mg_crew.png (front and back, labelled), mg_team.png and mg_team_front.png (set up in action, loose placement), mg_carry.png (on the march with loads).

- `scripts/units/mg_builder.gd`: generic water-cooled heavy MG (572 tris close, 192 mid), tripod open (232) and folded (104), ammo box closed/open (112), optional shield (64). Grip, feed, muzzle and carry points for IK.
- Crew roles in `SoldierBuilder.look_for_role`: gunner (no rifle, no pack, holster, gloves), loader (no rifle, pack, holster, gloves), carriers (rifle slung, pack, boxes), NCO (no rifle, holster, binoculars, map case, sergeant's stripes). Crew 894 to 1214 tris.
- New: rifle slung on the back (rig "back" mode), `Soldier.pose_spec_world` (hands to world points), `Soldier.attach` (props on bones).
- The team poses in the pictures are rough stand-ins; the real moves come in step 2.

## Step 2: moves (started 21:44 2026-11-09 on "Looks good, do moves"; ETA about 2 to 3 h)

Videos ready 21:54 2026-11-09, in results/units/anim/:

- **mg_march.mp4**: the six walking with their loads, then the heavier loaded run. Gun on the gunner's
  shoulder, tripod on the loader's, carriers with two boxes each, the NCO free. Steps are out of step on purpose.
- **mg_setup.mp4**: tripod down and unfolded, gun lifted onto it, box set down and belt fed in, the gunner
  cocks and fires, then the whole thing is packed up and carried off.
- **mg_fire.mp4**: gunner sweeping (the body turns with the gun), loader feeding the belt, steam off the
  water jacket, belt runs out, belt change and cock, firing again.
- **mg_swap.mp4**: a carrier runs a box up crouched and goes back, the gunner is hit and falls, the nearest
  carrier crawls to the gun, takes the grips and keeps firing.

New code: scripts/units/anim/clips_mg.gd (carries, loaded and crouched runs, crew poses, gunner death),
tools/mg_clips.gd (the four scenes), plus a tripod that unfolds and a live belt in mg_builder.gd.
All of it uses the same shared rig as the rifleman, so it bakes to Godot animations the same way.

Still rough: crew places are fixed slots for the videos. The free-roaming crew (like a CoH squad, not
a formation behind the gun) comes with the squad behaviour step.

# Officer and signallers (started 22:00 2026-11-09 on "Go"; ETA about 3.5 to 4.5 h)

Models and moves in one go, one look at the end. Officer: peaked cap, greatcoat, Sam Browne, pistol;
whistle and wave on, map and binoculars, pistol fire and reload, point and hand signals. Signallers (a pair):
wire drum, field phone, lamp and flags; lay wire, phone set up / crank / talk, repair a cut wire, lamp and flags.

Done 22:25 2026-11-09. Pictures in results/units/cmd/, videos in results/units/anim/:

- **cmd_kit.mp4**: the officer, lineman and signaller turning, the kit laid out (phone, handset, lamp, flags, map,
  binoculars, whistle).
- **cmd_orders.mp4**: whistle to the lips, wave on (four riflemen get up and go), pointing out the objective
  while calling, hand signals halt / down / follow me, then he walks off with his own upright walk.
- **cmd_field.mp4**: map out of the case, read, a look up at the ground, put away; binoculars out, glassing
  left and right, put away; pistol drawn, three shots with flash and kick, magazine dropped and a new one in,
  holstered.
- **cmd_lay.mp4**: the lineman walks with the drum turning on his back and the wire left on the ground behind
  him; the signaller sets the phone down, opens the lid, the lineman clips the line on, handset up, cranking,
  talking.
- **cmd_repair.mp4**: a line cut by a shell; the lineman walks the wire, picks up both ends, splices them,
  lays them down; the signaller on the line rings through and talks.
- **cmd_lamp.mp4**: Morse on the signal lamp (it lights the ground), then a run of semaphore positions.

New code: kit_builder.gd (phone, crank, handset, drum, wire, lamp, flag, map, binoculars, whistle, magazine);
officer, lineman and signaller looks in soldier_builder.gd (cap, greatcoat, breeches and tall boots, Sam
Browne, pistol, armband, drum frame); clips_officer.gd and clips_signal.gd (the moves); tools/cmd_clips.gd.
The rig got a "bone" item mode (the holstered pistol) and an opt-in way to place a hand-held item after
the arm IK. The rifleman's and the gun team's clips are unchanged.

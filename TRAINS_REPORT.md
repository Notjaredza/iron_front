# Iron Front: train assets and animations, round 1 (report)

Asset Builder Chat, 2026-11-09, 22:16. Plan and answers: TRAINS_PLAN.md.

**State: APPROVED by the user 22:21 2026-11-09 ("Looks good").** It took about 50 minutes, not the 8-9 h estimate.

## What to look at (results/trains/)

| File | Shows |
|---|---|
| engine_side.png, engine_three_quarter.png, engine_front.png, engine_rods.png | the engine close up |
| tender.png, van.png, van_doors.png, gunflat.png | the other cars |
| train_5.png, train_night.png, train_far.png | a 5-car train near, at night, and far off (far looks) |
| run.mp4 | standing with the whistle, pulling away to 15 m/s, braking to a stop |
| couplers.mp4 | close up between cars: the slack runs out on starting; on a hard stop the wagons run in and the buffers squash |
| doors_gun.mp4 | van doors open and shut; the gun turns, lifts and fires twice |
| tip_3/4/5.mp4 | too fast on a curve: each car rolls onto its side in turn, sliding in dust |
| track_3/4/5.mp4 | torn-up track: the engine drops into the hole and ploughs in, the tender rides up, the cars pile in |
| block_3/4/5.mp4 | tank-trap block: dead stop, the front crumples, the cars fold left and right and ride up |
| blast_3/4/5.mp4 | boiler hit: the engine is thrown apart (boiler, cab, chimney, wheels and rods fly), the tender is thrown off, and a burning wreck is left |
| sheet_*.jpg | 12-frame contact sheets of every video |

## The models (made in code, in the rifleman's style)

| Car | Near look | Far look (beyond 320 m) |
|---|---|---|
| Engine: WW1 0-6-0 with outside cylinders | 4,004 triangles | 88 |
| Tender: three axles, water tank and coal | 2,028 | 48 |
| Stand-in van with sliding doors | 2,008 | 48 |
| Stand-in gun flat: armour sides, sandbags, gun mount | 2,004 | 64 |

The engine is built from separate parts (frame, front beam, cylinders, smokebox, chimney, boiler, dome, cab), so a blast can throw them.

## The moving parts

- **Wheels and rods:** the wheels turn with the distance run. The coupling rods, connecting rods, crossheads and piston rods follow the crank pins, with the left side a quarter turn behind the right.
- **Smoke and steam:**
  - four chimney puffs per wheel turn, bigger when pulling hard, and a wisp when standing;
  - the cylinder cocks blow steam while starting;
  - a whistle plume.
- **Couplers:** each car runs its own distance. The couplings have 0.16 m of slack, and the buffers squash up to 0.12 m.
  - Like WW1 goods trains, only the engine and tender brake, so the wagons run in against them when stopping.
  - A chain link hangs between the cars, and it parts in a crash.
- **Doors:** the van's two doors slide on their rails (`set_doors(0..1)`).
- **Gun:** the mount turns, the cradle lifts, and the barrel recoils and runs back out (`aim()`, `recoil()`).

## The crashes (baked once, cheap to play)

- **How they were made:**
  - The physics engine works each crash out once (tools/train_bake.gd).
  - The result is recorded at 30 keys a second into Animations in **assets/trains/crashes.res**: 12 clips, crash_<kind>_<n>, 660 KB in all.
  - Each clip starts with the train running for 1 s, then the crash; they last 4-10 s.
- **During a crash, the Train script** keeps the wheels turning while a car is still upright, puts up dust where cars slide off the line, parts the couplings, and keeps the smoke and fire going.
- **Reuse:** the crashes work on a chain of any cars. A new wagon gets them for free when its clips are baked again.
- **The check:** every clip played back through an AnimationPlayer puts the cars exactly where the bake did (gap 0.0000 m). That's 12 of 12 ok.

How each crash ends:

| Crash | 3 cars | 4 cars | 5 cars |
|---|---|---|---|
| Tip | all on their sides, 33 m on | the same, the last car upside down | the same, the gun flat upside down |
| Track | engine 9° nose down in the hole | the same | the same |
| Block | engine stopped at the traps, cars folded | the same | the same |
| Blast | engine frame 15 m on, burning | frame on its back | frame on its back, 20 m on |

## How it's built (all my own paths)

- **scripts/trains/:**
  - train_geo.gd: flat-shaded parts;
  - train_parts.gd: the four cars, the track, the crater and the blockade;
  - train_car.gd: the moving parts;
  - track_path.gd;
  - puffs.gd: smoke, steam, dust, flames;
  - train.gd: running, slack and effects;
  - train_crashes.gd: the four crash setups.
- **tools/:**
  - train_pictures.gd;
  - train_videos.gd (uses ffmpeg);
  - train_bake.gd (`-- check` replays and compares the clips).

## Known small things

1. **Crash camera:** a crash is keyed where it was baked, on a straight line (a curve for the tip). In the game the Train is placed so that point lines up. On a different bend, the first frame of the crash will pop a little.
2. **The blast:** the engine's far look (beyond 320 m) is not blown apart; it just disappears with the train if you are that far off.
3. **The crumple** on the block is a simple squash of the front parts, not a bent mesh.
4. **Effects:** the smoke, flames and dust are simple faceted puffs. Another chat is making shared fire and smoke shaders (shaders/fx_*), which could replace them later.
5. **The stand-in van and gun flat** are only there to test with. The real wagons come in a later round.

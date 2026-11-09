# Iron Front: air assets and animations, round 1 (report)

Asset Builder Chat, 2026-11-09, 23:45. Plan and answers: AIR_PLAN.md.

**State: APPROVED by the user 23:48 2026-11-09 ("Looks good").** It took about 1 hour, not the 10-12 h estimate.

## What to look at (results/air/)

| File | Shows |
|---|---|
| fighter_three_quarter, fighter_side, fighter_front, fighter_top | the scout: rotary engine, one nose gun; the top view shows the ailerons, elevator and rudder moved |
| spotter_three_quarter, spotter_gunner | the two-seater; the observer swung round on his ring with the gun |
| bomber_three_quarter, bomber_side, bomber_under, bomber_gunners | the twin-engine bomber: nose and rear gunners on rings, 10 bombs under the fuselage, twin fins |
| planes_flying, planes_ground, planes_far, planes_night | all three together: flying, parked, far looks, at night |
| balloon, balloon_basket, winch_lorry, balloon_far, balloon_night | the balloon on its cable, the basket with two observers, the winch lorry |
| `<type>_flying.mp4` | turns (banking into the turn), a climb, a dive and a reversal; the ailerons, elevator and rudder move with the stick |
| fighter_weapons.mp4 | a strafing dive on a row of crates: muzzle flash, tracers, dust where the rounds land; then a message bag with its streamer |
| spotter_weapons.mp4 | the observer swings his ring gun round to the rear and fires two bursts; the pilot's gun fires; a message drop |
| bomber_weapons.mp4 | both gunners swing and fire; 10 bombs drop one by one, swing nose-down as they fall and burst in a line on the target |
| `<type>_takeoff.mp4` | the propeller starts (blades, then a blur), taxi onto the strip, take-off run with the tail coming up, lift-off and climb |
| `<type>_landing.mp4` | glide in, flare, a three-point landing (tail stays down), roll out, the propeller stops |
| balloon_winch.mp4 | the drum pays out and the balloon goes up to 90 m, swaying in the wind, then is hauled part way down |
| `<type>_spin.mp4` | hit: smoking, then on fire; a spinning dive into the ground; the plane breaks up and the wreck burns |
| `<type>_wing.mp4` | the right wing breaks off and flutters down on its own; the rest rolls over, falls and breaks up |
| balloon_burn.mp4 | the envelope catches fire, folds and falls; the two observers jump and come down under parachutes |
| sheet_*.jpg | 12-frame contact sheets of every video |

## The models (made in code, in the rifleman's and trains' style)

| Model | Near look | Far look |
|---|---|---|
| Fighter / scout: 8.4 m span | 1,712 triangles | 80 (beyond 450 m) |
| Two-seat spotter: 12 m span | 2,376 | 80 |
| Twin-engine bomber: 22 m span | 5,752 | 112 |
| Balloon (28 m envelope), basket, crew, cable, winch lorry | about 3,000 | boxes beyond 600 m |

- **Colours:** olive canvas on top and pale linen underneath, as asked. The bomber is darker.
- **Markings:** generic only. Each plane carries a cream-edged dark diamond on the fuselage sides and on the upper wings, with no real nation's roundel.
- **Break-up:** each plane is built in groups (Fuselage, WingL, WingR, Tail, Gear), so a crash can throw them apart.
- **Airmen:** flying coats, helmets and goggles.

## The moving parts (scripts/air/aircraft.gd)

- **Propellers:** they turn with `rpm`. Above 350 rpm the blades fade to a blur disc. On the bomber the two propellers turn opposite ways.
- **Control surfaces:** `set_surfaces(roll, pitch, yaw)` moves the ailerons, elevator and rudder(s).
- **Gunners:** `aim_gunner(i, yaw, pitch)` turns the ring and lifts the gun.
- **Guns:**
  - `flash()` shows the muzzle flash;
  - `muzzle()` and `muzzle_dir()` give where the rounds come from.
- **Bombs:** `release_bomb(i)`.
- **Wheels:** they turn with the distance run.
- **Flying is kinematic, so it is cheap:**
  - `fly(dt, turn, climb_rate, speed)` banks into turns and pitches with the climb. It adds a nose-up angle as the plane slows, so slow planes fly nose-high.
  - `roll_ground(...)` covers taxiing and the take-off run, with the tail rising.
  - `approach(...)` covers the glide, the flare and a three-point touchdown.
- **Effects (scripts/air/air_fx.gd):**
  - tracers;
  - falling bombs that turn nose-down;
  - message bags with fluttering streamers;
  - smoke and fire trails;
  - dust where the rounds land;
  - bomb bursts, which use the shared Blast effect (size 3).
- **The balloon (scripts/air/balloon.gd):**
  - `set_height(h)` turns the lorry's drum and pays the cable out or in;
  - `wind(t)` makes the balloon sway;
  - each observer has a parachute packed away, ready to jump.

## The crashes (baked once, cheap to play)

- **Where they are:** 7 clips in **assets/air/crashes.res** (440 KB), made by tools/air_bake.gd:
  - fighter, spotter and bomber, each `_spin` and `_wing`;
  - `balloon_burn`.
- **How the planes were baked:**
  - The start is scripted: the hit, smoke, fire, then the spin or the lost wing.
  - The physics engine then works out the fall, the impact and the break-up.
  - Impacts come at about 6 s. The wreck settles 4-7 s later.
- **The balloon** is keyed throughout:
  - the envelope folds in four parts;
  - the crew jump at 1.1 s and 1.7 s;
  - the chutes open after 1.2 s, and the men drift down at about 5 m/s.
- **The check:** `air_bake.gd -- check` plays every clip back through an AnimationPlayer. Every part lands where the bake put it: **7 of 7 ok, gap 0.0000 m**.
- **Using them:** `AirCrashes.player_for(plane)` gives an AnimationPlayer with only that model's clips.
  - The clips also drive `fire_level`, `rpm` and `crash_time`, the moment of impact.
  - In the game, put the plane's root where it was flying, facing its heading, 110 m up (`START_H`), and play.

## How it's built (my paths only)

- scripts/air/: air_parts.gd, aircraft.gd, air_fx.gd, balloon.gd, air_crashes.gd
- tools/: air_pictures.gd, air_videos.gd, air_crash_clips.gd, air_bake.gd (`-- check`)
- assets/air/crashes.res

## Known small things

1. **Crash height:** the crash clips are baked from 110 m. A plane hit lower will meet the ground sooner than the clip expects. Lower and higher versions can be baked later.
2. **Crashes are on a straight heading:** a plane hit while banked snaps level at the start of the clip.
3. **The balloon's cable** stays fixed to the lorry when the balloon burns, rather than snapping. The falling envelope also ends up near the lorry.
4. **The bomb bursts** use the shared Blast effect from the explosions round (scripts/fx/blast.gd), which another chat is still working on.
5. **Stand-in field:** the field strip, windsock and crates in the videos are only a stage for filming, not game assets.

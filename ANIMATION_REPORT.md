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

Done 22:20 2026-11-09. Pictures in results/units/cmd/, videos in results/units/anim/:

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

# Troop lorry (started 22:34 2026-11-09 on "Go"; ETA about 3 to 4 h)

An open army lorry with a canvas tilt (generic), one 12-man squad on benches. This round: driving (wheels turn,
the body rides the bumps, exhaust), the squad climbing in and jumping out, close / mid / far looks, and the
burning wreck left on the map. Built as the base vehicle for later ones. The engineers round is paused.

**Done 22:52 2026-11-09** (about 20 min against the 3 to 4 h ETA). Videos in `results/units/anim/`:

| Clip | What it shows |
|---|---|
| `lorry_look.mp4` | Close, mid and far looks side by side, plus the wreck; tailgate drops at 6 s |
| `lorry_drive.mp4` | 12 men on the benches, 4.5 m/s over bumps: wheels turn, body rocks on soft springs, exhaust and dust |
| `lorry_board.mp4` | The squad climbs in over the tailgate (step, knee, stand), stoops to a seat, tailgate up, drives off on a curve |
| `lorry_dismount.mp4` | Pulls up, tailgate down, men jump out one by one, spread and kneel |
| `lorry_wreck.mp4` | Shell hit, flash, swap to the burnt hull, flames and black smoke, then smouldering |

Triangles (at 22:49, before the mid wheels were trimmed): close 6622, mid 3706 (now lower), far 360, wreck 4580.

Files: `scripts/vehicles/lorry_builder.gd` (mesh: body, tilt, wheels, tailgate, wreck palette),
`scripts/vehicles/lorry.gd` (`Lorry` node: wheel stations, steer, spring ride, tailgate, 12 seats),
`scripts/units/anim/clips_vehicle.gd` (seated, driver, climb stages, stooped, crouch, airborne),
`tools/lorry_clips.gd` (the five scenes).

Base for other vehicles: copy the `Lorry` shape (body pivot, wheel stations, moving parts, seats).
Not done yet: not tied to real move orders in the game, no reversing, the driver never gets out, no crew in the wreck scene.

# Light field gun (started 22:59 2026-11-09 on "Go"; ETA 1.5 to 2.5 h)

**Done 23:33 2026-11-09** (about 35 min). A generic WW1-era field gun of about 75 mm, our own design: two big
spoked wheels, box trail with spade, steel shield, barrel on a recoil cradle, axle seats. Crew of six: NCO,
layer, breech man, loader, two ammunition numbers. Videos in `results/units/anim/`:

| Clip | What it shows |
|---|---|
| `gun_look.mp4` | Close, mid, far and the wreck; elevating, recoil, breech open |
| `gun_fire.mp4` | Three rounds: out of the box, handed to the loader, rammed, breech closed, NCO's arm drops, fire (flash, smoke, dust, recoil, hop), everyone flinches, breech opens, case thrown out |
| `gun_aim.mp4` | NCO points the new line, the layer winds the handwheel (barrel elevates), handspike in the trail, three heaves swing the gun left |
| `gun_push.mp4` | Manhandling: trail lifted, two on the trail, one behind each wheel, one with the ammunition box, pushed 3.6 m and swung round 28 degrees, trail down |
| `gun_unhitch.mp4` | Lorry arrives towing, crew jump out, trail off the hook, lorry away, the gun swung round 180 degrees and the crew take post |
| `gun_hitch.mp4` | Lorry backs up, trail lifted onto the hook, crew climb in either side of the trail, away towing |
| `gun_portee.mp4` | Lorry with tilt and benches off, ramps down, two men haul on ropes from the bed while two push the trail, gun aboard with the trail over the tailboard, away |
| `gun_wreck.mp4` | Direct hit: flash, dirt, the gun knocked out (a wheel off, shield torn, charred), burning, smoke |

Triangles: close 3250, mid 1578, far 144, wreck about 3100.

Files: `scripts/vehicles/field_gun_builder.gd` (mesh pieces, rounds, ammunition box, ramps, handspike),
`scripts/vehicles/field_gun.gd` (`FieldGun` node: carriage lift, elevation, recoil, breech, handwheel, wheel roll),
`scripts/units/anim/clips_gun.gd` (crew poses), `tools/gun_clips.gd` (the eight scenes; a `close` check view too).
The lorry got two options for this: `tilt` and `benches` (both on by default), and a tow hook point `HOOK`.

Not done yet: no limber or ammunition trailer; in the portee scene the other two crew are not shown and the ramps
stay on the ground; the swing in `unhitch` is long (about 7 s); feet slide a little when men shift with the trail
in `aim` and `push`.

# Four troop types (started 23:42 2026-11-09 on "Go"; ETA 1.5 to 2.5 h)

**Done 00:15 2026-11-10** (about 35 min). Four new kinds of troops on the rifleman's body and moves, all our own
generic designs. Videos in `results/units/anim/`:

| Clip | What it shows |
|---|---|
| `troop_look.mp4` | All ten roles close (front, then round the back), mid and far, with triangle counts |
| `troop_moves.mp4` | Carbine, scoped rifle, LMG and the bomb carrier doing the rifleman's set: walk, kneel, fire (the LMG fires a burst), reload, prone, fire, up, hit and fall |
| `troop_assault.mp4` | Section of 8 rushes in crouched, drops; three carbines fire, two throw stick grenades (they burst), the clubs wait; the NCO waves them on and they all rush |
| `troop_snipers.mp4` | Pair crawl in under hooded capes, down behind a rise; the spotter takes the binoculars from the case, glasses and points; two shots with the bolt worked (dust kicks up), reload |
| `troop_lmg.mp4` | Gunner and carrier run in, down; bipod swung down; three bursts (shake, flash, smoke); the carrier lifts off the empty drum, takes a full one from his pouch and fits it; firing again |
| `troop_mortar.mp4` | Three men walk in with the tube on a shoulder and the plate on a back; plate set down, tube into the socket, bipod legs out; three bombs: from the bag, over the muzzle, let go, everyone ducks, the tube kicks, flash, smoke, dust |

The roles (look keys in `SoldierBuilder.look_for_role`):
- Assault: `assault_nco` (pistol, stripes), `assault` (carbine), `raider` (nail-studded trench club); grenade bags, no packs.
- Snipers: `sniper` (scoped rifle), `spotter` (rifle, binocular case); both in a mottled hooded cape (hood replaces the helmet).
- LMG: `lmg_gunner` (light machine gun with finned jacket; the drum and bipod are props so they can be swapped and swung), `lmg_carrier` (drum pouches).
- Mortar: `mortar_tube` (pistol), `mortar_plate` (rifle, straps), `mortar_bombs` (rifle, front and back bomb bags).

Triangles, close / mid / far: 894 to 1350 / 282 to 538 / 200 to 266 a man.

Files: `scripts/units/troop_kit.gd` (`TroopKit`: weapons, body kit, hood, drum, bipod legs, baseplate, tube with
opening bipod, bomb, stick grenade), `scripts/units/anim/clips_troops.gd` (club carries, grenade throw, prone
binoculars and pointing, mortar crew kneel and duck), `tools/troop_clips.gd` (the six scenes).
`soldier_builder.gd` got a `weapon` look key (rifle, carbine, scoped, lmg, club) and the new roles.

New moves: grenade throw, LMG bipod deploy, burst and drum swap, mortar set-up and bomb drop, the spotter's
binoculars and pointing lying down. The rest reuse the rifleman's set.

Not done yet / rough: the LMG uses the rifle's bolt reload in `moves` (its own reload is the drum swap); the spotter's
slung rifle sticks up when he lies down; the clubs never strike (no melee move yet); the mortar scene is crowded in
the set-up shots; the throwers' carbine moves to the back quickly when they stand to throw.

## Railway siege gun (Question Chat, started 00:21, done 00:45 2026-11-10)

Our own railway howitzer, using the Schwerer Gustav idea at a smaller size: about 20 m long, so a normal engine can push it.
- **Model** (`scripts/trains/siege_gun.gd`, class SiegeGun). A girder carriage on two 4-axle bogies with a heavy barrel (about 28 cm) in a cradle on a traversing mount. Rear loading platform with ladders, railings, a shell crane worked by a hand winch on the post, a loading tray, a breech block with a lever, and four outriggers. Close look is 6720 triangles, far look 96 (swaps at 320 m). The wreck build is darkened and has a torn barrel stub.
- **Videos** (`results/units/anim/siege_*.mp4`, made with `tools/siege_clips.gd`):
  - look: orbit with the outriggers going down, elevation to 43 degrees, the crane swing, the breech opening, the far look, then the wreck.
  - move: one engine pushes the gun round a 110 m curve with the bogies following it, then stops and the outriggers go down.
  - setup: the officer glasses the target, four men push the outriggers down, the crew climb the ladders, the layer traverses and elevates.
  - fire: shell trolley, hook, hoist, swing to the tray, rammed by three men, charge from the rear box, breech shut, lanyard man jumps down, elevation, crew duck, officer's arm drop, FIRE (flash, fire and smoke along the bore, a ring of ground dust, a pressure ring, camera shake, recoil and the carriage rocking), then a second round from 150 m.
  - wreck: a direct hit, the front of the barrel thrown off and tumbling, debris, crew knocked down, a burning, smoking hulk.
- **Not done:** the third round (two are shown). The flash is a plain glow ball. The tracks are drawn on bare sand.

## Zombies (Question Chat, started 07:02, done 07:32 2026-11-10)

Dead soldiers back on their feet, in our basic army style. They use the soldier skeleton, so every pose, clip, IK hand and death works on them as it does on our men.
- **Models** (`scripts/units/zombie_builder.gd`, `scripts/units/zombie.gd` class Zombie). The soldier body with faded, mud-caked, stained cloth, grey-green skin, pale eyes, an open jaw, a torn chest with the ribs showing, a ripped bare forearm and rags.
  - Shambler: helmet or bare head, some in gas masks. 1020 / 332 / 192 triangles (close / mid / far).
  - Runner: bare-headed, thin and fresher. 868 / 312 / 192.
  - Brute: broad, scaled up 1.25, with scrap-iron plates, a bucket helm, a chain and a nailed timber club. 1324 / 444 / 240.
  - Zombie can also take its legs off (the shins shrink to stumps) and char black as it burns.
  - `soldier_builder.gd` gained one look key, `bare` (no helmet), for the zombies.
- **Moves** (`scripts/units/anim/clips_zombie.gd`):
  - gaits: shamble (arms out, one-arm-dead or limp), hunched sprint, the brute's walk and charge, a crawl on the arms;
  - attacks: grab and bite, claw swipes, the runner's crouch, leap and landing, the brute's two-handed club smash;
  - climbing: wall climb, belly over the top, the hunched heap at the wall foot, clawing at a gate or wall;
  - deaths: stumble (shot, keeps coming), head-shot drop, legs shot off, burning, the brute's slow fall after several hits.
- **Videos** (`results/units/anim/zombie_*.mp4`, made with `tools/zombie_clips.gd`):
  - look: the gallery, close, mid and far.
  - moves: every gait, a stagger, a turn, the charge, the crawl.
  - attacks: a bite, a leap, the club.
  - walls: shamblers heap at the wall foot and runners climb their backs, over the top and down inside. At the gate two claw at it, then the brute smashes it in and splinters fly.
  - trench: a shambler snags on the wire, falls in, gets up and claws out the far side. Another is stuck at the trench wall. A runner jumps the wire and the trench. The brute tears through the wire, steps down and climbs out.
  - horde: 16 shamblers, 2 runners and the brute against five rifles and the officer. Head shots drop them and wounds only slow them. One runner leaps in on a rifleman and the officer's pistol finishes it.
  - deaths: a head shot, legs shot away then crawling, fire, and the brute.
- **Rough edges:**
  - The jump down from the wall top is a quick tumble.
  - Fixed after the user's look: the fallen brute now lets go of its club and lies flat (it was propped up on it).
  - Hits are small dark sprays (no gore).

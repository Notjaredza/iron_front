# Iron Front: design (working title)

Written by the Question Chat on 2026-11-09, from about 30 rounds of the user's answers. **Nothing is built yet: building starts only on the user's go.**

## In one line
A single-player RTS in a WW1 world with strange tech. You hold out against endless ancient waves on a huge stepped map. Your orders only reach the front as fast as the communication network you build can carry them.

## The project
- **Engine:** Godot 4.7.2. **Folder:** `GAME IDEA!/iron_front`, with its own git repo. **Target:** 60 FPS on the laptop, with thousands of men.
- **Fresh on everything.** Worlds War 1 is a reference, not a source to copy from:
  - Models are new, low-poly and made in code, all in one style. The Asset Builder chat makes them in rounds.
  - Systems are rewritten cleanly but keep the same design as WW1: the Story Teller, the crowd tricks, train running.
- **The crew** is the same as WW1: Control, building chats, Laptop, Prep, Story Teller, Asset Builder. "Faster, fewer looks": several pieces get built between the user's looks.
- **Single player only.** No versus.

## How a run plays
- **The start:** you pick a start spot on a map generated fresh from a seed. You see the terrain from the start, but enemies are hidden.
- **The goal:** a run is endless. The score counts time survived, waves beaten and kills. A run lasts many hours over several sittings, so you can save anytime, and there's an autosave.
- **Pace:** slow, like a war game. You can pause and give orders while paused, and speed up to 2x or 3x.
- **Difficulty:** you pick the Story Teller's style and level at the start.
- **Losing:** the officer dies.

## The map
- **Size:** 8 x 12 km, the same as WW1.
- **Stepped, low poly:** one base level, with plateaus on levels 2 and 3. The cliff steps are tall (8 m or more) with dirt banks, as in `rts_project_mk1/look_references/04_block_cliffs_village`. No Terrain3D.
- **Ramps:** mixed. Mostly wide ramps so armies flow, plus a few narrow passes worth fighting over.
- **Water:** square-banked lakes and rivers. Rivers make bridges matter.
- **No roads.** Units take the most natural path, and dirt tracks wear in over time where armies walk. Tracks show on the ground and are a little faster.
- **On the map:** old rail lines (some working, some broken), stations, and villages or ruins that you can capture. High points are natural vantage points, not capture points.
- **High ground:** units on a higher level see and shoot further.
- **Look:** bright, flat low-poly colours by day, as in the reference pictures. At night and in fog, WW1's cool, moody look.
- **Day, night and fog** all matter to sight and to the comms network.
- **Fog of war:** anything out of sight or range of a troop, building and so on is hidden.
- **No civilians.**

## The officer (you)
- **A pure leader on foot.** He doesn't build. If he's hit, he's wounded first and carried back to HQ to recover. If he dies, the run ends.
- **Squads near him get:**
  - instant orders, with no network delay;
  - steadier fire;
  - a rally if they're pinned;
  - a local field doctrine that can differ from HQ's.
- **Moves** on foot, on horseback or by train.
- **Guard:** none built in. You assign squads to guard him.
- **On screen:** an always-on portrait showing his health and any danger.

## Squads and units
- **12-man squads,** with no regiments. Thousands of men overall, handled with control groups.
- **Close zoom** shows individual animated men; far out shows icons.
- **Combat:** cover and ammo matter. Squads can garrison ruins, houses and bunkers, as in Company of Heroes.
- **Wounded** men leave the squad, and aid posts send some of them back as reinforcements. A nearly wiped-out squad can merge with another one or be topped up.
- **Infantry:** riflemen, MG teams, engineers, and signallers, who set up temporary relays.
- **Machines:** WW1 tanks, our own walkers (strange tech), armoured cars, trucks and armoured trains.
- **Air:**
  - spotting;
  - bombing and strafing;
  - fighting the flying host;
  - carrying messages.
- **Artillery** fires far, but only where a spotter can see. The spotting reports travel the comms network.
- **Idle squads** do what the current doctrine says.

## Doctrines (the protocols)
- **Base-wide doctrines,** set on a protocol board.
- **One active per category:** stance, fire, supply, and night/comms. More categories unlock over a run.
- **Visible on the field:** flags, whistles and calls, with a doctrine colour on each squad.
- **A new doctrine reaches each squad only through the comms network,** as described below.

## The comms network (the user's big idea)
**Orders come from HQ and travel through the network you've built.** Changing orders takes as long as the network allows, so a front can miss its orders, and a broken line cuts a base off.

**Ways to send messages:**

| Way | How it behaves |
|---|---|
| Runners | Free and always there; slow, and can be killed on the way |
| Dispatch riders, messenger dogs | Faster than runners; dogs can cross rough ground |
| Telegraph and field-phone wire | Fast; cut by shelling and fights; engineers or linesmen walk out to repair it |
| Wire along the rails | An **upgrade** you make to a rail line, not there by default |
| Signal lamps | Need line of sight; carry further at night but the enemy sees them; blind in fog |
| Heliographs | Need sun |
| Pigeons, flares | A loft for pigeons; flares for simple calls |
| Balloon relays | Tethered balloons with phone lines, spotting far and passing signals over hills |
| Radio | Late tech, costly |
| The resonance mast | Strange tech: instant over long range, but it draws the enemy |
| Planes | Message drops: fast and costly |

- **What travels:**
  - Direct orders are instant near the officer, and travel the network when he's far away.
  - Train orders and superweapon fire orders travel it too.
  - **Reports travel back the same way.** What a far squad sees reaches you only as fast as the network, so a cut-off front goes dark or shows old news.
- **When cut off:** a group keeps following the last orders it heard.
- **The enemy** damages the network only by chance in fights, not on purpose.
- **What you see:**
  - a network overlay mode showing lines, towers, the delay to each group, and breaks in red;
  - each order as a pulse travelling the network;
  - a received or waiting marker on each group.

## Rail and trains: the spine
- **Trains** carry new squads from the barracks and stock the depots. Carts and trucks carry supply further out.
- **Three ways to get rail:**
  - take over and repair the old lines;
  - draw your own track on the 8 m grid;
  - send track-laying trains.
- **Crossing the terrain:** incline pieces climb the levels, plus bridges, cuttings and tunnels, and viaducts.
- **Running:** trains run simple routes on their own, and you can send a special train any time. Train orders travel the network, and signal boxes and rail wire make rail traffic faster and safer.
- **Damage:** track gets hurt only by chance in fights. Engineers repair it.
- **Armoured trains** are assembled from gun, MG, flak and troop wagons.
- **Trucks** are slow off the dirt tracks and fine on them. They climb by ramps only, never cliffs.

## Base and buildings
- **The HQ** places every building on the 8 m grid, on any level, and engineers build them. Forward HQs come later and act as network hubs.
- **The core sets:**
  - HQ, barracks, depot;
  - comms buildings: runner post, telegraph post, lamp tower, pigeon loft and so on;
  - rail buildings: halts, stations, yards, signal boxes;
  - defences.
- **Defences** are dragged out as lines: trenches, wire, walls. MG nests and gun pits need a squad crewing them to fight.
- **Research buildings** cover comms, weapons and units, rail, and defences. Each has its own short tree.
- **Strange tech** comes from **wrecks**. Engineers strip dead walkers and haul the parts back, ideally by train. It unlocks our walkers, the resonance mast and the Sunfall. There are no ancient sites on the map.
- **Superweapons** (railway guns, the Sunfall) are rare late builds and game-changing: one shot can wipe out a wave. They take a long time to build and reload, a big blast can tear a rift, and they're fired through comms.
- **Cost for now:** a single "supply" number. The real economy is set aside, because the focus is gameplay.
- **Left out:** town growth, and base micromanagement such as worker jobs and shifts.

## The enemy
- **Ancient waves,** mostly from the north, led by the Story Teller in the same way as WW1. Some waves hunt the officer or the HQ, at the Story Teller's choice.
- **New kinds appear over a run:** hosts first, then walkers, then the flying host.
- **Rift insects** come out only after big blasts, as in WW1.

## Screen and sound
- **The camera** works the same as WW1's.
- **The UI is minimal.** Squad info (a banner with type, men and ammo, the doctrine colour, the order marker) can be toggled on and off in game, or shown only when a squad is selected.
- **Sound is all new:**
  - real, varied troop sounds from free CC0 libraries, with many takes per sound plus pitch and volume changes, so nothing repeats;
  - comms sounds: telegraph clicks, bugles, whistles.
- **No tutorial or story for now.**

## Build order: pieces, each finished before the next
1. **The stepped map:**
   - generated levels, tall cliffs, mixed ramps, lakes and rivers;
   - old rail lines and villages placed;
   - the camera flying over it.

   Rough cost: about 15-20 h.
2. **Squads:** 12-man squads moving on levels and ramps, finding paths, taking cover, fighting, with high ground, close men and far icons.
3. **HQ and the first comms:** the HQ, the officer, runners and wire, orders travelling, the overlay, the fog of war, and reports coming back.
4. **Waves:** the Story Teller rewritten cleanly, with hosts from the north.
5. Then, in an order still to be agreed:
   - **Rail and trains:** laying, the old lines, routes, signal boxes;
   - **Barracks and depots,** with supply by train;
   - **Defences and garrisons;**
   - **The rest of comms;**
   - **Doctrines and the protocol board;**
   - **Research and salvage;**
   - **Machines and air;**
   - **Superweapons and rifts;**
   - **Saving.**

## Still open
- The real economy, after gameplay.
- The order of pieces after step 4.
- Exact numbers: squad speeds, ranges, network delays, wave sizes. These get tuned as each piece is built.

# Engineer section: workers and crew (Building Chat 1, 2026-11-10)

The user asked "can we do the workers and crew now?". These were the answers given (the saved engineer answers stand):
- **The section:** 4 men. The NCO directs, checks the plan and joins heavy lifts. The 3 sappers have their rifles slung.
- **Kit:** pick + shovel, mallet + stakes, saw + hammer + planks, wire cutters + coil.
- **Jobs:** dig a trench, build, barbed wire, strip a wreck, track repair.
- **Output:** pictures only. The work grows as they work.

Go was given at 17:04, with an ETA of 1.5-2.5 h. Pictures were done by 17:24. APPROVED by the user at 17:31.

## What is built
- **The men** are on the rifleman's skeleton, so every pose, clip, IK hand, death and blast throw works.
  - Sappers: no pack, sleeves rolled, leather gloves, the rifle slung across the back (on the chest bone).
  - Belt kit: a hatchet in its frog on the right hip, a nail and cutter pouch on the left.
  - Badge: a white sapper's patch on the left arm.
  - The NCO: stripes and map case, and he carries the plan (a clipboard placed at his left palm, tipped toward his eyes).
- **Tools,** held on the item bone (right hand grip, left hand on the shaft): pick, shovel, maul, saw, hammer, long cutters, crowbar, a plank, the wire coil on its carrying stake, and a steel panel. Each has close, mid and far versions.
- **Work pieces that grow** (`EngineerWorks`, each built for how far the work has got, p 0..1):
  - **trench:** tape and pegs at the start, a pit getting deeper (in the pictures), the spoil heap rising into a parapet, duckboards at the end.
  - **plank wall:** posts, then planks nailed on from the bottom up (8 rows); the plank stack shrinks; a trestle with a plank part sawn.
  - **barbed wire:** pickets every 2.5 m, the newest one half driven; two barbed strands paid out as far as the work has got; diagonals on finished bays.
  - **wreck:** a crate-like hull whose six side panels come off one by one, showing the ribs, an engine block and a drum inside; the panel pile grows.
  - **track:** a split sleeper; the bay cleared; the new sleeper in with its spikes loose; then spiked home.

## Moves (scripts/units/anim/clips_engineer.gd, names "eng_...")
- **Walking:** walk (shovel on the shoulder), walk_plank, walk_coil, walk_panel.
- **Digging:** pick (up, over, into the ground, lever), shovel (scoop, push, lift, throw forward onto the parapet).
- **Building:** saw (strokes on the trestle), hammer (nailing at chest height), hammer_low (kneeling).
- **Wire:** drive (two-handed maul on the picket), hold (the mate kneels holding the picket and turns his face from the blows), cut (snip, then twist round the picket).
- **Wreck and track:** prise (the bar in the seam, heaved down), lift (a sleeper end from the ground to the waist; the NCO takes one end), spike (the maul driving a rail spike).
- **The NCO:** nco_check (reads the plan, looks up, points at the work, reads again).
- **Shared:** hit, death_back, death_forward, prone_to_stand (tools dropped). Holds: stand, plan, point, kneel.

## Pictures (results/units/engineers/)
- eng_look.png: the section front and back, carrying, a close-up, the kit laid out, and the close/mid/far versions.
- eng_moves.png: one row per move, up to six moments.
- eng_dig.png, eng_build.png, eng_wire.png, eng_wreck.png, eng_track.png: six moments per job, the work growing from start to done.

## Numbers (triangles, close / mid / far)
NCO 1394 / 534 / 216; sapper 1226 / 374 / 216 (the tools are separate small meshes).

## Files
- scripts/units/engineer_builder.gd (EngineerBuilder): looks, body kit, tools, the plan.
- scripts/units/engineer.gd (Engineer): the unit, tool props, the plan placement.
- scripts/units/engineer_works.gd (EngineerWorks): the growing work pieces.
- scripts/units/anim/clips_engineer.gd: poses and clips.
- tools/engineer_pictures.gd (`-- look moves dig build wire wreck track`; the ENG_ONLY=clip,clip setting renders only those move rows to eng_debug.png).

## Rough edges, for later
- The trench in the pictures is cut into a raised earth block (the map ground can't be dug yet). In the game the work pieces need tying to real terrain and build orders.
- Tool contact is close, not exact: the pick and spade tips land near, not on, the marked spot, and the saw stroke is short.
- No dust, sparks or earth thrown, and no sounds.
- The sleeper lift is posed per picture, not a walking two-man carry clip.

# The medieval host's siege equipment (Building Chat 1, 2026-11-10)

The user asked "lets give them seige equipment". The answers given:
- **Engines:** all four groups.
  - Throwing engines: counterweight trebuchet, torsion mangonel.
  - Bolt thrower: ballista (springald).
  - Assault engines: siege tower with a drop bridge, roofed battering ram.
  - Approach kit: scaling ladders, wheeled mantlets, fascines.
- **Crews:** full crew work.
- **Targets:** not chosen. Our walls, gate and trenches are used.
- **Output:** pictures only ("skip videos to save time").

Go was given at 19:02 with an ETA of 1-1.5 h. It was built by 19:30 (about 30 min). APPROVED by the user at 19:30.

## What is built
Every engine faces -Z and is built from parts. Each moving part hangs on its own pivot, so it moves on a state. The crews take their hand spots from the engine's moving handles, spokes, ropes and rails, so the hands stay on them.

- **Trebuchet:**
  - A 10 m frame with A-frames and side braces.
  - A 9 m arm on an iron axle.
  - A counterweight box of stones that hangs plumb from the short end.
  - The sling and its leather pouch. The pouch lies in the trough when cocked, trails the arm, swings out straight at the release, then whips over.
  - The windlass with two spoke wheels, the cocking rope, the trigger lanyard, and a heap of shot.
- **Mangonel:**
  - A wheeled frame with a skein of twisted rope (iron washers and levers).
  - The arm with its cup, and the padded stop beam it strikes.
  - A spoked windlass behind.
- **Ballista:**
  - A four-wheeled trestle with a turning mount and a tilting cradle.
  - Two torsion skeins with bow arms.
  - The bowstring runs to a claw on the slider. A bolt sits in the groove.
  - The crank winch, and tiller pegs for laying it.
- **Siege tower:**
  - 4 floors, about 9 m to the banner. The floors are at 0.6, 2.7, 4.8 and 6.9 m, so the bridge is just above our parapet (4.2 m).
  - Wet hides on the front and sides, the lord's arms painted on the front, and loopholes.
  - Wooden merlons on the top platform, ladders inside between the floors, and a push bar behind.
  - The bridge drops on chains.
- **Ram:**
  - A 6 m roofed penthouse on 4 wheels, with hides on the roof and the lord's arms on the front gable.
  - The log, with an iron ram's head and horns, hangs from two tie beams on four ropes. It swings level, as a real hung ram does.
  - Rope handles for the crew.
- **Approach kit:**
  - A 5 m scaling ladder with hooks.
  - Wheeled mantlets. Each is a plank screen leaning back, painted in a lord's arms, with a loophole and push handles.
  - Fascines: brushwood bundles bound with withies.
- **Triangles (close / mid / far):**

  | Item | Close | Mid | Far |
  |---|---|---|---|
  | trebuchet | 1600 | 1188 | 716 |
  | mangonel | 1824 | 932 | 836 |
  | ballista | 1728 | 1136 | 952 |
  | tower | 3162 | 2045 | 1389 |
  | ram | 2088 | 1539 | 987 |
  | mantlet | 626 | 254 | 238 |
  | fascine | 432 | 188 | 60 |
  | ladder | 288 | | |

## Crew work (the host's own men, mostly the levy)
- **Trebuchet:**
  - winding the arm down at the spoke wheels;
  - carrying a shot from the heap to the pouch while a mate holds the sling open;
  - the master yanks the lanyard while the crew duck.
- **Mangonel:**
  - winding it back against the skein;
  - lifting the stone into the cup;
  - knocking the pin out.
- **Ballista:** cranked back, the bolt set in the groove, the aimer at the tiller, loose.
- **Tower:** five men heave it on from the push bar.
- **Ram:** men push it on its posts, then swing it by the rope handles; they lean in with the swing.
- **Ladders:**
  - carried between the rails at the shoulders;
  - walked up hand over hand while one man braces the foot, then over onto the wall;
  - climbed with feet on the rungs, one limb at a time.
- **Mantlet and fascines:** a mantlet pushed on with a crossbowman behind it; a fascine run up on the shoulder, heaved and thrown down.

## Pictures (results/units/medieval/)
- **siege_look:** every engine; the tower from behind; mantlets in six lords' arms; close / mid / far.
- **siege_crews_engines** and **siege_crews_assault:** every crew job, six frames each.
- **siege_actions:** the trebuchet's throw, the mangonel's throw, the ballista drawn and loosed, the tower's bridge let down, the ram's swing.
- **siege_siege**, against our troops:
  1. the siege lines before our wall;
  2. the trebuchet looses;
  3. a stone strikes the parapet;
  4. mangonel stones on our trench;
  5. a ballista bolt on the wall walk;
  6. the ram at our gate, the leaves bowing in;
  7. the tower docks and the host crosses the bridge;
  8. ladders up the wall;
  9. fascines thrown into our trench under the mantlets' cover.

## Files
- scripts/units/siege_builder.gd (the geometry)
- scripts/units/siege_engine.gd (`SiegeEngine`: the parts, the states, the crew spots)
- scripts/units/anim/clips_siege.gd (crew poses with their hands on points; gaits for push, carry and trot; the ladder climb)
- tools/siege_pictures.gd (`-- look crews actions siege`; SIEGE_ONLY=<row> for one row)

## Open / for later
- Shots in flight are props. In the game they want the projectile system, with hits that break wall pieces (the wall's damaged look exists).
- The ram crew are mostly hidden under the roof from the side; the front views show them.
- Ropes and chains are straight; there is no sag.
- No videos (as asked). The engines' states make them easy to animate later.

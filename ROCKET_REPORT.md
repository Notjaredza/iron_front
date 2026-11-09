# Rocket lorry round (Tanks Chat), 2026-11-10

Go at about 00:24, built by 00:46 (ETA was 1 to 2 h). APPROVED by the user at 00:52 after the lying-down fix.

## What it is
- The troop lorry with its tilt and benches taken off. A steel blast shield sits behind the cab, and a fold-down crew seat sits at the back of the bed.
- On the bed: a turntable carrying an open lattice cradle with 16 launch rails (4 by 4).
- Two screw jacks sit at the rear corners. A training handwheel is on the left cheek.
- Rockets are finned tubes 1.15 m long. They are carried from a wooden box that holds 6.
- Crew of 4: the NCO, the driver, and 2 men who ride on the rear seat.
- Code:
  - `scripts/vehicles/rocket_builder.gd` (the meshes);
  - `scripts/vehicles/rocket_lorry.gd` (class `RocketLorry`, extends `Lorry`: `set_train`, `set_elev`, `set_jacks`, `set_loaded`, `rocket_xf`);
  - `tools/rocket_clips.gd` (the clips).
- One small change to the approved lorry (`lorry_builder.gd`): the far look now leaves the canvas off when tilt is off. The troop lorry itself is unchanged.

## Triangles
| Look | Triangles |
|---|---|
| Close | 10,356 |
| Mid | 3,464 |
| Far | 480 |
| Wreck (close) | 8,660 |

- The mid look keeps the rockets but drops their fins and bands.
- The far look shows the rack as one block with no rockets.

## Videos (results/units/anim/)
- `rocket_gallery.mp4`: the close, mid and far looks and the wreck, front and back.
- `rocket_look.mp4`: the camera circles the lorry while the jacks go down and the rack trains and rises, then everything goes back for travel.
- `rocket_setup.mp4`: the lorry drives in and the crew get out (cab and over the tailgate). Two men crank the jacks down. The NCO walks out to point the line. The driver climbs up and turns the handwheel, and the rack trains and rises to 42°.
- `rocket_load.mp4`: the rack is held low (8°) for loading. Two carriers take rockets from the box and lift them up to the loader on the bed, who slides each one onto a top-row rail. With all 16 on, the rack goes up to firing angle.
- `rocket_fire.mp4`: the crew wait in cover and the NCO gives the word. The salvo ripples off (16 rockets, 0.22 s apart) with flame, fire trails, a smoke cloud and dust thrown up behind. The camera follows the arcs out to the impact zone, where the rockets land 200–260 m away in a spread of blasts.
- `rocket_packup.mp4`: the rack comes down and is trained back, and the jacks are wound up. The crew climb aboard, the tailgate goes up, and the lorry drives off.
- `rocket_wreck.mp4`: counter-battery fire. A near miss, then a direct hit. The lorry swaps to its burnt wreck and the rockets left on it cook off one by one in wild directions. The crew run, and the wreck burns down and stays.

Stills: `results/units/rockets/`: `rocket_gallery.png`, plus a front and back picture of each look.

## Check
`Godot --path iron_front --headless -s res://tools/rocket_clips.gd -- check` fires a salvo with no camera:
- **ROCKET CHECK OK**;
- all 16 rockets land, at 198–258 m;
- every look is within its triangle budget.

## How the flight works
- Each rocket leaves its rail at 13 m/s.
- Its motor pushes along the launch line (23–25 m/s²) for about 1.6 s, then it flies a plain ballistic arc.
- Each rocket's push and aim are seeded slightly differently, which spreads the impacts.
- Each landing sets off a size-1 Blast (the shared blast system).
- In a cook-off, the rockets use 70% thrust and fire in wild directions.

## Open items
- **IMPORTANT:** the clips are not yet tied to real move orders or the game's unit control. The same is true for the tanks.
- The crew carry no rifles in these clips.
- Rocket sounds are not done.
- 2026-11-10 00:50: on the user's note, no one lies down any more. The men in cover in the fire clip crouch, and the running crew in the wreck clip kneel; the old prone pose hovered in a push-up shape.
- Reloading takes a box of 6. A full reload of 16 would need more boxes and is not shown.

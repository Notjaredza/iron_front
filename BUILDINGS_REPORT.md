# Iron Front: buildings round (report)

Asset Builder Chat, night run 2026-11-10, about 00:55 to 01:50. The plan is BUILDINGS_PLAN.md. **This waits for the user's look.** It covers models, looks and stills only. Placing, costs and power come later.

## What's built: 25 kinds in 6 sets, plus the wall pieces

| Set | Kinds (tiles of 8 m) | Life |
|---|---|---|
| Core | HQ 3x3, barracks 2x3, depot 3x2 | smoke, flag, drill squad swaps stand and ready, depot crane jib swings |
| Walls | concrete wall pieces 1x1: end, straight, corner, T, cross; tower, bastion, road gate, rail gate | searchlights sweep, lamps, gates open and shut |
| Rail | halt 2x1, station 3x2, engine shed 2x3, water tower 1x1, coal stage 2x1, signal box 1x1 | smoke, water spout swings, coal jib swings, signal arms drop and rise |
| Comms | runner post, telegraph post, lamp tower, pigeon loft (all 1x1) | telegraph crank turns, lamp shutters flash long and short, pigeons wheel |
| Research | comms lab 2x2, weapons lab 2x2, rail lab 3x2, defences lab 2x2, wreck yard 3x3 | teal coils pulse, the coil gun's rings charge and flash, the field sheet flickers, gantry and trolley travel, cutting torches flicker and spark |
| Defences | sandbag line (joins as you drag), wire belt, concertina, hedgehogs, concrete teeth, MG nest 1x1, gun pit 2x2 | crews at the gun (posed) |

**Strange tech, "WW1 with a hint":** each lab is a plain field-army building with one strange piece on it, glowing teal: a coil on an insulated stand, a coil gun on a test stand, a bogie with glowing wheels, and a field sheet between two posts. The wreck yard has a walker hull on blocks, piles of legs and plates, and a coil test rig. The teal glow stays on even when the lights are off.

## Every building has
- **Construction:**
  - plot, then frame with scaffold, then half built, then finished;
  - builders stand in at the frame and half-built stages: one hammering at the wall foot, one carrying a plank, and one at a timber stack (see the note below).
- **Damage:**
  - intact, then damaged (roof holes, scorched walls and shell holes, fire points), then a ruin;
  - `collapse(u)` tips the four corners outward and sinks them into the ruin, while the ground slab stays put.
- **Lights:** `set_lights(on)` switches every window, lamp, searchlight and beam, ready for the power system.
- **Marks:** door, entry, rail, platform, gun, fire_dir, lamp and wire_out, as each building has them.
- **Far look:** each building has a far look of 16 to 212 triangles. Small props drop out of it, and thin things (wire, legs, sandbags) get simple stand-in blocks so they don't vanish.
- **Placement ghost:** green where it fits and red where it's blocked, with a tile outline.

## Auto-joining
- **Walls:** `BldWalls.solve(walls, tracks, chosen)` gives each cell its piece. Where a wall crosses a straight track, the rail gate goes in by itself, whichever was built second. A wall across a track bend or a junction comes back as "blocked".
- **Sandbag lines:** use the same solve; `BldDefences.line(mask)` builds the piece for each cell.
- **The rail gate:** `BldWalls.update_rail_gate(b, train_dist, dt)` opens it when a train is within 120 m and shuts it behind the train.
- **Crews:** `BldDefences.set_crew(b, on)` shows or hides the MG team or the gun crew.

## Crews (approved models, read only)
- **MG nest:** the heavy MG on its tripod sits on a raised firing platform so it clears the bags. The gunner's hands are on the grips and the loader feeds the belt from the open box, using the MG team's own poses.
- **Gun pit:** the light field gun sits under a camouflage net, with:
  - the layer and the breech man on the axle seats, their hands on the handwheel and the lever;
  - the loader and two ammunition numbers kneeling;
  - the NCO at the side.

  All of these use the gun crew's own poses.

## Stills (results/buildings/)
Results are git-ignored, as before.
- **Each kind:** `<kind>_day`, `<kind>_night` and `<kind>_stages`. The stages row shows plot, frame, half, finished, damaged, mid-collapse and ruin.
- **Per set:** `set_<set>_far_ghost`, with the far looks in the back row and the ghosts in the front row (the last ghost is red).
- **Walls:**
  - `walls_pieces`;
  - `walls_base_day` and `walls_base_night`;
  - `walls_rail_gate` (shut, and open with a train);
  - `walls_cliff`;
  - `walls_stages`.
- **Defences:**
  - `defences_line` and `defences_belt_night`;
  - `defences_crews` (crewed and empty, side by side).
- **The rest:** `build_site` (builders at work), `base_overview_day` and `base_overview_night`.

## Things to know
- **Builders:** the engineer round is paused, so the builders are riflemen in the loader's kit, without tools. When engineers are approved, they swap in at `Building._make_workers`.
- **Collapse:** it's a baked motion of the four corner chunks. The caller sets off the shared Blast at the start, so no blast is shown in these stills.
- **Wall-piece sizes:** 8 m cells, a body 3.4 m high, the walkway at 4.6 m, and the wall 2.6 m thick.
- **Triangle counts:** near looks run from 256 (hedgehogs) to 10,212 (HQ). The concertina is 6,448 near because every loop is real wire, but its far look is 144.

## Commits (iron_front)
- 29502cf: kit and core.
- 09e73f1: walls.
- e1499b2: rail.
- 1b03529: comms.
- 9f2931a: research.
- d55e226: defences.
- One more commit for the builders, the build_site still and this report.

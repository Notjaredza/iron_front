# Iron Front: buildings round (plan)

Asset Builder Chat, 2026-11-10. **Nothing is built until the user says go.** This is a night run: I build everything, check each picture myself, commit set by set, and leave one look for the morning.

This round covers models, their looks and stills only. Placing, costs and the power system come later. DESIGN.md "Base and buildings" is the source.

## The user's answers

### Sets, in this order
1. **Core:** HQ, barracks, depot.
2. **Walls and gates**, including the auto rail gate.
3. **Rail buildings.**
4. **Comms buildings.**
5. **Research and wreck yard.**
6. **Defences.**

### Sizes and look
- **Sizes:** a mix. Small posts take 1x1 tiles, the HQ and stations 3x3 or more, all on the 8 m grid.
- **Look:** a field-army mix: timber huts, sandbags and corrugated iron, with a few brick and stone halls (the HQ and the station). They're flat-shaded and low-poly like the trains and planes.

### The HQ
- A command post: a brick house with sandbags and map-room lights;
- a telegraph and radio mast, a flag and a staff car;
- a sick-bay corner where the officer recovers.

### Each set in detail
- **Barracks:** huts and a drill square.
- **Depot:** stacked crates and fuel drums under a roof, a loading bay and a rail siding.
- **Walls:**
  - one concrete wall type;
  - pieces join up by themselves as you drag (straight, corner, T, cross and end), and fit at cliff edges;
  - a walkway with firing steps;
  - towers and bastions.
- **Lights:**
  - lamps along the walls and at the gates;
  - searchlights on the towers;
  - all on an on/off switch, ready for the power system.
- **Gates:**
  - a road gate;
  - **the rail gate:** placed by itself wherever a wall and a track cross (whichever is built second). Heavy doors open as a train comes and shut behind it.
- **Rail buildings:** a halt; a station; a yard with an engine shed, water tower and coal stage; a signal box with moving signal arms.
- **Comms buildings:** a runner post, a telegraph post with poles and wire, a lamp tower with shutters, and a pigeon loft with pigeons.
- **Research and wreck yard:**
  - WW1 workshops and field labs with a hint of strange tech: salvaged walker parts, odd glowing coils and cables;
  - one research building each for comms, weapons and units, rail, and defences;
  - the wreck yard has a gantry, cutting torches and walker parts.
- **Defences:**
  - straight sandbag lines that join as you drag;
  - barbed-wire belts, concertina coils, and steel hedgehogs and concrete teeth against walkers;
  - MG nests and gun pits, shown empty and crewed with the approved gunner squad and light field gun. Those are read only: I pose them from my own scripts.

### Every building gets
- **Construction stages:** a marked-out plot, then frame and scaffold, then half built, then finished. Engineers are posed hammering and carrying.
- **Damage:** intact, then damaged (holes, fire and smoke), then a ruined shell, then a baked collapse with the shared Blast.
- **Life:**
  - chimney smoke and warm window lights at night;
  - moving parts: doors, flags, signal arms, shutters, pigeons;
  - working loops: drilling, crates moved, research sparks, cutting torches.
- **Hooks for later:**
  - one lights on/off switch per building;
  - door and entry marks for troops, trucks and trains;
  - a far look for the zoomed-out map;
  - a placement ghost: see-through, green where it fits and red where it's blocked.

### For the morning look
Stills only:
- each building by day and by night;
- its construction stages and damage stages;
- the wall-piece set, the rail gate open and shut, and the crewed nests;
- a base overview.

## Files (my paths only)
- scripts/buildings/
- tools/bld_*.gd
- assets/buildings/
- results/buildings/
- BUILDINGS_PLAN.md and BUILDINGS_REPORT.md

I won't touch other chats' files. The units, the field gun and the Blast are read only.

## ETA

By the old table it's about 16 h. Going by the last two rounds (the air round took about 1 h against 10-12 h, and the paratroopers about 1 h against 7-8 h), the real time is likely **4-6 h**.

| Step | Table time | Running |
|---|---|---|
| Shared kit: building geometry, lights switch, marks, far look, ghost, stage and damage system | 2 h | 2 h |
| Core: HQ, barracks, depot | 2 h | 4 h |
| Walls, gates, rail gate, towers, lights, auto-join pieces | 2.5 h | 6.5 h |
| Rail buildings | 2 h | 8.5 h |
| Comms buildings | 1.5 h | 10 h |
| Research and wreck yard | 1.5 h | 11.5 h |
| Defences: sandbags, wire, coils, traps, crewed MG nest and gun pit | 2.5 h | 14 h |
| Collapse bakes and check | 1 h | 15 h |
| Gallery, overview and report | 1 h | 16 h |

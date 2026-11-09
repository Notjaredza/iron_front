# Iron Front: step 1, the stepped map (plan)

Asset Builder Chat, 2026-11-09. This is the brief from DESIGN.md ("The map" section, plus "Build order" step 1) and the user's answers. **Nothing is built until the user says go.**

## The user's answers
- **Cliff edges:** square along the 8 m grid, plus 45° corner cuts, as in reference 04.
- **Step height:** 8 m per level. Level 2 is 8 m above the base and level 3 is 16 m.
- **High ground:** about a third of the map is on levels 2 and 3.
- **Trees:** none for now. They come later.

## What gets built
- **The project:** a new Godot 4.7.2 project in `iron_front`, with its own git repo and fresh code. Nothing is copied from WW1, and there is no Terrain3D.
- **The generator:** a seeded 8 x 12 km map on the 8 m grid (1000 x 1500 cells).
  - It places levels 1-3, with plateaus making up about a third.
  - Cliffs are 8 m high and smoothed to square edges plus 45° cuts.
  - Each cliff has a dirt bank at its foot and a grass lip at its top.
- **Ramps:** mostly wide (2-3 cells), plus a few narrow 1-cell passes. Every plateau gets at least one.
- **Water:** square-banked lakes and rivers, one level down, with flat water on top.
- **Markers:**
  - old rail lines: a mix of working and broken, laid along flat ground and ramps;
  - villages and ruins as simple stand-in blocks.
- **The look:**
  - by day, bright and flat low-poly colours (grass green, dirt brown, blue water);
  - at night and in fog, cool and moody.
  - A key toggles day, night and fog for checking.
- **Drawing:**
  - the ground is built as 256 m chunks, with a cheaper far version for distant chunks;
  - the target is 60 FPS on the laptop for the whole map.
- **The camera:** works like WW1's: fly over, zoom, turn and tilt.
- **The test scene and check:**
  - every plateau can be reached by ramps;
  - no gaps or holes at cliffs or between chunks;
  - a picture tool, and a frame-rate run booked in LAPTOP.md.

## ETA: about 15-17 h of work

| Stage | Hours | Total |
|---|---|---|
| Project, generator and chunked ground mesh | 5 | 5 |
| Ramps, water and the reachability and holes check | 4 | 9 |
| Rail lines and village stand-ins | 2 | 11 |
| Camera and the day, night and fog look | 3 | 14 |
| Frame rate to 60 FPS, plus the report and pictures | 2-3 | 16-17 |

**First pictures** of the ground will be ready after about 5 h, for an early look before ramps and water.

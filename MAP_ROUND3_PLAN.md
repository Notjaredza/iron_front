# Iron Front map round 3: water, fords, trees, fields (plan)

Asset Builder Chat, 2026-11-10. **Nothing is built until the user says go.** Bridges and other buildings are saved for later.

## The user's answers
- **Water:** all four.
  - Deeper banks and live water: ripples, foam at the banks, a darker deep middle.
  - Small streams, 1-2 cells wide, feeding the rivers and lakes.
  - Three rivers: one wide main river (5-8 cells, 40-64 m) and two at 2-4 cells.
  - Marsh edges: boggy shallows with reeds around some lakes, marked as slow ground.
- **Fords:** 3-5 per river. Each is a shallow, pebbly crossing with sloped banks, which units wade slowly. Streams are easy to cross everywhere.
- **Trees:** woods plus lone trees and hedgerow lines, covering about 20 % of the map.
- **Decor:** tall grass patches, and wheat or crop fields near the villages. They're looks only for now; what they do in play comes later.
- **Run:** all at once, with one look at the end: stills plus a fly-over.

## How
- **Map data (scripts/map/):**
  - new masks for ford, marsh, stream, wood and field;
  - fords and streams count as walkable, slow ground, so every area is still joined without bridges;
  - the reach check is changed to match, so deep water now blocks except at fords.
- **Water shader:**
  - gentle animated ripples, foam where the water meets a bank, and depth tint;
  - by day it keeps the bright low-poly look, at night the cool WW1 look.
- **Trees:**
  - low-poly instanced trees (MultiMesh per chunk), several shapes and colours, with simple far looks;
  - drawn within a set distance, with woods shown as clumps when seen from far up.
- **Fields and tall grass:** painted ground plus instanced stalks near the camera, like the grass tufts.
- **Keep-clear rules** still hold: nothing on cliffs, ramps, rails or village plots.

## Checks
- check_map on seeds 1, 2, 3 and 5:
  - no holes;
  - walls closed;
  - every area reachable without bridges;
  - each river has 3-5 fords;
  - wood cover is about 20 %.
- Frame rate in a fly-over: aim for 60+ fps at every height on the laptop.

## ETA
By the old table it's about **12 h**:

| Part | Hours |
|---|---|
| Water and shader | 3 |
| Streams, fords, marsh | 3 |
| Trees | 3 |
| Fields and grass | 1.5 |
| Checks, frame rate, stills | 1.5 |

Going by the last rounds, real time is likely **3-4 h**.

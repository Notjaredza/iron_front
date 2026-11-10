# Iron Front map round 3: water, fords, trees, fields (report)

Asset Builder Chat, 2026-11-10, built on the user's "Go" (plan: MAP_ROUND3_PLAN.md). Bridges and other buildings are saved for later, as asked.

## What's in
**Water**
- **Rivers:** three, with one wide main river through the middle third and two narrower ones; a narrow one sometimes widens.
- **Banks:**
  - deeper, at 2.2 m below the plain, with a sloped bank profile;
  - the water is coloured by depth (bank, middle, deep).
- **Live water (shader):**
  - drifting ripples and slow broad patches that soften the depth steps;
  - broken, moving foam where the water meets the bank;
  - a softer sun glare.
- **Streams:** 14 small streams running downhill into the rivers and lakes. Each is 1-2 cells wide, cut 0.45 m into the ground with dirt sides, and walkable.
- **Marsh:** boggy edges round some lakes (not the rivers): mottled mud and wet grass with pools of still water, plus reeds.

**Fords**
- **River fords:** 5 on each river (3-6 across the seeds), kept 600 m apart.
- **Island fords:** a small island that water would otherwise cut off now gets a short ford of its own to the main land.
- **Look:** at each ford the bank wall gives way to gravel slopes that run down under the water, with a shallow, pebbly crossing and stepping stones.
- **In play:** the map check now counts deep water as blocked except at fords, and every area is still reachable without bridges.

**Trees**
- **Woods:** about 20 % of the dry ground, in woods of mixed broadleaf and pine (more pine on the high ground).
- **Lone trees:** about 4,400, some along the streams.
- **Hedgerows:** round some fields, plus 90 field-edge hedge lines.
- **Tree shapes:** five low-poly kinds of about 50-58 triangles each, drawn as one MultiMesh per kind per chunk.
- **Distance:**
  - full trees are drawn to 700 m;
  - beyond that they become canopy lumps, so from high up woods read as clumps;
  - trees cast shadows only when the camera is low (below 220 m).

**Fields and tall grass** (looks only, as agreed)
- **Fields:**
  - 5-9 round each village, in wheat, green crop, ploughed earth or hay;
  - the shader draws crop rows along x or z;
  - near the camera, wheat stalks stand in the rows.
- **Tall grass:** patches of about 6 % of the dry ground, painted and with tall blade clumps near the camera.
- **Fields stay clean:** grass tufts and flowers are kept off fields and streams.

## Checks (check_map, seeds 1, 2, 3, 5)
All checks pass on all four seeds:
- no holes;
- walls closed;
- chunk borders match;
- every ramp right;
- every area reachable;
- 3+ fords per river;
- woods 19.4-19.8 %.

Generating a map takes about 14-24 s on a quiet laptop (54 s once, while a picture run shared the laptop). The nature step is about 4-8 s of that.

## Frame rate (fly-over, seed 2, window 1600 x 900)
| Height | Before this round (same laptop, same morning) | Now | Worst second now |
|---|---|---|---|
| 30 m | 92 | 74 | 69 |
| 120 m | 109 | 79 | 75 |
| 400 m | 96 | 66 | 63 |
| 1000 m | 88 | 66 | 64 |
| 2500 m | 70 | 50 | 48 |

Runs of the same setup moved by up to 9 fps between back-to-back runs, so these numbers are rough.

What I tried:
- shorter tree range;
- tree shadows only when low;
- trees hidden above the tree range;
- a coarser far canopy;
- a lighter water shader.

**Every height except 2500 m stays above 60.** The whole-map view at 2500 m is about 50 fps: the extra ground detail (paint patches split the big flat pieces), the shader and the canopy each take a few fps.

**IMPORTANT, your call:** to get 2500 m back to 60, I could:
- merge each 2 x 2 group of chunks' canopy into one draw, and/or
- drop the tall-grass paint from the ground mesh (keeping only the blades near the camera).

## Pictures (results/, from `tools/nature_pictures.gd -- --seed=2 --out=r3`)
| View | Files |
|---|---|
| Whole map | r3_whole_day, r3_whole_night |
| Regions | r3_region_day (1400 m), r3_region_low_day (600 m) |
| Fords | r3_ford_wide_day/night, r3_ford_close_day, r3_ford_narrow_day, r3_ford_eye_day |
| Streams | r3_stream_day, r3_stream_eye_day |
| Woods | r3_woods_day, r3_woods_edge_eye_day, r3_woods_night_night, r3_woods_night_fog |
| Fields and grass | r3_fields_day, r3_fields_close_day, r3_tall_day |

## Files
- **New:**
  - scripts/map/map_nature.gd: depth, fords, island fords, streams, marsh, fields, hedges, woods;
  - scripts/map/tree_kit.gd;
  - tools/nature_pictures.gd.
- **Changed:**
  - scripts/map/map_data.gd, map_gen.gd and map_mesher.gd;
  - scripts/map/map_view.gd and ground_scatter.gd;
  - shaders/ground.gdshader;
  - tools/check_map.gd.

## Later (not in this round)
- Bridges and other buildings.
- What the woods, fields, marsh and tall grass do in play: cover, slow ground, hiding.

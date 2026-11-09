# Iron Front, step 1: the stepped map (report)

Asset Builder Chat, 2026-11-09, 21:10. Plan and answers: MAP_PLAN.md. Code: iron_front at commits 0a05e75 and 2907b6e.

**State: built and checked, ready for your look.** It took about 30 minutes, not the 15-17 h estimate.

## How to see it

Open `iron_front` in Godot 4.7.2 and press Play, or run:
`Godot_v4.7.2-stable_win64.exe --path "GAME IDEA!/iron_front" -- --seed=2`

The map builds in about 12-15 s. A "Building the map" line shows while it works.

**Keys:**
- WASD or the arrows move, and Shift moves faster.
- The wheel zooms, all the way down to eye level.
- Q and E turn, as does dragging with the middle mouse button.
- T switches day, night and fog.
- N makes a new map.

## What's in it

- **The map:**
  - 8 x 12 km on the 8 m grid, made fresh from a seed.
  - About a third is high ground: 23 % on level 2 and 9-10 % on level 3.
  - The cliffs are 8 m tall. They run square along the grid with 45-degree cuts of 1-3 cells.
  - Each cliff has a grass lip, a dirt bank leaning out about 4.6 m, and a dirt apron at its foot.
- **Ramps:** about 300 per map, roughly 75 % wide (2-3 cells, 16-24 m) and 25 % narrow passes (1 cell).
  - Each ramp is 32 m long, with a dirt track down the middle, grass edges, and earth sides sloping down.
  - Every plateau gets some, more on big ones, and every area is joined.
  - An area that can't take a ramp is lowered or filled, so nothing is left cut off.
- **Water:**
  - Lakes and two rivers, one level down, with square banks and 45-degree cuts.
  - Water is kept at least one block (32 m) clear of the plateaus.
- **Old rail lines:** three per map, 30-50 km in all, with about a third broken.
  - Broken stretches have rusty or missing rails, skewed sleepers, and overgrown ballast.
  - They run on the base level only, with bridges where a line has to cross water.
- **Places:** 10 villages, 3-4 of them with a station and platform by a line, and 8 ruins.
  - The houses are simple stand-ins on the 8 m grid: walls, a gable roof, and windows that glow at night.
  - Each place is kept in the map data for capturing later.
- **The look:**
  - By day, bright, flat low-poly colours, with a little tone change per cell and over large patches.
  - At night and in fog, cool and grey.
  - The fog thins as you go up, so the whole map stays clear from high up.
- **The camera:** fresh code that behaves like WW1's.
  - It uses the same pan speed and zoom steps.
  - The tilt follows the height, and it comes down to eye level at the closest zoom.

## Checks (tools/check_map.gd, headless)

Seeds 1, 2, 3 and 5 at full size: **every check passes on all four.**
- **High ground:** 33 % on each seed.
- **Ramps:** mostly wide, some narrow.
- **Reach:** every ramp runs from a flat top to flat ground one level down, and every area of 16 cells or more can be reached from the main base area (115-130 plateau areas per map).
- **Walls closed:** about 66,000 wall corners per map, none open, and the chunks on each side of a border agree.
- **No holes:** 137,500 straight-down rays per map, all hitting ground at the right height, including at chunk borders.

## Frame rate (window, 1600 x 900, quiet laptop)

| Camera height | Average fps | Worst second | Draw calls | Triangles drawn |
|---|---|---|---|---|
| 120 m | 124 | 116 | 11 | 10 k |
| 400 m | 108 | 107 | 40 | 97 k |
| 1000 m | 95 | 87 | 39 | 111 k |
| 2500 m | 77 | 75 | 104 | 364 k |

This was a fly-over at WW1's pan speed (tools/fly_run.gd, seed 2). Each map has 384 chunks of 512 m, one draw call each, with 1.1-1.4 million triangles in all.

## Still open (your call where noted)

1. **Making a map takes 12-15 s:** 8-11 s to generate and 3-4 s to build the meshes. That's fine at the start of a long run, but it can be made faster later.
2. **Water has no crossings yet:** no bridges for armies, no fords. The reach check counts water as crossable until bridges come in a later step.
3. **Rail lines stay on the base level:** inclines, cuttings and tunnels come with the rail step. One line can wander round lakes (51 km on seed 2).
4. **Tiny corner pockets:** 15-29 flat bits per map, each under 16 cells, are left where cliff corners meet. No unit could use them.
5. **The water banks** are only 3 m drops, so they read thin from high up. They can be deepened if you want.
6. **Trees** come later, as you asked.

**Note:** another chat is building the rifleman in this same repo, and its commits sit between mine. Its files weren't touched.

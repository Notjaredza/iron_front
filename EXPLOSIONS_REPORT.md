# Explosions, round A (2026-11-09)

Built by Building Chat 1 in iron_front. The troops' faceted low-poly look, with a large share of the frame budget.

## What's in it
- **Sizes 1, 4 and 8, tuned.** 1 is a mortar, 4 a medium gun, and 8 a super-heavy railway gun a little bigger than Gustav. Sizes 2, 3, 5, 6 and 7 work but are not tuned yet; that's round B.
- **Each size has its own build, not one blast scaled up.**
  - Size 1: a fireball, a jet of earth, a smoke ball, clods and sparks.
  - Size 4 adds a flattened dust ring.
  - Sizes 6 and up add a dome of earth and a mushroom column. Size 8 also throws big blocks.
- **Faceted billows**, the style the user chose ("its the top rows"). The cloud is lit as one mass: creases go darker, the fire lights the smoke from inside, and the smoke lightens as it ages and drifts with the wind higher up. The soft-puff shader is still in the project but nothing uses it.
- **Craters and scorch stay**, each with a rim and an earth blanket. The flash and fire light up the ground, and the camera shake arrives at the speed of sound.
- **Night versions:** the fire glow and hot clods are stronger at night.
- **The GPU does all the motion.** Each blast's particles are made once; after that only the time is updated each frame. Clips are frame-exact repeatable.

## Files
- `scripts/fx/`: `blast.gd`, `blast_specs.gd` (the per-size table), `fx_mesh.gd`, `fx_ground.gd`, `blast_stage.gd`.
- `shaders/fx_*`.
- `tools/blast_test.gd` (live test) and `tools/blast_clips.gd` (stills and videos).
- Results in `results/fx/`: stills sheets and the clips `s1_day`, `s1_night`, `s4_day`, `s4_night`, `s8_day`, `s8_night` (.mp4).

## Live test
Run `Play Iron Front Blasts.bat` from GAME IDEA!.

| Key | What it does |
|---|---|
| 1-8 | Fire that size where the camera looks |
| X | Salvo |
| N | Day / night |
| C | Clear craters |
| K | Shake on / off |
| H | Hide help |
| Right drag | Turn |
| Wheel | Zoom |
| WASD | Move |
| Q / E | Turn |

## Frame rate
Laptop, 1600x900, faceted style, `-- bench`:

| Scene | Day: average / worst second | Night: average / worst second |
|---|---|---|
| Size 1, 30 m | 94 / 91 | 98 / 92 |
| Size 4, 70 m | 87 / 86 | 89 / 89 |
| Salvo of 7 | 77 / 73 | 78 / 71 |
| Barrage, 24 shells in 6 s | 62 / 55 | 63 / 57 |
| Size 8, 620 m | 93 / 88 | 94 / 88 |
| Size 8 from inside the dust, 250 m | 96 / 93 | 95 / 92 |
| Size 8 + barrage | 55 / 39 | 75 / 71 |

What fixed the frame rate:
- One shadow layer, as the map uses, with its distance following the camera.
- A particle budget: when many blasts are live, new ones draw fewer particles (down to 40%) but keep their shape.

Still open: one dip of about 120 ms in the day size 8 + barrage scene. It is probably crater ground rebuilds or a first-time shader load. I'll look at it in round B.

## Round B (on the user's go, about 4-5 h)
- Tune sizes 2, 3, 5, 6 and 7.
- Grenades, small hits (bullet strikes) and a mine or big charge.
- Men thrown by blasts.
- Craters on the real map.
- The hitch above.

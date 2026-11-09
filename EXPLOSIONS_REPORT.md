# Explosions, rounds A and B (2026-11-09)

Built by Building Chat 1 in iron_front. The troops' faceted low-poly look, with a large share of the frame budget.

## What's in it
- **Sizes 1, 4 and 8, tuned.** 1 is a mortar, 4 a medium gun, and 8 a super-heavy railway gun a little bigger than Gustav. (Round B tuned the rest; see below.)
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

Round A left one dip of about 120 ms in the day size 8 + barrage scene. Round B found and fixed it (see below).

# Round B (2026-11-09, started on the user's go at about 22:20)

## What's new
- **All eight sizes are tuned.** The sheets `results/fx/ladder_*.png` show them side by side.
  - Sizes 2, 3 and 5 sit between the approved ones.
  - Size 6 (siege mortar) got its own column: a stem that widens upwards into a broad cap.
  - Size 7 is a smaller 8.
- **New kinds** (`scripts/fx/blast_kinds.gd`), each its own shape:
  - **Grenade:** a sharp flash, a grey-brown puff, a short spray of dirt and fast fragments.
  - **Anti-person mine:** a small pop and a low ring of dirt thrown out flat.
  - **Anti-tank mine:** a tall narrow jet of earth with black smoke climbing it.
  - **Tunnel mine** under a trench: the ground heaves up as a dome for a second, then bursts into a huge fan of earth and a lingering brown cloud. Its flash and crater come late, with the burst.
  - **Demolition charge** (bridges, rails): a hard white flash, pale cordite smoke, wood and iron flung out flat and far.
  - **Bullets in the dirt:** a small puff and specks. A machine-gun burst walks across the ground.
  - **Bullets on metal:** sparks off the plate, shown on the goods van from trains round 1. Ready for tanks when they come.
  - **Light flare:** goes up on a smoke trail, then hangs on its parachute and drifts down for 30 s. It lights a wide circle of ground and throws real moving shadows (one shadowed light).
  - **Signal flares,** red, green and white: up, then a short bright fall with a tinted trail.
- **Men thrown by blasts** (`scripts/fx/blast_throw.gd`). The user's call: "tumble, most get up". Three rings come from each blast's crater size:
  - **Kill ring:** men are thrown tumbling and stay down, on their back or face.
  - **Throw ring:** men are thrown tumbling, land face down, lie stunned for 2–4 s, then get up.
  - **Knock ring:** men are knocked flat, then get up.
  - **Which way he falls depends on which way he faces** (the user's note after the first clips):
    - **Facing the blast:** he goes over backwards and lands on his back. If he lives, he rolls onto his front and gets up facing away.
    - **Back to the blast:** he's pitched forwards onto his face, then gets up.
  - The blast wave reaches each man at the speed of sound. The poses are the riflemen's own clips.
- **Blasts and lasting craters on the real map** (`scripts/fx/map_blasts.gd`, `map_craters.gd`).
  - The map's terraces aren't dug into. Each crater is a hole drawn through the ground with the stencil buffer, plus an earth lip and a scorched ring.
  - Four ragged shapes, one MultiMesh each, so a thousand craters still cost twelve draw calls.
  - Craters only go on flat ground; no craters on cliffs, ramps or water.
  - Run `Play Iron Front Map Blasts.bat`:
    - F fires the chosen blast at the mouse pointer. 1–8 pick a shell size, and 9 / 0 cycle the other kinds.
    - G fires a barrage, V a light flare, and C clears the craters.
- **The size 8 stutter is fixed.** Each blast works out where its clods land when it starts. That used to step along every path, which took 225 ms for a size 8 and 25 ms for a size 4. It now does a few Newton steps on the exact flight curve: 31 ms and 4 ms, with landing heights checked exact to the millimetre.

## Live test, new keys
| Key | What it does |
|---|---|
| G | Grenade |
| M | Mines in turn: anti-person, anti-tank, tunnel |
| J | Demolition charge |
| U | Machine-gun burst in the dirt |
| I | Bullets on the van |
| L | Light flare |
| R / T | Red / green signal flare |
| P | A new squad where you look |

## Clips (results/fx/*.mp4)
- **Sizes:** `s2_day`, `s3_day`, `s5_day`, `s6_day`, `s7_day`.
- **Kinds:** `grenade`, `mines`, `tunnel`, `demolition`, `bullets`, `flares_night`.
- **Thrown men:** `thrown_men`, `thrown_men_night`.
- **The real map:** `map_day` and `map_night`, with a barrage, an anti-tank mine and a size 6. At night a light flare goes up first. The craters left behind are in `map_craters_day.png` / `map_craters_night.png`.

## Round B frame rate
The laptop was shared with other chats' renders tonight. This run was made from a clean git worktree (only these files on top of the last commit) at 23:46; another Godot showed up in only one of its 5-second samples. 1600x900:

| Scene | Day: average / worst second | Night: average / worst second |
|---|---|---|
| Size 1, 30 m | 94 / 89 | 97 / 90 |
| Size 4, 70 m | 87 / 84 | 89 / 86 |
| Salvo of 7 | 77 / 75 | 80 / 78 |
| Barrage, 24 shells in 6 s | 61 / 53 | 62 / 54 |
| Size 8, 620 m | 97 / 80 | 86 / 17 (one 285 ms frame, when the other Godot started) |
| Size 8 from inside the dust, 250 m | 96 / 87 | 93 / 87 |
| Size 8 + barrage | 76 / 73 | 76 / 73 |
| Light flare (real shadows) over a 24-shell barrage | 54 / 39 | 57 / 47 |
| 4 MG bursts, grenades, bullets on the van | 97 / 95 | 99 / 97 |

- **The heaviest new case** is a light flare over a big barrage. It dips under 60, which is within "if it dips a little all good". Blast particles are kept out of the flare's shadows; only men, vehicles and ground cast them.
- **Thrown men only re-solve their pose when it changes**, so a field of fallen men costs nothing.
- **Bullets and grenades are cheap.**

## Not done / for later
- Water: blasts on rivers go off but make no splash and no crater.
- Grass tufts from the map's scatter still show inside craters.
- Bullet hits are one small node each. That's fine for the test; real MG fire in battle should pool them.
- On the test field, craters under 1.2 m only scorch, because its 1.5 m grid is too coarse. On the map they're real holes.

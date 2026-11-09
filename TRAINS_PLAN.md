# Iron Front: train assets and animations, round 1 (plan)

Asset Builder Chat, 2026-11-09. **Nothing is built until the user says go.**

This round covers the train models and their animations only. Track laying, routes, signals and running are a later piece.

## The user's answers
- **Models:** a steam engine with a tender. The 3, 4 and 5-car test trains are filled out with **plain stand-in cars**: a box van with doors and a flat wagon with a gun mount. The real wagons replace them later and reuse the same moves.
- **Look:** matches the rifleman, low-poly and made in code, in the same style and colours.
- **Animations:**
  - **Wheels and rods:** wheels turn at the right rate for the speed, and the coupling and connecting rods and crossheads move on the engine.
  - **Smoke and steam:** chimney puffs timed to the wheel beats (more when pulling hard), steam at the cylinders, and a whistle plume.
  - **Doors and loading:** the van's sliding doors open and close, with a marked spot for squads getting on and off.
  - **Guns and couplers:** the gun mount turns, aims and recoils. Buffers squash and couplings take up slack as the train starts and stops.
  - **Crashes, all four, at full speed only, for 3, 4 and 5-car trains:**
    1. **Tips onto its side:** hit from the side, or too fast on a curve. The engine rolls and the cars follow, jackknifing.
    2. **Track damaged ahead:** the engine drops off the broken rails and ploughs in, and the cars pile up behind it.
    3. **Blocked ahead:** it hits a tank trap or barricade on the line. Sudden stop, the front crumples, and the cars concertina.
    4. **Blown apart:** the boiler bursts, pieces fly off, and a burning, smoking wreck is left.
  - The crashes are worked out once by a simple solver and **baked into Animations**, so they cost almost nothing in game. They are built on a "car chain", so any later wagon slots in and the same crashes work with any number of cars.
- **For your look:** a gallery of stills (near and far looks), plus short videos: start, run and stop on a short test track; doors and gun; every crash for 3, 4 and 5 cars.

## Files (my paths only; the Question Chat's units paths are left alone)
- scripts/trains/
- tools/train_pictures.gd
- tools/train_videos.gd
- results/trains/
- TRAINS_PLAN.md and TRAINS_REPORT.md

## ETA: about 8-9 h of work

| Step | Time | Total |
|---|---|---|
| Engine and tender model, near and far looks | 1.5 h | 1.5 h |
| Stand-in van and gun flat, couplers and buffers | 0.5 h | 2 h |
| Wheels, rods, smoke and steam | 1.5 h | 3.5 h |
| Doors, the gun mount, coupler slack | 1 h | 4.5 h |
| Crash solver and bake: 4 cases x 3 lengths | 3 h | 7.5 h |
| Gallery, videos, checks and report | 1-1.5 h | 8.5-9 h |

**First stills** of the engine and tender come after about 1.5 h.

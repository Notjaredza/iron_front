# Iron Front: air assets and animations, round 1 (plan)

Asset Builder Chat, 2026-11-09. **Nothing is built until the user says go.**

This round covers the models and their animations only. Flying orders, spotting rules and airfields as buildings are later pieces.

## The user's answers
- **Types: all four.**
  1. **Fighter / scout:** a single-seat biplane with a forward MG. It strafes, fights the flying host and makes fast message drops.
  2. **Two-seat spotter:** a biplane with a pilot, and an observer with a ring-mounted MG. It spots for the guns and drops messages.
  3. **Bomber:** a large twin-engine biplane with bomb racks and front and rear gunners.
  4. **Balloon:** a tethered observation and relay balloon with a basket, a cable and a winch lorry.
- **Look:** the same low-poly, made-in-code style and colours as the rifleman and trains: olive and canvas tones. The roundels are kept generic, with no real nation markings.
- **Animations: all four groups.**
  - **Flying:** propellers spin (a blur disc at speed). The planes bank and turn, climb and dive. The ailerons, elevator and rudder move with the turns.
  - **Weapons:**
    - MG fire with muzzle flash;
    - the observer and rear gunners swing round on their rings;
    - bombs drop from the racks and fall nose-down;
    - message bags drop with a streamer.
  - **Ground:** taxiing, take-off and landing on a field strip (tail-skid down, then tail up), with the propeller starting and stopping. The balloon is winched up and down on its cable.
  - **Damage and crashes:**
    - smoking, then on fire;
    - a spinning dive into the ground;
    - a wing breaking off;
    - a balloon hit, burning, folding and falling, with the crew jumping by parachute.
- **Crashes are baked like the trains:** the physics engine works each crash out once and saves it as ready-made animations (one library per plane type), so playing them in the game is cheap.
- **For your look:** a gallery of stills (near and far looks, and a night picture), plus short videos of every animation group for each type.

## Files (my paths only)
- scripts/air/
- tools/air_pictures.gd, tools/air_videos.gd, tools/air_bake.gd
- assets/air/
- results/air/
- AIR_PLAN.md and AIR_REPORT.md

## ETA: about 10-12 h of work

| Step | Time | Total |
|---|---|---|
| Fighter, spotter and bomber models, near and far looks | 3 h | 3 h |
| Balloon, basket, cable and winch lorry | 1 h | 4 h |
| Flying: propellers, banking, control surfaces, flight paths | 1.5 h | 5.5 h |
| Weapons: MG fire, gunner rings, bombs, message drops | 1.5 h | 7 h |
| Ground: taxi, take-off, landing, winching | 1 h | 8 h |
| Damage and crashes: smoke and fire, spin, wing off, balloon fire, all baked | 2.5 h | 10.5 h |
| Gallery, videos, checks and report | 1-1.5 h | 11.5-12 h |

**First stills** of the three planes come after about 3 h.

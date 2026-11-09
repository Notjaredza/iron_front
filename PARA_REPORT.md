# Iron Front: paratrooper transport, air round 2 (report)

Asset Builder Chat, 2026-11-10. Plan: PARA_PLAN.md. This round covers the models and their animations only. Drop orders, landing zones and unit control come later.

## What was built

### The transport (scripts/air/air_parts.gd, "transport")
- A big biplane in the bomber's style:
  - three engines: one in the nose, two in nacelles between the wings;
  - a boxy cabin with windows down both sides;
  - a sliding door on the left side, plus a short ladder hung from the sill for loading on the ground;
  - twin fins and diamond markings.
- It carries a stick of 12.
- It flies, takes off and lands with the same flight code as the other planes (cruise 34 m/s, stall 19 m/s, 5,600 kg).
- Size: 3,864 triangles up close and 112 for the far look.
- New calls:
  - `set_door(u)`: 0 is shut, 1 is open (the door slides aft along its rail).
  - `mark_world(name)` gives world points for `door_sill`, `door_in`, `line_anchor` and `ladder_foot`, so the game can place men at the door.

### The paratrooper (scripts/air/para.gd, Para)
- The approved rifleman (Soldier, read only), with:
  - a pack on his back and a reserve on his chest;
  - harness straps and risers;
  - a gored canopy (scripts/air/canopy.gd).
- To start a jump, call `jump(velocity, facing, fate, hit_time, burn_time)`, then `step(dt)` each frame. The jump runs:
  1. the exit (the slipstream takes his speed off and he tips forward);
  2. the static line pulls the chute open at 0.9 s;
  3. a swing that dies away;
  4. the descent at 5.4 m/s, drifting downwind;
  5. the landing: crouch, roll onto his side, onto his back, up to a kneel;
  6. he gathers the chute (it lies down downwind, is pulled in, and ends as a bundle at his feet);
  7. he stands with the rifle ready, about 4.6 s after touchdown.
- Fates:
  - `ok`;
  - `streamer`: the chute never opens properly, so he falls fast and lands dead;
  - `ok` with a burn time: the chute burns with flame and smoke, shrinks and blackens, then a hard landing;
  - `hit`: shot hanging in his harness, he goes limp and lands crumpled.

### Supply crates (scripts/air/supply_crate.gd, SupplyCrate)
- Three kinds:
  - ammo: an olive crate with a yellow band and a yellow chute;
  - food: a tan crate with a blue-grey chute;
  - medical: a pale crate with a plain red band and a white chute.
- They fall at 6.5 m/s. On landing they bump and tip, and the chute lies down over the downwind side.

### Crashes
- `transport_spin` and `transport_wing` are baked into assets/air/crashes.res like the other planes:
  - the big-plane settings (slower spin, smaller blast) now go by `AirParts.is_big()`;
  - the check passes for all 9 clips, with a worst gap of 0.0000 m.

## For your look

**Stills (results/air/):**
- transport_three_quarter, transport_side, transport_flying, transport_far, transport_night;
- transport_door (door open, ladder down, men walking up);
- para_hanging, para_ground (five landing stages), para_kit;
- supply_crates.

**Videos (results/air/):**
- para_loading: men walk up, climb the ladder and go in; the ladder comes up, the door shuts, the engines start.
- para_drop: the door opens and 8 men go out 0.8 s apart; the chutes open and they drift down and land.
- para_landing: close up, a man lands, rolls, gathers his chute and stands ready, with two more landing beside him.
- para_supply: five crates pushed out on their coloured chutes, landing.
- para_shot:
  - the first two men go cleanly, then flak bursts and the left engine catches fire;
  - the rest bail out fast, with two streamers and one burning chute;
  - a ground machine gun hits a man in his harness;
  - the transport goes into its baked spin crash beyond the chutes.
- transport_flying, transport_takeoff, transport_landing, transport_spin and transport_wing.

## Notes and open points
- The static line is not drawn yet; the chute just opens 0.9 s after the exit. A line from the anchor to the pack could be added if you want it.
- The men vanish once inside the cabin, which has no interior. They show in the doorway when they jump.
- The flak bursts are smoke puffs from the air effects. The later shells round can replace them.

# Tanks round 1 (Tanks Chat, started 2026-11-09 ~23:40 on "Go"; ETA about 2.5 to 3.5 h)

Two generic WW1-era tanks, not copies of real ones. They are true size, plain olive like the lorry, and built in code
in the faceted unit style. They are built on the troop lorry pattern: a body pivot that rides the ground, moving parts
under it, and per-frame calls.

**Done 2026-11-10 00:20.** It took about 40 minutes against the 2.5 to 3.5 h ETA. **APPROVED by the user ("Looks good").**

## The two kinds

| Kind | What it is |
|---|---|
| `heavy_male` | Rhomboid tank, about 8.3 m long (10 m with the tail) and 2.5 m tall to the frame top. The track runs right round a tall side frame. It has a short gun in each sponson, a driver's cab with a front MG, an unditching beam on rails, a brushwood fascine across the roof and a two-wheel steering tail. Number 214 on the sides, and the tactical sign (white diamond, red bar) on the sides and the cab front. Crew of 8. |
| `heavy_female` | The same tank with a machine gun in each sponson and taller sponsons. Number 209. |
| `light_gun` | Small turret tank, about 4.4 m long (5.2 m with the tail skid). It has a big spoked front idler, six road wheels, return rollers, a side girder, a toothed rear sprocket and a tail skid. The octagonal turret turns right round and has a short gun and a cupola. Number 37 on the turret and the rear, and the sign on the hull sides. Crew of 2. |
| `light_mg` | The same tank with a machine gun in the turret. Number 41. |

## Triangles (from `-- check`)

| | close | mid | far | wreck (close) |
|---|---|---|---|---|
| Heavy (gun) | 7202 | 2266 | 496 | 6494 |
| Heavy (MG) | 7522 | 2478 | 484 | 6814 |
| Light (gun) | 6984 | 2216 | 200 | 6824 |
| Light (MG) | 6880 | 2148 | 228 | 6720 |

For comparison, the troop lorry is about 6600 close and 360 far. About half of the close count is the track links:
each link is a plate plus a grouser bar. The mid look uses links twice as long with no grousers. The far look is a
plain track outline with no wheels.

## Pictures and videos

Pictures are in `results/units/tanks/`:
- `tank_gallery.png`: all ten looks on one sheet.
- `g0..g9_front.png` / `_back.png`: each look from the front and the back. In order: heavy gun, heavy MG, heavy mid, heavy far, heavy wreck, light gun, light MG, light mid, light far, light wreck.

Videos are in `results/units/anim/`:

| Video | What it shows |
|---|---|
| `tank_look_heavy.mp4` | Gun and MG versions close, plus the mid and far looks, turning. The roof hatch and sponson doors open. |
| `tank_look_light.mp4` | Gun and MG versions close, plus the mid and far looks and the wreck, turning. The turret turns and the hatches open. |
| `tank_drive.mp4` | Both tanks over rough ground: the links scroll, the light tank's wheels turn, the hull pitches and rocks, with exhaust and dust. Then each turns on the spot, one track forward and one back. |
| `tank_ramp.mp4` | Up a ramp onto a 3 m terrace beside a cliff edge, then over the top. |
| `tank_trench.mp4` | The heavy crosses a 3.6 m trench: up the parapet, nose down, then climbing out of the far side. The light tank then takes a 1.5 m trench. |
| `tank_fire_heavy.mp4` | Gun version: the sponson guns traverse and fire (recoil, flash, smoke, the hull rocks, dust where shells land). MG version: sponson MG bursts with flicker and spent cases, plus the front MG. |
| `tank_fire_light.mp4` | The turret turns and the gun elevates, then fires (recoil, flash, smoke, pitch kick). The MG version sweeps in bursts. |
| `tank_crew.mp4` | Eight men climb into the heavy through the two sponson doors, which then shut. The light tank's driver goes in through the front hatch and the commander up the back and into the cupola. Engines start (darker exhaust) and both move off. |
| `tank_wreck_heavy.mp4` | Hit in the side: flash, a swap to the burnt hull (one track broken, a gun knocked askew), flames and black smoke. Six men bail out of the doors and the commander climbs out of the roof hatch, jumps down by way of the sponson top, and takes cover. One crewman doesn't get out. The fire then dies to a smoulder. |
| `tank_wreck_light.mp4` | The same for the light tank: the driver gets out of the front hatch and the commander out of the cupola. |

## How it is built

- `scripts/vehicles/tank_builder.gd` holds the meshes:
  - hull, track loop, wheels, sponson guns, turret, gun, hatches, doors and the tail;
  - markings (painted block digits, the sign);
  - wreck palette;
  - shared helpers: `prism` (an outline pushed out), `outline` (the hull round circles), `track` (links along the loop at a phase).
- `scripts/vehicles/tank.gd` is the `Tank` node:
  - `drive(dl, dr)`: each track's distance. The track mesh changes by link phase (8 cached meshes per link), and the wheels turn.
  - `ride(ground_fn, dt)`: rests the tank on the ground under its tracks (and the light tank's tail skid). For each track line it picks the tilt that puts the tank's weight lowest without any track point going under the ground. That is what makes it tip over a trench lip, dip and climb out. A stiff spring on top gives the lurch and a little rock. The heavy's tail follows the ground on its pivot.
  - `set_turret`, `set_elev`, `set_sponson`, `set_recoil`, `set_hatch`, `muzzle_xf`.
- `tools/tank_clips.gd` holds the 11 scenes. It extends the lorry clip tool, reusing its puffs, mounds and men. Run `-- check` for the headless check.
- The crew are the gunner-role men (no rifle, pistol holster, gloves) and use the shared vehicle moves (`clips_vehicle.gd`: climb, stooped, crouch, airborne).

## Checks

- `Godot --headless --path iron_front -s res://tools/tank_clips.gd -- check` runs these tests:
  - every kind, look and wreck builds;
  - each tank rests level on flat ground;
  - all 8 track phases build;
  - the muzzles are where they should be;
  - every hatch opens.

  Result: **TANK CHECK OK**.
- One `ride()` costs 0.60 ms (heavy) and 0.77 ms (light) per call on the laptop.

## Not done yet / known small things

- The tanks are not yet tied to real move orders on the map.
- `ride()` is fine for a few tanks, but dozens moving at once would cost several milliseconds a frame. In the game it should run only for close tanks, with mid and far tanks just following the ground height.
- On the heavy, the side frame hides the road wheels, as on the real rhomboid tanks, so only the links show that it is driving.
- Tank crew wear the same helmet as the infantry (no leather tanker helmets).
- The crew place their hands roughly on the door edges and hatch rims; the climbs are short and readable rather than exact.
- Getting stuck (ditching) and the unditching beam in use are left for later, as agreed.

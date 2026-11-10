# Iron Front: the General (report)

Asset Builder Chat, 2026-11-10, about 06:00 to 07:35. The plan is GENERAL_PLAN.md. **This waits for the user's look.**

He's an original, made-up strongman, built on the approved officer. The badge and the banners carry a plain gold star in a wreath, so there are no real-world symbols. His face is not a likeness of anyone.

## The General (scripts/units/general/general_kit.gd)
`GeneralKit.general(lod)` gives a normal Soldier node with the same skeleton, poses and clips as the officer. Only the mesh differs.

**Cap and face:**
- a tall peaked cap with a red band, a gold visor braid and chin cord, and a big gold star badge;
- a heavy moustache with drooping ends, and hard brows pulled down.

**Uniform:**
- a dressed-up olive tunic with red collar tabs;
- gold epaulettes with a gold fringe, and a gold aiguillette;
- a red sash from the right shoulder to the left hip;
- three rows of ribbons, four hanging medals, and a great star on the right breast;
- breeches with a red stripe, and polished black boots.

**Greatcoat:** dark, worn over the shoulders like a cape. It's open at the front and lined in red, with a stand-up collar and a gold chain across the front.

**Stick:** a swagger stick in the left hand.

**Detail levels:**

| Look | Triangles |
|---|---|
| Near | 2,706 |
| Mid | 1,274 |
| Far | 360 (cap, coat and gold flashes as blocks) |

## The bodyguards
`GeneralKit.guard(seed, lod)` gives our approved riflemen, smartened up:
- a white waist belt and a white cross strap, with no webbing and no pack;
- a red-white-red armband;
- a fixed bayonet.

A near guard is 942 triangles.

## Moves (scripts/units/general/clips_general.gd)
- **Standing:** chest out, chin up, heels together.
- **Parade walk:** a stiff, slow step, hands clasped behind his back.
- **Inspect:** hands behind his back, head turning and nodding.
- **Salute:** right hand at the brow, elbow out.
- **Speech:**
  - fists on the lectern;
  - pounding the lectern;
  - pointing out over the crowd;
  - the arm sweep;
  - the raised fist.
- **Powers** (these are poses only; the logic comes later):
  - **Rally aura:** the arm sweep, then the raised fist.
  - **Call in fire, flare:** he raises a flare pistol and fires a red flare that climbs and hangs.
  - **Call in fire, bark:** he points at the target with a hand cupped to his mouth, then jabs the stick at the nearest signaller (who is on the phone).
  - **No retreat:** feet planted wide, the stick pointed down at the ground he holds.
- **Wounded:**
  - he's hit (a hand to the chest) and falls;
  - two guards stoop, lift him by the shoulders and legs, and carry him off;
  - he recovers at the HQ sick bay, like the officer.
- **Guards:** standing at order arms, walking at port arms at his pace, stooping, and carrying.
- **In the car:** standing in the back with one hand on the rail, waving, and taking a salute.

## Props
- **Podium:** a raised platform with steps, and a lectern draped in red with a gold star. Two tall red banners stand behind it with gold borders and a star-in-wreath.
- **Staff car:** the HQ staff car with the hood folded down, a gold grab rail to stand at, and red pennants on the wings.
- **Flare pistol:** a wide brass barrel.

## Pictures (results/general/, git-ignored)
**Stills:**
- `gen_turn`: back, side, three-quarter and front;
- `gen_face`;
- `gen_lods`;
- `gen_poses_a` and `gen_poses_b`. The screen order runs right to left, because the camera looks from the front:
  - a: inspect, salute, point, sweep, raised fist, flare;
  - b: bark, stick jab, no retreat, hurt, pound, lying;
- `gen_guards`, `gen_guard_close`, `gen_escort`;
- `gen_podium`, `gen_car`.

**Clips:** made by tools/gen_clips.gd, each as an mp4 plus a `_sheet` contact sheet:
- `gen_inspect`: the parade walk with the escort, inspecting, taking the salute;
- `gen_speech`: at the podium;
- `gen_powers`: rally, flare, bark at the signaller, no retreat;
- `gen_wounded`: hit, lifted and carried off;
- `gen_car`: the car drives in, he waves, it stops and he salutes.

`gen_flare_sheet` is a close look at the flare.

## Things to know
- **Stick:** it's built into the left hand, so it turns with the hand. When his arm comes up, the stick points up. The rig has no wrist turn, so the poses aim the forearm instead.
- **Greatcoat:** it rides the chest bone. When an arm comes up, the arm pokes out from under it, as it would with a coat worn over the shoulders.
- **Carrying:** while he's carried, his body follows a position set by the clip tool (`pos_fn`). In the game the carry would follow the two guards.

## Files
- scripts/units/general/general_kit.gd and clips_general.gd
- tools/gen_pictures.gd and gen_clips.gd
- GENERAL_PLAN.md and this report

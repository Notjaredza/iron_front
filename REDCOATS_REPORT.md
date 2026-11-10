# Red jackets, round 1 (Building Chat 1, 2026-11-10)

**APPROVED by the user 2026-11-10 00:37.**

The first enemy type: musket-era line infantry, "a few red jackets", in the troops' faceted low-poly look.
They are plain living soldiers. The test field comes in a later round; this round is pictures and clips.

## What is built
- **Four figures** on the soldier skeleton (same bones and rest pose as our rifleman, so every body move, death and
  blast throw works on them):
  - **Musketeer:** tricorne laced white, red coat with buff lapels and cuffs, white lace, white waistcoat and breeches,
    black gaiters, white cross-belts with a brass plate, cartridge box, bayonet scabbard, haversack, canteen, some
    with a knapsack and blanket. Musket with its bayonet fixed (walnut stock, brass fittings, lock and cock, sling).
    Faces, hair (with the queue), builds and kit vary man to man.
  - **Officer:** scarlet coat with gold lace, gold epaulette, crimson sash with tassels, gilt gorget, tall boots,
    a drawn sword and its scabbard.
  - **Drummer:** "reversed colours" (a buff coat with red facings), laced sleeves, the drum on the left thigh with
    its red hoops and white cords, a stick in each hand.
  - **Ensign:** officer's coat, sash and gorget, the colour belt with its socket; a 3 m pole with a brass spear-head
    and gold cords, and the colour (a generic regimental colour: buff field, red border, red roundel in a gold
    ring). The cloth is its own mesh and waves in faceted folds (shaders/flag_wave.gdshader).
  - Close, mid and far meshes for each.
- **Moves** (scripts/units/anim/clips_musket.gd), 47 clips:
  - march with shouldered arms (right arm swinging); the officer, drummer (beating the step) and ensign march too;
  - the volley: make ready, present, fire, for a kneeling front rank and a standing rear rank. The flash in the pan,
    then the shot: a tongue of flame and a thick bank of white smoke that hangs for 7-12 s and drifts (new blast
    kinds "pan" and "musket", the same faceted billows as the explosions);
  - the long reload, about 18 s: half cock, open the pan, cartridge from the box, bite it, prime, shut the pan,
    cast about, pour, draw the rammer (two pulls), turn it, ram it home in three strokes and two taps, draw it, turn
    it back, return it, make ready. The rammer and the cartridge are their own props and move with the hand;
  - charge bayonets, the charge run, the thrust;
  - the officer raises his sword and cuts down for "fire!", leads the charge, waves the men on;
  - the drummer's long roll;
  - hit, death falling back, death falling forward, getting up, for every role;
  - blast throws: BlastThrow now plays a man's own deaths and get-up, so shells throw red jackets as they throw ours.

## Files
- scripts/units/redcoat_builder.gd (RedcoatBuilder), scripts/units/redcoat.gd (Redcoat, a Soldier),
  scripts/units/anim/clips_musket.gd, shaders/flag_wave.gdshader.
- scripts/fx/blast_kinds.gd: "musket" and "pan"; scripts/fx/blast_throw.gd: a man's own clips.
- tools/redcoat_pictures.gd (pictures), tools/redcoat_clips.gd (videos), tools/redcoat_check.gd (headless check).

## Pictures and clips
- results/units/redcoats/: look_front, look_three_quarter, look_back, line_shouldered, closeups, lods, pose_*.
- results/units/redcoats/*.mp4: march, volley, reload, charge, deaths.

## Numbers
- Triangles, close / mid / far: musketeer 2063 / ~740 / ~260, officer 1568 / ~660 / ~300, drummer 2032 / ~700 / ~240,
  ensign 1678 / ~700 / ~270 (plus the colour's cloth, 1144 close, 160 mid). The close look is about twice our
  rifleman's, from the lace, buttons and belts; the mid and far looks are what a crowd uses.
- Video recording ran at 10-25 fps with a whole company and the smoke; no frame-rate bench was booked this round.

## Not done yet, for later
- The test field (a playable scene) and real orders (the user chose pictures and clips first).
- A grenadier (left out of this round by the user's choice).
- No sounds yet (musket volley, drum, the officer's word of command).
- The close mesh could lose some lace if crowds of red jackets cost too much.

---

# Red coats, round 2 (Building Chat 1, 2026-11-10, built by about 01:11)

**APPROVED by the user 2026-11-10 05:57.**

More troops for the red coats, each fighting its own way. Plain soldiers, no strange tech. **Pictures and move sheets only**
(the user: "pics to save time"), so there are no videos and no test field this round.

## What is built
- **Grenadiers:** taller men in a red mitre cap with a front plate in the facing colour, a white badge and a tuft, laced
  shoulder wings, a grenade pouch and a brass match case on the belt. Musket and bayonet as the line.
  - **Move:** the grenade throw (3.6 s). The musket is slung on his back, he takes the grenade from the pouch and lights the
    fuse at the match case (the spark shows), winds up, throws overarm and follows through. The clip has a "throw" event
    for a later thrown-grenade effect.
  - Grenadiers lead the bayonet charge with the line's own charge clips.
- **Light infantry:** smaller men, green facings, a low black leather cap with its front turned up and a green tuft, short
  coat tails, a powder horn, no knapsack.
  - **Moves:** fire from behind cover (crouched, up on one knee, aim, fire with the musket's flash and smoke, down again,
    start priming), the low skirmish run with the musket trailed, and firing lying down.
- **Field gun and crew:**
  - **The gun:** a bronze 6-pounder on a lead-grey carriage (cheeks, trail, axle tree, ammunition boxes, two 12-spoke
    wheels with iron tyres). The barrel elevates on its trunnions, the gun recoils and the wheels turn as it rolls.
  - **The crew (blue facings, waist belts):** sponge man with a 2.4 m sponge and rammer staff, loader with the round (bag
    and ball), vent man, layer at the trail with a handspike, and the firer with a linstock and its glowing match.
  - **The drill, as 8 stills:** sponge, load, ram home, prick and prime, lay the gun, fire (the vent's flash, a big muzzle
    flame and a bank of smoke: the new "cannon" blast kind, about 2.6 times the musket's), recoil (the gun thrown back
    1.25 m), run up again. Each man's hands sit on the gun's own points (muzzle, vent, trail, wheels).
- **Dragoons:** a brass-combed black leather helmet with a horsehair crest, buff-yellow facings, tall boots, a white
  waist belt and carbine belt, and a sabre.
  - **New horse model,** with its own skeleton (17 bones): bay, black or chestnut, a saddle cloth in the facing colour
    edged in lace, saddle, holsters, rolled cloak, stirrups and bridle.
  - **Gaits** worked out by phase: walk (four beats), trot (diagonal pairs), gallop, and the charge (flat out, head low).
    The horse can also rear and fall onto its side.
  - **The rider** sits in the saddle with his left hand on the reins. Sabre moves: carry, raise, cut, and point (for the
    charge). In the fall he is thrown forward and lands with the officer's forward death.
- **Shared moves:** the new men share the deaths and blast throws. Grenadiers and light infantry use the line's; dragoons
  on foot use the officer's; the gunners have their own, where the tool falls with the hand.

## Files
- New: scripts/units/redcoat_cannon.gd (FieldCannon), scripts/units/redcoat_horse.gd (Horse),
  scripts/units/anim/clips_redcoat2.gd (round 2 moves), tools/redcoat2_pictures.gd.
- Changed: scripts/units/redcoat_builder.gd (new roles, hats, kit, gunner tools, the grenade and the round),
  scripts/units/redcoat.gd (grenade and round props, round 2 poses and clips), scripts/fx/blast_kinds.gd (the "cannon"
  kind), tools/redcoat_check.gd.

## Pictures (results/units/redcoats/)
| File | What it shows |
|---|---|
| r2_look_front, r2_look_three_quarter, r2_look_back | the new men from three sides |
| r2_closeups | the three hats and the grenadier's kit |
| r2_lods | close, mid and far meshes |
| r2_drill | the 8-step gun drill |
| r2_cannon | the gun from four sides |
| r2_sheet_grenadier_throw | grenade throw sheet |
| r2_sheet_light_fire | firing from cover sheet |
| r2_sheet_light_run | skirmish run sheet |
| r2_sheet_light_prone_fire | firing lying down sheet |
| r2_horses | the three horse coats |
| r2_sheet_horse_walk, _trot, _gallop, _charge | the gaits with a rider |
| r2_sabre | sabre carry, raise, cut, point |
| r2_rear_fall | rearing, and the fall with the rider thrown |
| r2_dragoon_close | the dragoon close up |
| r2_cavalry_charge, r2_cavalry_side | a troop charging |

## Numbers (triangles, close / mid / far)
| Unit | Close | Mid | Far |
|---|---|---|---|
| Grenadier | 2165 | 744 | 260 |
| Light infantry | 2015 | 688 | 260 |
| Dragoon | 1588 | 700 | 284 |
| Gunner | about 1600-1700 | about 570-660 | about 220-270 |
| Horse | 984 | — | — |
| Gun | about 1900 | — | — |

The horse and the gun have one mesh each so far; neither has a mid or far mesh yet.

## Rough edges, for later
- The run-up still is rough: the men pushing the wheels use the plain running pose.
- The gun drill is stills only. It has no timed clip yet, so there are no videos and nothing for the test field.
- The horse's hooves can slide a little in the gaits; the gaits are worked out by phase, not with foot IK.
- There is no thrown-grenade flight or burst yet (the clip only marks the "throw" moment).
- No sounds yet.

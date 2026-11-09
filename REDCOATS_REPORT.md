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

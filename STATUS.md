# Iron Front status

## Tanks round (Tanks Chat)
- 2026-11-09 ~23:40: answers in, ETA about 2.5 to 3.5 h. Started on "Go".
- 2026-11-10 00:20: BUILT (about 40 min). APPROVED by the user ("Looks good"). Details are in TANKS_REPORT.md.
- Kinds: heavy rhomboid (gun and MG versions) and light turret tank (gun and MG versions). Each has close, mid and far looks plus a wreck.
- Videos: results/units/anim/tank_*.mp4 (10). Pictures: results/units/tanks/ (tank_gallery.png plus front and back of each look).
- Not done: ditching, tying the tanks to real move orders, tanker helmets.

## Rocket lorry round (Tanks Chat), answers taken 2026-11-10 ~00:30
- State: "Go" ~00:24; BUILT 2026-11-10 00:46 (about 25 min). APPROVED by the user (00:52, after the lying-down fix) and committed. Details in ROCKET_REPORT.md. Videos: results/units/anim/rocket_*.mp4 (7). Pictures: results/units/rockets/. Check: ROCKET CHECK OK (salvo lands 198-258 m).
- 00:49: the user says it is good except for the men lying down weirdly. Fix chosen: no one lies down. The men in cover in the fire clip crouch, and the running crew in the wreck clip kneel when they stop. On "Go", done 00:50: fire and wreck clips re-rendered.
- A generic lorry-mounted rocket rack, built on the troop lorry: no tilt or benches, a blast shield behind the cab, an open lattice frame of about 12-16 steel launch rails on a turntable on the bed. Crew of 4 (an NCO and 3 men).
- Moves: park, set up (level, raise and turn the rails) and pack up; load (rockets carried from a box and slid onto the rails); ripple salvo (fire trails, a smoke cloud, dust thrown up behind), rockets in flight on arcs landing about 150-250 m out in a spread of blasts, all in one shot; hit (rockets cooking off, burning wreck, crew running).
- Close, mid and far looks plus the wreck, all in one go, one look at the end.
- ETA once the user says go: about 1 to 2 h.

## Red jackets round 1 (Building Chat 1), go 2026-11-10 ~00:05
- The first enemy type: musket-era line infantry in the troops' faceted look. Musketeer, officer, drummer, ensign (flag).
- Moves: march, volley (kneeling front rank, standing rear rank), the long reload (~18 s), bayonet charge and thrust, deaths and blast throws.
- BUILT 2026-11-10 ~00:36 (fb7be6f), approved 00:37, well under the 5 h ETA; APPROVED by the user. Pictures and clips in results/units/redcoats/. Report: REDCOATS_REPORT.md.
- Shells-in-flight round PAUSED by the user until the other chats' effect assets are in.

## Red coats round 2 (Building Chat 1), go 2026-11-10 ~00:50, ETA about 2-4 h (by ~03:00-04:50)
- Grenadiers (mitre caps, lit grenades), light infantry (skirmish: cover, kneel, fire, low runs, prone), a 6-pounder field gun and its five-man crew (the drill: sponge, load, ram, prime, lay, fire, recoil, run up), dragoons on a new horse model (walk, trot, gallop, charge, rear, fall; sabre carry, raise, cut, point).
- Pictures and move sheets only (the user: "pics to save time"). BUILT 2026-11-10 ~01:11 (3d5d5f4), APPROVED by the user 05:57. Report: REDCOATS_REPORT.md (round 2 section).

## Red coats vs our troops: fights (Building Chat 1), go 2026-11-10 ~07:55, ETA about 2-3 h
- Charge clash, three melee duels, storming a trench, dragoons riding in. Pictures only, mixed outcomes, blast-style hits and falls (no blood).
- BUILT 2026-11-10 08:05 (7290e32), APPROVED by the user 08:06. Sheets: results/units/redcoats/fight_*.png. Report: REDCOATS_REPORT.md (Fights section).

## Armoured melee troops (Building Chat 1), go 2026-11-10 ~08:10, ETA about 3-4 h (by ~11:10-12:10)
- Our side: full heavy WW1 trench armour (plates, brow-plate visor helmet), tall slit shields, trench clubs / maces / spades, pistol back-up.
- Moves: heavy walk, shield wall lock and step-push, strikes over the shields, break into the rush, swings, shield block and bash, pistol, hits, deaths, blast throws.
- Output: move sheets, five short videos (wall, rush, strikes, pistol, battle vs red coats), battle stills. BUILT 2026-11-10 08:39 (445a2e6), well under the ETA; APPROVED by the user 08:41. Files in results/units/armour/. Report: ARMOUR_REPORT.md.

## Engineers: workers and crew (Building Chat 1), go 2026-11-10 17:04, ETA about 1.5-2.5 h (by ~18:35-19:35)
- A section of 4 (NCO with the plan, 3 sappers, rifles slung). Kit: pick + shovel, mallet + stakes, saw + hammer + planks, wire cutters + coil.
- Jobs: dig a trench, build a plank wall, barbed wire, strip a wreck, track repair. The work grows as they work. Pictures only (look + move sheets).
- BUILT 2026-11-10 17:24 (about 20 min). Sheets in results/units/engineers/ (look, moves, dig, build, wire, wreck, track). Report: ENGINEERS_REPORT.md. APPROVED by the user 17:31.

## Medieval host: the ancient enemy (Building Chat 1), go 2026-11-10 18:10, ETA about 3-4 h (by ~21:10-22:10)
- Foot core (men-at-arms, spearmen, crossbow + pavise, longbow, captain, banner), heavy shock troops (two-hander, pole-axe/halberd), rabble levy, knights on barded horses + light horse scout.
- Bright heraldry: per-man tinctures, divisions and charges; several lords' banners.
- Moves, formations (shield wall, spear hedge, archer stakes), knight charge, fights vs our troops. Pictures and videos.
- BUILT 2026-11-10 18:37 (about 30 min). Pictures in results/units/medieval/ (med_look, med_close, med_moves_foot/missile/heavy/falls, med_formations, med_knights, med_fights). Videos: med_host, med_volley, med_charge, med_melee, med_battle (.mp4). Report: MEDIEVAL_REPORT.md. APPROVED by the user 18:43.

## Medieval siege equipment (Building Chat 1), go 2026-11-10 19:02, ETA about 1-1.5 h
- Trebuchet, mangonel, ballista, siege tower, roofed ram, scaling ladders, mantlets, fascines; full crew work. Pictures only.
- BUILT 19:30 (about 30 min): SiegeEngine / siege_builder.gd / clips_siege.gd, tools/siege_pictures.gd, SIEGE_REPORT.md. Pictures: results/units/medieval/siege_*.png. Waits for the user's look.

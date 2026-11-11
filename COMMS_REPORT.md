# Comms report: the officer and the first comms (design step 3)

## Round 1 (2026-11-11)
The user picked Option A and left the details to the suggestions:
1. The officer is the approved officer model, with two guards who carry him when he is hit.
2. Orders are instant within about 150 m of him. Further out they travel by runner or telegraph wire.
3. Only runners and wire this round. Lamps, pigeons, dogs and dispatch riders come later.

## How it plays
- **The officer (you)** starts behind the rifle squads with two guards. Select him and move him like any squad. He doesn't fire, but his guards do.
- **Near him (150 m):**
  - orders are taken at once;
  - squads shoot steadier, with a quarter more hits;
  - they are harder to pin, taking a third less shaking from fire.
- **Further away, every order has to be carried.** The game picks the quickest way:
  - **Runner:** a signaller (blue and white armband) runs from the officer to the squad. He can be shot on the way, and then another is sent. A runner over 400 m takes about 2 minutes.
  - **Runner post** (and the HQ): fresh runners. From there they run a third faster, and a runner reaching a post hands the order to a fresh man.
  - **Telegraph wire:** choose **Telegraph wire** in the build menu's Comms tab, click the HQ or a telegraph post, then another (up to 600 m; Shift keeps going). Poles go up every 30 m with the wire strung between them. Once both ends are finished, the officer hands an order in at a wired point near him, it goes down the wire in a few seconds, and a runner takes it the last stretch. Over the same 400 m: about 10 s instead of 2 minutes.
- **While an order is on its way** the squad goes on with its last order. Its card and banner say "order coming (40 s)", then "order in". If a newer order gets there first, the older one is dropped when it arrives late.
- **Every kind of order goes this way:** moving, drawn lines, attacking, manning posts, going into houses, engineers' building jobs, and the Run/Walk switch.
- **Wire gets cut** by shells bursting near it, and by enemies fighting or walking across it. A cut shows "WIRE CUT" on the map and a hanging break. Select engineers and right click the break: they walk out and splice it (10 s of work). Orders that were heading down a cut wire find another way.
- **Reports come back** the same way, from the squad to the officer:
  - enemy in sight (which band, how far, which way);
  - under fire;
  - men lost;
  - out of ammo;
  - a squad wiped out.

  They show at the top right when they arrive, with how late they are, and an "!" on the map where it happened. Reports from near the officer arrive at once.
- **The officer hit:**
  - Hit once, he is wounded. His guards carry him (shoulders and legs) to the nearest finished HQ or barracks, and he recovers there in 60 s.
  - With no HQ or barracks, or no one left to carry him, he lies where he fell and recovers in 90 s.
  - While wounded he takes no orders.
  - Hit again while wounded, he dies and **the run is over**. A panel shows how long you held, enemies killed and waves beaten off. N starts a new map.
- **O shows the comms map:**
  - the officer's 150 m reach (yellow ring);
  - the wired points and runner posts;
  - the wires (blue when working, red with a cross when cut);
  - each runner's way;
  - each order travelling down the wire as a pulse.

## Built
- `scripts/comms/comms_control.gd` (new): the officer, sending orders, finding the quickest way, runners, wire (laying, poles, cuts, splicing), reports, the officer wounded and dead, the comms map and the end-of-run panel.
- `scripts/combat/troop_kinds.gd`: a new "officer" kind: the approved officer model and clips (walk, run, stand, hit, deaths), and the General's lying and carry clips for the guards (used read only).
- `scripts/squads/squad.gd`: the carry (two guards front and rear, the officer lying between them at their hands' height), the "order coming" banner tag, and each man's role remembered.
- `scripts/squads/squad_control.gd`: every order goes through `dispatch` to the comms; right click on a cut wire with engineers; the wounded officer takes no orders.
- `scripts/combat/combat_control.gd`: the steadier-near-the-officer bonus, the officer's hit going to the comms, shells cutting wire, deaths counted by side, and waves counted as beaten off when their last man falls.
- `scripts/build/build_control.gd`, `build_menu.gd`: the Telegraph wire tool in the Comms tab, and engineers' building jobs sent as orders.
- `scripts/squads/unit_cards.gd`: the card shows "order coming" and "order in", and the Run/Walk switch is an order.
- `scripts/main.gd`: makes the comms and puts the officer on each new map.

## Checks
- `tools/check_comms.gd` (headless): 45 checks, all passing on map seeds 1, 2 and 3:
  - the officer and guards;
  - instant near and late far;
  - arrival about when the card says;
  - a newer order beats an older one;
  - wire much faster;
  - a shell cuts it, and engineers splice it;
  - runner posts are faster;
  - a runner is shot and another is sent;
  - reports arrive late from far and at once from near;
  - steadier and calmer near the officer;
  - wounded, carried, recovered, then dead and the run over;
  - waves beaten off counted.
- The earlier checks still pass: check_squads, check_controls, check_build, check_combat, check_combat2.

## Pictures (results/comms/, git-ignored)
`comms_officer`, `comms_runner`, `comms_map`, `comms_wire`, `comms_cut`, `comms_cards`, `comms_carried`, `comms_over`. Made by `tools/comms_shots.gd`.

## Not done yet
- What you see of the enemy still updates at once. Only the reports are late. Making the map itself wait for reports could be a later option.
- Wire is laid at once, with no linemen walking it out. Linemen lay and mend it in a later round.
- Lamps, pigeons, dogs, dispatch riders, field phones and forward HQs.
- The officer has no powers yet (rally, calling in fire, no retreat). The General's poses for them are ready.
- No costs yet (supply comes with the waves round).

# Recruitment report (recruitment round)

## Round 1 (2026-11-11)
The user said "Go for all":
- recruiting at the barracks and HQ;
- linemen who lay the wire;
- chained orders;
- the officer's powers;
- the single "supply" number.

Waves stay with the other session. Tanks and the rocket lorry are left for a later round.

## How it plays
- **Supply** shows at the top of the screen.
  - A run starts with 900. It comes in by itself at 0.5 a second.
  - Finished buildings add more each second: HQ +1, each depot +1.5, each station +1, each halt +0.5.
  - **Building costs supply.** The build menu shows each price, and lines are priced per piece. Some examples:

    | Building | Cost |
    |---|---|
    | HQ | 300 |
    | Barracks | 200 |
    | Depot | 150 |
    | Telegraph post | 60 |
    | Runner post | 40 |
    | MG nest | 50 |
    | Gun pit | 80 |
    | Sandbags (per piece) | 5 |
    | Wall (per piece) | 12 |
  - A ghost you can't pay for shows red.
  - Cancelling a building before it's finished gives the supply back. Taking one down gives half back.
- **Recruiting:** click a finished barracks or HQ. A panel at the bottom right shows what it trains.
  - Click a unit to queue it (up to 5). It's paid for then.
  - Click a queued unit to take it off the queue and get the supply back.
  - One unit trains at a time, with a bar showing progress.
  - With the building selected, right-click the ground to set its **rally point** (a yellow flag). New squads walk there.

| Unit | Where | Cost | Time | Men | What it does |
|---|---|---|---|---|---|
| Rifle squad | Barracks | 100 | 45 s | 12 | as before |
| Assault section | Barracks | 140 | 50 s | 8 | NCO, five carbines, two trench clubs. Short range (80 m), deadly hand to hand, throws grenades at enemies within 30 m (three a man) |
| LMG team | Barracks | 120 | 40 s | 4 | The gunner lies behind his gun and fires bursts (220 m) that pin hard. A drum carrier and two riflemen go with him |
| Sniper pair | Barracks | 90 | 35 s | 2 | The marksman (320 m, very accurate) picks out officers, NCOs, banners and gun crews first. The spotter sees half as far again. Both lie prone |
| Mortar crew | Barracks | 150 | 55 s | 3 | Sets up after 4 s halted (the mortar appears). Lobs a bomb every 8 s at enemies anyone of ours can see, 60–400 m off. 30 bombs, refilled at a depot or HQ. Packs up when it moves |
| Engineer section | HQ | 60 | 30 s | 4 | as before |
| Linemen | HQ | 40 | 25 s | 2 | Lay telegraph wire and mend cuts |

- **Linemen lay the wire.**
  - The Telegraph wire tool now *plans* a wire, shown grey on the comms map.
  - The nearest free linemen walk to its first end, then out along it. Poles go up behind them as they go.
  - The wire works once they reach the far end.
  - If the ground forces them a long way round, the poles wait until they're back near the line.
  - Free linemen also walk out to mend cuts by themselves. Engineers can still mend cuts when ordered.
- **Chained orders:** Shift+right-click adds a point to the selected squads' route, and they go through each in turn. A dotted line shows the chain while selected. A plain order clears it. Chained orders go through the comms like any order.
- **The officer's powers** are buttons on his unit card, or the keys Z and U:
  - **Rally:** squads within 150 m stop being pinned and shake off the fire at once. He sweeps his arm and raises his fist. Can be used every 90 s.
  - **Hold the line:** for 30 s, squads within 150 m fire faster (waits ×0.6) and can't be pinned. He plants his feet. Can be used every 120 s.

## Built
- `scripts/recruit/recruit_control.gd` (new):
  - supply and income;
  - prices;
  - the recruit panel;
  - queues and training;
  - rally points;
  - the supply line at the top of the screen.
- `scripts/combat/troop_kinds.gd`:
  - the five new kinds (assault, lmg, snipers, mortar, linemen), using the approved troop-type models with the rifle's moves, plus kneeling and the grenade throw made from the troop poses;
  - each man's own firing numbers;
  - the officer's rally and hold clips (the General's poses).
- `scripts/combat/combat_control.gd`:
  - each man's own numbers (LMG bursts, the marksman);
  - the marksman picking leaders;
  - the spotter's sight;
  - grenades;
  - mortars (the approved mortar kit shows when set up);
  - hold the line;
  - refilling by each man's own pouch.
- `scripts/comms/comms_control.gd`:
  - linemen laying planned wire and mending cuts;
  - Rally and Hold the line.
- `scripts/squads/squad.gd`: chained orders (queue, dotted route), the mortar's set-up stance, each man's own ammo.
- `scripts/squads/squad_control.gd`: Shift+right-click chains moves.
- `scripts/squads/unit_cards.gd`: the officer's Rally and Hold buttons with their waits.
- `scripts/build/build_control.gd`, `build_menu.gd`: building costs supply (red ghost when you can't pay, refunds), prices on the menu.
- `scripts/main.gd`: makes the RecruitControl.
- A small fix: the wounded no longer trip over a body that has been cleared away.

## Checks
- `tools/check_recruit.gd` (headless): 49 checks, all passing on map seeds 1, 2 and 3. It covers:
  - supply and refunds;
  - the queue, the training time and the rally point;
  - each new unit's men and moves;
  - LMG bursts (98 rounds to a rifleman's 5 in 30 s);
  - the marksman picks the officer first;
  - the spotter sees 340 m;
  - grenades thrown and hurting;
  - the mortar setting up, firing and using bombs, and packing up on the move;
  - linemen laying wire and mending a cut;
  - chained orders;
  - Rally and Hold the line.
- The earlier checks still pass: check_comms, check_squads, check_controls, check_build, check_combat, check_combat2.

## Pictures (results/recruit/, git-ignored)
`recruit_panel`, `recruit_troops`, `recruit_fight`, `recruit_mortar`, `recruit_linemen`, `recruit_chain`, `recruit_officer`. Made by `tools/recruit_shots.gd`.

## Not done yet
- Tanks and the rocket lorry (they need their own driving and fighting rules).
- Trains bringing new squads from the barracks, as in the design.
- The grenade isn't seen in flight (only the burst), and the mortar bomb rises as a flash and smoke trail only.
- The assault NCO fires his pistol with the rifle's moves.
- Prices and times are first guesses, to be tuned with the waves.

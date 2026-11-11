# Combat report

## Round 1 (2026-11-11)
The user's answers:
1. Each enemy type fights its own way.
2. A key spawns each wave, for now.
3. Squads fire on their own at enemies in range (Company of Heroes style); a right click on an enemy attacks it.
4. In this round: (a) shooting, hits and deaths, (b) cover, (d) pinned, (e) hand to hand. Ammo and wounded men come later.
5. MG nests and gun pits can be manned in this round.
6. This is the first combat session.

## How it plays
- **J, K, L** send a wave from the north, 280 m beyond the camera's spot:
  - J: two red coat companies of 12 (an officer, drummer and ensign with each);
  - K: the medieval host (two foot bands of 12 and 9 archers);
  - L: a zombie horde (three shambler packs, 8 runners, 3 brutes).
  - A wave only starts where the walk in is fairly direct (under 1.6 times the straight line). Otherwise it comes round from the north-east or north-west.
- **Our squads fire on their own** at the nearest enemy squad in range while they stand still (rifles 150 m). Each man aims at one man of that squad and plays his fire and reload moves. Rifle fire is aimed: about a round every 4-6 s.
- **Right click an enemy** and the selected squads attack it: they close to range and fire. Any move order cancels the attack.
- **Cover:**
  - Behind finished sandbags, walls, MG nests or gun pits a man is hit about a third as often.
  - In woods, tall grass or a hedge, a bit over half as often.
  - Lying down (pinned), half again.
  - Inside a post, about a seventh as often.
  - Range matters too: up to 25% of range a shot is at full chance, falling to a quarter at full range.
  - A running target is hit less, and a pinned shooter hits less.
- **Pinned:** every shot at a squad shakes it, hit or not. Past a point it is pinned:
  - It stops, even on an order. Our rifles go prone; red coats and engineers kneel. It shoots worse.
  - It frees itself once the fire stops.
  - Medieval men, archers and zombies are never pinned.
- **Hand to hand:**
  - Men within reach of an enemy man go for him and strike: our bayonets, red coat bayonets, swords, spears, polearms, claws and bites. Each blow kills by its kind's chance.
  - Zombies take two hits; a brute takes four. The host's men-at-arms, heavies and captains are armoured and take two. A shell kills anything.
  - Our squads can walk away from a fight when ordered.
- **Each enemy its own way:**
  - **Red coats** march up in line, halt at about 60 m (round 2; it was 75 m) and fire a volley with smoke. Then they fix bayonets and charge through the smoke, at once if we come close.
  - **Medieval foot** march up, run the last 60 m and fight hand to hand.
  - **Archers** march to bow range (about 110 m), halt and shoot.
  - **Zombies** head straight for the nearest men. Runners run, and brutes charge the last 30 m.
- **Posts:**
  - Right click a finished MG nest or gun pit with a rifle squad selected and it mans the post. Its men go inside and the post's own crew models show.
  - The **MG** fires 8 rounds a second with tracers at the nearest enemy within 220 m.
  - The **gun pit** fires a shell every 7 s at enemies 70-500 m away. Men near the burst fall, and squads within 25 m are pinned.
  - A move order brings the squad out.
- **The fallen** lie where they fell, playing their own death moves, for two minutes.
- Enemy banners are red. Our banners add PINNED, "hand to hand" or "in the MG nest" (or the house).

## Check
- **tools/check_combat.gd** covers:
  - every kind's clips are all there;
  - cover (open, woods, sandbags, prone);
  - pinned (stops, goes prone, frees itself);
  - red coats halt (about 63 m now), fire, charge and reach hand to hand, with men falling on both sides and the bookkeeping right;
  - zombies take two hits and get in close;
  - archers halt at about 108 m and shoot, and the foot reach hand to hand;
  - an MG nest manned and firing, and leaving it;
  - a shell's kills and shock.
  - Seeds 1-3, and repeat runs: COMBAT CHECK DONE 0. The squad, building and controls checks still pass.
- **tools/fight_shots.gd** (needs a screen or xvfb) saves fight pictures to results/fight/ (git-ignored): the red coat volley and charge, zombies closing, the host running in, the manned MG nest, and a pinned squad.

## Balance (all numbers in scripts/combat/troop_kinds.gd SPEC and combat_control.gd)
In the checks, one rifle squad against 24 red coats loses about a third of its men and wins. Against the zombie horde it is often overrun. One manned MG nest takes 8-12 zombies in its first 40 s at long range. These are first guesses for the user to tune.

## Files
- **New:**
  - scripts/combat/troop_kinds.gd: each kind's men, clips, speeds and fighting numbers.
  - scripts/combat/combat_control.gd: shooting, cover, pinned, hand to hand, enemy brains, posts, waves.
  - tools/check_combat.gd, tools/fight_shots.gd.
- **Changed:**
  - scripts/squads/squad.gd: any kind and side; men fall (kill), one-off moves (act), pinned, hand-to-hand places, posts; walk and run at the speed of the men's own clips.
  - squad_control.gd: attack and man-a-post orders.
  - main.gd: hooks it up.
- **Not touched:** the red coat, medieval, zombie, engineer and rifle models and their clips (other sessions' areas), used read only.

## Round 2: finishing off fighting (2026-11-11)
The user said "go" on the suggested answers:
- **Ammo:** a rifleman carries 50 rounds, red coats and archers 24. Every shot uses one.
  - Out of rounds, a man does not fire. The squad's banner and card say OUT OF AMMO, and it still fights hand to hand.
  - Ours fill up when they stand within 35 m of a finished depot or HQ. The enemy's never fill up.
  - MG nests carry 1200 rounds and gun pits 30 shells. A finished depot within 200 m keeps them full. A post keeps what's left when its crew leaves.
- **Wounded:** about a third of our men who would have died are wounded instead.
  - A wounded man lies 12 s, then gets up and walks (slowly) to the nearest finished HQ or barracks, which are the aid posts.
  - He heals there for 40 s. Then he joins a squad of his kind that comes within 40 m and is below full strength.
  - Top-ups are free for now. While walking back he can't be shot; that's a simplification.
- **Garrisons:** right click a village house or ruin, or one of our finished HQ, barracks, depot, station, halt, engine shed, signal box or runner post, with a rifle squad selected.
  - It goes inside, out of sight, and fires from it. A man inside is hit a quarter as often; in a ruin, 40% as often.
  - Its men fight at the door if the enemy reaches it, and it sees and shoots 15% further from inside.
  - One squad per building. A move order brings it out.
- **Line of sight:** higher ground between two squads (a cliff edge or a plateau) blocks seeing and shooting, and so do more than three cells of woods in between.
  - Higher up, a squad sees and shoots 15% further for each level above its target.
- **Fog of war:** enemies are hidden until one of ours sees them.
  - Ours see 260 m by day, half that at night and about a third in fog, with high ground counting.
  - Finished buildings see 150 m round them.
  - An enemy who fires shows himself to anyone of ours within 400 m for 4 s.
  - Ours only fire at enemies they can see. The enemy always knows where we are.
- **Balance change:** red coats now close to about 60 m before their volley, and their muskets hit more often up close (0.3 instead of 0.16). Before, the rifles shot them all down without a loss.
- **Unit card:** shows men left of full strength (e.g. "9 of 12 men") and ammo (e.g. "ammo 62%").
- **Check:** tools/check_combat2.gd covers:
  - ammo use, no fire when out, hand to hand when out;
  - refill at a depot and none far from one;
  - an MG's rounds, emptying and refilling;
  - a wounded man walking to the HQ, healing and joining the squad;
  - a squad going into a house, out of sight, harder to hit, firing and coming out;
  - a cliff blocking sight, and high ground adding range;
  - fog hiding a far enemy, showing a near one, and firing giving one away.
  - Seeds 1-2: COMBAT2 CHECK DONE 0. The round 1 combat, squad, building and controls checks still pass.
- **Pictures:** tools/fight2_shots.gd saves a garrisoned house, the wounded walking back to the HQ, and the card.
- **Files:**
  - new: scripts/combat/garrison.gd, tools/check_combat2.gd, tools/fight2_shots.gd;
  - changed: combat_control.gd, troop_kinds.gd (ammo, wound), squad.gd (ammo, add_man for top-ups), unit_cards.gd, squad_control.gd (garrison orders), main.gd.

## For later
- A supply lorry driving rounds out to squads.
- Stretcher bearers, and an aid post building of its own.
- Enemies garrisoning houses.
- A "last seen" marker for enemies that drop out of sight.
- Arrows in flight (they hit, but no arrow is drawn yet).
- Enemy waves on their own, led by the Story Teller.
- Knights on horses; red coat dragoons and field gun.

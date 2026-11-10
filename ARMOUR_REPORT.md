# Armoured trench troops (Building Chat 1, 2026-11-10)

The user asked for melee troops on our side: "a ww1 heavy armored riot police type army looking unit".

## The user's answers
- **Weapons:** trench clubs and maces (plus sharpened spades), big steel shields with a vision slit, a pistol as back-up.
- **Armour:** full heavy.
- **Fighting:** both moves. A locked shield wall that advances step by step, with club men striking over the shields, then breaking into a rush near the enemy.
- **Output:** pictures and videos.

Go was given about 08:10 with an ETA of 3-4 h. It was built by 08:39.

## What is built
- **Two roles, on the rifleman's skeleton.** Every pose, clip, IK hand, death and blast throw works as for our other troops.
  - **Shield man:** carries the tall slit shield and a club.
  - **Club man:** carries a trench club, a flanged mace or a sharpened spade, picked by seed or set per man. His left hand is free.
- **Armour:**
  - three overlapping belly lames and a ridged, riveted breastplate;
  - a gorget, shoulder plates with two lames, armoured forearms, thigh tassets, knee plates and shin plates;
  - leather gloves, and a holster on the right hip;
  - a deep steel helmet with a heavy bolted brow plate and a face visor with an eye slit and breathing holes;
  - a white chevron on the shoulder of about half the men.
- **The shield:**
  - a centre panel and two wings bent back, so it reads as curved, with rolled rims;
  - a vision slit under a little hood, a firing port with its swivel cover, rivets and a white chevron;
  - the handle and the arm strap behind.
- **How the shield is held:** it is a separate node, placed at the left palm and squared to the chest after every skeleton update. It is held more upright than the chest leans, so it follows any pose, clip or blast throw. When the man goes down it slides out to his left and lies on the ground beside him.
- **The pistol:** the club goes onto a belt hook at the left hip, and the pistol shows in the right hand.

## Moves (scripts/units/anim/clips_armour.gd; clip names are "shield_..." and "club_...")
- **walk:** the heavy walk, with short rolling steps.
- **wall_lock:** the shield comes up into the wall.
- **wall_step:** the wall's crouched step-and-drag advance. Club men follow behind with their clubs raised.
- **strike:** a club blow over the top of the shields.
- **rush:** breaking from the wall into the heavy run.
- **smash / swing (club men):** the overhead blow stepping in, and the side swing at head height.
- **bash / block (shield men):** the shield punch off the back foot, and taking a blow on the raised shield (jolted back, braced).
- **pistol:** the club goes to the belt, the pistol comes out and fires three shots (over the shield for the shield man).
- **hit:** a stagger. A ball rings off the plates and he is rocked back a step, then comes on again.
- **death_back, death_forward, prone_to_stand:** the shared ones, in the armour's carry.
- **Holds:** stand, wall, guard, pistol.

## Pictures and videos (results/units/armour/)
- armour_look.png: the four men front and back, shields and clubs up, a close-up, the close/mid/far meshes, and the shield wall.
- armour_moves_shield.png, armour_moves_club.png, armour_moves_falls.png: one row per move, up to six moments each.
- wall.mp4, rush.mp4, strikes.mp4, pistol.mp4, battle.mp4: the videos.
- armour_battle_stills.png: stills taken from the battle video.

## Numbers (triangles, close / mid / far)
| | close | mid | far |
|---|---|---|---|
| Shield man (body; the shield is a separate mesh) | 1764 | 524 | 264 |
| Club man | 1732 | 524 | 264 |

## Files
- scripts/units/armour_builder.gd (ArmourBuilder): the armour, the helmet, the shield and the hand items.
- scripts/units/armoured.gd (Armoured): the unit, its props and the shield placement.
- scripts/units/anim/clips_armour.gd: poses and clips.
- tools/armour_pictures.gd (`-- look moves`) and tools/armour_clips.gd (`-- wall rush strikes pistol battle`).

## Rough edges, for later
- The shield always faces where the chest faces; there is no separate "angle the shield" control in a pose.
- The shield is not counted when the man is set on the ground, so in a few lying poses it hovers a little above the earth.
- The strikes have no impact effects yet (no sparks or dust). Only the pistol flashes and smokes.
- No sounds.

## The videos
- **wall.mp4 (12 s):** five shields come up and lock, the wall's step-and-drag advance, then three club men (club, mace, spade) strike over the shields.
- **rush.mp4 (7 s):** the wall breaks into the rush, then bashes and blows at the end.
- **strikes.mp4 (6 s):** an overhead smash, a side swing, a shield bash and a block, side by side, each played twice.
- **pistol.mp4 (5 s):** the club goes to the belt, the pistol comes out, and three shots are fired (over the shield, and the club man's).
- **battle.mp4 (13 s):** against a red coat line.
  - The red coats fire a volley into the wall.
  - A cannon shell throws one of ours.
  - The red coats charge; their bayonets meet the shields while blows come over the top.
  - A bash, and a pistol fired over the shield.
  - Most of the red coats fall, and two of ours do too.

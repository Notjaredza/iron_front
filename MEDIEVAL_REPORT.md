# The medieval host: the ancient enemy (Building Chat 1, 2026-11-10)

The user asked "ancient hosts - lets work on the medieval enemy next". These were the answers given:
- **Roster:** all four sets.
  - Foot core: men-at-arms, spearmen, crossbows, longbows, a captain, a banner bearer.
  - Mounted knights: barded horses and lances, plus a light horse scout.
  - Heavy shock troops: two-handers, pole-axes and halberds, full plate.
  - The rabble levy: pitchforks, flails, billhooks.
- **Look:** bright heraldry. A feudal muster of many lords' colours, not one livery.
- **Moves:** core moves, formations, the knight charge, and fights against our riflemen and armoured troops.
- **Output:** pictures and videos.

Go was given at 18:10, with an ETA of 3-4 h. It was built by 18:37 (about 30 min). APPROVED by the user at 18:43.

## What is built
- **The men** (`Medieval`, built by `MedievalBuilder`) are on the rifleman's skeleton, so every pose, clip, IK hand, death and blast throw works.
  - The olive uniform is recoloured to the body kind: mail, padded jack, tunic or shirt. Legs are hose, mail or plate; shoes are leather.
  - Body layers go over that:
    - mail;
    - the quilted jack;
    - plate (pauldrons, couters, vambraces, cuisses, poleyns, greaves, a ridged breastplate);
    - the surcoat, with the skirt split on the thighs.
  - Helms:
    - nasal helm, kettle hat, crested great helm (a fan or horns in the arms' colours), visored pig-snout bascinet;
    - a mail coif under the war helms;
    - cap with a feather, hood, or bare head with hair for the archers and levy.
  - Belt pouch, a sword at the hip (crossbows, longbows, banner, knights), quiver with arrows, and a pavise on the crossbowman's back.
- **Roles and kit:**

  | Role | Body | Helm | Kit |
  |---|---|---|---|
  | man-at-arms | mail + surcoat | nasal/kettle | sword + heater shield |
  | spearman | jack, often a surcoat | kettle | spear + shield |
  | crossbow | jack | kettle | crossbow (steel prod, stirrup) + pavise |
  | longbow | jack or tunic | cap/hood/bare | longbow, quiver, stakes |
  | captain | plate + surcoat | crested great helm | sword + shield, his own arms |
  | banner | mail + surcoat | kettle | the lord's banner on a crossbar pole |
  | heavy | full plate | bascinet | greatsword, pole-axe or halberd |
  | levy | tunic or shirt | hood/cap/bare | pitchfork, flail or billhook |
  | knight | plate + surcoat | crested great helm | lance in his colours, sword, shield, barded horse |
  | scout | jack | kettle | javelin, small shield, plain horse |

- **Heraldry, all from seeds:**
  - Each of 6 lords has arms:
    - a metal (or, argent) and a colour (gules, azure, vert, sable, purpure);
    - a division (plain, per pale, per fess, quarterly, chevron, bend, chief);
    - a charge (cross, roundels, star, rampant beast).
  - The arms are cut into the actual outline (heater, banner, pavise) and painted on the shields, the surcoat breast and back, the banners and the pavises. Per pale and quarterly carry on down the surcoat's legs.
  - Men wear their lord's livery. Captains and knights bear their own arms.
- **The barded horse:** the red coat horse with a caparison.
  - The skirt is quartered in the knight's two tinctures, with his arms on both flanks.
  - A crinet in his colours covers the neck, plus a steel chanfron and a plume.
  - It is skinned to the horse's own bones, so it moves with every gait, the rear and the fall.
- **Triangles:** man-at-arms 908 / 412 / 224 (close / mid / far); heavy 1256 / 648 / 224.

## Moves (scripts/units/anim/clips_medieval.gd, "<kit>_<move>")
- **Every kit:** march, run, hit, death_back, death_forward, prone_to_stand, plus holds. The levy shambles: a looser, swaying gait.
- **Sword:** strike (overhead cut), thrust, block (the shield takes the blow), wall_lock, wall_step.
- **Spear:** thrust, block, brace (the hedge's front rank kneels, butt down, point up).
- **Crossbow:** shoot (the bow kicks); reload (nose down, foot in the stirrup, the cranequin wound round, then back to the shoulder).
- **Longbow:**
  - volley (the high loose) and shot (flat): reach to the quiver, nock, draw to the jaw, loose. The arrow sits on the string, and the string follows the hand.
  - stake: driving the sharpened stake in.
- **Banner:** wave.
- **Great / pole / levy:** strike (two-handed overhead blow), sweep (side blow).
- **Mounted** (riders on horses): lance up, couched for the charge, impact (thrown back), sword raise / cut, javelin throw, and unhorsed (thrown from the saddle to the ground).
- **Falls:** the shield comes to rest on the ground beside a fallen man. Pole arms fall along the arm.

## Formations
- **Shield wall:** a locked front rank, a second rank with shields up behind, and the captain and banner at the back.
- **Spear hedge:** the front rank braced on one knee, the second levelled, the third overarm.
- **Archer line:** longbows behind two rows of sharpened stakes, loosing high; crossbows kneeling or spanning at their pavises.

## Pictures (results/units/medieval/)
- med_look: every role, from behind, on guard, the six lords' arms, every heavy and levy weapon, close / mid / far.
- med_close: close-ups.
- med_moves_foot, med_moves_missile, med_moves_heavy, med_moves_falls: every clip, six frames each.
- med_formations, med_knights.
- med_fights, against our troops:
  1. the host comes on behind its banner while our line fires;
  2. the arrow storm;
  3. the knights' charge, with a horse brought down;
  4. the melee against our bayonets;
  5. our armoured shield wall against the levy;
  6. plate against plate.

## Videos (results/units/medieval/, 30 fps)
- **med_host:** the host on the march; it halts, locks the wall, the banner swings; the wall comes on.
- **med_volley:** two volleys over the stakes; the arrows fly, fall and stick in the ground. Crossbows shoot, span and shoot.
- **med_charge:** knights walk, gallop and couch their lances. Our line fires; a horse goes down and throws its rider. Impact, then swords out against our bayonets.
- **med_melee:** men-at-arms, a pole-axe heavy and the levy rush our riflemen, armoured shield man and mace man.
- **med_battle:** the host under our shell fire. Blasts throw men-at-arms and levy, their archers answer with the arrow storm, and they come on.

## Files
- scripts/units/medieval_builder.gd, scripts/units/medieval.gd, scripts/units/anim/clips_medieval.gd
- tools/medieval_pictures.gd (`-- look close moves formations knights fights`; MED_ONLY=<clip part> for one row)
- tools/medieval_clips.gd (`-- host volley charge melee battle`)

## Open / for later
- Banners are stiff cloth; they could use the flag-wave shader the red coat colours use.
- The crossbow's stirrup foot is not on the ground while spanning; the cranequin is shown by the hands only.
- Arrows are props in the videos. In the game they would want the projectile system, with hits on men.

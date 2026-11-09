# Iron Front: paratrooper transport, air round 2 (plan)

Asset Builder Chat, 2026-11-10. **Nothing is built until the user says go.**

This round covers the models and their animations only, on top of the approved air round 1 (AIR_REPORT.md). Drop orders, landing zones and unit control are later pieces.

## The user's answers
- **Plane:** a new big transport, made in the same style as the bomber. A large biplane with three engines, a boxy cabin, a side door and windows, carrying a stick of 10-12 men. It gets generic diamond markings.
- **Figure:** the approved rifleman (scripts/units, Soldier) plus a harness, a pack on the back, a reserve on the chest and a canopy. The look matches the troops. I only read the units code and change none of it: the jump poses are set from my own scripts.
- **Animations:**
  - **Loading on the ground:** men walk up to the door at the field strip, climb in and sit on benches; the door shuts.
  - **Jump and land:**
    - the door opens and the men stand and hook up their static lines;
    - they jump one after another, about 0.8 s apart;
    - each line pulls a chute open (the canopy blooms);
    - they drift down swinging, then land, roll, gather the chute, unhook, and stand with the rifle ready.
  - **Supply drops:** ammo, food and medical crates on their own coloured chutes, pushed out with the men. They land and the chutes collapse over them.
  - **Shot during the drop:**
    - the plane is hit mid-drop and the men bail out early and low;
    - some chutes fail (a streamer), one burns;
    - a man is hit while hanging in his harness and goes limp;
    - the plane then goes into its crash.
- **Crashes:** the transport gets the same baked crashes as the other planes (spin and wing-off), from assets/air/crashes.res.
- **For the user's look:** stills (near, far, night, cabin and figure close-ups), plus videos of loading, the drop, the landing close up, the supply drop, being shot during the drop, and both crashes.

## Files (my paths only)
- scripts/air/: new transport spec in air_parts.gd; para.gd for the jumper, chute and crate.
- tools/air_pictures.gd, air_videos.gd and air_bake.gd: new shots, clips and crash bakes.
- assets/air/, results/air/
- PARA_PLAN.md and PARA_REPORT.md

## ETA: about 7-8 h of work (the air round took about 1 h against its 10-12 h estimate)

| Step | Time | Total |
|---|---|---|
| Transport model: cabin, door, benches, three engines, far look | 1.5 h | 1.5 h |
| Paratrooper kit on the rifleman, chute canopy, supply crates | 1.5 h | 3 h |
| Poses: sit, stand and hook up, jump, hang and swing, land and roll, gather, stand ready | 1.5 h | 4.5 h |
| Loading, the drop, supply drop | 1 h | 5.5 h |
| Shot during the drop: failed chutes, burning chute, hit man, early bail-out | 1 h | 6.5 h |
| Crash bakes for the transport, check | 0.5 h | 7 h |
| Gallery, videos, report | 0.5-1 h | 7.5-8 h |

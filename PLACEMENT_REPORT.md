# Building placement report

## The round (2026-11-11)
The user's answers:
1. A build menu with pictures, like Company of Heroes or Rise of Nations.
2. R turns the building.
3. Engineers walk over and build it over time.
4. Free for now; supply and resources come later.
5. Fits on flat dry open ground only; no "near the HQ" rule for now.
6. Walls, wire and sandbags are dragged out as lines in this round.
7. This session keeps to unit control, placing and game controls; the building models are read only.

## How it plays
- **B** shows or hides the build menu. It sits along the bottom of the screen, with tabs: Core, Defences, Walls, Rail, Comms, Research. Each building has a picture, drawn from the real model when the game starts.
- **Click a picture** and a see-through copy follows the mouse on the 8 m grid: green where it fits, red where it doesn't.
- **R** turns it a quarter turn. **Left click** places it; hold **Shift** to place more of the same. **Right click** or **Esc** stops placing.
- **Lines** (wall, sandbags, wire belt, concertina, hedgehogs, teeth): press, drag and let go. Every cell that fits is placed and the ones that don't are skipped. Walls and sandbags join up by themselves: ends, straights, corners, T's and crosses. Tower, bastion and road gate are single wall cells that join the wall.
- **Where it fits:** flat dry ground, all on one level. Not on cliffs, water, fords, streams, marsh, ramps, woods, hedges, lone trees, rails or village houses, and not on another building or on men.
- **Building:** placing marks out a plot and closes its cells to walkers. The selected engineers, or the nearest section if none are selected, walk over. The NCO checks the plan while the sappers hammer, saw and dig (or drive pickets and dig for wire and walls). The stages run plot, frame and scaffold, half built, finished.
  - Build time: 20 s plus 10 s per tile for one section of four, so an HQ takes about 110 s. Wall cells take 14 s, wire 6 s.
  - Two sections build twice as fast.
  - A section that finishes its list helps the nearest building nobody is working on, within 200 m.
  - The banner shows "building HQ 42%".
- **Engineers and orders:** a move order drops their building jobs. A right click on an unfinished building sends the selected engineers back to it.
- **Delete or X** over a building that isn't finished cancels it and opens its cells again.
- **Delete or X over a finished building** has engineers take it down: the selected ones, or the nearest section. The stages run backwards (half built, frame, plot) in half its build time. Then it's gone, its cells open again, and walls or sandbags round it re-join. The banner shows "taking down Barracks 60%".
- **Finished buildings:** their lights come on at night, flags and other moving parts run, and they switch to the far look from high up.
- **Two engineer sections** (NCO and three sappers each, the approved models) now start behind the rifle squads.

## Check
- **tools/check_build.gd:**
  - placing rules (cliff, water, ramp, woods, men, overlap, turning);
  - plots close cells, and cancelling opens them;
  - walls join (end, straight, T, corner);
  - a wire line skips the cells it can't use;
  - engineers reach their spots outside the footprint and build the stages in order in the right time;
  - two sections build at twice the speed;
  - auto help;
  - taking down: stages backwards, half the time, cells open again.
  - Seeds 1-3: BUILD CHECK DONE 3 0. The squad check still passes: SQUAD CHECK DONE 3 0.
- **Pictures:** tools/build_shots.gd (needs a screen or xvfb, see its header) saves the menu, ghosts, work, close-up, done and night pictures to results/build/ (git-ignored).

## Files
- **New:** scripts/build/build_control.gd (placing, lines, joining, engineers' jobs), build_site.gd (one site: cells, progress, work spots), build_menu.gd (the menu and its pictures). tools/check_build.gd, tools/build_shots.gd.
- **Changed:**
  - scripts/squads/squad.gd: squads can be engineer sections, and engineers work at spots with their work clips and tools.
  - squad_control.gd: engineers spawn; move orders drop jobs; a right click on a site sends engineers there; mixed-size squads share a drawn line.
  - nav_grid.gd: set_blocked for buildings.
  - scripts/main.gd: hooks it up.
- **Not touched:** the building and engineer models and clips (another session's area), used read only. Their own stand-in builders are hidden while real engineers work.

## For later
- Supply costs, and a "near the HQ" rule.
- Rail gates where a wall crosses a track: walls on rails are refused for now.
- Trenches, which need the ground to be dug.
- Sandbags and wire now block walking completely; later they could slow men down or be crossable.
- Engineers walk straight to their spots, so on big buildings the back spots may mean a short walk past the corner.

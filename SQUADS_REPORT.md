# Squads report

## Round 1: select and move (2026-11-11)
- Three 12-man rifle squads. Left click or drag to select (Shift adds), right click to move, double right click to run, H to find them.
- Walk grid: cliffs and deep water closed, fords/streams/marsh slow, woods a little slow, ramps join the levels.
- Check: tools/check_squads.gd.

## Round 2: drawn formations, Total War style (2026-11-11)
- **Right drag** draws the line the selected squads will stand on. Let go and they walk there.
- **One solid line:** the squads stand side by side with the same spacing between squads as between men, in the left-to-right order they stand in now.
- **Line length sets the shape:** a long line makes them wide and shallow (up to 12 men across, one rank), a short line makes them narrow and deep (down to 3 across, four ranks). A short last rank stands centred.
- **Facing:** forward from the line. Drawn left to right on screen they face away from the camera, drawn right to left they turn round and face it.
- **Preview:** while dragging, a green tick shows every man's place and an arrow shows which way each squad will face.
- **Drawn lines are always a walk.** A plain right click still moves, and a double right click still runs.
- A plain right click now also turns every squad to face the same way (the way the group was going).
- Check: tools/check_squads.gd step 5 (long, medium and short lines, drawn both ways): everyone in place, facing right, front rank on the line, one solid evenly spaced line. Run on seeds 1-3: SQUAD CHECK DONE 3 0.
- Files: scripts/squads/squad.gd (width and facing on arrival), scripts/squads/squad_control.gd (drag, preview, plan_line).

## Building round: engineer sections (2026-11-11)
- Squads can now be engineer sections (NCO and three sappers, the approved models). Two start behind the rifle squads.
- They walk, run and stand like the rifles, carrying the shovel. At a building site each man takes a spot and plays his work clip, with the right tool in his hand.
- A move order drops their building jobs. A right click on an unfinished building sends them to it. See PLACEMENT_REPORT.md.

## Unit cards and control groups (2026-11-11)
- **Unit cards** (bottom left): one card per selected squad, showing its name, how many men, and what it's doing (standing, walking, running, building HQ 42%...).
  - The **Run/Walk** switch speeds up or slows down a squad on the move. It's greyed out while the squad stands still.
  - Click a card's name to select only that squad.
- **Control groups:** Ctrl+1-9 saves the selection under that number. 1-9 picks it again, and the same number twice quickly takes the camera there. Ctrl+number with nothing selected clears the group.
  - A number with no group saved goes on to the blast test's shell-size keys, as before.
- Check: tools/check_controls.gd (cards follow the selection; Run takes a squad to 3.7 m/s and Walk back to 1.3 m/s; groups save, pick, jump the camera and clear). CONTROLS CHECK DONE 0.
- Files: scripts/squads/unit_cards.gd (new), squad_control.gd (groups, cards), squad.gd (set_running).

## Ideas for later
- Orders delayed by the comms network (step 3).

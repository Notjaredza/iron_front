// Iron Front tracker content. Columns of the Built tab:
// ID, Name, Side, Type, Group, Status, Weapons, Crew / carries, Animations done, Videos / pictures,
// Job and abilities in game, Still missing, Notes
const OUR = "Our army", RED = "Red jackets", ZOM = "Zombies", ANY = "Any side";
const NC = "Not coded yet.";

exports.built = [
  // ---- Our army: infantry
  ["U-001", "Rifleman", OUR, "Infantry", "Line troops", "Approved", "Bolt-action rifle", "1 man (12-man squads)", "Walk, run, ready, stand/kneel/prone, fire and bolt, stripper-clip reload, pose changes, flinch, 2 deaths, blast throw", "rifleman_walk_run, rifleman_fire_reload, rifleman_pose_changes, rifleman_hit_death", "Fight, take cover, garrison ruins and houses. " + NC, "Melee (bayonet) moves", "Base body and moves for every other man."],
  ["U-002", "MG team (gunner squad)", OUR, "Infantry", "Support weapons", "Approved", "Heavy MG on tripod", "6 men: gunner, loader, carriers", "Loaded march and run, tripod set-up, belt feed, sweeping fire, ammo run, crew swap when the gunner falls", "mg_march, mg_setup, mg_fire, mg_swap", "Suppressing fire, set up and pack up, uses ammo. " + NC, "Pack-up move", ""],
  ["U-003", "Officer (the player)", OUR, "Hero", "Command", "Approved", "Pistol, whistle", "1", "Whistle, wave on, point out objective, map read, binoculars", "cmd_kit, cmd_orders, cmd_field", "Buffs squads near him. Wounded first and carried to HQ; the run ends if he dies. " + NC, "Horseback moves; wounded and carried moves", "On foot, horseback or train (DESIGN.md)."],
  ["U-004", "Lineman", OUR, "Infantry", "Comms", "Approved", "Rifle", "1, wire drum on back", "Lay wire from the drum, walk the line, splice a cut wire", "cmd_lay, cmd_repair", "Lays and repairs the comms wire network. " + NC, "", ""],
  ["U-005", "Signaller", OUR, "Infantry", "Comms", "Approved", "Rifle", "1, phone, lamp, flags", "Phone, Morse signal lamp, semaphore", "cmd_lamp, cmd_kit", "Sets up temporary relays; passes orders along the network. " + NC, "", ""],
  ["U-006", "Assault NCO", OUR, "Infantry", "Assault section (8)", "Approved", "Pistol", "Leads the section", "Crouched rush, drop, wave on", "troop_look, troop_assault", "Leads the assault section. " + NC, "", ""],
  ["U-007", "Assault trooper", OUR, "Infantry", "Assault section (8)", "Approved", "Carbine, stick grenades", "1", "Rifleman set plus grenade throw", "troop_moves, troop_assault", "Close assault, grenades. " + NC, "Carbine jumps to the back when standing to throw", ""],
  ["U-008", "Raider", OUR, "Infantry", "Assault section (8)", "Approved", "Nail-studded trench club", "1", "Club carries only", "troop_look, troop_assault", "Melee. " + NC, "No melee strike move yet", ""],
  ["U-009", "Sniper", OUR, "Infantry", "Sniper pair", "Approved", "Scoped rifle, hooded cape", "1", "Crawl, prone fire, bolt worked, reload", "troop_snipers", "Long-range shots. " + NC, "", ""],
  ["U-010", "Spotter", OUR, "Infantry", "Sniper pair", "Approved", "Rifle, binoculars", "1", "Prone glassing, pointing", "troop_snipers", "Spots targets for the sniper. " + NC, "Slung rifle sticks up when lying down", ""],
  ["U-011", "LMG gunner", OUR, "Infantry", "LMG team", "Approved", "Light MG with drum and bipod", "1", "Bipod deploy, bursts, drum swap", "troop_lmg, troop_moves", "Mobile suppressing fire. " + NC, "Uses the rifle's bolt reload in troop_moves", ""],
  ["U-012", "LMG carrier", OUR, "Infantry", "LMG team", "Approved", "Rifle, drum pouches", "1", "Drum swap", "troop_lmg", "Carries LMG ammo. " + NC, "", ""],
  ["U-013", "Mortar team", OUR, "Infantry", "Support weapons", "Approved", "Trench mortar (tube, plate, bombs)", "3 men: tube, plate, bombs", "Set-up, bomb drop, duck", "troop_mortar", "Indirect fire. " + NC, "Pack-up move", "Set-up shots are crowded."],
  ["U-014", "Armoured shield man", OUR, "Infantry", "Armoured trench troops", "Approved", "Big steel slit shield, pistol", "1", "Heavy walk, wall lock, wall step, rush, bash, block, pistol, hit stagger, deaths", "armour: wall, rush, strikes, pistol, battle", "Shield wall that advances, then rushes. " + NC, "", "60 s battle video parked."],
  ["U-015", "Armoured club man", OUR, "Infantry", "Armoured trench troops", "Approved", "Club, mace or spade, pistol", "1", "Strike over shields, overhead smash, side swing, rush, pistol", "armour: wall, rush, strikes, battle", "Melee behind the shield wall. " + NC, "", ""],
  ["U-016", "Paratrooper", OUR, "Infantry", "Air drop", "Approved", "Rifle, parachute", "Stick of 12 per transport", "Door exit, static line, swing, descent, landing roll, kneel up; hit and burn fates", "para videos (results/air)", "Air drop behind lines. " + NC, "", "Rifleman with chute kit."],
  ["U-017", "The General", OUR, "Hero", "Command", "Approved", "Swagger stick, flare pistol", "1 plus bodyguards", "Stand, parade walk, inspect, salute, speech set, powers poses, wounded and carried, in the staff car", "results/general stills", "Rally aura, call in fire (flare or bark), no retreat. Poses only, logic not coded.", "Power logic", "Made-up strongman."],
  ["U-018", "General's bodyguard", OUR, "Infantry", "Command", "Approved", "Rifle, fixed bayonet", "1", "Order arms, port arms walk, stoop, carry the General", "results/general stills", "Guards and carries the General. " + NC, "", ""],
  ["U-019", "Man-pack flamethrower team", OUR, "Infantry", "Flamethrowers", "Approved", "Back tanks and lance; assistant with spare bottle and rifle", "2 (operator, assistant)", "Carry walk and run with the lance, firing pose with sweep, tanks burst when hit, burning fall", "flame_trench, flame_wall", "Burns out trenches and the ground in front of walls; operator can burst in a fireball. " + NC, "", ""],
  ["U-020", "Heavy trench flamer", OUR, "Infantry", "Flamethrowers", "Approved", "Static projector on a stand, fuel cylinder, hand pump", "4 (gunner, pump man, valve man, loader)", "Gunner on the spade handles, pumping, carried in four loads (not shown carried yet)", "flame_wall", "Long sweeps from a wall or trench. " + NC, "", ""],

  // ---- Our army: vehicles
  ["V-001", "Troop lorry", OUR, "Vehicle", "Lorries", "Approved", "None", "Driver, carries 12; tows a gun", "Drive on springs, squad board and dismount, wreck", "lorry_look, lorry_drive, lorry_board, lorry_dismount, lorry_wreck", "Moves a squad; tows the field gun; portee. " + NC, "Reversing; driver never gets out", "Base for later vehicles."],
  ["V-002", "Rocket lorry", OUR, "Vehicle", "Lorries", "Approved", "16-rail rocket rack", "Crew of 4", "Set up with jacks, load, ripple salvo, pack up, cook-off wreck", "rocket_gallery, rocket_look, rocket_setup, rocket_load, rocket_fire, rocket_packup, rocket_wreck", "Area salvo. " + NC, "", ""],
  ["V-003", "Light field gun (75 mm)", OUR, "Artillery", "Field guns", "Approved", "75 mm gun", "Crew of 6", "Fire cycle, aim, manhandle, hitch, unhitch, portee, wreck", "gun_look, gun_fire, gun_aim, gun_push, gun_unhitch, gun_hitch, gun_portee, gun_wreck", "Artillery that fires where a spotter can see. " + NC, "Limber or ammo trailer", ""],
  ["V-004", "Heavy tank, gun (male)", OUR, "Vehicle", "Tanks", "Approved", "2 sponson guns, front MG", "Crew of 8", "Drive, turn on the spot, ramp, trench crossing, fire, crew in, bail out, wreck", "tank_look_heavy, tank_drive, tank_ramp, tank_trench, tank_fire_heavy, tank_crew, tank_wreck_heavy", "Breakthrough tank. " + NC, "", ""],
  ["V-005", "Heavy tank, MG (female)", OUR, "Vehicle", "Tanks", "Approved", "Sponson MGs", "Crew of 8", "As the male", "tank_look_heavy, tank_fire_heavy", "Anti-infantry tank. " + NC, "", ""],
  ["V-006", "Light tank, gun", OUR, "Vehicle", "Tanks", "Approved", "Turret gun", "Crew of 2", "Drive, trench, turret turn, fire, crew in, bail out, wreck", "tank_look_light, tank_fire_light, tank_wreck_light", "Fast support tank. " + NC, "", ""],
  ["V-007", "Light tank, MG", OUR, "Vehicle", "Tanks", "Approved", "Turret MG", "Crew of 2", "As the gun version", "tank_look_light, tank_fire_light", "Fast anti-infantry tank. " + NC, "", ""],
  ["V-008", "Flame tank", OUR, "Vehicle", "Tanks", "Approved", "Flame projector in the light tank turret, fuel drums on the deck", "Crew of 2", "Drives, turret turns and sweeps the jet", "flame_trench", "Burns out trenches. " + NC, "", "Built on the light gun tank."],

  // ---- Our army: trains
  ["T-001", "Steam engine and tender", OUR, "Train", "Rolling stock", "Approved", "None", "Crew (not shown)", "Wheels and rods, smoke, steam, coupler slack, baked crashes for 3, 4 and 5 cars", "results/trains", "Pulls every train. " + NC, "", ""],
  ["T-002", "Van (stand-in)", OUR, "Train", "Rolling stock", "Approved", "None", "Cargo", "Sliding doors", "results/trains", "Carries supply. " + NC, "Final van design", ""],
  ["T-003", "Gun flat (stand-in)", OUR, "Train", "Armoured train", "Approved", "Gun on a mount", "Crew (not shown)", "Mount turns, cradle lifts, recoil", "results/trains", "Armoured train gun wagon. " + NC, "MG, flak and troop wagons", "Armoured trains are built from wagons (DESIGN.md)."],
  ["T-004", "Railway siege gun", OUR, "Train", "Artillery", "Approved", "About 28 cm gun", "Crew on the platform", "Look, move, set up with outriggers, shell crane loading, fire, wreck", "siege_*.mp4", "Super-heavy artillery on rails. " + NC, "Third round of the fire cycle", ""],
  ["T-005", "Track-laying train", OUR, "Train", "Rail works", "Approved", "None", "Crane crew, 2 guides, 2 joint men, foreman", "Panel lift and lay, bolting, creep forward, straight and curve, shelled wreck", "layer_look, layer_straight, layer_curve, layer_shelled", "Builds new track for us. " + NC, "", ""],
  ["T-006", "Flame wagon", OUR, "Train", "Armoured train", "Approved", "Turret flame projector, two fuel tanks, pump house", "Crew (not shown)", "Turret turns right round, sweeps while rolling", "flame_wall", "Pushed out through a rail gate to burn a horde. " + NC, "", ""],

  // ---- Our army: air
  ["A-001", "Fighter / scout", OUR, "Air", "Planes", "Approved", "Forward MG", "Pilot", "Flying, take-off, landing, MG fire, baked crashes", "results/air", "Air fights, shoots down balloons and airships. " + NC, "", "Also used as the enemy fighter in ship_shotdown."],
  ["A-002", "Two-seat spotter", OUR, "Air", "Planes", "Approved", "Gunner's ring MG", "Pilot, observer", "Flying, gunner aim, baked crashes", "results/air", "Spots for artillery. " + NC, "", ""],
  ["A-003", "Twin-engine bomber", OUR, "Air", "Planes", "Approved", "Bombs, gunner MG", "Crew", "Flying, bomb release, baked crashes", "results/air", "Bombing. " + NC, "", ""],
  ["A-004", "Observation balloon and winch lorry", OUR, "Air", "Balloons", "Approved", "None", "Basket crew", "Winch up and down, crash keyed", "results/air", "Long-range spotting. " + NC, "", ""],
  ["A-005", "Paratroop transport", OUR, "Air", "Planes", "Approved", "None", "Carries a stick of 12", "Flying, door, ladder, baked crashes", "para videos (results/air)", "Drops troops and supply crates. " + NC, "", ""],
  ["A-006", "War airship (zeppelin)", OUR, "Air", "Airships", "Approved", "2 belly cannon turrets, 4 AA MGs, searchlight", "Gunners at each gun", "Look, mooring at a mast, bombarding, night searchlight, AA fight, burn, break and crash", "ship_look, ship_moor, ship_bombard, ship_night, ship_shotdown", "Slow heavy bombardment, night search. " + NC, "", "Only one so far."],

  // ---- Props and pickups
  ["P-001", "Supply crates (ammo, food, medical)", ANY, "Prop", "Air drop", "Approved", "None", "None", "Chute fall, land and tip", "para videos (results/air)", "Air-dropped supply. " + NC, "", ""],
  ["P-002", "Podium and staff car", OUR, "Prop", "Command", "Approved", "None", "General", "Speech, standing in the car", "results/general stills", "General's speech and travel. " + NC, "", ""],

  // ---- Red jackets
  ["R-001", "Musketeer", RED, "Infantry", "Line", "Approved", "Musket and bayonet", "1", "March, volley, long reload with rammer, bayonet charge, thrust, parry, butt stroke, deaths, blast throw", "results/units/redcoats", "Line infantry. " + NC, "", ""],
  ["R-002", "Red jacket officer", RED, "Infantry", "Line", "Approved", "Sword", "1", "Command poses, march", "results/units/redcoats", "Leads the line. " + NC, "", ""],
  ["R-003", "Drummer", RED, "Infantry", "Line", "Approved", "Drum", "1", "March and drumming", "results/units/redcoats", "Morale or pace. " + NC, "", ""],
  ["R-004", "Ensign (colour)", RED, "Infantry", "Line", "Approved", "Waving colour", "1", "March with colour", "results/units/redcoats", "Rally point. " + NC, "", ""],
  ["R-005", "Grenadier", RED, "Infantry", "Line", "Approved", "Musket and bayonet", "1", "Line moves", "results/units/redcoats", "Heavy line infantry. " + NC, "", ""],
  ["R-006", "Light infantry", RED, "Infantry", "Skirmishers", "Approved", "Musket", "1", "Line moves", "results/units/redcoats", "Skirmishers. " + NC, "", ""],
  ["R-007", "Red jacket field gun", RED, "Artillery", "Field guns", "Approved", "Muzzle-loading gun", "Gun crew", "Crew drill", "results/units/redcoats", "Artillery. " + NC, "", ""],
  ["R-008", "Dragoon", RED, "Cavalry", "Cavalry", "Approved", "Sabre, on horseback", "1 plus horse", "Gallop, cut, wheel, horse falls, unhorsed", "fight_dragoons sheet", "Charges. " + NC, "", "New horse model."],

  // ---- Zombies
  ["Z-001", "Zombie shambler", ZOM, "Infantry", "Dead soldiers", "Approved", "Hands and teeth", "1", "Shamble, crawl, grab and bite, claw, wall heap, gate claw, deaths", "zombie_*.mp4", "Slow horde. " + NC, "", ""],
  ["Z-002", "Zombie runner", ZOM, "Infantry", "Dead soldiers", "Approved", "Hands and teeth", "1", "Hunched sprint, leap and land, wall climb, deaths", "zombie_*.mp4", "Fast attacker. " + NC, "", ""],
  ["Z-003", "Zombie brute", ZOM, "Infantry", "Dead soldiers", "Approved", "Nailed timber club", "1", "Walk, charge, club smash, gate smash, slow fall", "zombie_*.mp4", "Breaks gates and wire. " + NC, "", ""],

  // ---- Buildings (shared by all: build stages, damage, collapse, lights, far look, placement ghost)
  ["B-001", "HQ", OUR, "Building", "Core", "Approved", "None", "Staff", "Build stages, smoke, flag, collapse", "results/buildings", "Command; the officer recovers here. " + NC, "", "3x3 tiles."],
  ["B-002", "Barracks", OUR, "Building", "Core", "Approved", "None", "Drill squad", "Drill squad stand and ready", "results/buildings", "Makes new squads. " + NC, "", "2x3."],
  ["B-003", "Depot", OUR, "Building", "Core", "Approved", "None", "None", "Crane jib swings", "results/buildings", "Stores supply. " + NC, "", "3x2."],
  ["B-004", "Concrete wall pieces", OUR, "Defence", "Walls", "Approved", "None", "None", "Auto-join (end, straight, corner, T, cross)", "results/buildings", "Blocks the way; walkway and firing steps. " + NC, "", "1x1 each."],
  ["B-005", "Wall tower", OUR, "Defence", "Walls", "Approved", "None", "None", "Searchlight sweep, lamps", "results/buildings", "Watch and light. " + NC, "", ""],
  ["B-006", "Bastion", OUR, "Defence", "Walls", "Approved", "None", "None", "Lamps", "results/buildings", "Strong point. " + NC, "", ""],
  ["B-007", "Road gate", OUR, "Defence", "Walls", "Approved", "None", "None", "Opens and shuts", "results/buildings", "Lets units through the wall. " + NC, "", ""],
  ["B-008", "Rail gate", OUR, "Defence", "Walls", "Approved", "None", "None", "Opens for a train within 120 m", "results/buildings", "Lets trains through the wall. " + NC, "", "Goes in by itself where a wall crosses a track."],
  ["B-009", "Halt", OUR, "Building", "Rail", "Approved", "None", "None", "Build stages", "results/buildings", "Small stop. " + NC, "", "2x1."],
  ["B-010", "Station", OUR, "Building", "Rail", "Approved", "None", "None", "Smoke", "results/buildings", "Loads troops and supply. " + NC, "", "3x2."],
  ["B-011", "Engine shed", OUR, "Building", "Rail", "Approved", "None", "None", "Smoke", "results/buildings", "Builds or repairs engines. " + NC, "", "2x3."],
  ["B-012", "Water tower", OUR, "Building", "Rail", "Approved", "None", "None", "Spout swings", "results/buildings", "Waters engines. " + NC, "", "1x1."],
  ["B-013", "Coal stage", OUR, "Building", "Rail", "Approved", "None", "None", "Jib swings", "results/buildings", "Coals engines. " + NC, "", "2x1."],
  ["B-014", "Signal box", OUR, "Building", "Rail", "Approved", "None", "None", "Signal arms drop and rise", "results/buildings", "Faster, safer rail traffic. " + NC, "", "1x1."],
  ["B-015", "Runner post", OUR, "Building", "Comms", "Approved", "None", "Runners", "Build stages", "results/buildings", "Comms node by runner. " + NC, "", "1x1."],
  ["B-016", "Telegraph post", OUR, "Building", "Comms", "Approved", "None", "Operator", "Crank turns, pole line", "results/buildings", "Wired comms node. " + NC, "", "1x1."],
  ["B-017", "Lamp tower", OUR, "Building", "Comms", "Approved", "None", "Operator", "Shutters flash long and short", "results/buildings", "Line-of-sight comms. " + NC, "", "1x1."],
  ["B-018", "Pigeon loft", OUR, "Building", "Comms", "Approved", "None", "None", "Pigeons wheel", "results/buildings", "Long-range comms. " + NC, "", "1x1."],
  ["B-019", "Comms lab", OUR, "Building", "Research", "Approved", "None", "None", "Teal coil pulses", "results/buildings", "Comms research. " + NC, "", "2x2."],
  ["B-020", "Weapons lab", OUR, "Building", "Research", "Approved", "None", "None", "Coil gun rings charge and flash", "results/buildings", "Weapons research. " + NC, "", "2x2."],
  ["B-021", "Rail lab", OUR, "Building", "Research", "Approved", "None", "None", "Glowing bogie, gantry travels", "results/buildings", "Rail research. " + NC, "", "3x2."],
  ["B-022", "Defences lab", OUR, "Building", "Research", "Approved", "None", "None", "Field sheet flickers", "results/buildings", "Defence research. " + NC, "", "2x2."],
  ["B-023", "Wreck yard", OUR, "Building", "Research", "Approved", "None", "None", "Gantry, trolley, cutting torches spark", "results/buildings", "Salvage from wrecks. " + NC, "", "3x3."],
  ["B-024", "Sandbag line", OUR, "Defence", "Defences", "Approved", "None", "None", "Joins as you drag", "results/buildings", "Cover. " + NC, "", ""],
  ["B-025", "Wire belt", OUR, "Defence", "Defences", "Approved", "None", "None", "None", "results/buildings", "Slows infantry. " + NC, "", ""],
  ["B-026", "Concertina wire", OUR, "Defence", "Defences", "Approved", "None", "None", "None", "results/buildings", "Slows infantry. " + NC, "", ""],
  ["B-027", "Hedgehogs", OUR, "Defence", "Defences", "Approved", "None", "None", "None", "results/buildings", "Stops vehicles. " + NC, "", ""],
  ["B-028", "Concrete teeth", OUR, "Defence", "Defences", "Approved", "None", "None", "None", "results/buildings", "Stops tanks. " + NC, "", ""],
  ["B-029", "MG nest", OUR, "Defence", "Defences", "Approved", "Heavy MG", "MG team (posed)", "Crew on or off", "results/buildings", "Crewed defence. " + NC, "", "1x1."],
  ["B-030", "Gun pit", OUR, "Defence", "Defences", "Approved", "Light field gun", "Gun crew (posed)", "Crew on or off", "results/buildings", "Crewed gun position. " + NC, "", "2x2."],

  // ---- Effects
  ["E-001", "Explosions, sizes 1 to 8", ANY, "Effect", "Explosions", "Approved", "", "", "Faceted blasts, craters, scorch, light, shake, night versions", "results/fx", "Used by every gun and bomb.", "Items marked IMPORTANT in EXPLOSIONS_REPORT.md", "Size 8 is a super-heavy railway gun."],
  ["E-002", "Blast kinds", ANY, "Effect", "Explosions", "Approved", "", "", "Grenade, AP and AT mines, tunnel mine, demolition, bullet hits, flares", "results/fx", "Weapon-specific effects.", "", ""],
  ["E-003", "Men thrown by blasts", ANY, "Effect", "Explosions", "Approved", "", "", "Tumble by facing, most get up", "thrown_men, thrown_men_night", "Works on any soldier-bodied unit.", "", ""],
  ["E-004", "Fire: jets, burning ground, burning men and things, fuel fireball", ANY, "Effect", "Fire", "Approved", "", "", "Arcing jet, ground fires that smoulder and scorch, charring, fire light, black oily smoke", "flame_trench, flame_wall", "FlameFx. " + NC, "", ""],
];

// Ideas tab starters (paused or parked work already agreed with the user).
// ID, Name, Side, Type, What it is, Weapons, Crew / carries, Animations needed, Abilities needed, Builds on, Priority, Size, Status
exports.ideas = [
  ["N-001", "Engineers", OUR, "Infantry", "Builders and repairers; answers already saved", "Rifle, tools", "Squad", "Build, repair track, wire, demolition", "Build and repair buildings and track", "U-001", "High", "Large", "Paused"],
  ["N-002", "Shells round", ANY, "Effect", "Shell flight and hits for every gun; answers already saved", "", "", "Shell flight, landing", "Shared by all guns", "E-001", "Medium", "Medium", "Paused"],
  ["N-003", "Armoured troops battle video (60 s)", OUR, "Effect", "Long battle video of the armoured trench troops", "", "", "Battle scene", "", "U-014", "Low", "Small", "Parked"],
];

exports.sides = [
  [OUR, "Our army: everything the player builds and commands"],
  [RED, "Red jackets: musket-era enemy"],
  [ZOM, "Zombies: dead-soldier enemy"],
  [ANY, "Any side: shared props and effects"],
];
exports.types = ["Infantry", "Hero", "Cavalry", "Artillery", "Vehicle", "Train", "Air", "Building", "Defence", "Prop", "Effect"];
exports.builtStatus = ["Approved", "Built, waiting for a look", "Paused"];
exports.ideaStatus = ["Idea", "Agreed", "Planned for the weekend", "Paused", "Parked", "Dropped"];
exports.priority = ["High", "Medium", "Low"];
exports.size = ["Small", "Medium", "Large"];

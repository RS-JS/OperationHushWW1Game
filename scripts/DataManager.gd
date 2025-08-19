class_name DataManager
extends RefCounted

# --- Game Constants ---
const TOTAL_MONITOR = 15
const SOLDIERS_PER_MONITOR = 300
const TANKS_PER_LIGHTER = 6
const TANK_COMBAT_BONUS = 60
const GROUND_ATTACK_BONUS = 150
const TOTAL_REINFORCEMENT_BARGES = 90 
const SOLDIERS_PER_BARGE = 200

const BASE_BARGE_HIT_CHANCE = 0.05
const BASE_SEAWALL_CASUALTY_RATE = 0.40

# --- Game State Variables ---
var division_order_of_battle: Array = []
var naval_support_ships: Array = []
var pontoon_monitors = {}
var targets = {
	"Middelkerke Bains": {"artillery": 25, "garrison": 4500, "battery_status": "Intact"},
	"Westende Bains": {"artillery": 20, "garrison": 3500, "battery_status": "Intact"},
	"Nieuwpoort Bains": {"artillery": 30, "garrison": 6500, "battery_status": "Intact"}
}
var monitors = []

# Planning choices
var pontoon_assault_plan = {}
var tank_assault_plan = {}
var main_force_plan = {}

var armour_decision_message = ""
var consolidation_plan = {}
var assignment_order = ["Middelkerke Bains", "Westende Bains", "Nieuwpoort Bains"]
var current_assignment_index = 0
var temp_redeployment_source = ""
var temp_assignment_value = 0

var consolidation_turns_total := 3
var consolidation_turn_current := 1
var naval_support_choice = "steam"
var naval_bombardment_target_focus = "split"
var q_ship_assignment = "none"
var time_of_day = "day"
var tanks_chosen = false
var bombardment_plan = "gunners"
var air_doctrine = "none"
var assault_doctrine = "coordinated"
var threat_level = 0
var mustard_gas_used = false
var time_of_day_effective = "day"
var morning_mist_failed = false
var air_doctrine_event = ""
var rfc_used_this_turn := false
var initial_targets_state = {} 

var current_assignment_type = "troops"
var assignment_values = {}
var barge_manifest = {}
var pontoon_status = {}

func initialize_game_data():
	populate_monitors()
	populate_division_structure() 
	pontoon_assault_plan.clear()
	tank_assault_plan.clear()
	main_force_plan.clear()
	consolidation_plan.clear()
	threat_level = 0
	mustard_gas_used = false
	air_doctrine = "none"

func populate_monitors():
	monitors.clear()
	pontoon_monitors.clear()
	
	var monitor_names = [
		"HMS General Macmahon", "HMS Lord Roberts", "HMS M24", "HMS M26",
		"HMS M27", "HMS M25",
		"HMS Erebus", "HMS Terror", "HMS Marshal Soult", "HMS Sir John Moore",
		"HMS Lord Clive", "HMS General Craufurd", "HMS Prince Eugene",
		"HMS General Wolfe", "HMS Prince Rupert"
	]
	
	# Assign pontoon monitors
	pontoon_monitors = {
		"Middelkerke Bains": [monitor_names[0], monitor_names[1]],
		"Westende Bains": [monitor_names[2], monitor_names[3]],
		"Nieuwpoort Bains": [monitor_names[4], monitor_names[5]]
	}
	
	# First 6 monitors carry pontoons
	for i in range(6):
		monitors.append({
			"name": monitor_names[i], 
			"purpose": "pontoon", 
			"carries": "pontoons",
			"soldiers": 0, 
			"status": "Assigned"
		})
	
	# Remaining monitors carry troops
	for i in range(6, TOTAL_MONITOR):
		monitors.append({
			"name": monitor_names[i], 
			"purpose": "troop_transport", 
			"carries": "troops",
			"soldiers": SOLDIERS_PER_MONITOR, 
			"status": "Ready"
		})

func populate_division_structure():
	division_order_of_battle.clear()
	
	# --- COLUMN "A" (2nd Brigade) -> Defaults to Middelkerke Bains ---
	division_order_of_battle.append({"name": "2nd Bde H.Q.", "strength": 100, "id": "2bde_hq", "current_dest": "Middelkerke Bains"})
	division_order_of_battle.append({"name": "2nd Machine Gun Coy.", "strength": 184, "id": "2mg", "current_dest": "Middelkerke Bains"})
	division_order_of_battle.append({"name": "216th Machine Gun Coy.", "strength": 184, "id": "216mg", "current_dest": "Middelkerke Bains"})
	division_order_of_battle.append({"name": "2nd Trench Mortar Bty.", "strength": 65, "id": "2tm", "current_dest": "Middelkerke Bains"})
	division_order_of_battle.append({"name": "1st Northants Regt.", "strength": 751, "id": "1north", "current_dest": "Middelkerke Bains"})
	division_order_of_battle.append({"name": "2nd Sussex Regiment", "strength": 751, "id": "2sussex", "current_dest": "Middelkerke Bains"})
	division_order_of_battle.append({"name": "1st Loyal N. Lancs.", "strength": 751, "id": "1loyal", "current_dest": "Middelkerke Bains"})
	division_order_of_battle.append({"name": "2nd K.R.R. Corps", "strength": 751, "id": "2krr", "current_dest": "Middelkerke Bains"})
	division_order_of_battle.append({"name": "409th Field Coy.", "strength": 197, "id": "409fc", "current_dest": "Middelkerke Bains"})
	division_order_of_battle.append({"name": "1 Coy. 6th Welsh Regt.", "strength": 170, "id": "1coy6w_a", "current_dest": "Middelkerke Bains"})
	division_order_of_battle.append({"name": "No.2 Field Ambulance", "strength": 139, "id": "2fa", "current_dest": "Middelkerke Bains"})
	division_order_of_battle.append({"name": "113th Bty. R.F.A.", "strength": 109, "id": "113rfa", "current_dest": "Middelkerke Bains"})
	division_order_of_battle.append({"name": "13th Cyclist Battn.", "strength": 294, "id": "13cyc", "current_dest": "Middelkerke Bains"})
	division_order_of_battle.append({"name": "12th Motor M.G.Bty.", "strength": 46, "id": "12mmg", "current_dest": "Middelkerke Bains"})
	division_order_of_battle.append({"name": "Corps Intelligence (A)", "strength": 2, "id": "coint_a", "current_dest": "Middelkerke Bains"})
	
	# --- COLUMN "B" (3rd Brigade) -> Defaults to Westende Bains ---
	division_order_of_battle.append({"name": "3rd Bde H.Qrs.", "strength": 101, "id": "3bde_hq", "current_dest": "Westende Bains"})
	division_order_of_battle.append({"name": "3rd Machine Gun Coy.", "strength": 184, "id": "3mg", "current_dest": "Westende Bains"})
	division_order_of_battle.append({"name": "3rd Trench Mortar Bty.", "strength": 65, "id": "3tm", "current_dest": "Westende Bains"})
	division_order_of_battle.append({"name": "2nd Welsh Regiment", "strength": 751, "id": "2welsh", "current_dest": "Westende Bains"})
	division_order_of_battle.append({"name": "2nd R. Munster Fusrs.", "strength": 751, "id": "2munster", "current_dest": "Westende Bains"})
	division_order_of_battle.append({"name": "1st Bn.Gloster Regt.", "strength": 751, "id": "1gloster_b", "current_dest": "Westende Bains"})
	division_order_of_battle.append({"name": "1st S.Wales Borderers", "strength": 751, "id": "1swb", "current_dest": "Westende Bains"})
	division_order_of_battle.append({"name": "56th Field Coy.", "strength": 197, "id": "56fc", "current_dest": "Westende Bains"})
	division_order_of_battle.append({"name": "1 Coy. 6th Welsh Regt.", "strength": 170, "id": "1coy6w_b", "current_dest": "Westende Bains"})
	division_order_of_battle.append({"name": "No.141 Field Ambulance", "strength": 139, "id": "141fa", "current_dest": "Westende Bains"})
	division_order_of_battle.append({"name": "114th Bty. R.F.A.", "strength": 109, "id": "114rfa", "current_dest": "Westende Bains"})
	division_order_of_battle.append({"name": "R.F.A. & S Coys.", "strength": 2, "id": "rfa_s", "current_dest": "Westende Bains"})
	division_order_of_battle.append({"name": "17th Cyclist Battn.", "strength": 204, "id": "17cyc", "current_dest": "Westende Bains"})
	division_order_of_battle.append({"name": "11th Motor M.G.Bty.", "strength": 46, "id": "11mmg", "current_dest": "Westende Bains"})
	division_order_of_battle.append({"name": "Corps Intelligence (B)", "strength": 2, "id": "coint_b", "current_dest": "Westende Bains"})
	division_order_of_battle.append({"name": "Div.Central Supply Coy.", "strength": 54, "id": "div_supply", "current_dest": "Westende Bains"})
	division_order_of_battle.append({"name": "Divn. Headquarters", "strength": 66, "id": "div_hq", "current_dest": "Westende Bains"})
	division_order_of_battle.append({"name": "Div.L&G.P.s", "strength": 13, "id": "div_lgp", "current_dest": "Westende Bains"})
	division_order_of_battle.append({"name": "25th Rdes.F.A. H.Q.", "strength": 10, "id": "25rfa_hq", "current_dest": "Westende Bains"})
	division_order_of_battle.append({"name": "Divisional Signals", "strength": 115, "id": "div_signals", "current_dest": "Westende Bains"})
	division_order_of_battle.append({"name": "Medical Embarkation Station", "strength": 114, "id": "med_station", "current_dest": "Westende Bains"})

	# --- COLUMN "C" (1st Brigade) -> Defaults to Nieuwpoort Bains ---
	division_order_of_battle.append({"name": "1st Bde H.Q.", "strength": 100, "id": "1bde_hq", "current_dest": "Nieuwpoort Bains"})
	division_order_of_battle.append({"name": "1st Machine Gun Coy.", "strength": 184, "id": "1mg", "current_dest": "Nieuwpoort Bains"})
	division_order_of_battle.append({"name": "1st Trench Mortar Bty.", "strength": 65, "id": "1tm", "current_dest": "Nieuwpoort Bains"})
	division_order_of_battle.append({"name": "1st Bn. The Black Watch", "strength": 751, "id": "1bw", "current_dest": "Nieuwpoort Bains"})
	division_order_of_battle.append({"name": "1st Cameron Hdrs.", "strength": 751, "id": "1cameron", "current_dest": "Nieuwpoort Bains"})
	division_order_of_battle.append({"name": "10th Gloster Regiment", "strength": 751, "id": "10gloster", "current_dest": "Nieuwpoort Bains"})
	division_order_of_battle.append({"name": "5th Royal Berks Regt.", "strength": 751, "id": "5berks", "current_dest": "Nieuwpoort Bains"})
	division_order_of_battle.append({"name": "53rd Field Coy.", "strength": 197, "id": "53fc", "current_dest": "Nieuwpoort Bains"})
	division_order_of_battle.append({"name": "R.E. & S Coys,6th Welsh", "strength": 411, "id": "re_s_welsh", "current_dest": "Nieuwpoort Bains"})
	division_order_of_battle.append({"name": "No.1 Field Ambulance", "strength": 139, "id": "1fa", "current_dest": "Nieuwpoort Bains"})
	division_order_of_battle.append({"name": "115th Bty. R.F.A.", "strength": 109, "id": "115rfa", "current_dest": "Nieuwpoort Bains"})
	division_order_of_battle.append({"name": "1 Coy,17th Cyclist Bn.", "strength": 90, "id": "1coy17cyc", "current_dest": "Nieuwpoort Bains"})
	division_order_of_battle.append({"name": "14th Motor M.G.Bty.", "strength": 46, "id": "14mmg", "current_dest": "Nieuwpoort Bains"})
	division_order_of_battle.append({"name": "Corps Intelligence (C)", "strength": 2, "id": "coint_c", "current_dest": "Nieuwpoort Bains"})
	
	# Motor Vehicles (distributed across columns as per original)
	division_order_of_battle.append({"name": "Motor Vehicles - Ambulances", "strength": 2, "id": "motor_amb", "current_dest": "Westende Bains"})
	division_order_of_battle.append({"name": "Motor Vehicles - Bus Cars", "strength": 2, "id": "motor_bus", "current_dest": "Nieuwpoort Bains"})
	division_order_of_battle.append({"name": "Motor Vehicles - Sidecars", "strength": 10, "id": "motor_side", "current_dest": "Westende Bains"})
	division_order_of_battle.append({"name": "Motor Vehicles - Motor Bicycles", "strength": 13, "id": "motor_bikes", "current_dest": "Nieuwpoort Bains"})

# --- Information Providers ---
func get_intelligence_briefing() -> String:
	var message = "The three landing sites have been chosen for their strategic value:\n"
	message += " • Middelkerke Bains: 1.75 miles behind the German Third line.\n"
	message += " • Westende Bains: 1 mile behind the German Second line.\n"
	message += " • Nieuwpoort Bains: 0.75 miles behind the German Second Line.\n\n"
	message += "ENEMY DISPOSITIONS:\n"
	message += "The sector is held by the 3rd German Marine Korps Flandern. The 199th Division is held as a mobile reserve.\n\n"
	
	# Calculate and display the strength for each target
	for target_name in targets.keys():
		var art = targets[target_name]["artillery"]
		var gar = targets[target_name]["garrison"]
		var strength = (art * 200) + gar
		var location_name = target_name.replace(" Bains", "")
		if target_name == "Middelkerke Bains":
			location_name = "Middelkerke ('Raversyde')"
		message += " > " + location_name + ": " + str(art) + " guns, " + str(gar) + " men. (Total Strength: " + str(strength) + ")\n"

	message += "\nTERRAIN ANALYSIS:\n"
	message += "A 30-foot seawall lines the coast. The immediate vicinity consists of sand dunes where the garrisons and artillery are well dug-in, favouring the defenders. Some areas have also been deliberately flooded."
	
	return message

func get_operation_plan() -> String:
	var message = "14,000 men of the 1st Division have been preparing for this assault in great secrecy at a replica facility in Dunkirk, codenamed 'Hush Island', practicing both day and night assaults.\n\n"
	message += "The operation will consist of the following stages:\n\n"
	message += "1. **NAVAL BOMBARDMENT**: Ship-to-shore fire to weaken German defensive positions.\n\n"
	message += "2. **PONTOON ASSAULT**: The Royal Naval Division, transported by monitors, will assault the beaches and deploy massive pontoons. These floating bridges will span the 30-foot concrete seawall, creating landing points for the main force.\n\n"
	message += "3. **MAIN FORCE DISEMBARKATION**: Once pontoons are secured, the 1st Division (14,000 men) will land via trawlers and barges. If pontoons fail, troops must scale the seawall under fire—a much more costly operation.\n\n"
	message += "4. **CONSOLIDATION**: The combined force must eliminate enemy artillery, clear garrisons, and secure bridgeheads for link-up with the main offensive.\n\n"
	message += "--- VICTORY CONDITION ---\n"
	message += "The complete elimination of all three enemy batteries and the routing of all three garrisons."
	
	return message

# --- Choice Processing ---
func set_naval_support_choice(choice: String):
	if choice == "Rely on the Dover Patrol":
		naval_support_choice = "destroyers"
		naval_support_ships = [
			{"name": "HMS Afridi", "class": "tribal", "status": "Ready"},
			{"name": "HMS Cossack", "class": "tribal", "status": "Ready"},
			{"name": "HMS Mohawk", "class": "tribal", "status": "Ready"},
			{"name": "HMS Tartar", "class": "tribal", "status": "Ready"}
		]
	elif choice == "Petition for Dreadnoughts":
		if randf() < 0.5:
			naval_support_choice = "dreadnought_success"
			threat_level += 2
			naval_support_ships = [
				{"name": "HMS Warspite", "class": "qe", "status": "Ready"},
				{"name": "HMS Barham", "class": "qe", "status": "Ready"}
			]
		else:
			naval_support_choice = "dreadnought_failure"
			naval_support_ships = [
				{"name": "HMS Afridi", "class": "tribal", "status": "Ready"},
				{"name": "HMS Cossack", "class": "tribal", "status": "Ready"},
				{"name": "HMS Mohawk", "class": "tribal", "status": "Ready"},
				{"name": "HMS Tartar", "class": "tribal", "status": "Ready"}
			]

func get_naval_support_resolution() -> String:
	var message = ""
	
	if naval_support_choice == "dreadnought_success":
		message += "A dispatch arrives, heavy with the gravity of its decision. It reads:\n'REQUEST GRANTED. BE ADVISED, THE ABSENCE OF WARSPITE AND BARHAM FROM THE GRAND FLEET PRESENTS A GRAVE STRATEGIC VULNERABILITY. THIS OPERATION MUST YIELD RESULTS COMMENSURATE WITH THE RISK I HAVE UNDERTAKEN. DO NOT FAIL. - JELLICOE'\n"
	elif naval_support_choice == "dreadnought_failure":
		message += "A curt dispatch arrives from the Admiralty. It reads:\n'REFERENCE YOUR REQUEST FOR CAPITAL SHIPS. UNACCEPTABLE RISK. THE GRAND FLEET'S STRENGTH MUST BE PRESERVED AT ALL COSTS TO COUNTER THE HIGH SEAS FLEET. YOU WILL MAKE DO WITH THE ASSETS ALLOCATED. - JELLICOE'\n"
	else:
		message += "Admiralty signals confirmation. The assets of the Dover Patrol are deemed sufficient for the task. Proceed as planned.\n"
		
	message += "\nThe following ships are assigned to the bombardment force:\n"
	for ship in naval_support_ships:
		message += " > " + ship["name"] + "\n"
		
	return message

func set_bombardment_targeting(choice: String):
	if choice == "Focus on Batteries":
		naval_bombardment_target_focus = "batteries"
	elif choice == "Focus on Garrisons":
		naval_bombardment_target_focus = "garrison"
	elif choice == "Split Fire":
		naval_bombardment_target_focus = "split"

func set_bombardment_plan(choice: String):
	var cost = 0
	if choice == "RNAS Balloon (Cost: 1 Monitor)": 
		bombardment_plan = "balloons"
		cost = 1
	elif choice == "Bacon's 'Islands' (Cost: 2 Monitors)": 
		bombardment_plan = "bacon"
		cost = 2
	elif choice == "Trust the Gunners (Cost: 0)": 
		bombardment_plan = "gunners"
	
	apply_monitor_costs(cost)

func apply_monitor_costs(cost: int):
	var decommissioned = 0
	for m in monitors:
		if m.purpose == "troop_transport" and decommissioned < cost:
			m.name = "Support Vessel " + str(decommissioned + 1)
			m.purpose = "support"
			m.carries = "support"
			m.soldiers = 0
			decommissioned += 1

func get_available_troop_monitors() -> int:
	return monitors.filter(func(m): return m["carries"] == "troops").size()

func process_armour_decision(choice: String) -> String:
	if "Reject" in choice:
		tanks_chosen = false
		return "A curt reply is sent to the Field Marshal. The monitors will not be converted; the infantry needs every available transport."
	elif "Approve" in choice:
		tanks_chosen = true
		var converted_monitors = refit_monitors_for_tanks()
		var message = "Orders are dispatched to the dockyards. The following monitors are to be immediately converted into tank lighters:\n"
		for monitor_name in converted_monitors:
			message += "\n > " + monitor_name
		message += "\n\nThey will be unavailable for troop transport."
		return message
	
	return ""

func refit_monitors_for_tanks() -> Array:
	var refitted_names = []
	var troop_monitors = monitors.filter(func(m): return m.purpose == "troop_transport")
	var refitted = 0
	
	for i in range(troop_monitors.size() - 1, -1, -1):
		if refitted >= 3: break
		var monitor = troop_monitors[i]
		
		refitted_names.append(monitor.name)
		
		monitor.name = "Tank Lighter " + str(refitted + 1)
		monitor.purpose = "tank_lighter"
		monitor.carries = "tanks"
		monitor.soldiers = 0
		monitor.tanks_onboard = TANKS_PER_LIGHTER
		refitted += 1
		
	return refitted_names

func set_q_ship_assignment(choice: String):
	if choice == "Screen Fire Support": 
		q_ship_assignment = "fleet"
		threat_level += 1
	elif choice == "Screen Landing Force": 
		q_ship_assignment = "screen"
		threat_level += 1
	elif choice == "No Q-Ships": 
		q_ship_assignment = "none"

func set_time_of_day(choice: String):
	if choice == "Night Assault": time_of_day = "night"
	elif choice == "Morning Landings": time_of_day = "morning"
	elif choice == "Daylight Assault": time_of_day = "day"

func set_air_doctrine(choice: String):
	if choice == "Air Reconnaissance": air_doctrine = "recon"
	elif choice == "Ground Attack": air_doctrine = "ground_attack"

func set_assault_doctrine(choice: String):
	if "Immediate" in choice:
		assault_doctrine = "immediate"
	elif "Coordinated" in choice:
		assault_doctrine = "coordinated"
		threat_level += 1

func generate_planning_summary() -> String:
	var message = "--- OPERATION PLAN FINALIZED ---\n\n"
	message += "Naval Support: " + naval_support_choice.capitalize().replace("_", " ") + "\n"
	message += "Bombardment Focus: " + naval_bombardment_target_focus.capitalize() + "\n"
	message += "Bombardment Plan: " + bombardment_plan.capitalize() + "\n"
	message += "H-Hour: " + time_of_day.capitalize() + "\n"
	message += "Air Doctrine: " + air_doctrine.replace("_", " ").capitalize() + "\n"
	message += "Assault Doctrine: " + assault_doctrine.replace("_", " ").capitalize() + "\n"
	var u_line = "U-Boat Defence: "
	u_line += "None" if q_ship_assignment == "none" else "Screen " + q_ship_assignment.capitalize()
	message += u_line + "\n\n"
	
	message += "--- PONTOON ASSAULT FORCE DISPOSITION ---\n"
	message += "Fixed Pontoon Escorts:\n"
	message += " > Middelkerke: " + pontoon_monitors["Middelkerke Bains"][0] + " & " + pontoon_monitors["Middelkerke Bains"][1] + "\n"
	message += " > Westende: " + pontoon_monitors["Westende Bains"][0] + " & " + pontoon_monitors["Westende Bains"][1] + "\n"
	message += " > Nieuwpoort: " + pontoon_monitors["Nieuwpoort Bains"][0] + " & " + pontoon_monitors["Nieuwpoort Bains"][1] + "\n\n"

	var doctrine_title = "Immediate Pontoon Assault" if assault_doctrine == "immediate" else "Coordinated Pontoon Assault"
	message += doctrine_title + " Support Assignments:\n"
	
	if not pontoon_assault_plan.is_empty():
		message += "Assault Support Monitors:\n"
		for beach_name in assignment_order:
			var monitors_assigned = pontoon_assault_plan.get(beach_name, 0)
			if monitors_assigned > 0:
				var men_assigned = monitors_assigned * SOLDIERS_PER_MONITOR
				message += " > " + beach_name + ": " + str(monitors_assigned) + " monitors (" + str(men_assigned) + " RND troops)\n"
		message += "\n"
	
	if not tank_assault_plan.is_empty():
		var has_tanks = false
		for beach_name in assignment_order:
			var tanks_assigned = tank_assault_plan.get(beach_name, 0)
			if tanks_assigned > 0:
				if not has_tanks:
					message += "Tank Support Lighters:\n"
					has_tanks = true
				var tanks_total = tanks_assigned * TANKS_PER_LIGHTER
				message += " > " + beach_name + ": " + str(tanks_assigned) + " lighters (" + str(tanks_total) + " tanks)\n"
		if has_tanks:
			message += "\n"
	
	message += "Total Pontoon Assault Force:\n"
	var total_men = 0
	var total_tanks = 0
	for beach_name in assignment_order:
		total_men += pontoon_assault_plan.get(beach_name, 0) * SOLDIERS_PER_MONITOR
		total_tanks += tank_assault_plan.get(beach_name, 0) * TANKS_PER_LIGHTER
	
	message += " > " + str(total_men) + " Royal Naval Division personnel\n"
	if total_tanks > 0:
		message += " > " + str(total_tanks) + " tanks\n"
	message += "\n"

	message += "Current Threat Level: " + str(threat_level) + "\n"
	
	return message

func get_monitor_assignment_briefing() -> String:
	var message = "--- PONTOON MONITOR ASSIGNMENTS ---\n\n"
	message += "The massive pontoons—critical for bridging the 30-foot seawall—have been assigned their escort monitors:\n\n"
	message += " > To Middelkerke Bains: " + pontoon_monitors["Middelkerke Bains"][0] + " & " + pontoon_monitors["Middelkerke Bains"][1] + "\n"
	message += " > To Westende Bains: " + pontoon_monitors["Westende Bains"][0] + " & " + pontoon_monitors["Westende Bains"][1] + "\n"
	message += " > To Nieuwpoort Bains: " + pontoon_monitors["Nieuwpoort Bains"][0] + " & " + pontoon_monitors["Nieuwpoort Bains"][1] + "\n\n"

	var troop_monitors_remaining = monitors.filter(func(m): return m.purpose == "troop_transport").size()
	
	message += "This leaves you with " + str(troop_monitors_remaining) + " support monitors available for the pontoon assault.\n"
	message += "Each carries " + str(SOLDIERS_PER_MONITOR) + " men of the Royal Naval Division. Their task is to secure the promenade, protect the pontoon crews during deployment, and establish the initial bridgehead.\n\n"
	message += "You must now assign these assault support troops to the three beachheads."

	return message

func get_active_fire_support() -> Array:
	var roster: Array = []
	if typeof(naval_support_ships) == TYPE_ARRAY and not naval_support_ships.is_empty():
		for s in naval_support_ships:
			if typeof(s) == TYPE_DICTIONARY and s.get("status", "Ready") == "Ready":
				roster.append(s)
	return roster

# --- Assignment Management ---
func get_tank_lighters_available() -> int:
	return monitors.filter(func(m): return m.purpose == "tank_lighter").size()

func get_troop_monitors_available() -> int:
	return monitors.filter(func(m): return m.purpose == "troop_transport").size()

func save_pontoon_assignment(assignment_values: Dictionary):
	pontoon_assault_plan = assignment_values.duplicate(true)

func save_tank_assignment(assignment_values: Dictionary):
	tank_assault_plan = assignment_values.duplicate(true)

func save_main_force_assignment(assignment_values: Dictionary):
	main_force_plan = assignment_values.duplicate(true)

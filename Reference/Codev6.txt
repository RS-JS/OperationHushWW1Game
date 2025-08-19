extends Control

# --- Node References ---
# Update your @onready references to match the new structure
@onready var display_text = $UIContainer/StandardGameUI/ScrollContainer/DisplayText
@onready var ui_container = $UIContainer

# Standard Game UI references
@onready var standard_ui = $UIContainer/StandardGameUI
@onready var choice_image = $UIContainer/StandardGameUI/ChoiceImage
@onready var choice_container = $UIContainer/StandardGameUI/ChoiceContainer
@onready var choice_buttons = [
	$UIContainer/StandardGameUI/ChoiceContainer/ChoiceButton1,
	$UIContainer/StandardGameUI/ChoiceContainer/ChoiceButton2,
	$UIContainer/StandardGameUI/ChoiceContainer/ChoiceButton3
]

# Pontoon Assignment UI references (renamed from Landing Assignment)
@onready var pontoon_assignment_ui = $UIContainer/PontoonAssignmentUI
@onready var assignment_title = $UIContainer/PontoonAssignmentUI/TitleLabel
@onready var assignment_confirm = $UIContainer/PontoonAssignmentUI/ConfirmButton
@onready var assignment_container = $UIContainer/PontoonAssignmentUI/AssignmentContainer

# Embarkation UI references (for main force disembarkation planning)
@onready var embarkation_ui = $UIContainer/EmbarkationUI
@onready var confirm_button = $UIContainer/EmbarkationUI/ConfirmButton
@onready var summary_label = $UIContainer/EmbarkationUI/SummaryLabel
@onready var middelkerke_unit_list = $UIContainer/EmbarkationUI/HBoxContainer/MiddelKerkeColumn/ScrollContainer/MiddelKerkeUnitList
@onready var westende_unit_list = $UIContainer/EmbarkationUI/HBoxContainer/WestendeColumn/ScrollContainer/WestendeColumnUnitList
@onready var nieuwpoort_unit_list = $UIContainer/EmbarkationUI/HBoxContainer/NieuwpoortColumn/ScrollContainer/NieuwpoortUnitList
@onready var middelkerke_stats = $UIContainer/EmbarkationUI/HBoxContainer/MiddelKerkeColumn/MiddelKerkeStats
@onready var westende_stats = $UIContainer/EmbarkationUI/HBoxContainer/WestendeColumn/WestendeColumnStats
@onready var nieuwpoort_stats = $UIContainer/EmbarkationUI/HBoxContainer/NieuwpoortColumn/NieuwpoortStats

# UI Management Functions
enum UIMode {
	STANDARD,
	PONTOON_ASSIGNMENT,  # Renamed from LANDING_ASSIGNMENT
	MAIN_FORCE_EMBARKATION  # Renamed from EMBARKATION
}

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
enum Phases {
	START_GAME, INTELLIGENCE_BRIEFING, PLAN_OVERVIEW, NAVAL_SUPPORT_DECISION, NAVAL_SUPPORT_RESOLUTION, 
	NAVAL_BOMBARDMENT_TARGETING_DECISION, ARMOUR_DECISION, ARMOUR_RESOLUTION, BOMBARDMENT_PLAN_DECISION,
	Q_SHIP_DECISION, TIME_OF_DAY_DECISION, AIR_DOCTRINE_DECISION, ASSAULT_DOCTRINE_DECISION,  # Renamed from LANDING_DOCTRINE_DECISION
	PLANNING_SUMMARY, BOMBARDMENT_REPORT, MONITOR_ASSIGNMENT_BRIEFING, TROOP_ASSIGNMENT_BRIEFING, 
	PONTOON_ASSIGNMENT,  # Renamed from LANDING_ASSIGNMENT
	PONTOON_ASSAULT_REPORT,  # Renamed from LANDING_REPORT
	MAIN_FORCE_EMBARKATION_ASSIGNMENT,  # Renamed from EMBARKATION_ASSIGNMENT
	MAIN_FORCE_ASSIGNMENT,  # New phase for main force assignment
	MAIN_FORCE_DISEMBARKATION_REPORT,  # Renamed from REINFORCEMENT_REPORT
	SPY_REPORT, CONSOLIDATION_ASSIGNMENT, CONSOLIDATION_RESOLUTION, FINAL_OUTCOME, FINAL_ROLL_OF_HONOUR
}
var current_phase = Phases.START_GAME

# --- Data Structures & Planning Choices ---
var division_order_of_battle: Array = []
var naval_support_ships: Array = []
var pontoon_monitors = {}
var targets = {
	"Middelkerke Bains": {"artillery": 25, "garrison": 4500, "battery_status": "Intact"},
	"Westende Bains": {"artillery": 20, "garrison": 3500, "battery_status": "Intact"},
	"Nieuwpoort Bains": {"artillery": 30, "garrison": 6500, "battery_status": "Intact"}
}
var monitors = []

# Renamed variables for clarity
var pontoon_assault_plan = {}  # Renamed from troop_landing_plan
var tank_assault_plan = {}     # Renamed from tank_landing_plan
var main_force_plan = {}       # Renamed from reinforcement_plan

var armour_decision_message = ""
var consolidation_plan = {}
var assignment_order = ["Middelkerke Bains", "Westende Bains", "Nieuwpoort Bains"]  # Renamed from landing_assignment_order
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
var assault_doctrine = "coordinated"  # Renamed from landing_doctrine. Can be "coordinated" or "immediate"
var threat_level = 0
var mustard_gas_used = false
var time_of_day_effective = "day"
var morning_mist_failed = false
var air_doctrine_event = ""
var rfc_used_this_turn := false
var initial_targets_state = {} 

var current_assignment_type = "troops"  # "troops" or "tanks"
var assignment_values = {}  # Beach name -> number assigned
var barge_manifest = {}  # Beach -> Array of barges with unit details
var pontoon_status = {}  # Beach -> boolean (true if pontoons established)

# --- Game Initialization ---
func _ready():
	randomize()
	confirm_button.pressed.connect(_on_choice_made.bind("Confirm Embarkation"))
	_create_and_apply_theme()
	await setup_simple_layout()
	start_new_game()

func start_new_game():
	populate_monitors()
	populate_division_structure() 
	pontoon_assault_plan.clear(); tank_assault_plan.clear(); main_force_plan.clear(); consolidation_plan.clear()
	threat_level = 0
	mustard_gas_used = false
	air_doctrine = "none"
	start_game_phase()

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
	
	for i in range(6):
		monitors.append({
			"name": monitor_names[i], 
			"purpose": "pontoon", 
			"carries": "pontoons",  # Keep both for compatibility
			"soldiers": 0, 
			"status": "Assigned"
		})
	
	for i in range(6, TOTAL_MONITOR):
		monitors.append({
			"name": monitor_names[i], 
			"purpose": "troop_transport", 
			"carries": "troops",  # Keep both for compatibility
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

func setup_choices(options: Array):
	choice_container.visible = true
	for i in range(choice_buttons.size()):
		var button = choice_buttons[i]
		
		# Disconnect ALL existing connections to prevent conflicts
		if button.is_connected("pressed", _on_choice_made):
			button.disconnect("pressed", _on_choice_made)
		if button.is_connected("pressed", handle_assignment_input):
			button.disconnect("pressed", handle_assignment_input)

		# Now, configure the button based on the current options
		if i < options.size():
			button.text = options[i]
			button.visible = true
			
			# SPECIAL HANDLING for assignment phases
			if current_phase == Phases.PONTOON_ASSIGNMENT or current_phase == Phases.MAIN_FORCE_ASSIGNMENT:
				# Connect directly to handle_assignment_input for these phases
				button.pressed.connect(handle_assignment_input.bind(button.text))
			else:
				# Connect the signal and use .bind() to pass the button's current text as an argument.
				button.pressed.connect(_on_choice_made.bind(button.text))
		else:
			button.visible = false
			
	if options.is_empty():
		choice_container.visible = false

# --- Input Handling ---
func _on_choice_made(choice: String):
	print("Button pressed! Choice was '", choice, "' in phase: ", Phases.keys()[current_phase])

	# Route input to the correct handler based on phase type
	if current_phase == Phases.PONTOON_ASSIGNMENT or current_phase == Phases.MAIN_FORCE_ASSIGNMENT:
		handle_assignment_input(choice)
		return

	# Standard choice handling for all other phases
	match current_phase:
		Phases.START_GAME:
			start_intelligence_briefing_phase()
		Phases.INTELLIGENCE_BRIEFING:
			start_plan_overview_phase()
		Phases.PLAN_OVERVIEW:
			start_naval_support_phase()
		Phases.NAVAL_SUPPORT_DECISION: 
			process_naval_support_choice(choice)
		Phases.NAVAL_SUPPORT_RESOLUTION: 
			start_naval_bombardment_targeting_phase()
		Phases.NAVAL_BOMBARDMENT_TARGETING_DECISION:
			process_naval_bombardment_targeting_choice(choice)
		Phases.ARMOUR_DECISION: 
			process_armour_choice(choice)
		Phases.ARMOUR_RESOLUTION: 
			start_q_ship_phase()
		Phases.BOMBARDMENT_PLAN_DECISION: 
			process_bombardment_plan_choice(choice)
		Phases.Q_SHIP_DECISION: 
			process_q_ship_choice(choice)
		Phases.TIME_OF_DAY_DECISION: 
			process_time_of_day_choice(choice)
		Phases.AIR_DOCTRINE_DECISION: 
			process_air_doctrine_choice(choice)
		Phases.ASSAULT_DOCTRINE_DECISION:
			process_assault_doctrine_choice(choice)
		Phases.PLANNING_SUMMARY:
			start_bombardment_report_phase()
		Phases.BOMBARDMENT_REPORT:
			if assault_doctrine == "immediate":
				resolve_pontoon_assault()
			else: # Coordinated
				start_monitor_assignment_briefing_phase()
		Phases.MONITOR_ASSIGNMENT_BRIEFING:
			pontoon_assault_plan.clear()
			tank_assault_plan.clear()
			_advance_assignment_phase()
		Phases.TROOP_ASSIGNMENT_BRIEFING:
			current_assignment_type = "troops"
			start_pontoon_assignment_phase()
		Phases.PONTOON_ASSAULT_REPORT:
			start_main_force_embarkation_phase()
		Phases.MAIN_FORCE_EMBARKATION_ASSIGNMENT: 
			resolve_main_force_disembarkation()
		Phases.MAIN_FORCE_DISEMBARKATION_REPORT: 
			start_spy_report_phase()
		Phases.SPY_REPORT: 
			start_consolidation_phase()
		Phases.CONSOLIDATION_ASSIGNMENT:
			if temp_redeployment_source != "": 
				process_redeployment_destination(choice)
			else: 
				process_consolidation_choice(choice)
		Phases.CONSOLIDATION_RESOLUTION:
			if consolidation_turn_current < consolidation_turns_total: 
				_advance_to_next_consolidation_turn()
			else: 
				determine_final_outcome()
		Phases.FINAL_OUTCOME: 
			start_roll_of_honour_phase()
		Phases.FINAL_ROLL_OF_HONOUR: 
			setup_choices([])

func start_game_phase():
	current_phase = Phases.START_GAME
	show_ui(UIMode.STANDARD)
	print("After show_ui call")

	var tex = load("res://assets/Map.jpeg")
	choice_image.texture = tex
	choice_image.visible = true
	var message = "--- OPERATION HUSH — BRIEFING ---\n\n"
	message += "For three years, the stalemate on the Western Front has bled the Empire white. Command has sanctioned a bold stroke: an amphibious landing to outflank the German line where it meets the sea.\n\n"
	message += "The German-held Belgian coast is a dagger pointed at our supply lines. The ports of Zeebrugge and Ostend serve as bases for the U-boats and destroyers that plague our shipping...\n\n"
	message += "Your objectives are twofold:\n • Objective 1: Seize the designated beachheads.\n • Objective 2: Neutralise the enemy batteries to enable a general advance from the Ypres Salient.\n\n"
	message += "The success of the entire Third Battle of Ypres may rest on your decisions."
	
	display_text.text = message
	setup_choices(["View Intelligence Briefing"])

func start_intelligence_briefing_phase():
	current_phase = Phases.INTELLIGENCE_BRIEFING
	var tex = load("res://assets/MataHari.jpg")
	choice_image.texture = tex
	choice_image.visible = true
	var message = "--- INTELLIGENCE BRIEFING ---\n\n"
	message += "The three landing sites have been chosen for their strategic value:\n"
	message += " • Middelkerke Bains: 1.75 miles behind the German Third line.\n"
	message += " • Westende Bains: 1 mile behind the German Second line.\n"
	message += " • Nieuwpoort Bains: 0.75 miles behind the German Second Line.\n\n"
	message += "ENEMY DISPOSITIONS:\n"
	message += "The sector is held by the 3rd German Marine Korps Flandern. The 199th Division is held as a mobile reserve.\n\n"
	# Calculate and display the strength for each target based on the new formula
	var m_art = targets["Middelkerke Bains"]["artillery"]
	var m_gar = targets["Middelkerke Bains"]["garrison"]
	var m_strength = (m_art * 200) + m_gar
	message += " > Middelkerke ('Raversyde'): " + str(m_art) + " guns, " + str(m_gar) + " men. (Total Strength: " + str(m_strength) + ")\n"

	var w_art = targets["Westende Bains"]["artillery"]
	var w_gar = targets["Westende Bains"]["garrison"]
	var w_strength = (w_art * 200) + w_gar
	message += " > Westende: " + str(w_art) + " guns, " + str(w_gar) + " men. (Total Strength: " + str(w_strength) + ")\n"
	
	var n_art = targets["Nieuwpoort Bains"]["artillery"]
	var n_gar = targets["Nieuwpoort Bains"]["garrison"]
	var n_strength = (n_art * 200) + n_gar
	message += " > Nieuwpoort: " + str(n_art) + " guns, " + str(n_gar) + " men. (Total Strength: " + str(n_strength) + ")\n\n"

	message += "TERRAIN ANALYSIS:\n"
	message += "A 30-foot seawall lines the coast. The immediate vicinity consists of sand dunes where the garrisons and artillery are well dug-in, favouring the defenders. Some areas have also been deliberately flooded."

	display_text.text = message
	setup_choices(["View Operation Plan"])

func start_plan_overview_phase():
	current_phase = Phases.PLAN_OVERVIEW
	var tex = load("res://assets/prepare.jpeg")
	choice_image.texture = tex
	choice_image.visible = true
	var message = "--- OPERATION PLAN & OBJECTIVES ---\n\n"
	message += "14,000 men of the 1st Division have been preparing for this assault in great secrecy at a replica facility in Dunkirk, codenamed 'Hush Island', practicing both day and night assaults.\n\n"
	message += "The operation will consist of the following stages:\n\n"
	message += "1. **NAVAL BOMBARDMENT**: Ship-to-shore fire to weaken German defensive positions.\n\n"
	message += "2. **PONTOON ASSAULT**: The Royal Naval Division, transported by monitors, will assault the beaches and deploy massive pontoons. These floating bridges will span the 30-foot concrete seawall, creating landing points for the main force.\n\n"
	message += "3. **MAIN FORCE DISEMBARKATION**: Once pontoons are secured, the 1st Division (14,000 men) will land via trawlers and barges. If pontoons fail, troops must scale the seawall under fire—a much more costly operation.\n\n"
	message += "4. **CONSOLIDATION**: The combined force must eliminate enemy artillery, clear garrisons, and secure bridgeheads for link-up with the main offensive.\n\n"
	message += "--- VICTORY CONDITION ---\n"
	message += "The complete elimination of all three enemy batteries and the routing of all three garrisons."

	display_text.text = message
	setup_choices(["Begin Planning"])

func start_naval_support_phase():
	current_phase = Phases.NAVAL_SUPPORT_DECISION
	var tex = load("res://assets/warspite.jpg")
	choice_image.texture = tex
	choice_image.visible = true
	
	var message = "--- STEP 1: NAVAL SUPPORT ---\n\n"
	message += "The Dover Patrol will provide the initial coastal barrage using a number of their obsolete Tribal-class destroyers.\n\n"
	message += "These are old, steam-powered ships armed with 12-pounder guns. Their advantage is that they are already in position, and the Germans are accustomed to their presence off the coast.\n\n"
	message += "You could, however, petition the Admiralty for the use of the latest Queen Elizabeth-class Dreadnoughts. Their 15-inch guns offer vastly superior accuracy. Be warned: they are currently in Scapa Flow. Moving these capital ships will delay the operation, alert the enemy, and there is no guarantee the Admiralty will approve the request."
	
	display_text.text = message
	setup_choices(["Rely on the Dover Patrol", "Petition for Dreadnoughts"])

func process_naval_support_choice(choice):
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
			
	start_naval_support_resolution_phase()

func start_naval_support_resolution_phase():
	current_phase = Phases.NAVAL_SUPPORT_RESOLUTION
	var tex = load("res://assets/Jelly.png")
	choice_image.texture = tex
	choice_image.visible = true
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
		
	display_text.text = message
	setup_choices(["Set Targeting Priority"])

func start_naval_bombardment_targeting_phase():
	current_phase = Phases.NAVAL_BOMBARDMENT_TARGETING_DECISION
	var tex = load("res://assets/target.jpeg")
	choice_image.texture = tex
	choice_image.visible = true
	var message = "--- STEP 2: BOMBARDMENT TARGETING ---\n\n"
	message += "The bombardment is the critical first step. The fleet's gunnery officers await your targeting doctrine.\n\n"
	message += "Your choice will determine the focus of the barrage:\n"
	message += " • Target the Batteries: Prioritise silencing the heavy guns that threaten our landing flotillas.\n"
	message += " • Target the Garrisons: Prioritise decimating the infantry in their trenches to aid our assaulting troops.\n\n"
	message += "What is the fleet's priority?"
	
	display_text.text = message
	setup_choices(["Focus on Batteries", "Focus on Garrisons", "Split Fire"])

func process_naval_bombardment_targeting_choice(choice):
	if choice == "Focus on Batteries":
		naval_bombardment_target_focus = "batteries"
	elif choice == "Focus on Garrisons":
		naval_bombardment_target_focus = "garrison"
	elif choice == "Split Fire":
		naval_bombardment_target_focus = "split"
	
	start_bombardment_plan_phase()

func start_bombardment_plan_phase():
	current_phase = Phases.BOMBARDMENT_PLAN_DECISION
	var tex = load("res://assets/baloon.jpg")
	choice_image.texture = tex
	choice_image.visible = true
	var message = "--- STEP 3: BOMBARDMENT METHOD ---\n\n"
	message += "The Dover Patrol has fifteen monitors assigned to support the mission. Six are reserved for landing the enormous pontoons, leaving nine available for close support.\n\n"
	message += "The RNAS, however, would like to requisition one of these nine to carry an observation balloon. This would provide the fleet with live feedback on hits and misses, potentially increasing the barrage's accuracy.\n\n"
	message += "Separately, Admiral Bacon has a radical idea: use two monitors as static 'islands'. This would give the gunners a fixed point of reference, allowing them to triangulate their fire—a high-risk gamble with the potential for devastating accuracy.\n\n"
	message += "Or, you can simply trust the gunners, freeing up all nine monitors for their primary support role."
	
	display_text.text = message
	setup_choices(["RNAS Balloon (Cost: 1 Monitor)", "Bacon's 'Islands' (Cost: 2 Monitors)", "Trust the Gunners (Cost: 0)"])

func process_bombardment_plan_choice(choice):
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
	start_armour_phase()

func start_armour_phase():
	current_phase = Phases.ARMOUR_DECISION
	var tex = load("res://assets/HAig.png")
	choice_image.texture = tex
	choice_image.visible = true
	
	var troop_monitors_count = monitors.filter(func(m): return m["carries"] == "troops").size()
	
	var message = "--- STEP 4: ARMOURED SUPPORT ---\n\n"
	message += "Field Marshal Haig has burst in, demanding that tanks be included in the assault.\n\n"
	message += "This would involve converting three of your " + str(troop_monitors_count) + " available troop-carrying monitors into specialist tank lighters, removing their initial infantry capacity entirely."
	
	display_text.text = message
	setup_choices(["Reject Haig's Plan", "Approve Haig's Plan"])

func process_armour_choice(choice: String):
	if "Reject" in choice:
		tanks_chosen = false
		armour_decision_message = "A curt reply is sent to the Field Marshal. The monitors will not be converted; the infantry needs every available transport."
	elif "Approve" in choice:
		tanks_chosen = true
		var converted_monitors = refit_monitors_for_tanks()
		armour_decision_message = "Orders are dispatched to the dockyards. The following monitors are to be immediately converted into tank lighters:\n"
		for monitor_name in converted_monitors:
			armour_decision_message += "\n > " + monitor_name
		armour_decision_message += "\n\nThey will be unavailable for troop transport."

	start_armour_resolution_phase()

func start_armour_resolution_phase():
	current_phase = Phases.ARMOUR_RESOLUTION
	show_ui(UIMode.STANDARD)
	choice_image.visible = true

	display_text.text = "--- ARMOUR DECISION: OUTCOME ---\n\n" + armour_decision_message
	setup_choices(["Continue Planning"])

func start_q_ship_phase():
	current_phase = Phases.Q_SHIP_DECISION
	var tex = load("res://assets/qSHip.jpg")
	choice_image.texture = tex
	choice_image.visible = true
	display_text.text = "--- STEP 5: SUBMARINE DEFENCE ---\n\nU‑boats are active in the sector. Q‑Ships can be deployed to screen either the fire‑support fleet or the landing flotillas. Their presence will likely put the enemy on alert.\n\nYour choice:"
	setup_choices(["Screen Fire Support", "Screen Landing Force", "No Q-Ships"])

func process_q_ship_choice(choice):
	if choice == "Screen Fire Support": 
		q_ship_assignment = "fleet"
		threat_level += 1
	elif choice == "Screen Landing Force": 
		q_ship_assignment = "screen"
		threat_level += 1
	elif choice == "No Q-Ships": 
		q_ship_assignment = "none"
	
	start_time_of_day_phase()

func start_time_of_day_phase():
	current_phase = Phases.TIME_OF_DAY_DECISION
	display_text.text = "--- STEP 6: H-HOUR ---\n\nChoose the timing of the assault carefully:\n\n • Night: Cloaks approach, but treacherous ranging.\n • Morning: Mist veils flotillas, but can fail.\n • Daylight: Perfect visibility for both sides."
	setup_choices(["Night Assault", "Morning Landings", "Daylight Assault"])

func process_time_of_day_choice(choice):
	if choice == "Night Assault": time_of_day = "night"
	elif choice == "Morning Landings": time_of_day = "morning"
	elif choice == "Daylight Assault": time_of_day = "day"
	start_air_doctrine_phase()

func start_air_doctrine_phase():
	current_phase = Phases.AIR_DOCTRINE_DECISION
	var tex = load("res://assets/Flashheart.jpeg")
	choice_image.texture = tex
	choice_image.visible = true
	display_text.text = "--- STEP 7: AIR DOCTRINE ---\n\nThe Royal Flying Corps is eager to help. Where do you want them?\n\n • Air Reconnaissance: Estimate enemy strength.\n • Ground Attack: Strafe trenches and gun-pits."
	setup_choices(["Air Reconnaissance", "Ground Attack"])

func process_air_doctrine_choice(choice):
	if choice == "Air Reconnaissance": air_doctrine = "recon"
	elif choice == "Ground Attack": air_doctrine = "ground_attack"
	start_assault_doctrine_phase()

func start_assault_doctrine_phase():
	current_phase = Phases.ASSAULT_DOCTRINE_DECISION
	show_ui(UIMode.STANDARD)
	choice_image.visible = false
	
	var message = "--- STEP 8: ASSAULT DOCTRINE ---\n\n"
	message += "One final decision remains: the exact timing of the pontoon assault relative to the bombardment.\n\n"
	
	message += " • **Immediate Pontoon Assault**: Launch the pontoon monitors in the immediate wake of the final bombardment shell. This maximizes surprise and shock. However, in the chaos, there is a small risk of friendly fire hitting our own pontoon flotillas.\n\n"
	
	message += " • **Coordinated Pontoon Assault**: Wait for the bombardment to cease and for observers to confirm damage before launching the pontoon assault. This allows you to adjust pontoon assignments based on bombardment results, but the delay gives the enemy time to recover and increases their alertness (`Threat Level +1`).\n"
	
	display_text.text = message
	setup_choices(["Immediate Assault (High Risk, High Reward)", "Coordinated Assault (Safe, Raises Threat)"])

func process_assault_doctrine_choice(choice):
	if "Immediate" in choice:
		assault_doctrine = "immediate"
		start_monitor_assignment_briefing_phase()
	elif "Coordinated" in choice:
		assault_doctrine = "coordinated"
		threat_level += 1
		show_planning_summary()

func show_planning_summary():
	print("=== SHOW_PLANNING_SUMMARY CALLED ===")
	current_phase = Phases.PLANNING_SUMMARY
	show_ui(UIMode.STANDARD)
	
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

	display_text.text = message
	setup_choices(["Begin Bombardment"])
	print("Planning summary setup complete")

func start_bombardment_report_phase():
	current_phase = Phases.BOMBARDMENT_REPORT
	var tex = load("res://assets/warspite.jpg")
	choice_image.texture = tex
	choice_image.visible = true
	
	var report = "--- BOMBARDMENT REPORT ---\n\n"
	report += "The pre-dawn gloom is shattered as the fleet opens fire. The Belgian shore disappears behind a wall of smoke, seawater, and pulverised earth.\n"
	
	initial_targets_state = targets.duplicate(true)
	
	for target_name in targets.keys():
		bombard_target(target_name)
	
	report += "\nInitial Damage Assessment:\n"
	for target_name in targets.keys():
		var pre_art = initial_targets_state[target_name]["artillery"]
		var post_art = targets[target_name]["artillery"]
		report += " > " + target_name + ": Guns reduced from " + str(pre_art) + " to " + str(post_art) + ".\n"
	
	if assault_doctrine == "immediate":
		report += "\n--- Immediate Pontoon Assault Commencing ---"
		report += "\nAs the last shells fall, the pontoon monitors surge forward into the smoke and debris. The assault plan is locked in!\n"
		
		if randf() < 0.05:
			var beaches = pontoon_monitors.keys()
			var hit_beach = beaches.pick_random()
			targets[hit_beach]["pontoons_damaged_by_friendly_fire"] = true
			
			report += "\n**DISASTER! FRIENDLY FIRE INCIDENT!**"
			report += "\nIn the chaos, a salvo from our own fleet landed short. Radio signals indicate the pontoon flotilla for " + hit_beach + " has taken a direct hit!\n"
	else:
		report += "\n--- Coordinated Pontoon Assault Pending ---"
		report += "\nThe bombardment ceases. Forward observers are assessing the damage to inform the pontoon assault plan.\n"

	display_text.text = report
	setup_choices(["Continue"])

func start_monitor_assignment_briefing_phase():
	current_phase = Phases.MONITOR_ASSIGNMENT_BRIEFING
	show_ui(UIMode.STANDARD)
	choice_image.visible = false

	var message = "--- PONTOON MONITOR ASSIGNMENTS ---\n\n"
	message += "The massive pontoons—critical for bridging the 30-foot seawall—have been assigned their escort monitors:\n\n"
	message += " > To Middelkerke Bains: " + pontoon_monitors["Middelkerke Bains"][0] + " & " + pontoon_monitors["Middelkerke Bains"][1] + "\n"
	message += " > To Westende Bains: " + pontoon_monitors["Westende Bains"][0] + " & " + pontoon_monitors["Westende Bains"][1] + "\n"
	message += " > To Nieuwpoort Bains: " + pontoon_monitors["Nieuwpoort Bains"][0] + " & " + pontoon_monitors["Nieuwpoort Bains"][1] + "\n\n"

	var troop_monitors_remaining = monitors.filter(func(m): return m.purpose == "troop_transport").size()
	
	message += "This leaves you with " + str(troop_monitors_remaining) + " support monitors available for the pontoon assault.\n"
	message += "Each carries " + str(SOLDIERS_PER_MONITOR) + " men of the Royal Naval Division. Their task is to secure the promenade, protect the pontoon crews during deployment, and establish the initial bridgehead.\n\n"
	message += "You must now assign these assault support troops to the three beachheads."

	display_text.text = message
	setup_choices(["Assign Pontoon Assault Troops"])

func start_troop_assignment_briefing_phase():
	current_phase = Phases.TROOP_ASSIGNMENT_BRIEFING
	show_ui(UIMode.STANDARD)
	choice_image.visible = false

	var message = "--- TANK LIGHTER ASSIGNMENTS CONFIRMED ---\n\n"
	message += "The dispositions for the armoured pontoon assault have been logged.\n\n"
	
	var troop_monitors_remaining = monitors.filter(func(m): return m.purpose == "troop_transport").size()
	message += "You must now assign your " + str(troop_monitors_remaining) + " remaining pontoon assault support monitors."

	display_text.text = message
	setup_choices(["Assign Pontoon Support Troops"])

func start_pontoon_assignment_phase():
	current_phase = Phases.PONTOON_ASSIGNMENT
	show_ui(UIMode.PONTOON_ASSIGNMENT)
	
	choice_container.visible = false
	choice_image.visible = false
	embarkation_ui.visible = false
	pontoon_assignment_ui.visible = true
	
	if tanks_chosen and tank_assault_plan.is_empty():
		current_assignment_type = "tanks"
	else:
		current_assignment_type = "troops"
	
	assignment_values.clear()
	for beach in assignment_order:
		assignment_values[beach] = 0
	
	setup_pontoon_assignment_ui()

func setup_pontoon_assignment_ui():
	var unit_type_for_filter = ""
	if current_assignment_type == "tanks":
		unit_type_for_filter = "tank_lighter"
	else:
		unit_type_for_filter = "troop_transport"
	
	var total_units = monitors.filter(func(m): return m.purpose == unit_type_for_filter).size()
	var unit_name = "Tank Lighters" if current_assignment_type == "tanks" else "Pontoon Support Monitors"
	
	print("Setting up UI for: ", current_assignment_type)
	print("Total units: ", total_units)
	print("Unit type filter: ", unit_type_for_filter)
	
	assignment_title.text = "ASSIGN " + unit_name.to_upper() + " TO BEACHES"
	
	for child in assignment_container.get_children():
		child.queue_free()
	
	await get_tree().process_frame
	
	var summary_label = Label.new()
	var assigned_total = 0
	for beach in assignment_values:
		assigned_total += assignment_values[beach]
	summary_label.text = "Available: " + str(total_units) + " | Assigned: " + str(assigned_total) + " | Remaining: " + str(total_units - assigned_total)
	summary_label.add_theme_color_override("font_color", Color("6631df"))
	assignment_container.add_child(summary_label)
	
	var spacer1 = Control.new()
	spacer1.custom_minimum_size = Vector2(0, 20)
	assignment_container.add_child(spacer1)
	
	for beach_name in assignment_order:
		create_beach_assignment_row(beach_name, total_units, assigned_total)
	
	var spacer2 = Control.new()
	spacer2.custom_minimum_size = Vector2(0, 30)
	assignment_container.add_child(spacer2)
	
	assignment_confirm.text = "Confirm Assignment"
	if not assignment_confirm.is_connected("pressed", _on_assignment_confirm):
		assignment_confirm.pressed.connect(_on_assignment_confirm)

func _on_assignment_change(beach_name: String, change: int):
	var unit_type_for_filter = ""
	if current_assignment_type == "tanks":
		unit_type_for_filter = "tank_lighter"
	else:
		unit_type_for_filter = "troop_transport"
		
	var total_units = monitors.filter(func(m): return m.purpose == unit_type_for_filter).size()
	
	var total_assigned = 0
	for beach in assignment_values:
		total_assigned += assignment_values[beach]
	
	var new_value = assignment_values[beach_name] + change
	
	if new_value < 0:
		return
	if change > 0 and total_assigned >= total_units:
		return
		
	assignment_values[beach_name] = new_value
	setup_pontoon_assignment_ui()

func create_beach_assignment_row(beach_name: String, total_units: int, assigned_total: int):
	var beach_label = Label.new()
	beach_label.text = beach_name
	beach_label.add_theme_color_override("font_color", Color("6631df"))
	beach_label.custom_minimum_size = Vector2(0, 30)
	assignment_container.add_child(beach_label)
	
	var assignment_row = HBoxContainer.new()
	assignment_row.custom_minimum_size = Vector2(0, 50)
	
	var minus_btn = Button.new()
	minus_btn.text = "➖"
	minus_btn.custom_minimum_size = Vector2(60, 40)
	minus_btn.pressed.connect(_on_assignment_change.bind(beach_name, -1))
	assignment_row.add_child(minus_btn)
	
	var value_label = Label.new()
	value_label.text = str(assignment_values.get(beach_name, 0))
	value_label.custom_minimum_size = Vector2(80, 40)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value_label.add_theme_color_override("font_color", Color("6631df"))
	assignment_row.add_child(value_label)
	
	var plus_btn = Button.new()
	plus_btn.text = "➕"
	plus_btn.custom_minimum_size = Vector2(60, 40)
	plus_btn.pressed.connect(_on_assignment_change.bind(beach_name, 1))
	assignment_row.add_child(plus_btn)
	
	assignment_container.add_child(assignment_row)

func _on_assignment_confirm():
	print("=== ASSIGNMENT CONFIRM ===")
	print("Current assignment type: ", current_assignment_type)
	print("Assignment values: ", assignment_values)
	print("Current phase BEFORE save: ", Phases.keys()[current_phase])
	
	if current_assignment_type == "tanks":
		tank_assault_plan = assignment_values.duplicate(true)
		print("Saved tank plan: ", tank_assault_plan)
	elif current_assignment_type == "troops":
		pontoon_assault_plan = assignment_values.duplicate(true)
		print("Saved troop plan: ", pontoon_assault_plan)

	print("About to call _advance_assignment_phase()...")
	_advance_assignment_phase()

func _advance_assignment_phase():
	print("=== ASSIGNMENT PHASE ROUTER ===")
	print("Current phase: ", Phases.keys()[current_phase])
	print("Assault doctrine: ", assault_doctrine)
	print("Tanks chosen: ", tanks_chosen)
	print("Tank plan empty: ", tank_assault_plan.is_empty())
	print("Troop plan empty: ", pontoon_assault_plan.is_empty())
	
	var tank_lighters_exist = monitors.filter(func(m): return m.purpose == "tank_lighter").size() > 0
	var troop_monitors_exist = monitors.filter(func(m): return m.purpose == "troop_transport").size() > 0
	
	print("Tank lighters exist: ", tank_lighters_exist)
	print("Troop monitors exist: ", troop_monitors_exist)
	
	if tank_lighters_exist and tank_assault_plan.is_empty():
		print("-> Starting tank assignment")
		current_assignment_type = "tanks"
		start_pontoon_assignment_phase()
		return
	
	if tank_lighters_exist and not tank_assault_plan.is_empty() and pontoon_assault_plan.is_empty():
		print("-> Starting troop briefing after tanks")
		start_troop_assignment_briefing_phase()
		return
	
	if troop_monitors_exist and pontoon_assault_plan.is_empty():
		print("-> Starting troop assignment")
		current_assignment_type = "troops"
		start_pontoon_assignment_phase()
		return
	
	print("-> All assignments complete, proceeding...")
	print("   Assault doctrine is: ", assault_doctrine)
	
	if assault_doctrine == "immediate":
		print("   -> Calling show_planning_summary()")
		show_planning_summary()
	else:
		print("   -> Calling resolve_pontoon_assault()")
		show_ui(UIMode.STANDARD)
		resolve_pontoon_assault()

func resolve_pontoon_assault():
	print("=== RESOLVE_PONTOON_ASSAULT CALLED ===")
	current_phase = Phases.PONTOON_ASSAULT_REPORT
	var tex = load("res://assets/landing.jpeg")
	choice_image.texture = tex
	choice_image.visible = true
	show_ui(UIMode.STANDARD)

	var report = "--- PONTOON ASSAULT REPORT ---\n\n"
	
	apply_environmental_effects()
	
	if time_of_day_effective == "morning" and morning_mist_failed:
		report += "The morning mist that was hoped to conceal our approach has failed to materialize. The pontoon flotillas advance under clear skies...\n\n"
	elif time_of_day_effective == "morning":
		report += "A blessed morning mist cloaks the pontoon monitors as they surge toward the Belgian coast...\n\n"
	elif time_of_day_effective == "night":
		report += "Under cover of darkness, the pontoon monitors navigate by compass toward their objectives...\n\n"
	else:
		report += "In full daylight, the pontoon monitors advance boldly toward the enemy shore...\n\n"

	for beach_name in assignment_order:
		report += resolve_beach_pontoon_assault(beach_name)
		report += "\n"

	report += generate_pontoon_operation_summary()

	display_text.text = report
	setup_choices(["Plan Main Force Disembarkation"])
	print("Pontoon assault resolution complete")

func apply_environmental_effects():
	time_of_day_effective = time_of_day
	morning_mist_failed = false
	
	if time_of_day == "morning" and randf() < 0.30:
		morning_mist_failed = true
		time_of_day_effective = "day"

func resolve_beach_pontoon_assault(beach_name: String) -> String:
	var report = "=== " + beach_name.to_upper() + " ===\n"
	var target_data = targets[beach_name]
	
	var monitors_assigned = pontoon_assault_plan.get(beach_name, 0)
	var tank_lighters_assigned = tank_assault_plan.get(beach_name, 0)
	var pontoon_monitors_count = 2
	
	var total_men = monitors_assigned * SOLDIERS_PER_MONITOR
	var total_tank_count = tank_lighters_assigned * TANKS_PER_LIGHTER
	
	if monitors_assigned == 0 and tank_lighters_assigned == 0:
		report += "No assault forces assigned to this beach. German defenders watch the empty waters with growing confidence.\n"
		target_data["beach_status"] = "No Assault"
		target_data["landed_force"] = 0
		target_data["operational_tanks"] = 0
		return report
	
	report += "Pontoon Assault Force: " + str(monitors_assigned) + " support monitors (" + str(total_men) + " RND troops)"
	if tank_lighters_assigned > 0:
		report += ", " + str(tank_lighters_assigned) + " tank lighters (" + str(total_tank_count) + " tanks)"
	report += "\n"
	
	var approach_results = resolve_approach_phase(beach_name, monitors_assigned, tank_lighters_assigned, pontoon_monitors_count)
	report += approach_results.report
	
	var submarine_results = resolve_submarine_phase(beach_name, approach_results.surviving_monitors, approach_results.surviving_tank_lighters, approach_results.surviving_pontoons)
	report += submarine_results.report
	
	var pontoon_results = resolve_pontoon_deployment_phase(beach_name, submarine_results.surviving_pontoons, submarine_results.surviving_monitors, submarine_results.surviving_tank_lighters)
	report += pontoon_results.report
	
	var consolidation_results = resolve_bridgehead_phase(beach_name, pontoon_results.pontoons_operational, pontoon_results.final_men, pontoon_results.final_tank_count)
	report += consolidation_results.report
	
	target_data["beach_status"] = consolidation_results.beach_status
	target_data["landed_force"] = consolidation_results.final_men
	target_data["operational_tanks"] = consolidation_results.final_tank_count
	target_data["pontoons_operational"] = pontoon_results.pontoons_operational
	
	return report

func generate_pontoon_operation_summary() -> String:
	var report = "=== PONTOON ASSAULT SUMMARY ===\n"
	
	var total_secured = 0
	var total_contested = 0
	var total_failed = 0
	var total_assault_troops = 0
	var total_operational_tanks = 0
	
	for beach_name in assignment_order:
		var status = targets[beach_name].get("beach_status", "Unknown")
		total_assault_troops += targets[beach_name].get("landed_force", 0)
		total_operational_tanks += targets[beach_name].get("operational_tanks", 0)
		
		match status:
			"Secured":
				total_secured += 1
			"Contested", "Pinned Down":
				total_contested += 1
			"Repulsed", "Failed", "No Landing":
				total_failed += 1
	
	report += "Pontoon Bridge Status: " + str(total_secured) + " operational | " + str(total_contested) + " contested | " + str(total_failed) + " failed\n"
	report += "Royal Naval Division Ashore: " + str(total_assault_troops) + " men, " + str(total_operational_tanks) + " tanks\n\n"
	
	if total_secured >= 2:
		report += "**MULTIPLE BRIDGEHEADS SECURED**: The main force can disembark across multiple pontoon bridges. Excellent prospects for the 1st Division landing.\n"
	elif total_secured == 1:
		report += "**SINGLE BRIDGEHEAD OPERATIONAL**: One pontoon bridge is secure. The main force can concentrate their disembarkation here.\n"
	elif total_contested > 0:
		report += "**CONTESTED PONTOONS**: Some bridges are under fire. Main force disembarkation will be more difficult but still possible.\n"
	else:
		report += "**ALL PONTOONS FAILED**: No bridges established. The main force must scale the 30-foot seawall under fire—casualties will be severe.\n"
	
	return report

func resolve_approach_phase(beach_name: String, monitors_count: int, tank_lighters_count: int, pontoon_monitors_count: int) -> Dictionary:
	var target_data = targets[beach_name]
	var artillery_guns = target_data.artillery
	var phase_report = ""
	
	var base_hit_chance = min(0.03 * artillery_guns, 0.25)
	
	var visibility_modifier = 1.0
	match time_of_day_effective:
		"night":
			visibility_modifier = 0.4
		"morning":
			visibility_modifier = 0.7 if not morning_mist_failed else 1.1
		"day":
			visibility_modifier = 1.2
	
	var alertness_modifier = 1.0 + (threat_level * 0.15)
	var final_hit_chance = base_hit_chance * visibility_modifier * alertness_modifier
	
	phase_report += "Approach Phase: " + str(artillery_guns) + " guns open fire (Hit chance: " + str(int(final_hit_chance * 100)) + "% per vessel)\n"
	
	var phase_results = {
		"surviving_monitors": monitors_count,
		"surviving_tank_lighters": tank_lighters_count,
		"surviving_pontoons": pontoon_monitors_count,
		"report": ""
	}
	
	for i in range(monitors_count):
		if randf() < final_hit_chance:
			var damage_roll = randf()
			if damage_roll < 0.10:
				phase_results.surviving_monitors -= 1
				phase_report += " > Troop monitor destroyed by direct hit!\n"
			elif damage_roll < 0.40:
				phase_report += " > Troop monitor crippled, landing capacity reduced.\n"
			else:
				phase_report += " > Troop monitor takes minor damage but continues.\n"
	
	for i in range(tank_lighters_count):
		if randf() < final_hit_chance:
			var damage_roll = randf()
			if damage_roll < 0.15:
				phase_results.surviving_tank_lighters -= 1
				phase_report += " > Tank lighter destroyed! Tanks lost!\n"
			else:
				phase_report += " > Tank lighter damaged but operational.\n"
	
	for i in range(pontoon_monitors_count):
		if randf() < final_hit_chance * 1.2:
			var damage_roll = randf()
			if damage_roll < 0.05:
				phase_results.surviving_pontoons -= 1
				phase_report += " > DISASTER! Pontoon monitor destroyed! Critical equipment lost!\n"
			elif damage_roll < 0.25:
				phase_report += " > Pontoon monitor hit! Pontoon equipment damaged!\n"
				target_data["pontoons_damaged_by_artillery"] = true
			else:
				phase_report += " > Pontoon monitor takes damage but pontoons intact.\n"
	
	if phase_results.surviving_monitors < monitors_count or phase_results.surviving_tank_lighters < tank_lighters_count or phase_results.surviving_pontoons < pontoon_monitors_count:
		phase_report += "Artillery fire takes its toll on the approaching flotilla.\n"
	else:
		phase_report += "The flotilla weathers the barrage and continues its approach.\n"
	
	phase_results.report = phase_report
	return phase_results

func resolve_submarine_phase(beach_name: String, monitors_count: int, tank_lighters_count: int, pontoon_monitors_count: int) -> Dictionary:
	var phase_report = ""
	var phase_results = {
		"surviving_monitors": monitors_count,
		"surviving_tank_lighters": tank_lighters_count,
		"surviving_pontoons": pontoon_monitors_count,
		"report": ""
	}
	
	var base_sub_threat = 0.05 + (threat_level * 0.02)
	
	if q_ship_assignment == "screen":
		base_sub_threat *= 0.3
		phase_report += "Q-ships screen the landing force from submarine attack.\n"
	elif q_ship_assignment == "fleet":
		base_sub_threat *= 0.8
	
	match time_of_day_effective:
		"night":
			base_sub_threat *= 1.3
		"day":
			base_sub_threat *= 0.8
	
	if randf() < base_sub_threat:
		phase_report += "SUBMARINE CONTACT! Periscope spotted off the port bow!\n"
		
		var target_roll = randf()
		if target_roll < 0.5 and pontoon_monitors_count > 0:
			var torpedo_hit = randf() < 0.6
			if torpedo_hit:
				phase_results.surviving_pontoons -= 1
				phase_report += " > Torpedo strike! Pontoon monitor sinking! Critical mission equipment lost!\n"
			else:
				phase_report += " > Torpedo narrowly misses pontoon monitor!\n"
		elif target_roll < 0.8 and monitors_count > 0:
			var torpedo_hit = randf() < 0.6
			if torpedo_hit:
				phase_results.surviving_monitors -= 1
				phase_report += " > Torpedo strike sinks troop monitor! Hundreds of men lost!\n"
			else:
				phase_report += " > Torpedo wake spotted, monitor takes evasive action!\n"
		elif tank_lighters_count > 0:
			var torpedo_hit = randf() < 0.6
			if torpedo_hit:
				phase_results.surviving_tank_lighters -= 1
				phase_report += " > Tank lighter torpedoed! Armoured support lost!\n"
			else:
				phase_report += " > Tank lighter zigzags away from torpedo track!\n"
	else:
		if q_ship_assignment == "screen":
			phase_report += "Q-ship patrols report waters clear of enemy submarines.\n"
		else:
			phase_report += "No submarine contacts reported during the approach.\n"
	
	phase_results.report = phase_report
	return phase_results

func resolve_pontoon_deployment_phase(beach_name: String, pontoon_monitors_count: int, surviving_monitors_count: int, surviving_tank_lighters_count: int) -> Dictionary:
	var target_data = targets[beach_name]
	var phase_report = ""
	
	var pontoons_operational = false
	var final_men = surviving_monitors_count * SOLDIERS_PER_MONITOR
	var final_tank_count = surviving_tank_lighters_count * TANKS_PER_LIGHTER
	
	if pontoon_monitors_count <= 0:
		phase_report += "**CRITICAL FAILURE**: No pontoon monitors survived the approach! Pontoon deployment impossible!\n"
		return {
			"pontoons_operational": false,
			"final_men": 0,
			"final_tank_count": 0,
			"report": phase_report
		}
	
	phase_report += "**PONTOON DEPLOYMENT PHASE**:\n"
	
	var pontoon_success_chance = 0.85
	
	if target_data.has("pontoons_damaged_by_artillery"):
		pontoon_success_chance = 0.40
		phase_report += "Damaged pontoon equipment complicates deployment...\n"
	
	if target_data.has("pontoons_damaged_by_friendly_fire"):
		pontoon_success_chance = 0.10
		phase_report += "Pontoons previously damaged by friendly fire are barely functional...\n"
	
	match time_of_day_effective:
		"night":
			pontoon_success_chance *= 0.8
		"day":
			pontoon_success_chance *= 1.1
	
	if randf() < pontoon_success_chance:
		pontoons_operational = true
		phase_report += "**SUCCESS!** Pontoons crash against the sea wall and lock into position!\n"
		phase_report += "The 30-foot concrete barrier is bridged. A functional landing platform is established!\n"
	else:
		pontoons_operational = false
		phase_report += "**PONTOON FAILURE!** The deployment goes disastrously wrong!\n"
		phase_report += "Without pontoon bridges, the main force will face the nightmare of scaling the 30-foot seawall under fire!\n"
		
		var deployment_casualty_rate = 0.25
		var deployment_casualties = int(final_men * deployment_casualty_rate)
		final_men -= deployment_casualties
		phase_report += str(deployment_casualties) + " RND casualties during the failed pontoon deployment!\n"
	
	return {
		"pontoons_operational": pontoons_operational,
		"final_men": final_men,
		"final_tank_count": final_tank_count,
		"report": phase_report
	}

func resolve_bridgehead_phase(beach_name: String, pontoons_operational: bool, men_count: int, tank_count: int) -> Dictionary:
	var target_data = targets[beach_name]
	var garrison = target_data.garrison
	var artillery = target_data.artillery
	var phase_report = ""
	
	if men_count <= 0:
		return {
			"beach_status": "Failed",
			"final_men": 0,
			"final_tank_count": 0,
			"report": "No effective force remains to secure the pontoon bridgehead.\n"
		}
	
	var attacker_strength = men_count
	var final_tank_count = tank_count
	
	if pontoons_operational and tank_count > 0:
		attacker_strength += tank_count * TANK_COMBAT_BONUS
		phase_report += "Tanks advance off the pontoons to establish a protective perimeter.\n"
	elif tank_count > 0:
		var tank_casualties = int(tank_count * 0.6)
		final_tank_count -= tank_casualties
		attacker_strength += final_tank_count * (TANK_COMBAT_BONUS * 0.3)
		phase_report += str(tank_casualties) + " tanks lost attempting to scale the sea wall!\n"
	
	var defender_strength = garrison + (artillery * 200)
	
	var combat_modifier = 1.0
	if pontoons_operational:
		combat_modifier = 1.5
	
	match time_of_day_effective:
		"night":
			combat_modifier *= 1.2
		"day":
			combat_modifier *= 0.9
	
	attacker_strength = int(attacker_strength * combat_modifier)
	
	var strength_ratio = float(attacker_strength) / float(defender_strength)
	var beach_status = ""
	var final_men_count = men_count
	
	if strength_ratio >= 1.5:
		beach_status = "Secured"
		if pontoons_operational:
			phase_report += "The pontoon bridgehead is secured. German defenders withdraw to secondary positions.\n"
			phase_report += "The promenade is cleared and ready for the main force embarkation.\n"
		else:
			phase_report += "Despite the pontoon failure, our forces secure a foothold on the sea wall.\n"
			phase_report += "Engineers work frantically to establish alternative landing points.\n"
	elif strength_ratio >= 1.0:
		beach_status = "Contested"
		if pontoons_operational:
			phase_report += "Fierce fighting around the pontoons. We hold the bridgehead but under pressure.\n"
			phase_report += "German counter-attacks threaten the pontoon connections.\n"
		else:
			phase_report += "Desperate fighting on the sea wall. Our forces cling to their precarious positions.\n"
			phase_report += "Without pontoons, reinforcement will be extremely difficult.\n"
		var combat_casualties = int(final_men_count * 0.25)
		final_men_count -= combat_casualties
		phase_report += str(combat_casualties) + " casualties in the fierce fighting.\n"
	elif strength_ratio >= 0.6:
		beach_status = "Pinned Down"
		if pontoons_operational:
			phase_report += "Heavy resistance pins down our forces near the pontoons.\n"
			phase_report += "German machine guns command the landing area despite the bridges.\n"
		else:
			phase_report += "Our forces are pinned down on the narrow sea wall.\n"
			phase_report += "Without pontoons, the position is nearly untenable.\n"
		var combat_casualties = int(final_men_count * 0.40)
		final_men_count -= combat_casualties
		phase_report += str(combat_casualties) + " casualties under withering defensive fire.\n"
	else:
		beach_status = "Repulsed"
		if pontoons_operational:
			phase_report += "Despite the pontoons being in place, overwhelming enemy fire repels our assault.\n"
			phase_report += "Survivors retreat to the pontoon bridges under heavy casualties.\n"
		else:
			phase_report += "The assault collapses completely. Without pontoons and facing fierce resistance,\n"
			phase_report += "survivors cling to the base of the sea wall or retreat to the water.\n"
		var combat_casualties = int(final_men_count * 0.60)
		final_men_count -= combat_casualties
		phase_report += str(combat_casualties) + " casualties. The bridgehead assault has failed.\n"
	
	return {
		"beach_status": beach_status,
		"final_men": final_men_count,
		"final_tank_count": final_tank_count,
		"report": phase_report
	}

func start_main_force_embarkation_phase():
	print("--- Starting Main Force Embarkation Phase ---")
	current_phase = Phases.MAIN_FORCE_EMBARKATION_ASSIGNMENT
	
	show_ui(UIMode.MAIN_FORCE_EMBARKATION)
	
	display_text.text = "--- MAIN FORCE EMBARKATION & ASSIGNMENT ---\nThe pontoon assault is complete. Based on the results, re-assign 1st Division units between beachheads as required. Units will cross in trawlers and barges—the logistical requirements (barges needed) will update with each change."
	
	await draw_embarkation_ui()

func resolve_main_force_disembarkation():
	print("--- DETAILED MAIN FORCE DISEMBARKATION ---")
	current_phase = Phases.MAIN_FORCE_DISEMBARKATION_REPORT
	show_ui(UIMode.STANDARD)
	
	organize_units_into_barges()
	var beach_threats = calculate_beach_threats()
	var report = execute_main_force_disembarkation(beach_threats)
	
	display_text.text = report
	setup_choices(["View Intelligence Report"])

func organize_units_into_barges():
	barge_manifest.clear()
	
	for beach_name in assignment_order:
		barge_manifest[beach_name] = []
	
	for unit in division_order_of_battle:
		var dest = unit.current_dest
		var remaining_strength = unit.strength
		var barge_number = 1
		
		while remaining_strength > 0:
			var men_in_barge = min(remaining_strength, SOLDIERS_PER_BARGE)
			var barge_data = {
				"unit_name": unit.name,
				"unit_id": unit.id,
				"men": men_in_barge,
				"barge_id": unit.id + "_barge_" + str(barge_number),
				"status": "En Route",
				"casualties": 0
			}
			
			barge_manifest[dest].append(barge_data)
			remaining_strength -= men_in_barge
			barge_number += 1
	
	for beach in barge_manifest:
		print("Beach ", beach, " has ", barge_manifest[beach].size(), " barges")

func calculate_beach_threats():
	var threats = {}
	
	for beach_name in assignment_order:
		var threat_data = {
			"artillery": 0,
			"u_boat": 0,
			"reinforcements": 0,
			"pontoon_factor": 1.0,
			"total_threat": 0.0
		}
		
		var target_data = targets[beach_name]
		
		threat_data.artillery = target_data.artillery * 3
		threat_data.u_boat = 2 + threat_level
		if q_ship_assignment == "screen":
			threat_data.u_boat *= 0.3
		
		threat_data.reinforcements = threat_level * 2
		
		var beach_status = target_data.get("beach_status", "Unknown")
		if beach_status == "Repulsed":
			threat_data.pontoon_factor = 3.0
			pontoon_status[beach_name] = false
		elif beach_status == "Contested":
			threat_data.pontoon_factor = 1.5
			pontoon_status[beach_name] = true
		else:
			threat_data.pontoon_factor = 1.0
			pontoon_status[beach_name] = true
		
		threat_data.total_threat = (threat_data.artillery + threat_data.u_boat + threat_data.reinforcements) * threat_data.pontoon_factor / 100.0
		
		threats[beach_name] = threat_data
		print("Beach ", beach_name, " total threat: ", threat_data.total_threat * 100, "%")
	
	return threats

func execute_main_force_disembarkation(beach_threats):
	var report = "--- MAIN FORCE DISEMBARKATION REPORT ---\n\n"
	report += "With the pontoon assault complete, the signal is given. Across the grey waters, trawlers and barges packed with the men of the 1st Division surge toward the Belgian coast...\n\n"

	var total_men_lost_op = 0
	var total_barges_lost_op = 0

	for beach_name in assignment_order:
		report += "=== " + beach_name.to_upper() + " ===\n"
		var beach_barges = barge_manifest[beach_name]

		if pontoon_status[beach_name]:
			report += "**PONTOON BRIDGES OPERATIONAL**: The main force can disembark directly onto the promenade!\n"
		else:
			report += "**NO PONTOON BRIDGES**: Men must scale the 30-foot seawall under heavy fire!\n"

		var initial_artillery = initial_targets_state[beach_name].get("artillery", 1)
		if initial_artillery == 0: initial_artillery = 1
		var current_artillery = targets[beach_name].get("artillery", 0)
		
		var artillery_modifier = float(current_artillery) / float(initial_artillery)
		var time_modifier = 1.0
		if time_of_day_effective == "night": time_modifier = 0.4
		elif time_of_day_effective == "morning": time_modifier = 0.7
		elif time_of_day_effective == "day": time_modifier = 1.1

		var final_barge_hit_chance = BASE_BARGE_HIT_CHANCE * artillery_modifier * time_modifier

		var barges_lost_this_beach = 0

		for barge in beach_barges:
			barge.casualties = 0
			if randf() < final_barge_hit_chance:
				var hit_effect_roll = randf()
				if hit_effect_roll < 0.10:
					barge.status = "Lost"
					barge.casualties = barge.men
					barges_lost_this_beach += 1
				elif hit_effect_roll < 0.50:
					barge.status = "Disorganized"
					barge.casualties = floori(barge.men * randf_range(0.10, 0.20))
				else:
					barge.status = "Shaken"
			else:
				barge.status = "Landed"

		report += "Approach Results: Of " + str(beach_barges.size()) + " barges, " + str(barges_lost_this_beach) + " were lost, and scattered by shellfire.\n"

		var seawall_casualties_this_beach = 0
		if not pontoon_status[beach_name]:
			report += "**SCALING THE SEAWALL**: Without pontoon bridges, men must climb the 30-foot concrete wall under machine gun fire!\n"
			
			var initial_garrison = initial_targets_state[beach_name].get("garrison", 1)
			if initial_garrison == 0: initial_garrison = 1
			var current_garrison = targets[beach_name].get("garrison", 0)
			
			var garrison_modifier = float(current_garrison) / float(initial_garrison)
			var final_seawall_casualty_rate = BASE_SEAWALL_CASUALTY_RATE * garrison_modifier

			for barge in beach_barges:
				if barge.status != "Lost":
					var surviving_men = barge.men - barge.casualties
					var casualties_from_wall = floori(surviving_men * final_seawall_casualty_rate)
					barge.casualties += casualties_from_wall
					seawall_casualties_this_beach += casualties_from_wall
			
			if seawall_casualties_this_beach > 0:
				report += "The division suffered an additional " + str(seawall_casualties_this_beach) + " casualties scaling the wall.\n"
		else:
			report += "**PONTOON DISEMBARKATION**: The main force disembarks directly onto the promenade via the pontoon bridges!\n"

		var landed_survivors = 0
		var beach_total_casualties = 0
		for barge in beach_barges:
			if barge.status != "Lost":
				landed_survivors += (barge.men - barge.casualties)
			beach_total_casualties += barge.casualties
		
		total_men_lost_op += beach_total_casualties
		total_barges_lost_op += barges_lost_this_beach
		
		if not targets[beach_name].has("landed_force"):
			targets[beach_name]["landed_force"] = 0
		targets[beach_name]["landed_force"] += landed_survivors

		report += "Total Beach Casualties: " + str(beach_total_casualties) + " men.\n"
		report += "Effective Force Disembarked: " + str(landed_survivors) + " men are ashore and forming up.\n\n"

	report += "=== MAIN FORCE DISEMBARKATION SUMMARY ===\n"
	report += "Total Barges Lost: " + str(total_barges_lost_op) + "\n"
	report += "Total Casualties (KIA & Wounded): " + str(total_men_lost_op) + " men\n\n"

	if total_men_lost_op > 4000:
		report += "The losses are catastrophic. The beaches run red with the blood of Britain's finest..."
	elif total_men_lost_op > 1500:
		report += "The cost has been heavy, but the Division has secured its foothold on Belgian soil."
	else:
		report += "Remarkably light casualties for such a daring operation. The men are ashore and ready for action."

	return report

# Assignment input handling
func handle_assignment_input(choice: String):
	print("handle_assignment_input called with choice: ", choice)
	
	var is_pontoon = (current_phase == Phases.PONTOON_ASSIGNMENT)
	
	var type = ""
	var total_units = 0
	var plan = {}
	
	if is_pontoon:
		type = "troops"
		if tanks_chosen and not tank_assault_plan.has(assignment_order.back()):
			type = "tanks"
		total_units = monitors.filter(func(m): return m["carries"] == type).size()
		plan = tank_assault_plan if type == "tanks" else pontoon_assault_plan
	else:
		total_units = TOTAL_REINFORCEMENT_BARGES
		plan = main_force_plan
		
	var assigned_so_far = 0
	for beach in plan: assigned_so_far += plan[beach]
	var remaining = total_units - assigned_so_far
	
	print("Type: ", type, " | Remaining: ", remaining, " | Current temp value: ", temp_assignment_value)
	
	if choice == "➖":
		temp_assignment_value = max(0, temp_assignment_value - 1)
		print("Decreased to: ", temp_assignment_value)
	elif choice == "➕":
		temp_assignment_value = min(remaining, temp_assignment_value + 1)
		print("Increased to: ", temp_assignment_value)
	elif choice == "Assign":
		print("Assigning ", temp_assignment_value, " units")
		if is_pontoon:
			process_pontoon_assignment(str(temp_assignment_value))
		else:
			process_main_force_assignment(str(temp_assignment_value))
		return
		
	# Redraw the UI after a +/- press
	if is_pontoon:
		ask_for_next_pontoon_assignment(type)
	else:
		ask_for_next_main_force_assignment()

func process_pontoon_assignment(player_input):
	var type = "troops"
	if tanks_chosen and not tank_assault_plan.has(assignment_order.back()): type = "tanks"
	var plan = tank_assault_plan if type == "tanks" else pontoon_assault_plan
	var num_assigned = int(player_input)
	var current_beach = assignment_order[current_assignment_index]
	plan[current_beach] = num_assigned
	current_assignment_index += 1
	var assigned_so_far = 0
	for beach in plan: assigned_so_far += plan[beach]
	var total_vessels = monitors.filter(func(m): return m["carries"] == type).size()
	if assigned_so_far >= total_vessels or current_assignment_index >= assignment_order.size():
		var remaining = total_vessels - assigned_so_far
		if current_assignment_index < assignment_order.size():
			plan[assignment_order[current_assignment_index]] = remaining
		while current_assignment_index < assignment_order.size():
			if not plan.has(assignment_order[current_assignment_index]):
				plan[assignment_order[current_assignment_index]] = 0
			current_assignment_index += 1
		if type == "tanks":
			current_assignment_index = 0
			ask_for_next_pontoon_assignment("troops")
		else:
			resolve_pontoon_assault()
	else:
		ask_for_next_pontoon_assignment(type)

func ask_for_next_pontoon_assignment(type):
	temp_assignment_value = 0
	var total_vessels = monitors.filter(func(m): return m["carries"] == type).size()
	var plan = tank_assault_plan if type == "tanks" else pontoon_assault_plan
	var vessel_name = "Tank Lighters" if type == "tanks" else "Pontoon Support Monitors"
	var assigned = 0
	for beach in plan: assigned += plan[beach]
	var remaining = total_vessels - assigned
	var current_beach = assignment_order[current_assignment_index]
	var message = "--- " + vessel_name.to_upper() + " ASSIGNMENT ---\n\n"
	message += "You have " + str(remaining) + " " + vessel_name + " remaining.\n"
	message += "Assign to " + current_beach + ":\n\n"
	message += "         " + str(temp_assignment_value) + "         \n"
	display_text.text = message
	setup_choices(["➖", "➕", "Assign"])

# Main Force Assignment Functions
func start_main_force_assignment_phase():
	current_phase = Phases.MAIN_FORCE_ASSIGNMENT
	current_assignment_index = 0
	main_force_plan = {}
	ask_for_next_main_force_assignment()

func ask_for_next_main_force_assignment():
	temp_assignment_value = 0
	var assigned = 0
	for beach in main_force_plan: assigned += main_force_plan[beach]
	var remaining = TOTAL_REINFORCEMENT_BARGES - assigned
	var current_beach = assignment_order[current_assignment_index]
	var message = "--- MAIN FORCE PHASE ---\n\n"
	for beach_name in assignment_order:
		message += " > " + beach_name + ": " + targets[beach_name].get("beach_status", "Unknown") + "\n"
	message += "\nYou have " + str(remaining) + " trawlers remaining.\n"
	message += "Assign to " + current_beach + ":\n\n"
	message += "         " + str(temp_assignment_value) + "         \n"
	display_text.text = message
	setup_choices(["➖", "➕", "Assign"])

func process_main_force_assignment(player_input):
	var num = int(player_input)
	var current_beach = assignment_order[current_assignment_index]
	main_force_plan[current_beach] = num
	current_assignment_index += 1
	var assigned_so_far = 0
	for beach in main_force_plan: assigned_so_far += main_force_plan[beach]
	var remaining = TOTAL_REINFORCEMENT_BARGES - assigned_so_far
	if current_assignment_index >= assignment_order.size() - 1:
		main_force_plan[assignment_order.back()] = remaining
		resolve_main_force_disembarkation()
	else:
		ask_for_next_main_force_assignment()

# Consolidation and End Game Functions
func start_spy_report_phase():
	current_phase = Phases.SPY_REPORT
	var tex = load("res://assets/break.jpg")
	choice_image.texture = tex
	choice_image.visible = true
	display_text.text = "--- FIELD INTELLIGENCE REPORT ---\n\n(Agent reports enemy movements...)"
	setup_choices(["Begin Consolidation Phase"])

func start_consolidation_phase():
	current_phase = Phases.CONSOLIDATION_ASSIGNMENT
	consolidation_turn_current = 1
	current_assignment_index = 0
	consolidation_plan.clear()
	rfc_used_this_turn = false
	ask_for_next_consolidation_order()

func ask_for_next_consolidation_order():
	var current_beach = assignment_order[current_assignment_index]
	var beach_data = targets[current_beach]
	var status = beach_data.get("beach_status", "No Landing")
	var message = "--- CONSOLIDATION — TURN " + str(consolidation_turn_current) + " ---\n\n"
	message += "Orders for " + current_beach + " (Status: " + status + ")\n"
	message += "Landed Force: ~" + str(beach_data.get("landed_force", 0)) + " men, " + str(beach_data.get("operational_tanks", 0)) + " tanks.\n"
	display_text.text = message
	if status == "Secured" or status == "Dominant":
		setup_choices(["Assault Battery", "Naval Support", "Push Inland"])
	elif status == "Pinned Down":
		setup_choices(["Assault (Desperate)", "Naval Support", "Dig In"])
	else:
		setup_choices(["Do Nothing"])

func process_consolidation_choice(choice):
	var current_beach = assignment_order[current_assignment_index]
	var status = targets[current_beach].get("beach_status", "No Landing")
	var action = ""
	if status == "Secured" or status == "Dominant":
		if choice == "Assault Battery": action = "assault_battery"
		elif choice == "Naval Support": action = "naval_support"
		elif choice == "Push Inland": action = "push_inland"
	elif status == "Pinned Down":
		if choice == "Assault (Desperate)": action = "assault_battery"
		elif choice == "Naval Support": action = "naval_support"
		elif choice == "Dig In": action = "dig_in"
	else:
		action = "dig_in"
	consolidation_plan[current_beach] = {"action": action}
	current_assignment_index += 1
	if current_assignment_index < assignment_order.size():
		ask_for_next_consolidation_order()
	else:
		resolve_consolidation_turn()

func resolve_consolidation_turn():
	current_phase = Phases.CONSOLIDATION_RESOLUTION
	var report = "--- CONSOLIDATION TURN " + str(consolidation_turn_current) + " REPORT ---\n\n(Player and enemy actions are resolved...)"
	display_text.text = report
	if consolidation_turn_current < consolidation_turns_total:
		setup_choices(["Plan Next Turn (" + str(consolidation_turn_current + 1) + ")"])
	else:
		setup_choices(["See Final Outcome"])

func _advance_to_next_consolidation_turn():
	consolidation_turn_current += 1
	rfc_used_this_turn = false
	consolidation_plan.clear()
	current_assignment_index = 0
	ask_for_next_consolidation_order()

func process_redeployment_destination(choice):
	var destination = ""
	var valid_options = []
	for beach in assignment_order:
		if beach != temp_redeployment_source:
			valid_options.append(beach)
	var choice_index = int(choice) - 1
	if choice_index >= 0 and choice_index < valid_options.size():
		destination = valid_options[choice_index]
	else:
		temp_redeployment_source = ""
		ask_for_next_consolidation_order()
		return
	consolidation_plan[temp_redeployment_source] = {"action": "redeploy", "to": destination}
	temp_redeployment_source = ""
	current_assignment_index += 1
	if current_assignment_index < assignment_order.size():
		ask_for_next_consolidation_order()
	else:
		resolve_consolidation_turn()

func determine_final_outcome():
	current_phase = Phases.FINAL_OUTCOME
	display_text.text = "--- FINAL OPERATION OUTCOME ---\n\n(Victory or Stalemate...)"
	setup_choices(["View Roll of Honour"])

func start_roll_of_honour_phase():
	current_phase = Phases.FINAL_ROLL_OF_HONOUR
	display_text.text = "--- OPERATION HUSH: ROLL OF HONOUR ---\n\n(Casualties are tallied...)"
	setup_choices(["Operation Complete"])

# Helper Functions
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

func apply_monitor_costs(cost):
	var decommissioned = 0
	for m in monitors:
		if m.purpose == "troop_transport" and decommissioned < cost:
			m.name = "Support Vessel " + str(decommissioned + 1)
			m.purpose = "support"
			m.carries = "support"
			m.soldiers = 0
			decommissioned += 1

func bombard_target(target_name):
	var target = targets[target_name]
	
	var active_ships = _get_active_fire_support()
	if active_ships.is_empty():
		return

	var total_firepower = 0
	for ship in active_ships:
		if ship.get("class") == "qe":
			total_firepower += 20
		elif ship.get("class") == "tribal":
			total_firepower += 4

	var spotting_multiplier = 1.0
	if bombardment_plan == "bacon":
		spotting_multiplier = 1.75
	elif bombardment_plan == "balloons":
		spotting_multiplier = 1.35

	var time_multiplier = 1.0
	if time_of_day_effective == "night":
		time_multiplier = 0.5
	elif time_of_day_effective == "morning":
		time_multiplier = 0.8

	var final_firepower = total_firepower * spotting_multiplier * time_multiplier
	var base_effectiveness = final_firepower / 150.0

	var artillery_reduction_percent = 0.0
	var garrison_reduction_percent = 0.0
	
	if naval_bombardment_target_focus == "batteries":
		artillery_reduction_percent = base_effectiveness
		garrison_reduction_percent = base_effectiveness * 0.3
	elif naval_bombardment_target_focus == "garrison":
		artillery_reduction_percent = base_effectiveness * 0.3
		garrison_reduction_percent = base_effectiveness
	elif naval_bombardment_target_focus == "split":
		artillery_reduction_percent = base_effectiveness * 0.7
		garrison_reduction_percent = base_effectiveness * 0.7
		
	artillery_reduction_percent *= randf_range(0.85, 1.15)
	garrison_reduction_percent *= randf_range(0.85, 1.15)

	var art_damage = floori(target.artillery * artillery_reduction_percent)
	var gar_damage = floori(target.garrison * garrison_reduction_percent)
	
	target.artillery = max(0, target.artillery - art_damage)
	target.garrison  = max(0, target.garrison  - gar_damage)

func _get_active_fire_support() -> Array:
	var roster: Array = []
	if typeof(naval_support_ships) == TYPE_ARRAY and not naval_support_ships.is_empty():
		for s in naval_support_ships:
			if typeof(s) == TYPE_DICTIONARY and s.get("status", "Ready") == "Ready":
				roster.append(s)
	return roster

# UI Helper Functions
func show_ui(mode: UIMode):
	standard_ui.visible = false
	pontoon_assignment_ui.visible = false
	embarkation_ui.visible = false
	
	match mode:
		UIMode.STANDARD:
			standard_ui.visible = true
		UIMode.PONTOON_ASSIGNMENT:
			pontoon_assignment_ui.visible = true
		UIMode.MAIN_FORCE_EMBARKATION:
			embarkation_ui.visible = true

func _create_and_apply_theme():
	var new_theme = Theme.new()
	var default_font = load("res://assets/cour.ttf")
	var font_color = Color("6631df")
	var background_color = Color("f7f0e6")
	
	var bg_stylebox = StyleBoxFlat.new()
	bg_stylebox.bg_color = background_color
	
	new_theme.set_font("font", "Control", default_font)
	new_theme.set_font_size("font_size", "Control", 16)
	new_theme.set_color("font_color", "Control", font_color)
	new_theme.set_stylebox("panel", "Control", bg_stylebox)
	
	self.theme = new_theme

func setup_simple_layout():
	await get_tree().process_frame
	
	var viewport_size = get_viewport().get_visible_rect().size
	print("Viewport size: ", viewport_size)
	
	if ui_container:
		var padding = 20
		ui_container.position = Vector2(padding, padding)
		ui_container.size = Vector2(viewport_size.x - (padding * 2), viewport_size.y - (padding * 2))
		print("UIContainer set to: ", ui_container.size, " with padding: ", padding)
	
	if standard_ui:
		standard_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		standard_ui.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		standard_ui.size_flags_vertical = Control.SIZE_EXPAND_FILL
		
		print("StandardGameUI type: ", standard_ui.get_class())
		if standard_ui is VBoxContainer:
			print("StandardGameUI IS a VBoxContainer - good!")
			(standard_ui as VBoxContainer).add_theme_constant_override("separation", 10)
		else:
			print("ERROR: StandardGameUI is NOT a VBoxContainer - this is the problem!")
		
		print("StandardGameUI should fill parent")
	
	if choice_image:
		choice_image.custom_minimum_size = Vector2(0, 250)
		choice_image.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		choice_image.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		choice_image.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		print("ChoiceImage parent: ", choice_image.get_parent().name if choice_image.get_parent() else "no parent")
	
	if display_text and display_text.get_parent():
		var scroll_container = display_text.get_parent()
		print("ScrollContainer found: ", scroll_container.name)
		
		scroll_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll_container.custom_minimum_size = Vector2(500, 300)
		
		display_text.fit_content = false
		display_text.scroll_active = false
		display_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		display_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
		display_text.custom_minimum_size = Vector2(500, 200)
		
		var theme_font_color = Color("6631df")
		display_text.add_theme_color_override("default_color", theme_font_color)
		display_text.add_theme_color_override("font_color", theme_font_color)
		
		display_text.bbcode_enabled = true
		print("RichTextLabel and ScrollContainer configured")
	
	if choice_container:
		choice_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		choice_container.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		choice_container.custom_minimum_size = Vector2(0, 50)
		print("ChoiceContainer parent: ", choice_container.get_parent().name if choice_container.get_parent() else "no parent")
	
	for button in choice_buttons:
		if button:
			button.custom_minimum_size = Vector2(150, 40)
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL

func draw_embarkation_ui():
	for child in middelkerke_unit_list.get_children(): 
		child.queue_free()
	for child in westende_unit_list.get_children(): 
		child.queue_free()
	for child in nieuwpoort_unit_list.get_children(): 
		child.queue_free()

	await get_tree().process_frame
	force_container_sizing()

	var beach_data = {
		"Middelkerke Bains": {
			"strength": 0, 
			"unit_list": middelkerke_unit_list, 
			"stats_label": middelkerke_stats,
			"other_beaches": ["Westende Bains", "Nieuwpoort Bains"]
		},
		"Westende Bains": {
			"strength": 0, 
			"unit_list": westende_unit_list, 
			"stats_label": westende_stats,
			"other_beaches": ["Middelkerke Bains", "Nieuwpoort Bains"]
		},
		"Nieuwpoort Bains": {
			"strength": 0, 
			"unit_list": nieuwpoort_unit_list, 
			"stats_label": nieuwpoort_stats,
			"other_beaches": ["Middelkerke Bains", "Westende Bains"]
		}
	}

	for unit in division_order_of_battle:
		var dest = unit.current_dest
		beach_data[dest].strength += unit.strength
		var unit_row = create_unit_row(unit, beach_data[dest].other_beaches)
		beach_data[dest].unit_list.add_child(unit_row)

	var total_barges = 0
	for beach_name in beach_data:
		var data = beach_data[beach_name]
		var strength = data.strength
		var barges = ceil(strength / float(SOLDIERS_PER_BARGE))
		total_barges += barges
		
		data.stats_label.text = "Str: " + str(strength) + " | Barges: " + str(barges)
		data.stats_label.add_theme_color_override("font_color", Color("6631df"))
		data.stats_label.add_theme_font_size_override("font_size", 10)

	summary_label.text = "Total Barges: " + str(total_barges) + " / " + str(TOTAL_REINFORCEMENT_BARGES)
	summary_label.add_theme_color_override("font_color", Color("6631df"))
	summary_label.add_theme_font_size_override("font_size", 12)
	
	setup_embarkation_footer()

func force_container_sizing():
	var scroll_containers = [
		middelkerke_unit_list.get_parent(),
		westende_unit_list.get_parent(),     
		nieuwpoort_unit_list.get_parent()
	]
	
	for scroll_container in scroll_containers:
		if scroll_container:
			scroll_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
			scroll_container.custom_minimum_size = Vector2(130, 500)
	
	var unit_lists = [middelkerke_unit_list, westende_unit_list, nieuwpoort_unit_list]
	for unit_list in unit_lists:
		if unit_list:
			unit_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			unit_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
			unit_list.custom_minimum_size = Vector2(130, 500)

func create_unit_row(unit_data: Dictionary, other_beaches: Array) -> Control:
	var row = VBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 25)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var unit_label = Label.new()
	unit_label.text = unit_data.name + " [" + str(unit_data.strength) + "]"
	unit_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	unit_label.add_theme_color_override("font_color", Color("6631df"))
	unit_label.add_theme_font_size_override("font_size", 10)
	unit_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	unit_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	row.add_child(unit_label)
	
	var button_container = HBoxContainer.new()
	button_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	for i in range(other_beaches.size()):
		var beach_name = other_beaches[i]
		var button = Button.new()
		
		var beach_initial = beach_name.substr(0, 1)
		button.text = "→" + beach_initial
		button.custom_minimum_size = Vector2(25, 16)
		button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		
		button.add_theme_color_override("font_color", Color.WHITE)
		button.add_theme_font_size_override("font_size", 8)
		
		var button_style = StyleBoxFlat.new()
		button_style.bg_color = Color("6631df")
		button_style.corner_radius_top_left = 2
		button_style.corner_radius_top_right = 2
		button_style.corner_radius_bottom_left = 2
		button_style.corner_radius_bottom_right = 2
		button.add_theme_stylebox_override("normal", button_style)
		button.add_theme_stylebox_override("pressed", button_style)
		button.add_theme_stylebox_override("hover", button_style)
		
		button.pressed.connect(_on_reassign_unit.bind(unit_data, beach_name))
		
		button_container.add_child(button)
		
		if i < other_beaches.size() - 1:
			var spacer = Control.new()
			spacer.custom_minimum_size = Vector2(2, 0)
			button_container.add_child(spacer)
	
	row.add_child(button_container)
	
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 3)
	row.add_child(spacer)
	
	return row

func setup_embarkation_footer():
	if not embarkation_ui.has_node("InstructionsLabel"):
		var instructions = Label.new()
		instructions.name = "InstructionsLabel"
		instructions.text = "Use the →M, →W, →N buttons to reassign units between beaches. Barge requirements update automatically."
		instructions.add_theme_color_override("font_color", Color("6631df"))
		instructions.add_theme_font_size_override("font_size", 11)
		instructions.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		instructions.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		instructions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		embarkation_ui.add_child(instructions)
		embarkation_ui.move_child(instructions, embarkation_ui.get_child_count() - 2)
	
	if confirm_button:
		confirm_button.add_theme_color_override("font_color", Color.WHITE)
		confirm_button.add_theme_font_size_override("font_size", 14)
		
		var confirm_style = StyleBoxFlat.new()
		confirm_style.bg_color = Color("6631df")
		confirm_style.corner_radius_top_left = 5
		confirm_style.corner_radius_top_right = 5
		confirm_style.corner_radius_bottom_left = 5
		confirm_style.corner_radius_bottom_right = 5
		confirm_button.add_theme_stylebox_override("normal", confirm_style)
		confirm_button.add_theme_stylebox_override("pressed", confirm_style)
		confirm_button.add_theme_stylebox_override("hover", confirm_style)

func _on_reassign_unit(unit_data: Dictionary, new_destination: String):
	unit_data.current_dest = new_destination
	await draw_embarkation_ui()

func get_unit_casualties():
	var casualties = {}
	
	for beach_name in barge_manifest:
		for barge in barge_manifest[beach_name]:
			if barge.casualties > 0:
				if not casualties.has(barge.unit_name):
					casualties[barge.unit_name] = 0
				casualties[barge.unit_name] += barge.casualties
	
	return casualties

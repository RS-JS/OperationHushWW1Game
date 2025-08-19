extends Control

# --- Node References ---
@onready var display_text = $UIContainer/StandardGameUI/ScrollContainer/DisplayText
@onready var ui_container = $UIContainer
@onready var choice_image = $UIContainer/StandardGameUI/ChoiceImage

# --- Module References ---
var ui_manager: UIManager
var combat_calculator: CombatCalculator
var data_manager: DataManager
var assignment_manager: AssignmentManager
var main_force_manager: MainForceManager
var consolidation_manager: ConsolidationManager

# --- Game State ---
enum Phases {
	START_GAME, INTELLIGENCE_BRIEFING, PLAN_OVERVIEW, NAVAL_SUPPORT_DECISION, NAVAL_SUPPORT_RESOLUTION, 
	NAVAL_BOMBARDMENT_TARGETING_DECISION, ARMOUR_DECISION, ARMOUR_RESOLUTION, BOMBARDMENT_PLAN_DECISION,
	Q_SHIP_DECISION, TIME_OF_DAY_DECISION, AIR_DOCTRINE_DECISION, ASSAULT_DOCTRINE_DECISION,
	PLANNING_SUMMARY, BOMBARDMENT_REPORT, MONITOR_ASSIGNMENT_BRIEFING, TROOP_ASSIGNMENT_BRIEFING, 
	PONTOON_ASSIGNMENT, PONTOON_ASSAULT_REPORT, MAIN_FORCE_EMBARKATION_ASSIGNMENT, MAIN_FORCE_ASSIGNMENT,
	MAIN_FORCE_DISEMBARKATION_REPORT, SPY_REPORT, CONSOLIDATION_ASSIGNMENT, CONSOLIDATION_RESOLUTION, 
	FINAL_OUTCOME, FINAL_ROLL_OF_HONOUR
}

var current_phase = Phases.START_GAME

# --- Game Initialization ---
func _ready():
	randomize()
	initialize_modules()
	ui_manager.setup_ui()
	start_new_game()

func initialize_modules():
	# Create module instances
	data_manager = DataManager.new()
	ui_manager = UIManager.new()
	combat_calculator = CombatCalculator.new()
	assignment_manager = AssignmentManager.new()
	main_force_manager = MainForceManager.new()
	consolidation_manager = ConsolidationManager.new()
	
	# Pass references between modules
	ui_manager.setup_references(self, data_manager)
	combat_calculator.setup_references(data_manager)
	assignment_manager.setup_references(self, data_manager, ui_manager)
	main_force_manager.setup_references(data_manager, ui_manager)
	consolidation_manager.setup_references(data_manager, ui_manager)
	
	# Connect signals
	ui_manager.choice_made.connect(_on_choice_made)
	assignment_manager.assignment_complete.connect(_on_assignment_complete)
	consolidation_manager.consolidation_complete.connect(_on_consolidation_complete)

func start_new_game():
	data_manager.initialize_game_data()
	current_phase = Phases.START_GAME
	start_game_phase()

# --- Signal Handlers ---
func _on_choice_made(choice: String):
	print("Choice made: ", choice, " in phase: ", Phases.keys()[current_phase])
	
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
			handle_bombardment_completion()
		Phases.MONITOR_ASSIGNMENT_BRIEFING:
			start_assignment_phases()
		Phases.PONTOON_ASSAULT_REPORT:
			start_main_force_embarkation_phase()
		Phases.MAIN_FORCE_EMBARKATION_ASSIGNMENT: 
			var report = main_force_manager.resolve_main_force_disembarkation()
			current_phase = Phases.MAIN_FORCE_DISEMBARKATION_REPORT
			ui_manager.show_standard_ui()
			ui_manager.display_message(report)
			ui_manager.setup_choices(["View Intelligence Report"])
		Phases.MAIN_FORCE_DISEMBARKATION_REPORT: 
			start_spy_report_phase()
		Phases.SPY_REPORT:
			consolidation_manager.start_consolidation_phase()
		_:
			print("Unhandled phase: ", Phases.keys()[current_phase])

func _on_assignment_complete():
	# Called when assignment manager completes all assignments
	var assault_report = combat_calculator.resolve_pontoon_assault()
	current_phase = Phases.PONTOON_ASSAULT_REPORT
	ui_manager.show_standard_ui()
	ui_manager.display_message(assault_report)
	ui_manager.setup_choices(["Plan Main Force Disembarkation"])

func _on_consolidation_complete():
	# Handle completion of consolidation phase
	print("Operation Hush Complete!")
	ui_manager.setup_choices([])  # Clear any remaining choices

# --- Phase Management ---
func start_game_phase():
	ui_manager.show_standard_ui()
	ui_manager.set_image("res://assets/Map.jpeg")
	
	var message = "--- OPERATION HUSH – BRIEFING ---\n\n"
	message += "For three years, the stalemate on the Western Front has bled the Empire white. Command has sanctioned a bold stroke: an amphibious landing to outflank the German line where it meets the sea.\n\n"
	message += "The German-held Belgian coast is a dagger pointed at our supply lines. The ports of Zeebrugge and Ostend serve as bases for the U-boats and destroyers that plague our shipping...\n\n"
	message += "Your objectives are twofold:\n • Objective 1: Seize the designated beachheads.\n • Objective 2: Neutralise the enemy batteries to enable a general advance from the Ypres Salient.\n\n"
	message += "The success of the entire Third Battle of Ypres may rest on your decisions."
	
	ui_manager.display_message(message)
	ui_manager.setup_choices(["View Intelligence Briefing"])

func start_intelligence_briefing_phase():
	current_phase = Phases.INTELLIGENCE_BRIEFING
	ui_manager.set_image("res://assets/MataHari.jpg")
	
	var message = "--- INTELLIGENCE BRIEFING ---\n\n"
	message += data_manager.get_intelligence_briefing()
	
	ui_manager.display_message(message)
	ui_manager.setup_choices(["View Operation Plan"])

func start_plan_overview_phase():
	current_phase = Phases.PLAN_OVERVIEW
	ui_manager.set_image("res://assets/prepare.jpeg")
	
	var message = "--- OPERATION PLAN & OBJECTIVES ---\n\n"
	message += data_manager.get_operation_plan()
	
	ui_manager.display_message(message)
	ui_manager.setup_choices(["Begin Planning"])

func start_naval_support_phase():
	current_phase = Phases.NAVAL_SUPPORT_DECISION
	ui_manager.set_image("res://assets/warspite.jpg")
	
	var message = "--- STEP 1: NAVAL SUPPORT ---\n\n"
	message += "The Dover Patrol will provide the initial coastal barrage using a number of their obsolete Tribal-class destroyers.\n\n"
	message += "These are old, steam-powered ships armed with 12-pounder guns. Their advantage is that they are already in position, and the Germans are accustomed to their presence off the coast.\n\n"
	message += "You could, however, petition the Admiralty for the use of the latest Queen Elizabeth-class Dreadnoughts. Their 15-inch guns offer vastly superior accuracy. Be warned: they are currently in Scapa Flow. Moving these capital ships will delay the operation, alert the enemy, and there is no guarantee the Admiralty will approve the request."
	
	ui_manager.display_message(message)
	ui_manager.setup_choices(["Rely on the Dover Patrol", "Petition for Dreadnoughts"])

func process_naval_support_choice(choice):
	data_manager.set_naval_support_choice(choice)
	start_naval_support_resolution_phase()

func start_naval_support_resolution_phase():
	current_phase = Phases.NAVAL_SUPPORT_RESOLUTION
	ui_manager.set_image("res://assets/Jelly.png")
	
	var message = data_manager.get_naval_support_resolution()
	ui_manager.display_message(message)
	ui_manager.setup_choices(["Set Targeting Priority"])

func start_naval_bombardment_targeting_phase():
	current_phase = Phases.NAVAL_BOMBARDMENT_TARGETING_DECISION
	ui_manager.set_image("res://assets/target.jpeg")
	
	var message = "--- STEP 2: BOMBARDMENT TARGETING ---\n\n"
	message += "The bombardment is the critical first step. The fleet's gunnery officers await your targeting doctrine.\n\n"
	message += "Your choice will determine the focus of the barrage:\n"
	message += " • Target the Batteries: Prioritise silencing the heavy guns that threaten our landing flotillas.\n"
	message += " • Target the Garrisons: Prioritise decimating the infantry in their trenches to aid our assaulting troops.\n\n"
	message += "What is the fleet's priority?"
	
	ui_manager.display_message(message)
	ui_manager.setup_choices(["Focus on Batteries", "Focus on Garrisons", "Split Fire"])

func process_naval_bombardment_targeting_choice(choice):
	data_manager.set_bombardment_targeting(choice)
	start_bombardment_plan_phase()

func start_bombardment_plan_phase():
	current_phase = Phases.BOMBARDMENT_PLAN_DECISION
	ui_manager.set_image("res://assets/baloon.jpg")
	
	var message = "--- STEP 3: BOMBARDMENT METHOD ---\n\n"
	message += "The Dover Patrol has fifteen monitors assigned to support the mission. Six are reserved for landing the enormous pontoons, leaving nine available for close support.\n\n"
	message += "The RNAS, however, would like to requisition one of these nine to carry an observation balloon. This would provide the fleet with live feedback on hits and misses, potentially increasing the barrage's accuracy.\n\n"
	message += "Separately, Admiral Bacon has a radical idea: use two monitors as static 'islands'. This would give the gunners a fixed point of reference, allowing them to triangulate their fire—a high-risk gamble with the potential for devastating accuracy.\n\n"
	message += "Or, you can simply trust the gunners, freeing up all nine monitors for their primary support role."
	
	ui_manager.display_message(message)
	ui_manager.setup_choices(["RNAS Balloon (Cost: 1 Monitor)", "Bacon's 'Islands' (Cost: 2 Monitors)", "Trust the Gunners (Cost: 0)"])

func process_bombardment_plan_choice(choice):
	data_manager.set_bombardment_plan(choice)
	start_armour_phase()

func start_armour_phase():
	current_phase = Phases.ARMOUR_DECISION
	ui_manager.set_image("res://assets/HAig.png")
	
	var troop_monitors_count = data_manager.get_available_troop_monitors()
	var message = "--- STEP 4: ARMOURED SUPPORT ---\n\n"
	message += "Field Marshal Haig has burst in, demanding that tanks be included in the assault.\n\n"
	message += "This would involve converting three of your " + str(troop_monitors_count) + " available troop-carrying monitors into specialist tank lighters, removing their initial infantry capacity entirely."
	
	ui_manager.display_message(message)
	ui_manager.setup_choices(["Reject Haig's Plan", "Approve Haig's Plan"])

func process_armour_choice(choice):
	var result = data_manager.process_armour_decision(choice)
	start_armour_resolution_phase(result)

func start_armour_resolution_phase(result_message):
	current_phase = Phases.ARMOUR_RESOLUTION
	ui_manager.display_message("--- ARMOUR DECISION: OUTCOME ---\n\n" + result_message)
	ui_manager.setup_choices(["Continue Planning"])

func start_q_ship_phase():
	current_phase = Phases.Q_SHIP_DECISION
	ui_manager.set_image("res://assets/qSHip.jpg")
	ui_manager.display_message("--- STEP 5: SUBMARINE DEFENCE ---\n\nU‑boats are active in the sector. Q‑Ships can be deployed to screen either the fire‑support fleet or the landing flotillas. Their presence will likely put the enemy on alert.\n\nYour choice:")
	ui_manager.setup_choices(["Screen Fire Support", "Screen Landing Force", "No Q-Ships"])

func process_q_ship_choice(choice):
	data_manager.set_q_ship_assignment(choice)
	start_time_of_day_phase()

func start_time_of_day_phase():
	current_phase = Phases.TIME_OF_DAY_DECISION
	ui_manager.display_message("--- STEP 6: H-HOUR ---\n\nChoose the timing of the assault carefully:\n\n • Night: Cloaks approach, but treacherous ranging.\n • Morning: Mist veils flotillas, but can fail.\n • Daylight: Perfect visibility for both sides.")
	ui_manager.setup_choices(["Night Assault", "Morning Landings", "Daylight Assault"])

func process_time_of_day_choice(choice):
	data_manager.set_time_of_day(choice)
	start_air_doctrine_phase()

func start_air_doctrine_phase():
	current_phase = Phases.AIR_DOCTRINE_DECISION
	ui_manager.set_image("res://assets/Flashheart.jpeg")
	ui_manager.display_message("--- STEP 7: AIR DOCTRINE ---\n\nThe Royal Flying Corps is eager to help. Where do you want them?\n\n • Air Reconnaissance: Estimate enemy strength.\n • Ground Attack: Strafe trenches and gun-pits.")
	ui_manager.setup_choices(["Air Reconnaissance", "Ground Attack"])

func process_air_doctrine_choice(choice):
	data_manager.set_air_doctrine(choice)
	start_assault_doctrine_phase()

func start_assault_doctrine_phase():
	current_phase = Phases.ASSAULT_DOCTRINE_DECISION
	ui_manager.hide_image()
	
	var message = "--- STEP 8: ASSAULT DOCTRINE ---\n\n"
	message += "One final decision remains: the exact timing of the pontoon assault relative to the bombardment.\n\n"
	message += " • **Immediate Pontoon Assault**: Launch the pontoon monitors in the immediate wake of the final bombardment shell. This maximizes surprise and shock. However, in the chaos, there is a small risk of friendly fire hitting our own pontoon flotillas.\n\n"
	message += " • **Coordinated Pontoon Assault**: Wait for the bombardment to cease and for observers to confirm damage before launching the pontoon assault. This allows you to adjust pontoon assignments based on bombardment results, but the delay gives the enemy time to recover and increases their alertness (`Threat Level +1`).\n"
	
	ui_manager.display_message(message)
	ui_manager.setup_choices(["Immediate Assault (High Risk, High Reward)", "Coordinated Assault (Safe, Raises Threat)"])

func process_assault_doctrine_choice(choice):
	data_manager.set_assault_doctrine(choice)
	
	if data_manager.assault_doctrine == "immediate":
		start_monitor_assignment_briefing_phase()
	else:
		show_planning_summary()

func show_planning_summary():
	current_phase = Phases.PLANNING_SUMMARY
	var summary = data_manager.generate_planning_summary()
	ui_manager.display_message(summary)
	ui_manager.setup_choices(["Begin Bombardment"])

func start_monitor_assignment_briefing_phase():
	current_phase = Phases.MONITOR_ASSIGNMENT_BRIEFING
	ui_manager.hide_image()
	
	var message = data_manager.get_monitor_assignment_briefing()
	ui_manager.display_message(message)
	ui_manager.setup_choices(["Assign Pontoon Assault Troops"])

func start_bombardment_report_phase():
	current_phase = Phases.BOMBARDMENT_REPORT
	ui_manager.set_image("res://assets/warspite.jpg")
	
	var report = combat_calculator.execute_bombardment()
	ui_manager.display_message(report)
	ui_manager.setup_choices(["Continue"])

func handle_bombardment_completion():
	if data_manager.assault_doctrine == "immediate":
		var assault_report = combat_calculator.resolve_pontoon_assault()
		current_phase = Phases.PONTOON_ASSAULT_REPORT
		ui_manager.display_message(assault_report)
		ui_manager.setup_choices(["Plan Main Force Disembarkation"])
	else:
		start_monitor_assignment_briefing_phase()

func start_assignment_phases():
	assignment_manager.start_pontoon_assignments()

func start_main_force_embarkation_phase():
	current_phase = Phases.MAIN_FORCE_EMBARKATION_ASSIGNMENT
	main_force_manager.start_main_force_embarkation()

func start_spy_report_phase():
	current_phase = Phases.SPY_REPORT
	ui_manager.set_image("res://assets/break.jpg")
	ui_manager.display_message("--- FIELD INTELLIGENCE REPORT ---\n\n(Agent reports enemy movements...)")
	ui_manager.setup_choices(["Begin Consolidation Phase"])

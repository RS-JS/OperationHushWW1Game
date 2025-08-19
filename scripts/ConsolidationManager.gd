class_name ConsolidationManager
extends RefCounted

signal consolidation_complete

var data_manager: DataManager
var ui_manager: UIManager

var consolidation_plan = {}
var consolidation_turns_total := 3
var consolidation_turn_current := 1
var current_assignment_index = 0
var temp_redeployment_source = ""
var rfc_used_this_turn := false

func setup_references(data_mgr: DataManager, ui_mgr: UIManager):
	data_manager = data_mgr
	ui_manager = ui_mgr

func start_consolidation_phase():
	"""Begin the consolidation phase"""
	consolidation_turn_current = 1
	current_assignment_index = 0
	consolidation_plan.clear()
	rfc_used_this_turn = false
	
	ui_manager.show_standard_ui()
	ui_manager.hide_image()
	
	ask_for_next_consolidation_order()

func ask_for_next_consolidation_order():
	"""Ask for orders for the current beach in the current turn"""
	var current_beach = data_manager.assignment_order[current_assignment_index]
	var beach_data = data_manager.targets[current_beach]
	var status = beach_data.get("beach_status", "No Landing")
	
	var message = "--- CONSOLIDATION – TURN " + str(consolidation_turn_current) + " ---\n\n"
	message += "Orders for " + current_beach + " (Status: " + status + ")\n"
	message += "Landed Force: ~" + str(beach_data.get("landed_force", 0)) + " men, " + str(beach_data.get("operational_tanks", 0)) + " tanks.\n"
	
	# Add environmental context
	if consolidation_turn_current > 1:
		message += "\nGerman reinforcements have arrived. Enemy resistance is stiffening.\n"
	
	ui_manager.display_message(message)
	
	# Determine available options based on beach status
	if status == "Secured" or status == "Dominant":
		ui_manager.setup_choices(["Assault Battery", "Naval Support", "Push Inland"])
	elif status == "Contested":
		ui_manager.setup_choices(["Assault Battery", "Naval Support", "Consolidate Position"])
	elif status == "Pinned Down":
		ui_manager.setup_choices(["Assault (Desperate)", "Naval Support", "Dig In"])
	else:
		ui_manager.setup_choices(["Do Nothing"])
	
	# Connect signal and wait for choice
	if not ui_manager.choice_made.is_connected(process_consolidation_choice):
		ui_manager.choice_made.connect(process_consolidation_choice)

func process_consolidation_choice(choice: String):
	"""Process the player's choice for the current beach"""
	# Disconnect signal to avoid multiple connections
	if ui_manager.choice_made.is_connected(process_consolidation_choice):
		ui_manager.choice_made.disconnect(process_consolidation_choice)
	
	var current_beach = data_manager.assignment_order[current_assignment_index]
	var status = data_manager.targets[current_beach].get("beach_status", "No Landing")
	
	var action = ""
	if status == "Secured" or status == "Dominant":
		if choice == "Assault Battery": action = "assault_battery"
		elif choice == "Naval Support": action = "naval_support"
		elif choice == "Push Inland": action = "push_inland"
	elif status == "Contested":
		if choice == "Assault Battery": action = "assault_battery"
		elif choice == "Naval Support": action = "naval_support"
		elif choice == "Consolidate Position": action = "consolidate"
	elif status == "Pinned Down":
		if choice == "Assault (Desperate)": action = "assault_battery"
		elif choice == "Naval Support": action = "naval_support"
		elif choice == "Dig In": action = "dig_in"
	else:
		action = "do_nothing"
	
	consolidation_plan[current_beach] = {"action": action}
	current_assignment_index += 1
	
	if current_assignment_index < data_manager.assignment_order.size():
		ask_for_next_consolidation_order()
	else:
		resolve_consolidation_turn()

func resolve_consolidation_turn():
	"""Resolve the actions for the current consolidation turn"""
	ui_manager.show_standard_ui()
	
	var report = "--- CONSOLIDATION TURN " + str(consolidation_turn_current) + " REPORT ---\n\n"
	
	# Resolve each beach's action
	for beach_name in data_manager.assignment_order:
		var beach_plan = consolidation_plan.get(beach_name, {"action": "do_nothing"})
		var action = beach_plan.action
		
		report += "=== " + beach_name.to_upper() + " ===\n"
		report += resolve_beach_action(beach_name, action)
		report += "\n"
	
	# Add environmental events
	report += resolve_environmental_events()
	
	# Check for German counter-attacks
	if consolidation_turn_current >= 2:
		report += resolve_german_counterattack()
	
	ui_manager.display_message(report)
	
	if consolidation_turn_current < consolidation_turns_total:
		ui_manager.setup_choices(["Plan Next Turn (" + str(consolidation_turn_current + 1) + ")"])
		if not ui_manager.choice_made.is_connected(_on_next_turn_choice):
			ui_manager.choice_made.connect(_on_next_turn_choice)
	else:
		ui_manager.setup_choices(["See Final Outcome"])
		if not ui_manager.choice_made.is_connected(_on_final_outcome_choice):
			ui_manager.choice_made.connect(_on_final_outcome_choice)

func _on_next_turn_choice(choice: String):
	"""Handle choice to advance to next turn"""
	if ui_manager.choice_made.is_connected(_on_next_turn_choice):
		ui_manager.choice_made.disconnect(_on_next_turn_choice)
	advance_to_next_consolidation_turn()

func _on_final_outcome_choice(choice: String):
	"""Handle choice to see final outcome"""
	if ui_manager.choice_made.is_connected(_on_final_outcome_choice):
		ui_manager.choice_made.disconnect(_on_final_outcome_choice)
	determine_final_outcome()

func resolve_beach_action(beach_name: String, action: String) -> String:
	"""Resolve the specific action taken at a beach"""
	var target_data = data_manager.targets[beach_name]
	var report = ""
	
	match action:
		"assault_battery":
			report += resolve_battery_assault(beach_name)
		"naval_support":
			report += resolve_naval_support_action(beach_name)
		"push_inland":
			report += resolve_push_inland(beach_name)
		"consolidate":
			report += resolve_consolidate_position(beach_name)
		"dig_in":
			report += resolve_dig_in(beach_name)
		"do_nothing":
			report += "No action taken. Forces remain in their current positions.\n"
		_:
			report += "Orders unclear. Forces hold position.\n"
	
	return report

func resolve_battery_assault(beach_name: String) -> String:
	"""Resolve an assault on the enemy battery"""
	var target_data = data_manager.targets[beach_name]
	var report = ""
	
	var landed_force = target_data.get("landed_force", 0)
	var operational_tanks = target_data.get("operational_tanks", 0)
	var artillery = target_data.get("artillery", 0)
	var garrison = target_data.get("garrison", 0)
	
	if artillery <= 0:
		report += "The battery has already been neutralized. Forces consolidate the position.\n"
		return report
	
	# Calculate assault strength
	var assault_strength = landed_force + (operational_tanks * data_manager.TANK_COMBAT_BONUS)
	var defense_strength = (artillery * 150) + (garrison * 0.8)  # Defenders fight harder for their guns
	
	var success_chance = float(assault_strength) / float(defense_strength + assault_strength)
	
	if randf() < success_chance:
		# Successful assault
		var guns_destroyed = min(artillery, max(1, artillery - randi() % 3))
		target_data.artillery -= guns_destroyed
		
		var casualties = int(landed_force * randf_range(0.15, 0.25))
		target_data.landed_force = max(0, landed_force - casualties)
		
		report += "**SUCCESS!** The battery assault succeeds! " + str(guns_destroyed) + " guns destroyed!\n"
		report += "Casualties: " + str(casualties) + " men.\n"
		
		if target_data.artillery <= 0:
			report += "**BATTERY ELIMINATED!** All enemy guns are silenced!\n"
	else:
		# Failed assault
		var casualties = int(landed_force * randf_range(0.25, 0.40))
		target_data.landed_force = max(0, landed_force - casualties)
		
		report += "**ASSAULT REPULSED!** Enemy fire pins down the attack.\n"
		report += "Heavy casualties: " + str(casualties) + " men lost.\n"
		
		# Possible status degradation
		var current_status = target_data.get("beach_status", "Unknown")
		if current_status == "Secured" and randf() < 0.3:
			target_data.beach_status = "Contested"
			report += "German counter-attack downgrades beach status to Contested.\n"
	
	return report

func resolve_naval_support_action(beach_name: String) -> String:
	"""Resolve naval gunfire support"""
	var target_data = data_manager.targets[beach_name]
	var report = ""
	
	var artillery = target_data.get("artillery", 0)
	var garrison = target_data.get("garrison", 0)
	
	if artillery <= 0 and garrison <= 0:
		report += "No viable targets for naval bombardment remain.\n"
		return report
	
	# Naval support effectiveness
	var guns_suppressed = min(artillery, max(0, randi() % 3 + 1))
	var garrison_casualties = min(garrison, int(garrison * randf_range(0.10, 0.20)))
	
	if guns_suppressed > 0:
		target_data.artillery = max(0, artillery - guns_suppressed)
		report += "Naval bombardment silences " + str(guns_suppressed) + " enemy guns!\n"
	
	if garrison_casualties > 0:
		target_data.garrison = max(0, garrison - garrison_casualties)
		report += "Shore bombardment inflicts " + str(garrison_casualties) + " casualties on the garrison.\n"
	
	if guns_suppressed == 0 and garrison_casualties == 0:
		report += "Naval fire falls wide of the mark. No significant damage inflicted.\n"
	
	return report

func resolve_push_inland(beach_name: String) -> String:
	"""Resolve pushing inland from secured beaches"""
	var target_data = data_manager.targets[beach_name]
	var report = ""
	
	var landed_force = target_data.get("landed_force", 0)
	
	if landed_force < 500:
		report += "Insufficient force strength to push inland. Forces hold current positions.\n"
		return report
	
	# Pushing inland can discover intelligence or threaten other beaches
	var discovery_roll = randf()
	
	if discovery_roll < 0.3:
		report += "**INTELLIGENCE DISCOVERY!** Advance units capture German field telephone exchange!\n"
		report += "Intercepted communications reveal enemy reinforcement plans.\n"
		# This could reduce threat level for next turn
		data_manager.threat_level = max(0, data_manager.threat_level - 1)
	elif discovery_roll < 0.6:
		report += "Forces advance " + str(randi() % 1000 + 500) + " meters inland, securing tactical positions.\n"
		report += "High ground provides excellent observation of the sector.\n"
	else:
		report += "Advance encounters strong resistance. Forces withdraw to the beachhead.\n"
		var casualties = int(landed_force * randf_range(0.05, 0.15))
		target_data.landed_force = max(0, landed_force - casualties)
		report += "Casualties: " + str(casualties) + " men.\n"
	
	return report

func resolve_consolidate_position(beach_name: String) -> String:
	"""Resolve consolidating defensive positions"""
	var target_data = data_manager.targets[beach_name]
	var report = ""
	
	# Consolidation improves beach status and reduces future casualties
	report += "Forces dig in and strengthen defensive positions.\n"
	report += "Improved fields of fire and communication networks established.\n"
	
	# Possible status improvement
	var current_status = target_data.get("beach_status", "Unknown")
	if current_status == "Contested" and randf() < 0.4:
		target_data.beach_status = "Secured"
		report += "**POSITION SECURED!** Defensive improvements stabilize the beachhead.\n"
	
	return report

func resolve_dig_in(beach_name: String) -> String:
	"""Resolve digging in when pinned down"""
	var target_data = data_manager.targets[beach_name]
	var report = ""
	
	report += "Forces construct hasty fortifications under fire.\n"
	report += "Casualties reduced but offensive capability limited.\n"
	
	# Reduces future casualty rates
	target_data["dug_in"] = true
	
	return report

func resolve_environmental_events() -> String:
	"""Resolve random environmental events"""
	var report = "=== OPERATIONAL DEVELOPMENTS ===\n"
	
	var event_roll = randf()
	
	if event_roll < 0.2:
		report += "**WEATHER**: Heavy rain begins to fall, limiting visibility and making movement difficult.\n"
		data_manager.threat_level += 1
	elif event_roll < 0.4:
		report += "**LOGISTICS**: Supply runners successfully establish ammunition resupply routes.\n"
		# All beaches get slight reinforcement
		for beach_name in data_manager.assignment_order:
			var current_force = data_manager.targets[beach_name].get("landed_force", 0)
			if current_force > 0:
				data_manager.targets[beach_name].landed_force = current_force + randi() % 50 + 25
	elif event_roll < 0.6:
		report += "**INTELLIGENCE**: RFC reconnaissance reports German reserves moving toward the sector.\n"
		data_manager.threat_level += 1
	elif event_roll < 0.8:
		report += "**COMMUNICATIONS**: Clear radio contact established with division headquarters.\n"
		report += "Coordinated operations become more effective.\n"
	else:
		report += "**MORALE**: Despite casualties, unit cohesion remains high. The men fight with determination.\n"
	
	return report

func resolve_german_counterattack() -> String:
	"""Resolve German counterattacks in later turns"""
	var report = "=== GERMAN COUNTERATTACK ===\n"
	
	var counterattack_strength = data_manager.threat_level * 2 + consolidation_turn_current
	
	# Target the most successful beach
	var target_beach = ""
	var highest_force = 0
	
	for beach_name in data_manager.assignment_order:
		var force = data_manager.targets[beach_name].get("landed_force", 0)
		if force > highest_force:
			highest_force = force
			target_beach = beach_name
	
	if target_beach == "":
		report += "German reserves probe for weaknesses but find no major concentrations to attack.\n"
		return report
	
	report += "German reserves launch a determined counterattack against " + target_beach + "!\n"
	
	var defender_strength = data_manager.targets[target_beach].get("landed_force", 0)
	var tanks = data_manager.targets[target_beach].get("operational_tanks", 0)
	var total_defense = defender_strength + (tanks * data_manager.TANK_COMBAT_BONUS)
	
	if total_defense > counterattack_strength:
		report += "**COUNTERATTACK REPULSED!** Our forces hold firm against the German assault.\n"
		var german_casualties = randi() % 200 + 100
		report += "Estimated " + str(german_casualties) + " German casualties.\n"
	else:
		report += "**HEAVY FIGHTING!** The German attack makes headway against our positions.\n"
		var our_casualties = int(defender_strength * randf_range(0.20, 0.35))
		data_manager.targets[target_beach].landed_force = max(0, defender_strength - our_casualties)
		report += "Our casualties: " + str(our_casualties) + " men.\n"
		
		# Possible status degradation
		var current_status = data_manager.targets[target_beach].get("beach_status", "Unknown")
		if current_status == "Secured":
			data_manager.targets[target_beach].beach_status = "Contested"
			report += "Beach status degraded to Contested.\n"
		elif current_status == "Contested":
			data_manager.targets[target_beach].beach_status = "Pinned Down"
			report += "Beach status degraded to Pinned Down.\n"
	
	return report

func advance_to_next_consolidation_turn():
	"""Advance to the next consolidation turn"""
	consolidation_turn_current += 1
	rfc_used_this_turn = false
	consolidation_plan.clear()
	current_assignment_index = 0
	ask_for_next_consolidation_order()

func determine_final_outcome():
	"""Determine the final outcome of Operation Hush"""
	ui_manager.show_standard_ui()
	ui_manager.hide_image()
	
	var report = "--- FINAL OPERATION OUTCOME ---\n\n"
	
	# Calculate victory conditions
	var batteries_destroyed = 0
	var garrisons_routed = 0
	var beaches_secured = 0
	var total_force_remaining = 0
	
	for beach_name in data_manager.assignment_order:
		var target_data = data_manager.targets[beach_name]
		
		if target_data.get("artillery", 0) <= 0:
			batteries_destroyed += 1
		
		if target_data.get("garrison", 0) <= target_data.get("garrison", 4500) * 0.2:  # 80% casualties = routed
			garrisons_routed += 1
		
		var status = target_data.get("beach_status", "Failed")
		if status == "Secured" or status == "Dominant":
			beaches_secured += 1
		
		total_force_remaining += target_data.get("landed_force", 0)
	
	# Determine overall outcome
	if batteries_destroyed >= 3 and garrisons_routed >= 3:
		report += "**COMPLETE VICTORY!**\n\n"
		report += "All three enemy batteries have been silenced and their garrisons routed. The coastal defenses are neutralized, and the way is clear for the main offensive from the Ypres Salient.\n\n"
		report += "Operation Hush has achieved its objectives beyond all expectations. The amphibious assault has proven the value of combined operations and innovative tactics.\n"
	elif batteries_destroyed >= 2 and beaches_secured >= 2:
		report += "**MAJOR SUCCESS!**\n\n"
		report += "The operation has achieved most of its objectives. " + str(batteries_destroyed) + " batteries destroyed and " + str(beaches_secured) + " beaches secured provide an excellent foundation for future operations.\n\n"
		report += "While not a complete victory, Operation Hush has demonstrated the feasibility of amphibious assault and significantly weakened the German coastal defenses.\n"
	elif batteries_destroyed >= 1 and beaches_secured >= 1:
		report += "**PARTIAL SUCCESS**\n\n"
		report += "The operation has achieved limited objectives. " + str(batteries_destroyed) + " battery destroyed and " + str(beaches_secured) + " beach secured, but at considerable cost.\n\n"
		report += "Operation Hush has gained valuable experience in amphibious warfare, though the strategic objectives remain partially unfulfilled.\n"
	else:
		report += "**OPERATIONAL FAILURE**\n\n"
		report += "The operation has failed to achieve its primary objectives. Enemy batteries remain largely intact and no secure beachheads have been established.\n\n"
		report += "While lessons have been learned about amphibious assault, the cost in men and materiel has been severe. The German coastal defenses remain a significant threat.\n"
	
	report += "\n--- FINAL STATISTICS ---\n"
	report += "Batteries Destroyed: " + str(batteries_destroyed) + "/3\n"
	report += "Garrisons Routed: " + str(garrisons_routed) + "/3\n"
	report += "Beaches Secured: " + str(beaches_secured) + "/3\n"
	report += "Force Remaining: " + str(total_force_remaining) + " men\n"
	
	ui_manager.display_message(report)
	ui_manager.setup_choices(["View Roll of Honour"])
	
	if not ui_manager.choice_made.is_connected(_on_roll_of_honour_choice):
		ui_manager.choice_made.connect(_on_roll_of_honour_choice)

func _on_roll_of_honour_choice(choice: String):
	"""Handle choice to view roll of honour"""
	if ui_manager.choice_made.is_connected(_on_roll_of_honour_choice):
		ui_manager.choice_made.disconnect(_on_roll_of_honour_choice)
	start_roll_of_honour_phase()

func start_roll_of_honour_phase():
	"""Show the final casualty report"""
	ui_manager.show_standard_ui()
	ui_manager.hide_image()
	
	var report = "--- OPERATION HUSH: ROLL OF HONOUR ---\n\n"
	report += "The following units sustained casualties during the operation:\n\n"
	
	# Calculate total casualties across all phases
	var total_casualties = 0
	
	# Add pontoon assault casualties
	for beach_name in data_manager.assignment_order:
		var initial_pontoon_force = data_manager.pontoon_assault_plan.get(beach_name, 0) * data_manager.SOLDIERS_PER_MONITOR
		var surviving_pontoon_force = data_manager.targets[beach_name].get("pontoon_survivors", 0)
		var pontoon_casualties = initial_pontoon_force - surviving_pontoon_force
		total_casualties += pontoon_casualties
	
	# Add main force casualties (would need to be tracked from MainForceManager)
	# Add consolidation casualties
	
	report += "Total Operation Casualties: " + str(total_casualties) + " officers and men\n\n"
	report += "Their sacrifice in the cause of victory shall not be forgotten.\n\n"
	report += "\"They shall grow not old, as we that are left grow old:\n"
	report += "Age shall not weary them, nor the years condemn.\n"
	report += "At the going down of the sun and in the morning,\n"
	report += "We will remember them.\"\n"
	
	ui_manager.display_message(report)
	ui_manager.setup_choices(["Operation Complete"])
	
	if not ui_manager.choice_made.is_connected(_on_operation_complete):
		ui_manager.choice_made.connect(_on_operation_complete)

func _on_operation_complete(choice: String):
	"""Handle operation completion"""
	if ui_manager.choice_made.is_connected(_on_operation_complete):
		ui_manager.choice_made.disconnect(_on_operation_complete)
	consolidation_complete.emit()

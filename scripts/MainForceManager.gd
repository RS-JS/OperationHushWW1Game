class_name MainForceManager
extends RefCounted

var data_manager: DataManager
var ui_manager: UIManager

var barge_manifest = {}  # Beach -> Array of barges with unit details
var pontoon_status = {}  # Beach -> boolean (true if pontoons established)

func setup_references(data_mgr: DataManager, ui_mgr: UIManager):
	data_manager = data_mgr
	ui_manager = ui_mgr
	
	# Connect UI signals for unit reassignment
	ui_manager.unit_reassigned.connect(_on_unit_reassigned)

func start_main_force_embarkation():
	"""Start the main force embarkation phase with UI"""
	print("--- Starting Main Force Embarkation Phase ---")
	
	ui_manager.show_embarkation_ui()
	ui_manager.display_message("--- MAIN FORCE EMBARKATION & ASSIGNMENT ---\nThe pontoon assault is complete. Based on the results, re-assign 1st Division units between beachheads as required. Units will cross in trawlers and barges—the logistical requirements (barges needed) will update with each change.")
	
	await ui_manager.draw_embarkation_ui(data_manager.division_order_of_battle)

func _on_unit_reassigned(unit_data: Dictionary, new_destination: String):
	"""Handle when a unit is reassigned to a different beach"""
	unit_data.current_dest = new_destination
	await ui_manager.draw_embarkation_ui(data_manager.division_order_of_battle)

func resolve_main_force_disembarkation() -> String:
	"""Execute the main force disembarkation and return detailed report"""
	print("--- DETAILED MAIN FORCE DISEMBARKATION ---")
	
	organize_units_into_barges()
	var beach_threats = calculate_beach_threats()
	var report = execute_main_force_disembarkation(beach_threats)
	
	return report

func organize_units_into_barges():
	"""Organize division units into individual barges for detailed tracking"""
	barge_manifest.clear()
	
	for beach_name in data_manager.assignment_order:
		barge_manifest[beach_name] = []
	
	for unit in data_manager.division_order_of_battle:
		var dest = unit.current_dest
		var remaining_strength = unit.strength
		var barge_number = 1
		
		while remaining_strength > 0:
			var men_in_barge = min(remaining_strength, data_manager.SOLDIERS_PER_BARGE)
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

func calculate_beach_threats() -> Dictionary:
	"""Calculate threat levels for each beach based on current conditions"""
	var threats = {}
	
	for beach_name in data_manager.assignment_order:
		var threat_data = {
			"artillery": 0,
			"u_boat": 0,
			"reinforcements": 0,
			"pontoon_factor": 1.0,
			"total_threat": 0.0
		}
		
		var target_data = data_manager.targets[beach_name]
		
		# Artillery threat
		threat_data.artillery = target_data.artillery * 3
		
		# U-boat threat
		threat_data.u_boat = 2 + data_manager.threat_level
		if data_manager.q_ship_assignment == "screen":
			threat_data.u_boat *= 0.3
		
		# German reinforcement threat
		threat_data.reinforcements = data_manager.threat_level * 2
		
		# Pontoon status affects difficulty
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

func execute_main_force_disembarkation(beach_threats: Dictionary) -> String:
	"""Execute the detailed main force landing with casualties"""
	var report = "--- MAIN FORCE DISEMBARKATION REPORT ---\n\n"
	report += "With the pontoon assault complete, the signal is given. Across the grey waters, trawlers and barges packed with the men of the 1st Division surge toward the Belgian coast...\n\n"

	var total_men_lost_op = 0
	var total_barges_lost_op = 0

	for beach_name in data_manager.assignment_order:
		report += "=== " + beach_name.to_upper() + " ===\n"
		var beach_barges = barge_manifest[beach_name]

		if pontoon_status[beach_name]:
			report += "**PONTOON BRIDGES OPERATIONAL**: The main force can disembark directly onto the promenade!\n"
		else:
			report += "**NO PONTOON BRIDGES**: Men must scale the 30-foot seawall under heavy fire!\n"

		# Calculate barge hit chances
		var initial_artillery = data_manager.initial_targets_state[beach_name].get("artillery", 1)
		if initial_artillery == 0: initial_artillery = 1
		var current_artillery = data_manager.targets[beach_name].get("artillery", 0)
		
		var artillery_modifier = float(current_artillery) / float(initial_artillery)
		var time_modifier = 1.0
		if data_manager.time_of_day_effective == "night": time_modifier = 0.4
		elif data_manager.time_of_day_effective == "morning": time_modifier = 0.7
		elif data_manager.time_of_day_effective == "day": time_modifier = 1.1

		var final_barge_hit_chance = data_manager.BASE_BARGE_HIT_CHANCE * artillery_modifier * time_modifier

		var barges_lost_this_beach = 0

		# Process each barge
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

		# Calculate seawall casualties if no pontoons
		var seawall_casualties_this_beach = 0
		if not pontoon_status[beach_name]:
			report += "**SCALING THE SEAWALL**: Without pontoon bridges, men must climb the 30-foot concrete wall under machine gun fire!\n"
			
			var initial_garrison = data_manager.initial_targets_state[beach_name].get("garrison", 1)
			if initial_garrison == 0: initial_garrison = 1
			var current_garrison = data_manager.targets[beach_name].get("garrison", 0)
			
			var garrison_modifier = float(current_garrison) / float(initial_garrison)
			var final_seawall_casualty_rate = data_manager.BASE_SEAWALL_CASUALTY_RATE * garrison_modifier

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

		# Calculate final results for this beach
		var landed_survivors = 0
		var beach_total_casualties = 0
		for barge in beach_barges:
			if barge.status != "Lost":
				landed_survivors += (barge.men - barge.casualties)
			beach_total_casualties += barge.casualties
		
		total_men_lost_op += beach_total_casualties
		total_barges_lost_op += barges_lost_this_beach
		
		# Update target data with landed force
		if not data_manager.targets[beach_name].has("landed_force"):
			data_manager.targets[beach_name]["landed_force"] = 0
		data_manager.targets[beach_name]["landed_force"] += landed_survivors

		report += "Total Beach Casualties: " + str(beach_total_casualties) + " men.\n"
		report += "Effective Force Disembarked: " + str(landed_survivors) + " men are ashore and forming up.\n\n"

	# Generate operation summary
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

func get_unit_casualties() -> Dictionary:
	"""Return detailed casualty breakdown by unit"""
	var casualties = {}
	
	for beach_name in barge_manifest:
		for barge in barge_manifest[beach_name]:
			if barge.casualties > 0:
				if not casualties.has(barge.unit_name):
					casualties[barge.unit_name] = 0
				casualties[barge.unit_name] += barge.casualties
	
	return casualties

func get_total_landed_force() -> int:
	"""Return total number of men successfully landed"""
	var total = 0
	for beach_name in data_manager.assignment_order:
		total += data_manager.targets[beach_name].get("landed_force", 0)
	return total

func get_beach_statistics() -> Dictionary:
	"""Return detailed statistics for each beach"""
	var stats = {}
	
	for beach_name in data_manager.assignment_order:
		var beach_barges = barge_manifest.get(beach_name, [])
		var total_barges = beach_barges.size()
		var lost_barges = 0
		var total_casualties = 0
		var landed_men = 0
		
		for barge in beach_barges:
			if barge.status == "Lost":
				lost_barges += 1
			total_casualties += barge.casualties
			if barge.status != "Lost":
				landed_men += (barge.men - barge.casualties)
		
		stats[beach_name] = {
			"total_barges": total_barges,
			"lost_barges": lost_barges,
			"total_casualties": total_casualties,
			"landed_men": landed_men,
			"pontoons_operational": pontoon_status.get(beach_name, false)
		}
	
	return stats
class_name CombatCalculator
extends RefCounted

var data_manager: DataManager

func setup_references(data_mgr: DataManager):
	data_manager = data_mgr

func execute_bombardment() -> String:
	var report = "--- BOMBARDMENT REPORT ---\n\n"
	report += "The pre-dawn gloom is shattered as the fleet opens fire. The Belgian shore disappears behind a wall of smoke, seawater, and pulverised earth.\n"
	
	data_manager.initial_targets_state = data_manager.targets.duplicate(true)
	
	for target_name in data_manager.targets.keys():
		bombard_target(target_name)
	
	report += "\nInitial Damage Assessment:\n"
	for target_name in data_manager.targets.keys():
		var pre_art = data_manager.initial_targets_state[target_name]["artillery"]
		var post_art = data_manager.targets[target_name]["artillery"]
		report += " > " + target_name + ": Guns reduced from " + str(pre_art) + " to " + str(post_art) + ".\n"
	
	if data_manager.assault_doctrine == "immediate":
		report += "\n--- Immediate Pontoon Assault Commencing ---"
		report += "\nAs the last shells fall, the pontoon monitors surge forward into the smoke and debris. The assault plan is locked in!\n"
		
		if randf() < 0.05:
			var beaches = data_manager.pontoon_monitors.keys()
			var hit_beach = beaches.pick_random()
			data_manager.targets[hit_beach]["pontoons_damaged_by_friendly_fire"] = true
			
			report += "\n**DISASTER! FRIENDLY FIRE INCIDENT!**"
			report += "\nIn the chaos, a salvo from our own fleet landed short. Radio signals indicate the pontoon flotilla for " + hit_beach + " has taken a direct hit!\n"
	else:
		report += "\n--- Coordinated Pontoon Assault Pending ---"
		report += "\nThe bombardment ceases. Forward observers are assessing the damage to inform the pontoon assault plan.\n"

	return report

func bombard_target(target_name: String):
	var target = data_manager.targets[target_name]
	
	var active_ships = data_manager.get_active_fire_support()
	if active_ships.is_empty():
		return

	var total_firepower = 0
	for ship in active_ships:
		if ship.get("class") == "qe":
			total_firepower += 20
		elif ship.get("class") == "tribal":
			total_firepower += 4

	var spotting_multiplier = 1.0
	if data_manager.bombardment_plan == "bacon":
		spotting_multiplier = 1.75
	elif data_manager.bombardment_plan == "balloons":
		spotting_multiplier = 1.35

	var time_multiplier = 1.0
	if data_manager.time_of_day_effective == "night":
		time_multiplier = 0.5
	elif data_manager.time_of_day_effective == "morning":
		time_multiplier = 0.8

	var final_firepower = total_firepower * spotting_multiplier * time_multiplier
	var base_effectiveness = final_firepower / 150.0

	var artillery_reduction_percent = 0.0
	var garrison_reduction_percent = 0.0
	
	if data_manager.naval_bombardment_target_focus == "batteries":
		artillery_reduction_percent = base_effectiveness
		garrison_reduction_percent = base_effectiveness * 0.3
	elif data_manager.naval_bombardment_target_focus == "garrison":
		artillery_reduction_percent = base_effectiveness * 0.3
		garrison_reduction_percent = base_effectiveness
	elif data_manager.naval_bombardment_target_focus == "split":
		artillery_reduction_percent = base_effectiveness * 0.7
		garrison_reduction_percent = base_effectiveness * 0.7
		
	artillery_reduction_percent *= randf_range(0.85, 1.15)
	garrison_reduction_percent *= randf_range(0.85, 1.15)

	var art_damage = floori(target.artillery * artillery_reduction_percent)
	var gar_damage = floori(target.garrison * garrison_reduction_percent)
	
	target.artillery = max(0, target.artillery - art_damage)
	target.garrison  = max(0, target.garrison  - gar_damage)

func resolve_pontoon_assault() -> String:
	print("=== RESOLVE_PONTOON_ASSAULT CALLED ===")
	
	var report = "--- PONTOON ASSAULT REPORT ---\n\n"
	
	apply_environmental_effects()
	
	if data_manager.time_of_day_effective == "morning" and data_manager.morning_mist_failed:
		report += "The morning mist that was hoped to conceal our approach has failed to materialize. The pontoon flotillas advance under clear skies...\n\n"
	elif data_manager.time_of_day_effective == "morning":
		report += "A blessed morning mist cloaks the pontoon monitors as they surge toward the Belgian coast...\n\n"
	elif data_manager.time_of_day_effective == "night":
		report += "Under cover of darkness, the pontoon monitors navigate by compass toward their objectives...\n\n"
	else:
		report += "In full daylight, the pontoon monitors advance boldly toward the enemy shore...\n\n"

	for beach_name in data_manager.assignment_order:
		# --- Tally Ho effect (33% chance, -15% enemy artillery per beach) ---
		if data_manager.air_doctrine == "tally_ho" and randf() < 0.33:
				var target: Dictionary = data_manager.targets[beach_name]  # <-- explicit type
				var initial_artillery: int = int(target.get("artillery", 0))
				if initial_artillery > 0:
					var reduction: int = floori(initial_artillery * 0.15)
					if reduction > 0:
						target["artillery"] = max(0, initial_artillery - reduction)
						report += "RFC executes 'Tally Ho' over " + beach_name + "! " + str(reduction) + " enemy guns knocked out in a daring low-level attack.\n\n"
		# ---------------------------------------------------------------
		
		report += resolve_beach_pontoon_assault(beach_name)
		report += "\n"

	report += generate_pontoon_operation_summary()
	return report

func apply_environmental_effects():
	data_manager.time_of_day_effective = data_manager.time_of_day
	data_manager.morning_mist_failed = false
	
	if data_manager.time_of_day == "morning" and randf() < 0.30:
		data_manager.morning_mist_failed = true
		data_manager.time_of_day_effective = "day"

func resolve_beach_pontoon_assault(beach_name: String) -> String:
	var report = "=== " + beach_name.to_upper() + " ===\n"
	var target_data = data_manager.targets[beach_name]
	
	var monitors_assigned = data_manager.pontoon_assault_plan.get(beach_name, 0)
	var tank_lighters_assigned = data_manager.tank_assault_plan.get(beach_name, 0)
	var pontoon_monitors_count = 2
	
	var total_men = monitors_assigned * data_manager.SOLDIERS_PER_MONITOR
	var total_tank_count = tank_lighters_assigned * data_manager.TANKS_PER_LIGHTER
	
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
	
	# --- Ground Attack air doctrine effect (10% artillery reduction, 7% garrison reduction) ---
	if data_manager.air_doctrine == "ground_attack":
		var initial_artillery = target_data.artillery
		var initial_garrison = target_data.garrison
		
		var artillery_reduction = floori(initial_artillery * 0.10)
		var garrison_reduction = floori(initial_garrison * 0.07)
		
		if artillery_reduction > 0 or garrison_reduction > 0:
			target_data.artillery = max(0, target_data.artillery - artillery_reduction)
			target_data.garrison = max(0, target_data.garrison - garrison_reduction)
			
			report += "**RFC GROUND ATTACK**: SE5s swoop low through the defenses!\n"
			if artillery_reduction > 0:
				report += " > " + str(artillery_reduction) + " guns knocked out by strafing runs!\n"
			if garrison_reduction > 0:
				report += " > " + str(garrison_reduction) + " defenders eliminated in trench attacks!\n"
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

func resolve_approach_phase(beach_name: String, monitors_count: int, tank_lighters_count: int, pontoon_monitors_count: int) -> Dictionary:
	var target_data = data_manager.targets[beach_name]
	var artillery_guns = target_data.artillery
	var phase_report = ""
	
	var base_hit_chance = min(0.03 * artillery_guns, 0.25)
	
	var visibility_modifier = 1.0
	match data_manager.time_of_day_effective:
		"night":
			visibility_modifier = 0.4
		"morning":
			visibility_modifier = 0.7 if not data_manager.morning_mist_failed else 1.1
		"day":
			visibility_modifier = 1.2
	
	var alertness_modifier = 1.0 + (data_manager.threat_level * 0.15)
	var final_hit_chance = base_hit_chance * visibility_modifier * alertness_modifier
	
	# --- Recon air doctrine effect (25% reduction in approach phase losses) ---
	if data_manager.air_doctrine == "recon":
		final_hit_chance *= 0.75
		phase_report += "RFC reconnaissance provides early warning of enemy gun positions!\n"
	
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
	
	var base_sub_threat = 0.05 + (data_manager.threat_level * 0.02)
	
	if data_manager.q_ship_assignment == "screen":
		base_sub_threat *= 0.3
		phase_report += "Q-ships screen the landing force from submarine attack.\n"
	elif data_manager.q_ship_assignment == "fleet":
		base_sub_threat *= 0.8
	
	match data_manager.time_of_day_effective:
		"night":
			base_sub_threat *= 1.3
		"day":
			base_sub_threat *= 0.8
	
	# --- Recon air doctrine effect (33% reduction in submarine phase losses) ---
	if data_manager.air_doctrine == "recon":
		base_sub_threat *= 0.67
		phase_report += "RFC scouts spotted submarine movements, flotilla takes evasive action!\n"
	
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
		if data_manager.q_ship_assignment == "screen":
			phase_report += "Q-ship patrols report waters clear of enemy submarines.\n"
		else:
			phase_report += "No submarine contacts reported during the approach.\n"
	
	phase_results.report = phase_report
	return phase_results

func resolve_pontoon_deployment_phase(beach_name: String, pontoon_monitors_count: int, surviving_monitors_count: int, surviving_tank_lighters_count: int) -> Dictionary:
	var target_data = data_manager.targets[beach_name]
	var phase_report = ""
	
	var pontoons_operational = false
	var final_men = surviving_monitors_count * data_manager.SOLDIERS_PER_MONITOR
	var final_tank_count = surviving_tank_lighters_count * data_manager.TANKS_PER_LIGHTER
	
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
	
	match data_manager.time_of_day_effective:
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
	var target_data = data_manager.targets[beach_name]
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
		attacker_strength += tank_count * data_manager.TANK_COMBAT_BONUS
		phase_report += "Tanks advance off the pontoons to establish a protective perimeter.\n"
	elif tank_count > 0:
		var tank_casualties = int(tank_count * 0.6)
		final_tank_count -= tank_casualties
		attacker_strength += final_tank_count * (data_manager.TANK_COMBAT_BONUS * 0.3)
		phase_report += str(tank_casualties) + " tanks lost attempting to scale the sea wall!\n"
	
	var defender_strength = garrison + (artillery * 200)
	
	var combat_modifier = 1.0
	if pontoons_operational:
		combat_modifier = 1.5
	
	match data_manager.time_of_day_effective:
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

func generate_pontoon_operation_summary() -> String:
	var report = "=== PONTOON ASSAULT SUMMARY ===\n"
	
	var total_secured = 0
	var total_contested = 0
	var total_failed = 0
	var total_assault_troops = 0
	var total_operational_tanks = 0
	
	for beach_name in data_manager.assignment_order:
		var status = data_manager.targets[beach_name].get("beach_status", "Unknown")
		total_assault_troops += data_manager.targets[beach_name].get("landed_force", 0)
		total_operational_tanks += data_manager.targets[beach_name].get("operational_tanks", 0)
		
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

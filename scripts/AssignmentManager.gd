class_name AssignmentManager
extends RefCounted

signal assignment_complete
var main_controller: Control
var data_manager: DataManager
var ui_manager: UIManager

var assignments_completed = {
	"tanks": false,
	"troops": false
}

var current_assignment_type = "troops"  # "troops" or "tanks"
var assignment_values = {}  # Beach name -> number assigned
var current_assignment_index = 0
var temp_assignment_value = 0

func setup_references(controller: Control, data_mgr: DataManager, ui_mgr: UIManager):
	main_controller = controller
	data_manager = data_mgr
	ui_manager = ui_mgr
	# Connect UI signals
	ui_manager.assignment_change.connect(_on_assignment_change)
	
func start_pontoon_assignments():
	"""Start the pontoon assignment sequence - handles both tanks and troops"""
	data_manager.pontoon_assault_plan.clear()
	data_manager.tank_assault_plan.clear()
	current_assignment_index = 0
	
	assignments_completed = {"tanks": false, "troops": false}
	
	# Determine if we need to assign tanks first
	if data_manager.tanks_chosen and data_manager.get_tank_lighters_available() > 0:
		current_assignment_type = "tanks"
	else:
		current_assignment_type = "troops"
	
	_start_assignment_phase()

func _start_assignment_phase():
	"""Initialize assignment values and start the UI"""
	assignment_values.clear()
	for beach in data_manager.assignment_order:
		assignment_values[beach] = 0
	
	ui_manager.show_pontoon_assignment_ui()
	
	var total_units = _get_total_units_for_current_type()
	ui_manager.setup_pontoon_assignment_ui(current_assignment_type, assignment_values, total_units)
	
	# Connect the confirm button
	if not ui_manager.assignment_confirm.is_connected("pressed", _on_assignment_confirm):
		ui_manager.assignment_confirm.pressed.connect(_on_assignment_confirm)

func _get_total_units_for_current_type() -> int:
	if current_assignment_type == "tanks":
		return data_manager.get_tank_lighters_available()
	else:
		return data_manager.get_troop_monitors_available()

func _on_assignment_change(beach_name: String, change: int):
	var total_units = _get_total_units_for_current_type()
	
	# Calculate what the new value would be
	var current_value = assignment_values[beach_name]
	var new_value = current_value + change
	
	# Calculate total after this change
	var total_assigned = 0
	for beach in assignment_values:
		if beach == beach_name:
			total_assigned += new_value  # Use the new value for this beach
		else:
			total_assigned += assignment_values[beach]
	
	# Validate the change
	if new_value < 0:
		return
	if total_assigned > total_units:  # Changed from >= to >
		return
		
	# Apply the change
	assignment_values[beach_name] = new_value
	
	# Refresh UI
	ui_manager.setup_pontoon_assignment_ui(current_assignment_type, assignment_values, total_units)
func _on_assignment_confirm():
	"""Handle confirmation of current assignment type"""
	print("Confirm pressed. Type:", current_assignment_type, " Values:", assignment_values)
	print("=== ASSIGNMENT CONFIRM ===")
	print("Current assignment type: ", current_assignment_type)
	print("Assignment values: ", assignment_values)
	
	# Save the current assignment
	if current_assignment_type == "tanks":
		data_manager.save_tank_assignment(assignment_values)
		print("Saved tank plan: ", data_manager.tank_assault_plan)
	elif current_assignment_type == "troops":
		data_manager.save_pontoon_assignment(assignment_values)
		print("Saved troop plan: ", data_manager.pontoon_assault_plan)

	_advance_assignment_phase()

func _advance_assignment_phase():
	"""Determine what assignment phase comes next"""
	print("Advance called. Tank plan:", data_manager.tank_assault_plan)
	print("=== ASSIGNMENT PHASE ROUTER ===")
	print("Current phase: ", current_assignment_type)
	print("Assignments completed: ", assignments_completed)
	
	var tank_lighters_exist = data_manager.get_tank_lighters_available() > 0
	var troop_monitors_exist = data_manager.get_troop_monitors_available() > 0
	
	# Mark current assignment as completed
	if current_assignment_type == "tanks":
		assignments_completed["tanks"] = true
	elif current_assignment_type == "troops":
		assignments_completed["troops"] = true
	
	# Check if we need to assign tanks (and haven't already)
	if tank_lighters_exist and not assignments_completed["tanks"]:
		print("-> Starting tank assignment")
		current_assignment_type = "tanks"
		_start_assignment_phase()
		return
	
	# Check if we need a troop briefing after tanks
	if assignments_completed["tanks"] and not assignments_completed["troops"] and troop_monitors_exist:
		print("-> Starting troop briefing after tanks")
		_show_troop_assignment_briefing()
		return
	
	# Check if we need to assign troops (and haven't already)
	if troop_monitors_exist and not assignments_completed["troops"]:
		print("-> Starting troop assignment")
		current_assignment_type = "troops"
		_start_assignment_phase()
		return
	
	# All assignments complete
	print("-> All assignments complete, proceeding...")
	_complete_assignments()
func _show_troop_assignment_briefing():
	"""Show briefing between tank and troop assignments"""
	ui_manager.show_standard_ui()
	ui_manager.hide_image()

	var message = "--- TANK LIGHTER ASSIGNMENTS CONFIRMED ---\n\n"
	message += "The dispositions for the armoured pontoon assault have been logged.\n\n"
	
	var troop_monitors_remaining = data_manager.get_troop_monitors_available()
	message += "You must now assign your " + str(troop_monitors_remaining) + " remaining pontoon assault support monitors."

	ui_manager.display_message(message)
	ui_manager.setup_choices(["Assign Pontoon Support Troops"])
	
	# Connect choice to continue to troop assignment
	await ui_manager.choice_made
	current_assignment_type = "troops"
	_start_assignment_phase()

func _complete_assignments():
	"""All pontoon assignments are complete"""
	print("Assignments complete!")
	print("All pontoon assignments complete")
	assignment_complete.emit()

# --- Main Force Assignment ---
func start_main_force_assignment():
	"""Start the main force assignment phase"""
	current_assignment_index = 0
	data_manager.main_force_plan = {}
	temp_assignment_value = 0
	_ask_for_next_main_force_assignment()

func _ask_for_next_main_force_assignment():
	"""Show assignment UI for the current beach"""
	ui_manager.show_standard_ui()
	ui_manager.hide_image()
	
	var assigned = 0
	for beach in data_manager.main_force_plan: 
		assigned += data_manager.main_force_plan[beach]
	var remaining = data_manager.TOTAL_REINFORCEMENT_BARGES - assigned
	var current_beach = data_manager.assignment_order[current_assignment_index]
	
	var message = "--- MAIN FORCE PHASE ---\n\n"
	for beach_name in data_manager.assignment_order:
		message += " > " + beach_name + ": " + data_manager.targets[beach_name].get("beach_status", "Unknown") + "\n"
	message += "\nYou have " + str(remaining) + " trawlers remaining.\n"
	message += "Assign to " + current_beach + ":\n\n"
	message += "         " + str(temp_assignment_value) + "         \n"
	
	ui_manager.display_message(message)
	ui_manager.setup_choices(["➖", "➕", "Assign"])
	
	# Connect choices
	
	var choice = await ui_manager.choice_made
	_handle_main_force_input(choice)

func _handle_main_force_input(choice: String):
	"""Handle main force assignment input"""
	var assigned_so_far = 0
	for beach in data_manager.main_force_plan: 
		assigned_so_far += data_manager.main_force_plan[beach]
	var remaining = data_manager.TOTAL_REINFORCEMENT_BARGES - assigned_so_far
	
	print("Main force input: ", choice, " | Remaining: ", remaining, " | Current temp value: ", temp_assignment_value)
	
	if choice == "➖":
		temp_assignment_value = max(0, temp_assignment_value - 1)
		_ask_for_next_main_force_assignment()
	elif choice == "➕":
		temp_assignment_value = min(remaining, temp_assignment_value + 1)
		_ask_for_next_main_force_assignment()
	elif choice == "Assign":
		_process_main_force_assignment(str(temp_assignment_value))

func _process_main_force_assignment(player_input: String):
	"""Process the assignment of forces to current beach"""
	var num = int(player_input)
	var current_beach = data_manager.assignment_order[current_assignment_index]
	data_manager.main_force_plan[current_beach] = num
	current_assignment_index += 1
	temp_assignment_value = 0
	
	var assigned_so_far = 0
	for beach in data_manager.main_force_plan: 
		assigned_so_far += data_manager.main_force_plan[beach]
	var remaining = data_manager.TOTAL_REINFORCEMENT_BARGES - assigned_so_far
	
	if current_assignment_index >= data_manager.assignment_order.size() - 1:
		# Auto-assign remaining to last beach
		data_manager.main_force_plan[data_manager.assignment_order.back()] = remaining
		print("Main force assignment complete: ", data_manager.main_force_plan)
		assignment_complete.emit()
	else:
		_ask_for_next_main_force_assignment()

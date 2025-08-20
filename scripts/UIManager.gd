class_name UIManager
extends RefCounted

signal choice_made(choice: String)
signal assignment_change(beach_name: String, change: int)  # Add this line

# Node references (set from main controller)
var main_controller: Control
var data_manager: DataManager

# UI Node references
var display_text: RichTextLabel
var ui_container: Control
var choice_image: TextureRect
var choice_container: Control
var choice_buttons: Array[Button]

# Standard Game UI references
var standard_ui: Control
var pontoon_assignment_ui: Control
var embarkation_ui: Control

# Pontoon Assignment UI references
var assignment_title: Label
var assignment_confirm: Button
var assignment_container: Control

# Embarkation UI references
var confirm_button: Button
var summary_label: Label
var middelkerke_unit_list: Control
var westende_unit_list: Control
var nieuwpoort_unit_list: Control
var middelkerke_stats: Label
var westende_stats: Label
var nieuwpoort_stats: Label

enum UIMode {
	STANDARD,
	PONTOON_ASSIGNMENT,
	MAIN_FORCE_EMBARKATION
}

var current_ui_mode = UIMode.STANDARD

func setup_references(controller: Control, data_mgr: DataManager):
	main_controller = controller
	data_manager = data_mgr
	
	# Get node references from main controller
	display_text = controller.get_node("UIContainer/StandardGameUI/ScrollContainer/DisplayText")
	ui_container = controller.get_node("UIContainer")
	choice_image = controller.get_node("UIContainer/StandardGameUI/ChoiceImage")
	choice_container = controller.get_node("UIContainer/StandardGameUI/ChoiceContainer")
	
	standard_ui = controller.get_node("UIContainer/StandardGameUI")
	pontoon_assignment_ui = controller.get_node("UIContainer/PontoonAssignmentUI")
	embarkation_ui = controller.get_node("UIContainer/EmbarkationUI")
	
	# Pontoon Assignment UI references
	assignment_title = controller.get_node("UIContainer/PontoonAssignmentUI/TitleLabel")
	assignment_confirm = controller.get_node("UIContainer/PontoonAssignmentUI/ConfirmButton")
	assignment_container = controller.get_node("UIContainer/PontoonAssignmentUI/AssignmentContainer")
	
	# Embarkation UI references
	confirm_button = controller.get_node("UIContainer/EmbarkationUI/ConfirmButton")
	summary_label = controller.get_node("UIContainer/EmbarkationUI/SummaryLabel")
	middelkerke_unit_list = controller.get_node("UIContainer/EmbarkationUI/HBoxContainer/MiddelKerkeColumn/ScrollContainer/MiddelKerkeUnitList")
	westende_unit_list = controller.get_node("UIContainer/EmbarkationUI/HBoxContainer/WestendeColumn/ScrollContainer/WestendeColumnUnitList")
	nieuwpoort_unit_list = controller.get_node("UIContainer/EmbarkationUI/HBoxContainer/NieuwpoortColumn/ScrollContainer/NieuwpoortUnitList")
	middelkerke_stats = controller.get_node("UIContainer/EmbarkationUI/HBoxContainer/MiddelKerkeColumn/MiddelKerkeStats")
	westende_stats = controller.get_node("UIContainer/EmbarkationUI/HBoxContainer/WestendeColumn/WestendeColumnStats")
	nieuwpoort_stats = controller.get_node("UIContainer/EmbarkationUI/HBoxContainer/NieuwpoortColumn/NieuwpoortStats")
	
	# Get choice buttons
	choice_buttons = [
		controller.get_node("UIContainer/StandardGameUI/ChoiceContainer/ChoiceButton1"),
		controller.get_node("UIContainer/StandardGameUI/ChoiceContainer/ChoiceButton2"),
		controller.get_node("UIContainer/StandardGameUI/ChoiceContainer/ChoiceButton3")
	]

func setup_ui():
	await _setup_simple_layout()  # Setup layout first
	_create_and_apply_theme()     # Then apply theme
	
	# Connect confirm button if it exists
	if confirm_button:
		confirm_button.pressed.connect(_on_confirm_button_pressed)

func _create_and_apply_theme():
	var new_theme = Theme.new()
	var default_font = load("res://assets/cour.ttf")
	var font_color = Color("6631df")
	var background_color = Color("faf2e5")
	var dark_purple = Color("4a1a9f")  # Darker version of the purple
	
	# Scrollbar styling to make it more visible
	var scrollbar_bg = StyleBoxFlat.new()
	scrollbar_bg.bg_color = Color("e6ded1")  # Darker background color
	scrollbar_bg.corner_radius_top_left = 4
	scrollbar_bg.corner_radius_top_right = 4
	scrollbar_bg.corner_radius_bottom_left = 4
	scrollbar_bg.corner_radius_bottom_right = 4
	
	var scrollbar_grabber = StyleBoxFlat.new()
	scrollbar_grabber.bg_color = font_color  # Purple scrollbar handle
	scrollbar_grabber.corner_radius_top_left = 4
	scrollbar_grabber.corner_radius_top_right = 4
	scrollbar_grabber.corner_radius_bottom_left = 4
	scrollbar_grabber.corner_radius_bottom_right = 4
	
	var scrollbar_grabber_hover = StyleBoxFlat.new()
	scrollbar_grabber_hover.bg_color = dark_purple  # Darker purple on hover
	scrollbar_grabber_hover.corner_radius_top_left = 4
	scrollbar_grabber_hover.corner_radius_top_right = 4
	scrollbar_grabber_hover.corner_radius_bottom_left = 4
	scrollbar_grabber_hover.corner_radius_bottom_right = 4
	
	# Apply scrollbar styles
	new_theme.set_stylebox("scroll", "VScrollBar", scrollbar_bg)
	new_theme.set_stylebox("grabber", "VScrollBar", scrollbar_grabber)
	new_theme.set_stylebox("grabber_highlight", "VScrollBar", scrollbar_grabber_hover)
	new_theme.set_stylebox("grabber_pressed", "VScrollBar", scrollbar_grabber_hover)
	
	# Button styling with subtle background variations
	var button_normal = StyleBoxFlat.new()
	button_normal.bg_color = Color("f0e8db")  # Slightly darker than main background
	button_normal.corner_radius_top_left = 8
	button_normal.corner_radius_top_right = 8
	button_normal.corner_radius_bottom_left = 8
	button_normal.corner_radius_bottom_right = 8
	
	var button_hover = StyleBoxFlat.new()
	button_hover.bg_color = Color("f5ede0")  # Between normal and main background
	button_hover.corner_radius_top_left = 8
	button_hover.corner_radius_top_right = 8
	button_hover.corner_radius_bottom_left = 8
	button_hover.corner_radius_bottom_right = 8
	
	var button_pressed = StyleBoxFlat.new()
	button_pressed.bg_color = Color("e6ded1")  # Darker than normal
	button_pressed.corner_radius_top_left = 8
	button_pressed.corner_radius_top_right = 8
	button_pressed.corner_radius_bottom_left = 8
	button_pressed.corner_radius_bottom_right = 8
	
	# Apply all button states
	new_theme.set_stylebox("normal", "Button", button_normal)
	new_theme.set_stylebox("hover", "Button", button_hover)
	new_theme.set_stylebox("pressed", "Button", button_pressed)
	new_theme.set_stylebox("focus", "Button", button_normal)
	
	# Button font settings
	new_theme.set_font("font", "Button", default_font)
	new_theme.set_font_size("font_size", "Button", 40)
	
	# Different font colors for different states
	new_theme.set_color("font_color", "Button", font_color)           # Normal: regular purple
	new_theme.set_color("font_hover_color", "Button", dark_purple)    # Hover: darker purple
	new_theme.set_color("font_pressed_color", "Button", dark_purple)  # Pressed: darker purple
	new_theme.set_color("font_focus_color", "Button", font_color)     # Focus: regular purple
	
	# RichTextLabel specific settings
	new_theme.set_font("normal_font", "RichTextLabel", default_font)
	new_theme.set_font_size("normal_font_size", "RichTextLabel", 48)
	new_theme.set_color("default_color", "RichTextLabel", font_color)
	
	# General Control settings
	new_theme.set_font("font", "Control", default_font)
	new_theme.set_font_size("font_size", "Control", 48)
	new_theme.set_color("font_color", "Control", font_color)
	
	var bg_stylebox = StyleBoxFlat.new()
	bg_stylebox.bg_color = background_color
	new_theme.set_stylebox("panel", "Control", bg_stylebox)
	
	main_controller.theme = new_theme
	
	print("Theme applied - Darker purple hover with bold text")
func _setup_simple_layout():
	await main_controller.get_tree().process_frame
	
	var viewport_size = main_controller.get_viewport().get_visible_rect().size
	print("Viewport size: ", viewport_size)
	
	if ui_container:
		var padding = 40
		ui_container.position = Vector2(padding, padding)
		ui_container.size = Vector2(viewport_size.x - (padding * 2), viewport_size.y - (padding * 2))
	
	if standard_ui:
		standard_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		standard_ui.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		standard_ui.size_flags_vertical = Control.SIZE_EXPAND_FILL
		
		if standard_ui is VBoxContainer:
			(standard_ui as VBoxContainer).add_theme_constant_override("separation", 20)
	
	if choice_image:
		var available_width = viewport_size.x - 80
		var aspect_ratio_height = available_width * (9.0 / 16.0)
		
		choice_image.custom_minimum_size = Vector2(available_width, aspect_ratio_height)
		choice_image.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		choice_image.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		choice_image.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		choice_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	
	if display_text and display_text.get_parent():
		var scroll_container = display_text.get_parent()
		scroll_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll_container.custom_minimum_size = Vector2(800, 600)
		
		# Configure ScrollContainer properly
		if scroll_container is ScrollContainer:
			scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
			scroll_container.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
			# Make scrollbars always visible for touch devices
			scroll_container.get_v_scroll_bar().modulate = Color.WHITE
			scroll_container.get_v_scroll_bar().custom_minimum_size = Vector2(20, 0)  # Wider scrollbar for touch
		
		# Clear any existing overrides
		display_text.remove_theme_font_size_override("normal_font_size")
		display_text.remove_theme_font_override("normal_font")
		display_text.remove_theme_color_override("default_color")
		
		# IMPORTANT: Enable scrolling and fit content
		display_text.fit_content = true  # Changed to true
		display_text.scroll_active = true  # Changed to true - this was the main issue!
		display_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		display_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
		display_text.custom_minimum_size = Vector2(800, 400)
		
		# Apply RichTextLabel specific settings
		var theme_font_color = Color("6631df")
		var default_font = load("res://assets/cour.ttf")
		
		display_text.add_theme_font_override("normal_font", default_font)
		display_text.add_theme_font_size_override("normal_font_size", 40)
		display_text.add_theme_color_override("default_color", theme_font_color)
		display_text.bbcode_enabled = true
		
		print("RichTextLabel scrolling enabled with visible scrollbars")
		# Apply RichTextLabel specific settings
		
		display_text.add_theme_font_override("normal_font", default_font)
		display_text.add_theme_font_size_override("normal_font_size", 48)
		display_text.add_theme_color_override("default_color", theme_font_color)
		display_text.bbcode_enabled = true
		
		print("RichTextLabel scrolling enabled with visible scrollbars")
	
	if choice_container:
		choice_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		choice_container.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		choice_container.custom_minimum_size = Vector2(0, 80)
	
	for button in choice_buttons:
		if button:
			# Clear existing button font overrides
			button.remove_theme_font_size_override("font_size")
			button.remove_theme_color_override("font_color")
			
			button.custom_minimum_size = Vector2(200, 60)
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			
			# Apply font size
			button.add_theme_font_size_override("font_size", 40)
			
			# Connect hover events for bold effect
			button.mouse_entered.connect(_on_button_hover_start.bind(button))
			button.mouse_exited.connect(_on_button_hover_end.bind(button))
			
			print("Button font size set to: 40")
func show_ui(mode: UIMode):
	current_ui_mode = mode
	
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

func show_standard_ui():
	show_ui(UIMode.STANDARD)

func show_pontoon_assignment_ui():
	show_ui(UIMode.PONTOON_ASSIGNMENT)

func show_embarkation_ui():
	show_ui(UIMode.MAIN_FORCE_EMBARKATION)

func display_message(message: String):
	if display_text:
		display_text.text = message

func set_image(image_path: String):
	if choice_image:
		var tex = load(image_path)
		choice_image.texture = tex
		choice_image.visible = true

func hide_image():
	if choice_image:
		choice_image.visible = false

func setup_choices(options: Array):
	if not choice_container:
		return
		
	choice_container.visible = true
	
	for i in range(choice_buttons.size()):
		var button = choice_buttons[i]
		
		# Disconnect existing connections
		if button.is_connected("pressed", _on_choice_button_pressed):
			button.disconnect("pressed", _on_choice_button_pressed)

		if i < options.size():
			button.text = options[i]
			button.visible = true
			button.pressed.connect(_on_choice_button_pressed.bind(button.text))
		else:
			button.visible = false
			
	if options.is_empty():
		choice_container.visible = false

func _on_choice_button_pressed(choice: String):
	choice_made.emit(choice)

func _on_confirm_button_pressed():
	choice_made.emit("Confirm Embarkation")

# --- Pontoon Assignment UI ---
func setup_pontoon_assignment_ui(assignment_type: String, assignment_values: Dictionary, total_units: int):
	var unit_name = "Tank Lighters" if assignment_type == "tanks" else "Pontoon Support Monitors"
	assignment_title.text = "ASSIGN " + unit_name.to_upper() + " TO BEACHES"
	
	# Style the title for iPad
	assignment_title.add_theme_font_size_override("font_size", 52)
	assignment_title.add_theme_color_override("font_color", Color("6631df"))
	
	# Clear existing UI
	for child in assignment_container.get_children():
		child.queue_free()
	
	await main_controller.get_tree().process_frame
	await main_controller.get_tree().process_frame
	
		# Double-check the container is actually empty
	if assignment_container.get_child_count() > 0:
		print("Warning: Assignment container not properly cleared!")
		for child in assignment_container.get_children():
			child.free()  # Force immediate deletion
			
	# Summary label with larger font
	var assigned_total = 0
	for beach in assignment_values:
		assigned_total += assignment_values[beach]
	
	var summary_label = Label.new()
	summary_label.text = "Available: " + str(total_units) + " | Assigned: " + str(assigned_total) + " | Remaining: " + str(total_units - assigned_total)
	summary_label.add_theme_color_override("font_color", Color("6631df"))
	summary_label.add_theme_font_size_override("font_size", 44)  # Larger font
	summary_label.custom_minimum_size = Vector2(0, 60)  # More height
	assignment_container.add_child(summary_label)
	
	var spacer1 = Control.new()
	spacer1.custom_minimum_size = Vector2(0, 30)  # Bigger spacer
	assignment_container.add_child(spacer1)
	
	# Create assignment rows for each beach
	var assignment_order = ["Middelkerke Bains", "Westende Bains", "Nieuwpoort Bains"]
	for beach_name in assignment_order:
		create_beach_assignment_row(beach_name, assignment_values, total_units, assigned_total)
	
	var spacer2 = Control.new()
	spacer2.custom_minimum_size = Vector2(0, 40)  # Bigger spacer
	assignment_container.add_child(spacer2)
	
	assignment_confirm.text = "Confirm Assignment"
	# Style the confirm button
	assignment_confirm.add_theme_font_size_override("font_size", 48)
	assignment_confirm.custom_minimum_size = Vector2(300, 80)

func create_beach_assignment_row(beach_name: String, assignment_values: Dictionary, total_units: int, assigned_total: int):
	var beach_label = Label.new()
	beach_label.text = beach_name
	beach_label.add_theme_color_override("font_color", Color("6631df"))
	beach_label.add_theme_font_size_override("font_size", 42)  # Larger font
	beach_label.custom_minimum_size = Vector2(0, 50)  # More height
	assignment_container.add_child(beach_label)
	
	var assignment_row = HBoxContainer.new()
	assignment_row.custom_minimum_size = Vector2(0, 80)  # Much larger row
	assignment_row.add_theme_constant_override("separation", 20)  # More spacing
	
	var minus_btn = Button.new()
	minus_btn.text = "➖"
	minus_btn.custom_minimum_size = Vector2(100, 60)  # Larger buttons
	minus_btn.add_theme_font_size_override("font_size", 36)
	minus_btn.pressed.connect(_on_assignment_change.bind(beach_name, -1))
	assignment_row.add_child(minus_btn)
	
	var value_label = Label.new()
	value_label.text = str(assignment_values.get(beach_name, 0))
	value_label.custom_minimum_size = Vector2(120, 60)  # Larger value display
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value_label.add_theme_color_override("font_color", Color("6631df"))
	value_label.add_theme_font_size_override("font_size", 48)  # Large value font
	assignment_row.add_child(value_label)
	
	var plus_btn = Button.new()
	plus_btn.text = "➕"
	plus_btn.custom_minimum_size = Vector2(100, 60)  # Larger buttons
	plus_btn.add_theme_font_size_override("font_size", 36)
	plus_btn.pressed.connect(_on_assignment_change.bind(beach_name, 1))
	assignment_row.add_child(plus_btn)
	
	assignment_container.add_child(assignment_row)
func _on_assignment_change(beach_name: String, change: int):
	assignment_change.emit(beach_name, change)

# --- Embarkation UI ---
func draw_embarkation_ui(division_order_of_battle: Array):
	# Clear existing units
	for child in middelkerke_unit_list.get_children(): 
		child.queue_free()
	for child in westende_unit_list.get_children(): 
		child.queue_free()
	for child in nieuwpoort_unit_list.get_children(): 
		child.queue_free()

	await main_controller.get_tree().process_frame
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

	# Populate units
	for unit in division_order_of_battle:
		var dest = unit.current_dest
		beach_data[dest].strength += unit.strength
		var unit_row = create_unit_row(unit, beach_data[dest].other_beaches)
		beach_data[dest].unit_list.add_child(unit_row)

	# Update stats with larger fonts
	var total_barges = 0
	var SOLDIERS_PER_BARGE = data_manager.SOLDIERS_PER_BARGE
	
	for beach_name in beach_data:
		var data = beach_data[beach_name]
		var strength = data.strength
		var barges = ceil(strength / float(SOLDIERS_PER_BARGE))
		total_barges += barges
		
		data.stats_label.text = "Str: " + str(strength) + " | Barges: " + str(barges)
		data.stats_label.add_theme_color_override("font_color", Color("6631df"))
		data.stats_label.add_theme_font_size_override("font_size", 32)  # Much larger

	var TOTAL_REINFORCEMENT_BARGES = data_manager.TOTAL_REINFORCEMENT_BARGES
	summary_label.text = "Total Barges: " + str(total_barges) + " / " + str(TOTAL_REINFORCEMENT_BARGES)
	summary_label.add_theme_color_override("font_color", Color("6631df"))
	summary_label.add_theme_font_size_override("font_size", 38)  # Much larger
	
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

signal unit_reassigned(unit_data: Dictionary, new_destination: String)

func create_unit_row(unit_data: Dictionary, other_beaches: Array) -> Control:
	var row = VBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 60)  # Much larger rows
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 8)
	
	var unit_label = Label.new()
	unit_label.text = unit_data.name + " [" + str(unit_data.strength) + "]"
	unit_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	unit_label.add_theme_color_override("font_color", Color("6631df"))
	unit_label.add_theme_font_size_override("font_size", 28)  # Much larger font
	unit_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	unit_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	row.add_child(unit_label)
	
	var button_container = HBoxContainer.new()
	button_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button_container.add_theme_constant_override("separation", 8)
	
	for i in range(other_beaches.size()):
		var beach_name = other_beaches[i]
		var button = Button.new()
		
		var beach_initial = beach_name.substr(0, 1)
		button.text = "→" + beach_initial
		button.custom_minimum_size = Vector2(50, 32)  # Larger buttons
		button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		
		button.add_theme_color_override("font_color", Color.WHITE)
		button.add_theme_font_size_override("font_size", 24)  # Larger font
		
		var button_style = StyleBoxFlat.new()
		button_style.bg_color = Color("6631df")
		button_style.corner_radius_top_left = 4
		button_style.corner_radius_top_right = 4
		button_style.corner_radius_bottom_left = 4
		button_style.corner_radius_bottom_right = 4
		button.add_theme_stylebox_override("normal", button_style)
		button.add_theme_stylebox_override("pressed", button_style)
		button.add_theme_stylebox_override("hover", button_style)
		
		button.pressed.connect(_on_reassign_unit.bind(unit_data, beach_name))
		
		button_container.add_child(button)
		
		if i < other_beaches.size() - 1:
			var spacer = Control.new()
			spacer.custom_minimum_size = Vector2(5, 0)  # Bigger spacer
			button_container.add_child(spacer)
	
	row.add_child(button_container)
	
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)  # Bigger spacer
	row.add_child(spacer)
	
	return row

func _on_reassign_unit(unit_data: Dictionary, new_destination: String):
	unit_reassigned.emit(unit_data, new_destination)

func setup_embarkation_footer():
	if not embarkation_ui.has_node("InstructionsLabel"):
		var instructions = Label.new()
		instructions.name = "InstructionsLabel"
		instructions.text = "Use the →M, →W, →N buttons to reassign units between beaches. Barge requirements update automatically."
		instructions.add_theme_color_override("font_color", Color("6631df"))
		instructions.add_theme_font_size_override("font_size", 32)  # Much larger font
		instructions.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		instructions.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		instructions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		instructions.custom_minimum_size = Vector2(0, 80)  # More height
		
		embarkation_ui.add_child(instructions)
		embarkation_ui.move_child(instructions, embarkation_ui.get_child_count() - 2)
	
	if confirm_button:
		confirm_button.add_theme_color_override("font_color", Color.WHITE)
		confirm_button.add_theme_font_size_override("font_size", 42)  # Larger font
		confirm_button.custom_minimum_size = Vector2(300, 80)  # Larger button
		
		var confirm_style = StyleBoxFlat.new()
		confirm_style.bg_color = Color("6631df")
		confirm_style.corner_radius_top_left = 8
		confirm_style.corner_radius_top_right = 8
		confirm_style.corner_radius_bottom_left = 8
		confirm_style.corner_radius_bottom_right = 8
		confirm_button.add_theme_stylebox_override("normal", confirm_style)
		confirm_button.add_theme_stylebox_override("pressed", confirm_style)
		confirm_button.add_theme_stylebox_override("hover", confirm_style)
func _on_button_hover_start(button: Button):
	# Make text bold on hover
	var bold_font = load("res://assets/cour.ttf")  # If you have a bold version, use it here
	# For now, we'll simulate bold by making the text slightly larger
	button.add_theme_font_size_override("font_size", 44)  # Slightly larger for "bold" effect

func _on_button_hover_end(button: Button):
	# Return to normal font
	button.add_theme_font_size_override("font_size", 40)

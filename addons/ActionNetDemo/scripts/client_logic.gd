# res://addons/ActionNetDemo/scripts/client_logic.gd
extends LogicHandler
class_name CustomClientLogicHandler

# DEMO: Client Logic Handler Implementation
# 
# PURPOSE: Demonstrates client-side presentation logic in ActionNet
# RESPONSIBILITIES:
# - Create and update UI elements (scoreboard, timer, status)
# - Read game state from server and translate to visual presentation
# - Handle client-specific effects and feedback
# 
# TIMING: Called every client tick after network data processed
# ACCESS: Latest world state via client.received_state_manager
# 
# SEPARATION PRINCIPLE: 
# - Server owns game rules and authoritative state
# - Client owns presentation and user experience
# - This class bridges server state to client UI

# UI elements
var ui_container: Control
var scoreboard_label: Label
var timer_label: Label
var status_label: Label
var team_label: Label

# Game state tracking
var current_soccer_data: Dictionary = {}
var last_game_state = -1

# References
var client: ActionNetClient

func _ready():
	# Get client reference after ActionNet is initialized
	call_deferred("setup_client_references")

func setup_client_references():
	# Wait for ActionNet to fully initialize
	await get_tree().process_frame
	await get_tree().process_frame
	
	client = ActionNetManager.client
	setup_soccer_ui()
	print("[SoccerClient] Client logic handler initialized")

func setup_soccer_ui():
	# Create UI container
	ui_container = Control.new()
	ui_container.name = "SoccerUI"
	ui_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ActionNetManager.add_child(ui_container)
	
	# Scoreboard
	scoreboard_label = Label.new()
	scoreboard_label.text = "BLUE 0 - 0 RED"
	scoreboard_label.position = Vector2(20, 20)
	scoreboard_label.add_theme_font_size_override("font_size", 28)
	scoreboard_label.add_theme_color_override("font_color", Color.WHITE)
	ui_container.add_child(scoreboard_label)
	
	# Game timer
	timer_label = Label.new()
	timer_label.text = "0:00"
	timer_label.position = Vector2(20, 55)
	timer_label.add_theme_font_size_override("font_size", 20)
	timer_label.add_theme_color_override("font_color", Color.YELLOW)
	ui_container.add_child(timer_label)
	
	# Game status
	status_label = Label.new()
	status_label.text = "Waiting for players..."
	status_label.position = Vector2(400, 20)
	status_label.add_theme_font_size_override("font_size", 24)
	status_label.add_theme_color_override("font_color", Color.CYAN)
	ui_container.add_child(status_label)
	
	# Team assignment
	team_label = Label.new()
	team_label.text = "Team: Not Assigned"
	team_label.position = Vector2(20, 85)
	team_label.add_theme_font_size_override("font_size", 18)
	team_label.add_theme_color_override("font_color", Color.LIGHT_GRAY)
	ui_container.add_child(team_label)
	
	print("[SoccerClient] Soccer UI created")
	
	# Add visual goal markers
	setup_goal_visuals()

func setup_goal_visuals():
	# Center line
	var center_line = ColorRect.new()
	center_line.color = Color.WHITE
	center_line.color.a = 0.8
	center_line.size = Vector2(4, 720)
	center_line.position = Vector2(638, 0)  # Center of 1280px screen
	ui_container.add_child(center_line)
	
	# Center circle
	var center_circle = ColorRect.new()
	center_circle.color = Color.TRANSPARENT
	center_circle.add_theme_stylebox_override("panel", create_circle_style())
	center_circle.size = Vector2(120, 120)
	center_circle.position = Vector2(580, 300)  # Center circle
	ui_container.add_child(center_circle)
	
	# Goal area outlines (visual only)
	# Red goal area outline
	var red_goal_outline = ColorRect.new()
	red_goal_outline.color = Color.TRANSPARENT
	red_goal_outline.add_theme_stylebox_override("panel", create_goal_outline_style(Color.RED))
	red_goal_outline.size = Vector2(60, 150)
	red_goal_outline.position = Vector2(0, 285)
	ui_container.add_child(red_goal_outline)
	
	# Blue goal area outline
	var blue_goal_outline = ColorRect.new()
	blue_goal_outline.color = Color.TRANSPARENT
	blue_goal_outline.add_theme_stylebox_override("panel", create_goal_outline_style(Color.CYAN))
	blue_goal_outline.size = Vector2(60, 150)
	blue_goal_outline.position = Vector2(1220, 285)
	ui_container.add_child(blue_goal_outline)
	
	# Add visual goal posts
	add_goal_post_visuals()
	
	print("[SoccerClient] Soccer field markings added")

func add_goal_post_visuals():
	# Convert physics CENTER positions to ColorRect TOP-LEFT positions
	# Physics: center at (x, y), ColorRect: top-left at (x - width/2, y - height/2)
	
	# RED GOAL POSTS (left side)
	# Back wall: physics center (5, 360), size (10, 150) → top-left (0, 285)
	var red_back = ColorRect.new()
	red_back.color = Color.RED
	red_back.size = Vector2(10, 150)
	red_back.position = Vector2(0, 285)
	ui_container.add_child(red_back)
	
	# Top wall: physics center (30, 285), size (60, 10) → top-left (0, 280)
	var red_top = ColorRect.new()
	red_top.color = Color.RED
	red_top.size = Vector2(60, 10)
	red_top.position = Vector2(0, 280)
	ui_container.add_child(red_top)
	
	# Bottom wall: physics center (30, 435), size (60, 10) → top-left (0, 430)
	var red_bottom = ColorRect.new()
	red_bottom.color = Color.RED
	red_bottom.size = Vector2(60, 10)
	red_bottom.position = Vector2(0, 430)
	ui_container.add_child(red_bottom)
	
	# BLUE GOAL POSTS (right side)
	# Back wall: physics center (1275, 360), size (10, 150) → top-left (1270, 285)
	var blue_back = ColorRect.new()
	blue_back.color = Color.CYAN
	blue_back.size = Vector2(10, 150)
	blue_back.position = Vector2(1270, 285)
	ui_container.add_child(blue_back)
	
	# Top wall: physics center (1250, 285), size (60, 10) → top-left (1220, 280)
	var blue_top = ColorRect.new()
	blue_top.color = Color.CYAN
	blue_top.size = Vector2(60, 10)
	blue_top.position = Vector2(1220, 280)
	ui_container.add_child(blue_top)
	
	# Bottom wall: physics center (1250, 435), size (60, 10) → top-left (1220, 430)
	var blue_bottom = ColorRect.new()
	blue_bottom.color = Color.CYAN
	blue_bottom.size = Vector2(60, 10)
	blue_bottom.position = Vector2(1220, 430)
	ui_container.add_child(blue_bottom)
	
	print("[SoccerClient] Goal visuals aligned with physics collision boxes")

func create_circle_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color.TRANSPARENT
	style.border_color = Color.WHITE
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 60
	style.corner_radius_top_right = 60
	style.corner_radius_bottom_left = 60
	style.corner_radius_bottom_right = 60
	return style

func create_goal_outline_style(color: Color) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color.TRANSPARENT
	style.border_color = color
	style.border_width_left = 3
	style.border_width_right = 3
	style.border_width_top = 3
	style.border_width_bottom = 3
	return style

# DEMO: Client Logic Update - Called Every Client Tick by ActionNet
# 
# EXECUTION CONTEXT:
# - Network data received and processed
# - Local predictions updated
# - World state synchronized
# - Ready for presentation updates
# 
# CLIENT LOGIC RESPONSIBILITIES:
# - Extract game data from ActionNet's world state
# - Update UI elements based on server's authoritative state
# - Handle visual feedback and effects
# - NO game rule enforcement (that's server's job)
func update():
	# Extract custom game data from ActionNet's network state
	update_soccer_data_from_world_state()
	
	# Update UI
	update_scoreboard()
	update_timer()
	update_status()
	update_team_display()

func update_soccer_data_from_world_state():
	# Get latest world state from ActionNet's received state manager
	if client and client.received_state_manager:
		var latest_state = client.received_state_manager.world_registry.get_newest_state()
		if latest_state and latest_state.has("soccer"):
			current_soccer_data = latest_state["soccer"]
		else:
			current_soccer_data = {}

func update_scoreboard():
	if not current_soccer_data.has("blue_score") or not current_soccer_data.has("red_score"):
		return
	
	var blue = current_soccer_data["blue_score"]
	var red = current_soccer_data["red_score"]
	scoreboard_label.text = "BLUE %d - %d RED" % [blue, red]
	
	# Color based on who's winning
	if blue > red:
		scoreboard_label.add_theme_color_override("font_color", Color.CYAN)
	elif red > blue:
		scoreboard_label.add_theme_color_override("font_color", Color.RED)
	else:
		scoreboard_label.add_theme_color_override("font_color", Color.WHITE)

func update_timer():
	if not current_soccer_data.has("game_time") or not current_soccer_data.has("max_time"):
		return
	
	var time = current_soccer_data["game_time"]
	var max_time = current_soccer_data["max_time"]
	
	var minutes = int(time / 60.0)
	var seconds = int(time) % 60
	timer_label.text = "%d:%02d" % [minutes, seconds]
	
	# Change color as time runs out
	var time_ratio = time / max_time if max_time > 0 else 0.0
	if time_ratio > 0.8:
		timer_label.add_theme_color_override("font_color", Color.RED)
	elif time_ratio > 0.6:
		timer_label.add_theme_color_override("font_color", Color.ORANGE)
	else:
		timer_label.add_theme_color_override("font_color", Color.YELLOW)

func update_status():
	if not current_soccer_data.has("game_state"):
		return
	
	var game_state = current_soccer_data["game_state"]
	
	match game_state:
		0:  # WAITING_FOR_PLAYERS
			status_label.text = "Waiting for players..."
			status_label.add_theme_color_override("font_color", Color.CYAN)
		1:  # KICKOFF
			status_label.text = "KICKOFF!"
			status_label.add_theme_color_override("font_color", Color.YELLOW)
		2:  # PLAYING
			status_label.text = "PLAYING!"
			status_label.add_theme_color_override("font_color", Color.GREEN)
		3:  # GOAL_SCORED
			var last_goal_team = current_soccer_data.get("last_goal_team", 0)
			var team_name = "BLUE" if last_goal_team == 1 else "RED"
			status_label.text = "GOAL! %s SCORES!" % team_name
			var color = Color.CYAN if last_goal_team == 1 else Color.RED
			status_label.add_theme_color_override("font_color", color)
	
	# Trigger celebration effects
	if game_state == 3 and last_game_state != game_state:  # GOAL_SCORED
		start_goal_celebration()
	
	last_game_state = game_state

func update_team_display():
	if not client or not client.client_multiplayer or not current_soccer_data.has("teams"):
		return
	
	var my_id = client.client_multiplayer.get_unique_id()
	var teams = current_soccer_data["teams"]
	var my_team = teams.get(my_id, 0)
	
	if my_team == 1:  # BLUE
		team_label.text = "Team: BLUE"
		team_label.add_theme_color_override("font_color", Color.CYAN)
	elif my_team == 2:  # RED
		team_label.text = "Team: RED"
		team_label.add_theme_color_override("font_color", Color.RED)
	else:
		team_label.text = "Team: Not Assigned"
		team_label.add_theme_color_override("font_color", Color.LIGHT_GRAY)

func start_goal_celebration():
	print("[SoccerClient] GOAL celebration!")
	# Could add more celebration effects here

func _exit_tree():
	# Clean up UI when disconnecting
	if ui_container:
		ui_container.queue_free()

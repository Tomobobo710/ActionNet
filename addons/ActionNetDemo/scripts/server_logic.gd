# res://addons/ActionNetDemo/scripts/server_logic.gd
extends LogicHandler
class_name CustomServerLogicHandler

# DEMO: Server Logic Handler Implementation
# 
# PURPOSE: Demonstrates authoritative game logic in ActionNet
# RESPONSIBILITIES:
# - Manage game state (scores, timers, game phases)
# - Enforce game rules (goal detection, team assignment)
# - Update world state that gets sent to all clients
# 
# TIMING: Called every server tick after physics, before network send
# ACCESS: Full authoritative world state via server.world_manager
# 
# SOCCER GAME LOGIC: Manages match flow, scoring, and team management

enum GameState {
	WAITING_FOR_PLAYERS,
	KICKOFF,
	PLAYING,
	GOAL_SCORED
}

enum Team {
	NONE = 0,
	BLUE = 1,
	RED = 2
}

# Game state
var current_game_state: GameState = GameState.WAITING_FOR_PLAYERS
var blue_score: int = 0
var red_score: int = 0
var game_time: float = 0.0
var max_game_time: float = 300.0  # 5 minutes
var goal_celebration_timer: float = 0.0
var last_goal_team: Team = Team.NONE
var kickoff_timer: float = 0.0

# Team management
var team_assignments: Dictionary = {}  # client_id -> Team
var next_team_assignment: Team = Team.BLUE

# Soccer field dimensions (matching actual screen)
var field_width: float = 1280.0
var field_height: float = 720.0
var goal_width: float = 150.0
var goal_depth: float = 60.0

# Simple goal areas for detection (no physics walls)
var red_goal_area = {"x_min": 0, "x_max": 100, "y_min": 260, "y_max": 460}
var blue_goal_area = {"x_min": 1180, "x_max": 1280, "y_min": 260, "y_max": 460}

# References
var server: ActionNetServer
var world_manager: WorldManager

func _ready():
	# Connect to ActionNet events
	ActionNetManager.server_created.connect(_on_actionnet_server_created)
	ActionNetManager.client_created.connect(_on_actionnet_client_created)

func _on_actionnet_server_created():
	server = ActionNetManager.server
	if server:
		world_manager = server.world_manager
		server.client_connected.connect(_on_client_connected)
		server.client_disconnected.connect(_on_client_disconnected)
		print("[SoccerGame] Connected to server events")

func _on_actionnet_client_created():
	print("[SoccerGame] Client created, ready for game data")

func _on_client_connected(client_id: int):
	print("[SoccerGame] Player ", client_id, " joined the game")
	
	# Assign to team
	team_assignments[client_id] = next_team_assignment
	print("[SoccerGame] Player ", client_id, " assigned to team ", Team.keys()[next_team_assignment])
	
	# Alternate team assignments
	next_team_assignment = Team.RED if next_team_assignment == Team.BLUE else Team.BLUE
	
	# Start game if we have at least 2 players
	if team_assignments.size() >= 2 and current_game_state == GameState.WAITING_FOR_PLAYERS:
		start_game()

func _on_client_disconnected(client_id: int):
	print("[SoccerGame] Player ", client_id, " left the game")
	team_assignments.erase(client_id)
	
	# Reset game if not enough players
	if team_assignments.size() < 2:
		current_game_state = GameState.WAITING_FOR_PLAYERS
		game_time = 0.0
		print("[SoccerGame] Not enough players, game reset")

func start_game():
	current_game_state = GameState.KICKOFF
	game_time = 0.0
	blue_score = 0
	red_score = 0
	kickoff_timer = 0.0
	print("[SoccerGame] Game started! Preparing kickoff...")
	setup_kickoff()

# DEMO: Server Logic Update - Called Every Server Tick by ActionNet
# 
# EXECUTION CONTEXT:
# - Physics simulation complete
# - All player inputs processed 
# - World state finalized
# - About to send state to clients
# 
# GAME LOGIC RESPONSIBILITIES:
# - Update match timer and check time limits
# - Detect goals and update scores
# - Manage game state transitions (kickoff, playing, goal celebration)
# - Assign teams to new players
# - Add custom game data to world state for client consumption
func update():
	# Try to get server reference if we don't have it
	if not world_manager:
		if not server and ActionNetManager.server:
			server = ActionNetManager.server
			world_manager = server.world_manager
			server.client_connected.connect(_on_client_connected)
			server.client_disconnected.connect(_on_client_disconnected)
			print("[SoccerGame] Connected to server events via update loop")
		return
	
	# Check for new unassigned clients
	check_for_unassigned_clients()
	
	# Add soccer game state to ActionNet's world state
	add_soccer_state_to_world()
	
	# Handle game state
	match current_game_state:
		GameState.WAITING_FOR_PLAYERS:
			handle_waiting_state()
		GameState.KICKOFF:
			handle_kickoff_state()
		GameState.PLAYING:
			handle_playing_state()
		GameState.GOAL_SCORED:
			handle_goal_celebration()

func add_soccer_state_to_world():
	if server and server.processed_state:
		server.processed_state["soccer"] = {
			"game_state": current_game_state,
			"blue_score": blue_score,
			"red_score": red_score,
			"game_time": game_time,
			"max_time": max_game_time,
			"teams": team_assignments.duplicate(),
			"last_goal_team": last_goal_team
		}

func check_for_unassigned_clients():
	if not server or not world_manager or not world_manager.client_objects:
		return
	
	var connected_clients = []
	for client_obj in world_manager.client_objects.get_children():
		var client_id = int(str(client_obj.name))
		connected_clients.append(client_id)
	
	var newly_assigned = false
	for client_id in connected_clients:
		if not team_assignments.has(client_id):
			team_assignments[client_id] = next_team_assignment
			print("[SoccerGame] Auto-assigned player ", client_id, " to team ", Team.keys()[next_team_assignment])
			next_team_assignment = Team.RED if next_team_assignment == Team.BLUE else Team.BLUE
			newly_assigned = true
	
	if newly_assigned and team_assignments.size() >= 2 and current_game_state == GameState.WAITING_FOR_PLAYERS:
		start_game()

func handle_waiting_state():
	# Just wait for more players
	pass

func handle_kickoff_state():
	kickoff_timer += 1.0 / 60.0
	
	# Give players 3 seconds to get ready
	if kickoff_timer >= 3.0:
		current_game_state = GameState.PLAYING
		print("[SoccerGame] Kickoff complete, game is now PLAYING!")

func handle_playing_state():
	# Update game timer
	game_time += 1.0 / 60.0
	
	# Check for goals
	check_for_goals()
	
	# Color players by team
	update_player_colors()
	
	# Check for game end
	if game_time >= max_game_time:
		print("[SoccerGame] FULL TIME! Final score - Blue: ", blue_score, ", Red: ", red_score)
		current_game_state = GameState.WAITING_FOR_PLAYERS
		game_time = 0.0

func handle_goal_celebration():
	goal_celebration_timer += 1.0 / 60.0
	
	if goal_celebration_timer >= 3.0:  # 3 second celebration
		goal_celebration_timer = 0.0
		current_game_state = GameState.KICKOFF
		kickoff_timer = 0.0
		setup_kickoff()
		print("[SoccerGame] Setting up kickoff after goal")

func check_for_goals():
	var ball = get_ball()
	if not ball:
		return
	
	# Convert ball position to world coordinates
	var ball_world_pos = Vector2(ball.fixed_position.x, ball.fixed_position.y) / Physics.SCALE
	
	# Check if ball is inside goal areas
	# Blue goal (right side)
	if (ball_world_pos.x >= blue_goal_area.x_min and ball_world_pos.x <= blue_goal_area.x_max and
		ball_world_pos.y >= blue_goal_area.y_min and ball_world_pos.y <= blue_goal_area.y_max):
		score_goal(Team.BLUE)
		return
	
	# Red goal (left side)
	if (ball_world_pos.x >= red_goal_area.x_min and ball_world_pos.x <= red_goal_area.x_max and
		ball_world_pos.y >= red_goal_area.y_min and ball_world_pos.y <= red_goal_area.y_max):
		score_goal(Team.RED)
		return

func score_goal(scoring_team: Team):
	if scoring_team == Team.BLUE:
		blue_score += 1
		print("[SoccerGame] GOAL! Blue team scores! Score: Blue ", blue_score, " - ", red_score, " Red")
	else:
		red_score += 1
		print("[SoccerGame] GOAL! Red team scores! Score: Blue ", blue_score, " - ", red_score, " Red")
	
	last_goal_team = scoring_team
	current_game_state = GameState.GOAL_SCORED
	goal_celebration_timer = 0.0

func setup_kickoff():
	# Reset ball to center
	reset_ball_position()
	
	# Position players for kickoff
	position_players_for_kickoff()

func reset_ball_position():
	var ball = get_ball()
	if ball:
		# Center of field
		ball.fixed_position = Physics.vec2(640, 360)
		ball.fixed_velocity = Vector2i(0, 0)
		ball.fixed_rotation = 0
		ball.fixed_angular_velocity = 0
		print("[SoccerGame] Ball reset to center (640, 360)")

func position_players_for_kickoff():
	if not world_manager or not world_manager.client_objects:
		return
	
	var blue_players = []
	var red_players = []
	
	# Separate players by team
	for player in world_manager.client_objects.get_children():
		var client_id = int(str(player.name))
		var team = team_assignments.get(client_id, Team.NONE)
		if team == Team.BLUE:
			blue_players.append(player)
		elif team == Team.RED:
			red_players.append(player)
	
	# Position Blue team (right side of field)
	for i in range(blue_players.size()):
		var player = blue_players[i]
		var x_pos = 800 + (i * 60)  # Right side formation
		var y_pos = 360 + (i - blue_players.size()/2.0) * 100
		player.fixed_position = Physics.vec2(x_pos, y_pos)
		player.fixed_velocity = Vector2i(0, 0)
	
	# Position Red team (left side of field)
	for i in range(red_players.size()):
		var player = red_players[i]
		var x_pos = 480 - (i * 60)  # Left side formation
		var y_pos = 360 + (i - red_players.size()/2.0) * 100
		player.fixed_position = Physics.vec2(x_pos, y_pos)
		player.fixed_velocity = Vector2i(0, 0)
	
	print("[SoccerGame] Players positioned for kickoff - Blue: ", blue_players.size(), ", Red: ", red_players.size())

func update_player_colors():
	if not world_manager or not world_manager.client_objects:
		return
	
	for player in world_manager.client_objects.get_children():
		var client_id = int(str(player.name))
		var team = team_assignments.get(client_id, Team.NONE)
		
		if team == Team.BLUE:
			player.set_color(Color.CYAN)
		elif team == Team.RED:
			player.set_color(Color.RED)
		else:
			player.set_color(Color.WHITE)

func get_ball():
	if not world_manager or not world_manager.physics_objects:
		return null
	
	for child in world_manager.physics_objects.get_children():
		if "ball" in child.name.to_lower():
			return child
	
	return null

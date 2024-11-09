# res://addons/ActionNet/scripts/ui/action_net_debug_ui.gd
extends CanvasLayer

class_name ActionNetDebugUI

const THEME_COLORS = {
	"background": Color("1a1a1a50"),
	"panel": Color("2a2a2a50"),
	"header": Color("3a3a3a50"),
	"text": Color("e0e0e0"),
	"text_dim": Color("909090"),
	"accent": Color("5294e2"),
	"warning": Color("e2a752"),
	"error": Color("e25252"),
	"success": Color("52e252")
}

var debug_panel: PanelContainer
var client_section: PanelContainer
var server_section: PanelContainer
var rtt_graph: RTTGraphControl

# Client labels
var connection_status_label: Label
var client_id_label: Label
var client_sequence_label: Label
var frame_ahead_label: Label
var rtt_label: Label
var sync_status_label: Label
var handshake_label: Label
var network_stats_label: Label
var client_world_stats_label: Label
var client_input_label: Label
var sequence_sync_label: Label
var rtt_tracking_label: Label
var adjustment_stats_label: Label

# Server labels
var server_status_label: Label
var server_sequence_label: Label
var server_clients_label: Label
var server_world_stats_label: Label
var server_network_stats_label: Label
var server_physics_stats_label: Label
var server_input_stats_label: Label
var server_memory_stats_label: Label
var server_collision_stats_label: Label

var server: ActionNetServer
var client: ActionNetClient

var error_popup: AcceptDialog
var stats_update_timer: float = 0.0
var stats_update_interval: float = 1.0

func _ready():
	create_debug_panel()
	create_error_popup()
	hide()

func create_error_popup():
	error_popup = AcceptDialog.new()
	error_popup.dialog_autowrap = true
	error_popup.size = Vector2(500, 100)
	var style = StyleBoxFlat.new()
	style.bg_color = THEME_COLORS.panel
	style.border_color = THEME_COLORS.accent
	#style.corner_radius_all = 4
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	error_popup.add_theme_stylebox_override("panel", style)
	add_child(error_popup)

func show_error_popup(error_message: String):
	error_popup.dialog_text = error_message
	error_popup.popup_centered()

func create_debug_panel():
	debug_panel = PanelContainer.new()
	debug_panel.custom_minimum_size = Vector2(400, 0)
	debug_panel.anchor_left = 1.0
	debug_panel.anchor_right = 1.0
	debug_panel.anchor_bottom = 1.0
	debug_panel.offset_left = -420  # Added margin from right edge
	debug_panel.offset_right = -20  # Added margin from right edge
	debug_panel.offset_top = 20     # Added margin from top
	debug_panel.offset_bottom = -20 # Added margin from bottom
	debug_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	debug_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = THEME_COLORS.background
	panel_style.border_width_left = 2
	panel_style.border_color = THEME_COLORS.panel
	#panel_style.corner_radius_all = 4
	debug_panel.add_theme_stylebox_override("panel", panel_style)
	
	# ScrollContainer setup:
	var scroll_container = ScrollContainer.new()
	scroll_container.anchor_right = 1.0
	scroll_container.anchor_bottom = 1.0
	scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED  # Disable horizontal scrolling
	debug_panel.add_child(scroll_container)

	# Ensure main_vbox takes full width:
	var main_vbox = VBoxContainer.new()
	main_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL  # Added for completeness
	main_vbox.add_theme_constant_override("separation", 10)
	scroll_container.add_child(main_vbox)
	
	create_title_section(main_vbox)
	create_client_section(main_vbox)
	create_server_section(main_vbox)
	
	add_child(debug_panel)

func create_title_section(parent: VBoxContainer):
	var title_panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = THEME_COLORS.header
	style.border_width_bottom = 2
	style.border_color = THEME_COLORS.accent
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.content_margin_left = 12
	style.content_margin_right = 12
	title_panel.add_theme_stylebox_override("panel", style)
	
	var title = Label.new()
	title.text = "ActionNet Debug (F9)"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", THEME_COLORS.accent)
	title.custom_minimum_size = Vector2(0, 40)
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_panel.add_child(title)
	
	parent.add_child(title_panel)

func create_section_header(title: String, content: Control) -> PanelContainer:
	var header_panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = THEME_COLORS.header
	style.border_width_bottom = 1
	style.border_color = THEME_COLORS.accent
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	header_panel.add_theme_stylebox_override("panel", style)
	
	var hbox = HBoxContainer.new()
	
	var button = Button.new()
	button.text = "▼"
	button.custom_minimum_size = Vector2(40, 30)
	button.flat = true
	button.add_theme_color_override("font_color", THEME_COLORS.accent)
	button.add_theme_color_override("font_hover_color", THEME_COLORS.text)
	
	var label = Label.new()
	label.text = title
	label.add_theme_color_override("font_color", THEME_COLORS.text)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.custom_minimum_size = Vector2(0, 30)
	
	hbox.add_child(button)
	hbox.add_child(label)
	
	header_panel.add_child(hbox)
	
	button.pressed.connect(func():
		content.visible = !content.visible
		button.text = "▼" if content.visible else "▶"
	)
	
	return header_panel

func create_info_label() -> Label:
	var label = Label.new()
	label.add_theme_color_override("font_color", THEME_COLORS.text_dim)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART  # Enable smart word wrapping
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL # Make label expand horizontally
	return label

func create_client_section(parent: VBoxContainer):
	client_section = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = THEME_COLORS.panel
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	client_section.add_theme_stylebox_override("panel", style)
	
	var header = create_section_header("Client", client_section)
	var content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	
	# Create all client-related labels
	connection_status_label = create_info_label()
	client_id_label = create_info_label()
	client_sequence_label = create_info_label()
	frame_ahead_label = create_info_label()
	sync_status_label = create_info_label()
	handshake_label = create_info_label()
	rtt_label = create_info_label()
	rtt_graph = RTTGraphControl.new()
	content.add_child(rtt_graph)
	network_stats_label = create_info_label()
	client_world_stats_label = create_info_label()
	client_input_label = create_info_label()
	sequence_sync_label = create_info_label()
	rtt_tracking_label = create_info_label()
	adjustment_stats_label = create_info_label()
	
	var labels = [
		connection_status_label,
		sync_status_label,
		client_id_label,
		handshake_label,
		client_sequence_label,
		frame_ahead_label,
		sequence_sync_label,
		rtt_label,
		rtt_tracking_label,
		adjustment_stats_label,
		network_stats_label,
		client_world_stats_label,
		client_input_label
	]
	
	for label in labels:
		label.add_theme_constant_override("line_spacing", 4)
		content.add_child(label)
	
	client_section.add_child(content)
	
	parent.add_child(header)
	parent.add_child(client_section)

func create_server_section(parent: VBoxContainer):
	server_section = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = THEME_COLORS.panel
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	server_section.add_theme_stylebox_override("panel", style)
	
	var header = create_section_header("Server", server_section)
	var content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	
	server_status_label = create_info_label()
	server_sequence_label = create_info_label()
	server_clients_label = create_info_label()
	server_world_stats_label = create_info_label()
	server_network_stats_label = create_info_label()
	server_physics_stats_label = create_info_label()
	server_input_stats_label = create_info_label()
	server_memory_stats_label = create_info_label()
	server_collision_stats_label = create_info_label()
	
	var labels = [
		server_status_label, server_sequence_label, server_clients_label,
		server_world_stats_label, server_network_stats_label,
		server_physics_stats_label, server_input_stats_label,
		server_memory_stats_label, server_collision_stats_label
	]
	
	for label in labels:
		label.add_theme_constant_override("line_spacing", 4)
		content.add_child(label)
	
	server_section.add_child(content)
	
	parent.add_child(header)
	parent.add_child(server_section)

func get_status_color(status: String) -> Color:
	match status.to_lower():
		"connected": return THEME_COLORS.success
		"active": return THEME_COLORS.success
		"connecting...": return THEME_COLORS.warning
		"disconnected": return THEME_COLORS.error
		"inactive": return THEME_COLORS.error
	return THEME_COLORS.text_dim

func _process(delta):
	if not visible:
		return
		
	stats_update_timer += delta
	var update_heavy_stats = stats_update_timer >= stats_update_interval
	
	if client:
		# Add the current RTT sample to the graph
		if client.connection_manager.sequence_adjuster.current_rtt > 0:
			rtt_graph.add_sample(client.connection_manager.sequence_adjuster.current_rtt)
		update_client_stats(update_heavy_stats)
	
	if server:
		update_server_stats(update_heavy_stats)

func update_client_stats(update_heavy_stats: bool):
	# Connection Status
	var connection_status = "Disconnected"
	if client.network:
		match client.network.get_connection_status():
			MultiplayerPeer.CONNECTION_DISCONNECTED: connection_status = "Disconnected"
			MultiplayerPeer.CONNECTION_CONNECTING: connection_status = "Connecting..."
			MultiplayerPeer.CONNECTION_CONNECTED: connection_status = "Connected"
	
	var status_color = get_status_color(connection_status)
	connection_status_label.text = "Connection Status: " + connection_status
	connection_status_label.add_theme_color_override("font_color", status_color)
	
	# Client ID and Basic Info
	var client_id = str(client.client_multiplayer.get_unique_id()) if client.client_multiplayer else "N/A"
	client_id_label.text = "Client ID: " + client_id
	
	# Handshake Information
	var handshake_info = "Handshake Status:"
	handshake_info += "\nIn Progress: " + str(client.connection_manager.handshake_in_progress)
	if client.connection_manager.handshake_in_progress:
		handshake_info += "\nTimer: " + str(snappedf(client.connection_manager.handshake_timer, 0.01)) + "/" + str(client.connection_manager.handshake_duration)
		handshake_info += "\nPings Sent: " + str(client.connection_manager.handshake_pings_sent) + "/" + str(client.connection_manager.handshake_pings_total)
		handshake_info += "\nSpawn Requested: " + str(client.connection_manager.spawn_requested)
		handshake_info += "\nClient Object Confirmed: " + str(client.connection_manager.client_object_confirmed)
	handshake_label.text = handshake_info
	
	# Sequence and Sync Information
	client_sequence_label.text = "Client Sequence: " + str(client.connection_manager.sequence_adjuster.client_sequence)
	frame_ahead_label.text = "Frames Ahead: " + str(client.connection_manager.sequence_adjuster.frames_ahead)
	
	var sequence_info = "Sequence Sync Info:"
	sequence_info += "\nServer Sequence Estimate: " + str(client.connection_manager.sequence_adjuster.server_sequence_estimate)
	sequence_info += "\nLast Processed Sequence: " + str(client.last_processed_sequence)
	sequence_info += "\nMin Frames Ahead: " + str(client.connection_manager.sequence_adjuster.min_frames_ahead)
	sequence_info += "\nMax Frames Ahead: " + str(client.connection_manager.sequence_adjuster.max_frames_ahead)
	sequence_info += "\nBaseline RTT: " + str(client.connection_manager.sequence_adjuster.baseline_rtt) + "ms"
	sequence_sync_label.text = sequence_info
	
	# Sync Status
	var sync_status = "Synced" if !client.connection_manager.handshake_in_progress else "Initial sync in progress"
	sync_status_label.text = "Sync Status: " + sync_status
	sync_status_label.add_theme_color_override("font_color", 
		THEME_COLORS.success if !client.connection_manager.handshake_in_progress else THEME_COLORS.warning)
	
	# RTT Information
	var rtt_info = "RTT: " + str(client.connection_manager.sequence_adjuster.current_rtt) + "ms"
	rtt_info += "\nSamples: " + str(client.connection_manager.rtt_samples.size()) + "/" + str(client.connection_manager.max_rtt_samples)
	if not client.connection_manager.rtt_samples.is_empty():
		var avg_rtt = 0
		for rtt in client.connection_manager.rtt_samples:
			avg_rtt += rtt
		avg_rtt = avg_rtt / client.connection_manager.rtt_samples.size()
		rtt_info += "\nAverage RTT: " + str(avg_rtt) + "ms"
	rtt_label.text = rtt_info
	
	# RTT Tracking Details
	var rtt_tracking = "RTT Tracking:"
	rtt_tracking += "\nWindow Size: " + str(client.connection_manager.sequence_adjuster.rtt_window.size()) + "/" + str(client.connection_manager.sequence_adjuster.rtt_window_size)
	rtt_tracking += "\nRTT Threshold: " + str(client.connection_manager.sequence_adjuster.rtt_threshold_ms) + "ms"
	rtt_tracking_label.text = rtt_tracking
	
	# Sequence Adjustment Stats
	var adjustment_info = "Sequence Adjustment:"
	adjustment_info += "\nEnabled: " + str(client.connection_manager.sequence_adjuster.sequence_adjustment_enabled)
	adjustment_info += "\nCooldown: " + str(client.connection_manager.sequence_adjuster.adjustment_cooldown) + "s"
	if client.connection_manager.sequence_adjuster.last_adjustment_time > 0:
		var time_since = Time.get_ticks_msec() / 1000.0 - client.connection_manager.sequence_adjuster.last_adjustment_time
		adjustment_info += "\nTime Since Last: " + str(snappedf(time_since, 0.1)) + "s"
	adjustment_stats_label.text = adjustment_info
	
	# Network Stats
	var net_stats = "Network Stats:"
	net_stats += "\nSending Inputs: " + str(client.is_sending_inputs)
	net_stats += "\nPing Timer: " + str(snappedf(client.connection_manager.ping_timer, 0.1)) + "/" + str(client.connection_manager.ping_interval)
	if client.connection_manager.last_ping_time > 0:
		net_stats += "\nLast Ping: " + str(Time.get_ticks_msec() - client.connection_manager.last_ping_time) + "ms ago"
	network_stats_label.text = net_stats
	
	# World Stats
	if update_heavy_stats and client.client_world:
		var world_stats = "World Stats:"
		world_stats += "\nClient Objects: " + str(client.client_objects.get_child_count() if client.client_objects else 0)
		world_stats += "\nPhysics Objects: " + str(client.physics_objects.get_child_count() if client.physics_objects else 0)
		world_stats += "\nWorld Tree Path: " + str(client.client_world.get_path())
		client_world_stats_label.text = world_stats
		
		# Input Stats
		var input_info = "Input Information:"
		if client.manager and client.manager.input_definitions:
			input_info += "\nRegistered Actions: " + str(client.manager.input_definitions.keys())
		client_input_label.text = input_info

func update_server_stats(update_heavy_stats: bool):
	var status = "Active" if server.network else "Inactive"
	if server.network:
		status += " (Port: " + str(server.port) + ")"
	server_status_label.text = "Server Status: " + status
	server_status_label.add_theme_color_override("font_color", get_status_color(status))
	
	server_sequence_label.text = "Sequence: " + str(server.world_manager.sequence)
	
	var clients_info = "Connected Clients: " + str(server.clients.size())
	clients_info += "\nClient IDs: " + str(server.clients.keys())
	server_clients_label.text = clients_info
	
	if update_heavy_stats:
		var world_stats = "World Stats:"
		world_stats += "\nClient Objects: " + str(server.world_manager.client_objects.get_child_count())
		world_stats += "\nPhysics Objects: " + str(server.world_manager.physics_objects.get_child_count())
		server_world_stats_label.text = world_stats
		
		var net_stats = "Network Stats:"
		net_stats += "\nPort: " + str(server.port)
		net_stats += "\nMax Clients: " + str(server.max_clients)
		if server.network:
			net_stats += "\nConnection Status: " + str(server.network.get_connection_status())
		server_network_stats_label.text = net_stats
		
		var collision_stats = "Collision Stats:"
		if server.collision_manager:
			var registered = server.collision_manager.get_registered_objects()
			collision_stats += "\nRegistered Objects: " + str(registered.size())
		server_collision_stats_label.text = collision_stats
		
		var input_stats = "Input Stats:"
		var total_stored = 0
		for client_id in server.input_registry.stored_inputs.keys():
			total_stored += server.input_registry.stored_inputs[client_id].size()
			input_stats += "\nClient " + str(client_id) + ": " + str(server.input_registry.stored_inputs[client_id].size()) + " inputs"
		input_stats += "\nTotal Stored Inputs: " + str(total_stored)
		server_input_stats_label.text = input_stats
		
		var memory_stats = server.input_registry.get_stats()
		var mem_text = "Memory Stats:"
		mem_text += "\nTotal Inputs Stored: " + str(memory_stats.total_inputs_stored)
		mem_text += "\nClients with Inputs: " + str(memory_stats.clients_with_inputs)
		mem_text += "\nEstimated Memory: " + str(memory_stats.estimated_memory_kb) + " KB"
		server_memory_stats_label.text = mem_text

func _input(event):
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_F9:
			toggle_visibility()

func toggle_visibility():
	visible = !visible

func set_server(new_server: ActionNetServer):
	server = new_server

func set_client(new_client: ActionNetClient):
	client = new_client

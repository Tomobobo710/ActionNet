# res://addons/ActionNet/scripts/ui/rtt_graph.gd
extends Control
class_name RTTGraphControl

const DISPLAY_TIME_SPAN = 60.0  # Show last 60 seconds
const GRAPH_PADDING = 20
const Y_AXIS_LABELS = 5
const MIN_RANGE = 20.0
const RANGE_PADDING_PERCENT = 0.5
const BUCKET_SIZE = 0.25  # Store one sample per 250ms

class TimeBucket:
	var min_value: float
	var max_value: float
	var sum: float
	var count: int
	var timestamp: float
	
	func _init(value: float, time: float):
		min_value = value
		max_value = value
		sum = value
		count = 1
		timestamp = time
	
	func add_sample(value: float):
		min_value = min(min_value, value)
		max_value = max(max_value, value)
		sum += value
		count += 1
	
	func get_average() -> float:
		return sum / count if count > 0 else 0.0

var buckets: Array[TimeBucket] = []
var moving_average: float = 0
var last_value: float = 0
var min_value: float = 0
var max_value: float = 100

var graph_line: Line2D
var baseline: Line2D
var grid_lines: Node2D
var labels: Node2D

func _ready():
	custom_minimum_size = Vector2(0, 160)
	size_flags_horizontal = SIZE_EXPAND_FILL
	
	# Create containers
	grid_lines = Node2D.new()
	labels = Node2D.new()
	add_child(grid_lines)
	add_child(labels)
	
	# Setup baseline
	baseline = Line2D.new()
	baseline.default_color = Color("ffff0040")
	baseline.width = 2.0
	baseline.antialiased = true
	add_child(baseline)
	
	# Setup graph line
	graph_line = Line2D.new()
	graph_line.default_color = Color("5294e2")
	graph_line.width = 2.0
	graph_line.antialiased = true
	add_child(graph_line)
	
	_setup_grid_lines()

func _setup_grid_lines():
	# Horizontal lines
	for i in range(Y_AXIS_LABELS + 1):
		var line = Line2D.new()
		line.default_color = Color("ffffff20")
		line.width = 1.0
		grid_lines.add_child(line)
	
	# Vertical lines
	for i in range(5):
		var line = Line2D.new()
		line.default_color = Color("ffffff20")
		line.width = 1.0
		grid_lines.add_child(line)

func add_sample(value: float):
	var current_time = Time.get_ticks_msec() / 1000.0
	last_value = value
	
	# Calculate which bucket this sample belongs in
	var bucket_time = floor(current_time / BUCKET_SIZE) * BUCKET_SIZE
	
	# Remove old buckets
	while buckets.size() > 0 and current_time - buckets[0].timestamp > DISPLAY_TIME_SPAN:
		buckets.pop_front()
	
	# Add to existing bucket or create new one
	if buckets.size() > 0 and buckets[-1].timestamp == bucket_time:
		buckets[-1].add_sample(value)
	else:
		buckets.append(TimeBucket.new(value, bucket_time))
	
	# Update moving average and range
	if buckets.size() > 0:
		# Calculate moving average from buckets
		var total_sum = 0.0
		var total_count = 0
		for bucket in buckets:
			total_sum += bucket.sum
			total_count += bucket.count
		moving_average = total_sum / total_count if total_count > 0 else value
		
		# Calculate range using recent buckets
		var max_deviation = 0.0
		var recent_buckets = buckets.slice(max(0, buckets.size() - 20))  # Look at last 5 seconds
		for bucket in recent_buckets:
			max_deviation = max(max_deviation, abs(bucket.max_value - moving_average))
			max_deviation = max(max_deviation, abs(bucket.min_value - moving_average))
		
		max_deviation = max(max_deviation, MIN_RANGE / 2.0)
		var range_with_padding = max_deviation * (1 + RANGE_PADDING_PERCENT)
		
		min_value = max(0, moving_average - range_with_padding)
		max_value = moving_average + range_with_padding
		
		if min_value < 0:
			min_value = 0
			max_value = max(max_value, moving_average + range_with_padding * 2)
	
	_update_display()

func _update_display():
	_update_graph()
	_update_grid()
	queue_redraw()

func _update_graph():
	var graph_rect = _get_graph_rect()
	var points = PackedVector2Array()
	
	if buckets.size() > 0:
		var current_time = Time.get_ticks_msec() / 1000.0
		
		for bucket in buckets:
			var time_ago = current_time - bucket.timestamp
			var x = graph_rect.position.x + graph_rect.size.x * (1.0 - time_ago / DISPLAY_TIME_SPAN)
			
			# Skip points that would be drawn outside the graph
			if x < graph_rect.position.x:
				continue
			
			# Plot min and max points for each bucket
			var y_min = _value_to_y(bucket.min_value)
			var y_max = _value_to_y(bucket.max_value)
			points.append(Vector2(x, y_min))
			points.append(Vector2(x, y_max))
		
		# Add current value point
		var x = graph_rect.position.x + graph_rect.size.x
		var y = _value_to_y(last_value)
		points.append(Vector2(x, y))
	
	graph_line.points = points
	
	# Update baseline
	var avg_y = _value_to_y(moving_average)
	baseline.points = PackedVector2Array([
		Vector2(graph_rect.position.x, avg_y),
		Vector2(graph_rect.position.x + graph_rect.size.x, avg_y)
	])

func _update_grid():
	var graph_rect = _get_graph_rect()
	
	# Update horizontal grid lines
	for i in range(Y_AXIS_LABELS + 1):
		var line = grid_lines.get_child(i)
		var y_pos = graph_rect.position.y + (graph_rect.size.y * (1 - float(i) / Y_AXIS_LABELS))
		line.points = PackedVector2Array([
			Vector2(graph_rect.position.x, y_pos),
			Vector2(graph_rect.position.x + graph_rect.size.x, y_pos)
		])
	
	# Update vertical grid lines
	var time_step = DISPLAY_TIME_SPAN / 4
	for i in range(5):
		var line = grid_lines.get_child(Y_AXIS_LABELS + 1 + i)
		var x_pos = graph_rect.position.x + (graph_rect.size.x * (1.0 - (i * time_step) / DISPLAY_TIME_SPAN))
		line.points = PackedVector2Array([
			Vector2(x_pos, graph_rect.position.y),
			Vector2(x_pos, graph_rect.position.y + graph_rect.size.y)
		])

func _get_graph_rect() -> Rect2:
	return Rect2(
		Vector2(GRAPH_PADDING * 2, GRAPH_PADDING),
		size - Vector2(GRAPH_PADDING * 3, GRAPH_PADDING * 2)
	)

func _value_to_y(value: float) -> float:
	var graph_rect = _get_graph_rect()
	var normalized_value = (value - min_value) / (max_value - min_value)
	return graph_rect.position.y + (graph_rect.size.y * (1 - normalized_value))

func _draw():
	var graph_rect = _get_graph_rect()
	
	# Draw background and border
	draw_rect(Rect2(Vector2.ZERO, size), Color("2a2a2a50"))
	draw_rect(graph_rect, Color("ffffff10"), false, 1.0)
	
	if buckets.size() > 0:
		var font = ThemeDB.fallback_font
		var font_size = 12
		
		# Draw average label
		var avg_label = "avg: %.1fms" % moving_average
		draw_string(
			font,
			Vector2(graph_rect.position.x + graph_rect.size.x - 40, _value_to_y(moving_average) - 10),
			avg_label,
			HORIZONTAL_ALIGNMENT_RIGHT,
			-1,
			font_size,
			Color("ffff00")
		)
		
		# Draw current value
		var value_text = "%.1fms" % last_value
		draw_string(
			font,
			Vector2(graph_rect.position.x + graph_rect.size.x - 40, graph_rect.position.y + 20),
			value_text,
			HORIZONTAL_ALIGNMENT_RIGHT,
			-1,
			font_size,
			Color("5294e2")
		)
		
		# Draw Y-axis labels
		for i in range(Y_AXIS_LABELS + 1):
			var value = min_value + (max_value - min_value) * (float(i) / Y_AXIS_LABELS)
			var y_pos = graph_rect.position.y + (graph_rect.size.y * (1 - float(i) / Y_AXIS_LABELS))
			draw_string(
				font,
				Vector2(GRAPH_PADDING * 0.5, y_pos + 4),
				"%.1f" % value,
				HORIZONTAL_ALIGNMENT_LEFT,
				-1,
				font_size,
				Color("ffffff")
			)
		
		# Draw X-axis time labels
		var time_step = DISPLAY_TIME_SPAN / 4
		for i in range(5):
			var x_pos = graph_rect.position.x + (graph_rect.size.x * (1.0 - (i * time_step) / DISPLAY_TIME_SPAN))
			var seconds = i * 15
			var label = "now" if seconds == 0 else "-%ds" % seconds
			draw_string(
				font,
				Vector2(x_pos - 10, graph_rect.position.y + graph_rect.size.y + 15),
				label,
				HORIZONTAL_ALIGNMENT_CENTER,
				-1,
				font_size,
				Color("ffffff")
			)

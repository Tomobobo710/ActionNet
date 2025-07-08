# ActionNet

**ActionNet** is a server-authoritative 2D deterministic physics engine and networking framework built for Godot. It provides real-time multiplayer networking with deterministic physics simulation, ensuring consistent gameplay across all clients.

## 🚀 Features

### Core Framework
- **Server-Authoritative Architecture**: Prevents cheating with authoritative game state
- **Deterministic 2D Physics**: Fixed-point arithmetic ensures identical physics across machines
- **Client-Side Prediction**: Smooth gameplay with rollback and reconciliation
- **Flexible Input System**: Supports both Godot actions and raw key codes
- **Auto-Spawn Object System**: Automatic and manual object creation patterns
- **Collision Detection**: Circle-circle, rectangle-rectangle, and circle-rectangle collisions
- **World State Synchronization**: Automatic state distribution to all connected clients
- **Debug UI**: Built-in networking diagnostics and performance monitoring
- **Custom Logic Handlers**: Separate server and client logic systems
- **Lookup Table Optimization**: Precomputed trigonometry for deterministic calculations

### Physics Engine
- **Fixed-Point Arithmetic**: Uses 1000x scaling for sub-pixel precision and determinism
- **Shape Support**: Circles and rectangles with full collision resolution
- **Mass & Velocity**: Realistic physics with mass, velocity, and angular momentum
- **Force Application**: Apply forces, handle collisions, and boundary detection
- **Restitution**: Configurable bounce and damping properties
- **Static Objects**: Immovable collision boundaries for level geometry
- **Impulse-Based Resolution**: Proper collision response with separation handling

### Networking
- **Client-Server Model**: Dedicated server with multiple client support
- **State Prediction**: Client-side prediction with server reconciliation
- **Input Lag Compensation**: Smooth input handling with network delay
- **Connection Management**: Automatic client connection handling
- **Sequence Management**: Frame-perfect synchronization with sequence numbers
- **State Compression**: Efficient world state transmission
- **RTT Monitoring**: Real-time latency measurement and adjustment

## 📦 Installation

1. **Copy the ActionNet addon** to your Godot project:
   ```
   res://addons/ActionNet/
   ```

2. **Enable the plugin** in your Project Settings:
   - Go to `Project > Project Settings > Plugins`
   - Find "ActionNet" and enable it
   - The framework will automatically add the `ActionNetManager` autoload

3. **Optional: Install the demo** for examples:
   ```
   res://addons/ActionNetDemo/
   ```
   Enable the "ActionNetDemo" plugin as well.

## 🏗️ Architecture

### Core Components

#### ActionNetManager (Autoload Singleton)
The central hub that manages all ActionNet functionality:
- Creates and manages server/client instances
- Handles object and input registration
- Provides debug UI access
- Manages world scenes and logic handlers

#### ActionNetPhysObject2D
Base class for all networked physics objects:
```gdscript
extends ActionNetPhysObject2D
class_name MyObject

func _init():
    super._init(Physics.vec2(640, 360))  # Position at screen center
    MASS = 1000
    RESTITUTION = 800  # Bounciness (0-1000)
    shape_type = Physics.ShapeType.CIRCLE
    shape_data = {"radius": BASE_SIZE / 2}
    auto_spawn = true  # Appear automatically in world
```

#### WorldManager
Manages object lifecycle and world state:
- **Auto-Spawning**: Creates objects marked with `auto_spawn = true`
- **Manual Spawning**: Factory methods for dynamic object creation
- **State Tracking**: Captures world snapshots for each frame
- **Prediction System**: Client-side prediction with rollback reconciliation
- **Object Registration**: Registers objects with collision manager

#### CollisionManager
Handles physics collision detection and resolution:
- **Broad-Phase Detection**: Checks all registered object pairs
- **Collision Resolution**: Calls appropriate physics shape handlers
- **Static Object Support**: Proper handling of immovable objects
- **Registration System**: Objects register/unregister for collision detection

#### LogicHandler
Custom game logic extension point:
```gdscript
extends LogicHandler
class_name MyServerLogic

func update():
    # Called every server tick after physics, before network send
    # Access world state via ActionNetManager.server.world_manager
    # Perfect for game rules, scoring, AI, win conditions
    pass
```

### Deterministic Physics System

#### Physics Class
Core physics calculations with fixed-point arithmetic:
- **Coordinate System**: `Physics.vec2(x, y)` converts pixels to physics coordinates
- **Vector Operations**: Fixed-point vector math and rotations
- **Collision Detection**: Shape-agnostic collision checking
- **Force Application**: Deterministic force and impulse calculations

#### Shape-Specific Physics
- **CirclePhysics**: Circle collision detection and resolution
- **RectPhysics**: Rectangle and circle-rectangle collisions
- **PhysicsTables**: Precomputed sin/cos lookup tables for determinism

#### Key Physics Features
```gdscript
# Convert screen coordinates to physics coordinates
var physics_pos = Physics.vec2(640, 360)  # Screen center

# Apply forces to objects
var force = Vector2i(1000 * Physics.SCALE, 0)  # Rightward force
fixed_velocity = Physics.apply_force(fixed_velocity, force, MASS, tick_rate)

# Collision detection between shapes
var collision = Physics.check_collision(
    pos1, shape_type1, shape_data1,
    pos2, shape_type2, shape_data2
)
```

### Framework Workflow

1. **Register Objects**: Define what objects exist in your game
2. **Register Inputs**: Map controls to game actions
3. **Create World Scene**: Define the game world layout
4. **Set Logic Handlers**: Implement game rules and presentation
5. **Start Server/Client**: Launch networking

## 🎮 Quick Start

### Basic Setup

```gdscript
func _ready():
    # Register a physics object
    var ball_scene = create_ball_scene()
    ActionNetManager.register_physics_object("ball", ball_scene)
    
    # Register a client object (player)
    var player_scene = create_player_scene()
    ActionNetManager.register_client_object(player_scene)
    
    # Register inputs
    ActionNetManager.register_key_input("move_up", "pressed", KEY_W)
    ActionNetManager.register_key_input("move_down", "pressed", KEY_S)
    ActionNetManager.register_godot_input("shoot", "just_pressed", "ui_accept")
    
    # Set custom logic
    var server_logic = MyServerLogic.new()
    ActionNetManager.set_server_logic_handler(server_logic)
    
    var client_logic = MyClientLogic.new()
    ActionNetManager.set_client_logic_handler(client_logic)

func create_server():
    ActionNetManager.create_server(9050)

func connect_to_server():
    ActionNetManager.create_client("127.0.0.1", 9050)
```

### Physics Object Example

```gdscript
extends ActionNetPhysObject2D
class_name Ball

func _init():
    super._init(Physics.vec2(640, 360))  # Center position
    
    # Physics properties
    MASS = 500
    RESTITUTION = 800  # Bounciness (0-1000)
    
    # Shape definition
    shape_type = Physics.ShapeType.CIRCLE
    shape_data = {"radius": BASE_SIZE / 2}
    
    # Visual properties
    sprite_texture = load("res://ball_texture.png")
    tint_color = Color.WHITE
    
    # Auto-spawn when world loads
    auto_spawn = true

func update(delta: int):
    # Custom physics behavior
    if not Physics.is_static(MASS):
        # Apply drag
        fixed_velocity = fixed_velocity * 990 / 1000
        
        # Custom boundary behavior
        # ... boundary checking code ...
    
    super.update(delta)  # Call base class update
```

### Input Handling

```gdscript
extends ActionNetPhysObject2D
class_name Player

const THRUST_FORCE = 1000 * Physics.SCALE

func apply_input(input: Dictionary, tick_rate: int):
    # Get input values (automatically handled by ActionNet)
    var move_up = input.get("move_up", false)
    var move_down = input.get("move_down", false)
    var shoot = input.get("shoot", false)
    
    # Apply movement
    if move_up:
        var force = Vector2i(0, -THRUST_FORCE)
        fixed_velocity = Physics.apply_force(fixed_velocity, force, MASS, tick_rate)
    
    if move_down:
        var force = Vector2i(0, THRUST_FORCE)
        fixed_velocity = Physics.apply_force(fixed_velocity, force, MASS, tick_rate)
    
    # Handle shooting
    if shoot:
        perform_shoot()
```

## 📚 Advanced Usage

### Coordinate System

ActionNet uses scaled coordinates for deterministic physics:

```gdscript
# Convert screen coordinates to physics coordinates
var physics_pos = Physics.vec2(640, 360)  # Screen center

# Physics calculations use Vector2i with SCALE factor
const SCALE = 1000  # Built into Physics class
var world_width = 1280 * SCALE   # Full screen width
var world_height = 720 * SCALE   # Full screen height

# Position objects anywhere in the world
var top_left = Physics.vec2(0, 0)
var bottom_right = Physics.vec2(1280, 720)
```

### Custom Logic Handlers

**Server Logic** (Authoritative):
```gdscript
extends LogicHandler
class_name GameServerLogic

var game_score = 0
var game_timer = 0.0
var players_by_team = {"red": [], "blue": []}

func update():
    # Access server world state
    var world_manager = ActionNetManager.server.world_manager
    
    # Update game timer
    game_timer += 1.0 / 60.0
    
    # Check win conditions
    if game_score >= 10:
        handle_game_over()
    
    # Add custom data to world state sent to clients
    ActionNetManager.server.processed_state["game"] = {
        "score": game_score,
        "timer": game_timer,
        "teams": players_by_team
    }
```

**Client Logic** (Presentation):
```gdscript
extends LogicHandler
class_name GameClientLogic

var scoreboard_label: Label
var timer_label: Label

func update():
    # Read server state
    var latest_state = ActionNetManager.client.received_state_manager.latest_state
    if latest_state and latest_state.has("game"):
        var game_data = latest_state["game"]
        
        # Update UI
        scoreboard_label.text = "Score: %d" % game_data.score
        timer_label.text = "Time: %.1f" % game_data.timer
        
        # Handle team colors
        update_player_colors(game_data.teams)
```

### Object Registration Patterns

```gdscript
func register_game_objects():
    # Auto-spawn objects (appear automatically)
    ActionNetManager.register_physics_object("ball", ball_scene)        # auto_spawn = true
    ActionNetManager.register_physics_object("goalpost", goal_scene)    # auto_spawn = true
    
    # Blueprint objects (manual spawning)
    ActionNetManager.register_physics_object("powerup", powerup_scene)  # auto_spawn = false
    ActionNetManager.register_physics_object("bullet", bullet_scene)    # auto_spawn = false

func spawn_powerup_at_position(position: Vector2i):
    # Manual spawning using WorldManager
    if ActionNetManager.server:
        var world_manager = ActionNetManager.server.world_manager
        world_manager.spawn_physics_object("powerup")
        
        # Get the spawned object and set its position
        var powerup = world_manager.physics_objects.get_child(-1)  # Most recent
        powerup.fixed_position = position
```

### Static vs Dynamic Objects

```gdscript
# Dynamic object (moves and collides)
extends ActionNetPhysObject2D
class_name MovingPlatform

func _init():
    super._init(Physics.vec2(640, 360))
    MASS = 2000  # Has mass - can be moved by collisions
    shape_type = Physics.ShapeType.RECTANGLE
    shape_data = {"width": 200 * Physics.SCALE, "height": 50 * Physics.SCALE}

# Static object (collision boundary)
extends ActionNetPhysObject2D
class_name Wall

func _init(wall_position: Vector2i):
    super._init(wall_position)
    MASS = 0  # Static - never moves
    shape_type = Physics.ShapeType.RECTANGLE
    shape_data = {"width": 100 * Physics.SCALE, "height": 400 * Physics.SCALE}
    auto_spawn = true  # Create automatically
```

### Input System Flexibility

```gdscript
func setup_controls():
    # Raw key codes
    ActionNetManager.register_key_input("move_left", "pressed", KEY_A)
    ActionNetManager.register_key_input("move_right", "pressed", KEY_D)
    ActionNetManager.register_key_input("jump", "just_pressed", KEY_SPACE)
    
    # Godot input actions (defined in Input Map)
    ActionNetManager.register_godot_input("shoot", "just_pressed", "fire")
    ActionNetManager.register_godot_input("reload", "just_pressed", "reload")
    
    # Different input types
    ActionNetManager.register_key_input("run", "pressed", KEY_SHIFT)         # Held down
    ActionNetManager.register_key_input("interact", "just_pressed", KEY_E)   # Single press
    ActionNetManager.register_key_input("menu", "just_released", KEY_ESCAPE) # On release
```

## ⚽ Soccer Demo

The **ActionNetDemo** addon provides a complete multiplayer soccer game showcasing ActionNet's capabilities.

### Demo Features
- **Multiplayer Soccer Game**: 2+ players, automatic team assignment, scoring system
- **Real-time Physics**: Ball kicking, player movement, collision detection
- **Game State Management**: Kickoffs, goal celebrations, match timer
- **UI Integration**: Scoreboard, timer, team indicators, goal visuals
- **Server Authority**: Authoritative scoring and game rules
- **Auto-Spawn System**: Demonstrates automatic vs manual object creation

### Demo Controls
- **WASD**: Move player
- **SPACE**: Kick ball
- **ESC**: Return to menu / Quit
- **F11**: Toggle fullscreen

### Running the Demo

1. **Enable both plugins**:
   - ActionNet (framework)
   - ActionNetDemo (demo)

2. **Launch the demo**: The demo autoload will present a connection UI

3. **Start a server**: Click "Create Server" (default port 9050)

4. **Connect clients**: Other instances can "Connect to Server" using the host IP

5. **Play soccer**: Game starts automatically when 2+ players join

### Demo Architecture

The soccer demo demonstrates key ActionNet patterns:

#### Object Registration Strategy
```gdscript
# Auto-spawning objects (created automatically)
ActionNetManager.register_physics_object("ball", ball_scene)        # Always present
ActionNetManager.register_physics_object("goalpost", goal_scene)    # Static world elements

# Blueprint objects (manual spawning available)
ActionNetManager.register_physics_object("box", box_scene)          # Can be spawned dynamically
```

#### Game Logic Separation
- **Server Logic** (`CustomServerLogicHandler`): 
  - Match rules and flow (waiting, kickoff, playing, goal celebration)
  - Team assignment and management
  - Authoritative scoring and goal detection
  - Player positioning for kickoffs
  - Match timer and game state transitions
  
- **Client Logic** (`CustomClientLogicHandler`): 
  - UI creation and updates (scoreboard, timer, status)
  - Visual goal markers and field elements
  - Team color management
  - Game state presentation

#### Soccer Object Examples

**Ball Physics** (`Ball`):
```gdscript
func _init():
    super._init(Physics.vec2(640, 360))  # Center field
    MASS = 4000
    RESTITUTION = 10  # Low bounce
    auto_spawn = true  # Always present
    shape_type = Physics.ShapeType.CIRCLE

func update(delta: int):
    # Custom drag for realistic ball physics
    fixed_velocity = fixed_velocity * 990 / 1000
    super.update(delta)
```

**Player Object** (`Ship`):
```gdscript
func apply_input(input: Dictionary, tick_rate: int):
    # Movement and rotation
    if input.get("move_forward", false):
        var thrust_direction = Physics.rotate_vector(Physics.vec2(1, 0), fixed_rotation)
        var force = Vector2i(thrust_direction.x * THRUST_FORCE, thrust_direction.y * THRUST_FORCE)
        fixed_velocity = Physics.apply_force(fixed_velocity, force, MASS, tick_rate)
    
    # Ball kicking
    if input.get("shoot", false) and kick_cooldown <= 0.0:
        perform_kick()
        kick_cooldown = max_kick_cooldown
```

**Static Goal Posts** (`GoalPost`):
```gdscript
func _init(goal_position: Vector2i):
    super._init(goal_position)  # Position set by game logic
    MASS = 0  # Static - never moves
    auto_spawn = true  # Created automatically
    shape_type = Physics.ShapeType.RECTANGLE
```

#### Team Management
The server automatically assigns teams:
- **Blue Team**: Right side of field (cyan color)
- **Red Team**: Left side of field (red color)
- **Auto-assignment**: Alternates between teams as players join
- **Dynamic Colors**: Server logic sets player colors based on team

#### Scoring System
- **Goal Detection**: Server checks ball position against invisible goal areas
- **Score Tracking**: Server maintains authoritative score state
- **Celebrations**: 3-second goal celebration before kickoff reset
- **Match Timer**: 5-minute matches with automatic game reset

### Key Demo Files

- `main.gd`: Demo setup, object registration, and world creation
- `server_logic.gd`: Authoritative game rules, scoring, and team management
- `client_logic.gd`: UI presentation, visual effects, and goal markers
- `ship_deterministic.gd`: Player object with movement and ball kicking
- `ball_deterministic.gd`: Soccer ball with realistic physics
- `goalpost_deterministic.gd`: Static collision boundaries for scoring

## 🔧 Debugging

ActionNet includes comprehensive debugging tools:

### Debug UI
The framework automatically creates a debug interface showing:
- **Connection Status**: Server/client state and peer information
- **Network Statistics**: RTT, packet loss, bandwidth usage
- **Performance Metrics**: Frame rate, tick rate, simulation time
- **Object Counts**: Active physics and client objects
- **RTT Graph**: Visual representation of network latency over time
- **Sequence Information**: Current sequence numbers and offsets

### Error Handling
Common error scenarios are handled gracefully:
- **Connection Failures**: Automatic error popups with retry options
- **Server Disconnection**: Clean state reset and menu return
- **Invalid Object Registration**: Console warnings with suggested fixes
- **Prediction Misses**: Automatic rollback and reconciliation
- **Port Conflicts**: Clear error messages for server creation issues

### Console Output
Detailed logging for development:
```
[ActionNetManager] Created default world scene.
[SoccerDemo] Soccer objects registered:
  - ball (auto_spawn=true): Appears at center
  - box (auto_spawn=false): Blueprint for manual spawning
[ActionNetServer] Server created on port 9050
[SoccerGame] Player 1 joined the game
[SoccerGame] Player 1 assigned to team BLUE
[WorldManager] Prediction missed! For sequence 123
[WorldManager] Reprediction complete. Total process took 2ms
```

### Performance Monitoring
Built-in performance tracking:
- **Physics Simulation Time**: Per-frame physics execution duration
- **Network Processing Time**: Time spent on networking operations
- **Reprediction Costs**: Rollback simulation performance impact
- **Memory Usage**: Object count and state storage metrics

## 🤝 Contributing

ActionNet is designed to be extensible. Common extension points:

- **Custom Physics Shapes**: Extend the `Physics` class for new collision shapes
- **Additional Input Types**: Expand `InputDefinition` for new input methods
- **Network Optimizations**: Customize `ActionNetClient`/`ActionNetServer` for specific needs
- **UI Enhancements**: Extend `ActionNetDebugUI` for additional diagnostic tools
- **Collision Algorithms**: Implement new collision detection methods in shape classes

### Extending Physics Shapes
```gdscript
# Add to Physics class
enum ShapeType {
    CIRCLE,
    RECTANGLE,
    POLYGON  # New shape type
}

# Implement in new PolygonPhysics class
class_name PolygonPhysics

static func check_collision(pos1: Vector2i, vertices1: Array, pos2: Vector2i, vertices2: Array) -> bool:
    # Implement SAT collision detection
    pass
```

### Custom Input Sources
```gdscript
# Extend InputDefinition for new input types
func get_input_value() -> bool:
    match input_source:
        "gamepad":
            return handle_gamepad_input()
        "mouse":
            return handle_mouse_input()
        _:
            return super.get_input_value()
```

## 📄 License

ActionNet is provided as-is for educational and development purposes. See the individual files for specific licensing information.

## 🎮 Getting Started

1. **Try the Demo**: Enable both plugins and run the soccer demo to see ActionNet in action
2. **Read the Code**: Examine the demo implementation for real-world usage patterns
3. **Build Your Game**: Use ActionNet's object registration and logic handler systems
4. **Join the Community**: Share your ActionNet creations and improvements

ActionNet provides the foundation for building robust, cheat-resistant multiplayer games in Godot. The comprehensive physics system, client-side prediction, and server authority ensure smooth gameplay while maintaining competitive integrity. The soccer demo showcases real-world usage patterns and serves as a complete reference implementation.

---

**Happy Networking! ⚽🎮**
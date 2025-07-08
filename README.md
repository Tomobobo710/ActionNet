# ActionNetGD

**ActionNet** is a server-authoritative 2D deterministic physics engine and networking framework built for Godot written in GDScript. It provides a complete multiplayer solution with client-side prediction, deterministic physics simulation, debugging tools and a game-ready network connection UI.

![image](https://github.com/user-attachments/assets/f43c2d1e-96be-4c8b-8e69-c42daf48b27f)

![image](https://github.com/user-attachments/assets/e269b174-c0d6-4437-83ef-7e3625e46eae)

![image](https://github.com/user-attachments/assets/82832c3b-80e4-440f-a974-269091bd6a7c)

## 🚀 Framework Overview

ActionNet delivers a comprehensive multiplayer framework consisting of four integrated systems:

- **Deterministic Physics Engine**: Fixed-point 2D physics with circle/rectangle collision detection
- **Server-Authoritative Networking**: Client prediction with rollback reconciliation
- **Complete UI Solution**: Ready-to-use connection interface and debug visualization
- **Production Tools**: Performance monitoring, state visualization, and diagnostic systems

## 📦 Installation

1. **Copy the ActionNet addon** to your Godot project:
   ```
   res://addons/ActionNet/
   ```

2. **Enable the plugin** in Project Settings → Plugins → "ActionNet"
   - Automatically adds `ActionNetManager` autoload singleton

3. **Optional: Install demo** for implementation examples:
   ```
   res://addons/ActionNetDemo/
   ```

## 🏗️ Framework Architecture

### Core Management Layer

**ActionNetManager (Autoload Singleton)**
- Central coordination hub for all framework systems
- Manages server/client instance lifecycle
- Handles object registration and input mapping
- Provides unified access to debug tools and world management
- Orchestrates logic handler injection points

**WorldManager**
- Object lifecycle management (auto-spawn vs manual creation)
- World state capture and restoration for rollback prediction
- Client-side prediction with server reconciliation
- Object registration with collision and networking systems
- State comparison and mismatch detection for prediction correction

**CollisionManager**
- Broad-phase collision detection between all registered objects
- Integration with shape-specific physics resolution algorithms
- Static vs dynamic object handling
- Registration/unregistration system for object lifecycle

### Physics Engine

**Deterministic Fixed-Point System**
- All calculations use integer arithmetic with 1000x scaling factor
- Guarantees identical results across all machines and platforms
- Sub-pixel precision for smooth visual movement
- Coordinate system: `Physics.vec2(640, 360)` = screen center for 1280x720

**Shape-Based Collision Detection**
- **CirclePhysics**: Circle-circle collision with radius-based detection
- **RectPhysics**: Rectangle-rectangle and circle-rectangle collision algorithms
- **Impulse-Based Resolution**: Proper collision response with separation handling
- **Static Object Support**: Immovable boundaries with correct collision response

**Physics Optimization Systems**
- **PhysicsTables**: Precomputed sin/cos lookup tables for deterministic trigonometry
- **Force Application**: Deterministic force and impulse calculations
- **Boundary Handling**: World edge collision with configurable restitution
- **Angular Physics**: Rotation and angular velocity with drag simulation

**ActionNetPhysObject2D Base Class**
- Unified interface for all networked physics objects
- Fixed-point position, velocity, and rotation storage
- Shape definition system (circle/rectangle with size data)
- Visual synchronization between physics state and Godot rendering
- Auto-spawn flag for automatic vs manual object creation

### Networking Architecture

**Client-Server Model**
- **ActionNetServer**: Authoritative physics and world state simulation with client management
- **ActionNetClient**: Local prediction with server reconciliation
- **Dedicated vs Hosted**: Support for both dedicated servers and host-client configurations

**Advanced Prediction System**
- **ClientSequenceAdjuster**: Adaptive frame-ahead calculation based on RTT
- **Dynamic Buffer Management**: Automatically adjusts prediction buffer size
- **Sequence Synchronization**: Frame-perfect timing with sequence number tracking
- **Rollback Reconciliation**: Re-simulation when client predictions diverge from server authority

**Connection Management**
- **ClientConnectionManager**: Multi-stage handshake with RTT measurement
- **Formal Handshake Process**: Ping measurement, object spawn confirmation, sync establishment
- **RTT-Based Adaptation**: Continuous adjustment of prediction parameters
- **Connection State Tracking**: Comprehensive monitoring of network health

**Input Processing System**
- **InputRegistry**: 5-second rolling buffer of sequenced input data
- **Input Definition System**: Flexible mapping of Godot actions and raw key codes
- **Sequence-Based Retrieval**: Exact and fallback input lookup for rollback simulation
- **Client/Server Separation**: Independent input storage for prediction and authority

**State Management**
- **WorldStateRegistry**: Rolling buffer of world snapshots for rollback
- **ReceivedStateManager**: Separate "ghost" world mirroring server authority
- **State Comparison**: Automated detection of prediction mismatches
- **Dual World Simulation**: Client maintains both predicted and authoritative world states

**Transport Layer Integration**
- **ENet Foundation**: Built on Godot's ENetMultiplayerPeer for reliable UDP networking
- **MultiplayerAPI Integration**: Leverages Godot's built-in networking with custom RPC patterns
- **Cross-Platform Compatibility**: ENet provides consistent networking across all Godot platforms
- **Connection Management**: ENet handles low-level connection establishment, timeouts, and cleanup

**RPC Communication Patterns**
- **`receive_world_state`**: Unreliable, authority-to-clients broadcast of complete world snapshots
- **`receive_input`**: Unreliable, client-to-server input commands with sequence numbers
- **`request_spawn`**: Reliable, client-to-server object creation requests
- **`receive_ping/receive_pong`**: Unreliable, bidirectional RTT measurement system
- **Authority Configuration**: Server marked as authority, clients as peers for proper RPC routing

**Network Protocol Design**
- **Unreliable State Updates**: High-frequency world state synchronization (60Hz)
- **Reliable Commands**: Spawn requests and critical game events use guaranteed delivery
- **Sequence Numbering**: Frame-perfect synchronization across all clients
- **RTT Measurement**: Continuous latency monitoring with ping/pong RPC system
- **Multiplayer Peer Management**: ENet handles client connections, disconnections, and peer identification

### Logic Handler System

**Extensible Game Logic Architecture**
- **LogicHandler Base Class**: Standardized injection point for custom game logic
- **Timing Guarantees**: Server logic runs after physics/before network send
- **Client Logic**: Executes after network processing/before rendering
- **Authority Separation**: Server handles rules, client handles presentation

**Custom Game Integration**
- Server logic handlers access authoritative world state
- Client logic handlers receive latest server state for UI updates
- Clean separation between game rules and presentation layer
- Framework-managed execution timing for optimal networking

## 🎮 User Interface Systems

### Connection Management UI

**ActionNetManagerUI**
- **Complete Connection Interface**: Ready-to-use multiplayer lobby
- **Hosting Options**: Host game, join game, or create dedicated server
- **Smart Connectivity**: Hostname resolution, IP validation, port configuration
- **Error Handling**: User-friendly connection failure messages
- **Workflow Management**: Seamless transition from menu to gameplay

### Professional Debug Tools

**ActionNetDebugUI (F9 Toggle)**
- **Real-Time Network Statistics**: RTT, packet loss, bandwidth monitoring
- **Sequence Synchronization Display**: Frame-ahead calculation, adjustment events
- **Connection State Monitoring**: Handshake progress, client management
- **Performance Metrics**: Physics timing, collision counts, memory usage
- **Input System Status**: Registry contents, sequence mapping, buffer states

**RTTGraphControl**
- **Visual RTT Tracking**: Real-time latency graphing with moving averages
- **Adaptive Y-Axis Scaling**: Automatic range adjustment based on network conditions
- **Bucket-Based Sampling**: Efficient storage of historical network data
- **Performance Indicators**: Visual baseline, current value, and trend analysis

### Debug Visualization

**Dual World Rendering**
- **Client Prediction Visualization**: See predicted vs authoritative object states
- **Ghost Object System**: Visual representation of server authority
- **Prediction Mismatch Highlighting**: Automatic rollback event visualization
- **Toggleable Overlays**: Show/hide debug objects without affecting gameplay

## 🔧 Core Utilities

**ActionNetClock**
- **Deterministic Timing**: Configurable tick rate with millisecond precision
- **Sequence Generation**: Frame-perfect numbering for synchronization
- **Timer Management**: Centralized timing for all framework systems

**Input Definition System**
- **Flexible Input Mapping**: Support for Godot actions and raw key codes
- **Input Type Handling**: pressed, just_pressed, just_released states
- **Runtime Registration**: Dynamic input system configuration

**Object Registration Framework**
- **Scene-Based Factory System**: PackedScene registration for network object creation
- **Auto-Spawn vs Blueprint Patterns**: Automatic world population vs manual spawning
- **Type-Safe Object Creation**: Centralized object instantiation with proper networking setup

## ⚽ Demonstration Implementation

The **ActionNetDemo** addon provides a complete multiplayer soccer game showcasing framework capabilities:

### Architecture Demonstration
- **Server Authority**: Game state management, team assignment, scoring system
- **Client Presentation**: UI updates, visual effects, input handling
- **Object Patterns**: Auto-spawning ball/goals, manual box spawning, player management
- **Logic Separation**: Server rules vs client presentation in separate handler classes

### Real-World Features
- **Dynamic Team Assignment**: Automatic player team balancing
- **Game State Management**: Match phases, kickoffs, goal celebrations
- **Physics Integration**: Ball kicking, collision-based scoring, boundary handling
- **UI Integration**: Scoreboard, timer, team indicators, connection management

### Learning Resource
The demo serves as a comprehensive reference implementation showing:
- Proper object registration patterns
- Server/client logic separation
- Input system configuration
- Custom physics object implementation
- Network lifecycle management

## 🔬 Technical Specifications

### Performance Characteristics
- **Tick Rate**: 60Hz default (configurable)
- **Input Buffer**: 5-second rolling window (300 frames at 60Hz)
- **State History**: 2-second rollback capability (120 world snapshots)
- **RTT Adaptation**: Dynamic prediction buffer (1-60 frames based on latency)

### Platform Compatibility
- **Deterministic Across Platforms**: Fixed-point arithmetic ensures consistency
- **Cross-Platform Networking**: Godot's ENet integration
- **Resolution Independent**: Scalable coordinate system

### Memory Management
- **Efficient State Storage**: Circular buffers for input and world state history
- **Object Pooling**: Reusable physics object instances
- **Automatic Cleanup**: Connection-based resource management

## 🎯 Framework Capabilities

ActionNet provides a **complete multiplayer solution** rather than just networking primitives:

✅ **Drop-in Multiplayer**: Add ActionNet and immediately have working multiplayer menus
✅ **Production-Ready Networking**: Advanced prediction with professional debugging tools
✅ **Deterministic Physics**: Cheat-resistant, consistent physics across all clients
✅ **Professional UI**: Complete connection interface with error handling
✅ **Extensible Architecture**: Clean injection points for custom game logic
✅ **Performance Monitoring**: Built-in tools for optimization and diagnostics

ActionNet transforms multiplayer development from "networking library + months of infrastructure work" into "enable plugin + implement game logic". The framework handles the complex networking, physics, and UI systems while providing clean extension points for game-specific functionality.

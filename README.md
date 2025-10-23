# MSX Stealth Game Skeleton

A complete stealth game prototype built in Godot 4.4+. Features player movement, enemy AI with patrol/alert/investigation states, vision cones, noise detection, traps, and win conditions. Perfect foundation for building stealth-based games.

## 🚀 Quick Start

1. **Open the project** in Godot 4.4 or later
2. **Open the main scene**: `scenes/level_1.tscn` 
3. **Press F5** or click the Play button
4. **Move with WASD**, **sneak with C**
5. **Avoid guards** and reach the green **Win Area** to complete the level

## 🎮 Controls

- **WASD** - Move player
- **C** - Toggle sneak mode (uses stamina)

## 🎯 Variables Map

### Player (`src/player/player.gd`)
- `player_speed` - Normal walking speed
- `sneak_speed` - Sneaking movement speed
- `MAX_STAMINA` - Maximum stamina capacity
- `STAMINA_DRAIN_RATE` - How fast stamina depletes while sneaking
- `STAMINA_REGEN_RATE` - Passive stamina recovery rate


### Guards (`src/enemy/guard.gd`)
- `enemy_speed` - Guard movement speed during alert/chase
- `view_angle` - Vision cone angle in degrees (90° default)
- `view_distance` - How far guards can see (75 units default)
- `alert_time` - Duration of alert state before aggressive behavior
- `min_patrol_speed` / `max_patrol_speed` - Patrol speed range
- `bullet_speed` - Speed of guard bullets
- `scan_rotation_speed` - How fast guards turn during scanning

### Win Condition (`src/props/WinArea.gd`)
- `win_message` - Text displayed on win screen
- `restart_delay` - Seconds to wait before restarting
- `next_level_scene` - Path to next level (for progression systems)

### Traps (`src/traps/SpikeTrap.gd`)
- `spike_frames` - Total animation frames for spike trap
- `activation_delay` - Time before spikes activate after triggering
- `retraction_delay` - Time spikes stay extended

### Trap Groups (`src/traps/TrapGroup.gd`)
- `trap_pattern` - Coordination pattern (Sequential, Alternating, Random, Synchronized)
- `pattern_delay` - Delay between trap activations in group
- `sync_offset` - Time offset for this group vs others

### Projectiles (`src/projectiles/SimpleBullet.gd`)
- `speed` - Bullet travel speed (225.0 - faster than guards to prevent collision issues)
- `lifetime` - Seconds before bullet auto-removes (3.0 default)

### Environmental Zones (`NoisyArea.gd`)
- `noise_multiplier` - How much louder footsteps are in this area (2.0 default)

## 🎨 How to Swap Art

### Player & Enemy Sprites
1. Replace `assets/sprites/player.png` with your player sprite
2. Replace `assets/sprites/enemy.png` with your guard sprite
3. Both sprites are scaled to 0.6 for consistency - adjust in scene files if needed

### Environment Assets
- **Tiles**: Replace files in `assets/tiles/` 
- **Props**: Snow crates in `assets/sprites/` can be replaced with your own props
- **UI Icons**: Guard state icons in `assets/sprites/icons/`

### Sprite Requirements
- **Static images only** - no animation sheets needed
- **PNG format** recommended
- **Power-of-2 sizes** work best (32x32, 64x64, etc.)
- Import settings will auto-generate on replacement

### Tilemap Setup
- Main tilemap uses `assets/tiles/tilesheet.png`
- Collision and navigation are set up automatically
- Modify TileMap node in `level_1.tscn` to adjust level layout

## 🏗️ Architecture Overview

### Core Systems
- **Player Controller** - Movement, stamina, noise generation with terrain modifiers
- **Guard AI** - Patrol → Alert → Investigate → Scanning state machine with shooting
- **Vision System** - Cone-based line-of-sight with raycasting and alert icons
- **Noise System** - Footstep detection with environmental sound zones
- **Trap System** - Animated spike traps with coordinated group patterns
- **Projectile System** - Guard bullets with physics simulation and auto-cleanup
- **Win Condition** - Area2D trigger with overlay UI and scene progression hooks

### Scene Structure
```
scenes/level_1.tscn          # Main game scene
├── Player                   # Player character (src/player/player.tscn)
├── Guards                   # Enemy guards (src/enemy/guard.tscn)
├── PatrolPoints            # Guard waypoint nodes
├── Traps                   # Spike traps (src/traps/SpikeTrap.tscn)
│   └── TrapGroups          # Coordinated trap timing (src/traps/TrapGroup.gd)
├── Props                   # Environment objects and snow crates
├── NoisyAreas              # Environmental sound zones (NoisyArea.gd)
├── WinArea                 # Victory condition (src/props/WinArea.tscn)
└── StaminaUI              # UI overlay (src/ui/StaminaUI.tscn)
```

### Extension Points
- **Next Level Progression** - Set `next_level_scene` in WinArea
- **Additional Guard Types** - Extend guard.gd base class
- **New Trap Types** - Follow SpikeTrap pattern or create TrapGroup coordination
- **Environmental Zones** - Use NoisyArea pattern for different surface effects
- **Projectile Weapons** - Extend SimpleBullet for different ammunition types
- **Custom Win Conditions** - Modify WinArea.gd trigger logic
- **Advanced AI** - All scripts include comprehensive headers for AI expansion context

## 📝 License

MIT License

Copyright (c) 2025 Obscura Tempura Studios

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

## 🤝 Consulting & Support

**Need custom systems or help adapting this skeleton?** We offer one-on-one consulting and commissions. Reach out through our Carrd site → https://obscuratempurastudios.carrd.co/

**This is one of several game skeletons we've released.** Browse the full collection on our Itch profile and start building faster → https://obscura-tempura-studios.itch.io/

---

### 🔧 Technical Notes
- Built with **Godot 4.4.1**
- Uses **Forward+ renderer**
- All sprites are **static images** (no animation system)
- **NavigationAgent2D** for guard pathfinding
- **Area2D collision detection** for interactions
- **Modular scene architecture** for easy customization
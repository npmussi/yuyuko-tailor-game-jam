# GameManager Autoload Setup Instructions

To enable the fade transitions and game over system, you need to add GameManager as an autoload:

## Setup Steps:

1. **In Godot Editor:**
   - Go to `Project` → `Project Settings`
   - Click on the `Autoload` tab
   - Set the following:
     - **Path**: `res://src/managers/GameManager.gd`
     - **Node Name**: `GameManager`
     - **Enable**: ✓ (checked)
   - Click `Add`

2. **Verify Setup:**
   - The GameManager will now be available as `/root/GameManager` in all scenes
   - Fade transitions will work automatically on game start and restart
   - Game over system will use smooth fade transitions

## Alternative Quick Setup (if autoload isn't working):

If you prefer not to use autoload, you can add GameManager directly to your main scene:

1. In your main game scene, add a new Node and rename it to "GameManager"
2. Attach the `GameManager.gd` script to this node
3. The fade system will work within that scene

## Fade Behavior:
- **Game Start**: Automatic fade-in (1 second)
- **Game Over**: Fade-out (0.5 seconds) → brief pause → restart with fade-in
- **Restart Buffer**: Total transition time is about 2 seconds for smooth experience

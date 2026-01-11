# Roblox Top-Down Camera System

A Hotline Miami-style top-down camera system for Roblox Studio with orthographic perspective, cursor-based character rotation, and edge nudging.

## Features

- **Orthographic Top-Down View**: Camera positioned directly above the player with minimal perspective distortion
- **Cursor-Based Character Rotation**: Character automatically faces the direction of the mouse cursor
- **Edge Nudging**: Camera smoothly shifts when cursor approaches screen edges (10% extra viewing area)
- **Smooth Transitions**: All camera movements and character rotations are smoothly interpolated

## Installation

### Method 1: LocalScript in StarterPlayer

1. Open your Roblox Studio project
2. Navigate to `StarterPlayer` → `StarterCharacterScripts`
3. Insert a new `LocalScript`
4. Copy the contents of `TopDownCameraSystem.lua` into the LocalScript
5. Rename the script to "TopDownCamera" (optional)
6. Test your game!

### Method 2: LocalScript in StarterPlayerScripts

1. Navigate to `StarterPlayer` → `StarterPlayerScripts`
2. Insert a new `LocalScript`
3. Copy the contents of `TopDownCameraSystem.lua` into the LocalScript
4. The script will handle character loading automatically

## Configuration

You can customize the camera behavior by modifying these values at the top of the script:

```lua
local CAMERA_HEIGHT = 50              -- Height above the player (higher = more zoomed out)
local CAMERA_FOV = 70                 -- Field of view (lower = more orthographic, try 30-70)
local NUDGE_PERCENTAGE = 0.10         -- 10% extra viewing area at edges
local NUDGE_SMOOTHNESS = 0.15         -- Camera nudge smoothness (0.1 = smooth, 0.3 = snappy)
local CHARACTER_ROTATION_SPEED = 0.2  -- Character rotation speed (0.1 = slow, 0.5 = fast)
```

### Recommended Settings for Different Feels

**More Orthographic (Hotline Miami style)**:
```lua
local CAMERA_HEIGHT = 40
local CAMERA_FOV = 50
```

**Wider View**:
```lua
local CAMERA_HEIGHT = 70
local CAMERA_FOV = 80
```

**Closer/More Intimate**:
```lua
local CAMERA_HEIGHT = 30
local CAMERA_FOV = 60
```

## How It Works

### Camera System
- The camera is locked in `Scriptable` mode to override default controls
- Position is calculated to be directly above the player's `HumanoidRootPart`
- Lower FOV creates a more orthographic (parallel projection) feel
- Edge nudging detects cursor position and smoothly offsets the camera

### Character Rotation
- Uses raycasting from the camera through the cursor to find world position
- Projects the intersection onto the horizontal plane at character height
- Smoothly rotates the `HumanoidRootPart` to face that position
- Ignores Y-axis to keep character upright

### Edge Nudging
- Monitors cursor position relative to screen edges
- Begins nudging when cursor is 70% towards any edge
- Smoothly interpolates offset up to 10% of camera height
- Creates extra viewing area without jarring movements

## Troubleshooting

### Camera doesn't move
- Ensure the script is a `LocalScript` (not a regular Script)
- Check that it's in `StarterCharacterScripts` or `StarterPlayerScripts`
- Verify no other scripts are controlling the camera

### Character doesn't rotate properly
- Make sure the character has a `HumanoidRootPart`
- Check that other scripts aren't controlling character rotation
- Try increasing `CHARACTER_ROTATION_SPEED` for more responsive rotation

### Camera is too close/far
- Adjust `CAMERA_HEIGHT` value
- Adjust `CAMERA_FOV` for zoom level

### Camera feels too orthographic (not perspective enough)
- Increase `CAMERA_FOV` to 80-90
- This adds more perspective distortion

### Nudging is too sensitive/not sensitive enough
- Modify the `edgeThreshold` value in the `calculateNudgeOffset()` function
- Lower value = starts nudging sooner (default: 0.7)
- Adjust `NUDGE_PERCENTAGE` to change maximum nudge distance

## Advanced Customization

### Making it More Orthographic

For a truly orthographic look, you need to modify the camera's projection matrix, which isn't directly accessible in Roblox. However, you can simulate it very closely:

1. Set FOV to minimum (lower values like 30-40)
2. Increase camera height significantly (80-100)
3. This creates very minimal perspective distortion

### Adding Obstacles/Collision

The current implementation doesn't handle camera collision. To add this:

```lua
-- Add raycast from camera to character
local raycastParams = RaycastParams.new()
raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
raycastParams.FilterDescendantsInstances = {character}

local rayResult = Workspace:Raycast(cameraPosition, characterPosition - cameraPosition, raycastParams)
if rayResult then
	-- Adjust camera position to avoid obstacle
end
```

### Multiple Camera Heights

You can add key bindings to change camera height:

```lua
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end

	if input.KeyCode == Enum.KeyCode.Q then
		CAMERA_HEIGHT = math.max(20, CAMERA_HEIGHT - 5)
	elseif input.KeyCode == Enum.KeyCode.E then
		CAMERA_HEIGHT = math.min(100, CAMERA_HEIGHT + 5)
	end
end)
```

## Performance

This script is optimized for performance:
- Uses `RenderStepped` for smooth camera updates
- Minimal calculations per frame
- No unnecessary object creation
- Should work well even with many players

## License

Free to use and modify for your Roblox projects!

## Credits

Created for top-down gameplay similar to Hotline Miami's camera system.

--[[
	Top-Down Camera System for Roblox Studio
	Similar to Hotline Miami's camera perspective

	Features:
	- Orthographic top-down view from directly above player
	- Character faces cursor position on screen
	- Camera nudging at screen edges (10% extra viewing area)
	- Character-relative movement (WASD moves in direction character faces)

	Instructions:
	Place this script in StarterPlayer > StarterCharacterScripts
	or StarterPlayer > StarterPlayerScripts (modify accordingly)
--]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera
local mouse = player:GetMouse()

-- Configuration
local CAMERA_HEIGHT = 50 -- Height above the player
local CAMERA_FOV = 70 -- Field of view (lower = more orthographic feel)
local NUDGE_PERCENTAGE = 0.10 -- 10% extra viewing area
local NUDGE_SMOOTHNESS = 0.15 -- How smoothly the camera nudges
local CHARACTER_ROTATION_SPEED = 0.2 -- How fast character rotates to face cursor
local MOVEMENT_SPEED = 16 -- Character movement speed

-- Camera nudge offset
local currentNudgeOffset = Vector2.new(0, 0)
local targetNudgeOffset = Vector2.new(0, 0)

-- Movement input tracking
local moveVector = Vector3.new(0, 0, 0)

-- Wait for character to load
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
local rootPart = character:WaitForChild("HumanoidRootPart")

-- Set camera mode
camera.CameraType = Enum.CameraType.Scriptable
camera.FieldOfView = CAMERA_FOV

-- Function to calculate nudge offset based on mouse position
local function calculateNudgeOffset()
	local viewportSize = camera.ViewportSize
	local mousePosition = UserInputService:GetMouseLocation()

	-- Calculate normalized position from edges (0 at center, 1 at edge)
	local normalizedX = (mousePosition.X / viewportSize.X) * 2 - 1
	local normalizedY = (mousePosition.Y / viewportSize.Y) * 2 - 1

	-- Edge detection - only nudge when near edges
	local edgeThreshold = 0.7 -- Start nudging when cursor is 70% towards edge
	local maxNudgeDistance = NUDGE_PERCENTAGE * CAMERA_HEIGHT

	local nudgeX = 0
	local nudgeY = 0

	-- Calculate nudge strength based on distance from threshold
	if math.abs(normalizedX) > edgeThreshold then
		local strength = (math.abs(normalizedX) - edgeThreshold) / (1 - edgeThreshold)
		nudgeX = math.sign(normalizedX) * strength * maxNudgeDistance
	end

	if math.abs(normalizedY) > edgeThreshold then
		local strength = (math.abs(normalizedY) - edgeThreshold) / (1 - edgeThreshold)
		nudgeY = math.sign(normalizedY) * strength * maxNudgeDistance
	end

	return Vector2.new(nudgeX, nudgeY)
end

-- Function to get world position of mouse cursor on the ground plane
local function getMouseWorldPosition()
	local mouseRay = camera:ScreenPointToRay(mouse.X, mouse.Y)
	local rayOrigin = mouseRay.Origin
	local rayDirection = mouseRay.Direction

	-- Calculate intersection with the horizontal plane at character's Y position
	local characterY = rootPart.Position.Y
	local t = (characterY - rayOrigin.Y) / rayDirection.Y

	if t > 0 then
		local hitPosition = rayOrigin + rayDirection * t
		return Vector3.new(hitPosition.X, characterY, hitPosition.Z)
	end

	return rootPart.Position
end

-- Function to rotate character to face a position
local function facePosition(position)
	if not rootPart or not rootPart.Parent then return end

	local currentPosition = rootPart.Position
	local direction = (position - currentPosition) * Vector3.new(1, 0, 1) -- Ignore Y axis

	if direction.Magnitude > 0.1 then
		local targetCFrame = CFrame.new(currentPosition, currentPosition + direction)
		-- Smooth rotation
		rootPart.CFrame = rootPart.CFrame:Lerp(targetCFrame, CHARACTER_ROTATION_SPEED)
	end
end

-- Update movement input
local function updateMovementInput()
	local inputVector = Vector3.new(0, 0, 0)

	-- Check WASD keys
	if UserInputService:IsKeyDown(Enum.KeyCode.W) then
		inputVector = inputVector + Vector3.new(0, 0, -1)
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.S) then
		inputVector = inputVector + Vector3.new(0, 0, 1)
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.A) then
		inputVector = inputVector + Vector3.new(-1, 0, 0)
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.D) then
		inputVector = inputVector + Vector3.new(1, 0, 0)
	end

	-- Normalize diagonal movement
	if inputVector.Magnitude > 0 then
		inputVector = inputVector.Unit
	end

	moveVector = inputVector
end

-- Apply character-relative movement
local function applyMovement()
	if not humanoid or not rootPart or not rootPart.Parent then return end

	-- Calculate movement direction relative to character's facing direction
	local characterLookVector = rootPart.CFrame.LookVector
	local characterRightVector = rootPart.CFrame.RightVector

	-- Transform input from local space to world space
	local worldMoveDirection = (characterLookVector * moveVector.Z) + (characterRightVector * moveVector.X)
	worldMoveDirection = Vector3.new(worldMoveDirection.X, 0, worldMoveDirection.Z) -- Keep on horizontal plane

	-- Set the humanoid's move direction
	if worldMoveDirection.Magnitude > 0 then
		humanoid:Move(worldMoveDirection * MOVEMENT_SPEED)
	end
end

-- Main camera and movement update loop
local function updateCamera()
	if not character or not character.Parent then
		character = player.Character
		if character then
			humanoid = character:WaitForChild("Humanoid")
			rootPart = character:WaitForChild("HumanoidRootPart")
		end
		return
	end

	if not rootPart or not rootPart.Parent then return end

	-- Update movement input and apply character-relative movement
	updateMovementInput()
	applyMovement()

	-- Calculate target nudge offset
	targetNudgeOffset = calculateNudgeOffset()

	-- Smoothly interpolate current nudge offset
	currentNudgeOffset = currentNudgeOffset:Lerp(targetNudgeOffset, NUDGE_SMOOTHNESS)

	-- Calculate camera position with nudge offset
	local characterPosition = rootPart.Position
	local nudgeOffset3D = Vector3.new(currentNudgeOffset.X, 0, currentNudgeOffset.Y)

	local cameraPosition = Vector3.new(
		characterPosition.X + nudgeOffset3D.X,
		characterPosition.Y + CAMERA_HEIGHT,
		characterPosition.Z + nudgeOffset3D.Z
	)

	-- Point camera straight down at the offset position (maintains straight-down angle)
	local lookAtPosition = characterPosition + nudgeOffset3D
	camera.CFrame = CFrame.new(cameraPosition, lookAtPosition)

	-- Make character face cursor position
	local mouseWorldPos = getMouseWorldPosition()
	facePosition(mouseWorldPos)
end

-- Disable default camera controls
local function disablePlayerControls()
	-- Lock the default camera
	player.CameraMode = Enum.CameraMode.LockFirstPerson
	player.CameraMaxZoomDistance = 0
	player.CameraMinZoomDistance = 0
end

-- Handle character respawn
player.CharacterAdded:Connect(function(newCharacter)
	character = newCharacter
	humanoid = character:WaitForChild("Humanoid")
	rootPart = character:WaitForChild("HumanoidRootPart")

	-- Reset camera
	camera.CameraType = Enum.CameraType.Scriptable
	camera.FieldOfView = CAMERA_FOV

	-- Reset nudge offset and movement
	currentNudgeOffset = Vector2.new(0, 0)
	targetNudgeOffset = Vector2.new(0, 0)
	moveVector = Vector3.new(0, 0, 0)
end)

-- Initialize
disablePlayerControls()

-- Connect update loop
RunService.RenderStepped:Connect(updateCamera)

print("Top-Down Camera System loaded successfully!")
print("Features: Top-down camera, cursor-based rotation, character-relative movement (WASD)")

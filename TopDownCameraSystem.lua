--[[
	Top-Down Camera System for Roblox Studio
	Similar to Hotline Miami's camera perspective

	Features:
	- Orthographic top-down view from directly above player
	- Character faces cursor position on screen
	- Camera nudging at screen edges (10% extra viewing area)

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

-- Camera nudge offset
local currentNudgeOffset = Vector2.new(0, 0)
local targetNudgeOffset = Vector2.new(0, 0)

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

	-- Calculate normalized position from center (-1 to 1)
	local normalizedX = (mousePosition.X / viewportSize.X) * 2 - 1
	local normalizedY = (mousePosition.Y / viewportSize.Y) * 2 - 1

	-- Apply edge detection with smooth falloff
	local edgeThreshold = 0.7 -- Start nudging when mouse is 70% to edge

	local nudgeX = 0
	local nudgeY = 0

	if math.abs(normalizedX) > edgeThreshold then
		local strength = (math.abs(normalizedX) - edgeThreshold) / (1 - edgeThreshold)
		nudgeX = math.sign(normalizedX) * strength * NUDGE_PERCENTAGE * CAMERA_HEIGHT
	end

	if math.abs(normalizedY) > edgeThreshold then
		local strength = (math.abs(normalizedY) - edgeThreshold) / (1 - edgeThreshold)
		nudgeY = math.sign(normalizedY) * strength * NUDGE_PERCENTAGE * CAMERA_HEIGHT
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

-- Main camera update loop
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

	-- Calculate target nudge offset
	targetNudgeOffset = calculateNudgeOffset()

	-- Smoothly interpolate current nudge offset
	currentNudgeOffset = currentNudgeOffset:Lerp(targetNudgeOffset, NUDGE_SMOOTHNESS)

	-- Set camera position directly above player with nudge offset
	local characterPosition = rootPart.Position
	local cameraPosition = Vector3.new(
		characterPosition.X + currentNudgeOffset.X,
		characterPosition.Y + CAMERA_HEIGHT,
		characterPosition.Z + currentNudgeOffset.Y
	)

	-- Point camera straight down
	camera.CFrame = CFrame.new(cameraPosition, characterPosition)

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

	-- Reset nudge offset
	currentNudgeOffset = Vector2.new(0, 0)
	targetNudgeOffset = Vector2.new(0, 0)
end)

-- Initialize
disablePlayerControls()

-- Connect update loop
RunService.RenderStepped:Connect(updateCamera)

print("Top-Down Camera System loaded successfully!")

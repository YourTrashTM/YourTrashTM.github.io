--[[
	Advanced Top-Down Camera System for Roblox Studio
	Enhanced Hotline Miami-style camera with additional features

	Additional Features:
	- More orthographic projection simulation
	- Zoom controls (mouse wheel)
	- Camera shake system (for impacts/actions)
	- Smoother edge nudging with acceleration
	- Optional camera tilt for slight perspective

	Instructions:
	Place this script in StarterPlayer > StarterCharacterScripts
--]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera
local mouse = player:GetMouse()

-- Configuration
local CAMERA_HEIGHT = 50 -- Default height above the player
local MIN_CAMERA_HEIGHT = 25
local MAX_CAMERA_HEIGHT = 100
local CAMERA_FOV = 40 -- Lower FOV for more orthographic feel
local NUDGE_PERCENTAGE = 0.10 -- 10% extra viewing area
local NUDGE_SMOOTHNESS = 0.12 -- How smoothly the camera nudges
local NUDGE_ACCELERATION = 0.08 -- Acceleration for nudging
local CHARACTER_ROTATION_SPEED = 0.25 -- How fast character rotates
local ZOOM_SPEED = 5 -- Mouse wheel zoom speed
local CAMERA_TILT = 0 -- Optional slight tilt (0 = directly top-down, 5-10 = slight angle)

-- Camera nudge system
local currentNudgeOffset = Vector2.new(0, 0)
local targetNudgeOffset = Vector2.new(0, 0)
local nudgeVelocity = Vector2.new(0, 0)

-- Camera shake system
local shakeOffset = Vector3.new(0, 0, 0)
local shakeIntensity = 0
local shakeDuration = 0

-- Character references
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
local rootPart = character:WaitForChild("HumanoidRootPart")

-- Set initial camera mode
camera.CameraType = Enum.CameraType.Scriptable
camera.FieldOfView = CAMERA_FOV

-- Function to calculate nudge offset with smooth acceleration
local function calculateNudgeOffset()
	local viewportSize = camera.ViewportSize
	local mousePosition = UserInputService:GetMouseLocation()

	-- Calculate normalized position from center (-1 to 1)
	local normalizedX = (mousePosition.X / viewportSize.X) * 2 - 1
	local normalizedY = (mousePosition.Y / viewportSize.Y) * 2 - 1

	-- Edge detection with smooth falloff
	local edgeThreshold = 0.65 -- Start nudging earlier for smoother feel
	local maxNudgeDistance = NUDGE_PERCENTAGE * CAMERA_HEIGHT

	local nudgeX = 0
	local nudgeY = 0

	-- Smooth quadratic easing for edge nudging
	if math.abs(normalizedX) > edgeThreshold then
		local strength = (math.abs(normalizedX) - edgeThreshold) / (1 - edgeThreshold)
		strength = strength * strength -- Quadratic easing
		nudgeX = math.sign(normalizedX) * strength * maxNudgeDistance
	end

	if math.abs(normalizedY) > edgeThreshold then
		local strength = (math.abs(normalizedY) - edgeThreshold) / (1 - edgeThreshold)
		strength = strength * strength -- Quadratic easing
		nudgeY = math.sign(normalizedY) * strength * maxNudgeDistance
	end

	return Vector2.new(nudgeX, nudgeY)
end

-- Function to get mouse world position on ground plane
local function getMouseWorldPosition()
	local mouseRay = camera:ScreenPointToRay(mouse.X, mouse.Y)
	local rayOrigin = mouseRay.Origin
	local rayDirection = mouseRay.Direction

	-- Calculate intersection with horizontal plane at character's Y position
	local characterY = rootPart.Position.Y
	local t = (characterY - rayOrigin.Y) / rayDirection.Y

	if t > 0 then
		local hitPosition = rayOrigin + rayDirection * t
		return Vector3.new(hitPosition.X, characterY, hitPosition.Z)
	end

	return rootPart.Position
end

-- Function to rotate character smoothly towards cursor
local function facePosition(position)
	if not rootPart or not rootPart.Parent then return end

	local currentPosition = rootPart.Position
	local direction = (position - currentPosition) * Vector3.new(1, 0, 1)

	if direction.Magnitude > 0.1 then
		local targetCFrame = CFrame.new(currentPosition, currentPosition + direction)
		rootPart.CFrame = rootPart.CFrame:Lerp(targetCFrame, CHARACTER_ROTATION_SPEED)
	end
end

-- Camera shake function (can be called from other scripts)
local function shakeCamera(intensity, duration)
	shakeIntensity = math.max(shakeIntensity, intensity)
	shakeDuration = math.max(shakeDuration, duration)
end

-- Update camera shake
local function updateCameraShake(deltaTime)
	if shakeDuration > 0 then
		shakeDuration = shakeDuration - deltaTime

		-- Random shake offset
		local randomX = (math.random() - 0.5) * 2 * shakeIntensity
		local randomZ = (math.random() - 0.5) * 2 * shakeIntensity
		shakeOffset = Vector3.new(randomX, 0, randomZ)

		-- Decay intensity
		shakeIntensity = shakeIntensity * 0.9
	else
		shakeOffset = Vector3.new(0, 0, 0)
		shakeIntensity = 0
	end
end

-- Main camera update loop
local lastUpdateTime = tick()

local function updateCamera()
	local currentTime = tick()
	local deltaTime = currentTime - lastUpdateTime
	lastUpdateTime = currentTime

	if not character or not character.Parent then
		character = player.Character
		if character then
			humanoid = character:WaitForChild("Humanoid")
			rootPart = character:WaitForChild("HumanoidRootPart")
		end
		return
	end

	if not rootPart or not rootPart.Parent then return end

	-- Calculate target nudge with acceleration
	targetNudgeOffset = calculateNudgeOffset()

	-- Apply velocity-based smoothing for more natural movement
	local nudgeDifference = targetNudgeOffset - currentNudgeOffset
	nudgeVelocity = nudgeVelocity:Lerp(nudgeDifference, NUDGE_ACCELERATION)
	currentNudgeOffset = currentNudgeOffset + nudgeVelocity * NUDGE_SMOOTHNESS

	-- Update camera shake
	updateCameraShake(deltaTime)

	-- Calculate camera position
	local characterPosition = rootPart.Position
	local baseCameraPosition = Vector3.new(
		characterPosition.X + currentNudgeOffset.X,
		characterPosition.Y + CAMERA_HEIGHT,
		characterPosition.Z + currentNudgeOffset.Y
	)

	-- Apply camera shake
	local finalCameraPosition = baseCameraPosition + shakeOffset

	-- Create camera CFrame with optional tilt
	local lookAtPosition = characterPosition
	local cameraCFrame = CFrame.new(finalCameraPosition, lookAtPosition)

	-- Apply optional tilt for slight perspective
	if CAMERA_TILT > 0 then
		local tiltRadians = math.rad(CAMERA_TILT)
		cameraCFrame = cameraCFrame * CFrame.Angles(tiltRadians, 0, 0)
	end

	camera.CFrame = cameraCFrame

	-- Make character face cursor
	local mouseWorldPos = getMouseWorldPosition()
	facePosition(mouseWorldPos)
end

-- Mouse wheel zoom control
UserInputService.InputChanged:Connect(function(input, gameProcessed)
	if gameProcessed then return end

	if input.UserInputType == Enum.UserInputType.MouseWheel then
		-- Zoom in/out with mouse wheel
		CAMERA_HEIGHT = math.clamp(
			CAMERA_HEIGHT - (input.Position.Z * ZOOM_SPEED),
			MIN_CAMERA_HEIGHT,
			MAX_CAMERA_HEIGHT
		)
	end
end)

-- Optional: Reset camera height with R key
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end

	if input.KeyCode == Enum.KeyCode.R then
		CAMERA_HEIGHT = 50 -- Reset to default
	elseif input.KeyCode == Enum.KeyCode.T then
		-- Test camera shake
		shakeCamera(2, 0.3)
	end
end)

-- Disable default camera controls
player.CameraMode = Enum.CameraMode.LockFirstPerson
player.CameraMaxZoomDistance = 0
player.CameraMinZoomDistance = 0

-- Handle character respawn
player.CharacterAdded:Connect(function(newCharacter)
	character = newCharacter
	humanoid = character:WaitForChild("Humanoid")
	rootPart = character:WaitForChild("HumanoidRootPart")

	camera.CameraType = Enum.CameraType.Scriptable
	camera.FieldOfView = CAMERA_FOV

	-- Reset states
	currentNudgeOffset = Vector2.new(0, 0)
	targetNudgeOffset = Vector2.new(0, 0)
	nudgeVelocity = Vector2.new(0, 0)
	shakeOffset = Vector3.new(0, 0, 0)
	shakeIntensity = 0
	shakeDuration = 0
end)

-- Connect main update loop
RunService.RenderStepped:Connect(updateCamera)

-- Expose camera shake function globally (optional)
_G.ShakeCamera = shakeCamera

print("Advanced Top-Down Camera System loaded!")
print("Controls: Mouse Wheel = Zoom, R = Reset Zoom, T = Test Shake")

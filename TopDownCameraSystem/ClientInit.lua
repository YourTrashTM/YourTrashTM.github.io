-- ClientInit.lua
-- LocalScript to initialize the top-down camera system
-- Place this in StarterPlayer.StarterPlayerScripts or StarterCharacterScripts

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

-- Get camera system folder (adjust path as needed)
local CameraSystemFolder = script.Parent -- Assumes modules are in same folder
local TopDownCameraController = require(CameraSystemFolder.TopDownCameraController)
local DebugVisualizer = require(CameraSystemFolder.DebugVisualizer)

-- Create controller
local camera = workspace.CurrentCamera
local player = Players.LocalPlayer

local controller = TopDownCameraController.new()
controller:Init(player, camera)

-- Optional: Set custom profile or configuration
-- controller:SetProfile("Responsive")

-- Optional: Override specific config values
-- controller:SetProfile({
-- 	Pitch = 75,
-- 	BaseHeight = 25,
-- 	RotationMode = "AimAligned",
-- })

-- Enable camera when character loads
local function onCharacterAdded(character)
	-- Wait for HumanoidRootPart
	local rootPart = character:WaitForChild("HumanoidRootPart", 5)
	if not rootPart then
		warn("HumanoidRootPart not found, camera may not work correctly")
		return
	end

	-- Small delay to let physics settle
	task.wait(0.1)

	-- Enable camera
	controller:Enable()
end

-- Handle initial character
if player.Character then
	onCharacterAdded(player.Character)
end

-- Handle respawns
player.CharacterAdded:Connect(onCharacterAdded)

-- Optional: Create debug visualizer
local debugVisualizer = DebugVisualizer.new(controller)

-- Optional: Toggle debug with F3 key
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end

	if input.KeyCode == Enum.KeyCode.F3 then
		debugVisualizer:Toggle()
	end
end)

-- Optional: Expose API for other scripts
_G.TopDownCamera = controller
_G.CameraDebug = debugVisualizer

-- Optional: Connect to framing changes for custom systems
-- controller.OnFramingChanged:Connect(function(data)
-- 	-- data.focusPoint
-- 	-- data.cameraPosition
-- 	-- data.zoom
-- 	-- data.yaw
-- 	-- data.lookAheadOffset
-- end)

-- Cleanup on script removed (rare but good practice)
script.AncestryChanged:Connect(function()
	if not script:IsDescendantOf(game) then
		controller:Destroy()
		debugVisualizer:Disable()
	end
end)

print("Top-down camera system initialized")
print("Press F3 to toggle debug visualization")

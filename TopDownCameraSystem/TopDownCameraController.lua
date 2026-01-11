-- TopDownCameraController.lua
-- Main camera controller for top-down perspective with dynamic framing
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local Smoother = require(script.Parent.Smoother)
local InputAdapter = require(script.Parent.InputAdapter)
local CollisionResolver = require(script.Parent.CollisionResolver)

local TopDownCameraController = {}
TopDownCameraController.__index = TopDownCameraController

-- Default configuration
local DEFAULT_CONFIG = {
	-- Perspective
	Pitch = 70, -- Degrees from horizontal
	BaseHeight = 20,
	BaseDistance = 15,

	-- Rotation mode: "WorldAligned", "AimAligned", "MovementAligned"
	RotationMode = "WorldAligned",
	RotationYaw = 0, -- Fixed yaw for WorldAligned mode
	YawSmoothTime = 0.3,
	MaxYawAdjustment = 15, -- Max degrees for lite alignment modes

	-- Follow and smoothing
	FollowSmoothTime = 0.15,
	AimSmoothTime = 0.2,
	ZoomSmoothTime = 0.25,

	-- Look-ahead
	AimWeight = 1.0,
	MovementWeight = 0.5,
	AimDominanceThreshold = 0.7, -- Above this, aim dominates
	MaxLookAheadDistance = 8,
	MaxScreenOffset = 4, -- Max offset from character center

	-- Deadzone
	DeadzoneRadius = 1.5,
	DeadzoneResponse = 3, -- Ease curve exponent

	-- Zoom
	BaseZoom = 25,
	DynamicZoomEnabled = true,
	ZoomSpeedFactor = 0.3,
	MinZoom = 15,
	MaxZoom = 40,

	-- Collision
	CollisionEnabled = true,
	CollisionPullback = 0.5,
	CeilingClearance = 2,
	IgnoreTransparent = true,

	-- Movement detection
	MovementDirectionMode = "MoveDirection", -- "MoveDirection", "Velocity", "Hybrid"
	MovementDirectionDecay = 0.5,

	-- Gamepad
	GamepadDeadzone = 0.15,
	GamepadSensitivityCurve = 2,
	GamepadAimRange = 50,

	-- Transition
	TransitionDuration = 0.5,
	TransitionEase = "Quad",

	-- Reference plane
	ReferencePlaneMode = "Character", -- "Character", "Fixed", "SurfaceDetect"
	FixedPlaneY = 0,
}

-- Create new controller
function TopDownCameraController.new()
	local self = setmetatable({}, TopDownCameraController)

	-- State
	self.state = "Disabled" -- Disabled, Active, Transitioning
	self.enabled = false

	-- References
	self.player = nil
	self.camera = nil
	self.character = nil
	self.humanoid = nil
	self.rootPart = nil

	-- Configuration
	self.config = self:DeepCopy(DEFAULT_CONFIG)

	-- Modules
	self.inputAdapter = nil
	self.collisionResolver = nil

	-- Smoothers
	self.positionSmoother = nil
	self.lookAheadSmoother = nil
	self.zoomSmoother = nil
	self.yawSmoother = nil

	-- Framing state
	self.currentPosition = Vector3.zero
	self.currentLookAt = Vector3.zero
	self.currentZoom = DEFAULT_CONFIG.BaseZoom
	self.currentYaw = 0

	-- Movement tracking
	self.lastMoveDirection = Vector3.zero
	self.lastVelocity = Vector3.zero

	-- POI system
	self.pointsOfInterest = {} -- {instance = {weight, options}}

	-- Door registry (for future fog of war)
	self.doorRegistry = nil

	-- Signals
	self.framingChangedSignal = Instance.new("BindableEvent")
	self.OnFramingChanged = self.framingChangedSignal.Event

	-- Lifecycle
	self.connections = {}
	self.characterAddedConnection = nil

	-- Saved camera state
	self.savedCameraType = nil
	self.savedCameraSubject = nil

	return self
end

-- Initialize with player and camera
function TopDownCameraController:Init(player, camera)
	self.player = player or Players.LocalPlayer
	self.camera = camera or workspace.CurrentCamera

	-- Create modules
	self.inputAdapter = InputAdapter.new(self.camera, self.config)
	self.collisionResolver = CollisionResolver.new(self.config)

	-- Create smoothers
	self.positionSmoother = Smoother.new(Vector3.zero, self.config.FollowSmoothTime)
	self.lookAheadSmoother = Smoother.new(Vector3.zero, self.config.AimSmoothTime)
	self.zoomSmoother = Smoother.new(self.config.BaseZoom, self.config.ZoomSmoothTime)
	self.yawSmoother = Smoother.new(0, self.config.YawSmoothTime)

	-- Setup character tracking
	self:SetupCharacterTracking()
end

-- Setup character tracking with respawn handling
function TopDownCameraController:SetupCharacterTracking()
	if not self.player then return end

	-- Disconnect previous
	if self.characterAddedConnection then
		self.characterAddedConnection:Disconnect()
		self.characterAddedConnection = nil
	end

	-- Track current character
	if self.player.Character then
		self:OnCharacterAdded(self.player.Character)
	end

	-- Track respawns
	self.characterAddedConnection = self.player.CharacterAdded:Connect(function(character)
		self:OnCharacterAdded(character)
	end)
end

-- Handle character added
function TopDownCameraController:OnCharacterAdded(character)
	self:SetSubject(character)
end

-- Set camera subject
function TopDownCameraController:SetSubject(subject)
	-- Clear previous
	self.character = nil
	self.humanoid = nil
	self.rootPart = nil

	if not subject then return end

	-- Handle Model
	if subject:IsA("Model") then
		self.character = subject
		self.humanoid = subject:FindFirstChildOfClass("Humanoid")
		self.rootPart = subject:FindFirstChild("HumanoidRootPart") or subject.PrimaryPart
	elseif subject:IsA("BasePart") then
		self.rootPart = subject
	end

	-- Update collision ignore
	if self.collisionResolver and self.character then
		self.collisionResolver:SetCharacter(self.character)
	end

	-- Snap smoothers to new subject if active
	if self.enabled and self.rootPart then
		local pos = self.rootPart.Position
		self.positionSmoother:Snap(pos)
		self.lookAheadSmoother:Snap(Vector3.zero)
		self.currentPosition = pos
		self.currentLookAt = pos
	end
end

-- Enable camera
function TopDownCameraController:Enable()
	if self.enabled then return end

	-- Save current camera state
	self.savedCameraType = self.camera.CameraType
	self.savedCameraSubject = self.camera.CameraSubject

	-- Set camera to scriptable
	self.camera.CameraType = Enum.CameraType.Scriptable

	-- Initialize state
	if self.rootPart then
		local pos = self.rootPart.Position
		self.positionSmoother:Snap(pos)
		self.lookAheadSmoother:Snap(Vector3.zero)
		self.currentPosition = pos
		self.currentLookAt = pos
	end

	-- Bind render step
	RunService:BindToRenderStep("TopDownCamera", Enum.RenderPriority.Camera.Value, function(dt)
		self:Update(dt)
	end)

	self.enabled = true
	self.state = "Active"
end

-- Disable camera
function TopDownCameraController:Disable()
	if not self.enabled then return end

	-- Unbind render step
	RunService:UnbindFromRenderStep("TopDownCamera")

	-- Restore camera state
	if self.savedCameraType then
		self.camera.CameraType = self.savedCameraType
	end
	if self.savedCameraSubject then
		self.camera.CameraSubject = self.savedCameraSubject
	end

	self.enabled = false
	self.state = "Disabled"
end

-- Main update loop
function TopDownCameraController:Update(dt)
	if not self.enabled or not self.rootPart then return end

	local subjectPos = self.rootPart.Position

	-- Update input
	self.inputAdapter:Update(dt, subjectPos, self.currentYaw)

	-- Get movement direction
	local moveDir = self:GetMovementDirection()

	-- Get aim data
	local referenceY = self:GetReferencePlaneY(subjectPos)
	local aimPos, aimDir, aimStrength = self.inputAdapter:GetAimWorld(subjectPos, referenceY)

	-- Compute look-ahead direction
	local lookAheadDir = self:ComputeLookAheadDirection(moveDir, aimDir, aimStrength)

	-- Compute look-ahead offset with deadzone
	local lookAheadOffset = self:ComputeLookAheadOffset(lookAheadDir, subjectPos)

	-- Smooth look-ahead
	local smoothedOffset = self.lookAheadSmoother:Update(lookAheadOffset, dt)

	-- Compute focus point
	local focusPoint = subjectPos + smoothedOffset

	-- Compute dynamic zoom
	local targetZoom = self:ComputeDynamicZoom(dt)
	local smoothedZoom = self.zoomSmoother:Update(targetZoom, dt)
	self.currentZoom = smoothedZoom

	-- Compute yaw
	local targetYaw = self:ComputeYaw(lookAheadDir, moveDir, aimDir, aimStrength)
	local smoothedYaw = self.yawSmoother:Update(targetYaw, dt)
	self.currentYaw = smoothedYaw

	-- Compute camera offset from focus
	local cameraOffset = self:ComputeCameraOffset(smoothedZoom, smoothedYaw)

	-- Compute ideal camera position
	local idealCameraPos = focusPoint + cameraOffset

	-- Smooth camera position
	local smoothedCameraPos = self.positionSmoother:Update(idealCameraPos, dt)

	-- Resolve collision
	if self.config.CollisionEnabled then
		smoothedCameraPos = self.collisionResolver:ResolveAll(
			smoothedCameraPos,
			subjectPos,
			self.config.CeilingClearance
		)
	end

	-- Apply to camera
	self.camera.CFrame = CFrame.new(smoothedCameraPos, focusPoint)
	self.camera.FieldOfView = 70

	self.currentPosition = smoothedCameraPos
	self.currentLookAt = focusPoint

	-- Fire framing changed signal
	self.framingChangedSignal:Fire({
		focusPoint = focusPoint,
		cameraPosition = smoothedCameraPos,
		zoom = smoothedZoom,
		yaw = smoothedYaw,
		lookAheadOffset = smoothedOffset,
	})
end

-- Get movement direction using configured mode
function TopDownCameraController:GetMovementDirection()
	if not self.humanoid then
		return Vector3.zero
	end

	local mode = self.config.MovementDirectionMode

	if mode == "MoveDirection" then
		local moveDir = self.humanoid.MoveDirection
		if moveDir.Magnitude > 0.1 then
			self.lastMoveDirection = moveDir
			return moveDir
		else
			-- Decay last direction
			self.lastMoveDirection = self.lastMoveDirection * (1 - self.config.MovementDirectionDecay * (1/60))
			return self.lastMoveDirection
		end
	elseif mode == "Velocity" then
		if self.rootPart then
			local vel = self.rootPart.AssemblyLinearVelocity
			local horizontal = Vector3.new(vel.X, 0, vel.Z)
			if horizontal.Magnitude > 1 then
				return horizontal.Unit
			end
		end
		return Vector3.zero
	elseif mode == "Hybrid" then
		-- Prefer MoveDirection, fallback to velocity
		local moveDir = self.humanoid.MoveDirection
		if moveDir.Magnitude > 0.1 then
			self.lastMoveDirection = moveDir
			return moveDir
		end

		if self.rootPart then
			local vel = self.rootPart.AssemblyLinearVelocity
			local horizontal = Vector3.new(vel.X, 0, vel.Z)
			if horizontal.Magnitude > 1 then
				return horizontal.Unit
			end
		end

		return Vector3.zero
	end

	return Vector3.zero
end

-- Compute look-ahead direction from aim and movement
function TopDownCameraController:ComputeLookAheadDirection(moveDir, aimDir, aimStrength)
	local aimWeight = self.config.AimWeight
	local moveWeight = self.config.MovementWeight
	local dominanceThreshold = self.config.AimDominanceThreshold

	-- Aim dominance
	if aimStrength >= dominanceThreshold and aimDir then
		return aimDir
	end

	-- Blend aim and movement
	local totalWeight = 0
	local blended = Vector3.zero

	if aimDir and aimStrength > 0 then
		blended = blended + aimDir * aimWeight * aimStrength
		totalWeight = totalWeight + aimWeight * aimStrength
	end

	if moveDir.Magnitude > 0.1 then
		blended = blended + moveDir * moveWeight
		totalWeight = totalWeight + moveWeight
	end

	if totalWeight > 0 then
		return (blended / totalWeight).Unit
	end

	return Vector3.zero
end

-- Compute look-ahead offset with deadzone
function TopDownCameraController:ComputeLookAheadOffset(lookAheadDir, subjectPos)
	if lookAheadDir.Magnitude < 0.1 then
		return Vector3.zero
	end

	local maxDistance = self.config.MaxLookAheadDistance
	local rawOffset = lookAheadDir * maxDistance

	-- Apply deadzone
	local deadzone = self.config.DeadzoneRadius
	local currentOffset = self.lookAheadSmoother:Get()
	local delta = rawOffset - currentOffset
	local deltaMag = delta.Magnitude

	if deltaMag < deadzone then
		return currentOffset
	end

	-- Ease out of deadzone
	local response = self.config.DeadzoneResponse
	local t = math.min((deltaMag - deadzone) / maxDistance, 1)
	t = t ^ response

	return currentOffset + delta.Unit * deltaMag * t
end

-- Compute dynamic zoom based on speed
function TopDownCameraController:ComputeDynamicZoom(dt)
	local baseZoom = self.config.BaseZoom

	if not self.config.DynamicZoomEnabled or not self.rootPart then
		return baseZoom
	end

	local vel = self.rootPart.AssemblyLinearVelocity
	local horizontalSpeed = Vector3.new(vel.X, 0, vel.Z).Magnitude

	local zoomAdd = horizontalSpeed * self.config.ZoomSpeedFactor
	local targetZoom = baseZoom + zoomAdd

	return math.clamp(targetZoom, self.config.MinZoom, self.config.MaxZoom)
end

-- Compute yaw based on rotation mode
function TopDownCameraController:ComputeYaw(lookAheadDir, moveDir, aimDir, aimStrength)
	local mode = self.config.RotationMode

	if mode == "WorldAligned" then
		return math.rad(self.config.RotationYaw)
	elseif mode == "AimAligned" then
		if aimDir and aimStrength > 0.3 then
			local targetAngle = math.atan2(aimDir.Z, aimDir.X)
			local currentAngle = self.currentYaw
			local delta = self:AngleDelta(targetAngle, currentAngle)
			local maxAdjust = math.rad(self.config.MaxYawAdjustment)
			delta = math.clamp(delta, -maxAdjust, maxAdjust)
			return currentAngle + delta * 0.5
		end
		return self.currentYaw
	elseif mode == "MovementAligned" then
		if moveDir.Magnitude > 0.1 then
			local targetAngle = math.atan2(moveDir.Z, moveDir.X)
			local currentAngle = self.currentYaw
			local delta = self:AngleDelta(targetAngle, currentAngle)
			local maxAdjust = math.rad(self.config.MaxYawAdjustment)
			delta = math.clamp(delta, -maxAdjust, maxAdjust)
			return currentAngle + delta * 0.5
		end
		return self.currentYaw
	end

	return self.currentYaw
end

-- Compute camera offset from focus point
function TopDownCameraController:ComputeCameraOffset(zoom, yaw)
	local pitch = math.rad(self.config.Pitch)
	local distance = zoom

	-- Compute offset in camera space
	local horizontalDist = distance * math.cos(pitch)
	local verticalDist = distance * math.sin(pitch)

	-- Rotate by yaw
	local offsetX = -horizontalDist * math.sin(yaw)
	local offsetZ = -horizontalDist * math.cos(yaw)

	return Vector3.new(offsetX, verticalDist, offsetZ)
end

-- Get reference plane Y coordinate
function TopDownCameraController:GetReferencePlaneY(subjectPos)
	local mode = self.config.ReferencePlaneMode

	if mode == "Character" then
		return subjectPos.Y
	elseif mode == "Fixed" then
		return self.config.FixedPlaneY
	elseif mode == "SurfaceDetect" then
		-- Raycast down to find floor
		local rayParams = RaycastParams.new()
		rayParams.FilterDescendantsInstances = self.collisionResolver.ignoreList
		rayParams.FilterType = Enum.RaycastFilterType.Exclude

		local result = workspace:Raycast(subjectPos, Vector3.new(0, -100, 0), rayParams)
		if result then
			return result.Position.Y
		end
		return subjectPos.Y
	end

	return subjectPos.Y
end

-- Angle delta helper
function TopDownCameraController:AngleDelta(target, current)
	local delta = target - current
	while delta > math.pi do delta = delta - 2 * math.pi end
	while delta < -math.pi do delta = delta + 2 * math.pi end
	return delta
end

-- Set configuration profile
function TopDownCameraController:SetProfile(profile)
	if type(profile) == "string" then
		-- Load predefined profile
		local profiles = self:GetPredefinedProfiles()
		if profiles[profile] then
			self:MergeConfig(profiles[profile])
		end
	elseif type(profile) == "table" then
		self:MergeConfig(profile)
	end

	-- Update smoother half-lives
	if self.positionSmoother then
		self.positionSmoother.halfLife = self.config.FollowSmoothTime
	end
	if self.lookAheadSmoother then
		self.lookAheadSmoother.halfLife = self.config.AimSmoothTime
	end
	if self.zoomSmoother then
		self.zoomSmoother.halfLife = self.config.ZoomSmoothTime
	end
	if self.yawSmoother then
		self.yawSmoother.halfLife = self.config.YawSmoothTime
	end
end

-- Merge configuration
function TopDownCameraController:MergeConfig(newConfig)
	for key, value in pairs(newConfig) do
		self.config[key] = value
	end
end

-- Get predefined profiles
function TopDownCameraController:GetPredefinedProfiles()
	return {
		Default = DEFAULT_CONFIG,
		Cinematic = {
			FollowSmoothTime = 0.3,
			AimSmoothTime = 0.4,
			ZoomSmoothTime = 0.5,
		},
		Responsive = {
			FollowSmoothTime = 0.05,
			AimSmoothTime = 0.1,
			ZoomSmoothTime = 0.15,
		},
		Indoor = {
			BaseZoom = 18,
			DynamicZoomEnabled = false,
			CeilingClearance = 1.5,
		},
	}
end

-- Set door registry for future fog of war
function TopDownCameraController:SetDoorRegistry(registry)
	self.doorRegistry = registry
end

-- Bind point of interest
function TopDownCameraController:BindPOI(instance, weight, options)
	self.pointsOfInterest[instance] = {
		weight = weight or 1,
		options = options or {},
	}
end

-- Unbind point of interest
function TopDownCameraController:UnbindPOI(instance)
	self.pointsOfInterest[instance] = nil
end

-- Get aim world position
function TopDownCameraController:GetAimWorldPosition()
	if not self.rootPart then return Vector3.zero end

	local subjectPos = self.rootPart.Position
	local referenceY = self:GetReferencePlaneY(subjectPos)
	local aimPos, _, _ = self.inputAdapter:GetAimWorld(subjectPos, referenceY)

	return aimPos or subjectPos
end

-- Get aim world direction
function TopDownCameraController:GetAimWorldDirection()
	if not self.rootPart then return Vector3.zero end

	local subjectPos = self.rootPart.Position
	local referenceY = self:GetReferencePlaneY(subjectPos)
	local _, aimDir, _ = self.inputAdapter:GetAimWorld(subjectPos, referenceY)

	return aimDir or Vector3.new(0, 0, 1)
end

-- Get view origin for raycasts
function TopDownCameraController:GetViewOrigin()
	return self.currentPosition
end

-- Get view direction
function TopDownCameraController:GetViewDirection()
	local dir = (self.currentLookAt - self.currentPosition)
	if dir.Magnitude > 0 then
		return dir.Unit
	end
	return Vector3.new(0, -1, 0)
end

-- Deep copy helper
function TopDownCameraController:DeepCopy(original)
	local copy = {}
	for k, v in pairs(original) do
		if type(v) == "table" then
			copy[k] = self:DeepCopy(v)
		else
			copy[k] = v
		end
	end
	return copy
end

-- Cleanup
function TopDownCameraController:Destroy()
	self:Disable()

	if self.characterAddedConnection then
		self.characterAddedConnection:Disconnect()
	end

	for _, conn in ipairs(self.connections) do
		conn:Disconnect()
	end

	self.framingChangedSignal:Destroy()
end

return TopDownCameraController

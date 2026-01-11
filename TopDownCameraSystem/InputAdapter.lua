-- InputAdapter.lua
-- Handles mouse and gamepad aim abstraction and world space projection
local UserInputService = game:GetService("UserInputService")

local InputAdapter = {}
InputAdapter.__index = InputAdapter

function InputAdapter.new(camera, config)
	local self = setmetatable({}, InputAdapter)

	self.camera = camera
	self.config = config or {}

	-- Mouse state
	self.mousePosition = Vector2.new()
	self.mouseActive = false

	-- Gamepad state
	self.gamepadAim = Vector2.new()
	self.gamepadActive = false
	self.lastGamepadAimWorldDir = nil

	-- Fallback and filtering
	self.lastAimDirection = nil
	self.aimStrength = 0

	return self
end

-- Update input state, call before GetAimWorld
function InputAdapter:Update(dt, characterPosition, cameraYaw)
	self:UpdateMouse()
	self:UpdateGamepad(dt, characterPosition, cameraYaw)
end

-- Update mouse position
function InputAdapter:UpdateMouse()
	if UserInputService.MouseEnabled then
		self.mousePosition = UserInputService:GetMouseLocation()
		self.mouseActive = true
	else
		self.mouseActive = false
	end
end

-- Update gamepad thumbstick
function InputAdapter:UpdateGamepad(dt, characterPosition, cameraYaw)
	local thumbstick = UserInputService:GetGamepadState(Enum.UserInputType.Gamepad1)
	local rightX, rightY = 0, 0

	for _, input in ipairs(thumbstick) do
		if input.KeyCode == Enum.KeyCode.Thumbstick2 then
			rightX = input.Position.X
			rightY = -input.Position.Y -- Invert Y for world space
		end
	end

	local deadzone = self.config.GamepadDeadzone or 0.15
	local magnitude = math.sqrt(rightX * rightX + rightY * rightY)

	if magnitude > deadzone then
		local normalized = (magnitude - deadzone) / (1 - deadzone)
		normalized = math.min(normalized, 1)

		-- Apply sensitivity curve
		local curve = self.config.GamepadSensitivityCurve or 2
		normalized = normalized ^ curve

		local angle = math.atan2(rightY, rightX)
		self.gamepadAim = Vector2.new(math.cos(angle) * normalized, math.sin(angle) * normalized)
		self.gamepadActive = true

		-- Convert to world direction relative to camera yaw
		local worldAngle = angle + cameraYaw
		local worldDir = Vector3.new(math.cos(worldAngle), 0, math.sin(worldAngle))
		self.lastGamepadAimWorldDir = worldDir
	else
		self.gamepadAim = Vector2.new()
		self.gamepadActive = false
	end
end

-- Get aim world position and direction using plane intersection
function InputAdapter:GetAimWorld(characterPosition, referenceHeight)
	local aimPos, aimDir, strength = nil, nil, 0

	if self.mouseActive and self.camera then
		-- Project mouse ray to reference plane
		local viewport = self.camera.ViewportSize
		local ray = self.camera:ViewportPointToRay(self.mousePosition.X, self.mousePosition.Y)

		-- Intersect with horizontal plane at reference height
		local planeY = referenceHeight or characterPosition.Y
		local t = (planeY - ray.Origin.Y) / ray.Direction.Y

		if t > 0 then
			aimPos = ray.Origin + ray.Direction * t
			aimDir = (aimPos - characterPosition) * Vector3.new(1, 0, 1)

			if aimDir.Magnitude > 0.1 then
				aimDir = aimDir.Unit
				strength = 1
			else
				aimDir = nil
			end
		end
	elseif self.gamepadActive and self.lastGamepadAimWorldDir then
		-- Use gamepad world direction
		aimDir = self.lastGamepadAimWorldDir
		local maxRange = self.config.GamepadAimRange or 50
		aimPos = characterPosition + aimDir * maxRange
		strength = self.gamepadAim.Magnitude
	end

	-- Fallback and update last known
	if aimDir then
		self.lastAimDirection = aimDir
		self.aimStrength = strength
	else
		-- Decay strength when no input
		self.aimStrength = math.max(0, self.aimStrength - (1 / 0.3) * (1/60)) -- 0.3s decay
	end

	return aimPos, aimDir or self.lastAimDirection, self.aimStrength
end

-- Get raw input strength for aim dominance
function InputAdapter:GetAimStrength()
	return self.aimStrength
end

-- Check if any aim input is active
function InputAdapter:IsAimActive()
	return self.mouseActive or self.gamepadActive
end

return InputAdapter

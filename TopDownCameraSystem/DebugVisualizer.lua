-- DebugVisualizer.lua
-- Optional debug visualization for camera tuning and development
local RunService = game:GetService("RunService")

local DebugVisualizer = {}
DebugVisualizer.__index = DebugVisualizer

function DebugVisualizer.new(controller)
	local self = setmetatable({}, DebugVisualizer)

	self.controller = controller
	self.enabled = false

	-- Visual elements
	self.folder = nil
	self.parts = {}
	self.beams = {}
	self.labels = {}

	-- Update connection
	self.connection = nil

	return self
end

-- Enable debug visualization
function DebugVisualizer:Enable()
	if self.enabled then return end

	-- Create folder
	self.folder = Instance.new("Folder")
	self.folder.Name = "CameraDebug"
	self.folder.Parent = workspace

	-- Create visualization parts
	self:CreateParts()

	-- Connect to render
	self.connection = RunService.RenderStepped:Connect(function()
		self:Update()
	end)

	self.enabled = true
end

-- Disable debug visualization
function DebugVisualizer:Disable()
	if not self.enabled then return end

	if self.connection then
		self.connection:Disconnect()
		self.connection = nil
	end

	if self.folder then
		self.folder:Destroy()
		self.folder = nil
	end

	self.parts = {}
	self.beams = {}
	self.labels = {}

	self.enabled = false
end

-- Create visualization parts
function DebugVisualizer:CreateParts()
	-- Camera position marker
	self.parts.camera = self:CreateSphere("Camera", Color3.new(0, 1, 1), 0.5)

	-- Focus point marker
	self.parts.focus = self:CreateSphere("Focus", Color3.new(1, 1, 0), 0.3)

	-- Subject marker
	self.parts.subject = self:CreateSphere("Subject", Color3.new(1, 0, 0), 0.4)

	-- Aim point marker
	self.parts.aim = self:CreateSphere("AimPoint", Color3.new(0, 1, 0), 0.3)

	-- Look-ahead offset marker
	self.parts.lookAhead = self:CreateSphere("LookAhead", Color3.new(1, 0.5, 0), 0.25)

	-- View direction beam
	self.beams.view = self:CreateBeam("ViewDirection", Color3.new(0, 1, 1))

	-- Aim direction beam
	self.beams.aim = self:CreateBeam("AimDirection", Color3.new(0, 1, 0))
end

-- Create sphere marker
function DebugVisualizer:CreateSphere(name, color, size)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = Vector3.new(size, size, size)
	part.Shape = Enum.PartType.Ball
	part.Color = color
	part.Material = Enum.Material.Neon
	part.CanCollide = false
	part.Anchored = true
	part.Transparency = 0.3
	part.Parent = self.folder

	return part
end

-- Create beam
function DebugVisualizer:CreateBeam(name, color)
	local attach0 = Instance.new("Attachment")
	local attach1 = Instance.new("Attachment")

	local part0 = Instance.new("Part")
	part0.Name = name .. "_Start"
	part0.Size = Vector3.new(0.1, 0.1, 0.1)
	part0.Transparency = 1
	part0.CanCollide = false
	part0.Anchored = true
	part0.Parent = self.folder

	local part1 = Instance.new("Part")
	part1.Name = name .. "_End"
	part1.Size = Vector3.new(0.1, 0.1, 0.1)
	part1.Transparency = 1
	part1.CanCollide = false
	part1.Anchored = true
	part1.Parent = self.folder

	attach0.Parent = part0
	attach1.Parent = part1

	local beam = Instance.new("Beam")
	beam.Name = name
	beam.Color = ColorSequence.new(color)
	beam.Width0 = 0.2
	beam.Width1 = 0.2
	beam.FaceCamera = true
	beam.Attachment0 = attach0
	beam.Attachment1 = attach1
	beam.Parent = part0

	return {beam = beam, part0 = part0, part1 = part1}
end

-- Update visualization
function DebugVisualizer:Update()
	if not self.enabled or not self.controller then return end

	local controller = self.controller

	-- Update camera position
	if self.parts.camera and controller.camera then
		self.parts.camera.Position = controller.camera.CFrame.Position
	end

	-- Update focus point
	if self.parts.focus then
		self.parts.focus.Position = controller.currentLookAt
	end

	-- Update subject
	if self.parts.subject and controller.rootPart then
		self.parts.subject.Position = controller.rootPart.Position
	end

	-- Update aim point
	if self.parts.aim then
		local aimPos = controller:GetAimWorldPosition()
		self.parts.aim.Position = aimPos
	end

	-- Update look-ahead offset
	if self.parts.lookAhead and controller.rootPart then
		local subjectPos = controller.rootPart.Position
		local offset = controller.lookAheadSmoother:Get()
		self.parts.lookAhead.Position = subjectPos + offset
	end

	-- Update view direction beam
	if self.beams.view then
		local origin = controller:GetViewOrigin()
		local dir = controller:GetViewDirection()
		self.beams.view.part0.Position = origin
		self.beams.view.part1.Position = origin + dir * 10
	end

	-- Update aim direction beam
	if self.beams.aim and controller.rootPart then
		local origin = controller.rootPart.Position
		local dir = controller:GetAimWorldDirection()
		self.beams.aim.part0.Position = origin
		self.beams.aim.part1.Position = origin + dir * 15
	end
end

-- Toggle visibility
function DebugVisualizer:Toggle()
	if self.enabled then
		self:Disable()
	else
		self:Enable()
	end
end

return DebugVisualizer

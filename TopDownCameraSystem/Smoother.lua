-- Smoother.lua
-- Frame-rate independent smoothing utility with minimal allocations
local Smoother = {}
Smoother.__index = Smoother

-- Create new smoother for a specific value type
function Smoother.new(initialValue, halfLife)
	local self = setmetatable({}, Smoother)
	self.current = initialValue
	self.velocity = typeof(initialValue) == "number" and 0 or Vector3.zero
	self.halfLife = halfLife or 0.1
	return self
end

-- Spring damper smoothing using half-life
function Smoother:Update(target, dt)
	if dt <= 0 or self.halfLife <= 0 then
		self.current = target
		return self.current
	end

	local omega = 0.69314718 / self.halfLife -- ln(2) / halfLife
	local x = omega * dt
	local exp = 1 / (1 + x + 0.48 * x * x + 0.235 * x * x * x) -- Fast exp approximation

	if typeof(self.current) == "number" then
		local delta = target - self.current
		self.current = self.current + delta * (1 - exp)
	else
		local delta = target - self.current
		self.current = self.current + delta * (1 - exp)
	end

	return self.current
end

-- Snap to target instantly
function Smoother:Snap(target)
	self.current = target
	self.velocity = typeof(target) == "number" and 0 or Vector3.zero
end

-- Get current value without updating
function Smoother:Get()
	return self.current
end

-- Reset to new value and half-life
function Smoother:Reset(value, halfLife)
	self.current = value
	self.velocity = typeof(value) == "number" and 0 or Vector3.zero
	if halfLife then
		self.halfLife = halfLife
	end
end

return Smoother

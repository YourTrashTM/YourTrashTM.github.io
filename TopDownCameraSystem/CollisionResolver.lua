-- CollisionResolver.lua
-- Handles camera collision, occlusion resolution, and ceiling detection
local CollisionResolver = {}
CollisionResolver.__index = CollisionResolver

function CollisionResolver.new(config)
	local self = setmetatable({}, CollisionResolver)

	self.config = config or {}
	self.ignoreList = {}
	self.ignoreTaggedParts = self.config.IgnoreTransparent or true

	-- Collision state
	self.lastCollisionDistance = nil
	self.ceilingHeight = nil

	return self
end

-- Set character to ignore in raycasts
function CollisionResolver:SetCharacter(character)
	self.ignoreList = {}

	if character then
		for _, desc in ipairs(character:GetDescendants()) do
			if desc:IsA("BasePart") then
				table.insert(self.ignoreList, desc)
			end
		end
	end
end

-- Add parts to ignore list
function CollisionResolver:AddIgnoreParts(parts)
	for _, part in ipairs(parts) do
		table.insert(self.ignoreList, part)
	end
end

-- Clear ignore list
function CollisionResolver:ClearIgnoreList()
	self.ignoreList = {}
end

-- Resolve camera position to avoid collision
function CollisionResolver:Resolve(targetPosition, subjectPosition)
	local direction = (targetPosition - subjectPosition)
	local distance = direction.Magnitude

	if distance < 0.1 then
		return targetPosition, false
	end

	local rayDir = direction.Unit
	local rayParams = RaycastParams.new()
	rayParams.FilterDescendantsInstances = self.ignoreList
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.IgnoreWater = true

	-- Main collision ray from subject to target
	local result = workspace:Raycast(subjectPosition, direction, rayParams)

	if result then
		-- Hit something, pull camera back
		local hitDistance = (result.Position - subjectPosition).Magnitude
		local pullback = self.config.CollisionPullback or 0.5
		local safeDistance = math.max(0.1, hitDistance - pullback)

		self.lastCollisionDistance = safeDistance
		return subjectPosition + rayDir * safeDistance, true
	else
		self.lastCollisionDistance = nil
		return targetPosition, false
	end
end

-- Check for ceiling above position
function CollisionResolver:CheckCeiling(position, maxHeight)
	local rayParams = RaycastParams.new()
	rayParams.FilterDescendantsInstances = self.ignoreList
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.IgnoreWater = true

	local checkHeight = maxHeight or 100
	local upRay = workspace:Raycast(position, Vector3.new(0, checkHeight, 0), rayParams)

	if upRay then
		self.ceilingHeight = upRay.Position.Y
		return upRay.Position.Y, upRay.Instance
	else
		self.ceilingHeight = nil
		return nil, nil
	end
end

-- Check if position is indoors based on ceiling proximity
function CollisionResolver:IsIndoors(position, threshold)
	local ceilingY, _ = self:CheckCeiling(position, threshold or 20)

	if ceilingY then
		local distance = ceilingY - position.Y
		return distance < (threshold or 20), distance
	end

	return false, nil
end

-- Resolve camera height to stay below ceilings
function CollisionResolver:ResolveCeiling(targetPosition, subjectPosition, minClearance)
	local clearance = minClearance or 2
	local ceilingY, _ = self:CheckCeiling(targetPosition, 100)

	if ceilingY then
		local maxY = ceilingY - clearance

		if targetPosition.Y > maxY then
			-- Camera would clip ceiling, lower it
			local newY = math.max(maxY, subjectPosition.Y + clearance)
			return Vector3.new(targetPosition.X, newY, targetPosition.Z), true
		end
	end

	return targetPosition, false
end

-- Combined resolve with both collision and ceiling
function CollisionResolver:ResolveAll(targetPosition, subjectPosition, minClearance)
	-- First resolve ceiling
	local pos, ceilingHit = self:ResolveCeiling(targetPosition, subjectPosition, minClearance)

	-- Then resolve collision
	local finalPos, collisionHit = self:Resolve(pos, subjectPosition)

	return finalPos, collisionHit or ceilingHit
end

-- Get last detected ceiling height
function CollisionResolver:GetLastCeilingHeight()
	return self.ceilingHeight
end

return CollisionResolver

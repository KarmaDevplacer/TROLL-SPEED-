-- Get necessary Roblox services.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local CollectionService = game:GetService("CollectionService") -- Useful for tagging specific dangerous objects

-- Get the local player, their character, and the humanoid within the character.
local localPlayer = Players.LocalPlayer
local character = localPlayer.Character or localPlayer.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
local humanoidRootPart = character:WaitForChild("HumanoidRootPart") -- The part we will teleport

-- --- Configuration for Ultra Instinct ---
local DETECTION_RADIUS = 50 -- How far away to detect potentially damaging objects (in studs)
local TELEPORT_RADIUS = 30 -- Max radius for random teleportation (in studs)
local MIN_TELEPORT_DISTANCE = 10 -- Minimum distance to teleport away from current position
local MIN_THREAT_VELOCITY = 10 -- Minimum velocity for a part to be considered a moving threat
local TELEPORT_COOLDOWN = 0.1 -- Minimum time between teleports to prevent excessive flickering (in seconds)

-- UI Colors
local UI_PRIMARY_COLOR = Color3.fromRGB(50, 50, 80) -- Dark Blue/Purple
local UI_ACCENT_COLOR = Color3.fromRGB(80, 80, 120) -- Lighter Blue/Purple
local UI_TEXT_COLOR = Color3.fromRGB(200, 200, 255) -- Light Blue/White
local UI_ACTIVE_COLOR = Color3.fromRGB(0, 200, 255) -- Bright Cyan for active state
local UI_INACTIVE_COLOR = Color3.fromRGB(150, 50, 50) -- Dark Red for inactive state
local UI_CLOSE_COLOR = Color3.fromRGB(200, 0, 0) -- Red for close button

-- State variable to control if the Ultra Instinct is active.
local isInstinctActive = false
local lastTeleportTime = 0 -- To manage teleport cooldown

-- Thread reference for the main detection and teleportation loop.
local instinctLoop = nil

---
-- UI Setup
---

local playerGui = localPlayer:WaitForChild("PlayerGui")
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "UltraInstinctUI"
screenGui.Parent = playerGui
screenGui.ResetOnSpawn = false -- Ensures the UI persists across deaths

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 220, 0, 200) -- Slightly larger frame
frame.Position = UDim2.new(0.5, -110, 0.1, 0) -- Center it
frame.BackgroundColor3 = UI_PRIMARY_COLOR
frame.BorderSizePixel = 0
frame.Parent = screenGui

-- Add UI Corner for rounded corners to the main frame
local uiCorner = Instance.new("UICorner")
uiCorner.CornerRadius = UDim.new(0, 10)
uiCorner.Parent = frame

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0.2, 0)
title.Text = "Instinto Defensivo: Ultra"
title.TextColor3 = UI_TEXT_COLOR
title.TextScaled = true
title.BackgroundColor3 = UI_ACCENT_COLOR
title.Font = Enum.Font.SourceSansBold
title.Parent = frame

-- Add UI Corner for rounded corners to the title
local titleUiCorner = Instance.new("UICorner")
titleUiCorner.CornerRadius = UDim.new(0, 10)
titleUiCorner.Parent = title

-- Close Button (the 'X')
local closeButton = Instance.new("TextButton")
closeButton.Size = UDim2.new(0, 28, 0, 28) -- Slightly larger button
closeButton.Position = UDim2.new(1, -28, 0, 0) -- Top-right corner of the frame
closeButton.Text = "X"
closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
closeButton.BackgroundColor3 = UI_CLOSE_COLOR
closeButton.Font = Enum.Font.SourceSansBold
closeButton.TextSize = 20
closeButton.Parent = frame

-- Add UI Corner for rounded corners to the close button
local closeButtonUiCorner = Instance.new("UICorner")
closeButtonUiCorner.CornerRadius = UDim.new(0, 5)
closeButtonUiCorner.Parent = closeButton

local toggleButton = Instance.new("TextButton")
toggleButton.Size = UDim2.new(0.9, 0, 0.25, 0)
toggleButton.Position = UDim2.new(0.05, 0, 0.25, 0)
toggleButton.Text = "Activar Instinto"
toggleButton.TextColor3 = UI_TEXT_COLOR
toggleButton.BackgroundColor3 = UI_INACTIVE_COLOR
toggleButton.Font = Enum.Font.SourceSansBold
toggleButton.Parent = frame

-- Add UI Corner for rounded corners to the toggle button
local toggleButtonUiCorner = Instance.new("UICorner")
toggleButtonUiCorner.CornerRadius = UDim.new(0, 8)
toggleButtonUiCorner.Parent = toggleButton

local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(0.9, 0, 0.25, 0)
statusLabel.Position = UDim2.new(0.05, 0, 0.5, 0)
statusLabel.Text = "Estado: Inactivo"
statusLabel.TextColor3 = UI_TEXT_COLOR
statusLabel.TextScaled = true
statusLabel.BackgroundColor3 = UI_ACCENT_COLOR
statusLabel.Font = Enum.Font.SourceSansBold
statusLabel.Parent = frame

-- Add UI Corner for rounded corners to the status label
local statusLabelUiCorner = Instance.new("UICorner")
statusLabelUiCorner.CornerRadius = UDim.new(0, 8)
statusLabelUiCorner.Parent = statusLabel

local lastTeleportInfoLabel = Instance.new("TextLabel")
lastTeleportInfoLabel.Size = UDim2.new(0.9, 0, 0.25, 0)
lastTeleportInfoLabel.Position = UDim2.new(0.05, 0, 0.75, 0)
lastTeleportInfoLabel.Text = "Última Esquiva: N/A"
lastTeleportInfoLabel.TextColor3 = UI_TEXT_COLOR
lastTeleportInfoLabel.TextScaled = true
lastTeleportInfoLabel.BackgroundColor3 = UI_ACCENT_COLOR
lastTeleportInfoLabel.Font = Enum.Font.SourceSansBold
lastTeleportInfoLabel.Parent = frame

-- Add UI Corner for rounded corners to the last teleport info label
local lastTeleportInfoUiCorner = Instance.new("UICorner")
lastTeleportInfoUiCorner.CornerRadius = UDim.new(0, 8)
lastTeleportInfoUiCorner.Parent = lastTeleportInfoLabel

---
-- Draggable UI Functionality (Standard)
---
local dragging = false
local dragInput
local dragStart
local startPos

local function updateFramePosition(input, gameProcessedEvent)
	local delta = input.Position - dragStart
	local newX = startPos.X.Offset + delta.X
	local newY = startPos.Y.Offset + delta.Y

	local maxX = screenGui.AbsoluteSize.X - frame.AbsoluteSize.X
	local maxY = screenGui.AbsoluteSize.Y - frame.AbsoluteSize.Y

	newX = math.clamp(newX, 0, maxX)
	newY = math.clamp(newY, 0, maxY)

	frame.Position = UDim2.new(0, newX, 0, newY)

	if not gameProcessedEvent then
		return true
	end
end

local function makeDraggable(guiObject)
	guiObject.InputBegan:Connect(function(input, gameProcessedEvent)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragInput = input
			dragStart = input.Position
			startPos = frame.Position

			input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					dragging = false
					dragInput = nil
				end
			end)

			if not gameProcessedEvent then
				return true
			end
		end
	end)
end

UserInputService.InputChanged:Connect(function(input, gameProcessedEvent)
	if dragging and input == dragInput then
		updateFramePosition(input, gameProcessedEvent)
	end
end)

makeDraggable(title)
makeDraggable(frame)


---
-- Ultra Instinct Core Logic
---

-- Function to check if a part is part of the player's character.
local function isPartOfCharacter(part)
    if not character then return false end
    return part:IsDescendantOf(character)
end

-- Function to find a safe teleport location.
-- This is a simplified approach: it just finds a random spot within the radius.
-- For true "safety" it would need raycasting or more complex collision checks.
local function findSafeTeleportLocation(currentPosition, threatPosition)
    local attempts = 5 -- Try a few times to find a good spot
    for i = 1, attempts do
        local randomAngle = math.random() * math.pi * 2 -- Random angle in radians
        local randomDistance = math.random(MIN_TELEPORT_DISTANCE * 100, TELEPORT_RADIUS * 100) / 100 -- Random distance within range

        -- Calculate a new position away from the current one
        local newX = currentPosition.X + math.cos(randomAngle) * randomDistance
        local newZ = currentPosition.Z + math.sin(randomAngle) * randomDistance
        local newY = currentPosition.Y -- Keep current Y or slightly adjust for floating effect

        local newPosition = Vector3.new(newX, newY, newZ)

        -- Optional: Check if the new position is reasonably clear (e.g., not inside a wall)
        -- This is a very basic check. For robust avoidance, more advanced checks are needed.
        local rayOrigin = newPosition + Vector3.new(0, 5, 0) -- Slightly above the ground
        local rayDirection = Vector3.new(0, -10, 0) -- Ray downwards
        local raycastParams = RaycastParams.new()
        raycastParams.FilterDescendantsInstances = {character} -- Ignore player's own character
        raycastParams.FilterType = Enum.RaycastFilterType.Exclude

        local raycastResult = workspace:Raycast(rayOrigin, rayDirection, raycastParams)

        -- If the ray hits something below, it's likely on solid ground or an object.
        -- If it doesn't hit anything, it might be in the air (floating effect).
        -- For "Ultra Instinct", we prioritize instant evasion, even if it means floating.
        return newPosition
    end
    -- If no "safe" spot found after attempts, just teleport a fixed distance
    return currentPosition + Vector3.new(math.random(-TELEPORT_RADIUS, TELEPORT_RADIUS), math.random(-TELEPORT_RADIUS, TELEPORT_RADIUS), math.random(-TELEPORT_RADIUS, TELEPORT_RADIUS))
end

-- Main Ultra Instinct detection and teleportation loop.
local function startInstinctLoop()
    if instinctLoop then return end -- Prevent multiple loops

    instinctLoop = RunService.Heartbeat:Connect(function(deltaTime)
        if not isInstinctActive or not humanoid or not humanoidRootPart or not humanoid.Parent then
            return -- Exit if not active or character/parts are missing
        end

        local currentTime = tick()
        if currentTime - lastTeleportTime < TELEPORT_COOLDOWN then
            return -- Respect cooldown
        end

        local playerPosition = humanoidRootPart.Position
        local threatDetected = false
        local threatInfo = "Ninguna"

        -- Get all parts within the detection radius
        local partsInRadius = workspace:GetPartsInRadius(playerPosition, DETECTION_RADIUS)

        for _, part in ipairs(partsInRadius) do
            -- Basic checks for a potentially damaging object:
            -- 1. It's a BasePart (not a model, folder, etc.)
            -- 2. It's not part of the player's character
            -- 3. It's not a character itself (to avoid teleporting from other players walking by)
            -- 4. It's either moving fast towards the player OR is currently touching the player
            if part:IsA("BasePart") and not isPartOfCharacter(part) and not part.Parent:FindFirstChildOfClass("Humanoid") then
                local relativeVelocity = part.Velocity - humanoidRootPart.Velocity
                local distance = (part.Position - playerPosition).Magnitude

                -- Check if it's moving towards the player or is very close/touching
                local isMovingTowards = relativeVelocity.Magnitude > MIN_THREAT_VELOCITY and (part.Position - playerPosition):Dot(relativeVelocity) < 0
                local isTouching = part:GetTouchingParts():FindFirst(function(p) return p == humanoidRootPart end)

                if isMovingTowards or isTouching then
                    threatDetected = true
                    threatInfo = "¡Amenaza Detectada!"
                    statusLabel.Text = threatInfo
                    statusLabel.BackgroundColor3 = UI_ACTIVE_COLOR -- Highlight status

                    -- Calculate a new safe position
                    local newPosition = findSafeTeleportLocation(playerPosition, part.Position)

                    -- Teleport the player
                    humanoidRootPart.CFrame = CFrame.new(newPosition)
                    lastTeleportTime = currentTime

                    lastTeleportInfoLabel.Text = string.format("Última Esquiva: %.2f studs", (newPosition - playerPosition).Magnitude)
                    break -- Teleport and break, we only need one threat to trigger evasion
                end
            end
        end

        if not threatDetected and statusLabel.Text ~= "Estado: Activo" then
            statusLabel.Text = "Estado: Activo" -- Reset status if no threat
            statusLabel.BackgroundColor3 = UI_ACCENT_COLOR
            lastTeleportInfoLabel.Text = "Última Esquiva: Ninguna"
        end
    end)
end

-- Function to stop the Ultra Instinct loop.
local function stopInstinctLoop()
    if instinctLoop then
        instinctLoop:Disconnect()
        instinctLoop = nil
    end
end

-- Function to reset all script states and UI when it's closed or deactivated
local function resetScriptState()
    isInstinctActive = false
    stopInstinctLoop()

    -- Reset UI elements
    statusLabel.Text = "Estado: Inactivo"
    statusLabel.BackgroundColor3 = UI_ACCENT_COLOR
    lastTeleportInfoLabel.Text = "Última Esquiva: N/A"

    if toggleButton then
        toggleButton.Text = "Activar Instinto"
        toggleButton.BackgroundColor3 = UI_INACTIVE_COLOR
    end
end

---
-- Event Handling for Buttons and Character Respawn
---

toggleButton.MouseButton1Click:Connect(function()
	isInstinctActive = not isInstinctActive
	if isInstinctActive then
		toggleButton.Text = "Desactivar Instinto"
		toggleButton.BackgroundColor3 = UI_ACTIVE_COLOR
        statusLabel.Text = "Estado: Activo"
        statusLabel.BackgroundColor3 = UI_ACTIVE_COLOR
        startInstinctLoop() -- Start the detection loop
	else
		resetScriptState() -- Use the reset function
	end
end)

closeButton.MouseButton1Click:Connect(function()
    resetScriptState() -- Reset all states
    if screenGui then
        screenGui:Destroy() -- Destroy the UI
    end
end)

-- Handle character respawns: Re-acquire references and persist state.
localPlayer.CharacterAdded:Connect(function(newCharacter)
    character = newCharacter
    humanoid = newCharacter:WaitForChild("Humanoid")
    humanoidRootPart = newCharacter:WaitForChild("HumanoidRootPart")

    -- If the instinct was active before death, restart the loop
    if isInstinctActive then
        toggleButton.Text = "Desactivar Instinto"
        toggleButton.BackgroundColor3 = UI_ACTIVE_COLOR
        statusLabel.Text = "Estado: Activo"
        statusLabel.BackgroundColor3 = UI_ACTIVE_COLOR
        startInstinctLoop() -- Restart the detection loop
    else
        -- If it was inactive, ensure everything is reset and UI reflects inactive state.
        resetScriptState()
    end
end)

-- Initial UI state setup
resetScriptState() -- Initialize UI to inactive state

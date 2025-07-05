-- Get necessary Roblox services.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

-- Get the local player, their character, and the humanoid within the character.
local localPlayer = Players.LocalPlayer
-- Wait for the character to be added initially.
local character = localPlayer.Character or localPlayer.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
local humanoidRootPart = character:WaitForChild("HumanoidRootPart") -- Get the HumanoidRootPart for CFrame manipulation

-- Configuration variables for troll speed and animation.
local MIN_TROLL_SPEED = 0.01 -- Minimum troll speed (simulates extreme slowness)
local MAX_TROLL_SPEED = 10e18 -- Maximum troll speed: 10 quintillion studs per second

local ANIMATION_SPEED_MULTIPLIER = 0.1 -- How much the animation speed scales with walk speed.

-- Store the original walk speed and animation speed for resetting.
local originalWalkSpeed = humanoid.WalkSpeed
local originalAnimationSpeed = 1 -- Default Roblox walk animation speed.

-- State variable to control if the speed boost script is active.
local isScriptActive = true

-- Variable to store the currently displayed speed for UI animation.
local currentDisplayedSpeed = 0

-- Variable to store the actual speed being applied via CFrame.
local currentAppliedTrollSpeed = 0

-- Thread references for loops, allows stopping them.
local speedChangeLoop = nil
local cframeMovementLoop = nil

---
-- UI Setup
---

local playerGui = localPlayer:WaitForChild("PlayerGui")
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "TrollSpeedControlUI"
screenGui.Parent = playerGui
screenGui.ResetOnSpawn = false -- THIS IS KEY: Prevents the UI from resetting on player death!

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 200, 0, 160) -- Increased height to accommodate new label
frame.Position = UDim2.new(0.5, -100, 0.1, 0)
frame.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
frame.BorderSizePixel = 0
frame.Parent = screenGui

-- Add UI Corner for rounded corners to the main frame
local uiCorner = Instance.new("UICorner")
uiCorner.CornerRadius = UDim.new(0, 8)
uiCorner.Parent = frame

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0.2, 0) -- Adjusted height
title.Text = "Control de Velocidad TROLL"
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.TextScaled = true
title.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
title.Font = Enum.Font.SourceSansBold
title.Parent = frame

-- Add UI Corner for rounded corners to the title
local titleUiCorner = Instance.new("UICorner")
titleUiCorner.CornerRadius = UDim.new(0, 8)
titleUiCorner.Parent = title

-- NEW: Close Button (the 'X')
local closeButton = Instance.new("TextButton")
closeButton.Size = UDim2.new(0, 24, 0, 24) -- Small square button
closeButton.Position = UDim2.new(1, -24, 0, 0) -- Top-right corner of the frame
closeButton.Text = "X"
closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
closeButton.BackgroundColor3 = Color3.fromRGB(200, 0, 0) -- Red background for close
closeButton.Font = Enum.Font.SourceSansBold
closeButton.TextSize = 18 -- Make 'X' visible
closeButton.Parent = frame

-- Add UI Corner for rounded corners to the close button
local closeButtonUiCorner = Instance.new("UICorner")
closeButtonUiCorner.CornerRadius = UDim.new(0, 4) -- Slightly smaller radius for close button
closeButtonUiCorner.Parent = closeButton

local toggleButton = Instance.new("TextButton")
toggleButton.Size = UDim2.new(0.9, 0, 0.25, 0) -- Adjusted height
toggleButton.Position = UDim2.new(0.05, 0, 0.25, 0) -- Adjusted position
toggleButton.Text = "Desactivar TROLL"
toggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
toggleButton.BackgroundColor3 = Color3.fromRGB(0, 150, 0)
toggleButton.Font = Enum.Font.SourceSansBold
toggleButton.Parent = frame

-- Add UI Corner for rounded corners to the toggle button
local toggleButtonUiCorner = Instance.new("UICorner")
toggleButtonUiCorner.CornerRadius = UDim.new(0, 6)
toggleButtonUiCorner.Parent = toggleButton

local resetButton = Instance.new("TextButton")
resetButton.Size = UDim2.new(0.9, 0, 0.25, 0) -- Adjusted height
resetButton.Position = UDim2.new(0.05, 0, 0.5, 0) -- Adjusted position
resetButton.Text = "Velocidad Normal"
resetButton.TextColor3 = Color3.fromRGB(255, 255, 255)
resetButton.BackgroundColor3 = Color3.fromRGB(150, 0, 0)
resetButton.Font = Enum.Font.SourceSansBold
resetButton.Parent = frame

-- Add UI Corner for rounded corners to the reset button
local resetButtonUiCorner = Instance.new("UICorner")
resetButtonUiCorner.CornerRadius = UDim.new(0, 6)
resetButtonUiCorner.Parent = resetButton

-- New TextLabel to display the current random speed with animation
local speedDisplayLabel = Instance.new("TextLabel")
speedDisplayLabel.Size = UDim2.new(0.9, 0, 0.25, 0)
speedDisplayLabel.Position = UDim2.new(0.05, 0, 0.75, 0) -- Positioned at the bottom
speedDisplayLabel.Text = "Velocidad Actual: N/A"
speedDisplayLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
speedDisplayLabel.TextScaled = true
speedDisplayLabel.BackgroundColor3 = Color3.fromRGB(40, 40, 40) -- Slightly darker background
speedDisplayLabel.Font = Enum.Font.SourceSansBold
speedDisplayLabel.Parent = frame

-- Add UI Corner for rounded corners to the speed display label
local speedDisplayUiCorner = Instance.new("UICorner")
speedDisplayUiCorner.CornerRadius = UDim.new(0, 6)
speedDisplayUiCorner.Parent = speedDisplayLabel

---
-- Draggable UI Functionality (Remains the same as previous version)
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
-- Troll Speed Logic - Modified for CFrame movement
---

-- Function to animate the speed display label.
local function animateSpeedDisplay(targetSpeed)
    local duration = 0.2 -- Animation duration in seconds
    local steps = 20 -- Number of updates during the animation
    local delay = duration / steps

    local startSpeed = currentDisplayedSpeed -- Start from the previously displayed speed

    for i = 1, steps do
        local progress = i / steps
        local animatedSpeed = startSpeed + (targetSpeed - startSpeed) * progress

        if speedDisplayLabel then
            if animatedSpeed >= 1e6 or animatedSpeed < 1 then
                speedDisplayLabel.Text = string.format("Velocidad Actual: %.2e", animatedSpeed)
            else
                speedDisplayLabel.Text = string.format("Velocidad Actual: %.2f", animatedSpeed)
            end
        end
        task.wait(delay)
    end
    if speedDisplayLabel then
        if targetSpeed >= 1e6 or targetSpeed < 1 then
            speedDisplayLabel.Text = string.format("Velocidad Actual: %.2e", targetSpeed)
        else
            speedDisplayLabel.Text = string.format("Velocidad Actual: %.2f", targetSpeed)
        end
    end
    currentDisplayedSpeed = targetSpeed
end

-- Function to set a random troll speed and update the UI.
local function setRandomTrollSpeed()
    if not isScriptActive or not humanoid or not humanoidRootPart then
        return
    end

    currentAppliedTrollSpeed = math.random() * (MAX_TROLL_SPEED - MIN_TROLL_SPEED) + MIN_TROLL_SPEED

    humanoid.WalkSpeed = originalWalkSpeed -- Keep original or a small value for animations

    for _, animTrack in ipairs(humanoid:GetPlayingAnimationTracks()) do
        if animTrack.Name == "WalkAnim" or animTrack.Name == "Running" then
            animTrack.Speed = originalAnimationSpeed + (currentAppliedTrollSpeed * ANIMATION_SPEED_MULTIPLIER)
            break
        end
    end

    task.spawn(animateSpeedDisplay, currentAppliedTrollSpeed)
end

-- Function to start the continuous random speed change loop.
local function startSpeedChangeLoop()
    if speedChangeLoop then return end
    speedChangeLoop = task.spawn(function()
        while isScriptActive do
            setRandomTrollSpeed()
            task.wait(5)
        end
        speedChangeLoop = nil
    end)
end

-- Function to stop the continuous random speed change loop.
local function stopSpeedChangeLoop()
    if speedChangeLoop then
        task.cancel(speedChangeLoop)
        speedChangeLoop = nil
    end
end

-- New function to handle CFrame-based movement.
local function startCFrameMovementLoop()
    if cframeMovementLoop then return end
    cframeMovementLoop = RunService.Heartbeat:Connect(function(deltaTime)
        if isScriptActive and humanoid and humanoidRootPart and humanoid.MoveDirection.Magnitude > 0 then
            local moveVector = humanoid.MoveDirection * currentAppliedTrollSpeed * deltaTime
            humanoidRootPart.CFrame = humanoidRootPart.CFrame + moveVector
        end
    end)
end

-- Function to stop CFrame-based movement.
local function stopCFrameMovementLoop()
    if cframeMovementLoop then
        cframeMovementLoop:Disconnect()
        cframeMovementLoop = nil
    end
end

-- Function to reset all script states and UI when it's closed or deactivated
local function resetScriptState()
    isScriptActive = false
    stopSpeedChangeLoop()
    stopCFrameMovementLoop()

    -- Ensure humanoid and humanoidRootPart exist before trying to reset their properties
    if humanoid then
        humanoid.WalkSpeed = originalWalkSpeed
        for _, animTrack in ipairs(humanoid:GetPlayingAnimationTracks()) do
            if animTrack.Name == "WalkAnim" or animTrack.Name == "Running" then
                animTrack.Speed = originalAnimationSpeed
                break
            end
        end
    end

    if speedDisplayLabel then
        speedDisplayLabel.Text = "Velocidad Actual: N/A"
        currentDisplayedSpeed = 0
        currentAppliedTrollSpeed = 0
    end

    -- Update toggle button text to reflect inactive state
    if toggleButton then
        toggleButton.Text = "Activar TROLL"
        toggleButton.BackgroundColor3 = Color3.fromRGB(150, 0, 0)
    end
end

---
-- Event Handling for Buttons and Character Respawn
---

toggleButton.MouseButton1Click:Connect(function()
	isScriptActive = not isScriptActive
	if isScriptActive then
		toggleButton.Text = "Desactivar TROLL"
		toggleButton.BackgroundColor3 = Color3.fromRGB(0, 150, 0)
        setRandomTrollSpeed()
        startSpeedChangeLoop()
        startCFrameMovementLoop()
	else
		resetScriptState() -- Use the new reset function
	end
end)

resetButton.MouseButton1Click:Connect(function()
	resetScriptState() -- Use the new reset function
end)

-- NEW: Close Button Click Event
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
    originalWalkSpeed = humanoid.WalkSpeed -- Re-acquire original walk speed

    -- If the script was active before death, restart the loops.
    -- The 'isScriptActive' flag itself persists because it's a script-level variable.
    if isScriptActive then
        setRandomTrollSpeed() -- Set an initial random speed immediately
        startSpeedChangeLoop() -- Restart the timed changes
        startCFrameMovementLoop() -- Restart CFrame movement
    else
        -- If it was inactive, ensure loops are stopped and UI reflects inactive state.
        resetScriptState() -- Ensure everything is reset if it was inactive
    end
end)

-- Initial UI state setup and start the loop if active
if isScriptActive then
	toggleButton.Text = "Desactivar TROLL"
	toggleButton.BackgroundColor3 = Color3.fromRGB(0, 150, 0)
    setRandomTrollSpeed() -- Set initial random speed
    startSpeedChangeLoop() -- Start the loop
    startCFrameMovementLoop() -- Start CFrame movement
else
	resetScriptState() -- Ensure initial state is correct if not active
end

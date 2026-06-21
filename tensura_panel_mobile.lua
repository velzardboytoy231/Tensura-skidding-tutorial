--// SERVICES
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

--// Anti-AFK service
local VirtualUser = game:GetService("VirtualUser")

--// REMOTES
local combatRemote = ReplicatedStorage.Remotes:WaitForChild("awaitCombat")
local prestigeRemote = ReplicatedStorage.Remotes:WaitForChild("prestiged")
local raidRemote = ReplicatedStorage.Remotes:WaitForChild("startRaid")
local evolveRemote = ReplicatedStorage.Remotes:WaitForChild("evolve")
local skipRemote = combatRemote
local dungeonRemote = ReplicatedStorage.Remotes:WaitForChild("enterDungeon")
local rollRaceRemote = ReplicatedStorage.Remotes:WaitForChild("rollRace")
local rollSpiritRemote = ReplicatedStorage.Remotes:WaitForChild("rollSpirit")

--// Player race Value
local player = Players.LocalPlayer
local raceValue = player:WaitForChild("Data"):WaitForChild("race")

-- Animated color helper
local function lerpColor3(a, b, t)
    return Color3.new(
        a.R + (b.R - a.R) * t,
        a.G + (b.G - a.G) * t,
        a.B + (b.B - a.B) * t
    )
end

--=== EP Relevant Values for Auto Evolve ===--
local function getCurrentEP()
    local success, ep = pcall(function()
        return player:FindFirstChild("Data") and player.Data:FindFirstChild("ep") and player.Data.ep.Value or nil
    end)
    return success and ep or nil
end

local function getNeededEP()
    local gui = player:FindFirstChild("PlayerGui")
    if not gui then return nil end
    local mainGui = gui:FindFirstChild("MainGui")
    if not mainGui then return nil end
    local handler = mainGui:FindFirstChild("mainHandler")
    if not handler then return nil end
    local neededEP = handler:FindFirstChild("neededEP")
    if not neededEP then return nil end
    local val = neededEP.Value
    if typeof(val) == "string" then
        val = tonumber(val)
    end
    return val
end

--// Main GRADIENT PRESETS
-- (no change here)
local gradientPresets = {
    ["Dark Blue"] = {
        {0, Color3.fromRGB(40, 60, 100)},
        {1, Color3.fromRGB(18, 26, 45)}
    },
    ["Pink Sunrise"] = {
        {0, Color3.fromRGB(250, 112, 154)},
        {1, Color3.fromRGB(168, 112, 250)}
    },
    ["Lime Mint"] = {
        {0, Color3.fromRGB(120, 255, 191)},
        {1, Color3.fromRGB(50, 205, 50)}
    },
    ["Gold Orange"] = {
        {0, Color3.fromRGB(255,180,70)},
        {1, Color3.fromRGB(220, 84, 54)}
    },
    ["Mono"] = {
        {0, Color3.fromRGB(70, 70, 70)},
        {1, Color3.fromRGB(40, 40, 40)}
    }
}

--// GUI SETUP (Horizontal & Tabbed + Fade In)
local gui = Instance.new("ScreenGui")
gui.Parent = LocalPlayer:WaitForChild("PlayerGui")
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true -- avoids the GUI shifting under mobile status bar / notch

local frame = Instance.new("Frame")
frame.Parent = gui
frame.Size = UDim2.new(0, 620, 0, 380)
frame.Position = UDim2.new(0, 20, 0, 100)
frame.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
frame.BorderSizePixel = 0
frame.Active = true
frame.ClipsDescendants = false
frame.Name = "AutoGUI"
frame.BackgroundTransparency = 1

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 18)
corner.Parent = frame

--// ANIMATED LIGHT GRADIENT BORDER
local borderThickness = 4
local borderFrame = Instance.new("Frame")
borderFrame.Name = "AnimatedBorder"
borderFrame.Parent = frame.Parent
borderFrame.Size = frame.Size + UDim2.new(0, borderThickness*2, 0, borderThickness*2)
borderFrame.Position = frame.Position - UDim2.new(0, borderThickness, 0, borderThickness)
borderFrame.BackgroundTransparency = 1
borderFrame.ZIndex = frame.ZIndex or 1
borderFrame.Active = false
borderFrame.ClipsDescendants = true

local borderCorner = Instance.new("UICorner")
borderCorner.CornerRadius = UDim.new(0, 18 + borderThickness)
borderCorner.Parent = borderFrame

local borderStroke = Instance.new("UIStroke")
borderStroke.Thickness = borderThickness
borderStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
borderStroke.Color = Color3.fromRGB(255,255,255)
borderStroke.Transparency = 0.5
borderStroke.Parent = borderFrame

local function createAnimatedBorderGradient(presetName)
    local preset = gradientPresets[presetName] or gradientPresets["Mono"]
    local keypoints = {}
    for _, data in ipairs(preset) do
        table.insert(keypoints, ColorSequenceKeypoint.new(data[1], data[2]))
    end
    local grad = Instance.new("UIGradient")
    grad.Color = ColorSequence.new(keypoints)
    grad.Rotation = 0
    grad.Offset = Vector2.new(0, 0)
    grad.Parent = borderStroke
    return grad
end

local borderGradient = createAnimatedBorderGradient("Mono")

local function syncBorderToFrame()
    borderFrame.Size = frame.Size + UDim2.new(0, borderThickness*2, 0, borderThickness*2)
    borderFrame.Position = frame.Position - UDim2.new(0, borderThickness, 0, borderThickness)
end

frame:GetPropertyChangedSignal("Size"):Connect(syncBorderToFrame)
frame:GetPropertyChangedSignal("Position"):Connect(syncBorderToFrame)

-- Return UIGradient AND its preset keypoints (so we can animate colors)
local function createAnimatedGradientFromPreset(presetName, rotation)
    local preset = gradientPresets[presetName] or gradientPresets["Mono"]
    local keypoints = {}
    for _, data in ipairs(preset) do
        table.insert(keypoints, ColorSequenceKeypoint.new(data[1], data[2]))
    end
    local grad = Instance.new("UIGradient")
    grad.Color = ColorSequence.new(keypoints)
    grad.Rotation = rotation or 45
    return grad, preset
end

local selectedGradientPreset = "Mono"
local mainGradient, mainPreset = createAnimatedGradientFromPreset(selectedGradientPreset, 45)
mainGradient.Parent = frame

--// Top bar for dragging + gradient
local topBar = Instance.new("Frame")
topBar.Parent = frame
topBar.Size = UDim2.new(1, 0, 0, 40)
topBar.Position = UDim2.new(0, 0, 0, 0)
topBar.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
topBar.BorderSizePixel = 0
topBar.Name = "TopBar"
topBar.Active = true -- ensures touch input is captured on mobile

local topBarCorner = Instance.new("UICorner", topBar)
topBarCorner.CornerRadius = UDim.new(0, 18)

local topGradient, topPreset = createAnimatedGradientFromPreset(selectedGradientPreset, 45)
topGradient.Parent = topBar

local title = Instance.new("TextLabel")
title.Parent = topBar
title.Size = UDim2.new(1, 0, 1, 0)
title.Position = UDim2.new(0, 0, 0, 0)
title.BackgroundTransparency = 1
title.Text = "Tensura Panel"
title.Font = Enum.Font.GothamBold
title.TextSize = 22
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.TextStrokeTransparency = 0.7
title.TextXAlignment = Enum.TextXAlignment.Center
title.TextYAlignment = Enum.TextYAlignment.Center

-- Drag logic (mouse + touch, with screen-bounds clamping for mobile)
local UIS = game:GetService("UserInputService")
local dragging = false
local dragStart
local startPos
local dragInput
local activeDragInput -- the specific InputObject (mouse or finger) we're tracking

local function clampFramePosition(newPos)
    local viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(800, 600)
    local absSize = frame.AbsoluteSize
    local minX, minY = 0, 0
    local maxX = math.max(minX, viewport.X - absSize.X)
    local maxY = math.max(minY, viewport.Y - absSize.Y)
    local x = math.clamp(newPos.X.Offset, minX, maxX)
    local y = math.clamp(newPos.Y.Offset, minY, maxY)
    return UDim2.new(newPos.X.Scale, x, newPos.Y.Scale, y)
end

local function updateDrag(input)
    local delta = input.Position - dragStart
    local newPos = UDim2.new(
        startPos.X.Scale, startPos.X.Offset + delta.X,
        startPos.Y.Scale, startPos.Y.Offset + delta.Y
    )
    frame.Position = clampFramePosition(newPos)
end

topBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        activeDragInput = input
        dragStart = input.Position
        startPos = frame.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
                if activeDragInput == input then
                    activeDragInput = nil
                end
            end
        end)
    end
end)

topBar.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch then
        dragInput = input
    end
end)

UIS.InputChanged:Connect(function(input)
    if dragging and activeDragInput == input then
        updateDrag(input)
    elseif dragging and input == dragInput then
        -- fallback path for movement events captured outside topBar's own InputChanged
        updateDrag(input)
    end
end)

UIS.InputEnded:Connect(function(input)
    if input == activeDragInput then
        dragging = false
        activeDragInput = nil
    end
end)

frame:GetPropertyChangedSignal("Position"):Connect(syncBorderToFrame)

local tabPanel = Instance.new("Frame")
tabPanel.Name = "TabPanel"
tabPanel.Parent = frame
tabPanel.Size = UDim2.new(0, 120, 1, -40)
tabPanel.Position = UDim2.new(0, 0, 0, 40)
tabPanel.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
tabPanel.BorderSizePixel = 0

local tabCorner = Instance.new("UICorner", tabPanel)
tabCorner.CornerRadius = UDim.new(0, 18)

local tabGradient, tabPreset = createAnimatedGradientFromPreset(selectedGradientPreset, 45)
tabGradient.Parent = tabPanel

-- Move Spirits above Settings tab
local tabs = { "Combat", "Player", "Raids", "Dungeon", "Spirits", "Settings" }
local tabButtons = {}
local tabContainers = {}
local selectedTab = "Combat"

local function createTabContent(name)
    local container = Instance.new("Frame")
    container.Name = "Content_" .. name
    container.Parent = frame
    container.Size = UDim2.new(1, -130, 1, -50)
    container.Position = UDim2.new(0, 125, 0, 45)
    container.BackgroundTransparency = 1
    container.Visible = name == "Combat"

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 18)
    corner.Parent = container

    tabContainers[name] = container
    return container
end

for _, tabName in ipairs(tabs) do
    createTabContent(tabName)
end

for i, tabName in ipairs(tabs) do
    local button = Instance.new("TextButton")
    button.Name = tabName.."Tab"
    button.Parent = tabPanel
    button.Size = UDim2.new(1, -10, 0, 36)
    button.Position = UDim2.new(0, 5, 0, (i-1)*42 + 5)
    button.BackgroundColor3 = tabName=="Combat" and Color3.fromRGB(60,100,160) or Color3.fromRGB(60,60,60)
    button.Text = tabName
    button.Font = Enum.Font.GothamSemibold
    button.TextColor3 = Color3.fromRGB(220,220,230)
    button.TextSize = 16
    button.BorderSizePixel = 0

    local btnCorner = Instance.new("UICorner", button)
    btnCorner.CornerRadius = UDim.new(0, 18)

    button.MouseButton1Click:Connect(function()
        for _, b in pairs(tabButtons) do
            b.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
        end
        button.BackgroundColor3 = Color3.fromRGB(60,100,160)
        selectedTab = tabName
        for t, container in pairs(tabContainers) do
            container.Visible = (t == tabName)
        end
    end)
    table.insert(tabButtons, button)
end

local function setGUIGradientPreset(newPreset)
    selectedGradientPreset = newPreset
    local newMain, newMainPreset = createAnimatedGradientFromPreset(newPreset, 45)
    local newTop, newTopPreset = createAnimatedGradientFromPreset(newPreset, 45)
    local newTab, newTabPreset = createAnimatedGradientFromPreset(newPreset, 45)
    mainGradient.Color = newMain.Color
    topGradient.Color = newTop.Color
    tabGradient.Color = newTab.Color
    mainPreset = gradientPresets[newPreset]
    topPreset = gradientPresets[newPreset]
    tabPreset = gradientPresets[newPreset]
    local preset = gradientPresets[newPreset] or gradientPresets["Mono"]
    local keypoints = {}
    for _, data in ipairs(preset) do
        table.insert(keypoints, ColorSequenceKeypoint.new(data[1], data[2]))
    end
    borderGradient.Color = ColorSequence.new(keypoints)
end

-- (no change in createToggle, createDropdown etc.)

local function createToggle(name, yPos, parent)
    local toggle = Instance.new("TextButton")
    toggle.Parent = parent
    toggle.Size = UDim2.new(0, 260, 0, 32)
    toggle.Position = UDim2.new(0, 10, 0, yPos)
    toggle.BackgroundColor3 = Color3.fromRGB(150, 50, 50)
    toggle.TextColor3 = Color3.fromRGB(255, 255, 255)
    toggle.Font = Enum.Font.SourceSans
    toggle.TextSize = 16
    toggle.Text = name .. ": OFF"
    toggle.BorderSizePixel = 0
    local enabled = false

    local corner = Instance.new("UICorner", toggle)
    corner.CornerRadius = UDim.new(0, 18)

    toggle.MouseButton1Click:Connect(function()
        enabled = not enabled
        toggle.Text = name .. (enabled and ": ON" or ": OFF")
        toggle.BackgroundColor3 = enabled and Color3.fromRGB(50, 150, 50) or Color3.fromRGB(150, 50, 50)
    end)
    return function() return enabled end, toggle
end

local openDropdowns = {}

local function createDropdown(name, options, yPos, parent)
    local dropdown = Instance.new("TextButton")
    dropdown.Parent = parent
    dropdown.Size = UDim2.new(0, 260, 0, 32)
    dropdown.Position = UDim2.new(0, 10, 0, yPos)
    dropdown.BackgroundColor3 = Color3.fromRGB(60,60,60)
    dropdown.TextColor3 = Color3.fromRGB(255, 255, 255)
    dropdown.Font = Enum.Font.SourceSans
    dropdown.TextSize = 16
    dropdown.Text = name .. ": " .. options[1]
    dropdown.ZIndex = 2
    dropdown.BorderSizePixel = 0

    local corner = Instance.new("UICorner", dropdown)
    corner.CornerRadius = UDim.new(0, 18)

    local selected = options[1]
    local open = false

    local container = Instance.new("Frame")
    container.Parent = parent
    container.Size = UDim2.new(0, 260, 0, math.min(#options * 25, 150))
    container.Position = UDim2.new(0, 10, 0, yPos + 32)
    container.BackgroundTransparency = 1
    container.ClipsDescendants = true

    local conCorner = Instance.new("UICorner")
    conCorner.CornerRadius = UDim.new(0, 18)
    conCorner.Parent = container

    local scrollFrame = Instance.new("ScrollingFrame")
    scrollFrame.Parent = container
    scrollFrame.Size = UDim2.new(1, 0, 1, 0)
    scrollFrame.CanvasSize = UDim2.new(0, 0, 0, #options * 25)
    scrollFrame.ScrollBarThickness = 6
    scrollFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    scrollFrame.Visible = false
    scrollFrame.ZIndex = 3
    scrollFrame.BorderSizePixel = 0

    local scrollCorner = Instance.new("UICorner", scrollFrame)
    scrollCorner.CornerRadius = UDim.new(0, 18)

    table.insert(openDropdowns, scrollFrame)

    local uiListLayout = Instance.new("UIListLayout")
    uiListLayout.Parent = scrollFrame

    for _, option in ipairs(options) do
        local optBtn = Instance.new("TextButton")
        optBtn.Parent = scrollFrame
        optBtn.Size = UDim2.new(1, 0, 0, 25)
        optBtn.Text = option
        optBtn.BackgroundColor3 = Color3.fromRGB(60,60,60)
        optBtn.TextColor3 = Color3.fromRGB(255,255,255)
        optBtn.Font = Enum.Font.SourceSans
        optBtn.TextSize = 14
        optBtn.ZIndex = 4
        optBtn.BorderSizePixel = 0

        local btnCorner = Instance.new("UICorner", optBtn)
        btnCorner.CornerRadius = UDim.new(0, 18)

        optBtn.MouseButton1Click:Connect(function()
            selected = option
            dropdown.Text = name .. ": " .. selected
            scrollFrame.Visible = false
            open = false
        end)
    end

    dropdown.MouseButton1Click:Connect(function()
        open = not open

        for _, v in ipairs(openDropdowns) do
            v.Visible = false
        end

        scrollFrame.Visible = open

        if open then
            dropdown.ZIndex = 99
            scrollFrame.ZIndex = 100
            for _, child in ipairs(scrollFrame:GetChildren()) do
                if child:IsA("TextButton") then
                    child.ZIndex = 101
                end
            end
        end
    end)

    return function() return selected end
end

--=== TAB CONTENTS ===--
-- (no change for content initialization, only gradients were changed above)
local combatTab = tabContainers["Combat"]
local combatEnabled = createToggle("Auto Combat", 10, combatTab)
local skipEnabled = createToggle("Auto Skip Turn", 52, combatTab)

local combatTypeOptions = {"Cycle", "Single", "Prefer Skill"}
local function getYForNextCombatControl()
    local ys = {10, 52}
    for _, child in ipairs(combatTab:GetChildren()) do
        if child:IsA("GuiObject") then
            table.insert(ys, child.Position and child.Position.Y.Offset or 0)
        end
    end
    local maxY = 0
    for _, y in ipairs(ys) do if y > maxY then maxY = y end end
    return maxY + 42
end
local combatTypeDropdown = createDropdown("Combat Type", combatTypeOptions, 94, combatTab)

local skillSelect = createDropdown("Select Skill", {
    "1","2","3","4","5","6","7","8"
}, 136, combatTab)

local playerTab = tabContainers["Player"]
local prestigeEnabled = createToggle("Auto Prestige", 10, playerTab)
local evolveEnabled = createToggle("Auto Evolve", 52, playerTab)
local autoRaceEnabled, autoRaceToggle = createToggle("Auto Race", 94, playerTab)

local races = {
    "Human", "Dragon Hatchling", "Lesser Daemon", "Ogre", "Orc", "Goblin", "Slime", "Beastfolk", "Elf", "Wight"
}
local raceDropdown = createDropdown("Auto Race Target", races, 136, playerTab)

local ROLL_DELAY = 0.001

local lastTargetRace = nil
local awaitingTargetAchieved = false

task.spawn(function()
    while true do
        if autoRaceEnabled() then
            local TARGET_RACE = raceDropdown()
            if lastTargetRace ~= TARGET_RACE or not awaitingTargetAchieved then
                lastTargetRace = TARGET_RACE
                awaitingTargetAchieved = true
            end

            if tostring(raceValue.Value) ~= tostring(TARGET_RACE) and awaitingTargetAchieved then
                print("Starting auto-roll for:", TARGET_RACE)
                while autoRaceEnabled() and tostring(raceValue.Value) ~= tostring(TARGET_RACE) and lastTargetRace == TARGET_RACE and awaitingTargetAchieved do
                    local success, result = pcall(function()
                        return rollRaceRemote:InvokeServer()
                    end)
                    if success then
                        print("Rolled:", raceValue.Value)
                    else
                        warn("Roll failed:", result)
                    end
                    task.wait(ROLL_DELAY)
                end
                if tostring(raceValue.Value) == tostring(TARGET_RACE) then
                    print("🎉 Target race found:", TARGET_RACE)
                    awaitingTargetAchieved = false
                end
            end
        else
            awaitingTargetAchieved = false
            lastTargetRace = nil
        end
        task.wait(0.1)
    end
end)

local spiritsTab = tabContainers["Spirits"]
local spiritNames = {"Lesser Dark", "Lesser Water", "Greater Water", "Greater Dark", "Greater Earth", "Greater Fire", "Greater Holy", "NONE"}
local spiritSlots = {"1", "2", "3", "4"}
local autoSpiritRollEnabled, autoSpiritRollToggle = createToggle("Auto Roll Spirit", 10, spiritsTab)
local spiritTargetDropdown = createDropdown("Target Spirit", spiritNames, 52, spiritsTab)
local spiritSlotDropdown = createDropdown("Spirit Slot", spiritSlots, 94, spiritsTab)

local lastSpiritTarget = nil
local lastSpiritSlot = nil
local awaitingSpiritTarget = false

local function getOwnedSpirits()
    local data = player:FindFirstChild("Data")
    if not data then return {} end
    local spirits = data:FindFirstChild("spirits2")
    if spirits and spirits.Value ~= "" then
        local success, decoded = pcall(function() return game:GetService("HttpService"):JSONDecode(spirits.Value) end)
        if success and type(decoded) == "table" then
            return decoded
        end
    end
    return {}
end

task.spawn(function()
    while true do
        if autoSpiritRollEnabled() then
            local targetSpirit = spiritTargetDropdown()
            local targetSlot = tonumber(spiritSlotDropdown())
            if typeof(targetSlot) ~= "number" or targetSlot < 1 or targetSlot > 4 then
                task.wait(0.2)
                continue
            end
            local ownedSpirits = getOwnedSpirits()
            local currentSpirit = ownedSpirits[targetSlot]

            if lastSpiritTarget ~= targetSpirit or lastSpiritSlot ~= targetSlot or not awaitingSpiritTarget then
                lastSpiritTarget = targetSpirit
                lastSpiritSlot = targetSlot
                awaitingSpiritTarget = true
            end

            if currentSpirit ~= targetSpirit and awaitingSpiritTarget then
                print(string.format("Starting auto-roll for spirit '%s' in slot %d", targetSpirit, targetSlot))
                while autoSpiritRollEnabled() and spiritTargetDropdown() == targetSpirit and tostring(spiritSlotDropdown()) == tostring(targetSlot) and awaitingSpiritTarget do
                    ownedSpirits = getOwnedSpirits()
                    currentSpirit = ownedSpirits[targetSlot]
                    if currentSpirit == targetSpirit then
                        print(string.format("🎉 Target spirit '%s' acquired in slot %d!", targetSpirit, targetSlot))
                        awaitingSpiritTarget = false
                        break
                    end
                    local success, result = pcall(function()
                        return rollSpiritRemote:InvokeServer(targetSlot)
                    end)
                    if success then
                        print("Spirit roll result for slot", targetSlot, ":", tostring(result))
                    else
                        warn("Spirit roll failed:", result)
                    end
                    task.wait(0.3)
                end
            elseif currentSpirit == targetSpirit then
                awaitingSpiritTarget = false
            end
        else
            awaitingSpiritTarget = false
            lastSpiritTarget = nil
            lastSpiritSlot = nil
        end
        task.wait(0.15)
    end
end)

local raidTab = tabContainers["Raids"]
local dungeonTab = tabContainers["Dungeon"]
local settingsTab = tabContainers["Settings"]

local raidEnabled = createToggle("Auto Raid", 10, raidTab)
local raidSelection = createDropdown("Select Raid", {
    "Direwolf Pack Attack",
    "Kingdom of Falmuth Battle",
    "Charybdis Descent",
    "Hinata Sakaguchi Encounter",
    "Scorch Dragon Velgrynd"
}, 52, raidTab)
local dungeonEnabled = createToggle("Auto Dungeon", 10, dungeonTab)

local colorPresetsList = {}
for name, _ in pairs(gradientPresets) do
    table.insert(colorPresetsList, name)
end
local colorDropdown = createDropdown("Color", colorPresetsList, 10, settingsTab)
local antiAFKEnabled, antiAFKToggle = createToggle("Anti-AFK", 52, settingsTab)
local antiAFKConnection

task.spawn(function()
    local lastPreset = selectedGradientPreset
    while true do
        local preset = colorDropdown()
        if preset ~= lastPreset then
            setGUIGradientPreset(preset)
            lastPreset = preset
        end
        task.wait(0.1)
    end
end)

task.spawn(function()
    local wasEnabled = false
    while true do
        local enabled = antiAFKEnabled()
        if enabled and not wasEnabled then
            if antiAFKConnection then
                antiAFKConnection:Disconnect()
                antiAFKConnection = nil
            end
            antiAFKConnection = player.Idled:Connect(function()
                VirtualUser:Button2Down(Vector2.new(0,0), workspace.CurrentCamera and workspace.CurrentCamera.CFrame or CFrame.new())
                wait(1)
                VirtualUser:Button2Up(Vector2.new(0,0), workspace.CurrentCamera and workspace.CurrentCamera.CFrame or CFrame.new())
            end)
            wasEnabled = true
        elseif not enabled and wasEnabled then
            if antiAFKConnection then
                antiAFKConnection:Disconnect()
                antiAFKConnection = nil
            end
            wasEnabled = false
        end
        task.wait(0.2)
    end
end)

-- Everything else below is the same as before

local combatType = "Cycle"
local selectedSkill = 1
local skillOrder = {8,7,6,5,4,3,2,1}
local index = 1

local preferredSkillTryPreferred = true
local preferSkillState = {step = 1, cycleIndex = 1}

combatRemote.OnClientInvoke = function(...)
    if combatEnabled() then
        combatType = combatTypeDropdown()
        selectedSkill = tonumber(skillSelect())
        if combatType == "Cycle" then
            local skill = skillOrder[index]
            index = index + 1
            if index > #skillOrder then index = 1 end
            return skill
        elseif combatType == "Single" then
            return selectedSkill
        elseif combatType == "Prefer Skill" then
            if preferSkillState.step == 1 then
                preferSkillState.lastTried = "preferred"
                preferSkillState.step = 2
                return selectedSkill
            else
                local skill = skillOrder[preferSkillState.cycleIndex]
                if skill == selectedSkill then
                    preferSkillState.cycleIndex = preferSkillState.cycleIndex + 1
                    if preferSkillState.cycleIndex > #skillOrder then
                        preferSkillState.cycleIndex = 1
                    end
                    skill = skillOrder[preferSkillState.cycleIndex]
                end
                preferSkillState.cycleIndex = preferSkillState.cycleIndex + 1
                if preferSkillState.cycleIndex > #skillOrder then
                    preferSkillState.cycleIndex = 1
                end
                preferSkillState.lastTried = "cycle"
                preferSkillState.step = 1
                return skill
            end
        end
    elseif skipEnabled() then
        return "skipturn"
    else
        return nil
    end
end

task.spawn(function()
    local lastCombatType, lastEnabled, lastSkill
    while true do
        local curType = combatTypeDropdown()
        local enabled = combatEnabled()
        local skill = tonumber(skillSelect())
        if curType ~= lastCombatType or enabled ~= lastEnabled or skill ~= lastSkill then
            preferSkillState.step = 1
            preferSkillState.cycleIndex = 1
            lastCombatType = curType
            lastEnabled = enabled
            lastSkill = skill
        end
        if curType ~= "Cycle" then
            index = 1
        end
        task.wait(0.05)
    end
end)

--// Coordination between Auto Prestige and Auto Raid
-- Previously, Auto Prestige fired prestigeRemote:InvokeServer() once per
-- FRAME (task.wait() with no args), and Auto Raid fired on its own
-- independent 2s timer with zero awareness of it. A raid could get queued
-- at the exact moment a prestige attempt landed server-side, stepping on
-- the reset and making prestige farming inconsistent. Fix: throttle the
-- prestige attempt rate to something sane, and give raids a short
-- cooldown window right after every prestige attempt so the server has
-- time to fully process it before the next raid is allowed to start.
local PRESTIGE_RETRY_DELAY = 0.5   -- seconds between prestige attempts (was every frame)
local PRESTIGE_RAID_COOLDOWN = 1.5 -- seconds raids are held off after a prestige attempt
local raidsPausedUntil = 0

task.spawn(function()
    while true do
        if prestigeEnabled() then
            local ok, result = pcall(function()
                return prestigeRemote:InvokeServer()
            end)
            if ok then
                if result then
                    print("✅ Prestige attempt returned:", result)
                end
                -- Pause raids regardless of the return value, since we don't
                -- know this game's exact success signal for the remote.
                -- This still guarantees raids never overlap a prestige call.
                raidsPausedUntil = os.clock() + PRESTIGE_RAID_COOLDOWN
            else
                warn("Prestige call failed:", result)
            end
            task.wait(PRESTIGE_RETRY_DELAY)
        else
            task.wait(0.2)
        end
    end
end)

task.spawn(function()
    while true do
        if evolveEnabled() then
            local curEP = getCurrentEP()
            local needEP = getNeededEP()
            if curEP and needEP and type(curEP) == "number" and type(needEP) == "number" then
                if curEP > needEP then
                    pcall(function()
                        evolveRemote:FireServer()
                    end)
                end
            end
        end
        task.wait(0.5) -- was firing every single frame; no reason to poll that fast
    end
end)

task.spawn(function()
    while true do
        if raidEnabled() then
            if os.clock() >= raidsPausedUntil then
                pcall(function()
                    raidRemote:InvokeServer(raidSelection())
                end)
            end
        end
        task.wait(2)
    end
end)

task.spawn(function()
    while true do
        if dungeonEnabled() then
            pcall(function()
                dungeonRemote:InvokeServer()
            end)
        end
        task.wait(3)
    end
end)

task.spawn(function()
    local tr = 1
    local fadeStep = 0.012
    while tr > 0 do
        tr = math.max(0, tr - fadeStep)
        frame.BackgroundTransparency = tr
        topBar.BackgroundTransparency = tr * 0.5
        tabPanel.BackgroundTransparency = tr * 0.5
        borderStroke.Transparency = 0.5 + tr*0.5
        task.wait(0.03)
    end
    frame.BackgroundTransparency = 0
    topBar.BackgroundTransparency = 0
    tabPanel.BackgroundTransparency = 0
    borderStroke.Transparency = 0.5
end)

-- Animation loop for gradients!
task.spawn(function()
    local t = 0
    while true do
        t += 0.015
        -- Animate gradient colors in a subtle way for mainGradient/topGradient/tabGradient
        local function shiftPresetColors(preset, speed, phase)
            local keypoints = {}
            for i, data in ipairs(preset) do
                local p = (t*speed + (phase or 0) + i*0.8)%1
                local offset = 0.08*math.sin(2*math.pi*p)
                table.insert(keypoints, ColorSequenceKeypoint.new(
                    data[1],
                    lerpColor3(data[2], Color3.fromRGB(
                        math.floor(data[2].R*255 + 18*offset),
                        math.floor(data[2].G*255 + 18*offset),
                        math.floor(data[2].B*255 + 18*offset)
                    ), 0.5 + 0.5*math.sin(t*speed + i+phase))
                ))
            end
            return ColorSequence.new(keypoints)
        end

        if mainGradient and mainPreset then
            mainGradient.Color = shiftPresetColors(mainPreset, 0.5, 0)
        end
        if topGradient and topPreset then
            topGradient.Color = shiftPresetColors(topPreset, 0.65, 0.2)
        end
        if tabGradient and tabPreset then
            tabGradient.Color = shiftPresetColors(tabPreset, 0.8, 0.45)
        end

        borderGradient.Offset = Vector2.new(math.sin(t)*0.35, math.cos(t*0.73)*0.35)
        borderStroke.Transparency = 0.35 + math.abs(math.sin(t*1.1))*0.16
        task.wait(0.025)
    end
end)

--// SERVICES
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")

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

-- Drag logic (mouse + touch, so it works on mobile)
local UIS = game:GetService("UserInputService")
local dragging = false
local dragStart
local startPos
local dragInput

topBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = frame.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end)
topBar.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        dragInput = input
    end
end)
UIS.InputChanged:Connect(function(input)
    if input == dragInput and dragging then
        local delta = input.Position - dragStart
        frame.Position = UDim2.new(
            startPos.X.Scale, startPos.X.Offset + delta.X,
            startPos.Y.Scale, startPos.Y.Offset + delta.Y
        )
    end
end)

frame:GetPropertyChangedSignal("Position"):Connect(syncBorderToFrame)

--// MOBILE SHOW/HIDE TOGGLE
local toggleButton = Instance.new("TextButton")
toggleButton.Name = "ToggleGUIButton"
toggleButton.Parent = gui
toggleButton.Size = UDim2.new(0, 46, 0, 46)
toggleButton.Position = UDim2.new(0, 10, 0, 10)
toggleButton.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
toggleButton.BackgroundTransparency = 0.1
toggleButton.Text = "✕"
toggleButton.Font = Enum.Font.GothamBold
toggleButton.TextSize = 22
toggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
toggleButton.BorderSizePixel = 0
toggleButton.ZIndex = 1000
toggleButton.AutoButtonColor = false
toggleButton.Active = true

local toggleCorner = Instance.new("UICorner")
toggleCorner.CornerRadius = UDim.new(1, 0)
toggleCorner.Parent = toggleButton

local toggleStroke = Instance.new("UIStroke")
toggleStroke.Thickness = 2
toggleStroke.Color = Color3.fromRGB(255, 255, 255)
toggleStroke.Transparency = 0.6
toggleStroke.Parent = toggleButton

local guiVisible = true
local function setGUIVisible(visible)
    guiVisible = visible
    frame.Visible = visible
    borderFrame.Visible = visible
    toggleButton.Text = visible and "✕" or "≡"
end

local toggleDragging = false
local toggleDragStart, toggleStartPos, toggleDragInput
local toggleMoved = false

toggleButton.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        toggleDragging = true
        toggleMoved = false
        toggleDragStart = input.Position
        toggleStartPos = toggleButton.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                toggleDragging = false
            end
        end)
    end
end)
toggleButton.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        toggleDragInput = input
    end
end)
UIS.InputChanged:Connect(function(input)
    if input == toggleDragInput and toggleDragging then
        local delta = input.Position - toggleDragStart
        if delta.Magnitude > 4 then
            toggleMoved = true
        end
        toggleButton.Position = UDim2.new(
            toggleStartPos.X.Scale, toggleStartPos.X.Offset + delta.X,
            toggleStartPos.Y.Scale, toggleStartPos.Y.Offset + delta.Y
        )
    end
end)

toggleButton.MouseButton1Click:Connect(function()
    if not toggleMoved then
        setGUIVisible(not guiVisible)
    end
end)

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

local function createToggle(name, yPos, parent, default)
    local toggle = Instance.new("TextButton")
    toggle.Parent = parent
    toggle.Size = UDim2.new(0, 260, 0, 32)
    toggle.Position = UDim2.new(0, 10, 0, yPos)
    toggle.TextColor3 = Color3.fromRGB(255, 255, 255)
    toggle.Font = Enum.Font.SourceSans
    toggle.TextSize = 16
    toggle.BorderSizePixel = 0
    local enabled = default and true or false
    toggle.Text = name .. (enabled and ": ON" or ": OFF")
    toggle.BackgroundColor3 = enabled and Color3.fromRGB(50, 150, 50) or Color3.fromRGB(150, 50, 50)

    local corner = Instance.new("UICorner", toggle)
    corner.CornerRadius = UDim.new(0, 18)

    local function setEnabled(state)
        enabled = state and true or false
        toggle.Text = name .. (enabled and ": ON" or ": OFF")
        toggle.BackgroundColor3 = enabled and Color3.fromRGB(50, 150, 50) or Color3.fromRGB(150, 50, 50)
    end

    toggle.MouseButton1Click:Connect(function()
        setEnabled(not enabled)
    end)
    return function() return enabled end, toggle, setEnabled
end

local openDropdowns = {}

local function createDropdown(name, options, yPos, parent, default)
    local dropdown = Instance.new("TextButton")
    dropdown.Parent = parent
    dropdown.Size = UDim2.new(0, 260, 0, 32)
    dropdown.Position = UDim2.new(0, 10, 0, yPos)
    dropdown.BackgroundColor3 = Color3.fromRGB(60,60,60)
    dropdown.TextColor3 = Color3.fromRGB(255, 255, 255)
    dropdown.Font = Enum.Font.SourceSans
    dropdown.TextSize = 16
    dropdown.ZIndex = 2
    dropdown.BorderSizePixel = 0

    local corner = Instance.new("UICorner", dropdown)
    corner.CornerRadius = UDim.new(0, 18)

    local selected = default or options[1]
    dropdown.Text = name .. ": " .. tostring(selected)
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

    local function setSelected(value)
        for _, option in ipairs(options) do
            if tostring(option) == tostring(value) then
                selected = option
                dropdown.Text = name .. ": " .. tostring(selected)
                return true
            end
        end
        return false
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

    return function() return selected end, setSelected
end

--=== TAB CONTENTS ===--
local combatTab = tabContainers["Combat"]
local combatEnabled, _, setCombatEnabled = createToggle("Auto Combat", 10, combatTab)
local skipEnabled, _, setSkipEnabled = createToggle("Auto Skip Turn", 52, combatTab)

local combatTypeOptions = {"Cycle", "Single", "Prefer Skill"}
local combatTypeDropdown, setCombatType = createDropdown("Combat Type", combatTypeOptions, 94, combatTab)

local skillSelect, setSkillSelect = createDropdown("Select Skill", {
    "1","2","3","4","5","6","7","8"
}, 136, combatTab)

local playerTab = tabContainers["Player"]
local prestigeEnabled, _, setPrestigeEnabled = createToggle("Auto Prestige", 10, playerTab)
local evolveEnabled, _, setEvolveEnabled = createToggle("Auto Evolve", 52, playerTab)
local autoRaceEnabled, autoRaceToggle, setAutoRaceEnabled = createToggle("Auto Race", 94, playerTab)

local races = {
    "Human", "Dragon Hatchling", "Lesser Daemon", "Ogre", "Orc", "Goblin", "Slime", "Beastfolk", "Elf", "Wight"
}
local raceDropdown, setRaceDropdown = createDropdown("Auto Race Target", races, 136, playerTab)

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
local autoSpiritRollEnabled, autoSpiritRollToggle, setAutoSpiritRollEnabled = createToggle("Auto Roll Spirit", 10, spiritsTab)
local spiritTargetDropdown, setSpiritTarget = createDropdown("Target Spirit", spiritNames, 52, spiritsTab)
local spiritSlotDropdown, setSpiritSlot = createDropdown("Spirit Slot", spiritSlots, 94, spiritsTab)

local lastSpiritTarget = nil
local lastSpiritSlot = nil
local awaitingSpiritTarget = false

local function getOwnedSpirits()
    local data = player:FindFirstChild("Data")
    if not data then return {} end
    local spirits = data:FindFirstChild("spirits2")
    if spirits and spirits.Value ~= "" then
        local success, decoded = pcall(function() return HttpService:JSONDecode(spirits.Value) end)
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

local raidEnabled, _, setRaidEnabled = createToggle("Auto Raid", 10, raidTab)
local raidSelection, setRaidSelection = createDropdown("Select Raid", {
    "Direwolf Pack Attack",
    "Kingdom of Falmuth Battle",
    "Charybdis Descent",
    "Hinata Sakaguchi Encounter",
    "Scorch Dragon Velgrynd"
}, 52, raidTab)
local dungeonEnabled, _, setDungeonEnabled = createToggle("Auto Dungeon", 10, dungeonTab)

local colorPresetsList = {}
for name, _ in pairs(gradientPresets) do
    table.insert(colorPresetsList, name)
end
local colorDropdown, setColorDropdown = createDropdown("Color", colorPresetsList, 10, settingsTab)
local antiAFKEnabled, antiAFKToggle, setAntiAFKEnabled = createToggle("Anti-AFK", 52, settingsTab)
local antiSpamEnabled, antiSpamToggle, setAntiSpamEnabled = createToggle("Anti-Spam (Lag Fix)", 94, settingsTab)
local autoClaimEnabled, autoClaimToggle, setAutoClaimEnabled = createToggle("Auto Claim Rewards", 136, settingsTab)

--=====================================================--
--===              AUTO REJOIN SYSTEM               ===--
--=====================================================--
-- Placed above Settings buttons so they sit at y=178 area cleanly.

local autoRejoinEnabled, autoRejoinToggle, setAutoRejoinEnabled = createToggle("Auto Rejoin", 178, settingsTab)

-- Status label for rejoin (sits just below the toggle)
local rejoinStatusLabel = Instance.new("TextLabel")
rejoinStatusLabel.Parent = settingsTab
rejoinStatusLabel.Size = UDim2.new(0, 260, 0, 18)
rejoinStatusLabel.Position = UDim2.new(0, 10, 0, 214)
rejoinStatusLabel.BackgroundTransparency = 1
rejoinStatusLabel.Font = Enum.Font.SourceSans
rejoinStatusLabel.TextSize = 13
rejoinStatusLabel.TextColor3 = Color3.fromRGB(160, 210, 160)
rejoinStatusLabel.TextXAlignment = Enum.TextXAlignment.Left
rejoinStatusLabel.Text = "Rejoin: idle"

-- Capture the private server link code at script start (if one exists).
-- Roblox stores it in game.PrivateServerId / game.PrivateServerOwnerId.
-- TeleportService:TeleportToPrivateServer needs the PlaceId + reservedServerCode.
-- We read the reserved code via GetJoinData which is available in LocalScript context.
local reservedServerCode = nil
task.spawn(function()
    -- GetJoinData is not always instantly available; wrap in pcall
    local ok, joinData = pcall(function()
        return Players:GetJoinData()
    end)
    if ok and joinData then
        reservedServerCode = joinData.ReservedServerAccessCode ~= "" and joinData.ReservedServerAccessCode or nil
    end
    if reservedServerCode then
        print("[AutoRejoin] Private server code captured:", reservedServerCode)
        rejoinStatusLabel.Text = "Rejoin: private server detected"
    else
        rejoinStatusLabel.Text = "Rejoin: public server detected"
    end
end)

local REJOIN_DELAY = 5 -- seconds to wait before rejoining

local function doRejoin()
    if not autoRejoinEnabled() then return end
    rejoinStatusLabel.Text = "Rejoining in " .. REJOIN_DELAY .. "s..."
    task.wait(REJOIN_DELAY)
    if not autoRejoinEnabled() then
        rejoinStatusLabel.Text = "Rejoin: cancelled (toggled off)"
        return
    end

    local placeId = game.PlaceId

    if reservedServerCode and reservedServerCode ~= "" then
        -- Rejoin the exact private server
        rejoinStatusLabel.Text = "Rejoining private server..."
        local ok, err = pcall(function()
            TeleportService:TeleportToPrivateServer(placeId, reservedServerCode, {LocalPlayer})
        end)
        if not ok then
            warn("[AutoRejoin] Private server rejoin failed:", err)
            -- Fall back to public if private server rejoin fails
            rejoinStatusLabel.Text = "Private rejoin failed, trying public..."
            pcall(function()
                TeleportService:Teleport(placeId, LocalPlayer)
            end)
        end
    else
        -- Rejoin the public server
        rejoinStatusLabel.Text = "Rejoining public server..."
        local ok, err = pcall(function()
            TeleportService:Teleport(placeId, LocalPlayer)
        end)
        if not ok then
            warn("[AutoRejoin] Public server rejoin failed:", err)
            -- Last-resort: use teleport to same place without specifying player
            pcall(function()
                TeleportService:Teleport(placeId)
            end)
        end
    end
end

-- Hook: fires when the server is shutting down or we are being kicked
game:BindToClose(function()
    doRejoin()
end)

-- Hook: fires when the local player is kicked / removed from the server
Players.PlayerRemoving:Connect(function(p)
    if p == LocalPlayer then
        doRejoin()
    end
end)

-- Hook: catch teleport state failures (e.g. failed teleport attempt mid-game)
LocalPlayer.OnTeleport:Connect(function(teleportState, _placeId, _spawnName)
    if teleportState == Enum.TeleportState.Failed then
        warn("[AutoRejoin] Teleport failed, retrying...")
        rejoinStatusLabel.Text = "Teleport failed, retrying..."
        task.wait(3)
        doRejoin()
    end
end)

--=====================================================--
--===          END AUTO REJOIN SYSTEM               ===--
--=====================================================--

--=====================================================--
--===            CONFIG AUTO-SAVE SYSTEM            ===--
--=====================================================--
local CONFIG_REGISTRY = {
    CombatEnabled     = { get = combatEnabled,         set = setCombatEnabled },
    SkipEnabled       = { get = skipEnabled,           set = setSkipEnabled },
    CombatType        = { get = combatTypeDropdown,    set = setCombatType },
    SelectedSkill     = { get = skillSelect,           set = setSkillSelect },
    PrestigeEnabled   = { get = prestigeEnabled,       set = setPrestigeEnabled },
    EvolveEnabled     = { get = evolveEnabled,         set = setEvolveEnabled },
    AutoRaceEnabled   = { get = autoRaceEnabled,       set = setAutoRaceEnabled },
    RaceTarget        = { get = raceDropdown,          set = setRaceDropdown },
    AutoSpiritEnabled = { get = autoSpiritRollEnabled, set = setAutoSpiritRollEnabled },
    SpiritTarget      = { get = spiritTargetDropdown,  set = setSpiritTarget },
    SpiritSlot        = { get = spiritSlotDropdown,    set = setSpiritSlot },
    RaidEnabled       = { get = raidEnabled,           set = setRaidEnabled },
    RaidSelection     = { get = raidSelection,         set = setRaidSelection },
    DungeonEnabled    = { get = dungeonEnabled,        set = setDungeonEnabled },
    ColorPreset       = { get = colorDropdown,         set = setColorDropdown },
    AntiAFKEnabled    = { get = antiAFKEnabled,        set = setAntiAFKEnabled },
    AntiSpamEnabled   = { get = antiSpamEnabled,       set = setAntiSpamEnabled },
    AutoClaimEnabled  = { get = autoClaimEnabled,      set = setAutoClaimEnabled },
    AutoRejoinEnabled = { get = autoRejoinEnabled,     set = setAutoRejoinEnabled }, -- NEW
}

local CONFIG_FOLDER = "TensuraAutoConfig"
local CONFIG_FILE = CONFIG_FOLDER .. "/config.json"

local fsSupported = typeof(writefile) == "function"
    and typeof(readfile) == "function"
    and typeof(isfile) == "function"
    and typeof(makefolder) == "function"
    and typeof(isfolder) == "function"

if fsSupported then
    pcall(function()
        if not isfolder(CONFIG_FOLDER) then
            makefolder(CONFIG_FOLDER)
        end
    end)
end

local function buildConfigTable()
    local data = {}
    for key, entry in pairs(CONFIG_REGISTRY) do
        local ok, value = pcall(entry.get)
        if ok then
            data[key] = value
        end
    end
    data.FramePosition = {
        XScale = frame.Position.X.Scale,
        XOffset = frame.Position.X.Offset,
        YScale = frame.Position.Y.Scale,
        YOffset = frame.Position.Y.Offset,
    }
    return data
end

local function saveConfig()
    if not fsSupported then return false end
    local ok, encoded = pcall(function()
        return HttpService:JSONEncode(buildConfigTable())
    end)
    if not ok then return false end
    return pcall(function()
        writefile(CONFIG_FILE, encoded)
    end)
end

local function loadConfig()
    if not fsSupported then return false end
    local exists, fileExists = pcall(function() return isfile(CONFIG_FILE) end)
    if not exists or not fileExists then return false end

    local readOk, raw = pcall(function() return readfile(CONFIG_FILE) end)
    if not readOk then return false end

    local decodeOk, data = pcall(function() return HttpService:JSONDecode(raw) end)
    if not decodeOk or type(data) ~= "table" then return false end

    for key, entry in pairs(CONFIG_REGISTRY) do
        if data[key] ~= nil and entry.set then
            pcall(function() entry.set(data[key]) end)
        end
    end

    if data.ColorPreset and gradientPresets[data.ColorPreset] then
        pcall(function() setGUIGradientPreset(data.ColorPreset) end)
    end

    if data.FramePosition then
        pcall(function()
            frame.Position = UDim2.new(
                data.FramePosition.XScale or 0, data.FramePosition.XOffset or 20,
                data.FramePosition.YScale or 0, data.FramePosition.YOffset or 100
            )
            syncBorderToFrame()
        end)
    end

    return true
end

local configLoaded = loadConfig()

-- Settings tab: manual save / delete buttons + status label
-- Shifted down by 42px to make room for the Auto Rejoin toggle above
local saveConfigButton = Instance.new("TextButton")
saveConfigButton.Parent = settingsTab
saveConfigButton.Size = UDim2.new(0, 125, 0, 32)
saveConfigButton.Position = UDim2.new(0, 10, 0, 236)
saveConfigButton.BackgroundColor3 = Color3.fromRGB(60, 100, 160)
saveConfigButton.TextColor3 = Color3.fromRGB(255, 255, 255)
saveConfigButton.Font = Enum.Font.SourceSans
saveConfigButton.TextSize = 16
saveConfigButton.Text = "Save Config"
saveConfigButton.BorderSizePixel = 0
Instance.new("UICorner", saveConfigButton).CornerRadius = UDim.new(0, 18)

local resetConfigButton = Instance.new("TextButton")
resetConfigButton.Parent = settingsTab
resetConfigButton.Size = UDim2.new(0, 125, 0, 32)
resetConfigButton.Position = UDim2.new(0, 145, 0, 236)
resetConfigButton.BackgroundColor3 = Color3.fromRGB(150, 60, 60)
resetConfigButton.TextColor3 = Color3.fromRGB(255, 255, 255)
resetConfigButton.Font = Enum.Font.SourceSans
resetConfigButton.TextSize = 16
resetConfigButton.Text = "Delete Saved"
resetConfigButton.BorderSizePixel = 0
Instance.new("UICorner", resetConfigButton).CornerRadius = UDim.new(0, 18)

local configStatusLabel = Instance.new("TextLabel")
configStatusLabel.Parent = settingsTab
configStatusLabel.Size = UDim2.new(0, 260, 0, 20)
configStatusLabel.Position = UDim2.new(0, 10, 0, 272)
configStatusLabel.BackgroundTransparency = 1
configStatusLabel.Font = Enum.Font.SourceSans
configStatusLabel.TextSize = 14
configStatusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
configStatusLabel.TextXAlignment = Enum.TextXAlignment.Left
configStatusLabel.Text = (not fsSupported) and "Autosave unsupported by executor"
    or (configLoaded and "Config loaded - Autosave: ON" or "No saved config - Autosave: ON")

saveConfigButton.MouseButton1Click:Connect(function()
    local ok = saveConfig()
    configStatusLabel.Text = ok and "Saved!" or "Save failed"
    task.delay(1.5, function()
        configStatusLabel.Text = fsSupported and "Autosave: ON" or "Autosave unsupported by executor"
    end)
end)

resetConfigButton.MouseButton1Click:Connect(function()
    if fsSupported then
        pcall(function()
            if isfile(CONFIG_FILE) then
                if typeof(delfile) == "function" then
                    delfile(CONFIG_FILE)
                else
                    writefile(CONFIG_FILE, "{}")
                end
            end
        end)
    end
    configStatusLabel.Text = "Saved config deleted"
    task.delay(1.5, function()
        configStatusLabel.Text = fsSupported and "Autosave: ON" or "Autosave unsupported by executor"
    end)
end)

if not fsSupported then
    warn("[Tensura Panel] Executor doesn't support file I/O (writefile/readfile) - config auto-save disabled.")
end

task.spawn(function()
    if not fsSupported then return end
    local lastSnapshot = nil
    while true do
        local ok, snapshot = pcall(function()
            return HttpService:JSONEncode(buildConfigTable())
        end)
        if ok and snapshot ~= lastSnapshot then
            local saved = pcall(function() writefile(CONFIG_FILE, snapshot) end)
            if saved then
                lastSnapshot = snapshot
            end
        end
        task.wait(1)
    end
end)
--=====================================================--
--===          END CONFIG AUTO-SAVE SYSTEM          ===--
--=====================================================--

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

local antiAFKConnection
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

local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local antiSpamConnection

local function startAntiSpam()
    if antiSpamConnection then return end
    antiSpamConnection = PlayerGui.DescendantAdded:Connect(function(inst)
        if inst:IsA("TextLabel") or inst:IsA("TextButton") then
            task.spawn(function()
                task.wait()
                local ok, text = pcall(function() return inst.Text end)
                if ok and text and text:find("EVOLUTION FAILED") then
                    local card = inst
                    for i = 1, 3 do
                        if card.Parent and card.Parent ~= PlayerGui then
                            card = card.Parent
                        end
                    end
                    card:Destroy()
                end
            end)
        end
    end)
end

local function stopAntiSpam()
    if antiSpamConnection then
        antiSpamConnection:Disconnect()
        antiSpamConnection = nil
    end
end

task.spawn(function()
    local wasEnabled = false
    while true do
        local enabled = antiSpamEnabled()
        if enabled and not wasEnabled then
            startAntiSpam()
            wasEnabled = true
        elseif not enabled and wasEnabled then
            stopAntiSpam()
            wasEnabled = false
        end
        task.wait(0.2)
    end
end)

local autoClaimConnection

local function startAutoClaim()
    if autoClaimConnection then return end
    autoClaimConnection = PlayerGui.DescendantAdded:Connect(function(inst)
        if inst:IsA("TextButton") then
            task.spawn(function()
                task.wait()
                local ok, text = pcall(function() return inst.Text end)
                if ok and text and text:match("^%s*CLAIM%s*$") then
                    task.wait(0.15)
                    local fired = pcall(function()
                        firesignal(inst.MouseButton1Click)
                    end)
                    if not fired then
                        pcall(function()
                            inst:Activate()
                        end)
                    end
                end
            end)
        end
    end)
end

local function stopAutoClaim()
    if autoClaimConnection then
        autoClaimConnection:Disconnect()
        autoClaimConnection = nil
    end
end

task.spawn(function()
    local wasEnabled = false
    while true do
        local enabled = autoClaimEnabled()
        if enabled and not wasEnabled then
            startAutoClaim()
            wasEnabled = true
        elseif not enabled and wasEnabled then
            stopAutoClaim()
            wasEnabled = false
        end
        task.wait(0.2)
    end
end)

-- Combat logic
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

task.spawn(function()
    while true do
        if prestigeEnabled() then
            pcall(function()
                prestigeRemote:InvokeServer()
            end)
        end
        task.wait()
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
        task.wait()
    end
end)
task.spawn(function()
    while true do
        if raidEnabled() then
            pcall(function()
                raidRemote:InvokeServer(raidSelection())
            end)
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

task.spawn(function()
    local t = 0
    while true do
        t += 0.015
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

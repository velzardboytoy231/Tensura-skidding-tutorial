--// SERVICES
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")

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

-- === EARLY COMBAT/SKIP STATE — auto-execute safe ===
local _state = { combat = false, skip = false, type = "Cycle", skill = 1 }
local _skillOrder = {8,7,6,5,4,3,2,1}
local _skillIdx = 1
local _psState  = {step = 1, cycleIndex = 1}

combatRemote.OnClientInvoke = function()
    if _state.combat then
        if _state.type == "Cycle" then
            local s = _skillOrder[_skillIdx]
            _skillIdx = (_skillIdx % #_skillOrder) + 1
            return s
        elseif _state.type == "Single" then
            return _state.skill
        elseif _state.type == "Prefer Skill" then
            if _psState.step == 1 then
                _psState.step = 2
                return _state.skill
            else
                local s = _skillOrder[_psState.cycleIndex]
                if s == _state.skill then
                    _psState.cycleIndex = (_psState.cycleIndex % #_skillOrder) + 1
                    s = _skillOrder[_psState.cycleIndex]
                end
                _psState.cycleIndex = (_psState.cycleIndex % #_skillOrder) + 1
                _psState.step = 1
                return s
            end
        end
    elseif _state.skip then
        return "skipturn"
    end
    return nil
end

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
    },
    -- New preset for the OP tab glow
    ["OP Crimson"] = {
        {0, Color3.fromRGB(255, 60, 60)},
        {1, Color3.fromRGB(120, 0, 180)}
    },
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

-- OP tab added between Spirits and Settings
local tabs = { "Combat", "Player", "Raids", "Dungeon", "Spirits", "⚡ OP", "Settings" }
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
    button.Text = tabName
    button.Font = Enum.Font.GothamSemibold
    button.TextSize = 14
    button.BorderSizePixel = 0

    -- Give the OP tab a special crimson color
    if tabName == "⚡ OP" then
        button.BackgroundColor3 = Color3.fromRGB(80, 20, 20)
        button.TextColor3 = Color3.fromRGB(255, 120, 120)
    else
        button.BackgroundColor3 = tabName=="Combat" and Color3.fromRGB(60,100,160) or Color3.fromRGB(60,60,60)
        button.TextColor3 = Color3.fromRGB(220,220,230)
    end

    local btnCorner = Instance.new("UICorner", button)
    btnCorner.CornerRadius = UDim.new(0, 18)

    button.MouseButton1Click:Connect(function()
        for _, b in pairs(tabButtons) do
            -- Restore OP tab to its special idle color
            if b.Name == "⚡ OPTab" then
                b.BackgroundColor3 = Color3.fromRGB(80, 20, 20)
                b.TextColor3 = Color3.fromRGB(255, 120, 120)
            else
                b.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
                b.TextColor3 = Color3.fromRGB(220, 220, 230)
            end
        end
        if tabName == "⚡ OP" then
            button.BackgroundColor3 = Color3.fromRGB(180, 30, 30)
            button.TextColor3 = Color3.fromRGB(255, 220, 220)
        else
            button.BackgroundColor3 = Color3.fromRGB(60,100,160)
            button.TextColor3 = Color3.fromRGB(220,220,230)
        end
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
    local function setter(val)
        enabled = val
        toggle.Text = name .. (enabled and ": ON" or ": OFF")
        toggle.BackgroundColor3 = enabled and Color3.fromRGB(50, 150, 50) or Color3.fromRGB(150, 50, 50)
    end
    return function() return enabled end, toggle, setter
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

    local function setter(val)
        for _, opt in ipairs(options) do
            if opt == val then
                selected = val
                dropdown.Text = name .. ": " .. selected
                break
            end
        end
    end

    return function() return selected end, setter
end

--=== TAB CONTENTS ===--
local combatTab = tabContainers["Combat"]
local combatEnabled, _, setCombatEnabled = createToggle("Auto Combat", 10, combatTab)
local skipEnabled, _, setSkipEnabled = createToggle("Auto Skip Turn", 52, combatTab)

local combatTypeOptions = {"Cycle", "Single", "Prefer Skill"}
local combatTypeDropdown, setCombatTypeDropdown = createDropdown("Combat Type", combatTypeOptions, 94, combatTab)

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
local spiritTargetDropdown, setSpiritTargetDropdown = createDropdown("Target Spirit", spiritNames, 52, spiritsTab)
local spiritSlotDropdown, setSpiritSlotDropdown = createDropdown("Spirit Slot", spiritSlots, 94, spiritsTab)

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
local opTab = tabContainers["⚡ OP"]
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

--==========================================================--
--// ⚡ OP TAB — AUTO INSTANT PRESTIGE
-- Fires prestigeRemote as fast as possible, completely
-- independent of evolution state. No EP check, no evolve
-- delay. Pure spam prestige on its own thread.
--==========================================================--

-- Prestige counter display
local opPrestigeCountLabel = Instance.new("TextLabel")
opPrestigeCountLabel.Parent = opTab
opPrestigeCountLabel.Size = UDim2.new(0, 460, 0, 28)
opPrestigeCountLabel.Position = UDim2.new(0, 10, 0, 10)
opPrestigeCountLabel.BackgroundTransparency = 1
opPrestigeCountLabel.Text = "⚡ Instant Prestiges This Session: 0"
opPrestigeCountLabel.TextColor3 = Color3.fromRGB(255, 80, 80)
opPrestigeCountLabel.Font = Enum.Font.GothamBold
opPrestigeCountLabel.TextSize = 16
opPrestigeCountLabel.TextXAlignment = Enum.TextXAlignment.Left

-- Main toggle
local instantPrestigeEnabled, _, setInstantPrestigeEnabled = createToggle("Auto Instant Prestige", 46, opTab)

-- Speed dropdown: how fast to fire per cycle
local prestigeSpeedOptions = {"Max Speed (no delay)", "Fast (0.05s)", "Normal (0.1s)", "Safe (0.5s)"}
local prestigeSpeedDropdown, setPrestigeSpeedDropdown = createDropdown("Prestige Speed", prestigeSpeedOptions, 88, opTab)

-- Warning label
local opWarningLabel = Instance.new("TextLabel")
opWarningLabel.Parent = opTab
opWarningLabel.Size = UDim2.new(0, 460, 0, 54)
opWarningLabel.Position = UDim2.new(0, 10, 0, 172)
opWarningLabel.BackgroundTransparency = 1
opWarningLabel.Text = "⚠  Max Speed fires with no delay.\nThis bypasses evolution entirely — prestige\nfires on its own loop, instantly and always."
opWarningLabel.TextColor3 = Color3.fromRGB(255, 200, 60)
opWarningLabel.Font = Enum.Font.SourceSans
opWarningLabel.TextSize = 14
opWarningLabel.TextXAlignment = Enum.TextXAlignment.Left
opWarningLabel.TextWrapped = true

-- Status glow label
local opStatusLabel = Instance.new("TextLabel")
opStatusLabel.Parent = opTab
opStatusLabel.Size = UDim2.new(0, 460, 0, 28)
opStatusLabel.Position = UDim2.new(0, 10, 0, 230)
opStatusLabel.BackgroundTransparency = 1
opStatusLabel.Text = "Status: IDLE"
opStatusLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
opStatusLabel.Font = Enum.Font.GothamSemibold
opStatusLabel.TextSize = 15
opStatusLabel.TextXAlignment = Enum.TextXAlignment.Left

-- Prestige counter tracker
local instantPrestigeCount = 0

-- Instant Prestige loop — fully independent thread, no EP or evolve dependency
task.spawn(function()
    while true do
        if instantPrestigeEnabled() then
            -- Determine delay from speed setting
            local speedSetting = prestigeSpeedDropdown()
            local delay = 0
            if speedSetting == "Fast (0.05s)" then
                delay = 0.05
            elseif speedSetting == "Normal (0.1s)" then
                delay = 0.1
            elseif speedSetting == "Safe (0.5s)" then
                delay = 0.5
            else
                delay = 0  -- Max Speed
            end

            local success, result = pcall(function()
                return prestigeRemote:InvokeServer()
            end)

            if success then
                instantPrestigeCount += 1
                opPrestigeCountLabel.Text = "⚡ Instant Prestiges This Session: " .. tostring(instantPrestigeCount)
                opStatusLabel.Text = "Status: ⚡ FIRING — " .. tostring(instantPrestigeCount) .. " prestiges done"
                opStatusLabel.TextColor3 = Color3.fromRGB(255, 80, 80)
            else
                opStatusLabel.Text = "Status: ⚠ Remote error, retrying..."
                opStatusLabel.TextColor3 = Color3.fromRGB(255, 200, 60)
            end

            if delay > 0 then
                task.wait(delay)
            else
                task.wait()  -- yield one frame only at max speed
            end
        else
            opStatusLabel.Text = "Status: IDLE"
            opStatusLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
            task.wait(0.1)
        end
    end
end)

-- Pulsing glow effect on the OP status label when active
task.spawn(function()
    local t = 0
    while true do
        t += 0.05
        if instantPrestigeEnabled() then
            local pulse = 0.5 + 0.5 * math.sin(t * 6)
            opStatusLabel.TextColor3 = Color3.fromRGB(
                255,
                math.floor(60 + 60 * pulse),
                math.floor(60 + 60 * pulse)
            )
            opPrestigeCountLabel.TextColor3 = Color3.fromRGB(
                255,
                math.floor(80 + 80 * pulse),
                math.floor(80 + 80 * pulse)
            )
        end
        task.wait(0.03)
    end
end)

-- Syncs toggle states into _state at 100 Hz — keeps OnClientInvoke always current
task.spawn(function()
    local lastType, lastSkill
    while true do
        _state.combat = combatEnabled()
        _state.skip   = skipEnabled()
        _state.type   = combatTypeDropdown()
        _state.skill  = tonumber(skillSelect()) or 1
        if lastType ~= _state.type or lastSkill ~= _state.skill then
            _psState.step = 1
            _psState.cycleIndex = 1
            lastType  = _state.type
            lastSkill = _state.skill
        end
        task.wait(0.01)
    end
end)

local colorPresetsList = {}
for name, _ in pairs(gradientPresets) do
    table.insert(colorPresetsList, name)
end
local colorDropdown, setColorDropdown = createDropdown("Color", colorPresetsList, 10, settingsTab)
local antiAFKEnabled, antiAFKToggle, setAntiAFKEnabled = createToggle("Anti-AFK", 52, settingsTab)
local antiSpamEnabled, antiSpamToggle, setAntiSpamEnabled = createToggle("Anti-Spam (Lag Fix)", 94, settingsTab)
local autoClaimEnabled, autoClaimToggle, setAutoClaimEnabled = createToggle("Auto Claim Rewards", 136, settingsTab)

--==========================================================--
--// AUTO REJOIN
--==========================================================--
local autoRejoinEnabled, autoRejoinToggle, setAutoRejoinEnabled = createToggle("Auto Rejoin", 178, settingsTab)

local privateLinkLabel = Instance.new("TextLabel")
privateLinkLabel.Parent = settingsTab
privateLinkLabel.Size = UDim2.new(0, 260, 0, 20)
privateLinkLabel.Position = UDim2.new(0, 10, 0, 218)
privateLinkLabel.BackgroundTransparency = 1
privateLinkLabel.Text = "Private Server Link (optional):"
privateLinkLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
privateLinkLabel.Font = Enum.Font.SourceSans
privateLinkLabel.TextSize = 13
privateLinkLabel.TextXAlignment = Enum.TextXAlignment.Left

local privateLinkBox = Instance.new("TextBox")
privateLinkBox.Parent = settingsTab
privateLinkBox.Size = UDim2.new(0, 260, 0, 28)
privateLinkBox.Position = UDim2.new(0, 10, 0, 240)
privateLinkBox.BackgroundColor3 = Color3.fromRGB(45, 45, 55)
privateLinkBox.TextColor3 = Color3.fromRGB(255, 255, 255)
privateLinkBox.PlaceholderText = "Paste private server link here"
privateLinkBox.PlaceholderColor3 = Color3.fromRGB(120, 120, 120)
privateLinkBox.Font = Enum.Font.SourceSans
privateLinkBox.TextSize = 12
privateLinkBox.Text = ""
privateLinkBox.BorderSizePixel = 0
privateLinkBox.ClearTextOnFocus = false

local privateLinkCorner = Instance.new("UICorner", privateLinkBox)
privateLinkCorner.CornerRadius = UDim.new(0, 10)

local function extractPrivateCode(link)
    if not link or link == "" then return nil end
    local code = link:match("[?&]privateServerLinkCode=([^&%s]+)")
    return code
end

local gameId = game.PlaceId

task.spawn(function()
    local Players = game:GetService("Players")
    local TeleportService = game:GetService("TeleportService")

    Players.LocalPlayer.OnTeleport:Connect(function(state)
    end)

    game:BindToClose(function()
        if not autoRejoinEnabled() then return end
        task.wait(1)
        local privateCode = extractPrivateCode(privateLinkBox.Text)
        if privateCode then
            pcall(function()
                TeleportService:TeleportToPrivateServer(gameId, privateCode, {Players.LocalPlayer})
            end)
        else
            pcall(function()
                TeleportService:Teleport(gameId, Players.LocalPlayer)
            end)
        end
    end)

    Players.PlayerRemoving:Connect(function(removedPlayer)
        if removedPlayer ~= Players.LocalPlayer then return end
        if not autoRejoinEnabled() then return end
        task.wait(1)
        local privateCode = extractPrivateCode(privateLinkBox.Text)
        if privateCode then
            pcall(function()
                TeleportService:TeleportToPrivateServer(gameId, privateCode, {Players.LocalPlayer})
            end)
        else
            pcall(function()
                TeleportService:Teleport(gameId, Players.LocalPlayer)
            end)
        end
    end)
end)

--==========================================================--
--// AUTO SAVE SETTINGS
--==========================================================--
local SETTINGS_FILE = "TensuraPanel_Settings.json"

local function canUseFileIO()
    return type(writefile) == "function" and type(readfile) == "function" and type(isfile) == "function"
end

local function gatherSettings()
    return {
        combatEnabled        = combatEnabled(),
        skipEnabled          = skipEnabled(),
        combatType           = combatTypeDropdown(),
        selectedSkill        = skillSelect(),
        prestigeEnabled      = prestigeEnabled(),
        evolveEnabled        = evolveEnabled(),
        autoRaceEnabled      = autoRaceEnabled(),
        raceTarget           = raceDropdown(),
        autoSpiritRoll       = autoSpiritRollEnabled(),
        spiritTarget         = spiritTargetDropdown(),
        spiritSlot           = spiritSlotDropdown(),
        raidEnabled          = raidEnabled(),
        raidSelection        = raidSelection(),
        dungeonEnabled       = dungeonEnabled(),
        -- OP tab
        instantPrestige      = instantPrestigeEnabled(),
        prestigeSpeed        = prestigeSpeedDropdown(),
        -- Settings
        colorPreset          = colorDropdown(),
        antiAFK              = antiAFKEnabled(),
        antiSpam             = antiSpamEnabled(),
        autoClaim            = autoClaimEnabled(),
        autoRejoin           = autoRejoinEnabled(),
        privateLink          = privateLinkBox.Text,
    }
end

local function applySettings(s)
    if s.combatEnabled   ~= nil then setCombatEnabled(s.combatEnabled) end
    if s.skipEnabled     ~= nil then setSkipEnabled(s.skipEnabled) end
    if s.combatType      ~= nil then setCombatTypeDropdown(s.combatType) end
    if s.selectedSkill   ~= nil then setSkillSelect(s.selectedSkill) end
    if s.prestigeEnabled ~= nil then setPrestigeEnabled(s.prestigeEnabled) end
    if s.evolveEnabled   ~= nil then setEvolveEnabled(s.evolveEnabled) end
    if s.autoRaceEnabled ~= nil then setAutoRaceEnabled(s.autoRaceEnabled) end
    if s.raceTarget      ~= nil then setRaceDropdown(s.raceTarget) end
    if s.autoSpiritRoll  ~= nil then setAutoSpiritRollEnabled(s.autoSpiritRoll) end
    if s.spiritTarget    ~= nil then setSpiritTargetDropdown(s.spiritTarget) end
    if s.spiritSlot      ~= nil then setSpiritSlotDropdown(s.spiritSlot) end
    if s.raidEnabled     ~= nil then setRaidEnabled(s.raidEnabled) end
    if s.raidSelection   ~= nil then setRaidSelection(s.raidSelection) end
    if s.dungeonEnabled  ~= nil then setDungeonEnabled(s.dungeonEnabled) end
    -- OP tab
    if s.instantPrestige ~= nil then setInstantPrestigeEnabled(s.instantPrestige) end
    if s.prestigeSpeed   ~= nil then setPrestigeSpeedDropdown(s.prestigeSpeed) end
    -- Settings tab
    if s.colorPreset     ~= nil then setColorDropdown(s.colorPreset) ; setGUIGradientPreset(s.colorPreset) end
    if s.antiAFK         ~= nil then setAntiAFKEnabled(s.antiAFK) end
    if s.antiSpam        ~= nil then setAntiSpamEnabled(s.antiSpam) end
    if s.autoClaim       ~= nil then setAutoClaimEnabled(s.autoClaim) end
    if s.autoRejoin      ~= nil then setAutoRejoinEnabled(s.autoRejoin) end
    if s.privateLink     ~= nil then privateLinkBox.Text = s.privateLink end
end

local function saveSettings()
    if not canUseFileIO() then return end
    local ok, encoded = pcall(function()
        return HttpService:JSONEncode(gatherSettings())
    end)
    if ok then
        pcall(writefile, SETTINGS_FILE, encoded)
    end
end

local function loadSettings()
    if not canUseFileIO() then return end
    local ok, exists = pcall(isfile, SETTINGS_FILE)
    if not ok or not exists then return end
    local ok2, content = pcall(readfile, SETTINGS_FILE)
    if not ok2 or not content or content == "" then return end
    local ok3, data = pcall(function()
        return HttpService:JSONDecode(content)
    end)
    if ok3 and type(data) == "table" then
        applySettings(data)
        print("[TensuraPanel] Settings loaded from", SETTINGS_FILE)
    end
end

local autoSaveEnabled, autoSaveToggle, setAutoSaveEnabled = createToggle("Auto Save Settings", 276, settingsTab)

local saveButton = Instance.new("TextButton")
saveButton.Parent = settingsTab
saveButton.Size = UDim2.new(0, 124, 0, 28)
saveButton.Position = UDim2.new(0, 10, 0, 316)
saveButton.BackgroundColor3 = Color3.fromRGB(50, 100, 170)
saveButton.TextColor3 = Color3.fromRGB(255, 255, 255)
saveButton.Font = Enum.Font.GothamSemibold
saveButton.TextSize = 14
saveButton.Text = "💾 Save Now"
saveButton.BorderSizePixel = 0
local saveCorner = Instance.new("UICorner", saveButton)
saveCorner.CornerRadius = UDim.new(0, 12)

local loadButton = Instance.new("TextButton")
loadButton.Parent = settingsTab
loadButton.Size = UDim2.new(0, 124, 0, 28)
loadButton.Position = UDim2.new(0, 146, 0, 316)
loadButton.BackgroundColor3 = Color3.fromRGB(80, 60, 120)
loadButton.TextColor3 = Color3.fromRGB(255, 255, 255)
loadButton.Font = Enum.Font.GothamSemibold
loadButton.TextSize = 14
loadButton.Text = "📂 Load Save"
loadButton.BorderSizePixel = 0
local loadCorner = Instance.new("UICorner", loadButton)
loadCorner.CornerRadius = UDim.new(0, 12)

saveButton.MouseButton1Click:Connect(function()
    saveSettings()
    saveButton.Text = "✅ Saved!"
    task.delay(1.5, function()
        saveButton.Text = "💾 Save Now"
    end)
end)

loadButton.MouseButton1Click:Connect(function()
    loadSettings()
    loadButton.Text = "✅ Loaded!"
    task.delay(1.5, function()
        loadButton.Text = "📂 Load Save"
    end)
end)

task.spawn(function()
    while true do
        task.wait(10)
        if autoSaveEnabled() then
            saveSettings()
        end
    end
end)

task.spawn(function()
    task.wait(0.5)
    loadSettings()
end)

--==========================================================--
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

-- Original auto prestige (Player tab) — still works as before
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

-- Animation loop for gradients
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

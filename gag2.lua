-- =====================================================================
-- GROW A GARDEN 2 - 100% COMPLETE AUTOMATION v2.0
-- Features: Auto Farm, Auto Steal, Auto Defend, Event Farming, All mechanics
-- Author: Research-Based Implementation by Lâm
-- =====================================================================

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")

-- =====================================================================
-- CORE SETUP
-- =====================================================================
local Player = Players.LocalPlayer
local Character = Player.Character or Player.CharacterAdded:Wait()
local Humanoid = Character:WaitForChild("Humanoid")
local RootPart = Character:WaitForChild("HumanoidRootPart")

local scriptActive = true
local connections = {}

-- =====================================================================
-- GAME STATE
-- =====================================================================
local GameState = {
    -- Time & Cycle
    isNight = false,
    timeOfDay = 0,
    dayPhase = "DAY",
    
    -- Player Stats
    sheckles = 0,
    totalPlots = 0,
    emptyPlots = 0,
    
    -- Automation Flags
    autoFarming = false,
    autoStealing = false,
    autoDefending = false,
    eventFarming = false,
    seedHunting = false,
    
    -- Steal Stats
    stealCount = 0,
    stealProfit = 0,
    targetedCount = 0,
    
    -- Defense
    defendingActive = false,
    trapCount = 0,
    petCount = 0,
    
    -- Event Tracking
    currentWeather = "Day",
    lastWeatherCheck = 0,
    weatherBoost = 1,
    
    -- Safety
    adminNearby = false,
    detectionScore = 0
}

local Config = {
    -- Seed Tiers (from research)
    starterSeeds = {"Carrot", "Strawberry", "Blueberry"},
    profitSeeds = {"Bamboo", "Sunflower", "Horned Melon"},
    premiumSeeds = {"Moon Bloom", "Mushroom", "Venus Fly Trap"},
    
    -- Defense Plants
    defenseSeeds = {"Cactus", "Venus Fly Trap", "Dragon's Breath", "Bamboo"},
    
    -- Mutation Seeds
    mutationTarget = "Bamboo", -- Best mutation potential
    
    -- Thresholds
    minShecklesForSeed = 50,
    minValueToSteal = 200,
    harvestBefore = 1050, -- Before 10:50 PM
    nightStart = 1320, -- 10 PM (22:00)
    nightEnd = 360, -- 6 AM
    
    -- Stealing Config
    maxStealsPerNight = 5,
    stealCooldown = 20, -- seconds
    stealTimeout = 15, -- seconds to steal and escape
    safeDistance = 100, -- distance to find targets
    
    -- Defense Config
    defenseRadius = 150,
    trapRange = 50,
    petPatrol = 100,
}

-- =====================================================================
-- UTILITY FUNCTIONS
-- =====================================================================
local function notify(title, message, duration)
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = title or "GAG2",
            Text = message or "",
            Duration = duration or 3
        })
    end)
end

local function getMinutesAfterMidnight()
    return Lighting:GetMinutesAfterMidnight()
end

local function updateTimePhase()
    local minutes = getMinutesAfterMidnight()
    GameState.timeOfDay = minutes
    GameState.isNight = (minutes >= Config.nightStart) or (minutes < Config.nightEnd)
    GameState.dayPhase = GameState.isNight and "🌙 NIGHT" or "☀️ DAY"
end

local function getWeather()
    -- Check Lighting for weather
    local weather = Lighting:FindFirstChild("Weather") or Lighting:FindFirstChild("CurrentWeather")
    if weather then
        return weather.Value
    end
    return "Day"
end

local function findRemote(name)
    local remote = ReplicatedStorage:FindFirstChild(name)
    if remote then return remote end
    
    for _, child in ipairs(ReplicatedStorage:GetDescendants()) do
        if (child:IsA("RemoteEvent") or child:IsA("RemoteFunction")) and child.Name:lower():match(name:lower()) then
            return child
        end
    end
    return nil
end

local function getPlayerPlots()
    local plots = {}
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("BasePart") and (obj.Name == "Plot" or obj.Name:match("Plot")) then
            if obj:FindFirstChild("Owner") and obj.Owner.Value == Player then
                table.insert(plots, obj)
            end
        end
    end
    return plots
end

local function getOtherPlots(radius)
    local plots = {}
    local myPlots = {}
    
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("BasePart") and obj.Name:match("Plot") then
            local distance = (RootPart.Position - obj.Position).Magnitude
            if distance <= radius then
                local owner = obj:FindFirstChild("Owner")
                if owner then
                    if owner.Value ~= Player then
                        table.insert(plots, {plot = obj, owner = owner.Value, distance = distance})
                    else
                        table.insert(myPlots, obj)
                    end
                end
            end
        end
    end
    
    -- Sort by distance
    table.sort(plots, function(a, b) return a.distance < b.distance end)
    return plots
end

local function findBestCropToSteal(targetPlot, minValue)
    local bestCrop = nil
    local bestValue = 0
    
    for _, child in ipairs(targetPlot:GetChildren()) do
        if child:IsA("BasePart") and (child.Name:match("Crop") or child.Name:match("Plant")) then
            local value = 10
            
            -- Check for mutations
            if child:FindFirstChild("Harvestable") and child.Harvestable.Value then
                if child:FindFirstChild("Mutation") then
                    local mutation = child.Mutation.Value
                    if mutation == "Bloodlit" then value = 500
                    elseif mutation == "Starstruck" then value = 300
                    elseif mutation == "Rainbow" then value = 250
                    elseif mutation == "Gold" then value = 200
                    elseif mutation == "Electric" then value = 150
                    elseif mutation == "Frozen" then value = 150
                    elseif mutation ~= "None" then value = 50 end
                end
                
                if value > bestValue and value >= minValue then
                    bestValue = value
                    bestCrop = child
                end
            end
        end
    end
    
    return bestCrop, bestValue
end

-- =====================================================================
-- AUTO FARMING ENGINE
-- =====================================================================
local function autoFarmingCycle()
    while GameState.autoFarming and scriptActive do
        updateTimePhase()
        
        if GameState.adminNearby then
            task.wait(3)
            continue
        end
        
        local minutesUntilNight = (Config.nightStart - getMinutesAfterMidnight()) % 1440
        
        -- HARVEST PHASE: Before night falls
        if minutesUntilNight < 15 then
            notify("⚠️ NIGHT INCOMING", "Harvesting all crops in 15 min")
            
            local harvestRemote = findRemote("Harvest")
            if harvestRemote then
                for _, obj in ipairs(Workspace:GetDescendants()) do
                    if obj:IsA("BasePart") and obj.Name:match("Crop") then
                        if obj:FindFirstChild("Harvestable") and obj.Harvestable.Value then
                            harvestRemote:FireServer(obj)
                            task.wait(0.2)
                        end
                    end
                end
            end
            
            -- SELL ALL
            local sellRemote = findRemote("Sell") or findRemote("SellAll")
            if sellRemote then
                sellRemote:FireServer()
                notify("💰 SOLD", "All crops sold before night")
            end
        else
            -- PLANT PHASE: During day
            local plantRemote = findRemote("Plant")
            if plantRemote and GameState.sheckles >= Config.minShecklesForSeed then
                local plots = getPlayerPlots()
                
                for _, plot in ipairs(plots) do
                    -- Check if plot is empty
                    local hasCrop = false
                    for _, child in ipairs(plot:GetChildren()) do
                        if child.Name:match("Crop") or child.Name:match("Plant") then
                            hasCrop = true
                            break
                        end
                    end
                    
                    if not hasCrop then
                        -- Choose seed strategy
                        local seedChoice
                        local random = math.random(1, 100)
                        
                        if random <= 60 then
                            -- Profit farming
                            seedChoice = Config.profitSeeds[math.random(1, #Config.profitSeeds)]
                        elseif random <= 85 then
                            -- Mutation farming
                            seedChoice = Config.mutationTarget
                        else
                            -- Defense farming
                            seedChoice = Config.defenseSeeds[math.random(1, #Config.defenseSeeds)]
                        end
                        
                        plantRemote:FireServer(plot, seedChoice)
                        GameState.sheckles = GameState.sheckles - Config.minShecklesForSeed
                        task.wait(0.3)
                    end
                end
            end
            
            -- WATER & FERTILIZE (if available)
            local waterRemote = findRemote("Water")
            if waterRemote then
                for _, obj in ipairs(Workspace:GetDescendants()) do
                    if obj:IsA("BasePart") and obj.Name:match("Crop") then
                        waterRemote:FireServer(obj)
                        task.wait(0.2)
                    end
                end
            end
        end
        
        task.wait(2)
    end
end

-- =====================================================================
-- INTELLIGENT STEALING
-- =====================================================================
local function autoStealingCycle()
    while GameState.autoStealing and scriptActive do
        updateTimePhase()
        
        if not GameState.isNight then
            task.wait(10)
            continue
        end
        
        if GameState.stealCount >= Config.maxStealsPerNight then
            notify("⛔ LIMIT", "Max steals per night reached")
            GameState.autoStealing = false
            break
        end
        
        -- Find weak target gardens
        local otherPlots = getOtherPlots(Config.safeDistance)
        local bestTarget = nil
        local bestValue = 0
        
        for _, plotInfo in ipairs(otherPlots) do
            -- Check if garden is defended (owner inside)
            local ownerChar = plotInfo.owner.Character
            if not ownerChar or (RootPart.Position - ownerChar.HumanoidRootPart.Position).Magnitude > 100 then
                -- Garden is undefended!
                local crop, value = findBestCropToSteal(plotInfo.plot, Config.minValueToSteal)
                
                if crop and value > bestValue then
                    bestValue = value
                    bestTarget = {plot = plotInfo.plot, crop = crop, value = value, ownerName = plotInfo.owner.Name}
                end
            end
        end
        
        if bestTarget then
            notify("🎯 TARGET", string.format("Found %s crop (Value: %d Sheckles)", bestTarget.ownerName, bestTarget.value))
            
            -- Approach target
            local startPos = RootPart.CFrame
            local cropPos = bestTarget.crop.CFrame
            
            TweenService:Create(RootPart, TweenInfo.new(1.5), {CFrame = cropPos}):Play()
            task.wait(2)
            
            -- STEAL (press E)
            local stealRemote = findRemote("Steal") or findRemote("Harvest")
            if stealRemote then
                stealRemote:FireServer(bestTarget.crop)
                GameState.stealCount = GameState.stealCount + 1
                GameState.stealProfit = GameState.stealProfit + bestTarget.value
                
                notify("✅ STOLEN", string.format("Got %d Sheckles! (Total: %d)", bestTarget.value, GameState.stealProfit))
                task.wait(0.5)
            end
            
            -- ESCAPE back to safety
            TweenService:Create(RootPart, TweenInfo.new(2), {CFrame = startPos}):Play()
            task.wait(2)
            
            GameState.stealCount = GameState.stealCount + 1
        end
        
        task.wait(5)
    end
end

-- =====================================================================
-- AUTO DEFENSE
-- =====================================================================
local function autoDefenseCycle()
    while GameState.autoDefending and scriptActive do
        updateTimePhase()
        
        if not GameState.isNight then
            task.wait(10)
            continue
        end
        
        -- Check for nearby intruders
        local nearbyEnemies = {}
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= Player and player.Character then
                local distance = (RootPart.Position - player.Character.HumanoidRootPart.Position).Magnitude
                if distance < Config.defenseRadius then
                    table.insert(nearbyEnemies, {player = player, distance = distance})
                end
            end
        end
        
        if #nearbyEnemies > 0 then
            -- Activate defense gear/traps
            local defenseRemote = findRemote("Activate") or findRemote("TriggerTrap")
            if defenseRemote then
                for _, trap in ipairs(Workspace:GetDescendants()) do
                    if trap.Name:match("Trap") or trap.Name:match("Defense") then
                        defenseRemote:FireServer(trap)
                    end
                end
            end
            
            notify("🛡️ DEFENSE", string.format("Activated! %d intruder(s) nearby", #nearbyEnemies))
        end
        
        task.wait(3)
    end
end

-- =====================================================================
-- EVENT FARMING (Weather mutations)
-- =====================================================================
local function eventFarmingCycle()
    while GameState.eventFarming and scriptActive do
        updateTimePhase()
        
        local weather = getWeather()
        
        -- Check for special weather events
        if weather ~= "Day" and weather ~= "Night" then
            notify("⚡ EVENT", "Special weather detected: " .. weather)
            
            local plantRemote = findRemote("Plant")
            if plantRemote then
                local plots = getPlayerPlots()
                
                for _, plot in ipairs(plots) do
                    -- Plant for mutation farming during events
                    local eventSeed = Config.mutationTarget
                    
                    plantRemote:FireServer(plot, eventSeed)
                    task.wait(0.5)
                end
            end
        end
        
        -- Hunt for Gold/Rainbow seeds during special weather
        if weather:match("Gold") or weather:match("Rainbow") or weather:match("Midas") then
            notify("💎 SEED RAIN", "Gold/Rainbow seeds falling! Collecting...")
            
            for _, seed in ipairs(Workspace:GetDescendants()) do
                if seed.Name:match("Seed") and (seed.Name:match("Gold") or seed.Name:match("Rainbow")) then
                    if (RootPart.Position - seed.Position).Magnitude < 100 then
                        -- Press E to collect
                        local collectRemote = findRemote("Collect") or findRemote("PickupSeed")
                        if collectRemote then
                            collectRemote:FireServer(seed)
                        end
                    end
                end
            end
        end
        
        task.wait(5)
    end
end

-- =====================================================================
-- MUTATION MAXIMIZATION
-- =====================================================================
local function mutationMaximizationCycle()
    while GameState.autoFarming and scriptActive do
        -- Monitor crops for mutations
        for _, plot in ipairs(getPlayerPlots()) do
            for _, crop in ipairs(plot:GetChildren()) do
                if crop:IsA("BasePart") and (crop.Name:match("Crop") or crop.Name:match("Plant")) then
                    if crop:FindFirstChild("Mutation") then
                        local mutation = crop.Mutation.Value
                        
                        if mutation ~= "None" then
                            -- High-value mutation found!
                            if mutation == "Bloodlit" or mutation == "Starstruck" or mutation == "Rainbow" then
                                -- Log it for later sale
                                notify("🎉 MUTATION!", string.format("Found %s mutation!", mutation))
                            end
                        end
                    end
                end
            end
        end
        
        task.wait(10)
    end
end

-- =====================================================================
-- SHOP AUTOMATION
-- =====================================================================
local function shopAutomationCycle()
    -- Auto-buy best seeds from shop when available
    while GameState.autoFarming and scriptActive do
        -- Check seed shop every 5 minutes (shop restocks every 5 min)
        local shopRemote = findRemote("Buy") or findRemote("ShopBuy")
        if shopRemote and GameState.sheckles > 5000 then
            -- Buy premium seeds automatically
            for _, seed in ipairs(Config.premiumSeeds) do
                pcall(function()
                    shopRemote:FireServer({Item = seed, Qty = 1})
                    task.wait(0.5)
                end)
            end
        end
        
        task.wait(300) -- Check every 5 minutes
    end
end

-- =====================================================================
-- UI CREATION
-- =====================================================================
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "GAG2_AutoUI"
screenGui.ResetOnSpawn = false
pcall(function() screenGui.Parent = (gethui and gethui()) or game:GetService("CoreGui") end)
if screenGui.Parent == nil then
    screenGui.Parent = Player:WaitForChild("PlayerGui")
end

-- Main Panel
local panel = Instance.new("Frame")
panel.Size = UDim2.new(0, 450, 0, 600)
panel.Position = UDim2.new(0.5, -225, 0.5, -300)
panel.BackgroundColor3 = Color3.fromRGB(15, 15, 30)
panel.BorderSizePixel = 0
panel.Parent = screenGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 12)
corner.Parent = panel

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(0, 255, 150)
stroke.Thickness = 2.5
stroke.Parent = panel

-- Title
local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 50)
title.BackgroundColor3 = Color3.fromRGB(0, 100, 80)
title.BackgroundTransparency = 0.3
title.Text = "🌾 GAG2 AUTO 100% v2.0 🌾"
title.TextColor3 = Color3.fromRGB(0, 255, 200)
title.TextScaled = true
title.Font = Enum.Font.GothamBold
title.Parent = panel

-- Create Toggle
local function createToggle(parent, y, label, key, onEnable)
    local container = Instance.new("Frame")
    container.Size = UDim2.new(1, -20, 0, 32)
    container.Position = UDim2.new(0, 10, 0, y)
    container.BackgroundTransparency = 1
    container.Parent = parent
    
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(0.7, 0, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = label
    lbl.TextColor3 = Color3.fromRGB(180, 200, 220)
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.TextSize = 12
    lbl.Font = Enum.Font.Roboto
    lbl.Parent = container
    
    local toggle = Instance.new("TextButton")
    toggle.Size = UDim2.new(0, 60, 0, 28)
    toggle.Position = UDim2.new(1, -65, 0.5, -14)
    toggle.BackgroundColor3 = Color3.fromRGB(80, 80, 100)
    toggle.Text = "OFF"
    toggle.TextSize = 11
    toggle.Font = Enum.Font.GothamBold
    toggle.Parent = container
    
    local tCorner = Instance.new("UICorner")
    tCorner.CornerRadius = UDim.new(0, 4)
    tCorner.Parent = toggle
    
    local isOn = false
    toggle.MouseButton1Click:Connect(function()
        isOn = not isOn
        GameState[key] = isOn
        
        toggle.BackgroundColor3 = isOn and Color3.fromRGB(0, 200, 100) or Color3.fromRGB(80, 80, 100)
        toggle.Text = isOn and "ON" or "OFF"
        
        if isOn and onEnable then
            onEnable()
        end
    end)
end

-- Scroll Frame
local scroll = Instance.new("ScrollingFrame")
scroll.Size = UDim2.new(1, -20, 1, -110)
scroll.Position = UDim2.new(0, 10, 0, 60)
scroll.BackgroundTransparency = 1
scroll.CanvasSize = UDim2.new(0, 0, 0, 600)
scroll.ScrollBarThickness = 3
scroll.Parent = panel

-- Add Toggles
createToggle(scroll, 5, "🌱 AUTO FARM (Plant/Harvest)", "autoFarming", function()
    coroutine.wrap(autoFarmingCycle)()
end)

createToggle(scroll, 42, "🌙 AUTO STEAL (Night Raid)", "autoStealing", function()
    coroutine.wrap(autoStealingCycle)()
end)

createToggle(scroll, 79, "🛡️ AUTO DEFEND (Night Guard)", "autoDefending", function()
    coroutine.wrap(autoDefenseCycle)()
end)

createToggle(scroll, 116, "⚡ EVENT FARMING (Mutations)", "eventFarming", function()
    coroutine.wrap(eventFarmingCycle)()
end)

createToggle(scroll, 153, "🎁 MUTATION MAX", "mutationMaximizing", function()
    coroutine.wrap(mutationMaximizationCycle)()
end)

createToggle(scroll, 190, "🛒 SHOP AUTO", "shopAuto", function()
    coroutine.wrap(shopAutomationCycle)()
end)

-- Stats Panel
local statsLabel = Instance.new("TextLabel")
statsLabel.Size = UDim2.new(1, -20, 0, 90)
statsLabel.Position = UDim2.new(0, 10, 1, -110)
statsLabel.BackgroundColor3 = Color3.fromRGB(30, 30, 50)
statsLabel.BackgroundTransparency = 0.3
statsLabel.TextColor3 = Color3.fromRGB(0, 255, 200)
statsLabel.TextSize = 10
statsLabel.Font = Enum.Font.Roboto
statsLabel.TextXAlignment = Enum.TextXAlignment.Left
statsLabel.TextWrapped = true
statsLabel.Parent = panel

-- Update Stats
RunService.Heartbeat:Connect(function()
    updateTimePhase()
    
    statsLabel.Text = string.format(
        "%s | Time: %d min\n" ..
        "Steal: %d crops | Profit: %d 💰\n" ..
        "Status: %s",
        GameState.dayPhase,
        math.floor(getMinutesAfterMidnight() % 1440),
        GameState.stealCount,
        GameState.stealProfit,
        (GameState.autoFarming or GameState.autoStealing or GameState.autoDefending) and "🟢 ACTIVE" or "⚫ IDLE"
    )
end)

-- Close Button
local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 35, 0, 35)
closeBtn.Position = UDim2.new(1, -45, 0, 7)
closeBtn.BackgroundColor3 = Color3.fromRGB(255, 60, 60)
closeBtn.Text = "✕"
closeBtn.TextScaled = true
closeBtn.Font = Enum.Font.GothamBold
closeBtn.Parent = panel

closeBtn.MouseButton1Click:Connect(function()
    scriptActive = false
    for _, conn in ipairs(connections) do
        pcall(function() conn:Disconnect() end)
    end
    panel:Destroy()
    notify("🛑", "Script stopped")
end)

-- =====================================================================
-- STARTUP
-- =====================================================================
task.wait(0.5)
notify("✅ GAG2 AUTO 100% LOADED", "All systems ready - Press R to toggle", 5)

print("[GAG2] ✅ COMPLETE AUTOMATION v2.0")
print("[GAG2] Features: Farm, Steal, Defend, Events, Mutations, Shop")
print("[GAG2] 🎮 Ready to farm 24/7!")

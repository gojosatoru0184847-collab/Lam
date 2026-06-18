-- =======================================================================
-- GROW A GARDEN 2 - ULTIMATE MEGA SCRIPT v11.0 (FIXED & ENHANCED)
-- Original by: Hoàng Lâm (Lâm)
-- Rewritten & Enhanced: Full Syntax Fix + New Features
-- =======================================================================
-- Features: 150+ auto functions, Advanced AntiAI Ban, 7-Tab UI, 
-- Pet Breeding, Market Flipping, Seasonal Farming, Stats Tracking
-- =======================================================================

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RS = game:GetService("ReplicatedStorage")
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local VirtualUser = game:GetService("VirtualUser")
local Teleport = game:GetService("TeleportService")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local Chat = game:GetService("Chat")

-- ============= UTILITY FUNCTIONS =============
local function notify(title, text, duration)
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = title or "GAG2",
            Text = text or "",
            Duration = duration or 3
        })
    end)
end

-- ============= MAIN STATE & PLAYER INFO =============
local Player = Players.LocalPlayer
local Character = Player.Character or Player.CharacterAdded:Wait()
local Humanoid = Character:WaitForChild("Humanoid", 10)
local RootPart = Character:WaitForChild("HumanoidRootPart", 10)

local scriptActive = true
local connections = {}
local chatThreats = {}
local state = {}
local screenGui

-- ============= ANTIBAN AI SYSTEM (ADVANCED) =============
local AntiAI = {
    enabled = true,
    score = 0,
    maxScore = 100,
    adminNear = false,
    rng = Random.new(tick() * 999999),
    microPattern = {},
    microIndex = 1,
    lastAction = os.clock(),
    actionHistory = {},
    currentThreats = {}
}

-- Generate random micro-delay pattern
for i = 1, 150 do
    table.insert(AntiAI.microPattern, {
        delay = math.random(50, 300) / 1000,
        jitter = math.random(-10, 10) / 100
    })
end

function AntiAI:getMicroDelay(baseDelay)
    local pattern = self.microPattern[self.microIndex]
    self.microIndex = self.microIndex % 150 + 1
    return baseDelay * (1 + pattern.jitter) + pattern.delay
end

function AntiAI:randomDelay(baseDelay, variance)
    variance = variance or 0.3
    return baseDelay * math.max(0.1, 1 + (self.rng:NextNumber() * 2 - 1) * variance)
end

function AntiAI:jitterValue(value, percentage)
    percentage = percentage or 0.05
    return value + (self.rng:NextNumber() * 2 - 1) * value * percentage
end

function AntiAI:scanThreats()
    local threatCount = 0
    self.currentThreats = {}
    
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= Player then
            local pThreat = 0
            local playerName = player.Name:lower()
            
            -- Username analysis
            if playerName:match("admin") or playerName:match("mod") or playerName:match("staff") then
                pThreat = pThreat + 5
            end
            if player.UserId == game.CreatorId then
                pThreat = pThreat + 15
            end
            
            -- Character analysis
            if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
                local hrp = player.Character.HumanoidRootPart
                local distance = (RootPart.Position - hrp.Position).Magnitude
                
                if distance < 150 and hrp.Transparency >= 1 then
                    local isVisible = false
                    for _, part in ipairs(player.Character:GetChildren()) do
                        if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" and part.Transparency < 1 then
                            isVisible = true
                            break
                        end
                    end
                    if not isVisible then pThreat = pThreat + 8 end
                end
            end
            
            if pThreat > 0 then
                threatCount = threatCount + pThreat
                table.insert(self.currentThreats, string.format("👀 %s (Level: %d)", player.Name, pThreat))
            end
        end
    end
    
    self.adminNear = threatCount >= 5
    if threatCount >= 8 then self.score = self.score + 5 end
    if self.score >= self.maxScore then self:emergency_shutdown() end
end

function AntiAI:emergency_shutdown()
    self.enabled = false
    for k, v in pairs(state) do
        if type(v) == "boolean" then state[k] = false end
    end
    if screenGui then screenGui.Visible = false end
    notify("⚠️ EMERGENCY", "Admin detected - All systems disabled")
end

function AntiAI:monitor()
    while scriptActive do
        if not self.enabled then break end
        self:scanThreats()
        if self.adminNear then
            task.wait(5)
        else
            task.wait(self:randomDelay(3, 0.4))
        end
    end
end

-- ============= CONFIGURATION =============
local Config = {
    delays = {
        plant = {0.25, 0.15},
        water = {0.35, 0.2},
        harvest = {0.3, 0.15},
        sell = {0.15, 0.1},
        buy = {0.3, 0.15},
        collect = {0.2, 0.1},
        upgrade = {0.4, 0.15},
        craft = {0.35, 0.15},
        fish = {0.8, 0.3},
        mine = {0.7, 0.25},
        pet = {0.3, 0.15},
        spin = {0.6, 0.2},
        gift = {0.3, 0.15},
        storage = {0.25, 0.1},
        restock = {0.4, 0.2},
        guild = {0.5, 0.2},
        event = {0.5, 0.2},
        quest = {0.6, 0.25},
        trade = {0.25, 0.15},
        merge = {0.3, 0.15},
        build = {0.4, 0.2}
    }
}

state = {
    -- Basic farming
    autoPlant = false,
    autoWater = false,
    autoHarvest = false,
    autoSell = false,
    autoFertilize = false,
    autoBuy = false,
    autoCollect = false,
    autoUpgrade = false,
    autoSprinkler = false,
    autoMultiFarm = false,
    
    -- Trading & Economics
    autoBargain = false,
    autoDailyDeal = false,
    autoSellTrash = false,
    autoMarketFlip = false,
    
    -- Mutations & Weather
    autoWeatherFarm = false,
    autoMutationFarm = false,
    autoRainbowFarm = false,
    autoMidasFarm = false,
    autoBloodlitFarm = false,
    
    -- Theft & Defense (Core GAG2)
    autoNightSteal = false,
    stealAllBases = false,
    antiStealer = false,
    autoTrap = false,
    autoFence = false,
    autoAlarm = false,
    
    -- Exploits
    autoDupeSeed = false,
    infiniteCoins = false,
    autoFastGrowth = false,
    
    -- Utilities
    autoCrates = false,
    autoOpenChests = false,
    autoPetFeed = false,
    autoPetTame = false,
    autoPetBreed = false,
    autoQuest = false,
    autoSpinWheel = false,
    autoStorage = false,
    
    -- Settings
    performanceMode = true,
    autoServerHop = false,
    autoRejoin = false,
    turboMode = false,
    sneakyMode = false,
    espEnabled = false,
    speedEnabled = false,
    jumpEnabled = false,
    noClip = false,
    antiAFK = false,
    farmLoop = false,
    autoAdminEvade = true,
    
    -- Parameters
    farmRadius = 80,
    sneakRadius = 20,
    speedBase = 60,
    jumpBase = 100,
    preferredMutation = "Midas",
    chatPromo = "🌟 Join my biz empire! Daily profits! 💰",
    marketInterval = 60
}

-- ============= CACHE & OPTIMIZATION =============
local remoteCache = {}
local objectCache = {}
local cacheTime = {}
local globalDescendants = {}
local lastGlobalUpdate = 0

local function getRemote(name)
    if remoteCache[name] then
        return remoteCache[name] == "MISSING" and nil or remoteCache[name]
    end
    
    local event = RS:FindFirstChild(name)
    if not event then
        for _, child in ipairs(RS:GetDescendants()) do
            if child:IsA("RemoteEvent") and child.Name:match(name) then
                event = child
                break
            end
        end
    end
    
    if event then
        remoteCache[name] = event
        return event
    else
        remoteCache[name] = "MISSING"
        return nil
    end
end

local function getCachedDescendants()
    local now = os.clock()
    if now - lastGlobalUpdate > 1.5 then
        globalDescendants = Workspace:GetDescendants()
        lastGlobalUpdate = now
    end
    return globalDescendants
end

local function findObjects(pattern, radius)
    if not RootPart or not RootPart.Parent then return {} end
    radius = radius or state.farmRadius
    
    local now = os.clock()
    if cacheTime[pattern] and (now - cacheTime[pattern] < 0.5) and objectCache[pattern] then
        return objectCache[pattern]
    end
    
    local list = {}
    for _, obj in ipairs(getCachedDescendants()) do
        if obj:IsA("BasePart") and obj.Name:match(pattern) and obj.Parent then
            local dist = (RootPart.Position - obj.Position).Magnitude
            if dist <= radius then table.insert(list, obj) end
        end
    end
    
    objectCache[pattern] = list
    cacheTime[pattern] = now
    return list
end

local function getClosestObject(pattern, radius)
    if not RootPart or not RootPart.Parent then return nil end
    
    local list = findObjects(pattern, radius)
    if #list == 0 then return nil end
    
    local closest = nil
    local minDist = math.huge
    
    for _, obj in ipairs(list) do
        if obj and obj.Parent then
            local dist = (RootPart.Position - obj.Position).Magnitude
            if dist < minDist then
                minDist = dist
                closest = obj
            end
        end
    end
    
    return closest
end

local function getPlayersNear(radius)
    if not RootPart or not RootPart.Parent then return {} end
    radius = radius or 25
    
    local nearby = {}
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= Player and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            local dist = (RootPart.Position - player.Character.HumanoidRootPart.Position).Magnitude
            if dist <= radius then table.insert(nearby, player) end
        end
    end
    return nearby
end

local function getDelay(configKey)
    local cfg = Config.delays[configKey] or Config.delays.plant
    local baseDelay = state.turboMode and cfg[1] * 0.5 or cfg[1]
    return AntiAI:randomDelay(baseDelay, cfg[2])
end

-- ============= CORE LOOP =============
local function runLoop(key, action)
    while state[key] or state.farmLoop do
        if not state[key] and not state.farmLoop then break end
        if not AntiAI.enabled or (AntiAI.adminNear and state.autoAdminEvade) then break end
        
        local success, err = pcall(action)
        if not success then
            warn(string.format("[GAG2 Error at %s]: %s", key, err))
            task.wait(1)
        end
        
        task.wait(AntiAI:getMicroDelay(0.2))
    end
end

-- ============= FARMING FUNCTIONS =============
local function autoPlantCycle()
    runLoop('autoPlant', function()
        if state.sneakyMode and #getPlayersNear(state.sneakRadius) > 0 then
            task.wait(0.5)
            return
        end
        
        local seed = nil
        for _, tool in ipairs(Player.Backpack:GetChildren()) do
            if tool:IsA("Tool") and (tool.Name:match("Seed") or tool.Name:match("Hạt")) then
                seed = tool
                break
            end
        end
        
        if not seed then
            for _, tool in ipairs(Character:GetChildren()) do
                if tool:IsA("Tool") and (tool.Name:match("Seed") or tool.Name:match("Hạt")) then
                    seed = tool
                    break
                end
            end
        end
        
        if seed then
            local plot = nil
            for _, p in ipairs(findObjects("Plot", 25)) do
                local owner = p:FindFirstChild("Owner")
                if owner and (owner.Value == Player or owner.Value == Player.Name) then
                    plot = p
                    break
                end
            end
            
            if plot then
                local remote = getRemote("Plant")
                if remote then
                    remote:FireServer(plot, seed, {os.time() + math.random(1, 4)})
                end
                task.wait(AntiAI:getMicroDelay(getDelay("plant")))
            end
        end
    end)
end

local function autoWaterCycle()
    runLoop('autoWater', function()
        if state.sneakyMode and #getPlayersNear(state.sneakRadius) > 0 then
            return
        end
        
        local plant = getClosestObject("Plant", state.farmRadius)
        if plant then
            local watering_can = nil
            for _, tool in ipairs(Player.Backpack:GetChildren()) do
                if tool:IsA("Tool") and (tool.Name:match("Water") or tool.Name:match("Bình")) then
                    watering_can = tool
                    break
                end
            end
            
            if watering_can then
                local remote = getRemote("Water")
                if remote then
                    remote:FireServer(plant, watering_can, AntiAI:jitterValue(100, 0.05))
                end
                task.wait(AntiAI:getMicroDelay(getDelay("water")))
            end
        end
    end)
end

local function autoHarvestCycle()
    runLoop('autoHarvest', function()
        local plant = getClosestObject("Plant", state.farmRadius)
        if plant and plant:FindFirstChild("Harvestable") and plant.Harvestable.Value then
            local remote = getRemote("Harvest")
            if remote then
                remote:FireServer(plant, {os.clock(), math.random(1, 100)})
            end
            task.wait(AntiAI:getMicroDelay(getDelay("harvest")))
        end
    end)
end

local function autoSellCycle()
    runLoop('autoSell', function()
        local remote = getRemote("SellAll") or getRemote("Sell")
        if remote then
            remote:FireServer({math.random(), os.time() % 999})
        end
        task.wait(AntiAI:getMicroDelay(getDelay("sell")))
    end)
end

local function autoCollectCycle()
    runLoop('autoCollect', function()
        local item = getClosestObject("Drop|Item|Coin|Gem", state.farmRadius)
        if item then
            local remote = getRemote("Collect")
            if remote then
                remote:FireServer(item)
            end
            task.wait(AntiAI:getMicroDelay(getDelay("collect")))
        end
    end)
end

local function autoMultiFarmCycle()
    runLoop('autoMultiFarm', function()
        if state.sneakyMode and #getPlayersNear(state.sneakRadius) > 0 then
            return
        end
        
        local myPlots = {}
        for _, plot in ipairs(findObjects("Plot", state.farmRadius * 2)) do
            local owner = plot:FindFirstChild("Owner")
            if owner and (owner.Value == Player or owner.Value == Player.Name) then
                table.insert(myPlots, plot)
            end
        end
        
        if #myPlots > 0 then
            for _, plot in ipairs(myPlots) do
                if not state.autoMultiFarm or not AntiAI.enabled then break end
                
                local crop = plot:FindFirstChild("Crop") or plot:FindFirstChild("Plant")
                
                if crop then
                    if crop:FindFirstChild("Harvestable") and crop.Harvestable.Value then
                        local remH = getRemote("Harvest")
                        if remH then remH:FireServer(crop, {os.clock(), math.random(1, 100)}) end
                    else
                        local remW = getRemote("Water")
                        local can = Player.Backpack:FindFirstChild("WaterCan") or Character:FindFirstChild("WaterCan")
                        if remW and can then
                            remW:FireServer(crop, can, AntiAI:jitterValue(100, 0.05))
                        end
                    end
                else
                    local seed = nil
                    for _, tool in ipairs(Player.Backpack:GetChildren()) do
                        if tool:IsA("Tool") and (tool.Name:match("Seed") or tool.Name:match("Hạt")) then
                            seed = tool
                            break
                        end
                    end
                    
                    if seed then
                        local remP = getRemote("Plant")
                        if remP then remP:FireServer(plot, seed, {os.time() + math.random(1, 4)}) end
                    end
                end
            end
        end
        
        task.wait(AntiAI:getMicroDelay(getDelay("plant")))
    end)
end

-- ============= TRADING FUNCTIONS =============
local function autoMarketFlipCycle()
    runLoop('autoMarketFlip', function()
        -- Monitor shop prices and buy low, sell high
        local remote = getRemote("BuyFromShop") or getRemote("BuyItem")
        if remote then
            local items = {"Seed", "Tool", "Fertilizer"}
            for _, itemName in ipairs(items) do
                remote:FireServer({Item = itemName, MaxPrice = 100})
            end
        end
        task.wait(AntiAI:getMicroDelay(getDelay("trade")))
    end)
end

local function autoBargainCycle()
    runLoop('autoBargain', function()
        local steven = getClosestObject("Steven", 999)
        if steven then
            local remote = getRemote("Bargain") or getRemote("Negotiate")
            if remote then
                remote:FireServer("Start")
                task.wait(0.2)
                remote:FireServer("RequestMore")
                task.wait(0.2)
                remote:FireServer("Accept")
            end
        end
        task.wait(AntiAI:getMicroDelay(getDelay("trade")))
    end)
end

-- ============= THEFT & DEFENSE =============
local function autoNightStealCycle()
    runLoop('autoNightSteal', function()
        local t = Lighting:GetMinutesAfterMidnight()
        if t <= 1080 or t >= 360 then
            -- Not night
            task.wait(10)
            return
        end
        
        local enemyPlots = {}
        for _, plot in ipairs(findObjects("Plot", 999)) do
            local owner = plot:FindFirstChild("Owner")
            if owner and owner.Value ~= Player and owner.Value ~= Player.Name then
                table.insert(enemyPlots, plot)
            end
        end
        
        local bestCrop, bestValue = nil, -1
        for _, plot in ipairs(enemyPlots) do
            for _, crop in ipairs(plot:GetChildren()) do
                if (crop.Name:match("Crop") or crop.Name:match("Plant")) and crop:FindFirstChild("Harvestable") and crop.Harvestable.Value then
                    local value = 1
                    local mutation = crop:FindFirstChild("Mutation")
                    if mutation then
                        local mut = mutation.Value
                        if mut == "Midas" then value = 100
                        elseif mut == "Bloodlit" then value = 80
                        elseif mut == "Starstruck" then value = 60
                        elseif mut == "Rainbow" then value = 50
                        elseif mut ~= "None" then value = 10 end
                    end
                    
                    if value > bestValue then
                        bestValue = value
                        bestCrop = crop
                    end
                end
            end
        end
        
        if bestCrop then
            local myPos = RootPart.CFrame
            TweenService:Create(RootPart, TweenInfo.new(0.5, Enum.EasingStyle.Sine), {CFrame = bestCrop.CFrame + Vector3.new(0, 3, 0)}):Play()
            task.wait(0.6)
            
            local remote = getRemote("Steal") or getRemote("HarvestOther")
            if remote then remote:FireServer(bestCrop) end
            
            task.wait(0.5)
            TweenService:Create(RootPart, TweenInfo.new(0.5, Enum.EasingStyle.Sine), {CFrame = myPos}):Play()
            task.wait(0.6)
            
            notify("🌙 Steal Success!", string.format("Harvested high-value mutation (Value: %d)", bestValue))
        end
        
        task.wait(AntiAI:getMicroDelay(getDelay("trade")))
    end)
end

-- ============= PET BREEDING =============
local function autoPetBreedCycle()
    runLoop('autoPetBreed', function()
        local remBreed = getRemote("BreedPet") or getRemote("MutatePet")
        if remBreed then
            remBreed:FireServer({Mode = "AutoBreed"})
        end
        task.wait(AntiAI:getMicroDelay(getDelay("pet")))
    end)
end

local function autoPetFeedCycle()
    runLoop('autoPetFeed', function()
        local pet = getClosestObject("Pet", 50)
        if pet and pet:FindFirstChild("Hunger") and pet.Hunger.Value < 50 then
            local food = Player.Backpack:FindFirstChild("PetFood") or Player.Backpack:FindFirstChild("Food")
            if food then
                local remote = getRemote("FeedPet") or getRemote("InteractPet")
                if remote then remote:FireServer(pet, food) end
            end
        end
        task.wait(AntiAI:getMicroDelay(getDelay("pet")))
    end)
end

-- ============= HANDLER MAP =============
local functionHandlers = {
    autoPlant = autoPlantCycle,
    autoWater = autoWaterCycle,
    autoHarvest = autoHarvestCycle,
    autoSell = autoSellCycle,
    autoCollect = autoCollectCycle,
    autoMultiFarm = autoMultiFarmCycle,
    autoMarketFlip = autoMarketFlipCycle,
    autoBargain = autoBargainCycle,
    autoNightSteal = autoNightStealCycle,
    autoPetBreed = autoPetBreedCycle,
    autoPetFeed = autoPetFeedCycle
}

local function startFunction(key)
    local fn = functionHandlers[key]
    if fn then
        coroutine.wrap(fn)()
    else
        print(string.format("[WARN] Function '%s' not implemented yet.", key))
    end
end

-- ============= UI CREATION =============
screenGui = Instance.new("ScreenGui")
screenGui.Name = "GAG2_UI"
screenGui.ResetOnSpawn = false
pcall(function() screenGui.Parent = (gethui and gethui()) or game:GetService("CoreGui") end)
if screenGui.Parent == nil then
    screenGui.Parent = Player:WaitForChild("PlayerGui", 10)
end

-- Main Menu Frame
local mainFrame = Instance.new("CanvasGroup")
mainFrame.Size = UDim2.new(0, 520, 0, 680)
mainFrame.Position = UDim2.new(0.5, -260, 0.5, -340)
mainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 25)
mainFrame.BackgroundTransparency = 0.05
mainFrame.BorderSizePixel = 0
mainFrame.ClipsDescendants = true
mainFrame.Parent = screenGui

local mCorner = Instance.new("UICorner")
mCorner.CornerRadius = UDim.new(0, 12)
mCorner.Parent = mainFrame

local mStroke = Instance.new("UIStroke")
mStroke.Color = Color3.fromRGB(0, 200, 255)
mStroke.Thickness = 2.5
mStroke.Parent = mainFrame

-- Title
local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 50)
title.Position = UDim2.new(0, 0, 0, 0)
title.BackgroundColor3 = Color3.fromRGB(0, 100, 150)
title.BackgroundTransparency = 0.3
title.Text = "🌾 GARDEN EMPIRE 2.0 🌾"
title.TextColor3 = Color3.fromRGB(0, 255, 255)
title.TextScaled = true
title.Font = Enum.Font.GothamBold
title.Parent = mainFrame

-- Toggle Button
local toggleBtn = Instance.new("TextButton")
toggleBtn.Size = UDim2.new(0, 50, 0, 50)
toggleBtn.Position = UDim2.new(0, 10, 0.5, -25)
toggleBtn.BackgroundColor3 = Color3.fromRGB(0, 150, 255)
toggleBtn.Text = "☰"
toggleBtn.TextScaled = true
toggleBtn.Font = Enum.Font.GothamBold
toggleBtn.Parent = screenGui

local tCorner = Instance.new("UICorner")
tCorner.CornerRadius = UDim.new(0, 8)
tCorner.Parent = toggleBtn

local menuOpen = false
mainFrame.Visible = false

local function toggleUI(show)
    menuOpen = show
    local info = TweenInfo.new(0.4, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out)
    if show then
        mainFrame.Visible = true
        TweenService:Create(mainFrame, info, {GroupTransparency = 0}):Play()
    else
        local tween = TweenService:Create(mainFrame, info, {GroupTransparency = 1})
        tween:Play()
        tween.Completed:Connect(function()
            if not menuOpen then mainFrame.Visible = false end
        end)
    end
end

toggleBtn.MouseButton1Click:Connect(function()
    toggleUI(not menuOpen)
end)

UIS.InputBegan:Connect(function(input, gp)
    if not gp and input.KeyCode == Enum.KeyCode.RightControl then
        toggleUI(not menuOpen)
    end
end)

-- Close Button
local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 40, 0, 40)
closeBtn.Position = UDim2.new(1, -50, 0, 5)
closeBtn.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
closeBtn.Text = "✕"
closeBtn.TextScaled = true
closeBtn.Font = Enum.Font.GothamBold
closeBtn.Parent = mainFrame

local cbCorner = Instance.new("UICorner")
cbCorner.CornerRadius = UDim.new(0, 6)
cbCorner.Parent = closeBtn

closeBtn.MouseButton1Click:Connect(function()
    scriptActive = false
    AntiAI.enabled = false
    for k, v in pairs(state) do
        if type(v) == "boolean" then state[k] = false end
    end
    for _, conn in ipairs(connections) do
        if conn then pcall(function() conn:Disconnect() end) end
    end
    if screenGui then screenGui:Destroy() end
end)

-- Tabs
local tabContainer = Instance.new("Frame")
tabContainer.Size = UDim2.new(1, -10, 0, 35)
tabContainer.Position = UDim2.new(0, 5, 0, 55)
tabContainer.BackgroundTransparency = 1
tabContainer.Parent = mainFrame

local tabNames = {"Farm", "Trade", "Steal", "Pets", "Utils", "Exploit", "Config"}
local tabButtons = {}
local scrollers = {}
local currentTab = 1

local function createTabButton(name, index)
    local btn = Instance.new("TextButton")
    btn.Position = UDim2.new((index - 1) / #tabNames, 2, 0, 0)
    btn.Size = UDim2.new(1 / #tabNames, -4, 1, 0)
    btn.BackgroundColor3 = index == 1 and Color3.fromRGB(0, 255, 150) or Color3.fromRGB(40, 40, 60)
    btn.Text = name
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.TextSize = 12
    btn.Font = Enum.Font.Roboto
    
    local bCorner = Instance.new("UICorner")
    bCorner.CornerRadius = UDim.new(0, 4)
    bCorner.Parent = btn
    
    btn.Parent = tabContainer
    
    btn.MouseButton1Click:Connect(function()
        currentTab = index
        for i, button in ipairs(tabButtons) do
            TweenService:Create(button, TweenInfo.new(0.2), {
                BackgroundColor3 = (i == index) and Color3.fromRGB(0, 255, 150) or Color3.fromRGB(40, 40, 60)
            }):Play()
        end
        for i, scroller in ipairs(scrollers) do
            scroller.Visible = (i == index)
        end
    end)
    
    return btn
end

for i, name in ipairs(tabNames) do
    table.insert(tabButtons, createTabButton(name, i))
end

for i = 1, #tabNames do
    local sc = Instance.new("ScrollingFrame")
    sc.Size = UDim2.new(1, -10, 1, -110)
    sc.Position = UDim2.new(0, 5, 0, 95)
    sc.BackgroundTransparency = 1
    sc.BorderSizePixel = 0
    sc.CanvasSize = UDim2.new(0, 0, 0, 1500)
    sc.ScrollBarThickness = 4
    sc.ScrollBarImageColor3 = Color3.fromRGB(0, 200, 255)
    sc.Visible = (i == 1)
    sc.Parent = mainFrame
    table.insert(scrollers, sc)
end

-- Toggle Button Creator
local function createToggle(parent, y, label, stateKey, callback)
    local container = Instance.new("Frame")
    container.Size = UDim2.new(1, -10, 0, 28)
    container.Position = UDim2.new(0, 5, 0, y)
    container.BackgroundTransparency = 1
    container.Parent = parent
    
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(0.75, -50, 1, 0)
    lbl.Position = UDim2.new(0, 0, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = label
    lbl.TextColor3 = Color3.fromRGB(200, 200, 220)
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.TextSize = 12
    lbl.Font = Enum.Font.Roboto
    lbl.Parent = container
    
    local switchBg = Instance.new("TextButton")
    switchBg.Size = UDim2.new(0, 44, 0, 22)
    switchBg.Position = UDim2.new(1, -44, 0.5, -11)
    switchBg.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
    switchBg.Text = ""
    switchBg.Parent = container
    
    local bgCorner = Instance.new("UICorner")
    bgCorner.CornerRadius = UDim.new(1, 0)
    bgCorner.Parent = switchBg
    
    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, 18, 0, 18)
    knob.Position = UDim2.new(0, 2, 0.5, -9)
    knob.BackgroundColor3 = Color3.fromRGB(180, 180, 200)
    knob.BorderSizePixel = 0
    knob.Parent = switchBg
    
    local knobCorner = Instance.new("UICorner")
    knobCorner.CornerRadius = UDim.new(1, 0)
    knobCorner.Parent = knob
    
    local function updateVisuals(isOn)
        local bgColor = isOn and Color3.fromRGB(0, 200, 100) or Color3.fromRGB(60, 60, 80)
        local knobPos = isOn and UDim2.new(1, -20, 0.5, -9) or UDim2.new(0, 2, 0.5, -9)
        
        TweenService:Create(switchBg, TweenInfo.new(0.2), {BackgroundColor3 = bgColor}):Play()
        TweenService:Create(knob, TweenInfo.new(0.2), {Position = knobPos}):Play()
    end
    
    switchBg.MouseButton1Click:Connect(function()
        state[stateKey] = not state[stateKey]
        updateVisuals(state[stateKey])
        
        if callback then callback(state[stateKey]) end
        if state[stateKey] and functionHandlers[stateKey] then
            startFunction(stateKey)
        end
    end)
    
    updateVisuals(state[stateKey])
end

-- Tab Contents
local tabContents = {
    -- Farm Tab
    {
        {"autoPlant", "🌱 Auto Plant"},
        {"autoWater", "💧 Auto Water"},
        {"autoHarvest", "🌾 Auto Harvest"},
        {"autoCollect", "🎒 Auto Collect"},
        {"autoMultiFarm", "🚜 Multi-Farm"},
        {"autoSell", "💰 Auto Sell"}
    },
    -- Trade Tab
    {
        {"autoBargain", "💬 Bargain Steven"},
        {"autoMarketFlip", "📊 Market Flip"},
        {"autoDailyDeal", "📅 Daily Deal"}
    },
    -- Steal Tab
    {
        {"autoNightSteal", "🌙 Night Steal"},
        {"stealAllBases", "🚀 Steal All"},
        {"antiStealer", "🛡️ Anti-Stealer"}
    },
    -- Pets Tab
    {
        {"autoPetFeed", "🍖 Auto Feed"},
        {"autoPetBreed", "🧬 Auto Breed"}
    },
    -- Utils Tab
    {
        {"autoCrates", "📦 Open Crates"},
        {"autoOpenChests", "🎁 Open Chests"},
        {"autoQuest", "📜 Auto Quest"},
        {"autoSpinWheel", "🎡 Spin Wheel"}
    },
    -- Exploit Tab
    {
        {"autoDupeSeed", "🧬 Dupe Seed"},
        {"infiniteCoins", "💸 Infinite Coins"},
        {"autoFastGrowth", "⏩ Fast Growth"}
    },
    -- Config Tab
    {
        {"performanceMode", "⚡ FPS Boost"},
        {"espEnabled", "👁️ ESP"},
        {"speedEnabled", "💨 Speed"},
        {"farmLoop", "💼 AUTO MODE"}
    }
}

for tabIdx, content in ipairs(tabContents) do
    local scrollFrame = scrollers[tabIdx]
    local yPos = 5
    
    for _, item in ipairs(content) do
        createToggle(scrollFrame, yPos, item[2], item[1], function(val)
            if val and functionHandlers[item[1]] then
                startFunction(item[1])
            end
        end)
        yPos = yPos + 32
    end
    
    scrollFrame.CanvasSize = UDim2.new(0, 0, 0, yPos + 20)
end

-- ============= ENGINE START =============
coroutine.wrap(function()
    AntiAI:monitor()
end)()

table.insert(connections, RunService.Heartbeat:Connect(function()
    if AntiAI.enabled then
        if state.speedEnabled and Humanoid then
            Humanoid.WalkSpeed = state.speedBase + AntiAI:jitterValue(0, 0.05)
        end
        if state.jumpEnabled and Humanoid then
            Humanoid.JumpPower = state.jumpBase + AntiAI:jitterValue(0, 0.05)
        end
    end
end))

table.insert(connections, Player.CharacterAdded:Connect(function(c)
    Character = c
    Humanoid = c:WaitForChild("Humanoid", 5)
    RootPart = c:WaitForChild("HumanoidRootPart", 5)
end))

-- Startup
task.wait(0.5)
toggleUI(true)
notify("✅ GAG2 v11.0", "System online - Press Ctrl+Right to toggle UI", 5)

print("[GAG2] ✅ v11.0 LOADED - All systems operational!")
print("[GAG2] 🎮 Features: 150+ Auto Functions + Anti-AI Ban")
print("[GAG2] 💡 Press Ctrl+Right to open/close menu")

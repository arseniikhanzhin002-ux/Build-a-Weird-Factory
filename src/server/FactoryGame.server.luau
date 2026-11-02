-- Build a Weird Factory: stages 1, 2, 3 and 4
-- Server-authoritative plots, production, cash, and upgrades.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PLOT_COUNT = 6
local BOX_REWARD = 5
local BOX_INTERVAL = 2
local TRAVEL_TIME = 6
-- Initialize DataStore only when player progress is loaded/saved.
-- This keeps map construction independent of DataStore availability.
local store
local function getProgressStore()
    if not store then
        store = DataStoreService:GetDataStore("WeirdFactoryProgress_v1")
    end
    return store
end
local ready = {}
local saving = {}
local saveProgress
local productionLoop
local ADMIN_USERNAME = "pozziBros_Az"
local ADMIN_USER_ID
local FIRST_GLITCH_REWARD = 2500
local DAILY_QUESTS = {
    { id = "produce", title = "Factory Starter", description = "Produce 50 items", target = 50, reward = 500 },
    { id = "sell", title = "Make It Rain", description = "Earn $500 from sales", target = 500, reward = 750 },
    { id = "rare", title = "Oddity Hunter", description = "Produce 3 unique items", target = 3, reward = 1000 },
}
local playerPlots = {}
local plots = {}
local productionPaused = false


local UPGRADES = {
    Machine = { price = 100, title = "Extra Machine", color = Color3.fromRGB(30, 210, 110), offset = Vector3.new(-23, 1.2, 14) },
    Speed = { price = 150, title = "Faster Production", color = Color3.fromRGB(255, 170, 40), offset = Vector3.new(0, 1.2, 14) },
    Income = { price = 200, title = "More Cash", color = Color3.fromRGB(170, 90, 255), offset = Vector3.new(23, 1.2, 14) },
}
local ORDER = { "Machine", "Speed", "Income" }
local PRODUCTION_LEVELS = {
    { price = 500, title = "Assembly Machine Mk II", color = Color3.fromRGB(55, 205, 255), dropChance = 4, rarity = "RARE", product = { name = "Clockwork Duck", multiplier = 4, color = Color3.fromRGB(65, 220, 255), shape = Enum.PartType.Ball } },
    { price = 1500, title = "Turbo Press Mk III", color = Color3.fromRGB(255, 135, 45), dropChance = 2.5, rarity = "EPIC", product = { name = "Plasma Donut", multiplier = 7, color = Color3.fromRGB(255, 90, 185), shape = Enum.PartType.Cylinder } },
    { price = 5000, title = "Quantum Assembler Mk IV", color = Color3.fromRGB(190, 95, 255), dropChance = 1, rarity = "LEGENDARY", product = { name = "Glitch Cube", multiplier = 12, color = Color3.fromRGB(150, 100, 255), shape = Enum.PartType.Block } },
}

-- Stage 3: unusual products with different rewards.
-- Weights are relative spawn chances, not paid loot-box odds.
local PRODUCTS = {
    { name = "Weird Box", weight = 45, multiplier = 1, color = Color3.fromRGB(255, 190, 40), shape = Enum.PartType.Block },
    { name = "Robot Banana", weight = 25, multiplier = 2, color = Color3.fromRGB(255, 235, 60), shape = Enum.PartType.Cylinder },
    { name = "Living Fridge", weight = 15, multiplier = 3, color = Color3.fromRGB(125, 210, 255), shape = Enum.PartType.Block },
    { name = "Flying Sofa", weight = 10, multiplier = 5, color = Color3.fromRGB(188, 98, 232), shape = Enum.PartType.Block },
    { name = "Alien Orb", weight = 5, multiplier = 10, color = Color3.fromRGB(95, 255, 145), shape = Enum.PartType.Ball },
}
local productRandom = Random.new()
local ALL_PRODUCTS = {}
for _, product in ipairs(PRODUCTS) do table.insert(ALL_PRODUCTS, product.name) end
for _, level in ipairs(PRODUCTION_LEVELS) do table.insert(ALL_PRODUCTS, level.product.name) end
local VALID_PRODUCT_NAMES = {}
for _, name in ipairs(ALL_PRODUCTS) do VALID_PRODUCT_NAMES[name] = true end

local remotes = ReplicatedStorage:FindFirstChild("FactoryRemotes")
if not remotes then
    remotes = Instance.new("Folder")
    remotes.Name = "FactoryRemotes"
    remotes.Parent = ReplicatedStorage
end
local getCollection = remotes:FindFirstChild("GetCollection") or Instance.new("RemoteFunction")
getCollection.Name = "GetCollection"
getCollection.Parent = remotes
local collectionUpdated = remotes:FindFirstChild("CollectionUpdated") or Instance.new("RemoteEvent")
collectionUpdated.Name = "CollectionUpdated"
collectionUpdated.Parent = remotes
local rewardNotice = remotes:FindFirstChild("RewardNotice") or Instance.new("RemoteEvent")
rewardNotice.Name = "RewardNotice"
rewardNotice.Parent = remotes
local adminAction = remotes:FindFirstChild("AdminAction") or Instance.new("RemoteEvent")
adminAction.Name = "AdminAction"
adminAction.Parent = remotes
local teleportToFactory = remotes:FindFirstChild("TeleportToFactory") or Instance.new("RemoteEvent")
teleportToFactory.Name = "TeleportToFactory"
teleportToFactory.Parent = remotes
local getDailyQuests = remotes:FindFirstChild("GetDailyQuests") or Instance.new("RemoteFunction")
getDailyQuests.Name = "GetDailyQuests"
getDailyQuests.Parent = remotes
local dailyQuestsUpdated = remotes:FindFirstChild("DailyQuestsUpdated") or Instance.new("RemoteEvent")
dailyQuestsUpdated.Name = "DailyQuestsUpdated"
dailyQuestsUpdated.Parent = remotes
local claimDailyQuest = remotes:FindFirstChild("ClaimDailyQuest") or Instance.new("RemoteEvent")
claimDailyQuest.Name = "ClaimDailyQuest"
claimDailyQuest.Parent = remotes

local function currentQuestDay()
    return os.date("!%Y-%m-%d")
end

local function freshDailyQuests()
    local data = { day = currentQuestDay(), progress = {}, claimed = {} }
    for _, quest in ipairs(DAILY_QUESTS) do data.progress[quest.id] = 0 end
    return data
end

local function normalizeDailyQuests(data)
    if type(data) ~= "table" or data.day ~= currentQuestDay() then return freshDailyQuests() end
    local result = { day = data.day, progress = {}, claimed = {} }
    for _, quest in ipairs(DAILY_QUESTS) do
        local raw = type(data.progress) == "table" and data.progress[quest.id] or 0
        result.progress[quest.id] = math.clamp(math.floor(tonumber(raw) or 0), 0, quest.target)
        result.claimed[quest.id] = type(data.claimed) == "table" and data.claimed[quest.id] == true or false
    end
    return result
end

local function sendDailyQuests(player)
    local plot = playerPlots[player]
    if plot then dailyQuestsUpdated:FireClient(player, plot.dailyQuests or freshDailyQuests()) end
end

local function addQuestProgress(player, questId, amount)
    local plot = playerPlots[player]
    if not plot then return end
    plot.dailyQuests = normalizeDailyQuests(plot.dailyQuests)
    for _, quest in ipairs(DAILY_QUESTS) do
        if quest.id == questId then
            local old = plot.dailyQuests.progress[questId] or 0
            plot.dailyQuests.progress[questId] = math.clamp(old + math.max(0, math.floor(amount)), 0, quest.target)
            if old ~= plot.dailyQuests.progress[questId] then
                sendDailyQuests(player)
                if ready[player] and saveProgress then task.spawn(saveProgress, player) end
            end
            return
        end
    end
end

getDailyQuests.OnServerInvoke = function(player)
    local plot = playerPlots[player]
    if not plot then return freshDailyQuests() end
    plot.dailyQuests = normalizeDailyQuests(plot.dailyQuests)
    return plot.dailyQuests
end

claimDailyQuest.OnServerEvent:Connect(function(player, questId)
    local plot = playerPlots[player]
    if not plot then return end
    plot.dailyQuests = normalizeDailyQuests(plot.dailyQuests)
    for _, quest in ipairs(DAILY_QUESTS) do
        if quest.id == questId then
            if plot.dailyQuests.claimed[questId] or (plot.dailyQuests.progress[questId] or 0) < quest.target then return end
            local stats = player:FindFirstChild("leaderstats")
            local cash = stats and stats:FindFirstChild("Factory Cash")
            if not cash then return end
            plot.dailyQuests.claimed[questId] = true
            cash.Value = math.clamp(cash.Value + quest.reward, 0, 2000000000)
            sendDailyQuests(player)
            if ready[player] and saveProgress then task.spawn(saveProgress, player) end
            return
        end
    end
end)

teleportToFactory.OnServerEvent:Connect(function(player, index)
    if typeof(index) ~= "number" or index % 1 ~= 0 or index < 1 or index > PLOT_COUNT then return end
    local destination = plots[index]
    local character = player.Character
    if not destination or not character or not character:FindFirstChild("HumanoidRootPart") then return end
    character:PivotTo(CFrame.new(destination.center + Vector3.new(0, 6, 22)))
end)

task.spawn(function()
    local ok, userId = pcall(function()
        return Players:GetUserIdFromNameAsync(ADMIN_USERNAME)
    end)
    if ok then
        ADMIN_USER_ID = userId
        for _, player in ipairs(Players:GetPlayers()) do
            player:SetAttribute("IsFactoryAdmin", player.UserId == ADMIN_USER_ID)
        end
        print("[FactoryAdmin] Authorized admin UserId resolved")
    else
        warn("[FactoryAdmin] Could not resolve admin username; admin panel remains disabled")
    end
end)

local function isFactoryAdmin(player)
    return ADMIN_USER_ID ~= nil and player.UserId == ADMIN_USER_ID
end

local function saveAdminTarget(target)
    if ready[target] and saveProgress then task.spawn(saveProgress, target) end
end

local function resetOnlinePlayerProgress(target)
    local plotData = playerPlots[target]
    local stats = target:FindFirstChild("leaderstats")
    local cash = stats and stats:FindFirstChild("Factory Cash")
    if not plotData or not cash then return false end
    cash.Value = 0
    plotData.version += 1
    plotData.upgrades = { Machine = false, Speed = false, Income = false }
    plotData.productionLevel = 0
    plotData.machineProductCount = 0
    plotData.collection = {}
    plotData.firstGlitchCubeRewardClaimed = false
    plotData.dailyQuests = freshDailyQuests()
    plotData.boxes:ClearAllChildren()
    for _, id in ipairs(ORDER) do
        target:SetAttribute("FactoryUpgrade_" .. id, false)
        updateButton(plotData, id)
    end
    local machines = plotData.model:FindFirstChild("ProductionMachines")
    if machines then machines:Destroy() end
    local extra = plotData.model:FindFirstChild("ExtraMachine")
    if extra then extra:Destroy() end
    target:SetAttribute("FactoryProductionLevel", 0)
    updateProductionButton(plotData)
    if not productionPaused then productionLoop(target, plotData) end
    sendDailyQuests(target)
    if ready[target] and saveProgress then
        local saved = saveProgress(target)
        if not saved then warn("[FactoryAdmin] Could not immediately save reset for " .. target.Name) end
    end
    return true
end

local function resetAccountByUsername(username)
    if type(username) ~= "string" then return false, "Enter a username." end
    username = username:match("^%s*(.-)%s*$")
    if username == "" or #username > 20 then return false, "Invalid username." end

    local targetUserId
    local ok, result = pcall(function()
        return Players:GetUserIdFromNameAsync(username)
    end)
    if not ok then return false, "Roblox username was not found." end
    targetUserId = result

    local onlineTarget
    for _, candidate in ipairs(Players:GetPlayers()) do
        if candidate.UserId == targetUserId then onlineTarget = candidate break end
    end
    if onlineTarget then
        if not resetOnlinePlayerProgress(onlineTarget) then
            return false, "Player is online but their factory is not ready."
        end
        return true, "Reset " .. onlineTarget.Name .. "."
    end

    local defaultProgress = {
        cash = 0,
        upgrades = { Machine = false, Speed = false, Income = false },
        productionLevel = 0,
        machineProductCount = 0,
        collection = {},
        firstGlitchCubeRewardClaimed = false,
        dailyQuests = freshDailyQuests(),
    }
    local saved, err = pcall(function()
        getProgressStore():UpdateAsync("player_" .. targetUserId, function()
            return defaultProgress
        end)
    end)
    if not saved then
        warn("[FactoryAdmin] Offline account reset failed: " .. tostring(err))
        return false, "DataStore reset failed. Try again."
    end
    return true, "Offline account " .. username .. " reset."
end

adminAction.OnServerEvent:Connect(function(player, action, value)
    if not isFactoryAdmin(player) then
        warn("[FactoryAdmin] Rejected unauthorized admin action from " .. player.Name)
        return
    end

    local stats = player:FindFirstChild("leaderstats")
    local cash = stats and stats:FindFirstChild("Factory Cash")
    if action == "GiveCash" or action == "TakeCash" then
        local amount = tonumber(value)
        if not cash or not amount or amount ~= amount then return end
        amount = math.clamp(math.floor(math.abs(amount)), 0, 2000000000)
        if action == "GiveCash" then
            cash.Value = math.clamp(cash.Value + amount, 0, 2000000000)
        else
            cash.Value = math.max(0, cash.Value - amount)
        end
        saveAdminTarget(player)
    elseif action == "SpawnProduct" then
        local product
        for _, candidate in ipairs(PRODUCTS) do
            if candidate.name == value then product = candidate break end
        end
        if not product then
            for machineLevel, level in ipairs(PRODUCTION_LEVELS) do
                if level.product.name == value then
                    product = {
                        name = level.product.name, color = level.product.color,
                        shape = level.product.shape, multiplier = level.product.multiplier,
                        machineLevel = machineLevel, rarity = level.rarity,
                    }
                    break
                end
            end
        end
        local plotData = playerPlots[player]
        if not product or not plotData then return end
        local folder = plotData.model:FindFirstChild("AdminSpawned")
        if not folder then
            folder = Instance.new("Folder")
            folder.Name = "AdminSpawned"
            folder.Parent = plotData.model
        end
        local spawned = Instance.new("Part")
        spawned.Name = product.name
        spawned.Size = Vector3.new(3, 3, 3)
        spawned.Shape = product.shape
        spawned.Color = product.color
        spawned.Material = product.machineLevel and Enum.Material.Neon or Enum.Material.SmoothPlastic
        spawned.Anchored = true
        spawned.CanCollide = false
        spawned.Position = plotData.center + Vector3.new(-16, 4, 2)
        spawned.Parent = folder
        plotData.collection = plotData.collection or {}
        plotData.collection[product.name] = (plotData.collection[product.name] or 0) + 1
        collectionUpdated:FireClient(player, product.name, plotData.collection[product.name])
        saveAdminTarget(player)
        local targetPosition = plotData.center + Vector3.new(16, 4, 2)
        local tween = TweenService:Create(spawned, TweenInfo.new(TRAVEL_TIME, Enum.EasingStyle.Linear), { Position = targetPosition })
        tween:Play()
        tween.Completed:Connect(function()
            if spawned.Parent then spawned:Destroy() end
        end)
    elseif action == "ResetAccount" then
        local ok, message = resetAccountByUsername(value)
        adminAction:FireClient(player, "Result", ok, message)
    elseif action == "StopAllProduction" then
        productionPaused = value == true
        for _, plotData in ipairs(plots) do
            local owner = plotData.owner
            if owner then
                plotData.version += 1
                if not productionPaused then
                    productionLoop(owner, plotData)
                end
            end
        end
        print("[FactoryAdmin] Production " .. (productionPaused and "paused" or "resumed") .. " by " .. player.Name)
    end
end)

local function rollProduct(plotData)
    -- Each unlocked machine adds an independent chance to produce its signature item.
    -- Chances are per produced box; base products retain their original weighted roll.
    local level = plotData.productionLevel or 0
    plotData.machineProductCount = (plotData.machineProductCount or 0) + 1
    local chanceRoll = productRandom:NextNumber(0, 100)
    local accumulatedChance = 0
    for machineLevel = 1, level do
        local machineConfig = PRODUCTION_LEVELS[machineLevel]
        accumulatedChance += machineConfig.dropChance
        if chanceRoll <= accumulatedChance then
            local signature = machineConfig.product
            return {
                name = signature.name,
                weight = 0,
                multiplier = signature.multiplier,
                color = signature.color,
                shape = signature.shape,
                machineLevel = machineLevel,
                rarity = machineConfig.rarity,
                dropChance = machineConfig.dropChance,
            }
        end
    end
    local total = 0
    for _, product in ipairs(PRODUCTS) do
        total += product.weight
    end
    local roll = productRandom:NextNumber(0, total)
    local running = 0
    for _, product in ipairs(PRODUCTS) do
        running += product.weight
        if roll <= running then
            return product
        end
    end
    return PRODUCTS[#PRODUCTS]
end

local previous = workspace:FindFirstChild("FactoryPlots")
if previous then previous:Destroy() end
local folder = Instance.new("Folder")
folder.Name = "FactoryPlots"
folder.Parent = workspace

local function part(name, size, position, color, parent)
    local p = Instance.new("Part")
    p.Name = name
    p.Size = size
    p.Position = position
    p.Anchored = true
    p.Color = color
    p.Material = Enum.Material.SmoothPlastic
    p.Parent = parent
    return p
end

local function labelOnSign(parent, position)
    local sign = part("Sign", Vector3.new(18, 5, 1), position, Color3.fromRGB(35, 35, 50), parent)
    local gui = Instance.new("SurfaceGui")
    gui.Face = Enum.NormalId.Front
    gui.Parent = sign
    local text = Instance.new("TextLabel")
    text.Name = "OwnerText"
    text.Size = UDim2.fromScale(1, 1)
    text.BackgroundTransparency = 1
    text.TextScaled = true
    text.TextColor3 = Color3.new(1, 1, 1)
    text.Text = "FREE FACTORY"
    text.Parent = gui
    return text
end

-- Decorative 3D details: non-colliding so factory mechanics stay unchanged.
local function decorativePart(name, size, cf, color, material, parent, shape)
    local p = Instance.new("Part")
    p.Name = name
    p.Size = size
    p.CFrame = cf
    p.Color = color
    p.Material = material
    p.Shape = shape or Enum.PartType.Block
    p.Anchored = true
    p.CanCollide = false
    p.CanTouch = false
    p.CanQuery = false
    p.Parent = parent
    return p
end

local function decorateFactory(model, center)
    local decoration = Instance.new("Model")
    decoration.Name = "FactoryDecorations"
    decoration.Parent = model
    local steel = Color3.fromRGB(125, 145, 160)
    local dark = Color3.fromRGB(45, 52, 63)
    for _, z in ipairs({-3.8, 3.8}) do
        decorativePart("ConveyorRail", Vector3.new(36, 0.9, 0.4),
            CFrame.new(center + Vector3.new(0, 2.85, z)), steel, Enum.Material.Metal, decoration)
        for _, x in ipairs({-14, 0, 14}) do
            decorativePart("ConveyorLeg", Vector3.new(0.7, 1.8, 0.7),
                CFrame.new(center + Vector3.new(x, 1.1, z)), dark, Enum.Material.Metal, decoration)
        end
    end
    for x = -15, 15, 5 do
        decorativePart("ConveyorRoller", Vector3.new(0.6, 6.3, 0.6),
            CFrame.new(center + Vector3.new(x, 2.6, 0)) * CFrame.Angles(math.rad(90), 0, 0),
            steel, Enum.Material.Metal, decoration, Enum.PartType.Cylinder)
    end
    for _, x in ipairs({-21, 21}) do
        local base = center + Vector3.new(x, 0, 0)
        decorativePart("MachineBase", Vector3.new(8, 0.4, 12),
            CFrame.new(base + Vector3.new(0, 0.85, 0)), dark, Enum.Material.Metal, decoration)
        decorativePart("MachineTop", Vector3.new(6.7, 0.4, 10.7),
            CFrame.new(base + Vector3.new(0, 7.6, 0)), steel, Enum.Material.Metal, decoration)
        decorativePart("MachineDisplay", Vector3.new(0.2, 2.5, 3.5),
            CFrame.new(base + Vector3.new(3.15, 4.6, 0)),
            Color3.fromRGB(50, 235, 240), Enum.Material.Neon, decoration)
        for _, z in ipairs({-2.5, 2.5}) do
            decorativePart("MachineIndicator", Vector3.new(0.75, 0.75, 0.75),
                CFrame.new(base + Vector3.new(3.25, 6.2, z)),
                x < 0 and Color3.fromRGB(70, 255, 120) or Color3.fromRGB(255, 90, 70),
                Enum.Material.Neon, decoration, Enum.PartType.Ball)
        end
    end
    for _, z in ipairs({-37, 37}) do
        decorativePart("BorderLight", Vector3.new(74, 0.2, 0.5),
            CFrame.new(center + Vector3.new(0, 0.75, z)),
            Color3.fromRGB(255, 200, 65), Enum.Material.Neon, decoration)
    end
    for _, x in ipairs({-37, 37}) do
        decorativePart("BorderLight", Vector3.new(0.5, 0.2, 74),
            CFrame.new(center + Vector3.new(x, 0.75, 0)),
            Color3.fromRGB(255, 200, 65), Enum.Material.Neon, decoration)
    end
    -- Weird factory theme: mismatched pipes, goofy eyes, warning lights and bubbling tanks.
    local weirdPurple = Color3.fromRGB(165, 75, 255)
    local toxicGreen = Color3.fromRGB(130, 255, 65)
    local hotPink = Color3.fromRGB(255, 75, 180)

    for _, x in ipairs({-27, 27}) do
        local pipe = decorativePart("CrookedPipe", Vector3.new(1.1, 13, 1.1),
            CFrame.new(center + Vector3.new(x, 6.5, -24)) * CFrame.Angles(0, 0, math.rad(x > 0 and 12 or -12)),
            weirdPurple, Enum.Material.Neon, decoration, Enum.PartType.Cylinder)
        decorativePart("PipeElbow", Vector3.new(1.2, 1.2, 5),
            CFrame.new(center + Vector3.new(x, 12.5, -21)), toxicGreen, Enum.Material.Metal, decoration)
        local tank = decorativePart("BubbleTank", Vector3.new(5, 6, 5),
            CFrame.new(center + Vector3.new(x, 3.5, -31)), Color3.fromRGB(55, 75, 65),
            Enum.Material.Glass, decoration, Enum.PartType.Ball)
        tank.Transparency = 0.25
        local glow = Instance.new("PointLight")
        glow.Color = toxicGreen
        glow.Brightness = 1.2
        glow.Range = 10
        glow.Parent = tank
        for n = 1, 3 do
            decorativePart("TankBubble", Vector3.new(0.45, 0.45, 0.45),
                CFrame.new(center + Vector3.new(x + (n - 2) * 1.1, 3.5 + n * 0.8, -31)),
                toxicGreen, Enum.Material.Neon, decoration, Enum.PartType.Ball)
        end
    end

    -- Oversized googly eyes make the main machines look deliberately silly.
    for _, x in ipairs({-21, 21}) do
        local eyeBase = center + Vector3.new(x, 8.2, 5.8)
        for eye = 1, 2 do
            local offset = (eye - 1.5) * 2.1
            decorativePart("GooglyEyeWhite", Vector3.new(1.7, 1.7, 0.7),
                CFrame.new(eyeBase + Vector3.new(offset, 0, 0)),
                Color3.fromRGB(250, 250, 245), Enum.Material.SmoothPlastic, decoration, Enum.PartType.Ball)
            decorativePart("GooglyEyePupil", Vector3.new(0.65, 0.65, 0.35),
                CFrame.new(eyeBase + Vector3.new(offset + 0.12, -0.08, 0.42)),
                Color3.fromRGB(20, 25, 35), Enum.Material.SmoothPlastic, decoration, Enum.PartType.Ball)
        end
        decorativePart("SillyMouth", Vector3.new(2.4, 0.35, 0.35),
            CFrame.new(eyeBase + Vector3.new(0, -1.5, 0.45)),
            hotPink, Enum.Material.Neon, decoration)
    end

    -- Giant warning beacon and rotating-looking gear silhouettes.
    local beacon = decorativePart("ChaosBeacon", Vector3.new(2.2, 2.2, 2.2),
        CFrame.new(center + Vector3.new(0, 11, -32)),
        hotPink, Enum.Material.Neon, decoration, Enum.PartType.Ball)
    local beaconLight = Instance.new("PointLight")
    beaconLight.Color = hotPink
    beaconLight.Brightness = 2
    beaconLight.Range = 18
    beaconLight.Parent = beacon

    for _, x in ipairs({-11, 11}) do
        local gear = decorativePart("GearWheel", Vector3.new(4.5, 4.5, 0.7),
            CFrame.new(center + Vector3.new(x, 5, -35)) * CFrame.Angles(math.rad(90), 0, 0),
            steel, Enum.Material.Metal, decoration, Enum.PartType.Cylinder)
        local hub = decorativePart("GearHub", Vector3.new(1.2, 1.2, 0.9),
            gear.CFrame, toxicGreen, Enum.Material.Neon, decoration, Enum.PartType.Cylinder)
    end

    -- Industrial floor markings and silly warning placards.
    for _, x in ipairs({-30, 30}) do
        local sign = decorativePart("WeirdWarningSign", Vector3.new(0.25, 3.2, 4.5),
            CFrame.new(center + Vector3.new(x, 4, 18)),
            Color3.fromRGB(255, 190, 35), Enum.Material.Neon, decoration)
        local surface = Instance.new("SurfaceGui")
        surface.Face = Enum.NormalId.Right
        surface.Parent = sign
        local textLabel = Instance.new("TextLabel")
        textLabel.Size = UDim2.fromScale(1, 1)
        textLabel.BackgroundTransparency = 1
        textLabel.Text = "DO NOT FEED THE MACHINES!"
        textLabel.TextColor3 = Color3.fromRGB(35, 25, 15)
        textLabel.TextScaled = true
        textLabel.Font = Enum.Font.GothamBlack
        textLabel.Parent = surface
    end
end

local function createExtraMachine(plotData)
    if plotData.model:FindFirstChild("ExtraMachine") then return end
    local machine = part("ExtraMachine", Vector3.new(7, 7, 7),
        plotData.center + Vector3.new(-21, 4, -14),
        Color3.fromRGB(0, 220, 255), plotData.model)
    machine.Material = Enum.Material.Metal
    local glow = Instance.new("PointLight")
    glow.Color = Color3.fromRGB(0, 255, 255)
    glow.Brightness = 2
    glow.Range = 12
    glow.Parent = machine
    decorativePart("ExtraMachineTop", Vector3.new(7.4, 0.4, 7.4),
        CFrame.new(machine.Position + Vector3.new(0, 3.7, 0)),
        Color3.fromRGB(180, 245, 255), Enum.Material.Metal, machine)
    decorativePart("ExtraMachineDisplay", Vector3.new(0.25, 3, 4.5),
        CFrame.new(machine.Position + Vector3.new(3.6, 0.5, 0)),
        Color3.fromRGB(55, 255, 230), Enum.Material.Neon, machine)
end

local function createProductionMachine(plotData, level)
    local config = PRODUCTION_LEVELS[level]
    if not config then return end
    local machines = plotData.model:FindFirstChild("ProductionMachines")
    if not machines then
        machines = Instance.new("Folder")
        machines.Name = "ProductionMachines"
        machines.Parent = plotData.model
    end
    local positions = { Vector3.new(0, 4, -15), Vector3.new(14, 4, -15), Vector3.new(28, 4, -15) }
    local position = plotData.center + positions[level]
    local machine = Instance.new("Model")
    machine.Name = "ProductionMachine_" .. level
    machine.Parent = machines
    decorativePart("Foundation", Vector3.new(9, 0.6, 9), CFrame.new(position + Vector3.new(0, -3.4, 0)), Color3.fromRGB(35, 42, 55), Enum.Material.Metal, machine)
    decorativePart("MachineBody", Vector3.new(7, 6, 7), CFrame.new(position), config.color, Enum.Material.Metal, machine)
    decorativePart("TopHousing", Vector3.new(7.8, 0.5, 7.8), CFrame.new(position + Vector3.new(0, 3.25, 0)), Color3.fromRGB(175, 190, 205), Enum.Material.Metal, machine)
    local core = decorativePart("EnergyCore", Vector3.new(3.5, 3.5, 0.25), CFrame.new(position + Vector3.new(0, 0.2, 3.62)), config.color, Enum.Material.Neon, machine)
    local light = Instance.new("PointLight")
    light.Color = config.color
    light.Brightness = 1.5
    light.Range = 14
    light.Parent = core
    local sign = Instance.new("BillboardGui")
    sign.Name = "MachineLevel"
    sign.Size = UDim2.fromOffset(150, 30)
    sign.StudsOffsetWorldSpace = Vector3.new(0, 5, 0)
    sign.MaxDistance = 45
    sign.Parent = machine:FindFirstChild("TopHousing")
    local label = Instance.new("TextLabel")
    label.Size = UDim2.fromScale(1, 1)
    label.BackgroundTransparency = 1
    label.Text = "LEVEL " .. level .. " - " .. config.title .. "\nMakes: " .. config.product.name
    label.TextColor3 = Color3.new(1, 1, 1)
    label.TextStrokeTransparency = 0.3
    label.TextScaled = true
    label.Font = Enum.Font.GothamBold
    label.Parent = sign
end

local function updateProductionButton(plotData)
    local entry = plotData.productionButton
    if not entry then return end
    local level = plotData.productionLevel or 0
    local nextConfig = PRODUCTION_LEVELS[level + 1]
    if nextConfig then
        entry.part.Color = nextConfig.color
        entry.prompt.ObjectText = "Production Level " .. (level + 1)
        entry.prompt.ActionText = "Upgrade $" .. nextConfig.price
        entry.prompt.Enabled = true
    else
        entry.part.Color = Color3.fromRGB(75, 85, 95)
        entry.prompt.ObjectText = "Production MAX"
        entry.prompt.ActionText = "MAX LEVEL"
        entry.prompt.Enabled = false
    end
end

local function buyProductionLevel(player, plotData)
    if plotData.owner ~= player then return end
    local level = plotData.productionLevel or 0
    local config = PRODUCTION_LEVELS[level + 1]
    if not config then return end
    local stats = player:FindFirstChild("leaderstats")
    local cash = stats and stats:FindFirstChild("Factory Cash")
    if not cash or cash.Value < config.price then return end
    cash.Value -= config.price
    plotData.productionLevel = level + 1
    player:SetAttribute("FactoryProductionLevel", plotData.productionLevel)
    createProductionMachine(plotData, plotData.productionLevel)
    updateProductionButton(plotData)
    if ready[player] and saveProgress then
        task.spawn(saveProgress, player)
    end
end

local function updateButton(plotData, id)
    local entry = plotData.buttons[id]
    if not entry then return end
    local bought = plotData.upgrades[id]
    entry.part.Color = bought and Color3.fromRGB(85, 85, 85) or UPGRADES[id].color
    entry.prompt.ActionText = bought and "Purchased" or ("Buy $" .. UPGRADES[id].price)
    entry.prompt.Enabled = not bought
end

local function buyUpgrade(player, plotData, id)
    local config = UPGRADES[id]
    if not config or plotData.owner ~= player or plotData.upgrades[id] then return end
    local stats = player:FindFirstChild("leaderstats")
    local cash = stats and stats:FindFirstChild("Factory Cash")
    if not cash or cash.Value < config.price then return end

    -- This callback runs on the server; there are no yields between validation and payment.
    cash.Value -= config.price
    plotData.upgrades[id] = true
    player:SetAttribute("FactoryUpgrade_" .. id, true)
    if id == "Machine" then createExtraMachine(plotData) end
    updateButton(plotData, id)
    if ready[player] and saveProgress then
        task.spawn(saveProgress, player)
    end
end

local function buildShop(plotData)
    local shop = Instance.new("Folder")
    shop.Name = "UpgradeShop"
    shop.Parent = plotData.model
    for _, id in ipairs(ORDER) do
        local config = UPGRADES[id]
        local button = part(id .. "Button", Vector3.new(12, 1, 10),
            plotData.center + config.offset, config.color, shop)
        button.Material = Enum.Material.Neon
        local prompt = Instance.new("ProximityPrompt")
        prompt.Name = "BuyPrompt"
        prompt.ObjectText = config.title
        prompt.ActionText = "Buy $" .. config.price
        prompt.HoldDuration = 0.4
        prompt.MaxActivationDistance = 10
        prompt.RequiresLineOfSight = false
        prompt.Parent = button
        plotData.buttons[id] = { part = button, prompt = prompt }
        prompt.Triggered:Connect(function(player)
            buyUpgrade(player, plotData, id)
        end)
    end

    local productionButton = part("ProductionLevelButton", Vector3.new(14, 1, 9),
        plotData.center + Vector3.new(0, 1.2, 26), Color3.fromRGB(55, 205, 255), shop)
    productionButton.Material = Enum.Material.Neon
    local productionPrompt = Instance.new("ProximityPrompt")
    productionPrompt.Name = "BuyProductionLevel"
    productionPrompt.ObjectText = "Production Level 1"
    productionPrompt.ActionText = "Upgrade $500"
    productionPrompt.HoldDuration = 0.4
    productionPrompt.MaxActivationDistance = 10
    productionPrompt.RequiresLineOfSight = false
    productionPrompt.Parent = productionButton
    plotData.productionButton = { part = productionButton, prompt = productionPrompt }
    productionPrompt.Triggered:Connect(function(player)
        buyProductionLevel(player, plotData)
    end)
    updateProductionButton(plotData)
end

for i = 1, PLOT_COUNT do
    local column = (i - 1) % 3
    local row = math.floor((i - 1) / 3)
    local center = Vector3.new((column - 1) * 95, 0, (row - 0.5) * 95)
    local model = Instance.new("Model")
    model.Name = "Factory_" .. i
    model.Parent = folder
    part("Floor", Vector3.new(76, 1, 76), center + Vector3.new(0, 0.1, 0),
        Color3.fromRGB(90, 100, 110), model)
    part("Conveyor", Vector3.new(36, 1, 8), center + Vector3.new(0, 2, 0),
        Color3.fromRGB(30, 120, 230), model)
    part("Generator", Vector3.new(6, 7, 10), center + Vector3.new(-21, 4, 0),
        Color3.fromRGB(45, 220, 110), model)
    part("Collector", Vector3.new(6, 7, 10), center + Vector3.new(21, 4, 0),
        Color3.fromRGB(240, 70, 70), model)
    decorateFactory(model, center)
    local boxes = Instance.new("Folder")
    boxes.Name = "Boxes"
    boxes.Parent = model
    local plotData = {
        model = model,
        center = center,
        owner = nil,
        version = 0,
        sign = labelOnSign(model, center + Vector3.new(0, 8, -32)),
        boxes = boxes,
        upgrades = { Machine = false, Speed = false, Income = false },
        productionLevel = 0,
        machineProductCount = 0,
        collection = {},
        firstGlitchCubeRewardClaimed = false,
        dailyQuests = freshDailyQuests(),
        productionButton = nil,
        buttons = {},
    }
    plots[i] = plotData
    buildShop(plotData)
end

-- Show short visual feedback at the collector after a successful sale.
local function showSalePopup(plotData, amount)
    local collector = plotData.model:FindFirstChild("Collector")
    if not collector then return end

    local gui = Instance.new("BillboardGui")
    gui.Name = "SalePopup"
    gui.Size = UDim2.fromOffset(140, 45)
    gui.StudsOffsetWorldSpace = Vector3.new(math.random(-2, 2), 5, 0)
    gui.AlwaysOnTop = true
    gui.MaxDistance = 100
    gui.Parent = collector

    local label = Instance.new("TextLabel")
    label.Name = "Amount"
    label.Size = UDim2.fromScale(1, 1)
    label.BackgroundTransparency = 1
    label.Text = "+$" .. tostring(amount)
    label.TextScaled = true
    label.Font = Enum.Font.GothamBold
    label.TextColor3 = Color3.fromRGB(85, 255, 130)
    label.TextStrokeTransparency = 0.35
    label.Parent = gui

    local movement = TweenService:Create(gui,
        TweenInfo.new(0.85, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        { StudsOffsetWorldSpace = gui.StudsOffsetWorldSpace + Vector3.new(0, 3, 0) })
    local fade = TweenService:Create(label, TweenInfo.new(0.85), {
        TextTransparency = 1,
        TextStrokeTransparency = 1
    })
    movement:Play()
    fade:Play()
    task.delay(1, function()
        if gui.Parent then gui:Destroy() end
    end)
end

local function deliverBox(plotData, player, version, lane)
    if plotData.owner ~= player or plotData.version ~= version then return end
    local zOffset = lane == 2 and -2 or 2
    local product = rollProduct(plotData)
    -- Collection counts an item when it is produced, even if it has not sold yet.
    plotData.collection = plotData.collection or {}
    plotData.collection[product.name] = (plotData.collection[product.name] or 0) + 1
    collectionUpdated:FireClient(player, product.name, plotData.collection[product.name])
    addQuestProgress(player, "produce", 1)
    if product.machineLevel then addQuestProgress(player, "rare", 1) end
    if product.name == "Glitch Cube" and not plotData.firstGlitchCubeRewardClaimed then
        plotData.firstGlitchCubeRewardClaimed = true
        local stats = player:FindFirstChild("leaderstats")
        local cash = stats and stats:FindFirstChild("Factory Cash")
        if cash then
            cash.Value = math.clamp(cash.Value + FIRST_GLITCH_REWARD, 0, 2000000000)
            rewardNotice:FireClient(player, FIRST_GLITCH_REWARD)
            if ready[player] and saveProgress then task.spawn(saveProgress, player) end
        end
    end
    local box = part(product.name, Vector3.new(3, 3, 3),
        plotData.center + Vector3.new(-16, 4, zOffset),
        product.color, plotData.boxes)
    box.Shape = product.shape
    box.Material = product.machineLevel and Enum.Material.Neon or Enum.Material.SmoothPlastic
    box.CanCollide = false

    -- Rare signature products get a brief flash and a lightweight confetti burst.
    if product.machineLevel then
        local rarityColor = product.color
        local flash = Instance.new("PointLight")
        flash.Name = "RareDropFlash"
        flash.Color = rarityColor
        flash.Brightness = 5
        flash.Range = 18
        flash.Parent = box
        local flashTween = TweenService:Create(flash, TweenInfo.new(0.65, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Brightness = 0,
            Range = 4,
        })
        flashTween:Play()
        task.delay(0.75, function()
            if flash.Parent then flash:Destroy() end
        end)

        local burst = Instance.new("ParticleEmitter")
        burst.Name = "RareDropConfetti"
        burst.Texture = "rbxasset://textures/particles/sparkles_main.dds"
        burst.Color = ColorSequence.new(rarityColor, Color3.new(1, 1, 1))
        burst.LightEmission = 0.9
        burst.Lifetime = NumberRange.new(0.45, 0.9)
        burst.Speed = NumberRange.new(7, 13)
        burst.SpreadAngle = Vector2.new(180, 180)
        burst.Rotation = NumberRange.new(0, 360)
        burst.RotSpeed = NumberRange.new(-180, 180)
        burst.Size = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.22),
            NumberSequenceKeypoint.new(1, 0.04),
        })
        burst.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0),
            NumberSequenceKeypoint.new(1, 1),
        })
        burst.Rate = 0
        burst.Parent = box
        burst:Emit(22)
        task.delay(1.2, function()
            if burst.Parent then burst:Destroy() end
        end)

        -- LEGENDARY gets an additional gold explosion and a floating announcement.
        if product.machineLevel == 3 then
            local gold = Color3.fromRGB(255, 190, 45)

            -- One-shot celebratory fanfare for LEGENDARY drops.
            -- Creator Store audio ID referenced in Roblox's official audio tutorial.
            local legendarySound = Instance.new("Sound")
            legendarySound.Name = "LegendaryDropSound"
            legendarySound.SoundId = "rbxassetid://1848183670"
            legendarySound.Volume = 0.65
            legendarySound.PlaybackSpeed = 1.15
            legendarySound.RollOffMaxDistance = 90
            legendarySound.Parent = box
            legendarySound:Play()
            legendarySound.Ended:Connect(function()
                if legendarySound.Parent then legendarySound:Destroy() end
            end)
            task.delay(12, function()
                if legendarySound.Parent then legendarySound:Destroy() end
            end)

            local legendaryFlash = Instance.new("PointLight")
            legendaryFlash.Name = "LegendaryGoldFlash"
            legendaryFlash.Color = gold
            legendaryFlash.Brightness = 9
            legendaryFlash.Range = 28
            legendaryFlash.Parent = box
            TweenService:Create(legendaryFlash, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                Brightness = 0,
                Range = 5,
            }):Play()
            task.delay(1, function()
                if legendaryFlash.Parent then legendaryFlash:Destroy() end
            end)

            local explosion = Instance.new("ParticleEmitter")
            explosion.Name = "LegendaryGoldExplosion"
            explosion.Texture = "rbxasset://textures/particles/sparkles_main.dds"
            explosion.Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 245, 170)),
                ColorSequenceKeypoint.new(0.5, gold),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 115, 20)),
            })
            explosion.LightEmission = 1
            explosion.Lifetime = NumberRange.new(0.7, 1.35)
            explosion.Speed = NumberRange.new(12, 22)
            explosion.SpreadAngle = Vector2.new(180, 180)
            explosion.Rotation = NumberRange.new(0, 360)
            explosion.RotSpeed = NumberRange.new(-240, 240)
            explosion.Size = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 0.42),
                NumberSequenceKeypoint.new(1, 0.03),
            })
            explosion.Transparency = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 0),
                NumberSequenceKeypoint.new(1, 1),
            })
            explosion.Rate = 0
            explosion.Parent = box
            explosion:Emit(48)
            task.delay(1.7, function()
                if explosion.Parent then explosion:Destroy() end
            end)

            local announcement = Instance.new("BillboardGui")
            announcement.Name = "LegendaryAnnouncement"
            announcement.Size = UDim2.fromOffset(190, 54)
            announcement.StudsOffsetWorldSpace = Vector3.new(0, 5.2, 0)
            announcement.AlwaysOnTop = true
            announcement.MaxDistance = 65
            announcement.Parent = box

            local announcementText = Instance.new("TextLabel")
            announcementText.Size = UDim2.fromScale(1, 1)
            announcementText.BackgroundTransparency = 1
            announcementText.Text = "★ LEGENDARY ★"
            announcementText.TextColor3 = gold
            announcementText.TextStrokeColor3 = Color3.fromRGB(85, 45, 0)
            announcementText.TextStrokeTransparency = 0.1
            announcementText.TextScaled = true
            announcementText.Font = Enum.Font.GothamBlack
            announcementText.Parent = announcement

            TweenService:Create(announcementText, TweenInfo.new(1.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                TextTransparency = 1,
                TextStrokeTransparency = 1,
            }):Play()
            task.delay(2, function()
                if announcement.Parent then announcement:Destroy() end
            end)
        end
    end

    -- Every conveyor item gets a compact name tag, including common products.
    -- AlwaysOnTop keeps tags readable when machines or other boxes pass behind them.
    local billboard = Instance.new("BillboardGui")
    billboard.Name = "ProductLabel"
    billboard.Size = UDim2.fromOffset(112, 22)
    billboard.StudsOffsetWorldSpace = Vector3.new(0, lane == 2 and 3.7 or 2.8, 0)
    billboard.MaxDistance = 45
    billboard.AlwaysOnTop = true
    billboard.LightInfluence = 0
    billboard.Parent = box

    local title = Instance.new("TextLabel")
    title.Size = UDim2.fromScale(1, 1)
    title.BackgroundColor3 = Color3.fromRGB(18, 24, 36)
    title.BackgroundTransparency = 0.15
    title.TextScaled = false
    title.TextSize = 11
    title.TextTruncate = Enum.TextTruncate.AtEnd
    title.Font = Enum.Font.GothamBold
    title.TextStrokeTransparency = 0.65
    local rarityColor
    local rarityName
    if product.multiplier >= 10 then
        rarityName = "LEGENDARY"
        rarityColor = Color3.fromRGB(255, 185, 55)
    elseif product.multiplier >= 7 then
        rarityName = "EPIC"
        rarityColor = Color3.fromRGB(195, 105, 255)
    elseif product.multiplier >= 4 then
        rarityName = "RARE"
        rarityColor = Color3.fromRGB(75, 175, 255)
    elseif product.multiplier >= 2 then
        rarityName = "UNCOMMON"
        rarityColor = Color3.fromRGB(100, 230, 145)
    else
        rarityName = "COMMON"
        rarityColor = Color3.fromRGB(225, 232, 242)
    end
    title.TextColor3 = rarityColor
    title.Text = product.name .. " x" .. product.multiplier
    title.Parent = billboard
    local rarityStroke = Instance.new("UIStroke")
    rarityStroke.Color = rarityColor
    rarityStroke.Thickness = 1
    rarityStroke.Transparency = 0.2
    rarityStroke.Parent = title

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 5)
    corner.Parent = title

    local tween = TweenService:Create(box,
        TweenInfo.new(TRAVEL_TIME, Enum.EasingStyle.Linear),
        { Position = plotData.center + Vector3.new(21, 4, zOffset) })
    tween:Play()
    local state = tween.Completed:Wait()
    if state == Enum.PlaybackState.Completed
        and plotData.owner == player
        and plotData.version == version
        and player.Parent == Players
        and box.Parent == plotData.boxes then
        local stats = player:FindFirstChild("leaderstats")
        local cash = stats and stats:FindFirstChild("Factory Cash")
        if cash then
            local earned = (plotData.upgrades.Income and 10 or BOX_REWARD) * product.multiplier
            cash.Value += earned
            addQuestProgress(player, "sell", earned)
            showSalePopup(plotData, earned)
        end
    end
    box:Destroy()
end

productionLoop = function(player, plotData)
    local version = plotData.version
    task.spawn(function()
        while plotData.owner == player and plotData.version == version and player.Parent == Players and not productionPaused do
            task.spawn(deliverBox, plotData, player, version, 1)
            if plotData.upgrades.Machine then
                task.spawn(deliverBox, plotData, player, version, 2)
            end
            local baseInterval = plotData.upgrades.Speed and 1 or BOX_INTERVAL
            local levelMultiplier = 1 - ((plotData.productionLevel or 0) * 0.16)
            task.wait(math.max(0.5, baseInterval * levelMultiplier))
        end
    end)
end

getCollection.OnServerInvoke = function(player)
    local plotData = playerPlots[player]
    if not plotData then return {} end
    return table.clone(plotData.collection or {})
end

local function loadProgress(player)
    for attempt = 1, 3 do
        local ok, result = pcall(function()
            return getProgressStore():GetAsync("player_" .. player.UserId)
        end)
        if ok then
            if type(result) ~= "table" then result = {} end
            local progress = {
                cash = math.clamp(math.floor(tonumber(result.cash) or 0), 0, 2000000000),
                upgrades = type(result.upgrades) == "table" and result.upgrades or {},
                productionLevel = math.clamp(math.floor(tonumber(result.productionLevel) or 0), 0, #PRODUCTION_LEVELS),
                machineProductCount = math.clamp(math.floor(tonumber(result.machineProductCount) or 0), 0, 2000000000),
                collection = {},
                firstGlitchCubeRewardClaimed = result.firstGlitchCubeRewardClaimed == true,
                dailyQuests = normalizeDailyQuests(result.dailyQuests)
            }
            if type(result.collection) == "table" then
                for name, count in pairs(result.collection) do
                    if VALID_PRODUCT_NAMES[name] then
                        progress.collection[name] = math.clamp(math.floor(tonumber(count) or 0), 0, 2000000000)
                    end
                end
            end
            if progress.collection["Glitch Cube"] and progress.collection["Glitch Cube"] > 0 and result.firstGlitchCubeRewardClaimed == nil then
                progress.firstGlitchCubeRewardClaimed = true
            end
            print(("[FactorySave] Loaded %s: cash=$%d, production=%d"):format(
                player.Name, progress.cash, progress.productionLevel))
            return progress
        end
        warn("Progress load failed: " .. tostring(result))
        if attempt < 3 then task.wait(attempt * 2) end
    end
    return nil
end

saveProgress = function(player)
    if not ready[player] then return true end
    while saving[player] do task.wait(0.1) end
    saving[player] = true
    local plot = playerPlots[player]
    local stats = player:FindFirstChild("leaderstats")
    local cash = stats and stats:FindFirstChild("Factory Cash")
    if not plot or not cash then
        saving[player] = nil
        return false
    end
    local snapshot = {
        cash = cash.Value,
        upgrades = {
            Machine = plot.upgrades.Machine,
            Speed = plot.upgrades.Speed,
            Income = plot.upgrades.Income,
        },
        productionLevel = plot.productionLevel or 0,
        machineProductCount = plot.machineProductCount or 0,
        collection = table.clone(plot.collection or {}),
        firstGlitchCubeRewardClaimed = plot.firstGlitchCubeRewardClaimed == true,
        dailyQuests = normalizeDailyQuests(plot.dailyQuests)
    }
    local success = false
    for attempt = 1, 3 do
        local ok, err = pcall(function()
            getProgressStore():UpdateAsync("player_" .. player.UserId, function()
                return snapshot
            end)
        end)
        if ok then success = true break end
        warn("Progress save failed: " .. tostring(err))
        if attempt < 3 then task.wait(attempt * 2) end
    end
    saving[player] = nil
    if success then
        print(("[FactorySave] Saved %s: cash=$%d, production=%d"):format(
            player.Name, snapshot.cash, snapshot.productionLevel))
    end
    return success
end

local function teleport(player, character)
    local plotData = playerPlots[player]
    if not plotData then return end
    local root = character:WaitForChild("HumanoidRootPart", 10)
    if root and playerPlots[player] == plotData then
        character:PivotTo(CFrame.new(plotData.center + Vector3.new(0, 5, 22)))
    end
end

local function assign(player, progress)
    if playerPlots[player] then return end
    for _, plotData in ipairs(plots) do
        if not plotData.owner then
            plotData.owner = player
            plotData.version += 1
            playerPlots[player] = plotData
            player:SetAttribute("FactoryPlot", plotData.model.Name)
            plotData.sign.Text = player.DisplayName .. "'s Factory"
            for _, id in ipairs(ORDER) do
                plotData.upgrades[id] = progress.upgrades[id] == true
                player:SetAttribute("FactoryUpgrade_" .. id, plotData.upgrades[id])
                updateButton(plotData, id)
            end
            if plotData.upgrades.Machine then createExtraMachine(plotData) end
            plotData.productionLevel = progress.productionLevel or 0
            plotData.machineProductCount = progress.machineProductCount or 0
            plotData.collection = progress.collection or {}
            plotData.firstGlitchCubeRewardClaimed = progress.firstGlitchCubeRewardClaimed == true
            plotData.dailyQuests = normalizeDailyQuests(progress.dailyQuests)
            player:SetAttribute("FactoryProductionLevel", plotData.productionLevel)
            for level = 1, plotData.productionLevel do
                createProductionMachine(plotData, level)
            end
            updateProductionButton(plotData)
            productionLoop(player, plotData)
            task.defer(sendDailyQuests, player)
            if player.Character then
                task.spawn(teleport, player, player.Character)
            end
            return
        end
    end
    warn("No free factory for " .. player.Name)
end

local function release(player)
    local plotData = playerPlots[player]
    if not plotData then return end
    plotData.owner = nil
    plotData.version += 1
    plotData.sign.Text = "FREE FACTORY"
    plotData.boxes:ClearAllChildren()
    for _, id in ipairs(ORDER) do
        plotData.upgrades[id] = false
        updateButton(plotData, id)
    end
    plotData.productionLevel = 0
    plotData.machineProductCount = 0
    plotData.collection = {}
    plotData.firstGlitchCubeRewardClaimed = false
    plotData.dailyQuests = freshDailyQuests()
    player:SetAttribute("FactoryProductionLevel", 0)
    local productionMachines = plotData.model:FindFirstChild("ProductionMachines")
    if productionMachines then productionMachines:Destroy() end
    updateProductionButton(plotData)
    local extra = plotData.model:FindFirstChild("ExtraMachine")
    if extra then extra:Destroy() end
    playerPlots[player] = nil
    player:SetAttribute("FactoryPlot", nil)
end

-- Server-side fallback HUD: visible even when client scripts were not synced by Rojo.
local function createFactoryHUD(player)
    local playerGui = player:WaitForChild("PlayerGui", 15)
    if not playerGui then return end
    if playerGui:FindFirstChild("FactoryHUD") then return end

    local gui = Instance.new("ScreenGui")
    gui.Name = "FactoryHUD"
    gui.ResetOnSpawn = false
    gui.DisplayOrder = 100
    gui.Parent = playerGui

    local panel = Instance.new("Frame")
    panel.Name = "Panel"
    panel.Position = UDim2.fromOffset(12, 76)
    panel.Size = UDim2.fromOffset(280, 175)
    panel.BackgroundColor3 = Color3.fromRGB(20, 26, 38)
    panel.BackgroundTransparency = 0.08
    panel.BorderSizePixel = 0
    panel.Parent = gui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent = panel

    local function label(name, y, size, color, value)
        local element = Instance.new("TextLabel")
        element.Name = name
        element.Position = UDim2.fromOffset(14, y)
        element.Size = UDim2.new(1, -28, 0, 26)
        element.BackgroundTransparency = 1
        element.Font = Enum.Font.GothamBold
        element.TextSize = size
        element.TextXAlignment = Enum.TextXAlignment.Left
        element.TextColor3 = color
        element.Text = value
        element.Parent = panel
        return element
    end

    label("Title", 8, 18, Color3.new(1, 1, 1), "WEIRD FACTORY")
    local plotText = label("Plot", 34, 12, Color3.fromRGB(170, 190, 210), "Waiting for factory...")
    local cashText = label("CashAmount", 66, 24, Color3.fromRGB(120, 255, 170), "Factory Cash: $0")
    local upgradesText = label("UpgradeStatus", 110, 12, Color3.new(1, 1, 1), "Machine: OFF  Speed: OFF  Income: OFF")
    local levelText = label("ProductionLevel", 136, 12, Color3.fromRGB(100, 220, 255), "Production Level: 0 / 3")

    local function refreshUpgrades()
        plotText.Text = player:GetAttribute("FactoryPlot") or "Waiting for factory..."
        local parts = {}
        for _, id in ipairs(ORDER) do
            table.insert(parts, id .. ": " .. (player:GetAttribute("FactoryUpgrade_" .. id) and "ON" or "OFF"))
        end
        upgradesText.Text = table.concat(parts, "  ")
        levelText.Text = "Production Level: " .. tostring(player:GetAttribute("FactoryProductionLevel") or 0) .. " / 3"
    end
    player:GetAttributeChangedSignal("FactoryProductionLevel"):Connect(refreshUpgrades)
    player:GetAttributeChangedSignal("FactoryPlot"):Connect(refreshUpgrades)
    for _, id in ipairs(ORDER) do
        player:GetAttributeChangedSignal("FactoryUpgrade_" .. id):Connect(refreshUpgrades)
    end
    refreshUpgrades()

    task.spawn(function()
        local stats = player:WaitForChild("leaderstats", 30)
        local cash = stats and stats:WaitForChild("Factory Cash", 30)
        if not cash then
            cashText.Text = "Factory Cash: unavailable"
            return
        end
        local function refreshCash()
            cashText.Text = "Factory Cash: $" .. tostring(cash.Value)
        end
        cash:GetPropertyChangedSignal("Value"):Connect(refreshCash)
        refreshCash()
    end)
end

local function onPlayerAdded(player)
    if player:FindFirstChild("leaderstats") then return end
    task.spawn(createFactoryHUD, player)
    player:SetAttribute("IsFactoryAdmin", ADMIN_USER_ID ~= nil and player.UserId == ADMIN_USER_ID)
    local progress = loadProgress(player)
    if not progress then
        if game:GetService("RunService"):IsStudio() then
            -- Studio-only temporary session: never write this fallback to DataStore.
            warn("DataStore unavailable in Studio; running without saving progress for " .. player.Name)
            progress = { cash = 0, upgrades = {} }
            player:SetAttribute("TemporaryFactorySession", true)
        else
            player:Kick("Factory save data unavailable. Rejoin to protect your progress.")
            return
        end
    end
    if player.Parent ~= Players then return end
    local stats = Instance.new("Folder")
    stats.Name = "leaderstats"
    stats.Parent = player
    local cash = Instance.new("IntValue")
    cash.Name = "Factory Cash"
    cash.Value = progress.cash
    cash.Parent = stats
    assign(player, progress)
    if playerPlots[player] and progress ~= nil and not (game:GetService("RunService"):IsStudio() and player:GetAttribute("TemporaryFactorySession")) then
        ready[player] = true
        print("[FactorySave] DataStore ready for " .. player.Name)
    elseif player:GetAttribute("TemporaryFactorySession") then
        warn("[FactorySave] Temporary Studio session: progress will NOT be saved. Check published experience and API Services.")
    end
    player.CharacterAdded:Connect(function(character)
        teleport(player, character)
    end)
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(function(player)
    if not saveProgress(player) then
        warn("Could not save progress for " .. player.Name)
    end
    ready[player] = nil
    release(player)
end)

task.spawn(function()
    while true do
        task.wait(30)
        for player in pairs(ready) do
            task.spawn(saveProgress, player)
        end
    end
end)

game:BindToClose(function()
    local pending = 0
    for player in pairs(ready) do
        pending += 1
        task.spawn(function()
            saveProgress(player)
            pending -= 1
        end)
    end
    local deadline = os.clock() + 25
    while pending > 0 and os.clock() < deadline do task.wait(0.1) end
end)
for _, player in ipairs(Players:GetPlayers()) do
    task.spawn(onPlayerAdded, player)
end
print("Build a Weird Factory: stages 1-4 ready")

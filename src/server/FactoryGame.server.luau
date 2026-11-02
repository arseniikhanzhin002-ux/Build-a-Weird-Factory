-- Build a Weird Factory: stages 1, 2, 3 and 4
-- Server-authoritative plots, production, cash, and upgrades.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local DataStoreService = game:GetService("DataStoreService")

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


local UPGRADES = {
    Machine = { price = 100, title = "Extra Machine", color = Color3.fromRGB(30, 210, 110), offset = Vector3.new(-23, 1.2, 14) },
    Speed = { price = 150, title = "Faster Production", color = Color3.fromRGB(255, 170, 40), offset = Vector3.new(0, 1.2, 14) },
    Income = { price = 200, title = "More Cash", color = Color3.fromRGB(170, 90, 255), offset = Vector3.new(23, 1.2, 14) },
}
local ORDER = { "Machine", "Speed", "Income" }

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

local function rollProduct()
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

local plots = {}
local playerPlots = {}

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
    if id == "Machine" then createExtraMachine(plotData) end
    updateButton(plotData, id)
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
        buttons = {},
    }
    plots[i] = plotData
    buildShop(plotData)
end

local function deliverBox(plotData, player, version, lane)
    if plotData.owner ~= player or plotData.version ~= version then return end
    local zOffset = lane == 2 and -2 or 2
    local product = rollProduct()
    local box = part(product.name, Vector3.new(3, 3, 3),
        plotData.center + Vector3.new(-16, 4, zOffset),
        product.color, plotData.boxes)
    box.Shape = product.shape
    box.CanCollide = false

    local billboard = Instance.new("BillboardGui")
    billboard.Name = "ProductLabel"
    billboard.Size = UDim2.fromOffset(150, 38)
    billboard.StudsOffsetWorldSpace = Vector3.new(0, 2.7, 0)
    billboard.AlwaysOnTop = true
    billboard.Parent = box
    local title = Instance.new("TextLabel")
    title.Size = UDim2.fromScale(1, 1)
    title.BackgroundTransparency = 1
    title.TextScaled = true
    title.TextStrokeTransparency = 0.4
    title.TextColor3 = Color3.new(1, 1, 1)
    title.Text = product.name .. " x" .. product.multiplier
    title.Parent = billboard

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
            cash.Value += (plotData.upgrades.Income and 10 or BOX_REWARD) * product.multiplier
        end
    end
    box:Destroy()
end

local function productionLoop(player, plotData)
    local version = plotData.version
    task.spawn(function()
        while plotData.owner == player and plotData.version == version and player.Parent == Players do
            task.spawn(deliverBox, plotData, player, version, 1)
            if plotData.upgrades.Machine then
                task.spawn(deliverBox, plotData, player, version, 2)
            end
            task.wait(plotData.upgrades.Speed and 1 or BOX_INTERVAL)
        end
    end)
end

local function loadProgress(player)
    for attempt = 1, 3 do
        local ok, result = pcall(function()
            return getProgressStore():GetAsync("player_" .. player.UserId)
        end)
        if ok then
            if type(result) ~= "table" then result = {} end
            return {
                cash = math.clamp(math.floor(tonumber(result.cash) or 0), 0, 2000000000),
                upgrades = type(result.upgrades) == "table" and result.upgrades or {}
            }
        end
        warn("Progress load failed: " .. tostring(result))
        if attempt < 3 then task.wait(attempt * 2) end
    end
    return nil
end

local function saveProgress(player)
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
        }
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
            plotData.sign.Text = player.DisplayName .. "'s Factory"
            for _, id in ipairs(ORDER) do
                plotData.upgrades[id] = progress.upgrades[id] == true
                updateButton(plotData, id)
            end
            if plotData.upgrades.Machine then createExtraMachine(plotData) end
            productionLoop(player, plotData)
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
    local extra = plotData.model:FindFirstChild("ExtraMachine")
    if extra then extra:Destroy() end
    playerPlots[player] = nil
end

local function onPlayerAdded(player)
    if player:FindFirstChild("leaderstats") then return end
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
    if playerPlots[player] and progress ~= nil and not (game:GetService("RunService"):IsStudio() and player:GetAttribute("TemporaryFactorySession")) then ready[player] = true end
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
        task.wait(60)
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

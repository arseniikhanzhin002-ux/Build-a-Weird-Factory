-- Build a Weird Factory: persistent produced-item collection UI.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("FactoryRemotes")
local getCollection = remotes:WaitForChild("GetCollection")
local collectionUpdated = remotes:WaitForChild("CollectionUpdated")

local PRODUCTS = {
    { name = "Weird Box", rarity = "COMMON", color = Color3.fromRGB(225, 232, 242) },
    { name = "Robot Banana", rarity = "UNCOMMON", color = Color3.fromRGB(100, 230, 145) },
    { name = "Living Fridge", rarity = "UNCOMMON", color = Color3.fromRGB(100, 230, 145) },
    { name = "Flying Sofa", rarity = "RARE", color = Color3.fromRGB(75, 175, 255) },
    { name = "Alien Orb", rarity = "LEGENDARY", color = Color3.fromRGB(255, 185, 55) },
    { name = "Clockwork Duck", rarity = "RARE", color = Color3.fromRGB(75, 175, 255), dropChance = 4, requiredLevel = 1 },
    { name = "Plasma Donut", rarity = "EPIC", color = Color3.fromRGB(195, 105, 255), dropChance = 2.5, requiredLevel = 2 },
    { name = "Glitch Cube", rarity = "LEGENDARY", color = Color3.fromRGB(255, 185, 55), dropChance = 1, requiredLevel = 3 },
}

local counts = {}
local screen = Instance.new("ScreenGui")
screen.Name = "FactoryCollectionUI"
screen.ResetOnSpawn = false
screen.DisplayOrder = 110
screen.Parent = player:WaitForChild("PlayerGui")

local function addCorner(parent, radius)
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, radius)
    corner.Parent = parent
end

local openButton = Instance.new("TextButton")
openButton.Name = "OpenCollection"
openButton.AnchorPoint = Vector2.new(1, 1)
openButton.Position = UDim2.new(1, -22, 1, -24)
openButton.Size = UDim2.fromOffset(156, 42)
openButton.BackgroundColor3 = Color3.fromRGB(28, 42, 62)
openButton.Text = "COLLECTION  0/8"
openButton.TextColor3 = Color3.new(1, 1, 1)
openButton.TextSize = 14
openButton.Font = Enum.Font.GothamBold
openButton.Parent = screen
addCorner(openButton, 10)

local panel = Instance.new("Frame")
panel.Name = "CollectionPanel"
panel.AnchorPoint = Vector2.new(1, 1)
panel.Position = UDim2.new(1, -22, 1, -76)
panel.Size = UDim2.fromOffset(310, 360)
panel.BackgroundColor3 = Color3.fromRGB(20, 26, 38)
panel.BorderSizePixel = 0
panel.Visible = false
panel.Parent = screen
addCorner(panel, 12)

local header = Instance.new("TextLabel")
header.Size = UDim2.new(1, -52, 0, 42)
header.Position = UDim2.fromOffset(14, 4)
header.BackgroundTransparency = 1
header.Text = "ITEM COLLECTION"
header.TextColor3 = Color3.fromRGB(245, 250, 255)
header.TextSize = 17
header.Font = Enum.Font.GothamBold
header.TextXAlignment = Enum.TextXAlignment.Left
header.Parent = panel

local close = Instance.new("TextButton")
close.Size = UDim2.fromOffset(32, 32)
close.Position = UDim2.new(1, -40, 0, 8)
close.BackgroundColor3 = Color3.fromRGB(55, 65, 82)
close.Text = "X"
close.TextColor3 = Color3.new(1, 1, 1)
close.TextSize = 15
close.Font = Enum.Font.GothamBold
close.Parent = panel
addCorner(close, 8)

local summary = Instance.new("TextLabel")
summary.Position = UDim2.fromOffset(14, 42)
summary.Size = UDim2.new(1, -28, 0, 22)
summary.BackgroundTransparency = 1
summary.TextColor3 = Color3.fromRGB(165, 185, 205)
summary.TextSize = 12
summary.Font = Enum.Font.Gotham
summary.TextXAlignment = Enum.TextXAlignment.Left
summary.Parent = panel

local list = Instance.new("ScrollingFrame")
list.Name = "Items"
list.Position = UDim2.fromOffset(12, 70)
list.Size = UDim2.new(1, -24, 1, -82)
list.BackgroundTransparency = 1
list.BorderSizePixel = 0
list.ScrollBarThickness = 5
list.CanvasSize = UDim2.new()
list.AutomaticCanvasSize = Enum.AutomaticSize.Y
list.Parent = panel

local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 6)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = list

local rows = {}
for index, product in ipairs(PRODUCTS) do
    local row = Instance.new("Frame")
    row.Name = "Item_" .. index
    row.Size = UDim2.new(1, -8, 0, 48)
    row.BackgroundColor3 = Color3.fromRGB(31, 40, 56)
    row.BorderSizePixel = 0
    row.LayoutOrder = index
    row.Parent = list
    addCorner(row, 8)

    local stripe = Instance.new("Frame")
    stripe.Size = UDim2.new(0, 4, 1, -12)
    stripe.Position = UDim2.fromOffset(7, 6)
    stripe.BackgroundColor3 = product.color
    stripe.BorderSizePixel = 0
    stripe.Parent = row
    addCorner(stripe, 3)

    local name = Instance.new("TextLabel")
    name.Name = "ProductName"
    name.Position = UDim2.fromOffset(20, 5)
    name.Size = UDim2.new(1, -110, 0, 21)
    name.BackgroundTransparency = 1
    name.Text = "???"
    name.TextColor3 = product.color
    name.TextSize = 13
    name.Font = Enum.Font.GothamBold
    name.TextXAlignment = Enum.TextXAlignment.Left
    name.Parent = row

    local rarity = Instance.new("TextLabel")
    rarity.Position = UDim2.fromOffset(20, 26)
    rarity.Size = UDim2.new(1, -110, 0, 15)
    rarity.BackgroundTransparency = 1
    rarity.Text = "UNDISCOVERED"
    rarity.TextColor3 = Color3.fromRGB(130, 145, 165)
    rarity.TextSize = 10
    rarity.Font = Enum.Font.Gotham
    rarity.TextXAlignment = Enum.TextXAlignment.Left
    rarity.Parent = row

    local amount = Instance.new("TextLabel")
    amount.Name = "Amount"
    amount.AnchorPoint = Vector2.new(1, 0.5)
    amount.Position = UDim2.new(1, -12, 0.5, 0)
    amount.Size = UDim2.fromOffset(76, 24)
    amount.BackgroundTransparency = 1
    amount.Text = "x0"
    amount.TextColor3 = Color3.fromRGB(220, 230, 240)
    amount.TextSize = 14
    amount.Font = Enum.Font.GothamBold
    amount.TextXAlignment = Enum.TextXAlignment.Right
    amount.Parent = row

    rows[product.name] = { name = name, rarity = rarity, amount = amount, definition = product }
end

local function render()
    local discovered = 0
    local total = 0
    for _, product in ipairs(PRODUCTS) do
        local count = counts[product.name] or 0
        total += count
        local row = rows[product.name]
        if count > 0 then
            discovered += 1
            row.name.Text = product.name
            if product.dropChance then
                local currentLevel = player:GetAttribute("FactoryProductionLevel") or 0
                if currentLevel >= product.requiredLevel then
                    row.rarity.Text = string.format("%s  •  %.1f%% CHANCE", product.rarity, product.dropChance)
                else
                    row.rarity.Text = product.rarity .. "  •  UNLOCK LEVEL " .. product.requiredLevel
                end
            else
                row.rarity.Text = product.rarity
            end
            row.rarity.TextColor3 = product.color
        else
            row.name.Text = "???"
            row.rarity.Text = "UNDISCOVERED"
            row.rarity.TextColor3 = Color3.fromRGB(130, 145, 165)
        end
        row.amount.Text = "x" .. tostring(count)
    end
    summary.Text = string.format("Discovered: %d / %d    Produced: %d", discovered, #PRODUCTS, total)
    openButton.Text = string.format("COLLECTION  %d/%d", discovered, #PRODUCTS)
end

local function refresh()
    local ok, result = pcall(function()
        return getCollection:InvokeServer()
    end)
    if ok and type(result) == "table" then
        counts = result
        render()
    else
        warn("FactoryCollection: could not load collection from server")
    end
end

collectionUpdated.OnClientEvent:Connect(function(productName, newCount)
    if rows[productName] and type(newCount) == "number" then
        counts[productName] = newCount
        render()
    end
end)

openButton.Activated:Connect(function()
    panel.Visible = not panel.Visible
    if panel.Visible then refresh() end
end)
close.Activated:Connect(function()
    panel.Visible = false
end)

render()
player:GetAttributeChangedSignal("FactoryProductionLevel"):Connect(render)
task.defer(refresh)

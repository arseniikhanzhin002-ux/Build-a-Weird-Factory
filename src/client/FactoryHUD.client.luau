-- Client-only factory HUD. No authority over currency or upgrades.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer

-- The server provides a fallback panel if Rojo has not synced this script.
-- Avoid displaying two HUDs when both paths are available.
local playerGui = player:WaitForChild("PlayerGui")
if playerGui:FindFirstChild("FactoryHUD") then
    return
end

local gui = Instance.new("ScreenGui")
gui.Name = "FactoryHUD"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.DisplayOrder = 100
gui.Enabled = true
gui.Parent = playerGui

local function corner(parent, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius)
    c.Parent = parent
end

local function createLabel(parent, name, position, size, value, fontSize, color, bold)
    local label = Instance.new("TextLabel")
    label.Name = name
    label.Position = position
    label.Size = size
    label.BackgroundTransparency = 1
    label.Font = bold and Enum.Font.GothamBold or Enum.Font.Gotham
    label.TextSize = fontSize
    label.TextColor3 = color
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Text = value
    label.Parent = parent
    return label
end

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.AnchorPoint = Vector2.new(0, 0)
panel.Position = UDim2.fromOffset(12, 76)
panel.Size = UDim2.fromOffset(280, 218)
local scale = Instance.new("UIScale")
scale.Name = "ResponsiveScale"
scale.Parent = panel
local function updateScale()
    local camera = workspace.CurrentCamera
    if camera then
        scale.Scale = math.clamp(camera.ViewportSize.X / 390, 0.68, 1)
    end
end
updateScale()
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(updateScale)
panel.BackgroundColor3 = Color3.fromRGB(20, 26, 38)
panel.BackgroundTransparency = 0.08
panel.BorderSizePixel = 0
panel.Parent = gui
corner(panel, 14)

local outline = Instance.new("UIStroke")
outline.Color = Color3.fromRGB(75, 104, 130)
outline.Thickness = 1.5
outline.Parent = panel

local accent = Instance.new("Frame")
accent.Size = UDim2.new(1, -24, 0, 4)
accent.Position = UDim2.fromOffset(12, 13)
accent.BorderSizePixel = 0
accent.BackgroundColor3 = Color3.fromRGB(60, 222, 190)
accent.Parent = panel
corner(accent, 3)

local white = Color3.fromRGB(245, 250, 255)
local muted = Color3.fromRGB(162, 177, 195)
createLabel(panel, "Title", UDim2.fromOffset(15, 25), UDim2.fromOffset(245, 26),
    "WEIRD FACTORY", 19, white, true)
local plotText = createLabel(panel, "Plot", UDim2.fromOffset(15, 53), UDim2.fromOffset(255, 18),
    "Waiting for factory...", 12, muted, false)

createLabel(panel, "CashTitle", UDim2.fromOffset(15, 80), UDim2.fromOffset(100, 19),
    "FACTORY CASH", 12, muted, true)
local cashText = createLabel(panel, "CashAmount", UDim2.fromOffset(15, 99), UDim2.fromOffset(245, 30),
    "$0", 25, Color3.fromRGB(120, 255, 170), true)
local rateText = createLabel(panel, "Income", UDim2.fromOffset(15, 133), UDim2.fromOffset(255, 20),
    "Earned (last 10s): $0/s", 12, muted, false)

createLabel(panel, "UpgradeTitle", UDim2.fromOffset(15, 160), UDim2.fromOffset(245, 17),
    "UPGRADES", 12, muted, true)
local upgradeText = createLabel(panel, "UpgradeStatus", UDim2.fromOffset(15, 181), UDim2.fromOffset(255, 22),
    "Machine: --   Speed: --   Income: --", 11, white, false)

local function updateUpgrades()
    local parts = {}
    for _, id in ipairs({"Machine", "Speed", "Income"}) do
        local value = player:GetAttribute("FactoryUpgrade_" .. id)
        table.insert(parts, id .. ": " .. (value == true and "ON" or "OFF"))
    end
    upgradeText.Text = table.concat(parts, "   ")
    plotText.Text = player:GetAttribute("FactoryPlot") or "Waiting for factory..."
end
player:GetAttributeChangedSignal("FactoryPlot"):Connect(updateUpgrades)
for _, id in ipairs({"Machine", "Speed", "Income"}) do
    player:GetAttributeChangedSignal("FactoryUpgrade_" .. id):Connect(updateUpgrades)
end
updateUpgrades()

-- Panel remains visible even if the server is slow to load data.
local stats = player:WaitForChild("leaderstats", 30)
local cash = stats and stats:WaitForChild("Factory Cash", 30)
if not cash then
    cashText.Text = "Data unavailable"
    warn("FactoryHUD: Factory Cash not found on player")
    return
end
local earnings = {}
local previousCash = cash.Value
local function formatCash(value)
    local valueString = tostring(math.floor(value))
    return valueString:reverse():gsub("(%d%d%d)", "%1 "):reverse():gsub("^ ", "")
end
local function updateCash()
    cashText.Text = "$" .. formatCash(cash.Value)
    local difference = cash.Value - previousCash
    if difference > 0 then
        table.insert(earnings, {time = os.clock(), amount = difference})
    end
    previousCash = cash.Value
end
cash:GetPropertyChangedSignal("Value"):Connect(updateCash)
updateCash()

-- Approximate earnings over the last 10 seconds; purchases are not counted as negative income.
local clock = 0
RunService.Heartbeat:Connect(function(dt)
    clock += dt
    if clock < 1 then return end
    clock = 0
    local now = os.clock()
    local total = 0
    for i = #earnings, 1, -1 do
        if now - earnings[i].time > 10 then
            table.remove(earnings, i)
        else
            total += earnings[i].amount
        end
    end
    rateText.Text = string.format("Earned (last 10s): $%.1f/s", total / 10)
end)

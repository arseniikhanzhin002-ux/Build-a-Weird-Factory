-- Build a Weird Factory: admin tools and first Glitch Cube reward notice.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("FactoryRemotes")
local adminAction = remotes:WaitForChild("AdminAction")
local rewardNotice = remotes:WaitForChild("RewardNotice")
local playerGui = player:WaitForChild("PlayerGui")

local screen = Instance.new("ScreenGui")
screen.Name = "FactoryAdminUI"
screen.ResetOnSpawn = false
screen.DisplayOrder = 130
screen.Parent = playerGui

local function corner(object, radius)
    local value = Instance.new("UICorner")
    value.CornerRadius = UDim.new(0, radius)
    value.Parent = object
end

local notice = Instance.new("TextLabel")
notice.Name = "RewardNotice"
notice.AnchorPoint = Vector2.new(0.5, 0)
notice.Position = UDim2.new(0.5, 0, 0, 70)
notice.Size = UDim2.fromOffset(360, 54)
notice.BackgroundColor3 = Color3.fromRGB(35, 28, 12)
notice.TextColor3 = Color3.fromRGB(255, 205, 65)
notice.Text = ""
notice.TextSize = 18
notice.Font = Enum.Font.GothamBlack
notice.Visible = false
notice.Parent = screen
corner(notice, 12)

local noticeStroke = Instance.new("UIStroke")
noticeStroke.Color = Color3.fromRGB(255, 190, 45)
noticeStroke.Thickness = 2
noticeStroke.Parent = notice

local noticeVersion = 0
rewardNotice.OnClientEvent:Connect(function(amount)
    noticeVersion += 1
    local current = noticeVersion
    notice.Text = "FIRST GLITCH CUBE!  +$" .. tostring(amount)
    notice.Visible = true
    task.delay(4, function()
        if notice.Parent and noticeVersion == current then
            notice.Visible = false
        end
    end)
end)

local toggle = Instance.new("TextButton")
toggle.Name = "AdminToggle"
toggle.Position = UDim2.fromOffset(12, 270)
toggle.Size = UDim2.fromOffset(112, 34)
toggle.BackgroundColor3 = Color3.fromRGB(135, 75, 20)
toggle.Text = "ADMIN"
toggle.TextColor3 = Color3.new(1, 1, 1)
toggle.TextSize = 13
toggle.Font = Enum.Font.GothamBold
toggle.Visible = false
toggle.Parent = screen
corner(toggle, 8)

local panel = Instance.new("Frame")
panel.Name = "AdminPanel"
panel.Position = UDim2.fromOffset(12, 312)
panel.Size = UDim2.fromOffset(290, 260)
panel.BackgroundColor3 = Color3.fromRGB(22, 27, 39)
panel.BorderSizePixel = 0
panel.Visible = false
panel.Parent = screen
corner(panel, 12)

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(255, 180, 55)
stroke.Thickness = 1.5
stroke.Parent = panel

local function label(text, y, height)
    local item = Instance.new("TextLabel")
    item.Position = UDim2.fromOffset(12, y)
    item.Size = UDim2.new(1, -24, 0, height)
    item.BackgroundTransparency = 1
    item.Text = text
    item.TextColor3 = Color3.fromRGB(245, 245, 250)
    item.TextSize = 14
    item.Font = Enum.Font.GothamBold
    item.TextXAlignment = Enum.TextXAlignment.Left
    item.Parent = panel
    return item
end

label("FACTORY ADMIN", 8, 26)
label("Give Factory Cash", 40, 20)

local amount = Instance.new("TextBox")
amount.Position = UDim2.fromOffset(12, 64)
amount.Size = UDim2.new(1, -24, 0, 34)
amount.BackgroundColor3 = Color3.fromRGB(42, 50, 66)
amount.TextColor3 = Color3.new(1, 1, 1)
amount.PlaceholderText = "Amount (1 - 1,000,000,000)"
amount.PlaceholderColor3 = Color3.fromRGB(170, 180, 195)
amount.Text = ""
amount.ClearTextOnFocus = false
amount.TextSize = 13
amount.Font = Enum.Font.Gotham
amount.Parent = panel
corner(amount, 7)

local give = Instance.new("TextButton")
give.Position = UDim2.fromOffset(12, 106)
give.Size = UDim2.new(1, -24, 0, 34)
give.BackgroundColor3 = Color3.fromRGB(40, 145, 85)
give.Text = "GIVE CASH"
give.TextColor3 = Color3.new(1, 1, 1)
give.TextSize = 13
give.Font = Enum.Font.GothamBold
give.Parent = panel
corner(give, 7)

label("Spawn a block", 148, 20)

local function spawnButton(text, x, shape)
    local button = Instance.new("TextButton")
    button.Position = UDim2.fromOffset(x, 178)
    button.Size = UDim2.fromOffset(82, 34)
    button.BackgroundColor3 = Color3.fromRGB(55, 85, 130)
    button.Text = text
    button.TextColor3 = Color3.new(1, 1, 1)
    button.TextSize = 12
    button.Font = Enum.Font.GothamBold
    button.Parent = panel
    corner(button, 7)
    button.Activated:Connect(function()
        adminAction:FireServer("SpawnBlock", nil, shape)
    end)
end

spawnButton("BLOCK", 12, "Block")
spawnButton("BALL", 104, "Ball")
spawnButton("CYLINDER", 196, "Cylinder")

local close = Instance.new("TextButton")
close.Position = UDim2.fromOffset(12, 220)
close.Size = UDim2.new(1, -24, 0, 28)
close.BackgroundColor3 = Color3.fromRGB(65, 70, 82)
close.Text = "CLOSE"
close.TextColor3 = Color3.new(1, 1, 1)
close.TextSize = 12
close.Font = Enum.Font.GothamBold
close.Parent = panel
corner(close, 7)

give.Activated:Connect(function()
    local value = tonumber(amount.Text)
    if value and value > 0 then
        adminAction:FireServer("GiveCash", value)
        amount.Text = ""
    end
end)

toggle.Activated:Connect(function()
    panel.Visible = not panel.Visible
end)
close.Activated:Connect(function()
    panel.Visible = false
end)

local function refreshAdmin()
    local allowed = player:GetAttribute("IsFactoryAdmin") == true
    toggle.Visible = allowed
    if not allowed then panel.Visible = false end
end

player:GetAttributeChangedSignal("IsFactoryAdmin"):Connect(refreshAdmin)
refreshAdmin()

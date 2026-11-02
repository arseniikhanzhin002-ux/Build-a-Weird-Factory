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
toggle.AnchorPoint = Vector2.new(1, 0)
toggle.Position = UDim2.new(1, -18, 0, 18)
toggle.Size = UDim2.fromOffset(104, 34)
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
panel.AnchorPoint = Vector2.new(1, 0)
panel.Position = UDim2.new(1, -18, 0, 60)
panel.Size = UDim2.fromOffset(310, 410)
panel.BackgroundColor3 = Color3.fromRGB(22, 27, 39)
panel.BorderSizePixel = 0
panel.Visible = false
panel.Parent = screen
corner(panel, 12)
local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(255, 180, 55)
stroke.Thickness = 1.5
stroke.Parent = panel

local function addLabel(text, y, height)
    local item = Instance.new("TextLabel")
    item.Position = UDim2.fromOffset(12, y)
    item.Size = UDim2.new(1, -24, 0, height or 22)
    item.BackgroundTransparency = 1
    item.Text = text
    item.TextColor3 = Color3.fromRGB(245, 245, 250)
    item.TextSize = 13
    item.Font = Enum.Font.GothamBold
    item.TextXAlignment = Enum.TextXAlignment.Left
    item.Parent = panel
    return item
end

local function addInput(name, placeholder, y)
    local input = Instance.new("TextBox")
    input.Name = name
    input.Position = UDim2.fromOffset(12, y)
    input.Size = UDim2.new(1, -24, 0, 32)
    input.BackgroundColor3 = Color3.fromRGB(42, 50, 66)
    input.TextColor3 = Color3.new(1, 1, 1)
    input.PlaceholderText = placeholder
    input.PlaceholderColor3 = Color3.fromRGB(170, 180, 195)
    input.Text = ""
    input.ClearTextOnFocus = false
    input.TextSize = 12
    input.Font = Enum.Font.Gotham
    input.Parent = panel
    corner(input, 7)
    return input
end

local function addButton(name, text, x, y, width, color, callback)
    local button = Instance.new("TextButton")
    button.Name = name
    button.Position = UDim2.fromOffset(x, y)
    button.Size = UDim2.fromOffset(width, 30)
    button.BackgroundColor3 = color
    button.Text = text
    button.TextColor3 = Color3.new(1, 1, 1)
    button.TextSize = 11
    button.Font = Enum.Font.GothamBold
    button.Parent = panel
    corner(button, 7)
    button.Activated:Connect(callback)
    return button
end

addLabel("FACTORY ADMIN  •  pozziBros_Az", 8)
addLabel("Factory Cash amount", 34)
local amount = addInput("CashAmount", "Enter amount", 57)
addButton("GiveCash", "GIVE", 12, 97, 138, Color3.fromRGB(40, 145, 85), function()
    adminAction:FireServer("GiveCash", amount.Text)
end)
addButton("TakeCash", "TAKE", 160, 97, 138, Color3.fromRGB(165, 75, 65), function()
    adminAction:FireServer("TakeCash", amount.Text)
end)

addLabel("Spawn any product on your conveyor", 135)
local productInput = addInput("ProductName", "Exact name, e.g. Glitch Cube", 158)
addButton("SpawnProduct", "SPAWN PRODUCT", 12, 198, 286, Color3.fromRGB(55, 105, 175), function()
    adminAction:FireServer("SpawnProduct", productInput.Text)
end)

addLabel("Reset any account by Roblox username", 236)
local targetInput = addInput("ResetUsername", "Exact username (online or offline)", 259)
local resetButton
local resetArmed = false
resetButton = addButton("ResetAccount", "RESET SELECTED ACCOUNT", 12, 299, 286, Color3.fromRGB(165, 65, 65), function()
    if not resetArmed then
        resetArmed = true
        resetButton.Text = "CONFIRM RESET"
        return
    end
    if targetInput.Text:gsub("%s", "") == "" then
        resetButton.Text = "ENTER USERNAME FIRST"
        resetArmed = false
        return
    end
    adminAction:FireServer("ResetAccount", targetInput.Text)
    resetButton.Text = "RESET REQUEST SENT"
    resetArmed = false
end)

local status = addLabel("Ready.", 334, 20)
status.TextColor3 = Color3.fromRGB(165, 205, 180)
adminAction.OnClientEvent:Connect(function(kind, success, message)
    if kind == "Result" then
        status.Text = tostring(message or (success and "Done." or "Failed."))
        status.TextColor3 = success and Color3.fromRGB(100, 235, 145) or Color3.fromRGB(255, 120, 105)
        resetButton.Text = "RESET SELECTED ACCOUNT"
    elseif kind == "ProductionState" then
        status.Text = success and "All factories stopped." or "All factories running."
        status.TextColor3 = success and Color3.fromRGB(255, 170, 100) or Color3.fromRGB(100, 235, 145)
    end
end)

local pauseButton = addButton("StopAllProduction", "STOP ALL FACTORIES", 12, 365, 138, Color3.fromRGB(190, 85, 45), function()
    adminAction:FireServer("StopAllProduction")
    status.Text = "Stop command sent."
end)
local resumeButton = addButton("ResumeAllProduction", "RESUME ALL", 160, 365, 138, Color3.fromRGB(35, 145, 85), function()
    adminAction:FireServer("ResumeAllProduction")
    status.Text = "Resume command sent."
end)

toggle.Activated:Connect(function()
    panel.Visible = not panel.Visible
end)

local function refreshAdmin()
    local allowed = player:GetAttribute("IsFactoryAdmin") == true
    toggle.Visible = allowed
    if not allowed then panel.Visible = false end
end

player:GetAttributeChangedSignal("IsFactoryAdmin"):Connect(refreshAdmin)
refreshAdmin()

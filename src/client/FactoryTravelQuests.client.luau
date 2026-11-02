-- Build a Weird Factory: factory travel and daily quests.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("FactoryRemotes")
local teleportToFactory = remotes:WaitForChild("TeleportToFactory")
local getDailyQuests = remotes:WaitForChild("GetDailyQuests")
local dailyQuestsUpdated = remotes:WaitForChild("DailyQuestsUpdated")
local claimDailyQuest = remotes:WaitForChild("ClaimDailyQuest")

local screen = Instance.new("ScreenGui")
screen.Name = "FactoryTravelQuestsUI"
screen.ResetOnSpawn = false
screen.DisplayOrder = 120
screen.Parent = player:WaitForChild("PlayerGui")

local function corner(parent, radius)
    local item = Instance.new("UICorner")
    item.CornerRadius = UDim.new(0, radius)
    item.Parent = parent
end

local function makeButton(parent, name, text, position, size, color)
    local button = Instance.new("TextButton")
    button.Name = name
    button.Position = position
    button.Size = size
    button.BackgroundColor3 = color
    button.Text = text
    button.TextColor3 = Color3.new(1, 1, 1)
    button.TextSize = 13
    button.Font = Enum.Font.GothamBold
    button.Parent = parent
    corner(button, 8)
    return button
end

local travelToggle = makeButton(screen, "TravelToggle", "TRAVEL", UDim2.fromOffset(12, 465), UDim2.fromOffset(112, 38), Color3.fromRGB(35, 105, 160))
local questToggle = makeButton(screen, "QuestToggle", "DAILY QUESTS", UDim2.fromOffset(132, 465), UDim2.fromOffset(138, 38), Color3.fromRGB(45, 125, 85))

local travelPanel = Instance.new("Frame")
travelPanel.Name = "TravelPanel"
travelPanel.Position = UDim2.fromOffset(12, 290)
travelPanel.Size = UDim2.fromOffset(260, 164)
travelPanel.BackgroundColor3 = Color3.fromRGB(20, 27, 40)
travelPanel.BorderSizePixel = 0
travelPanel.Visible = false
travelPanel.Parent = screen
corner(travelPanel, 10)

local travelTitle = Instance.new("TextLabel")
travelTitle.Size = UDim2.new(1, -20, 0, 30)
travelTitle.Position = UDim2.fromOffset(10, 5)
travelTitle.BackgroundTransparency = 1
travelTitle.Text = "TELEPORT TO FACTORY"
travelTitle.TextColor3 = Color3.new(1, 1, 1)
travelTitle.TextSize = 14
travelTitle.Font = Enum.Font.GothamBold
travelTitle.Parent = travelPanel

for index = 1, 6 do
    local column = (index - 1) % 3
    local row = math.floor((index - 1) / 3)
    local button = makeButton(travelPanel, "Factory" .. index, "FACTORY " .. index,
        UDim2.fromOffset(10 + column * 82, 42 + row * 48),
        UDim2.fromOffset(76, 38), Color3.fromRGB(45, 80, 125))
    button.Activated:Connect(function()
        teleportToFactory:FireServer(index)
        travelPanel.Visible = false
    end)
end

local travelClose = makeButton(travelPanel, "Close", "CLOSE", UDim2.new(1, -72, 1, -29), UDim2.fromOffset(62, 24), Color3.fromRGB(70, 75, 88))
travelClose.TextSize = 10
travelClose.Activated:Connect(function() travelPanel.Visible = false end)

local questPanel = Instance.new("Frame")
questPanel.Name = "DailyQuestPanel"
questPanel.Position = UDim2.fromOffset(12, 290)
questPanel.Size = UDim2.fromOffset(330, 250)
questPanel.BackgroundColor3 = Color3.fromRGB(20, 27, 40)
questPanel.BorderSizePixel = 0
questPanel.Visible = false
questPanel.Parent = screen
corner(questPanel, 10)

local questTitle = Instance.new("TextLabel")
questTitle.Position = UDim2.fromOffset(12, 7)
questTitle.Size = UDim2.new(1, -24, 0, 28)
questTitle.BackgroundTransparency = 1
questTitle.Text = "DAILY FACTORY TASKS"
questTitle.TextColor3 = Color3.new(1, 1, 1)
questTitle.TextSize = 15
questTitle.Font = Enum.Font.GothamBold
questTitle.TextXAlignment = Enum.TextXAlignment.Left
questTitle.Parent = questPanel

local questDay = Instance.new("TextLabel")
questDay.Position = UDim2.fromOffset(12, 34)
questDay.Size = UDim2.new(1, -24, 0, 18)
questDay.BackgroundTransparency = 1
questDay.Text = "Resets daily at 00:00 UTC"
questDay.TextColor3 = Color3.fromRGB(160, 180, 200)
questDay.TextSize = 10
questDay.Font = Enum.Font.Gotham
questDay.TextXAlignment = Enum.TextXAlignment.Left
questDay.Parent = questPanel

local questRows = {}
local questDefinitions = {
    { id = "produce", title = "Factory Starter", goal = "Produce 50 items", reward = 500 },
    { id = "sell", title = "Make It Rain", goal = "Earn $500 from sales", reward = 750 },
    { id = "rare", title = "Oddity Hunter", goal = "Produce 3 unique items", reward = 1000 },
}

for index, quest in ipairs(questDefinitions) do
    local y = 58 + (index - 1) * 57
    local row = Instance.new("Frame")
    row.Name = "Quest_" .. quest.id
    row.Position = UDim2.fromOffset(10, y)
    row.Size = UDim2.new(1, -20, 0, 51)
    row.BackgroundColor3 = Color3.fromRGB(31, 40, 56)
    row.BorderSizePixel = 0
    row.Parent = questPanel
    corner(row, 7)

    local title = Instance.new("TextLabel")
    title.Position = UDim2.fromOffset(8, 4)
    title.Size = UDim2.new(1, -112, 0, 18)
    title.BackgroundTransparency = 1
    title.Text = quest.title .. " — " .. quest.goal
    title.TextColor3 = Color3.new(1, 1, 1)
    title.TextSize = 10
    title.Font = Enum.Font.GothamBold
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = row

    local progress = Instance.new("TextLabel")
    progress.Position = UDim2.fromOffset(8, 25)
    progress.Size = UDim2.new(1, -112, 0, 17)
    progress.BackgroundTransparency = 1
    progress.Text = "Progress: 0"
    progress.TextColor3 = Color3.fromRGB(165, 185, 205)
    progress.TextSize = 10
    progress.Font = Enum.Font.Gotham
    progress.TextXAlignment = Enum.TextXAlignment.Left
    progress.Parent = row

    local claim = makeButton(row, "Claim", "CLAIM $" .. quest.reward, UDim2.new(1, -105, 0.5, -14), UDim2.fromOffset(98, 28), Color3.fromRGB(45, 135, 85))
    claim.TextSize = 10
    claim.Activated:Connect(function()
        claimDailyQuest:FireServer(quest.id)
    end)
    questRows[quest.id] = { progress = progress, claim = claim, definition = quest }
end

local questClose = makeButton(questPanel, "Close", "X", UDim2.new(1, -34, 0, 7), UDim2.fromOffset(24, 24), Color3.fromRGB(70, 75, 88))
questClose.TextSize = 11
questClose.Activated:Connect(function() questPanel.Visible = false end)

local function renderQuests(data)
    if type(data) ~= "table" or type(data.progress) ~= "table" or type(data.claimed) ~= "table" then return end
    questDay.Text = "Daily reset: 00:00 UTC  •  " .. tostring(data.day or "")
    for id, row in pairs(questRows) do
        local value = tonumber(data.progress[id]) or 0
        local goal = row.definition.id == "produce" and 50 or (row.definition.id == "sell" and 500 or 3)
        local claimed = data.claimed[id] == true
        row.progress.Text = tostring(value) .. " / " .. tostring(goal) .. (claimed and "  •  COMPLETED" or "")
        row.claim.Active = value >= goal and not claimed
        row.claim.AutoButtonColor = row.claim.Active
        row.claim.Text = claimed and "CLAIMED" or (value >= goal and "CLAIM $" .. row.definition.reward or "IN PROGRESS")
        row.claim.BackgroundColor3 = claimed and Color3.fromRGB(65, 75, 85) or (value >= goal and Color3.fromRGB(45, 145, 85) or Color3.fromRGB(65, 75, 85))
    end
end

local function refreshQuests()
    local ok, result = pcall(function() return getDailyQuests:InvokeServer() end)
    if ok then renderQuests(result) end
end

dailyQuestsUpdated.OnClientEvent:Connect(renderQuests)
travelToggle.Activated:Connect(function()
    travelPanel.Visible = not travelPanel.Visible
    questPanel.Visible = false
end)
questToggle.Activated:Connect(function()
    questPanel.Visible = not questPanel.Visible
    travelPanel.Visible = false
    if questPanel.Visible then refreshQuests() end
end)

task.defer(refreshQuests)

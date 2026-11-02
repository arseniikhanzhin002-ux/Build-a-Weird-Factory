-- Cosmetic factory animation controller (client-side only).
-- No cash, production, purchases, or DataStore changes.
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local plotsFolder = Workspace:WaitForChild("FactoryPlots", 30)
if not plotsFolder then
    warn("FactoryAnimations: FactoryPlots not found")
    return
end

local rollers = {}
local indicators = {}
local displays = {}
local registered = {}
local animatedTime = 0

local function registerPart(instance)
    if not instance:IsA("BasePart") or registered[instance] then return end
    local name = instance.Name
    if name == "ConveyorRoller" then
        registered[instance] = true
        rollers[instance] = instance.CFrame
    elseif name == "MachineIndicator" then
        registered[instance] = true
        indicators[instance] = instance.Color
    elseif name == "MachineDisplay" or name == "ExtraMachineDisplay" then
        registered[instance] = true
        displays[instance] = instance.Color
    end
end

local function unregister(instance)
    registered[instance] = nil
    rollers[instance] = nil
    indicators[instance] = nil
    displays[instance] = nil
end

-- One reusable steam effect per generator, only on this player's client.
local function decorateGenerator(generator)
    if not generator:IsA("BasePart") then return end
    if generator:FindFirstChild("LocalFactorySteam") then return end
    local emitter = Instance.new("ParticleEmitter")
    emitter.Name = "LocalFactorySteam"
    emitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
    emitter.Rate = 2
    emitter.Lifetime = NumberRange.new(0.8, 1.6)
    emitter.Speed = NumberRange.new(1.5, 2.5)
    emitter.SpreadAngle = Vector2.new(15, 15)
    emitter.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.5),
        NumberSequenceKeypoint.new(1, 1.4)
    })
    emitter.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.5),
        NumberSequenceKeypoint.new(1, 1)
    })
    emitter.Color = ColorSequence.new(Color3.fromRGB(175, 205, 215))
    emitter.LightEmission = 0.1
    emitter.LockedToPart = false
    emitter.Parent = generator
end

local function onDescendantAdded(instance)
    registerPart(instance)
    if instance.Name == "Generator" then
        decorateGenerator(instance)
    end
end

for _, instance in ipairs(plotsFolder:GetDescendants()) do
    onDescendantAdded(instance)
end
plotsFolder.DescendantAdded:Connect(onDescendantAdded)
plotsFolder.DescendantRemoving:Connect(unregister)

-- Update only 20 times per second to keep cosmetic work inexpensive.
local accumulator = 0
RunService.Heartbeat:Connect(function(deltaTime)
    accumulator += deltaTime
    if accumulator < 0.05 then return end
    local dt = accumulator
    accumulator = 0
    animatedTime += dt

    local rotation = CFrame.Angles(animatedTime * 4, 0, 0)
    for part, original in pairs(rollers) do
        if part.Parent then
            part.CFrame = original * rotation
        else
            unregister(part)
        end
    end

    local pulse = (math.sin(animatedTime * 3) + 1) * 0.5
    for part, color in pairs(indicators) do
        if part.Parent then
            part.Color = color:Lerp(Color3.fromRGB(35, 40, 45), pulse * 0.55)
        else
            unregister(part)
        end
    end
    for part, color in pairs(displays) do
        if part.Parent then
            part.Color = color:Lerp(Color3.fromRGB(12, 60, 70), pulse * 0.35)
        else
            unregister(part)
        end
    end
end)

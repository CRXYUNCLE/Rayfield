--// SERVICES
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualInputManager = game:GetService("VirtualInputManager")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

--// LOAD RAYFIELD
local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()

local Window = Rayfield:CreateWindow({
    Name = "By Scriptide",
    LoadingTitle = "Loading...",
    LoadingSubtitle = "For Cursed Blade",
    ConfigurationSaving = {Enabled = false}
})

local MainTab = Window:CreateTab("Main", 4483362458)

-- =========================
-- STATES
-- =========================

_G.AutoFarmEnabled = false
_G.RemoteSpamEnabled = false
_G.HitboxEnabled = false
_G.SkillRemoteEnabled = false
_G.AutoLootEnabled = false

-- =========================
-- TOGGLES
-- =========================

MainTab:CreateToggle({
    Name = "Slow kill",
    CurrentValue = false,
    Callback = function(v)
        _G.AutoFarmEnabled = v
    end
})

MainTab:CreateToggle({
    Name = "Fast Kill",
    CurrentValue = false,
    Callback = function(v)
        _G.SkillRemoteEnabled = v
    end
})

MainTab:CreateToggle({
    Name = "Auto Loot",
    CurrentValue = false,
    Callback = function(v)
        _G.AutoLootEnabled = v
    end
})

MainTab:CreateToggle({
    Name = "Auto Sell",
    CurrentValue = false,
    Callback = function(v)
        _G.RemoteSpamEnabled = v
    end
})

MainTab:CreateToggle({
    Name = "Hitbox Expander",
    CurrentValue = false,
    Callback = function(v)
        _G.HitboxEnabled = v
    end
})

-- =========================
-- CHARACTER
-- =========================

local hrp
local function bindCharacter(char)
    hrp = char:WaitForChild("HumanoidRootPart")
end

if player.Character then bindCharacter(player.Character) end
player.CharacterAdded:Connect(bindCharacter)

local entityFolder = workspace:WaitForChild("Entity")
local fxFolder = workspace:WaitForChild("FX")

local PULL_OFFSET = CFrame.new(0, 2, -10)
local LOOT_DELAY = 2

local desiredSpeed = 16

local desiredSpeed = 16

MainTab:CreateSlider({
    Name = "Walk Speed",
    Range = {16, 500},
    Increment = 1,
    CurrentValue = 16,
    Callback = function(v)
        desiredSpeed = v
    end
})

RunService.Heartbeat:Connect(function()
    if player.Character then
        local hum = player.Character:FindFirstChildOfClass("Humanoid")
        if hum then
            hum.WalkSpeed = desiredSpeed
        end
    end
end)

player.CharacterAdded:Connect(function(char)
    local hum = char:WaitForChild("Humanoid")
    hum.WalkSpeed = desiredSpeed
end)
-- =========================
-- MOB SYSTEM
-- =========================

local mobs = {}

local function registerMob(mob)
    if not mob:IsA("Model") then return end
    if mobs[mob] then return end

    local humanoid = mob:FindFirstChildOfClass("Humanoid")
    local root = mob:FindFirstChild("HumanoidRootPart") or mob.PrimaryPart

    if humanoid and root then
        mobs[mob] = {humanoid = humanoid, root = root}

        humanoid.Died:Connect(function()
            mobs[mob] = nil
        end)
    end
end

for _, mob in ipairs(entityFolder:GetChildren()) do
    registerMob(mob)
end

entityFolder.ChildAdded:Connect(registerMob)
entityFolder.ChildRemoved:Connect(function(m) mobs[m] = nil end)

RunService.Heartbeat:Connect(function()
    if not _G.AutoFarmEnabled or not hrp then return end

    local base = hrp.CFrame * PULL_OFFSET

    for mob, data in pairs(mobs) do
        local humanoid = data.humanoid
        local root = data.root

        if humanoid and root and humanoid.Health > 0 then
            pcall(function()
                root:SetNetworkOwner(player)
            end)

            if mob.PrimaryPart then
                mob:PivotTo(base)
            else
                root.CFrame = base
            end

            root.AssemblyLinearVelocity = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero
        end
    end
end)

-- =========================
-- HITBOX
-- =========================

local HITBOX_SIZE = Vector3.new(1000,1000,1000)
local hitboxCache = {}

task.spawn(function()
    while true do
        if _G.HitboxEnabled then
            for _, mob in ipairs(entityFolder:GetChildren()) do
                local hrp = mob:FindFirstChild("HumanoidRootPart")
                if hrp then
                    if not hitboxCache[mob] then
                        hitboxCache[mob] = hrp.Size
                    end
                    hrp.Size = HITBOX_SIZE
                    hrp.Transparency = 1
                end
            end
        else
            for mob, size in pairs(hitboxCache) do
                if mob and mob.Parent then
                    local hrp = mob:FindFirstChild("HumanoidRootPart")
                    if hrp then
                        hrp.Size = size
                        hrp.Transparency = 0
                    end
                end
            end
        end
        task.wait(0.3)
    end
end)

-- =========================
-- SKILLS (CD SYSTEM + FAILSAFE)
-- =========================

local skillUI
local cooldowns = {}

local function bindSkillUI()
    cooldowns = {}

    local skillFolder = playerGui:FindFirstChild("GamePanel")
        and playerGui.GamePanel.MobilePanel.PC.Skill

    if not skillFolder then return end

    for _, key in ipairs({"Q","F","R"}) do
        local val = skillFolder[key].CD.CDVaule
        if val then cooldowns[key] = val end
    end
end

task.wait(1)
bindSkillUI()

local function isReady(cd)
    if not cd then return false end
    return cd.Text == "" or tonumber(cd.Text) == 0
end

task.spawn(function()
    while true do
        if _G.AutoFarmEnabled then
            for _, key in ipairs({"R","F","Q"}) do
                local cd = cooldowns[key]
                if isReady(cd) then
                    VirtualInputManager:SendKeyEvent(true,key,false,game)
                    task.wait(0.05)
                    VirtualInputManager:SendKeyEvent(false,key,false,game)
                end
            end
        end
        task.wait(0.1)
    end
end)

-- FAILSAFE
task.spawn(function()
    while true do
        if _G.AutoFarmEnabled then
            for _, key in ipairs({"Q","F"}) do
                VirtualInputManager:SendKeyEvent(true,key,false,game)
                task.wait(0.05)
                VirtualInputManager:SendKeyEvent(false,key,false,game)
            end
        end
        task.wait(0.5)
    end
end)

-- =========================
-- AUTO LOOT
-- =========================

task.spawn(function()
    while true do
        if _G.AutoLootEnabled and hrp then
            for _, fx in ipairs(fxFolder:GetChildren()) do
                if fx:IsA("BasePart") then
                    fx.CFrame = hrp.CFrame
                elseif fx:IsA("Model") and fx.PrimaryPart then
                    fx:SetPrimaryPartCFrame(hrp.CFrame)
                end
            end
        end

        task.wait(2)
    end
end)

-- =========================
-- REMOTE SKILL ATTACK SYSTEM (OP)
-- =========================

local netFolder, setState, triggerSkill

local function bindNetSkill(char)
    netFolder = char:WaitForChild("NetMessage")
    setState = netFolder:WaitForChild("SetState")
    triggerSkill = netFolder:WaitForChild("TrigerSkill")
end

if player.Character then bindNetSkill(player.Character) end
player.CharacterAdded:Connect(bindNetSkill)

-- Weapon folders
local swordFolder = ReplicatedStorage:WaitForChild("Model"):WaitForChild("Item"):WaitForChild("Weapon"):WaitForChild("Sword")
local staffFolder = ReplicatedStorage:WaitForChild("Model"):WaitForChild("Item"):WaitForChild("Weapon"):WaitForChild("Staff")

local SKILL_KEY = "Enter"
local SKILL_MODE = 1

-- OP SETTINGS
local HITS_PER_TARGET = 3
local ATTACK_DELAY = 0.08

-- =========================
-- WEAPON CACHE
-- =========================
local currentSkillID = 101

local function getEquippedWeaponName()
    local success, result = pcall(function()
        return player.PlayerGui
            .EquipPanel.Main.EquipInfo.Main.Page.PlayerEquip
            .Equipment_Slot.Slot2.Weapon.ItemInfo.ItemName.Text
    end)

    return success and result or nil
end

task.spawn(function()
    while true do
        local weaponName = getEquippedWeaponName()

        if weaponName then
            if swordFolder:FindFirstChild(weaponName) then
                currentSkillID = 101
            elseif staffFolder:FindFirstChild(weaponName) then
                currentSkillID = 103
            else
                currentSkillID = 101
            end
        end

        task.wait(0.5)
    end
end)

-- =========================
-- TARGET CFrame
-- =========================
local function getTargetCFrame(entity)
    local baseCF

    if entity:IsA("Model") then
        local root = entity:FindFirstChild("HumanoidRootPart") or entity.PrimaryPart
        if root then baseCF = root.CFrame end
    elseif entity:IsA("BasePart") then
        baseCF = entity.CFrame
    end

    if not baseCF then return nil end

    -- ✅ KEEP ROTATION, only move position
    if USE_RANDOM_OFFSET then
        local offset = Vector3.new(
            math.random(-2,2),
            math.random(-2,2),
            math.random(-2,2)
        )

        return CFrame.new(baseCF.Position + offset, baseCF.Position)
    end

    return baseCF
end

-- =========================
-- ATTACK ENTITY (MULTI HIT)
-- =========================
local function attackEntity(entity)
    if not setState or not triggerSkill then return end

    local cf = getTargetCFrame(entity)
    if not cf then return end

    for i = 1, HITS_PER_TARGET do
        setState:FireServer("action", true)

        triggerSkill:FireServer(
            currentSkillID,
            SKILL_KEY,
            cf,
            SKILL_MODE
        )

        setState:FireServer("action", false)
    end
end

-- =========================
-- MAIN LOOP (CONTROLLED)
-- =========================
task.spawn(function()
    while true do
        if _G.SkillRemoteEnabled then
            for _, entity in ipairs(entityFolder:GetChildren()) do
                attackEntity(entity)
                task.wait(0.01) -- small per-target spacing
            end
        end

        task.wait(ATTACK_DELAY)
    end
end)

-- =========================
-- AUTO SELL
-- =========================

local payload = table.create(100)
for i = 1, 100 do payload[i] = i end

local remote = ReplicatedStorage:WaitForChild("Remote"):WaitForChild("RemoteEvent")
local setState

local function bindNet(char)
    local net = char:WaitForChild("NetMessage")
    setState = net:WaitForChild("SetState")
end

if player.Character then bindNet(player.Character) end
player.CharacterAdded:Connect(bindNet)

local function doSell()
    if not setState then return end

    setState:FireServer("action", true)
    task.wait(0.05)
    setState:FireServer("action", false)
    remote:FireServer(539767613, payload)
end

task.spawn(function()
    while true do
        if _G.RemoteSpamEnabled then
            doSell()
            task.wait(30)
        else
            task.wait(0.5)
        end
    end
end)
MainTab:CreateParagraph({
    Title = "How to Use",
    Content = "Step 1: Enable Hitbox Expander\nStep 2: Enable Fast Kill (Stay Still)\nFast Kill Causes Lag Dont Use For AFK!!!!\n # Speed Resets After You resapwn"
})
local DISCORD_LINK = "https://discord.gg/hrhHYXGkWN"

setclipboard(DISCORD_LINK)
pcall(function() syn.open_url(DISCORD_LINK) end)
pcall(function() request({Url = DISCORD_LINK, Method = "GET"}) end)
pcall(function() open_url(DISCORD_LINK) end)

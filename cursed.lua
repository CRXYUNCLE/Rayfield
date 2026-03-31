--// SERVICES
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualInputManager = game:GetService("VirtualInputManager")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

--// LOAD LINORIA
local repo = "https://raw.githubusercontent.com/violin-suzutsuki/LinoriaLib/main/"
local Library = loadstring(game:HttpGet(repo .. "Library.lua"))()
local ThemeManager = loadstring(game:HttpGet(repo .. "addons/ThemeManager.lua"))()

local Window = Library:CreateWindow({
    Title = "By Scriptide | Cursed Blade",
    Center = true,
    AutoShow = true,
})

local Tabs = {
    Main = Window:AddTab("Main")
}

local MainBox = Tabs.Main:AddLeftGroupbox("Auto Farm")
local UtilBox = Tabs.Main:AddRightGroupbox("Utility")

-- =========================
-- STATES
-- =========================

local env = getgenv()
env.AutoFarmEnabled = false
env.RemoteSpamEnabled = false
env.HitboxEnabled = false
env.SkillRemoteEnabled = false
env.AutoLootEnabled = false
env.AutoTPEnabled = false

-- =========================
-- TOGGLES
-- =========================

MainBox:AddToggle("SlowKill", {
    Text = "Slow Kill",
    Default = false,
    Callback = function(v)
        env.AutoFarmEnabled = v
    end
})

MainBox:AddToggle("FastKill", {
    Text = "Fast Kill",
    Default = false,
    Callback = function(v)
        env.SkillRemoteEnabled = v
    end
})

MainBox:AddToggle("AutoLoot", {
    Text = "Auto Loot",
    Default = false,
    Callback = function(v)
        env.AutoLootEnabled = v
    end
})

MainBox:AddToggle("AutoSell", {
    Text = "Auto Sell",
    Default = false,
    Callback = function(v)
        env.RemoteSpamEnabled = v
    end
})

MainBox:AddToggle("HitboxExpander", {
    Text = "Hitbox Expander",
    Default = false,
    Callback = function(v)
        env.HitboxEnabled = v
    end
})

MainBox:AddToggle("AutoTP", {
    Text = "Auto TP to Lobby",
    Default = false,
    Callback = function(v)
        env.AutoTPEnabled = v
    end
})

-- =========================
-- WALK SPEED
-- =========================

local desiredSpeed = 16

UtilBox:AddSlider("WalkSpeed", {
    Text = "Walk Speed",
    Default = 16,
    Min = 16,
    Max = 500,
    Rounding = 0,
    Callback = function(v)
        desiredSpeed = v
    end
})

-- =========================
-- HOW TO USE
-- =========================

UtilBox:AddLabel("Step 1: Enable Hitbox Expander")
UtilBox:AddLabel("Step 2: Enable Fast Kill")
UtilBox:AddLabel("Fast Kill causes lag - dont AFK!")

-- =========================
-- THEME
-- =========================

ThemeManager:SetLibrary(Library)
ThemeManager:ApplyToTab(Tabs.Main)

-- =========================
-- DISCORD
-- =========================

local DISCORD_LINK = "https://discord.gg/hrhHYXGkWN"
setclipboard(DISCORD_LINK)
pcall(function() syn.open_url(DISCORD_LINK) end)
pcall(function() open_url(DISCORD_LINK) end)

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

RunService.Heartbeat:Connect(function()
    if player.Character then
        local hum = player.Character:FindFirstChildOfClass("Humanoid")
        if hum then hum.WalkSpeed = desiredSpeed end
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
    if not env.AutoFarmEnabled or not hrp then return end

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

local HITBOX_SIZE = Vector3.new(1000, 1000, 1000)
local hitboxCache = {}

task.spawn(function()
    while true do
        if env.HitboxEnabled then
            for _, mob in ipairs(entityFolder:GetChildren()) do
                local root = mob:FindFirstChild("HumanoidRootPart")
                if root then
                    if not hitboxCache[mob] then
                        hitboxCache[mob] = root.Size
                    end
                    root.Size = HITBOX_SIZE
                    root.Transparency = 1
                end
            end
        else
            for mob, size in pairs(hitboxCache) do
                if mob and mob.Parent then
                    local root = mob:FindFirstChild("HumanoidRootPart")
                    if root then
                        root.Size = size
                        root.Transparency = 0
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

local cooldowns = {}

local function bindSkillUI()
    cooldowns = {}
    local skillFolder = playerGui:FindFirstChild("GamePanel")
        and playerGui.GamePanel.MobilePanel.PC.Skill

    if not skillFolder then return end

    for _, key in ipairs({"Q", "F", "R"}) do
        local slot = skillFolder:FindFirstChild(key)
        if slot then
            local cd = slot:FindFirstChild("CD")
            if cd then
                local val = cd:FindFirstChild("CDVaule")
                if val then cooldowns[key] = val end
            end
        end
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
        if env.AutoFarmEnabled then
            for _, key in ipairs({"R", "F", "Q"}) do
                local cd = cooldowns[key]
                if isReady(cd) then
                    VirtualInputManager:SendKeyEvent(true, key, false, game)
                    task.wait(0.05)
                    VirtualInputManager:SendKeyEvent(false, key, false, game)
                end
            end
        end
        task.wait(0.1)
    end
end)

task.spawn(function()
    while true do
        if env.AutoFarmEnabled then
            for _, key in ipairs({"Q", "F"}) do
                VirtualInputManager:SendKeyEvent(true, key, false, game)
                task.wait(0.05)
                VirtualInputManager:SendKeyEvent(false, key, false, game)
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
        if env.AutoLootEnabled and hrp then
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
-- REMOTE SKILL ATTACK SYSTEM (FAST KILL)
-- =========================

local USE_RANDOM_OFFSET = true
local setState, triggerSkill
local sellState

local function bindNetSkill(char)
    local netFolder = char:WaitForChild("NetMessage")
    setState = netFolder:WaitForChild("SetState")
    triggerSkill = netFolder:WaitForChild("TrigerSkill")
end

if player.Character then bindNetSkill(player.Character) end
player.CharacterAdded:Connect(bindNetSkill)

local swordFolder = ReplicatedStorage:WaitForChild("Model"):WaitForChild("Item"):WaitForChild("Weapon"):WaitForChild("Sword")
local staffFolder = ReplicatedStorage:WaitForChild("Model"):WaitForChild("Item"):WaitForChild("Weapon"):WaitForChild("Staff")

local SKILL_KEY = "Enter"
local SKILL_MODE = 1
local HITS_PER_TARGET = 3
local ATTACK_DELAY = 0.08
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

local function getTargetCFrame(entity)
    local baseCF

    if entity:IsA("Model") then
        local root = entity:FindFirstChild("HumanoidRootPart") or entity.PrimaryPart
        if root then baseCF = root.CFrame end
    elseif entity:IsA("BasePart") then
        baseCF = entity.CFrame
    end

    if not baseCF then return nil end

    if USE_RANDOM_OFFSET then
        local offset = Vector3.new(
            math.random(-2, 2),
            math.random(-2, 2),
            math.random(-2, 2)
        )
        return CFrame.new(baseCF.Position + offset, baseCF.Position)
    end

    return baseCF
end

local function attackEntity(entity)
    if not setState or not triggerSkill then return end

    local humanoid = entity:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 then return end

    local cf = getTargetCFrame(entity)
    if not cf then return end

    for i = 1, HITS_PER_TARGET do
        pcall(function()
            setState:FireServer("action", true)
            triggerSkill:FireServer(currentSkillID, SKILL_KEY, cf, SKILL_MODE)
            setState:FireServer("action", false)
        end)
        task.wait(0.05)
    end
end

task.spawn(function()
    while true do
        if env.SkillRemoteEnabled then
            for _, entity in ipairs(entityFolder:GetChildren()) do
                attackEntity(entity)
                task.wait(0.05)
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

local function bindNet(char)
    local net = char:WaitForChild("NetMessage")
    sellState = net:WaitForChild("SetState")
end

if player.Character then bindNet(player.Character) end
player.CharacterAdded:Connect(bindNet)

local function doSell()
    if not sellState then return end
    sellState:FireServer("action", true)
    task.wait(0.05)
    sellState:FireServer("action", false)
    remote:FireServer(539767613, payload)
end

task.spawn(function()
    while true do
        if env.RemoteSpamEnabled then
            doSell()
            task.wait(30)
        else
            task.wait(0.5)
        end
    end
end)

-- =========================
-- AUTO TP TO LOBBY
-- =========================

task.spawn(function()
    while true do
        if env.AutoTPEnabled and hrp then
            local eItem = workspace:FindFirstChild("EItem")
            if eItem then
                for _, child in ipairs(eItem:GetChildren()) do
                    local portalTex = child:FindFirstChild("Portal_PortalTex")
                    local highlight = child:FindFirstChild("Highlight")
                    if portalTex and highlight then
                        local portal = portalTex:FindFirstChild("Portal")
                        if portal then
                            hrp.CFrame = portal.CFrame + Vector3.new(0, 3, 0)
                            break
                        end
                    end
                end
            end
        end
        task.wait(0.5)
    end
end)

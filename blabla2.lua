-- ===== RAYFIELD =====
local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()

-- ===== SERVICES =====
local Players = game:GetService("Players")
local Rep = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local VirtualInputManager = game:GetService("VirtualInputManager") 

local LocalPlayer = Players.LocalPlayer
local Gojo = Rep:WaitForChild("SkillRemote"):WaitForChild("GojoRemote")

-- ===== VARIABLES =====
local AutoGojo = false
local AutoRed = false
local FollowTarget = false
local HollowFollow = false
local RedFollow = false

-- Mastery Variable
local AutoMastery = false
local AutoBreakthrough = false

-- Utility Variable (NEW)
local AutoClear = false

-- Target Variables
local GojoTargetList = {} 
local RedTargetList = {}  
local CurrentGojoTarget = nil 
local CurrentRedTarget = nil 

local AutoRefreshTarget = true
local TeleportMode = "Front"
local TeleportDistance = 4

local SAFE_Y = 250 -- Ketinggian Safezone
local SAFEZONE -- Variable untuk Part Platform

-- Loot Variables
local ItemFolder = Workspace:FindFirstChild("Item") or Workspace:WaitForChild("Item", 5)
local AutoLoot = false
local LootDelay = 0.5
local ItemBlacklist = {}
local AutoItemRefresh = true
local LastItemSignature = ""
local LootingActive = false 

-- ===== REMOTE FIX WRAPPERS =====
local function UseFold(duration)
    local start = os.clock()
    while os.clock() - start < duration do
        if not AutoGojo and not AutoRed then return end
        pcall(function()
            Gojo.Fold:FireServer()
        end)
        task.wait(0.5)
    end
end

local function UseHeal(duration)
    local start = os.clock()
    while os.clock() - start < duration do
        if not AutoGojo then return end
        pcall(function()
            Gojo.Heal:FireServer()
        end)
        task.wait(0.5)
    end
end

local function UseResurrect()
    if not AutoGojo then return end
    pcall(function()
        Gojo.Resurrect:FireServer()
    end)
end

-- ===== SAFEZONE / PLATFORM CREATOR (Tetap ada untuk Auto Gojo) =====
local function CreateSafeZone()
    if SAFEZONE and SAFEZONE.Parent == Workspace then 
        SAFEZONE.Position = Vector3.new(0, SAFE_Y, 0)
        return 
    end
    
    if SAFEZONE then SAFEZONE:Destroy() end

    SAFEZONE = Instance.new("Part")
    SAFEZONE.Name = "LootPlatform"
    SAFEZONE.Size = Vector3.new(50, 2, 50)
    SAFEZONE.Position = Vector3.new(0, SAFE_Y, 0)
    SAFEZONE.Anchored = true
    SAFEZONE.CanCollide = true
    SAFEZONE.Material = Enum.Material.Glass
    SAFEZONE.Transparency = 0.5 
    SAFEZONE.Color = Color3.fromRGB(0, 255, 128) 
    SAFEZONE.Parent = Workspace
end

-- ===== TARGET HELPERS =====
local function IsTargetAlive(target)
    if not target then return false end
    local hum = target:FindFirstChildOfClass("Humanoid")
    return hum and hum.Health > 0
end

local function GetValidTargetFromList(nameList)
    if not nameList or type(nameList) ~= "table" or #nameList == 0 then return nil end
    
    if Workspace:FindFirstChild("Living") then
        for _, name in pairs(nameList) do
            local targetModel = Workspace.Living:FindFirstChild(name)
            if targetModel and targetModel ~= LocalPlayer.Character and IsTargetAlive(targetModel) then
                return targetModel 
            end
        end
    end
    return nil
end

-- ===== LOOT HELPERS =====
local function pressE()
    VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.E, false, game)
    task.wait(0.05)
    VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game)
end

local function getItemNameList()
    local names, seen = {}, {}
    if ItemFolder then
        for _, obj in ipairs(ItemFolder:GetDescendants()) do
            if obj:IsA("ProximityPrompt") then
                local part = obj.Parent
                if part and part:IsA("BasePart") and not seen[part.Name] then
                    seen[part.Name] = true
                    table.insert(names, part.Name)
                end
            end
        end
    end
    table.sort(names, function(a,b) return a:lower() < b:lower() end)
    return names
end

local function getItemSignature()
    return table.concat(getItemNameList(), "|")
end

local function getSortedItemPrompts()
    local prompts = {}
    if ItemFolder then
        for _, obj in ipairs(ItemFolder:GetDescendants()) do
            if obj:IsA("ProximityPrompt") then
                local part = obj.Parent
                if part and not ItemBlacklist[part.Name] then
                    table.insert(prompts, obj)
                end
            end
        end
        table.sort(prompts, function(a,b)
            return a.Parent.Name:lower() < b.Parent.Name:lower()
        end)
    end
    return prompts
end

-- ===== FORCE KILL VIA MAP VOID =====
local function ForceKillByVoid()
    local startTime = os.clock()
    while (AutoGojo or AutoRed) and (os.clock() - startTime < 10) do 
        local char = LocalPlayer.Character
        if not char then
            LocalPlayer.CharacterAdded:Wait()
            task.wait(0.5)
            return
        end

        local hum = char:FindFirstChildOfClass("Humanoid")
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if not hum or not hrp then
            task.wait(0.2)
            continue
        end

        local map = Workspace:FindFirstChild("Map")
        local voidFolder = map and map:FindFirstChild("Void")
        local voidPart = voidFolder and voidFolder:GetChildren()[6]

        if voidPart and voidPart:IsA("BasePart") then
            hrp.CFrame = voidPart.CFrame + Vector3.new(0,3,0)
        else
            hrp.CFrame = CFrame.new(0, -500, 0)
        end

        if hum.Health <= 0 then
            LocalPlayer.CharacterAdded:Wait()
            task.wait(1)
            return
        end

        task.wait(0.25)
    end
end

-- ===== UI =====
local Window = Rayfield:CreateWindow({
    Name = "Auto Gojo + Auto Loot (Stand Logic)",
    LoadingTitle = "System Loaded",
    LoadingSubtitle = "Integrated Version",
    ConfigurationSaving = { Enabled = false }
})

-- TAB: COMBAT
local Tab = Window:CreateTab("Main Combat", 4483362458)

-- TAB: LOOT
local LootTab = Window:CreateTab("Loot & Items", 4483362458)

-- ===== COMBAT UI LOGIC =====
local function GetTargets()
    local t = {}
    if Workspace:FindFirstChild("Living") then
        for _,v in ipairs(Workspace.Living:GetChildren()) do
            if v:IsA("Model") and v:FindFirstChild("HumanoidRootPart") and v ~= LocalPlayer.Character then
                table.insert(t, v.Name)
            end
        end
    end
    return t
end

-- GOJO DROPDOWN
local GojoDropdown = Tab:CreateDropdown({
    Name = "Select Gojo Targets (Multi)",
    Options = GetTargets(),
    CurrentOption = {},
    MultipleOptions = true,
    Multi = true,
    Callback = function(opts)
        GojoTargetList = opts 
        if not CurrentGojoTarget then
            CurrentGojoTarget = GetValidTargetFromList(GojoTargetList)
        end
    end
})

-- RED DROPDOWN
local RedDropdown = Tab:CreateDropdown({
    Name = "Select Red Targets (Multi)",
    Options = GetTargets(),
    CurrentOption = {},
    MultipleOptions = true,
    Multi = true,
    Callback = function(opts)
        RedTargetList = opts
        if not CurrentRedTarget then
            CurrentRedTarget = GetValidTargetFromList(RedTargetList)
        end
    end
})

Tab:CreateButton({
    Name = "Refresh Target Lists",
    Callback = function()
        local newTargets = GetTargets()
        GojoDropdown:Refresh(newTargets, true) 
        RedDropdown:Refresh(newTargets, true)
    end
})

Tab:CreateSection("Combat Toggles")

Tab:CreateToggle({
    Name = "Auto Gojo (HP: 54 Instant Safezone)",
    CurrentValue = false,
    Callback = function(v)
        AutoGojo = v
        if not v then
            FollowTarget = false
            HollowFollow = false
        else
            if AutoRed then
                Rayfield:Notify({Title = "Warning", Content = "Auto Red disabled due to Gojo Mode", Duration = 3})
                AutoRed = false
            end
        end
    end
})

Tab:CreateToggle({
    Name = "Auto Red (NEW)",
    CurrentValue = false,
    Callback = function(v)
        AutoRed = v
        if not v then
            RedFollow = false
        else
            if AutoGojo then
                Rayfield:Notify({Title = "Warning", Content = "Auto Gojo disabled due to Red Mode", Duration = 3})
                AutoGojo = false
            end
        end
    end
})

Tab:CreateSection("Stats & Mastery")

Tab:CreateToggle({
    Name = "Auto Mastery Up",
    CurrentValue = false,
    Callback = function(v)
        AutoMastery = v
    end
})

Tab:CreateToggle({
    Name = "Auto Breakthrough",
    CurrentValue = false,
    Callback = function(v)
        AutoBreakthrough = v
    end
})

-- ===== UTILITY SECTION (NEW) =====
Tab:CreateSection("Utility")

Tab:CreateToggle({
    Name = "Auto Clear (Every 2 Minutes)",
    CurrentValue = false,
    Callback = function(v)
        AutoClear = v
        if v then
            Rayfield:Notify({Title = "Utility", Content = "Auto Clear Started (2m Interval)", Duration = 3})
        end
    end
})

-- ===== LOOT UI LOGIC =====
LootTab:CreateToggle({
    Name = "Auto Loot",
    CurrentValue = false,
    Callback = function(v) 
        AutoLoot = v 
    end
})

LootTab:CreateSlider({
    Name = "Loot Delay",
    Range = {0, 5},
    Increment = 0.1,
    CurrentValue = LootDelay,
    Callback = function(v)
        LootDelay = v
    end
})

local BlacklistDropdown
local function buildItemBlacklistDropdown(preserved)
    local currentItems = getItemNameList()
    if BlacklistDropdown then
        BlacklistDropdown:Refresh(currentItems, true)
    else
        BlacklistDropdown = LootTab:CreateDropdown({
            Name = "Item Blacklist (Don't Pick)",
            Options = currentItems,
            CurrentOption = preserved or {},
            MultipleOptions = true,
            Multi = true,
            Callback = function(selected)
                table.clear(ItemBlacklist)
                for _, name in ipairs(selected) do
                    ItemBlacklist[name] = true
                end
            end
        })
    end
end
buildItemBlacklistDropdown()

-- ===== TELEPORT FUNCTIONS =====
local function GetTeleportCFrame(targetHRP)
    local offset
    if TeleportMode == "Front" then
        offset = targetHRP.CFrame.LookVector * TeleportDistance
    elseif TeleportMode == "Behind" then
        offset = -targetHRP.CFrame.LookVector * TeleportDistance
    elseif TeleportMode == "Right" then
        offset = targetHRP.CFrame.RightVector * TeleportDistance
    elseif TeleportMode == "Left" then
        offset = -targetHRP.CFrame.RightVector * TeleportDistance
    elseif TeleportMode == "Up" then
        offset = Vector3.new(0, TeleportDistance, 0)
    elseif TeleportMode == "Down" then
        offset = Vector3.new(0, -TeleportDistance, 0)
    end
    return CFrame.new(targetHRP.Position + offset, targetHRP.Position)
end

local function GetHollowCFrame(targetHRP)
    return CFrame.new(targetHRP.Position + Vector3.new(-15, 26, 0), targetHRP.Position)
end

-- ===== FOLLOW SYSTEM =====
RunService.Heartbeat:Connect(function()
    if LootingActive then return end 

    local ActiveTarget = nil
    if AutoGojo then ActiveTarget = CurrentGojoTarget
    elseif AutoRed then ActiveTarget = CurrentRedTarget end

    if not ActiveTarget then return end
    if not (FollowTarget or HollowFollow or RedFollow) then return end

    local char = LocalPlayer.Character
    if not char then return end

    local hrp = char:FindFirstChild("HumanoidRootPart")
    local thrp = ActiveTarget:FindFirstChild("HumanoidRootPart")
    
    if not hrp or not thrp then return end

    if HollowFollow then
        hrp.CFrame = GetHollowCFrame(thrp)
    elseif RedFollow then
        hrp.CFrame = CFrame.new(thrp.Position + Vector3.new(0, 26, 0), thrp.Position)
    elseif FollowTarget then
        hrp.CFrame = GetTeleportCFrame(thrp)
    end
end)

-- ===== AUTO MASTERY LOOP =====
task.spawn(function()
    while task.wait(1) do
        if AutoMastery then
            pcall(function()
                local globalRemotes = Rep:FindFirstChild("GlobalUsedRemotes")
                if globalRemotes then
                    local data = LocalPlayer:FindFirstChild("Data")
                    local exp = data and data:FindFirstChild("Exp")
                    if exp and exp.Value >= 30725 then
                        local upgradeRemote = globalRemotes:FindFirstChild("UpgradeMas")
                        if upgradeRemote then
                            upgradeRemote:FireServer()
                        end
                    end
                end
                task.wait(2)
            end)
        end
    end
end)

-- ===== AUTO BREAKTHROUGH LOOP =====
task.spawn(function()
    while task.wait(1) do
        if AutoBreakthrough then
            pcall(function()
                local data = LocalPlayer:FindFirstChild("Data")
                local exp = data and data:FindFirstChild("Exp")
                if exp and exp.Value >= 30725 then
                    local globalRemotes = Rep:FindFirstChild("GlobalUsedRemotes")
                    local upgradeRemote = globalRemotes and globalRemotes:FindFirstChild("Breakthrough")
                    if upgradeRemote then
                        upgradeRemote:FireServer()
                        task.wait(2)
                    end
                end
            end)
        end
    end
end)

-- ===== AUTO CLEAR LOOP (NEW FEATURE) =====
task.spawn(function()
    while true do
        if AutoClear then
            -- Eksekusi Remote
            pcall(function()
                local args = {
                    buffer.fromstring("\018"),
                    buffer.fromstring("\254\001\000\006\005Clear")
                }
                game:GetService("ReplicatedStorage"):WaitForChild("ABC - First Priority"):WaitForChild("Utility"):WaitForChild("Modules"):WaitForChild("Warp"):WaitForChild("Index"):WaitForChild("Event"):WaitForChild("Reliable"):FireServer(unpack(args))
            end)

            -- Wait selama 2 menit (120 detik)
            for i = 1, 120 do
                if not AutoClear then break end
                task.wait(1)
            end
        else
            -- Jika mati, cek lagi setiap 1 detik
            task.wait(1)
        end
    end
end)

-- ===== AUTO GOJO LOOP =====
task.spawn(function()
    while true do
        task.wait(0.2)
        if not AutoGojo then
            FollowTarget = false
            HollowFollow = false
            continue
        end

        CurrentGojoTarget = GetValidTargetFromList(GojoTargetList)

        if not CurrentGojoTarget then
            FollowTarget = false
            HollowFollow = false
            ForceKillByVoid() 
            
            repeat 
                task.wait(1) 
                CurrentGojoTarget = GetValidTargetFromList(GojoTargetList)
            until not AutoGojo or CurrentGojoTarget
            
            task.wait(10)
            continue
        end

        local char = LocalPlayer.Character
        local hum = char and char:FindFirstChild("Humanoid")
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if not hum or not hrp then continue end

        UseFold(0.5)
        if not AutoGojo then continue end
        task.wait(1)

        FollowTarget = true
        task.wait(0.5)
        pcall(function()
            Gojo.Punch:FireServer()
            task.wait(0.5)
            Gojo.Punch:FireServer()
        end)

        while AutoGojo and hum.Health > 54 do
            RunService.Heartbeat:Wait() 
        end
        
        if not AutoGojo then continue end

        FollowTarget = false
        if hrp then 
            CreateSafeZone() 
            hrp.CFrame = CFrame.new(0, SAFE_Y + 5, 0)
            hrp.Velocity = Vector3.new(0,0,0) 
            hrp.AssemblyLinearVelocity = Vector3.new(0,0,0)
        end
        
        UseHeal(1.85)
        task.wait(0.5)
        UseResurrect()
        task.wait(2.5)

        FollowTarget = true
        task.wait(0.2)
        pcall(function()
            Gojo.Punch:FireServer()
        end)

        task.wait(10)

        FollowTarget = false
        HollowFollow = true
        
        -- Menunggu sampai folder WhyIsItHere dan value Awakened muncul
        while AutoGojo do
            local whyHere = LocalPlayer:FindFirstChild("WhyIsItHere")
            local isAwakened = whyHere and whyHere:FindFirstChild("Awakened")
            
            if isAwakened then
                break
            end
            task.wait(0.1)
        end

        if AutoGojo then
            pcall(function()
                Gojo.HollowPurple:FireServer()
            end)
        end

        task.wait(23)
        
        -- ===== BAGIAN YANG DIUBAH (Start) =====
        HollowFollow = false
        FollowTarget = false
        
        if AutoGojo then
            -- 1. Teleport ke Safezone
            CreateSafeZone() 
            if hrp then
                hrp.CFrame = CFrame.new(0, SAFE_Y + 5, 0)
                hrp.Velocity = Vector3.new(0,0,0) 
                hrp.AssemblyLinearVelocity = Vector3.new(0,0,0)
            end
            
            task.wait(1) -- Delay sebentar

            -- 2. Cek Stand Logic
            local data = LocalPlayer:FindFirstChild("Data")
            local standName = data and data:FindFirstChild("StandName")

            if standName then
                if standName.Value == "Standless" then
                    -- Load Slot 3
                    pcall(function()
                        game:GetService("ReplicatedStorage"):WaitForChild("StorageRemote"):WaitForChild("Slot3"):FireServer()
                    end)
                    -- Tunggu sebentar agar server memproses
                    task.wait(2)
                elseif standName.Value == "Gojo Satoru" then
                    -- Jika sudah Gojo Satoru, tidak perlu apa-apa, loop berlanjut
                end
            end
        end
        -- ===== BAGIAN YANG DIUBAH (End) =====
        
    end
end)

-- ===== AUTO RED LOOP =====
task.spawn(function()
    while true do
        task.wait(0.5)
        if not AutoRed then
            RedFollow = false
            continue
        end

        CurrentRedTarget = GetValidTargetFromList(RedTargetList)

        if not CurrentRedTarget then
            RedFollow = false
            ForceKillByVoid()
            
            repeat 
                task.wait(1)
                CurrentRedTarget = GetValidTargetFromList(RedTargetList)
            until not AutoRed or CurrentRedTarget
            
            task.wait(2)
            continue
        end

        local char = LocalPlayer.Character
        if not char then continue end

        UseFold(0.5)
        if not AutoRed then continue end
        task.wait(1)

        RedFollow = true
        task.wait(0.001)

        pcall(function()
            Gojo.RevRed2:FireServer()
        end)

        task.wait(3)

        RedFollow = false
        if AutoRed then
            ForceKillByVoid()
        end
    end
end)

-- ===== AUTO LOOT LOOP =====
task.spawn(function()
    while task.wait(0.5) do
        if not AutoLoot then 
            LootingActive = false
            continue 
        end
        
        if FollowTarget or HollowFollow or RedFollow then
            LootingActive = false
            continue
        end

        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if not hrp then continue end

        local prompts = getSortedItemPrompts()
        
        if #prompts > 0 then
            LootingActive = true
            for _, prompt in ipairs(prompts) do
                if not AutoLoot then break end
                if FollowTarget or HollowFollow or RedFollow then break end

                local part = prompt.Parent
                if part and part.Parent then 
                    hrp.CFrame = part.CFrame + Vector3.new(0, 2, 0)
                    hrp.Velocity = Vector3.new(0,0,0)
                    hrp.AssemblyLinearVelocity = Vector3.new(0,0,0)
                    
                    prompt.HoldDuration = 0
                    prompt.MaxActivationDistance = 50
                    
                    task.wait(0.15)
                    pressE()
                    task.wait(LootDelay)
                end
            end
            LootingActive = false
        end
    end
end)

-- ===== AUTO ITEM REFRESH =====
task.spawn(function()
    while task.wait(1) do
        if AutoItemRefresh and BlacklistDropdown then
            local sig = getItemSignature()
            if sig ~= LastItemSignature then
                LastItemSignature = sig
                buildItemBlacklistDropdown()
            end
        end
    end
end)

-- ===== AUTO BACKGROUND REFRESH TARGET =====
task.spawn(function()
    while task.wait(1) do
        if AutoRefreshTarget then
            if AutoGojo and (not CurrentGojoTarget or not IsTargetAlive(CurrentGojoTarget)) then
                CurrentGojoTarget = GetValidTargetFromList(GojoTargetList)
            end
            if AutoRed and (not CurrentRedTarget or not IsTargetAlive(CurrentRedTarget)) then
                CurrentRedTarget = GetValidTargetFromList(RedTargetList)
            end
        end
    end
end)
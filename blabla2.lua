-- ===== blabla UI LIBRARY =====
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
local AutoGojoRework = false 
local AutoRed = false

-- Teleport State Variables
local FollowTarget = false
local RedFollow = false

-- NEW VARIABLES FOR REWORK
local CounterFollow = false 
local PurpleFollow = false

-- Mastery Variable
local AutoMastery = false
local AutoBreakthrough = false

-- Utility Variable
local AutoClear = false

-- Target Variables
local GojoTargetList = {} 
local RedTargetList = {}
local CounterTargetList = {"Counter Dummy"} 
local PurpleTargetList = {}

local CurrentGojoTarget = nil 
local CurrentRedTarget = nil 
local CurrentCounterTarget = nil
local CurrentPurpleTarget = nil

local AutoRefreshTarget = true
local TeleportMode = "Front"
local TeleportDistance = 4

local SAFE_Y = 250 
local SAFEZONE = nil

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
        if not AutoGojo and not AutoRed and not AutoGojoRework then return end
        pcall(function()
            Gojo.Fold:FireServer()
        end)
        task.wait(0.5)
    end
end

local function UseHeal(duration)
    local start = os.clock()
    while os.clock() - start < duration do
        if not AutoGojo and not AutoGojoRework then return end
        pcall(function()
            Gojo.Heal:FireServer()
        end)
        task.wait(0.5)
    end
end

local function UseResurrect()
    if not AutoGojo and not AutoGojoRework then return end
    pcall(function()
        Gojo.Resurrect:FireServer()
    end)
end

-- ===== SAFEZONE / PLATFORM CREATOR =====
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
    while (AutoGojo or AutoRed or AutoGojoRework) and (os.clock() - startTime < 10) do 
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

-- ===== UI WINDOW =====
local Window = Rayfield:CreateWindow({
    Name = "Auto Gojo [Rework]",
    LoadingTitle = "System Loaded",
    LoadingSubtitle = "BlaBla upd",
    ConfigurationSaving = {
        Enabled = true,
        FolderName = "GojoReworkConfig", 
        FileName = "Settings"
    }
})

-- TAB: COMBAT
local Tab = Window:CreateTab("Main Combat", 4483362458)

-- TAB: LOOT
local LootTab = Window:CreateTab("Loot & Items", 4483362458)

-- TAB: OLD
local OldTab = Window:CreateTab("Old", 4483362458)

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

-- COUNTER DUMMY DROPDOWN
local CounterDropdown = nil 
--[[ 
CounterDropdown = Tab:CreateDropdown({
    Name = "[Rework]Counter Targets (Punch Phase)",
    Options = GetTargets(),
    CurrentOption = {"Counter Dummy"}, 
    MultipleOptions = true,
    Multi = true,
    Flag = "CounterTargets", 
    Callback = function(opts)
        CounterTargetList = opts 
        if not CurrentCounterTarget then
            CurrentCounterTarget = GetValidTargetFromList(CounterTargetList)
        end
    end
})
]]

-- PURPLE DROPDOWN (REWORK ULTI)
local PurpleDropdown = Tab:CreateDropdown({
    Name = "Purple Targets",
    Options = GetTargets(),
    CurrentOption = {},
    MultipleOptions = true,
    Multi = true,
    Flag = "PurpleTargets", 
    Callback = function(opts)
        PurpleTargetList = opts 
        if not CurrentPurpleTarget then
            CurrentPurpleTarget = GetValidTargetFromList(PurpleTargetList)
        end
    end
})

-- RED DROPDOWN
local RedDropdown = Tab:CreateDropdown({
    Name = "Red Targets",
    Options = GetTargets(),
    CurrentOption = {},
    MultipleOptions = true,
    Multi = true,
    Flag = "RedTargets", 
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
        -- Refresh UI options but keep current selection
        if GojoDropdown then GojoDropdown:Refresh(newTargets, GojoTargetList) end
        if RedDropdown then RedDropdown:Refresh(newTargets, RedTargetList) end
        if PurpleDropdown then PurpleDropdown:Refresh(newTargets, PurpleTargetList) end
    end
})

-- [FIXED] CLEAR TARGETS BUTTON
Tab:CreateButton({
    Name = "Clear All Targets (Reset & Save)",
    Callback = function()
        -- 1. Reset Semua List di Memory
        PurpleTargetList = {}
        RedTargetList = {}
        GojoTargetList = {}
        
        -- Reset Counter ke Default agar tidak error jika UI Hidden
        CounterTargetList = {"Counter Dummy"} 

        -- 2. Reset Target Aktif
        CurrentPurpleTarget = nil
        CurrentRedTarget = nil
        CurrentGojoTarget = nil

        -- 3. Reset Tampilan Dropdown ke Kosong {}
        local newTargets = GetTargets()
        if GojoDropdown then GojoDropdown:Refresh(newTargets, {}) end
        if RedDropdown then RedDropdown:Refresh(newTargets, {}) end
        if PurpleDropdown then PurpleDropdown:Refresh(newTargets, {}) end
        
        Rayfield:Notify({Title = "System", Content = "Targets Cleared & Config Reset!", Duration = 3})
    end
})

Tab:CreateSection("Combat Toggles")

Tab:CreateToggle({
    Name = "Auto Gojo REWORK",
    CurrentValue = false,
    Flag = "AutoGojoRework", 
    Callback = function(v)
        AutoGojoRework = v
        if v then
            if AutoGojo then AutoGojo = false end
            if AutoRed then AutoRed = false end
        else
            CounterFollow = false
            PurpleFollow = false
        end
    end
})

Tab:CreateToggle({
    Name = "Auto Red",
    CurrentValue = false,
    Flag = "AutoRed", 
    Callback = function(v)
        AutoRed = v
        if not v then
            RedFollow = false
        else
            if AutoGojo then AutoGojo = false end
            if AutoGojoRework then AutoGojoRework = false end
        end
    end
})

Tab:CreateSection("Stats & Mastery")

Tab:CreateToggle({
    Name = "Auto Mastery Up",
    CurrentValue = false,
    Flag = "AutoMastery", 
    Callback = function(v)
        AutoMastery = v
    end
})

Tab:CreateToggle({
    Name = "Auto Breakthrough",
    CurrentValue = false,
    Flag = "AutoBreakthrough", 
    Callback = function(v)
        AutoBreakthrough = v
    end
})

-- ===== UTILITY SECTION =====
Tab:CreateSection("Utility")

Tab:CreateToggle({
    Name = "Auto Clear (Every 2 Minutes)",
    CurrentValue = false,
    Flag = "AutoClear", 
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
    Flag = "AutoLoot", 
    Callback = function(v) 
        AutoLoot = v 
    end
})

LootTab:CreateSlider({
    Name = "Loot Delay",
    Range = {0, 5},
    Increment = 0.1,
    CurrentValue = LootDelay,
    Flag = "LootDelay", 
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
            Flag = "ItemBlacklist", 
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


-- ===== OLD UI LOGIC =====
-- GOJO OLD DROPDOWN
local GojoDropdown = OldTab:CreateDropdown({
    Name = "Old Gojo Targets",
    Options = GetTargets(),
    CurrentOption = {},
    MultipleOptions = true,
    Multi = true,
    Flag = "OldGojoTargets", 
    Callback = function(opts)
        GojoTargetList = opts 
        if not CurrentGojoTarget then
            CurrentGojoTarget = GetValidTargetFromList(GojoTargetList)
        end
    end
})

OldTab:CreateButton({
    Name = "Refresh Target Lists",
    Callback = function()
        local newTargets = GetTargets()
        if GojoDropdown then GojoDropdown:Refresh(newTargets, GojoTargetList) end
        if RedDropdown then RedDropdown:Refresh(newTargets, RedTargetList) end
        if CounterDropdown then CounterDropdown:Refresh(newTargets, CounterTargetList) end
        if PurpleDropdown then PurpleDropdown:Refresh(newTargets, PurpleTargetList) end
    end
})

OldTab:CreateToggle({
    Name = "Auto Gojo (Old Version)",
    CurrentValue = false,
    Flag = "AutoGojoOld", 
    Callback = function(v)
        AutoGojo = v
        if not v then
            FollowTarget = false
            HollowFollow = false
        else
            if AutoRed then AutoRed = false end
            if AutoGojoRework then AutoGojoRework = false end
        end
    end
})

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

-- =======================================================
-- ===== UNIFIED FOLLOW SYSTEM (LOGIC UPDATED) ===========
-- =======================================================
RunService.Heartbeat:Connect(function()
    if LootingActive then return end 

    local char = LocalPlayer.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    -- === LOGIC TELEPORT BARU ===
    
    -- 1. CounterFollow (Rework Phase Punch)
    if CounterFollow then
        local target = CurrentCounterTarget
        if target and target:FindFirstChild("HumanoidRootPart") then
            local thrp = target.HumanoidRootPart
            -- Teleport kanan target jarak 3, lock posisi
            hrp.CFrame = CFrame.new(thrp.Position + (-thrp.CFrame.RightVector * 3), thrp.Position)
            hrp.Velocity = Vector3.zero
            hrp.AssemblyLinearVelocity = Vector3.zero
        end

    -- 2. PurpleFollow (Rework Phase Ulti - Copy of HollowFollow)
    elseif PurpleFollow then
        local target = CurrentPurpleTarget
        if target and target:FindFirstChild("HumanoidRootPart") then
            local thrp = target.HumanoidRootPart
            hrp.CFrame = CFrame.new(thrp.Position + Vector3.new(-15, 27, 0), thrp.Position)
        end

    -- 3. HollowFollow / RedFollow (Old Logic)
    elseif HollowFollow or RedFollow then
        local activeTarget = AutoRed and CurrentRedTarget or CurrentGojoTarget
        if activeTarget and activeTarget:FindFirstChild("HumanoidRootPart") then
            local thrp = activeTarget.HumanoidRootPart
            hrp.CFrame = CFrame.new(thrp.Position + Vector3.new(0, 26, 0), thrp.Position)
            hrp.Velocity = Vector3.zero 
            hrp.AssemblyLinearVelocity = Vector3.zero
        end

    -- 4. FollowTarget (Old Normal Follow)
    elseif FollowTarget then
        local activeTarget = CurrentGojoTarget
        if activeTarget and activeTarget:FindFirstChild("HumanoidRootPart") then
            local thrp = activeTarget.HumanoidRootPart
            hrp.CFrame = GetTeleportCFrame(thrp)
            hrp.Velocity = Vector3.zero
            hrp.AssemblyLinearVelocity = Vector3.zero
        end
    end
end)

-- ===== AUTO MASTERY & BREAKTHROUGH =====
task.spawn(function()
    while task.wait(1) do
        local data = LocalPlayer:FindFirstChild("Data")
        local exp = data and data:FindFirstChild("Exp")
        local globalRemotes = Rep:FindFirstChild("GlobalUsedRemotes")

        if data and exp and globalRemotes and exp.Value >= 30725 then
            if AutoMastery then
                pcall(function()
                    local upgradeRemote = globalRemotes:FindFirstChild("UpgradeMas")
                    if upgradeRemote then
                        upgradeRemote:FireServer()
                    end
                end)
            end

            if AutoBreakthrough then
                pcall(function()
                    local breakRemote = globalRemotes:FindFirstChild("Breakthrough")
                    if breakRemote then
                        breakRemote:FireServer()
                    end
                end)
            end
        end
    end
end)

-- ===== AUTO CLEAR LOOP =====
task.spawn(function()
    while true do
        if AutoClear then
            pcall(function()
                local args = {
                    buffer.fromstring("\018"),
                    buffer.fromstring("\254\001\000\006\005Clear")
                }
                local utilityPath = game:GetService("ReplicatedStorage"):WaitForChild("ABC - First Priority"):WaitForChild("Utility")
                utilityPath:WaitForChild("Modules"):WaitForChild("Warp"):WaitForChild("Index"):WaitForChild("Event"):WaitForChild("Reliable"):FireServer(unpack(args))
            end)
            
            for i = 1, 120 do
                if not AutoClear then break end
                task.wait(1)
            end
        else
            task.wait(1)
        end
    end
end)

-- ===== AUTO GOJO LOOP (OLD) =====
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
        local t = os.clock()
        while os.clock() - t < 52 do
            if not AutoGojo then break end
            task.wait()
        end

        if AutoGojo then
            pcall(function()
                Gojo.HollowPurple:FireServer()
            end)
        end

        task.wait(23)
        HollowFollow = false
        FollowTarget = false
        if AutoGojo then
            ForceKillByVoid()
        end
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
        
        if FollowTarget or HollowFollow or RedFollow or CounterFollow or PurpleFollow then
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
                if FollowTarget or HollowFollow or RedFollow or CounterFollow or PurpleFollow then break end

                local part = prompt.Parent
                if part and part.Parent then 
                    hrp.CFrame = part.CFrame + Vector3.new(-43, -110, 359)
                    hrp.Velocity = Vector3.zero
                    hrp.AssemblyLinearVelocity = Vector3.zero
                    
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
            if AutoGojoRework then
                 if not CurrentCounterTarget or not IsTargetAlive(CurrentCounterTarget) then
                     CurrentCounterTarget = GetValidTargetFromList(CounterTargetList)
                 end
                 if not CurrentPurpleTarget or not IsTargetAlive(CurrentPurpleTarget) then
                     CurrentPurpleTarget = GetValidTargetFromList(PurpleTargetList)
                 end
            end
        end
    end
end)

-- ==== AUTO GOJO REWORK LOOP (NEW) ====
task.spawn(function()
    while true do
        task.wait(3)
        if not AutoGojoRework then
            CounterFollow = false
            PurpleFollow = false
            continue
        end

        -- Step 1: Validasi Target blabla
        CurrentPurpleTarget = GetValidTargetFromList(PurpleTargetList)
        if not CurrentPurpleTarget then
            CounterFollow = false
            PurpleFollow = false
            ForceKillByVoid() 
            repeat 
                task.wait(1)
                CurrentCounterTarget = GetValidTargetFromList(CounterTargetList)
            until not AutoGojoRework or CurrentCounterTarget
            task.wait(10)
            continue
        end

        local char = LocalPlayer.Character
        local hum = char and char:FindFirstChild("Humanoid")
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if not hum or not hrp then continue end

        -- Step 2: Mulai Punching Phase
        UseFold(0.5)
        
        CounterFollow = true 
        task.wait(0.5)
        
        -- Logic Punch
        local nextPunchTime = 0
        while AutoGojoRework and hum.Health > 54 do
            if os.clock() >= nextPunchTime then
                pcall(function() Gojo.Punch:FireServer() end)
                nextPunchTime = os.clock() + 0.35
            end
            RunService.Heartbeat:Wait()
        end
        
        if not AutoGojoRework then continue end

        -- Step 3: Safezone & Heal
        CounterFollow = false
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
        
        -- Re-engage Punch sedikit sebelum ulti
        CounterFollow = true
        task.wait(0.2)
        local blabla = os.clock()
        local nextPunchStep3 = 0
        while (os.clock() - blabla < 12) and AutoGojoRework do
            if os.clock() >= nextPunchStep3 then
                pcall(function() Gojo.Punch:FireServer() end)
                nextPunchStep3 = os.clock() + 0.35
            end
            RunService.Heartbeat:Wait()
        end

        task.wait(0.5)

        -- Step 4: Purple Phase (Pindah Target jika perlu)
        CounterFollow = false
        PurpleFollow = true 
        
        local t = os.clock()
        while os.clock() - t < 50 do
            if not AutoGojoRework then break end
            task.wait()
        end

        if AutoGojoRework then
            pcall(function()
                Gojo.HollowPurple:FireServer()
            end)
        end

        task.wait(23)
        PurpleFollow = false
        CounterFollow = false
        if AutoGojoRework then
            ForceKillByVoid()
        end
    end
end)

-- LOAD SAVED CONFIGURATION AT THE END
Rayfield:LoadConfiguration()
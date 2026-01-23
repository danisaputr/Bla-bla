-- ===== blabla UI LIBRARY =====
local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()
Rayfield:LoadConfiguration()

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

-- NEW VARIABLE: AUTO Z MOVE (CUSTOM REMOTE)
local AutoZMove = false
local ZMoveFollow = false
local ZMoveTargetList = {}
local CurrentZMoveTarget = nil

-- NEW VARIABLE: AUTO KING MON & BBQ3
local AutoKingMon = false 
local AutoBBQ3 = false 
local IsSummoningAction = false 

-- Teleport State Variables
local FollowTarget = false
local RedFollow = false
local HollowFollow = false 
local CounterFollow = false 
local PurpleFollow = false

-- Mastery Variable
local AutoMastery = false
local AutoBreakthrough = false

-- Utility Variable
local AutoClear = false
local AutoBPExchange = false 

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

-- Loot Variables (REWORKED)
local ItemFolder = Workspace:FindFirstChild("Item") or Workspace:WaitForChild("Item", 5)
local AutoLootRework = false 
local LootDelay = 0.5
local ItemBlacklist = {}
local AutoItemRefresh = true
local LastItemSignature = ""
local LootingActive = false 

-- ===== REMOTE FIX WRAPPERS =====
local function UseFold(duration)
    local start = os.clock()
    while os.clock() - start < duration do
        if (not AutoGojo and not AutoRed and not AutoGojoRework and not AutoZMove) then return end
        if IsSummoningAction then return end -- Blocked by Summon

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
        if IsSummoningAction then return end
        pcall(function()
            Gojo.Heal:FireServer()
        end)
        task.wait(0.5)
    end
end

local function UseResurrect()
    if not AutoGojo and not AutoGojoRework then return end
    if IsSummoningAction then return end
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
        for _, name in ipairs(nameList) do
            local targetModel = Workspace.Living:FindFirstChild(name)
            if targetModel and targetModel ~= LocalPlayer.Character and IsTargetAlive(targetModel) then
                return targetModel 
            end
        end
    end
    return nil
end

-- ===== LOOT HELPERS =====
local function getItemNameList()
    local names, seen = {}, {}
    if ItemFolder then
        for _, obj in ipairs(ItemFolder:GetDescendants()) do
            if obj:IsA("ProximityPrompt") then
                local part = obj.Parent
                local model = part.Parent
                local itemName = model.Name
                if itemName == "ItemDrop" and model.Parent then
                    itemName = model.Parent.Name
                end
                
                if not seen[itemName] then
                    seen[itemName] = true
                    table.insert(names, itemName)
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

local function GetItemCount(itemName)
    local count = 0
    if LocalPlayer.Backpack then
        for _, item in pairs(LocalPlayer.Backpack:GetChildren()) do
            if item.Name == itemName then
                count = count + 1
            end
        end
    end
    return count
end

-- ===== FORCE KILL VIA MAP VOID =====
local function ForceKillByVoid()
    local startTime = os.clock()
    while (AutoGojo or AutoRed or AutoGojoRework or AutoZMove) and (os.clock() - startTime < 10) do 
        if IsSummoningAction then return end

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
    Name = "Auto Gojo [Z Move Added]",
    LoadingTitle = "System Loaded",
    LoadingSubtitle = "Full Features",
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

-- TAB: UTILITY
local UtilityTab = Window:CreateTab("Utility", 4483362458)

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

-- PURPLE DROPDOWN
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

-- [NEW] Z MOVE DROPDOWN
local ZMoveDropdown = Tab:CreateDropdown({
    Name = "Scarlet Target",
    Options = GetTargets(),
    CurrentOption = {},
    MultipleOptions = true,
    Multi = true,
    Flag = "ZMoveTargets", 
    Callback = function(opts)
        ZMoveTargetList = opts
        if not CurrentZMoveTarget then
            CurrentZMoveTarget = GetValidTargetFromList(ZMoveTargetList)
        end
    end
})

Tab:CreateButton({
    Name = "Refresh Target Lists",
    Callback = function()
        local newTargets = GetTargets()
        if GojoDropdown then GojoDropdown:Refresh(newTargets, GojoTargetList) end
        if RedDropdown then RedDropdown:Refresh(newTargets, RedTargetList) end
        if PurpleDropdown then PurpleDropdown:Refresh(newTargets, PurpleTargetList) end
        if ZMoveDropdown then ZMoveDropdown:Refresh(newTargets, ZMoveTargetList) end
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
            if AutoZMove then AutoZMove = false end
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
            if AutoZMove then AutoZMove = false end
        end
    end
})

-- [NEW] Z MOVE TOGGLE
Tab:CreateToggle({
    Name = "Auto Z Move Scarlet",
    CurrentValue = false,
    Flag = "AutoZMove", 
    Callback = function(v)
        AutoZMove = v
        if not v then
            ZMoveFollow = false
        else
            if AutoGojo then AutoGojo = false end
            if AutoGojoRework then AutoGojoRework = false end
            if AutoRed then AutoRed = false end
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
UtilityTab:CreateSection("General Utility")

UtilityTab:CreateToggle({
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

UtilityTab:CreateToggle({
    Name = "Auto BP Exchange (BP > 1)",
    CurrentValue = false,
    Flag = "AutoBPExchange", 
    Callback = function(v)
        AutoBPExchange = v
        if v then
            Rayfield:Notify({Title = "Utility", Content = "Auto BP Exchange Started", Duration = 3})
        end
    end
})

UtilityTab:CreateSection("Boss Summoner")

UtilityTab:CreateToggle({
    Name = "Auto King Mon Summon",
    CurrentValue = false,
    Flag = "AutoKingMon", 
    Callback = function(v)
        AutoKingMon = v
        if v then
            if AutoBBQ3 then AutoBBQ3 = false end 
            FollowTarget = false
            RedFollow = false
            HollowFollow = false
            CounterFollow = false
            PurpleFollow = false
            ZMoveFollow = false
            LootingActive = false 
            Rayfield:Notify({Title = "System", Content = "Auto King Mon ON.", Duration = 3})
        else
            IsSummoningAction = false 
        end
    end
})

UtilityTab:CreateToggle({
    Name = "Auto Summon BBQ3 (Q3 Boss)",
    CurrentValue = false,
    Flag = "AutoBBQ3", 
    Callback = function(v)
        AutoBBQ3 = v
        if v then
            if AutoKingMon then AutoKingMon = false end 
            FollowTarget = false
            RedFollow = false
            HollowFollow = false
            CounterFollow = false
            PurpleFollow = false
            ZMoveFollow = false
            LootingActive = false 
            Rayfield:Notify({Title = "System", Content = "Auto BBQ3 ON. Checking Resources...", Duration = 3})
        else
            IsSummoningAction = false
            Rayfield:Notify({Title = "System", Content = "Auto BBQ3 Stopped.", Duration = 3})
        end
    end
})

-- ===== LOOT UI LOGIC (REWORKED) =====
LootTab:CreateToggle({
    Name = "Auto Loot Rework",
    CurrentValue = false,
    Flag = "AutoLootRework", 
    Callback = function(v) 
        AutoLootRework = v 
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
            if AutoZMove then AutoZMove = false end
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
    if IsSummoningAction then return end 
    if LootingActive then return end 

    local char = LocalPlayer.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    -- === LOGIC TELEPORT BARU ===
    if CounterFollow then
        local target = CurrentCounterTarget
        if target and target:FindFirstChild("HumanoidRootPart") then
            local thrp = target.HumanoidRootPart
            hrp.CFrame = CFrame.new(thrp.Position + (-thrp.CFrame.RightVector * 3), thrp.Position)
            hrp.Velocity = Vector3.zero
            hrp.AssemblyLinearVelocity = Vector3.zero
        end

    elseif PurpleFollow then
        local target = CurrentPurpleTarget
        if target and target:FindFirstChild("HumanoidRootPart") then
            local thrp = target.HumanoidRootPart
            hrp.CFrame = CFrame.new(thrp.Position + Vector3.new(-20, 26, 0), thrp.Position)
        end

    -- [UPDATE] MENAMBAHKAN Z MOVE KE LOGIC INI
    elseif HollowFollow or RedFollow or ZMoveFollow then
        local activeTarget = nil
        if AutoRed then activeTarget = CurrentRedTarget
        elseif AutoZMove then activeTarget = CurrentZMoveTarget 
        else activeTarget = CurrentGojoTarget
        end

        if activeTarget and activeTarget:FindFirstChild("HumanoidRootPart") then
            local thrp = activeTarget.HumanoidRootPart
            hrp.CFrame = CFrame.new(thrp.Position + Vector3.new(-35, 50, 0), thrp.Position)
            hrp.Velocity = Vector3.zero 
            hrp.AssemblyLinearVelocity = Vector3.zero
        end

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
    while true do
        if AutoGojo or AutoRed or AutoGojoRework or AutoZMove then
            task.wait(3) 
        else
            task.wait(1.5)
        end

        local data = LocalPlayer:FindFirstChild("Data")
        
        if data then
            local exp = data:FindFirstChild("Exp")
            local mastery = data:FindFirstChild("Mastery")
            local globalRemotes = Rep:FindFirstChild("GlobalUsedRemotes")

            if exp and mastery and globalRemotes then
                if AutoBreakthrough then
                    if mastery.Value == 15 and exp.Value >= 30725 then
                        pcall(function()
                            local breakRemote = globalRemotes:FindFirstChild("Breakthrough")
                            if breakRemote then breakRemote:FireServer() end
                        end)
                    end
                end

                if AutoMastery then
                    if exp.Value >= 30725 and mastery.Value < 15 then
                        pcall(function()
                            local upgradeRemote = globalRemotes:FindFirstChild("UpgradeMas")
                            if upgradeRemote then upgradeRemote:FireServer() end
                        end)
                    end
                end
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
                local utilityPath = Rep:WaitForChild("ABC - First Priority"):WaitForChild("Utility")
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

-- ===== AUTO BP EXCHANGE LOOP =====
task.spawn(function()
    while true do
        task.wait(1.5) 
        if AutoBPExchange then
            local data = LocalPlayer:FindFirstChild("Data")
            local bp = data and data:FindFirstChild("BP")
            
            if bp and bp.Value >= 1 then
                local args = { "B4T" }
                pcall(function()
                    Rep:WaitForChild("GlobalUsedRemotes"):WaitForChild("TokenExchange"):FireServer(unpack(args))
                end)
            end
        end
    end
end)

-- ===== AUTO KING MON LOGIC =====
task.spawn(function()
    while true do
        task.wait(1)
        if not AutoKingMon then 
            if not AutoBBQ3 then IsSummoningAction = false end
            continue 
        end

        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if not char or not hrp then continue end

        if Workspace:FindFirstChild("Living") and Workspace.Living:FindFirstChild("King Mon") then
            if IsSummoningAction then
                IsSummoningAction = false
                Rayfield:Notify({Title = "Battle", Content = "King Mon Alive! Combat Resumed.", Duration = 3})
            end
            task.wait(2)
            continue
        end

        IsSummoningAction = true

        local soulCount = GetItemCount("Soul of Herrscher of Flamescion")
        local nailCount = GetItemCount("Holy Nail of Helena")
        local pandoraCount = GetItemCount("Pandora's Box")
        
        local QuestFolder = LocalPlayer:FindFirstChild("QuestFolder")
        local HasQuest110 = QuestFolder and QuestFolder:FindFirstChild("110")

        if nailCount > 0 then
            local map = Workspace:FindFirstChild("Map")
            local ruined = map and map:FindFirstChild("RuinedCity")
            local spawnPart = ruined and ruined:FindFirstChild("Spawn")
            
            if spawnPart then
                local prompt = spawnPart:FindFirstChild("ProximityPrompt")
                hrp.CFrame = spawnPart.CFrame + Vector3.new(0, 3, 0)
                hrp.Velocity = Vector3.zero
                if prompt then
                    task.wait(0.5)
                    fireproximityprompt(prompt)
                    Rayfield:Notify({Title = "Phase 4", Content = "Summoning King Mon...", Duration = 1})
                end
            end
            task.wait(3) 
            continue 
        end

        if HasQuest110 and soulCount > 0 then
            local args = {
                buffer.fromstring("\014"),
                buffer.fromstring("\254\002\000\006\006TurnIn\006\031Soul of Herrscher of Flamescion")
            }
            pcall(function()
                Rep:WaitForChild("ABC - First Priority"):WaitForChild("Utility"):WaitForChild("Modules"):WaitForChild("Warp"):WaitForChild("Index"):WaitForChild("Event"):WaitForChild("Reliable"):FireServer(unpack(args))
            end)
            task.wait(0.5) 
            continue 
        end

        if HasQuest110 and soulCount == 0 and nailCount == 0 then
            local map = Workspace:FindFirstChild("Map")
            local npcs = map and map:FindFirstChild("NPCs")
            local anderson = npcs and npcs:FindFirstChild("Anderson")

            if anderson then
                local root = anderson:FindFirstChild("HumanoidRootPart") or anderson:FindFirstChild("Head")
                local prompt = anderson:FindFirstChildWhichIsA("ProximityPrompt", true)

                if root then
                    hrp.CFrame = root.CFrame + Vector3.new(0, 3, 0)
                    hrp.Velocity = Vector3.zero
                    if prompt then
                        task.wait(0.5)
                        fireproximityprompt(prompt)
                        task.wait(1)
                    end
                end
            end
            continue
        end

        if not HasQuest110 then
            if soulCount < 10 then
                local foundItem = false
                if Workspace:FindFirstChild("Item") then
                    for _, drop in ipairs(Workspace.Item:GetChildren()) do
                        local itemDrop = drop:FindFirstChild("ItemDrop")
                        local nameVal = drop:FindFirstChild("ItemName") or (itemDrop and itemDrop:FindFirstChild("ItemName"))
                        local isTargetItem = (nameVal and nameVal.Value == "Soul of Herrscher of Flamescion") or (drop.Name == "Soul of Herrscher of Flamescion")

                        if isTargetItem then
                            local prompt = drop:FindFirstChildWhichIsA("ProximityPrompt", true)
                            local targetPart = drop:FindFirstChild("ItemDrop") or drop
                            if targetPart and prompt then
                                hrp.CFrame = targetPart.CFrame + Vector3.new(0, 3, 0)
                                hrp.Velocity = Vector3.zero
                                task.wait(0.3) 
                                fireproximityprompt(prompt)
                                foundItem = true
                                break 
                            end
                        end
                    end
                end
                task.wait(0.5)

            else
                if pandoraCount == 0 then
                    local args = {
                        buffer.fromstring("\020"),
                        buffer.fromstring("\254\002\000\006\bPurchase\001\020")
                    }
                    pcall(function()
                        Rep:WaitForChild("ABC - First Priority"):WaitForChild("Utility"):WaitForChild("Modules"):WaitForChild("Warp"):WaitForChild("Index"):WaitForChild("Event"):WaitForChild("Reliable"):FireServer(unpack(args))
                    end)
                    task.wait(1)
                end
                local argsQ = {110}
                pcall(function()
                    Rep:WaitForChild("QuestRemotes"):WaitForChild("AcceptQuest"):FireServer(unpack(argsQ))
                end)
                task.wait(1) 
            end
        end
    end
end)

-- ===== AUTO BBQ3 SUMMON LOGIC =====
task.spawn(function()
    local IsSavingToken = false 

    while true do
        task.wait(0.1)
        if not AutoBBQ3 then 
            IsSavingToken = false
            if not AutoKingMon then IsSummoningAction = false end
            continue 
        end

        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if not char or not hrp then continue end

        if Workspace:FindFirstChild("Living") and Workspace.Living:FindFirstChild("Q3Boss") then
            if IsSummoningAction then
                IsSummoningAction = false
                Rayfield:Notify({Title = "Battle", Content = "Q3 Boss Spawned! Combat Resumed.", Duration = 3})
            end
            task.wait(0.1)
            continue
        end

        local meatCount = GetItemCount("Delicious Meat")
        local ultraCount = GetItemCount("Ultra Premium BBQ Meat")
        local tokenData = LocalPlayer:WaitForChild("Data"):WaitForChild("Token")
        local tokenValue = tokenData and tokenData.Value or 0

        if ultraCount == 0 and meatCount < 5 then
            if IsSavingToken then
                if tokenValue >= 5000 then
                    IsSavingToken = false 
                    Rayfield:Notify({Title = "BBQ3", Content = "Token 5000 Terkumpul! Melanjutkan...", Duration = 3})
                else
                    IsSummoningAction = false 
                    Rayfield:Notify({Title = "Saving Token", Content = "Farming... (" .. tostring(tokenValue) .. "/5000)", Duration = 1})
                    task.wait(3)
                    continue
                end
            elseif tokenValue < 1000 then
                IsSavingToken = true
                IsSummoningAction = false 
                Rayfield:Notify({Title = "Low Token", Content = "Token < 1000. Memulai Farming sampai 5000...", Duration = 3})
                task.wait(0.1)
                continue
            end
        end

        IsSummoningAction = true

        if ultraCount > 0 then
            local map = Workspace:FindFirstChild("Map")
            local ruined = map and map:FindFirstChild("RuinedCity")
            local spawnPart = ruined and ruined:FindFirstChild("Spawn")
            if spawnPart then
                local prompt = spawnPart:FindFirstChild("ProximityPrompt")
                hrp.CFrame = spawnPart.CFrame + Vector3.new(0, 3, 0)
                hrp.Velocity = Vector3.zero
                if prompt then
                    task.wait(0.5)
                    fireproximityprompt(prompt)
                    Rayfield:Notify({Title = "Phase 4", Content = "Summoning Q3BOSS...", Duration = 1})
                end
            end
            task.wait(0.1) 
            continue 
        end
            
        if ultraCount == 0 and meatCount >= 5 then
            Rayfield:Notify({Title = "BBQ3", Content = "Crafting Ultra Premium Meat... (Combat Paused)", Duration = 1})
            local args = {
                buffer.fromstring("\005"),
                buffer.fromstring("\254\003\000\006\004Rest\006\022Ultra Premium BBQ Meat\006\005Craft")
            }
            pcall(function()
                Rep:WaitForChild("ABC - First Priority"):WaitForChild("Utility"):WaitForChild("Modules"):WaitForChild("Warp"):WaitForChild("Index"):WaitForChild("Event"):WaitForChild("Reliable"):FireServer(unpack(args))
            end)
            task.wait(0.1)
            continue
        end

        if ultraCount == 0 and meatCount < 5 then
            local needed = 5 - meatCount
            Rayfield:Notify({Title = "BBQ3", Content = "Buying Delicious Meat... (Combat Paused)", Duration = 1})
            for i = 1, needed do
                if not AutoBBQ3 then break end
                if LocalPlayer.Data.Token.Value < 1000 then break end 
                local args = {
                    buffer.fromstring("\b"),
                    buffer.fromstring("\254\001\000\006\rDeliciousMeat")
                }
                pcall(function()
                    Rep:WaitForChild("ABC - First Priority"):WaitForChild("Utility"):WaitForChild("Modules"):WaitForChild("Warp"):WaitForChild("Index"):WaitForChild("Event"):WaitForChild("Reliable"):FireServer(unpack(args))
                end)
                task.wait(0.1)
            end
            task.wait(0.1)
        end
    end
end)

-- ===== AUTO GOJO LOOP (OLD) =====
task.spawn(function()
    while true do
        task.wait(0.2)
        if IsSummoningAction then continue end 

        if not AutoGojo then
            FollowTarget = false
            HollowFollow = false
            continue
        end

        CurrentGojoTarget = GetValidTargetFromList(GojoTargetList)

        if not CurrentGojoTarget then
            FollowTarget = false
            HollowFollow = false
            if not IsSummoningAction then
                ForceKillByVoid() 
            end
            repeat 
                task.wait(1) 
                CurrentGojoTarget = GetValidTargetFromList(GojoTargetList)
            until not AutoGojo or CurrentGojoTarget or IsSummoningAction
            task.wait(1)
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

        while AutoGojo and not IsSummoningAction and hum.Health > 54 do
            RunService.Heartbeat:Wait() 
        end
        
        if not AutoGojo or IsSummoningAction then continue end

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
            if not AutoGojo or IsSummoningAction then break end
            task.wait()
        end

        if AutoGojo and not IsSummoningAction then
            pcall(function()
                Gojo.HollowPurple:FireServer()
            end)
        end

        task.wait(23)
        HollowFollow = false
        FollowTarget = false
        if AutoGojo and not IsSummoningAction then
            ForceKillByVoid()
        end
    end
end)

-- ===== AUTO RED LOOP =====
task.spawn(function()
    while true do
        task.wait(1)
        if IsSummoningAction then continue end 

        if not AutoRed then
            RedFollow = false
            continue
        end

        CurrentRedTarget = GetValidTargetFromList(RedTargetList)

        if not CurrentRedTarget then
             RedFollow = false
             repeat
                task.wait(0.1)
                CurrentRedTarget = GetValidTargetFromList(RedTargetList)
             until not AutoRed or CurrentRedTarget or IsSummoningAction
             
             if not AutoRed or IsSummoningAction then continue end
        end

        local char = LocalPlayer.Character
        if not char then continue end

        UseFold(0.1)
        if not AutoRed then continue end
        task.wait(0.001)

        RedFollow = true
        task.wait(0.001)

        pcall(function()
            Gojo.RevRed2:FireServer()
        end)

        task.wait(3)

        RedFollow = false
        if AutoRed and not IsSummoningAction then
            ForceKillByVoid()
        end
    end
end)

-- ===== [NEW] AUTO Z MOVE LOOP (Custom Remote) =====
task.spawn(function()
    while true do
        task.wait(0.1)
        if IsSummoningAction then continue end 

        if not AutoZMove then
            ZMoveFollow = false
            continue
        end

        CurrentZMoveTarget = GetValidTargetFromList(ZMoveTargetList)

        if not CurrentZMoveTarget then
             ZMoveFollow = false
             repeat
                task.wait(0.1)
                CurrentZMoveTarget = GetValidTargetFromList(ZMoveTargetList)
             until not AutoZMove or CurrentZMoveTarget or IsSummoningAction
             
             if not AutoZMove or IsSummoningAction then continue end
        end

        local char = LocalPlayer.Character
        if not char then continue end

        UseFold(0.1)
        if not AutoZMove then continue end
        task.wait(0.001)

        ZMoveFollow = true
        task.wait(0.5)

        pcall(function()
            local args = {
                buffer.fromstring("\022"),
                buffer.fromstring("\254\002\000\006\001Z\005\000")
            }
            Rep:WaitForChild("ABC - First Priority"):WaitForChild("Utility"):WaitForChild("Modules"):WaitForChild("Warp"):WaitForChild("Index"):WaitForChild("Event"):WaitForChild("Reliable"):FireServer(unpack(args))
        end)

        task.wait(3)

        ZMoveFollow = false
        if AutoZMove and not IsSummoningAction then
            ForceKillByVoid()
        end
    end
end)

-- ===== AUTO LOOT LOOP (REWORKED) =====
task.spawn(function()
    while task.wait(0.5) do
        if IsSummoningAction then 
            continue 
        end

        if not AutoLootRework then 
            LootingActive = false
            continue 
        end
        
        if FollowTarget or HollowFollow or RedFollow or CounterFollow or PurpleFollow or ZMoveFollow then
            LootingActive = false
            continue
        end

        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if not hrp then continue end

        local items = Workspace:FindFirstChild("Item") and Workspace.Item:GetChildren() or {}

        if #items > 0 then
            LootingActive = true
            for _, item in ipairs(items) do
                if not AutoLootRework then break end
                if IsSummoningAction then break end
                if FollowTarget or HollowFollow or RedFollow or CounterFollow or PurpleFollow or ZMoveFollow then break end

                local itemName = item.Name
                local nameVal = item:FindFirstChild("ItemName") or (item:FindFirstChild("ItemDrop") and item.ItemDrop:FindFirstChild("ItemName"))
                if nameVal then itemName = nameVal.Value end

                if ItemBlacklist[itemName] then 
                    continue 
                end

                local prompt = item:FindFirstChildWhichIsA("ProximityPrompt", true)
                local targetPart = item:FindFirstChild("ItemDrop") or item:FindFirstChildWhichIsA("BasePart") or item

                if prompt and targetPart and targetPart:IsA("BasePart") then
                    hrp.CFrame = targetPart.CFrame + Vector3.new(0, 3, 0)
                    hrp.Velocity = Vector3.zero
                    hrp.AssemblyLinearVelocity = Vector3.zero
                    
                    prompt.HoldDuration = 0
                    prompt.MaxActivationDistance = 50
                    
                    task.wait(0.15) 
                    fireproximityprompt(prompt) 
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
            if AutoZMove and (not CurrentZMoveTarget or not IsTargetAlive(CurrentZMoveTarget)) then
                CurrentZMoveTarget = GetValidTargetFromList(ZMoveTargetList)
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

-- ==== AUTO GOJO REWORK LOOP ====
task.spawn(function()
    while true do
        task.wait(2)
        if IsSummoningAction then continue end

        if not AutoGojoRework then
            CounterFollow = false
            PurpleFollow = false
            continue
        end

        CurrentPurpleTarget = GetValidTargetFromList(PurpleTargetList)
        
        if not CurrentCounterTarget or not IsTargetAlive(CurrentCounterTarget) then
             CurrentCounterTarget = GetValidTargetFromList(CounterTargetList)
        end

        if not CurrentCounterTarget then
            CounterFollow = false
            PurpleFollow = false
            Rayfield:Notify({Title = "System", Content = "Waiting for Counter Dummy...", Duration = 3})
            
            repeat 
                task.wait(1)
                CurrentCounterTarget = GetValidTargetFromList(CounterTargetList)
            until not AutoGojoRework or CurrentCounterTarget or IsSummoningAction
            
            task.wait(1)
            continue
        end

        if not CurrentPurpleTarget then
             Rayfield:Notify({Title = "System", Content = "Waiting for Purple Target...", Duration = 3})             
             CounterFollow = false
             PurpleFollow = false
            
             repeat
                task.wait(1)
                CurrentPurpleTarget = GetValidTargetFromList(PurpleTargetList)
             until not AutoGojoRework or CurrentPurpleTarget or IsSummoningAction
             
             if not AutoGojoRework or IsSummoningAction then continue end
        end

        local char = LocalPlayer.Character
        local hum = char and char:FindFirstChild("Humanoid")
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if not hum or not hrp then continue end

        UseFold(0.5)
        CounterFollow = true 
        task.wait(0.5)
        
        local nextPunchTime = 0
        while AutoGojoRework and not IsSummoningAction and hum.Health > 54 and IsTargetAlive(CurrentCounterTarget) do
            if os.clock() >= nextPunchTime then
                pcall(function() Gojo.Punch:FireServer() end)
                nextPunchTime = os.clock() + 0.35
            end
            RunService.Heartbeat:Wait()
        end
        
        if not AutoGojoRework or IsSummoningAction then continue end

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
        
        if not IsTargetAlive(CurrentCounterTarget) then
             CurrentCounterTarget = GetValidTargetFromList(CounterTargetList)
        end

        if CurrentCounterTarget then
            CounterFollow = true
            task.wait(0.1)
            local phase3Start = os.clock()
            local nextPunchStep3 = 0
            while (os.clock() - phase3Start < 12) and AutoGojoRework and not IsSummoningAction do
                if os.clock() >= nextPunchStep3 then
                    pcall(function() Gojo.Punch:FireServer() end)
                    nextPunchStep3 = os.clock() + 0.35
                end
                RunService.Heartbeat:Wait()
            end
        end

        task.wait(0.5)

        CounterFollow = false
        PurpleFollow = true 
        
        local t = os.clock()
        while os.clock() - t < 50 do
            if not AutoGojoRework or IsSummoningAction then break end
            task.wait()
        end

        if AutoGojoRework and not IsSummoningAction then
            pcall(function()
                Gojo.HollowPurple:FireServer()
            end)
        end

        task.wait(23)
        PurpleFollow = false
        CounterFollow = false
        if AutoGojoRework and not IsSummoningAction then
            ForceKillByVoid()
        end
    end
end)
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

-- NEW VARIABLE: AUTO KING MON
local AutoKingMon = false 

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

-- ===== HELPER: ITEM COUNT IN BACKPACK =====
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

-- TAB: UTILITY (Moved Auto Clear here and added King Mon)
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
        if GojoDropdown then GojoDropdown:Refresh(newTargets, GojoTargetList) end
        if RedDropdown then RedDropdown:Refresh(newTargets, RedTargetList) end
        if PurpleDropdown then PurpleDropdown:Refresh(newTargets, PurpleTargetList) end
    end
})

Tab:CreateButton({
    Name = "Clear All Targets (Reset & Save)",
    Callback = function()
        PurpleTargetList = {}
        RedTargetList = {}
        GojoTargetList = {}
        CounterTargetList = {"Counter Dummy"} 

        CurrentPurpleTarget = nil
        CurrentRedTarget = nil
        CurrentGojoTarget = nil

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
        if AutoKingMon and v then 
            Rayfield:Notify({Title = "Blocked", Content = "Cannot enable while Auto King Mon is active!", Duration = 3})
            return 
        end
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
        if AutoKingMon and v then 
            Rayfield:Notify({Title = "Blocked", Content = "Cannot enable while Auto King Mon is active!", Duration = 3})
            return 
        end
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

UtilityTab:CreateSection("Boss Summoner")

-- [NEW] AUTO KING MON TOGGLE
UtilityTab:CreateToggle({
    Name = "Auto King Mon Summon",
    CurrentValue = false,
    Flag = "AutoKingMon", 
    Callback = function(v)
        AutoKingMon = v
        if v then
            -- MATIKAN AUTO LAIN SESUAI INSTRUKSI
            AutoGojo = false
            AutoGojoRework = false
            AutoRed = false
            
            -- RESET FOLLOW STATES
            FollowTarget = false
            RedFollow = false
            HollowFollow = false
            CounterFollow = false
            PurpleFollow = false
            LootingActive = false -- Pause loot biasa
            
            Rayfield:Notify({Title = "System", Content = "Auto King Mon Started. Combat paused.", Duration = 3})
        else
            Rayfield:Notify({Title = "System", Content = "Auto King Mon Stopped.", Duration = 3})
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
        if AutoKingMon and v then 
            Rayfield:Notify({Title = "Blocked", Content = "Cannot enable while Auto King Mon is active!", Duration = 3})
            return 
        end
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
    -- Jika Auto King Mon aktif, jangan jalankan follow combat
    if AutoKingMon then return end
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
            hrp.CFrame = CFrame.new(thrp.Position + (-thrp.CFrame.RightVector * 3), thrp.Position)
            hrp.Velocity = Vector3.zero
            hrp.AssemblyLinearVelocity = Vector3.zero
        end

    -- 2. PurpleFollow (Rework Phase Ulti)
    elseif PurpleFollow then
        local target = CurrentPurpleTarget
        if target and target:FindFirstChild("HumanoidRootPart") then
            local thrp = target.HumanoidRootPart
            hrp.CFrame = CFrame.new(thrp.Position + Vector3.new(-20, 26, 0), thrp.Position)
        end

    -- 3. HollowFollow / RedFollow
    elseif HollowFollow or RedFollow then
        local activeTarget = AutoRed and CurrentRedTarget or CurrentGojoTarget
        if activeTarget and activeTarget:FindFirstChild("HumanoidRootPart") then
            local thrp = activeTarget.HumanoidRootPart
            hrp.CFrame = CFrame.new(thrp.Position + Vector3.new(0, 26, 0), thrp.Position)
            hrp.Velocity = Vector3.zero 
            hrp.AssemblyLinearVelocity = Vector3.zero
        end

    -- 4. FollowTarget
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
        if AutoGojo or AutoRed or AutoGojoRework then
            task.wait(3) 
        else
            task.wait(1.5)
        end

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
            task.wait(0.1)
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

-- =======================================================
-- ===== AUTO KING MON LOGIC (WITH GET NAIL STEP) ========
-- =======================================================
task.spawn(function()
    while true do
        task.wait(1)
        if not AutoKingMon then continue end

        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if not char or not hrp then continue end

        -- [STEP 0] Cek Keberadaan Boss
        if Workspace:FindFirstChild("Living") and Workspace.Living:FindFirstChild("King Mon") then
            Rayfield:Notify({Title = "Success", Content = "King Mon Spawned!", Duration = 5})
            AutoKingMon = false
            continue
        end

        -- Update Inventory & Quest State
        local soulCount = GetItemCount("Soul of Herrscher of Flamescion")
        local nailCount = GetItemCount("Holy Nail of Helena")
        local pandoraCount = GetItemCount("Pandora's Box")
        
        local QuestFolder = LocalPlayer:FindFirstChild("QuestFolder")
        local HasQuest110 = QuestFolder and QuestFolder:FindFirstChild("110")

        -- [STEP 4] SUMMON PHASE (Prioritas Utama: Jika sudah punya Holy Nail)
        if nailCount > 0 then
            local map = Workspace:FindFirstChild("Map")
            local ruined = map and map:FindFirstChild("RuinedCity")
            local spawnPart = ruined and ruined:FindFirstChild("Spawn")
            
            if spawnPart then
                local prompt = spawnPart:FindFirstChildWhichIsA("ProximityPrompt", true)
                hrp.CFrame = spawnPart.CFrame + Vector3.new(0, 3, 0)
                hrp.Velocity = Vector3.zero
                
                if prompt then
                    task.wait(0.5)
                    fireproximityprompt(prompt)
                    Rayfield:Notify({Title = "Phase 4", Content = "Summoning King Mon...", Duration = 1})
                end
            else
                Rayfield:Notify({Title = "Error", Content = "RuinedCity Spawn not found!", Duration = 3})
            end
            task.wait(2)
            continue 
        end

        -- [STEP 3] TURN IN PHASE (Jika Punya Quest & Ada Soul)
        if HasQuest110 and soulCount > 0 then
            Rayfield:Notify({Title = "Phase 3", Content = "Turning In Souls: " .. tostring(soulCount), Duration = 1})
            
            local args = {
                buffer.fromstring("\014"),
                buffer.fromstring("\254\002\000\006\006TurnIn\006\031Soul of Herrscher of Flamescion")
            }
            pcall(function()
                game:GetService("ReplicatedStorage"):WaitForChild("ABC - First Priority"):WaitForChild("Utility"):WaitForChild("Modules"):WaitForChild("Warp"):WaitForChild("Index"):WaitForChild("Event"):WaitForChild("Reliable"):FireServer(unpack(args))
            end)
            task.wait(0.5) 
            continue 
        end

        -- [STEP 3.5] GET HOLY NAIL (Jika Soul Habis, Quest Aktif, Tapi Belum Punya Nail)
        if HasQuest110 and soulCount == 0 and nailCount == 0 then
            Rayfield:Notify({Title = "Phase 3.5", Content = "Getting Holy Nail from Anderson...", Duration = 1})

            local map = Workspace:FindFirstChild("Map")
            local npcs = map and map:FindFirstChild("NPCs")
            local anderson = npcs and npcs:FindFirstChild("Anderson")

            if anderson then
                local root = anderson:FindFirstChild("HumanoidRootPart") or anderson:FindFirstChild("Head")
                local prompt = anderson:FindFirstChildWhichIsA("ProximityPrompt", true)

                if root then
                    -- Teleport ke Anderson
                    hrp.CFrame = root.CFrame + Vector3.new(0, 3, 0)
                    hrp.Velocity = Vector3.zero
                    
                    if prompt then
                        task.wait(0.5)
                        fireproximityprompt(prompt)
                        task.wait(1) -- Beri waktu interaksi
                    else
                         Rayfield:Notify({Title = "Error", Content = "Anderson has no Prompt!", Duration = 3})
                    end
                end
            else
                Rayfield:Notify({Title = "Error", Content = "Anderson NPC Not Found!", Duration = 3})
            end
            continue -- Lanjut loop, script akan otomatis masuk Step 4 setelah dapat Nail
        end

        -- [STEP 1 & 2] PREPARATION PHASE (Hanya jika BELUM punya Quest)
        if not HasQuest110 then
            -- [Step 1] Farming Soul jika kurang dari 10
            if soulCount < 10 then
                Rayfield:Notify({Title = "Phase 1", Content = "Farming Souls ("..soulCount.."/10)", Duration = 1})
                
                local foundItem = false
                if Workspace:FindFirstChild("Item") then
                    for _, drop in ipairs(Workspace.Item:GetChildren()) do
                        local itemDrop = drop:FindFirstChild("ItemDrop")
                        local nameVal = drop:FindFirstChild("ItemName") or (itemDrop and itemDrop:FindFirstChild("ItemName"))
                        
                        local isTargetItem = false
                        if nameVal and nameVal.Value == "Soul of Herrscher of Flamescion" then
                            isTargetItem = true
                        elseif drop.Name == "Soul of Herrscher of Flamescion" then
                            isTargetItem = true
                        end

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

            -- [Step 2] Soul sudah 10 -> Beli Pandora -> Accept Quest
            else
                Rayfield:Notify({Title = "Phase 2", Content = "Buying Pandora & Accepting Quest", Duration = 1})
                
                if pandoraCount == 0 then
                    local args = {
                        buffer.fromstring("\020"),
                        buffer.fromstring("\254\002\000\006\bPurchase\001\020")
                    }
                    pcall(function()
                        game:GetService("ReplicatedStorage"):WaitForChild("ABC - First Priority"):WaitForChild("Utility"):WaitForChild("Modules"):WaitForChild("Warp"):WaitForChild("Index"):WaitForChild("Event"):WaitForChild("Reliable"):FireServer(unpack(args))
                    end)
                    task.wait(1)
                end

                local argsQ = {110}
                pcall(function()
                    game:GetService("ReplicatedStorage"):WaitForChild("QuestRemotes"):WaitForChild("AcceptQuest"):FireServer(unpack(argsQ))
                end)
                task.wait(1.5) 
            end
        end
    end
end)


-- ===== AUTO GOJO LOOP (OLD) =====
task.spawn(function()
    while true do
        task.wait(0.2)
        if AutoKingMon then continue end -- Pause if King Mon Active
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
            until not AutoGojo or CurrentGojoTarget or AutoKingMon
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

        while AutoGojo and not AutoKingMon and hum.Health > 54 do
            RunService.Heartbeat:Wait() 
        end
        
        if not AutoGojo or AutoKingMon then continue end

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
            if not AutoGojo or AutoKingMon then break end
            task.wait()
        end

        if AutoGojo and not AutoKingMon then
            pcall(function()
                Gojo.HollowPurple:FireServer()
            end)
        end

        task.wait(23)
        HollowFollow = false
        FollowTarget = false
        if AutoGojo and not AutoKingMon then
            ForceKillByVoid()
        end
    end
end)

-- ===== AUTO RED LOOP (FIXED) =====
task.spawn(function()
    while true do
        task.wait(1)
        if AutoKingMon then continue end -- Pause
        if not AutoRed then
            RedFollow = false
            continue
        end

        CurrentRedTarget = GetValidTargetFromList(RedTargetList)

        if not CurrentRedTarget then
             Rayfield:Notify({Title = "System", Content = "Waiting for Red Target...", Duration = 3})
             RedFollow = false
            
             repeat
                task.wait(0.1)
                CurrentRedTarget = GetValidTargetFromList(RedTargetList)
             until not AutoRed or CurrentRedTarget or AutoKingMon
             
             if not AutoRed or AutoKingMon then continue end
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
        if AutoRed and not AutoKingMon then
            ForceKillByVoid()
        end
    end
end)

-- ===== AUTO LOOT LOOP =====
task.spawn(function()
    while task.wait(0.5) do
        if AutoKingMon then 
            -- Pause normal looting, King Mon has its own loot logic
            continue 
        end

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
                if not AutoLoot or AutoKingMon then break end
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

-- ==== AUTO GOJO REWORK LOOP (FIXED) ====
task.spawn(function()
    while true do
        task.wait(1.7)
        if AutoKingMon then continue end -- Pause
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
            until not AutoGojoRework or CurrentCounterTarget or AutoKingMon
            
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
             until not AutoGojoRework or CurrentPurpleTarget or AutoKingMon
             
             if not AutoGojoRework or AutoKingMon then continue end
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
        while AutoGojoRework and not AutoKingMon and hum.Health > 54 and IsTargetAlive(CurrentCounterTarget) do
            if os.clock() >= nextPunchTime then
                pcall(function() Gojo.Punch:FireServer() end)
                nextPunchTime = os.clock() + 0.35
            end
            RunService.Heartbeat:Wait()
        end
        
        if not AutoGojoRework or AutoKingMon then continue end

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
        if not IsTargetAlive(CurrentCounterTarget) then
             CurrentCounterTarget = GetValidTargetFromList(CounterTargetList)
        end

        if CurrentCounterTarget then
            CounterFollow = true
            task.wait(0.1)
            local phase3Start = os.clock()
            local nextPunchStep3 = 0
            while (os.clock() - phase3Start < 12) and AutoGojoRework and not AutoKingMon do
                if os.clock() >= nextPunchStep3 then
                    pcall(function() Gojo.Punch:FireServer() end)
                    nextPunchStep3 = os.clock() + 0.35
                end
                RunService.Heartbeat:Wait()
            end
        end

        task.wait(0.5)

        -- Step 4: Purple Phase (Pindah Target ke Musuh Asli)
        CounterFollow = false
        PurpleFollow = true 
        
        local t = os.clock()
        while os.clock() - t < 50 do
            if not AutoGojoRework or AutoKingMon then break end
            task.wait()
        end

        if AutoGojoRework and not AutoKingMon then
            pcall(function()
                Gojo.HollowPurple:FireServer()
            end)
        end

        task.wait(23)
        PurpleFollow = false
        CounterFollow = false
        if AutoGojoRework and not AutoKingMon then
            ForceKillByVoid()
        end
    end
end)

-- LOAD SAVED CONFIGURATION AT THE END
Rayfield:LoadConfiguration()
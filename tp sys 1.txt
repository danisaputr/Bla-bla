-- ================= SERVICES =================
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualInputManager = game:GetService("VirtualInputManager")

local player = Players.LocalPlayer

-- ================= RAYFIELD UI =================
local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()

local Window = Rayfield:CreateWindow({
    Name = "Teleport + Auto Loot System",
    LoadingTitle = "Teleport Controller",
    LoadingSubtitle = "Rayfield UI",
    ConfigurationSaving = {
        Enabled = true,
        FolderName = "RayfieldConfigs",
        FileName = "TeleportAutoLoot"
    }
})

local MainTab = Window:CreateTab("Main", 4483362458)

-- ================= FOLDERS =================
local LivingFolder = workspace:WaitForChild("Living")
local ItemFolder = workspace:WaitForChild("Item")
local BossFolder = ReplicatedStorage:WaitForChild("BossNames")

-- ================= CONFIG =================
local OFFSET_DISTANCE = 35
local TeleportMode = "Bawah"

local AutoTeleport = false
local AutoHit = false
local AutoLoot = false

local LootDelay = 0.5
local CurrentTarget

-- ================= SAFEZONE =================
local SAFEZONE_POS = Vector3.new(151, 1011, -799)
local InSafezone = false

-- ================= DATA =================
local SelectedEnemies = {}
local ItemBlacklist = {}

local AutoItemRefresh = true
local LastItemSignature = ""

-- ================= HIT REMOTES =================
local HitRemote = ReplicatedStorage
    :WaitForChild("ABC - First Priority")
    :WaitForChild("Utility")
    :WaitForChild("Modules")
    :WaitForChild("Warp")
    :WaitForChild("Index")
    :WaitForChild("Event")
    :WaitForChild("Reliable")

local EmperorPunchRemote = ReplicatedStorage
    :WaitForChild("EmperorRemote")
    :WaitForChild("Punch")

local HitArgs_LMB = {
    buffer.fromstring("\022"),
    buffer.fromstring("\254\002\000\006\003LMB\005\001")
}

-- ================= FUNCTIONS =================
local function getHRP()
    local char = player.Character or player.CharacterAdded:Wait()
    return char:WaitForChild("HumanoidRootPart")
end

local function isAlive(model)
    local hum = model and model:FindFirstChildOfClass("Humanoid")
    return hum and hum.Health > 0
end

local function ensurePrimary(model)
    if model and not model.PrimaryPart then
        local p = model:FindFirstChildWhichIsA("BasePart")
        if p then model.PrimaryPart = p end
    end
end

local function sortEnemyNames(list)
    table.sort(list, function(a, b)
        local aL = a:match("^[A-Za-z]") ~= nil
        local bL = b:match("^[A-Za-z]") ~= nil
        if aL ~= bL then return aL end
        return a:lower() < b:lower()
    end)
end

local function findTarget()
    for _, model in ipairs(LivingFolder:GetChildren()) do
        if model:IsA("Model")
        and SelectedEnemies[model.Name]
        and isAlive(model) then
            ensurePrimary(model)
            return model
        end
    end
end

local function getOffset(cf)
    local look, right, up = cf.LookVector, cf.RightVector, Vector3.new(0,1,0)
    if TeleportMode == "Atas" then
        return cf.Position + up * OFFSET_DISTANCE
    elseif TeleportMode == "Bawah" then
        return cf.Position - up * OFFSET_DISTANCE
    elseif TeleportMode == "Depan" then
        return cf.Position + look * OFFSET_DISTANCE
    elseif TeleportMode == "Belakang" then
        return cf.Position - look * OFFSET_DISTANCE
    elseif TeleportMode == "Kanan" then
        return cf.Position + right * OFFSET_DISTANCE
    elseif TeleportMode == "Kiri" then
        return cf.Position - right * OFFSET_DISTANCE
    end
end

-- ================= INPUT =================
local function pressE()
    VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.E, false, game)
    task.wait(0.05)
    VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game)
end

-- ================= ITEM HELPERS =================
local function getItemNameList()
    local names, seen = {}, {}
    for _, obj in ipairs(ItemFolder:GetDescendants()) do
        if obj:IsA("ProximityPrompt") then
            local part = obj.Parent
            if part and part:IsA("BasePart") and not seen[part.Name] then
                seen[part.Name] = true
                table.insert(names, part.Name)
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
    return prompts
end

local function hasLootableItem()
    for _, obj in ipairs(ItemFolder:GetDescendants()) do
        if obj:IsA("ProximityPrompt") then
            if not ItemBlacklist[obj.Parent.Name] then
                return true
            end
        end
    end
end

-- ================= AUTO LOOT =================
local function collectDroppedItems()
    local hrp = getHRP()
    for _, prompt in ipairs(getSortedItemPrompts()) do
        if not AutoLoot then return end
        local part = prompt.Parent
        if part then
            InSafezone = false
            hrp.CFrame = part.CFrame + Vector3.new(0,2,0)
            prompt.HoldDuration = 0
            prompt.MaxActivationDistance = 1e6
            task.wait(0.1)
            pressE()
            task.wait(LootDelay)
        end
    end
end

-- ================= SAFEZONE =================
local function teleportToSafezone()
    getHRP().CFrame = CFrame.new(SAFEZONE_POS)
    InSafezone = true
end

-- ================= GUI =================
MainTab:CreateToggle({
    Name = "Auto Teleport",
    Flag = "AutoTeleport",
    Callback = function(v) AutoTeleport = v end
})

MainTab:CreateToggle({
    Name = "Auto Hit (LMB + Punch)",
    Flag = "AutoHit",
    Callback = function(v) AutoHit = v end
})

MainTab:CreateToggle({
    Name = "Auto Loot",
    Flag = "AutoLoot",
    Callback = function(v) AutoLoot = v end
})

MainTab:CreateSlider({
    Name = "Jarak Teleport",
    Flag = "TeleportDistance",
    Range = {1,200},
    Increment = 1,
    CurrentValue = OFFSET_DISTANCE,
    Callback = function(v) OFFSET_DISTANCE = v end
})

MainTab:CreateSlider({
    Name = "Delay Ambil Loot",
    Flag = "LootDelay",
    Range = {0,5},
    Increment = 0.1,
    CurrentValue = LootDelay,
    Callback = function(v) LootDelay = v end
})

MainTab:CreateDropdown({
    Name = "Mode Teleport",
    Flag = "TeleportMode",
    Options = {"Atas","Bawah","Depan","Belakang","Kanan","Kiri"},
    CurrentOption = {"Bawah"},
    Callback = function(v) TeleportMode = v[1] end
})

-- ================= ENEMY SELECTOR =================
local bossNames = {}
for _, b in ipairs(BossFolder:GetChildren()) do
    bossNames[#bossNames+1] = b.Name
    SelectedEnemies[b.Name] = false
end
sortEnemyNames(bossNames)

MainTab:CreateDropdown({
    Name = "Enemy Selector",
    Flag = "EnemySelector",
    Options = bossNames,
    MultipleOptions = true,
    Callback = function(list)
        table.clear(SelectedEnemies)
        for _, name in ipairs(list) do
            SelectedEnemies[name] = true
        end
    end
})

-- ================= ITEM BLACKLIST =================
local blacklistDropdown
local function buildItemBlacklistDropdown(preserved)
    if blacklistDropdown then blacklistDropdown:Destroy() end
    blacklistDropdown = MainTab:CreateDropdown({
        Name = "Item Blacklist (Kecuali)",
        Flag = "ItemBlacklist",
        Options = getItemNameList(),
        MultipleOptions = true,
        CurrentOption = preserved or {},
        Callback = function(selected)
            table.clear(ItemBlacklist)
            for _, name in ipairs(selected) do
                ItemBlacklist[name] = true
            end
        end
    })
end
buildItemBlacklistDropdown()

-- ================= AUTO REFRESH ITEM =================
task.spawn(function()
    while task.wait(0.001) do
        if not AutoItemRefresh then continue end
        local sig = getItemSignature()
        if sig ~= LastItemSignature then
            LastItemSignature = sig
            local keep = {}
            for name in pairs(ItemBlacklist) do
                keep[#keep+1] = name
            end
            buildItemBlacklistDropdown(keep)
        end
    end
end)

-- ================= MAIN LOOP =================
task.spawn(function()
    while task.wait() do -- Menggunakan wait() default agar tidak crash
        -- 1. Validasi Kehidupan Player (PENTING)
        -- Kita cek dulu apakah player hidup dan punya RootPart sebelum lanjut
        local char = player.Character
        if not char or not char:FindFirstChild("HumanoidRootPart") or not isAlive(char) then
            -- Jika mati, tunggu sebentar dan skip loop ini
            -- Ini mencegah script error saat mencoba memindahkan mayat
            CurrentTarget = nil -- Reset target saat mati
            InSafezone = false
            task.wait(0.5)
            continue
        end

        local hrp = char.HumanoidRootPart -- Gunakan variabel ini, jangan panggil getHRP() terus menerus

        -- 2. Logika Mencari Target
        if not isAlive(CurrentTarget)
        or (CurrentTarget and not SelectedEnemies[CurrentTarget.Name]) then
            CurrentTarget = findTarget()
        end

        -- 3. Eksekusi Teleport / Hit / Loot
        if CurrentTarget and CurrentTarget.PrimaryPart then
            InSafezone = false
            if AutoTeleport then
                local cf = CurrentTarget.PrimaryPart.CFrame
                -- Menggunakan pcall agar jika terjadi error fisika, script tidak berhenti
                pcall(function()
                    hrp.CFrame = CFrame.new(getOffset(cf), cf.Position)
                end)
            end
            
            if AutoHit then
                HitRemote:FireServer(unpack(HitArgs_LMB))
                EmperorPunchRemote:FireServer()
            end
        else
            -- Mode Looting / Safezone
            if AutoLoot and hasLootableItem() then
                collectDroppedItems()
            elseif not InSafezone then
                -- Gunakan hrp yang sudah divalidasi
                hrp.CFrame = CFrame.new(SAFEZONE_POS)
                InSafezone = true
            end
        end
    end
end)
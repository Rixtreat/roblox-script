-- [[ Daley Hub v20.0 ]] --
-- Credits: by Daley

-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualUser = game:GetService("VirtualUser")
local VirtualInputManager = game:GetService("VirtualInputManager")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")

local LP = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

-- Rayfield Library Boot
local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()

local Window = Rayfield:CreateWindow({
    Name = "Daley Hub v20.0",
    LoadingTitle = "Daley Hub Loaded Successfully",
    LoadingSubtitle = "by Daley",
    Theme = "Default",
    DisableRayfieldPrompts = false,
    DisableBuildWarnings = false,
    ConfigurationSaving = { Enabled = false },
    KeySystem = false,
})

-- ==========================================
-- [[ STATE STORAGE ]] --
-- ==========================================
local States = {
    -- Automation & Combat Actions
    AutoClaimRewards   = false,
    AutoClaimLevel     = false,
    AutoClaimBP        = false,
    AutoTask           = false,
    TaskID             = 2003001,
    TaskID2            = 1000001,
    AutoEnterBattle    = false,
    AutoAbandon        = false,
    AutoAbandonEnd     = false,
    AutoCatch          = false,
    CatchPetID         = 9115276855,
    LogPetClicks       = false,
    
    -- Standalone Interact Spam
    AutoSpamE          = false,
    
    -- Quest Teleporter State
    SelectedQuestNPC   = nil,
    
    -- Skill Automation State
    AutoSkills1Enabled = false,
    Skill1DelayTime    = 0.1,
    AutoSkills2Enabled = false,
    Skill2DelayTime    = 0.1,
    AutoSkills3Enabled = false,
    Skill3DelayTime    = 0.1,
    AutoSkills4Enabled = false,
    Skill4DelayTime    = 0.1,
    
    -- Chest Farming State
    AutoChestFarm      = false,
    ChestFarmDelay     = 4,
    
    -- Locomotion
    SpeedEnabled       = false,
    SpeedValue         = 50,
    FlyEnabled         = false,
    FlySpeed           = 50,
    NoclipEnabled      = false,
    
    -- Pokemon Auto Fight Walking Loop
    AutoFightWalk      = false,
    W_Duration         = 2,
    A_Duration         = 2,
    S_Duration         = 2,
    D_Duration         = 2,
    
    -- Visuals / ESP
    PlayerESP          = false,
    ShowHighlights     = true,
    ShowUsernames      = true,
    ShowDistance       = true,
    
    -- Universal Scanner
    ScanKeyword        = "",
    ScannerESP         = false,
    
    -- Target Management
    SelectedPlayer     = nil,

    -- Dungeon Automation
    AutoCreateDungeon  = false,
    SelectedDungeonTier= "Normal Mode",
    DungeonDifficultyID = 1,
    AutoSelectDungeonBuff = false,
    DungeonBuffID      = 101,

    -- Mail Rewards
    AutoClaimAllMail   = false,
    MailClaimInterval  = 5
}

local Player_ESP_Cache = {}
local Scanner_ESP_Cache = {}
local currentChestIndex = 0

-- Target Chest Root Directory Reference
local CHEST_DIR = Workspace:FindFirstChild("RuntimeCache") 
    and Workspace.RuntimeCache:FindFirstChild("RuntimeCacheClient") 
    and Workspace.RuntimeCache.RuntimeCacheClient:FindFirstChild("Chest")

-- Target Quest Directory Reference
local QUEST_DIR = Workspace:FindFirstChild("RefreshPoints") and Workspace.RefreshPoints:FindFirstChild("NPC")

-- ==========================================
-- [[ UTILITY FUNCTIONS ]] --
-- ==========================================
local function GetRoot(player)
    local p = player or LP
    local char = p.Character
    return char and (char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso"))
end

local function GetHumanoid()
    local char = LP.Character
    return char and char:FindFirstChildOfClass("Humanoid")
end

local function GetOtherPlayers()
    local names = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP then table.insert(names, p.Name) end
    end
    if #names == 0 then table.insert(names, "None") end
    return names
end

local function GetQuestNPCList()
    local npcList = {}
    if QUEST_DIR then
        for _, child in ipairs(QUEST_DIR:GetChildren()) do
            if child:IsA("BasePart") or child:IsA("Model") then
                table.insert(npcList, child.Name)
            end
        end
    end
    table.sort(npcList, function(a, b)
        local numA = tonumber(string.match(a, "%d+")) or 0
        local numB = tonumber(string.match(b, "%d+")) or 0
        if numA ~= numB then return numA < numB end
        return a < b
    end)
    if #npcList == 0 then table.insert(npcList, "No Quest NPCs Found") end
    return npcList
end

local function ServerHop()
    local success, result = pcall(function()
        local servers = HttpService:JSONDecode(game:HttpGet("https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100"))
        local possibleServers = {}
        
        for _, server in ipairs(servers.data) do
            if server.playing < server.maxPlayers and server.id ~= game.JobId then
                table.insert(possibleServers, server.id)
            end
        end
        
        if #possibleServers > 0 then
            local targetServer = possibleServers[math.random(1, #possibleServers)]
            TeleportService:TeleportToPlaceInstance(game.PlaceId, targetServer, LP)
        else
            Rayfield:Notify({
                Name = "Server Hop Failed",
                Content = "No alternative optimal servers found. Try again shortly.",
                Duration = 5,
                Image = 4483362458,
            })
        end
    end)
    
    if not success then
        warn("Server Hop Attempt Error: ", result)
    end
end

local function GatherUniqueChests()
    if not CHEST_DIR then return {} end
    local uniqueContainers = {}
    for _, child in ipairs(CHEST_DIR:GetChildren()) do
        if child:IsA("Folder") or child:IsA("Model") then
            table.insert(uniqueContainers, child)
        end
    end
    return uniqueContainers
end

local function TeleportToNextChest()
    local rootPart = GetRoot()
    if not rootPart then return end
    
    local chests = GatherUniqueChests()
    if #chests == 0 then return end
    
    currentChestIndex = currentChestIndex + 1
    if currentChestIndex > #chests then
        currentChestIndex = 1
    end
    
    local targetFolder = chests[currentChestIndex]
    local tpTarget = targetFolder:FindFirstChildWhichIsA("BasePart", true)
    
    if tpTarget then
        rootPart.CFrame = tpTarget.CFrame * CFrame.new(0, 3, 0)
    end
end

local function SpamEKey()
    if VirtualInputManager then
        pcall(function()
            VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.E, false, game)
            task.wait(0.05)
            VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game)
        end)
    end
end

-- Fires the battle operate remote directly for abandon actions
local function FireBattleAbandon(actionType, campId)
    local BattleRemote = ReplicatedStorage:FindFirstChild("Remote")
        and ReplicatedStorage.Remote:FindFirstChild("Battle")
        and ReplicatedStorage.Remote.Battle:FindFirstChild("ReqOperateBattle")
    if not BattleRemote then return end

    local payload = { actionType = actionType }
    if campId then payload.campId = campId end

    pcall(function()
        BattleRemote:InvokeServer(payload)
    end)
end

-- ==========================================
-- [[ ESP FRAMEWORKS ]] --
-- ==========================================
local function CreatePlayerESP(player)
    if player == LP or Player_ESP_Cache[player] then return end
    local container = {}

    local function applyESP(char)
        if not char then return end
        
        local hl = Instance.new("Highlight")
        hl.FillColor = Color3.fromRGB(0, 170, 255)
        hl.FillTransparency = 0.5
        hl.OutlineColor = Color3.fromRGB(255, 255, 255)
        hl.Adornee = char
        hl.Enabled = States.PlayerESP and States.ShowHighlights
        hl.Parent = char
        container.Highlight = hl

        local bb = Instance.new("BillboardGui")
        bb.Size = UDim2.new(0, 200, 0, 50)
        bb.AlwaysOnTop = true
        bb.ExtentsOffset = Vector3.new(0, 3, 0)
        bb.Enabled = States.PlayerESP
        bb.Parent = char
        container.Billboard = bb

        local lbl = Instance.new("TextLabel", bb)
        lbl.Size = UDim2.new(1, 0, 1, 0)
        lbl.BackgroundTransparency = 1
        lbl.TextSize = 13
        lbl.Font = Enum.Font.SourceSansBold
        lbl.TextColor3 = Color3.fromRGB(255, 255, 255)
        lbl.TextStrokeTransparency = 0
        container.Label = lbl

        local root = char:WaitForChild("HumanoidRootPart", 5)
        if root then bb.Adornee = root end
    end

    if player.Character then applyESP(player.Character) end
    player.CharacterAdded:Connect(applyESP)
    Player_ESP_Cache[player] = container
end

local function RemovePlayerESP(player)
    if Player_ESP_Cache[player] then
        pcall(function()
            if Player_ESP_Cache[player].Highlight then Player_ESP_Cache[player].Highlight:Destroy() end
            if Player_ESP_Cache[player].Billboard then Player_ESP_Cache[player].Billboard:Destroy() end
        end)
        Player_ESP_Cache[player] = nil
    end
end

for _, p in ipairs(Players:GetPlayers()) do CreatePlayerESP(p) end
Players.PlayerAdded:Connect(CreatePlayerESP)
Players.PlayerRemoving:Connect(RemovePlayerESP)

-- ==========================================
-- [[ UI TABS CREATION ]] --
-- ==========================================
local AutomationTab   = Window:CreateTab("Automation", nil)
local DungeonTab      = Window:CreateTab("Dungeon Hub", nil)
local MailTab         = Window:CreateTab("Mail Claims", nil)
local MovementTab     = Window:CreateTab("Movement", nil)
local VisualsTab      = Window:CreateTab("Visuals", nil)
local ScannerTab      = Window:CreateTab("Universal Scanner", nil)
local PlayersTab      = Window:CreateTab("Players", nil)

-- --- AUTOMATION TAB ---
AutomationTab:CreateSection("Server Navigation")

AutomationTab:CreateButton({
    Name     = "⚡ Server Hop ⚡",
    Callback = function() ServerHop() end,
})

AutomationTab:CreateSection("Interaction Utilities")

AutomationTab:CreateToggle({
    Name     = "Auto Spam 'E' Key",
    Default  = false,
    Callback = function(v) States.AutoSpamE = v end,
})

AutomationTab:CreateSection("Quest Teleporter Navigation")

local questDropdown = AutomationTab:CreateDropdown({
    Name = "Select Target Quest NPC",
    Options = GetQuestNPCList(),
    CurrentOption = {GetQuestNPCList()[1]},
    MultipleOptions = false,
    Callback = function(option) States.SelectedQuestNPC = option[1] end,
})

AutomationTab:CreateButton({
    Name     = "Refresh Quest Directory List",
    Callback = function() questDropdown:Refresh(GetQuestNPCList(), true) end,
})

AutomationTab:CreateButton({
    Name = "Teleport to Selected Quest NPC",
    Callback = function()
        local targetName = States.SelectedQuestNPC
        if not targetName or targetName == "No Quest NPCs Found" then return end
        
        if QUEST_DIR then
            local npcObject = QUEST_DIR:FindFirstChild(targetName)
            local root = GetRoot()
            
            if npcObject and root then
                local targetPart = npcObject:IsA("BasePart") and npcObject or npcObject:FindFirstChildWhichIsA("BasePart", true)
                if targetPart then
                    root.CFrame = targetPart.CFrame * CFrame.new(0, 3, 0)
                end
            else
                Rayfield:Notify({
                    Name = "Teleport Failed",
                    Content = "Target NPC could not be found or loaded in the Workspace.",
                    Duration = 3,
                    Image = 4483362458,
                })
            end
        end
    end,
})

AutomationTab:CreateSection("Chest Collection Infrastructure")

AutomationTab:CreateButton({
    Name     = "Teleport to Next Chest (Manual Step)",
    Callback = function() TeleportToNextChest() end,
})

AutomationTab:CreateToggle({
    Name     = "Auto Chest Cycle Farm",
    Default  = false,
    Callback = function(v) States.AutoChestFarm = v end,
})

AutomationTab:CreateSlider({
    Name         = "Auto Chest Interval Delay",
    Range        = {1, 15},
    Increment    = 1,
    Suffix       = " seconds",
    CurrentValue = 4,
    Callback     = function(v) States.ChestFarmDelay = v end,
})

AutomationTab:CreateSection("Pet Intercept & Data Sniffer")

AutomationTab:CreateToggle({
    Name     = "Log Pet Click Data",
    Default  = false,
    Callback = function(v) States.LogPetClicks = v end,
})

local PetDataLabel = AutomationTab:CreateLabel("Last Played Pet Data: None captured yet")

AutomationTab:CreateSection("Reward Automation")

AutomationTab:CreateToggle({
    Name     = "Auto Claim Pet Manual Rewards",
    Default  = false,
    Callback = function(v) States.AutoClaimRewards = v end,
})

AutomationTab:CreateToggle({
    Name     = "Auto Claim Level Rewards",
    Default  = false,
    Callback = function(v) States.AutoClaimLevel = v end,
})

AutomationTab:CreateToggle({
    Name     = "Auto Claim Battle Pass Rewards",
    Default  = false,
    Callback = function(v) States.AutoClaimBP = v end,
})

AutomationTab:CreateSection("Task Automation")

AutomationTab:CreateToggle({
    Name     = "Auto Complete Tasks (Dual Loop)",
    Default  = false,
    Callback = function(v) States.AutoTask = v end,
})

AutomationTab:CreateInput({
    Name = "Target Task ID 1",
    PlaceholderText = "2003001",
    RemoveTextAfterFocusLost = false,
    Callback = function(text) 
        local parsed = tonumber(text)
        if parsed then States.TaskID = parsed end
    end,
})

AutomationTab:CreateInput({
    Name = "Target Task ID 2",
    PlaceholderText = "1000001",
    RemoveTextAfterFocusLost = false,
    Callback = function(text) 
        local parsed = tonumber(text)
        if parsed then States.TaskID2 = parsed end
    end,
})

AutomationTab:CreateSection("Pet Automation")

AutomationTab:CreateToggle({
    Name     = "Auto Catch / Main Pet Loop",
    Default  = false,
    Callback = function(v) States.AutoCatch = v end,
})

AutomationTab:CreateInput({
    Name = "Target Pet ID config",
    PlaceholderText = "9115276855",
    RemoveTextAfterFocusLost = false,
    Callback = function(text) 
        local parsed = tonumber(text)
        if parsed then States.CatchPetID = parsed end
    end,
})

AutomationTab:CreateSection("Battle Automation")

AutomationTab:CreateToggle({
    Name     = "Auto Enter Battle (Randomized Cycle)",
    Default  = false,
    Callback = function(v) States.AutoEnterBattle = v end,
})

AutomationTab:CreateToggle({
    Name     = "Auto Abandon Battle (Start of Fight)",
    Default  = false,
    Callback = function(v) States.AutoAbandon = v end,
})

AutomationTab:CreateToggle({
    Name     = "Auto Abandon Battle (End of Fight)",
    Default  = false,
    Callback = function(v) States.AutoAbandonEnd = v end,
})

AutomationTab:CreateSection("Skill Automation")

AutomationTab:CreateToggle({
    Name     = "Auto Spam Skill Key (1)",
    Default  = false,
    Callback = function(v) States.AutoSkills1Enabled = v end,
})

AutomationTab:CreateSlider({
    Name         = "Key 1 Press Delay",
    Range        = {1, 50},
    Increment    = 1,
    Suffix       = " / 10s",
    CurrentValue = 1,
    Callback     = function(v) States.Skill1DelayTime = v / 10 end,
})

AutomationTab:CreateToggle({
    Name     = "Auto Spam Skill Key (2)",
    Default  = false,
    Callback = function(v) States.AutoSkills2Enabled = v end,
})

AutomationTab:CreateSlider({
    Name         = "Key 2 Press Delay",
    Range        = {1, 50},
    Increment    = 1,
    Suffix       = " / 10s",
    CurrentValue = 1,
    Callback     = function(v) States.Skill2DelayTime = v / 10 end,
})

AutomationTab:CreateToggle({
    Name     = "Auto Spam Skill Key (3)",
    Default  = false,
    Callback = function(v) States.AutoSkills3Enabled = v end,
})

AutomationTab:CreateSlider({
    Name         = "Key 3 Press Delay",
    Range        = {1, 50},
    Increment    = 1,
    Suffix       = " / 10s",
    CurrentValue = 1,
    Callback     = function(v) States.Skill3DelayTime = v / 10 end,
})

AutomationTab:CreateToggle({
    Name     = "Auto Spam Skill Key (4)",
    Default  = false,
    Callback = function(v) States.AutoSkills4Enabled = v end,
})

AutomationTab:CreateSlider({
    Name         = "Key 4 Press Delay",
    Range        = {1, 50},
    Increment    = 1,
    Suffix       = " / 10s",
    CurrentValue = 1,
    Callback     = function(v) States.Skill4DelayTime = v / 10 end,
})


-- --- DUNGEON AUTOMATION TAB ---
DungeonTab:CreateSection("Matchmaking & Generation")

DungeonTab:CreateDropdown({
    Name = "Select Dungeon Mode / Tier",
    Options = {"Normal Mode", "Hard Mode", "Nightmare Mode", "Raid Tier 1"},
    CurrentOption = {"Normal Mode"},
    MultipleOptions = false,
    Callback = function(option)
        States.SelectedDungeonTier = option[1]
        if option[1] == "Normal Mode" then States.DungeonDifficultyID = 1
        elseif option[1] == "Hard Mode" then States.DungeonDifficultyID = 2
        elseif option[1] == "Nightmare Mode" then States.DungeonDifficultyID = 3
        else States.DungeonDifficultyID = 4 end
    end,
})

DungeonTab:CreateToggle({
    Name     = "Auto Start / Create Dungeon",
    Default  = false,
    Callback = function(v) States.AutoCreateDungeon = v end,
})

DungeonTab:CreateSection("In-Dungeon Modifiers")

DungeonTab:CreateToggle({
    Name     = "Auto Select Hard Dungeon Buffs",
    Default  = false,
    Callback = function(v) States.AutoSelectDungeonBuff = v end,
})

DungeonTab:CreateSection("Emergency Controls")

DungeonTab:CreateButton({
    Name     = "Force Abort Current Dungeon Instance",
    Callback = function()
        local AbortRemote = game.ReplicatedStorage.Remote.Dungeon:FindFirstChild("ResDungeonAbort")
        if AbortRemote then AbortRemote:FireServer() end
    end,
})


-- --- MAIL REWARDS TAB ---
MailTab:CreateSection("Postal Rewards Infrastructure")

MailTab:CreateToggle({
    Name     = "Auto Claim All Mail Attachments",
    Default  = false,
    Callback = function(v) States.AutoClaimAllMail = v end,
})

MailTab:CreateSlider({
    Name         = "Claim Refresh Rate",
    Range        = {2, 30},
    Increment    = 1,
    Suffix       = " seconds",
    CurrentValue = 5,
    Callback     = function(v) States.MailClaimInterval = v end,
})

MailTab:CreateSection("Manual Overrides")

MailTab:CreateButton({
    Name     = "Instant Bulk Claim Mail",
    Callback = function()
        local ClaimAllRemote = game.ReplicatedStorage.Remote.Mail:FindFirstChild("ReqClaimAllMailReward")
        if ClaimAllRemote then ClaimAllRemote:InvokeServer() end
    end,
})


-- --- MOVEMENT TAB ---
MovementTab:CreateSection("Locomotion Adjustments")

MovementTab:CreateToggle({
    Name     = "Speed Mode",
    Default  = false,
    Callback = function(v) States.SpeedEnabled = v end,
})

MovementTab:CreateSlider({
    Name         = "Walk Speed Scale",
    Range        = {16, 250},
    Increment    = 1,
    Suffix       = " studs/s",
    CurrentValue = 50,
    Callback     = function(v) States.SpeedValue = v end
})

MovementTab:CreateToggle({
    Name     = "Fly Mode",
    Default  = false,
    Callback = function(v)
        local hum = GetHumanoid()
        States.FlyEnabled = v
        if not v and hum then hum.PlatformStand = false end
    end,
})

MovementTab:CreateSlider({
    Name         = "Fly Speed Scale",
    Range        = {10, 250},
    Increment    = 1,
    Suffix       = " studs/s",
    CurrentValue = 50,
    Callback     = function(v) States.FlySpeed = v end
})

MovementTab:CreateToggle({
    Name     = "Noclip",
    Default  = false,
    Callback = function(v) States.NoclipEnabled = v end
})

MovementTab:CreateSection("Pokemon Automated Encounter Loops")

MovementTab:CreateToggle({
    Name     = "Auto Fight Pokemon (W-A-D-S Loop)",
    Default  = false,
    Callback = function(v) States.AutoFightWalk = v end,
})

MovementTab:CreateSlider({
    Name         = "W Walk Duration",
    Range        = {1, 10},
    Increment    = 1,
    Suffix       = " seconds",
    CurrentValue = 2,
    Callback     = function(v) States.W_Duration = v end,
})

MovementTab:CreateSlider({
    Name         = "A Walk Duration",
    Range        = {1, 10},
    Increment    = 1,
    Suffix       = " seconds",
    CurrentValue = 2,
    Callback     = function(v) States.A_Duration = v end,
})

MovementTab:CreateSlider({
    Name         = "D Walk Duration",
    Range        = {1, 10},
    Increment    = 1,
    Suffix       = " seconds",
    CurrentValue = 2,
    Callback     = function(v) States.D_Duration = v end,
})

MovementTab:CreateSlider({
    Name         = "S Walk Duration",
    Range        = {1, 10},
    Increment    = 1,
    Suffix       = " seconds",
    CurrentValue = 2,
    Callback     = function(v) States.S_Duration = v end,
})


-- --- VISUALS TAB ---
VisualsTab:CreateSection("Player Tracking (ESP)")

VisualsTab:CreateToggle({
    Name     = "Enable Player ESP",
    Default  = false,
    Callback = function(v)
        States.PlayerESP = v
        for _, obj in pairs(Player_ESP_Cache) do
            if obj.Highlight then obj.Highlight.Enabled = (v and States.ShowHighlights) end
            if obj.Billboard then obj.Billboard.Enabled = v end
        end
    end,
})

VisualsTab:CreateToggle({
    Name     = "Render Chams (Highlights)",
    Default  = true,
    Callback = function(v) 
        States.ShowHighlights = v 
        for _, obj in pairs(Player_ESP_Cache) do
            if obj.Highlight then obj.Highlight.Enabled = (States.PlayerESP and v) end
        end
    end,
})

VisualsTab:CreateToggle({
    Name     = "Display Usernames",
    Default  = true,
    Callback = function(v) States.ShowUsernames = v end,
})

VisualsTab:CreateToggle({
    Name     = "Display Distance (Studs)",
    Default  = true,
    Callback = function(v) States.ShowDistance = v end,
})


-- --- UNIVERSAL SCANNER TAB ---
ScannerTab:CreateSection("Workspace Search Configuration")

ScannerTab:CreateInput({
    Name = "Search Keyword Match",
    PlaceholderText = "e.g., Chest, Item, Door, Objective",
    RemoveTextAfterFocusLost = false,
    Callback = function(text) States.ScanKeyword = string.lower(text) end,
})

ScannerTab:CreateToggle({
    Name     = "Keyword Object ESP",
    Default  = false,
    Callback = function(v)
        States.ScannerESP = v
        if not v then
            for _, obj in pairs(Scanner_ESP_Cache) do
                pcall(function() obj.Billboard:Destroy() end)
            end
            table.clear(Scanner_ESP_Cache)
        end
    end,
})


-- --- PLAYERS TAB ---
PlayersTab:CreateSection("Target Interaction Architecture")

local playerDropdown = PlayersTab:CreateDropdown({
    Name = "Select Active Player Target",
    Options = GetOtherPlayers(),
    CurrentOption = {GetOtherPlayers()[1]},
    MultipleOptions = false,
    Callback = function(option) States.SelectedPlayer = option[1] end,
})

PlayersTab:CreateButton({
    Name     = "Update Active Player Directory",
    Callback = function() playerDropdown:Refresh(GetOtherPlayers(), true) end,
})

PlayersTab:CreateButton({
    Name     = "Teleport to Selected Target",
    Callback = function()
        local name = States.SelectedPlayer
        if not name or name == "None" then return end

        local match = Players:FindFirstChild(name)
        local root = GetRoot()
        if match and root then
            local targetRoot = GetRoot(match)
            if targetRoot then
                root.CFrame = targetRoot.CFrame * CFrame.new(0, 0, 3)
            end
        end
    end,
})

-- ==========================================
-- [[ METATABLE HOOK / SNIFFER ]] --
-- ==========================================
local RawMeta = getrawmetatable(game)
local OldNamecall = RawMeta.__namecall
setreadonly(RawMeta, false)

RawMeta.__namecall = newcclosure(function(Self, ...)
    local Args = {...}
    local Method = getnamecallmethod()
    
    if Method == "InvokeServer" then
        if Self.Name == "ReqSetMainPet" and States.LogPetClicks then
            if Args[1] and type(Args[1]) == "string" then
                task.spawn(function()
                    PetDataLabel:Set("Captured ID: " .. tostring(Args[1]))
                end)
            end
        end
    end
    
    return OldNamecall(Self, ...)
end)
setreadonly(RawMeta, true)

-- ==========================================
-- [[ BACKGROUND DAEMONS (LOOPS) ]] --
-- ==========================================

-- 1. Heartbeat Physics Frame Sync Loop
RunService.Heartbeat:Connect(function()
    local root = GetRoot()
    local hum = GetHumanoid()
    if not root or not hum then return end

    if States.NoclipEnabled and LP.Character then
        for _, descendant in ipairs(LP.Character:GetChildren()) do
            if descendant:IsA("BasePart") then descendant.CanCollide = false end
        end
    end

    if States.FlyEnabled then
        hum.PlatformStand = true
        local flyDirection = Vector3.new(0, 0, 0)
        
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then flyDirection = flyDirection + Camera.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then flyDirection = flyDirection - Camera.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then flyDirection = flyDirection - Camera.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then flyDirection = flyDirection + Camera.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then flyDirection = flyDirection + Vector3.new(0, 1, 0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then flyDirection = flyDirection - Vector3.new(0, 1, 0) end

        if flyDirection.Magnitude > 0 then
            root.Velocity = flyDirection.Unit * States.FlySpeed
        else
            root.Velocity = Vector3.new(0, 0, 0)
        end
    elseif States.SpeedEnabled then
        local moveVector = hum.MoveDirection
        if moveVector.Magnitude > 0 then
            root.Velocity = Vector3.new(moveVector.X * States.SpeedValue, root.Velocity.Y, moveVector.Z * States.SpeedValue)
        end
    end
end)

-- 2. Consolidated RenderStepped Visual Overlay Loop
RunService.RenderStepped:Connect(function()
    local localRoot = GetRoot()
    if not localRoot then return end

    if States.PlayerESP then
        for targetPlayer, objects in pairs(Player_ESP_Cache) do
            local targetRoot = GetRoot(targetPlayer)
            if targetRoot and objects.Label and objects.Billboard then
                objects.Billboard.Enabled = true
                local totalDistance = math.floor((targetRoot.Position - localRoot.Position).Magnitude)

                local metadata = ""
                if States.ShowUsernames then metadata = targetPlayer.Name end
                if States.ShowDistance then
                    metadata = metadata ~= "" and metadata .. "\n[" .. totalDistance .. " studs]" or "[" .. totalDistance .. " studs]"
                end
                objects.Label.Text = metadata
            else
                if objects.Billboard then objects.Billboard.Enabled = false end
            end
        end
    end

    if States.ScannerESP and States.ScanKeyword ~= "" then
        for _, element in ipairs(Workspace:GetDescendants()) do
            if element:IsA("BasePart") and string.find(string.lower(element.Name), States.ScanKeyword) then
                if not element:IsDescendantOf(LP.Character) and not Players:GetPlayerFromCharacter(element.Parent) then
                    local tracking = Scanner_ESP_Cache[element]
                    if not tracking then
                        tracking = {}
                        local bb = Instance.new("BillboardGui")
                        bb.Size = UDim2.new(0, 150, 0, 40)
                        bb.AlwaysOnTop = true
                        bb.Adornee = element
                        bb.Parent = element
                        
                        local lbl = Instance.new("TextLabel", bb)
                        lbl.Size = UDim2.new(1, 0, 1, 0)
                        lbl.BackgroundTransparency = 1
                        lbl.TextSize = 11
                        lbl.Font = Enum.Font.SourceSansItalic
                        lbl.TextColor3 = Color3.fromRGB(255, 215, 0)
                        lbl.TextStrokeTransparency = 0
                        
                        tracking.Billboard = bb
                        tracking.Label = lbl
                        Scanner_ESP_Cache[element] = tracking
                    end
                    
                    local currentDist = math.floor((element.Position - localRoot.Position).Magnitude)
                    tracking.Label.Text = string.format("%s\n[%d studs]", element.Name, currentDist)
                end
            end
        end
    end
end)

-- 3. Dedicated Standalone 'E' Keypress Loop
task.spawn(function()
    while task.wait(0.05) do
        if States.AutoSpamE and not States.AutoChestFarm then
            SpamEKey()
        end
    end
end)

-- 4. Auto Chest Teleport Loop + "E" Keypress Interceptor Engine
task.spawn(function()
    while task.wait() do
        if States.AutoChestFarm then
            TeleportToNextChest()
            
            local timeElapsed = 0
            while timeElapsed < States.ChestFarmDelay and States.AutoChestFarm do
                SpamEKey()
                task.wait(0.2)
                timeElapsed = timeElapsed + 0.2
            end
        else
            task.wait(0.5)
        end
    end
end)

-- 5. Pokemon Encounter Customizable Directional Walking Sequence Engine
local function SimulateDirectionalKey(keyCode, duration)
    if not States.AutoFightWalk or not VirtualInputManager then return end
    pcall(function()
        VirtualInputManager:SendKeyEvent(true, keyCode, false, game)
        
        local timer = 0
        while timer < duration and States.AutoFightWalk do
            task.wait(0.1)
            timer = timer + 0.1
        end
        
        VirtualInputManager:SendKeyEvent(false, keyCode, false, game)
    end)
end

task.spawn(function()
    while true do
        if States.AutoFightWalk then
            SimulateDirectionalKey(Enum.KeyCode.W, States.W_Duration)
            task.wait(0.1)
            SimulateDirectionalKey(Enum.KeyCode.A, States.A_Duration)
            task.wait(0.1)
            SimulateDirectionalKey(Enum.KeyCode.D, States.D_Duration)
            task.wait(0.1)
            SimulateDirectionalKey(Enum.KeyCode.S, States.S_Duration)
            task.wait(0.1)
        else
            task.wait(0.5)
        end
    end
end)

-- 6. Scanned Dungeon Hub Loop Daemon
task.spawn(function()
    while task.wait(2) do
        if States.AutoCreateDungeon then
            local CreateRemote = game.ReplicatedStorage.Remote.Dungeon:FindFirstChild("ResCreateDungeon")
            if CreateRemote then
                pcall(function() CreateRemote:FireServer(States.DungeonDifficultyID) end)
            end
        end
    end
end)

task.spawn(function()
    while task.wait(1) do
        if States.AutoSelectDungeonBuff then
            local BuffRemote = game.ReplicatedStorage.Remote.Dungeon:FindFirstChild("ResHardDungeonBuffSelect")
            if BuffRemote then
                pcall(function() BuffRemote:FireServer(States.DungeonBuffID) end)
            end
        end
    end
end)

-- 7. Scanned Mail Claims Loop Daemon
task.spawn(function()
    while true do
        if States.AutoClaimAllMail then
            local ClaimAllRemote = game.ReplicatedStorage.Remote.Mail:FindFirstChild("ReqClaimAllMailReward")
            if ClaimAllRemote then
                pcall(function() ClaimAllRemote:InvokeServer() end)
            end
        end
        task.wait(States.MailClaimInterval)
    end
end)

-- 8. Core Reward & Claim Remotes Engine Loops
local RewardRemoteFunction = ReplicatedStorage:FindFirstChild("Remote") and ReplicatedStorage.Remote:FindFirstChild("PetManual") and ReplicatedStorage.Remote.PetManual:FindFirstChild("ReqClaimAllPetManualReward")
task.spawn(function()
    while task.wait(1) do if States.AutoClaimRewards and RewardRemoteFunction then pcall(function() RewardRemoteFunction:InvokeServer() end) end end
end)

local LevelRewardRemoteFunction = ReplicatedStorage:FindFirstChild("Remote") and ReplicatedStorage.Remote:FindFirstChild("PlayerLevelReward") and ReplicatedStorage.Remote.PlayerLevelReward:FindFirstChild("ReqClaimPlayerLevelReward")
task.spawn(function()
    while task.wait(1) do if States.AutoClaimLevel and LevelRewardRemoteFunction then pcall(function() LevelRewardRemoteFunction:InvokeServer() end) end end
end)

local BPRemoteFunction = ReplicatedStorage:FindFirstChild("Remote") and ReplicatedStorage.Remote:FindFirstChild("BattlePass") and ReplicatedStorage.Remote.BattlePass:FindFirstChild("ReqClaimBattlePassReward")
task.spawn(function()
    while task.wait(1) do if States.AutoClaimBP and BPRemoteFunction then pcall(function() BPRemoteFunction:InvokeServer() end) end end
end)

-- 9. Auto Skill Spam Loops (1, 2, 3, 4)
task.spawn(function()
    while task.wait(States.Skill1DelayTime) do
        if States.AutoSkills1Enabled and VirtualInputManager then
            pcall(function()
                VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.One, false, game)
                task.wait(0.05)
                VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.One, false, game)
            end)
        end
    end
end)

task.spawn(function()
    while task.wait(States.Skill2DelayTime) do
        if States.AutoSkills2Enabled and VirtualInputManager then
            pcall(function()
                VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Two, false, game)
                task.wait(0.05)
                VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Two, false, game)
            end)
        end
    end
end)

task.spawn(function()
    while task.wait(States.Skill3DelayTime) do
        if States.AutoSkills3Enabled and VirtualInputManager then
            pcall(function()
                VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Three, false, game)
                task.wait(0.05)
                VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Three, false, game)
            end)
        end
    end
end)

task.spawn(function()
    while task.wait(States.Skill4DelayTime) do
        if States.AutoSkills4Enabled and VirtualInputManager then
            pcall(function()
                VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Four, false, game)
                task.wait(0.05)
                VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Four, false, game)
            end)
        end
    end
end)

-- 10. Auto Abandon Battle Loops (Start of Fight + End of Fight)
task.spawn(function()
    while task.wait(0.5) do
        if States.AutoAbandon then
            FireBattleAbandon(2, 1)
        end
    end
end)

task.spawn(function()
    while task.wait(0.5) do
        if States.AutoAbandonEnd then
            FireBattleAbandon(8)
        end
    end
end)

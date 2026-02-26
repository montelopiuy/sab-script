--[[
    SP HUB - Script combiné
    Intègre : autogen, autograbv3, autojoin 10m, AutoMoteira, Autosteal, AutoScam/Autotp
]]

if getgenv().SP_HUB_Loaded then
    return
end
getgenv().SP_HUB_Loaded = true

-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")
local GuiService = game:GetService("GuiService")
local HttpService = game:GetService("HttpService")
local VirtualUser = game:GetService("VirtualUser")
local CoreGui = game:GetService("CoreGui")
local ProximityPromptService = game:GetService("ProximityPromptService")
local PathfindingService = game:GetService("PathfindingService")
local StarterGui = game:GetService("StarterGui")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local PlaceId = game.PlaceId

-- Variables globales du hub
getgenv().WebhookEnabled = false
getgenv().WebhookURL = ""
getgenv().AutoExecuted = false
getgenv().tpDelay = 0.5
getgenv().repairgenerators = true
getgenv().ForceWin = false
getgenv().FarmSukkars = false
getgenv().msfarm = false
getgenv().AutoGetReady = false
getgenv().NoRender = false
getgenv().FloatingEnabled = false
getgenv().autoStealEnabled = false
getgenv().autoGrabBar = true  -- barre de progression des prompts
getgenv().muteSounds = false
getgenv().brainrotAutoGrab = false
getgenv().autoJoinEnabled = false
getgenv().minMoneyThreshold = 1  -- en millions

-- Anti-AFK (de autogen)
local function startAntiAfk()
    local GC = getconnections or get_signal_cons
    if GC then
        for _, v in pairs(GC(LocalPlayer.Idled)) do
            if v["Disable"] then
                v["Disable"](v)
            elseif v["Disconnect"] then
                v["Disconnect"](v)
            end
        end
    else
        LocalPlayer.Idled:Connect(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new(0,0))
        end)
    end
end
startAntiAfk()

-- Fonctions utilitaires
local function getPing()
    return LocalPlayer:GetNetworkPing()
end

local function pingDelay(baseDelay)
    task.wait(baseDelay + getPing())
end

-- Gestion des erreurs de téléport (de autogen)
local function safeRejoin()
    TeleportService:Teleport(PlaceId, LocalPlayer)
end
GuiService.ErrorMessageChanged:Connect(function(msg)
    if msg ~= "" then
        if not string.find(msg:lower(), "full") and not string.find(msg:lower(), "unavailable") then
            safeRejoin()
        end
    end
end)

-- No Render (FPS boost)
local screenGui = Instance.new("ScreenGui")
screenGui.IgnoreGuiInset = true
screenGui.ResetOnSpawn = false
screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

local blackFrame = Instance.new("Frame")
blackFrame.Size = UDim2.fromScale(1,1)
blackFrame.BackgroundColor3 = Color3.new(0,0,0)
blackFrame.BorderSizePixel = 0
blackFrame.Visible = false
blackFrame.Parent = screenGui

-- Webhook function
local function sendWebhook(title, description, color)
    if not getgenv().WebhookEnabled or getgenv().WebhookURL == "" then return end
    local requestFunc = request or http_request or syn and syn.request
    if not requestFunc then return end
    local embed = {
        embeds = {{
            title = title or "Notification",
            description = description or "",
            color = color or 0x1ABC9C,
            timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
        }}
    }
    local data = HttpService:JSONEncode(embed)
    pcall(function()
        requestFunc({
            Url = getgenv().WebhookURL,
            Method = "POST",
            Headers = {["Content-Type"] = "application/json"},
            Body = data
        })
    end)
end

-- ==================== Rayfield GUI ====================
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
local Window = Rayfield:CreateWindow({
    Name = "SP HUB",
    Icon = 134395825211880,
    LoadingTitle = "Chargement SP HUB",
    LoadingSubtitle = "by zxcv & others",
    ShowText = "SP HUB",
    Theme = "Default",
    ToggleUIKeybind = "K",
    DisableRayfieldPrompts = false,
    ConfigurationSaving = {
        Enabled = true,
        FolderName = "sphub",
        FileName = "config"
    },
    KeySystem = true,
    KeySettings = {
        Title = "SP HUB - Key System",
        Subtitle = "Clé requise",
        Note = "Rejoins le discord pour obtenir une clé",
        FileName = "sphub_key",
        SaveKey = true,
        GrabKeyFromSite = false,
        Key = {"SPHUB2025", "MEGAKEY", "SECRET"}
    }
})

-- ==================== Onglet MAIN (autogen) ====================
local MainTab = Window:CreateTab("Main")
local InfoSection = MainTab:CreateSection("Info")

local pointsLabel = MainTab:CreateLabel("Points : 0")
local timeLabel = MainTab:CreateLabel("Playtime : 00:00:00")
local equippedLabel = MainTab:CreateLabel("Equipped : None")

-- Mise à jour des infos
local startClock = os.clock()
task.spawn(function()
    while true do
        local stats = LocalPlayer:FindFirstChild("PlayerData") and LocalPlayer.PlayerData:FindFirstChild("Stats")
        if stats and stats:FindFirstChild("Currency") and stats.Currency:FindFirstChild("Money") then
            pcall(function() pointsLabel:Set("Points : " .. tostring(stats.Currency.Money.Value)) end)
        end
        local t = os.clock() - startClock
        timeLabel:Set(string.format("Playtime : %02d:%02d:%02d", math.floor(t/3600), math.floor((t%3600)/60), math.floor(t%60)))
        -- Equipped
        local pdata = LocalPlayer:FindFirstChild("PlayerData")
        if pdata and pdata:FindFirstChild("Equipped") then
            local survivor = pdata.Equipped:FindFirstChild("Survivor")
            if survivor and survivor.Value ~= "" then
                local name = survivor.Value
                local val = 0
                local purchased = pdata:FindFirstChild("Purchased")
                if purchased and purchased:FindFirstChild("Survivors") then
                    local folder = purchased.Survivors
                    if folder:FindFirstChild(name) then
                        val = folder[name].Value
                    end
                end
                equippedLabel:Set(("Equipped : %s (%d)"):format(name, val))
            else
                equippedLabel:Set("Equipped : None")
            end
        end
        task.wait(0.5)
    end
end)

-- Fonctions pour le farming (de autogen)
local function getRoot(char) return char and char:FindFirstChild("HumanoidRootPart") end

-- MS-Farm
local currentMode = "Normal"
local msFarmConn
local function getHighestSurvivor(survivors)
    local highestName = nil
    local highestValue = -math.huge
    for _, child in ipairs(survivors:GetChildren()) do
        if child:IsA("IntValue") and child.Value < 59390 and child.Value > highestValue then
            highestValue = child.Value
            highestName = child.Name
        end
    end
    return highestName
end
local function startMSFarm()
    local survivors = LocalPlayer:WaitForChild("PlayerData"):WaitForChild("Purchased"):WaitForChild("Survivors")
    local RemoteEvent = ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Network"):WaitForChild("RemoteEvent")
    if msFarmConn then msFarmConn:Disconnect() end
    msFarmConn = RunService.RenderStepped:Connect(function()
        if currentMode ~= "MS-Farm" then return end
        local highestName = getHighestSurvivor(survivors)
        if highestName then
            local equip = {"EquipState", {ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Survivors"):WaitForChild(highestName), buffer.fromstring("true")}}
            RemoteEvent:FireServer(unpack(equip))
        end
    end)
end
startMSFarm()

-- Sukkars farm
local folder = nil
local getsukkars = false
local savedPos = nil
local returning = false
local index = 1
local function updateFolder()
    local map = workspace:FindFirstChild("Map")
    if not map then return end
    local ingame = map:FindFirstChild("Ingame")
    if not ingame then return end
    folder = ingame:FindFirstChild("CurrencyLocations")
end
updateFolder()
workspace.DescendantAdded:Connect(function(obj) if obj.Name == "CurrencyLocations" then folder = obj end end)
workspace.DescendantRemoving:Connect(function(obj) if obj == folder then folder = nil end end)

local function tpToNext()
    if returning or not folder or not getRoot(LocalPlayer.Character) then return end
    local children = folder:GetChildren()
    if #children == 0 then return end
    if index > #children then index = 1 end
    local A = children[index]
    if not A then index = index + 1 return end
    local inner = A:GetChildren()
    local hasCollect = false
    for _, obj in ipairs(inner) do
        if obj:FindFirstChild("Collect") then hasCollect = true break end
    end
    if hasCollect then index = index + 1 getsukkars = false return end
    for _, obj in ipairs(inner) do
        if obj:IsA("BasePart") then
            savedPos = getRoot(LocalPlayer.Character).CFrame
            getRoot(LocalPlayer.Character).CFrame = obj.CFrame + Vector3.new(0,1,0)
            getsukkars = true
            returning = true
            break
        end
    end
end

-- Repair generators
local lastTp = 0
local genIndex = 1
local lastGenerators = {}
local function getGenerators()
    local map = workspace:FindFirstChild("Map")
    map = map and map:FindFirstChild("Ingame")
    map = map and map:FindFirstChild("Map")
    if not map then return {} end
    local gens = {}
    for _, gen in pairs(map:GetChildren()) do
        if gen.Name == "Generator" and gen:FindFirstChild("Progress") and gen.Progress.Value < 100 then
            table.insert(gens, gen)
        end
    end
    return gens
end
local function isOccupied(pos)
    for _, survivor in pairs(workspace.Players.Survivors:GetChildren()) do
        local root = survivor:FindFirstChild("HumanoidRootPart")
        if root and survivor ~= LocalPlayer.Character and (root.Position - pos).Magnitude <= 6 then
            return true
        end
    end
    return false
end
local function sameGenerators(a,b)
    if #a ~= #b then return false end
    for i=1,#a do if a[i] ~= b[i] then return false end end
    return true
end
local function repairGenerators()
    local char = LocalPlayer.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") or char.Parent.Name ~= "Survivors" then return end
    local hrp = char.HumanoidRootPart
    local gens = getGenerators()
    if #gens == 0 then return end
    if not sameGenerators(gens, lastGenerators) then genIndex = 1 lastGenerators = gens end
    local gen = gens[genIndex]
    if not gen then genIndex = 1 return end
    if tick() - lastTp < (getgenv().tpDelay + getPing()) then return end
    lastTp = tick()
    if gen:FindFirstChild("Positions") then
        for _, pos in ipairs({gen.Positions.Center, gen.Positions.Right, gen.Positions.Left}) do
            if pos and not isOccupied(pos.Position) then
                hrp.CFrame = pos.CFrame
                break
            end
        end
    end
    task.wait(0.2)
    pcall(function()
        if gen.Remotes and gen.Remotes:FindFirstChild("RF") then gen.Remotes.RF:InvokeServer("enter") end
        if gen.Remotes and gen.Remotes:FindFirstChild("RE") then gen.Remotes.RE:FireServer() end
    end)
    genIndex = genIndex + 1
    if genIndex > #gens then genIndex = 1 end
end

-- Check objectives for ForceWin
local seenProgress, doneAll = {}, false
local flagflyaway = false
local function resetProgress() seenProgress = {} doneAll = false end
local function checkObjectives()
    local objectives = LocalPlayer.PlayerGui:FindFirstChild("MainUI") and LocalPlayer.PlayerGui.MainUI:FindFirstChild("Objectives")
    if not objectives then return end
    for _, obj in ipairs(objectives:GetChildren()) do
        if obj.Name:match("^SetupGenerators_") then
            local desc = obj:FindFirstChild("Description")
            if desc and desc:IsA("TextLabel") then
                local progress = desc.Text:match("%((%d+/%d+)%)")
                if progress then
                    if progress == "0/5" then resetProgress()
                    elseif not seenProgress[progress] then
                        seenProgress[progress] = true
                        if progress == "5/5" then
                            doneAll = true
                            if getgenv().ForceWin and not flagflyaway then
                                local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                                if hrp then
                                    hrp.CFrame = hrp.CFrame + Vector3.new(0,10000,0)
                                    getgenv().FloatingEnabled = true
                                    flagflyaway = true
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end

-- Ghosting (activeghosting)
local function activeghosting(char)
    getgenv().FloatingEnabled = true
    local queryHitbox
    repeat queryHitbox = char:FindFirstChild("QueryHitbox") wait() until queryHitbox
    local firstInvisible = true
    local hasLifted = false
    local hrp = char:WaitForChild("HumanoidRootPart")
    while (queryHitbox.Position.Y - hrp.Position.Y) < 5000 do
        local oldpos = hrp.CFrame
        if not hasLifted then
            hrp.CFrame = hrp.CFrame + Vector3.new(0,10000,0)
            wait(getPing()*0.5)
            if firstInvisible then
                getgenv().activateRemoteHook("UnreliableRemoteEvent","UpdCF")
                firstInvisible = false
            else
                wait(getPing()*0.5)
                getgenv().deactivateRemoteHook("UnreliableRemoteEvent","UpdCF")
                wait(getPing()*0.5)
                getgenv().activateRemoteHook("UnreliableRemoteEvent","UpdCF")
            end
            wait(getPing()*0.5)
            hrp.CFrame = oldpos
            hasLifted = true
        end
        if (queryHitbox.Position.Y - hrp.Position.Y) < 5000 then hasLifted = false end
        wait(getPing()*0.01)
    end
    getgenv().FloatingEnabled = false
end

-- Remote hooks (de autogen)
getgenv().HookRules = getgenv().HookRules or {}
if not getgenv().originalNamecall then
    getgenv().originalNamecall = hookmetamethod(game, "__namecall", function(self, ...)
        local method = getnamecallmethod()
        local args = {...}
        if method == "FireServer" then
            for _, rule in ipairs(getgenv().HookRules) do
                if (not rule.remoteName or self.Name == rule.remoteName) and (not rule.blockedFirstArg or args[1] == rule.blockedFirstArg) and rule.block then
                    return
                end
            end
        end
        return getgenv().originalNamecall(self, ...)
    end)
end
getgenv().activateRemoteHook = function(remoteName, blockedFirstArg)
    for _, rule in ipairs(getgenv().HookRules) do
        if rule.remoteName == remoteName and rule.blockedFirstArg == blockedFirstArg then return end
    end
    table.insert(getgenv().HookRules, {remoteName = remoteName, blockedFirstArg = blockedFirstArg, block = true})
end
getgenv().deactivateRemoteHook = function(remoteName, blockedFirstArg)
    for i, rule in ipairs(getgenv().HookRules) do
        if rule.remoteName == remoteName and rule.blockedFirstArg == blockedFirstArg then
            table.remove(getgenv().HookRules, i)
            break
        end
    end
end

-- Character detection
local function checkChar(char)
    if char and char.Parent and char.Parent.Name == "Survivors" then
        getgenv().FloatingEnabled = false
        activeghosting(char)
        resetProgress()
        -- delayKillerIntroUI (simplifié)
        getgenv().AutoGetReady = true
    else
        getgenv().deactivateRemoteHook("UnreliableRemoteEvent", "UpdCF")
        getgenv().AutoGetReady = false
    end
end
LocalPlayer.CharacterAdded:Connect(checkChar)
if LocalPlayer.Character then checkChar(LocalPlayer.Character) end

-- Stop animations
local function stopAnimations(char)
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if humanoid then
        local animator = humanoid:FindFirstChildOfClass("Animator")
        if animator then
            for _, track in ipairs(animator:GetPlayingAnimationTracks()) do track:Stop() end
        end
    end
end
RunService.Heartbeat:Connect(function()
    if LocalPlayer.Character then stopAnimations(LocalPlayer.Character) end
end)

-- Auto teleport to empty servers (de autogen)
local teleportDebounce = false
getgenv().isTeleporting = false
getgenv().cancelTeleportRetry = false
getgenv().recentServers = getgenv().recentServers or {}
local function addRecentServer(id) table.insert(getgenv().recentServers,1,id) if #getgenv().recentServers>5 then table.remove(getgenv().recentServers) end end
local function isRecentlyUsed(id) for _,v in ipairs(getgenv().recentServers) do if v==id then return true end end return false end
local function safeHttpGet(url)
    for retries=0,5 do
        local ok, result = pcall(function() return game:HttpGet(url) end)
        if ok and result and #result>0 then return result end
        task.wait(5+retries*1.5)
    end
    return nil
end
local function safeJSONDecode(str) local ok,dec = pcall(function() return HttpService:JSONDecode(str) end) return ok and dec or {data={}} end
local function listServers(cursor)
    local url = "https://games.roblox.com/v1/games/"..PlaceId.."/servers/Public?sortOrder=Asc&limit=100"
    if cursor then url = url .. "&cursor=" .. HttpService:UrlEncode(cursor) end
    return safeJSONDecode(safeHttpGet(url) or "{}")
end
local function teleportToEmptyServer()
    if teleportDebounce or getgenv().cancelTeleportRetry then return end
    teleportDebounce = true
    task.spawn(function()
        local cursor = nil
        local success = false
        for page=1,100 do
            local servers = listServers(cursor)
            if servers and servers.data then
                for _, s in ipairs(servers.data) do
                    if s.playing <= 2 and s.maxPlayers > 0 and s.id ~= game.JobId and not s.reserved and not isRecentlyUsed(s.id) then
                        local ok = pcall(function() TeleportService:TeleportToPlaceInstance(PlaceId, s.id, LocalPlayer) end)
                        if ok then addRecentServer(s.id) getgenv().isTeleporting = true success = true break end
                    end
                end
                if success then break end
            end
            if not servers.nextPageCursor then break end
            cursor = servers.nextPageCursor
            task.wait(0.5)
        end
        teleportDebounce = false
        if not success then getgenv().isTeleporting = false end
    end)
end

-- Auto execute on teleport
local queueteleport = queue_on_teleport or (syn and syn.queue_on_teleport) or (getgenv().fluxus and getgenv().fluxus.queue_on_teleport)
local hubLoader = [[loadstring(game:HttpGet("https://pastefy.app/S4wGCukr/raw"))()]]  -- À remplacer par l'URL du script combiné
local TeleportCheck = false
LocalPlayer.OnTeleport:Connect(function(state)
    if getgenv().AutoExecuted and not TeleportCheck and queueteleport then
        TeleportCheck = true
        queueteleport(hubLoader)
    end
end)

-- Boucle principale farming
RunService.Heartbeat:Connect(function()
    if not getgenv().AutoGetReady then return end
    local map = workspace:FindFirstChild("Map")
    local ingame = map and map:FindFirstChild("Ingame")
    local f = ingame and ingame:FindFirstChild("CurrencyLocations")
    if getgenv().FarmSukkars then
        if (not f) and (not getgenv().repairgenerators) then teleportToEmptyServer() return end
    end
    if not getsukkars then
        if getgenv().ForceWin and getgenv().repairgenerators then
            if not doneAll then repairGenerators() checkObjectives() end
            return
        end
        if getgenv().repairgenerators and not getgenv().ForceWin then
            if doneAll then
                if not f then teleportToEmptyServer() end
            else
                repairGenerators() checkObjectives()
            end
            return
        end
        if getgenv().ForceWin and not getgenv().repairgenerators then return end
    end
end)

-- Sukkars movement
RunService.Heartbeat:Connect(function()
    if not getgenv().AutoGetReady or not getgenv().FarmSukkars then
        returning = false; getsukkars = false; savedPos = nil
        return
    end
    if returning then
        getsukkars = true
        if savedPos and getRoot(LocalPlayer.Character) then
            getRoot(LocalPlayer.Character).CFrame = savedPos
        end
        returning = false; getsukkars = false
        return
    end
    tpToNext()
end)

-- Toggles MainTab
MainTab:CreateToggle({
    Name = "MS-Farm Mode",
    Flag = "MSFarmMode",
    CurrentValue = getgenv().msfarm,
    Callback = function(v)
        getgenv().msfarm = v
        currentMode = v and "MS-Farm" or "Normal"
    end
})

MainTab:CreateToggle({
    Name = "Auto Repair Generators",
    Flag = "AutoRepairGenerators",
    CurrentValue = getgenv().repairgenerators,
    Callback = function(v) getgenv().repairgenerators = v end
})

MainTab:CreateToggle({
    Name = "Auto Win",
    Flag = "AutoWin",
    CurrentValue = getgenv().ForceWin,
    Callback = function(v) getgenv().ForceWin = v end
})

MainTab:CreateToggle({
    Name = "Auto Farm Sukkars",
    Flag = "AutoFarmSukkars",
    CurrentValue = getgenv().FarmSukkars,
    Callback = function(v) getgenv().FarmSukkars = v end
})

-- ==================== Onglet AUTO STEAL ====================
local StealTab = Window:CreateTab("Auto Steal")

-- Auto Steal (de Autosteal)
local autoStealRunning = false
local stealLoopConn
local function startAutoSteal()
    if autoStealRunning then return end
    autoStealRunning = true
    local TARGET_HOLD_DURATION = 1.5
    local TARGET_MAX_DISTANCE = 10
    local CHECK_INTERVAL = 0.25
    local HOLD_TIME = 0.6

    local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    local RootPart = Character:WaitForChild("HumanoidRootPart")
    local myPlot = Character:FindFirstAncestorOfClass("Model")

    LocalPlayer.CharacterAdded:Connect(function(c)
        task.wait(0.12)
        Character = c
        RootPart = c:WaitForChild("HumanoidRootPart")
        myPlot = c:FindFirstAncestorOfClass("Model")
    end)

    local function getBasePart(p)
        local par = p.Parent
        if par:IsA("BasePart") then return par end
        if par:IsA("Attachment") and par.Parent:IsA("BasePart") then return par.Parent end
        if par:IsA("Model") and par.PrimaryPart then return par.PrimaryPart end
        return nil
    end

    local function isCandidate(prompt)
        if not prompt.Enabled or prompt.ActionText ~= "Steal" then return false end
        if math.abs((prompt.HoldDuration or 0) - TARGET_HOLD_DURATION) > 0.1 or math.abs((prompt.MaxActivationDistance or 0) - TARGET_MAX_DISTANCE) > 1 then return false end
        local part = getBasePart(prompt)
        if not part or not RootPart then return false end
        local plotsContainer = Workspace:FindFirstChild("Plots")
        if plotsContainer then
            local plot = part:FindFirstAncestorWhichIsA("Model")
            if plot and plot.Parent == plotsContainer and plot == myPlot then return false end
        end
        local dist = (part.Position - RootPart.Position).Magnitude
        return dist <= TARGET_MAX_DISTANCE + 0.5, part, dist
    end

    local function findClosest()
        local best, bestDist = nil, math.huge
        for _, v in ipairs(Workspace:GetDescendants()) do
            if v:IsA("ProximityPrompt") then
                local ok, part, dist = isCandidate(v)
                if ok and dist < bestDist then
                    best = v
                    bestDist = dist
                end
            end
        end
        return best
    end

    local function tryActivate(prompt)
        if not prompt then return end
        pcall(function()
            if typeof(prompt.InputHoldBegin) == "function" then
                prompt:InputHoldBegin()
                task.wait(HOLD_TIME)
                prompt:InputHoldEnd()
            end
        end)
        task.wait(0.1)
        pcall(function()
            fireproximityprompt(prompt, 1)
            task.wait(HOLD_TIME)
            fireproximityprompt(prompt, 0)
        end)
    end

    stealLoopConn = RunService.Heartbeat:Connect(function()
        if not getgenv().autoStealEnabled then return end
        local prompt = findClosest()
        if prompt then tryActivate(prompt) end
    end)
end

local function stopAutoSteal()
    autoStealRunning = false
    if stealLoopConn then stealLoopConn:Disconnect() stealLoopConn = nil end
end

StealTab:CreateToggle({
    Name = "Activer Auto Steal",
    Flag = "AutoStealToggle",
    CurrentValue = false,
    Callback = function(v)
        getgenv().autoStealEnabled = v
        if v then startAutoSteal() else stopAutoSteal() end
    end
})

-- Desync (FFlags + respawn)
StealTab:CreateButton({
    Name = "Activer Desync (FFlags + Respawn)",
    Callback = function()
        local fflags = {
            GameNetPVHeaderRotationalVelocityZeroCutoffExponent = -5000,
            LargeReplicatorWrite5 = true,
            LargeReplicatorEnabled9 = true,
            AngularVelociryLimit = 360,
            TimestepArbiterVelocityCriteriaThresholdTwoDt = 2147483646,
            S2PhysicsSenderRate = 15000,
            DisableDPIScale = true,
            MaxDataPacketPerSend = 2147483647,
            PhysicsSenderMaxBandwidthBps = 20000,
            TimestepArbiterHumanoidLinearVelThreshold = 21,
            MaxMissedWorldStepsRemembered = -2147483648,
            PlayerHumanoidPropertyUpdateRestrict = true,
            SimDefaultHumanoidTimestepMultiplier = 0,
            StreamJobNOUVolumeLengthCap = 2147483647,
            DebugSendDistInSteps = -2147483648,
            GameNetDontSendRedundantNumTimes = 1,
            CheckPVLinearVelocityIntegrateVsDeltaPositionThresholdPercent = 1,
            CheckPVDifferencesForInterpolationMinVelThresholdStudsPerSecHundredth = 1,
            LargeReplicatorSerializeRead3 = true,
            ReplicationFocusNouExtentsSizeCutoffForPauseStuds = 2147483647,
            CheckPVCachedVelThresholdPercent = 10,
            CheckPVDifferencesForInterpolationMinRotVelThresholdRadsPerSecHundredth = 1,
            GameNetDontSendRedundantDeltaPositionMillionth = 1,
            InterpolationFrameVelocityThresholdMillionth = 5,
            StreamJobNOUVolumeCap = 2147483647,
            InterpolationFrameRotVelocityThresholdMillionth = 5,
            CheckPVCachedRotVelThresholdPercent = 10,
            WorldStepMax = 30,
            InterpolationFramePositionThresholdMillionth = 5,
            TimestepArbiterHumanoidTurningVelThreshold = 1,
            SimOwnedNOUCountThresholdMillionth = 2147483647,
            GameNetPVHeaderLinearVelocityZeroCutoffExponent = -5000,
            NextGenReplicatorEnabledWrite4 = true,
            TimestepArbiterOmegaThou = 1073741823,
            MaxAcceptableUpdateDelay = 1,
            LargeReplicatorSerializeWrite4 = true
        }
        for name, value in pairs(fflags) do
            pcall(function() setfflag(tostring(name), tostring(value)) end)
        end
        -- Respawn
        local char = LocalPlayer.Character
        if char then
            local hum = char:FindFirstChildWhichIsA('Humanoid')
            if hum then hum:ChangeState(Enum.HumanoidStateType.Dead) end
            char:ClearAllChildren()
        end
    end
})

-- Barre de progression des prompts (autograbv3)
do
    local gui = Instance.new("ScreenGui")
    gui.Name = "PromptProgressGui"
    gui.ResetOnSpawn = false
    gui.Parent = LocalPlayer:WaitForChild("PlayerGui")

    local frame = Instance.new("Frame")
    frame.Size = UDim2.fromScale(0.3, 0.035)
    frame.Position = UDim2.fromScale(0.35, 0.9)
    frame.BackgroundColor3 = Color3.fromRGB(25,25,25)
    frame.BorderSizePixel = 0
    frame.Visible = false
    frame.Parent = gui

    local frameCorner = Instance.new("UICorner"); frameCorner.CornerRadius = UDim.new(0,12); frameCorner.Parent = frame
    local bar = Instance.new("Frame"); bar.Size = UDim2.fromScale(0,1); bar.BackgroundColor3 = Color3.fromRGB(255,0,0); bar.BorderSizePixel = 0; bar.Parent = frame
    local barCorner = Instance.new("UICorner"); barCorner.CornerRadius = UDim.new(0,12); barCorner.Parent = bar
    local text = Instance.new("TextLabel"); text.Size = UDim2.fromScale(1,1); text.BackgroundTransparency = 1; text.Text = "0%"; text.TextColor3 = Color3.new(1,1,1); text.TextScaled = true; text.Font = Enum.Font.GothamBold; text.Parent = frame

    local activePrompt = nil
    local startTime = 0
    local holdDuration = 1.5
    local renderConn = nil

    local function colorFromProgress(p)
        if p < 0.5 then return Color3.fromRGB(255, math.floor(p*2*255), 0)
        else return Color3.fromRGB(math.floor((1-p)*2*255), 255, 0) end
    end
    local function stopBar()
        if renderConn then renderConn:Disconnect() renderConn = nil end
        frame.Visible = false
        bar.Size = UDim2.fromScale(0,1)
        text.Text = "0%"
        activePrompt = nil
    end

    ProximityPromptService.PromptButtonHoldBegan:Connect(function(prompt)
        if not getgenv().autoGrabBar then return end
        activePrompt = prompt
        startTime = os.clock()
        holdDuration = prompt.HoldDuration
        frame.Visible = true
        bar.Size = UDim2.fromScale(0,1)
        text.Text = "0%"
        renderConn = RunService.RenderStepped:Connect(function()
            if not activePrompt then return end
            local progress = math.clamp((os.clock() - startTime) / holdDuration, 0, 0.99)
            bar.Size = UDim2.fromScale(progress, 1)
            bar.BackgroundColor3 = colorFromProgress(progress)
            text.Text = math.floor(progress*100) .. "%"
        end)
    end)
    ProximityPromptService.PromptButtonHoldEnded:Connect(stopBar)
    ProximityPromptService.PromptTriggered:Connect(function()
        bar.Size = UDim2.fromScale(1,1)
        bar.BackgroundColor3 = Color3.fromRGB(0,255,0)
        text.Text = "100%"
        task.wait(0.05)
        stopBar()
    end)
    ProximityPromptService.PromptHidden:Connect(stopBar)
end

StealTab:CreateToggle({
    Name = "Afficher barre de progression des prompts",
    Flag = "AutoGrabBar",
    CurrentValue = true,
    Callback = function(v) getgenv().autoGrabBar = v end
})

-- ==================== Onglet BRAINROT (AutoScam) ====================
local BrainrotTab = Window:CreateTab("Brainrot")

-- Fonctions de scan des brainrots
local function extractValue(text)
    if not text then return 0 end
    local clean = text:gsub("[%$,/s]",""):gsub(",","")
    local mult = 1
    if clean:match("[kK]") then mult = 1e3 clean = clean:gsub("[kK]","")
    elseif clean:match("[mM]") then mult = 1e6 clean = clean:gsub("[mM]","")
    elseif clean:match("[bB]") then mult = 1e9 clean = clean:gsub("[bB]","")
    elseif clean:match("[tT]") then mult = 1e12 clean = clean:gsub("[tT]","")
    elseif clean:match("[qQ]") then mult = 1e15 clean = clean:gsub("[qQ]","") end
    local num = tonumber(clean)
    return num and num*mult or 0
end
local function formatValue(value)
    if value >= 1e15 then return string.format("%.1fQ", value/1e15)
    elseif value >= 1e12 then return string.format("%.1fT", value/1e12)
    elseif value >= 1e9 then return string.format("%.1fB", value/1e9)
    elseif value >= 1e6 then return string.format("%.1fM", value/1e6)
    elseif value >= 1e3 then return string.format("%.1fK", value/1e3)
    else return tostring(math.floor(value)) end
end
local function findAllBrainrots()
    local allPets = {}
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj.Name == "AnimalOverhead" then
            local petValue, petName, generation = 0, "Brainrot", "Gen 1"
            for _, child in ipairs(obj:GetChildren()) do
                if child:IsA("TextLabel") then
                    local text = child.Text
                    if text then
                        if child.Name == "DisplayName" and text ~= "" then petName = text
                        elseif text:find("$") and text:find("/s") then petValue = extractValue(text)
                        elseif child.Name == "Generation" then generation = text end
                    end
                end
            end
            local position = nil
            local current = obj.Parent
            while current and current ~= workspace do
                if current:IsA("BasePart") then position = current.Position break end
                current = current.Parent
            end
            if position and petValue > 0 then
                table.insert(allPets, {position=position, name=petName, value=petValue, formatted=formatValue(petValue), generation=generation})
            end
        end
    end
    table.sort(allPets, function(a,b) return a.value > b.value end)
    return allPets
end

-- Téléportation vers brainrot
local isTeleporting = false
local function block(plr) if plr and plr~=LocalPlayer then pcall(function() StarterGui:SetCore("PromptBlockPlayer", plr) end) end end
local function teleportToPosition(target)
    local char = LocalPlayer.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local path = PathfindingService:CreatePath({AgentRadius=2, AgentHeight=5, AgentCanJump=true})
    local elevated = Vector3.new(target.X, target.Y+5, target.Z)
    path:ComputeAsync(hrp.Position, elevated)
    if path.Status == Enum.PathStatus.Success then
        local waypoints = path:GetWaypoints()
        isTeleporting = true
        for _, wp in ipairs(waypoints) do
            if not isTeleporting then break end
            hrp.CFrame = CFrame.new(wp.Position.X, wp.Position.Y+5, wp.Position.Z)
            task.wait(0.02)
        end
        isTeleporting = false
    else
        hrp.CFrame = CFrame.new(elevated)
    end
    -- Bloque le joueur le plus proche
    local nearest, nearestDist = nil, math.huge
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character then
            local targetHRP = p.Character:FindFirstChild("HumanoidRootPart")
            if targetHRP then
                local dist = (hrp.Position - targetHRP.Position).Magnitude
                if dist < nearestDist then nearestDist = dist nearest = p end
            end
        end
    end
    if nearest then block(nearest) end
end

-- Affichage de la liste (on utilise un ScrollingFrame manuel car Rayfield ne gère pas les listes dynamiques)
local brainrotListFrame = Instance.new("ScrollingFrame")
brainrotListFrame.Size = UDim2.new(1, -20, 0, 300)
brainrotListFrame.Position = UDim2.new(0, 10, 0, 50)
brainrotListFrame.BackgroundTransparency = 1
brainrotListFrame.BorderSizePixel = 0
brainrotListFrame.ScrollBarThickness = 8
brainrotListFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
brainrotListFrame.Parent = LocalPlayer.PlayerGui  -- À attacher au hub plus tard

-- On va plutôt créer un onglet personnalisé dans Rayfield en ajoutant un Frame
-- Mais Rayfield ne permet pas d'ajouter des éléments arbitraires facilement.
-- Solution : on crée un Frame directement dans le hub, et on l'affiche dans l'onglet Brainrot.
-- Nous devons accéder au conteneur de l'onglet. Rayfield utilise des frames internes.
-- Nous allons plutôt utiliser une méthode simple : un bouton "Rafraîchir" qui imprime la liste dans la console et propose un téléport via un input.
-- Pour une expérience plus riche, on pourrait créer un petit UI séparé mais intégré.

-- Alternative : on crée un onglet avec un bouton pour lister dans la console et un autre pour téléporter au meilleur.
BrainrotTab:CreateButton({
    Name = "Afficher les brainrots dans la console",
    Callback = function()
        local pets = findAllBrainrots()
        print("=== Brainrots trouvés ===")
        for i, pet in ipairs(pets) do
            print(string.format("%d. %s - %s/s (%s)", i, pet.name, pet.formatted, pet.generation))
        end
    end
})

BrainrotTab:CreateButton({
    Name = "Téléporter au meilleur brainrot",
    Callback = function()
        local pets = findAllBrainrots()
        if #pets > 0 then
            teleportToPosition(pets[1].position)
        else
            print("Aucun brainrot trouvé")
        end
    end
})

BrainrotTab:CreateToggle({
    Name = "Auto Grab (insta pickup)",
    Flag = "BrainrotAutoGrab",
    CurrentValue = false,
    Callback = function(v) getgenv().brainrotAutoGrab = v end
})

-- InstaPickup system (de AutoScam)
local InstaPickupSystem = {}
InstaPickupSystem.currentPrompt = nil
InstaPickupSystem.currentDistance = math.huge
InstaPickupSystem.lastUpdate = 0
function InstaPickupSystem:parseMoneyPerSec(text)
    if not text then return 0 end
    local mult = 1
    local numStr = text:match("[%d%.]+")
    if not numStr then return 0 end
    if text:find("K") then mult=1e3 elseif text:find("M") then mult=1e6 elseif text:find("B") then mult=1e9 elseif text:find("T") then mult=1e12 elseif text:find("Q") then mult=1e15 end
    return tonumber(numStr) and tonumber(numStr)*mult or 0
end
function InstaPickupSystem:getBrainrotValue(prompt)
    local parent = prompt.Parent
    if not parent or not parent.Parent then return 0 end
    local model = parent.Parent
    for _, desc in ipairs(model:GetDescendants()) do
        if desc:IsA("TextLabel") and desc.Name == "Rarity" then
            local gen = desc.Parent:FindFirstChild("Generation")
            if gen and gen:IsA("TextLabel") then return self:parseMoneyPerSec(gen.Text) end
        end
    end
    return 0
end
function InstaPickupSystem:getPromptPosition(prompt)
    local parent = prompt.Parent
    if parent:IsA("BasePart") then return parent.Position end
    if parent:IsA("Model") then
        local primary = parent.PrimaryPart or parent:FindFirstChildWhichIsA("BasePart")
        if primary then return primary.Position end
    end
    if parent:IsA("Attachment") then return parent.WorldPosition end
    return nil
end
function InstaPickupSystem:findHighestValuePrompt()
    local bestPrompt, bestValue, bestDist = nil, 0, math.huge
    local plots = workspace:FindFirstChild("Plots")
    if not plots then return nil, math.huge end
    for _, obj in pairs(plots:GetDescendants()) do
        if obj:IsA("ProximityPrompt") and obj.Enabled and obj.ActionText == "Steal" then
            local pos = self:getPromptPosition(obj)
            if pos then
                local dist = (self.hrp.Position - pos).Magnitude
                if dist <= obj.MaxActivationDistance then
                    local val = self:getBrainrotValue(obj)
                    if val > bestValue then bestValue = val bestPrompt = obj bestDist = dist end
                end
            end
        end
    end
    return bestPrompt, bestDist
end
function InstaPickupSystem:activatePrompt(prompt)
    prompt.RequiresLineOfSight = false
    fireproximityprompt(prompt, 20, math.huge)
    prompt:InputHoldBegin()
    prompt:InputHoldEnd()
end
function InstaPickupSystem:start()
    local function getHRP()
        return LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") or LocalPlayer.CharacterAdded:Wait():WaitForChild("HumanoidRootPart")
    end
    self.hrp = getHRP()
    LocalPlayer.CharacterAdded:Connect(function() self.hrp = getHRP() end)
    RunService.Heartbeat:Connect(function()
        local now = tick()
        if now - self.lastUpdate >= 0.05 then
            self.currentPrompt, self.currentDistance = self:findHighestValuePrompt()
            self.lastUpdate = now
        end
    end)
    task.spawn(function()
        while true do
            if getgenv().brainrotAutoGrab and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") and LocalPlayer.Character.Humanoid.WalkSpeed > 25 then
                if self.currentPrompt and self.currentDistance <= self.currentPrompt.MaxActivationDistance then
                    self:activatePrompt(self.currentPrompt)
                    task.wait(1.5)
                else task.wait(0.1) end
            else task.wait(0.5) end
        end
    end)
end
InstaPickupSystem:start()

-- ==================== Onglet SERVER ====================
local ServerTab = Window:CreateTab("Server")

-- Auto Moteira (envoi webhook + scan brainrots)
ServerTab:CreateButton({
    Name = "Scanner et envoyer au webhook (Auto Moteira)",
    Callback = function()
        local brainrots = findAllBrainrots()
        local playerCount = #Players:GetPlayers()
        local playerName = LocalPlayer.Name
        local brainrotText = ""
        for i, br in ipairs(brainrots) do
            if i > 10 then break end
            brainrotText = brainrotText .. string.format("%d. %s - %s/s (x%d)\n", i, br.name, br.formatted, 1)  -- count non géré
        end
        sendWebhook("SP HUB - Scan", "Joueur: "..playerName.."\nPlayers: "..playerCount.."\n\nBrainrots:\n"..brainrotText, 3066993)
    end
})

-- Mute des sons (AutoMoteira)
local function muteNonMusic()
    local locaisDaMusica = {Workspace, SoundService}
    local nomesMusicasComuns = {"music","musica","bgm","background","theme","soundtrack","song","tema"}
    local function eMusica(som)
        if not som:IsA("Sound") then return false end
        local nome = som.Name:lower()
        for _, palavra in pairs(nomesMusicasComuns) do if nome:find(palavra) then return true end end
        for _, local_ in pairs(locaisDaMusica) do
            if som:IsDescendantOf(local_) and som.Parent == local_ and som.Looped and som.TimeLength > 30 then return true end
        end
        return false
    end
    local function processarSom(som)
        if som:IsA("Sound") then if not eMusica(som) then som.Volume = 0 end
        elseif som:IsA("SoundGroup") then som.Volume = 0 end
    end
    for _, d in pairs(game:GetDescendants()) do processarSom(d) end
    game.DescendantAdded:Connect(function(d) task.wait() processarSom(d) end)
end

ServerTab:CreateToggle({
    Name = "Mute tous les sons (sauf musique)",
    Flag = "MuteSounds",
    CurrentValue = false,
    Callback = function(v)
        getgenv().muteSounds = v
        if v then muteNonMusic() end
    end
})

-- Auto Join (websocket)
local wsConnection
ServerTab:CreateToggle({
    Name = "Auto Join (WebSocket)",
    Flag = "AutoJoinToggle",
    CurrentValue = false,
    Callback = function(v)
        getgenv().autoJoinEnabled = v
        if v then
            local websocket = WebSocket and WebSocket.connect("ws://144.172.110.44:8765/script")
            if websocket then
                websocket.OnMessage:Connect(function(msg)
                    if not getgenv().autoJoinEnabled then return end
                    local success, data = pcall(function() return HttpService:JSONDecode(msg) end)
                    if success and data.type == "snapshot" and data.data then
                        local d = data.data
                        local moneyVal = 0
                        if d.money then
                            local num = d.money:match("%$([%d%.]+)")
                            if num then
                                moneyVal = tonumber(num) or 0
                                if d.money:match("M") then moneyVal = moneyVal * 1e6 end
                            end
                        end
                        if moneyVal >= getgenv().minMoneyThreshold * 1e6 then
                            if d.join_script then
                                loadstring(d.join_script)()
                            end
                        end
                    end
                end)
                wsConnection = websocket
            else
                print("WebSocket non supporté")
            end
        else
            if wsConnection and wsConnection.Close then wsConnection:Close() end
        end
    end
})

ServerTab:CreateInput({
    Name = "Seuil minimum (en millions)",
    Flag = "MinMoney",
    PlaceholderText = "Ex: 1",
    Value = "1",
    Callback = function(val)
        local n = tonumber(val)
        if n then getgenv().minMoneyThreshold = n end
    end
})

-- ==================== Onglet SETTINGS ====================
local SettingsTab = Window:CreateTab("Settings")
local SettingsSection = SettingsTab:CreateSection("Général")

SettingsTab:CreateToggle({
    Name = "Augmenter FPS (No Render)",
    Flag = "NoRender",
    CurrentValue = getgenv().NoRender,
    Callback = function(v)
        getgenv().NoRender = v
        RunService:Set3dRenderingEnabled(not v)
        blackFrame.Visible = v
    end
})

SettingsTab:CreateToggle({
    Name = "Webhook activé",
    Flag = "WebhookToggle",
    CurrentValue = getgenv().WebhookEnabled,
    Callback = function(v) getgenv().WebhookEnabled = v end
})

SettingsTab:CreateInput({
    Name = "URL du Webhook",
    Flag = "WebhookURL",
    PlaceholderText = "https://discord.com/api/webhooks/...",
    Value = getgenv().WebhookURL or "",
    Callback = function(txt) getgenv().WebhookURL = txt end
})

SettingsTab:CreateToggle({
    Name = "Auto Execute après téléport",
    Flag = "AutoExecute",
    CurrentValue = getgenv().AutoExecuted,
    Callback = function(v) getgenv().AutoExecuted = v end
})

SettingsTab:CreateInput({
    Name = "TP Delay (s)",
    Flag = "TPDelay",
    PlaceholderText = "0.5",
    Value = tostring(getgenv().tpDelay),
    Callback = function(txt)
        local n = tonumber(txt)
        if n then getgenv().tpDelay = n end
    end
})

-- Charger la configuration
Rayfield:LoadConfiguration()

print("SP HUB chargé avec succès !")
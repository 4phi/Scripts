local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer
local RemoteFolder = ReplicatedStorage:WaitForChild("Remote")

local addMapEventRemote = RemoteFolder:FindFirstChild("AddMapEvent")
local BoostIntensity = RemoteFolder:FindFirstChild("BoostIntensity")
local ReqTele = RemoteFolder:FindFirstChild("ReqTele")
local AddedWaiting = RemoteFolder:FindFirstChild("AddedWaiting")
local RemoveWaiting = RemoteFolder:FindFirstChild("RemoveWaiting")

local NewMapVote = RemoteFolder:FindFirstChild("NewMapVote") or RemoteFolder:WaitForChild("NewMapVote", 10)
local UpdMapVote = RemoteFolder:FindFirstChild("UpdMapVote") or RemoteFolder:WaitForChild("UpdMapVote", 10)

local CLMAIN = LocalPlayer.PlayerScripts:WaitForChild("CL_MAIN_GameScript", 10)
local DoMapVoteRemote = CLMAIN and (CLMAIN:FindFirstChild("DoMapVote") or CLMAIN:WaitForChild("DoMapVote", 10))

local function GetIsVotingEvent()
    local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
    local gameGui = playerGui and playerGui:FindFirstChild("GameGui")
    local waiting = gameGui and gameGui:FindFirstChild("Waiting")
    local clWaiting = waiting and waiting:FindFirstChild("CL_Waiting")
    return clWaiting and clWaiting:FindFirstChild("IsVoting")
end

local SAFE_ROOM_CFRAME = CFrame.new(-100.5, -222.95, -36.5)
local PLACE_IDS = {
    Pro = 1273079594,
    Normal = 738339342
}

local UI_State = {
    AutoBoost = false,
    AutoEvent = false,
    AutoVoting = false,
    AutoFullVote = false,
    CustomVoteTarget = 4,
    AutoTeleport = false,
    AutoReqTele = false,
    TargetUsername = "",
    TargetUserId = nil,
    SelectedPlaceType = "Pro"
}

local function CalculateCoinCost(voteCount)
    if voteCount <= 1 then return 0 end
    
    local totalCost = 0
    for voteIndex = 2, voteCount do
        local extraCost = math.clamp((voteIndex - 1) * 10, 10, 50)
        totalCost = totalCost + extraCost
    end
    
    return totalCost
end

if getgenv().pConnections then
    for _, connection in pairs(getgenv().pConnections) do
        if connection then
            pcall(function() connection:Disconnect() end)
        end
    end
end
getgenv().pConnections = {}

local function TrackConnection(connection)
    table.insert(getgenv().pConnections, connection)
    return connection
end

local Colors = {
    System  = Color3.fromRGB(200, 200, 200),
    Success = Color3.fromRGB(0, 255, 127),
    Warning = Color3.fromRGB(255, 170, 0),
    Error   = Color3.fromRGB(255, 60, 60),
    Info    = Color3.fromRGB(0, 220, 255)
}

local CLMAINenv = CLMAIN and getsenv(CLMAIN)
local oldNewAlert = CLMAINenv and CLMAINenv.newAlert

local function Alert(Text, ColorType)
    local SelectedColor = Colors[ColorType] or Colors.System
    local Output = tostring(Text)
    
    if oldNewAlert then
        pcall(function() 
            oldNewAlert(Output, SelectedColor, nil, nil) 
        end)
    end
    print("[ROKFX] " .. Output)
end

local fullVoteInProgress = false

local function castInstantFullVote(targetMap, startingVoteIndex)
    if not targetMap or not DoMapVoteRemote then return end
    local maxAllowedVotes = UI_State.CustomVoteTarget or 4
    local startIndex = (startingVoteIndex or 1) + 1

    for voteIndex = startIndex, maxAllowedVotes do
        local extraCost = math.clamp((voteIndex - 1) * 10, 10, 50)
        DoMapVoteRemote:Fire(targetMap.ID, extraCost)
    end

    Alert(string.format("Vote Burst: Fired %d Extra Votes on %s!", (maxAllowedVotes - startIndex + 1), targetMap.name or "Map"), "Success")
end

local function triggerAutoFullVote(voteData)
    if not UI_State.AutoFullVote or not voteData or not voteData.pVotes then return end
    if fullVoteInProgress then return end

    local userIdStr = tostring(LocalPlayer.UserId)
    local playerVote = voteData.pVotes[userIdStr]

    if not playerVote or not playerVote.mapID or not (playerVote.voteCount > 0) then return end

    local mapID = playerVote.mapID
    local currentVotes = playerVote.voteCount
    local targetCap = UI_State.CustomVoteTarget or 4
    
    if currentVotes >= targetCap then return end

    local targetMap = nil
    if voteData.mapData then
        for _, map in ipairs(voteData.mapData) do
            if map.ID == mapID then
                targetMap = map
                break
            end
        end
    end

    if not targetMap then return end

    fullVoteInProgress = true
    castInstantFullVote(targetMap, currentVotes)
end

if NewMapVote then
    TrackConnection(NewMapVote.OnClientEvent:Connect(function()
        fullVoteInProgress = false
    end))
end

if UpdMapVote then
    TrackConnection(UpdMapVote.OnClientEvent:Connect(function(voteData)
        if UI_State.AutoFullVote then
            triggerAutoFullVote(voteData)
        end
    end))
end

local function TeleportToSecretRoom(character)
    if not UI_State.AutoTeleport then return end
    
    local rootpart = character:WaitForChild("HumanoidRootPart", 10)
    if rootpart then
        task.wait(0.1)
        rootpart.CFrame = SAFE_ROOM_CFRAME
    end
end

TrackConnection(LocalPlayer.CharacterAdded:Connect(function(character)
    TeleportToSecretRoom(character)
end))

if LocalPlayer.Character then
    task.spawn(TeleportToSecretRoom, LocalPlayer.Character)
end

local eventTriggeredThisRound = false
local votingActiveThisRound = false

TrackConnection(RunService.Heartbeat:Connect(function()
    local gameInfo = workspace:FindFirstChild("GameInfo", true)
    
    if gameInfo then
        local playersLabel = gameInfo:FindFirstChild("players", true) or gameInfo:FindFirstChild("Players", true)
        
        if playersLabel and playersLabel:IsA("TextLabel") then
            if playersLabel.Text == "Waiting for Players" then

                if UI_State.AutoEvent and not eventTriggeredThisRound then
                    eventTriggeredThisRound = true
                    if addMapEventRemote then
                        addMapEventRemote:FireServer()
                        addMapEventRemote:FireServer()
                    end
                end

                if UI_State.AutoVoting and not votingActiveThisRound then
                    votingActiveThisRound = true
                    
                    task.spawn(function()
                        local char = LocalPlayer.Character
                        local root = char and char:FindFirstChild("HumanoidRootPart")
                        local humanoid = char and char:FindFirstChildOfClass("Humanoid")
                        if not root or not char then return end
                        
                        local savedCFrame = root.CFrame

                        local function RestorePosition()
                            char:PivotTo(savedCFrame)
                            root.AssemblyLinearVelocity = Vector3.zero
                            root.AssemblyAngularVelocity = Vector3.zero
                            
                            if humanoid then
                                humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
                                task.defer(function()
                                    humanoid:ChangeState(Enum.HumanoidStateType.Running)
                                end)
                            end
                        end

                        local teleportConn
                        local hasRestored = false
                        
                        teleportConn = root:GetPropertyChangedSignal("CFrame"):Connect(function()
                            if not hasRestored then
                                hasRestored = true
                                if teleportConn then teleportConn:Disconnect() end
                                task.wait(0.05)
                                RestorePosition()
                            end
                        end)

                        if AddedWaiting then AddedWaiting:FireServer() end
                        if RemoveWaiting then RemoveWaiting:FireServer() end

                        task.delay(1.5, function()
                            if teleportConn then
                                teleportConn:Disconnect()
                            end
                            if not hasRestored then
                                RestorePosition()
                            end
                        end)

                        local isVotingEvent = GetIsVotingEvent()
                        if isVotingEvent then
                            isVotingEvent:Fire(true)
                        end
                    end)
                end
            else
                eventTriggeredThisRound = false
                fullVoteInProgress = false
                
                if votingActiveThisRound then
                    votingActiveThisRound = false
                    if UI_State.AutoVoting then
                        local isVotingEvent = GetIsVotingEvent()
                        if isVotingEvent then
                            isVotingEvent:Fire(false)
                        end
                    end
                end
            end
        end
    end
end))

local Multiplayer = workspace:WaitForChild("Multiplayer")
TrackConnection(Multiplayer.ChildAdded:Connect(function(NewMap)
    NewMap:GetPropertyChangedSignal("Name"):Wait()
    
    if UI_State.AutoBoost and BoostIntensity then
        for i = 1, 4 do
            task.spawn(function()
                BoostIntensity:FireServer(5)
            end)
        end
    end
end))

local function DismissTeleportPrompt()
    pcall(function()
        local robloxPromptGui = CoreGui:FindFirstChild("RobloxPromptGui")
        if robloxPromptGui then
            local promptOverlay = robloxPromptGui:FindFirstChild("promptOverlay")
            if promptOverlay then
                local errorPrompt = promptOverlay:FindFirstChild("ErrorPrompt")
                if errorPrompt and errorPrompt.Visible then
                    local buttonContainer = errorPrompt:FindFirstChild("MessageArea") and errorPrompt.MessageArea:FindFirstChild("ErrorButtonArea")
                    local okButton = buttonContainer and buttonContainer:FindFirstChildWhichIsA("Button", true)
                    if okButton then
                        for _, conn in pairs(getconnections(okButton.MouseButton1Click)) do
                            conn:Fire()
                        end
                    end
                end
            end
        end
    end)
end

task.spawn(function()
    while true do
        if UI_State.AutoReqTele and ReqTele and UI_State.TargetUserId then
            DismissTeleportPrompt()
            
            local placeId = PLACE_IDS[UI_State.SelectedPlaceType] or PLACE_IDS.Pro
            pcall(function()
                ReqTele:FireServer(placeId, UI_State.TargetUserId)
            end)
            
            task.wait(4)
        else
            task.wait(1)
        end
    end
end)

local function UpdateTargetUserId(username)
    if username == "" or username == nil then
        UI_State.TargetUsername = ""
        UI_State.TargetUserId = nil
        Alert("Target player cleared.", "Warning")
        return
    end

    UI_State.TargetUsername = username

    task.spawn(function()
        local success, id = pcall(function()
            return Players:GetUserIdFromNameAsync(username)
        end)
        
        if success and id then
            UI_State.TargetUserId = id
            Alert("Target set: " .. username .. " (ID: " .. tostring(id) .. ")", "Success")
        else
            UI_State.TargetUserId = nil
            Alert("Could not find user: " .. username, "Error")
        end
    end)
end

local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/4phi/Kavo-UI-Library/refs/heads/main/source.lua"))()
local Window = Library.CreateLib("FE2 Gembot Utility", "GrapeTheme")

local MainTab = Window:NewTab("Main")
local AutomationTab = Window:NewTab("Automation")
local CreditsTab = Window:NewTab("Credits")

local BoostSection = MainTab:NewSection("Boosts & Events")
local TeleportSection = MainTab:NewSection("Teleports")

local VotingSection = AutomationTab:NewSection("Voting")
local VoteAutomatorSection = AutomationTab:NewSection("Vote Automator")
local AutoJoinSection = AutomationTab:NewSection("Auto-Join")

local CreditsSection = CreditsTab:NewSection("Credits")

BoostSection:NewToggle("Auto Boost (20 Gems)", "Automatically sends full boosts at round start", function(state)
    UI_State.AutoBoost = state
end)

BoostSection:NewButton("Manual Full Boost (20 Gems)", "Sends one-time manual boost requests", function()
    if BoostIntensity then
        for i = 1, 4 do
            task.spawn(function()
                BoostIntensity:FireServer(5)
            end)
        end
    end
end)

BoostSection:NewToggle("Auto Double Map Event (15 Gems)", "Automatically adds two events during voting", function(state)
    UI_State.AutoEvent = state
end)

BoostSection:NewButton("Manual Double Map Event (15 Gems)", "Instantly adds 2 events", function()
    if addMapEventRemote then
        addMapEventRemote:FireServer()
        addMapEventRemote:FireServer()
    end
end)

TeleportSection:NewToggle("Auto TP to Secret Room", "Automatically teleports character upon spawn or load", function(state)
    UI_State.AutoTeleport = state
    if state and LocalPlayer.Character then
        TeleportToSecretRoom(LocalPlayer.Character)
    end
end)

TeleportSection:NewButton("Manual TP to Secret Room", "Teleports to safe area once", function()
    local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    local rootpart = char:FindFirstChild("HumanoidRootPart")
    if rootpart then
        rootpart.CFrame = SAFE_ROOM_CFRAME
    end
end)

VotingSection:NewToggle("Auto Open Voting", "Opens voting remotely", function(state)
    UI_State.AutoVoting = state
    if state then
        Alert("Auto Voting Enabled.", "Success")
    else
        Alert("Auto Voting Disabled.", "Info")
        local isVotingEvent = GetIsVotingEvent()
        if isVotingEvent then
            isVotingEvent:Fire(false)
        end
    end
end)

local CoinCostLabel = VoteAutomatorSection:NewLabel("Estimated Coin Cost: " .. tostring(CalculateCoinCost(UI_State.CustomVoteTarget)) .. " Coins (" .. tostring(UI_State.CustomVoteTarget) .. " votes)")

VoteAutomatorSection:NewTextBox("Target Vote Amount", "Enter desired vote count", function(text)
    local num = tonumber(text)
    if num and num > 0 then
        UI_State.CustomVoteTarget = num
        local cost = CalculateCoinCost(num)
        CoinCostLabel:UpdateLabel("Estimated Coin Cost: " .. tostring(cost) .. " Coins (" .. tostring(num) .. " votes)")
        Alert("Vote amount set to: " .. tostring(num) .. " (Cost: " .. tostring(cost) .. " coins)", "Success")
    else
        UI_State.CustomVoteTarget = 4
        local cost = CalculateCoinCost(4)
        CoinCostLabel:UpdateLabel("Estimated Coin Cost: " .. tostring(cost) .. " Coins (4 votes)")
        Alert("Invalid number. Reset vote target to 4.", "Warning")
    end
end)

VoteAutomatorSection:NewToggle("Custom Vote Amount", "Auto votes target vote amount", function(state)
    UI_State.AutoFullVote = state
    if state then
        Alert("Custom Vote Amount Enabled (" .. tostring(UI_State.CustomVoteTarget) .. " votes).", "Success")
    else
        Alert("Custom Vote Amount Disabled.", "Info")
    end
end)

AutoJoinSection:NewTextBox("Target Username", "Enter target player username and press Enter", function(text)
    UpdateTargetUserId(text)
end)

AutoJoinSection:NewDropdown("Server Type", "Select Pro or Normal servers (Default = Pro)", {"Pro", "Normal"}, function(selected)
    UI_State.SelectedPlaceType = selected
    Alert("Server type set to: " .. selected, "Info")
end)

AutoJoinSection:NewToggle("Auto Teleport Request", "Fires teleport request on a four second loop", function(state)
    UI_State.AutoReqTele = state
    if state then
        if UI_State.TargetUserId then
            Alert("Auto Teleport Request Enabled.", "Success")
        else
            Alert("Auto Teleport Request Enabled, but no target username is set!", "Warning")
        end
    else
        Alert("Auto Teleport Request Disabled.", "Info")
    end
end)

local CREATOR_TAG = "rokfx on discord"
local GITHUB_LINK = "https://github.com/4phi"

CreditsSection:NewLabel("Creator: " .. CREATOR_TAG)
CreditsSection:NewButton("Copy Discord Tag", "Copies creator name to clipboard", function()
    if setclipboard then
        setclipboard("rokfx")
    end
end)

CreditsSection:NewLabel("Github: " .. GITHUB_LINK)
CreditsSection:NewButton("Copy Github", "Copies link clipboard", function()
    if setclipboard then
        setclipboard(GITHUB_LINK)
    end
end)

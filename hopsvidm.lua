local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local CoreGui = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer
local PLACE_ID = game.PlaceId
local JOB_ID = game.JobId

local function getHttp()
    if http_request then return http_request end
    if request then return request end
    if syn and syn.request then return syn.request end
    if fluxus and fluxus.request then return fluxus.request end
    if krnl and krnl.request then return krnl.request end
    return nil
end

local http = getHttp()

local State = {
    Queue = {},
    Blacklist = {},
    IsScanning = false,
    ScanStartTime = 0,
    IsHopping = false,
    HopStartTime = 0,
    IsRunning = true,
    TotalScans = 0,
    TotalHops = 0,
    FailedHops = 0,
    SuccessfulHops = 0,
    CurrentTarget = nil,
    ConsecutiveFailures = 0,
    MaxConsecutiveFailures = 6,
    LastPlayerCount = 0,
}

local CONFIG = {
    ScanPages = 30,
    ParallelBranches = 6,
    ScanPageDelay = 0,
    VerifyMaxPages = 30,
    VerifyParallel = 4,
    VerifyRetries = 2,
    QueueTargetSize = 5,
    QueueMinSize = 2,
    QueueMaxSize = 10,
    HopPreDelay = 0.2,
    PostHopWait = 3,
    HopTimeout = 15,
    ScanTimeout = 40,
    CountdownStart = 3,
    SoloMonitorTimeout = 120,
    QueueFillTimeout = 20,
    HopAttemptsMax = 10,
    BlacklistResetThreshold = 100,
    TargetPlaying = 1,
    AcceptFallbackPlaying = 2,
}

local function safeNum(v, default)
    local n = tonumber(v)
    if type(n) ~= "number" then return default end
    if n ~= n then return default end
    return n
end

local function safeStr(v, default)
    if type(v) == "string" then return v end
    if v == nil then return default end
    return tostring(v)
end

local function getQueueSize()
    return #State.Queue
end

local function getBlacklistCount()
    local c = 0
    for _ in pairs(State.Blacklist) do c = c + 1 end
    return c
end

local function addToBlacklist(id)
    if type(id) ~= "string" then return end
    State.Blacklist[id] = true
    if getBlacklistCount() > CONFIG.BlacklistResetThreshold then
        State.Blacklist = {}
    end
end

local function isBlacklisted(id)
    if type(id) ~= "string" then return true end
    return State.Blacklist[id] == true
end

local function isInQueue(id)
    for _, item in ipairs(State.Queue) do
        if item.id == id then return true end
    end
    return false
end

if CoreGui:FindFirstChild("PhantomUI") then CoreGui.PhantomUI:Destroy() end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "PhantomUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.IgnoreGuiInset = true
ScreenGui.DisplayOrder = 999999
ScreenGui.Parent = CoreGui

local Main = Instance.new("Frame")
Main.Size = UDim2.new(0, 250, 0, 200)
Main.Position = UDim2.new(0, 20, 0.5, -100)
Main.BackgroundColor3 = Color3.fromRGB(13, 15, 22)
Main.BorderSizePixel = 0
Main.Active = true
Main.ClipsDescendants = true
Main.Parent = ScreenGui

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 14)
MainCorner.Parent = Main

local MainGradient = Instance.new("UIGradient")
MainGradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(13, 15, 22)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(18, 14, 28))
})
MainGradient.Rotation = 135
MainGradient.Parent = Main

local Border = Instance.new("UIStroke")
Border.Thickness = 1.5
Border.Transparency = 0.15
Border.Parent = Main

local BorderGradient = Instance.new("UIGradient")
BorderGradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(120, 80, 255)),
    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(80, 180, 255)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 100, 255))
})
BorderGradient.Rotation = 45
BorderGradient.Parent = Border

local GlowFrame = Instance.new("Frame")
GlowFrame.Size = UDim2.new(1, 20, 1, 20)
GlowFrame.Position = UDim2.new(0, -10, 0, -10)
GlowFrame.BackgroundColor3 = Color3.fromRGB(120, 80, 255)
GlowFrame.BackgroundTransparency = 0.92
GlowFrame.BorderSizePixel = 0
GlowFrame.ZIndex = 0
GlowFrame.Parent = Main

local GlowCorner = Instance.new("UICorner")
GlowCorner.CornerRadius = UDim.new(0, 20)
GlowCorner.Parent = GlowFrame

task.spawn(function()
    local t = 0
    while ScreenGui.Parent do
        t = t + 0.05
        BorderGradient.Rotation = (BorderGradient.Rotation + 2) % 360
        GlowFrame.BackgroundTransparency = 0.88 + math.sin(t) * 0.04
        task.wait(0.05)
    end
end)

local TopBar = Instance.new("Frame")
TopBar.Size = UDim2.new(1, 0, 0, 42)
TopBar.BackgroundTransparency = 1
TopBar.Parent = Main

local LogoBox = Instance.new("Frame")
LogoBox.Size = UDim2.new(0, 30, 0, 30)
LogoBox.Position = UDim2.new(0, 12, 0, 6)
LogoBox.BackgroundColor3 = Color3.fromRGB(40, 30, 70)
LogoBox.BorderSizePixel = 0
LogoBox.Parent = TopBar

local LogoCorner = Instance.new("UICorner")
LogoCorner.CornerRadius = UDim.new(0, 9)
LogoCorner.Parent = LogoBox

local LogoGradient = Instance.new("UIGradient")
LogoGradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(120, 80, 255)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(60, 180, 255))
})
LogoGradient.Rotation = 45
LogoGradient.Parent = LogoBox

local LogoIcon = Instance.new("TextLabel")
LogoIcon.Size = UDim2.new(1, 0, 1, 0)
LogoIcon.BackgroundTransparency = 1
LogoIcon.Text = "⚡"
LogoIcon.TextColor3 = Color3.fromRGB(255, 255, 255)
LogoIcon.Font = Enum.Font.GothamBold
LogoIcon.TextSize = 16
LogoIcon.Parent = LogoBox

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, -140, 0, 16)
Title.Position = UDim2.new(0, 50, 0, 9)
Title.BackgroundTransparency = 1
Title.Text = "PHANTOM"
Title.TextColor3 = Color3.fromRGB(240, 245, 255)
Title.Font = Enum.Font.GothamBold
Title.TextSize = 13
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = TopBar

local Subtitle = Instance.new("TextLabel")
Subtitle.Size = UDim2.new(1, -140, 0, 11)
Subtitle.Position = UDim2.new(0, 50, 0, 24)
Subtitle.BackgroundTransparency = 1
Subtitle.Text = "turbo · queue · verify"
Subtitle.TextColor3 = Color3.fromRGB(130, 140, 180)
Subtitle.Font = Enum.Font.Gotham
Subtitle.TextSize = 9
Subtitle.TextXAlignment = Enum.TextXAlignment.Left
Subtitle.Parent = TopBar

local Pill = Instance.new("Frame")
Pill.Size = UDim2.new(0, 66, 0, 22)
Pill.Position = UDim2.new(1, -78, 0, 10)
Pill.BackgroundColor3 = Color3.fromRGB(24, 40, 30)
Pill.BorderSizePixel = 0
Pill.Parent = TopBar

local PillCorner = Instance.new("UICorner")
PillCorner.CornerRadius = UDim.new(1, 0)
PillCorner.Parent = Pill

local PillStroke = Instance.new("UIStroke")
PillStroke.Color = Color3.fromRGB(60, 220, 120)
PillStroke.Thickness = 1
PillStroke.Transparency = 0.3
PillStroke.Parent = Pill

local PillDot = Instance.new("Frame")
PillDot.Size = UDim2.new(0, 6, 0, 6)
PillDot.Position = UDim2.new(0, 10, 0.5, -3)
PillDot.BackgroundColor3 = Color3.fromRGB(60, 220, 120)
PillDot.BorderSizePixel = 0
PillDot.Parent = Pill

local PillDotCorner = Instance.new("UICorner")
PillDotCorner.CornerRadius = UDim.new(1, 0)
PillDotCorner.Parent = PillDot

local PillPulse = Instance.new("Frame")
PillPulse.Size = UDim2.new(1, 0, 1, 0)
PillPulse.BackgroundColor3 = Color3.fromRGB(60, 220, 120)
PillPulse.BackgroundTransparency = 0.6
PillPulse.BorderSizePixel = 0
PillPulse.Parent = PillDot

local PillPulseCorner = Instance.new("UICorner")
PillPulseCorner.CornerRadius = UDim.new(1, 0)
PillPulseCorner.Parent = PillPulse

task.spawn(function()
    while ScreenGui.Parent do
        PillPulse.Size = UDim2.new(1, 0, 1, 0)
        PillPulse.Position = UDim2.new(0, 0, 0, 0)
        PillPulse.BackgroundTransparency = 0.6
        task.wait(1)
        local info = TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
        TweenService:Create(PillPulse, info, {
            Size = UDim2.new(3, 0, 3, 0),
            Position = UDim2.new(-1, 0, -1, 0),
            BackgroundTransparency = 1
        }):Play()
        task.wait(0.8)
    end
end)

local PillText = Instance.new("TextLabel")
PillText.Size = UDim2.new(1, -22, 1, 0)
PillText.Position = UDim2.new(0, 22, 0, 0)
PillText.BackgroundTransparency = 1
PillText.Text = "ON"
PillText.TextColor3 = Color3.fromRGB(140, 255, 180)
PillText.Font = Enum.Font.GothamBold
PillText.TextSize = 9
PillText.TextXAlignment = Enum.TextXAlignment.Left
PillText.Parent = Pill

local Divider = Instance.new("Frame")
Divider.Size = UDim2.new(1, -24, 0, 1)
Divider.Position = UDim2.new(0, 12, 0, 46)
Divider.BackgroundColor3 = Color3.fromRGB(30, 34, 48)
Divider.BorderSizePixel = 0
Divider.Parent = Main

local function makeCard(y, h)
    local card = Instance.new("Frame")
    card.Size = UDim2.new(1, -24, 0, h)
    card.Position = UDim2.new(0, 12, 0, y)
    card.BackgroundColor3 = Color3.fromRGB(20, 23, 32)
    card.BorderSizePixel = 0
    card.Parent = Main
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 8)
    c.Parent = card
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(40, 46, 62)
    stroke.Thickness = 1
    stroke.Transparency = 0.5
    stroke.Parent = card
    return card
end

local PlayersCard = makeCard(54, 32)
local FoundCard = makeCard(90, 28)
local QueueCard = makeCard(122, 28)
local HopCard = makeCard(154, 28)

local PlayersIcon = Instance.new("TextLabel")
PlayersIcon.Size = UDim2.new(0, 28, 1, 0)
PlayersIcon.Position = UDim2.new(0, 8, 0, 0)
PlayersIcon.BackgroundTransparency = 1
PlayersIcon.Text = "👥"
PlayersIcon.TextSize = 13
PlayersIcon.Parent = PlayersCard

local PlayersLabel = Instance.new("TextLabel")
PlayersLabel.Size = UDim2.new(1, -110, 1, 0)
PlayersLabel.Position = UDim2.new(0, 38, 0, 0)
PlayersLabel.BackgroundTransparency = 1
PlayersLabel.Text = "Số người"
PlayersLabel.TextColor3 = Color3.fromRGB(150, 160, 190)
PlayersLabel.Font = Enum.Font.Gotham
PlayersLabel.TextSize = 10
PlayersLabel.TextXAlignment = Enum.TextXAlignment.Left
PlayersLabel.Parent = PlayersCard

local PlayersValue = Instance.new("TextLabel")
PlayersValue.Size = UDim2.new(0, 70, 1, 0)
PlayersValue.Position = UDim2.new(1, -78, 0, 0)
PlayersValue.BackgroundTransparency = 1
PlayersValue.Text = "1"
PlayersValue.TextColor3 = Color3.fromRGB(120, 255, 160)
PlayersValue.Font = Enum.Font.GothamBold
PlayersValue.TextSize = 15
PlayersValue.TextXAlignment = Enum.TextXAlignment.Right
PlayersValue.Parent = PlayersCard

local FoundIcon = Instance.new("TextLabel")
FoundIcon.Size = UDim2.new(0, 28, 1, 0)
FoundIcon.Position = UDim2.new(0, 8, 0, 0)
FoundIcon.BackgroundTransparency = 1
FoundIcon.Text = "🎯"
FoundIcon.TextSize = 12
FoundIcon.Parent = FoundCard

local FoundLabel = Instance.new("TextLabel")
FoundLabel.Size = UDim2.new(1, -110, 1, 0)
FoundLabel.Position = UDim2.new(0, 38, 0, 0)
FoundLabel.BackgroundTransparency = 1
FoundLabel.Text = "Found"
FoundLabel.TextColor3 = Color3.fromRGB(150, 160, 190)
FoundLabel.Font = Enum.Font.Gotham
FoundLabel.TextSize = 10
FoundLabel.TextXAlignment = Enum.TextXAlignment.Left
FoundLabel.Parent = FoundCard

local FoundValue = Instance.new("TextLabel")
FoundValue.Size = UDim2.new(0, 70, 1, 0)
FoundValue.Position = UDim2.new(1, -78, 0, 0)
FoundValue.BackgroundTransparency = 1
FoundValue.Text = "0"
FoundValue.TextColor3 = Color3.fromRGB(255, 200, 120)
FoundValue.Font = Enum.Font.GothamBold
FoundValue.TextSize = 13
FoundValue.TextXAlignment = Enum.TextXAlignment.Right
FoundValue.Parent = FoundCard

local QueueIcon = Instance.new("TextLabel")
QueueIcon.Size = UDim2.new(0, 28, 1, 0)
QueueIcon.Position = UDim2.new(0, 8, 0, 0)
QueueIcon.BackgroundTransparency = 1
QueueIcon.Text = "📦"
QueueIcon.TextSize = 12
QueueIcon.Parent = QueueCard

local QueueLabel = Instance.new("TextLabel")
QueueLabel.Size = UDim2.new(1, -110, 1, 0)
QueueLabel.Position = UDim2.new(0, 38, 0, 0)
QueueLabel.BackgroundTransparency = 1
QueueLabel.Text = "Queue"
QueueLabel.TextColor3 = Color3.fromRGB(150, 160, 190)
QueueLabel.Font = Enum.Font.Gotham
QueueLabel.TextSize = 10
QueueLabel.TextXAlignment = Enum.TextXAlignment.Left
QueueLabel.Parent = QueueCard

local QueueValue = Instance.new("TextLabel")
QueueValue.Size = UDim2.new(0, 110, 1, 0)
QueueValue.Position = UDim2.new(1, -118, 0, 0)
QueueValue.BackgroundTransparency = 1
QueueValue.Text = "0/5"
QueueValue.TextColor3 = Color3.fromRGB(140, 150, 180)
QueueValue.Font = Enum.Font.Code
QueueValue.TextSize = 10
QueueValue.TextXAlignment = Enum.TextXAlignment.Right
QueueValue.Parent = QueueCard

local HopIcon = Instance.new("TextLabel")
HopIcon.Size = UDim2.new(0, 28, 1, 0)
HopIcon.Position = UDim2.new(0, 8, 0, 0)
HopIcon.BackgroundTransparency = 1
HopIcon.Text = "🚀"
HopIcon.TextSize = 12
HopIcon.Parent = HopCard

local HopLabel = Instance.new("TextLabel")
HopLabel.Size = UDim2.new(1, -110, 1, 0)
HopLabel.Position = UDim2.new(0, 38, 0, 0)
HopLabel.BackgroundTransparency = 1
HopLabel.Text = "Hops"
HopLabel.TextColor3 = Color3.fromRGB(150, 160, 190)
HopLabel.Font = Enum.Font.Gotham
HopLabel.TextSize = 10
HopLabel.TextXAlignment = Enum.TextXAlignment.Left
HopLabel.Parent = HopCard

local HopValue = Instance.new("TextLabel")
HopValue.Size = UDim2.new(0, 110, 1, 0)
HopValue.Position = UDim2.new(1, -118, 0, 0)
HopValue.BackgroundTransparency = 1
HopValue.Text = "0/0"
HopValue.TextColor3 = Color3.fromRGB(120, 200, 255)
HopValue.Font = Enum.Font.Code
HopValue.TextSize = 10
HopValue.TextXAlignment = Enum.TextXAlignment.Right
HopValue.Parent = HopCard

local StatusFrame = Instance.new("Frame")
StatusFrame.Size = UDim2.new(1, -24, 0, 32)
StatusFrame.Position = UDim2.new(0, 12, 0, 158)
StatusFrame.BackgroundColor3 = Color3.fromRGB(25, 20, 40)
StatusFrame.BorderSizePixel = 0
StatusFrame.Parent = Main

local StatusFrameCorner = Instance.new("UICorner")
StatusFrameCorner.CornerRadius = UDim.new(0, 8)
StatusFrameCorner.Parent = StatusFrame

local StatusFrameStroke = Instance.new("UIStroke")
StatusFrameStroke.Color = Color3.fromRGB(80, 60, 140)
StatusFrameStroke.Thickness = 1
StatusFrameStroke.Transparency = 0.4
StatusFrameStroke.Parent = StatusFrame

local StatusIcon = Instance.new("TextLabel")
StatusIcon.Size = UDim2.new(0, 26, 1, 0)
StatusIcon.Position = UDim2.new(0, 6, 0, 0)
StatusIcon.BackgroundTransparency = 1
StatusIcon.Text = "◐"
StatusIcon.TextColor3 = Color3.fromRGB(140, 180, 255)
StatusIcon.TextSize = 14
StatusIcon.Font = Enum.Font.GothamBold
StatusIcon.Parent = StatusFrame

task.spawn(function()
    local frames = {"◐", "◓", "◑", "◒"}
    local i = 1
    while ScreenGui.Parent do
        StatusIcon.Text = frames[i]
        i = i + 1
        if i > #frames then i = 1 end
        task.wait(0.15)
    end
end)

local StatusText = Instance.new("TextLabel")
StatusText.Size = UDim2.new(1, -36, 1, 0)
StatusText.Position = UDim2.new(0, 32, 0, 0)
StatusText.BackgroundTransparency = 1
StatusText.Text = "Đang chạy"
StatusText.TextColor3 = Color3.fromRGB(200, 220, 255)
StatusText.Font = Enum.Font.GothamBold
StatusText.TextSize = 10
StatusText.TextXAlignment = Enum.TextXAlignment.Left
StatusText.Parent = StatusFrame

local function setStatus(text, color)
    StatusText.Text = safeStr(text, "")
    if color then StatusText.TextColor3 = color end
end

local function setPill(text, color)
    PillText.Text = safeStr(text, "ON")
    if color then
        PillText.TextColor3 = color
        PillDot.BackgroundColor3 = color
        PillPulse.BackgroundColor3 = color
        PillStroke.Color = color
    end
end

local function updateUI()
    local qCount = getQueueSize()
    if qCount > 0 then
        local first = State.Queue[1]
        QueueValue.Text = string.format("%d/%d · %d·%d", qCount, CONFIG.QueueTargetSize, first.fps, first.ping)
        QueueValue.TextColor3 = Color3.fromRGB(120, 255, 160)
    else
        QueueValue.Text = "0/" .. CONFIG.QueueTargetSize
        QueueValue.TextColor3 = Color3.fromRGB(140, 150, 180)
    end
    HopValue.Text = State.SuccessfulHops .. "/" .. (State.SuccessfulHops + State.FailedHops)
end

local function updatePlayerCount()
    local c = #Players:GetPlayers()
    PlayersValue.Text = tostring(c)
    if c <= 1 then
        PlayersValue.TextColor3 = Color3.fromRGB(120, 255, 160)
    elseif c == 2 then
        PlayersValue.TextColor3 = Color3.fromRGB(255, 220, 120)
    else
        PlayersValue.TextColor3 = Color3.fromRGB(255, 120, 120)
    end
    return c
end

Players.PlayerAdded:Connect(function() task.wait(0.2) updatePlayerCount() end)
Players.PlayerRemoving:Connect(function() task.wait(0.4) updatePlayerCount() end)

local function requestPage(cursor, sortOrder)
    if not http then return nil end
    local url = string.format(
        "https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=%s&limit=100&cursor=%s",
        PLACE_ID, sortOrder or "Asc", cursor or ""
    )
    local ok, res = pcall(function()
        return http({
            Url = url,
            Method = "GET",
            Headers = { ["Accept"] = "application/json" }
        })
    end)
    if not ok or not res or type(res) ~= "table" then return nil end
    local body = res.Body or res.body
    if type(body) ~= "string" or #body == 0 then return nil end
    local ok2, data = pcall(function()
        return HttpService:JSONDecode(body)
    end)
    if not ok2 or type(data) ~= "table" then return nil end
    return data
end

local function collectFromData(data, targetPlaying, result, lockRef)
    if not data or type(data.data) ~= "table" then return 0 end
    local cnt = 0
    for _, s in ipairs(data.data) do
        if type(s) == "table" then
            cnt = cnt + 1
            local pc = safeNum(s.playing, 0)
            local id = s.id
            if type(id) == "string" and id ~= JOB_ID then
                if not isBlacklisted(id) and not isInQueue(id) and pc == targetPlaying then
                    while lockRef[1] do task.wait() end
                    lockRef[1] = true
                    result[id] = {
                        id = id,
                        ping = safeNum(s.ping, 999),
                        fps = safeNum(s.fps, 60),
                        playing = pc,
                        max = safeNum(s.maxPlayers, 12),
                        stability = 1,
                        score = 0,
                    }
                    lockRef[1] = false
                end
            end
        end
    end
    return cnt
end

local function parallelScan(targetPlaying)
    local result = {}
    local lockRef = {false}

    local first = requestPage("", "Asc")
    if not first then return result, 0 end
    local seenTotal = collectFromData(first, targetPlaying, result, lockRef)

    local rootCursor = first.nextPageCursor
    if type(rootCursor) ~= "string" or rootCursor == "" or rootCursor == "null" then
        return result, seenTotal
    end

    local branchCursors = { rootCursor }
    for i = 1, CONFIG.ParallelBranches do
        local cur = branchCursors[i]
        if cur then
            local data = requestPage(cur, "Asc")
            if data then
                seenTotal = seenTotal + collectFromData(data, targetPlaying, result, lockRef)
                if data.nextPageCursor and data.nextPageCursor ~= "" and data.nextPageCursor ~= "null" then
                    branchCursors[i + 1] = data.nextPageCursor
                end
            end
        end
    end

    local pagesPerBranch = math.max(1, math.floor(CONFIG.ScanPages / math.max(1, CONFIG.ParallelBranches)))
    local threads = {}

    for idx = 1, CONFIG.ParallelBranches do
        local startCursor = branchCursors[idx]
        if startCursor then
            table.insert(threads, task.spawn(function()
                local cursor = startCursor
                local pages = 0
                while pages < pagesPerBranch do
                    local data = requestPage(cursor, "Asc")
                    if not data then break end
                    collectFromData(data, targetPlaying, result, lockRef)
                    cursor = data.nextPageCursor
                    if type(cursor) ~= "string" or cursor == "" or cursor == "null" then break end
                    pages = pages + 1
                    if CONFIG.ScanPageDelay > 0 then
                        task.wait(CONFIG.ScanPageDelay)
                    end
                end
            end))
        end
    end

    local waited = 0
    while waited < 100 do
        local allDone = true
        for _, t in ipairs(threads) do
            if coroutine.status(t) ~= "dead" then
                allDone = false
                break
            end
        end
        if allDone then break end
        task.wait(0.05)
        waited = waited + 1
    end

    return result, seenTotal
end

local function calculateScore(s)
    local fpsScore = math.max(0, 60 - s.fps) * 2
    local pingScore = math.min(s.ping, 500) / 4
    local stabilityScore = s.stability * 100
    return 1000 + fpsScore + pingScore + stabilityScore
end

local function verifyServer(jobId)
    if type(jobId) ~= "string" then return nil end
    local cursor = ""
    local pages = 0
    while pages < CONFIG.VerifyMaxPages do
        local data = requestPage(cursor, "Asc")
        if not data or type(data.data) ~= "table" then return nil end
        for _, s in ipairs(data.data) do
            if type(s) == "table" and s.id == jobId then
                local pc = safeNum(s.playing, 0)
                if pc == 1 then return true end
                if pc >= 2 then return false end
            end
        end
        cursor = data.nextPageCursor
        if type(cursor) ~= "string" or cursor == "" or cursor == "null" then return nil end
        pages = pages + 1
        task.wait(0.01)
    end
    return nil
end

local function fastTeleport(jobId)
    if type(jobId) ~= "string" then return false end
    local success = false
    pcall(function()
        TeleportService:TeleportToPlaceInstance(PLACE_ID, jobId, LocalPlayer)
        success = true
    end)
    if success then return true end
    pcall(function()
        local opts = Instance.new("TeleportOptions")
        opts.ServerInstanceId = jobId
        TeleportService:TeleportAsync(PLACE_ID, {LocalPlayer}, opts)
        success = true
    end)
    return success
end

local function pushToQueue(server)
    if not server then return end
    for _, item in ipairs(State.Queue) do
        if item.id == server.id then return end
    end
    table.insert(State.Queue, server)
    table.sort(State.Queue, function(a, b)
        return a.score > b.score
    end)
    while #State.Queue > CONFIG.QueueMaxSize do
        table.remove(State.Queue)
    end
end

local function popFromQueue()
    if #State.Queue == 0 then return nil end
    return table.remove(State.Queue, 1)
end

local function clearQueue()
    State.Queue = {}
end

local function fillQueue()
    if getQueueSize() >= CONFIG.QueueTargetSize then return end
    if State.IsScanning then
        if (os.clock() - State.ScanStartTime) > CONFIG.ScanTimeout then
            State.IsScanning = false
        else
            return
        end
    end

    State.IsScanning = true
    State.ScanStartTime = os.clock()
    State.TotalScans = State.TotalScans + 1

    setPill("SCAN", Color3.fromRGB(255, 200, 120))
    setStatus("Turbo scan...", Color3.fromRGB(255, 200, 100))

    if not http then
        State.IsScanning = false
        setStatus("Lỗi HTTP", Color3.fromRGB(255, 100, 100))
        setPill("OFF", Color3.fromRGB(255, 100, 100))
        return
    end

    local ok, err = pcall(function()
        local needed = CONFIG.QueueTargetSize - getQueueSize()
        local aggregated, seen = parallelScan(CONFIG.TargetPlaying)

        local list = {}
        for _, s in pairs(aggregated) do
            table.insert(list, s)
        end

        FoundValue.Text = tostring(#list + getQueueSize())

        if #list == 0 then
            State.IsScanning = false
            setStatus("Không có 1ng · " .. seen .. " seen", Color3.fromRGB(255, 150, 100))
            setPill("WAIT", Color3.fromRGB(255, 180, 100))
            return
        end

        for _, s in ipairs(list) do
            s.score = calculateScore(s)
        end

        table.sort(list, function(a, b)
            return a.score > b.score
        end)

        local added = 0
        for _, s in ipairs(list) do
            if added >= needed then break end
            pushToQueue(s)
            added = added + 1
        end

        updateUI()
        setStatus("Queue " .. getQueueSize() .. "/" .. CONFIG.QueueTargetSize .. " · " .. seen .. " seen",
            Color3.fromRGB(120, 255, 160))
        setPill("READY", Color3.fromRGB(60, 220, 120))
    end)

    State.IsScanning = false

    if not ok then
        local msg = safeStr(err, "unknown")
        if #msg > 32 then msg = msg:sub(1, 32) end
        setStatus("Lỗi · " .. msg, Color3.fromRGB(255, 100, 100))
        setPill("ERR", Color3.fromRGB(255, 100, 100))
    end
end

local function hopWithCandidate(candidate)
    if not candidate then return false, "no_candidate" end
    if State.IsHopping then return false, "busy" end

    State.IsHopping = true
    State.HopStartTime = os.clock()
    State.CurrentTarget = candidate.id

    setPill("VERIFY", Color3.fromRGB(255, 200, 120))
    setStatus("Verify " .. candidate.id:sub(1, 8) .. "...", Color3.fromRGB(255, 200, 100))

    local ok, verifyResult = pcall(function()
        return verifyServer(candidate.id)
    end)

    if not ok then verifyResult = nil end

    if verifyResult == false then
        addToBlacklist(candidate.id)
        State.IsHopping = false
        State.FailedHops = State.FailedHops + 1
        State.ConsecutiveFailures = State.ConsecutiveFailures + 1
        updateUI()
        setStatus("Server filled · next", Color3.fromRGB(255, 150, 100))
        setPill("RETRY", Color3.fromRGB(255, 150, 100))
        return false, "filled"
    end

    setPill("HOP", Color3.fromRGB(120, 255, 160))
    setStatus("Vào · FPS" .. candidate.fps .. " · " .. candidate.id:sub(1, 8), Color3.fromRGB(120, 255, 160))

    addToBlacklist(candidate.id)

    task.wait(CONFIG.HopPreDelay)

    local teleportOk = fastTeleport(candidate.id)

    if teleportOk then
        State.SuccessfulHops = State.SuccessfulHops + 1
        State.ConsecutiveFailures = 0
        State.IsHopping = false
        updateUI()
        task.wait(CONFIG.PostHopWait)
        return true, "ok"
    else
        State.FailedHops = State.FailedHops + 1
        State.ConsecutiveFailures = State.ConsecutiveFailures + 1
        State.IsHopping = false
        updateUI()
        setStatus("Teleport fail · next", Color3.fromRGB(255, 100, 100))
        setPill("FAIL", Color3.fromRGB(255, 100, 100))
        return false, "teleport_fail"
    end
end

local function hopAttempts(maxAttempts)
    local attempts = 0

    while attempts < maxAttempts do
        attempts = attempts + 1

        if not ScreenGui.Parent then return false end

        if getQueueSize() == 0 then
            setStatus("Queue rỗng · refill", Color3.fromRGB(255, 200, 100))
            setPill("SCAN", Color3.fromRGB(255, 200, 120))

            if not State.IsScanning then
                task.spawn(fillQueue)
            end

            local waited = 0
            while getQueueSize() == 0 and waited < CONFIG.QueueFillTimeout * 10 do
                if not ScreenGui.Parent then return false end
                if not State.IsScanning and getQueueSize() == 0 then
                    task.spawn(fillQueue)
                end
                task.wait(0.1)
                waited = waited + 1
            end

            if getQueueSize() == 0 then
                if getBlacklistCount() > CONFIG.BlacklistResetThreshold - 20 then
                    State.Blacklist = {}
                    setStatus("Reset blacklist", Color3.fromRGB(255, 150, 100))
                    task.wait(1)
                end
                return false
            end
        end

        local candidate = popFromQueue()
        updateUI()

        if candidate then
            local ok, reason = hopWithCandidate(candidate)

            if ok then
                return true
            end
        end

        task.wait(0.1)
    end

    return false
end

local function mainLoop()
    task.wait(1)

    while State.IsRunning and ScreenGui.Parent do
        local count = updatePlayerCount()

        if count == 1 then
            setStatus("Solo · chờ", Color3.fromRGB(120, 255, 160))
            setPill("SOLO", Color3.fromRGB(60, 220, 120))

            if getQueueSize() < CONFIG.QueueTargetSize and not State.IsScanning then
                task.spawn(fillQueue)
            end

            local elapsed = 0
            local someoneJoined = false

            while elapsed < CONFIG.SoloMonitorTimeout do
                if not ScreenGui.Parent then return end
                task.wait(1)
                elapsed = elapsed + 1

                local c = #Players:GetPlayers()
                updatePlayerCount()

                if c > 1 then
                    someoneJoined = true
                    break
                end

                if getQueueSize() < CONFIG.QueueMinSize and not State.IsScanning then
                    task.spawn(fillQueue)
                end
            end

            if someoneJoined then
                setStatus("Có người · hop", Color3.fromRGB(255, 180, 100))
                setPill("PREP", Color3.fromRGB(255, 180, 100))

                hopAttempts(CONFIG.HopAttemptsMax)
            end
            continue
        end

        if count == 2 then
            setStatus("2ng · tìm 1ng", Color3.fromRGB(255, 200, 100))
            setPill("HUNT", Color3.fromRGB(255, 200, 120))

            if getQueueSize() < CONFIG.QueueTargetSize and not State.IsScanning then
                task.spawn(fillQueue)
            end

            hopAttempts(CONFIG.HopAttemptsMax)
            continue
        end

        setStatus("Server " .. count .. "ng · chờ 3s", Color3.fromRGB(255, 180, 100))
        setPill("WAIT", Color3.fromRGB(255, 180, 100))

        for i = CONFIG.CountdownStart, 1, -1 do
            if not ScreenGui.Parent then return end
            local c = #Players:GetPlayers()
            if c <= 1 then break end
            setStatus("Hop sau " .. i .. "s · " .. c .. "ng", Color3.fromRGB(255, 180, 100))
            task.wait(1)
        end

        if #Players:GetPlayers() <= 1 then continue end

        if getQueueSize() < CONFIG.QueueTargetSize and not State.IsScanning then
            task.spawn(fillQueue)
        end

        hopAttempts(CONFIG.HopAttemptsMax)
    end
end

local dragging = false
local dragStart = nil
local startPos = nil
local dragMoved = false

TopBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragMoved = false
        dragStart = input.Position
        startPos = Main.Position
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if not dragging then return end
    if input.UserInputType ~= Enum.UserInputType.MouseMovement
        and input.UserInputType ~= Enum.UserInputType.Touch then return end
    local d = input.Position - dragStart
    if math.abs(d.X) > 5 or math.abs(d.Y) > 5 then
        dragMoved = true
    end
    if dragMoved then
        Main.Position = UDim2.new(
            startPos.X.Scale, startPos.X.Offset + d.X,
            startPos.Y.Scale, startPos.Y.Offset + d.Y
        )
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        dragging = false
    end
end)

Players.PlayerAdded:Connect(function(plr)
    if plr == LocalPlayer then return end
    task.wait(0.2)
    updatePlayerCount()
    if getQueueSize() < CONFIG.QueueTargetSize and not State.IsScanning then
        task.spawn(fillQueue)
    end
end)

Players.PlayerRemoving:Connect(function()
    task.wait(0.4)
    updatePlayerCount()
end)

updatePlayerCount()
updateUI()
setStatus("Đang chạy", Color3.fromRGB(120, 255, 160))
setPill("ON", Color3.fromRGB(60, 220, 120))

task.spawn(mainLoop)

task.spawn(function()
    while ScreenGui.Parent do
        task.wait(3)

        if State.IsScanning and (os.clock() - State.ScanStartTime) > CONFIG.ScanTimeout then
            State.IsScanning = false
            setStatus("Scan timeout · reset", Color3.fromRGB(255, 150, 100))
        end

        if State.IsHopping and (os.clock() - State.HopStartTime) > CONFIG.HopTimeout then
            State.IsHopping = false
            setStatus("Hop timeout · reset", Color3.fromRGB(255, 150, 100))
        end

        if State.ConsecutiveFailures >= State.MaxConsecutiveFailures then
            State.Blacklist = {}
            State.ConsecutiveFailures = 0
            setStatus("Reset blacklist", Color3.fromRGB(255, 150, 100))
        end
    end
end)

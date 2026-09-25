local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local CoreGui = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

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

local Blacklist = {}
local Queue = nil
local QueueCandidates = {}
local IsScanning = false
local ScanStartTime = 0
local IsHopping = false
local IsRunning = true
local TotalScans = 0
local TotalHops = 0
local FailedHops = 0
local ConsecutiveFailures = 0

local CONFIG = {
    ScanPages = 12,
    ScanPassDelay = 2.5,
    ScanConfirmDelay = 1.5,
    ScanPageDelay = 0.02,
    VerifyMaxPages = 40,
    HopCountdown = 3,
    PreTeleportDelay = 0.3,
    PostHopWait = 3,
    MaxHopAttempts = 8,
    ScanTimeout = 40,
    QueueFillTimeout = 20,
    QueueSize = 3,
}

local function safeNum(v, default)
    local n = tonumber(v)
    if type(n) ~= "number" then return default end
    if n ~= n then return default end
    return n
end

local function addToBlacklist(id)
    if type(id) ~= "string" then return end
    Blacklist[id] = true
    local count = 0
    for _ in pairs(Blacklist) do count = count + 1 end
    if count > 80 then
        Blacklist = {}
    end
end

local function isBlacklisted(id)
    if type(id) ~= "string" then return true end
    return Blacklist[id] == true
end

local function getBlacklistCount()
    local c = 0
    for _ in pairs(Blacklist) do c = c + 1 end
    return c
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
Main.Size = UDim2.new(0, 230, 0, 195)
Main.Position = UDim2.new(0, 20, 0.5, -97)
Main.BackgroundColor3 = Color3.fromRGB(13, 15, 22)
Main.BorderSizePixel = 0
Main.Active = true
Main.ClipsDescendants = true
Main.Parent = ScreenGui

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 14)
MainCorner.Parent = Main

local MainGrad = Instance.new("UIGradient")
MainGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(13, 15, 22)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(18, 14, 28))
})
MainGrad.Rotation = 135
MainGrad.Parent = Main

local Border = Instance.new("UIStroke")
Border.Thickness = 1.5
Border.Transparency = 0.15
Border.Parent = Main

local BorderGrad = Instance.new("UIGradient")
BorderGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(120, 80, 255)),
    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(80, 180, 255)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 100, 255))
})
BorderGrad.Rotation = 45
BorderGrad.Parent = Border

task.spawn(function()
    while ScreenGui.Parent do
        BorderGrad.Rotation = BorderGrad.Rotation + 2
        task.wait(0.05)
    end
end)

local Header = Instance.new("Frame")
Header.Size = UDim2.new(1, 0, 0, 42)
Header.BackgroundTransparency = 1
Header.Parent = Main

local LogoBox = Instance.new("Frame")
LogoBox.Size = UDim2.new(0, 30, 0, 30)
LogoBox.Position = UDim2.new(0, 12, 0, 6)
LogoBox.BackgroundColor3 = Color3.fromRGB(40, 30, 70)
LogoBox.BorderSizePixel = 0
LogoBox.Parent = Header

local LogoCorner = Instance.new("UICorner")
LogoCorner.CornerRadius = UDim.new(0, 9)
LogoCorner.Parent = LogoBox

local LogoGrad = Instance.new("UIGradient")
LogoGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(120, 80, 255)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(60, 180, 255))
})
LogoGrad.Rotation = 45
LogoGrad.Parent = LogoBox

local LogoIcon = Instance.new("TextLabel")
LogoIcon.Size = UDim2.new(1, 0, 1, 0)
LogoIcon.BackgroundTransparency = 1
LogoIcon.Text = "⚡"
LogoIcon.TextColor3 = Color3.fromRGB(255, 255, 255)
LogoIcon.Font = Enum.Font.GothamBold
LogoIcon.TextSize = 16
LogoIcon.Parent = LogoBox

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, -130, 0, 16)
Title.Position = UDim2.new(0, 50, 0, 9)
Title.BackgroundTransparency = 1
Title.Text = "PHANTOM"
Title.TextColor3 = Color3.fromRGB(240, 245, 255)
Title.Font = Enum.Font.GothamBold
Title.TextSize = 13
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = Header

local Subtitle = Instance.new("TextLabel")
Subtitle.Size = UDim2.new(1, -130, 0, 11)
Subtitle.Position = UDim2.new(0, 50, 0, 24)
Subtitle.BackgroundTransparency = 1
Subtitle.Text = "auto · queue · verify"
Subtitle.TextColor3 = Color3.fromRGB(130, 140, 180)
Subtitle.Font = Enum.Font.Gotham
Subtitle.TextSize = 9
Subtitle.TextXAlignment = Enum.TextXAlignment.Left
Subtitle.Parent = Header

local Pill = Instance.new("Frame")
Pill.Size = UDim2.new(0, 64, 0, 22)
Pill.Position = UDim2.new(1, -76, 0, 10)
Pill.BackgroundColor3 = Color3.fromRGB(24, 40, 30)
Pill.BorderSizePixel = 0
Pill.Parent = Header

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
        game:GetService("TweenService"):Create(PillPulse, info, {
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

local PlayersCard = makeCard(54, 34)
local FoundCard = makeCard(92, 28)
local QueueCard = makeCard(124, 28)

local PlayersIcon = Instance.new("TextLabel")
PlayersIcon.Size = UDim2.new(0, 28, 1, 0)
PlayersIcon.Position = UDim2.new(0, 8, 0, 0)
PlayersIcon.BackgroundTransparency = 1
PlayersIcon.Text = "👥"
PlayersIcon.TextSize = 13
PlayersIcon.Parent = PlayersCard

local PlayersLabel = Instance.new("TextLabel")
PlayersLabel.Size = UDim2.new(1, -100, 1, 0)
PlayersLabel.Position = UDim2.new(0, 36, 0, 0)
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
FoundLabel.Size = UDim2.new(1, -100, 1, 0)
FoundLabel.Position = UDim2.new(0, 36, 0, 0)
FoundLabel.BackgroundTransparency = 1
FoundLabel.Text = "Server 1 người"
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
QueueLabel.Size = UDim2.new(1, -100, 1, 0)
QueueLabel.Position = UDim2.new(0, 36, 0, 0)
QueueLabel.BackgroundTransparency = 1
QueueLabel.Text = "Queue"
QueueLabel.TextColor3 = Color3.fromRGB(150, 160, 190)
QueueLabel.Font = Enum.Font.Gotham
QueueLabel.TextSize = 10
QueueLabel.TextXAlignment = Enum.TextXAlignment.Left
QueueLabel.Parent = QueueCard

local QueueValue = Instance.new("TextLabel")
QueueValue.Size = UDim2.new(0, 90, 1, 0)
QueueValue.Position = UDim2.new(1, -98, 0, 0)
QueueValue.BackgroundTransparency = 1
QueueValue.Text = "--"
QueueValue.TextColor3 = Color3.fromRGB(140, 150, 180)
QueueValue.Font = Enum.Font.Code
QueueValue.TextSize = 10
QueueValue.TextXAlignment = Enum.TextXAlignment.Right
QueueValue.Parent = QueueCard

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
    StatusText.Text = tostring(text or "")
    if color then StatusText.TextColor3 = color end
end

local function setPill(text, color)
    PillText.Text = tostring(text or "ON")
    if color then
        PillText.TextColor3 = color
        PillDot.BackgroundColor3 = color
        PillPulse.BackgroundColor3 = color
        PillStroke.Color = color
    end
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

local function updateQueueUI()
    local count = #QueueCandidates
    if Queue then
        QueueValue.Text = string.format("1ng·%d·%d", Queue.fps, Queue.ping)
        QueueValue.TextColor3 = Color3.fromRGB(120, 255, 160)
    elseif count > 0 then
        QueueValue.Text = count .. " standby"
        QueueValue.TextColor3 = Color3.fromRGB(200, 200, 100)
    else
        QueueValue.Text = "--"
        QueueValue.TextColor3 = Color3.fromRGB(140, 150, 180)
    end
end

Players.PlayerAdded:Connect(function() task.wait(0.2) updatePlayerCount() end)
Players.PlayerRemoving:Connect(function() task.wait(0.4) updatePlayerCount() end)

local function requestPage(cursor)
    if not http then return nil end
    local url = string.format(
        "https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100&cursor=%s",
        PLACE_ID, cursor or ""
    )
    local ok, res = pcall(function()
        return http({ Url = url, Method = "GET", Headers = { ["Accept"] = "application/json" } })
    end)
    if not ok or not res then return nil end
    local body = res.Body or res.body
    if type(body) ~= "string" or #body == 0 then return nil end
    local ok2, data = pcall(function()
        return HttpService:JSONDecode(body)
    end)
    if not ok2 or type(data) ~= "table" then return nil end
    return data
end

local function scanPass(maxPlayers, maxPages)
    local result = {}
    local cursor = ""
    local pages = 0

    while pages < maxPages do
        local data = requestPage(cursor)
        if not data or type(data.data) ~= "table" then break end
        local cnt = 0
        for _, s in ipairs(data.data) do
            if type(s) == "table" then
                cnt = cnt + 1
                local pc = safeNum(s.playing, 0)
                local id = s.id
                if pc >= 1 and pc <= maxPlayers then
                    if type(id) == "string" and id ~= JOB_ID and not isBlacklisted(id) then
                        result[id] = {
                            id = id,
                            ping = safeNum(s.ping, 999),
                            fps = safeNum(s.fps, 60),
                            playing = pc,
                            max = safeNum(s.maxPlayers, 12),
                            stability = 1,
                            score = 0,
                        }
                    end
                end
            end
        end
        if cnt == 0 then break end
        cursor = data.nextPageCursor
        if type(cursor) ~= "string" or cursor == "" or cursor == "null" then break end
        pages = pages + 1
        if CONFIG.ScanPageDelay > 0 then
            task.wait(CONFIG.ScanPageDelay)
        end
    end

    return result
end

local function calculateScore(s)
    local playerScore = 0
    if s.playing == 1 then playerScore = 1000
    elseif s.playing == 2 then playerScore = 200
    elseif s.playing == 3 then playerScore = 50 end
    local fpsScore = math.max(0, 60 - s.fps) * 1.5
    local pingScore = math.min(s.ping, 500) / 5
    local stabilityScore = s.stability * 80
    return playerScore + fpsScore + pingScore + stabilityScore
end

local function verifyServer(jobId)
    if type(jobId) ~= "string" then return nil end
    local cursor = ""
    local pages = 0
    while pages < CONFIG.VerifyMaxPages do
        local data = requestPage(cursor)
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

local function fillQueue()
    if Queue then return end
    if IsScanning then
        if (os.clock() - ScanStartTime) > CONFIG.ScanTimeout then
            IsScanning = false
        else
            return
        end
    end

    IsScanning = true
    ScanStartTime = os.clock()
    TotalScans = TotalScans + 1

    setPill("SCAN", Color3.fromRGB(255, 200, 120))
    setStatus("Đang dò server...", Color3.fromRGB(255, 200, 100))

    if not http then
        IsScanning = false
        setStatus("Lỗi HTTP", Color3.fromRGB(255, 100, 100))
        setPill("OFF", Color3.fromRGB(255, 100, 100))
        return
    end

    local ok, err = pcall(function()
        local pass1 = scanPass(2, CONFIG.ScanPages)
        local count1 = 0
        for _ in pairs(pass1) do count1 = count1 + 1 end

        FoundValue.Text = tostring(count1)

        if count1 == 0 then
            IsScanning = false
            setStatus("Không có server 1-2 người", Color3.fromRGB(255, 150, 100))
            setPill("WAIT", Color3.fromRGB(255, 180, 100))
            return
        end

        setStatus("Pass 1: " .. count1 .. " · phân tích", Color3.fromRGB(255, 200, 100))
        task.wait(CONFIG.ScanPassDelay)

        local pass2 = scanPass(2, CONFIG.ScanPages)

        local stable = {}
        for id, s in pairs(pass2) do
            if pass1[id] then
                s.stability = 2
                if s.playing == pass1[id].playing then
                    s.stability = 3
                end
                table.insert(stable, s)
            end
        end

        if #stable == 0 then
            for id, s in pairs(pass1) do
                s.stability = 1
                table.insert(stable, s)
            end
        end

        setStatus("Đang xác nhận...", Color3.fromRGB(255, 200, 100))
        task.wait(CONFIG.ScanConfirmDelay)

        for _, s in ipairs(stable) do
            s.score = calculateScore(s)
        end

        table.sort(stable, function(a, b)
            if a.playing ~= b.playing then
                return a.playing < b.playing
            end
            return a.score > b.score
        end)

        IsScanning = false

        local onePlayer = {}
        for _, s in ipairs(stable) do
            if s.playing == 1 then
                table.insert(onePlayer, s)
            end
        end

        local pickFrom = onePlayer
        if #pickFrom == 0 then
            pickFrom = stable
        end

        if #pickFrom == 0 then
            setStatus("Không có server!", Color3.fromRGB(255, 120, 120))
            setPill("FAIL", Color3.fromRGB(255, 120, 120))
            return
        end

        QueueCandidates = {}

        local topN = math.min(CONFIG.QueueSize, #pickFrom)
        for i = 1, topN do
            table.insert(QueueCandidates, pickFrom[i])
        end

        Queue = QueueCandidates[1]
        updateQueueUI()

        setStatus("Queue sẵn sàng · " .. #pickFrom .. " server", Color3.fromRGB(120, 255, 160))
        setPill("READY", Color3.fromRGB(60, 220, 120))
    end)

    IsScanning = false

    if not ok then
        local msg = tostring(err or "unknown")
        if #msg > 32 then msg = msg:sub(1, 32) end
        setStatus("Lỗi · " .. msg, Color3.fromRGB(255, 100, 100))
        setPill("ERR", Color3.fromRGB(255, 100, 100))
    end
end

local function promoteQueue()
    if Queue then return end
    if #QueueCandidates > 0 then
        table.remove(QueueCandidates, 1)
        if #QueueCandidates > 0 then
            Queue = QueueCandidates[1]
        end
        updateQueueUI()
    end
end

local function hopWithVerify()
    if not Queue then return false end
    if IsHopping then return false end

    IsHopping = true

    setPill("VERIFY", Color3.fromRGB(255, 200, 120))
    setStatus("Xác minh server...", Color3.fromRGB(255, 200, 100))

    local target = Queue

    local ok, verifyResult = pcall(function()
        return verifyServer(target.id)
    end)

    if not ok then verifyResult = nil end

    if verifyResult == false then
        Queue = nil
        addToBlacklist(target.id)
        promoteQueue()
        updateQueueUI()
        IsHopping = false
        FailedHops = FailedHops + 1
        ConsecutiveFailures = ConsecutiveFailures + 1
        setStatus("Server bị fill · đổi queue", Color3.fromRGB(255, 150, 100))
        setPill("RETRY", Color3.fromRGB(255, 150, 100))
        return false
    end

    Queue = nil
    promoteQueue()
    updateQueueUI()

    setPill("HOP", Color3.fromRGB(120, 255, 160))
    setStatus("Vào " .. target.playing .. "ng · FPS" .. target.fps, Color3.fromRGB(120, 255, 160))

    addToBlacklist(target.id)

    task.wait(CONFIG.PreTeleportDelay)

    local teleportOk = fastTeleport(target.id)

    if teleportOk then
        TotalHops = TotalHops + 1
        ConsecutiveFailures = 0
        IsHopping = false
        task.wait(CONFIG.PostHopWait)
        return true
    else
        FailedHops = FailedHops + 1
        ConsecutiveFailures = ConsecutiveFailures + 1
        IsHopping = false
        setStatus("Teleport fail", Color3.fromRGB(255, 100, 100))
        setPill("FAIL", Color3.fromRGB(255, 100, 100))
        return false
    end
end

local function waitForQueue(timeout)
    local start = os.clock()
    while not Queue do
        if not ScreenGui.Parent then return false end
        if (os.clock() - start) > timeout then return false end
        if not IsScanning then
            task.spawn(fillQueue)
        end
        task.wait(0.3)
    end
    return true
end

local function safeHopLoop(maxAttempts)
    if not waitForQueue(CONFIG.QueueFillTimeout) then return false end

    local attempts = 0
    while attempts < maxAttempts do
        attempts = attempts + 1

        if not ScreenGui.Parent then return false end
        if #Players:GetPlayers() <= 1 then return false end

        if Queue then
            if hopWithVerify() then return true end
        end

        if not Queue then
            if not waitForQueue(CONFIG.QueueFillTimeout) then
                if getBlacklistCount() > 60 then
                    Blacklist = {}
                    task.wait(2)
                end
                break
            end
        end

        task.wait(0.2)
    end

    return false
end

local function mainLoop()
    task.wait(1)

    while IsRunning and ScreenGui.Parent do
        local count = updatePlayerCount()

        if count == 1 then
            setStatus("Solo · 1 người", Color3.fromRGB(120, 255, 160))
            setPill("SOLO", Color3.fromRGB(60, 220, 120))

            if not Queue and not IsScanning then
                task.spawn(fillQueue)
            end

            local elapsed = 0
            local someoneJoined = false

            while elapsed < 120 do
                if not ScreenGui.Parent then return end
                task.wait(1)
                elapsed = elapsed + 1

                local c = #Players:GetPlayers()
                updatePlayerCount()

                if c > 1 then
                    someoneJoined = true
                    break
                end

                if not Queue and not IsScanning then
                    task.spawn(fillQueue)
                end
            end

            if someoneJoined then
                setStatus("Có người vào · chuẩn bị hop", Color3.fromRGB(255, 180, 100))
                setPill("PREP", Color3.fromRGB(255, 180, 100))

                if waitForQueue(CONFIG.QueueFillTimeout) then
                    safeHopLoop(CONFIG.MaxHopAttempts)
                end
            end
            continue
        end

        if count == 2 then
            setStatus("Server 2ng · tìm 1ng", Color3.fromRGB(255, 200, 100))
            setPill("HUNT", Color3.fromRGB(255, 200, 120))

            if not Queue and not IsScanning then
                task.spawn(fillQueue)
            end

            if waitForQueue(CONFIG.QueueFillTimeout) then
                safeHopLoop(CONFIG.MaxHopAttempts)
            else
                if not IsScanning then
                    task.spawn(fillQueue)
                end
                task.wait(1)
            end
            continue
        end

        setStatus("Server " .. count .. "ng · chờ 3s", Color3.fromRGB(255, 180, 100))
        setPill("WAIT", Color3.fromRGB(255, 180, 100))

        for i = 3, 1, -1 do
            if not ScreenGui.Parent then return end
            local c = #Players:GetPlayers()
            if c <= 1 then break end
            setStatus("Hop sau " .. i .. "s · " .. c .. "ng", Color3.fromRGB(255, 180, 100))
            task.wait(1)
        end

        if #Players:GetPlayers() <= 1 then continue end

        if not Queue and not IsScanning then
            task.spawn(fillQueue)
        end

        if waitForQueue(CONFIG.QueueFillTimeout) then
            safeHopLoop(CONFIG.MaxHopAttempts)
        else
            Blacklist = {}
            setStatus("Reset · thử lại", Color3.fromRGB(255, 150, 100))
            task.wait(1)
        end
    end
end

local dragging = false
local dragStart = nil
local startPos = nil
local dragMoved = false

Header.InputBegan:Connect(function(input)
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

updatePlayerCount()
updateQueueUI()
setStatus("Đang chạy", Color3.fromRGB(120, 255, 160))
setPill("ON", Color3.fromRGB(60, 220, 120))

task.spawn(mainLoop)

task.spawn(function()
    while ScreenGui.Parent do
        task.wait(5)

        if IsScanning and (os.clock() - ScanStartTime) > CONFIG.ScanTimeout then
            IsScanning = false
            setStatus("Scan timeout · reset", Color3.fromRGB(255, 150, 100))
        end

        if ConsecutiveFailures >= 6 then
            Blacklist = {}
            ConsecutiveFailures = 0
            setStatus("Reset blacklist", Color3.fromRGB(255, 150, 100))
        end
    end
end)

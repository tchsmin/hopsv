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
    return nil
end
local http = getHttp()

local CONFIG = {
    PageDelay = 0,
    PassDelay = 0.5,
    ConfirmDelay = 0.3,
    PreTeleportDelay = 0.1,
    MaxPages = 25,
    ParallelBranches = 5,
    AutoHopDelay = 8,
}

local Blacklist = {}
local IsScanning = false
local IsHopping = false
local AutoHopEnabled = true
local CurrentTargetPlayers = nil
local MonitorConn = nil
local ScanCount = 0
local TotalScans = 0
local LastFound = nil

if CoreGui:FindFirstChild("HopUI") then CoreGui.HopUI:Destroy() end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "HopUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.IgnoreGuiInset = true
ScreenGui.DisplayOrder = 999999
ScreenGui.Parent = CoreGui

local Main = Instance.new("Frame")
Main.Size = UDim2.new(0, 240, 0, 180)
Main.Position = UDim2.new(0, 20, 0.5, -90)
Main.BackgroundColor3 = Color3.fromRGB(15, 17, 24)
Main.BorderSizePixel = 0
Main.Active = true
Main.ClipsDescendants = true
Main.Parent = ScreenGui

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 16)
MainCorner.Parent = Main

local MainStroke = Instance.new("UIStroke")
MainStroke.Thickness = 1.2
MainStroke.Transparency = 0.2
MainStroke.Parent = Main

local StrokeGradient = Instance.new("UIGradient")
StrokeGradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(80, 200, 255)),
    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(140, 100, 255)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 100, 180))
})
StrokeGradient.Rotation = 45
StrokeGradient.Parent = MainStroke

local Glow = Instance.new("Frame")
Glow.Size = UDim2.new(1, 20, 1, 20)
Glow.Position = UDim2.new(0, -10, 0, -10)
Glow.BackgroundColor3 = Color3.fromRGB(100, 140, 255)
Glow.BackgroundTransparency = 0.9
Glow.BorderSizePixel = 0
Glow.ZIndex = 0
Glow.Parent = Main

local GlowCorner = Instance.new("UICorner")
GlowCorner.CornerRadius = UDim.new(0, 24)
GlowCorner.Parent = Glow

local Header = Instance.new("Frame")
Header.Size = UDim2.new(1, 0, 0, 44)
Header.BackgroundTransparency = 1
Header.Parent = Main

local LogoCircle = Instance.new("Frame")
LogoCircle.Size = UDim2.new(0, 26, 0, 26)
LogoCircle.Position = UDim2.new(0, 14, 0, 11)
LogoCircle.BackgroundColor3 = Color3.fromRGB(40, 45, 60)
LogoCircle.BorderSizePixel = 0
LogoCircle.Parent = Header

local LogoCorner = Instance.new("UICorner")
LogoCorner.CornerRadius = UDim.new(1, 0)
LogoCorner.Parent = LogoCircle

local LogoGradient = Instance.new("UIGradient")
LogoGradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(80, 200, 255)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(140, 100, 255))
})
LogoGradient.Rotation = 45
LogoGradient.Parent = LogoCircle

local LogoText = Instance.new("TextLabel")
LogoText.Size = UDim2.new(1, 0, 1, 0)
LogoText.BackgroundTransparency = 1
LogoText.Text = "⚡"
LogoText.TextColor3 = Color3.fromRGB(255, 255, 255)
LogoText.Font = Enum.Font.GothamBold
LogoText.TextSize = 14
LogoText.Parent = LogoCircle

local TitleText = Instance.new("TextLabel")
TitleText.Size = UDim2.new(1, -110, 0, 16)
TitleText.Position = UDim2.new(0, 48, 0, 12)
TitleText.BackgroundTransparency = 1
TitleText.Text = "SERVER HUNTER"
TitleText.TextColor3 = Color3.fromRGB(240, 245, 255)
TitleText.Font = Enum.Font.GothamBold
TitleText.TextSize = 12
TitleText.TextXAlignment = Enum.TextXAlignment.Left
TitleText.Parent = Header

local SubText = Instance.new("TextLabel")
SubText.Size = UDim2.new(1, -110, 0, 12)
SubText.Position = UDim2.new(0, 48, 0, 27)
SubText.BackgroundTransparency = 1
SubText.Text = "auto hop · 1 người"
SubText.TextColor3 = Color3.fromRGB(120, 140, 180)
SubText.Font = Enum.Font.Gotham
SubText.TextSize = 9
SubText.TextXAlignment = Enum.TextXAlignment.Left
SubText.Parent = Header

local StatusPill = Instance.new("Frame")
StatusPill.Size = UDim2.new(0, 58, 0, 20)
StatusPill.Position = UDim2.new(1, -70, 0, 12)
StatusPill.BackgroundColor3 = Color3.fromRGB(30, 40, 35)
StatusPill.BorderSizePixel = 0
StatusPill.Parent = Header

local PillCorner = Instance.new("UICorner")
PillCorner.CornerRadius = UDim.new(1, 0)
PillCorner.Parent = StatusPill

local PillDot = Instance.new("Frame")
PillDot.Size = UDim2.new(0, 6, 0, 6)
PillDot.Position = UDim2.new(0, 8, 0.5, -3)
PillDot.BackgroundColor3 = Color3.fromRGB(60, 220, 120)
PillDot.BorderSizePixel = 0
PillDot.Parent = StatusPill

local PillDotCorner = Instance.new("UICorner")
PillDotCorner.CornerRadius = UDim.new(1, 0)
PillDotCorner.Parent = PillDot

local PillPulse = Instance.new("Frame")
PillPulse.Size = UDim2.new(1, 0, 1, 0)
PillPulse.BackgroundColor3 = Color3.fromRGB(60, 220, 120)
PillPulse.BackgroundTransparency = 0.7
PillPulse.BorderSizePixel = 0
PillPulse.Parent = PillDot

local PulseCorner = Instance.new("UICorner")
PulseCorner.CornerRadius = UDim.new(1, 0)
PulseCorner.Parent = PillPulse

local PillText = Instance.new("TextLabel")
PillText.Size = UDim2.new(1, -20, 1, 0)
PillText.Position = UDim2.new(0, 18, 0, 0)
PillText.BackgroundTransparency = 1
PillText.Text = "LIVE"
PillText.TextColor3 = Color3.fromRGB(140, 255, 180)
PillText.Font = Enum.Font.GothamBold
PillText.TextSize = 9
PillText.TextXAlignment = Enum.TextXAlignment.Left
PillText.Parent = StatusPill

task.spawn(function()
    while ScreenGui.Parent do
        TweenService:Create(PillPulse, TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
            BackgroundTransparency = 1,
            Size = UDim2.new(3, 0, 3, 0),
            Position = UDim2.new(-1, 0, -1, 0)
        }):Play()
        task.wait(1.2)
        PillPulse.BackgroundTransparency = 0.7
        PillPulse.Size = UDim2.new(1, 0, 1, 0)
        PillPulse.Position = UDim2.new(0, 0, 0, 0)
    end
end)

local StatsRow = Instance.new("Frame")
StatsRow.Size = UDim2.new(1, -24, 0, 32)
StatsRow.Position = UDim2.new(0, 12, 0, 50)
StatsRow.BackgroundTransparency = 1
StatsRow.Parent = Main

local function createStatCard(xPos, icon, label)
    local card = Instance.new("Frame")
    card.Size = UDim2.new(0.5, -4, 1, 0)
    card.Position = UDim2.new(xPos, 0, 0, 0)
    card.BackgroundColor3 = Color3.fromRGB(24, 27, 38)
    card.BorderSizePixel = 0
    card.Parent = StatsRow

    local cc = Instance.new("UICorner")
    cc.CornerRadius = UDim.new(0, 8)
    cc.Parent = card

    local iconLbl = Instance.new("TextLabel")
    iconLbl.Size = UDim2.new(0, 24, 1, 0)
    iconLbl.Position = UDim2.new(0, 6, 0, 0)
    iconLbl.BackgroundTransparency = 1
    iconLbl.Text = icon
    iconLbl.TextColor3 = Color3.fromRGB(100, 160, 255)
    iconLbl.Font = Enum.Font.GothamBold
    iconLbl.TextSize = 13
    iconLbl.Parent = card

    local valueLbl = Instance.new("TextLabel")
    valueLbl.Size = UDim2.new(1, -36, 0, 14)
    valueLbl.Position = UDim2.new(0, 34, 0, 4)
    valueLbl.BackgroundTransparency = 1
    valueLbl.Text = "0"
    valueLbl.TextColor3 = Color3.fromRGB(240, 245, 255)
    valueLbl.Font = Enum.Font.GothamBold
    valueLbl.TextSize = 12
    valueLbl.TextXAlignment = Enum.TextXAlignment.Left
    valueLbl.Parent = card

    local tagLbl = Instance.new("TextLabel")
    tagLbl.Size = UDim2.new(1, -36, 0, 10)
    tagLbl.Position = UDim2.new(0, 34, 0, 18)
    tagLbl.BackgroundTransparency = 1
    tagLbl.Text = label
    tagLbl.TextColor3 = Color3.fromRGB(120, 140, 180)
    tagLbl.Font = Enum.Font.Gotham
    tagLbl.TextSize = 8
    tagLbl.TextXAlignment = Enum.TextXAlignment.Left
    tagLbl.Parent = card

    return valueLbl
end

local PlayerValue = createStatCard(0, "👥", "PLAYERS")
local ScanValue = createStatCard(0.5, "🎯", "FOUND")

local StatusBar = Instance.new("Frame")
StatusBar.Size = UDim2.new(1, -24, 0, 36)
StatusBar.Position = UDim2.new(0, 12, 0, 88)
StatusBar.BackgroundColor3 = Color3.fromRGB(24, 27, 38)
StatusBar.BorderSizePixel = 0
StatusBar.Parent = Main

local StatusBarCorner = Instance.new("UICorner")
StatusBarCorner.CornerRadius = UDim.new(0, 8)
StatusBarCorner.Parent = StatusBar

local StatusIndicator = Instance.new("Frame")
StatusIndicator.Size = UDim2.new(0, 3, 1, -12)
StatusIndicator.Position = UDim2.new(0, 6, 0, 6)
StatusIndicator.BackgroundColor3 = Color3.fromRGB(60, 220, 120)
StatusIndicator.BorderSizePixel = 0
StatusIndicator.Parent = StatusBar

local IndCorner = Instance.new("UICorner")
IndCorner.CornerRadius = UDim.new(1, 0)
IndCorner.Parent = StatusIndicator

local StatusText = Instance.new("TextLabel")
StatusText.Size = UDim2.new(1, -20, 1, 0)
StatusText.Position = UDim2.new(0, 16, 0, 0)
StatusText.BackgroundTransparency = 1
StatusText.Text = "Đang khởi động..."
StatusText.TextColor3 = Color3.fromRGB(220, 230, 255)
StatusText.Font = Enum.Font.GothamBold
StatusText.TextSize = 10
StatusText.TextXAlignment = Enum.TextXAlignment.Left
StatusText.Parent = StatusBar

local TargetBar = Instance.new("Frame")
TargetBar.Size = UDim2.new(1, -24, 0, 20)
TargetBar.Position = UDim2.new(0, 12, 0, 128)
TargetBar.BackgroundColor3 = Color3.fromRGB(24, 27, 38)
TargetBar.BorderSizePixel = 0
TargetBar.Parent = Main

local TargetBarCorner = Instance.new("UICorner")
TargetBarCorner.CornerRadius = UDim.new(0, 6)
TargetBarCorner.Parent = TargetBar

local TargetIcon = Instance.new("TextLabel")
TargetIcon.Size = UDim2.new(0, 22, 1, 0)
TargetIcon.Position = UDim2.new(0, 4, 0, 0)
TargetIcon.BackgroundTransparency = 1
TargetIcon.Text = "◎"
TargetIcon.TextColor3 = Color3.fromRGB(120, 220, 180)
TargetIcon.Font = Enum.Font.GothamBold
TargetIcon.TextSize = 12
TargetIcon.Parent = TargetBar

local TargetText = Instance.new("TextLabel")
TargetText.Size = UDim2.new(1, -30, 1, 0)
TargetText.Position = UDim2.new(0, 24, 0, 0)
TargetText.BackgroundTransparency = 1
TargetText.Text = "Mục tiêu: 1 người (2/2)"
TargetText.TextColor3 = Color3.fromRGB(120, 220, 180)
TargetText.Font = Enum.Font.GothamBold
TargetText.TextSize = 9
TargetText.TextXAlignment = Enum.TextXAlignment.Left
TargetText.Parent = TargetBar

local ButtonRow = Instance.new("Frame")
ButtonRow.Size = UDim2.new(1, -24, 0, 28)
ButtonRow.Position = UDim2.new(0, 12, 0, 152)
ButtonRow.BackgroundTransparency = 1
ButtonRow.Parent = Main

local HopBtn = Instance.new("TextButton")
HopBtn.Size = UDim2.new(0.6, -3, 1, 0)
HopBtn.Position = UDim2.new(0, 0, 0, 0)
HopBtn.BackgroundColor3 = Color3.fromRGB(60, 140, 220)
HopBtn.Text = "🚀  HOP NOW"
HopBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
HopBtn.Font = Enum.Font.GothamBold
HopBtn.TextSize = 11
HopBtn.AutoButtonColor = false
HopBtn.Parent = ButtonRow

local HopCorner = Instance.new("UICorner")
HopCorner.CornerRadius = UDim.new(0, 8)
HopCorner.Parent = HopBtn

local HopGradient = Instance.new("UIGradient")
HopGradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(80, 160, 255)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(120, 100, 255))
})
HopGradient.Rotation = 0
HopGradient.Parent = HopBtn

local AutoBtn = Instance.new("TextButton")
AutoBtn.Size = UDim2.new(0.4, -3, 1, 0)
AutoBtn.Position = UDim2.new(0.6, 3, 0, 0)
AutoBtn.BackgroundColor3 = Color3.fromRGB(40, 45, 60)
AutoBtn.Text = "AUTO ON"
AutoBtn.TextColor3 = Color3.fromRGB(140, 255, 180)
AutoBtn.Font = Enum.Font.GothamBold
AutoBtn.TextSize = 10
AutoBtn.AutoButtonColor = false
AutoBtn.Parent = ButtonRow

local AutoCorner = Instance.new("UICorner")
AutoCorner.CornerRadius = UDim.new(0, 8)
AutoCorner.Parent = AutoBtn

local AutoStroke = Instance.new("UIStroke")
AutoStroke.Color = Color3.fromRGB(60, 220, 120)
AutoStroke.Thickness = 1
AutoStroke.Transparency = 0.3
AutoStroke.Parent = AutoBtn

local SPINNER = {"◐", "◓", "◑", "◒"}
local spinIndex = 1

local function setStatus(text, color)
    StatusText.Text = text
    if color then StatusText.TextColor3 = color end
end

local function setIndicator(color)
    StatusIndicator.BackgroundColor3 = color
end

local function setTarget(text, color)
    TargetText.Text = text
    if color then TargetText.TextColor3 = color end
end

local function setDot(color)
    PillDot.BackgroundColor3 = color
    PillPulse.BackgroundColor3 = color
end

local function updatePlayerCount()
    local count = #Players:GetPlayers()
    PlayerValue.Text = tostring(count)
    if count <= 2 then
        PlayerValue.TextColor3 = Color3.fromRGB(120, 255, 160)
    elseif count <= 4 then
        PlayerValue.TextColor3 = Color3.fromRGB(255, 220, 120)
    else
        PlayerValue.TextColor3 = Color3.fromRGB(255, 120, 120)
    end
    return count
end

task.spawn(function()
    while ScreenGui.Parent do
        spinIndex = spinIndex + 1
        if spinIndex > #SPINNER then spinIndex = 1 end
        if IsScanning and not IsHopping then
            StatusText.Text = SPINNER[spinIndex] .. " Đang quét server..."
        end
        task.wait(0.15)
    end
end)

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
    if type(body) ~= "string" then return nil end
    local ok2, data = pcall(function()
        return HttpService:JSONDecode(body)
    end)
    if not ok2 or type(data) ~= "table" then return nil end
    return data
end

local function collectFromData(data, targetPlaying, result, lockRef)
    if not data or not data.data then return end
    for _, s in ipairs(data.data) do
        local pc = s.playing or 0
        local id = s.id
        if id and id ~= JOB_ID and not Blacklist[id] and pc == targetPlaying then
            while lockRef[1] do task.wait() end
            lockRef[1] = true
            result[id] = {
                id = id,
                ping = s.ping or 999,
                fps = s.fps or 60,
                playing = pc,
                max = s.maxPlayers or 12,
            }
            lockRef[1] = false
        end
    end
end

local function parallelScan(targetPlaying)
    local result = {}
    local lockRef = {false}

    local first = requestPage("")
    if not first then return result end
    collectFromData(first, targetPlaying, result, lockRef)

    local rootCursor = first.nextPageCursor
    if not rootCursor or rootCursor == "" or rootCursor == "null" then
        return result
    end

    local branchCursors = { rootCursor }
    for i = 1, CONFIG.ParallelBranches do
        local cur = branchCursors[i]
        if cur then
            local data = requestPage(cur)
            if data then
                collectFromData(data, targetPlaying, result, lockRef)
                if data.nextPageCursor and data.nextPageCursor ~= "" and data.nextPageCursor ~= "null" then
                    branchCursors[i + 1] = data.nextPageCursor
                end
            end
        end
    end

    local pagesPerBranch = math.floor(CONFIG.MaxPages / math.max(1, CONFIG.ParallelBranches))
    local threads = {}

    for idx = 1, CONFIG.ParallelBranches do
        local startCursor = branchCursors[idx]
        if startCursor then
            table.insert(threads, task.spawn(function()
                local cursor = startCursor
                local pages = 0
                while pages < pagesPerBranch do
                    local data = requestPage(cursor)
                    if not data then break end
                    collectFromData(data, targetPlaying, result, lockRef)
                    cursor = data.nextPageCursor
                    if not cursor or cursor == "" or cursor == "null" then break end
                    pages = pages + 1
                    if CONFIG.PageDelay > 0 then task.wait(CONFIG.PageDelay) end
                end
            end))
        end
    end

    for _ = 1, #threads do task.wait(0.05) end
    task.wait(0.15)

    return result
end

local function calculateScore(server, stabilityBonus)
    local playerScore = 0
    if server.playing == 1 then
        playerScore = 1000
    elseif server.playing == 2 then
        playerScore = 200
    end

    local fpsScore = math.max(0, 60 - server.fps) * 2
    local pingScore = math.min(server.ping, 500) / 4
    local stabilityScore = stabilityBonus * 100

    return playerScore + fpsScore + pingScore + stabilityScore
end

local function fastTeleport(jobId)
    local success = false
    pcall(function()
        local opts = Instance.new("TeleportOptions")
        opts.ServerInstanceId = jobId
        TeleportService:TeleportAsync(PLACE_ID, {LocalPlayer}, opts)
        success = true
    end)
    if success then return true end
    pcall(function()
        TeleportService:TeleportToPlaceInstance(PLACE_ID, jobId, LocalPlayer)
        success = true
    end)
    return success
end

local function scanForTarget(targetPlaying)
    local pass1 = parallelScan(targetPlaying)
    local count1 = 0
    for _ in pairs(pass1) do count1 = count1 + 1 end
    if count1 == 0 then return nil end

    task.wait(CONFIG.PassDelay)

    local pass2 = parallelScan(targetPlaying)

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

    task.wait(CONFIG.ConfirmDelay)

    local finalPool = {}
    for _, s in ipairs(stable) do
        s.score = calculateScore(s, s.stability)
        table.insert(finalPool, s)
    end

    table.sort(finalPool, function(a, b)
        if a.stability ~= b.stability then
            return a.stability > b.stability
        end
        return a.score > b.score
    end)

    local topCount = math.min(3, #finalPool)
    if topCount == 0 then return nil end

    return finalPool[math.random(1, topCount)]
end

local function setAutoHop(enabled)
    AutoHopEnabled = enabled
    if enabled then
        AutoBtn.Text = "AUTO ON"
        AutoBtn.TextColor3 = Color3.fromRGB(140, 255, 180)
        AutoStroke.Color = Color3.fromRGB(60, 220, 120)
        AutoStroke.Transparency = 0.3
    else
        AutoBtn.Text = "AUTO OFF"
        AutoBtn.TextColor3 = Color3.fromRGB(140, 150, 180)
        AutoStroke.Color = Color3.fromRGB(80, 90, 120)
        AutoStroke.Transparency = 0.5
    end
end

AutoBtn.MouseButton1Click:Connect(function()
    setAutoHop(not AutoHopEnabled)
end)

local function performHop()
    if IsScanning or IsHopping then return end
    IsScanning = true
    setDot(Color3.fromRGB(255, 200, 100))
    setIndicator(Color3.fromRGB(255, 200, 100))
    setStatus("Đang quét server 1 người...", Color3.fromRGB(255, 220, 140))
    setTarget("Mục tiêu: 1 người (2/2)", Color3.fromRGB(120, 220, 180))

    if not http then
        IsScanning = false
        setDot(Color3.fromRGB(255, 100, 100))
        setIndicator(Color3.fromRGB(255, 100, 100))
        setStatus("Executor không hỗ trợ HTTP", Color3.fromRGB(255, 120, 120))
        return
    end

    local target = scanForTarget(1)
    local mode = "1 người (2/2)"

    if not target then
        setStatus("Thử mở rộng lên 2 người...", Color3.fromRGB(255, 200, 100))
        setTarget("Mục tiêu: 2 người (3/3)", Color3.fromRGB(255, 200, 120))
        target = scanForTarget(2)
        mode = "2 người (3/3)"
    end

    if not target then
        IsScanning = false
        setDot(Color3.fromRGB(255, 100, 100))
        setIndicator(Color3.fromRGB(255, 100, 100))
        setStatus("Không tìm thấy server", Color3.fromRGB(255, 120, 120))
        task.wait(5)
        return
    end

    setDot(Color3.fromRGB(255, 140, 60))
    setIndicator(Color3.fromRGB(255, 140, 60))
    setStatus("Vào server " .. mode, Color3.fromRGB(120, 255, 160))
    setTarget("Đang vào: " .. target.playing .. "/" .. target.max .. " người", Color3.fromRGB(120, 220, 180))

    ScanCount = ScanCount + 1
    TotalScans = TotalScans + 1
    LastFound = target
    ScanValue.Text = tostring(TotalScans)
    ScanValue.TextColor3 = Color3.fromRGB(120, 255, 160)

    task.wait(CONFIG.PreTeleportDelay)

    IsScanning = false
    IsHopping = true
    Blacklist[target.id] = true
    CurrentTargetPlayers = target.playing + 1

    fastTeleport(target.id)

    task.wait(3)
    IsHopping = false
end

HopBtn.MouseButton1Click:Connect(function()
    task.spawn(performHop)
end)

local lastPlayerCount = 0

local function startMonitor()
    if MonitorConn then MonitorConn:Disconnect() end
    MonitorConn = RunService.Heartbeat:Connect(function()
        if not AutoHopEnabled then return end
        if IsHopping or IsScanning then return end

        local count = #Players:GetPlayers()
        if count == lastPlayerCount then return end
        lastPlayerCount = count

        if CurrentTargetPlayers then
            if count > CurrentTargetPlayers then
                setDot(Color3.fromRGB(255, 180, 100))
                setIndicator(Color3.fromRGB(255, 180, 100))
                setStatus("Có người vào · chờ " .. CONFIG.AutoHopDelay .. "s", Color3.fromRGB(255, 200, 120))

                task.spawn(function()
                    for i = CONFIG.AutoHopDelay, 1, -1 do
                        if not AutoHopEnabled then return end
                        local cnt = #Players:GetPlayers()
                        if cnt <= CurrentTargetPlayers then
                            setDot(Color3.fromRGB(60, 220, 120))
                            setIndicator(Color3.fromRGB(60, 220, 120))
                            setStatus("Người đó đã rời", Color3.fromRGB(120, 255, 160))
                            return
                        end
                        setStatus("Hop sau " .. i .. "s · " .. cnt .. " người", Color3.fromRGB(255, 180, 100))
                        task.wait(1)
                    end

                    if #Players:GetPlayers() > CurrentTargetPlayers then
                        setStatus("Auto hop", Color3.fromRGB(255, 150, 100))
                        performHop()
                    end
                end)
            end
        else
            if count >= 2 then
                task.spawn(performHop)
            end
        end
    end)
end

local dragging, dragStart, startPos
Header.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = Main.Position
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if not dragging then return end
    if input.UserInputType ~= Enum.UserInputType.MouseMovement
        and input.UserInputType ~= Enum.UserInputType.Touch then return end
    local d = input.Position - dragStart
    Main.Position = UDim2.new(
        startPos.X.Scale, startPos.X.Offset + d.X,
        startPos.Y.Scale, startPos.Y.Offset + d.Y
    )
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        dragging = false
    end
end)

HopBtn.MouseEnter:Connect(function()
    TweenService:Create(HopBtn, TweenInfo.new(0.15), {
        BackgroundColor3 = Color3.fromRGB(90, 170, 255)
    }):Play()
end)
HopBtn.MouseLeave:Connect(function()
    TweenService:Create(HopBtn, TweenInfo.new(0.15), {
        BackgroundColor3 = Color3.fromRGB(60, 140, 220)
    }):Play()
end)

AutoBtn.MouseEnter:Connect(function()
    TweenService:Create(AutoBtn, TweenInfo.new(0.15), {
        BackgroundColor3 = Color3.fromRGB(55, 60, 80)
    }):Play()
end)
AutoBtn.MouseLeave:Connect(function()
    TweenService:Create(AutoBtn, TweenInfo.new(0.15), {
        BackgroundColor3 = Color3.fromRGB(40, 45, 60)
    }):Play()
end)

TweenService:Create(Glow, TweenInfo.new(2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
    BackgroundTransparency = 0.85
}):Play()

setDot(Color3.fromRGB(60, 220, 120))
setIndicator(Color3.fromRGB(60, 220, 120))
setStatus("Sẵn sàng", Color3.fromRGB(220, 230, 255))
setTarget("Mục tiêu: 1 người (2/2)", Color3.fromRGB(120, 220, 180))
updatePlayerCount()
startMonitor()

task.spawn(function()
    task.wait(2)
    if #Players:GetPlayers() >= 2 then
        performHop()
    else
        setStatus("Đang chờ có người vào...", Color3.fromRGB(160, 200, 255))
    end
end)

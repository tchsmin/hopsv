local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local CoreGui = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")
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
    PassDelay = 0.3,
    ConfirmDelay = 0.2,
    PreTeleportDelay = 0.15,
    MaxPages = 50,
    ParallelBranches = 6,
    LoopWait = 1.2,
    TeleportWait = 4,
    TargetPlaying = 1,
    FallbackPlaying = 2,
}

local Blacklist = {}
local IsRunning = true
local LastRender = 0
local DebugInfo = {
    totalSeen = 0,
    byPlaying = {},
    lastPool = 0,
    attempts = 0,
}

if CoreGui:FindFirstChild("PhantomUI") then CoreGui.PhantomUI:Destroy() end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "PhantomUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.IgnoreGuiInset = true
ScreenGui.DisplayOrder = 999999
ScreenGui.Parent = CoreGui

local Main = Instance.new("Frame")
Main.Size = UDim2.new(0, 240, 0, 175)
Main.Position = UDim2.new(0, 20, 0.5, -87)
Main.BackgroundColor3 = Color3.fromRGB(13, 15, 22)
Main.BorderSizePixel = 0
Main.Active = true
Main.ClipsDescendants = true
Main.Parent = ScreenGui

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 14)
MainCorner.Parent = Main

local Glow = Instance.new("Frame")
Glow.Size = UDim2.new(1, 16, 1, 16)
Glow.Position = UDim2.new(0, -8, 0, -8)
Glow.BackgroundColor3 = Color3.fromRGB(120, 80, 255)
Glow.BackgroundTransparency = 0.92
Glow.BorderSizePixel = 0
Glow.ZIndex = 0
Glow.Parent = Main

local GlowCorner = Instance.new("UICorner")
GlowCorner.CornerRadius = UDim.new(0, 20)
GlowCorner.Parent = Glow

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

local TopBar = Instance.new("Frame")
TopBar.Size = UDim2.new(1, 0, 0, 38)
TopBar.BackgroundTransparency = 1
TopBar.Parent = Main

local StatusPill = Instance.new("Frame")
StatusPill.Size = UDim2.new(0, 66, 0, 22)
StatusPill.Position = UDim2.new(1, -78, 0, 8)
StatusPill.BackgroundColor3 = Color3.fromRGB(24, 40, 30)
StatusPill.BorderSizePixel = 0
StatusPill.Parent = TopBar

local SPillC = Instance.new("UICorner")
SPillC.CornerRadius = UDim.new(1, 0)
SPillC.Parent = StatusPill

local SPillStroke = Instance.new("UIStroke")
SPillStroke.Color = Color3.fromRGB(60, 220, 120)
SPillStroke.Thickness = 1
SPillStroke.Transparency = 0.3
SPillStroke.Parent = StatusPill

local PillDot = Instance.new("Frame")
PillDot.Size = UDim2.new(0, 6, 0, 6)
PillDot.Position = UDim2.new(0, 9, 0.5, -3)
PillDot.BackgroundColor3 = Color3.fromRGB(60, 220, 120)
PillDot.BorderSizePixel = 0
PillDot.Parent = StatusPill

local PDotC = Instance.new("UICorner")
PDotC.CornerRadius = UDim.new(1, 0)
PDotC.Parent = PillDot

local DotPulse = Instance.new("Frame")
DotPulse.Size = UDim2.new(1, 0, 1, 0)
DotPulse.BackgroundColor3 = Color3.fromRGB(60, 220, 120)
DotPulse.BackgroundTransparency = 0.6
DotPulse.BorderSizePixel = 0
DotPulse.Parent = PillDot

local DPulseC = Instance.new("UICorner")
DPulseC.CornerRadius = UDim.new(1, 0)
DPulseC.Parent = DotPulse

task.spawn(function()
    while ScreenGui.Parent do
        DotPulse.Size = UDim2.new(1, 0, 1, 0)
        DotPulse.Position = UDim2.new(0, 0, 0, 0)
        DotPulse.BackgroundTransparency = 0.6
        task.wait(1)
        DotPulse:TweenSizeAndPosition(
            UDim2.new(3, 0, 3, 0),
            UDim2.new(-1, 0, -1, 0),
            Enum.EasingDirection.Out,
            Enum.EasingStyle.Sine,
            0.8
        )
        DotPulse.BackgroundTransparency = 1
        task.wait(0.8)
    end
end)

local PillText = Instance.new("TextLabel")
PillText.Size = UDim2.new(1, -20, 1, 0)
PillText.Position = UDim2.new(0, 20, 0, 0)
PillText.BackgroundTransparency = 1
PillText.Text = "ON"
PillText.TextColor3 = Color3.fromRGB(140, 255, 180)
PillText.Font = Enum.Font.GothamBold
PillText.TextSize = 9
PillText.TextXAlignment = Enum.TextXAlignment.Left
PillText.Parent = StatusPill

local LogoBox = Instance.new("Frame")
LogoBox.Size = UDim2.new(0, 28, 0, 28)
LogoBox.Position = UDim2.new(0, 12, 0, 5)
LogoBox.BackgroundColor3 = Color3.fromRGB(40, 30, 70)
LogoBox.BorderSizePixel = 0
LogoBox.Parent = TopBar

local LBC = Instance.new("UICorner")
LBC.CornerRadius = UDim.new(0, 8)
LBC.Parent = LogoBox

local LBG = Instance.new("UIGradient")
LBG.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(120, 80, 255)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(60, 180, 255))
})
LBG.Rotation = 45
LBG.Parent = LogoBox

local LogoIcon = Instance.new("TextLabel")
LogoIcon.Size = UDim2.new(1, 0, 1, 0)
LogoIcon.BackgroundTransparency = 1
LogoIcon.Text = "⚡"
LogoIcon.TextColor3 = Color3.fromRGB(255, 255, 255)
LogoIcon.Font = Enum.Font.GothamBold
LogoIcon.TextSize = 15
LogoIcon.Parent = LogoBox

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, -130, 0, 16)
Title.Position = UDim2.new(0, 46, 0, 8)
Title.BackgroundTransparency = 1
Title.Text = "PHANTOM"
Title.TextColor3 = Color3.fromRGB(240, 245, 255)
Title.Font = Enum.Font.GothamBold
Title.TextSize = 13
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = TopBar

local Subtitle = Instance.new("TextLabel")
Subtitle.Size = UDim2.new(1, -130, 0, 11)
Subtitle.Position = UDim2.new(0, 46, 0, 23)
Subtitle.BackgroundTransparency = 1
Subtitle.Text = "auto hop · solo 1 người"
Subtitle.TextColor3 = Color3.fromRGB(130, 140, 180)
Subtitle.Font = Enum.Font.Gotham
Subtitle.TextSize = 9
Subtitle.TextXAlignment = Enum.TextXAlignment.Left
Subtitle.Parent = TopBar

local Divider = Instance.new("Frame")
Divider.Size = UDim2.new(1, -24, 0, 1)
Divider.Position = UDim2.new(0, 12, 0, 42)
Divider.BackgroundColor3 = Color3.fromRGB(30, 34, 48)
Divider.BorderSizePixel = 0
Divider.Parent = Main

local function makeCard(yPos)
    local card = Instance.new("Frame")
    card.Size = UDim2.new(1, -24, 0, 28)
    card.Position = UDim2.new(0, 12, 0, yPos)
    card.BackgroundColor3 = Color3.fromRGB(20, 23, 32)
    card.BorderSizePixel = 0
    card.Parent = Main
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 7)
    c.Parent = card
    return card
end

local PlayersCard = makeCard(50)
local PlayerIcon = Instance.new("TextLabel")
PlayerIcon.Size = UDim2.new(0, 26, 1, 0)
PlayerIcon.Position = UDim2.new(0, 6, 0, 0)
PlayerIcon.BackgroundTransparency = 1
PlayerIcon.Text = "👥"
PlayerIcon.TextSize = 13
PlayerIcon.Parent = PlayersCard

local PlayerText = Instance.new("TextLabel")
PlayerText.Size = UDim2.new(1, -100, 1, 0)
PlayerText.Position = UDim2.new(0, 34, 0, 0)
PlayerText.BackgroundTransparency = 1
PlayerText.Text = "Số người"
PlayerText.TextColor3 = Color3.fromRGB(160, 170, 200)
PlayerText.Font = Enum.Font.Gotham
PlayerText.TextSize = 10
PlayerText.TextXAlignment = Enum.TextXAlignment.Left
PlayerText.Parent = PlayersCard

local PlayerValue = Instance.new("TextLabel")
PlayerValue.Size = UDim2.new(0, 60, 1, 0)
PlayerValue.Position = UDim2.new(1, -66, 0, 0)
PlayerValue.BackgroundTransparency = 1
PlayerValue.Text = "1"
PlayerValue.TextColor3 = Color3.fromRGB(120, 255, 160)
PlayerValue.Font = Enum.Font.GothamBold
PlayerValue.TextSize = 13
PlayerValue.TextXAlignment = Enum.TextXAlignment.Right
PlayerValue.Parent = PlayersCard

local FoundCard = makeCard(82)
local FoundIcon = Instance.new("TextLabel")
FoundIcon.Size = UDim2.new(0, 26, 1, 0)
FoundIcon.Position = UDim2.new(0, 6, 0, 0)
FoundIcon.BackgroundTransparency = 1
FoundIcon.Text = "🎯"
FoundIcon.TextSize = 13
FoundIcon.Parent = FoundCard

local FoundText = Instance.new("TextLabel")
FoundText.Size = UDim2.new(1, -100, 1, 0)
FoundText.Position = UDim2.new(0, 34, 0, 0)
FoundText.BackgroundTransparency = 1
FoundText.Text = "Server tìm được"
FoundText.TextColor3 = Color3.fromRGB(160, 170, 200)
FoundText.Font = Enum.Font.Gotham
FoundText.TextSize = 10
FoundText.TextXAlignment = Enum.TextXAlignment.Left
FoundText.Parent = FoundCard

local FoundValue = Instance.new("TextLabel")
FoundValue.Size = UDim2.new(0, 60, 1, 0)
FoundValue.Position = UDim2.new(1, -66, 0, 0)
FoundValue.BackgroundTransparency = 1
FoundValue.Text = "0"
FoundValue.TextColor3 = Color3.fromRGB(120, 180, 255)
FoundValue.Font = Enum.Font.GothamBold
FoundValue.TextSize = 13
FoundValue.TextXAlignment = Enum.TextXAlignment.Right
FoundValue.Parent = FoundCard

local StatusCard = makeCard(114)
local StatusIcon = Instance.new("TextLabel")
StatusIcon.Size = UDim2.new(0, 26, 1, 0)
StatusIcon.Position = UDim2.new(0, 6, 0, 0)
StatusIcon.BackgroundTransparency = 1
StatusIcon.Text = "◐"
StatusIcon.TextColor3 = Color3.fromRGB(120, 200, 255)
StatusIcon.TextSize = 13
StatusIcon.Parent = StatusCard

task.spawn(function()
    local frames = {"◐", "◓", "◑", "◒"}
    local i = 1
    while ScreenGui.Parent do
        StatusIcon.Text = frames[i]
        i = i + 1
        if i > #frames then i = 1 end
        task.wait(0.2)
    end
end)

local StatusText = Instance.new("TextLabel")
StatusText.Size = UDim2.new(1, -20, 1, 0)
StatusText.Position = UDim2.new(0, 34, 0, 0)
StatusText.BackgroundTransparency = 1
StatusText.Text = "Đang chạy"
StatusText.TextColor3 = Color3.fromRGB(220, 230, 255)
StatusText.Font = Enum.Font.GothamBold
StatusText.TextSize = 10
StatusText.TextXAlignment = Enum.TextXAlignment.Left
StatusText.Parent = StatusCard

local DebugLabel = Instance.new("TextLabel")
DebugLabel.Size = UDim2.new(1, -24, 0, 20)
DebugLabel.Position = UDim2.new(0, 12, 0, 148)
DebugLabel.BackgroundTransparency = 1
DebugLabel.Text = "seen 0 | pool 0 | attempt 0"
DebugLabel.TextColor3 = Color3.fromRGB(100, 110, 140)
DebugLabel.Font = Enum.Font.Code
DebugLabel.TextSize = 8
DebugLabel.TextXAlignment = Enum.TextXAlignment.Left
DebugLabel.Parent = Main

local function setStatus(text, color)
    StatusText.Text = text
    if color then
        StatusText.TextColor3 = color
        PillDot.BackgroundColor3 = color
        DotPulse.BackgroundColor3 = color
        SPillStroke.Color = color
    end
end

local function setPill(text, color)
    PillText.Text = text
    PillText.TextColor3 = color or Color3.fromRGB(140, 255, 180)
end

local function updateDebug()
    local topDist = {}
    for p, cnt in pairs(DebugInfo.byPlaying) do
        table.insert(topDist, {p = p, c = cnt})
    end
    table.sort(topDist, function(a, b) return a.p < b.p end)

    local parts = {}
    for i = 1, math.min(5, #topDist) do
        local t = topDist[i]
        table.insert(parts, t.p .. ":" .. t.c)
    end

    DebugLabel.Text = string.format(
        "seen %d | pool %d | try %d | %s",
        DebugInfo.totalSeen,
        DebugInfo.lastPool,
        DebugInfo.attempts,
        table.concat(parts, " ")
    )
end

local function updatePlayerCount()
    local count = #Players:GetPlayers()
    PlayerValue.Text = tostring(count)
    if count <= 2 then
        PlayerValue.TextColor3 = Color3.fromRGB(120, 255, 160)
    else
        PlayerValue.TextColor3 = Color3.fromRGB(255, 120, 120)
    end
    return count
end

Players.PlayerAdded:Connect(function() task.wait(0.2) updatePlayerCount() end)
Players.PlayerRemoving:Connect(function() task.wait(0.4) updatePlayerCount() end)

local function requestPage(cursor, sortOrder)
    if not http then return nil end
    sortOrder = sortOrder or "Asc"
    local url = string.format(
        "https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=%s&limit=100&cursor=%s",
        PLACE_ID, sortOrder, cursor or ""
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

local function scanOnce(targetPlaying, sortOrder)
    local result = {}
    local lockRef = {false}
    DebugInfo.byPlaying = {}

    local function processData(data)
        if not data or not data.data then return 0 end
        local cnt = 0
        for _, s in ipairs(data.data) do
            cnt = cnt + 1
            DebugInfo.totalSeen = DebugInfo.totalSeen + 1
            local pc = tonumber(s.playing) or 0
            DebugInfo.byPlaying[pc] = (DebugInfo.byPlaying[pc] or 0) + 1

            local id = s.id
            if id and id ~= JOB_ID and not Blacklist[id] and pc == targetPlaying then
                while lockRef[1] do task.wait() end
                lockRef[1] = true
                result[id] = {
                    id = id,
                    ping = tonumber(s.ping) or 999,
                    fps = tonumber(s.fps) or 60,
                    playing = pc,
                    max = tonumber(s.maxPlayers) or 12,
                }
                lockRef[1] = false
            end
        end
        return cnt
    end

    local first = requestPage("", sortOrder)
    if not first then return result end
    processData(first)

    local rootCursor = first.nextPageCursor
    if not rootCursor or rootCursor == "" or rootCursor == "null" then
        return result
    end

    local pagesPerBranch = math.floor(CONFIG.MaxPages / math.max(1, CONFIG.ParallelBranches))
    local branchCursors = { rootCursor }
    for i = 1, CONFIG.ParallelBranches do
        local cur = branchCursors[i]
        if cur then
            local data = requestPage(cur, sortOrder)
            if data then
                processData(data)
                if data.nextPageCursor and data.nextPageCursor ~= "" and data.nextPageCursor ~= "null" then
                    branchCursors[i + 1] = data.nextPageCursor
                end
            end
        end
    end

    local threads = {}
    for idx = 1, CONFIG.ParallelBranches do
        local startCursor = branchCursors[idx]
        if startCursor then
            table.insert(threads, task.spawn(function()
                local cursor = startCursor
                local pages = 0
                while pages < pagesPerBranch do
                    local data = requestPage(cursor, sortOrder)
                    if not data then break end
                    processData(data)
                    cursor = data.nextPageCursor
                    if not cursor or cursor == "" or cursor == "null" then break end
                    pages = pages + 1
                end
            end))
        end
    end

    for _ = 1, #threads do task.wait(0.05) end
    task.wait(0.1)

    return result
end

local function calculateScore(server, stabilityBonus)
    local fpsScore = math.max(0, 60 - server.fps) * 3
    local pingScore = math.min(server.ping, 500) / 3
    local stabilityScore = stabilityBonus * 150
    return 1000 + fpsScore + pingScore + stabilityScore
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

local function findServer(targetPlaying)
    local pass1 = scanOnce(targetPlaying, "Asc")
    local count1 = 0
    for _ in pairs(pass1) do count1 = count1 + 1 end

    if count1 == 0 then
        pass1 = scanOnce(targetPlaying, "Desc")
        for _ in pairs(pass1) do count1 = count1 + 1 end
        if count1 == 0 then return nil, DebugInfo.totalSeen end
    end

    task.wait(CONFIG.PassDelay)

    local pass2 = scanOnce(targetPlaying, "Asc")

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

    return finalPool, DebugInfo.totalSeen
end

local function mainLoop()
    task.wait(1)

    while IsRunning and ScreenGui.Parent do
        local count = updatePlayerCount()

        if count <= 2 then
            setStatus("Server " .. count .. " người · ổn định", Color3.fromRGB(120, 255, 160))
            setPill("ON", Color3.fromRGB(140, 255, 180))

            for _ = 1, 3 do
                if not ScreenGui.Parent then return end
                task.wait(1)
                count = #Players:GetPlayers()
                updatePlayerCount()
                if count > 2 then break end
            end

            if count <= 2 then
                continue
            end
        end

        for i = 3, 1, -1 do
            if not ScreenGui.Parent then return end
            local cnt = #Players:GetPlayers()
            if cnt <= 2 then
                setStatus("Người rời · hủy hop", Color3.fromRGB(120, 255, 160))
                break
            end
            setStatus("Chờ " .. i .. "s · " .. cnt .. " người", Color3.fromRGB(255, 200, 100))
            task.wait(1)
        end

        if #Players:GetPlayers() <= 2 then continue end

        DebugInfo.attempts = 0
        local hopSuccess = false

        while not hopSuccess and ScreenGui.Parent do
            DebugInfo.attempts = DebugInfo.attempts + 1
            DebugInfo.totalSeen = 0

            setStatus("Tìm server 1 người...", Color3.fromRGB(255, 200, 100))
            setPill("SCAN", Color3.fromRGB(255, 200, 120))
            updateDebug()

            if not http then
                setStatus("Lỗi HTTP", Color3.fromRGB(255, 100, 100))
                setPill("OFF", Color3.fromRGB(255, 120, 120))
                task.wait(2)
                continue
            end

            local pool, seenCount = findServer(1)
            DebugInfo.lastPool = pool and #pool or 0
            FoundValue.Text = tostring(DebugInfo.lastPool)
            updateDebug()

            if not pool or #pool == 0 then
                setStatus("Không có 1 người · thử 2", Color3.fromRGB(255, 180, 100))
                task.wait(0.5)

                pool, seenCount = findServer(2)
                DebugInfo.lastPool = pool and #pool or 0
                FoundValue.Text = tostring(DebugInfo.lastPool)
                updateDebug()
            end

            if pool and #pool > 0 then
                local target = pool[1]
                setStatus("Tìm được " .. #pool .. " · đang vào", Color3.fromRGB(120, 255, 160))
                setPill("HOP", Color3.fromRGB(120, 255, 160))

                Blacklist[target.id] = true
                task.wait(CONFIG.PreTeleportDelay)

                local ok = fastTeleport(target.id)
                if ok then
                    hopSuccess = true
                    task.wait(CONFIG.TeleportWait)
                else
                    setStatus("Teleport fail · thử lại", Color3.fromRGB(255, 100, 100))
                    task.wait(1)
                end
            else
                Blacklist = {}
                setStatus("Không có · thử lại sau " .. CONFIG.LoopWait .. "s", Color3.fromRGB(255, 150, 100))
                setPill("WAIT", Color3.fromRGB(255, 180, 100))
                task.wait(CONFIG.LoopWait)
            end
        end
    end
end

local dragging, dragStart, startPos
TopBar.InputBegan:Connect(function(input)
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

TweenService:Create(Glow, TweenInfo.new(2.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
    BackgroundTransparency = 0.88
}):Play()

updatePlayerCount()
setStatus("Đang chạy", Color3.fromRGB(120, 255, 160))
setPill("ON", Color3.fromRGB(140, 255, 180))

task.spawn(mainLoop)

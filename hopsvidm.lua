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
    PassDelay = 0.25,
    ConfirmDelay = 0.15,
    PreTeleportDelay = 0.1,
    MaxPages = 80,
    ParallelBranches = 8,
    LoopWait = 1,
    TeleportWait = 3,
}

local Blacklist = {}
local IsRunning = true

local Debug = {
    seen = 0,
    pool = 0,
    attempt = 0,
    dist = {},
    ascSeen = 0,
    descSeen = 0,
    lastMode = "",
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
Main.Size = UDim2.new(0, 250, 0, 195)
Main.Position = UDim2.new(0, 20, 0.5, -97)
Main.BackgroundColor3 = Color3.fromRGB(13, 15, 22)
Main.BorderSizePixel = 0
Main.Active = true
Main.ClipsDescendants = true
Main.Parent = ScreenGui

local MC = Instance.new("UICorner")
MC.CornerRadius = UDim.new(0, 14)
MC.Parent = Main

local BGrad = Instance.new("UIGradient")
BGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(13, 15, 22)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(18, 14, 28))
})
BGrad.Rotation = 135
BGrad.Parent = Main

local Border = Instance.new("UIStroke")
Border.Thickness = 1.5
Border.Transparency = 0.1
Border.Parent = Main

local BG = Instance.new("UIGradient")
BG.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(120, 80, 255)),
    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(80, 180, 255)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 100, 255))
})
BG.Rotation = 45
BG.Parent = Border

task.spawn(function()
    while ScreenGui.Parent do
        BG.Rotation = BG.Rotation + 3
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
Subtitle.Text = "auto hop · scan toàn bộ"
Subtitle.TextColor3 = Color3.fromRGB(130, 140, 180)
Subtitle.Font = Enum.Font.Gotham
Subtitle.TextSize = 9
Subtitle.TextXAlignment = Enum.TextXAlignment.Left
Subtitle.Parent = TopBar

local Pill = Instance.new("Frame")
Pill.Size = UDim2.new(0, 68, 0, 22)
Pill.Position = UDim2.new(1, -80, 0, 10)
Pill.BackgroundColor3 = Color3.fromRGB(24, 40, 30)
Pill.BorderSizePixel = 0
Pill.Parent = TopBar

local PC = Instance.new("UICorner")
PC.CornerRadius = UDim.new(1, 0)
PC.Parent = Pill

local PS = Instance.new("UIStroke")
PS.Color = Color3.fromRGB(60, 220, 120)
PS.Thickness = 1
PS.Transparency = 0.3
PS.Parent = Pill

local PDot = Instance.new("Frame")
PDot.Size = UDim2.new(0, 6, 0, 6)
PDot.Position = UDim2.new(0, 10, 0.5, -3)
PDot.BackgroundColor3 = Color3.fromRGB(60, 220, 120)
PDot.BorderSizePixel = 0
PDot.Parent = Pill

local PDC = Instance.new("UICorner")
PDC.CornerRadius = UDim.new(1, 0)
PDC.Parent = PDot

local DPulse = Instance.new("Frame")
DPulse.Size = UDim2.new(1, 0, 1, 0)
DPulse.BackgroundColor3 = Color3.fromRGB(60, 220, 120)
DPulse.BackgroundTransparency = 0.6
DPulse.BorderSizePixel = 0
DPulse.Parent = PDot

local DPC = Instance.new("UICorner")
DPC.CornerRadius = UDim.new(1, 0)
DPC.Parent = DPulse

task.spawn(function()
    while ScreenGui.Parent do
        DPulse.Size = UDim2.new(1, 0, 1, 0)
        DPulse.Position = UDim2.new(0, 0, 0, 0)
        DPulse.BackgroundTransparency = 0.6
        task.wait(1)
        DPulse:TweenSizeAndPosition(
            UDim2.new(3, 0, 3, 0),
            UDim2.new(-1, 0, -1, 0),
            Enum.EasingDirection.Out,
            Enum.EasingStyle.Sine,
            0.8
        )
        DPulse.BackgroundTransparency = 1
        task.wait(0.8)
    end
end)

local PText = Instance.new("TextLabel")
PText.Size = UDim2.new(1, -22, 1, 0)
PText.Position = UDim2.new(0, 22, 0, 0)
PText.BackgroundTransparency = 1
PText.Text = "ON"
PText.TextColor3 = Color3.fromRGB(140, 255, 180)
PText.Font = Enum.Font.GothamBold
PText.TextSize = 9
PText.TextXAlignment = Enum.TextXAlignment.Left
PText.Parent = Pill

local Div = Instance.new("Frame")
Div.Size = UDim2.new(1, -24, 0, 1)
Div.Position = UDim2.new(0, 12, 0, 46)
Div.BackgroundColor3 = Color3.fromRGB(30, 34, 48)
Div.BorderSizePixel = 0
Div.Parent = Main

local function makeRow(y, labelText, iconText)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, -24, 0, 26)
    row.Position = UDim2.new(0, 12, 0, y)
    row.BackgroundColor3 = Color3.fromRGB(20, 23, 32)
    row.BorderSizePixel = 0
    row.Parent = Main
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 6)
    c.Parent = row
    local icon = Instance.new("TextLabel")
    icon.Size = UDim2.new(0, 24, 1, 0)
    icon.Position = UDim2.new(0, 6, 0, 0)
    icon.BackgroundTransparency = 1
    icon.Text = iconText
    icon.TextSize = 12
    icon.Parent = row
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -100, 1, 0)
    lbl.Position = UDim2.new(0, 32, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = labelText
    lbl.TextColor3 = Color3.fromRGB(160, 170, 200)
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = 10
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = row
    local val = Instance.new("TextLabel")
    val.Size = UDim2.new(0, 60, 1, 0)
    val.Position = UDim2.new(1, -66, 0, 0)
    val.BackgroundTransparency = 1
    val.Text = "0"
    val.TextColor3 = Color3.fromRGB(120, 180, 255)
    val.Font = Enum.Font.GothamBold
    val.TextSize = 12
    val.TextXAlignment = Enum.TextXAlignment.Right
    val.Parent = row
    return row, val
end

local _, PlayerValue = makeRow(54, "Số người", "👥")
local _, FoundValue = makeRow(84, "Pool tìm được", "🎯")
local _, DistValue = makeRow(114, "Server 1 người", "🔍")

PlayerValue.TextColor3 = Color3.fromRGB(120, 255, 160)
FoundValue.TextColor3 = Color3.fromRGB(120, 200, 255)
DistValue.TextColor3 = Color3.fromRGB(255, 200, 120)

local StatusFrame = Instance.new("Frame")
StatusFrame.Size = UDim2.new(1, -24, 0, 24)
StatusFrame.Position = UDim2.new(0, 12, 0, 144)
StatusFrame.BackgroundColor3 = Color3.fromRGB(25, 20, 40)
StatusFrame.BorderSizePixel = 0
StatusFrame.Parent = Main

local SFC = Instance.new("UICorner")
SFC.CornerRadius = UDim.new(0, 6)
SFC.Parent = StatusFrame

local StatusIcon = Instance.new("TextLabel")
StatusIcon.Size = UDim2.new(0, 24, 1, 0)
StatusIcon.Position = UDim2.new(0, 4, 0, 0)
StatusIcon.BackgroundTransparency = 1
StatusIcon.Text = "◐"
StatusIcon.TextColor3 = Color3.fromRGB(140, 180, 255)
StatusIcon.TextSize = 13
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
StatusText.Size = UDim2.new(1, -32, 1, 0)
StatusText.Position = UDim2.new(0, 30, 0, 0)
StatusText.BackgroundTransparency = 1
StatusText.Text = "Đang chạy"
StatusText.TextColor3 = Color3.fromRGB(200, 220, 255)
StatusText.Font = Enum.Font.GothamBold
StatusText.TextSize = 10
StatusText.TextXAlignment = Enum.TextXAlignment.Left
StatusText.Parent = StatusFrame

local DebugLabel = Instance.new("TextLabel")
DebugLabel.Size = UDim2.new(1, -24, 0, 16)
DebugLabel.Position = UDim2.new(0, 12, 0, 173)
DebugLabel.BackgroundTransparency = 1
DebugLabel.Text = "chưa scan"
DebugLabel.TextColor3 = Color3.fromRGB(100, 110, 140)
DebugLabel.Font = Enum.Font.Code
DebugLabel.TextSize = 8
DebugLabel.TextXAlignment = Enum.TextXAlignment.Left
DebugLabel.Parent = Main

local function setStatus(text, color)
    StatusText.Text = text
    if color then
        StatusText.TextColor3 = color
        PDot.BackgroundColor3 = color
        DPulse.BackgroundColor3 = color
        PS.Color = color
    end
end

local function setPill(text, color)
    PText.Text = text
    PText.TextColor3 = color or Color3.fromRGB(140, 255, 180)
    if color then
        PDot.BackgroundColor3 = color
        DPulse.BackgroundColor3 = color
        PS.Color = color
    end
end

local function updatePlayerCount()
    local c = #Players:GetPlayers()
    PlayerValue.Text = tostring(c)
    PlayerValue.TextColor3 = c <= 2 and Color3.fromRGB(120, 255, 160) or Color3.fromRGB(255, 120, 120)
    return c
end

local function updateDebug()
    local parts = {}
    local keys = {}
    for k in pairs(Debug.dist) do table.insert(keys, k) end
    table.sort(keys)
    for i = 1, math.min(6, #keys) do
        local k = keys[i]
        table.insert(parts, k .. ":" .. Debug.dist[k])
    end
    DebugLabel.Text = string.format(
        "seen %d | asc %d | desc %d | try %d | %s",
        Debug.seen, Debug.ascSeen, Debug.descSeen, Debug.attempt, table.concat(parts, " ")
    )
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

local function scanAll(targetPlaying, sortOrder)
    local result = {}
    local lockRef = {false}
    local seenLocal = 0

    local function processData(data)
        if not data or not data.data then return end
        for _, s in ipairs(data.data) do
            Debug.seen = Debug.seen + 1
            seenLocal = seenLocal + 1
            local pc = tonumber(s.playing) or 0
            Debug.dist[pc] = (Debug.dist[pc] or 0) + 1

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
    end

    local first = requestPage("", sortOrder)
    if not first then return result, 0 end
    processData(first)

    local rootCursor = first.nextPageCursor
    if not rootCursor or rootCursor == "" or rootCursor == "null" then
        return result, seenLocal
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

    return result, seenLocal
end

local function calculateScore(s, stability)
    local fps = math.max(0, 60 - s.fps) * 3
    local ping = math.min(s.ping, 500) / 3
    return 1000 + fps + ping + stability * 150
end

local function fastTeleport(jobId)
    local ok1 = pcall(function()
        local opts = Instance.new("TeleportOptions")
        opts.ServerInstanceId = jobId
        TeleportService:TeleportAsync(PLACE_ID, {LocalPlayer}, opts)
    end)
    if ok1 then return true end
    local ok2 = pcall(function()
        TeleportService:TeleportToPlaceInstance(PLACE_ID, jobId, LocalPlayer)
    end)
    return ok2
end

local function findServer(targetPlaying)
    Debug.dist = {}
    Debug.ascSeen = 0
    Debug.descSeen = 0

    local pass1Asc, ascSeen = scanAll(targetPlaying, "Asc")
    Debug.ascSeen = ascSeen
    local count1 = 0
    for _ in pairs(pass1Asc) do count1 = count1 + 1 end

    if count1 == 0 then
        local pass1Desc, descSeen = scanAll(targetPlaying, "Desc")
        Debug.descSeen = descSeen
        for id, s in pairs(pass1Desc) do
            pass1Asc[id] = s
        end
        count1 = 0
        for _ in pairs(pass1Asc) do count1 = count1 + 1 end
    end

    if count1 == 0 then return nil end

    task.wait(CONFIG.PassDelay)

    local pass2 = scanAll(targetPlaying, "Asc")

    local stable = {}
    for id, s in pairs(pass2) do
        if pass1Asc[id] then
            s.stability = 2
            if s.playing == pass1Asc[id].playing then
                s.stability = 3
            end
            table.insert(stable, s)
        end
    end

    if #stable == 0 then
        for _, s in pairs(pass1Asc) do
            s.stability = 1
            table.insert(stable, s)
        end
    end

    task.wait(CONFIG.ConfirmDelay)

    local pool = {}
    for _, s in ipairs(stable) do
        s.score = calculateScore(s, s.stability)
        table.insert(pool, s)
    end

    table.sort(pool, function(a, b)
        if a.stability ~= b.stability then
            return a.stability > b.stability
        end
        return a.score > b.score
    end)

    return pool
end

local function mainLoop()
    task.wait(1)

    while IsRunning and ScreenGui.Parent do
        local count = updatePlayerCount()

        if count <= 2 then
            setStatus("Server " .. count .. " người · ổn", Color3.fromRGB(120, 255, 160))
            setPill("ON", Color3.fromRGB(60, 220, 120))

            for _ = 1, 3 do
                if not ScreenGui.Parent then return end
                task.wait(1)
                count = #Players:GetPlayers()
                updatePlayerCount()
                if count > 2 then break end
            end

            if count <= 2 then continue end
        end

        for i = 3, 1, -1 do
            if not ScreenGui.Parent then return end
            local cnt = #Players:GetPlayers()
            if cnt <= 2 then
                setStatus("Người rời · hủy hop", Color3.fromRGB(120, 255, 160))
                break
            end
            setStatus("Chờ " .. i .. "s · " .. cnt .. " người", Color3.fromRGB(255, 200, 100))
            setPill("WAIT", Color3.fromRGB(255, 180, 100))
            task.wait(1)
        end

        if #Players:GetPlayers() <= 2 then continue end

        Debug.attempt = 0
        local hopped = false

        while not hopped and ScreenGui.Parent do
            Debug.attempt = Debug.attempt + 1
            Debug.seen = 0

            setStatus("Scan lần " .. Debug.attempt, Color3.fromRGB(255, 200, 100))
            setPill("SCAN", Color3.fromRGB(255, 200, 120))

            if not http then
                setStatus("Lỗi HTTP", Color3.fromRGB(255, 100, 100))
                setPill("OFF", Color3.fromRGB(255, 100, 100))
                task.wait(3)
                continue
            end

            local pool = findServer(1)
            Debug.pool = pool and #pool or 0
            FoundValue.Text = tostring(Debug.pool)
            DistValue.Text = tostring(Debug.dist[1] or 0)
            updateDebug()

            if not pool or #pool == 0 then
                setStatus("Không có 1ng · thử 2ng", Color3.fromRGB(255, 180, 100))
                task.wait(0.3)

                pool = findServer(2)
                Debug.pool = pool and #pool or 0
                FoundValue.Text = tostring(Debug.pool)
                DistValue.Text = "2ng: " .. (Debug.dist[2] or 0)
                updateDebug()
            end

            if pool and #pool > 0 then
                local target = pool[1]
                setStatus("Vào server · FPS" .. target.fps .. " P" .. target.ping, Color3.fromRGB(120, 255, 160))
                setPill("HOP", Color3.fromRGB(120, 255, 160))

                Blacklist[target.id] = true
                task.wait(CONFIG.PreTeleportDelay)

                if fastTeleport(target.id) then
                    hopped = true
                    task.wait(CONFIG.TeleportWait)
                else
                    setStatus("Teleport fail", Color3.fromRGB(255, 100, 100))
                    task.wait(1)
                end
            else
                Blacklist = {}
                setStatus("Không có · scan lại " .. CONFIG.LoopWait .. "s", Color3.fromRGB(255, 150, 100))
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

updatePlayerCount()
setStatus("Đang chạy", Color3.fromRGB(120, 255, 160))
setPill("ON", Color3.fromRGB(60, 220, 120))

task.spawn(mainLoop)

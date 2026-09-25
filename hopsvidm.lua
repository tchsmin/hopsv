local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local CoreGui = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local PLACE_ID = game.PlaceId
local JOB_ID = game.JobId

local ALLOWED_PLACE_IDS = {
    [13772394625] = true,
    [109983668079237] = true,
    [115484077057506] = true,
    [135609351274353] = true,
}

local function isAllowedGame()
    return ALLOWED_PLACE_IDS[PLACE_ID] == true
end

if not isAllowedGame() then
    warn("[HOP SERVER] Chỉ hoạt động trong Steal an Egg")
    return
end

local function getHttp()
    if syn and syn.request then return syn.request end
    if http_request then return http_request end
    if request then return request end
    if fluxus and fluxus.request then return fluxus.request end
    if krnl and krnl.request then return krnl.request end
    if http and http.request then return http.request end
    return nil
end
local http = getHttp()

local CONFIG = {
    PageDelay = 0.03,
    PassDelay = 0.4,
    ConfirmDelay = 0.25,
    PreTeleportDelay = 0.1,
    MaxPages = 30,
    ParallelBranches = 4,
    AutoHopDelay = 3,
    MaxTotalAllowed = 2,
    MaxPlayerFilter = 2,
    MinPlayerFilter = 1,
    TeleportTimeout = 12,
    MaxTeleportAttempts = 3,
}

local Blacklist = {}
local IsScanning = false
local IsHopping = false
local AutoEnabled = true
local TargetTotal = nil
local MonitorConn = nil
local LastPlayerCount = 0
local TeleportPending = false

if CoreGui:FindFirstChild("PhantomUI") then CoreGui.PhantomUI:Destroy() end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "PhantomUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.IgnoreGuiInset = true
ScreenGui.DisplayOrder = 999999
ScreenGui.Parent = CoreGui

local Main = Instance.new("Frame")
Main.Size = UDim2.new(0, 200, 0, 108)
Main.Position = UDim2.new(0, 20, 0.5, -54)
Main.BackgroundColor3 = Color3.fromRGB(16, 18, 26)
Main.BorderSizePixel = 0
Main.Active = true
Main.Parent = ScreenGui

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 12)
MainCorner.Parent = Main

local MainStroke = Instance.new("UIStroke")
MainStroke.Color = Color3.fromRGB(120, 80, 255)
MainStroke.Thickness = 1
MainStroke.Transparency = 0.3
MainStroke.Parent = Main

local Header = Instance.new("Frame")
Header.Size = UDim2.new(1, 0, 0, 32)
Header.BackgroundTransparency = 1
Header.Parent = Main

local TitleText = Instance.new("TextLabel")
TitleText.Size = UDim2.new(1, -24, 1, 0)
TitleText.Position = UDim2.new(0, 12, 0, 0)
TitleText.BackgroundTransparency = 1
TitleText.Text = "HOP SERVER"
TitleText.TextColor3 = Color3.fromRGB(240, 240, 255)
TitleText.Font = Enum.Font.GothamBold
TitleText.TextSize = 12
TitleText.TextXAlignment = Enum.TextXAlignment.Left
TitleText.Parent = Header

local HeaderDot = Instance.new("Frame")
HeaderDot.Size = UDim2.new(0, 6, 0, 6)
HeaderDot.Position = UDim2.new(1, -16, 0.5, -3)
HeaderDot.BackgroundColor3 = Color3.fromRGB(120, 80, 255)
HeaderDot.BorderSizePixel = 0
HeaderDot.Parent = Header

local HdCorner = Instance.new("UICorner")
HdCorner.CornerRadius = UDim.new(1, 0)
HdCorner.Parent = HeaderDot

local Divider = Instance.new("Frame")
Divider.Size = UDim2.new(1, -24, 0, 1)
Divider.Position = UDim2.new(0, 12, 0, 34)
Divider.BackgroundColor3 = Color3.fromRGB(35, 40, 55)
Divider.BorderSizePixel = 0
Divider.Parent = Main

local PlayerRow = Instance.new("Frame")
PlayerRow.Size = UDim2.new(1, -24, 0, 30)
PlayerRow.Position = UDim2.new(0, 12, 0, 40)
PlayerRow.BackgroundColor3 = Color3.fromRGB(24, 27, 38)
PlayerRow.BorderSizePixel = 0
PlayerRow.Parent = Main

local PRCorner = Instance.new("UICorner")
PRCorner.CornerRadius = UDim.new(0, 7)
PRCorner.Parent = PlayerRow

local PlayerIcon = Instance.new("TextLabel")
PlayerIcon.Size = UDim2.new(0, 30, 1, 0)
PlayerIcon.Position = UDim2.new(0, 2, 0, 0)
PlayerIcon.BackgroundTransparency = 1
PlayerIcon.Text = "👥"
PlayerIcon.TextColor3 = Color3.fromRGB(120, 180, 255)
PlayerIcon.Font = Enum.Font.GothamBold
PlayerIcon.TextSize = 14
PlayerIcon.Parent = PlayerRow

local PlayerLabel = Instance.new("TextLabel")
PlayerLabel.Size = UDim2.new(1, -100, 1, 0)
PlayerLabel.Position = UDim2.new(0, 34, 0, 0)
PlayerLabel.BackgroundTransparency = 1
PlayerLabel.Text = "Số người"
PlayerLabel.TextColor3 = Color3.fromRGB(160, 170, 200)
PlayerLabel.Font = Enum.Font.Gotham
PlayerLabel.TextSize = 10
PlayerLabel.TextXAlignment = Enum.TextXAlignment.Left
PlayerLabel.Parent = PlayerRow

local PlayerValue = Instance.new("TextLabel")
PlayerValue.Size = UDim2.new(0, 60, 1, 0)
PlayerValue.Position = UDim2.new(1, -66, 0, 0)
PlayerValue.BackgroundTransparency = 1
PlayerValue.Text = "1"
PlayerValue.TextColor3 = Color3.fromRGB(120, 255, 160)
PlayerValue.Font = Enum.Font.GothamBold
PlayerValue.TextSize = 13
PlayerValue.TextXAlignment = Enum.TextXAlignment.Right
PlayerValue.Parent = PlayerRow

local StatusRow = Instance.new("Frame")
StatusRow.Size = UDim2.new(1, -24, 0, 30)
StatusRow.Position = UDim2.new(0, 12, 0, 76)
StatusRow.BackgroundColor3 = Color3.fromRGB(24, 27, 38)
StatusRow.BorderSizePixel = 0
StatusRow.Parent = Main

local SRCorner = Instance.new("UICorner")
SRCorner.CornerRadius = UDim.new(0, 7)
SRCorner.Parent = StatusRow

local StatusDot = Instance.new("Frame")
StatusDot.Size = UDim2.new(0, 8, 0, 8)
StatusDot.Position = UDim2.new(0, 12, 0.5, -4)
StatusDot.BackgroundColor3 = Color3.fromRGB(60, 220, 120)
StatusDot.BorderSizePixel = 0
StatusDot.Parent = StatusRow

local DotCorner = Instance.new("UICorner")
DotCorner.CornerRadius = UDim.new(1, 0)
DotCorner.Parent = StatusDot

local DotPulse = Instance.new("Frame")
DotPulse.Size = UDim2.new(1, 0, 1, 0)
DotPulse.BackgroundColor3 = Color3.fromRGB(60, 220, 120)
DotPulse.BackgroundTransparency = 0.6
DotPulse.BorderSizePixel = 0
DotPulse.Parent = StatusDot

local PulseCorner = Instance.new("UICorner")
PulseCorner.CornerRadius = UDim.new(1, 0)
PulseCorner.Parent = DotPulse

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

local StatusLabel = Instance.new("TextLabel")
StatusLabel.Size = UDim2.new(1, -100, 1, 0)
StatusLabel.Position = UDim2.new(0, 26, 0, 0)
StatusLabel.BackgroundTransparency = 1
StatusLabel.Text = "Đang chạy"
StatusLabel.TextColor3 = Color3.fromRGB(160, 170, 200)
StatusLabel.Font = Enum.Font.Gotham
StatusLabel.TextSize = 10
StatusLabel.TextXAlignment = Enum.TextXAlignment.Left
StatusLabel.Parent = StatusRow

local StatusValue = Instance.new("TextLabel")
StatusValue.Size = UDim2.new(0, 60, 1, 0)
StatusValue.Position = UDim2.new(1, -66, 0, 0)
StatusValue.BackgroundTransparency = 1
StatusValue.Text = "ON"
StatusValue.TextColor3 = Color3.fromRGB(120, 255, 160)
StatusValue.Font = Enum.Font.GothamBold
StatusValue.TextSize = 11
StatusValue.TextXAlignment = Enum.TextXAlignment.Right
StatusValue.Parent = StatusRow

local function setStatus(text, color, state)
    StatusLabel.Text = text
    StatusValue.Text = state or ""
    StatusValue.TextColor3 = color or Color3.fromRGB(120, 255, 160)
    StatusDot.BackgroundColor3 = color or Color3.fromRGB(60, 220, 120)
    DotPulse.BackgroundColor3 = color or Color3.fromRGB(60, 220, 120)
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

local function requestPage(cursor)
    if not http then return nil end
    local cursorParam = cursor
    if type(cursorParam) ~= "string" or cursorParam == "" then
        cursorParam = ""
    end
    local url = string.format(
        "https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100&cursor=%s",
        PLACE_ID, cursorParam
    )
    for attempt = 1, 2 do
        local ok, res = pcall(function()
            return http({ Url = url, Method = "GET", Headers = { ["Accept"] = "application/json" } })
        end)
        if ok and res then
            local body = res.Body or res.body
            if type(body) == "string" and #body > 0 then
                local ok2, data = pcall(function()
                    return HttpService:JSONDecode(body)
                end)
                if ok2 and type(data) == "table" and type(data.data) == "table" then
                    return data
                end
            end
        end
        task.wait(0.15)
    end
    return nil
end

local function collectFromData(data, targetPlaying, result, lockRef)
    if not data or type(data.data) ~= "table" then return 0 end
    local added = 0
    for _, s in ipairs(data.data) do
        if type(s) == "table" then
            local pc = tonumber(s.playing) or 0
            local id = s.id
            if type(id) == "string" and id ~= JOB_ID and not Blacklist[id] and pc == targetPlaying then
                while lockRef[1] do task.wait() end
                lockRef[1] = true
                if not result[id] then
                    result[id] = {
                        id = id,
                        ping = tonumber(s.ping) or 999,
                        fps = tonumber(s.fps) or 60,
                        playing = pc,
                        max = tonumber(s.maxPlayers) or 12,
                    }
                    added = added + 1
                end
                lockRef[1] = false
            end
        end
    end
    return added
end

local function parallelScan(targetPlaying)
    local result = {}
    local lockRef = {false}

    local first = requestPage("")
    if not first then return result end
    collectFromData(first, targetPlaying, result, lockRef)

    local rootCursor = first.nextPageCursor
    if not rootCursor or rootCursor == "" or rootCursor == "null" or type(rootCursor) ~= "string" then
        return result
    end

    local branchCursors = { rootCursor }
    for i = 1, CONFIG.ParallelBranches - 1 do
        local cur = branchCursors[i]
        if cur then
            local data = requestPage(cur)
            if data then
                collectFromData(data, targetPlaying, result, lockRef)
                if data.nextPageCursor and data.nextPageCursor ~= "" and data.nextPageCursor ~= "null" then
                    branchCursors[i + 1] = data.nextPageCursor
                else
                    break
                end
            end
        end
    end

    local activeBranches = {}
    for i = 1, CONFIG.ParallelBranches do
        if branchCursors[i] then
            table.insert(activeBranches, branchCursors[i])
        end
    end

    if #activeBranches == 0 then
        return result
    end

    local pagesPerBranch = math.max(2, math.floor(CONFIG.MaxPages / #activeBranches))
    local threads = {}

    for idx = 1, #activeBranches do
        local startCursor = activeBranches[idx]
        table.insert(threads, task.spawn(function()
            local cursor = startCursor
            local pages = 0
            local failCount = 0
            while pages < pagesPerBranch do
                local data = requestPage(cursor)
                if not data then
                    failCount = failCount + 1
                    if failCount >= 2 then break end
                    task.wait(0.2)
                else
                    failCount = 0
                    collectFromData(data, targetPlaying, result, lockRef)
                    local nc = data.nextPageCursor
                    if not nc or nc == "" or nc == "null" or type(nc) ~= "string" then break end
                    cursor = nc
                    pages = pages + 1
                    if CONFIG.PageDelay > 0 then task.wait(CONFIG.PageDelay) end
                end
            end
        end))
    end

    local startTime = tick()
    while tick() - startTime < 6 do
        local allDone = true
        for _, t in ipairs(threads) do
            local status = coroutine.status(t)
            if status ~= "dead" then
                allDone = false
                break
            end
        end
        if allDone then break end
        task.wait(0.05)
    end

    return result
end

local function calculateScore(server, stabilityBonus)
    local fpsScore = math.max(0, 60 - server.fps) * 2
    local pingScore = math.min(server.ping, 500) / 4
    local stabilityScore = stabilityBonus * 100
    return 1000 + fpsScore + pingScore + stabilityScore
end

local function attemptTeleport(jobId)
    local ok1 = pcall(function()
        local opts = Instance.new("TeleportOptions")
        opts.ServerInstanceId = jobId
        TeleportService:TeleportAsync(PLACE_ID, {LocalPlayer}, opts)
    end)
    if ok1 then return true, "async" end

    local ok2 = pcall(function()
        TeleportService:TeleportToPlaceInstance(PLACE_ID, jobId, LocalPlayer)
    end)
    if ok2 then return true, "place3" end

    local ok3 = pcall(function()
        TeleportService:TeleportToPlaceInstance(PLACE_ID, jobId)
    end)
    if ok3 then return true, "place2" end

    return false, nil
end

local function verifyServerExists(jobId)
    if not http then return true end
    local cursor = ""
    local pages = 0
    while pages < 8 do
        local data = requestPage(cursor)
        if not data then return true end
        if type(data.data) == "table" then
            for _, s in ipairs(data.data) do
                if type(s) == "table" and s.id == jobId then
                    local pc = tonumber(s.playing) or 0
                    if pc >= 1 and pc <= CONFIG.MaxPlayerFilter then
                        return true
                    end
                    return false
                end
            end
        end
        local nc = data.nextPageCursor
        if not nc or nc == "" or nc == "null" then break end
        cursor = nc
        pages = pages + 1
    end
    return true
end

local function teleportWithVerify(target)
    if not target or type(target.id) ~= "string" then
        return false, "invalid_target"
    end

    local verified = false
    for _ = 1, 2 do
        if verifyServerExists(target.id) then
            verified = true
            break
        end
        task.wait(0.3)
    end

    if not verified then
        Blacklist[target.id] = true
        return false, "verify_fail"
    end

    TeleportPending = true
    local originalJob = game.JobId

    local ok, method = attemptTeleport(target.id)
    if not ok then
        TeleportPending = false
        Blacklist[target.id] = true
        return false, "teleport_call_fail"
    end

    local startTime = tick()
    while tick() - startTime < CONFIG.TeleportTimeout do
        if game.JobId ~= originalJob then
            TeleportPending = false
            return true, method
        end
        task.wait(0.3)
    end

    TeleportPending = false
    Blacklist[target.id] = true
    return false, "stuck"
end

local function scanForOnePlayer()
    local pass1 = parallelScan(1)
    local count1 = 0
    for _ in pairs(pass1) do count1 = count1 + 1 end

    if count1 == 0 then
        task.wait(0.3)
        local pass1b = parallelScan(2)
        local count1b = 0
        for _ in pairs(pass1b) do count1b = count1b + 1 end
        if count1b == 0 then return nil, nil end

        task.wait(CONFIG.PassDelay)
        local pass2b = parallelScan(2)

        local stableB = {}
        for id, s in pairs(pass2b) do
            if pass1b[id] then
                s.stability = 2
                if s.playing == pass1b[id].playing then
                    s.stability = 3
                end
                table.insert(stableB, s)
            end
        end

        if #stableB == 0 then
            for id, s in pairs(pass1b) do
                s.stability = 1
                table.insert(stableB, s)
            end
        end

        task.wait(CONFIG.ConfirmDelay)
        local finalPoolB = {}
        for _, s in ipairs(stableB) do
            s.score = calculateScore(s, s.stability)
            table.insert(finalPoolB, s)
        end

        table.sort(finalPoolB, function(a, b)
            if a.stability ~= b.stability then
                return a.stability > b.stability
            end
            return a.score > b.score
        end)

        if #finalPoolB == 0 then return nil, nil end
        local topCount = math.min(5, #finalPoolB)
        return finalPoolB[math.random(1, topCount)], "2"
    end

    task.wait(CONFIG.PassDelay)

    local pass2 = parallelScan(1)

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

    if #finalPool == 0 then return nil, nil end
    local topCount = math.min(5, #finalPool)
    return finalPool[math.random(1, topCount)], "1"
end

local function performHop()
    if IsScanning or IsHopping then return end
    IsScanning = true

    setStatus("Đang quét server...", Color3.fromRGB(255, 200, 100), "...")

    if not http then
        IsScanning = false
        setStatus("Lỗi HTTP", Color3.fromRGB(255, 100, 100), "OFF")
        return
    end

    local target, targetMode = scanForOnePlayer()

    if not target then
        IsScanning = false
        setStatus("Không có server", Color3.fromRGB(255, 120, 120), "FAIL")
        task.wait(5)
        setStatus("Đang chạy", Color3.fromRGB(120, 255, 160), "ON")
        return
    end

    local modeText = targetMode == "1" and "1 người" or "2 người"
    setStatus("Vào server " .. modeText, Color3.fromRGB(120, 255, 160), "HOP")

    task.wait(CONFIG.PreTeleportDelay)

    IsScanning = false
    IsHopping = true
    TargetTotal = target.playing + 1
    Blacklist[target.id] = true

    local success = false
    for attempt = 1, CONFIG.MaxTeleportAttempts do
        local ok = teleportWithVerify(target)
        if ok then
            success = true
            break
        end
        task.wait(1)
    end

    IsHopping = false
    if success then
        setStatus("Đang chạy", Color3.fromRGB(120, 255, 160), "ON")
    else
        setStatus("Vào thất bại · thử lại", Color3.fromRGB(255, 180, 100), "RETRY")
        task.wait(2)
        performHop()
    end
end

local function startMonitor()
    if MonitorConn then MonitorConn:Disconnect() end
    MonitorConn = RunService.Heartbeat:Connect(function()
        if not AutoEnabled then return end
        if IsHopping or IsScanning or TeleportPending then return end

        local count = #Players:GetPlayers()
        if count == LastPlayerCount then return end
        LastPlayerCount = count

        if count > CONFIG.MaxTotalAllowed then
            setStatus("Server " .. count .. " người · chờ " .. CONFIG.AutoHopDelay .. "s", Color3.fromRGB(255, 200, 120), "...")

            task.spawn(function()
                for i = CONFIG.AutoHopDelay, 1, -1 do
                    if not AutoEnabled then return end
                    local cnt = #Players:GetPlayers()
                    if cnt <= CONFIG.MaxTotalAllowed then
                        setStatus("Đã về " .. cnt .. " người", Color3.fromRGB(120, 255, 160), "ON")
                        return
                    end
                    setStatus("Hop sau " .. i .. "s · " .. cnt .. " người", Color3.fromRGB(255, 180, 100), "...")
                    task.wait(1)
                end

                if #Players:GetPlayers() > CONFIG.MaxTotalAllowed then
                    performHop()
                end
            end)
        else
            setStatus("Server " .. count .. " người · ổn", Color3.fromRGB(120, 255, 160), "ON")
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

updatePlayerCount()
setStatus("Đang chạy", Color3.fromRGB(120, 255, 160), "ON")
startMonitor()

task.spawn(function()
    task.wait(2)
    local count = #Players:GetPlayers()
    if count > CONFIG.MaxTotalAllowed then
        performHop()
    end
end)

if _G.PHANTOM_LOADED then
    return
end
_G.PHANTOM_LOADED = true

local VERSION = "13.4.1"
local APP_NAME = "PHANTOM ⚡"

local SCAN_MAX_PAGES = 40
local SCAN_BRANCHES = 10
local SCAN_PASSES = 2
local MIN_PASS_DELAY = 0.4
local PAGE_DELAY_MIN = 0.005
local PAGE_DELAY_MAX = 0.15
local PAGE_DELAY_START = 0.01
local SCAN_TIMEOUT = 20
local API_RETRY = 2
local VERIFY_MAX_PAGES = 6
local VERIFY_RETRY = 1
local VERIFY_TIMEOUT = 12
local MAX_QUEUE = 100
local MIN_QUEUE = 5
local REFILL_AT = 3
local HOP_ATTEMPTS = 15
local MAX_BLACKLIST = 120
local MAX_FAIL_STREAK = 6
local PRE_TELEPORT_DELAY = 0.1
local POST_TELEPORT_WAIT = 1.2
local JOBID_CONFIRM_TIMEOUT = 8
local WATCHDOG_STEP = 2
local WATCHDOG_HOP_TIMEOUT = 15
local WATCHDOG_FILL_TIMEOUT = 15
local MONITOR_STEP = 0.5
local HOP_COUNTDOWN = 3
local LOG_LIMIT = 50
local SCORE_ONE = 1000
local SCORE_TWO = 200
local SCORE_THREE = 50
local SCORE_STABILITY = 100
local MIN_STABILITY = 1
local EARLY_STOP_PAGE = 5
local EARLY_STOP_FOUND = 40

local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local CoreGuiService = game:GetService("CoreGui")
local StarterGuiService = game:GetService("StarterGui")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local WaitStart = os.clock()
while not LocalPlayer and os.clock() - WaitStart < 5 do
    task.wait(0.1)
    LocalPlayer = Players.LocalPlayer
end
if not game:IsLoaded() then
    game.Loaded:Wait()
end

local PlaceId = game.PlaceId
local CurrentJobId = game.JobId

local HttpRequest = nil
pcall(function()
    if syn and syn.request then
        HttpRequest = syn.request
    elseif http and http.request then
        HttpRequest = http.request
    elseif fluxus and fluxus.request then
        HttpRequest = fluxus.request
    elseif http_request then
        HttpRequest = http_request
    elseif request then
        HttpRequest = request
    end
end)

local IsScanning = false
local IsHopping = false
local ScanCancelled = false
local AutoEnabled = true
local ScanStartedAt = 0
local HopStartedAt = 0
local HopProgressAt = 0
local FillStartedAt = 0
local FoundServers = {}
local FoundCount = 0
local ServerQueue = {}
local BlacklistTable = {}
local BlacklistCount = 0
local FailStreak = 0
local MergeLock = false
local CurrentPageDelay = PAGE_DELAY_START
local ApiErrorStreak = 0
local TeleportFailed = false
local TeleportFailMsg = ""
local LogBuffer = {}
local LogEnabled = true
local LastHopInfo = ""
local UiStatusLabel = nil
local UiInfoLabel = nil
local UiLogLabel = nil

local function safeNum(value, fallback)
    local n = tonumber(value)
    if n == nil or n ~= n then
        return fallback or 0
    end
    return n
end

local function safeStr(value, fallback)
    if type(value) == "string" and value ~= "" then
        return value
    end
    if value ~= nil then
        return tostring(value)
    end
    return fallback or ""
end

local function addLog(level, msg)
    if not LogEnabled then
        return
    end
    local line = string.format("[%s][%s] %s", os.date("%H:%M:%S"), level, msg)
    table.insert(LogBuffer, line)
    if #LogBuffer > LOG_LIMIT then
        table.remove(LogBuffer, 1)
    end
    pcall(function()
        print(line)
    end)
    pcall(function()
        if UiLogLabel then
            UiLogLabel.Text = line
        end
    end)
end

local function setStatus(text)
    pcall(function()
        if UiStatusLabel then
            UiStatusLabel.Text = text
        end
    end)
end

local function blacklistAdd(jobId)
    if jobId == "" or jobId == CurrentJobId then
        return
    end
    if not BlacklistTable[jobId] then
        BlacklistTable[jobId] = true
        BlacklistCount = BlacklistCount + 1
    end
    if BlacklistCount > MAX_BLACKLIST then
        BlacklistTable = {}
        BlacklistCount = 0
        addLog("WARN", "Blacklist quá tải, đã reset")
    end
end

local function blacklistHas(jobId)
    return BlacklistTable[jobId] == true
end

local function blacklistReset()
    BlacklistTable = {}
    BlacklistCount = 0
    addLog("WARN", "Blacklist đã reset")
end

local function httpGet(url)
    if HttpRequest then
        local ok, res = pcall(function()
            return HttpRequest({Url = url, Method = "GET"})
        end)
        if ok and res and res.Body then
            return res.Body
        end
    end
    local ok2, body = pcall(function()
        return game:HttpGet(url, true)
    end)
    if ok2 and type(body) == "string" and body ~= "" then
        return body
    end
    return nil
end

local function throttleSuccess()
    ApiErrorStreak = 0
    if CurrentPageDelay > PAGE_DELAY_MIN then
        CurrentPageDelay = math.max(PAGE_DELAY_MIN, CurrentPageDelay * 0.8)
    end
end

local function throttleFail()
    ApiErrorStreak = ApiErrorStreak + 1
    if CurrentPageDelay < PAGE_DELAY_MAX then
        CurrentPageDelay = math.min(PAGE_DELAY_MAX, CurrentPageDelay * 1.5)
    end
end

local function fetchServerPage(cursor, sortOrder)
    local url = "https://games.roblox.com/v1/games/" .. tostring(PlaceId) .. "/servers/Public?sortOrder=" .. sortOrder .. "&limit=100"
    if cursor and cursor ~= "" then
        url = url .. "&cursor=" .. HttpService:UrlEncode(cursor)
    end
    local body = httpGet(url)
    if not body then
        return nil, "HTTP_FAIL"
    end
    local ok, data = pcall(function()
        return HttpService:JSONDecode(body)
    end)
    if not ok or type(data) ~= "table" then
        return nil, "DECODE_FAIL"
    end
    if data.errors then
        return nil, "API_ERROR"
    end
    return data, nil
end

local function fetchPageRetry(cursor, sortOrder)
    for attempt = 1, API_RETRY do
        local data, err = fetchServerPage(cursor, sortOrder)
        if data then
            throttleSuccess()
            return data, nil
        end
        throttleFail()
        if err == "DECODE_FAIL" then
            return nil, err
        end
        task.wait(0.05)
    end
    return nil, "RETRY_EXHAUSTED"
end

local function mergeFound(server, passIndex)
    local id = safeStr(server.id)
    if id == "" or id == CurrentJobId then
        return
    end
    if blacklistHas(id) then
        return
    end
    local playing = safeNum(server.playing, -1)
    if playing < 1 or playing > 2 then
        return
    end
    local entry = FoundServers[id]
    if not entry then
        entry = {
            Id = id,
            Playing = playing,
            Fps = safeNum(server.fps, 60),
            Ping = safeNum(server.ping, 0),
            Passes = {},
            Stability = 1,
            Score = 0
        }
        FoundServers[id] = entry
        FoundCount = FoundCount + 1
    end
    entry.Passes[passIndex] = true
    local seen = 0
    for _ in pairs(entry.Passes) do
        seen = seen + 1
    end
    entry.Stability = seen >= 2 and 3 or 1
    entry.Playing = playing
    entry.Fps = safeNum(server.fps, entry.Fps)
    entry.Ping = safeNum(server.ping, entry.Ping)
end

local function scanBranch(branchIndex, passIndex, sortOrder)
    local cursor = nil
    local previousCursor = "___"
    for page = 1, SCAN_MAX_PAGES do
        if ScanCancelled then
            return
        end
        local data, err = fetchPageRetry(cursor, sortOrder)
        if not data then
            return
        end
        local list = data.data
        if type(list) ~= "table" or #list == 0 then
            return
        end
        for _, server in ipairs(list) do
            mergeFound(server, passIndex)
        end
        if page >= EARLY_STOP_PAGE and FoundCount >= EARLY_STOP_FOUND then
            return
        end
        local nextCursor = data.nextPageCursor
        if nextCursor == nil or nextCursor == "" or nextCursor == cursor or nextCursor == previousCursor then
            return
        end
        previousCursor = cursor or "___"
        cursor = nextCursor
        if CurrentPageDelay > 0 then
            task.wait(CurrentPageDelay)
        end
    end
end

local function scoreServer(entry)
    local score = 0
    if entry.Playing == 1 then
        score = score + SCORE_ONE
    elseif entry.Playing == 2 then
        score = score + SCORE_TWO
    else
        score = score + SCORE_THREE
    end
    score = score + math.max(0, 120 - safeNum(entry.Fps, 60))
    score = score + math.min(500, safeNum(entry.Ping, 0))
    score = score + entry.Stability * SCORE_STABILITY
    return score
end

local function queueSort()
    table.sort(ServerQueue, function(a, b)
        if a.Stability ~= b.Stability then
            return a.Stability > b.Stability
        end
        return a.Score > b.Score
    end)
end

local function queueContains(jobId)
    for i = 1, #ServerQueue do
        if ServerQueue[i].Id == jobId then
            return true
        end
    end
    return false
end

local function rebuildQueue()
    local candidates = {}
    for _, entry in pairs(FoundServers) do
        if entry.Playing >= 1 and entry.Playing <= 2 then
            if entry.Id ~= CurrentJobId and not blacklistHas(entry.Id) then
                if entry.Stability >= MIN_STABILITY and not queueContains(entry.Id) then
                    entry.Score = scoreServer(entry)
                    table.insert(candidates, entry)
                end
            end
        end
    end
    table.sort(candidates, function(a, b)
        if a.Stability ~= b.Stability then
            return a.Stability > b.Stability
        end
        return a.Score > b.Score
    end)
    local added = 0
    for _, entry in ipairs(candidates) do
        if #ServerQueue >= MAX_QUEUE then
            break
        end
        table.insert(ServerQueue, entry)
        added = added + 1
    end
    queueSort()
    return added
end

local function runScan()
    if IsScanning then
        return
    end
    IsScanning = true
    ScanCancelled = false
    ScanStartedAt = os.clock()
    FoundServers = {}
    FoundCount = 0
    setStatus("Đang dò server...")
    addLog("INFO", "Bắt đầu quét server")
    for pass = 1, SCAN_PASSES do
        local doneCount = 0
        for branch = 1, SCAN_BRANCHES do
            local sortOrder = "Asc"
            if branch % 2 == 0 then
                sortOrder = "Desc"
            end
            task.spawn(function()
                local ok = pcall(function()
                    scanBranch(branch, pass, sortOrder)
                end)
                doneCount = doneCount + 1
            end)
        end
        while doneCount < SCAN_BRANCHES do
            if os.clock() - ScanStartedAt > SCAN_TIMEOUT then
                ScanCancelled = true
                break
            end
            task.wait(0.05)
        end
        if ScanCancelled then
            break
        end
        if pass < SCAN_PASSES and FoundCount < MIN_QUEUE then
            setStatus("Đang phân tích...")
            task.wait(MIN_PASS_DELAY)
        end
    end
    local added = rebuildQueue()
    IsScanning = false
    ScanCancelled = false
    setStatus("Đã xác định server ít người")
    addLog("INFO", "Quét xong: " .. FoundCount .. " server, queue +" .. added)
end

local function ensureScan()
    if IsScanning then
        return
    end
    if #ServerQueue >= MIN_QUEUE then
        return
    end
    FillStartedAt = os.clock()
    task.spawn(function()
        local ok = pcall(runScan)
        if not ok then
            IsScanning = false
        end
    end)
end

local function verifyServer(jobId)
    local deadline = os.clock() + VERIFY_TIMEOUT
    for attempt = 1, VERIFY_RETRY do
        local cursor = nil
        for page = 1, VERIFY_MAX_PAGES do
            if os.clock() > deadline then
                return nil
            end
            local data = fetchServerPage(cursor, "Asc")
            if not data then
                break
            end
            local list = data.data
            if type(list) ~= "table" or #list == 0 then
                break
            end
            for _, server in ipairs(list) do
                if safeStr(server.id) == jobId then
                    local playing = safeNum(server.playing, -1)
                    if playing >= 1 and playing <= 2 then
                        return true
                    end
                    return false
                end
            end
            local nextCursor = data.nextPageCursor
            if nextCursor == nil or nextCursor == "" or nextCursor == cursor then
                break
            end
            cursor = nextCursor
        end
    end
    return nil
end

local function teleportToServer(jobId)
    local okMain = pcall(function()
        TeleportService:TeleportToPlaceInstance(PlaceId, jobId, LocalPlayer)
    end)
    if okMain then
        return true
    end
    task.wait(0.1)
    local okOpt = pcall(function()
        local options = Instance.new("TeleportOptions")
        options.ServerInstanceId = jobId
        TeleportService:TeleportAsync(PlaceId, {LocalPlayer}, options)
    end)
    if okOpt then
        return true
    end
    task.wait(0.1)
    local okPlain = pcall(function()
        TeleportService:TeleportAsync(PlaceId, {LocalPlayer})
    end)
    if okPlain then
        return true
    end
    return false
end

pcall(function()
    TeleportService.TeleportInitFailed:Connect(function(player, result, message)
        if player == LocalPlayer then
            TeleportFailed = true
            TeleportFailMsg = safeStr(result) .. " " .. safeStr(message)
        end
    end)
end)

local function doHop()
    if IsHopping then
        return
    end
    IsHopping = true
    HopStartedAt = os.clock()
    HopProgressAt = os.clock()
    setStatus("Đang check qua server hiện có")
    local attempts = 0
    while attempts < HOP_ATTEMPTS and IsHopping do
        if #ServerQueue == 0 then
            break
        end
        local target = table.remove(ServerQueue, 1)
        if target and not blacklistHas(target.Id) and target.Id ~= CurrentJobId then
            attempts = attempts + 1
            HopProgressAt = os.clock()
            setStatus("Đang xác nhận...")
            local verdict = verifyServer(target.Id)
            HopProgressAt = os.clock()
            if verdict == false then
                blacklistAdd(target.Id)
            else
                blacklistAdd(target.Id)
                setStatus("Đã xác định server ít người")
                if PRE_TELEPORT_DELAY > 0 then
                    task.wait(PRE_TELEPORT_DELAY)
                end
                setStatus("Đang tạo cổng kết nối")
                TeleportFailed = false
                TeleportFailMsg = ""
                teleportToServer(target.Id)
                setStatus("Đang vào")
                LastHopInfo = target.Id .. " | " .. tostring(target.Playing) .. " người | Ping " .. tostring(target.Ping)
                if POST_TELEPORT_WAIT > 0 then
                    task.wait(POST_TELEPORT_WAIT)
                end
                HopProgressAt = os.clock()
                local deadline = os.clock() + (JOBID_CONFIRM_TIMEOUT - POST_TELEPORT_WAIT)
                local joined = false
                while os.clock() < deadline do
                    local nowJob = game.JobId
                    if nowJob ~= "" and nowJob ~= CurrentJobId then
                        joined = true
                        break
                    end
                    if TeleportFailed then
                        break
                    end
                    task.wait(0.25)
                end
                if joined then
                    FailStreak = 0
                    CurrentJobId = game.JobId
                    IsHopping = false
                    setStatus("Vào server " .. tostring(target.Playing) .. " người...")
                    addLog("INFO", "Hop thành công")
                    return
                end
                FailStreak = FailStreak + 1
                local reason = TeleportFailed and TeleportFailMsg or "Timeout"
                local lowerReason = string.lower(reason)
                if string.find(lowerReason, "771") or string.find(lowerReason, "no longer") then
                    addLog("WARN", "Server đã đóng")
                end
                addLog("ERR", "Hop thất bại (" .. attempts .. ")")
                setStatus("Lỗi vào server, thử lại")
                if FailStreak >= MAX_FAIL_STREAK then
                    blacklistReset()
                    FailStreak = 0
                end
                if #ServerQueue >= REFILL_AT then
                    HopProgressAt = os.clock()
                else
                    task.wait(0.2)
                    HopProgressAt = os.clock()
                end
            end
        end
    end
    IsHopping = false
    setStatus("Đang dò server...")
    ensureScan()
end

local function monitorLoop()
    while true do
        task.wait(MONITOR_STEP)
        local ok = pcall(function()
            if not AutoEnabled then
                return
            end
            if IsHopping or IsScanning then
                return
            end
            local count = #Players:GetPlayers()
            if count >= 3 then
                local stillCrowded = true
                for i = 1, HOP_COUNTDOWN do
                    setStatus("Có " .. count .. " người, hop sau " .. tostring(HOP_COUNTDOWN - i + 1) .. "s")
                    task.wait(1)
                    if #Players:GetPlayers() <= 2 then
                        stillCrowded = false
                        break
                    end
                end
                if stillCrowded and #Players:GetPlayers() >= 3 and not IsHopping then
                    if #ServerQueue < REFILL_AT then
                        setStatus("Đang dò server...")
                        ensureScan()
                        local waitDeadline = os.clock() + SCAN_TIMEOUT
                        while IsScanning and os.clock() < waitDeadline do
                            task.wait(0.25)
                        end
                    end
                    if #ServerQueue > 0 and not IsHopping then
                        doHop()
                    end
                end
            else
                if #ServerQueue < REFILL_AT and not IsScanning then
                    ensureScan()
                end
            end
        end)
    end
end

local function watchdogLoop()
    while true do
        task.wait(WATCHDOG_STEP)
        pcall(function()
            if IsScanning and os.clock() - ScanStartedAt > SCAN_TIMEOUT then
                ScanCancelled = true
                IsScanning = false
                setStatus("Quét bị kẹt, đã reset")
            end
            if IsHopping and os.clock() - HopProgressAt > WATCHDOG_HOP_TIMEOUT then
                IsHopping = false
                setStatus("Hop bị kẹt, đã reset")
            end
            if FillStartedAt > 0 and #ServerQueue < MIN_QUEUE and not IsScanning then
                if os.clock() - FillStartedAt > WATCHDOG_FILL_TIMEOUT then
                    FillStartedAt = 0
                    ensureScan()
                end
            end
            if FailStreak >= MAX_FAIL_STREAK then
                blacklistReset()
                FailStreak = 0
            end
            local nowJob = game.JobId
            if nowJob ~= "" and nowJob ~= CurrentJobId then
                CurrentJobId = nowJob
            end
        end)
    end
end

local function makeDraggable(frame)
    local dragging = false
    local dragStart = nil
    local startPos = nil
    frame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = frame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)
    frame.InputChanged:Connect(function(input)
        if not dragging then
            return
        end
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            local delta = input.Position - dragStart
            frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
end

local function createButton(parent, name, text, position, color)
    local button = Instance.new("TextButton")
    button.Name = name
    button.Size = UDim2.new(0.5, -15, 0, 28)
    button.Position = position
    button.BackgroundColor3 = color
    button.Text = text
    button.TextColor3 = Color3.fromRGB(255, 255, 255)
    button.Font = Enum.Font.GothamBold
    button.TextSize = 13
    button.AutoButtonColor = true
    button.Parent = parent
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = button
    return button
end

local function buildUi()
    local parent = nil
    pcall(function()
        if gethui then
            parent = gethui()
        end
    end)
    if not parent then
        parent = CoreGuiService
    end
    if not parent and LocalPlayer then
        parent = LocalPlayer:WaitForChild("PlayerGui", 5)
    end
    if not parent then
        return
    end
    pcall(function()
        local old = parent:FindFirstChild("PHANTOM_UI")
        if old then
            old:Destroy()
        end
    end)

    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "PHANTOM_UI"
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

    local mainFrame = Instance.new("Frame")
    mainFrame.Name = "MainFrame"
    mainFrame.Size = UDim2.new(0, 300, 0, 210)
    mainFrame.Position = UDim2.new(0.5, -150, 0.1, 0)
    mainFrame.BackgroundColor3 = Color3.fromRGB(18, 18, 26)
    mainFrame.BorderSizePixel = 0
    mainFrame.Active = true
    mainFrame.Parent = screenGui

    local frameCorner = Instance.new("UICorner")
    frameCorner.CornerRadius = UDim.new(0, 10)
    frameCorner.Parent = mainFrame

    local frameStroke = Instance.new("UIStroke")
    frameStroke.Color = Color3.fromRGB(120, 90, 255)
    frameStroke.Thickness = 1.5
    frameStroke.Parent = mainFrame

    local titleLabel = Instance.new("TextLabel")
    titleLabel.Size = UDim2.new(1, -20, 0, 28)
    titleLabel.Position = UDim2.new(0, 10, 0, 6)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = APP_NAME .. "  v" .. VERSION
    titleLabel.TextColor3 = Color3.fromRGB(230, 225, 255)
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.TextSize = 16
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.Parent = mainFrame

    local statusPill = Instance.new("TextLabel")
    statusPill.Size = UDim2.new(1, -20, 0, 26)
    statusPill.Position = UDim2.new(0, 10, 0, 38)
    statusPill.BackgroundColor3 = Color3.fromRGB(38, 36, 60)
    statusPill.Text = "Đang khởi động"
    statusPill.TextColor3 = Color3.fromRGB(180, 220, 255)
    statusPill.Font = Enum.Font.GothamMedium
    statusPill.TextSize = 13
    statusPill.Parent = mainFrame

    local pillCorner = Instance.new("UICorner")
    pillCorner.CornerRadius = UDim.new(1, 0)
    pillCorner.Parent = statusPill

    local infoLabel = Instance.new("TextLabel")
    infoLabel.Size = UDim2.new(1, -20, 0, 22)
    infoLabel.Position = UDim2.new(0, 10, 0, 70)
    infoLabel.BackgroundTransparency = 1
    infoLabel.Text = "Người: 1 | Queue: 0 | Ban: 0"
    infoLabel.TextColor3 = Color3.fromRGB(200, 200, 210)
    infoLabel.Font = Enum.Font.Gotham
    infoLabel.TextSize = 12
    infoLabel.TextXAlignment = Enum.TextXAlignment.Left
    infoLabel.Parent = mainFrame

    local autoButton = createButton(mainFrame, "AutoButton", "AUTO: ON", UDim2.new(0, 10, 0, 100), Color3.fromRGB(40, 140, 80))
    local hopButton = createButton(mainFrame, "HopButton", "Hop ngay", UDim2.new(0.5, 5, 0, 100), Color3.fromRGB(90, 70, 200))
    local copyButton = createButton(mainFrame, "CopyButton", "Copy JobId", UDim2.new(0, 10, 0, 136), Color3.fromRGB(60, 90, 140))
    local logButton = createButton(mainFrame, "LogButton", "Log: ON", UDim2.new(0.5, 5, 0, 136), Color3.fromRGB(80, 80, 95))

    local logLabel = Instance.new("TextLabel")
    logLabel.Size = UDim2.new(1, -20, 0, 30)
    logLabel.Position = UDim2.new(0, 10, 0, 172)
    logLabel.BackgroundTransparency = 1
    logLabel.Text = ""
    logLabel.TextColor3 = Color3.fromRGB(140, 140, 160)
    logLabel.Font = Enum.Font.Code
    logLabel.TextSize = 10
    logLabel.TextXAlignment = Enum.TextXAlignment.Left
    logLabel.TextTruncate = Enum.TextTruncate.AtEnd
    logLabel.Parent = mainFrame

    UiStatusLabel = statusPill
    UiInfoLabel = infoLabel
    UiLogLabel = logLabel

    makeDraggable(mainFrame)

    autoButton.MouseButton1Click:Connect(function()
        AutoEnabled = not AutoEnabled
        if AutoEnabled then
            autoButton.Text = "AUTO: ON"
            autoButton.BackgroundColor3 = Color3.fromRGB(40, 140, 80)
            setStatus("Auto đã bật")
        else
            autoButton.Text = "AUTO: OFF"
            autoButton.BackgroundColor3 = Color3.fromRGB(120, 50, 60)
            setStatus("Auto đã tắt")
        end
    end)

    hopButton.MouseButton1Click:Connect(function()
        if IsHopping then
            return
        end
        if #ServerQueue == 0 then
            setStatus("Đang dò server...")
            ensureScan()
            return
        end
        task.spawn(doHop)
    end)

    copyButton.MouseButton1Click:Connect(function()
        pcall(function()
            local text = LastHopInfo
            if text == "" then
                text = safeStr(game.JobId, "Không có")
            end
            if setclipboard then
                setclipboard(text)
            end
            setStatus("Đã copy thông tin server")
        end)
    end)

    logButton.MouseButton1Click:Connect(function()
        LogEnabled = not LogEnabled
        if LogEnabled then
            logButton.Text = "Log: ON"
        else
            logButton.Text = "Log: OFF"
        end
    end)

    screenGui.Parent = parent
end

local function updateUiInfo()
    pcall(function()
        if UiInfoLabel then
            UiInfoLabel.Text = "Người: " .. #Players:GetPlayers() .. " | Queue: " .. #ServerQueue .. " | Ban: " .. BlacklistCount
        end
    end)
end

local function uiUpdateLoop()
    while true do
        task.wait(0.5)
        updateUiInfo()
    end
end

Players.PlayerAdded:Connect(updateUiInfo)
Players.PlayerRemoving:Connect(function()
    task.wait(0.2)
    updateUiInfo()
end)

buildUi()
setStatus("Đang khởi động")
addLog("INFO", "[" .. APP_NAME .. "] Loaded v" .. VERSION)

pcall(function()
    StarterGuiService:SetCore("SendNotification", {
        Title = APP_NAME,
        Text = "Script đã chạy",
        Duration = 4
    })
end)

task.spawn(function()
    local probe = httpGet("https://games.roblox.com/v1/games/" .. tostring(PlaceId) .. "/servers/Public?limit=10")
    if not probe then
        setStatus("Lỗi HTTP, kiểm tra executor")
    end
end)

task.spawn(monitorLoop)
task.spawn(watchdogLoop)
task.spawn(uiUpdateLoop)

setStatus("Đang dò server...")
ensureScan()

local VERSION = "PHANTOM v13.3.3"
local SCRIPT_NAME = "PHANTOM ⚡"

if not game:IsLoaded() then game.Loaded:Wait() end

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local StarterGui = game:GetService("StarterGui")
local TeleportService = game:GetService("TeleportService")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer
local waited = 0
while not LocalPlayer and waited < 5 do
    task.wait(0.1)
    waited = waited + 0.1
    LocalPlayer = Players.LocalPlayer
end

if not LocalPlayer then
    warn("[PHANTOM] Không tìm thấy LocalPlayer sau 5 giây")
    return
end

local function safeNum(v, default)
    default = default or 0
    if type(v) == "number" then return v end
    local n = tonumber(v)
    if n then return n end
    return default
end

local function safeStr(v, default)
    default = default or ""
    if type(v) == "string" then return v end
    if v == nil then return default end
    return tostring(v)
end

local function getRequest()
    if http_request then return http_request end
    if request then return request end
    if syn and syn.request then return syn.request end
    if fluxus and fluxus.request then return fluxus.request end
    return nil
end

local HttpRequest = getRequest()

if not HttpRequest then
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = "PHANTOM",
            Text = "Executor không hỗ trợ HTTP",
            Duration = 5,
        })
    end)
    warn("[PHANTOM] Executor không hỗ trợ HTTP")
    return
end

local RequestPool = {
    active = 0,
    maxActive = 5,
    lastRequest = 0,
    minInterval = 0.03,
    maxInterval = 0.3,
    totalReqs = 0,
    hits429 = 0,
}

local function httpGet(url)
    local ok, res = pcall(HttpRequest, {Url = url, Method = "GET"})
    if not ok then return nil end
    if type(res) ~= "table" then return nil end
    local status = safeNum(res.StatusCode or res.Status, 0)
    local body = safeStr(res.Body or res.body, "")
    return {Status = status, Body = body}
end

local function throttledGet(url)
    local startWait = tick()
    while RequestPool.active >= RequestPool.maxActive do
        task.wait(0.02)
        if tick() - startWait > 20 then return nil end
    end
    local now = tick()
    local delta = now - RequestPool.lastRequest
    if delta < RequestPool.minInterval then
        task.wait(RequestPool.minInterval - delta)
    end
    RequestPool.lastRequest = tick()
    RequestPool.active = RequestPool.active + 1
    RequestPool.totalReqs = RequestPool.totalReqs + 1

    local res = httpGet(url)
    RequestPool.active = RequestPool.active - 1

    if res then
        if res.Status == 429 then
            RequestPool.hits429 = RequestPool.hits429 + 1
            local newInterval = RequestPool.minInterval * 1.4
            if newInterval > RequestPool.maxInterval then newInterval = RequestPool.maxInterval end
            RequestPool.minInterval = newInterval
        elseif res.Status == 200 then
            if RequestPool.minInterval > 0.03 then
                local newInterval = RequestPool.minInterval * 0.97
                if newInterval < 0.03 then newInterval = 0.03 end
                RequestPool.minInterval = newInterval
            end
        end
    end

    return res
end

local State = {
    Auto = true,
    IsScanning = false,
    IsHopping = false,
    ScanStart = 0,
    HopStart = 0,
    SeenCount = 0,
    FoundCount = 0,
    FailCount = 0,
    ConsecutiveFails = 0,
    Status = "Đang khởi động",
    Delay = 3,
    ScanSpeed = 0,
    TotalScans = 0,
}

local Queue = {}
local Blacklist = {}
local Logs = {}
local scanPending = false
local MAX_PAGES = 25
local MAX_QUEUE = 30
local SCAN_TIMEOUT = 40
local HOP_TIMEOUT = 10
local BLACKLIST_MAX = 150
local PASS_DELAY = 0.3
local TOTAL_PASSES = 3
local MIN_STABILITY = 1
local MAX_HOP_ATTEMPTS = 3
local UI_UPDATE_INTERVAL = 1

local function log(level, msg)
    local entry = string.format("[%s][%s] %s", os.date("%H:%M:%S"), level, msg)
    table.insert(Logs, entry)
    if #Logs > 50 then table.remove(Logs, 1) end
    if level == "error" or level == "warn" then
        print(entry)
    elseif level == "info" and msg:find("^Scan") or msg:find("^TOP") or msg:find("Countdown") or msg:find("^Hop") then
        print(entry)
    end
end

local function blacklistCount()
    local c = 0
    for _ in pairs(Blacklist) do c = c + 1 end
    return c
end

local function addBlacklist(jobId)
    if not jobId or jobId == "" then return end
    Blacklist[jobId] = true
    if blacklistCount() > BLACKLIST_MAX then
        Blacklist = {}
    end
end

local function isBlacklisted(jobId)
    return Blacklist[jobId] == true
end

local function fetchServers(cursor, sortOrder)
    sortOrder = sortOrder or "Asc"
    local url = string.format(
        "https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=%s&limit=100",
        game.PlaceId, sortOrder
    )
    if cursor and cursor ~= "" then
        url = url .. "&cursor=" .. cursor
    end
    local res = throttledGet(url)
    if not res then return nil end
    if res.Status ~= 200 then return nil end
    local ok, data = pcall(HttpService.JSONDecode, HttpService, res.Body)
    if not ok or type(data) ~= "table" then return nil end
    return data
end

local function scanBranch(branchId, sortOrder, result)
    local cursor = nil
    local lastCursor = nil
    local cursorRepeat = 0
    local pageCount = 0
    local startTime = tick()

    while pageCount < MAX_PAGES do
        if not State.IsScanning then break end
        if tick() - startTime > SCAN_TIMEOUT then break end
        local data = fetchServers(cursor, sortOrder)
        if not data then
            State.ConsecutiveFails = State.ConsecutiveFails + 1
            if State.ConsecutiveFails >= 6 then
                Blacklist = {}
                State.ConsecutiveFails = 0
            end
            break
        end
        local servers = data.data
        if type(servers) ~= "table" or #servers == 0 then break end

        for _, srv in ipairs(servers) do
            State.SeenCount = State.SeenCount + 1
            local jobId = safeStr(srv.id, "")
            local playing = safeNum(srv.playing, 0)
            if jobId ~= "" and jobId ~= game.JobId and playing == 1 then
                if not isBlacklisted(jobId) then
                    result[jobId] = {
                        id = jobId,
                        ping = safeNum(srv.ping, 999),
                        fps = safeNum(srv.fps, 60),
                        playing = 1,
                        max = safeNum(srv.maxPlayers, 12),
                    }
                end
            end
        end

        pageCount = pageCount + 1
        cursor = data.nextPageCursor
        if not cursor or cursor == "" or cursor == "null" then break end
        if cursor == lastCursor then
            cursorRepeat = cursorRepeat + 1
            if cursorRepeat >= 2 then break end
        else
            cursorRepeat = 0
        end
        lastCursor = cursor
    end
end

local function scanOnePass(passTag)
    local result = {}
    local threads = {}
    local branches = {
        {id = passTag .. "A", sortOrder = "Asc"},
        {id = passTag .. "D", sortOrder = "Desc"},
        {id = passTag .. "B", sortOrder = "Asc"},
    }
    for _, br in ipairs(branches) do
        local t = task.spawn(function()
            pcall(scanBranch, br.id, br.sortOrder, result)
        end)
        table.insert(threads, t)
    end
    for _, t in ipairs(threads) do
        pcall(function() task.wait(t) end)
    end
    return result
end

local function calculateScore(server, stability)
    local playerScore = 100000

    local fpsScore = 0
    if server.fps <= 5 then fpsScore = 15000
    elseif server.fps <= 10 then fpsScore = 12000
    elseif server.fps <= 20 then fpsScore = 8000
    elseif server.fps <= 30 then fpsScore = 4000
    elseif server.fps <= 45 then fpsScore = 1500
    elseif server.fps <= 55 then fpsScore = 400 end

    local pingScore = 0
    if server.ping >= 500 then pingScore = 12000
    elseif server.ping >= 400 then pingScore = 9000
    elseif server.ping >= 300 then pingScore = 6000
    elseif server.ping >= 200 then pingScore = 3500
    elseif server.ping >= 100 then pingScore = 1500 end

    local stabilityScore = stability * 5000

    local slotScore = 0
    local fillRate = server.playing / math.max(server.max, 1)
    if fillRate <= 0.08 then slotScore = 8000
    elseif fillRate <= 0.1 then slotScore = 5000
    elseif fillRate <= 0.15 then slotScore = 3000
    elseif fillRate <= 0.2 then slotScore = 1200
    else slotScore = 300 end

    return playerScore + fpsScore + pingScore + stabilityScore + slotScore
end

local function scanServers()
    if scanPending then
        log("info", "Scan pending, bỏ qua")
        return
    end
    scanPending = true
    if State.IsScanning then
        local t = tick()
        while State.IsScanning and tick() - t < 15 do task.wait(0.1) end
        if State.IsScanning then State.IsScanning = false end
    end

    State.IsScanning = true
    State.ScanStart = tick()
    State.Status = "Đang dò server..."
    State.FoundCount = 0
    Queue = {}
    State.TotalScans = State.TotalScans + 1
    log("info", "Scan lần " .. State.TotalScans)

    local startTime = tick()
    local startSeen = State.SeenCount

    local passes = {}
    for i = 1, TOTAL_PASSES do
        State.Status = "Pass " .. i .. "/" .. TOTAL_PASSES
        passes[i] = scanOnePass("P" .. i)
        if i < TOTAL_PASSES then
            task.wait(PASS_DELAY)
            if not State.IsScanning then scanPending = false return end
        end
    end

    State.Status = "Đang chấm điểm..."

    local seenIds = {}
    for i = 1, TOTAL_PASSES do
        for id, s in pairs(passes[i]) do
            local entry = seenIds[id]
            if not entry then
                seenIds[id] = {count = 1, maxPing = s.ping, minFps = s.fps, ref = s}
            else
                entry.count = entry.count + 1
                if s.ping > entry.maxPing then entry.maxPing = s.ping end
                if s.fps < entry.minFps then entry.minFps = s.fps end
            end
        end
    end

    local merged = {}
    for _, info in pairs(seenIds) do
        local s = info.ref
        s.ping = info.maxPing
        s.fps = info.minFps
        s.stability = info.count
        s.score = calculateScore(s, info.count)
        if info.count >= MIN_STABILITY then
            table.insert(merged, s)
        end
    end

    table.sort(merged, function(a, b) return a.score > b.score end)

    for i = 1, math.min(#merged, MAX_QUEUE) do
        Queue[i] = merged[i]
    end

    local elapsed = tick() - startTime
    local seenDelta = State.SeenCount - startSeen
    if elapsed > 0 then State.ScanSpeed = math.floor(seenDelta / elapsed) end

    State.IsScanning = false
    State.FoundCount = #Queue
    scanPending = false

    if #Queue > 0 then
        local msg = ""
        for i = 1, math.min(3, #Queue) do
            local s = Queue[i]
            msg = msg .. string.format(" #%d(fps=%d,ping=%d,stab=%d)", i, s.fps, s.ping, s.stability)
        end
        log("info", "TOP3:" .. msg)
    end
    log("info", "Scan " .. #Queue .. " sv, " .. State.ScanSpeed .. " sv/s, pool " .. RequestPool.totalReqs .. " req, 429=" .. RequestPool.hits429)
end

local function verifyServerOnePlayer(jobId)
    local cursor = nil
    local pages = 0
    while pages < 20 do
        local data = fetchServers(cursor, "Asc")
        if not data then return nil end
        for _, srv in ipairs(data.data or {}) do
            if safeStr(srv.id, "") == jobId then
                local playing = safeNum(srv.playing, 0)
                if playing == 1 then return true end
                return false
            end
        end
        cursor = data.nextPageCursor
        if not cursor or cursor == "" or cursor == "null" then break end
        pages = pages + 1
    end
    return nil
end

local function teleportToServer(jobId)
    task.wait(0.3)
    local ok = pcall(function()
        TeleportService:TeleportToPlaceInstance(game.PlaceId, jobId, LocalPlayer)
    end)
    if ok then return true end
    ok = pcall(function()
        TeleportService:TeleportAsync(game.PlaceId, {LocalPlayer}, {
            ServerInstanceId = jobId
        })
    end)
    if ok then return true end
    ok = pcall(function()
        TeleportService:TeleportAsync(game.PlaceId, {LocalPlayer})
    end)
    return ok
end

local function getPlayerCount()
    return #Players:GetPlayers()
end

local function hopToServer(server)
    if not server or not server.id then return false end
    if State.IsHopping then return false end
    State.IsHopping = true
    State.HopStart = tick()

    State.Status = "Đang xác nhận..."
    local verify = verifyServerOnePlayer(server.id)
    if verify == false then
        addBlacklist(server.id)
        State.IsHopping = false
        return false
    end

    State.Status = "Đang tạo cổng kết nối..."
    addBlacklist(server.id)

    local ok = teleportToServer(server.id)
    if not ok then
        State.FailCount = State.FailCount + 1
        State.ConsecutiveFails = State.ConsecutiveFails + 1
        if State.ConsecutiveFails >= 6 then
            Blacklist = {}
            State.ConsecutiveFails = 0
        end
        State.IsHopping = false
        return false
    end

    State.Status = "Đang vào..."
    task.wait(1.5)
    State.IsHopping = false
    return true
end

local function pickTopCandidate()
    for _, s in ipairs(Queue) do
        if not isBlacklisted(s.id) and s.playing == 1 then
            return s
        end
    end
    return nil
end

local function tryHop(forceManual)
    if State.IsHopping then return end

    if not forceManual then
        local nowCount = getPlayerCount()
        if nowCount <= 2 then
            State.Status = "Server " .. nowCount .. " người"
            return
        end
    end

    if State.IsScanning then
        local t = tick()
        while State.IsScanning and tick() - t < 15 do task.wait(0.1) end
        if State.IsScanning then State.IsScanning = false end
    end

    if #Queue == 0 then
        scanServers()
    end

    for attempt = 1, MAX_HOP_ATTEMPTS do
        local candidate = pickTopCandidate()
        if not candidate then
            scanServers()
            candidate = pickTopCandidate()
            if not candidate then return end
        end

        for i = #Queue, 1, -1 do
            if Queue[i].id == candidate.id then
                table.remove(Queue, i)
                break
            end
        end

        local ok = hopToServer(candidate)
        if ok then return end
    end

    task.spawn(scanServers)
end

local UI = nil
local UICache = {}

local function buildUI()
    local parent = nil
    pcall(function()
        if CoreGui then parent = CoreGui end
    end)
    if not parent then parent = LocalPlayer:FindFirstChild("PlayerGui") end
    if not parent then return nil end

    pcall(function()
        local old = parent:FindFirstChild("PhantomUI")
        if old then old:Destroy() end
    end)

    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "PhantomUI"
    ScreenGui.ResetOnSpawn = false
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    ScreenGui.Parent = parent

    local MainFrame = Instance.new("Frame")
    MainFrame.Name = "MainFrame"
    MainFrame.Size = UDim2.new(0, 320, 0, 268)
    MainFrame.Position = UDim2.new(0, 20, 0, 80)
    MainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
    MainFrame.BorderSizePixel = 0
    MainFrame.Active = true
    MainFrame.Draggable = true
    MainFrame.Parent = ScreenGui

    local UICorner = Instance.new("UICorner")
    UICorner.CornerRadius = UDim.new(0, 12)
    UICorner.Parent = MainFrame

    local Stroke = Instance.new("UIStroke")
    Stroke.Color = Color3.fromRGB(120, 80, 220)
    Stroke.Thickness = 1.5
    Stroke.Parent = MainFrame

    local Logo = Instance.new("TextLabel")
    Logo.Size = UDim2.new(1, -100, 0, 32)
    Logo.Position = UDim2.new(0, 10, 0, 8)
    Logo.BackgroundTransparency = 1
    Logo.Text = SCRIPT_NAME
    Logo.TextColor3 = Color3.fromRGB(200, 180, 255)
    Logo.TextSize = 20
    Logo.Font = Enum.Font.GothamBold
    Logo.TextXAlignment = Enum.TextXAlignment.Left
    Logo.Parent = MainFrame

    local StatusPill = Instance.new("TextLabel")
    StatusPill.Size = UDim2.new(0, 78, 0, 22)
    StatusPill.Position = UDim2.new(1, -88, 0, 12)
    StatusPill.BackgroundColor3 = Color3.fromRGB(40, 160, 80)
    StatusPill.Text = "AUTO: ON"
    StatusPill.TextColor3 = Color3.fromRGB(255, 255, 255)
    StatusPill.TextSize = 12
    StatusPill.Font = Enum.Font.GothamBold
    StatusPill.Parent = MainFrame
    local PillCorner = Instance.new("UICorner")
    PillCorner.CornerRadius = UDim.new(1, 0)
    PillCorner.Parent = StatusPill

    local InfoFrame = Instance.new("Frame")
    InfoFrame.Size = UDim2.new(1, -20, 0, 128)
    InfoFrame.Position = UDim2.new(0, 10, 0, 48)
    InfoFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
    InfoFrame.BorderSizePixel = 0
    InfoFrame.Parent = MainFrame
    local InfoCorner = Instance.new("UICorner")
    InfoCorner.CornerRadius = UDim.new(0, 8)
    InfoCorner.Parent = InfoFrame

    local function makeRow(key, display, y)
        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(0.5, 0, 0, 22)
        lbl.Position = UDim2.new(0, 10, 0, y)
        lbl.BackgroundTransparency = 1
        lbl.TextColor3 = Color3.fromRGB(180, 180, 200)
        lbl.TextSize = 14
        lbl.Font = Enum.Font.Gotham
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Text = display
        lbl.Parent = InfoFrame

        local val = Instance.new("TextLabel")
        val.Size = UDim2.new(0.5, -10, 0, 22)
        val.Position = UDim2.new(0.5, 0, 0, y)
        val.BackgroundTransparency = 1
        val.TextColor3 = Color3.fromRGB(255, 255, 255)
        val.TextSize = 14
        val.Font = Enum.Font.GothamBold
        val.TextXAlignment = Enum.TextXAlignment.Right
        val.Text = "-"
        val.Parent = InfoFrame
        UICache[key .. "Value"] = val
    end

    makeRow("Players", "Số người", 6)
    makeRow("Found", "Server cổ", 30)
    makeRow("Queue", "Queue", 54)
    makeRow("Speed", "Tốc độ", 78)
    makeRow("Status", "Trạng thái", 102)

    local ButtonFrame = Instance.new("Frame")
    ButtonFrame.Size = UDim2.new(1, -20, 0, 40)
    ButtonFrame.Position = UDim2.new(0, 10, 1, -52)
    ButtonFrame.BackgroundTransparency = 1
    ButtonFrame.Parent = MainFrame

    local function makeButton(name, text, xOffset)
        local btn = Instance.new("TextButton")
        btn.Name = name
        btn.Size = UDim2.new(0, 92, 0, 36)
        btn.Position = UDim2.new(0, xOffset, 0, 0)
        btn.BackgroundColor3 = Color3.fromRGB(80, 50, 160)
        btn.Text = text
        btn.TextColor3 = Color3.fromRGB(255, 255, 255)
        btn.TextSize = 13
        btn.Font = Enum.Font.GothamBold
        btn.Parent = ButtonFrame
        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(0, 6)
        c.Parent = btn
        return btn
    end

    local AutoButton = makeButton("AutoButton", "AUTO: ON", 0)
    local HopButton = makeButton("HopButton", "Hop thủ công", 100)
    local CopyButton = makeButton("CopyButton", "Copy info", 200)

    UICache.StatusPill = StatusPill
    UICache.AutoButton = AutoButton

    return {
        ScreenGui = ScreenGui,
        MainFrame = MainFrame,
        AutoButton = AutoButton,
        HopButton = HopButton,
        CopyButton = CopyButton,
    }
end

UI = buildUI()
if not UI then return end

pcall(function()
    StarterGui:SetCore("SendNotification", {
        Title = "PHANTOM",
        Text = "Script đã chạy",
        Duration = 3,
    })
end)

local uiLast = {players = -1, found = -1, queue = -1, speed = -1, status = "", auto = nil}

local function updateUI()
    pcall(function()
        local pc = getPlayerCount()
        if pc ~= uiLast.players then
            UICache.PlayersValue.Text = tostring(pc)
            uiLast.players = pc
        end
        if State.FoundCount ~= uiLast.found then
            UICache.FoundValue.Text = tostring(State.FoundCount)
            uiLast.found = State.FoundCount
        end
        if #Queue ~= uiLast.queue then
            UICache.QueueValue.Text = tostring(#Queue)
            uiLast.queue = #Queue
        end
        if State.ScanSpeed ~= uiLast.speed then
            UICache.SpeedValue.Text = State.ScanSpeed .. " sv/s"
            uiLast.speed = State.ScanSpeed
        end
        if State.Status ~= uiLast.status then
            UICache.StatusValue.Text = State.Status
            uiLast.status = State.Status
        end
        if State.Auto ~= uiLast.auto then
            local txt = State.Auto and "AUTO: ON" or "AUTO: OFF"
            UICache.StatusPill.Text = txt
            UICache.StatusPill.BackgroundColor3 = State.Auto
                and Color3.fromRGB(40, 160, 80)
                or Color3.fromRGB(120, 40, 40)
            UICache.AutoButton.Text = txt
            uiLast.auto = State.Auto
        end
    end)
end

UI.AutoButton.MouseButton1Click:Connect(function()
    State.Auto = not State.Auto
    State.Status = State.Auto and "Đang chạy" or "Đã tắt"
end)

UI.HopButton.MouseButton1Click:Connect(function()
    task.spawn(function()
        tryHop(true)
    end)
end)

UI.CopyButton.MouseButton1Click:Connect(function()
    local lines = {
        "[PHANTOM] " .. VERSION,
        "Số người: " .. tostring(getPlayerCount()),
        "Queue: " .. tostring(#Queue),
        "Server cổ: " .. tostring(State.FoundCount),
        "Seen: " .. tostring(State.SeenCount),
        "Fails: " .. tostring(State.FailCount),
        "Tốc độ: " .. State.ScanSpeed .. " sv/s",
        "429 hits: " .. RequestPool.hits429,
        "Interval: " .. string.format("%.3f", RequestPool.minInterval),
        "Status: " .. State.Status,
    }
    local text = table.concat(lines, "\n")
    pcall(function()
        if setclipboard then setclipboard(text) end
    end)
end)

task.spawn(function()
    while true do
        task.wait(UI_UPDATE_INTERVAL)
        updateUI()
    end
end)

local countdownActive = false
local countdownRemaining = 0

local function monitorLoop()
    while true do
        task.wait(1)
        if State.Auto and not State.IsHopping then
            local pc = getPlayerCount()
            if pc >= 3 and not countdownActive then
                countdownActive = true
                countdownRemaining = State.Delay
                State.Status = "Đếm ngược " .. countdownRemaining .. "s"
                log("info", "Countdown bắt đầu, " .. pc .. " người")
            end
            if countdownActive then
                if pc <= 2 then
                    countdownActive = false
                    State.Status = "Server " .. pc .. " người"
                else
                    countdownRemaining = countdownRemaining - 1
                    if countdownRemaining <= 0 then
                        countdownActive = false
                        if getPlayerCount() <= 2 then
                            State.Status = "Hủy hop"
                        else
                            State.Status = "Bắt đầu hop"
                            task.spawn(function() tryHop() end)
                        end
                    else
                        State.Status = "Đếm ngược " .. countdownRemaining .. "s"
                    end
                end
            end
        end
    end
end

local function watchdogLoop()
    while true do
        task.wait(3)
        local now = tick()
        if State.IsScanning and now - State.ScanStart > SCAN_TIMEOUT then
            State.IsScanning = false
            scanPending = false
            log("warn", "Watchdog reset scan")
        end
        if State.IsHopping and now - State.HopStart > HOP_TIMEOUT then
            State.IsHopping = false
            log("warn", "Watchdog reset hop")
        end
    end
end

local function refillLoop()
    while true do
        task.wait(8)
        if State.Auto and #Queue == 0 and not State.IsScanning and not State.IsHopping and not scanPending then
            if getPlayerCount() < 3 then
                task.spawn(scanServers)
            end
        end
    end
end

log("info", SCRIPT_NAME .. " Loaded")
State.Status = "Đang chạy"

task.spawn(scanServers)
task.spawn(monitorLoop)
task.spawn(watchdogLoop)
task.spawn(refillLoop)

local VERSION = "PHANTOM v13.2.3"
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
    if syn and syn.request then return syn.request end
    if http_request then return http_request end
    if request then return request end
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

local function httpGet(url)
    local ok, res = pcall(HttpRequest, {Url = url, Method = "GET"})
    if not ok then return nil, "pcall fail" end
    if type(res) ~= "table" then return nil, "response invalid" end
    local status = safeNum(res.StatusCode or res.Status, 0)
    local body = safeStr(res.Body or res.body, "")
    return {Status = status, Body = body}
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
}

local Queue = {}
local Blacklist = {}
local Logs = {}
local QueueLock = false
local MAX_PAGES = 30
local MAX_QUEUE = 10
local SCAN_TIMEOUT = 40
local HOP_TIMEOUT = 15
local BLACKLIST_MAX = 80
local SCAN_DELAY = 0
local PASS_DELAY = 0.2

local function log(level, msg)
    local entry = string.format("[%s][%s] %s", os.date("%H:%M:%S"), level, msg)
    table.insert(Logs, entry)
    if #Logs > 50 then table.remove(Logs, 1) end
    print(entry)
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
        log("warn", "Blacklist reset do vượt " .. BLACKLIST_MAX)
    end
end

local function isBlacklisted(jobId)
    return Blacklist[jobId] == true
end

local function inQueue(jobId)
    for _, s in ipairs(Queue) do
        if s.JobId == jobId then return true end
    end
    return false
end

local function sortQueue()
    table.sort(Queue, function(a, b)
        if a.Stability ~= b.Stability then
            return a.Stability > b.Stability
        end
        return a.Score > b.Score
    end)
end

local function getScore(playerCount)
    if playerCount == 1 then return 1000 end
    return 0
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
    local res, err = httpGet(url)
    if not res then return nil, err end
    if res.Status == 429 or res.Status >= 500 then
        return nil, "api error " .. res.Status
    end
    if res.Status ~= 200 then
        return nil, "status " .. res.Status
    end
    local ok, data = pcall(HttpService.JSONDecode, HttpService, res.Body)
    if not ok or type(data) ~= "table" then return nil, "json fail" end
    return data
end

local function mergeServerToQueue(srv, passNum)
    local jobId = safeStr(srv.id, "")
    local playing = safeNum(srv.playing, 0)
    local maxPlayers = safeNum(srv.maxPlayers, 0)
    if jobId == "" or jobId == game.JobId then return end
    if playing ~= 1 then return end
    if isBlacklisted(jobId) then return end

    while QueueLock do task.wait() end
    QueueLock = true
    State.SeenCount = State.SeenCount + 1

    local existing = nil
    for _, q in ipairs(Queue) do
        if q.JobId == jobId then existing = q break end
    end

    if existing then
        existing.Passes[passNum] = true
        local passCount = 0
        for _ in pairs(existing.Passes) do passCount = passCount + 1 end
        if passCount >= 3 then
            existing.Stability = 3
        elseif passCount == 2 then
            existing.Stability = 2
        else
            existing.Stability = 1
        end
        if existing.Stability < 2 then
            for i = #Queue, 1, -1 do
                if Queue[i].JobId == jobId then
                    table.remove(Queue, i)
                    break
                end
            end
        end
    else
        local entry = {
            JobId = jobId,
            Playing = playing,
            MaxPlayers = maxPlayers,
            Score = getScore(playing),
            Stability = 1,
            Passes = {[passNum] = true},
        }
        if #Queue < MAX_QUEUE then
            table.insert(Queue, entry)
        end
    end

    sortQueue()
    QueueLock = false
end

local function scanBranch(branchId, sortOrder)
    local cursor = nil
    local lastCursor = nil
    local cursorRepeat = 0
    local pageCount = 0
    local startTime = tick()
    local seenThisBranch = 0

    while pageCount < MAX_PAGES do
        if not State.IsScanning then break end
        if tick() - startTime > SCAN_TIMEOUT then
            log("warn", "Nhánh " .. branchId .. " quá timeout")
            break
        end
        local data, err = fetchServers(cursor, sortOrder)
        if not data then
            log("warn", "Nhánh " .. branchId .. " lỗi: " .. tostring(err))
            State.ConsecutiveFails = State.ConsecutiveFails + 1
            if State.ConsecutiveFails >= 6 then
                Blacklist = {}
                State.ConsecutiveFails = 0
                log("warn", "Reset blacklist do 6 fail liên tiếp")
            end
            break
        end
        local servers = data.data
        if type(servers) ~= "table" then break end
        if #servers == 0 then break end

        for _, srv in ipairs(servers) do
            seenThisBranch = seenThisBranch + 1
            mergeServerToQueue(srv, branchId)
        end

        pageCount = pageCount + 1
        cursor = data.nextPageCursor
        if not cursor or cursor == "" then break end
        if cursor == lastCursor then
            cursorRepeat = cursorRepeat + 1
            if cursorRepeat >= 2 then break end
        else
            cursorRepeat = 0
        end
        lastCursor = cursor
        if SCAN_DELAY > 0 then task.wait(SCAN_DELAY) end
    end
    log("info", "Nhánh " .. branchId .. " xong: " .. seenThisBranch .. " server")
end

local function scanServers()
    if State.IsScanning then return end
    State.IsScanning = true
    State.ScanStart = tick()
    State.Status = "Đang dò server..."
    State.FoundCount = 0
    log("info", "Bắt đầu scan 3 nhánh song song")

    local startTime = tick()
    local startSeen = State.SeenCount

    local branches = {
        {id = 1, sortOrder = "Asc"},
        {id = 2, sortOrder = "Desc"},
        {id = 3, sortOrder = "Asc"},
    }

    local threads = {}
    for _, br in ipairs(branches) do
        local t = task.spawn(function()
            local ok, err = pcall(scanBranch, br.id, br.sortOrder)
            if not ok then
                log("error", "Nhánh " .. br.id .. " crash: " .. tostring(err))
            end
        end)
        table.insert(threads, t)
        task.wait(PASS_DELAY)
    end

    for _, t in ipairs(threads) do
        pcall(function() task.wait(t) end)
    end

    task.wait(0.5)

    local elapsed = tick() - startTime
    local seenDelta = State.SeenCount - startSeen
    if elapsed > 0 then
        State.ScanSpeed = math.floor(seenDelta / elapsed)
    end

    State.IsScanning = false
    sortQueue()
    for _, s in ipairs(Queue) do
        if s.Stability >= 2 then
            State.FoundCount = State.FoundCount + 1
        end
    end
    log("info", "Scan xong: " .. #Queue .. " queue, tốc độ " .. State.ScanSpeed .. " sv/s")
end

local function teleportToServer(jobId)
    task.wait(0.3)
    local ok = pcall(function()
        TeleportService:TeleportToPlaceInstance(game.PlaceId, jobId, LocalPlayer)
    end)
    if ok then return true end
    log("warn", "TeleportToPlaceInstance fail, thử TeleportAsync")
    ok = pcall(function()
        TeleportService:TeleportAsync(game.PlaceId, {LocalPlayer}, {
            ServerInstanceId = jobId
        })
    end)
    if ok then return true end
    log("warn", "TeleportAsync fail, thử không options")
    ok = pcall(function()
        TeleportService:TeleportAsync(game.PlaceId, {LocalPlayer})
    end)
    return ok
end

local function hopToServer(server)
    if not server or not server.JobId then return false end
    if State.IsHopping then return false end
    State.IsHopping = true
    State.HopStart = tick()
    State.Status = "Đang tạo cổng kết nối..."
    log("info", "Vào server " .. server.JobId .. " (" .. server.Stability .. " pass)")

    local ok = teleportToServer(server.JobId)
    if not ok then
        log("error", "Teleport fail")
        addBlacklist(server.JobId)
        State.FailCount = State.FailCount + 1
        State.ConsecutiveFails = State.ConsecutiveFails + 1
        if State.ConsecutiveFails >= 6 then
            Blacklist = {}
            State.ConsecutiveFails = 0
            log("warn", "Reset blacklist do 6 fail")
        end
        State.IsHopping = false
        return false
    end

    State.Status = "Đang vào..."
    task.wait(2)
    State.IsHopping = false
    return true
end

local function findCandidate()
    sortQueue()
    for _, s in ipairs(Queue) do
        if s.Stability >= 2 and not isBlacklisted(s.JobId) then
            return s
        end
    end
    return nil
end

local function tryHop()
    if State.IsHopping then return end
    if State.IsScanning then
        State.Status = "Đang chờ scan..."
        return
    end
    local candidate = findCandidate()
    if not candidate then
        State.Status = "Chưa có server cổ, scan lại"
        task.spawn(scanServers)
        return
    end
    for i = #Queue, 1, -1 do
        if Queue[i].JobId == candidate.JobId then
            table.remove(Queue, i)
            break
        end
    end
    local ok = hopToServer(candidate)
    if not ok then
        addBlacklist(candidate.JobId)
        State.FailCount = State.FailCount + 1
        State.ConsecutiveFails = State.ConsecutiveFails + 1
        if State.ConsecutiveFails >= 6 then
            Blacklist = {}
            State.ConsecutiveFails = 0
            log("warn", "Reset blacklist")
        end
    end
end

local function getPlayerCount()
    return #Players:GetPlayers()
end

local function buildUI()
    local parent = nil
    pcall(function()
        if CoreGui then parent = CoreGui end
    end)
    if not parent then
        parent = LocalPlayer:FindFirstChild("PlayerGui")
    end
    if not parent then
        log("error", "Không tìm được parent UI")
        return nil
    end

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
    Logo.Name = "Logo"
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
    StatusPill.Name = "StatusPill"
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
    InfoFrame.Name = "InfoFrame"
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
        lbl.Name = key .. "Label"
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
        val.Name = key .. "Value"
        val.Size = UDim2.new(0.5, -10, 0, 22)
        val.Position = UDim2.new(0.5, 0, 0, y)
        val.BackgroundTransparency = 1
        val.TextColor3 = Color3.fromRGB(255, 255, 255)
        val.TextSize = 14
        val.Font = Enum.Font.GothamBold
        val.TextXAlignment = Enum.TextXAlignment.Right
        val.Text = "-"
        val.Parent = InfoFrame
    end

    makeRow("Players", "Số người", 6)
    makeRow("Found", "Found", 30)
    makeRow("Queue", "Queue", 54)
    makeRow("Speed", "Tốc độ", 78)
    makeRow("Status", "Trạng thái", 102)

    local ButtonFrame = Instance.new("Frame")
    ButtonFrame.Name = "ButtonFrame"
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

    return {
        ScreenGui = ScreenGui,
        MainFrame = MainFrame,
        StatusPill = StatusPill,
        InfoFrame = InfoFrame,
        AutoButton = AutoButton,
        HopButton = HopButton,
        CopyButton = CopyButton,
    }
end

local UI = buildUI()

if not UI then
    warn("[PHANTOM] Không tạo được UI")
    return
end

pcall(function()
    StarterGui:SetCore("SendNotification", {
        Title = "PHANTOM",
        Text = "Script đã chạy",
        Duration = 3,
    })
end)

local function updateUI()
    if not UI then return end
    pcall(function()
        local playerCount = getPlayerCount()
        local playersVal = UI.InfoFrame:FindFirstChild("PlayersValue")
        local foundVal = UI.InfoFrame:FindFirstChild("FoundValue")
        local queueVal = UI.InfoFrame:FindFirstChild("QueueValue")
        local speedVal = UI.InfoFrame:FindFirstChild("SpeedValue")
        local statusVal = UI.InfoFrame:FindFirstChild("StatusValue")
        if playersVal then playersVal.Text = tostring(playerCount) end
        if foundVal then foundVal.Text = tostring(State.FoundCount) end
        if queueVal then queueVal.Text = tostring(#Queue) end
        if speedVal then speedVal.Text = State.ScanSpeed .. " sv/s" end
        if statusVal then statusVal.Text = State.Status end

        UI.StatusPill.Text = State.Auto and "AUTO: ON" or "AUTO: OFF"
        UI.StatusPill.BackgroundColor3 = State.Auto
            and Color3.fromRGB(40, 160, 80)
            or Color3.fromRGB(120, 40, 40)
        UI.AutoButton.Text = State.Auto and "AUTO: ON" or "AUTO: OFF"
    end)
end

UI.AutoButton.MouseButton1Click:Connect(function()
    State.Auto = not State.Auto
    State.Status = State.Auto and "Đang chạy" or "Đã tắt"
    log("info", "Auto = " .. tostring(State.Auto))
end)

UI.HopButton.MouseButton1Click:Connect(function()
    State.Status = "Đang dò server..."
    task.spawn(function()
        scanServers()
        tryHop()
    end)
end)

UI.CopyButton.MouseButton1Click:Connect(function()
    local lines = {
        "[PHANTOM] " .. VERSION,
        "Số người: " .. tostring(getPlayerCount()),
        "Queue: " .. tostring(#Queue),
        "Found: " .. tostring(State.FoundCount),
        "Seen: " .. tostring(State.SeenCount),
        "Fails: " .. tostring(State.FailCount),
        "Tốc độ: " .. State.ScanSpeed .. " sv/s",
        "Status: " .. State.Status,
    }
    local text = table.concat(lines, "\n")
    pcall(function()
        if setclipboard then setclipboard(text) end
    end)
    log("info", "Đã copy info")
end)

task.spawn(function()
    while true do
        task.wait(0.5)
        updateUI()
    end
end)

local countdownActive = false
local countdownRemaining = 0

local function monitorLoop()
    while true do
        task.wait(1)
        if State.Auto then
            local playerCount = getPlayerCount()
            if playerCount >= 3 and not countdownActive and not State.IsHopping then
                countdownActive = true
                countdownRemaining = State.Delay
                State.Status = "Đang đếm ngược " .. countdownRemaining .. "s"
                log("info", "Có " .. playerCount .. " người, bắt đầu countdown")
            end
            if countdownActive then
                if playerCount <= 2 then
                    countdownActive = false
                    State.Status = "Đang chạy"
                    log("info", "Hủy countdown, người rời")
                else
                    countdownRemaining = countdownRemaining - 1
                    if countdownRemaining <= 0 then
                        countdownActive = false
                        State.Status = "Bắt đầu hop"
                        log("info", "Countdown xong, bắt đầu hop")
                        if #Queue < 2 then
                            task.spawn(scanServers)
                            task.wait(1)
                        end
                        tryHop()
                    else
                        State.Status = "Đang đếm ngược " .. countdownRemaining .. "s"
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
            log("warn", "Watchdog: reset IsScanning")
        end
        if State.IsHopping and now - State.HopStart > HOP_TIMEOUT then
            State.IsHopping = false
            log("warn", "Watchdog: reset IsHopping")
        end
    end
end

local function refillLoop()
    while true do
        task.wait(3)
        if State.Auto and #Queue < 3 and not State.IsScanning then
            State.Status = "Queue thiếu, scan lại"
            task.spawn(scanServers)
        end
    end
end

log("info", SCRIPT_NAME .. " Loaded")
State.Status = "Đang chạy"

task.spawn(scanServers)
task.spawn(monitorLoop)
task.spawn(watchdogLoop)
task.spawn(refillLoop)

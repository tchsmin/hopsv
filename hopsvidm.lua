local VERSION = "PHANTOM v13.3.2"
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
    TotalScans = 0,
}

local Queue = {}
local Blacklist = {}
local Logs = {}
local MAX_PAGES = 50
local MAX_QUEUE = 30
local SCAN_TIMEOUT = 40
local HOP_TIMEOUT = 10
local BLACKLIST_MAX = 150
local SCAN_DELAY = 0.02
local PASS_DELAY = 1
local TOTAL_PASSES = 3
local MIN_STABILITY = 1
local MAX_HOP_ATTEMPTS = 3

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

local function scanBranch(branchId, sortOrder, result)
    local cursor = nil
    local lastCursor = nil
    local cursorRepeat = 0
    local pageCount = 0
    local startTime = tick()

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
            State.SeenCount = State.SeenCount + 1
            local jobId = safeStr(srv.id, "")
            local playing = safeNum(srv.playing, 0)
            if jobId ~= "" and jobId ~= game.JobId then
                if playing == 1 then
                    if not isBlacklisted(jobId) then
                        result[jobId] = {
                            id = jobId,
                            ping = safeNum(srv.ping, 999),
                            fps = safeNum(srv.fps, 60),
                            playing = playing,
                            max = safeNum(srv.maxPlayers, 12),
                        }
                    end
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
        if SCAN_DELAY > 0 then task.wait(SCAN_DELAY) end
    end
end

local function scanOnePass(passTag)
    local result = {}
    local branches = {
        {id = passTag .. "-A", sortOrder = "Asc"},
        {id = passTag .. "-D", sortOrder = "Desc"},
        {id = passTag .. "-A2", sortOrder = "Asc"},
    }
    local threads = {}
    for _, br in ipairs(branches) do
        local t = task.spawn(function()
            local ok, err = pcall(scanBranch, br.id, br.sortOrder, result)
            if not ok then
                log("error", "Nhánh " .. br.id .. " crash: " .. tostring(err))
            end
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
    if server.fps <= 5 then
        fpsScore = 15000
    elseif server.fps <= 10 then
        fpsScore = 12000
    elseif server.fps <= 20 then
        fpsScore = 8000
    elseif server.fps <= 30 then
        fpsScore = 4000
    elseif server.fps <= 45 then
        fpsScore = 1500
    elseif server.fps <= 55 then
        fpsScore = 400
    end

    local pingScore = 0
    if server.ping >= 500 then
        pingScore = 12000
    elseif server.ping >= 400 then
        pingScore = 9000
    elseif server.ping >= 300 then
        pingScore = 6000
    elseif server.ping >= 200 then
        pingScore = 3500
    elseif server.ping >= 100 then
        pingScore = 1500
    end

    local stabilityScore = stability * 5000

    local slotScore = 0
    local fillRate = server.playing / math.max(server.max, 1)
    if fillRate <= 0.08 then
        slotScore = 8000
    elseif fillRate <= 0.1 then
        slotScore = 5000
    elseif fillRate <= 0.15 then
        slotScore = 3000
    elseif fillRate <= 0.2 then
        slotScore = 1200
    else
        slotScore = 300
    end

    return playerScore + fpsScore + pingScore + stabilityScore + slotScore
end

local function scanServers()
    local waitStart = tick()
    while State.IsScanning and tick() - waitStart < 15 do
        task.wait(0.1)
    end
    if State.IsScanning then
        State.IsScanning = false
        log("warn", "Force reset scan kẹt")
    end

    State.IsScanning = true
    State.ScanStart = tick()
    State.Status = "Đang dò server..."
    State.FoundCount = 0
    Queue = {}
    State.TotalScans = State.TotalScans + 1
    log("info", "Bắt đầu scan " .. TOTAL_PASSES .. " pass - lần " .. State.TotalScans)

    local startTime = tick()
    local startSeen = State.SeenCount

    local passes = {}
    for i = 1, TOTAL_PASSES do
        State.Status = "Đang dò pass " .. i .. "/" .. TOTAL_PASSES
        passes[i] = scanOnePass("P" .. i)
        local cnt = 0
        for _ in pairs(passes[i]) do cnt = cnt + 1 end
        log("info", "Pass " .. i .. ": " .. cnt .. " server 1 người")
        if i < TOTAL_PASSES then
            State.Status = "Đang phân tích..."
            task.wait(PASS_DELAY)
            if not State.IsScanning then State.IsScanning = false return end
        end
    end

    State.Status = "Đang chấm điểm..."
    task.wait(0.2)

    local merged = {}
    local seenIds = {}
    for i = 1, TOTAL_PASSES do
        for id, s in pairs(passes[i]) do
            if not seenIds[id] then
                seenIds[id] = {count = 0, maxPing = s.ping, minFps = s.fps, samePlaying = true}
            end
            local entry = seenIds[id]
            entry.count = entry.count + 1
            if s.ping > entry.maxPing then entry.maxPing = s.ping end
            if s.fps < entry.minFps then entry.minFps = s.fps end
        end
    end

    for id, info in pairs(seenIds) do
        local s = nil
        for i = 1, TOTAL_PASSES do
            if passes[i][id] then s = passes[i][id] break end
        end
        if s then
            s.ping = info.maxPing
            s.fps = info.minFps
            s.stability = info.count
            s.score = calculateScore(s, info.count)
            if info.count >= MIN_STABILITY then
                table.insert(merged, s)
            end
        end
    end

    table.sort(merged, function(a, b)
        return a.score > b.score
    end)

    for i = 1, math.min(#merged, MAX_QUEUE) do
        table.insert(Queue, merged[i])
    end

    local elapsed = tick() - startTime
    local seenDelta = State.SeenCount - startSeen
    if elapsed > 0 then
        State.ScanSpeed = math.floor(seenDelta / elapsed)
    end

    State.IsScanning = false
    State.FoundCount = #Queue

    if #Queue > 0 then
        local topMsg = ""
        for i = 1, math.min(3, #Queue) do
            topMsg = topMsg .. string.format(" #%d(score=%d,fps=%d,ping=%d) ",
                i, math.floor(Queue[i].score), Queue[i].fps, Queue[i].ping)
        end
        log("info", "TOP 3:" .. topMsg)
    end

    log("info", "Scan xong: " .. #Queue .. " queue, tốc độ " .. State.ScanSpeed .. " sv/s")
end

local function verifyServerOnePlayer(jobId)
    local cursor = nil
    local pages = 0
    while pages < 30 do
        local data, err = fetchServers(cursor, "Asc")
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
        task.wait(0.05)
    end
    return nil
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

local function getPlayerCount()
    return #Players:GetPlayers()
end

local function hopToServer(server)
    if not server or not server.id then
        log("warn", "hopToServer: server nil")
        return false
    end
    if State.IsHopping then
        log("warn", "hopToServer: đang hopping")
        return false
    end
    State.IsHopping = true
    State.HopStart = tick()

    State.Status = "Đang xác nhận..."
    log("info", "Verify " .. server.id .. " (score=" .. math.floor(server.score) .. " fps=" .. server.fps .. " ping=" .. server.ping .. " stab=" .. server.stability .. ")")
    local verify = verifyServerOnePlayer(server.id)
    if verify == false then
        log("warn", "Server đã đầy, blacklist")
        addBlacklist(server.id)
        State.IsHopping = false
        return false
    end

    State.Status = "Đang tạo cổng kết nối..."
    addBlacklist(server.id)

    local ok = teleportToServer(server.id)
    if not ok then
        log("error", "Teleport fail")
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
    log("info", "tryHop bắt đầu: forceManual=" .. tostring(forceManual) .. " queue=" .. #Queue)

    if State.IsHopping then
        log("warn", "tryHop: đang hopping, bỏ")
        return
    end

    if not forceManual then
        local nowCount = getPlayerCount()
        if nowCount <= 2 then
            State.Status = "Server " .. nowCount .. " người, không hop"
            log("info", "Bỏ qua hop: server chỉ có " .. nowCount .. " người")
            return
        end
    end

    if State.IsScanning then
        State.Status = "Đang chờ scan xong..."
        log("info", "tryHop: đang scan, chờ 15s")
        local t = tick()
        while State.IsScanning and tick() - t < 15 do
            task.wait(0.2)
        end
        if State.IsScanning then
            State.IsScanning = false
            log("warn", "Force reset scan sau 15s chờ")
        end
    end

    if #Queue == 0 then
        State.Status = "Queue rỗng, scan ngay"
        log("info", "Queue rỗng, scan")
        scanServers()
    end

    for attempt = 1, MAX_HOP_ATTEMPTS do
        local candidate = pickTopCandidate()
        if not candidate then
            State.Status = "Hết server cổ, scan lại"
            log("info", "Hết candidate (attempt " .. attempt .. "), scan lại")
            scanServers()
            candidate = pickTopCandidate()
            if not candidate then
                log("warn", "Sau scan vẫn không có candidate, dừng")
                return
            end
        end

        for i = #Queue, 1, -1 do
            if Queue[i].id == candidate.id then
                table.remove(Queue, i)
                break
            end
        end

        local ok = hopToServer(candidate)
        if ok then
            log("info", "Hop thành công")
            return
        end
        log("warn", "Attempt " .. attempt .. " fail, thử tiếp")
    end

    State.Status = "Thử hết, scan lại"
    task.spawn(scanServers)
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
    makeRow("Found", "Server cổ", 30)
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
                    State.Status = "Server " .. playerCount .. " người, hủy hop"
                    log("info", "Hủy countdown, server còn " .. playerCount .. " người")
                else
                    countdownRemaining = countdownRemaining - 1
                    if countdownRemaining <= 0 then
                        countdownActive = false
                        local finalCount = getPlayerCount()
                        if finalCount <= 2 then
                            State.Status = "Server " .. finalCount .. " người, không hop"
                            log("info", "Bỏ hop: server còn " .. finalCount .. " người")
                        else
                            State.Status = "Bắt đầu hop"
                            log("info", "Countdown xong, bắt đầu hop")
                            task.spawn(function()
                                tryHop()
                            end)
                        end
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
        task.wait(8)
        if State.Auto and #Queue == 0 and not State.IsScanning and not State.IsHopping then
            local pc = getPlayerCount()
            if pc < 3 then
                State.Status = "Queue rỗng, scan sẵn"
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

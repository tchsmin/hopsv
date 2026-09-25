local VERSION = "PHANTOM v13.2.6"
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
}

local Queue = {}
local Blacklist = {}
local Logs = {}
local MAX_PAGES = 20
local MAX_QUEUE = 20
local SCAN_TIMEOUT = 40
local HOP_TIMEOUT = 15
local BLACKLIST_MAX = 80
local SCAN_DELAY = 0.02
local PASS_DELAY = 2

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
                if playing >= 1 and playing <= 2 then
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
    local playerScore = 0
    if server.playing == 1 then
        playerScore = 10000
    elseif server.playing == 2 then
        playerScore = 100
    end

    local fpsScore = 0
    if server.fps <= 10 then
        fpsScore = 3000
    elseif server.fps <= 20 then
        fpsScore = 2000
    elseif server.fps <= 30 then
        fpsScore = 1200
    elseif server.fps <= 45 then
        fpsScore = 600
    elseif server.fps <= 55 then
        fpsScore = 200
    else
        fpsScore = math.max(0, 60 - server.fps) * 5
    end

    local pingScore = 0
    if server.ping >= 400 then
        pingScore = 2500
    elseif server.ping >= 250 then
        pingScore = 1800
    elseif server.ping >= 150 then
        pingScore = 1000
    elseif server.ping >= 80 then
        pingScore = 400
    else
        pingScore = math.min(server.ping, 500) / 2
    end

    local stabilityScore = stability * 1000

    local slotScore = 0
    local fillRate = server.playing / math.max(server.max, 1)
    if fillRate <= 0.1 then
        slotScore = 1500
    elseif fillRate <= 0.2 then
        slotScore = 800
    else
        slotScore = 300
    end

    return playerScore + fpsScore + pingScore + stabilityScore + slotScore
end

local function scanServers()
    if State.IsScanning then return end
    State.IsScanning = true
    State.ScanStart = tick()
    State.Status = "Đang dò server..."
    State.FoundCount = 0
    Queue = {}
    log("info", "Bắt đầu scan 3 pass")

    local startTime = tick()
    local startSeen = State.SeenCount

    local pass1 = scanOnePass("P1")
    local count1 = 0
    for _ in pairs(pass1) do count1 = count1 + 1 end
    log("info", "Pass 1: " .. count1 .. " server")

    State.Status = "Đang phân tích..."
    task.wait(PASS_DELAY)
    if not State.IsScanning then State.IsScanning = false return end

    local pass2 = scanOnePass("P2")
    local count2 = 0
    for _ in pairs(pass2) do count2 = count2 + 1 end
    log("info", "Pass 2: " .. count2 .. " server")

    State.Status = "Đang xác nhận..."
    task.wait(PASS_DELAY)
    if not State.IsScanning then State.IsScanning = false return end

    local pass3 = scanOnePass("P3")
    local count3 = 0
    for _ in pairs(pass3) do count3 = count3 + 1 end
    log("info", "Pass 3: " .. count3 .. " server")

    State.Status = "Đang chấm điểm..."
    task.wait(0.3)

    local merged = {}
    for id, s in pairs(pass1) do
        local stability = 1
        local p2 = pass2[id]
        local p3 = pass3[id]
        if p2 and p3 then
            if p2.playing == s.playing and p3.playing == s.playing then
                stability = 3
            else
                stability = 2
            end
        elseif p2 or p3 then
            stability = 2
        end
        if p2 then
            s.ping = math.max(s.ping, p2.ping)
            s.fps = math.min(s.fps, p2.fps)
        end
        if p3 then
            s.ping = math.max(s.ping, p3.ping)
            s.fps = math.min(s.fps, p3.fps)
        end
        s.stability = stability
        s.score = calculateScore(s, stability)
        table.insert(merged, s)
    end
    for id, s in pairs(pass2) do
        if not pass1[id] then
            local stability = 1
            if pass3[id] then stability = 2 end
            s.stability = stability
            s.score = calculateScore(s, stability)
            table.insert(merged, s)
        end
    end
    for id, s in pairs(pass3) do
        if not pass1[id] and not pass2[id] then
            s.stability = 1
            s.score = calculateScore(s, 1)
            table.insert(merged, s)
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

local function getPlayerCount()
    return #Players:GetPlayers()
end

local function hopToServer(server)
    if not server or not server.id then return false end
    if State.IsHopping then return false end
    State.IsHopping = true
    State.HopStart = tick()
    State.Status = "Đang tạo cổng kết nối..."
    log("info", "Vào " .. server.id .. " (score=" .. math.floor(server.score) .. " fps=" .. server.fps .. " ping=" .. server.ping .. " stab=" .. server.stability .. ")")

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
    task.wait(2)
    State.IsHopping = false
    return true
end

local function pickCandidate()
    local onePlayer = {}
    local twoPlayer = {}
    for _, s in ipairs(Queue) do
        if not isBlacklisted(s.id) then
            if s.playing == 1 then
                table.insert(onePlayer, s)
            elseif s.playing == 2 then
                table.insert(twoPlayer, s)
            end
        end
    end
    local pool = onePlayer
    if #pool == 0 then pool = twoPlayer end
    if #pool == 0 then return nil end
    local topCount = math.min(5, #pool)
    return pool[math.random(1, topCount)]
end

local function tryHop(forceManual)
    if State.IsHopping then return end

    if not forceManual then
        local nowCount = getPlayerCount()
        if nowCount <= 2 then
            State.Status = "Server " .. nowCount .. " người, không hop"
            log("info", "Bỏ qua hop: server chỉ có " .. nowCount .. " người")
            return
        end
    end

    if State.IsScanning then
        State.Status = "Đang chờ scan..."
        return
    end

    local candidate = pickCandidate()
    if not candidate then
        State.Status = "Chưa có server, scan lại"
        task.spawn(scanServers)
        return
    end

    for i = #Queue, 1, -1 do
        if Queue[i].id == candidate.id then
            table.remove(Queue, i)
            break
        end
    end

    local ok = hopToServer(candidate)
    if not ok then
        State.FailCount = State.FailCount + 1
        State.ConsecutiveFails = State.ConsecutiveFails + 1
        if State.ConsecutiveFails >= 6 then
            Blacklist = {}
            State.ConsecutiveFails = 0
            log("warn", "Reset blacklist")
        end
    end
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
        tryHop(true)
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
                            if #Queue < 2 then
                                task.spawn(scanServers)
                                task.wait(1)
                            end
                            tryHop()
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

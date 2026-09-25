local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local PLACE_ID = game.PlaceId
local JOB_ID = game.JobId

local function notify(title, text, duration)
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = tostring(title),
            Text = tostring(text),
            Duration = duration or 5
        })
    end)
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

if not http then
    notify("LỖI", "Executor không có HTTP")
    return
end

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
    TeleportTimeout = 10,
    MaxTeleportAttempts = 3,
    RequestRetries = 2,
}

local Blacklist = {}
local IsScanning = false
local IsHopping = false
local AutoEnabled = true
local MonitorConn = nil
local LastPlayerCount = 0
local TeleportPending = false
local ScanGeneration = 0

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
    local attempts = 0
    while attempts < CONFIG.RequestRetries do
        attempts = attempts + 1
        local ok, res = pcall(function()
            return http({ Url = url, Method = "GET" })
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
        if attempts < CONFIG.RequestRetries then
            task.wait(0.15)
        end
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

local function parallelScan(targetPlaying, myGeneration)
    local result = {}
    local lockRef = {false}

    local first = requestPage("")
    if not first then return result end
    if myGeneration ~= ScanGeneration then return result end
    collectFromData(first, targetPlaying, result, lockRef)

    local rootCursor = first.nextPageCursor
    if not rootCursor or rootCursor == "" or rootCursor == "null" or type(rootCursor) ~= "string" then
        return result
    end

    local branchCursors = { rootCursor }
    for i = 1, CONFIG.ParallelBranches - 1 do
        if myGeneration ~= ScanGeneration then return result end
        local cur = branchCursors[i]
        if cur then
            local data = requestPage(cur)
            if data then
                collectFromData(data, targetPlaying, result, lockRef)
                local nc = data.nextPageCursor
                if nc and nc ~= "" and nc ~= "null" and type(nc) == "string" then
                    branchCursors[i + 1] = nc
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

    if #activeBranches == 0 then return result end

    local pagesPerBranch = math.max(2, math.floor(CONFIG.MaxPages / #activeBranches))
    local threads = {}

    for idx = 1, #activeBranches do
        local startCursor = activeBranches[idx]
        table.insert(threads, task.spawn(function()
            local cursor = startCursor
            local pages = 0
            local failCount = 0
            while pages < pagesPerBranch do
                if myGeneration ~= ScanGeneration then return end
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
            if coroutine.status(t) ~= "dead" then
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
    if ok1 then return true end

    local ok2 = pcall(function()
        TeleportService:TeleportToPlaceInstance(PLACE_ID, jobId, LocalPlayer)
    end)
    if ok2 then return true end

    local ok3 = pcall(function()
        TeleportService:TeleportToPlaceInstance(PLACE_ID, jobId)
    end)
    if ok3 then return true end

    return false
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
                    if pc >= CONFIG.MinPlayerFilter and pc <= CONFIG.MaxPlayerFilter then
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
    if not target or type(target.id) ~= "string" then return false end

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
        return false
    end

    TeleportPending = true
    local originalJob = game.JobId

    if not attemptTeleport(target.id) then
        TeleportPending = false
        Blacklist[target.id] = true
        return false
    end

    local startTime = tick()
    while tick() - startTime < CONFIG.TeleportTimeout do
        if game.JobId ~= originalJob then
            TeleportPending = false
            return true
        end
        task.wait(0.3)
    end

    TeleportPending = false
    Blacklist[target.id] = true
    return false
end

local function scanForOnePlayer(myGeneration)
    local pass1 = parallelScan(1, myGeneration)
    if myGeneration ~= ScanGeneration then return nil, nil end
    local count1 = 0
    for _ in pairs(pass1) do count1 = count1 + 1 end

    if count1 == 0 then
        task.wait(0.3)
        local pass1b = parallelScan(2, myGeneration)
        if myGeneration ~= ScanGeneration then return nil, nil end
        local count1b = 0
        for _ in pairs(pass1b) do count1b = count1b + 1 end
        if count1b == 0 then return nil, nil end

        task.wait(CONFIG.PassDelay)
        local pass2b = parallelScan(2, myGeneration)
        if myGeneration ~= ScanGeneration then return nil, nil end

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
        if myGeneration ~= ScanGeneration then return nil, nil end

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
    if myGeneration ~= ScanGeneration then return nil, nil end

    local pass2 = parallelScan(1, myGeneration)
    if myGeneration ~= ScanGeneration then return nil, nil end

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
    if myGeneration ~= ScanGeneration then return nil, nil end

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
    ScanGeneration = ScanGeneration + 1
    local myGeneration = ScanGeneration

    notify("HOP SERVER", "Đang quét server...", 3)

    local target, targetMode = scanForOnePlayer(myGeneration)

    if myGeneration ~= ScanGeneration then
        IsScanning = false
        return
    end

    if not target then
        IsScanning = false
        notify("HOP SERVER", "Không có server · thử lại sau 5s", 3)
        task.wait(5)
        return
    end

    notify("HOP SERVER", "Vào server " .. targetMode .. " người", 3)

    task.wait(CONFIG.PreTeleportDelay)

    if myGeneration ~= ScanGeneration then
        IsScanning = false
        return
    end

    IsScanning = false
    IsHopping = true
    Blacklist[target.id] = true

    local success = false
    for attempt = 1, CONFIG.MaxTeleportAttempts do
        if myGeneration ~= ScanGeneration then
            IsHopping = false
            return
        end

        if teleportWithVerify(target) then
            success = true
            break
        end
        task.wait(1)
    end

    IsHopping = false
    if not success then
        notify("HOP SERVER", "Vào fail · thử lại", 3)
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
            notify("HOP SERVER", "Server " .. count .. " người · hop sau " .. CONFIG.AutoHopDelay .. "s", 3)

            task.spawn(function()
                for i = CONFIG.AutoHopDelay, 1, -1 do
                    if not AutoEnabled then return end
                    if IsHopping or IsScanning then return end
                    local cnt = #Players:GetPlayers()
                    if cnt <= CONFIG.MaxTotalAllowed then
                        notify("HOP SERVER", "Đã về " .. cnt .. " người · hủy hop", 3)
                        return
                    end
                    if i > 1 then
                        notify("HOP SERVER", "Hop sau " .. i .. "s · " .. cnt .. " người", 2)
                    end
                    task.wait(1)
                end

                if IsHopping or IsScanning then return end
                if #Players:GetPlayers() > CONFIG.MaxTotalAllowed then
                    performHop()
                end
            end)
        end
    end)
end

notify("HOP SERVER", "Đang khởi động...", 3)
startMonitor()

task.spawn(function()
    task.wait(2)
    local count = #Players:GetPlayers()
    if count > CONFIG.MaxTotalAllowed then
        performHop()
    else
        notify("HOP SERVER", "Đang chạy · chờ người vào", 3)
    end
end)

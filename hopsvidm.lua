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
    RequestRetries = 3,
    RequestBackoff = 0.25,
    PageDelay = 0.02,
    MaxPages = 40,
    ParallelBranches = 5,
    TrackDelay = 1.5,
    TrackPasses = 4,
    PreTeleportVerify = 3,
    VerifyGap = 0.3,
    TeleportTimeout = 10,
    PostTeleportWait = 4,
    MaxTeleportAttempts = 2,
    AutoHopDelay = 3,
    MaxTotalAllowed = 2,
    MinServerAge = 2.0,
    MinSightings = 4,
    HopCooldownBase = 6,
    HopCooldownAfterFail = 12,
    HopCooldownAfter279 = 25,
    MaxConsecutiveFail = 4,
    MonitorTickRate = 0.5,
}

local State = {
    Blacklist = {},
    IsScanning = false,
    IsHopping = false,
    AutoEnabled = true,
    MonitorConn = nil,
    MonitorSlowConn = nil,
    LastPlayerCount = 0,
    TeleportPending = false,
    ScanGeneration = 0,
    LastHopTime = 0,
    ConsecutiveFail = 0,
    Last279Time = 0,
    CountdownActive = false,
    CountdownGen = 0,
    PostTeleportCheckGen = 0,
}

local function is279Error(err)
    if not err then return false end
    local s = tostring(err):lower()
    return s:find("279") or s:find("unable to connect") or s:find("không thể kết nối")
end

local function getCurrentPlayerCount()
    return #Players:GetPlayers()
end

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
            task.wait(CONFIG.RequestBackoff * attempts)
        end
    end
    return nil
end

local function extractServers(data, targetPlaying, result, lock)
    if not data or type(data.data) ~= "table" then return 0 end
    local added = 0
    local now = tick()
    for _, s in ipairs(data.data) do
        if type(s) == "table" then
            local pc = tonumber(s.playing) or 0
            local id = s.id
            if type(id) == "string" and id ~= JOB_ID and not State.Blacklist[id] and pc == targetPlaying then
                while lock[1] do task.wait() end
                lock[1] = true
                if not result[id] then
                    result[id] = {
                        id = id,
                        ping = tonumber(s.ping) or 999,
                        fps = tonumber(s.fps) or 60,
                        playing = pc,
                        max = tonumber(s.maxPlayers) or 12,
                        firstSeen = now,
                        lastSeen = now,
                        sightings = 1,
                    }
                    added = added + 1
                else
                    result[id].lastSeen = now
                    result[id].sightings = result[id].sightings + 1
                end
                lock[1] = false
            end
        end
    end
    return added
end

local function parallelScan(targetPlaying, myGeneration)
    local result = {}
    local lock = {false}

    local first = requestPage("")
    if not first then return result end
    if myGeneration ~= State.ScanGeneration then return result end
    extractServers(first, targetPlaying, result, lock)

    local rootCursor = first.nextPageCursor
    if not rootCursor or rootCursor == "" or rootCursor == "null" or type(rootCursor) ~= "string" then
        return result
    end

    local branchCursors = { rootCursor }
    for i = 1, CONFIG.ParallelBranches - 1 do
        if myGeneration ~= State.ScanGeneration then return result end
        local cur = branchCursors[i]
        if cur then
            local data = requestPage(cur)
            if data then
                extractServers(data, targetPlaying, result, lock)
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
                if myGeneration ~= State.ScanGeneration then return end
                local data = requestPage(cursor)
                if not data then
                    failCount = failCount + 1
                    if failCount >= 2 then break end
                    task.wait(0.25)
                else
                    failCount = 0
                    extractServers(data, targetPlaying, result, lock)
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
    while tick() - startTime < 8 do
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

local function trackServers(serverIds, targetPlaying, myGeneration)
    local tracked = {}
    local lock = {false}

    for pass = 1, CONFIG.TrackPasses do
        if myGeneration ~= State.ScanGeneration then return tracked end
        task.wait(CONFIG.TrackDelay)

        local passResult = parallelScan(targetPlaying, myGeneration)
        if myGeneration ~= State.ScanGeneration then return tracked end

        local now = tick()
        for id, s in pairs(passResult) do
            if serverIds[id] then
                if not tracked[id] then
                    tracked[id] = {
                        id = id,
                        ping = s.ping,
                        fps = s.fps,
                        playing = s.playing,
                        max = s.max,
                        firstSeen = now,
                        lastSeen = now,
                        sightings = 1,
                    }
                else
                    tracked[id].lastSeen = now
                    tracked[id].sightings = tracked[id].sightings + 1
                    tracked[id].ping = s.ping
                    tracked[id].fps = s.fps
                end
            end
        end

        if pass < CONFIG.TrackPasses then
            local c = 0
            for _ in pairs(tracked) do c = c + 1 end
            notify("HOP SERVER", "Track " .. pass .. "/" .. CONFIG.TrackPasses .. " · " .. c .. " server", 2)
        end
    end

    return tracked
end

local function verifyServerOnePlayer(jobId)
    if not http then return false, "no_http" end
    local cursor = ""
    local pages = 0
    while pages < 12 do
        local data = requestPage(cursor)
        if not data then return false, "request_fail" end
        if type(data.data) == "table" then
            for _, s in ipairs(data.data) do
                if type(s) == "table" and s.id == jobId then
                    local pc = tonumber(s.playing) or 0
                    if pc == 1 then
                        return true, nil
                    elseif pc > 1 then
                        return false, "filled"
                    elseif pc == 0 then
                        return false, "empty"
                    end
                end
            end
        end
        local nc = data.nextPageCursor
        if not nc or nc == "" or nc == "null" then break end
        cursor = nc
        pages = pages + 1
    end
    return false, "not_found"
end

local function attemptTeleport(jobId)
    local ok1, err1 = pcall(function()
        local opts = Instance.new("TeleportOptions")
        opts.ServerInstanceId = jobId
        TeleportService:TeleportAsync(PLACE_ID, {LocalPlayer}, opts)
    end)
    if ok1 then return true, nil end

    local ok2, err2 = pcall(function()
        TeleportService:TeleportToPlaceInstance(PLACE_ID, jobId, LocalPlayer)
    end)
    if ok2 then return true, nil end

    local ok3, err3 = pcall(function()
        TeleportService:TeleportToPlaceInstance(PLACE_ID, jobId)
    end)
    if ok3 then return true, nil end

    return false, err1 or err2 or err3
end

local function teleportWithHeavyVerify(target)
    if not target or type(target.id) ~= "string" then
        return false, "invalid_target"
    end

    for check = 1, CONFIG.PreTeleportVerify do
        local live, reason = verifyServerOnePlayer(target.id)
        if not live then
            State.Blacklist[target.id] = true
            return false, "verify_" .. tostring(reason)
        end
        if check < CONFIG.PreTeleportVerify then
            task.wait(CONFIG.VerifyGap)
        end
    end

    State.TeleportPending = true
    local originalJob = game.JobId

    local ok, err = attemptTeleport(target.id)
    if not ok then
        State.TeleportPending = false
        State.Blacklist[target.id] = true
        if is279Error(err) then
            State.Last279Time = tick()
            return false, "279"
        end
        return false, "call_fail"
    end

    local startTime = tick()
    while tick() - startTime < CONFIG.TeleportTimeout do
        if game.JobId ~= originalJob then
            State.TeleportPending = false
            return true, nil
        end
        task.wait(0.3)
    end

    State.TeleportPending = false
    State.Blacklist[target.id] = true
    return false, "stuck"
end

local function scoreAndSort(servers)
    local list = {}
    local now = tick()
    for id, s in pairs(servers) do
        local age = (s.lastSeen or now) - (s.firstSeen or now)
        local sightings = s.sightings or 1
        if age >= CONFIG.MinServerAge and sightings >= CONFIG.MinSightings then
            s.age = age
            s.score = 0
            s.score = s.score + sightings * 500
            s.score = s.score + age * 200
            s.score = s.score + math.max(0, 60 - (s.fps or 60)) * 5
            s.score = s.score + math.min(s.ping or 999, 500) / 2
            table.insert(list, s)
        end
    end
    table.sort(list, function(a, b)
        if a.score ~= b.score then return a.score > b.score end
        return (a.ping or 999) > (b.ping or 999)
    end)
    return list
end

local function findBestOnePlayerServer(myGeneration)
    notify("HOP SERVER", "Scan 1 người...", 2)

    local pass1 = parallelScan(1, myGeneration)
    if myGeneration ~= State.ScanGeneration then return nil, "cancel" end

    local count1 = 0
    local serverIds = {}
    for id, _ in pairs(pass1) do
        count1 = count1 + 1
        serverIds[id] = true
    end

    if count1 == 0 then
        return nil, "no_server"
    end

    notify("HOP SERVER", "Có " .. count1 .. " ứng viên · track " .. CONFIG.TrackPasses .. " pass", 3)

    local tracked = trackServers(serverIds, 1, myGeneration)
    if myGeneration ~= State.ScanGeneration then return nil, "cancel" end

    local candidates = scoreAndSort(tracked)
    if #candidates == 0 then
        return nil, "no_stable"
    end

    notify("HOP SERVER", "Chọn từ " .. #candidates .. " server ổn định", 3)

    return candidates[1], nil
end

local function postTeleportVerify(myGen)
    task.wait(CONFIG.PostTeleportWait)
    if myGen ~= State.PostTeleportCheckGen then return end
    if State.IsHopping or State.IsScanning or State.TeleportPending then return end

    local count = getCurrentPlayerCount()
    if count > CONFIG.MaxTotalAllowed then
        notify("HOP SERVER", "Vừa vào server " .. count .. " người · hop lại", 3)
        task.wait(1)
        if myGen ~= State.PostTeleportCheckGen then return end
        performHop()
    else
        notify("HOP SERVER", "Server " .. count .. " người · OK", 3)
    end
end

local function performHop()
    if State.IsScanning or State.IsHopping then return end

    local now = tick()
    local cooldown = CONFIG.HopCooldownBase
    if State.ConsecutiveFail >= 2 then
        cooldown = CONFIG.HopCooldownAfterFail
    end
    if now - State.Last279Time < 30 then
        cooldown = CONFIG.HopCooldownAfter279
    end
    if now - State.LastHopTime < cooldown then
        local wait = math.ceil(cooldown - (now - State.LastHopTime))
        if wait > 2 then
            notify("HOP SERVER", "Cooldown " .. wait .. "s", 2)
        end
        task.wait(cooldown - (now - State.LastHopTime))
    end

    State.IsScanning = true
    State.ScanGeneration = State.ScanGeneration + 1
    local myGeneration = State.ScanGeneration

    local target, reason = findBestOnePlayerServer(myGeneration)

    if myGeneration ~= State.ScanGeneration then
        State.IsScanning = false
        return
    end

    if not target then
        State.IsScanning = false
        State.ConsecutiveFail = State.ConsecutiveFail + 1
        State.LastHopTime = tick()

        if reason == "cancel" then return end

        if State.ConsecutiveFail >= CONFIG.MaxConsecutiveFail then
            notify("HOP SERVER", "Fail " .. State.ConsecutiveFail .. " lần · nghỉ 20s", 5)
            task.wait(20)
            State.ConsecutiveFail = 0
        else
            notify("HOP SERVER", "Không có server 1 người · thử lại sau 5s", 3)
            task.wait(5)
        end
        return
    end

    notify("HOP SERVER", "Vào server · FPS" .. (target.fps or 60) .. " · P" .. (target.ping or 0), 3)

    task.wait(0.1)

    if myGeneration ~= State.ScanGeneration then
        State.IsScanning = false
        return
    end

    State.IsScanning = false
    State.IsHopping = true
    State.Blacklist[target.id] = true
    State.LastHopTime = tick()

    local success = false
    local failReason = nil

    for attempt = 1, CONFIG.MaxTeleportAttempts do
        if myGeneration ~= State.ScanGeneration then
            State.IsHopping = false
            return
        end

        local ok, reason2 = teleportWithHeavyVerify(target)
        if ok then
            success = true
            break
        else
            failReason = reason2
        end
        task.wait(1.5)
    end

    State.IsHopping = false

    if success then
        State.ConsecutiveFail = 0
        State.PostTeleportCheckGen = State.PostTeleportCheckGen + 1
        local myPostGen = State.PostTeleportCheckGen
        task.spawn(function()
            postTeleportVerify(myPostGen)
        end)
    else
        State.ConsecutiveFail = State.ConsecutiveFail + 1

        if failReason == "279" then
            notify("HOP SERVER", "Lỗi 279 · nghỉ dài", 4)
            State.Last279Time = tick()
            task.wait(CONFIG.HopCooldownAfter279)
        elseif failReason and failReason:find("verify_filled") then
            notify("HOP SERVER", "Server đã đầy · tìm server khác", 3)
            task.wait(2)
            performHop()
        elseif failReason and failReason:find("verify_") then
            notify("HOP SERVER", "Server biến mất · tìm server khác", 3)
            task.wait(2)
            performHop()
        elseif failReason == "stuck" then
            notify("HOP SERVER", "Kẹt loading · thử server khác", 3)
            task.wait(3)
            performHop()
        else
            notify("HOP SERVER", "Vào fail · đợi " .. CONFIG.HopCooldownAfterFail .. "s", 3)
            task.wait(CONFIG.HopCooldownAfterFail)
        end
    end
end

local function triggerHopCountdown(count)
    if State.CountdownActive then return end
    State.CountdownActive = true
    State.CountdownGen = State.CountdownGen + 1
    local myGen = State.CountdownGen

    task.spawn(function()
        for i = CONFIG.AutoHopDelay, 1, -1 do
            if myGen ~= State.CountdownGen then
                State.CountdownActive = false
                return
            end
            if not State.AutoEnabled then
                State.CountdownActive = false
                return
            end
            if State.IsHopping or State.IsScanning then
                State.CountdownActive = false
                return
            end

            local cnt = getCurrentPlayerCount()
            if cnt <= CONFIG.MaxTotalAllowed then
                notify("HOP SERVER", "Đã về " .. cnt .. " người · hủy hop", 3)
                State.CountdownActive = false
                return
            end

            if i > 1 then
                notify("HOP SERVER", "Hop sau " .. i .. "s · " .. cnt .. " người", 2)
            end
            task.wait(1)
        end

        if myGen ~= State.CountdownGen then
            State.CountdownActive = false
            return
        end

        State.CountdownActive = false
        local cnt = getCurrentPlayerCount()
        if cnt > CONFIG.MaxTotalAllowed then
            performHop()
        end
    end)
end

local function cancelHopCountdown()
    State.CountdownGen = State.CountdownGen + 1
    State.CountdownActive = false
end

local function startMonitorFast()
    if State.MonitorConn then State.MonitorConn:Disconnect() end
    State.MonitorConn = RunService.Heartbeat:Connect(function()
        if not State.AutoEnabled then return end
        if State.IsHopping or State.IsScanning or State.TeleportPending then return end

        local count = getCurrentPlayerCount()
        if count == State.LastPlayerCount then return end

        local oldCount = State.LastPlayerCount
        State.LastPlayerCount = count

        if count > CONFIG.MaxTotalAllowed then
            if oldCount <= CONFIG.MaxTotalAllowed then
                notify("HOP SERVER", "Phát hiện " .. count .. " người · sẽ hop", 3)
            end
            triggerHopCountdown(count)
        else
            if oldCount > CONFIG.MaxTotalAllowed then
                cancelHopCountdown()
            end
        end
    end)
end

local function startMonitorSlow()
    if State.MonitorSlowConn then State.MonitorSlowConn:Disconnect() end
    State.MonitorSlowConn = task.spawn(function()
        while true do
            task.wait(10)
            if not State.AutoEnabled then continue end
            local count = getCurrentPlayerCount()
            if count <= CONFIG.MaxTotalAllowed then
                notify("HOP SERVER", "Server " .. count .. " người · ổn định", 2)
            end
        end
    end)
end

notify("HOP SERVER", "Đang khởi động...", 3)

State.LastPlayerCount = getCurrentPlayerCount()
notify("HOP SERVER", "Server hiện tại: " .. State.LastPlayerCount .. " người", 3)

startMonitorFast()

task.spawn(function()
    task.wait(3)
    local count = getCurrentPlayerCount()
    if count > CONFIG.MaxTotalAllowed then
        notify("HOP SERVER", "Server đông · hop ngay", 3)
        performHop()
    else
        notify("HOP SERVER", "Đang chạy · sẽ hop khi ≥ 3 người", 4)
    end
end)

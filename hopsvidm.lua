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

local function log(...)
    print("[HOP]", ...)
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
    MaxPages = 25,
    MaxPlayerFilter = 2,
    AutoHopDelay = 3,
    MaxTotalAllowed = 2,
    RetryDelay = 5,
    PostCheckDelay = 4,
    VerifyRetries = 2,
    RequestRetries = 3,
}

local Blacklist = {}
local IsScanning = false
local IsHopping = false
local AutoEnabled = true
local MonitorConn = nil
local LastPlayerCount = 0
local TeleportPending = false
local NeedHop = false
local CountdownGen = 0
local PostCheckGen = 0

local function requestPage(cursor)
    if not http then return nil, "no_http" end
    local url = string.format(
        "https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100&cursor=%s",
        PLACE_ID, cursor or ""
    )
    for attempt = 1, CONFIG.RequestRetries do
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
                    return data, nil
                end
            end
        end
        task.wait(0.3)
    end
    return nil, "request_fail"
end

local function scanAllServers()
    local all = {}
    local cursor = ""
    local pages = 0
    local totalServers = 0
    local filteredCount = 0

    while pages < CONFIG.MaxPages do
        local data, err = requestPage(cursor)
        if not data then
            log("Request failed at page", pages, err)
            break
        end

        local cnt = 0
        for _, s in ipairs(data.data) do
            cnt = cnt + 1
            totalServers = totalServers + 1
            local pc = tonumber(s.playing) or 0
            local id = s.id
            if type(id) == "string" and pc >= 1 and pc <= CONFIG.MaxPlayerFilter then
                if id ~= JOB_ID then
                    all[id] = {
                        id = id,
                        ping = tonumber(s.ping) or 999,
                        fps = tonumber(s.fps) or 60,
                        playing = pc,
                        max = tonumber(s.maxPlayers) or 12,
                    }
                    filteredCount = filteredCount + 1
                end
            end
        end

        if cnt == 0 then break end

        cursor = data.nextPageCursor
        if not cursor or cursor == "" or cursor == "null" then break end
        pages = pages + 1
        task.wait(0.02)
    end

    log("Total servers scanned:", totalServers, "| Filtered:", filteredCount, "| Pages:", pages)
    return all, totalServers, filteredCount
end

local function calculateScore(server)
    local fpsScore = math.max(0, 60 - server.fps) * 2
    local pingScore = math.min(server.ping, 500) / 4
    local playerBonus = server.playing == 1 and 500 or 0
    return playerBonus + fpsScore + pingScore
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

local function findServer()
    log("=== SCAN START ===")

    local servers, total, filtered = scanAllServers()

    if next(servers) == nil then
        log("No servers found")
        return nil, "no_servers"
    end

    local candidates = {}
    for id, s in pairs(servers) do
        s.score = calculateScore(s)
        table.insert(candidates, s)
    end

    table.sort(candidates, function(a, b)
        return a.score > b.score
    end)

    local onePlayer = {}
    for _, s in ipairs(candidates) do
        if s.playing == 1 then
            table.insert(onePlayer, s)
        end
    end

    local pool = #onePlayer > 0 and onePlayer or candidates
    local topCount = math.min(3, #pool)
    local target = pool[math.random(1, topCount)]

    log("Candidates:", #candidates, "| 1-player:", #onePlayer, "| Target:", target.id:sub(1, 12), "| players:", target.playing)
    log("=== SCAN END ===")

    return target, nil
end

local function postTeleportCheck(myGen)
    task.wait(CONFIG.PostCheckDelay)
    if myGen ~= PostCheckGen then return end
    if IsHopping or IsScanning or TeleportPending then return end

    local count = #Players:GetPlayers()
    if count > CONFIG.MaxTotalAllowed then
        notify("HOP SERVER", "Vừa vào " .. count .. " người · hop lại", 3)
        NeedHop = true
    else
        notify("HOP SERVER", "Server " .. count .. " người · OK", 3)
        NeedHop = false
    end
end

function performHop()
    if IsScanning or IsHopping then return false end

    IsScanning = true
    NeedHop = false

    local target = findServer()

    if not target then
        IsScanning = false
        notify("HOP SERVER", "Không có server · thử lại sau " .. CONFIG.RetryDelay .. "s", 3)
        task.wait(CONFIG.RetryDelay)
        return false
    end

    notify("HOP SERVER", "Vào " .. target.playing .. " người · FPS" .. target.fps .. " · P" .. target.ping, 3)

    task.wait(0.2)

    IsScanning = false
    IsHopping = true
    TeleportPending = true
    Blacklist[target.id] = tick()

    local success = false
    for attempt = 1, 2 do
        local ok, method = attemptTeleport(target.id)
        if ok then
            success = true
            log("Teleport success via", method)
            break
        end
        task.wait(1.5)
    end

    TeleportPending = false
    IsHopping = false

    if success then
        PostCheckGen = PostCheckGen + 1
        local myGen = PostCheckGen
        task.spawn(function()
            postTeleportCheck(myGen)
        end)
        return true
    else
        notify("HOP SERVER", "Vào fail · thử lại " .. CONFIG.RetryDelay .. "s", 3)
        task.wait(CONFIG.RetryDelay)
        return false
    end
end

local function triggerCountdown(count)
    CountdownGen = CountdownGen + 1
    local myGen = CountdownGen

    task.spawn(function()
        for i = CONFIG.AutoHopDelay, 1, -1 do
            if myGen ~= CountdownGen then return end
            if not AutoEnabled then return end
            if IsHopping or IsScanning then return end

            local cnt = #Players:GetPlayers()
            if cnt <= CONFIG.MaxTotalAllowed then
                notify("HOP SERVER", "Đã về " .. cnt .. " người · hủy hop", 3)
                NeedHop = false
                return
            end

            if i > 1 then
                notify("HOP SERVER", "Hop sau " .. i .. "s · " .. cnt .. " người", 2)
            end
            task.wait(1)
        end

        if myGen ~= CountdownGen then return end
        if IsHopping or IsScanning then return end
        if #Players:GetPlayers() > CONFIG.MaxTotalAllowed then
            NeedHop = true
        end
    end)
end

local function startMonitor()
    if MonitorConn then MonitorConn:Disconnect() end
    MonitorConn = RunService.Heartbeat:Connect(function()
        if not AutoEnabled then return end
        if IsHopping or IsScanning or TeleportPending then return end

        local count = #Players:GetPlayers()
        if count == LastPlayerCount then return end

        local oldCount = LastPlayerCount
        LastPlayerCount = count

        if count > CONFIG.MaxTotalAllowed then
            if oldCount <= CONFIG.MaxTotalAllowed then
                notify("HOP SERVER", "Phát hiện " .. count .. " người · sẽ hop", 3)
            end
            triggerCountdown(count)
        else
            if oldCount > CONFIG.MaxTotalAllowed then
                CountdownGen = CountdownGen + 1
                NeedHop = false
            end
        end
    end)
end

task.spawn(function()
    while true do
        task.wait(1)
        if not AutoEnabled then continue end
        if IsHopping or IsScanning or TeleportPending then continue end

        local count = #Players:GetPlayers()
        if count > CONFIG.MaxTotalAllowed then
            NeedHop = true
        end

        if NeedHop then
            performHop()
        end
    end
end)

notify("HOP SERVER", "Đang khởi động...", 3)

LastPlayerCount = #Players:GetPlayers()
notify("HOP SERVER", "Server hiện tại: " .. LastPlayerCount .. " người", 3)

log("PlaceId:", PLACE_ID)
log("JobId:", JOB_ID:sub(1, 12))

startMonitor()

task.spawn(function()
    task.wait(3)
    local count = #Players:GetPlayers()
    if count > CONFIG.MaxTotalAllowed then
        notify("HOP SERVER", "Server đông · hop ngay", 3)
        NeedHop = true
    else
        notify("HOP SERVER", "Đang chạy · hop khi ≥ 3 người", 4)
    end
end)

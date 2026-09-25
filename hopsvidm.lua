local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local PLACE_ID = game.PlaceId
local JOB_ID = game.JobId

local function notify(text, duration)
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = "HOP SERVER",
            Text = tostring(text),
            Duration = duration or 4
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
    notify("Lỗi: không có HTTP")
    return
end

local CONFIG = {
    MaxPages = 30,
    RetryDelay = 4,
    AutoHopDelay = 3,
    MaxTotalAllowed = 2,
    PostCheckDelay = 4,
    RequestRetries = 3,
    VerifyRetries = 2,
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

local function requestUrl(url)
    if not http then return nil end
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
                    return data
                end
            end
        end
        task.wait(0.25)
    end
    return nil
end

local function scanWithFilter(minP, maxP)
    local result = {}
    local cursor = ""
    local pages = 0
    local totalSeen = 0

    while pages < CONFIG.MaxPages do
        local url = string.format(
            "https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100&cursor=%s&minPlayers=%d&maxPlayers=%d",
            PLACE_ID, cursor or "", minP, maxP
        )

        local data = requestUrl(url)
        if not data then break end

        local cnt = 0
        for _, s in ipairs(data.data) do
            cnt = cnt + 1
            totalSeen = totalSeen + 1
            local pc = tonumber(s.playing) or 0
            local id = s.id
            if type(id) == "string" and id ~= JOB_ID and not Blacklist[id] then
                if pc >= minP and pc <= maxP then
                    result[id] = {
                        id = id,
                        ping = tonumber(s.ping) or 999,
                        fps = tonumber(s.fps) or 60,
                        playing = pc,
                        max = tonumber(s.maxPlayers) or 12,
                    }
                end
            end
        end

        if cnt == 0 then break end

        cursor = data.nextPageCursor
        if not cursor or cursor == "" or cursor == "null" then break end
        pages = pages + 1
        task.wait(0.02)
    end

    return result, totalSeen
end

local function scanWithoutFilter()
    local result = {}
    local cursor = ""
    local pages = 0

    while pages < CONFIG.MaxPages do
        local url = string.format(
            "https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100&cursor=%s",
            PLACE_ID, cursor or ""
        )

        local data = requestUrl(url)
        if not data then break end

        local cnt = 0
        for _, s in ipairs(data.data) do
            cnt = cnt + 1
            local pc = tonumber(s.playing) or 0
            local id = s.id
            if type(id) == "string" and id ~= JOB_ID and not Blacklist[id] then
                if pc >= 1 and pc <= 2 then
                    result[id] = {
                        id = id,
                        ping = tonumber(s.ping) or 999,
                        fps = tonumber(s.fps) or 60,
                        playing = pc,
                        max = tonumber(s.maxPlayers) or 12,
                    }
                end
            end
        end

        if cnt == 0 then break end

        cursor = data.nextPageCursor
        if not cursor or cursor == "" or cursor == "null" then break end
        pages = pages + 1
        task.wait(0.02)
    end

    return result
end

local function calculateScore(server)
    local fpsScore = math.max(0, 60 - server.fps) * 2
    local pingScore = math.min(server.ping, 500) / 4
    local playerBonus = server.playing == 1 and 500 or 0
    return playerBonus + fpsScore + pingScore
end

local function verifyServerLive(jobId)
    if not http then return true end

    local url = string.format(
        "https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100&cursor=&minPlayers=1&maxPlayers=2",
        PLACE_ID
    )
    local data = requestUrl(url)
    if not data then return true end

    local cursor = ""
    local pages = 0
    local seenInFirstPage = false

    while pages < 15 do:
        if pages > 0 then
            local url2 = string.format(
                "https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100&cursor=%s",
                PLACE_ID, cursor or ""
            )
            data = requestUrl(url2)
            if not data then return true end
        end

        if type(data.data) == "table" then
            for _, s in ipairs(data.data) do
                if type(s) == "table" and s.id == jobId then
                    local pc = tonumber(s.playing) or 0
                    if pc >= 1 and pc <= 2 then
                        return true
                    end
                    return false
                end
            end
        end

        cursor = data.nextPageCursor
        if not cursor or cursor == "" or cursor == "null" then break end
        pages = pages + 1
    end

    return true
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

local function postCheck(myGen)
    task.wait(CONFIG.PostCheckDelay)
    if myGen ~= PostCheckGen then return end
    if IsHopping or IsScanning or TeleportPending then return end

    local count = #Players:GetPlayers()
    if count > CONFIG.MaxTotalAllowed then
        notify("Lỗi: server đông · bắt đầu dò lại", 3)
        NeedHop = true
    else
        notify("OK · server " .. count .. " người", 3)
    end
end

local function findBestServer()
    notify("Đang tìm server...", 3)

    local servers = select(1, scanWithFilter(1, 1))

    if next(servers) == nil then
        notify("Không có 1 người · thử 1-2 người", 2)
        servers = select(1, scanWithFilter(1, 2))
    end

    if next(servers) == nil then
        notify("Không có filter · scan toàn bộ", 2)
        servers = scanWithoutFilter()
    end

    if next(servers) == nil then
        return nil
    end

    local candidates = {}
    for _, s in pairs(servers) do
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
    return pool[math.random(1, topCount)]
end

function performHop()
    if IsScanning or IsHopping then return false end

    IsScanning = true
    NeedHop = false

    local target = findBestServer()

    if not target then
        IsScanning = false
        notify("Lỗi: không có server · bắt đầu dò lại", 3)
        task.wait(CONFIG.RetryDelay)
        return false
    end

    notify("Vào server " .. target.playing .. " người · FPS" .. target.fps .. " · P" .. target.ping, 3)

    task.wait(0.2)

    IsScanning = false
    IsHopping = true
    TeleportPending = true
    Blacklist[target.id] = tick()

    local success = false
    for attempt = 1, 2 do
        if attemptTeleport(target.id) then
            success = true
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
            postCheck(myGen)
        end)
        return true
    else
        notify("Lỗi: vào fail · bắt đầu dò lại", 3)
        task.wait(CONFIG.RetryDelay)
        return false
    end
end

local function triggerCountdown()
    CountdownGen = CountdownGen + 1
    local myGen = CountdownGen

    task.spawn(function()
        for i = CONFIG.AutoHopDelay, 1, -1 do
            if myGen ~= CountdownGen then return end
            if not AutoEnabled then return end
            if IsHopping or IsScanning then return end

            local cnt = #Players:GetPlayers()
            if cnt <= CONFIG.MaxTotalAllowed then
                NeedHop = false
                return
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
                notify("Phát hiện " .. count .. " người · sẽ hop", 3)
            end
            triggerCountdown()
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

        if #Players:GetPlayers() > CONFIG.MaxTotalAllowed then
            NeedHop = true
        end

        if NeedHop then
            performHop()
        end
    end
end)

LastPlayerCount = #Players:GetPlayers()
startMonitor()

notify("Script sẵn sàng", 4)

task.spawn(function()
    task.wait(2)
    if #Players:GetPlayers() > CONFIG.MaxTotalAllowed then
        NeedHop = true
    end
end)

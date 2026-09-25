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
    MaxPages = 15,
    PassDelay = 2.5,
    ConfirmDelay = 1.5,
    PreTeleportDelay = 0.3,
    AutoHopDelay = 3,
    MaxTotalAllowed = 2,
    HopCooldown = 6,
    FailCooldown = 12,
    PostCheckDelay = 4,
    MaxPlayerFilter = 2,
}

local Blacklist = {}
local IsScanning = false
local IsHopping = false
local AutoEnabled = true
local MonitorConn = nil
local LastPlayerCount = 0
local TeleportPending = false
local LastHopTime = 0
local ConsecutiveFail = 0
local CountdownGen = 0
local PostCheckGen = 0

local function requestPage(cursor)
    if not http then return nil end
    local url = string.format(
        "https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100&cursor=%s",
        PLACE_ID, cursor or ""
    )
    for attempt = 1, 2 do
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
        task.wait(0.2)
    end
    return nil
end

local function scanPass(maxPlayers, maxPages)
    local result = {}
    local cursor = ""
    local pages = 0

    while pages < maxPages do
        local data = requestPage(cursor)
        if not data then break end

        local cnt = 0
        for _, s in ipairs(data.data) do
            cnt = cnt + 1
            local pc = tonumber(s.playing) or 0
            local id = s.id
            if type(id) == "string" and pc >= 1 and pc <= maxPlayers then
                if id ~= JOB_ID and not Blacklist[id] then
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

local function calculateScore(server, stabilityBonus)
    local playerScore = 0
    if server.playing == 1 then
        playerScore = 100
    elseif server.playing == 2 then
        playerScore = 40
    elseif server.playing == 3 then
        playerScore = 10
    end
    local fpsScore = math.max(0, 60 - server.fps) * 1.5
    local pingScore = math.min(server.ping, 500) / 5
    local stabilityScore = stabilityBonus * 60
    return playerScore + fpsScore + pingScore + stabilityScore
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

local function findServer()
    notify("HOP SERVER", "Đang dò server...", 2)

    local pass1 = scanPass(CONFIG.MaxPlayerFilter, CONFIG.MaxPages)

    local count1 = 0
    for _ in pairs(pass1) do count1 = count1 + 1 end
    if count1 == 0 then
        return nil, "no_server_pass1"
    end

    notify("HOP SERVER", "Pass 1: " .. count1 .. " server · chờ 2.5s", 2)
    task.wait(CONFIG.PassDelay)

    local pass2 = scanPass(CONFIG.MaxPlayerFilter, CONFIG.MaxPages)

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

    if #stable == 0 then
        return nil, "no_stable"
    end

    notify("HOP SERVER", "Đang xác nhận...", 2)
    task.wait(CONFIG.ConfirmDelay)

    local finalPool = {}
    for _, s in ipairs(stable) do
        s.score = calculateScore(s, s.stability)
        table.insert(finalPool, s)
    end

    table.sort(finalPool, function(a, b)
        return a.score > b.score
    end)

    local onePlayer = {}
    for _, s in ipairs(finalPool) do
        if s.playing == 1 then
            table.insert(onePlayer, s)
        end
    end

    local pickFrom = onePlayer
    if #pickFrom == 0 then
        pickFrom = finalPool
    end

    if #pickFrom == 0 then
        return nil, "empty_pool"
    end

    local topCount = math.min(3, #pickFrom)
    return pickFrom[math.random(1, topCount)], nil
end

local function postTeleportCheck(myGen)
    task.wait(CONFIG.PostCheckDelay)
    if myGen ~= PostCheckGen then return end
    if IsHopping or IsScanning or TeleportPending then return end

    local count = #Players:GetPlayers()
    if count > CONFIG.MaxTotalAllowed then
        notify("HOP SERVER", "Vừa vào " .. count .. " người · hop lại", 3)
        task.wait(1)
        if myGen ~= PostCheckGen then return end
        performHop()
    else
        notify("HOP SERVER", "Server " .. count .. " người · OK", 3)
    end
end

function performHop()
    if IsScanning or IsHopping then return end

    local now = tick()
    local cooldown = CONFIG.HopCooldown
    if ConsecutiveFail >= 2 then cooldown = CONFIG.FailCooldown end
    if now - LastHopTime < cooldown then
        local wait = math.ceil(cooldown - (now - LastHopTime))
        if wait > 2 then
            notify("HOP SERVER", "Cooldown " .. wait .. "s", 2)
        end
        task.wait(cooldown - (now - LastHopTime))
    end

    IsScanning = true

    local target, reason = findServer()

    if not target then
        IsScanning = false
        ConsecutiveFail = ConsecutiveFail + 1
        LastHopTime = tick()

        if ConsecutiveFail >= 4 then
            notify("HOP SERVER", "Fail nhiều · nghỉ 20s", 4)
            task.wait(20)
            ConsecutiveFail = 0
        else
            notify("HOP SERVER", "Không có server · thử lại 5s", 3)
            task.wait(5)
        end
        return
    end

    notify("HOP SERVER", "Vào " .. target.playing .. " người · FPS" .. target.fps .. " · P" .. target.ping, 3)

    task.wait(CONFIG.PreTeleportDelay)

    IsScanning = false
    IsHopping = true
    TeleportPending = true
    Blacklist[target.id] = true
    LastHopTime = tick()

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
        ConsecutiveFail = 0
        PostCheckGen = PostCheckGen + 1
        local myGen = PostCheckGen
        task.spawn(function()
            postTeleportCheck(myGen)
        end)
    else
        ConsecutiveFail = ConsecutiveFail + 1
        notify("HOP SERVER", "Vào fail · đợi " .. CONFIG.FailCooldown .. "s", 3)
        task.wait(CONFIG.FailCooldown)
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
                notify("HOP SERVER", "Đã về " .. cnt .. " người · hủy", 3)
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
            performHop()
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
            end
        end
    end)
end

notify("HOP SERVER", "Đang khởi động...", 3)

LastPlayerCount = #Players:GetPlayers()
notify("HOP SERVER", "Server hiện tại: " .. LastPlayerCount .. " người", 3)

startMonitor()

task.spawn(function()
    task.wait(3)
    local count = #Players:GetPlayers()
    if count > CONFIG.MaxTotalAllowed then
        notify("HOP SERVER", "Server đông · hop ngay", 3)
        performHop()
    else
        notify("HOP SERVER", "Đang chạy · hop khi ≥ 3 người", 4)
    end
end)

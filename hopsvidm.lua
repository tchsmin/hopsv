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

local CONFIG = {
    MaxTotalAllowed = 2,
    AutoHopDelay = 3,
    PostCheckDelay = 4,
    RetryDelay = 4,
}

local function requestPage(cursor)
    if not http then return nil end
    local url = string.format(
        "https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100&cursor=%s",
        PLACE_ID, cursor or ""
    )
    local ok, res = pcall(function()
        return http({ Url = url, Method = "GET", Headers = { ["Accept"] = "application/json" } })
    end)
    if not ok or not res then return nil end
    local body = res.Body or res.body
    if type(body) ~= "string" or #body == 0 then return nil end
    local ok2, data = pcall(function()
        return HttpService:JSONDecode(body)
    end)
    if not ok2 or type(data) ~= "table" then return nil end
    return data
end

local function scanPass(maxPlayers, maxPages)
    local result = {}
    local cursor = ""
    local pages = 0
    local totalScanned = 0

    while pages < maxPages do
        local data = requestPage(cursor)
        if not data or not data.data then break end

        local cnt = 0
        for _, s in ipairs(data.data) do
            cnt = cnt + 1
            totalScanned = totalScanned + 1
            local pc = tonumber(s.playing) or 0
            local id = s.id
            if pc >= 1 and pc <= maxPlayers then
                if id ~= JOB_ID and not Blacklist[id] then
                    result[id] = {
                        id = id,
                        ping = tonumber(s.ping) or 999,
                        fps = tonumber(s.fps) or 60,
                        playing = pc,
                        max = tonumber(s.maxPlayers) or 12
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

    return result, totalScanned
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
    notify("Đang tìm server", 3)

    local pass1 = select(1, scanPass(2, 12))

    local count1 = 0
    for _ in pairs(pass1) do count1 = count1 + 1 end

    if count1 == 0 then
        return nil
    end

    task.wait(2.5)

    local pass2 = select(1, scanPass(2, 12))

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

    task.wait(1.5)

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
        return nil
    end

    local topCount = math.min(3, #pickFrom)
    return pickFrom[math.random(1, topCount)]
end

local function postCheck(myGen)
    task.wait(CONFIG.PostCheckDelay)
    if myGen ~= PostCheckGen then return end
    if IsHopping or IsScanning or TeleportPending then return end

    local count = #Players:GetPlayers()
    if count > CONFIG.MaxTotalAllowed then
        notify("Lỗi, bắt đầu dò lại", 3)
        NeedHop = true
    else
        notify("OK · server " .. count .. " người", 3)
    end
end

function performHop()
    if IsScanning or IsHopping then return false end

    IsScanning = true
    NeedHop = false

    local target = findServer()

    if not target then
        IsScanning = false
        notify("Lỗi, bắt đầu dò lại", 3)
        task.wait(CONFIG.RetryDelay)
        return false
    end

    notify("Vào server " .. target.playing .. " người · FPS" .. target.fps .. " · P" .. target.ping, 3)

    task.wait(0.3)

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
        notify("Lỗi, bắt đầu dò lại", 3)
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

local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")

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
    ScanPages = 20,
    TrackPasses = 5,
    TrackDelay = 1.5,
    MinAge = 4,
    MinSightings = 5,
    VerifyAttempts = 5,
    VerifyGap = 0.6,
    TeleportTimeout = 12,
    PostCheckDelay = 5,
    PostLeaderboardWait = 8,
    RetryDelay = 4,
    BlacklistTTL = 300,
    RequestRetries = 3,
    PopupCheckInterval = 0.2,
    StuckTimeout = 45,
}

local State = {
    Blacklist = {},
    IsBusy = false,
    AutoEnabled = true,
    LastPlayerCount = 0,
    CurrentTargetId = nil,
    NeedHop = false,
    LastLoopTime = 0,
    VerifyCache = {},
}

local function cleanBlacklist()
    local now = tick()
    for id, t in pairs(State.Blacklist) do
        if now - t > CONFIG.BlacklistTTL then
            State.Blacklist[id] = nil
        end
    end
end

local function killPopups()
    pcall(function()
        local promptGui = CoreGui:FindFirstChild("RobloxPromptGui")
        if not promptGui then return end
        local overlay = promptGui:FindFirstChild("promptOverlay")
        if overlay then
            overlay.Parent = nil
            overlay:Destroy()
        end
    end)
end

local function clickPopupOk()
    local clicked = false
    pcall(function()
        local promptGui = CoreGui:FindFirstChild("RobloxPromptGui")
        if not promptGui then return end
        local overlay = promptGui:FindFirstChild("promptOverlay")
        if not overlay then return end

        for _, obj in ipairs(overlay:GetDescendants()) do
            if obj:IsA("TextButton") then
                local txt = obj.Text or ""
                if txt == "Ok" or txt == "OK" or txt:lower() == "ok" then
                    if firesignal then
                        pcall(function() firesignal(obj.MouseButton1Click) end)
                        pcall(function() firesignal(obj.Activated) end)
                    end
                    if obj.Activate then
                        pcall(function() obj:Activate() end)
                    end
                    clicked = true
                end
            end
        end
    end)
    return clicked
end

pcall(function()
    TeleportService.TeleportInitFailed:Connect(function(player, result, errMsg)
        if player ~= LocalPlayer then return end
        if State.CurrentTargetId then
            State.Blacklist[State.CurrentTargetId] = tick()
        end
        State.IsBusy = false
        State.NeedHop = true
        notify("Lỗi " .. tostring(errMsg or "?") .. " · block server · dò lại", 4)
    end)
end)

local function requestPage(cursor)
    if not http then return nil end
    local url = string.format(
        "https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100&cursor=%s",
        PLACE_ID, cursor or ""
    )
    for attempt = 1, CONFIG.RequestRetries do
        local ok, res = pcall(function()
            return http({ Url = url, Method = "GET", Headers = { ["Accept"] = "application/json" } })
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
        task.wait(0.3)
    end
    return nil
end

local function scanPass(targetPc, maxPages, intoResult)
    local result = intoResult or {}
    local cursor = ""
    local pages = 0

    while pages < maxPages do
        local data = requestPage(cursor)
        if not data then break end

        local cnt = 0
        local now = tick()
        for _, s in ipairs(data.data) do
            cnt = cnt + 1
            local pc = tonumber(s.playing) or 0
            local id = s.id
            if type(id) == "string" and id ~= JOB_ID and not State.Blacklist[id] then
                if pc == targetPc then
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
                    else
                        result[id].lastSeen = now
                        result[id].sightings = result[id].sightings + 1
                        result[id].ping = tonumber(s.ping) or result[id].ping
                        result[id].fps = tonumber(s.fps) or result[id].fps
                    end
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

local function trackServers(pool, targetPc)
    local tracked = {}
    for id, s in pairs(pool) do
        tracked[id] = {
            id = id,
            ping = s.ping,
            fps = s.fps,
            playing = s.playing,
            max = s.max,
            firstSeen = s.firstSeen,
            lastSeen = s.lastSeen,
            sightings = s.sightings,
        }
    end

    for pass = 1, CONFIG.TrackPasses do
        task.wait(CONFIG.TrackDelay)

        local passResult = scanPass(targetPc, CONFIG.ScanPages, {})

        local now = tick()
        for id, s in pairs(passResult) do
            if tracked[id] then
                tracked[id].lastSeen = now
                tracked[id].sightings = tracked[id].sightings + 1
                tracked[id].ping = s.ping
                tracked[id].fps = s.fps
            end
        end

        local alive = 0
        for _ in pairs(tracked) do alive = alive + 1 end
        notify("Track " .. pass .. "/" .. CONFIG.TrackPasses .. " · " .. alive, 2)
    end

    local stable = {}
    for id, s in pairs(tracked) do
        local age = (s.lastSeen or 0) - (s.firstSeen or 0)
        if age >= CONFIG.MinAge and s.sightings >= CONFIG.MinSightings then
            s.age = age
            table.insert(stable, s)
        end
    end

    return stable
end

local function verifyServerNow(jobId)
    if not http then return false end

    local cursor = ""
    local pages = 0
    local maxPages = 15

    while pages < maxPages do
        local url = string.format(
            "https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100&cursor=%s",
            PLACE_ID, cursor or ""
        )

        local ok, res = pcall(function()
            return http({ Url = url, Method = "GET", Headers = { ["Accept"] = "application/json" } })
        end)

        if ok and res then
            local body = res.Body or res.body
            if type(body) == "string" and #body > 0 then
                local ok2, data = pcall(function()
                    return HttpService:JSONDecode(body)
                end)
                if ok2 and type(data) == "table" and type(data.data) == "table" then
                    for _, s in ipairs(data.data) do
                        if type(s) == "table" and s.id == jobId then
                            local pc = tonumber(s.playing) or 0
                            return pc == 1
                        end
                    end
                    cursor = data.nextPageCursor
                    if not cursor or cursor == "" or cursor == "null" then return false end
                    pages = pages + 1
                    task.wait(0.05)
                else
                    return false
                end
            else
                return false
            end
        else
            return false
        end
    end

    return false
end

local function calculateScore(server)
    local fpsScore = math.max(0, 60 - server.fps) * 2
    local pingScore = math.min(server.ping, 500) / 3
    local ageScore = (server.age or 0) * 100
    local sightScore = (server.sightings or 0) * 200
    return ageScore + sightScore + fpsScore + pingScore
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
    notify("Đang quét server 1 người", 3)

    local pool = scanPass(1, CONFIG.ScanPages, {})

    local count1 = 0
    for _ in pairs(pool) do count1 = count1 + 1 end

    if count1 == 0 then
        notify("Không có server 1 người · thử lại", 3)
        return nil
    end

    notify("Có " .. count1 .. " ứng viên · track " .. CONFIG.TrackPasses .. " pass", 3)

    local stable = trackServers(pool, 1)

    if #stable == 0 then
        notify("Không có server ổn định · thử lại", 3)
        return nil
    end

    notify("Có " .. #stable .. " server ổn định · chọn", 3)

    for _, s in ipairs(stable) do
        s.score = calculateScore(s)
    end

    table.sort(stable, function(a, b)
        return a.score > b.score
    end)

    return stable
end

local function verifyAndTeleport(candidates)
    if #candidates == 0 then return false end

    local maxTry = math.min(#candidates, 5)

    for i = 1, maxTry do
        local target = candidates[i]
        if not target then break end

        notify("Verify " .. i .. "/" .. maxTry .. " · " .. target.playing .. "ng FPS" .. target.fps, 3)

        local allVerified = true
        for check = 1, CONFIG.VerifyAttempts do
            if not verifyServerNow(target.id) then
                allVerified = false
                break
            end
            if check < CONFIG.VerifyAttempts then
                task.wait(CONFIG.VerifyGap)
            end
        end

        if not allVerified then
            State.Blacklist[target.id] = tick()
            notify("Server " .. i .. " đã full · thử server khác", 3)
        else
            notify("Server OK · teleport " .. target.playing .. "ng", 3)
            State.CurrentTargetId = target.id
            State.Blacklist[target.id] = tick()

            local success = false
            for attempt = 1, 2 do
                if attemptTeleport(target.id) then
                    success = true
                    break
                end
                task.wait(1.5)
            end

            if success then
                local startTime = tick()
                while tick() - startTime < CONFIG.TeleportTimeout do
                    if game.JobId ~= JOB_ID then
                        return true
                    end
                    task.wait(0.2)
                end
            end

            notify("Teleport fail · thử server khác", 3)
        end

        task.wait(1)
    end

    return false
end

local function performHop()
    if State.IsBusy then return false end
    State.IsBusy = true
    State.NeedHop = false

    cleanBlacklist()

    local candidates = findServer()

    if not candidates or #candidates == 0 then
        State.IsBusy = false
        notify("Không có server · dò lại sau " .. CONFIG.RetryDelay .. "s", 3)
        task.wait(CONFIG.RetryDelay)
        return false
    end

    local success = verifyAndTeleport(candidates)

    State.IsBusy = false

    if success then
        notify("Đã vào server", 3)
        task.wait(CONFIG.PostCheckDelay)

        local count = #Players:GetPlayers()
        if count > 2 then
            notify("Vào nhầm server " .. count .. " người · dò lại", 4)
            State.NeedHop = true
            return false
        end

        notify("OK · server " .. count .. " người", 3)
        return true
    else
        notify("Không vào được · dò lại sau " .. CONFIG.RetryDelay .. "s", 3)
        task.wait(CONFIG.RetryDelay)
        return false
    end
end

local function startPopupKiller()
    task.spawn(function()
        while true do
            task.wait(CONFIG.PopupCheckInterval)
            local clicked = clickPopupOk()
            if clicked then
                killPopups()
                State.IsBusy = false
                State.NeedHop = true
                notify("Đã đóng popup · dò lại", 3)
                task.wait(1.5)
            end
        end
    end)
end

local function startPlayerMonitor()
    task.spawn(function()
        while true do
            task.wait(0.5)
            if not State.AutoEnabled then continue end
            if State.IsBusy then continue end

            local count = #Players:GetPlayers()
            if count == State.LastPlayerCount then continue end

            local oldCount = State.LastPlayerCount
            State.LastPlayerCount = count

            if count > 2 then
                if oldCount <= 2 then
                    notify("Có " .. count .. " người · sẽ hop", 3)
                end
                State.NeedHop = true
            end
        end
    end)
end

local function startMainLoop()
    task.spawn(function()
        while true do
            task.wait(1)

            if not State.AutoEnabled then continue end

            if State.IsBusy then
                if tick() - State.LastLoopTime > CONFIG.StuckTimeout then
                    State.IsBusy = false
                    State.NeedHop = true
                    notify("Reset · dò lại", 3)
                end
                State.LastLoopTime = tick()
                continue
            end

            State.LastLoopTime = tick()

            local count = #Players:GetPlayers()
            if count > 2 then
                State.NeedHop = true
            end

            if State.NeedHop then
                performHop()
            end
        end
    end)
end

State.LastPlayerCount = #Players:GetPlayers()
State.LastLoopTime = tick()

startPopupKiller()
startPlayerMonitor()
startMainLoop()

notify("Script sẵn sàng", 4)

task.spawn(function()
    task.wait(2)
    if #Players:GetPlayers() > 2 then
        State.NeedHop = true
    end
end)

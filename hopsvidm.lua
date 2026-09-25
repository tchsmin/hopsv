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
    RetryDelay = 5,
    PostCheckDelay = 4,
    ScanPages = 15,
    PassDelay = 2,
    ConfirmDelay = 1,
    BlacklistTTL = 180,
    MaxBlacklist = 500,
    RequestRetries = 3,
    LeaderboardRefreshWait = 8,
    LeaderboardCheckInterval = 6,
    TeleportTimeout = 8,
}

local State = {
    Blacklist = {},
    IsScanning = false,
    IsHopping = false,
    AutoEnabled = true,
    MonitorConn = nil,
    LeaderboardConn = nil,
    LastPlayerCount = 0,
    TeleportPending = false,
    NeedHop = false,
    PostCheckGen = 0,
    FailCount = 0,
    LoopRunning = false,
    LastLeaderboardCheck = 0,
    IsTopOne = false,
    CurrentTargetId = nil,
    TeleportFailedFlag = false,
    TeleportFailReason = nil,
}

local function cleanBlacklist()
    local now = tick()
    local count = 0
    for id, t in pairs(State.Blacklist) do
        if now - t > CONFIG.BlacklistTTL then
            State.Blacklist[id] = nil
        else
            count = count + 1
        end
    end
    if count > CONFIG.MaxBlacklist then
        State.Blacklist = {}
    end
end

local function resetState()
    State.IsScanning = false
    State.IsHopping = false
    State.TeleportPending = false
    State.NeedHop = false
    State.TeleportFailedFlag = false
    State.TeleportFailReason = nil
end

pcall(function()
    TeleportService.TeleportInitFailed:Connect(function(player, teleportResult, errorMessage)
        if player ~= LocalPlayer then return end

        State.TeleportFailedFlag = true
        State.TeleportFailReason = tostring(errorMessage or teleportResult or "unknown")

        if State.CurrentTargetId then
            State.Blacklist[State.CurrentTargetId] = tick()
        end

        notify("Lỗi: " .. State.TeleportFailReason .. " · dò lại", 4)
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
        task.wait(0.3 * attempt)
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
            if type(id) == "string" and id ~= JOB_ID and not State.Blacklist[id] then
                if pc >= 1 and pc <= maxPlayers then
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
    if server.playing == 1 then playerScore = 100
    elseif server.playing == 2 then playerScore = 40
    elseif server.playing == 3 then playerScore = 10 end
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

    local pass1 = scanPass(2, CONFIG.ScanPages)

    local count1 = 0
    for _ in pairs(pass1) do count1 = count1 + 1 end

    if count1 == 0 then return nil end

    task.wait(CONFIG.PassDelay)

    local pass2 = scanPass(2, CONFIG.ScanPages)

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

    if #stable == 0 then return nil end

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

    if #pickFrom == 0 then return nil end

    local topCount = math.min(3, #pickFrom)
    return pickFrom[math.random(1, topCount)]
end

local function checkTopOneInLeaderboard()
    local found = false

    local function scanGui(gui)
        for _, obj in ipairs(gui:GetDescendants()) do
            if obj:IsA("TextLabel") or obj:IsA("TextButton") then
                pcall(function()
                    if obj.Visible and type(obj.Text) == "string" then
                        if obj.Text:find(LocalPlayer.Name) then
                            found = true
                        end
                    end
                end)
            end
            if found then return end
        end
    end

    pcall(function()
        local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
        if playerGui then scanGui(playerGui) end
    end)

    if not found then
        pcall(function()
            local coreGui = game:GetService("CoreGui")
            if coreGui then
                for _, gui in ipairs(coreGui:GetChildren()) do
                    if gui:IsA("ScreenGui") or gui:IsA("Folder") then
                        scanGui(gui)
                    end
                end
            end
        end)
    end

    return found
end

local function postCheck(myGen)
    task.wait(CONFIG.PostCheckDelay)
    if myGen ~= State.PostCheckGen then return end
    if State.IsHopping or State.IsScanning or State.TeleportPending then return end

    if State.TeleportFailedFlag then
        State.TeleportFailedFlag = false
        State.NeedHop = true
        return
    end

    local count = #Players:GetPlayers()
    if count > 2 then
        notify("Server " .. count .. " người · dò lại", 3)
        State.NeedHop = true
        return
    end

    task.wait(CONFIG.LeaderboardRefreshWait)

    if myGen ~= State.PostCheckGen then return end

    local isTop = checkTopOneInLeaderboard()

    if isTop then
        State.IsTopOne = true
        State.NeedHop = false
        State.FailCount = 0
        notify("OK · top 1 speed", 4)
    else
        State.IsTopOne = false
        notify("Không top 1 speed · dò lại", 4)
        State.NeedHop = true
    end
end

local function performHop()
    if State.IsScanning or State.IsHopping then return false end

    cleanBlacklist()

    State.IsScanning = true
    State.NeedHop = false
    State.IsTopOne = false
    State.TeleportFailedFlag = false

    local target = findServer()

    if not target then
        State.IsScanning = false
        State.FailCount = State.FailCount + 1
        notify("Không có server · thử lại " .. CONFIG.RetryDelay .. "s", 3)
        task.wait(CONFIG.RetryDelay)
        return false
    end

    notify("Vào " .. target.playing .. " người · FPS" .. target.fps .. " · P" .. target.ping, 3)

    task.wait(0.3)

    State.IsScanning = false
    State.IsHopping = true
    State.TeleportPending = true
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
            if State.TeleportFailedFlag then
                success = false
                break
            end
            task.wait(0.3)
        end
    end

    State.TeleportPending = false
    State.IsHopping = false
    State.CurrentTargetId = nil

    if success and not State.TeleportFailedFlag then
        State.PostCheckGen = State.PostCheckGen + 1
        local myGen = State.PostCheckGen
        task.spawn(function()
            postCheck(myGen)
        end)
        return true
    else
        State.TeleportFailedFlag = false
        State.FailCount = State.FailCount + 1
        notify("Vào fail · thử lại " .. CONFIG.RetryDelay .. "s", 3)
        task.wait(CONFIG.RetryDelay)
        return false
    end
end

local function startLeaderboardMonitor()
    if State.LeaderboardConn then State.LeaderboardConn:Disconnect() end

    State.LeaderboardConn = RunService.Heartbeat:Connect(function()
        if not State.AutoEnabled then return end
        if State.IsHopping or State.IsScanning or State.TeleportPending then return end

        local now = tick()
        if now - State.LastLeaderboardCheck < CONFIG.LeaderboardCheckInterval then return end
        State.LastLeaderboardCheck = now

        if #Players:GetPlayers() <= 2 then
            local isTop = checkTopOneInLeaderboard()
            if isTop then
                if not State.IsTopOne then
                    State.IsTopOne = true
                    notify("OK · top 1 speed", 3)
                end
            else
                if State.IsTopOne then
                    State.IsTopOne = false
                end
                notify("Không top 1 · dò lại", 3)
                State.NeedHop = true
            end
        end
    end)
end

local function startPlayerMonitor()
    if State.MonitorConn then State.MonitorConn:Disconnect() end
    State.MonitorConn = RunService.Heartbeat:Connect(function()
        if not State.AutoEnabled then return end
        if State.IsHopping or State.IsScanning or State.TeleportPending then return end

        local count = #Players:GetPlayers()
        if count == State.LastPlayerCount then return end

        local oldCount = State.LastPlayerCount
        State.LastPlayerCount = count

        if count > 2 then
            if oldCount <= 2 then
                notify("Có " .. count .. " người · sẽ hop", 3)
            end
            State.NeedHop = true
        end
    end)
end

local function startMainLoop()
    if State.LoopRunning then return end
    State.LoopRunning = true

    task.spawn(function()
        while true do
            task.wait(1)

            if not State.AutoEnabled then
                continue
            end

            if State.IsHopping or State.IsScanning or State.TeleportPending then
                State.StuckTimer = (State.StuckTimer or 0) + 1
                if State.StuckTimer > 30 then
                    resetState()
                    State.StuckTimer = 0
                    notify("Reset · dò lại", 3)
                    State.NeedHop = true
                end
                continue
            end

            State.StuckTimer = 0

            if State.NeedHop then
                performHop()
            end
        end
    end)
end

State.LastPlayerCount = #Players:GetPlayers()
startPlayerMonitor()
startLeaderboardMonitor()
startMainLoop()

notify("Script sẵn sàng", 4)

task.spawn(function()
    task.wait(2)
    local count = #Players:GetPlayers()
    if count > 2 then
        State.NeedHop = true
    end
end)

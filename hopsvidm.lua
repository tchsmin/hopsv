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
            Duration = duration or 3
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
local IsBusy = false
local LastPlayerCount = #Players:GetPlayers()
local NeedHop = false
local CurrentTarget = nil
local BusyStart = 0

local function nukePopups()
    pcall(function()
        local pg = CoreGui:FindFirstChild("RobloxPromptGui")
        if pg then
            local ov = pg:FindFirstChild("promptOverlay")
            if ov then
                ov.Parent = nil
                ov:Destroy()
            end
        end
    end)
end

local function clickOk()
    pcall(function()
        local pg = CoreGui:FindFirstChild("RobloxPromptGui")
        if not pg then return end
        local ov = pg:FindFirstChild("promptOverlay")
        if not ov then return end
        for _, o in ipairs(ov:GetDescendants()) do
            if o:IsA("TextButton") then
                local t = tostring(o.Text or "")
                if t == "Ok" or t == "OK" or t:lower() == "ok" then
                    if firesignal then
                        pcall(function() firesignal(o.MouseButton1Click) end)
                    end
                    if o.Activate then
                        pcall(function() o:Activate() end)
                    end
                end
            end
        end
    end)
end

pcall(function()
    TeleportService.TeleportInitFailed:Connect(function(player)
        if player ~= LocalPlayer then return end
        if CurrentTarget then
            Blacklist[CurrentTarget] = tick()
        end
        IsBusy = false
        NeedHop = true
        task.spawn(function()
            task.wait(0.1)
            clickOk()
            nukePopups()
        end)
    end)
end)

local function requestPage(cursor)
    if not http then return nil end
    local url = string.format(
        "https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100&cursor=%s",
        PLACE_ID, cursor or ""
    )
    for i = 1, 2 do
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

local function scanPass(maxPages)
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

local function score(server, stability)
    local p = 0
    if server.playing == 1 then p = 500
    elseif server.playing == 2 then p = 100 end
    local f = math.max(0, 60 - server.fps) * 1.5
    local pi = math.min(server.ping, 500) / 5
    return p + f + pi + stability * 60
end

local function attemptTeleport(jobId)
    local ok = pcall(function()
        local opts = Instance.new("TeleportOptions")
        opts.ServerInstanceId = jobId
        TeleportService:TeleportAsync(PLACE_ID, {LocalPlayer}, opts)
    end)
    if ok then return true end
    ok = pcall(function()
        TeleportService:TeleportToPlaceInstance(PLACE_ID, jobId, LocalPlayer)
    end)
    return ok
end

local function findServer()
    notify("Đang tìm server", 2)

    local pass1 = scanPass(12)
    local c1 = 0
    for _ in pairs(pass1) do c1 = c1 + 1 end

    if c1 == 0 then return nil end

    notify("Có " .. c1 .. " server · chờ 2.5s", 2)
    task.wait(2.5)

    local pass2 = scanPass(12)

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

    task.wait(1.5)

    local pool = {}
    for _, s in ipairs(stable) do
        s.score = score(s, s.stability)
        table.insert(pool, s)
    end

    table.sort(pool, function(a, b)
        return a.score > b.score
    end)

    local one = {}
    for _, s in ipairs(pool) do
        if s.playing == 1 then
            table.insert(one, s)
        end
    end

    local pickFrom = #one > 0 and one or pool
    local n = math.min(3, #pickFrom)
    return pickFrom[math.random(1, n)]
end

local function doHop()
    if IsBusy then return end
    IsBusy = true
    BusyStart = tick()
    NeedHop = false

    local now = tick()
    for id, t in pairs(Blacklist) do
        if now - t > 240 then
            Blacklist[id] = nil
        end
    end

    local target = findServer()

    if not target then
        IsBusy = false
        notify("Không có server · dò lại 4s", 3)
        task.wait(4)
        NeedHop = true
        return
    end

    notify("Vào " .. target.playing .. "ng · FPS" .. target.fps .. " · P" .. target.ping, 3)

    task.wait(0.3)

    CurrentTarget = target.id
    Blacklist[target.id] = tick()

    local success = false
    for i = 1, 2 do
        if attemptTeleport(target.id) then
            success = true
            break
        end
        task.wait(1.5)
    end

    if success then
        local t0 = tick()
        while tick() - t0 < 8 do
            if game.JobId ~= JOB_ID then
                IsBusy = false
                CurrentTarget = nil
                task.wait(5)
                local c = #Players:GetPlayers()
                if c > 2 then
                    notify("Server " .. c .. " ng · dò lại", 3)
                    NeedHop = true
                else
                    notify("OK · " .. c .. " người", 3)
                end
                return
            end
            task.wait(0.2)
        end
    end

    IsBusy = false
    CurrentTarget = nil
    notify("Fail · dò lại 4s", 3)
    task.wait(4)
    NeedHop = true
end

task.spawn(function()
    while true do
        task.wait(1)
        local ok = pcall(function()
            if IsBusy then
                if tick() - BusyStart > 60 then
                    IsBusy = false
                    NeedHop = true
                end
                return
            end
            local c = #Players:GetPlayers()
            if c > 2 then
                NeedHop = true
            end
            if NeedHop then
                doHop()
            end
        end)
        if not ok then
            IsBusy = false
            NeedHop = true
        end
    end
end)

task.spawn(function()
    while true do
        task.wait(0.2)
        pcall(function()
            clickOk()
            local pg = CoreGui:FindFirstChild("RobloxPromptGui")
            if pg and pg:FindFirstChild("promptOverlay") then
                nukePopups()
                IsBusy = false
                NeedHop = true
            end
        end)
    end
end)

task.spawn(function()
    while true do
        task.wait(0.5)
        pcall(function()
            local c = #Players:GetPlayers()
            if c ~= LastPlayerCount then
                local old = LastPlayerCount
                LastPlayerCount = c
                if c > 2 then
                    NeedHop = true
                    if old <= 2 then
                        notify("Có " .. c .. " người · sẽ hop", 3)
                    end
                end
            end
        end)
    end
end)

notify("Script sẵn sàng", 4)

task.spawn(function()
    task.wait(2)
    if #Players:GetPlayers() > 2 then
        NeedHop = true
    end
end)

local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
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
    if http_request then return http_request end
    if request then return request end
    if syn and syn.request then return syn.request end
    if fluxus and fluxus.request then return fluxus.request end
    return nil
end
local http = getHttp()

if not http then
    notify("Lỗi: không có HTTP")
    return
end

local Blacklist = {}

local function nukePopup()
    pcall(function()
        local pg = CoreGui:FindFirstChild("RobloxPromptGui")
        if not pg then return end
        local ov = pg:FindFirstChild("promptOverlay")
        if ov then
            ov.Parent = nil
            ov:Destroy()
        end
    end)
end

pcall(function()
    TeleportService.TeleportInitFailed:Connect(function(player)
        if player ~= LocalPlayer then return end
        task.spawn(nukePopup)
    end)
end)

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

    while pages < maxPages do
        local data = requestPage(cursor)
        if not data or not data.data then break end

        local cnt = 0
        for _, s in ipairs(data.data) do
            cnt = cnt + 1
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

local function doHop()
    notify("Đang tìm server", 3)

    local pass1 = scanPass(2, 12)
    local count1 = 0
    for _ in pairs(pass1) do count1 = count1 + 1 end

    if count1 == 0 then
        return nil
    end

    task.wait(2.5)

    local pass2 = scanPass(2, 12)

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
        return nil
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

local function teleportTo(target)
    Blacklist[target.id] = true

    notify("Vào " .. target.playing .. "ng FPS" .. target.fps .. " P" .. target.ping, 3)

    task.wait(0.3)

    local ok = pcall(function()
        local opts = Instance.new("TeleportOptions")
        opts.ServerInstanceId = target.id
        TeleportService:TeleportAsync(PLACE_ID, {LocalPlayer}, opts)
    end)

    if not ok then
        pcall(function()
            TeleportService:TeleportToPlaceInstance(PLACE_ID, target.id, LocalPlayer)
        end)
    end

    task.wait(6)
end

local mainThread = coroutine.create(function()
    while true do
        local ok, err = pcall(function()
            local count = #Players:GetPlayers()

            if count > 2 then
                notify("Server " .. count .. " người · dò lại", 3)

                local target = doHop()

                if target then
                    teleportTo(target)

                    task.wait(5)

                    local newCount = #Players:GetPlayers()
                    if newCount > 2 then
                        notify("Vào server " .. newCount .. "ng · dò lại", 3)
                    else
                        notify("OK · " .. newCount .. " người", 3)
                    end
                else
                    notify("Không có server · thử lại", 3)
                    task.wait(4)
                end
            end
        end)

        if not ok then
            task.wait(2)
        end

        task.wait(1)
    end
end)

coroutine.resume(mainThread)

notify("Script sẵn sàng", 4)

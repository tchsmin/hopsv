repeat task.wait() until game:IsLoaded()

local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local CoreGui = game:GetService("CoreGui")
local HttpService = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer
local PLACE_ID = 107778070777162

local CONFIG = {
    TargetPlayersPrimary = 1,
    TargetPlayersFallback = 2,
    SwitchAtPlayers = 3,
    Countdown = 3,
    ScanDelay = 1.5,
    MonitorDelay = 1,
    TeleportTimeout = 12,
    RetryDelay = 2.5,
    MaxPages = 7,
    ServersPerPage = 100,
    PreferLowFPS = true,
    PreferHighPing = true,
    AvoidCurrentServer = true,
    RequireSpeedCheck = true,
}

if game.PlaceId ~= PLACE_ID then
    return
end

local function Notify(message)
    pcall(function()
        local gui = CoreGui:FindFirstChild("SAE_AutoServerNotify")

        if not gui then
            gui = Instance.new("ScreenGui")
            gui.Name = "SAE_AutoServerNotify"
            gui.ResetOnSpawn = false
            gui.IgnoreGuiInset = true
            gui.Parent = CoreGui
        end

        local old = gui:FindFirstChild("Message")
        if old then
            old:Destroy()
        end

        local label = Instance.new("TextLabel")
        label.Name = "Message"
        label.Size = UDim2.fromOffset(430, 40)
        label.Position = UDim2.new(0.5, -215, 0, 20)
        label.BackgroundTransparency = 0.15
        label.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
        label.BorderSizePixel = 0
        label.TextColor3 = Color3.new(1, 1, 1)
        label.TextSize = 16
        label.Font = Enum.Font.GothamMedium
        label.Text = message
        label.Parent = gui

        task.delay(2.2, function()
            if label and label.Parent then
                label:Destroy()
            end
        end)
    end)

    print("[SAE]", message)
end

local function HttpGet(url)
    local funcs = {
        function()
            return game:HttpGet(url)
        end,
        function()
            return request({
                Url = url,
                Method = "GET"
            }).Body
        end,
        function()
            return http_request({
                Url = url,
                Method = "GET"
            }).Body
        end,
        function()
            return syn and syn.request({
                Url = url,
                Method = "GET"
            }).Body
        end,
    }

    for _, fn in ipairs(funcs) do
        local ok, result = pcall(fn)
        if ok and type(result) == "string" and #result > 0 then
            return result
        end
    end

    return nil
end

local function DecodeJSON(raw)
    if not raw then
        return nil
    end

    local ok, result = pcall(function()
        return HttpService:JSONDecode(raw)
    end)

    if ok then
        return result
    end

    return nil
end

local SPEED_NAMES = {
    "Speed",
    "SpeedPower",
    "Speed Power",
    "MovementSpeed",
    "MoveSpeed",
}

local function NumberFromObject(obj)
    if not obj then
        return nil
    end

    if obj:IsA("IntValue") or obj:IsA("NumberValue") then
        return tonumber(obj.Value)
    end

    if obj:IsA("StringValue") then
        return tonumber(obj.Value)
    end

    return nil
end

local function FindSpeedRecursive(root, depth)
    if not root or depth > 4 then
        return nil
    end

    for _, child in ipairs(root:GetChildren()) do
        local name = child.Name:lower()

        for _, wanted in ipairs(SPEED_NAMES) do
            if name == wanted:lower() then
                local value = NumberFromObject(child)
                if value then
                    return value
                end
            end
        end
    end

    for _, child in ipairs(root:GetChildren()) do
        local result = FindSpeedRecursive(child, depth + 1)
        if result ~= nil then
            return result
        end
    end

    return nil
end

local function GetPlayerSpeed(player)
    local speed = FindSpeedRecursive(player, 0)

    if speed ~= nil then
        return speed
    end

    for _, wanted in ipairs(SPEED_NAMES) do
        local value = player:GetAttribute(wanted)

        if typeof(value) == "number" then
            return value
        end
    end

    local character = player.Character

    if character then
        local humanoid = character:FindFirstChildOfClass("Humanoid")

        if humanoid then
            return tonumber(humanoid.WalkSpeed)
        end
    end

    return nil
end

local function IsLocalPlayerTopSpeed()
    local mySpeed = GetPlayerSpeed(LocalPlayer)

    if mySpeed == nil then
        return nil
    end

    local highest = mySpeed

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local speed = GetPlayerSpeed(player)

            if speed and speed > highest then
                highest = speed
            end
        end
    end

    return mySpeed >= highest
end

local function GetServers()
    local servers = {}
    local cursor = nil

    for _ = 1, CONFIG.MaxPages do
        local url =
            "https://games.roblox.com/v1/games/"
            .. PLACE_ID
            .. "/servers/Public?sortOrder=2&excludeFullGames=true&limit="
            .. CONFIG.ServersPerPage

        if cursor and cursor ~= "" then
            url = url .. "&cursor=" .. HttpService:UrlEncode(cursor)
        end

        local raw = HttpGet(url)
        local decoded = DecodeJSON(raw)

        if not decoded or type(decoded.data) ~= "table" then
            break
        end

        for _, server in ipairs(decoded.data) do
            local id = tostring(server.id or "")
            local playing = tonumber(server.playing) or 0
            local maxPlayers = tonumber(server.maxPlayers) or 0
            local fps = tonumber(server.fps)
            local ping = tonumber(server.ping)

            if id ~= "" and maxPlayers > playing then
                if not CONFIG.AvoidCurrentServer or id ~= game.JobId then
                    table.insert(servers, {
                        id = id,
                        playing = playing,
                        maxPlayers = maxPlayers,
                        fps = fps,
                        ping = ping
                    })
                end
            end
        end

        cursor = decoded.nextPageCursor

        if not cursor then
            break
        end

        task.wait(0.1)
    end

    return servers
end

local function ScoreServer(server)
    local score = 0

    if server.playing == CONFIG.TargetPlayersPrimary then
        score += 100000
    elseif server.playing == CONFIG.TargetPlayersFallback then
        score += 50000
    else
        score -= server.playing * 1000
    end

    if CONFIG.PreferLowFPS and server.fps then
        score += math.max(0, 100 - server.fps) * 10
    end

    if CONFIG.PreferHighPing and server.ping then
        score += math.min(server.ping, 1000)
    end

    local freeSlots = server.maxPlayers - server.playing

    if freeSlots > 0 then
        score += math.max(0, 20 - freeSlots)
    end

    return score
end

local function SortServers(servers)
    table.sort(servers, function(a, b)
        local sa = ScoreServer(a)
        local sb = ScoreServer(b)

        if sa ~= sb then
            return sa > sb
        end

        if a.playing ~= b.playing then
            return a.playing < b.playing
        end

        return tostring(a.id) < tostring(b.id)
    end)

    return servers
end

local function FindBestServer()
    Notify("ĐANG TÌM SERVER...")

    local servers = GetServers()

    if #servers == 0 then
        return nil
    end

    local onePlayer = {}

    for _, server in ipairs(servers) do
        if server.playing == CONFIG.TargetPlayersPrimary then
            table.insert(onePlayer, server)
        end
    end

    if #onePlayer > 0 then
        SortServers(onePlayer)
        return onePlayer[1]
    end

    local twoPlayers = {}

    for _, server in ipairs(servers) do
        if server.playing == CONFIG.TargetPlayersFallback then
            table.insert(twoPlayers, server)
        end
    end

    if #twoPlayers > 0 then
        SortServers(twoPlayers)
        return twoPlayers[1]
    end

    return nil
end

local teleporting = false

local function TeleportToServer(server)
    if not server or not server.id or teleporting then
        return false
    end

    teleporting = true

    Notify("ĐÃ CHỌN SERVER " .. server.playing .. " NGƯỜI")

    local success = false

    for attempt = 1, 3 do
        local ok = pcall(function()
            TeleportService:TeleportToPlaceInstance(
                PLACE_ID,
                server.id,
                LocalPlayer
            )
        end)

        if ok then
            success = true
            break
        end

        Notify("LỖI TELEPORT - THỬ LẠI " .. attempt .. "/3")
        task.wait(CONFIG.RetryDelay)
    end

    if not success then
        teleporting = false
        return false
    end

    return true
end

local function WaitForArrival(oldJobId)
    local started = os.clock()

    while os.clock() - started < CONFIG.TeleportTimeout do
        task.wait(0.5)

        if game.JobId ~= oldJobId then
            return true
        end
    end

    return false
end

local function Countdown()
    for i = CONFIG.Countdown, 1, -1 do
        if #Players:GetPlayers() >= CONFIG.SwitchAtPlayers then
            Notify("SERVER " .. #Players:GetPlayers() .. " NGƯỜI - CHUYỂN " .. i)
        else
            return false
        end

        task.wait(1)

        if #Players:GetPlayers() <= CONFIG.TargetPlayersFallback then
            Notify("SERVER GIẢM NGƯỜI - HỦY CHUYỂN")
            return false
        end
    end

    return true
end

local function InitialJoin()
    local count = #Players:GetPlayers()

    if count <= CONFIG.TargetPlayersFallback then
        Notify("SẴN SÀNG - SERVER " .. count .. " NGƯỜI")
        return true
    end

    local server = FindBestServer()

    if not server then
        Notify("LỖI - KHÔNG TÌM THẤY SERVER PHÙ HỢP")
        return false
    end

    local oldJob = game.JobId

    if not TeleportToServer(server) then
        return false
    end

    WaitForArrival(oldJob)

    return true
end

local function Monitor()
    Notify("ĐÃ VÀO SERVER - ĐANG THEO DÕI")

    while task.wait(CONFIG.MonitorDelay) do
        if game.PlaceId ~= PLACE_ID then
            return
        end

        local playerCount = #Players:GetPlayers()

        if playerCount <= CONFIG.TargetPlayersFallback then
            continue
        end

        if playerCount >= CONFIG.SwitchAtPlayers then
            local topSpeed = IsLocalPlayerTopSpeed()

            if topSpeed == true then
                Notify("TOP 1 TỐC ĐỘ - GIỮ SERVER")
                continue
            end

            if topSpeed == nil and CONFIG.RequireSpeedCheck then
                Notify("CHƯA ĐỌC ĐƯỢC SPEED - GIỮ SERVER")
                task.wait(2)
                continue
            end

            local shouldSwitch = Countdown()

            if not shouldSwitch then
                continue
            end

            if #Players:GetPlayers() <= CONFIG.TargetPlayersFallback then
                continue
            end

            local finalTopCheck = IsLocalPlayerTopSpeed()

            if finalTopCheck == true then
                Notify("ĐÃ LÊN TOP 1 - HỦY CHUYỂN")
                continue
            end

            local server = FindBestServer()

            if server then
                local oldJobId = game.JobId

                Notify("ĐANG CHUYỂN SERVER...")

                if TeleportToServer(server) then
                    local arrived = WaitForArrival(oldJobId)

                    if not arrived then
                        teleporting = false
                        Notify("TELEPORT TIMEOUT - TÌM LẠI")
                    end
                else
                    Notify("TELEPORT LỖI - TÌM SERVER KHÁC")
                end
            else
                Notify("CHƯA CÓ SERVER 1/2 NGƯỜI - TIẾP TỤC TÌM")
            end

            teleporting = false
        end
    end
end

local function Start()
    Notify("SẴN SÀNG")

    while true do
        local ok = pcall(function()
            InitialJoin()
        end)

        if ok then
            break
        end

        Notify("LỖI - ĐANG THỬ LẠI...")
        task.wait(CONFIG.RetryDelay)
    end

    teleporting = false

    while true do
        local ok = pcall(Monitor)

        if not ok then
            teleporting = false
            Notify("LỖI GIÁM SÁT - ĐANG KHÔI PHỤC...")
            task.wait(CONFIG.RetryDelay)
        end
    end
end

task.spawn(Start)

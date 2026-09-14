local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local CoreGui = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local StarterGui = game:GetService("StarterGui")

local LocalPlayer = Players.LocalPlayer
local PLACE_ID = game.PlaceId
local JOB_ID = game.JobId

local CONFIG = {
    SCAN_LIMIT = 700,
    PAGE_SIZE = 100,
    PAGE_DELAY_MIN = 0.28,
    PAGE_DELAY_MAX = 0.48,
    PRE_HOP_DELAY_MIN = 1.2,
    PRE_HOP_DELAY_MAX = 2.0,
    FPS_CEILING = 45,
    PING_FLOOR = 120,
    PING_CEILING = 680,
    PLAYER_SOFT_CAP = 2,
    RANDOM_POOL = 4,
    BLACKLIST_TTL = 900,
    CACHE_TTL = 60,
    AUTO_RETRY = true,
    RETRY_LIMIT = 3,
    RETRY_BACKOFF = 1.8,
    NOTIFY = true
}

local RUNTIME = {
    blacklist = {},
    cache = {},
    busy = false,
    loaderActive = false,
    loaderThread = nil,
    pulseActive = false,
    pulseConn = nil,
    stats = {
        scans = 0,
        scanned = 0,
        candidates = 0,
        hops = 0,
        fails = 0,
        sessionStart = tick()
    },
    lastError = nil
}

local function acquireHttp()
    local pool = {
        rawget(getfenv(), "http_request"),
        rawget(getfenv(), "request"),
        syn and syn.request,
        fluxus and fluxus.request,
        http and http.request,
        krypt and krypt.request,
        codex and codex.request
    }
    for _, fn in ipairs(pool) do
        if type(fn) == "function" then
            return fn
        end
    end
    return nil
end

local HTTP = acquireHttp()

local function randRange(a, b)
    return a + math.random() * (b - a)
end

local function pause(min, max)
    if min == max then
        task.wait(min)
    else
        task.wait(randRange(min, max))
    end
end

local function callSafe(fn)
    local ok, result = pcall(fn)
    return ok, result
end

local function isBlacklisted(id)
    if not id then return false end
    local item = RUNTIME.blacklist[id]
    if not item then return false end
    if tick() > item.expires then
        RUNTIME.blacklist[id] = nil
        return false
    end
    return true
end

local function blacklist(id)
    if not id then return end
    RUNTIME.blacklist[id] = {
        created = tick(),
        expires = tick() + CONFIG.BLACKLIST_TTL
    }
end

local function getCache(id)
    local item = RUNTIME.cache[id]
    if not item then return nil end
    if tick() - item.cachedAt > CONFIG.CACHE_TTL then
        RUNTIME.cache[id] = nil
        return nil
    end
    return item
end

local function setCache(id, data)
    data.cachedAt = tick()
    RUNTIME.cache[id] = data
end

local function notify(title, text)
    if not CONFIG.NOTIFY then return end
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = title,
            Text = text,
            Duration = 3
        })
    end)
end

if CoreGui:FindFirstChild("HopUI") then
    CoreGui.HopUI:Destroy()
end

local gui = Instance.new("ScreenGui")
gui.Name = "HopUI"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.IgnoreGuiInset = true
gui.DisplayOrder = 999999
gui.Parent = CoreGui

local root = Instance.new("Frame")
root.Name = "Root"
root.Size = UDim2.new(0, 240, 0, 140)
root.Position = UDim2.new(0, 20, 0, 80)
root.BackgroundTransparency = 1
root.Parent = gui

local halo = Instance.new("ImageLabel")
halo.Name = "Halo"
halo.Size = UDim2.new(0, 120, 0, 120)
halo.Position = UDim2.new(0.5, -60, 0, -22)
halo.BackgroundTransparency = 1
halo.Image = "rbxassetid://5028857084"
halo.ImageColor3 = Color3.fromRGB(60, 180, 120)
halo.ImageTransparency = 0.85
halo.ZIndex = 0
halo.Parent = root

local mainBtn = Instance.new("TextButton")
mainBtn.Name = "MainBtn"
mainBtn.Size = UDim2.new(0, 80, 0, 80)
mainBtn.Position = UDim2.new(0.5, -40, 0, 0)
mainBtn.BackgroundColor3 = Color3.fromRGB(60, 180, 120)
mainBtn.Text = "HOP"
mainBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
mainBtn.Font = Enum.Font.GothamBold
mainBtn.TextSize = 18
mainBtn.AutoButtonColor = false
mainBtn.Active = true
mainBtn.ZIndex = 2
mainBtn.Parent = root

local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(1, 0)
mainCorner.Parent = mainBtn

local mainGradient = Instance.new("UIGradient")
mainGradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(90, 230, 160)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(40, 130, 95))
})
mainGradient.Rotation = 90
mainGradient.Parent = mainBtn

local mainStroke = Instance.new("UIStroke")
mainStroke.Color = Color3.fromRGB(255, 255, 255)
mainStroke.Thickness = 1.5
mainStroke.Transparency = 0.45
mainStroke.Parent = mainBtn

local bar = Instance.new("Frame")
bar.Name = "Bar"
bar.Size = UDim2.new(1, 0, 0, 32)
bar.Position = UDim2.new(0, 0, 0, 88)
bar.BackgroundColor3 = Color3.fromRGB(18, 20, 28)
bar.BackgroundTransparency = 0.05
bar.BorderSizePixel = 0
bar.ZIndex = 2
bar.Parent = root

local barCorner = Instance.new("UICorner")
barCorner.CornerRadius = UDim.new(0, 8)
barCorner.Parent = bar

local barStroke = Instance.new("UIStroke")
barStroke.Color = Color3.fromRGB(80, 120, 180)
barStroke.Thickness = 1
barStroke.Transparency = 0.6
barStroke.Parent = bar

local icon = Instance.new("TextLabel")
icon.Name = "Icon"
icon.Size = UDim2.new(0, 28, 1, 0)
icon.Position = UDim2.new(0, 4, 0, 0)
icon.BackgroundTransparency = 1
icon.Text = "●"
icon.TextColor3 = Color3.fromRGB(120, 200, 255)
icon.Font = Enum.Font.GothamBold
icon.TextSize = 14
icon.ZIndex = 3
icon.Parent = bar

local text = Instance.new("TextLabel")
text.Name = "Text"
text.Size = UDim2.new(1, -70, 1, 0)
text.Position = UDim2.new(0, 32, 0, 0)
text.BackgroundTransparency = 1
text.Text = "Sẵn sàng"
text.TextColor3 = Color3.fromRGB(200, 220, 255)
text.Font = Enum.Font.GothamBold
text.TextSize = 11
text.TextXAlignment = Enum.TextXAlignment.Left
text.TextTruncate = Enum.TextTruncate.AtEnd
text.ZIndex = 3
text.Parent = bar

local progressBg = Instance.new("Frame")
progressBg.Name = "ProgressBg"
progressBg.Size = UDim2.new(1, -8, 0, 3)
progressBg.Position = UDim2.new(0, 4, 1, -5)
progressBg.BackgroundColor3 = Color3.fromRGB(40, 50, 70)
progressBg.BorderSizePixel = 0
progressBg.ZIndex = 4
progressBg.Parent = bar

local progressBgCorner = Instance.new("UICorner")
progressBgCorner.CornerRadius = UDim.new(1, 0)
progressBgCorner.Parent = progressBg

local progressFill = Instance.new("Frame")
progressFill.Name = "ProgressFill"
progressFill.Size = UDim2.new(0, 0, 1, 0)
progressFill.BackgroundColor3 = Color3.fromRGB(120, 200, 255)
progressFill.BorderSizePixel = 0
progressFill.ZIndex = 5
progressFill.Parent = progressBg

local progressFillCorner = Instance.new("UICorner")
progressFillCorner.CornerRadius = UDim.new(1, 0)
progressFillCorner.Parent = progressFill

local progressGradient = Instance.new("UIGradient")
progressGradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(100, 180, 255)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(180, 120, 255))
})
progressGradient.Parent = progressFill

local stats = Instance.new("TextLabel")
stats.Name = "Stats"
stats.Size = UDim2.new(1, 0, 0, 14)
stats.Position = UDim2.new(0, 0, 1, 6)
stats.BackgroundTransparency = 1
stats.Text = "Sẵn sàng hoạt động"
stats.TextColor3 = Color3.fromRGB(130, 150, 180)
stats.Font = Enum.Font.Gotham
stats.TextSize = 9
stats.ZIndex = 2
stats.Parent = root

local SPINNERS = {
    dots = {"", ".", "..", "...", "...."},
    braille = {"⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"},
    arrow = {"←", "↖", "↑", "↗", "→", "↘", "↓", "↙"},
    block = {"▁", "▂", "▃", "▄", "▅", "▆", "▇", "█", "▇", "▆", "▅", "▄", "▃", "▂"},
    pulse = {"◐", "◓", "◑", "◒"},
    target = {"◜", "◝", "◞", "◟"},
    dots2 = {"⣾", "⣽", "⣻", "⢿", "⡿", "⣟", "⣯", "⣷"}
}

local activeSpinner = SPINNERS.dots
local activeBaseText = ""

local function startPulse(color)
    RUNTIME.pulseActive = false
    if RUNTIME.pulseConn then
        RUNTIME.pulseConn:Disconnect()
        RUNTIME.pulseConn = nil
    end
    halo.ImageColor3 = color or Color3.fromRGB(60, 180, 120)
    RUNTIME.pulseActive = true

    local startTime = tick()
    RUNTIME.pulseConn = RunService.Heartbeat:Connect(function()
        if not RUNTIME.pulseActive then return end
        if not halo or not halo.Parent then return end
        local t = (tick() - startTime) * 2
        local wave = (math.sin(t) + 1) / 2
        halo.ImageTransparency = 0.7 - (wave * 0.35)
        local size = 120 + wave * 25
        halo.Size = UDim2.new(0, size, 0, size)
        halo.Position = UDim2.new(0.5, -size / 2, 0, -22 - (size - 120) / 2)
    end)
end

local function stopPulse()
    RUNTIME.pulseActive = false
    if RUNTIME.pulseConn then
        RUNTIME.pulseConn:Disconnect()
        RUNTIME.pulseConn = nil
    end
    TweenService:Create(halo, TweenInfo.new(0.3), {
        ImageTransparency = 0.85,
        Size = UDim2.new(0, 120, 0, 120),
        Position = UDim2.new(0.5, -60, 0, -22)
    }):Play()
end

local function pressDown()
    TweenService:Create(mainBtn, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Size = UDim2.new(0, 72, 0, 72),
        Position = UDim2.new(0.5, -36, 0, 4)
    }):Play()
end

local function pressUp()
    TweenService:Create(mainBtn, TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Size = UDim2.new(0, 80, 0, 80),
        Position = UDim2.new(0.5, -40, 0, 0)
    }):Play()
end

local function refreshStats()
    local elapsed = tick() - RUNTIME.stats.sessionStart
    stats.Text = string.format("Scan %d • Hops %d • Found %d • %ds",
        RUNTIME.stats.scans,
        RUNTIME.stats.hops,
        RUNTIME.stats.candidates,
        math.floor(elapsed))
end

local function startLoading(label, spinnerKey, iconChar, color)
    RUNTIME.loaderActive = false
    task.wait()
    RUNTIME.loaderActive = true

    activeBaseText = label
    activeSpinner = SPINNERS[spinnerKey] or SPINNERS.dots

    local c = color or Color3.fromRGB(120, 200, 255)
    text.TextColor3 = c
    icon.Text = iconChar or "●"
    icon.TextColor3 = c
    progressFill.BackgroundColor3 = c

    RUNTIME.loaderThread = task.spawn(function()
        local i = 1
        local startTime = tick()
        while RUNTIME.loaderActive do
            local elapsed = tick() - startTime

            if activeSpinner == SPINNERS.dots then
                local dots = math.floor(elapsed * 3) % 5
                text.Text = activeBaseText .. string.rep(".", dots)
            else
                text.Text = activeBaseText .. " " .. activeSpinner[i]
                i = i + 1
                if i > #activeSpinner then i = 1 end
            end

            if activeSpinner == SPINNERS.block then
                progressFill.Size = UDim2.new(
                    (math.sin(elapsed * 3) + 1) / 2 * 0.9 + 0.1, 0, 1, 0
                )
            elseif activeSpinner == SPINNERS.pulse then
                local p = (elapsed % 1.5) / 1.5
                progressFill.Size = UDim2.new(p, 0, 1, 0)
            elseif activeSpinner == SPINNERS.target then
                local p = (math.sin(elapsed * 2) + 1) / 2
                progressFill.Size = UDim2.new(p * 0.9 + 0.05, 0, 1, 0)
            else
                local p = (elapsed % 2) / 2
                progressFill.Size = UDim2.new(p, 0, 1, 0)
            end

            task.wait(0.05)
        end
    end)
end

local function stopLoading(finalText, color)
    RUNTIME.loaderActive = false
    RUNTIME.loaderThread = nil
    if finalText then
        text.Text = finalText
        text.TextColor3 = color or Color3.fromRGB(200, 220, 255)
        icon.TextColor3 = color or Color3.fromRGB(120, 200, 255)
        progressFill.BackgroundColor3 = color or Color3.fromRGB(120, 200, 255)
    end
    TweenService:Create(progressFill, TweenInfo.new(0.3), {
        Size = UDim2.new(0, 0, 1, 0)
    }):Play()
    task.delay(0.3, refreshStats)
end

local drag = {
    active = false,
    startInput = nil,
    startPos = nil,
    moved = false
}

mainBtn.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        drag.active = true
        drag.moved = false
        drag.startInput = input.Position
        drag.startPos = root.Position
        pressDown()
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if not drag.active then return end
    if input.UserInputType ~= Enum.UserInputType.MouseMovement
        and input.UserInputType ~= Enum.UserInputType.Touch then return end
    local delta = input.Position - drag.startInput
    if math.abs(delta.X) > 8 or math.abs(delta.Y) > 8 then
        drag.moved = true
    end
    root.Position = UDim2.new(
        drag.startPos.X.Scale,
        drag.startPos.X.Offset + delta.X,
        drag.startPos.Y.Scale,
        drag.startPos.Y.Offset + delta.Y
    )
end)

UserInputService.InputEnded:Connect(function(input)
    if not drag.active then return end
    if input.UserInputType ~= Enum.UserInputType.MouseButton1
        and input.UserInputType ~= Enum.UserInputType.Touch then return end
    drag.active = false
    pressUp()
    if not drag.moved then
        task.spawn(function()
            local ok = pcall(executeHopPipeline)
            if not ok then
                stopLoading("Lỗi hệ thống!", Color3.fromRGB(255, 100, 100))
                stopPulse()
                RUNTIME.busy = false
            end
        end)
    end
end)

local function fetchPage(cursor)
    if not HTTP then return nil end
    local url = string.format(
        "https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=%d&cursor=%s",
        PLACE_ID, CONFIG.PAGE_SIZE, cursor or ""
    )
    local ok, res = callSafe(function()
        return HTTP({
            Url = url,
            Method = "GET",
            Headers = {
                ["Accept"] = "application/json",
                ["User-Agent"] = "Roblox/WinInet"
            }
        })
    end)
    if not ok or not res or not res.Body then return nil end
    local ok2, data = callSafe(function()
        return HttpService:JSONDecode(res.Body)
    end)
    if not ok2 or not data then return nil end
    return data
end

local function streamServers(onPage)
    local cursor = ""
    local scanned = 0
    local pages = 0
    local maxPages = math.ceil(CONFIG.SCAN_LIMIT / CONFIG.PAGE_SIZE)

    while pages < maxPages and scanned < CONFIG.SCAN_LIMIT do
        local data = fetchPage(cursor)
        if not data or not data.data then break end

        local pageList = {}
        local pageCount = 0

        for _, s in ipairs(data.data) do
            pageCount = pageCount + 1
            scanned = scanned + 1

            local id = s.id
            local pc = s.playing or 0
            local ping = s.ping or 999
            local fps = s.fps or 60

            if id and id ~= JOB_ID and not isBlacklisted(id) then
                if pc >= 1 and pc <= CONFIG.PLAYER_SOFT_CAP then
                    if ping >= CONFIG.PING_FLOOR and ping <= CONFIG.PING_CEILING then
                        if fps > 0 and fps <= CONFIG.FPS_CEILING then
                            local server = {
                                id = id,
                                playing = pc,
                                max = s.maxPlayers or 12,
                                ping = ping,
                                fps = fps,
                                discovered = tick()
                            }
                            table.insert(pageList, server)
                            setCache(id, server)
                        end
                    end
                end
            end

            if scanned >= CONFIG.SCAN_LIMIT then break end
        end

        if onPage then
            onPage(pageList, scanned)
        end

        if pageCount == 0 then break end

        cursor = data.nextPageCursor
        if not cursor or cursor == "" or cursor == "null" then break end

        pages = pages + 1
        pause(CONFIG.PAGE_DELAY_MIN, CONFIG.PAGE_DELAY_MAX)
    end

    return scanned
end

local function scorePlayerCount(pc)
    if pc == 1 then return 150 end
    if pc == 2 then return 45 end
    return 0
end

local function scoreFPSValue(fps)
    local inverted = math.max(0, CONFIG.FPS_CEILING - fps)
    return inverted * 2.2
end

local function scorePingValue(ping)
    local center = (CONFIG.PING_FLOOR + CONFIG.PING_CEILING) / 2
    local distance = math.abs(ping - center)
    local maxDistance = (CONFIG.PING_CEILING - CONFIG.PING_FLOOR) / 2
    local normalized = 1 - (distance / maxDistance)
    return normalized * 70
end

local function scoreCandidate(server)
    local a = scorePlayerCount(server.playing)
    local b = scoreFPSValue(server.fps)
    local c = scorePingValue(server.ping)
    local bonus = 0
    if server.playing == 1 and server.fps <= 20 and server.ping >= 300 then
        bonus = 40
    end
    return a + b + c + bonus
end

local function rankPool(pool)
    for _, s in ipairs(pool) do
        s.score = scoreCandidate(s)
    end
    table.sort(pool, function(a, b)
        if a.score ~= b.score then
            return a.score > b.score
        end
        return a.discovered > b.discovered
    end)
    return pool
end

local function filterUnique(pool)
    local seen = {}
    local unique = {}
    for _, s in ipairs(pool) do
        if not seen[s.id] then
            seen[s.id] = true
            table.insert(unique, s)
        end
    end
    return unique
end

local function pickTarget(pool)
    if #pool == 0 then return nil end

    local onePlayer = {}
    for _, s in ipairs(pool) do
        if s.playing == 1 then
            table.insert(onePlayer, s)
        end
    end

    local pickFrom = #onePlayer > 0 and onePlayer or pool

    local topN = math.min(CONFIG.RANDOM_POOL, #pickFrom)
    return pickFrom[math.random(1, topN)]
end

local function teleportTo(target)
    blacklist(target.id)

    local ok = pcall(function()
        TeleportService:TeleportToPlaceInstance(
            PLACE_ID,
            target.id,
            LocalPlayer
        )
    end)

    return ok
end

function executeHopPipeline()
    if RUNTIME.busy then return end
    RUNTIME.busy = true
    RUNTIME.stats.scans = RUNTIME.stats.scans + 1

    startPulse(Color3.fromRGB(255, 200, 100))
    startLoading("Đang quét toàn bộ server", "braille", "◉", Color3.fromRGB(255, 200, 100))
    pause(0.4, 0.8)

    if not HTTP then
        RUNTIME.busy = false
        stopLoading("Không có HTTP!", Color3.fromRGB(255, 100, 100))
        stopPulse()
        return
    end

    local allPool = {}
    local liveCount = 0

    local scanned = streamServers(function(pageList, scannedSoFar)
        for _, s in ipairs(pageList) do
            table.insert(allPool, s)
        end

        RUNTIME.stats.scanned = RUNTIME.stats.scanned + #pageList
        RUNTIME.stats.candidates = #allPool

        liveCount = scannedSoFar
        local pct = scannedSoFar / CONFIG.SCAN_LIMIT
        progressFill.Size = UDim2.new(pct * 0.85, 0, 1, 0)

        if #allPool > 0 then
            text.Text = string.format("Đang quét • tìm thấy %d", #allPool)
        end
    end)

    if RUNTIME.stats.candidates == 0 and #allPool == 0 then
        RUNTIME.busy = false
        stopLoading("Không có server phù hợp!", Color3.fromRGB(255, 100, 100))
        stopPulse()
        return
    end

    startLoading("Đang xếp hạng", "target", "◆", Color3.fromRGB(100, 180, 255))
    startPulse(Color3.fromRGB(100, 180, 255))
    pause(1.2, 2.0)

    local unique = filterUnique(allPool)
    local ranked = rankPool(unique)

    if #ranked == 0 then
        RUNTIME.busy = false
        stopLoading("Không có server hợp lệ!", Color3.fromRGB(255, 100

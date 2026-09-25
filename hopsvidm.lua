local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local CoreGui = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local PLACE_ID = game.PlaceId
local JOB_ID = game.JobId

local function getHttp()
    if http_request then return http_request end
    if request then return request end
    if syn and syn.request then return syn.request end
    if fluxus and fluxus.request then return fluxus.request end
    return nil
end
local http = getHttp()

local CONFIG = {
    PassDelay = 0.4,
    ConfirmDelay = 0.2,
    PreTeleportDelay = 0.15,
    MaxPages = 40,
    ParallelBranches = 6,
    AutoHopDelay = 3,
    MaxTotalAllowed = 2,
    LoopWait = 1.5,
    TeleportWait = 4,
}

local Blacklist = {}
local IsRunning = true
local IsHopping = false

if CoreGui:FindFirstChild("PhantomUI") then CoreGui.PhantomUI:Destroy() end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "PhantomUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.IgnoreGuiInset = true
ScreenGui.DisplayOrder = 999999
ScreenGui.Parent = CoreGui

local Main = Instance.new("Frame")
Main.Size = UDim2.new(0, 200, 0, 108)
Main.Position = UDim2.new(0, 20, 0.5, -54)
Main.BackgroundColor3 = Color3.fromRGB(16, 18, 26)
Main.BorderSizePixel = 0
Main.Active = true
Main.Parent = ScreenGui

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 12)
MainCorner.Parent = Main

local MainStroke = Instance.new("UIStroke")
MainStroke.Color = Color3.fromRGB(120, 80, 255)
MainStroke.Thickness = 1
MainStroke.Transparency = 0.3
MainStroke.Parent = Main

local Header = Instance.new("Frame")
Header.Size = UDim2.new(1, 0, 0, 32)
Header.BackgroundTransparency = 1
Header.Parent = Main

local TitleText = Instance.new("TextLabel")
TitleText.Size = UDim2.new(1, -24, 1, 0)
TitleText.Position = UDim2.new(0, 12, 0, 0)
TitleText.BackgroundTransparency = 1
TitleText.Text = "HOP SERVER"
TitleText.TextColor3 = Color3.fromRGB(240, 240, 255)
TitleText.Font = Enum.Font.GothamBold
TitleText.TextSize = 12
TitleText.TextXAlignment = Enum.TextXAlignment.Left
TitleText.Parent = Header

local HeaderDot = Instance.new("Frame")
HeaderDot.Size = UDim2.new(0, 6, 0, 6)
HeaderDot.Position = UDim2.new(1, -16, 0.5, -3)
HeaderDot.BackgroundColor3 = Color3.fromRGB(120, 80, 255)
HeaderDot.BorderSizePixel = 0
HeaderDot.Parent = Header

local HdCorner = Instance.new("UICorner")
HdCorner.CornerRadius = UDim.new(1, 0)
HdCorner.Parent = HeaderDot

local Divider = Instance.new("Frame")
Divider.Size = UDim2.new(1, -24, 0, 1)
Divider.Position = UDim2.new(0, 12, 0, 34)
Divider.BackgroundColor3 = Color3.fromRGB(35, 40, 55)
Divider.BorderSizePixel = 0
Divider.Parent = Main

local PlayerRow = Instance.new("Frame")
PlayerRow.Size = UDim2.new(1, -24, 0, 30)
PlayerRow.Position = UDim2.new(0, 12, 0, 40)
PlayerRow.BackgroundColor3 = Color3.fromRGB(24, 27, 38)
PlayerRow.BorderSizePixel = 0
PlayerRow.Parent = Main

local PRCorner = Instance.new("UICorner")
PRCorner.CornerRadius = UDim.new(0, 7)
PRCorner.Parent = PlayerRow

local PlayerIcon = Instance.new("TextLabel")
PlayerIcon.Size = UDim2.new(0, 30, 1, 0)
PlayerIcon.Position = UDim2.new(0, 2, 0, 0)
PlayerIcon.BackgroundTransparency = 1
PlayerIcon.Text = "👥"
PlayerIcon.TextColor3 = Color3.fromRGB(120, 180, 255)
PlayerIcon.Font = Enum.Font.GothamBold
PlayerIcon.TextSize = 14
PlayerIcon.Parent = PlayerRow

local PlayerLabel = Instance.new("TextLabel")
PlayerLabel.Size = UDim2.new(1, -100, 1, 0)
PlayerLabel.Position = UDim2.new(0, 34, 0, 0)
PlayerLabel.BackgroundTransparency = 1
PlayerLabel.Text = "Số người"
PlayerLabel.TextColor3 = Color3.fromRGB(160, 170, 200)
PlayerLabel.Font = Enum.Font.Gotham
PlayerLabel.TextSize = 10
PlayerLabel.TextXAlignment = Enum.TextXAlignment.Left
PlayerLabel.Parent = PlayerRow

local PlayerValue = Instance.new("TextLabel")
PlayerValue.Size = UDim2.new(0, 60, 1, 0)
PlayerValue.Position = UDim2.new(1, -66, 0, 0)
PlayerValue.BackgroundTransparency = 1
PlayerValue.Text = "1"
PlayerValue.TextColor3 = Color3.fromRGB(120, 255, 160)
PlayerValue.Font = Enum.Font.GothamBold
PlayerValue.TextSize = 13
PlayerValue.TextXAlignment = Enum.TextXAlignment.Right
PlayerValue.Parent = PlayerRow

local StatusRow = Instance.new("Frame")
StatusRow.Size = UDim2.new(1, -24, 0, 30)
StatusRow.Position = UDim2.new(0, 12, 0, 76)
StatusRow.BackgroundColor3 = Color3.fromRGB(24, 27, 38)
StatusRow.BorderSizePixel = 0
StatusRow.Parent = Main

local SRCorner = Instance.new("UICorner")
SRCorner.CornerRadius = UDim.new(0, 7)
SRCorner.Parent = StatusRow

local StatusDot = Instance.new("Frame")
StatusDot.Size = UDim2.new(0, 8, 0, 8)
StatusDot.Position = UDim2.new(0, 12, 0.5, -4)
StatusDot.BackgroundColor3 = Color3.fromRGB(60, 220, 120)
StatusDot.BorderSizePixel = 0
StatusDot.Parent = StatusRow

local DotCorner = Instance.new("UICorner")
DotCorner.CornerRadius = UDim.new(1, 0)
DotCorner.Parent = StatusDot

local DotPulse = Instance.new("Frame")
DotPulse.Size = UDim2.new(1, 0, 1, 0)
DotPulse.BackgroundColor3 = Color3.fromRGB(60, 220, 120)
DotPulse.BackgroundTransparency = 0.6
DotPulse.BorderSizePixel = 0
DotPulse.Parent = StatusDot

local PulseCorner = Instance.new("UICorner")
PulseCorner.CornerRadius = UDim.new(1, 0)
PulseCorner.Parent = DotPulse

task.spawn(function()
    while ScreenGui.Parent do
        DotPulse.Size = UDim2.new(1, 0, 1, 0)
        DotPulse.Position = UDim2.new(0, 0, 0, 0)
        DotPulse.BackgroundTransparency = 0.6
        task.wait(1)
        DotPulse:TweenSizeAndPosition(
            UDim2.new(3, 0, 3, 0),
            UDim2.new(-1, 0, -1, 0),
            Enum.EasingDirection.Out,
            Enum.EasingStyle.Sine,
            0.8
        )
        DotPulse.BackgroundTransparency = 1
        task.wait(0.8)
    end
end)

local StatusLabel = Instance.new("TextLabel")
StatusLabel.Size = UDim2.new(1, -100, 1, 0)
StatusLabel.Position = UDim2.new(0, 26, 0, 0)
StatusLabel.BackgroundTransparency = 1
StatusLabel.Text = "Đang chạy"
StatusLabel.TextColor3 = Color3.fromRGB(160, 170, 200)
StatusLabel.Font = Enum.Font.Gotham
StatusLabel.TextSize = 10
StatusLabel.TextXAlignment = Enum.TextXAlignment.Left
StatusLabel.Parent = StatusRow

local StatusValue = Instance.new("TextLabel")
StatusValue.Size = UDim2.new(0, 60, 1, 0)
StatusValue.Position = UDim2.new(1, -66, 0, 0)
StatusValue.BackgroundTransparency = 1
StatusValue.Text = "ON"
StatusValue.TextColor3 = Color3.fromRGB(120, 255, 160)
StatusValue.Font = Enum.Font.GothamBold
StatusValue.TextSize = 11
StatusValue.TextXAlignment = Enum.TextXAlignment.Right
StatusValue.Parent = StatusRow

local function setStatus(text, color, state)
    StatusLabel.Text = text
    StatusValue.Text = state or ""
    StatusValue.TextColor3 = color or Color3.fromRGB(120, 255, 160)
    StatusDot.BackgroundColor3 = color or Color3.fromRGB(60, 220, 120)
    DotPulse.BackgroundColor3 = color or Color3.fromRGB(60, 220, 120)
end

local function updatePlayerCount()
    local count = #Players:GetPlayers()
    PlayerValue.Text = tostring(count)
    if count <= 2 then
        PlayerValue.TextColor3 = Color3.fromRGB(120, 255, 160)
    else
        PlayerValue.TextColor3 = Color3.fromRGB(255, 120, 120)
    end
    return count
end

Players.PlayerAdded:Connect(function() task.wait(0.2) updatePlayerCount() end)
Players.PlayerRemoving:Connect(function() task.wait(0.4) updatePlayerCount() end)

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
    if type(body) ~= "string" then return nil end
    local ok2, data = pcall(function()
        return HttpService:JSONDecode(body)
    end)
    if not ok2 or type(data) ~= "table" then return nil end
    return data
end

local function scanParallel()
    local result = {}
    local lockRef = {false}

    local first = requestPage("")
    if not first then return result end

    for _, s in ipairs(first.data or {}) do
        local pc = tonumber(s.playing) or 0
        local id = s.id
        if id and id ~= JOB_ID and not Blacklist[id] and pc == 1 then
            result[id] = {
                id = id,
                ping = tonumber(s.ping) or 999,
                fps = tonumber(s.fps) or 60,
                playing = pc,
                max = tonumber(s.maxPlayers) or 12,
            }
        end
    end

    local rootCursor = first.nextPageCursor
    if not rootCursor or rootCursor == "" or rootCursor == "null" then
        return result
    end

    local branchCursors = { rootCursor }
    for i = 1, CONFIG.ParallelBranches do
        local cur = branchCursors[i]
        if cur then
            local data = requestPage(cur)
            if data then
                for _, s in ipairs(data.data or {}) do
                    local pc = tonumber(s.playing) or 0
                    local id = s.id
                    if id and id ~= JOB_ID and not Blacklist[id] and pc == 1 then
                        result[id] = {
                            id = id,
                            ping = tonumber(s.ping) or 999,
                            fps = tonumber(s.fps) or 60,
                            playing = pc,
                            max = tonumber(s.maxPlayers) or 12,
                        }
                    end
                end
                if data.nextPageCursor and data.nextPageCursor ~= "" and data.nextPageCursor ~= "null" then
                    branchCursors[i + 1] = data.nextPageCursor
                end
            end
        end
    end

    local pagesPerBranch = math.floor(CONFIG.MaxPages / math.max(1, CONFIG.ParallelBranches))
    local threads = {}

    for idx = 1, CONFIG.ParallelBranches do
        local startCursor = branchCursors[idx]
        if startCursor then
            table.insert(threads, task.spawn(function()
                local cursor = startCursor
                local pages = 0
                while pages < pagesPerBranch do
                    local data = requestPage(cursor)
                    if not data then break end
                    for _, s in ipairs(data.data or {}) do
                        local pc = tonumber(s.playing) or 0
                        local id = s.id
                        if id and id ~= JOB_ID and not Blacklist[id] and pc == 1 then
                            while lockRef[1] do task.wait() end
                            lockRef[1] = true
                            result[id] = {
                                id = id,
                                ping = tonumber(s.ping) or 999,
                                fps = tonumber(s.fps) or 60,
                                playing = pc,
                                max = tonumber(s.maxPlayers) or 12,
                            }
                            lockRef[1] = false
                        end
                    end
                    cursor = data.nextPageCursor
                    if not cursor or cursor == "" or cursor == "null" then break end
                    pages = pages + 1
                end
            end))
        end
    end

    for _ = 1, #threads do task.wait(0.05) end
    task.wait(0.1)

    return result
end

local function calculateScore(server, stabilityBonus)
    local fpsScore = math.max(0, 60 - server.fps) * 3
    local pingScore = math.min(server.ping, 500) / 3
    local stabilityScore = stabilityBonus * 150
    return 1000 + fpsScore + pingScore + stabilityScore
end

local function fastTeleport(jobId)
    local success = false
    pcall(function()
        local opts = Instance.new("TeleportOptions")
        opts.ServerInstanceId = jobId
        TeleportService:TeleportAsync(PLACE_ID, {LocalPlayer}, opts)
        success = true
    end)
    if success then return true end
    pcall(function()
        TeleportService:TeleportToPlaceInstance(PLACE_ID, jobId, LocalPlayer)
        success = true
    end)
    return success
end

local function findOneServer()
    local pass1 = scanParallel()
    local count1 = 0
    for _ in pairs(pass1) do count1 = count1 + 1 end
    if count1 == 0 then return nil end

    task.wait(CONFIG.PassDelay)

    local pass2 = scanParallel()

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

    task.wait(CONFIG.ConfirmDelay)

    local finalPool = {}
    for _, s in ipairs(stable) do
        s.score = calculateScore(s, s.stability)
        table.insert(finalPool, s)
    end

    table.sort(finalPool, function(a, b)
        if a.stability ~= b.stability then
            return a.stability > b.stability
        end
        return a.score > b.score
    end)

    return finalPool
end

local function mainLoop()
    task.wait(1)

    while IsRunning and ScreenGui.Parent do
        local count = updatePlayerCount()

        if count <= CONFIG.MaxTotalAllowed then
            setStatus("Server " .. count .. " người · ổn", Color3.fromRGB(120, 255, 160), "ON")

            for _ = 1, CONFIG.AutoHopDelay do
                if not ScreenGui.Parent then return end
                task.wait(1)
                count = #Players:GetPlayers()
                updatePlayerCount()
                if count > CONFIG.MaxTotalAllowed then break end
            end

            if count <= CONFIG.MaxTotalAllowed then
                continue
            end
        end

        setStatus("Chờ xác nhận người mới...", Color3.fromRGB(255, 200, 100), "...")

        for i = CONFIG.AutoHopDelay, 1, -1 do
            if not ScreenGui.Parent then return end
            local cnt = #Players:GetPlayers()
            if cnt <= CONFIG.MaxTotalAllowed then
                setStatus("Người rời · hủy hop", Color3.fromRGB(120, 255, 160), "ON")
                break
            end
            setStatus("Hop sau " .. i .. "s · " .. cnt .. " người", Color3.fromRGB(255, 180, 100), "...")
            task.wait(1)
        end

        if #Players:GetPlayers() <= CONFIG.MaxTotalAllowed then
            continue
        end

        local found = false
        local scanAttempt = 0

        while not found and ScreenGui.Parent and IsRunning do
            scanAttempt = scanAttempt + 1
            setStatus("Đang quét lần " .. scanAttempt, Color3.fromRGB(255, 200, 100), "...")

            if not http then
                setStatus("Lỗi HTTP", Color3.fromRGB(255, 100, 100), "OFF")
                task.wait(2)
                continue
            end

            local pool = findOneServer()

            if pool and #pool > 0 then
                local target = pool[1]
                setStatus("Tìm được " .. #pool .. " server · vào", Color3.fromRGB(120, 255, 160), "HOP")

                Blacklist[target.id] = true
                task.wait(CONFIG.PreTeleportDelay)

                local ok = fastTeleport(target.id)

                if ok then
                    found = true
                    IsHopping = true
                    task.wait(CONFIG.TeleportWait)
                    IsHopping = false
                    break
                else
                    setStatus("Teleport fail · quét lại", Color3.fromRGB(255, 100, 100), "FAIL")
                    task.wait(1)
                end
            else
                Blacklist = {}
                setStatus("Không có · quét lại sau " .. CONFIG.LoopWait .. "s", Color3.fromRGB(255, 150, 100), "...")
                task.wait(CONFIG.LoopWait)
            end
        end
    end
end

local dragging, dragStart, startPos
Header.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = Main.Position
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if not dragging then return end
    if input.UserInputType ~= Enum.UserInputType.MouseMovement
        and input.UserInputType ~= Enum.UserInputType.Touch then return end
    local d = input.Position - dragStart
    Main.Position = UDim2.new(
        startPos.X.Scale, startPos.X.Offset + d.X,
        startPos.Y.Scale, startPos.Y.Offset + d.Y
    )
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        dragging = false
    end
end)

updatePlayerCount()
setStatus("Đang chạy", Color3.fromRGB(120, 255, 160), "ON")

task.spawn(mainLoop)

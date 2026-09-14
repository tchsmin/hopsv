local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local CoreGui = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

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

local Blacklist = {}
local IsScanning = false
local LoaderActive = false
local loaderCoroutine = nil
local PulseActive = false
local pulseConn = nil

if CoreGui:FindFirstChild("HopUI") then CoreGui.HopUI:Destroy() end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "HopUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.IgnoreGuiInset = true
ScreenGui.DisplayOrder = 999999
ScreenGui.Parent = CoreGui

local Container = Instance.new("Frame")
Container.Size = UDim2.new(0, 220, 0, 125)
Container.Position = UDim2.new(0, 20, 0, 80)
Container.BackgroundTransparency = 1
Container.Parent = ScreenGui

local Glow = Instance.new("ImageLabel")
Glow.Size = UDim2.new(0, 120, 0, 120)
Glow.Position = UDim2.new(0.5, -60, 0, -20)
Glow.BackgroundTransparency = 1
Glow.Image = "rbxassetid://5028857084"
Glow.ImageColor3 = Color3.fromRGB(60, 180, 120)
Glow.ImageTransparency = 0.85
Glow.ZIndex = 0
Glow.Parent = Container

local Btn = Instance.new("TextButton")
Btn.Size = UDim2.new(0, 80, 0, 80)
Btn.Position = UDim2.new(0.5, -40, 0, 0)
Btn.BackgroundColor3 = Color3.fromRGB(60, 180, 120)
Btn.Text = "HOP"
Btn.TextColor3 = Color3.fromRGB(255, 255, 255)
Btn.Font = Enum.Font.GothamBold
Btn.TextSize = 18
Btn.AutoButtonColor = false
Btn.Active = true
Btn.ZIndex = 2
Btn.Parent = Container

local BtnCorner = Instance.new("UICorner")
BtnCorner.CornerRadius = UDim.new(1, 0)
BtnCorner.Parent = Btn

local BtnGradient = Instance.new("UIGradient")
BtnGradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(80, 220, 150)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(40, 140, 100))
})
BtnGradient.Rotation = 90
BtnGradient.Parent = Btn

local BtnStroke = Instance.new("UIStroke")
BtnStroke.Color = Color3.fromRGB(255, 255, 255)
BtnStroke.Thickness = 1.5
BtnStroke.Transparency = 0.5
BtnStroke.Parent = Btn

local StatusBar = Instance.new("Frame")
StatusBar.Size = UDim2.new(1, 0, 0, 30)
StatusBar.Position = UDim2.new(0, 0, 0, 88)
StatusBar.BackgroundColor3 = Color3.fromRGB(18, 20, 28)
StatusBar.BackgroundTransparency = 0.05
StatusBar.BorderSizePixel = 0
StatusBar.ZIndex = 2
StatusBar.Parent = Container

local StatusBarCorner = Instance.new("UICorner")
StatusBarCorner.CornerRadius = UDim.new(0, 8)
StatusBarCorner.Parent = StatusBar

local StatusStroke = Instance.new("UIStroke")
StatusStroke.Color = Color3.fromRGB(80, 120, 180)
StatusStroke.Thickness = 1
StatusStroke.Transparency = 0.6
StatusStroke.Parent = StatusBar

local StatusIcon = Instance.new("TextLabel")
StatusIcon.Size = UDim2.new(0, 28, 1, 0)
StatusIcon.Position = UDim2.new(0, 4, 0, 0)
StatusIcon.BackgroundTransparency = 1
StatusIcon.Text = "●"
StatusIcon.TextColor3 = Color3.fromRGB(120, 200, 255)
StatusIcon.Font = Enum.Font.GothamBold
StatusIcon.TextSize = 14
StatusIcon.ZIndex = 3
StatusIcon.Parent = StatusBar

local StatusLabel = Instance.new("TextLabel")
StatusLabel.Size = UDim2.new(1, -70, 1, 0)
StatusLabel.Position = UDim2.new(0, 32, 0, 0)
StatusLabel.BackgroundTransparency = 1
StatusLabel.Text = "Sẵn sàng"
StatusLabel.TextColor3 = Color3.fromRGB(200, 220, 255)
StatusLabel.Font = Enum.Font.GothamBold
StatusLabel.TextSize = 11
StatusLabel.TextXAlignment = Enum.TextXAlignment.Left
StatusLabel.TextTruncate = Enum.TextTruncate.AtEnd
StatusLabel.ZIndex = 3
StatusLabel.Parent = StatusBar

local ProgressBar = Instance.new("Frame")
ProgressBar.Size = UDim2.new(1, -8, 0, 3)
ProgressBar.Position = UDim2.new(0, 4, 1, -5)
ProgressBar.BackgroundColor3 = Color3.fromRGB(40, 50, 70)
ProgressBar.BorderSizePixel = 0
ProgressBar.ZIndex = 4
ProgressBar.Parent = StatusBar

local ProgressCorner = Instance.new("UICorner")
ProgressCorner.CornerRadius = UDim.new(1, 0)
ProgressCorner.Parent = ProgressBar

local ProgressFill = Instance.new("Frame")
ProgressFill.Size = UDim2.new(0, 0, 1, 0)
ProgressFill.BackgroundColor3 = Color3.fromRGB(120, 200, 255)
ProgressFill.BorderSizePixel = 0
ProgressFill.ZIndex = 5
ProgressFill.Parent = ProgressBar

local ProgressFillCorner = Instance.new("UICorner")
ProgressFillCorner.CornerRadius = UDim.new(1, 0)
ProgressFillCorner.Parent = ProgressFill

local ProgressGradient = Instance.new("UIGradient")
ProgressGradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(100, 180, 255)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(180, 120, 255))
})
ProgressGradient.Parent = ProgressFill

local SPINNER_DOTS = {"", ".", "..", "...", "...."}
local SPINNER_BRAILLE = {"⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"}
local SPINNER_ARROW = {"←", "↖", "↑", "↗", "→", "↘", "↓", "↙"}
local SPINNER_BLOCK = {"▁", "▂", "▃", "▄", "▅", "▆", "▇", "█", "▇", "▆", "▅", "▄", "▃", "▂"}

local currentSpinner = SPINNER_DOTS
local currentBaseText = ""

local function startPulse(color)
    PulseActive = false
    if pulseConn then
        pulseConn:Disconnect()
        pulseConn = nil
    end
    Glow.ImageColor3 = color or Color3.fromRGB(60, 180, 120)
    PulseActive = true

    local startTime = tick()
    pulseConn = RunService.Heartbeat:Connect(function()
        if not PulseActive then return end
        if not Glow or not Glow.Parent then return end
        local t = (tick() - startTime) * 2
        local wave = (math.sin(t) + 1) / 2
        Glow.ImageTransparency = 0.7 - (wave * 0.35)
        local size = 120 + wave * 25
        Glow.Size = UDim2.new(0, size, 0, size)
        Glow.Position = UDim2.new(0.5, -size / 2, 0, -20 - (size - 120) / 2)
    end)
end

local function stopPulse()
    PulseActive = false
    if pulseConn then
        pulseConn:Disconnect()
        pulseConn = nil
    end
    TweenService:Create(Glow, TweenInfo.new(0.3), {
        ImageTransparency = 0.85,
        Size = UDim2.new(0, 120, 0, 120),
        Position = UDim2.new(0.5, -60, 0, -20)
    }):Play()
end

local function pressDown()
    TweenService:Create(Btn, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Size = UDim2.new(0, 72, 0, 72),
        Position = UDim2.new(0.5, -36, 0, 4)
    }):Play()
end

local function pressUp()
    TweenService:Create(Btn, TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Size = UDim2.new(0, 80, 0, 80),
        Position = UDim2.new(0.5, -40, 0, 0)
    }):Play()
end

local function startLoading(text, spinnerType, icon, color)
    LoaderActive = false
    task.wait()
    LoaderActive = true

    currentBaseText = text

    if spinnerType == "braille" then
        currentSpinner = SPINNER_BRAILLE
    elseif spinnerType == "arrow" then
        currentSpinner = SPINNER_ARROW
    elseif spinnerType == "block" then
        currentSpinner = SPINNER_BLOCK
    else
        currentSpinner = SPINNER_DOTS
    end

    local c = color or Color3.fromRGB(120, 200, 255)
    StatusLabel.TextColor3 = c
    StatusIcon.Text = icon or "●"
    StatusIcon.TextColor3 = c
    ProgressFill.BackgroundColor3 = c

    loaderCoroutine = task.spawn(function()
        local i = 1
        local startTime = tick()
        while LoaderActive do
            local elapsed = tick() - startTime

            if currentSpinner == SPINNER_DOTS then
                local dotCount = math.floor(elapsed * 3) % 5
                StatusLabel.Text = currentBaseText .. string.rep(".", dotCount)
            else
                StatusLabel.Text = currentBaseText .. " " .. currentSpinner[i]
                i = i + 1
                if i > #currentSpinner then i = 1 end
            end

            if currentSpinner == SPINNER_BLOCK then
                ProgressFill.Size = UDim2.new(
                    (math.sin(elapsed * 3) + 1) / 2 * 0.9 + 0.1, 0, 1, 0
                )
            else
                local progress = (elapsed % 2) / 2
                ProgressFill.Size = UDim2.new(progress, 0, 1, 0)
            end

            task.wait(0.05)
        end
    end)
end

local function stopLoading(finalText, color)
    LoaderActive = false
    loaderCoroutine = nil
    if finalText then
        StatusLabel.Text = finalText
        StatusLabel.TextColor3 = color or Color3.fromRGB(200, 220, 255)
        StatusIcon.TextColor3 = color or Color3.fromRGB(120, 200, 255)
        ProgressFill.BackgroundColor3 = color or Color3.fromRGB(120, 200, 255)
    end
    TweenService:Create(ProgressFill, TweenInfo.new(0.3), {
        Size = UDim2.new(0, 0, 1, 0)
    }):Play()
end

local dragActive = false
local dragStartInput = nil
local dragStartPos = nil
local dragMoved = false

Btn.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        dragActive = true
        dragMoved = false
        dragStartInput = input.Position
        dragStartPos = Container.Position
        pressDown()
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if not dragActive then return end
    if input.UserInputType ~= Enum.UserInputType.MouseMovement
        and input.UserInputType ~= Enum.UserInputType.Touch then return end
    local delta = input.Position - dragStartInput
    if math.abs(delta.X) > 8 or math.abs(delta.Y) > 8 then
        dragMoved = true
    end
    Container.Position = UDim2.new(
        dragStartPos.X.Scale,
        dragStartPos.X.Offset + delta.X,
        dragStartPos.Y.Scale,
        dragStartPos.Y.Offset + delta.Y
    )
end)

UserInputService.InputEnded:Connect(function(input)
    if not dragActive then return end
    if input.UserInputType ~= Enum.UserInputType.MouseButton1
        and input.UserInputType ~= Enum.UserInputType.Touch then return end
    dragActive = false
    pressUp()
    if not dragMoved then
        task.spawn(function()
            local ok = pcall(doHop)
            if not ok then
                stopLoading("Lỗi!", Color3.fromRGB(255, 100, 100))
                stopPulse()
                IsScanning = false
            end
        end)
    end
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
    if not ok or not res or not res.Body then return nil end
    local ok2, data = pcall(function()
        return HttpService:JSONDecode(res.Body)
    end)
    if not ok2 or not data then return nil end
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
            local pc = s.playing or 0
            local id = s.id
            local ping = s.ping or 999
            local fps = s.fps or 60

            if pc >= 1 and pc <= maxPlayers then
                if id ~= JOB_ID and not Blacklist[id] then
                    result[id] = {
                        id = id,
                        ping = ping,
                        fps = fps,
                        playing = pc,
                        max = s.maxPlayers or 12
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
        playerScore = 120
    elseif server.playing == 2 then
        playerScore = 30
    end

    local fpsScore = 0
    if server.fps <= 15 then
        fpsScore = 60
    elseif server.fps <= 25 then
        fpsScore = 50
    elseif server.fps <= 35 then
        fpsScore = 30
    elseif server.fps <= 45 then
        fpsScore = 10
    else
        fpsScore = 0
    end

    local pingScore = 0
    if server.ping >= 400 and server.ping <= 550 then
        pingScore = 50
    elseif server.ping >= 300 and server.ping < 400 then
        pingScore = 40
    elseif server.ping >= 550 and server.ping <= 650 then
        pingScore = 25
    elseif server.ping >= 200 and server.ping < 300 then
        pingScore = 20
    elseif server.ping > 650 then
        pingScore = 0
    else
        pingScore = 10
    end

    local stabilityScore = stabilityBonus * 50

    return playerScore + fpsScore + pingScore + stabilityScore
end

function doHop()
    if IsScanning then return end
    IsScanning = true

    startPulse(Color3.fromRGB(255, 200, 100))
    startLoading("Đang dò server", "dots", "◉", Color3.fromRGB(255, 200, 100))
    task.wait(0.1)

    if not http then
        IsScanning = false
        stopLoading("Lỗi kết nối!", Color3.fromRGB(255, 100, 100))
        stopPulse()
        return
    end

    local pass1 = scanPass(2, 12)

    local count1 = 0
    for _ in pairs(pass1) do count1 = count1 + 1 end

    if count1 == 0 then
        IsScanning = false
        stopLoading("Không có server!", Color3.fromRGB(255, 100, 100))
        stopPulse()
        return
    end

    startLoading("Đang phân tích", "braille", "◆", Color3.fromRGB(100, 180, 255))
    startPulse(Color3.fromRGB(100, 180, 255))
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

    startLoading("Đang xác nhận", "arrow", "★", Color3.fromRGB(180, 130, 255))
    startPulse(Color3.fromRGB(180, 130, 255))
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
        IsScanning = false
        stopLoading("Không có server!", Color3.fromRGB(255, 100, 100))
        stopPulse()
        return
    end

    local topN = math.min(3, #pickFrom)
    local target = pickFrom[math.random(1, topN)]

    startLoading("Đang vào server", "block", "▶", Color3.fromRGB(60, 220, 150))
    startPulse(Color3.fromRGB(60, 220, 150))

    Blacklist[target.id] = true
    IsScanning = false

    local ok = pcall(function()
        TeleportService:TeleportToPlaceInstance(PLACE_ID, target.id, LocalPlayer)
    end)

    if not ok then
        stopLoading("Lỗi! Bấm lại.", Color3.fromRGB(255, 100, 100))
        stopPulse()
    end
end

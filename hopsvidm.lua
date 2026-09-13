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
Container.Size = UDim2.new(0, 200, 0, 115)
Container.Position = UDim2.new(0, 20, 0.5, -57)
Container.BackgroundTransparency = 1
Container.Parent = ScreenGui

local Glow = Instance.new("ImageLabel")
Glow.Size = UDim2.new(0, 130, 0, 130)
Glow.Position = UDim2.new(0.5, -65, 0, -25)
Glow.BackgroundTransparency = 1
Glow.Image = "rbxassetid://5028857084"
Glow.ImageColor3 = Color3.fromRGB(60, 180, 120)
Glow.ImageTransparency = 0.5
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

local StatusLabel = Instance.new("TextLabel")
StatusLabel.Size = UDim2.new(1, 0, 0, 22)
StatusLabel.Position = UDim2.new(0, 0, 0, 88)
StatusLabel.BackgroundColor3 = Color3.fromRGB(20, 22, 30)
StatusLabel.BackgroundTransparency = 0.1
StatusLabel.BorderSizePixel = 0
StatusLabel.Text = "Sẵn sàng"
StatusLabel.TextColor3 = Color3.fromRGB(200, 220, 255)
StatusLabel.Font = Enum.Font.GothamBold
StatusLabel.TextSize = 11
StatusLabel.ZIndex = 2
StatusLabel.Parent = Container

local StatusCorner = Instance.new("UICorner")
StatusCorner.CornerRadius = UDim.new(0, 6)
StatusCorner.Parent = StatusLabel

local SPINNER = {"|", "/", "-", "\\"}

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
        Glow.Size = UDim2.new(0, 120 + wave * 25, 0, 120 + wave * 25)
        Glow.Position = UDim2.new(0.5, -(120 + wave * 25) / 2, 0, -22 - (wave * 25) / 2)
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

local function startLoading(text)
    LoaderActive = false
    task.wait()
    LoaderActive = true
    StatusLabel.TextColor3 = Color3.fromRGB(255, 220, 120)
    loaderCoroutine = task.spawn(function()
        local i = 1
        while LoaderActive do
            StatusLabel.Text = text .. " " .. SPINNER[i]
            i = i + 1
            if i > #SPINNER then i = 1 end
            task.wait(0.13)
        end
    end)
end

local function stopLoading(finalText, color)
    LoaderActive = false
    loaderCoroutine = nil
    if finalText then
        StatusLabel.Text = finalText
        StatusLabel.TextColor3 = color or Color3.fromRGB(200, 220, 255)
    end
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
            if pc >= 1 and pc <= maxPlayers then
                if id ~= JOB_ID and not Blacklist[id] then
                    result[id] = {
                        id = id,
                        ping = s.ping or 999,
                        fps = s.fps or 60,
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

function doHop()
    if IsScanning then return end
    IsScanning = true

    startPulse(Color3.fromRGB(255, 200, 100))
    startLoading("Đang dò server")
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

    startLoading("Đang phân tích")
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

    startLoading("Đang xác nhận")
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

    local topCount = math.min(3, #pickFrom)
    if topCount == 0 then
        IsScanning = false
        stopLoading("Không có server!", Color3.fromRGB(255, 100, 100))
        stopPulse()
        return
    end

    local target = pickFrom[math.random(1, topCount)]

    startLoading("Đang vào server")
    startPulse(Color3.fromRGB(60, 220, 150))
    task.wait(0.5)

    IsScanning = false
    Blacklist[target.id] = true

    local ok = pcall(function()
        TeleportService:TeleportToPlaceInstance(PLACE_ID, target.id, LocalPlayer)
    end)

    if not ok then
        stopLoading("Lỗi! Bấm lại.", Color3.fromRGB(255, 100, 100))
        stopPulse()
    end
end

Glow.ImageTransparency = 0.85
Glow.Size = UDim2.new(0, 120, 0, 120)
Glow.Position = UDim2.new(0.5, -60, 0, -20)

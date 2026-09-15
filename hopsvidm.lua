local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local CoreGui = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

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
local LoaderText = "Đang dò server"
local SpinIndex = 1
local SpinTimer = 0
local SpinConn = nil
local IsMinimized = false
local CurrentTarget = nil

if CoreGui:FindFirstChild("HopUI") then CoreGui.HopUI:Destroy() end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "HopUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.IgnoreGuiInset = true
ScreenGui.DisplayOrder = 999999
ScreenGui.Parent = CoreGui

local Main = Instance.new("Frame")
Main.Size = UDim2.new(0, 240, 0, 180)
Main.Position = UDim2.new(0, 20, 0.5, -90)
Main.BackgroundColor3 = Color3.fromRGB(22, 24, 34)
Main.BorderSizePixel = 0
Main.Active = true
Main.Parent = ScreenGui

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 12)
MainCorner.Parent = Main

local MainStroke = Instance.new("UIStroke")
MainStroke.Color = Color3.fromRGB(60, 200, 130)
MainStroke.Thickness = 1.5
MainStroke.Transparency = 0.3
MainStroke.Parent = Main

local Title = Instance.new("Frame")
Title.Size = UDim2.new(1, 0, 0, 36)
Title.BackgroundColor3 = Color3.fromRGB(32, 36, 50)
Title.BorderSizePixel = 0
Title.Parent = Main

local TitleCorner = Instance.new("UICorner")
TitleCorner.CornerRadius = UDim.new(0, 12)
TitleCorner.Parent = Title

local TitleFix = Instance.new("Frame")
TitleFix.Size = UDim2.new(1, 0, 0, 12)
TitleFix.Position = UDim2.new(0, 0, 1, -12)
TitleFix.BackgroundColor3 = Color3.fromRGB(32, 36, 50)
TitleFix.BorderSizePixel = 0
TitleFix.Parent = Title

local TitleText = Instance.new("TextLabel")
TitleText.Size = UDim2.new(1, -50, 1, 0)
TitleText.Position = UDim2.new(0, 12, 0, 0)
TitleText.BackgroundTransparency = 1
TitleText.Text = "HOPSVIDM"
TitleText.TextColor3 = Color3.fromRGB(255, 255, 255)
TitleText.Font = Enum.Font.GothamBold
TitleText.TextSize = 13
TitleText.TextXAlignment = Enum.TextXAlignment.Left
TitleText.Parent = Title

local MinBtn = Instance.new("TextButton")
MinBtn.Size = UDim2.new(0, 24, 0, 24)
MinBtn.Position = UDim2.new(1, -30, 0, 6)
MinBtn.BackgroundColor3 = Color3.fromRGB(90, 100, 140)
MinBtn.Text = "−"
MinBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
MinBtn.Font = Enum.Font.GothamBold
MinBtn.TextSize = 15
MinBtn.Parent = Title

local MinCorner = Instance.new("UICorner")
MinCorner.CornerRadius = UDim.new(0, 6)
MinCorner.Parent = MinBtn

local Content = Instance.new("Frame")
Content.Size = UDim2.new(1, 0, 1, -36)
Content.Position = UDim2.new(0, 0, 0, 36)
Content.BackgroundTransparency = 1
Content.Parent = Main

local Btn = Instance.new("TextButton")
Btn.Size = UDim2.new(0, 60, 0, 60)
Btn.Position = UDim2.new(0.5, -30, 0, 8)
Btn.BackgroundColor3 = Color3.fromRGB(60, 180, 120)
Btn.Text = "HOP"
Btn.TextColor3 = Color3.fromRGB(255, 255, 255)
Btn.Font = Enum.Font.GothamBold
Btn.TextSize = 14
Btn.AutoButtonColor = false
Btn.Active = true
Btn.Parent = Content

local BtnCorner = Instance.new("UICorner")
BtnCorner.CornerRadius = UDim.new(1, 0)
BtnCorner.Parent = Btn

local BtnStroke = Instance.new("UIStroke")
BtnStroke.Color = Color3.fromRGB(255, 255, 255)
BtnStroke.Thickness = 1.5
BtnStroke.Transparency = 0.5
BtnStroke.Parent = Btn

local SubTitle = Instance.new("TextLabel")
SubTitle.Size = UDim2.new(1, -24, 0, 12)
SubTitle.Position = UDim2.new(0, 12, 0, 74)
SubTitle.BackgroundTransparency = 1
SubTitle.Text = "SERVER ÍT NGƯỜI"
SubTitle.TextColor3 = Color3.fromRGB(120, 220, 180)
SubTitle.Font = Enum.Font.GothamBold
SubTitle.TextSize = 9
SubTitle.Parent = Content

local StatusLabel = Instance.new("TextLabel")
StatusLabel.Size = UDim2.new(1, -24, 0, 26)
StatusLabel.Position = UDim2.new(0, 12, 0, 90)
StatusLabel.BackgroundColor3 = Color3.fromRGB(38, 42, 58)
StatusLabel.BorderSizePixel = 0
StatusLabel.Text = "Sẵn sàng"
StatusLabel.TextColor3 = Color3.fromRGB(200, 220, 255)
StatusLabel.Font = Enum.Font.GothamBold
StatusLabel.TextSize = 10
StatusLabel.TextWrapped = true
StatusLabel.Parent = Content

local StatusCorner = Instance.new("UICorner")
StatusCorner.CornerRadius = UDim.new(0, 6)
StatusCorner.Parent = StatusLabel

local SPINNER = {"|", "/", "-", "\\"}

local function startSpin()
    LoaderActive = true
    SpinTimer = 0
    if SpinConn then SpinConn:Disconnect() end
    SpinConn = RunService.Heartbeat:Connect(function(dt)
        SpinTimer = SpinTimer + dt
        if SpinTimer >= 0.18 then
            SpinTimer = 0
            SpinIndex = SpinIndex + 1
            if SpinIndex > #SPINNER then SpinIndex = 1 end
            StatusLabel.Text = LoaderText .. " " .. SPINNER[SpinIndex]
        end
    end)
end

local function changeLoader(text, color)
    LoaderText = text
    if color then
        StatusLabel.TextColor3 = color
    end
end

local function stopSpin(finalText, color)
    LoaderActive = false
    if SpinConn then
        SpinConn:Disconnect()
        SpinConn = nil
    end
    if finalText then
        StatusLabel.Text = finalText
        StatusLabel.TextColor3 = color or Color3.fromRGB(200, 220, 255)
    end
end

local drag = {
    active = false,
    target = nil,
    startInput = nil,
    startPos = nil,
    moved = false,
    isBtn = false
}

local function beginDrag(input, target, isBtn)
    drag.active = true
    drag.target = target
    drag.startInput = input.Position
    drag.startPos = target.Position
    drag.moved = false
    drag.isBtn = isBtn
    if isBtn then
        Btn.Size = UDim2.new(0, 54, 0, 54)
        Btn.Position = UDim2.new(0.5, -27, 0, 11)
    end
end

local function moveDrag(input)
    if not drag.active then return end
    local delta = input.Position - drag.startInput
    if not drag.moved then
        if math.abs(delta.X) > 8 or math.abs(delta.Y) > 8 then
            drag.moved = true
        else
            return
        end
    end
    drag.target.Position = UDim2.new(
        drag.startPos.X.Scale,
        drag.startPos.X.Offset + delta.X,
        drag.startPos.Y.Scale,
        drag.startPos.Y.Offset + delta.Y
    )
end

local function endDrag()
    if not drag.active then return end
    local wasBtn = drag.isBtn
    local wasMoved = drag.moved
    drag.active = false
    drag.target = nil

    if wasBtn then
        Btn.Size = UDim2.new(0, 60, 0, 60)
        Btn.Position = UDim2.new(0.5, -30, 0, 8)
        if not wasMoved then
            task.spawn(function()
                local ok = pcall(doHop)
                if not ok then
                    stopSpin("Lỗi!", Color3.fromRGB(255, 100, 100))
                    IsScanning = false
                    Btn.BackgroundColor3 = Color3.fromRGB(60, 180, 120)
                    Btn.Text = "HOP"
                end
            end)
        end
    end
end

Title.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        beginDrag(input, Main, false)
    end
end)

Btn.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        beginDrag(input, Main, true)
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if not drag.active then return end
    if input.UserInputType ~= Enum.UserInputType.MouseMovement
        and input.UserInputType ~= Enum.UserInputType.Touch then return end
    moveDrag(input)
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType ~= Enum.UserInputType.MouseButton1
        and input.UserInputType ~= Enum.UserInputType.Touch then return end
    endDrag()
end)

local function toggleMinimize()
    IsMinimized = not IsMinimized
    if IsMinimized then
        Content.Visible = false
        Main.ClipsDescendants = true
        Main.Size = UDim2.new(0, 240, 0, 36)
        MinBtn.Text = "+"
    else
        Main.ClipsDescendants = false
        Main.Size = UDim2.new(0, 240, 0, 180)
        MinBtn.Text = "−"
        Content.Visible = true
    end
end

MinBtn.MouseButton1Click:Connect(toggleMinimize)

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
    local totalSeen = 0

    while pages < maxPages do
        local data = requestPage(cursor)
        if not data or not data.data then break end
        local cnt = 0
        for _, s in ipairs(data.data) do
            cnt = cnt + 1
            totalSeen = totalSeen + 1
            local pc = s.playing or 0
            local id = s.id
            if pc >= 1 and pc <= maxPlayers then
                if id ~= JOB_ID and not Blacklist[id] then
                    result[id] = {
                        id = id,
                        ping = s.ping or 999,
                        fps = s.fps or 60,
                        playing = pc
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

    return result, totalSeen
end

local function calculateScore(server, stabilityBonus)
    local playerScore = 0
    if server.playing == 1 then
        playerScore = 100
    elseif server.playing == 2 then
        playerScore = 40
    elseif server.playing == 3 then
        playerScore = 10
    elseif server.playing <= 5 then
        playerScore = 3
    end
    local fpsScore = math.max(0, 60 - server.fps) * 1.5
    local pingScore = math.min(server.ping, 500) / 5
    local stabilityScore = stabilityBonus * 60
    return playerScore + fpsScore + pingScore + stabilityScore
end

local teleportSuccess = false

TeleportService.TeleportInitFailed:Connect(function(player, teleportResult, errorMessage, placeId, teleportOptions)
    if player == LocalPlayer then
        warn("[Hop] Teleport thất bại: " .. tostring(errorMessage))
        if CurrentTarget then
            Blacklist[CurrentTarget] = true
            CurrentTarget = nil
        end
        if not teleportSuccess then
            stopSpin("Lỗi! Bấm lại.", Color3.fromRGB(255, 100, 100))
            Btn.BackgroundColor3 = Color3.fromRGB(60, 180, 120)
            Btn.Text = "HOP"
            IsScanning = false
        end
    end
end)

function doHop()
    if IsScanning then return end
    IsScanning = true

    if IsMinimized then toggleMinimize() end

    Btn.BackgroundColor3 = Color3.fromRGB(200, 160, 60)
    Btn.Text = "..."
    changeLoader("Đang dò server", Color3.fromRGB(255, 200, 100))
    startSpin()
    task.wait(0.1)

    if not http then
        IsScanning = false
        stopSpin("Lỗi kết nối!", Color3.fromRGB(255, 100, 100))
        Btn.BackgroundColor3 = Color3.fromRGB(60, 180, 120)
        Btn.Text = "HOP"
        return
    end

    local pass1, totalSeen1 = scanPass(2, 12)
    local count1 = 0
    for _ in pairs(pass1) do count1 = count1 + 1 end

    if count1 == 0 then
        changeLoader("Mở rộng tìm kiếm", Color3.fromRGB(255, 180, 100))
        task.wait(0.5)
        pass1, totalSeen1 = scanPass(6, 12)
        count1 = 0
        for _ in pairs(pass1) do count1 = count1 + 1 end
    end

    if count1 == 0 then
        changeLoader("Mở rộng tối đa", Color3.fromRGB(255, 150, 100))
        task.wait(0.5)
        pass1, totalSeen1 = scanPass(12, 12)
        count1 = 0
        for _ in pairs(pass1) do count1 = count1 + 1 end
    end

    if count1 == 0 then
        IsScanning = false
        if totalSeen1 == 0 then
            stopSpin("API lỗi! Thử lại.", Color3.fromRGB(255, 100, 100))
        else
            stopSpin("Không có server!", Color3.fromRGB(255, 100, 100))
        end
        Btn.BackgroundColor3 = Color3.fromRGB(60, 180, 120)
        Btn.Text = "HOP"
        return
    end

    changeLoader("Đang lọc", Color3.fromRGB(100, 180, 255))
    task.wait(2.5)

    local pass2 = scanPass(12, 12)

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
        for _, s in pairs(pass1) do
            s.stability = 1
            table.insert(stable, s)
        end
    end

    changeLoader("Đang tránh server lỗi", Color3.fromRGB(200, 140, 255))
    task.wait(1.2)

    changeLoader("Đang tạo cổng vào", Color3.fromRGB(140, 220, 255))
    task.wait(0.8)

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
    if #pickFrom == 0 then pickFrom = finalPool end

    local topCount = math.min(3, #pickFrom)
    if topCount == 0 then
        IsScanning = false
        stopSpin("Không có server!", Color3.fromRGB(255, 100, 100))
        Btn.BackgroundColor3 = Color3.fromRGB(60, 180, 120)
        Btn.Text = "HOP"
        return
    end

    local target = pickFrom[math.random(1, topCount)]
    CurrentTarget = target.id

    changeLoader("Đang vào", Color3.fromRGB(120, 255, 160))
    Btn.Text = ">>"
    task.wait(0.4)

    IsScanning = false
    teleportSuccess = false

    local ok = pcall(function()
        TeleportService:TeleportToPlaceInstance(PLACE_ID, target.id, LocalPlayer)
    end)

    if not ok then
        Blacklist[target.id] = true
        CurrentTarget = nil
        stopSpin("Lỗi! Bấm lại.", Color3.fromRGB(255, 100, 100))
        Btn.BackgroundColor3 = Color3.fromRGB(60, 180, 120)
        Btn.Text = "HOP"
        return
    end

    Blacklist[target.id] = true
    teleportSuccess = true
end

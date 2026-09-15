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
local LoaderText = "Đang check qua server hiện có"
local SpinIndex = 1
local SpinTimer = 0
local SpinConn = nil
local IsMinimized = false
local CurrentTarget = nil
local teleportSuccess = false

if CoreGui:FindFirstChild("HopUI") then CoreGui.HopUI:Destroy() end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "HopUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.IgnoreGuiInset = true
ScreenGui.DisplayOrder = 999999
ScreenGui.Parent = CoreGui

local Main = Instance.new("Frame")
Main.Size = UDim2.new(0, 260, 0, 180)
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
        if SpinTimer >= 0.15 then
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
        Main.Size = UDim2.new(0, 260, 0, 36)
        MinBtn.Text = "+"
    else
        Main.ClipsDescendants = false
        Main.Size = UDim2.new(0, 260, 0, 180)
        MinBtn.Text = "−"
        Content.Visible = true
    end
end

MinBtn.MouseButton1Click:Connect(toggleMinimize)

local function requestPageSafe(cursor)
    if not http then return nil, "NO_HTTP" end
    local url = string.format(
        "https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100&cursor=%s",
        PLACE_ID, cursor or ""
    )
    for attempt = 1, 3 do
        local ok, res = pcall(function()
            return http({
                Url = url,
                Method = "GET",
                Headers = { ["Accept"] = "application/json" }
            })
        end)
        if ok and res and res.Body and #res.Body > 0 then
            local ok2, data = pcall(function()
                return HttpService:JSONDecode(res.Body)
            end)
            if ok2 and data then
                return data, nil
            end
        end
        task.wait(0.1)
    end
    return nil, "REQUEST_FAIL"
end

local function fullScan(maxPages)
    local result = {}
    local cursor = ""
    local pages = 0
    local totalSeen = 0
    local errCode = nil

    while pages < maxPages do
        local data, err = requestPageSafe(cursor)
        if not data then
            if pages == 0 then errCode = err end
            break
        end

        if not data.data or type(data.data) ~= "table" then
            if pages == 0 then errCode = "NO_DATA" end
            break
        end

        local cnt = 0
        for _, s in ipairs(data.data) do
            cnt = cnt + 1
            totalSeen = totalSeen + 1
            local pc = s.playing or 0
            if pc >= 1 and pc <= 12 then
                local id = s.id
                if id and id ~= JOB_ID and not Blacklist[id] then
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
    end

    return result, totalSeen, errCode
end

local function scanTriplePass()
    local pass1, seen1, err1 = fullScan(12)

    if err1 and seen1 == 0 then
        return nil, "API_FAIL"
    end
    if seen1 == 0 then
        return nil, "NO_SERVER"
    end

    local count1 = 0
    for _ in pairs(pass1) do count1 = count1 + 1 end
    if count1 == 0 then
        return nil, "NO_ONE_PLAYER"
    end

    task.wait(5.5)
    local pass2 = fullScan(12)

    task.wait(5.5)
    local pass3 = fullScan(12)

    local stable = {}
    for id, s3 in pairs(pass3) do
        local s1 = pass1[id]
        local s2 = pass2[id]
        if s1 and s2 then
            s3.stability = 3
            if s1.playing == 1 and s2.playing == 1 and s3.playing == 1 then
                s3.afkLock = true
                s3.pingBefore = s1.ping
                s3.fpsBefore = s1.fps
            end
            table.insert(stable, s3)
        elseif s1 then
            s3.stability = 2
            table.insert(stable, s3)
        end
    end

    if #stable == 0 then
        for id, s in pairs(pass1) do
            s.stability = 1
            table.insert(stable, s)
        end
    end

    return stable, nil
end

local function getAfkScore(server)
    local score = 0

    if server.playing == 1 then
        score = score + 1000
    elseif server.playing == 2 then
        score = score + 200
    else
        score = score - 1000
    end

    if server.afkLock then
        score = score + 800
    end

    if server.stability == 3 then
        score = score + 600
    elseif server.stability == 2 then
        score = score + 200
    end

    if server.fps <= 10 then
        score = score + 500
    elseif server.fps <= 20 then
        score = score + 400
    elseif server.fps <= 30 then
        score = score + 300
    elseif server.fps <= 45 then
        score = score + 150
    end

    if server.ping >= 300 then
        score = score + 500
    elseif server.ping >= 200 then
        score = score + 400
    elseif server.ping >= 150 then
        score = score + 300
    elseif server.ping >= 100 then
        score = score + 150
    end

    if server.afkLock and server.playing == 1 then
        score = score + 500
    end

    return score
end

TeleportService.TeleportInitFailed:Connect(function(player, teleportResult, errorMessage, placeId, teleportOptions)
    if player == LocalPlayer then
        warn("[Hop] Teleport thất bại: " .. tostring(errorMessage))
        if CurrentTarget then
            Blacklist[CurrentTarget] = true
            CurrentTarget = nil
        end
        if not teleportSuccess then
            stopSpin("Server lỗi! Bấm lại.", Color3.fromRGB(255, 100, 100))
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
    changeLoader("Đang check qua server hiện có", Color3.fromRGB(255, 200, 100))
    startSpin()
    task.wait(0.05)

    if not http then
        IsScanning = false
        stopSpin("Executor không HTTP!", Color3.fromRGB(255, 100, 100))
        Btn.BackgroundColor3 = Color3.fromRGB(60, 180, 120)
        Btn.Text = "HOP"
        return
    end

    local pass1, seen1, err1 = fullScan(12)

    if err1 and seen1 == 0 then
        IsScanning = false
        stopSpin("API lỗi! Thử lại.", Color3.fromRGB(255, 100, 100))
        Btn.BackgroundColor3 = Color3.fromRGB(60, 180, 120)
        Btn.Text = "HOP"
        return
    end

    if seen1 == 0 then
        IsScanning = false
        stopSpin("Game hết server!", Color3.fromRGB(255, 100, 100))
        Btn.BackgroundColor3 = Color3.fromRGB(60, 180, 120)
        Btn.Text = "HOP"
        return
    end

    local count1 = 0
    for _ in pairs(pass1) do count1 = count1 + 1 end

    if count1 == 0 then
        IsScanning = false
        stopSpin("Không có server 1 người!", Color3.fromRGB(255, 150, 100))
        Btn.BackgroundColor3 = Color3.fromRGB(60, 180, 120)
        Btn.Text = "HOP"
        return
    end

    changeLoader("Đang lọc server", Color3.fromRGB(100, 180, 255))
    task.wait(5.5)

    local pass2 = fullScan(12)

    changeLoader("Đang lọc server", Color3.fromRGB(140, 200, 255))
    task.wait(5.5)

    local pass3 = fullScan(12)

    local stable = {}
    for id, s3 in pairs(pass3) do
        local s1 = pass1[id]
        local s2 = pass2[id]
        if s1 and s2 then
            s3.stability = 3
            if s1.playing == 1 and s2.playing == 1 and s3.playing == 1 then
                s3.afkLock = true
                s3.pingBefore = s1.ping
                s3.fpsBefore = s1.fps
            end
            table.insert(stable, s3)
        elseif s1 then
            s3.stability = 2
            table.insert(stable, s3)
        end
    end

    if #stable == 0 then
        for _, s in pairs(pass1) do
            s.stability = 1
            table.insert(stable, s)
        end
    end

    if #stable == 0 then
        IsScanning = false
        stopSpin("Không có server!", Color3.fromRGB(255, 100, 100))
        Btn.BackgroundColor3 = Color3.fromRGB(60, 180, 120)
        Btn.Text = "HOP"
        return
    end

    changeLoader("Đã xác định server ít người", Color3.fromRGB(200, 140, 255))
    task.wait(1.2)

    for _, s in ipairs(stable) do
        s.score = getAfkScore(s)
    end

    table.sort(stable, function(a, b)
        return a.score > b.score
    end)

    local onePlayer = {}
    for _, s in ipairs(stable) do
        if s.playing == 1 and s.stability == 3 then
            table.insert(onePlayer, s)
        end
    end

    if #onePlayer == 0 then
        for _, s in ipairs(stable) do
            if s.playing == 1 then
                table.insert(onePlayer, s)
            end
        end
    end

    local pool = onePlayer
    if #pool == 0 then
        pool = stable
    end

    if #pool == 0 then
        IsScanning = false
        stopSpin("Không có server!", Color3.fromRGB(255, 100, 100))
        Btn.BackgroundColor3 = Color3.fromRGB(60, 180, 120)
        Btn.Text = "HOP"
        return
    end

    local target = pool[1]
    CurrentTarget = target.id

    changeLoader("Đang tạo cổng kết nối", Color3.fromRGB(140, 220, 255))
    task.wait(1.5)

    changeLoader("Đang vào", Color3.fromRGB(120, 255, 160))
    Btn.Text = ">>"
    task.wait(0.5)

    IsScanning = false
    teleportSuccess = false
    Blacklist[target.id] = true

    local ok = pcall(function()
        TeleportService:TeleportToPlaceInstance(PLACE_ID, target.id, LocalPlayer)
    end)

    if not ok then
        CurrentTarget = nil
        stopSpin("Lỗi! Bấm lại.", Color3.fromRGB(255, 100, 100))
        Btn.BackgroundColor3 = Color3.fromRGB(60, 180, 120)
        Btn.Text = "HOP"
        return
    end

    teleportSuccess = true
end
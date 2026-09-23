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

local CONFIG = {
    PageDelay = 0,
    PassDelay = 0.5,
    ConfirmDelay = 0.3,
    PreTeleportDelay = 0.1,
    MaxPages = 25,
    ParallelBranches = 5,
}

local Blacklist = {}
local IsScanning = false
local IsRunning = true

if CoreGui:FindFirstChild("PhantomUI") then CoreGui.PhantomUI:Destroy() end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "PhantomUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.IgnoreGuiInset = true
ScreenGui.DisplayOrder = 999999
ScreenGui.Parent = CoreGui

local Main = Instance.new("Frame")
Main.Size = UDim2.new(0, 220, 0, 155)
Main.Position = UDim2.new(0, 20, 0.5, -77)
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
Header.Size = UDim2.new(1, 0, 0, 44)
Header.BackgroundTransparency = 1
Header.Parent = Main

local AvatarCircle = Instance.new("Frame")
AvatarCircle.Size = UDim2.new(0, 30, 0, 30)
AvatarCircle.Position = UDim2.new(0, 12, 0, 7)
AvatarCircle.BackgroundColor3 = Color3.fromRGB(30, 24, 60)
AvatarCircle.BorderSizePixel = 0
AvatarCircle.Parent = Header

local AvCorner = Instance.new("UICorner")
AvCorner.CornerRadius = UDim.new(1, 0)
AvCorner.Parent = AvatarCircle

local AvGradient = Instance.new("UIGradient")
AvGradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(120, 80, 255)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(60, 180, 255))
})
AvGradient.Rotation = 45
AvGradient.Parent = AvatarCircle

local AvatarIcon = Instance.new("ImageLabel")
AvatarIcon.Size = UDim2.new(1, -8, 1, -8)
AvatarIcon.Position = UDim2.new(0, 4, 0, 4)
AvatarIcon.BackgroundTransparency = 1
AvatarIcon.Image = "rbxassetid://6026568198"
AvatarIcon.ImageColor3 = Color3.fromRGB(255, 255, 255)
AvatarIcon.Parent = AvatarCircle

local TitleText = Instance.new("TextLabel")
TitleText.Size = UDim2.new(1, -60, 0, 16)
TitleText.Position = UDim2.new(0, 50, 0, 10)
TitleText.BackgroundTransparency = 1
TitleText.Text = "PHANTOM"
TitleText.TextColor3 = Color3.fromRGB(240, 240, 255)
TitleText.Font = Enum.Font.GothamBold
TitleText.TextSize = 13
TitleText.TextXAlignment = Enum.TextXAlignment.Left
TitleText.Parent = Header

local SubText = Instance.new("TextLabel")
SubText.Size = UDim2.new(1, -60, 0, 12)
SubText.Position = UDim2.new(0, 50, 0, 26)
SubText.BackgroundTransparency = 1
SubText.Text = "solo server hunter"
SubText.TextColor3 = Color3.fromRGB(130, 130, 170)
SubText.Font = Enum.Font.Gotham
SubText.TextSize = 9
SubText.TextXAlignment = Enum.TextXAlignment.Left
SubText.Parent = Header

local Divider = Instance.new("Frame")
Divider.Size = UDim2.new(1, -24, 0, 1)
Divider.Position = UDim2.new(0, 12, 0, 48)
Divider.BackgroundColor3 = Color3.fromRGB(35, 40, 55)
Divider.BorderSizePixel = 0
Divider.Parent = Main

local PlayerRow = Instance.new("Frame")
PlayerRow.Size = UDim2.new(1, -24, 0, 30)
PlayerRow.Position = UDim2.new(0, 12, 0, 56)
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
StatusRow.Position = UDim2.new(0, 12, 0, 90)
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
        DotPulse.BackgroundTransparency = 0.6
        task.wait(1)
        DotPulse:TweenSizeAndPosition(UDim2.new(3, 0, 3, 0), UDim2.new(-1, 0, -1, 0), "Out", "Sine", 0.8)
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

local HopBtn = Instance.new("TextButton")
HopBtn.Size = UDim2.new(1, -24, 0, 26)
HopBtn.Position = UDim2.new(0, 12, 0, 124)
HopBtn.BackgroundColor3 = Color3.fromRGB(80, 60, 180)
HopBtn.Text = "⚡  HOP 1 NGƯỜI"
HopBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
HopBtn.Font = Enum.Font.GothamBold
HopBtn.TextSize = 11
HopBtn.AutoButtonColor = false
HopBtn.Parent = Main

local HBtnCorner = Instance.new("UICorner")
HBtnCorner.CornerRadius = UDim.new(0, 7)
HBtnCorner.Parent = HopBtn

local HBtnGradient = Instance.new("UIGradient")
HBtnGradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(100, 70, 220)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(60, 130, 255))
})
HBtnGradient.Rotation = 0
HBtnGradient.Parent = HopBtn

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
    if count == 1 then
        PlayerValue.TextColor3 = Color3.fromRGB(120, 255, 160)
    elseif count == 2 then
        PlayerValue.TextColor3 = Color3.fromRGB(255, 220, 120)
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

local function collectFromData(data, targetPlaying, result, lockRef)
    if not data or not data.data then return end
    for _, s in ipairs(data.data) do
        local pc = s.playing or 0
        local id = s.id
        if id and id ~= JOB_ID and not Blacklist[id] and pc == targetPlaying then
            while lockRef[1] do task.wait() end
            lockRef[1] = true
            result[id] = {
                id = id,
                ping = s.ping or 999,
                fps = s.fps or 60,
                playing = pc,
                max = s.maxPlayers or 12,
            }
            lockRef[1] = false
        end
    end
end

local function parallelScan(targetPlaying)
    local result = {}
    local lockRef = {false}

    local first = requestPage("")
    if not first then return result end
    collectFromData(first, targetPlaying, result, lockRef)

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
                collectFromData(data, targetPlaying, result, lockRef)
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
                    collectFromData(data, targetPlaying, result, lockRef)
                    cursor = data.nextPageCursor
                    if not cursor or cursor == "" or cursor == "null" then break end
                    pages = pages + 1
                    if CONFIG.PageDelay > 0 then task.wait(CONFIG.PageDelay) end
                end
            end))
        end
    end

    for _ = 1, #threads do task.wait(0.05) end
    task.wait(0.15)

    return result
end

local function calculateScore(server, stabilityBonus)
    local playerScore = 1000
    local fpsScore = math.max(0, 60 - server.fps) * 2
    local pingScore = math.min(server.ping, 500) / 4
    local stabilityScore = stabilityBonus * 100
    return playerScore + fpsScore + pingScore + stabilityScore
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

local function scanForOnePlayer()
    local pass1 = parallelScan(1)
    local count1 = 0
    for _ in pairs(pass1) do count1 = count1 + 1 end
    if count1 == 0 then return nil end

    task.wait(CONFIG.PassDelay)

    local pass2 = parallelScan(1)

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

    local topCount = math.min(3, #finalPool)
    if topCount == 0 then return nil end

    return finalPool[math.random(1, topCount)]
end

local function performHop()
    if IsScanning then return end
    IsScanning = true

    setStatus("Đang quét server...", Color3.fromRGB(255, 200, 100), "...")
    HopBtn.Text = "ĐANG QUÉT..."

    if not http then
        IsScanning = false
        setStatus("Lỗi HTTP", Color3.fromRGB(255, 100, 100), "OFF")
        HopBtn.Text = "⚡  HOP 1 NGƯỜI"
        return
    end

    local target = scanForOnePlayer()

    if not target then
        IsScanning = false
        setStatus("Không có server", Color3.fromRGB(255, 120, 120), "FAIL")
        HopBtn.Text = "⚡  HOP 1 NGƯỜI"
        task.wait(3)
        setStatus("Đang chạy", Color3.fromRGB(120, 255, 160), "ON")
        return
    end

    setStatus("Đang vào server...", Color3.fromRGB(120, 255, 160), "HOP")
    HopBtn.Text = "ĐANG VÀO..."

    task.wait(CONFIG.PreTeleportDelay)

    IsScanning = false
    Blacklist[target.id] = true

    fastTeleport(target.id)

    setStatus("Đã hop", Color3.fromRGB(120, 255, 160), "ON")
    HopBtn.Text = "⚡  HOP 1 NGƯỜI"
end

HopBtn.MouseButton1Click:Connect(function()
    task.spawn(performHop)
end)

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

HopBtn.MouseEnter:Connect(function()
    HopBtn.BackgroundColor3 = Color3.fromRGB(110, 80, 220)
end)
HopBtn.MouseLeave:Connect(function()
    HopBtn.BackgroundColor3 = Color3.fromRGB(80, 60, 180)
end)

coroutine.wrap(function()
    while ScreenGui.Parent do
        task.wait(0.5)
        if not IsRunning then
            setStatus("Đang off", Color3.fromRGB(140, 140, 160), "OFF")
            StatusDot.BackgroundColor3 = Color3.fromRGB(140, 140, 160)
            DotPulse.BackgroundColor3 = Color3.fromRGB(140, 140, 160)
        end
    end
end)()

updatePlayerCount()
setStatus("Đang chạy", Color3.fromRGB(120, 255, 160), "ON")

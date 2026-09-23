local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local CoreGui = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Stats = game:GetService("Stats")
local VirtualUser = game:GetService("VirtualUser")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer
local PLACE_ID = game.PlaceId
local JOB_ID = game.JobId

local STEAL_IDS = {
    [13772394625] = true,
    [109983668079237] = true,
    [115484077057506] = true,
    [135609351274353] = true,
}
local IS_STEAL = STEAL_IDS[PLACE_ID] == true

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
    StealPassDelay = 1.2,
    StealPasses = 4,
    StealConfirmDelay = 0.5,
    ConfirmDelay = 0.3,
    PreTeleportDelay = 0.1,
    MaxPages = 25,
    ParallelBranches = 5,
    MaxTotalAllowed = 2,
    MinHopDelay = 3,
    MaxHopDelay = 7,
    MaxBlacklist = 100,
}

local State = {
    TargetPlayers = 1,
    AutoEnabled = true,
    IsScanning = false,
    IsHopping = false,
    Blacklist = {},
    History = {},
    LastPlayerCount = 0,
    LastHopTime = 0,
    KickCount = 0,
}

if CoreGui:FindFirstChild("PhantomUI") then CoreGui.PhantomUI:Destroy() end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "PhantomUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.IgnoreGuiInset = true
ScreenGui.DisplayOrder = 999999
ScreenGui.Parent = CoreGui

local Main = Instance.new("Frame")
Main.Size = UDim2.new(0, 220, 0, 148)
Main.Position = UDim2.new(0, 20, 0.5, -74)
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
TitleText.Size = UDim2.new(1, -70, 1, 0)
TitleText.Position = UDim2.new(0, 12, 0, 0)
TitleText.BackgroundTransparency = 1
TitleText.Text = "HOP SERVER"
TitleText.TextColor3 = Color3.fromRGB(240, 240, 255)
TitleText.Font = Enum.Font.GothamBold
TitleText.TextSize = 12
TitleText.TextXAlignment = Enum.TextXAlignment.Left
TitleText.Parent = Header

local HistoryBtn = Instance.new("TextButton")
HistoryBtn.Size = UDim2.new(0, 20, 0, 20)
HistoryBtn.Position = UDim2.new(1, -48, 0, 6)
HistoryBtn.BackgroundColor3 = Color3.fromRGB(30, 34, 48)
HistoryBtn.Text = "📋"
HistoryBtn.TextColor3 = Color3.fromRGB(180, 190, 220)
HistoryBtn.Font = Enum.Font.GothamBold
HistoryBtn.TextSize = 11
HistoryBtn.AutoButtonColor = false
HistoryBtn.Parent = Header

local HBCorner = Instance.new("UICorner")
HBCorner.CornerRadius = UDim.new(0, 6)
HBCorner.Parent = HistoryBtn

local SettingsBtn = Instance.new("TextButton")
SettingsBtn.Size = UDim2.new(0, 20, 0, 20)
SettingsBtn.Position = UDim2.new(1, -24, 0, 6)
SettingsBtn.BackgroundColor3 = Color3.fromRGB(30, 34, 48)
SettingsBtn.Text = "⚙"
SettingsBtn.TextColor3 = Color3.fromRGB(180, 190, 220)
SettingsBtn.Font = Enum.Font.GothamBold
SettingsBtn.TextSize = 11
SettingsBtn.AutoButtonColor = false
SettingsBtn.Parent = Header

local SBCorner = Instance.new("UICorner")
SBCorner.CornerRadius = UDim.new(0, 6)
SBCorner.Parent = SettingsBtn

local Divider = Instance.new("Frame")
Divider.Size = UDim2.new(1, -24, 0, 1)
Divider.Position = UDim2.new(0, 12, 0, 34)
Divider.BackgroundColor3 = Color3.fromRGB(35, 40, 55)
Divider.BorderSizePixel = 0
Divider.Parent = Main

local function makeRow(yPos, icon, label, valueColor)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, -24, 0, 26)
    row.Position = UDim2.new(0, 12, 0, yPos)
    row.BackgroundColor3 = Color3.fromRGB(24, 27, 38)
    row.BorderSizePixel = 0
    row.Parent = Main

    local rc = Instance.new("UICorner")
    rc.CornerRadius = UDim.new(0, 7)
    rc.Parent = row

    local iconLbl = Instance.new("TextLabel")
    iconLbl.Size = UDim2.new(0, 28, 1, 0)
    iconLbl.Position = UDim2.new(0, 2, 0, 0)
    iconLbl.BackgroundTransparency = 1
    iconLbl.Text = icon
    iconLbl.TextColor3 = Color3.fromRGB(120, 180, 255)
    iconLbl.Font = Enum.Font.GothamBold
    iconLbl.TextSize = 13
    iconLbl.Parent = row

    local labelLbl = Instance.new("TextLabel")
    labelLbl.Size = UDim2.new(1, -100, 1, 0)
    labelLbl.Position = UDim2.new(0, 32, 0, 0)
    labelLbl.BackgroundTransparency = 1
    labelLbl.Text = label
    labelLbl.TextColor3 = Color3.fromRGB(160, 170, 200)
    labelLbl.Font = Enum.Font.Gotham
    labelLbl.TextSize = 10
    labelLbl.TextXAlignment = Enum.TextXAlignment.Left
    labelLbl.Parent = row

    local valueLbl = Instance.new("TextLabel")
    valueLbl.Size = UDim2.new(0, 60, 1, 0)
    valueLbl.Position = UDim2.new(1, -66, 0, 0)
    valueLbl.BackgroundTransparency = 1
    valueLbl.Text = "0"
    valueLbl.TextColor3 = valueColor or Color3.fromRGB(120, 255, 160)
    valueLbl.Font = Enum.Font.GothamBold
    valueLbl.TextSize = 12
    valueLbl.TextXAlignment = Enum.TextXAlignment.Right
    valueLbl.Parent = row

    return valueLbl
end

local PlayerValue = makeRow(40, "👥", "Số người", Color3.fromRGB(120, 255, 160))
local PingValue = makeRow(70, "📶", "Ping", Color3.fromRGB(120, 200, 255))

local StatusRow = Instance.new("Frame")
StatusRow.Size = UDim2.new(1, -24, 0, 26)
StatusRow.Position = UDim2.new(0, 12, 0, 100)
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

local SettingsPanel = Instance.new("Frame")
SettingsPanel.Size = UDim2.new(0, 200, 0, 100)
SettingsPanel.Position = UDim2.new(0, 240, 0, 0)
SettingsPanel.BackgroundColor3 = Color3.fromRGB(20, 22, 32)
SettingsPanel.BorderSizePixel = 0
SettingsPanel.Visible = false
SettingsPanel.ZIndex = 10
SettingsPanel.Parent = Main

local SpCorner = Instance.new("UICorner")
SpCorner.CornerRadius = UDim.new(0, 10)
SpCorner.Parent = SettingsPanel

local SpStroke = Instance.new("UIStroke")
SpStroke.Color = Color3.fromRGB(100, 70, 220)
SpStroke.Thickness = 1
SpStroke.Transparency = 0.4
SpStroke.Parent = SettingsPanel

local SpTitle = Instance.new("TextLabel")
SpTitle.Size = UDim2.new(1, -30, 0, 20)
SpTitle.Position = UDim2.new(0, 12, 0, 8)
SpTitle.BackgroundTransparency = 1
SpTitle.Text = "CÀI ĐẶT"
SpTitle.TextColor3 = Color3.fromRGB(200, 180, 255)
SpTitle.Font = Enum.Font.GothamBold
SpTitle.TextSize = 10
SpTitle.TextXAlignment = Enum.TextXAlignment.Left
SpTitle.Parent = SettingsPanel

local SpClose = Instance.new("TextButton")
SpClose.Size = UDim2.new(0, 18, 0, 18)
SpClose.Position = UDim2.new(1, -24, 0, 8)
SpClose.BackgroundColor3 = Color3.fromRGB(50, 40, 70)
SpClose.Text = "✕"
SpClose.TextColor3 = Color3.fromRGB(200, 180, 255)
SpClose.Font = Enum.Font.GothamBold
SpClose.TextSize = 10
SpClose.AutoButtonColor = false
SpClose.Parent = SettingsPanel

local SpClCorner = Instance.new("UICorner")
SpClCorner.CornerRadius = UDim.new(0, 4)
SpClCorner.Parent = SpClose

local SpLabel = Instance.new("TextLabel")
SpLabel.Size = UDim2.new(1, -24, 0, 16)
SpLabel.Position = UDim2.new(0, 12, 0, 32)
SpLabel.BackgroundTransparency = 1
SpLabel.Text = "Số người trong server:"
SpLabel.TextColor3 = Color3.fromRGB(160, 170, 200)
SpLabel.Font = Enum.Font.Gotham
SpLabel.TextSize = 9
SpLabel.TextXAlignment = Enum.TextXAlignment.Left
SpLabel.Parent = SettingsPanel

local SliderTrack = Instance.new("Frame")
SliderTrack.Size = UDim2.new(1, -40, 0, 3)
SliderTrack.Position = UDim2.new(0, 20, 0, 62)
SliderTrack.BackgroundColor3 = Color3.fromRGB(45, 40, 65)
SliderTrack.BorderSizePixel = 0
SliderTrack.Parent = SettingsPanel

local STCorner = Instance.new("UICorner")
STCorner.CornerRadius = UDim.new(1, 0)
STCorner.Parent = SliderTrack

local SliderFill = Instance.new("Frame")
SliderFill.Size = UDim2.new(0, 0, 1, 0)
SliderFill.BackgroundColor3 = Color3.fromRGB(120, 80, 255)
SliderFill.BorderSizePixel = 0
SliderFill.Parent = SliderTrack

local SFLCorner = Instance.new("UICorner")
SFLCorner.CornerRadius = UDim.new(1, 0)
SFLCorner.Parent = SliderFill

local SliderKnob = Instance.new("Frame")
SliderKnob.Size = UDim2.new(0, 14, 0, 14)
SliderKnob.Position = UDim2.new(0, -7, 0.5, -7)
SliderKnob.BackgroundColor3 = Color3.fromRGB(180, 140, 255)
SliderKnob.BorderSizePixel = 0
SliderKnob.Parent = SliderTrack

local SKCorner = Instance.new("UICorner")
SKCorner.CornerRadius = UDim.new(1, 0)
SKCorner.Parent = SliderKnob

local sliderValue = 1
local sliderPositions = {0, 0.5, 1.0}
local sliderLabels = {}

for i = 1, 3 do
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(0, 20, 0, 14)
    lbl.Position = UDim2.new(sliderPositions[i], -10, 0, 76)
    lbl.BackgroundTransparency = 1
    lbl.Text = tostring(i)
    lbl.TextColor3 = i == 1 and Color3.fromRGB(180, 140, 255) or Color3.fromRGB(120, 130, 160)
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 10
    lbl.Parent = SettingsPanel
    sliderLabels[i] = lbl
end

local SliderHit = Instance.new("TextButton")
SliderHit.Size = UDim2.new(1, -40, 0, 30)
SliderHit.Position = UDim2.new(0, 20, 0, 50)
SliderHit.BackgroundTransparency = 1
SliderHit.Text = ""
SliderHit.Parent = SettingsPanel

local function updateSlider(val)
    sliderValue = math.clamp(val, 1, 3)
    State.TargetPlayers = sliderValue

    local pos = sliderPositions[sliderValue]
    SliderKnob.Position = UDim2.new(pos, -7, 0.5, -7)
    SliderFill.Size = UDim2.new(pos, 0, 1, 0)

    for i = 1, 3 do
        sliderLabels[i].TextColor3 = (i == sliderValue)
            and Color3.fromRGB(180, 140, 255)
            or Color3.fromRGB(120, 130, 160)
    end

    CONFIG.MaxTotalAllowed = sliderValue + 1
    setStatus("Đang chạy · target " .. sliderValue, Color3.fromRGB(120, 255, 160), "ON")
end

SliderHit.MouseButton1Click:Connect(function()
    local mouseX = UserInputService:GetMouseLocation().X
    local trackAbsPos = SliderTrack.AbsolutePosition.X
    local trackAbsSize = SliderTrack.AbsoluteSize.X
    local ratio = math.clamp((mouseX - trackAbsPos) / trackAbsSize, 0, 1)

    local closest = 1
    local minDist = math.huge
    for i = 1, 3 do
        local d = math.abs(sliderPositions[i] - ratio)
        if d < minDist then
            minDist = d
            closest = i
        end
    end
    updateSlider(closest)
end)

SettingsBtn.MouseButton1Click:Connect(function()
    SettingsPanel.Visible = not SettingsPanel.Visible
end)

SpClose.MouseButton1Click:Connect(function()
    SettingsPanel.Visible = false
end)

local HistoryPanel = Instance.new("Frame")
HistoryPanel.Size = UDim2.new(0, 260, 0, 220)
HistoryPanel.Position = UDim2.new(-1, -270, 0, 0)
HistoryPanel.BackgroundColor3 = Color3.fromRGB(20, 22, 32)
HistoryPanel.BorderSizePixel = 0
HistoryPanel.Visible = false
HistoryPanel.ZIndex = 10
HistoryPanel.Parent = Main

local HpCorner = Instance.new("UICorner")
HpCorner.CornerRadius = UDim.new(0, 10)
HpCorner.Parent = HistoryPanel

local HpStroke = Instance.new("UIStroke")
HpStroke.Color = Color3.fromRGB(60, 140, 220)
HpStroke.Thickness = 1
HpStroke.Transparency = 0.4
HpStroke.Parent = HistoryPanel

local HpTitle = Instance.new("TextLabel")
HpTitle.Size = UDim2.new(1, -30, 0, 20)
HpTitle.Position = UDim2.new(0, 12, 0, 8)
HpTitle.BackgroundTransparency = 1
HpTitle.Text = "LỊCH SỬ HOP"
HpTitle.TextColor3 = Color3.fromRGB(160, 210, 255)
HpTitle.Font = Enum.Font.GothamBold
HpTitle.TextSize = 10
HpTitle.TextXAlignment = Enum.TextXAlignment.Left
HpTitle.Parent = HistoryPanel

local HpClose = Instance.new("TextButton")
HpClose.Size = UDim2.new(0, 18, 0, 18)
HpClose.Position = UDim2.new(1, -24, 0, 8)
HpClose.BackgroundColor3 = Color3.fromRGB(30, 40, 55)
HpClose.Text = "✕"
HpClose.TextColor3 = Color3.fromRGB(160, 210, 255)
HpClose.Font = Enum.Font.GothamBold
HpClose.TextSize = 10
HpClose.AutoButtonColor = false
HpClose.Parent = HistoryPanel

local HpClCorner = Instance.new("UICorner")
HpClCorner.CornerRadius = UDim.new(0, 4)
HpClCorner.Parent = HpClose

local HpScroll = Instance.new("ScrollingFrame")
HpScroll.Size = UDim2.new(1, -16, 1, -40)
HpScroll.Position = UDim2.new(0, 8, 0, 32)
HpScroll.BackgroundColor3 = Color3.fromRGB(14, 16, 22)
HpScroll.BorderSizePixel = 0
HpScroll.ScrollBarThickness = 3
HpScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
HpScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
HpScroll.Parent = HistoryPanel

local HpScrollCorner = Instance.new("UICorner")
HpScrollCorner.CornerRadius = UDim.new(0, 6)
HpScrollCorner.Parent = HpScroll

local HpList = Instance.new("UIListLayout")
HpList.Padding = UDim.new(0, 3)
HpList.SortOrder = Enum.SortOrder.LayoutOrder
HpList.Parent = HpScroll

local HpPad = Instance.new("UIPadding")
HpPad.PaddingTop = UDim.new(0, 4)
HpPad.PaddingLeft = UDim.new(0, 4)
HpPad.PaddingRight = UDim.new(0, 4)
HpPad.PaddingBottom = UDim.new(0, 4)
HpPad.Parent = HpScroll

local function renderHistory()
    for _, c in ipairs(HpScroll:GetChildren()) do
        if c:IsA("Frame") then c:Destroy() end
    end

    for i, h in ipairs(State.History) do
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, -8, 0, 26)
        row.BackgroundColor3 = h.success and Color3.fromRGB(26, 40, 32) or Color3.fromRGB(45, 26, 30)
        row.BorderSizePixel = 0
        row.LayoutOrder = i
        row.Parent = HpScroll

        local rc = Instance.new("UICorner")
        rc.CornerRadius = UDim.new(0, 5)
        rc.Parent = row

        local txt = Instance.new("TextLabel")
        txt.Size = UDim2.new(1, -8, 1, 0)
        txt.Position = UDim2.new(0, 4, 0, 0)
        txt.BackgroundTransparency = 1
        txt.Text = h.text
        txt.TextColor3 = h.success and Color3.fromRGB(180, 255, 200) or Color3.fromRGB(255, 180, 180)
        txt.Font = Enum.Font.Code
        txt.TextSize = 9
        txt.TextXAlignment = Enum.TextXAlignment.Left
        txt.TextYAlignment = Enum.TextYAlignment.Center
        txt.Parent = row
    end
end

HistoryBtn.MouseButton1Click:Connect(function()
    HistoryPanel.Visible = not HistoryPanel.Visible
    if HistoryPanel.Visible then renderHistory() end
end)

HpClose.MouseButton1Click:Connect(function()
    HistoryPanel.Visible = false
end)

local function addHistory(text, success)
    table.insert(State.History, 1, {text = text, success = success})
    while #State.History > 10 do table.remove(State.History) end
    if HistoryPanel.Visible then renderHistory() end
end

task.spawn(function()
    while ScreenGui.Parent do
        spinIndex = spinIndex + 1
        if spinIndex > #SPINNER then spinIndex = 1 end
        task.wait(0.12)
    end
end)

local function updatePlayerCount()
    local count = #Players:GetPlayers()
    PlayerValue.Text = tostring(count)
    if count <= CONFIG.MaxTotalAllowed then
        PlayerValue.TextColor3 = Color3.fromRGB(120, 255, 160)
    else
        PlayerValue.TextColor3 = Color3.fromRGB(255, 120, 120)
    end
    return count
end

local function updatePing()
    local ok, val = pcall(function()
        return Stats.Network.ServerStatsItem["Data Ping"]:GetValue()
    end)
    local ping = ok and math.floor(val) or 0
    PingValue.Text = tostring(ping)
    if ping < 80 then
        PingValue.TextColor3 = Color3.fromRGB(120, 255, 160)
    elseif ping < 150 then
        PingValue.TextColor3 = Color3.fromRGB(255, 220, 120)
    else
        PingValue.TextColor3 = Color3.fromRGB(255, 120, 120)
    end
end

Players.PlayerAdded:Connect(function() task.wait(0.2) updatePlayerCount() end)
Players.PlayerRemoving:Connect(function() task.wait(0.4) updatePlayerCount() end)

task.spawn(function()
    while ScreenGui.Parent do
        updatePing()
        task.wait(1)
    end
end)

task.spawn(function()
    while true do
        task.wait(900)
        pcall(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton1(Vector2.new())
        end)
    end
end)

local function maybeResetBlacklist()
    local count = 0
    for _ in pairs(State.Blacklist) do count = count + 1 end
    if count >= CONFIG.MaxBlacklist then
        State.Blacklist = {}
    end
end

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
        if id and id ~= JOB_ID and not State.Blacklist[id] and pc == targetPlaying then
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

local function computeMetrics(id, passes)
    local total = #passes
    local presence = 0
    local onePlayer = 0
    local filled = 0
    local fpsSum, pingSum = 0, 0
    local fpsCount, pingCount = 0, 0
    local minFps, maxFps = 999, 0
    local minPing, maxPing = 9999, 0
    local currentStreak = 0
    local maxConsecutiveOne = 0
    local neverChanged = true
    local firstPc = nil

    for _, pass in ipairs(passes) do
        local s = pass[id]
        if s then
            presence = presence + 1
            local pc = s.playing or 0

            if pc == 1 then
                onePlayer = onePlayer + 1
                currentStreak = currentStreak + 1
                if currentStreak > maxConsecutiveOne then
                    maxConsecutiveOne = currentStreak
                end
            else
                currentStreak = 0
            end

            if pc > 1 then
                filled = filled + 1
                neverChanged = false
            end

            if firstPc == nil then
                firstPc = pc
            elseif pc ~= firstPc then
                neverChanged = false
            end

            fpsSum = fpsSum + (s.fps or 60)
            pingSum = pingSum + (s.ping or 0)
            fpsCount = fpsCount + 1
            pingCount = pingCount + 1

            if s.fps < minFps then minFps = s.fps end
            if s.fps > maxFps then maxFps = s.fps end
            if s.ping < minPing then minPing = s.ping end
            if s.ping > maxPing then maxPing = s.ping end
        else
            currentStreak = 0
        end
    end

    local avgFps = fpsCount > 0 and (fpsSum / fpsCount) or 60
    local avgPing = pingCount > 0 and (pingSum / pingCount) or 0

    return {
        presenceRate = presence / total,
        onePlayerRate = onePlayer / total,
        filledRate = filled / total,
        neverChanged = neverChanged,
        maxConsecutiveOne = maxConsecutiveOne,
        avgFps = avgFps,
        avgPing = avgPing,
        fpsStability = math.max(0, 1 - ((maxFps - minFps) / 30)),
        pingStability = math.max(0, 1 - ((maxPing - minPing) / 200)),
    }
end

local function computeAfkScore(m)
    if not m then return 0 end
    local score = 0
    if m.onePlayerRate >= 1.0 then score = score + 60
    elseif m.onePlayerRate >= 0.85 then score = score + 45
    elseif m.onePlayerRate >= 0.7 then score = score + 30
    elseif m.onePlayerRate >= 0.5 then score = score + 15 end

    if m.neverChanged then score = score + 25 end
    if m.maxConsecutiveOne >= 4 then score = score + 20
    elseif m.maxConsecutiveOne >= 3 then score = score + 15
    elseif m.maxConsecutiveOne >= 2 then score = score + 8 end

    score = score + (m.fpsStability * 15)
    score = score + (m.pingStability * 10)
    return math.min(100, score)
end

local function computeGhostScore(m)
    if not m then return 0 end
    local score = 0
    local avgPing = m.avgPing or 0
    local avgFps = m.avgFps or 60

    if avgPing >= 350 then score = score + 30
    elseif avgPing >= 280 then score = score + 25
    elseif avgPing >= 220 then score = score + 20
    elseif avgPing >= 160 then score = score + 12
    elseif avgPing >= 100 then score = score + 5 end

    if avgFps <= 8 then score = score + 30
    elseif avgFps <= 15 then score = score + 25
    elseif avgFps <= 22 then score = score + 20
    elseif avgFps <= 30 then score = score + 12
    elseif avgFps <= 40 then score = score + 5 end

    if m.neverChanged and m.onePlayerRate >= 0.8 then score = score + 20 end
    if m.maxConsecutiveOne >= 4 then score = score + 15 end

    if m.filledRate == 0 then score = score + 15
    elseif m.filledRate <= 0.2 then score = score + 8 end

    return math.min(100, score)
end

local function computeAgeScore(m)
    if not m then return 0 end
    local score = 0
    local avgPing = m.avgPing or 0
    local avgFps = m.avgFps or 60

    if avgFps <= 8 and avgPing >= 280 then score = score + 40
    elseif avgFps <= 12 and avgPing >= 240 then score = score + 35
    elseif avgFps <= 18 and avgPing >= 200 then score = score + 28
    elseif avgFps <= 25 and avgPing >= 160 then score = score + 20
    elseif avgFps <= 35 and avgPing >= 120 then score = score + 12
    else score = score + 3 end

    if m.presenceRate >= 1.0 then score = score + 25
    elseif m.presenceRate >= 0.8 then score = score + 18
    elseif m.presenceRate >= 0.6 then score = score + 10 end

    if m.fpsStability >= 0.95 then score = score + 15 end
    if m.pingStability >= 0.95 then score = score + 15 end
    return math.min(100, score)
end

local function stealScore(server, metrics)
    local afk = computeAfkScore(metrics)
    local ghost = computeGhostScore(metrics)
    local age = computeAgeScore(metrics)

    server.afkScore = afk
    server.ghostScore = ghost
    server.ageScore = age

    local total = 0

    if server.playing == 1 then
        total = total + 500000
    elseif server.playing == 2 then
        total = total + 5000
    end

    total = total + (afk * 300)
    total = total + (ghost * 400)
    total = total + (age * 250)
    total = total + ((metrics.onePlayerRate or 0) * 20000)
    total = total + ((metrics.presenceRate or 0) * 15000)

    if metrics.neverChanged then total = total + 30000 end
    if (metrics.maxConsecutiveOne or 0) >= 4 then total = total + 25000 end

    if (metrics.avgPing or 0) >= 300 then total = total + 20000
    elseif (metrics.avgPing or 0) >= 220 then total = total + 14000
    elseif (metrics.avgPing or 0) >= 150 then total = total + 8000 end

    if (metrics.avgFps or 60) <= 10 then total = total + 20000
    elseif (metrics.avgFps or 60) <= 18 then total = total + 14000
    elseif (metrics.avgFps or 60) <= 28 then total = total + 8000 end

    if metrics.filledRate == 0 then total = total + 25000 end

    return total
end

local function simpleScore(server, stabilityBonus)
    local playerScore = 0
    if server.playing == 1 then
        playerScore = 1000
    elseif server.playing == 2 then
        playerScore = 200
    end

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

local function scanForTarget(targetPlaying)
    if IS_STEAL then
        local passes = {}
        local passCount = CONFIG.StealPasses

        for p = 1, passCount do
            local pass = parallelScan(targetPlaying)
            table.insert(passes, pass)
            if p < passCount then task.wait(CONFIG.StealPassDelay) end
        end

        local firstPass = passes[1]
        local lastPass = passes[passCount]
        local firstCount = 0
        for _ in pairs(firstPass) do firstCount = firstCount + 1 end
        if firstCount == 0 then return nil end

        task.wait(CONFIG.StealConfirmDelay)

        local pool = {}
        for id, s in pairs(lastPass) do
            local m = computeMetrics(id, passes)
            if m and m.presenceRate >= 0.4 then
                s.metrics = m
                pool[id] = s
            end
        end

        if not next(pool) then
            for id, s in pairs(firstPass) do
                local m = computeMetrics(id, passes)
                if m then
                    s.metrics = m
                    pool[id] = s
                end
            end
        end

        local ranked = {}
        for _, s in pairs(pool) do
            if s.metrics then
                s.score = stealScore(s, s.metrics)
                table.insert(ranked, s)
            end
        end

        if #ranked == 0 then return nil end

        table.sort(ranked, function(a, b)
            if a.playing ~= b.playing then
                return a.playing < b.playing
            end
            return a.score > b.score
        end)

        local topCount = math.min(3, #ranked)
        return ranked[math.random(1, topCount)]
    else
        local pass1 = parallelScan(targetPlaying)
        local count1 = 0
        for _ in pairs(pass1) do count1 = count1 + 1 end
        if count1 == 0 then return nil end

        task.wait(CONFIG.PassDelay)

        local pass2 = parallelScan(targetPlaying)

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
            s.score = simpleScore(s, s.stability)
            table.insert(finalPool, s)
        end

        if #finalPool == 0 then return nil end

        table.sort(finalPool, function(a, b)
            return a.score > b.score
        end)

        local topCount = math.min(3, #finalPool)
        return finalPool[math.random(1, topCount)]
    end
end

local function performHop()
    if State.IsScanning or State.IsHopping then return end
    State.IsScanning = true

    setStatus(SPINNER[spinIndex] .. " Đang quét server...", Color3.fromRGB(255, 200, 100), "...")

    if not http then
        State.IsScanning = false
        setStatus("Lỗi HTTP", Color3.fromRGB(255, 100, 100), "OFF")
        return
    end

    maybeResetBlacklist()

    local startTarget = State.TargetPlayers
    local target = nil
    local usedTarget = nil

    if startTarget == 1 then
        setStatus("Tìm server 1 người...", Color3.fromRGB(255, 200, 100), "...")
        target = scanForTarget(1)

        if not target then
            task.wait(2)
            setStatus("Xác nhận lại 1 người...", Color3.fromRGB(255, 200, 100), "...")
            target = scanForTarget(1)
        end

        if target then
            usedTarget = 1
        else
            setStatus("Chuyển sang server 2 người...", Color3.fromRGB(255, 180, 120), "...")
            target = scanForTarget(2)
            if target then usedTarget = 2 end
        end
    elseif startTarget == 2 then
        setStatus("Tìm server 2 người...", Color3.fromRGB(255, 200, 100), "...")
        target = scanForTarget(2)
        if target then usedTarget = 2 end
    elseif startTarget == 3 then
        setStatus("Tìm server 3 người...", Color3.fromRGB(255, 200, 100), "...")
        target = scanForTarget(3)
        if target then usedTarget = 3 end
    end

    if not target and startTarget < 3 then
        local nextTarget = math.min(3, (usedTarget or startTarget) + 1)
        if nextTarget > (usedTarget or startTarget) then
            setStatus("Chuyển sang server " .. nextTarget .. " người...", Color3.fromRGB(255, 180, 120), "...")
            target = scanForTarget(nextTarget)
            if target then usedTarget = nextTarget end
        end
    end

    if not target then
        State.IsScanning = false
        setStatus("Không có server", Color3.fromRGB(255, 120, 120), "FAIL")
        addHistory("Không có server phù hợp", false)
        task.wait(5)
        setStatus("Đang chạy", Color3.fromRGB(120, 255, 160), "ON")
        return
    end

    local shortId = string.sub(target.id, 1, 8)
    local infoText = string.format("[%s] %d/%d · FPS%d · P%d",
        shortId, target.playing, target.max, target.fps, target.ping)

    setStatus("Đang vào server " .. (usedTarget or startTarget) .. " người...", Color3.fromRGB(120, 255, 160), "HOP")
    addHistory(infoText, true)

    task.wait(CONFIG.PreTeleportDelay)

    State.IsScanning = false
    State.IsHopping = true
    State.Blacklist[target.id] = true
    State.LastHopTime = tick()

    fastTeleport(target.id)

    task.wait(3)
    State.IsHopping = false
    setStatus("Đang chạy", Color3.fromRGB(120, 255, 160), "ON")
end

local MonitorConn = nil
local lastMonitorCount = 0

local function startMonitor()
    if MonitorConn then MonitorConn:Disconnect() end
    MonitorConn = RunService.Heartbeat:Connect(function()
        if not State.AutoEnabled then return end
        if State.IsHopping or State.IsScanning then return end

        local count = #Players:GetPlayers()
        if count == lastMonitorCount then return end
        lastMonitorCount = count

        if count > CONFIG.MaxTotalAllowed then
            setStatus("Server " .. count .. " người · đang đếm...", Color3.fromRGB(255, 200, 120), "...")

            task.spawn(function()
                local delay = math.random(CONFIG.MinHopDelay, CONFIG.MaxHopDelay)
                for i = delay, 1, -1 do
                    if not State.AutoEnabled then return end
                    local cnt = #Players:GetPlayers()
                    if cnt <= CONFIG.MaxTotalAllowed then
                        setStatus("Đã về " .. cnt .. " người", Color3.fromRGB(120, 255, 160), "ON")
                        return
                    end
                    setStatus("Hop sau " .. i .. "s · " .. cnt .. " người", Color3.fromRGB(255, 180, 100), "...")
                    task.wait(1)
                end

                if #Players:GetPlayers() > CONFIG.MaxTotalAllowed then
                    performHop()
                end
            end)
        else
            setStatus("Server " .. count .. " người · ổn", Color3.fromRGB(120, 255, 160), "ON")
        end
    end)
end

pcall(function()
    TeleportService.TeleportInitFailed:Connect(function(player, result, errMsg)
        if player == LocalPlayer then
            addHistory("Teleport fail: " .. tostring(errMsg):sub(1, 20), false)
            State.IsHopping = false
            task.wait(1)
            task.spawn(performHop)
        end
    end)
end)

pcall(function()
    LocalPlayer.OnTeleport:Connect(function(state)
        if state == Enum.TeleportState.Failed then
            State.KickCount = State.KickCount + 1
            addHistory("Teleport failed · retry", false)
            task.wait(2)
            task.spawn(performHop)
        end
    end)
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

updatePlayerCount()
updatePing()
updateSlider(1)
setStatus("Đang chạy", Color3.fromRGB(120, 255, 160), "ON")
startMonitor()

task.spawn(function()
    task.wait(2)
    local count = #Players:GetPlayers()
    if count > CONFIG.MaxTotalAllowed then
        performHop()
    end
end)

print("[HOP SERVER] Loaded | " .. (IS_STEAL and "STEAL MODE" or "UNIVERSAL MODE"))

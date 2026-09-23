local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local CoreGui = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local MarketplaceService = game:GetService("MarketplaceService")
local Stats = game:GetService("Stats")
local VirtualUser = game:GetService("VirtualUser")

local LocalPlayer = Players.LocalPlayer
local PLACE_ID = game.PlaceId
local JOB_ID = game.JobId

local function getHttp()
    if http_request then return http_request end
    if request then return request end
    if syn and syn.request then return syn.request end
    if fluxus and fluxus.request then return fluxus.request end
    if krnl and krnl.request then return krnl.request end
    return nil
end
local http = getHttp()

local function getUIParent()
    local ok, p = pcall(function() return game:GetService("CoreGui") end)
    if ok and p then return p end
    if gethui then
        local ok2, h = pcall(gethui)
        if ok2 and h then return h end
    end
    return LocalPlayer:WaitForChild("PlayerGui")
end
local UIParent = getUIParent()

local CONFIG = {
    PageDelay = 0,
    PassDelay = 0.5,
    ConfirmDelay = 0.3,
    PreTeleportDelay = 0.1,
    MaxPages = 25,
    ParallelBranches = 5,
    MaxTotalAllowed = 2,
    AutoHopDelayMin = 3,
    AutoHopDelayMax = 7,
    TeleportTimeout = 8,
    MaxHopRetries = 5,
    BlacklistMaxSize = 100,
    BlacklistResetTime = 1800,
    TargetOtherPlayers = 1,
    IsSteal = false,
}

local Blacklist = {}
local BlacklistTimestamp = os.time()
local IsScanning = false
local IsHopping = false
local AutoEnabled = true
local MonitorConn = nil
local LastPlayerCount = 0
local History = {}
local StartTimestamp = os.time()

pcall(function()
    local info = MarketplaceService:GetProductInfo(PLACE_ID)
    if info and info.Name then
        local n = info.Name:lower()
        if n:find("steal") or n:find("egg") then
            CONFIG.IsSteal = true
        end
    end
end)

pcall(function()
    if UIParent:FindFirstChild("PhantomUI") then UIParent.PhantomUI:Destroy() end
end)

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "PhantomUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.IgnoreGuiInset = true
ScreenGui.DisplayOrder = 999999
ScreenGui.Parent = UIParent

local Main = Instance.new("Frame")
Main.Size = UDim2.new(0, 210, 0, 148)
Main.Position = UDim2.new(0, 20, 0.5, -74)
Main.BackgroundColor3 = Color3.fromRGB(16, 18, 26)
Main.BorderSizePixel = 0
Main.Active = true
Main.ClipsDescendants = true
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
TitleText.Size = UDim2.new(1, -60, 1, 0)
TitleText.Position = UDim2.new(0, 12, 0, 0)
TitleText.BackgroundTransparency = 1
TitleText.Text = "HOP SERVER"
TitleText.TextColor3 = Color3.fromRGB(240, 240, 255)
TitleText.Font = Enum.Font.GothamBold
TitleText.TextSize = 12
TitleText.TextXAlignment = Enum.TextXAlignment.Left
TitleText.Parent = Header

local SetBtn = Instance.new("TextButton")
SetBtn.Size = UDim2.new(0, 20, 0, 20)
SetBtn.Position = UDim2.new(1, -26, 0, 6)
SetBtn.BackgroundColor3 = Color3.fromRGB(35, 40, 55)
SetBtn.Text = "⚙"
SetBtn.TextColor3 = Color3.fromRGB(200, 210, 240)
SetBtn.Font = Enum.Font.GothamBold
SetBtn.TextSize = 12
SetBtn.AutoButtonColor = false
SetBtn.Parent = Header

local SetCorner = Instance.new("UICorner")
SetCorner.CornerRadius = UDim.new(0, 6)
SetCorner.Parent = SetBtn

local Divider = Instance.new("Frame")
Divider.Size = UDim2.new(1, -24, 0, 1)
Divider.Position = UDim2.new(0, 12, 0, 34)
Divider.BackgroundColor3 = Color3.fromRGB(35, 40, 55)
Divider.BorderSizePixel = 0
Divider.Parent = Main

local PlayerRow = Instance.new("Frame")
PlayerRow.Size = UDim2.new(1, -24, 0, 26)
PlayerRow.Position = UDim2.new(0, 12, 0, 40)
PlayerRow.BackgroundColor3 = Color3.fromRGB(24, 27, 38)
PlayerRow.BorderSizePixel = 0
PlayerRow.Parent = Main

local PRCorner = Instance.new("UICorner")
PRCorner.CornerRadius = UDim.new(0, 6)
PRCorner.Parent = PlayerRow

local PlayerIcon = Instance.new("TextLabel")
PlayerIcon.Size = UDim2.new(0, 24, 1, 0)
PlayerIcon.Position = UDim2.new(0, 2, 0, 0)
PlayerIcon.BackgroundTransparency = 1
PlayerIcon.Text = "👥"
PlayerIcon.TextColor3 = Color3.fromRGB(120, 180, 255)
PlayerIcon.Font = Enum.Font.GothamBold
PlayerIcon.TextSize = 12
PlayerIcon.Parent = PlayerRow

local PlayerLabel = Instance.new("TextLabel")
PlayerLabel.Size = UDim2.new(1, -120, 1, 0)
PlayerLabel.Position = UDim2.new(0, 28, 0, 0)
PlayerLabel.BackgroundTransparency = 1
PlayerLabel.Text = "Số người"
PlayerLabel.TextColor3 = Color3.fromRGB(160, 170, 200)
PlayerLabel.Font = Enum.Font.Gotham
PlayerLabel.TextSize = 10
PlayerLabel.TextXAlignment = Enum.TextXAlignment.Left
PlayerLabel.Parent = PlayerRow

local PingLabel = Instance.new("TextLabel")
PingLabel.Size = UDim2.new(0, 50, 1, 0)
PingLabel.Position = UDim2.new(1, -110, 0, 0)
PingLabel.BackgroundTransparency = 1
PingLabel.Text = "0ms"
PingLabel.TextColor3 = Color3.fromRGB(180, 200, 240)
PingLabel.Font = Enum.Font.Code
PingLabel.TextSize = 10
PingLabel.TextXAlignment = Enum.TextXAlignment.Right
PingLabel.Parent = PlayerRow

local PlayerValue = Instance.new("TextLabel")
PlayerValue.Size = UDim2.new(0, 55, 1, 0)
PlayerValue.Position = UDim2.new(1, -60, 0, 0)
PlayerValue.BackgroundTransparency = 1
PlayerValue.Text = "1"
PlayerValue.TextColor3 = Color3.fromRGB(120, 255, 160)
PlayerValue.Font = Enum.Font.GothamBold
PlayerValue.TextSize = 12
PlayerValue.TextXAlignment = Enum.TextXAlignment.Right
PlayerValue.Parent = PlayerRow

local StatusRow = Instance.new("Frame")
StatusRow.Size = UDim2.new(1, -24, 0, 26)
StatusRow.Position = UDim2.new(0, 12, 0, 72)
StatusRow.BackgroundColor3 = Color3.fromRGB(24, 27, 38)
StatusRow.BorderSizePixel = 0
StatusRow.Parent = Main

local SRCorner = Instance.new("UICorner")
SRCorner.CornerRadius = UDim.new(0, 6)
SRCorner.Parent = StatusRow

local StatusDot = Instance.new("Frame")
StatusDot.Size = UDim2.new(0, 8, 0, 8)
StatusDot.Position = UDim2.new(0, 10, 0.5, -4)
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
        pcall(function()
            DotPulse:TweenSizeAndPosition(
                UDim2.new(3, 0, 3, 0),
                UDim2.new(-1, 0, -1, 0),
                Enum.EasingDirection.Out,
                Enum.EasingStyle.Sine,
                0.8
            )
        end)
        DotPulse.BackgroundTransparency = 1
        task.wait(0.8)
    end
end)

local StatusLabel = Instance.new("TextLabel")
StatusLabel.Size = UDim2.new(1, -80, 1, 0)
StatusLabel.Position = UDim2.new(0, 24, 0, 0)
StatusLabel.BackgroundTransparency = 1
StatusLabel.Text = "Đang chạy"
StatusLabel.TextColor3 = Color3.fromRGB(160, 170, 200)
StatusLabel.Font = Enum.Font.Gotham
StatusLabel.TextSize = 10
StatusLabel.TextXAlignment = Enum.TextXAlignment.Left
StatusLabel.Parent = StatusRow

local StatusValue = Instance.new("TextLabel")
StatusValue.Size = UDim2.new(0, 50, 1, 0)
StatusValue.Position = UDim2.new(1, -56, 0, 0)
StatusValue.BackgroundTransparency = 1
StatusValue.Text = "ON"
StatusValue.TextColor3 = Color3.fromRGB(120, 255, 160)
StatusValue.Font = Enum.Font.GothamBold
StatusValue.TextSize = 11
StatusValue.TextXAlignment = Enum.TextXAlignment.Right
StatusValue.Parent = StatusRow

local TargetRow = Instance.new("Frame")
TargetRow.Size = UDim2.new(1, -24, 0, 22)
TargetRow.Position = UDim2.new(0, 12, 0, 104)
TargetRow.BackgroundColor3 = Color3.fromRGB(24, 27, 38)
TargetRow.BorderSizePixel = 0
TargetRow.Parent = Main

local TRCorner = Instance.new("UICorner")
TRCorner.CornerRadius = UDim.new(0, 6)
TRCorner.Parent = TargetRow

local TargetIcon = Instance.new("TextLabel")
TargetIcon.Size = UDim2.new(0, 20, 1, 0)
TargetIcon.Position = UDim2.new(0, 2, 0, 0)
TargetIcon.BackgroundTransparency = 1
TargetIcon.Text = "◎"
TargetIcon.TextColor3 = Color3.fromRGB(120, 220, 180)
TargetIcon.Font = Enum.Font.GothamBold
TargetIcon.TextSize = 11
TargetIcon.Parent = TargetRow

local TargetText = Instance.new("TextLabel")
TargetText.Size = UDim2.new(1, -28, 1, 0)
TargetText.Position = UDim2.new(0, 24, 0, 0)
TargetText.BackgroundTransparency = 1
TargetText.Text = "Tìm: 1 người khác · Tổng: 2"
TargetText.TextColor3 = Color3.fromRGB(180, 220, 200)
TargetText.Font = Enum.Font.Gotham
TargetText.TextSize = 9
TargetText.TextXAlignment = Enum.TextXAlignment.Left
TargetText.Parent = TargetRow

local function setStatus(text, color, state)
    StatusLabel.Text = text
    StatusValue.Text = state or ""
    StatusValue.TextColor3 = color or Color3.fromRGB(120, 255, 160)
    StatusDot.BackgroundColor3 = color or Color3.fromRGB(60, 220, 120)
    DotPulse.BackgroundColor3 = color or Color3.fromRGB(60, 220, 120)
end

local function setTarget(text, color)
    TargetText.Text = text
    if color then TargetText.TextColor3 = color end
end

local function updatePlayerCount()
    local count = #Players:GetPlayers()
    PlayerValue.Text = tostring(count)
    if count <= CONFIG.TargetOtherPlayers + 1 then
        PlayerValue.TextColor3 = Color3.fromRGB(120, 255, 160)
    else
        PlayerValue.TextColor3 = Color3.fromRGB(255, 120, 120)
    end
    return count
end

local function updatePing()
    local ok, ping = pcall(function()
        return Stats.Network.ServerStatsItem["Data Ping"]:GetValue()
    end)
    if ok and ping then
        PingLabel.Text = string.format("%dms", math.floor(ping))
        if ping < 100 then
            PingLabel.TextColor3 = Color3.fromRGB(120, 255, 160)
        elseif ping < 200 then
            PingLabel.TextColor3 = Color3.fromRGB(255, 220, 120)
        else
            PingLabel.TextColor3 = Color3.fromRGB(255, 120, 120)
        end
    end
end

task.spawn(function()
    while ScreenGui.Parent do
        updatePing()
        task.wait(1)
    end
end)

Players.PlayerAdded:Connect(function() task.wait(0.2) updatePlayerCount() end)
Players.PlayerRemoving:Connect(function() task.wait(0.4) updatePlayerCount() end)

local SettingsPanel = Instance.new("Frame")
SettingsPanel.Size = UDim2.new(0, 210, 0, 108)
SettingsPanel.Position = UDim2.new(0, 0, 0, 40)
SettingsPanel.BackgroundColor3 = Color3.fromRGB(12, 14, 20)
SettingsPanel.BorderSizePixel = 0
SettingsPanel.Visible = false
SettingsPanel.ZIndex = 5
SettingsPanel.Parent = Main

local SPanelCorner = Instance.new("UICorner")
SPanelCorner.CornerRadius = UDim.new(0, 10)
SPanelCorner.Parent = SettingsPanel

local SetTitle = Instance.new("TextLabel")
SetTitle.Size = UDim2.new(1, -20, 0, 18)
SetTitle.Position = UDim2.new(0, 10, 0, 6)
SetTitle.BackgroundTransparency = 1
SetTitle.Text = "CÀI ĐẶT"
SetTitle.TextColor3 = Color3.fromRGB(180, 190, 220)
SetTitle.Font = Enum.Font.GothamBold
SetTitle.TextSize = 10
SetTitle.TextXAlignment = Enum.TextXAlignment.Left
SetTitle.Parent = SettingsPanel

local TargetLabel = Instance.new("TextLabel")
TargetLabel.Size = UDim2.new(1, -20, 0, 14)
TargetLabel.Position = UDim2.new(0, 10, 0, 28)
TargetLabel.BackgroundTransparency = 1
TargetLabel.Text = "Số người khác trong server:"
TargetLabel.TextColor3 = Color3.fromRGB(160, 170, 200)
TargetLabel.Font = Enum.Font.Gotham
TargetLabel.TextSize = 9
TargetLabel.TextXAlignment = Enum.TextXAlignment.Left
TargetLabel.Parent = SettingsPanel

local SliderBg = Instance.new("Frame")
SliderBg.Size = UDim2.new(1, -20, 0, 8)
SliderBg.Position = UDim2.new(0, 10, 0, 50)
SliderBg.BackgroundColor3 = Color3.fromRGB(30, 34, 48)
SliderBg.BorderSizePixel = 0
SliderBg.Parent = SettingsPanel

local SliderBgCorner = Instance.new("UICorner")
SliderBgCorner.CornerRadius = UDim.new(1, 0)
SliderBgCorner.Parent = SliderBg

local SliderFill = Instance.new("Frame")
SliderFill.Size = UDim2.new(0, 0, 1, 0)
SliderFill.BackgroundColor3 = Color3.fromRGB(120, 80, 255)
SliderFill.BorderSizePixel = 0
SliderFill.Parent = SliderBg

local SliderFillCorner = Instance.new("UICorner")
SliderFillCorner.CornerRadius = UDim.new(1, 0)
SliderFillCorner.Parent = SliderFill

local SliderFillGrad = Instance.new("UIGradient")
SliderFillGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(120, 80, 255)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(60, 180, 255))
})
SliderFillGrad.Parent = SliderFill

local sliderPositions = {
    {x = 0,   value = 1, label = "1 · tổng 2"},
    {x = 0.5, value = 2, label = "2 · tổng 3"},
    {x = 1,   value = 3, label = "3 · tổng 4"},
}

local SliderKnob = Instance.new("Frame")
SliderKnob.Size = UDim2.new(0, 16, 0, 16)
SliderKnob.Position = UDim2.new(0, -8, 0.5, -8)
SliderKnob.BackgroundColor3 = Color3.fromRGB(220, 220, 240)
SliderKnob.BorderSizePixel = 0
SliderKnob.ZIndex = 6
SliderKnob.Parent = SliderBg

local KnobCorner = Instance.new("UICorner")
KnobCorner.CornerRadius = UDim.new(1, 0)
KnobCorner.Parent = SliderKnob

local KnobStroke = Instance.new("UIStroke")
KnobStroke.Color = Color3.fromRGB(120, 80, 255)
KnobStroke.Thickness = 2
KnobStroke.Parent = SliderKnob

local SliderLabel = Instance.new("TextLabel")
SliderLabel.Size = UDim2.new(1, -20, 0, 16)
SliderLabel.Position = UDim2.new(0, 10, 0, 64)
SliderLabel.BackgroundTransparency = 1
SliderLabel.Text = "Chọn: " .. sliderPositions[1].label
SliderLabel.TextColor3 = Color3.fromRGB(220, 220, 240)
SliderLabel.Font = Enum.Font.GothamBold
SliderLabel.TextSize = 10
SliderLabel.TextXAlignment = Enum.TextXAlignment.Left
SliderLabel.Parent = SettingsPanel

local InfoLabel = Instance.new("TextLabel")
InfoLabel.Size = UDim2.new(1, -20, 0, 20)
InfoLabel.Position = UDim2.new(0, 10, 0, 82)
InfoLabel.BackgroundTransparency = 1
InfoLabel.Text = "Nếu không có → nới lên mốc tiếp theo"
InfoLabel.TextColor3 = Color3.fromRGB(130, 140, 170)
InfoLabel.Font = Enum.Font.Gotham
InfoLabel.TextSize = 8
InfoLabel.TextXAlignment = Enum.TextXAlignment.Left
InfoLabel.TextWrapped = true
InfoLabel.Parent = SettingsPanel

local function updateSliderUI(index)
    local pos = sliderPositions[index]
    TweenService:Create(SliderFill, TweenInfo.new(0.2), {
        Size = UDim2.new(pos.x, 0, 1, 0)
    }):Play()
    TweenService:Create(SliderKnob, TweenInfo.new(0.2), {
        Position = UDim2.new(pos.x, -8, 0.5, -8)
    }):Play()
    SliderLabel.Text = "Chọn: " .. pos.label
    CONFIG.TargetOtherPlayers = pos.value
    setTarget("Tìm: " .. pos.value .. " người khác · Tổng: " .. (pos.value + 1))
end

local sliderIndex = 1
SliderBg.InputBegan:Connect(function(input)
    if input.UserInputType ~= Enum.UserInputType.MouseButton1
        and input.UserInputType ~= Enum.UserInputType.Touch then return end

    local function updateFromInput(inp)
        local relX = (inp.Position.X - SliderBg.AbsolutePosition.X) / SliderBg.AbsoluteSize.X
        relX = math.clamp(relX, 0, 1)
        local idx
        if relX < 0.25 then idx = 1
        elseif relX < 0.75 then idx = 2
        else idx = 3 end
        if idx ~= sliderIndex then
            sliderIndex = idx
            updateSliderUI(sliderIndex)
        end
    end

    updateFromInput(input)

    local conn1, conn2
    conn1 = UserInputService.InputChanged:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseMovement
            or inp.UserInputType == Enum.UserInputType.Touch then
            updateFromInput(inp)
        end
    end)
    conn2 = UserInputService.InputEnded:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1
            or inp.UserInputType == Enum.UserInputType.Touch then
            pcall(function() conn1:Disconnect() end)
            pcall(function() conn2:Disconnect() end)
        end
    end)
end)

SetBtn.MouseButton1Click:Connect(function()
    SettingsPanel.Visible = not SettingsPanel.Visible
end)

local function updatePlayerCount() end

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

local function calculateGhostScore(server, stabilityBonus)
    local score = 0
    score = score + (server.ping / 5)
    score = score + ((60 - server.fps) * 30)
    score = score + (stabilityBonus * 5000)
    if server.afkDetected then
        score = score + 3000
    end
    return score
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

local function findServer(targetPlaying, strictMode)
    local pass1 = parallelScan(targetPlaying)
    local count1 = 0
    for _ in pairs(pass1) do count1 = count1 + 1 end
    if count1 == 0 then return nil end

    task.wait(CONFIG.PassDelay)

    local pass2 = parallelScan(targetPlaying)

    task.wait(CONFIG.PassDelay)

    local pass3 = parallelScan(targetPlaying)

    local stable = {}
    for id, s3 in pairs(pass3) do
        local s1 = pass1[id]
        local s2 = pass2[id]
        if s1 and s2 then
            s3.stability = 3
            if s1.playing == targetPlaying and s2.playing == targetPlaying and s3.playing == targetPlaying then
                s3.afkDetected = true
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

    task.wait(CONFIG.ConfirmDelay)

    if strictMode then
        local filtered = {}
        for _, s in ipairs(stable) do
            if s.stability == 3 then
                table.insert(filtered, s)
            end
        end
        if #filtered > 0 then
            stable = filtered
        else
            return nil
        end
    end

    local finalPool = {}
    for _, s in ipairs(stable) do
        s.score = calculateGhostScore(s, s.stability)
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

local function findBestServer()
    for target = 1, CONFIG.TargetOtherPlayers do
        local strict = target >= 3
        setStatus("Quét server " .. target .. " người khác", Color3.fromRGB(255, 200, 100), "...")
        local result = findServer(target, strict)
        if result then
            return result, target
        end
    end
    return nil, nil
end

local function addHistory(target, success, msg)
    table.insert(History, 1, {
        id = target.id:sub(1, 8),
        playing = target.playing,
        fps = target.fps,
        ping = target.ping,
        success = success,
        msg = msg,
        time = os.date("%H:%M:%S"),
    })
    while #History > 10 do table.remove(History) end
end

local function resetBlacklistIfNeeded()
    local now = os.time()
    if #Blacklist > CONFIG.BlacklistMaxSize
        or (now - BlacklistTimestamp) > CONFIG.BlacklistResetTime then
        Blacklist = {}
        BlacklistTimestamp = now
    end
end

local function tryHopWithVerify(target)
    local startJobId = game.JobId

    local sent = fastTeleport(target.id)
    if not sent then
        return false, "send_fail"
    end

    local waited = 0
    while waited < CONFIG.TeleportTimeout do
        task.wait(0.5)
        waited = waited + 0.5

        if game.JobId ~= startJobId and game.JobId ~= "" then
            return true, "success"
        end
    end

    return false, "timeout"
end

local function performHop()
    if IsScanning or IsHopping then return end
    IsScanning = true

    if not http then
        IsScanning = false
        setStatus("Lỗi HTTP", Color3.fromRGB(255, 100, 100), "OFF")
        return
    end

    resetBlacklistIfNeeded()

    local attempt = 0

    while attempt < CONFIG.MaxHopRetries and AutoEnabled do
        attempt = attempt + 1

        local target, mode = findBestServer()

        if not target then
            setStatus("Không có server", Color3.fromRGB(255, 120, 120), "FAIL")
            task.wait(5)
        else
            setStatus("Vào " .. target.playing .. "n · " .. target.fps .. "fps · " .. target.ping .. "ms",
                Color3.fromRGB(120, 255, 160), "HOP")

            task.wait(CONFIG.PreTeleportDelay)

            IsScanning = false
            IsHopping = true
            Blacklist[target.id] = true

            local ok, reason = tryHopWithVerify(target)

            if ok then
                addHistory(target, true, "OK")
                return
            end

            IsHopping = false
            IsScanning = true

            addHistory(target, false, reason)

            if reason == "send_fail" then
                setStatus("Gửi lỗi · thử lại", Color3.fromRGB(255, 120, 120), "FAIL")
            else
                setStatus("Server lỗi · đổi", Color3.fromRGB(255, 150, 100), "FAIL")
            end

            task.wait(1)
        end
    end

    IsScanning = false
    IsHopping = false
    setStatus("Hết lần thử · chờ", Color3.fromRGB(255, 100, 100), "FAIL")

    task.wait(10)
    setStatus("Đang chạy", Color3.fromRGB(120, 255, 160), "ON")
end

local function startMonitor()
    if MonitorConn then MonitorConn:Disconnect() end
    MonitorConn = RunService.Heartbeat:Connect(function()
        if not AutoEnabled then return end
        if IsHopping or IsScanning then return end

        local count = #Players:GetPlayers()
        if count == LastPlayerCount then return end
        LastPlayerCount = count

        if count > CONFIG.TargetOtherPlayers + 1 then
            local delay = math.random(CONFIG.AutoHopDelayMin, CONFIG.AutoHopDelayMax)
            setStatus("Đông · hop sau " .. delay .. "s", Color3.fromRGB(255, 200, 120), "...")

            task.spawn(function()
                for i = delay, 1, -1 do
                    if not AutoEnabled then return end
                    if IsHopping or IsScanning then return end
                    local cnt = #Players:GetPlayers()
                    if cnt <= CONFIG.TargetOtherPlayers + 1 then
                        setStatus("Đã về " .. cnt .. " người", Color3.fromRGB(120, 255, 160), "ON")
                        return
                    end
                    setStatus("Hop sau " .. i .. "s · " .. cnt .. " người", Color3.fromRGB(255, 180, 100), "...")
                    task.wait(1)
                end

                if #Players:GetPlayers() > CONFIG.TargetOtherPlayers + 1 then
                    performHop()
                end
            end)
        else
            setStatus("Server " .. count .. " người · ổn", Color3.fromRGB(120, 255, 160), "ON")
        end
    end)
end

task.spawn(function()
    while ScreenGui.Parent do
        task.wait(900)
        pcall(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton1(Vector2.new())
        end)
    end
end)

pcall(function()
    if queue_on_teleport then
        local scriptUrl = ""
        queue_on_teleport('loadstring(game:HttpGet("' .. scriptUrl .. '"))()')
    end
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

SetBtn.MouseEnter:Connect(function()
    SetBtn.BackgroundColor3 = Color3.fromRGB(50, 55, 75)
end)
SetBtn.MouseLeave:Connect(function()
    SetBtn.BackgroundColor3 = Color3.fromRGB(35, 40, 55)
end)

updateSliderUI(1)
updatePlayerCount()
setStatus("Đang chạy", Color3.fromRGB(120, 255, 160), "ON")
startMonitor()

task.spawn(function()
    task.wait(2)
    local count = #Players:GetPlayers()
    if count > CONFIG.TargetOtherPlayers + 1 then
        performHop()
    end
end)

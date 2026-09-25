local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local PLACE_ID = game.PlaceId
local JOB_ID = game.JobId

-- ==== CONFIG ====
local CONFIG = {
    HopDelay = 5,
    MinPlayersToHop = 2,
    MaxPages = 20,
    MinPlayer = 1,
    MaxPlayer = 5,
}

local function getHttp()
    if syn and syn.request then return syn.request end
    if http_request then return http_request end
    if request then return request end
    if fluxus and fluxus.request then return fluxus.request end
    if krnl and krnl.request then return krnl.request end
    return nil
end

local http = getHttp()

pcall(function()
    if game:GetService("CoreGui"):FindFirstChild("HopUI") then
        game:GetService("CoreGui").HopUI:Destroy()
    end
end)

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "HopUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.IgnoreGuiInset = true
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = game:GetService("CoreGui")

local Main = Instance.new("Frame")
Main.Size = UDim2.new(0, 200, 0, 155)
Main.Position = UDim2.new(0, 20, 0.5, -77)
Main.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
Main.BorderSizePixel = 0
Main.Parent = ScreenGui

local Btn = Instance.new("TextButton")
Btn.Size = UDim2.new(0, 70, 0, 70)
Btn.Position = UDim2.new(0, 10, 0, 10)
Btn.BackgroundColor3 = Color3.fromRGB(60, 180, 120)
Btn.Text = "HOP"
Btn.TextColor3 = Color3.fromRGB(255, 255, 255)
Btn.Font = Enum.Font.GothamBold
Btn.TextSize = 16
Btn.AutoButtonColor = false
Btn.Parent = Main

local AutoBtn = Instance.new("TextButton")
AutoBtn.Size = UDim2.new(0, 110, 0, 30)
AutoBtn.Position = UDim2.new(0, 85, 0, 10)
AutoBtn.BackgroundColor3 = Color3.fromRGB(90, 60, 140)
AutoBtn.Text = "AUTO: OFF"
AutoBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
AutoBtn.Font = Enum.Font.GothamBold
AutoBtn.TextSize = 11
AutoBtn.AutoButtonColor = false
AutoBtn.Parent = Main

local DelayBtn = Instance.new("TextButton")
DelayBtn.Size = UDim2.new(0, 110, 0, 30)
DelayBtn.Position = UDim2.new(0, 85, 0, 50)
DelayBtn.BackgroundColor3 = Color3.fromRGB(40, 45, 60)
DelayBtn.Text = "DELAY: 5s"
DelayBtn.TextColor3 = Color3.fromRGB(200, 210, 230)
DelayBtn.Font = Enum.Font.GothamBold
DelayBtn.TextSize = 11
DelayBtn.AutoButtonColor = false
DelayBtn.Parent = Main

local CountLabel = Instance.new("TextLabel")
CountLabel.Size = UDim2.new(0, 110, 0, 18)
CountLabel.Position = UDim2.new(0, 85, 0, 85)
CountLabel.BackgroundTransparency = 1
CountLabel.Text = "Players: 1/12"
CountLabel.TextColor3 = Color3.fromRGB(120, 255, 160)
CountLabel.Font = Enum.Font.Code
CountLabel.TextSize = 9
CountLabel.TextXAlignment = Enum.TextXAlignment.Left
CountLabel.Parent = Main

local StatusLabel = Instance.new("TextLabel")
StatusLabel.Size = UDim2.new(1, -20, 0, 30)
StatusLabel.Position = UDim2.new(0, 10, 0, 115)
StatusLabel.BackgroundTransparency = 1
StatusLabel.Text = "Sẵn sàng"
StatusLabel.TextColor3 = Color3.fromRGB(200, 220, 255)
StatusLabel.Font = Enum.Font.GothamBold
StatusLabel.TextSize = 10
StatusLabel.TextWrapped = true
StatusLabel.Parent = Main

local State = {
    AutoEnabled = false,
    IsHopping = false,
    PlayerAddedConn = nil,
    PlayerRemovingConn = nil,
    PendingHopThread = nil,
}

local function getPlayerCount()
    return #Players:GetPlayers()
end

local function updatePlayerCount()
    local count = getPlayerCount()
    local maxP = Players.MaxPlayers or 12
    CountLabel.Text = "Players: " .. count .. "/" .. maxP

    if count <= 1 then
        CountLabel.TextColor3 = Color3.fromRGB(120, 255, 160)
    elseif count == 2 then
        CountLabel.TextColor3 = Color3.fromRGB(255, 220, 120)
    else
        CountLabel.TextColor3 = Color3.fromRGB(255, 120, 120)
    end
end

local function setStatus(text, color)
    StatusLabel.Text = text
    StatusLabel.TextColor3 = color or Color3.fromRGB(200, 220, 255)
end

local function doHop(reason)
    if State.IsHopping then return end
    if not http then
        setStatus("Không có HTTP", Color3.fromRGB(255, 100, 100))
        return
    end

    State.IsHopping = true

    setStatus("Đang quét...", Color3.fromRGB(255, 200, 100))
    Btn.BackgroundColor3 = Color3.fromRGB(200, 160, 60)
    Btn.Text = "..."

    local candidates = {}
    local cursor = ""
    local pages = 0

    while pages < CONFIG.MaxPages do
        local url = string.format(
            "https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100&cursor=%s",
            PLACE_ID, cursor or ""
        )
        local ok, res = pcall(function() return http({Url = url, Method = "GET"}) end)
        if not ok or not res then break end
        local body = res.Body or res.body
        if type(body) ~= "string" then break end
        local ok2, data = pcall(function() return HttpService:JSONDecode(body) end)
        if not ok2 or type(data) ~= "table" then break end
        if type(data.data) ~= "table" then break end

        local cnt = 0
        for _, s in ipairs(data.data) do
            cnt = cnt + 1
            local pc = tonumber(s.playing) or 0
            local id = s.id
            if type(id) == "string" and id ~= JOB_ID and pc >= CONFIG.MinPlayer and pc <= CONFIG.MaxPlayer then
                table.insert(candidates, {
                    id = id,
                    playing = pc,
                    ping = tonumber(s.ping) or 999,
                    fps = tonumber(s.fps) or 60,
                })
            end
        end
        if cnt == 0 then break end

        cursor = data.nextPageCursor
        if not cursor or cursor == "" or cursor == "null" then break end
        pages = pages + 1
        task.wait(0.05)
    end

    if #candidates == 0 then
        setStatus("Không có server!", Color3.fromRGB(255, 100, 100))
        Btn.BackgroundColor3 = Color3.fromRGB(60, 180, 120)
        Btn.Text = "HOP"
        State.IsHopping = false
        return
    end

    table.sort(candidates, function(a, b)
        if a.playing ~= b.playing then return a.playing < b.playing end
        if a.fps ~= b.fps then return a.fps < b.fps end
        return a.ping > b.ping
    end)

    local target = candidates[1]

    local prefix = reason and ("[" .. reason .. "] ") or ""
    setStatus(prefix .. "Vào " .. target.playing .. "ng · FPS" .. target.fps .. " · P" .. target.ping,
        Color3.fromRGB(120, 255, 160))
    Btn.Text = ">>"

    task.wait(0.3)

    local sent = false
    pcall(function()
        local opts = Instance.new("TeleportOptions")
        opts.ServerInstanceId = target.id
        TeleportService:TeleportAsync(PLACE_ID, {LocalPlayer}, opts)
        sent = true
    end)
    if not sent then
        pcall(function()
            TeleportService:TeleportToPlaceInstance(PLACE_ID, target.id, LocalPlayer)
        end)
    end

    State.IsHopping = false
end

local function cancelPendingHop()
    if State.PendingHopThread then
        pcall(function() task.cancel(State.PendingHopThread) end)
        State.PendingHopThread = nil
    end
end

local function scheduleAutoHop()
    cancelPendingHop()

    State.PendingHopThread = task.spawn(function()
        setStatus("Phát hiện người vào · chờ " .. CONFIG.HopDelay .. "s",
            Color3.fromRGB(255, 180, 100))

        for i = CONFIG.HopDelay, 1, -1 do
            if not State.AutoEnabled then
                setStatus("Auto đã tắt", Color3.fromRGB(200, 220, 255))
                return
            end
            local count = getPlayerCount()
            if count < CONFIG.MinPlayersToHop then
                setStatus("Người đó đã rời · huỷ hop", Color3.fromRGB(120, 255, 160))
                return
            end
            setStatus("Chờ " .. i .. "s · server có " .. count .. " người",
                Color3.fromRGB(255, 180, 100))
            task.wait(1)
        end

        if not State.AutoEnabled then return end
        if getPlayerCount() < CONFIG.MinPlayersToHop then return end

        setStatus("Auto hop!", Color3.fromRGB(255, 150, 100))
        doHop("Auto")
    end)
end

local function setupAutoListeners()
    if State.PlayerAddedConn then
        State.PlayerAddedConn:Disconnect()
        State.PlayerAddedConn = nil
    end
    if State.PlayerRemovingConn then
        State.PlayerRemovingConn:Disconnect()
        State.PlayerRemovingConn = nil
    end

    if not State.AutoEnabled then return end

    State.PlayerAddedConn = Players.PlayerAdded:Connect(function(plr)
        if plr == LocalPlayer then return end
        if not State.AutoEnabled then return end
        if State.IsHopping then return end

        task.wait(0.3)
        local count = getPlayerCount()
        updatePlayerCount()

        if count >= CONFIG.MinPlayersToHop then
            scheduleAutoHop()
        end
    end)

    State.PlayerRemovingConn = Players.PlayerRemoving:Connect(function()
        task.wait(0.3)
        updatePlayerCount()
        if getPlayerCount() < CONFIG.MinPlayersToHop then
            cancelPendingHop()
        end
    end)
end

local function setAuto(enabled)
    State.AutoEnabled = enabled

    if enabled then
        AutoBtn.Text = "AUTO: ON"
        AutoBtn.BackgroundColor3 = Color3.fromRGB(60, 180, 120)
        setStatus("Auto ON · sẽ hop khi có người vào", Color3.fromRGB(120, 255, 160))

        setupAutoListeners()

        if getPlayerCount() >= CONFIG.MinPlayersToHop then
            scheduleAutoHop()
        end
    else
        AutoBtn.Text = "AUTO: OFF"
        AutoBtn.BackgroundColor3 = Color3.fromRGB(90, 60, 140)
        setStatus("Auto OFF", Color3.fromRGB(200, 220, 255))

        cancelPendingHop()
        setupAutoListeners()
    end
end

AutoBtn.MouseButton1Click:Connect(function()
    setAuto(not State.AutoEnabled)
end)

local delayOptions = {5, 10, 3, 15, 20, 30}
local delayIndex = 1

DelayBtn.MouseButton1Click:Connect(function()
    delayIndex = delayIndex + 1
    if delayIndex > #delayOptions then delayIndex = 1 end
    CONFIG.HopDelay = delayOptions[delayIndex]
    DelayBtn.Text = "DELAY: " .. CONFIG.HopDelay .. "s"
    DelayBtn.BackgroundColor3 = Color3.fromRGB(60, 100, 140)
    task.delay(0.3, function()
        DelayBtn.BackgroundColor3 = Color3.fromRGB(40, 45, 60)
    end)
end)

local dragStart = nil
local startPos = nil
local moved = false

Btn.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        dragStart = input.Position
        startPos = Main.Position
        moved = false
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if not dragStart then return end
    if input.UserInputType ~= Enum.UserInputType.MouseMovement
        and input.UserInputType ~= Enum.UserInputType.Touch then return end
    local d = input.Position - dragStart
    if math.abs(d.X) > 5 or math.abs(d.Y) > 5 then moved = true end
    if moved then
        Main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType ~= Enum.UserInputType.MouseButton1
        and input.UserInputType ~= Enum.UserInputType.Touch then return end
    if not dragStart then return end
    local wasMoved = moved
    dragStart = nil
    moved = false
    if wasMoved then return end

    task.spawn(function()
        doHop(nil)
    end)
end)

Players.PlayerAdded:Connect(function() task.wait(0.3) updatePlayerCount() end)
Players.PlayerRemoving:Connect(function() task.wait(0.5) updatePlayerCount() end)
updatePlayerCount()

print("[HOP v13.2.4.4] Loaded | Auto Hop + Delay config")

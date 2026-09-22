local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local CoreGui = game:GetService("CoreGui")

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

-- ==== CONFIG ====
local CONFIG = {
    MinPlayers = 1,        -- Số người tối thiểu
    MaxPlayers = 1,        -- Số người tối đa (ưu tiên server 1 người)
    MaxPages = 15,
    ScanInterval = 3,      -- Giây giữa các lần scan khi đang ở server ổn
    RehopDelay = 8,        -- Giây chờ trước khi hop khi có người vào
}

-- ==== BLACKLIST ====
local Blacklist = {}
local IsRunning = true
local IsHopping = false
local CurrentState = "idle"

if CoreGui:FindFirstChild("AutoHopUI") then CoreGui.AutoHopUI:Destroy() end

-- ==== UI ====
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "AutoHopUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.IgnoreGuiInset = true
ScreenGui.DisplayOrder = 999999
ScreenGui.Parent = CoreGui

local Main = Instance.new("Frame")
Main.Size = UDim2.new(0, 180, 0, 50)
Main.Position = UDim2.new(0, 20, 0.5, -25)
Main.BackgroundColor3 = Color3.fromRGB(18, 20, 28)
Main.BorderSizePixel = 0
Main.Parent = ScreenGui

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 8)
MainCorner.Parent = Main

local Stroke = Instance.new("UIStroke")
Stroke.Color = Color3.fromRGB(60, 180, 120)
Stroke.Thickness = 1
Stroke.Transparency = 0.4
Stroke.Parent = Main

local StatusLabel = Instance.new("TextLabel")
StatusLabel.Size = UDim2.new(1, -16, 0, 16)
StatusLabel.Position = UDim2.new(0, 8, 0, 8)
StatusLabel.BackgroundTransparency = 1
StatusLabel.Text = "Đang khởi động..."
StatusLabel.TextColor3 = Color3.fromRGB(200, 220, 255)
StatusLabel.Font = Enum.Font.GothamBold
StatusLabel.TextSize = 11
StatusLabel.TextXAlignment = Enum.TextXAlignment.Left
StatusLabel.Parent = Main

local InfoLabel = Instance.new("TextLabel")
InfoLabel.Size = UDim2.new(1, -16, 0, 16)
InfoLabel.Position = UDim2.new(0, 8, 0, 26)
InfoLabel.BackgroundTransparency = 1
InfoLabel.Text = "0 người · chờ"
InfoLabel.TextColor3 = Color3.fromRGB(140, 180, 220)
InfoLabel.Font = Enum.Font.Code
InfoLabel.TextSize = 10
InfoLabel.TextXAlignment = Enum.TextXAlignment.Left
InfoLabel.Parent = Main

local Dot = Instance.new("Frame")
Dot.Size = UDim2.new(0, 6, 0, 6)
Dot.Position = UDim2.new(1, -14, 0, 10)
Dot.BackgroundColor3 = Color3.fromRGB(60, 200, 100)
Dot.BorderSizePixel = 0
Dot.Parent = Main

local DotCorner = Instance.new("UICorner")
DotCorner.CornerRadius = UDim.new(1, 0)
DotCorner.Parent = Dot

-- ==== UI HELPERS ====
local SPINNER = {"|", "/", "-", "\\"}
local spinIndex = 1

local function setStatus(text, color)
    StatusLabel.Text = text
    StatusLabel.TextColor3 = color or Color3.fromRGB(200, 220, 255)
end

local function setInfo(text, color)
    InfoLabel.Text = text
    InfoLabel.TextColor3 = color or Color3.fromRGB(140, 180, 220)
end

local function setDotState(state)
    if state == "active" then
        Dot.BackgroundColor3 = Color3.fromRGB(60, 200, 100)
        Stroke.Color = Color3.fromRGB(60, 180, 120)
    elseif state == "scanning" then
        Dot.BackgroundColor3 = Color3.fromRGB(255, 200, 100)
        Stroke.Color = Color3.fromRGB(255, 180, 100)
    elseif state == "hopping" then
        Dot.BackgroundColor3 = Color3.fromRGB(255, 140, 60)
        Stroke.Color = Color3.fromRGB(255, 140, 60)
    elseif state == "error" then
        Dot.BackgroundColor3 = Color3.fromRGB(255, 100, 100)
        Stroke.Color = Color3.fromRGB(200, 60, 60)
    end
end

-- Spinner animation
task.spawn(function()
    while ScreenGui.Parent and IsRunning do
        spinIndex = spinIndex + 1
        if spinIndex > #SPINNER then spinIndex = 1 end
        local spin = SPINNER[spinIndex]
        if CurrentState == "scanning" then
            StatusLabel.Text = "Đang tìm server " .. spin
        end
        task.wait(0.15)
    end
end)

-- Player count update
local function updatePlayerCount()
    local count = #Players:GetPlayers()
    setInfo(count .. " người trong server", 
        count <= 1 and Color3.fromRGB(120, 255, 160) 
        or count == 2 and Color3.fromRGB(255, 220, 120) 
        or Color3.fromRGB(255, 120, 120))
    return count
end

Players.PlayerAdded:Connect(function() task.wait(0.3) updatePlayerCount() end)
Players.PlayerRemoving:Connect(function() task.wait(0.5) updatePlayerCount() end)

-- ==== SCAN ====
local function scanServers()
    if not http then
        setStatus("Không có HTTP", Color3.fromRGB(255, 100, 100))
        setDotState("error")
        return {}
    end

    local candidates = {}
    local cursor = ""
    local pages = 0

    while pages < CONFIG.MaxPages do
        local url = string.format(
            "https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100&cursor=%s",
            PLACE_ID, cursor or ""
        )
        local ok, res = pcall(function()
            return http({ Url = url, Method = "GET", Headers = { ["Accept"] = "application/json" } })
        end)
        if not ok or not res then break end
        local body = res.Body or res.body
        if type(body) ~= "string" then break end
        local ok2, data = pcall(function()
            return HttpService:JSONDecode(body)
        end)
        if not ok2 or type(data) ~= "table" then break end
        if type(data.data) ~= "table" then break end

        local cnt = 0
        for _, s in ipairs(data.data) do
            cnt = cnt + 1
            local pc = tonumber(s.playing) or 0
            local id = s.id
            if type(id) == "string" and id ~= JOB_ID and not Blacklist[id] then
                if pc >= CONFIG.MinPlayers and pc <= CONFIG.MaxPlayers then
                    table.insert(candidates, {
                        id = id,
                        playing = pc,
                        ping = tonumber(s.ping) or 999,
                        fps = tonumber(s.fps) or 60,
                    })
                end
            end
        end
        if cnt == 0 then break end

        cursor = data.nextPageCursor
        if not cursor or cursor == "" or cursor == "null" then break end
        pages = pages + 1
        task.wait(0.05)
    end

    -- Sort: ưu tiên số người ít → FPS thấp → ping cao
    table.sort(candidates, function(a, b)
        if a.playing ~= b.playing then return a.playing < b.playing end
        if a.fps ~= b.fps then return a.fps < b.fps end
        return a.ping > b.ping
    end)

    return candidates
end

-- ==== HOP ====
local function hopTo(target)
    if IsHopping then return false end
    IsHopping = true
    CurrentState = "hopping"
    setDotState("hopping")
    setStatus("Đang vào server...", Color3.fromRGB(255, 180, 100))

    local success = false
    pcall(function()
        local opts = Instance.new("TeleportOptions")
        opts.ServerInstanceId = target.id
        TeleportService:TeleportAsync(PLACE_ID, {LocalPlayer}, opts)
        success = true
    end)
    if not success then
        pcall(function()
            TeleportService:TeleportToPlaceInstance(PLACE_ID, target.id, LocalPlayer)
            success = true
        end)
    end

    if success then
        Blacklist[target.id] = true
    end

    task.wait(3)
    IsHopping = false
    return success
end

-- ==== MAIN LOOP ====
local function mainLoop()
    task.wait(1)

    while IsRunning and ScreenGui.Parent do
        local count = updatePlayerCount()

        -- Nếu đang ở server 1 người → ổn định, chỉ chờ
        if count <= 1 then
            CurrentState = "stable"
            setDotState("active")
            setStatus("Server 1 người ✓", Color3.fromRGB(120, 255, 160))

            -- Chờ và theo dõi liên tục
            for _ = 1, CONFIG.ScanInterval do
                if not ScreenGui.Parent then return end
                task.wait(1)
                local c = #Players:GetPlayers()
                updatePlayerCount()
                if c > 1 then
                    -- Có người vào → chuẩn bị hop
                    setStatus("Có người vào · chờ " .. CONFIG.RehopDelay .. "s", 
                        Color3.fromRGB(255, 180, 100))
                    setDotState("scanning")

                    for i = CONFIG.RehopDelay, 1, -1 do
                        if not ScreenGui.Parent then return end
                        local cnt = #Players:GetPlayers()
                        if cnt <= 1 then
                            setStatus("Người đó đã rời ✓", Color3.fromRGB(120, 255, 160))
                            setDotState("active")
                            break
                        end
                        setStatus("Hop sau " .. i .. "s · " .. cnt .. " người", 
                            Color3.fromRGB(255, 180, 100))
                        task.wait(1)
                    end

                    -- Sau delay, nếu vẫn có người → hop
                    if #Players:GetPlayers() > 1 then
                        count = 999  -- force re-scan below
                    else
                        count = 1
                    end
                    break
                end
            end

            if count <= 1 then
                -- Vẫn ổn → tiếp tục loop
                continue
            end
        end

        -- Cần tìm server mới
        CurrentState = "scanning"
        setDotState("scanning")
        setStatus("Đang tìm server...", Color3.fromRGB(255, 200, 100))

        local candidates = scanServers()

        if #candidates == 0 then
            setStatus("Không có server 1 người", Color3.fromRGB(255, 100, 100))
            setDotState("error")
            setInfo("Chờ 5s rồi thử lại...", Color3.fromRGB(255, 150, 150))
            task.wait(5)
            -- Reset blacklist sau vài lần thất bại
            local blCount = 0
            for _ in pairs(Blacklist) do blCount = blCount + 1 end
            if blCount > 50 then
                Blacklist = {}
            end
        else
            local target = candidates[1]
            setInfo(
                target.playing .. " người · FPS" .. target.fps .. " · P" .. target.ping,
                Color3.fromRGB(120, 255, 160)
            )
            task.wait(0.3)
            hopTo(target)
            task.wait(2)
        end
    end
end

-- ==== AUTO MONITOR (re-hook khi đang ở server 1 người) ====
task.spawn(function()
    while IsRunning and ScreenGui.Parent do
        task.wait(1)
        if not IsHopping then
            local count = #Players:GetPlayers()
            if count > 1 and CurrentState == "stable" then
                -- Trigger rehop
                task.spawn(function()
                    setStatus("Có người vào · chờ " .. CONFIG.RehopDelay .. "s", 
                        Color3.fromRGB(255, 180, 100))
                    setDotState("scanning")

                    for i = CONFIG.RehopDelay, 1, -1 do
                        if not ScreenGui.Parent then return end
                        local cnt = #Players:GetPlayers()
                        if cnt <= 1 then
                            setStatus("Người đó đã rời ✓", Color3.fromRGB(120, 255, 160))
                            setDotState("active")
                            return
                        end
                        setStatus("Hop sau " .. i .. "s · " .. cnt .. " người", 
                            Color3.fromRGB(255, 180, 100))
                        task.wait(1)
                    end

                    if #Players:GetPlayers() > 1 then
                        local candidates = scanServers()
                        if #candidates > 0 then
                            hopTo(candidates[1])
                        end
                    end
                end)
            end
        end
    end
end)

-- ==== DRAG UI ====
local UserInputService = game:GetService("UserInputService")
local dragging, dragStart, startPos

Main.InputBegan:Connect(function(input)
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

-- ==== START ====
setStatus("Khởi động...", Color3.fromRGB(255, 200, 100))
setDotState("scanning")
updatePlayerCount()

task.spawn(mainLoop)

print("[AUTO HOP] Đang chạy liên tục | Tìm server 1 người")

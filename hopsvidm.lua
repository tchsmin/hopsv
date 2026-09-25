--[[
    ⚡ PHANTOM — HOP SERVER ÍT NGƯỜI ⚡
    Game     : Steal an Egg
    Version  : V13.2.1
    Executor : Delta
    Chức năng: Hop server 1 người + Auto Hop + Queue + UI
--]]

-- ==========================================================
--  CONFIG
-- ==========================================================
local CONFIG = {
    Version          = "V13.2.1",
    ScanPasses       = 3,     -- số pass quét
    PassDelay        = 5,     -- giây giữa các pass
    HopDelay         = 3,     -- giây đếm ngược trước khi hop
    AutoHopThreshold = 3,     -- hop khi server >= 3 người
    RequestLimit     = 100,   -- số server mỗi request
}

-- ==========================================================
--  SERVICES
-- ==========================================================
local Players         = game:GetService("Players")
local HttpService     = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local UserInputService= game:GetService("UserInputService")

local LP      = Players.LocalPlayer
local PlaceId = game.PlaceId
local JobId   = game.JobId

-- ==========================================================
--  STATE
-- ==========================================================
local State = {
    AutoOn       = true,
    IsScanning   = false,
    QueuedServer = nil,
    Status       = "Đang khởi động...",
    CurrentCount = #Players:GetPlayers(),
    Log          = {},
    HopCountdown = nil,
}

-- ==========================================================
--  UTIL
-- ==========================================================
local function log(msg)
    local line = string.format("[%s] %s", os.date("%H:%M:%S"), msg)
    table.insert(State.Log, line)
    if #State.Log > 300 then table.remove(State.Log, 1) end
    print("[PHANTOM] " .. msg)
end

-- ==========================================================
--  UI
-- ==========================================================
local guiParent = (gethui and gethui()) or game:GetService("CoreGui")
pcall(function()
    if guiParent:FindFirstChild("PHANTOM_HOP") then
        guiParent.PHANTOM_HOP:Destroy()
    end
end)

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "PHANTOM_HOP"
ScreenGui.ResetOnSpawn = false
ScreenGui.IgnoreGuiInset = true
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = guiParent

-- Khung chính
local Main = Instance.new("Frame")
Main.Name = "Main"
Main.Size = UDim2.new(0, 320, 0, 340)
Main.Position = UDim2.new(0, 20, 0.5, -170)
Main.BackgroundColor3 = Color3.fromRGB(14, 14, 20)
Main.BorderSizePixel = 0
Main.Active = true
Main.Parent = ScreenGui

Instance.new("UICorner", Main).CornerRadius = UDim.new(0, 14)
local stroke = Instance.new("UIStroke", Main)
stroke.Color = Color3.fromRGB(140, 90, 255)
stroke.Thickness = 1.5
stroke.Transparency = 0.2
stroke.Parent = Main

-- Header
local Header = Instance.new("Frame")
Header.Size = UDim2.new(1, 0, 0, 46)
Header.BackgroundColor3 = Color3.fromRGB(24, 18, 46)
Header.BorderSizePixel = 0
Header.Parent = Main
Instance.new("UICorner", Header).CornerRadius = UDim.new(0, 14)

local hFix = Instance.new("Frame")
hFix.Size = UDim2.new(1, 0, 0, 14)
hFix.Position = UDim2.new(0, 0, 1, -14)
hFix.BackgroundColor3 = Color3.fromRGB(24, 18, 46)
hFix.BorderSizePixel = 0
hFix.Parent = Header

local Title = Instance.new("TextLabel")
Title.BackgroundTransparency = 1
Title.Size = UDim2.new(1, -110, 1, 0)
Title.Position = UDim2.new(0, 14, 0, 0)
Title.Font = Enum.Font.GothamBold
Title.TextSize = 20
Title.TextColor3 = Color3.fromRGB(215, 195, 255)
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Text = "⚡ PHANTOM"
Title.Parent = Header

local VerTag = Instance.new("TextLabel")
VerTag.BackgroundTransparency = 1
VerTag.Size = UDim2.new(0, 100, 1, 0)
VerTag.Position = UDim2.new(1, -105, 0, 0)
VerTag.Font = Enum.Font.Gotham
VerTag.TextSize = 12
VerTag.TextColor3 = Color3.fromRGB(155, 135, 215)
VerTag.TextXAlignment = Enum.TextXAlignment.Right
VerTag.Text = CONFIG.Version
VerTag.Parent = Header

-- Kéo thả
do
    local dragging, dragStart, startPos
    Header.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            dragging   = true
            dragStart  = input.Position
            startPos   = Main.Position
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch) then
            local d = input.Position - dragStart
            Main.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + d.X,
                startPos.Y.Scale, startPos.Y.Offset + d.Y
            )
        end
    end)
end

-- Body
local Body = Instance.new("Frame")
Body.BackgroundTransparency = 1
Body.Size = UDim2.new(1, -24, 1, -120)
Body.Position = UDim2.new(0, 12, 0, 56)
Body.Parent = Main

local function makeRow(y, label)
    local f = Instance.new("Frame")
    f.BackgroundColor3 = Color3.fromRGB(22, 22, 32)
    f.BorderSizePixel = 0
    f.Size = UDim2.new(1, 0, 0, 34)
    f.Position = UDim2.new(0, 0, 0, y)
    f.Parent = Body
    Instance.new("UICorner", f).CornerRadius = UDim.new(0, 8)

    local key = Instance.new("TextLabel")
    key.BackgroundTransparency = 1
    key.Size = UDim2.new(0.5, 0, 1, 0)
    key.Position = UDim2.new(0, 12, 0, 0)
    key.Font = Enum.Font.GothamMedium
    key.TextSize = 13
    key.TextColor3 = Color3.fromRGB(160, 150, 200)
    key.TextXAlignment = Enum.TextXAlignment.Left
    key.Text = label
    key.Parent = f

    local val = Instance.new("TextLabel")
    val.BackgroundTransparency = 1
    val.Size = UDim2.new(0.5, -12, 1, 0)
    val.Position = UDim2.new(0.5, 0, 0, 0)
    val.Font = Enum.Font.GothamBold
    val.TextSize = 13
    val.TextColor3 = Color3.fromRGB(230, 230, 250)
    val.TextXAlignment = Enum.TextXAlignment.Right
    val.Text = "..."
    val.Parent = f

    return val
end

local StatusVal = makeRow(0,   "Trạng thái")
local CountVal  = makeRow(40,  "Số người hiện tại")
local AutoVal   = makeRow(80,  "AUTO")
local QueueVal  = makeRow(120, "Queue")

local StatusLine = Instance.new("TextLabel")
StatusLine.BackgroundTransparency = 1
StatusLine.Size = UDim2.new(1, 0, 0, 44)
StatusLine.Position = UDim2.new(0, 0, 0, 164)
StatusLine.Font = Enum.Font.Gotham
StatusLine.TextSize = 12
StatusLine.TextColor3 = Color3.fromRGB(200, 180, 255)
StatusLine.TextWrapped = true
StatusLine.TextXAlignment = Enum.TextXAlignment.Left
StatusLine.TextYAlignment = Enum.TextYAlignment.Top
StatusLine.Text = "Đang khởi động..."
StatusLine.Parent = Body

-- Nút
local BtnHolder = Instance.new("Frame")
BtnHolder.BackgroundTransparency = 1
BtnHolder.Size = UDim2.new(1, -24, 0, 40)
BtnHolder.Position = UDim2.new(0, 12, 1, -52)
BtnHolder.Parent = Main

local function makeBtn(text, x, w, color)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0, w, 1, 0)
    b.Position = UDim2.new(0, x, 0, 0)
    b.BackgroundColor3 = color
    b.BorderSizePixel = 0
    b.Font = Enum.Font.GothamBold
    b.TextSize = 13
    b.TextColor3 = Color3.fromRGB(255, 255, 255)
    b.Text = text
    b.AutoButtonColor = true
    b.Parent = BtnHolder
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 8)
    return b
end

local HopBtn  = makeBtn("HOP THỦ CÔNG", 0,   180, Color3.fromRGB(110, 60, 220))
local CopyBtn = makeBtn("COPY LOG",     190, 106, Color3.fromRGB(50, 50, 70))

-- ==========================================================
--  UI UPDATE
-- ==========================================================
local function updateUI()
    StatusVal.Text = State.Status
    CountVal.Text  = tostring(State.CurrentCount)

    AutoVal.Text = State.AutoOn and "ON" or "OFF"
    AutoVal.TextColor3 = State.AutoOn
        and Color3.fromRGB(80, 230, 130)
        or  Color3.fromRGB(230, 90, 90)

    if State.QueuedServer then
        QueueVal.Text = "ĐÃ SOẠN"
        QueueVal.TextColor3 = Color3.fromRGB(80, 230, 130)
    elseif State.IsScanning then
        QueueVal.Text = "ĐANG QUÉT..."
        QueueVal.TextColor3 = Color3.fromRGB(255, 200, 90)
    else
        QueueVal.Text = "TRỐNG"
        QueueVal.TextColor3 = Color3.fromRGB(200, 200, 220)
    end

    StatusLine.Text = State.Status
end

-- ==========================================================
--  API SERVER
-- ==========================================================
local function fetchServers()
    local url = string.format(
        "https://games.roblox.com/v1/games/%d/servers/Public?limit=%d&sortOrder=Asc",
        PlaceId, CONFIG.RequestLimit
    )
    local ok, res = pcall(function()
        return HttpService:JSONDecode(game:HttpGet(url))
    end)
    if ok and res and res.data then
        return res.data
    end
    return {}
end

-- ==========================================================
--  SCAN SERVER 1 NGƯỜI
-- ==========================================================
local function scanOnePersonServer()
    if State.IsScanning then return nil end
    State.IsScanning = true
    updateUI()

    local candidates = {}

    for pass = 1, CONFIG.ScanPasses do
        State.Status = string.format(
            "Đang check qua server hiện có (Pass %d/%d)...",
            pass, CONFIG.ScanPasses
        )
        updateUI()

        local servers = fetchServers()
        local found   = {}
        for _, s in ipairs(servers) do
            if s.playing == 1 and s.id ~= JobId then
                found[s.id] = s
            end
        end

        if pass == 1 then
            for id, s in pairs(found) do
                candidates[id] = { data = s, hits = 1 }
            end
        else
            local nextCand = {}
            for id, c in pairs(candidates) do
                if found[id] then
                    c.hits = c.hits + 1
                    c.data = found[id]
                    nextCand[id] = c
                end
            end
            candidates = nextCand
        end

        if pass < CONFIG.ScanPasses then
            State.Status = string.format("Đang lọc server... (%ds)", CONFIG.PassDelay)
            updateUI()
            task.wait(CONFIG.PassDelay)
        end
    end

    -- Chọn server tốt nhất: qua đủ 3 pass, FPS thấp + Ping cao
    local best = nil
    for _, c in pairs(candidates) do
        if c.hits == CONFIG.ScanPasses then
            if not best then
                best = c.data
            else
                local bf, bp = best.fps or 60, best.ping or 0
                local cf, cp = c.data.fps or 60, c.data.ping or 0
                if cf < bf or (cf == bf and cp > bp) then
                    best = c.data
                end
            end
        end
    end

    State.IsScanning = false
    if best then
        State.Status = "Đã xác định server ít người!"
        log(string.format(
            "Đã xác định server 1 người: %s (FPS=%s, Ping=%s)",
            best.id, tostring(best.fps), tostring(best.ping)
        ))
    else
        log("Không tìm thấy server 1 người ổn định")
    end
    updateUI()
    return best
end

-- ==========================================================
--  HOP
-- ==========================================================
local function hopTo(serverData)
    if not serverData or not serverData.id then return end

    State.Status = "Đang tạo cổng kết nối..."
    updateUI()
    task.wait(0.3)

    State.Status = "Đang vào server..."
    updateUI()

    log("Đang vào server: " .. serverData.id)
    local ok, err = pcall(function()
        TeleportService:TeleportToPlaceInstance(PlaceId, serverData.id, LP)
    end)
    if not ok then
        log("Lỗi teleport: " .. tostring(err))
        State.Status = "Lỗi kết nối, thử lại..."
        updateUI()
    end
end

-- ==========================================================
--  MONITOR SỐ NGƯỜI
-- ==========================================================
task.spawn(function()
    while true do
        task.wait(0.5)
        State.CurrentCount = #Players:GetPlayers()
        updateUI()
    end
end)

-- ==========================================================
--  BACKGROUND SCANNER (soạn trước server 1 người)
-- ==========================================================
task.spawn(function()
    while true do
        task.wait(2)
        if State.AutoOn
        and not State.IsScanning
        and not State.QueuedServer then
            local s = scanOnePersonServer()
            if s and s.id ~= JobId then
                State.QueuedServer = s
                log("Đã soạn server dự phòng: " .. s.id)
                updateUI()
            end
        end
    end
end)

-- ==========================================================
--  AUTO HOP LOGIC
-- ==========================================================
task.spawn(function()
    while true do
        task.wait(0.5)

        if not State.AutoOn then
            State.HopCountdown = nil
        else
            local count = #Players:GetPlayers()

            -- Case 1: chỉ mình ta → reset đếm ngược
            if count <= 1 then
                State.HopCountdown = nil

            -- Case 2: có 1 người khác vào (2 người) → nếu có queue thì hop luôn
            elseif count == 2 then
                State.HopCountdown = nil
                if State.QueuedServer then
                    local q = State.QueuedServer
                    State.QueuedServer = nil
                    log("Có người vào — hop sang server 1 người đã soạn")
                    hopTo(q)
                    task.wait(5)
                end

            -- Case 3: server đông (>= 3) → đếm ngược 3s rồi hop
            elseif count >= CONFIG.AutoHopThreshold then
                if not State.HopCountdown then
                    State.HopCountdown = tick()
                    log(string.format(
                        "Server đông (%d người) — đếm ngược %ds",
                        count, CONFIG.HopDelay
                    ))
                elseif tick() - State.HopCountdown >= CONFIG.HopDelay then
                    State.HopCountdown = nil
                    if #Players:GetPlayers() >= CONFIG.AutoHopThreshold then
                        log("Vẫn đông — tiến hành hop!")
                        local q = State.QueuedServer
                        State.QueuedServer = nil
                        if q then
                            hopTo(q)
                        else
                            local s = scanOnePersonServer()
                            if s then hopTo(s) end
                        end
                        task.wait(5)
                    else
                        log("Người đã rời — hủy hop")
                    end
                end
            end
        end
    end
end)

-- ==========================================================
--  BUTTONS
-- ==========================================================
HopBtn.MouseButton1Click:Connect(function()
    if State.IsScanning then return end
    task.spawn(function()
        local s = scanOnePersonServer()
        if s then
            hopTo(s)
        else
            State.Status = "Không tìm thấy server 1 người"
            updateUI()
        end
    end)
end)

CopyBtn.MouseButton1Click:Connect(function()
    local text = table.concat(State.Log, "\n")
    if setclipboard then
        setclipboard(text)
        log("Đã copy log vào clipboard")
    end
end)

-- ==========================================================
--  KHỞI ĐỘNG
-- ==========================================================
log("⚡ PHANTOM " .. CONFIG.Version .. " đã khởi động — AUTO: ON")
State.Status = "Đang check qua server hiện có..."
updateUI()

-- Auto scan ngay khi load
task.spawn(function()
    task.wait(1)
    local s = scanOnePersonServer()
    if s and s.id ~= JobId then
        State.QueuedServer = s
        updateUI()
    end
end)

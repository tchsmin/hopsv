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
    AutoHopDelay = 8,
    MonitorInterval = 1,
}

local Blacklist = {}
local IsScanning = false
local IsHopping = false
local LoaderActive = false
local loaderCoroutine = nil
local AutoHopEnabled = true
local CurrentTargetPlayers = nil
local MonitorConn = nil

if CoreGui:FindFirstChild("HopUI") then CoreGui.HopUI:Destroy() end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "HopUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.IgnoreGuiInset = true
ScreenGui.DisplayOrder = 999999
ScreenGui.Parent = CoreGui

local Main = Instance.new("Frame")
Main.Size = UDim2.new(0, 220, 0, 130)
Main.Position = UDim2.new(0, 20, 0.5, -65)
Main.BackgroundColor3 = Color3.fromRGB(18, 20, 28)
Main.BorderSizePixel = 0
Main.Active = true
Main.Parent = ScreenGui

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 10)
MainCorner.Parent = Main

local MainStroke = Instance.new("UIStroke")
MainStroke.Color = Color3.fromRGB(60, 200, 130)
MainStroke.Thickness = 1
MainStroke.Transparency = 0.4
MainStroke.Parent = Main

local StatusDot = Instance.new("Frame")
StatusDot.Size = UDim2.new(0, 8, 0, 8)
StatusDot.Position = UDim2.new(1, -16, 0, 12)
StatusDot.BackgroundColor3 = Color3.fromRGB(60, 200, 100)
StatusDot.BorderSizePixel = 0
StatusDot.Parent = Main

local DotCorner = Instance.new("UICorner")
DotCorner.CornerRadius = UDim.new(1, 0)
DotCorner.Parent = StatusDot

local StatusLabel = Instance.new("TextLabel")
StatusLabel.Size = UDim2.new(1, -30, 0, 16)
StatusLabel.Position = UDim2.new(0, 10, 0, 10)
StatusLabel.BackgroundTransparency = 1
StatusLabel.Text = "Đang khởi động"
StatusLabel.TextColor3 = Color3.fromRGB(220, 230, 255)
StatusLabel.Font = Enum.Font.GothamBold
StatusLabel.TextSize = 11
StatusLabel.TextXAlignment = Enum.TextXAlignment.Left
StatusLabel.Parent = Main

local InfoLabel = Instance.new("TextLabel")
InfoLabel.Size = UDim2.new(1, -20, 0, 16)
InfoLabel.Position = UDim2.new(0, 10, 0, 30)
InfoLabel.BackgroundTransparency = 1
InfoLabel.Text = "0 người · chờ"
InfoLabel.TextColor3 = Color3.fromRGB(140, 180, 220)
InfoLabel.Font = Enum.Font.Code
InfoLabel.TextSize = 10
InfoLabel.TextXAlignment = Enum.TextXAlignment.Left
InfoLabel.Parent = Main

local CurrentLabel = Instance.new("TextLabel")
CurrentLabel.Size = UDim2.new(1, -20, 0, 14)
CurrentLabel.Position = UDim2.new(0, 10, 0, 48)
CurrentLabel.BackgroundTransparency = 1
CurrentLabel.Text = "Mục tiêu: 1 người (2/2)"
CurrentLabel.TextColor3 = Color3.fromRGB(120, 220, 180)
CurrentLabel.Font = Enum.Font.Code
CurrentLabel.TextSize = 9
CurrentLabel.TextXAlignment = Enum.TextXAlignment.Left
CurrentLabel.Parent = Main

local Btn = Instance.new("TextButton")
Btn.Size = UDim2.new(1, -20, 0, 30)
Btn.Position = UDim2.new(0, 10, 0, 68)
Btn.BackgroundColor3 = Color3.fromRGB(60, 180, 120)
Btn.Text = "HOP"
Btn.TextColor3 = Color3.fromRGB(255, 255, 255)
Btn.Font = Enum.Font.GothamBold
Btn.TextSize = 13
Btn.AutoButtonColor = false
Btn.Parent = Main

local BtnCorner = Instance.new("UICorner")
BtnCorner.CornerRadius = UDim.new(0, 6)
BtnCorner.Parent = Btn

local AutoBtn = Instance.new("TextButton")
AutoBtn.Size = UDim2.new(1, -20, 0, 24)
AutoBtn.Position = UDim2.new(0, 10, 0, 102)
AutoBtn.BackgroundColor3 = Color3.fromRGB(60, 140, 200)
AutoBtn.Text = "AUTO HOP: ON"
AutoBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
AutoBtn.Font = Enum.Font.GothamBold
AutoBtn.TextSize = 11
AutoBtn.AutoButtonColor = false
AutoBtn.Parent = Main

local AutoCorner = Instance.new("UICorner")
AutoCorner.CornerRadius = UDim.new(0, 6)
AutoCorner.Parent = AutoBtn

local SPINNER = {"|", "/", "-", "\\"}
local spinIndex = 1

local function setStatus(text, color)
    StatusLabel.Text = text
    StatusLabel.TextColor3 = color or Color3.fromRGB(220, 230, 255)
end

local function setInfo(text, color)
    InfoLabel.Text = text
    InfoLabel.TextColor3 = color or Color3.fromRGB(140, 180, 220)
end

local function setCurrent(text, color)
    CurrentLabel.Text = text
    CurrentLabel.TextColor3 = color or Color3.fromRGB(120, 220, 180)
end

local function setDot(state)
    if state == "active" then
        StatusDot.BackgroundColor3 = Color3.fromRGB(60, 200, 100)
        MainStroke.Color = Color3.fromRGB(60, 200, 130)
    elseif state == "scanning" then
        StatusDot.BackgroundColor3 = Color3.fromRGB(255, 200, 100)
        MainStroke.Color = Color3.fromRGB(255, 180, 100)
    elseif state == "hopping" then
        StatusDot.BackgroundColor3 = Color3.fromRGB(255, 140, 60)
        MainStroke.Color = Color3.fromRGB(255, 140, 60)
    elseif state == "error" then
        StatusDot.BackgroundColor3 = Color3.fromRGB(255, 100, 100)
        MainStroke.Color = Color3.fromRGB(200, 60, 60)
    end
end

task.spawn(function()
    while ScreenGui.Parent do
        spinIndex = spinIndex + 1
        if spinIndex > #SPINNER then spinIndex = 1 end
        if IsScanning and not IsHopping then
            StatusLabel.Text = "Đang quét " .. SPINNER[spinIndex]
        end
        task.wait(0.1)
    end
end)

local function updatePlayerCount()
    local count = #Players:GetPlayers()
    setInfo(count .. " người trong server", count <= 2 and Color3.fromRGB(120, 255, 160) or Color3.fromRGB(255, 180, 120))
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

local function setAutoHop(enabled)
    AutoHopEnabled = enabled
    if enabled then
        AutoBtn.Text = "AUTO HOP: ON"
        AutoBtn.BackgroundColor3 = Color3.fromRGB(60, 140, 200)
    else
        AutoBtn.Text = "AUTO HOP: OFF"
        AutoBtn.BackgroundColor3 = Color3.fromRGB(90, 90, 100)
    end
end

AutoBtn.MouseButton1Click:Connect(function()
    setAutoHop(not AutoHopEnabled)
end)

local function performHop()
    if IsScanning or IsHopping then return end
    IsScanning = true
    setDot("scanning")
    setStatus("Đang quét server 1 người")
    setCurrent("Mục tiêu: 1 người (2/2)", Color3.fromRGB(120, 220, 180))

    if not http then
        IsScanning = false
        setDot("error")
        setStatus("Không có HTTP", Color3.fromRGB(255, 100, 100))
        return
    end

    local target = scanForTarget(1)
    local mode = "1 người (2/2)"

    if not target then
        setStatus("Không có server 1 ng · quét 2 ng", Color3.fromRGB(255, 200, 100))
        setCurrent("Mục tiêu: 2 người (3/3)", Color3.fromRGB(255, 200, 120))
        target = scanForTarget(2)
        mode = "2 người (3/3)"
    end

    if not target then
        IsScanning = false
        setDot("error")
        setStatus("Không có server", Color3.fromRGB(255, 100, 100))
        task.wait(5)
        return
    end

    setDot("hopping")
    setStatus("Vào server " .. mode)
    setInfo(target.playing .. " ng · FPS" .. target.fps .. " · P" .. target.ping, Color3.fromRGB(120, 255, 160))
    setCurrent("Đang vào: " .. mode, Color3.fromRGB(120, 220, 180))

    task.wait(CONFIG.PreTeleportDelay)

    IsScanning = false
    IsHopping = true
    Blacklist[target.id] = true
    CurrentTargetPlayers = target.playing + 1

    fastTeleport(target.id)

    task.wait(3)
    IsHopping = false
end

Btn.MouseButton1Click:Connect(function()
    task.spawn(performHop)
end)

local lastPlayerCount = 0

local function startMonitor()
    if MonitorConn then MonitorConn:Disconnect() end
    MonitorConn = RunService.Heartbeat:Connect(function()
        if not AutoHopEnabled then return end
        if IsHopping or IsScanning then return end

        local count = #Players:GetPlayers()
        if count == lastPlayerCount then return end
        lastPlayerCount = count

        if CurrentTargetPlayers then
            if count > CurrentTargetPlayers then
                setDot("scanning")
                setStatus("Có người vào · chờ " .. CONFIG.AutoHopDelay .. "s", Color3.fromRGB(255, 180, 100))

                task.spawn(function()
                    for i = CONFIG.AutoHopDelay, 1, -1 do
                        if not AutoHopEnabled then return end
                        local cnt = #Players:GetPlayers()
                        if cnt <= CurrentTargetPlayers then
                            setDot("active")
                            setStatus("Người đó đã rời", Color3.fromRGB(120, 255, 160))
                            return
                        end
                        setStatus("Hop sau " .. i .. "s · " .. cnt .. " người", Color3.fromRGB(255, 180, 100))
                        task.wait(1)
                    end

                    if #Players:GetPlayers() > CurrentTargetPlayers then
                        setStatus("Auto hop", Color3.fromRGB(255, 150, 100))
                        performHop()
                    end
                end)
            end
        else
            if count >= 2 and not IsScanning and not IsHopping then
                task.spawn(performHop)
            end
        end
    end)
end

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

setDot("active")
setStatus("Sẵn sàng")
setInfo("0 người · chờ")
setCurrent("Mục tiêu: 1 người (2/2)")
updatePlayerCount()
startMonitor()

task.spawn(function()
    task.wait(2)
    if #Players:GetPlayers() >= 2 then
        performHop()
    else
        setStatus("Đang chờ có người vào")
    end
end)

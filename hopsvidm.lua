local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local PLACE_ID = game.PlaceId
local JOB_ID = game.JobId

local MIN_TOTAL_PLAYERS = 3
local MAX_PAGES = 15

local function getHttp()
    if syn and syn.request then return syn.request end
    if http_request then return http_request end
    if request then return request end
    if fluxus and fluxus.request then return fluxus.request end
    if krnl and krnl.request then return krnl.request end
    if http and http.request then return http.request end
    if HttpGet then
        return function(opts) return { Body = HttpGet(opts.Url), StatusCode = 200 } end
    end
    if game.HttpGet then
        return function(opts) return { Body = game:HttpGet(opts.Url), StatusCode = 200 } end
    end
    return nil
end

local http = getHttp()

local function getUIParent()
    local ok, cg = pcall(function() return game:GetService("CoreGui") end)
    if ok and cg then
        local ok2 = pcall(function() return cg:FindFirstChild("RobloxGui") end)
        if ok2 then return cg end
    end
    if gethui then
        local ok3, hui = pcall(gethui)
        if ok3 and hui then return hui end
    end
    return LocalPlayer:WaitForChild("PlayerGui")
end

local UIParent = getUIParent()

pcall(function()
    local old = UIParent:FindFirstChild("AutoHopUI")
    if old then old:Destroy() end
end)

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "AutoHopUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.IgnoreGuiInset = true
ScreenGui.DisplayOrder = 999999
ScreenGui.Parent = UIParent

local Main = Instance.new("Frame")
Main.Size = UDim2.new(0, 260, 0, 100)
Main.Position = UDim2.new(0, 20, 0.5, -50)
Main.BackgroundColor3 = Color3.fromRGB(18, 20, 28)
Main.BorderSizePixel = 0
Main.Parent = ScreenGui

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 10)
MainCorner.Parent = Main

local Stroke = Instance.new("UIStroke")
Stroke.Color = Color3.fromRGB(60, 200, 130)
Stroke.Thickness = 1.5
Stroke.Transparency = 0.3
Stroke.Parent = Main

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Size = UDim2.new(1, -20, 0, 18)
TitleLabel.Position = UDim2.new(0, 10, 0, 8)
TitleLabel.BackgroundTransparency = 1
TitleLabel.Text = "AUTO HOP"
TitleLabel.TextColor3 = Color3.fromRGB(120, 255, 180)
TitleLabel.Font = Enum.Font.GothamBold
TitleLabel.TextSize = 11
TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
TitleLabel.Parent = Main

local PlayerCountLabel = Instance.new("TextLabel")
PlayerCountLabel.Size = UDim2.new(1, -20, 0, 18)
PlayerCountLabel.Position = UDim2.new(0, 10, 0, 28)
PlayerCountLabel.BackgroundTransparency = 1
PlayerCountLabel.Text = "Server: 1 người"
PlayerCountLabel.TextColor3 = Color3.fromRGB(140, 220, 180)
PlayerCountLabel.Font = Enum.Font.Code
PlayerCountLabel.TextSize = 10
PlayerCountLabel.TextXAlignment = Enum.TextXAlignment.Left
PlayerCountLabel.Parent = Main

local StatusLabel = Instance.new("TextLabel")
StatusLabel.Size = UDim2.new(1, -20, 0, 18)
StatusLabel.Position = UDim2.new(0, 10, 0, 50)
StatusLabel.BackgroundTransparency = 1
StatusLabel.Text = "Đang khởi động..."
StatusLabel.TextColor3 = Color3.fromRGB(200, 220, 255)
StatusLabel.Font = Enum.Font.GothamBold
StatusLabel.TextSize = 11
StatusLabel.TextXAlignment = Enum.TextXAlignment.Left
StatusLabel.Parent = Main

local InfoLabel = Instance.new("TextLabel")
InfoLabel.Size = UDim2.new(1, -20, 0, 18)
InfoLabel.Position = UDim2.new(0, 10, 0, 72)
InfoLabel.BackgroundTransparency = 1
InfoLabel.Text = "Sẵn sàng"
InfoLabel.TextColor3 = Color3.fromRGB(140, 180, 220)
InfoLabel.Font = Enum.Font.Code
InfoLabel.TextSize = 9
InfoLabel.TextXAlignment = Enum.TextXAlignment.Left
InfoLabel.Parent = Main

local dragStart, startPos, dragging

TitleLabel.InputBegan:Connect(function(input)
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

local SPINNER = {"|", "/", "-", "\\"}
local SpinActive = false
local SpinThread = nil
local BaseText = ""

local function startSpin(text)
    BaseText = text
    if SpinThread then pcall(function() task.cancel(SpinThread) end) end
    SpinActive = true
    SpinThread = task.spawn(function()
        local i = 1
        while SpinActive do
            StatusLabel.Text = BaseText .. " " .. SPINNER[i]
            i = i + 1
            if i > #SPINNER then i = 1 end
            task.wait(0.15)
        end
    end)
end

local function setStatus(text, color)
    SpinActive = false
    if SpinThread then pcall(function() task.cancel(SpinThread) end) end
    StatusLabel.Text = text
    if color then StatusLabel.TextColor3 = color end
end

local function setInfo(text, color)
    InfoLabel.Text = text
    if color then InfoLabel.TextColor3 = color end
end

local function getTotalPlayers()
    return #Players:GetPlayers()
end

local function getOthers()
    return getTotalPlayers() - 1
end

local function updatePlayerCount()
    local total = getTotalPlayers()
    local others = getOthers()
    PlayerCountLabel.Text = "Server: " .. total .. " người (" .. others .. " khác)"

    if total >= MIN_TOTAL_PLAYERS then
        PlayerCountLabel.TextColor3 = Color3.fromRGB(255, 150, 100)
    elseif total == 2 then
        PlayerCountLabel.TextColor3 = Color3.fromRGB(255, 220, 120)
    else
        PlayerCountLabel.TextColor3 = Color3.fromRGB(140, 220, 180)
    end
end

Players.PlayerAdded:Connect(function()
    task.wait(0.3)
    updatePlayerCount()
end)

Players.PlayerRemoving:Connect(function()
    task.wait(0.3)
    updatePlayerCount()
end)

updatePlayerCount()

local Blacklist = {}

local function requestPage(cursor)
    if not http then return nil end
    local url = string.format(
        "https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100&cursor=%s",
        PLACE_ID, cursor or ""
    )
    for attempt = 1, 3 do
        local ok, res = pcall(function()
            return http({ Url = url, Method = "GET", Headers = { ["Accept"] = "application/json" } })
        end)
        if ok and res then
            local body = res.Body or res.body
            if type(body) == "string" and #body > 0 then
                local ok2, data = pcall(function()
                    return HttpService:JSONDecode(body)
                end)
                if ok2 and type(data) == "table" and data.data then
                    return data
                end
            end
        end
        task.wait(0.4 * attempt)
    end
    return nil
end

local function findBestServer()
    local candidates = {}
    local cursor = ""
    local pages = 0
    local totalScanned = 0

    while pages < MAX_PAGES do
        local data = requestPage(cursor)
        if not data or type(data.data) ~= "table" then break end

        local cnt = 0
        for _, s in ipairs(data.data) do
            if type(s) == "table" then
                cnt = cnt + 1
                totalScanned = totalScanned + 1
                local pc = tonumber(s.playing) or 0
                local id = s.id
                if type(id) == "string" and id ~= JOB_ID
                    and pc >= 1 and pc <= 2
                    and not Blacklist[id] then
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

        setInfo("Quét: " .. totalScanned .. " | Ứng viên: " .. #candidates)
        task.wait(0.1)
    end

    if #candidates == 0 then return nil, totalScanned end

    table.sort(candidates, function(a, b)
        if a.playing ~= b.playing then return a.playing < b.playing end
        if a.fps ~= b.fps then return a.fps < b.fps end
        return a.ping > b.ping
    end)

    return candidates[1], totalScanned
end

local function teleport(target)
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
end

local function mainLoop()
    if not http then
        setStatus("Không có HTTP!", Color3.fromRGB(255, 100, 100))
        setInfo("Executor không hỗ trợ HTTP")
        return
    end

    task.wait(1)
    setStatus("Đang theo dõi...", Color3.fromRGB(180, 200, 255))

    while true do
        local total = getTotalPlayers()
        local others = getOthers()
        updatePlayerCount()

        if total < MIN_TOTAL_PLAYERS then
            setStatus("Chờ đủ " .. MIN_TOTAL_PLAYERS .. " người (" .. total .. "/" .. MIN_TOTAL_PLAYERS .. ")", Color3.fromRGB(140, 200, 255))
            setInfo("Cần " .. (MIN_TOTAL_PLAYERS - 1) .. " người khác + bạn")
            task.wait(1)
        else
            startSpin("Đang quét server")
            setInfo("Server có " .. others .. " người khác · Đang tìm server 1-2 người")

            local target, scanned = findBestServer()

            if not target then
                setStatus("Không có server 1-2 người", Color3.fromRGB(255, 150, 100))
                setInfo("Đã quét: " .. tostring(scanned) .. " | Chờ 3s")
                task.wait(3)
            else
                setStatus("Vào " .. target.playing .. " ng · FPS" .. target.fps .. " · P" .. target.ping,
                    Color3.fromRGB(120, 255, 160))
                setInfo("Đã quét: " .. tostring(scanned) .. " | Đang teleport")
                task.wait(0.8)
                Blacklist[target.id] = true
                teleport(target)
                task.wait(10)
            end
        end
    end
end

task.spawn(mainLoop)

local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local CoreGui = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")

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
local IsRunning = true
local IsHopping = false

if CoreGui:FindFirstChild("PhantomUI") then CoreGui.PhantomUI:Destroy() end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "PhantomUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.IgnoreGuiInset = true
ScreenGui.DisplayOrder = 999999
ScreenGui.Parent = CoreGui

local Main = Instance.new("Frame")
Main.Size = UDim2.new(0, 220, 0, 110)
Main.Position = UDim2.new(0, 20, 0.5, -55)
Main.BackgroundColor3 = Color3.fromRGB(15, 17, 24)
Main.BorderSizePixel = 0
Main.Active = true
Main.Parent = ScreenGui

local MC = Instance.new("UICorner")
MC.CornerRadius = UDim.new(0, 14)
MC.Parent = Main

local Border = Instance.new("UIStroke")
Border.Thickness = 1.5
Border.Transparency = 0.2
Border.Parent = Main

local BGrad = Instance.new("UIGradient")
BGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(120, 80, 255)),
    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(80, 180, 255)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 100, 255))
})
BGrad.Rotation = 45
BGrad.Parent = Border

task.spawn(function()
    while ScreenGui.Parent do
        BGrad.Rotation = BGrad.Rotation + 2
        task.wait(0.05)
    end
end)

local TopBar = Instance.new("Frame")
TopBar.Size = UDim2.new(1, 0, 0, 36)
TopBar.BackgroundTransparency = 1
TopBar.Parent = Main

local LogoBox = Instance.new("Frame")
LogoBox.Size = UDim2.new(0, 26, 0, 26)
LogoBox.Position = UDim2.new(0, 12, 0, 5)
LogoBox.BackgroundColor3 = Color3.fromRGB(40, 30, 70)
LogoBox.BorderSizePixel = 0
LogoBox.Parent = TopBar

local LBC = Instance.new("UICorner")
LBC.CornerRadius = UDim.new(0, 8)
LBC.Parent = LogoBox

local LBG = Instance.new("UIGradient")
LBG.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(120, 80, 255)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(60, 180, 255))
})
LBG.Rotation = 45
LBG.Parent = LogoBox

local LogoIcon = Instance.new("TextLabel")
LogoIcon.Size = UDim2.new(1, 0, 1, 0)
LogoIcon.BackgroundTransparency = 1
LogoIcon.Text = "⚡"
LogoIcon.TextColor3 = Color3.fromRGB(255, 255, 255)
LogoIcon.Font = Enum.Font.GothamBold
LogoIcon.TextSize = 14
LogoIcon.Parent = LogoBox

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, -120, 0, 16)
Title.Position = UDim2.new(0, 44, 0, 8)
Title.BackgroundTransparency = 1
Title.Text = "PHANTOM"
Title.TextColor3 = Color3.fromRGB(240, 245, 255)
Title.Font = Enum.Font.GothamBold
Title.TextSize = 12
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = TopBar

local Sub = Instance.new("TextLabel")
Sub.Size = UDim2.new(1, -120, 0, 11)
Sub.Position = UDim2.new(0, 44, 0, 22)
Sub.BackgroundTransparency = 1
Sub.Text = "auto hop"
Sub.TextColor3 = Color3.fromRGB(130, 140, 180)
Sub.Font = Enum.Font.Gotham
Sub.TextSize = 8
Sub.TextXAlignment = Enum.TextXAlignment.Left
Sub.Parent = TopBar

local Pill = Instance.new("Frame")
Pill.Size = UDim2.new(0, 56, 0, 20)
Pill.Position = UDim2.new(1, -68, 0, 8)
Pill.BackgroundColor3 = Color3.fromRGB(24, 40, 30)
Pill.BorderSizePixel = 0
Pill.Parent = TopBar

local PC = Instance.new("UICorner")
PC.CornerRadius = UDim.new(1, 0)
PC.Parent = Pill

local PS = Instance.new("UIStroke")
PS.Color = Color3.fromRGB(60, 220, 120)
PS.Thickness = 1
PS.Transparency = 0.3
PS.Parent = Pill

local PDot = Instance.new("Frame")
PDot.Size = UDim2.new(0, 6, 0, 6)
PDot.Position = UDim2.new(0, 8, 0.5, -3)
PDot.BackgroundColor3 = Color3.fromRGB(60, 220, 120)
PDot.BorderSizePixel = 0
PDot.Parent = Pill

local PDC = Instance.new("UICorner")
PDC.CornerRadius = UDim.new(1, 0)
PDC.Parent = PDot

local PText = Instance.new("TextLabel")
PText.Size = UDim2.new(1, -18, 1, 0)
PText.Position = UDim2.new(0, 18, 0, 0)
PText.BackgroundTransparency = 1
PText.Text = "ON"
PText.TextColor3 = Color3.fromRGB(140, 255, 180)
PText.Font = Enum.Font.GothamBold
PText.TextSize = 9
PText.TextXAlignment = Enum.TextXAlignment.Left
PText.Parent = Pill

local Div = Instance.new("Frame")
Div.Size = UDim2.new(1, -24, 0, 1)
Div.Position = UDim2.new(0, 12, 0, 40)
Div.BackgroundColor3 = Color3.fromRGB(30, 34, 48)
Div.BorderSizePixel = 0
Div.Parent = Main

local InfoCard = Instance.new("Frame")
InfoCard.Size = UDim2.new(1, -24, 0, 38)
InfoCard.Position = UDim2.new(0, 12, 0, 48)
InfoCard.BackgroundColor3 = Color3.fromRGB(20, 23, 32)
InfoCard.BorderSizePixel = 0
InfoCard.Parent = Main

local ICC = Instance.new("UICorner")
ICC.CornerRadius = UDim.new(0, 8)
ICC.Parent = InfoCard

local InfoLeft = Instance.new("TextLabel")
InfoLeft.Size = UDim2.new(0.5, -8, 1, 0)
InfoLeft.Position = UDim2.new(0, 10, 0, 0)
InfoLeft.BackgroundTransparency = 1
InfoLeft.Text = "👥 0"
InfoLeft.TextColor3 = Color3.fromRGB(120, 255, 160)
InfoLeft.Font = Enum.Font.GothamBold
InfoLeft.TextSize = 14
InfoLeft.TextXAlignment = Enum.TextXAlignment.Left
InfoLeft.Parent = InfoCard

local InfoRight = Instance.new("TextLabel")
InfoRight.Size = UDim2.new(0.5, -8, 1, 0)
InfoRight.Position = UDim2.new(0.5, 0, 0, 0)
InfoRight.BackgroundTransparency = 1
InfoRight.Text = "🎯 0"
InfoRight.TextColor3 = Color3.fromRGB(255, 200, 120)
InfoRight.Font = Enum.Font.GothamBold
InfoRight.TextSize = 13
InfoRight.TextXAlignment = Enum.TextXAlignment.Right
InfoRight.Parent = InfoCard

local StatusText = Instance.new("TextLabel")
StatusText.Size = UDim2.new(1, -24, 0, 18)
StatusText.Position = UDim2.new(0, 12, 0, 90)
StatusText.BackgroundTransparency = 1
StatusText.Text = "Đang chạy"
StatusText.TextColor3 = Color3.fromRGB(180, 200, 230)
StatusText.Font = Enum.Font.GothamBold
StatusText.TextSize = 10
StatusText.TextXAlignment = Enum.TextXAlignment.Left
StatusText.Parent = Main

local function setStatus(text, color)
    StatusText.Text = text
    if color then StatusText.TextColor3 = color end
end

local function setPill(text, color)
    PText.Text = text
    if color then
        PText.TextColor3 = color
        PDot.BackgroundColor3 = color
        PS.Color = color
    end
end

local function updatePlayerCount()
    local c = #Players:GetPlayers()
    InfoLeft.Text = "👥 " .. c
    InfoLeft.TextColor3 = c <= 2 and Color3.fromRGB(120, 255, 160) or Color3.fromRGB(255, 120, 120)
    return c
end

Players.PlayerAdded:Connect(function() task.wait(0.2) updatePlayerCount() end)
Players.PlayerRemoving:Connect(function() task.wait(0.4) updatePlayerCount() end)

-- ============ V13 CORE ============
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

    while pages < maxPages do
        local data = requestPage(cursor)
        if not data or not data.data then break end
        local cnt = 0
        for _, s in ipairs(data.data) do
            cnt = cnt + 1
            local pc = s.playing or 0
            local id = s.id
            if pc >= 1 and pc <= maxPlayers then
                if id ~= JOB_ID and not Blacklist[id] then
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
        task.wait(0.02)
    end

    return result
end

local function calculateScore(server, stabilityBonus)
    local playerScore = 0
    if server.playing == 1 then
        playerScore = 100
    elseif server.playing == 2 then
        playerScore = 40
    elseif server.playing == 3 then
        playerScore = 10
    end

    local fpsScore = math.max(0, 60 - server.fps) * 1.5
    local pingScore = math.min(server.ping, 500) / 5
    local stabilityScore = stabilityBonus * 60

    return playerScore + fpsScore + pingScore + stabilityScore
end

function doHop()
    setStatus("Đang dò server...", Color3.fromRGB(255, 200, 100))
    setPill("SCAN", Color3.fromRGB(255, 200, 120))

    if not http then
        setStatus("Lỗi HTTP", Color3.fromRGB(255, 100, 100))
        setPill("OFF", Color3.fromRGB(255, 100, 100))
        return false
    end

    local pass1 = scanPass(2, 12)

    local count1 = 0
    for _ in pairs(pass1) do count1 = count1 + 1 end

    InfoRight.Text = "🎯 " .. count1

    if count1 == 0 then
        setStatus("Không có server!", Color3.fromRGB(255, 120, 120))
        setPill("FAIL", Color3.fromRGB(255, 120, 120))
        return false
    end

    setStatus("Pass 1: " .. count1 .. " · phân tích", Color3.fromRGB(255, 200, 100))
    task.wait(2.5)

    local pass2 = scanPass(2, 12)

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

    setStatus("Xác nhận...", Color3.fromRGB(255, 200, 100))
    task.wait(1.5)

    local finalPool = {}
    for _, s in ipairs(stable) do
        local total = calculateScore(s, s.stability)
        s.score = total
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
    if #pickFrom == 0 then
        pickFrom = finalPool
    end

    local topCount = math.min(3, #pickFrom)
    if topCount == 0 then
        setStatus("Không có server!", Color3.fromRGB(255, 120, 120))
        setPill("FAIL", Color3.fromRGB(255, 120, 120))
        return false
    end

    local target = pickFrom[math.random(1, topCount)]

    setStatus("Vào " .. target.playing .. " ng · FPS" .. target.fps, Color3.fromRGB(120, 255, 160))
    setPill("HOP", Color3.fromRGB(120, 255, 160))

    Blacklist[target.id] = true

    task.wait(0.5)

    local ok = pcall(function()
        TeleportService:TeleportToPlaceInstance(PLACE_ID, target.id, LocalPlayer)
    end)

    if not ok then
        setStatus("Teleport fail", Color3.fromRGB(255, 100, 100))
        setPill("FAIL", Color3.fromRGB(255, 100, 100))
        return false
    end

    return true
end

-- ============ MAIN LOOP ============
local function mainLoop()
    task.wait(1)

    while IsRunning and ScreenGui.Parent do
        local count = updatePlayerCount()

        if count <= 1 then
            setStatus("Server " .. count .. " ng · chờ", Color3.fromRGB(120, 255, 160))
            setPill("ON", Color3.fromRGB(60, 220, 120))

            for _ = 1, 30 do
                if not ScreenGui.Parent then return end
                task.wait(1)
                count = #Players:GetPlayers()
                updatePlayerCount()
                if count > 1 then break end
            end

            if count <= 1 then
                continue
            end
        end

        for i = 3, 1, -1 do
            if not ScreenGui.Parent then return end
            local cnt = #Players:GetPlayers()
            if cnt <= 1 then
                setStatus("Người rời · hủy", Color3.fromRGB(120, 255, 160))
                setPill("ON", Color3.fromRGB(60, 220, 120))
                break
            end
            setStatus("Hop sau " .. i .. "s · " .. cnt .. " ng", Color3.fromRGB(255, 200, 100))
            setPill("WAIT", Color3.fromRGB(255, 180, 100))
            task.wait(1)
        end

        if #Players:GetPlayers() <= 1 then
            continue
        end

        local hopped = false

        while not hopped and ScreenGui.Parent do
            local ok = doHop()

            if ok then
                hopped = true
                task.wait(3)
            else
                Blacklist = {}
                setStatus("Thử lại sau 2s...", Color3.fromRGB(255, 150, 100))
                setPill("WAIT", Color3.fromRGB(255, 180, 100))
                task.wait(2)
            end
        end
    end
end

local dragging, dragStart, startPos
TopBar.InputBegan:Connect(function(input)
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
setStatus("Đang chạy", Color3.fromRGB(120, 255, 160))
setPill("ON", Color3.fromRGB(60, 220, 120))

task.spawn(mainLoop)

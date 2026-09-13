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
local IsScanning = false
local IsDragging = false
local DragStartTime = 0
local DragStartPos = nil
local BtnStartPos = nil
local MovedDistance = 0

if CoreGui:FindFirstChild("HopButton") then CoreGui.HopButton:Destroy() end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "HopButton"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.IgnoreGuiInset = true
ScreenGui.DisplayOrder = 999999
ScreenGui.Parent = CoreGui

local Container = Instance.new("Frame")
Container.Size = UDim2.new(0, 220, 0, 130)
Container.Position = UDim2.new(0, 20, 0.5, -65)
Container.BackgroundTransparency = 1
Container.Active = false
Container.Parent = ScreenGui

local Btn = Instance.new("TextButton")
Btn.Size = UDim2.new(0, 85, 0, 85)
Btn.Position = UDim2.new(0.5, -42, 0, 0)
Btn.BackgroundColor3 = Color3.fromRGB(60, 180, 120)
Btn.Text = "HOP"
Btn.TextColor3 = Color3.fromRGB(255, 255, 255)
Btn.Font = Enum.Font.GothamBold
Btn.TextSize = 18
Btn.AutoButtonColor = false
Btn.Active = true
Btn.Parent = Container

local BtnCorner = Instance.new("UICorner")
BtnCorner.CornerRadius = UDim.new(1, 0)
BtnCorner.Parent = Btn

local BtnStroke = Instance.new("UIStroke")
BtnStroke.Color = Color3.fromRGB(255, 255, 255)
BtnStroke.Thickness = 2
BtnStroke.Transparency = 0.4
BtnStroke.Parent = Btn

local CounterLabel = Instance.new("TextLabel")
CounterLabel.Size = UDim2.new(1, 0, 0, 22)
CounterLabel.Position = UDim2.new(0, 0, 0, 88)
CounterLabel.BackgroundColor3 = Color3.fromRGB(20, 22, 30)
CounterLabel.BackgroundTransparency = 0.15
CounterLabel.BorderSizePixel = 0
CounterLabel.Text = "0 / 1000"
CounterLabel.TextColor3 = Color3.fromRGB(200, 220, 255)
CounterLabel.Font = Enum.Font.GothamBold
CounterLabel.TextSize = 12
CounterLabel.Parent = Container

local CounterCorner = Instance.new("UICorner")
CounterCorner.CornerRadius = UDim.new(0, 6)
CounterCorner.Parent = CounterLabel

local StatusLabel = Instance.new("TextLabel")
StatusLabel.Size = UDim2.new(1, 0, 0, 20)
StatusLabel.Position = UDim2.new(0, 0, 0, 111)
StatusLabel.BackgroundColor3 = Color3.fromRGB(20, 22, 30)
StatusLabel.BackgroundTransparency = 0.2
StatusLabel.BorderSizePixel = 0
StatusLabel.Text = "San sang"
StatusLabel.TextColor3 = Color3.fromRGB(200, 220, 255)
StatusLabel.Font = Enum.Font.Gotham
StatusLabel.TextSize = 11
StatusLabel.Parent = Container

local StatusCorner = Instance.new("UICorner")
StatusCorner.CornerRadius = UDim.new(0, 6)
StatusCorner.Parent = StatusLabel

local function setBtnColor(color)
    Btn.BackgroundColor3 = color
end

local function resetDragState()
    IsDragging = false
    DragStartPos = nil
    BtnStartPos = nil
    MovedDistance = 0
end

Btn.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        IsDragging = true
        DragStartTime = tick()
        DragStartPos = input.Position
        BtnStartPos = Container.Position
        MovedDistance = 0
        Btn.BackgroundColor3 = Color3.fromRGB(40, 140, 90)
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if not IsDragging then return end
    if input.UserInputType ~= Enum.UserInputType.MouseMovement
        and input.UserInputType ~= Enum.UserInputType.Touch then return end
    if not DragStartPos or not BtnStartPos then return end

    local delta = input.Position - DragStartPos
    local dist = math.sqrt(delta.X * delta.X + delta.Y * delta.Y)
    if dist > MovedDistance then
        MovedDistance = dist
    end

    Container.Position = UDim2.new(
        BtnStartPos.X.Scale,
        BtnStartPos.X.Offset + delta.X,
        BtnStartPos.Y.Scale,
        BtnStartPos.Y.Offset + delta.Y
    )
end)

UserInputService.InputEnded:Connect(function(input)
    if not IsDragging then return end
    if input.UserInputType ~= Enum.UserInputType.MouseButton1
        and input.UserInputType ~= Enum.UserInputType.Touch then return end

    local wasClick = MovedDistance < 12
    local holdTime = tick() - DragStartTime

    resetDragState()
    setBtnColor(Color3.fromRGB(60, 180, 120))

    if wasClick and holdTime < 2 then
        task.spawn(function()
            local ok, err = pcall(scanAndHop)
            if not ok then
                StatusLabel.Text = "Loi: " .. tostring(err)
                StatusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
                IsScanning = false
            end
        end)
    end
end)

local function requestPage(cursor)
    if not http then return nil end
    local url = string.format(
        "https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100&cursor=%s",
        PLACE_ID, cursor or ""
    )
    local ok, res = pcall(function()
        return http({
            Url = url,
            Method = "GET",
            Headers = { ["Accept"] = "application/json" }
        })
    end)
    if not ok or not res or not res.Body then return nil end
    local ok2, data = pcall(function()
        return HttpService:JSONDecode(res.Body)
    end)
    if not ok2 or not data then return nil end
    return data
end

function scanAndHop()
    if IsScanning then return end
    IsScanning = true

    CounterLabel.Text = "0 / 1000"
    CounterLabel.TextColor3 = Color3.fromRGB(255, 220, 120)
    StatusLabel.Text = "Bat dau quet..."
    StatusLabel.TextColor3 = Color3.fromRGB(255, 200, 100)

    task.wait(0.1)

    if not http then
        StatusLabel.Text = "Loi HTTP!"
        StatusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
        CounterLabel.TextColor3 = Color3.fromRGB(200, 220, 255)
        IsScanning = false
        return
    end

    local onePlayer = {}
    local totalScanned = 0
    local cursor = ""
    local pages = 0
    local maxPages = 10

    while pages < maxPages do
        local data = requestPage(cursor)
        if not data or not data.data then break end

        local pageCount = 0
        for _, s in ipairs(data.data) do
            pageCount = pageCount + 1
            totalScanned = totalScanned + 1

            local pc = s.playing or 0
            if pc == 1 then
                local id = s.id
                if id ~= JOB_ID and not Blacklist[id] then
                    table.insert(onePlayer, {
                        id = id,
                        ping = s.ping or 999,
                        fps = s.fps or 60
                    })
                end
            end
        end

        if pageCount == 0 then break end

        CounterLabel.Text = totalScanned .. " / 1000"
        StatusLabel.Text = "Da tim: " .. #onePlayer .. " server 1 nguoi"

        cursor = data.nextPageCursor
        if not cursor or cursor == "" or cursor == "null" then break end

        pages = pages + 1
        task.wait(0.05)
    end

    if totalScanned == 0 then
        StatusLabel.Text = "Khong lay duoc du lieu!"
        StatusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
        CounterLabel.TextColor3 = Color3.fromRGB(200, 220, 255)
        IsScanning = false
        return
    end

    CounterLabel.Text = totalScanned .. " / 1000"
    CounterLabel.TextColor3 = Color3.fromRGB(120, 255, 160)

    if #onePlayer == 0 then
        StatusLabel.Text = "Khong co server 1 nguoi!"
        StatusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
        IsScanning = false
        return
    end

    table.sort(onePlayer, function(a, b)
        if a.fps ~= b.fps then
            return a.fps < b.fps
        end
        return a.ping > b.ping
    end)

    local target = onePlayer[1]
    StatusLabel.Text = "Vao FPS" .. target.fps .. " | Ping" .. target.ping
    StatusLabel.TextColor3 = Color3.fromRGB(120, 255, 160)

    task.wait(0.3)

    IsScanning = false

    local ok = pcall(function()
        TeleportService:TeleportToPlaceInstance(PLACE_ID, target.id, LocalPlayer)
    end)

    if not ok then
        Blacklist[target.id] = true
        StatusLabel.Text = "Loi teleport! Bam lai."
        StatusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
    else
        Blacklist[target.id] = true
    end
end

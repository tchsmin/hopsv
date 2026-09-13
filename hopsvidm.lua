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
local LoaderActive = false
local loaderCoroutine = nil

if CoreGui:FindFirstChild("HopUI") then CoreGui.HopUI:Destroy() end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "HopUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.IgnoreGuiInset = true
ScreenGui.DisplayOrder = 999999
ScreenGui.Parent = CoreGui

local Container = Instance.new("Frame")
Container.Size = UDim2.new(0, 180, 0, 110)
Container.Position = UDim2.new(0, 20, 0.5, -55)
Container.BackgroundTransparency = 1
Container.Parent = ScreenGui

local Btn = Instance.new("TextButton")
Btn.Size = UDim2.new(0, 80, 0, 80)
Btn.Position = UDim2.new(0.5, -40, 0, 0)
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

local StatusLabel = Instance.new("TextLabel")
StatusLabel.Size = UDim2.new(1, 0, 0, 22)
StatusLabel.Position = UDim2.new(0, 0, 0, 84)
StatusLabel.BackgroundColor3 = Color3.fromRGB(20, 22, 30)
StatusLabel.BackgroundTransparency = 0.1
StatusLabel.BorderSizePixel = 0
StatusLabel.Text = "Sẵn sàng"
StatusLabel.TextColor3 = Color3.fromRGB(200, 220, 255)
StatusLabel.Font = Enum.Font.GothamBold
StatusLabel.TextSize = 12
StatusLabel.Parent = Container

local StatusCorner = Instance.new("UICorner")
StatusCorner.CornerRadius = UDim.new(0, 6)
StatusCorner.Parent = StatusLabel

local SPINNER = {"|", "/", "-", "\\"}

local function startLoading(text)
    LoaderActive = false
    task.wait()
    LoaderActive = true
    StatusLabel.TextColor3 = Color3.fromRGB(255, 220, 120)
    loaderCoroutine = task.spawn(function()
        local i = 1
        while LoaderActive do
            StatusLabel.Text = text .. " " .. SPINNER[i]
            i = i + 1
            if i > #SPINNER then i = 1 end
            task.wait(0.15)
        end
    end)
end

local function stopLoading(finalText, color)
    LoaderActive = false
    loaderCoroutine = nil
    if finalText then
        StatusLabel.Text = finalText
        StatusLabel.TextColor3 = color or Color3.fromRGB(200, 220, 255)
    end
end

local dragActive = false
local dragStartInput = nil
local dragStartPos = nil
local dragMoved = false

Btn.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        dragActive = true
        dragMoved = false
        dragStartInput = input.Position
        dragStartPos = Container.Position
        Btn.BackgroundColor3 = Color3.fromRGB(40, 140, 90)
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if not dragActive then return end
    if input.UserInputType ~= Enum.UserInputType.MouseMovement
        and input.UserInputType ~= Enum.UserInputType.Touch then return end
    local delta = input.Position - dragStartInput
    if math.abs(delta.X) > 8 or math.abs(delta.Y) > 8 then
        dragMoved = true
    end
    Container.Position = UDim2.new(
        dragStartPos.X.Scale,
        dragStartPos.X.Offset + delta.X,
        dragStartPos.Y.Scale,
        dragStartPos.Y.Offset + delta.Y
    )
end)

UserInputService.InputEnded:Connect(function(input)
    if not dragActive then return end
    if input.UserInputType ~= Enum.UserInputType.MouseButton1
        and input.UserInputType ~= Enum.UserInputType.Touch then return end
    dragActive = false
    Btn.BackgroundColor3 = Color3.fromRGB(60, 180, 120)
    if not dragMoved then
        task.spawn(function()
            local ok, err = pcall(doHop)
            if not ok then
                stopLoading("Lỗi!", Color3.fromRGB(255, 100, 100))
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
        return http({ Url = url, Method = "GET", Headers = { ["Accept"] = "application/json" } })
    end)
    if not ok or not res or not res.Body then return nil end
    local ok2, data = pcall(function()
        return HttpService:JSONDecode(res.Body)
    end)
    if not ok2 or not data then return nil end
    return data
end

function doHop()
    if IsScanning then return end
    IsScanning = true
    startLoading("Đang tìm server")
    task.wait(0.1)

    if not http then
        IsScanning = false
        stopLoading("Lỗi kết nối!", Color3.fromRGB(255, 100, 100))
        return
    end

    local onePlayer = {}
    local twoPlayer = {}
    local cursor = ""
    local pages = 0

    while pages < 12 do
        local data = requestPage(cursor)
        if not data or not data.data then break end
        local cnt = 0
        for _, s in ipairs(data.data) do
            cnt = cnt + 1
            local pc = s.playing or 0
            local id = s.id
            if id ~= JOB_ID and not Blacklist[id] then
                local entry = {
                    id = id,
                    ping = s.ping or 999,
                    fps = s.fps or 60,
                    playing = pc
                }
                if pc == 1 then
                    table.insert(onePlayer, entry)
                elseif pc == 2 then
                    table.insert(twoPlayer, entry)
                end
            end
        end
        if cnt == 0 then break end
        cursor = data.nextPageCursor
        if not cursor or cursor == "" or cursor == "null" then break end
        pages = pages + 1
        task.wait(0.02)
    end

    local pool = onePlayer
    if #pool == 0 then pool = twoPlayer end

    if #pool == 0 then
        IsScanning = false
        stopLoading("Không có server!", Color3.fromRGB(255, 100, 100))
        return
    end

    table.sort(pool, function(a, b)
        if a.fps ~= b.fps then
            return a.fps < b.fps
        end
        return a.ping > b.ping
    end)

    local topN = math.min(5, #pool)
    local target = pool[math.random(1, topN)]

    startLoading("Đang vào server")
    task.wait(0.5)

    IsScanning = false
    Blacklist[target.id] = true

    local ok = pcall(function()
        TeleportService:TeleportToPlaceInstance(PLACE_ID, target.id, LocalPlayer)
    end)

    if not ok then
        stopLoading("Lỗi! Bấm lại.", Color3.fromRGB(255, 100, 100))
    end
end

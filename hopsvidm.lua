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

-- ==== CONFIG TỐC ĐỘ ====
local CONFIG = {
    PageDelay = 0,          -- Không delay giữa các trang
    PassDelay = 0.5,        -- Delay giữa các pass (giảm từ 2.5s → 0.5s)
    ConfirmDelay = 0.3,     -- Delay xác nhận (giảm từ 1.5s → 0.3s)
    PreTeleportDelay = 0.1, -- Delay trước teleport (giảm từ 0.5s → 0.1s)
    MaxPages = 20,          -- Quét nhiều trang hơn (tăng từ 12 → 20)
    ParallelPages = 4,      -- Số trang quét song song
}

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
Container.Size = UDim2.new(0, 200, 0, 110)
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
StatusLabel.TextSize = 11
StatusLabel.TextWrapped = false
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
            task.wait(0.1)
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
            local ok = pcall(doHop)
            if not ok then
                stopLoading("Lỗi!", Color3.fromRGB(255, 100, 100))
                IsScanning = false
            end
        end)
    end
end)

-- ==== REQUEST SINGLE PAGE (nhanh, không retry) ====
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

-- ==== PARALLEL SCAN: Lấy cursor đầu → quét nhiều nhánh song song ====
local function parallelScan(maxPages, maxPlayers)
    local result = {}
    local scanned = 0

    -- Bước 1: Lấy cursor gốc
    local first = requestPage("")
    if not first or not first.data then return result, 0 end

    -- Xử lý trang đầu
    for _, s in ipairs(first.data) do
        scanned = scanned + 1
        local pc = s.playing or 0
        local id = s.id
        if id and id ~= JOB_ID and not Blacklist[id] and pc >= 1 and pc <= maxPlayers then
            result[id] = {
                id = id,
                ping = s.ping or 999,
                fps = s.fps or 60,
                playing = pc,
                max = s.maxPlayers or 12,
            }
        end
    end

    local rootCursor = first.nextPageCursor
    if not rootCursor or rootCursor == "" or rootCursor == "null" then
        return result, scanned
    end

    -- Bước 2: Quét song song nhiều nhánh cursor
    local totalBranches = math.min(CONFIG.ParallelPages, math.max(1, math.floor(maxPages / 5)))
    local branches = {}
    local branchCursors = { rootCursor }

    -- Lấy cursor của các nhánh
    for i = 1, totalBranches do
        local cur = branchCursors[i]
        if cur then
            local data = requestPage(cur)
            if data then
                for _, s in ipairs(data.data or {}) do
                    scanned = scanned + 1
                    local pc = s.playing or 0
                    local id = s.id
                    if id and id ~= JOB_ID and not Blacklist[id] and pc >= 1 and pc <= maxPlayers then
                        result[id] = {
                            id = id,
                            ping = s.ping or 999,
                            fps = s.fps or 60,
                            playing = pc,
                            max = s.maxPlayers or 12,
                        }
                    end
                end
                if data.nextPageCursor and data.nextPageCursor ~= "" and data.nextPageCursor ~= "null" then
                    branchCursors[i + 1] = data.nextPageCursor
                end
            end
        end
    end

    -- Bước 3: Chạy parallel từ mỗi branch cursor
    local pageCount = math.floor(maxPages / math.max(1, totalBranches))
    local threads = {}
    local lock = false

    for idx = 1, totalBranches do
        local startCursor = branchCursors[idx]
        if startCursor then
            table.insert(threads, task.spawn(function()
                local cursor = startCursor
                local pages = 0
                while pages < pageCount do
                    local data = requestPage(cursor)
                    if not data or not data.data then break end
                    local localResult = {}
                    for _, s in ipairs(data.data) do
                        local pc = s.playing or 0
                        local id = s.id
                        if id and id ~= JOB_ID and not Blacklist[id] and pc >= 1 and pc <= maxPlayers then
                            localResult[id] = {
                                id = id,
                                ping = s.ping or 999,
                                fps = s.fps or 60,
                                playing = pc,
                                max = s.maxPlayers or 12,
                            }
                        end
                    end

                    -- Merge vào result
                    while lock do task.wait() end
                    lock = true
                    for id, s in pairs(localResult) do
                        result[id] = s
                    end
                    lock = false

                    cursor = data.nextPageCursor
                    if not cursor or cursor == "" or cursor == "null" then break end
                    pages = pages + 1
                    if CONFIG.PageDelay > 0 then task.wait(CONFIG.PageDelay) end
                end
            end))
        end
    end

    -- Chờ tất cả thread xong
    for _, t in ipairs(threads) do
        pcall(function() task.wait(0) end)
    end

    return result, scanned
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

-- ==== FAST TELEPORT (ưu tiên TeleportAsync) ====
local function fastTeleport(jobId)
    local success = false

    -- Ưu tiên TeleportAsync (nhanh hơn)
    pcall(function()
        local opts = Instance.new("TeleportOptions")
        opts.ServerInstanceId = jobId
        TeleportService:TeleportAsync(PLACE_ID, {LocalPlayer}, opts)
        success = true
    end)

    if success then return true end

    -- Fallback
    pcall(function()
        TeleportService:TeleportToPlaceInstance(PLACE_ID, jobId, LocalPlayer)
        success = true
    end)

    return success
end

function doHop()
    if IsScanning then return end
    IsScanning = true

    startLoading("Đang dò server")

    if not http then
        IsScanning = false
        stopLoading("Lỗi kết nối!", Color3.fromRGB(255, 100, 100))
        return
    end

    -- PASS 1: Parallel scan
    local pass1, scanned1 = parallelScan(CONFIG.MaxPages, 2)

    local count1 = 0
    for _ in pairs(pass1) do count1 = count1 + 1 end

    if count1 == 0 then
        IsScanning = false
        stopLoading("Không có server!", Color3.fromRGB(255, 100, 100))
        return
    end

    startLoading("Đang phân tích")
    task.wait(CONFIG.PassDelay)

    -- PASS 2: Parallel scan lại
    local pass2, _ = parallelScan(CONFIG.MaxPages, 2)

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

    startLoading("Đang xác nhận")
    task.wait(CONFIG.ConfirmDelay)

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
        IsScanning = false
        stopLoading("Không có server!", Color3.fromRGB(255, 100, 100))
        return
    end

    local target = pickFrom[math.random(1, topCount)]

    startLoading("Đang vào server")
    task.wait(CONFIG.PreTeleportDelay)

    IsScanning = false
    Blacklist[target.id] = true

    local ok = fastTeleport(target.id)

    if not ok then
        stopLoading("Lỗi! Bấm lại.", Color3.fromRGB(255, 100, 100))
    end
end

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

local CONFIG = {
    Tier1Playing = 1,
    Tier1HopThreshold = 3,
    Tier2Playing = 2,
    Tier2HopThreshold = 4,
    MaxPages = 20,
    ParallelBranches = 4,
    PageDelay = 0,
    PassDelay = 0.4,
    ConfirmDelay = 0.25,
    PreTeleportDelay = 0.1,
    MonitorInterval = 1,
}

local Blacklist = {}
local IsScanning = false
local IsMonitoring = false
local LoaderActive = false
local loaderCoroutine = nil
local CurrentTier = nil

if CoreGui:FindFirstChild("HopUI") then CoreGui.HopUI:Destroy() end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "HopUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.IgnoreGuiInset = true
ScreenGui.DisplayOrder = 999999
ScreenGui.Parent = CoreGui

local Container = Instance.new("Frame")
Container.Size = UDim2.new(0, 210, 0, 120)
Container.Position = UDim2.new(0, 20, 0.5, -60)
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
StatusLabel.Size = UDim2.new(1, 0, 0, 20)
StatusLabel.Position = UDim2.new(0, 0, 0, 84)
StatusLabel.BackgroundColor3 = Color3.fromRGB(20, 22, 30)
StatusLabel.BackgroundTransparency = 0.1
StatusLabel.BorderSizePixel = 0
StatusLabel.Text = "Sẵn sàng"
StatusLabel.TextColor3 = Color3.fromRGB(200, 220, 255)
StatusLabel.Font = Enum.Font.GothamBold
StatusLabel.TextSize = 10
StatusLabel.TextWrapped = false
StatusLabel.Parent = Container

local StatusCorner = Instance.new("UICorner")
StatusCorner.CornerRadius = UDim.new(0, 6)
StatusCorner.Parent = StatusLabel

local InfoLabel = Instance.new("TextLabel")
InfoLabel.Size = UDim2.new(1, 0, 0, 16)
InfoLabel.Position = UDim2.new(0, 0, 0, 106)
InfoLabel.BackgroundTransparency = 1
InfoLabel.Text = ""
InfoLabel.TextColor3 = Color3.fromRGB(140, 180, 220)
InfoLabel.Font = Enum.Font.Code
InfoLabel.TextSize = 9
InfoLabel.Parent = Container

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

local function setInfo(text, color)
    InfoLabel.Text = text
    InfoLabel.TextColor3 = color or Color3.fromRGB(140, 180, 220)
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

local function parallelScan(maxPages, targetPlaying)
    local result = {}
    local first = requestPage("")
    if not first or not first.data then return result end

    for _, s in ipairs(first.data) do
        local pc = s.playing or 0
        local id = s.id
        if id and id ~= JOB_ID and not Blacklist[id] and pc == targetPlaying then
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
        return result
    end

    local branchCursors = { rootCursor }
    local branchesToSpawn = CONFIG.ParallelBranches

    for i = 1, branchesToSpawn do
        local cur = branchCursors[i]
        if not cur then break end
        local data = requestPage(cur)
        if not data or not data.data then break end
        for _, s in ipairs(data.data) do
            local pc = s.playing or 0
            local id = s.id
            if id and id ~= JOB_ID and not Blacklist[id] and pc == targetPlaying then
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

    local pagesPerBranch = math.floor(maxPages / math.max(1, branchesToSpawn))
    local threads = {}
    local lock = false

    for idx = 1, branchesToSpawn do
        local startCursor = branchCursors[idx]
        if startCursor then
            table.insert(threads, task.spawn(function()
                local cursor = startCursor
                local pages = 0
                while pages < pagesPerBranch do
                    local data = requestPage(cursor)
                    if not data or not data.data then break end

                    local localResult = {}
                    for _, s in ipairs(data.data) do
                        local pc = s.playing or 0
                        local id = s.id
                        if id and id ~= JOB_ID and not Blacklist[id] and pc == targetPlaying then
                            localResult[id] = {
                                id = id,
                                ping = s.ping or 999,
                                fps = s.fps or 60,
                                playing = pc,
                                max = s.maxPlayers or 12,
                            }
                        end
                    end

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

    local timeout = tick() + 15
    while tick() < timeout do
        local allDone = true
        for _, t in ipairs(threads) do
            if coroutine.status(t) ~= "dead" then
                allDone = false
                break
            end
        end
        if allDone then break end
        task.wait(0.05)
    end

    return result
end

local function calculateScore(server, stabilityBonus)
    local playerScore = 0
    if server.playing == 1 then
        playerScore = 1000
    elseif server.playing == 2 then
        playerScore = 100
    end

    local fpsScore = math.max(0, 60 - server.fps) * 1.5
    local pingScore = math.min(server.ping, 500) / 5
    local stabilityScore = stabilityBonus * 60

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

local function startMonitor(threshold)
    if IsMonitoring then return end
    IsMonitoring = true

    task.spawn(function()
        local lastCount = -1
        while IsMonitoring do
            task.wait(CONFIG.MonitorInterval)

            if not ScreenGui.Parent then
                IsMonitoring = false
                return
            end

            local count = #Players:GetPlayers()

            if count ~= lastCount then
                lastCount = count
                local others = count - 1

                if count >= threshold then
                    stopLoading("Có " .. others .. " người khác! Đang hop...",
                        Color3.fromRGB(255, 150, 100))
                    setInfo("Vượt ngưỡng " .. threshold .. " → hop", Color3.fromRGB(255, 180, 100))
                    IsMonitoring = false
                    task.wait(0.3)
                    Blacklist[JOB_ID] = true
                    task.spawn(function()
                        local ok = pcall(doHop)
                        if not ok then
                            stopLoading("Lỗi!", Color3.fromRGB(255, 100, 100))
                            IsScanning = false
                        end
                    end)
                    return
                else
                    local remain = threshold - count
                    setInfo(
                        "Server: " .. count .. " người (" .. others .. " khác) · chờ +" .. remain,
                        Color3.fromRGB(255, 220, 120)
                    )
                    stopLoading("Đang ở server OK", Color3.fromRGB(120, 255, 160))
                end
            end
        end
    end)
end

local function stopMonitor()
    IsMonitoring = false
end

function doHop()
    if IsScanning then return end
    IsScanning = true
    stopMonitor()

    startLoading("Đang dò server 1 người")
    setInfo("Ưu tiên: server 1 người", Color3.fromRGB(180, 220, 255))

    if not http then
        IsScanning = false
        stopLoading("Lỗi kết nối!", Color3.fromRGB(255, 100, 100))
        return
    end

    local pass1_t1 = parallelScan(CONFIG.MaxPages, CONFIG.Tier1Playing)
    local count1_t1 = 0
    for _ in pairs(pass1_t1) do count1_t1 = count1_t1 + 1 end

    local targetTier = nil
    local targetPool = nil
    local hopThreshold = 0

    if count1_t1 > 0 then
        task.wait(CONFIG.PassDelay)
        startLoading("Xác nhận server 1 người")

        local pass2_t1 = parallelScan(CONFIG.MaxPages, CONFIG.Tier1Playing)

        local stable = {}
        for id, s in pairs(pass2_t1) do
            if pass1_t1[id] then
                s.stability = 2
                if s.playing == pass1_t1[id].playing then
                    s.stability = 3
                end
                table.insert(stable, s)
            end
        end

        if #stable == 0 then
            for id, s in pairs(pass1_t1) do
                s.stability = 1
                table.insert(stable, s)
            end
        end

        task.wait(CONFIG.ConfirmDelay)

        local scored = {}
        for _, s in ipairs(stable) do
            s.score = calculateScore(s, s.stability)
            table.insert(scored, s)
        end
        table.sort(scored, function(a, b) return a.score > b.score end)

        targetPool = scored
        targetTier = "tier1"
        hopThreshold = CONFIG.Tier1HopThreshold

        setInfo(
            "Tier 1: " .. count1_t1 .. " server 1 người",
            Color3.fromRGB(120, 255, 160)
        )
    else
        startLoading("Tìm server 2 người")
        setInfo("Không có server 1 người · fallback tier 2",
            Color3.fromRGB(255, 200, 100))

        task.wait(0.2)

        local pass1_t2 = parallelScan(CONFIG.MaxPages, CONFIG.Tier2Playing)
        local count1_t2 = 0
        for _ in pairs(pass1_t2) do count1_t2 = count1_t2 + 1 end

        if count1_t2 == 0 then
            IsScanning = false
            stopLoading("Không có server!", Color3.fromRGB(255, 100, 100))
            setInfo("Thử lại sau", Color3.fromRGB(255, 150, 150))
            return
        end

        task.wait(CONFIG.PassDelay)
        startLoading("Xác nhận server 2 người")

        local pass2_t2 = parallelScan(CONFIG.MaxPages, CONFIG.Tier2Playing)

        local stable = {}
        for id, s in pairs(pass2_t2) do
            if pass1_t2[id] then
                s.stability = 2
                if s.playing == pass1_t2[id].playing then
                    s.stability = 3
                end
                table.insert(stable, s)
            end
        end

        if #stable == 0 then
            for id, s in pairs(pass1_t2) do
                s.stability = 1
                table.insert(stable, s)
            end
        end

        task.wait(CONFIG.ConfirmDelay)

        local scored = {}
        for _, s in ipairs(stable) do
            s.score = calculateScore(s, s.stability)
            table.insert(scored, s)
        end
        table.sort(scored, function(a, b) return a.score > b.score end)

        targetPool = scored
        targetTier = "tier2"
        hopThreshold = CONFIG.Tier2HopThreshold

        setInfo(
            "Tier 2: " .. count1_t2 .. " server 2 người",
            Color3.fromRGB(255, 200, 100)
        )
    end

    if not targetPool or #targetPool == 0 then
        IsScanning = false
        stopLoading("Không có server!", Color3.fromRGB(255, 100, 100))
        return
    end

    local target = targetPool[1]
    CurrentTier = targetTier

    startLoading("Đang vào server")
    setInfo(
        target.playing .. " người · FPS" .. target.fps .. " · P" .. target.ping,
        Color3.fromRGB(120, 255, 160)
    )
    task.wait(CONFIG.PreTeleportDelay)

    IsScanning = false
    Blacklist[target.id] = true

    local ok = fastTeleport(target.id)

    if not ok then
        stopLoading("Lỗi! Bấm lại.", Color3.fromRGB(255, 100, 100))
        return
    end

    task.wait(3)
    startMonitor(hopThreshold)
end

LocalPlayer.OnTeleport:Connect(function(state)
    if state == Enum.TeleportState.Started then
        stopMonitor()
        IsMonitoring = false
    end
end)

task.spawn(function()
    task.wait(2)
    if not IsMonitoring and not IsScanning then
        local count = #Players:GetPlayers()
        if count <= 2 then
            local threshold = CONFIG.Tier1HopThreshold
            if count >= 3 then
                threshold = CONFIG.Tier2HopThreshold
            end
            startMonitor(threshold)
            setInfo("Monitor tự động · ngưỡng " .. threshold, Color3.fromRGB(140, 220, 180))
        end
    end
end)

print("[HOP v13.3.1] Loaded")

local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local CoreGui = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local StarterGui = game:GetService("StarterGui")

local LocalPlayer = Players.LocalPlayer
local PLACE_ID = game.PlaceId
local JOB_ID = game.JobId

local CONFIG = {
    SCAN_LIMIT = 700,
    PAGE_SIZE = 100,
    PAGE_DELAY_MIN = 0.28,
    PAGE_DELAY_MAX = 0.48,
    PRE_HOP_DELAY_MIN = 1.2,
    PRE_HOP_DELAY_MAX = 2.0,
    FPS_CEILING = 45,
    PING_FLOOR = 120,
    PING_CEILING = 680,
    PLAYER_SOFT_CAP = 2,
    RANDOM_POOL = 4,
    BLACKLIST_TTL = 900,
    CACHE_TTL = 60,
    AUTO_RETRY = true,
    RETRY_LIMIT = 3,
    RETRY_BACKOFF = 1.8,
    NOTIFY = true
}

local RUNTIME = {
    blacklist = {},
    cache = {},
    busy = false,
    loaderActive = false,
    loaderThread = nil,
    pulseActive = false,
    pulseConn = nil,
    rotateConn = nil,
    dotBlinkThread = nil,
    stats = {
        scans = 0,
        scanned = 0,
        candidates = 0,
        hops = 0,
        fails = 0,
        sessionStart = tick()
    }
}

local function acquireHttp()
    local pool = {
        rawget(getfenv(), "http_request"),
        rawget(getfenv(), "request"),
        syn and syn.request,
        fluxus and fluxus.request,
        http and http.request,
        krypt and krypt.request,
        codex and codex.request
    }
    for _, fn in ipairs(pool) do
        if type(fn) == "function" then
            return fn
        end
    end
    return nil
end

local HTTP = acquireHttp()

local function randRange(a, b)
    return a + math.random() * (b - a)
end

local function pause(min, max)
    if min == max then
        task.wait(min)
    else
        task.wait(randRange(min, max))
    end
end

local function callSafe(fn)
    local ok, result = pcall(fn)
    return ok, result
end

local function isBlacklisted(id)
    if not id then return false end
    local item = RUNTIME.blacklist[id]
    if not item then return false end
    if tick() > item.expires then
        RUNTIME.blacklist[id] = nil
        return false
    end
    return true
end

local function blacklist(id)
    if not id then return end
    RUNTIME.blacklist[id] = {
        created = tick(),
        expires = tick() + CONFIG.BLACKLIST_TTL
    }
end

local function getCache(id)
    local item = RUNTIME.cache[id]
    if not item then return nil end
    if tick() - item.cachedAt > CONFIG.CACHE_TTL then
        RUNTIME.cache[id] = nil
        return nil
    end
    return item
end

local function setCache(id, data)
    data.cachedAt = tick()
    RUNTIME.cache[id] = data
end

local function notify(title, text)
    if not CONFIG.NOTIFY then return end
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = title,
            Text = text,
            Duration = 3
        })
    end)
end

if CoreGui:FindFirstChild("HopUI") then
    CoreGui.HopUI:Destroy()
end

local gui = Instance.new("ScreenGui")
gui.Name = "HopUI"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.IgnoreGuiInset = true
gui.DisplayOrder = 999999
gui.Parent = CoreGui

local root = Instance.new("Frame")
root.Name = "Root"
root.Size = UDim2.new(0, 240, 0, 150)
root.Position = UDim2.new(0, 20, 0, 80)
root.BackgroundTransparency = 1
root.Parent = gui

local halo = Instance.new("ImageLabel")
halo.Name = "Halo"
halo.Size = UDim2.new(0, 120, 0, 120)
halo.Position = UDim2.new(0.5, -60, 0, -22)
halo.BackgroundTransparency = 1
halo.Image = "rbxassetid://5028857084"
halo.ImageColor3 = Color3.fromRGB(60, 180, 120)
halo.ImageTransparency = 0.85
halo.ZIndex = 0
halo.Parent = root

local outerRing = Instance.new("Frame")
outerRing.Name = "OuterRing"
outerRing.Size = UDim2.new(0, 96, 0, 96)
outerRing.Position = UDim2.new(0.5, -48, 0, -8)
outerRing.BackgroundTransparency = 1
outerRing.ZIndex = 1
outerRing.Parent = root

local outerRingCorner = Instance.new("UICorner")
outerRingCorner.CornerRadius = UDim.new(1, 0)
outerRingCorner.Parent = outerRing

local outerRingStroke = Instance.new("UIStroke")
outerRingStroke.Color = Color3.fromRGB(255, 255, 255)
outerRingStroke.Thickness = 1.5
outerRingStroke.Transparency = 0.65
outerRingStroke.Parent = outerRing

local outerRingGradient = Instance.new("UIGradient")
outerRingGradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(120, 230, 180)),
    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(200, 220, 255)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(180, 140, 255))
})
outerRingGradient.Rotation = 45
outerRingGradient.Parent = outerRingStroke

local mainBtn = Instance.new("TextButton")
mainBtn.Name = "MainBtn"
mainBtn.Size = UDim2.new(0, 84, 0, 84)
mainBtn.Position = UDim2.new(0.5, -42, 0, -2)
mainBtn.BackgroundColor3 = Color3.fromRGB(45, 180, 130)
mainBtn.Text = ""
mainBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
mainBtn.Font = Enum.Font.GothamBold
mainBtn.TextSize = 18
mainBtn.AutoButtonColor = false
mainBtn.Active = true
mainBtn.ZIndex = 2
mainBtn.Parent = root

local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(1, 0)
mainCorner.Parent = mainBtn

local mainGradient = Instance.new("UIGradient")
mainGradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(120, 240, 180)),
    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(60, 190, 140)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(30, 120, 90))
})
mainGradient.Rotation = 90
mainGradient.Parent = mainBtn

local mainStroke = Instance.new("UIStroke")
mainStroke.Color = Color3.fromRGB(255, 255, 255)
mainStroke.Thickness = 2
mainStroke.Transparency = 0.35
mainStroke.Parent = mainBtn

local mainStrokeGradient = Instance.new("UIGradient")
mainStrokeGradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(120, 180, 150))
})
mainStrokeGradient.Rotation = 135
mainStrokeGradient.Parent = mainStroke

local innerGlow = Instance.new("Frame")
innerGlow.Name = "InnerGlow"
innerGlow.Size = UDim2.new(1, -8, 1, -8)
innerGlow.Position = UDim2.new(0, 4, 0, 4)
innerGlow.BackgroundColor3 = Color3.fromRGB(150, 255, 200)
innerGlow.BackgroundTransparency = 1
innerGlow.BorderSizePixel = 0
innerGlow.ZIndex = 3
innerGlow.Parent = mainBtn

local innerGlowCorner = Instance.new("UICorner")
innerGlowCorner.CornerRadius = UDim.new(1, 0)
innerGlowCorner.Parent = innerGlow

local topHighlight = Instance.new("Frame")
topHighlight.Name = "TopHighlight"
topHighlight.Size = UDim2.new(0.72, 0, 0.32, 0)
topHighlight.Position = UDim2.new(0.14, 0, 0.06, 0)
topHighlight.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
topHighlight.BackgroundTransparency = 0.62
topHighlight.BorderSizePixel = 0
topHighlight.ZIndex = 3
topHighlight.Parent = mainBtn

local topHighlightCorner = Instance.new("UICorner")
topHighlightCorner.CornerRadius = UDim.new(1, 0)
topHighlightCorner.Parent = topHighlight

local hopText = Instance.new("TextLabel")
hopText.Name = "HopText"
hopText.Size = UDim2.new(1, 0, 0, 30)
hopText.Position = UDim2.new(0, 0, 0.24, 0)
hopText.BackgroundTransparency = 1
hopText.Text = "HOP"
hopText.TextColor3 = Color3.fromRGB(255, 255, 255)
hopText.Font = Enum.Font.GothamBlack
hopText.TextSize = 20
hopText.ZIndex = 5
hopText.Parent = mainBtn

local hopTextStroke = Instance.new("UIStroke")
hopTextStroke.Color = Color3.fromRGB(20, 80, 60)
hopTextStroke.Thickness = 1.2
hopTextStroke.Transparency = 0.4
hopTextStroke.Parent = hopText

local serverText = Instance.new("TextLabel")
serverText.Name = "ServerText"
serverText.Size = UDim2.new(1, 0, 0, 14)
serverText.Position = UDim2.new(0, 0, 0.58, 0)
serverText.BackgroundTransparency = 1
serverText.Text = "S E R V E R"
serverText.TextColor3 = Color3.fromRGB(220, 255, 240)
serverText.Font = Enum.Font.GothamBold
serverText.TextSize = 8
serverText.ZIndex = 5
serverText.Parent = mainBtn

local dotsContainer = Instance.new("Frame")
dotsContainer.Name = "Dots"
dotsContainer.Size = UDim2.new(0, 40, 0, 6)
dotsContainer.Position = UDim2.new(0.5, -20, 0.08, 0)
dotsContainer.BackgroundTransparency = 1
dotsContainer.ZIndex = 5
dotsContainer.Parent = mainBtn

local dot1 = Instance.new("Frame")
dot1.Size = UDim2.new(0, 5, 0, 5)
dot1.Position = UDim2.new(0, 0, 0.5, -2.5)
dot1.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
dot1.BackgroundTransparency = 0.3
dot1.BorderSizePixel = 0
dot1.ZIndex = 5
dot1.Parent = dotsContainer

local dot1Corner = Instance.new("UICorner")
dot1Corner.CornerRadius = UDim.new(1, 0)
dot1Corner.Parent = dot1

local dot2 = Instance.new("Frame")
dot2.Size = UDim2.new(0, 5, 0, 5)
dot2.Position = UDim2.new(0.5, -2.5, 0.5, -2.5)
dot2.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
dot2.BackgroundTransparency = 0.3
dot2.BorderSizePixel = 0
dot2.ZIndex = 5
dot2.Parent = dotsContainer

local dot2Corner = Instance.new("UICorner")
dot2Corner.CornerRadius = UDim.new(1, 0)
dot2Corner.Parent = dot2

local dot3 = Instance.new("Frame")
dot3.Size = UDim2.new(0, 5, 0, 5)
dot3.Position = UDim2.new(1, -5, 0.5, -2.5)
dot3.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
dot3.BackgroundTransparency = 0.3
dot3.BorderSizePixel = 0
dot3.ZIndex = 5
dot3.Parent = dotsContainer

local dot3Corner = Instance.new("UICorner")
dot3Corner.CornerRadius = UDim.new(1, 0)
dot3Corner.Parent = dot3

local allDots = {dot1, dot2, dot3}

local bar = Instance.new("Frame")
bar.Name = "Bar"
bar.Size = UDim2.new(1, 0, 0, 32)
bar.Position = UDim2.new(0, 0, 0, 96)
bar.BackgroundColor3 = Color3.fromRGB(18, 20, 28)
bar.BackgroundTransparency = 0.05
bar.BorderSizePixel = 0
bar.ZIndex = 2
bar.Parent = root

local barCorner = Instance.new("UICorner")
barCorner.CornerRadius = UDim.new(0, 8)
barCorner.Parent = bar

local barStroke = Instance.new("UIStroke")
barStroke.Color = Color3.fromRGB(80, 120, 180)
barStroke.Thickness = 1
barStroke.Transparency = 0.6
barStroke.Parent = bar

local icon = Instance.new("TextLabel")
icon.Name = "Icon"
icon.Size = UDim2.new(0, 28, 1, 0)
icon.Position = UDim2.new(0, 4, 0, 0)
icon.BackgroundTransparency = 1
icon.Text = "●"
icon.TextColor3 = Color3.fromRGB(120, 200, 255)
icon.Font = Enum.Font.GothamBold
icon.TextSize = 14
icon.ZIndex = 3
icon.Parent = bar

local text = Instance.new("TextLabel")
text.Name = "Text"
text.Size = UDim2.new(1, -70, 1, 0)
text.Position = UDim2.new(0, 32, 0, 0)
text.BackgroundTransparency = 1
text.Text = "Sẵn sàng"
text.TextColor3 = Color3.fromRGB(200, 220, 255)
text.Font = Enum.Font.GothamBold
text.TextSize = 11
text.TextXAlignment = Enum.TextXAlignment.Left
text.TextTruncate = Enum.TextTruncate.AtEnd
text.ZIndex = 3
text.Parent = bar

local progressBg = Instance.new("Frame")
progressBg.Name = "ProgressBg"
progressBg.Size = UDim2.new(1, -8, 0, 3)
progressBg.Position = UDim2.new(0, 4, 1, -5)
progressBg.BackgroundColor3 = Color3.fromRGB(40, 50, 70)
progressBg.BorderSizePixel = 0
progressBg.ZIndex = 4
progressBg.Parent = bar

local progressBgCorner = Instance.new("UICorner")
progressBgCorner.CornerRadius = UDim.new(1, 0)
progressBgCorner.Parent = progressBg

local progressFill = Instance.new("Frame")
progressFill.Name = "ProgressFill"
progressFill.Size = UDim2.new(0, 0, 1, 0)
progressFill.BackgroundColor3 = Color3.fromRGB(120, 200, 255)
progressFill.BorderSizePixel = 0
progressFill.ZIndex = 5
progressFill.Parent = progressBg

local progressFillCorner = Instance.new("UICorner")
progressFillCorner.CornerRadius = UDim.new(1, 0)
progressFillCorner.Parent = progressFill

local progressGradient = Instance.new("UIGradient")
progressGradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(100, 180, 255)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(180, 120, 255))
})
progressGradient.Parent = progressFill

local stats = Instance.new("TextLabel")
stats.Name = "Stats"
stats.Size = UDim2.new(1, 0, 0, 14)
stats.Position = UDim2.new(0, 0, 1, 6)
stats.BackgroundTransparency = 1
stats.Text = "Sẵn sàng hoạt động"
stats.TextColor3 = Color3.fromRGB(130, 150, 180)
stats.Font = Enum.Font.Gotham
stats.TextSize = 9
stats.ZIndex = 2
stats.Parent = root

local SPINNERS = {
    dots = {"", ".", "..", "...", "...."},
    braille = {"⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"},
    arrow = {"←", "↖", "↑", "↗", "→", "↘", "↓", "↙"},
    block = {"▁", "▂", "▃", "▄", "▅", "▆", "▇", "█", "▇", "▆", "▅", "▄", "▃", "▂"},
    pulse = {"◐", "◓", "◑", "◒"},
    target = {"◜", "◝", "◞", "◟"},
    dots2 = {"⣾", "⣽", "⣻", "⢿", "⡿", "⣟", "⣯", "⣷"}
}

local activeSpinner = SPINNERS.dots
local activeBaseText = ""

local function setDotsBlink(speed)
    if RUNTIME.dotBlinkThread then
        task.cancel(RUNTIME.dotBlinkThread)
        RUNTIME.dotBlinkThread = nil
    end
    for _, d in ipairs(allDots) do
        d.BackgroundTransparency = 0.3
    end

    if not speed then return end

    RUNTIME.dotBlinkThread = task.spawn(function()
        local i = 1
        while true do
            if not speed or not mainBtn or not mainBtn.Parent then break end
            for j, d in ipairs(allDots) do
                if j == i then
                    TweenService:Create(d, TweenInfo.new(0.15), {
                        BackgroundTransparency = 0
                    }):Play()
                else
                    TweenService:Create(d, TweenInfo.new(0.15), {
                        BackgroundTransparency = 0.7
                    }):Play()
                end
            end
            i = i + 1
            if i > #allDots then i = 1 end
            task.wait(speed)
        end
    end)
end

local function startRingRotation(color)
    if RUNTIME.rotateConn then
        RUNTIME.rotateConn:Disconnect()
        RUNTIME.rotateConn = nil
    end

    outerRingStroke.Color = color or Color3.fromRGB(120, 230, 180)
    outerRingStroke.Transparency = 0.2

    local startTime = tick()
    RUNTIME.rotateConn = RunService.Heartbeat:Connect(function()
        if not outerRingStroke or not outerRingStroke.Parent then return end
        local t = (tick() - startTime) * 180
        outerRingGradient.Rotation = (t % 360)
    end)
end

local function stopRingRotation()
    if RUNTIME.rotateConn then
        RUNTIME.rotateConn:Disconnect()
        RUNTIME.rotateConn = nil
    end
    outerRingGradient.Rotation = 45
    outerRingStroke.Transparency = 0.65
end

local function startPulse(color)
    RUNTIME.pulseActive = false
    if RUNTIME.pulseConn then
        RUNTIME.pulseConn:Disconnect()
        RUNTIME.pulseConn = nil
    end
    halo.ImageColor3 = color or Color3.fromRGB(60, 180, 120)
    RUNTIME.pulseActive = true

    local startTime = tick()
    RUNTIME.pulseConn = RunService.Heartbeat:Connect(function()
        if not RUNTIME.pulseActive then return end
        if not halo or not halo.Parent then return end
        local t = (tick() - startTime) * 2
        local wave = (math.sin(t) + 1) / 2
        halo.ImageTransparency = 0.7 - (wave * 0.35)
        local size = 120 + wave * 25
        halo.Size = UDim2.new(0, size, 0, size)
        halo.Position = UDim2.new(0.5, -size / 2, 0, -22 - (size - 120) / 2)
    end)
end

local function stopPulse()
    RUNTIME.pulseActive = false
    if RUNTIME.pulseConn then
        RUNTIME.pulseConn:Disconnect()
        RUNTIME.pulseConn = nil
    end
    TweenService:Create(halo, TweenInfo.new(0.3), {
        ImageTransparency = 0.85,
        Size = UDim2.new(0, 120, 0, 120),
        Position = UDim2.new(0.5, -60, 0, -22)
    }):Play()
end

local function pressDown()
    TweenService:Create(mainBtn, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Size = UDim2.new(0, 76, 0, 76),
        Position = UDim2.new(0.5, -38, 0, 2)
    }):Play()
    TweenService:Create(topHighlight, TweenInfo.new(0.08), {
        BackgroundTransparency = 0.85
    }):Play()
    TweenService:Create(innerGlow, TweenInfo.new(0.08), {
        BackgroundTransparency = 0.88
    }):Play()
end

local function pressUp()
    TweenService:Create(mainBtn, TweenInfo.new(0.14, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Size = UDim2.new(0, 84, 0, 84),
        Position = UDim2.new(0.5, -42, 0, -2)
    }):Play()
    TweenService:Create(topHighlight, TweenInfo.new(0.14), {
        BackgroundTransparency = 0.62
    }):Play()
    TweenService:Create(innerGlow, TweenInfo.new(0.14), {
        BackgroundTransparency = 1
    }):Play()
end

local function refreshStats()
    local elapsed = tick() - RUNTIME.stats.sessionStart
    stats.Text = string.format("Scan %d • Hops %d • Found %d • %ds",
        RUNTIME.stats.scans,
        RUNTIME.stats.hops,
        RUNTIME.stats.candidates,
        math.floor(elapsed))
end

local function startLoading(label, spinnerKey, iconChar, color)
    RUNTIME.loaderActive = false
    task.wait()
    RUNTIME.loaderActive = true

    activeBaseText = label
    activeSpinner = SPINNERS[spinnerKey] or SPINNERS.dots

    local c = color or Color3.fromRGB(120, 200, 255)
    text.TextColor3 = c
    icon.Text = iconChar or "●"
    icon.TextColor3 = c
    progressFill.BackgroundColor3 = c

    RUNTIME.loaderThread = task.spawn(function()
        local i = 1
        local startTime = tick()
        while RUNTIME.loaderActive do
            local elapsed = tick() - startTime

            if activeSpinner == SPINNERS.dots then
                local dots = math.floor(elapsed * 3) % 5
                text.Text = activeBaseText .. string.rep(".", dots)
            else
                text.Text = activeBaseText .. " " .. activeSpinner[i]
                i = i + 1
                if i > #activeSpinner then i = 1 end
            end

            if activeSpinner == SPINNERS.block then
                progressFill.Size = UDim2.new(
                    (math.sin(elapsed * 3) + 1) / 2 * 0.9 + 0.1, 0, 1, 0
                )
            elseif activeSpinner == SPINNERS.pulse then
                local p = (elapsed % 1.5) / 1.5
                progressFill.Size = UDim2.new(p, 0, 1, 0)
            elseif activeSpinner == SPINNERS.target then
                local p = (math.sin(elapsed * 2) + 1) / 2
                progressFill.Size = UDim2.new(p * 0.9 + 0.05, 0, 1, 0)
            else
                local p = (elapsed % 2) / 2
                progressFill.Size = UDim2.new(p, 0, 1, 0)
            end

            task.wait(0.05)
        end
    end)
end

local function stopLoading(finalText, color)
    RUNTIME.loaderActive = false
    RUNTIME.loaderThread = nil
    if finalText then
        text.Text = finalText
        text.TextColor3 = color or Color3.fromRGB(200, 220, 255)
        icon.TextColor3 = color or Color3.fromRGB(120, 200, 255)
        progressFill.BackgroundColor3 = color or Color3.fromRGB(120, 200, 255)
    end
    TweenService:Create(progressFill, TweenInfo.new(0.3), {
        Size = UDim2.new(0, 0, 1, 0)
    }):Play()
    task.delay(0.3, refreshStats)
end

local drag = {
    active = false,
    startInput = nil,
    startPos = nil,
    moved = false
}

mainBtn.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        drag.active = true
        drag.moved = false
        drag.startInput = input.Position
        drag.startPos = root.Position
        pressDown()
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if not drag.active then return end
    if input.UserInputType ~= Enum.UserInputType.MouseMovement
        and input.UserInputType ~= Enum.UserInputType.Touch then return end
    local delta = input.Position - drag.startInput
    if math.abs(delta.X) > 8 or math.abs(delta.Y) > 8 then
        drag.moved = true
    end
    root.Position = UDim2.new(
        drag.startPos.X.Scale,
        drag.startPos.X.Offset + delta.X,
        drag.startPos.Y.Scale,
        drag.star

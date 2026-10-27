local CFG = {
    MinSpeed = 200,
    MaxSpeed = 350,
    SpeedCurve = 750,
    ClimbSpeed = 200,
    CorrectionSpeed = 90,
    CruiseHeight = 45,
    LandingDropHeight = 12,
    LandingDropSpeed = 140,
    TerrainLookAhead = 200,
    TerrainCheck = 0.15,
    ObstacleClearance = 18,
    MaxClimbBoost = 180,
    ArriveXZ = 8,
    InteractDistance = 10,
    InteractVertical = 8,
    FlyPoll = 0.03,
    LandPoll = 0.01,
    LandFallSpeed = 120,
    FlightTimeout = 60,
    LandingTimeout = 10,
    TickInterval = 0.10,
    RemoteInterval = 0.45,
    RemoteTimeout = 4,
    StateTimeout = 2,
    StateMaxAge = 0.5,
    StuckTimeout = 5,
    ResetDistance = 30,
    PickupResetDistance = 60,
    PickupResetHeight = 20,
    PickupDropStart = 3,
    PickupDropStep = 10,
    PickupDropMax = 33,
    PickupResetWait = 0.40,
    PickupSettleTimeout = 8,
    JobRetryDelay = 4,
    AcceptX = 800,
    AcceptY = 425,
    PromptDelay = 0.60,
    ClickHold = 0.06,
    JobConfirmTimeout = 3,
}

local old = _G.AD_INSTANCE
local resumeProgress = type(old) == "table" and old.Progress or nil
if type(old) == "table" and type(old.Stop) == "function" then
    pcall(old.Stop, "Chạy lại", true)
end
_G.AD_STOP = true

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer
if not player then
    warn("[AD] Không tìm thấy LocalPlayer.")
    return
end

local playerGui = player:WaitForChild("PlayerGui", 10)
if not playerGui then
    warn("[AD] Không tìm thấy PlayerGui trong 10 giây.")
    return
end
if playerGui:FindFirstChild("AD_UI") then _G.AD_REJOIN_REQUIRED = true end
if _G.AD_REJOIN_REQUIRED then
    warn("[AD] Phát hiện bản AD_UI cũ không có connection handle. Khởi động lại Roblox rồi chạy bản mới; không bật lại AD_STOP=false trong phiên này.")
    return
end
for _, name in ipairs({"AutoDeliveryUI", "TestUI"}) do
    local staleGui = playerGui:FindFirstChild(name)
    if staleGui then staleGui:Destroy() end
end
_G.AD_STOP = false

local gui = Instance.new("ScreenGui")
gui.Name = "AutoDeliveryUI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.DisplayOrder = 100
gui.Parent = playerGui

local shadow = Instance.new("Frame")
shadow.Name = "Shadow"
shadow.Position = UDim2.fromOffset(10, 10)
shadow.Size = UDim2.fromOffset(208, 56)
shadow.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
shadow.BackgroundTransparency = 0.58
shadow.BorderSizePixel = 0
shadow.ZIndex = 0
shadow.Parent = gui
local shadowCorner = Instance.new("UICorner")
shadowCorner.CornerRadius = UDim.new(0, 10)
shadowCorner.Parent = shadow

local frame = Instance.new("Frame")
frame.Name = "Card"
frame.Position = UDim2.fromOffset(8, 8)
frame.Size = UDim2.fromOffset(208, 56)
frame.BackgroundColor3 = Color3.fromRGB(23, 20, 35)
frame.BorderSizePixel = 0
frame.ClipsDescendants = true
frame.ZIndex = 1
frame.Parent = gui
local frameCorner = Instance.new("UICorner")
frameCorner.CornerRadius = UDim.new(0, 8)
frameCorner.Parent = frame
local frameStroke = Instance.new("UIStroke")
frameStroke.Color = Color3.fromRGB(108, 88, 160)
frameStroke.Transparency = 0.45
frameStroke.Thickness = 1
frameStroke.Parent = frame
local frameGradient = Instance.new("UIGradient")
frameGradient.Rotation = 90
frameGradient.Color = ColorSequence.new{
    ColorSequenceKeypoint.new(0, Color3.fromRGB(35, 29, 54)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(16, 14, 24)),
}
frameGradient.Parent = frame

local dotGlow = Instance.new("Frame")
dotGlow.Name = "StatusGlow"
dotGlow.Position = UDim2.fromOffset(7, 7)
dotGlow.Size = UDim2.fromOffset(12, 12)
dotGlow.BackgroundColor3 = Color3.fromRGB(186, 167, 237)
dotGlow.BackgroundTransparency = 0.82
dotGlow.BorderSizePixel = 0
dotGlow.ZIndex = 2
dotGlow.Parent = frame
local dotGlowCorner = Instance.new("UICorner")
dotGlowCorner.CornerRadius = UDim.new(1, 0)
dotGlowCorner.Parent = dotGlow

local dot = Instance.new("Frame")
dot.Name = "StatusDot"
dot.Position = UDim2.fromOffset(10, 10)
dot.Size = UDim2.fromOffset(6, 6)
dot.BackgroundColor3 = Color3.fromRGB(186, 167, 237)
dot.BorderSizePixel = 0
dot.ZIndex = 3
dot.Parent = frame
local dotCorner = Instance.new("UICorner")
dotCorner.CornerRadius = UDim.new(1, 0)
dotCorner.Parent = dot

local title = Instance.new("TextLabel")
title.Position = UDim2.fromOffset(22, 4)
title.Size = UDim2.new(1, -70, 0, 18)
title.BackgroundTransparency = 1
title.Text = "AUTO DELIVERY"
title.Font = Enum.Font.GothamBold
title.TextSize = 9
title.TextColor3 = Color3.fromRGB(239, 233, 255)
title.TextXAlignment = Enum.TextXAlignment.Left
title.ZIndex = 2
title.Parent = frame

local stopButton = Instance.new("TextButton")
stopButton.Name = "StopButton"
stopButton.Position = UDim2.fromOffset(161, 4)
stopButton.Size = UDim2.fromOffset(40, 18)
stopButton.BackgroundColor3 = Color3.fromRGB(122, 43, 60)
stopButton.BorderSizePixel = 0
stopButton.Text = "STOP"
stopButton.Font = Enum.Font.GothamBold
stopButton.TextSize = 8
stopButton.TextColor3 = Color3.fromRGB(255, 223, 230)
stopButton.ZIndex = 3
stopButton.Parent = frame
local stopCorner = Instance.new("UICorner")
stopCorner.CornerRadius = UDim.new(0, 5)
stopCorner.Parent = stopButton
local stopStroke = Instance.new("UIStroke")
stopStroke.Color = Color3.fromRGB(255, 132, 154)
stopStroke.Transparency = 0.55
stopStroke.Thickness = 1
stopStroke.Parent = stopButton

local l1 = Instance.new("TextLabel")
l1.Position = UDim2.fromOffset(10, 23)
l1.Size = UDim2.new(1, -20, 0, 15)
l1.BackgroundTransparency = 1
l1.TextXAlignment = Enum.TextXAlignment.Left
l1.TextTruncate = Enum.TextTruncate.AtEnd
l1.Font = Enum.Font.GothamBold
l1.TextSize = 11
l1.Text = ""
l1.ZIndex = 2
l1.Parent = frame

local l2 = Instance.new("TextLabel")
l2.Position = UDim2.fromOffset(10, 38)
l2.Size = UDim2.new(1, -20, 0, 11)
l2.BackgroundTransparency = 1
l2.TextXAlignment = Enum.TextXAlignment.Left
l2.TextTruncate = Enum.TextTruncate.AtEnd
l2.Font = Enum.Font.Gotham
l2.TextSize = 9
l2.TextColor3 = Color3.fromRGB(146, 138, 168)
l2.Text = ""
l2.ZIndex = 2
l2.Parent = frame

local barBack = Instance.new("Frame")
barBack.Name = "ProgressBack"
barBack.Position = UDim2.fromOffset(10, 51)
barBack.Size = UDim2.new(1, -20, 0, 2)
barBack.BackgroundColor3 = Color3.fromRGB(47, 40, 66)
barBack.BorderSizePixel = 0
barBack.ZIndex = 2
barBack.Parent = frame
local barBackCorner = Instance.new("UICorner")
barBackCorner.CornerRadius = UDim.new(1, 0)
barBackCorner.Parent = barBack

local progressFill = Instance.new("Frame")
progressFill.Name = "ProgressFill"
progressFill.Position = UDim2.fromOffset(10, 51)
progressFill.Size = UDim2.new(0, 0, 0, 2)
progressFill.BackgroundColor3 = Color3.fromRGB(186, 167, 237)
progressFill.BorderSizePixel = 0
progressFill.ZIndex = 3
progressFill.Parent = frame
local fillCorner = Instance.new("UICorner")
fillCorner.CornerRadius = UDim.new(1, 0)
fillCorner.Parent = progressFill

local COLOR = {
    idle = Color3.fromRGB(186, 167, 237),
    start = Color3.fromRGB(124, 185, 255),
    pickup = Color3.fromRGB(255, 207, 105),
    delivery = Color3.fromRGB(117, 225, 174),
    stuck = Color3.fromRGB(255, 153, 107),
    error = Color3.fromRGB(255, 119, 137),
}
local function status(text, color)
    if not gui.Parent then return end
    if l1.Text ~= text then l1.Text = text end
    if color then
        if l1.TextColor3 ~= color then l1.TextColor3 = color end
        if dot.BackgroundColor3 ~= color then dot.BackgroundColor3 = color end
        if dotGlow.BackgroundColor3 ~= color then dotGlow.BackgroundColor3 = color end
    end
end
local function detail(text)
    if gui.Parent and l2.Text ~= text then l2.Text = text end
end
local function setBar(fraction, color)
    if not gui.Parent then return end
    fraction = tonumber(fraction) or 0
    if fraction ~= fraction then fraction = 0 end
    fraction = math.clamp(fraction, 0, 1)
    progressFill.Size = UDim2.new(fraction, 0, 0, 2)
    if color then progressFill.BackgroundColor3 = color end
end
local function setRunButton(running)
    if not (stopButton and stopButton.Parent) then return end
    stopButton.Active = true
    stopButton.AutoButtonColor = true
    if running then
        stopButton.Text = "STOP"
        stopButton.BackgroundColor3 = Color3.fromRGB(122, 43, 60)
        stopButton.TextColor3 = Color3.fromRGB(255, 223, 230)
        stopStroke.Color = Color3.fromRGB(255, 132, 154)
        stopStroke.Transparency = 0.55
    else
        stopButton.Text = "START"
        stopButton.BackgroundColor3 = Color3.fromRGB(34, 104, 74)
        stopButton.TextColor3 = Color3.fromRGB(216, 255, 233)
        stopStroke.Color = Color3.fromRGB(110, 235, 168)
        stopStroke.Transparency = 0.45
    end
end

local stopping, traveling, startingJob, landing = false, false, false, false
local canResume, disposed = false, false
local noclip = false
local connections, partConnections, parts, pending = {}, {}, {}, {}
local character, humanoid, root, worker, lift, liftAttachment
local flightControl, flightHumanoid, savedPlatformStand, savedAutoRotate
local jt, pickupRemote, completeRemote, vim
local padContainer, padPrompt
local mousePressed = false
local nextTick, nextRemote, nextJob, nextPadScan = 0, 0, 0, 0
local phase, lastItems, lastCapacity, lastPickup, lastDestination
local pickStuck, destStuck
local pickAttempts, pickDropOffset, pickBaseItems = 0, CFG.PickupDropStart, nil
local stateRequest, stateCache, nextStateRead
nextStateRead = 0
if type(resumeProgress) == "table" then
    phase = resumeProgress.phase
    lastItems, lastCapacity = resumeProgress.items, resumeProgress.capacity
    lastPickup, lastDestination = resumeProgress.pickup, resumeProgress.destination
end
local session = {}
_G.AD_INSTANCE = session

local function cancelled()
    return stopping or _G.AD_STOP
end
local function validCharacter()
    return character and character == player.Character and character.Parent
        and root and root.Parent == character and humanoid and humanoid.Parent == character
        and humanoid.Health > 0
end
local function disconnectAll(list)
    for _, connection in ipairs(list) do
        pcall(function() connection:Disconnect() end)
    end
    table.clear(list)
end
local function cancelThread(thread)
    if thread and thread ~= coroutine.running() then
        pcall(task.cancel, thread)
    end
end
local function clearStateReader()
    if stateRequest then cancelThread(stateRequest.thread) end
    stateRequest, stateCache, nextStateRead = nil, nil, 0
end
local function releaseMouse()
    if not mousePressed then return true end
    mousePressed = false
    if not vim then return false, "VirtualInputManager không có" end
    return pcall(function()
        vim:SendMouseButtonEvent(CFG.AcceptX, CFG.AcceptY, 0, false, game, 0)
    end)
end
local function removeLift()
    if lift then lift:Destroy(); lift = nil end
    if liftAttachment then liftAttachment:Destroy(); liftAttachment = nil end
end
local function beginFlightControl()
    if not validCharacter() then return false end
    if flightControl and flightHumanoid == humanoid then return true end
    if flightControl and flightHumanoid and flightHumanoid.Parent then
        pcall(function()
            flightHumanoid.PlatformStand = savedPlatformStand == true
            flightHumanoid.AutoRotate = savedAutoRotate ~= false
        end)
    end
    flightControl = true
    flightHumanoid = humanoid
    savedPlatformStand = humanoid.PlatformStand
    savedAutoRotate = humanoid.AutoRotate
    humanoid.Sit = false
    humanoid.PlatformStand = true
    humanoid.AutoRotate = false
    return true
end
local function endFlightControl(freefall)
    local controlled = flightHumanoid
    flightControl, flightHumanoid = false, nil
    if controlled and controlled.Parent then
        pcall(function()
            controlled.PlatformStand = savedPlatformStand == true
            controlled.AutoRotate = savedAutoRotate ~= false
            controlled.Sit = false
            if freefall and not controlled.PlatformStand then
                controlled:ChangeState(Enum.HumanoidStateType.Freefall)
            end
        end)
    end
    savedPlatformStand, savedAutoRotate = nil, nil
end
local function setCollisions(restore)
    for part, original in pairs(parts) do
        if part.Parent then
            local wanted = restore and original or false
            if part.CanCollide ~= wanted then part.CanCollide = wanted end
        else
            parts[part] = nil
        end
    end
end
local function finishMotion()
    removeLift()
    endFlightControl(false)
    landing = false
    noclip = false
    setCollisions(true)
    if root and root.Parent then root.AssemblyLinearVelocity = Vector3.zero end
end
local function resetProgress()
    phase, lastItems, lastCapacity, lastPickup, lastDestination = nil, nil, nil, nil, nil
    pickStuck, destStuck = nil, nil
    pickAttempts, pickDropOffset, pickBaseItems = 0, CFG.PickupDropStart, nil
    nextRemote = 0
    session.Progress = nil
end

local function haltRuntime()
    cancelThread(worker)
    worker = nil
    releaseMouse()
    clearStateReader()
    for _, call in pairs(pending) do cancelThread(call.thread) end
    table.clear(pending)
    finishMotion()
    setCollisions(true)
    traveling, startingJob = false, false
end

local function shutdown()
    disposed = true
    disconnectAll(connections)
    disconnectAll(partConnections)
    haltRuntime()
    if _G.AD_INSTANCE == session then
        _G.AD_STOP = true
        _G.AD_INSTANCE = nil
    end
end

function session.Stop(reason, removeUI)
    if stopping then
        if removeUI and not disposed then
            shutdown()
            if gui.Parent then gui:Destroy() end
        end
        return
    end
    stopping = true
    if _G.AD_INSTANCE == session then _G.AD_STOP = true end
    haltRuntime()
    if canResume and not disposed and not removeUI then
        status(reason or "Đã dừng", COLOR.error)
        setBar(0, COLOR.error)
        setRunButton(false)
        detail("Bấm START để chạy tiếp")
        return
    end
    shutdown()
    status(reason or "Đã dừng", COLOR.error)
    setBar(0, COLOR.error)
    if stopButton and stopButton.Parent then
        stopButton.Text = "STOPPED"
        stopButton.Active = false
        stopButton.AutoButtonColor = false
        stopButton.BackgroundColor3 = Color3.fromRGB(58, 43, 52)
        stopButton.TextColor3 = Color3.fromRGB(140, 124, 134)
        stopStroke.Color = Color3.fromRGB(122, 78, 90)
        stopStroke.Transparency = 0.6
    end
    if removeUI then gui:Destroy() end
end

function session.Start()
    if not stopping or disposed or not canResume then return end
    stopping = false
    _G.AD_STOP = false
    nextTick, nextRemote, nextJob, nextPadScan = 0, 0, 0, 0
    clearStateReader()
    resetProgress()
    status("Đang chạy...", COLOR.start)
    detail("")
    setBar(0, COLOR.idle)
    setRunButton(true)
end

if stopButton then
    connections[#connections + 1] = stopButton.Activated:Connect(function()
        if stopping then
            session.Start()
        else
            session.Stop("Đã dừng từ UI")
        end
    end)
end

local function addPart(part)
    if part:IsA("BasePart") and parts[part] == nil then
        parts[part] = part.CanCollide
    end
end
local function bindCharacter(newCharacter)
    cancelThread(worker)
    worker = nil
    releaseMouse()
    finishMotion()
    setCollisions(true)
    disconnectAll(partConnections)
    table.clear(parts)
    for _, call in pairs(pending) do cancelThread(call.thread) end
    table.clear(pending)
    character, humanoid, root = newCharacter, nil, nil
    traveling, startingJob = false, false
    clearStateReader()
    pickStuck, destStuck, nextRemote = nil, nil, 0
    pickAttempts, pickDropOffset, pickBaseItems = 0, CFG.PickupDropStart, nil
    if not character then return end
    for _, part in ipairs(character:GetDescendants()) do addPart(part) end
    partConnections[#partConnections + 1] = character.DescendantAdded:Connect(addPart)
    partConnections[#partConnections + 1] = character.DescendantRemoving:Connect(function(part)
        local original = parts[part]
        if original ~= nil then
            pcall(function() part.CanCollide = original end)
            parts[part] = nil
        end
    end)
    humanoid = character:FindFirstChildOfClass("Humanoid")
    root = character:FindFirstChild("HumanoidRootPart")
end

connections[#connections + 1] = player.CharacterAdded:Connect(bindCharacter)
connections[#connections + 1] = player.CharacterRemoving:Connect(function(oldCharacter)
    if character == oldCharacter then bindCharacter(nil) end
end)
bindCharacter(player.Character)

connections[#connections + 1] = RunService.Stepped:Connect(function()
    if stopping then return end
    if _G.AD_STOP then session.Stop("Đã dừng"); return end
    if not character then return end
    if not humanoid or humanoid.Parent ~= character then
        humanoid = character:FindFirstChildOfClass("Humanoid")
    end
    if not root or root.Parent ~= character then
        root = character:FindFirstChild("HumanoidRootPart")
    end
    if not validCharacter() then return end
    setCollisions(not noclip)
    if flightControl and flightHumanoid == humanoid and not landing then
        humanoid.Sit = false
        humanoid.PlatformStand = true
        humanoid.AutoRotate = false
    elseif humanoid.Sit then
        humanoid.Sit = false
        humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
    end
end)

local function requireBounded(module, timeout)
    local result, done
    local thread = task.defer(function()
        result = table.pack(pcall(require, module))
        done = true
    end)
    local deadline = os.clock() + timeout
    while not done and not cancelled() and os.clock() < deadline do
        task.wait(CFG.FlyPoll)
    end
    if not done then
        cancelThread(thread)
        return false, "require timeout hoặc đã dừng"
    end
    return table.unpack(result, 1, result.n)
end

local module = RS:FindFirstChild("DeliveryJobTask", true) or RS:WaitForChild("DeliveryJobTask", 10)
local remotes = RS:WaitForChild("Remotes", 10)
if not module or not remotes then
    session.Stop("Thiếu module / Remotes")
    return
end
pickupRemote = remotes:WaitForChild("AttemptDeliveryPickup", 10)
completeRemote = remotes:WaitForChild("AttemptDeliveryComplete", 10)
local required, moduleResult = requireBounded(module, 10)
if cancelled() then session.Stop("Đã dừng"); return end
if not required or type(moduleResult) ~= "table"
    or type(moduleResult.HasActiveDelivery) ~= "function"
    or type(moduleResult.GetCurrentDeliveryState) ~= "function" then
    warn("[AD] DeliveryJobTask không hợp lệ: " .. tostring(moduleResult))
    session.Stop("Không đọc được DeliveryJobTask")
    return
end
jt = moduleResult
local function validRemote(remote)
    return remote and (remote:IsA("RemoteEvent") or remote:IsA("RemoteFunction"))
end
if not validRemote(pickupRemote) or not validRemote(completeRemote) then
    session.Stop("Thiếu remote nhặt / trả")
    return
end
local vimOK, vimResult = pcall(function() return game:GetService("VirtualInputManager") end)
if vimOK then vim = vimResult end

local function readState()
    if cancelled() then return false, nil, nil end
    local now = os.clock()
    if stateRequest and now >= stateRequest.deadline then
        cancelThread(stateRequest.thread)
        stateRequest, stateCache = nil, nil
        nextStateRead = now + 1
        return false, nil, nil
    end
    if not stateRequest and now >= nextStateRead then
        local request = {deadline = now + CFG.StateTimeout}
        stateRequest = request
        nextStateRead = now + CFG.TickInterval
        request.thread = task.defer(function()
            local ok, active, state = pcall(function()
                return jt:HasActiveDelivery(), jt:GetCurrentDeliveryState()
            end)
            if stateRequest == request and not cancelled() then
                local snapshot = state
                if type(state) == "table" then
                    snapshot = {
                        ItemsCarried = state.ItemsCarried,
                        MaxCapacity = state.MaxCapacity,
                        PickupPosition = state.PickupPosition,
                        DestinationPosition = state.DestinationPosition,
                    }
                end
                stateCache = {ok = ok, active = active, state = snapshot, time = os.clock()}
                stateRequest = nil
            end
        end)
    end
    if not stateCache or not stateCache.ok or now - stateCache.time > CFG.StateMaxAge then
        return false, nil, nil
    end
    return true, stateCache.active, stateCache.state
end
local function horizontal(vector)
    return Vector3.new(vector.X, 0, vector.Z)
end
local function xzDistance(a, b)
    return horizontal(a - b).Magnitude
end
local function samePosition(a, b)
    return typeof(a) == "Vector3" and typeof(b) == "Vector3" and (a - b).Magnitude < 1
end
local function pause(seconds)
    local deadline = os.clock() + seconds
    while not cancelled() and os.clock() < deadline do
        task.wait(math.min(CFG.FlyPoll, math.max(0, deadline - os.clock())))
    end
    return not cancelled()
end

local function cruiseSpeed(distance)
    if type(distance) ~= "number" or distance ~= distance or distance < 0 then
        distance = 0
    end
    return CFG.MaxSpeed - (CFG.MaxSpeed - CFG.MinSpeed) * math.exp(-distance / CFG.SpeedCurve)
end

local rayParams
local clearanceProbes = {0.35, 0.7, 1}
local function raycast(origin, direction)
    if typeof(workspace.Raycast) ~= "function" then return nil end
    if not rayParams then
        local created, params = pcall(RaycastParams.new)
        if not created or not params then return nil end
        rayParams = params
        rayParams.FilterType = Enum.RaycastFilterType.Exclude
        rayParams.IgnoreWater = true
        pcall(function() rayParams.RespectCanCollide = true end)
    end
    rayParams.FilterDescendantsInstances = character and {character} or {}
    local ok, hit = pcall(function() return workspace:Raycast(origin, direction, rayParams) end)
    if ok then return hit end
    return nil
end
local function surfaceAheadY(x, z, originY)
    local hit = raycast(Vector3.new(x, originY, z), Vector3.new(0, -(originY + 200), 0))
    if hit then return hit.Position.Y end
    return nil
end
local function clearanceAheadY(position, direction)
    local flat = horizontal(direction)
    if flat.Magnitude < 0.001 then return nil end
    flat = flat.Unit
    local originY = position.Y + 400
    local required
    local wall = raycast(position + Vector3.new(0, 1, 0), flat * CFG.TerrainLookAhead)
    if wall then
        local top = surfaceAheadY(wall.Position.X, wall.Position.Z, originY) or wall.Position.Y
        required = top + CFG.ObstacleClearance
    end
    for _, ratio in ipairs(clearanceProbes) do
        local probe = position + flat * (CFG.TerrainLookAhead * ratio)
        local groundY = surfaceAheadY(probe.X, probe.Z, originY)
        if groundY then
            local need = groundY + CFG.CruiseHeight
            if not required or need > required then required = need end
        end
    end
    return required
end

local function velocityLeg(target, speed, horizontalOnly, avoidTerrain, onProgress)
    if cancelled() or not validCharacter() then return false end
    local movingRoot, start = root, root.Position
    local delta = target - start
    local length = horizontalOnly and horizontal(delta).Magnitude or delta.Magnitude
    local tolerance = horizontalOnly and CFG.ArriveXZ or 2
    if length <= tolerance then return true end
    if delta.Magnitude < 0.001 then return true end
    if not beginFlightControl() then return false end
    landing = false
    noclip = true
    setCollisions(false)
    removeLift()
    liftAttachment = Instance.new("Attachment")
    liftAttachment.Name = "AD_LiftAttachment"
    liftAttachment.Parent = movingRoot
    lift = Instance.new("VectorForce")
    lift.Name = "AD_GravityCompensation"
    lift.Attachment0 = liftAttachment
    lift.RelativeTo = Enum.ActuatorRelativeTo.World
    lift.ApplyAtCenterOfMass = true
    lift.Force = Vector3.new(0, movingRoot.AssemblyMass * workspace.Gravity, 0)
    lift.Parent = movingRoot
    local projectedDirection = horizontalOnly and horizontal(delta).Unit or delta.Unit
    local verticalBoost, slowFactor, nextTerrain, nextReport = 0, 1, 0, 0
    local function applyWanted()
        local wanted
        if horizontalOnly then
            verticalBoost = math.clamp(verticalBoost, 0, math.min(CFG.MaxClimbBoost, speed))
            local flatSpeed = math.sqrt(math.max(speed * speed - verticalBoost * verticalBoost, 0)) * slowFactor
            wanted = projectedDirection * flatSpeed + Vector3.new(0, verticalBoost, 0)
        else
            wanted = projectedDirection * speed
        end
        local current = movingRoot.AssemblyLinearVelocity
        if (current - wanted).Magnitude > speed * 0.12 then
            movingRoot.AssemblyLinearVelocity = wanted
        end
    end
    applyWanted()
    local deadline = os.clock() + math.min(CFG.FlightTimeout, delta.Magnitude / speed * 3 + 4)
    local arrived = false
    while not cancelled() and validCharacter() and root == movingRoot
        and os.clock() < deadline do
        local now = os.clock()
        local position = movingRoot.Position
        local remaining = horizontalOnly and xzDistance(position, target) or (position - target).Magnitude
        if remaining <= tolerance then arrived = true; break end
        local displacement = horizontalOnly and horizontal(position - start) or position - start
        if displacement:Dot(projectedDirection) >= length then
            arrived = true
            break
        end
        if horizontalOnly and avoidTerrain and now >= nextTerrain then
            nextTerrain = now + CFG.TerrainCheck
            local requiredY = clearanceAheadY(position, projectedDirection)
            if requiredY and requiredY > position.Y + 2 then
                local need = requiredY - position.Y
                verticalBoost = math.clamp(need * 3, 40, CFG.MaxClimbBoost)
                if need > 90 then
                    slowFactor = 0.45
                elseif need > 45 then
                    slowFactor = 0.7
                else
                    slowFactor = 1
                end
            else
                verticalBoost, slowFactor = 0, 1
            end
        end
        applyWanted()
        if onProgress and now >= nextReport then
            nextReport = now + 0.25
            onProgress(remaining, speed)
        end
        task.wait(CFG.FlyPoll)
    end
    if movingRoot.Parent then movingRoot.AssemblyLinearVelocity = Vector3.zero end
    removeLift()
    return arrived and not cancelled() and validCharacter() and root == movingRoot
end

local function flyTo(destination, label)
    if typeof(destination) ~= "Vector3" or cancelled() or not validCharacter() then
        return false
    end
    local movingRoot = root
    local start = movingRoot.Position
    local distance = xzDistance(start, destination)
    if distance <= CFG.ArriveXZ and math.abs(start.Y - (destination.Y + 3)) <= 8 then
        return true
    end
    local cruiseY = math.max(start.Y, destination.Y + CFG.CruiseHeight)
    local speed = cruiseSpeed(distance)
    local function report(remaining, currentSpeed)
        if not label then return end
        status(label .. tostring(math.floor(remaining)), nil)
        detail(string.format("còn %d | %d studs/s", math.floor(remaining), math.floor(currentSpeed + 0.5)))
    end
    if start.Y < cruiseY - 2 then
        local climbTarget = Vector3.new(start.X, cruiseY, start.Z)
        if not velocityLeg(climbTarget, CFG.ClimbSpeed, false) then return false end
    end
    if cancelled() or not validCharacter() or root ~= movingRoot then return false end
    local arrived = xzDistance(root.Position, destination) <= CFG.ArriveXZ
    if not arrived then
        local horizontalTarget = Vector3.new(destination.X, root.Position.Y, destination.Z)
        arrived = velocityLeg(horizontalTarget, speed, true, true, report)
    end
    for attempt = 1, 3 do
        if cancelled() or not validCharacter() or root ~= movingRoot then return false end
        if arrived and xzDistance(root.Position, destination) <= CFG.ArriveXZ then break end
        if xzDistance(root.Position, destination) <= CFG.ArriveXZ then arrived = true; break end
        local correction = Vector3.new(destination.X, root.Position.Y, destination.Z)
        arrived = velocityLeg(correction, CFG.CorrectionSpeed, true, false, report)
    end
    if not arrived or cancelled() or not validCharacter() or root ~= movingRoot then
        return false
    end
    local dropY = destination.Y + CFG.LandingDropHeight
    if movingRoot.Position.Y > dropY + 2 then
        local dropTarget = Vector3.new(movingRoot.Position.X, dropY, movingRoot.Position.Z)
        if not velocityLeg(dropTarget, CFG.LandingDropSpeed, false) then return false end
    end
    if cancelled() or not validCharacter() or root ~= movingRoot then return false end
    removeLift()
    movingRoot.AssemblyLinearVelocity = Vector3.zero
    landing = true
    endFlightControl(true)
    local deadline = os.clock() + CFG.LandingTimeout
    local settled = false
    while not cancelled() and validCharacter() and root == movingRoot
        and os.clock() < deadline do
        local falling = movingRoot.AssemblyLinearVelocity
        if falling.Y < -CFG.LandFallSpeed then
            movingRoot.AssemblyLinearVelocity = Vector3.new(0, -CFG.LandFallSpeed, 0)
            falling = movingRoot.AssemblyLinearVelocity
        end
        local position = movingRoot.Position
        local nearXZ = xzDistance(position, destination) <= CFG.ArriveXZ
        local lead = math.clamp(math.abs(falling.Y) * 0.06, 3, 15)
        local nearY = position.Y <= destination.Y + lead
        if nearXZ and nearY then
            movingRoot.AssemblyLinearVelocity = Vector3.zero
            movingRoot.CFrame = CFrame.new(destination.X, destination.Y + 3, destination.Z)
            settled = true
            break
        end
        if position.Y < destination.Y - 6 then break end
        task.wait(CFG.LandPoll)
    end
    noclip = false
    setCollisions(true)
    landing = true
    return settled and not cancelled() and validCharacter() and root == movingRoot
end

local function teleportCharacter(position)
    if cancelled() or not validCharacter() or typeof(position) ~= "Vector3" then
        return false
    end
    local movingRoot = root
    removeLift()
    endFlightControl(false)
    landing = false
    noclip = false
    setCollisions(true)
    movingRoot.AssemblyLinearVelocity = Vector3.zero
    movingRoot.AssemblyAngularVelocity = Vector3.zero
    movingRoot.CFrame = CFrame.new(position.X, position.Y, position.Z)
    if humanoid then
        pcall(function()
            humanoid.Sit = false
            humanoid.PlatformStand = false
            humanoid.AutoRotate = true
            humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
        end)
    end
    return not cancelled() and validCharacter() and root == movingRoot
end

local function teleportPickupReset(target)
    if cancelled() or not validCharacter() or typeof(target) ~= "Vector3" then
        return false
    end
    pickAttempts = pickAttempts + 1
    pickDropOffset = math.min(pickDropOffset + CFG.PickupDropStep, CFG.PickupDropMax)
    status("Kẹt nhặt → teleport ra xa", COLOR.stuck)
    detail(string.format("lần %d | thả cao %d", pickAttempts, pickDropOffset))
    local angle = math.random() * math.pi * 2
    local away = Vector3.new(
        target.X + math.cos(angle) * CFG.PickupResetDistance,
        math.max(target.Y, root.Position.Y) + CFG.PickupResetHeight,
        target.Z + math.sin(angle) * CFG.PickupResetDistance
    )
    if not teleportCharacter(away) then return false end
    if not pause(CFG.PickupResetWait) then return false end
    local drop = Vector3.new(target.X, target.Y + pickDropOffset, target.Z)
    if not teleportCharacter(drop) then return false end
    local landed = false
    local deadline = os.clock() + CFG.PickupSettleTimeout
    while not cancelled() and validCharacter() and os.clock() < deadline do
        local position = root.Position
        local fallSpeed = math.abs(root.AssemblyLinearVelocity.Y)
        local onFloor = false
        if humanoid then
            local ok, floor = pcall(function() return humanoid.FloorMaterial end)
            onFloor = ok and Enum.Material ~= nil and floor ~= nil and floor ~= Enum.Material.Air
        end
        if onFloor or (position.Y <= target.Y + CFG.InteractVertical and fallSpeed < 6) then
            landed = true
            break
        end
        task.wait(0.05)
    end
    detail(string.format("lần %d | thả cao %d | %s", pickAttempts, pickDropOffset,
        landed and "đã chạm đất" or "chờ hạ cánh"))
    return not cancelled() and validCharacter()
end

local function runWorker(kind, action)
    if worker or cancelled() then return end
    startingJob = kind == "start"
    traveling = kind ~= "start"
    worker = task.defer(function()
        local ok, result = pcall(action)
        releaseMouse()
        finishMotion()
        traveling, startingJob, worker = false, false, nil
        pickStuck, destStuck = nil, nil
        nextRemote = os.clock() + 0.20
        if not cancelled() and (not ok or result == false) then
            if not ok then warn("[AD] " .. tostring(result)) end
            status("Thao tác thất bại / timeout", COLOR.error)
            nextTick = os.clock() + 1
        end
    end)
end

local function getPadPosition(container, prompt)
    if not container or not container.Parent or not prompt or not prompt.Parent then return nil end
    local anchor = prompt.Parent
    if anchor:IsA("Attachment") then return anchor.WorldPosition end
    if anchor:IsA("BasePart") then return anchor.Position end
    if anchor:IsA("Model") then
        if anchor.PrimaryPart then return anchor.PrimaryPart.Position end
        for _, part in ipairs(anchor:GetDescendants()) do
            if part:IsA("BasePart") then return part.Position end
        end
    end
    if container:IsA("BasePart") then return container.Position end
    if container:IsA("Model") and container.PrimaryPart then
        return container.PrimaryPart.Position
    end
    for _, part in ipairs(container:GetDescendants()) do
        if part:IsA("BasePart") then return part.Position end
    end
    return nil
end

local function findPad()
    if padContainer and padContainer:IsDescendantOf(workspace) and padPrompt
        and padPrompt:IsDescendantOf(padContainer) then
        local position = getPadPosition(padContainer, padPrompt)
        if typeof(position) == "Vector3" then return position, padPrompt end
    end
    if os.clock() < nextPadScan then return nil end
    nextPadScan = os.clock() + 2
    local gameFolder = workspace:FindFirstChild("Game")
    local jobs = gameFolder and gameFolder:FindFirstChild("Jobs")
    local delivery = jobs and jobs:FindFirstChild("Delivery")
    local locations = delivery and delivery:FindFirstChild("DeliveryLocations")
    if not locations then return nil end
    local best, bestPrompt, bestPosition, bestDistance
    for _, candidate in ipairs(locations:GetDescendants()) do
        if candidate.Name == "DeliveryJobPad" then
            local prompt = candidate:FindFirstChild("JobPadPrompt", true)
            if prompt and prompt:IsA("ProximityPrompt") then
                local position = getPadPosition(candidate, prompt)
                if typeof(position) == "Vector3" then
                    local distance = root and xzDistance(root.Position, position) or 0
                    if not bestDistance or distance < bestDistance then
                        best, bestPrompt, bestPosition, bestDistance = candidate, prompt, position, distance
                    end
                end
            end
        end
    end
    padContainer, padPrompt = best, bestPrompt
    if best then return bestPosition, bestPrompt end
    return nil
end

local function startJob(padPosition, prompt)
    status("Bay đến bảng nhận việc", COLOR.start)
    detail(string.format("Pad %.0f, %.0f, %.0f", padPosition.X, padPosition.Y, padPosition.Z))
    if not flyTo(padPosition, "→ pad ") or cancelled() then return false end
    local stateOK, active = readState()
    if stateOK and active then return true end
    if type(fireproximityprompt) ~= "function" then
        session.Stop("Executor thiếu fireproximityprompt")
        return false
    end
    if not vim then
        session.Stop("Không có VirtualInputManager")
        return false
    end
    local camera = workspace.CurrentCamera
    if camera and (CFG.AcceptX >= camera.ViewportSize.X or CFG.AcceptY >= camera.ViewportSize.Y) then
        detail("Sửa CFG.AcceptX / AcceptY cho màn hình")
        session.Stop("Tọa độ click ngoài màn hình")
        return false
    end
    if not prompt.Parent or not prompt:IsDescendantOf(workspace) then return false end
    local currentPadPosition = getPadPosition(padContainer, prompt)
    if typeof(currentPadPosition) ~= "Vector3"
        or xzDistance(root.Position, currentPadPosition) > CFG.InteractDistance then return false end
    status("Đang nhận job", COLOR.start)
    local promptOK, promptError = pcall(fireproximityprompt, prompt, 0)
    if not promptOK then warn("[AD] Prompt: " .. tostring(promptError)); return false end
    if not pause(CFG.PromptDelay) or not validCharacter() then return false end
    mousePressed = true
    local clickOK, clickError = pcall(function()
        vim:SendMouseButtonEvent(CFG.AcceptX, CFG.AcceptY, 0, true, game, 0)
    end)
    local held = clickOK and pause(CFG.ClickHold)
    local releaseOK, releaseError = releaseMouse()
    if not clickOK or not releaseOK then
        warn("[AD] Click: " .. tostring(clickError or releaseError))
        return false
    end
    if not held or not validCharacter() then return false end
    local deadline = os.clock() + CFG.JobConfirmTimeout
    while not cancelled() and validCharacter() and os.clock() < deadline do
        local ok, hasJob = readState()
        if ok and hasJob then resetProgress(); return true end
        task.wait(0.10)
    end
    return false
end

local function resetZone(center)
    if cancelled() or not validCharacter() then return false end
    status("Kẹt → bay ra...", COLOR.stuck)
    local height = math.max(root.Position.Y, center.Y) + 24
    if not velocityLeg(Vector3.new(root.Position.X, height, root.Position.Z), 60, false) then
        return false
    end
    local angle = math.random() * math.pi * 2
    local offset = Vector3.new(math.cos(angle), 0, math.sin(angle)) * CFG.ResetDistance
    if not velocityLeg(Vector3.new(center.X + offset.X, height, center.Z + offset.Z), 40, true) then
        return false
    end
    if not pause(0.15) then return false end
    status("Kẹt → quay lại...", COLOR.stuck)
    return flyTo(center, "→ quay lại ")
end

local function sendRemote(remote)
    local now = os.clock()
    if cancelled() or pending[remote] or now < nextRemote or not remote.Parent then return end
    nextRemote = now + CFG.RemoteInterval
    local call = {deadline = now + CFG.RemoteTimeout}
    pending[remote] = call
    call.thread = task.defer(function()
        local ok, err = pcall(function()
            if remote:IsA("RemoteEvent") then
                remote:FireServer()
            else
                remote:InvokeServer()
            end
        end)
        if pending[remote] == call then pending[remote] = nil end
        if not ok and not cancelled() then
            warn("[AD] Remote " .. remote.Name .. ": " .. tostring(err))
            status("Remote lỗi; sẽ thử lại", COLOR.error)
        end
    end)
end

local function refreshRemotes()
    local folder = RS:FindFirstChild("Remotes")
    if not folder then return end
    if not (pickupRemote and pickupRemote.Parent) then
        local candidate = folder:FindFirstChild("AttemptDeliveryPickup")
        if validRemote(candidate) then pickupRemote = candidate end
    end
    if not (completeRemote and completeRemote.Parent) then
        local candidate = folder:FindFirstChild("AttemptDeliveryComplete")
        if validRemote(candidate) then completeRemote = candidate end
    end
end

connections[#connections + 1] = RunService.Heartbeat:Connect(function()
    if stopping then return end
    if _G.AD_STOP then session.Stop("Đã dừng"); return end
    local now = os.clock()
    if now < nextTick then return end
    nextTick = now + CFG.TickInterval
    for remote, call in pairs(pending) do
        if now >= call.deadline then
            cancelThread(call.thread)
            pending[remote] = nil
            status("Remote timeout; sẽ thử lại", COLOR.error)
        end
    end
    if traveling or startingJob or worker then return end
    if not validCharacter() then status("Chờ nhân vật...", COLOR.idle); return end
    local ok, active, state = readState()
    if not ok then
        status(stateRequest and "Đang đọc state..." or "Không đọc được state", stateRequest and COLOR.idle or COLOR.error)
        return
    end
    if not active then
        resetProgress()
        setBar(0, COLOR.idle)
        if now < nextJob then return end
        local position, prompt = findPad()
        if not position then status("Chưa tìm thấy DeliveryJobPad", COLOR.error); return end
        nextJob = now + CFG.JobRetryDelay
        runWorker("start", function()
            local result = startJob(position, prompt)
            nextJob = os.clock() + CFG.JobRetryDelay
            return result
        end)
        return
    end
    if type(state) ~= "table" then status("Chờ dữ liệu job...", COLOR.idle); return end
    local items, capacity = state.ItemsCarried, state.MaxCapacity
    local pickup, destination = state.PickupPosition, state.DestinationPosition
    if type(items) ~= "number" or type(capacity) ~= "number"
        or items ~= items or capacity ~= capacity or capacity <= 0 or items < 0
        or items == math.huge or capacity == math.huge then
        status("State thiếu dữ liệu hợp lệ", COLOR.error)
        return
    end
    local pickupChanged = typeof(lastPickup) == "Vector3" and typeof(pickup) == "Vector3"
        and not samePosition(lastPickup, pickup)
    local destinationChanged = typeof(lastDestination) == "Vector3" and typeof(destination) == "Vector3"
        and not samePosition(lastDestination, destination)
    if lastCapacity ~= capacity or pickupChanged then resetProgress() end
    if lastItems ~= items or destinationChanged then pickStuck, destStuck = nil, nil end
    if type(lastItems) == "number" and items > lastItems then
        pickAttempts, pickDropOffset, pickBaseItems = 0, CFG.PickupDropStart, nil
    end
    lastItems, lastCapacity = items, capacity
    if typeof(pickup) == "Vector3" then lastPickup = pickup end
    if typeof(destination) == "Vector3" then lastDestination = destination end
    if items >= capacity then phase = "delivery"
    elseif phase == "delivery" and items == 0 then phase = "pickup"
    elseif phase == nil then phase = "pickup" end
    session.Progress = {
        phase = phase, items = items, capacity = capacity,
        pickup = lastPickup, destination = lastDestination,
    }
    local delivering = phase == "delivery"
    local target
    if delivering then target = destination else target = pickup end
    local color = delivering and COLOR.delivery or COLOR.pickup
    local mode = capacity == 8 and "Hard" or capacity == 4 and "Normal" or "Custom"
    detail(string.format("items %d/%d | %s", items, capacity, mode))
    setBar(items / capacity, color)
    if typeof(target) ~= "Vector3" then
        pickStuck, destStuck = nil, nil
        status(delivering and "Chờ dest..." or "Chờ pickup...", COLOR.idle)
        return
    end
    local distance = xzDistance(root.Position, target)
    local vertical = math.abs(root.Position.Y - (target.Y + 3))
    local landed = false
    if humanoid then
        local floorOK, floor = pcall(function() return humanoid.FloorMaterial end)
        if floorOK and floor ~= nil and Enum.Material ~= nil then
            landed = floor ~= Enum.Material.Air
        end
    end
    if not landed then
        landed = vertical <= CFG.InteractVertical
            and math.abs(root.AssemblyLinearVelocity.Y) < 8
    end
    if distance > CFG.InteractDistance then
        pickStuck, destStuck = nil, nil
        status((delivering and "→ giao " or "→ nhặt ") .. tostring(math.floor(distance)), color)
        runWorker("travel", function()
            return flyTo(target, delivering and "→ giao " or "→ nhặt ")
        end)
        return
    end
    if delivering then
        destStuck = destStuck or now
        pickStuck = nil
        if now - destStuck >= CFG.StuckTimeout then
            runWorker("travel", function() return resetZone(target) end)
            return
        end
    else
        if not landed then
            pickBaseItems, pickStuck = items, nil
            status("Đang hạ cánh...", color)
            return
        end
        if pickBaseItems == nil then pickBaseItems = items end
        if items > pickBaseItems then
            pickAttempts, pickDropOffset = 0, CFG.PickupDropStart
            pickBaseItems, pickStuck = items, now
        elseif pickStuck == nil then
            pickBaseItems, pickStuck = items, now
        end
        if items <= pickBaseItems and now - pickStuck >= CFG.StuckTimeout then
            runWorker("travel", function() return teleportPickupReset(target) end)
            return
        end
    end
    if vertical > CFG.InteractVertical then
        status("Chờ hạ cánh / kiểm tra Y", COLOR.stuck)
        return
    end
    refreshRemotes()
    local remote = delivering and completeRemote or pickupRemote
    if not validRemote(remote) then
        status("Remote nhặt/trả đã mất; chờ tải lại", COLOR.error)
        return
    end
    if delivering then
        status("Đang giao", color)
    else
        local left = math.max(0, CFG.StuckTimeout - (now - (pickStuck or now)))
        if left > 0 then
            status(string.format("Chờ nhặt %.1fs", left), color)
        else
            status("Đang nhặt", color)
        end
    end
    sendRemote(remote)
end)

canResume = true
status("Auto Delivery đã sẵn sàng", COLOR.idle)

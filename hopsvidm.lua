_G.AD_STOP = true
task.wait(0.2)
_G.AD_STOP = false

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local rep = game:GetService("ReplicatedStorage")
local vim = game:GetService("VirtualInputManager")
local plr = Players.LocalPlayer
local jt = require(rep:FindFirstChild("DeliveryJobTask", true))
local remotes = rep.Remotes

local pad = workspace.Game.Jobs.Delivery.DeliveryLocations.DeliveryLocation.DeliveryJobPad
local padPrompt = pad:FindFirstChild("JobPadPrompt", true)
local padPos = Vector3.new(0,0,0)
for _,v in ipairs(pad:GetDescendants()) do
    if v:IsA("BasePart") then padPos=v.Position; break end
end

for _,v in ipairs(plr.PlayerGui:GetChildren()) do
    if v.Name=="AD_UI" or v.Name=="AutoDeliveryUI" or v.Name=="TestUI" then v:Destroy() end
end

local sg=Instance.new("ScreenGui"); sg.Name="AD_UI"; sg.ResetOnSpawn=false; sg.Parent=plr.PlayerGui
local bg=Instance.new("Frame"); bg.Size=UDim2.new(0,240,0,48); bg.Position=UDim2.new(0,10,0,10)
bg.BackgroundColor3=Color3.fromRGB(10,10,18); bg.BorderSizePixel=0; bg.Parent=sg
Instance.new("UICorner",bg).CornerRadius=UDim.new(0,8)
local bar=Instance.new("Frame"); bar.Size=UDim2.new(1,0,0,20)
bar.BackgroundColor3=Color3.fromRGB(90,30,180); bar.BorderSizePixel=0; bar.Parent=bg
Instance.new("UICorner",bar).CornerRadius=UDim.new(0,8)
local ttl=Instance.new("TextLabel"); ttl.Size=UDim2.new(1,0,1,0); ttl.BackgroundTransparency=1
ttl.Text="⚡ AUTO DELIVERY"; ttl.TextColor3=Color3.new(1,1,1)
ttl.Font=Enum.Font.GothamBold; ttl.TextSize=11; ttl.Parent=bar
local l1=Instance.new("TextLabel"); l1.Size=UDim2.new(1,-8,0,14); l1.Position=UDim2.new(0,4,0,21)
l1.BackgroundTransparency=1; l1.TextXAlignment=Enum.TextXAlignment.Left
l1.Font=Enum.Font.Code; l1.TextSize=10; l1.TextColor3=Color3.fromRGB(180,180,180); l1.Parent=bg
local l2=Instance.new("TextLabel"); l2.Size=UDim2.new(1,-8,0,11); l2.Position=UDim2.new(0,4,0,36)
l2.BackgroundTransparency=1; l2.TextXAlignment=Enum.TextXAlignment.Left
l2.Font=Enum.Font.Code; l2.TextSize=9; l2.TextColor3=Color3.fromRGB(110,110,110); l2.Parent=bg
local function s1(m,c) l1.Text=m; l1.TextColor3=c or Color3.fromRGB(180,180,180) end
local function s2(m) l2.Text=m end

local traveling=false
local startingJob=false
local pickStuck=nil
local destStuck=nil
local lastItems=-1

RunService.Stepped:Connect(function()
    if _G.AD_STOP then return end
    local char=plr.Character; if not char then return end
    for _,p in ipairs(char:GetDescendants()) do
        if p:IsA("BasePart") then p.CanCollide=false end
    end
    local hum=char:FindFirstChildOfClass("Humanoid")
    if hum then hum.Sit=false end
end)

local function fly(dest)
    if _G.AD_STOP then traveling=false; return end
    local char=plr.Character; if not char then traveling=false; return end
    local root=char:FindFirstChild("HumanoidRootPart"); if not root then traveling=false; return end
    local sp=root.Position
    local d=math.sqrt((dest.X-sp.X)^2+(dest.Z-sp.Z)^2)
    local spd=d<50 and 80 or d<150 and 120 or d<300 and 180 or 260
    local hi=math.max(sp.Y,dest.Y)+25
    root.CFrame=CFrame.new(sp.X,hi,sp.Z)
    task.wait(math.clamp(0.1+d/2000,0.08,0.35))
    if _G.AD_STOP then traveling=false; return end
    local t=TweenService:Create(root,TweenInfo.new(d/spd,Enum.EasingStyle.Linear),{CFrame=CFrame.new(dest.X,hi,dest.Z)})
    t:Play(); t.Completed:Wait()
    root.CFrame=CFrame.new(dest.X,dest.Y+3,dest.Z)
    task.wait(0.08)
    traveling=false
end

local function resetZone(target)
    traveling=true; pickStuck=nil; destStuck=nil
    s1("Stuck → bay ra...",Color3.fromRGB(255,60,60))
    local char=plr.Character; if not char then traveling=false; return end
    local root=char:FindFirstChild("HumanoidRootPart"); if not root then traveling=false; return end
    local a=math.random()*math.pi*2
    local hi=math.max(root.Position.Y,target.Y)+25
    root.CFrame=CFrame.new(root.Position.X,hi,root.Position.Z)
    task.wait(0.1)
    local t1=TweenService:Create(root,TweenInfo.new(1,Enum.EasingStyle.Linear),
        {CFrame=CFrame.new(target.X+math.cos(a)*30,hi,target.Z+math.sin(a)*30)})
    t1:Play(); t1.Completed:Wait()
    task.wait(0.3)
    s1("Bay vào lại...",Color3.fromRGB(255,170,0))
    local t2=TweenService:Create(root,TweenInfo.new(1,Enum.EasingStyle.Linear),
        {CFrame=CFrame.new(target.X,hi,target.Z)})
    t2:Play(); t2.Completed:Wait()
    root.CFrame=CFrame.new(target.X,target.Y+3,target.Z)
    task.wait(0.1)
    traveling=false
end

local function startJob()
    if startingJob or _G.AD_STOP then return end
    local ok,active=pcall(function() return jt:HasActiveDelivery() end)
    if not (ok and not active) then return end
    startingJob=true; traveling=true
    s1("Bay về pad...",Color3.fromRGB(180,120,255))
    fly(padPos)
    if _G.AD_STOP then startingJob=false; return end
    traveling=true
    task.wait(0.3)
    if padPrompt then fireproximityprompt(padPrompt) end
    task.wait(0.6)
    vim:SendMouseButtonEvent(800,425,0,true,game,0)
    task.wait(0.06)
    vim:SendMouseButtonEvent(800,425,0,false,game,0)
    task.wait(1.5)
    startingJob=false; traveling=false
end

s1("Đang chạy...",Color3.fromRGB(80,220,100))
s2("pad "..string.format("%.0f,%.0f,%.0f",padPos.X,padPos.Y,padPos.Z))

RunService.Heartbeat:Connect(function()
    if _G.AD_STOP or traveling or startingJob then return end
    local char=plr.Character; if not char then return end
    local root=char:FindFirstChild("HumanoidRootPart"); if not root then return end

    local ok,st=pcall(function() return jt:GetCurrentDeliveryState() end)
    if not ok or not st then
        s1("Không có job",Color3.fromRGB(255,140,0))
        pickStuck=nil; destStuck=nil
        task.spawn(startJob)
        task.wait(2); return
    end

    local items=st.ItemsCarried or 0
    local cap=st.MaxCapacity or 4
    local pickup=st.PickupPosition
    local dest=st.DestinationPosition

    s2(string.format("items %d/%d | Hard",items,cap))
    if items~=lastItems then
        lastItems=items; pickStuck=nil; destStuck=nil
    end

    if items < cap then
        destStuck=nil
        if not pickup then s1("Chờ pickup...",Color3.fromRGB(255,200,0)); return end
        local d=(root.Position-pickup).Magnitude
        if d>10 then
            pickStuck=nil; traveling=true
            s1(string.format("→ nhặt  %.0f",d),Color3.fromRGB(80,180,255))
            task.spawn(fly,pickup)
        else
            if not pickStuck then pickStuck=tick() end
            local ss=tick()-pickStuck
            s1(string.format("Nhặt hàng... %.0fs",ss),Color3.fromRGB(255,210,0))
            if ss>=5 then
                task.spawn(resetZone,pickup)
            else
                pcall(function() remotes.AttemptDeliveryPickup:InvokeServer() end)
                task.wait(0.45)
            end
        end
    else
        pickStuck=nil
        if not dest then s1("Chờ dest...",Color3.fromRGB(255,200,0)); destStuck=nil; task.wait(0.5); return end
        local d=(root.Position-dest).Magnitude
        if d>10 then
            destStuck=nil; traveling=true
            s1(string.format("→ giao  %.0f",d),Color3.fromRGB(255,110,50))
            task.spawn(fly,dest)
        else
            if not destStuck then destStuck=tick() end
            local ss=tick()-destStuck
            s1(string.format("Giao hàng... %.0fs",ss),Color3.fromRGB(80,220,80))
            if ss>=5 then
                task.spawn(resetZone,dest)
            else
                pcall(function() remotes.AttemptDeliveryComplete:InvokeServer() end)
                task.wait(0.45)
            end
        end
    end
end)

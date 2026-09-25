local HttpService = game:GetService("HttpService")
local PLACE_ID = game.PlaceId

local function notify(text)
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = "SCAN",
            Text = tostring(text),
            Duration = 5
        })
    end)
    print("[SCAN]", text)
end

local http = nil
if syn and syn.request then http = syn.request
elseif http_request then http = http_request
elseif request then http = request
end

if not http then
    notify("Không có HTTP")
    return
end

notify("Bắt đầu scan")

local url = string.format(
    "https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100",
    PLACE_ID
)

local ok, res = pcall(function()
    return http({ Url = url, Method = "GET" })
end)

if not ok or not res then
    notify("Request fail")
    return
end

local body = res.Body or res.body
local data = HttpService:JSONDecode(body)

local count1 = 0
local count2 = 0
local count3plus = 0
local count0 = 0

for _, s in ipairs(data.data) do
    local pc = s.playing or 0
    if pc == 0 then count0 = count0 + 1
    elseif pc == 1 then count1 = count1 + 1
    elseif pc == 2 then count2 = count2 + 1
    else count3plus = count3plus + 1 end
end

local msg = string.format(
    "Tổng: %d\n0ng: %d · 1ng: %d · 2ng: %d · 3+: %d",
    #data.data, count0, count1, count2, count3plus
)
notify(msg)
print("[SCAN] " .. msg)

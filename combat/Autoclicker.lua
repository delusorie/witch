local cloneref = cloneref or function(f) return f end
local Players = cloneref(game:GetService("Players"))
local UserInputService = cloneref(game:GetService("UserInputService"))
local LocalPlayer = Players.LocalPlayer

local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

pcall(function()
    local OldNamecall
    OldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
        local method = getnamecallmethod()
        if method == "FireServer" and tostring(self) == "AutoclickerDetected" then
            return
        end
        return OldNamecall(self, ...)
    end))
end)

local Settings = {
    NormalEnabled = false,
    PrivateActive = true,
    NormalRange = 9999,
    NormalCPS = 3000,
    IgnoreFriends = true,
    SteambleEnabled = false,

    SpecialEnabled = false,
    SpecialActive = true,
    SpecialRange = 9999,
    SpecialCPS = 3000,
}

local _friendCache = {}
local function cacheFriendship(player)
    if not player or player == LocalPlayer then return end
    task.spawn(function()
        local success, isFriend = pcall(function()
            return LocalPlayer:IsFriendsWith(player.UserId)
        end)
        if success then
            _friendCache[player.UserId] = isFriend
        end
    end)
end

for _, player in ipairs(Players:GetPlayers()) do
    cacheFriendship(player)
end
Players.PlayerAdded:Connect(cacheFriendship)
Players.PlayerRemoving:Connect(function(player)
    _friendCache[player.UserId] = nil
end)

local PlayerScripts = LocalPlayer:WaitForChild("PlayerScripts")
local ModuleScripts = PlayerScripts:WaitForChild("ModuleScripts")
local AbilityHandler = require(ModuleScripts:WaitForChild("AbilityHandler"))
local ClientDebounce = require(ModuleScripts:WaitForChild("ClientDebounce"))

local function getTargetInContact(range)
    local character = LocalPlayer.Character
    if not character then return nil end

    local myRoot = character:FindFirstChild("HumanoidRootPart")
    if not myRoot then return nil end

    local closestTarget = nil
    local shortestDistance = range or 9999
    local entities = workspace:FindFirstChild("Entities")
    local searchGroup = entities and entities:GetChildren() or Players:GetPlayers()

    for _, target in pairs(searchGroup) do
        local targetChar = target:IsA("Player") and target.Character or target
        if targetChar and targetChar ~= character and targetChar:FindFirstChild("HumanoidRootPart") then
            local plr = target:IsA("Player") and target or Players:GetPlayerFromCharacter(targetChar)

            if Settings.IgnoreFriends and plr and _friendCache[plr.UserId] then
                continue
            end

            local h = targetChar:FindFirstChildOfClass("Humanoid")
            if h and h.Health <= 0 then continue end

            local dist = (myRoot.Position - targetChar.HumanoidRootPart.Position).Magnitude
            if dist < shortestDistance then
                shortestDistance = dist
                closestTarget = targetChar
            end
        end
    end
    return closestTarget
end

local function getTargetUnderMouse(range)
    if isMobile then return nil end
    local camera = workspace.CurrentCamera
    local mouse = LocalPlayer:GetMouse()
    local unitRay = camera:ScreenPointToRay(mouse.X, mouse.Y)
    local ray = Ray.new(unitRay.Origin, unitRay.Direction * (range or 9999))
    local ignore = { LocalPlayer.Character or workspace }
    local hit, _pos = workspace:FindPartOnRayWithIgnoreList(ray, ignore)
    if not hit then return nil end

    local model = hit:FindFirstAncestorOfClass("Model")
    if not model then return nil end

    local h = model:FindFirstChildOfClass("Humanoid")
    if not h or h.Health <= 0 then return nil end
    local hrp = model:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end

    local plr = Players:GetPlayerFromCharacter(model)
    if Settings.IgnoreFriends and plr and _friendCache[plr.UserId] then return nil end

    return model
end

local lastNormalTick = tick()
task.spawn(function()
    while true do
        task.wait(0)
        if not Settings.NormalEnabled or not Settings.PrivateActive then
            lastNormalTick = tick()
            continue
        end

        local ability = AbilityHandler.activeAbility
        if not ability then
            lastNormalTick = tick()
            continue
        end

        local abilityName = ability._name
        if abilityName and ClientDebounce.isAlive(abilityName) then
            lastNormalTick = tick()
            continue
        end

        if ability._animTracks and ability._animTracks["activated"] then
            local track = ability._animTracks["activated"]
            if track.IsPlaying then
                lastNormalTick = tick()
                continue
            end
        end

        local now = tick()
        local elapsed = now - lastNormalTick
        local interval = 1 / Settings.NormalCPS

        if elapsed >= interval then
            lastNormalTick = now

            local range = ability._range or 200
            local target
            if Settings.SteambleEnabled and not isMobile then
                target = getTargetUnderMouse(math.min(range, Settings.NormalRange))
            else
                target = getTargetInContact(math.min(range, Settings.NormalRange))
            end

            if target then
                if ability._targetSystem then
                    ability._targetSystem.ValidTarget = target
                end

                ability._isHolding = true
                pcall(function()
                    ability:activated()
                end)
                ability._isHolding = false
            end
        end
    end
end)

local lastSpecialTick = tick()
task.spawn(function()
    while true do
        task.wait(0)
        if not Settings.SpecialEnabled or not Settings.SpecialActive then
            lastSpecialTick = tick()
            continue
        end

        local ability = AbilityHandler.activeAbility
        if not ability then
            lastSpecialTick = tick()
            continue
        end

        local abilityName = ability._name
        if abilityName and ClientDebounce.isAlive(abilityName) then
            lastSpecialTick = tick()
            continue
        end

        if ability._animTracks and ability._animTracks["activated"] then
            local track = ability._animTracks["activated"]
            if track.IsPlaying then
                lastSpecialTick = tick()
                continue
            end
        end

        local now = tick()
        local elapsed = now - lastSpecialTick
        local interval = 1 / Settings.SpecialCPS

        if elapsed >= interval then
            lastSpecialTick = now

            local range = ability._range or 200
            local target = getTargetInContact(math.min(range, Settings.SpecialRange))
            if target then
                if ability._targetSystem then
                    ability._targetSystem.ValidTarget = target
                end

                ability._isHolding = true
                pcall(function()
                    ability:activated()
                end)
                ability._isHolding = false
            end
        end
    end
end)

return Settings

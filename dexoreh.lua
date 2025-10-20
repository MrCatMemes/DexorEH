-- DexorEH V1 Beta Hub - Komplettpaket
-- By MrCatMemes & Steve (mit PoliceTab, RadarFarm & AutoTaser)

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

-- Orion Loader
local OrionLib = loadstring(game:HttpGet("https://pastebin.com/raw/WRUyYTdY"))()
local Window = OrionLib:MakeWindow({
    Name = "DexorEH V1 Beta",
    HidePremium = false,
    SaveConfig = false,
    ConfigFolder = "DexorEH",
    IntroEnabled = true,
    IntroText = "Welcome "..LocalPlayer.Name
})

----------------------------------------------------------------
-- GLOBAL VARS
----------------------------------------------------------------
local ESPEnabled = false
local ESPObjects = {}
local ESPShowNames = true
local ESPShowDistance = false
local ESPFontSize = 14

local AimbotEnabled = false
local AimbotSmoothness = 0
local AimbotPrediction = false
local AimbotFollowMouse = true
local AimbotColor = Color3.fromRGB(255,255,255)

local NoClipEnabled = false
local InfJumpEnabled = false
local AntiAFKEnabled = false
local AntiFall = false

local FlightSpeed = 150
local SpeedKeyMultiplier = 3
local FlyKey = Enum.KeyCode.X
local SpeedKey = Enum.KeyCode.LeftControl
local FlightAcceleration = 4

-- Police Features Vars
local autoTaserEnabled = false
local radarFarmEnabled = false
local lastTase = 0
local AUTO_TASER_INTERVAL = 2.5

----------------------------------------------------------------
-- ESP
----------------------------------------------------------------
local function ClearESP()
    for _,v in pairs(ESPObjects) do
        v:Remove()
    end
    ESPObjects = {}
end

local function GetTeamColor(player)
    if player.Team == nil then return Color3.fromRGB(255,255,255) end
    local teamName = player.Team.Name:lower()
    if teamName:find("police") then
        return Color3.fromRGB(0, 100, 255)
    elseif teamName:find("crime") then
        return Color3.fromRGB(255, 255, 0)
    elseif teamName:find("civil") or teamName:find("citizen") then
        return Color3.fromRGB(0, 255, 0)
    elseif teamName:find("fire") then
        return Color3.fromRGB(255, 0, 0)
    end
    return Color3.fromRGB(255,255,255)
end

local function CreateESP(player)
    if player ~= LocalPlayer then
        local box = Drawing.new("Text")
        box.Text = player.Name
        box.Size = ESPFontSize
        box.Center = true
        box.Outline = true
        box.Color = GetTeamColor(player)
        box.Visible = false
        ESPObjects[player] = box
    end
end

local function UpdateESP()
    if not ESPEnabled then
        ClearESP()
        return
    end
    for _, player in pairs(Players:GetPlayers()) do
        if not ESPObjects[player] then
            CreateESP(player)
        end
    end
    for player,draw in pairs(ESPObjects) do
        if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            local pos, onScreen = Camera:WorldToViewportPoint(player.Character.HumanoidRootPart.Position)
            if onScreen then
                local text = ""
                if ESPShowNames then text = player.Name end
                if ESPShowDistance then
                    local dist = math.floor((Camera.CFrame.Position - player.Character.HumanoidRootPart.Position).Magnitude)
                    text = text.." ["..dist.."m]"
                end
                draw.Text = text
                draw.Size = ESPFontSize
                draw.Color = GetTeamColor(player)
                draw.Position = Vector2.new(pos.X, pos.Y)
                draw.Visible = true
            else
                draw.Visible = false
            end
        else
            draw.Visible = false
        end
    end
end
RunService.RenderStepped:Connect(UpdateESP)

----------------------------------------------------------------
-- Aimbot
----------------------------------------------------------------
local Holding = false
local FOVCircle = Drawing.new("Circle")
FOVCircle.Radius = 100
FOVCircle.Thickness = 1
FOVCircle.Filled = false
FOVCircle.Transparency = 0.7
FOVCircle.Color = AimbotColor
FOVCircle.Visible = false

local function GetClosestPlayer()
    local MaxDist = FOVCircle.Radius
    local Target = nil
    for _,v in pairs(Players:GetPlayers()) do
        if v ~= LocalPlayer and v.Character and v.Character:FindFirstChild("Head") and v.Character:FindFirstChild("Humanoid") and v.Character.Humanoid.Health > 0 then
            local pos, onScreen = Camera:WorldToViewportPoint(v.Character.Head.Position)
            if onScreen then
                local dist = (Vector2.new(
                    (AimbotFollowMouse and UserInputService:GetMouseLocation().X or Camera.ViewportSize.X/2),
                    (AimbotFollowMouse and UserInputService:GetMouseLocation().Y or Camera.ViewportSize.Y/2)
                ) - Vector2.new(pos.X,pos.Y)).Magnitude
                if dist < MaxDist then
                    MaxDist = dist
                    Target = v
                end
            end
        end
    end
    return Target
end

UserInputService.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton2 then
        Holding = true
    end
end)
UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton2 then
        Holding = false
    end
end)

RunService.RenderStepped:Connect(function()
    if AimbotEnabled then
        FOVCircle.Visible = true
        FOVCircle.Color = AimbotColor
        if AimbotFollowMouse then
            FOVCircle.Position = UserInputService:GetMouseLocation()
        else
            FOVCircle.Position = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)
        end
        if Holding then
            local target = GetClosestPlayer()
            if target and target.Character and target.Character:FindFirstChild("Head") then
                local aimPos = target.Character.Head.Position
                if AimbotPrediction and target.Character:FindFirstChild("HumanoidRootPart") then
                    aimPos = aimPos + target.Character.HumanoidRootPart.Velocity/2
                end
                local newCF = CFrame.new(Camera.CFrame.Position, aimPos)
                if AimbotSmoothness > 0 then
                    Camera.CFrame = Camera.CFrame:Lerp(newCF, AimbotSmoothness/100)
                else
                    Camera.CFrame = newCF
                end
            end
        end
    else
        FOVCircle.Visible = false
    end
end)

----------------------------------------------------------------
-- Car Fly
----------------------------------------------------------------
local UserCharacter, UserRootPart, Connection
local CurrentVelocity = Vector3.new(0,0,0)

local function setCharacter(c)
    UserCharacter = c
    UserRootPart = c:WaitForChild("HumanoidRootPart")
end
LocalPlayer.CharacterAdded:Connect(setCharacter)
if LocalPlayer.Character then setCharacter(LocalPlayer.Character) end

local function Flight(delta)
    local BaseVelocity = Vector3.new(0,0,0)
    if not UserInputService:GetFocusedTextBox() then
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then BaseVelocity += Camera.CFrame.LookVector * FlightSpeed end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then BaseVelocity -= Camera.CFrame.RightVector * FlightSpeed end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then BaseVelocity -= Camera.CFrame.LookVector * FlightSpeed end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then BaseVelocity += Camera.CFrame.RightVector * FlightSpeed end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then BaseVelocity += Camera.CFrame.UpVector * FlightSpeed end
        if UserInputService:IsKeyDown(SpeedKey) then BaseVelocity *= SpeedKeyMultiplier end
    end
    if UserRootPart then
        CurrentVelocity = CurrentVelocity:Lerp(BaseVelocity, math.clamp(delta * FlightAcceleration, 0, 1))
        UserRootPart.Velocity = CurrentVelocity + Vector3.new(0,2,0)
        UserRootPart.RotVelocity = Vector3.new(0,0,0)
    end
end

UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode == FlyKey then
        if Connection then
            Connection:Disconnect()
            Connection = nil
            StarterGui:SetCore("SendNotification",{Title="Car Fly",Text="Disabled"})
        else
            CurrentVelocity = UserRootPart.Velocity
            Connection = RunService.Heartbeat:Connect(Flight)
            StarterGui:SetCore("SendNotification",{Title="Car Fly",Text="Enabled (Press X to toggle)"})
        end
    end
end)

----------------------------------------------------------------
-- Enter Own Car
----------------------------------------------------------------
local function GetOwnCar()
    for _, obj in pairs(workspace:GetDescendants()) do
        if obj:IsA("VehicleSeat") or obj:IsA("Seat") then
            if tostring(obj.Parent):find(LocalPlayer.Name) then
                return obj
            end
        end
    end
    return nil
end

local function EnterCar()
    local seat = GetOwnCar()
    if seat and LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid") then
        LocalPlayer.Character:MoveTo(seat.Position + Vector3.new(0,3,0))
        task.wait(0.2)
        seat:Sit(LocalPlayer.Character:FindFirstChildOfClass("Humanoid"))
    else
        warn("No personal vehicle found!")
    end
end

----------------------------------------------------------------
-- Car Mods
----------------------------------------------------------------
local InfiniteFuelEnabled = false
local InfiniteFuelValue = 1e6
local InfiniteFuelInterval = 0.25

local function SetFuelForVehicle(vehicle)
    if not vehicle then return end
    for _,v in pairs(vehicle:GetDescendants()) do
        if v:IsA("NumberValue") or v:IsA("IntValue") then
            if tostring(v.Name):lower():find("fuel") then
                v.Value = InfiniteFuelValue
            end
        end
    end
    local success, attrs = pcall(function() return vehicle:GetAttributes() end)
    if success then
        for attrName,_ in pairs(attrs) do
            if tostring(attrName):lower():find("fuel") then
                vehicle:SetAttribute(attrName, InfiniteFuelValue)
            end
        end
    end
end

local function GetVehicleOfSeat(seat)
    if not seat then return nil end
    return seat:FindFirstAncestorOfClass("Model") or seat.Parent
end

task.spawn(function()
    while true do
        if InfiniteFuelEnabled and LocalPlayer.Character then
            local humanoid = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
            if humanoid and humanoid.SeatPart then
                local vehicle = GetVehicleOfSeat(humanoid.SeatPart)
                if vehicle then SetFuelForVehicle(vehicle) end
            else
                local own = GetOwnCar()
                if own then
                    local veh = GetVehicleOfSeat(own)
                    if veh then SetFuelForVehicle(veh) end
                end
            end
        end
        task.wait(InfiniteFuelInterval)
    end
end)

-- Turbo Accel
local TurboEnabled = false
local TurboForce = 50

local function ApplyTurbo(vehicle, seat)
    if not vehicle or not seat then return end
    local root = vehicle.PrimaryPart or vehicle:FindFirstChildWhichIsA("BasePart")
    if not root then return end
    local vel = root.Velocity
    local forward = seat.CFrame.LookVector
    if UserInputService:IsKeyDown(Enum.KeyCode.W) or UserInputService:IsKeyDown(Enum.KeyCode.S) then
        local newVel = vel + forward * TurboForce
        if newVel.Magnitude > 170 then
            newVel = newVel.Unit * 170
        end
        root.Velocity = Vector3.new(newVel.X, vel.Y, newVel.Z)
    end
end

task.spawn(function()
    while true do
        if TurboEnabled and LocalPlayer.Character then
            local humanoid = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
            if humanoid and humanoid.SeatPart and humanoid.SeatPart:IsA("VehicleSeat") then
                local seat = humanoid.SeatPart
                local vehicle = seat:FindFirstAncestorOfClass("Model")
                if vehicle then
                    ApplyTurbo(vehicle, seat)
                end
            end
        end
        task.wait(0.1)
    end
end)

----------------------------------------------------------------
-- Player
----------------------------------------------------------------
UserInputService.JumpRequest:Connect(function()
    if InfJumpEnabled and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
        LocalPlayer.Character.Humanoid:ChangeState("Jumping")
    end
end)

RunService.Stepped:Connect(function()
    if NoClipEnabled and LocalPlayer.Character then
        for _,part in pairs(LocalPlayer.Character:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = false
            end
        end
    end
    if AntiFall and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
        local root = LocalPlayer.Character.HumanoidRootPart
        if root.Velocity.Y < -50 then
            root.Velocity = Vector3.new(root.Velocity.X, -5, root.Velocity.Z)
        end
    end
end)

local VirtualUser = game:GetService("VirtualUser")
LocalPlayer.Idled:Connect(function()
    if AntiAFKEnabled then
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new())
    end
end)

----------------------------------------------------------------
-- POLICE TAB mit Radar Farm & AutoTaser
----------------------------------------------------------------

local PoliceTab = Window:MakeTab({Name="Police",Icon="rbxassetid://4483345998",PremiumOnly=false})

-- Radar Farm
local _G = _G or getgenv()
_G.RadarFarmEnabled = false

local function startRadarFarm()
    local rs = game:GetService("ReplicatedStorage")
    local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    local hrp = char:WaitForChild("HumanoidRootPart")
    local remote = rs:FindFirstChild("Bnl") and rs.Bnl:FindFirstChild("bbb7c252-304d-4582-b2a0-89eb9d3a0855")
    if not remote then
        warn("Radar Remote not found")
        return
    end

    print("Radar Farm started")
    while _G.RadarFarmEnabled do
        char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
        hrp = char:FindFirstChild("HumanoidRootPart")
        local radarGun = char:FindFirstChild("Radar Gun")
        if radarGun then
            for _, vehicle in ipairs(workspace.Vehicles:GetChildren()) do
                local driveSeat = vehicle:FindFirstChild("DriveSeat")
                if driveSeat and driveSeat.Occupant then
                    local direction = (driveSeat.Position - hrp.Position).Unit
                    pcall(function()
                        remote:FireServer(radarGun, driveSeat.Position, direction)
                    end)
                end
            end
        end
        task.wait(1)
    end
end

local function stopRadarFarm()
    _G.RadarFarmEnabled = false
    print("Radar Farm stopped")
end

PoliceTab:AddToggle({
    Name = "Radar Farm",
    Default = false,
    Callback = function(Value)
        _G.RadarFarmEnabled = Value
        if Value then
            spawn(startRadarFarm)
        else
            stopRadarFarm()
        end
    end
})

-- Auto Taser
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

local REMOTE_FOLDER = "Bnl"
local REMOTE_ID = "c6011f40-2809-4686-a297-33283dd11715"
local AUTO_TASER_INTERVAL = 0.5
local MAX_TASE_RANGE = 80

local function getTaserPosition()
    local char = LocalPlayer.Character
    if not char then return nil, nil end
    local taser = char:FindFirstChild("Taser")
    if taser then
        if taser:IsA("Tool") then
            local handle = taser:FindFirstChild("Handle")
            if handle and handle:IsA("BasePart") then
                return handle.Position, taser
            end
        elseif typeof(taser.Position) == "Vector3" then
            return taser.Position, taser
        end
    end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if hrp and hrp:IsA("BasePart") then
        return hrp.Position, nil
    end
    return nil, nil
end

local function findNearestEnemy(maxRange)
    local pos = getTaserPosition()
    if not pos then return nil end
    local taserPos = pos
    local nearestPlayer, nearestDist
    for _, pl in ipairs(Players:GetPlayers()) do
        if pl ~= LocalPlayer and pl.Team ~= LocalPlayer.Team then
            local char = pl.Character
            local humanoid = char and char:FindFirstChildOfClass("Humanoid")
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            if humanoid and hrp then
                local dist = (hrp.Position - taserPos).Magnitude
                if (not maxRange or dist <= maxRange) and (not nearestDist or dist < nearestDist) then
                    nearestDist = dist
                    nearestPlayer = pl
                end
            end
        end
    end
    return nearestPlayer
end

local function fireTaserAtTarget()
    local taserPos, taserObj = getTaserPosition()
    if not taserPos then return end
    local target = findNearestEnemy(MAX_TASE_RANGE)
    if not target then return end
    local targetChar = target.Character
    if not targetChar then return end
    local hrp = targetChar:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local aimPos = hrp.Position
    local dir = (aimPos - taserPos)
    dir = dir.Magnitude == 0 and Vector3.zero or dir.Unit
    local args = {
        [1] = taserObj,
        [2] = aimPos,
        [3] = dir
    }
    local folder = ReplicatedStorage:FindFirstChild(REMOTE_FOLDER)
    if not folder then return end
    local remote = folder:FindFirstChild(REMOTE_ID)
    if not remote then return end
    if remote:IsA("RemoteEvent") then
        remote:FireServer(unpack(args))
    elseif remote:IsA("RemoteFunction") then
        pcall(function()
            remote:InvokeServer(unpack(args))
        end)
    end
end

local autoEnabled = false
local lastTase = 0

RunService.RenderStepped:Connect(function()
    if autoEnabled and tick() - lastTase >= AUTO_TASER_INTERVAL then
        fireTaserAtTarget()
        lastTase = tick()
    end
end)
-- DexorEH V1 Beta Hub
-- Clean Full Version with Aimbot, ESP, Car Fly, Enter Own Car, Player, Misc, Car Mods

-- Services
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")

local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

-- Orion Loader
local OrionLib = loadstring(game:HttpGet("https://pastebin.com/raw/WRUyYTdY"))()
local Window = OrionLib:MakeWindow({
    Name = "DexorEH V1 Beta",
    HidePremium = false,
    SaveConfig = false,
    ConfigFolder = "DexorEH",
    IntroEnabled = true,
    IntroText = "Welcome "..LocalPlayer.Name
})

----------------------------------------------------------------
-- GLOBAL VARS
----------------------------------------------------------------
local ESPEnabled = false
local ESPObjects = {}
local ESPShowNames = true
local ESPShowDistance = false
local ESPFontSize = 14

local AimbotEnabled = false
local AimbotSmoothness = 0
local AimbotPrediction = false
local AimbotFollowMouse = true
local AimbotColor = Color3.fromRGB(255,255,255)

local NoClipEnabled = false
local InfJumpEnabled = false
local AntiAFKEnabled = false
local AntiFall = false

local FlightSpeed = 150
local SpeedKeyMultiplier = 3
local FlyKey = Enum.KeyCode.X
local SpeedKey = Enum.KeyCode.LeftControl
local FlightAcceleration = 4

----------------------------------------------------------------
-- ESP
----------------------------------------------------------------
local function ClearESP()
    for _,v in pairs(ESPObjects) do
        v:Remove()
    end
    ESPObjects = {}
end

local function GetTeamColor(player)
    if player.Team == nil then return Color3.fromRGB(255,255,255) end
    local teamName = player.Team.Name:lower()
    if teamName:find("police") then
        return Color3.fromRGB(0, 100, 255)
    elseif teamName:find("crime") then
        return Color3.fromRGB(255, 255, 0)
    elseif teamName:find("civil") or teamName:find("citizen") then
        return Color3.fromRGB(0, 255, 0)
    elseif teamName:find("fire") then
        return Color3.fromRGB(255, 0, 0)
    end
    return Color3.fromRGB(255,255,255)
end

local function CreateESP(player)
    if player ~= LocalPlayer then
        local box = Drawing.new("Text")
        box.Text = player.Name
        box.Size = ESPFontSize
        box.Center = true
        box.Outline = true
        box.Color = GetTeamColor(player)
        box.Visible = false
        ESPObjects[player] = box
    end
end

local function UpdateESP()
    if not ESPEnabled then
        ClearESP()
        return
    end
    for _, player in pairs(Players:GetPlayers()) do
        if not ESPObjects[player] then
            CreateESP(player)
        end
    end
    for player,draw in pairs(ESPObjects) do
        if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            local pos, onScreen = Camera:WorldToViewportPoint(player.Character.HumanoidRootPart.Position)
            if onScreen then
                local text = ""
                if ESPShowNames then text = player.Name end
                if ESPShowDistance then
                    local dist = math.floor((Camera.CFrame.Position - player.Character.HumanoidRootPart.Position).Magnitude)
                    text = text.." ["..dist.."m]"
                end
                draw.Text = text
                draw.Size = ESPFontSize
                draw.Color = GetTeamColor(player)
                draw.Position = Vector2.new(pos.X, pos.Y)
                draw.Visible = true
            else
                draw.Visible = false
            end
        else
            draw.Visible = false
        end
    end
end
RunService.RenderStepped:Connect(UpdateESP)

----------------------------------------------------------------
-- Aimbot
----------------------------------------------------------------
local Holding = false
local FOVCircle = Drawing.new("Circle")
FOVCircle.Radius = 100
FOVCircle.Thickness = 1
FOVCircle.Filled = false
FOVCircle.Transparency = 0.7
FOVCircle.Color = AimbotColor
FOVCircle.Visible = false

local function GetClosestPlayer()
    local MaxDist = FOVCircle.Radius
    local Target = nil
    for _,v in pairs(Players:GetPlayers()) do
        if v ~= LocalPlayer and v.Character and v.Character:FindFirstChild("Head") and v.Character:FindFirstChild("Humanoid") and v.Character.Humanoid.Health > 0 then
            local pos, onScreen = Camera:WorldToViewportPoint(v.Character.Head.Position)
            if onScreen then
                local dist = (Vector2.new(
                    (AimbotFollowMouse and UserInputService:GetMouseLocation().X or Camera.ViewportSize.X/2),
                    (AimbotFollowMouse and UserInputService:GetMouseLocation().Y or Camera.ViewportSize.Y/2)
                ) - Vector2.new(pos.X,pos.Y)).Magnitude
                if dist < MaxDist then
                    MaxDist = dist
                    Target = v
                end
            end
        end
    end
    return Target
end

UserInputService.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton2 then
        Holding = true
    end
end)
UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton2 then
        Holding = false
    end
end)

RunService.RenderStepped:Connect(function()
    if AimbotEnabled then
        FOVCircle.Visible = true
        FOVCircle.Color = AimbotColor
        if AimbotFollowMouse then
            FOVCircle.Position = UserInputService:GetMouseLocation()
        else
            FOVCircle.Position = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)
        end
        if Holding then
            local target = GetClosestPlayer()
            if target and target.Character and target.Character:FindFirstChild("Head") then
                local aimPos = target.Character.Head.Position
                if AimbotPrediction and target.Character:FindFirstChild("HumanoidRootPart") then
                    aimPos = aimPos + target.Character.HumanoidRootPart.Velocity/2
                end
                local newCF = CFrame.new(Camera.CFrame.Position, aimPos)
                if AimbotSmoothness > 0 then
                    Camera.CFrame = Camera.CFrame:Lerp(newCF, AimbotSmoothness/100)
                else
                    Camera.CFrame = newCF
                end
            end
        end
    else
        FOVCircle.Visible = false
    end
end)

----------------------------------------------------------------
-- Car Fly
----------------------------------------------------------------
local UserCharacter, UserRootPart, Connection
local CurrentVelocity = Vector3.new(0,0,0)

local function setCharacter(c)
    UserCharacter = c
    UserRootPart = c:WaitForChild("HumanoidRootPart")
end
LocalPlayer.CharacterAdded:Connect(setCharacter)
if LocalPlayer.Character then setCharacter(LocalPlayer.Character) end

local function Flight(delta)
    local BaseVelocity = Vector3.new(0,0,0)
    if not UserInputService:GetFocusedTextBox() then
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then BaseVelocity += Camera.CFrame.LookVector * FlightSpeed end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then BaseVelocity -= Camera.CFrame.RightVector * FlightSpeed end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then BaseVelocity -= Camera.CFrame.LookVector * FlightSpeed end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then BaseVelocity += Camera.CFrame.RightVector * FlightSpeed end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then BaseVelocity += Camera.CFrame.UpVector * FlightSpeed end
        if UserInputService:IsKeyDown(SpeedKey) then BaseVelocity *= SpeedKeyMultiplier end
    end
    if UserRootPart then
        CurrentVelocity = CurrentVelocity:Lerp(BaseVelocity, math.clamp(delta * FlightAcceleration, 0, 1))
        UserRootPart.Velocity = CurrentVelocity + Vector3.new(0,2,0)
        UserRootPart.RotVelocity = Vector3.new(0,0,0)
    end
end

UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode == FlyKey then
        if Connection then
            Connection:Disconnect()
            Connection = nil
            StarterGui:SetCore("SendNotification",{Title="Car Fly",Text="Disabled"})
        else
            CurrentVelocity = UserRootPart.Velocity
            Connection = RunService.Heartbeat:Connect(Flight)
            StarterGui:SetCore("SendNotification",{Title="Car Fly",Text="Enabled (Press X to toggle)"})
        end
    end
end)

----------------------------------------------------------------
-- Enter Own Car
----------------------------------------------------------------
local function GetOwnCar()
    for _, obj in pairs(workspace:GetDescendants()) do
        if obj:IsA("VehicleSeat") or obj:IsA("Seat") then
            if tostring(obj.Parent):find(LocalPlayer.Name) then
                return obj
            end
        end
    end
    return nil
end

local function EnterCar()
    local seat = GetOwnCar()
    if seat and LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid") then
        LocalPlayer.Character:MoveTo(seat.Position + Vector3.new(0,3,0))
        task.wait(0.2)
        seat:Sit(LocalPlayer.Character:FindFirstChildOfClass("Humanoid"))
    else
        warn("No personal vehicle found!")
    end
end

----------------------------------------------------------------
-- Car Mods
----------------------------------------------------------------
-- Infinite Fuel
local InfiniteFuelEnabled = false
local InfiniteFuelValue = 1e6
local InfiniteFuelInterval = 0.25

local function SetFuelForVehicle(vehicle)
    if not vehicle then return end
    for _,v in pairs(vehicle:GetDescendants()) do
        if v:IsA("NumberValue") or v:IsA("IntValue") then
            if tostring(v.Name):lower():find("fuel") then
                v.Value = InfiniteFuelValue
            end
        end
    end
    local success, attrs = pcall(function() return vehicle:GetAttributes() end)
    if success then
        for attrName,_ in pairs(attrs) do
            if tostring(attrName):lower():find("fuel") then
                vehicle:SetAttribute(attrName, InfiniteFuelValue)
            end
        end
    end
end

local function GetVehicleOfSeat(seat)
    if not seat then return nil end
    return seat:FindFirstAncestorOfClass("Model") or seat.Parent
end

task.spawn(function()
    while true do
        if InfiniteFuelEnabled and LocalPlayer.Character then
            local humanoid = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
            if humanoid and humanoid.SeatPart then
                local vehicle = GetVehicleOfSeat(humanoid.SeatPart)
                if vehicle then SetFuelForVehicle(vehicle) end
            else
                local own = GetOwnCar()
                if own then
                    local veh = GetVehicleOfSeat(own)
                    if veh then SetFuelForVehicle(veh) end
                end
            end
        end
        task.wait(InfiniteFuelInterval)
    end
end)

-- Turbo Accel
local TurboEnabled = false
local TurboForce = 50

local function ApplyTurbo(vehicle, seat)
    if not vehicle or not seat then return end
    local root = vehicle.PrimaryPart or vehicle:FindFirstChildWhichIsA("BasePart")
    if not root then return end
    local vel = root.Velocity
    local forward = seat.CFrame.LookVector
    if UserInputService:IsKeyDown(Enum.KeyCode.W) or UserInputService:IsKeyDown(Enum.KeyCode.S) then
        local newVel = vel + forward * TurboForce
        if newVel.Magnitude > 170 then
            newVel = newVel.Unit * 170
        end
        root.Velocity = Vector3.new(newVel.X, vel.Y, newVel.Z)
    end
end

task.spawn(function()
    while true do
        if TurboEnabled and LocalPlayer.Character then
            local humanoid = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
            if humanoid and humanoid.SeatPart and humanoid.SeatPart:IsA("VehicleSeat") then
                local seat = humanoid.SeatPart
                local vehicle = seat:FindFirstAncestorOfClass("Model")
                if vehicle then
                    ApplyTurbo(vehicle, seat)
                end
            end
        end
        task.wait(0.1)
    end
end)

----------------------------------------------------------------
-- Player
----------------------------------------------------------------
UserInputService.JumpRequest:Connect(function()
    if InfJumpEnabled and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
        LocalPlayer.Character.Humanoid:ChangeState("Jumping")
    end
end)

RunService.Stepped:Connect(function()
    if NoClipEnabled and LocalPlayer.Character then
        for _,part in pairs(LocalPlayer.Character:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = false
            end
        end
    end
    if AntiFall and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
        local root = LocalPlayer.Character.HumanoidRootPart
        if root.Velocity.Y < -50 then
            root.Velocity = Vector3.new(root.Velocity.X, -5, root.Velocity.Z)
        end
    end
end)

-- Ganz oben, NACH deinen Services (Players, RunService, etc):

local AntiTaserEnabled = false
local antiTaserConnections = {}
local NORMAL_WALKSPEED = 20
local charAddedConnection

local function disconnectAntiTaser()
    for _, c in ipairs(antiTaserConnections) do
        if c and c.Disconnect then
            pcall(function() c:Disconnect() end)
        end
    end
    antiTaserConnections = {}
    if charAddedConnection then
        charAddedConnection:Disconnect()
        charAddedConnection = nil
    end
end

local function setupAntiTaserForCharacter(char)
    disconnectAntiTaser()
    if not char then return end
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not humanoid then
        humanoid = char:WaitForChild("Humanoid", 5)
        if not humanoid then return end
    end
    table.insert(antiTaserConnections, humanoid.StateChanged:Connect(function(_, new)
        if new == Enum.HumanoidStateType.PlatformStanding or new == Enum.HumanoidStateType.Physics then
            pcall(function()
                humanoid.PlatformStand = false
                humanoid:ChangeState(Enum.HumanoidStateType.Running)
            end)
        end
    end))
    table.insert(antiTaserConnections, RunService.Heartbeat:Connect(function()
        if not humanoid.Parent then return end
        if humanoid.PlatformStand then
            pcall(function() humanoid.PlatformStand = false end)
        end
        if humanoid.WalkSpeed and humanoid.WalkSpeed < NORMAL_WALKSPEED then
            pcall(function() humanoid.WalkSpeed = NORMAL_WALKSPEED end)
        end
        if hrp and hrp.Anchored then
            pcall(function() hrp.Anchored = false end)
        end
    end))
end
----------------------------------------------------------------
-- TABS
----------------------------------------------------------------
-- Aimbot
local AimbotTab = Window:MakeTab({Name="Aimbot",Icon="rbxassetid://4483345998",PremiumOnly=false})
AimbotTab:AddToggle({Name="Enable Aimbot",Default=false,Callback=function(v) AimbotEnabled=v end})
AimbotTab:AddSlider({Name="FOV Radius",Min=50,Max=300,Default=100,Callback=function(v) FOVCircle.Radius=v end})
AimbotTab:AddSlider({Name="Smoothness",Min=0,Max=100,Default=0,Callback=function(v) AimbotSmoothness=v end})
AimbotTab:AddToggle({Name="Prediction",Default=false,Callback=function(v) AimbotPrediction=v end})
AimbotTab:AddToggle({Name="Follow Mouse",Default=true,Callback=function(v) AimbotFollowMouse=v end})
AimbotTab:AddColorpicker({Name="FOV Color",Default=Color3.fromRGB(255,255,255),Callback=function(v) AimbotColor=v end})

-- ESP
local ESPTab = Window:MakeTab({Name="ESP",Icon="rbxassetid://4483345998",PremiumOnly=false})
ESPTab:AddToggle({Name="Enable ESP",Default=false,Callback=function(v) ESPEnabled=v end})
ESPTab:AddToggle({Name="Show Names",Default=true,Callback=function(v) ESPShowNames=v end})
ESPTab:AddToggle({Name="Show Distance",Default=false,Callback=function(v) ESPShowDistance=v end})
ESPTab:AddSlider({Name="Font Size",Min=10,Max=24,Default=14,Callback=function(v) ESPFontSize=v end})

-- Vehicle
local CarTab = Window:MakeTab({Name="Vehicle",Icon="rbxassetid://4483345998",PremiumOnly=false})
CarTab:AddLabel("Tip: Car Fly - Press X to toggle")
CarTab:AddSlider({Name="Car Fly Speed",Min=50,Max=500,Default=150,Callback=function(v) FlightSpeed = v end})
CarTab:AddButton({Name="Enter Own Car",Callback=function() EnterCar() end})

CarTab:AddToggle({
    Name = "Infinite Fuel",
    Default = false,
    Callback = function(v) InfiniteFuelEnabled = v end
})
CarTab:AddToggle({
    Name = "Turbo Accel",
    Default = false,
    Callback = function(v) TurboEnabled = v end
})
CarTab:AddSlider({
    Name = "Turbo Force",
    Min = 10, Max = 200, Default = 50,
    Callback = function(v) TurboForce = v end
})

-- Player
local PlayerTab = Window:MakeTab({Name="Player",Icon="rbxassetid://4483345998",PremiumOnly=false})
PlayerTab:AddToggle({Name="Infinite Jump",Default=false,Callback=function(v) InfJumpEnabled=v end})
PlayerTab:AddToggle({Name="NoClip",Default=false,Callback=function(v) NoClipEnabled=v end})
PlayerTab:AddToggle({Name="Anti Fall",Default=false,Callback=function(v) AntiFall=v end})
PlayerTab:AddToggle({
    Name = "Anti Taser",
    Default = false,
    Callback = function(Value)
        AntiTaserEnabled = Value
        if AntiTaserEnabled then
            setupAntiTaserForCharacter(localPlayer.Character or localPlayer.CharacterAdded:Wait())
            if not charAddedConnection then
                charAddedConnection = localPlayer.CharacterAdded:Connect(function(char)
                    task.wait(0.8)
                    if AntiTaserEnabled then
                        setupAntiTaserForCharacter(char)
                    end
                end)
            end
        else
            disconnectAntiTaser()
        end
    end
})
           
----------------------------------------------------------------
-- POLICE TAB mit Radar Farm & AutoTaser
----------------------------------------------------------------

local PoliceTab = Window:MakeTab({Name="Police",Icon="rbxassetid://4483345998",PremiumOnly=false})

-- Radar Farm
local _G = _G or getgenv()
_G.RadarFarmEnabled = false

local function startRadarFarm()
    local rs = game:GetService("ReplicatedStorage")
    local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    local hrp = char:WaitForChild("HumanoidRootPart")
    local remote = rs:FindFirstChild("Bnl") and rs.Bnl:FindFirstChild("bbb7c252-304d-4582-b2a0-89eb9d3a0855")
    if not remote then
        warn("Radar Remote not found")
        return
    end

    print("Radar Farm started")
    while _G.RadarFarmEnabled do
        char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
        hrp = char:FindFirstChild("HumanoidRootPart")
        local radarGun = char:FindFirstChild("Radar Gun")
        if radarGun then
            for _, vehicle in ipairs(workspace.Vehicles:GetChildren()) do
                local driveSeat = vehicle:FindFirstChild("DriveSeat")
                if driveSeat and driveSeat.Occupant then
                    local direction = (driveSeat.Position - hrp.Position).Unit
                    pcall(function()
                        remote:FireServer(radarGun, driveSeat.Position, direction)
                    end)
                end
            end
        end
        task.wait(1)
    end
end

local function stopRadarFarm()
    _G.RadarFarmEnabled = false
    print("Radar Farm stopped")
end

PoliceTab:AddToggle({
    Name = "Radar Farm",
    Default = false,
    Callback = function(Value)
        _G.RadarFarmEnabled = Value
        if Value then
            spawn(startRadarFarm)
        else
            stopRadarFarm()
        end
    end
})

-- Auto Taser
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

local REMOTE_FOLDER = "Bnl"
local REMOTE_ID = "c6011f40-2809-4686-a297-33283dd11715"
local AUTO_TASER_INTERVAL = 0.5
local MAX_TASE_RANGE = 80

local function getTaserPosition()
    local char = LocalPlayer.Character
    if not char then return nil, nil end
    local taser = char:FindFirstChild("Taser")
    if taser then
        if taser:IsA("Tool") then
            local handle = taser:FindFirstChild("Handle")
            if handle and handle:IsA("BasePart") then
                return handle.Position, taser
            end
        elseif typeof(taser.Position) == "Vector3" then
            return taser.Position, taser
        end
    end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if hrp and hrp:IsA("BasePart") then
        return hrp.Position, nil
    end
    return nil, nil
end

local function findNearestEnemy(maxRange)
    local pos = getTaserPosition()
    if not pos then return nil end
    local taserPos = pos
    local nearestPlayer, nearestDist
    for _, pl in ipairs(Players:GetPlayers()) do
        if pl ~= LocalPlayer and pl.Team ~= LocalPlayer.Team then
            local char = pl.Character
            local humanoid = char and char:FindFirstChildOfClass("Humanoid")
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            if humanoid and hrp then
                local dist = (hrp.Position - taserPos).Magnitude
                if (not maxRange or dist <= maxRange) and (not nearestDist or dist < nearestDist) then
                    nearestDist = dist
                    nearestPlayer = pl
                end
            end
        end
    end
    return nearestPlayer
end

local function fireTaserAtTarget()
    local taserPos, taserObj = getTaserPosition()
    if not taserPos then return end
    local target = findNearestEnemy(MAX_TASE_RANGE)
    if not target then return end
    local targetChar = target.Character
    if not targetChar then return end
    local hrp = targetChar:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local aimPos = hrp.Position
    local dir = (aimPos - taserPos)
    dir = dir.Magnitude == 0 and Vector3.zero or dir.Unit
    local args = {
        [1] = taserObj,
        [2] = aimPos,
        [3] = dir
    }
    local folder = ReplicatedStorage:FindFirstChild(REMOTE_FOLDER)
    if not folder then return end
    local remote = folder:FindFirstChild(REMOTE_ID)
    if not remote then return end
    if remote:IsA("RemoteEvent") then
        remote:FireServer(unpack(args))
    elseif remote:IsA("RemoteFunction") then
        pcall(function()
            remote:InvokeServer(unpack(args))
        end)
    end
end

local autoEnabled = false
local lastTase = 0

RunService.RenderStepped:Connect(function()
    if autoEnabled and tick() - lastTase >= AUTO_TASER_INTERVAL then
        fireTaserAtTarget()
        lastTase = tick()
    end
end)

-- Misc
local MiscTab = Window:MakeTab({Name="Misc",Icon="rbxassetid://4483345998",PremiumOnly=false})
local player = game:GetService("Players").LocalPlayer
local vu = game:GetService("VirtualUser")
local antiAfkEnabled = false
local antiAfkConnection = nil

local function enableAntiAfk()
    if antiAfkConnection then
        antiAfkConnection:Disconnect()
    end
    antiAfkConnection = player.Idled:Connect(function()
        if antiAfkEnabled then
            vu:CaptureController()
            vu:ClickButton2(Vector2.new())
            -- optional kannst du hier Notification machen
            print("Roblox tried kicking you, aber Anti-AFK aktiv!")
        end
    end)
end

-- Dann im UI als Toggle z.B.
MiscTab:AddToggle({
    Name = "Anti-AFK",
    Default = false,
    Callback = function(state)
        antiAfkEnabled = state
        if state then
            enableAntiAfk()
            print("Anti-AFK aktiviert!")
        else
            if antiAfkConnection then
                antiAfkConnection:Disconnect()
                antiAfkConnection = nil
            end
            print("Anti-AFK deaktiviert!")
        end
    end
})

local SelfReviveTab = Window:MakeTab({
    Name = "Self Revive",
    Icon = "rbxassetid://4483345998", -- nimm irgendein Icon, sonst einfach entfernen
    PremiumOnly = false
})
SelfReviveTab:AddParagraph("Bitte warte 1 Minute nach Klick für Heal (OP)", "")

SelfReviveTab:AddButton({
    Name = "Aktiviere Self-Revive",
    Callback = function()
        if game.PlaceId ~= 7711635737 then
            OrionLib:MakeNotification({
                Name = "Fehler",
                Content = "Nur für Emergency Hamburg! (7711635737)",
                Time = 4
            })
            return
        end

        local Players = game:GetService("Players")
        local TweenService = game:GetService("TweenService")
        local Workspace = game:GetService("Workspace")
        local LocalPlayer = Players.LocalPlayer

        local autoReviveEnabled = true
        local healthConnection = nil

        local function tweenTo(destination)
            local VehiclesFolder = Workspace:FindFirstChild("Vehicles")
            local car = VehiclesFolder and VehiclesFolder:FindFirstChild(LocalPlayer.Name)
            if not car then return false end

            car.PrimaryPart = car:FindFirstChild("DriveSeat", true) or car.PrimaryPart
            if car.DriveSeat and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
                pcall(function() car.DriveSeat:Sit(LocalPlayer.Character.Humanoid) end)
            end

            if typeof(destination) == "CFrame" then
                destination = destination.Position
            end

            local function moveTo(targetPosition)
                if not car.PrimaryPart then return end
                local distance = (car.PrimaryPart.Position - targetPosition).Magnitude
                local tweenDuration = math.clamp(distance / 175, 0.05, 20)
                local tweenInfo = TweenInfo.new(tweenDuration, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)

                local value = Instance.new("CFrameValue")
                value.Value = car:GetPivot()

                local con
                con = value.Changed:Connect(function(newCFrame)
                    if car and car.Parent then
                        car:PivotTo(newCFrame)
                        if car:FindFirstChild("DriveSeat") then
                            pcall(function()
                                car.DriveSeat.AssemblyLinearVelocity = Vector3.zero
                                car.DriveSeat.AssemblyAngularVelocity = Vector3.zero
                            end)
                        end
                    else
                        if con then con:Disconnect() end
                    end
                end)

                local success, err = pcall(function()
                    local tween = TweenService:Create(value, tweenInfo, { Value = CFrame.new(targetPosition) })
                    tween:Play()
                    tween.Completed:Wait()
                end)

                if con then con:Disconnect() end
                value:Destroy()
                if not success then
                    warn("tweenTo moveTo error:", err)
                end
            end

            -- smooth Start/End
            pcall(function() moveTo(car.PrimaryPart.Position + Vector3.new(0, -4, 0)) end)
            pcall(function() moveTo(destination + Vector3.new(0, -4, 0)) end)
            pcall(function() moveTo(destination) end)
            return true
        end

        local function autoHealAndReturn(originalPosition)
            local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
            local humanoid = char:FindFirstChild("Humanoid")
            if not humanoid then return false end

            local bed = Workspace:FindFirstChild("Buildings")
                and Workspace.Buildings:FindFirstChild("Hospital")
                and Workspace.Buildings.Hospital:FindFirstChild("HospitalBed")
                and Workspace.Buildings.Hospital.HospitalBed:FindFirstChild("Seat")

            if not bed then
                OrionLib:MakeNotification({
                    Name = "Self-Revive Fehler",
                    Content = "HospitalBed nicht gefunden (Error 404)",
                    Time = 4
                })
                return false
            end

            -- Aus Fahrzeug aussteigen wenn nötig
            if humanoid.Sit then
                humanoid.Sit = false
                humanoid.Jump = true
                task.wait(0.12)
            end

            -- Zum Bett teleportieren (smooth)
            if char:FindFirstChild("HumanoidRootPart") then
                local hrp = char.HumanoidRootPart
                hrp.CFrame = bed.CFrame * CFrame.new(0, 3, 0)
                task.wait(0.18)
                pcall(function()
                    hrp.AssemblyLinearVelocity = Vector3.zero
                    hrp.AssemblyAngularVelocity = Vector3.zero
                end)
                hrp.CFrame = bed.CFrame * CFrame.new(0, 0.5, 0)
                task.wait(0.12)
            end

            -- Sitzen
            local attempts = 0
            while not humanoid.Sit and attempts < 6 do
                pcall(function() bed:Sit(humanoid) end)
                attempts = attempts + 1
                task.wait(0.22)
            end

            -- Warte bis geheilt
            repeat task.wait(0.2) until humanoid.Health >= humanoid.MaxHealth * 0.27

            -- Aufstehen
            humanoid.Sit = false
            humanoid.Jump = true
            task.wait(0.2)

            -- Back to car
            local car = Workspace:FindFirstChild("Vehicles") and Workspace.Vehicles:FindFirstChild(LocalPlayer.Name)
            if car and char:FindFirstChild("HumanoidRootPart") and car:FindFirstChild("DriveSeat") then
                char.HumanoidRootPart.CFrame = car.DriveSeat.CFrame * CFrame.new(0, 2, 0)
                pcall(function() car.DriveSeat:Sit(humanoid) end)
                task.wait(0.12)
                pcall(function() tweenTo(originalPosition) end)
            end

            return true
        end

        local function checkHealthAndTeleport()
            local car = Workspace:FindFirstChild("Vehicles") and Workspace.Vehicles:FindFirstChild(LocalPlayer.Name)
            if not car then
                OrionLib:MakeNotification({
                    Name = "Self-Revive",
                    Content = "Kein Fahrzeug gefunden.",
                    Time = 3
                })
                return
            end

            local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
            local humanoid = char:FindFirstChild("Humanoid")
            if not humanoid then return end

            local success, originalPos = pcall(function() return car:GetPivot().Position end)
            if not success or not originalPos then return end

            local hospital = CFrame.new(-120.30, 5.61, 1077.29) -- fix für EH

            if humanoid.Health <= humanoid.MaxHealth * 0.27 then
                if tweenTo(hospital) then
                    task.wait(1.8)
                    autoHealAndReturn(originalPos)
                end
            else
                OrionLib:MakeNotification({
                    Name = "Self-Revive",
                    Content = "Du bist nicht verletzt – keine Aktion nötig",
                    Time = 3
                })
            end
        end

        -- Aktivierungslogik
        local function enableAutoRevive(val)
            autoReviveEnabled = val
            if val then
                local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
                local humanoid = char:WaitForChild("Humanoid")
                if healthConnection then
                    pcall(function() healthConnection:Disconnect() end)
                    healthConnection = nil
                end
                healthConnection = humanoid.HealthChanged:Connect(function(hp)
                    if autoReviveEnabled and hp <= humanoid.MaxHealth * 0.27 then
                        pcall(function() checkHealthAndTeleport() end)
                    end
                end)
            else
                if healthConnection then
                    pcall(function() healthConnection:Disconnect() end)
                    healthConnection = nil
                end
            end
        end

        -- Respawn Handler
        LocalPlayer.CharacterAdded:Connect(function(char)
            if autoReviveEnabled then
                char:WaitForChild("Humanoid").HealthChanged:Connect(function(hp)
                    if hp <= char.Humanoid.MaxHealth * 0.27 then
                        pcall(function() checkHealthAndTeleport() end)
                    end
                end)
            end
        end)

        -- Start Auto-Revive
        enableAutoRevive(true)

        OrionLib:MakeNotification({
            Name = "Self-Revive aktiviert",
            Content = "Auto-Revive läuft jetzt (vorsichtig verwenden).",
            Time = 5
        })
    end
})

-- Info
local InfoTab = Window:MakeTab({Name="Info",Icon="rbxassetid://4483345998",PremiumOnly=false})
InfoTab:AddLabel("DexorEH V1 Beta")
InfoTab:AddLabel("Made by MrCatMemes")

----------------------------------------------------------------
OrionLib:Init()

-- DexorEH V1 Beta Hub
-- Clean Full Version with Aimbot, ESP, Car Fly, Enter Own Car, Player, Misc

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

-- Player
local PlayerTab = Window:MakeTab({Name="Player",Icon="rbxassetid://4483345998",PremiumOnly=false})
PlayerTab:AddToggle({Name="Infinite Jump",Default=false,Callback=function(v) InfJumpEnabled=v end})
PlayerTab:AddToggle({Name="NoClip",Default=false,Callback=function(v) NoClipEnabled=v end})
PlayerTab:AddToggle({Name="Anti Fall",Default=false,Callback=function(v) AntiFall=v end})

-- Misc
local MiscTab = Window:MakeTab({Name="Misc",Icon="rbxassetid://4483345998",PremiumOnly=false})
MiscTab:AddToggle({Name="Anti AFK",Default=false,Callback=function(v) AntiAFKEnabled=v end})

-- Info
local InfoTab = Window:MakeTab({Name="Info",Icon="rbxassetid://4483345998",PremiumOnly=false})
InfoTab:AddLabel("DexorEH V1 Beta")
InfoTab:AddLabel("Made by MrCatMemes")

----------------------------------------------------------------
OrionLib:Init()

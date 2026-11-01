-- ==========================================
-- Vexari Hub (Lavender Pink + Optimized)
-- ==========================================
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local TextService = game:GetService("TextService")
local CoreGui = game:GetService("CoreGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualInputManager = game:GetService("VirtualInputManager")
local GuiService = game:GetService("GuiService")

local env = (getgenv and getgenv()) or _G
local LocalPlayer = Players.LocalPlayer

-- เคลียร์ของเก่าและปิด Connection ทั้งหมดก่อนเริ่ม
if env.__VexariHubCleanup then
    pcall(env.__VexariHubCleanup)
    env.__VexariHubCleanup = nil
end

local conns = {}
local function track(c) 
    conns[#conns + 1] = c 
    return c 
end

----------------------------------------------------------------
-- 0) LOGIC Aimbot & Moonwalk
----------------------------------------------------------------
local FunState = { Enabled = false, Connection = nil, BaseYaw = 0 }
local AimbotState = { Enabled = false, FOV = 150, TargetPart = "Head", CurrentTarget = nil }

function ToggleFunSpin(state)
    FunState.Enabled = state
    if FunState.Enabled then
        local char = LocalPlayer.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        
        if hum then hum.AutoRotate = false end
        if root then
            local _, currentYaw, _ = root.CFrame:ToEulerAnglesYXZ()
            FunState.BaseYaw = currentYaw
        end

        if not FunState.Connection then
            FunState.Connection = RunService.Heartbeat:Connect(function()
                local c = LocalPlayer.Character
                local r = c and c:FindFirstChild("HumanoidRootPart")
                if r and FunState.Enabled then
                    local sway = math.sin(tick() * 30) * math.rad(25)
                    r.CFrame = CFrame.new(r.Position) * CFrame.Angles(0, FunState.BaseYaw + sway, 0)
                end
            end)
        end
    else
        if FunState.Connection then
            FunState.Connection:Disconnect()
            FunState.Connection = nil
        end
        local char = LocalPlayer.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hum then hum.AutoRotate = true end
    end
end
local toggleRef = ToggleFunSpin

local function GetClosestTarget()
    local cam = workspace.CurrentCamera
    local vp = cam.ViewportSize
    local center = Vector2.new(vp.X / 2, vp.Y / 2)
    local closest = nil
    local minDist = AimbotState.FOV

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character and plr.Character:FindFirstChild(AimbotState.TargetPart) then
            local targetPart = plr.Character[AimbotState.TargetPart]
            local screenPos, onScreen = cam:WorldToViewportPoint(targetPart.Position)
            if onScreen then
                local dist = (Vector2.new(screenPos.X, screenPos.Y) - center).Magnitude
                if dist < minDist then
                    minDist = dist
                    closest = targetPart
                end
            end
        end
    end
    return closest
end

-- อัปเดตเป้าหมายทุก 0.05 วิ
track(task.spawn(function()
    while task.wait(0.05) do
        if AimbotState.Enabled then
            AimbotState.CurrentTarget = GetClosestTarget()
        else
            AimbotState.CurrentTarget = nil
        end
    end
end))

-- หมุนกล้องทุกเฟรม
track(RunService.RenderStepped:Connect(function()
    if AimbotState.Enabled and AimbotState.CurrentTarget then
        local cam = workspace.CurrentCamera
        cam.CFrame = cam.CFrame:Lerp(CFrame.new(cam.CFrame.Position, AimbotState.CurrentTarget.Position), 0.25)
    end
end))

----------------------------------------------------------------
-- 1) โหลด Fluent
----------------------------------------------------------------
local Fluent = loadstring(game:HttpGet("https://raw.githubusercontent.com/StyearX/Fluent-modded/main/dist/main.lua"))()

local Window = Fluent:CreateWindow({
    Title = "Vexari Hub",
    SubTitle = "Premium Interface",
    Icons = "rbxassetid://80322351456283",
    UserInfoTop = true,
    UserInfoTitle = "Vexari",
    UserInfoSubtitle = "@vb4",
    TabWidth = 100,
    Size = UDim2.fromOffset(380, 300),
    Acrylic = false,
    Theme = "Lavender Pink", 
    MinimizeKey = Enum.KeyCode.RightShift,
})

local Options = Fluent.Options

local okTheme, errTheme = pcall(function()
    local SettingsTab = Window:AddTab({ Title = "Settings", Icon = "settings" })
    local themeList = Fluent.Themes
    local currentTheme = Fluent.Theme or "Lavender Pink"
    local defaultIndex = table.find(themeList, currentTheme) or 1

    SettingsTab:AddDropdown("ThemeDropdown", {
        Title = "Theme",
        Description = "เลือกธีมของหน้าต่าง",
        Values = themeList,
        Multi = false,
        Default = defaultIndex,
        Callback = function(value) Fluent:SetTheme(value) end,
    })
    Window:SelectTab(1)
end)

local VisualTab = Window:AddTab({ Title = "ESP", Icon = "eye" })
local CombatTab = Window:AddTab({ Title = "Combat", Icon = "swords" })
local FunTab = Window:AddTab({ Title = "Fun", Icon = "smile" })
-- ==========================================
-- 2) Logic: Team ESP + Charm (อัปเดตทุก 30 วิ)
-- ==========================================
local EspEnabled = false
local function clearAllESP()
    for _, plr in pairs(Players:GetPlayers()) do
        if plr.Character then
            if plr.Character:FindFirstChild("TeamHighlight") then plr.Character.TeamHighlight:Destroy() end
            if plr.Character:FindFirstChild("Head") and plr.Character.Head:FindFirstChild("TeamESP") then plr.Character.Head.TeamESP:Destroy() end
        end
    end
end

local function updateESP()
    clearAllESP()
    if not EspEnabled then return end
    
    for _, plr in pairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character then
            local head = plr.Character:FindFirstChild("Head")
            if plr.Team and head then
                local teamColor = plr.TeamColor.Color
                
                local esp = Instance.new("BillboardGui")
                esp.Name = "TeamESP"; esp.Size = UDim2.new(0, 150, 0, 40)
                esp.StudsOffset = Vector3.new(0, 3, 0); esp.AlwaysOnTop = true; esp.Parent = head
                
                local label = Instance.new("TextLabel")
                label.Name = "Label"; label.Size = UDim2.new(1, 0, 1, 0)
                label.BackgroundTransparency = 1; label.Font = Enum.Font.GothamBold
                label.TextSize = 16; label.TextStrokeTransparency = 0; label.Parent = esp
                label.Text = "[" .. plr.Team.Name .. "] " .. plr.Name
                label.TextColor3 = teamColor
                label.TextStrokeColor3 = Color3.new(teamColor.R * 0.3, teamColor.G * 0.3, teamColor.B * 0.3)
                
                local highlight = Instance.new("Highlight")
                highlight.Name = "TeamHighlight"; highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                highlight.FillColor = teamColor; highlight.OutlineColor = teamColor
                highlight.FillTransparency = 0.8; highlight.OutlineTransparency = 0
                highlight.Parent = plr.Character
            end
        end
    end
end

track(task.spawn(function()
    while task.wait(30) do
        if EspEnabled then pcall(updateESP) end
    end
end))

VisualTab:AddToggle("TeamESP", { Title = "Team ESP + Charm", Description = "มองทะลุกำแพง + เรืองแสงตามสีทีม (อัปเดตทุก 30 วิ)", Default = false })
Options.TeamESP:OnChanged(function()
    EspEnabled = Options.TeamESP.Value
    if EspEnabled then updateESP() else clearAllESP() end
end)

-- ==========================================
-- 3) Logic: Auto Parry
-- ==========================================
local AttackAnims = {
    ["129626174716003"]=true, ["140101491310539"]=true, ["88927390791538"]=true, ["101213085150090"]=true,
    ["108435030989857"]=true, ["89185525343404"]=true, ["83160743983246"]=true, ["98704572602731"]=true,
    ["92960319113695"]=true, ["78719043959654"]=true, ["79591664733486"]=true, ["91619171958082"]=true,
    ["108286715411226"]=true, ["70835133748914"]=true, ["87833180786200"]=true, ["77647134875637"]=true,
    ["126808696786184"]=true, ["111387253672755"]=true, ["83873880822918"]=true, ["113691709436161"]=true,
    ["74099023522626"]=true, ["126081405469607"]=true, ["124706657239027"]=true, ["101968088258360"]=true,
    ["115156433745401"]=true, ["72346764885778"]=true, ["72908958549833"]=true, ["83487501759124"]=true,
    ["136731398826046"]=true, ["78363289630619"]=true, ["130819705183003"]=true, ["136553272065734"]=true,
    ["83511010475014"]=true, ["126782232696074"]=true, ["104228973542429"]=true, ["121845674088602"]=true,
    ["83027040228061"]=true, ["85713585812635"]=true, ["70400864844827"]=true, ["84390193150093"]=true,
    ["75825369929893"]=true, ["103051010112845"]=true, ["128003442585728"]=true, ["110466971021611"]=true,
    ["101474643265724"]=true, ["84065325761108"]=true, ["126526181422628"]=true, ["99837327705528"]=true,
    ["91797648729481"]=true, ["140463265233127"]=true,
}
local ParryState = { Enabled = false, Cooldown = false, Distance = 15 }

local function GetParryRemote()
    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    local items = remotes and remotes:FindFirstChild("Items")
    local dagger = items and items:FindFirstChild("Parrying Dagger")
    return dagger and dagger:FindFirstChild("parry")
end

local function ExecuteParry(reason)
    if not ParryState.Enabled or ParryState.Cooldown then return end
    pcall(function()
        local parryRemote = GetParryRemote()
        if parryRemote then for i = 1, 5 do parryRemote:FireServer() end end
        local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
        local survivorMob = playerGui and playerGui:FindFirstChild("Survivor-mob")
        local parryBtn = survivorMob and survivorMob:FindFirstChild("Controls") and survivorMob.Controls:FindFirstChild("Gui-mob")
        if parryBtn and parryBtn.Visible and firesignal then
            firesignal(parryBtn.MouseButton1Down); task.wait(0.01); firesignal(parryBtn.MouseButton1Up)
        end
        print("[Auto Parry] 🛡️ กด Parry สำเร็จ! (ID:", reason, ")")
    end)
end

task.spawn(function()
    local remotes = ReplicatedStorage:WaitForChild("Remotes", 5)
    local items = remotes and remotes:WaitForChild("Items", 5)
    local dagger = items and items:WaitForChild("Parrying Dagger", 5)
    local parryResult = dagger and dagger:WaitForChild("parryResult", 5)
    if parryResult then
        parryResult.OnClientEvent:Connect(function(success, cdTime)
            local cd = tonumber(cdTime) or 60
            ParryState.Cooldown = true
            print("[Auto Parry] ⏳ ติดคูลดาวน์", cd, "วิ")
            task.delay(cd, function() ParryState.Cooldown = false; print("[Auto Parry] 🔄 พร้อมใช้งานอีกครั้ง") end)
        end)
    end
end)

local Attached = {}
local function AttachParrySensor(plr)
    if plr == LocalPlayer or not plr.Character or Attached[plr] then return end
    if not (plr.Team and plr.Team.Name == "Killer") then return end
    Attached[plr] = true
    local humanoid = plr.Character:FindFirstChild("Humanoid")
    local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
    if animator then
        track(animator.AnimationPlayed:Connect(function(track)
            if not ParryState.Enabled or ParryState.Cooldown then return end
            local animId = track.Animation and track.Animation.AnimationId
            if not animId then return end
            local cleanId = tostring(animId):match("%d+")
            if cleanId and AttackAnims[cleanId] then
                local myRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                local kRoot = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
                if myRoot and kRoot then
                    if (myRoot.Position - kRoot.Position).Magnitude <= ParryState.Distance then ExecuteParry(cleanId) end
                else ExecuteParry(cleanId) end
            end
        end))
    end
end

for _, plr in ipairs(Players:GetPlayers()) do
    AttachParrySensor(plr)
    track(plr.CharacterAdded:Connect(function() Attached[plr] = nil; AttachParrySensor(plr) end))
    track(plr:GetPropertyChangedSignal("Team"):Connect(function() Attached[plr] = nil; AttachParrySensor(plr) end))
end
track(Players.PlayerAdded:Connect(function(plr)
    track(plr.CharacterAdded:Connect(function() Attached[plr] = nil; AttachParrySensor(plr) end))
    track(plr:GetPropertyChangedSignal("Team"):Connect(function() Attached[plr] = nil; AttachParrySensor(plr) end))
end))

CombatTab:AddToggle("AutoParry", { Title = "Auto Parry", Description = "บล็อกอัตโนมัติเมื่อ Killer เงื้อมือ", Default = false })
Options.AutoParry:OnChanged(function()
    ParryState.Enabled = Options.AutoParry.Value
    if not ParryState.Enabled then ParryState.Cooldown = false end
end)

CombatTab:AddSlider("ParryDist", { Title = "ระยะการ Parry", Description = "ระยะห่างที่ยอมให้ Parry", Default = 15, Min = 5, Max = 30, Rounding = 0 })
Options.ParryDist:OnChanged(function() ParryState.Distance = Options.ParryDist.Value end)
-- ==========================================
-- 4) Logic: Auto Skillcheck (เวอร์ชันแม่นยำ)
-- ==========================================
local AutoSkill = {
    Enabled = false, Mode = "Perfect",
    LastGoalRotation = nil, HasClickedThisGoal = false, LastLineRotation = nil, LastTick = nil, WasActive = false,
    PerfectLastGoalRotation = nil, PerfectHasClickedThisGoal = false, PerfectLastLineRotation = nil, PerfectLastTick = nil, PerfectWasActive = false,
    InstantHasClicked = false,
}

local function PressSkill()
    local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
    if isMobile then
        local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
        local btn = playerGui and playerGui:FindFirstChild("check", true)
        if btn and btn:IsA("GuiObject") then
            local pos, size = btn.AbsolutePosition, btn.AbsoluteSize
            local inset = GuiService:GetGuiInset()
            local x, y = pos.X + (size.X / 2) + inset.X, pos.Y + (size.Y / 2) + inset.Y
            pcall(function() VirtualInputManager:SendTouchEvent(8822, Enum.UserInputState.Begin.Value, x, y) end)
            task.wait(0.01)
            pcall(function() VirtualInputManager:SendTouchEvent(8822, Enum.UserInputState.End.Value, x, y) end)
            pcall(function() if firesignal and btn.MouseButton1Click then firesignal(btn.MouseButton1Click) end end)
        end
    else
        pcall(function() VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Space, false, game) end)
        task.wait(0.01)
        pcall(function() VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Space, false, game) end)
    end
end

local function GetSkillCheck()
    local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
    if not playerGui then return nil end
    for _, guiName in ipairs({ "SkillCheckPromptGui", "SkillCheckPromptGui-con" }) do
        local gui = playerGui:FindFirstChild(guiName, true)
        if gui then
            local check = gui:FindFirstChild("Check", true)
            if check and check.Visible then
                local line, goal = check:FindFirstChild("Line", true), check:FindFirstChild("Goal", true)
                if line and goal then return line, goal end
            end
        end
    end
    return nil
end

local function AngularDelta(from, to)
    local d = to - from
    if d > 180 then d = d - 360 end
    if d < -180 then d = d + 360 end
    return d
end

local function CrossedZone(prevLr, lr, startPos, endPos)
    local function inZone(r) if startPos > endPos then return r >= startPos or r <= endPos end return r >= startPos and r <= endPos end
    if inZone(lr) then return true end
    if prevLr == nil then return false end
    local delta = AngularDelta(prevLr, lr)
    local steps = math.abs(math.floor(delta))
    if steps < 2 then return false end
    local stepSize = delta / steps
    for i = 1, steps do if inZone((prevLr + stepSize * i) % 360) then return true end end
    return false
end

local function NormalSkillcheckUpdate()
    local line, goal = GetSkillCheck()
    if not (line and goal) then
        AutoSkill.LastGoalRotation, AutoSkill.HasClickedThisGoal, AutoSkill.LastLineRotation, AutoSkill.LastTick, AutoSkill.WasActive = nil, false, nil, nil, false
        return
    end
    local lr, gr, now = line.Rotation % 360, goal.Rotation % 360, os.clock()
    if not AutoSkill.WasActive then
        AutoSkill.WasActive, AutoSkill.HasClickedThisGoal, AutoSkill.LastGoalRotation, AutoSkill.LastLineRotation, AutoSkill.LastTick = true, false, gr, lr, now
        return
    end
    if AutoSkill.LastGoalRotation and math.abs(AngularDelta(AutoSkill.LastGoalRotation, gr)) > 5 then
        AutoSkill.HasClickedThisGoal, AutoSkill.LastLineRotation, AutoSkill.LastTick = false, nil, nil
    end
    AutoSkill.LastGoalRotation = gr
    if AutoSkill.HasClickedThisGoal then AutoSkill.LastLineRotation, AutoSkill.LastTick = lr, now; return end
    if AutoSkill.LastLineRotation and AutoSkill.LastTick then
        local dt = now - AutoSkill.LastTick
        if dt > 0 then
            local lineSpeed = AngularDelta(AutoSkill.LastLineRotation, lr) / dt
            local predicted = (lr + lineSpeed * dt * 0) % 360
            if CrossedZone(AutoSkill.LastLineRotation, predicted, (gr + 104) % 360, (gr + 109) % 360) then
                AutoSkill.HasClickedThisGoal = true
                task.spawn(function() task.wait(0.03) PressSkill() end)
            end
        end
    end
    AutoSkill.LastLineRotation, AutoSkill.LastTick = lr, now
end

local function PerfectSkillcheckUpdate()
    local line, goal = GetSkillCheck()
    if not (line and goal) then
        AutoSkill.PerfectLastGoalRotation, AutoSkill.PerfectHasClickedThisGoal, AutoSkill.PerfectLastLineRotation, AutoSkill.PerfectLastTick, AutoSkill.PerfectWasActive = nil, false, nil, nil, false
        return
    end
    local lr, gr, now = line.Rotation % 360, goal.Rotation % 360, os.clock()
    if not AutoSkill.PerfectWasActive then
        AutoSkill.PerfectWasActive, AutoSkill.PerfectHasClickedThisGoal, AutoSkill.PerfectLastGoalRotation, AutoSkill.PerfectLastLineRotation, AutoSkill.PerfectLastTick = true, false, gr, lr, now
        return
    end
    if AutoSkill.PerfectLastGoalRotation and math.abs(AngularDelta(AutoSkill.PerfectLastGoalRotation, gr)) > 5 then
        AutoSkill.PerfectHasClickedThisGoal, AutoSkill.PerfectLastLineRotation, AutoSkill.PerfectLastTick = false, nil, nil
    end
    AutoSkill.PerfectLastGoalRotation = gr
    if AutoSkill.PerfectHasClickedThisGoal then AutoSkill.PerfectLastLineRotation, AutoSkill.PerfectLastTick = lr, now; return end
    if AutoSkill.PerfectLastLineRotation and AutoSkill.PerfectLastTick then
        local dt = now - AutoSkill.PerfectLastTick
        if dt > 0 then
            local lineSpeed = AngularDelta(AutoSkill.PerfectLastLineRotation, lr) / dt
            local predicted = (lr + lineSpeed * dt * 0) % 360
            if CrossedZone(AutoSkill.PerfectLastLineRotation, predicted, (gr + 104) % 360, (gr + 108) % 360) then
                AutoSkill.PerfectHasClickedThisGoal = true
                PressSkill()
            end
        end
    end
    AutoSkill.PerfectLastLineRotation, AutoSkill.PerfectLastTick = lr, now
end

local function InstantSkillcheckUpdate()
    if AutoSkill.InstantHasClicked then return end
    local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
    local prompt = playerGui and (playerGui:FindFirstChild("SkillCheckPromptGui") or playerGui:FindFirstChild("SkillCheckPromptGui-con"))
    if not prompt then return end
    local check = prompt:FindFirstChild("Check")
    if not check or not check.Visible then return end
    local line, goal = check:FindFirstChild("Line"), check:FindFirstChild("Goal")
    if not line or not goal then return end
    line.Rotation = goal.Rotation + 109
    AutoSkill.InstantHasClicked = true
    task.spawn(function() PressSkill(); task.wait(0.2); AutoSkill.InstantHasClicked = false end)
end

track(RunService.RenderStepped:Connect(function()
    if not AutoSkill.Enabled then return end
    if AutoSkill.Mode == "Perfect" then PerfectSkillcheckUpdate()
    elseif AutoSkill.Mode == "Instant" then InstantSkillcheckUpdate()
    else NormalSkillcheckUpdate() end
end))

CombatTab:AddToggle("AutoSkill", { Title = "Auto Skillcheck", Description = "กดสกิลเช็คอัตโนมัติ", Default = false })
Options.AutoSkill:OnChanged(function() AutoSkill.Enabled = Options.AutoSkill.Value end)
CombatTab:AddDropdown("SkillMode", { Title = "โหมดการกด", Description = "Perfect = แม่นยำ, Instant = โกงความเร็ว", Values = { "Normal", "Perfect", "Instant" }, Multi = false, Default = "Perfect" })
Options.SkillMode:OnChanged(function() AutoSkill.Mode = Options.SkillMode.Value end)

-- ==========================================
-- 5) Aimbot UI & FOV Circle
-- ==========================================
local FovGui = Instance.new("ScreenGui")
FovGui.Name = "VexariFOV"
FovGui.ResetOnSpawn = false
FovGui.IgnoreGuiInset = true
FovGui.Parent = CoreGui

local FovCircle = Instance.new("Frame")
FovCircle.AnchorPoint = Vector2.new(0.5, 0.5)
FovCircle.Position = UDim2.fromScale(0.5, 0.5)
FovCircle.Size = UDim2.fromOffset(AimbotState.FOV * 2, AimbotState.FOV * 2)
FovCircle.BackgroundTransparency = 1
FovCircle.Visible = false
FovCircle.Parent = FovGui
local FovCorner = Instance.new("UICorner", FovCircle)
FovCorner.CornerRadius = UDim.new(1, 0)

local FovStroke = Instance.new("UIStroke", FovCircle)
FovStroke.Color = Color3.fromRGB(255, 255, 255)
FovStroke.Thickness = 1.5
FovStroke.Transparency = 0.2

CombatTab:AddSlider("FOVRadius", {
    Title = "FOV Radius", Description = "ขนาดวง FOV",
    Default = 150, Min = 50, Max = 500, Rounding = 0,
    Callback = function(val)
        AimbotState.FOV = val
        FovCircle.Size = UDim2.fromOffset(val * 2, val * 2)
    end
})
CombatTab:AddToggle("ShowAimBtn", { Title = "Show Aimbot Button", Description = "เปิดเพื่อแสดงปุ่มลอย Aimbot", Default = false })

Fluent:Notify({ Title = "Vexari Hub", Content = "โหลดระบบทั้งหมดสำเร็จ!", Duration = 4 })

----------------------------------------------------------------
-- 6) ระบบ UI ลอย
----------------------------------------------------------------
local C = {
    Lav    = Color3.fromRGB(196, 167, 255),
    Violet = Color3.fromRGB(139, 92, 246),
    Deep   = Color3.fromRGB(76, 29, 149),
    Night  = Color3.fromRGB(18, 10, 38),
    White  = Color3.fromRGB(255, 255, 255),
}
local REST_STROKE_T = 0.2

local function new(class, props, parent) local inst = Instance.new(class) for k, v in pairs(props or {}) do inst[k] = v end if parent then inst.Parent = parent end return inst end
local function tween(inst, info, goal) local t = TweenService:Create(inst, info, goal) t:Play() return t end

local function getRoot() local ok, root = pcall(function() return Window.Root end) if ok and typeof(root) == "Instance" then return root end ok, root = pcall(function() return Fluent.WindowFrame end) if ok and typeof(root) == "Instance" then return root end return nil end
local function isOpen() local root = getRoot() if root then return root.Visible end local ok, minimized = pcall(function() return Window.Minimized end) if ok and type(minimized) == "boolean" then return not minimized end return true end
local function setOpen(state) local root = getRoot() if root then root.Visible = state pcall(function() Window.Minimized = not state end) return end local ok, gui = pcall(function() return Fluent.GUI end) if ok and typeof(gui) == "Instance" then gui.Enabled = state return end if isOpen() ~= state then pcall(function() Window:Minimize() end) end end
local function toggle() if Fluent.Unloaded then if env.__VexariHubCleanup then env.__VexariHubCleanup() end return end setOpen(not isOpen()) end

local function loopGradient(gradient, time)
    track(task.spawn(function()
        while gradient and gradient.Parent do
            gradient.Rotation = 0
            local tw = TweenService:Create(gradient, TweenInfo.new(time, Enum.EasingStyle.Linear), {Rotation = 360})
            tw:Play()
            tw.Completed:Wait()
        end
    end))
end

-- Minimize Capsule
local M_IconId    = "rbxassetid://80322351456283"
local M_BrandText = "Vexari"
local M_BgColor   = Color3.fromRGB(46, 18, 104)
local M_BgTrans   = 0.8
local M_DragDist  = 8
local H, ICON, PAD_L, GAP, PAD_R, TEXT_SIZE = 34, 22, 8, 7, 15, 14
local textW = 46
pcall(function() textW = math.ceil(TextService:GetTextSize(M_BrandText, TEXT_SIZE, Enum.Font.GothamBold, Vector2.new(400, 40)).X) end)
local W = PAD_L + ICON + GAP + textW + PAD_R
local function viewport() local cam = workspace.CurrentCamera return cam and cam.ViewportSize or Vector2.new(800, 400) end
local function clampXY(x, y) local vp = viewport() local hw, hh = W / 2 + 4, H / 2 + 4 return math.clamp(x, hw, math.max(hw, vp.X - hw)), math.clamp(y, hh, math.max(hh, vp.Y - hh)) end

local MinGui = new("ScreenGui", { Name = "VXM_" .. tostring(math.random(100000, 999999)), ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 999, ZIndexBehavior = Enum.ZIndexBehavior.Sibling })
if gethui then pcall(function() MinGui.Parent = gethui() end) end
if not MinGui.Parent then pcall(function() MinGui.Parent = CoreGui end) end
if not MinGui.Parent then MinGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

local saved = env.__VexariMinPos
local startX, startY
if typeof(saved) == "Vector2" then startX, startY = clampXY(saved.X, saved.Y) else startX, startY = clampXY(16 + W / 2, 150) end

local Button = new("TextButton", { Name = "Capsule", AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(W, H), Position = UDim2.fromOffset(startX, startY), BackgroundColor3 = M_BgColor, BackgroundTransparency = M_BgTrans, BorderSizePixel = 0, AutoButtonColor = false, Active = true, Text = "" }, MinGui)
new("UICorner", { CornerRadius = UDim.new(1, 0) }, Button)
local Scale = new("UIScale", { Scale = 0 }, Button)
local Stroke = new("UIStroke", { Color = C.White, Thickness = 1.5, Transparency = REST_STROKE_T, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, Button)
local StrokeGrad = new("UIGradient", { Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, C.Lav), ColorSequenceKeypoint.new(0.35, C.Violet), ColorSequenceKeypoint.new(0.7, C.Deep), ColorSequenceKeypoint.new(1, C.Lav) }), Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.45, 0.2), NumberSequenceKeypoint.new(0.75, 0.8), NumberSequenceKeypoint.new(1, 0) }) }, Stroke)
loopGradient(StrokeGrad, 3)

local Icon = new("ImageLabel", { Name = "Icon", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, PAD_L, 0.5, 0), Size = UDim2.fromOffset(ICON, ICON), BackgroundTransparency = 1, Image = M_IconId, ScaleType = Enum.ScaleType.Fit, ZIndex = 2 }, Button)
new("TextLabel", { Name = "Label", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, PAD_L + ICON + GAP, 0.5, 0), Size = UDim2.fromOffset(textW + 2, H), BackgroundTransparency = 1, Text = M_BrandText, TextColor3 = C.White, TextXAlignment = Enum.TextXAlignment.Left, Font = Enum.Font.GothamBold, TextSize = TEXT_SIZE, TextStrokeColor3 = C.Night, TextStrokeTransparency = 0.7, ZIndex = 2 }, Button)

local boost = 0
local iconTween
local function animateIcon(open)
    boost = 1
    local target = open and 360 or 0
    if iconTween then iconTween:Cancel() end
    local dist = math.abs(target - Icon.Rotation)
    if dist < 1 then Icon.Rotation = target return end
    local dur = math.max(0.3, 0.75 * dist / 360)
    local mine = tween(Icon, TweenInfo.new(dur, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Rotation = target })
    iconTween = mine
    mine.Completed:Connect(function(state) if state == Enum.PlaybackState.Completed and iconTween == mine then Icon.Rotation = target end end)
end

local function pressIn() local info = TweenInfo.new(0.09, Enum.EasingStyle.Quad, Enum.EasingDirection.Out) tween(Scale, info, { Scale = 0.9 }) tween(Button, info, { BackgroundTransparency = M_BgTrans - 0.2 }) tween(Stroke, info, { Transparency = 0, Thickness = 2.2 }) end
local function pressOut() tween(Scale, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }) local info = TweenInfo.new(0.35, Enum.EasingStyle.Quint, Enum.EasingDirection.Out) tween(Button, info, { BackgroundTransparency = M_BgTrans }) tween(Stroke, info, { Transparency = REST_STROKE_T, Thickness = 1.5 }) end

local minRoot = getRoot()
local function readOpen() if minRoot then return minRoot.Visible end return isOpen() end
local shown = readOpen()
Icon.Rotation = shown and 360 or 0
tween(Scale, TweenInfo.new(0.6, Enum.EasingStyle.Back, Enum.EasingDirection.Out, 0, false, 0.1), { Scale = 1 })

track(RunService.Heartbeat:Connect(function()
    local open = readOpen()
    if open ~= shown then shown = open animateIcon(open) end
end))

local activeInput, dragStart, buttonStart, dragging
track(Button.InputBegan:Connect(function(input)
    if activeInput then return end
    local t = input.UserInputType
    if t ~= Enum.UserInputType.Touch and t ~= Enum.UserInputType.MouseButton1 then return end
    activeInput = input; dragStart = Vector2.new(input.Position.X, input.Position.Y); buttonStart = Button.Position; dragging = false
    pressIn()
    local conn
    conn = input.Changed:Connect(function()
        if input.UserInputState ~= Enum.UserInputState.End then return end
        conn:Disconnect(); if activeInput ~= input then return end; activeInput = nil
        pressOut()
        if dragging then
            dragging = false
            env.__VexariMinPos = Vector2.new(Button.Position.X.Offset, Button.Position.Y.Offset)
        else
            toggle()
        end
    end)
end))

track(UserInputService.InputChanged:Connect(function(input)
    if not activeInput then return end
    if input ~= activeInput and input.UserInputType ~= Enum.UserInputType.MouseMovement then return end
    local delta = Vector2.new(input.Position.X, input.Position.Y) - dragStart
    if not dragging and delta.Magnitude >= M_DragDist then
        dragging = true
        tween(Scale, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1.06 })
    end
    if dragging then
        local x, y = clampXY(buttonStart.X.Offset + delta.X, buttonStart.Y.Offset + delta.Y)
        Button.Position = UDim2.fromOffset(x, y)
    end
end))

-- FAB Moonwalk
local FAB_TEXT = "Moonwalk"
local FAB_SIZE = 56
local FAB_RADIUS = 16
local FAB_TEXT_SIZE = 16
local TEXT_OFF = Color3.fromRGB(205, 195, 230)
local tw = 40
pcall(function() tw = math.ceil(TextService:GetTextSize(FAB_TEXT, FAB_TEXT_SIZE, Enum.Font.GothamBold, Vector2.new(400, 40)).X) end)
local FW = math.max(FAB_SIZE, tw + 28)
local FH = FAB_SIZE
local function fabClamp(x, y) local vp = viewport() local hw, hh = FW / 2 + 4, FH / 2 + 4 return math.clamp(x, hw, math.max(hw, vp.X - hw)), math.clamp(y, hh, math.max(hh, vp.Y - hh)) end

local savedFab = env.__VexariHubPosFab
local sx, sy
if typeof(savedFab) == "Vector2" then sx, sy = fabClamp(savedFab.X, savedFab.Y) else sx, sy = fabClamp(16 + FW / 2, 215) end

local Fab = new("TextButton", { Name = "FabButton", AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(FW, FH), Position = UDim2.fromOffset(sx, sy), BackgroundColor3 = M_BgColor, BackgroundTransparency = M_BgTrans, BorderSizePixel = 0, AutoButtonColor = false, Active = true, Text = FAB_TEXT, TextColor3 = TEXT_OFF, Font = Enum.Font.GothamBold, TextSize = FAB_TEXT_SIZE, TextStrokeColor3 = C.Night, TextStrokeTransparency = 0.7, Visible = false }, MinGui)
new("UICorner", { CornerRadius = UDim.new(0, FAB_RADIUS) }, Fab)
local FabScale = new("UIScale", { Scale = 0 }, Fab)
local restStrokeT = 0.3
local FabStroke = new("UIStroke", { Color = C.White, Thickness = 2, Transparency = restStrokeT, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, Fab)
local FabGrad = new("UIGradient", { Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, C.Lav), ColorSequenceKeypoint.new(0.35, C.Violet), ColorSequenceKeypoint.new(0.7, C.Deep), ColorSequenceKeypoint.new(1, C.Lav) }), Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.45, 0.2), NumberSequenceKeypoint.new(0.75, 0.8), NumberSequenceKeypoint.new(1, 0) }) }, FabStroke)
loopGradient(FabGrad, 4)

local function applyState(on, instant)
    restStrokeT = on and 0.08 or 0.3
    local textColor = on and C.White or TEXT_OFF
    if instant then Fab.TextColor3 = textColor; FabStroke.Transparency = restStrokeT
    else local info = TweenInfo.new(0.35, Enum.EasingStyle.Quint, Enum.EasingDirection.Out); tween(Fab, info, { TextColor3 = textColor }); tween(FabStroke, info, { Transparency = restStrokeT }) end
end
local function fabPressIn() local info = TweenInfo.new(0.09, Enum.EasingStyle.Quad, Enum.EasingDirection.Out) tween(FabScale, info, { Scale = 0.9 }) tween(Fab, info, { BackgroundTransparency = M_BgTrans - 0.2 }) tween(FabStroke, info, { Transparency = 0, Thickness = 2.7 }) end
local function fabPressOut() tween(FabScale, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }) local info = TweenInfo.new(0.35, Enum.EasingStyle.Quint, Enum.EasingDirection.Out) tween(Fab, info, { BackgroundTransparency = M_BgTrans }) tween(FabStroke, info, { Transparency = restStrokeT, Thickness = 2 }) end

local fabShown = FunState.Enabled
applyState(fabShown, true)
tween(FabScale, TweenInfo.new(0.6, Enum.EasingStyle.Back, Enum.EasingDirection.Out, 0, false, 0.2), { Scale = 1 })

track(RunService.Heartbeat:Connect(function()
    if FunState.Enabled ~= fabShown then fabShown = FunState.Enabled; applyState(fabShown, false) end
end))

local fabInput, fabDragStart, fabStartPos, fabDragging
track(Fab.InputBegan:Connect(function(input)
    if fabInput then return end
    local t = input.UserInputType
    if t ~= Enum.UserInputType.Touch and t ~= Enum.UserInputType.MouseButton1 then return end
    fabInput = input; fabDragStart = Vector2.new(input.Position.X, input.Position.Y); fabStartPos = Fab.Position; fabDragging = false
    fabPressIn()
    local conn
    conn = input.Changed:Connect(function()
        if input.UserInputState ~= Enum.UserInputState.End then return end
        conn:Disconnect(); if fabInput ~= input then return end; fabInput = nil
        fabPressOut()
        if fabDragging then
            fabDragging = false
            env.__VexariHubPosFab = Vector2.new(Fab.Position.X.Offset, Fab.Position.Y.Offset)
        else
            local newState = not FunState.Enabled
            ToggleFunSpin(newState)
            if Options.MoonwalkToggle then Options.MoonwalkToggle:Set(newState) end
        end
    end)
end))

track(UserInputService.InputChanged:Connect(function(input)
    if not fabInput then return end
    if input ~= fabInput and input.UserInputType ~= Enum.UserInputType.MouseMovement then return end
    local delta = Vector2.new(input.Position.X, input.Position.Y) - fabDragStart
    if not fabDragging and delta.Magnitude >= M_DragDist then
        fabDragging = true
        tween(FabScale, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1.06 })
    end
    if fabDragging then
        local x, y = fabClamp(fabStartPos.X.Offset + delta.X, fabStartPos.Y.Offset + delta.Y)
        Fab.Position = UDim2.fromOffset(x, y)
    end
end))

FunTab:AddToggle("MoonwalkToggle", { Title = "Moonwalk", Description = "เปิดเพื่อแสดงปุ่มลอย Moonwalk บนหน้าจอ", Default = false })
Options.MoonwalkToggle:OnChanged(function(state)
    Fab.Visible = state
    if not state then ToggleFunSpin(false) end
end)

-- FAB Aimbot
local AIM_TEXT = "Aimbot"
local AIM_TW = 40
pcall(function() AIM_TW = math.ceil(TextService:GetTextSize(AIM_TEXT, FAB_TEXT_SIZE, Enum.Font.GothamBold, Vector2.new(400, 40)).X) end)
local AFW = math.max(FAB_SIZE, AIM_TW + 28)
local AFH = FAB_SIZE
local function aimClamp(x, y) local vp = viewport() local hw, hh = AFW / 2 + 4, AFH / 2 + 4 return math.clamp(x, hw, math.max(hw, vp.X - hw)), math.clamp(y, hh, math.max(hh, vp.Y - hh)) end

local AimFab = new("TextButton", { Name = "AimFab", AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(AFW, AFH), Position = UDim2.fromOffset(sx, sy + 65), BackgroundColor3 = M_BgColor, BackgroundTransparency = M_BgTrans, BorderSizePixel = 0, AutoButtonColor = false, Active = true, Text = AIM_TEXT, TextColor3 = TEXT_OFF, Font = Enum.Font.GothamBold, TextSize = FAB_TEXT_SIZE, TextStrokeColor3 = C.Night, TextStrokeTransparency = 0.7, Visible = false }, MinGui)
new("UICorner", { CornerRadius = UDim.new(0, FAB_RADIUS) }, AimFab)
local AimScale = new("UIScale", { Scale = 0 }, AimFab)
local AimStroke = new("UIStroke", { Color = C.White, Thickness = 2, Transparency = restStrokeT, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, AimFab)
local AimGrad = new("UIGradient", { Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, C.Lav), ColorSequenceKeypoint.new(0.35, C.Violet), ColorSequenceKeypoint.new(0.7, C.Deep), ColorSequenceKeypoint.new(1, C.Lav) }), Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.45, 0.2), NumberSequenceKeypoint.new(0.75, 0.8), NumberSequenceKeypoint.new(1, 0) }) }, AimStroke)
loopGradient(AimGrad, 4)

local aimShown = AimbotState.Enabled
local function applyAimState(on, instant)
    local sT = on and 0.08 or 0.3
    local tC = on and C.White or TEXT_OFF
    if instant then AimFab.TextColor3 = tC; AimStroke.Transparency = sT
    else local info = TweenInfo.new(0.35, Enum.EasingStyle.Quint, Enum.EasingDirection.Out); tween(AimFab, info, { TextColor3 = tC }); tween(AimStroke, info, { Transparency = sT }) end
end
local function aimPressIn() local info = TweenInfo.new(0.09, Enum.EasingStyle.Quad, Enum.EasingDirection.Out) tween(AimScale, info, { Scale = 0.9 }) tween(AimFab, info, { BackgroundTransparency = M_BgTrans - 0.2 }) tween(AimStroke, info, { Transparency = 0, Thickness = 2.7 }) end
local function aimPressOut() tween(AimScale, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }) local info = TweenInfo.new(0.35, Enum.EasingStyle.Quint, Enum.EasingDirection.Out) tween(AimFab, info, { BackgroundTransparency = M_BgTrans }) tween(AimStroke, info, { Transparency = restStrokeT, Thickness = 2 }) end
applyAimState(aimShown, true)
tween(AimScale, TweenInfo.new(0.6, Enum.EasingStyle.Back, Enum.EasingDirection.Out, 0, false, 0.2), { Scale = 1 })

track(RunService.Heartbeat:Connect(function()
    if AimbotState.Enabled ~= aimShown then aimShown = AimbotState.Enabled; applyAimState(aimShown, false) end
end))

local aimInput, aimDragStart, aimStartPos, aimDragging
track(AimFab.InputBegan:Connect(function(input)
    if aimInput then return end
    local t = input.UserInputType
    if t ~= Enum.UserInputType.Touch and t ~= Enum.UserInputType.MouseButton1 then return end
    aimInput = input; aimDragStart = Vector2.new(input.Position.X, input.Position.Y); aimStartPos = AimFab.Position; aimDragging = false
    aimPressIn()
    local conn
    conn = input.Changed:Connect(function()
        if input.UserInputState ~= Enum.UserInputState.End then return end
        conn:Disconnect(); if aimInput ~= input then return end; aimInput = nil
        aimPressOut()
        if aimDragging then
            aimDragging = false
        else
            AimbotState.Enabled = not AimbotState.Enabled
            FovCircle.Visible = AimbotState.Enabled
            if Options.ShowAimBtn then Options.ShowAimBtn:Set(AimbotState.Enabled) end
        end
    end)
end))

track(UserInputService.InputChanged:Connect(function(input)
    if not aimInput then return end
    if input ~= aimInput and input.UserInputType ~= Enum.UserInputType.MouseMovement then return end
    local delta = Vector2.new(input.Position.X, input.Position.Y) - aimDragStart
    if not aimDragging and delta.Magnitude >= M_DragDist then
        aimDragging = true
        tween(AimScale, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1.06 })
    end
    if aimDragging then
        local x, y = aimClamp(aimStartPos.X.Offset + delta.X, aimStartPos.Y.Offset + delta.Y)
        AimFab.Position = UDim2.fromOffset(x, y)
    end
end))

Options.ShowAimBtn:OnChanged(function(state)
    AimFab.Visible = state
    if not state then
        AimbotState.Enabled = false
        FovCircle.Visible = false
    end
end)

if LocalPlayer then
    track(LocalPlayer.CharacterAdded:Connect(function(char)
        if not FunState.Enabled then return end
        local hum = char:WaitForChild("Humanoid", 5)
        if hum then hum.AutoRotate = false end
    end))
end

----------------------------------------------------------------
-- CLEANUP (สำคัญมาก: ป้องกัน Memory Leak)
----------------------------------------------------------------
env.__VexariHubCleanup = function()
    for _, c in ipairs(conns) do 
        pcall(function() 
            if typeof(c) == "Instance" then c:Destroy() 
            elseif typeof(c) == "RBXScriptConnection" then c:Disconnect()
            elseif typeof(c) == "thread" then task.cancel(c)
            end 
        end) 
    end
    pcall(toggleRef, false)
    
    clearAllESP()
    
    pcall(function() MinGui:Destroy() end)
    pcall(function() FovGui:Destroy() end)
end

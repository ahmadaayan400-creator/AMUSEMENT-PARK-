--==================================================
-- MAXU AMUSEMENT PARK
-- One LOCAL script (executor / LocalScript). Works in any game.
--
--  * A giant night-time amusement park is built far above the map, locally.
--  * 15 working rides, a dangerous roller coaster, and EL CLOWN who dances.
--  * Press a seat prompt to ride. Jump or LEAVE RIDE to get off.
--  * SKIP (top of the screen) takes you back to where you were.
--
-- HONEST NOTES
--  * Everything is created on YOUR client, so only you see the park and the rides.
--  * Re-running the script safely removes the old park and returns you.
--  * Not run inside Roblox while writing it: test it and report what looks wrong.
--==================================================
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local UIS = game:GetService("UserInputService")

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

if _G.MAXU_PARK_EXIT then pcall(_G.MAXU_PARK_EXIT, true) end

--==================================================
-- SETTINGS
--==================================================
local MUSIC_ID = "rbxassetid://103768345751621"
local HQ_HEIGHT = 3600
local HALF = 480                      -- island half size

local GOLD = Color3.fromRGB(255, 190, 35)
local RED = Color3.fromRGB(220, 30, 50)
local WHITE = Color3.fromRGB(255, 255, 255)
local BLACK = Color3.fromRGB(10, 10, 14)
local IRON = Color3.fromRGB(58, 60, 70)
local STEEL = Color3.fromRGB(150, 156, 170)
local WOOD = Color3.fromRGB(110, 70, 38)
local PINK = Color3.fromRGB(255, 70, 190)
local CYAN = Color3.fromRGB(40, 220, 255)
local PURPLE = Color3.fromRGB(150, 70, 255)
local LIME = Color3.fromRGB(110, 255, 90)
local ORANGE = Color3.fromRGB(255, 130, 30)
local YELLOW = Color3.fromRGB(255, 230, 60)
local GRASS = Color3.fromRGB(52, 120, 62)
local M = Enum.Material

--==================================================
-- SAFE GETTERS
--==================================================
local function getChar() return Player.Character end
local function getHum()
	local c = Player.Character
	return c and c:FindFirstChildOfClass("Humanoid")
end
local function getRoot()
	local c = Player.Character
	return c and (c:FindFirstChild("HumanoidRootPart") or c.PrimaryPart)
end
local function getCam() return workspace.CurrentCamera end

local startChar = Player.Character or Player.CharacterAdded:Wait()
local startRoot = startChar:WaitForChild("HumanoidRootPart", 15) or startChar.PrimaryPart
if not startRoot then
	warn("[MAXU PARK] no character root found")
	return
end
local OldCF = startRoot.CFrame

--==================================================
-- CLEAN OLD PARK
--==================================================
for _, n in ipairs({ "MAXU_AMUSEMENT_PARK", "MAXU_PARK_MUSIC" }) do
	local o = workspace:FindFirstChild(n)
	if o then o:Destroy() end
end
do
	local o = PlayerGui:FindFirstChild("MAXU_PARK_UI")
	if o then o:Destroy() end
end

local HQ = Instance.new("Folder")
HQ.Name = "MAXU_AMUSEMENT_PARK"
HQ.Parent = workspace

local Center = startRoot.Position + Vector3.new(700, HQ_HEIGHT, 700)

local conns = {}
local function bind(sig, fn)
	local c = sig:Connect(fn)
	conns[#conns + 1] = c
	return c
end
local Closed = false

--==================================================
-- BUILD HELPERS (all coordinates are relative to Center, 1 unit = 1 stud)
--==================================================
local CUR = HQ
local function section(name)
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = HQ
	CUR = f
	return f
end

local function V(x, y, z) return Center + Vector3.new(x, y, z) end
local function at(x, y, z, ry)
	return CFrame.new(V(x, y, z)) * CFrame.Angles(0, math.rad(ry or 0), 0)
end

local function P(name, size, cf, color, mat, parent, collide)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = mat or M.SmoothPlastic
	p.Anchored = true
	p.CanCollide = collide ~= false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent or CUR
	return p
end
local function B(name, sx, sy, sz, x, y, z, color, mat, ry, collide)
	return P(name, Vector3.new(sx, sy, sz), at(x, y, z, ry), color, mat, nil, collide)
end
-- vertical cylinder
local function VC(name, radius, height, x, y, z, color, mat, collide)
	local p = P(name, Vector3.new(height, radius * 2, radius * 2),
		CFrame.new(V(x, y, z)) * CFrame.Angles(0, 0, math.pi / 2), color, mat, nil, collide)
	p.Shape = Enum.PartType.Cylinder
	return p
end
local function Ball(name, d, x, y, z, color, mat)
	local p = P(name, Vector3.new(d, d, d), at(x, y, z), color, mat, nil, false)
	p.Shape = Enum.PartType.Ball
	return p
end
-- ellipsoid (works with any non-uniform size)
local function Blob(name, size, cf, color, mat, parent)
	local p = P(name, size, cf, color, mat, parent, false)
	local m = Instance.new("SpecialMesh")
	m.MeshType = Enum.MeshType.Sphere
	m.Parent = p
	return p
end
-- a beam between two world points
local function Beam(name, a, b, th, color, mat, collide, parent)
	local len = (b - a).Magnitude
	if len < 0.01 then len = 0.01 end
	return P(name, Vector3.new(th, th, len), CFrame.lookAt((a + b) / 2, b), color, mat, parent, collide)
end

local LIGHTS = 0
local function addLight(part, color, range, brightness)
	if LIGHTS > 170 then return nil end
	LIGHTS = LIGHTS + 1
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = brightness
	l.Shadows = false
	l.Parent = part
	return l
end

-- colour-cycling neon parts
local NEONS = {}
local function rainbow(part, h0, speed)
	NEONS[#NEONS + 1] = { part = part, h0 = h0 or math.random(), speed = speed or 0.12 }
	return part
end

--==================================================
-- LIGHTING (restored on exit): neon night, atmosphere, bloom, searchlights
--==================================================
local lightingBackup = {
	ClockTime = Lighting.ClockTime, Brightness = Lighting.Brightness, Ambient = Lighting.Ambient,
	OutdoorAmbient = Lighting.OutdoorAmbient, FogEnd = Lighting.FogEnd, FogStart = Lighting.FogStart,
	FogColor = Lighting.FogColor, ExposureCompensation = Lighting.ExposureCompensation,
	GlobalShadows = Lighting.GlobalShadows,
}
local lightingMade = {}
local oldAtmos = {}
local function applyNightLighting(instant)
	pcall(function()
		local goal = {
			ClockTime = 0, Brightness = 2, Ambient = Color3.fromRGB(70, 50, 110),
			OutdoorAmbient = Color3.fromRGB(90, 60, 140), FogColor = Color3.fromRGB(40, 20, 70),
			FogStart = 800, FogEnd = 6000, ExposureCompensation = 0.3,
		}
		if instant then
			for k, v in pairs(goal) do Lighting[k] = v end
		else
			TweenService:Create(Lighting, TweenInfo.new(3, Enum.EasingStyle.Sine), goal):Play()
		end
	end)
end
pcall(function()
	for _, o in ipairs(Lighting:GetChildren()) do
		if o:IsA("Atmosphere") then oldAtmos[#oldAtmos + 1] = o o.Parent = nil end
	end
	local atm = Instance.new("Atmosphere")
	atm.Name = "MAXU_PARK_ATMOS"
	atm.Density = 0.32
	atm.Offset = 0.25
	atm.Color = Color3.fromRGB(140, 90, 200)
	atm.Decay = Color3.fromRGB(70, 30, 110)
	atm.Glare = 0.5
	atm.Haze = 1.6
	atm.Parent = Lighting
	lightingMade[#lightingMade + 1] = atm
	local bloom = Instance.new("BloomEffect")
	bloom.Name = "MAXU_PARK_BLOOM"
	bloom.Intensity = 1.5
	bloom.Size = 40
	bloom.Threshold = 0.85
	bloom.Parent = Lighting
	lightingMade[#lightingMade + 1] = bloom
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "MAXU_PARK_CC"
	cc.TintColor = Color3.fromRGB(255, 232, 255)
	cc.Saturation = 0.35
	cc.Contrast = 0.12
	cc.Parent = Lighting
	lightingMade[#lightingMade + 1] = cc
	local dof = Instance.new("DepthOfFieldEffect")
	dof.Name = "MAXU_PARK_DOF"
	dof.FarIntensity = 0.12
	dof.FocusDistance = 140
	dof.InFocusRadius = 120
	dof.NearIntensity = 0
	dof.Parent = Lighting
	lightingMade[#lightingMade + 1] = dof
	local sky = Instance.new("Sky")
	sky.Name = "MAXU_PARK_SKY"
	sky.StarCount = 7000
	sky.CelestialBodiesShown = false
	for _, f in ipairs({ "SkyboxBk", "SkyboxDn", "SkyboxFt", "SkyboxLf", "SkyboxRt", "SkyboxUp" }) do sky[f] = "" end
	sky.Parent = Lighting
	lightingMade[#lightingMade + 1] = sky
end)
applyNightLighting(false)

--==================================================
-- MUSIC
--==================================================
local Sound = Instance.new("Sound")
Sound.Name = "MAXU_PARK_MUSIC"
Sound.SoundId = MUSIC_ID
Sound.Volume = 0.55
Sound.Looped = true
Sound.Parent = workspace
pcall(function() Sound:Play() end)

--==================================================
-- UI: root, toasts, counters, leave button
--==================================================
local SG = Instance.new("ScreenGui")
SG.Name = "MAXU_PARK_UI"
SG.ResetOnSpawn = false
SG.IgnoreGuiInset = true
SG.DisplayOrder = 300
SG.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
SG.Parent = PlayerGui

local function corner(p, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r)
	c.Parent = p
	return c
end
local function stroke(p, color, th)
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = th or 1.5
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = p
	return s
end
local function tween(o, t, props, style, dir)
	local tw = TweenService:Create(o, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end
local function scaleFor()
	local c = getCam()
	local v = c and c.ViewportSize or Vector2.new(1280, 720)
	return math.clamp(math.min(v.X / 900, v.Y / 520), 0.55, 1.2)
end

local toastHolder = Instance.new("Frame")
toastHolder.AnchorPoint = Vector2.new(0.5, 0)
toastHolder.Position = UDim2.new(0.5, 0, 0, 70)
toastHolder.Size = UDim2.fromOffset(380, 200)
toastHolder.BackgroundTransparency = 1
toastHolder.ZIndex = 50
toastHolder.Parent = SG
local tl = Instance.new("UIListLayout")
tl.Padding = UDim.new(0, 6)
tl.HorizontalAlignment = Enum.HorizontalAlignment.Center
tl.Parent = toastHolder

local function toast(text, good)
	local f = Instance.new("Frame")
	f.Size = UDim2.fromOffset(360, 38)
	f.BackgroundColor3 = Color3.fromRGB(14, 8, 24)
	f.BackgroundTransparency = 1
	f.ZIndex = 50
	f.Parent = toastHolder
	corner(f, 10)
	local s = stroke(f, good == false and Color3.fromRGB(255, 90, 90) or PINK, 1.6)
	s.Transparency = 1
	local l = Instance.new("TextLabel")
	l.Size = UDim2.new(1, -16, 1, 0)
	l.Position = UDim2.fromOffset(8, 0)
	l.BackgroundTransparency = 1
	l.Text = text
	l.TextColor3 = WHITE
	l.TextSize = 13
	l.Font = Enum.Font.GothamBold
	l.TextWrapped = true
	l.TextTransparency = 1
	l.ZIndex = 51
	l.Parent = f
	tween(f, 0.25, { BackgroundTransparency = 0.12 })
	tween(s, 0.25, { Transparency = 0 })
	tween(l, 0.25, { TextTransparency = 0 })
	task.delay(3.4, function()
		if not f.Parent then return end
		tween(f, 0.3, { BackgroundTransparency = 1 })
		tween(s, 0.3, { Transparency = 1 })
		tween(l, 0.3, { TextTransparency = 1 })
		task.delay(0.35, function() f:Destroy() end)
	end)
end

local counter = Instance.new("TextLabel")
counter.AnchorPoint = Vector2.new(0, 1)
counter.Position = UDim2.new(0, 14, 1, -14)
counter.Size = UDim2.fromOffset(200, 30)
counter.BackgroundColor3 = Color3.fromRGB(14, 8, 24)
counter.BackgroundTransparency = 0.2
counter.TextColor3 = PINK
counter.TextSize = 13
counter.Font = Enum.Font.GothamBold
counter.ZIndex = 40
counter.Visible = false
counter.Parent = SG
corner(counter, 9)
stroke(counter, PURPLE, 1.3)

local leaveBtn = Instance.new("TextButton")
leaveBtn.AnchorPoint = Vector2.new(0.5, 1)
leaveBtn.Position = UDim2.new(0.5, 0, 1, -24)
leaveBtn.Size = UDim2.fromOffset(200, 46)
leaveBtn.BackgroundColor3 = Color3.fromRGB(190, 20, 50)
leaveBtn.Text = "LEAVE RIDE"
leaveBtn.TextColor3 = WHITE
leaveBtn.Font = Enum.Font.GothamBlack
leaveBtn.TextSize = 18
leaveBtn.ZIndex = 60
leaveBtn.Visible = false
leaveBtn.Parent = SG
corner(leaveBtn, 12)
stroke(leaveBtn, GOLD, 2)

local Black = Instance.new("Frame")
Black.Size = UDim2.fromScale(1, 1)
Black.BackgroundColor3 = Color3.new(0, 0, 0)
Black.BorderSizePixel = 0
Black.ZIndex = 100
Black.Parent = SG
local Intro = Instance.new("TextLabel")
Intro.Size = UDim2.new(1, 0, 0, 70)
Intro.Position = UDim2.new(0, 0, 0.5, -35)
Intro.BackgroundTransparency = 1
Intro.Text = "TELEPORTING TO MAXU AMUSEMENT PARK"
Intro.TextColor3 = WHITE
Intro.Font = Enum.Font.GothamBlack
Intro.TextScaled = true
Intro.ZIndex = 101
Intro.Parent = Black

--==================================================
-- RIDE SYSTEM: every ride exposes seats; boarding glues you to a seat
--==================================================
local RIDES = {}
local RS = { cur = nil, visited = {}, n = 0, T = 0 }
local TOTAL_RIDES = 15
local function updateCounter()
	counter.Text = string.format("RIDES  %d / %d", RS.n, TOTAL_RIDES)
end

local function newRide(name, exitCF)
	local r = { name = name, exitCF = exitCF, duration = 30 }
	RIDES[#RIDES + 1] = r
	return r
end

-- invisible-or-visible part that the ride keeps moving; `off` is where your body sits on it
local function prompt(part, action, object, fn, hold, dist)
	local pr = Instance.new("ProximityPrompt")
	pr.ActionText = action
	pr.ObjectText = object or ""
	pr.HoldDuration = hold or 0.3
	pr.MaxActivationDistance = dist or 12
	pr.RequiresLineOfSight = false
	pr.Parent = part
	bind(pr.Triggered, function() fn(pr) end)
	return pr
end

local origFov = nil
function RS.mark(ride)
	if not RS.visited[ride.name] then
		RS.visited[ride.name] = true
		RS.n = RS.n + 1
		updateCounter()
		toast(ride.name .. "  -  new ride!  (" .. RS.n .. "/" .. TOTAL_RIDES .. ")", true)
		if RS.n == TOTAL_RIDES then
			toast("YOU RODE EVERY RIDE IN THE PARK!", true)
			if RS.celebrate then RS.celebrate() end
		end
	end
end

local function board(ride, seatPart, off, duration)
	if RS.cur or Closed then return end
	local r = getRoot()
	local h = getHum()
	if not r or not h then return end
	RS.cur = { ride = ride, part = seatPart, off = off or CFrame.new(0, 2.3, 0), t0 = os.clock(), dur = duration or ride.duration }
	r.Anchored = true
	h.Sit = true
	leaveBtn.Visible = true
	local cam = getCam()
	origFov = cam and cam.FieldOfView or 70
	if ride.onBoard then pcall(ride.onBoard) end
	RS.mark(ride)
end

local function leave(force)
	local c = RS.cur
	if not c then return end
	if c.ride.noLeave and c.ride.noLeave() and not force then
		toast("Please wait until the ride stops.", false)
		return
	end
	RS.cur = nil
	leaveBtn.Visible = false
	local r = getRoot()
	local h = getHum()
	local cam = getCam()
	if cam and origFov then tween(cam, 0.4, { FieldOfView = origFov }) end
	if h then h.Sit = false h.CameraOffset = Vector3.zero end
	if c.ride.onLeave then pcall(c.ride.onLeave) end
	if r then
		r.Anchored = false
		pcall(function() getChar():PivotTo(c.ride.exitCF + Vector3.new(0, 3, 0)) end)
		r.AssemblyLinearVelocity = Vector3.zero
		r.AssemblyAngularVelocity = Vector3.zero
	end
end
bind(leaveBtn.Activated, function() leave(false) end)
bind(UIS.JumpRequest, function() if RS.cur then leave(false) end end)

-- master loop: update every ride, then glue the rider to the seat
local function rideSeat(ride, part, off, label, dur)
	return prompt(part, "Ride", label or ride.name, function() board(ride, part, off, dur) end, 0.3, 14)
end

local neonAcc = 0
bind(RunService.Heartbeat, function(dt)
	if Closed then return end
	RS.T = RS.T + dt
	for _, r in ipairs(RIDES) do
		if r.update then r.update(dt, RS.T) end
	end
	local c = RS.cur
	if c then
		local root = getRoot()
		if not root then
			RS.cur = nil
			leaveBtn.Visible = false
		else
			root.CFrame = c.part.CFrame * c.off
			root.AssemblyLinearVelocity = Vector3.zero
			if c.ride.done and c.ride.done() then
				leave(true)
			elseif os.clock() - c.t0 > c.dur and not (c.ride.noLeave and c.ride.noLeave()) then
				leave(true)
			end
		end
	end
	-- colour cycling neon
	neonAcc = neonAcc + dt
	if neonAcc > 0.08 then
		neonAcc = 0
		local t = RS.T
		for _, n in ipairs(NEONS) do
			if n.part.Parent then n.part.Color = Color3.fromHSV((t * n.speed + n.h0) % 1, 0.85, 1) end
		end
	end
end)

--==================================================
-- bursts and fireworks
--==================================================
local function burst(pos, color, n, dist, life)
	for _ = 1, n do
		local p = Instance.new("Part")
		p.Shape = Enum.PartType.Ball
		p.Size = Vector3.new(2, 2, 2)
		p.Color = color
		p.Material = M.Neon
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CastShadow = false
		p.Position = pos
		p.Parent = HQ
		local dir = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5)
		if dir.Magnitude < 0.01 then dir = Vector3.new(0, 1, 0) end
		tween(p, life, { Position = pos + dir.Unit * dist * (0.5 + math.random() * 0.5), Size = Vector3.new(0.3, 0.3, 0.3), Transparency = 1 })
		task.delay(life + 0.1, function() p:Destroy() end)
	end
end
local function rcolor() return Color3.fromHSV(math.random(), 0.75, 1) end

local function fireworks(count, origin)
	task.spawn(function()
		for _ = 1, count do
			if Closed then return end
			local start = origin + Vector3.new(math.random(-30, 30), 0, math.random(-30, 30))
			local rocket = Instance.new("Part")
			rocket.Shape = Enum.PartType.Ball
			rocket.Size = Vector3.new(3, 3, 3)
			rocket.Color = Color3.fromRGB(255, 240, 200)
			rocket.Material = M.Neon
			rocket.Anchored = true
			rocket.CanCollide = false
			rocket.CanQuery = false
			rocket.Position = start
			rocket.Parent = HQ
			local top = start + Vector3.new(0, math.random(200, 300), 0)
			tween(rocket, 1.3, { Position = top }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			task.delay(1.35, function()
				rocket:Destroy()
				burst(top, rcolor(), 50, 110, 1.8)
				burst(top, rcolor(), 32, 65, 1.5)
			end)
			task.wait(0.4)
		end
	end)
end
RS.celebrate = function() fireworks(14, V(0, 10, 0)) end

--==================================================
-- TERRAIN, PLAZA, GATE, DECOR
--==================================================
local SPAWN = V(0, 4, -410)
local SPAWN_CF = CFrame.lookAt(SPAWN, SPAWN + Vector3.new(0, 0, 100))

section("Terrain")
do
	B("Island", HALF * 2, 12, HALF * 2, 0, -6, 0, GRASS, M.Grass)
	-- cliffs under the island
	B("Cliff", HALF * 2 - 20, 80, HALF * 2 - 20, 0, -52, 0, Color3.fromRGB(70, 62, 78), M.Slate)
	B("Cliff2", HALF * 2 - 120, 140, HALF * 2 - 120, 0, -160, 0, Color3.fromRGB(55, 48, 66), M.Slate)
	-- paved plaza disc
	VC("Plaza", 78, 1, 0, 0.5, 0, Color3.fromRGB(45, 40, 62), M.Concrete)
	rainbow(VC("PlazaRing", 80, 0.8, 0, 0.45, 0, PINK, M.Neon, false), 0, 0.1)
	-- main avenue (gate to plaza) and cross avenues
	B("Avenue", 34, 0.6, 330, 0, 0.3, -245, Color3.fromRGB(60, 52, 80), M.Concrete)
	B("AvenueN", 34, 0.6, 330, 0, 0.3, 245, Color3.fromRGB(60, 52, 80), M.Concrete)
	B("AvenueE", 330, 0.6, 30, 245, 0.3, 0, Color3.fromRGB(60, 52, 80), M.Concrete)
	B("AvenueW", 330, 0.6, 30, -245, 0.3, 0, Color3.fromRGB(60, 52, 80), M.Concrete)
	-- neon strips along the avenue
	for i, sx in ipairs({ -17.5, 17.5 }) do
		rainbow(B("AveStrip" .. i, 1, 0.5, 330, sx, 0.7, -245, PINK, M.Neon, 0, false), i * 0.5, 0.09)
		rainbow(B("AveStripN" .. i, 1, 0.5, 330, sx, 0.7, 245, PINK, M.Neon, 0, false), i * 0.5, 0.09)
	end
	-- fountain
	VC("FountainBase", 22, 3, 0, 1.5, 0, Color3.fromRGB(90, 90, 110), M.Marble)
	VC("FountainWater", 19.5, 1, 0, 3.2, 0, Color3.fromRGB(40, 120, 230), M.Glass, false).Transparency = 0.3
	VC("FountainPillar", 3, 14, 0, 9, 0, Color3.fromRGB(120, 120, 140), M.Marble)
	local top = Ball("FountainTop", 7, 0, 17, 0, CYAN, M.Neon)
	rainbow(top, 0.3, 0.2)
	addLight(top, CYAN, 60, 3)
	local spray = Instance.new("ParticleEmitter")
	spray.Rate = 60
	spray.Lifetime = NumberRange.new(1.4, 2.0)
	spray.Speed = NumberRange.new(14, 20)
	spray.SpreadAngle = Vector2.new(35, 35)
	spray.Acceleration = Vector3.new(0, -40, 0)
	spray.Size = NumberSequence.new(0.8, 0.2)
	spray.Color = ColorSequence.new(Color3.fromRGB(170, 220, 255))
	spray.LightEmission = 0.6
	spray.Parent = top
end

-- island edge neon rail + invisible walls
section("Edge")
do
	local e = HALF - 2
	local sides = { { 0, -e, HALF * 2, 1 }, { 0, e, HALF * 2, 1 }, { -e, 0, 1, HALF * 2 }, { e, 0, 1, HALF * 2 } }
	for i, s in ipairs(sides) do
		rainbow(B("EdgeNeon" .. i, s[3], 0.8, s[4], s[1], 1, s[2], PURPLE, M.Neon, 0, false), i * 0.25, 0.08)
		local w = B("Wall" .. i, s[3], 40, s[4], s[1], 20, s[2], BLACK, M.SmoothPlastic, 0)
		w.Transparency = 1
		w.CanQuery = false
	end
end

--==================================================
-- GATE
--==================================================
section("Gate")
do
	local gz = -440
	for _, sx in ipairs({ -42, 42 }) do
		B("GatePillar", 10, 46, 10, sx, 23, gz, Color3.fromRGB(230, 40, 120), M.SmoothPlastic)
		B("GateCap", 14, 3, 14, sx, 47, gz, GOLD, M.Metal)
		local b = Ball("GateBall", 9, sx, 53, gz, YELLOW, M.Neon)
		addLight(b, YELLOW, 50, 2.5)
	end
	B("GateBeam", 94, 18, 6, 0, 46, gz, Color3.fromRGB(26, 14, 44), M.SmoothPlastic)
	rainbow(B("GateNeonTop", 94, 1.4, 1, 0, 55.5, gz - 3.4, PINK, M.Neon, 0, false), 0, 0.2)
	rainbow(B("GateNeonBot", 94, 1.4, 1, 0, 36.5, gz - 3.4, CYAN, M.Neon, 0, false), 0.5, 0.2)
	local sg = Instance.new("SurfaceGui")
	sg.Face = Enum.NormalId.Back
	sg.SizeStudsPerPixel = 0.08
	sg.LightInfluence = 0
	sg.Brightness = 2
	local sp = B("GateSign", 90, 14, 1, 0, 46, gz - 3.2, BLACK, M.SmoothPlastic, 0, false)
	sg.Parent = sp
	sg.Adornee = sp
	for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
		local g = sg:Clone()
		g.Face = face
		g.Parent = sp
		local t = Instance.new("TextLabel")
		t.Size = UDim2.fromScale(1, 1)
		t.BackgroundTransparency = 1
		t.Text = "MAXU AMUSEMENT PARK"
		t.TextColor3 = Color3.fromRGB(255, 80, 200)
		t.Font = Enum.Font.GothamBlack
		t.TextScaled = true
		t.Parent = g
		local st = Instance.new("UIStroke")
		st.Color = CYAN
		st.Thickness = 5
		st.Parent = t
	end
	sg:Destroy()
	-- balloon arch
	for i = 0, 18 do
		local a = math.pi * i / 18
		local b = Ball("Balloon", 6, math.cos(a) * 34, 8 + math.sin(a) * 30 - 6, gz + 18, Color3.fromHSV(i / 19, 0.8, 1), M.Neon)
		b.Transparency = 0.15
	end
	-- ticket booths
	for _, sx in ipairs({ -70, 70 }) do
		B("Booth", 14, 12, 12, sx, 6, -400, Color3.fromRGB(240, 220, 90), M.SmoothPlastic)
		B("BoothRoof", 18, 2, 16, sx, 13, -400, RED, M.SmoothPlastic)
		rainbow(B("BoothNeon", 14.5, 0.8, 12.5, sx, 11, -400, PINK, M.Neon, 0, false), sx, 0.1)
		B("BoothGlass", 8, 5, 0.5, sx, 7, -406.2, CYAN, M.Glass, 0, false).Transparency = 0.5
	end
end

--==================================================
-- LAMP POSTS, BULB STRINGS, TREES
--==================================================
section("Decor")
do
	local function lamp(x, z, color)
		B("LampPole", 1, 16, 1, x, 8, z, IRON, M.Metal)
		local b = Ball("LampBulb", 3.4, x, 16.8, z, color, M.Neon)
		addLight(b, color, 40, 1.6)
	end
	local lc = { PINK, CYAN, YELLOW, LIME }
	for i = 0, 10 do
		local z = -400 + i * 30
		lamp(-24, z, lc[i % 4 + 1])
		lamp(24, z, lc[(i + 2) % 4 + 1])
	end
	for i = 0, 6 do
		local x = -300 + i * 100
		if math.abs(x) > 60 then lamp(x, -20, lc[i % 4 + 1]) lamp(x, 20, lc[(i + 1) % 4 + 1]) end
	end
	-- bulb strings across the avenue
	for i = 0, 7 do
		local z = -380 + i * 38
		for k = 0, 14 do
			local t = k / 14
			local x = -24 + 48 * t
			local y = 17 - math.sin(t * math.pi) * -3
			Ball("Bulb", 1.5, x, y + 1, z, Color3.fromHSV((i * 0.11 + k * 0.07) % 1, 0.8, 1), M.Neon)
		end
	end
	-- trees with fairy lights
	local function tree(x, z)
		B("Trunk", 3, 14, 3, x, 7, z, WOOD, M.Wood)
		Blob("Leaves", Vector3.new(18, 16, 18), at(x, 19, z), Color3.fromRGB(30, 100, 60), M.Grass)
		for k = 1, 6 do
			local a = k * 1.05
			Ball("Fairy", 1.2, x + math.cos(a) * 8, 18 + math.sin(a * 2) * 4, z + math.sin(a) * 8, Color3.fromHSV((k / 6 + x * 0.01) % 1, 0.7, 1), M.Neon)
		end
	end
	for i = 0, 11 do
		local z = -400 + i * 70
		if i % 1 == 0 then tree(-60 - (i % 3) * 8, z) tree(60 + (i % 3) * 8, z + 20) end
	end
	for _, p in ipairs({ { -380, -380 }, { 380, -380 }, { -380, 380 }, { 380, 380 }, { 400, 0 }, { -420, 0 }, { 0, 420 }, { 330, -330 }, { -330, -330 } }) do
		tree(p[1], p[2])
	end
	-- benches
	for _, p in ipairs({ { -45, -90 }, { 45, -90 }, { -45, 90 }, { 45, 90 } }) do
		B("BenchSeat", 8, 1, 3, p[1], 2.2, p[2], WOOD, M.Wood)
		B("BenchBack", 8, 3, 0.7, p[1], 4, p[2] - 1.4, WOOD, M.Wood)
		B("BenchLegA", 0.8, 2, 2.5, p[1] - 3, 1, p[2], IRON, M.Metal)
		B("BenchLegB", 0.8, 2, 2.5, p[1] + 3, 1, p[2], IRON, M.Metal)
	end
end

-- rotating searchlights
section("Searchlights")
local SEARCH = {}
do
	local spots = { { -420, -420 }, { 420, -420 }, { -420, 420 }, { 420, 420 }, { 0, 440 }, { 0, -380 } }
	local cols = { PINK, CYAN, LIME, YELLOW, PURPLE, ORANGE }
	for i, s in ipairs(spots) do
		B("SpotBase", 8, 4, 8, s[1], 2, s[2], IRON, M.Metal)
		local beam = P("SearchBeam", Vector3.new(5, 5, 420), CFrame.new(V(s[1], 5, s[2])), cols[i], M.Neon, nil, false)
		beam.Transparency = 0.82
		beam.CastShadow = false
		beam.CanQuery = false
		SEARCH[i] = { part = beam, x = s[1], z = s[2], ph = i * 1.1 }
	end
end

--==================================================
-- FOOD STALLS
--==================================================
section("Stalls")
do
	local function stall(x, z, ry, name, color)
		B("StallBase", 14, 8, 8, x, 4, z, Color3.fromRGB(35, 28, 50), M.SmoothPlastic, ry)
		local roof = B("StallRoof", 17, 1.4, 11, x, 9, z, color, M.SmoothPlastic, ry)
		rainbow(B("StallNeon", 14.4, 0.7, 8.4, x, 8.2, z, color, M.Neon, ry, false), math.random(), 0.1)
		local counter = B("Counter", 14, 1, 3, x, 4.2, z, WOOD, M.Wood, ry)
		local cf = at(x, 4, z, ry) * CFrame.new(0, 6, 0)
		local lblp = P("StallLabel", Vector3.new(10, 3, 0.3), at(x, 11.5, z, ry), BLACK, M.SmoothPlastic, nil, false)
		local g = Instance.new("SurfaceGui")
		g.Face = Enum.NormalId.Front
		g.SizeStudsPerPixel = 0.05
		g.Parent = lblp
		local t = Instance.new("TextLabel")
		t.Size = UDim2.fromScale(1, 1)
		t.BackgroundTransparency = 1
		t.Text = name
		t.TextColor3 = color
		t.Font = Enum.Font.GothamBlack
		t.TextScaled = true
		t.Parent = g
		prompt(counter, "Buy", name, function() toast("Yum! " .. name .. " - on the house.", true) end, 0.2, 10)
		local l = addLight(roof, color, 26, 1.4)
	end
	stall(-40, -250, 90, "POPCORN", YELLOW)
	stall(40, -250, -90, "ICE CREAM", CYAN)
	stall(-40, -330, 90, "COTTON CANDY", PINK)
	stall(40, -330, -90, "HOT DOGS", ORANGE)
	stall(-40, 330, 90, "DONUTS", LIME)
	stall(40, 330, -90, "SODA", RED)
end

-- animate searchlights + keep the player on the island
local lastGuard = 0
bind(RunService.Heartbeat, function(dt)
	if Closed then return end
	local t = RS.T
	for _, s in ipairs(SEARCH) do
		local yaw = t * 0.5 + s.ph
		local dir = Vector3.new(math.cos(yaw) * 0.55, 0.85, math.sin(yaw) * 0.55).Unit
		local o = V(s.x, 5, s.z)
		s.part.CFrame = CFrame.lookAt(o + dir * 210, o + dir * 420)
	end
	lastGuard = lastGuard + dt
	if lastGuard > 0.5 then
		lastGuard = 0
		local r = getRoot()
		if r and not RS.cur then
			local rel = r.Position - Center
			if rel.Y < -40 or math.abs(rel.X) > HALF + 10 or math.abs(rel.Z) > HALF + 10 then
				pcall(function() getChar():PivotTo(SPAWN_CF) end)
				toast("Back to the park entrance!", false)
			end
		end
	end
end)

--==================================================
-- RIDE HELPERS
--==================================================
local function newModel(name)
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = CUR
	return m
end
-- part placed relative to Center (rel is a CFrame offset from Center)
local function RP(m, name, size, rel, color, mat, collide)
	return P(name, size, CFrame.new(Center) * rel, color, mat, m, collide == true)
end
local function RBlob(m, name, size, rel, color, mat)
	return Blob(name, size, CFrame.new(Center) * rel, color, mat, m)
end
local function RBall(m, name, d, rel, color, mat)
	local p = RP(m, name, Vector3.new(d, d, d), rel, color, mat)
	p.Shape = Enum.PartType.Ball
	return p
end
local function CN(x, y, z) return CFrame.new(x, y, z) end
local SEATOFF = CFrame.new(0, 2.4, 0)
local function smooth(x) x = math.clamp(x, 0, 1) return x * x * (3 - 2 * x) end

--==================================================
-- RIDE 1: FERRIS WHEEL
--==================================================
section("Ferris wheel")
do
	local ride = newRide("Ferris Wheel", at(0, 1, 270))
	ride.duration = 34
	local hub = V(0, 80, 320)
	local R = 64
	local wheel = newModel("WheelRot")
	local hubPart = P("Hub", Vector3.new(10, 10, 14), CFrame.new(hub), GOLD, M.Metal, wheel, false)
	wheel.PrimaryPart = hubPart
	local function wp(name, size, rel, color, mat)
		return P(name, size, CFrame.new(hub) * rel, color, mat, wheel, false)
	end
	for _, zz in ipairs({ -6, 6 }) do
		local N = 24
		for i = 0, N - 1 do
			local a1 = i / N * math.pi * 2
			local a2 = (i + 1) / N * math.pi * 2
			local p1 = Vector3.new(math.cos(a1) * R, math.sin(a1) * R, zz)
			local p2 = Vector3.new(math.cos(a2) * R, math.sin(a2) * R, zz)
			local seg = P("Rim", Vector3.new(1.6, 1.6, (p2 - p1).Magnitude + 0.3), CFrame.lookAt(hub + (p1 + p2) / 2, hub + p2), WHITE, M.Metal, wheel, false)
			if i % 2 == 0 then seg.Color = PINK seg.Material = M.Neon rainbow(seg, i / N, 0.15) end
		end
		for i = 0, 11 do
			local a = i / 12 * math.pi * 2
			local p2 = Vector3.new(math.cos(a) * R, math.sin(a) * R, zz)
			P("Spoke", Vector3.new(0.8, 0.8, R), CFrame.lookAt(hub + p2 / 2, hub + p2), STEEL, M.Metal, wheel, false)
		end
	end
	-- gondolas
	local gondolas = {}
	for i = 0, 11 do
		local g = newModel("Gondola" .. i)
		local seatp = P("Seat", Vector3.new(6, 0.8, 5), CFrame.new(hub), Color3.fromHSV(i / 12, 0.7, 1), M.SmoothPlastic, g, false)
		g.PrimaryPart = seatp
		P("Roof", Vector3.new(7, 0.6, 6), CFrame.new(hub) * CN(0, 6.2, 0), RED, M.SmoothPlastic, g, false)
		for _, sx in ipairs({ -3, 3 }) do
			P("Post", Vector3.new(0.5, 6, 0.5), CFrame.new(hub) * CN(sx, 3.2, -2.4), WHITE, M.Metal, g, false)
			P("Post", Vector3.new(0.5, 6, 0.5), CFrame.new(hub) * CN(sx, 3.2, 2.4), WHITE, M.Metal, g, false)
			P("Rail", Vector3.new(0.4, 0.4, 5), CFrame.new(hub) * CN(sx, 2, 0), WHITE, M.Metal, g, false)
		end
		local lb = P("Bulb", Vector3.new(1.6, 1.6, 1.6), CFrame.new(hub) * CN(0, 6.9, 0), YELLOW, M.Neon, g, false)
		lb.Shape = Enum.PartType.Ball
		rideSeat(ride, seatp, SEATOFF, "Gondola", 34)
		gondolas[i] = { m = g, seat = seatp }
	end
	-- supports
	for _, zz in ipairs({ -12, 12 }) do
		for _, sx in ipairs({ -30, 30 }) do
			Beam("Leg", V(sx, 0, 320 + zz), V(0, 80, 320 + zz * 0.5), 3, IRON, M.Metal, false)
		end
		B("Foot", 74, 2, 5, 0, 1, 320 + zz, IRON, M.Metal)
	end
	B("Axle", 3, 3, 28, 0, 80, 320, STEEL, M.Metal)
	-- station platform
	B("FerrisPad", 40, 1.2, 24, 0, 0.6, 292, Color3.fromRGB(70, 60, 100), M.Concrete)
	local ang = 0
	ride.update = function(dt)
		ang = ang + dt * 0.22
		wheel:PivotTo(CFrame.new(hub) * CFrame.Angles(0, 0, ang))
		for i, g in pairs(gondolas) do
			local a = ang + i / 12 * math.pi * 2
			g.m:PivotTo(CFrame.new(hub + Vector3.new(math.cos(a) * R, math.sin(a) * R - 6.4, 0)))
		end
	end
end

--==================================================
-- RIDE 3: CAROUSEL
--==================================================
section("Carousel")
do
	local ride = newRide("Carousel", at(-160, 1, -110))
	ride.duration = 32
	local cx, cz = -160, -150
	local c = V(cx, 0, cz)
	VC("CarouselBase", 26, 2, cx, 1, cz, Color3.fromRGB(50, 30, 70), M.Concrete)
	local rot = newModel("CarouselRot")
	local floor = P("Floor", Vector3.new(1.4, 44, 44), CFrame.new(c + Vector3.new(0, 2.5, 0)) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(240, 220, 170), M.Wood, rot, true)
	floor.Shape = Enum.PartType.Cylinder
	rot.PrimaryPart = floor
	local core = P("Core", Vector3.new(34, 8, 8), CFrame.new(c + Vector3.new(0, 20, 0)) * CFrame.Angles(0, 0, math.pi / 2), GOLD, M.Metal, rot, false)
	core.Shape = Enum.PartType.Cylinder
	local canopy = P("Canopy", Vector3.new(4, 54, 54), CFrame.new(c + Vector3.new(0, 38, 0)) * CFrame.Angles(0, 0, math.pi / 2), RED, M.SmoothPlastic, rot, false)
	canopy.Shape = Enum.PartType.Cylinder
	local rim = P("CanopyRim", Vector3.new(1.4, 55, 55), CFrame.new(c + Vector3.new(0, 36.5, 0)) * CFrame.Angles(0, 0, math.pi / 2), PINK, M.Neon, rot, false)
	rim.Shape = Enum.PartType.Cylinder
	rainbow(rim, 0, 0.2)
	local cone = P("Cone", Vector3.new(14, 14, 14), CFrame.new(c + Vector3.new(0, 47, 0)), GOLD, M.Metal, rot, false)
	cone.Shape = Enum.PartType.Ball
	addLight(cone, YELLOW, 70, 3)
	for k = 0, 23 do
		local a = k / 24 * math.pi * 2
		local b = P("Bulb", Vector3.new(1.4, 1.4, 1.4), CFrame.new(c + Vector3.new(math.cos(a) * 27, 36, math.sin(a) * 27)), Color3.fromHSV(k / 24, 0.8, 1), M.Neon, rot, false)
		b.Shape = Enum.PartType.Ball
	end
	local horses = {}
	for i = 0, 7 do
		local h = newModel("Horse" .. i)
		local saddle = P("Saddle", Vector3.new(2.6, 0.8, 4), CFrame.new(Center), Color3.fromHSV(i / 8, 0.7, 1), M.SmoothPlastic, h, false)
		h.PrimaryPart = saddle
		local col = (i % 2 == 0) and WHITE or Color3.fromRGB(60, 40, 30)
		RBlob(h, "Body", Vector3.new(2.8, 3, 6.5), CN(0, 0.6, 0), col, M.SmoothPlastic)
		RBlob(h, "Neck", Vector3.new(1.6, 4, 1.8), CN(0, 2.6, -2.8) * CFrame.Angles(math.rad(-25), 0, 0), col, M.SmoothPlastic)
		RBlob(h, "Head", Vector3.new(1.6, 1.6, 3), CN(0, 4.4, -4.3), col, M.SmoothPlastic)
		RBlob(h, "Tail", Vector3.new(0.8, 3.4, 0.8), CN(0, 0.2, 3.5) * CFrame.Angles(math.rad(25), 0, 0), PINK, M.Neon)
		for _, lx in ipairs({ -0.9, 0.9 }) do
			for _, lz in ipairs({ -2, 2 }) do
				RP(h, "Leg", Vector3.new(0.7, 3, 0.7), CN(lx, -1.8, lz), col, M.SmoothPlastic)
			end
		end
		RP(h, "Pole", Vector3.new(0.7, 36, 0.7), CN(0, 16, 0), GOLD, M.Metal)
		rideSeat(ride, saddle, CN(0, 2.2, 0), "Horse", 32)
		horses[i] = h
	end
	local a = 0
	ride.update = function(dt, t)
		a = a + dt * 0.55
		rot:PivotTo(CFrame.new(c + Vector3.new(0, 2.5, 0)) * CFrame.Angles(0, a, 0) * CFrame.Angles(0, 0, math.pi / 2))
		for i = 0, 7 do
			local ph = i / 8 * math.pi * 2
			local bob = math.sin(t * 2.4 + ph * 2) * 2.4
			horses[i]:PivotTo(CFrame.new(c + Vector3.new(0, 8, 0)) * CFrame.Angles(0, a + ph, 0) * CFrame.new(16, bob, 0))
		end
	end
end

--==================================================
-- RIDE 4: DROP TOWER
--==================================================
section("Drop tower")
do
	local ride = newRide("Drop Tower", at(-290, 1, -20))
	ride.duration = 44
	local x0, z0 = -290, -60
	B("TowerBase", 30, 3, 30, x0, 1.5, z0, IRON, M.Concrete)
	for _, d in ipairs({ { -5, -5 }, { 5, -5 }, { -5, 5 }, { 5, 5 } }) do
		B("TowerCol", 2, 128, 2, x0 + d[1], 64, z0 + d[2], Color3.fromRGB(200, 30, 60), M.Metal)
	end
	for y = 12, 120, 12 do B("TowerBrace", 12, 1, 12, x0, y, z0, STEEL, M.Metal, 0, false) end
	local topn = B("TowerTop", 14, 4, 14, x0, 130, z0, GOLD, M.Metal)
	rainbow(B("TowerNeon", 15, 1, 15, x0, 127.5, z0, PINK, M.Neon, 0, false), 0, 0.3)
	addLight(topn, PINK, 90, 3)
	local car = newModel("DropCar")
	local ring = P("Ring", Vector3.new(1.4, 15, 15), CFrame.new(V(x0, 6, z0)) * CFrame.Angles(0, 0, math.pi / 2), WHITE, M.SmoothPlastic, car, false)
	ring.Shape = Enum.PartType.Cylinder
	car.PrimaryPart = ring
	local seats = {}
	for i = 0, 3 do
		local a = i / 4 * math.pi * 2
		local sp = P("Seat", Vector3.new(4, 0.8, 3.4), CFrame.new(V(x0, 6.8, z0)) * CFrame.new(math.cos(a) * 6.5, 0.3, math.sin(a) * 6.5) * CFrame.Angles(0, -a - math.pi / 2, 0), Color3.fromHSV(i / 4, 0.8, 1), M.SmoothPlastic, car, false)
		P("Back", Vector3.new(4, 3, 0.5), sp.CFrame * CN(0, 1.8, 1.4), BLACK, M.SmoothPlastic, car, false)
		seats[i] = sp
	end
	local cycle = 30
	local function height(t)
		t = t % cycle
		if t < 4 then return 6 end                                    -- load
		if t < 14 then return 6 + 112 * smooth((t - 4) / 10) end     -- rise
		if t < 17 then return 118 end                                 -- hold
		if t < 18.32 then                                          -- free fall
			local u = t - 17
			return math.max(118 - 0.5 * 120 * u * u, 14)
		end
		if t < 19.72 then                                    -- brake
			return 14 - 8 * smooth((t - 18.32) / 1.4)
		end
		return 6
	end
	local prompts = {}
	for i = 0, 3 do prompts[i] = rideSeat(ride, seats[i], CN(0, 2.4, 0), "Drop seat", 44) end
	local hcur = 6
	ride.noLeave = function() return hcur > 9 end
	local lastT = 0
	ride.update = function(dt, t)
		hcur = height(t)
		car:PivotTo(CFrame.new(V(x0, hcur, z0)) * CFrame.Angles(0, 0, math.pi / 2))
		for i = 0, 3 do prompts[i].Enabled = hcur < 9 end
		local c = RS.cur
		if c and c.ride == ride then
			local tt = t % cycle
			local h = getHum()
			if h then
				if tt > 17 and tt < 19.2 then
					h.CameraOffset = Vector3.new((math.random() - 0.5) * 0.5, (math.random() - 0.5) * 0.5, 0)
				else
					h.CameraOffset = Vector3.zero
				end
			end
		end
	end
end

local function cyc(t, period, rampUp, rampDown)
	local u = t % period
	local up = smooth(u / rampUp)
	local down = 1 - smooth((u - (period - rampDown)) / rampDown)
	return 0.1 + 0.9 * up * down
end
local function inputDir()
	local h = getHum()
	local md = h and h.MoveDirection or Vector3.zero
	if md.Magnitude > 0.1 then return Vector3.new(md.X, 0, md.Z).Unit end
	local cam = getCam()
	if not cam then return Vector3.zero end
	local look = cam.CFrame.LookVector
	look = Vector3.new(look.X, 0, look.Z)
	if look.Magnitude < 0.01 then return Vector3.zero end
	look = look.Unit
	local right = Vector3.new(-look.Z, 0, look.X)
	local d = Vector3.zero
	if UIS:IsKeyDown(Enum.KeyCode.W) then d = d + look end
	if UIS:IsKeyDown(Enum.KeyCode.S) then d = d - look end
	if UIS:IsKeyDown(Enum.KeyCode.D) then d = d + right end
	if UIS:IsKeyDown(Enum.KeyCode.A) then d = d - right end
	if d.Magnitude < 0.1 then return Vector3.zero end
	return d.Unit
end

--==================================================
-- RIDE 5: BUMPER CARS (you drive: WASD / thumbstick)
--==================================================
section("Bumper cars")
do
	local ride = newRide("Bumper Cars", at(160, 1, -105))
	ride.duration = 45
	local ax, az = 160, -150
	local HX, HZ = 45, 35
	B("ArenaFloor", HX * 2, 1, HZ * 2, ax, 0.6, az, Color3.fromRGB(30, 34, 60), M.Metal)
	for i = -4, 4 do
		rainbow(B("FloorStripe", 1, 0.2, HZ * 2, ax + i * 10, 1.15, az, CYAN, M.Neon, 0, false), i * 0.1, 0.1)
	end
	local walls = { { 0, -HZ - 1, HX * 2 + 4, 2 }, { 0, HZ + 1, HX * 2 + 4, 2 }, { -HX - 1, 0, 2, HZ * 2 }, { HX + 1, 0, 2, HZ * 2 } }
	for i, w in ipairs(walls) do
		B("ArenaWall", w[3], 3, w[4], ax + w[1], 2.2, az + w[2], RED, M.SmoothPlastic)
		rainbow(B("ArenaWallNeon", w[3], 0.6, w[4], ax + w[1], 3.9, az + w[2], PINK, M.Neon, 0, false), i * 0.2, 0.15)
	end
	-- ceiling grid and poles
	B("Ceiling", HX * 2 + 6, 0.8, HZ * 2 + 6, ax, 28, az, Color3.fromRGB(20, 18, 34), M.Metal, 0, false).Transparency = 0.2
	for _, c in ipairs({ { -HX - 2, -HZ - 2 }, { HX + 2, -HZ - 2 }, { -HX - 2, HZ + 2 }, { HX + 2, HZ + 2 } }) do
		B("ArenaPost", 2, 28, 2, ax + c[1], 14, az + c[2], STEEL, M.Metal)
	end
	rainbow(B("CeilingNeon", HX * 2 + 6, 0.8, 1, ax, 27.2, az, YELLOW, M.Neon, 0, false), 0, 0.2)
	local sign = B("ArenaLight", 4, 4, 4, ax, 26, az, WHITE, M.Neon, 0, false)
	addLight(sign, PINK, 100, 2.5)
	local cars = {}
	local cols = { RED, CYAN, LIME, YELLOW, PURPLE, ORANGE }
	for i = 1, 6 do
		local m = newModel("Car" .. i)
		local body = P("Body", Vector3.new(6, 2, 7.5), CFrame.new(Center), cols[i], M.SmoothPlastic, m, false)
		m.PrimaryPart = body
		RP(m, "Bumper", Vector3.new(7.4, 1, 8.8), CN(0, -0.6, 0), WHITE, M.Metal)
		RP(m, "Seat", Vector3.new(3.4, 1.4, 2.6), CN(0, 1.4, 0.8), BLACK, M.SmoothPlastic)
		RP(m, "SeatBack", Vector3.new(3.4, 2.6, 0.6), CN(0, 2.4, 1.9), BLACK, M.SmoothPlastic)
		RP(m, "Pole", Vector3.new(0.4, 22, 0.4), CN(0, 12, 2.8), STEEL, M.Metal)
		local nb = RP(m, "Nose", Vector3.new(4, 0.5, 0.6), CN(0, 1.1, -3.7), WHITE, M.Neon)
		rainbow(nb, i / 6, 0.2)
		local c = { m = m, x = -30 + (i % 3) * 30, z = (i <= 3) and -18 or 18, vx = 0, vz = 0, dir = Vector3.new(0, 0, -1), tx = 0, tz = 0, tt = 0 }
		c.body = body
		cars[i] = c
		rideSeat(ride, body, CN(0, 2.3, 0.4), "Bumper car", 45).ActionText = "Drive"
	end
	local function ownCar()
		local cur = RS.cur
		if cur and cur.ride == ride then
			for _, c in ipairs(cars) do if c.body == cur.part then return c end end
		end
	end
	ride.update = function(dt, t)
		local mine = ownCar()
		for _, c in ipairs(cars) do
			local want
			if c == mine then
				want = inputDir()
			else
				c.tt = c.tt - dt
				if c.tt <= 0 then
					c.tt = 1 + math.random() * 2
					c.tx = (math.random() - 0.5) * (HX * 1.7)
					c.tz = (math.random() - 0.5) * (HZ * 1.7)
				end
				local d = Vector3.new(c.tx - c.x, 0, c.tz - c.z)
				want = d.Magnitude > 2 and d.Unit * 0.8 or Vector3.zero
			end
			local sp = (c == mine) and 34 or 22
			c.vx = c.vx + (want.X * sp - c.vx) * math.min(1, dt * 2.2)
			c.vz = c.vz + (want.Z * sp - c.vz) * math.min(1, dt * 2.2)
			c.x = c.x + c.vx * dt
			c.z = c.z + c.vz * dt
			if c.x > HX - 4.5 then c.x = HX - 4.5 c.vx = -math.abs(c.vx) * 0.7 end
			if c.x < -HX + 4.5 then c.x = -HX + 4.5 c.vx = math.abs(c.vx) * 0.7 end
			if c.z > HZ - 4.5 then c.z = HZ - 4.5 c.vz = -math.abs(c.vz) * 0.7 end
			if c.z < -HZ + 4.5 then c.z = -HZ + 4.5 c.vz = math.abs(c.vz) * 0.7 end
		end
		local hit = false
		for i = 1, #cars do
			for j = i + 1, #cars do
				local a, b = cars[i], cars[j]
				local dx, dz = a.x - b.x, a.z - b.z
				local d = math.sqrt(dx * dx + dz * dz)
				if d < 7.5 and d > 0.001 then
					local nx, nz = dx / d, dz / d
					local push = (7.5 - d) / 2
					a.x, a.z = a.x + nx * push, a.z + nz * push
					b.x, b.z = b.x - nx * push, b.z - nz * push
					local rel = (a.vx - b.vx) * nx + (a.vz - b.vz) * nz
					if rel < 0 then
						local imp = -rel * 1.25
						a.vx, a.vz = a.vx + nx * imp, a.vz + nz * imp
						b.vx, b.vz = b.vx - nx * imp, b.vz - nz * imp
						if a == mine or b == mine then hit = true end
					end
				end
			end
		end
		for _, c in ipairs(cars) do
			local sp = math.sqrt(c.vx * c.vx + c.vz * c.vz)
			if sp > 2 then c.dir = c.dir:Lerp(Vector3.new(c.vx, 0, c.vz).Unit, math.min(1, dt * 8)) end
			if c.dir.Magnitude < 0.01 then c.dir = Vector3.new(0, 0, -1) end
			local pos = Vector3.new(ax + c.x, 2.1, az + c.z) + Center
			c.m:PivotTo(CFrame.lookAt(pos, pos + c.dir.Unit))
		end
		if mine then
			local h = getHum()
			if h then
				h.CameraOffset = hit and Vector3.new((math.random() - 0.5) * 1.6, (math.random() - 0.5) * 1.6, 0) or Vector3.zero
			end
		end
	end
	-- the body is facing -Z at build; the rider seat offset sits on the seat
end

--==================================================
-- RIDE 6: STAR FLYER (chair swing)
--==================================================
section("Star flyer")
do
	local ride = newRide("Star Flyer", at(-170, 1, 100))
	ride.duration = 40
	local x0, z0 = -170, 60
	local top = V(x0, 48, z0)
	B("FlyerBase", 22, 2, 22, x0, 1, z0, IRON, M.Concrete)
	VC("FlyerTower", 3.4, 46, x0, 24, z0, Color3.fromRGB(240, 240, 255), M.Metal)
	local disc = newModel("FlyerDisc")
	local d = P("Disc", Vector3.new(1.6, 36, 36), CFrame.new(top) * CFrame.Angles(0, 0, math.pi / 2), PURPLE, M.SmoothPlastic, disc, false)
	d.Shape = Enum.PartType.Cylinder
	disc.PrimaryPart = d
	local rm = P("DiscRim", Vector3.new(0.8, 36.6, 36.6), CFrame.new(top) * CN(0, -1, 0) * CFrame.Angles(0, 0, math.pi / 2), PINK, M.Neon, disc, false)
	rm.Shape = Enum.PartType.Cylinder
	rainbow(rm, 0, 0.25)
	local cp = P("Crown", Vector3.new(8, 8, 8), CFrame.new(top) * CN(0, 3, 0), GOLD, M.Neon, disc, false)
	cp.Shape = Enum.PartType.Ball
	addLight(cp, YELLOW, 60, 2.5)
	local chairs = {}
	for i = 0, 11 do
		local m = newModel("Chair" .. i)
		local seatp = P("Seat", Vector3.new(3.6, 0.8, 3.4), CFrame.new(Center), Color3.fromHSV(i / 12, 0.75, 1), M.SmoothPlastic, m, false)
		m.PrimaryPart = seatp
		RP(m, "Back", Vector3.new(3.6, 3, 0.6), CN(0, 1.8, 1.4), WHITE, M.SmoothPlastic)
		RP(m, "Bar", Vector3.new(3.8, 0.4, 0.4), CN(0, 1.6, -1.2), STEEL, M.Metal)
		local chain = P("Chain", Vector3.new(0.3, 0.3, 20), CFrame.new(Center), STEEL, M.Metal, CUR, false)
		rideSeat(ride, seatp, CN(0, 2.3, 0.2), "Chair", 40)
		chairs[i] = { m = m, seat = seatp, chain = chain }
	end
	local ang = 0
	local L = 22
	ride.update = function(dt, t)
		local w = 0.12 + 1.45 * (cyc(t, 40, 8, 8) - 0.1) / 0.9
		ang = ang + w * dt
		local tilt = 0.08 + 0.62 * (w / 1.57)
		disc:PivotTo(CFrame.new(top) * CFrame.Angles(0, ang, 0) * CFrame.Angles(0, 0, math.pi / 2))
		for i = 0, 11 do
			local ph = -(ang + i / 12 * math.pi * 2)
			local out = Vector3.new(math.cos(ph), 0, math.sin(ph))
			local tangent = Vector3.new(math.sin(ph), 0, -math.cos(ph))
			local attach = top + out * 17 + Vector3.new(0, -1, 0)
			local dvec = out * math.sin(tilt) + Vector3.new(0, -math.cos(tilt), 0)
			local pos = attach + dvec * L
			local up = -dvec
			local right = tangent:Cross(up)
			local cf = CFrame.fromMatrix(pos - up * 0.4, right, up)
			chairs[i].m:PivotTo(cf)
			chairs[i].chain.CFrame = CFrame.lookAt((attach + pos) / 2 + up * 1, attach)
			chairs[i].chain.Size = Vector3.new(0.3, 0.3, L + 1)
		end
	end
end

--==================================================
-- RIDE 7: PIRATE SHIP
--==================================================
section("Pirate ship")
do
	local ride = newRide("Pirate Ship", at(170, 1, 110))
	ride.duration = 40
	local x0, z0 = 170, 60
	local axle = V(x0, 44, z0)
	for _, sx in ipairs({ -16, 16 }) do
		Beam("PirateLeg", V(x0 + sx, 0, z0 - 20), V(x0 + sx, 44, z0), 2.4, Color3.fromRGB(120, 20, 40), M.Metal, false)
		Beam("PirateLeg", V(x0 + sx, 0, z0 + 20), V(x0 + sx, 44, z0), 2.4, Color3.fromRGB(120, 20, 40), M.Metal, false)
	end
	B("PirateBaseA", 44, 2, 6, x0, 1, z0 - 20, IRON, M.Concrete)
	B("PirateBaseB", 44, 2, 6, x0, 1, z0 + 20, IRON, M.Concrete)
	local ax = P("Axle", Vector3.new(36, 2.4, 2.4), CFrame.new(axle), STEEL, M.Metal, CUR, false)
	B("PirateDeck", 30, 1, 66, x0, 0.5, z0, Color3.fromRGB(60, 40, 40), M.Wood, 0, false)
	local ship = newModel("Ship")
	local hull = RBlob(ship, "Hull", Vector3.new(18, 7, 46), CN(0, 0, 0), Color3.fromRGB(110, 55, 30), M.Wood)
	ship.PrimaryPart = hull
	RBlob(ship, "Deck", Vector3.new(15, 1, 40), CN(0, 3, 0), Color3.fromRGB(190, 140, 80), M.Wood)
	for _, sx in ipairs({ -12, 12 }) do RP(ship, "Arm", Vector3.new(1.2, 32, 1.2), CN(sx, 16, 0), STEEL, M.Metal) end
	rainbow(RP(ship, "Trim", Vector3.new(19, 0.6, 47), CN(0, 3.4, 0), PINK, M.Neon), 0, 0.2)
	RP(ship, "Mast", Vector3.new(1, 14, 1), CN(0, 10, 4), WOOD, M.Wood)
	RP(ship, "Flag", Vector3.new(0.4, 5, 8), CN(0, 15, 8), BLACK, M.Fabric)
	RP(ship, "Bow", Vector3.new(4, 4, 8), CN(0, 3, -24), Color3.fromRGB(110, 55, 30), M.Wood)
	local lamp = RBall(ship, "ShipLamp", 3, CN(0, 8, -6), YELLOW, M.Neon)
	addLight(lamp, YELLOW, 40, 2)
	local seats = {}
	for _, z in ipairs({ -12, 0, 12 }) do
		for _, sx in ipairs({ -4.5, 4.5 }) do
			local s = RP(ship, "Bench", Vector3.new(5, 0.8, 4), CN(sx, 4, z), RED, M.SmoothPlastic)
			RP(ship, "BenchBack", Vector3.new(5, 2.5, 0.5), CN(sx, 5.4, z + 1.9), RED, M.SmoothPlastic)
			rideSeat(ride, s, CN(0, 2.3, 0), "Bench", 40)
		end
	end
	ship:PivotTo(CFrame.new(axle) * CN(0, -32, 0))
	local ph = 0
	ride.update = function(dt, t)
		local amp = 1.15 * cyc(t, 44, 14, 10)
		ph = ph + dt * 1.05
		local th = amp * math.sin(ph)
		ship:PivotTo(CFrame.new(axle) * CFrame.Angles(th, 0, 0) * CN(0, -32, 0))
	end
end

--==================================================
-- RIDE 8: TOP SPIN
--==================================================
section("Top spin")
do
	local ride = newRide("Top Spin", at(-110, 1, 245))
	ride.duration = 38
	local x0, z0 = -110, 200
	local axle = V(x0, 36, z0)
	for _, sx in ipairs({ -17, 17 }) do
		B("SpinTower", 3, 36, 8, x0 + sx, 18, z0, Color3.fromRGB(30, 150, 220), M.Metal)
		B("SpinFoot", 8, 2, 24, x0 + sx, 1, z0, IRON, M.Concrete)
		local lamp = Ball("SpinLamp", 3, x0 + sx, 38, z0, CYAN, M.Neon)
		addLight(lamp, CYAN, 50, 2)
	end
	local arms = {}
	for _, sx in ipairs({ -14, 14 }) do arms[#arms + 1] = { sx = sx, part = P("Arm", Vector3.new(1.8, 24, 1.8), CFrame.new(axle), STEEL, M.Metal, CUR, false) } end
	local plat = newModel("SpinPlat")
	local bench = P("Bench", Vector3.new(34, 1.4, 8), CFrame.new(Center), RED, M.SmoothPlastic, plat, false)
	plat.PrimaryPart = bench
	rainbow(P("BenchNeon", Vector3.new(34.4, 0.5, 8.4), CFrame.new(Center), PINK, M.Neon, plat, false), 0, 0.2)
	for _, side in ipairs({ 1, -1 }) do
		for _, sx in ipairs({ -10.5, -3.5, 3.5, 10.5 }) do
			local sp = RP(plat, "Seat", Vector3.new(5, 0.8, 4), CN(sx, side * 1.6, 0), Color3.fromHSV((sx + 20) / 40, 0.7, 1), M.SmoothPlastic)
			RP(plat, "Back", Vector3.new(5, 0.5, 3), CN(sx, side * 3, 2.2), BLACK, M.SmoothPlastic)
			local off = side == 1 and CN(0, 2.4, 0) or (CN(0, -2.4, 0) * CFrame.Angles(math.pi, 0, 0))
			rideSeat(ride, sp, off, "Seat", 38)
		end
	end
	local spin = 0
	ride.update = function(dt, t)
		local k = cyc(t, 38, 6, 6)
		local A = 2.5 * k * math.sin(t * 0.9)
		spin = spin + dt * (0.4 + 2.6 * (k - 0.1) / 0.9)
		local armCF = CFrame.new(axle) * CFrame.Angles(A, 0, 0)
		for _, a in ipairs(arms) do a.part.CFrame = armCF * CN(a.sx, -12, 0) end
		plat:PivotTo(armCF * CN(0, -24, 0) * CFrame.Angles(spin, 0, 0))
	end
end

--==================================================
-- RIDE 9: TILT-A-WHIRL
--==================================================
section("Tilt a whirl")
do
	local ride = newRide("Tilt-A-Whirl", at(110, 1, 245))
	ride.duration = 36
	local x0, z0 = 110, 200
	VC("TiltBase", 30, 2, x0, 1, z0, Color3.fromRGB(40, 30, 60), M.Concrete)
	local plat = newModel("TiltPlat")
	local disc = P("Disc", Vector3.new(1.4, 52, 52), CFrame.new(V(x0, 3, z0)) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(40, 220, 150), M.SmoothPlastic, plat, true)
	disc.Shape = Enum.PartType.Cylinder
	plat.PrimaryPart = disc
	local ring = P("Ring", Vector3.new(0.6, 53, 53), CFrame.new(V(x0, 3.6, z0)) * CFrame.Angles(0, 0, math.pi / 2), PINK, M.Neon, plat, false)
	ring.Shape = Enum.PartType.Cylinder
	rainbow(ring, 0, 0.2)
	local centerpiece = Ball("TiltCenter", 8, x0, 9, z0, YELLOW, M.Neon)
	addLight(centerpiece, YELLOW, 50, 2)
	local cars = {}
	for i = 0, 3 do
		local m = newModel("TiltCar" .. i)
		local base = P("Base", Vector3.new(0.8, 11, 11), CFrame.new(Center), Color3.fromHSV(i / 4, 0.8, 1), M.SmoothPlastic, m, false)
		base.Shape = Enum.PartType.Cylinder
		base.CFrame = CFrame.new(Center) * CFrame.Angles(0, 0, math.pi / 2)
		m.PrimaryPart = base
		local seatp = {}
		for k = 0, 2 do
			local a = k / 3 * math.pi * 2
			local sp = RP(m, "Seat", Vector3.new(3, 1.2, 2.6), CN(math.cos(a) * 3.4, 1, math.sin(a) * 3.4) * CFrame.Angles(0, -a + math.pi / 2, 0), Color3.fromHSV(i / 4, 0.4, 1), M.SmoothPlastic)
			RP(m, "Back", Vector3.new(3, 2.4, 0.5), CN(math.cos(a) * 4.7, 2, math.sin(a) * 4.7) * CFrame.Angles(0, -a + math.pi / 2, 0), WHITE, M.SmoothPlastic)
			rideSeat(ride, sp, CN(0, 2.2, 0), "Spinner", 36)
		end
		cars[i] = m
	end
	local a, tw = 0, 0
	ride.update = function(dt, t)
		local k = cyc(t, 36, 6, 6)
		a = a + dt * (0.25 + 0.5 * k)
		local wob = 0.14 * k
		local pcf = CFrame.new(V(x0, 3, z0)) * CFrame.Angles(wob * math.sin(a * 3), 0, wob * math.cos(a * 3))
		plat:PivotTo(pcf * CFrame.Angles(0, a, 0) * CFrame.Angles(0, 0, math.pi / 2))
		tw = tw + dt * (1.2 + 3 * k)
		for i = 0, 3 do
			local ph = i / 4 * math.pi * 2
			local lp = CFrame.Angles(0, ph, 0) * CN(15, 1.4, 0)
			cars[i]:PivotTo(pcf * CFrame.Angles(0, a, 0) * lp * CFrame.Angles(0, -tw + i, 0) * CFrame.Angles(0, 0, math.pi / 2))
		end
	end
end

--==================================================
-- RIDE 10: SKY SWINGER (giant swing arm + spinning disc)
--==================================================
section("Sky swinger")
do
	local ride = newRide("Sky Swinger", at(-250, 1, 270))
	ride.duration = 40
	local x0, z0 = -250, 220
	local pivot = V(x0, 66, z0)
	for _, sz in ipairs({ -8, 8 }) do
		Beam("SwingLeg", V(x0 - 22, 0, z0 + sz * 2), V(x0, 66, z0 + sz), 2.6, Color3.fromRGB(230, 120, 20), M.Metal, false)
		Beam("SwingLeg", V(x0 + 22, 0, z0 + sz * 2), V(x0, 66, z0 + sz), 2.6, Color3.fromRGB(230, 120, 20), M.Metal, false)
	end
	B("SwingFoot", 50, 2, 34, x0, 1, z0, IRON, M.Concrete)
	P("SwingAxle", Vector3.new(2.4, 2.4, 22), CFrame.new(pivot), STEEL, M.Metal, CUR, false)
	local lamp = Ball("SwingLamp", 5, x0, 70, z0, ORANGE, M.Neon)
	addLight(lamp, ORANGE, 90, 3)
	local arm = P("Arm", Vector3.new(2.2, 48, 2.2), CFrame.new(pivot), STEEL, M.Metal, CUR, false)
	local g = newModel("SwingDisc")
	local dd = P("Disc", Vector3.new(1.2, 30, 30), CFrame.new(Center) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(255, 120, 30), M.SmoothPlastic, g, false)
	dd.Shape = Enum.PartType.Cylinder
	g.PrimaryPart = dd
	local rr = P("DiscRim", Vector3.new(0.5, 30.6, 30.6), CFrame.new(Center) * CN(0, -0.6, 0) * CFrame.Angles(0, 0, math.pi / 2), PINK, M.Neon, g, false)
	rr.Shape = Enum.PartType.Cylinder
	rainbow(rr, 0.1, 0.3)
	for i = 0, 5 do
		local a = i / 6 * math.pi * 2
		local rel = CN(math.cos(a) * 10, 1.2, math.sin(a) * 10) * CFrame.Angles(0, -a - math.pi / 2, 0)
		local sp = RP(g, "Seat", Vector3.new(4, 0.9, 3.4), rel, Color3.fromHSV(i / 6, 0.8, 1), M.SmoothPlastic)
		RP(g, "Back", Vector3.new(4, 3, 0.5), rel * CN(0, 1.8, 1.5), BLACK, M.SmoothPlastic)
		RP(g, "Bar", Vector3.new(4.2, 0.4, 0.4), rel * CN(0, 1.7, -1.3), STEEL, M.Metal)
		rideSeat(ride, sp, CN(0, 2.3, 0), "Seat", 40)
	end
	local spin = 0
	ride.update = function(dt, t)
		local k = cyc(t, 44, 14, 8)
		local th = 1.85 * k * math.sin(t * 0.62)
		spin = spin + dt * (0.5 + 1.5 * k)
		local acf = CFrame.new(pivot) * CFrame.Angles(0, 0, th)
		arm.CFrame = acf * CN(0, -24, 0)
		g:PivotTo(acf * CN(0, -50, 0) * CFrame.Angles(0, spin, 0) * CFrame.Angles(0, 0, math.pi / 2))
	end
end

--==================================================
-- RIDE 11: SKY TRAM (cable car shuttle, board while docked)
--==================================================
section("Sky tram")
local TRAM = {}
do
	local ride = newRide("Sky Tram", at(-385, 1, -300))
	ride.duration = 400
	local x0 = -400
	local ZA, ZB = -330, 330
	local function path(u) return V(x0, 1.8 + 62 * math.sin(math.pi * u) ^ 0.8, ZA + (ZB - ZA) * u) end
	for _, z in ipairs({ ZA, ZB }) do
		B("TramStation", 26, 1, 26, x0, 0.5, z, Color3.fromRGB(70, 60, 100), M.Concrete)
		B("TramRoofPost", 2, 20, 2, x0 - 11, 10, z, IRON, M.Metal)
		B("TramRoofPost", 2, 20, 2, x0 + 11, 10, z, IRON, M.Metal)
		rainbow(B("TramRoof", 28, 1.2, 28, x0, 20.5, z, PINK, M.Neon, 0, false), z, 0.1)
		B("TramSign", 12, 4, 1, x0, 24, z, BLACK, M.SmoothPlastic)
	end
	local N = 28
	for i = 0, N - 1 do
		local a, b = path(i / N) + Vector3.new(0, 11, 0), path((i + 1) / N) + Vector3.new(0, 11, 0)
		Beam("Cable", a, b, 0.7, STEEL, M.Metal, false)
	end
	for _, u in ipairs({ 0.2, 0.4, 0.6, 0.8 }) do
		local p = path(u)
		Beam("Pylon", Vector3.new(p.X, Center.Y, p.Z), p + Vector3.new(0, 13, 0), 3, Color3.fromRGB(230, 230, 250), M.Metal, false)
	end
	local cab = newModel("TramCabin")
	local floor = RP(cab, "Floor", Vector3.new(9, 1, 13), CN(0, 0, 0), Color3.fromRGB(30, 30, 50), M.SmoothPlastic)
	cab.PrimaryPart = floor
	for _, sx in ipairs({ -4.5, 4.5 }) do
		local gl = RP(cab, "Glass", Vector3.new(0.4, 6, 13), CN(sx, 3.5, 0), CYAN, M.Glass)
		gl.Transparency = 0.6
	end
	RP(cab, "Roof", Vector3.new(10, 1, 14), CN(0, 6.8, 0), RED, M.SmoothPlastic)
	rainbow(RP(cab, "RoofNeon", Vector3.new(10.4, 0.5, 14.4), CN(0, 6.3, 0), PINK, M.Neon), 0, 0.2)
	RP(cab, "Hanger", Vector3.new(0.8, 4.2, 0.8), CN(0, 9.2, 0), STEEL, M.Metal)
	local cl = RBall(cab, "CabLamp", 2, CN(0, 5.5, 0), YELLOW, M.Neon)
	addLight(cl, YELLOW, 30, 1.8)
	local prompts = {}
	for k, sz in ipairs({ -3, 3 }) do
		local sp = RP(cab, "Bench", Vector3.new(7, 0.8, 3), CN(0, 0.9, sz), WOOD, M.Wood)
		prompts[k] = rideSeat(ride, sp, CN(0, 2.2, 0), "Sky Tram", 400)
	end
	local DW, TR = 7, 20
	local cycle = (DW + TR) * 2
	local function state(T)
		local tt = T % cycle
		if tt < DW then return 0, true end
		if tt < DW + TR then return smooth((tt - DW) / TR), false end
		if tt < 2 * DW + TR then return 1, true end
		return 1 - smooth((tt - 2 * DW - TR) / TR), false
	end
	local function tripIdx(T) return math.floor(T / (DW + TR)) end
	local docked = true
	ride.noLeave = function() return not docked end
	ride.onBoard = function() ride._b = tripIdx(RS.T) end
	ride.done = function() return docked and ride._b and tripIdx(RS.T) > ride._b end
	ride.update = function(dt, T)
		local u, d = state(T)
		docked = d
		cab:PivotTo(CFrame.new(path(u) - Vector3.new(0, 0, 0)) * CFrame.Angles(0, 0, 0))
		for _, p in ipairs(prompts) do p.Enabled = d end
		ride.exitCF = (u < 0.5) and at(-385, 1, -308) or at(-385, 1, 308)
	end
end

--==================================================
-- RIDE 12: MINI TRAIN (ring track around the plaza)
--==================================================
section("Mini train")
do
	local ride = newRide("Mini Train", at(0, 1, -112))
	ride.duration = 34
	local R = 100
	local N = 64
	for i = 0, N - 1 do
		local a1, a2 = i / N * math.pi * 2, (i + 1) / N * math.pi * 2
		for _, rr in ipairs({ R - 3, R + 3 }) do
			Beam("Rail", V(math.cos(a1) * rr, 1.1, math.sin(a1) * rr), V(math.cos(a2) * rr, 1.1, math.sin(a2) * rr), 0.7, STEEL, M.Metal, false)
		end
		if i % 2 == 0 then
			local a = (a1 + a2) / 2
			local p = P("Tie", Vector3.new(9, 0.5, 2), CFrame.lookAt(V(math.cos(a) * R, 0.7, math.sin(a) * R), V(math.cos(a) * R, 0.7, math.sin(a) * R) + Vector3.new(math.cos(a), 0, math.sin(a))), WOOD, M.Wood, nil, false)
		end
	end
	local cars = {}
	for i = 0, 5 do
		local m = newModel("TrainCar" .. i)
		local base = RP(m, "Base", Vector3.new(6, 1, 8), CN(0, 1.3, 0), i == 0 and RED or Color3.fromHSV(i / 6, 0.7, 1), M.SmoothPlastic)
		m.PrimaryPart = base
		RP(m, "WheelsA", Vector3.new(7, 1.4, 1.4), CN(0, 0.7, -2.4), IRON, M.Metal)
		RP(m, "WheelsB", Vector3.new(7, 1.4, 1.4), CN(0, 0.7, 2.4), IRON, M.Metal)
		if i == 0 then
			RP(m, "Boiler", Vector3.new(4.4, 4.4, 5), CN(0, 4, -1), Color3.fromRGB(20, 20, 30), M.Metal)
			RP(m, "Stack", Vector3.new(1.6, 3, 1.6), CN(0, 7, -3), GOLD, M.Metal)
			local lt = RBall(m, "Headlight", 1.8, CN(0, 4, -3.8), YELLOW, M.Neon)
			addLight(lt, YELLOW, 40, 2)
			local sm = Instance.new("ParticleEmitter")
			sm.Rate = 18
			sm.Lifetime = NumberRange.new(1.5, 2.5)
			sm.Speed = NumberRange.new(4, 6)
			sm.Size = NumberSequence.new(1, 4)
			sm.Transparency = NumberSequence.new(0.4, 1)
			sm.Color = ColorSequence.new(Color3.fromRGB(230, 230, 240))
			sm.Acceleration = Vector3.new(0, 3, 0)
			sm.Parent = base
			sm.Parent = RP(m, "Smoke", Vector3.new(0.5, 0.5, 0.5), CN(0, 8.8, -3), BLACK, M.SmoothPlastic)
			sm.Rate = 18
		else
			RP(m, "Seat", Vector3.new(4.6, 0.8, 5), CN(0, 2.2, 0), WHITE, M.SmoothPlastic)
			RP(m, "Back", Vector3.new(4.6, 2.5, 0.5), CN(0, 3.6, 2.4), WHITE, M.SmoothPlastic)
		end
		rideSeat(ride, base, CN(0, 3.2, 0), "Train", 34)
		cars[i] = m
	end
	local ang = 0
	ride.update = function(dt)
		ang = ang + dt * 0.2
		for i = 0, 5 do
			local f = ang - i * 0.085
			local pos = V(math.cos(f) * R, 0, math.sin(f) * R)
			local tan = Vector3.new(-math.sin(f), 0, math.cos(f))
			cars[i]:PivotTo(CFrame.lookAt(pos, pos + tan))
		end
	end
end

--==================================================
-- RIDE 13: SPIRAL SLIDE (lift up, slide down)
--==================================================
section("Spiral slide")
do
	local ride = newRide("Spiral Slide", at(-326, 1, 100))
	ride.duration = 40
	local x0, z0 = -300, 100
	local R, TOP, BOT = 22, 70, 3
	local TURNS = 3.5
	local th0, th1 = 0, TURNS * math.pi * 2
	local function hp(u)
		local th = th0 + (th1 - th0) * u
		return Vector3.new(x0 + math.cos(th) * R, TOP + (BOT - TOP) * u, z0 + math.sin(th) * R)
	end
	for _, c in ipairs({ { -9, -9 }, { 9, -9 }, { -9, 9 }, { 9, 9 } }) do
		B("SlideCol", 2.4, TOP + 8, 2.4, x0 + c[1], (TOP + 8) / 2, z0 + c[2], Color3.fromRGB(240, 70, 160), M.Metal)
	end
	B("SlideLiftPad", 12, 1, 12, x0, 0.5, z0, STEEL, M.Metal, 0, false)
	local deck = VC("SlideDeck", 26, 1.4, x0, TOP + 8, z0, WHITE, M.SmoothPlastic, false)
	rainbow(VC("SlideDeckNeon", 26.6, 0.6, x0, TOP + 7.4, z0, PINK, M.Neon, false), 0, 0.2)
	local cap = Ball("SlideTop", 12, x0, TOP + 16, z0, YELLOW, M.Neon)
	addLight(cap, YELLOW, 70, 2.5)
	local N = 96
	for i = 0, N - 1 do
		local a, b = hp(i / N), hp((i + 1) / N)
		local mid = (a + b) / 2 + Center
		local aw, bw = a + Center, b + Center
		local len = (bw - aw).Magnitude + 0.5
		local cf = CFrame.lookAt(mid, bw)
		local seg = P("SlideSeg", Vector3.new(8, 0.8, len), cf, Color3.fromHSV(i / N, 0.55, 1), M.SmoothPlastic, nil, true)
		for _, s in ipairs({ -4.2, 4.2 }) do
			local rail = P("SlideRail", Vector3.new(0.6, 2, len), cf * CN(s, 1.2, 0), (s < 0) and CYAN or PINK, M.Neon, nil, false)
		end
	end
	local sled = P("Sled", Vector3.new(4, 1, 5), CFrame.new(V(x0, 2, z0)), RED, M.SmoothPlastic, nil, false)
	RP(CUR, "SledBack", Vector3.new(4, 2, 0.6), CN(x0, 3.2, z0 + 2.4), WHITE, M.SmoothPlastic)
	rideSeat(ride, sled, CN(0, 2.2, 0.2), "Lift & Slide", 40).ActionText = "Lift up & slide"
	local DUR1, DUR2, DUR3 = 7, 1.2, 12
	local function sledCF(t)
		if t < DUR1 then
			return CFrame.new(V(x0, 2 + (TOP + 0.6 - 2) * smooth(t / DUR1), z0))
		elseif t < DUR1 + DUR2 then
			local u = smooth((t - DUR1) / DUR2)
			local p = hp(0)
			return CFrame.new(V(x0, TOP + 0.6, z0):Lerp(p + Center + Vector3.new(0, 0.6, 0), u))
		else
			local u = math.clamp((t - DUR1 - DUR2) / DUR3, 0, 1)
			u = u ^ 1.12
			local a, b = hp(u) + Center, hp(math.min(u + 0.01, 1)) + Center
			return CFrame.lookAt(a + Vector3.new(0, 0.7, 0), b + Vector3.new(0, 0.7, 0))
		end
	end
	ride.done = function()
		local c = RS.cur
		return c and c.ride == ride and (os.clock() - c.t0) > DUR1 + DUR2 + DUR3 + 0.3
	end
	ride.noLeave = function() return false end
	ride.update = function()
		local c = RS.cur
		if c and c.ride == ride then
			sled.CFrame = sledCF(os.clock() - c.t0)
		else
			sled.CFrame = CFrame.new(V(x0, 2, z0))
		end
	end
end

--==================================================
-- RIDE 14: ZIP LINE
--==================================================
section("Zip line")
do
	local ride = newRide("Zip Line", at(372, 1, -390))
	ride.duration = 30
	local A = V(-380, 50, -390)
	local Bp = V(380, 4, -390)
	Beam("ZipCable", A + Vector3.new(0, 4, 0), Bp + Vector3.new(0, 4, 0), 0.5, STEEL, M.Metal, false)
	B("ZipTower", 8, 52, 8, -386, 26, -390, Color3.fromRGB(220, 110, 20), M.Metal)
	B("ZipDeck", 14, 1, 14, -380, 50.5, -390, STEEL, M.Metal)
	for _, c in ipairs({ { -6, -6 }, { 6, -6 }, { -6, 6 }, { 6, 6 } }) do B("ZipRail", 0.5, 4, 0.5, -380 + c[1], 53, -390 + c[2], YELLOW, M.Metal, 0, false) end
	local lamp = Ball("ZipLamp", 4, -386, 56, -390, ORANGE, M.Neon)
	addLight(lamp, ORANGE, 60, 2.5)
	B("ZipEndPost", 5, 14, 5, 384, 7, -390, Color3.fromRGB(220, 110, 20), M.Metal)
	B("ZipEndPad", 24, 1, 20, 372, 0.6, -390, Color3.fromRGB(70, 60, 100), M.Concrete)
	local liftPad = B("ZipLiftPad", 12, 1, 12, -380, 0.6, -372, Color3.fromRGB(70, 60, 100), M.Concrete)
	prompt(liftPad, "Take the lift up", "Zip Line", function()
		if RS.cur then return end
		pcall(function() getChar():PivotTo(CFrame.new(V(-380, 54, -390))) end)
	end, 0.4, 14)
	local trolley = P("Trolley", Vector3.new(3, 1, 3), CFrame.lookAt(A, Bp), IRON, M.Metal, nil, false)
	RP(CUR, "TrolleyHandle", Vector3.new(0.4, 4, 0.4), CN(-380, 47, -390), YELLOW, M.Metal)
	rideSeat(ride, trolley, CN(0, -4.4, 0), "Zip Line", 30).ActionText = "Grab handle"
	local DUR = 15
	ride.done = function()
		local c = RS.cur
		return c and c.ride == ride and (os.clock() - c.t0) > DUR + 0.3
	end
	ride.noLeave = function() return false end
	ride.update = function()
		local c = RS.cur
		local u = 0
		if c and c.ride == ride then
			local t = (os.clock() - c.t0) / DUR
			u = smooth(math.clamp(t, 0, 1)) * 0.55 + math.clamp(t, 0, 1) * 0.45
			local h = getHum()
			local cam = getCam()
			if cam then cam.FieldOfView = 70 + 25 * math.sin(math.clamp(t, 0, 1) * math.pi) end
		end
		local p = A:Lerp(Bp, u)
		trolley.CFrame = CFrame.lookAt(p + Vector3.new(0, 4, 0), Bp + Vector3.new(0, 4, 0))
	end
end

--==================================================
-- RIDE 15: TRAMPOLINE PARK (bounce pads)
--==================================================
section("Trampolines")
do
	local ride = newRide("Trampoline Park", at(330, 1, 180))
	local x0, z0 = 330, 230
	B("TrampFloor", 56, 1, 56, x0, 0.5, z0, Color3.fromRGB(40, 30, 80), M.Concrete)
	local pads = {}
	for ix = -1, 1 do
		for iz = -1, 1 do
			local p = B("Pad", 12, 1, 12, x0 + ix * 16, 1.3, z0 + iz * 16, Color3.fromHSV(((ix + 1) * 3 + iz + 1) / 9, 0.7, 1), M.SmoothPlastic)
			rainbow(B("PadRing", 13, 0.4, 13, x0 + ix * 16, 0.9, z0 + iz * 16, PINK, M.Neon, 0, false), ix + iz, 0.2)
			pads[#pads + 1] = { part = p, power = (ix == 0 and iz == 0) and 135 or 95, y0 = p.Position.Y, dip = 0 }
		end
	end
	for i, s in ipairs({ { 0, -29, 58, 1 }, { 0, 29, 58, 1 }, { -29, 0, 1, 58 }, { 29, 0, 1, 58 } }) do
		local net = B("Net", s[3], 18, s[4], x0 + s[1], 9, z0 + s[2], WHITE, M.Glass, 0, true)
		net.Transparency = 0.7
	end
	local sg = B("TrampSign", 24, 6, 1, x0, 20, z0 - 30, BLACK, M.SmoothPlastic, 0, false)
	local g = Instance.new("SurfaceGui")
	g.Face = Enum.NormalId.Back
	g.SizeStudsPerPixel = 0.06
	g.Parent = sg
	local tl2 = Instance.new("TextLabel")
	tl2.Size = UDim2.fromScale(1, 1)
	tl2.BackgroundTransparency = 1
	tl2.Text = "BOUNCE! middle pad = SUPER"
	tl2.TextColor3 = LIME
	tl2.Font = Enum.Font.GothamBlack
	tl2.TextScaled = true
	tl2.Parent = g
	local tz = Instance.new("SurfaceGui")
	tz.Face = Enum.NormalId.Front
	tz.SizeStudsPerPixel = 0.06
	tz.Parent = sg
	local tl3 = tl2:Clone()
	tl3.Parent = tz
	local cd = 0
	ride.update = function(dt)
		local r = getRoot()
		for _, p in ipairs(pads) do
			if p.dip > 0 then
				p.dip = math.max(0, p.dip - dt * 5)
				p.part.Position = Vector3.new(p.part.Position.X, p.y0 - p.dip * 0.5, p.part.Position.Z)
			end
		end
		if not r or RS.cur then return end
		local pos = r.Position
		local vel = r.AssemblyLinearVelocity
		for _, p in ipairs(pads) do
			local pp = p.part.Position
			if math.abs(pos.X - pp.X) < 6.2 and math.abs(pos.Z - pp.Z) < 6.2 then
				local feet = pos.Y - 3
				local top = p.y0 + 0.5
				if feet < top + 0.9 and feet > top - 2.5 and vel.Y < 10 then
					r.AssemblyLinearVelocity = Vector3.new(vel.X, p.power, vel.Z)
					p.dip = 1
					RS.mark(ride)
					break
				end
			end
		end
	end
end

--==================================================
-- RIDE 2: DRAGON FURY (roller coaster)
-- closed spline -> resampled points -> rotation-minimizing frames -> banking
-- speed profile: chain lift, then energy based, then brakes into the station
--==================================================
section("Dragon Fury")
local COASTER = {}
do
	local ride = newRide("Dragon Fury Coaster", at(344, 1, -312))
	ride.duration = 9999
	local gold = Color3.fromRGB(255, 200, 40)

	-- ---------- waypoints (relative to Center) ----------
	local W = {}
	local function add(x, y, z) W[#W + 1] = Vector3.new(x, y, z) end
	add(330, 4, -300)                                         -- station stop (index 1)
	add(330, 4, -282) add(330, 14, -262) add(330, 34, -238) add(330, 62, -210)
	add(330, 92, -180) add(330, 120, -152) add(330, 138, -130) add(331, 142, -112)
	add(335, 138, -98)
	-- first drop (curves east)
	add(342, 122, -84) add(354, 92, -70) add(364, 56, -58) add(371, 24, -48) add(375, 8, -40)
	-- vertical loop (circle in the Y-Z plane with a small drift in x)
	local LOOP = 20
	for k = 0, LOOP - 1 do
		local th = k / LOOP * math.pi * 2
		add(376 + 10 * th / (math.pi * 2), 5 + 28 * (1 - math.cos(th)), -28 + 28 * math.sin(th) + 9 * th)
	end
	add(386, 5, 28.5) add(387, 5, 38)
	-- camelback
	add(388, 22, 52) add(389, 34, 64) add(390, 24, 76) add(390, 10, 88) add(390, 6, 100)
	-- big banked U-turn
	for k = 1, 5 do
		local ph = k * math.pi / 6
		add(340 + 50 * math.cos(ph), 6 + 20 * math.sin(ph), 100 + 50 * math.sin(ph))
	end
	-- return lane with hills and a chicane
	add(290, 6, 80) add(290, 10, 60) add(290, 32, 34) add(290, 14, 12) add(290, 8, -6)
	add(290, 16, -26) add(290, 46, -52) add(290, 18, -80) add(290, 8, -102)
	add(279, 8, -140) add(279, 8, -160) add(293, 8, -182) add(303, 8, -202) add(298, 8, -222)
	add(290, 6, -245) add(290, 5, -290) add(290, 4, -322)
	-- station U-turn
	for _, a in ipairs({ 5 * math.pi / 4, 3 * math.pi / 2, 7 * math.pi / 4 }) do
		add(310 + 20 * math.cos(a), 4, -335 + 20 * math.sin(a))
	end
	add(330, 4, -335) add(330, 4, -318)

	-- ---------- closed C1 spline (Hermite with arc-length tangents) ----------
	local nW = #W
	local dense, DS = {}, 14
	local function wp(i) return W[(i - 1) % nW + 1] end
	for i = 1, nW do
		local p0, p1, p2, p3 = wp(i - 1), wp(i), wp(i + 1), wp(i + 2)
		local h = (p2 - p1).Magnitude
		local m1 = (p2 - p0).Unit * h
		local m2 = (p3 - p1).Unit * h
		for k = 0, DS - 1 do
			local t = k / DS
			local t2, t3 = t * t, t * t * t
			dense[#dense + 1] = p1 * (2 * t3 - 3 * t2 + 1) + m1 * (t3 - 2 * t2 + t) + p2 * (-2 * t3 + 3 * t2) + m2 * (t3 - t2)
		end
	end
	-- arc-length resampling
	local nd = #dense
	local cum = { 0 }
	for i = 1, nd do cum[i + 1] = cum[i] + (dense[i % nd + 1] - dense[i]).Magnitude end
	local L = cum[nd + 1]
	local STEP = 4
	local N = math.floor(L / STEP + 0.5)
	local ds = L / N
	local Pp = {}
	do
		local j = 1
		for i = 0, N - 1 do
			local target = i * ds
			while cum[j + 1] < target do j = j + 1 end
			local seg = cum[j + 1] - cum[j]
			local a = seg > 0 and (target - cum[j]) / seg or 0
			Pp[i] = dense[j]:Lerp(dense[j % nd + 1], a)
		end
	end
	for _ = 1, 8 do                                         -- soften sharp crests
		local q = {}
		for i = 0, N - 1 do q[i] = (Pp[(i - 1) % N] + Pp[i] * 2 + Pp[(i + 1) % N]) / 4 end
		for i = 0, N - 1 do Pp[i] = q[i] end
	end
	local function idx(i) return i % N end
	local T = {}
	for i = 0, N - 1 do T[i] = (Pp[idx(i + 1)] - Pp[idx(i - 1)]).Unit end

	-- ---------- rotation-minimizing frames ----------
	local U = {}
	do
		local y = Vector3.new(0, 1, 0)
		U[0] = (y - T[0] * y:Dot(T[0])).Unit
		for i = 0, N - 1 do
			local j = idx(i + 1)
			local v1 = Pp[j] - Pp[i]
			local c1 = v1:Dot(v1)
			local rL = U[i] - v1 * (2 / c1 * v1:Dot(U[i]))
			local tL = T[i] - v1 * (2 / c1 * v1:Dot(T[i]))
			local v2 = T[j] - tL
			local c2 = v2:Dot(v2)
			local rn = rL
			if c2 > 1e-9 then rn = rL - v2 * (2 / c2 * v2:Dot(rL)) end
			if j ~= 0 then U[j] = rn else U[N] = rn end
		end
		-- close the twist
		local Un, U0, T0 = U[N], U[0], T[0]
		local phi = math.atan2(Un:Cross(U0):Dot(T0), Un:Dot(U0))
		for i = 0, N - 1 do
			local a = phi * i / N
			local u = U[i]
			local ca, sa = math.cos(a), math.sin(a)
			U[i] = (u * ca + T[i]:Cross(u) * sa + T[i] * (T[i]:Dot(u) * (1 - ca))).Unit
		end
	end

	-- ---------- speed profile ----------
	local Y0 = {}
	for i = 0, N - 1 do Y0[i] = Pp[i].Y end
	local iCrest, yc = 0, -1
	for i = 0, math.floor(N / 3) do if Y0[i] > yc then yc = Y0[i] iCrest = i end end
	local sCrest = iCrest * ds
	local VMAX, VCHAIN, G, K, VMIN = 92, 15, 45, 7, 17
	local vstar = {}
	for i = 0, N - 1 do
		local s = i * ds
		if i <= iCrest then
			vstar[i] = math.min(VCHAIN, math.sqrt(2 * 8 * s) + 2)
		else
			local e = VCHAIN * VCHAIN + 2 * G * (yc - Y0[i]) - K * (s - sCrest)
			vstar[i] = math.clamp(math.sqrt(math.max(e, 0)), VMIN, VMAX)
		end
	end
	for i = N - 1, 0, -1 do                                   -- braking into the station
		local dist = (N - i) * ds
		local lim = math.max(math.sqrt(2 * 14 * dist), 2.5)
		if i < N - 1 and dist < 130 then vstar[i] = math.min(vstar[i], lim) end
	end

	-- ---------- banking ----------
	local kl = {}
	for i = 0, N - 1 do
		local kappa = (T[idx(i + 1)] - T[idx(i - 1)]) / (2 * ds)
		kl[i] = kappa:Dot(T[i]:Cross(U[i]))
	end
	local R, Fr = {}, {}
	for i = 0, N - 1 do
		local sm, c = 0, 0
		for d = -6, 6 do sm = sm + kl[idx(i + d)] c = c + 1 end
		local k = sm / c
		local beta = math.clamp(math.atan(k * vstar[i] * vstar[i] / 55), -1.3, 1.3)
		local right = T[i]:Cross(U[i])
		local u = (U[i] * math.cos(beta) + right * math.sin(beta)).Unit
		U[i] = u
		R[i] = T[i]:Cross(u).Unit
	end

	local function frameAt(s)
		s = s % L
		local f = s / ds
		local i0 = math.floor(f)
		local a = f - i0
		local i1 = idx(i0 + 1)
		i0 = idx(i0)
		local p = Pp[i0]:Lerp(Pp[i1], a)
		local t = T[i0]:Lerp(T[i1], a).Unit
		local u = U[i0]:Lerp(U[i1], a)
		u = (u - t * u:Dot(t)).Unit
		return p + Center, t, u
	end

	-- ---------- build the rails ----------
	local bcount = 0
	local function yieldMaybe()
		bcount = bcount + 1
		if bcount % 160 == 0 then task.wait() end
	end
	local railFolder = Instance.new("Folder")
	railFolder.Name = "Rails"
	railFolder.Parent = CUR
	local supFolder = Instance.new("Folder")
	supFolder.Name = "Supports"
	supFolder.Parent = CUR
	for i = 0, N - 1 do
		local j = idx(i + 1)
		local aL, bL = Pp[i] - R[i] * 1.7 + Center, Pp[j] - R[j] * 1.7 + Center
		local aR, bR = Pp[i] + R[i] * 1.7 + Center, Pp[j] + R[j] * 1.7 + Center
		local aS, bS = Pp[i] - U[i] * 1.1 + Center, Pp[j] - U[j] * 1.1 + Center
		local rl = Beam("RailL", aL, bL, 0.55, CYAN, M.Neon, false, railFolder)
		rl.Size = Vector3.new(0.55, 0.55, (bL - aL).Magnitude + 0.25)
		local rr = Beam("RailR", aR, bR, 0.55, PINK, M.Neon, false, railFolder)
		rr.Size = Vector3.new(0.55, 0.55, (bR - aR).Magnitude + 0.25)
		local sp = Beam("Spine", aS, bS, 1.1, Color3.fromRGB(70, 75, 95), M.Metal, false, railFolder)
		sp.Size = Vector3.new(1.1, 1.1, (bS - aS).Magnitude + 0.25)
		if i % 2 == 0 then
			local mid = Pp[i] + Center
			P("Tie", Vector3.new(4.4, 0.35, 0.8), CFrame.fromMatrix(mid - U[i] * 0.4, R[i], U[i], -T[i]), STEEL, M.Metal, railFolder, false)
		end
		yieldMaybe()
	end
	-- supports
	local lift = 0
	for i = 0, N - 1, 5 do
		local p = Pp[i]
		local inLoop = (p.X > 372 and p.X < 392 and p.Z > -34 and p.Z < 36 and p.Y > 10)
		if p.Y > 9 and not inLoop then
			local h = p.Y - 1.8
			P("Support", Vector3.new(1.6, h, 1.6), CFrame.new(Center + Vector3.new(p.X, h / 2, p.Z)), Color3.fromRGB(150, 25, 45), M.Metal, supFolder, false)
			P("Foot", Vector3.new(4, 0.6, 4), CFrame.new(Center + Vector3.new(p.X, 0.4, p.Z)), IRON, M.Metal, supFolder, false)
			if h > 26 and i % 10 == 0 then
				local q = Pp[idx(i + 5)]
				if q.Y > 9 then
					Beam("Brace", Center + Vector3.new(p.X, h * 0.45, p.Z), Center + Vector3.new(q.X, h * 0.1, q.Z), 0.7, IRON, M.Metal, false, supFolder)
				end
			end
		end
		yieldMaybe()
	end
	-- loop towers
	for _, z in ipairs({ -36, 38 }) do
		for _, dx in ipairs({ -3, 3 }) do
			B("LoopTower", 2, 66, 2, 381 + dx, 33, z, Color3.fromRGB(150, 25, 45), M.Metal)
		end
		B("LoopTowerTop", 10, 2, 2, 381, 66, z, gold, M.Metal)
		local lb = Ball("LoopLamp", 4, 381, 69, z, RED, M.Neon)
		addLight(lb, RED, 70, 2.5)
	end
	-- lift chain rungs
	for i = 1, iCrest, 2 do
		local mid = Pp[i] + Center
		local rung = P("Chain", Vector3.new(2.4, 0.4, 0.5), CFrame.fromMatrix(mid + U[i] * -0.1, R[i], U[i], -T[i]), YELLOW, M.Neon, railFolder, false)
	end

	-- ---------- station ----------
	B("StationPlatform", 20, 1, 44, 346, 0.5, -312, Color3.fromRGB(70, 60, 100), M.Concrete)
	B("StationPlat2", 6, 1, 44, 320, 0.5, -312, Color3.fromRGB(70, 60, 100), M.Concrete)
	for _, sx in ipairs({ 312, 354 }) do
		for _, sz in ipairs({ -332, -292 }) do B("StationPost", 2, 24, 2, sx, 12, sz, RED, M.Metal) end
	end
	B("StationRoof", 46, 1.4, 50, 333, 24.5, -312, Color3.fromRGB(30, 20, 50), M.SmoothPlastic)
	rainbow(B("StationRoofNeon", 46.6, 0.7, 50.6, 333, 23.6, -312, PINK, M.Neon, 0, false), 0, 0.15)
	local board = B("StationSign", 40, 8, 1, 333, 30, -337, BLACK, M.SmoothPlastic, 0, false)
	for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
		local g = Instance.new("SurfaceGui")
		g.Face = face
		g.SizeStudsPerPixel = 0.07
		g.Parent = board
		local t = Instance.new("TextLabel")
		t.Size = UDim2.fromScale(1, 1)
		t.BackgroundTransparency = 1
		t.Text = "DRAGON FURY"
		t.TextColor3 = Color3.fromRGB(255, 70, 60)
		t.Font = Enum.Font.GothamBlack
		t.TextScaled = true
		t.Parent = g
		local st = Instance.new("UIStroke")
		st.Color = YELLOW
		st.Thickness = 4
		st.Parent = t
	end
	B("StationSignPost", 2, 24, 2, 316, 12, -337, IRON, M.Metal)
	B("StationSignPost", 2, 24, 2, 350, 12, -337, IRON, M.Metal)
	local warn = B("WarnSign", 18, 5, 0.6, 346, 4, -332, Color3.fromRGB(255, 220, 30), M.SmoothPlastic, 0, false)
	local wg = Instance.new("SurfaceGui")
	wg.Face = Enum.NormalId.Back
	wg.SizeStudsPerPixel = 0.05
	wg.Parent = warn
	local wt = Instance.new("TextLabel")
	wt.Size = UDim2.fromScale(1, 1)
	wt.BackgroundTransparency = 1
	wt.Text = "DANGER! HOLD ON. NO EXIT UNTIL THE STATION."
	wt.TextColor3 = BLACK
	wt.Font = Enum.Font.GothamBlack
	wt.TextScaled = true
	wt.Parent = wg

	-- dragon head on top of the lift
	do
		local base = Pp[iCrest] + Center
		local hd = newModel("Dragon")
		local function dp(n, size, rel, color, mat, blob)
			local cf = CFrame.new(base + Vector3.new(0, 10, 18)) * rel
			if blob then return Blob(n, size, cf, color, mat, hd) end
			return P(n, size, cf, color, mat, hd, false)
		end
		dp("Skull", Vector3.new(16, 11, 22), CN(0, 0, 0), Color3.fromRGB(190, 30, 40), M.SmoothPlastic, true)
		dp("Jaw", Vector3.new(14, 4, 18), CN(0, -6, -2), Color3.fromRGB(150, 20, 30), M.SmoothPlastic, true)
		dp("Snout", Vector3.new(10, 7, 10), CN(0, -1, -13), Color3.fromRGB(200, 40, 40), M.SmoothPlastic, true)
		for _, sx in ipairs({ -5, 5 }) do
			local ey = dp("Eye", Vector3.new(3, 3, 3), CN(sx, 3, -9), YELLOW, M.Neon, true)
			addLight(ey, YELLOW, 40, 3)
			dp("Horn", Vector3.new(2, 11, 2), CN(sx * 1.2, 8, 6) * CFrame.Angles(math.rad(-25), 0, math.rad(sx > 0 and -12 or 12)), gold, M.Metal, false)
			dp("Fang", Vector3.new(1.2, 4, 1.2), CN(sx * 0.7, -4.5, -15), WHITE, M.SmoothPlastic, false)
		end
		local mouth = dp("Mouth", Vector3.new(2, 2, 2), CN(0, -3, -17), ORANGE, M.Neon, true)
		local fire = Instance.new("ParticleEmitter")
		fire.Rate = 40
		fire.Lifetime = NumberRange.new(0.8, 1.4)
		fire.Speed = NumberRange.new(26, 38)
		fire.SpreadAngle = Vector2.new(10, 10)
		fire.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2), NumberSequenceKeypoint.new(1, 7) })
		fire.Transparency = NumberSequence.new(0.1, 1)
		fire.Color = ColorSequence.new(Color3.fromRGB(255, 230, 80), Color3.fromRGB(255, 60, 20))
		fire.LightEmission = 1
		fire.EmissionDirection = Enum.NormalId.Front
		fire.Parent = mouth
		addLight(mouth, ORANGE, 90, 4)
	end

	-- ---------- train ----------
	local CARS = 3
	local cars = {}
	for c = 1, CARS do
		local m = newModel("CoasterCar" .. c)
		local seat = P("Seat", Vector3.new(5.4, 1, 6.2), CFrame.new(Center), c == 1 and RED or Color3.fromRGB(200, 30, 60), M.SmoothPlastic, m, false)
		m.PrimaryPart = seat
		RBlob(m, "Shell", Vector3.new(6.4, 2.6, 7.4), CN(0, -0.6, 0), c == 1 and RED or Color3.fromRGB(200, 30, 60), M.SmoothPlastic)
		RP(m, "Back", Vector3.new(5.2, 2.8, 0.7), CN(0, 2, 2.8), BLACK, M.SmoothPlastic)
		RP(m, "Bar", Vector3.new(5, 0.6, 0.6), CN(0, 1.5, -1.3), STEEL, M.Metal)
		RP(m, "WheelF", Vector3.new(6, 1.2, 1.4), CN(0, -2, -2.3), IRON, M.Metal)
		RP(m, "WheelB", Vector3.new(6, 1.2, 1.4), CN(0, -2, 2.3), IRON, M.Metal)
		rainbow(RP(m, "Trim", Vector3.new(6.7, 0.4, 7.7), CN(0, 0.2, 0), YELLOW, M.Neon), c / 3, 0.3)
		if c == 1 then
			local hl = RBall(m, "Headlight", 1.6, CN(0, 0.4, -3.8), WHITE, M.Neon)
			addLight(hl, WHITE, 50, 2.5)
			RBlob(m, "Nose", Vector3.new(4, 2, 3), CN(0, -0.4, -4.2), RED, M.SmoothPlastic)
		end
		local pr = rideSeat(ride, seat, CN(0, 2.3, 0.2), "Coaster seat", 9999)
		cars[c] = { m = m, prompt = pr }
	end

	-- ---------- simulation ----------
	local st = { phase = "dwell", t = 0, s = 0, v = 0, lap = 0 }
	COASTER.state = st
	local DWELL_IDLE, DWELL_RIDER = 12, 5
	ride.noLeave = function() return st.phase ~= "dwell" end
	ride.onBoard = function() ride._lap0 = st.lap st.t = math.max(st.t, 0) end
	ride.done = function()
		return st.phase == "dwell" and ride._lap0 ~= nil and st.lap > ride._lap0 and st.t > 3
	end
	ride.onLeave = function() ride._lap0 = nil end
	local function placeTrain()
		for c = 1, CARS do
			local p, t, u = frameAt(st.s - (c - 1) * 9.5)
			local r = t:Cross(u)
			local pos = p + u * 2.6
			cars[c].m:PivotTo(CFrame.fromMatrix(pos, r, u, -t))
		end
	end
	placeTrain()
	ride.exitCF = at(346, 1, -312)
	ride.update = function(dt)
		local riding = RS.cur and RS.cur.ride == ride
		if st.phase == "dwell" then
			st.t = st.t + dt
			for _, c in ipairs(cars) do c.prompt.Enabled = st.t > 0.6 and not riding end
			local need = riding and DWELL_RIDER or DWELL_IDLE
			if st.t >= need then
				st.phase = "run"
				st.t = 0
				for _, c in ipairs(cars) do c.prompt.Enabled = false end
				if riding then toast("HOLD ON TIGHT!", false) end
			end
		else
			local i = math.floor(st.s / ds) % N
			local vt = vstar[i]
			if st.v < vt then st.v = math.min(vt, st.v + 80 * dt) else st.v = math.max(vt, st.v - 90 * dt) end
			st.s = st.s + st.v * dt
			if st.s >= L - 0.25 then
				st.s = 0
				st.v = 0
				st.phase = "dwell"
				st.t = 0
				st.lap = st.lap + 1
			end
		end
		placeTrain()
		if riding then
			local f = st.v / VMAX
			local cam = getCam()
			if cam then cam.FieldOfView = 66 + 42 * f end
			local h = getHum()
			if h then
				local amp = 0.5 * f * f
				h.CameraOffset = Vector3.new((math.random() - 0.5) * amp, (math.random() - 0.5) * amp, 0)
			end
		end
	end
end

--==================================================
-- EL CLOWN (dances on the plaza stage)
--==================================================
section("EL CLOWN")
local CLOWN = {}
do
	local sx, sz = 0, 62
	VC("StageBase", 17, 3, sx, 1.5, sz, Color3.fromRGB(60, 30, 90), M.Concrete)
	rainbow(VC("StageRing", 17.6, 0.8, sx, 3.1, sz, PINK, M.Neon, false), 0, 0.2)
	local top = V(sx, 3, sz)
	for k = 0, 5 do
		local a = k / 6 * math.pi * 2
		local lx, lz = sx + math.cos(a) * 20, sz + math.sin(a) * 20
		B("StageLamp", 1, 12, 1, lx, 6, lz, IRON, M.Metal)
		local b = Ball("StageBulb", 3, lx, 12.6, lz, Color3.fromHSV(k / 6, 0.8, 1), M.Neon)
		addLight(b, Color3.fromHSV(k / 6, 0.8, 1), 36, 2)
	end
	local spot = B("StageSpot", 2, 2, 2, sx, 60, sz, WHITE, M.Neon, 0, false)
	addLight(spot, Color3.fromRGB(255, 240, 255), 80, 3.5)

	-- rig: each part has a group; groups rotate about a pivot (clown-local coords, origin = stage top centre)
	local parts = {}
	local groups = {
		body = { pv = Vector3.new(0, 0, 0) }, torso = { pv = Vector3.new(0, 8, 0) }, head = { pv = Vector3.new(0, 19, 0) },
		armR = { pv = Vector3.new(5.6, 17, 0) }, armL = { pv = Vector3.new(-5.6, 17, 0) },
		legR = { pv = Vector3.new(2.2, 8, 0) }, legL = { pv = Vector3.new(-2.2, 8, 0) },
	}
	local model = newModel("ClownRig")
	local function cp(group, name, size, lx, ly, lz, color, mat, kind, rotCF)
		local rel = CFrame.new(lx, ly, lz) * (rotCF or CFrame.new())
		local cf = CFrame.new(top) * rel
		local p
		if kind == "ball" then
			p = P(name, size, cf, color, mat, model, false)
			p.Shape = Enum.PartType.Ball
		elseif kind == "blob" then
			p = Blob(name, size, cf, color, mat, model)
		else
			p = P(name, size, cf, color, mat, model, false)
		end
		parts[#parts + 1] = { p = p, g = group, rel = rel }
		return p
	end
	local SUIT1, SUIT2 = Color3.fromRGB(235, 40, 60), Color3.fromRGB(40, 90, 255)
	local YEL = Color3.fromRGB(255, 220, 50)
	-- legs
	for _, side in ipairs({ { "legR", 2.2, SUIT1 }, { "legL", -2.2, SUIT2 } }) do
		cp(side[1], "Leg", Vector3.new(3, 8, 3), side[2], 4.2, 0, side[3], M.SmoothPlastic, "blob")
		cp(side[1], "Stripe", Vector3.new(3.2, 1.4, 3.2), side[2], 5.5, 0, YEL, M.SmoothPlastic, "blob")
		cp(side[1], "Shoe", Vector3.new(4, 2.4, 8), side[2], 0.9, -1.4, ORANGE, M.SmoothPlastic, "blob")
		cp(side[1], "ShoeTip", Vector3.new(2.4, 2.4, 2.4), side[2], 1.2, -5, PINK, M.Neon, "ball")
	end
	-- torso
	cp("torso", "Torso", Vector3.new(9.5, 11, 7.5), 0, 13.5, 0, SUIT1, M.SmoothPlastic, "blob")
	cp("torso", "Belly", Vector3.new(7, 7, 3), 0, 12.8, -2.8, YEL, M.SmoothPlastic, "blob")
	for i, d in ipairs({ { -2.6, 16 }, { 2.6, 15 }, { 0, 10 }, { -3, 11 }, { 3, 11.5 } }) do
		cp("torso", "Dot", Vector3.new(1.6, 1.6, 1.6), d[1], d[2], -3.3, (i % 2 == 0) and CYAN or LIME, M.Neon, "ball")
	end
	for i, y in ipairs({ 17.8, 14.8, 11.8 }) do
		cp("torso", "Button", Vector3.new(1, 1, 1), 0, y, -3.9, WHITE, M.Neon, "ball")
	end
	cp("torso", "Ruff", Vector3.new(7.6, 2, 7.6), 0, 18.6, 0, PINK, M.Neon, "blob")
	-- head
	cp("head", "Head", Vector3.new(7, 7.4, 7), 0, 23, 0, Color3.fromRGB(255, 245, 240), M.SmoothPlastic, "blob")
	local nose = cp("head", "Nose", Vector3.new(2.6, 2.6, 2.6), 0, 22.6, -3.6, RED, M.Neon, "ball")
	addLight(nose, RED, 18, 1.4)
	for _, ex in ipairs({ -1.7, 1.7 }) do
		cp("head", "EyeW", Vector3.new(1.8, 2.2, 0.8), ex, 24.2, -3.2, WHITE, M.SmoothPlastic, "blob")
		cp("head", "Pupil", Vector3.new(0.8, 0.8, 0.6), ex, 24.2, -3.7, BLACK, M.SmoothPlastic, "ball")
		cp("head", "Cheek", Vector3.new(1.6, 1.6, 0.6), ex * 1.7, 22, -3.1, PINK, M.Neon, "ball")
	end
	cp("head", "Mouth", Vector3.new(4, 1.6, 0.6), 0, 20.8, -3.3, RED, M.Neon, "blob")
	for k = 0, 7 do
		local a = k / 8 * math.pi * 2
		local b = cp("head", "Hair", Vector3.new(3, 3, 3), math.cos(a) * 4.6, 24 + math.sin(a) * 0.6, math.sin(a) * 4.6 * 0.9 + 0.5, Color3.fromHSV(k / 8, 0.8, 1), M.Neon, "ball")
	end
	cp("head", "Hat", Vector3.new(5.4, 7.5, 5.4), 0, 29.4, 0.3, PURPLE, M.SmoothPlastic, "blob")
	cp("head", "HatBrim", Vector3.new(8.4, 0.8, 8.4), 0, 26.7, 0.3, YEL, M.SmoothPlastic, "blob")
	cp("head", "HatPom", Vector3.new(1.8, 1.8, 1.8), 0, 33.4, 0.3, LIME, M.Neon, "ball")
	-- arms
	for _, side in ipairs({ { "armR", 5.6, 1 }, { "armL", -5.6, -1 } }) do
		cp(side[1], "Arm", Vector3.new(2.6, 8, 2.6), side[2] + side[3] * 0.6, 13, 0, side[3] == 1 and SUIT2 or SUIT1, M.SmoothPlastic, "blob")
		cp(side[1], "Cuff", Vector3.new(3.2, 1.2, 3.2), side[2] + side[3] * 0.6, 9.4, 0, YEL, M.SmoothPlastic, "blob")
		cp(side[1], "Hand", Vector3.new(3.2, 3.2, 3.2), side[2] + side[3] * 0.6, 8.2, 0, WHITE, M.SmoothPlastic, "ball")
	end
	-- balloons in the right hand
	for i = 1, 4 do
		local bx = 6.2 + math.cos(i * 1.6) * 2
		local bz = math.sin(i * 1.6) * 2
		cp("armR", "String", Vector3.new(0.15, 0.15, 11 + i * 1.5), bx, 8.2 + 7, bz, WHITE, M.SmoothPlastic, "block", CFrame.Angles(math.rad(90), 0, 0))
		cp("armR", "Balloon", Vector3.new(5, 6, 5), bx, 8.2 + 13 + i * 2, bz, Color3.fromHSV(i / 4, 0.85, 1), M.Neon, "blob")
	end

	-- name tag and speech bubble
	local tagPart = P("TagAnchor", Vector3.new(1, 1, 1), CFrame.new(top + Vector3.new(0, 43, 0)), WHITE, M.SmoothPlastic, model, false)
	tagPart.Transparency = 1
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(220, 70)
	bb.StudsOffset = Vector3.new(0, 0, 0)
	bb.AlwaysOnTop = false
	bb.MaxDistance = 600
	bb.Adornee = tagPart
	bb.Parent = tagPart
	local nameL = Instance.new("TextLabel")
	nameL.Size = UDim2.new(1, 0, 0.5, 0)
	nameL.BackgroundTransparency = 1
	nameL.Text = "EL CLOWN"
	nameL.TextColor3 = Color3.fromRGB(255, 80, 200)
	nameL.Font = Enum.Font.GothamBlack
	nameL.TextScaled = true
	nameL.Parent = bb
	local ns = Instance.new("UIStroke")
	ns.Thickness = 2.5
	ns.Color = BLACK
	ns.Parent = nameL
	local say = Instance.new("TextLabel")
	say.Size = UDim2.new(1, 0, 0.45, 0)
	say.Position = UDim2.new(0, 0, 0.55, 0)
	say.BackgroundColor3 = WHITE
	say.BackgroundTransparency = 0.05
	say.TextColor3 = BLACK
	say.Font = Enum.Font.GothamBold
	say.TextScaled = true
	say.Text = "HA HA HA!"
	say.Parent = bb
	corner(say, 10)
	local lines = { "HA HA HA!", "WELCOME TO MAXU PARK!", "DANCE WITH ME!", "RIDE THE DRAGON... IF YOU DARE!", "HONK HONK!", "15 RIDES! TRY THEM ALL!" }
	local lineI = 1
	task.spawn(function()
		while not Closed do
			task.wait(4.5)
			lineI = lineI % #lines + 1
			say.Text = lines[lineI]
		end
	end)

	-- confetti
	local conf = Instance.new("ParticleEmitter")
	conf.Rate = 22
	conf.Lifetime = NumberRange.new(3, 5)
	conf.Speed = NumberRange.new(10, 22)
	conf.SpreadAngle = Vector2.new(60, 60)
	conf.Acceleration = Vector3.new(0, -9, 0)
	conf.Size = NumberSequence.new(0.6)
	conf.RotSpeed = NumberRange.new(-200, 200)
	conf.LightEmission = 0.7
	conf.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, PINK), ColorSequenceKeypoint.new(0.33, CYAN),
		ColorSequenceKeypoint.new(0.66, YELLOW), ColorSequenceKeypoint.new(1, LIME) })
	conf.Parent = tagPart

	-- dance with the clown (own character emote; needs the animation to be playable in this game)
	local danceTrack
	local function stopDance()
		if danceTrack then pcall(function() danceTrack:Stop() end) danceTrack = nil end
	end
	local stagePad = VC("StagePrompt", 3, 0.4, sx, 3.4, sz + 12, YELLOW, M.Neon, false)
	prompt(stagePad, "Dance with EL CLOWN", "EL CLOWN", function()
		local h = getHum()
		if not h then return end
		stopDance()
		local ids = (h.RigType == Enum.HumanoidRigType.R15) and { 507771019, 507776043, 507777268 } or { 182435998, 182491037, 182491065 }
		local an = Instance.new("Animation")
		an.AnimationId = "rbxassetid://" .. ids[math.random(1, #ids)]
		local ok = pcall(function()
			local animator = h:FindFirstChildOfClass("Animator") or h
			danceTrack = animator:LoadAnimation(an)
			danceTrack.Priority = Enum.AnimationPriority.Action
			danceTrack.Looped = true
			danceTrack:Play()
		end)
		toast(ok and "Dance with EL CLOWN! (walk to stop)" or "Dance animation could not load here.", ok)
	end, 0.3, 16)
	bind(RunService.Heartbeat, function()
		if danceTrack then
			local h = getHum()
			if h and h.MoveDirection.Magnitude > 0.1 then stopDance() end
		end
	end)
	CLOWN.stop = stopDance
	CLOWN.cf = CFrame.new(top + Vector3.new(0, 1, 22)) * CFrame.Angles(0, math.pi, 0)

	local function rx(a) return CFrame.Angles(a, 0, 0) end
	local function rz(a) return CFrame.Angles(0, 0, a) end
	local clownT = 0
	bind(RunService.Heartbeat, function(dt)
		if Closed then return end
		clownT = clownT + dt
		local t = clownT
		local beat = t * 3.4
		local spinT = t % 8
		local yaw = 0
		if spinT < 1.3 then yaw = yaw + math.pi * 2 * smooth(spinT / 1.3) end
		local hop = math.abs(math.sin(beat)) * 1.6
		local G = {}
		local B0 = CFrame.new(0, hop, 0) * CFrame.new(math.sin(beat * 0.5) * 1.2, 0, 0)
		local rootLocal = CFrame.Angles(0, yaw, 0) * B0
		local function lgrp(name, parentCF, rot)
			local pv = groups[name].pv
			G[name] = parentCF * CFrame.new(pv) * rot * CFrame.new(-pv)
		end
		G.body = rootLocal
		lgrp("torso", rootLocal, rz(math.sin(beat * 0.5) * 0.18) * rx(math.sin(beat) * 0.06))
		lgrp("head", G.torso, rz(math.sin(beat * 0.5 + 1) * 0.28) * rx(math.sin(beat) * 0.08))
		lgrp("armR", G.torso, rz(1.35 + 0.8 * math.sin(beat)))
		lgrp("armL", G.torso, rz(-(1.35 + 0.8 * math.sin(beat + math.pi))))
		lgrp("legR", rootLocal, rx(math.sin(beat) * 0.55))
		lgrp("legL", rootLocal, rx(-math.sin(beat) * 0.55))
		for _, e in ipairs(parts) do
			e.p.CFrame = CFrame.new(top) * G[e.g] * e.rel
		end
	end)
end

--==================================================
-- EXIT / CLEANUP
--==================================================
local exitDone = false
local SkipShow = false
local function exitPark(silent)
	if exitDone then return end
	exitDone = true
	Closed = true
	pcall(function() if CLOWN.stop then CLOWN.stop() end end)
	pcall(function() leave(true) end)
	for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
	local r = getRoot()
	local h = getHum()
	if h then pcall(function() h.CameraOffset = Vector3.zero h.Sit = false end) end
	if r then pcall(function() r.Anchored = false end) end
	local cam = getCam()
	if cam then pcall(function() cam.CameraType = Enum.CameraType.Custom cam.FieldOfView = origFov or 70 end) end
	if not silent and r then
		pcall(function() getChar():PivotTo(OldCF) end)
	end
	pcall(function() for k, v in pairs(lightingBackup) do Lighting[k] = v end end)
	for _, o in ipairs(lightingMade) do pcall(function() o:Destroy() end) end
	for _, o in ipairs(oldAtmos) do pcall(function() o.Parent = Lighting end) end
	pcall(function() Sound:Destroy() end)
	pcall(function() HQ:Destroy() end)
	pcall(function() SG:Destroy() end)
	_G.MAXU_PARK_EXIT = nil
end
_G.MAXU_PARK_EXIT = exitPark
bind(Player.CharacterRemoving, function() if RS.cur then RS.cur = nil leaveBtn.Visible = false end end)
bind(Player.CharacterAdded, function(c)
	if Closed or exitDone then return end
	task.wait(0.6)
	local r = c:FindFirstChild("HumanoidRootPart")
	if r and not RS.cur then pcall(function() c:PivotTo(SPAWN_CF) end) end
end)

--==================================================
-- MENUS: RIDES teleport list, PHOTO MODE, BACK button
--==================================================
local function mkButton(parent, text, color, pos, size, anchor)
	local b = Instance.new("TextButton")
	b.AnchorPoint = anchor or Vector2.new(0, 0)
	b.Position = pos
	b.Size = size
	b.BackgroundColor3 = color
	b.TextColor3 = WHITE
	b.Text = text
	b.Font = Enum.Font.GothamBold
	b.TextSize = 13
	b.AutoButtonColor = true
	b.ZIndex = 70
	b.Parent = parent
	corner(b, 9)
	stroke(b, Color3.fromRGB(255, 255, 255), 1).Transparency = 0.7
	return b
end

local bar = Instance.new("Frame")
bar.AnchorPoint = Vector2.new(1, 0)
bar.Position = UDim2.new(1, -12, 0, 12)
bar.Size = UDim2.fromOffset(176, 120)
bar.BackgroundTransparency = 1
bar.Visible = false
bar.ZIndex = 70
bar.Parent = SG
local barLayout = Instance.new("UIListLayout")
barLayout.Padding = UDim.new(0, 6)
barLayout.Parent = bar
local ridesBtn = mkButton(bar, "RIDES MENU", Color3.fromRGB(110, 40, 190), UDim2.new(), UDim2.new(1, 0, 0, 34))
local photoBtn = mkButton(bar, "PHOTO MODE", Color3.fromRGB(30, 110, 170), UDim2.new(), UDim2.new(1, 0, 0, 34))
local backBtn = mkButton(bar, "SKIP - BACK TO OLD PLACE", Color3.fromRGB(170, 30, 60), UDim2.new(), UDim2.new(1, 0, 0, 34))
backBtn.TextSize = 11
bind(backBtn.Activated, function() exitPark(false) end)

local modal = Instance.new("Frame")
modal.AnchorPoint = Vector2.new(0.5, 0.5)
modal.Position = UDim2.fromScale(0.5, 0.5)
modal.Size = UDim2.fromOffset(340, 420)
modal.BackgroundColor3 = Color3.fromRGB(16, 10, 28)
modal.Visible = false
modal.ZIndex = 90
modal.Parent = SG
corner(modal, 14)
stroke(modal, PINK, 2)
local mt = Instance.new("TextLabel")
mt.Size = UDim2.new(1, -20, 0, 34)
mt.Position = UDim2.fromOffset(10, 6)
mt.BackgroundTransparency = 1
mt.Text = "RIDES - tap to go there"
mt.TextColor3 = WHITE
mt.Font = Enum.Font.GothamBlack
mt.TextSize = 16
mt.ZIndex = 91
mt.Parent = modal
local scroll = Instance.new("ScrollingFrame")
scroll.Position = UDim2.fromOffset(10, 46)
scroll.Size = UDim2.new(1, -20, 1, -100)
scroll.BackgroundTransparency = 1
scroll.BorderSizePixel = 0
scroll.ScrollBarThickness = 5
scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
scroll.CanvasSize = UDim2.new()
scroll.ZIndex = 91
scroll.Parent = modal
local sl = Instance.new("UIListLayout")
sl.Padding = UDim.new(0, 5)
sl.Parent = scroll
local closeM = mkButton(modal, "CLOSE", Color3.fromRGB(70, 70, 90), UDim2.new(0.5, 0, 1, -10), UDim2.fromOffset(120, 32), Vector2.new(0.5, 1))
closeM.ZIndex = 92
bind(closeM.Activated, function() modal.Visible = false end)
bind(ridesBtn.Activated, function() modal.Visible = not modal.Visible end)

local function goTo(cf)
	if RS.cur then leave(true) end
	pcall(function() getChar():PivotTo(cf + Vector3.new(0, 3, 0)) end)
	local r = getRoot()
	if r then r.AssemblyLinearVelocity = Vector3.zero end
	modal.Visible = false
end
local menuCF = { ["Zip Line"] = at(-380, 1, -360), ["Sky Tram"] = at(-385, 1, -308) }
local function addEntry(label, getCF)
	local b = mkButton(scroll, label, Color3.fromRGB(38, 26, 66), UDim2.new(), UDim2.new(1, -8, 0, 30))
	b.ZIndex = 92
	bind(b.Activated, function() goTo(getCF()) end)
end
for i, r in ipairs(RIDES) do
	addEntry(i .. ".  " .. r.name, function() return menuCF[r.name] or r.exitCF end)
end
addEntry("EL CLOWN stage", function() return CLOWN.cf or SPAWN_CF end)
addEntry("Main gate", function() return SPAWN_CF end)

local photo = false
local photoBack = mkButton(SG, "EXIT PHOTO MODE", Color3.fromRGB(30, 30, 40), UDim2.new(0.5, 0, 1, -16), UDim2.fromOffset(170, 30), Vector2.new(0.5, 1))
photoBack.Visible = false
bind(photoBtn.Activated, function()
	photo = true
	bar.Visible = false
	counter.Visible = false
	toastHolder.Visible = false
	modal.Visible = false
	photoBack.Visible = true
end)
bind(photoBack.Activated, function()
	photo = false
	bar.Visible = true
	counter.Visible = true
	toastHolder.Visible = true
	photoBack.Visible = false
end)

--==================================================
-- BOOT PANEL (pixel logo + status lines)
--==================================================
local GLY = {
	M = { "10001", "11011", "10101", "10001", "10001" }, A = { "01110", "10001", "11111", "10001", "10001" },
	X = { "10001", "01010", "00100", "01010", "10001" }, U = { "10001", "10001", "10001", "10001", "01110" },
	P = { "11110", "10001", "11110", "10000", "10000" }, R = { "11110", "10001", "11110", "10010", "10001" },
	K = { "10010", "10100", "11000", "10100", "10010" },
}
local panel = Instance.new("Frame")
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.Size = UDim2.fromOffset(500, 330)
panel.BackgroundColor3 = Color3.fromRGB(10, 6, 20)
panel.BackgroundTransparency = 0.05
panel.ZIndex = 120
panel.Parent = SG
corner(panel, 14)
stroke(panel, PINK, 2)
local pscale = Instance.new("UIScale")
pscale.Scale = scaleFor()
pscale.Parent = panel
do
	local word = "MAXUPARK"
	local cell, gap = 6, 1
	local x = 0
	local logo = Instance.new("Frame")
	logo.BackgroundTransparency = 1
	logo.Size = UDim2.fromOffset(#word * 6 * (cell + gap), 5 * (cell + gap))
	logo.AnchorPoint = Vector2.new(0.5, 0)
	logo.Position = UDim2.new(0.5, 0, 0, 16)
	logo.ZIndex = 121
	logo.Parent = panel
	for wi = 1, #word do
		local g = GLY[word:sub(wi, wi)]
		for ry = 1, 5 do
			for rx2 = 1, 5 do
				if g[ry]:sub(rx2, rx2) == "1" then
					local f = Instance.new("Frame")
					f.Size = UDim2.fromOffset(cell, cell)
					f.Position = UDim2.fromOffset(((wi - 1) * 6 + rx2 - 1) * (cell + gap), (ry - 1) * (cell + gap))
					f.BackgroundColor3 = Color3.fromHSV(((wi - 1) * 6 + rx2) / 50 % 1, 0.7, 1)
					f.BorderSizePixel = 0
					f.ZIndex = 122
					f.Parent = logo
				end
			end
		end
	end
end
local lines = Instance.new("Frame")
lines.Position = UDim2.fromOffset(24, 70)
lines.Size = UDim2.new(1, -48, 0, 190)
lines.BackgroundTransparency = 1
lines.ZIndex = 121
lines.Parent = panel
local ll = Instance.new("UIListLayout")
ll.Padding = UDim.new(0, 3)
ll.Parent = lines
local pbar = Instance.new("Frame")
pbar.AnchorPoint = Vector2.new(0.5, 1)
pbar.Position = UDim2.new(0.5, 0, 1, -22)
pbar.Size = UDim2.new(1, -48, 0, 10)
pbar.BackgroundColor3 = Color3.fromRGB(40, 30, 60)
pbar.ZIndex = 121
pbar.Parent = panel
corner(pbar, 5)
local pfill = Instance.new("Frame")
pfill.Size = UDim2.fromScale(0, 1)
pfill.BackgroundColor3 = PINK
pfill.ZIndex = 122
pfill.Parent = pbar
corner(pfill, 5)
local pstatus = Instance.new("TextLabel")
pstatus.AnchorPoint = Vector2.new(0.5, 1)
pstatus.Position = UDim2.new(0.5, 0, 1, -36)
pstatus.Size = UDim2.new(1, -48, 0, 18)
pstatus.BackgroundTransparency = 1
pstatus.Text = "LOADING..."
pstatus.TextColor3 = CYAN
pstatus.Font = Enum.Font.Code
pstatus.TextSize = 13
pstatus.ZIndex = 121
pstatus.Parent = panel

task.spawn(function()
	local tasks = {
		"Building island above the clouds", "Raising 15 rides", "Laying roller coaster track  (Dragon Fury)",
		"Waking up EL CLOWN", "Stringing neon lights", "Loading fireworks", "Tuning night sky and bloom",
	}
	for i, tx in ipairs(tasks) do
		local l = Instance.new("TextLabel")
		l.Size = UDim2.new(1, 0, 0, 18)
		l.BackgroundTransparency = 1
		l.TextXAlignment = Enum.TextXAlignment.Left
		l.Font = Enum.Font.Code
		l.TextSize = 13
		l.TextColor3 = Color3.fromRGB(200, 190, 230)
		l.Text = ""
		l.ZIndex = 121
		l.Parent = lines
		local full = "> " .. tx
		for k = 1, #full, 2 do
			if Closed then return end
			l.Text = full:sub(1, k)
			task.wait(0.012)
		end
		l.Text = full .. "   [ OK ]"
		l.TextColor3 = LIME
		tween(pfill, 0.3, { Size = UDim2.fromScale(i / #tasks, 1) })
		task.wait(0.35)
	end
	pstatus.Text = "ACCESS GRANTED"
	pstatus.TextColor3 = LIME
	task.wait(1.2)
	if Closed then return end
	tween(panel, 0.6, { BackgroundTransparency = 1 })
	for _, d in ipairs(panel:GetDescendants()) do
		if d:IsA("Frame") then tween(d, 0.6, { BackgroundTransparency = 1 })
		elseif d:IsA("TextLabel") then tween(d, 0.6, { TextTransparency = 1 })
		elseif d:IsA("UIStroke") then tween(d, 0.6, { Transparency = 1 }) end
	end
	task.wait(0.7)
	panel:Destroy()
end)

--==================================================
-- CINEMATIC, TELEPORT IN
--==================================================
local skipIntro = false
local skipBtn = mkButton(SG, "SKIP INTRO", Color3.fromRGB(40, 40, 60), UDim2.new(0.5, 0, 1, -20), UDim2.fromOffset(130, 32), Vector2.new(0.5, 1))
skipBtn.ZIndex = 130
bind(skipBtn.Activated, function() skipIntro = true end)

local function arrive()
	local r = getRoot()
	local cam = getCam()
	if r then
		r.Anchored = false
		pcall(function() getChar():PivotTo(SPAWN_CF) end)
		r.AssemblyLinearVelocity = Vector3.zero
	end
	if cam then
		cam.CameraType = Enum.CameraType.Custom
		cam.FieldOfView = 70
		local h = getHum()
		if h then cam.CameraSubject = h end
	end
	skipBtn:Destroy()
	bar.Visible = true
	counter.Visible = true
	updateCounter()
	tween(Black, 0.9, { BackgroundTransparency = 1 })
	toast("Welcome to MAXU AMUSEMENT PARK. Find the seats: press the prompt to ride.", true)
	task.delay(4, function() toast("Dragon Fury coaster is on the east side. EL CLOWN dances at the plaza.", true) end)
	task.delay(1, function() Black.Visible = false end)
end

task.spawn(function()
	local r = getRoot()
	if r then r.Anchored = true end
	task.wait(2)
	if Closed then return end
	tween(Intro, 0.8, { TextTransparency = 1 })
	tween(Black, 0.9, { BackgroundTransparency = 1 })
	local cam = getCam()
	if cam then cam.CameraType = Enum.CameraType.Scriptable end
	local t = 0
	local focus = V(0, 70, 0)
	local lastPos = V(560, 340, 0)
	while t < 9 and not skipIntro and not Closed do
		local dt = RunService.RenderStepped:Wait()
		t = t + dt
		local a = 0.4 + t * 0.32
		local rad = 640 - t * 14
		local pos = V(math.cos(a) * rad, 300 - t * 8, math.sin(a) * rad)
		lastPos = pos
		cam = getCam()
		if cam then cam.CFrame = CFrame.lookAt(pos, focus) end
	end
	if not Closed and not skipIntro then
		local goalPos = V(0, 50, -540)
		local goalLook = V(0, 46, -440)
		local t2 = 0
		while t2 < 3 and not skipIntro and not Closed do
			local dt = RunService.RenderStepped:Wait()
			t2 = t2 + dt
			local k = smooth(t2 / 3)
			cam = getCam()
			if cam then cam.CFrame = CFrame.lookAt(lastPos:Lerp(goalPos, k), focus:Lerp(goalLook, k)) end
		end
	end
	if Closed then return end
	Black.Visible = true
	Black.BackgroundTransparency = 1
	tween(Black, 0.6, { BackgroundTransparency = 0 })
	task.wait(0.7)
	if Closed then return end
	arrive()
end)

-- fireworks show every ~70 seconds
task.spawn(function()
	task.wait(25)
	while not Closed do
		fireworks(5, V(0, 10, -60))
		for _ = 1, 70 do
			if Closed then return end
			task.wait(1)
		end
	end
end)

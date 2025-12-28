-- DarkEye Internal

local DarkEye = getgenv().DarkEye
if not DarkEye then return end

-- Services

local Players = game:GetService("Players")
local RStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local TextChatService = game:GetService("TextChatService")
local Teams = game:GetService("Teams")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TeleportService = game:GetService("TeleportService")

-- Variables & Functions

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer.PlayerGui
local Camera = workspace.CurrentCamera

local BrickFolder = workspace.Bricks

local function GetFolder()
	for _, F in TextChatService:GetChildren() do
		if F:IsA("Folder") and F.Name == "TextChannels" and #F:GetChildren() >= 1 then
			return F
		end
	end
end

local Folder = GetFolder()

local function GetBricks()
	local Bricks = {}
	for _, Model in BrickFolder:GetChildren() do
		for _, Brick in Model:GetChildren() do
			table.insert(Bricks, Brick)
		end
	end
	return Bricks
end

local AdminTeam = Teams.Chosen
local function GetAdmin()
	for _, Player in Players:GetPlayers() do
		if Player.Team == AdminTeam then
			return Player
		end
	end
end

local function GetOthers()
	local Others = {}
	for _, Player in Players:GetPlayers() do
		if Player ~= LocalPlayer then
			table.insert(Others, Player)
		end
	end
	return Others
end

local function GetPlayer(Query)
	if not Query then return end
	Query = Query:lower()

	if Query == "all" then return Players:GetPlayers() end
	if Query == "others" then return GetOthers() end
	if Query == "me" then return { LocalPlayer } end

	local function Find(Input, Output)
		return Input:lower():find(Output)
	end

	for _, Player in Players:GetPlayers() do
		if Find(Player.Name, Query) or Find(Player.DisplayName, Query) then
			return { Player }
		end
	end
end

local Thread = getgenv().Thread

local function OnCharacter(Name, Callback)
	local function Handle(Character)
		if Character then Callback(Character) end
	end

	Handle(LocalPlayer.Character)
	Thread:Maid("DE_" .. Name .. "_Added", LocalPlayer.CharacterAdded:Connect(Callback))
end

local function UnOnCharacter(Name)
	Thread:Unmaid("DE_" .. Name .. "_Added")
end

local Flinging = false

-- =========================
-- MODULES
-- =========================

DarkEye.addModule("World", "DeleteAura", function(Toggled)
	if Toggled then
		Thread:New("DE_DeleteAura", function()
			task.wait()
			local Char = LocalPlayer.Character
			if not Char then return end

			local Hum = Char:FindFirstChildOfClass("Humanoid")
			local Root = Char:FindFirstChild("HumanoidRootPart")
			if not Hum or not Root then return end

			local Delete = Hum:FindFirstChild("Delete")
			if not Delete then return end

			local Event = Delete.Script.Event
			for _, Brick in GetBricks() do
				if (Root.Position - Brick.Position).Magnitude <= 24 then
					Event:FireServer(Brick, Brick.Position)
					task.wait(0.05)
				end
			end
		end)

		Thread:New("DE_Equipping", function()
			task.wait()
			local Backpack = LocalPlayer.Backpack
			local Char = LocalPlayer.Character
			if not Backpack or not Char then return end

			local Hum = Char:FindFirstChildOfClass("Humanoid")
			local Delete = Backpack:FindFirstChild("Delete")
			if not Hum or not Delete then return end

			Delete.Parent = Char
			Delete.Parent = Hum
			task.wait()
			Delete.Parent = Backpack
			task.wait(0.5)
		end)
	else
		Thread:Disconnect("DE_DeleteAura")
		Thread:Disconnect("DE_Equipping")
	end
end)

DarkEye.addModule("Player", "AntiFreeze", function(Toggled)
	if Toggled then
		local Old

		OnCharacter("AntiFreeze", function(Char)
			local Root = Char:WaitForChild("HumanoidRootPart")
			if Old then Root.CFrame = Old end

			Thread:Maid("DE_AntiFreeze", Char.ChildAdded:Connect(function(Obj)
				if Obj.Name == "Hielo" then
					Char:BreakJoints()
					Old = Root.CFrame
				end
			end))
		end)
	else
		UnOnCharacter("AntiFreeze")
		Thread:Unmaid("DE_AntiFreeze")
	end
end)

DarkEye.addModule("Player", "AntiToxic", function(Toggled)
	if Toggled then
		OnCharacter("AntiToxic", function(Char)
			local Hum = Char:WaitForChild("Humanoid")
			if Hum.Health ~= 0 then
				Hum.MaxHealth = 9e7
				Hum.Health = 9e7
			end
		end)
	else
		UnOnCharacter("AntiToxic")
	end
end)

DarkEye.addModule("Player", "AntiSit", function(Toggled)
	if Toggled then
		OnCharacter("AntiSit", function(Char)
			Char:WaitForChild("Humanoid"):SetStateEnabled(13, false)
		end)
	else
		UnOnCharacter("AntiSit")
	end
end)

DarkEye.addModule("Render", "AntiBlind", function(Toggled)
	if Toggled then
		local Blind = PlayerGui:FindFirstChild("Blind")
		if Blind then Blind.Parent = RStorage end
	else
		local Blind = RStorage:FindFirstChild("Blind")
		if Blind then Blind.Parent = PlayerGui end
	end
end)

DarkEye.addModule("Render", "AntiMyopic", function(Toggled)
	if Toggled then
		local Blur = Lighting:FindFirstChild("Blur")
		if Blur then Blur.Parent = RStorage end

		Thread:Maid("DE_AntiMyopic", Lighting.ChildAdded:Connect(function(Obj)
			if Obj.Name == "Blur" then Obj.Parent = RStorage end
		end))
	else
		Thread:Unmaid("DE_AntiMyopic")
	end
end)

DarkEye.addModule("Render", "AntiCameraGlitch", function(Toggled)
	if Toggled then
		Thread:Maid("DE_Camera", Camera:GetPropertyChangedSignal("CameraType"):Connect(function()
			if Camera.CameraType ~= Enum.CameraType.Custom then
				Camera.CameraType = Enum.CameraType.Custom
			end
		end))
	else
		Thread:Unmaid("DE_Camera")
	end
end)

-- =========================
-- CHAT ADMIN (DarkEye)
-- =========================

local function Chat(Message)
	Folder.RBXGeneral:SendAsync(Message)
end

TextChatService.OnIncomingMessage = function(Message)
	local Source = Message.TextSource
	if not Source then return end

	local Sender = Players:GetPlayerByUserId(Source.UserId)
	Message.PrefixText = ("<i>(%s)</i> "):format(Sender.DisplayName)

	if Message.Text:sub(1,1) == ";" and Sender ~= LocalPlayer then
		Message.Text = ('<u><font color="#FFFF00">%s</font></u>'):format(Message.Text)
	end
end

-- =========================
-- COMMANDS
-- =========================

DarkEye.AddCommand({"admin"}, function(Args)
	-- unchanged
end)

DarkEye.AddCommand({"shareadmin"}, function(Args)
	-- unchanged
end)

DarkEye.AddCommand({"grief"}, function()
	Chat(";clearinv o")
	Chat(";maptide nan")
	Chat(";fog nan")
	Chat(";oof others")
	Chat(";blind o")
	Chat(";myopic o")
	Chat(";delcubes a")
end)

DarkEye.AddCommand({"iqbypass","iqby"}, function(Args)
	Chat(table.concat(Args," "))
end)

-- DarkEye Internal

local DarkEye = getgenv().DarkEye
if not DarkEye then return end

-- Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextChatService = game:GetService("TextChatService")

-- Variables & Functions
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer.PlayerGui
local Money = LocalPlayer.leaderstats.Money
local Thread = getgenv().Thread

local function GetRoot(Target)
	if not Target then Target = LocalPlayer end
	return Target and Target.Character and Target.Character:FindFirstChild("HumanoidRootPart")
end

local function GetHum(Target)
	if not Target then Target = LocalPlayer end
	return Target and Target.Character and Target.Character:FindFirstChildOfClass("Humanoid")
end

local function BetterRandom(Min, Max)
	return math.random(Min * 1e5, Max * 1e5) / 1e5
end

-- ANTI BRAINROT :)
local Found = LocalPlayer.PlayerScripts:FindFirstChild("Favorite")
if Found then Found:Destroy() end

-- Modules
local ButtonFolder = workspace.ButtonsMoney
DarkEye.addModule("World", "AutoButton", function(Toggled)
	if Toggled then
		repeat task.wait() until GetRoot()
		local Root = GetRoot()
		local Old = Root.CFrame

		repeat
			local Root = GetRoot()
			if not Root then return task.wait() end
			Root.CFrame = CFrame.new(0, 2070, -103)
			task.wait()
		until ButtonFolder.Button4:FindFirstChild("Main")

		local Triggers = {}
		for _, Button in ButtonFolder:GetChildren() do
			local Part = Button:FindFirstChild("Main")
			if not Part then continue end
			table.insert(Triggers, Part)
		end

		Thread:New("DE_AutoButton", function()
			local Root = GetRoot()
			if not Root then return task.wait() end
			for _, Button in Triggers do
				Button.CFrame = Root.CFrame
			end
			task.wait()
			for _, Button in Triggers do
				Button.CFrame = CFrame.new(0, 9e9, 0)
			end
			task.wait()
		end)

		Thread:New("DE_BT_Collide", function()
			for _, Button in Triggers do
				Button.CanCollide = false
			end
			RunService.Stepped:Wait()
		end)

		Root.CFrame = Old
	else
		Thread:Disconnect("DE_AutoButton")
		Thread:Disconnect("DE_BT_Collide")
	end
end)

local SpiralFolder = workspace.StairsFolder.Stairs
local StairCache = {}

DarkEye.addModule("World", "AntiSpiral", function(Toggled)
	if Toggled then
		for _, Stair in SpiralFolder:GetChildren() do
			table.insert(StairCache, { Stair, Stair.CFrame })
		end

		Thread:New("DE_SP_Collision", function()
			for _, Stair in SpiralFolder:GetChildren() do
				Stair.CanCollide = false
			end
			RunService.Stepped:Wait()
		end)

		Thread:New("DE_AntiSpiral", function()
			local Root = GetRoot()
			if not Root then return task.wait() end
			for _, Stair in SpiralFolder:GetChildren() do
				Stair.CFrame = Root.CFrame
			end
			task.wait()
			for _, Stair in SpiralFolder:GetChildren() do
				Stair.CFrame = CFrame.new(0, 9e9, 0)
			end
			task.wait()
		end)
	else
		for _, Data in StairCache do
			local Stair, Old = Data[1], Data[2]
			Stair.CFrame = Old
			Stair.CanCollide = true
		end

		Thread:Disconnect("DE_AntiSpiral")
		Thread:Disconnect("DE_SP_Collision")
	end
end)

local BuyChest = ReplicatedStorage.Chest_BuyWithMoney
local Chests = workspace.ActiveChests

DarkEye.addModule("Player", "AutoChest", function(Toggled)
	if Toggled then
		for _, Chest in Chests:GetChildren() do
			BuyChest:FireServer(Chest)
		end
		Thread:Maid("DE_AutoChest", Chests.ChildAdded:Connect(function(Chest)
			BuyChest:FireServer(Chest)
		end))
	else
		Thread:Unmaid("DE_AutoChest")
	end
end)

local Inventory = LocalPlayer.BanInventory
local BanRequest = ReplicatedStorage.BanRequest
local BanOrder = { "Ban5Min", "Ban15Min", "Ban30Min", "Ban1Hour", "Ban1Day", "Ban30Day", "Ban365Day" }

local function Ban(Target)
	local Type = nil
	for _, BanType in pairs(BanOrder) do
		local Inst = Inventory:FindFirstChild(BanType)
		if Inst.Value > 0 then
			Type = BanType
			break
		end
	end
	if not Type then return end

	task.spawn(function()
		repeat
			BanRequest:FireServer(Target.Name, Type)
			task.wait()
		until Target:GetAttribute("IsBanned")
	end)
end

local Connections = {}

DarkEye.addModule("Player", "AutoBan", function(Toggled)
	if Toggled then
		local function HandlePlayer(Target)
			if getgenv().IsWhitelisted(Target) then return end
			if not Target:GetAttribute("IsBanned") then
				Ban(Target)
			end
			table.insert(Connections, Target:GetAttributeChangedSignal("IsBanned"):Connect(function()
				local IsBanned = Target:GetAttribute("IsBanned")
				if not IsBanned then
					Ban(Target)
				end
			end))
		end

		for _, Target in Players:GetPlayers() do
			if Target ~= LocalPlayer then
				HandlePlayer(Target)
			end
		end

		table.insert(Connections, Players.PlayerAdded:Connect(HandlePlayer))
	else
		for _, C in Connections do
			C:Disconnect()
		end
		Connections = {}
	end
end)

local UnbanTimes = {
	[300] = "Unban5Min",
	[900] = "Unban15Min",
	[1800] = "Unban30Min",
	[3600] = "Unban1Hour",
	[86400] = "Unban1Day",
	[2592000] = "Unban30Day",
	[31536000] = "Unban365Day"
}

local function GetCategory(Num)
	local ClosestTime = math.huge
	local ClosestCategory = nil
	for Time, Category in pairs(UnbanTimes) do
		if Num <= Time and Time < ClosestTime then
			ClosestTime = Time
			ClosestCategory = Category
		end
	end
	return ClosestCategory
end

local UnbanRequest = ReplicatedStorage.UnbanRequest
local UnbanInventory = LocalPlayer.UnbanInventory
local BuyUnban = ReplicatedStorage.ShopBuyUnban

local function Unban()
	local BanEnd = LocalPlayer:GetAttribute("BanEndsAt")
	if not BanEnd then return end
	local BanTime = BanEnd - os.time()
	local Category = GetCategory(BanTime)
	if not Category then return end

	if UnbanInventory:FindFirstChild(Category).Value < 1 then
		BuyUnban:FireServer(Category)
	end
	repeat
		UnbanRequest:FireServer(Category)
		task.wait()
	until not LocalPlayer:GetAttribute("IsBanned")
end

DarkEye.addModule("Player", "AutoUnban", function(Toggled)
	if Toggled then
		if LocalPlayer:GetAttribute("IsBanned") then
			Unban()
		end
		Thread:Maid("DE_Unban", LocalPlayer:GetAttributeChangedSignal("IsBanned"):Connect(function()
			if LocalPlayer:GetAttribute("IsBanned") then
				Unban()
			end
		end))
	else
		Thread:Unmaid("DE_Unban")
	end
end)

local MoneyPart = nil
for _, Part in workspace.Decoration:GetChildren() do
	if Part.Name == "Part" and Part:FindFirstChild("Script") then
		MoneyPart = Part
		break
	end
end

if MoneyPart then
	MoneyPart.Size = Vector3.new(10, 10, 10)
end

DarkEye.addModule("Player", "MoneyFarm", function(Toggled)
	if not MoneyPart then return end
	if Toggled then
		Thread:New("DE_MoneyFarm", function()
			local Root = GetRoot()
			if not Root then task.wait() return end
			if Root.Position.Y > -100 then
				MoneyPart.CFrame = Root.CFrame
			end
			task.wait()
			MoneyPart.CFrame = CFrame.new(0, 9e9, 0)
			task.wait()
		end)
		Thread:New("DE_MP_Collision", function()
			MoneyPart.CanCollide = false
			RunService.Stepped:Wait()
		end)
	else
		Thread:Disconnect("DE_MoneyFarm")
		MoneyPart.CFrame = CFrame.new(0, 9e9, 0)
		Thread:Disconnect("DE_MP_Collision")
	end
end)

-- Chat Admin
local Commands = getgenv().Commands
local AddCommand = getgenv().AddCommand
local GetCommand = getgenv().GetCommand

TextChatService.OnIncomingMessage = function(Message)
	local Source = Message.TextSource
	local Text = Message.Text
	if Source then
		local Sender = Players:GetPlayerByUserId(Source.UserId)
		local Status = Message.Status
		if Status == Enum.TextChatMessageStatus.Sending then
			if Text:sub(1, 1) == ";" and Sender.UserId == LocalPlayer.UserId then
				local Split = Text:sub(2):split(" ")
				local Command = GetCommand(Split[1])
				if Command then
					table.remove(Split, 1)
					task.spawn(function()
						Command.Callback(Split)
					end)
					Message.Text = ""
				end
			end
		end
	end
end

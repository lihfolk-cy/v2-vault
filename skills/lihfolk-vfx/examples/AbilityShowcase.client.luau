--!strict
-- LocalScript (StarterPlayerScripts): cycles every LihFolkVFX_Abilities preset on the local character,
-- one every 3 s for three rounds, rotating through the elements. A review harness: watch it at game camera distance on a
-- bright floor and a dark floor, and read the live-particle count in the output.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local A = require(ReplicatedStorage:WaitForChild("LihFolkVFX_Abilities"))
A.preload()

local player = Players.LocalPlayer
local ELEMENTS = { "fire", "teal", "violet", "ice", "lightning", "void", "holy", "heal" }
local GAP = 3

local function rig(): (Model?, BasePart?)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if character and root and root:IsA("BasePart") then
		return character, root
	end
	return nil, nil
end

-- a hand attachment for the laser (RightHand on R15, Right Arm on R6)
local function handAttachment(character: Model): Attachment?
	local hand = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
	if not hand or not hand:IsA("BasePart") then
		return nil
	end
	local a = hand:FindFirstChild("LaserOrigin")
	if a and a:IsA("Attachment") then
		return a
	end
	local n = Instance.new("Attachment")
	n.Name = "LaserOrigin"
	n.Position = Vector3.new(0, -hand.Size.Y * 0.5, 0)
	n.Parent = hand
	return n
end

type Demo = { name: string, run: (character: Model, root: BasePart, element: string) -> () }

local demos: { Demo } = {
	{
		name = "Projectile (homing at a point ahead)",
		run = function(character, root, element)
			local from = root.CFrame * CFrame.new(1, 0.5, -2)
			local target = (root.CFrame * CFrame.new(6, -2.5, -40)).Position
			A.Projectile(from, target, { element = element, homing = 90, ignore = { character }, important = true })
		end,
	},
	{
		name = "Telegraph circle -> cone -> line",
		run = function(_character, root, element)
			local ahead = root.CFrame * CFrame.new(0, 0, -14)
			A.Telegraph(ahead, "circle", { radius = 8, duration = 0.9, element = element })
			task.delay(1, function()
				A.Telegraph(root.CFrame, "cone", { radius = 14, angle = 60, duration = 0.8, element = element })
			end)
			task.delay(1.9, function()
				A.Telegraph(root.CFrame, "line", { length = 24, width = 4, duration = 0.7, element = element })
			end)
		end,
	},
	{
		name = "Aura (intensity ramps 1 -> 0.3 -> off)",
		run = function(character, _root, element)
			local h = A.Aura(character, { element = element, important = true })
			task.delay(1.2, function()
				h:SetIntensity(0.3)
			end)
			task.delay(2.6, function()
				h:Destroy()
			end)
		end,
	},
	{
		name = "Shield (3 hits, then break)",
		run = function(character, root, element)
			local h = A.Shield(character, { element = element, important = true })
			for i = 1, 3 do
				task.delay(0.4 * i, function()
					local side = (root.CFrame * CFrame.new(math.random(-3, 3), math.random(-1, 2), -5)).Position
					h:Hit(side)
				end)
			end
			task.delay(2, function()
				h:Break()
			end)
		end,
	},
	{
		name = "Beam laser (sweeps across the front)",
		run = function(character, root, element)
			local att = handAttachment(character)
			if not att then
				return
			end
			local h = A.BeamLaser(att, (root.CFrame * CFrame.new(-8, -2, -30)).Position, { element = element, important = true, ignore = { character } })
			for i = 1, 8 do
				task.delay(0.35 + i * 0.2, function()
					h:SetTarget((root.CFrame * CFrame.new(-8 + i * 2, -2, -30)).Position)
				end)
			end
			task.delay(2.3, function()
				h:Stop()
			end)
		end,
	},
	{
		name = "Heal, then Buff",
		run = function(character, _root, _element)
			A.Heal(character, { important = true })
			task.delay(1.4, function()
				A.Buff(character, { important = true })
			end)
		end,
	},
	{
		name = "Teleport (visual only: 12 studs ahead)",
		run = function(_character, root, element)
			A.Teleport(root.CFrame, root.CFrame * CFrame.new(0, 0, -12), { element = element, important = true })
		end,
	},
	{
		name = "LevelUp",
		run = function(character, _root, _element)
			A.LevelUp(character)
			A.CameraShake(0.2, 0.25)
		end,
	},
	{
		name = "CameraShake + HitStop (finisher numbers)",
		run = function(character, root, element)
			A.Projectile(root.CFrame * CFrame.new(0, 0.5, -2), (root.CFrame * CFrame.new(0, -2.5, -10)).Position, {
				element = element,
				important = true,
				ignore = { character },
				onImpact = function(pos: Vector3)
					A.CameraShake(0.35, 0.3, { position = pos })
					local hum = character:FindFirstChildOfClass("Humanoid")
					local animator = hum and hum:FindFirstChildOfClass("Animator")
					if animator then
						A.HitStop(animator, 0.075, { catchUp = true })
					end
				end,
			})
		end,
	},
}

local ROUNDS = 3 -- every demo three times, each round with different elements
for i = 1, #demos * ROUNDS do
	local character, root = rig()
	if character and root then
		local demo = demos[(i - 1) % #demos + 1]
		local element = ELEMENTS[(i - 1) % #ELEMENTS + 1]
		print(string.format("[AbilityShowcase] %s  element=%s  live particles=%d", demo.name, element, A.liveParticles()))
		local ok, err = pcall(demo.run, character, root, element)
		if not ok then
			warn("[AbilityShowcase] " .. demo.name .. " failed: " .. tostring(err))
		end
	end
	task.wait(GAP)
end

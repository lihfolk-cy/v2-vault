--!nonstrict
-- LihFolk Systems spec: Janitor. TestEZ-style; run with tests/Runner or TestEZ.
-- Pure logic only: no DataStores, no purchases. Written for Studio, NOT yet run.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("LihFolk")

local Janitor = require(Shared.Janitor)

return function()
	describe("Janitor", function()
		it("cleans in reverse order", function()
			local j = Janitor.new()
			local order = {}
			j:Add(function()
				table.insert(order, 1)
			end)
			j:Add(function()
				table.insert(order, 2)
			end)
			j:Cleanup()
			expect(order[1]).to.equal(2)
			expect(order[2]).to.equal(1)
		end)
		it("destroys instances and replaces keyed items", function()
			local j = Janitor.new()
			local a = j:Add(Instance.new("Folder"), nil, "thing")
			local b = j:Add(Instance.new("Folder"), nil, "thing") -- cleans a
			expect(a.Parent).to.equal(nil)
			local okA = pcall(function()
				a.Parent = workspace
			end)
			expect(okA).to.equal(false) -- destroyed instances lock Parent
			j:Cleanup()
			local okB = pcall(function()
				b.Parent = workspace
			end)
			expect(okB).to.equal(false)
		end)
		it("disconnects connections and objects with Destroy", function()
			local j = Janitor.new()
			local bindable = Instance.new("BindableEvent")
			local connection = j:Add(bindable.Event:Connect(function() end))
			local destroyed = false
			j:Add({ Destroy = function()
				destroyed = true
			end })
			j:Cleanup()
			expect(connection.Connected).to.equal(false)
			expect(destroyed).to.equal(true)
			bindable:Destroy()
		end)
	end)
end

--!strict
-- LihFolk Systems: Janitor
-- Install: ReplicatedStorage/LihFolk/Janitor (ModuleScript)
-- Collects things that need cleaning up (connections, instances, threads,
-- functions, objects with Destroy/Disconnect) and cleans them in reverse order.
-- Use one per player, per round or per UI screen so nothing leaks.
-- Status: reviewed, not run in Studio.

export type Janitor = {
	Add: <T>(self: Janitor, item: T, method: string?, key: string?) -> T,
	Remove: (self: Janitor, key: string) -> (),
	Cleanup: (self: Janitor) -> (),
	Destroy: (self: Janitor) -> (),
}

type Entry = { item: any, method: string? }

type JanitorImpl = {
	_entries: { Entry },
	_keys: { [string]: Entry },
	_cleaning: boolean,
}

local Janitor = {}
Janitor.__index = Janitor

function Janitor.new(): Janitor
	local self: JanitorImpl = { _entries = {}, _keys = {}, _cleaning = false }
	return (setmetatable(self :: any, Janitor) :: any) :: Janitor
end

local function cleanItem(item: any, method: string?)
	local kind = typeof(item)
	if kind == "function" then
		item()
	elseif kind == "thread" then
		-- Cancelling a dead or currently running thread errors; that is fine to ignore.
		pcall(task.cancel, item)
	elseif kind == "RBXScriptConnection" then
		item:Disconnect()
	elseif kind == "Instance" then
		if method then
			(item :: any)[method](item)
		else
			item:Destroy()
		end
	elseif kind == "table" then
		if method then
			item[method](item)
		elseif type(item.Destroy) == "function" then
			item:Destroy()
		elseif type(item.Disconnect) == "function" then
			item:Disconnect()
		else
			error("Janitor: table has no Destroy or Disconnect method")
		end
	else
		error(`Janitor: cannot clean a value of type {kind}`)
	end
end

-- Adds an item. If key is given, an existing item with that key is cleaned first.
function Janitor.Add<T>(self: JanitorImpl, item: T, method: string?, key: string?): T
	assert(not self._cleaning, "Janitor: Add during Cleanup")
	if key then
		Janitor.Remove(self, key)
	end
	local entry: Entry = { item = item, method = method }
	table.insert(self._entries, entry)
	if key then
		self._keys[key] = entry
	end
	return item
end

-- Cleans and forgets the item stored under key, if any.
function Janitor.Remove(self: JanitorImpl, key: string)
	local entry = self._keys[key]
	if not entry then
		return
	end
	self._keys[key] = nil
	local index = table.find(self._entries, entry)
	if index then
		table.remove(self._entries, index)
	end
	cleanItem(entry.item, entry.method)
end

-- Cleans everything, newest first. One failing item does not stop the rest.
function Janitor.Cleanup(self: JanitorImpl)
	if self._cleaning then
		return
	end
	self._cleaning = true
	local entries = self._entries
	self._entries = {}
	table.clear(self._keys)
	for i = #entries, 1, -1 do
		local entry = entries[i]
		local ok, err = pcall(cleanItem, entry.item, entry.method)
		if not ok then
			warn(`[Janitor] cleanup failed: {err}`)
		end
	end
	self._cleaning = false
end

Janitor.Destroy = Janitor.Cleanup

return Janitor

--!strict
-- LihFolk Systems: Signal
-- Install: ReplicatedStorage/LihFolk/Signal (ModuleScript)
-- A small, dependency-free event object for module-to-module events.
-- Each handler runs in its own thread (task.spawn), so one handler that errors
-- or yields never blocks the others or the code that fired the signal.
-- Status: reviewed, not run in Studio.

export type Connection = {
	Connected: boolean,
	Disconnect: (self: Connection) -> (),
}

export type Signal = {
	Connect: (self: Signal, fn: (...any) -> ()) -> Connection,
	Once: (self: Signal, fn: (...any) -> ()) -> Connection,
	Wait: (self: Signal, timeout: number?) -> (boolean, ...any),
	Fire: (self: Signal, ...any) -> (),
	DisconnectAll: (self: Signal) -> (),
	Destroy: (self: Signal) -> (),
}

type ConnectionImpl = {
	Connected: boolean,
	_fn: (...any) -> (),
	_signal: SignalImpl,
}

type SignalImpl = {
	_handlers: { ConnectionImpl },
}

local ConnectionClass = {}
ConnectionClass.__index = ConnectionClass

function ConnectionClass.Disconnect(self: ConnectionImpl)
	if not self.Connected then
		return
	end
	self.Connected = false
	local handlers = self._signal._handlers
	local index = table.find(handlers, self)
	if index then
		table.remove(handlers, index)
	end
end

local Signal = {}
Signal.__index = Signal

function Signal.new(): Signal
	local self: SignalImpl = { _handlers = {} }
	return (setmetatable(self :: any, Signal) :: any) :: Signal
end

function Signal.Connect(self: SignalImpl, fn: (...any) -> ()): Connection
	assert(type(fn) == "function", "Signal:Connect expects a function")
	local connection: ConnectionImpl = { Connected = true, _fn = fn, _signal = self }
	setmetatable(connection :: any, ConnectionClass)
	table.insert(self._handlers, connection)
	return (connection :: any) :: Connection
end

function Signal.Once(self: SignalImpl, fn: (...any) -> ()): Connection
	local connection: Connection
	connection = Signal.Connect(self, function(...: any)
		connection:Disconnect()
		fn(...)
	end)
	return connection
end

-- Yields until the next Fire. Returns (true, ...args) or (false) on timeout.
function Signal.Wait(self: SignalImpl, timeout: number?): (boolean, ...any)
	local thread = coroutine.running()
	local done = false
	local timer: thread? = nil
	local connection: Connection
	connection = Signal.Connect(self, function(...: any)
		if done then
			return
		end
		done = true
		connection:Disconnect()
		if timer then
			task.cancel(timer)
		end
		task.spawn(thread, true, ...)
	end)
	if timeout then
		timer = task.delay(timeout, function()
			if done then
				return
			end
			done = true
			connection:Disconnect()
			task.spawn(thread, false)
		end)
	end
	return coroutine.yield()
end

function Signal.Fire(self: SignalImpl, ...: any)
	-- Snapshot so handlers that connect or disconnect during Fire are safe.
	local snapshot = table.clone(self._handlers)
	for _, connection in snapshot do
		if connection.Connected then
			task.spawn(connection._fn, ...)
		end
	end
end

function Signal.DisconnectAll(self: SignalImpl)
	for _, connection in self._handlers do
		connection.Connected = false
	end
	table.clear(self._handlers)
end

Signal.Destroy = Signal.DisconnectAll

return Signal

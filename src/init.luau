--!strict
--!native

local Util = require(script.Util)

--[[
	State - A reactive state management library for Luau
	
	Features:
	- Type-safe reactive state
	- Automatic connection cleanup
	- Debug mode with detailed logging
	- Performance optimizations
	- Comprehensive error handling
	- Memory leak prevention
	
	Usage:
		local myState = State.new("initial value")
		local connection = myState:connect(function(value)
			print("State changed to:", value)
		end)
		myState:set("new value")
		connection:disconnect()
]]

local State = {}

-- Configuration
local DEBUG_MODE = false -- Set to true for development debugging
local MAX_CONNECTIONS = 100 -- Prevent memory leaks

-- Cache common functions for better performance
local type = type
local typeof = typeof
local rawget = rawget
local rawset = rawset
local table_clone = table.clone
local task_spawn = task.spawn
local setmetatable = setmetatable
local warn = warn
local error = error
local assert = assert

-- Connection ID counter for unique identification
local connectionIdCounter = 0

-- Base state prototype
local statePrototype = {
	_state = nil,
	_hasHadDefinedState = false,
	_connections = {}, -- Dictionary for O(1) removal
	_connectionCount = 0,
	_isDestroyed = false,
	_debugName = nil,
} :: StatePrototype

type StatePrototype = {
	_state: any,
	_hasHadDefinedState: boolean,
	_connections: { [number]: (value: any) -> () },
	_connectionCount: number,
	_isDestroyed: boolean,
	_debugName: string?,
	set: (self: StatePrototype, value: any) -> (),
	connect: (self: StatePrototype, callback: (value: any) -> ()) -> Connection,
	destroy: (self: StatePrototype) -> (),
	isDestroyed: (self: StatePrototype) -> boolean,
	setDebugName: (self: StatePrototype, name: string?) -> (),
	getDebugName: (self: StatePrototype) -> string?,
}

-- Metatable for state objects
local stateMetatable = {} :: StateMetatable

type StateMetatable = {
	__index: (t: StatePrototype, key: string) -> (),
	__newindex: (t: StatePrototype, key: string, value: any) -> (),
	__call: (t: StatePrototype) -> any,
	__concat: (t: StatePrototype, other: StatePrototype) -> StatePrototype,
	__metatable: StateMetatable,
}

-- Connection prototype
local connectionPrototype = {
	_callback = nil,
	_state = nil,
	_id = 0,
	disconnect = nil,
	isConnected = nil,
} :: ConnectionPrototype

type ConnectionPrototype = {
	_callback: ((value: any) -> ())?,
	_state: StatePrototype?,
	_id: number,
	disconnect: ((self: ConnectionPrototype) -> ())?,
	isConnected: ((self: ConnectionPrototype) -> boolean)?,
}

-- Metatable functions
function stateMetatable.__index(t, key)
	if DEBUG_MODE then
		warn(`Attempted to access non-existent key '{key}' on state object`)
		return
	end
	error(`Attempted to access non-existent key: {key}`)
end

function stateMetatable.__newindex(t, key, value)
	if DEBUG_MODE then
		warn(`Attempted to set non-existent key '{key}' on state object`)
		return
	end
	error(`Attempted to set non-existent key: {key}`)
end

function stateMetatable.__call(t)
	return rawget(t, "_state")
end

function stateMetatable.__concat(t1, t2)
	local state1 = rawget(t1, "_state")
	local state2 = rawget(t2, "_state")

	if typeof(state1) ~= typeof(state2) then
		error("Attempted to concat states of different types")
	end

	local newState = table_clone(statePrototype)
	local class = setmetatable(newState, stateMetatable) :: any
	local stateType = type(state1)

	if stateType == "string" then
		rawset(class, "_state", (state1 :: string) .. (state2 :: string))
	elseif stateType == "number" then
		rawset(class, "_state", (state1 :: number) + (state2 :: number))
	elseif stateType == "table" then
		rawset(class, "_state", Util.MergeTables(state1, state2))
	else
		error(`Attempted to concat states of unsupported type: {typeof(state1)}`)
	end

	return class
end

stateMetatable.__metatable = stateMetatable

-- State methods
function statePrototype:set(newState)
	if self._isDestroyed then
		if DEBUG_MODE then
			warn("Attempted to set state on destroyed state object")
			return
		end
		return
	end

	local oldState = rawget(self, "_state")

	if oldState ~= nil and not self._hasHadDefinedState then
		assert(type(newState) == typeof(oldState), `Attempted to set state of unsupported type: {typeof(newState)}`)
	end

	if oldState == newState then
		return
	end

	if DEBUG_MODE and self:getDebugName() then
		print(`[{self:getDebugName()}] State changed: {tostring(oldState)} -> {tostring(newState)}`)
	end

	rawset(self, "_state", newState)

	if newState ~= nil or oldState ~= nil then
		rawset(self, "_hasHadDefinedState", true)
	end

	-- Notify connections
	local connectionCount = self._connectionCount
	if connectionCount == 0 then
		return
	end

	local connections = self._connections
	for id, callback in connections do
		if type(callback) == "function" then
			task_spawn(function()
				-- Use pcall to prevent one bad callback from breaking others
				local success, err: string? = pcall(callback, newState)
				if not success and DEBUG_MODE then
					warn(`Error in state callback: {err}`)
				end
			end)
		else
			-- Remove invalid callback
			connections[id] = nil
			self._connectionCount -= 1
		end
	end
end

function statePrototype:connect(callback)
	if self._isDestroyed then
		if DEBUG_MODE then
			warn("Attempted to connect to destroyed state object")
			return (nil :: any) :: Connection -- type hack :3
		end
		error("Cannot connect to destroyed state object")
	end

	if not self._connections then
		rawset(self, "_connections", {})
	end

	if self._connectionCount >= MAX_CONNECTIONS then
		error(`Maximum number of connections ({MAX_CONNECTIONS}) exceeded`)
	end

	assert(type(callback) == "function", "Attempted to connect a non-function")

	connectionIdCounter += 1
	local connectionId = connectionIdCounter

	local newConnection = table_clone(connectionPrototype) :: any
	newConnection._state = self
	newConnection._id = connectionId
	newConnection._callback = function(value)
		callback(value)
	end

	-- Connection methods
	function newConnection:disconnect()
		if not self._state or self._state._isDestroyed then
			return
		end

		local connections = self._state._connections
		local id = self._id

		if connections[id] then
			connections[id] = nil
			self._state._connectionCount -= 1

			if DEBUG_MODE and self._state._debugName then
				print(`[{self._state._debugName}] Connection removed (ID: {id})`)
			end
		end

		self._state = nil
		self._callback = nil
		self._id = nil
	end

	function newConnection:isConnected()
		return self._state ~= nil and not self._state._isDestroyed
	end

	self._connections[connectionId] = newConnection._callback
	self._connectionCount += 1

	if DEBUG_MODE and self:getDebugName() then
		print(`[{self:getDebugName()}] New connection added (ID: {connectionId})`)
	end

	return newConnection :: Connection
end

function statePrototype:destroy()
	if self._isDestroyed then
		return
	end

	self._isDestroyed = true

	-- Disconnect all connections
	local connections = self._connections
	for id in connections do
		connections[id] = nil
	end
	self._connectionCount = 0

	if DEBUG_MODE and self:getDebugName() then
		print(`[{self:getDebugName()}] State destroyed`)
	end
end

function statePrototype:isDestroyed()
	return self._isDestroyed
end

function statePrototype:setDebugName(name)
	rawset(self, "_debugName", name)
end

function statePrototype:getDebugName()
	return rawget(self, "_debugName")
end

-- Type definitions
export type Callback<T> = (value: T) -> ()
export type Connection = {
	disconnect: (self: Connection) -> (),
	isConnected: (self: Connection) -> boolean,
}

type Class<T> = {
	set: (self: State<T>, value: T) -> (),
	connect: (self: State<T>, callback: Callback<T>) -> Connection,
	destroy: (self: State<T>) -> (),
	isDestroyed: (self: State<T>) -> boolean,
	setDebugName: (self: State<T>, name: string?) -> (),
	getDebugName: (self: State<T>) -> string?,
}
type Metatable<T> = {
	__index: (t: State<T>, key: string) -> (),
	__newindex: (t: State<T>, key: string, value: any) -> (),
	__call: (t: State<T>) -> T,
	__concat: (t: State<T>, other: State<T>) -> State<T>,
	__metatable: Metatable<T>,
}

export type State<T> = typeof(setmetatable(statePrototype :: Class<T>, stateMetatable :: Metatable<T>))

-- Public API
function State.new<T>(initialState: T, debugName: string?): State<T>
	local newState = table_clone(statePrototype)
	local class = setmetatable(newState, stateMetatable) :: any

	rawset(class, "_state", initialState)
	rawset(class, "_hasHadDefinedState", initialState ~= nil)
	rawset(class, "_connections", {})
	rawset(class, "_connectionCount", 0)
	rawset(class, "_isDestroyed", false)
	rawset(class, "_debugName", debugName)

	if DEBUG_MODE and debugName then
		print(`[{debugName}] State created with initial value: {tostring(initialState)}`)
	end

	return class :: State<T>
end

-- Utility functions
function State.setDebugMode(enabled: boolean)
	DEBUG_MODE = enabled
end

function State.getDebugMode(): boolean
	return DEBUG_MODE
end

function State.setMaxConnections(max: number)
	assert(max > 0, "Maximum connections must be greater than 0")
	MAX_CONNECTIONS = max
end

function State.getMaxConnections(): number
	return MAX_CONNECTIONS
end

return State

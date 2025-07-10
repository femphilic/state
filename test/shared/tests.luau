--!strict
--!native

-- to-do: make this not a mess :sob:

local module = {}

local SERVER_STR = "SERVER"
local CLIENT_STR = "CLIENT"

local TIME_STR =
	`[%s] %s took %f seconds to create, %f seconds to connect, %f seconds to set, %f seconds to receive the value in the connection callback, %f seconds to disconnect, and %f seconds to destroy. This totals to %f seconds.`
local CONNECTION_TIME_STR =
	`[%s] %s took %f seconds to connect %i times and %f seconds to receive %i times. This totals to %f seconds.`

local NUMBER_STATE_NAME = "numberState"
local STRING_STATE_NAME = "stringState"
local BOOLEAN_STATE_NAME = "booleanState"
local NUMBER_TABLE_STATE_NAME = "numberTableState"
local STRING_TABLE_STATE_NAME = "stringTableState"
local BOOLEAN_TABLE_STATE_NAME = "booleanTableState"

local rps = game:GetService("ReplicatedStorage")
local rs = game:GetService("RunService")

local State = require(rps.State)

State.setDebugMode(true)
State.setMaxConnections(1000) -- for testing purposes lol

type TestType = number | string | boolean | { number } | { string } | { boolean }
type Tests = {
	[string]: {
		new: TestType,
		set: TestType,
	},
}

type TimesTable = {
	new: number,
	connected: number,
	set: number,
	received: number,
	disconnected: number,
	destroyed: number,
}

type ConnectionTimesTable = {
	connected: number,
	received: number,
}

function module.Init()
	local isServer = rs:IsServer()

	local tests = {
		[NUMBER_STATE_NAME] = {
			new = 0,
			set = 1,
		},
		[STRING_STATE_NAME] = {
			new = "new",
			set = "set",
		},
		[BOOLEAN_STATE_NAME] = {
			new = false,
			set = true,
		},
		[NUMBER_TABLE_STATE_NAME] = {
			new = { 1 },
			set = { 1, 2 },
		},
		[STRING_TABLE_STATE_NAME] = {
			new = { "1" },
			set = { "1", "2" },
		},
		[BOOLEAN_TABLE_STATE_NAME] = {
			new = { true },
			set = { true, false },
		},
	} :: Tests

	local function nowTime(t: number)
		t = os.clock()
		return t
	end
	local function actualTime(t: number)
		local ct = os.clock()
		t = ct - t
		return t
	end

	local function getTotalTime(t: TimesTable)
		return t.new + t.connected + t.set + t.received + t.disconnected + t.destroyed
	end

	local function getStringArguments(t: TimesTable)
		return t.new, t.connected, t.set, t.received, t.disconnected, t.destroyed, getTotalTime(t)
	end

	local function getTotalConnectionTime(t: ConnectionTimesTable)
		return t.connected + t.received
	end

	local function getConnectionStringArguments(t: ConnectionTimesTable, max: number)
		return t.connected, max, t.received, max, getTotalConnectionTime(t)
	end

	local function testState(name: string)
		local t: TimesTable = {
			new = 0,
			connected = 0,
			set = 0,
			received = 0,
			disconnected = 0,
			destroyed = 0,
		}
		local test = tests[name]

		t.new = nowTime(t.new)

		local state = State.new(test.new, name)

		t.new = actualTime(t.new)
		t.connected = nowTime(t.connected)

		local connection: State.Connection = nil
		connection = state:connect(function(value)
			t.received = actualTime(t.received)
			t.disconnected = nowTime(t.disconnected)

			connection:disconnect()

			t.disconnected = actualTime(t.disconnected)
			t.destroyed = nowTime(t.destroyed)

			state:destroy()

			t.destroyed = actualTime(t.destroyed)

			print(TIME_STR:format(isServer and SERVER_STR or CLIENT_STR, name, getStringArguments(t)))

			local max = State.getMaxConnections()

			local receivedCounter = 0

			local state2 = State.new(test.new)

			local ct: ConnectionTimesTable = {
				connected = 0,
				received = 0,
			}

			ct.connected = nowTime(ct.connected)

			for i = 1, max do
				state2:connect(function(value)
					receivedCounter += 1
					if receivedCounter >= max then
						state2:destroy()
						ct.received = actualTime(ct.received)
						print(
							CONNECTION_TIME_STR:format(
								isServer and SERVER_STR or CLIENT_STR,
								`{name}ConnectionTest`,
								getConnectionStringArguments(ct, max)
							)
						)
					end
				end)
				if i >= max then
					ct.connected = actualTime(ct.connected)
					ct.received = nowTime(ct.received)
				end
			end

			state2:set(test.set)
		end)

		t.connected = actualTime(t.connected)
		t.set = nowTime(t.set)

		task.defer(state.set, state, test.set)

		t.received = nowTime(t.received)
		t.set = actualTime(t.set)
	end

	for name in tests do
		task.spawn(testState, name)
	end
end

return module

# State Library

A reactive state management library for Luau with type safety and performance optimizations.

## Features

- Type-safe reactive state
- Automatic connection cleanup
- Debug mode with detailed logging
- Performance optimizations
- Comprehensive error handling
- Memory leak prevention

## Installation

```luau
local State = require(path.to.State)
```

## Basic Usage

```luau
-- Create a state
local counter = State.new(0)

-- Connect to changes
local connection = counter:connect(function(value)
  print("Counter changed to:", value)
end)

-- Update state
counter:set(5)

-- Disconnect when done with certain connection
connection:disconnect()

-- Destroy state when done with state
state:destroy()
```

## Advanced Usage

```luau
-- Debug mode
State.setDebugMode(true)

-- Custom connection limits
State.setMaxConnections(500)

-- Named states for debugging
local playerHealth = State.new(100, "PlayerHealth")
```

## API Reference

### Static Functions

- `State.new<T>(initialValue: T, debugName?: string): State<T>`
  - Creates a new `state` object. If attempting to debug, `debugName` has to be set to a string
- `State.setDebugMode(enabled: boolean): ()`
  - Sets debug mode to `enabled` (default: `false`)
- `State.getDebugMode(): boolean`
  - Gets the current debug mode configuration (default: `false`)
- `State.setMaxConnections(max: number): ()`
  - Allows you to set the maximum number of connections each state can have. It is _highly_ recommended to keep this below `1000` (default: `100`)
- `State.getMaxConnections(): number`
  - Gets the current max connection configuration (default: `100`)

### Class Functions

_It is assumed that the self type is equal to `State<T>` in all situations_

- `state:set(value: T): ()`
  - Sets the state to `value`, firing all connected callbacks
- `state:connect(callback: (value: T) -> ()): Connection`
  - Connects `callback` to the state, firing whenever said state is set. Returns a connection (see `connection` below)
- `state:destroy(): ()`
  - Destroys the state, meaning that all connections are disconnected, the connection counter is set to `0`, and the state is rendered **unusable**.
- `state:isDestroyed(): boolean`
  - Returns the state's destroyed state
- `state:setDebugName(name: string?): ()`
  - Sets the state's debug name to `name`. This can also be set to `nil` if you would like to disable debugging for that state.
- `state:getDebugName(): string?`
  - Get the current state's debug name, which can potentially be `nil`.

### Connection functions

Connections are returned when calling `state:connect(callback)`.

_It is assumed that the self type is equal to `Connection` in all situations_

- `connection:disconnect(): ()`
  - Disconnects the connection callback, meaning it'll no longer be called when `state:set(value)` is called
- `connection:isConnected(): boolean`
  - Returns whether the connection callback is connected to the state.

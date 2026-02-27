---------------------------------------------------------------------------------
-- history.lua - Undo/redo state stack
---------------------------------------------------------------------------------

local utils = require( "classes.utils" )
local deepCopy = utils.deepCopy

local M = {}

local states = {}
local currentIndex = 0
local maxStates = 50
-- When paused, push() is a no-op. Used during restoreState to avoid
-- pushing intermediate states back onto the stack.
local isPaused = false

function M.init()
    states = {}
    currentIndex = 0
end

function M.push( state, description )
    if isPaused then return end
    if type( state ) ~= "table" then return end
    if not state.emitterState or type( state.emitterState ) ~= "table" then return end
    if not state.objectOrder or type( state.objectOrder ) ~= "table" then return end

    -- Discard any redo states ahead of current position
    while #states > currentIndex do
        table.remove( states )
    end

    local entry = {
        state = deepCopy( state ),
        timestamp = os.time(),
        description = description or "Unknown change",
    }
    table.insert( states, entry )
    currentIndex = #states

    while #states > maxStates do
        table.remove( states, 1 )
        currentIndex = currentIndex - 1
    end

    M.notifyChange()
end

function M.undo()
    if currentIndex <= 1 then return nil end

    currentIndex = currentIndex - 1
    local entry = states[currentIndex]
    local state = deepCopy( entry.state )

    M.notifyChange()
    return state
end

function M.redo()
    if currentIndex >= #states then return nil end

    currentIndex = currentIndex + 1
    local entry = states[currentIndex]
    local state = deepCopy( entry.state )

    M.notifyChange()
    return state
end

function M.canUndo()
    return currentIndex > 1
end

function M.canRedo()
    return currentIndex < #states
end

function M.getCurrent()
    if currentIndex < 1 or currentIndex > #states then
        return nil
    end
    return deepCopy( states[currentIndex].state )
end

function M.clear()
    states = {}
    currentIndex = 0
    M.notifyChange()
end

function M.pause()
    isPaused = true
end

function M.resume()
    isPaused = false
end

function M.notifyChange()
    -- Lazy lookup avoids circular require (history is loaded before jsBridge)
    local jsBridge = package.loaded["classes.jsBridge"]
    if jsBridge then
        local currentEntry = states[currentIndex]
        local undoEntry = currentIndex > 1 and states[currentIndex - 1] or nil
        local redoEntry = currentIndex < #states and states[currentIndex + 1] or nil

        jsBridge.dispatchEvent( "historyChanged", {
            canUndo = M.canUndo(),
            canRedo = M.canRedo(),
            undoCount = currentIndex - 1,
            redoCount = #states - currentIndex,
            currentDescription = currentEntry and currentEntry.description or nil,
            undoDescription = undoEntry and undoEntry.description or nil,
            redoDescription = redoEntry and redoEntry.description or nil,
        })
    end
end

function M.getStats()
    return {
        totalStates = #states,
        currentIndex = currentIndex,
        canUndo = M.canUndo(),
        canRedo = M.canRedo(),
    }
end

return M

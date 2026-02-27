---------------------------------------------------------------------------------
-- jsBridge.lua
-- Lua <-> JavaScript communication for HTML5 builds.
-- Polls a JS command queue each frame; dispatches events to parent via parentBridge.
---------------------------------------------------------------------------------

if system.getInfo( "platform" ) ~= "html5" then
    return {
        init = function() end,
        dispatchEvent = function() end,
        registerHandler = function() end,
    }
end

local json = require( "json" )

local M = {}

local handlers = {}

local parentBridge = require( "parentBridge" )
local jsBridgeHost = require( "jsBridgeHost" )

local function processCommand( cmdJson )
    local ok, cmd = pcall( json.decode, cmdJson )
    if not ok then
        print( "jsBridge: Failed to decode command: " .. tostring( cmd ) )
        return
    end
    if not cmd or not cmd.method then return end

    local handler = handlers[cmd.method]
    if not handler then
        if cmd.id then
            M.dispatchEvent( "callLuaResponse", {
                id = cmd.id,
                error = "Unknown method: " .. tostring( cmd.method ),
            } )
        end
        return
    end

    local args = cmd.args or {}

    local handleOk, result = pcall( function()
        if type( args ) == "table" and #args > 0 then
            return handler( unpack( args ) )
        else
            return handler( args )
        end
    end )

    if cmd.id then
        if handleOk then
            M.dispatchEvent( "callLuaResponse", {
                id = cmd.id,
                result = result,
            } )
        else
            M.dispatchEvent( "callLuaResponse", {
                id = cmd.id,
                error = tostring( result ),
            } )
        end
    end
end

local MAX_COMMANDS_PER_FRAME = 20

local function onEnterFrame()
    local count = 0
    while jsBridgeHost.hasPending() == 1 and count < MAX_COMMANDS_PER_FRAME do
        local cmdJson = jsBridgeHost.dequeue()
        if cmdJson and cmdJson ~= "" then
            processCommand( cmdJson )
        end
        count = count + 1
    end
end

Runtime:addEventListener( "enterFrame", onEnterFrame )

function M.init( handlerTable )
    handlers = handlerTable or {}
end

function M.registerHandler( method, handler )
    handlers[method] = handler
end

function M.dispatchEvent( eventName, data )
    local eventData = {
        name = eventName,
        data = data or {},
    }

    local jsonStr = json.encode( eventData )
    parentBridge.dispatchToParent( jsonStr )
end

return M

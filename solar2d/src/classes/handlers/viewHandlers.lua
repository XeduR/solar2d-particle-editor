---------------------------------------------------------------------------------
-- viewHandlers.lua - View/preview control handlers
---------------------------------------------------------------------------------

local M = {}

function M.create( deps )
    local emitterManager = deps.emitterManager
    local imageManager = deps.imageManager
    local history = deps.history
    local screen = deps.screen

    return {
        -- Reverts to previous history state. Dispatches stateRestored event
        undo = function()
            local state = history.undo()
            if state then
                history.pause()
                deps.restoreFullState( state )
                history.resume()

                deps.refreshAllIndicators()

                deps.jsBridge.dispatchEvent( "stateRestored", {
                    objects = deps.getObjectList(),
                    selectedId = deps.getSelectedId(),
                    selectedType = deps.getSelectedType(),
                    params = deps.getSelectedType() == "emitter" and emitterManager.getParams( deps.getSelectedId() ) or nil,
                    textureInfo = deps.getSelectedType() == "emitter" and emitterManager.getTextureInfo( deps.getSelectedId() ) or nil,
                    imageProperties = deps.getSelectedType() == "image" and imageManager.getProperties( deps.getSelectedId() ) or nil,
                } )
            end
        end,

        -- Advances to next history state. Dispatches stateRestored event
        redo = function()
            local state = history.redo()
            if state then
                history.pause()
                deps.restoreFullState( state )
                history.resume()

                deps.refreshAllIndicators()

                deps.jsBridge.dispatchEvent( "stateRestored", {
                    objects = deps.getObjectList(),
                    selectedId = deps.getSelectedId(),
                    selectedType = deps.getSelectedType(),
                    params = deps.getSelectedType() == "emitter" and emitterManager.getParams( deps.getSelectedId() ) or nil,
                    textureInfo = deps.getSelectedType() == "emitter" and emitterManager.getTextureInfo( deps.getSelectedId() ) or nil,
                    imageProperties = deps.getSelectedType() == "image" and imageManager.getProperties( deps.getSelectedId() ) or nil,
                } )
            end
        end,

        -- Centers the selected object in the current view
        resetPosition = function()
            local canvasGroup = deps.getCanvasGroup()
            local cx, cy = canvasGroup:contentToLocal( screen.centerX, screen.centerY )
            if deps.getSelectedType() == "emitter" then
                emitterManager.setPreviewPosition( cx, cy )
            elseif deps.getSelectedType() == "image" and deps.getSelectedId() then
                imageManager.setProperty( deps.getSelectedId(), "x", cx )
                imageManager.setProperty( deps.getSelectedId(), "y", cy )
            end
            deps.refreshAllIndicators()
        end,

        -- Sets grid overlay size (clamped 8-128)
        setGridSize = function( size )
            size = tonumber( size ) or 40
            if size < 8 then size = 8 end
            if size > 128 then size = 128 end
            deps.setGridSize( size )
        end,

        -- Toggles grid overlay visibility
        setGridEnabled = function( enabled )
            deps.setGridEnabled( enabled == true or enabled == "true" )
        end,

        -- Sets emitter bounds display mode: "hidden", "active", or "all"
        setEmitterBoundsMode = function( mode )
            if mode ~= "hidden" and mode ~= "active" and mode ~= "all" then
                mode = "hidden"
            end
            deps.setEmitterBoundsMode( mode )
        end,

        -- Sets canvas background color
        setBackgroundColor = function( r, g, b )
            r = tonumber( r ) or 0.1
            g = tonumber( g ) or 0.1
            b = tonumber( b ) or 0.12
            deps.setBackgroundColorFn( r, g, b )
        end,

        -- Sets grid line color
        setGridColor = function( r, g, b )
            r = tonumber( r ) or 0.2
            g = tonumber( g ) or 0.2
            b = tonumber( b ) or 0.22
            deps.setGridColor( r, g, b )
        end,

        -- Sets emitter bounds indicator color
        setBoundsColor = function( r, g, b )
            r = tonumber( r ) or 1
            g = tonumber( g ) or 1
            b = tonumber( b ) or 1
            deps.setBoundsColor( r, g, b )
        end,

        -- Prevents default emitter creation on startup
        skipDefaultEmitter = function()
            deps.setSkipDefaultEmitter( true )
        end,

        -- Pauses all active emitters
        pauseEmitters = function()
            emitterManager.pauseEmitters()
        end,

        -- Resumes all paused emitters
        resumeEmitters = function()
            emitterManager.resumeEmitters()
        end,

        -- Restarts all emitters from beginning
        restartEmitters = function()
            emitterManager.restartEmitters()
        end,

        -- Resets zoom to 1x and pan to (0,0)
        resetView = function()
            deps.resetViewFn()
        end,

        -- Signals parent page is ready. Triggers sendReady
        parentReady = function()
            deps.sendReady()
        end,

        -- Removes all temporary image files from system.TemporaryDirectory
        clearTempFiles = function()
            local lfs = require( "lfs" )
            local tempPath = system.pathForFile( "", system.TemporaryDirectory )
            if not tempPath then return end
            for file in lfs.dir( tempPath ) do
                if file ~= "." and file ~= ".." then
                    os.remove( system.pathForFile( file, system.TemporaryDirectory ) )
                end
            end
        end,
    }
end

return M

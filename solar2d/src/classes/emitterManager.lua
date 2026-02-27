---------------------------------------------------------------------------------
-- emitterManager.lua
---------------------------------------------------------------------------------

local json = require( "json" )
local screen = require( "classes.screen" )
local utils = require( "classes.utils" )
local deepCopy = utils.deepCopy

local M = {}

local canvasGroup = nil
local emitters = {}       -- id -> { emitter, params, name, textureBase64, textureFilename }
local emitterOrder = {}   -- ordered list of emitter IDs (determines display/list order)
local activeEmitterId = nil
local idCounter = 0
local isVisible = true
local isPaused = false
local replayTimers = {}

-- Avoids redundant base64 decode + file writes for unchanged textures
local textureCache = {}   -- filename -> hash string

-- Caches base64-encoded preset textures so repeated exports don't re-read files
local presetTextureCache = {}  -- filename -> base64 string

-- Used as the base for new emitters and as reset target for replaceAllParams()
local defaultParams = {
    maxParticles = 256,
    duration = -1,
    emitterType = 0,
    absolutePosition = true,
    angle = -90,
    angleVariance = 10,
    speed = 100,
    speedVariance = 30,
    sourcePositionVariancex = 0,
    sourcePositionVariancey = 0,
    particleLifespan = 1,
    particleLifespanVariance = 0.5,
    startParticleSize = 32,
    startParticleSizeVariance = 0,
    finishParticleSize = 16,
    finishParticleSizeVariance = 0,
    rotationStart = 0,
    rotationStartVariance = 0,
    rotationEnd = 0,
    rotationEndVariance = 0,
    startColorRed = 1,
    startColorGreen = 0.5,
    startColorBlue = 0.1,
    startColorAlpha = 1,
    startColorVarianceRed = 0,
    startColorVarianceGreen = 0,
    startColorVarianceBlue = 0,
    startColorVarianceAlpha = 0,
    finishColorRed = 1,
    finishColorGreen = 0.2,
    finishColorBlue = 0,
    finishColorAlpha = 0,
    finishColorVarianceRed = 0,
    finishColorVarianceGreen = 0,
    finishColorVarianceBlue = 0,
    finishColorVarianceAlpha = 0,
    gravityx = 0,
    gravityy = 0,
    radialAcceleration = 0,
    radialAccelVariance = 0,
    tangentialAcceleration = 0,
    tangentialAccelVariance = 0,
    maxRadius = 100,
    maxRadiusVariance = 0,
    minRadius = 0,
    minRadiusVariance = 0,
    rotatePerSecond = 0,
    rotatePerSecondVariance = 0,
    blendFuncSource = 770,    -- GL_SRC_ALPHA
    blendFuncDestination = 1, -- GL_ONE (additive blending)
    textureFileName = "assets/particles/basic_circle_01.png",
}

function M.getDefaultParams()
    return deepCopy( defaultParams )
end

local function generateId()
    idCounter = idCounter + 1
    return "emitter_" .. idCounter
end

local function ensureTextureFile( filename, base64 )
    if not filename or not base64 or base64 == "" then return false end

    local len = #base64
    local mid = math.floor( len / 2 )
    local hash = string.sub( base64, 1, 32 ) .. "_"
        .. string.sub( base64, mid + 1, mid + 32 ) .. "_"
        .. string.sub( base64, math.max( 1, len - 31 ), len ) .. "_" .. len
    if textureCache[filename] == hash then
        return true  -- Already written
    end

    local binaryData = utils.base64Decode( base64 )
    if not binaryData or #binaryData == 0 then return false end

    local pngHeader = "\137\080\078\071" -- 0x89 P N G
    if #binaryData < 8 or binaryData:sub( 1, 4 ) ~= pngHeader then
        print( "ensureTextureFile: Not a valid PNG file: " .. tostring( filename ) )
        return false
    end

    local success = utils.writeTempFile( filename, binaryData )
    if success then
        textureCache[filename] = hash
    end
    return success
end

-- Auto-replays finite-duration emitters so they loop in the preview
local function setupEmitterReplay( emitterId, params )
    if replayTimers[emitterId] then
        timer.cancel( replayTimers[emitterId] )
        replayTimers[emitterId] = nil
    end

    local duration = params.duration or 1
    local particleLifespan = params.particleLifespan or 1
    -- Wait for duration + particle fadeout + 500ms buffer before restarting
    local replayDelay = ( duration + particleLifespan ) * 1000 + 500

    replayTimers[emitterId] = timer.performWithDelay( replayDelay, function()
        local data = emitters[emitterId]
        if data and data.emitter then
            data.emitter:start()
            setupEmitterReplay( emitterId, data.params )
        end
    end )
end

local function cancelAllReplayTimers()
    for id, timerId in pairs( replayTimers ) do
        timer.cancel( timerId )
        replayTimers[id] = nil
    end
end

local function createEmitterDisplay( params, baseDir, emitterId )
    local emitterObj = display.newEmitter( params, baseDir )
    if canvasGroup then
        canvasGroup:insert( emitterObj )
    end
    emitterObj.x = screen.centerX
    emitterObj.y = screen.centerY
    -- Solar2D ignores absolutePosition in the constructor table; must be set on the instance
    if params.absolutePosition ~= nil then
        emitterObj.absolutePosition = params.absolutePosition
    end

    if emitterId and params.duration and params.duration > 0 then
        setupEmitterReplay( emitterId, params )
    end

    return emitterObj
end

local function recreateEmitter( id )
    local data = emitters[id]
    if not data then return end

    local oldX = data.emitter.x or screen.centerX
    local oldY = data.emitter.y or screen.centerY

    -- Remember the z-order index within the parent group before removing
    local oldIndex = nil
    local parent = data.emitter.parent
    if parent then
        for i = 1, parent.numChildren do
            if parent[i] == data.emitter then
                oldIndex = i
                break
            end
        end
    end

    if replayTimers[id] then
        timer.cancel( replayTimers[id] )
        replayTimers[id] = nil
    end

    -- Custom textures live in TemporaryDirectory; built-in textures use ResourceDirectory (nil)
    local baseDir = nil
    if data.textureBase64 and data.textureBase64 ~= "" then
        ensureTextureFile( data.textureFilename, data.textureBase64 )
        baseDir = system.TemporaryDirectory
    end

    data.emitter:removeSelf()
    data.emitter = createEmitterDisplay( data.params, baseDir, id )
    data.emitter.x = oldX
    data.emitter.y = oldY
    data.emitter.isVisible = isVisible

    -- Restore z-order position within the parent group
    if oldIndex and parent and oldIndex <= parent.numChildren then
        parent:insert( oldIndex, data.emitter )
    end

    if isPaused then
        data.emitter:pause()
        if replayTimers[id] then
            timer.cancel( replayTimers[id] )
            replayTimers[id] = nil
        end
    end
end

---------------------------------------------------------------------------------
-- Public API
---------------------------------------------------------------------------------

function M.init( group )
    canvasGroup = group
end

function M.createEmitter( templateParams, name )
    local id = generateId()
    local params = deepCopy( defaultParams )

    if templateParams then
        for k, v in pairs( templateParams ) do
            params[k] = v
        end
    end

    local emitterObj = createEmitterDisplay( params, nil, id )
    emitterObj.isVisible = isVisible

    if isPaused then
        emitterObj:pause()
        if replayTimers[id] then
            timer.cancel( replayTimers[id] )
            replayTimers[id] = nil
        end
    end

    name = name or ( "Emitter " .. idCounter )

    emitters[id] = {
        emitter = emitterObj,
        params = params,
        name = name,
        textureBase64 = nil,
        textureFilename = params.textureFileName,
    }

    emitterOrder[#emitterOrder + 1] = id

    return { id = id, name = name }
end

function M.removeEmitter( id )
    if not emitters[id] then return false end

    if replayTimers[id] then
        timer.cancel( replayTimers[id] )
        replayTimers[id] = nil
    end

    emitters[id].emitter:removeSelf()
    emitters[id] = nil

    for i = #emitterOrder, 1, -1 do
        if emitterOrder[i] == id then
            table.remove( emitterOrder, i )
            break
        end
    end

    if activeEmitterId == id then
        activeEmitterId = emitterOrder[1] or nil
    end

    return true
end

function M.duplicateEmitter( id )
    if not emitters[id] then return nil end

    local sourceData = emitters[id]
    local newParams = deepCopy( sourceData.params )
    local newName = sourceData.name .. " (copy)"

    local result = M.createEmitter( newParams, newName )

    if result and emitters[result.id] then
        emitters[result.id].textureBase64 = sourceData.textureBase64
        emitters[result.id].textureFilename = sourceData.textureFilename

        if sourceData.textureBase64 and sourceData.textureBase64 ~= "" then
            recreateEmitter( result.id )
        end
    end

    return result
end

function M.selectEmitter( id )
    if not emitters[id] then return false end
    activeEmitterId = id
    return true
end

function M.renameEmitter( id, name )
    if not emitters[id] then return false end
    emitters[id].name = name
    return true
end

function M.getName( id )
    id = id or activeEmitterId
    if not emitters[id] then return nil end
    return emitters[id].name
end

function M.setParam( id, key, value )
    id = id or activeEmitterId
    if not emitters[id] then return false end

    emitters[id].params[key] = value

    if key == "textureFileName" then
        emitters[id].textureBase64 = nil
        emitters[id].textureFilename = value
    end

    recreateEmitter( id )
    return true
end

function M.setParams( id, params )
    id = id or activeEmitterId
    if not emitters[id] then return false end

    for k, v in pairs( params ) do
        emitters[id].params[k] = v
    end

    recreateEmitter( id )
    return true
end

-- Resets to defaults before overlaying new params (used for template loading)
function M.replaceAllParams( id, params )
    id = id or activeEmitterId
    if not emitters[id] then return false end

    emitters[id].params = deepCopy( defaultParams )

    if params then
        for k, v in pairs( params ) do
            emitters[id].params[k] = v
        end
    end

    emitters[id].textureBase64 = nil
    emitters[id].textureFilename = emitters[id].params.textureFileName

    recreateEmitter( id )
    return true
end

function M.setTexture( id, base64, filename )
    id = id or activeEmitterId
    if not emitters[id] then return false end

    base64 = base64:gsub( "^data:image/[%w+]+;base64,", "" )

    local success = ensureTextureFile( filename, base64 )
    if not success then
        print( "setTexture: Failed to decode/write texture: " .. tostring( filename ) )
        return false
    end

    emitters[id].textureBase64 = base64
    emitters[id].textureFilename = filename
    emitters[id].params.textureFileName = filename

    recreateEmitter( id )
    return true
end

function M.getActiveEmitter()
    if activeEmitterId and emitters[activeEmitterId] then
        return emitters[activeEmitterId].emitter
    end
    return nil
end

function M.getActiveEmitterId()
    return activeEmitterId
end

function M.getParams( id )
    id = id or activeEmitterId
    if not emitters[id] then return nil end
    return deepCopy( emitters[id].params )
end

function M.getTextureInfo( id )
    id = id or activeEmitterId
    if not emitters[id] then return nil end

    local data = emitters[id]
    return {
        textureFileName = data.params.textureFileName,
        textureFilename = data.textureFilename,
        hasCustomTexture = ( data.textureBase64 ~= nil and data.textureBase64 ~= "" ),
    }
end

function M.getEmitterList()
    local list = {}
    for _, id in ipairs( emitterOrder ) do
        local data = emitters[id]
        if data then
            list[#list + 1] = {
                id = id,
                name = data.name,
                selected = ( id == activeEmitterId ),
            }
        end
    end
    return list
end

function M.getDisplayObject( id )
    if not emitters[id] then return nil end
    return emitters[id].emitter
end

function M.setPreviewPosition( x, y )
    if activeEmitterId then
        local data = emitters[activeEmitterId]
        if data and data.emitter then
            data.emitter.x = x
            data.emitter.y = y
        end
    end
end

function M.setEmitterPosition( id, x, y )
    id = id or activeEmitterId
    if not emitters[id] then return false end
    local data = emitters[id]
    if data.emitter then
        data.emitter.x = x
        data.emitter.y = y
    end
    return true
end

function M.show()
    isVisible = true
    for _, id in ipairs( emitterOrder ) do
        local data = emitters[id]
        if data and data.emitter then
            data.emitter.isVisible = true
        end
    end
end

function M.hide()
    isVisible = false
    for _, id in ipairs( emitterOrder ) do
        local data = emitters[id]
        if data and data.emitter then
            data.emitter.isVisible = false
        end
    end
end

function M.pauseEmitters()
    isPaused = true
    cancelAllReplayTimers()

    for _, id in ipairs( emitterOrder ) do
        local data = emitters[id]
        if data and data.emitter then
            data.emitter:pause()
        end
    end
end

function M.resumeEmitters()
    isPaused = false
    for _, id in ipairs( emitterOrder ) do
        local data = emitters[id]
        if data and data.emitter then
            data.emitter:start()
            if data.params.duration and data.params.duration > 0 then
                setupEmitterReplay( id, data.params )
            end
        end
    end
end

function M.restartEmitters()
    isPaused = false
    for _, id in ipairs( emitterOrder ) do
        recreateEmitter( id )
    end
end

function M.isPaused()
    return isPaused
end

function M.reorderEmitter( id, newIndex )
    if newIndex < 1 then newIndex = 1 end
    if newIndex > #emitterOrder + 1 then newIndex = #emitterOrder + 1 end

    local currentIndex
    for i, eid in ipairs( emitterOrder ) do
        if eid == id then
            currentIndex = i
            break
        end
    end

    if not currentIndex or currentIndex == newIndex then
        return false
    end

    table.remove( emitterOrder, currentIndex )

    if currentIndex < newIndex then
        newIndex = newIndex - 1
    end

    table.insert( emitterOrder, newIndex, id )

    for _, eid in ipairs( emitterOrder ) do
        local data = emitters[eid]
        if data and data.emitter and data.emitter.parent then
            data.emitter:toFront()
        end
    end

    return true
end

---------------------------------------------------------------------------------
-- State Management (for undo/redo)
---------------------------------------------------------------------------------

function M.getState()
    local state = {
        emitters = {},
        order = deepCopy( emitterOrder ),
        activeId = activeEmitterId,
        isVisible = isVisible,
        isPaused = isPaused,
    }

    for id, data in pairs( emitters ) do
        state.emitters[id] = {
            params = deepCopy( data.params ),
            name = data.name,
            textureBase64 = data.textureBase64,
            textureFilename = data.textureFilename,
            x = data.emitter and data.emitter.x or screen.centerX,
            y = data.emitter and data.emitter.y or screen.centerY,
        }
    end

    return state
end

function M.restoreState( state )
    cancelAllReplayTimers()

    for _, id in ipairs( emitterOrder ) do
        local data = emitters[id]
        if data and data.emitter then
            data.emitter:removeSelf()
        end
    end

    emitters = {}
    emitterOrder = {}

    emitterOrder = deepCopy( state.order )
    activeEmitterId = state.activeId

    for _, id in ipairs( emitterOrder ) do
        local savedData = state.emitters[id]
        if savedData then
            local params = deepCopy( savedData.params )

            local baseDir = nil
            if savedData.textureBase64 and savedData.textureBase64 ~= "" then
                ensureTextureFile( savedData.textureFilename, savedData.textureBase64 )
                baseDir = system.TemporaryDirectory
            end

            local emitterObj = createEmitterDisplay( params, baseDir, id )
            emitterObj.isVisible = isVisible

            emitterObj.x = savedData.x or screen.centerX
            emitterObj.y = savedData.y or screen.centerY

            emitters[id] = {
                emitter = emitterObj,
                params = params,
                name = savedData.name,
                textureBase64 = savedData.textureBase64,
                textureFilename = savedData.textureFilename,
            }

            local numPart = tonumber( id:match( "emitter_(%d+)" ) )
            if numPart and numPart >= idCounter then
                idCounter = numPart
            end
        end
    end

    if state.isVisible == false then
        M.hide()
    else
        isVisible = true
    end

    if state.isPaused then
        M.pauseEmitters()
    else
        isPaused = false
    end
end

---------------------------------------------------------------------------------
-- Export Functions
---------------------------------------------------------------------------------

function M.exportEmitter( id, includeTextures )
    id = id or activeEmitterId
    if not emitters[id] then return nil end

    local data = emitters[id]
    local textureBase64 = data.textureBase64

    -- For preset textures, read from ResourceDirectory and base64-encode on demand
    if includeTextures and ( not textureBase64 or textureBase64 == "" ) and data.textureFilename then
        if presetTextureCache[data.textureFilename] then
            textureBase64 = presetTextureCache[data.textureFilename]
        else
            local binaryData = utils.readBinaryFile( data.textureFilename, system.ResourceDirectory )
            if binaryData then
                textureBase64 = utils.base64Encode( binaryData )
                presetTextureCache[data.textureFilename] = textureBase64
            end
        end
    end

    return {
        id = id,
        name = data.name,
        params = deepCopy( data.params ),
        x = data.emitter and data.emitter.x or screen.centerX,
        y = data.emitter and data.emitter.y or screen.centerY,
        textureBase64 = textureBase64,
        textureFilename = data.textureFilename,
    }
end

function M.exportAll( includeTextures )
    local result = {}
    for _, id in ipairs( emitterOrder ) do
        result[#result + 1] = M.exportEmitter( id, includeTextures )
    end
    return result
end

return M

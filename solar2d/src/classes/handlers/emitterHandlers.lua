---------------------------------------------------------------------------------
-- emitterHandlers.lua - Emitter CRUD and parameter management handlers
---------------------------------------------------------------------------------

local M = {}

function M.create( deps )
    local emitterManager = deps.emitterManager
    local history = deps.history
    local templates = deps.templates

    return {
        -- createEmitter( [templateId] ) - Creates a new emitter, optionally from a template. Returns { id, name, params }.
        createEmitter = function( templateId )
            local templateData = nil
            local name = nil
            if templateId and templateId ~= "" and templates.exists( templateId ) then
                templateData = templates.get( templateId )
                name = templateId:sub( 1, 1 ):upper() .. templateId:sub( 2 )
            end
            local result = emitterManager.createEmitter( templateData, name )
            deps.addToObjectOrder( result.id, "emitter" )
            deps.selectObject( result.id, "emitter" )
            deps.applyZOrder()
            deps.refreshIndicator( result.id, nil )
            history.push( deps.getFullState(), "Create emitter" )

            deps.dispatchObjectListChanged()
            deps.dispatchObjectSelected()

            return result
        end,

        -- removeEmitter( id ) - Removes an emitter by ID. Selects next object if current was removed.
        removeEmitter = function( id )
            local success = emitterManager.removeEmitter( id )
            if success then
                deps.removeFromObjectOrder( id )

                if deps.getSelectedId() == id then
                    local orderCount = deps.getObjectCount()
                    if orderCount > 0 then
                        local nextObj = deps.getObjectOrderEntry( 1 )
                        deps.selectObject( nextObj.id, nextObj.type )
                    else
                        deps.setSelectedId( nil )
                        deps.setSelectedType( nil )
                    end
                end
                deps.refreshAllIndicators()

                history.push( deps.getFullState(), "Remove emitter" )
                deps.dispatchObjectListChanged()
                deps.dispatchObjectSelected()
            end
            return success
        end,

        -- duplicateEmitter( id ) - Creates a copy of an emitter with all its parameters.
        duplicateEmitter = function( id )
            local result = emitterManager.duplicateEmitter( id )
            if result then
                deps.addToObjectOrder( result.id, "emitter" )
                deps.selectObject( result.id, "emitter" )
                deps.applyZOrder()
                deps.refreshIndicator( result.id, nil )
                history.push( deps.getFullState(), "Duplicate emitter" )
                deps.dispatchObjectListChanged()
                deps.dispatchObjectSelected()
            end
            return result
        end,

        -- setParam( id, key, value ) - Sets a single emitter parameter and commits to history.
        setParam = function( id, key, value )
            local success = emitterManager.setParam( id, key, value )
            if success then
                deps.refreshIndicator( id, key )
                history.push( deps.getFullState(), "Set parameter: " .. tostring( key ) )
            end
            return success
        end,

        -- setParams( id, params ) - Sets multiple emitter parameters at once and commits to history.
        setParams = function( id, params )
            local success = emitterManager.setParams( id, params )
            if success then
                deps.refreshIndicator( id, nil )
                history.push( deps.getFullState(), "Set parameters" )
            end
            return success
        end,

        -- setParamPreview( id, key, value ) - Sets a parameter for live preview without history commit.
        setParamPreview = function( id, key, value )
            local success = emitterManager.setParam( id, key, value )
            if success then
                deps.refreshIndicator( id, key )
            end
            return success
        end,

        -- setParamsPreview( id, params ) - Sets multiple parameters for live preview without history commit.
        setParamsPreview = function( id, params )
            local success = emitterManager.setParams( id, params )
            if success then
                deps.refreshIndicator( id, nil )
            end
            return success
        end,

        -- commitParams() - Commits the current preview state to history.
        commitParams = function()
            history.push( deps.getFullState(), "Adjust parameter" )
        end,

        -- setTexture( id, base64, filename ) - Sets a custom texture from base64 data. Pushes to history.
        setTexture = function( id, base64, filename )
            local success = emitterManager.setTexture( id, base64, filename )
            if success then
                history.push( deps.getFullState(), "Set texture" )
            end
            return success
        end,

        -- loadTemplate( templateId ) - Loads a template into the active emitter, replacing all params.
        loadTemplate = function( templateId )
            local templateData = templates.get( templateId )
            if templateData then
                local activeId = emitterManager.getActiveEmitterId()
                if activeId then
                    emitterManager.replaceAllParams( activeId, templateData )
                    deps.refreshIndicator( activeId, nil )
                    history.push( deps.getFullState(), "Load template" )

                    deps.jsBridge.dispatchEvent( "objectSelected", {
                        id = activeId,
                        type = "emitter",
                        name = emitterManager.getName( activeId ),
                        params = emitterManager.getParams( activeId ),
                        textureInfo = emitterManager.getTextureInfo( activeId ),
                    } )
                end
            end
            return templateData ~= nil
        end,

        -- setEmitterPosition( id, x, y ) - Sets the display position of an emitter.
        setEmitterPosition = function( id, x, y )
            return emitterManager.setEmitterPosition( id, tonumber( x ), tonumber( y ) )
        end,

        -- getEmitterList() - Returns the list of all emitters.
        getEmitterList = function()
            return emitterManager.getEmitterList()
        end,

        -- getEmitterParams( id ) - Returns parameter values for a specific emitter.
        getEmitterParams = function( id )
            return emitterManager.getParams( id )
        end,

        -- getTextureInfo( id ) - Returns texture info (filename, base64) for an emitter.
        getTextureInfo = function( id )
            return emitterManager.getTextureInfo( id )
        end,

        -- getTemplateList() - Returns the list of available templates.
        getTemplateList = function()
            return templates.getList()
        end,
    }
end

return M

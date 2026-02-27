---------------------------------------------------------------------------------
-- sceneHandlers.lua - Scene/object management handlers
---------------------------------------------------------------------------------

local M = {}

function M.create( deps )
    local emitterManager = deps.emitterManager
    local imageManager = deps.imageManager
    local history = deps.history

    return {
        -- Selects an emitter or image by ID and type. Updates indicator
        selectObject = function( id, objType )
            if objType == "emitter" then
                local success = emitterManager.selectEmitter( id )
                if not success then return false end
            elseif objType == "image" then
                local success = imageManager.selectImage( id )
                if not success then return false end
            end
            deps.selectObject( id, objType )
            deps.dispatchObjectSelected()

            deps.refreshAllIndicators()
            return true
        end,

        -- Renames an emitter or image. Dispatches objectListChanged
        renameObject = function( id, name, objType )
            local success
            if objType == "emitter" then
                success = emitterManager.renameEmitter( id, name )
            else
                success = imageManager.renameImage( id, name )
            end
            if success then
                history.push( deps.getFullState(), "Rename " .. tostring( objType ) )
                deps.dispatchObjectListChanged()
            end
            return success
        end,

        -- Moves an object to a new position in scene order
        reorderObject = function( id, newIndex )
            newIndex = tonumber( newIndex )
            if not id or not newIndex then return end

            local success = deps.reorderObject( id, newIndex )
            if success then
                deps.dispatchObjectListChanged()
                history.push( deps.getFullState(), "Reorder object" )
            end
        end,

        -- Returns combined list of all objects in scene order
        getObjectList = function()
            return deps.getObjectList()
        end,

        -- Returns all objects in scene order as exportable scene data
        getSceneData = function()
            local objects = {}
            local count = deps.getObjectCount()
            for i = 1, count do
                local entry = deps.getObjectOrderEntry( i )
                if entry.type == "emitter" then
                    local exported = emitterManager.exportEmitter( entry.id, true )
                    if exported then
                        exported.type = "emitter"
                        objects[#objects + 1] = exported
                    end
                elseif entry.type == "image" then
                    local imgData = deps.imageManager.exportImage( entry.id )
                    if imgData then
                        imgData.type = "image"
                        objects[#objects + 1] = imgData
                    end
                end
            end
            return { objects = objects }
        end,

        -- Returns export data for one or all emitters
        getExportData = function( id, includeTextures )
            if id == "all" then
                return emitterManager.exportAll( includeTextures )
            else
                return emitterManager.exportEmitter( id, includeTextures )
            end
        end,

        -- Removes all emitters and images from the scene
        clearAllObjects = function()
            local emList = emitterManager.getEmitterList()
            for _, em in ipairs( emList ) do
                emitterManager.removeEmitter( em.id )
            end
            imageManager.removeAll()

            deps.clearObjectOrder()
            deps.setSelectedId( nil )
            deps.setSelectedType( nil )
            history.clear()
            history.push( deps.getFullState(), "Clear all objects" )
        end,

        -- Backward-compatible alias for selectObject with type="emitter"
        selectEmitter = function( id )
            local success = emitterManager.selectEmitter( id )
            if success then
                deps.selectObject( id, "emitter" )
                deps.dispatchObjectSelected()
            end
            return success
        end,

        -- Backward-compatible alias for renameObject with type="emitter"
        renameEmitter = function( id, name )
            local success = emitterManager.renameEmitter( id, name )
            if success then
                history.push( deps.getFullState(), "Rename emitter" )
                deps.dispatchObjectListChanged()
            end
            return success
        end,

        -- Backward-compatible alias for reorderObject
        reorderEmitter = function( id, newIndex )
            newIndex = tonumber( newIndex )
            if not id or not newIndex then return end

            local success = deps.reorderObject( id, newIndex )
            if success then
                deps.dispatchObjectListChanged()
                history.push( deps.getFullState(), "Reorder emitter" )
            end
        end,
    }
end

return M

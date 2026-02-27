---------------------------------------------------------------------------------
-- imageHandlers.lua - Image CRUD and property management handlers
---------------------------------------------------------------------------------

local M = {}

function M.create( deps )
    local imageManager = deps.imageManager
    local history = deps.history

    return {
        -- Creates a new image object from base64 data
        createImage = function( base64Data, filename, name, width, height )
            width = tonumber( width )
            height = tonumber( height )
            local result = imageManager.createImage( base64Data, filename, name, width, height )
            if result then
                deps.addToObjectOrder( result.id, "image" )
                deps.selectObject( result.id, "image" )
                deps.applyZOrder()
                history.push( deps.getFullState(), "Create image" )
                deps.dispatchObjectListChanged()
                deps.dispatchObjectSelected()
            end
            return result
        end,

        -- Removes an image by ID. Selects next object if current was removed
        removeImage = function( id )
            local success = imageManager.removeImage( id )
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

                history.push( deps.getFullState(), "Remove image" )
                deps.dispatchObjectListChanged()
                deps.dispatchObjectSelected()
            end
            return success
        end,

        -- Creates a copy of an image with all its properties
        duplicateImage = function( id )
            local result = imageManager.duplicateImage( id )
            if result then
                deps.addToObjectOrder( result.id, "image" )
                deps.selectObject( result.id, "image" )
                deps.applyZOrder()
                history.push( deps.getFullState(), "Duplicate image" )
                deps.dispatchObjectListChanged()
                deps.dispatchObjectSelected()
            end
            return result
        end,

        -- Replaces image content with new data
        replaceImage = function( id, base64Data, filename, name, width, height )
            width = tonumber( width )
            height = tonumber( height )
            local success = imageManager.replaceImage( id, base64Data, filename, name, width, height )
            if success then
                deps.applyZOrder()
                history.push( deps.getFullState(), "Replace image" )
                deps.dispatchObjectListChanged()
                deps.dispatchObjectSelected()
            end
            return success
        end,

        -- Sets an image property (x, y, scale, opacity) and commits to history
        setImageProperty = function( id, key, value )
            local success = imageManager.setProperty( id, key, tonumber( value ) )
            if success then
                history.push( deps.getFullState(), "Set image " .. tostring( key ) )
            end
            return success
        end,

        -- Sets an image property for live preview without history commit
        setImagePropertyPreview = function( id, key, value )
            return imageManager.setProperty( id, key, tonumber( value ) )
        end,
    }
end

return M

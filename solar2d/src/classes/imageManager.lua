---------------------------------------------------------------------------------
-- imageManager.lua
---------------------------------------------------------------------------------

local screen = require( "classes.screen" )
local utils = require( "classes.utils" )
local deepCopy = utils.deepCopy

local M = {}

local canvasGroup = nil
local jsBridge = nil
local images = {}         -- id -> { displayObj, name, imageBase64, filename, width, height, x, y, scale, opacity }
local imageOrder = {}     -- ordered list of image IDs (determines display/list order)
local activeImageId = nil
local idCounter = 0
local onImageTouched = nil
local tempFileCounter = 0

local function generateId()
    idCounter = idCounter + 1
    return "image_" .. idCounter
end

local function createImageDisplay( base64Data, filename, width, height )
    -- Strip data URL prefix if present
    base64Data = base64Data:gsub( "^data:image/[%w+]+;base64,", "" )

    local binaryData = utils.base64Decode( base64Data )
    if not binaryData or #binaryData == 0 then
        print( "imageManager: Failed to decode base64 data" )
        return nil
    end

    local pngHeader = "\137\080\078\071" -- 0x89 P N G
    if #binaryData < 8 or binaryData:sub( 1, 4 ) ~= pngHeader then
        print( "imageManager: Not a valid PNG file, skipping" )
        return nil
    end

    tempFileCounter = tempFileCounter + 1
    local tempFilename = "_img_" .. tempFileCounter .. ".png"
    local success = utils.writeTempFile( tempFilename, binaryData )
    if not success then
        print( "imageManager: Failed to write temp file" )
        return nil
    end

    -- pcall: display.newImageRect crashes the WASM runtime on corrupt PNG data
    width = width or 200
    height = height or 200
    local ok, img = pcall( display.newImageRect, tempFilename, system.TemporaryDirectory, width, height )
    if ok and img then
        img.x = screen.centerX
        img.y = screen.centerY
        if canvasGroup then
            canvasGroup:insert( img )
        end
        return img
    else
        print( "imageManager: Failed to load image - " .. tostring( img ) )
        return nil
    end
end

local function addTouchListener( id )
    local data = images[id]
    if not data or not data.displayObj then return end

    local isDragging = false
    local dragOffsetX = 0
    local dragOffsetY = 0

    data.displayObj:addEventListener( "touch", function( event )
        if event.phase == "began" then
            isDragging = true
            local localX, localY = canvasGroup:contentToLocal( event.x, event.y )
            dragOffsetX = localX - data.displayObj.x
            dragOffsetY = localY - data.displayObj.y
            display.getCurrentStage():setFocus( event.target )

            if onImageTouched then
                onImageTouched( id )
            end

        elseif event.phase == "moved" and isDragging then
            local localX, localY = canvasGroup:contentToLocal( event.x, event.y )
            data.displayObj.x = localX - dragOffsetX
            data.displayObj.y = localY - dragOffsetY
            data.x = data.displayObj.x
            data.y = data.displayObj.y

        elseif event.phase == "ended" or event.phase == "cancelled" then
            isDragging = false
            data.x = data.displayObj.x
            data.y = data.displayObj.y
            display.getCurrentStage():setFocus( nil )

            -- Notify JS of position change
            if jsBridge and id == activeImageId then
                jsBridge.dispatchEvent( "imagePropertyChanged", {
                    id = id,
                    x = data.x,
                    y = data.y,
                    scale = data.scale,
                    opacity = data.opacity,
                } )
            end
        end
        return true
    end )
end

---------------------------------------------------------------------------------
-- Public API
---------------------------------------------------------------------------------

function M.init( group, bridge )
    canvasGroup = group
    jsBridge = bridge
end

function M.setOnImageTouched( callback )
    onImageTouched = callback
end

function M.createImage( base64Data, filename, name, width, height )
    local id = generateId()

    local displayObj = createImageDisplay( base64Data, filename, width, height )
    if not displayObj then
        return nil
    end

    name = name or ( "Image " .. idCounter )

    images[id] = {
        displayObj = displayObj,
        name = name,
        imageBase64 = base64Data:gsub( "^data:image/[%w+]+;base64,", "" ),
        filename = filename or ( "image_" .. idCounter .. ".png" ),
        width = width or displayObj.width,
        height = height or displayObj.height,
        x = displayObj.x,
        y = displayObj.y,
        scale = 1,
        opacity = 1,
    }

    imageOrder[#imageOrder + 1] = id
    addTouchListener( id )

    return { id = id, name = name }
end

function M.removeImage( id )
    if not images[id] then return false end

    images[id].displayObj:removeSelf()
    images[id] = nil

    for i = #imageOrder, 1, -1 do
        if imageOrder[i] == id then
            table.remove( imageOrder, i )
            break
        end
    end

    if activeImageId == id then
        activeImageId = nil
    end

    return true
end

function M.duplicateImage( id )
    if not images[id] then return nil end

    local sourceData = images[id]
    local result = M.createImage(
        sourceData.imageBase64,
        sourceData.filename,
        sourceData.name .. " (copy)",
        sourceData.width,
        sourceData.height
    )

    if result and images[result.id] then
        M.setProperty( result.id, "x", sourceData.x + 20 )
        M.setProperty( result.id, "y", sourceData.y + 20 )
        M.setProperty( result.id, "scale", sourceData.scale )
        M.setProperty( result.id, "opacity", sourceData.opacity )
    end

    return result
end

function M.replaceImage( id, base64Data, filename, name, width, height )
    if not images[id] then return false end

    local data = images[id]
    local oldX = data.x
    local oldY = data.y
    local oldScale = data.scale
    local oldOpacity = data.opacity

    -- Remove old display object
    data.displayObj:removeSelf()

    -- Strip data URL prefix if present
    base64Data = base64Data:gsub( "^data:image/[%w+]+;base64,", "" )

    -- Create new display object
    width = width or 200
    height = height or 200
    local displayObj = createImageDisplay( base64Data, filename, width, height )
    if not displayObj then
        -- Failed: try to restore old image
        displayObj = createImageDisplay( data.imageBase64, data.filename, data.width, data.height )
        if displayObj then
            displayObj.x = oldX
            displayObj.y = oldY
            displayObj.xScale = oldScale
            displayObj.yScale = oldScale
            displayObj.alpha = oldOpacity
            data.displayObj = displayObj
            addTouchListener( id )
        end
        return false
    end

    -- Apply preserved properties
    displayObj.x = oldX
    displayObj.y = oldY
    displayObj.xScale = oldScale
    displayObj.yScale = oldScale
    displayObj.alpha = oldOpacity

    -- Update data entry
    data.displayObj = displayObj
    data.imageBase64 = base64Data
    data.filename = filename or data.filename
    data.name = name or data.name
    data.width = width
    data.height = height

    -- Reattach touch listener
    addTouchListener( id )

    return true
end

function M.selectImage( id )
    if not images[id] then return false end
    activeImageId = id
    return true
end

function M.deselectImage()
    activeImageId = nil
end

function M.getActiveImageId()
    return activeImageId
end

function M.renameImage( id, name )
    if not images[id] then return false end
    images[id].name = name
    return true
end

function M.getName( id )
    if not images[id] then return nil end
    return images[id].name
end

function M.setProperty( id, key, value )
    if not images[id] then return false end

    local data = images[id]
    value = tonumber( value )
    if not value then return false end

    if key == "x" then
        data.x = value
        data.displayObj.x = value
    elseif key == "y" then
        data.y = value
        data.displayObj.y = value
    elseif key == "scale" then
        data.scale = value
        data.displayObj.xScale = value
        data.displayObj.yScale = value
    elseif key == "opacity" then
        data.opacity = value
        data.displayObj.alpha = value
    else
        return false
    end

    return true
end

function M.getProperties( id )
    if not images[id] then return nil end
    local data = images[id]
    return {
        x = data.x,
        y = data.y,
        scale = data.scale,
        opacity = data.opacity,
    }
end

function M.getImageList()
    local list = {}
    for _, id in ipairs( imageOrder ) do
        local data = images[id]
        if data then
            list[#list + 1] = {
                id = id,
                name = data.name,
                selected = ( id == activeImageId ),
            }
        end
    end
    return list
end

function M.getDisplayObject( id )
    if not images[id] then return nil end
    return images[id].displayObj
end

function M.reorderImage( id, newIndex )
    if newIndex < 1 then newIndex = 1 end
    if newIndex > #imageOrder + 1 then newIndex = #imageOrder + 1 end

    local currentIndex
    for i, iid in ipairs( imageOrder ) do
        if iid == id then
            currentIndex = i
            break
        end
    end

    if not currentIndex or currentIndex == newIndex then
        return false
    end

    table.remove( imageOrder, currentIndex )

    if currentIndex < newIndex then
        newIndex = newIndex - 1
    end

    table.insert( imageOrder, newIndex, id )
    return true
end

function M.removeAll()
    for _, id in ipairs( imageOrder ) do
        local data = images[id]
        if data and data.displayObj then
            data.displayObj:removeSelf()
        end
    end
    images = {}
    imageOrder = {}
    activeImageId = nil
end

---------------------------------------------------------------------------------
-- State Management (for undo/redo)
---------------------------------------------------------------------------------

function M.getState()
    local state = {
        images = {},
        order = deepCopy( imageOrder ),
        activeId = activeImageId,
    }

    for id, data in pairs( images ) do
        state.images[id] = {
            imageBase64 = data.imageBase64,
            filename = data.filename,
            name = data.name,
            width = data.width,
            height = data.height,
            x = data.x,
            y = data.y,
            scale = data.scale,
            opacity = data.opacity,
        }
    end

    return state
end

function M.restoreState( state )
    if not state then return end

    -- Remove all existing images
    for _, id in ipairs( imageOrder ) do
        local data = images[id]
        if data and data.displayObj then
            data.displayObj:removeSelf()
        end
    end

    images = {}
    imageOrder = {}

    imageOrder = deepCopy( state.order )
    activeImageId = state.activeId

    for _, id in ipairs( imageOrder ) do
        local savedData = state.images[id]
        if savedData then
            local displayObj = createImageDisplay(
                savedData.imageBase64,
                savedData.filename,
                savedData.width,
                savedData.height
            )

            if displayObj then
                displayObj.x = savedData.x or screen.centerX
                displayObj.y = savedData.y or screen.centerY
                displayObj.xScale = savedData.scale or 1
                displayObj.yScale = savedData.scale or 1
                displayObj.alpha = savedData.opacity or 1

                images[id] = {
                    displayObj = displayObj,
                    name = savedData.name,
                    imageBase64 = savedData.imageBase64,
                    filename = savedData.filename,
                    width = savedData.width,
                    height = savedData.height,
                    x = displayObj.x,
                    y = displayObj.y,
                    scale = savedData.scale or 1,
                    opacity = savedData.opacity or 1,
                }

                addTouchListener( id )

                local numPart = tonumber( id:match( "image_(%d+)" ) )
                if numPart and numPart >= idCounter then
                    idCounter = numPart
                end
            end
        end
    end
end

---------------------------------------------------------------------------------
-- Export (for scene save)
---------------------------------------------------------------------------------

function M.exportImage( id )
    if not images[id] then return nil end
    local data = images[id]
    return {
        id = id,
        name = data.name,
        imageBase64 = data.imageBase64,
        filename = data.filename,
        width = data.width,
        height = data.height,
        x = data.x,
        y = data.y,
        scale = data.scale,
        opacity = data.opacity,
    }
end

function M.exportAll()
    local result = {}
    for _, id in ipairs( imageOrder ) do
        result[#result + 1] = M.exportImage( id )
    end
    return result
end

return M

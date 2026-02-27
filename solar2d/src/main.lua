---------------------------------------------------------------------------------
-- main.lua - Application Entry Point
---------------------------------------------------------------------------------

display.setStatusBar( display.HiddenStatusBar )
display.setDefault( "background", 0.1, 0.1, 0.12 )

local platform = system.getInfo( "platform" )
local isHTML5 = ( platform == "html5" )

-- Manifests are generated at build time in Simulator so the HTML5 build
-- can fetch them at runtime (HTML5 has no filesystem access).
if not isHTML5 then
    require( "classes.manifestGenerator" )
end

local screen = require( "classes.screen" )
local utils = require( "classes.utils" )
local deepCopy = utils.deepCopy
local emitterManager = require( "classes.emitterManager" )
local imageManager = require( "classes.imageManager" )
local history = require( "classes.history" )
local templates = require( "classes.templates" )

local jsBridge
if isHTML5 then
    jsBridge = require( "classes.jsBridge" )
end

---------------------------------------------------------------------------------
-- Canvas Setup
---------------------------------------------------------------------------------

-- Objects group: zoomable and pannable, holds emitters + images
local groupObjects = display.newGroup()

local positionIndicator = display.newGroup()
groupObjects:insert( positionIndicator )

-- Grid overlay: never scales, never pans. Drawn in screen coordinates.
local groupGrid = display.newGroup()
local gridGroup = display.newGroup()
groupGrid:insert( gridGroup )

local borderRect = nil

local indicatorObjects = {}  -- display objects in positionIndicator group
local currentGridSize = 32
local emitterBoundsMode = "hidden"  -- "hidden", "active", "all"
local gridColor = { 0.2, 0.2, 0.22 }
local boundsColor = { 1, 1, 1 }

local function createGrid( gridSize )
    gridSize = gridSize or currentGridSize

    for i = gridGroup.numChildren, 1, -1 do
        gridGroup[i]:removeSelf()
    end

    if gridSize < 4 then return end

    local originX = screen.minX
    local originY = screen.minY
    local w = screen.width
    local h = screen.height
    local lineThickness = 1

    -- Vertical lines (2px wide rects)
    for x = originX, originX + w, gridSize do
        local rect = display.newRect( gridGroup, x, originY + h * 0.5, lineThickness, h )
        rect:setFillColor( gridColor[1], gridColor[2], gridColor[3] )
    end

    -- Horizontal lines (2px tall rects)
    for y = originY, originY + h, gridSize do
        local rect = display.newRect( gridGroup, originX + w * 0.5, y, w, lineThickness )
        rect:setFillColor( gridColor[1], gridColor[2], gridColor[3] )
    end
end

local function createBorder()
    if borderRect then
        borderRect:removeSelf()
        borderRect = nil
    end
    borderRect = display.newRect( groupGrid, screen.centerX, screen.centerY, screen.width, screen.height )
    borderRect:setFillColor( 0, 0, 0, 0 )
    borderRect:setStrokeColor( 0.35, 0.35, 0.4 )
    borderRect.strokeWidth = 4
end

local function setBackgroundColor( r, g, b )
    display.setDefault( "background", r, g, b )
end

local function clearIndicator()
    for i = #indicatorObjects, 1, -1 do
        if indicatorObjects[i] and indicatorObjects[i].removeSelf then
            indicatorObjects[i]:removeSelf()
        end
        indicatorObjects[i] = nil
    end
end

local function addIndicatorObj( obj )
    positionIndicator:insert( obj )
    indicatorObjects[#indicatorObjects + 1] = obj
end

-- Draws indicator shapes for a single emitter (additive — does not clear first)
local function drawEmitterIndicator( cx, cy, params )
    if not params then return end

    local emitterType = params.emitterType or 0

    if emitterType == 0 then
        -- Gravity emitter: source position variance rectangle
        local varX = ( params.sourcePositionVariancex or 0 ) * 2
        local varY = ( params.sourcePositionVariancey or 0 ) * 2

        if varX > 0 or varY > 0 then
            varX = math.max( varX, 2 )
            varY = math.max( varY, 2 )

            local rect = display.newRect( cx, cy, varX, varY )
            rect:setFillColor( boundsColor[1], boundsColor[2], boundsColor[3], 0.05 )
            rect:setStrokeColor( boundsColor[1], boundsColor[2], boundsColor[3], 0.3 )
            rect.strokeWidth = 1
            addIndicatorObj( rect )
        else
            -- Both variances are 0: show small crosshair as fallback
            local size = 6
            local hLine = display.newLine( cx - size, cy, cx + size, cy )
            hLine:setStrokeColor( boundsColor[1], boundsColor[2], boundsColor[3], 0.4 )
            hLine.strokeWidth = 1
            addIndicatorObj( hLine )

            local vLine = display.newLine( cx, cy - size, cx, cy + size )
            vLine:setStrokeColor( boundsColor[1], boundsColor[2], boundsColor[3], 0.4 )
            vLine.strokeWidth = 1
            addIndicatorObj( vLine )
        end

    elseif emitterType == 1 then
        -- Radial emitter: concentric circles for maxRadius and minRadius
        local maxR = params.maxRadius or 0
        local minR = params.minRadius or 0

        if maxR > 0 then
            local outerCircle = display.newCircle( cx, cy, maxR )
            outerCircle:setFillColor( 0, 0, 0, 0 )
            outerCircle:setStrokeColor( boundsColor[1], boundsColor[2], boundsColor[3], 0.3 )
            outerCircle.strokeWidth = 1
            addIndicatorObj( outerCircle )
        end

        if minR > 0 then
            local innerCircle = display.newCircle( cx, cy, minR )
            innerCircle:setFillColor( 0, 0, 0, 0 )
            innerCircle:setStrokeColor( boundsColor[1], boundsColor[2], boundsColor[3], 0.15 )
            innerCircle.strokeWidth = 1
            addIndicatorObj( innerCircle )
        end

        if maxR == 0 and minR == 0 then
            local dot = display.newCircle( cx, cy, 3 )
            dot:setFillColor( boundsColor[1], boundsColor[2], boundsColor[3], 0.5 )
            addIndicatorObj( dot )
        end
    end

    -- Angle/speed arrow (gravity emitters only)
    if emitterType == 0 then
        local angle = params.angle or 0
        local speed = params.speed or 0

        if speed > 0 then
            local lineLength = math.max( speed / 2, 10 )
            lineLength = math.min( lineLength, 200 )

            local rad = math.rad( angle )
            local endX = cx + math.cos( rad ) * lineLength
            local endY = cy + math.sin( rad ) * lineLength

            local dirLine = display.newLine( cx, cy, endX, endY )
            dirLine:setStrokeColor( boundsColor[1], boundsColor[2], boundsColor[3], 0.7 )
            dirLine.strokeWidth = 1
            addIndicatorObj( dirLine )

            -- Arrowhead
            local arrowSize = 6
            local arrowAngle1 = rad + math.rad( 150 )
            local arrowAngle2 = rad - math.rad( 150 )
            local ax1 = endX + math.cos( arrowAngle1 ) * arrowSize
            local ay1 = endY + math.sin( arrowAngle1 ) * arrowSize
            local ax2 = endX + math.cos( arrowAngle2 ) * arrowSize
            local ay2 = endY + math.sin( arrowAngle2 ) * arrowSize

            local arrow1 = display.newLine( endX, endY, ax1, ay1 )
            arrow1:setStrokeColor( boundsColor[1], boundsColor[2], boundsColor[3], 0.7 )
            arrow1.strokeWidth = 1
            addIndicatorObj( arrow1 )

            local arrow2 = display.newLine( endX, endY, ax2, ay2 )
            arrow2:setStrokeColor( boundsColor[1], boundsColor[2], boundsColor[3], 0.7 )
            arrow2.strokeWidth = 1
            addIndicatorObj( arrow2 )
        else
            -- Speed is 0: show a small dot
            local dot = display.newCircle( cx, cy, 3 )
            dot:setFillColor( boundsColor[1], boundsColor[2], boundsColor[3], 0.5 )
            addIndicatorObj( dot )
        end
    end
end

-- Clears and redraws indicator(s) based on current emitterBoundsMode
local function updateEmitterIndicator( cx, cy, params )
    clearIndicator()
    if emitterBoundsMode == "hidden" then return end
    drawEmitterIndicator( cx, cy, params )
end

-- Forward declaration; defined after objectOrder/selectedObjectId
local refreshAllIndicators

createGrid()
createBorder()
groupGrid.isVisible = false
groupGrid:toFront()

---------------------------------------------------------------------------------
-- Unified Object Order
---------------------------------------------------------------------------------

local objectOrder = {}     -- Array of { id = "emitter_1", type = "emitter" } or { id = "image_1", type = "image" }
local selectedObjectId = nil
local selectedObjectType = nil  -- "emitter" or "image"

-- Lookup for params that affect the indicator visualization
local indicatorParamKeys = {
    sourcePositionVariancex = true,
    sourcePositionVariancey = true,
    angle = true,
    speed = true,
    emitterType = true,
    maxRadius = true,
    minRadius = true,
}

local function refreshIndicator( id, changedKey )
    if changedKey and not indicatorParamKeys[changedKey] then return end
    if emitterBoundsMode == "all" then
        refreshAllIndicators()
    elseif emitterBoundsMode == "active" then
        if id == selectedObjectId and selectedObjectType == "emitter" then
            local emitter = emitterManager.getActiveEmitter()
            if emitter then
                updateEmitterIndicator( emitter.x, emitter.y, emitterManager.getParams( id ) )
            end
        end
    else
        clearIndicator()
    end
end

-- Redraws all emitter indicators (used for "show all" mode)
refreshAllIndicators = function()
    clearIndicator()
    if emitterBoundsMode == "hidden" then return end

    for _, entry in ipairs( objectOrder ) do
        if entry.type == "emitter" then
            local show = ( emitterBoundsMode == "all" )
                or ( emitterBoundsMode == "active" and entry.id == selectedObjectId )
            if show then
                local emObj = emitterManager.getDisplayObject( entry.id )
                local p = emitterManager.getParams( entry.id )
                if emObj and p then
                    drawEmitterIndicator( emObj.x, emObj.y, p )
                end
            end
        end
    end
    positionIndicator:toFront()
end

local function addToObjectOrder( id, objType )
    objectOrder[#objectOrder + 1] = { id = id, type = objType }
end

local function removeFromObjectOrder( id )
    for i = #objectOrder, 1, -1 do
        if objectOrder[i].id == id then
            table.remove( objectOrder, i )
            break
        end
    end
end

local function applyZOrder()
    for _, entry in ipairs( objectOrder ) do
        local displayObj
        if entry.type == "emitter" then
            displayObj = emitterManager.getDisplayObject( entry.id )
        else
            displayObj = imageManager.getDisplayObject( entry.id )
        end
        if displayObj and displayObj.parent then
            displayObj:toFront()
        end
    end
    positionIndicator:toFront()
end

local function reorderObject( id, newIndex )
    if newIndex < 1 then newIndex = 1 end
    if newIndex > #objectOrder + 1 then newIndex = #objectOrder + 1 end

    local currentIndex
    for i, entry in ipairs( objectOrder ) do
        if entry.id == id then
            currentIndex = i
            break
        end
    end

    if not currentIndex or currentIndex == newIndex then
        return false
    end

    local entry = objectOrder[currentIndex]
    table.remove( objectOrder, currentIndex )

    if currentIndex < newIndex then
        newIndex = newIndex - 1
    end

    table.insert( objectOrder, newIndex, entry )

    -- Also reorder within the type-specific manager
    if entry.type == "emitter" then
        emitterManager.reorderEmitter( id, newIndex )
    else
        imageManager.reorderImage( id, newIndex )
    end

    applyZOrder()
    return true
end

local function getObjectList()
    local list = {}
    for _, entry in ipairs( objectOrder ) do
        if entry.type == "emitter" then
            local name = emitterManager.getName( entry.id )
            if name then
                list[#list + 1] = {
                    id = entry.id,
                    type = "emitter",
                    name = name,
                    selected = ( entry.id == selectedObjectId ),
                }
            end
        else
            local name = imageManager.getName( entry.id )
            if name then
                list[#list + 1] = {
                    id = entry.id,
                    type = "image",
                    name = name,
                    selected = ( entry.id == selectedObjectId ),
                }
            end
        end
    end
    return list
end

local function getFullState()
    return {
        emitterState = emitterManager.getState(),
        imageState = imageManager.getState(),
        objectOrder = deepCopy( objectOrder ),
        selectedId = selectedObjectId,
        selectedType = selectedObjectType,
    }
end

local function restoreFullState( state )
    emitterManager.restoreState( state.emitterState )
    if state.imageState then
        imageManager.restoreState( state.imageState )
    end
    objectOrder = deepCopy( state.objectOrder or {} )
    selectedObjectId = state.selectedId
    selectedObjectType = state.selectedType

    -- Backward compat: if objectOrder is empty but emitters exist, rebuild it
    if #objectOrder == 0 then
        local emList = emitterManager.getEmitterList()
        for _, em in ipairs( emList ) do
            objectOrder[#objectOrder + 1] = { id = em.id, type = "emitter" }
        end
        if state.selectedId then
            selectedObjectType = "emitter"
        end
    end

    applyZOrder()
end

local function selectObject( id, objType )
    selectedObjectId = id
    selectedObjectType = objType
    if objType == "emitter" then
        emitterManager.selectEmitter( id )
        imageManager.deselectImage()
    elseif objType == "image" then
        imageManager.selectImage( id )
        emitterManager.selectEmitter( nil )
    end
end

local function dispatchObjectSelected()
    if not jsBridge then return end

    if selectedObjectType == "emitter" and selectedObjectId then
        jsBridge.dispatchEvent( "objectSelected", {
            id = selectedObjectId,
            type = "emitter",
            name = emitterManager.getName( selectedObjectId ),
            params = emitterManager.getParams( selectedObjectId ),
            textureInfo = emitterManager.getTextureInfo( selectedObjectId ),
        } )
    elseif selectedObjectType == "image" and selectedObjectId then
        jsBridge.dispatchEvent( "objectSelected", {
            id = selectedObjectId,
            type = "image",
            name = imageManager.getName( selectedObjectId ),
            properties = imageManager.getProperties( selectedObjectId ),
        } )
    else
        jsBridge.dispatchEvent( "objectSelected", {
            id = nil,
            type = nil,
            name = nil,
            params = nil,
        } )
    end
end

local function dispatchObjectListChanged()
    if not jsBridge then return end
    jsBridge.dispatchEvent( "objectListChanged", {
        objects = getObjectList(),
    } )
end

---------------------------------------------------------------------------------
-- Zoom/Pan State
---------------------------------------------------------------------------------

local viewZoom = 1.0
local isPanning = false
local panStartX = 0
local panStartY = 0
local panStartGroupX = 0
local panStartGroupY = 0
local lastMouseX = screen.centerX
local lastMouseY = screen.centerY

local MIN_ZOOM = 0.1
local MAX_ZOOM = 5.0
local ZOOM_STEP = 1.1  -- multiplicative factor per scroll notch

local function dispatchViewChanged()
    if not jsBridge then return end
    jsBridge.dispatchEvent( "viewChanged", {
        zoom = viewZoom,
        panX = groupObjects.x,
        panY = groupObjects.y,
    } )
end

local function resetView()
    viewZoom = 1.0
    groupObjects.xScale = 1
    groupObjects.yScale = 1
    groupObjects.x = 0
    groupObjects.y = 0
    dispatchViewChanged()
end

---------------------------------------------------------------------------------
-- Drag Interaction (emitters only; images have their own touch listeners)
---------------------------------------------------------------------------------

local isDragging = false
local dragOffsetX = 0
local dragOffsetY = 0

local touchRect = display.newRect(
    screen.centerX,
    screen.centerY,
    screen.width,
    screen.height
)
touchRect.isVisible = false
touchRect.isHitTestable = true

local function onCanvasTouch( event )
    -- Only drag emitters via the background touch rect
    if selectedObjectType ~= "emitter" then return false end

    if event.phase == "began" then
        isDragging = true
        local activeEmitter = emitterManager.getActiveEmitter()
        if activeEmitter then
            local localX, localY = groupObjects:contentToLocal( event.x, event.y )
            dragOffsetX = localX - activeEmitter.x
            dragOffsetY = localY - activeEmitter.y
        else
            dragOffsetX = 0
            dragOffsetY = 0
        end
        display.getCurrentStage():setFocus( event.target )

    elseif event.phase == "moved" and isDragging then
        local localX, localY = groupObjects:contentToLocal( event.x, event.y )
        local newX = localX - dragOffsetX
        local newY = localY - dragOffsetY
        emitterManager.setPreviewPosition( newX, newY )
        refreshAllIndicators()

    elseif event.phase == "ended" or event.phase == "cancelled" then
        isDragging = false
        display.getCurrentStage():setFocus( nil )
    end
    return true
end

touchRect:addEventListener( "touch", onCanvasTouch )

---------------------------------------------------------------------------------
-- Zoom (scroll wheel) & Pan (right/middle-click drag)
---------------------------------------------------------------------------------

local function onMouseEvent( event )
    -- Track mouse position from all event types (scroll events may not
    -- report accurate x/y in HTML5 builds, so we use the last known position).
    if event.x and event.y then
        if event.type ~= "scroll" then
            lastMouseX = event.x
            lastMouseY = event.y
        end
    end

    if event.type == "scroll" then
        local scrollY = event.scrollY or 0
        if scrollY == 0 then return end

        local oldZoom = viewZoom
        local newZoom

        if scrollY > 0 then
            newZoom = oldZoom * ZOOM_STEP
        else
            newZoom = oldZoom / ZOOM_STEP
        end

        if newZoom < MIN_ZOOM then newZoom = MIN_ZOOM end
        if newZoom > MAX_ZOOM then newZoom = MAX_ZOOM end
        if newZoom == oldZoom then return end

        -- Zoom toward last known cursor position
        local mouseX = lastMouseX
        local mouseY = lastMouseY
        local scale = newZoom / oldZoom

        groupObjects.x = mouseX - ( mouseX - groupObjects.x ) * scale
        groupObjects.y = mouseY - ( mouseY - groupObjects.y ) * scale
        groupObjects.xScale = newZoom
        groupObjects.yScale = newZoom

        viewZoom = newZoom
        dispatchViewChanged()

    elseif event.isSecondaryButtonDown or event.isMiddleButtonDown then
        if event.type == "down" then
            isPanning = true
            panStartX = event.x
            panStartY = event.y
            panStartGroupX = groupObjects.x
            panStartGroupY = groupObjects.y

        elseif event.type == "drag" and isPanning then
            groupObjects.x = panStartGroupX + ( event.x - panStartX )
            groupObjects.y = panStartGroupY + ( event.y - panStartY )

        elseif event.type == "up" and isPanning then
            isPanning = false
            dispatchViewChanged()
        end

    elseif event.type == "up" then
        if isPanning then
            isPanning = false
            dispatchViewChanged()
        end
    end
end

Runtime:addEventListener( "mouse", onMouseEvent )

---------------------------------------------------------------------------------
-- Platform Warning
---------------------------------------------------------------------------------

local function showPlatformWarning()
    local group = display.newGroup()
    local bg = display.newRect( group, screen.centerX, 30, screen.width, 60 )
    bg:setFillColor( 0.8, 0.1, 0.1 )

    local warningText = display.newText( {
        parent = group,
        text = "This application requires the web interface to function properly.",
        x = screen.centerX,
        y = 30,
        font = native.systemFontBold,
        fontSize = 16,
        align = "center",
    } )
    warningText:setFillColor( 1, 1, 1 )

    return group
end

---------------------------------------------------------------------------------
-- Module Initialization
---------------------------------------------------------------------------------
emitterManager.init( groupObjects )
imageManager.init( groupObjects, jsBridge )
history.init()

imageManager.setOnImageTouched( function( id )
    if selectedObjectId ~= id then
        selectObject( id, "image" )
        refreshAllIndicators()
        dispatchObjectSelected()
        dispatchObjectListChanged()
    end
end )

-- Set to true by JS bridge "skipDefaultEmitter" call when restoring a saved session
local skipDefaultEmitter = false

if not skipDefaultEmitter then
    local defaultEmitter = emitterManager.createEmitter( templates.getDefault(), "Fire" )
    emitterManager.selectEmitter( defaultEmitter.id )
    selectedObjectId = defaultEmitter.id
    selectedObjectType = "emitter"
    addToObjectOrder( defaultEmitter.id, "emitter" )
    refreshIndicator( defaultEmitter.id, nil )
    history.push( getFullState(), "Initial state" )
end


---------------------------------------------------------------------------------
-- JS Bridge Handler Registration
---------------------------------------------------------------------------------

if jsBridge then
    local readySent = false

    local function sendReady()
        if readySent then return end
        readySent = true
        jsBridge.dispatchEvent( "ready", {
            objects = getObjectList(),
            templates = templates.getList(),
            canUndo = history.canUndo(),
            canRedo = history.canRedo(),
        } )
    end

    -- Dependency table for handler modules (closures share upvalues with main.lua)
    local deps = {
        -- Modules
        emitterManager = emitterManager,
        imageManager = imageManager,
        history = history,
        templates = templates,
        jsBridge = jsBridge,
        screen = screen,

        -- Functions
        getFullState = getFullState,
        restoreFullState = restoreFullState,
        getObjectList = getObjectList,
        selectObject = selectObject,
        addToObjectOrder = addToObjectOrder,
        removeFromObjectOrder = removeFromObjectOrder,
        applyZOrder = applyZOrder,
        refreshIndicator = refreshIndicator,
        clearIndicator = clearIndicator,
        refreshAllIndicators = refreshAllIndicators,
        updateEmitterIndicator = updateEmitterIndicator,
        dispatchObjectListChanged = dispatchObjectListChanged,
        dispatchObjectSelected = dispatchObjectSelected,
        reorderObject = reorderObject,
        sendReady = sendReady,

        -- State accessors (closures over main.lua's local variables)
        getSelectedId = function() return selectedObjectId end,
        setSelectedId = function( v ) selectedObjectId = v end,
        getSelectedType = function() return selectedObjectType end,
        setSelectedType = function( v ) selectedObjectType = v end,
        getObjectCount = function() return #objectOrder end,
        getObjectOrderEntry = function( i ) return objectOrder[i] end,
        clearObjectOrder = function()
            for i = #objectOrder, 1, -1 do objectOrder[i] = nil end
        end,
        setSkipDefaultEmitter = function( v ) skipDefaultEmitter = v end,
        setGridSize = function( size )
            currentGridSize = size
            createGrid( size )
        end,
        setGridEnabled = function( enabled )
            groupGrid.isVisible = enabled
        end,
        setEmitterBoundsMode = function( mode )
            emitterBoundsMode = mode
            refreshAllIndicators()
        end,
        setBackgroundColorFn = setBackgroundColor,
        setGridColor = function( r, g, b )
            gridColor[1] = r
            gridColor[2] = g
            gridColor[3] = b
            createGrid()
        end,
        setBoundsColor = function( r, g, b )
            boundsColor[1] = r
            boundsColor[2] = g
            boundsColor[3] = b
            refreshAllIndicators()
        end,
        resetViewFn = resetView,
        getCanvasGroup = function() return groupObjects end,
    }

    local emitterH = require( "classes.handlers.emitterHandlers" ).create( deps )
    local imageH = require( "classes.handlers.imageHandlers" ).create( deps )
    local sceneH = require( "classes.handlers.sceneHandlers" ).create( deps )
    local viewH = require( "classes.handlers.viewHandlers" ).create( deps )

    local allHandlers = {}
    for k, v in pairs( emitterH ) do allHandlers[k] = v end
    for k, v in pairs( imageH ) do allHandlers[k] = v end
    for k, v in pairs( sceneH ) do allHandlers[k] = v end
    for k, v in pairs( viewH ) do allHandlers[k] = v end

    jsBridge.init( allHandlers )

    -- Fallback if parent page's postMessage never arrives
    timer.performWithDelay( 300, sendReady )
else
    showPlatformWarning()
end

---------------------------------------------------------------------------------
-- Window Resize Handler
---------------------------------------------------------------------------------

local function onResize()
    createGrid()
    createBorder()
    -- groupGrid:toFront()

    touchRect.width = screen.width
    touchRect.height = screen.height
    touchRect.x = screen.centerX
    touchRect.y = screen.centerY
end

Runtime:addEventListener( "resize", onResize )

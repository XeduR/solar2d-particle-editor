-- storageHandlers.lua - Persistent storage via system.DocumentsDirectory (IDBFS on HTML5)

local fileStorage = require( "classes.fileStorage" )
local utils = require( "classes.utils" )

local M = {}

--------------------------------------------------------------------------------------
-- Forward declarations & variables

local AUTOSAVE_FILE = "autosave.json"
local SCENES_DIR = "scenes"
local TEXTURES_DIR = "textures"
local TEXTURES_MANIFEST = "textures.json"
local SAVE_VERSION = 3

--------------------------------------------------------------------------------------
-- Private functions

local function sanitizeSceneName( name )
	if not name or name == "" then return nil end
	return name:gsub( "[^%w%s%-_]", "" ):gsub( "%s+", "_" )
end

local function sceneFilePath( name )
	local safe = sanitizeSceneName( name )
	if not safe then return nil end
	return SCENES_DIR .. "/" .. safe .. ".json"
end

-- Assembles current scene data for saving (reuses deps.getSceneData pattern)
local function buildSaveData( deps, bgColor )
	local sceneData = deps.getSceneData()
	return {
		version = SAVE_VERSION,
		timestamp = os.time() * 1000,
		objects = sceneData.objects,
		backgroundColor = bgColor or "#000000",
	}
end

-- Restores a scene from saved data on the Lua side, avoiding large bridge transfers.
local function restoreScene( deps, saveData )
	if not saveData then return false end

	local objects = saveData.objects
	if not objects or #objects == 0 then
		-- Support legacy formats
		if saveData.emitters then
			objects = {}
			if saveData.images then
				for i = 1, #saveData.images do
					saveData.images[i].type = "image"
					objects[#objects + 1] = saveData.images[i]
				end
			end
			for i = 1, #saveData.emitters do
				saveData.emitters[i].type = "emitter"
				objects[#objects + 1] = saveData.emitters[i]
			end
		end
		if not objects or #objects == 0 then return false end
	end

	-- Clear existing scene
	deps.clearAllObjects()

	local emitterManager = deps.emitterManager
	local imageManager = deps.imageManager
	local lastId, lastType

	for i = 1, #objects do
		local obj = objects[i]

		if obj.type == "emitter" then
			local params = obj.params or obj
			local result = emitterManager.createEmitter( params, obj.name )
			if result then
				if obj.x and obj.y then
					emitterManager.setEmitterPosition( result.id, obj.x, obj.y )
				end
				if obj.textureBase64 and obj.textureBase64 ~= "" then
					emitterManager.setTexture( result.id, obj.textureBase64, obj.textureFilename or obj.textureFileName )
				end
				deps.addToObjectOrder( result.id, "emitter" )
				if obj.locked then
					deps.setObjectLocked( result.id, true )
				end
				deps.refreshIndicator( result.id, nil )
				lastId = result.id
				lastType = "emitter"
			end

		elseif obj.type == "image" then
			local base64 = obj.imageBase64 or ""
			if base64 ~= "" and not base64:match( "^data:" ) then
				base64 = "data:image/png;base64," .. base64
			end
			local result = imageManager.createImage( base64, obj.filename, obj.name, obj.width, obj.height )
			if result then
				if obj.x then imageManager.setProperty( result.id, "x", obj.x ) end
				if obj.y then imageManager.setProperty( result.id, "y", obj.y ) end
				if obj.scale and obj.scale ~= 1 then imageManager.setProperty( result.id, "scale", obj.scale ) end
				if obj.opacity and obj.opacity ~= 1 then imageManager.setProperty( result.id, "opacity", obj.opacity ) end
				deps.addToObjectOrder( result.id, "image" )
				if obj.locked then
					deps.setObjectLocked( result.id, true )
				end
				lastId = result.id
				lastType = "image"
			end
		end
	end

	deps.applyZOrder()

	-- Select the last created object (matching JS behavior)
	if lastId then
		deps.selectObject( lastId, lastType )
	end

	if saveData.backgroundColor then
		local hex = saveData.backgroundColor:gsub( "^#", "" )
		local r = tonumber( hex:sub( 1, 2 ), 16 )
		local g = tonumber( hex:sub( 3, 4 ), 16 )
		local b = tonumber( hex:sub( 5, 6 ), 16 )
		if r and g and b then
			deps.setBackgroundColorFn( r / 255, g / 255, b / 255 )
		end
	end

	deps.history.push( deps.getFullState(), "Restore scene" )

	-- Notify JS
	deps.jsBridge.dispatchEvent( "sceneRestored", {
		objects = deps.getObjectList(),
		selectedId = deps.getSelectedId(),
		selectedType = deps.getSelectedType(),
		backgroundColor = saveData.backgroundColor,
		canUndo = deps.history.canUndo(),
		canRedo = deps.history.canRedo(),
	} )

	return true
end

-- Reads or creates the texture manifest
local function getTextureManifest()
	return fileStorage.readJSON( TEXTURES_MANIFEST ) or {}
end

local function saveTextureManifest( manifest )
	fileStorage.writeJSON( TEXTURES_MANIFEST, manifest )
end

--------------------------------------------------------------------------------------
-- Public functions

function M.create( deps )
	-- Ensure storage directories exist on init
	fileStorage.ensureDir( SCENES_DIR )
	fileStorage.ensureDir( TEXTURES_DIR )

	-- Wrap deps.getSceneData if it doesn't exist directly (it's in sceneHandlers)
	local getSceneData = deps.getSceneData
	if not getSceneData then
		-- Build it from deps (same logic as sceneHandlers.getSceneData)
		getSceneData = function()
			local objects = {}
			local count = deps.getObjectCount()
			for i = 1, count do
				local entry = deps.getObjectOrderEntry( i )
				if entry.type == "emitter" then
					local exported = deps.emitterManager.exportEmitter( entry.id, true )
					if exported then
						exported.type = "emitter"
						if deps.isObjectLocked( entry.id ) then
							exported.locked = true
						end
						objects[#objects + 1] = exported
					end
				elseif entry.type == "image" then
					local imgData = deps.imageManager.exportImage( entry.id )
					if imgData then
						imgData.type = "image"
						if deps.isObjectLocked( entry.id ) then
							imgData.locked = true
						end
						objects[#objects + 1] = imgData
					end
				end
			end
			return { objects = objects }
		end
	end

	-- Clear all objects (reuse the same logic as sceneHandlers.clearAllObjects)
	local clearAllObjects = deps.clearAllObjects
	if not clearAllObjects then
		clearAllObjects = function()
			local emList = deps.emitterManager.getEmitterList()
			for _, em in ipairs( emList ) do
				deps.emitterManager.removeEmitter( em.id )
			end
			deps.imageManager.removeAll()
			deps.clearObjectOrder()
			deps.setSelectedId( nil )
			deps.setSelectedType( nil )
			deps.history.clear()
			deps.history.push( deps.getFullState(), "Clear all objects" )
		end
	end

	-- Attach to deps for restoreScene to use
	deps.getSceneData = getSceneData
	deps.clearAllObjects = clearAllObjects

	return {
		----------------------------------------------------------------
		-- Autosave
		----------------------------------------------------------------

		saveAutosave = function( bgColor )
			local data = buildSaveData( deps, bgColor )
			return fileStorage.writeJSON( AUTOSAVE_FILE, data )
		end,

		hasAutosave = function()
			local data = fileStorage.readJSON( AUTOSAVE_FILE )
			if not data then
				return { exists = false }
			end
			local objectCount = 0
			if data.objects then
				objectCount = #data.objects
			elseif data.emitters then
				objectCount = #data.emitters + ( data.images and #data.images or 0 )
			end
			return {
				exists = true,
				timestamp = data.timestamp or 0,
				objectCount = objectCount,
			}
		end,

		loadAutosave = function()
			local data = fileStorage.readJSON( AUTOSAVE_FILE )
			return restoreScene( deps, data )
		end,

		deleteAutosave = function()
			return fileStorage.delete( AUTOSAVE_FILE )
		end,

		----------------------------------------------------------------
		-- Scenes
		----------------------------------------------------------------

		saveScene = function( name, bgColor )
			local path = sceneFilePath( name )
			if not path then return false end
			local data = buildSaveData( deps, bgColor )
			data.name = name
			return fileStorage.writeJSON( path, data )
		end,

		loadScene = function( name )
			local path = sceneFilePath( name )
			if not path then return false end
			local data = fileStorage.readJSON( path )
			return restoreScene( deps, data )
		end,

		deleteScene = function( name )
			local path = sceneFilePath( name )
			if not path then return false end
			return fileStorage.delete( path )
		end,

		listScenes = function()
			local files = fileStorage.listDir( SCENES_DIR )
			local scenes = {}
			for i = 1, #files do
				if files[i]:match( "%.json$" ) then
					local sceneName = files[i]:gsub( "%.json$", "" ):gsub( "_", " " )
					local data = fileStorage.readJSON( SCENES_DIR .. "/" .. files[i] )
					scenes[#scenes + 1] = {
						name = ( data and data.name ) or sceneName,
						file = files[i]:gsub( "%.json$", "" ),
						timestamp = data and data.timestamp or 0,
					}
				end
			end
			table.sort( scenes, function( a, b ) return ( a.timestamp or 0 ) > ( b.timestamp or 0 ) end )
			return scenes
		end,

		----------------------------------------------------------------
		-- Textures
		----------------------------------------------------------------

		saveTexture = function( base64, filename, label )
			if not base64 or not filename then return false end
			base64 = base64:gsub( "^data:image/[%w+]+;base64,", "" )
			local binaryData = utils.base64Decode( base64 )
			if not binaryData or #binaryData == 0 then return false end

			fileStorage.writeBinary( TEXTURES_DIR .. "/" .. filename, binaryData )

			-- Update manifest (dedupe by filename)
			local manifest = getTextureManifest()
			local found = false
			for i = 1, #manifest do
				if manifest[i].file == filename then
					manifest[i].label = label or manifest[i].label
					found = true
					break
				end
			end
			if not found then
				manifest[#manifest + 1] = { label = label or filename, file = filename }
			end
			saveTextureManifest( manifest )
			return true
		end,

		deleteTexture = function( filename )
			if not filename then return false end
			fileStorage.delete( TEXTURES_DIR .. "/" .. filename )

			local manifest = getTextureManifest()
			for i = #manifest, 1, -1 do
				if manifest[i].file == filename then
					table.remove( manifest, i )
					break
				end
			end
			saveTextureManifest( manifest )
			return true
		end,

		listTextures = function()
			return getTextureManifest()
		end,

		getTextureBase64 = function( filename )
			if not filename then return nil end
			local binaryData = fileStorage.readBinary( TEXTURES_DIR .. "/" .. filename )
			if not binaryData then return nil end
			return utils.base64Encode( binaryData )
		end,

		----------------------------------------------------------------
		-- Migration (one-time, from old localStorage data)
		----------------------------------------------------------------

		migrateAutosave = function( data )
			if not data then return false end
			return fileStorage.writeJSON( AUTOSAVE_FILE, data )
		end,

		migrateScene = function( name, data )
			if not name or not data then return false end
			local path = sceneFilePath( name )
			if not path then return false end
			data.name = data.name or name
			return fileStorage.writeJSON( path, data )
		end,

		migrateTexture = function( base64, filename, label )
			if not base64 or not filename then return false end
			base64 = base64:gsub( "^data:image/[%w+]+;base64,", "" )
			local binaryData = utils.base64Decode( base64 )
			if not binaryData or #binaryData == 0 then return false end

			fileStorage.writeBinary( TEXTURES_DIR .. "/" .. filename, binaryData )

			local manifest = getTextureManifest()
			local found = false
			for i = 1, #manifest do
				if manifest[i].file == filename then
					found = true
					break
				end
			end
			if not found then
				manifest[#manifest + 1] = { label = label or filename, file = filename }
				saveTextureManifest( manifest )
			end
			return true
		end,

		clearAllStorage = function()
			-- Delete autosave
			fileStorage.delete( AUTOSAVE_FILE )

			-- Delete all scenes
			local sceneFiles = fileStorage.listDir( SCENES_DIR )
			for i = 1, #sceneFiles do
				fileStorage.delete( SCENES_DIR .. "/" .. sceneFiles[i] )
			end

			-- Delete all textures
			local textureFiles = fileStorage.listDir( TEXTURES_DIR )
			for i = 1, #textureFiles do
				fileStorage.delete( TEXTURES_DIR .. "/" .. textureFiles[i] )
			end

			-- Delete manifest
			fileStorage.delete( TEXTURES_MANIFEST )

			return true
		end,
	}
end

return M

---------------------------------------------------------------------------------
-- manifestGenerator.lua (Simulator only)
--
-- Scans asset folders for .png files and writes manifest.json.
-- Only writes when contents change to avoid triggering the Simulator's
-- "Restart on file change" loop.
---------------------------------------------------------------------------------

local lfs = require( "lfs" )
local json = require( "json" )

-- "smoke_01.png" -> "Smoke 01"
local function filenameToLabel( filename )
    local name = filename:match( "^(.+)%.[^%.]+$" ) or filename
    name = name:gsub( "_", " " )
    name = name:gsub( "(%a)([%w]*)", function( first, rest )
        return first:upper() .. rest
    end )
    return name
end

local function scanFolder( folderPath )
    local entries = {}
    for file in lfs.dir( folderPath ) do
        if file:match( "%.png$" ) then
            entries[#entries + 1] = {
                file = file,
                label = filenameToLabel( file ),
            }
        end
    end
    table.sort( entries, function( a, b )
        return a.file < b.file
    end )
    return entries
end

local function readFile( path )
    local file = io.open( path, "r" )
    if not file then return nil end
    local content = file:read( "*a" )
    file:close()
    return content
end

local function writeFile( path, content )
    local file = io.open( path, "w" )
    if not file then
        print( "manifestGenerator: Failed to open for writing: " .. tostring( path ) )
        return false
    end
    file:write( content )
    file:close()
    return true
end

local function generateManifest( assetSubfolder )
    local folderPath = system.pathForFile( assetSubfolder, system.ResourceDirectory )
    if not folderPath then
        print( "manifestGenerator: Cannot resolve path for " .. assetSubfolder )
        return
    end

    local manifestPath = folderPath .. "/manifest.json"
    local entries = scanFolder( folderPath )
    local newJson = json.encode( entries )

    local existingJson = readFile( manifestPath )
    if existingJson == newJson then
        return
    end

    local success = writeFile( manifestPath, newJson )
    if success then
        print( "manifestGenerator: Updated " .. assetSubfolder .. "/manifest.json (" .. #entries .. " files)" )
    end
end

generateManifest( "assets/particles" )
generateManifest( "assets/images" )

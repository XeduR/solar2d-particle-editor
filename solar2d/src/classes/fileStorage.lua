-- Persistent file I/O for system.DocumentsDirectory (IDBFS on HTML5).

local lfs = require( "lfs" )
local json = require( "json" )

local M = {}

--------------------------------------------------------------------------------------
-- Forward declarations & variables

local pathForFile = system.pathForFile
local docsDir = system.DocumentsDirectory

--------------------------------------------------------------------------------------
-- Private functions

local function sanitize( relativePath )
	relativePath = relativePath:gsub( "%.%.", "" )
	if relativePath:sub( 1, 1 ) == "/" or relativePath:sub( 1, 1 ) == "\\" then
		relativePath = relativePath:sub( 2 )
	end
	return relativePath
end

local function resolvePath( relativePath )
	relativePath = sanitize( relativePath )
	if relativePath == "" then return nil end
	return pathForFile( relativePath, docsDir )
end

--------------------------------------------------------------------------------------
-- Public functions

function M.writeJSON( relativePath, t )
	local path = resolvePath( relativePath )
	if not path then return false end
	local encoded = json.encode( t )
	if not encoded then return false end
	local file = io.open( path, "w" )
	if not file then return false end
	file:write( encoded )
	io.close( file )
	return true
end

function M.readJSON( relativePath )
	local path = resolvePath( relativePath )
	if not path then return nil end
	local file = io.open( path, "r" )
	if not file then return nil end
	local content = file:read( "*a" )
	io.close( file )
	if not content or content == "" then return nil end
	local ok, result = pcall( json.decode, content )
	if not ok then return nil end
	return result
end

function M.writeBinary( relativePath, data )
	local path = resolvePath( relativePath )
	if not path then return false end
	local file = io.open( path, "wb" )
	if not file then return false end
	file:write( data )
	io.close( file )
	return true
end

function M.readBinary( relativePath )
	local path = resolvePath( relativePath )
	if not path then return nil end
	local file = io.open( path, "rb" )
	if not file then return nil end
	local data = file:read( "*a" )
	io.close( file )
	return data
end

function M.delete( relativePath )
	local path = resolvePath( relativePath )
	if not path then return false end
	return os.remove( path ) ~= nil
end

function M.exists( relativePath )
	local path = resolvePath( relativePath )
	if not path then return false end
	local file = io.open( path, "r" )
	if not file then return false end
	io.close( file )
	return true
end

function M.listDir( relativePath )
	relativePath = sanitize( relativePath or "" )
	local path
	if relativePath == "" then
		path = pathForFile( "", docsDir )
	else
		path = pathForFile( relativePath, docsDir )
	end
	if not path then return {} end

	local entries = {}
	local ok, iter = pcall( lfs.dir, path )
	if not ok then return {} end
	for file in iter do
		if file ~= "." and file ~= ".." then
			entries[#entries + 1] = file
		end
	end
	return entries
end

function M.ensureDir( relativePath )
	relativePath = sanitize( relativePath or "" )
	if relativePath == "" then return true end
	local path = pathForFile( "", docsDir )
	if not path then return false end
	local fullPath = path .. "/" .. relativePath
	lfs.mkdir( fullPath )
	return true
end

return M

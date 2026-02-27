---------------------------------------------------------------------------------
-- utils.lua
---------------------------------------------------------------------------------

local M = {}

function M.deepCopy( orig, seen )
    if type( orig ) ~= "table" then
        return orig
    end
    seen = seen or {}
    if seen[orig] then return seen[orig] end
    local copy = {}
    seen[orig] = copy
    for k, v in pairs( orig ) do
        copy[k] = M.deepCopy( v, seen )
    end
    return copy
end

-- Pre-built lookup tables for O(n) base64 encode/decode
local b64chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
local b64decode = {}
for i = 1, #b64chars do
    b64decode[string.byte( b64chars, i )] = i - 1
end

local b64encode = {}
for i = 0, 63 do
    b64encode[i] = string.sub( b64chars, i + 1, i + 1 )
end

local floor = math.floor
local char = string.char
local byte = string.byte
local concat = table.concat

function M.base64Decode( data )
    local result = {}
    local n = 0
    local bits = 0
    local numBits = 0

    for i = 1, #data do
        local val = b64decode[byte( data, i )]
        if val then
            bits = bits * 64 + val
            numBits = numBits + 6
            if numBits >= 8 then
                numBits = numBits - 8
                local shift = 2 ^ numBits
                local b = floor( bits / shift )
                n = n + 1
                result[n] = char( b )
                bits = bits - b * shift
            end
        end
    end

    return concat( result )
end

function M.base64Encode( data )
    local result = {}
    local n = 0
    local bits = 0
    local numBits = 0

    for i = 1, #data do
        bits = bits * 256 + byte( data, i )
        numBits = numBits + 8
        while numBits >= 6 do
            numBits = numBits - 6
            local shift = 2 ^ numBits
            local idx = floor( bits / shift )
            n = n + 1
            result[n] = b64encode[idx]
            bits = bits - idx * shift
        end
    end

    if numBits > 0 then
        local shift = 2 ^ ( 6 - numBits )
        n = n + 1
        result[n] = b64encode[bits * shift]
    end

    local pad = ( 3 - #data % 3 ) % 3
    for _ = 1, pad do
        n = n + 1
        result[n] = '='
    end

    return concat( result )
end

function M.readBinaryFile( filename, baseDir )
    local path = system.pathForFile( filename, baseDir )
    if not path then return nil end
    local file = io.open( path, "rb" )
    if not file then return nil end
    local data = file:read( "*a" )
    io.close( file )
    return data
end

function M.writeTempFile( filename, binaryData )
    filename = filename:gsub( "%.%.", "" ):gsub( "[/\\]", "" )
    if filename == "" then return false end
    local path = system.pathForFile( filename, system.TemporaryDirectory )
    if not path then return false end
    local file = io.open( path, "wb" )
    if not file then return false end
    file:write( binaryData )
    io.close( file )
    return true
end

return M

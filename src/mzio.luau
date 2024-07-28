
--[=[
    ========== mzio.lua ==========
    Source streamer for Moonslice.
    Last Commited:	27/07/2024 - 11:00 PM
]=]

--!native
--!strict

--[=[
	Format of Z structure (ZIO)
	Z.n			-- bytes still unread
	Z.p			-- last read position position in buffer
	Z.reader	-- chunk reader function
	Z.data		-- additional data
]=]

local Exception = {
	"Passed source to stream was not a string."
}

local ZIO = {}

export type Z = typeof(ZIO) & {
	reader : () -> string ,
	data : string ,
	name : string ,
	n : number ,
	p : number
}

-- // Makes a buffer reader
local function MakeReader( source : string? )
	return function()
		local data = source
		source = nil
		return data
	end
end

-- // Fill up input buffer
local function Fill( Z : Z )
	local buff = Z.reader()
	Z.data = buff
	if not buff or buff == "" then return "<eoz>" end
	Z.n, Z.p = #buff - 1, 1
	return string.sub(buff, 1, 1)
end

-- // Get next character
-- * local n, p are used to optimize code generation
function ZIO.GetChar( self : Z )
	local n, p = self.n, self.p + 1
	if n > 0 then
		self.n, self.p = n - 1, p
		return string.sub(self.data, p, p)
	else
		return Fill(self)
	end
end

-- // Create a ZIO input stream
function ZIO.new(
	source : string ,
	data : string? ,
	name : string
)
	assert( type(source) == "string" , Exception[1] )
	local Z = setmetatable({}, {__index = ZIO})
	Z.reader = MakeReader(source)
	Z.data = data or ""
	Z.name = name
	-- set up additional data for reading
	if not data or data == "" then
		Z.n = 0
	else
		Z.n = #data
	end
	Z.p = 0
	return Z
end

return ZIO
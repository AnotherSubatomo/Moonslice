
--[=[
    ========== mzio.lua ==========
    Source streamer for Moonslice.
    
    By:             @AnotherSubatomo (GitHub)
    Version:        0.1.0
    Last Commited:  02/06/2024 - 8:42 PM

    SPDX-License-Identifier: MIT
]=]

--[=[
	Format of z structure (ZIO)
	z.n			-- bytes still unread
	z.p			-- last read position position in buffer
	z.reader	-- chunk reader function
	z.data		-- additional data
]=]

local Exception = {
	"Passed source to stream was not a string."
}

local ZIO = {}

-- // Makes a buffer reader
function ZIO:MakeReader(buff)
	assert( type(buff) == "string" , Exception[1] )
	return function ()
		local data = buff
		buff = nil
		return data
	end
end

-- // Fill up input buffer
local function Fill(z)
	local buff = z.reader()
	z.data = buff
	if not buff or buff == "" then return "<eoz>" end
	z.n, z.p = #buff - 1, 1
	return string.sub(buff, 1, 1)
end

-- // Get next character
-- * local n, p are used to optimize code generation
function ZIO:GetChar()
	local n, p = self.n, self.p + 1
	if n > 0 then
		self.n, self.p = n - 1, p
		return string.sub(self.data, p, p)
	else
		return Fill(self)
	end
end

-- // Create a ZIO input stream
function ZIO.new(reader, data, name)
	if not reader then return end
	local z = setmetatable({}, {__index = ZIO})
	z.reader = reader
	z.data = data or ""
	z.name = name
	-- set up additional data for reading
	if not data or data == "" then z.n = 0 else z.n = #data end
	z.p = 0
	return z
end

return ZIO

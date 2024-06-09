
--[=[
    ============ maux.lua ============
    Auxiliary functions for the lexer,
    to be required and set as a global.
    
    By:             @AnotherSubatomo (GitHub)
    Version:        0.1.0
    Last Commited:  09/06/2024 - 6:04 PM

    SPDX-License-Identifier: MIT
]=]

--[=[
    * some features of the Lua lexer this was derived
      from are still here; might be changed in the future.
]=]

local Aux = {}

function Aux.ChunkID(source, bufflen)
	local out
	local first = string.sub(source, 1, 1)
	if first == "=" then
		out = string.sub(source, 2, bufflen)  -- remove first char
	else  -- out = "source", or "...source"
		if first == "@" then
			source = string.sub(source, 2)  -- skip the '@'
			bufflen = bufflen - #" '...' "
			local l = #source
			out = ""
			if l > bufflen then
				source = string.sub(source, 1 + l - bufflen)  -- get last part of file name
				out = out.."..."
			end
			out = out..source
		else  -- out = [string "string"]
			local len = string.find(source, "[\n\r]")  -- stop at first newline
			len = len and (len - 1) or #source
			bufflen = bufflen - #(" [string \"...\"] ")
			if len > bufflen then len = bufflen end
			out = "[string \""
			if len < #source then  -- must truncate?
				out = out..string.sub(source, 1, len).."..."
			else
				out = out..source
			end
			out = out.."\"]"
		end
	end
	return out
end

function Aux.IsAtNewLine(LS)
	return LS.Current == "\n" or LS.Current == "\r"
end

function Aux.IncLineCounter(LS)
	local old = LS.Current
	-- lua_assert(currIsNewline(LS))
	Aux.NextChar(LS)  -- skip '\n' or '\r'
	if Aux.IsAtNewLine(LS) and LS.Current ~= old then
		Aux.NextChar(LS)  -- skip '\n\r' or '\r\n'
	end
	LS.LineNumber = LS.LineNumber + 1
	if LS.LineNumber >= LS.MAX_INT then
		LS:SyntaxError(LS, "chunk has too many lines")
	end
end

------------------------------------------------------------------------
-- checks if current character read is found in the set 'set'
------------------------------------------------------------------------
function Aux.CheckNext(LS, set)
	if not string.find(set, LS.Current, 1, 1) then
		return false
	end
	Aux.SaveThenNext(LS)
	return true
end

------------------------------------------------------------------------
-- gets the next character and returns it; previously :nextc()
-- * this is the next() macro in llex.c; see notes at the beginning
------------------------------------------------------------------------
function Aux.NextChar(LS)
	local c = LS.ZIO:GetChar()
	LS.Current = c
	return c
end

------------------------------------------------------------------------
-- saves the given character into the token buffer; previously :save()
-- * buffer handling code removed, not used in this implementation
-- * test for maximum token buffer length not used, makes things faster
------------------------------------------------------------------------

function Aux.SaveChar(LS, c)
	local buff = LS.Buffer
	-- if you want to use this, please uncomment Lexer.MAX_SIZET further up
	--if #buff > LS.MAX_SIZET then
	--  LS:LexError(LS, "lexical element too long")
	--end
	LS.Buffer = buff..c
end

------------------------------------------------------------------------
-- save current character into token buffer, grabs next character
-- * like Aux.nextc, returns the character read for convenience
-- * previously :save_and_next()
------------------------------------------------------------------------
function Aux.SaveThenNext(LS)
	Aux.SaveChar(LS, LS.Current)
	return Aux.NextChar(LS)
end

------------------------------------------------------------------------
-- LUA_NUMBER
-- * Aux.read_numeral is the main lexer function to read a number
-- * Aux.str2d, Aux.buffreplace, Aux.trydecpoint are support functions
------------------------------------------------------------------------

------------------------------------------------------------------------
-- string to number converter (was luaO_str2d from lobject.c)
-- * returns the number, nil if fails (originally returns a boolean)
-- * conversion function originally lua_str2number(s,p), a macro which
--   maps to the strtod() function by default (from luaconf.h)
-- * ccuser44 was here to add support for binary intiger constants
------------------------------------------------------------------------
function Aux.ToNumber(s)
	local result = tonumber(s)
	if result then return result end
	-- conversion failed

	if string.lower(string.sub(s, 1, 2)) == "0x" then  -- maybe an hexadecimal constant?
		result = tonumber(s, 16)
		if result then return result end  -- most common case
		-- Was: invalid trailing characters?
		-- In C, this function then skips over trailing spaces.
		-- true is returned if nothing else is found except for spaces.
		-- If there is still something else, then it returns a false.
		-- All this is not necessary using Lua's tonumber.
	elseif string.lower(string.sub(s, 1, 2)) == "0b" then  -- binary intiger constants
		local bin_str = string.sub(s, 3)

		if string.match(bin_str, "[01]*") then
			result = tonumber(bin_str, 2)
			if result then return result end  -- most common case
		end
	end
	return nil
end

------------------------------------------------------------------------
-- single-character replacement, for locale-aware decimal points
------------------------------------------------------------------------
function Aux.ReplaceBuffer(LS, from, to)
	local result, buff = "", LS.Buffer
	for p = 1, #buff do
		local c = string.sub(buff, p, p)
		if c == from then c = to end
		result = result..c
	end
	LS.Buffer = result
end

------------------------------------------------------------------------
-- Attempt to convert a number by translating '.' decimal points to
-- the decimal point character used by the current locale. This is not
-- needed in Yueliang as Lua's tonumber() is already locale-aware.
-- Instead, the code is here in case the user implements localeconv().
------------------------------------------------------------------------
function Aux.TryDecimal(LS, Token)
	-- format error: try to update decimal point separator
	local old = LS.DecPoint
	-- translate the following to Lua if you implement localeconv():
	-- struct lconv *cv = localeconv();
	-- LS->decpoint = (cv ? cv->decimal_point[0] : '.');
	Aux.ReplaceBuffer(LS, old, LS.DecPoint)  -- try updated decimal separator
	local seminfo = Aux.ToNumber(LS.Buffer)
	Token.SemanticInfo = seminfo
	if not seminfo then
		-- format error with correct decimal point: no more options
		Aux.ReplaceBuffer(LS, LS.DecPoint, ".")  -- undo change (for error message)
		LS:LexError(LS, "malformed number", "TK_NUMBER")
	end
end

------------------------------------------------------------------------
-- main number conversion function
-- * "^%w$" needed in the scan in order to detect "<eoz>"
------------------------------------------------------------------------
function Aux.ReadNumeral(LS, Token)
	-- lua_assert(string.find(LS.Current, "%d"))
	repeat
		Aux.SaveThenNext(LS)
	until string.find(LS.Current, "%D") and LS.Current ~= "."
	if Aux.CheckNext(LS, "Ee") then  -- 'E'?
		Aux.CheckNext(LS, "+-")  -- optional exponent sign
	end
	while string.find(LS.Current, "^%w$") or LS.Current == "_" do
		Aux.SaveThenNext(LS)
	end
	Aux.ReplaceBuffer(LS, ".", LS.DecPoint)  -- follow locale for decimal point
	local seminfo = Aux.ToNumber(LS.Buffer)
	Token.SemanticInfo = seminfo
	if not seminfo then  -- format error?
		Aux.TryDecimal(LS, Token) -- try to update decimal point separator
	end
end

------------------------------------------------------------------------
-- reads a long comment
-- * if the language supports it
------------------------------------------------------------------------
function Aux.ReadLongComment(LS, ending)
	local endrest = (ending):split('')
	local endsign = table.remove(endrest, 1)
	while true do
		local c = LS.Current
		if c == "<eoz>" then
			LS:LexError(LS, "unfinished long comment", "<eos>")
		elseif c == endsign then
			local done = false
			for n , punct in endrest do
				if Aux.NextChar(LS) ~= punct then break end
				if n == #endrest then done = true end
			end
			if done then break end
		elseif Aux.IsAtNewLine(LS) then
			Aux.IncLineCounter(LS)
		else
			Aux.NextChar(LS)
		end--if c
	end--while
	LS.Buffer = ""
	Aux.NextChar(LS)
end

------------------------------------------------------------------------
-- reads a long string
-- * if the language supports it
------------------------------------------------------------------------
function Aux.ReadLongString(LS, Token, ending)
	local endrest = (ending):split('')
	local endsign = table.remove(endrest, 1)
	LS.Buffer = ""
	while true do
		local c = LS.Current
		if c == "<eoz>" then
			LS:LexError(LS, "unfinished long string", "<eos>")
		elseif c == endsign then
			local done = false
			for n , punct in endrest do
				if Aux.NextChar(LS) ~= punct then break end
				if n == #endrest then done = true end
			end
			if done then break end
		elseif Aux.IsAtNewLine(LS) then
			Aux.IncLineCounter(LS)
		else
			Aux.SaveThenNext(LS)
		end--if c
	end--while
	Aux.NextChar(LS)
end

------------------------------------------------------------------------
-- reads a string
-- * ccuser44 was here to add support for UTF8 string literals,
-- hex numerical string literals and the \z string literal
------------------------------------------------------------------------

function Aux.ReadString(LS, del, Token)
	Aux.SaveThenNext(LS)
	while LS.Current ~= del do
		local c = LS.Current
		if c == "<eoz>" then
			LS:LexError(LS, "unfinished string", "<eos>")
		elseif Aux.IsAtNewLine(LS) then
			LS:LexError(LS, "unfinished string", "<string>")
		elseif c == "\\" then
			c = Aux.NextChar(LS)  -- do not save the '\'
			if Aux.IsAtNewLine(LS) then  -- go through
				Aux.SaveChar(LS, "\n")
				Aux.IncLineCounter(LS)
			elseif c ~= "<eoz>" then -- will raise an error next loop
				-- escapes handling greatly simplified here:
				local i = string.find("abfnrtv", c, 1, 1)
				if i then
					Aux.SaveChar(LS, string.sub("\a\b\f\n\r\t\v", i, i))
					Aux.NextChar(LS)
				elseif c == "u" then -- UTF8 string literal
					assert(utf8 and utf8.char, "No utf8 library found! Cannot decode UTF8 string literal!")

					if Aux.NextChar(LS) ~= "{" then
						LS:LexError("Missing { bracket for UTF8 literal", "<string>")
					end

					local unicodeCharacter = ""

					while true do
						c = Aux.NextChar(LS)

						if c == "}" then
							break
						elseif string.match(c, "%x") then
							unicodeCharacter = unicodeCharacter .. c
						else
							LS:LexError(string.format("Invalid unicode character sequence. Expected alphanumeric character, got %s. Did you forget to close the code sequence with a curly bracket?", c), "<string>")
						end
					end

					if not tonumber(unicodeCharacter, 16) or not utf8.char(tonumber(unicodeCharacter, 16)) then
						LS:LexError(string.format("Invalid UTF8 char %s. Expected a valid UTF8 character code", unicodeCharacter), "<string>")
					else
						Aux.SaveChar(LS, utf8.char(tonumber(unicodeCharacter)))
					end
				elseif string.lower(c) == "x" then -- Hex numeral literal
					local hexNum = Aux.NextChar(LS)..Aux.NextChar(LS)

					if not string.match(string.upper(hexNum), "%x") then
						LS:LexError(string.format("Invalid hex string literal. Expected valid string literal, got %s", hexNum), "<string>")
					else
						Aux.SaveChar(LS, string.char(tonumber(hexNum, 16)))
					end
				elseif string.lower(c) == "z" then -- Support \z string literal. I'm not sure why you would want to use this
					local c = Aux.NextChar(LS)

					if c == del then
						break
					else
						Aux.SaveChar(LS, c)
					end
				elseif not string.find(c, "%d") then
					Aux.SaveThenNext(LS)  -- handles \\, \", \', and \?
				else  -- \xxx
					c, i = 0, 0
					repeat
						c = 10 * c + LS.Current
						Aux.NextChar(LS)
						i = i + 1
					until i >= 3 or not string.find(LS.Current, "%d")
					if c > 255 then  -- UCHAR_MAX
						LS:LexError(LS, "escape sequence too large", "<string>")
					end
					Aux.SaveChar(LS, string.char(c))
				end
			end
		else
			Aux.SaveThenNext(LS)
		end--if c
	end--while
	Aux.SaveThenNext(LS)  -- skip delimiter
	Token.SemanticInfo = string.sub(LS.Buffer, 2, -2)
end


return Aux

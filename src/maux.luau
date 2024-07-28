
--[=[
    ============ maux.lua ============
    Auxiliary functions for the lexer.
    Last Commited:	27/07/2024 - 11:00 PM
]=]

--!native
--!strict

--[=[
    * some features of the Lua lexer this was derived
      from are still here; might be changed in the future.
]=]

local Types = require(script.Parent.common)
type LexerState = Types.LexerState
type Token = Types.Token

local Aux = {}

function Aux.ChunkID(source : string, bufflen : number) : string
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

function Aux.IsAtNewLine(LS : LexerState) : boolean
	return LS.Current == "\n" or LS.Current == "\r"
end

function Aux.IncLineCounter(LS : LexerState)
	local old = LS.Current
	-- lua_assert(currIsNewline(LS))
	Aux.NextChar(LS)  -- skip '\n' or '\r'
	if Aux.IsAtNewLine(LS) and LS.Current ~= old then
		Aux.NextChar(LS)  -- skip '\n\r' or '\r\n'
	end
	LS.LineNumber = LS.LineNumber + 1
	if LS.LineNumber >= LS.MAX_INT then
		LS:SyntaxError("chunk has too many lines")
	end
end

------------------------------------------------------------------------
-- checks if current character read is found in the set 'set'
------------------------------------------------------------------------
function Aux.CheckNext(LS : LexerState, set) : boolean
	if not string.find(set, LS.Current, 1, true) then
		return false
	end
	Aux.SaveThenNext(LS)
	return true
end

------------------------------------------------------------------------
-- gets the next character and returns it; previously :nextc()
-- * this is the next() macro in llex.c; see notes at the beginning
------------------------------------------------------------------------
function Aux.NextChar(LS : LexerState) : string
	local c = LS.ZIO:GetChar()
	LS.Current = c
	return c
end

------------------------------------------------------------------------
-- saves the given character into the token buffer; previously :save()
-- * buffer handling code removed, not used in this implementation
-- * test for maximum token buffer length not used, makes things faster
------------------------------------------------------------------------

function Aux.SaveChar(LS : LexerState, c)
	local buff = LS.Buffer
	-- if you want to use this, please uncomment Lexer.MAX_SIZET further up
	--if #buff > LS.MAX_SIZET then
	--  LS:LexicalError("lexical element too long")
	--end
	LS.Buffer = buff..c
end

------------------------------------------------------------------------
-- save current character into token buffer, grabs next character
-- * like Aux.nextc, returns the character read for convenience
-- * previously :save_and_next()
------------------------------------------------------------------------
function Aux.SaveThenNext(LS : LexerState)
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
-- * ccuser44 was here to add support for binary integer constants
------------------------------------------------------------------------
function Aux.ToNumber(s) : number?
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
	elseif string.lower(string.sub(s, 1, 2)) == "0o" then  -- maybe an hexadecimal constant?
		result = tonumber(s:sub(3), 8)
		if result then return result end  -- least common case
	elseif string.lower(string.sub(s, 1, 2)) == "0b" then  -- binary integer constants
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
function Aux.ReplaceBuffer(LS : LexerState, from, to)
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
function Aux.TryDecimal(LS : LexerState, Token : Token)
	-- format error: try to update decimal point separator
	local old = LS.DecPoint
	-- translate the following to Lua if you implement localeconv():
	-- struct lconv *cv = localeconv();
	-- LS->decpoint = (cv ? cv->decimal_point[0] : '.');
	Aux.ReplaceBuffer(LS, old, LS.DecPoint)  -- try updated decimal separator
	local lexeme = Aux.ToNumber(LS.Buffer)
	Token.Lexeme = lexeme
	if not lexeme then
		-- format error with correct decimal point: no more options
		Aux.ReplaceBuffer(LS, LS.DecPoint, ".")  -- undo change (for error message)
		LS:LexicalError("malformed number", "TK_NUMBER")
	end
end

------------------------------------------------------------------------
-- main number conversion function
-- * "^%w$" needed in the scan in order to detect "<eoz>"
------------------------------------------------------------------------
function Aux.ReadNumeral(LS : LexerState, Token : Token)
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
	local lexeme = Aux.ToNumber(LS.Buffer)
	Token.Lexeme = lexeme
	if not lexeme then  -- format error?
		Aux.TryDecimal(LS, Token) -- try to update decimal point separator
	end
end

------------------------------------------------------------------------
-- reads a long string or comment
-- * if the language supports it
------------------------------------------------------------------------
function Aux.ReadLongText(LS : LexerState, ending : string)
	local endrest = (ending):split('')
	local endsign = table.remove(endrest, 1)
	LS.Buffer = ""
	
	while true do
		local c = LS.Current
		if c == "<eoz>" then
			LS:LexicalError("unfinished long text", "<eos>")
		elseif c == endsign then
			local matched = #endrest == 0
			for n , punct in endrest do
				if Aux.NextChar(LS) ~= punct then break end
				if n == #endrest then matched = true end
			end
			if matched then break end
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

function Aux.ReadString(LS : LexerState, del, Token : Token)
	Aux.SaveThenNext(LS)
	while LS.Current ~= del do
		local c = LS.Current
		if c == "<eoz>" then
			LS:LexicalError("unfinished string", "<eos>")
		elseif Aux.IsAtNewLine(LS) then
			LS:LexicalError("unfinished string", "<string>")
		elseif c == "\\" then
			local _c = Aux.NextChar(LS)  -- do not save the '\'
			if Aux.IsAtNewLine(LS) then  -- go through
				Aux.SaveChar(LS, "\n")
				Aux.IncLineCounter(LS)
			elseif _c ~= "<eoz>" then -- will raise an error next loop
				-- escapes handling greatly simplified here:
				local i = string.find("abfnrtv", c, 1, true)
				if i then
					Aux.SaveChar(LS, string.sub("\a\b\f\n\r\t\v", i, i))
					Aux.NextChar(LS)
				elseif _c == "u" then -- UTF8 string literal
					assert(utf8 and utf8.char, "No utf8 library found! Cannot decode UTF8 string literal!")

					if Aux.NextChar(LS) ~= "{" then
						LS:LexicalError("Missing { bracket for UTF8 literal", "<string>")
					end

					local unicodeCharacter = ""

					while true do
						local __c = Aux.NextChar(LS)

						if __c == "}" then
							break
						elseif string.match(__c, "%x") then
							unicodeCharacter ..= __c
						else
							LS:LexicalError(string.format("Invalid unicode character sequence. Expected alphanumeric character, got %s. Did you forget to close the code sequence with a curly bracket?", __c), "<string>")
						end
					end

					if not tonumber(unicodeCharacter, 16) or not utf8.char(tonumber(unicodeCharacter, 16) :: number) then
						LS:LexicalError(string.format("Invalid UTF8 char %s. Expected a valid UTF8 character code", unicodeCharacter), "<string>")
					else
						Aux.SaveChar(LS, utf8.char(tonumber(unicodeCharacter) :: number))
					end
				elseif string.lower(_c) == "x" then -- Hex numeral literal
					local hexNum = Aux.NextChar(LS)..Aux.NextChar(LS)

					if not string.match(string.upper(hexNum), "%x") then
						LS:LexicalError(string.format("Invalid hex string literal. Expected valid string literal, got %s", hexNum), "<string>")
					else
						Aux.SaveChar(LS, string.char(tonumber(hexNum, 16) :: number))
					end
				elseif string.lower(_c) == "z" then -- Support \z string literal. I'm not sure why you would want to use this
					local __c = Aux.NextChar(LS)
					if __c == del then break else
						Aux.SaveChar(LS, __c)
					end
				elseif not string.find(_c, "%d") then
					Aux.SaveThenNext(LS)  -- handles \\, \", \', and \?
				else  -- \xxx
					local __c, _i = 0, 0
					repeat
						__c = 10 * __c + string.byte(LS.Current)
						Aux.NextChar(LS)
						_i = _i + 1
					until _i >= 3 or not string.find(LS.Current, "%d")
					if __c > 255 then  -- UCHAR_MAX
						LS:LexicalError("escape sequence too large", "<string>")
					end
					Aux.SaveChar(LS, string.char(__c))
				end
			end
		else
			Aux.SaveThenNext(LS)
		end--if c
	end--while
	Aux.SaveThenNext(LS)  -- skip delimiter
	Token.Lexeme = string.sub(LS.Buffer, 2, -2)
end


return Aux
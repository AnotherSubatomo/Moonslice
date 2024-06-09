
--[=[
    ========== Moonslice ==========
    Similar to the actual `Lex`
    program, this module generates
    a lexical analyzer given a
    a set of regular expressions,
    rules, and tokens from a
    specific syntax.

    By:             @AnotherSubatomo (GitHub)
    Version:        1.1.0
    Last Commited:  09/06/2024 - 7:34 PM

    SPDX-License-Identifier: MIT
]=]

--[=[
    NOTICE
    
    To use the lexer:
    (1) Give a set of RegEx the lexers will be based on.
    (2) Call Lexer:Set() on the returned lexer API to
        set the general state and input stream of the lexer.
    (3) call Lexer:Next() or Lexer:Lexer:Lookahead() to get tokens,
        until "<eos>" or "<eoz>"
]=]

local Exception = {
	"Expression for defining long comments was invalid; should be formatted as \"{START}{END}\"" ,
	"Expression for defining long strings was invalid; should be formatted as \"{START}{END}\"" ,
	"%q cannot be used for declaring strings as they must only be a single character long."
}

local Aux = require(script and script.maux or "./maux.lua")
local ZIO = require(script and script.mzio or "./mzio.lua")
for k, v in Aux do _G[k] = v end

local function SanitizeLexicon( Lexicon )
	-- # Symbols used for declaring strings must
	--   only be a single character (might change)
	for _ , Operator in Lexicon.Strings do
		assert( #Operator == 1 , Exception[3]:format(Operator) )
	end
end

local function ConstructSemantics( Lexicon )
	-- # Semantics of the lexer, to be returned
	local Semantics = {
		OprProgs = {} ,                 -- should be a procedural arragement of related symbols
		Tokens = {} ,                   -- a validation look-up table
	}
	
	-- # Make validation look-up table
	for _ , Keyword : string in Lexicon.Keywords do
		Semantics.Tokens[Keyword] = true
	end

	-- # Process the comment expressions
	if Lexicon.Comments and Lexicon.Comments.Long then
		local Start, End = (Lexicon.Comments.Long):match("{(.*)}{(.*)}")
		assert( Start and End , Exception[1] )
		-- These need to have their progressions too
		table.insert(Lexicon.Operators, Lexicon.Comments.Short)
		table.insert(Lexicon.Operators, Start)
		table.insert(Lexicon.Operators, End)
		-- For the lexer to be able to recognize
		-- the operators post progressive recognition
		Semantics.ShortComment = Lexicon.Comments.Short
		Semantics.LongCommentStart = Start
		Semantics.LongCommentEnd = End
	end
	
	-- # Process the string expressions...
	if Lexicon.LongStrings then
		local Start, End = (Lexicon.LongStrings):match("{(.*)}{(.*)}")
		assert( Start and End , Exception[2] )
		-- These need to have their progressions too
		table.insert(Lexicon.Operators, Start)
		table.insert(Lexicon.Operators, End)
		-- For the lexer to be able to recognize
		-- the operators post progressive recognition
		Semantics.LongStringStart = Start
		Semantics.LongStringEnd = End
	end
	
	-- # and char expressions too
	if Lexicon.Chars then
		table.insert(Lexicon.Operators, Lexicon.Chars)
	end

	-- # For the creation of a progression table
	-- # used for the deduction of a punctual lexeme
	local __PuncGroups = {}             -- phase 1

	for __ , Operator in Lexicon.Operators do
		local Group = (Operator):sub(1,1)
		if not __PuncGroups[Group] then
			__PuncGroups[Group] = {}
		end
		table.insert(__PuncGroups[Group], Operator)
	end

	-- # For all punctual lexemes of their respective group...
	for Parent , Group in __PuncGroups do
		-- # Sort them from shortest to longest
		table.sort(Group, function(a, b)
			return a < b
		end)

		-- # Transform into a progression table
		local Progression = {}
		for _ , Lexeme in Group do
			local Scope = Progression
			local Indexes = (Lexeme):split("")
			table.remove(Indexes, 1)

			for __ : number , Index : string in Indexes do
				if not Scope[Index] then
					Scope[Index] = {}
				end
				Scope = Scope[Index]
			end
		end
		
		Semantics.OprProgs[Parent] = Progression
	end


	return Semantics
end

local function EvaluatePunctualExpressions( LS , BaseOpr , OprProg )
	_G.NextChar(LS)
	for Punct , NextPuncts in OprProg do
		if LS.Current ~= Punct then continue end
		return BaseOpr..EvaluatePunctualExpressions(LS, Punct, NextPuncts)
	end
	return BaseOpr
end

--[=[==========================]=]
--[=[ Lexer generator function ]=]
--[=[==========================]=]

return function ( Lexicon )
	SanitizeLexicon(Lexicon)
	local Semantics = ConstructSemantics(Lexicon)

	-- // Construct the lexer based on the ruleset
	local function Lex( LS , Token )
		LS.Buffer = ""
		while true do
			local C = LS.Current
			if _G.IsAtNewLine(LS) then
				_G.IncLineCounter(LS)
			elseif string.find(C, "%p") then
				for BaseOpr , OprProg in Semantics.OprProgs do
					if C ~= BaseOpr then continue end
					local Operator = EvaluatePunctualExpressions(LS, BaseOpr, OprProg)
					if Operator == Semantics.ShortComment then  -- short comment
						while not _G.IsAtNewLine(LS) and LS.Current ~= "<eoz>" do
							_G.NextChar(LS)
						end
						LS.Buffer = ""
						return "<comment>"
					elseif Operator == Semantics.LongCommentStart then  -- long comment
						_G.ReadLongComment(LS, Semantics.LongCommentEnd)
						return "<comment>"
					elseif Operator == Lexicon.Chars then  -- character
						_G.SaveThenNext(LS)
						for _ = 1, #Lexicon.Chars do _G.NextChar(LS) end
						return "<char>"
					elseif Operator == Semantics.LongStringStart then  -- long string
						_G.ReadLongString(LS, Token, Semantics.LongStringEnd)
						return "<string>"
					else
						return Operator
					end
				end
				if table.find(Lexicon.Strings, C) then
					_G.ReadString(LS, C, Token)
					return "<string>"
				end
				_G.NextChar(LS)
				return C  -- single-char tokens (+ - / ...)
				
			elseif string.find(C, "%s") then  -- whitespace, skip
				_G.NextChar(LS)
			elseif string.find(C, "%d") then  -- number
				_G.ReadNumeral(LS, Token)
				return "<number>"
			elseif string.find(C, "[_%a]") then  -- name or reserved word
				repeat
					C = _G.SaveThenNext(LS)
				until C == "<eoz>" or not string.find(C, "[_%w]")
				local SemanticInfo = LS.Buffer
				local IsKeyword = Semantics.Tokens[SemanticInfo]
				if IsKeyword then return SemanticInfo end  -- reserved word
				Token.SemanticInfo = SemanticInfo
				return "<name>"  -- else name
			end
		end
	end

	-- // Lexer API construction
	local Lexer = {}

	function Lexer:Next()
		self.LastLine =  self.LineNumber
		if self.Ahead.Token ~= "<eos>" then  -- is there a look-ahead token?
			-- use it's data instead
			self.Now.SemanticInfo =  self.Ahead.SemanticInfo
			self.Now.Token =  self.Ahead.Token
			self.Ahead.Token = "<eos>"  -- and discharge it
		else
			self.Now.Token = Lex(self,  self.Now)  -- read next token
		end
	end

	function Lexer:Lookahead()
		self.Ahead.Token = Lex(self, self.Ahead)
	end

	-- // For producing errors
	function Lexer:LexError( msg , Token )
		local function Specify(Token)
			if  Token == "<name>" or
				Token == "<string>" or
				Token == "<number>" then
				return self.Buffer
			else
				return Token
			end
		end

		local buff = _G.ChunkID(self, self.Source, self.MAXSRC)
		local msg = string.format("%s:%d: %s", buff,  self.LineNumber, msg)
		if Token then
			msg = string.format("%s near "..self.QS, msg, Specify(Token))
		end
		error(msg)
	end

	function Lexer:SyntaxError( msg )
		self:LexError(msg, self.Now.Token)
	end

	-- // Function for setting lexer context
	function Lexer:Set( State , Source , Filename )
		-- // IO
		local Z = ZIO.new(ZIO:MakeReader(Source), nil, Filename)
		
		-- // State Configuration
		self.MAXSRC = 80
		self.MAX_INT = 2147483645
		self.QS = "'%s'"
		self.COMPAT_LSTR = 1
		self.MAX_SIZET = 4294967293

		-- // State
		self.Ahead = {}             -- # next token
		self.Ahead.Token = "<eos>"  -- # [default "nothing next" token]
		self.Now = {}                   -- # current token
		self.DecPoint = "."             -- # decimal point symbol used
		self.State = State              -- # general language state
		self.ZIO = Z                    -- # input reader
		self.FS = nil                   -- # function state
		self.Buffer = nil               -- # collected characters (not whitespace)
		self.Current = nil              -- # current character
		self.LineNumber = 1             -- # current line in source
		self.LastLine = 1               -- # last line in source
		self.Source = Filename          -- # source's file name (confusing ik srry...)
		_G.NextChar(self)
	end

	-- // Return lexer
	return Lexer
end

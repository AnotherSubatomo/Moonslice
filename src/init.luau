
--[=[
    ========== Moonslice ==========
    Similar to the actual `Lex`
    program, this module generates
    a lexical analyzer given what
	is called a 'Lexicon' (type found
	in common.luau).
    
    Author:			@AnotherSubatomo (GitHub)
    Version:		0.3.2
    Last Commited:	27/07/2024 - 11:00 PM

    SPDX-License-Identifier: MIT
]=]

--!native
--!nonstrict

--[=[
    NOTICE
    
    To use the lexer:
    (1) Give a 'Lexicon' the lexers will be based on.
    (2) Call Lexer:Set() on the returned lexer API to
        set the general state and input stream of the lexer.
    (3) call Lexer:Next() or Lexer:Lexer:Lookahead() to get tokens,
        until "<eos>" or "<eoz>"
]=]

local Types = require(script.common)
local Aux = require(script.maux)
local ZIO = require(script.mzio)

-- # Vocabulary of the language
export type Lexicon = {
	Version : number? ,
	Keywords : { string } ,
	Operators : { string } ,
	Comments : {
		Short : string ,
		Long : string?
	} ,
	Strings : {
		Short : { string } ,
		Long : string?
	} ,
	Chars : string? ,
	Literals : boolean?
}

type OprTree = {[string] : OprTree} | {}

-- # The 'sense' of the lexicon of the language
export type Semantics = {
	OprProgs : OprTree ,				 -- purely punctual reserved lexemes organized into a tree (progression table)
	IsKeyword : { [string] : boolean } , -- an 'is a keyword' map
	ShortString : string , 				 -- short string definers turned into a string set
	ShortComment : string ,
	LongStringStart : string? ,
	LongStringEnd : string? ,
	LongCommentStart : string? ,
	LongCommentEnd : string?
}

export type Token = Types.Token
export type LexerState = Types.LexerState

local Exception = {
	"Expression for defining long %ss was invalid; should be formatted as \"{START}{END}\"" ,
	"%q cannot be used for delimiting must only be a single character long." ,
	"Having non-alphabetic characters in your keyword (ex. %q) is bad design." ,
	"Having non-punctual characters in your keyword (ex. %q) is bad design." ,
	"Using more than one character for declaring a %s (ex. %q) is bad design."
}

-- // Looks out for potential bad designs in the lexicon
local function SanitizeLexicon( Lexicon : Lexicon )
	-- # Keywords must only be made of
	--	 alphabetic characters
	for _ , Keyword : string in Lexicon.Keywords do
		local Valid = #(Keyword:match("%a*") or "") == #Keyword
		assert( Valid , Exception[3]:format(Keyword) )
	end
	-- # Operators must only be made of
	--	 punctuation characters
	for _ , Operator : string in Lexicon.Operators do
		local Valid = #(Operator:match("%p*") or "") == #Operator
		assert( Valid , Exception[4]:format(Operator) )
	end
	-- # Symbols used for declaring short strings must
	--   only be a single character
	for _ , Operator : string in Lexicon.Strings.Short do
		assert( #Operator == 1 , Exception[5]:format('short string', Operator) )
	end

	-- # Symbol used for declaring chars must
	--   only be a single character
	if Lexicon.Chars then
		assert( #Lexicon.Chars == 1 , Exception[5]:format('char', Lexicon.Chars) )
	end
end

local function ConstructSemantics( Lexicon : Lexicon ) : Semantics
	local Semantics = { OprProgs = {} , IsKeyword = {} }
	
	-- # Temporary bucket for all operators
	local Operators = table.clone(Lexicon.Operators);

	-- # Make validation map
	for _ , Keyword : string in Lexicon.Keywords do
		Semantics.IsKeyword[Keyword] = true
	end

	-- # Process the comment expressions
	if Lexicon.Comments and Lexicon.Comments.Long then
		-- Make sure theres symbols for each start and end
		local Start, End = (Lexicon.Comments.Long):match("{(.*)}{(.*)}")
		assert( Start and End , Exception[1]:format('comment') )
		-- These need to have their progressions too
		table.insert(Operators, Start)
		table.insert(Operators, End)
		-- For the lexer to be able to recognize
		-- the operators post-progressive recognition
		Semantics.LongCommentStart = Start
		Semantics.LongCommentEnd = End
	end

	if Lexicon.Comments and Lexicon.Comments.Short then
		table.insert(Operators, Lexicon.Comments.Short)
		Semantics.ShortComment = Lexicon.Comments.Short
	end
	
	-- # Process the string expressions...
	if Lexicon.Strings.Long then
		-- Make sure theres symbols for each start and end
		local Start, End = (Lexicon.Strings.Long):match("{(.*)}{(.*)}")
		assert( Start and End , Exception[1]:format('string') )
		-- These need to have their progressions too
		table.insert(Operators, Start)
		table.insert(Operators, End)
		-- For the lexer to be able to recognize
		-- the operators post-progressive recognition
		Semantics.LongStringStart = Start
		Semantics.LongStringEnd = End
	end

	if Lexicon.Strings.Short then
		Semantics.ShortString = table.concat(Lexicon.Strings.Short, '')
	end
	
	-- # and char expressions too
	if Lexicon.Chars then
		table.insert(Operators, Lexicon.Chars)
	end

	-- # For the creation of a progression table
	-- # used for the deduction of a punctual lexeme
	local __PuncGroups = {}             -- phase 1

	-- # classify each operator by their first char
	for __ , Operator : string in Operators do
		local Class = (Operator):sub(1,1)
		if not __PuncGroups[Class] then
			__PuncGroups[Class] = {}
		end
		table.insert(__PuncGroups[Class], Operator)
	end

	-- # For all punctual lexemes of their respective group...
	for Class : string , Group : {string} in __PuncGroups do
		-- # Sort them from shortest to longest
		table.sort(Group, function(a, b)
			return a < b
		end)

		-- # Transform into a progression table
		local Progression = {}
		for _ : number , Lexeme : string in Group do
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
		
		Semantics.OprProgs[Class] = Progression
	end


	return Semantics :: Semantics
end

local function EvaluatePunctualExpressions( LS : LexerState , BaseOpr :  string , OprProg : OprTree )
	Aux.NextChar(LS)
	for Punct : string , NextPuncts in pairs(OprProg) do
		if LS.Current ~= Punct then continue end
		return BaseOpr..EvaluatePunctualExpressions(LS, Punct, NextPuncts)
	end
	return BaseOpr
end

--[=[==========================]=]
--[=[ Lexer generator function ]=]
--[=[==========================]=]

return function ( Lexicon : Lexicon )
	SanitizeLexicon(Lexicon)
	local Semantics = ConstructSemantics(Lexicon)

	-- // Construct the lexer based on the ruleset
	local function Lex( LS : LexerState , Token : Token )
		LS.Buffer = ""
		while true do
			local C = LS.Current
			if Aux.IsAtNewLine(LS) then
				Aux.IncLineCounter(LS)
			elseif string.find(C, "%p") then
				
				for BaseOpr : string , OprProg : {} in Semantics.OprProgs do
					if C ~= BaseOpr then continue end
					local Operator = EvaluatePunctualExpressions(LS, BaseOpr, OprProg)
					
					if Operator == Semantics.ShortComment then  -- short comment
						LS.Buffer = ""
						while not Aux.IsAtNewLine(LS) and LS.Current ~= "<eoz>" do
							Aux.SaveThenNext(LS)
						end
						Token.Lexeme = LS.Buffer
						return "<comment>"
					elseif Operator == Lexicon.Chars then  -- character
						Aux.SaveThenNext(LS)
						Aux.NextChar(LS)
						return "<char>"
					elseif Operator == Semantics.LongCommentStart then  -- long comment
						Aux.ReadLongText(LS, Semantics.LongCommentEnd)
						Token.Lexeme = LS.Buffer
						return "<comment>"
					elseif Operator == Semantics.LongStringStart then  -- long string
						Aux.ReadLongText(LS, Semantics.LongStringEnd)
						Token.Lexeme = LS.Buffer
						return "<string>"
					else
						return Operator
					end
				end
				
				if Aux.CheckNext(LS, Semantics.ShortString) then
					Aux.ReadString(LS, C, Token)
					return "<string>"
				end
				
				Aux.NextChar(LS)
				return C  -- single-char tokens (+ - / ...)
			elseif string.find(C, "%s") then  -- whitespace, skip
				Aux.NextChar(LS)
			elseif string.find(C, "%d") then  -- number
				Aux.ReadNumeral(LS, Token)
				return "<number>"
			elseif string.find(C, "[_%a]") then  -- name or reserved word
				repeat
					C = Aux.SaveThenNext(LS)
				until C == "<eoz>" or not string.find(C, "[_%w]")
				local Lexeme = LS.Buffer
				local IsKeyword = Semantics.IsKeyword[Lexeme]
				if IsKeyword then return Lexeme end  -- reserved word
				Token.Lexeme = Lexeme
				return "<name>"  -- else name
			end
		end
	end

	-- // Lexer API construction
	local Lexer = {}

	function Lexer:Next()
		self.LastLine =  self.LineNumber
		if self.Ahead.Type ~= "<eos>" then  -- is there a look-ahead token?
			-- use it's data instead
			self.Now.Lexeme =  self.Ahead.Lexeme
			self.Now.Type =  self.Ahead.Type
			self.Ahead.Type = "<eos>"  -- and discharge it
		else
			self.Now.Type = Lex(self,  self.Now)  -- read next token
		end
	end

	function Lexer:Lookahead()
		self.Ahead.Type = Lex(self, self.Ahead)
	end

	-- // For producing errors
	function Lexer:LexicalError( Message : string , TokenType : string? )
		local SpecifiedType = TokenType
		
		if  TokenType == "<name>" or
			TokenType == "<string>" or
			TokenType == "<number>" then
			SpecifiedType = self.Buffer
		end

		local buff = Aux.ChunkID(self.Source, self.MAXSRC)
		local ErrorMessage = string.format("%s:%d: %s", buff,  self.LineNumber, Message)
		if TokenType then
			ErrorMessage = string.format("%s near "..self.QS, ErrorMessage, SpecifiedType)
		end
		error(ErrorMessage)
	end

	function Lexer:SyntaxError( Message : string )
		self:LexicalError(Message, self.Now.Type)
	end

	-- // Function for setting lexer context
	-- * MUST BE CALLED BEFORE ANYTHING ELSE!
	function Lexer:Set( State : {} , Source : string , Filename : string )
		-- // IO
		local Z = ZIO.new(Source, nil, Filename)
		
		-- // Lexer State Configuration
		self.MAXSRC = 80
		self.MAX_INT = 2147483645
		self.QS = "'%s'"
		self.SUPPORT_STR_LIT = Lexicon.Literals
		self.MAX_SIZET = 4294967293

		-- // Lexer State
		self.Ahead = {}                 -- # next token
		self.Ahead.Type = "<eos>"      -- # [default "nothing next" token]
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
		Aux.NextChar(self)
	end

	-- // Return lexer
	return Lexer :: typeof(Lexer)
end
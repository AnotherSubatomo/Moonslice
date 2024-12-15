
--[=[
	Contains the lexer object's proto
    Last Commited:	15/12/2024 - 7:24 PM
]=]

--!native
--!strict

local root = script.Parent
local Types = require(root.common)
local Aux = require(root.maux)
local ZIO = require(root.mzio)

type Token = Types.Token
type Tokenizer = Types.Tokenizer
type LexerState = Types.LexerState

local Lexer = {}

function Lexer:Next()
	self.LastLine =  self.LineNumber
	-- Is there a look-ahead token? If so...
	if (self.Ahead.Type ~= "<eos>") :: boolean then -- * not typesetting this will error
		-- use it's data instead
		self.Now.Lexeme =  self.Ahead.Lexeme
		self.Now.Type =  self.Ahead.Type
		self.Ahead.Type = "<eos>"  -- and discharge it
	else
		self.Now.Type = self.__Lex(self,  self.Now)  -- read next token
	end
end

function Lexer:Lookahead()
	self.Ahead.Type = self.__Lex(self, self.Ahead)
end

-- // For producing errors
function Lexer:LexicalError( Message : string , TokenType : string? )
	local SpecifiedType = TokenType
	
	if  TokenType == "<name>" or
		TokenType == "<string>" or
		TokenType == "<number>" then
		SpecifiedType = self.Buffer
	end

	local ErrorMessage = string.format("%s:%d: %s", self.Source,  self.LineNumber, Message)
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
	self.MAX_SIZET = 4294967293

	-- // Lexer State
	self.Ahead = {} :: Token        -- # next token
	self.Ahead.Type = "<eos>"       -- # [default "nothing next" token]
	self.Now = {} :: Token          -- # current token
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

return function (tokenizer: Tokenizer , support_literals: boolean?)
	local self = setmetatable({}, {__index = Lexer})
	self.__Lex = tokenizer
	self.SUPPORT_STR_LIT = support_literals
	return self
end
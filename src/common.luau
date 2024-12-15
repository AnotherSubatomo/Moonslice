
--[=[
	File that holds types found across scripts.
    Last Commited:	15/12/2024 - 7:24 PM
]=]

--!native
--!strict

local ZIO = require(script.Parent.mzio)

-- # Token structure
export type Token = {
	Lexeme : (string | number)? ,
	Type : string
}

-- * A function that updates a token structure to reflect
--   the current token it has parsed from the source text
export type Tokenizer = (LS: LexerState, Token: Token) -> string

-- # Lexer object structure
export type LexerState = {
	Next : ( LexerState , LexemeInfo : {} ) -> nil ,
	Lookahead : ( LexerState , LexemeInfo : {} ) -> nil ,
	LexicalError : ( LexerState , Message : string, Token : any ) -> nil ,
	SyntaxError : ( LexerState , Message : string ) -> nil ,
	__Lex : Tokenizer ,

	MAXSRC : number ,
	MAX_INT : number ,
	QS : string ,
	SUPPORT_STR_LIT : boolean ,
	MAX_SIZET : number ,

	State : {} ,
	Now : Token ,
	Ahead : Token ,
	LineNumber : number ,
	LastLine : number ,
	DecPoint : string ,
	Buffer : string ,
	Current : string ,
	Source : string ,
	ZIO : ZIO.Z
}

return true
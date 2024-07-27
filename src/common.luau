
--[=[
	File that holds types found across scripts.
    Last Commited:	27/07/2024 - 11:00 PM
]=]

--!strict
--!native
local ZIO = require(script.Parent.mzio)

-- # Token structure
export type Token = {
	Lexeme : (string | number)? ,
	Type : string
}

-- # Lexer object structure
export type LexerState = {
	Next : ( LexerState , LexemeInfo : {} ) -> nil ,
	Lookahead : ( LexerState , LexemeInfo : {} ) -> nil ,
	LexicalError : ( LexerState , Message : string, Token : any ) -> nil ,
	SyntaxError : ( LexerState , Message : string ) -> nil ,

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
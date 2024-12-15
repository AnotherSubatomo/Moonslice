
--[=[
	An example on how to use Moonslice.
	Author:		@AnotherSubatomo (GitHub)
]=]

local CLexicon = {
	Version = 1 ,
	Keywords = {
		"auto" ,
		"register" ,
		"extern" ,
		"static" ,
		"typedef" ,
		"enum" ,
		"switch" ,
		"case" ,
		"default" ,
		"if" ,
		"else" ,
		"for" ,
		"continue" ,
		"while" ,
		"do" ,
		"break" ,
		"return" ,
		"goto" ,
		"float" ,
		"double" ,
		"long" ,
		"short" ,
		"unsigned" ,
		"signed" ,
		"char" ,
		"int" ,
		"void" ,
		"union" ,
		"struct" ,
		"volatile" ,
		"const" ,
		"false" ,
		"true" ,
		"null"
	} ,
	Operators = {
		"++" ,
		"--" ,
		"&&" ,
		"!" ,
		"||" ,
		"==" ,
		">=" ,
		"<=" ,
		"!=" ,
		"+=" ,
		"-=" ,
		"*=" ,
		"/=" ,
		"%=" ,
		"^=" ,
		"&=" ,
		"|=" ,
		">>=" ,
		"<<=" ,
		">>" ,
		"<<"
	},
	Comments = {
		Short = "//" ,
		Long = "{/*}{*/}"
	},
	Strings = {
		Short = {"\""}
	},
	Chars = "'"
}

local Source = [[
/* Type your code here, or load an example. */
int square(int num) {
	num >>= 10;
    return num * num;
}

int main () {
    int a = square(1);
    return 0;
}
]]

local Lex = require(game.ReplicatedStorage.Moonslice)
local Lexer = Lex(CLexicon)
local State = {}

Lexer:Set(State, Source, "@example")

while Lexer.Now.Type ~= "<eoz>" do
	-- # Depending on the length of the token's lexeme,
	--	 tokens take about 1/175 to 1 of a millisecond
	--	 on average to get, blazingly fast isnt it?
	local Tick = os.clock()
	Lexer:Next()
	warn(`Tock!: {(os.clock() - Tick) * 1000} ms`)
	print(Lexer.Now)
end
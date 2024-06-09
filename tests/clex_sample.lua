
--[=[
	========== clex ==========
	The lexicon of C23.
	
	By:				@AnotherSubatomo (GitHub)
	Version:		23 (C)
	Last Committed:	09/06/2024 - 6:03 PM
]=]

return {{
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
		"\"" ,
	},
	LongStrings = nil ,
	Chars = "'"
}, [[
// Type your code here, or load an example.
int square(int num) {
	num >>= 10;
    return num * num;
}

int main () {
    int a = square(1);
    return 0;
}
]]}

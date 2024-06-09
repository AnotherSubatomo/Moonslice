
--[=[
	========== Yuepian ==========
	Isolated script for debuging
	Moonslice.
	
    Last Commited:  09/06/2024 - 6:04 PM
]=]

local Lex = require(script and script.Parent or "../src-lua/Moonslice.lua")

local Lexicon, Source = unpack(require(script and script.clex_sample or "./clex_sample.lua"))

local Lexer = Lex(Lexicon)
local State = {}
Lexer:Set({}, Source, "@yuepian")

while Lexer.Now.Token ~= "<eoz>" do
	Lexer:Next()
	print(Lexer.Now.Token)
end

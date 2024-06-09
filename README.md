# Moonslice
A lexical analyzer generator in Lua and Luau.
Similar to the actual `Lex` program, this module generates a lexical analyzer **but** given a what is called a `Lexicon`.

A `Lexicon` of a language is structured like this:
```lua
type Lexicon = {
	Version : number? ,      -- # optional, might be important if I change the way a **Lexicon** is made
	Keywords : { string } ,  -- # eg. "if", "while", "break"
	Operators : { string } , -- # eg. "&&", "||", "=="
	Comments : {
		Short : string ,
		Long : string ,        -- # must be formatted as "{START}{END}"
	} ,
	Strings : { string } ,   -- # each symbol for string declaration must only be a single char long
	LongStrings : string? ,  -- # must be formatted as "{START}{END}"
	Chars : string?          -- # if the language has a seperate definition for chars
}
```

<br>

Requiring `Moonslice` will return a function that takes in this `Lexicon` and outputs a lexer with the following methods:
- `:Next()` — Gets the next `TokenValue`.
- `:Lookahead()` — Peeks the next `TokenValue`.
- `:LexError()` — Produces a lexical error given a `Message` and `Token`.
- `:SyntaxError()` — Produces a syntax error given a `Message`.

...and the following properties:
- `Now` — The current `TokenValue` being viewed.
- `Ahead` — A peek of the next `TokenValue`, if there is any token to be peeked.
- `LineNumber` — The current line the lexer is in.

_P.S.: These are not **all** of the properties, but the one you might find of use._

<br>

A `TokenValue` is structured like this:
```lua
type TokenValue = {
  SemanticInfo : string? ,    -- # Usually holds the identifier (name)
  Token :  string             -- # Very value which gives meaning to the structure
}
```
---
### Constraints
Specific things will always have the same token outputed by lexer design, so please watch out for the following constraints:
- Anything identified as a string will always have the token `<string>`
- Anything identified as a number will always have the token `<number>`
- Anything identified as a identifier/name will always have the token `<name>`
- Anything identified as a character will always have the token `<char>`
- Anything identified as a comment will always have the token `<comment>`
- If the ZIO runs out of things to read, it will output `<eoz>`, meaning **end of ZIO**.

---
### Why
This module was actually a side-product another project of mine, where I attempt to port other languages into the Roblox environment by creating compilers written in Lua _(The LCC Project)_, which all output a standard bytecode _(The LuASM Project)_.

If you have an eye for possible optimizations, bug fixes, or improvements, please feel free to contribute as this project is **open-source**. 😊

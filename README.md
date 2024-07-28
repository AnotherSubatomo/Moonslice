# Moonslice
A lexical analyzer generator in Luau.
Similar to the actual `Lex` program, this module generates a lexical analyzer **but** given a what is called a `Lexicon`.

A `Lexicon` of a language is structured like this:
```lua
type Lexicon = {
	Version : number? ,      -- # optional, might be important if I change the way a **Lexicon** is made
	Keywords : { string } ,  -- # eg. "if", "while", "break"
	Operators : { string } , -- # eg. "&&", "||", "=="
	Comments : {
		Short : string ,
		Long : string?       -- # must be formatted as "{START}{END}"
	} ,
	Strings : {
		Short : { string } , -- # each symbol for string declaration must only be a single char long
		Long : string?       -- # must be formatted as "{START}{END}"
	} ,
	Chars : string? ,        -- # if the language has a seperate definition for chars
	Literals : boolean?      -- # if the language supports the use of special characters in strings or not
}
```

<br>

Requiring `Moonslice` will return a function that takes in this `Lexicon` and outputs a lexer object with the following methods:
- `:Set()` — Initializes the lexer, **must be ran immidiately after creating a lexer**.
- `:Next()` — Gets the next `Token`.
- `:Lookahead()` — Peeks the next `Token`.
- `:LexError()` — Produces a lexical error given a `Message` and `Token`.
- `:SyntaxError()` — Produces a syntax error given a `Message`.

...and the following properties:
- `Now` — The current `Token` being viewed.
- `Ahead` — A peek of the next `Token`, if there is any token to be peeked.
- `LineNumber` — The current line the lexer is in.

_P.S.: These are not **all** of the properties, but the ones you might find of use._

<br>

A `Token` is structured like this:
```lua
type Token = {
  Lexeme : (string | number)? , -- # The last literal string or number met
  Type :  string                -- # Token type
}
```
---
### Constraints
Specific things will always have the same token outputed by lexer design, so please watch out for the following constraints:
- Anything identified as a string will always have the token type `<string>`
- Anything identified as a number will always have the token type `<number>`
- Anything identified as a identifier/name will always have the token type `<name>`
- Anything identified as a character will always have the token type `<char>`
- Anything identified as a comment will always have the token type `<comment>`
- If the ZIO runs out of things to read, the token's type constantly be `<eoz>`, meaning **end of ZIO**.

_* Comments are never skipped, as they might be used for features like directives._

_* Literal numbers are automatically converted into numbers (Hence why `Token.Lexeme` can be a number). Octals, hexadecimal and binary are supported._

---
### Installation

Installation can be easily done by either downloading the latest release and importing it directly into studio or by using [Wally]().

If you're using Wally, simply add `Moonslice = "anothersubatomo/moonslice@0.3.2"` to your dependencies at the `wally.toml` file and run `wally install`.

---
### Why
This module was actually a side-product another project of mine — *Eclipse* (formerly LCC and LuASM) — which you can think of as the "lesser-ambitious" version of LLVM. It has a set of compilers, a compiler infrastructure, and toolchains, all written in Luau. Why? Because (1) It allows Roblox experiences that are focused on teaching people how to program in different languages can actually sandbox the code. (2) I am a compiler nerd, and (3) why not?

If you have an eye for possible optimizations, bug fixes, or improvements, please feel free to contribute as this project is *open-source*. 😊
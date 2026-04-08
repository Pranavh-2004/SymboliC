# PE3 - Symbol Table Using Flex/Bison

This project implements a C-subset symbol table using:
- `flex` for lexical analysis
- `bison` for parsing declarations, function definitions, and blocks

## Captured Symbol Fields
For each identifier/tag/constant the table records:
- `Name`
- `Kind`: variable/function/parameter/typedef/enum-const/struct-tag/union-tag
- `Type`: base + declarator info (pointers, arrays, function signatures)
- `Storage class`: auto/static/extern/register
- `Size in bytes`
- `Scope`: level + scope label (`global`, `function:<name>`, `block`)
- `Definition location`: file + line + column
- `Use-sites`: recorded from expression references
- `Initializer`: constant value when computable, otherwise `null`

## Build
```bash
make
```

## Run
```bash
./bin/pe3_symbol_table input/sample.c
```

## Notes on Supported Subset
- Declarations with storage/type specifiers
- Function definitions with parameter declarations
- Block scopes (`{ ... }`)
- `typedef` declarations and typedef-name usage
- `enum` definitions with enumerators and constant assignments
- `struct`/`union` tags (`struct X;`, `union Y;`, and usage in type specifiers)
- Expression subset for assignments and arithmetic/relational/logical usage tracking

## Reference Alignment
Built in the style of your existing repos:
- `/Users/pranavhemanth/Code/Projects/ParseC`
- `/Users/pranavhemanth/Code/Projects/LexiC`

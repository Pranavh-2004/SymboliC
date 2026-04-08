# SymboliC - C Subset Symbol Table

A Flex/Bison-based parser to construct a symbol table for a simplified subset of the C language. Programming Exercise 3 (PE3) for Compiler Design.

## Features

- Symbol entries for variables, functions, parameters, typedefs, enum constants, struct tags, and union tags
- Records attributes such as name, kind, type, storage class, size, scope, definition location, initializer, and use-sites
- Supports basic data types (`int`, `float`, `char`, `double`, `void`)
- Handles pointer, array, and function declarators
- Typedef declaration and typedef-name resolution
- Enum constants with explicit and implicit value assignment
- Struct and union tag handling
- Nested scope tracking (global, function, and block scopes)
- Comment handling (single-line `//` and multi-line `/* */`)
- Line-aware parse error reporting

## Build

```
make
```

## Usage

```
./bin/pe3_symbol_table <source_file.c>    # Parse a file
./bin/pe3_symbol_table                   # Read from stdin
```

## Example

```
./bin/pe3_symbol_table input/sample.c
```

Output:

```
================ Symbol Table ================
... symbol entries ...
================================================
```

## Run Sample

```
make run
```

## Clean

```
make clean
```

## Project Structure

```
SymboliC/
├── src/
│   ├── lexer.l           # Flex lexer specification
│   ├── parser.y          # Bison parser grammar
│   ├── symbol_table.h    # Symbol table API and data model
│   ├── symbol_table.c    # Symbol table implementation
│   └── main.c            # Driver program
├── input/                # Sample/test C files
├── bin/                  # Compiled output
├── Makefile
├── LICENSE
└── README.md
```

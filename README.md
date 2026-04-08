SymboliC - C Subset Symbol Table

A Flex/Bison based symbol table generator for a simplified subset of C. Programming Exercise 3 (PE3) for Compiler Design.

Features

Records symbols for variables, functions, parameters, typedef names, enum constants, struct tags, and union tags
Stores name, kind, type representation, storage class, size in bytes, scope level/label, definition location, initializer, and use-sites
Supports declarations with basic types (int, float, char, double, void)
Supports pointers, arrays (including multi-dimensional), and function declarators/signatures
Supports typedef declarations and typedef-name usage in later declarations
Supports enum declarations with explicit and implicit constant values
Supports struct/union tag declarations and tagged type usage
Tracks nested scopes (global, function, block)
Handles single-line (//) and multi-line (/* */) comments
Reports parse errors with line context

Build

make

Usage

./bin/pe3_symbol_table <source_file.c>    # Parse file and print symbol table
./bin/pe3_symbol_table                     # Read from stdin

Example

./bin/pe3_symbol_table input/sample.c

Output:

================ Symbol Table ================
... symbol entries ...
================================================

Run Sample

make run

Clean

make clean

Project Structure

SymboliC/
├── src/
│   ├── lexer.l           # Flex lexer specification
│   ├── parser.y          # Bison parser grammar
│   ├── symbol_table.h    # Symbol table API and symbol model
│   ├── symbol_table.c    # Symbol table implementation
│   └── main.c            # Driver program
├── input/                # Sample/test input files
├── bin/                  # Compiled output
├── Makefile
├── LICENSE
└── README.md

%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "parser.tab.h"
#include "symbol_table.h"

int yycolumn = 1;
char current_lexeme[256] = "";

static void save_lexeme(const char *text) {
    strncpy(current_lexeme, text, sizeof(current_lexeme) - 1);
    current_lexeme[sizeof(current_lexeme) - 1] = '\0';
}

#define YY_USER_ACTION                                                   \
    yylloc.first_line = yylineno;                                        \
    yylloc.first_column = yycolumn;                                      \
    yylloc.last_line = yylineno;                                         \
    yylloc.last_column = yycolumn + (int)yyleng - 1;                     \
    yycolumn += (int)yyleng;
%}

%option noyywrap
%option yylineno
%option nounput
%option noinput

DIGIT      [0-9]
ID_START   [a-zA-Z_]
ID_CONT    [a-zA-Z0-9_]
IDENT      {ID_START}{ID_CONT}*

%%

"auto"        { save_lexeme(yytext); return AUTO; }
"static"      { save_lexeme(yytext); return STATIC; }
"extern"      { save_lexeme(yytext); return EXTERN; }
"register"    { save_lexeme(yytext); return REGISTER; }
"typedef"     { save_lexeme(yytext); return TYPEDEF; }

"int"         { save_lexeme(yytext); return INT; }
"float"       { save_lexeme(yytext); return FLOAT; }
"double"      { save_lexeme(yytext); return DOUBLE; }
"char"        { save_lexeme(yytext); return CHAR; }
"void"        { save_lexeme(yytext); return VOID; }

"struct"      { save_lexeme(yytext); return STRUCT; }
"union"       { save_lexeme(yytext); return UNION; }
"enum"        { save_lexeme(yytext); return ENUM; }

"if"          { save_lexeme(yytext); return IF; }
"else"        { save_lexeme(yytext); return ELSE; }
"for"         { save_lexeme(yytext); return FOR; }
"while"       { save_lexeme(yytext); return WHILE; }
"return"      { save_lexeme(yytext); return RETURN; }

"=="          { save_lexeme(yytext); return EQ; }
"!="          { save_lexeme(yytext); return NE; }
"<="          { save_lexeme(yytext); return LE; }
">="          { save_lexeme(yytext); return GE; }
"&&"          { save_lexeme(yytext); return AND; }
"||"          { save_lexeme(yytext); return OR; }

{IDENT}       {
                save_lexeme(yytext);
                if (symtab_is_typedef_name(yytext)) {
                    yylval.str = strdup(yytext);
                    return TYPE_NAME;
                }
                yylval.str = strdup(yytext);
                return IDENT;
             }

{DIGIT}+      {
                save_lexeme(yytext);
                yylval.ival = strtol(yytext, NULL, 10);
                return INT_CONST;
             }

"//"[^\n]*    { save_lexeme(yytext); }
"/*"([^*]|\*+[^*/])*\*+"/"  { save_lexeme("/*...*/"); }

[ \t\r]+      { /* ignore */ }
\n            { yycolumn = 1; }

[(){}\[\],;+\-*/=<>]   { save_lexeme(yytext); return yytext[0]; }

.             { save_lexeme(yytext); return yytext[0]; }

%%

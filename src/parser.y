%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdarg.h>

#include "symbol_table.h"

int yylex(void);
void yyerror(const char *msg);

extern FILE *yyin;
extern int yylineno;
extern char current_lexeme[256];

static const char *g_input_file = "<stdin>";
static long g_enum_next_value = 0;

/* ---------- Internal semantic structs ---------- */
struct IntNode {
    long value;
    struct IntNode *next;
};

struct Param {
    char *name;
    char *type_repr;
    int size;
    int def_line;
    int def_col;
    struct Param *next;
};

struct ParamList {
    struct Param *head;
    struct Param *tail;
    int count;
};

struct Declarator {
    char *name;
    int pointers;
    struct IntNode *arrays;
    int is_function;
    struct ParamList *params;
    int def_line;
    int def_col;
};

struct TypeSpec {
    char *base_name;
    int base_size;
    StorageClass storage;
    int is_typedef_decl;
};

struct ExprVal {
    int is_const;
    long value;
    char *text;
};

struct DeclItem {
    struct Declarator *decl;
    struct ExprVal *init;
    struct DeclItem *next;
};

struct DeclList {
    struct DeclItem *head;
    struct DeclItem *tail;
};

static void *xmalloc(size_t n) {
    void *p = malloc(n);
    if (!p) {
        fprintf(stderr, "Out of memory\n");
        exit(1);
    }
    return p;
}

static char *xstrdup(const char *s) {
    if (!s) return NULL;
    size_t n = strlen(s) + 1;
    char *d = (char *)xmalloc(n);
    memcpy(d, s, n);
    return d;
}

static char *strf(const char *fmt, ...) {
    va_list ap;
    va_start(ap, fmt);
    int n = vsnprintf(NULL, 0, fmt, ap);
    va_end(ap);
    char *buf = (char *)xmalloc((size_t)n + 1);
    va_start(ap, fmt);
    vsnprintf(buf, (size_t)n + 1, fmt, ap);
    va_end(ap);
    return buf;
}

static struct TypeSpec *mk_type(const char *base, int size, StorageClass sc, int is_typedef_decl) {
    struct TypeSpec *t = (struct TypeSpec *)xmalloc(sizeof(struct TypeSpec));
    t->base_name = xstrdup(base);
    t->base_size = size;
    t->storage = sc;
    t->is_typedef_decl = is_typedef_decl;
    return t;
}

static struct Declarator *mk_decl_ident(char *name, int line, int col) {
    struct Declarator *d = (struct Declarator *)xmalloc(sizeof(struct Declarator));
    d->name = name;
    d->pointers = 0;
    d->arrays = NULL;
    d->is_function = 0;
    d->params = NULL;
    d->def_line = line;
    d->def_col = col;
    return d;
}

static void decl_add_array(struct Declarator *d, long dim) {
    struct IntNode *n = (struct IntNode *)xmalloc(sizeof(struct IntNode));
    n->value = dim;
    n->next = NULL;
    if (!d->arrays) {
        d->arrays = n;
        return;
    }
    struct IntNode *it = d->arrays;
    while (it->next) it = it->next;
    it->next = n;
}

static void decl_mark_function(struct Declarator *d, struct ParamList *params) {
    d->is_function = 1;
    d->params = params;
}

static struct Param *mk_param(char *name, char *type_repr, int size, int line, int col) {
    struct Param *p = (struct Param *)xmalloc(sizeof(struct Param));
    p->name = name ? name : xstrdup("<anon>");
    p->type_repr = type_repr;
    p->size = size;
    p->def_line = line;
    p->def_col = col;
    p->next = NULL;
    return p;
}

static struct ParamList *mk_param_list(void) {
    struct ParamList *pl = (struct ParamList *)xmalloc(sizeof(struct ParamList));
    pl->head = pl->tail = NULL;
    pl->count = 0;
    return pl;
}

static void param_list_add(struct ParamList *pl, struct Param *p) {
    if (!pl || !p) return;
    if (!pl->head) pl->head = p;
    else pl->tail->next = p;
    pl->tail = p;
    pl->count++;
}

static struct DeclItem *mk_decl_item(struct Declarator *d, struct ExprVal *init) {
    struct DeclItem *it = (struct DeclItem *)xmalloc(sizeof(struct DeclItem));
    it->decl = d;
    it->init = init;
    it->next = NULL;
    return it;
}

static struct DeclList *mk_decl_list(void) {
    struct DeclList *dl = (struct DeclList *)xmalloc(sizeof(struct DeclList));
    dl->head = dl->tail = NULL;
    return dl;
}

static void decl_list_add(struct DeclList *dl, struct DeclItem *it) {
    if (!dl || !it) return;
    if (!dl->head) dl->head = it;
    else dl->tail->next = it;
    dl->tail = it;
}

static struct ExprVal *mk_expr_const(long v) {
    struct ExprVal *e = (struct ExprVal *)xmalloc(sizeof(struct ExprVal));
    e->is_const = 1;
    e->value = v;
    e->text = strf("%ld", v);
    return e;
}

static struct ExprVal *mk_expr_nonconst(const char *text) {
    struct ExprVal *e = (struct ExprVal *)xmalloc(sizeof(struct ExprVal));
    e->is_const = 0;
    e->value = 0;
    e->text = xstrdup(text ? text : "expr");
    return e;
}

static struct ExprVal *expr_binary(char op, struct ExprVal *a, struct ExprVal *b) {
    if (!a || !b) return mk_expr_nonconst("expr");
    if (!a->is_const || !b->is_const) return mk_expr_nonconst("expr");

    long out = 0;
    switch (op) {
        case '+': out = a->value + b->value; break;
        case '-': out = a->value - b->value; break;
        case '*': out = a->value * b->value; break;
        case '/':
            if (b->value == 0) return mk_expr_nonconst("expr");
            out = a->value / b->value;
            break;
        default:
            return mk_expr_nonconst("expr");
    }
    return mk_expr_const(out);
}

static int sizeof_decl(const struct TypeSpec *t, const struct Declarator *d) {
    if (d->is_function) return 0;
    if (d->pointers > 0) return 8;

    long sz = t->base_size;
    if (sz < 0) sz = 0;

    for (struct IntNode *it = d->arrays; it; it = it->next) {
        if (it->value <= 0) return 0;
        sz *= it->value;
    }
    if (sz > 2147483647L) return 0;
    return (int)sz;
}

static char *build_type_repr(const struct TypeSpec *t, const struct Declarator *d) {
    char *base = xstrdup(t->base_name);

    for (int i = 0; i < d->pointers; i++) {
        char *tmp = strf("%s*", base);
        free(base);
        base = tmp;
    }

    for (struct IntNode *it = d->arrays; it; it = it->next) {
        char *tmp = strf("%s[%ld]", base, it->value);
        free(base);
        base = tmp;
    }

    if (d->is_function) {
        char *sig = xstrdup("");
        int first = 1;
        for (struct Param *p = d->params ? d->params->head : NULL; p; p = p->next) {
            char *tmp = strf("%s%s%s", sig, first ? "" : ", ", p->type_repr);
            free(sig);
            sig = tmp;
            first = 0;
        }
        char *tmp = strf("fn(%s) -> %s", sig, base);
        free(sig);
        free(base);
        base = tmp;
    }

    return base;
}

static int base_size_from_name(const char *name) {
    if (strcmp(name, "int") == 0) return 4;
    if (strcmp(name, "float") == 0) return 4;
    if (strcmp(name, "double") == 0) return 8;
    if (strcmp(name, "char") == 0) return 1;
    if (strcmp(name, "void") == 0) return 0;
    Symbol *s = symtab_lookup(name);
    return s ? s->size_bytes : 0;
}

static void declare_from_list(struct TypeSpec *t, struct DeclList *dl) {
    for (struct DeclItem *it = dl ? dl->head : NULL; it; it = it->next) {
        struct Declarator *d = it->decl;
        SymbolKind kind = t->is_typedef_decl ? SYM_TYPEDEF : (d->is_function ? SYM_FUNCTION : SYM_VARIABLE);
        StorageClass sc = t->is_typedef_decl ? SC_NONE : t->storage;

        char *type_repr = build_type_repr(t, d);
        int size = sizeof_decl(t, d);

        char *init = NULL;
        if (it->init && it->init->is_const) {
            init = strf("%ld", it->init->value);
        }

        symtab_declare(d->name, kind, type_repr, sc, size, d->def_line, d->def_col, init ? init : "null");

        free(type_repr);
        free(init);
    }
}

static void declare_function_and_params(struct TypeSpec *t, struct Declarator *d) {
    char *type_repr = build_type_repr(t, d);
    symtab_declare(d->name, SYM_FUNCTION, type_repr, t->storage, 0, d->def_line, d->def_col, "null");

    char *scope_name = strf("function:%s", d->name);
    symtab_enter_scope(scope_name);
    free(scope_name);

    for (struct Param *p = d->params ? d->params->head : NULL; p; p = p->next) {
        symtab_declare(p->name,
                       SYM_PARAMETER,
                       p->type_repr,
                       SC_AUTO,
                       p->size,
                       p->def_line,
                       p->def_col,
                       "null");
    }
    free(type_repr);
}

static void end_function_scope(void) {
    symtab_leave_scope();
}

%}

%error-verbose
%locations

%union {
    char *str;
    long ival;
    int storage;
    void *ptr;
}

%token <str> IDENT TYPE_NAME
%token <ival> INT_CONST

%token INT FLOAT DOUBLE CHAR VOID
%token STRUCT UNION ENUM TYPEDEF
%token AUTO STATIC EXTERN REGISTER
%token IF ELSE FOR WHILE RETURN

%token EQ NE LE GE AND OR

%type <storage> storage_class_specifier storage_class_specifier_opt
%type <ptr> declaration_specifiers type_specifier
%type <ptr> declarator direct_declarator
%type <ptr> init_declarator
%type <ptr> init_declarator_list
%type <ptr> parameter_declaration
%type <ptr> parameter_list parameter_list_opt
%type <ptr> initializer assignment_expression logical_or_expression logical_and_expression equality_expression relational_expression additive_expression multiplicative_expression unary_expression primary_expression constant_expression

%right '='
%left OR
%left AND
%left EQ NE
%left '<' '>' LE GE
%left '+' '-'
%left '*' '/'

%%

program
    : translation_unit
    ;

translation_unit
    : external_declaration
    | translation_unit external_declaration
    ;

external_declaration
    : declaration
    | function_definition
    ;

declaration
    : declaration_specifiers init_declarator_list ';'
      {
          declare_from_list($1, $2);
      }
    | declaration_specifiers ';'
      {
          /* standalone declarations like: struct S; enum E {A,B}; */
      }
    ;

function_definition
    : declaration_specifiers declarator
      {
          declare_function_and_params($1, $2);
      }
      compound_statement
      {
          end_function_scope();
      }
    ;

declaration_specifiers
    : storage_class_specifier_opt type_specifier
      {
          ((struct TypeSpec *)$2)->storage = (StorageClass)$1;
          if ($1 == TYPEDEF) {
              ((struct TypeSpec *)$2)->is_typedef_decl = 1;
          }
          $$ = $2;
      }
    ;

storage_class_specifier_opt
    : /* empty */ { $$ = SC_NONE; }
    | storage_class_specifier { $$ = $1; }
    ;

storage_class_specifier
    : AUTO { $$ = SC_AUTO; }
    | STATIC { $$ = SC_STATIC; }
    | EXTERN { $$ = SC_EXTERN; }
    | REGISTER { $$ = SC_REGISTER; }
    | TYPEDEF { $$ = TYPEDEF; }
    ;

type_specifier
    : INT { $$ = mk_type("int", 4, SC_NONE, 0); }
    | FLOAT { $$ = mk_type("float", 4, SC_NONE, 0); }
    | DOUBLE { $$ = mk_type("double", 8, SC_NONE, 0); }
    | CHAR { $$ = mk_type("char", 1, SC_NONE, 0); }
    | VOID { $$ = mk_type("void", 0, SC_NONE, 0); }
    | TYPE_NAME
      {
          int sz = base_size_from_name($1);
          $$ = mk_type($1, sz, SC_NONE, 0);
      }
    | STRUCT IDENT
      {
          char *t = strf("struct %s", $2);
          symtab_declare($2, SYM_STRUCT_TAG, t, SC_NONE, 0, @2.first_line, @2.first_column, "null");
          $$ = mk_type(t, 0, SC_NONE, 0);
          free(t);
      }
    | UNION IDENT
      {
          char *t = strf("union %s", $2);
          symtab_declare($2, SYM_UNION_TAG, t, SC_NONE, 0, @2.first_line, @2.first_column, "null");
          $$ = mk_type(t, 0, SC_NONE, 0);
          free(t);
      }
    | ENUM IDENT '{'
      {
          g_enum_next_value = 0;
      }
      enumerator_list '}'
      {
          $$ = mk_type("enum", 4, SC_NONE, 0);
      }
    | ENUM '{'
      {
          g_enum_next_value = 0;
      }
      enumerator_list '}'
      {
          $$ = mk_type("enum", 4, SC_NONE, 0);
      }
    ;

enumerator_list
    : enumerator
    | enumerator_list ',' enumerator
    ;

enumerator
    : IDENT
      {
          char *init = strf("%ld", g_enum_next_value);
          symtab_declare($1, SYM_ENUM_CONST, "int", SC_NONE, 4, @1.first_line, @1.first_column, init);
          free(init);
          g_enum_next_value++;
      }
    | IDENT '=' constant_expression
      {
          struct ExprVal *e = (struct ExprVal *)$3;
          char *init = e && e->is_const ? strf("%ld", e->value) : xstrdup("null");
          symtab_declare($1, SYM_ENUM_CONST, "int", SC_NONE, 4, @1.first_line, @1.first_column, init);
          if (e && e->is_const) g_enum_next_value = e->value + 1;
          free(init);
      }
    ;

init_declarator_list
    : init_declarator
      {
          $$ = mk_decl_list();
          decl_list_add($$, $1);
      }
    | init_declarator_list ',' init_declarator
      {
          decl_list_add($1, $3);
          $$ = $1;
      }
    ;

init_declarator
    : declarator
      {
          $$ = mk_decl_item($1, NULL);
      }
    | declarator '=' initializer
      {
          $$ = mk_decl_item($1, $3);
      }
    ;

declarator
    : direct_declarator
      {
          $$ = $1;
      }
    | '*' declarator
      {
          ((struct Declarator *)$2)->pointers += 1;
          $$ = $2;
      }
    ;

direct_declarator
    : IDENT
      {
          $$ = mk_decl_ident($1, @1.first_line, @1.first_column);
      }
    | '(' declarator ')'
      {
          $$ = $2;
      }
    | direct_declarator '[' INT_CONST ']'
      {
          decl_add_array($1, $3);
          $$ = $1;
      }
    | direct_declarator '(' parameter_list_opt ')'
      {
          decl_mark_function($1, $3);
          $$ = $1;
      }
    ;

parameter_list_opt
    : /* empty */
      {
          $$ = mk_param_list();
      }
    | parameter_list
      {
          $$ = $1;
      }
    ;

parameter_list
    : parameter_declaration
      {
          $$ = mk_param_list();
          param_list_add($$, $1);
      }
    | parameter_list ',' parameter_declaration
      {
          param_list_add($1, $3);
          $$ = $1;
      }
    ;

parameter_declaration
    : declaration_specifiers declarator
      {
          char *type_repr = build_type_repr($1, $2);
          int sz = sizeof_decl($1, $2);
          $$ = mk_param(((struct Declarator *)$2)->name ? xstrdup(((struct Declarator *)$2)->name) : NULL,
                        type_repr,
                        sz,
                        ((struct Declarator *)$2)->def_line,
                        ((struct Declarator *)$2)->def_col);
      }
    ;

compound_statement
    : '{'
      {
          symtab_enter_scope("block");
      }
      block_item_list_opt
      '}'
      {
          symtab_leave_scope();
      }
    ;

block_item_list_opt
    : /* empty */
    | block_item_list
    ;

block_item_list
    : block_item
    | block_item_list block_item
    ;

block_item
    : declaration
    | statement
    ;

statement
    : expression_statement
    | compound_statement
    | selection_statement
    | iteration_statement
    | jump_statement
    ;

expression_statement
    : ';'
    | assignment_expression ';'
    ;

selection_statement
    : IF '(' assignment_expression ')' statement
    | IF '(' assignment_expression ')' statement ELSE statement
    ;

iteration_statement
    : WHILE '(' assignment_expression ')' statement
    | FOR '(' expression_statement expression_statement assignment_expression ')' statement
    | FOR '(' expression_statement expression_statement ')' statement
    ;

jump_statement
    : RETURN ';'
    | RETURN assignment_expression ';'
    ;

initializer
    : assignment_expression
      {
          $$ = $1;
      }
    ;

constant_expression
    : assignment_expression { $$ = $1; }
    ;

assignment_expression
    : IDENT '=' assignment_expression
      {
          symtab_note_use($1, @1.first_line, @1.first_column);
          $$ = mk_expr_nonconst("assign");
      }
    | logical_or_expression
      {
          $$ = $1;
      }
    ;

logical_or_expression
    : logical_and_expression
      {
          $$ = $1;
      }
    | logical_or_expression OR logical_and_expression
      {
          $$ = mk_expr_nonconst("expr");
      }
    ;

logical_and_expression
    : equality_expression
      {
          $$ = $1;
      }
    | logical_and_expression AND equality_expression
      {
          $$ = mk_expr_nonconst("expr");
      }
    ;

equality_expression
    : relational_expression
      {
          $$ = $1;
      }
    | equality_expression EQ relational_expression
      {
          $$ = mk_expr_nonconst("expr");
      }
    | equality_expression NE relational_expression
      {
          $$ = mk_expr_nonconst("expr");
      }
    ;

relational_expression
    : additive_expression
      {
          $$ = $1;
      }
    | relational_expression '<' additive_expression
      {
          $$ = mk_expr_nonconst("expr");
      }
    | relational_expression '>' additive_expression
      {
          $$ = mk_expr_nonconst("expr");
      }
    | relational_expression LE additive_expression
      {
          $$ = mk_expr_nonconst("expr");
      }
    | relational_expression GE additive_expression
      {
          $$ = mk_expr_nonconst("expr");
      }
    ;

additive_expression
    : multiplicative_expression
      {
          $$ = $1;
      }
    | additive_expression '+' multiplicative_expression
      {
          $$ = expr_binary('+', $1, $3);
      }
    | additive_expression '-' multiplicative_expression
      {
          $$ = expr_binary('-', $1, $3);
      }
    ;

multiplicative_expression
    : unary_expression
      {
          $$ = $1;
      }
    | multiplicative_expression '*' unary_expression
      {
          $$ = expr_binary('*', $1, $3);
      }
    | multiplicative_expression '/' unary_expression
      {
          $$ = expr_binary('/', $1, $3);
      }
    ;

unary_expression
    : primary_expression
      {
          $$ = $1;
      }
    | '-' unary_expression
      {
          struct ExprVal *e = (struct ExprVal *)$2;
          if (e && e->is_const) $$ = mk_expr_const(-e->value);
          else $$ = mk_expr_nonconst("expr");
      }
    | '+' unary_expression
      {
          $$ = $2;
      }
    ;

primary_expression
    : IDENT
      {
          symtab_note_use($1, @1.first_line, @1.first_column);
          $$ = mk_expr_nonconst($1);
      }
    | INT_CONST
      {
          $$ = mk_expr_const($1);
      }
    | '(' assignment_expression ')'
      {
          $$ = $2;
      }
    ;

%%

void yyerror(const char *msg) {
    fprintf(stderr,
            "Parse error in %s at line %d near '%s': %s\n",
            g_input_file,
            yylineno,
            current_lexeme,
            msg);
}

void parser_set_input_file(const char *path) {
    g_input_file = path ? path : "<stdin>";
}

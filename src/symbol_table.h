#ifndef SYMBOL_TABLE_H
#define SYMBOL_TABLE_H

#include <stddef.h>

typedef enum {
    SYM_VARIABLE,
    SYM_FUNCTION,
    SYM_PARAMETER,
    SYM_TYPEDEF,
    SYM_ENUM_CONST,
    SYM_STRUCT_TAG,
    SYM_UNION_TAG
} SymbolKind;

typedef enum {
    SC_NONE,
    SC_AUTO,
    SC_STATIC,
    SC_EXTERN,
    SC_REGISTER
} StorageClass;

typedef struct UseSite {
    int line;
    int col;
    const char *file;
    struct UseSite *next;
} UseSite;

typedef struct Symbol {
    char *name;
    SymbolKind kind;
    char *type_repr;
    StorageClass storage;
    int size_bytes;

    int scope_level;
    const char *scope_label;

    int def_line;
    int def_col;
    const char *def_file;

    char *initializer;
    UseSite *uses;

    struct Symbol *next;
} Symbol;

void symtab_init(const char *filename);
void symtab_enter_scope(const char *label);
void symtab_leave_scope(void);
int symtab_current_scope_level(void);
const char *symtab_current_scope_label(void);

int symtab_declare(const char *name,
                   SymbolKind kind,
                   const char *type_repr,
                   StorageClass storage,
                   int size_bytes,
                   int line,
                   int col,
                   const char *initializer);

Symbol *symtab_lookup(const char *name);
Symbol *symtab_lookup_current(const char *name);
void symtab_note_use(const char *name, int line, int col);

int symtab_is_typedef_name(const char *name);

void symtab_print(void);
void symtab_destroy(void);

const char *sym_kind_str(SymbolKind kind);
const char *sym_storage_str(StorageClass sc);

#endif

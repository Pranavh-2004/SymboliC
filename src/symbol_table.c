#include "symbol_table.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

typedef struct Scope {
    int level;
    const char *label;
    struct Scope *parent;
} Scope;

static Symbol *g_symbols = NULL;
static Scope *g_scope = NULL;
static const char *g_file = "<stdin>";

static char *xstrdup(const char *s) {
    if (!s) return NULL;
    size_t n = strlen(s) + 1;
    char *out = (char *)malloc(n);
    if (!out) {
        fprintf(stderr, "Out of memory\n");
        exit(1);
    }
    memcpy(out, s, n);
    return out;
}

const char *sym_kind_str(SymbolKind kind) {
    switch (kind) {
        case SYM_VARIABLE: return "variable";
        case SYM_FUNCTION: return "function";
        case SYM_PARAMETER: return "parameter";
        case SYM_TYPEDEF: return "typedef";
        case SYM_ENUM_CONST: return "enum-const";
        case SYM_STRUCT_TAG: return "struct-tag";
        case SYM_UNION_TAG: return "union-tag";
    }
    return "unknown";
}

const char *sym_storage_str(StorageClass sc) {
    switch (sc) {
        case SC_NONE: return "-";
        case SC_AUTO: return "auto";
        case SC_STATIC: return "static";
        case SC_EXTERN: return "extern";
        case SC_REGISTER: return "register";
    }
    return "-";
}

void symtab_init(const char *filename) {
    g_symbols = NULL;
    g_file = filename ? filename : "<stdin>";

    g_scope = (Scope *)malloc(sizeof(Scope));
    if (!g_scope) {
        fprintf(stderr, "Out of memory\n");
        exit(1);
    }
    g_scope->level = 0;
    g_scope->label = "global";
    g_scope->parent = NULL;
}

void symtab_enter_scope(const char *label) {
    Scope *s = (Scope *)malloc(sizeof(Scope));
    if (!s) {
        fprintf(stderr, "Out of memory\n");
        exit(1);
    }
    s->level = g_scope ? g_scope->level + 1 : 0;
    s->label = label ? xstrdup(label) : xstrdup("block");
    s->parent = g_scope;
    g_scope = s;
}

void symtab_leave_scope(void) {
    if (!g_scope || !g_scope->parent) return;
    Scope *old = g_scope;
    g_scope = g_scope->parent;
    free((void *)old->label);
    free(old);
}

int symtab_current_scope_level(void) {
    return g_scope ? g_scope->level : 0;
}

const char *symtab_current_scope_label(void) {
    return g_scope ? g_scope->label : "global";
}

Symbol *symtab_lookup_current(const char *name) {
    int lvl = symtab_current_scope_level();
    Symbol *it = g_symbols;
    while (it) {
        if (it->scope_level == lvl && strcmp(it->name, name) == 0) {
            return it;
        }
        it = it->next;
    }
    return NULL;
}

Symbol *symtab_lookup(const char *name) {
    Symbol *best = NULL;
    Symbol *it = g_symbols;
    while (it) {
        if (strcmp(it->name, name) == 0) {
            if (!best || it->scope_level > best->scope_level) {
                best = it;
            }
        }
        it = it->next;
    }
    return best;
}

int symtab_declare(const char *name,
                   SymbolKind kind,
                   const char *type_repr,
                   StorageClass storage,
                   int size_bytes,
                   int line,
                   int col,
                   const char *initializer) {
    if (!name || !*name) return 0;
    if (symtab_lookup_current(name)) {
        fprintf(stderr,
                "Semantic error: redeclaration of '%s' at %s:%d:%d\n",
                name,
                g_file,
                line,
                col);
        return 0;
    }

    Symbol *s = (Symbol *)calloc(1, sizeof(Symbol));
    if (!s) {
        fprintf(stderr, "Out of memory\n");
        exit(1);
    }

    s->name = xstrdup(name);
    s->kind = kind;
    s->type_repr = xstrdup(type_repr ? type_repr : "unknown");
    s->storage = storage;
    s->size_bytes = size_bytes;
    s->scope_level = symtab_current_scope_level();
    s->scope_label = xstrdup(symtab_current_scope_label());
    s->def_line = line;
    s->def_col = col;
    s->def_file = xstrdup(g_file);
    s->initializer = initializer ? xstrdup(initializer) : xstrdup("null");

    s->next = g_symbols;
    g_symbols = s;
    return 1;
}

void symtab_note_use(const char *name, int line, int col) {
    Symbol *s = symtab_lookup(name);
    if (!s) return;

    UseSite *u = (UseSite *)malloc(sizeof(UseSite));
    if (!u) {
        fprintf(stderr, "Out of memory\n");
        exit(1);
    }
    u->line = line;
    u->col = col;
    u->file = g_file;
    u->next = NULL;

    if (!s->uses) {
        s->uses = u;
        return;
    }

    UseSite *it = s->uses;
    while (it->next) it = it->next;
    it->next = u;
}

int symtab_is_typedef_name(const char *name) {
    Symbol *s = symtab_lookup(name);
    return s && s->kind == SYM_TYPEDEF;
}

static void print_uses(const UseSite *u) {
    if (!u) {
        printf("-\n");
        return;
    }
    int first = 1;
    while (u) {
        if (!first) printf(", ");
        printf("%d:%d", u->line, u->col);
        first = 0;
        u = u->next;
    }
    printf("\n");
}

void symtab_print(void) {
    printf("\n================ Symbol Table ================\n");
    printf("%-14s %-11s %-28s %-9s %-6s %-18s %-16s %-12s %s\n",
           "Name",
           "Kind",
           "Type",
           "Storage",
           "Size",
           "Scope",
           "Def(file:line:col)",
           "Initializer",
           "Use-sites");
    printf("-----------------------------------------------------------------------------------------------------------------------------\n");

    int total = 0;
    for (Symbol *s = g_symbols; s; s = s->next) {
        ++total;
        char *scope = NULL;
        char *defloc = NULL;

        {
            int n1 = snprintf(NULL, 0, "%s(L%d)", s->scope_label, s->scope_level);
            int n2 = snprintf(NULL, 0, "%s:%d:%d", s->def_file, s->def_line, s->def_col);
            scope = (char *)malloc((size_t)n1 + 1);
            defloc = (char *)malloc((size_t)n2 + 1);
            if (!scope || !defloc) {
                fprintf(stderr, "Out of memory\n");
                exit(1);
            }
            snprintf(scope, (size_t)n1 + 1, "%s(L%d)", s->scope_label, s->scope_level);
            snprintf(defloc, (size_t)n2 + 1, "%s:%d:%d", s->def_file, s->def_line, s->def_col);
        }

        printf("%-14s %-11s %-28s %-9s %-6d %-18s %-16s %-12s ",
               s->name,
               sym_kind_str(s->kind),
               s->type_repr,
               sym_storage_str(s->storage),
               s->size_bytes,
               scope,
               defloc,
               s->initializer);
        print_uses(s->uses);
        free(scope);
        free(defloc);
    }

    if (total == 0) {
        printf("(empty)\n");
    }
    printf("================================================\n");
}

void symtab_destroy(void) {
    while (g_scope && g_scope->parent) {
        symtab_leave_scope();
    }
    if (g_scope) {
        free(g_scope);
        g_scope = NULL;
    }

    Symbol *s = g_symbols;
    while (s) {
        Symbol *n = s->next;
        free(s->name);
        free(s->type_repr);
        free((void *)s->scope_label);
        free((void *)s->def_file);
        free(s->initializer);
        UseSite *u = s->uses;
        while (u) {
            UseSite *un = u->next;
            free(u);
            u = un;
        }
        free(s);
        s = n;
    }
    g_symbols = NULL;
}

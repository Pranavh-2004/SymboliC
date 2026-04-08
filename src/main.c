#include <stdio.h>
#include <stdlib.h>

#include "symbol_table.h"

extern FILE *yyin;
int yyparse(void);
void parser_set_input_file(const char *path);

int main(int argc, char **argv) {
    const char *input_name = "<stdin>";
    FILE *f = NULL;

    if (argc > 1) {
        input_name = argv[1];
        f = fopen(input_name, "r");
        if (!f) {
            fprintf(stderr, "Error: cannot open '%s'\n", input_name);
            return 1;
        }
        yyin = f;
    }

    symtab_init(input_name);
    parser_set_input_file(input_name);

    int rc = yyparse();

    if (rc == 0) {
        symtab_print();
    } else {
        fprintf(stderr, "Parsing failed.\n");
    }

    symtab_destroy();

    if (f) fclose(f);
    return rc == 0 ? 0 : 1;
}

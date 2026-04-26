#include <stdio.h>
#include <stdlib.h>

extern FILE *yyin;
int yyparse(void);

/* Defined here, used as extern in parser.y and lexer.l */
FILE *out       = NULL;
FILE *token_out = NULL;
FILE *tree_out  = NULL;

int main(int argc, char **argv) {
  /* Usage: j2cpp in.java out.cpp [tokens.txt] [tree.txt] */
  if (argc < 3) {
    fprintf(stderr, "usage: %s in.java out.cpp [tokens.txt] [tree.txt]\n", argv[0]);
    return 1;
  }

  yyin = fopen(argv[1], "r");
  if (!yyin) {
    perror(argv[1]);
    return 1;
  }

  out = fopen(argv[2], "w");
  if (!out) {
    perror(argv[2]);
    fclose(yyin);
    return 1;
  }

  /* Optional: open token output */
  if (argc >= 4) {
    token_out = fopen(argv[3], "w");
    if (!token_out) {
      perror(argv[3]);
    }
  }

  /* Optional: open parse-tree output */
  if (argc >= 5) {
    tree_out = fopen(argv[4], "w");
    if (!tree_out) {
      perror(argv[4]);
    }
  }

  /* Emit C++ preamble */
  fputs(
      "#include <iostream>\n"
      "#include <string>\n"
      "#include <vector>\n"
      "using namespace std;\n\n",
      out);

  int rc = yyparse();

  fclose(yyin);
  fclose(out);
  if (token_out) fclose(token_out);
  if (tree_out)  fclose(tree_out);

  return rc ? 1 : 0;
}

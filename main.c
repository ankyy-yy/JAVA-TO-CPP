#include <stdio.h>
#include <stdlib.h>

extern FILE *yyin;
extern FILE *out;
int yyparse(void);

int main(int argc, char **argv) {
  if (argc != 3) {
    fprintf(stderr, "usage: %s in.java out.cpp\n", argv[0]);
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

  fputs(
      "#include <iostream>\n"
      "#include <string>\n"
      "#include <vector>\n"
      "using namespace std;\n\n",
      out);

  int rc = yyparse();
  fclose(yyin);
  fclose(out);
  return rc ? 1 : 0;
}

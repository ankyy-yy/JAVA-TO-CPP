%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

extern FILE *out;       /* defined in main.c */
extern FILE *tree_out;  /* defined in main.c */

void yyerror(const char *s);
int yylex(void);

/* ── helpers ──────────────────────────────────────────── */
static void emit(const char *s) { fputs(s, out); }

static char *dup_str(const char *s) {
  return strdup(s ? s : "");
}

static char *join2(const char *a, const char *b) {
  size_t la = strlen(a), lb = strlen(b);
  char *r = malloc(la + lb + 1);
  if (!r) return dup_str("");
  memcpy(r, a, la);
  memcpy(r + la, b, lb + 1);
  return r;
}

static char *join3(const char *a, const char *b, const char *c) {
  char *t = join2(a, b);
  char *r = join2(t, c);
  free(t);
  return r;
}

static char *join4(const char *a, const char *b, const char *c, const char *d) {
  char *t = join3(a, b, c);
  char *r = join2(t, d);
  free(t);
  return r;
}

static char *cpp_string_literal(const char *inner) {
  size_t n = strlen(inner);
  char *r = malloc(n * 2 + 3);
  if (!r) return dup_str("\"\"");
  char *p = r;
  *p++ = '"';
  for (const char *s = inner; *s; s++) {
    if (*s == '"' || *s == '\\')
      *p++ = '\\';
    *p++ = *s;
  }
  *p++ = '"';
  *p = '\0';
  return r;
}

/*
 * Convert a Java-style string concatenation expression into a C++ cout chain.
 * e.g. "Hello " + name + "!" => "Hello " << name << "!"
 * We detect this by scanning for '+' that are top-level (not inside parens).
 * If there are no '+' this is a simple value.
 */
static char *concat_to_cout_chain(const char *expr) {
  /* Walk expr, split on top-level '+', join with " << " */
  size_t len = strlen(expr);
  char *result = dup_str("");
  size_t start = 0;
  int depth = 0;
  int first = 1;

  for (size_t i = 0; i <= len; i++) {
    char c = expr[i];
    if (c == '(' || c == '[') depth++;
    else if (c == ')' || c == ']') depth--;
    else if ((c == '+' || c == '\0') && depth == 0) {
      /* extract segment expr[start..i-1] */
      /* trim leading/trailing spaces from segment */
      size_t s = start;
      while (s < i && expr[s] == ' ') s++;
      size_t e2 = i;
      while (e2 > s && expr[e2-1] == ' ') e2--;
      char *seg = malloc(e2 - s + 1);
      if (!seg) break;
      memcpy(seg, expr + s, e2 - s);
      seg[e2 - s] = '\0';

      if (seg[0] != '\0') {
        if (!first) {
          char *tmp = join3(result, " << ", seg);
          free(result);
          result = tmp;
        } else {
          free(result);
          result = dup_str(seg);
          first = 0;
        }
      }
      free(seg);
      start = i + 1;
    }
  }
  return result;
}

static void emit_java_type(const char *cpp_type) {
  emit(cpp_type);
}

static void free_str(char *s) {
  if (s) free(s);
}

/* ── parse-tree printer ────────────────────────────────── */
static int pt_depth = 0;

static void pt_indent(void) {
  if (!tree_out) return;
  for (int i = 0; i < pt_depth; ++i) {
    fputs("  ", tree_out);
  }
}

static void pt_enter(const char *node) {
  if (!tree_out) return;
  pt_indent();
  fprintf(tree_out, "├─ %s\n", node);
  pt_depth++;
}

static void pt_leaf(const char *label, const char *value) {
  if (!tree_out) return;
  pt_indent();
  if (value && value[0])
    fprintf(tree_out, "├─ %s: \"%s\"\n", label, value);
  else
    fprintf(tree_out, "├─ %s\n", label);
}

static void pt_leave(void) {
  if (pt_depth > 0) pt_depth--;
}
%}

%union {
  char *str;
}

%token <str> IDENTIFIER INT_LITERAL STRING_LITERAL

%token PRINTLN PACKAGE IMPORT PUBLIC PRIVATE PROTECTED STATIC FINAL
%token CLASS VOID INT BOOLEAN TRUE FALSE IF ELSE FOR WHILE DO RETURN NEW STRING_T THIS
%token ANDAND OROR LE GE EQEQ NE LT GT INC DEC PLUSEQ MINUSEQ
%token STRINGBUILDER

%nonassoc LOWER_THAN_ELSE
%nonassoc ELSE
%right '='
%right PLUSEQ MINUSEQ
%left OROR
%left ANDAND
%left EQEQ NE
%left LT LE GT GE
%left '+' '-'
%left '*' '/' '%'
%right '!' UMINUS
%nonassoc INC DEC

%type <str> expr expr_opt primary postfix unary add mul relational equality land lor assign
%type <str> java_type_spec dotted for_step_opt for_init_opt new_array_expr
%type <str> local_var_list_inline
%type <str> local_var_one
%type <str> local_var_tail
%type <str> expr_list_inline
%type <str> arg_list_opt arg_list
%type <str> param_list_opt param_list param_one

%start program

%%

program
  : { pt_enter("Program"); }
    package_opt import_list class_decl
    { pt_leave(); }
  ;

package_opt
  : /* empty */
  | PACKAGE dotted ';'
    { pt_leaf("PackageDecl", $2); free_str($2); }
  ;

import_list
  : /* empty */
  | import_list IMPORT dotted ';'
    { pt_leaf("ImportDecl", $3); free_str($3); }
  ;

dotted
  : IDENTIFIER { $$ = $1; }
  | dotted '.' IDENTIFIER { char *t = join3($1, ".", $3); free_str($1); free_str($3); $$ = t; }
  ;

modifier_list
  : /* empty */
  | modifier_list PUBLIC
  | modifier_list PRIVATE
  | modifier_list PROTECTED
  | modifier_list STATIC
  | modifier_list FINAL
  ;

class_decl
  : modifier_list CLASS IDENTIFIER
    { pt_enter("ClassDecl"); pt_leaf("ClassName", $3); }
    '{' members '}'
    { pt_leave(); free_str($3); }
  ;

members
  : /* empty */
  | members member
  ;

member
  : field
  | method
  ;

java_type_spec
  : INT { $$ = dup_str("int"); }
  | INT '[' ']' { $$ = dup_str("vector<int>"); }
  | BOOLEAN { $$ = dup_str("bool"); }
  | BOOLEAN '[' ']' { $$ = dup_str("vector<bool>"); }
  | STRING_T { $$ = dup_str("string"); }
  | STRING_T '[' ']' { $$ = dup_str("vector<string>"); }
  | VOID { $$ = dup_str("void"); }
  ;

field
  : modifier_list java_type_spec IDENTIFIER ';'
    {
      pt_enter("FieldDecl");
      pt_leaf("Type", $2);
      pt_leaf("Name", $3);
      pt_leave();
      emit("static ");
      emit_java_type($2);
      emit(" ");
      emit($3);
      emit(";\n");
      free_str($2);
      free_str($3);
    }
  | modifier_list java_type_spec IDENTIFIER '=' expr ';'
    {
      pt_enter("FieldDecl");
      pt_leaf("Type", $2);
      pt_leaf("Name", $3);
      pt_leaf("InitValue", $5);
      pt_leave();
      emit("static ");
      emit_java_type($2);
      emit(" ");
      emit($3);
      emit(" = ");
      emit($5);
      emit(";\n");
      free_str($2);
      free_str($3);
      free_str($5);
    }
  ;

/* ── Parameter list (for function definitions) ─────────── */

param_list_opt
  : /* empty */ { $$ = dup_str(""); }
  | param_list  { $$ = $1; }
  ;

param_list
  : param_one
    { $$ = $1; }
  | param_list ',' param_one
    { $$ = join3($1, ", ", $3); free_str($1); free_str($3); }
  ;

param_one
  : java_type_spec IDENTIFIER
    {
      pt_leaf("Param", $2);
      $$ = join3($1, " ", $2);
      free_str($1);
      free_str($2);
    }
  ;

/* ── Argument list (for function calls) ────────────────── */

arg_list_opt
  : /* empty */ { $$ = dup_str(""); }
  | arg_list    { $$ = $1; }
  ;

arg_list
  : expr
    { $$ = $1; }
  | arg_list ',' expr
    { $$ = join3($1, ", ", $3); free_str($1); free_str($3); }
  ;

/* ── Method declarations ────────────────────────────────── */

method
  : modifier_list VOID IDENTIFIER '(' param_list_opt ')'
    {
      pt_enter("MethodDecl");
      pt_leaf("ReturnType", "void");
      pt_leaf("MethodName", $3);
      if (strcmp($3, "main") == 0) {
        emit("int main() ");
      } else {
        emit("void ");
        emit($3);
        emit("(");
        emit($5);
        emit(") ");
      }
      free_str($3);
      free_str($5);
    }
    main_block
    { pt_leave(); }
  | modifier_list java_type_spec IDENTIFIER '(' param_list_opt ')'
    {
      pt_enter("MethodDecl");
      pt_leaf("ReturnType", $2);
      pt_leaf("MethodName", $3);
      emit($2);
      emit(" ");
      emit($3);
      emit("(");
      emit($5);
      emit(") ");
      free_str($2);
      free_str($3);
      free_str($5);
    }
    block
    { pt_leave(); }
  ;

block
  : '{' { emit("{\n"); pt_enter("Block"); } stmts '}' { emit("}\n"); pt_leave(); }
  ;

main_block
  : '{' { emit("{\n"); pt_enter("Block"); } stmts '}'
    { emit("return 0;\n}\n"); pt_leave(); }
  ;

stmts
  : /* empty */
  | stmts stmt
  ;

stmt
  : block
  | if_head stmt %prec LOWER_THAN_ELSE
    { pt_leave(); }
  | if_head stmt ELSE
    { pt_leaf("ElseBranch", ""); emit("else "); }
    stmt
    { pt_leave(); }
  | WHILE '(' expr ')'
    { pt_enter("WhileStmt"); pt_leaf("Condition", $3);
      emit("while ("); emit($3); emit(") "); free_str($3); }
    stmt
    { pt_leave(); }
  | DO
    { pt_enter("DoWhileStmt"); emit("do "); }
    stmt WHILE '(' expr ')' ';'
    { pt_leaf("Condition", $6);
      emit("while ("); emit($6); emit(");\n"); free_str($6);
      pt_leave(); }
  | FOR '(' for_init_opt ';' expr_opt ';' for_step_opt ')'
    {
      pt_enter("ForStmt");
      if ($3) pt_leaf("Init", $3);
      if ($5) pt_leaf("Condition", $5);
      if ($7) pt_leaf("Step", $7);
      emit("for (");
      if ($3) { emit($3); free_str($3); }
      emit("; ");
      if ($5) { emit($5); free_str($5); }
      emit("; ");
      if ($7) { emit($7); free_str($7); }
      emit(") ");
    }
    stmt
    { pt_leave(); }
  | RETURN expr_opt ';'
    {
      pt_enter("ReturnStmt");
      emit("return");
      if ($2) {
        pt_leaf("Value", $2);
        emit(" ");
        emit($2);
        free_str($2);
      }
      emit(";\n");
      pt_leave();
    }
  | java_type_spec
    { emit($1); emit(" "); }
    local_var_list ';'
    { pt_enter("VarDecl"); pt_leaf("Type", $1); pt_leave();
      emit(";\n"); free_str($1); }
  | PRINTLN '(' expr ')' ';'
    {
      pt_enter("PrintStmt");
      pt_leaf("Expr", $3);
      pt_leave();
      /* Convert Java + string concat to << chain for cout */
      char *chain = concat_to_cout_chain($3);
      emit("cout << ");
      emit(chain);
      emit(" << endl;\n");
      free(chain);
      free_str($3);
    }
  | assign ';'
    { pt_enter("ExprStmt"); pt_leaf("Expr", $1); pt_leave();
      emit($1); emit(";\n"); free_str($1); }
  | postfix INC ';'
    { pt_enter("PostIncStmt"); pt_leaf("Operand", $1); pt_leave();
      emit($1); emit("++;\n"); free_str($1); }
  | postfix DEC ';'
    { pt_enter("PostDecStmt"); pt_leaf("Operand", $1); pt_leave();
      emit($1); emit("--;\n"); free_str($1); }
  ;

if_head
  : IF '(' expr ')'
    { pt_enter("IfStmt"); pt_leaf("Condition", $3);
      emit("if ("); emit($3); emit(") "); free_str($3); }
  ;

for_init_opt
  : /* empty */ { $$ = NULL; }
  | java_type_spec local_var_list_inline
    { $$ = join3($1, " ", $2); free_str($1); free_str($2); }
  | expr_list_inline { $$ = $1; }
  ;

local_var_list
  : local_var
  | local_var_list ',' { emit(", "); } local_var
  ;

local_var
  : IDENTIFIER { pt_leaf("VarName", $1); emit($1); free_str($1); }
  | IDENTIFIER '=' expr
    { pt_leaf("VarName", $1); emit($1); emit(" = "); emit($3); free_str($1); free_str($3); }
  | IDENTIFIER '[' ']' { pt_leaf("VarName", $1); emit($1); free_str($1); }
  | IDENTIFIER '[' ']' '=' new_array_expr
    {
      pt_leaf("VarName", $1);
      /* Java: int[] a = new int[n];  =>  C++: vector<int> a(n); */
      /* The type 'vector<int>' was already emitted; emit 'a(n)' */
      emit($1);
      emit("(");
      {
        const char *s = $5;
        const char *open = strchr(s, '(');
        if (open) {
          open++;
          const char *close = strrchr(s, ')');
          if (close && close > open) {
            size_t len = (size_t)(close - open);
            char *inner = malloc(len + 1);
            if (inner) { memcpy(inner, open, len); inner[len] = '\0'; emit(inner); free(inner); }
          } else { emit(s); }
        } else { emit(s); }
      }
      emit(")");
      free_str($1); free_str($5);
    }
  ;

local_var_list_inline
  : local_var_one { $$ = $1; }
  | local_var_list_inline ',' local_var_tail
    { char *t = join3($1, ", ", $3); free_str($1); free_str($3); $$ = t; }
  ;

local_var_one
  : IDENTIFIER
    { $$ = dup_str($1); free_str($1); }
  | IDENTIFIER '=' expr
    { char *t = join3($1, " = ", $3); free_str($1); free_str($3); $$ = t; }
  | IDENTIFIER '[' ']' '=' new_array_expr
    {
      char inner_buf[256] = "";
      const char *s5 = $5;
      const char *op = strchr(s5, '(');
      if (op) {
        op++;
        const char *cp = strrchr(s5, ')');
        if (cp && cp > op) {
          size_t ln = (size_t)(cp - op);
          if (ln < sizeof(inner_buf)) { memcpy(inner_buf, op, ln); inner_buf[ln] = '\0'; }
        }
      }
      char *inner = inner_buf[0] ? inner_buf : (char*)$5;
      char *t = join4($1, "(", inner, ")");
      free_str($1); free_str($5);
      $$ = t;
    }
  ;

local_var_tail
  : IDENTIFIER
    { $$ = dup_str($1); free_str($1); }
  | IDENTIFIER '=' expr
    { char *t = join3($1, " = ", $3); free_str($1); free_str($3); $$ = t; }
  ;

new_array_expr
  : NEW INT '[' expr ']'
    {
      char *tmp = join2($4, ")");
      $$ = join2("vector<int>(", tmp);
      free(tmp);
      free_str($4);
    }
  | NEW BOOLEAN '[' expr ']'
    {
      char *tmp = join2($4, ")");
      $$ = join2("vector<bool>(", tmp);
      free(tmp);
      free_str($4);
    }
  | NEW STRING_T '[' expr ']'
    {
      char *tmp = join2($4, ")");
      $$ = join2("vector<string>(", tmp);
      free(tmp);
      free_str($4);
    }
  ;

expr_list_inline
  : expr
  | expr_list_inline ',' expr
    { char *t = join3($1, ", ", $3); free_str($1); free_str($3); $$ = t; }
  ;

for_step_opt
  : /* empty */ { $$ = NULL; }
  | expr_list_inline { $$ = $1; }
  ;

expr_opt
  : /* empty */ { $$ = NULL; }
  | expr { $$ = $1; }
  ;

assign
  : lor { $$ = $1; }
  | unary '=' assign
    { $$ = join3($1, " = ", $3); free_str($1); free_str($3); }
  | unary PLUSEQ assign
    { $$ = join3($1, " += ", $3); free_str($1); free_str($3); }
  | unary MINUSEQ assign
    { $$ = join3($1, " -= ", $3); free_str($1); free_str($3); }
  ;

lor
  : land { $$ = $1; }
  | lor OROR land
    { $$ = join3($1, " || ", $3); free_str($1); free_str($3); }
  ;

land
  : equality { $$ = $1; }
  | land ANDAND equality
    { $$ = join3($1, " && ", $3); free_str($1); free_str($3); }
  ;

equality
  : relational { $$ = $1; }
  | equality EQEQ relational
    { $$ = join3($1, " == ", $3); free_str($1); free_str($3); }
  | equality NE relational
    { $$ = join3($1, " != ", $3); free_str($1); free_str($3); }
  ;

relational
  : add { $$ = $1; }
  | relational LT add
    { $$ = join3($1, " < ", $3); free_str($1); free_str($3); }
  | relational GT add
    { $$ = join3($1, " > ", $3); free_str($1); free_str($3); }
  | relational LE add
    { $$ = join3($1, " <= ", $3); free_str($1); free_str($3); }
  | relational GE add
    { $$ = join3($1, " >= ", $3); free_str($1); free_str($3); }
  ;

add
  : mul { $$ = $1; }
  | add '+' mul
    { $$ = join3($1, " + ", $3); free_str($1); free_str($3); }
  | add '-' mul
    { $$ = join3($1, " - ", $3); free_str($1); free_str($3); }
  ;

mul
  : unary { $$ = $1; }
  | mul '*' unary
    { $$ = join3($1, " * ", $3); free_str($1); free_str($3); }
  | mul '/' unary
    { $$ = join3($1, " / ", $3); free_str($1); free_str($3); }
  | mul '%' unary
    { $$ = join3($1, " % ", $3); free_str($1); free_str($3); }
  ;

unary
  : postfix { $$ = $1; }
  | '!' unary
    { $$ = join2("!", $2); free_str($2); }
  | '-' unary %prec UMINUS
    { $$ = join2("-", $2); free_str($2); }
  | INC unary
    { $$ = join2("++", $2); free_str($2); }
  | DEC unary
    { $$ = join2("--", $2); free_str($2); }
  ;

postfix
  : primary { $$ = $1; }
  | postfix '[' expr ']'
    { $$ = join4($1, "[", $3, "]"); free_str($1); free_str($3); }
  | postfix INC
    { $$ = join2($1, "++"); free_str($1); }
  | postfix DEC
    { $$ = join2($1, "--"); free_str($1); }
  ;

primary
  : INT_LITERAL { $$ = $1; }
  | STRING_LITERAL
    { $$ = cpp_string_literal($1); free_str($1); }
  | TRUE { $$ = dup_str("true"); }
  | FALSE { $$ = dup_str("false"); }
  | THIS { $$ = dup_str("this"); }
  | IDENTIFIER
    { $$ = $1; }
  | IDENTIFIER '(' arg_list_opt ')'
    {
      /* Function call: name(args) */
      pt_leaf("FuncCall", $1);
      $$ = join4($1, "(", $3, ")");
      free_str($1);
      free_str($3);
    }
  | '(' expr ')'
    { $$ = join3("(", $2, ")"); free_str($2); }
  | NEW INT '[' expr ']'
    { $$ = join3("vector<int>(", $4, ")"); free_str($4); }
  | NEW BOOLEAN '[' expr ']'
    { $$ = join3("vector<bool>(", $4, ")"); free_str($4); }
  | NEW STRING_T '[' expr ']'
    { $$ = join3("vector<string>(", $4, ")"); free_str($4); }
  ;

expr
  : assign { $$ = $1; }
  ;

%%

void yyerror(const char *s) {
  extern int yylineno;
  fprintf(stderr, "%s near line %d\n", s, yylineno);
}

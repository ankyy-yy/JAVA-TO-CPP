%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "parser.tab.h"

FILE *out;

void yyerror(const char *s);
int yylex(void);

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

static void emit_java_type(const char *cpp_type) {
  emit(cpp_type);
}

static void free_str(char *s) {
  if (s) free(s);
}
%}

%union {
  char *str;
}

%token <str> IDENTIFIER INT_LITERAL STRING_LITERAL

%token PRINTLN PACKAGE IMPORT PUBLIC PRIVATE PROTECTED STATIC FINAL
%token CLASS VOID INT BOOLEAN TRUE FALSE IF ELSE FOR WHILE RETURN NEW STRING_T THIS
%token ANDAND OROR LE GE EQEQ NE LT GT INC DEC PLUSEQ MINUSEQ

%nonassoc LOWER_THAN_ELSE
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

%start program

%%

program
  : package_opt import_list class_decl
  ;

package_opt
  : /* empty */
  | PACKAGE dotted ';'
  ;

import_list
  : /* empty */
  | import_list IMPORT dotted ';'
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
  : modifier_list CLASS IDENTIFIER '{' members '}'
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
  ;

field
  : modifier_list java_type_spec IDENTIFIER ';'
    {
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

method
  : modifier_list VOID IDENTIFIER '(' param_list_opt ')'
    {
      if (strcmp($3, "main") == 0) {
        emit("int main(int argc, char* argv[]) ");
      } else {
        emit("static void ");
        emit($3);
        emit("() ");
      }
      free_str($3);
    }
    block
  | modifier_list java_type_spec IDENTIFIER '(' param_list_opt ')'
    {
      emit("static ");
      emit($2);
      emit(" ");
      emit($3);
      emit("() ");
      free_str($2);
      free_str($3);
    }
    block
  ;

param_list_opt
  : /* empty */
  | java_type_spec IDENTIFIER
    { free_str($1); free_str($2); }
  | STRING_T '[' ']' IDENTIFIER
    { free_str($4); }
  | param_list_opt ',' java_type_spec IDENTIFIER
    { free_str($3); free_str($4); }
  ;

block
  : '{' { emit("{\n"); } stmts '}' { emit("}\n"); }
  ;

stmts
  : /* empty */
  | stmts stmt
  ;

stmt
  : block
  | IF '(' expr ')'
    { emit("if ("); emit($3); emit(") "); free_str($3); }
    stmt %prec LOWER_THAN_ELSE
  | IF '(' expr ')'
    { emit("if ("); emit($3); emit(") "); free_str($3); }
    stmt
    ELSE
    { emit(" else "); }
    stmt
  | WHILE '(' expr ')'
    { emit("while ("); emit($3); emit(") "); free_str($3); }
    stmt
  | FOR '(' for_init_opt ';' expr_opt ';' for_step_opt ')'
    {
      emit("for (");
      if ($3) { emit($3); free_str($3); }
      emit(";");
      if ($5) { emit($5); free_str($5); }
      emit(";");
      if ($7) { emit($7); free_str($7); }
      emit(") ");
    }
    stmt
  | RETURN expr_opt ';'
    {
      emit("return");
      if ($2) {
        emit(" ");
        emit($2);
        free_str($2);
      }
      emit(";\n");
    }
  | java_type_spec
    { emit($1); emit(" "); free_str($1); }
    local_var_list ';'
    { emit("\n"); }
  | PRINTLN '(' expr ')' ';'
    {
      emit("cout << ");
      emit($3);
      emit(" << endl;\n");
      free_str($3);
    }
  | assign ';'
    { emit($1); emit(";\n"); free_str($1); }
  | postfix INC ';'
    { emit($1); emit("++;\n"); free_str($1); }
  | postfix DEC ';'
    { emit($1); emit("--;\n"); free_str($1); }
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
  : IDENTIFIER { emit($1); free_str($1); }
  | IDENTIFIER '=' expr
    { emit($1); emit(" = "); emit($3); free_str($1); free_str($3); }
  | IDENTIFIER '[' ']' { emit($1); free_str($1); }
  | IDENTIFIER '[' ']' '=' new_array_expr
    { emit($1); emit(" = "); emit($5); free_str($1); free_str($5); }
  ;

local_var_list_inline
  : local_var_one { $$ = $1; }
  | local_var_list_inline ',' local_var_tail
    { char *t = join3($1, ",", $3); free_str($1); free_str($3); $$ = t; }
  ;

local_var_one
  : IDENTIFIER
    { $$ = dup_str($1); free_str($1); }
  | IDENTIFIER '=' expr
    { char *t = join3($1, "=", $3); free_str($1); free_str($3); $$ = t; }
  | IDENTIFIER '[' ']' '=' new_array_expr
    { char *t = join3($1, "=", $5); free_str($1); free_str($5); $$ = t; }
  ;

local_var_tail
  : IDENTIFIER
    { $$ = dup_str($1); free_str($1); }
  | IDENTIFIER '=' expr
    { char *t = join3($1, "=", $3); free_str($1); free_str($3); $$ = t; }
  ;

new_array_expr
  : NEW INT '[' expr ']'
    { $$ = join2("vector<int>(", join2($4, ")")); free_str($4); }
  ;

expr_list_inline
  : expr
  | expr_list_inline ',' expr
    { char *t = join3($1, ",", $3); free_str($1); free_str($3); $$ = t; }
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
    { $$ = join3($1, "=", $3); free_str($1); free_str($3); }
  | unary PLUSEQ assign
    { $$ = join3($1, "+=", $3); free_str($1); free_str($3); }
  | unary MINUSEQ assign
    { $$ = join3($1, "-=", $3); free_str($1); free_str($3); }
  ;

lor
  : land { $$ = $1; }
  | lor OROR land
    { $$ = join3($1, "||", $3); free_str($1); free_str($3); }
  ;

land
  : equality { $$ = $1; }
  | land ANDAND equality
    { $$ = join3($1, "&&", $3); free_str($1); free_str($3); }
  ;

equality
  : relational { $$ = $1; }
  | equality EQEQ relational
    { $$ = join3($1, "==", $3); free_str($1); free_str($3); }
  | equality NE relational
    { $$ = join3($1, "!=", $3); free_str($1); free_str($3); }
  ;

relational
  : add { $$ = $1; }
  | relational LT add
    { $$ = join3($1, "<", $3); free_str($1); free_str($3); }
  | relational GT add
    { $$ = join3($1, ">", $3); free_str($1); free_str($3); }
  | relational LE add
    { $$ = join3($1, "<=", $3); free_str($1); free_str($3); }
  | relational GE add
    { $$ = join3($1, ">=", $3); free_str($1); free_str($3); }
  ;

add
  : mul { $$ = $1; }
  | add '+' mul
    { $$ = join3($1, "+", $3); free_str($1); free_str($3); }
  | add '-' mul
    { $$ = join3($1, "-", $3); free_str($1); free_str($3); }
  ;

mul
  : unary { $$ = $1; }
  | mul '*' unary
    { $$ = join3($1, "*", $3); free_str($1); free_str($3); }
  | mul '/' unary
    { $$ = join3($1, "/", $3); free_str($1); free_str($3); }
  | mul '%' unary
    { $$ = join3($1, "%", $3); free_str($1); free_str($3); }
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
    { $$ = join2(join3($1, "[", $3), "]"); free_str($1); free_str($3); }
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
  | IDENTIFIER { $$ = $1; }
  | '(' expr ')'
    { $$ = join3("(", $2, ")"); free_str($2); }
  | NEW INT '[' expr ']'
    { $$ = join3("vector<int>(", $4, ")"); free_str($4); }
  ;

expr
  : assign { $$ = $1; }
  ;

%%

void yyerror(const char *s) {
  extern int yylineno;
  fprintf(stderr, "%s near line %d\n", s, yylineno);
}

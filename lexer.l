%option noyywrap nodefault yylineno
%{
#include "parser.tab.h"
#include <stdlib.h>
#include <string.h>

void yyerror(const char *msg);

static char str_lit_buf[8192];
static char *str_lit_ptr;
%}

%x STR
%x COMMENT

%%

[ \t\r\n]+                 ;
"//".*                     ;
"/*"                       { BEGIN(COMMENT); }
<COMMENT>"*/"              { BEGIN(INITIAL); }
<COMMENT>.|\n              ;

"System.out.println"       return PRINTLN;
"package"                  return PACKAGE;
"import"                   return IMPORT;
"public"                   return PUBLIC;
"private"                  return PRIVATE;
"protected"                return PROTECTED;
"static"                   return STATIC;
"final"                    return FINAL;
"class"                    return CLASS;
"void"                     return VOID;
"int"                      return INT;
"boolean"                  return BOOLEAN;
"true"                     return TRUE;
"false"                    return FALSE;
"if"                       return IF;
"else"                     return ELSE;
"for"                      return FOR;
"while"                    return WHILE;
"return"                   return RETURN;
"new"                      return NEW;
"String"                   return STRING_T;
"this"                     return THIS;

"&&"                       return ANDAND;
"||"                       return OROR;
"<="                       return LE;
">="                       return GE;
"=="                       return EQEQ;
"!="                       return NE;
"<"                        return LT;
">"                        return GT;
"++"                       return INC;
"--"                       return DEC;
"+="                       return PLUSEQ;
"-="                       return MINUSEQ;

[0-9]+                     { yylval.str = strdup(yytext); return INT_LITERAL; }

\"                         { BEGIN(STR); str_lit_ptr = str_lit_buf; }
<STR>\\n                   { if (str_lit_ptr < str_lit_buf + sizeof(str_lit_buf) - 1) *str_lit_ptr++ = '\n'; }
<STR>\\t                   { if (str_lit_ptr < str_lit_buf + sizeof(str_lit_buf) - 1) *str_lit_ptr++ = '\t'; }
<STR>\\r                   { if (str_lit_ptr < str_lit_buf + sizeof(str_lit_buf) - 1) *str_lit_ptr++ = '\r'; }
<STR>\\\"                  { if (str_lit_ptr < str_lit_buf + sizeof(str_lit_buf) - 1) *str_lit_ptr++ = '"'; }
<STR>\\\\                  { if (str_lit_ptr < str_lit_buf + sizeof(str_lit_buf) - 1) *str_lit_ptr++ = '\\'; }
<STR>\"                    { *str_lit_ptr = '\0'; BEGIN(INITIAL); yylval.str = strdup(str_lit_buf); return STRING_LITERAL; }
<STR>.                     { if (str_lit_ptr < str_lit_buf + sizeof(str_lit_buf) - 1) *str_lit_ptr++ = yytext[0]; }
<STR>\n                    { yyerror("unterminated string"); return 0; }

[A-Za-z_][A-Za-z0-9_]*     { yylval.str = strdup(yytext); return IDENTIFIER; }

";"                        return ';';
","                        return ',';
"."                        return '.';
"("                        return '(';
")"                        return ')';
"{"                        return '{';
"}"                        return '}';
"["                        return '[';
"]"                        return ']';
"="                        return '=';
"+"                        return '+';
"-"                        return '-';
"*"                        return '*';
"/"                        return '/';
"%"                        return '%';
"!"                        return '!';

.                          { return yytext[0]; }

%%

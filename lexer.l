%option noyywrap nodefault yylineno
%{
#include "parser.tab.h"
#include <stdlib.h>
#include <string.h>

void yyerror(const char *msg);

/* ── Token recording ───────────────────────────────────── */
extern FILE *token_out;          /* set in main.c */

void record_token(const char* type, const char* value) {
    if (token_out) {
        /* Escape newlines/tabs so each token stays on one line */
        fprintf(token_out, "%s\t", type);
        for (const char *p = value; *p; ++p) {
            switch (*p) {
                case '\n': fputs("\\n", token_out); break;
                case '\t': fputs("\\t", token_out); break;
                case '\r': fputs("\\r", token_out); break;
                case '\\': fputs("\\\\", token_out); break;
                default:   fputc(*p, token_out);    break;
            }
        }
        fputc('\n', token_out);
    }
}

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

"System.out.println"       { record_token("PRINTLN", yytext); return PRINTLN; }
"package"                  { record_token("PACKAGE", yytext); return PACKAGE; }
"import"                   { record_token("IMPORT", yytext); return IMPORT; }
"public"                   { record_token("PUBLIC", yytext); return PUBLIC; }
"private"                  { record_token("PRIVATE", yytext); return PRIVATE; }
"protected"                { record_token("PROTECTED", yytext); return PROTECTED; }
"static"                   { record_token("STATIC", yytext); return STATIC; }
"final"                    { record_token("FINAL", yytext); return FINAL; }
"class"                    { record_token("CLASS", yytext); return CLASS; }
"void"                     { record_token("VOID", yytext); return VOID; }
"int"                      { record_token("INT", yytext); return INT; }
"boolean"                  { record_token("BOOLEAN", yytext); return BOOLEAN; }
"true"                     { record_token("TRUE", yytext); return TRUE; }
"false"                    { record_token("FALSE", yytext); return FALSE; }
"if"                       { record_token("IF", yytext); return IF; }
"else"                     { record_token("ELSE", yytext); return ELSE; }
"for"                      { record_token("FOR", yytext); return FOR; }
"while"                    { record_token("WHILE", yytext); return WHILE; }
"do"                       { record_token("DO", yytext); return DO; }
"return"                   { record_token("RETURN", yytext); return RETURN; }
"new"                      { record_token("NEW", yytext); return NEW; }
"String"                   { record_token("STRING_T", yytext); return STRING_T; }
"StringBuilder"            { record_token("STRINGBUILDER", yytext); return STRINGBUILDER; }
"this"                     { record_token("THIS", yytext); return THIS; }

"&&"                       { record_token("ANDAND", yytext); return ANDAND; }
"||"                       { record_token("OROR", yytext); return OROR; }
"<="                       { record_token("LE", yytext); return LE; }
">="                       { record_token("GE", yytext); return GE; }
"=="                       { record_token("EQEQ", yytext); return EQEQ; }
"!="                       { record_token("NE", yytext); return NE; }
"<"                        { record_token("LT", yytext); return LT; }
">"                        { record_token("GT", yytext); return GT; }
"++"                       { record_token("INC", yytext); return INC; }
"--"                       { record_token("DEC", yytext); return DEC; }
"+="                       { record_token("PLUSEQ", yytext); return PLUSEQ; }
"-="                       { record_token("MINUSEQ", yytext); return MINUSEQ; }

[0-9]+                     { yylval.str = strdup(yytext); record_token("INT_LITERAL", yytext); return INT_LITERAL; }

\"                         { BEGIN(STR); str_lit_ptr = str_lit_buf; }
<STR>\\n                   { if (str_lit_ptr < str_lit_buf + sizeof(str_lit_buf) - 1) *str_lit_ptr++ = '\n'; }
<STR>\\t                   { if (str_lit_ptr < str_lit_buf + sizeof(str_lit_buf) - 1) *str_lit_ptr++ = '\t'; }
<STR>\\r                   { if (str_lit_ptr < str_lit_buf + sizeof(str_lit_buf) - 1) *str_lit_ptr++ = '\r'; }
<STR>\\\"                  { if (str_lit_ptr < str_lit_buf + sizeof(str_lit_buf) - 1) *str_lit_ptr++ = '"'; }
<STR>\\\\                  { if (str_lit_ptr < str_lit_buf + sizeof(str_lit_buf) - 1) *str_lit_ptr++ = '\\'; }
<STR>\"                    { *str_lit_ptr = '\0'; BEGIN(INITIAL); yylval.str = strdup(str_lit_buf); record_token("STRING_LITERAL", str_lit_buf); return STRING_LITERAL; }
<STR>.                     { if (str_lit_ptr < str_lit_buf + sizeof(str_lit_buf) - 1) *str_lit_ptr++ = yytext[0]; }
<STR>\n                    { yyerror("unterminated string"); return 0; }

[A-Za-z_][A-Za-z0-9_]*     { yylval.str = strdup(yytext); record_token("IDENTIFIER", yytext); return IDENTIFIER; }

";"                        { record_token("SEMI", yytext); return ';'; }
","                        { record_token("COMMA", yytext); return ','; }
"."                        { record_token("DOT", yytext); return '.'; }
"("                        { record_token("LPAREN", yytext); return '('; }
")"                        { record_token("RPAREN", yytext); return ')'; }
"{"                        { record_token("LBRACE", yytext); return '{'; }
"}"                        { record_token("RBRACE", yytext); return '}'; }
"["                        { record_token("LBRACKET", yytext); return '['; }
"]"                        { record_token("RBRACKET", yytext); return ']'; }
"="                        { record_token("ASSIGN", yytext); return '='; }
"+"                        { record_token("PLUS", yytext); return '+'; }
"-"                        { record_token("MINUS", yytext); return '-'; }
"*"                        { record_token("MUL", yytext); return '*'; }
"/"                        { record_token("DIV", yytext); return '/'; }
"%"                        { record_token("MOD", yytext); return '%'; }
"!"                        { record_token("NOT", yytext); return '!'; }

.                          { char buf[2] = {yytext[0], 0}; record_token("UNKNOWN", buf); return yytext[0]; }

%%

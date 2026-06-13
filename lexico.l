%{
#include <string>
%}

%option noyywrap

ESPACO [ \t]
DIGITO [0-9]
LETRA [a-zA-Z]

DELIM {ESPACO}+
FNUM [-]?{DIGITO}+"."{DIGITO}*
NUM [-]?{DIGITO}+
ID {LETRA}({LETRA}|[0-9]|_)*
STRLIT \"([^\\\"\n]|\\.)*\"

%%

"\r"        {}
"\n"		{ linha++; }

{DELIM} 	{}

"int"       { return TK_INT; }
"float"     { return TK_FLOAT; }
"char"      { return TK_CHAR; }
"bool"      { return TK_BOOLEAN; }
"string"    { return TK_STRING; }
"printf"    { return TK_PRINTF; }
"print"     { return TK_PRINT; }
"scan"      { return TK_SCAN; }
"if"        { return TK_IF; }
"else"      { return TK_ELSE; }
"while"     { return TK_WHILE; }
"do"        { return TK_DO; }
"break"     { return TK_BREAK; }
"switch"    { return TK_SWITCH; }
"case"      { return TK_CASE; }
"default"   { return TK_DEFAULT; }
"for"       { return TK_FOR; }
"continue"  { return TK_CONTINUE; }
"function"  { return TK_FUNCTION; }
"return"    { return TK_RETURN; }
"true"      { yylval.label = "1"; return TK_BOOL_LIT; }
"false"     { yylval.label = "0"; return TK_BOOL_LIT; }
"'"[^'\\\n]"'"   { yylval.label = yytext; return TK_CHAR_LIT; }
{STRLIT}     { yylval.label = yytext; return TK_STR_LIT; }
"=="        { return TK_IGUAL; }
"!="        { return TK_DIFERENTE; }
"+="        { return TK_ADD_ASSIGN; }
"-="        { return TK_SUB_ASSIGN; }
"*="        { return TK_MUL_ASSIGN; }
"/="        { return TK_DIV_ASSIGN; }
"++"        { return TK_INC; }
"--"        { return TK_DEC; }
"&&"        { return TK_AND; }
"||"        { return TK_OR; }
"!"         { return TK_NOT; }
"<"         { return TK_MENOR; }
">"         { return TK_MAIOR; }
"<="        { return TK_MENOR_OU_IGUAL; }
">="        { return TK_MAIOR_OU_IGUAL; }

[+]			{ return *yytext; }
[-]         { return *yytext; }
[*]         { return *yytext; }
[/]         { return *yytext; }
[(]         { return *yytext; }
[)]         { return *yytext; }
[=]         { return *yytext; }
[;]         { return *yytext; }
[,]         { return *yytext; }
[:]         { return *yytext; }
[{]         { return *yytext; }
[}]         { return *yytext; }


{NUM}		{ yylval.label = yytext; return TK_NUM; }
{FNUM}      { yylval.label = yytext; return TK_FNUM; }
{ID}        { yylval.label = yytext; return TK_ID; }

.			{ fprintf(stderr, "Caractere nao reconhecido na linha %d: %s\n", linha, yytext); }

%%

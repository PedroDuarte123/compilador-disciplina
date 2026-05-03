%{
#include <string>
%}

%option noyywrap

ESPACO [ \t]
DIGITO [0-9]
LETRA [a-zA-Z]

DELIM {ESPACO}+
FNUM {DIGITO}+"."{DIGITO}*
NUM {DIGITO}+
ID {LETRA}({LETRA}|[0-9]|_)*

%%

"\n"		{ linha++; }

{DELIM} 	{}

"int"       { return TK_INT; }
"float"     { return TK_FLOAT; }
"char"      { return TK_CHAR; }
"bool"      { return TK_BOOLEAN; }
"true"      { yylval.label = "1"; return TK_BOOL_LIT; }
"false"     { yylval.label = "0"; return TK_BOOL_LIT; }
"'"[^'\\\n]"'"   { yylval.label = yytext; return TK_CHAR_LIT; }

[+]			{ return *yytext; }
[-]         { return *yytext; }
[*]         { return *yytext; }
[/]         { return *yytext; }
[(]         { return *yytext; }
[)]         { return *yytext; }
[=]         { return *yytext; }
[;]         { return *yytext; }

{NUM}		{ yylval.label = yytext; return TK_NUM; }
{FNUM}      { yylval.label = yytext; return TK_FNUM; }
{ID}        { yylval.label = yytext; return TK_ID; }

.			{ fprintf(stderr, "Caractere nao reconhecido na linha %d: %s\n", linha, yytext); }

%%

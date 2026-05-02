%{
#include <string>
%}

%option noyywrap

ESPACO [ \t]
DIGITO [0-9]
LETRA [a-zA-Z]

DELIM {ESPACO}+
NUM {DIGITO}+
ID {LETRA}({LETRA}|[0-9]|_)*

%%

"\n"		{ linha++; }

{DELIM} 	{}

[+]			{ return *yytext; }
[-]         { return *yytext; }
[*]         { return *yytext; }
[/]         { return *yytext; }
[(]         { return *yytext; }
[)]         { return *yytext; }

[=] { return *yytext; }

{NUM}		{ yylval.label = yytext; return TK_NUM; }
{ID}        { yylval.label = yytext; return TK_ID; }

.			{ fprintf(stderr, "Caractere nao reconhecido na linha %d: %s\n", linha, yytext); }

%%

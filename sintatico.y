%{
// -----------------------------
// Arquivo do Bison (parser)
// -----------------------------
// Este arquivo descreve a gramática da linguagem FOCA e, junto com as ações
// semânticas (blocos { ... }), gera uma "tradução" (string) que vira código C.
//
// Estrutura típica do .y:
// 1) Prologue %{ ... %}  -> código C/C++ copiado para o arquivo gerado (y.tab.c)
// 2) Declarações Bison    -> %token, %left, %start, etc.
// 3) Gramática            -> regras e ações semânticas
// 4) Epilogue (após %%)   -> mais código C/C++ copiado ao final do y.tab.c

#include <iostream>
#include <string>
#include <map>



using namespace std;

int var_temp_qnt;
int linha = 1;
string codigo_gerado;

struct atributos
{
	string label;
	string traducao;
};

struct simbolo{
	string nome;
	string tipo;
	string memoria;
	bool inicializado;

	simbolo() : nome(""), tipo(""), memoria(""), inicializado(false) {}

	simbolo(string argnome, string argtipo, string argmemoria, bool arginicializado = false):
		nome(argnome), tipo(argtipo), memoria(argmemoria), inicializado(arginicializado) {} 
};

#define YYSTYPE atributos
map <string, simbolo> tabela_simbolos;
map<string, string> tipos_temp;

int yylex(void);
void yyerror(string);
string gentempcode(string tipo = "int");
string gen_temp_declarations();
void is_declarado(string);
void is_inicializado(string);
%}

%token TK_NUM
%token TK_FNUM
%token TK_ID
%token TK_INT
%token TK_FLOAT

%start S

%left '+' '-'
%left '*' '/'
%left '(' ')'


%%

S 			: D E
			{
				codigo_gerado = "/*Compilador FOCA*/\n"
								"#include <stdio.h>\n"
								"int main(void) {\n";

				codigo_gerado += gen_temp_declarations();

				codigo_gerado += $2.traducao;

				codigo_gerado += "\treturn 0;"
							"\n}\n";
			}
			;

D 			: D TK_INT TK_ID ';'
			{
				string memoria = gentempcode();
				tabela_simbolos[$3.label] = simbolo($3.label, "int", memoria, false);
			}
			| TK_FLOAT TK_ID ';'{
				string memoria = gentempcode();
				tabela_simbolos[$3.label] = simbolo($3.label, "float", memoria, false);
			}
			| /* vazio */
			{
				/* base da recursao de D */
			}
			;

E 			: E '+' E
			{
				$$.label = gentempcode();
				$$.traducao = $1.traducao + $3.traducao + "\t" + $$.label +
					" = " + $1.label + " + " + $3.label + ";\n";
			}
			| E '-' E
			{
				$$.label = gentempcode();
				$$.traducao = $1.traducao + $3.traducao + "\t" + $$.label +
					" = " + $1.label + " - " + $3.label + ";\n";
			}
			| E '*' E
			{
				$$.label = gentempcode();
				$$.traducao = $1.traducao + $3.traducao + "\t" + $$.label +
					" = " + $1.label + " * " + $3.label + ";\n";
			}
			| E '/' E
			{
				$$.label = gentempcode();
				$$.traducao = $1.traducao + $3.traducao + "\t" + $$.label +
					" = " + $1.label + " / " + $3.label + ";\n";	
			}
			| '(' E ')'
			{
				$$.label = $2.label;
				$$.traducao = $2.traducao;
			}
			| TK_ID '=' E
			{
				is_declarado($1.label);
				tabela_simbolos[$1.label].inicializado = true;
				$$.label = tabela_simbolos[$1.label].memoria;
    			$$.traducao = $3.traducao + "\t" + $$.label + " = " + $3.label + ";\n";
			}
			| TK_NUM
			{
				$$.label = gentempcode("int");
				$$.traducao = "\t" + $$.label + " = " + $1.label + ";\n";
			}
			| TK_FNUM
			{
				$$.label = gentempcode("float");
				$$.traducao = "\t" + $$.label + " = " + $1.label + ";\n";
			}
			| TK_ID
			{
				is_declarado($1.label);
				$$.label = tabela_simbolos[$1.label].memoria;
				$$.traducao = "";
			}
			;

%%

#include "lex.yy.c"

int yyparse();

string gentempcode(string tipo)
{
	var_temp_qnt++;
	string temp = "t" + to_string(var_temp_qnt);
    tipos_temp[temp] = tipo;
    return temp;
}

// TODO: Fazer essa função declarar corretamente variáveis que não são do tipo int.
	
string gen_temp_declarations()
{
	string declarations;
	for (int i = 1; i <= var_temp_qnt; i++){
		 string temp = "t" + to_string(i);
        string tipo = tipos_temp[temp];
        if (tipo.empty()) tipo = "int";  // default
        declarations += "\t" + tipo + " " + temp + ";\n";
	}
		
	if (var_temp_qnt > 0)
		declarations += "\n";
	return declarations;
}

void is_declarado(string nome){
	if (tabela_simbolos.find(nome) == tabela_simbolos.end()) { /* Verifica se a variável foi declarada */
        yyerror("Variável '" + nome + "' não declarada");
		return;
    }
}

void is_inicializado(string nome){
	if (!tabela_simbolos[nome].inicializado) { /* Verifica se a variável foi inicializada */
        yyerror("Variável '" + nome + "' usada antes de inicialização");
		return;
    }
}


int main(int argc, char* argv[])
{
	var_temp_qnt = 0;
	tabela_simbolos.clear();
	if (yyparse() == 0)
		cout << codigo_gerado;

	return 0;
}

void yyerror(string MSG)
{
	cerr << "Erro na linha " << linha << ": " << MSG << endl;
}

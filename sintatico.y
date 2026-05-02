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
	string tipo;
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

simbolo* buscar_simbolo(const string& nome);
const simbolo* buscar_simbolo_const(const string& nome);

static inline bool is_tipo_valido(const string& t) { return t == "int" || t == "float"; }
static inline string tipo_resultado_aritmetico(const string& a, const string& b)
{
	if (a == "float" || b == "float") return "float";
	return "int";
}

int yylex(void);
void yyerror(string);
string gentempcode(string tipo = "int");
string gen_temp_declarations();
void is_declarado(string);
void is_inicializado(string);
void atribuir_temporario(string);
string upcast_para_float(string label, string tipo, string &code);
atributos gerar_op_aritmetica(const atributos& expressao_esquerda, const char* op, const atributos& expressao_direita);
%}

%token TK_NUM
%token TK_FNUM
%token TK_ID
%token TK_INT
%token TK_FLOAT

%start S

%right '='
%left '+' '-'
%left '*' '/'


%%

S 			: D E OPT_PONTO_VIRGULA
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

OPT_PONTO_VIRGULA	: ';'
			| /* vazio */
			;

TIPO		: TK_INT
			{
				$$.tipo = "int";
			}
			| TK_FLOAT
			{
				$$.tipo = "float";
			}
			;


D 			: D TIPO TK_ID ';'
			{
				if (buscar_simbolo_const($3.label))
				{
					yyerror("Variável '" + $3.label + "' redeclarada");
				}
				else
				{
					tabela_simbolos.emplace($3.label, simbolo($3.label, $2.tipo, "", false));
				}
			}
			| /* vazio */
			{
				/* base da recursao de D */
			}
			;

E 			: E '+' E
			{
				$$ = gerar_op_aritmetica($1, "+", $3);
			}
			| E '-' E
			{
				$$ = gerar_op_aritmetica($1, "-", $3);
			}
			| E '*' E
			{
				$$ = gerar_op_aritmetica($1, "*", $3);
			}
			| E '/' E
			{
				$$ = gerar_op_aritmetica($1, "/", $3);
			}
			| '(' TIPO ')' E
			{
				string target = $2.tipo;
				if (!is_tipo_valido(target))
					yyerror("Tipo inválido no cast");
				$$.tipo = target;
				$$.label = gentempcode(target);
				$$.traducao = $4.traducao + "\t" + $$.label +
					" = (" + target + ") " + $4.label + ";\n";
			}
			| '(' E ')'
			{
				$$.label = $2.label;
				$$.traducao = $2.traducao;
				$$.tipo = $2.tipo;
			}
			| TK_ID '=' E
			{
				is_declarado($1.label);
				simbolo* sym = buscar_simbolo($1.label);
				if (!sym)
				{
					$$.label = "";
					$$.traducao = $3.traducao;
					$$.tipo = $3.tipo;
				}
				else
				{
					atribuir_temporario($1.label);
					string tipo_expressao_esquerda = sym->tipo;
					string tipo_expressao_direita = $3.tipo;
					string label_expressao_direita = $3.label;
					string codigo_expressao_direita = $3.traducao;
				if (tipo_expressao_esquerda == "float" && tipo_expressao_direita == "int")
				{
					string tmp = gentempcode("float");
					codigo_expressao_direita += "\t" + tmp + " = (float) " + label_expressao_direita + ";\n";
					label_expressao_direita = tmp;
					tipo_expressao_direita = "float";
				}
				if (tipo_expressao_esquerda == "int" && tipo_expressao_direita == "float")
				{
					yyerror("Conversão explícita necessária para atribuir float em int");
				}
				sym->inicializado = true;
				$$.label = sym->memoria;
				$$.tipo = tipo_expressao_esquerda;
	    		$$.traducao = codigo_expressao_direita + "\t" + $$.label + " = " + label_expressao_direita + ";\n";
				}
			}
			| TK_NUM
			{
				$$.label = gentempcode("int");
				$$.traducao = "\t" + $$.label + " = " + $1.label + ";\n";
				$$.tipo = "int";
			}
			| TK_FNUM
			{
				$$.label = gentempcode("float");
				$$.traducao = "\t" + $$.label + " = " + $1.label + ";\n";
				$$.tipo = "float";
			}
			| TK_ID
			{
				is_declarado($1.label);
				const simbolo* sym = buscar_simbolo_const($1.label);
				if (!sym)
				{
					$$.label = "";
					$$.traducao = "";
					$$.tipo = "int";
				}
				else
				{
					atribuir_temporario($1.label);
					string t = sym->tipo;
					$$.tipo = t;
					if (t == "float")
					{
						// Para float, sempre gera um "load" para um temporário de expressão.
						$$.label = gentempcode("float");
						$$.traducao = "\t" + $$.label + " = " + sym->memoria + ";\n";
					}
					else
					{
						// Para int, usar diretamente a célula de memória da variável.
						$$.label = sym->memoria;
						$$.traducao = "";
					}
				}
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

string upcast_para_float(string label, string tipo, string &code)
{
	if (tipo != "int")
		return label;
	string tmp = gentempcode("float");
	code += "\t" + tmp + " = (float) " + label + ";\n";
	return tmp;
}

atributos gerar_op_aritmetica(const atributos& expressao_esquerda, const char* op, const atributos& expressao_direita)
{
	atributos out;
	string tipo_res = tipo_resultado_aritmetico(expressao_esquerda.tipo, expressao_direita.tipo);
	string codigo_expressao_esquerda = expressao_esquerda.traducao;
	string codigo_expressao_direita = expressao_direita.traducao;
	string label_expressao_esquerda = expressao_esquerda.label;
	string label_expressao_direita = expressao_direita.label;
	if (tipo_res == "float")
	{
		label_expressao_esquerda = upcast_para_float(label_expressao_esquerda, expressao_esquerda.tipo, codigo_expressao_esquerda);
		label_expressao_direita = upcast_para_float(label_expressao_direita, expressao_direita.tipo, codigo_expressao_direita);
	}
	out.tipo = tipo_res;
	out.label = gentempcode(tipo_res);
	out.traducao = codigo_expressao_esquerda + codigo_expressao_direita + "\t" + out.label +
		" = " + label_expressao_esquerda + " " + op + " " + label_expressao_direita + ";\n";
	return out;
}

	
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
	if (!buscar_simbolo_const(nome)) { /* Verifica se a variável foi declarada */
        yyerror("Variável '" + nome + "' não declarada");
		return;
    }
}

void is_inicializado(string nome){
	const simbolo* sym = buscar_simbolo_const(nome);
	if (!sym)
	{
		yyerror("Variável '" + nome + "' não declarada");
		return;
	}
	if (!sym->inicializado) { /* Verifica se a variável foi inicializada */
        yyerror("Variável '" + nome + "' usada antes de inicialização");
		return;
    }
}

void atribuir_temporario(string nome)
{
	simbolo* sym = buscar_simbolo(nome);
	if (!sym)
		return;
	if (sym->memoria.empty())
	{
		string tipo = sym->tipo;
		if (!is_tipo_valido(tipo))
			tipo = "int";
		sym->memoria = gentempcode(tipo);
	}
}

simbolo* buscar_simbolo(const string& nome)
{
	auto it = tabela_simbolos.find(nome);
	if (it == tabela_simbolos.end())
		return nullptr;
	return &it->second;
}


// Função só de leitura para evitar modificações acidentais
const simbolo* buscar_simbolo_const(const string& nome)
{
	auto it = tabela_simbolos.find(nome);
	if (it == tabela_simbolos.end())
		return nullptr;
	return &it->second;
}


int main(int argc, char* argv[])
{
	var_temp_qnt = 0;
	tabela_simbolos.clear();
	tipos_temp.clear();
	if (yyparse() == 0)
		cout << codigo_gerado;

	return 0;
}

void yyerror(string MSG)
{
	cerr << "Erro na linha " << linha << ": " << MSG << endl;
}

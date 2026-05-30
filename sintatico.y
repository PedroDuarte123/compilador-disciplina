%{
#include <iostream>
#include <string>
#include <map>
#include <vector>

using namespace std;

int var_temp_qnt;
int linha = 1;
string codigo_gerado;
bool usa_string = false;
int erros = 0;
int label_qnt = 0;

struct atributos
{
	string label;
	string traducao;
	string tipo;
};

struct simbolo{
	string nome;
	string tipo;
	string nome_interno;
	bool inicializado;

	simbolo() : nome(""), tipo(""), nome_interno(""), inicializado(false) {}

	simbolo(string argnome, string argtipo, string argnomeinterno, bool arginicializado = false):
		nome(argnome), tipo(argtipo), nome_interno(argnomeinterno), inicializado(arginicializado) {} 
};

#define YYSTYPE atributos
map<string, string> tipos_temp;

static vector< map<string, simbolo> > escopos;

static void push_scope();
static void pop_scope();
static map<string, simbolo>& escopo_atual();

simbolo* buscar_simbolo(const string& nome);
const simbolo* buscar_simbolo_const(const string& nome);

bool is_tipo_valido(const string& t) { return t == "int" || t == "float" || t == "char" || t == "boolean" || t == "string"; }
bool is_string(const string& t) { return t == "string"; }
string tipo_resultado_aritmetico(const string& a, const string& b)
{
	if (a == "float" || b == "float") return "float";
	return "int";
}
string tipo_para_c(const string& t) {
	if (t == "boolean") return "int";
	if (t == "char")    return "char";
	if (t == "float")   return "float";
	if (t == "string")  return "foca_string";
	return "int";
}

string gen_string_runtime_support();

int yylex(void);
void yyerror(string);
string gentempcode(string tipo = "int");
string gen_temp_declarations();
void is_declarado(string);
void is_inicializado(string);
void atribuir_temporario(string);
string upcast_para_float(string label, string tipo, string &code);
atributos gerar_op_aritmetica(const atributos& expressao_esquerda, const char* op, const atributos& expressao_direita);
atributos gerar_op_soma(const atributos& expressao_esquerda, const atributos& expressao_direita);
atributos gerar_op_relacional(const atributos& expressao_esquerda, const char* op, const atributos& expressao_direita);
atributos gerar_op_logica(const atributos& expressao_esquerda, const char* op, const atributos& expressao_direita);
atributos gerar_op_concat(const atributos& expressao_esquerda, const atributos& expressao_direita);
string genlabel();
%}

%token TK_NUM
%token TK_FNUM
%token TK_ID
%token TK_INT
%token TK_FLOAT
%token TK_CHAR
%token TK_BOOLEAN
%token TK_STRING
%token TK_PRINT
%token TK_SCAN
%token TK_IF
%token TK_ELSE
%token TK_BOOL_LIT
%token TK_CHAR_LIT
%token TK_STR_LIT
%token TK_IGUAL
%token TK_DIFERENTE
%token TK_MENOR
%token TK_MAIOR
%token TK_MENOR_OU_IGUAL
%token TK_MAIOR_OU_IGUAL
%token TK_AND
%token TK_OR
%token TK_NOT

%start S

%right '='
%left TK_OR
%left TK_AND
%left TK_IGUAL TK_DIFERENTE TK_MENOR TK_MAIOR TK_MENOR_OU_IGUAL TK_MAIOR_OU_IGUAL
%left '+' '-'
%left '*' '/'
%right TK_NOT
%nonassoc TK_IFAKE // token fake para resolver ambiguidade do else (declarado antes, tem precedência menor)
%nonassoc TK_ELSE // precedência maior (declarado depois) -> resolver dangling else


%%

S			: LISTA_COMANDOS
			{
				codigo_gerado.clear();
				if (usa_string)
				{
					codigo_gerado += "/*Compilador FOCA*/\n";
					codigo_gerado += "#include <stdio.h>\n";
					codigo_gerado += "#include <stdlib.h>\n\n";
					string rt = gen_string_runtime_support();
					codigo_gerado += rt;
					codigo_gerado += "int main(void) {\n";
				}
				else
				{
					codigo_gerado += "/*Compilador FOCA*/\n";
					codigo_gerado += "#include <stdio.h>\n";
					codigo_gerado += "int main(void) {\n";
				}

				{
					string decls = gen_temp_declarations();
					codigo_gerado += decls;
				}

				codigo_gerado += $1.traducao;

				codigo_gerado += "\treturn 0;\n}\n";
			}
			;


TIPO		: TK_INT
			{
				$$.tipo = "int";
			}
			| TK_FLOAT
			{
				$$.tipo = "float";
			}
			| TK_CHAR
			{
				$$.tipo = "char";
			}
			| TK_BOOLEAN
			{
				$$.tipo = "boolean";
			}
			| TK_STRING
			{
				usa_string = true;
				$$.tipo = "string";
			}
			;

LISTA_COMANDOS	: LISTA_COMANDOS COMANDO
			{
				$$.traducao = $1.traducao + $2.traducao;
			}
			| /* vazio */
			{
				$$.traducao = "";
			}
			;

COMANDO		: TIPO TK_ID ';'
			{
				auto &cur = escopo_atual();
				if (cur.find($2.label) != cur.end())
				{
					yyerror("Variável '" + $2.label + "' redeclarada");
				}
				else
				{
					cur.emplace($2.label, simbolo($2.label, $1.tipo, "", false));
				}
				$$.traducao = "";
			}
			| TK_IF '(' E ')' COMANDO %prec TK_IFAKE // %prec usa a precedencia (menor) do token fake TK_IFAKE (evita ambiguidade do else)
			{									//	ELSE vai sempre casar com o IF mais próximo	(shift)				
				if ($3.tipo != "boolean")
					yyerror("Condição do if deve ser booleana");
				{
					string Lifelse = genlabel(); // Label fim de bloco if
					$$.traducao = $3.traducao
						+ "\tif (!" + $3.label + ") goto " + Lifelse + ";\n" // nega condição e gera go to para Lifelse (fim do if-else)
						+ $5.traducao
						+ Lifelse + ":\n";
				}
			}
			| TK_IF '(' E ')' COMANDO TK_ELSE COMANDO
			{
				if ($3.tipo != "boolean")
					yyerror("Condição do if deve ser booleana");
				{
					string Lelse = genlabel(); // Label início do bloco else
					string Lifelse = genlabel(); // Label fim de bloco if-else
					$$.traducao = $3.traducao
						+ "\tif (!" + $3.label + ") goto " + Lelse + ";\n"
						+ $5.traducao
						+ "\tgoto " + Lifelse + ";\n"
						+ Lelse + ":\n"
						+ $7.traducao
						+ Lifelse + ":\n";
				}
			}
			| BLOCO
			{
				$$.traducao = $1.traducao;
			}
			| TK_PRINT '(' TK_STR_LIT ')' ';'
			{
				$$.traducao = "\tprintf(" + $3.label + ");\n";
			}
			| TK_PRINT '(' TK_STR_LIT ',' ARGS ')' ';'
			{
				$$.traducao = $5.traducao + "\tprintf(" + $3.label + ", " + $5.label + ");\n";
			}
			| TK_SCAN TK_ID ';'
			{
				is_declarado($2.label);
				simbolo* sym = buscar_simbolo($2.label);
				if (!sym)
				{
					$$.traducao = "";
				}
				else
				{
					atribuir_temporario($2.label);
					sym->inicializado = true;
					if (is_string(sym->tipo))
					{
						usa_string = true;
						$$.traducao = "\tfoca_str_scanline(&" + sym->nome_interno + ");\n";
					}
					else if (sym->tipo == "float")
					{
						$$.traducao = "\tscanf(\"%f\", &" + sym->nome_interno + ");\n";
					}
					else if (sym->tipo == "char")
					{
						$$.traducao = "\tscanf(\" %c\", &" + sym->nome_interno + ");\n";
					}
					else
					{
						/* int/boolean */
						$$.traducao = "\tscanf(\"%d\", &" + sym->nome_interno + ");\n";
					}
				}
			}
			| E ';'
			{
				$$.traducao = $1.traducao;
			}
			;

BLOCO		: '{'
			{
				push_scope();
			}
			LISTA_COMANDOS
			'}'
			{
				pop_scope();
				$$.traducao = $3.traducao;
			}
			;

ARGS		: E
			{
				$$.traducao = $1.traducao;
				if (is_string($1.tipo))
					$$.label = "(" + $1.label + ".data ? " + $1.label + ".data : \"\")";
				if (is_string($1.tipo)) {
					usa_string = true;
					$$.label = "foca_str_cstr(&" + $1.label + ")";
				}
				else
					$$.label = $1.label;
			}
			| ARGS ',' E
			{
				$$.traducao = $1.traducao + $3.traducao;
				string arg;
				if (is_string($3.tipo))
					arg = "(" + $3.label + ".data ? " + $3.label + ".data : \"\")";
				if (is_string($3.tipo)) {
					usa_string = true;
					arg = "foca_str_cstr(&" + $3.label + ")";
				}
				else
					arg = $3.label;
				$$.label = $1.label + ", " + arg;
			}
			;

E 			: E '+' E
			{
				$$ = gerar_op_soma($1, $3);
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
			| E TK_IGUAL E
			{
				$$ = gerar_op_relacional($1, "==", $3);
			}
			| E TK_DIFERENTE E
			{
				$$ = gerar_op_relacional($1, "!=", $3);
			}
			| E TK_MENOR E
			{
				$$ = gerar_op_relacional($1, "<", $3);
			}
			| E TK_MAIOR E
			{
				$$ = gerar_op_relacional($1, ">", $3);
			}
			| E TK_MENOR_OU_IGUAL E
			{
				$$ = gerar_op_relacional($1, "<=", $3);
			}
			| E TK_MAIOR_OU_IGUAL E
			{
				$$ = gerar_op_relacional($1, ">=", $3);
			}
			| E TK_AND E
			{
				$$ = gerar_op_logica($1, "&&", $3);
			}
			| E TK_OR E
			{
				$$ = gerar_op_logica($1, "||", $3);
			}
			| TK_NOT E
			{
				if ($2.tipo != "boolean")
					yyerror("Operador lógico '!' exige boolean");
				$$.tipo = "boolean";
				$$.label = gentempcode("boolean");
				$$.traducao = $2.traducao + "\t" + $$.label + " = !" + $2.label + ";\n";
			}
			| '(' TIPO ')' E
			{
				string target = $2.tipo;
				if (!is_tipo_valido(target))
					yyerror("Tipo inválido no cast");
				if (is_string(target) || is_string($4.tipo))
					yyerror("Cast envolvendo string não suportado");
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

					if (is_string(tipo_expressao_esquerda) || is_string(tipo_expressao_direita))
					{
						usa_string = true;
						if (!is_string(tipo_expressao_esquerda) || !is_string(tipo_expressao_direita))
							yyerror("Tipos incompatíveis: não é possível atribuir " + tipo_expressao_direita + " em " + tipo_expressao_esquerda);
					}
					else if (tipo_expressao_esquerda == "float" && tipo_expressao_direita == "int")
					{
						string tmp = gentempcode("float");
						codigo_expressao_direita += "\t" + tmp + " = (float) " + label_expressao_direita + ";\n";
						label_expressao_direita = tmp;
						tipo_expressao_direita = "float";
					}
					else if (tipo_expressao_esquerda == "int" && tipo_expressao_direita == "float")
					{
						yyerror("Conversão explícita necessária para atribuir float em int");
					}
					else if (tipo_expressao_esquerda != tipo_expressao_direita)
					{
						yyerror("Tipos incompatíveis: não é possível atribuir " + tipo_expressao_direita + " em " + tipo_expressao_esquerda);
					}

					sym->inicializado = true;
					$$.label = sym->nome_interno;
					$$.tipo = tipo_expressao_esquerda;
					if (is_string(tipo_expressao_esquerda))
						$$.traducao = codigo_expressao_direita + "\tfoca_str_copy(&" + $$.label + ", &" + label_expressao_direita + ");\n";
					else
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
			| TK_BOOL_LIT
			{
				$$.label = gentempcode("boolean");
				$$.traducao = "\t" + $$.label + " = " + $1.label + ";\n";
				$$.tipo = "boolean";
			}
			| TK_CHAR_LIT
			{
				$$.label = gentempcode("char");
				$$.traducao = "\t" + $$.label + " = " + $1.label + ";\n";
				$$.tipo = "char";
			}
			| TK_STR_LIT
			{
				usa_string = true;
				$$.label = gentempcode("string");
				$$.traducao = "\tfoca_str_from_lit(&" + $$.label + ", " + $1.label + ", (int)(sizeof(" + $1.label + ") - 1));\n";
				$$.tipo = "string";
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
						$$.label = gentempcode("float");
						$$.traducao = "\t" + $$.label + " = " + sym->nome_interno + ";\n";
					}
					else  /* int, char, boolean — usa memória diretamente */
					{
						$$.label = sym->nome_interno;
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

bool is_literal_label(const string& label)
{
	return !label.empty() && (isdigit((unsigned char)label[0]) || label[0] == '\'');
}

void ensure_float_temp_for_literal(string &label, string &code, const atributos &expr)
{
	if (expr.tipo == "float" && expr.traducao.empty() && is_literal_label(label))
	{
		string tmp = gentempcode("float");
		code += "\t" + tmp + " = " + label + ";\n";
		label = tmp;
	}
}

bool is_boolean(const string& tipo)
{
	return tipo == "boolean";
}

atributos gerar_op_aritmetica(const atributos& expressao_esquerda, const char* op, const atributos& expressao_direita)
{
	atributos out;
	if (is_string(expressao_esquerda.tipo) || is_string(expressao_direita.tipo))
	{
		yyerror("Operação aritmética inválida com string");
		out.tipo = "int";
		out.label = "";
		out.traducao = expressao_esquerda.traducao + expressao_direita.traducao;
		return out;
	}
	string tipo_res = tipo_resultado_aritmetico(expressao_esquerda.tipo, expressao_direita.tipo);
	string codigo_expressao_esquerda = expressao_esquerda.traducao;
	string codigo_expressao_direita = expressao_direita.traducao;
	string label_expressao_esquerda = expressao_esquerda.label;
	string label_expressao_direita = expressao_direita.label;
	if (tipo_res == "float")
	{
		label_expressao_esquerda = upcast_para_float(label_expressao_esquerda, expressao_esquerda.tipo, codigo_expressao_esquerda);
		label_expressao_direita = upcast_para_float(label_expressao_direita, expressao_direita.tipo, codigo_expressao_direita);
		ensure_float_temp_for_literal(label_expressao_esquerda, codigo_expressao_esquerda, expressao_esquerda);
		ensure_float_temp_for_literal(label_expressao_direita, codigo_expressao_direita, expressao_direita);
	}
	out.tipo = tipo_res;
	out.label = gentempcode(tipo_res);
	out.traducao = codigo_expressao_esquerda + codigo_expressao_direita + "\t" + out.label +
		" = " + label_expressao_esquerda + " " + op + " " + label_expressao_direita + ";\n";
	return out;
}

atributos gerar_op_concat(const atributos& expressao_esquerda, const atributos& expressao_direita)
{
	atributos out;
	usa_string = true;
	if (!is_string(expressao_esquerda.tipo) || !is_string(expressao_direita.tipo))
	{
		yyerror("Concatenação exige dois operandos string");
		out.tipo = "string";
		out.label = "";
		out.traducao = expressao_esquerda.traducao + expressao_direita.traducao;
		return out;
	}
	out.tipo = "string";
	out.label = gentempcode("string");
	out.traducao = expressao_esquerda.traducao + expressao_direita.traducao +
		"\tfoca_str_concat(&" + out.label + ", &" + expressao_esquerda.label + ", &" + expressao_direita.label + ");\n";
	return out;
}

atributos gerar_op_soma(const atributos& expressao_esquerda, const atributos& expressao_direita)
{
	if (is_string(expressao_esquerda.tipo) || is_string(expressao_direita.tipo))
		return gerar_op_concat(expressao_esquerda, expressao_direita);
	return gerar_op_aritmetica(expressao_esquerda, "+", expressao_direita);
}

atributos gerar_op_relacional(const atributos& expressao_esquerda, const char* op, const atributos& expressao_direita)
{
	atributos out;
	if (is_string(expressao_esquerda.tipo) || is_string(expressao_direita.tipo))
	{
		usa_string = true;
		string sop = op;
		if (is_string(expressao_esquerda.tipo) && is_string(expressao_direita.tipo) && (sop == "==" || sop == "!="))
		{
			out.tipo = "boolean";
			out.label = gentempcode("boolean");
			out.traducao = expressao_esquerda.traducao + expressao_direita.traducao;
			if (sop == "==")
				out.traducao += "\t" + out.label + " = foca_str_eq(&" + expressao_esquerda.label + ", &" + expressao_direita.label + ");\n";
			else
				out.traducao += "\t" + out.label + " = !foca_str_eq(&" + expressao_esquerda.label + ", &" + expressao_direita.label + ");\n";
			return out;
		}
		yyerror("Operador relacional inválido com string");
		out.tipo = "boolean";
		out.label = gentempcode("boolean");
		out.traducao = expressao_esquerda.traducao + expressao_direita.traducao + "\t" + out.label + " = 0;\n";
		return out;
	}
	string tipo_comum = tipo_resultado_aritmetico(expressao_esquerda.tipo, expressao_direita.tipo);
	string codigo_expressao_esquerda = expressao_esquerda.traducao;
	string codigo_expressao_direita = expressao_direita.traducao;
	string label_expressao_esquerda = expressao_esquerda.label;
	string label_expressao_direita = expressao_direita.label;
	if (tipo_comum == "float")
	{
		label_expressao_esquerda = upcast_para_float(label_expressao_esquerda, expressao_esquerda.tipo, codigo_expressao_esquerda);
		label_expressao_direita = upcast_para_float(label_expressao_direita, expressao_direita.tipo, codigo_expressao_direita);
		ensure_float_temp_for_literal(label_expressao_esquerda, codigo_expressao_esquerda, expressao_esquerda);
		ensure_float_temp_for_literal(label_expressao_direita, codigo_expressao_direita, expressao_direita);
	}
	out.tipo = "boolean";
	out.label = gentempcode("boolean");
	out.traducao = codigo_expressao_esquerda + codigo_expressao_direita + "\t" + out.label +
		" = " + label_expressao_esquerda + " " + op + " " + label_expressao_direita + ";\n";
	return out;
}

atributos gerar_op_logica(const atributos& expressao_esquerda, const char* op, const atributos& expressao_direita)
{
	atributos out;
	if (!is_boolean(expressao_esquerda.tipo) || !is_boolean(expressao_direita.tipo))
	{
		yyerror("Operadores lógicos '&&' e '||' exigem operandos booleanos");
	}
	string codigo_expressao_esquerda = expressao_esquerda.traducao;
	string codigo_expressao_direita = expressao_direita.traducao;
	string label_expressao_esquerda = expressao_esquerda.label;
	string label_expressao_direita = expressao_direita.label;
	out.tipo = "boolean";
	out.label = gentempcode("boolean");
	out.traducao = codigo_expressao_esquerda + codigo_expressao_direita + "\t" + out.label +
		" = " + label_expressao_esquerda + " " + op + " " + label_expressao_direita + ";\n";
	return out;
}

string gen_temp_declarations()
{
	string declarations;
	string init_code;
	for (int i = 1; i <= var_temp_qnt; i++){
		string temp = "t" + to_string(i);
		string tipo = tipos_temp[temp];
		if (tipo.empty()) tipo = "int";
		declarations += "\t" + tipo_para_c(tipo) + " " + temp + ";\n";
		if (tipo == "string")
			init_code += "\tfoca_str_init(&" + temp + ");\n";
	}
	if (var_temp_qnt > 0)
		declarations += "\n";
	if (!init_code.empty())
		declarations += init_code + "\n";
	return declarations;
}

string gen_string_runtime_support()
{
	return string(
		"typedef struct {\n"
		"\tchar *data;\n"
		"\tint len;\n"
		"\tint cap;\n"
		"} foca_string;\n\n"
		"static void foca_str_init(foca_string *s) {\n"
		"\ts->data = NULL;\n"
		"\ts->len = 0;\n"
		"\ts->cap = 0;\n"
		"}\n\n"
		"static const char* foca_str_cstr(const foca_string *s) {\n"
		"\tconst char *p;\n"
		"\tint t1;\n"
		"\tt1 = (s != NULL);\n"
		"\tif (t1) goto L_cstr_check_data;\n"
		"\tp = \"\";\n"
		"\tgoto L_cstr_end;\n"
		"L_cstr_check_data:\n"
		"\tt1 = (s->data != NULL);\n"
		"\tif (t1) goto L_cstr_ok;\n"
		"\tp = \"\";\n"
		"\tgoto L_cstr_end;\n"
		"L_cstr_ok:\n"
		"\tp = s->data;\n"
		"L_cstr_end:\n"
		"\treturn p;\n"
		"}\n\n"
		"/* Runtime em estilo 3-endereços (labels + goto; sem for/while/else/?:). */\n"
		"static void foca_str_reserve(foca_string *s, int needed_cap) {\n"
		"\tint new_cap;\n"
		"\tchar *p;\n"
		"\tint t1;\n"
		"\tt1 = (needed_cap <= s->cap);\n"
		"\tif (t1) goto L_reserve_end;\n"
		"\tt1 = (s->cap != 0);\n"
		"\tif (t1) goto L_reserve_has_cap;\n"
		"\tnew_cap = 64;\n"
		"\tgoto L_reserve_loop_check;\n"
		"L_reserve_has_cap:\n"
		"\tnew_cap = s->cap;\n"
		"L_reserve_loop_check:\n"
		"\tt1 = (new_cap >= needed_cap);\n"
		"\tif (t1) goto L_reserve_realloc;\n"
		"\tnew_cap = new_cap * 2;\n"
		"\tgoto L_reserve_loop_check;\n"
		"L_reserve_realloc:\n"
		"\tp = (char*)realloc(s->data, (size_t)new_cap);\n"
		"\tt1 = (p != NULL);\n"
		"\tif (t1) goto L_reserve_ok;\n"
		"\tfprintf(stderr, \"Erro: sem memória ao alocar string\\n\");\n"
		"\texit(1);\n"
		"L_reserve_ok:\n"
		"\ts->data = p;\n"
		"\ts->cap = new_cap;\n"
		"\tt1 = (s->len != 0);\n"
		"\tif (t1) goto L_reserve_end;\n"
		"\tt1 = (s->data == NULL);\n"
		"\tif (t1) goto L_reserve_end;\n"
		"\ts->data[0] = '\\0';\n"
		"L_reserve_end:\n"
		"\treturn;\n"
		"}\n\n"
		"static char* foca_strcopy_end(char *dst, const char *src) {\n"
		"\tchar *dp;\n"
		"\tconst char *sp;\n"
		"\tchar ch;\n"
		"\tint t1;\n"
		"\tdp = dst;\n"
		"\tsp = src;\n"
		"L_copy_loop:\n"
		"\tch = *sp;\n"
		"\tt1 = (ch == '\\0');\n"
		"\tif (t1) goto L_copy_end;\n"
		"\t*dp = ch;\n"
		"\tdp = dp + 1;\n"
		"\tsp = sp + 1;\n"
		"\tgoto L_copy_loop;\n"
		"L_copy_end:\n"
		"\t*dp = '\\0';\n"
		"\treturn dp;\n"
		"}\n\n"
		"static void foca_str_from_lit(foca_string *s, const char *lit, int lit_len) {\n"
		"\tint needed;\n"
		"\tchar *end;\n"
		"\tneeded = lit_len + 1;\n"
		"\tfoca_str_reserve(s, needed);\n"
		"\tend = foca_strcopy_end(s->data, lit);\n"
		"\t(void)end;\n"
		"\ts->len = lit_len;\n"
		"\treturn;\n"
		"}\n\n"
		"static void foca_str_copy(foca_string *dst, const foca_string *src) {\n"
		"\tint needed;\n"
		"\tconst char *sp;\n"
		"\tchar *end;\n"
		"\tint t1;\n"
		"\tneeded = src->len + 1;\n"
		"\tfoca_str_reserve(dst, needed);\n"
		"\tt1 = (src->data != NULL);\n"
		"\tif (t1) goto L_copy_src_ok;\n"
		"\tsp = \"\";\n"
		"\tgoto L_copy_do;\n"
		"L_copy_src_ok:\n"
		"\tsp = src->data;\n"
		"L_copy_do:\n"
		"\tend = foca_strcopy_end(dst->data, sp);\n"
		"\t(void)end;\n"
		"\tdst->len = src->len;\n"
		"\treturn;\n"
		"}\n\n"
		"static void foca_str_concat(foca_string *dst, const foca_string *a, const foca_string *b) {\n"
		"\tint alen;\n"
		"\tint blen;\n"
		"\tint new_len;\n"
		"\tconst char *ap;\n"
		"\tconst char *bp;\n"
		"\tchar *end;\n"
		"\tint t1;\n"
		"\talen = a->len;\n"
		"\tblen = b->len;\n"
		"\tnew_len = alen + blen;\n"
		"\tfoca_str_reserve(dst, new_len + 1);\n"
		"\tt1 = (a->data != NULL);\n"
		"\tif (t1) goto L_cat_a_ok;\n"
		"\tap = \"\";\n"
		"\tgoto L_cat_a_done;\n"
		"L_cat_a_ok:\n"
		"\tap = a->data;\n"
		"L_cat_a_done:\n"
		"\tt1 = (b->data != NULL);\n"
		"\tif (t1) goto L_cat_b_ok;\n"
		"\tbp = \"\";\n"
		"\tgoto L_cat_b_done;\n"
		"L_cat_b_ok:\n"
		"\tbp = b->data;\n"
		"L_cat_b_done:\n"
		"\tend = foca_strcopy_end(dst->data, ap);\n"
		"\tend = foca_strcopy_end(end, bp);\n"
		"\t(void)end;\n"
		"\tdst->len = new_len;\n"
		"\treturn;\n"
		"}\n\n"
		"static int foca_str_eq(const foca_string *a, const foca_string *b) {\n"
		"\tint i;\n"
		"\tchar ca;\n"
		"\tchar cb;\n"
		"\tint t1;\n"
		"\tt1 = (a->len == b->len);\n"
		"\tif (t1) goto L_eq_loop_init;\n"
		"\treturn 0;\n"
		"L_eq_loop_init:\n"
		"\ti = 0;\n"
		"L_eq_loop_check:\n"
		"\tt1 = (i < a->len);\n"
		"\tif (t1) goto L_eq_load_a;\n"
		"\treturn 1;\n"
		"L_eq_load_a:\n"
		"\tt1 = (a->data != NULL);\n"
		"\tif (t1) goto L_eq_a_ok;\n"
		"\tca = 0;\n"
		"\tgoto L_eq_load_b;\n"
		"L_eq_a_ok:\n"
		"\tca = a->data[i];\n"
		"L_eq_load_b:\n"
		"\tt1 = (b->data != NULL);\n"
		"\tif (t1) goto L_eq_b_ok;\n"
		"\tcb = 0;\n"
		"\tgoto L_eq_cmp;\n"
		"L_eq_b_ok:\n"
		"\tcb = b->data[i];\n"
		"L_eq_cmp:\n"
		"\tt1 = (ca == cb);\n"
		"\tif (t1) goto L_eq_inc;\n"
		"\treturn 0;\n"
		"L_eq_inc:\n"
		"\ti = i + 1;\n"
		"\tgoto L_eq_loop_check;\n"
		"}\n\n"
		"static void foca_str_scanline(foca_string *s) {\n"
		"\tint ch;\n"
		"\tint needed;\n"
		"\tint t1;\n"
		"\ts->len = 0;\n"
		"\tfoca_str_reserve(s, 1);\n"
		"\tt1 = (s->data == NULL);\n"
		"\tif (t1) goto L_scan_read_first;\n"
		"\ts->data[0] = '\\0';\n"
		"L_scan_read_first:\n"
		"\tch = getchar();\n"
		"L_scan_skip_newline:\n"
		"\tt1 = (ch == '\\n');\n"
		"\tif (t1) goto L_scan_get_next_skip;\n"
		"\tt1 = (ch == '\\r');\n"
		"\tif (t1) goto L_scan_get_next_skip;\n"
		"\tgoto L_scan_loop_check;\n"
		"L_scan_get_next_skip:\n"
		"\tch = getchar();\n"
		"\tgoto L_scan_skip_newline;\n"
		"L_scan_loop_check:\n"
		"\tt1 = (ch == EOF);\n"
		"\tif (t1) goto L_scan_done;\n"
		"\tt1 = (ch == '\\n');\n"
		"\tif (t1) goto L_scan_done;\n"
		"\tt1 = (ch == '\\r');\n"
		"\tif (t1) goto L_scan_done;\n"
		"\tneeded = s->len + 2;\n"
		"\tfoca_str_reserve(s, needed);\n"
		"\tt1 = (s->data == NULL);\n"
		"\tif (t1) goto L_scan_done;\n"
		"\ts->data[s->len] = (char)ch;\n"
		"\ts->len = s->len + 1;\n"
		"\ts->data[s->len] = '\\0';\n"
		"\tch = getchar();\n"
		"\tgoto L_scan_loop_check;\n"
		"L_scan_done:\n"
		"\treturn;\n"
		"}\n\n"
		"static void foca_str_scanline(foca_string *s) {\n"
		"\t/* Lê uma linha inteira (com espaços) de stdin. */\n"
		"\ts->len = 0;\n"
		"\tfoca_str_reserve(s, 1);\n"
		"\tif (s->data) s->data[0] = '\\0';\n"
		"\tint ch = getchar();\n"
		"\twhile (ch == '\\n' || ch == '\\r') {\n"
		"\t\tch = getchar();\n"
		"\t}\n"
		"\twhile (ch != EOF && ch != '\\n' && ch != '\\r') {\n"
		"\t\tint needed = s->len + 2;\n"
		"\t\tfoca_str_reserve(s, needed);\n"
		"\t\ts->data[s->len++] = (char)ch;\n"
		"\t\ts->data[s->len] = '\\0';\n"
		"\t\tch = getchar();\n"
		"\t}\n"
		"}\n\n"
	);
}

string genlabel() // gera Labels para o Goto
{
	label_qnt++;
	return "L" + to_string(label_qnt);
}

void is_declarado(string nome){
	if (!buscar_simbolo_const(nome)) {
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
	if (!sym->inicializado) {
		yyerror("Variável '" + nome + "' usada antes de inicialização");
		return;
	}
}

void atribuir_temporario(string nome)
{
	simbolo* sym = buscar_simbolo(nome);
	if (!sym)
		return;
	if (sym->nome_interno.empty())
	{
		string tipo = sym->tipo;
		if (!is_tipo_valido(tipo))
			tipo = "int";
		sym->nome_interno = gentempcode(tipo);
	}
}

simbolo* buscar_simbolo(const string& nome)
{
	for (int i = (int)escopos.size() - 1; i >= 0; i--)
	{
		auto it = escopos[(size_t)i].find(nome);
		if (it != escopos[(size_t)i].end())
			return &it->second;
	}
	return nullptr;
}

const simbolo* buscar_simbolo_const(const string& nome)
{
	for (int i = (int)escopos.size() - 1; i >= 0; i--)
	{
		auto it = escopos[(size_t)i].find(nome);
		if (it != escopos[(size_t)i].end())
			return &it->second;
	}
	return nullptr;
}

static map<string, simbolo>& escopo_atual()
{
	if (escopos.empty())
		escopos.emplace_back();
	return escopos.back();
}

static void push_scope()
{
	escopos.emplace_back();
}

static void pop_scope()
{
	if (!escopos.empty())
		escopos.pop_back();
	if (escopos.empty())
		escopos.emplace_back();
}

int main(int argc, char* argv[])
{
	var_temp_qnt = 0;
	erros = 0;
	escopos.clear();
	push_scope();
	tipos_temp.clear();
	int rc = yyparse();
	if (rc == 0 && erros == 0)
		cout << codigo_gerado;
	return (rc == 0 && erros == 0) ? 0 : 1;
}

void yyerror(string MSG)
{
	erros++;
	cerr << "Erro na linha " << linha << ": " << MSG << endl;
}
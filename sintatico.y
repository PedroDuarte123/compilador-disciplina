%{
#include <iostream>
#include <string>
#include <map>

using namespace std;

int var_temp_qnt;
int linha = 1;
string codigo_gerado;
bool usa_string = false;

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
map <string, simbolo> tabela_simbolos;
map<string, string> tipos_temp;

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
%}

%token TK_NUM
%token TK_FNUM
%token TK_ID
%token TK_INT
%token TK_FLOAT
%token TK_CHAR
%token TK_BOOLEAN
%token TK_STRING
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
				if (buscar_simbolo_const($2.label))
				{
					yyerror("Variável '" + $2.label + "' redeclarada");
				}
				else
				{
					tabela_simbolos.emplace($2.label, simbolo($2.label, $1.tipo, "", false));
				}
				$$.traducao = "";
			}
			| E ';'
			{
				$$.traducao = $1.traducao;
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
		"static void foca_str_reserve(foca_string *s, int needed_cap) {\n"
		"\tif (needed_cap <= s->cap) return;\n"
		"\tint new_cap = s->cap ? s->cap : 64;\n"
		"\twhile (new_cap < needed_cap) new_cap *= 2;\n"
		"\tchar *p = (char*)realloc(s->data, (size_t)new_cap);\n"
		"\tif (!p) {\n"
		"\t\tfprintf(stderr, \"Erro: sem memória ao alocar string\\n\");\n"
		"\t\texit(1);\n"
		"\t}\n"
		"\ts->data = p;\n"
		"\ts->cap = new_cap;\n"
		"\tif (s->len == 0) s->data[0] = '\\0';\n"
		"}\n\n"
		"static char* foca_strcopy_end(char *dst, const char *src) {\n"
		"\twhile (*src) { *dst++ = *src++; }\n"
		"\t*dst = '\\0';\n"
		"\treturn dst;\n"
		"}\n\n"
		"static char* foca_strcat_end(char *dst_end, const char *src) {\n"
		"\treturn foca_strcopy_end(dst_end, src);\n"
		"}\n\n"
		"static void foca_str_from_lit(foca_string *s, const char *lit, int lit_len) {\n"
		"\tint needed = lit_len + 1;\n"
		"\tfoca_str_reserve(s, needed);\n"
		"\tchar *end = foca_strcopy_end(s->data, lit);\n"
		"\t(void)end;\n"
		"\ts->len = lit_len;\n"
		"}\n\n"
		"static void foca_str_copy(foca_string *dst, const foca_string *src) {\n"
		"\tint needed = src->len + 1;\n"
		"\tfoca_str_reserve(dst, needed);\n"
		"\tchar *end = foca_strcopy_end(dst->data, src->data ? src->data : \"\");\n"
		"\t(void)end;\n"
		"\tdst->len = src->len;\n"
		"}\n\n"
		"static void foca_str_concat(foca_string *dst, const foca_string *a, const foca_string *b) {\n"
		"\tint alen = a->len;\n"
		"\tint blen = b->len;\n"
		"\tint new_len = alen + blen;\n"
		"\tfoca_str_reserve(dst, new_len + 1);\n"
		"\tchar *end = foca_strcopy_end(dst->data, a->data ? a->data : \"\");\n"
		"\tend = foca_strcat_end(end, b->data ? b->data : \"\");\n"
		"\t(void)end;\n"
		"\tdst->len = new_len;\n"
		"}\n\n"
		"static int foca_str_eq(const foca_string *a, const foca_string *b) {\n"
		"\tif (a->len != b->len) return 0;\n"
		"\tfor (int i = 0; i < a->len; i++) {\n"
		"\t\tchar ca = a->data ? a->data[i] : 0;\n"
		"\t\tchar cb = b->data ? b->data[i] : 0;\n"
		"\t\tif (ca != cb) return 0;\n"
		"\t}\n"
		"\treturn 1;\n"
		"}\n\n"
	);
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
	auto it = tabela_simbolos.find(nome);
	if (it == tabela_simbolos.end())
		return nullptr;
	return &it->second;
}

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

%{
#include <iostream>
#include <string>
#include <map>
#include <vector>
#include <cctype>

using namespace std;

int var_temp_qnt;
int linha = 1;
string codigo_gerado;
bool usa_string = false;
bool usa_io = false;
int erros = 0;
int label_qnt = 0;
string codigo_funcoes;

struct switch_context
{
	string switch_label;
	string expr_tipo; // tipo da exp q esta no switch
	string break_label;  // destino dos breaks
};

static vector<switch_context> switch_stack; // pilha de switches

struct loop_context
{
    string break_label;
    string continue_label;
};

static vector<loop_context> loop_stack; // pilha de loops

struct atributos
{
	string label;
	string traducao;
	string tipo;
	string extra;
	string extra2;
};

struct parametro_funcao
{
	string nome;
	string tipo;
	string nome_c;
	string nome_interno;
};

struct funcao_info
{
	string nome;
	string tipo_retorno;
	vector<parametro_funcao> parametros;
	string label_retorno;
	string nome_retorno;
	int temp_inicio;
	int temp_fim;

	funcao_info() : temp_inicio(0), temp_fim(0) {}
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
static map<string, funcao_info> funcoes;
static funcao_info* funcao_atual = nullptr;

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
string gen_io_runtime_support();
string gen_potencia_runtime_support();

int yylex(void);
void yyerror(string);
string gentempcode(string tipo = "int");
string gen_temp_declarations_range(int inicio_exclusivo, int fim_inclusivo);
void is_declarado(string);
void is_inicializado(string);
void atribuir_temporario(string);
string upcast_para_float(string label, string tipo, string &code);
void enter_switch(const atributos& expr); // funções para suportar switches aninhados (pilha de switches)
void exit_switch(); //
const switch_context& current_switch(); //
bool is_switch_tipo_valido(const string& tipo);
void enter_loop(const string& break_label, const string& continue_label);
void exit_loop();
const loop_context& current_loop();
atributos gerar_op_aritmetica(const atributos& expressao_esquerda, const char* op, const atributos& expressao_direita);
atributos gerar_op_potencia(const atributos& expressao_esquerda, const atributos& expressao_direita);
atributos gerar_op_soma(const atributos& expressao_esquerda, const atributos& expressao_direita);
atributos gerar_op_relacional(const atributos& expressao_esquerda, const char* op, const atributos& expressao_direita);
atributos gerar_op_logica(const atributos& expressao_esquerda, const char* op, const atributos& expressao_direita);
atributos gerar_op_concat(const atributos& expressao_esquerda, const atributos& expressao_direita);
atributos gerar_unario_aritmetico(const char* op, const atributos& expr);
atributos gerar_inc_dec(const string& nome, bool incrementar, bool prefixo);
atributos gerar_atribuicao(const string& nome, const atributos& expr);
atributos gerar_atribuicao_composta(const string& nome, const char* op, const atributos& expr);
string gerar_print_simples(const atributos& expr);
string gerar_print_template(const string& literal, const atributos& args);
string append_print_arg(const string& atual, const string& tipo, const string& label);
vector<string> split_print_args(const string& serializado);
string formatador_por_tipo(const string& tipo);
bool is_tipo_unario_aritmetico(const string& tipo);
string literal_um_para_tipo(const string& tipo);
string genlabel();
string append_param_decl(const string& atual, const string& tipo, const string& nome);
vector<parametro_funcao> parse_parametros_funcao(const string& serializado);
void registrar_funcao(const string& nome, const string& tipo_retorno, const string& params_serializados);
void iniciar_funcao(const string& nome);
string preparar_parametros_funcao();
string finalizar_funcao(const string& traducao_corpo);
void encerrar_funcao();
string append_call_arg(const string& atual, const string& nome, const string& tipo, const string& label);
atributos gerar_chamada_funcao(const string& nome, const atributos& argumentos);
string literal_padrao_tipo(const string& tipo);
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
%token TK_PRINTF
%token TK_SCAN
%token TK_IF
%token TK_ELSE
%token TK_WHILE
%token TK_DO
%token TK_FOR
%token TK_CONTINUE
%token TK_FUNCTION
%token TK_RETURN
%token TK_BREAK
%token TK_SWITCH
%token TK_CASE
%token TK_DEFAULT
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
%token TK_ADD_ASSIGN
%token TK_SUB_ASSIGN
%token TK_MUL_ASSIGN
%token TK_DIV_ASSIGN
%token TK_INC
%token TK_DEC

%start S

%right '=' TK_ADD_ASSIGN TK_SUB_ASSIGN TK_MUL_ASSIGN TK_DIV_ASSIGN
%left TK_OR
%left TK_AND
%left TK_IGUAL TK_DIFERENTE TK_MENOR TK_MAIOR TK_MENOR_OU_IGUAL TK_MAIOR_OU_IGUAL
%left '+' '-'
%left '*' '/'
%right TK_NOT UPLUS UMINUS PREINC PREDEC
%left POSTINC POSTDEC
%right '^'
%nonassoc TK_IFAKE // token fake para resolver ambiguidade do else (declarado antes, tem precedência menor)
%nonassoc TK_ELSE // precedência maior (declarado depois) -> resolver dangling else


%%

S			: LISTA_FUNCOES LISTA_COMANDOS
			{
				codigo_gerado.clear();
				if (usa_string)
				{
					codigo_gerado += "/*Compilador FOCA*/\n";
					codigo_gerado += "#include <stdio.h>\n";
					codigo_gerado += "#include <stdlib.h>\n\n";
					codigo_gerado += gen_potencia_runtime_support();
					string rt = gen_string_runtime_support();
					codigo_gerado += rt;
					if (usa_io)
						codigo_gerado += gen_io_runtime_support();
					codigo_gerado += $1.traducao;
					codigo_gerado += "int main(void) {\n";
				}
				else if (usa_io)
				{
					codigo_gerado += "/*Compilador FOCA*/\n";
					codigo_gerado += "#include <stdio.h>\n\n";
					codigo_gerado += gen_potencia_runtime_support();
					codigo_gerado += gen_io_runtime_support();
					codigo_gerado += $1.traducao;
					codigo_gerado += "int main(void) {\n";
				}
				else
				{
					codigo_gerado += "/*Compilador FOCA*/\n";
					codigo_gerado += "#include <stdio.h>\n";
					codigo_gerado += gen_potencia_runtime_support();
					codigo_gerado += "\n";
					codigo_gerado += $1.traducao;
					codigo_gerado += "int main(void) {\n";
				}

				{
					int inicio_main = $1.extra.empty() ? 0 : stoi($1.extra);
					string decls = gen_temp_declarations_range(inicio_main, var_temp_qnt);
					codigo_gerado += decls;
				}

				codigo_gerado += $2.traducao;

				codigo_gerado += "\treturn 0;\n}\n";
			}
			;


LISTA_FUNCOES	: LISTA_FUNCOES FUNCAO_DEF
			{
				$$.traducao = $1.traducao + $2.traducao;
				$$.extra = to_string(var_temp_qnt);
			}
			| /* vazio */
			{
				$$.traducao = "";
				$$.extra = to_string(var_temp_qnt);
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

FUNCAO_CABECALHO : TK_FUNCTION TIPO TK_ID '(' PARAMS_DECL_OPT ')'
			{
				registrar_funcao($3.label, $2.tipo, $5.label);
				iniciar_funcao($3.label);
				$$.label = $3.label;
			}
			;

FUNCAO_ENTER	: '{'
			{
				push_scope();
				$$.traducao = preparar_parametros_funcao();
			}
			;

BLOCO_FUNCAO	: FUNCAO_ENTER LISTA_COMANDOS '}'
			{
				pop_scope();
				$$.traducao = $1.traducao + $2.traducao;
			}
			;

FUNCAO_DEF	: FUNCAO_CABECALHO BLOCO_FUNCAO
			{
				$$.traducao = finalizar_funcao($2.traducao);
				encerrar_funcao();
			}
			;

PARAM_DECL	: TIPO TK_ID
			{
				$$.tipo = $1.tipo;
				$$.label = $2.label;
			}
			;

PARAMS_DECL	: PARAM_DECL
			{
				$$.label = append_param_decl("", $1.tipo, $1.label);
			}
			| PARAMS_DECL ',' PARAM_DECL
			{
				$$.label = append_param_decl($1.label, $3.tipo, $3.label);
			}
			;

PARAMS_DECL_OPT : PARAMS_DECL
			{
				$$.label = $1.label;
			}
			| /* vazio */
			{
				$$.label = "";
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
			| TK_BREAK ';'
			{
				if (!loop_stack.empty())
					$$.traducao = "\tgoto " + current_loop().break_label + ";\n"; // break em loop
				else if (!switch_stack.empty())
					$$.traducao = "\tgoto " + current_switch().break_label + ";\n"; // break em switch
				else
					yyerror("'break' fora de loop ou switch");
			}
			| TK_CONTINUE ';'
			{
				if (loop_stack.empty())
					yyerror("'continue' fora de loop");
				else
					$$.traducao = "\tgoto " + current_loop().continue_label + ";\n";
			}
			| TK_RETURN E ';'
			{
				if (!funcao_atual)
				{
					yyerror("'return' fora de função");
					$$.traducao = $2.traducao;
				}
				else
				{
					string tipo_destino = funcao_atual->tipo_retorno;
					string tipo_origem = $2.tipo;
					string valor = $2.label;
					string codigo = $2.traducao;

					if (is_string(tipo_destino) || is_string(tipo_origem))
					{
						usa_string = true;
						if (!is_string(tipo_destino) || !is_string(tipo_origem))
							yyerror("Tipos incompatíveis no retorno da função '" + funcao_atual->nome + "'");
					}
					else if (tipo_destino == "float" && tipo_origem == "int")
					{
						string tmp = gentempcode("float");
						codigo += "\t" + tmp + " = (float) " + valor + ";\n";
						valor = tmp;
					}
					else if (tipo_destino == "int" && tipo_origem == "float")
					{
						yyerror("Conversão explícita necessária no retorno da função '" + funcao_atual->nome + "'");
					}
					else if (tipo_destino != tipo_origem)
					{
						yyerror("Tipos incompatíveis no retorno da função '" + funcao_atual->nome + "'");
					}

					if (is_string(tipo_destino))
						codigo += "\tfoca_str_copy(&" + funcao_atual->nome_retorno + ", &" + valor + ");\n";
					else
						codigo += "\t" + funcao_atual->nome_retorno + " = " + valor + ";\n";
					codigo += "\tgoto " + funcao_atual->label_retorno + ";\n";
					$$.traducao = codigo;
				}
			}
		| WHILE_HEAD COMANDO
    	{
        $$.traducao = $1.label + ":\n"
            + $1.traducao
            + "\tif (!" + $1.extra + ") goto " + $1.tipo + ";\n"  // ← $1.extra em vez de nada
            + $2.traducao
            + "\tgoto " + $1.label + ";\n"
            + $1.tipo + ":\n";
       		 exit_loop();
   		 }
		| DO_HEAD COMANDO TK_WHILE '(' E ')' ';'
		{
			if ($5.tipo != "boolean")
				yyerror("Condição do do/while deve ser booleana");
			{
				$$.traducao = $1.traducao + $1.label + ":\n" + $2.traducao + $1.tipo + ":\n" + $5.traducao
					+ "\tif (" + $5.label + ") goto " + $1.label + ";\n"
					+ $1.extra + ":\n";
				exit_loop();
			}
		}
		| FOR_HEAD COMANDO
		{
			$$.traducao = $1.traducao + $2.traducao + $1.tipo + ":\n" + $1.extra2 + "\tgoto " + $1.label + ";\n" + $1.extra + ":\n";
			exit_loop();
		}
				| TK_SWITCH '(' E ')' 
					{
						if (!is_switch_tipo_valido($3.tipo))
							yyerror("Switch deve usar expressão int, char ou boolean");
						enter_switch($3); // cria switch na pilha
					}
					'{' SWITCH_CLAUSES '}'
					{
						const switch_context& context = current_switch();
						$$.traducao = $3.traducao + $7.traducao + context.break_label + ":\n";
						exit_switch(); // remove da pilha após finalizar switch
					}
			| BLOCO
			{
				$$.traducao = $1.traducao;
			}
			| TK_PRINT '(' TK_STR_LIT ')' ';'
			{
				$$.traducao = "\tprintf(" + $3.label + ");\n";
			}
			| TK_PRINTF '(' TK_STR_LIT ',' ARGS ')' ';'
			{
				$$.traducao = gerar_print_template($3.label, $5);
			}
			| TK_PRINT '(' E ')' ';'
			{
				$$.traducao = gerar_print_simples($3);
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
					usa_io = true;
					atribuir_temporario($2.label);
					sym->inicializado = true;
					if (is_string(sym->tipo))
					{
						usa_string = true;
						$$.traducao = "\tfoca_str_scanline(&" + sym->nome_interno + ");\n";
					}
					else if (sym->tipo == "float")
					{
						string tscan = gentempcode("int");
						string tok = gentempcode("boolean");
						string Lok = genlabel();
						$$.traducao = "\t" + tscan + " = scanf(\"%f\", &" + sym->nome_interno + ");\n"
							+ "\t" + tok + " = (" + tscan + " == 1);\n"
							+ "\tif (" + tok + ") goto " + Lok + ";\n"
							+ "\t" + sym->nome_interno + " = 0;\n"
							+ "\tfoca_discard_line();\n"
							+ Lok + ":\n";
					}
					else if (sym->tipo == "char")
					{
						string tscan = gentempcode("int");
						string tok = gentempcode("boolean");
						string Lok = genlabel();
						string Lend = genlabel();
						$$.traducao = "\t" + tscan + " = scanf(\" %c\", &" + sym->nome_interno + ");\n"
							+ "\t" + tok + " = (" + tscan + " == 1);\n"
							+ "\tif (" + tok + ") goto " + Lok + ";\n"
							+ "\t" + sym->nome_interno + " = 0;\n"
							+ "\tfoca_discard_line();\n"
							+ "\tgoto " + Lend + ";\n"
							+ Lok + ":\n"
							+ "\tfoca_discard_line();\n"
							+ Lend + ":\n";
					}
					else
					{
						/* int/boolean */
						string tscan = gentempcode("int");
						string tok = gentempcode("boolean");
						string Lok = genlabel();
						$$.traducao = "\t" + tscan + " = scanf(\"%d\", &" + sym->nome_interno + ");\n"
							+ "\t" + tok + " = (" + tscan + " == 1);\n"
							+ "\tif (" + tok + ") goto " + Lok + ";\n"
							+ "\t" + sym->nome_interno + " = 0;\n"
							+ "\tfoca_discard_line();\n"
							+ Lok + ":\n";
					}
				}
			}
			| E ';'
			{
				$$.traducao = $1.traducao;
			}
			;

CALL_ARG	: E
			{
				$$ = $1;
				$$.extra = "";
			}
			| TK_ID ':' E
			{
				$$ = $3;
				$$.extra = $1.label;
			}
			;

CALL_ARGS	: CALL_ARG
			{
				$$.traducao = $1.traducao;
				$$.label = append_call_arg("", $1.extra, $1.tipo, $1.label);
			}
			| CALL_ARGS ',' CALL_ARG
			{
				$$.traducao = $1.traducao + $3.traducao;
				$$.label = append_call_arg($1.label, $3.extra, $3.tipo, $3.label);
			}
			;

CALL_ARGS_OPT : CALL_ARGS
			{
				$$ = $1;
			}
			| /* vazio */
			{
				$$.traducao = "";
				$$.label = "";
			}
			;

SWITCH_CLAUSES	: TK_CASE E ':' COMANDO SWITCH_CLAUSES // trata as clausulas
			{
				const switch_context& context = current_switch();
				if ($2.tipo != context.expr_tipo) // clausula precisa ter o mesmo tipo da exp do switch
					yyerror("Case incompatível com a expressão do switch");
				string Lcase = genlabel();
				string next_label;
				if ($5.label.empty())
					next_label = context.break_label; // se nao houver prox case, ele vai pro break (finaliza)
				else
					next_label = $5.label; // se houver prox case, ele vai pra ele (recursivamente)
				$$.label = Lcase;
				$$.traducao = Lcase + ":\n"
					+ $2.traducao
					+ "\tif (" + context.switch_label + " != " + $2.label + ") goto " + next_label + ";\n"
					+ $4.traducao
					+ $5.traducao;
			}
			| TK_DEFAULT ':' COMANDO
			{
				const switch_context& context = current_switch();
				string Ldefault = genlabel();
				$$.label = Ldefault;
				$$.traducao = Ldefault + ":\n"
					+ $3.traducao;
			}
			| /* vazio */ // usa quando nao ha outros cases ou default
			{
				$$.label = "";
				$$.traducao = "";
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
				$$.label = append_print_arg("", $1.tipo, $1.label);
			}
			| ARGS ',' E
			{
				$$.traducao = $1.traducao + $3.traducao;
				$$.label = append_print_arg($1.label, $3.tipo, $3.label);
			}
			;

FOR_INIT	: E
			{
				$$ = $1;
			}
		| TIPO TK_ID '=' E
		{
			auto &cur = escopo_atual();
			if (cur.find($2.label) != cur.end())
			{ yyerror("Vari�vel '" + $2.label + "' redeclarada"); }
			else
			{ cur.emplace($2.label, simbolo($2.label, $1.tipo, "", false)); }
			
			simbolo* sym = buscar_simbolo($2.label);
			if (!sym)
			{
				$$.label = "";
				$$.traducao = $4.traducao;
				$$.tipo = $4.tipo;
			}
			else
			{
				atribuir_temporario($2.label);
				string tipo_var = sym->tipo;
				string tipo_expr = $4.tipo;
				string label_expr = $4.label;
				string codigo_expr = $4.traducao;
				
				if (tipo_var == "float" && tipo_expr == "int")
				{
					string tmp = gentempcode("float");
					codigo_expr += "\t" + tmp + " = (float) " + label_expr + ";\n";
					label_expr = tmp;
					tipo_expr = "float";
				}
				else if (tipo_var == "int" && tipo_expr == "float")
				{
					yyerror("Conversão explícita necessária para atribuir float em int");
				}
				else if (tipo_var != tipo_expr)
				{
					yyerror("Tipos incompatíveis na inicialização do for");
				}
				
				sym->inicializado = true;
				$$.label = sym->nome_interno;
				$$.tipo = tipo_var;
				$$.traducao = codigo_expr + "\t" + $$.label + " = " + label_expr + ";\n";
			}
		}
		| TIPO TK_ID
		{
			auto &cur = escopo_atual();
			if (cur.find($2.label) != cur.end())
			{ yyerror("Vari�vel '" + $2.label + "' redeclarada"); }
			else
			{ cur.emplace($2.label, simbolo($2.label, $1.tipo, "", false)); }
			$$.traducao = "";
			$$.label = "";
			$$.tipo = "int";
		}
FOR_COND	: E
			{
				$$ = $1;
			}
			| /* vazio */
			{
				$$.traducao = "";
				$$.label = "";
				$$.tipo = "boolean"; // empty cond -> treated as true
			}

FOR_POST	: E
			{
				$$ = $1;
			}
			| /* vazio */
			{
				$$.traducao = "";
				$$.label = "";
				$$.tipo = "int";
			}


WHILE_HEAD	: TK_WHILE '(' E ')'
		{
			if ($3.tipo != "boolean")
				yyerror("Condição do while deve ser booleana");
			string Lbegin = genlabel();
			string Lend = genlabel();
			enter_loop(Lend, Lbegin);
			$$.label = Lbegin;
			$$.traducao = $3.traducao;
			$$.tipo = Lend;
			$$.extra = $3.label; // condição do while (usada para o if dentro do bloco)
		}

DO_HEAD	: TK_DO
		{
			string Lbegin = genlabel();
			string Lcont = genlabel();
			string Lend = genlabel();
			enter_loop(Lend, Lcont);
			$$.label = Lbegin;
			$$.tipo = Lcont;
			$$.extra = Lend;
			$$.traducao = "";
		}

FOR_HEAD	: TK_FOR '(' FOR_INIT ';' FOR_COND ';' FOR_POST ')'
		{
			string Lbegin = genlabel();
			string Lpost = genlabel();
			string Lend = genlabel();
			enter_loop(Lend, Lpost);
			$$.label = Lbegin;
			$$.tipo = Lpost;
			$$.extra = Lend;
			$$.extra2 = $7.traducao;
			$$.traducao = $3.traducao + Lbegin + ":\n";
			if (!$5.label.empty())
				$$.traducao += $5.traducao + "\tif (!" + $5.label + ") goto " + Lend + ";\n";
			else
				$$.traducao += $5.traducao;
		}

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
			| E '^' E
			{
				$$ = gerar_op_potencia($1, $3);
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
			| '+' E %prec UPLUS
			{
				$$ = gerar_unario_aritmetico("+", $2);
			}
			| '-' E %prec UMINUS
			{
				$$ = gerar_unario_aritmetico("-", $2);
			}
			| TK_NOT E
			{
				if ($2.tipo != "boolean")
					yyerror("Operador lógico '!' exige boolean");
				$$.tipo = "boolean";
				$$.label = gentempcode("boolean");
				$$.traducao = $2.traducao + "\t" + $$.label + " = !" + $2.label + ";\n";
			}
			| TK_INC TK_ID %prec PREINC
			{
				$$ = gerar_inc_dec($2.label, true, true);
			}
			| TK_DEC TK_ID %prec PREDEC
			{
				$$ = gerar_inc_dec($2.label, false, true);
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
				$$.traducao = $3.traducao + "\t" + $$.label +
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
				$$ = gerar_atribuicao($1.label, $3);
			}
			| TK_ID '(' CALL_ARGS_OPT ')'
			{
				$$ = gerar_chamada_funcao($1.label, $3);
			}
			| TK_ID TK_ADD_ASSIGN E
			{
				$$ = gerar_atribuicao_composta($1.label, "+", $3);
			}
			| TK_ID TK_SUB_ASSIGN E
			{
				$$ = gerar_atribuicao_composta($1.label, "-", $3);
			}
			| TK_ID TK_MUL_ASSIGN E
			{
				$$ = gerar_atribuicao_composta($1.label, "*", $3);
			}
			| TK_ID TK_DIV_ASSIGN E
			{
				$$ = gerar_atribuicao_composta($1.label, "/", $3);
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
			| TK_ID TK_INC %prec POSTINC
			{
				$$ = gerar_inc_dec($1.label, true, false);
			}
			| TK_ID TK_DEC %prec POSTDEC
			{
				$$ = gerar_inc_dec($1.label, false, false);
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

bool is_tipo_unario_aritmetico(const string& tipo)
{
	return tipo == "int" || tipo == "float";
}

string literal_um_para_tipo(const string& tipo)
{
	if (tipo == "float")
		return "1.0";
	return "1";
}

atributos gerar_unario_aritmetico(const char* op, const atributos& expr)
{
	atributos out;
	if (!is_tipo_unario_aritmetico(expr.tipo))
	{
		yyerror("Operador unário aritmético exige operando int ou float");
		out.tipo = expr.tipo;
		out.label = expr.label;
		out.traducao = expr.traducao;
		return out;
	}

	if (string(op) == "+")
		return expr;

	out.tipo = expr.tipo;
	out.label = gentempcode(expr.tipo);
	out.traducao = expr.traducao + "\t" + out.label + " = -" + expr.label + ";\n";
	return out;
}

atributos gerar_inc_dec(const string& nome, bool incrementar, bool prefixo)
{
	atributos out;
	simbolo* sym = buscar_simbolo(nome);
	if (!sym)
	{
		yyerror("Variável '" + nome + "' não declarada");
		out.tipo = "int";
		out.label = "";
		out.traducao = "";
		return out;
	}

	if (!is_tipo_unario_aritmetico(sym->tipo))
	{
		yyerror("Operadores '++' e '--' exigem variável int ou float");
		atribuir_temporario(nome);
		out.tipo = sym->tipo;
		out.label = sym->nome_interno;
		out.traducao = "";
		return out;
	}

	if (!sym->inicializado)
		yyerror("Variável '" + nome + "' usada antes de inicialização");

	atribuir_temporario(nome);
	sym->inicializado = true;
	string destino = sym->nome_interno;
	string op = incrementar ? "+" : "-";
	string um = literal_um_para_tipo(sym->tipo);

	out.tipo = sym->tipo;
	if (prefixo)
	{
		out.label = destino;
		out.traducao = "\t" + destino + " = " + destino + " " + op + " " + um + ";\n";
	}
	else
	{
		out.label = gentempcode(sym->tipo);
		out.traducao = "\t" + out.label + " = " + destino + ";\n"
			+ "\t" + destino + " = " + destino + " " + op + " " + um + ";\n";
	}
	return out;
}

atributos gerar_atribuicao(const string& nome, const atributos& expr)
{
	atributos out;
	is_declarado(nome);
	simbolo* sym = buscar_simbolo(nome);
	if (!sym)
	{
		out.label = "";
		out.traducao = expr.traducao;
		out.tipo = expr.tipo;
		return out;
	}

	atribuir_temporario(nome);
	string tipo_expressao_esquerda = sym->tipo;
	string tipo_expressao_direita = expr.tipo;
	string label_expressao_direita = expr.label;
	string codigo_expressao_direita = expr.traducao;

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
	out.label = sym->nome_interno;
	out.tipo = tipo_expressao_esquerda;
	if (is_string(tipo_expressao_esquerda))
		out.traducao = codigo_expressao_direita + "\tfoca_str_copy(&" + out.label + ", &" + label_expressao_direita + ");\n";
	else
		out.traducao = codigo_expressao_direita + "\t" + out.label + " = " + label_expressao_direita + ";\n";
	return out;
}

atributos gerar_atribuicao_composta(const string& nome, const char* op, const atributos& expr)
{
	is_declarado(nome);
	simbolo* sym = buscar_simbolo(nome);
	if (!sym)
	{
		atributos out;
		out.label = "";
		out.traducao = expr.traducao;
		out.tipo = expr.tipo;
		return out;
	}

	atribuir_temporario(nome);
	atributos esquerda;
	esquerda.tipo = sym->tipo;
	if (sym->tipo == "float")
	{
		esquerda.label = gentempcode("float");
		esquerda.traducao = "\t" + esquerda.label + " = " + sym->nome_interno + ";\n";
	}
	else
	{
		esquerda.label = sym->nome_interno;
		esquerda.traducao = "";
	}

	atributos combinada;
	if (string(op) == "+")
		combinada = gerar_op_soma(esquerda, expr);
	else
		combinada = gerar_op_aritmetica(esquerda, op, expr);

	return gerar_atribuicao(nome, combinada);
}

string append_print_arg(const string& atual, const string& tipo, const string& label)
{
	const char sep = '\x1f';
	string out = atual;
	if (!out.empty())
		out += sep;
	out += tipo;
	out += sep;
	out += label;
	return out;
}

string append_param_decl(const string& atual, const string& tipo, const string& nome)
{
	const char sep = '\x1f';
	string out = atual;
	if (!out.empty())
		out += sep;
	out += tipo;
	out += sep;
	out += nome;
	return out;
}

vector<parametro_funcao> parse_parametros_funcao(const string& serializado)
{
	vector<parametro_funcao> parametros;
	if (serializado.empty())
		return parametros;

	vector<string> partes;
	string atual;
	const char sep = '\x1f';
	for (char ch : serializado)
	{
		if (ch == sep)
		{
			partes.push_back(atual);
			atual.clear();
		}
		else
		{
			atual += ch;
		}
	}
	partes.push_back(atual);

	for (size_t i = 0; i + 1 < partes.size(); i += 2)
	{
		parametro_funcao param;
		param.tipo = partes[i];
		param.nome = partes[i + 1];
		parametros.push_back(param);
	}
	return parametros;
}

void registrar_funcao(const string& nome, const string& tipo_retorno, const string& params_serializados)
{
	if (funcoes.find(nome) != funcoes.end())
	{
		yyerror("Função '" + nome + "' redeclarada");
		return;
	}

	funcao_info info;
	info.nome = nome;
	info.tipo_retorno = tipo_retorno;
	info.parametros = parse_parametros_funcao(params_serializados);

	map<string, bool> nomes_parametros;
	for (size_t i = 0; i < info.parametros.size(); ++i)
	{
		parametro_funcao &param = info.parametros[i];
		if (nomes_parametros[param.nome])
			yyerror("Parâmetro '" + param.nome + "' redeclarado na função '" + nome + "'");
		nomes_parametros[param.nome] = true;
		param.nome_c = "p_" + nome + "_" + param.nome;
		param.nome_interno = param.nome_c;
	}

	funcoes[nome] = info;
}

void iniciar_funcao(const string& nome)
{
	auto it = funcoes.find(nome);
	if (it == funcoes.end())
		return;
	funcao_atual = &it->second;
	funcao_atual->temp_inicio = var_temp_qnt;
	funcao_atual->nome_retorno = gentempcode(funcao_atual->tipo_retorno);
	funcao_atual->label_retorno = genlabel();
	for (size_t i = 0; i < funcao_atual->parametros.size(); ++i)
	{
		parametro_funcao &param = funcao_atual->parametros[i];
		if (param.tipo == "string")
			param.nome_interno = gentempcode("string");
	}
}

string preparar_parametros_funcao()
{
	if (!funcao_atual)
		return "";

	string codigo;
	for (size_t i = 0; i < funcao_atual->parametros.size(); ++i)
	{
		const parametro_funcao &param = funcao_atual->parametros[i];
		auto &cur = escopo_atual();
		cur.emplace(param.nome, simbolo(param.nome, param.tipo, param.nome_interno, true));
		if (param.tipo == "string")
		{
			usa_string = true;
			codigo += "\tfoca_str_copy(&" + param.nome_interno + ", &" + param.nome_c + ");\n";
		}
	}

	string literal = literal_padrao_tipo(funcao_atual->tipo_retorno);
	if (!literal.empty())
		codigo += "\t" + funcao_atual->nome_retorno + " = " + literal + ";\n";
	return codigo;
}

string finalizar_funcao(const string& traducao_corpo)
{
	if (!funcao_atual)
		return "";

	funcao_atual->temp_fim = var_temp_qnt;
	string assinatura = tipo_para_c(funcao_atual->tipo_retorno) + " " + funcao_atual->nome + "(";
	for (size_t i = 0; i < funcao_atual->parametros.size(); ++i)
	{
		if (i != 0)
			assinatura += ", ";
		assinatura += tipo_para_c(funcao_atual->parametros[i].tipo) + " " + funcao_atual->parametros[i].nome_c;
	}
	assinatura += ") {\n";

	string codigo = assinatura;
	codigo += gen_temp_declarations_range(funcao_atual->temp_inicio, funcao_atual->temp_fim);
	codigo += traducao_corpo;
	codigo += funcao_atual->label_retorno + ":\n";
	codigo += "\treturn " + funcao_atual->nome_retorno + ";\n";
	codigo += "}\n\n";
	return codigo;
}

void encerrar_funcao()
{
	funcao_atual = nullptr;
}

string append_call_arg(const string& atual, const string& nome, const string& tipo, const string& label)
{
	const char field_sep = '\x1f';
	const char item_sep = '\x1e';
	string out = atual;
	if (!out.empty())
		out += item_sep;
	out += nome;
	out += field_sep;
	out += tipo;
	out += field_sep;
	out += label;
	return out;
}

string literal_padrao_tipo(const string& tipo)
{
	if (tipo == "float") return "0.0";
	if (tipo == "string") return "";
	return "0";
}

atributos gerar_chamada_funcao(const string& nome, const atributos& argumentos)
{
	atributos out;
	auto it = funcoes.find(nome);
	if (it == funcoes.end())
	{
		yyerror("Função '" + nome + "' não declarada");
		out.traducao = argumentos.traducao;
		out.tipo = "int";
		out.label = "";
		return out;
	}

	const funcao_info &funcao = it->second;
	vector<string> itens;
	string atual;
	const char item_sep = '\x1e';
	for (char ch : argumentos.label)
	{
		if (ch == item_sep)
		{
			itens.push_back(atual);
			atual.clear();
		}
		else
		{
			atual += ch;
		}
	}
	if (!atual.empty())
		itens.push_back(atual);

	vector<string> labels_ordenados(funcao.parametros.size());
	vector<bool> preenchido(funcao.parametros.size(), false);
	string codigo = argumentos.traducao;
	bool usou_nomeado = false;
	size_t proximo_posicional = 0;

	for (size_t i = 0; i < itens.size(); ++i)
	{
		vector<string> campos;
		string campo_atual;
		const char field_sep = '\x1f';
		for (char ch : itens[i])
		{
			if (ch == field_sep)
			{
				campos.push_back(campo_atual);
				campo_atual.clear();
			}
			else
			{
				campo_atual += ch;
			}
		}
		campos.push_back(campo_atual);
		if (campos.size() != 3)
			continue;

		string nome_arg = campos[0];
		string tipo_arg = campos[1];
		string label_arg = campos[2];
		int indice_param = -1;

		if (!nome_arg.empty())
		{
			usou_nomeado = true;
			for (size_t j = 0; j < funcao.parametros.size(); ++j)
			{
				if (funcao.parametros[j].nome == nome_arg)
				{
					indice_param = (int)j;
					break;
				}
			}
			if (indice_param < 0)
			{
				yyerror("Parâmetro nomeado '" + nome_arg + "' inexistente na função '" + nome + "'");
				continue;
			}
		}
		else
		{
			if (usou_nomeado)
				 yyerror("Argumentos posicionais devem vir antes dos nomeados na função '" + nome + "'");
			while (proximo_posicional < funcao.parametros.size() && preenchido[proximo_posicional])
				++proximo_posicional;
			if (proximo_posicional >= funcao.parametros.size())
			{
				yyerror("Quantidade de argumentos excede a função '" + nome + "'");
				continue;
			}
			indice_param = (int)proximo_posicional++;
		}

		if (preenchido[(size_t)indice_param])
		{
			yyerror("Parâmetro '" + funcao.parametros[(size_t)indice_param].nome + "' informado mais de uma vez na função '" + nome + "'");
			continue;
		}

		string tipo_param = funcao.parametros[(size_t)indice_param].tipo;
		if (is_string(tipo_param) || is_string(tipo_arg))
		{
			usa_string = true;
			if (!is_string(tipo_param) || !is_string(tipo_arg))
				yyerror("Tipos incompatíveis no argumento '" + funcao.parametros[(size_t)indice_param].nome + "' da função '" + nome + "'");
		}
		else if (tipo_param == "float" && tipo_arg == "int")
		{
			string tmp = gentempcode("float");
			codigo += "\t" + tmp + " = (float) " + label_arg + ";\n";
			label_arg = tmp;
		}
		else if (tipo_param == "int" && tipo_arg == "float")
		{
			yyerror("Conversão explícita necessária no argumento '" + funcao.parametros[(size_t)indice_param].nome + "' da função '" + nome + "'");
		}
		else if (tipo_param != tipo_arg)
		{
			yyerror("Tipos incompatíveis no argumento '" + funcao.parametros[(size_t)indice_param].nome + "' da função '" + nome + "'");
		}

		labels_ordenados[(size_t)indice_param] = label_arg;
		preenchido[(size_t)indice_param] = true;
	}

	for (size_t i = 0; i < preenchido.size(); ++i)
	{
		if (!preenchido[i])
			yyerror("Argumento ausente para o parâmetro '" + funcao.parametros[i].nome + "' da função '" + nome + "'");
	}

	string chamada;
	for (size_t i = 0; i < labels_ordenados.size(); ++i)
	{
		if (i != 0)
			chamada += ", ";
		chamada += labels_ordenados[i];
	}

	out.tipo = funcao.tipo_retorno;
	out.label = gentempcode(funcao.tipo_retorno);
	out.traducao = codigo + "\t" + out.label + " = " + nome + "(" + chamada + ");\n";
	return out;
}

vector<string> split_print_args(const string& serializado)
{
	vector<string> partes;
	string atual;
	const char sep = '\x1f';
	for (char ch : serializado)
	{
		if (ch == sep)
		{
			partes.push_back(atual);
			atual.clear();
		}
		else
		{
			atual += ch;
		}
	}
	partes.push_back(atual);
	return partes;
}

string formatador_por_tipo(const string& tipo)
{
	if (tipo == "float") return "%f";
	if (tipo == "char") return "%c";
	if (tipo == "string") return "%s";
	return "%d";
}

string gerar_print_simples(const atributos& expr)
{
	string codigo = expr.traducao;
	string formato = formatador_por_tipo(expr.tipo);
	string valor = expr.label;
	if (is_string(expr.tipo))
	{
		usa_string = true;
		valor = "foca_str_cstr(&" + expr.label + ")";
	}
	codigo += "\tprintf(\"" + formato + "\", " + valor + ");\n";
	return codigo;
}

string gerar_print_template(const string& literal, const atributos& args)
{
	vector<string> partes = split_print_args(args.label);
	vector<string> tipos;
	vector<string> labels;
	for (size_t i = 0; i + 1 < partes.size(); i += 2)
	{
		tipos.push_back(partes[i]);
		labels.push_back(partes[i + 1]);
	}

	string codigo = args.traducao;
	string trecho = "\"";
	size_t indice_arg = 0;

	for (size_t i = 1; i + 1 < literal.size(); ++i)
	{
		char ch = literal[i];
		if (ch == '\\' && i + 1 < literal.size() - 1)
		{
			trecho += ch;
			trecho += literal[++i];
			continue;
		}

		if (ch == '%')
		{
			if (i + 1 >= literal.size() - 1)
			{
				yyerror("Template de print termina com '%' inválido");
				break;
			}

			char spec = literal[++i];
			if (spec == '%')
			{
				trecho += '%';
				continue;
			}

			if (indice_arg >= labels.size())
			{
				yyerror("Quantidade de argumentos insuficiente para o template de print");
				break;
			}

			if (trecho != "\"")
			{
				trecho += "\"";
				codigo += "\tprintf(" + trecho + ");\n";
				trecho = "\"";
			}

			string tipo = tipos[indice_arg];
			string esperado;
			switch (spec)
			{
				case 'd': esperado = "int"; break;
				case 'f': esperado = "float"; break;
				case 'c': esperado = "char"; break;
				case 's': esperado = "string"; break;
				default:
					yyerror(string("Placeholder de print não suportado: %") + spec);
					esperado.clear();
			}

			if (!esperado.empty())
			{
				bool compativel = (tipo == esperado)
					|| (spec == 'd' && tipo == "boolean");
				if (!compativel)
				{
					yyerror("Tipo incompatível no template de print: esperado " + esperado + ", recebeu " + tipo);
				}
				string valor = labels[indice_arg];
				if (tipo == "string")
				{
					usa_string = true;
					valor = "foca_str_cstr(&" + valor + ")";
				}
				codigo += "\tprintf(\"%" + string(1, spec) + "\", " + valor + ");\n";
			}
			++indice_arg;
			continue;
		}

		if (ch == '"' || ch == '\\')
			trecho += '\\';
		trecho += ch;
	}

	if (indice_arg < labels.size())
		yyerror("Quantidade de argumentos excede os placeholders do template de print");

	if (trecho != "\"")
	{
		trecho += "\"";
		codigo += "\tprintf(" + trecho + ");\n";
	}

	return codigo;
}

bool is_switch_tipo_valido(const string& tipo)
{
	return tipo == "int" || tipo == "char" || tipo == "boolean";
}

void enter_switch(const atributos& expr) // Adiciona um novo contexto de switch à pilha
{
    switch_context context;
	context.switch_label = expr.label; // resultado da expressão do switch
	context.expr_tipo = expr.tipo;         // tipo da expressão
    context.break_label = genlabel();        // destino dos breaks

    switch_stack.push_back(context);
}


void exit_switch() // Remove o switch atual da pilha
{
    if (!switch_stack.empty())
        switch_stack.pop_back();
}


const switch_context& current_switch() // Retorna o contexto do switch atual/ switch que está no topo da pilha
{
    return switch_stack.back();
}

void enter_loop(const string& break_label, const string& continue_label)
{
	loop_context ctx;
	ctx.break_label = break_label;
	ctx.continue_label = continue_label;
	loop_stack.push_back(ctx);
}

void exit_loop()
{
	if (!loop_stack.empty())
		loop_stack.pop_back();
}

const loop_context& current_loop()
{
	return loop_stack.back();
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

atributos gerar_op_potencia(const atributos& expressao_esquerda, const atributos& expressao_direita)
{
	atributos out;
	if (is_string(expressao_esquerda.tipo) || is_string(expressao_direita.tipo))
	{
		yyerror("Operação de exponenciação inválida com string");
		out.tipo = "int";
		out.label = "";
		out.traducao = expressao_esquerda.traducao + expressao_direita.traducao;
		return out;
	}

	if (expressao_direita.tipo == "float") // so aceita expoentes inteiros
	{
		yyerror("Expoente de potência deve ser inteiro");
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
		ensure_float_temp_for_literal(label_expressao_esquerda, codigo_expressao_esquerda, expressao_esquerda);
	}

	out.tipo = tipo_res;
	out.label = gentempcode(tipo_res);
	out.traducao = codigo_expressao_esquerda + codigo_expressao_direita + "\t" + out.label +
		" = (" + tipo_para_c(tipo_res) + ") pot(" + label_expressao_esquerda + ", (int)(" + label_expressao_direita + "));\n";
	return out;
}

string gen_potencia_runtime_support()
{
	return
		"double pot(double base, int exp) {\n"
		"\tdouble resultado = 1.0;\n" // inicia com 0
		"\tint n;\n\n"
		"\tif (exp < 0) {\n" // pega módulo do expoente (em caso de negativo)
		"\t\tn = -exp;\n"
		"\t} else {\n"
		"\t\tn = exp;\n"
		"\t}\n\n"
		"\twhile (n > 0) {\n"
		"\t\tresultado *= base;\n" // multiplica a base por ela mesma 
		"\t\tn--;\n"
		"\t}\n\n"
		"\tif (exp < 0) {\n"
		"\t\treturn 1.0 / resultado;\n" // inverso do resultado se o expoente for negativo
		"\t}\n\n"
		"\treturn resultado;\n"
		"}\n\n";
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

string gen_temp_declarations_range(int inicio_exclusivo, int fim_inclusivo)
{
	string declarations;
	string init_code;
	for (int i = inicio_exclusivo + 1; i <= fim_inclusivo; i++){
		string temp = "t" + to_string(i);
		string tipo = tipos_temp[temp];
		if (tipo.empty()) tipo = "int";
		declarations += "\t" + tipo_para_c(tipo) + " " + temp + ";\n";
		if (tipo == "string")
			init_code += "\tfoca_str_init(&" + temp + ");\n";
	}
	if (fim_inclusivo > inicio_exclusivo)
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
	);
}

string gen_io_runtime_support()
{
	return string(
		"static void foca_discard_line(void) {\n"
		"\tint ch;\n"
		"\tint t1;\n"
		"L_discard_get:\n"
		"\tch = getchar();\n"
		"\tt1 = (ch == EOF);\n"
		"\tif (t1) goto L_discard_end;\n"
		"\tt1 = (ch == '\\n');\n"
		"\tif (t1) goto L_discard_end;\n"
		"\tt1 = (ch == '\\r');\n"
		"\tif (t1) goto L_discard_end;\n"
		"\tgoto L_discard_get;\n"
		"L_discard_end:\n"
		"\treturn;\n"
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
	funcoes.clear();
	funcao_atual = nullptr;
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

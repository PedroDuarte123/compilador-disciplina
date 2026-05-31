# Strings no FOCA — especificação e implementação

Este documento descreve **o que foi adicionado à linguagem FOCA** para suportar strings e **como isso é traduzido** para o código intermediário em C.

A implementação foi feita para:

- Não depender de `strlen`.
- Evitar concatenação ingênua com custo $O(n^2)$.
- Ser modular: a linguagem trata `string` como tipo, e o código intermediário usa um “runtime” pequeno (`foca_string`) com funções auxiliares.

---

## 1) O que a linguagem suporta

### 1.1 Tipo

- Tipo novo: `string`

Exemplo:

```foca
string A;
string B;
```

### 1.2 Literais

- Literal de string entre aspas duplas: `"..."`
- Permite escapes no nível léxico (`\n`, `\"`, `\\`, etc.) porque o padrão aceita `\\.`.

Exemplo:

```foca
string A;
A = "ola";
```

### 1.3 Operações

- Atribuição: `A = expr_string;`
- Concatenação: `expr_string + expr_string` (o `+` é sobrecarregado)
- Comparação: `==` e `!=` entre strings (resultado é boolean)

Exemplo:

```foca
string A;
string B;
string C;

A = "ola";
B = " mundo";
C = A + B + "!";

bool R;
R = C == "ola mundo!";
```

### 1.4 Restrições (intencionais)

- Não há cast envolvendo `string`: `(int)A`, `(string)X`, etc. geram erro.
- Relacionais (`<`, `>`, `<=`, `>=`) não são suportados para `string`.
- Concatenação só é permitida entre `string` e `string`.

---

## 2) Visão geral do código intermediário em C

Strings no código intermediário são representadas por um struct:

```c
typedef struct {
    char *data;
    int len;
    int cap;
} foca_string;
```

A ideia central é:

- `len` armazena o tamanho atual (sem o `\0`).
- `cap` armazena a capacidade alocada.
- `data` aponta para o buffer NUL-terminated.

Isso permite:

- **Concatenação eficiente**: reservar memória uma vez para o tamanho final.
- **Sem `strlen`**: o tamanho é conhecido pela semântica (`len`) ou fornecido pelo compilador no caso de literais.

---

## 3) Implementação no léxico (Flex)

Arquivo: `lexico.l`

### 3.1 Token de palavra-chave

A palavra-chave `string` gera o token `TK_STRING`:

```lex
"string"    { return TK_STRING; }
```

### 3.2 Token de literal

Foi adicionada uma regra para literais entre aspas duplas:

```lex
STRLIT \"([^\\\"\n]|\\.)*\"
{STRLIT}     { yylval.label = yytext; return TK_STR_LIT; }
```

- `yylval.label` recebe o texto literal (ex.: `"ola"`).
- O parser usa esse texto diretamente na geração do código C.

---

## 4) Implementação no parser/semântica (Bison)

Arquivo: `sintatico.y`

### 4.1 Tokens

Foram adicionados:

- `TK_STRING`
- `TK_STR_LIT`

### 4.2 Tabelas e temporários

A infraestrutura existente já tem:

- `gentempcode(tipo)` para criar temporários `t1`, `t2`, ...
- `tipos_temp[temp] = tipo` para lembrar o tipo do temporário.

Para strings:

- `tipo_para_c("string")` retorna `foca_string`
- `gen_temp_declarations()` declara `foca_string tN;` e **inicializa** cada string temporária com `foca_str_init(&tN);`

Essa inicialização é essencial, porque `foca_str_reserve()` usa `realloc()` sobre `data` (que precisa iniciar como `NULL`).

### 4.3 Ativação condicional do runtime

Existe uma flag global:

- `bool usa_string = false;`

Ela é marcada como `true` quando o programa realmente usa strings (tipo `string`, literal, concatenação, comparação, etc.).

Com isso:

- Programas sem string continuam gerando exatamente o mesmo cabeçalho antigo.
- Programas com string adicionam `#include <stdlib.h>` e o runtime de string antes do `main`.

### 4.4 Concatenação com `+`

O `+` foi “separado” semanticamente:

- Se ambos operandos são numéricos → usa `gerar_op_aritmetica(..., "+", ...)`
- Se algum operando é `string` → chama `gerar_op_soma`, que redireciona para `gerar_op_concat`.

Regra prática:

- `string + string` é permitido e gera:

```c
foca_str_concat(&t_out, &t_left, &t_right);
```

- `string + int` (ou qualquer mistura) gera erro semântico.

### 4.5 Atribuição

Para tipos primitivos, a atribuição segue o padrão existente:

```c
tX = expr;
```

Para string, a atribuição vira cópia semântica:

```c
foca_str_copy(&dest, &src);
```

Isso evita aliasing acidental (dois símbolos apontando para o mesmo buffer).

### 4.6 Comparação `==` e `!=`

Para strings, só `==` e `!=` são aceitos.

Geração:

- `A == B` vira `foca_str_eq(&A, &B)`
- `A != B` vira `!foca_str_eq(&A, &B)`

---

## 5) Runtime em C (sem `strlen`)

O runtime é gerado pelo compilador como texto (funções `static`) antes do `main` quando `usa_string == true`.

### 5.1 Reserva de capacidade (crescimento amortizado)

A função `foca_str_reserve` usa estratégia de **dobrar capacidade**, garantindo custo amortizado linear ao longo de várias concatenações.

Ponto principal:

- Em vez de fazer `realloc` a cada caractere, reservamos para o tamanho final.

### 5.2 Por que não usar `strcat` ingênuo

Um erro clássico é:

- Alocar pouco a pouco e usar `strcat` repetidamente.

Isso costuma ser $O(n^2)$, porque `strcat` precisa achar o fim do destino (varrendo de novo) a cada chamada.

### 5.3 Estilo “strcpy/strcat” sem varrer destino

Para manter o estilo sugerido pelo professor (usar `strcpy`/`strcat`), mas sem cair na versão ingênua:

- Implementamos funções que **retornam o ponteiro do fim**:

```c
static char* foca_strcopy_end(char *dst, const char *src);
static char* foca_strcat_end(char *dst_end, const char *src);
```

Uso típico (na concatenação):

```c
char *end = foca_strcopy_end(dst->data, a->data);
end = foca_strcat_end(end, b->data);
```

Assim, o “fim do destino” é conhecido sem precisar fazer busca repetida.

### 5.4 Literais sem `strlen`

Para literal `"ola"`, o compilador gera:

```c
foca_str_from_lit(&t, "ola", (int)(sizeof("ola") - 1));
```

- `sizeof("ola") - 1` dá o tamanho do literal **em tempo de compilação em C**.
- Isso elimina a necessidade de `strlen`.

> Observação: o runtime ainda copia o literal varrendo até o `\0` via `foca_strcopy_end`, mas o tamanho real da string (len) vem do `lit_len` sem usar `strlen`.

---

## 6) Exemplo completo

Arquivo: `exemplos/14_string.foca`

Entrada:

```foca
string A;
string B;
string C;

A = "ola";
B = " mundo";
C = A + B + "!";

bool R;
R = C == "ola mundo!";
```

Saída esperada (gerada pelo compilador): `exemplos/14_string.expected`

---

## 7) Limitações e próximos passos

- O runtime não faz `free()` dos buffers no final do programa. Para o compilador/avaliador de disciplina isso normalmente é aceitável, mas se quiser, é possível gerar chamadas `foca_str_free(&var)` antes do `return`.
- Se futuramente você quiser permitir `string + int` (conversão implícita), isso exigiria definir regras de coerção e um `to_string` no runtime.

---

## 8) Alocação de memória (detalhe)

Esta seção explica com mais profundidade como a string é alocada e redimensionada no runtime.

### 8.1 Invariantes do tipo `foca_string`

Lembre da estrutura:

```c
typedef struct {
    char *data;
    int len;
    int cap;
} foca_string;
```

O runtime mantém estes invariantes:

- `len` é o número de caracteres válidos (não conta o `\0`).
- `data` é um buffer NUL-terminated (`data[len] == '\0'`), **quando `data != NULL`**.
- `cap` é a capacidade alocada em bytes do buffer `data`.
- Sempre que a string precisa armazenar `len` caracteres, precisamos de pelo menos `cap >= len + 1` (o `+1` é pelo terminador `\0`).

Inicialização:

```c
foca_str_init(&s);
/* s.data = NULL; s.len = 0; s.cap = 0; */
```

Isso é importante porque a estratégia de crescimento usa `realloc(s.data, ...)`, e `realloc(NULL, n)` funciona como `malloc(n)`.

### 8.2 Quando ocorre alocação/re-alocação

Toda operação que muda o conteúdo chama `foca_str_reserve` antes de copiar:

- `foca_str_from_lit`: precisa de `lit_len + 1`
- `foca_str_copy`: precisa de `src->len + 1`
- `foca_str_concat`: precisa de `(a->len + b->len) + 1`

Em cada caso o runtime calcula a necessidade e garante a capacidade:

```c
foca_str_reserve(dst, needed_cap);
```

Se `needed_cap <= cap`, **não aloca nada**.

### 8.3 Estratégia de crescimento (evitando abordagem ingênua)

Uma implementação ingênua costuma crescer 1 a 1 (ou faz `strcat` repetido), causando muitas realocações e múltiplas varreduras.

Aqui usamos crescimento geométrico:

- Se `cap == 0`, começa com um tamanho base (ex.: 64).
- Enquanto `new_cap < needed_cap`, faz `new_cap *= 2`.

Vantagens:

- O número de `realloc` ao longo de várias concatenações cresce como $O(\log n)$.
- O custo total de cópia é **amortizado linear**: ao construir uma string de tamanho final $n$, o custo total tende a $O(n)$.

### 8.4 Por que `len` elimina `strlen`

Sem `len`, para concatenar você teria que descobrir `|a|` e `|b|` chamando `strlen(a)` e `strlen(b)` (varrendo buffers toda hora).

Com `len`:

- O tamanho de cada string já está disponível em O(1).
- O runtime já sabe exatamente quanto reservar: `a->len + b->len + 1`.

No caso de literais, o compilador calcula o tamanho com `sizeof("...") - 1`, também em O(1), sem `strlen`.

### 8.5 Copiando dados: linear e com terminador

Após reservar memória suficiente, o runtime copia bytes para `data`.

O ponto essencial é sempre garantir:

- escrever os caracteres
- escrever o `\0` no final
- atualizar `len`

Isso mantém a string compatível com funções de C que esperam NUL-termination (mesmo sem usar `strlen`).

### 8.6 Observação sobre liberação (leak vs. simplicidade)

Hoje o runtime não gera um `free` ao final do programa.

Na prática, ao terminar o processo, o sistema operacional recupera toda a memória, então isso não costuma ser um problema para testes de compilador.

Se quiser deixar “certinho”, uma extensão natural é:

- adicionar `static void foca_str_free(foca_string *s) { free(s->data); foca_str_init(s); }`
- e o compilador emitir `foca_str_free(&tN);` para todas as temporárias/variáveis string antes do `return 0;`.

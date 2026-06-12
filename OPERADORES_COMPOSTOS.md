# Operadores Compostos

Este documento descreve a implementação dos operadores compostos básicos no compilador FOCA.

## Operadores suportados

Foram adicionados os seguintes operadores:

- `+=`
- `-=`
- `*=`
- `/=`

Esses operadores funcionam sobre variáveis já declaradas e seguem a mesma regra de tipos da atribuição simples.

## Exemplo na linguagem FOCA

```foca
int a;
float b;

a = 10;
a += 5;
a -= 3;
a *= 2;
a /= 4;

b = 1.5;
b += 2;
b *= 2.0;
```

O exemplo completo usado como regressão está em `exemplos/29_operadores_compostos.foca`.

## Como a implementação foi feita

### 1. Análise léxica

No arquivo `lexico.l`, o scanner passou a reconhecer os novos tokens:

- `TK_ADD_ASSIGN` para `+=`
- `TK_SUB_ASSIGN` para `-=`
- `TK_MUL_ASSIGN` para `*=`
- `TK_DIV_ASSIGN` para `/=`

Esses tokens são retornados antes dos operadores simples, o que evita que `+=` seja lido como `+` seguido de `=`.

### 2. Análise sintática

No arquivo `sintatico.y`, os novos tokens foram declarados e receberam a mesma associatividade da atribuição simples:

```bison
%right '=' TK_ADD_ASSIGN TK_SUB_ASSIGN TK_MUL_ASSIGN TK_DIV_ASSIGN
```

As produções adicionadas em `E` seguem este formato:

```bison
| TK_ID TK_ADD_ASSIGN E
| TK_ID TK_SUB_ASSIGN E
| TK_ID TK_MUL_ASSIGN E
| TK_ID TK_DIV_ASSIGN E
```

Cada uma delas delega a geração de código para um helper específico.

### 3. Reuso da lógica de atribuição

Para evitar duplicação, a atribuição simples foi extraída para o helper:

- `gerar_atribuicao(const string& nome, const atributos& expr)`

Esse helper concentra:

- verificação de declaração da variável
- alocação do temporário interno
- coerção implícita de `int` para `float`
- erro em atribuição de `float` para `int` sem cast explícito
- validação de tipos incompatíveis
- cópia especial para `string`

Com isso, os operadores compostos puderam reaproveitar exatamente as mesmas regras sem manter código duplicado.

### 4. Geração da atribuição composta

Foi criado o helper:

- `gerar_atribuicao_composta(const string& nome, const char* op, const atributos& expr)`

O fluxo dele é:

1. Buscar a variável de destino.
2. Materializar o valor atual da variável como operando esquerdo.
3. Gerar a operação aritmética correspondente.
4. Reaproveitar `gerar_atribuicao` para gravar o resultado final.

Na prática, uma instrução como:

```foca
a += 5;
```

é traduzida conceitualmente para:

```foca
a = a + 5;
```

mas preservando a infraestrutura de geração de temporários e as checagens semânticas já existentes no compilador.

## Regras de tipo

As mesmas regras da atribuição simples são aplicadas:

- `int += int` funciona
- `float += int` funciona com promoção implícita para `float`
- `int += float` gera erro, exigindo conversão explícita
- operações compostas com `string` não são suportadas

Os operadores compostos reutilizam a lógica de operações aritméticas já existente, então continuam respeitando as restrições dos tipos numéricos aceitos pelo compilador.

## Arquivos alterados

- `lexico.l`
- `sintatico.y`
- `exemplos/29_operadores_compostos.foca`
- `exemplos/29_operadores_compostos.expected`

## Validação

A validação foi feita em duas etapas:

1. recompilação do compilador com `make clean && make glf`
2. execução manual de um programa com `+=`, `-=`, `*=`, `/=` para conferir o C gerado

Também foi adicionado um exemplo de regressão em `exemplos/29_operadores_compostos.*`.
# Entrada e Saída no FOCA (scan / print)

Este documento descreve como foram implementados os comandos de **entrada** e **saída** na linguagem FOCA, gerando código intermediário em C usando `scanf` e `printf`.

## 1) Sintaxe adicionada

### 1.1) Entrada (scan)

Leitura para dentro de uma variável já declarada:

```foca
scan ID;
```

Exemplo:

```foca
int a;
scan a;
```

### 1.2) Saída (print)

Saída estilo `printf`, com string literal de formato e lista opcional de expressões:

```foca
print("...format...");
print("...format...", E1, E2, ...);
```

Exemplo:

```foca
print("a=%d\n", a);
print("x=%d y=%f s=%s\n", x, y, s);
```

Observação: o FOCA **não valida** se o formato (`%d`, `%f`, `%c`, `%s`, etc.) combina com os tipos; o formato é responsabilidade do programador, como em C.

---

## 2) Alterações no léxico (Flex)

Arquivo: `lexico.l`

Foram adicionadas duas palavras-chave:

- `print` → token `TK_PRINT`
- `scan` → token `TK_SCAN`

Além disso, foi adicionado o token do caractere `,` (vírgula), necessário para separar argumentos do `print("fmt", a, b, c)`.

---

## 3) Alterações no sintático (Bison)

Arquivo: `sintatico.y`

### 3.1) Novo comando `print`

O `print` foi implementado como **comando** (não é expressão). Existem duas formas:

- `print("fmt");`
- `print("fmt", ARGS);`

A geração de código é direta:

- Sem argumentos:
  - gera `printf("fmt");`
- Com argumentos:
  - primeiro gera o código das expressões (temporários, casts, concatenações etc.)
  - depois gera `printf("fmt", args...);`

Para montar os argumentos foi criado o não-terminal `ARGS`, que:

- concatena o `traducao` das expressões na ordem correta
- monta uma string com a lista `arg1, arg2, ...` para a chamada de `printf`

#### Strings em `printf`

Como as strings do FOCA são um `struct` (`foca_string`), não podemos passá-las diretamente para `printf`. Para isso, o argumento gerado para `string` é sempre um `char*`:

- se `s` é `foca_string`, usamos `(s.data ? s.data : "")`

Isso evita comportamento indefinido caso a string ainda esteja vazia/`NULL`.

### 3.2) Novo comando `scan`

O `scan` foi implementado como:

```foca
scan ID;
```

Semântica/checagens:

- exige que `ID` esteja declarado (`is_declarado`)
- garante que a variável tenha uma “célula de memória” interna (`atribuir_temporario`)
- marca a variável como inicializada (`inicializado = true`)

Geração de código (por tipo):

- `int` / `bool` → `scanf("%d", &var);`
- `float` → `scanf("%f", &var);`
- `char` → `scanf(" %c", &var);` (com espaço para ignorar whitespace pendente)
- `string` → `foca_str_scanline(&var);`

---

## 4) Suporte de runtime para ler `string` com espaços

Para `string`, foi criada uma função no runtime gerado:

- `foca_str_scanline(foca_string *s)`

Ela lê uma linha de `stdin` caractere a caractere usando `getchar()`, armazenando em um buffer dinâmico.

### 4.1) Estratégia de alocação

A função usa `foca_str_reserve`, que faz crescimento por **dobramento de capacidade**:

- começa com uma capacidade mínima (ex.: 64)
- dobra enquanto necessário

Isso dá custo amortizado linear para a leitura: $O(n)$.

### 4.2) Quebras de linha

A implementação atual ignora `\n`/`\r` iniciais antes de começar a capturar a linha. Isso ajuda quando uma leitura numérica (`scanf`) deixa um `\n` pendente no buffer.

---

## 5) Exemplo pronto

Arquivo: `exemplos/15_io.foca`

Ele demonstra:

- `scan` para `int`, `float`, `char`, `bool`, `string`
- `print` com formato e múltiplos argumentos

Para ver o C intermediário:

```bash
make translate FILE=exemplos/15_io.foca
```

Para compilar e executar o C gerado:

```bash
make run FILE=exemplos/15_io.foca
```

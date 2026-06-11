# Implementacao dos Prints no FOCA

Este documento descreve toda a implementacao atual dos comandos de impressao do compilador FOCA.

## Visao geral

O compilador agora possui dois comandos distintos de impressao:

- `print(expr);`
- `printf("template", arg1, arg2, ...);`

A separacao e sintatica e semantica:

- `print` e usado para imprimir um unico valor ja tipado.
- `printf` e usado quando existe um template com placeholders.

O objetivo principal dessa separacao e evitar que a interpolacao seja delegada para o `printf` variadico do C. O compilador passa a expandir o template durante a traducao.

## Sintaxe aceita

### Print simples

Imprime uma unica expressao:

```foca
print(a);
print(10);
print("ola\n");
print(nome);
```

Casos aceitos:

- `int`
- `float`
- `char`
- `boolean`
- `string`
- literal de string sem argumentos

### Print com template

Imprime um template com placeholders:

```foca
printf("a=%d b=%f c=%c s=%s\n", a, b, c, s);
printf("ola %s %d\n", nome, idade);
```

Placeholders suportados:

- `%d` para `int` e `boolean`
- `%f` para `float`
- `%c` para `char`
- `%s` para `string`
- `%%` para emitir o caractere `%`

## Analise lexica

No arquivo `lexico.l`, foram definidos dois tokens diferentes:

- `TK_PRINT` para a palavra reservada `print`
- `TK_PRINTF` para a palavra reservada `printf`

Isso garante que os dois comandos sejam distinguidos logo no lexer.

Trecho conceitual:

```lex
"printf"    { return TK_PRINTF; }
"print"     { return TK_PRINT; }
```

## Analise sintatica

No arquivo `sintatico.y`, a gramatica separa explicitamente os dois casos.

### Regra do print simples

Existem dois caminhos relevantes:

```bison
TK_PRINT '(' TK_STR_LIT ')' ';'
TK_PRINT '(' E ')' ';'
```

O primeiro preserva a emissao direta de literais de string sem precisar materializar uma `foca_string` temporaria.

O segundo usa qualquer expressao tipada e chama `gerar_print_simples`.

### Regra do print com template

O print com template possui uma regra propria:

```bison
TK_PRINTF '(' TK_STR_LIT ',' ARGS ')' ';'
```

Essa regra chama `gerar_print_template`, que percorre o literal e gera o codigo C correspondente.

## Representacao dos argumentos do template

Os argumentos passados para `printf` sao reconhecidos pela nao-terminal `ARGS`.

Cada argumento e serializado em `$$.label` no formato:

```text
tipo <sep> label <sep> tipo <sep> label ...
```

O separador usado e o caractere ASCII `0x1F`, armazenado nas funcoes auxiliares:

- `append_print_arg`
- `split_print_args`

Essa estrategia foi adotada para evitar criar uma estrutura de dados mais pesada dentro de `YYSTYPE`, mantendo a implementacao local e simples.

## Geracao de codigo do print simples

A funcao `gerar_print_simples(const atributos& expr)` faz o seguinte:

1. Reaproveita `expr.traducao` para garantir que a expressao seja avaliada antes da impressao.
2. Escolhe o especificador de formato com `formatador_por_tipo`.
3. Para `string`, converte a expressao para `foca_str_cstr(&temp)`.
4. Emite um unico `printf` em C.

Exemplo:

```foca
print(a);
```

Pode gerar algo conceitualmente equivalente a:

```c
printf("%d", t2);
```

## Geracao de codigo do print com template

A funcao `gerar_print_template(const string& literal, const atributos& args)` implementa a interpolacao no compilador.

### Etapas

1. Desserializa os argumentos com `split_print_args`.
2. Percorre o literal caractere por caractere, ignorando as aspas externas.
3. Acumula texto bruto em `trecho`.
4. Ao encontrar um placeholder, descarrega o texto acumulado como `printf("texto...");`.
5. Valida o tipo do argumento atual contra o placeholder.
6. Emite um `printf` especifico para aquele argumento.
7. Continua o processo ate o final do template.
8. Ao final, descarrega qualquer trecho literal restante.

### Exemplo de traducao

Entrada FOCA:

```foca
printf("ola %s %d!\n", nome, idade);
```

Saida C gerada:

```c
printf("ola ");
printf("%s", foca_str_cstr(&t_nome));
printf(" ");
printf("%d", t_idade);
printf("!\n");
```

Observe que o compilador faz a expansao do template. O C apenas executa impressoes pontuais ja determinadas.

## Checagens semanticas

A implementacao atual faz as seguintes validacoes para `printf`:

- erro se o template terminar com `%` invalido
- erro se houver menos argumentos do que placeholders
- erro se houver mais argumentos do que placeholders
- erro se houver placeholder nao suportado
- erro se o tipo do argumento nao for compativel com o placeholder

Compatibilidade atual:

- `%d` aceita `int` e `boolean`
- `%f` aceita `float`
- `%c` aceita `char`
- `%s` aceita `string`

## Strings e runtime

Quando o print envolve `string`, o compilador marca `usa_string = true`, o que faz com que o codigo gerado inclua o runtime de strings:

- `foca_string`
- `foca_str_init`
- `foca_str_from_lit`
- `foca_str_copy`
- `foca_str_concat`
- `foca_str_cstr`

No caso de impressao, `foca_str_cstr` e usado para converter a representacao interna para `const char*` no ponto exato onde o C precisa imprimir.

## Decisoes de projeto

### Por que separar `print` e `printf`

- deixa a gramatica explicita
- evita sobrecarga excessiva de um unico comando
- deixa claro quando ha template e quando nao ha
- facilita validacao semantica especifica por comando

### Por que manter `print("literal")`

Esse caso continua valido porque e um print simples, sem interpolacao. Alem disso, ele pode ser emitido diretamente como:

```c
printf("literal");
```

sem custo extra de criar uma `foca_string` temporaria.

### Por que ainda usar `printf` na saida C

O objetivo nao e eliminar a funcao `printf` da linguagem alvo, e sim impedir que ela resolva a interpolacao por conta propria. Agora o compilador decide como quebrar o template e qual argumento imprimir em cada passo.

## Limitacoes atuais

- placeholders com largura e precisao, como `%0.2f`, nao sao suportados
- placeholders diferentes de `%d`, `%f`, `%c`, `%s` e `%%` nao sao suportados
- o template precisa ser um literal de string na sintaxe atual

## Resumo final

- `print(expr)` imprime um unico valor
- `printf("template", ...)` imprime usando template expandido pelo compilador
- a interpolacao agora acontece na traducao, nao no casamento variadico do C
- strings continuam usando o runtime proprio do compilador
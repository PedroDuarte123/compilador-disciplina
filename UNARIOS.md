# Implementacao dos Operadores Unarios no FOCA

Este documento descreve a implementacao atual dos operadores unarios basicos no compilador FOCA.

## Operadores suportados

O compilador passa a aceitar os seguintes operadores unarios:

- `+expr`  : mais unario
- `-expr`  : menos unario
- `++id`   : pre-incremento
- `id++`   : pos-incremento
- `--id`   : pre-decremento
- `id--`   : pos-decremento
- `!expr`  : negacao logica, que ja existia

## Escopo da implementacao

Os operadores aritmeticos unarios e de incremento/decremento foram implementados apenas para tipos `int` e `float`.

Regras atuais:

- `+expr` e `-expr` exigem `int` ou `float`
- `++id`, `id++`, `--id` e `id--` exigem variavel `int` ou `float`
- `!expr` continua exigindo `boolean`

`++` e `--` atuam apenas sobre identificadores, nao sobre expressoes arbitrarias.

Exemplos validos:

```foca
int a;
float b;

a = 5;
b = 2.5;

print(--a);
print(a--);
print(++a);
print(a++);
print(-a);
print(+a);
print(--b);
print(b--);
print(-b);
```

Exemplos invalidos:

```foca
++1
(a + b)--
--"texto"
```

## Alteracoes no lexer

No arquivo `lexico.l`, foram adicionados dois tokens novos:

- `TK_INC` para `++`
- `TK_DEC` para `--`

Essas regras precisam aparecer antes das regras de `+` e `-`, para que o lexer reconheca os operadores compostos como um token unico.

Trecho conceitual:

```lex
"++"        { return TK_INC; }
"--"        { return TK_DEC; }
```

## Alteracoes na gramatica

No arquivo `sintatico.y`, foram adicionados:

- os tokens `TK_INC` e `TK_DEC`
- precedencias artificiais para distinguir operadores prefixos e posfixos
- producoes especificas dentro da regra `E`

As precedencias usadas foram:

```bison
%right TK_NOT UPLUS UMINUS PREINC PREDEC
%left POSTINC POSTDEC
```

Com isso:

- os prefixos ficam com alta precedencia
- os posfixos ficam ainda mais fortes
- `+expr` e `-expr` nao conflitam com os operadores binarios `+` e `-`

## Novas producoes na expressao

Foram adicionadas producoes equivalentes a:

```bison
'+' E %prec UPLUS
'-' E %prec UMINUS
TK_INC TK_ID %prec PREINC
TK_DEC TK_ID %prec PREDEC
TK_ID TK_INC %prec POSTINC
TK_ID TK_DEC %prec POSTDEC
```

Essas regras resolvem dois grupos de operadores:

- unarios sobre qualquer expressao numerica: `+expr` e `-expr`
- atualizacao de variavel: `++id`, `id++`, `--id`, `id--`

## Geracao de codigo para `+expr` e `-expr`

Foi adicionada a funcao:

- `gerar_unario_aritmetico(const char* op, const atributos& expr)`

### Mais unario

`+expr` apenas valida o tipo e devolve a propria expressao, sem gerar temporario extra.

Exemplo:

```foca
print(+a);
```

Pode reutilizar diretamente o valor atual de `a`.

### Menos unario

`-expr` gera um novo temporario do mesmo tipo da expressao e emite codigo equivalente a:

```c
t5 = -t2;
```

Isso preserva o valor original da expressao de entrada.

## Geracao de codigo para `++` e `--`

Foi adicionada a funcao:

- `gerar_inc_dec(const string& nome, bool incrementar, bool prefixo)`

Ela centraliza toda a logica de:

- localizar a variavel na tabela de simbolos
- validar o tipo
- verificar inicializacao
- garantir que a variavel tenha uma celula temporaria interna
- gerar o codigo de atualizacao
- devolver o valor correto da expressao para o caso prefixo ou posfixo

### Prefixo

No prefixo, a variavel e atualizada primeiro, e o resultado da expressao e o valor atualizado.

Exemplo:

```foca
print(--a);
```

Gera algo conceitualmente assim:

```c
t2 = t2 - 1;
printf("%d", t2);
```

### Posfixo

No posfixo, a expressao devolve o valor antigo, e so depois a variavel e atualizada.

Exemplo:

```foca
print(a--);
```

Gera algo conceitualmente assim:

```c
t3 = t2;
t2 = t2 - 1;
printf("%d", t3);
```

## Escolha do literal `1` ou `1.0`

Foi adicionada a funcao:

- `literal_um_para_tipo(const string& tipo)`

Ela escolhe o incremento apropriado:

- `1` para `int`
- `1.0` para `float`

Assim, `++` e `--` preservam o tipo numerico da variavel atualizada.

## Validacoes semanticas

As novas operacoes fazem validacoes explicitas.

### Para `+expr` e `-expr`

Se o operando nao for `int` nem `float`, o compilador emite:

```text
Operador unário aritmético exige operando int ou float
```

### Para `++` e `--`

Se a variavel nao for `int` nem `float`, o compilador emite:

```text
Operadores '++' e '--' exigem variável int ou float
```

Se a variavel ainda nao tiver sido inicializada, o compilador emite:

```text
Variável 'x' usada antes de inicialização
```

## Exemplo oficial

Foi adicionado o exemplo:

- `exemplos/28_unarios.foca`

Esse arquivo cobre:

- pre-decremento
- pos-decremento
- pre-incremento
- pos-incremento
- mais unario
- menos unario
- casos com `int`
- casos com `float`

## Resumo

- o lexer agora reconhece `++` e `--`
- o parser agora diferencia prefixo e posfixo
- `+expr` e `-expr` foram implementados como unarios reais
- `--x` e `x--` geram codigo diferente, respeitando a semantica correta
- a implementacao atual cobre `int` e `float`
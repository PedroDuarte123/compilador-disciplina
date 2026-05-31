# Blocos e Contexto (Escopo) no FOCA

Este documento explica as mudanças feitas para suportar **blocos** `{ ... }` e **contexto** (escopo) no compilador FOCA.

A ideia é deixar o código pronto para, no futuro, ser fácil adicionar comandos como **condicionais** (`if/else`) e **repetição** (`while/for`), que normalmente aceitam tanto um comando simples quanto um bloco.

---

## 1) O que é “bloco” e o que é “contexto”

- **Bloco**: uma sequência de comandos delimitada por chaves:

```foca
{
    ...comandos...
}
```

- **Contexto/Escopo**: o “ambiente” onde variáveis declaradas existem.
  - Variáveis declaradas dentro de um bloco devem **existir apenas dentro dele**.
  - Fora do bloco, elas deixam de ser visíveis.

Isso é essencial para permitir:

- variáveis locais em blocos
- sombreamento (*shadowing*): declarar uma variável com o mesmo nome em um bloco interno sem “destruir” a do escopo externo

---

## 2) Mudanças no Léxico (Flex)

Arquivo: `lexico.l`

Foram adicionados tokens para reconhecer as chaves:

- `{`
- `}`

No Flex, isso foi feito retornando o próprio caractere (`return *yytext;`), da mesma forma que já acontece com `(`, `)`, `;`, `=` etc.

---

## 3) Mudanças no Sintático (Bison)

Arquivo: `sintatico.y`

### 3.1) Regra `BLOCO`

Foi adicionada uma regra específica para bloco:

- ao ler `{`, o compilador faz `push_scope()` (abre um novo escopo)
- processa uma `LISTA_COMANDOS`
- ao ler `}`, faz `pop_scope()` (fecha o escopo)

A tradução do bloco é simplesmente a concatenação das traduções internas (não adicionamos nada no C além do que já era gerado).

### 3.2) Bloco como `COMANDO`

Foi adicionada a alternativa:

```bison
COMANDO : BLOCO
```

Isso é um ponto-chave para facilitar `if/while` depois, porque fica natural escrever algo do tipo:

- `if (cond) COMANDO`
- `while (cond) COMANDO`

Como `COMANDO` já pode ser:

- um comando simples (`scan x;`, `print(...);`, `E;`, declaração etc.)
- ou um `BLOCO`

então `if/while` automaticamente passam a aceitar as duas formas.

---

## 4) Implementação do Contexto (Escopo)

### 4.1) Por que trocar a tabela de símbolos

Antes, a tabela de símbolos era um único `map` global (um único escopo). Isso impede variáveis locais e o comportamento correto de blocos.

Agora, o compilador usa uma **pilha de escopos**:

```cpp
static vector< map<string, simbolo> > escopos;
```

Cada item do `vector` representa um escopo.

- Escopo global: `escopos[0]`
- Escopos internos: `escopos[1]`, `escopos[2]`, ...

### 4.2) Operações básicas

Foram criadas três funções utilitárias:

- `push_scope()`
  - cria um novo `map` no topo da pilha
- `pop_scope()`
  - remove o `map` do topo
  - garante que sempre exista pelo menos 1 escopo
- `escopo_atual()`
  - retorna uma referência para o escopo do topo

### 4.3) Busca de símbolos (lookup)

As funções `buscar_simbolo`/`buscar_simbolo_const` foram adaptadas para procurar do escopo mais interno para o mais externo:

- começa do topo (escopo atual)
- se não encontrar, vai “subindo” para o escopo pai
- até chegar no global

Isso implementa o comportamento esperado de linguagens comuns:

- dentro do bloco interno, um identificador pode referenciar a variável interna
- fora do bloco, volta a referenciar a variável externa

### 4.4) Regra de redeclaração

A regra adotada foi:

- **redeclaração é erro apenas no escopo atual**
- em escopos internos, é permitido declarar um novo símbolo com o mesmo nome (shadowing)

Isso foi implementado verificando apenas `escopo_atual()` na declaração:

- se já existe ali → erro
- senão → insere no escopo atual

---

## 5) Exemplo de uso

Arquivo: `exemplos/16_bloco.foca`

Ele demonstra shadowing:

```foca
int x;
x = 1;

{
    int x;
    x = 2;
    print("inner x=%d\n", x);
}

print("outer x=%d\n", x);
```

Saída esperada ao executar o C gerado:

- `inner x=2`
- `outer x=1`

---

## 6) Dicas para implementar `if/while` depois

Uma forma simples e modular de evoluir a gramática é:

- criar tokens `if`, `else`, `while`
- criar regras que usem `COMANDO` (não apenas `BLOCO`)

Exemplo de formato de regra (esqueleto):

```bison
COMANDO
  : ...
  | IF '(' E ')' COMANDO
  | IF '(' E ')' COMANDO ELSE COMANDO
  | WHILE '(' E ')' COMANDO
  ;
```

Como `COMANDO` já aceita `BLOCO`, você ganha automaticamente:

- `if (...) x = 1;`
- `if (...) { ... }`

E o gerenciamento de variáveis locais já fica correto por causa de `push_scope/pop_scope` no `BLOCO`.

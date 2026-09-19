# Conciliação de pagamentos em COBOL

Projeto de aprendizado e portfólio para construir uma aplicação
de conciliação de pagamentos, começando pelo processamento em COBOL.

O objetivo é comparar pagamentos esperados e recebidos,
identificando correspondências, diferenças e ausências.

## Estado atual

Programa de terminal que confere um pagamento por execução.

Funcionalidades implementadas:

- Recebe o nome ou login do operador.
- Solicita os valores esperado e recebido pelo teclado.
- Valida o formato e o limite dos valores antes da conversão.
- Permite corrigir entradas inválidas sem reiniciar.
- Preserva os campos já aceitos.
- Calcula a diferença entre recebido e esperado.
- Classifica o pagamento como igual, abaixo ou acima do esperado.

A identificação do operador é informativa: ainda não há autenticação.

O programa utiliza GnuCOBOL no Ubuntu. Não foi executado
em ambiente mainframe.

## Regra de cálculo

```text
Diferença = valor recebido - valor esperado
```

| Diferença | Classificação |
|---|---|
| Positiva | Recebido acima do esperado |
| Zero | Pagamento conferido |
| Negativa | Recebido abaixo do esperado |

## Regras de entrada

### Operador

Aceita nome ou login preenchido, como `Bruno` ou `bruno.lopes`.

Uma entrada vazia ou composta apenas por espaços gera uma mensagem
e uma nova solicitação.

### Valores monetários

- Faixa permitida: 0 até 99999.99, inclusive.
- Pelo menos um dígito antes do ponto.
- Ponto decimal opcional.
- Quando houver ponto, deve haver um ou dois dígitos depois dele.
- Zeros à esquerda são aceitos.
- Espaços nas extremidades são removidos.
- Espaços internos, vírgulas, sinais, letras e outros símbolos
  são rejeitados.
- Entradas inválidas permitem nova tentativa do mesmo campo.

| Formato | Exemplos |
|---|---|
| Inteiro | `0`, `100` |
| Uma casa decimal | `100.5` |
| Duas casas decimais | `0.50`, `100.50` |
| Zeros à esquerda | `00100.50` |
| Espaços nas extremidades | ` 100.50 ` |

Exemplos rejeitados: `100,50`, `+100`, `-100`, `1 00.50`,
`.50`, `100.`, `90.8.0` e `100.509`.

A validação examina o texto armazenado no campo.
Entradas acima da capacidade desse campo ainda precisam
de tratamento específico.

## Organização do código

O fluxo principal recebe os dados, solicita correções,
armazena os valores aceitos e apresenta o resultado.

As regras monetárias são compartilhadas entre esperado e recebido.

| Parágrafo | Responsabilidade |
|---|---|
| `validar-formato` | Examinar os caracteres e contar dígitos inteiros e decimais |
| `validar-valor` | Aplicar as verificações de formato, casas decimais, conversibilidade e limite; converter o valor aceito |

O parágrafo `validar-valor` chama `validar-formato`.

A leitura dos campos utiliza `PERFORM UNTIL`.
A escolha entre condições utiliza `EVALUATE TRUE`.

### Dados compartilhados pela validação

| Variável | Finalidade |
|---|---|
| `entrada-validacao` | Texto a validar, normalizado pela remoção de espaços nas extremidades |
| `formato-ok` | Indica se a estrutura do texto é aceita |
| `tamanho-entrada` | Comprimento do texto sem espaços nas extremidades |
| `digitos-inteiros` | Quantidade de dígitos antes do ponto |
| `casas-decimais` | Quantidade de dígitos após o ponto |
| `encontrou-ponto` | Indica se o ponto já foi encontrado |
| `validacao-ok` | Resultado final: 0 para inválido, 1 para válido |
| `valor-validado` | Número convertido quando a validação passa |
| `mensagem-erro` | Motivo da rejeição |

Essas variáveis pertencem ao programa e são compartilhadas pelos
parágrafos. Não constituem parâmetros formais de uma função.

Os resultados e contadores são reinicializados em cada validação.

## Ambiente

- Ubuntu 24.04 LTS em VirtualBox.
- GnuCOBOL 3.1.2.0.
- Git 2.43.0.
- Editor GNU Nano.
- Acesso ao Ubuntu por SSH a partir do Windows.

## Arquivos

| Arquivo | Finalidade |
|---|---|
| `ola.cob` | Código-fonte |
| `.gitignore` | Regras para ignorar arquivos gerados |
| `README.md` | Documentação |

O executável `ola` é gerado pela compilação e não é versionado.

## Compilar e executar

Na pasta do projeto:

```bash
cobc -x -free -o ola ola.cob
```

| Parte | Significado |
|---|---|
| `cobc` | Compilador |
| `-x` | Gera executável |
| `-free` | Utiliza formato livre |
| `-o ola` | Define o nome da saída |
| `ola.cob` | Arquivo-fonte |

Após alterar o código, compile novamente para atualizar o executável.

Para executar:

```bash
./ola
```

`./` indica a pasta atual.

Exemplo de interação:

```text
Sistema de conciliacao iniciado.
Digite o nome ou login do operador:
bruno.lopes
Operador: bruno.lopes
Digite o valor esperado (exemplo: 100.50):
100,50
Erro no valor esperado: use digitos e ponto decimal, como 100.50.
Digite o valor esperado (exemplo: 100.50):
100.50
Digite o valor recebido (exemplo: 80.25):
90.80
Valor esperado: 00100.50
Valor recebido: 00090.80
Diferenca: -00009.70
Status: valor recebido abaixo do esperado.
```

Os zeros à esquerda fazem parte da apresentação atual dos campos.
Para testar outros dados, basta executar novamente, sem recompilar.

## Testes manuais

Os testes utilizam dados fictícios.

### Cenários verificados em etapas anteriores

- Classificação de valores iguais, abaixo e acima do esperado.
- Limites monetários, incluindo 0 e 99999.99.
- Rejeição de letras, valores negativos e valores acima do limite.
- Rejeição de casas decimais extras.
- Operador obrigatório.
- Correção de entradas sem reiniciar.
- Preservação dos campos já aceitos.
- Reutilização da validação sem carregar resultados de chamadas anteriores.
- Remoção de um bloco antigo que solicitava o recebido novamente.

Esses cenários não foram todos reexecutados após cada alteração.

### Formato monetário — etapa atual

Primeira execução:

| Campo | Sequência de tentativas |
|---|---|
| Operador | bruno.lopes |
| Esperado | 100,50 → 1 00.50 → .50 → 100.50 |
| Recebido | 100. → 90.8.0 → 90.809 → 90.80 |

Somente a última tentativa de cada valor foi aceita.

Resultado: diferença -9.70, abaixo do esperado.

Segunda execução:

| Campo | Entrada | Resultado |
|---|---|---|
| Esperado | ` 00100.50 ` | Aceito como 100.50 |
| Recebido | `+100.50` | Rejeitado, permitindo correção |
| Recebido | `100.5` | Aceito como 100.50 |

Resultado: diferença zero, pagamento conferido.

Os testes são manuais. Não há cobertura exaustiva nem suíte
automatizada.

## Limitações

- Apenas um pagamento por execução.
- Sem tratamento específico para entradas acima da capacidade
  dos campos `PIC X(40)`.
- Sem tratamento específico para fim da entrada padrão.
- Sem leitura de arquivos de pagamentos ou relatório.
- Sem banco, API, interface web ou autenticação.
- Sem integração com sistemas bancários.

## Conceitos praticados

- Estrutura de um programa COBOL.
- Campos com `PIC` e inicialização com `VALUE`.
- Entrada e saída com `ACCEPT` e `DISPLAY`.
- Verificação de conversibilidade com `TEST-NUMVAL`.
- Conversão com `NUMVAL` e cálculos com `COMPUTE`.
- Condições com `IF`, `ELSE`, `AND` e `OR`.
- Seleção com `EVALUATE TRUE`.
- Repetição com `PERFORM UNTIL` e `PERFORM VARYING`.
- Interrupção de um laço com `EXIT PERFORM`.
- Parágrafos executados com `PERFORM`.
- Atribuição com `MOVE` e incremento com `ADD`.
- Referência a posições de texto.
- Remoção de espaços com `TRIM` e comprimento com `LENGTH`.
- Validação explícita do formato de entrada.
- Refatoração para compartilhar regras.
- Reinicialização de resultados entre chamadas.
- Testes manuais e regressão.
- Compilação, execução, Git e GitHub.

## Próximas etapas do COBOL

- Melhorar a apresentação dos valores.
- Ler arquivos de esperados e recebidos.
- Tratar limites de entrada e fim de arquivo.
- Conciliar pagamentos por identificador.
- Identificar diferenças e ausências.
- Gerar relatório com resultados e totais.
- Automatizar os testes principais.

## Evolução planejada

Todos os componentes abaixo fazem parte do escopo obrigatório,
em um único repositório. Apenas a etapa inicial em COBOL foi
implementada até agora.

| Componente | Tecnologia |
|---|---|
| Motor de conciliação | COBOL |
| Banco de dados | PostgreSQL |
| Primeiro backend | Java |
| Backend alternativo | C# com .NET |
| Primeira interface | Angular |
| Interface alternativa | Vue |
| Interface alternativa | React |

Primeiro será concluída uma combinação funcional de ponta a ponta.
Depois serão implementadas as alternativas.

Os backends deverão seguir o mesmo contrato de API.
As três interfaces deverão ser compatíveis com ambos.

Funcionalidades web planejadas:

- Autenticação e separação dos dados por usuário.
- Envio de arquivos para conciliação.
- Histórico de execuções, detalhes e totais.
- Download de relatórios.

## Autor

Bruno Ramos Lopes

Projeto de aprendizado e portfólio em desenvolvimento.

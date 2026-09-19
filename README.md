# Conciliação de pagamentos em COBOL

Projeto de aprendizado e portfólio para desenvolver uma aplicação
de conciliação de pagamentos, começando pelo processamento em COBOL.

O objetivo é comparar pagamentos esperados e recebidos,
identificando correspondências, diferenças e ausências.

## Estado atual

Programa executado no terminal que confere um pagamento por execução.

Funcionalidades implementadas:

- Recebe o nome ou login do operador.
- Solicita os valores esperado e recebido pelo teclado.
- Valida as entradas antes de realizar o cálculo.
- Permite corrigir entradas inválidas sem reiniciar o programa.
- Preserva os dados já aceitos enquanto solicita a correção do campo atual.
- Calcula a diferença entre valor recebido e valor esperado.
- Classifica o recebimento como igual, abaixo ou acima do esperado.

A identificação do operador é informativa. Ainda não há autenticação
de contas ou verificação de senha.

O projeto é executado no Ubuntu com GnuCOBOL, sem uso de
ambiente mainframe.

## Regra de cálculo

```text
Diferença = valor recebido - valor esperado
```

- Diferença positiva: valor recebido acima do esperado.
- Diferença zero: pagamento conferido.
- Diferença negativa: valor recebido abaixo do esperado.

## Validações implementadas

- Nome ou login do operador não pode ficar vazio ou conter apenas espaços.
- Entradas monetárias devem ser conversíveis em número.
- Valores devem estar entre 0 e 99999.99, inclusive.
- São permitidos no máximo dois dígitos após o ponto decimal.
- Uma entrada inválida gera uma mensagem e uma nova solicitação
  do mesmo campo.

Para digitar valores, utilize ponto como separador decimal,
sem separador de milhares. Exemplos: `100`, `100.5` e `100.50`.

A conversibilidade é verificada com `FUNCTION TEST-NUMVAL`.
O valor é armazenado no campo numérico com `FUNCTION NUMVAL`
após passar pelas validações.

## Correção de entradas

As solicitações utilizam `PERFORM UNTIL` para repetir a leitura
até que a entrada seja aceita.

Nos valores monetários, `EVALUATE TRUE` organiza a escolha entre
as condições de validação.

- Operador inválido: solicita novamente o operador.
- Valor esperado inválido: mantém o operador e solicita novamente
  o valor esperado.
- Valor recebido inválido: mantém o operador e o valor esperado,
  solicitando novamente o valor recebido.

O cálculo ocorre depois que os dois valores são aceitos.

## Limitações atuais

- Apenas um pagamento é conferido por execução.
- Há código repetido entre as validações do esperado e do recebido.
- O formato monetário ainda não possui uma validação estrita:
  a conversão segue as regras do GnuCOBOL, complementadas pelas
  verificações de faixa e casas decimais.
- Os campos de entrada utilizam `PIC X(40)`. Ainda não há tratamento
  específico para entradas que ultrapassem essa capacidade.
- Ainda não há tratamento específico para fim da entrada padrão.
- Não há leitura de arquivos de pagamentos, persistência em banco,
  interface web ou geração de relatório.
- Não há integração com sistemas bancários.

Os testes utilizam dados fictícios.

## Ambiente utilizado

- Ubuntu 24.04 LTS em uma máquina virtual no VirtualBox.
- GnuCOBOL 3.1.2.0.
- Git 2.43.0.
- Editor GNU Nano.
- Acesso ao Ubuntu por SSH a partir do Windows.

## Arquivos

| Arquivo | Finalidade |
|---|---|
| `ola.cob` | Código-fonte do programa COBOL |
| `.gitignore` | Define arquivos que não devem ser versionados |
| `README.md` | Documentação do projeto |

O executável `ola` é gerado pela compilação e não é versionado.

## Como compilar

Com o GnuCOBOL instalado, execute na pasta do projeto:

```bash
cobc -x -free -o ola ola.cob
```

| Parte | Significado |
|---|---|
| `cobc` | Compilador do GnuCOBOL |
| `-x` | Gera um programa executável |
| `-free` | Utiliza formato livre para o código-fonte |
| `-o ola` | Define `ola` como nome do arquivo de saída |
| `ola.cob` | Arquivo-fonte que será compilado |

Após alterar e salvar `ola.cob`, compile novamente para atualizar
o executável.

## Como executar

Após compilar sem erros:

```bash
./ola
```

`./` indica a pasta atual e `ola` é o programa executável.

Exemplo de interação com correção do valor recebido:

```text
Sistema de conciliacao iniciado.
Digite o nome ou login do operador:
bruno.lopes
Operador: bruno.lopes
Digite o valor esperado (exemplo: 100.50):
100.50
Digite o valor recebido (exemplo: 80.25):
abc
Erro: valor recebido invalido.
Digite o valor recebido (exemplo: 80.25):
90.80
Valor esperado: 00100.50
Valor recebido: 00090.80
Diferenca: -00009.70
Status: valor recebido abaixo do esperado.
```

Os zeros à esquerda fazem parte da apresentação atual dos campos
numéricos.

Não é necessário recompilar para testar outros valores:
basta executar o programa novamente.

## Testes manuais realizados

### Cálculo e limites — etapas anteriores

| Esperado | Recebido | Resultado verificado |
|---|---|---|
| 100.50 | 90.80 | Diferença -9.70; abaixo do esperado |
| 100.50 | 100.50 | Pagamento conferido |
| 100.50 | 120.75 | Diferença +20.25; acima do esperado |
| 0 | 99999.99 | Diferença +99999.99; acima do esperado |
| -1 | Não solicitado | Rejeição por limite do esperado |
| 100000 | Não solicitado | Rejeição por limite do esperado |
| 100 | -1 | Rejeição por limite do recebido |
| 100 | 100000 | Rejeição por limite do recebido |
| 100.509 | Não solicitado | Rejeição por casas decimais do esperado |
| 100.50 | 100.509 | Rejeição por casas decimais do recebido |

Esses cenários foram executados antes da introdução das novas tentativas.
Naquela versão, uma entrada inválida encerrava o programa.

### Novas tentativas — etapa atual

Cada sequência abaixo foi executada sem reiniciar o programa.

| Campo | Sequência de entradas | Resultado verificado |
|---|---|---|
| Operador | Vazio → espaços → bruno.lopes | Rejeita as duas primeiras tentativas e aceita o login |
| Esperado | abc → -1 → 100.509 → 100.50 | Exibe os erros e aceita a última tentativa, mantendo o operador |
| Recebido | abc → 100000 → 90.809 → 90.80 | Exibe os erros e aceita a última tentativa, mantendo os dados anteriores |

Nos testes da etapa atual, a conclusão com esperado `100.50`
e recebido `90.80` produziu diferença de `-9.70`,
classificada como abaixo do esperado.

Os testes são manuais e documentam os cenários executados.
Não representam cobertura exaustiva nem uma suíte automatizada.

## Conceitos praticados

- Estrutura básica de um programa COBOL.
- Declaração de campos com `PIC` e valores iniciais com `VALUE`.
- Entrada e saída com `ACCEPT` e `DISPLAY`.
- Conversão de texto em número.
- Cálculos com `COMPUTE`.
- Condições com `IF`, `ELSE`, `AND` e `OR`.
- Seleção de condições com `EVALUATE TRUE`.
- Repetição com `PERFORM VARYING` e `PERFORM UNTIL`.
- Variáveis de controle para indicar uma entrada válida.
- Leitura de posições de um campo de texto.
- Atribuição com `MOVE` e incremento com `ADD`.
- Validação antes do armazenamento em campos numéricos.
- Preservação de dados já aceitos durante novas tentativas.
- Testes de entradas válidas, inválidas e valores de limite.
- Diferença entre código-fonte e executável.
- Controle de versões com Git e publicação no GitHub.

## Próximas etapas do COBOL

- Organizar as validações para reduzir repetição de código.
- Tornar o formato de entrada monetária mais rigoroso.
- Melhorar a apresentação dos valores.
- Ler arquivos de pagamentos esperados e recebidos.
- Conciliar registros por identificador.
- Identificar diferenças e pagamentos ausentes.
- Gerar relatório com resultados e totais.
- Automatizar os principais testes.

## Evolução planejada da aplicação

O objetivo é manter os componentes em um único repositório,
organizado futuramente como monorepo.

Todas as tecnologias abaixo fazem parte do escopo planejado.
Ainda não estão implementadas.

| Componente | Tecnologia | Responsabilidade |
|---|---|---|
| Motor de conciliação | COBOL | Processar e comparar os pagamentos |
| Banco de dados | PostgreSQL | Guardar execuções e resultados |
| Primeiro backend | Java | Expor API e integrar o processamento |
| Backend alternativo | C# com .NET | Implementar o mesmo contrato de API |
| Primeira interface | Angular | Enviar dados e consultar resultados |
| Interface alternativa | Vue | Implementar as mesmas funcionalidades |
| Interface alternativa | React | Implementar as mesmas funcionalidades |

Primeiro será construída uma combinação funcional de ponta a ponta.
Depois serão implementadas as alternativas.

Os dois backends deverão seguir o mesmo contrato de API.
As três interfaces deverão ser compatíveis com ambos.

Funcionalidades web planejadas:

- Autenticação de usuários.
- Separação dos dados de cada usuário.
- Envio de arquivos para conciliação.
- Consulta do histórico, detalhes e totais.
- Download de relatórios.

## Autor

Bruno Ramos Lopes

Projeto de aprendizado e portfólio em desenvolvimento.

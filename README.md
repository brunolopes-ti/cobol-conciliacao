# Conciliação de pagamentos em COBOL

Projeto de estudo desenvolvido para praticar programação em COBOL,
validação de dados, cálculos monetários, testes e controle de versões.

O objetivo é evoluir para uma conciliação entre pagamentos esperados
e recebidos, identificando correspondências e diferenças.

## Estado atual

Programa executado no terminal que confere um pagamento por execução.

Funcionalidades implementadas:

- Recebe o nome ou login do operador.
- Solicita os valores esperado e recebido pelo teclado.
- Valida as entradas antes de realizar o cálculo.
- Calcula a diferença entre valor recebido e valor esperado.
- Classifica o recebimento como igual, abaixo ou acima do esperado.

A identificação do operador é informativa: não há autenticação
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
- Entradas rejeitadas geram uma mensagem de erro e encerram o programa.

Para digitar valores, utilize ponto como separador decimal,
sem separador de milhares. Exemplos: `100`, `100.5` e `100.50`.

A conversibilidade é verificada com `FUNCTION TEST-NUMVAL`.
A conversão é realizada com `FUNCTION NUMVAL`, após as validações.

## Limitações atuais

- Apenas um pagamento é conferido por execução.
- O programa encerra ao detectar uma entrada inválida; ainda não solicita
  uma nova tentativa.
- O formato monetário ainda não possui uma validação estrita:
  a conversão segue as regras do GnuCOBOL, complementadas pelas
  verificações de faixa e casas decimais.
- Os campos de entrada utilizam `PIC X(40)`. Ainda não há tratamento
  específico para entradas que ultrapassem essa capacidade.
- Não há leitura de arquivos, persistência em banco de dados,
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

Exemplo de interação:

```text
Sistema de conciliacao iniciado.
Digite o nome ou login do operador:
bruno.lopes
Operador: bruno.lopes
Digite o valor esperado (exemplo: 100.50):
100.50
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

### Cálculo e classificação

| Esperado | Recebido | Diferença | Resultado |
|---|---|---|---|
| 100.50 | 90.80 | -9.70 | Abaixo do esperado |
| 100.50 | 100.50 | 0.00 | Pagamento conferido |
| 100.50 | 120.75 | +20.25 | Acima do esperado |
| 0 | 99999.99 | +99999.99 | Acima do esperado |

### Validação dos valores

| Esperado | Recebido | Resultado |
|---|---|---|
| abcd | Não solicitado | Erro de valor esperado inválido |
| 100.50 | abcd | Erro de valor recebido inválido |
| -1 | Não solicitado | Erro de limite do esperado |
| 100000 | Não solicitado | Erro de limite do esperado |
| 100 | -1 | Erro de limite do recebido |
| 100 | 100000 | Erro de limite do recebido |
| 100.509 | Não solicitado | Erro de casas decimais do esperado |
| 100.50 | 100.509 | Erro de casas decimais do recebido |

### Identificação do operador

- Nome vazio: rejeitado.
- Nome ou login preenchido, como `Bruno` e `bruno.lopes`: aceito.

Após acrescentar a validação de casas decimais, foi repetido o teste
com valor esperado de `100.50` e recebido de `90.80`.
O resultado continuou sendo diferença de `-9.70`, abaixo do esperado.

Esses testes documentam os cenários executados; não representam
cobertura de todas as entradas possíveis.

## Conceitos praticados

- Estrutura básica de um programa COBOL.
- Declaração de campos com `PIC` e valores iniciais com `VALUE`.
- Entrada e saída com `ACCEPT` e `DISPLAY`.
- Conversão de texto em número.
- Cálculos com `COMPUTE`.
- Condições com `IF`, `ELSE`, `AND` e `OR`.
- Repetição com `PERFORM VARYING`.
- Leitura de posições de um campo de texto.
- Atribuição com `MOVE` e incremento com `ADD`.
- Validação antes do armazenamento em campos numéricos.
- Testes de entradas válidas, inválidas e valores de limite.
- Diferença entre código-fonte e executável.
- Controle de versões com Git e publicação no GitHub.

## Próximos passos

- Organizar as validações para reduzir repetição de código.
- Tornar o formato de entrada monetária mais rigoroso.
- Permitir nova tentativa após uma entrada inválida.
- Melhorar a apresentação dos valores.
- Ler pagamentos de arquivos.
- Processar vários pagamentos e gerar um relatório de conciliação.

## Autor

Bruno Ramos Lopes

Projeto de aprendizado e portfólio em desenvolvimento.

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
- Valida as entradas antes de armazenar os valores numéricos.
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

## Validações

- Operador não pode ficar vazio ou conter apenas espaços.
- Valores devem ser conversíveis em número.
- Faixa permitida: 0 até 99999.99, inclusive.
- No máximo dois dígitos após o ponto decimal.
- Entradas inválidas geram uma mensagem e nova tentativa do mesmo campo.

Digite os valores usando ponto decimal e sem separador de milhares.
Exemplos: `100`, `100.5` e `100.50`.

## Organização do código

A leitura dos campos utiliza `PERFORM UNTIL` para permitir
novas tentativas.

As regras monetárias são compartilhadas entre esperado e recebido.

| Parágrafo | Responsabilidade |
|---|---|
| `validar-valor` | Verificar conversibilidade, faixa e casas decimais; converter o valor aceito |
| `contar-casas-decimais` | Contar os dígitos após o ponto no texto de entrada |

O parágrafo `validar-valor` utiliza `contar-casas-decimais`.

### Dados compartilhados pela validação

| Variável | Finalidade |
|---|---|
| `entrada-validacao` | Texto que será validado |
| `validacao-ok` | Resultado: 0 para inválido, 1 para válido |
| `valor-validado` | Número convertido quando a validação passa |
| `mensagem-erro` | Motivo da rejeição |

Essas variáveis pertencem ao programa e são compartilhadas pelos
parágrafos. Não constituem parâmetros formais de uma função.

Cada chamada reinicializa seus resultados para evitar o
reaproveitamento de informações de uma validação anterior.

O fluxo principal exibe as mensagens e guarda o valor aceito
no campo esperado ou recebido.

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
100.50
Digite o valor recebido (exemplo: 80.25):
abc
Erro no valor recebido: informe um numero valido.
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

| Cenário | Resultado |
|---|---|
| Esperado 100.50, recebido 90.80 | Diferença -9.70, abaixo |
| Esperado 100.50, recebido 100.50 | Pagamento conferido |
| Esperado 100.50, recebido 120.75 | Diferença +20.25, acima |
| Esperado 0, recebido 99999.99 | Diferença +99999.99, acima |
| Letras nos valores | Rejeitadas |
| Valores -1 e 100000 nos dois campos | Rejeitados |
| Valor 100.509 nos dois campos | Rejeitado |
| Operador vazio ou apenas espaços | Nova tentativa |
| Operador bruno.lopes | Aceito |

### Regressão após extração da contagem

Na mesma execução:

- Esperado: `100.509` seguido de `100.50`.
- Recebido: `90.809` seguido de `90.80`.
- Entradas inválidas rejeitadas e corrigidas.
- Resultado final: diferença -9.70, abaixo do esperado.

### Regressão após centralização da validação

Na mesma execução:

| Campo | Sequência de tentativas |
|---|---|
| Operador | bruno.lopes |
| Esperado | abc → -1 → 100.509 → 100.50 |
| Recebido | abc → 100000 → 90.809 → 90.80 |

As tentativas inválidas foram rejeitadas e as últimas foram aceitas,
preservando os campos anteriores.

Resultado final: diferença -9.70, abaixo do esperado.

O teste também verificou que uma validação bem-sucedida do esperado
não faz a rotina aceitar uma entrada inválida no recebido.

Os testes são manuais. Não há cobertura exaustiva nem suíte
automatizada. Os cenários de etapas anteriores não foram todos
reexecutados após cada alteração.

## Limitações

- Apenas um pagamento por execução.
- Formato monetário ainda não é estritamente validado:
  utiliza as regras de conversão do GnuCOBOL, além das verificações
  de faixa e casas decimais.
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
- Conversão com `TEST-NUMVAL` e `NUMVAL`.
- Cálculos com `COMPUTE`.
- Condições com `IF`, `ELSE`, `AND` e `OR`.
- Seleção com `EVALUATE TRUE`.
- Repetição com `PERFORM UNTIL` e `PERFORM VARYING`.
- Parágrafos executados com `PERFORM`.
- Atribuição com `MOVE` e incremento com `ADD`.
- Referência a posições de texto e uso de `FUNCTION TRIM`.
- Refatoração para compartilhar regras.
- Reinicialização de resultados entre chamadas.
- Testes manuais e regressão.
- Compilação, execução, Git e GitHub.

## Próximas etapas do COBOL

- Tornar o formato monetário mais rigoroso.
- Melhorar a apresentação dos valores.
- Ler arquivos de esperados e recebidos.
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

# Conciliação de pagamentos em COBOL

Projeto de aprendizado e portfólio para construir uma aplicação
de conciliação de pagamentos, começando pelo processamento em COBOL.

O objetivo é comparar pagamentos esperados e recebidos,
identificar correspondências, diferenças e ausências.

O projeto utiliza GnuCOBOL no Ubuntu. Não foi executado
em ambiente mainframe.

## Estado atual

Existem dois programas independentes:

| Programa | Responsabilidade |
|---|---|
| `ola.cob` | Conferência interativa de um pagamento |
| `leitor.cob` | Leitura e validação de registros de um arquivo |

Os dois programas possuem testes automatizados em Bash.

Atualmente existem oito cenários automatizados:

- Cinco para o leitor de arquivo.
- Três para o tratamento de fim da entrada interativa.

A comparação entre arquivos de pagamentos esperados e recebidos
ainda não foi implementada.

## Conferência interativa

O programa `ola.cob`:

- Solicita o nome ou login do operador.
- Rejeita identificação vazia ou composta apenas por espaços.
- Solicita os valores esperado e recebido.
- Valida as entradas monetárias.
- Permite nova tentativa após uma entrada inválida.
- Detecta o encerramento inesperado da entrada padrão.
- Encerra com código de erro quando a entrada termina antes dos dados necessários.
- Calcula a diferença entre recebido e esperado.
- Classifica o pagamento como conferido, abaixo ou acima do esperado.
- Exibe valores com duas casas decimais.

A identificação do operador é informativa: não existe autenticação.

### Regra de cálculo

```text
Diferença = valor recebido - valor esperado
```

| Diferença | Classificação |
|---|---|
| Positiva | Recebimento acima do esperado |
| Zero | Pagamento conferido |
| Negativa | Recebimento abaixo do esperado |

### Fim da entrada interativa

O programa trata situações em que a entrada padrão termina antes
da conclusão da conferência.

São tratados os seguintes pontos:

- Antes de informar o operador.
- Antes de informar o valor esperado.
- Antes de informar o valor recebido.

Nessas situações, o programa apresenta uma mensagem específica
e encerra com código `1`.

Exemplo:

```text
Sistema de conciliacao iniciado.
Digite o nome ou login do operador:
Erro: entrada encerrada antes de informar o operador.
```

## Leitura de arquivo

O programa `leitor.cob` lê:

```text
dados/esperados.csv
```

Cada linha deve conter um identificador e um valor esperado,
separados por ponto e vírgula.

O arquivo não possui cabeçalho.

Exemplo:

```text
P001;100.50
P002;200.00
P003;75.25
```

### Validação da estrutura

Cada registro precisa apresentar:

- Exatamente um ponto e vírgula.
- Identificador preenchido.
- Valor preenchido.
- No máximo 256 caracteres por linha.

O leitor informa o número da linha com erro, continua processando
os registros seguintes e apresenta os totais de registros lidos,
válidos e inválidos.

Uma linha é contabilizada como válida somente depois de passar
pela validação da estrutura e pela validação monetária.

Os identificadores ainda não possuem verificação de duplicidade
nem uma regra específica de formato.

### Limite de tamanho das linhas

O campo bruto utilizado para leitura possui capacidade maior que
o limite aceito pela aplicação.

Isso permite receber uma linha maior e verificar explicitamente
se ela ultrapassa o limite definido de 256 caracteres.

Uma linha maior que 256 caracteres é rejeitada com:

```text
Erro na linha 1: linha excede o limite de 256 caracteres.
```

### Arquivo vazio

Um arquivo existente, porém sem registros, é considerado inválido.

Nesse caso, o leitor apresenta:

```text
Erro: arquivo de pagamentos esperados esta vazio.
```

e encerra com código `1`.

## Validação monetária

Os dois programas aplicam as seguintes regras:

- Faixa permitida: de `0` a `99999.99`, inclusive.
- Inteiros são aceitos.
- Uma ou duas casas decimais são aceitas.
- O separador decimal é o ponto.
- Zeros à esquerda são aceitos.
- Espaços nas extremidades são aceitos.
- Sinais, vírgulas e espaços internos são rejeitados.
- Letras e múltiplos pontos são rejeitados.
- Quando existe ponto, deve haver dígitos antes e depois dele.
- Mais de duas casas decimais são rejeitadas.

Exemplos:

| Entrada | Resultado |
|---|---|
| `0` | Aceita |
| `100` | Aceita |
| `100.5` | Aceita |
| `100.50` | Aceita |
| `00100.50` | Aceita |
| ` 100.50 ` | Aceita |
| `99999.99` | Aceita |
| `abc` | Rejeitada |
| `+100.50` | Rejeitada |
| `-1` | Rejeitada |
| `100,50` | Rejeitada |
| `1 00.50` | Rejeitada |
| `.50` | Rejeitada |
| `100.` | Rejeitada |
| `90.8.0` | Rejeitada |
| `100.509` | Rejeitada |
| `100000` | Rejeitada |

Atualmente, as rotinas monetárias estão presentes nos dois programas.

Ainda não existe um módulo compartilhado para essa validação.
Essa organização será realizada na próxima etapa do projeto.

## Organização do leitor

| Parágrafo | Responsabilidade |
|---|---|
| `validar-registro` | Verificar tamanho, separador e campos preenchidos |
| `validar-formato` | Examinar caracteres e contar casas decimais |
| `validar-valor` | Coordenar a validação monetária e converter o valor |
| `mostrar-registro` | Apresentar identificador e valor formatado |

O fluxo principal abre o arquivo, lê cada registro, realiza
as validações, contabiliza os resultados e fecha o arquivo.

A validação monetária só ocorre quando a estrutura está correta.

## Ambiente utilizado

- Ubuntu 24.04 LTS em máquina virtual no VirtualBox.
- GnuCOBOL 3.1.2.
- Bash.
- Git e GitHub.
- Nano.
- Acesso ao Ubuntu por SSH a partir do Windows.

## Arquivos

| Arquivo | Finalidade |
|---|---|
| `ola.cob` | Conferência interativa |
| `leitor.cob` | Leitura e validação do arquivo |
| `dados/esperados.csv` | Dados fictícios de exemplo |
| `testes/cenarios/validos.csv` | Cenário com registros válidos |
| `testes/cenarios/mistos.csv` | Cenário com registros válidos e inválidos |
| `testes/cenarios/vazio.csv` | Cenário de arquivo vazio |
| `testes/cenarios/linha-longa.csv` | Cenário acima do limite de tamanho |
| `testes/testar-leitor.sh` | Testes automatizados do leitor |
| `testes/testar-ola.sh` | Testes automatizados da entrada interativa |
| `.gitignore` | Arquivos ignorados pelo Git |
| `README.md` | Documentação do projeto |

Os executáveis `ola` e `leitor` são gerados localmente
e não são versionados.

## Como compilar e executar

Execute os comandos a partir da raiz do projeto.

### Conferência interativa

Compilar:

```bash
cobc -x -free -o ola ola.cob
```

Executar:

```bash
./ola
```

### Leitor de arquivo

Compilar:

```bash
cobc -x -free -o leitor leitor.cob
```

Executar:

```bash
./leitor
```

O caminho `dados/esperados.csv` é relativo à pasta de onde
o programa é executado.

### Opções utilizadas

| Opção | Significado |
|---|---|
| `-x` | Gera um executável |
| `-free` | Utiliza formato livre de código COBOL |
| `-o` | Define o nome do executável |

## Resultado do arquivo de exemplo

```text
Leitura dos pagamentos esperados.
Pagamento: P001 | Valor esperado: 100.50
Pagamento: P002 | Valor esperado: 200.00
Pagamento: P003 | Valor esperado: 75.25
Total de registros lidos: 3
Registros validos: 3
Registros invalidos: 0
```

## Tratamento de erros do leitor

O leitor verifica as operações de arquivo por meio de `FILE STATUS`.

| Código | Significado |
|---|---|
| `00` | Operação realizada com sucesso |
| `10` | Fim do arquivo |
| `35` | Arquivo não encontrado |

Além das falhas de arquivo, o leitor também rejeita:

- Arquivo vazio.
- Linha maior que 256 caracteres.
- Estrutura inválida.
- Valor monetário inválido.

### Código de saída

| Código | Significado |
|---|---|
| `0` | Processamento concluído sem registros inválidos |
| `1` | Falha de entrada, falha de arquivo ou registro inválido |

Para consultar o código de saída:

```bash
echo $?
```

## Testes automatizados

O projeto possui duas suítes de testes em Bash.

### Testes do leitor

Execute:

```bash
bash testes/testar-leitor.sh
```

O próprio script compila `leitor.cob`, prepara os cenários,
executa o programa e verifica as saídas.

O arquivo original `dados/esperados.csv` não é alterado.

### Cenários do leitor

| Cenário | Resultado esperado | Código |
|---|---|---|
| Arquivo válido | Três registros válidos | `0` |
| Arquivo misto | Quatro válidos e quatro inválidos | `1` |
| Arquivo vazio | Arquivo rejeitado | `1` |
| Linha longa | Linha acima de 256 caracteres rejeitada | `1` |
| Arquivo ausente | `FILE STATUS 35` | `1` |

Resultado confirmado:

```text
Compilando o leitor...
PASSOU: arquivo valido
PASSOU: arquivo misto
PASSOU: arquivo vazio
PASSOU: linha longa
PASSOU: arquivo ausente

Resumo: 5 aprovados, 0 reprovados.
```

### Testes da conferência interativa

Execute:

```bash
bash testes/testar-ola.sh
```

São verificados o código de saída e a mensagem esperada.

### Cenários interativos

| Cenário | Resultado esperado | Código |
|---|---|---|
| Fim antes do operador | Entrada encerrada antes da identificação | `1` |
| Fim antes do valor esperado | Entrada encerrada antes do valor esperado | `1` |
| Fim antes do valor recebido | Entrada encerrada antes do valor recebido | `1` |

Resultado confirmado:

```text
Compilando a conferencia interativa...
PASSOU: fim antes do operador
PASSOU: fim antes do valor esperado
PASSOU: fim antes do valor recebido

Resumo: 3 aprovados, 0 reprovados.
```

### Resultado geral

```text
8 cenarios automatizados
8 aprovados
0 reprovados
```

Os testes automatizados ainda não são executados em uma
pipeline de integração contínua.

## Testes manuais realizados

### Conferência interativa

Foram testados:

- Valor recebido abaixo do esperado.
- Valor recebido igual ao esperado.
- Valor recebido acima do esperado.
- Identificação vazia.
- Nome ou login válido.
- Valores monetários inválidos.
- Nova tentativa após erro.
- Limites monetários.
- Fim da entrada antes do operador.
- Fim da entrada antes do valor esperado.
- Fim da entrada antes do valor recebido.

Os três cenários de fim da entrada também foram automatizados.

### Leitura de arquivo

Foram testados:

- Arquivo válido.
- Arquivo misto.
- Arquivo ausente.
- Arquivo vazio.
- Linha maior que 256 caracteres.
- Ausência de separador.
- Separador extra.
- Identificador vazio.
- Valor vazio.
- Valor monetário inválido.
- Continuação após um registro inválido.

### Cenário misto

Arquivo:

```text
P001;100.50
P002;abc
P003;100.509
P004;100000
P005; 00100.5
P006;0
P007;99999.99
P008;50.00;extra
```

Resultado:

| Linha | Resultado |
|---|---|
| 1 | Válida: `100.50` |
| 2 | Formato monetário inválido |
| 3 | Mais de duas casas decimais |
| 4 | Valor acima do limite |
| 5 | Válida: `100.50` |
| 6 | Válida: `0.00` |
| 7 | Válida: `99999.99` |
| 8 | Separador extra |

Totais:

```text
8 registros lidos
4 validos
4 invalidos
```

Código de saída:

```text
1
```

## Etapas do módulo COBOL

### Bloco 1 — Testes automatizados

Concluído.

Foram criados testes reproduzíveis para validar automaticamente
saídas e códigos de encerramento.

### Bloco 2 — Robustez das entradas

Concluído.

Foram implementados:

- Rejeição de arquivo vazio.
- Rejeição explícita de linhas maiores que 256 caracteres.
- Tratamento de fim da entrada interativa.
- Testes automatizados para essas situações.

### Bloco 3 — Organização do código

Próxima etapa.

Objetivo:

- Organizar os programas.
- Reduzir duplicação.
- Compartilhar a validação monetária.

### Bloco 4 — Leitura dos dois arquivos

Planejado.

Objetivo:

- Ler pagamentos esperados.
- Ler pagamentos recebidos.
- Armazenar os registros.
- Verificar identificadores duplicados.

### Bloco 5 — Conciliação por identificador

Planejado.

Objetivo:

- Comparar registros pelo identificador.
- Permitir arquivos em ordens diferentes.

### Bloco 6 — Ausências e recebimentos inesperados

Planejado.

Objetivo:

- Identificar pagamentos esperados sem recebimento.
- Identificar recebimentos sem previsão.

### Bloco 7 — Relatório e totais

Planejado.

Objetivo:

- Gerar relatório de conciliação.
- Calcular totais e classificações.

### Bloco 8 — Fechamento COBOL

Planejado.

Objetivo:

- Testar o fluxo completo.
- Finalizar a documentação.
- Preparar o módulo para integração externa.

## Limitações atuais

- A conferência interativa processa um pagamento por execução.
- A entrada interativa utiliza campos de tamanho fixo.
- O leitor trabalha apenas com pagamentos esperados.
- O arquivo de recebimentos ainda não foi implementado.
- Não existe comparação entre dois arquivos.
- Não existe detecção de identificadores duplicados.
- Não existe relatório final.
- A validação monetária ainda está duplicada nos dois programas.
- Não existe banco de dados.
- Não existe API.
- Não existe interface web.
- Não existe autenticação real.
- Não existe integração com sistemas bancários.
- Não foi utilizado ambiente mainframe.

## Evolução planejada

O projeto será expandido gradualmente para uma aplicação
completa de estudo.

| Componente | Tecnologia |
|---|---|
| Motor de conciliação | COBOL |
| Banco de dados | PostgreSQL |
| Backend | Java |
| Backend alternativo | C# com .NET |
| Interface web | Angular |
| Interface alternativa | Vue |
| Interface alternativa | React |

Primeiro será concluído o módulo COBOL.

Depois serão adicionados banco de dados, backend e interface web.

As alternativas em Java, .NET, Angular, Vue e React fazem parte
do escopo planejado de aprendizado.

## Funcionalidades futuras

- Autenticação.
- Separação dos dados por usuário.
- Envio de arquivos.
- Execução da conciliação.
- Histórico de execuções.
- Visualização de detalhes.
- Totais e indicadores.
- Download de relatórios.
- Integração do módulo COBOL com aplicações externas.

## Autor

Bruno Ramos Lopes.

Projeto educacional com dados fictícios, desenvolvido para
aprendizado e portfólio.

Não representa experiência profissional em sistemas bancários
nem execução em ambiente mainframe.

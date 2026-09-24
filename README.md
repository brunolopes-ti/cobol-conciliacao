# Conciliação de pagamentos em COBOL

Projeto de aprendizado e portfólio para comparar cobranças e
pagamentos, identificar divergências e produzir relatórios.

O motor utiliza GnuCOBOL no Ubuntu. O projeto também possui
scripts PostgreSQL para estrutura, dados de teste, consultas,
restrições e validação dos resultados.

O código COBOL não foi executado em ambiente mainframe.
Os dados utilizados são fictícios.

## Estado atual

| Componente | Estado |
|---|---|
| Conferência interativa | Implementada |
| Leitura e validação de arquivo | Implementada |
| Validação monetária compartilhada | Implementada |
| Conciliação entre dois arquivos | Implementada |
| Tratamento de pagamentos recebidos duplicados | Implementado |
| Resumo financeiro, relatório TXT e resultado TSV v1 | Implementados |
| Caminhos por argumentos de terminal | Implementados |
| Proteções adicionais de entrada e relatório | Implementadas |
| Testes automatizados COBOL | 9 suítes aprovadas |
| Estrutura, views e restrições PostgreSQL | Implementadas e validadas |
| Integração direta entre banco e COBOL | Pendente |
| Backend Java | Planejado |
| Backend .NET | Planejado |
| Interface Angular | Planejada |
| Interfaces Vue e React | Planejadas |

O banco e o motor COBOL ainda funcionam separadamente.

A aplicação web ainda não foi implementada.

---

## Programas COBOL

| Arquivo | Responsabilidade |
|---|---|
| `ola.cob` | Conferência interativa de um pagamento |
| `leitor.cob` | Leitura e validação dos pagamentos esperados |
| `conciliacao.cob` | Comparação dos arquivos, classificação, totais e relatório |
| `validar-monetario.cob` | Validação monetária compartilhada |

Os três programas principais utilizam o mesmo subprograma
de validação monetária.

O projeto também utiliza pequenas rotinas auxiliares em C para
fortalecer operações que dependem do sistema operacional.

| Arquivo | Responsabilidade |
|---|---|
| `entrada-segura.c` | Apoio à leitura segura de argumentos, arquivos e identificadores |
| `relatorio-seguro.c` | Geração temporária e publicação coordenada de TXT e TSV |

---

## Conferência interativa

O programa `ola.cob`:

- Solicita o nome ou login do operador.
- Rejeita identificação vazia ou composta apenas por espaços.
- Solicita os valores esperado e recebido.
- Permite novas tentativas após entradas inválidas.
- Trata o encerramento da entrada antes dos campos obrigatórios.
- Calcula e apresenta a diferença.
- Classifica o pagamento como conferido, acima ou abaixo do esperado.

O nome do operador é apenas informativo.

Não existe autenticação.

---

## Leitor

O programa `leitor.cob` lê:

```text
dados/esperados.csv
```

Ele:

- valida a estrutura das linhas;
- valida valores monetários;
- informa erros por linha;
- continua analisando os registros seguintes quando aplicável;
- apresenta totais de registros lidos, válidos e inválidos;
- rejeita arquivos vazios;
- identifica entradas que ultrapassam os limites estabelecidos.

A validação monetária é feita pelo mesmo subprograma
`validar-monetario.cob` utilizado pelos demais programas.

---

## Motor de conciliação

O programa `conciliacao.cob`:

- Carrega pagamentos esperados e recebidos.
- Rejeita arquivos vazios.
- Valida estrutura e valores monetários.
- Valida identificadores.
- Armazena até 1000 registros por arquivo.
- Compara pagamentos pelo identificador independentemente da ordem.
- Identifica valores iguais, acima e abaixo do esperado.
- Identifica cobranças sem recebimento.
- Identifica recebimentos sem previsão.
- Identifica pagamentos recebidos duplicados.
- Apresenta contagens e totais.
- Calcula o saldo global.
- Gera relatório TXT.
- Permite caminhos personalizados por argumentos.
- Utiliza rotinas auxiliares para proteção das operações de arquivo.

O carregamento é interrompido quando encontra uma entrada inválida.

---

## Formato dos arquivos

Os arquivos não possuem cabeçalho.

Cada linha deve conter exatamente um ponto e vírgula:

```text
identificador;valor
```

Exemplo de `dados/esperados.csv`:

```text
P001;100.50
P002;200.00
P003;75.25
```

Exemplo de `dados/recebidos.csv`:

```text
P003;75.25
P001;90.00
P004;50.00
```

Identificador e valor precisam estar preenchidos.

A comparação dos identificadores diferencia letras maiúsculas
e minúsculas.

Não há suporte a campos CSV entre aspas contendo ponto e vírgula.

---

## Validação monetária

As regras compartilhadas estão implementadas em
`validar-monetario.cob`.

Regras:

- Valores entre `0` e `99999.99`, inclusive.
- Inteiros são aceitos.
- Uma ou duas casas decimais são aceitas.
- O separador decimal é o ponto.
- Zeros à esquerda são permitidos.
- Espaços externos tratados conforme o contrato de entrada.
- Sinais não são permitidos.
- Vírgulas não são permitidas.
- Letras não são permitidas.
- Espaços internos não são permitidos.
- Múltiplos pontos são rejeitados.
- Quando existe ponto decimal, são necessários dígitos antes e depois dele.
- Mais de duas casas decimais são rejeitadas.

Exemplos:

| Entrada | Resultado |
|---|---|
| `0` | Aceita |
| `100` | Aceita |
| `100.5` | Aceita |
| `100.50` | Aceita |
| `00100.50` | Aceita |
| `99999.99` | Aceita |
| `abc` | Rejeitada |
| `+100.50` | Rejeitada |
| `-1` | Rejeitada |
| `100,50` | Rejeitada |
| `1 00.50` | Rejeitada |
| `.50` | Rejeitada |
| `100.` | Rejeitada |
| `100.509` | Rejeitada |
| `100000` | Rejeitada |

### Contrato do subprograma

Os campos são passados por `CALL ... USING` nesta ordem:

| Campo | Definição COBOL | Finalidade |
|---|---|---|
| `entrada-validacao` | `PIC X(256)` | Texto recebido |
| `validacao-ok` | `PIC 9` | `1` para válido; `0` para inválido |
| `valor-validado` | `PIC 9(5)V99` | Valor convertido |
| `mensagem-erro` | `PIC X(80)` | Motivo da rejeição |

O subprograma:

- reinicializa as saídas a cada chamada;
- valida antes da conversão;
- não abre arquivos;
- não lê teclado;
- não exibe mensagens diretamente;
- retorna ao chamador com `GOBACK`.

---

## Regras da conciliação COBOL

A diferença básica é calculada por:

```text
Diferença = valor recebido - valor esperado
```

### Classificações

| Situação | Classificação |
|---|---|
| Mesmo identificador e valores iguais | Conferido |
| Recebido maior que esperado | Acima do esperado |
| Recebido menor que esperado | Abaixo do esperado |
| Identificador apenas nos esperados | Sem recebimento |
| Identificador apenas nos recebidos | Sem previsão |
| Mais de um recebimento para o mesmo identificador esperado | Duplicado |

### Pagamentos duplicados

Identificadores duplicados no arquivo de valores esperados são
considerados entrada inválida.

Pagamentos recebidos podem possuir mais de uma ocorrência para
o mesmo identificador.

Nesse caso:

- o primeiro recebimento encontrado é tratado como pagamento principal;
- a cobrança é classificada como `duplicado`;
- os recebimentos adicionais do mesmo identificador também são
  reconhecidos como pertencentes àquela cobrança;
- esses recebimentos adicionais não são classificados como
  `sem previsão`;
- o total recebido continua considerando todos os registros recebidos.

Essa política é uma regra didática definida para esta versão
do projeto.

---

## Resumo da conciliação

O relatório apresenta contadores semelhantes a:

```text
Resumo da conciliacao:
Conferidos: 1
Acima do esperado: 0
Abaixo do esperado: 1
Duplicados: 0
Sem recebimento: 1
Sem previsao: 1
```

Também são exibidos:

```text
Total esperado
Total recebido
Saldo global
```

O saldo global é:

```text
Saldo global = total recebido - total esperado
```

Um saldo global igual a zero não significa necessariamente que
todos os pagamentos estejam corretos.

Valores acima e abaixo do esperado podem se compensar
financeiramente.

---

## Limites e proteção das entradas

A versão atual possui validações adicionais de entrada.

Entre os casos cobertos estão:

- argumentos acima do limite;
- caminhos vazios;
- caminhos terminados incorretamente;
- linhas acima do limite suportado;
- entradas inválidas;
- caracteres de controle;
- entradas de texto inválidas;
- identificadores fora do contrato estabelecido;
- proteção contra uso inadequado dos arquivos de entrada e saída.

As validações foram exercitadas por uma suíte automatizada
específica de limites.

---

## Ambiente utilizado

- Ubuntu 24.04 LTS em VirtualBox.
- GnuCOBOL 3.1.2.
- Bash.
- GCC.
- Git.
- GitHub.
- VS Code / terminal.
- Acesso ao Ubuntu por SSH a partir do Windows.
- PostgreSQL 18 no Windows.
- Cliente `psql` no Ubuntu.

A comunicação do Ubuntu com o PostgreSQL instalado no Windows
foi testada com autenticação.

---

## Compilação e execução

Execute os comandos a partir da raiz do projeto.

### Conferência interativa

```bash
cobc -x -free -o ola \
    ola.cob \
    validar-monetario.cob \
    entrada-segura.c
```

Execute:

```bash
./ola
```

### Leitor

```bash
cobc -x -free -o leitor \
    leitor.cob \
    validar-monetario.cob \
    entrada-segura.c
```

Execute:

```bash
./leitor
```

### Conciliação

```bash
cobc -x -free -o conciliacao \
    conciliacao.cob \
    validar-monetario.cob \
    entrada-segura.c \
    relatorio-seguro.c
```

Execute:

```bash
./conciliacao
```

Sem argumentos, são utilizados:

| Finalidade | Caminho |
|---|---|
| Valores esperados | `dados/esperados.csv` |
| Valores recebidos | `dados/recebidos.csv` |
| Relatório | `relatorio.txt` |
| Resultado estruturado | `resultado.tsv` |

Também é possível informar os quatro caminhos:

```bash
./conciliacao \
    "dados/esperados.csv" \
    "dados/recebidos.csv" \
    "relatorio.txt" \
    "resultado.tsv"
```

A ordem é:

```text
esperados recebidos relatorio resultado
```

São aceitos zero ou quatro argumentos.

Caminhos contendo espaços devem ser colocados entre aspas.

Os caminhos relativos são interpretados a partir da pasta
onde o programa é executado.

---

## Opções do compilador

| Opção | Significado |
|---|---|
| `-x` | Gera um executável |
| `-free` | Utiliza formato livre de código COBOL |
| `-o` | Define o nome do executável |

Após modificar código COBOL ou as rotinas auxiliares utilizadas
por um executável, ele deve ser recompilado.

Alterações somente em arquivos CSV ou documentação não exigem
recompilação.

---

## Resultado do exemplo

Com os arquivos padrão do projeto, a saída inclui:

```text
Carregamento dos pagamentos.
Conferencia dos pagamentos esperados:
Pagamento: P001 | Esperado: 100.50 | Recebido: 90.00 | Diferenca: -10.50 | Status: abaixo do esperado
Pagamento: P002 | Status: sem recebimento
Pagamento: P003 | Esperado: 75.25 | Recebido: 75.25 | Diferenca: +0.00 | Status: conferido
Recebimentos sem previsao:
Pagamento: P004 | Recebido: 50.00 | Status: sem previsao
Resumo da conciliacao:
Conferidos: 1
Acima do esperado: 0
Abaixo do esperado: 1
Duplicados: 0
Sem recebimento: 1
Sem previsao: 1
Total esperado: 375.75
Total recebido: 215.25
Saldo global: -160.50
Conferencia concluida.
```

---

## Resultado estruturado

O arquivo `resultado.tsv` usa UTF-8 sem BOM, TAB entre campos e LF entre
linhas. O formato versão 1 possui:

- `VERSAO`: 2 campos, com versão `1`.
- `DETALHE`: 7 campos (tipo, identificador, esperado, recebido, diferença,
  status e quantidade de recebimentos).
- `RESUMO`: 10 campos; é obrigatoriamente a última linha.

Cobranças com vários pagamentos usam o primeiro como principal e
classificam o detalhe como `DUPLICADO`. Cada pagamento sem cobrança gera
seu próprio `SEM_PREVISAO`, inclusive quando o identificador se repete.
Campos monetários não aplicáveis ficam vazios.

O contrato completo está em [docs/contrato-integracao.md](docs/contrato-integracao.md).
O backend Java ainda não foi implementado.

## Publicação das saídas

As duas saídas são gravadas em temporários, sincronizadas e fechadas
antes de qualquer publicação. Caminhos equivalentes para o mesmo destino
são rejeitados mesmo quando o arquivo ainda não existe.

A publicação é coordenada: uma reserva do relatório anterior permite
restaurá-lo se a publicação do TSV falhar. Se não havia relatório, o novo
é removido nessa recuperação. O TSV anterior permanece intacto.

Isso não constitui uma troca atômica do par: os arquivos são substituídos
em sequência. Queda de energia, encerramento forçado e alterações
concorrentes não têm recuperação automática garantida. O backend deve
usar uma pasta exclusiva por execução e consumir as saídas somente após
o processo terminar com código 0 e a validação do TSV ser aprovada.

Se a própria recuperação falhar, o programa retorna 1 e informa o nome
da reserva `.conciliacao-*.bak`, mantida na pasta do relatório para
recuperação manual. Nenhum sucesso é anunciado. Uma falha na limpeza da
reserva após publicar ambas as saídas também retorna 1.

## Relatório e códigos de saída

Os arquivos de entrada são validados antes da publicação
do relatório final.

O projeto utiliza uma rotina auxiliar específica para as operações
do relatório.

São tratadas falhas nas etapas necessárias para geração
e publicação da saída.

| Código | Significado |
|---|---|
| `0` | Processamento concluído |
| `1` | Entrada inválida ou falha de operação |
| `2` | Uso incorreto dos argumentos da conciliação |

Divergências financeiras são resultados do processamento.

Elas não tornam o código de saída diferente de zero.

Para consultar o código depois da execução:

```bash
echo $?
```

---

# Testes automatizados

As suítes usam Bash, GnuCOBOL, GCC e Python 3 no Ubuntu.

Execute todas as suítes com:

```bash
bash testes/testar-tudo.sh
```

Os testes compilam os programas necessários em áreas temporárias.

Não é necessário compilar manualmente antes da execução
das suítes.

## Suítes atuais

O projeto possui nove suítes automatizadas:

| Suíte | Finalidade |
|---|---|
| Leitor | Validação da leitura de arquivos |
| Conferência interativa | Entrada e cálculo interativo |
| Conciliação | Regras de comparação entre arquivos |
| Relatório | Conteúdo e comportamento do relatório |
| Resultado estruturado | Contrato TSV, detalhes e resumo |
| Publicação das saídas | Colisões, falhas e recuperação do par TXT/TSV |
| Argumentos | Caminhos e argumentos de terminal |
| Limites das entradas | Limites e entradas inválidas |
| Proteção de arquivos | Segurança dos arquivos de entrada e saída |

Resultado confirmado localmente:

```text
Suites aprovadas: 9
Suites reprovadas: 0
VERIFICACAO COMPLETA: PASSOU
```

---

## Cobertura atual dos testes

Os testes incluem cenários para:

- Arquivos válidos.
- Arquivos mistos.
- Arquivos vazios.
- Arquivos ausentes.
- Registros inválidos.
- Valores monetários inválidos.
- Encerramento da entrada interativa.
- Conferência de pagamento válido.
- Identificadores em ordens diferentes.
- Valores iguais.
- Valores acima do esperado.
- Valores abaixo do esperado.
- Cobranças sem recebimento.
- Recebimentos sem previsão.
- Duplicidade nos valores esperados.
- Duplicidade nos pagamentos recebidos.
- Classificação de recebimentos duplicados.
- Capacidade de 1000 registros.
- Rejeição de excesso de capacidade.
- Valores monetários próximos dos limites.
- Conteúdo completo do relatório.
- Preservação do comportamento esperado diante de falhas.
- Caminhos personalizados.
- Caminhos contendo espaços.
- Quantidade incorreta de argumentos.
- Caminhos vazios.
- Caminhos acima do limite.
- Limites de entradas.
- Proteção dos arquivos utilizados pelo processamento.

As suítes verificam códigos de saída e resultados esperados.

Os testes não representam todas as combinações possíveis,
mas cobrem os principais fluxos e casos de erro atualmente
previstos para o projeto.

O GitHub Actions ainda não foi configurado.

---

# PostgreSQL

O projeto possui uma implementação relacional das regras
de conciliação.

O ambiente de desenvolvimento utiliza um usuário próprio:

```text
conciliacao_app
```

e o banco:

```text
conciliacao_pagamentos
```

Também foi utilizado um banco separado para testes de
reprodutibilidade.

---

## Tabelas

| Tabela | Finalidade |
|---|---|
| `cobrancas` | Identificadores e valores esperados |
| `pagamentos` | Identificadores e valores efetivamente pagos |

As cobranças possuem identificador único.

A tabela de pagamentos permite múltiplos registros para
o mesmo identificador.

Isso permite representar e analisar pagamentos duplicados.

Também é possível representar pagamento sem cobrança
correspondente para que o caso possa ser detectado
pela conciliação.

---

## Contrato de dados PostgreSQL

As restrições do banco foram fortalecidas para aproximar
o comportamento do PostgreSQL das regras utilizadas pelo
processamento COBOL.

O conjunto de scripts inclui validações adicionais para
entradas, identificadores e valores monetários.

Os casos de restrição possuem testes próprios.

---

## Views

### `vw_conciliacao_completa`

Realiza a classificação principal dos registros.

Status implementados:

- `CORRETO`
- `DIVERGENTE`
- `DUPLICADO`
- `COBRANCA INEXISTENTE`
- `SEM PAGAMENTO`

Na política atual de pagamentos repetidos, o primeiro pagamento
de cada identificador é considerado o pagamento principal para
efeito da análise.

Pagamentos posteriores são tratados como ocorrências duplicadas.

### `vw_resumo_financeiro`

Produz métricas financeiras consolidadas.

Entre as métricas estão:

- total esperado;
- total recebido bruto;
- total duplicado;
- total relacionado a cobrança inexistente;
- total pago válido;
- valor pendente;
- valor excedente;
- saldo líquido.

Pendência e excedente são tratados separadamente para evitar
que um pagamento acima do esperado em uma cobrança esconda
uma dívida existente em outra.

---

## Cenário SQL utilizado

Os dados fictícios incluem cobranças como:

```text
COB001
COB002
COB003
COB004
```

e um pagamento associado a:

```text
COB999
```

sem cobrança correspondente.

O cenário contempla:

- pagamento correto;
- pagamento divergente;
- pagamento duplicado;
- cobrança sem pagamento;
- pagamento sem cobrança.

Para o conjunto principal de dados utilizado nos testes:

| Métrica | Valor |
|---|---:|
| Total esperado | 465.75 |
| Total recebido bruto | 506.25 |
| Total duplicado | 100.50 |
| Total de cobrança inexistente | 50.00 |
| Total pago válido | 355.75 |
| Valor pendente | 110.00 |
| Valor excedente | 0.00 |
| Saldo líquido | -110.00 |

Os dados SQL utilizados para teste não são os mesmos arquivos
CSV usados no exemplo COBOL.

---

## Scripts SQL

| Arquivo | Finalidade |
|---|---|
| `sql/01-estrutura.sql` | Criação da estrutura principal |
| `sql/02-dados-teste.sql` | Carga dos dados fictícios |
| `sql/03-views.sql` | Criação das views de conciliação e resumo |
| `sql/04-validacao.sql` | Validação do cenário esperado |
| `sql/05-restricoes.sql` | Restrições adicionais do contrato de dados |
| `sql/06-testar-restricoes.sql` | Testes das restrições do banco |

Os scripts foram exercitados em ambiente PostgreSQL de teste.

As verificações incluem tanto o cenário válido quanto entradas
que devem ser rejeitadas.

---

## Alinhamento entre COBOL e PostgreSQL

O tratamento de pagamentos recebidos duplicados foi alinhado
entre as duas implementações.

A política adotada é:

```text
primeiro recebimento = principal
recebimentos adicionais = duplicados
```

No COBOL, pagamentos repetidos deixam de invalidar todo o arquivo
de recebidos.

A ocorrência é processada e classificada como duplicada.

Identificadores duplicados no arquivo de valores esperados
continuam sendo rejeitados.

Ainda não existe conexão direta entre o código COBOL e
o PostgreSQL.

Essa integração será realizada por uma camada de backend.

---

# Organização dos arquivos

| Caminho | Finalidade |
|---|---|
| `ola.cob` | Programa interativo |
| `leitor.cob` | Leitor de pagamentos esperados |
| `conciliacao.cob` | Motor de conciliação |
| `validar-monetario.cob` | Subprograma monetário compartilhado |
| `entrada-segura.c` | Rotinas auxiliares de entrada |
| `relatorio-seguro.c` | Rotinas auxiliares do relatório |
| `dados/esperados.csv` | Valores esperados de exemplo |
| `dados/recebidos.csv` | Valores recebidos de exemplo |
| `testes/cenarios/` | Dados auxiliares de teste |
| `testes/testar-leitor.sh` | Suíte do leitor |
| `testes/testar-ola.sh` | Suíte interativa |
| `testes/testar-conciliacao.sh` | Suíte da conciliação |
| `testes/testar-relatorio.sh` | Suíte do relatório |
| `testes/testar-argumentos.sh` | Suíte dos argumentos |
| `testes/testar-limites.sh` | Suíte de limites das entradas |
| `testes/testar-protecao-arquivos.sh` | Suíte de proteção dos arquivos |
| `testes/testar-resultado.sh` | Suíte do contrato TSV |
| `testes/testar-publicacao-saidas.sh` | Suíte da publicação coordenada |
| `testes/testar-tudo.sh` | Execução conjunta das suítes |
| `sql/01-estrutura.sql` | Estrutura PostgreSQL |
| `sql/02-dados-teste.sql` | Massa de teste SQL |
| `sql/03-views.sql` | Views SQL |
| `sql/04-validacao.sql` | Validação do cenário SQL |
| `sql/05-restricoes.sql` | Restrições adicionais |
| `sql/06-testar-restricoes.sql` | Testes das restrições |
| `.gitignore` | Arquivos locais que não devem ser versionados |
| `README.md` | Documentação do projeto |

Os executáveis gerados localmente não são versionados.

O relatório padrão da raiz também não é versionado.

---

# Limitações atuais

O projeto é educacional e de portfólio.

As principais limitações atuais são:

- Até 1000 registros por arquivo no motor COBOL.
- Os arquivos utilizados pela conciliação precisam possuir registros.
- A busca COBOL por correspondências ainda é linear.
- A comparação de identificadores diferencia maiúsculas e minúsculas.
- Não existe parser CSV completo com suporte a campos complexos entre aspas.
- A política de considerar o primeiro recebimento como principal é uma regra didática.
- O motor gera TXT para leitura humana e TSV v1 para integração; o consumidor Java ainda está pendente.
- COBOL e PostgreSQL ainda não estão conectados diretamente.
- Não existe API.
- Não existe interface web.
- Não existe autenticação.
- Não existe isolamento de dados por usuário.
- Não existe integração com sistemas bancários reais.
- O projeto não está preparado para uso em produção.
- O GitHub Actions ainda não foi configurado.

---

# Próximas etapas

As próximas etapas previstas são:

1. Consolidar o contrato de integração entre COBOL, PostgreSQL e backend.
2. Implementar o backend Java com Spring Boot.
3. Conectar o backend ao PostgreSQL.
4. Integrar o backend ao processamento COBOL.
5. Criar endpoints REST para cobranças, pagamentos, conciliação e resumo.
6. Implementar autenticação e separação de dados por usuário.
7. Construir a interface Angular.
8. Adicionar Docker ao ambiente da aplicação.
9. Configurar integração contínua.
10. Implementar posteriormente o backend alternativo em .NET.
11. Implementar posteriormente as interfaces alternativas em Vue e React.

---

# Evolução planejada

O projeto foi planejado como exercício de evolução incremental
de uma aplicação.

| Camada | Tecnologia |
|---|---|
| Processamento de conciliação | COBOL |
| Banco de dados | PostgreSQL |
| Backend principal | Java / Spring Boot |
| Backend alternativo | C# / .NET |
| Interface principal | Angular |
| Interface alternativa | Vue |
| Interface alternativa | React |
| Conteinerização | Docker |

A estratégia é primeiro construir uma combinação funcional
de ponta a ponta.

Depois serão implementadas as tecnologias alternativas.

Os backends deverão seguir um contrato compatível de API.

As interfaces deverão consumir o mesmo modelo funcional.

---

## Funcionalidades web planejadas

Entre as funcionalidades futuras estão:

- Autenticação.
- Cadastro e consulta de cobranças.
- Cadastro e consulta de pagamentos.
- Envio de arquivos para conciliação.
- Histórico de execuções.
- Consulta de resultados.
- Consulta de totais financeiros.
- Identificação de divergências.
- Identificação de duplicidades.
- Download de relatórios.

---

# Mainframe

O código atual utiliza:

```text
GnuCOBOL
Ubuntu
```

Ele não representa experiência prática em ambiente mainframe.

Tecnologias como:

```text
z/OS
JCL
Db2
CICS
datasets
jobs batch
```

fazem parte de uma trilha de estudo futura e não são apresentadas
como experiência já adquirida neste projeto.

---

# Autor

Bruno Ramos Lopes

Projeto educacional e de portfólio com dados fictícios.

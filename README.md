# Conciliação de pagamentos em COBOL

Projeto de aprendizado e portfólio para comparar cobranças e
pagamentos, identificar divergências e produzir relatórios.

O motor utiliza GnuCOBOL no Ubuntu. O projeto também possui
scripts PostgreSQL para estrutura, dados de teste, consultas
de conciliação e validação dos resultados.

O código COBOL não foi executado em ambiente mainframe.
Os dados utilizados são fictícios.

## Estado atual

| Componente | Estado |
|---|---|
| Conferência interativa | Implementada |
| Leitura e validação de arquivo | Implementada |
| Validação monetária compartilhada | Implementada |
| Conciliação entre dois arquivos | Implementada |
| Resumo financeiro e relatório TXT | Implementados |
| Caminhos por argumentos de terminal | Implementados |
| Testes automatizados COBOL | 28 cenários aprovados |
| Estrutura e views PostgreSQL | Implementadas e validadas em banco separado |
| Integração entre banco e COBOL | Pendente |
| Backends Java e .NET | Planejados |
| Interfaces Angular, Vue e React | Planejadas |

O banco e o motor COBOL ainda funcionam separadamente.
A aplicação web ainda não foi implementada.

## Programas COBOL

| Arquivo | Responsabilidade |
|---|---|
| `ola.cob` | Conferência interativa de um pagamento |
| `leitor.cob` | Leitura e validação dos pagamentos esperados |
| `conciliacao.cob` | Comparação dos arquivos, totais e relatório |
| `validar-monetario.cob` | Validação monetária compartilhada |

Os três programas principais utilizam o mesmo subprograma
de validação monetária.

### Conferência interativa

O programa `ola.cob`:

- Solicita o nome ou login do operador.
- Rejeita identificação vazia ou composta apenas por espaços.
- Solicita os valores esperado e recebido.
- Permite novas tentativas após entradas inválidas.
- Trata o encerramento da entrada antes dos campos obrigatórios.
- Calcula e apresenta a diferença.
- Classifica o pagamento como conferido, acima ou abaixo do esperado.

O nome do operador é informativo. Não existe autenticação.

### Leitor

O programa `leitor.cob` lê `dados/esperados.csv`.

Ele informa erros por linha, continua analisando os registros
seguintes e apresenta os totais de registros lidos, válidos
e inválidos.

O leitor não verifica duplicidade de identificadores.
Essa verificação está no programa `conciliacao.cob`.

### Motor de conciliação

O programa `conciliacao.cob`:

- Carrega pagamentos esperados e recebidos.
- Rejeita arquivos vazios.
- Valida estrutura e valores monetários.
- Rejeita identificadores duplicados dentro de cada arquivo.
- Armazena até 1000 registros por arquivo.
- Compara os pagamentos pelo identificador, independentemente da ordem.
- Identifica valores iguais, acima e abaixo do esperado.
- Identifica cobranças sem recebimento.
- Identifica recebimentos sem previsão.
- Apresenta contagens, totais e saldo global.
- Grava um relatório TXT.

O carregamento é interrompido quando encontra uma entrada inválida.

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
Espaços nas extremidades do identificador são removidos.
A comparação dos identificadores distingue letras maiúsculas
e minúsculas.

Não há suporte a campos entre aspas contendo ponto e vírgula.

## Validação monetária

Regras compartilhadas em `validar-monetario.cob`:

- Valores entre `0` e `99999.99`, inclusive.
- Inteiros ou números com uma ou duas casas decimais.
- Ponto como separador decimal.
- Zeros à esquerda permitidos.
- Espaços nas extremidades permitidos.
- Sinais, vírgulas, letras e espaços internos rejeitados.
- Múltiplos pontos rejeitados.
- Quando existe ponto, são necessários dígitos antes e depois dele.
- Mais de duas casas decimais são rejeitadas.

| Entrada | Resultado |
|---|---|
| `0` | Aceita |
| `100` | Aceita |
| `100.5` | Aceita |
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
| `100.509` | Rejeitada |
| `100000` | Rejeitada |

### Contrato do subprograma

Os campos são passados por `CALL ... USING`, nesta ordem:

| Campo | Definição COBOL | Finalidade |
|---|---|---|
| `entrada-validacao` | `PIC X(256)` | Texto recebido |
| `validacao-ok` | `PIC 9` | `1` para válido; `0` para inválido |
| `valor-validado` | `PIC 9(5)V99` | Valor convertido |
| `mensagem-erro` | `PIC X(80)` | Motivo da rejeição |

O subprograma reinicializa as saídas a cada chamada, valida antes
da conversão e retorna ao chamador com `GOBACK`.

Ele não lê teclado, abre arquivos ou exibe mensagens.
Não recupera conteúdo truncado antes da chamada.

## Regras da conciliação COBOL

```text
Diferença = valor recebido - valor esperado
```

| Situação | Classificação |
|---|---|
| Mesmo identificador e valores iguais | Conferido |
| Recebido maior que esperado | Acima do esperado |
| Recebido menor que esperado | Abaixo do esperado |
| Identificador apenas nos esperados | Sem recebimento |
| Identificador apenas nos recebidos | Sem previsão |

O saldo global considera todos os registros aceitos:

```text
Saldo global = total recebido - total esperado
```

Um saldo global igual a zero não garante que todos os pagamentos
estejam conferidos: diferenças entre identificadores podem se compensar.

## Ambiente utilizado

- Ubuntu 24.04 LTS em VirtualBox.
- GnuCOBOL 3.1.2.
- Bash e utilitários como `diff`, `grep` e `mktemp`.
- Git e GitHub.
- Editor Nano.
- Acesso ao Ubuntu por SSH a partir do Windows.
- PostgreSQL 18.2 no Windows.
- Cliente `psql` 16.15 no Ubuntu.

A conexão do Ubuntu ao PostgreSQL no Windows foi testada
com autenticação.

## Compilação e execução

Execute os comandos a partir da raiz do projeto.

### Conferência interativa

```bash
cobc -x -free -o ola ola.cob validar-monetario.cob
./ola
```

### Leitor

```bash
cobc -x -free -o leitor leitor.cob validar-monetario.cob
./leitor
```

### Conciliação

```bash
cobc -x -free -o conciliacao conciliacao.cob validar-monetario.cob
./conciliacao
```

Sem argumentos, a conciliação utiliza:

| Finalidade | Caminho |
|---|---|
| Valores esperados | `dados/esperados.csv` |
| Valores recebidos | `dados/recebidos.csv` |
| Relatório | `relatorio.txt` |

Também é possível informar os três caminhos:

```bash
./conciliacao "dados/esperados.csv" "dados/recebidos.csv" "relatorio.txt"
```

A ordem é: esperados, recebidos e relatório.

São aceitos zero ou três argumentos. Caminhos com espaços
devem ser colocados entre aspas.

Os caminhos relativos são interpretados a partir da pasta
onde o programa é executado. A pasta de destino do relatório
precisa existir.

### Opções do compilador

| Opção | Significado |
|---|---|
| `-x` | Gera um executável |
| `-free` | Utiliza formato livre de código COBOL |
| `-o` | Define o nome do executável |

O programa principal deve aparecer antes do subprograma
no comando de compilação.

Após modificar código COBOL, recompile os executáveis afetados.
Alterações somente nos dados ou na documentação não exigem recompilação.

Ao alterar `validar-monetario.cob`, recompile os três programas principais.

## Resultado do exemplo

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
Sem recebimento: 1
Sem previsao: 1
Total esperado: 375.75
Total recebido: 215.25
Saldo global: -160.50
Conferencia concluida.
```

O relatório contém os resultados a partir de
`Conferencia dos pagamentos esperados:`.

## Relatório e códigos de saída

Os dois arquivos de entrada são validados antes da abertura
do relatório para escrita.

Uma entrada inválida preserva o relatório anterior.
Uma execução válida substitui o relatório existente.

São verificadas as operações de abertura, escrita e fechamento.
A escrita ainda não é atômica: uma falha durante a gravação
pode deixar um relatório incompleto.

| Código | Significado |
|---|---|
| `0` | Processamento concluído |
| `1` | Entrada inválida ou falha de operação |
| `2` | Uso incorreto dos argumentos da conciliação |

Divergências financeiras são resultados do processamento.
Elas não tornam o código de saída diferente de zero.

Para consultar o código imediatamente após a execução:

```bash
echo $?
```

## Testes automatizados

Execute todas as suítes:

```bash
bash testes/testar-tudo.sh
```

Os scripts compilam os programas em pastas temporárias.
Não é necessário compilar manualmente antes dos testes.

| Suíte | Cenários |
|---|---:|
| Leitor | 5 |
| Conferência interativa | 4 |
| Conciliação | 10 |
| Relatório | 3 |
| Argumentos | 6 |
| **Total** | **28** |

Resultado confirmado na execução local: 28 cenários aprovados,
cinco suítes aprovadas e código de saída `0`.

### Cobertura atual

- Arquivos válidos, mistos, vazios e ausentes.
- Registro acima do limite testado.
- Encerramento da entrada interativa antes dos campos obrigatórios.
- Conferência interativa com valores válidos.
- Identificadores em ordens diferentes.
- Duplicidade nos esperados e nos recebidos.
- Valor inválido nos recebidos.
- Arquivos sem identificadores em comum.
- Valores iguais, acima e abaixo do esperado.
- Capacidade de 1000 registros por arquivo.
- Rejeição de 1001 registros nos recebidos.
- Maior total esperado permitido.
- Conteúdo completo do relatório.
- Preservação do relatório anterior diante de entrada inválida.
- Falha na abertura do relatório.
- Caminhos personalizados contendo espaços.
- Quantidade incorreta de argumentos.
- Caminho vazio ou acima do limite.
- Caminho do relatório textualmente igual a uma entrada.
- Arquivo de entrada personalizado inexistente.

As suítes verificam códigos de saída e resultados esperados.
A suíte interativa verifica linhas específicas; ela não compara
a saída inteira.

Os testes não cobrem todas as combinações possíveis.
Falhas durante escrita e fechamento do relatório ainda não
foram simuladas.

O GitHub Actions ainda não foi configurado.

## PostgreSQL

O ambiente possui um usuário próprio da aplicação,
`conciliacao_app`, e o banco `conciliacao_pagamentos`.

A reprodução dos scripts foi exercitada em um banco separado,
`conciliacao_teste`.

### Tabelas

| Tabela | Finalidade |
|---|---|
| `cobrancas` | Identificadores e valores esperados |
| `pagamentos` | Identificadores de cobrança e valores pagos |

As cobranças possuem identificador único.
Valores negativos são rejeitados.

A tabela de pagamentos permite múltiplos registros para
o mesmo identificador e pagamentos sem cobrança correspondente.
Isso permite identificar esses casos nas consultas.

### Views

| View | Finalidade |
|---|---|
| `vw_conciliacao_completa` | Classificação por identificador |
| `vw_resumo_financeiro` | Métricas financeiras do cenário |

Classificações SQL implementadas:

- `CORRETO`
- `DIVERGENTE`
- `DUPLICADO`
- `COBRANCA INEXISTENTE`
- `SEM PAGAMENTO`

### Scripts reproduzíveis

Execute os scripts nesta ordem em um banco de testes preparado:

| Arquivo | Finalidade |
|---|---|
| `sql/01-estrutura.sql` | Criação das tabelas |
| `sql/02-dados-teste.sql` | Carga dos dados fictícios |
| `sql/03-views.sql` | Criação das views |
| `sql/04-validacao.sql` | Validação dos resultados |

Os quatro scripts foram executados em um banco vazio separado.
Os cinco status e as métricas financeiras foram conferidos.

Valores confirmados para o cenário SQL:

| Métrica | Valor |
|---|---:|
| Total esperado | 465.75 |
| Total recebido bruto | 506.25 |
| Total duplicado | 100.50 |
| Total de cobrança inexistente | 50.00 |
| Total pago válido | 355.75 |
| Valor pendente | 110.00 |

Esses dados de teste são diferentes dos exemplos CSV do COBOL.

### Alinhamento pendente

O COBOL rejeita identificadores duplicados no arquivo.
O SQL armazena pagamentos repetidos e os classifica como duplicados.

As duas implementações ainda não possuem um contrato integrado
de tratamento de duplicidades e resultados.

Não existe conexão direta do código COBOL com o PostgreSQL.

## Organização dos arquivos

| Caminho | Finalidade |
|---|---|
| `ola.cob` | Programa interativo |
| `leitor.cob` | Leitor de registros |
| `conciliacao.cob` | Motor de conciliação |
| `validar-monetario.cob` | Subprograma monetário |
| `dados/esperados.csv` | Exemplo de valores esperados |
| `dados/recebidos.csv` | Exemplo de valores recebidos |
| `testes/cenarios/` | Arquivos de teste do leitor |
| `testes/testar-leitor.sh` | Suíte do leitor |
| `testes/testar-ola.sh` | Suíte interativa |
| `testes/testar-conciliacao.sh` | Suíte da conciliação |
| `testes/testar-relatorio.sh` | Suíte do relatório |
| `testes/testar-argumentos.sh` | Suíte dos argumentos |
| `testes/testar-tudo.sh` | Execução conjunta das suítes |
| `sql/` | Estrutura, dados, views e validação PostgreSQL |
| `.gitignore` | Exclusão dos executáveis e do relatório padrão |
| `README.md` | Documentação |

Os executáveis `ola`, `leitor` e `conciliacao`, além do
`relatorio.txt` da raiz, são gerados localmente e não são versionados.

Relatórios com outros nomes não são automaticamente ignorados.

## Limitações atuais

- Até 1000 registros por arquivo na conciliação.
- Os dois arquivos da conciliação precisam conter registros.
- Identificadores possuem validação de preenchimento, mas ainda
  não têm uma regra estrita de caracteres permitidos.
- A comparação de identificadores diferencia maiúsculas e minúsculas.
- A busca por correspondências é linear.
- O campo de leitura de arquivo possui 1024 posições.
- A verificação de 256 posições desconsidera espaços finais;
  ela não garante detectar todo excesso de tamanho físico da linha.
- Campos interativos de 40 posições ainda podem truncar entradas maiores.
- Caminhos têm limite de 256 posições e não suportam espaços finais.
- A proteção contra sobrescrever uma entrada compara apenas o texto
  dos caminhos. Caminhos equivalentes e links simbólicos ainda
  não são identificados.
- A gravação do relatório não é atômica.
- Os resultados do motor são textuais.
- Banco e COBOL ainda não estão integrados.
- Não há autenticação, isolamento por usuário, API ou interface web.
- Não há integração com sistemas bancários.
- O projeto ainda não está preparado para uso em produção.

## Próximas etapas

- Alinhar as regras entre o banco e o motor COBOL.
- Definir o contrato de integração.
- Implementar o backend Java e sua integração com PostgreSQL e COBOL.
- Implementar autenticação e separação dos dados por usuário.
- Construir a interface Angular.
- Implementar o backend .NET e as interfaces Vue e React.
- Ampliar os testes e configurar integração contínua.
- Tratar as limitações de entrada e geração de relatório.

## Evolução planejada

Todos os componentes abaixo fazem parte do escopo de estudo:

| Componente | Tecnologia |
|---|---|
| Motor de conciliação | COBOL |
| Banco de dados | PostgreSQL |
| Backend | Java |
| Backend alternativo | C# com .NET |
| Interface web | Angular |
| Interface alternativa | Vue |
| Interface alternativa | React |

Primeiro será construída uma combinação funcional de ponta a ponta.
Depois serão implementadas as alternativas.

Os backends deverão seguir o mesmo contrato de API.
As três interfaces deverão ser compatíveis com ambos.

Funcionalidades web planejadas:

- Autenticação.
- Envio de arquivos para conciliação.
- Histórico de execuções.
- Consulta de resultados e totais.
- Download de relatórios.

## Autor

Bruno Ramos Lopes.

Projeto educacional e de portfólio com dados fictícios.

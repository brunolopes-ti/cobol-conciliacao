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

A comparação entre arquivos de pagamentos esperados e recebidos
ainda não foi implementada.

## Conferência interativa

O programa `ola.cob`:

- Solicita o nome ou login do operador.
- Rejeita identificação vazia ou composta apenas por espaços.
- Solicita os valores esperado e recebido.
- Valida as entradas monetárias.
- Permite nova tentativa após uma entrada inválida.
- Calcula a diferença entre recebido e esperado.
- Classifica o pagamento como conferido, abaixo ou acima do esperado.
- Exibe valores com duas casas decimais, sem zeros desnecessários à esquerda.

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

O leitor informa o número da linha com erro, continua processando
os registros seguintes e apresenta os totais de registros lidos,
válidos e inválidos.

Uma linha é contabilizada como válida somente depois de passar
pela validação da estrutura e pela validação monetária.

Os identificadores ainda não possuem verificação de duplicidade
nem uma regra específica de formato.

### Validação monetária

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

A validação examina o texto armazenado no campo.
Entradas acima da capacidade dos campos ainda precisam
de tratamento específico.

Atualmente, as rotinas monetárias estão presentes em cada
programa. Ainda não existe um módulo compartilhado entre
os dois executáveis.

## Organização do leitor

| Parágrafo | Responsabilidade |
|---|---|
| `validar-registro` | Verificar separador e campos preenchidos |
| `validar-formato` | Examinar caracteres e contar casas decimais |
| `validar-valor` | Coordenar a validação monetária e converter o valor |
| `mostrar-registro` | Apresentar identificador e valor formatado |

O fluxo principal abre o arquivo, lê cada registro, solicita
as validações, contabiliza os resultados e fecha o arquivo.

A validação monetária só ocorre quando a estrutura está correta.

Os campos de trabalho são reinicializados a cada validação,
evitando que resultados anteriores interfiram no registro seguinte.

## Ambiente utilizado

- Ubuntu 24.04 LTS em máquina virtual no VirtualBox.
- GnuCOBOL 3.1.2.
- Git e GitHub.
- Editor Nano.
- Acesso ao Ubuntu por SSH a partir do Windows.

## Arquivos

| Arquivo | Finalidade |
|---|---|
| `ola.cob` | Código da conferência interativa |
| `leitor.cob` | Código da leitura e validação do arquivo |
| `dados/esperados.csv` | Dados fictícios de exemplo |
| `.gitignore` | Regras para ignorar os executáveis |
| `README.md` | Documentação do projeto |

Os executáveis `ola` e `leitor` são gerados localmente e
não são versionados.

## Como compilar e executar

Execute os comandos a partir da pasta raiz do projeto.

### Conferência interativa

Compile:

```bash
cobc -x -free -o ola ola.cob
```

Execute:

```bash
./ola
```

### Leitor de arquivo

Compile:

```bash
cobc -x -free -o leitor leitor.cob
```

Execute:

```bash
./leitor
```

O caminho `dados/esperados.csv` é relativo à pasta de onde
o programa é executado.

Após alterar e salvar um arquivo `.cob`, compile novamente
para atualizar seu executável.

Alterar apenas o CSV ou o README não exige recompilação.

### Opções de compilação

| Opção | Significado |
|---|---|
| `-x` | Gera um executável |
| `-free` | Usa formato livre de código COBOL |
| `-o` | Define o nome do arquivo de saída |

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

O leitor verifica o resultado das operações de abertura,
leitura e fechamento por meio de `FILE STATUS`.

| Código | Significado |
|---|---|
| `00` | Operação realizada com sucesso |
| `10` | Fim do arquivo durante a leitura |
| `35` | Arquivo não encontrado na abertura |

Outros códigos são apresentados como erro de operação.

O fim do arquivo é tratado como encerramento normal da leitura.

### Código de saída

| Código | Significado |
|---|---|
| `0` | Processamento concluído sem registros inválidos |
| `1` | Falha de arquivo ou presença de registros inválidos |

Para consultar o código de saída no terminal, execute
imediatamente depois do programa:

```bash
echo $?
```

## Testes manuais realizados

### Conferência interativa

Foram testados ao longo do desenvolvimento:

- Recebimento abaixo, igual e acima do esperado.
- Diferença calculada como recebido menos esperado.
- Identificação vazia e login com ponto.
- Entradas monetárias inválidas seguidas de entradas válidas.
- Limites monetários e casas decimais.
- Apresentação dos valores sem zeros à esquerda.

### Leitura de arquivo

Foram testados:

- Leitura e separação de três registros.
- Arquivo ausente, com `FILE STATUS 35` e saída `1`.
- Ausência de separador.
- Separador extra.
- Identificador vazio.
- Valor vazio.
- Continuação da leitura após registros inválidos.

### Teste combinado de estrutura e valor

Arquivo utilizado temporariamente:

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

Resultado confirmado:

| Linha | Resultado |
|---|---|
| 1 | Válida: `100.50` |
| 2 | Erro de formato monetário |
| 3 | Erro por excesso de casas decimais |
| 4 | Erro por valor acima do limite |
| 5 | Válida, apresentada como `100.50` |
| 6 | Válida: `0.00` |
| 7 | Válida: `99999.99` |
| 8 | Erro por separador extra |

Totais confirmados: oito registros lidos, quatro válidos,
quatro inválidos e código de saída `1`.

Após restaurar o arquivo de exemplo, uma nova execução
apresentou três registros válidos, nenhum inválido e saída `0`.

Os testes foram executados manualmente.
Ainda não existe uma suíte automatizada nem cobertura exaustiva.
Os cenários anteriores não foram todos repetidos após cada alteração.

## Limitações atuais

- A conferência interativa processa um pagamento por execução.
- O leitor valida somente o arquivo de valores esperados.
- Não existe comparação entre dois arquivos.
- Não existe detecção de identificadores duplicados.
- O leitor não grava relatório de saída.
- Linhas maiores que o campo de 256 posições não possuem
  tratamento explícito de excesso de tamanho.
- Entradas acima da capacidade dos campos e fim da entrada
  padrão ainda precisam de tratamento no programa interativo.
- Um arquivo vazio ainda não é rejeitado.
- Não há autenticação, banco de dados, API ou interface web.
- Não há integração com sistemas bancários.

## Próximas etapas

- Automatizar testes reproduzíveis.
- Tratar limites de entrada e demais casos pendentes.
- Ler pagamentos recebidos.
- Comparar pagamentos por identificador.
- Identificar divergências, ausências e recebimentos inesperados.
- Gerar relatório com resultados e totais.

## Evolução planejada

Todos os componentes abaixo fazem parte do escopo de estudo,
em um único repositório:

| Componente | Tecnologia |
|---|---|
| Motor de conciliação | COBOL |
| Banco de dados | PostgreSQL |
| Backend | Java |
| Backend alternativo | C# com .NET |
| Interface web | Angular |
| Interface alternativa | Vue |
| Interface alternativa | React |

Até o momento, somente a etapa inicial em COBOL foi implementada.

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

Bruno Ramos Lopes.

Projeto educacional com dados fictícios, desenvolvido para
aprendizado e portfólio. Não representa experiência profissional
em sistemas bancários nem execução em mainframe.

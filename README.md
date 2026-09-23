# Conciliação de pagamentos em COBOL

Projeto de aprendizado e portfólio para construir uma aplicação
de conciliação de pagamentos, começando pelo processamento em COBOL.

O objetivo é comparar pagamentos esperados e recebidos,
identificar correspondências, diferenças e ausências.

O projeto utiliza GnuCOBOL no Ubuntu. Não foi executado
em ambiente mainframe.

## Estado atual

| Componente | Responsabilidade |
|---|---|
| `ola.cob` | Conferência interativa de um pagamento |
| `leitor.cob` | Leitura e validação de registros de um arquivo |
| `validar-monetario.cob` | Validação monetária compartilhada |

Os dois programas principais chamam o mesmo subprograma monetário.

Existem nove cenários automatizados:
cinco para o leitor e quatro para a conferência interativa.

A comparação entre arquivos de pagamentos esperados e recebidos
ainda não foi implementada.

## Conferência interativa

O programa `ola.cob`:

- Solicita o nome ou login do operador.
- Rejeita identificação vazia ou composta apenas por espaços.
- Solicita os valores esperado e recebido.
- Valida as entradas monetárias pelo subprograma compartilhado.
- Permite nova tentativa após uma entrada inválida.
- Trata o encerramento da entrada antes dos campos obrigatórios.
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

O leitor rejeita arquivo vazio e verifica o comprimento do registro
antes de separar os campos.

O leitor informa o número da linha com erro, continua processando
os registros seguintes e apresenta os totais de registros lidos,
válidos e inválidos.

Uma linha é contabilizada como válida somente depois de passar
pela validação da estrutura e pela validação monetária.

Os identificadores ainda não possuem verificação de duplicidade
nem uma regra específica de formato.

### Limite das linhas

O campo de leitura possui 1024 posições.
A verificação atual rejeita registros cujo texto, após remover
espaços finais, excede 256 posições.

Essa verificação ainda não mede integralmente o tamanho físico
de qualquer linha: espaços finais são desconsiderados e linhas
acima da capacidade do campo de leitura precisam de tratamento
adicional.

## Validação monetária compartilhada

As regras estão implementadas em `validar-monetario.cob`:

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

### Contrato do subprograma

Os campos são passados nesta ordem:

| Campo | Definição COBOL | Finalidade |
|---|---|---|
| `entrada-validacao` | `PIC X(256)` | Texto de entrada |
| `validacao-ok` | `PIC 9` | `1` para válido; `0` para inválido |
| `valor-validado` | `PIC 9(5)V99` | Número convertido quando aprovado |
| `mensagem-erro` | `PIC X(80)` | Motivo da rejeição |

Os programas chamam o subprograma com `CALL ... USING`.

O subprograma:

- Recebe os campos por meio da `LINKAGE SECTION`.
- Reinicializa os resultados a cada chamada.
- Copia a entrada para um campo de trabalho.
- Valida o formato antes da conversão.
- Não altera o texto original recebido.
- Não lê teclado, abre arquivos ou exibe mensagens.
- Devolve a execução ao chamador com `GOBACK`.

A validação examina o texto recebido no campo.
Ela não recupera conteúdo que tenha sido truncado antes da chamada.

## Organização do código

| Componente | Responsabilidades |
|---|---|
| `ola.cob` | Interação, novas tentativas, cálculo e apresentação |
| `leitor.cob` | Operações de arquivo, estrutura dos registros e contadores |
| `validar-monetario.cob` | Formato, casas decimais, limite e conversão monetária |

No leitor, a validação monetária só é chamada quando
a estrutura do registro está correta.

O código-fonte monetário é compartilhado.
Na compilação, ele é ligado a cada executável.

Ao alterar esse subprograma, é necessário recompilar
os dois programas principais.

## Ambiente utilizado

- Ubuntu 24.04 LTS em máquina virtual no VirtualBox.
- GnuCOBOL 3.1.2.
- Bash e utilitários de terminal, incluindo `diff`, `grep` e `mktemp`.
- Git e GitHub.
- Editor Nano.
- Acesso ao Ubuntu por SSH a partir do Windows.

## Arquivos

| Arquivo | Finalidade |
|---|---|
| `ola.cob` | Conferência interativa |
| `leitor.cob` | Leitura e validação do arquivo |
| `validar-monetario.cob` | Subprograma monetário compartilhado |
| `dados/esperados.csv` | Dados fictícios de exemplo |
| `testes/cenarios/validos.csv` | Cenário válido |
| `testes/cenarios/mistos.csv` | Registros válidos e inválidos |
| `testes/cenarios/vazio.csv` | Arquivo vazio |
| `testes/cenarios/linha-longa.csv` | Registro acima do limite testado |
| `testes/testar-leitor.sh` | Testes automatizados do leitor |
| `testes/testar-ola.sh` | Testes automatizados da conferência interativa |
| `.gitignore` | Regras para ignorar os executáveis |
| `README.md` | Documentação do projeto |

Os executáveis `ola` e `leitor` são gerados localmente e
não são versionados.

## Como compilar e executar

Execute os comandos a partir da pasta raiz do projeto.

### Conferência interativa

Compile:

```bash
cobc -x -free -o ola ola.cob validar-monetario.cob
```

Execute:

```bash
./ola
```

### Leitor de arquivo

Compile:

```bash
cobc -x -free -o leitor leitor.cob validar-monetario.cob
```

Execute:

```bash
./leitor
```

O programa principal é listado antes do subprograma na compilação.

O caminho `dados/esperados.csv` é relativo à pasta de onde
o leitor é executado.

Após alterar um arquivo `.cob`, recompile os executáveis afetados.

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

## Tratamento de erros

O leitor verifica abertura, leitura e fechamento por meio
de `FILE STATUS`.

| Código | Significado |
|---|---|
| `00` | Operação realizada com sucesso |
| `10` | Fim do arquivo durante a leitura |
| `35` | Arquivo não encontrado na abertura |

Outros códigos são apresentados como erro de operação.

O fim do arquivo encerra normalmente a leitura.
Se nenhum registro tiver sido lido, o arquivo é rejeitado como vazio.

No programa interativo, o encerramento da entrada antes de um
campo obrigatório produz uma mensagem de erro e saída `1`.

### Códigos de saída dos programas

| Código | Significado |
|---|---|
| `0` | Execução concluída com sucesso |
| `1` | Erro de arquivo, registros inválidos ou entrada interativa encerrada prematuramente |

Um pagamento abaixo ou acima do esperado não é erro de execução:
é um resultado da conferência e permite saída `0`.

Para consultar o código de saída, execute imediatamente
depois do programa:

```bash
echo $?
```

## Testes automatizados

Na pasta raiz do projeto, execute:

```bash
bash testes/testar-leitor.sh
```

```bash
bash testes/testar-ola.sh
```

Os scripts compilam o programa principal junto com
`validar-monetario.cob` em uma pasta temporária.

Não é necessário compilar manualmente antes dos testes.

### Testes do leitor

A suíte compara a saída completa usando `diff`
e verifica o código de encerramento.

| Cenário | Código esperado |
|---|---|
| Arquivo válido | `0` |
| Arquivo misto | `1` |
| Arquivo vazio | `1` |
| Linha longa | `1` |
| Arquivo ausente | `1` |

O arquivo original `dados/esperados.csv` não é alterado.

### Testes da conferência interativa

A suíte fornece entradas pelo terminal, verifica o código
de encerramento e procura as linhas esperadas com `grep -Fxq`.

Ela não compara a saída completa do programa.

| Cenário | Código esperado |
|---|---|
| Fim da entrada antes do operador | `1` |
| Fim da entrada antes do valor esperado | `1` |
| Fim da entrada antes do valor recebido | `1` |
| Esperado `100.50`, recebido `90.80` | `0` |

O cenário válido verifica os dois valores apresentados,
a diferença `-9.70` e a classificação abaixo do esperado.

### Resultado confirmado após a refatoração

Leitor:

```text
Resumo: 5 aprovados, 0 reprovados.
```

Conferência interativa:

```text
Resumo: 4 aprovados, 0 reprovados.
```

As duas suítes terminaram com código `0`.

Os oito cenários anteriores foram preservados e foi
acrescentado um cenário de pagamento válido.

### Código de saída das suítes

- `0`: todos os cenários da suíte passaram.
- `1`: pelo menos uma verificação de cenário falhou.
- Falhas de preparação ou compilação também interrompem
  o script com código diferente de zero.

Um cenário de erro passa quando o programa apresenta
o erro esperado.

A suíte ainda não cobre todas as regras e limites.
O subprograma é exercitado por meio dos programas principais;
ainda não possui uma suíte direta de testes.
O GitHub Actions ainda não foi configurado.

## Testes manuais anteriores

Foram exercitados ao longo do desenvolvimento:

- Recebimentos abaixo, iguais e acima do esperado.
- Operador vazio e login com ponto.
- Entradas monetárias inválidas seguidas de correção.
- Limites monetários e casas decimais.
- Apresentação sem zeros desnecessários à esquerda.
- Ausência e excesso de separadores.
- Identificador vazio e valor vazio.
- Continuação da leitura após erros.

Os cenários manuais anteriores não foram todos repetidos
após cada alteração.

### Arquivo misto usado na automação

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

Resultado esperado e confirmado:
oito registros lidos, quatro válidos, quatro inválidos
e código de saída `1`.

## Limitações atuais

- A conferência interativa processa um pagamento por execução.
- Os campos de leitura interativa têm 40 posições e ainda
  não possuem tratamento completo de excesso de tamanho.
- O leitor valida somente o arquivo de valores esperados.
- A medição do tamanho das linhas tem as limitações descritas acima.
- Não existe comparação entre dois arquivos.
- Não existe detecção de identificadores duplicados.
- O leitor não grava relatório de saída.
- Não há autenticação, banco de dados, API ou interface web.
- Não há integração com sistemas bancários.

## Próximas etapas

- Ler e armazenar pagamentos esperados e recebidos.
- Definir regras para identificadores e detectar duplicidades.
- Comparar pagamentos por identificador.
- Identificar divergências, ausências e recebimentos inesperados.
- Gerar relatório com resultados e totais.
- Ampliar os testes e tratar os limites de entrada pendentes.

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
aprendizado e portfólio.

# Contrato de Integração

Este documento define o contrato técnico entre o backend Java,
o motor de conciliação em COBOL e o PostgreSQL.

O objetivo é tornar explícitas as responsabilidades de cada camada,
os formatos de comunicação, as regras de processamento e o
comportamento esperado diante de falhas.

O documento também serve como referência para evitar que alterações
futuras em uma camada quebrem silenciosamente as demais.

O projeto utiliza dados fictícios e possui finalidade educacional
e de portfólio.

---

# 1. Responsabilidades

## 1.1 PostgreSQL

O PostgreSQL é a fonte persistente dos dados da aplicação.

Responsabilidades:

- armazenar cobranças;
- armazenar pagamentos;
- manter restrições de integridade;
- disponibilizar os dados necessários para criação do snapshot;
- armazenar o histórico das conciliações;
- armazenar resultados estruturados;
- armazenar resumos;
- armazenar o relatório definitivo;
- preservar o histórico de execuções concluídas.

O PostgreSQL não executará diretamente o programa COBOL.

---

## 1.2 Backend Java

O backend Java será responsável pela orquestração da aplicação.

Responsabilidades:

- receber requisições da API;
- validar dados no nível da aplicação;
- acessar o PostgreSQL;
- criar o snapshot dos dados da conciliação;
- preparar arquivos de entrada para o COBOL;
- criar diretório temporário exclusivo por execução;
- executar o motor COBOL;
- aplicar timeout;
- consumir a saída do processo;
- interpretar o código de saída;
- validar o resultado estruturado;
- validar o relatório;
- conferir o resultado contra o snapshot;
- persistir resultados válidos;
- registrar falhas;
- remover artefatos temporários;
- expor resultados por meio da API.

O backend será a camada responsável por coordenar PostgreSQL,
sistema de arquivos e processo COBOL.

---

## 1.3 Motor COBOL

O COBOL permanece responsável pelas regras de conciliação.

Responsabilidades:

- receber arquivos de valores esperados e recebidos;
- validar o contrato de entrada do motor;
- comparar cobranças e pagamentos;
- classificar resultados;
- identificar duplicidades;
- calcular totais;
- calcular saldo global;
- gerar relatório destinado à leitura humana;
- gerar resultado estruturado destinado ao backend;
- retornar código de saída compatível com este contrato.

O COBOL não será responsável por:

- acessar diretamente o PostgreSQL;
- expor API HTTP;
- autenticar usuários;
- controlar autorização;
- manter sessões;
- persistir diretamente o histórico da aplicação.

---

# 2. Visão geral do fluxo

O fluxo conceitual será:

```text
API
 |
 v
Backend Java
 |
 | cria snapshot
 v
PostgreSQL
 |
 | dados congelados da execução
 v
Backend Java
 |
 | gera arquivos
 v
esperados.csv
recebidos.csv
 |
 v
Motor COBOL
 |
 +--> relatorio.txt
 |
 +--> resultado.tsv
 |
 v
Backend Java
 |
 | valida resultado
 | compara com snapshot
 v
PostgreSQL
 |
 v
Conciliação concluída
```

O backend não deverá utilizar dados que tenham sido alterados depois
da criação do snapshot para reconstruir uma execução já iniciada.

---

# 3. Execução do motor COBOL

O backend Java executará o programa `conciliacao` como processo
separado do processo da aplicação.

Será utilizado:

```text
ProcessBuilder
```

com cada argumento fornecido separadamente.

Não será utilizado:

```text
bash -c
```

nem montagem de uma linha de comando única por concatenação.

Também não será utilizado caminho de executável recebido pela API.

Essa regra reduz riscos de injeção de comandos e problemas com
interpretação de caracteres especiais.

---

## 3.1 Executável COBOL

O caminho do executável será uma configuração interna da aplicação.

Exemplo conceitual:

```text
/opt/conciliacao/bin/conciliacao
```

O consumidor da API não poderá definir ou modificar esse caminho.

Antes da execução, o backend deverá verificar que o caminho configurado:

- existe;
- aponta para arquivo regular;
- possui permissão de execução.

---

# 4. Interface de argumentos do COBOL

A versão atual do programa COBOL aceita zero ou três argumentos.

Para integração com o backend, essa interface será evoluída.

A interface de integração passará a utilizar quatro argumentos:

```text
conciliacao esperados.csv recebidos.csv relatorio.txt resultado.tsv
```

Ordem:

```text
1. arquivo de valores esperados
2. arquivo de valores recebidos
3. relatório destinado à leitura humana
4. resultado estruturado destinado ao backend
```

Os quatro caminhos serão enviados separadamente por `ProcessBuilder`.

O processo não precisará receber dados pela entrada padrão.

A alteração para quatro argumentos deverá ser implementada e
testada antes da integração real com o backend.

Essa evolução não deverá modificar as regras de conciliação já
validadas.

---

# 5. Diretório temporário por execução

Cada conciliação utilizará um diretório temporário exclusivo.

Exemplo:

```text
/tmp/conciliacao/<uuid>/
```

A criação deverá utilizar mecanismos seguros do Java, como:

```text
Files.createTempDirectory
```

quando aplicável.

Arquivos conceituais:

```text
esperados.csv
recebidos.csv
relatorio.txt
resultado.tsv
processo.log
```

Uma execução nunca deverá reutilizar o diretório temporário de outra.

Quando o sistema operacional permitir, o diretório deverá possuir
permissões restritas ao usuário da aplicação.

A API nunca fornecerá caminhos locais diretamente para o COBOL.

---

# 6. Arquivos de entrada

Os arquivos:

```text
esperados.csv
recebidos.csv
```

serão produzidos exclusivamente pelo backend.

Eles serão gerados a partir dos dados do snapshot da execução.

Formato:

```text
identificador;valor
```

Regras:

- codificação UTF-8;
- quebra de linha LF;
- sem cabeçalho;
- um registro por linha;
- ponto como separador decimal;
- no máximo duas casas decimais;
- nenhuma montagem a partir de caminhos fornecidos pelo usuário.

Os valores monetários deverão ser formatados pelo Java usando
`BigDecimal`.

Não deverá ser utilizado `double` ou `float` para cálculos monetários.

---

# 7. Limites da versão atual do motor

O motor COBOL atual suporta no máximo:

```text
1000 cobranças
1000 pagamentos
```

O backend deverá verificar esses limites antes de executar o processo.

A versão inicial da integração exige também pelo menos:

```text
1 cobrança
1 pagamento
```

porque o motor atual considera arquivo de entrada vazio inválido.

Portanto:

```text
1 <= quantidade de cobranças <= 1000
1 <= quantidade de pagamentos <= 1000
```

Se os dados selecionados estiverem fora desses limites, o backend
deverá rejeitar a solicitação antes da execução do COBOL.

Essa rejeição é uma falha de pré-condição da aplicação e não uma
falha interna do motor.

Uma futura versão poderá ampliar o contrato para permitir um dos
conjuntos vazio.

---

# 8. Ordem determinística

A ordem dos dados faz parte do contrato.

Isso é especialmente importante porque, quando existem pagamentos
duplicados, o primeiro pagamento é considerado o pagamento principal.

---

## 8.1 Cobranças

Na implementação inicial, as cobranças serão selecionadas utilizando:

```sql
ORDER BY cobrancas.id ASC
```

O snapshot armazenará essa ordem.

`esperados.csv` será gerado por:

```text
ORDER BY ordem ASC
```

---

## 8.2 Pagamentos

Na implementação inicial, os pagamentos serão selecionados usando:

```sql
ORDER BY pagamentos.id ASC
```

O snapshot preservará essa sequência.

`recebidos.csv` será gerado utilizando:

```text
ORDER BY ordem ASC
```

O backend nunca deverá depender da ordem implícita de um `SELECT`
sem `ORDER BY`.

---

# 9. Resultado estruturado

Além do relatório destinado à leitura humana, o COBOL produzirá:

```text
resultado.tsv
```

Esse arquivo será a interface estruturada entre COBOL e Java.

O backend não deverá interpretar frases de `relatorio.txt` para
tomar decisões de negócio.

---

# 10. Formato do `resultado.tsv`

O formato inicial será TSV.

O caractere separador será TAB:

```text
U+0009
```

Nos exemplos deste documento, `<TAB>` representa esse caractere.

Regras:

- UTF-8;
- LF como quebra de linha;
- sem BOM;
- sem cabeçalho tradicional;
- primeira linha obrigatoriamente contém a versão;
- depois vêm registros de detalhe;
- a última linha será obrigatoriamente o resumo;
- não serão permitidas linhas vazias;
- não será permitido conteúdo depois do resumo.

---

## 10.1 Versão

Primeira linha:

```text
VERSAO<TAB>1
```

A versão 1 terá exatamente dois campos.

O backend rejeitará qualquer versão desconhecida.

---

## 10.2 Registros de detalhe

Formato:

```text
DETALHE<TAB>identificador<TAB>valor_esperado<TAB>valor_recebido<TAB>diferenca<TAB>status<TAB>quantidade_recebimentos
```

Existem exatamente sete campos.

Exemplo:

```text
DETALHE<TAB>P001<TAB>100.50<TAB>90.00<TAB>-10.50<TAB>ABAIXO_DO_ESPERADO<TAB>1
```

Status permitidos:

```text
CONFERIDO
ACIMA_DO_ESPERADO
ABAIXO_DO_ESPERADO
DUPLICADO
SEM_RECEBIMENTO
SEM_PREVISAO
```

Esses valores fazem parte do contrato de máquina.

Alterações de texto no relatório humano não deverão alterar esses
identificadores.

---

# 11. Valores monetários no resultado

Os valores deverão:

- utilizar ponto decimal;
- possuir exatamente duas casas;
- não possuir separador de milhares;
- usar sinal negativo apenas quando necessário.

Exemplos:

```text
0.00
100.50
-10.50
```

Campos monetários não aplicáveis permanecerão vazios.

Não será utilizada a palavra:

```text
NULL
```

O Java deverá interpretar valores monetários utilizando:

```text
BigDecimal
```

---

# 12. Regras dos detalhes

## 12.1 Conferido

```text
status = CONFERIDO
valor_esperado preenchido
valor_recebido preenchido
diferenca = 0.00
quantidade_recebimentos = 1
```

---

## 12.2 Acima do esperado

```text
status = ACIMA_DO_ESPERADO
valor_esperado preenchido
valor_recebido preenchido
diferenca > 0
quantidade_recebimentos = 1
```

---

## 12.3 Abaixo do esperado

```text
status = ABAIXO_DO_ESPERADO
valor_esperado preenchido
valor_recebido preenchido
diferenca < 0
quantidade_recebimentos = 1
```

---

## 12.4 Sem recebimento

Exemplo:

```text
DETALHE<TAB>P002<TAB>200.00<TAB><TAB><TAB>SEM_RECEBIMENTO<TAB>0
```

Regras:

```text
valor_esperado preenchido
valor_recebido vazio
diferenca vazia
quantidade_recebimentos = 0
```

---

## 12.5 Sem previsão

Exemplo:

```text
DETALHE<TAB>P999<TAB><TAB>50.00<TAB><TAB>SEM_PREVISAO<TAB>1
```

Regras:

```text
valor_esperado vazio
valor_recebido preenchido
diferenca vazia
quantidade_recebimentos = 1
```

Cada pagamento sem cobrança correspondente gera seu próprio registro.

---

# 13. Pagamentos duplicados

Quando uma cobrança existente possuir mais de um pagamento:

- será produzido um único `DETALHE` para a cobrança;
- o status será `DUPLICADO`;
- o primeiro pagamento, segundo a ordem do snapshot, será o principal;
- `valor_recebido` representará o primeiro pagamento;
- `diferenca` será calculada usando o primeiro pagamento;
- `quantidade_recebimentos` conterá a quantidade total de pagamentos
  associados à cobrança;
- todos esses pagamentos serão considerados utilizados;
- nenhum pagamento adicional dessa cobrança será classificado como
  `SEM_PREVISAO`.

Exemplo:

```text
DETALHE<TAB>P001<TAB>100.00<TAB>90.00<TAB>-10.00<TAB>DUPLICADO<TAB>2
```

Identificadores duplicados no arquivo de valores esperados continuam
sendo entrada inválida.

---

# 14. Pagamentos repetidos sem cobrança existente

Considere:

```text
P999;10.00
P999;20.00
```

sem existir cobrança `P999`.

O resultado deverá possuir dois registros:

```text
SEM_PREVISAO
SEM_PREVISAO
```

Cada pagamento representa uma ocorrência independente.

Não será produzido um único registro `DUPLICADO`, pois não existe
cobrança válida à qual os pagamentos possam ser associados.

A camada SQL deverá seguir a mesma regra quando apresentar resultados
detalhados.

Antes da integração com o backend, a view SQL detalhada deverá ser
ajustada caso ainda esteja limitando cobranças inexistentes ao primeiro
pagamento do identificador.

---

# 15. Resumo estruturado

Depois de todos os detalhes deverá existir exatamente uma linha:

```text
RESUMO<TAB>conferidos<TAB>acima<TAB>abaixo<TAB>duplicados<TAB>sem_recebimento<TAB>sem_previsao<TAB>total_esperado<TAB>total_recebido<TAB>saldo_global
```

A linha possui exatamente dez campos.

Exemplo:

```text
RESUMO<TAB>1<TAB>0<TAB>1<TAB>0<TAB>1<TAB>1<TAB>375.75<TAB>215.25<TAB>-160.50
```

Todos os contadores deverão ser inteiros não negativos.

---

## 15.1 Contador de duplicados

`duplicados` representa a quantidade de cobranças classificadas como:

```text
DUPLICADO
```

Não representa a quantidade de pagamentos adicionais.

Exemplo:

Uma cobrança com três pagamentos continua contando como:

```text
Duplicados = 1
```

---

# 16. Semântica dos totais

## 16.1 `total_esperado`

Soma de todas as cobranças do snapshot.

---

## 16.2 `total_recebido`

Soma de todos os pagamentos do snapshot.

Inclui:

- pagamento principal;
- pagamentos adicionais de cobranças duplicadas;
- pagamentos sem cobrança correspondente.

---

## 16.3 `saldo_global`

Definição:

```text
saldo_global = total_recebido - total_esperado
```

O valor é bruto.

Um saldo global igual a zero não significa que todas as cobranças
estejam conciliadas corretamente.

---

# 17. `saldo_global` e `saldo_liquido` não são sinônimos

O COBOL utiliza:

```text
saldo_global
```

calculado sobre todos os pagamentos recebidos.

A view SQL atual possui:

```text
saldo_liquido
```

baseado no pagamento principal válido por cobrança.

Portanto:

```text
saldo_global != saldo_liquido
```

em determinados cenários.

O backend não deverá comparar esses campos como se representassem a
mesma métrica.

Na API e na persistência, os dois nomes deverão permanecer distintos.

A validação do resultado COBOL utilizará `saldo_global` calculado a
partir do próprio snapshot.

---

# 18. Limites do resultado estruturado

Considerando os limites atuais:

```text
1000 cobranças
1000 pagamentos
```

o número máximo de registros `DETALHE` será limitado pelo conteúdo do
snapshot.

O backend não aceitará um número de linhas incompatível com esses
limites.

Como regra adicional de proteção, a implementação deverá impor limites
de tamanho para:

- cada linha do TSV;
- arquivo TSV total;
- relatório;
- saída capturada do processo.

Esses limites serão constantes de configuração interna e não serão
definidos pela API.

---

# 19. Validação do resultado pelo backend

Código de saída `0` isoladamente não será suficiente.

Antes de aceitar uma execução, o Java deverá verificar:

- existência de `resultado.tsv`;
- arquivo regular;
- ausência de link simbólico;
- arquivo pertencente ao diretório da execução;
- UTF-8 válido;
- primeira linha `VERSAO`;
- versão conhecida;
- quantidade correta de campos;
- status conhecidos;
- números válidos;
- formato monetário válido;
- exatamente uma linha `RESUMO`;
- resumo obrigatoriamente na última linha;
- ausência de conteúdo depois do resumo;
- ausência de linhas vazias inesperadas.

Qualquer falha produzirá:

```text
RESULTADO_INVALIDO
```

---

# 20. Validação cruzada contra o snapshot

O backend não confiará cegamente no resultado produzido pelo COBOL.

Deverá comparar:

```text
snapshot
resultado detalhado
resumo
```

Entre as verificações:

- cada cobrança deverá produzir exatamente um resultado;
- cobrança sem pagamento deverá ser `SEM_RECEBIMENTO`;
- cobrança com um pagamento deverá possuir classificação compatível
  com os valores;
- cobrança com mais de um pagamento deverá ser `DUPLICADO`;
- `quantidade_recebimentos` deverá corresponder ao snapshot;
- cada pagamento sem cobrança deverá gerar um `SEM_PREVISAO`;
- nenhum pagamento poderá desaparecer da contabilização;
- contadores do resumo deverão corresponder aos detalhes;
- `total_esperado` deverá corresponder ao snapshot;
- `total_recebido` deverá corresponder ao snapshot;
- `saldo_global` deverá ser:

```text
total_recebido - total_esperado
```

A diferença dos registros também poderá ser recalculada pelo Java.

Qualquer inconsistência será:

```text
RESULTADO_INVALIDO
```

---

# 21. Relatório humano

`relatorio.txt` continuará sendo destinado a:

- leitura humana;
- auditoria;
- consulta;
- download.

O backend não utilizará frases do relatório para determinar:

- status;
- totais;
- contadores;
- decisões de negócio.

Após código `0`, o backend deverá verificar que o relatório:

- existe;
- é arquivo regular;
- não é link simbólico;
- pertence ao diretório temporário da execução;
- pode ser lido;
- não está vazio.

---

# 22. Código de saída do processo

Contrato:

| Código | Significado |
|---|---|
| `0` | Processamento COBOL concluído |
| `1` | Falha de entrada, validação ou operação |
| `2` | Erro de uso ou configuração dos argumentos |

Código diferente de `0` nunca poderá resultar em uma conciliação
`CONCLUIDA`.

Código `0` ainda exige validação do relatório e do resultado
estruturado.

---

# 23. Saída padrão e saída de erro do processo

O processo externo pode produzir conteúdo em:

```text
stdout
stderr
```

O backend deverá consumir essas saídas enquanto o processo estiver
executando.

Não será permitido iniciar o processo e somente ler sua saída depois
do término, pois o preenchimento dos buffers do sistema operacional
poderia bloquear o processo.

A implementação poderá combinar os fluxos com:

```text
redirectErrorStream(true)
```

ou consumir os dois fluxos concorrentemente.

A quantidade de saída armazenada deverá possuir limite.

O excesso de saída não deverá causar consumo ilimitado de memória ou
disco.

A saída será utilizada para diagnóstico e logging.

Ela não substituirá:

- código de saída;
- `resultado.tsv`;
- relatório.

---

# 24. Timeout

Toda execução COBOL possuirá tempo máximo configurável.

O timeout:

- será configuração interna;
- não será recebido diretamente pela API.

Se o prazo for excedido:

1. o backend solicitará encerramento do processo;
2. aguardará um pequeno período de tolerância;
3. se necessário, utilizará encerramento forçado;
4. confirmará que o processo realmente terminou;
5. somente então iniciará a limpeza dos arquivos;
6. a execução será marcada como `FALHA`.

Tipo:

```text
TIMEOUT
```

Quando aplicável, processos descendentes iniciados pelo processo
também deverão ser tratados.

---

# 25. Concorrência de processos COBOL

O backend não iniciará quantidade ilimitada de processos COBOL ao
mesmo tempo.

Existirá um limite de concorrência configurável.

O valor será definido de acordo com o ambiente de execução.

Ele não será configurável pela API.

Na primeira versão, com uma única instância do backend, poderá ser
utilizado mecanismo local de controle de concorrência.

Caso a aplicação seja escalada para múltiplas instâncias, será
necessário substituir ou complementar esse mecanismo por coordenação
compartilhada.

---

# 26. Persistência e transações

O PostgreSQL é a fonte de verdade persistente.

O processo COBOL não participará de uma transação PostgreSQL.

O backend nunca manterá uma transação JDBC aberta enquanto aguarda o
processo externo.

Isso evita:

- transações longas;
- locks prolongados;
- conexões ocupadas;
- rollback dependente de processo externo.

---

# 27. Identificação da execução

Cada conciliação possuirá UUID.

Exemplo:

```text
7b31c94a-0a50-4a13-8c26-4cbf0ab7cb70
```

O UUID relacionará:

- execução;
- snapshot de cobranças;
- snapshot de pagamentos;
- resultados;
- resumo;
- relatório;
- logs correlacionados;
- falhas.

Esse UUID também será utilizado como identificador de correlação nos
logs da aplicação.

---

# 28. Estados da conciliação

Estados iniciais:

```text
EM_PROCESSAMENTO
CONCLUIDA
FALHA
```

Transições válidas:

```text
EM_PROCESSAMENTO -> CONCLUIDA
EM_PROCESSAMENTO -> FALHA
```

Não será permitido:

```text
CONCLUIDA -> EM_PROCESSAMENTO
CONCLUIDA -> FALHA
FALHA -> CONCLUIDA
FALHA -> EM_PROCESSAMENTO
```

Reprocessamento cria nova execução.

---

# 29. Criação do snapshot

A criação do snapshot ocorrerá em uma transação curta.

Essa transação utilizará nível de isolamento:

```text
REPEATABLE READ
```

Motivo:

No PostgreSQL, `READ COMMITTED` pode fornecer snapshots diferentes
para comandos separados dentro da mesma transação.

Como cobranças e pagamentos serão consultados em comandos distintos,
a conciliação precisa enxergar ambos a partir de uma visão consistente
do banco.

Fluxo:

1. iniciar transação `REPEATABLE READ`;
2. selecionar cobranças em ordem determinística;
3. selecionar pagamentos em ordem determinística;
4. validar quantidades;
5. criar registro da conciliação;
6. copiar cobranças para snapshot;
7. copiar pagamentos para snapshot;
8. confirmar a transação.

Se os limites não forem atendidos, a transação deverá ser abortada.

Nesse caso nenhuma execução `EM_PROCESSAMENTO` deverá permanecer
persistida.

---

# 30. Snapshot imutável

Depois do commit da criação:

```text
conciliacao_cobrancas
conciliacao_pagamentos
```

serão a fonte dos arquivos enviados ao COBOL.

Alterações posteriores em:

```text
cobrancas
pagamentos
```

não poderão modificar uma conciliação já iniciada.

---

# 31. Processamento fora da transação

Depois do snapshot:

1. criar diretório temporário;
2. gerar `esperados.csv`;
3. gerar `recebidos.csv`;
4. executar COBOL;
5. drenar stdout/stderr;
6. aplicar timeout;
7. verificar código de saída;
8. validar `resultado.tsv`;
9. validar `relatorio.txt`;
10. validar resultado contra snapshot.

Nenhuma transação de banco permanecerá aberta durante essas etapas.

---

# 32. Persistência dos resultados

Depois que tudo estiver validado, será aberta uma nova transação
curta.

A transação deverá:

1. verificar que a execução ainda está `EM_PROCESSAMENTO`;
2. impedir finalização concorrente da mesma execução;
3. persistir resultados detalhados;
4. persistir resumo;
5. persistir relatório definitivo;
6. definir `finalizada_em`;
7. alterar estado para `CONCLUIDA`;
8. confirmar a transação.

Resultados e estado `CONCLUIDA` deverão fazer parte da mesma transação.

Não poderá existir execução concluída sem seus dados definitivos.

---

# 33. Controle de concorrência da finalização

A atualização de estado deverá verificar explicitamente o estado
anterior esperado.

Uma execução somente poderá ser finalizada quando ainda estiver:

```text
EM_PROCESSAMENTO
```

A implementação poderá utilizar:

- controle otimista;
- coluna de versão;
- atualização condicional;
- lock de linha;

conforme a estratégia adotada no JPA.

O requisito funcional é que apenas um fluxo consiga concluir ou
marcar como falha uma determinada execução.

---

# 34. Persistência do relatório

Na primeira versão:

```text
relatorio.txt
```

será lido pelo backend e seu conteúdo será persistido no PostgreSQL
como texto.

O arquivo em `/tmp` não será a cópia definitiva.

Isso evita dependência do sistema de arquivos local para histórico.

Armazenamento externo poderá substituir essa estratégia futuramente.

---

# 35. Persistência do TSV

`resultado.tsv` é somente formato de integração.

Ele não será o armazenamento definitivo dos resultados.

Depois de validado, seu conteúdo será convertido em registros
estruturados no banco.

Consultas futuras não dependerão da existência do arquivo TSV.

---

# 36. Modelo conceitual

Estrutura:

```text
cobrancas
pagamentos
    |
    | snapshot
    v
conciliacoes
    |
    +-- conciliacao_cobrancas
    +-- conciliacao_pagamentos
    +-- conciliacao_resultados
    +-- conciliacao_resumo
```

---

# 37. Tabela `conciliacoes`

Campos conceituais:

```text
id
status
criada_em
finalizada_em
tipo_falha
mensagem_falha
versao_resultado
relatorio
versao
```

Regras:

- `id` UUID;
- `criada_em` obrigatória;
- `finalizada_em` nula enquanto `EM_PROCESSAMENTO`;
- `CONCLUIDA` exige `finalizada_em`;
- `FALHA` exige `finalizada_em`;
- `FALHA` exige `tipo_falha`;
- `versao_resultado` será preenchida apenas quando o resultado
  estruturado válido tiver sido reconhecido;
- `versao` poderá ser usada para controle otimista.

Datas serão armazenadas de forma compatível com instante absoluto.

No Java deverá ser preferido:

```text
Instant
```

---

# 38. Snapshot de cobranças

Tabela conceitual:

```text
conciliacao_cobrancas
```

Campos:

```text
conciliacao_id
ordem
cobranca_origem_id
identificador
valor_esperado
```

Chave lógica:

```text
conciliacao_id + ordem
```

Regras:

- `ordem` única na execução;
- `identificador` único na execução;
- valor imutável;
- ordem preservada.

---

# 39. Snapshot de pagamentos

Tabela:

```text
conciliacao_pagamentos
```

Campos:

```text
conciliacao_id
ordem
pagamento_origem_id
identificador_cobranca
valor_pago
```

Chave lógica:

```text
conciliacao_id + ordem
```

Não haverá unicidade sobre:

```text
identificador_cobranca
```

porque duplicidades são válidas nos recebimentos.

---

# 40. IDs de origem e histórico

Campos:

```text
cobranca_origem_id
pagamento_origem_id
```

existem para rastreabilidade.

Eles não deverão criar dependência que permita a exclusão ou alteração
da linha original invalidar o histórico.

Na implementação inicial, esses valores poderão ser armazenados sem
foreign key obrigatória para a tabela principal.

O snapshot deverá permanecer válido mesmo que a entidade original seja
alterada ou futuramente removida.

---

# 41. Resultados detalhados persistidos

Tabela:

```text
conciliacao_resultados
```

Campos:

```text
conciliacao_id
sequencia
identificador
valor_esperado
valor_recebido
diferenca
status
quantidade_recebimentos
```

Chave:

```text
conciliacao_id + sequencia
```

Não haverá unicidade apenas por identificador.

Isso é necessário porque múltiplos pagamentos `SEM_PREVISAO` podem
possuir o mesmo identificador.

---

# 42. Resumo persistido

Tabela:

```text
conciliacao_resumo
```

Relação de um para um com:

```text
conciliacoes
```

Campos:

```text
conciliacao_id
conferidos
acima
abaixo
duplicados
sem_recebimento
sem_previsao
total_esperado
total_recebido
saldo_global
```

Contadores deverão ser não negativos.

---

# 43. Restrições monetárias

Valores individuais de cobrança e pagamento respeitam o contrato
atual do motor:

```text
0.00 até 99999.99
```

com no máximo duas casas decimais.

A diferença individual está limitada ao intervalo possível entre dois
valores desse domínio.

Totais poderão atingir aproximadamente:

```text
99999990.00
```

considerando 1000 registros no valor máximo.

As colunas de totais deverão suportar esse domínio.

O Java sempre utilizará `BigDecimal`.

---

# 44. Imutabilidade histórica

Depois de `CONCLUIDA`, a aplicação não deverá alterar:

- snapshots;
- resultados;
- resumo;
- relatório.

Uma correção ou novo processamento cria outra execução.

A API inicial não oferecerá exclusão de conciliações históricas.

---

# 45. Tipos de falha

Tipos iniciais:

```text
ERRO_COBOL
TIMEOUT
RESULTADO_INVALIDO
ERRO_RELATORIO
ERRO_PERSISTENCIA
ERRO_INTERNO
PROCESSO_INTERROMPIDO
```

A descrição técnica detalhada poderá ser armazenada separadamente.

Stack traces, caminhos locais e mensagens internas do sistema
operacional não serão devolvidos diretamente pela API.

---

# 46. Registro de falha

Quando houver falha depois da criação do snapshot, o backend deverá
tentar registrar:

```text
status = FALHA
finalizada_em
tipo_falha
mensagem_falha
```

em transação independente.

Se nem mesmo essa operação puder ser persistida por indisponibilidade
do banco, a ocorrência deverá ser registrada no log da aplicação com
o UUID da execução.

---

# 47. Ausência de transação distribuída

Não existe uma transação única envolvendo simultaneamente:

```text
PostgreSQL
sistema de arquivos
processo COBOL
```

O sistema reconhecerá explicitamente essa limitação.

A consistência será obtida por:

- snapshots imutáveis;
- diretório exclusivo;
- validação antes da persistência;
- transações curtas;
- estados da execução;
- recuperação de execuções interrompidas.

---

# 48. Recuperação de execuções interrompidas

Uma queda da aplicação pode deixar uma execução em:

```text
EM_PROCESSAMENTO
```

sem processo ativo.

A implementação deverá possuir mecanismo de recuperação.

Cada execução possuirá informação suficiente para determinar quando
ultrapassou o prazo máximo esperado.

Em inicialização da aplicação ou rotina periódica, execuções
`EM_PROCESSAMENTO` que ultrapassaram o timeout mais uma margem de
segurança poderão ser marcadas como:

```text
FALHA
PROCESSO_INTERROMPIDO
```

A transição continuará condicionada ao estado ainda ser
`EM_PROCESSAMENTO`.

Assim, uma execução já concluída não poderá ser sobrescrita pela
rotina de recuperação.

---

# 49. Limpeza

Após persistência do resultado ou registro de falha:

- arquivos temporários deverão ser removidos;
- diretório temporário deverá ser removido.

A limpeza somente ocorrerá depois de o processo estar confirmado como
encerrado.

Falha de limpeza deverá ser registrada em log.

Ela não deverá transformar retroativamente uma conciliação já
persistida com sucesso em `FALHA`.

---

# 50. Limpeza após queda da aplicação

Uma queda abrupta pode deixar diretórios temporários abandonados.

A aplicação deverá possuir rotina de limpeza para diretórios antigos
que não correspondam a execução ativa válida.

A rotina não deverá apagar arquivos de uma execução ainda em andamento.

O UUID da execução permitirá correlacionar o diretório ao registro
persistido.

---

# 51. Segurança de arquivos

Os arquivos deverão ser criados pelo próprio backend dentro do
diretório exclusivo.

Quando possível, utilizar criação que rejeite arquivo já existente.

O backend não deverá seguir links simbólicos ao validar arquivos de
saída.

Antes de aceitar `relatorio.txt` ou `resultado.tsv`, deverá confirmar:

- arquivo regular;
- não link simbólico;
- caminho real contido dentro do diretório da execução.

---

# 52. Reprocessamento

Execuções concluídas e falhas são históricas.

Novo processamento cria novo UUID.

O sistema não sobrescreverá uma conciliação anterior.

Mesmo que o mesmo conjunto de dados seja processado novamente,
existirão duas execuções independentes.

---

# 53. Relação com as views SQL atuais

As views SQL existentes continuam úteis para:

- validação;
- estudo;
- consultas financeiras;
- comparação de regras.

Elas não serão usadas como substituto do snapshot da execução.

Antes da integração Java, deverá ser garantido que o resultado
detalhado SQL siga a política:

```text
cada pagamento sem cobrança = um SEM_PREVISAO
```

Também deverá ser preservada a distinção entre:

```text
saldo_global
saldo_liquido
```

---

# 54. Responsabilidade do backend sobre validação

O backend deverá validar dados antes da geração dos arquivos.

O PostgreSQL continuará possuindo restrições como segunda camada de
proteção.

O COBOL continuará validando novamente o formato recebido.

Portanto existirão três níveis complementares:

```text
Java
PostgreSQL
COBOL
```

Essa duplicação é intencional em fronteiras diferentes.

---

# 55. Erros enviados pela API

O consumidor da API receberá mensagens funcionais e controladas.

Não deverão ser expostos diretamente:

- stack traces;
- comandos executados;
- caminhos `/tmp`;
- caminho do executável COBOL;
- mensagens brutas de `errno`;
- detalhes de configuração do servidor.

Os logs internos poderão conter informações técnicas adicionais
associadas ao UUID da execução.

---

# 56. Observabilidade

Toda execução deverá poder ser correlacionada nos logs por:

```text
conciliacao_id
```

Eventos relevantes:

```text
snapshot criado
arquivos gerados
processo iniciado
processo finalizado
timeout
resultado validado
persistência concluída
falha registrada
limpeza executada
```

Não deverão ser registrados dados sensíveis desnecessariamente.

---

# 57. Pré-condições antes de iniciar o backend Java

Antes de considerar a integração COBOL pronta para o Java, deverão
estar concluídos e testados:

```text
1. suporte ao quarto argumento resultado.tsv
2. geração do resultado estruturado versão 1
3. testes automatizados do resultado.tsv
4. proteção do resultado estruturado contra publicação incompleta
5. preservação das regras atuais do relatório
6. ajuste do caso SQL de múltiplos pagamentos sem cobrança
7. execução completa das suítes existentes
```

Nenhuma dessas alterações deverá enfraquecer as validações já
existentes no motor.

---

# 58. Estratégia de testes da integração

A implementação Java deverá possuir testes em diferentes níveis.

## Testes unitários

Exemplos:

```text
parser TSV
validação dos status
validação dos valores
validação do resumo
cálculo de saldo
verificação das combinações de campos
```

## Testes de persistência

Exemplos:

```text
snapshot
ordem
imutabilidade
transição de status
restrições
rollback
```

## Testes de integração do processo

Exemplos:

```text
execução real do COBOL
código 0
código 1
código 2
timeout
resultado inválido
relatório ausente
processo encerrado
```

## Testes de concorrência

Exemplos:

```text
duas conciliações diferentes
tentativa de finalizar a mesma execução duas vezes
limite de processos simultâneos
```

---

# 59. Gate de qualidade por bloco

A implementação não será acumulada até o final para só então ser
revisada.

Cada bloco seguirá:

```text
definição
implementação
testes
revisão crítica
correção
commit
```

Um novo bloco somente deverá começar depois que o anterior estiver
estável.

---

# 60. Ordem inicial de implementação

A sequência planejada será:

```text
1. finalizar contrato de integração
2. evoluir COBOL para resultado.tsv
3. testar novamente o motor
4. alinhar detalhe SQL restante
5. criar estrutura do backend Spring Boot
6. configurar acesso ao PostgreSQL
7. criar modelo de persistência da conciliação
8. implementar snapshot
9. implementar geração dos CSV
10. implementar execução segura do COBOL
11. implementar parser e validação do resultado.tsv
12. persistir resultados
13. expor API
14. adicionar autenticação em etapa posterior
15. construir frontend Angular
```

---

# 61. Limitações assumidas na primeira versão

A primeira versão integrada assumirá:

```text
Linux/Ubuntu
GnuCOBOL
PostgreSQL
uma instância principal do backend
máximo de 1000 cobranças por execução
máximo de 1000 pagamentos por execução
pelo menos uma cobrança
pelo menos um pagamento
```

Suporte a:

```text
Windows como servidor
mainframe
execução distribuída
filas externas
armazenamento de objetos
múltiplas instâncias coordenadas
```

não faz parte da primeira versão.

---

# 62. Mainframe

A integração descrita neste documento utiliza o executável local
produzido pelo GnuCOBOL em Linux.

Ela não representa integração com:

```text
z/OS
JCL
CICS
Db2 mainframe
datasets
jobs batch de mainframe
```

Essas tecnologias fazem parte de uma trilha futura separada.

---

# 63. Regra central do contrato

A arquitetura deverá preservar a seguinte separação:

```text
PostgreSQL = persistência e histórico

Java = orquestração, integração, validação e API

COBOL = motor das regras de conciliação
```

Nenhuma camada deverá depender de comportamento implícito de outra.

Quando um comportamento fizer parte da integração, ele deverá ser
documentado, testado e versionado.

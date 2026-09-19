# Conciliação de pagamentos em COBOL

Projeto de estudo para aprender programação em COBOL e desenvolver,
gradualmente, uma rotina de conciliação de pagamentos.

Conciliação é a comparação entre registros, como pagamentos esperados
e pagamentos recebidos, para identificar correspondências e diferenças.

## Estado atual

Programa inicial de conferência de um pagamento, executado no terminal.

Funcionalidades implementadas:
- Recebe o nome do operador.
- Calcula a diferença entre valor recebido e valor esperado.
- Classifica o recebimento como igual, abaixo ou acima do esperado.

Regra adotada:

Diferença = valor recebido - valor esperado.

- Diferença positiva: valor recebido acima do esperado.
- Diferença zero: pagamento conferido.
- Diferença negativa: valor recebido abaixo do esperado.

Os valores monetários ainda são definidos diretamente no código.
A leitura de arquivos e a conciliação de vários pagamentos ainda
não foram implementadas.

O projeto é executado no Ubuntu, sem uso de ambiente mainframe.

### Testes manuais realizados

| Esperado | Recebido | Diferença | Resultado |
|---|---|---|---|
| 100,00 | 80,00 | -20,00 | Abaixo do esperado |
| 100,00 | 100,00 | 0,00 | Pagamento conferido |
| 100,00 | 120,00 | +20,00 | Acima do esperado |

Os três cenários foram executados e apresentaram os resultados esperados.

## Ambiente utilizado

- Ubuntu 24.04 LTS em uma máquina virtual no VirtualBox.
- GnuCOBOL 3.1.2.0.
- Git 2.43.0.
- Editor de texto Nano.

## Arquivos

- `ola.cob`: código-fonte da conferência inicial de um pagamento.
- `.gitignore`: regras para ignorar arquivos gerados.
- `README.md`: apresentação e instruções do projeto.

O executável `ola` é gerado pela compilação e não é incluído
no controle de versões.

## Como compilar e executar

Com o GnuCOBOL instalado, abra o terminal na pasta do projeto.

Compile:

```bash
cobc -x -free -o ola ola.cob
```

Execute:

```bash
./ola
```

Saída esperada:

```text

Sistema de conciliacao iniciado.
Digite seu nome:
Bruno
Operador: Bruno
Valor esperado: 00100.00
Valor recebido: 00080.00
Diferenca: -00020.00
Status: valor recebido abaixo do esperado.
```

Após alterar e salvar `ola.cob`, compile novamente para atualizar
o executável.

## Próximas etapas

- Receber os valores monetários pelo teclado.
- Validar os dados informados.
- Melhorar a apresentação dos valores.
- Ler registros de arquivos.
- Gerar um relatório de conciliação de vários pagamentos.

## Autor

Bruno Ramos Lopes — projeto de estudo e portfólio.

# Conciliação de pagamentos em COBOL

Projeto de estudo para aprender programação em COBOL e desenvolver,
gradualmente, uma rotina de conciliação de pagamentos.

Conciliação é a comparação entre registros, como pagamentos esperados
e pagamentos recebidos, para identificar correspondências e diferenças.

## Estado atual

Etapa inicial: programa que exibe uma mensagem no terminal.

Já praticado:
- Criação e edição de código-fonte em COBOL.
- Compilação com GnuCOBOL.
- Execução de um programa no Linux.
- Diferença entre código-fonte e executável.
- Início do controle de versões com Git.

A lógica de conciliação ainda não foi implementada.
O projeto é executado no Ubuntu, sem uso de ambiente mainframe.

## Ambiente utilizado

- Ubuntu 24.04 LTS em uma máquina virtual no VirtualBox.
- GnuCOBOL 3.1.2.0.
- Git 2.43.0.
- Editor de texto Nano.

## Arquivos

- `ola.cob`: código-fonte do programa inicial.
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
```

Após alterar e salvar `ola.cob`, compile novamente para atualizar
o executável.

## Próximas etapas

- Aprender variáveis e entrada de dados.
- Comparar valores esperados e recebidos.
- Ler registros de arquivos.
- Gerar um relatório com os resultados da conciliação.

## Autor

Bruno Ramos Lopes — projeto de estudo e portfólio.

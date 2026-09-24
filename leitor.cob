identification division.
program-id. leitor.

data division.
working-storage section.
01 status-arquivo pic 99 value zero.
01 codigo-entrada binary-long value zero.
01 capacidade-registro binary-long value 256.
01 comprimento-registro binary-long value zero.
01 tamanho-identificador binary-long value zero.
01 posicao-separador binary-long value zero.
01 codigo-identificador binary-long value zero.
01 caminho-entrada-c pic x(257) value low-values.
01 registro-esperado pic x(256) value spaces.
01 fim-arquivo pic 9 value zero.
01 total-registros pic 9(9) value zero.
01 total-validos pic 9(9) value zero.
01 total-invalidos pic 9(9) value zero.
01 numero-exibicao pic z(8)9.

01 identificador-pagamento pic x(256) value spaces.
01 valor-texto pic x(256) value spaces.
01 quantidade-separadores pic 9(3) value zero.
01 tamanho-registro pic 9(4) value zero.

01 entrada-validacao pic x(256) value spaces.
01 validacao-ok pic 9 value zero.
01 valor-validado pic 9(5)v99 value zero.
01 mensagem-erro pic x(80) value spaces.
01 valor-exibicao pic zzzz9.99.

procedure division.
    display "Leitura dos pagamentos esperados."

    move z"dados/esperados.csv" to caminho-entrada-c
    perform abrir-entrada

    if status-arquivo not = "00"
        display "Erro ao abrir arquivo. Codigo: " status-arquivo
        move 1 to return-code
        stop run
    end-if

    perform until fim-arquivo = 1
        perform ler-entrada

        evaluate status-arquivo
            when "00"
            when "04"
            when "09"
                add 1 to total-registros
                perform validar-registro

                if mensagem-erro = spaces
                    move valor-texto to entrada-validacao

                    call "validar-monetario" using
                        entrada-validacao
                        validacao-ok
                        valor-validado
                        mensagem-erro
                    end-call
                end-if

                if mensagem-erro = spaces
                    add 1 to total-validos
                    perform mostrar-registro
                else
                    add 1 to total-invalidos
                    move total-registros to numero-exibicao

                    display "Erro na linha "
                        function trim(numero-exibicao)
                        ": "
                        function trim(mensagem-erro)
                end-if

            when "10"
                move 1 to fim-arquivo

            when other
                display "Erro na leitura. Codigo: " status-arquivo
                perform fechar-entrada
                move 1 to return-code
                stop run
        end-evaluate
    end-perform

    perform fechar-entrada

    if status-arquivo not = "00"
        display "Erro ao fechar arquivo. Codigo: " status-arquivo
        move 1 to return-code
        stop run
    end-if

    if total-registros = zero
        display "Erro: arquivo de pagamentos esperados esta vazio."
        move 1 to return-code
        stop run
    end-if

    move total-registros to numero-exibicao
    display "Total de registros lidos: "
        function trim(numero-exibicao)

    move total-validos to numero-exibicao
    display "Registros validos: "
        function trim(numero-exibicao)

    move total-invalidos to numero-exibicao
    display "Registros invalidos: "
        function trim(numero-exibicao)

    if total-invalidos > zero
        move 1 to return-code
    else
        move zero to return-code
    end-if

    stop run.

validar-registro.
    move spaces to identificador-pagamento valor-texto mensagem-erro
    move zero to quantidade-separadores

    if status-arquivo = "04"
        move "linha excede o limite de 256 bytes." to mensagem-erro
        exit paragraph
    end-if
    if status-arquivo = "09"
        move "linha contem controle ou UTF-8 invalido." to mensagem-erro
        exit paragraph
    end-if

    inspect registro-esperado
        tallying quantidade-separadores for all ";"
    if quantidade-separadores not = 1
        move "informe exatamente um ponto e virgula." to mensagem-erro
        exit paragraph
    end-if

    move 1 to posicao-separador
    perform until registro-esperado(posicao-separador:1) = ";"
        add 1 to posicao-separador
    end-perform
    compute tamanho-identificador = posicao-separador - 1

    unstring registro-esperado delimited by ";"
        into identificador-pagamento valor-texto
    end-unstring

    call static "entrada_identificador" using
        identificador-pagamento tamanho-identificador mensagem-erro
        returning codigo-identificador
    end-call
    if codigo-identificador not = zero
        exit paragraph
    end-if
    if function trim(valor-texto) = spaces
        move "valor vazio." to mensagem-erro
        exit paragraph
    end-if
    continue.

mostrar-registro.
    move valor-validado to valor-exibicao

    display "Pagamento: "
        function trim(identificador-pagamento)
        " | Valor esperado: "
        function trim(valor-exibicao).

abrir-entrada.
    call static "entrada_abrir" using caminho-entrada-c
        returning codigo-entrada
    end-call
    move codigo-entrada to status-arquivo.

ler-entrada.
    call static "entrada_ler" using
        registro-esperado capacidade-registro comprimento-registro
        returning codigo-entrada
    end-call
    move codigo-entrada to status-arquivo.

fechar-entrada.
    call static "entrada_fechar" returning codigo-entrada
    end-call
    move codigo-entrada to status-arquivo.

identification division.
program-id. leitor.

environment division.
input-output section.
file-control.
    select arquivo-esperados
        assign to "dados/esperados.csv"
        organization is line sequential
        file status is status-arquivo.

data division.
file section.
fd arquivo-esperados.
01 registro-esperado pic x(256).

working-storage section.
01 status-arquivo pic xx value spaces.
01 fim-arquivo pic 9 value zero.
01 total-registros pic 9(5) value zero.
01 total-exibicao pic zzzz9.
01 identificador-pagamento pic x(256) value spaces.
01 valor-texto pic x(256) value spaces.

procedure division.
    display "Leitura dos pagamentos esperados."

    open input arquivo-esperados

    if status-arquivo not = "00"
        display "Erro ao abrir arquivo. Codigo: " status-arquivo
        move 1 to return-code
        stop run
    end-if

    perform until fim-arquivo = 1
        read arquivo-esperados

        evaluate status-arquivo
            when "00"
                add 1 to total-registros
                perform separar-registro

            when "10"
                move 1 to fim-arquivo

            when other
                display "Erro na leitura. Codigo: " status-arquivo
                close arquivo-esperados
                move 1 to return-code
                stop run
        end-evaluate
    end-perform

    close arquivo-esperados

    if status-arquivo not = "00"
        display "Erro ao fechar arquivo. Codigo: " status-arquivo
        move 1 to return-code
        stop run
    end-if

    move total-registros to total-exibicao

    display "Total de registros lidos: "
        function trim(total-exibicao)

    move zero to return-code
    stop run.

separar-registro.
    move spaces to identificador-pagamento valor-texto

    unstring registro-esperado
        delimited by ";"
        into identificador-pagamento valor-texto
    end-unstring

    display "Pagamento: "
        function trim(identificador-pagamento)
        " | Valor esperado: "
        function trim(valor-texto).

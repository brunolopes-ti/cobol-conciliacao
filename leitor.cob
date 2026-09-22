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
01 total-registros pic 9(9) value zero.
01 total-validos pic 9(9) value zero.
01 total-invalidos pic 9(9) value zero.
01 numero-exibicao pic z(8)9.

01 identificador-pagamento pic x(256) value spaces.
01 valor-texto pic x(256) value spaces.
01 quantidade-separadores pic 9(3) value zero.
01 mensagem-erro pic x(80) value spaces.

01 entrada-validacao pic x(256) value spaces.
01 valor-validado pic 9(5)v99 value zero.
01 valor-exibicao pic zzzz9.99.
01 validacao-ok pic 9 value zero.
01 formato-ok pic 9 value zero.
01 encontrou-ponto pic 9 value zero.
01 posicao pic 9(3) value zero.
01 tamanho-entrada pic 9(3) value zero.
01 digitos-inteiros pic 9(3) value zero.
01 casas-decimais pic 9(3) value zero.

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
                perform validar-registro

                if mensagem-erro = spaces
                    move valor-texto to entrada-validacao
                    perform validar-valor
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
    move spaces to identificador-pagamento
        valor-texto mensagem-erro
    move zero to quantidade-separadores

    inspect registro-esperado
        tallying quantidade-separadores for all ";"

    if quantidade-separadores not = 1
        move "informe exatamente um ponto e virgula."
            to mensagem-erro
    else
        unstring registro-esperado
            delimited by ";"
            into identificador-pagamento valor-texto
        end-unstring

        evaluate true
            when function trim(identificador-pagamento) = spaces
                move "identificador vazio."
                    to mensagem-erro

            when function trim(valor-texto) = spaces
                move "valor vazio."
                    to mensagem-erro
        end-evaluate
    end-if.

validar-formato.
    move 1 to formato-ok
    move zero to digitos-inteiros
        casas-decimais encontrou-ponto

    move function trim(entrada-validacao)
        to entrada-validacao

    compute tamanho-entrada =
        function length(function trim(entrada-validacao))

    perform varying posicao from 1 by 1
        until posicao > tamanho-entrada

        evaluate true
            when entrada-validacao(posicao:1) is numeric
                if encontrou-ponto = zero
                    add 1 to digitos-inteiros
                else
                    add 1 to casas-decimais
                end-if

            when entrada-validacao(posicao:1) = "."
                if encontrou-ponto = 1
                    move zero to formato-ok
                    exit perform
                else
                    move 1 to encontrou-ponto
                end-if

            when other
                move zero to formato-ok
                exit perform
        end-evaluate
    end-perform

    if digitos-inteiros = zero
        move zero to formato-ok
    end-if

    if encontrou-ponto = 1 and casas-decimais = zero
        move zero to formato-ok
    end-if.

validar-valor.
    move zero to validacao-ok valor-validado
    move spaces to mensagem-erro

    perform validar-formato

    evaluate true
        when formato-ok = zero
            move "use digitos e ponto decimal, como 100.50."
                to mensagem-erro

        when casas-decimais > 2
            move "utilize no maximo 2 casas decimais."
                to mensagem-erro

        when function test-numval(entrada-validacao) not = zero
            move "informe um numero valido."
                to mensagem-erro

        when function numval(entrada-validacao) > 99999.99
            move "informe um valor entre 0 e 99999.99."
                to mensagem-erro

        when other
            compute valor-validado =
                function numval(entrada-validacao)
            move 1 to validacao-ok
    end-evaluate.

mostrar-registro.
    move valor-validado to valor-exibicao

    display "Pagamento: "
        function trim(identificador-pagamento)
        " | Valor esperado: "
        function trim(valor-exibicao).

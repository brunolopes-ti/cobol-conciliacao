identification division.
program-id. validar-monetario.

data division.
working-storage section.
01 texto-trabalho pic x(256) value spaces.
01 formato-ok pic 9 value zero.
01 encontrou-ponto pic 9 value zero.
01 posicao pic 9(3) value zero.
01 tamanho-entrada pic 9(3) value zero.
01 digitos-inteiros pic 9(3) value zero.
01 casas-decimais pic 9(3) value zero.

linkage section.
01 entrada-validacao pic x(256).
01 validacao-ok pic 9.
01 valor-validado pic 9(5)v99.
01 mensagem-erro pic x(80).

procedure division using
    entrada-validacao
    validacao-ok
    valor-validado
    mensagem-erro.

    move zero to validacao-ok valor-validado
    move spaces to mensagem-erro

    move function trim(entrada-validacao)
        to texto-trabalho

    perform validar-formato

    evaluate true
        when formato-ok = zero
            move "use digitos e ponto decimal, como 100.50."
                to mensagem-erro

        when casas-decimais > 2
            move "utilize no maximo 2 casas decimais."
                to mensagem-erro

        when function test-numval(texto-trabalho) not = zero
            move "informe um numero valido."
                to mensagem-erro

        when function numval(texto-trabalho) > 99999.99
            move "informe um valor entre 0 e 99999.99."
                to mensagem-erro

        when other
            compute valor-validado =
                function numval(texto-trabalho)
            move 1 to validacao-ok
    end-evaluate

    goback.

validar-formato.
    move 1 to formato-ok
    move zero to digitos-inteiros
        casas-decimais encontrou-ponto

    compute tamanho-entrada =
        function length(function trim(texto-trabalho))

    perform varying posicao from 1 by 1
        until posicao > tamanho-entrada

        evaluate true
            when texto-trabalho(posicao:1) is numeric
                if encontrou-ponto = zero
                    add 1 to digitos-inteiros
                else
                    add 1 to casas-decimais
                end-if

            when texto-trabalho(posicao:1) = "."
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

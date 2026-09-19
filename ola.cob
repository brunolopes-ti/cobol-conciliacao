identification division.
program-id. ola.

data division.
working-storage section.
01 nome-operador pic x(40) value spaces.
01 valor-esperado pic 9(5)v99 value zero.
01 valor-recebido pic 9(5)v99 value zero.
01 diferenca pic s9(5)v99 value zero.
01 entrada-esperado pic x(40) value spaces.
01 entrada-recebido pic x(40) value spaces.
01 posicao pic 99 value zero.
01 casas-decimais pic 99 value zero.
01 encontrou-ponto pic 9 value zero.
01 esperado-valido pic 9 value zero.
01 recebido-valido pic 9 value zero.
01 entrada-validacao pic x(40) value spaces.
01 validacao-ok pic 9 value zero.
01 valor-validado pic 9(5)v99 value zero.
01 mensagem-erro pic x(80) value spaces.

procedure division.
    display "Sistema de conciliacao iniciado."

    move spaces to nome-operador

    perform until nome-operador not = spaces
        display "Digite o nome ou login do operador:"
        accept nome-operador

        if nome-operador = spaces
            display "Erro: informe o nome do operador."
        end-if
    end-perform

    display "Operador: " nome-operador

    move zero to esperado-valido

    perform until esperado-valido = 1
        display "Digite o valor esperado (exemplo: 100.50):"
        accept entrada-esperado

        move entrada-esperado to entrada-validacao
        perform validar-valor

        if validacao-ok = 1
            move valor-validado to valor-esperado
            move 1 to esperado-valido
        else
            display "Erro no valor esperado: "
                function trim(mensagem-erro)
        end-if
    end-perform

    move zero to recebido-valido

    perform until recebido-valido = 1
        display "Digite o valor recebido (exemplo: 80.25):"
        accept entrada-recebido

        move entrada-recebido to entrada-validacao
        perform validar-valor

        if validacao-ok = 1
            move valor-validado to valor-recebido
            move 1 to recebido-valido
        else
            display "Erro no valor recebido: "
                function trim(mensagem-erro)
        end-if
    end-perform

    compute diferenca = valor-recebido - valor-esperado

    display "Valor esperado: " valor-esperado
    display "Valor recebido: " valor-recebido
    display "Diferenca: " diferenca

    if diferenca = zero
        display "Status: pagamento conferido."
    else
        if diferenca > zero
            display "Status: valor recebido acima do esperado."
        else
            display "Status: valor recebido abaixo do esperado."
        end-if
    end-if

    stop run.

contar-casas-decimais.
    move zero to casas-decimais encontrou-ponto

    perform varying posicao from 1 by 1 until posicao > 40
        if entrada-validacao(posicao:1) = "."
            move 1 to encontrou-ponto
        else
            if encontrou-ponto = 1
                and entrada-validacao(posicao:1) is numeric
                add 1 to casas-decimais
            end-if
        end-if
    end-perform.

validar-valor.
    move zero to validacao-ok valor-validado
    move spaces to mensagem-erro

    evaluate true
        when function test-numval(entrada-validacao) not = zero
            move "informe um numero valido."
                to mensagem-erro

        when function numval(entrada-validacao) < zero
            or function numval(entrada-validacao) > 99999.99
            move "informe um valor entre 0 e 99999.99."
                to mensagem-erro

        when other
            perform contar-casas-decimais

            if casas-decimais > 2
                move "utilize no maximo 2 casas decimais."
                    to mensagem-erro
            else
                compute valor-validado =
                    function numval(entrada-validacao)
                move 1 to validacao-ok
            end-if
    end-evaluate.	

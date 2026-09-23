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
01 esperado-valido pic 9 value zero.
01 recebido-valido pic 9 value zero.

01 entrada-validacao pic x(256) value spaces.
01 validacao-ok pic 9 value zero.
01 valor-validado pic 9(5)v99 value zero.
01 mensagem-erro pic x(80) value spaces.

01 esperado-exibicao pic zzzz9.99.
01 recebido-exibicao pic zzzz9.99.
01 diferenca-exibicao pic +++++9.99.

procedure division.
    display "Sistema de conciliacao iniciado."

    move spaces to nome-operador

    perform until nome-operador not = spaces
        display "Digite o nome ou login do operador:"

        accept nome-operador
            on exception
                display
                    "Erro: entrada encerrada antes de informar o operador."
                move 1 to return-code
                stop run
        end-accept

        if nome-operador = spaces
            display "Erro: informe o nome do operador."
        end-if
    end-perform

    display "Operador: " nome-operador

    move zero to esperado-valido

    perform until esperado-valido = 1
        display "Digite o valor esperado (exemplo: 100.50):"

        accept entrada-esperado
            on exception
                display
                    "Erro: entrada encerrada antes do valor esperado."
                move 1 to return-code
                stop run
        end-accept

        move entrada-esperado to entrada-validacao

        call "validar-monetario" using
            entrada-validacao
            validacao-ok
            valor-validado
            mensagem-erro
        end-call

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
            on exception
                display
                    "Erro: entrada encerrada antes do valor recebido."
                move 1 to return-code
                stop run
        end-accept

        move entrada-recebido to entrada-validacao

        call "validar-monetario" using
            entrada-validacao
            validacao-ok
            valor-validado
            mensagem-erro
        end-call

        if validacao-ok = 1
            move valor-validado to valor-recebido
            move 1 to recebido-valido
        else
            display "Erro no valor recebido: "
                function trim(mensagem-erro)
        end-if
    end-perform

    compute diferenca = valor-recebido - valor-esperado

    move valor-esperado to esperado-exibicao
    move valor-recebido to recebido-exibicao
    move diferenca to diferenca-exibicao

    display "Valor esperado: "
        function trim(esperado-exibicao)
    display "Valor recebido: "
        function trim(recebido-exibicao)
    display "Diferenca: "
        function trim(diferenca-exibicao)

    if diferenca = zero
        display "Status: pagamento conferido."
    else
        if diferenca > zero
            display "Status: valor recebido acima do esperado."
        else
            display "Status: valor recebido abaixo do esperado."
        end-if
    end-if

    move zero to return-code
    stop run.

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

procedure division.
    display "Sistema de conciliacao iniciado."
    display "Digite o nome ou login do operador:"
    accept nome-operador

    if nome-operador = spaces
        display "Erro: informe o nome do operador."
        stop run
    end-if

    display "Operador: " nome-operador

    display "Digite o valor esperado (exemplo: 100.50):"
    accept entrada-esperado

    if function test-numval(entrada-esperado) not = zero
        display "Erro: valor esperado invalido."
        stop run
    end-if

    if function numval(entrada-esperado) < zero
        or function numval(entrada-esperado) > 99999.99
        display "Erro: valor esperado deve estar entre 0 e 99999.99."
        stop run
    end-if

    move zero to casas-decimais encontrou-ponto

    perform varying posicao from 1 by 1 until posicao > 40
        if entrada-esperado(posicao:1) = "."
            move 1 to encontrou-ponto
        else
            if encontrou-ponto = 1
                and entrada-esperado(posicao:1) is numeric
                add 1 to casas-decimais
            end-if
        end-if
    end-perform

    if casas-decimais > 2
        display "Erro: valor esperado deve ter no maximo 2 casas decimais."
        stop run
    end-if

    compute valor-esperado = function numval(entrada-esperado)

    display "Digite o valor recebido (exemplo: 80.25):"
    accept entrada-recebido

    if function test-numval(entrada-recebido) not = zero
        display "Erro: valor recebido invalido."
        stop run
    end-if

    if function numval(entrada-recebido) < zero
        or function numval(entrada-recebido) > 99999.99
        display "Erro: valor recebido deve estar entre 0 e 99999.99."
        stop run
    end-if

    move zero to casas-decimais encontrou-ponto

    perform varying posicao from 1 by 1 until posicao > 40
        if entrada-recebido(posicao:1) = "."
            move 1 to encontrou-ponto
        else
            if encontrou-ponto = 1
                and entrada-recebido(posicao:1) is numeric
                add 1 to casas-decimais
            end-if
        end-if
    end-perform

    if casas-decimais > 2
        display "Erro: valor recebido deve ter no maximo 2 casas decimais."
        stop run
    end-if

    compute valor-recebido = function numval(entrada-recebido)

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

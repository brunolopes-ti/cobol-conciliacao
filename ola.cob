identification division.
program-id. ola.

data division.
working-storage section.
01 nome-operador pic x(40) value spaces.
01 valor-esperado pic 9(5)v99 value 100.00.
01 valor-recebido pic 9(5)v99 value 80.00.
01 diferenca pic s9(5)v99 value zero.

procedure division.
    display "Sistema de conciliacao iniciado."
    display "Digite seu nome:"
    accept nome-operador
    display "Operador: " nome-operador

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

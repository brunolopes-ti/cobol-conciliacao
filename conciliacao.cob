identification division.
program-id. conciliacao.

environment division.
input-output section.
file-control.
    select arquivo-pagamentos
        assign to dynamic caminho-arquivo
        organization is line sequential
        file status is status-arquivo.

    select arquivo-relatorio
        assign to dynamic caminho-relatorio
        organization is line sequential
        file status is status-relatorio.

data division.
file section.
fd arquivo-pagamentos.
01 registro-arquivo pic x(1024).

fd arquivo-relatorio.
01 registro-relatorio pic x(512).

working-storage section.
78 limite-pagamentos value 1000.

01 caminho-esperados pic x(256)
    value "dados/esperados.csv".
01 caminho-recebidos pic x(256)
    value "dados/recebidos.csv".
01 caminho-relatorio pic x(256)
    value "relatorio.txt".
01 quantidade-argumentos binary-long.
01 indice-argumento binary-long.
01 argumento-bruto pic x(4096) value spaces.
01 argumentos.
   05 caminho-argumento pic x(256) occurs 3 times.

01 caminho-arquivo pic x(256) value spaces.
01 status-arquivo pic xx value spaces.
01 status-relatorio pic xx value spaces.
01 linha-relatorio pic x(512) value spaces.
01 fim-arquivo pic 9 value zero.
01 numero-linha pic 9(9) value zero.
01 numero-exibicao pic z(8)9.
01 tamanho-registro pic 9(4) value zero.
01 quantidade-separadores pic 9(4) value zero.

01 tipo-arquivo binary-long.
01 indice binary-long.
01 posicao-livre binary-long.
01 identificador pic x(256) value spaces.
01 valor-texto pic x(256) value spaces.

01 entrada-validacao pic x(256) value spaces.
01 validacao-ok pic 9 value zero.
01 valor-validado pic 9(5)v99 value zero.
01 mensagem-erro pic x(80) value spaces.

01 indice-esperado binary-long.
01 indice-recebido binary-long.
01 posicao-encontrada binary-long.
01 diferenca pic s9(5)v99 value zero.
01 esperado-exibicao pic zzzz9.99.
01 recebido-exibicao pic zzzz9.99.
01 diferenca-exibicao pic +++++9.99.
01 status-pagamento pic x(30) value spaces.

01 quantidade-conferidos pic 9(4) value zero.
01 quantidade-acima pic 9(4) value zero.
01 quantidade-abaixo pic 9(4) value zero.
01 quantidade-sem-recebimento pic 9(4) value zero.
01 quantidade-sem-previsao pic 9(4) value zero.

01 total-esperado pic 9(8)v99 value zero.
01 total-recebido pic 9(8)v99 value zero.
01 saldo-global pic s9(8)v99 value zero.
01 total-exibicao pic z(7)9.99.
01 saldo-exibicao pic +(8)9.99.

01 listas-pagamentos.
   05 lista occurs 2 times.
      10 quantidade binary-long.
      10 pagamento occurs 1000 times.
         15 pagamento-id pic x(256).
         15 pagamento-valor pic 9(5)v99.
         15 pagamento-utilizado pic 9.

procedure division.
    initialize listas-pagamentos
    perform configurar-argumentos

    display "Carregamento dos pagamentos."

    move 1 to tipo-arquivo
    move caminho-esperados to caminho-arquivo
    perform carregar-arquivo

    move 2 to tipo-arquivo
    move caminho-recebidos to caminho-arquivo
    perform carregar-arquivo

    open output arquivo-relatorio

    if status-relatorio not = "00"
        display "Erro ao abrir "
            function trim(caminho-relatorio)
            ". Codigo: " status-relatorio
        move 1 to return-code
        stop run
    end-if

    move "Conferencia dos pagamentos esperados:"
        to linha-relatorio
    perform emitir-linha
    perform conferir-pagamentos

    move "Recebimentos sem previsao:" to linha-relatorio
    perform emitir-linha
    perform mostrar-sem-previsao

    perform mostrar-resumo

    move "Conferencia concluida." to linha-relatorio
    perform gravar-linha

    close arquivo-relatorio

    if status-relatorio not = "00"
        display "Erro ao fechar "
            function trim(caminho-relatorio)
            ". Codigo: " status-relatorio
        move 1 to return-code
        stop run
    end-if

    display "Conferencia concluida."

    move zero to return-code
    stop run.

configurar-argumentos.
    accept quantidade-argumentos from argument-number

    if quantidade-argumentos = zero
        exit paragraph
    end-if

    if quantidade-argumentos not = 3
        display "Erro: informe zero ou tres argumentos."
        perform encerrar-uso
    end-if

    perform varying indice-argumento from 1 by 1
        until indice-argumento > 3

        move spaces to argumento-bruto
        display indice-argumento upon argument-number

        accept argumento-bruto from argument-value
            on exception
                display "Erro: nao foi possivel ler um argumento."
                perform encerrar-uso
        end-accept

        if argumento-bruto = spaces
            display "Erro: caminho vazio."
            perform encerrar-uso
        end-if

        if function length(
            function trim(argumento-bruto trailing)
        ) > 256
            display "Erro: caminho excede 256 posicoes."
            perform encerrar-uso
        end-if

        move argumento-bruto
            to caminho-argumento(indice-argumento)
    end-perform

    move caminho-argumento(1) to caminho-esperados
    move caminho-argumento(2) to caminho-recebidos
    move caminho-argumento(3) to caminho-relatorio

    if caminho-relatorio = caminho-esperados
        or caminho-relatorio = caminho-recebidos
        display "Erro: relatorio deve ter caminho diferente das entradas."
        perform encerrar-uso
    end-if.

encerrar-uso.
    display "Uso: ./conciliacao [esperados recebidos relatorio]"
    move 2 to return-code
    stop run.

carregar-arquivo.
    move zero to fim-arquivo numero-linha

    open input arquivo-pagamentos

    if status-arquivo not = "00"
        display "Erro ao abrir "
            function trim(caminho-arquivo)
            ". Codigo: " status-arquivo
        move 1 to return-code
        stop run
    end-if

    perform until fim-arquivo = 1
        read arquivo-pagamentos

        evaluate status-arquivo
            when "00"
                add 1 to numero-linha
                perform validar-registro

                if mensagem-erro not = spaces
                    perform encerrar-com-erro
                end-if

                perform armazenar-registro

            when "10"
                move 1 to fim-arquivo

            when other
                display "Erro na leitura de "
                    function trim(caminho-arquivo)
                    ". Codigo: " status-arquivo
                close arquivo-pagamentos
                move 1 to return-code
                stop run
        end-evaluate
    end-perform

    close arquivo-pagamentos

    if status-arquivo not = "00"
        display "Erro ao fechar "
            function trim(caminho-arquivo)
            ". Codigo: " status-arquivo
        move 1 to return-code
        stop run
    end-if

    if quantidade(tipo-arquivo) = zero
        display "Erro: arquivo vazio: "
            function trim(caminho-arquivo)
        move 1 to return-code
        stop run
    end-if.

validar-registro.
    move spaces to identificador valor-texto mensagem-erro
    move zero to quantidade-separadores

    compute tamanho-registro =
        function length(
            function trim(registro-arquivo trailing)
        )

    if tamanho-registro > 256
        move "linha excede o limite de 256 caracteres."
            to mensagem-erro
        exit paragraph
    end-if

    inspect registro-arquivo
        tallying quantidade-separadores for all ";"

    if quantidade-separadores not = 1
        move "informe exatamente um ponto e virgula."
            to mensagem-erro
        exit paragraph
    end-if

    unstring registro-arquivo
        delimited by ";"
        into identificador valor-texto
    end-unstring

    move function trim(identificador) to identificador

    if identificador = spaces
        move "identificador vazio." to mensagem-erro
        exit paragraph
    end-if

    if function trim(valor-texto) = spaces
        move "valor vazio." to mensagem-erro
        exit paragraph
    end-if

    move valor-texto to entrada-validacao

    call "validar-monetario" using
        entrada-validacao
        validacao-ok
        valor-validado
        mensagem-erro
    end-call.

armazenar-registro.
    perform varying indice from 1 by 1
        until indice > quantidade(tipo-arquivo)

        if pagamento-id(tipo-arquivo, indice) = identificador
            move "identificador duplicado neste arquivo."
                to mensagem-erro
            perform encerrar-com-erro
        end-if
    end-perform

    if quantidade(tipo-arquivo) >= limite-pagamentos
        move "arquivo excede o limite de 1000 pagamentos."
            to mensagem-erro
        perform encerrar-com-erro
    end-if

    compute posicao-livre = quantidade(tipo-arquivo) + 1

    move identificador
        to pagamento-id(tipo-arquivo, posicao-livre)
    move valor-validado
        to pagamento-valor(tipo-arquivo, posicao-livre)
    move zero
        to pagamento-utilizado(tipo-arquivo, posicao-livre)

    add 1 to quantidade(tipo-arquivo)

    if tipo-arquivo = 1
        add valor-validado to total-esperado
    else
        add valor-validado to total-recebido
    end-if.

encerrar-com-erro.
    move numero-linha to numero-exibicao

    display "Erro em "
        function trim(caminho-arquivo)
        ", linha "
        function trim(numero-exibicao)
        ": "
        function trim(mensagem-erro)

    close arquivo-pagamentos
    move 1 to return-code
    stop run.

conferir-pagamentos.
    perform varying indice-esperado from 1 by 1
        until indice-esperado > quantidade(1)

        perform procurar-recebimento

        if posicao-encontrada = zero
            add 1 to quantidade-sem-recebimento

            move spaces to linha-relatorio
            string
                "Pagamento: "
                function trim(pagamento-id(1, indice-esperado))
                " | Status: sem recebimento"
                delimited by size
                into linha-relatorio
            end-string
            perform emitir-linha
        else
            move 1 to pagamento-utilizado(
                2, posicao-encontrada
            )
            perform comparar-valores
        end-if
    end-perform.

procurar-recebimento.
    move zero to posicao-encontrada

    perform varying indice-recebido from 1 by 1
        until indice-recebido > quantidade(2)

        if pagamento-id(1, indice-esperado) =
            pagamento-id(2, indice-recebido)

            move indice-recebido to posicao-encontrada
            exit perform
        end-if
    end-perform.

comparar-valores.
    compute diferenca =
        pagamento-valor(2, posicao-encontrada)
        - pagamento-valor(1, indice-esperado)

    evaluate true
        when diferenca = zero
            move "conferido" to status-pagamento
            add 1 to quantidade-conferidos
        when diferenca > zero
            move "acima do esperado" to status-pagamento
            add 1 to quantidade-acima
        when other
            move "abaixo do esperado" to status-pagamento
            add 1 to quantidade-abaixo
    end-evaluate

    move pagamento-valor(1, indice-esperado)
        to esperado-exibicao
    move pagamento-valor(2, posicao-encontrada)
        to recebido-exibicao
    move diferenca to diferenca-exibicao

    move spaces to linha-relatorio
    string
        "Pagamento: "
        function trim(pagamento-id(1, indice-esperado))
        " | Esperado: "
        function trim(esperado-exibicao)
        " | Recebido: "
        function trim(recebido-exibicao)
        " | Diferenca: "
        function trim(diferenca-exibicao)
        " | Status: "
        function trim(status-pagamento)
        delimited by size
        into linha-relatorio
    end-string
    perform emitir-linha.

mostrar-sem-previsao.
    perform varying indice-recebido from 1 by 1
        until indice-recebido > quantidade(2)

        if pagamento-utilizado(2, indice-recebido) = zero
            add 1 to quantidade-sem-previsao

            move pagamento-valor(2, indice-recebido)
                to recebido-exibicao

            move spaces to linha-relatorio
            string
                "Pagamento: "
                function trim(pagamento-id(2, indice-recebido))
                " | Recebido: "
                function trim(recebido-exibicao)
                " | Status: sem previsao"
                delimited by size
                into linha-relatorio
            end-string
            perform emitir-linha
        end-if
    end-perform.

mostrar-resumo.
    move "Resumo da conciliacao:" to linha-relatorio
    perform emitir-linha

    move quantidade-conferidos to numero-exibicao
    move spaces to linha-relatorio
    string "Conferidos: " function trim(numero-exibicao)
        delimited by size into linha-relatorio
    end-string
    perform emitir-linha

    move quantidade-acima to numero-exibicao
    move spaces to linha-relatorio
    string "Acima do esperado: " function trim(numero-exibicao)
        delimited by size into linha-relatorio
    end-string
    perform emitir-linha

    move quantidade-abaixo to numero-exibicao
    move spaces to linha-relatorio
    string "Abaixo do esperado: " function trim(numero-exibicao)
        delimited by size into linha-relatorio
    end-string
    perform emitir-linha

    move quantidade-sem-recebimento to numero-exibicao
    move spaces to linha-relatorio
    string "Sem recebimento: " function trim(numero-exibicao)
        delimited by size into linha-relatorio
    end-string
    perform emitir-linha

    move quantidade-sem-previsao to numero-exibicao
    move spaces to linha-relatorio
    string "Sem previsao: " function trim(numero-exibicao)
        delimited by size into linha-relatorio
    end-string
    perform emitir-linha

    move total-esperado to total-exibicao
    move spaces to linha-relatorio
    string "Total esperado: " function trim(total-exibicao)
        delimited by size into linha-relatorio
    end-string
    perform emitir-linha

    move total-recebido to total-exibicao
    move spaces to linha-relatorio
    string "Total recebido: " function trim(total-exibicao)
        delimited by size into linha-relatorio
    end-string
    perform emitir-linha

    compute saldo-global = total-recebido - total-esperado
    move saldo-global to saldo-exibicao
    move spaces to linha-relatorio
    string "Saldo global: " function trim(saldo-exibicao)
        delimited by size into linha-relatorio
    end-string
    perform emitir-linha.

emitir-linha.
    perform gravar-linha
    display function trim(linha-relatorio trailing).

gravar-linha.
    write registro-relatorio from linha-relatorio

    if status-relatorio not = "00"
        display "Erro ao gravar "
            function trim(caminho-relatorio)
            ". Codigo: " status-relatorio
        close arquivo-relatorio
        move 1 to return-code
        stop run
    end-if.
